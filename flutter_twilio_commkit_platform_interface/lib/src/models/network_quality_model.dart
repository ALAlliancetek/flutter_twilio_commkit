/// Network quality level (0-5).
class NetworkQualityModel {
  const NetworkQualityModel({
    required this.level,
    required this.participantSid,
  });

  /// Quality level: 0 = unknown, 1 = poor, 5 = excellent.
  final int level;
  final String participantSid;

  factory NetworkQualityModel.fromMap(Map<String, dynamic> map) {
    return NetworkQualityModel(
      level: map['level'] as int,
      participantSid: map['participantSid'] as String,
    );
  }

  Map<String, dynamic> toMap() => {
        'level': level,
        'participantSid': participantSid,
      };
}

