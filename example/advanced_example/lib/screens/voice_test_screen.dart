import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_twilio_commkit/flutter_twilio_commkit.dart';
import 'package:permission_handler/permission_handler.dart';

import '../screens/settings_screen.dart';
import '../services/notification_service.dart';
import '../services/twilio_token_service.dart';

/// Advanced Voice call screen with custom theming.
class VoiceTestScreen extends StatefulWidget {
  const VoiceTestScreen({super.key});

  @override
  State<VoiceTestScreen> createState() => _VoiceTestScreenState();
}

class _VoiceTestScreenState extends State<VoiceTestScreen> {
  bool _loading = false;
  bool _voiceReady = false;
  String? _error;
  String? _lastToken;
  // Incoming call notifications are handled globally in main.dart
  // to avoid duplicate screens. No local subscription needed here.

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final callTo = AppSettings.callTo;
    final identity = TwilioTokenService.instance.currentIdentity;
    final sameIdentityWarning = identity == callTo;

    return Scaffold(
      appBar: AppBar(title: const Text('Voice Call')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Quick identity switcher ───────────────────────────────
            _QuickIdentityCard(
              currentIdentity: identity,
              onSwitch: _switchIdentity,
              voiceReady: _voiceReady,
            ),
            const SizedBox(height: 12),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoRow('Server', TwilioTokenService.instance.currentBaseUrl),
                    _InfoRow('Identity', identity),
                    _InfoRow('Call To', callTo),
                    _InfoRow(
                      'FCM Token',
                      NotificationService.instance.currentFcmToken != null
                          ? '${NotificationService.instance.currentFcmToken!.substring(0, 16)}…'
                          : 'Not available — add google-services.json',
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      Icon(
                        _voiceReady ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 16,
                        color: _voiceReady ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _voiceReady ? 'Voice SDK Ready' : 'Voice SDK not initialized',
                        style: TextStyle(
                            color: _voiceReady ? Colors.green : Colors.grey,
                            fontSize: 13),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Warning: same identity as callTo
            if (sameIdentityWarning)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade900.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade700),
                ),
                child: Row(children: [
                  const Icon(Icons.warning_amber, color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Identity "$identity" = Call To "$callTo"\n'
                      'You cannot call yourself! Use the switcher above.',
                      style: const TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  ),
                ]),
              ),

            const SizedBox(height: 4),

            if (_error != null) _ErrorBanner(_error!),
            if (_lastToken != null) _TokenBanner(_lastToken!),

            const SizedBox(height: 12),

            _HowToTestCard(),
            const SizedBox(height: 16),

            if (!_voiceReady) ...[
              ElevatedButton.icon(
                icon: _loading
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.phone_android),
                label: Text(_loading ? 'Fetching token…' : 'Initialize Voice SDK'),
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: _loading ? null : _initVoice,
              ),
            ] else ...[
              ElevatedButton.icon(
                icon: _loading
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.call),
                label: Text(_loading ? 'Starting call…' : 'Call "$callTo"'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _loading ? null : _makeCall,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Re-initialize Voice'),
                onPressed: _loading ? null : _initVoice,
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.key),
              label: const Text('Fetch Voice Token Only'),
              onPressed: _loading ? null : _fetchTokenOnly,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _switchIdentity() async {
    final current = TwilioTokenService.instance.currentIdentity;
    final next = current == 'flutter-tester-1' ? 'flutter-tester-2' : 'flutter-tester-1';
    final callTo = current == 'flutter-tester-1' ? 'flutter-tester-1' : 'flutter-tester-2';
    await AppSettings.save(
      serverUrl: AppSettings.serverUrl,
      identity: next,
      roomName: AppSettings.roomName,
      callTo: callTo,
    );
    setState(() {
      _voiceReady = false;
      _error = null;
      _lastToken = null;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Identity switched to "$next" — tap Initialize Voice SDK'),
        backgroundColor: Colors.blue.shade800,
        duration: const Duration(seconds: 3),
      ));
    }
  }

