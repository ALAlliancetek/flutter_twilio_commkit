/// Network quality level for a participant (0–5).
class NetworkQuality {
  const NetworkQuality({required this.level, required this.participantSid});

  /// 0 = unknown, 1 = poor … 5 = excellent.
  final int level;
  final String participantSid;

  bool get isGood => level >= 3;
}

