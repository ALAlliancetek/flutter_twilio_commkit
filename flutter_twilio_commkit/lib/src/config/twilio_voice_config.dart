/// Per-feature configuration for Twilio Voice.
class TwilioVoiceConfig {
  const TwilioVoiceConfig({
    this.enableCallKit = true,
    this.enableForegroundService = true,
    this.callerIdName,
    this.defaultRegion,
    this.enableInsights = true,
    this.ringtoneAssetPath,
    this.callKitIconAssetPath,
    this.notificationIconName,
  });

  /// (iOS) Enable CallKit integration for native call UI.
  final bool enableCallKit;

  /// (Android) Enable foreground service to keep calls alive in background.
  final bool enableForegroundService;

  /// Caller ID display name shown in native call UI (CallKit / Android dialer).
  final String? callerIdName;

  /// Preferred Twilio Voice edge region (e.g. `'ashburn'`, `'sydney'`).
  /// `null` = Twilio auto-selects the nearest region.
  final String? defaultRegion;

  /// Enable Twilio Insights for call quality analytics.
  final bool enableInsights;

  /// Flutter asset path for custom ringtone audio.
  /// e.g. `'assets/audio/ringtone.mp3'`
  final String? ringtoneAssetPath;

  /// Flutter asset path for the icon shown in iOS CallKit UI.
  /// e.g. `'assets/images/call_icon.png'`
  final String? callKitIconAssetPath;

  /// (Android) Name of a drawable resource in the host app to use as the
  /// small icon for incoming-call and active-call notifications.
  ///
  /// The resource must exist in the host app's `res/drawable` or
  /// `res/mipmap` directory. Pass only the resource name without extension.
  ///
  /// Example: if your app has `res/drawable/ic_notification.png`, pass
  /// `'ic_notification'`.
  ///
  /// If null, the SDK falls back to `android.R.drawable.ic_menu_call`.
  final String? notificationIconName;

  Map<String, dynamic> toMap() => {
        'enableCallKit': enableCallKit,
        'enableForegroundService': enableForegroundService,
        if (callerIdName != null) 'callerIdName': callerIdName,
        if (defaultRegion != null) 'defaultRegion': defaultRegion,
        'enableInsights': enableInsights,
        if (ringtoneAssetPath != null) 'ringtoneAssetPath': ringtoneAssetPath,
        if (callKitIconAssetPath != null)
          'callKitIconAssetPath': callKitIconAssetPath,
        if (notificationIconName != null)
          'notificationIconName': notificationIconName,
      };
}

