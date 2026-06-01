import 'package:flutter_twilio_commkit_platform_interface/flutter_twilio_commkit_platform_interface.dart'
    show VoiceCallModel;

import '../models/call_state.dart';

/// Represents an active Twilio Voice Call.
class VoiceCall {
  const VoiceCall({
    required this.callSid,
    required this.state,
    this.from,
    this.to,
    this.isMuted = false,
    this.isOnHold = false,
  });

  final String callSid;
  final CallState state;
  final String? from;
  final String? to;
  final bool isMuted;
  final bool isOnHold;

  factory VoiceCall.fromModel(VoiceCallModel model) {
    return VoiceCall(
      callSid: model.callSid,
      state: CallStateX.fromString(model.state),
      from: model.from,
      to: model.to,
      isMuted: model.isMuted,
      isOnHold: model.isOnHold,
    );
  }

  VoiceCall copyWith({
    String? callSid,
    CallState? state,
    String? from,
    String? to,
    bool? isMuted,
    bool? isOnHold,
  }) {
    return VoiceCall(
      callSid: callSid ?? this.callSid,
      state: state ?? this.state,
      from: from ?? this.from,
      to: to ?? this.to,
      isMuted: isMuted ?? this.isMuted,
      isOnHold: isOnHold ?? this.isOnHold,
    );
  }
}

