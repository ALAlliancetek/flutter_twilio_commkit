package com.twiliocommkit.android.video

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.os.Build
import androidx.core.content.ContextCompat
import com.twilio.audioswitch.AudioSwitch
import com.twilio.audioswitch.AudioDevice
import com.twilio.video.*
import com.twiliocommkit.android.TwilioLogger
import com.twiliocommkit.android.core.TwilioEventSink
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class TwilioVideoManager(
    private val context: Context,
    private val eventSink: TwilioEventSink,
    private val scope: CoroutineScope,
    val trackRegistry: TwilioVideoTrackRegistry = TwilioVideoTrackRegistry()
) {

    private var room: Room? = null
    private var localAudioTrack: LocalAudioTrack? = null
    private var localVideoTrack: LocalVideoTrack? = null
    private var cameraCapturer: Camera2Capturer? = null
    private var isFrontCamera = true

    private var pendingConnectResult: Result? = null
    private var pendingRoomName: String = ""

    private var roomType: String = "group"
    private var preferredVideoCodec: String = "vp8"

    // AudioSwitch state guards — prevents "deactivate when Disconnected" warning
    private var audioSwitchStarted = false
    private var audioSwitchActivated = false

    // AudioSwitch handles all audio routing (speaker, earpiece, bluetooth, wired).
    // Build preferred device list; exclude BluetoothHeadset on Android 12+ when
    // BLUETOOTH_CONNECT permission is not granted to avoid log spam.
    private val audioSwitch: AudioSwitch = AudioSwitch(
        context = context,
        loggingEnabled = false,   // suppress verbose internal BT logs
        audioFocusChangeListener = { focusChange ->
            TwilioLogger.debug("AudioSwitch focus change: $focusChange")
        },
        preferredDeviceList = buildPreferredDeviceList()
    )

    // ─── Camera helpers ──────────────────────────────────────────────────────

    /** Returns the preferred device list, omitting BluetoothHeadset when the
     *  required runtime permission is absent (Android 12+). */
    private fun buildPreferredDeviceList(): List<Class<out AudioDevice>> {
        val hasBluetoothPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ContextCompat.checkSelfPermission(
                context, Manifest.permission.BLUETOOTH_CONNECT
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            // Pre-Android 12: BLUETOOTH is a normal (install-time) permission —
            // always granted if declared in the manifest.
            true
        }
        val list = mutableListOf<Class<out AudioDevice>>()
        if (hasBluetoothPermission) list.add(AudioDevice.BluetoothHeadset::class.java)
        list.add(AudioDevice.WiredHeadset::class.java)
        list.add(AudioDevice.Speakerphone::class.java)
        list.add(AudioDevice.Earpiece::class.java)
        return list
    }

    /** Safely starts AudioSwitch, guarded against double-start. */
    private fun safeStartAudioSwitch() {
        if (audioSwitchStarted) return
        audioSwitch.start { audioDevices, selectedDevice ->
            TwilioLogger.debug("AudioSwitch devices: $audioDevices, selected: $selectedDevice")
        }
        audioSwitchStarted = true
    }

    /** Safely activates AudioSwitch — only when started and not yet active. */
    private fun safeActivateAudioSwitch() {
        if (!audioSwitchStarted || audioSwitchActivated) return
        audioSwitch.activate()
        audioSwitchActivated = true
        TwilioLogger.debug("AudioSwitch activated. Selected: ${audioSwitch.selectedAudioDevice}")
    }

    /** Safely deactivates AudioSwitch — only when it was previously activated. */
    private fun safeDeactivateAudioSwitch() {
        if (!audioSwitchActivated) return
        try { audioSwitch.deactivate() } catch (e: Exception) {
            TwilioLogger.warning("AudioSwitch deactivate skipped: ${e.message}")
        }
        audioSwitchActivated = false
    }

    /** Safely stops AudioSwitch — only when it was previously started. */
    private fun safeStopAudioSwitch() {
        safeDeactivateAudioSwitch()
        if (!audioSwitchStarted) return
        try { audioSwitch.stop() } catch (e: Exception) {
            TwilioLogger.warning("AudioSwitch stop skipped: ${e.message}")
        }
        audioSwitchStarted = false
    }

    private fun getCameraId(front: Boolean): String? {
        val cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        for (id in cameraManager.cameraIdList) {
            val facing = cameraManager
                .getCameraCharacteristics(id)
                .get(CameraCharacteristics.LENS_FACING)
            val match = if (front)
                facing == CameraCharacteristics.LENS_FACING_FRONT
            else
                facing == CameraCharacteristics.LENS_FACING_BACK
            if (match) return id
        }
        return cameraManager.cameraIdList.firstOrNull()
    }

    // ─── Config ───────────────────────────────────────────────────────────────

    fun applyConfig(config: Map<String, Any?>) {
        roomType = config["roomType"] as? String ?: "group"
        preferredVideoCodec = config["preferredVideoCodec"] as? String ?: "vp8"
        TwilioLogger.debug("VideoManager config applied: roomType=$roomType codec=$preferredVideoCodec")
    }

    // ─── Public API ──────────────────────────────────────────────────────────

    fun connectToRoom(call: MethodCall, result: Result) {
        val accessToken = call.argument<String>("accessToken") ?: run {
            result.error("INVALID_ARG", "accessToken is required", null); return
        }
        val roomName = call.argument<String>("roomName") ?: run {
            result.error("INVALID_ARG", "roomName is required", null); return
        }
        val enableVideo = call.argument<Boolean>("enableVideo") ?: true
        val enableAudio = call.argument<Boolean>("enableAudio") ?: true

        // If there's an unresolved pending result from a previous attempt,
        // cancel it so the old Flutter call doesn't hang indefinitely.
        pendingConnectResult?.error("CANCELLED", "New joinRoom called", null)
        pendingConnectResult = null

        // Disconnect from any existing room and fully release all resources
        // so the native SDK is in a clean state before the next connect.
        room?.disconnect()
        room = null
        releaseLocalTracks()
        // Reset camera facing so rejoin always starts on front camera
        isFrontCamera = true
        // Fully stop AudioSwitch — safe wrappers reset state flags correctly
        // so the next safeStartAudioSwitch() will actually start it again.
        safeStopAudioSwitch()

        pendingConnectResult = result
        pendingRoomName = roomName

        // All Twilio SDK operations MUST run on Main thread
        scope.launch(Dispatchers.Main) {
            try {
                // Start AudioSwitch — this handles audio focus + routing
                safeStartAudioSwitch()
                // Activate AudioSwitch for the call (routes audio to speaker/bt/etc.)
                safeActivateAudioSwitch()

                if (enableAudio) {
                    localAudioTrack = LocalAudioTrack.create(context, true)
                    if (localAudioTrack == null) {
                        TwilioLogger.error("Failed to create LocalAudioTrack — check RECORD_AUDIO permission")
                    } else {
                        TwilioLogger.debug("LocalAudioTrack created: enabled=${localAudioTrack!!.isEnabled}")
                    }
                }

                if (enableVideo) {
                    val cameraId = getCameraId(front = true)
                    TwilioLogger.debug("Camera ID for front: $cameraId, Camera2Capturer supported: ${Camera2Capturer.isSupported(context)}")
                    if (cameraId != null && Camera2Capturer.isSupported(context)) {
                        cameraCapturer = Camera2Capturer(context, cameraId)
                        localVideoTrack = LocalVideoTrack.create(context, true, cameraCapturer!!)
                        if (localVideoTrack == null) {
                            TwilioLogger.error("Failed to create LocalVideoTrack — check CAMERA permission")
                        } else {
                            TwilioLogger.debug("LocalVideoTrack created: enabled=${localVideoTrack!!.isEnabled}")
                            trackRegistry.setLocalTrack(localVideoTrack)
                        }
                    }
                }

                val connectOptionsBuilder = ConnectOptions.Builder(accessToken)
                    .roomName(roomName)

                localAudioTrack?.let {
                    connectOptionsBuilder.audioTracks(listOf(it))
                    TwilioLogger.debug("Adding audio track to connect options")
                }
                localVideoTrack?.let {
                    connectOptionsBuilder.videoTracks(listOf(it))
                    TwilioLogger.debug("Adding video track to connect options")
                }

                connectOptionsBuilder.enableNetworkQuality(true)
                connectOptionsBuilder.networkQualityConfiguration(
                    NetworkQualityConfiguration(
                        NetworkQualityVerbosity.NETWORK_QUALITY_VERBOSITY_MINIMAL,
                        NetworkQualityVerbosity.NETWORK_QUALITY_VERBOSITY_MINIMAL
                    )
                )

                val connectOptions = connectOptionsBuilder.build()
                room = Video.connect(context, connectOptions, roomListener)
                TwilioLogger.debug("Video.connect() called for room: $roomName")

            } catch (e: Exception) {
                TwilioLogger.error("connectToRoom setup failed", e)
                pendingConnectResult?.error("VIDEO_ERROR", e.message, null)
                pendingConnectResult = null
            }
        }
    }

    fun disconnectFromRoom(call: MethodCall, result: Result) {
        // Disconnect regardless of the roomSid argument — the native side
        // always knows which room it is connected to.
        room?.disconnect()
        room = null
        releaseLocalTracks()
        isFrontCamera = true
        scope.launch(Dispatchers.Main) {
            safeStopAudioSwitch()
        }
        result.success(null)
    }

    fun muteVideo(call: MethodCall, result: Result) {
        val muted = call.argument<Boolean>("muted") ?: false
        localVideoTrack?.enable(!muted)
        TwilioLogger.debug("Video ${if (muted) "muted" else "unmuted"}")
        result.success(null)
    }

    fun muteAudio(call: MethodCall, result: Result) {
        val muted = call.argument<Boolean>("muted") ?: false
        localAudioTrack?.enable(!muted)
        TwilioLogger.debug("Audio ${if (muted) "muted" else "unmuted"}")
        result.success(null)
    }

    fun switchCamera(result: Result) {
        isFrontCamera = !isFrontCamera
        val cameraId = getCameraId(front = isFrontCamera)
        if (cameraId != null) {
            cameraCapturer?.switchCamera(cameraId)
            TwilioLogger.debug("Switched to ${if (isFrontCamera) "front" else "back"} camera: $cameraId")
        }
        result.success(null)
    }

    fun setSpeaker(call: MethodCall, result: Result) {
        val enabled = call.argument<Boolean>("enabled") ?: false
        scope.launch(Dispatchers.Main) {
            try {
                val devices = audioSwitch.availableAudioDevices
                val target = if (enabled)
                    devices.filterIsInstance<AudioDevice.Speakerphone>().firstOrNull()
                else
                    devices.filterIsInstance<AudioDevice.Earpiece>().firstOrNull()
                        ?: devices.filterIsInstance<AudioDevice.WiredHeadset>().firstOrNull()
                        ?: devices.filterIsInstance<AudioDevice.BluetoothHeadset>().firstOrNull()
                if (target != null) {
                    audioSwitch.selectDevice(target)
                    TwilioLogger.debug("Video audio routing → ${target::class.simpleName}")
                }
            } catch (e: Exception) {
                TwilioLogger.error("setSpeaker for video failed", e)
            }
        }
        result.success(null)
    }

    fun getParticipants(call: MethodCall, result: Result) {
        val currentRoom = room
        if (currentRoom == null) {
            result.success(emptyList<Map<String, Any>>())
            return
        }
        val participants = currentRoom.remoteParticipants.map { participant ->
            mapOf(
                "sid" to participant.sid,
                "identity" to participant.identity,
                "isVideoEnabled" to (participant.remoteVideoTracks.firstOrNull()?.isTrackEnabled ?: false),
                "isAudioEnabled" to (participant.remoteAudioTracks.firstOrNull()?.isTrackEnabled ?: false),
                "networkQualityLevel" to (participant.networkQualityLevel?.ordinal ?: 0),
                "isDominantSpeaker" to false
            )
        }
        TwilioLogger.debug("getParticipants: ${participants.size} in room")
        result.success(participants)
    }

    fun dispose() {
        room?.disconnect()
        releaseLocalTracks()
        safeStopAudioSwitch()
    }

    // ─── Room Listener ───────────────────────────────────────────────────────

    private val roomListener = object : Room.Listener {
        override fun onConnected(room: Room) {
            TwilioLogger.debug("Room connected: ${room.name} sid=${room.sid} participants=${room.remoteParticipants.size}")
            this@TwilioVideoManager.room = room

            pendingConnectResult?.success(
                mapOf(
                    "sid" to room.sid,
                    "name" to room.name,
                    "state" to "connected",
                    "localParticipantSid" to (room.localParticipant?.sid ?: "")
                )
            )
            pendingConnectResult = null

            eventSink.send(mapOf(
                "type" to "roomConnected",
                "roomSid" to room.sid,
                "roomName" to room.name
            ))

            // Emit participants already in the room
            room.remoteParticipants.forEach { participant ->
                TwilioLogger.debug("Pre-existing participant: ${participant.identity}")
                participant.setListener(makeParticipantListener(participant))
                eventSink.send(mapOf(
                    "type" to "participantConnected",
                    "participant" to mapOf(
                        "sid" to participant.sid,
                        "identity" to participant.identity,
                        "isVideoEnabled" to (participant.remoteVideoTracks.firstOrNull()?.isTrackEnabled ?: false),
                        "isAudioEnabled" to (participant.remoteAudioTracks.firstOrNull()?.isTrackEnabled ?: false),
                        "networkQualityLevel" to 0,
                        "isDominantSpeaker" to false
                    )
                ))
                participant.remoteVideoTracks.forEach { pub ->
                    pub.remoteVideoTrack?.let { track ->
                        trackRegistry.addRemoteTrack(participant.sid, track)
                    }
                }
                // Explicitly enable any already-subscribed audio tracks
                participant.remoteAudioTracks.forEach { pub ->
                    pub.remoteAudioTrack?.let { track ->
                        track.enablePlayback(true)
                        TwilioLogger.debug("Enabled pre-existing audio track for ${participant.identity}")
                    }
                }
            }
        }

        override fun onConnectFailure(room: Room, twilioException: TwilioException) {
            TwilioLogger.error("Room connect failure: ${twilioException.message}", twilioException)
            pendingConnectResult?.error("VIDEO_ERROR", twilioException.message, null)
            pendingConnectResult = null
            // Clean up so a retry attempt starts from a clean state
            this@TwilioVideoManager.room = null
            releaseLocalTracks()
            safeStopAudioSwitch()
            eventSink.send(mapOf("type" to "error",
                "message" to (twilioException.message ?: "Connect failed"),
                "code" to twilioException.code))
        }

        override fun onDisconnected(room: Room, twilioException: TwilioException?) {
            TwilioLogger.debug("Room disconnected: ${room.name}")
            // Use safe wrappers so the state flags are kept in sync — prevents
            // "deactivate in Disconnected state" on next joinRoom attempt.
            safeStopAudioSwitch()
            // Clear the room reference so connectToRoom starts with a clean slate.
            this@TwilioVideoManager.room = null
            eventSink.send(mapOf("type" to "roomDisconnected",
                "roomSid" to room.sid, "reason" to twilioException?.message))
        }

        override fun onReconnecting(room: Room, twilioException: TwilioException) {
            eventSink.send(mapOf("type" to "roomReconnecting", "roomSid" to room.sid))
        }

        override fun onReconnected(room: Room) {
            eventSink.send(mapOf("type" to "roomReconnected", "roomSid" to room.sid))
        }

        override fun onParticipantConnected(room: Room, remoteParticipant: RemoteParticipant) {
            TwilioLogger.debug("Participant connected: ${remoteParticipant.identity}")
            remoteParticipant.setListener(makeParticipantListener(remoteParticipant))
            eventSink.send(mapOf(
                "type" to "participantConnected",
                "participant" to mapOf(
                    "sid" to remoteParticipant.sid,
                    "identity" to remoteParticipant.identity,
                    "isVideoEnabled" to (remoteParticipant.remoteVideoTracks.firstOrNull()?.isTrackEnabled ?: false),
                    "isAudioEnabled" to (remoteParticipant.remoteAudioTracks.firstOrNull()?.isTrackEnabled ?: false),
                    "networkQualityLevel" to 0,
                    "isDominantSpeaker" to false
                )
            ))
            // Register already-subscribed tracks
            remoteParticipant.remoteVideoTracks.forEach { pub ->
                pub.remoteVideoTrack?.let { track ->
                    trackRegistry.addRemoteTrack(remoteParticipant.sid, track)
                }
            }
            remoteParticipant.remoteAudioTracks.forEach { pub ->
                pub.remoteAudioTrack?.let { track ->
                    track.enablePlayback(true)
                    TwilioLogger.debug("Enabled audio track for newly connected ${remoteParticipant.identity}")
                }
            }
        }

        override fun onParticipantDisconnected(room: Room, remoteParticipant: RemoteParticipant) {
            TwilioLogger.debug("Participant disconnected: ${remoteParticipant.identity}")
            eventSink.send(mapOf("type" to "participantDisconnected",
                "participantSid" to remoteParticipant.sid))
        }

        override fun onDominantSpeakerChanged(room: Room, remoteParticipant: RemoteParticipant?) {
            eventSink.send(mapOf("type" to "dominantSpeakerChanged",
                "participantSid" to remoteParticipant?.sid))
        }

        override fun onRecordingStarted(room: Room) {}
        override fun onRecordingStopped(room: Room) {}
    }

    // ─── Participant Listener ─────────────────────────────────────────────────

    private fun makeParticipantListener(participant: RemoteParticipant) =
        object : RemoteParticipant.Listener {
            override fun onVideoTrackSubscribed(
                participant: RemoteParticipant,
                publication: RemoteVideoTrackPublication,
                track: RemoteVideoTrack
            ) {
                TwilioLogger.debug("Remote video track subscribed: ${participant.identity}")
                trackRegistry.addRemoteTrack(participant.sid, track)
            }

            override fun onVideoTrackUnsubscribed(
                participant: RemoteParticipant,
                publication: RemoteVideoTrackPublication,
                track: RemoteVideoTrack
            ) {
                TwilioLogger.debug("Remote video track unsubscribed: ${participant.identity}")
                trackRegistry.removeRemoteTrack(participant.sid)
            }

            override fun onAudioTrackSubscribed(
                p: RemoteParticipant,
                pub: RemoteAudioTrackPublication,
                track: RemoteAudioTrack
            ) {
                // CRITICAL: explicitly enable playback so remote audio is heard
                track.enablePlayback(true)
                TwilioLogger.debug("Remote audio track subscribed + playback enabled: ${p.identity}")
            }

            override fun onAudioTrackUnsubscribed(
                p: RemoteParticipant,
                pub: RemoteAudioTrackPublication,
                track: RemoteAudioTrack
            ) {
                track.enablePlayback(false)
                TwilioLogger.debug("Remote audio track unsubscribed: ${p.identity}")
            }

            override fun onAudioTrackEnabled(p: RemoteParticipant, pub: RemoteAudioTrackPublication) {
                pub.remoteAudioTrack?.enablePlayback(true)
                eventSink.send(mapOf(
                    "type" to "participantAudioChanged",
                    "participantSid" to p.sid,
                    "isAudioEnabled" to true
                ))
            }
            override fun onAudioTrackDisabled(p: RemoteParticipant, pub: RemoteAudioTrackPublication) {
                eventSink.send(mapOf(
                    "type" to "participantAudioChanged",
                    "participantSid" to p.sid,
                    "isAudioEnabled" to false
                ))
            }
            override fun onVideoTrackEnabled(p: RemoteParticipant, pub: RemoteVideoTrackPublication) {
                eventSink.send(mapOf(
                    "type" to "participantVideoChanged",
                    "participantSid" to p.sid,
                    "isVideoEnabled" to true
                ))
            }
            override fun onVideoTrackDisabled(p: RemoteParticipant, pub: RemoteVideoTrackPublication) {
                eventSink.send(mapOf(
                    "type" to "participantVideoChanged",
                    "participantSid" to p.sid,
                    "isVideoEnabled" to false
                ))
            }
            override fun onAudioTrackSubscriptionFailed(p: RemoteParticipant, pub: RemoteAudioTrackPublication, e: TwilioException) {
                TwilioLogger.error("Audio track subscription failed for ${p.identity}: ${e.message}", e)
            }
            override fun onVideoTrackSubscriptionFailed(p: RemoteParticipant, pub: RemoteVideoTrackPublication, e: TwilioException) {}
            override fun onVideoTrackPublished(p: RemoteParticipant, pub: RemoteVideoTrackPublication) {}
            override fun onVideoTrackUnpublished(p: RemoteParticipant, pub: RemoteVideoTrackPublication) {}
            override fun onAudioTrackPublished(p: RemoteParticipant, pub: RemoteAudioTrackPublication) {}
            override fun onAudioTrackUnpublished(p: RemoteParticipant, pub: RemoteAudioTrackPublication) {}
            override fun onDataTrackPublished(p: RemoteParticipant, pub: RemoteDataTrackPublication) {}
            override fun onDataTrackUnpublished(p: RemoteParticipant, pub: RemoteDataTrackPublication) {}
            override fun onDataTrackSubscribed(p: RemoteParticipant, pub: RemoteDataTrackPublication, track: RemoteDataTrack) {}
            override fun onDataTrackUnsubscribed(p: RemoteParticipant, pub: RemoteDataTrackPublication, track: RemoteDataTrack) {}
            override fun onDataTrackSubscriptionFailed(p: RemoteParticipant, pub: RemoteDataTrackPublication, e: TwilioException) {}
            override fun onNetworkQualityLevelChanged(p: RemoteParticipant, networkQualityLevel: NetworkQualityLevel) {}
        }

    private fun releaseLocalTracks() {
        trackRegistry.setLocalTrack(null)
        trackRegistry.clear()
        localAudioTrack?.release()
        localAudioTrack = null
        localVideoTrack?.release()
        localVideoTrack = null
        // Stop the camera capturer explicitly — without this, the Camera2
        // session stays open and the green camera indicator never turns off.
        try { cameraCapturer?.stopCapture() } catch (_: Exception) {}
        cameraCapturer = null
    }
}
