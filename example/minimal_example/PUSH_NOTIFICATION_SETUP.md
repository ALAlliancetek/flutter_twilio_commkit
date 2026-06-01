# Push Notification Setup Guide

## Overview

Incoming Twilio Voice calls use **Firebase Cloud Messaging (FCM)** to wake up
the app even when it is killed / in background.

```
Caller Device          Token Server           Twilio Cloud           Callee Device
    │                       │                      │                      │
    │──startCall(to)────────▶                      │                      │
    │                       │──VoiceGrant(TwiML)   │                      │
    │                       └──────────────────────▶                      │
    │                                              │──FCM push ───────────▶
    │                                              │   (call invite)      │
    │                                              │               FirebaseMessagingService.kt
    │                                              │               TwilioVoiceNotificationHandler
    │                                              │               → shows heads-up notification
    │                                              │               → user taps → accept call
```

---

## Step 1 — Create a Firebase Project

1. Go to https://console.firebase.google.com
2. Click **Add Project** → give it a name → Continue
3. Disable Google Analytics if not needed → Create Project

---

## Step 2 — Add Android App to Firebase

1. In Firebase Console → Project Overview → **Add app** → Android
2. Android package name: `com.twiliocommkit.example`
3. Download **google-services.json**
4. Place it at:
   ```
   example/minimal_example/android/app/google-services.json
   ```

---

## Step 3 — Get FCM Server Key

1. Firebase Console → Project Settings → **Cloud Messaging** tab
2. Copy the **Server key** (legacy) OR use the new **Sender ID**
   - For Twilio Push Credential use: **Sender ID** and the **Service Account JSON key**
   - Recommended: Use **FCM v1 API** (HTTP v1)

---

## Step 4 — Create Twilio Push Credential

1. Go to https://console.twilio.com → Voice → **Push Credentials**
2. Click **Create new Credential** → Android (FCM)
3. Upload the FCM Service Account JSON key
   - OR paste the FCM Server Key (legacy)
4. Copy the **Push Credential SID** (starts with `CR`)

---

## Step 5 — Update App Config

Edit `example/minimal_example/lib/config/twilio_app_config.dart`:

```dart
static const String pushCredentialSid = 'CRxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'; // ← paste here
```

---

## Step 6 — Configure FlutterFire (Dart SDK)

Install the FlutterFire CLI:
```bash
dart pub global activate flutterfire_cli
```

Run in `example/minimal_example/`:
```bash
flutterfire configure
```

This generates `lib/firebase_options.dart` automatically.

Then update `lib/services/notification_service.dart`:

```dart
import '../firebase_options.dart';

// Change this line:
const FirebaseOptions? kFirebaseOptions = null;
// To:
const FirebaseOptions? kFirebaseOptions = DefaultFirebaseOptions.currentPlatform;
```

---

## Step 7 — Create the TwiML App (for outgoing/routing)

1. Twilio Console → Voice → **TwiML Apps** → Create new TwiML App
2. Set **Voice Request URL** to:
   ```
   http://<YOUR_LAN_IP>:3000/voice
   ```
   (for local testing — use ngrok for external access)
3. Copy the **TwiML App SID** (starts with `AP`)

Update `twilio_app_config.dart`:
```dart
static const String outgoingApplicationSid = 'APxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';
```

Update `docs/token_server/.env`:
```
TWILIO_TWIML_APP_SID=APxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

---

## Step 8 — Expose Token Server with ngrok (for real device testing)

For testing on physical devices that can't reach `localhost`:

```bash
# Install ngrok: https://ngrok.com
ngrok http 3000
```

You'll get a URL like: `https://abc123.ngrok.io`

Update in Settings screen → Token Server URL:
```
https://abc123.ngrok.io
```

Also update the TwiML App Voice URL in Twilio Console to:
```
https://abc123.ngrok.io/voice
```

---

## Step 9 — Test Incoming Calls Between Two Devices

### Device A setup:
- Settings → Identity: `flutter-tester-1`
- Settings → Call To: `flutter-tester-2`
- Voice Tab → Initialize Voice SDK (green = FCM registered)

### Device B setup:
- Settings → Identity: `flutter-tester-2`
- Settings → Call To: `flutter-tester-1`
- Voice Tab → Initialize Voice SDK (green = FCM registered)

### Make the call:
1. Device A → "Call flutter-tester-2"
2. Device B receives **heads-up notification** or incoming call screen appears
3. Device B taps **Accept**
4. Both devices are connected, can hear each other

---

## Step 10 — Test Incoming Call When App is Killed

1. Close the app completely on Device B
2. Device A makes a call to `flutter-tester-2`
3. FCM wakes up Device B via `TwilioFirebaseMessagingService`
4. Android system shows a **full-screen incoming call notification**
5. User taps answer → app opens → incoming call screen appears

---

## Notification Channel

The app creates an Android notification channel `twilio_voice_calls` with:
- Importance: HIGH (heads-up)
- Category: CALL
- Full screen intent: true (works when screen is locked)

---

## Permissions Required

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>  <!-- Android 13+ -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE"/>
```

All are already declared in `AndroidManifest.xml`.

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| No FCM token shown | Add `google-services.json` and run `flutterfire configure` |
| Voice init shows "outgoing only" | FCM not set up — incoming calls won't work on killed app |
| Notification not showing | Check `POST_NOTIFICATIONS` permission is granted on device |
| Call fails immediately | Check TwiML App Voice URL is reachable (use ngrok) |
| "Bad Request" on register | Push Credential SID is wrong or FCM key is invalid |
| No audio | Check `RECORD_AUDIO` permission granted; speakerphone auto-enabled |

---

## Files Reference

| File | Purpose |
|------|---------|
| `android/app/google-services.json` | Firebase config (you must add this) |
| `lib/firebase_options.dart` | Generated by `flutterfire configure` |
| `lib/services/notification_service.dart` | FCM init, token management, notification posting |
| `android/app/src/.../TwilioFirebaseMessagingService.kt` | FCM message handler → Twilio Voice |
| `flutter_twilio_commkit_android/.../TwilioVoiceNotificationHandler.kt` | Twilio Voice push processing |
| `docs/token_server/.env` | Server credentials (never commit!) |
| `docs/token_server/server.js` | Token server with `/voice` TwiML endpoint |

