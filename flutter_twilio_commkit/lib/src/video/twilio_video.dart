import 'dart:async';

import 'package:flutter_twilio_commkit_platform_interface/flutter_twilio_commkit_platform_interface.dart';

import '../models/participant.dart';

import '../models/network_quality.dart';
import '../utils/twilio_logger.dart';
import '../exceptions/twilio_exceptions.dart';
import '../events/video_events.dart';
import 'video_room.dart';

export '../events/video_events.dart';

/// High-level API for Twilio Video.
///
/// Usage:
/// ```dart
/// final room = await TwilioVideo.instance.joinRoom(
///   accessToken: token,
///   roomName: 'my-room',
/// );
/// ```
class TwilioVideo {
  TwilioVideo._();

  static final TwilioVideo _instance = TwilioVideo._();

  /// Singleton instance.
  static TwilioVideo get instance => _instance;

  VideoRoom? _currentRoom;
  int? _maxParticipants; // set from TwilioCommKit config

  /// Applies video config values that affect runtime behaviour.
  /// Called internally by [TwilioCommKit.initialize].
  void applyConfig({int? maxParticipants}) {
    _maxParticipants = maxParticipants;
  }

  /// The client-side participant cap, or null if not set.
  int? get maxParticipants => _maxParticipants;

  final _videoEventController = StreamController<VideoRoomEvent>.broadcast();
  StreamSubscription<VideoEvent>? _platformSubscription;

  /// Stream of strongly-typed video room events.
  Stream<VideoRoomEvent> get onRoomEvent => _videoEventController.stream;

  /// Stream of participant connection events.
  Stream<ParticipantConnectedRoomEvent> get onParticipantConnected =>
      onRoomEvent
          .where((e) => e is ParticipantConnectedRoomEvent)
          .cast<ParticipantConnectedRoomEvent>();

  /// Stream of network quality events.
  Stream<NetworkQualityRoomEvent> get onNetworkQualityChanged =>
      onRoomEvent
          .where((e) => e is NetworkQualityRoomEvent)
          .cast<NetworkQualityRoomEvent>();

  /// Fired when a remote participant mutes or unmutes their audio track.
  Stream<ParticipantAudioChangedRoomEvent> get onParticipantAudioChanged =>
      onRoomEvent
          .where((e) => e is ParticipantAudioChangedRoomEvent)
          .cast<ParticipantAudioChangedRoomEvent>();

  /// Fired when a remote participant enables or disables their video track.
  Stream<ParticipantVideoChangedRoomEvent> get onParticipantVideoChanged =>
      onRoomEvent
          .where((e) => e is ParticipantVideoChangedRoomEvent)
          .cast<ParticipantVideoChangedRoomEvent>();

  /// The currently active room, or null.
  VideoRoom? get currentRoom => _currentRoom;

  /// Joins a Twilio Video room.
  ///
  /// Throws [TwilioCallException] with code `ROOM_FULL` if [maxParticipants]
  /// is set and the room already has reached the cap.
  /// Throws [TwilioAuthException] on invalid token.
  /// Throws [TwilioNetworkException] on connectivity issues.
  Future<VideoRoom> joinRoom({
    required String accessToken,
    required String roomName,
    bool enableVideo = true,
    bool enableAudio = true,
  }) async {
    TwilioLogger.debug('Joining room: $roomName');

    // Client-side participant cap check: try to fetch current participant count
    // BEFORE connecting. This is advisory — the Twilio server enforces hard
    // limits for groupSmall rooms independently.
    if (_maxParticipants != null) {
      try {
        // We need to connect to get the count, so we do a lightweight check:
        // the platform will return the room state on connect. We guard after
        // connect inside the returned room model instead.
        TwilioLogger.debug(
            'maxParticipants=$_maxParticipants — will enforce after connect');
      } catch (_) {}
    }

    try {
      final model = await TwilioCommKitPlatform.instance.connectToRoom(
        accessToken: accessToken,
        roomName: roomName,
        enableVideo: enableVideo,
        enableAudio: enableAudio,
      );
      _currentRoom = VideoRoom.fromModel(model);

      // Post-connect cap check
      if (_maxParticipants != null) {
        try {
          final existing = await TwilioCommKitPlatform.instance
              .getParticipants(roomSid: model.sid);
          final total = existing.length + 1;
          if (total > _maxParticipants!) {
            TwilioLogger.warning(
                'Room full: $total participants > cap $_maxParticipants — disconnecting');
            await TwilioCommKitPlatform.instance
                .disconnectFromRoom(roomSid: model.sid);
            _currentRoom = null;
            throw TwilioCallException(
              'Room is full. Maximum $_maxParticipants participants allowed.',
              errorCode: 'ROOM_FULL',
            );
          }
        } on TwilioCallException {
          rethrow;
        } catch (_) {
          // Non-fatal: cap check failed, allow join
        }
      }

      // Always ensure we have an active subscription after joining.
      // resetSubscription() already called one in initState, but we
      // re-confirm here in case joinRoom is called without it.
      if (_platformSubscription == null) {
        _subscribeToPlatformEvents();
      }
      TwilioLogger.debug('Joined room: ${model.sid}');
      return _currentRoom!;
    } on TwilioCallException {
      rethrow;
    } on Exception catch (e) {
      TwilioLogger.error('Failed to join room', e);
      throw TwilioCallException('Failed to join room: $e');
    }
  }

