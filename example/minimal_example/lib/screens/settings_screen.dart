import 'package:flutter/material.dart';
import 'package:flutter_twilio_commkit/flutter_twilio_commkit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/twilio_token_service.dart';

const _keyServerUrl   = 'token_server_url';
const _keyIdentity    = 'user_identity';
const _keyRoomName    = 'room_name';
const _keyCallTo      = 'call_to';
const _keyAvatarImage = 'avatar_image_url';

/// Persists and loads test settings using SharedPreferences.
class AppSettings {
  static late SharedPreferences _prefs;

  static Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    TwilioTokenService.instance
        .setBaseUrl(_prefs.getString(_keyServerUrl) ??
            TwilioTokenService.instance.currentBaseUrl);
    TwilioTokenService.instance
        .setIdentity(_prefs.getString(_keyIdentity) ??
            TwilioTokenService.instance.currentIdentity);
    // Restore avatar image URL
    final imageUrl = _prefs.getString(_keyAvatarImage);
    TwilioUserPreferences.instance.avatarImageUrl = imageUrl;
  }

  static String get serverUrl =>
      _prefs.getString(_keyServerUrl) ??
      TwilioTokenService.instance.currentBaseUrl;

  static String get identity =>
      _prefs.getString(_keyIdentity) ??
      TwilioTokenService.instance.currentIdentity;

  static String get roomName =>
      _prefs.getString(_keyRoomName) ?? 'test-room-001';

  static String get callTo =>
      _prefs.getString(_keyCallTo) ?? 'flutter-tester-2';

  static Future<void> save({
    required String serverUrl,
    required String identity,
    required String roomName,
    required String callTo,
    String? avatarImageUrl,
  }) async {
    await Future.wait([
      _prefs.setString(_keyServerUrl, serverUrl),
      _prefs.setString(_keyIdentity,  identity),
      _prefs.setString(_keyRoomName,  roomName),
      _prefs.setString(_keyCallTo,    callTo),
      if (avatarImageUrl != null && avatarImageUrl.isNotEmpty)
        _prefs.setString(_keyAvatarImage, avatarImageUrl)
      else
        _prefs.remove(_keyAvatarImage),
    ]);
    TwilioTokenService.instance.setBaseUrl(serverUrl);
    TwilioTokenService.instance.setIdentity(identity);
    TwilioUserPreferences.instance
      ..avatarImageUrl = avatarImageUrl?.isNotEmpty == true ? avatarImageUrl : null;
  }
}

