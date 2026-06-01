package com.twiliocommkit.android.core

/**
 * Holds the Twilio project credentials for the current SDK session.
 *
 * Set once during [FlutterTwilioCommKitAndroidPlugin.initialize] and
 * accessible by all managers via the [current] singleton reference.
 */
data class TwilioSdkCredentials(
    /** Twilio Account SID — starts with AC */
    val accountSid: String,
    /** API Key SID — starts with SK */
    val apiKeySid: String,
    /** Push Credential SID — starts with CR (optional) */
    val pushCredentialSid: String?,
    /** TwiML Application SID — starts with AP (optional, used for outgoing calls) */
    val outgoingApplicationSid: String?
) {
    companion object {
        /** Current session credentials. Null until initialize() is called. */
        @Volatile
        var current: TwilioSdkCredentials? = null
    }
}

