import 'package:flutter/material.dart';

import '../../models/participant.dart';
import '../../theme/twilio_theme.dart';
import '../widgets/twilio_avatar.dart' show TwilioAvatar;
import 'twilio_video_view.dart';

/// Displays a single remote participant's video tile with name and quality.
class TwilioParticipantTile extends StatelessWidget {
  const TwilioParticipantTile({
    super.key,
    required this.participant,
    this.child,
    this.showNameBadge = true,
  });

  final Participant participant;

  /// Optional custom renderer. Falls back to video view / avatar when null.
  final Widget? child;

  /// Whether to show the name badge at the bottom of the tile.
  /// Set to [false] in full-screen single-participant view to avoid duplicating
  /// the name that is already shown in the bottom name strip.
  final bool showNameBadge;

  @override
  Widget build(BuildContext context) {
    final theme = TwilioTheme.of(context);
    final radius = theme.participantTileRadius;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Video / avatar ──────────────────────────────────────────────
          child ??
              (participant.isVideoEnabled
                  ? TwilioVideoView(trackId: participant.sid)
                  : Container(
                      color: theme.effectiveVideoMutedColor,
                        child: Center(
                          child: TwilioAvatar.build(
                            identity: participant.identity,
                            size: 64,
                          ),
                        ),
                    )),

          // ── Participant name badge ────────────────────────────────────────
          if (showNameBadge)
            Positioned(
            bottom: 8,
            left: 8,
            right: 48,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: theme.effectiveNameBadgeColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipOval(
                    child: TwilioAvatar.build(
                      identity: participant.identity,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 5),
                  if (!participant.isAudioEnabled) ... [
                    const Icon(Icons.mic_off, size: 13, color: Colors.redAccent),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Text(
                      participant.identity,
                      style: theme.participantNameStyle ??
                          TextStyle(
                              color: theme.participantNameColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Network quality indicator ────────────────────────────────────
          Positioned(
            bottom: 8,
            right: 8,
            child: _NetworkQualityBadge(level: participant.networkQualityLevel),
          ),

          // ── Dominant speaker highlight ───────────────────────────────────
          if (participant.isDominantSpeaker)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: theme.effectiveDominantSpeakerColor,
                    width: theme.dominantSpeakerBorderWidth,
                  ),
                  borderRadius: BorderRadius.circular(radius),
                ),
              ),
            ),

          // ── Optional per-tile border ─────────────────────────────────────
          if (theme.participantTileBorderColor != null &&
              theme.participantTileBorderWidth > 0 &&
              !participant.isDominantSpeaker)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: theme.participantTileBorderColor!,
                    width: theme.participantTileBorderWidth,
                  ),
                  borderRadius: BorderRadius.circular(radius),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NetworkQualityBadge extends StatelessWidget {
  const _NetworkQualityBadge({required this.level});
  final int level;

  @override
  Widget build(BuildContext context) {
    final theme = TwilioTheme.of(context);
    final color = level >= 3
        ? theme.networkQualityGoodColor
        : theme.networkQualityPoorColor;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(
        5,
        (i) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 1),
          width: 4,
          height: (i + 1) * 3.0,
          decoration: BoxDecoration(
            color: i < level ? color : Colors.white30,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
