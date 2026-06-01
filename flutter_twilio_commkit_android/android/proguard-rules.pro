# Twilio Video SDK ProGuard rules
-keep class com.twilio.video.** { *; }
-dontwarn com.twilio.video.**

# Twilio Voice SDK ProGuard rules
-keep class com.twilio.voice.** { *; }
-dontwarn com.twilio.voice.**

# Keep plugin entry point
-keep class com.twiliocommkit.android.** { *; }

# WebRTC
-keep class org.webrtc.** { *; }
-dontwarn org.webrtc.**

# Kotlin coroutines
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keepclassmembernames class kotlinx.** {
    volatile <fields>;
}

