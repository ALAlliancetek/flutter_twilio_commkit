package com.twiliocommkit.android.core

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/**
 * Thread-safe EventChannel.EventSink wrapper.
 *
 * Key behaviours:
 * - Buffers events that arrive BEFORE Flutter starts listening (onListen)
 * - Always dispatches on the main thread (required by Flutter platform channels)
 * - Flushes buffer immediately when Flutter listener attaches
 */
class TwilioEventSink : EventChannel.StreamHandler {

    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var sink: EventChannel.EventSink? = null

    // Buffer events that arrive before Flutter is listening
    private val pendingEvents = mutableListOf<Map<String, Any?>>()

    override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink) {
        sink = eventSink
        // Flush any buffered events
        val events = synchronized(pendingEvents) {
            val copy = pendingEvents.toList()
            pendingEvents.clear()
            copy
        }
        events.forEach { eventSink.success(it) }
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    /**
     * Sends [event] to Flutter. Safe to call from any thread.
     * If Flutter is not yet listening, the event is buffered and sent
     * as soon as [onListen] is called.
     */
    fun send(event: Map<String, Any?>) {
        mainHandler.post {
            val s = sink
            if (s != null) {
                s.success(event)
            } else {
                synchronized(pendingEvents) {
                    pendingEvents.add(event)
                }
            }
        }
    }

    /**
     * Sends an error event to Flutter.
     */
    fun sendError(code: String, message: String, details: Any? = null) {
        mainHandler.post {
            sink?.error(code, message, details)
        }
    }
}
