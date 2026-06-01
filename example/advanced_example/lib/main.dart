import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_twilio_commkit/flutter_twilio_commkit.dart';

import 'config/twilio_app_config.dart';
import 'screens/settings_screen.dart';
import 'screens/video_test_screen.dart';
import 'screens/voice_test_screen.dart';
import 'services/notification_service.dart';
import 'services/twilio_token_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppSettings.load();

  // Initialise Firebase + FCM push notifications
  try {
    await NotificationService.instance.initialise();
  } catch (e) {
    debugPrint('[main] Firebase/notification init failed: $e\n'
        '  → Run `flutterfire configure` and add google-services.json');
  }

  // Initialize the Twilio SDK
  await TwilioCommKit.initialize(
    config: TwilioCommKitConfig(
      credentials: TwilioCredentials(
        accountSid: TwilioAppConfig.accountSid,
        apiKeySid: TwilioAppConfig.apiKeySid,
        outgoingApplicationSid: TwilioAppConfig.outgoingApplicationSid,
        pushCredentialSid: TwilioAppConfig.pushCredentialSid,
      ),
      accessTokenProvider: TwilioTokenService.instance.fetchToken,
      videoConfig: const TwilioVideoConfig(
        roomType: TwilioRoomType.group,
        enableNetworkQuality: true,
        enableDominantSpeaker: true,
        preferredVideoCodec: TwilioVideoCodec.vp8,
        // Maximum total participants (including yourself).
        // When reached: join is blocked with "Room Full" error,
        // and the participant count badge turns orange.
        // Set to null to remove the client-side limit (server limit still applies).
        maxParticipants: 10,
      ),
      voiceConfig: TwilioVoiceConfig(
        callerIdName: TwilioAppConfig.userIdentity,
        enableCallKit: true,
        enableForegroundService: true,
        enableInsights: true,
        // ── Custom notification icon (Android) ──────────────────────────
        // Name of a drawable/mipmap resource in your app's res/ folder.
        // e.g. add  android/app/src/main/res/drawable/ic_notification.png
        // then reference it here as 'ic_notification'.
        notificationIconName: 'ic_launcher',  // uses the app launcher icon as fallback demo
        // ── Custom CallKit icon (iOS) ────────────────────────────────────
        // Flutter asset path; the image must be a square PNG ≤ 40×40 pt, template style.
        // Add it to pubspec.yaml under flutter > assets.
        // callKitIconAssetPath: 'assets/images/call_icon.png',
      ),
      logLevel: TwilioLogLevel.debug,
    ),
  );

  runApp(const ProviderScope(child: AdvancedExampleApp()));
}

class AdvancedExampleApp extends StatelessWidget {
  const AdvancedExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return TwilioTheme(
      data: TwilioThemeData.dark(),
      child: MaterialApp(
        title: 'Twilio CommKit — Advanced',
        debugShowCheckedModeBanner: false,
        darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1A0533),
            brightness: Brightness.dark,
          ),
        ),
        themeMode: ThemeMode.dark,
        // ── TwilioCallHandler wraps the home screen ───────────────────────
        // This single widget handles ALL incoming call scenarios:
        //   • App in foreground (Voice SDK event)
        //   • App in background (FCM notification)
        //   • App killed (TwilioIncomingCallActivity → launch intent)
        home: TwilioCallHandler(
          theme: TwilioThemeData.dark(),
          child: const _AdvancedHomeScreen(),
        ),
      ),
    );
  }
}

class _AdvancedHomeScreen extends StatefulWidget {
  const _AdvancedHomeScreen();

  @override
  State<_AdvancedHomeScreen> createState() => _AdvancedHomeScreenState();
}

class _AdvancedHomeScreenState extends State<_AdvancedHomeScreen> {
  StreamSubscription<String>? _fcmTokenSub;
  String? _fcmToken;

  @override
  void initState() {
    super.initState();
    _fcmTokenSub = NotificationService.instance.onFcmToken.listen((token) {
      if (mounted) setState(() => _fcmToken = token);
    });
    _fcmToken = NotificationService.instance.currentFcmToken;
  }

