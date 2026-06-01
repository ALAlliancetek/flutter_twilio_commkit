/// ═══════════════════════════════════════════════════════════════════════════
/// TWILIO APP CONFIGURATION
///
/// Fill in your values from https://console.twilio.com
/// This is the ONLY file you need to edit to test with your Twilio project.
/// ═══════════════════════════════════════════════════════════════════════════

class TwilioAppConfig {
  TwilioAppConfig._();

  // ── Twilio Account credentials ────────────────────────────────────────────
  // https://console.twilio.com → Account Info

  /// Your Twilio Account SID (starts with AC)
  static const String accountSid = 'ACe78f25b098b2a7e1bd7a62e1faa62eb1';

  /// Your Twilio API Key SID (starts with SK)
  /// Create at: https://console.twilio.com/us1/account/keys-credentials/api-keys
  static const String apiKeySid = 'SKb9de5b726aa1e078546773a5f61e70e6';

  // ── Voice credentials (optional — only needed for voice calls) ────────────

  /// TwiML Application SID for outgoing Voice calls (starts with AP)
  /// Create at: https://console.twilio.com → Voice → TwiML Apps
  static const String outgoingApplicationSid = 'APb081648e96d68b4aed1a4d708faf5211';

  /// Push Credential SID for incoming call push notifications (starts with CR)
  /// Create at: https://console.twilio.com → Voice → Push Credentials
  ///
  /// ERROR 52005 FIX:
  /// The current credential SID points to an invalid/expired push credential.
  ///
  /// Android — Re-create using FCM v1 (HTTP v2):
  ///   1. Firebase Console → Project Settings → Service Accounts → Generate new private key
  ///   2. Twilio Console → Voice → Push Credentials → Create (FCM v1) → Upload JSON
  ///   3. Replace this SID with the new CR... value
  ///
  /// iOS — Re-create using a fresh VoIP certificate:
  ///   1. Apple Developer Portal → Certificates → VoIP Services Certificate (renew/create)
  ///   2. Export .p12 from Keychain Access
  ///   3. Twilio Console → Voice → Push Credentials → Create (APN) → Upload .p12
  ///   4. Use SANDBOX cert for debug, PRODUCTION cert for release
  ///   5. Replace this SID with the new CR... value
  static const String pushCredentialSid = 'CRce491888ff21b1b069a9cc1bcbd65fa3'; // ← REPLACE with new SID after fixing credential in Twilio Console

  // ── Token Server ──────────────────────────────────────────────────────────
  // Your backend server that generates Twilio Access Tokens.
  //
  // Deploy docs/token_server/ to Render.com for a permanent HTTPS URL.
  // See docs/token_server/README.md for step-by-step instructions.
  //
  // After deploying, set this to your Render URL:
  //   e.g. 'https://twilio-token-server.onrender.com'
  //
  // For local testing with Android emulator: use http://10.0.2.2:3000
  // For local testing with iOS simulator:    use http://localhost:3000

  static const String tokenServerBaseUrl = 'https://twilio-token-v0ej.onrender.com';

  // ── Test identities ───────────────────────────────────────────────────────

  /// Identity used for this device in the test app.
  static const String userIdentity = 'flutter-tester-1';

  /// Default video room name to join.
  static const String defaultVideoRoom = 'test-room-001';

  /// Default phone number OR Twilio client identity to call.
  /// For device-to-device testing use the other device's identity string.
  /// e.g. 'flutter-tester-2'
  /// For calling a real phone use E.164 format: '+15551234567'
  static const String defaultCallTo = 'flutter-tester-2';
}

