import 'package:flutter/services.dart';

import 'platform_interface.dart';
import 'models/video_room_model.dart';
import 'models/voice_call_model.dart';
import 'models/participant_model.dart';
import 'models/twilio_credentials_model.dart';
import 'events/video_event.dart';
import 'events/voice_event.dart';

/// Default implementation using Flutter MethodChannel + EventChannel.
class MethodChannelTwilioCommKit extends TwilioCommKitPlatform {
  static const _methodChannel =
      MethodChannel('com.twiliocommkit/methods');
  static const _videoEventChannel =
      EventChannel('com.twiliocommkit/video_events');
  static const _voiceEventChannel =
      EventChannel('com.twiliocommkit/voice_events');

  @override
  Future<void> initialize({
    required String logLevel,
    required TwilioCredentialsModel credentials,
    required Map<String, dynamic> videoConfig,
    required Map<String, dynamic> voiceConfig,
  }) async {
    await _methodChannel.invokeMethod('initialize', {
      'logLevel': logLevel,
      'credentials': credentials.toMap(),
      'videoConfig': videoConfig,
      'voiceConfig': voiceConfig,
    });
  }

  // ─── Video ────────────────────────────────────────────────────────────────

  @override
  Future<VideoRoomModel> connectToRoom({
    required String accessToken,
    required String roomName,
    bool enableVideo = true,
    bool enableAudio = true,
  }) async {
    final result = await _methodChannel.invokeMapMethod<String, dynamic>(
      'connectToRoom',
      {
        'accessToken': accessToken,
        'roomName': roomName,
        'enableVideo': enableVideo,
        'enableAudio': enableAudio,
      },
    );
    return VideoRoomModel.fromMap(result!);
  }

  @override
  Future<void> disconnectFromRoom({required String roomSid}) async {
    await _methodChannel
        .invokeMethod('disconnectFromRoom', {'roomSid': roomSid});
  }

  @override
  Future<void> muteVideo({required bool muted}) async {
    await _methodChannel.invokeMethod('muteVideo', {'muted': muted});
  }

  @override
  Future<void> muteAudio({required bool muted}) async {
    await _methodChannel.invokeMethod('muteAudio', {'muted': muted});
  }

  @override
  Future<void> switchCamera() async {
    await _methodChannel.invokeMethod('switchCamera');
  }

  @override
  Stream<VideoEvent> get onVideoEvent {
    return _videoEventChannel
        .receiveBroadcastStream()
        .map((event) => VideoEvent.fromMap(Map<String, dynamic>.from(event)));
  }

  // ─── Voice ────────────────────────────────────────────────────────────────

  @override
  Future<void> initVoice({required String accessToken, String? fcmToken}) async {
    await _methodChannel.invokeMethod('initVoice', {
      'accessToken': accessToken,
      if (fcmToken != null && fcmToken.isNotEmpty) 'fcmToken': fcmToken,
    });
  }

  @override
  Future<VoiceCallModel> startCall({
    required String to,
    required String accessToken,
    Map<String, String>? params,
  }) async {
    final result = await _methodChannel.invokeMapMethod<String, dynamic>(
      'startCall',
      {'to': to, 'accessToken': accessToken, 'params': params ?? {}},
    );
    return VoiceCallModel.fromMap(result!);
  }

  @override
  Future<void> acceptCall({required String callSid}) async {
    await _methodChannel.invokeMethod('acceptCall', {'callSid': callSid});
  }

  @override
  Future<void> rejectCall({required String callSid}) async {
    await _methodChannel.invokeMethod('rejectCall', {'callSid': callSid});
  }

  @override
  Future<void> hangUpCall({required String callSid}) async {
    await _methodChannel.invokeMethod('hangUpCall', {'callSid': callSid});
  }

  @override
  Future<void> muteCall({required bool muted}) async {
    await _methodChannel.invokeMethod('muteCall', {'muted': muted});
  }

  @override
  Future<void> holdCall({required bool held}) async {
    await _methodChannel.invokeMethod('holdCall', {'held': held});
  }

  @override
  Future<void> setSpeaker({required bool enabled}) async {
    await _methodChannel.invokeMethod('setSpeaker', {'enabled': enabled});
  }

  @override
  Future<void> sendDigits({required String digits}) async {
    await _methodChannel.invokeMethod('sendDigits', {'digits': digits});
  }

  @override
  Future<void> setSpeakerForVideo({required bool enabled}) async {
    await _methodChannel.invokeMethod('setSpeakerForVideo', {'enabled': enabled});
  }

  @override
  Stream<VoiceEvent> get onVoiceEvent {
    return _voiceEventChannel
        .receiveBroadcastStream()
        .map((event) => VoiceEvent.fromMap(Map<String, dynamic>.from(event)));
  }

  @override
  Future<List<ParticipantModel>> getParticipants(
      {required String roomSid}) async {
    final result = await _methodChannel
        .invokeListMethod<Map>('getParticipants', {'roomSid': roomSid});
    return result
            ?.map((e) =>
                ParticipantModel.fromMap(Map<String, dynamic>.from(e)))
            .toList() ??
        [];
  }
}
