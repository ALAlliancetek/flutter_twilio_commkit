import Flutter
import TwilioVideo
import AVFoundation

/// Manages Twilio Video room lifecycle on iOS.
final class TwilioVideoManager: NSObject {

    private let eventSink: TwilioEventSink
    private var room: Room?
    private var localAudioTrack: LocalAudioTrack?
    private var localVideoTrack: LocalVideoTrack?
    private var camera: CameraSource?
    private var isFrontCamera = true

    // Pending connect result — held until roomDidConnect or roomDidFailToConnect
    private var pendingConnectResult: FlutterResult?

    // Resolved from TwilioVideoConfig
    private var enableNetworkQuality = true
    private var preferredVideoCodec = "vp8"
    private var maxVideoBitrate: UInt?
    private var maxAudioBitrate: UInt?

    init(eventSink: TwilioEventSink) {
        self.eventSink = eventSink
    }

    // MARK: - Config

    func applyConfig(_ config: [String: Any]) {
        enableNetworkQuality = config["enableNetworkQuality"] as? Bool ?? true
        preferredVideoCodec = config["preferredVideoCodec"] as? String ?? "vp8"
        if let v = config["maxVideoBitrate"] as? Int { maxVideoBitrate = UInt(v) }
        if let a = config["maxAudioBitrate"] as? Int { maxAudioBitrate = UInt(a) }
        TwilioLogger.debug("VideoManager config: codec=\(preferredVideoCodec) networkQuality=\(enableNetworkQuality)")
    }

    // MARK: - Public API

    func connectToRoom(args: [String: Any], result: @escaping FlutterResult) {
        guard let accessToken = args["accessToken"] as? String,
              let roomName = args["roomName"] as? String else {
            result(FlutterError(code: "INVALID_ARG", message: "accessToken and roomName required", details: nil))
            return
        }
        let enableVideo = args["enableVideo"] as? Bool ?? true
        let enableAudio = args["enableAudio"] as? Bool ?? true

        room?.disconnect()
        releaseLocalTracks()

        // Store result — resolved in roomDidConnect or roomDidFailToConnect
        pendingConnectResult = result

        // Configure AVAudioSession for voice communication
        configureAudioSession()

        if enableAudio {
            localAudioTrack = LocalAudioTrack.init()
            if localAudioTrack == nil {
                TwilioLogger.error("Failed to create LocalAudioTrack — check NSMicrophoneUsageDescription and permission")
            } else {
                TwilioLogger.debug("LocalAudioTrack created: enabled=\(localAudioTrack!.isEnabled)")
            }
        }

        if enableVideo {
            let frontCamera = CameraSource.captureDevice(position: .front)
            TwilioLogger.debug("Front camera device: \(String(describing: frontCamera))")
            if let device = frontCamera {
                camera = CameraSource()
                localVideoTrack = LocalVideoTrack(source: camera!, enabled: true, name: "camera")
                camera?.startCapture(device: device) { _, _, error in
                    if let error = error {
                        TwilioLogger.error("Camera capture start error: \(error)")
                    }
                }
                if localVideoTrack == nil {
                    TwilioLogger.error("Failed to create LocalVideoTrack — check NSCameraUsageDescription and permission")
                } else {
                    TwilioLogger.debug("LocalVideoTrack created: enabled=\(localVideoTrack!.isEnabled)")
                }
            } else {
                TwilioLogger.error("No front camera found on device")
            }
        }

        let connectOptions = ConnectOptions(token: accessToken) { builder in
            builder.roomName = roomName
            if let audio = self.localAudioTrack {
                builder.audioTracks = [audio]
                TwilioLogger.debug("Adding audio track to connect options")
            }
            if let video = self.localVideoTrack {
                builder.videoTracks = [video]
                TwilioLogger.debug("Adding video track to connect options")
            }
            builder.isNetworkQualityEnabled = true
            builder.networkQualityConfiguration = NetworkQualityConfiguration(
                localVerbosity: .minimal,
                remoteVerbosity: .minimal
            )
        }

        TwilioLogger.debug("TwilioVideoSDK.connect() called for room: \(roomName)")
        room = TwilioVideoSDK.connect(options: connectOptions, delegate: self)
        // NOTE: result is NOT called here — it's called in roomDidConnect/roomDidFailToConnect
    }

    func disconnectFromRoom(args: [String: Any], result: @escaping FlutterResult) {
        room?.disconnect()
        room = nil
        releaseLocalTracks()
        deactivateAudioSession()
        result(nil)
    }

