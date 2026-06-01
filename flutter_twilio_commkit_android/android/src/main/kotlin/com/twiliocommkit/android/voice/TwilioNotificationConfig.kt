package com.twiliocommkit.android.voice

import android.content.Context
import com.twiliocommkit.android.TwilioLogger

/**
 * Shared configuration for SDK notifications.
 *
 * Host apps set [notificationIconName] via [TwilioVoiceConfig.notificationIconName]
 * during SDK initialisation. The name must match a drawable resource in the
 * host app (e.g. `"ic_notification"` for `res/drawable/ic_notification.png`).
 */
object TwilioNotificationConfig {

    /** Drawable resource name supplied by the host app. Null = use SDK default. */
    var notificationIconName: String? = null

    /**
     * Resolves the notification small-icon resource ID.
     *
     * Lookup order:
     *  1. [notificationIconName] in the host app's `drawable` package
     *  2. [notificationIconName] in the host app's `mipmap` package
     *  3. Fallback: `android.R.drawable.ic_menu_call`
     */
    fun resolveSmallIconRes(context: Context): Int {
        val name = notificationIconName
        if (!name.isNullOrBlank()) {
            // Try drawable first
            val drawableId = context.resources.getIdentifier(
                name, "drawable", context.packageName
            )
            if (drawableId != 0) {
                TwilioLogger.debug("NotificationConfig: using drawable/$name")
                return drawableId
            }
            // Try mipmap
            val mipmapId = context.resources.getIdentifier(
                name, "mipmap", context.packageName
            )
            if (mipmapId != 0) {
                TwilioLogger.debug("NotificationConfig: using mipmap/$name")
                return mipmapId
            }
            TwilioLogger.warning("NotificationConfig: resource '$name' not found in drawable or mipmap — using default")
        }
        return android.R.drawable.ic_menu_call
    }
}

