/// Per-feature configuration for Twilio Video.
class TwilioVideoConfig {
  const TwilioVideoConfig({
    this.roomType = TwilioRoomType.group,
    this.defaultEnableVideo = true,
    this.defaultEnableAudio = true,
    this.enableNetworkQuality = true,
    this.enableDominantSpeaker = true,
    this.preferredVideoCodec = TwilioVideoCodec.vp8,
    this.maxVideoBitrate,
    this.maxAudioBitrate,
    this.maxParticipants,
  });

  /// Room type: peer-to-peer, go, group (default), or group-small.
  final TwilioRoomType roomType;

  /// Whether video is enabled by default when joining a room.
  final bool defaultEnableVideo;

  /// Whether audio is enabled by default when joining a room.
  final bool defaultEnableAudio;

  /// Whether to enable network quality monitoring.
  final bool enableNetworkQuality;

  /// Whether to enable dominant speaker detection.
  final bool enableDominantSpeaker;

  /// Preferred video codec.
  final TwilioVideoCodec preferredVideoCodec;

  /// Maximum video bitrate in bits per second. `null` = SDK default.
  final int? maxVideoBitrate;

  /// Maximum audio bitrate in bits per second. `null` = SDK default.
  final int? maxAudioBitrate;

  /// Maximum number of **total** participants allowed in a room (including
  /// the local user). When this limit is reached:
  ///
  /// - [TwilioVideo.joinRoom] will throw a [TwilioCallException] with code
  ///   `ROOM_FULL` if the room already has `maxParticipants - 1` remote
  ///   participants (i.e. joining would exceed the cap).
  /// - The built-in [TwilioVideoCallScreen] shows a "Room is full" error.
  /// - New remote participants who join after the cap is reached are silently
  ///   ignored in the UI grid but still connected at the Twilio level (the
  ///   Twilio server enforces the hard cap for `groupSmall` rooms; for `group`
  ///   rooms the client-side cap is advisory).
  ///
  /// Hard limits per room type (server-enforced):
  /// - `peerToPeer` → 10
  /// - `go`         → 2
  /// - `group`      → 50
  /// - `groupSmall` → 4
  ///
  /// `null` = no client-side limit (server limit still applies).
  final int? maxParticipants;

  Map<String, dynamic> toMap() => {
        'roomType': roomType.name,
        'defaultEnableVideo': defaultEnableVideo,
        'defaultEnableAudio': defaultEnableAudio,
        'enableNetworkQuality': enableNetworkQuality,
        'enableDominantSpeaker': enableDominantSpeaker,
        'preferredVideoCodec': preferredVideoCodec.name,
        if (maxVideoBitrate != null) 'maxVideoBitrate': maxVideoBitrate,
        if (maxAudioBitrate != null) 'maxAudioBitrate': maxAudioBitrate,
        if (maxParticipants != null) 'maxParticipants': maxParticipants,
      };
}

/// Twilio Video room types.
enum TwilioRoomType {
  /// Peer-to-peer (no media server, up to 10 participants).
  peerToPeer,

  /// Go rooms (free tier, up to 2 participants).
  go,

  /// Group rooms (media server, up to 50 participants).
  group,

  /// Group-small rooms (media server, up to 4 participants, lower cost).
  groupSmall,
}

/// Supported video codecs.
enum TwilioVideoCodec { vp8, h264, vp9 }

