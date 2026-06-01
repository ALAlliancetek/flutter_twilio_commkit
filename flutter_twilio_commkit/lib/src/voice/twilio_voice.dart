import 'dart:async';

import 'package:flutter_twilio_commkit_platform_interface/flutter_twilio_commkit_platform_interface.dart';

import '../models/call_state.dart';
import '../utils/twilio_logger.dart';
import '../exceptions/twilio_exceptions.dart';
import '../events/voice_events.dart';
import 'voice_call.dart';

export '../events/voice_events.dart';

/// High-level API for Twilio Voice calling.
///
/// Usage:
/// ```dart
/// await TwilioVoice.instance.initialize(accessToken: token);
/// final call = await TwilioVoice.instance.startCall(to: '+15551234567');
/// ```
class TwilioVoice {
  TwilioVoice._();

  static final TwilioVoice _instance = TwilioVoice._();

  /// Singleton instance.
  static TwilioVoice get instance => _instance;

  VoiceCall? _activeCall;
  String _lastAccessToken = '';
  String _activeCallSid = ''; // tracks SID even for accepted incoming calls

  /// The last call state received — allows the call screen to sync on mount.
  CallState? _lastCallState;
  String? _lastCallStateSid;
  /// Wall-clock timestamp of when the call last transitioned to [CallState.connected].
  /// Exposed so call screens on both caller and callee use the same reference point.
  DateTime? _callConnectedAt;

  CallState? get lastCallState => _lastCallState;
  String? get lastCallStateSid => _lastCallStateSid;
  DateTime? get callConnectedAt => _callConnectedAt;

  final _eventController = StreamController<VoiceCallEvent>.broadcast();
  StreamSubscription<VoiceEvent>? _platformSubscription;

  /// Stream of strongly-typed voice call events.
  Stream<VoiceCallEvent> get onCallEvent => _eventController.stream;

  /// Convenience: stream of call state changes.
  Stream<CallStateChangedEvent> get onCallStateChanged =>
      onCallEvent
          .where((e) => e is CallStateChangedEvent)
          .cast<CallStateChangedEvent>();

  /// Convenience: stream of incoming call events.
  Stream<IncomingCallEvent> get onIncomingCall =>
      onCallEvent
          .where((e) => e is IncomingCallEvent)
          .cast<IncomingCallEvent>();

  /// Fired when Twilio detects network quality problems on the active call.
  Stream<CallQualityWarningChangedEvent> get onCallQualityWarning =>
      onCallEvent
          .where((e) => e is CallQualityWarningChangedEvent)
          .cast<CallQualityWarningChangedEvent>();

  /// The currently active call, or null.
  VoiceCall? get activeCall => _activeCall;

  /// Initializes the Voice SDK with the given access token.
  ///
  /// [fcmToken] is optional — only required for **incoming call push notifications**.
  /// For outgoing-only calls (testing), omit [fcmToken] and everything works fine.
  Future<void> initialize({required String accessToken, String? fcmToken}) async {
    TwilioLogger.debug('TwilioVoice initializing...');
    _lastAccessToken = accessToken;
    await TwilioCommKitPlatform.instance
        .initVoice(accessToken: accessToken, fcmToken: fcmToken);
    _subscribeToPlatformEvents();
    TwilioLogger.debug('TwilioVoice initialized.');
  }

  /// Starts an outgoing voice call.
  ///
  /// [accessToken] overrides the token from [initialize]. Useful when tokens
  /// are short-lived and refresh is needed before each call.
  Future<VoiceCall> startCall({
    required String to,
    String? accessToken,
    Map<String, String>? params,
  }) async {
    final token = accessToken?.isNotEmpty == true ? accessToken! : _lastAccessToken;
    if (token.isEmpty) {
      throw const TwilioAuthException(
          'No access token available. Call initialize() first or pass accessToken to startCall().',);
    }
    // Clear any stale call state from the previous call so the new screen
    // doesn't incorrectly replay an old "connected" state.
    _lastCallState = null;
    _lastCallStateSid = null;
    _callConnectedAt = null;
    TwilioLogger.debug('Starting call to: $to');
    try {
      final model = await TwilioCommKitPlatform.instance
          .startCall(to: to, accessToken: token, params: params);
      _activeCall = VoiceCall.fromModel(model);
      _activeCallSid = _activeCall!.callSid;
      return _activeCall!;
    } on Exception catch (e) {
      TwilioLogger.error('startCall failed', e);
      throw TwilioCallException('Failed to start call: $e');
    }
  }

  /// Accepts an incoming call.
  Future<void> acceptCall({required String callSid}) async {
    // Clear stale state before accepting so the call screen starts fresh.
    _lastCallState = null;
    _lastCallStateSid = null;
    _callConnectedAt = null;
    _activeCallSid = callSid;
    await TwilioCommKitPlatform.instance.acceptCall(callSid: callSid);
  }

