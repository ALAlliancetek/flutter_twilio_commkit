/// Available audio output routes.
enum AudioRoute { earpiece, speaker, bluetooth, headset }

extension AudioRouteX on AudioRoute {
  static AudioRoute fromString(String value) {
    return switch (value) {
      'speaker' => AudioRoute.speaker,
      'bluetooth' => AudioRoute.bluetooth,
      'headset' => AudioRoute.headset,
      _ => AudioRoute.earpiece,
    };
  }
}

