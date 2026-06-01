import 'package:flutter_twilio_commkit_platform_interface/flutter_twilio_commkit_platform_interface.dart'
    show VideoRoomModel;

import '../models/room_state.dart';

/// Represents an active Twilio Video Room.
class VideoRoom {
  const VideoRoom({
    required this.sid,
    required this.name,
    required this.state,
    this.localParticipantSid,
  });

  final String sid;
  final String name;
  final RoomState state;
  final String? localParticipantSid;

  factory VideoRoom.fromModel(VideoRoomModel model) {
    return VideoRoom(
      sid: model.sid,
      name: model.name,
      state: RoomStateX.fromString(model.state),
      localParticipantSid: model.localParticipantSid,
    );
  }

  VideoRoom copyWith({
    String? sid,
    String? name,
    RoomState? state,
    String? localParticipantSid,
  }) {
    return VideoRoom(
      sid: sid ?? this.sid,
      name: name ?? this.name,
      state: state ?? this.state,
      localParticipantSid: localParticipantSid ?? this.localParticipantSid,
    );
  }
}

