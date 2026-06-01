import Flutter
import UIKit
import PushKit

/// iOS plugin entry point for flutter_twilio_commkit.
@objc public class FlutterTwilioCommKitIosPlugin: NSObject, FlutterPlugin {

    /// Shared instance — used by AppDelegate to forward PushKit events.
    @objc public static var shared: FlutterTwilioCommKitIosPlugin?

    private var methodChannel: FlutterMethodChannel?
    private var callHandlerChannel: FlutterMethodChannel?
    private var videoEventChannel: FlutterEventChannel?
    private var voiceEventChannel: FlutterEventChannel?

    private let videoEventSink = TwilioEventSink()
    private let voiceEventSink = TwilioEventSink()

    private var videoManager: TwilioVideoManager?
    var voiceManager: TwilioVoiceManager?   // internal — accessed by PushKit forwarding

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = FlutterTwilioCommKitIosPlugin()
        FlutterTwilioCommKitIosPlugin.shared = instance

        instance.methodChannel = FlutterMethodChannel(
            name: "com.twiliocommkit/methods",
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(instance, channel: instance.methodChannel!)

        // Dedicated channel for TwilioCallHandler incoming call results.
        // On Android this comes via an Intent (onNewIntent). On iOS, CallKit fires
        // CXAnswerCallAction and we forward it to Flutter via this same channel.
        instance.callHandlerChannel = FlutterMethodChannel(
            name: "com.twiliocommkit/incoming_call",
            binaryMessenger: registrar.messenger()
        )
        instance.callHandlerChannel?.setMethodCallHandler { call, result in
            if call.method == "getPendingIncomingCall" {
                // iOS: no pending intent — CallKit already handles ringing
                result(nil)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }

        instance.videoEventChannel = FlutterEventChannel(
            name: "com.twiliocommkit/video_events",
            binaryMessenger: registrar.messenger()
        )
        instance.videoEventChannel?.setStreamHandler(instance.videoEventSink)

        instance.voiceEventChannel = FlutterEventChannel(
            name: "com.twiliocommkit/voice_events",
            binaryMessenger: registrar.messenger()
        )
        instance.voiceEventChannel?.setStreamHandler(instance.voiceEventSink)

        instance.videoManager = TwilioVideoManager(eventSink: instance.videoEventSink)
        instance.voiceManager = TwilioVoiceManager(eventSink: instance.voiceEventSink)

        // Wire CallKit answer → Flutter navigation.
        // When the user taps Answer in the native CallKit sheet (lock-screen or notification),
        // we notify Flutter so TwilioCallHandler can navigate to the call screen, exactly like
        // Android does via onNewIntent → invokeMethod("onIncomingCallResult").
        instance.voiceManager?.onCallKitAnswer = { [weak instance] callSid, from in
            DispatchQueue.main.async {
                instance?.callHandlerChannel?.invokeMethod("onIncomingCallResult", arguments: [
                    "accepted": true,
                    "callSid": callSid,
                    "from": from
                ])
            }
        }
    }

    // MARK: - PushKit forwarding (called from AppDelegate)

    /// Forward VoIP device token to TwilioVoice so it can register for
    /// incoming push notifications.
    public func voicePushRegistry(
        _ registry: PKPushRegistry,
        didUpdate pushCredentials: PKPushCredentials,
        for type: PKPushType
    ) {
        voiceManager?.handleDeviceToken(pushCredentials.token)
    }

    /// Forward an incoming VoIP push to TwilioVoice.
    /// **Must** call `completion()` — iOS 13+ requires it or the app is killed.
    public func voicePushRegistry(
        _ registry: PKPushRegistry,
        didReceiveIncomingPushWith payload: PKPushPayload,
        for type: PKPushType,
        completion: @escaping () -> Void
    ) {
        voiceManager?.handleIncomingPush(payload: payload.dictionaryPayload, completion: completion)
    }

    // MARK: - Method Channel

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "initialize":
            let logLevel = args["logLevel"] as? String ?? "none"
            TwilioLogger.configure(level: logLevel)

            if let credMap = args["credentials"] as? [String: Any?] {
                let creds = TwilioSdkCredentials(
                    accountSid: credMap["accountSid"] as? String ?? "",
                    apiKeySid: credMap["apiKeySid"] as? String ?? "",
                    pushCredentialSid: credMap["pushCredentialSid"] as? String,
                    outgoingApplicationSid: credMap["outgoingApplicationSid"] as? String
                )
                TwilioSdkCredentials.current = creds
                TwilioLogger.debug("Credentials configured: accountSid=\(creds.accountSid)")
            }

            if let videoConfigMap = args["videoConfig"] as? [String: Any] {
                videoManager?.applyConfig(videoConfigMap)
            }
            if let voiceConfigMap = args["voiceConfig"] as? [String: Any] {
                voiceManager?.applyConfig(voiceConfigMap)
            }
            result(nil)

        // ── Video ──────────────────────────────────────────────────────────
        case "connectToRoom":     videoManager?.connectToRoom(args: args, result: result)
        case "disconnectFromRoom":videoManager?.disconnectFromRoom(args: args, result: result)
        case "muteVideo":         videoManager?.muteVideo(args: args, result: result)
        case "muteAudio":         videoManager?.muteAudio(args: args, result: result)
        case "switchCamera":      videoManager?.switchCamera(result: result)
        case "getParticipants":   videoManager?.getParticipants(args: args, result: result)

        // ── Voice ──────────────────────────────────────────────────────────
        case "initVoice":         voiceManager?.initVoice(args: args, result: result)
        case "startCall":         voiceManager?.startCall(args: args, result: result)
        case "acceptCall":        voiceManager?.acceptCall(args: args, result: result)
        case "rejectCall":        voiceManager?.rejectCall(args: args, result: result)
        case "hangUpCall":        voiceManager?.hangUpCall(args: args, result: result)
        case "muteCall":          voiceManager?.muteCall(args: args, result: result)
        case "holdCall":          voiceManager?.holdCall(args: args, result: result)
        case "setSpeaker":        voiceManager?.setSpeaker(args: args, result: result)
        case "sendDigits":        voiceManager?.sendDigits(args: args, result: result)
        case "setSpeakerForVideo":videoManager?.setSpeaker(args: args, result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
