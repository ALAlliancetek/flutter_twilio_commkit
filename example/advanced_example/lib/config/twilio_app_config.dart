/// ═══════════════════════════════════════════════════════════════════════════
/// TWILIO APP CONFIGURATION — Advanced Example
///
/// Fill in your values from https://console.twilio.com
/// This is the ONLY file you need to edit to test with your Twilio project.
/// ═══════════════════════════════════════════════════════════════════════════

class TwilioAppConfig {
  TwilioAppConfig._();

  // ── Twilio Account credentials ────────────────────────────────────────────
  static const String accountSid = 'ACe78f25b098b2a7e1bd7a62e1faa62eb1';
  static const String apiKeySid = 'SKb9de5b726aa1e078546773a5f61e70e6';

  // ── Voice credentials ─────────────────────────────────────────────────────
  static const String outgoingApplicationSid = 'APb081648e96d68b4aed1a4d708faf5211';
  static const String pushCredentialSid = 'CRce491888ff21b1b069a9cc1bcbd65fa3';

  // ── Token Server ──────────────────────────────────────────────────────────
  // Deploy docs/token_server/ to Render.com for a permanent HTTPS URL.
  // See docs/token_server/README.md for step-by-step instructions.
  static const String tokenServerBaseUrl = 'https://twilio-token-v0ej.onrender.com';

  // ── Test identities ───────────────────────────────────────────────────────
  static const String userIdentity = 'flutter-advanced-1';
  static const String defaultVideoRoom = 'advanced-room-001';
  static const String defaultCallTo = 'flutter-tester-2';
}
