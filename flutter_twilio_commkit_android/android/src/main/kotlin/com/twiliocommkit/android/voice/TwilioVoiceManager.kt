package com.twiliocommkit.android.voice

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import com.twilio.voice.*
import com.twiliocommkit.android.TwilioLogger
import com.twiliocommkit.android.core.TwilioEventSink
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * Manages Twilio Voice calls on Android.
 *
 * Handles:
 * - Outgoing/incoming calls
 * - Mute, hold, speaker
 * - Audio focus management
 * - Forwarding call events to Flutter
 * - BroadcastReceiver for FCM-triggered incoming calls
 */
class TwilioVoiceManager(
    private val context: Context,
    private val eventSink: TwilioEventSink,
    private val scope: CoroutineScope
) {

    private var activeCall: Call? = null
    private var activeCallInvite: CallInvite? = null
    private val audioManager: AudioManager =
        context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    // Resolved from TwilioVoiceConfig passed via initialize()
    private var enableForegroundService: Boolean = true
    private var callerIdName: String? = null
    private var defaultRegion: String? = null
    private var enableInsights: Boolean = true
    private var lastAccessToken: String = ""

    // ─── BroadcastReceiver — listens for incoming call from FCM ─────────────

    private val incomingCallReceiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context, intent: Intent) {
            when (intent.action) {
                TwilioVoiceNotificationHandler.ACTION_INCOMING_CALL -> {
                    val callSid = intent.getStringExtra(TwilioVoiceNotificationHandler.EXTRA_CALL_SID) ?: ""
                    val from = intent.getStringExtra(TwilioVoiceNotificationHandler.EXTRA_FROM) ?: "Unknown"

                    // Populate activeCallInvite from store so acceptCall/rejectCall work
                    val invite = TwilioVoiceCallInviteStore.pendingCallInvite
                    if (invite != null) {
                        activeCallInvite = invite
                        TwilioLogger.debug("BroadcastReceiver: incoming call stored — sid=$callSid from=$from")
                    }

                    // NOTE: We do NOT launch TwilioIncomingCallActivity here.
                    // TwilioVoiceNotificationHandler already posted the notification with
                    // fullScreenIntent pointing to TwilioIncomingCallActivity. Android will:
                    //   • Foreground → fire fullScreenIntent immediately (API 29+ with USE_FULL_SCREEN_INTENT)
                    //   • Background / killed → fire fullScreenIntent or show heads-up notification
                    // Starting the activity again here would cause two instances to appear.

                    // Emit Flutter event only for headless / custom handling scenarios.
                    eventSink.send(mapOf(
                        "type" to "callIncoming",
                        "callSid" to callSid,
                        "from" to from.removePrefix("client:"),
                        "to" to ""
                    ))
                }
                TwilioVoiceNotificationHandler.ACTION_CANCEL_CALL -> {
                    val callSid = intent.getStringExtra(TwilioVoiceNotificationHandler.EXTRA_CALL_SID) ?: ""
                    activeCallInvite = null
                    TwilioVoiceCallInviteStore.pendingCallInvite = null
                    TwilioLogger.debug("BroadcastReceiver: call cancelled — sid=$callSid")
                    eventSink.send(mapOf("type" to "callDisconnected", "callSid" to callSid))
                }
            }
        }
    }


    private var receiverRegistered = false

    private fun registerReceiver() {
        if (receiverRegistered) return
        val filter = IntentFilter().apply {
            addAction(TwilioVoiceNotificationHandler.ACTION_INCOMING_CALL)
            addAction(TwilioVoiceNotificationHandler.ACTION_CANCEL_CALL)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(incomingCallReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context.registerReceiver(incomingCallReceiver, filter)
        }
        receiverRegistered = true
        TwilioLogger.debug("VoiceManager: BroadcastReceiver registered")
    }

    private fun unregisterReceiver() {
        if (!receiverRegistered) return
        try { context.unregisterReceiver(incomingCallReceiver) } catch (_: Exception) {}
        receiverRegistered = false
    }

    // ─── Config ───────────────────────────────────────────────────────────────

    fun applyConfig(config: Map<String, Any?>) {
        enableForegroundService = config["enableForegroundService"] as? Boolean ?: true
        callerIdName = config["callerIdName"] as? String
        defaultRegion = config["defaultRegion"] as? String
        enableInsights = config["enableInsights"] as? Boolean ?: true
        // Store notification icon name so TwilioVoiceNotificationHandler can use it
        val iconName = config["notificationIconName"] as? String
        if (iconName != null) {
            TwilioNotificationConfig.notificationIconName = iconName
            TwilioLogger.debug("VoiceManager: custom notification icon set → $iconName")
        }
        TwilioLogger.debug("VoiceManager config applied: callerIdName=$callerIdName region=$defaultRegion")
    }

    // ─── Public API ──────────────────────────────────────────────────────────

    fun initVoice(call: MethodCall, result: Result) {
        val accessToken = call.argument<String>("accessToken") ?: run {
            result.error("INVALID_ARG", "accessToken is required", null); return
        }
        lastAccessToken = accessToken
        val fcmToken = call.argument<String>("fcmToken")

        // Always register broadcast receiver so incoming calls from FCM are handled
        registerReceiver()

        // Silently restore any pending call invite (stored by TwilioFcmService).
        // The Flutter layer (TwilioCallHandler) calls acceptCall() with the proper
        // callListener so all events (connected, disconnected) reach Flutter correctly.
        val pending = TwilioVoiceCallInviteStore.pendingCallInvite
        if (pending != null) {
            activeCallInvite = pending
            TwilioLogger.debug("initVoice: restored pending CallInvite sid=${pending.callSid}")
        }


        if (!fcmToken.isNullOrBlank()) {
            Voice.register(accessToken, Voice.RegistrationChannel.FCM, fcmToken, object : RegistrationListener {
                override fun onRegistered(accessToken: String, fcmToken: String) {
                    TwilioLogger.debug("Voice registered for incoming calls (FCM)")
                    result.success(null)
                }
                override fun onError(registrationException: RegistrationException, accessToken: String, fcmToken: String) {
                    TwilioLogger.error("Voice FCM registration failed", registrationException)
                    TwilioLogger.warning("Continuing without push registration — outgoing calls will still work")
                    result.success(null)
                }
            })
        } else {
            TwilioLogger.debug("Voice initialized in outgoing-only mode (no FCM token — incoming push not available)")
            result.success(null)
        }
    }

    fun startCall(call: MethodCall, result: Result) {
        val to = call.argument<String>("to") ?: run {
            result.error("INVALID_ARG", "to is required", null); return
        }
        val accessToken = call.argument<String>("accessToken")?.takeIf { it.isNotBlank() }
            ?: lastAccessToken.takeIf { it.isNotBlank() }
            ?: run {
                result.error("INVALID_ARG", "accessToken is required — pass it in startCall or call initVoice first", null)
                return
            }
        val params = call.argument<Map<String, String>>("params") ?: emptyMap()

        TwilioLogger.debug("startCall to=$to using token length=${accessToken.length}")
        val connectOptions = ConnectOptions.Builder(accessToken)
            .params(mapOf("To" to to) + params)
            .build()

        requestAudioFocus()
        activeCall = Voice.connect(context, connectOptions, callListener)
        result.success(mapOf(
            "callSid" to (activeCall?.sid ?: ""),
            "state" to "connecting",
            "to" to to,
            "isMuted" to false,
            "isOnHold" to false
        ))
    }

    fun acceptCall(call: MethodCall, result: Result) {
        // Try activeCallInvite, then fall back to store
        val invite = activeCallInvite ?: TwilioVoiceCallInviteStore.pendingCallInvite
        if (invite == null) {
            TwilioLogger.warning("acceptCall: no pending call invite found")
            result.error("NO_INVITE", "No pending call invite to accept", null)
            return
        }
        requestAudioFocus()
        activeCall = invite.accept(context, callListener)
        activeCallInvite = null
        TwilioVoiceCallInviteStore.pendingCallInvite = null
        result.success(null)
    }

    fun rejectCall(call: MethodCall, result: Result) {
        val invite = activeCallInvite ?: TwilioVoiceCallInviteStore.pendingCallInvite
        if (invite == null) {
            TwilioLogger.warning("rejectCall: no pending call invite found")
            result.success(null) // Already gone — treat as success
            return
        }
        invite.reject(context)
        activeCallInvite = null
        TwilioVoiceCallInviteStore.pendingCallInvite = null
        result.success(null)
    }

    fun hangUpCall(call: MethodCall, result: Result) {
        activeCall?.disconnect()
        abandonAudioFocus()
        result.success(null)
    }

    fun muteCall(call: MethodCall, result: Result) {
        val muted = call.argument<Boolean>("muted") ?: false
        activeCall?.mute(muted)
        result.success(null)
    }

    fun holdCall(call: MethodCall, result: Result) {
        val held = call.argument<Boolean>("held") ?: false
        activeCall?.hold(held)
        result.success(null)
    }

    fun setSpeaker(call: MethodCall, result: Result) {
        val enabled = call.argument<Boolean>("enabled") ?: false
        setSpeakerInternal(enabled)
        result.success(null)
    }

    private fun setSpeakerInternal(enabled: Boolean) {
        // MODE_IN_COMMUNICATION is required for voice calls on Android.
        // Without it, isSpeakerphoneOn has no effect on the audio routing.
        audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
        audioManager.isSpeakerphoneOn = enabled
        TwilioLogger.debug("Audio routing → ${if (enabled) "SPEAKER" else "EARPIECE"}")
    }

    fun sendDigits(call: MethodCall, result: Result) {
        val digits = call.argument<String>("digits") ?: run {
            result.error("INVALID_ARG", "digits is required", null); return
        }
        activeCall?.sendDigits(digits)
        TwilioLogger.debug("sendDigits: $digits")
        result.success(null)
    }

    fun dispose() {
        activeCall?.disconnect()
        abandonAudioFocus()
        unregisterReceiver()
    }

    // ─── Call Listener ───────────────────────────────────────────────────────

    private val callListener = object : Call.Listener {
        override fun onConnectFailure(call: Call, callException: CallException) {
            TwilioLogger.error("Call connect failure [${callException.errorCode}]: ${callException.message}", callException)
            eventSink.send(mapOf(
                "type" to "callFailed",
                "callSid" to call.sid,
                "message" to (callException.message ?: "Connect failed"),
                "code" to callException.errorCode
            ))
        }

        override fun onRinging(call: Call) {
            TwilioLogger.debug("Call ringing: ${call.sid}")
            eventSink.send(mapOf("type" to "callRinging", "callSid" to call.sid))
        }

        override fun onConnected(call: Call) {
            TwilioLogger.debug("Call connected: ${call.sid}")
            activeCall = call
            eventSink.send(mapOf("type" to "callConnected", "callSid" to call.sid))
        }

        override fun onReconnecting(call: Call, callException: CallException) {
            TwilioLogger.warning("Call reconnecting [${callException.errorCode}]: ${callException.message}")
            eventSink.send(mapOf("type" to "callReconnecting", "callSid" to call.sid))
        }

        override fun onReconnected(call: Call) {
            TwilioLogger.debug("Call reconnected: ${call.sid}")
            eventSink.send(mapOf("type" to "callReconnected", "callSid" to call.sid))
        }

        override fun onDisconnected(call: Call, callException: CallException?) {
            if (callException != null) {
                TwilioLogger.error("Call disconnected with error [${callException.errorCode}]: ${callException.message}", callException)
            } else {
                TwilioLogger.debug("Call disconnected normally: ${call.sid}")
            }
            abandonAudioFocus()
            eventSink.send(mapOf(
                "type" to "callDisconnected",
                "callSid" to call.sid,
                "errorCode" to (callException?.errorCode ?: 0),
                "errorMessage" to (callException?.message ?: "")
            ))
            activeCall = null
        }

        override fun onCallQualityWarningsChanged(
            call: Call,
            currentWarnings: MutableSet<Call.CallQualityWarning>,
            previousWarnings: MutableSet<Call.CallQualityWarning>
        ) {
            val warningLabels = currentWarnings.map { it.name }
            TwilioLogger.debug("Call quality warnings changed: $warningLabels")
            eventSink.send(mapOf(
                "type" to "callQualityWarning",
                "callSid" to call.sid,
                "warnings" to warningLabels
            ))
        }
    }

    // ─── Audio Focus ─────────────────────────────────────────────────────────

    private var audioFocusRequest: AudioFocusRequest? = null

    private fun requestAudioFocus() {
        // MODE_IN_COMMUNICATION routes audio through earpiece for voice calls.
        // Speaker is OFF by default — user can toggle via setSpeaker().
        audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
        audioManager.isSpeakerphoneOn = false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val focusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build()
                )
                .setAcceptsDelayedFocusGain(false)
                .build()
            audioFocusRequest = focusRequest
            audioManager.requestAudioFocus(focusRequest)
        } else {
            @Suppress("DEPRECATION")
            audioManager.requestAudioFocus(
                null,
                AudioManager.STREAM_VOICE_CALL,
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT
            )
        }
        TwilioLogger.debug("Audio focus acquired — routing to EARPIECE (default)")
    }

    private fun abandonAudioFocus() {
        audioManager.isSpeakerphoneOn = false
        audioManager.mode = AudioManager.MODE_NORMAL
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioFocusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
            audioFocusRequest = null
        } else {
            @Suppress("DEPRECATION")
            audioManager.abandonAudioFocus(null)
        }
        TwilioLogger.debug("Audio focus released")
    }
}
