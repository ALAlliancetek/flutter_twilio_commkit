import Flutter
import TwilioVoice
import AVFoundation
import CallKit
import PushKit
import UIKit

/// Manages Twilio Voice calls on iOS with CallKit + PushKit integration.
final class TwilioVoiceManager: NSObject {

    private let eventSink: TwilioEventSink
    private var activeCall: Call?
    private var callInvite: CallInvite?
    private let callKitProvider: CXProvider
    private let callKitCallController = CXCallController()
    private var activeCallUUID: UUID?

    // Stored from PushKit registration
    private var voipDeviceToken: Data?

    // Resolved from TwilioVoiceConfig
    private var callerIdName: String?
    private var defaultRegion: String?
    private var enableCallKit: Bool = true
    private var lastAccessToken: String = ""

    // Callback invoked when CallKit Answer action fires so Flutter can open the call screen
    var onCallKitAnswer: ((_ callSid: String, _ from: String) -> Void)?

    init(eventSink: TwilioEventSink) {
        self.eventSink = eventSink

        let configuration = CXProviderConfiguration()
        configuration.maximumCallsPerCallGroup = 1
        configuration.supportsVideo = false
        configuration.supportedHandleTypes = [.phoneNumber, .generic]
        callKitProvider = CXProvider(configuration: configuration)

        super.init()
        callKitProvider.setDelegate(self, queue: nil)
    }

    // MARK: - Config

    func applyConfig(_ config: [String: Any]) {
        enableCallKit = config["enableCallKit"] as? Bool ?? true
        callerIdName = config["callerIdName"] as? String
        defaultRegion = config["defaultRegion"] as? String

        // Apply CallKit icon if provided.
        // callKitIconAssetPath is a Flutter asset path (e.g. "assets/images/call_icon.png").
        // The Flutter tool copies assets into the app bundle so we can load them with UIImage(named:).
        // Strip the leading directory so UIImage can find it by filename.
        if let assetPath = config["callKitIconAssetPath"] as? String {
            let filename = (assetPath as NSString).lastPathComponent
            let nameWithoutExt = (filename as NSString).deletingPathExtension
            if let icon = UIImage(named: nameWithoutExt) ?? UIImage(named: filename) {
                let providerConfig = callKitProvider.configuration
                providerConfig.iconTemplateImageData = icon.pngData()
                callKitProvider.configuration = providerConfig
                TwilioLogger.debug("CallKit icon set from asset: \(assetPath)")
            } else {
                TwilioLogger.warning("CallKit icon not found for asset path: \(assetPath) — using system default")
            }
        }

        TwilioLogger.debug("VoiceManager config: callerIdName=\(callerIdName ?? "nil") region=\(defaultRegion ?? "auto")")
    }

    // MARK: - PushKit

    /// Called by the plugin when PushKit delivers a new VoIP device token.
    /// Registers with Twilio Voice for incoming call pushes.
    func handleDeviceToken(_ token: Data) {
        voipDeviceToken = token
        TwilioLogger.debug("PushKit VoIP device token received, length=\(token.count)")
        // If we already have an access token, register now.
        // Otherwise registration will happen inside initVoice once the token arrives.
        if !lastAccessToken.isEmpty {
            registerWithTwilio(accessToken: lastAccessToken, deviceToken: token)
        }
    }

    /// Called by the plugin when a VoIP push arrives.
    /// **Must** call `completion()` — iOS 13+ terminates the app if not called.
    func handleIncomingPush(payload: [AnyHashable: Any], completion: @escaping () -> Void) {
        TwilioLogger.debug("Incoming VoIP push received")
        TwilioVoiceSDK.handleNotification(payload, delegate: self, delegateQueue: nil)
        // completion() is called after CallKit reports the call — see notificationDelegate below.
        // Store it so we can call it from the delegate callback.
        pendingPushCompletion = completion
    }

    private var pendingPushCompletion: (() -> Void)?

    private func registerWithTwilio(accessToken: String, deviceToken: Data) {
        TwilioVoiceSDK.register(accessToken: accessToken, deviceToken: deviceToken) { error in
            if let error = error {
                TwilioLogger.error("Twilio VoIP registration failed: \(error.localizedDescription)")
            } else {
                TwilioLogger.debug("Twilio VoIP registration successful — incoming calls enabled")
            }
        }
    }

    // MARK: - Public API

    func initVoice(args: [String: Any], result: @escaping FlutterResult) {
        guard let accessToken = args["accessToken"] as? String else {
            result(FlutterError(code: "INVALID_ARG", message: "accessToken required", details: nil))
            return
        }
        lastAccessToken = accessToken
        // Clear stale call state so new call screen starts fresh (mirrors Android fix)
        TwilioLogger.debug("Voice access token stored, length=\(accessToken.count)")

        if let token = voipDeviceToken {
            registerWithTwilio(accessToken: accessToken, deviceToken: token)
        } else {
            TwilioLogger.debug("No VoIP device token yet — registration will happen when PushKit delivers one")
        }

        result(nil)
    }

