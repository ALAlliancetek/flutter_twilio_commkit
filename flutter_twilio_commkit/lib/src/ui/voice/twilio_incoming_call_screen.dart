import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../theme/twilio_theme.dart';
import '../../theme/twilio_theme_data.dart';
import '../../voice/twilio_voice.dart';
import '../widgets/twilio_avatar.dart';

/// Full-screen incoming call screen with ringtone support and full
/// theme customisation.
///
/// To show the caller's custom profile picture, pass [resolveParticipantImage]:
/// ```dart
/// TwilioIncomingCallScreen(
///   from: 'alice',
///   resolveParticipantImage: (identity) => myContactBook.imageUrlFor(identity),
/// )
/// ```
class TwilioIncomingCallScreen extends StatefulWidget {
  const TwilioIncomingCallScreen({
    super.key,
    required this.callSid,
    required this.from,
    this.theme,
    this.onAccepted,
    this.onRejected,
    this.resolveParticipantImage,
  });

  final String callSid;
  final String from;

  /// Optional theme override; falls back to [TwilioTheme.of(context)].
  final TwilioThemeData? theme;

  /// Called after the user taps Accept (call has already been accepted).
  final VoidCallback? onAccepted;

  /// Called after the user taps Decline (call has already been rejected).
  final VoidCallback? onRejected;

  /// Optional callback that returns a custom image URL for a given identity.
  /// When provided, the returned URL is used instead of the default pravatar.
  final String? Function(String identity)? resolveParticipantImage;

  @override
  State<TwilioIncomingCallScreen> createState() =>
      _TwilioIncomingCallScreenState();
}

class _TwilioIncomingCallScreenState extends State<TwilioIncomingCallScreen>
    with SingleTickerProviderStateMixin {
  final _player = AudioPlayer();
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  bool _busy = false; // prevents double-tap

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _startRingtone();
  }

  Future<void> _startRingtone() async {
    final path = widget.theme?.ringtonePath;
    if (path == null || path.isEmpty) return;
    try {
      await _player.setReleaseMode(
        widget.theme!.ringtoneLoop ? ReleaseMode.loop : ReleaseMode.stop,
      );
      // Force max volume so the ring is audible on both earpiece and speaker.
      await _player.setVolume(1.0);
      // Use the ringtone audio context so the OS routes audio through the
      // ring/notification stream (audible even when the earpiece is active).
      await _player.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            audioFocus: AndroidAudioFocus.gainTransient,
            usageType: AndroidUsageType.notification,
            contentType: AndroidContentType.sonification,
            audioMode: AndroidAudioMode.ringtone,
          ),
          iOS: AudioContextIOS(
            options: const {
              AVAudioSessionOptions.mixWithOthers,
            },
          ),
        ),
      );
      await _player.play(AssetSource(path));
    } catch (_) {
      // Ringtone is best-effort — silently ignore errors
    }
  }

  Future<void> _stopRingtone() async {
    try {
      await _player.stop();
      await _player.dispose();
    } catch (_) {}
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _accept(TwilioThemeData theme) async {
    if (_busy) return;
    _busy = true;
    await _stopRingtone();
    await TwilioVoice.instance.acceptCall(callSid: widget.callSid);
    widget.onAccepted?.call();
  }

  Future<void> _reject(TwilioThemeData theme) async {
    if (_busy) return;
    _busy = true;
    await _stopRingtone();
    await TwilioVoice.instance.rejectCall(callSid: widget.callSid);
    widget.onRejected?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme ?? TwilioTheme.of(context);

    final bg = theme.incomingBackgroundGradient != null
        ? BoxDecoration(gradient: theme.incomingBackgroundGradient)
        : BoxDecoration(color: theme.backgroundColor);

    return TwilioTheme(
      data: theme,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: bg,
          child: SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),

                // ── Pulsing avatar ────────────────────────────────────────
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, child) => Transform.scale(
                    scale: _pulseAnim.value,
                    child: child,
                  ),
                  child: _buildAvatar(theme),
                ),

                const SizedBox(height: 24),

                // ── Caller name ───────────────────────────────────────────
                Text(
                  widget.from,
                  textAlign: TextAlign.center,
                  style: theme.callerNameStyle ??
                      TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: theme.participantNameColor,
                        letterSpacing: 0.3,
                      ),
                ),

                const SizedBox(height: 10),

                // ── Status ────────────────────────────────────────────────
                Text(
                  'Incoming Voice Call',
                  style: theme.callStatusStyle ??
                      TextStyle(
                        fontSize: 16,
                        color: theme.participantNameColor
                            .withValues(alpha: 0.65),
                        letterSpacing: 0.5,
                      ),
                ),

                const Spacer(flex: 3),

                // ── Accept / Reject buttons ───────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 48, vertical: 12,),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ActionButton(
                        style: theme.rejectButtonStyle ??
                            const TwilioCallButtonStyle(
                              backgroundColor: Color(0xFFCC0000),
                              iconColor: Colors.white,
                              size: 72,
                              iconSize: 34,
                            ),
                        icon: Icons.call_end,
                        label: 'Decline',
                        labelStyle: theme.buttonLabelStyle,
                        onTap: () => _reject(theme),
                      ),
                      _ActionButton(
                        style: theme.acceptButtonStyle ??
                            const TwilioCallButtonStyle(
                              backgroundColor: Color(0xFF1B8C1B),
                              iconColor: Colors.white,
                              size: 72,
                              iconSize: 34,
                            ),
                        icon: Icons.call,
                        label: 'Accept',
                        labelStyle: theme.buttonLabelStyle,
                        onTap: () => _accept(theme),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(TwilioThemeData theme) {
    final radius = theme.avatarRadius;
    if (theme.avatarWidget != null) {
      return ClipOval(
        child: SizedBox(
          width: radius * 2,
          height: radius * 2,
          child: theme.avatarWidget,
        ),
      );
    }
    // Show the caller's avatar
    final identity = widget.from;
    final resolvedUrl = widget.resolveParticipantImage?.call(identity);
    final bgColor = avatarColorFor(identity);
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: bgColor.withValues(alpha: 0.4),
            blurRadius: 24,
            spreadRadius: 6,
          ),
        ],
      ),
      child: TwilioAvatar.build(
        identity: identity,
        size: radius * 2,
        imageUrl: resolvedUrl,
      ),
    );
  }
}

// ─── Reusable action button ────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.style,
    required this.icon,
    required this.label,
    required this.onTap,
    this.labelStyle,
  });

  final TwilioCallButtonStyle style;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    final theme = TwilioTheme.of(context);
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
              color: style.backgroundColor ?? theme.controlBarColor,
              shape: BoxShape.circle,
              border: style.border,
            ),
            child: Icon(
              icon,
              size: style.iconSize,
              color: style.iconColor ?? theme.controlIconColor,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: labelStyle ??
                TextStyle(
                  color: theme.participantNameColor.withValues(alpha: 0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}
