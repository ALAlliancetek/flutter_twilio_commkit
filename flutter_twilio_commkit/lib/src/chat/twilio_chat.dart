/// Placeholder for future Twilio Chat/Conversations module.
///
/// This class is intentionally minimal. The chat architecture will be
/// implemented in a future release without breaking existing APIs.
class TwilioChat {
  TwilioChat._();

  static final TwilioChat _instance = TwilioChat._();

  /// Singleton instance.
  static TwilioChat get instance => _instance;

  // TODO(chat): Implement Twilio Conversations integration.
  // Planned features:
  // - createConversation()
  // - sendMessage()
  // - getMessages()
  // - onMessageReceived stream
  // - onTypingStarted / onTypingStopped
  // - readReceipts
  // - presence
  // - push notification hooks
}

