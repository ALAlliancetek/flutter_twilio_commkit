import 'dart:ui';
import 'package:flutter/material.dart';

import '../../theme/twilio_theme.dart';
import '../../theme/twilio_theme_data.dart';

/// Built-in call controls bar for video/voice calls.
///
/// All button styles come from [TwilioThemeData]:
/// - Mute/unmute → [TwilioThemeData.muteButtonStyle]
/// - Video on/off → [TwilioThemeData.videoButtonStyle]
/// - Flip camera → [TwilioThemeData.flipCameraButtonStyle]
/// - Speaker    → [TwilioThemeData.speakerButtonStyle]
/// - End call   → [TwilioThemeData.endCallButtonStyle]
class TwilioCallControls extends StatelessWidget {
  const TwilioCallControls({
    super.key,
    required this.isAudioMuted,
    required this.isVideoMuted,
    required this.onToggleAudio,
    required this.onToggleVideo,
    required this.onHangUp,
    this.onSwitchCamera,
    this.onToggleSpeaker,
    this.onShowParticipants,
    this.isSpeakerOn = false,
    this.participantCount = 0,
    this.extraActions = const [],
  });

  final bool isAudioMuted;
  final bool isVideoMuted;
  final bool isSpeakerOn;
  final VoidCallback onToggleAudio;
  final VoidCallback onToggleVideo;
  final VoidCallback onHangUp;
  final VoidCallback? onSwitchCamera;
  final VoidCallback? onToggleSpeaker;
  /// Tap handler for the participants list button (null = button hidden).
  final VoidCallback? onShowParticipants;
  /// Current total participant count shown on the people button badge.
  final int participantCount;

  /// Additional action buttons injected by the client app.
  final List<Widget> extraActions;

  @override
  Widget build(BuildContext context) {
    final theme = TwilioTheme.of(context);

    Widget bar = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: theme.controlBarColor.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(theme.controlBarBorderRadius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ControlButton(
            icon: isAudioMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            label: isAudioMuted ? 'Unmute' : 'Mute',
            onTap: onToggleAudio,
            isActive: isAudioMuted,
            style: theme.muteButtonStyle,
            activeColor: const Color(0xFFFF7043),
            defaultColor: theme.controlIconColor,
            labelStyle: theme.buttonLabelStyle,
          ),
          _ControlButton(
            icon: isVideoMuted
                ? Icons.videocam_off_rounded
                : Icons.videocam_rounded,
            label: isVideoMuted ? 'Cam On' : 'Cam Off',
            onTap: onToggleVideo,
            isActive: isVideoMuted,
            style: theme.videoButtonStyle,
            activeColor: const Color(0xFFFF7043),
            defaultColor: theme.controlIconColor,
            labelStyle: theme.buttonLabelStyle,
          ),
          if (onSwitchCamera != null)
            _ControlButton(
              icon: Icons.flip_camera_android_rounded,
              label: 'Flip',
              onTap: onSwitchCamera!,
              style: theme.flipCameraButtonStyle,
              activeColor: theme.controlIconActiveColor,
              defaultColor: theme.controlIconColor,
              labelStyle: theme.buttonLabelStyle,
            ),
          if (onToggleSpeaker != null)
            _ControlButton(
              icon: isSpeakerOn
                  ? Icons.volume_up_rounded
                  : Icons.hearing_rounded,
              label: isSpeakerOn ? 'Speaker' : 'Earpiece',
              onTap: onToggleSpeaker!,
              isActive: isSpeakerOn,
              style: theme.speakerButtonStyle,
              activeColor: theme.controlIconActiveColor,
              defaultColor: theme.controlIconColor,
              labelStyle: theme.buttonLabelStyle,
            ),
          if (onShowParticipants != null)
            _ControlButton(
              icon: Icons.people_alt_rounded,
              label: participantCount > 1 ? '$participantCount' : 'People',
              onTap: onShowParticipants!,
              style: theme.speakerButtonStyle,
              activeColor: theme.controlIconActiveColor,
              defaultColor: theme.controlIconColor,
              labelStyle: theme.buttonLabelStyle,
            ),
          ...extraActions,
          _EndCallButton(
            onTap: onHangUp,
            style: theme.endCallButtonStyle,
            labelStyle: theme.buttonLabelStyle,
          ),
        ],
      ),
    );

    if (theme.controlBarBlur) {
      bar = ClipRRect(
        borderRadius: BorderRadius.circular(theme.controlBarBorderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: bar,
        ),
      );
    }

    return bar;
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.activeColor,
    required this.defaultColor,
    this.isActive = false,
    this.style,
    this.labelStyle,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;
  final Color activeColor;
  final Color defaultColor;
  final TwilioCallButtonStyle? style;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    final theme = TwilioTheme.of(context);
    final effectiveIconColor =
        style?.iconColor ?? (isActive ? activeColor : defaultColor);
    // Active: coloured background; inactive: subtle white/dark tint
    final bgColor = style?.backgroundColor ??
        (isActive
            ? activeColor.withValues(alpha: 0.20)
            : Colors.white.withValues(alpha: 0.10));
    final size = style?.size ?? 50.0;
    final iconSize = style?.iconSize ?? theme.controlIconSize;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius:
                  style?.borderRadius ?? BorderRadius.circular(size / 2),
              border: style?.border ??
                  (isActive
                      ? Border.all(
                          color: activeColor.withValues(alpha: 0.4), width: 1.5,)
                      : null),
            ),
            child: Icon(icon, color: effectiveIconColor, size: iconSize),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: labelStyle ??
                TextStyle(
                  color: isActive
                      ? activeColor
                      : (style?.labelColor ?? Colors.white70),
                  fontSize: 10,
                  fontWeight:
                      isActive ? FontWeight.w600 : FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}

// ── Dedicated end-call button — always solid red, larger, prominent ────────────

class _EndCallButton extends StatelessWidget {
  const _EndCallButton({required this.onTap, this.style, this.labelStyle});

  final VoidCallback onTap;
  final TwilioCallButtonStyle? style;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    final size = style?.size ?? 58.0;
    final iconSize = style?.iconSize ?? 28.0;
    final bg = style?.backgroundColor ?? const Color(0xFFE53935); // Material red 600

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
              color: bg,
              boxShadow: [
                BoxShadow(
                  color: bg.withValues(alpha: 0.45),
                  blurRadius: 14,
                  spreadRadius: 2,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              Icons.call_end_rounded,
              color: style?.iconColor ?? Colors.white,
              size: iconSize,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'End',
            style: labelStyle ??
                const TextStyle(
                  color: Color(0xFFEF5350),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

