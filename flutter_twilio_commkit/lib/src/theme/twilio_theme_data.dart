import 'package:flutter/material.dart';
/// Style for a single call action button (accept, reject, end, mute, speaker...).
@immutable
class TwilioCallButtonStyle {
  const TwilioCallButtonStyle({
    this.backgroundColor,
    this.iconColor,
    this.labelColor,
    this.size = 64.0,
    this.iconSize = 28.0,
    this.borderRadius,
    this.border,
    this.elevation = 0,
    this.shape,
  });
  final Color? backgroundColor;
  final Color? iconColor;
  final Color? labelColor;
  final double size;
  final double iconSize;
  final BorderRadius? borderRadius;
  final BoxBorder? border;
  final double elevation;
  /// Override entire shape -- if set, [borderRadius] is ignored.
  final ShapeBorder? shape;
  TwilioCallButtonStyle copyWith({
    Color? backgroundColor,
    Color? iconColor,
    Color? labelColor,
    double? size,
    double? iconSize,
    BorderRadius? borderRadius,
    BoxBorder? border,
    double? elevation,
    ShapeBorder? shape,
  }) =>
      TwilioCallButtonStyle(
        backgroundColor: backgroundColor ?? this.backgroundColor,
        iconColor: iconColor ?? this.iconColor,
        labelColor: labelColor ?? this.labelColor,
        size: size ?? this.size,
        iconSize: iconSize ?? this.iconSize,
        borderRadius: borderRadius ?? this.borderRadius,
        border: border ?? this.border,
        elevation: elevation ?? this.elevation,
        shape: shape ?? this.shape,
      );
}
/// Defines the visual properties for ALL Twilio built-in UI components.
///
/// Pass to [TwilioVideoCallScreen], [TwilioVoiceCallScreen],
/// [TwilioCallHandler], or [TwilioIncomingCallScreen].
@immutable
class TwilioThemeData {
  const TwilioThemeData({
    required this.backgroundColor,
    required this.controlBarColor,
    required this.controlIconColor,
    required this.controlIconActiveColor,
    required this.participantNameColor,
    required this.networkQualityGoodColor,
    required this.networkQualityPoorColor,
    this.controlBarBorderRadius = 16.0,
    this.controlIconSize = 28.0,
    this.participantTileRadius = 12.0,
    this.videoBackgroundColor,
    this.participantTileBorderColor,
    this.participantTileBorderWidth = 0.0,
    this.dominantSpeakerBorderColor,
    this.dominantSpeakerBorderWidth = 2.5,
    this.pipBorderColor,
    this.pipBorderWidth = 1.5,
    this.pipBorderRadius = 12.0,
    this.pipWidth = 100.0,
    this.pipHeight = 140.0,
    this.participantNameBadgeColor,
    this.waitingOverlayColor,
    this.roomBadgeColor,
    this.controlBarBlur = false,
    this.tileSeparatorColor,
    this.videoMutedTileColor,
    this.avatarWidget,
    this.avatarRadius = 56.0,
    this.avatarBackgroundColor,
    this.avatarIcon = Icons.person,
    this.avatarIconColor,
    this.callerNameStyle,
    this.callStatusStyle,
    this.callDurationStyle,
    this.buttonLabelStyle,
    this.participantNameStyle,
    this.ringtonePath,
    this.ringtoneLoop = true,
    this.incomingBackgroundGradient,
    this.acceptButtonStyle,
    this.rejectButtonStyle,
    this.endCallButtonStyle,
    this.muteButtonStyle,
    this.videoButtonStyle,
    this.speakerButtonStyle,
    this.holdButtonStyle,
    this.flipCameraButtonStyle,
  });
  final Color backgroundColor;
  final Color controlBarColor;
  final Color controlIconColor;
  final Color controlIconActiveColor;
  final Color participantNameColor;
  final Color networkQualityGoodColor;
  final Color networkQualityPoorColor;
  final double controlBarBorderRadius;
  final double controlIconSize;
  final double participantTileRadius;
  /// Background color of the video call screen. Defaults to [backgroundColor].
  final Color? videoBackgroundColor;
  final Color? participantTileBorderColor;
  final double participantTileBorderWidth;
  final Color? dominantSpeakerBorderColor;
  final double dominantSpeakerBorderWidth;
  final Color? pipBorderColor;
  final double pipBorderWidth;
  final double pipBorderRadius;
  final double pipWidth;
  final double pipHeight;
  final Color? participantNameBadgeColor;
  final Color? waitingOverlayColor;
  final Color? roomBadgeColor;
  /// Blur the control bar background (glassmorphism effect).
  final bool controlBarBlur;
  final Color? tileSeparatorColor;
  final Color? videoMutedTileColor;
  final Widget? avatarWidget;
  final double avatarRadius;
  final Color? avatarBackgroundColor;
  final IconData avatarIcon;
  final Color? avatarIconColor;
  final TextStyle? callerNameStyle;
  final TextStyle? callStatusStyle;
  final TextStyle? callDurationStyle;
  final TextStyle? buttonLabelStyle;
  /// Text style for the participant name overlay on video tiles.
  final TextStyle? participantNameStyle;
  final String? ringtonePath;
  final bool ringtoneLoop;
  final Gradient? incomingBackgroundGradient;
  final TwilioCallButtonStyle? acceptButtonStyle;
  final TwilioCallButtonStyle? rejectButtonStyle;
  final TwilioCallButtonStyle? endCallButtonStyle;
  final TwilioCallButtonStyle? muteButtonStyle;
  final TwilioCallButtonStyle? videoButtonStyle;
  final TwilioCallButtonStyle? speakerButtonStyle;
  final TwilioCallButtonStyle? holdButtonStyle;
  final TwilioCallButtonStyle? flipCameraButtonStyle;
  // ── Helpers ──────────────────────────────────────────────────────────────
  Color get effectiveVideoBackground => videoBackgroundColor ?? backgroundColor;
  Color get effectiveDominantSpeakerColor =>
      dominantSpeakerBorderColor ?? networkQualityGoodColor;
  Color get effectivePipBorderColor =>
      pipBorderColor ?? Colors.white.withValues(alpha: 0.3);
  Color get effectiveNameBadgeColor =>
      participantNameBadgeColor ?? Colors.black.withValues(alpha: 0.45);
  Color get effectiveRoomBadgeColor =>
      roomBadgeColor ?? Colors.black.withValues(alpha: 0.55);
  Color get effectiveTileSeparatorColor => tileSeparatorColor ?? Colors.black;
  Color get effectiveVideoMutedColor => videoMutedTileColor ?? Colors.black87;
  // ── Presets ──────────────────────────────────────────────────────────────
  factory TwilioThemeData.dark() => const TwilioThemeData(
        backgroundColor: Color(0xFF1A1A2E),
        controlBarColor: Color(0xFF16213E),
        controlIconColor: Colors.white,
        controlIconActiveColor: Color(0xFF0F3460),
        participantNameColor: Colors.white,
        networkQualityGoodColor: Color(0xFF4CAF50),
        networkQualityPoorColor: Color(0xFFF44336),
      );
  factory TwilioThemeData.light() => const TwilioThemeData(
        backgroundColor: Color(0xFFF5F5F5),
        controlBarColor: Colors.white,
        controlIconColor: Color(0xFF1A1A2E),
        controlIconActiveColor: Color(0xFF0F3460),
        participantNameColor: Color(0xFF1A1A2E),
        networkQualityGoodColor: Color(0xFF4CAF50),
        networkQualityPoorColor: Color(0xFFF44336),
        videoBackgroundColor: Color(0xFF222222),
      );
  factory TwilioThemeData.videoCinema() => const TwilioThemeData(
        backgroundColor: Colors.black,
        videoBackgroundColor: Colors.black,
        controlBarColor: Color(0xFF111111),
        controlIconColor: Colors.white,
        controlIconActiveColor: Colors.orangeAccent,
        participantNameColor: Colors.white,
        networkQualityGoodColor: Colors.greenAccent,
        networkQualityPoorColor: Colors.redAccent,
        dominantSpeakerBorderColor: Colors.orangeAccent,
        dominantSpeakerBorderWidth: 3,
        pipBorderColor: Colors.white24,
        participantNameBadgeColor: Colors.black54,
        roomBadgeColor: Colors.black54,
        controlBarBorderRadius: 0,
        participantTileRadius: 0,
        tileSeparatorColor: Color(0xFF222222),
        endCallButtonStyle: TwilioCallButtonStyle(
          backgroundColor: Colors.redAccent,
          iconColor: Colors.white,
          size: 68,
          iconSize: 30,
        ),
        muteButtonStyle: TwilioCallButtonStyle(
          backgroundColor: Color(0xFF222222),
          iconColor: Colors.white,
        ),
        videoButtonStyle: TwilioCallButtonStyle(
          backgroundColor: Color(0xFF222222),
          iconColor: Colors.white,
        ),
      );
  factory TwilioThemeData.videoPurple() => TwilioThemeData(
        backgroundColor: const Color(0xFF0D0020),
        videoBackgroundColor: const Color(0xFF0D0020),
        controlBarColor: const Color(0xFF1A0040),
        controlIconColor: Colors.white,
        controlIconActiveColor: Colors.purpleAccent,
        participantNameColor: Colors.white,
        networkQualityGoodColor: const Color(0xFF69F0AE),
        networkQualityPoorColor: const Color(0xFFFF5252),
        dominantSpeakerBorderColor: Colors.purpleAccent,
        pipBorderColor: Colors.purple.withValues(alpha: 0.5),
        pipBorderRadius: 16,
        participantTileRadius: 16,
        participantNameBadgeColor: Colors.black45,
        roomBadgeColor: const Color(0xFF1A0040),
        controlBarBorderRadius: 24,
        tileSeparatorColor: const Color(0xFF0D0020),
        incomingBackgroundGradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A0040), Color(0xFF0D0020)],
        ),
        endCallButtonStyle: const TwilioCallButtonStyle(
          backgroundColor: Color(0xFFCC0000),
          iconColor: Colors.white,
          size: 70,
          iconSize: 30,
        ),
        muteButtonStyle: TwilioCallButtonStyle(
          backgroundColor: Colors.purple.withValues(alpha: 0.2),
          iconColor: Colors.white70,
        ),
        videoButtonStyle: TwilioCallButtonStyle(
          backgroundColor: Colors.purple.withValues(alpha: 0.2),
          iconColor: Colors.white70,
        ),
        flipCameraButtonStyle: TwilioCallButtonStyle(
          backgroundColor: Colors.purple.withValues(alpha: 0.2),
          iconColor: Colors.white70,
        ),
      );
  factory TwilioThemeData.videoOcean() => const TwilioThemeData(
        backgroundColor: Color(0xFF003049),
        videoBackgroundColor: Color(0xFF001E33),
        controlBarColor: Color(0xFF003049),
        controlIconColor: Colors.white,
        controlIconActiveColor: Color(0xFF00B4D8),
        participantNameColor: Colors.white,
        networkQualityGoodColor: Color(0xFF80FFDB),
        networkQualityPoorColor: Color(0xFFEF233C),
        dominantSpeakerBorderColor: Color(0xFF00B4D8),
        pipBorderColor: Color(0xFF00B4D8),
        roomBadgeColor: Color(0xFF003049),
        controlBarBorderRadius: 20,
        tileSeparatorColor: Color(0xFF001E33),
        endCallButtonStyle: TwilioCallButtonStyle(
          backgroundColor: Color(0xFFEF233C),
          iconColor: Colors.white,
          size: 68,
        ),
      );
  TwilioThemeData copyWith({
    Color? backgroundColor,
    Color? controlBarColor,
    Color? controlIconColor,
    Color? controlIconActiveColor,
    Color? participantNameColor,
    Color? networkQualityGoodColor,
    Color? networkQualityPoorColor,
    double? controlBarBorderRadius,
    double? controlIconSize,
    double? participantTileRadius,
    Color? videoBackgroundColor,
    Color? participantTileBorderColor,
    double? participantTileBorderWidth,
    Color? dominantSpeakerBorderColor,
    double? dominantSpeakerBorderWidth,
    Color? pipBorderColor,
    double? pipBorderWidth,
    double? pipBorderRadius,
    double? pipWidth,
    double? pipHeight,
    Color? participantNameBadgeColor,
    Color? waitingOverlayColor,
    Color? roomBadgeColor,
    bool? controlBarBlur,
    Color? tileSeparatorColor,
    Color? videoMutedTileColor,
    Widget? avatarWidget,
    double? avatarRadius,
    Color? avatarBackgroundColor,
    IconData? avatarIcon,
    Color? avatarIconColor,
    TextStyle? callerNameStyle,
    TextStyle? callStatusStyle,
    TextStyle? callDurationStyle,
    TextStyle? buttonLabelStyle,
    TextStyle? participantNameStyle,
    String? ringtonePath,
    bool? ringtoneLoop,
    Gradient? incomingBackgroundGradient,
    TwilioCallButtonStyle? acceptButtonStyle,
    TwilioCallButtonStyle? rejectButtonStyle,
    TwilioCallButtonStyle? endCallButtonStyle,
    TwilioCallButtonStyle? muteButtonStyle,
    TwilioCallButtonStyle? videoButtonStyle,
    TwilioCallButtonStyle? speakerButtonStyle,
    TwilioCallButtonStyle? holdButtonStyle,
    TwilioCallButtonStyle? flipCameraButtonStyle,
  }) =>
      TwilioThemeData(
        backgroundColor: backgroundColor ?? this.backgroundColor,
        controlBarColor: controlBarColor ?? this.controlBarColor,
        controlIconColor: controlIconColor ?? this.controlIconColor,
        controlIconActiveColor: controlIconActiveColor ?? this.controlIconActiveColor,
        participantNameColor: participantNameColor ?? this.participantNameColor,
        networkQualityGoodColor: networkQualityGoodColor ?? this.networkQualityGoodColor,
        networkQualityPoorColor: networkQualityPoorColor ?? this.networkQualityPoorColor,
        controlBarBorderRadius: controlBarBorderRadius ?? this.controlBarBorderRadius,
        controlIconSize: controlIconSize ?? this.controlIconSize,
        participantTileRadius: participantTileRadius ?? this.participantTileRadius,
        videoBackgroundColor: videoBackgroundColor ?? this.videoBackgroundColor,
        participantTileBorderColor: participantTileBorderColor ?? this.participantTileBorderColor,
        participantTileBorderWidth: participantTileBorderWidth ?? this.participantTileBorderWidth,
        dominantSpeakerBorderColor: dominantSpeakerBorderColor ?? this.dominantSpeakerBorderColor,
        dominantSpeakerBorderWidth: dominantSpeakerBorderWidth ?? this.dominantSpeakerBorderWidth,
        pipBorderColor: pipBorderColor ?? this.pipBorderColor,
        pipBorderWidth: pipBorderWidth ?? this.pipBorderWidth,
        pipBorderRadius: pipBorderRadius ?? this.pipBorderRadius,
        pipWidth: pipWidth ?? this.pipWidth,
        pipHeight: pipHeight ?? this.pipHeight,
        participantNameBadgeColor: participantNameBadgeColor ?? this.participantNameBadgeColor,
        waitingOverlayColor: waitingOverlayColor ?? this.waitingOverlayColor,
        roomBadgeColor: roomBadgeColor ?? this.roomBadgeColor,
        controlBarBlur: controlBarBlur ?? this.controlBarBlur,
        tileSeparatorColor: tileSeparatorColor ?? this.tileSeparatorColor,
        videoMutedTileColor: videoMutedTileColor ?? this.videoMutedTileColor,
        avatarWidget: avatarWidget ?? this.avatarWidget,
        avatarRadius: avatarRadius ?? this.avatarRadius,
        avatarBackgroundColor: avatarBackgroundColor ?? this.avatarBackgroundColor,
        avatarIcon: avatarIcon ?? this.avatarIcon,
        avatarIconColor: avatarIconColor ?? this.avatarIconColor,
        callerNameStyle: callerNameStyle ?? this.callerNameStyle,
        callStatusStyle: callStatusStyle ?? this.callStatusStyle,
        callDurationStyle: callDurationStyle ?? this.callDurationStyle,
        buttonLabelStyle: buttonLabelStyle ?? this.buttonLabelStyle,
        participantNameStyle: participantNameStyle ?? this.participantNameStyle,
        ringtonePath: ringtonePath ?? this.ringtonePath,
        ringtoneLoop: ringtoneLoop ?? this.ringtoneLoop,
        incomingBackgroundGradient: incomingBackgroundGradient ?? this.incomingBackgroundGradient,
        acceptButtonStyle: acceptButtonStyle ?? this.acceptButtonStyle,
        rejectButtonStyle: rejectButtonStyle ?? this.rejectButtonStyle,
        endCallButtonStyle: endCallButtonStyle ?? this.endCallButtonStyle,
        muteButtonStyle: muteButtonStyle ?? this.muteButtonStyle,
        videoButtonStyle: videoButtonStyle ?? this.videoButtonStyle,
        speakerButtonStyle: speakerButtonStyle ?? this.speakerButtonStyle,
        holdButtonStyle: holdButtonStyle ?? this.holdButtonStyle,
        flipCameraButtonStyle: flipCameraButtonStyle ?? this.flipCameraButtonStyle,
      );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TwilioThemeData &&
          backgroundColor == other.backgroundColor &&
          controlBarColor == other.controlBarColor &&
          ringtonePath == other.ringtonePath;
  @override
  int get hashCode =>
      backgroundColor.hashCode ^ controlBarColor.hashCode ^ ringtonePath.hashCode;
}
