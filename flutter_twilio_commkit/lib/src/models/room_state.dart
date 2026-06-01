/// Represents the state of a Twilio Video Room.
enum RoomState { connecting, connected, disconnected, reconnecting, failed }

/// Parsed room state from native layer string.
extension RoomStateX on RoomState {
  static RoomState fromString(String value) {
    return switch (value) {
      'connecting' => RoomState.connecting,
      'connected' => RoomState.connected,
      'disconnected' => RoomState.disconnected,
      'reconnecting' => RoomState.reconnecting,
      _ => RoomState.failed,
    };
  }
}

