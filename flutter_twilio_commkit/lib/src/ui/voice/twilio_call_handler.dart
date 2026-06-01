import 'package:flutter/material.dart';

import '../../core/twilio_commkit.dart';
import '../../voice/twilio_voice.dart';
import '../../theme/twilio_theme.dart';
import '../../services/twilio_call_handler_service.dart';
import 'twilio_voice_call_screen.dart';

export '../../services/twilio_call_handler_service.dart' show TwilioCallHandlerService;

/// A widget that automatically handles incoming Twilio Voice calls.
///
/// Wrap your app's root widget (or any ancestor of your main Navigator) with
/// [TwilioCallHandler] and it will:
///
/// - Show the native [TwilioIncomingCallActivity] full-screen UI for ALL app
///   states: foreground, background and killed.
/// - Navigate to [TwilioVoiceCallScreen] when the user accepts the call.
///
/// The bottom-sheet incoming call UI is intentionally removed — the native
/// Android full-screen activity provides a consistent experience in all modes.
///
/// **Minimal usage:**
/// ```dart
/// MaterialApp(
///   home: TwilioCallHandler(
///     child: MyHomeScreen(),
///   ),
/// )
/// ```
///
/// **Custom accept flow (headless mode):**
/// ```dart
/// TwilioCallHandler(
///   onAcceptCall: (callSid, from) async {
///     await TwilioVoice.instance.acceptCall(callSid: callSid);
///     // navigate yourself
///   },
///   child: MyHomeScreen(),
/// )
/// ```
class TwilioCallHandler extends StatefulWidget {
  const TwilioCallHandler({
    super.key,
    required this.child,
    this.onAcceptCall,
    this.onRejectCall,
    this.theme,
  });

  /// The widget below this in the tree (typically your home screen).
  final Widget child;

  /// Called when the user taps Accept on the native incoming call screen.
  ///
  /// If null the SDK calls [TwilioVoice.instance.acceptCall] automatically
  /// and navigates to [TwilioVoiceCallScreen].
  final Future<void> Function(String callSid, String from)? onAcceptCall;

  /// Called when the user taps Decline on the native incoming call screen.
  /// If null the SDK calls [TwilioVoice.instance.rejectCall] automatically.
  final Future<void> Function(String callSid)? onRejectCall;

  /// Optional theme override for the built-in call screen.
  final dynamic theme; // TwilioThemeData

  @override
  State<TwilioCallHandler> createState() => _TwilioCallHandlerState();
}

class _TwilioCallHandlerState extends State<TwilioCallHandler> {
  // No stream subscription — native TwilioIncomingCallActivity handles all UI.
  // We only need to handle the result after the user acts on the native screen.

  @override
  void initState() {
    super.initState();
    // Register for foreground accept/reject events pushed from native.
    TwilioCallHandlerService.startListening();
    TwilioCallHandlerService.addListener(_onNativeCallResult);

    // After first frame: check if app was launched/resumed from
    // TwilioIncomingCallActivity (background / killed scenario).
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkNativePending());
  }

  @override
  void dispose() {
    TwilioCallHandlerService.removeListener(_onNativeCallResult);
    super.dispose();
  }

  // ── Native pending call (background / killed-app scenario) ────────────────

  Future<void> _checkNativePending() async {
    try {
      final result = await TwilioCallHandlerService.getPendingIncomingCall();
      if (result == null || !mounted) return;

      final callSid  = result['callSid'] as String? ?? '';
      final from     = result['from']    as String? ?? 'Unknown';
      final accepted = result['accepted'] as bool? ?? false;

      if (callSid.isEmpty) return;

      if (accepted) {
        // User tapped Accept on the native screen.
        // Initialize the Voice SDK first (registers event listener + restores CallInvite),
        // then navigate to the call screen and accept with the proper callListener.
        await _autoInitVoiceIfNeeded();
        if (!mounted) return;
        await _navigateToCallScreen(callSid: callSid, from: from);
      }
      // If not accepted (banner tap without acting): TwilioIncomingCallActivity is
      // already showing — nothing to do in Flutter.
    } catch (_) {
      // Not Android or method unavailable — ignore.
    }
  }

  // ── Foreground: native pushed the result via method channel ───────────────

  void _onNativeCallResult(Map<String, dynamic> data) {
    if (!mounted) return;
    final callSid  = data['callSid'] as String? ?? '';
    final from     = data['from']    as String? ?? 'Unknown';
    final accepted = data['accepted'] as bool? ?? false;
    if (callSid.isEmpty) return;

    if (accepted) {
      // User accepted on the native screen. Init Voice SDK then navigate+accept.
      _autoInitVoiceIfNeeded().then((_) {
        if (mounted) _navigateToCallScreen(callSid: callSid, from: from);
      });
    }
    // Rejected: TwilioIncomingCallActivity already rejected natively.
  }

  /// Initializes the Voice SDK (registers event listener + restores CallInvite).
  Future<void> _autoInitVoiceIfNeeded() async {
    try {
      final token = await TwilioCommKit.config.accessTokenProvider();
      await TwilioVoice.instance.initialize(accessToken: token);
    } catch (e) {
      // Best-effort token fetch failed — still subscribe to platform events
      // so disconnect events from the remote side reach the call screen.
      TwilioVoice.instance.ensureSubscribed();
    }
  }

  Future<void> _navigateToCallScreen({
    required String callSid,
    required String from,
  }) async {
    if (!mounted) return;
    final themeData = widget.theme ?? TwilioTheme.of(context);

    // Custom accept callback: delegate fully to the host app.
    if (widget.onAcceptCall != null) {
      await widget.onAcceptCall!(callSid, from);
      return;
    }

    // IMPORTANT: Navigate FIRST so the call screen is mounted and its
    // onCallStateChanged subscription is active. THEN accept the call so the
    // callConnected event arrives after the screen is listening for it.
    // If we accept first, callConnected fires before the screen subscribes
    // and the status stays stuck at "Connecting…".
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TwilioVoiceCallScreen(
          callSid: callSid,
          remoteIdentity: from,
          theme: themeData,
          onCallEnded: () => Navigator.pop(context),
        ),
      ),
    );

    // Accept slightly after navigation so the screen's stream subscription
    // is registered before callConnected fires.
    await Future.delayed(const Duration(milliseconds: 150));
    await TwilioVoice.instance.acceptCall(callSid: callSid);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
