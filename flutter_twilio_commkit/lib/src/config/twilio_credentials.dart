/// Twilio project credentials provided by the client application.
///
/// All SIDs are sourced from the [Twilio Console](https://console.twilio.com).
/// The SDK **never** generates tokens or stores these values beyond the
/// lifetime of the current SDK session.
///
/// ```dart
/// TwilioCredentials(
///   accountSid: 'ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
///   apiKeySid: 'SKxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
///   // apiKeySecret is optional here — supply it only if you
///   // generate tokens server-side using the SDK helper for testing.
///   // In production, use accessTokenProvider instead.
/// )
/// ```
class TwilioCredentials {
  const TwilioCredentials({
    required this.accountSid,
    required this.apiKeySid,
    this.apiKeySecret,
    this.pushCredentialSid,
    this.outgoingApplicationSid,
  });

  /// Twilio Account SID — starts with `AC`.
  final String accountSid;

  /// API Key SID — starts with `SK`. Used for token generation and auth.
  final String apiKeySid;

  /// API Key Secret — used ONLY in a trusted server environment.
  /// Do NOT embed this in your Flutter app binary in production.
  final String? apiKeySecret;

  /// Push Credential SID — starts with `CR`.
  /// Required for incoming call push notifications (VoIP/FCM).
  ///
  /// **Twilio Error 52005** ("The stored credential has invalid contents"):
  ///
  /// This error means the push credential stored in Twilio Console for this
  /// SID is expired, wrong environment, or malformed. To fix:
  ///
  /// **Android (FCM v1)**:
  ///   1. Firebase Console → Project Settings → Service Accounts → Generate new private key
  ///   2. Twilio Console → Voice → Push Credentials → Create (FCM v1) → upload JSON
  ///   3. Update this SID to the new CR... value
  ///
  /// **iOS (APNs VoIP)**:
  ///   1. Apple Developer Portal → renew VoIP Services Certificate
  ///   2. Export .p12 from Keychain Access
  ///   3. Twilio Console → Voice → Push Credentials → Create (APN) → upload .p12
  ///   4. Use SANDBOX cert for debug builds, PRODUCTION cert for release
  ///   5. Update this SID to the new CR... value
  final String? pushCredentialSid;

  /// TwiML Application SID — starts with `AP`.
  /// Required for outgoing voice calls via TwiML.
  final String? outgoingApplicationSid;

  /// Validates that required SIDs are in expected formats.
  void validate() {
    assert(
      accountSid.startsWith('AC') && accountSid.length == 34,
      'accountSid must be 34 chars starting with "AC". Got: $accountSid',
    );
    assert(
      apiKeySid.startsWith('SK') && apiKeySid.length == 34,
      'apiKeySid must be 34 chars starting with "SK". Got: $apiKeySid',
    );
    if (pushCredentialSid != null) {
      assert(
        pushCredentialSid!.startsWith('CR') && pushCredentialSid!.length == 34,
        'pushCredentialSid must start with "CR".',
      );
    }
    if (outgoingApplicationSid != null) {
      assert(
        outgoingApplicationSid!.startsWith('AP') &&
            outgoingApplicationSid!.length == 34,
        'outgoingApplicationSid must start with "AP".',
      );
    }
  }

  /// Returns a sanitized map safe for logging (no secrets).
  Map<String, String?> toSafeMap() => {
        'accountSid': accountSid,
        'apiKeySid': apiKeySid,
        'apiKeySecret': apiKeySecret != null ? '***hidden***' : null,
        'pushCredentialSid': pushCredentialSid,
        'outgoingApplicationSid': outgoingApplicationSid,
      };
}

