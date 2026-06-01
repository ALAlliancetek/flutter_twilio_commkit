import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../screens/custom_video_screen.dart';
import '../screens/settings_screen.dart';
import '../services/twilio_token_service.dart';


/// Advanced Video call screen with custom UI and theming.
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
      appBar: AppBar(title: const Text('Video Call')),
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

            if (_error != null)
              _ErrorBanner(_error!),

            if (_lastToken != null)
              _TokenBanner(_lastToken!),

            const SizedBox(height: 16),

            OutlinedButton.icon(
              icon: const Icon(Icons.key),
              label: const Text('Fetch Token Only (Test)'),
              onPressed: _loading ? null : _fetchTokenOnly,
            ),
            const SizedBox(height: 12),

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

  Future<void> _joinRoom() async {
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

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await TwilioTokenService.instance
        .fetchVideoToken(roomName: AppSettings.roomName);

    if (!mounted) return;

    switch (result) {
      case TokenFailure(:final message):
        setState(() {
          _loading = false;
          _error = message;
        });
      case TokenSuccess(:final token):
        setState(() {
          _loading = false;
          _lastToken = token;
        });
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CustomVideoScreen(
              accessToken: token,
              roomName: AppSettings.roomName,
              localIdentity: AppSettings.identity,
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
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.red.shade900.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade700),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.error_outline, color: Colors.red, size: 18),
        const SizedBox(width: 8),
        Expanded(
            child: Text(message,
                style: const TextStyle(color: Colors.red, fontSize: 13))),
      ]),
    );
  }
}

class _TokenBanner extends StatelessWidget {
  const _TokenBanner(this.token);
  final String token;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.green.shade900.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade700),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('✅ Token fetched successfully',
            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          token.length > 60 ? '${token.substring(0, 60)}…' : token,
          style: const TextStyle(
              fontFamily: 'monospace', fontSize: 11, color: Colors.green),
        ),
      ]),
    );
  }
}



