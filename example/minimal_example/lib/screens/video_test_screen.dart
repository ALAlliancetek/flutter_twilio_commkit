import 'package:flutter/material.dart';
import 'package:flutter_twilio_commkit/flutter_twilio_commkit.dart';
import 'package:permission_handler/permission_handler.dart';

import '../screens/settings_screen.dart';
import '../services/twilio_token_service.dart';

/// Video call launch screen.
/// Fetches a token from the server, shows a preview, then joins the room.
class VideoTestScreen extends StatefulWidget {
  const VideoTestScreen({super.key});

  @override
  State<VideoTestScreen> createState() => _VideoTestScreenState();
}

class _VideoTestScreenState extends State<VideoTestScreen> {
  bool _loading = false;
  String? _error;
  String? _lastToken;

  @override
  Widget build(BuildContext context) {
    final roomName = AppSettings.roomName;

    return Scaffold(
      appBar: AppBar(title: const Text('Video Call Test')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoRow('Server', TwilioTokenService.instance.currentBaseUrl),
                    _InfoRow('Identity', TwilioTokenService.instance.currentIdentity),
                    _InfoRow('Room', roomName),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Error
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade700),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_error!,
                        style: const TextStyle(color: Colors.red, fontSize: 13)),
                  ),
                ]),
              ),

            // Token preview
            if (_lastToken != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.green.shade900.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade700),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('✅ Token fetched successfully',
                          style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        _lastToken!.length > 60
                            ? '${_lastToken!.substring(0, 60)}…'
                            : _lastToken!,
                        style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: Colors.green),
                      ),
                    ]),
              ),

            const SizedBox(height: 16),

            // Fetch token button
            OutlinedButton.icon(
              icon: const Icon(Icons.key),
              label: const Text('Fetch Token Only (Test)'),
              onPressed: _loading ? null : _fetchTokenOnly,
            ),
            const SizedBox(height: 12),

            // Join room button
            ElevatedButton.icon(
              icon: _loading
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.videocam),
              label: Text(_loading ? 'Fetching token…' : 'Join Room "$roomName"'),
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              onPressed: _loading ? null : _joinRoom,
            ),
          ],
        ),
      ),
    );
  }

  /// Only fetches + shows the token without joining the room.
  Future<void> _fetchTokenOnly() async {
    setState(() {
      _loading = true;
      _error = null;
      _lastToken = null;
    });

    final result = await TwilioTokenService.instance
        .fetchVideoToken(roomName: AppSettings.roomName);

    if (!mounted) return;
    setState(() {
      _loading = false;
      switch (result) {
        case TokenSuccess(:final token):
          _lastToken = token;
        case TokenFailure(:final message):
          _error = message;
      }
    });
  }

  /// Fetches token then opens the built-in video call screen.
  Future<void> _joinRoom() async {
    // Request camera + microphone permissions before joining
    final statuses = await [
      Permission.camera,
      Permission.microphone,
    ].request();

    final cameraDenied = statuses[Permission.camera] != PermissionStatus.granted;
    final micDenied = statuses[Permission.microphone] != PermissionStatus.granted;

    if (cameraDenied || micDenied) {
      final denied = [
        if (cameraDenied) 'Camera',
        if (micDenied) 'Microphone',
      ].join(' & ');
      setState(() {
        _error = '$denied permission denied. Please grant it in device settings.';
      });
      final anyPermanent =
          statuses[Permission.camera]?.isPermanentlyDenied == true ||
          statuses[Permission.microphone]?.isPermanentlyDenied == true;
      if (anyPermanent) openAppSettings();
      return;
    }

    setState(() { _loading = true; _error = null; });

    final result = await TwilioTokenService.instance
        .fetchVideoToken(roomName: AppSettings.roomName);

    if (!mounted) return;

    switch (result) {
      case TokenFailure(:final message):
        setState(() { _loading = false; _error = message; });
      case TokenSuccess(:final token):
        setState(() { _loading = false; _lastToken = token; });
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TwilioVideoCallScreen(
              accessToken: token,
              roomName: AppSettings.roomName,
              localIdentity: AppSettings.identity,
              theme: TwilioThemeData.dark(),
              onRoomConnected: () => debugPrint('Room connected'),
              onRoomDisconnected: (reason) {
                debugPrint('Room disconnected: $reason');
                Navigator.pop(context);
              },
            ),
          ),
        );
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text('$label:',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

