# SDK Feature Audit — Voice & Video

> **Audit date:** May 29, 2026  
> Status: ✅ = implemented & working · ⚠️ = partial · ❌ = missing (now fixed)

---

## Voice Calling

| Feature | Status | Notes |
|---|---|---|
| Outgoing call (`startCall`) | ✅ | Android + iOS |
| Incoming call — FCM (Android) | ✅ | `TwilioFcmService` handles push |
| Incoming call — PushKit (iOS) | ✅ | AppDelegate forwards to SDK |
| Full-screen incoming call UI | ✅ | `TwilioIncomingCallActivity` (Android), CallKit (iOS) |
| Lock-screen incoming call | ✅ | `FLAG_SHOW_WHEN_LOCKED` + `USE_FULL_SCREEN_INTENT` |
| Accept call | ✅ | CallKit (iOS) + native Activity (Android) |
| Reject call | ✅ | Both platforms |
| Hang up | ✅ | Works for both caller & callee |
| Mute / unmute | ✅ | Both platforms |
| Hold / unhold | ✅ | Both platforms |
| Speaker / earpiece toggle | ✅ | Both platforms |
| **DTMF / Send Digits** | ✅ *(was ❌)* | `TwilioVoice.instance.sendDigits("1")` — IVR navigation |
| Call state events (connecting/ringing/connected/disconnected) | ✅ | Full state machine |
| Ringing state (separate from connecting) | ✅ | `callRinging` event |
| Call reconnecting / reconnected | ✅ | Both platforms |
| **Call quality warnings** | ✅ *(was ❌)* | `onCallQualityWarning` stream; warns on jitter/packet-loss/RTT |
| Mute state change event | ✅ | `CallMutedChangedEvent` |
| Hold state change event | ✅ | `CallHoldChangedEvent` |
| Incoming call UI — built-in | ✅ | `TwilioCallHandler` widget |
| Call timer (elapsed) | ✅ | Synced via `callConnectedAt` timestamp |
| Auto-close screen on remote hang-up | ✅ | `callDisconnected` event |
| CallKit (iOS native UI) | ✅ | Full CXProvider integration |
| Foreground service (Android) | ✅ | `TwilioCallForegroundService` |
| Bluetooth audio routing | ✅ | `allowBluetooth` iOS / `AudioSwitch` Android |

### Voice — What was missing (now fixed)

#### 1. DTMF / Send Digits
**Was:** No `sendDigits` API existed anywhere in the SDK.  
**Fixed:**
- `TwilioVoice.instance.sendDigits(digits)` — Dart public API
- Android: `activeCall?.sendDigits(digits)` in `TwilioVoiceManager`
- iOS: `activeCall?.sendDigits(digits)` in `TwilioVoiceManager.swift`
- Platform interface + method channel wired
- **Built-in UI:** "Keypad" button appears on the voice call screen when connected, opens a full DTMF dial-pad bottom sheet

#### 2. Call Quality Warnings
**Was:** Android had a stub `onCallQualityWarningsChanged` that did nothing. iOS had no implementation.  
**Fixed:**
- Android: emits `"type": "callQualityWarning"` with `warnings: [String]` list
- iOS: `callDidReceiveQualityWarnings` delegate implemented
- Platform event: `CallQualityWarningEvent` class added
- Dart: `CallQualityWarningChangedEvent` with `warnings: List<String>` and `hasWarnings` getter
- New stream: `TwilioVoice.instance.onCallQualityWarning`

**Usage:**
```dart
TwilioVoice.instance.onCallQualityWarning.listen((event) {
  if (event.hasWarnings) {
    print('Call quality issues: ${event.warnings}');
    // e.g. ["highJitter", "highPacketsLostFraction"]
  }
});
```

---

## Video Calling

| Feature | Status | Notes |
|---|---|---|
| Join room | ✅ | `TwilioVideo.instance.joinRoom(...)` |
| Disconnect from room | ✅ | Both platforms |
| Local video mute/unmute | ✅ | Both platforms |
| Local audio mute/unmute | ✅ | Both platforms |
| Camera switch (front/back) | ✅ | Both platforms |
| Remote participant joined event | ✅ | `ParticipantConnectedRoomEvent` |
| Remote participant left event | ✅ | `ParticipantDisconnectedRoomEvent` |
| **Remote participant audio mute event** | ✅ *(was ❌)* | `ParticipantAudioChangedRoomEvent` |
| **Remote participant video mute event** | ✅ *(was ❌)* | `ParticipantVideoChangedRoomEvent` |
| Dominant speaker detection | ✅ | `DominantSpeakerChangedRoomEvent` |
| Network quality monitoring | ✅ | `NetworkQualityRoomEvent` |
| Room reconnecting / reconnected | ✅ | Both platforms |
| Audio routing (AudioSwitch) | ✅ | Android via `AudioSwitch` library |
| **Speaker toggle for video** | ✅ *(was ❌)* | `TwilioVideo.instance.setSpeaker(enabled: true)` |
| Get participants list | ✅ | `TwilioVideo.instance.getParticipants(...)` |
| Pre-existing participants on join | ✅ | Emitted in `onConnected`/`roomDidConnect` |
| Video track rendering | ✅ | `TwilioVideoView`, `TwilioVideoPreview` |
| Bluetooth audio | ✅ | AudioSwitch preferred device list |