  Future<void> _fetchTokenOnly() async {
    setState(() {
      _loading = true;
      _error = null;
      _lastToken = null;
    });
    final result = await TwilioTokenService.instance.fetchVoiceToken();
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

  Future<void> _initVoice() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      setState(() {
        _error = 'Microphone permission denied. Please grant it in device settings.';
      });
      if (status.isPermanentlyDenied) openAppSettings();
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await TwilioTokenService.instance.fetchVoiceToken();
    if (!mounted) return;

    switch (result) {
      case TokenFailure(:final message):
        setState(() {
          _loading = false;
          _error = message;
        });
        return;
      case TokenSuccess(:final token):
        _lastToken = token;
        try {
          final fcmToken = NotificationService.instance.currentFcmToken;
          await TwilioVoice.instance.initialize(
            accessToken: token,
            fcmToken: fcmToken,
          );
          setState(() {
            _loading = false;
            _voiceReady = true;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(fcmToken != null
                    ? 'Voice SDK initialized ✓ FCM registered — incoming calls enabled'
                    : 'Voice SDK initialized ✓ (No FCM token — outgoing only)'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          setState(() {
            _loading = false;
            _error = 'Voice init failed: $e';
          });
        }
    }
  }

  Future<void> _makeCall() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      setState(() {
        _error = 'Microphone permission denied. Please grant it in device settings.';
      });
      if (status.isPermanentlyDenied) openAppSettings();
      return;
    }

    final callTo = AppSettings.callTo;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final call = await TwilioVoice.instance.startCall(
        to: callTo,
        params: {'identity': TwilioTokenService.instance.currentIdentity},
      );
      if (!mounted) return;
      setState(() => _loading = false);

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TwilioVoiceCallScreen(
            callSid: call.callSid,
            remoteIdentity: callTo,
            theme: TwilioThemeData.dark(),
            onCallEnded: () => Navigator.pop(context),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Call failed: $e';
      });
    }
  }

}

class _HowToTestCard extends StatelessWidget {
  const _HowToTestCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.blue.shade900.withValues(alpha: 0.15),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.info_outline, size: 16, color: Colors.lightBlue),
            SizedBox(width: 6),
            Text('How to test Voice calls',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.lightBlue)),
          ]),
          const SizedBox(height: 8),
          const Text(
            '• Device A identity: "flutter-advanced-1"\n'
            '• Device A "Call To": "flutter-tester-2"\n'
            '• Device B identity: "flutter-tester-2"\n'
            '• Device B "Call To": "flutter-advanced-1"\n\n'
            '→ Go to Settings ⚙ to change identity & call-to\n'
            '→ Both devices must be connected to the same token server\n'
            '→ Token server needs TWILIO_TWIML_APP_SID set in .env',
            style: TextStyle(fontSize: 12, height: 1.6, color: Colors.white70),
          ),
        ]),
      ),
    );
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
      child: Row(children: [
        SizedBox(
          width: 70,
          child: Text('$label:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
        ),
      ]),
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
        const Text('✅ Token fetched',
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

// ─── Quick Identity Switcher Card ─────────────────────────────────────────────

class _QuickIdentityCard extends StatelessWidget {
  const _QuickIdentityCard({
    required this.currentIdentity,
    required this.onSwitch,
    required this.voiceReady,
  });
  final String currentIdentity;
  final VoidCallback onSwitch;
  final bool voiceReady;

  @override
  Widget build(BuildContext context) {
    final isDevice1 = currentIdentity == 'flutter-tester-1';
    final color = isDevice1 ? Colors.blue.shade800 : Colors.purple.shade800;
    return Card(
      color: color.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Icon(Icons.smartphone, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                isDevice1 ? 'This is Device A (Caller)' : 'This is Device B (Receiver)',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isDevice1 ? Colors.blue.shade300 : Colors.purple.shade300),
              ),
              Text(
                'Identity: $currentIdentity  •  Calls: ${isDevice1 ? "flutter-tester-2" : "flutter-tester-1"}',
                style: const TextStyle(fontSize: 11, color: Colors.white60),
              ),
            ]),
          ),
          TextButton(
            onPressed: onSwitch,
            child: Text(
              isDevice1 ? 'Switch → B' : 'Switch → A',
              style: TextStyle(fontSize: 12, color: color),
            ),
          ),
        ]),
      ),
    );
  }
}

