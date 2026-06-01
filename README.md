# flutter_twilio_commkit

[![pub version](https://img.shields.io/pub/v/flutter_twilio_commkit.svg)](https://pub.dev/packages/flutter_twilio_commkit)
[![pub points](https://img.shields.io/pub/points/flutter_twilio_commkit)](https://pub.dev/packages/flutter_twilio_commkit/score)
[![Platform](https://img.shields.io/badge/platform-android%20%7C%20ios-blue.svg)](https://pub.dev/packages/flutter_twilio_commkit)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**Production-grade Flutter SDK for Twilio Voice & Video calling.**

Wrap the official Twilio Android and iOS native SDKs behind a clean, simple Dart API — with a fully customizable built-in UI, headless mode, and a federated plugin architecture designed for enterprise use.

---

## ✨ Features

| Feature | Status |
|---|---|
| 📞 Outgoing & incoming Voice calls | ✅ |
| 🎥 1-to-1 and Group Video calls | ✅ |
| 📲 CallKit integration (iOS) | ✅ |
| 🔔 FCM push for incoming calls (Android) | ✅ |
| 🔔 PushKit/APNs VoIP push (iOS) | ✅ |
| 🎨 5 built-in themes + full custom theming | ✅ |
| 🖼️ Custom participant profile images | ✅ |
| 🔇 Mute, hold, speakerphone, Bluetooth | ✅ |
| 🔢 DTMF dialpad (IVR navigation) | ✅ |
| 🔔 Customizable ringtone | ✅ |
| 📡 Network quality monitoring | ✅ |
| 🔄 Auto-reconnection handling | ✅ |
| 🏗️ Headless (API-only) mode | ✅ |
| 💬 Chat module (placeholder, coming soon) | 🔜 |

---

## 🚀 Quick start

### 1. Add the dependency

```yaml
dependencies:
  flutter_twilio_commkit: ^0.1.0
```

### 2. Initialize

```dart
import 'package:flutter_twilio_commkit/flutter_twilio_commkit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  TwilioCallHandlerService.startListening();

  await TwilioCommKit.initialize(
    config: TwilioCommKitConfig(
      credentials: TwilioCredentials(
        accountSid: 'ACxxxxxxxx',
        apiKeySid:  'SKxxxxxxxx',
        outgoingApplicationSid: 'APxxxxxxxx',
        pushCredentialSid:      'CRxxxxxxxx',
      ),
      accessTokenProvider: () async => await fetchTokenFromYourServer(),
      voiceConfig: TwilioVoiceConfig(callerIdName: 'Alice'),
    ),
  );

  runApp(const ProviderScope(child: MyApp()));
}
```

### 3. Make a voice call

```dart
final call = await TwilioVoice.instance.startCall(to: 'bob');

Navigator.push(context, MaterialPageRoute(
  builder: (_) => TwilioVoiceCallScreen(
    callSid: call.callSid,
    remoteIdentity: 'bob',
    theme: TwilioThemeData.dark(),
    onCallEnded: () => Navigator.pop(context),
  ),
));
```

### 4. Join a video room

```dart
Navigator.push(context, MaterialPageRoute(
  builder: (_) => TwilioVideoCallScreen(
    roomName: 'my-room',
    accessToken: videoToken,
    localIdentity: 'alice',
    theme: TwilioThemeData.videoPurple(),
    onRoomDisconnected: (_) => Navigator.pop(context),
  ),
));
```

### 5. Handle incoming calls automatically

```dart
MaterialApp(
  home: TwilioCallHandler(
    theme: TwilioThemeData.dark(),
    child: MyHomeScreen(),
  ),
)
```

---

## 🎨 Built-in themes

```dart
TwilioThemeData.dark()         // Deep navy (default)
TwilioThemeData.light()        // Clean white/grey
TwilioThemeData.videoCinema()  // Full-black, orange accents
TwilioThemeData.videoPurple()  // Deep purple, gradient incoming screen
TwilioThemeData.videoOcean()   // Ocean blue, cyan accents
```

---

## 📦 Package structure (federated)

| Package | Description |
|---|---|
| `flutter_twilio_commkit` | Main package — public API + UI widgets |
| `flutter_twilio_commkit_platform_interface` | Abstract platform interface |
| `flutter_twilio_commkit_android` | Android native implementation (Kotlin) |
| `flutter_twilio_commkit_ios` | iOS native implementation (Swift) |

---

## 📖 Documentation

- [Integration Guide](docs/integration_guide.md) — full setup walkthrough
- [API Reference](docs/api_reference.md)
- [Customization Guide](docs/customization.md)
- [Installation Guide](docs/installation.md)
- [Token Server](https://github.com/ALAlliancetek/Twilio-Token/blob/main/README.md) — ready-made Node.js backend

---

## 🛠️ Platform setup

### Android

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT"/>

<activity android:name="com.twiliocommkit.android.voice.TwilioIncomingCallActivity"
    android:showWhenLocked="true" android:turnScreenOn="true"
    android:launchMode="singleInstance" android:exported="false"/>

<service android:name="com.twiliocommkit.android.voice.TwilioFcmService"
    android:exported="false">
    <intent-filter>
        <action android:name="com.google.firebase.MESSAGING_EVENT"/>
    </intent-filter>
</service>
```

Minimum SDK: **API 26 (Android 8.0)**

### iOS

In `ios/Podfile`:
```ruby
platform :ios, '14.0'
```

In `ios/Runner/AppDelegate.swift` — add `PKPushRegistryDelegate` for incoming VoIP calls.  
See the full [iOS setup guide](docs/integration_guide.md#6-ios-setup).

Add to `Info.plist`:
```xml
<key>NSMicrophoneUsageDescription</key><string>Required for calls.</string>
<key>NSCameraUsageDescription</key><string>Required for video calls.</string>
```

Enable **Background Modes** capability: `voip`, `audio`, `remote-notification`.

---

## 🎭 Headless mode

Use the raw API without any built-in UI:

```dart
final call = await TwilioVoice.instance.startCall(to: 'bob');

TwilioVoice.instance.onCallStateChanged.listen((event) {
  // drive your own UI
});

TwilioVoice.instance.onCallQualityWarning.listen((event) {
  // handle network quality
});
```

---

## 🔢 DTMF dialpad

A built-in dialpad bottom sheet opens when the user taps **Keypad** on the voice call screen.  
You can also send digits programmatically:

```dart
await TwilioVoice.instance.sendDigits('1');   // IVR navigation
```

---

## 🖼️ Custom participant images

```dart
TwilioVoiceCallScreen(
  remoteIdentity: 'alice',
  resolveParticipantImage: (identity) => myContactBook.imageUrlFor(identity),
  ...
)
```

---

## 🔊 Custom ringtone

```dart
TwilioThemeData(
  ringtonePath: 'audio/ringtone.mp3',  // Flutter asset path (without 'assets/' prefix)
  ringtoneLoop: true,
  ...
)
```

---

## 📋 Requirements

| Platform | Minimum version |
|---|---|
| Android | API 26 (Android 8.0) |
| iOS | iOS 14.0 |
| Flutter | 3.10.0 |
| Dart | 3.0.0 |

---

## ⚠️ Important: Token server required

The SDK **never** generates Twilio tokens on-device. You must run your own token server.  
A ready-made Node.js server is included in `docs/token_server/`.

```bash
cd docs/token_server && npm install && npm start
```

---

## 📄 License

MIT — see [LICENSE](LICENSE)

---

## 🙏 Credits

Built on top of the official [Twilio Video](https://www.twilio.com/docs/video) and [Twilio Voice](https://www.twilio.com/docs/voice/sdks) native SDKs.
