package com.twiliocommkit.android

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel

import com.twiliocommkit.android.video.TwilioVideoManager
import com.twiliocommkit.android.voice.TwilioVoiceManager
import com.twiliocommkit.android.voice.TwilioVoiceNotificationHandler
import com.twiliocommkit.android.voice.TwilioIncomingCallActivity
import com.twiliocommkit.android.core.TwilioEventSink
import com.twiliocommkit.android.core.TwilioSdkCredentials
import com.twiliocommkit.android.video.TwilioVideoViewFactory

/**
 * Flutter plugin entry point for the Android Twilio CommKit implementation.
 */
class FlutterTwilioCommKitAndroidPlugin : FlutterPlugin, MethodCallHandler,
    ActivityAware, PluginRegistry.NewIntentListener {

    private lateinit var methodChannel: MethodChannel
    private lateinit var callHandlerChannel: MethodChannel
    private lateinit var videoEventChannel: EventChannel
    private lateinit var voiceEventChannel: EventChannel

    private val coroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    private lateinit var videoManager: TwilioVideoManager
    private lateinit var voiceManager: TwilioVoiceManager

    private val videoEventSink = TwilioEventSink()
    private val voiceEventSink = TwilioEventSink()

    // Pending incoming call from a launch/new intent (app was killed or in background)
    private var pendingCallSid: String? = null
    private var pendingFrom: String? = null
    private var pendingAccepted: Boolean = false

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val context = binding.applicationContext

        methodChannel = MethodChannel(binding.binaryMessenger, "com.twiliocommkit/methods")
        methodChannel.setMethodCallHandler(this)

        // Dedicated channel for the SDK's TwilioCallHandler to query pending calls
        callHandlerChannel = MethodChannel(binding.binaryMessenger, "com.twiliocommkit/incoming_call")
        callHandlerChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getPendingIncomingCall" -> {
                    if (pendingCallSid != null) {
                        result.success(mapOf(
                            "callSid" to (pendingCallSid ?: ""),
                            "from" to (pendingFrom ?: "Unknown"),
                            "accepted" to pendingAccepted
                        ))
                        pendingCallSid = null
                        pendingFrom = null
                        pendingAccepted = false
                    } else {
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        videoEventChannel = EventChannel(binding.binaryMessenger, "com.twiliocommkit/video_events")
        videoEventChannel.setStreamHandler(videoEventSink)

        voiceEventChannel = EventChannel(binding.binaryMessenger, "com.twiliocommkit/voice_events")
        voiceEventChannel.setStreamHandler(voiceEventSink)

        videoManager = TwilioVideoManager(context, videoEventSink, coroutineScope)
        voiceManager = TwilioVoiceManager(context, voiceEventSink, coroutineScope)

        binding.platformViewRegistry.registerViewFactory(
            "com.twiliocommkit/video_view",
            TwilioVideoViewFactory(videoManager.trackRegistry)
        )
    }

    // ── ActivityAware — needed to read the launch intent ─────────────────────

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        binding.addOnNewIntentListener(this)
        handleIntent(binding.activity.intent, fromLaunch = true)
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        binding.addOnNewIntentListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {}

    override fun onDetachedFromActivity() {}

    override fun onNewIntent(intent: Intent): Boolean {
        handleIntent(intent, fromLaunch = false)
        return false
    }

    private fun handleIntent(intent: Intent?, fromLaunch: Boolean) {
        if (intent?.action == TwilioVoiceNotificationHandler.ACTION_INCOMING_CALL) {
            val callSid  = intent.getStringExtra(TwilioVoiceNotificationHandler.EXTRA_CALL_SID)
            val from     = intent.getStringExtra(TwilioVoiceNotificationHandler.EXTRA_FROM)
                               ?.removePrefix("client:") ?: "Unknown"
            val accepted = intent.getBooleanExtra(TwilioIncomingCallActivity.EXTRA_ACCEPTED, false)
            TwilioLogger.debug("Plugin: incoming call intent fromLaunch=$fromLaunch sid=$callSid accepted=$accepted")

            if (fromLaunch) {
                // App was killed/background — store for Flutter to poll via getPendingIncomingCall
                pendingCallSid  = callSid
                pendingFrom     = from
                pendingAccepted = accepted
            } else {
                // App already running (foreground) — push directly to Flutter via method channel
                callHandlerChannel.invokeMethod("onIncomingCallResult", mapOf(
                    "callSid"  to (callSid ?: ""),
                    "from"     to from,
                    "accepted" to accepted
                ))
            }
        }
    }

    // ── Main method channel ───────────────────────────────────────────────────

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "initialize" -> {
                val logLevel = call.argument<String>("logLevel") ?: "none"
                TwilioLogger.configure(logLevel)

                val credMap = call.argument<Map<String, Any?>>("credentials")
                if (credMap != null) {
                    val creds = TwilioSdkCredentials(
                        accountSid = credMap["accountSid"] as? String ?: "",
                        apiKeySid = credMap["apiKeySid"] as? String ?: "",
                        pushCredentialSid = credMap["pushCredentialSid"] as? String,
                        outgoingApplicationSid = credMap["outgoingApplicationSid"] as? String
                    )
                    TwilioSdkCredentials.current = creds
                    TwilioLogger.debug("Credentials configured: accountSid=${creds.accountSid}")
                }

                val videoConfig = call.argument<Map<String, Any?>>("videoConfig") ?: emptyMap()
                val voiceConfig = call.argument<Map<String, Any?>>("voiceConfig") ?: emptyMap()
                videoManager.applyConfig(videoConfig)
                voiceManager.applyConfig(voiceConfig)

                result.success(null)
            }
            "connectToRoom" -> videoManager.connectToRoom(call, result)
            "disconnectFromRoom" -> videoManager.disconnectFromRoom(call, result)
            "muteVideo" -> videoManager.muteVideo(call, result)
            "muteAudio" -> videoManager.muteAudio(call, result)
            "switchCamera" -> videoManager.switchCamera(result)
            "getParticipants" -> videoManager.getParticipants(call, result)
            "initVoice" -> voiceManager.initVoice(call, result)
            "startCall" -> voiceManager.startCall(call, result)
            "acceptCall" -> voiceManager.acceptCall(call, result)
            "rejectCall" -> voiceManager.rejectCall(call, result)
            "hangUpCall" -> voiceManager.hangUpCall(call, result)
            "muteCall"    -> voiceManager.muteCall(call, result)
            "holdCall"    -> voiceManager.holdCall(call, result)
            "setSpeaker"  -> voiceManager.setSpeaker(call, result)
            "sendDigits"  -> voiceManager.sendDigits(call, result)
            "setSpeakerForVideo" -> videoManager.setSpeaker(call, result)
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        callHandlerChannel.setMethodCallHandler(null)
        videoManager.dispose()
        voiceManager.dispose()
        coroutineScope.cancel()
    }
}