    func startCall(args: [String: Any], result: @escaping FlutterResult) {
        guard let to = args["to"] as? String else {
            result(FlutterError(code: "INVALID_ARG", message: "to required", details: nil))
            return
        }
        let accessToken: String
        if let t = args["accessToken"] as? String, !t.isEmpty {
            accessToken = t
        } else if !lastAccessToken.isEmpty {
            accessToken = lastAccessToken
        } else {
            result(FlutterError(code: "INVALID_ARG",
                                message: "accessToken is required — pass it in startCall or call initVoice first",
                                details: nil))
            return
        }

        let params = args["params"] as? [String: String] ?? [:]
        var connectParams = params
        connectParams["To"] = to

        let uuid = UUID()
        activeCallUUID = uuid

        let handle = CXHandle(type: .generic, value: to)
        let startAction = CXStartCallAction(call: uuid, handle: handle)
        let transaction = CXTransaction(action: startAction)

        TwilioLogger.debug("startCall to=\(to)")

        callKitCallController.request(transaction) { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                TwilioLogger.error("CXStartCallAction failed: \(error)")
                result(FlutterError(code: "CALL_ERROR", message: error.localizedDescription, details: nil))
                return
            }
            let connectOptions = ConnectOptions(accessToken: accessToken) { builder in
                builder.params = connectParams
                builder.uuid = uuid
            }
            self.activeCall = TwilioVoiceSDK.connect(options: connectOptions, delegate: self)
            result([
                "callSid": self.activeCall?.sid ?? "",
                "state": "connecting",
                "to": to,
                "isMuted": false,
                "isOnHold": false
            ])
        }
    }

    func acceptCall(args: [String: Any], result: @escaping FlutterResult) {
        // On iOS the call is already accepted by CallKit's CXAnswerCallAction handler.
        // Flutter calls this AFTER CallKit has answered — by this point activeCall is set
        // and the call is already connecting. We just confirm success.
        if activeCall != nil {
            TwilioLogger.debug("acceptCall: call already accepted via CallKit — confirming to Flutter")
            result(nil)
            return
        }
        guard let invite = callInvite else {
            result(FlutterError(code: "NO_INVITE", message: "No pending call invite", details: nil))
            return
        }
        let acceptOptions = AcceptOptions(callInvite: invite) { builder in
            builder.uuid = invite.uuid
        }
        activeCall = invite.accept(options: acceptOptions, delegate: self)
        callInvite = nil
        result(nil)
    }

    func rejectCall(args: [String: Any], result: @escaping FlutterResult) {
        callInvite?.reject()
        callInvite = nil
        result(nil)
    }

    func hangUpCall(args: [String: Any], result: @escaping FlutterResult) {
        if let uuid = activeCallUUID {
            let endAction = CXEndCallAction(call: uuid)
            callKitCallController.request(CXTransaction(action: endAction)) { _ in }
        }
        activeCall?.disconnect()
        result(nil)
    }

    func muteCall(args: [String: Any], result: @escaping FlutterResult) {
        let muted = args["muted"] as? Bool ?? false
        activeCall?.isMuted = muted
        result(nil)
    }

    func holdCall(args: [String: Any], result: @escaping FlutterResult) {
        let held = args["held"] as? Bool ?? false
        activeCall?.isOnHold = held
        result(nil)
    }

    func setSpeaker(args: [String: Any], result: @escaping FlutterResult) {
        let enabled = args["enabled"] as? Bool ?? false
        let session = AVAudioSession.sharedInstance()
        do {
            try session.overrideOutputAudioPort(enabled ? .speaker : .none)
            TwilioLogger.debug("Audio routing → \(enabled ? "SPEAKER" : "EARPIECE")")
        } catch {
            TwilioLogger.error("setSpeaker failed: \(error.localizedDescription)")
        }
        result(nil)
    }

    func sendDigits(args: [String: Any], result: @escaping FlutterResult) {
        guard let digits = args["digits"] as? String else {
            result(FlutterError(code: "INVALID_ARG", message: "digits required", details: nil))
            return
        }
        activeCall?.sendDigits(digits)
        TwilioLogger.debug("sendDigits: \(digits)")
        result(nil)
    }

    // MARK: - Private
}

// MARK: - NotificationDelegate (incoming VoIP push → CallKit)
extension TwilioVoiceManager: NotificationDelegate {
    func callInviteReceived(callInvite: CallInvite) {
        TwilioLogger.debug("Incoming call from: \(callInvite.from ?? "Unknown")")
        self.callInvite = callInvite

        // Show native CallKit incoming call UI (with system ringtone)
        let uuid = callInvite.uuid
        let callerName = callInvite.from?.replacingOccurrences(of: "client:", with: "") ?? "Unknown"
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: callerName)
        update.localizedCallerName = callerName
        update.hasVideo = false

