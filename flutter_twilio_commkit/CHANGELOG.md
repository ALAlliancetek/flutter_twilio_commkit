## 0.1.1

### Fixes
* Fixed missing trailing commas in `video_event.dart` and `method_channel_twilio_commkit.dart` (static analysis).
* Applied `const` constructors in example `main.dart` for better performance.
* Sorted `dev_dependencies` alphabetically in `example/pubspec.yaml`.
* Added `.pubignore` to exclude `.dart_tool/` and `pubspec.lock` from published artifacts.
* Removed tracked build artifacts (`.dart_tool/`, `pubspec.lock`) from version control.

## 0.1.0

### Voice
* Outgoing calls via `TwilioVoice.instance.startCall()`
* Incoming calls via FCM (Android) and PushKit/APNs (iOS)
* Accept / reject incoming calls
* Mute, hold, speakerphone controls
* DTMF dialpad — built-in bottom sheet + `sendDigits()` API
* Bluetooth audio routing
* Android foreground service for background calls
* iOS CallKit integration with native UI
* Reconnection handling
* Call quality warning stream (`onCallQualityWarning`)
* Mute/hold change event streams
* Shared `callConnectedAt` timestamp — synchronized call timer across caller and callee

### Video
* 1-to-1 and group video calls
* Adaptive layout engine (1 / 2 / 3 / 4+ participants)
* Draggable picture-in-picture local preview
* Camera switch (front / back)
* Audio and video mute controls
* Dominant speaker detection
* Network quality monitoring per participant
* `controlsBuilder` and `participantBuilder` override callbacks
* `enableVideo` / `enableAudio` initial-state flags
* `localIdentity` parameter for participant list

### UI
* `TwilioVoiceCallScreen` — full voice call UI with pulsing avatar, timer, dialpad
* `TwilioVideoCallScreen` — adaptive multi-participant video UI with draggable PIP
* `TwilioIncomingCallScreen` — accept/decline screen with ringtone support
* `TwilioCallHandler` — automatic incoming call routing (foreground / background / killed-app)
* `TwilioCallControls` — reusable call control bar widget
* `TwilioAvatar` — participant avatar with image/fallback support
* `TwilioVideoView` / `TwilioVideoPreview` — raw video track renderers

### Theming
* `TwilioThemeData.dark()` — deep navy preset
* `TwilioThemeData.light()` — white/grey preset
* `TwilioThemeData.videoCinema()` — full-black cinema preset
* `TwilioThemeData.videoPurple()` — deep purple preset with gradient incoming screen
* `TwilioThemeData.videoOcean()` — ocean blue preset
* Full custom theme support: colours, typography, button styles, avatar, PIP, tiles
* `controlBarBlur` glassmorphism effect
* `incomingBackgroundGradient` for incoming call screen
* Per-button style overrides: `muteButtonStyle`, `endCallButtonStyle`, `acceptButtonStyle`, `rejectButtonStyle`, `videoButtonStyle`, `flipCameraButtonStyle`, `holdButtonStyle`, `speakerButtonStyle`

### Customization
* `resolveParticipantImage` callback on all call screen widgets — supply remote participant avatars from your contact store
* Custom ringtone via `TwilioThemeData.ringtonePath` / `ringtoneLoop`
* `avatarWidget` override — replace default avatar with any widget
* `controlsBuilder` — replace entire controls bar in video screen
* `participantBuilder` — replace individual participant tiles

### Architecture
* Federated plugin architecture (4-package split)
* Platform channels with strongly typed Pigeon-ready interface
* Riverpod state management (internal only — client apps stay framework-agnostic)
* Strongly typed event streams (`onCallStateChanged`, `onIncomingCall`, `onCallQualityWarning`, `onRoomEvent`)
* Strongly typed exceptions (`TwilioAuthException`, `TwilioCallException`, `TwilioNetworkException`, `TwilioPermissionException`)
* Configurable logging (`TwilioLogLevel.debug / warning / error / none`)
* Chat module placeholder for future Twilio Conversations integration