  /// Rejects an incoming call.
  Future<void> rejectCall({required String callSid}) async {
    await TwilioCommKitPlatform.instance.rejectCall(callSid: callSid);
  }

  /// Hangs up an active call.
  Future<void> hangUp() async {
    // Use callSid from activeCall if available, otherwise use the tracked SID
    // (set when acceptCall is called for incoming calls where _activeCall is not set).
    final sid = _activeCall?.callSid ?? _activeCallSid;
    _activeCall = null;
    _activeCallSid = '';
    await TwilioCommKitPlatform.instance.hangUpCall(callSid: sid);
  }

  /// Mutes or unmutes the active call.
  Future<void> mute({required bool muted}) async {
    await TwilioCommKitPlatform.instance.muteCall(muted: muted);
  }

  /// Holds or resumes the active call.
  Future<void> hold({required bool held}) async {
    await TwilioCommKitPlatform.instance.holdCall(held: held);
  }

  /// Enables or disables speakerphone.
  Future<void> setSpeaker({required bool enabled}) async {
    await TwilioCommKitPlatform.instance.setSpeaker(enabled: enabled);
  }

  /// Sends DTMF digits during an active call (e.g. IVR navigation: "1", "#", "*").
  Future<void> sendDigits(String digits) async {
    await TwilioCommKitPlatform.instance.sendDigits(digits: digits);
  }

  /// Ensures the platform event subscription is active without re-initializing.
  /// Safe to call multiple times.
  void ensureSubscribed() {
    if (_platformSubscription == null) {
      _subscribeToPlatformEvents();
    }
  }

  void _subscribeToPlatformEvents() {
    _platformSubscription?.cancel();
    _platformSubscription =
        TwilioCommKitPlatform.instance.onVoiceEvent.listen(
      (event) {
        final mapped = _mapEvent(event);
        if (mapped != null) {
          // Track last state so call screen can sync on mount
          if (mapped is CallStateChangedEvent) {
            _lastCallState = mapped.state;
            _lastCallStateSid = mapped.callSid;
            // Keep activeCallSid in sync with real SID from events
            if (mapped.state == CallState.connected || mapped.state == CallState.ringing) {
              if (_activeCallSid.isEmpty) _activeCallSid = mapped.callSid;
            }
            if (mapped.state == CallState.connected) {
              // Record wall-clock connection time once — don't overwrite on reconnect
              _callConnectedAt ??= DateTime.now();
            }
            // Clear last state after disconnect so stale state isn't replayed
            if (mapped.state == CallState.disconnected) {
              _activeCallSid = '';
              _activeCall = null;
              _callConnectedAt = null;
              Future.delayed(const Duration(seconds: 2), () {
                _lastCallState = null;
                _lastCallStateSid = null;
              });
            }
          }
          _eventController.add(mapped);
        }
      },
      onError: (Object e) => TwilioLogger.error('Voice event error', e),
    );
  }

  VoiceCallEvent? _mapEvent(VoiceEvent event) {
    return switch (event) {
      CallConnectingEvent e => CallStateChangedEvent(
          callSid: e.callSid, state: CallState.connecting,),
      CallRingingEvent e => CallStateChangedEvent(
          callSid: e.callSid, state: CallState.ringing,),
      CallConnectedEvent e => CallStateChangedEvent(
          callSid: e.callSid, state: CallState.connected,),
      CallDisconnectedEvent e => CallStateChangedEvent(
          callSid: e.callSid, state: CallState.disconnected,),
      CallFailedEvent e => VoiceErrorEvent(
          message: e.message, code: e.code,),
      CallIncomingEvent e =>
        IncomingCallEvent(callSid: e.callSid, from: e.from, to: e.to),
      CallReconnectingEvent e => CallStateChangedEvent(
          callSid: e.callSid, state: CallState.reconnecting,),
      CallReconnectedEvent e => CallStateChangedEvent(
          callSid: e.callSid, state: CallState.connected,),
      CallMutedEvent e =>
        CallMutedChangedEvent(callSid: e.callSid, isMuted: e.isMuted),
      CallHeldEvent e =>
        CallHoldChangedEvent(callSid: e.callSid, isOnHold: e.isOnHold),
      CallQualityWarningEvent e =>
        CallQualityWarningChangedEvent(callSid: e.callSid, warnings: e.warnings),
      _ => null,
    };
  }

  /// Releases all resources. Called automatically by [TwilioCommKit.dispose].
  void dispose() {
    _platformSubscription?.cancel();
    _eventController.close();
  }
}

