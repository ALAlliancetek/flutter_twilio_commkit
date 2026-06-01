/// Strongly typed voice events from the native layer.
sealed class VoiceEvent {
  const VoiceEvent();

  factory VoiceEvent.fromMap(Map<String, dynamic> map) {
    final type = map['type'] as String;
    return switch (type) {
      'callConnecting' => CallConnectingEvent(
          callSid: map['callSid'] as String,
        ),
      'callRinging' => CallRingingEvent(
          callSid: map['callSid'] as String,
        ),
      'callConnected' => CallConnectedEvent(
          callSid: map['callSid'] as String,
          from: map['from'] as String?,
          to: map['to'] as String?,
        ),
      'callDisconnected' => CallDisconnectedEvent(
          callSid: map['callSid'] as String,
          errorCode: map['errorCode'] as int? ?? 0,
          errorMessage: map['errorMessage'] as String? ?? '',
        ),
      'callFailed' => CallFailedEvent(
          callSid: map['callSid'] as String?,
          message: map['message'] as String,
          code: map['code'] as int? ?? -1,
        ),
      'callIncoming' => CallIncomingEvent(
          callSid: map['callSid'] as String,
          from: map['from'] as String?,
          to: map['to'] as String?,
        ),
      'callReconnecting' => CallReconnectingEvent(
          callSid: map['callSid'] as String,
        ),
      'callReconnected' => CallReconnectedEvent(
          callSid: map['callSid'] as String,
        ),
      'callMuted' => CallMutedEvent(
          callSid: map['callSid'] as String,
          isMuted: map['isMuted'] as bool,
        ),
      'callHeld' => CallHeldEvent(
          callSid: map['callSid'] as String,
          isOnHold: map['isOnHold'] as bool,
        ),
      'callQualityWarning' => CallQualityWarningEvent(
          callSid: map['callSid'] as String,
          warnings: (map['warnings'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [],
        ),
      _ => UnknownVoiceEvent(raw: map),
    };
  }
}

class CallConnectingEvent extends VoiceEvent {
  const CallConnectingEvent({required this.callSid});
  final String callSid;
}

class CallRingingEvent extends VoiceEvent {
  const CallRingingEvent({required this.callSid});
  final String callSid;
}

class CallConnectedEvent extends VoiceEvent {
  const CallConnectedEvent({required this.callSid, this.from, this.to});
  final String callSid;
  final String? from;
  final String? to;
}

class CallDisconnectedEvent extends VoiceEvent {
  const CallDisconnectedEvent({
    required this.callSid,
    this.errorCode = 0,
    this.errorMessage = '',
  });
  final String callSid;
  /// 0 = normal hangup, non-zero = error disconnect
  final int errorCode;
  final String errorMessage;
}

class CallFailedEvent extends VoiceEvent {
  const CallFailedEvent({this.callSid, required this.message, required this.code});
  final String? callSid;
  final String message;
  final int code;
}

class CallIncomingEvent extends VoiceEvent {
  const CallIncomingEvent({required this.callSid, this.from, this.to});
  final String callSid;
  final String? from;
  final String? to;
}

class CallReconnectingEvent extends VoiceEvent {
  const CallReconnectingEvent({required this.callSid});
  final String callSid;
}

class CallReconnectedEvent extends VoiceEvent {
  const CallReconnectedEvent({required this.callSid});
  final String callSid;
}

class CallMutedEvent extends VoiceEvent {
  const CallMutedEvent({required this.callSid, required this.isMuted});
  final String callSid;
  final bool isMuted;
}

class CallHeldEvent extends VoiceEvent {
  const CallHeldEvent({required this.callSid, required this.isOnHold});
  final String callSid;
  final bool isOnHold;
}

class CallQualityWarningEvent extends VoiceEvent {
  const CallQualityWarningEvent({
    required this.callSid,
    required this.warnings,
  });
  final String callSid;
  /// List of active warning labels e.g. ["highJitter", "highPacketsLostFraction"]
  final List<String> warnings;
}

class UnknownVoiceEvent extends VoiceEvent {
  const UnknownVoiceEvent({required this.raw});
  final Map<String, dynamic> raw;
}
