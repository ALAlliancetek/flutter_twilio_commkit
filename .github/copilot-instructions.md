# GitHub Copilot Master Prompt
# Flutter Twilio Communication SDK / Library
# Target: Flutter Package (NOT Application)

Read and strictly follow `.github/copilot-instructions.md`.

We are NOT building a Flutter application.

We are building a production-grade Flutter SDK / Library package that can be integrated into any Flutter Android or iOS application.

The goal is to create a lightweight, scalable, modular, enterprise-grade Flutter communication SDK using native Twilio SDKs internally.

The SDK must support:

- Twilio Video Calling
- Twilio Voice Calling
- Future Chat Module Support
- Custom UI Components
- Fully Customizable Theming
- Native SDK Integration
- Android + iOS
- Production-grade architecture
- High scalability
- Lightweight performance

The SDK must expose simple Flutter APIs for client applications while internally handling native SDK complexity.

---

# SDK NAME

Package Name:

flutter_twilio_commkit

Example import:

```dart
import 'package:flutter_twilio_commkit/flutter_twilio_commkit.dart';
```

---

# IMPORTANT REQUIREMENTS

This is NOT an app.

DO NOT generate:

- main.dart application
- app-level business logic
- Firebase application implementation
- complete demo application
- unnecessary UI screens

We are building:

- Flutter package/library
- reusable SDK
- platform integration layer
- customizable UI kit
- extensible communication framework

---

# PRIMARY GOALS

The SDK must provide:

1. Easy integration
2. Lightweight architecture
3. Native performance
4. Extensibility
5. Modular features
6. Production-grade reliability
7. Custom UI support
8. Future chat support
9. Minimal setup for client apps
10. Strong abstraction over native Twilio SDKs

---

# REQUIRED ARCHITECTURE

Use modular clean package architecture.

Structure:

lib/
├── flutter_twilio_commkit.dart
├── src/
│   ├── core/
│   ├── common/
│   ├── config/
│   ├── platform/
│   ├── video/
│   ├── voice/
│   ├── chat/
│   ├── ui/
│   ├── theme/
│   ├── events/
│   ├── models/
│   ├── services/
│   ├── exceptions/
│   ├── permissions/
│   ├── network/
│   └── utils/

platform/
├── android/
└── ios/

example/
├── minimal_example/
└── advanced_example/

---

# SDK DESIGN PRINCIPLES

The SDK must:

- Be modular
- Be feature-based
- Support tree-shaking
- Avoid unnecessary dependencies
- Support future expansion
- Support custom rendering
- Support custom event listeners
- Support dependency injection
- Support configurable logging
- Avoid memory leaks
- Avoid tight coupling

---

# NATIVE SDK INTEGRATION

Use official native Twilio SDKs internally.

Android:

- Twilio Video Android SDK
- Twilio Voice Android SDK

Implementation language:

- Kotlin only

iOS:

- Twilio Video iOS SDK
- Twilio Voice iOS SDK

Implementation language:

- Swift only

DO NOT use:

- unofficial Flutter plugins
- third-party wrappers
- deprecated SDKs

Use Flutter platform channels or Pigeon for communication.

Prefer:

- Pigeon
- EventChannels
- MethodChannels

Architecture must allow future migration to FFI if needed.

---

# PACKAGE TYPE

This must be a federated Flutter plugin architecture.

Required structure:

flutter_twilio_commkit/
flutter_twilio_commkit_platform_interface/
flutter_twilio_commkit_android/
flutter_twilio_commkit_ios/

Use:

- plugin_platform_interface

---

# REQUIRED FEATURES

# VIDEO CALL FEATURES

Implement:

- 1-to-1 video calls
- Group video calls
- Local participant
- Remote participant
- Camera switching
- Front/back camera
- Mute/unmute
- Speaker control
- Screen sharing support architecture
- Video quality handling
- Reconnection handling
- Dominant speaker detection
- Participant events
- Video renderer abstraction
- Call statistics
- Network quality monitoring
- Background handling
- Lifecycle handling

---

# VOICE CALL FEATURES

Implement:

- Outgoing calls
- Incoming calls
- Call accept/reject
- Mute/unmute
- Hold/unhold
- Speakerphone
- Bluetooth support
- Audio route management
- Call state events
- Reconnection handling
- Background mode
- Native call integration
- CallKit support
- Android foreground service support

---

# FUTURE CHAT MODULE SUPPORT

Architecture MUST support future integration for:

- Twilio Conversations
- Messaging
- Attachments
- Typing indicators
- Read receipts
- Presence
- Push notifications

Create placeholder modular structure now.

DO NOT tightly couple video and voice implementations.

---

# CUSTOM UI REQUIREMENTS

SDK must support TWO MODES:

1. Headless SDK mode
2. Built-in customizable UI mode

---

# HEADLESS MODE

Expose APIs only.

Client applications can create their own UI.

Example:

```dart
final call = await TwilioVoice.instance.startCall(...);
```

---

# BUILT-IN UI MODE

Provide customizable widgets for:

- Video call screen
- Voice call screen
- Incoming call screen
- Participant tiles
- Call controls
- Floating local preview
- Audio controls
- Call status widgets

