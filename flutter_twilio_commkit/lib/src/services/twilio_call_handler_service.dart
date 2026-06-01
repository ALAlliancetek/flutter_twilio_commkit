import 'package:flutter/services.dart';

/// Internal service used by [TwilioCallHandler] to query the native Android
/// plugin for any pending incoming call that was received while the app was
/// killed or backgrounded, and to receive real-time results when the user acts
/// on the native [TwilioIncomingCallActivity] while the app is in the foreground.
///
/// The native side ([FlutterTwilioCommKitAndroidPlugin]) stores the pending
/// call data when the host Activity is launched with an
/// [ACTION_INCOMING_CALL] intent from [TwilioIncomingCallActivity].
class TwilioCallHandlerService {
  TwilioCallHandlerService._();

  static const _channel = MethodChannel('com.twiliocommkit/incoming_call');

  // Listeners registered by TwilioCallHandler for foreground accept/reject events
  static final List<void Function(Map<String, dynamic>)> _listeners = [];

  /// Must be called once (by [TwilioCallHandler]) to wire up the method call
  /// handler so the native side can push [onIncomingCallResult] events.
  static void startListening() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onIncomingCallResult') {
        final data = Map<String, dynamic>.from(call.arguments as Map);
        for (final listener in List.of(_listeners)) {
          listener(data);
        }
      }
    });
  }

  static void addListener(void Function(Map<String, dynamic>) listener) {
    _listeners.add(listener);
  }

  static void removeListener(void Function(Map<String, dynamic>) listener) {
    _listeners.remove(listener);
  }

  /// Returns a map `{callSid, from, accepted}` if there is a pending incoming
  /// call that the app was launched for, or `null` otherwise.
  ///
  /// Clears the pending call on the native side after reading.
  static Future<Map<String, dynamic>?> getPendingIncomingCall() async {
    try {
      final result = await _channel
          .invokeMapMethod<String, dynamic>('getPendingIncomingCall');
      return result;
    } on MissingPluginException {
      // Running on a platform that doesn't implement this (e.g. iOS, web)
      return null;
    } catch (_) {
      return null;
    }
  }
}
