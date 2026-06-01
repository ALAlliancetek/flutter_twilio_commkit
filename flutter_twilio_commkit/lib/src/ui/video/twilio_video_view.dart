import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Renders a native Twilio video track on screen.
///
/// Pass [trackId] as:
/// - `"__local__"` for the local camera preview
/// - remote participant SID for a remote participant's video
///
/// Falls back to a black box on unsupported platforms.
class TwilioVideoView extends StatelessWidget {
  const TwilioVideoView({
    super.key,
    required this.trackId,
    this.fit = BoxFit.cover,
  });

  /// Track identifier. Use [localTrackId] constant for local preview,
  /// or a remote participant's SID for their video.
  final String trackId;
  final BoxFit fit;

  /// Constant track ID for the local camera preview.
  static const String localTrackId = '__local__';

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return ClipRect(
        child: SizedBox.expand(
          child: AndroidView(
            viewType: 'com.twiliocommkit/video_view',
            layoutDirection: TextDirection.ltr,
            creationParams: {'trackId': trackId},
            creationParamsCodec: const StandardMessageCodec(),
            gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
          ),
        ),
      );
    }

    // iOS / unsupported: placeholder
    return Container(
      color: Colors.black,
      child: const Center(
        child: Icon(Icons.videocam, color: Colors.white38, size: 32),
      ),
    );
  }
}

