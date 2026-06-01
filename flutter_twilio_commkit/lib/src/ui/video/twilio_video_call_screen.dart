import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/participant.dart';
import '../../core/twilio_user_preferences.dart';
import '../../theme/twilio_theme.dart';
import '../../theme/twilio_theme_data.dart';
import '../../video/twilio_video.dart';
import '../../utils/twilio_logger.dart';
import '../../exceptions/twilio_exceptions.dart';
import '../widgets/twilio_call_controls.dart';
import '../widgets/twilio_avatar.dart';
import 'twilio_participant_tile.dart';
import 'twilio_video_preview.dart';

/// Built-in full-screen video call UI.
///
/// **Layout behaviour** (mirrors WhatsApp / Microsoft Teams):
/// - 0 remote participants → waiting screen + local preview full-screen
/// - 1 remote participant  → their video fills the screen; local is a small
///                           draggable tile in the corner
/// - 2 remote participants → equal vertical split (50 / 50)
/// - 3 remote participants → 1 large tile on top, 2 equal tiles below
/// - 4+ remote participants → responsive 2-column grid; local stays as a
///                            floating draggable tile
///
/// All layouts keep the local preview as a draggable pip (picture-in-picture)
/// that the user can move to any corner.
class TwilioVideoCallScreen extends ConsumerStatefulWidget {
  const TwilioVideoCallScreen({
    super.key,
    required this.roomName,
    required this.accessToken,
    this.localIdentity = '',
    this.theme,
    this.onRoomConnected,
    this.onRoomDisconnected,
    this.controlsBuilder,
    this.participantBuilder,
    this.enableVideo = true,
    this.enableAudio = true,
    this.resolveParticipantImage,
  });

  final String roomName;
  final String accessToken;

  /// The local user's identity string — used to load their avatar image
  /// in the participant list "You" row.
  final String localIdentity;
  final TwilioThemeData? theme;
  final VoidCallback? onRoomConnected;
  final void Function(String? reason)? onRoomDisconnected;

  /// Override the default controls bar. Receives current mute/video state.
  final Widget Function(BuildContext context, _VideoCallState state)?
      controlsBuilder;

  /// Override individual participant tiles.
  final Widget Function(BuildContext context, Participant participant)?
      participantBuilder;

  final bool enableVideo;
  final bool enableAudio;

  /// Optional callback that returns a custom image URL for a given identity.
  /// When provided, the URL is used for that participant's avatar in tiles
  /// and the participant list. Return `null` to fall back to the default.
  final String? Function(String identity)? resolveParticipantImage;

  @override
  ConsumerState<TwilioVideoCallScreen> createState() =>
      _TwilioVideoCallScreenState();
}

class _VideoCallState {
  const _VideoCallState({
    this.isAudioMuted = false,
    this.isVideoMuted = false,
    this.participants = const [],
  });
  final bool isAudioMuted;
  final bool isVideoMuted;
  final List<Participant> participants;
}

