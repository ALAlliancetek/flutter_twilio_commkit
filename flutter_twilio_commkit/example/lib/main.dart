// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_twilio_commkit/flutter_twilio_commkit.dart';

/// Minimal example showing how to integrate [flutter_twilio_commkit].
///
/// Replace the placeholder constants with your real values.
/// See the full integration guide at:
/// https://github.com/ALAlliancetek/flutter_twilio_commkit/blob/main/docs/integration_guide.md
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Register the native call-result channel before runApp so it is ready
  // even in the killed-app incoming-call scenario.
  TwilioCallHandlerService.startListening();

  await TwilioCommKit.initialize(
    config: TwilioCommKitConfig(
      credentials: const TwilioCredentials(
        accountSid: 'YOUR_ACCOUNT_SID',
        apiKeySid: 'YOUR_API_KEY_SID',
        outgoingApplicationSid: 'YOUR_TWIML_APP_SID',
        pushCredentialSid: 'YOUR_PUSH_CREDENTIAL_SID',
      ),
      // accessTokenProvider is called by the SDK whenever a fresh token is needed.
      // Fetch the token from YOUR backend server – never generate it on-device.
      accessTokenProvider: () async {
        // Example: fetch from your token server
        // final res = await http.get(Uri.parse('https://your-server.com/token/voice?identity=alice'));
        // return jsonDecode(res.body)['token'] as String;
        throw UnimplementedError('Provide your own token server URL.');
      },
      voiceConfig: const TwilioVoiceConfig(callerIdName: 'alice'),
      logLevel: TwilioLogLevel.debug,
    ),
  );

  runApp(
    // ProviderScope is required by flutter_riverpod, used internally by the SDK.
    const ProviderScope(child: ExampleApp()),
  );
}

/// Root widget – wraps [TwilioCallHandler] so ALL incoming call states
/// (foreground, background, killed-app) are handled automatically.
class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_twilio_commkit example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: TwilioCallHandler(
        theme: TwilioThemeData.dark(),
        child: const HomeScreen(),
      ),
    );
  }
}

/// Simple home screen demonstrating outgoing voice and video calls.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _status = 'Ready';

  // ---------------------------------------------------------------------------
  // Voice call
  // ---------------------------------------------------------------------------

  Future<void> _startVoiceCall() async {
    setState(() => _status = 'Starting voice call…');
    try {
      // 1. Initialize Voice SDK with a fresh access token.
      // In production, fetch the token from your backend.
      await TwilioVoice.instance.initialize(
        accessToken: 'YOUR_VOICE_ACCESS_TOKEN',
      );

      // 2. Start the call.
      final call = await TwilioVoice.instance.startCall(to: 'bob');

      // 3. Navigate to the built-in call screen.
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TwilioVoiceCallScreen(
            callSid: call.callSid,
            remoteIdentity: 'bob',
            theme: TwilioThemeData.dark(),
            onCallEnded: () => Navigator.pop(context),
          ),
        ),
      );
      setState(() => _status = 'Call ended');
    } on TwilioCallException catch (e) {
      setState(() => _status = 'Error: ${e.message}');
    }
  }

  // ---------------------------------------------------------------------------
  // Video call
  // ---------------------------------------------------------------------------

  Future<void> _startVideoCall() async {
    setState(() => _status = 'Joining video room…');
    try {
      // Navigate to the built-in video call screen.
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TwilioVideoCallScreen(
            roomName: 'example-room',
            accessToken: 'YOUR_VIDEO_ACCESS_TOKEN',
            localIdentity: 'alice',
            theme: TwilioThemeData.videoPurple(),
            onRoomConnected: () => setState(() => _status = 'In video call'),
            onRoomDisconnected: (_) => Navigator.pop(context),
          ),
        ),
      );
      setState(() => _status = 'Video call ended');
    } on TwilioCallException catch (e) {
      setState(() => _status = 'Error: ${e.message}');
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('flutter_twilio_commkit')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _status,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              icon: const Icon(Icons.call),
              label: const Text('Voice call'),
              onPressed: _startVoiceCall,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.videocam),
              label: const Text('Video call'),
              onPressed: _startVideoCall,
            ),
          ],
        ),
      ),
    );
  }
}

