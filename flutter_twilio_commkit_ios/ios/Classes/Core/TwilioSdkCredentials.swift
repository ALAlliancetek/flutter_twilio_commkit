import Foundation

/// Holds the Twilio project credentials for the current SDK session.
/// Set once during initialize() and accessible by all managers.
final class TwilioSdkCredentials {

    /// Twilio Account SID — starts with `AC`.
    let accountSid: String

    /// API Key SID — starts with `SK`.
    let apiKeySid: String

    /// Push Credential SID — starts with `CR` (optional).
    let pushCredentialSid: String?

    /// TwiML Application SID — starts with `AP` (optional).
    let outgoingApplicationSid: String?

    init(
        accountSid: String,
        apiKeySid: String,
        pushCredentialSid: String? = nil,
        outgoingApplicationSid: String? = nil
    ) {
        self.accountSid = accountSid
        self.apiKeySid = apiKeySid
        self.pushCredentialSid = pushCredentialSid
        self.outgoingApplicationSid = outgoingApplicationSid
    }

    /// The current session credentials. `nil` until `initialize()` is called.
    static var current: TwilioSdkCredentials?
}

