import 'package:flutter/material.dart';
import 'package:flutter_twilio_commkit/flutter_twilio_commkit.dart';
import 'package:flutter_twilio_commkit/src/ui/widgets/twilio_avatar.dart';

/// Demonstrates full customization of the video call screen:
/// - Custom controls builder
/// - Custom participant tile builder
/// - Custom theme
class CustomVideoScreen extends StatelessWidget {
  const CustomVideoScreen({
    super.key,
    required this.roomName,
    required this.accessToken,
    this.localIdentity = '',
  });

  final String roomName;
  final String accessToken;
  final String localIdentity;

  @override
  Widget build(BuildContext context) {
    final customTheme = TwilioThemeData.dark().copyWith(
      controlBarColor: const Color(0xFF0A1628),
      controlIconColor: const Color(0xFF00D9FF),
      controlIconActiveColor: const Color(0xFFFF4081),
      participantTileRadius: 20.0,
    );

    return TwilioVideoCallScreen(
      roomName: roomName,
      accessToken: accessToken,
      localIdentity: localIdentity,
      theme: customTheme,
      enableVideo: true,
      enableAudio: true,
      onRoomDisconnected: (_) => Navigator.pop(context),

      // Custom controls bar
      controlsBuilder: (context, state) => _CustomControls(state: state),

      // Custom participant tile with identity initial override
      participantBuilder: (context, participant) => _CustomParticipantTile(
        participant: participant,
      ),
    );
  }
}

class _CustomControls extends StatelessWidget {
  const _CustomControls({required this.state});
  final dynamic state; // _VideoCallState

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A1628), Color(0xFF1B2A4A)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _GlowButton(
            icon: Icons.mic,
            color: const Color(0xFF00D9FF),
            onTap: () => TwilioVideo.instance.muteAudio(muted: false),
          ),
          _GlowButton(
            icon: Icons.videocam,
            color: const Color(0xFF00D9FF),
            onTap: () => TwilioVideo.instance.muteVideo(muted: false),
          ),
          _GlowButton(
            icon: Icons.flip_camera_ios,
            color: const Color(0xFF7C4DFF),
            onTap: () => TwilioVideo.instance.switchCamera(),
          ),
          _GlowButton(
            icon: Icons.call_end,
            color: const Color(0xFFFF4081),
            onTap: () async {
              await TwilioVideo.instance.disconnect();
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

class _GlowButton extends StatelessWidget {
  const _GlowButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.15),
          border: Border.all(color: color, width: 1.5),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 12),
          ],
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }
}

class _CustomParticipantTile extends StatelessWidget {
  const _CustomParticipantTile({required this.participant});
  final Participant participant;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B2A4A), Color(0xFF0A1628)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: participant.isDominantSpeaker
            ? Border.all(color: const Color(0xFF00D9FF), width: 2)
            : null,
      ),
      child: Stack(
        children: [
          Center(
            child: TwilioAvatar.build(
              identity: participant.identity,
              size: 56,
            ),
          ),
          Positioned(
            bottom: 8,
            left: 8,
            right: 8,
            child: Text(
              participant.identity,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