        callKitProvider.reportNewIncomingCall(with: uuid, update: update) { [weak self] error in
            if let error = error {
                TwilioLogger.error("CallKit reportNewIncomingCall failed: \(error)")
            }
            // Complete the PushKit push processing — MUST be called on iOS 13+
            self?.pendingPushCompletion?()
            self?.pendingPushCompletion = nil
        }

        // Also emit Flutter event (used by TwilioCallHandler on foreground)
        eventSink.send([
            "type": "callIncoming",
            "callSid": callInvite.callSid,
            "from": callerName,
            "to": ""
        ])
    }

    func cancelledCallInviteReceived(cancelledCallInvite: CancelledCallInvite, error: Error?) {
        TwilioLogger.debug("Call invite cancelled: \(cancelledCallInvite.callSid)")
        callInvite = nil
        eventSink.send([
            "type": "callDisconnected",
            "callSid": cancelledCallInvite.callSid
        ])
    }
}

// MARK: - CallDelegate
extension TwilioVoiceManager: CallDelegate {
    func callDidStartRinging(call: Call) {
        TwilioLogger.debug("Call ringing: \(call.sid ?? "")")
        eventSink.send(["type": "callRinging", "callSid": call.sid ?? ""])
    }

    func callDidConnect(call: Call) {
        TwilioLogger.debug("Call connected: \(call.sid ?? "")")
        activeCall = call
        eventSink.send(["type": "callConnected", "callSid": call.sid ?? ""])
    }

    func callDidFailToConnect(call: Call, error: Error) {
        let nsError = error as NSError
        eventSink.send(["type": "callFailed", "callSid": call.sid ?? "",
                         "message": error.localizedDescription, "code": nsError.code])
    }

    func callDidDisconnect(call: Call, error: Error?) {
        TwilioLogger.debug("Call disconnected: \(call.sid ?? "")")
        eventSink.send(["type": "callDisconnected", "callSid": call.sid ?? ""])
        activeCall = nil
        activeCallUUID = nil
    }

    func callIsReconnecting(call: Call, error: Error) {
        eventSink.send(["type": "callReconnecting", "callSid": call.sid ?? ""])
    }

    func callDidReconnect(call: Call) {
        eventSink.send(["type": "callReconnected", "callSid": call.sid ?? ""])
    }

    func callDidReceiveQualityWarnings(call: Call,
                                       currentWarnings: Set<Call.QualityWarning>,
                                       previousWarnings: Set<Call.QualityWarning>) {
        let labels = currentWarnings.map { "\($0)" }
        TwilioLogger.debug("Call quality warnings: \(labels)")
        eventSink.send([
            "type": "callQualityWarning",
            "callSid": call.sid ?? "",
            "warnings": labels
        ])
    }
}

// MARK: - CXProviderDelegate
extension TwilioVoiceManager: CXProviderDelegate {
    func providerDidReset(_ provider: CXProvider) {
        TwilioVoiceSDK.audioDevice.isEnabled = false
    }

    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        TwilioVoiceSDK.audioDevice.isEnabled = true
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        // User tapped Answer in native CallKit UI
        TwilioVoiceSDK.audioDevice.isEnabled = true

        let pendingInvite = callInvite
        let callSid = pendingInvite?.callSid ?? ""
        let from = pendingInvite?.from?.replacingOccurrences(of: "client:", with: "") ?? "Unknown"

        if let invite = pendingInvite {
            let acceptOptions = AcceptOptions(callInvite: invite) { builder in
                builder.uuid = invite.uuid
            }
            activeCall = invite.accept(options: acceptOptions, delegate: self)
            activeCallUUID = invite.uuid
            callInvite = nil
        }

        action.fulfill()

        // Notify Flutter so TwilioCallHandler can open the call screen.
        // This mirrors Android's onNewIntent → invokeMethod("onIncomingCallResult") path.
        onCallKitAnswer?(callSid, from)
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        activeCall?.disconnect()
        callInvite?.reject()
        callInvite = nil
        activeCallUUID = nil
        TwilioVoiceSDK.audioDevice.isEnabled = false
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        activeCall?.isMuted = action.isMuted
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        activeCall?.isOnHold = action.isOnHold
        action.fulfill()
    }

    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        // CallKit activated the audio session for us — configure category then enable Twilio audio device.
        do {
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .allowBluetoothA2DP])
            try audioSession.overrideOutputAudioPort(.none) // default: earpiece
            TwilioLogger.debug("Audio session activated by CallKit — route: EARPIECE")
        } catch {
            TwilioLogger.error("Audio session setup in didActivate failed: \(error.localizedDescription)")
        }
        TwilioVoiceSDK.audioDevice.isEnabled = true
    }

    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        TwilioVoiceSDK.audioDevice.isEnabled = false
    }
}
