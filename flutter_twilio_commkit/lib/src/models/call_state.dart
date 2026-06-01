/// State of a Twilio Voice Call.
enum CallState { connecting, connected, disconnected, reconnecting, failed, ringing, incoming }

extension CallStateX on CallState {
  static CallState fromString(String value) {
    return switch (value) {
      'connecting' => CallState.connecting,
      'connected' => CallState.connected,
      'disconnected' => CallState.disconnected,
      'reconnecting' => CallState.reconnecting,
      'ringing' => CallState.ringing,
      'incoming' => CallState.incoming,
      _ => CallState.failed,
    };
  }
}

