import 'package:flutter/material.dart';
import 'twilio_video_view.dart';

/// Floating local camera preview widget.
///
/// In production this renders the native local camera track.
/// Pass [fit] to control how the video fills the available space.
class TwilioVideoPreview extends StatelessWidget {
  const TwilioVideoPreview({
    super.key,
    this.borderRadius = 8.0,
    this.fit = BoxFit.cover,
  });

  final double borderRadius;

  /// How the video frame is inscribed into the widget bounds.
  /// Defaults to [BoxFit.cover] (fills the tile, may crop edges).
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: TwilioVideoView(
        trackId: TwilioVideoView.localTrackId,
        fit: fit,
      ),
    );
  }
}
