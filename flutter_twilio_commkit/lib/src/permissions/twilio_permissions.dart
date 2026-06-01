/// Permission management placeholder for Twilio CommKit.
///
/// Client apps must request camera/microphone permissions before calling
/// video/voice APIs. This utility provides platform-agnostic helpers.
///
/// For full permission handling, add `permission_handler` to your app's
/// pubspec.yaml (not this SDK to keep dependencies minimal).
library;

/// Required permissions for SDK features.
enum TwilioPermission {
  camera,
  microphone,
  bluetooth,
  notification,
  phoneState,
}

extension TwilioPermissionX on TwilioPermission {
  /// Human-readable name for display in UI.
  String get displayName => switch (this) {
        TwilioPermission.camera => 'Camera',
        TwilioPermission.microphone => 'Microphone',
        TwilioPermission.bluetooth => 'Bluetooth',
        TwilioPermission.notification => 'Notifications',
        TwilioPermission.phoneState => 'Phone',
      };
}

/// Permissions required for video calls.
const kVideoPermissions = [
  TwilioPermission.camera,
  TwilioPermission.microphone,
];

/// Permissions required for voice calls.
const kVoicePermissions = [
  TwilioPermission.microphone,
  TwilioPermission.bluetooth,
];

