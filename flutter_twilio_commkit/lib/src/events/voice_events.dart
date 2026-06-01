import '../models/call_state.dart';

/// Strongly-typed voice call events exposed to client apps.
sealed class VoiceCallEvent {
  const VoiceCallEvent();
}

class CallStateChangedEvent extends VoiceCallEvent {
  const CallStateChangedEvent(
      {required this.callSid, required this.state,});
  final String callSid;
  final CallState state;
}

class IncomingCallEvent extends VoiceCallEvent {
  const IncomingCallEvent(
      {required this.callSid, this.from, this.to,});
  final String callSid;
  final String? from;
  final String? to;
}

class CallMutedChangedEvent extends VoiceCallEvent {
  const CallMutedChangedEvent(
      {required this.callSid, required this.isMuted,});
  final String callSid;
  final bool isMuted;
}

class CallHoldChangedEvent extends VoiceCallEvent {
  const CallHoldChangedEvent(
      {required this.callSid, required this.isOnHold,});
  final String callSid;
  final bool isOnHold;
}

class VoiceErrorEvent extends VoiceCallEvent {
  const VoiceErrorEvent({required this.message, required this.code});
  final String message;
  final int code;
}

/// Fired when Twilio detects network quality issues during a call.
/// [warnings] contains labels such as "highJitter", "highPacketsLostFraction",
/// "highRtt", "lowMos", "constantAudioInputLevel".
class CallQualityWarningChangedEvent extends VoiceCallEvent {
  const CallQualityWarningChangedEvent({
    required this.callSid,
    required this.warnings,
  });
  final String callSid;
  final List<String> warnings;
  bool get hasWarnings => warnings.isNotEmpty;
}

