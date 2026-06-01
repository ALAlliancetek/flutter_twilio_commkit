/// Represents a video/audio participant in a room.
class Participant {
  const Participant({
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

  Participant copyWith({
    String? sid,
    String? identity,
    bool? isVideoEnabled,
    bool? isAudioEnabled,
    int? networkQualityLevel,
    bool? isDominantSpeaker,
  }) {
    return Participant(
      sid: sid ?? this.sid,
      identity: identity ?? this.identity,
      isVideoEnabled: isVideoEnabled ?? this.isVideoEnabled,
      isAudioEnabled: isAudioEnabled ?? this.isAudioEnabled,
      networkQualityLevel: networkQualityLevel ?? this.networkQualityLevel,
      isDominantSpeaker: isDominantSpeaker ?? this.isDominantSpeaker,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Participant && other.sid == sid;

  @override
  int get hashCode => sid.hashCode;
}

