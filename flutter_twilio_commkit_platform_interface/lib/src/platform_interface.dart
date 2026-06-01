import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'method_channel_twilio_commkit.dart';
import 'models/video_room_model.dart';
import 'models/voice_call_model.dart';
import 'models/participant_model.dart';
import 'models/twilio_credentials_model.dart';
import 'events/video_event.dart';
import 'events/voice_event.dart';

/// The interface that platform-specific implementations must implement.
abstract class TwilioCommKitPlatform extends PlatformInterface {
  TwilioCommKitPlatform() : super(token: _token);

  static final Object _token = Object();
  static TwilioCommKitPlatform _instance = MethodChannelTwilioCommKit();

  static TwilioCommKitPlatform get instance => _instance;

  static set instance(TwilioCommKitPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  // ─── Initialization ───────────────────────────────────────────────────────

  /// Initializes the native SDK layer with the project credentials and
  /// per-feature configurations. Must be called before any other method.
  Future<void> initialize({
    required String logLevel,
    required TwilioCredentialsModel credentials,
    required Map<String, dynamic> videoConfig,
    required Map<String, dynamic> voiceConfig,
  }) {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  // ─── Video ────────────────────────────────────────────────────────────────

  Future<VideoRoomModel> connectToRoom({
    required String accessToken,
    required String roomName,
    bool enableVideo = true,
    bool enableAudio = true,
  }) {
    throw UnimplementedError('connectToRoom() has not been implemented.');
  }

  Future<void> disconnectFromRoom({required String roomSid}) {
    throw UnimplementedError('disconnectFromRoom() has not been implemented.');
  }

  Future<void> muteVideo({required bool muted}) {
    throw UnimplementedError('muteVideo() has not been implemented.');
  }

  Future<void> muteAudio({required bool muted}) {
    throw UnimplementedError('muteAudio() has not been implemented.');
  }

  Future<void> switchCamera() {
    throw UnimplementedError('switchCamera() has not been implemented.');
  }

  Stream<VideoEvent> get onVideoEvent {
    throw UnimplementedError('onVideoEvent has not been implemented.');
  }

  // ─── Voice ────────────────────────────────────────────────────────────────

  Future<void> initVoice({required String accessToken, String? fcmToken}) {
    throw UnimplementedError('initVoice() has not been implemented.');
  }

  Future<VoiceCallModel> startCall({
    required String to,
    required String accessToken,
    Map<String, String>? params,
  }) {
    throw UnimplementedError('startCall() has not been implemented.');
  }

  Future<void> acceptCall({required String callSid}) {
    throw UnimplementedError('acceptCall() has not been implemented.');
  }

  Future<void> rejectCall({required String callSid}) {
    throw UnimplementedError('rejectCall() has not been implemented.');
  }

  Future<void> hangUpCall({required String callSid}) {
    throw UnimplementedError('hangUpCall() has not been implemented.');
  }

  Future<void> muteCall({required bool muted}) {
    throw UnimplementedError('muteCall() has not been implemented.');
  }

  Future<void> holdCall({required bool held}) {
    throw UnimplementedError('holdCall() has not been implemented.');
  }

  Future<void> setSpeaker({required bool enabled}) {
    throw UnimplementedError('setSpeaker() has not been implemented.');
  }

  Future<void> sendDigits({required String digits}) {
    throw UnimplementedError('sendDigits() has not been implemented.');
  }

  Future<void> setSpeakerForVideo({required bool enabled}) {
    throw UnimplementedError('setSpeakerForVideo() has not been implemented.');
  }

  Stream<VoiceEvent> get onVoiceEvent {
    throw UnimplementedError('onVoiceEvent has not been implemented.');
  }

  // ─── Participants ─────────────────────────────────────────────────────────

  Future<List<ParticipantModel>> getParticipants({required String roomSid}) {
    throw UnimplementedError('getParticipants() has not been implemented.');
  }
}
