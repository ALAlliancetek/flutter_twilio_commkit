/// Lightweight in-memory store for the local user's display preferences.
///
/// Set once (e.g. from your settings screen) before starting a call:
///
/// ```dart
/// TwilioUserPreferences.instance
///   ..avatarImageUrl = 'https://example.com/avatar.png';
/// ```
///
/// The SDK's built-in UI reads this to show the user's avatar on the
/// voice call screen, incoming call screen, and the "You" row in the
/// video participant list.
///
/// When [avatarImageUrl] is null the SDK falls back to a plain
/// initial-letter circle derived from the identity string.
class TwilioUserPreferences {
  TwilioUserPreferences._();
  static final TwilioUserPreferences instance = TwilioUserPreferences._();

  /// Optional public image URL (http/https) for the user's profile picture.
  /// When set, the image is loaded and shown as the circular avatar.
  String? avatarImageUrl;

  /// Convenience reset.
  void reset() {
    avatarImageUrl = null;
  }
}
