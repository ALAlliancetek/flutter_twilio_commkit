import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/call_state.dart';
import '../../theme/twilio_theme.dart';
import '../../theme/twilio_theme_data.dart';
import '../../voice/twilio_voice.dart';
import '../widgets/twilio_avatar.dart';

/// Built-in voice call screen with full theme customisation.
///
/// All visual elements — avatar, button styles, colours, typography — are
/// controlled via [TwilioThemeData].
///
/// To show the remote participant's custom profile picture, pass
/// [resolveParticipantImage]:
/// ```dart
/// TwilioVoiceCallScreen(
///   remoteIdentity: 'alice',
///   resolveParticipantImage: (identity) => myContactBook.imageUrlFor(identity),
/// )
/// ```
class TwilioVoiceCallScreen extends StatefulWidget {
  const TwilioVoiceCallScreen({
    super.key,
    required this.callSid,
    required this.remoteIdentity,
    this.theme,
    this.onCallEnded,
    this.resolveParticipantImage,
  });

  final String callSid;
  final String remoteIdentity;
  final TwilioThemeData? theme;
  final VoidCallback? onCallEnded;

  /// Optional callback that returns a custom image URL for a given identity.
  /// When provided, the returned URL is used instead of the default pravatar.
  /// Return `null` to fall back to the default.
  final String? Function(String identity)? resolveParticipantImage;

  @override
  State<TwilioVoiceCallScreen> createState() => _TwilioVoiceCallScreenState();
}

