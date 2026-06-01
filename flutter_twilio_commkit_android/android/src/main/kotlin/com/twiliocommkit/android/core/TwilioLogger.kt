package com.twiliocommkit.android

/**
 * Internal logger for the Android plugin.
 */
object TwilioLogger {
    private var level: Level = Level.NONE

    enum class Level { DEBUG, WARNING, ERROR, NONE }

    fun configure(levelName: String) {
        level = when (levelName.lowercase()) {
            "debug" -> Level.DEBUG
            "warning" -> Level.WARNING
            "error" -> Level.ERROR
            else -> Level.NONE
        }
    }

    fun debug(message: String) {
        if (level <= Level.DEBUG) android.util.Log.d("TwilioCommKit", message)
    }

    fun warning(message: String) {
        if (level <= Level.WARNING) android.util.Log.w("TwilioCommKit", message)
    }

    fun error(message: String, throwable: Throwable? = null) {
        if (level <= Level.ERROR) android.util.Log.e("TwilioCommKit", message, throwable)
    }

    private operator fun Level.compareTo(other: Level): Int = ordinal - other.ordinal
}

