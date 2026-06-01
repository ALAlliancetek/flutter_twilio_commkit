import Flutter
import UIKit
import PushKit
import flutter_twilio_commkit_ios

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Register for VoIP pushes via PushKit so Twilio can deliver
    // incoming calls even when the app is killed.
    let registry = PKPushRegistry(queue: .main)
    registry.delegate = self
    registry.desiredPushTypes = [.voIP]

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

// MARK: - PKPushRegistryDelegate
extension AppDelegate: PKPushRegistryDelegate {
  func pushRegistry(_ registry: PKPushRegistry,
                    didUpdate pushCredentials: PKPushCredentials,
                    for type: PKPushType) {
    guard type == .voIP else { return }
    // Forward the APNs VoIP device token to the SDK so it can register
    // with Twilio Voice for incoming call pushes.
    FlutterTwilioCommKitIosPlugin.shared?.voicePushRegistry(
      registry,
      didUpdate: pushCredentials,
      for: type
    )
  }

  func pushRegistry(_ registry: PKPushRegistry,
                    didReceiveIncomingPushWith payload: PKPushPayload,
                    for type: PKPushType,
                    completion: @escaping () -> Void) {
    guard type == .voIP else { completion(); return }
    // Forward the push payload to the SDK which will show the CallKit UI.
    FlutterTwilioCommKitIosPlugin.shared?.voicePushRegistry(
      registry,
      didReceiveIncomingPushWith: payload,
      for: type,
      completion: completion
    )
  }
}
