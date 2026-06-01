package com.twiliocommkit.android.voice

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.IBinder
import androidx.core.app.NotificationCompat

/**
 * Foreground service to keep voice calls alive on Android while the app
 * is in the background. Required for Android 8+ background restrictions.
 */
class TwilioCallForegroundService : Service() {

    companion object {
        const val CHANNEL_ID = "twilio_call_channel"
        const val NOTIFICATION_ID = 1001
        const val ACTION_START = "ACTION_START_CALL"
        const val ACTION_STOP = "ACTION_STOP_CALL"
        const val EXTRA_CALLER = "EXTRA_CALLER"
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                val caller = intent.getStringExtra(EXTRA_CALLER) ?: "Unknown"
                startForeground(NOTIFICATION_ID, buildNotification(caller))
            }
            ACTION_STOP -> {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun buildNotification(caller: String): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Active Call")
            .setContentText("In call with $caller")
            .setSmallIcon(TwilioNotificationConfig.resolveSmallIconRes(this))
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Active Calls",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Keeps active calls running in the background"
        }
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }
}