---

# UI CUSTOMIZATION

Support:

- Theme customization
- Widget overrides
- Builder callbacks
- Custom control buttons
- Custom layouts
- Dark mode
- Light mode
- Responsive UI

Example:

```dart
TwilioVideoCallScreen(
  theme: customTheme,
  controlsBuilder: ...,
  participantBuilder: ...,
)
```

---

# STATE MANAGEMENT

Inside SDK use ONLY:

- Riverpod

DO NOT use:

- GetX
- Bloc
- Provider

State management must remain internal.

Client apps should not be forced to use Riverpod.

Public APIs must remain framework-agnostic.

---

# API DESIGN REQUIREMENTS

Public APIs must be:

- Simple
- Typed
- Stable
- Minimal
- Extensible

Example:

```dart
await TwilioCommKit.initialize(
  accessTokenProvider: ...,
);

await TwilioVideo.instance.joinRoom(...);

await TwilioVoice.instance.startCall(...);
```

---

# EVENT SYSTEM

Implement typed event streams.

Examples:

```dart
TwilioVoice.instance.onCallStateChanged
TwilioVideo.instance.onParticipantConnected
TwilioVideo.instance.onNetworkQualityChanged
```

Use:

- StreamController
- Broadcast streams

Avoid:

- dynamic events
- loosely typed callbacks

---

# PERFORMANCE REQUIREMENTS

SDK must be lightweight.

Optimize:

- startup time
- rendering
- memory usage
- event handling
- video rendering
- native bridge calls

Avoid:

- unnecessary widget rebuilds
- heavy dependencies
- blocking UI thread
- memory leaks

---

# SECURITY REQUIREMENTS

SDK must support:

- secure token injection
- token refresh callbacks
- SSL pinning support hooks
- encrypted local storage hooks
- runtime validation hooks

SDK MUST NEVER:

- generate Twilio token locally
- expose secrets
- hardcode credentials

---

# PLATFORM CHANNEL REQUIREMENTS

Use strongly typed channels.

Avoid:

- unstructured maps
- excessive serialization
- duplicated channels

Prefer:

- Pigeon generated APIs

---

# ANDROID REQUIREMENTS

Use:

- Kotlin
- Coroutines
- Flow
- AndroidX
- Lifecycle-aware components

Support:

- Android 8+
- Android foreground services
- Android 14 compatibility

Implement:

- ProGuard rules
- R8 optimization
- audio focus handling
- Bluetooth routing
- camera lifecycle handling

---

# IOS REQUIREMENTS

Use:

- Swift
- Combine where useful

Support:

- latest iOS versions

Implement:

- CallKit
- AVAudioSession handling
- PushKit preparation
- lifecycle management

---

# DEPENDENCY REQUIREMENTS

Keep dependencies minimal.

Use ONLY if necessary:

- flutter_riverpod
- freezed
- json_serializable
- plugin_platform_interface
- pigeon

Avoid bloated packages.

---

# MODEL REQUIREMENTS

Use:

- immutable models
- freezed
- json_serializable

Generate:

- fromJson
- toJson
- copyWith

Avoid mutable state.

---

# ERROR HANDLING

Implement strongly typed exceptions:

- TwilioAuthException
- TwilioNetworkException
- TwilioPermissionException
- TwilioCallException

Avoid generic Exception usage.

---

# LOGGING

Implement configurable logging system.

Support:

- debug logs
- warning logs
- error logs
- analytics hooks

Allow client apps to disable logs.

---

# TESTING REQUIREMENTS

Generate:

- unit tests
- platform interface tests
- widget tests
- integration-ready architecture

Use mockable abstractions.

---

# DOCUMENTATION REQUIREMENTS

Generate:

- README.md
- installation guide
- Android setup guide
- iOS setup guide
- migration guide
- API documentation
- example usage
- customization guide

---

# EXAMPLE APPLICATIONS

Generate ONLY lightweight examples:

1. Minimal integration example
2. Advanced custom UI example

DO NOT generate bloated demo apps.

---

# PUB PACKAGE REQUIREMENTS

SDK must be pub.dev ready.

Include:

- proper package scoring practices
- linting
- analysis_options.yaml
- dartdoc comments
- semantic versioning preparation

---

# CI/CD REQUIREMENTS

Generate:

- GitHub Actions
- lint workflow
- test workflow
- package publish workflow

---

# FUTURE SCALABILITY REQUIREMENTS

Architecture must support future modules:

- Chat
- Screen sharing
- Recording
- AI noise cancellation
- Live transcription
- Call analytics
- Multi-device sync
- Web support
- Desktop support

WITHOUT major refactoring.

---

# FINAL GOAL

Generate a production-grade Flutter Twilio communication SDK/library with:

- native Android/iOS Twilio integration
- modular architecture
- customizable UI
- lightweight implementation
- scalable plugin architecture
- future-ready communication framework

Generate:
1. full folder structure
2. package architecture
3. platform interface
4. Android native layer
5. iOS native layer
6. Flutter abstraction APIs
7. event system
8. UI kit architecture
9. example structure
10. initialization flow
11. public SDK APIs
12. extensibility architecture

Generate production-grade code only.