class _TwilioVoiceCallScreenState extends State<TwilioVoiceCallScreen>
    with SingleTickerProviderStateMixin {
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  CallState _callState = CallState.connecting;
  bool _callEndedFired = false;

  /// Digits typed via the keypad during the call (displayed in the sheet).
  String _dtmfBuffer = '';

  DateTime? _connectedAt;
  Duration _callDuration = Duration.zero;
  Timer? _durationTimer;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  StreamSubscription<CallStateChangedEvent>? _callStateSub;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );


    _callStateSub = TwilioVoice.instance.onCallStateChanged.listen(_onCallState);

    // Replay last known state in case callConnected fired before we subscribed.
    // Match by SID when available; also accept when widget.callSid is empty
    // (iOS outgoing calls where the SID isn't yet known at screen-open time).
    final lastState = TwilioVoice.instance.lastCallState;
    final lastSid   = TwilioVoice.instance.lastCallStateSid;
    final sidMatch  = lastSid != null && lastSid.isNotEmpty &&
        (widget.callSid.isEmpty || lastSid == widget.callSid);
    if (lastState != null && sidMatch) {
      // If the call is already connected, seed the timer from the stored timestamp
      // so both caller and callee show the same elapsed time.
      if (lastState == CallState.connected) {
        final connectedAt = TwilioVoice.instance.callConnectedAt;
        if (connectedAt != null) {
          _connectedAt = connectedAt;
          _callDuration = DateTime.now().difference(connectedAt);
        }
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onCallState(CallStateChangedEvent(callSid: lastSid, state: lastState));
      });
    }
  }

  void _onCallState(CallStateChangedEvent event) {
    if (!mounted) return;
    setState(() => _callState = event.state);

    if (event.state == CallState.connected && _durationTimer == null) {
      // Use the globally-stored connectedAt so both caller and callee show
      // the same elapsed time even if this device's screen mounted late.
      _connectedAt = TwilioVoice.instance.callConnectedAt ?? DateTime.now();
      _callDuration = DateTime.now().difference(_connectedAt!);
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() {
            _callDuration = DateTime.now().difference(_connectedAt!);
          });
        }
      });
    }

    if (event.state == CallState.disconnected && !_callEndedFired) {
      _callEndedFired = true;
      _durationTimer?.cancel();
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) widget.onCallEnded?.call();
      });
    }
  }

  @override
  void dispose() {
    _callStateSub?.cancel();
    _durationTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  String get _durationLabel {
    final m = _callDuration.inMinutes.toString().padLeft(2, '0');
    final s = (_callDuration.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _stateLabel(CallState s) => switch (s) {
        CallState.connecting  => 'Connecting…',
        CallState.ringing     => 'Ringing…',
        CallState.connected   => 'Connected',
        CallState.reconnecting => 'Reconnecting…',
        CallState.disconnected => 'Call Ended',
        CallState.incoming    => 'Incoming',
        _ => 'Unknown',
      };

  Future<void> _toggleMute() async {
    _isMuted = !_isMuted;
    await TwilioVoice.instance.mute(muted: _isMuted);
    if (mounted) setState(() {});
  }

  Future<void> _toggleSpeaker() async {
    _isSpeakerOn = !_isSpeakerOn;
    await TwilioVoice.instance.setSpeaker(enabled: _isSpeakerOn);
    if (mounted) setState(() {});
  }

  /// Shows a DTMF dial-pad bottom sheet so the user can navigate IVR menus.
  void _showDialpad(BuildContext context, TwilioThemeData theme) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.backgroundColor,
      isScrollControlled: true,  // allows sheet to resize for keyboard
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _DialpadSheet(
        theme: theme,
        initialBuffer: _dtmfBuffer,
        onDigit: (d) {
          TwilioVoice.instance.sendDigits(d);
          if (mounted) setState(() => _dtmfBuffer += d);
        },
      ),
    );
  }

  Future<void> _hangUp() async {
    if (_callEndedFired) return;
    _callEndedFired = true;
    _durationTimer?.cancel();
    await TwilioVoice.instance.hangUp();
    if (mounted) {
      setState(() => _callState = CallState.disconnected);
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) widget.onCallEnded?.call();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme ?? TwilioTheme.of(context);
    final isConnected = _callState == CallState.connected;
    final isEnded     = _callState == CallState.disconnected;

    return TwilioTheme(
      data: theme,
      child: Scaffold(
        backgroundColor: theme.backgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              // ── Top label ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Center(
                  child: Text(
                    'Voice Call',
                    style: TextStyle(
                      color: theme.participantNameColor.withValues(alpha: 0.45),
                      fontSize: 12,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const Spacer(flex: 2),

              // ── Pulsing avatar ─────────────────────────────────────────
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (_, child) => Transform.scale(
                  scale: isConnected ? _pulseAnimation.value : 1.0,
                  child: child,
                ),
                child: _buildAvatar(theme, isConnected),
              ),

              const SizedBox(height: 24),

              // ── Remote identity ────────────────────────────────────────
              Text(
                widget.remoteIdentity,
                style: theme.callerNameStyle ??
                    TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: theme.participantNameColor,
                      letterSpacing: 0.4,
                    ),
              ),

              const SizedBox(height: 10),

              // ── Status / duration ──────────────────────────────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: isConnected
                    ? Row(
                        key: const ValueKey('duration'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _durationLabel,
                            style: theme.callDurationStyle ??
                                TextStyle(
                                  fontSize: 16,
                                  color: Colors.green.shade300,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                      )
                    : Text(
                        _stateLabel(_callState),
                        key: ValueKey(_callState),
                        style: theme.callStatusStyle ??
                            TextStyle(
                              fontSize: 15,
                              color: theme.participantNameColor
                                  .withValues(alpha: 0.6),
                            ),
                      ),
              ),

              const Spacer(flex: 3),

              // ── Controls: Mute | End | Speaker ─────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ToggleButton(
                      baseStyle: theme.muteButtonStyle ??
                          TwilioCallButtonStyle(
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.08),
                            iconColor: Colors.white70,
                          ),
                      activeStyle: theme.muteButtonStyle?.copyWith(
                            backgroundColor:
                                Colors.orange.withValues(alpha: 0.2),
                            iconColor: Colors.orange,
                          ) ??
                          TwilioCallButtonStyle(
                            backgroundColor:
                                Colors.orange.withValues(alpha: 0.2),
                            iconColor: Colors.orange,
                          ),
                      icon: _isMuted ? Icons.mic_off : Icons.mic,
                      label: _isMuted ? 'Unmute' : 'Mute',
                      isActive: _isMuted,
                      labelStyle: theme.buttonLabelStyle,
                      onTap: isEnded ? null : _toggleMute,
                    ),
                    _EndButton(
                      style: theme.endCallButtonStyle ??
                          const TwilioCallButtonStyle(
                            backgroundColor: Colors.red,
                            iconColor: Colors.white,
                            size: 72,
                            iconSize: 32,
                          ),
                      labelStyle: theme.buttonLabelStyle,
                      onTap: isEnded ? null : _hangUp,
                    ),
                    _ToggleButton(
                      baseStyle: theme.speakerButtonStyle ??
                          TwilioCallButtonStyle(
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.08),
                            iconColor: Colors.white70,
                          ),
                      activeStyle: theme.speakerButtonStyle?.copyWith(
                            backgroundColor:
                                Colors.blue.withValues(alpha: 0.2),
                            iconColor: Colors.blue,
                          ) ??
                          TwilioCallButtonStyle(
                            backgroundColor:
                                Colors.blue.withValues(alpha: 0.2),
                            iconColor: Colors.blue,
                          ),
                      icon: _isSpeakerOn ? Icons.volume_up : Icons.hearing,
                      label: _isSpeakerOn ? 'Speaker' : 'Earpiece',
                      isActive: _isSpeakerOn,
                      labelStyle: theme.buttonLabelStyle,
                      onTap: isEnded ? null : _toggleSpeaker,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ── Keypad shortcut ────────────────────────────────────────
              if (isConnected)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Show typed digits so the user can see what was sent
                      if (_dtmfBuffer.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            _dtmfBuffer,
                            style: TextStyle(
                              color: theme.participantNameColor
                                  .withValues(alpha: 0.85),
                              fontSize: 22,
                              letterSpacing: 6,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      TextButton.icon(
                        icon: Icon(Icons.dialpad,
                            color: theme.participantNameColor
                                .withValues(alpha: 0.55),
                            size: 18),
                        label: Text(
                          'Keypad',
                          style: TextStyle(
                            color: theme.participantNameColor
                                .withValues(alpha: 0.55),
                            fontSize: 13,
                          ),
                        ),
                        onPressed: () => _showDialpad(context, theme),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildAvatar(TwilioThemeData theme, bool isConnected) {
    final radius = theme.avatarRadius;

    // If a custom widget is provided via theme, use it
    if (theme.avatarWidget != null) {
      return ClipOval(
        child: SizedBox(
          width: radius * 2,
          height: radius * 2,
          child: theme.avatarWidget,
        ),
      );
    }

    // Show the remote person's avatar
    final identity = widget.remoteIdentity;
    final resolvedUrl = widget.resolveParticipantImage?.call(identity);
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: isConnected
            ? [
                BoxShadow(
                  color: Colors.green.withValues(alpha: 0.3),
                  blurRadius: 24,
                  spreadRadius: 6,
                ),
              ]
            : const [],
      ),
      child: TwilioAvatar.build(
        identity: identity,
        size: radius * 2,
        imageUrl: resolvedUrl,
      ),
    );
  }
}

// ─── DTMF Dial-pad bottom sheet ───────────────────────────────────────────────

class _DialpadSheet extends StatefulWidget {
  const _DialpadSheet({
    required this.theme,
    required this.onDigit,
    this.initialBuffer = '',
  });
  final TwilioThemeData theme;
  final void Function(String digit) onDigit;
  final String initialBuffer;

  @override
  State<_DialpadSheet> createState() => _DialpadSheetState();
}

class _DialpadSheetState extends State<_DialpadSheet> {
  late String _buffer;

  @override
  void initState() {
    super.initState();
    _buffer = widget.initialBuffer;
  }

  static const _keys = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['*', '0', '#'],
  ];

  void _onKey(String digit) {
    HapticFeedback.lightImpact();
    widget.onDigit(digit);
    setState(() => _buffer += digit);
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    // viewInsets.bottom pushes content above the soft keyboard
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 16, 24, 32 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Keypad',
              style: TextStyle(
                color: theme.participantNameColor,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            // Digit display — truly centered using Stack so backspace
            // button on the right doesn't shift the text left.
            SizedBox(
              height: 44,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Centered digit text — always fills full width
                  Center(
                    child: Text(
                      _buffer.isEmpty ? ' ' : _buffer,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.participantNameColor,
                        fontSize: 26,
                        letterSpacing: 8,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  // Backspace pinned to the right — doesn't affect centering
                  if (_buffer.isNotEmpty)
                    Positioned(
                      right: 0,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(Icons.backspace_outlined,
                            color: theme.participantNameColor
                                .withValues(alpha: 0.5),
                            size: 20),
                        onPressed: () => setState(() =>
                            _buffer =
                                _buffer.substring(0, _buffer.length - 1)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            for (final row in _keys)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: row
                    .map((key) => _DialKey(
                          label: key,
                          theme: theme,
                          onTap: () => _onKey(key),
                        ))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _DialKey extends StatelessWidget {
  const _DialKey({required this.label, required this.theme, required this.onTap});
  final String label;
  final TwilioThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.controlBarColor.withValues(alpha: 0.7),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: theme.participantNameColor,
              fontSize: 26,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Toggle button (mute / speaker) ──────────────────────────────────────────

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.baseStyle,
    required this.activeStyle,
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.labelStyle,
  });

  final TwilioCallButtonStyle baseStyle;
  final TwilioCallButtonStyle activeStyle;
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    final s = isActive ? activeStyle : baseStyle;
    final size = s.size;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: s.backgroundColor,
              border: s.border,
            ),
            child: Icon(icon, color: s.iconColor, size: s.iconSize),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: labelStyle ??
                TextStyle(
                  color: TwilioTheme.of(context).participantNameColor.withValues(alpha: 0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}

// ─── End call button ──────────────────────────────────────────────────────────

class _EndButton extends StatelessWidget {
  const _EndButton({
    required this.style,
    required this.onTap,
    this.labelStyle,
  });

  final TwilioCallButtonStyle style;
  final VoidCallback? onTap;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = onTap == null
        ? Colors.grey
        : (style.backgroundColor ?? Colors.red);
    final size = style.size;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: effectiveColor,
              boxShadow: onTap == null
                  ? const []
                  : [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.4),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
            ),
            child: Icon(
              Icons.call_end,
              color: style.iconColor ?? Colors.white,
              size: style.iconSize,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'End',
            style: labelStyle ??
                TextStyle(
                  color: effectiveColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
