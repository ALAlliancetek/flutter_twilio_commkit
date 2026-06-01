import '../models/participant.dart';
import '../models/network_quality.dart';

/// Strongly-typed video room events exposed to client apps.
sealed class VideoRoomEvent {
  const VideoRoomEvent();
}

class RoomConnectedRoomEvent extends VideoRoomEvent {
  const RoomConnectedRoomEvent({required this.roomSid, required this.roomName});
  final String roomSid;
  final String roomName;
}

class RoomDisconnectedRoomEvent extends VideoRoomEvent {
  const RoomDisconnectedRoomEvent({required this.roomSid, this.reason});
  final String roomSid;
  final String? reason;
}

class RoomReconnectingRoomEvent extends VideoRoomEvent {
  const RoomReconnectingRoomEvent({required this.roomSid});
  final String roomSid;
}

class RoomReconnectedRoomEvent extends VideoRoomEvent {
  const RoomReconnectedRoomEvent({required this.roomSid});
  final String roomSid;
}

class ParticipantConnectedRoomEvent extends VideoRoomEvent {
  const ParticipantConnectedRoomEvent({required this.participant});
  final Participant participant;
}

class ParticipantDisconnectedRoomEvent extends VideoRoomEvent {
  const ParticipantDisconnectedRoomEvent({required this.participantSid});
  final String participantSid;
}

/// Fired when a remote participant mutes or unmutes their audio.
class ParticipantAudioChangedRoomEvent extends VideoRoomEvent {
  const ParticipantAudioChangedRoomEvent({
    required this.participantSid,
    required this.isAudioEnabled,
  });
  final String participantSid;
  final bool isAudioEnabled;
}

/// Fired when a remote participant enables or disables their video.
class ParticipantVideoChangedRoomEvent extends VideoRoomEvent {
  const ParticipantVideoChangedRoomEvent({
    required this.participantSid,
    required this.isVideoEnabled,
  });
  final String participantSid;
  final bool isVideoEnabled;
}

class DominantSpeakerChangedRoomEvent extends VideoRoomEvent {
  const DominantSpeakerChangedRoomEvent({this.participantSid});
  final String? participantSid;
}

class NetworkQualityRoomEvent extends VideoRoomEvent {
  const NetworkQualityRoomEvent({required this.quality});
  final NetworkQuality quality;
}

class VideoErrorRoomEvent extends VideoRoomEvent {
  const VideoErrorRoomEvent({required this.message, required this.code});
  final String message;
  final int code;
}

