/// Represents a participant in a Twilio Video Room.
class ParticipantModel {
  const ParticipantModel({
    required this.sid,
    required this.identity,
    this.isVideoEnabled = true,
    this.isAudioEnabled = true,
    this.networkQualityLevel = 0,
    this.isDominantSpeaker = false,
  });

  final String sid;
  final String identity;
  final bool isVideoEnabled;
  final bool isAudioEnabled;
  final int networkQualityLevel;
  final bool isDominantSpeaker;

  factory ParticipantModel.fromMap(Map<String, dynamic> map) {
    return ParticipantModel(
      sid: map['sid'] as String,
      identity: map['identity'] as String,
      isVideoEnabled: map['isVideoEnabled'] as bool? ?? true,
      isAudioEnabled: map['isAudioEnabled'] as bool? ?? true,
      networkQualityLevel: map['networkQualityLevel'] as int? ?? 0,
      isDominantSpeaker: map['isDominantSpeaker'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'sid': sid,
        'identity': identity,
        'isVideoEnabled': isVideoEnabled,
        'isAudioEnabled': isAudioEnabled,
        'networkQualityLevel': networkQualityLevel,
        'isDominantSpeaker': isDominantSpeaker,
      };

  ParticipantModel copyWith({
    String? sid,
    String? identity,
    bool? isVideoEnabled,
    bool? isAudioEnabled,
    int? networkQualityLevel,
    bool? isDominantSpeaker,
  }) {
    return ParticipantModel(
      sid: sid ?? this.sid,
      identity: identity ?? this.identity,
      isVideoEnabled: isVideoEnabled ?? this.isVideoEnabled,
      isAudioEnabled: isAudioEnabled ?? this.isAudioEnabled,
      networkQualityLevel: networkQualityLevel ?? this.networkQualityLevel,
      isDominantSpeaker: isDominantSpeaker ?? this.isDominantSpeaker,
    );
  }
}