    func muteVideo(args: [String: Any], result: @escaping FlutterResult) {
        let muted = args["muted"] as? Bool ?? false
        localVideoTrack?.isEnabled = !muted
        result(nil)
    }

    func muteAudio(args: [String: Any], result: @escaping FlutterResult) {
        let muted = args["muted"] as? Bool ?? false
        localAudioTrack?.isEnabled = !muted
        result(nil)
    }

    func switchCamera(result: @escaping FlutterResult) {
        isFrontCamera.toggle()
        let position: AVCaptureDevice.Position = isFrontCamera ? .front : .back
        if let device = CameraSource.captureDevice(position: position) {
            camera?.selectCaptureDevice(device) { _, _, error in
                if let error = error {
                    TwilioLogger.error("switchCamera error: \(error)")
                }
            }
        }
        result(nil)
    }

    func setSpeaker(args: [String: Any], result: @escaping FlutterResult) {
        let enabled = args["enabled"] as? Bool ?? false
        let session = AVAudioSession.sharedInstance()
        do {
            try session.overrideOutputAudioPort(enabled ? .speaker : .none)
            TwilioLogger.debug("Video audio routing → \(enabled ? "SPEAKER" : "EARPIECE")")
        } catch {
            TwilioLogger.error("setSpeaker for video failed: \(error.localizedDescription)")
        }
        result(nil)
    }

    func getParticipants(args: [String: Any], result: @escaping FlutterResult) {
        let participants = room?.remoteParticipants.map { p -> [String: Any] in
            return [
                "sid": p.sid,
                "identity": p.identity,
                "isVideoEnabled": p.remoteVideoTracks.first?.isTrackEnabled ?? false,
                "isAudioEnabled": p.remoteAudioTracks.first?.isTrackEnabled ?? false,
                "networkQualityLevel": p.networkQualityLevel.rawValue,
                "isDominantSpeaker": false
            ]
        } ?? []
        result(participants)
    }

    func dispose() {
        room?.disconnect()
        releaseLocalTracks()
        deactivateAudioSession()
    }

    // MARK: - Audio Session

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord,
                                    mode: .voiceChat,
                                    options: [.allowBluetooth, .allowBluetoothA2DP])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            TwilioLogger.debug("AVAudioSession configured for video call")
        } catch {
            TwilioLogger.error("AVAudioSession configure failed: \(error)")
        }
    }

    private func deactivateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            TwilioLogger.error("AVAudioSession deactivate failed: \(error)")
        }
    }

    // MARK: - Private

    private func releaseLocalTracks() {
        camera?.stopCapture()
        localVideoTrack = nil
        localAudioTrack = nil
        camera = nil
    }
}

// MARK: - RoomDelegate
extension TwilioVideoManager: RoomDelegate {
    func roomDidConnect(room: Room) {
        TwilioLogger.debug("Room connected: \(room.name) sid=\(room.sid) participants=\(room.remoteParticipants.count)")
        self.room = room

        pendingConnectResult?([
            "sid": room.sid,
            "name": room.name,
            "state": "connected",
            "localParticipantSid": room.localParticipant?.sid ?? ""
        ])
        pendingConnectResult = nil

        eventSink.send(["type": "roomConnected", "roomSid": room.sid, "roomName": room.name])

        // Emit pre-existing participants
        room.remoteParticipants.forEach { participant in
            TwilioLogger.debug("Pre-existing participant: \(participant.identity)")
            participant.delegate = self  // subscribe to track enable/disable events
            eventSink.send([
                "type": "participantConnected",
                "participant": [
                    "sid": participant.sid,
                    "identity": participant.identity,
                    "isVideoEnabled": participant.remoteVideoTracks.first?.isTrackEnabled ?? false,
                    "isAudioEnabled": participant.remoteAudioTracks.first?.isTrackEnabled ?? false,
                    "networkQualityLevel": 0,
                    "isDominantSpeaker": false
                ] as [String: Any]
            ])
        }
    }

    func roomDidFailToConnect(room: Room, error: Error) {
        TwilioLogger.error("Room connect failed: \(error)")
        let nsError = error as NSError
        pendingConnectResult?(FlutterError(code: "VIDEO_ERROR",
                                           message: error.localizedDescription,
                                           details: nsError.code))
        pendingConnectResult = nil
        eventSink.send(["type": "error", "message": error.localizedDescription, "code": nsError.code])
    }