  @override
  void dispose() {
    _fcmTokenSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Twilio CommKit — Advanced'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Configure server URL & identity',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _ServerStatusCard(),
          const SizedBox(height: 12),
          _FcmTokenCard(token: _fcmToken),
          const SizedBox(height: 24),
          const Text('Features',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _FeatureTile(
            icon: Icons.videocam,
            color: const Color(0xFF1A0533),
            title: 'Custom Video Call UI',
            subtitle: 'Themed video call with custom controls & participant tiles\n'
                'Tests: connect, mute, camera switch, participants',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VideoTestScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _FeatureTile(
            icon: Icons.call,
            color: const Color(0xFF0D2B0D),
            title: 'Voice Call',
            subtitle:
                'Fetch token → Initialize Voice SDK → Make / Receive calls\n'
                'Tests: outgoing, incoming (FCM push), mute, hold, speaker',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VoiceTestScreen()),
            ),
          ),
          const SizedBox(height: 24),
          _ThemeSwitcher(),
          const SizedBox(height: 16),
          _QuickHelp(),
        ],
      ),
    );
  }
}

// ─── FCM Token Card ───────────────────────────────────────────────────────────

class _FcmTokenCard extends StatelessWidget {
  const _FcmTokenCard({this.token});
  final String? token;

  @override
  Widget build(BuildContext context) {
    final hasToken = token != null && token!.isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Icon(
            hasToken ? Icons.notifications_active : Icons.notifications_off,
            color: hasToken ? Colors.green : Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                hasToken ? 'Push Notifications Ready' : 'Push Notifications Not Ready',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: hasToken ? Colors.green : Colors.orange,
                ),
              ),
              Text(
                hasToken
                    ? 'FCM token: ${token!.substring(0, 20)}…'
                    : 'Add google-services.json to enable FCM',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─── Server Status Banner ─────────────────────────────────────────────────────

class _ServerStatusCard extends StatefulWidget {
  @override
  State<_ServerStatusCard> createState() => _ServerStatusCardState();
}

class _ServerStatusCardState extends State<_ServerStatusCard> {
  String _status = 'Not tested';
  bool _testing = false;
  Color _color = Colors.grey;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            Icon(Icons.cloud, color: _color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Token Server',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      TwilioTokenService.instance.currentBaseUrl,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 12, color: Colors.grey),
                    ),
                  ]),
            ),
            TextButton(
              onPressed: _testing ? null : _pingServer,
              child: _testing
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Ping'),
            ),
          ]),
          if (_status != 'Not tested') ...[
            const SizedBox(height: 8),
            Row(children: [
              Icon(
                _color == Colors.green ? Icons.check_circle : Icons.cancel,
                color: _color,
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(_status, style: TextStyle(color: _color, fontSize: 12)),
              ),
            ]),
          ],
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.settings, size: 14),
              label: const Text('Change server URL', style: TextStyle(fontSize: 12)),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
                setState(() {});
              },
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _pingServer() async {
    setState(() { _testing = true; _status = 'Testing…'; _color = Colors.grey; });
    final result = await TwilioTokenService.instance.fetchVideoToken(roomName: 'ping-test');
    if (!mounted) return;
    setState(() {
      _testing = false;
      switch (result) {
        case TokenSuccess():
          _status = '✓ Server reachable — token received';
          _color = Colors.green;
        case TokenFailure(:final message):
          _status = message.split('\n').first;
          _color = Colors.red;
      }
    });
  }
}

// ─── Feature Tile ─────────────────────────────────────────────────────────────

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ]),
            ),
            const Icon(Icons.chevron_right),
          ]),
        ),
      ),
    );
  }
}

// ─── Theme Switcher ───────────────────────────────────────────────────────────

class _ThemeSwitcher extends StatefulWidget {
  @override
  State<_ThemeSwitcher> createState() => _ThemeSwitcherState();
}

class _ThemeSwitcherState extends State<_ThemeSwitcher> {
  bool _isDark = true;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SwitchListTile(
        title: const Text('Dark Mode'),
        subtitle: const Text('SDK UI theme — affects video/voice screens'),
        value: _isDark,
        onChanged: (val) => setState(() => _isDark = val),
      ),
    );
  }
}

// ─── Quick Help ───────────────────────────────────────────────────────────────

class _QuickHelp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Quick Setup Guide',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          ...[
            '1. Edit lib/config/twilio_app_config.dart with your Twilio SIDs.',
            '2. Run: flutterfire configure (for push notification support)',
            '3. Deploy token server: cd docs/token_server && npm start',
            '4. Tap ⚙ Settings → set server URL.',
            '5. Tap "Ping" to verify. Green = ready.',
            '6. For voice calls: see the Voice screen help section.',
          ].map((s) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(s, style: const TextStyle(fontSize: 13)),
              )).toList(),
        ]),
      ),
    );
  }
}
