package com.twiliocommkit.android.voice

import android.Manifest
import android.app.ActivityManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.twilio.voice.CallInvite
import com.twilio.voice.CallException
import com.twilio.voice.CancelledCallInvite
import com.twilio.voice.MessageListener
import com.twilio.voice.Voice
import com.twiliocommkit.android.TwilioLogger

/**
 * Handles incoming Twilio Voice push notification messages.
 *
 * Integrate into your app's FirebaseMessagingService:
 *
 * ```kotlin
 * class MyFirebaseMessagingService : FirebaseMessagingService() {
 *     override fun onMessageReceived(remoteMessage: RemoteMessage) {
 *         if (TwilioVoiceNotificationHandler.handleMessage(applicationContext, remoteMessage.data)) {
 *             return // Twilio consumed it
 *         }
 *         // Handle your own FCM messages…
 *     }
 * }
 * ```
 */
object TwilioVoiceNotificationHandler {

    const val CHANNEL_ID = "twilio_voice_calls"
    const val CHANNEL_NAME = "Incoming Calls"
    const val INCOMING_CALL_NOTIFICATION_ID = 1001

    // Intent action sent as a broadcast so Flutter can show the incoming call UI
    const val ACTION_INCOMING_CALL = "com.twiliocommkit.INCOMING_CALL"
    const val ACTION_CANCEL_CALL  = "com.twiliocommkit.CANCEL_CALL"
    const val EXTRA_CALL_INVITE   = "call_invite"
    const val EXTRA_CALL_SID      = "call_sid"
    const val EXTRA_FROM          = "from"

    /**
     * Returns true if this FCM message was a Twilio Voice message and was handled.
     *
     * @param data  RemoteMessage.data map
     * @param accessToken  The Twilio access token for this device (used to validate the push)
     */
    fun handleMessage(
        context: Context,
        data: Map<String, String>,
        accessToken: String? = null
    ): Boolean {
        if (!Voice.handleMessage(context, data, object : MessageListener {
                override fun onCallInvite(callInvite: CallInvite) {
                    TwilioLogger.debug("FCM: CallInvite received from=${callInvite.from} sid=${callInvite.callSid}")
                    TwilioVoiceCallInviteStore.pendingCallInvite = callInvite
                    sendIncomingCallBroadcast(context, callInvite)

                    val from = callInvite.from?.removePrefix("client:") ?: "Unknown"
                    if (isAppInForeground(context)) {
                        // Android suppresses fullScreenIntent when app is in foreground.
                        // Launch TwilioIncomingCallActivity directly — singleInstance ensures
                        // only one instance is created even if called multiple times.
                        TwilioLogger.debug("FCM: app is foreground — launching TwilioIncomingCallActivity directly")
                        val activityIntent = Intent(context, TwilioIncomingCallActivity::class.java).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_USER_ACTION
                            putExtra(EXTRA_CALL_SID, callInvite.callSid)
                            putExtra(EXTRA_FROM, from)
                        }
                        context.startActivity(activityIntent)
                    }
                    // Always post the notification so it appears in the status bar / lock screen
                    // and acts as the fullScreenIntent trigger for background/killed scenarios.
                    showIncomingCallNotification(context, callInvite)
                }

                override fun onCancelledCallInvite(
                    cancelledCallInvite: CancelledCallInvite,
                    ex: CallException?
                ) {
                    TwilioLogger.debug("FCM: CallInvite cancelled sid=${cancelledCallInvite.callSid}")
                    TwilioVoiceCallInviteStore.pendingCallInvite = null
                    sendCancelCallBroadcast(context, cancelledCallInvite.callSid)
                    dismissIncomingCallNotification(context)
                }
            })) {
            return false // Not a Twilio message
        }
        return true
    }

    /** Returns true when the app process is currently visible/foreground. */
    private fun isAppInForeground(context: Context): Boolean {
        val am = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val processes = am.runningAppProcesses ?: return false
        return processes.any {
            it.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND &&
            it.processName == context.packageName
        }
    }

    // ── Notification ─────────────────────────────────────────────────────────

    fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Incoming Twilio voice call notifications"
                enableVibration(true)
                setShowBadge(true)
                // Show notification content on the lock screen
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            }
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(channel)
        }
    }

    private fun showIncomingCallNotification(context: Context, callInvite: CallInvite) {
        createNotificationChannel(context)

        val from = callInvite.from?.removePrefix("client:") ?: "Unknown"
        val callSid = callInvite.callSid

        val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        else
            PendingIntent.FLAG_UPDATE_CURRENT

        // Full-screen intent: launches the SDK's TwilioIncomingCallActivity directly
        val fullScreenIntent = Intent(context, TwilioIncomingCallActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_USER_ACTION
            putExtra(EXTRA_CALL_SID, callSid)
            putExtra(EXTRA_FROM, from)
        }

        val fullScreenPendingIntent = PendingIntent.getActivity(
            context, callSid.hashCode(), fullScreenIntent, pendingFlags
        )

        // Content intent: tapping notification banner also opens IncomingCallActivity
        val contentPendingIntent = PendingIntent.getActivity(
            context, callSid.hashCode() + 1, fullScreenIntent, pendingFlags
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(TwilioNotificationConfig.resolveSmallIconRes(context))
            .setContentTitle("Incoming Call")
            .setContentText("$from is calling…")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .setContentIntent(contentPendingIntent)
            .setAutoCancel(false)
            .setOngoing(true)
            .build()

        if (ActivityCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS)
            == PackageManager.PERMISSION_GRANTED || Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU
        ) {
            NotificationManagerCompat.from(context)
                .notify(INCOMING_CALL_NOTIFICATION_ID, notification)
        }
    }

    fun dismissIncomingCallNotification(context: Context) {
        NotificationManagerCompat.from(context).cancel(INCOMING_CALL_NOTIFICATION_ID)
    }

    private fun sendIncomingCallBroadcast(context: Context, callInvite: CallInvite) {
        val intent = Intent(ACTION_INCOMING_CALL).apply {
            putExtra(EXTRA_CALL_SID, callInvite.callSid)
            putExtra(EXTRA_FROM, callInvite.from ?: "Unknown")
            setPackage(context.packageName)
        }
        context.sendBroadcast(intent)
    }

    private fun sendCancelCallBroadcast(context: Context, callSid: String) {
        val intent = Intent(ACTION_CANCEL_CALL).apply {
            putExtra(EXTRA_CALL_SID, callSid)
            setPackage(context.packageName)
        }
        context.sendBroadcast(intent)
    }
}

/**
 * Singleton store for the current pending CallInvite.
 * Used when the app is brought to foreground after receiving an incoming call.
 * TwilioVoiceManager.acceptCall() reads from here so it can accept with the
 * proper callListener and emit Flutter events correctly.
 */
object TwilioVoiceCallInviteStore {
    var pendingCallInvite: CallInvite? = null
}