    func roomDidDisconnect(room: Room, error: Error?) {
        TwilioLogger.debug("Room disconnected: \(room.name)")
        deactivateAudioSession()
        eventSink.send(["type": "roomDisconnected", "roomSid": room.sid,
                        "reason": error?.localizedDescription ?? NSNull()])
        releaseLocalTracks()
    }

    func roomIsReconnecting(room: Room, error: Error) {
        eventSink.send(["type": "roomReconnecting", "roomSid": room.sid])
    }

    func roomDidReconnect(room: Room) {
        eventSink.send(["type": "roomReconnected", "roomSid": room.sid])
    }

    func participantDidConnect(room: Room, participant: RemoteParticipant) {
        TwilioLogger.debug("Participant connected: \(participant.identity)")
        participant.delegate = self  // subscribe to track enable/disable events
        eventSink.send([
            "type": "participantConnected",
            "participant": [
                "sid": participant.sid,
                "identity": participant.identity,
                "isVideoEnabled": participant.remoteVideoTracks.first?.isTrackEnabled ?? false,
                "isAudioEnabled": participant.remoteAudioTracks.first?.isTrackEnabled ?? false,
                "networkQualityLevel": 0,
                "isDominantSpeaker": false
            ] as [String: Any]
        ])
    }

    func participantDidDisconnect(room: Room, participant: RemoteParticipant) {
        TwilioLogger.debug("Participant disconnected: \(participant.identity)")
        eventSink.send(["type": "participantDisconnected", "participantSid": participant.sid])
    }

    func dominantSpeakerDidChange(room: Room, participant: RemoteParticipant?) {
        eventSink.send(["type": "dominantSpeakerChanged", "participantSid": participant?.sid ?? NSNull()])
    }

    func remoteParticipantDidChangeNetworkQualityLevel(
        participant: RemoteParticipant,
        networkQualityLevel: NetworkQualityLevel
    ) {
        eventSink.send([
            "type": "networkQualityChanged",
            "quality": [
                "participantSid": participant.sid,
                "level": networkQualityLevel.rawValue
            ] as [String: Any]
        ])
    }
}

// MARK: - RemoteParticipantDelegate (audio/video mute state changes)
extension TwilioVideoManager: RemoteParticipantDelegate {
    func remoteParticipantDidEnableVideoTrack(participant: RemoteParticipant,
                                              publication: RemoteVideoTrackPublication) {
        eventSink.send(["type": "participantVideoChanged",
                        "participantSid": participant.sid,
                        "isVideoEnabled": true])
    }

    func remoteParticipantDidDisableVideoTrack(participant: RemoteParticipant,
                                               publication: RemoteVideoTrackPublication) {
        eventSink.send(["type": "participantVideoChanged",
                        "participantSid": participant.sid,
                        "isVideoEnabled": false])
    }

    func remoteParticipantDidEnableAudioTrack(participant: RemoteParticipant,
                                              publication: RemoteAudioTrackPublication) {
        eventSink.send(["type": "participantAudioChanged",
                        "participantSid": participant.sid,
                        "isAudioEnabled": true])
    }

    func remoteParticipantDidDisableAudioTrack(participant: RemoteParticipant,
                                               publication: RemoteAudioTrackPublication) {
        eventSink.send(["type": "participantAudioChanged",
                        "participantSid": participant.sid,
                        "isAudioEnabled": false])
    }

    // Required stubs
    func didSubscribeToVideoTrack(videoTrack: RemoteVideoTrack, publication: RemoteVideoTrackPublication, participant: RemoteParticipant) {}
    func didUnsubscribeFromVideoTrack(videoTrack: RemoteVideoTrack, publication: RemoteVideoTrackPublication, participant: RemoteParticipant) {}
    func didSubscribeToAudioTrack(audioTrack: RemoteAudioTrack, publication: RemoteAudioTrackPublication, participant: RemoteParticipant) {}
    func didUnsubscribeFromAudioTrack(audioTrack: RemoteAudioTrack, publication: RemoteAudioTrackPublication, participant: RemoteParticipant) {}
    func remoteParticipantDidPublishVideoTrack(participant: RemoteParticipant, publication: RemoteVideoTrackPublication) {}
    func remoteParticipantDidUnpublishVideoTrack(participant: RemoteParticipant, publication: RemoteVideoTrackPublication) {}
    func remoteParticipantDidPublishAudioTrack(participant: RemoteParticipant, publication: RemoteAudioTrackPublication) {}
    func remoteParticipantDidUnpublishAudioTrack(participant: RemoteParticipant, publication: RemoteAudioTrackPublication) {}
}

