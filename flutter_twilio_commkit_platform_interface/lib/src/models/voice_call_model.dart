/// Represents a Twilio Voice Call.
class VoiceCallModel {
  const VoiceCallModel({
    required this.callSid,
    required this.state,
    this.from,
    this.to,
    this.isMuted = false,
    this.isOnHold = false,
  });

  final String callSid;
  final String state;
  final String? from;
  final String? to;
  final bool isMuted;
  final bool isOnHold;

  factory VoiceCallModel.fromMap(Map<String, dynamic> map) {
    return VoiceCallModel(
      callSid: map['callSid'] as String,
      state: map['state'] as String,
      from: map['from'] as String?,
      to: map['to'] as String?,
      isMuted: map['isMuted'] as bool? ?? false,
      isOnHold: map['isOnHold'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'callSid': callSid,
        'state': state,
        'from': from,
        'to': to,
        'isMuted': isMuted,
        'isOnHold': isOnHold,
      };

  VoiceCallModel copyWith({
    String? callSid,
    String? state,
    String? from,
    String? to,
    bool? isMuted,
    bool? isOnHold,
  }) {
    return VoiceCallModel(
      callSid: callSid ?? this.callSid,
      state: state ?? this.state,
      from: from ?? this.from,
      to: to ?? this.to,
      isMuted: isMuted ?? this.isMuted,
      isOnHold: isOnHold ?? this.isOnHold,
    );
  }
}