/// Settings screen — configure token server, identity, avatar photo URL, and test values.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _serverUrlCtrl;
  late final TextEditingController _identityCtrl;
  late final TextEditingController _roomCtrl;
  late final TextEditingController _callToCtrl;
  late final TextEditingController _avatarImageCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _serverUrlCtrl   = TextEditingController(text: AppSettings.serverUrl);
    _identityCtrl    = TextEditingController(text: AppSettings.identity);
    _roomCtrl        = TextEditingController(text: AppSettings.roomName);
    _callToCtrl      = TextEditingController(text: AppSettings.callTo);
    _avatarImageCtrl = TextEditingController(
        text: TwilioUserPreferences.instance.avatarImageUrl ?? '');
  }

  @override
  void dispose() {
    _serverUrlCtrl.dispose();
    _identityCtrl.dispose();
    _roomCtrl.dispose();
    _callToCtrl.dispose();
    _avatarImageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save',
            onPressed: _save,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Avatar photo ──────────────────────────────────────────────
            _SectionHeader('Profile Picture'),
            const SizedBox(height: 8),
            _AvatarPreview(
              imageUrl: _avatarImageCtrl.text.trim(),
              identity: _identityCtrl.text.trim(),
            ),
            const SizedBox(height: 14),
            _Field(
              controller: _avatarImageCtrl,
              label: 'Profile Picture URL (optional)',
              hint: 'https://example.com/photo.png',
              helper: 'Leave blank to use the auto-generated avatar from your identity.',
              onChanged: (_) => setState(() {}),
            ),
            const Divider(height: 32),

            // ── Connection ────────────────────────────────────────────────
            _SectionHeader('Token Server'),
            _Field(
              controller: _serverUrlCtrl,
              label: 'Token Server URL',
              hint: 'http://10.0.2.2:3000',
              helper: 'Android emulator → 10.0.2.2   iOS simulator → localhost',
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 4),
            _tokenServerHelpCard(),
            const SizedBox(height: 20),

            _SectionHeader('Identity'),
            _Field(
              controller: _identityCtrl,
              label: 'User Identity',
              hint: 'flutter-tester-1',
              helper: 'Used as the participant name in video/voice.',
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),

            _SectionHeader('Video'),
            _Field(
              controller: _roomCtrl,
              label: 'Room Name',
              hint: 'test-room-001',
              helper: 'Video room to join.',
            ),
            const SizedBox(height: 20),

            _SectionHeader('Voice'),
            _Field(
              controller: _callToCtrl,
              label: 'Call To (identity or E.164)',
              hint: 'flutter-tester-2',
              helper: 'Twilio client identity or E.164 phone number to call.',
            ),
            const SizedBox(height: 8),
            _voiceHelpCard(),
            const SizedBox(height: 32),

            ElevatedButton.icon(
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: const Text('Save Settings'),
              onPressed: _saving ? null : _save,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.network_ping),
              label: const Text('Test Server Connection'),
              onPressed: _testConnection,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _voiceHelpCard() {
    return Card(
      color: Colors.blue.shade900.withValues(alpha: 0.2),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.info_outline, size: 16, color: Colors.blue),
            SizedBox(width: 6),
            Text('How to test Voice between 2 devices',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ]),
          const SizedBox(height: 8),
          const Text(
            '1. Device A: identity = "flutter-tester-1", Call To = "flutter-tester-2"\n'
            '2. Device B: identity = "flutter-tester-2", Call To = "flutter-tester-1"\n'
            '3. Both tap "Initialize Voice SDK"\n'
            '4. Device A taps Call → Device B sees incoming call\n'
            '5. Device B accepts\n\n'
            'Requires TwiML App SID in server .env',
            style: TextStyle(fontSize: 12, height: 1.5),
          ),
        ]),
      ),
    );
  }

  Widget _tokenServerHelpCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Expected server endpoint:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          const Text(
            'GET <url>/token?type=video&room=<room>&identity=<id>\n'
            '→ { "token": "<jwt>" }',
            style: TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          const SizedBox(height: 8),
          const Text('See docs/token_server/server.js for a ready-to-run '
              'Node.js example.',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await AppSettings.save(
      serverUrl:      _serverUrlCtrl.text.trim(),
      identity:       _identityCtrl.text.trim(),
      roomName:       _roomCtrl.text.trim(),
      callTo:         _callToCtrl.text.trim(),
      avatarImageUrl: _avatarImageCtrl.text.trim(),
    );
    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved ✓'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _testConnection() async {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Testing…')));
    final result = await TwilioTokenService.instance.fetchVideoToken(
      roomName: _roomCtrl.text.trim().isNotEmpty
          ? _roomCtrl.text.trim()
          : 'test-room',
      identity: _identityCtrl.text.trim(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    switch (result) {
      case TokenSuccess(:final token):
        final preview =
            token.length > 40 ? '${token.substring(0, 40)}…' : token;
        _showDialog('✅ Connected!',
            'Token received successfully.\n\nPreview:\n$preview');
      case TokenFailure(:final message):
        _showDialog('❌ Connection Failed', message);
    }
  }

  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(message)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK')),
        ],
      ),
    );
  }
}

// ─── Avatar Preview ───────────────────────────────────────────────────────────

class _AvatarPreview extends StatelessWidget {
  const _AvatarPreview({required this.imageUrl, required this.identity});
  final String imageUrl;
  final String identity;

  @override
  Widget build(BuildContext context) {
    const double r = 52;
    // Always resolve a URL — custom if provided, otherwise pravatar default
    final resolvedUrl = imageUrl.isNotEmpty
        ? imageUrl
        : 'https://i.pravatar.cc/150?u=${Uri.encodeComponent(identity.isNotEmpty ? identity : 'user')}';
    final isCustom = imageUrl.isNotEmpty;

    return Center(
      child: Column(
        children: [
          Container(
            width: r * 2,
            height: r * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade300,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.network(
                resolvedUrl,
                width: r * 2,
                height: r * 2,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : Container(
                        color: Colors.grey.shade200,
                        alignment: Alignment.center,
                        child: CircularProgressIndicator(
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded /
                                  progress.expectedTotalBytes!
                              : null,
                          strokeWidth: 2,
                        ),
                      ),
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image,
                  size: 44,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isCustom ? 'Custom photo' : 'Auto-generated from identity',
            style: TextStyle(
              fontSize: 12,
              color: isCustom
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey[600],
              fontWeight:
                  isCustom ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          if (!isCustom)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                resolvedUrl,
                style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title,
          style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
              fontSize: 14)),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.helper,
    this.validator,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final String? helper;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        helperMaxLines: 2,
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}