### Video — What was missing (now fixed)

#### 3. Remote Participant Audio/Video Mute Events
**Was:** Android had empty stubs for `onAudioTrackEnabled`/`onAudioTrackDisabled`/`onVideoTrackEnabled`/`onVideoTrackDisabled`. iOS had no `RemoteParticipantDelegate` set on participants.  

**Impact:** When a remote participant muted/unmuted their microphone or camera, the local user's UI had no way to know — leading to stale participant state in the UI (e.g. showing a microphone icon as active when the remote had muted).

**Fixed:**
- Android: all 4 callbacks now emit `participantAudioChanged` / `participantVideoChanged` events
- iOS: `RemoteParticipantDelegate` extension added; `participant.delegate = self` set for all participants (existing and newly connected)
- Platform event: `ParticipantAudioChangedEvent` + `ParticipantVideoChangedEvent` classes
- Dart: `ParticipantAudioChangedRoomEvent` + `ParticipantVideoChangedRoomEvent` events
- New streams: `TwilioVideo.instance.onParticipantAudioChanged` + `TwilioVideo.instance.onParticipantVideoChanged`

**Usage:**
```dart
TwilioVideo.instance.onParticipantAudioChanged.listen((event) {
  print('${event.participantSid} audio: ${event.isAudioEnabled}');
});

TwilioVideo.instance.onParticipantVideoChanged.listen((event) {
  print('${event.participantSid} video: ${event.isVideoEnabled}');
});
```

#### 4. Speaker Toggle for Video Calls
**Was:** `TwilioVoice.instance.setSpeaker()` existed for voice, but `TwilioVideo` had no equivalent. Video calls always used the default audio route with no way to switch.

**Fixed:**
- `TwilioVideo.instance.setSpeaker(enabled: bool)` — new Dart public API
- Android: routes via `AudioSwitch.selectDevice()` (Speakerphone vs Earpiece)
- iOS: `AVAudioSession.overrideOutputAudioPort(.speaker / .none)`
- Platform interface + method channel: `setSpeakerForVideo` method added

**Usage:**
```dart
// During an active video room
await TwilioVideo.instance.setSpeaker(enabled: true);   // → loudspeaker
await TwilioVideo.instance.setSpeaker(enabled: false);  // → earpiece
```

---

## Summary of New Public APIs Added

### Voice
```dart
// Send DTMF tones (IVR navigation, PIN entry, etc.)
await TwilioVoice.instance.sendDigits('1');
await TwilioVoice.instance.sendDigits('#');

// Listen for call quality degradation
TwilioVoice.instance.onCallQualityWarning.listen((event) {
  // event.warnings → ["highJitter", "highPacketsLostFraction", ...]
  // event.hasWarnings → bool
});
```

### Video
```dart
// Toggle speakerphone during a video call
await TwilioVideo.instance.setSpeaker(enabled: true);

// Know when remote participants mute/unmute
TwilioVideo.instance.onParticipantAudioChanged.listen((event) {
  // event.participantSid, event.isAudioEnabled
});

TwilioVideo.instance.onParticipantVideoChanged.listen((event) {
  // event.participantSid, event.isVideoEnabled
});
```

---

## Still Planned (Future Scope)

The following are advanced features not in scope for the current version but the architecture supports them:

| Feature | Notes |
|---|---|
| Screen sharing | Architecture ready; needs `MediaProjection` (Android) + `ReplayKit` (iOS) |
| Call recording | Twilio server-side; no client changes needed |
| Video call stats (bitrate, framerate) | Available via Twilio `StatsReport` — can be added as a method |
| Data track (text/binary side-channel) | Twilio Data Tracks; stubs exist in Android `RemoteParticipant.Listener` |
| Live transcription / AI noise cancellation | Twilio Intelligence add-on — server-side |
| Chat / Conversations module | Placeholder structure exists in `lib/src/chat/` |
| Web / Desktop support | Federated architecture ready |

