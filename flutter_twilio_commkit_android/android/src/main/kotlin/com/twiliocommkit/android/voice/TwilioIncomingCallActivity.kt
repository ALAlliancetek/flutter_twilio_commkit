package com.twiliocommkit.android.voice

import android.app.Activity
import android.app.KeyguardManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioAttributes
import android.media.Ringtone
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import android.view.WindowManager

/**
 * Full-screen incoming call Activity bundled inside the SDK.
 *
 * Plays the default system ringtone while the screen is visible.
 * On **Accept** → stops ringtone and starts the host app.
 * On **Decline** → stops ringtone, rejects the CallInvite and finishes.
 */
class TwilioIncomingCallActivity : Activity() {

    private val callSid: String by lazy {
        intent.getStringExtra(TwilioVoiceNotificationHandler.EXTRA_CALL_SID) ?: ""
    }
    private val callerName: String by lazy {
        (intent.getStringExtra(TwilioVoiceNotificationHandler.EXTRA_FROM) ?: "Unknown")
            .removePrefix("client:")
    }

    private var ringtone: Ringtone? = null

    private val cancelReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.getStringExtra(TwilioVoiceNotificationHandler.EXTRA_CALL_SID) == callSid) {
                stopRingtone()
                finish()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // setShowWhenLocked / setTurnScreenOn must be called before super.onCreate()
        // on API 27+ so the window token is configured correctly from the start.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }

        super.onCreate(savedInstanceState)

        // Window flags must be applied AFTER super.onCreate() (window is now available)
        // but BEFORE setContentView so the layout inflates with the correct window config.
        @Suppress("DEPRECATION")
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
        )

        // For devices with a secure lock screen (PIN / pattern / biometric),
        // requestDismissKeyguard prompts the user to authenticate. The call UI
        // is shown immediately over the keyguard so they can Accept/Decline first.
        (getSystemService(KEYGUARD_SERVICE) as? KeyguardManager)?.let { km ->
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                km.requestDismissKeyguard(this, null)
            }
        }

        setContentView(buildLayout())
        startRingtone()

        val filter = IntentFilter(TwilioVoiceNotificationHandler.ACTION_CANCEL_CALL)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(cancelReceiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(cancelReceiver, filter)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        stopRingtone()
        try { unregisterReceiver(cancelReceiver) } catch (_: Exception) {}
    }

    // ── Ringtone ──────────────────────────────────────────────────────────────

    private fun startRingtone() {
        try {
            val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            ringtone = RingtoneManager.getRingtone(applicationContext, uri)?.also { r ->
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    r.isLooping = true
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    r.audioAttributes = AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                }
                r.play()
            }
        } catch (_: Exception) { /* best-effort */ }
    }

    private fun stopRingtone() {
        try {
            ringtone?.stop()
            ringtone = null
        } catch (_: Exception) {}
    }

    // ── Actions ───────────────────────────────────────────────────────────────

    private fun onAccept() {
        stopRingtone()
        TwilioVoiceNotificationHandler.dismissIncomingCallNotification(this)
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP
            action = TwilioVoiceNotificationHandler.ACTION_INCOMING_CALL
            putExtra(TwilioVoiceNotificationHandler.EXTRA_CALL_SID, callSid)
            putExtra(TwilioVoiceNotificationHandler.EXTRA_FROM, callerName)
            putExtra(EXTRA_ACCEPTED, true)
        }
        if (launchIntent != null) startActivity(launchIntent)
        finish()
    }


    private fun onReject() {
        stopRingtone()
        TwilioVoiceCallInviteStore.pendingCallInvite?.reject(this)
        TwilioVoiceCallInviteStore.pendingCallInvite = null
        TwilioVoiceNotificationHandler.dismissIncomingCallNotification(this)
        finish()
    }

    // ── Programmatic UI ───────────────────────────────────────────────────────

    private fun buildLayout(): android.view.View {
        val root = android.widget.LinearLayout(this).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            gravity = android.view.Gravity.CENTER
            setBackgroundColor(android.graphics.Color.parseColor("#0D0020"))
            layoutParams = android.view.ViewGroup.LayoutParams(
                android.view.ViewGroup.LayoutParams.MATCH_PARENT,
                android.view.ViewGroup.LayoutParams.MATCH_PARENT
            )
        }

        // Avatar
        val avatar = android.widget.FrameLayout(this).apply {
            val s = dp(100)
            layoutParams = android.widget.LinearLayout.LayoutParams(s, s).apply {
                gravity = android.view.Gravity.CENTER_HORIZONTAL
                bottomMargin = dp(20)
            }
            background = circleDrawable(android.graphics.Color.parseColor("#3D0060"))
        }
        android.widget.ImageView(this).apply {
            setImageResource(android.R.drawable.ic_menu_myplaces)
            setColorFilter(android.graphics.Color.WHITE)
            val p = dp(18); setPadding(p, p, p, p)
            layoutParams = android.widget.FrameLayout.LayoutParams(
                android.view.ViewGroup.LayoutParams.MATCH_PARENT,
                android.view.ViewGroup.LayoutParams.MATCH_PARENT
            )
        }.also { avatar.addView(it) }
        root.addView(avatar)

        // Caller name
        root.addView(android.widget.TextView(this).apply {
            text = callerName
            textSize = 26f
            setTextColor(android.graphics.Color.WHITE)
            gravity = android.view.Gravity.CENTER
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            layoutParams = android.widget.LinearLayout.LayoutParams(
                android.view.ViewGroup.LayoutParams.WRAP_CONTENT,
                android.view.ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply { gravity = android.view.Gravity.CENTER_HORIZONTAL }
        })

        // Subtitle
        root.addView(android.widget.TextView(this).apply {
            text = "Incoming Voice Call"
            textSize = 14f
            setTextColor(android.graphics.Color.parseColor("#AAAAAA"))
            gravity = android.view.Gravity.CENTER
            layoutParams = android.widget.LinearLayout.LayoutParams(
                android.view.ViewGroup.LayoutParams.WRAP_CONTENT,
                android.view.ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {
                gravity = android.view.Gravity.CENTER_HORIZONTAL
                topMargin = dp(8); bottomMargin = dp(60)
            }
        })

        // Buttons row
        val row = android.widget.LinearLayout(this).apply {
            orientation = android.widget.LinearLayout.HORIZONTAL
            gravity = android.view.Gravity.CENTER
            layoutParams = android.widget.LinearLayout.LayoutParams(
                android.view.ViewGroup.LayoutParams.MATCH_PARENT,
                android.view.ViewGroup.LayoutParams.WRAP_CONTENT
            )
        }
        row.addView(callButton(android.R.drawable.ic_menu_close_clear_cancel, "Decline",
            android.graphics.Color.parseColor("#CC0000"), ::onReject))
        row.addView(android.view.View(this).apply {
            layoutParams = android.widget.LinearLayout.LayoutParams(dp(80), 1)
        })
        row.addView(callButton(android.R.drawable.ic_menu_call, "Accept",
            android.graphics.Color.parseColor("#1B8C1B"), ::onAccept))
        root.addView(row)
        return root
    }

    private fun callButton(iconRes: Int, label: String, color: Int, action: () -> Unit)
            : android.widget.LinearLayout {
        val col = android.widget.LinearLayout(this).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            gravity = android.view.Gravity.CENTER
            layoutParams = android.widget.LinearLayout.LayoutParams(
                android.view.ViewGroup.LayoutParams.WRAP_CONTENT,
                android.view.ViewGroup.LayoutParams.WRAP_CONTENT
            )
        }
        col.addView(android.widget.ImageButton(this).apply {
            setImageResource(iconRes); setColorFilter(android.graphics.Color.WHITE)
            val s = dp(70)
            layoutParams = android.widget.LinearLayout.LayoutParams(s, s).apply {
                gravity = android.view.Gravity.CENTER_HORIZONTAL
            }
            background = circleDrawable(color)
            val p = dp(16); setPadding(p, p, p, p)
            setOnClickListener { action() }
        })
        col.addView(android.widget.TextView(this).apply {
            text = label; textSize = 13f; setTextColor(android.graphics.Color.WHITE)
            gravity = android.view.Gravity.CENTER
            layoutParams = android.widget.LinearLayout.LayoutParams(
                android.view.ViewGroup.LayoutParams.WRAP_CONTENT,
                android.view.ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply { gravity = android.view.Gravity.CENTER_HORIZONTAL; topMargin = dp(8) }
        })
        return col
    }

    private fun circleDrawable(color: Int) =
        android.graphics.drawable.ShapeDrawable(
            android.graphics.drawable.shapes.OvalShape()
        ).apply { paint.color = color }

    private fun dp(v: Int) = (v * resources.displayMetrics.density).toInt()

    companion object {
        const val EXTRA_ACCEPTED = "twi_call_accepted"
    }
}

