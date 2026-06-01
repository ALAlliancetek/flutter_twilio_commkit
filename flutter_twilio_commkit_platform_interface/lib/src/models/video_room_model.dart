/// Represents a Twilio Video Room.
class VideoRoomModel {
  const VideoRoomModel({
    required this.sid,
    required this.name,
    required this.state,
    this.localParticipantSid,
  });

  final String sid;
  final String name;
  final String state;
  final String? localParticipantSid;

  factory VideoRoomModel.fromMap(Map<String, dynamic> map) {
    return VideoRoomModel(
      sid: map['sid'] as String,
      name: map['name'] as String,
      state: map['state'] as String,
      localParticipantSid: map['localParticipantSid'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'sid': sid,
        'name': name,
        'state': state,
        'localParticipantSid': localParticipantSid,
      };

  VideoRoomModel copyWith({
    String? sid,
    String? name,
    String? state,
    String? localParticipantSid,
  }) {
    return VideoRoomModel(
      sid: sid ?? this.sid,
      name: name ?? this.name,
      state: state ?? this.state,
      localParticipantSid: localParticipantSid ?? this.localParticipantSid,
    );
  }
}

