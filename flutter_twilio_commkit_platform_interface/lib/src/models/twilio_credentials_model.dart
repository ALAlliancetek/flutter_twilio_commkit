/// Platform-layer representation of Twilio credentials.
/// Passed from Flutter to native via MethodChannel during [initialize].
class TwilioCredentialsModel {
  const TwilioCredentialsModel({
    required this.accountSid,
    required this.apiKeySid,
    this.pushCredentialSid,
    this.outgoingApplicationSid,
  });

  final String accountSid;
  final String apiKeySid;

  /// Push Credential SID (starts with `CR`) — for incoming call push notifications.
  final String? pushCredentialSid;

  /// TwiML Application SID (starts with `AP`) — for outgoing voice calls.
  final String? outgoingApplicationSid;

  Map<String, dynamic> toMap() => {
        'accountSid': accountSid,
        'apiKeySid': apiKeySid,
        if (pushCredentialSid != null) 'pushCredentialSid': pushCredentialSid,
        if (outgoingApplicationSid != null)
          'outgoingApplicationSid': outgoingApplicationSid,
      };

  factory TwilioCredentialsModel.fromMap(Map<String, dynamic> map) {
    return TwilioCredentialsModel(
      accountSid: map['accountSid'] as String,
      apiKeySid: map['apiKeySid'] as String,
      pushCredentialSid: map['pushCredentialSid'] as String?,
      outgoingApplicationSid: map['outgoingApplicationSid'] as String?,
    );
  }
}

