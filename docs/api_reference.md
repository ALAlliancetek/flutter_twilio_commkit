# API Reference

## TwilioCommKit

| Method | Description |
|---|---|
| `initialize({config})` | Initialize the SDK. Must be called first. |
| `dispose()` | Release all SDK resources. |
| `config` | Access current SDK configuration. |

## TwilioVideo

| Method | Description |
|---|---|
| `joinRoom({accessToken, roomName, enableVideo, enableAudio})` | Connect to a video room. |
| `disconnect()` | Leave the current room. |
| `muteVideo({muted})` | Enable/disable local video. |
| `muteAudio({muted})` | Enable/disable local audio. |
| `switchCamera()` | Toggle front/back camera. |
| `getParticipants({roomSid})` | Get remote participants. |
| `onRoomEvent` | Stream of all video room events. |
| `onParticipantConnected` | Stream of participant join events. |
| `onNetworkQualityChanged` | Stream of network quality events. |
| `currentRoom` | Currently active VideoRoom or null. |

## TwilioVoice

| Method | Description |
|---|---|
| `initialize({accessToken})` | Register device for voice calls. |
| `startCall({to, params})` | Start an outgoing voice call. |
| `acceptCall({callSid})` | Accept an incoming call. |
| `rejectCall({callSid})` | Reject an incoming call. |
| `hangUp()` | End the active call. |
| `mute({muted})` | Mute/unmute the active call. |
| `hold({held})` | Hold/unhold the active call. |
| `setSpeaker({enabled})` | Toggle speakerphone. |
| `onCallEvent` | Stream of all voice call events. |
| `onCallStateChanged` | Stream of call state changes. |
| `onIncomingCall` | Stream of incoming call events. |
| `activeCall` | Currently active VoiceCall or null. |

## UI Widgets

| Widget | Description |
|---|---|
| `TwilioVideoCallScreen` | Full-screen video call with customizable UI. |
| `TwilioVoiceCallScreen` | Full-screen voice call screen. |
| `TwilioIncomingCallScreen` | Incoming call accept/reject screen. |
| `TwilioParticipantTile` | Individual participant video tile. |
| `TwilioVideoPreview` | Local camera preview (floating). |
| `TwilioCallControls` | Customizable call controls bar. |
| `TwilioAudioControls` | Audio route selector widget. |

## Models

| Model | Description |
|---|---|
| `VideoRoom` | Active video room. |
| `VoiceCall` | Active voice call. |
| `Participant` | Video room participant. |
| `NetworkQuality` | Participant network quality (0-5). |
| `RoomState` | Video room state enum. |
| `CallState` | Voice call state enum. |
| `AudioRoute` | Available audio output routes. |

## Exceptions

| Exception | When thrown |
|---|---|
| `TwilioAuthException` | Invalid or expired token. |
| `TwilioNetworkException` | Network connectivity issues. |
| `TwilioPermissionException` | Missing camera/microphone permission. |
| `TwilioCallException` | Call-level failures. |
| `TwilioNotInitializedException` | SDK used before `initialize()`. |

## TwilioCommKitConfig

| Property | Type | Default | Description |
|---|---|---|---|
| `credentials` | `TwilioCredentials` | required | Twilio project SIDs. |
| `accessTokenProvider` | `Future<String> Function()` | required | Token provider callback. |
| `videoConfig` | `TwilioVideoConfig` | default | Video feature settings. |
| `voiceConfig` | `TwilioVoiceConfig` | default | Voice feature settings. |
| `logLevel` | `TwilioLogLevel` | `none` | Log verbosity. |
| `enableAnalytics` | `bool` | `false` | Enable analytics hooks. |
| `tokenRefreshMarginSeconds` | `int` | `30` | Token refresh margin. |

## TwilioCredentials

All SIDs come from [console.twilio.com](https://console.twilio.com).

| Property | Required | Format | Description |
|---|---|---|---|
| `accountSid` | ✅ | `AC` + 32 chars | Twilio Account SID |
| `apiKeySid` | ✅ | `SK` + 32 chars | API Key SID |
| `apiKeySecret` | ❌ | - | API Key Secret — **server-side only** |
| `outgoingApplicationSid` | ❌ | `AP` + 32 chars | TwiML Application SID for outgoing voice |
| `pushCredentialSid` | ❌ | `CR` + 32 chars | Push Credential SID for incoming call push |

## TwilioVideoConfig

| Property | Type | Default | Description |
|---|---|---|---|
| `roomType` | `TwilioRoomType` | `group` | Room type (peerToPeer, go, group, groupSmall) |
| `defaultEnableVideo` | `bool` | `true` | Auto-enable video on join |
| `defaultEnableAudio` | `bool` | `true` | Auto-enable audio on join |
| `enableNetworkQuality` | `bool` | `true` | Enable network quality monitoring |
| `enableDominantSpeaker` | `bool` | `true` | Enable dominant speaker detection |
| `preferredVideoCodec` | `TwilioVideoCodec` | `vp8` | Video codec (vp8, h264, vp9) |
| `maxVideoBitrate` | `int?` | `null` | Max video bitrate (bps) |
| `maxAudioBitrate` | `int?` | `null` | Max audio bitrate (bps) |

## TwilioVoiceConfig

| Property | Type | Default | Description |
|---|---|---|---|
| `enableCallKit` | `bool` | `true` | iOS CallKit integration |
| `enableForegroundService` | `bool` | `true` | Android foreground service for background calls |
| `callerIdName` | `String?` | `null` | Display name shown in CallKit / Android dialer |
| `defaultRegion` | `String?` | `null` | Twilio media edge region (e.g. `'ashburn'`) |
| `enableInsights` | `bool` | `true` | Twilio Insights call quality analytics |
| `ringtoneAssetPath` | `String?` | `null` | Flutter asset path for custom ringtone |
| `callKitIconAssetPath` | `String?` | `null` | Flutter asset path for CallKit icon |