  /// Resets the platform event subscription and clears any stale room state.
  /// Called by [TwilioVideoCallScreen] on [initState] to ensure a clean slate
  /// before each new joinRoom attempt — even on a rejoin after leaving.
  void resetSubscription() {
    _platformSubscription?.cancel();
    _platformSubscription = null;
    // Clear stale room reference so joinRoom always starts fresh.
    _currentRoom = null;
    _subscribeToPlatformEvents();
    TwilioLogger.debug('TwilioVideo: platform subscription reset');
  }

  /// Disconnects from the current room.
  Future<void> disconnect() async {
    final room = _currentRoom;
    _currentRoom = null;
    // Cancel platform subscription so next joinRoom gets a fresh one.
    _platformSubscription?.cancel();
    _platformSubscription = null;
    if (room == null) {
      // No tracked room, but tell the native side to disconnect anyway
      // in case it has a stale room (e.g. after a failed cap check).
      try {
        await TwilioCommKitPlatform.instance
            .disconnectFromRoom(roomSid: '');
      } catch (_) {}
      return;
    }
    try {
      await TwilioCommKitPlatform.instance
          .disconnectFromRoom(roomSid: room.sid);
    } catch (_) {}
    TwilioLogger.debug('Disconnected from room: ${room.sid}');
  }

  /// Mutes/unmutes local video track.
  Future<void> muteVideo({required bool muted}) async {
    await TwilioCommKitPlatform.instance.muteVideo(muted: muted);
  }

  /// Mutes/unmutes local audio track.
  Future<void> muteAudio({required bool muted}) async {
    await TwilioCommKitPlatform.instance.muteAudio(muted: muted);
  }

  /// Switches between front and back camera.
  Future<void> switchCamera() async {
    await TwilioCommKitPlatform.instance.switchCamera();
  }

  /// Enables or disables the speakerphone for an active video call.
  /// On Android this routes audio via AudioSwitch; on iOS it overrides the
  /// AVAudioSession output port.
  Future<void> setSpeaker({required bool enabled}) async {
    await TwilioCommKitPlatform.instance.setSpeakerForVideo(enabled: enabled);
  }

  /// Fetches current participants in [roomSid].
  Future<List<Participant>> getParticipants({required String roomSid}) async {
    final models =
        await TwilioCommKitPlatform.instance.getParticipants(roomSid: roomSid);
    return models
        .map((m) => Participant(
              sid: m.sid,
              identity: m.identity,
              isVideoEnabled: m.isVideoEnabled,
              isAudioEnabled: m.isAudioEnabled,
              networkQualityLevel: m.networkQualityLevel,
              isDominantSpeaker: m.isDominantSpeaker,
            ))
        .toList();
  }

  void _subscribeToPlatformEvents() {
    _platformSubscription?.cancel();
    _platformSubscription =
        TwilioCommKitPlatform.instance.onVideoEvent.listen(
      (event) {
        final mapped = _mapEvent(event);
        if (mapped != null) _videoEventController.add(mapped);
      },
      onError: (Object e) => TwilioLogger.error('Video event error', e),
    );
  }

  VideoRoomEvent? _mapEvent(VideoEvent event) {
    return switch (event) {
      RoomConnectedEvent e => RoomConnectedRoomEvent(
          roomSid: e.roomSid, roomName: e.roomName),
      RoomDisconnectedEvent e =>
        RoomDisconnectedRoomEvent(roomSid: e.roomSid, reason: e.reason),
      RoomReconnectingEvent e =>
        RoomReconnectingRoomEvent(roomSid: e.roomSid),
      RoomReconnectedEvent e => RoomReconnectedRoomEvent(roomSid: e.roomSid),
      ParticipantConnectedEvent e => ParticipantConnectedRoomEvent(
          participant: Participant(
            sid: e.participant.sid,
            identity: e.participant.identity,
            isVideoEnabled: e.participant.isVideoEnabled,
            isAudioEnabled: e.participant.isAudioEnabled,
          ),
        ),
      ParticipantDisconnectedEvent e =>
        ParticipantDisconnectedRoomEvent(participantSid: e.participantSid),
      ParticipantAudioChangedEvent e => ParticipantAudioChangedRoomEvent(
          participantSid: e.participantSid,
          isAudioEnabled: e.isAudioEnabled,
        ),
      ParticipantVideoChangedEvent e => ParticipantVideoChangedRoomEvent(
          participantSid: e.participantSid,
          isVideoEnabled: e.isVideoEnabled,
        ),
      DominantSpeakerChangedEvent e =>
        DominantSpeakerChangedRoomEvent(participantSid: e.participantSid),
      NetworkQualityChangedEvent e => NetworkQualityRoomEvent(
          quality: NetworkQuality(
            level: e.quality.level,
            participantSid: e.quality.participantSid,
          ),
        ),
      VideoErrorEvent e =>
        VideoErrorRoomEvent(message: e.message, code: e.code),
      _ => null,
    };
  }

  /// Releases all resources. Called automatically by [TwilioCommKit.dispose].
  void dispose() {
    _platformSubscription?.cancel();
    _videoEventController.close();
  }
}

