package com.twiliocommkit.android.voice

import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.twiliocommkit.android.TwilioLogger

/**
 * Firebase Cloud Messaging service bundled inside the SDK.
 *
 * Receives FCM push messages and delegates Twilio Voice messages to
 * [TwilioVoiceNotificationHandler], which stores the [CallInvite] and
 * shows the full-screen [TwilioIncomingCallActivity].
 *
 * Host apps only need to declare this in their AndroidManifest.xml — no Kotlin
 * code required:
 * ```xml
 * <service
 *     android:name="com.twiliocommkit.android.voice.TwilioFcmService"
 *     android:exported="false">
 *     <intent-filter>
 *         <action android:name="com.google.firebase.MESSAGING_EVENT"/>
 *     </intent-filter>
 * </service>
 * ```
 */
class TwilioFcmService : FirebaseMessagingService() {

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        val handled = TwilioVoiceNotificationHandler.handleMessage(
            context = applicationContext,
            data = remoteMessage.data
        )
        if (handled) {
            TwilioLogger.debug("TwilioFcmService: Twilio Voice message handled")
        }
        // Non-Twilio messages are ignored here — host apps that need to handle
        // other FCM messages should subclass this service and call super.onMessageReceived().
    }

    override fun onNewToken(token: String) {
        // FCM token refresh is handled by the Flutter layer via
        // FirebaseMessaging.instance.onTokenRefresh in NotificationService.
        TwilioLogger.debug("TwilioFcmService: FCM token refreshed")
    }
}

