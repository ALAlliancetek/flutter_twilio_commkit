# Flutter Twilio CommKit — Integration Guide

> **Package:** `flutter_twilio_commkit`  
> **Supports:** Android 8.0+ (API 26+) · iOS 14+  
> **Flutter:** ≥ 3.10.0 · **Dart:** ≥ 3.0.0

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Twilio Console Setup](#2-twilio-console-setup)
3. [Token Server Setup](#3-token-server-setup)
4. [Add the Package](#4-add-the-package)
5. [Android Setup](#5-android-setup)
6. [iOS Setup](#6-ios-setup)
7. [SDK Initialization (Dart)](#7-sdk-initialization-dart)
8. [Voice Calling](#8-voice-calling)
9. [Video Calling](#9-video-calling)
10. [Incoming Call Handling](#10-incoming-call-handling)
11. [UI Customization & Theming](#11-ui-customization--theming)
12. [Participant Image Resolution](#12-participant-image-resolution)
13. [Ringtone Customization](#13-ringtone-customization)
14. [DTMF Dialpad](#14-dtmf-dialpad)
15. [Headless Mode (Custom UI)](#15-headless-mode-custom-ui)
16. [Permissions](#16-permissions)
17. [Push Notifications for Incoming Calls](#17-push-notifications-for-incoming-calls)
18. [Troubleshooting](#18-troubleshooting)

---

## 1. Prerequisites

Before integrating the SDK make sure you have:

| Requirement | Details |
|---|---|
| Flutter SDK | ≥ 3.10.0 |
| Dart SDK | ≥ 3.0.0 |
| Android Studio / Xcode | Latest stable |
| Twilio Account | [console.twilio.com](https://console.twilio.com) |
| Node.js | ≥ 18 (for the token server) |
| Firebase project | Only required for Android **incoming** calls via FCM push |

---

## 2. Twilio Console Setup

You need the following Twilio resources. Create them once in the [Twilio Console](https://console.twilio.com).

### 2.1 Account SID & Auth Token

Found at **Console → Dashboard**.

```
Account SID:  ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
Auth Token:   (keep secret — only used server-side)
```

### 2.2 API Key & Secret (for token generation)

**Console → Account → API Keys & Tokens → Create API Key**

- Type: **Standard**
- Copy both `SID` (SK…) and `Secret` — the Secret is shown only once.

```
API Key SID:    SKxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
API Key Secret: (store in token server .env only)
```

### 2.3 TwiML Application (for Voice outgoing calls)

**Console → Voice → TwiML Apps → Create**

- Friendly Name: `MyApp Voice`
- Voice Request URL: `https://your-token-server.com/twiml` (or your ngrok URL during development)

```
TwiML App SID:  APxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### 2.4 Push Credential (for incoming Voice calls — Android FCM)

**Console → Voice → Push Credentials → Create**

- Type: **FCM**
- FCM Server Key: from your Firebase project **Project Settings → Cloud Messaging → Server Key**

```
Push Credential SID:  CRxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### 2.5 Push Credential (for incoming Voice calls — iOS APNs)

**Console → Voice → Push Credentials → Create**

- Type: **APN**
- Upload your `.p12` or `.pem` VoIP certificate (from Apple Developer → Certificates)

```
iOS Push Credential SID:  CRxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx  (different from FCM one)
```

---

## 3. Token Server Setup

The SDK **never** generates Twilio tokens on-device. You need a small backend server.

A ready-made Node.js token server is included in this repository:

```
docs/token_server/
├── server.js
├── package.json
├── .env.example
└── README.md
```

### 3.1 Local development

```bash
cd docs/token_server
npm install

# Copy the example and fill in your Twilio credentials
cp .env.example .env
```

Edit `.env`:

```env
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_API_KEY_SID=SKxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_API_KEY_SECRET=your_api_key_secret
TWILIO_TWIML_APP_SID=APxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_PUSH_CREDENTIAL_SID=CRxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

PORT=3000
```

Start the server:

```bash
npm start
# → Listening on http://localhost:3000
```

Expose it to your phone using **ngrok**:

```bash
npx ngrok http 3000
# → https://abc123.ngrok.io
```

Use `https://abc123.ngrok.io` as your server base URL in the app.

### 3.2 Token endpoints

| Method | Path | Description |
|---|---|---|
| GET | `/token/video?identity=alice&room=MyRoom` | Returns a Video access token |
| GET | `/token/voice?identity=alice` | Returns a Voice access token |
| POST | `/twiml` | TwiML response for outgoing Voice calls |

### 3.3 Production deployment

The token server is deploy-ready for [Render](https://render.com) (see `docs/token_server/render.yaml`).  
You can also deploy to Railway, Heroku, AWS Lambda, or any Node.js host.

---

## 4. Add the Package

### 4.1 pubspec.yaml

```yaml
dependencies:
  flutter_twilio_commkit:
    path: ../flutter_twilio_commkit   # local path during development
    # OR once published to pub.dev:
    # flutter_twilio_commkit: ^0.1.0
```

> **Note:** The federated package structure means you only need to add `flutter_twilio_commkit`. The platform packages (`_android`, `_ios`, `_platform_interface`) are pulled in automatically.

For **push notifications** (incoming calls), also add:

```yaml
dependencies:
  firebase_core: ^3.0.0
  firebase_messaging: ^15.0.0
```

Run:

```bash
flutter pub get
```

---

## 5. Android Setup

### 5.1 Minimum SDK version

In `android/app/build.gradle` (or `build.gradle.kts`):

```groovy
android {
    defaultConfig {
        minSdkVersion 26   // Android 8.0 minimum
        targetSdkVersion 34
    }
}
```

### 5.2 AndroidManifest.xml

Open `android/app/src/main/AndroidManifest.xml` and add everything shown below:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <!-- ── Permissions ─────────────────────────────────────────────────── -->
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.CAMERA"/>
    <uses-permission android:name="android.permission.RECORD_AUDIO"/>
    <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS"/>
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
    <uses-permission android:name="android.permission.BLUETOOTH"/>
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_CAMERA"/>
    <!-- Android 13+ notification permission -->
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <!-- Required for waking the screen on incoming call -->
    <uses-permission android:name="android.permission.WAKE_LOCK"/>
    <!-- Required for fullScreenIntent to show over the lock screen (Android 10+) -->
    <uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT"/>

    <application ...>

        <!-- ── Your existing MainActivity ──────────────────────────────── -->
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:taskAffinity="">
            <!-- existing intent filters ... -->

            <!-- Required: lets the SDK navigate back to the app after accept -->
            <intent-filter>
                <action android:name="com.twiliocommkit.INCOMING_CALL"/>
                <category android:name="android.intent.category.DEFAULT"/>
            </intent-filter>
        </activity>

        <!-- ── SDK: Full-screen incoming call screen ────────────────────── -->
        <!--
            Displayed automatically when a Twilio push arrives in any app state
            (foreground / background / killed). No Kotlin code needed.
        -->
        <activity
            android:name="com.twiliocommkit.android.voice.TwilioIncomingCallActivity"
            android:exported="false"
            android:launchMode="singleInstance"
            android:taskAffinity="${applicationId}.call"
            android:showWhenLocked="true"
            android:turnScreenOn="true"
            android:showOnLockScreen="true"
            android:excludeFromRecents="true"/>

        <!-- ── SDK: FCM service for incoming Voice push notifications ────── -->
        <!--
            Handles all Twilio Voice FCM push messages internally.
            No custom Kotlin code needed.
        -->
        <service
            android:name="com.twiliocommkit.android.voice.TwilioFcmService"
            android:exported="false">
            <intent-filter>
                <action android:name="com.google.firebase.MESSAGING_EVENT"/>
            </intent-filter>
        </service>

        <!-- ── Firebase: default notification channel ────────────────────── -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_channel_id"
            android:value="twilio_voice_calls"/>

    </application>
</manifest>
```

### 5.3 Firebase / google-services.json

> Skip this section if you only need **outgoing** Voice calls or Video (no push notifications).

1. Go to [Firebase Console](https://console.firebase.google.com) → your project → **Project Settings → General**
2. Add an **Android app** with your app's package name (e.g. `com.example.myapp`)
3. Download `google-services.json` → place it at `android/app/google-services.json`

In `android/build.gradle` (project-level):

```groovy
buildscript {
    dependencies {
        classpath 'com.google.gms:google-services:4.4.0'
    }
}
```

In `android/app/build.gradle`:

```groovy
apply plugin: 'com.google.gms.google-services'
```

### 5.4 ProGuard (release builds)

The SDK ships with ProGuard rules. No extra configuration is needed.

If you use custom ProGuard and see issues, add to `android/app/proguard-rules.pro`:

```
-keep class com.twilio.** { *; }
-keep class com.twiliocommkit.** { *; }
```

---

## 6. iOS Setup

### 6.1 Minimum deployment target

In `ios/Podfile`:

```ruby
platform :ios, '14.0'
```

Then run:

```bash
cd ios && pod install
```

### 6.2 AppDelegate.swift

Replace (or update) `ios/Runner/AppDelegate.swift` with the following to enable PushKit for **incoming VoIP calls**:

```swift
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

    // Register for VoIP pushes so Twilio can deliver incoming calls
    // even when the app is in the background or killed.
    let registry = PKPushRegistry(queue: .main)
    registry.delegate = self
    registry.desiredPushTypes = [.voIP]

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

// MARK: - PKPushRegistryDelegate
extension AppDelegate: PKPushRegistryDelegate {

  /// Called when APNs issues / refreshes the VoIP device token.
  func pushRegistry(_ registry: PKPushRegistry,
                    didUpdate pushCredentials: PKPushCredentials,
                    for type: PKPushType) {
    guard type == .voIP else { return }
    FlutterTwilioCommKitIosPlugin.shared?.voicePushRegistry(
      registry,
      didUpdate: pushCredentials,
      for: type
    )
  }

  /// Called when an incoming VoIP push arrives.
  /// MUST call completion() — iOS 13+ kills the app if it is not called.
  func pushRegistry(_ registry: PKPushRegistry,
                    didReceiveIncomingPushWith payload: PKPushPayload,
                    for type: PKPushType,
                    completion: @escaping () -> Void) {
    guard type == .voIP else { completion(); return }
    FlutterTwilioCommKitIosPlugin.shared?.voicePushRegistry(
      registry,
      didReceiveIncomingPushWith: payload,
      for: type,
      completion: completion
    )
  }
}
```

> **Objective-C project?** Rename the file to `AppDelegate.m` and use the equivalent ObjC bridging — or migrate to Swift (recommended).

### 6.3 Info.plist capabilities

In Xcode, open `ios/Runner/Info.plist` (or the **Signing & Capabilities** tab) and ensure the following keys are present:

```xml
<!-- Required for microphone access -->
<key>NSMicrophoneUsageDescription</key>
<string>Microphone is needed for voice and video calls.</string>

<!-- Required for camera access (video calls) -->
<key>NSCameraUsageDescription</key>
<string>Camera is needed for video calls.</string>
```

### 6.4 Xcode Capabilities

In **Xcode → Runner → Signing & Capabilities**, add:

| Capability | Notes |
|---|---|
| **Background Modes** | Check: **Voice over IP**, **Audio, AirPlay and Picture in Picture**, **Remote notifications** |
| **Push Notifications** | Required for incoming calls |

Background Modes in `Runner.entitlements`:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>voip</string>
    <string>audio</string>
    <string>remote-notification</string>
</array>
```

### 6.5 APNs VoIP Certificate

1. Go to [Apple Developer → Certificates](https://developer.apple.com/account/resources/certificates/list)
2. Create a **VoIP Services Certificate** for your App ID
3. Download the `.cer` → export as `.p12` with Keychain Access
4. Upload to Twilio Console → **Voice → Push Credentials → (iOS credential)**

---

## 7. SDK Initialization (Dart)

Call `TwilioCommKit.initialize()` once, **before** `runApp()`, in your `main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_twilio_commkit/flutter_twilio_commkit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Register native channel early — critical for killed-app incoming calls
  TwilioCallHandlerService.startListening();

  await TwilioCommKit.initialize(
    config: TwilioCommKitConfig(
      // ── Twilio credentials (from Console) ──────────────────────────────
      credentials: TwilioCredentials(
        accountSid:             'ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
        apiKeySid:              'SKxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
        outgoingApplicationSid: 'APxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', // TwiML App SID
        pushCredentialSid:      'CRxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', // FCM push cred SID
      ),

      // ── Token provider: called by the SDK whenever a fresh token is needed
      accessTokenProvider: () async {
        // Fetch from YOUR token server. Example:
        final response = await http.get(
          Uri.parse('https://your-server.com/token/voice?identity=alice'),
        );
        return jsonDecode(response.body)['token'] as String;
      },

      // ── Optional: Video configuration ──────────────────────────────────
      videoConfig: const TwilioVideoConfig(
        roomType: TwilioRoomType.group,
        enableNetworkQuality: true,
        enableDominantSpeaker: true,
        preferredVideoCodec: TwilioVideoCodec.vp8,
      ),

      // ── Optional: Voice configuration ──────────────────────────────────
      voiceConfig: TwilioVoiceConfig(
        callerIdName: 'alice',          // displayed in CallKit / incoming call screen
        enableCallKit: true,            // iOS: use native CallKit UI
        enableForegroundService: true,  // Android: keep call alive in background
        enableInsights: true,
      ),

      // ── Logging (use .none in production) ──────────────────────────────
      logLevel: TwilioLogLevel.debug,
    ),
  );

  runApp(
    // ProviderScope is required by flutter_riverpod (used internally by the SDK)
    const ProviderScope(child: MyApp()),
  );
}
```

### Config reference

| Parameter | Type | Required | Description |
|---|---|---|---|
| `credentials.accountSid` | `String` | ✅ | Twilio Account SID |
| `credentials.apiKeySid` | `String` | ✅ | API Key SID |
| `credentials.outgoingApplicationSid` | `String` | Voice only | TwiML App SID |
| `credentials.pushCredentialSid` | `String` | Incoming calls | FCM/APNs push credential SID |
| `accessTokenProvider` | `Future<String> Function()` | ✅ | Callback that returns a fresh access token |
| `videoConfig` | `TwilioVideoConfig` | Optional | Video call settings |
| `voiceConfig` | `TwilioVoiceConfig` | Optional | Voice call settings |
| `logLevel` | `TwilioLogLevel` | Optional | `debug`, `warning`, `error`, `none` |

### TwilioVoiceConfig reference

| Parameter | Platform | Description |
|---|---|---|
| `callerIdName` | Both | Name shown in CallKit / Android incoming call screen |
| `enableCallKit` | iOS | Use native CallKit UI (default: `true`) |
| `enableForegroundService` | Android | Keep calls alive in background (default: `true`) |
| `notificationIconName` | Android | Drawable/mipmap resource name for notification icon (see below) |
| `callKitIconAssetPath` | iOS | Flutter asset path for CallKit icon (see below) |
| `defaultRegion` | Both | Twilio edge region, e.g. `'ashburn'` |
| `enableInsights` | Both | Twilio Insights analytics |

---

### Setting a Custom Notification Icon

#### Android — `notificationIconName`

The SDK uses this icon for:
- The **incoming call notification** (status bar + lock screen)
- The **active call foreground service notification** (shown while a call is in progress)

**Step 1** — Add your icon to the host app's resources:

```
android/app/src/main/res/
├── drawable/
│   └── ic_notification.png       ← your custom icon (white silhouette on transparent bg)
├── drawable-hdpi/
│   └── ic_notification.png
├── drawable-xhdpi/
│   └── ic_notification.png
└── drawable-xxhdpi/
    └── ic_notification.png
```

> **Important:** Android notification icons must be a **white silhouette on a transparent background**. Coloured icons show as solid blobs on API 21+.

**Step 2** — Pass the resource name (without extension) to the SDK:

```dart
voiceConfig: TwilioVoiceConfig(
  callerIdName: 'Alice',
  notificationIconName: 'ic_notification',  // ← matches res/drawable/ic_notification.png
),
```

The SDK resolves the resource at runtime: it first searches `drawable`, then `mipmap`, then falls back to the default system call icon.

---

#### iOS — `callKitIconAssetPath`

The SDK uses this as the **CallKit call icon** shown on the lock screen and in the native phone app switcher.

**Requirements:**
- Square PNG, ≤ 40×40 pt, **template image style** (white with transparency)
- Added to Flutter assets

**Step 1** — Add image to your project and register in `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/images/call_icon.png
```

**Step 2** — Pass the asset path to the SDK:

```dart
voiceConfig: TwilioVoiceConfig(
  callerIdName: 'Alice',
  callKitIconAssetPath: 'assets/images/call_icon.png',
),
```

The SDK loads the image with `UIImage(named:)` from the Flutter asset bundle and sets it as `CXProviderConfiguration.iconTemplateImageData`.

---

## 8. Voice Calling

### 8.1 Initialize the Voice SDK

Before making or receiving voice calls, initialize with a **voice access token**:

```dart
// Fetch a voice-specific token from your server
final voiceToken = await myServer.fetchVoiceToken(identity: 'alice');

await TwilioVoice.instance.initialize(
  accessToken: voiceToken,
  fcmToken: fcmToken,   // optional — pass Firebase FCM token for incoming calls
);
```

> **When to call this:** Call `initialize()` once after the user logs in, or lazily before the first call.

### 8.2 Make an outgoing call

```dart
try {
  final call = await TwilioVoice.instance.startCall(
    to: 'bob',                    // Twilio client identity OR E.164 phone number
    params: {'identity': 'alice'} // optional custom params passed to your TwiML
  );

  // Navigate to the built-in call screen
  Navigator.push(context, MaterialPageRoute(
    builder: (_) => TwilioVoiceCallScreen(
      callSid: call.callSid,
      remoteIdentity: 'bob',
      theme: TwilioThemeData.dark(),
      onCallEnded: () => Navigator.pop(context),
    ),
  ));
} on TwilioCallException catch (e) {
  debugPrint('Call failed: ${e.message}');
}
```

### 8.3 Call controls

```dart
// During an active call
await TwilioVoice.instance.mute(muted: true);
await TwilioVoice.instance.mute(muted: false);

await TwilioVoice.instance.setSpeaker(enabled: true);
await TwilioVoice.instance.setSpeaker(enabled: false);

await TwilioVoice.instance.hold(held: true);
await TwilioVoice.instance.hold(held: false);

// Send DTMF digits for IVR navigation (see Section 14 for the built-in dialpad)
await TwilioVoice.instance.sendDigits('1');
await TwilioVoice.instance.sendDigits('*#5');

await TwilioVoice.instance.hangUp();
```

### 8.4 Listen to call state events

```dart
// Call state changes (connecting → ringing → connected → disconnected)
TwilioVoice.instance.onCallStateChanged.listen((event) {
  switch (event.state) {
    case CallState.connecting:
      print('Connecting…');
    case CallState.ringing:
      print('Ringing…');
    case CallState.connected:
      print('Connected — call SID: ${event.callSid}');
    case CallState.disconnected:
      print('Call ended');
    case CallState.reconnecting:
      print('Reconnecting…');
    default:
      break;
  }
});

// Incoming call events (convenience stream)
TwilioVoice.instance.onIncomingCall.listen((event) {
  print('Incoming call from: ${event.from}  SID: ${event.callSid}');
});

// Network quality warnings
TwilioVoice.instance.onCallQualityWarning.listen((event) {
  print('Quality warnings: ${event.warnings}');
});

// All voice events (union of all types)
TwilioVoice.instance.onCallEvent.listen((event) {
  if (event is IncomingCallEvent) print('Incoming from: ${event.from}');
  if (event is CallMutedChangedEvent) print('Muted: ${event.isMuted}');
  if (event is CallHoldChangedEvent) print('On hold: ${event.isOnHold}');
  if (event is VoiceErrorEvent) print('Error: ${event.message}');
});
```

### 8.5 Accessing the connected-at timestamp

The SDK exposes `callConnectedAt` so both caller and callee display the same elapsed duration, even if one screen mounts slightly after the other:

```dart
final connectedAt = TwilioVoice.instance.callConnectedAt;
if (connectedAt != null) {
  final elapsed = DateTime.now().difference(connectedAt);
  print('Call running for ${elapsed.inSeconds}s');
}
```

> This is used internally by `TwilioVoiceCallScreen`. You only need it when building a fully custom call screen.

---

## 9. Video Calling

### 9.1 Join a video room

```dart
// Fetch a video-specific token from your server
final videoToken = await myServer.fetchVideoToken(
  identity: 'alice',
  roomName: 'my-room',
);

final room = await TwilioVideo.instance.connect(
  roomName: 'my-room',
  accessToken: videoToken,
);

// Navigate to the built-in video call screen
Navigator.push(context, MaterialPageRoute(
  builder: (_) => TwilioVideoCallScreen(
    roomName: 'my-room',
    accessToken: videoToken,
    localIdentity: 'alice',         // shown in participant list as "You"
    theme: TwilioThemeData.dark(),
    onRoomConnected: () => print('Room connected'),
    onRoomDisconnected: (reason) => Navigator.pop(context),
  ),
));
```

### 9.2 TwilioVideoCallScreen parameters

| Parameter | Type | Description |
|---|---|---|
| `roomName` | `String` | ✅ Name of the Twilio Video room |
| `accessToken` | `String` | ✅ Video access token |
| `localIdentity` | `String` | Identity string for the local user (shown in the participant row). Defaults to `''` |
| `theme` | `TwilioThemeData?` | Optional visual theme override |
| `onRoomConnected` | `VoidCallback?` | Fired when the room connects successfully |
| `onRoomDisconnected` | `void Function(String? reason)?` | Fired when the room disconnects |
| `controlsBuilder` | `Widget Function(context, state)?` | Override the default controls bar entirely |
| `participantBuilder` | `Widget Function(context, participant)?` | Override individual participant tiles |
| `enableVideo` | `bool` | Start with camera on/off (default: `true`) |
| `enableAudio` | `bool` | Start with mic on/off (default: `true`) |
| `resolveParticipantImage` | `String? Function(String identity)?` | Callback for remote participant avatars (see [Section 12](#12-participant-image-resolution)) |

### 9.3 Adaptive layout behaviour

The screen automatically adapts its layout based on the number of remote participants (mirrors WhatsApp / Teams behaviour):

| Remote participants | Layout |
|---|---|
| 0 | Waiting screen + local preview full-screen |
| 1 | Remote video fills screen; local is a draggable PIP corner tile |
| 2 | Equal vertical split (50 / 50) |
| 3 | 1 large tile on top, 2 equal tiles below |
| 4+ | Responsive 2-column grid; local stays as a floating draggable PIP tile |

The local preview PIP is **draggable** — the user can move it to any corner of the screen.

### 9.4 Video controls during a call

```dart
await TwilioVideo.instance.muteAudio(muted: true);
await TwilioVideo.instance.muteVideo(muted: true);
await TwilioVideo.instance.switchCamera();
await TwilioVideo.instance.disconnect();
```

### 9.5 Room events

```dart
TwilioVideo.instance.onRoomEvent.listen((event) {
  if (event is ParticipantConnectedEvent) {
    print('${event.participant.identity} joined');
  }
  if (event is ParticipantDisconnectedEvent) {
    print('${event.participant.identity} left');
  }
  if (event is RoomDisconnectedEvent) {
    print('Room disconnected: ${event.reason}');
  }
});
```

### 9.6 Custom controls builder

Override the entire controls bar while keeping the SDK layout logic:

```dart
TwilioVideoCallScreen(
  roomName: 'my-room',
  accessToken: token,
  controlsBuilder: (context, state) {
    return Row(
      children: [
        IconButton(
          icon: Icon(state.isAudioMuted ? Icons.mic_off : Icons.mic),
          onPressed: () =>
              TwilioVideo.instance.muteAudio(muted: !state.isAudioMuted),
        ),
        IconButton(
          icon: const Icon(Icons.call_end, color: Colors.red),
          onPressed: () => TwilioVideo.instance.disconnect(),
        ),
      ],
    );
  },
)
```

---

## 10. Incoming Call Handling

The `TwilioCallHandler` widget handles **all** incoming call scenarios automatically:

- App **foreground** → native `TwilioIncomingCallActivity` (Android) / CallKit (iOS) shows
- App **background** → FCM/PushKit notification triggers the full-screen native UI
- App **killed** → full-screen Activity/CallKit launches the app → `TwilioCallHandler` detects the pending call result

### 10.1 Wrap your home screen

```dart
MaterialApp(
  home: TwilioCallHandler(
    theme: TwilioThemeData.dark(),    // optional: theme for the built-in call screen
    child: MyHomeScreen(),
  ),
)
```

That's all. The SDK handles accept/reject, navigation to `TwilioVoiceCallScreen`, and cleanup automatically.

### 10.2 Custom accept flow (headless mode)

```dart
TwilioCallHandler(
  child: MyHomeScreen(),

  // Override accept: handle navigation yourself
  onAcceptCall: (callSid, from) async {
    // IMPORTANT: navigate FIRST, then accept (see note below)
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => MyCustomCallScreen(callSid: callSid, from: from),
    ));
    await Future.delayed(const Duration(milliseconds: 150));
    await TwilioVoice.instance.acceptCall(callSid: callSid);
  },

  // Override reject
  onRejectCall: (callSid) async {
    await TwilioVoice.instance.rejectCall(callSid: callSid);
  },
)
```

> **Navigate before accept:** Always navigate to the call screen **before** calling `acceptCall()`. This ensures the screen's `onCallStateChanged` subscription is active before the `callConnected` event fires — preventing the status from being stuck at "Connecting…".

### 10.3 Register `TwilioCallHandlerService` in main (recommended)

Call this once during app startup so the native channel is registered before any incoming call arrives:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  TwilioCallHandlerService.startListening(); // register the method channel early
  // ...rest of init
  runApp(const ProviderScope(child: MyApp()));
}
```

> `TwilioCallHandler` widget also calls `startListening()` — but calling it in `main()` ensures it's registered even before the widget tree is built, which is critical for the killed-app scenario.

---

## 11. UI Customization & Theming

### 11.1 Provide a theme globally

Wrap your app (or a subtree) with `TwilioTheme`:

```dart
TwilioTheme(
  data: TwilioThemeData.dark(),   // or .light() or custom
  child: MaterialApp(...)
)
```

### 11.2 Built-in theme presets

The SDK ships five ready-to-use presets:

| Preset | Description |
|---|---|
| `TwilioThemeData.dark()` | Deep navy dark theme (default) |
| `TwilioThemeData.light()` | Clean white/grey light theme |
| `TwilioThemeData.videoCinema()` | Full-black cinema style, orange accents |
| `TwilioThemeData.videoPurple()` | Deep purple with green/red accents + gradient incoming screen |
| `TwilioThemeData.videoOcean()` | Deep ocean blue with cyan accents |

```dart
// Use a preset directly
TwilioVideoCallScreen(
  roomName: 'my-room',
  accessToken: token,
  theme: TwilioThemeData.videoPurple(),
)
```

### 11.3 Create a fully custom theme

```dart
final myTheme = TwilioThemeData(
  // ── Core colours ──────────────────────────────────────────────────────
  backgroundColor: const Color(0xFF0D0020),
  controlBarColor: const Color(0xFF1A0040),
  controlIconColor: Colors.white,
  controlIconActiveColor: Colors.purpleAccent,
  participantNameColor: Colors.white,
  networkQualityGoodColor: const Color(0xFF69F0AE),
  networkQualityPoorColor: const Color(0xFFFF5252),

  // ── Avatar ────────────────────────────────────────────────────────────
  avatarRadius: 56,
  avatarBackgroundColor: const Color(0xFF3D0060),
  avatarIcon: Icons.person,
  // avatarWidget: MyCustomAvatarWidget(),    // fully replace with your own widget

  // ── Typography ────────────────────────────────────────────────────────
  callerNameStyle: const TextStyle(
    fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
  callStatusStyle: TextStyle(
    fontSize: 15, color: Colors.white.withOpacity(0.65)),
  callDurationStyle: const TextStyle(
    fontSize: 16, color: Colors.greenAccent, fontFamily: 'monospace'),
  buttonLabelStyle: const TextStyle(
    fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w500),
  participantNameStyle: const TextStyle(
    fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),

  // ── Call button styles ─────────────────────────────────────────────────
  muteButtonStyle: TwilioCallButtonStyle(
    backgroundColor: Colors.white12,
    iconColor: Colors.white70,
    size: 60, iconSize: 28,
  ),
  speakerButtonStyle: TwilioCallButtonStyle(
    backgroundColor: Colors.white12,
    iconColor: Colors.white70,
    size: 60, iconSize: 28,
  ),
  endCallButtonStyle: const TwilioCallButtonStyle(
    backgroundColor: Color(0xFFCC0000),
    iconColor: Colors.white,
    size: 72, iconSize: 32,
  ),
  videoButtonStyle: TwilioCallButtonStyle(
    backgroundColor: Colors.white12,
    iconColor: Colors.white70,
    size: 60, iconSize: 28,
  ),
  flipCameraButtonStyle: TwilioCallButtonStyle(
    backgroundColor: Colors.white12,
    iconColor: Colors.white70,
    size: 60, iconSize: 28,
  ),
  acceptButtonStyle: const TwilioCallButtonStyle(
    backgroundColor: Color(0xFF1B8C1B),
    iconColor: Colors.white,
    size: 72, iconSize: 34,
  ),
  rejectButtonStyle: const TwilioCallButtonStyle(
    backgroundColor: Color(0xFFCC0000),
    iconColor: Colors.white,
    size: 72, iconSize: 34,
  ),

  // ── Incoming call ──────────────────────────────────────────────────────
  incomingBackgroundGradient: const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1A0040), Color(0xFF0D0020)],
  ),
  ringtonePath: 'audio/ringtone.mp3',  // see Section 13
  ringtoneLoop: true,

  // ── Video-specific ────────────────────────────────────────────────────
  videoBackgroundColor: const Color(0xFF0D0020),
  participantTileRadius: 16,
  dominantSpeakerBorderColor: Colors.purpleAccent,
  dominantSpeakerBorderWidth: 2.5,
  pipBorderRadius: 16,
  pipWidth: 100, pipHeight: 140,
  controlBarBlur: true,          // glassmorphism effect on control bar
  controlBarBorderRadius: 24,
);
```

### 11.4 TwilioThemeData full parameter reference

#### Core colours
| Parameter | Type | Default | Description |
|---|---|---|---|
| `backgroundColor` | `Color` | ✅ required | Screen/widget background |
| `controlBarColor` | `Color` | ✅ required | Control bar background |
| `controlIconColor` | `Color` | ✅ required | Default icon colour |
| `controlIconActiveColor` | `Color` | ✅ required | Active/toggled icon colour |
| `participantNameColor` | `Color` | ✅ required | All text label colour |
| `networkQualityGoodColor` | `Color` | ✅ required | Good network quality indicator |
| `networkQualityPoorColor` | `Color` | ✅ required | Poor network quality indicator |

#### Avatar
| Parameter | Type | Default | Description |
|---|---|---|---|
| `avatarWidget` | `Widget?` | `null` | Fully replace the default avatar circle |
| `avatarRadius` | `double` | `56.0` | Avatar circle radius |
| `avatarBackgroundColor` | `Color?` | auto-derived | Avatar background fill |
| `avatarIcon` | `IconData` | `Icons.person` | Fallback icon inside avatar |
| `avatarIconColor` | `Color?` | `null` | Avatar icon colour |

#### Typography
| Parameter | Type | Description |
|---|---|---|
| `callerNameStyle` | `TextStyle?` | Caller/identity name (voice + incoming screens) |
| `callStatusStyle` | `TextStyle?` | Status label (Connecting…, Ringing…, etc.) |
| `callDurationStyle` | `TextStyle?` | Call timer label |
| `buttonLabelStyle` | `TextStyle?` | Labels below control buttons |
| `participantNameStyle` | `TextStyle?` | Participant name overlay on video tiles |

#### Button styles (`TwilioCallButtonStyle?`)
| Parameter | Description |
|---|---|
| `muteButtonStyle` | Mute / unmute button |
| `speakerButtonStyle` | Speaker / earpiece toggle |
| `endCallButtonStyle` | Hang-up / end call button |
| `videoButtonStyle` | Camera on/off button |
| `flipCameraButtonStyle` | Switch camera button |
| `holdButtonStyle` | Hold / resume button |
| `acceptButtonStyle` | Accept button (incoming call screen) |
| `rejectButtonStyle` | Decline button (incoming call screen) |

`TwilioCallButtonStyle` fields:

| Field | Type | Default | Description |
|---|---|---|---|
| `backgroundColor` | `Color?` | `null` | Button background |
| `iconColor` | `Color?` | `null` | Icon colour |
| `size` | `double` | `64.0` | Circle diameter (dp) |
| `iconSize` | `double` | `28.0` | Icon size (dp) |
| `border` | `BoxBorder?` | `null` | Optional border |
| `elevation` | `double` | `0` | Drop shadow elevation |
| `shape` | `ShapeBorder?` | `null` | Full shape override |

#### Incoming call
| Parameter | Type | Default | Description |
|---|---|---|---|
| `incomingBackgroundGradient` | `Gradient?` | `null` | Gradient overlay for the incoming call screen (overrides `backgroundColor`) |
| `ringtonePath` | `String?` | `null` | Flutter asset path for ringtone (see [Section 13](#13-ringtone-customization)) |
| `ringtoneLoop` | `bool` | `true` | Loop until dismissed; false = play once |

#### Video
| Parameter | Type | Default | Description |
|---|---|---|---|
| `videoBackgroundColor` | `Color?` | `null` | Video tile background (defaults to `backgroundColor`) |
| `controlBarBlur` | `bool` | `false` | Glassmorphism blur behind control bar |
| `controlBarBorderRadius` | `double` | `16.0` | Control bar corner radius |
| `participantTileRadius` | `double` | `12.0` | Participant tile corner radius |
| `participantTileBorderColor` | `Color?` | `null` | Tile border colour |
| `participantTileBorderWidth` | `double` | `0.0` | Tile border width |
| `dominantSpeakerBorderColor` | `Color?` | `networkQualityGoodColor` | Active-speaker highlight colour |
| `dominantSpeakerBorderWidth` | `double` | `2.5` | Active-speaker border width |
| `pipBorderColor` | `Color?` | `white30` | Local preview PIP border colour |
| `pipBorderWidth` | `double` | `1.5` | Local preview PIP border width |
| `pipBorderRadius` | `double` | `12.0` | Local preview PIP corner radius |
| `pipWidth` | `double` | `100.0` | Local preview PIP width (dp) |
| `pipHeight` | `double` | `140.0` | Local preview PIP height (dp) |
| `tileSeparatorColor` | `Color?` | `Colors.black` | Gap colour between participant tiles |
| `videoMutedTileColor` | `Color?` | `Colors.black87` | Background for camera-off tiles |

### 11.5 Pass theme to individual screens

```dart
TwilioVoiceCallScreen(
  callSid: call.callSid,
  remoteIdentity: 'bob',
  theme: myTheme,
  onCallEnded: () => Navigator.pop(context),
)

TwilioIncomingCallScreen(
  callSid: callSid,
  from: 'alice',
  theme: myTheme,
)

TwilioVideoCallScreen(
  roomName: 'my-room',
  accessToken: token,
  theme: myTheme,
  onRoomDisconnected: (_) => Navigator.pop(context),
)
```

---

## 12. Participant Image Resolution

By default the SDK generates a deterministic avatar from the participant's identity string. When remote participants have set a profile picture in your app's user directory, use the `resolveParticipantImage` callback to supply the correct URL.

```dart
// Your contact store / user service
String? _resolveImage(String identity) {
  // Return a URL, or null to fall back to the default pravatar
  return myContacts[identity]?.profileImageUrl;
}
```

Pass the callback to any call screen widget:

```dart
// Voice call screen — resolves avatar for the remote participant
TwilioVoiceCallScreen(
  callSid: call.callSid,
  remoteIdentity: 'alice',
  resolveParticipantImage: _resolveImage,
  onCallEnded: () => Navigator.pop(context),
)

// Incoming call screen — resolves avatar for the caller
TwilioIncomingCallScreen(
  callSid: callSid,
  from: 'alice',
  resolveParticipantImage: _resolveImage,
)

// Video call screen — callback is invoked for every participant tile
TwilioVideoCallScreen(
  roomName: 'my-room',
  accessToken: token,
  resolveParticipantImage: _resolveImage,
  onRoomDisconnected: (_) => Navigator.pop(context),
)
```

**Behaviour:**
- If the callback is `null` or returns `null`, the SDK falls back to a deterministic pravatar URL generated from the identity string.
- If the callback returns a non-null URL, `TwilioAvatar` loads it in a circular crop.
- If the image fails to load (network error, 404, etc.), the widget falls back to the generated pravatar automatically.

> **Performance:** The callback is called per-identity, per-render. Keep it a fast O(1) map lookup. Do **not** perform async work inside the callback — pre-fetch and cache URLs in your contact store.

---

## 13. Ringtone Customization

`TwilioIncomingCallScreen` plays a ringtone using the [`audioplayers`](https://pub.dev/packages/audioplayers) package. Configure it via `TwilioThemeData`.

### 13.1 Add your ringtone asset

Place your audio file in the project and register it in `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/audio/ringtone.mp3
```

Supported formats: `.mp3`, `.ogg`, `.wav`, `.aac`

### 13.2 Configure in theme

```dart
final myTheme = TwilioThemeData(
  // ... other theme params
  // Pass the path WITHOUT the leading 'assets/' prefix
  ringtonePath: 'audio/ringtone.mp3',
  ringtoneLoop: true,   // true = loop until dismissed; false = play once
);

TwilioIncomingCallScreen(
  callSid: callSid,
  from: 'alice',
  theme: myTheme,
)
```

> **Path format:** `AssetSource` (used internally) expects the path relative to the `assets/` folder. If you register `assets/audio/ringtone.mp3` in pubspec, pass `'audio/ringtone.mp3'` as `ringtonePath`.

### 13.3 Audio routing

The SDK routes ringtone audio through the OS **ring/notification** stream (not the call/media stream), so it is audible even when the earpiece is active, and respects the device's ringer mode.

### 13.4 Disable ringtone

Omit `ringtonePath` (or set it to `null`) to display the incoming call UI silently:

```dart
TwilioThemeData(
  ringtonePath: null,  // no ringtone
  // ...
)
```

---

## 14. DTMF Dialpad

`TwilioVoiceCallScreen` includes a built-in DTMF dialpad for IVR navigation. It appears automatically once the call is **connected**.

### 14.1 Built-in dialpad

No setup required. While on an active call, tap the **Keypad** button at the bottom of the screen to open a bottom sheet with a full 12-key pad (0–9, `*`, `#`). Typed digits are:

- Sent in real-time via `TwilioVoice.instance.sendDigits()`
- Displayed inside the dialpad sheet for confirmation
- Also shown on the main call screen below the Keypad button

### 14.2 Send DTMF programmatically

```dart
// Single digit
await TwilioVoice.instance.sendDigits('1');

// Multiple digits (multi-level IVR)
await TwilioVoice.instance.sendDigits('5#');
await TwilioVoice.instance.sendDigits('*123');
```

### 14.3 Custom IVR buttons (headless)

```dart
// Custom button that selects an IVR option
ElevatedButton(
  onPressed: () => TwilioVoice.instance.sendDigits('1'),
  child: const Text('Press 1 for Sales'),
)
```

---

## 15. Headless Mode (Custom UI)

Use the SDK APIs directly without any built-in UI:

```dart
// Voice — pure API, no UI
final call = await TwilioVoice.instance.startCall(to: 'bob');

TwilioVoice.instance.onCallStateChanged.listen((event) {
  // update your own UI
});

// Video — pure API, no UI
final room = await TwilioVideo.instance.connect(
  roomName: 'room',
  accessToken: token,
);

TwilioVideo.instance.onRoomEvent.listen((event) {
  // update your own UI
});
```

You can still use individual SDK widgets:

```dart
// Render a remote participant's video track
TwilioVideoView(
  participantIdentity: 'bob',
  roomName: 'my-room',
)

// Local camera preview
TwilioVideoPreview()

// Reusable call control bar
TwilioCallControls(
  isMuted: _isMuted,
  isSpeakerOn: _isSpeakerOn,
  onMute: _toggleMute,
  onSpeaker: _toggleSpeaker,
  onHangUp: _hangUp,
)
```

---

## 16. Permissions

### 16.1 Request permissions at runtime

```dart
import 'package:flutter_twilio_commkit/flutter_twilio_commkit.dart';

// Request microphone + camera before a call
final granted = await TwilioPermissions.requestCallPermissions();
if (!granted) {
  // Show explanation to the user
}

// Or request individually
await TwilioPermissions.requestMicrophone();
await TwilioPermissions.requestCamera();
```

### 16.2 Android 13+ notification permission

On Android 13 (API 33+) you must request `POST_NOTIFICATIONS` at runtime for FCM to show incoming call notifications:

```dart
import 'package:permission_handler/permission_handler.dart';

await Permission.notification.request();
```

---

## 17. Push Notifications for Incoming Calls

### Android (FCM)

1. Complete [Section 5.3](#53-firebase--google-servicesjson) to set up Firebase
2. Pass the FCM token when initializing Voice:

```dart
import 'package:firebase_messaging/firebase_messaging.dart';

final fcmToken = await FirebaseMessaging.instance.getToken();

await TwilioVoice.instance.initialize(
  accessToken: voiceToken,
  fcmToken: fcmToken,   // ← registers device with Twilio for incoming call pushes
);
```

3. The `TwilioFcmService` (declared in your manifest) handles all incoming Twilio push messages automatically. No additional code is needed.

### iOS (PushKit / APNs)

1. Complete [Section 6.2](#62-appdelegateswift) — PushKit is set up in `AppDelegate.swift`
2. The SDK registers the APNs VoIP token with Twilio automatically when `initVoice` is called
3. Incoming calls arrive via PushKit → SDK shows the native CallKit incoming call UI

> **No FCM token is needed on iOS** — Twilio uses APNs/PushKit directly.

---

## 18. Troubleshooting

### ❌ "No access token available"

`TwilioVoice.instance.initialize()` was not called before `startCall()`, **or** the `accessTokenProvider` threw an error.

**Fix:** Always call `initialize()` with a valid token before any call operations.

---

### ❌ Incoming call not showing on Android

**Check:**
1. `google-services.json` is present at `android/app/google-services.json`
2. FCM token was passed to `TwilioVoice.instance.initialize(fcmToken: ...)`
3. `TwilioFcmService` is declared in `AndroidManifest.xml`
4. `TwilioIncomingCallActivity` is declared in `AndroidManifest.xml`
5. `USE_FULL_SCREEN_INTENT` permission is in your manifest
6. On Android 14+: go to **Settings → Apps → Your App → Notifications** and ensure "Full Screen Intents" is allowed

---

### ❌ Incoming call not showing on iOS

**Check:**
1. `AppDelegate.swift` includes `PKPushRegistryDelegate` and forwards to `FlutterTwilioCommKitIosPlugin.shared`
2. Background Modes capability includes **Voice over IP**
3. Push Notifications capability is enabled
4. iOS push credential (APNs) is correctly configured in Twilio Console
5. You're testing on a **real device** — the iOS Simulator does not support PushKit

---

### ❌ No audio on iOS during a call

**Check:**
1. `NSMicrophoneUsageDescription` is set in `Info.plist`
2. Microphone permission was granted at runtime
3. Do NOT call `AVAudioSession.setActive(true)` yourself — the SDK manages audio session via CallKit's `didActivate` delegate

---

### ❌ Call activity shows only after unlocking (Android)

**Check:**
1. `android:showWhenLocked="true"` and `android:turnScreenOn="true"` are set on `TwilioIncomingCallActivity` in your manifest
2. `android.permission.USE_FULL_SCREEN_INTENT` permission is declared
3. `android.permission.WAKE_LOCK` permission is declared
4. On Android 14+: **Settings → Apps → Your App → Permissions** → check "Display over other apps" / "Full Screen Intents"

---

### ❌ Call timer shows wrong elapsed time / starts instantly

The SDK handles this automatically using the shared `callConnectedAt` timestamp. Both the caller's and callee's call screens seed their timers from `TwilioVoice.instance.callConnectedAt` so elapsed time is consistent across devices regardless of when each screen mounts.

Ensure you are on SDK version **≥ 0.1.0** with the latest fixes applied.

---

### ❌ One side ends the call but the other screen doesn't close

**Check:**
1. `TwilioCallHandler` wraps your home screen (not just the call screen)
2. `TwilioVoice.instance.initialize()` was called for the **callee** before navigating to the call screen (done automatically by `TwilioCallHandler`)
3. Both devices are on the same Twilio account and connected to the internet

---

### ❌ Call screen status stuck at "Connecting…" after incoming accept

This happens when `acceptCall()` is called **before** the call screen is mounted and its `onCallStateChanged` subscription is active.

**Fix:** `TwilioCallHandler` already handles this with a navigate-first pattern. If implementing a custom `onAcceptCall`, always navigate before accepting:

```dart
onAcceptCall: (callSid, from) async {
  // 1. Navigate first — screen subscribes to events
  Navigator.push(context, MaterialPageRoute(
    builder: (_) => MyCallScreen(callSid: callSid),
  ));
  // 2. Brief delay ensures subscription is active, then accept
  await Future.delayed(const Duration(milliseconds: 150));
  await TwilioVoice.instance.acceptCall(callSid: callSid);
},
```

---

### ❌ Ringtone not playing on incoming call screen

**Check:**
1. `ringtonePath` is set in `TwilioThemeData` using the path **without** the `'assets/'` prefix (e.g. `'audio/ringtone.mp3'` not `'assets/audio/ringtone.mp3'`)
2. The asset is declared in `pubspec.yaml` under `flutter: assets:`
3. The file format is supported (`.mp3`, `.ogg`, `.wav`, `.aac`)
4. Device volume is not set to zero or silent

---

### 📋 Checklist before testing

```
Android:
  ☐ minSdkVersion = 26
  ☐ google-services.json added
  ☐ All permissions in AndroidManifest.xml
  ☐ TwilioIncomingCallActivity declared with showWhenLocked + turnScreenOn
  ☐ TwilioFcmService declared
  ☐ FCM token passed to TwilioVoice.instance.initialize()

iOS:
  ☐ Deployment target = 14.0
  ☐ AppDelegate.swift has PKPushRegistryDelegate
  ☐ Background Modes: voip + audio + remote-notification
  ☐ Push Notifications capability enabled
  ☐ NSMicrophoneUsageDescription + NSCameraUsageDescription in Info.plist
  ☐ Testing on real device (not simulator)

Both:
  ☐ Token server running and reachable
  ☐ TwilioCommKit.initialize() called in main() before runApp()
  ☐ TwilioCallHandlerService.startListening() called in main() (before runApp)
  ☐ TwilioCallHandler wraps home screen
  ☐ TwilioVoice.instance.initialize() called before startCall()
  ☐ ProviderScope wraps the app (required by Riverpod)
  ☐ resolveParticipantImage wired up if using custom profile images
  ☐ ringtonePath set correctly (without 'assets/' prefix) if using custom ringtone
```

---

## Full minimal example

```dart
// main.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_twilio_commkit/flutter_twilio_commkit.dart';
import 'package:http/http.dart' as http;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Register native channel early — critical for killed-app incoming calls
  TwilioCallHandlerService.startListening();

  await TwilioCommKit.initialize(
    config: TwilioCommKitConfig(
      credentials: TwilioCredentials(
        accountSid: 'ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
        apiKeySid:  'SKxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
        outgoingApplicationSid: 'APxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
        pushCredentialSid:      'CRxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
      ),
      accessTokenProvider: () async {
        final res = await http.get(
          Uri.parse('https://your-server.com/token/voice?identity=alice'),
        );
        return jsonDecode(res.body)['token'] as String;
      },
      voiceConfig: TwilioVoiceConfig(callerIdName: 'alice'),
      logLevel: TwilioLogLevel.debug,
    ),
  );

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: TwilioCallHandler(               // ← handles ALL incoming call states
        theme: TwilioThemeData.dark(),
        child: const HomeScreen(),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // Example contact store — replace with your own user directory
  static const _contacts = {
    'bob': 'https://example.com/avatars/bob.jpg',
  };

  String? _resolveImage(String identity) => _contacts[identity];

  Future<void> _call(BuildContext context) async {
    final token = await http.get(
      Uri.parse('https://your-server.com/token/voice?identity=alice'),
    ).then((r) => jsonDecode(r.body)['token'] as String);

    await TwilioVoice.instance.initialize(accessToken: token);

    final call = await TwilioVoice.instance.startCall(to: 'bob');

    if (context.mounted) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => TwilioVoiceCallScreen(
          callSid: call.callSid,
          remoteIdentity: 'bob',
          theme: TwilioThemeData.dark(),
          resolveParticipantImage: _resolveImage,   // ← custom profile image
          onCallEnded: () => Navigator.pop(context),
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My App')),
      body: Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.call),
          label: const Text('Call Bob'),
          onPressed: () => _call(context),
        ),
      ),
    );
  }
}
```

---

*For advanced usage, theming examples, and the full API reference see [`docs/api_reference.md`](./api_reference.md) and [`docs/customization.md`](./customization.md).*