class _TwilioVideoCallScreenState
    extends ConsumerState<TwilioVideoCallScreen> {
  bool _isAudioMuted = false;
  bool _isVideoMuted = false;
  final List<Participant> _participants = [];
  String? _connectError;
  bool _isRoomFull = false;
  bool _isConnecting = true;
  bool _controlsVisible = true;
  Timer? _controlsHideTimer;

  // Tracks whether we ever successfully connected — prevents
  // RoomDisconnectedRoomEvent from firing onRoomDisconnected during the
  // initial connecting phase (e.g. on a failed token or network error).
  bool _hasConnectedOnce = false;
  // Prevents double-disconnect when _hangUp and dispose() race.
  bool _disconnectCalled = false;

  // Call duration timer (starts when first participant joins or room connected)
  DateTime? _callStartedAt;
  Timer? _durationTimer;
  Duration _callDuration = Duration.zero;

  // Pip (local preview) drag position — offset from top-left of screen
  Offset? _pipOffset;
  double _pipW = 100;
  double _pipH = 140;

  StreamSubscription<VideoRoomEvent>? _eventSubscription;

  @override
  void initState() {
    super.initState();
    TwilioVideo.instance.resetSubscription();
    _subscribeToEvents();
    _connectAndRefresh();
    _scheduleHideControls();
  }


  /// Single place that does the actual disconnect — idempotent.
  /// Returns a Future so callers that CAN await (like _hangUp) do so,
  /// while dispose() calls it fire-and-forget (cannot await).
  Future<void> _doDisconnect() async {
    if (_disconnectCalled) return;
    _disconnectCalled = true;
    await TwilioVideo.instance.disconnect();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _controlsHideTimer?.cancel();
    _durationTimer?.cancel();
    // Always release camera + mic when the screen is destroyed — covers
    // back-gesture, system back button, or any navigation bypassing _hangUp.
    // Fire-and-forget because dispose() cannot be async.
    if (!_disconnectCalled) {
      _disconnectCalled = true;
      TwilioVideo.instance.disconnect();
    }
    super.dispose();
  }

  void _startDurationTimer() {
    if (_callStartedAt != null) return;
    _callStartedAt = DateTime.now();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _callDuration = DateTime.now().difference(_callStartedAt!);
        });
      }
    });
  }

  String get _durationLabel {
    final h = _callDuration.inHours;
    final m = (_callDuration.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_callDuration.inSeconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  // ── Controls auto-hide ────────────────────────────────────────────────────

  void _scheduleHideControls() {
    _controlsHideTimer?.cancel();
    // Don't auto-hide when the local user is alone — controls must always
    // be reachable so they can hang up or toggle camera/mic.
    if (_participants.isEmpty) return;
    _controlsHideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _participants.isNotEmpty) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _onTapScreen() {
    setState(() => _controlsVisible = true);
    _scheduleHideControls();
  }

  // ── Events ────────────────────────────────────────────────────────────────

  void _subscribeToEvents() {
    _eventSubscription?.cancel();
    _eventSubscription = TwilioVideo.instance.onRoomEvent.listen((event) {
      if (!mounted) return;
      switch (event) {
        case ParticipantConnectedRoomEvent(:final participant):
          setState(() {
            if (!_participants.any((p) => p.sid == participant.sid)) {
              final cap = TwilioVideo.instance.maxParticipants;
              if (cap != null && _participants.length + 1 >= cap) {
                TwilioLogger.warning(
                    'Participant ${participant.identity} joined but cap $cap reached — hidden from grid');
                return;
              }
              _participants.add(participant);
            }
          });
          _startDurationTimer();
          // Show controls when someone joins
          setState(() => _controlsVisible = true);
          _scheduleHideControls();
        case ParticipantDisconnectedRoomEvent(:final participantSid):
          setState(() {
            _participants.removeWhere((p) => p.sid == participantSid);
          });
          // If we're now alone again, always show controls and cancel timer
          if (_participants.isEmpty) {
            _controlsHideTimer?.cancel();
            setState(() => _controlsVisible = true);
          }
        case ParticipantAudioChangedRoomEvent(
            :final participantSid,
            :final isAudioEnabled
          ):
          setState(() {
            final idx = _participants.indexWhere((p) => p.sid == participantSid);
            if (idx != -1) {
              _participants[idx] = _participants[idx].copyWith(
                  isAudioEnabled: isAudioEnabled);
            }
          });
        case ParticipantVideoChangedRoomEvent(
            :final participantSid,
            :final isVideoEnabled
          ):
          setState(() {
            final idx = _participants.indexWhere((p) => p.sid == participantSid);
            if (idx != -1) {
              _participants[idx] = _participants[idx].copyWith(
                  isVideoEnabled: isVideoEnabled);
            }
          });
        case DominantSpeakerChangedRoomEvent(:final participantSid):
          setState(() {
            for (var i = 0; i < _participants.length; i++) {
              _participants[i] = _participants[i].copyWith(
                  isDominantSpeaker: _participants[i].sid == participantSid);
            }
          });
        case RoomConnectedRoomEvent():
          _hasConnectedOnce = true;
          setState(() => _isConnecting = false);
          _refreshParticipants();
        case RoomDisconnectedRoomEvent(:final reason):
          // Only surface the disconnect to the host app after we were actually
          // connected — prevents false "disconnected" during initial token error.
          if (_hasConnectedOnce && !_disconnectCalled) {
            widget.onRoomDisconnected?.call(reason);
          }
        default:
          break;
      }
    });
  }

  Future<void> _connectAndRefresh() async {
    try {
      await TwilioVideo.instance.joinRoom(
        accessToken: widget.accessToken,
        roomName: widget.roomName,
        enableVideo: widget.enableVideo,
        enableAudio: widget.enableAudio,
      );
      if (mounted) {
        setState(() => _isConnecting = false);
        widget.onRoomConnected?.call();
        _refreshParticipants();
      }
    } on TwilioCallException catch (e) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _isRoomFull = e.errorCode == 'ROOM_FULL';
          _connectError = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _connectError = e
              .toString()
              .replaceAll(
                  'TwilioCallException(code: null, message: ', '')
              .replaceAll(RegExp(r'\)$'), '');
        });
      }
    }
  }

  Future<void> _refreshParticipants() async {
    final room = TwilioVideo.instance.currentRoom;
    if (room == null || room.sid.isEmpty) return;
    try {
      final fetched =
          await TwilioVideo.instance.getParticipants(roomSid: room.sid);
      if (!mounted) return;
      setState(() {
        for (final p in fetched) {
          if (!_participants.any((e) => e.sid == p.sid)) {
            _participants.add(p);
          }
        }
      });
    } catch (_) {}
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme ?? TwilioTheme.of(context);

    if (_connectError != null) return _buildError(theme);
    if (_isConnecting) return _buildConnecting(theme);

    final size = MediaQuery.of(context).size;
    _pipW = theme.pipWidth;
    _pipH = theme.pipHeight;
    // Initial pip position: bottom-right, above controls + name strip
    final mq = MediaQuery.of(context);
    final pipDefaultBottom = mq.padding.bottom + 28.0 + 80.0 + 10.0 + 44.0 + 12.0;
    _pipOffset ??= Offset(
      size.width - _pipW - 16,
      size.height - _pipH - pipDefaultBottom,
    );

    final aloneInRoom = _participants.isEmpty;
    final showControls = aloneInRoom || _controlsVisible;

    final state = _VideoCallState(
      isAudioMuted: _isAudioMuted,
      isVideoMuted: _isVideoMuted,
      participants: _participants,
    );

    return TwilioTheme(
      data: theme,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _onTapScreen,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final mq = MediaQuery.of(context);
              final bottomPad = mq.padding.bottom;

              // Controls bar actual height:
              // icon(50) + label(14) + vertical padding(14*2) + SizedBox(6) ≈ 98
              // Add extra headroom so name strip is never clipped behind controls.
              const controlsH = 100.0;
              const controlsBottomGap = 28.0;
              const nameStripH = 44.0;   // approximate height of one strip row
              const nameStripGap = 10.0; // gap between name strip and controls

              // Name strip bottom positions
              final nameStripVisible =
                  bottomPad + controlsBottomGap + controlsH + nameStripGap;
              final nameStripHidden = bottomPad + 16.0;

              return Stack(
                fit: StackFit.expand,
                children: [
                  // ── Main video / waiting area ───────────────────────────
                  Positioned.fill(child: _buildMainLayout(theme)),

                  // ── Draggable local pip ─────────────────────────────────
                  _buildDraggablePip(theme, size),

                  // ── Top gradient scrim ──────────────────────────────────
                  Positioned(
                    top: 0, left: 0, right: 0,
                    height: mq.padding.top + 90,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.72),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── Bottom gradient scrim ───────────────────────────────
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    height: bottomPad +
                        controlsBottomGap +
                        controlsH +
                        nameStripGap +
                        nameStripH +
                        48,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.82),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── Top bar ─────────────────────────────────────────────
                  Positioned(
                    top: 0, left: 0, right: 0,
                    child: AnimatedOpacity(
                      opacity: showControls ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      child: _buildTopBar(context, theme),
                    ),
                  ),

                  // ── Name / waiting strip — centred pill, NOT full width ──
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeInOut,
                    bottom: showControls ? nameStripVisible : nameStripHidden,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: _buildNameStrip(theme, showControls),
                    ),
                  ),

                  // ── Controls bar ────────────────────────────────────────
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    bottom: showControls
                        ? bottomPad + controlsBottomGap
                        : -(controlsH + 20),
                    left: 12,
                    right: 12,
                    child: widget.controlsBuilder?.call(context, state) ??
                        TwilioCallControls(
                          isAudioMuted: _isAudioMuted,
                          isVideoMuted: _isVideoMuted,
                          onToggleAudio: _toggleAudio,
                          onToggleVideo: _toggleVideo,
                          onSwitchCamera: _switchCamera,
                          onHangUp: _hangUp,
                          onShowParticipants: _participants.isNotEmpty
                              ? () => _showParticipantList(context, theme)
                              : null,
                          participantCount: _participants.length + 1,
                        ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildNameStrip(TwilioThemeData theme, bool controlsVisible) {
    // ── Waiting state ──────────────────────────────────────────────────────
    if (_participants.isEmpty) {
      return IntrinsicWidth(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.14), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.82, end: 1.12),
                duration: const Duration(milliseconds: 1000),
                builder: (_, v, child) =>
                    Transform.scale(scale: v, child: child),
                child: const Icon(Icons.people_outline,
                    color: Colors.white70, size: 18),
              ),
              const SizedBox(width: 8),
              const Text(
                'Waiting for others to join…',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ── Participants present ───────────────────────────────────────────────
    final names = _participants.map((p) => p.identity).toList();
    final label = names.length == 1
        ? names[0]
        : names.length == 2
            ? '${names[0]} & ${names[1]}'
            : '${names[0]}, ${names[1]} +${names.length - 2}';

    final avatarCount = _participants.length.clamp(1, 3);
    final stackWidth = 26.0 + (avatarCount - 1) * 18.0 + 4.0;
    final hasDominant = _participants.any((p) => p.isDominantSpeaker);

    return IntrinsicWidth(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.14), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Stacked avatar initials
            SizedBox(
              width: stackWidth,
              height: 26,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var i = 0; i < avatarCount; i++)
                    Positioned(
                      left: i * 18.0,
                      top: 0,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _avatarColor(i),
                          border: Border.all(
                              color: Colors.black, width: 1.5),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _participants[i].identity.isNotEmpty
                              ? _participants[i].identity[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                ),
              ),
            ),
            if (!controlsVisible && _callDuration.inSeconds > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _durationLabel,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
            if (hasDominant) ...[
              const SizedBox(width: 6),
              const Icon(Icons.volume_up_rounded,
                  color: Colors.greenAccent, size: 14),
            ],
          ],
        ),
      ),
    );
  }

  /// Distinct avatar background colour per participant index.
  Color _avatarColor(int index) {
    const colors = [
      Color(0xFF1565C0), // blue
      Color(0xFF6A1B9A), // purple
      Color(0xFF00695C), // teal
      Color(0xFFAD1457), // pink
      Color(0xFF4E342E), // brown
    ];
    return colors[index % colors.length];
  }

  /// Full-width top bar: back button | room name + duration | participant badge.
  Widget _buildTopBar(BuildContext context, TwilioThemeData theme) {
    final topPad = MediaQuery.of(context).padding.top;
    final total = _participants.length + 1;
    final cap = TwilioVideo.instance.maxParticipants;
    final atCap = cap != null && total > cap;
    final hasOthers = _participants.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(
          top: topPad + 4, left: 8, right: 8, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Back / hang-up shortcut ──────────────────────────────────
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: _hangUp,
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.35),
                ),
                child: const Icon(Icons.arrow_back_ios_new,
                    color: Colors.white, size: 18),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // ── Room name + live duration ─────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.roomName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6, height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF4CAF50),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      hasOthers ? _durationLabel : 'Waiting…',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 11,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Participant count chip (tappable → sheet) ─────────────────
          GestureDetector(
            onTap: hasOthers
                ? () => _showParticipantList(context, theme)
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: atCap
                    ? Colors.orange.withValues(alpha: 0.85)
                    : Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    hasOthers ? Icons.people_alt : Icons.person_outline,
                    color: Colors.white,
                    size: 15,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    cap != null ? '$total/$cap' : '$total',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (hasOthers) ...[
                    const SizedBox(width: 3),
                    Icon(Icons.chevron_right,
                        color: Colors.white.withValues(alpha: 0.6), size: 14),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Bottom sheet listing all participants (remote + local self).
  void _showParticipantList(BuildContext context, TwilioThemeData theme) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ParticipantListSheet(
        theme: theme,
        participants: List.unmodifiable(_participants),
        roomName: widget.roomName,
        localIdentity: widget.localIdentity,
        resolveParticipantImage: widget.resolveParticipantImage,
      ),
    );
  }

  // ── Smart layout engine ───────────────────────────────────────────────────

  Widget _buildMainLayout(TwilioThemeData theme) {
    final count = _participants.length;

    if (count == 0) return _buildWaiting(theme);
    if (count == 1) return _buildSingleParticipant(theme);
    if (count == 2) return _buildTwoParticipants(theme);
    if (count == 3) return _buildThreeParticipants(theme);
    return _buildGrid(theme); // 4+
  }

  // 0 participants — full-screen self-view while waiting
  Widget _buildWaiting(TwilioThemeData theme) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Background colour (visible before camera is ready) ──────────
        ColoredBox(color: const Color(0xFF0D0D0D)),

        // ── Local camera preview ─────────────────────────────────────────
        TwilioVideoPreview(fit: BoxFit.cover),

        // ── Camera-off avatar overlay ────────────────────────────────────
        if (_isVideoMuted)
          Container(
            color: Colors.black87,
            child: Center(
              child: CircleAvatar(
                radius: 52,
                backgroundColor:
                    theme.avatarBackgroundColor ?? theme.controlBarColor,
                child: Icon(theme.avatarIcon,
                    size: 52,
                    color:
                        theme.avatarIconColor ?? theme.controlIconColor),
              ),
            ),
          ),

        // ── Centre waiting icon (subtle — text is in the bottom name strip) ──
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.88, end: 1.08),
            duration: const Duration(milliseconds: 1000),
            builder: (_, v, child) =>
                Transform.scale(scale: v, child: child),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.40),
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08), width: 1),
              ),
              child: Icon(Icons.people_outline,
                  color: Colors.white.withValues(alpha: 0.70), size: 48),
            ),
          ),
        ),

        // ── "You" self-label — bottom-left corner, just above controls ──
        Builder(builder: (ctx) {
          final bp = MediaQuery.of(ctx).padding.bottom;
          return Positioned(
            bottom: bp + 6,
            left: 16,
            child: _SelfLabel(
                isMuted: _isAudioMuted, isVideoMuted: _isVideoMuted),
          );
        }),
      ],
    );
  }

  // 1 participant — their video fills the screen; name is in the bottom strip
  Widget _buildSingleParticipant(TwilioThemeData theme) {
    final custom = widget.participantBuilder?.call(context, _participants[0]);
    if (custom != null) return custom;
    return ClipRRect(
      borderRadius: BorderRadius.zero,
      child: TwilioParticipantTile(
        participant: _participants[0],
        showNameBadge: false, // name shown in bottom strip instead
      ),
    );
  }

  // 2 participants — equal vertical split (top / bottom)
  Widget _buildTwoParticipants(TwilioThemeData theme) {
    return Column(
      children: [
        Expanded(child: _buildTile(_participants[0], theme, radius: 0)),
        SizedBox(height: 2,
            child: ColoredBox(color: theme.effectiveTileSeparatorColor)),
        Expanded(child: _buildTile(_participants[1], theme, radius: 0)),
      ],
    );
  }

  // 3 participants — 1 large top, 2 small bottom row
  Widget _buildThreeParticipants(TwilioThemeData theme) {
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: _buildTile(_participants[0], theme, radius: 0),
        ),
        SizedBox(height: 2,
            child: ColoredBox(color: theme.effectiveTileSeparatorColor)),
        Expanded(
          flex: 2,
          child: Row(
            children: [
              Expanded(
                  child: _buildTile(_participants[1], theme, radius: 0)),
              SizedBox(width: 2,
                  child: ColoredBox(color: theme.effectiveTileSeparatorColor)),
              Expanded(
                  child: _buildTile(_participants[2], theme, radius: 0)),
            ],
          ),
        ),
      ],
    );
  }

  // 4+ participants — dynamic 2-column grid
  Widget _buildGrid(TwilioThemeData theme) {
    final count = _participants.length;
    final fullRows = count ~/ 2;
    final hasOdd = count.isOdd;
    final sep = theme.effectiveTileSeparatorColor;

    return Column(
      children: [
        for (int row = 0; row < fullRows; row++) ...[
          if (row > 0)
            SizedBox(height: 2, child: ColoredBox(color: sep)),
          Expanded(
            child: Row(
              children: [
                Expanded(
                    child: _buildTile(_participants[row * 2], theme,
                        radius: 0)),
                SizedBox(width: 2, child: ColoredBox(color: sep)),
                Expanded(
                    child: _buildTile(_participants[row * 2 + 1], theme,
                        radius: 0)),
              ],
            ),
          ),
        ],
        if (hasOdd) ...[
          SizedBox(height: 2, child: ColoredBox(color: sep)),
          Expanded(
            child: _buildTile(_participants[count - 1], theme, radius: 0),
          ),
        ],
      ],
    );
  }

  // Single participant tile
  Widget _buildTile(Participant p, TwilioThemeData theme,
      {double radius = 12}) {
    final custom = widget.participantBuilder?.call(context, p);
    if (custom != null) return custom;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: TwilioParticipantTile(participant: p),
    );
  }

  // ── Draggable local pip ───────────────────────────────────────────────────

  Widget _buildDraggablePip(TwilioThemeData theme, Size screenSize) {
    if (_participants.isEmpty) return const SizedBox.shrink();

    return Positioned(
      left: _pipOffset!.dx,
      top: _pipOffset!.dy,
      width: _pipW,
      height: _pipH,
      child: GestureDetector(
        onTap: () {},
        onPanUpdate: (d) {
          setState(() {
            double dx = (_pipOffset!.dx + d.delta.dx)
                .clamp(0.0, screenSize.width - _pipW);
            double dy = (_pipOffset!.dy + d.delta.dy)
                .clamp(0.0, screenSize.height - _pipH);
            _pipOffset = Offset(dx, dy);
          });
        },
        onPanEnd: (_) {
          final cx = screenSize.width / 2;
          final cy = screenSize.height / 2;
          const pad = 16.0;
          final mq = MediaQuery.of(context);
          // Bottom snap: keep above controls bar + name strip
          final bottomSnap = mq.padding.bottom + 28.0 + 80.0 + 10.0 + 44.0 + 12.0;
          final snapX = _pipOffset!.dx < cx
              ? pad
              : screenSize.width - _pipW - pad;
          final snapY = _pipOffset!.dy < cy
              ? mq.padding.top + 60
              : screenSize.height - _pipH - bottomSnap;
          setState(() => _pipOffset = Offset(snapX, snapY));
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(theme.pipBorderRadius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Camera feed
              TwilioVideoPreview(fit: BoxFit.cover),

              // Camera-off overlay
              if (_isVideoMuted)
                Container(
                  color: Colors.black87,
                  child: Center(
                    child: Icon(Icons.videocam_off,
                        color: Colors.white54, size: 24),
                  ),
                ),

              // Bottom gradient + "You" label
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(6, 12, 6, 5),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.65),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      if (_isAudioMuted)
                        const Icon(Icons.mic_off,
                            color: Colors.redAccent, size: 11),
                      if (_isAudioMuted) const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          'You',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Theme border
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(theme.pipBorderRadius),
                    border: Border.all(
                        color: theme.effectivePipBorderColor,
                        width: theme.pipBorderWidth),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Error / connecting screens ────────────────────────────────────────────

  Widget _buildError(TwilioThemeData theme) {
    final isRoomFull = _isRoomFull;
    return TwilioTheme(
      data: theme,
      child: Scaffold(
        backgroundColor: theme.backgroundColor,
        appBar: AppBar(
          backgroundColor: theme.backgroundColor,
          foregroundColor: theme.participantNameColor,
          title: const Text('Video Call'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isRoomFull ? Icons.group_off : Icons.error_outline,
                  color: isRoomFull ? Colors.orange : Colors.red,
                  size: 56,
                ),
                const SizedBox(height: 16),
                Text(
                  isRoomFull ? 'Room is Full' : 'Failed to join room',
                  style: TextStyle(
                    color: isRoomFull ? Colors.orange : Colors.red,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                if (isRoomFull) ...[
                  Text(
                    _connectError ?? '',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.participantNameColor.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The room has reached its maximum participant limit.\nPlease try again later.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.participantNameColor.withValues(alpha: 0.55),
                      fontSize: 13,
                    ),
                  ),
                ] else
                  Text(
                    _connectError ?? '',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.participantNameColor.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Go Back'),
                  style: isRoomFull
                      ? ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        )
                      : null,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnecting(TwilioThemeData theme) {
    return TwilioTheme(
      data: theme,
      child: Scaffold(
        backgroundColor: theme.backgroundColor,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Connecting to "${widget.roomName}"…',
                style: TextStyle(color: theme.participantNameColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Controls ──────────────────────────────────────────────────────────────

  Future<void> _toggleAudio() async {
    _isAudioMuted = !_isAudioMuted;
    await TwilioVideo.instance.muteAudio(muted: _isAudioMuted);
    if (mounted) setState(() {});
  }

  Future<void> _toggleVideo() async {
    _isVideoMuted = !_isVideoMuted;
    await TwilioVideo.instance.muteVideo(muted: _isVideoMuted);
    if (mounted) setState(() {});
  }

  Future<void> _switchCamera() async {
    await TwilioVideo.instance.switchCamera();
  }

  Future<void> _hangUp() async {
    _doDisconnect();
    if (mounted) Navigator.of(context).pop();
  }
}

// ─── Self "You" label ─────────────────────────────────────────────────────────

class _SelfLabel extends StatelessWidget {
  const _SelfLabel({required this.isMuted, required this.isVideoMuted});
  final bool isMuted;
  final bool isVideoMuted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person, color: Colors.white70, size: 13),
          const SizedBox(width: 4),
          const Text('You',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          if (isMuted) ...[
            const SizedBox(width: 6),
            const Icon(Icons.mic_off, color: Colors.redAccent, size: 12),
          ],
          if (isVideoMuted) ...[
            const SizedBox(width: 4),
            const Icon(Icons.videocam_off, color: Colors.white38, size: 12),
          ],
        ],
      ),
    );
  }
}

// ─── Participant List Bottom Sheet ────────────────────────────────────────────

class _ParticipantListSheet extends StatelessWidget {
  const _ParticipantListSheet({
    required this.theme,
    required this.participants,
    required this.roomName,
    this.localIdentity = '',
    this.resolveParticipantImage,
  });

  final TwilioThemeData theme;
  final List<Participant> participants;
  final String roomName;
  final String localIdentity;
  final String? Function(String identity)? resolveParticipantImage;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle + header ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(Icons.people,
                        color: theme.participantNameColor
                            .withValues(alpha: 0.8),
                        size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Participants',
                      style: TextStyle(
                        color: theme.participantNameColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${participants.length + 1}',
                        style: TextStyle(
                          color: theme.participantNameColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Divider(color: Colors.white12),
              ],
            ),
          ),

          // ── List ──────────────────────────────────────────────────────
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              children: [
                // Local "You" row
                _ParticipantRow(
                  name: 'You',
                  isLocal: true,
                  localIdentity: localIdentity,
                  imageUrl: TwilioUserPreferences.instance.avatarImageUrl,
                  theme: theme,
                ),
                ...participants.map(
                  (p) => _ParticipantRow(
                    name: p.identity,
                    imageUrl: resolveParticipantImage?.call(p.identity),
                    isAudioEnabled: p.isAudioEnabled,
                    isVideoEnabled: p.isVideoEnabled,
                    isDominantSpeaker: p.isDominantSpeaker,
                    networkQuality: p.networkQualityLevel,
                    theme: theme,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ParticipantRow extends StatelessWidget {
  const _ParticipantRow({
    required this.name,
    required this.theme,
    this.isLocal = false,
    this.localIdentity = '',
    this.imageUrl,
    this.isAudioEnabled = true,
    this.isVideoEnabled = true,
    this.isDominantSpeaker = false,
    this.networkQuality = 0,
  });

  final String name;
  final TwilioThemeData theme;
  final bool isLocal;
  final String localIdentity;
  final String? imageUrl;
  final bool isAudioEnabled;
  final bool isVideoEnabled;
  final bool isDominantSpeaker;
  final int networkQuality;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Avatar — local and remote both use TwilioAvatar.build
          if (isLocal)
            TwilioAvatar.build(
              identity: localIdentity,
              size: 40,
              imageUrl: imageUrl,
            )
          else
            Stack(
              alignment: Alignment.center,
              children: [
                TwilioAvatar.build(
                  identity: name,
                  size: 40,
                  imageUrl: imageUrl,
                ),
                if (isDominantSpeaker)
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.effectiveDominantSpeakerColor,
                        width: 2.5,
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(width: 12),

          // Name + speaking indicator
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    isLocal ? '$name (You)' : name,
                    style: TextStyle(
                      color: theme.participantNameColor,
                      fontSize: 14,
                      fontWeight: isDominantSpeaker
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isDominantSpeaker) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.volume_up,
                      color: theme.effectiveDominantSpeakerColor, size: 14),
                ],
              ],
            ),
          ),

          // Status icons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Network quality bars (remote only)
              if (!isLocal && networkQuality > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(
                      3,
                      (i) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        width: 3,
                        height: (i + 1) * 4.0,
                        decoration: BoxDecoration(
                          color: i < (networkQuality / 2).ceil()
                              ? (networkQuality >= 3
                                  ? Colors.greenAccent
                                  : Colors.orangeAccent)
                              : Colors.white24,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                  ),
                ),
              // Mic
              if (!isAudioEnabled && !isLocal)
                const Icon(Icons.mic_off,
                    color: Colors.redAccent, size: 18),
              // Camera
              if (!isVideoEnabled && !isLocal) ...[
                const SizedBox(width: 4),
                Icon(Icons.videocam_off,
                    color: Colors.white38, size: 18),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

