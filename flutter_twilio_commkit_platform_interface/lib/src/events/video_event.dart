import '../models/participant_model.dart';
import '../models/network_quality_model.dart';

/// Strongly typed video events from the native layer.
sealed class VideoEvent {
  const VideoEvent();

  factory VideoEvent.fromMap(Map<String, dynamic> map) {
    final type = map['type'] as String;
    return switch (type) {
      'roomConnected' => RoomConnectedEvent(
          roomSid: map['roomSid'] as String,
          roomName: map['roomName'] as String,
        ),
      'roomDisconnected' => RoomDisconnectedEvent(
          roomSid: map['roomSid'] as String,
          reason: map['reason'] as String?,
        ),
      'roomReconnecting' => RoomReconnectingEvent(
          roomSid: map['roomSid'] as String,
        ),
      'roomReconnected' => RoomReconnectedEvent(
          roomSid: map['roomSid'] as String,
        ),
      'participantConnected' => ParticipantConnectedEvent(
          participant: ParticipantModel.fromMap(
            Map<String, dynamic>.from(map['participant']),
          ),
        ),
      'participantDisconnected' => ParticipantDisconnectedEvent(
          participantSid: map['participantSid'] as String,
        ),
      'participantAudioChanged' => ParticipantAudioChangedEvent(
          participantSid: map['participantSid'] as String,
          isAudioEnabled: map['isAudioEnabled'] as bool? ?? false,
        ),
      'participantVideoChanged' => ParticipantVideoChangedEvent(
          participantSid: map['participantSid'] as String,
          isVideoEnabled: map['isVideoEnabled'] as bool? ?? false,
        ),
      'dominantSpeakerChanged' => DominantSpeakerChangedEvent(
          participantSid: map['participantSid'] as String?,
        ),
      'networkQualityChanged' => NetworkQualityChangedEvent(
          quality: NetworkQualityModel.fromMap(
            Map<String, dynamic>.from(map['quality']),
          ),
        ),
      'error' => VideoErrorEvent(
          message: map['message'] as String,
          code: map['code'] as int? ?? -1,
        ),
      _ => UnknownVideoEvent(raw: map),
    };
  }
}

class RoomConnectedEvent extends VideoEvent {
  const RoomConnectedEvent({required this.roomSid, required this.roomName});
  final String roomSid;
  final String roomName;
}

class RoomDisconnectedEvent extends VideoEvent {
  const RoomDisconnectedEvent({required this.roomSid, this.reason});
  final String roomSid;
  final String? reason;
}

class RoomReconnectingEvent extends VideoEvent {
  const RoomReconnectingEvent({required this.roomSid});
  final String roomSid;
}

class RoomReconnectedEvent extends VideoEvent {
  const RoomReconnectedEvent({required this.roomSid});
  final String roomSid;
}

class ParticipantConnectedEvent extends VideoEvent {
  const ParticipantConnectedEvent({required this.participant});
  final ParticipantModel participant;
}

class ParticipantDisconnectedEvent extends VideoEvent {
  const ParticipantDisconnectedEvent({required this.participantSid});
  final String participantSid;
}

class ParticipantAudioChangedEvent extends VideoEvent {
  const ParticipantAudioChangedEvent({
    required this.participantSid,
    required this.isAudioEnabled,
  });
  final String participantSid;
  final bool isAudioEnabled;
}

class ParticipantVideoChangedEvent extends VideoEvent {
  const ParticipantVideoChangedEvent({
    required this.participantSid,
    required this.isVideoEnabled,
  });
  final String participantSid;
  final bool isVideoEnabled;
}

class DominantSpeakerChangedEvent extends VideoEvent {
  const DominantSpeakerChangedEvent({this.participantSid});
  final String? participantSid;
}

class NetworkQualityChangedEvent extends VideoEvent {
  const NetworkQualityChangedEvent({required this.quality});
  final NetworkQualityModel quality;
}

class VideoErrorEvent extends VideoEvent {
  const VideoErrorEvent({required this.message, required this.code});
  final String message;
  final int code;
}

class UnknownVideoEvent extends VideoEvent {
  const UnknownVideoEvent({required this.raw});
  final Map<String, dynamic> raw;
}

