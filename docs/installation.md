# Installation Guide

## Add dependency

```yaml
dependencies:
  flutter_twilio_commkit: ^0.1.0
```

## Android Setup

### 1. Set minimum SDK to 26 in `android/app/build.gradle`:
```groovy
defaultConfig {
    minSdk 26
}
```

### 2. Add permissions to `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_PHONE_CALL" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />

<service
    android:name="com.twiliocommkit.android.voice.TwilioCallForegroundService"
    android:foregroundServiceType="phoneCall"
    android:exported="false" />
```

## iOS Setup

### 1. Set minimum iOS to 14.0 in `Podfile`:
```ruby
platform :ios, '14.0'
```

### 2. Add to `Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>Camera required for video calls.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Microphone required for calls.</string>
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
    <string>voip</string>
    <string>remote-notification</string>
</array>
```

## Initialize

```dart
await TwilioCommKit.initialize(
  config: TwilioCommKitConfig(
    // ── Twilio project credentials (from https://console.twilio.com) ─────────
    credentials: TwilioCredentials(
      accountSid: 'ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', // Account SID
      apiKeySid:  'SKxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', // API Key SID
      outgoingApplicationSid: 'APxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', // TwiML App SID
      pushCredentialSid:      'CRxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', // Push Credential SID
      // apiKeySecret: kept server-side ONLY — never embed in Flutter app
    ),

    // ── Token provider — always fetch from your secure server ────────────────
    accessTokenProvider: () async => await fetchTokenFromServer(),

    // ── Per-feature configuration (optional) ─────────────────────────────────
    videoConfig: const TwilioVideoConfig(
      roomType: TwilioRoomType.group,
      enableNetworkQuality: true,
      preferredVideoCodec: TwilioVideoCodec.vp8,
    ),
    voiceConfig: const TwilioVoiceConfig(
      callerIdName: 'My App',
      enableCallKit: true,           // iOS CallKit
      enableForegroundService: true, // Android background service
      defaultRegion: 'ashburn',      // optional Twilio media region
    ),
    logLevel: TwilioLogLevel.debug,
  ),
);
```

