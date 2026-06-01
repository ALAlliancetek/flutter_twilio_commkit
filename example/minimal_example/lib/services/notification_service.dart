import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// FirebaseOptions placeholder — replace with your google-services.json values
/// or use the FlutterFire CLI: `flutterfire configure`
///
/// Leave null and use google-services.json on Android instead.
const FirebaseOptions? kFirebaseOptions = null;

// ── Background message handler (top-level function — required by FlutterFire) ─

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // App is in background/terminated — Firebase already initialised by the system.
  // flutter_local_notifications can post a notification here if needed.
  // For Twilio Voice: the native FirebaseMessagingService.kt handles this,
  // so we only need to ensure Firebase is initialised.
  await Firebase.initializeApp(options: kFirebaseOptions);
}

/// Service that manages:
/// - Firebase / FCM initialisation
/// - Notification permission request
/// - Routing incoming call FCM messages to Twilio Voice SDK
/// - Posting local "Incoming Call" heads-up notifications when app is in foreground
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _fcmTokenController = StreamController<String>.broadcast();
  final _incomingCallController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Stream that emits the latest FCM token (and updates on refresh).
  Stream<String> get onFcmToken => _fcmTokenController.stream;

  /// Stream that emits incoming call payloads when app is in foreground.
  Stream<Map<String, dynamic>> get onIncomingCall =>
      _incomingCallController.stream;

  final _localNotifications = FlutterLocalNotificationsPlugin();

  static const _channelId = 'twilio_voice_calls';
  static const _channelName = 'Incoming Calls';

  bool _initialised = false;
  String? _fcmToken;

  String? get currentFcmToken => _fcmToken;

  // ── Initialise ──────────────────────────────────────────────────────────────

  Future<void> initialise() async {
    if (_initialised) return;
    _initialised = true;

    // 1. Init Firebase
    await Firebase.initializeApp(options: kFirebaseOptions);

    // 2. Set background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 3. Request permission (iOS + Android 13+)
    await _requestPermission();

    // 4. Init local notifications
    await _initLocalNotifications();

    // 5. Get current FCM token
    await _fetchAndEmitToken();

    // 6. Listen for token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      _fcmToken = token;
      _fcmTokenController.add(token);
    });

    // 7. Foreground FCM messages — Android only (iOS uses PushKit/CallKit)
    if (defaultTargetPlatform == TargetPlatform.android) {
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _handleNotificationTap(initial);
    }
  }

  // ── Permission ──────────────────────────────────────────────────────────────

  Future<void> _requestPermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      announcement: false,
    );
    debugPrint('[NotificationService] FCM permission: ${settings.authorizationStatus}');
  }

  // ── Local notifications ──────────────────────────────────────────────────────

  Future<void> _initLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false, // iOS uses CallKit for calls — no local notifications needed
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    // Create Android notification channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: 'Twilio Voice incoming call notifications',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ));
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    // User tapped the notification — payload is the call SID or JSON
    final payload = response.payload;
    if (payload != null) {
      _incomingCallController.add({'callSid': payload, 'source': 'notification_tap'});
    }
  }

  // ── Token ────────────────────────────────────────────────────────────────────

  Future<void> _fetchAndEmitToken() async {
    try {
      // Timeout so FIS auth failure doesn't block app startup indefinitely
      final token = await FirebaseMessaging.instance
          .getToken()
          .timeout(const Duration(seconds: 10));
      if (token != null) {
        _fcmToken = token;
        _fcmTokenController.add(token);
        debugPrint('[NotificationService] FCM token: ${token.substring(0, 20)}…');
      }
    } catch (e) {
      // Common causes:
      // - SHA-1 fingerprint not registered in Firebase Console
      // - No internet connection
      // - Firebase Installations API not enabled
      debugPrint('[NotificationService] ⚠️  Could not get FCM token: $e\n'
          '  Fix: Add SHA-1 to Firebase Console → Project Settings → Your App\n'
          '  SHA-1: 76:5C:0F:45:A0:9F:EC:FE:CB:C1:65:F8:B5:11:E2:4D:CB:68:2F:E0\n'
          '  App will still work for outgoing calls — only incoming FCM push affected.');
    }
  }

  // ── Foreground FCM message handler ──────────────────────────────────────────

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final data = message.data;
    final isTwilioVoice = data.containsKey('twi_message_type') &&
        data['twi_message_type'] == 'twilio.voice.call';

    if (isTwilioVoice) {
      // Emit to Flutter so VoiceTestScreen can show incoming call UI
      _incomingCallController.add({
        'callSid': data['twi_call_sid'] ?? '',
        'from': data['twi_from'] ?? 'Unknown',
        'source': 'foreground_fcm',
        'raw': data,
      });

      // Show heads-up notification while app is in foreground
      await _showIncomingCallNotification(
        callSid: data['twi_call_sid'] ?? '',
        from: (data['twi_from'] ?? 'Unknown')
            .toString()
            .replaceFirst('client:', ''),
      );
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    if (data.containsKey('twi_call_sid')) {
      _incomingCallController.add({
        'callSid': data['twi_call_sid'] ?? '',
        'from': data['twi_from'] ?? 'Unknown',
        'source': 'notification_tap',
        'raw': data,
      });
    }
  }

  Future<void> _showIncomingCallNotification({
    required String callSid,
    required String from,
  }) async {
    // Android only — iOS uses CallKit which shows its own native system UI
    if (defaultTargetPlatform != TargetPlatform.android) return;

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Twilio Voice incoming call notifications',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.call,
      fullScreenIntent: true,
      ongoing: true,
      autoCancel: false,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      1001,
      'Incoming Call',
      '$from is calling…',
      details,
      payload: callSid,
    );
  }

  /// Dismiss the incoming call notification (after accept/reject).
  Future<void> dismissIncomingCallNotification() async {
    await _localNotifications.cancel(1001);
  }

  void dispose() {
    _fcmTokenController.close();
    _incomingCallController.close();
  }
}

