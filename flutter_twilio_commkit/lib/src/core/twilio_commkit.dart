import 'package:flutter_twilio_commkit_platform_interface/flutter_twilio_commkit_platform_interface.dart';

import '../config/twilio_commkit_config.dart';
import '../utils/twilio_logger.dart';
import '../video/twilio_video.dart';
import '../voice/twilio_voice.dart';

export '../config/twilio_commkit_config.dart';

/// Entry point for the Flutter Twilio CommKit SDK.
///
/// Call [TwilioCommKit.initialize] once at app startup before using
/// [TwilioVideo] or [TwilioVoice].
class TwilioCommKit {
  TwilioCommKit._();

  static bool _initialized = false;
  static TwilioCommKitConfig? _config;

  /// Returns the current SDK configuration.
  static TwilioCommKitConfig get config {
    _assertInitialized();
    return _config!;
  }

  /// Initializes the SDK with project-specific Twilio credentials.
  ///
  /// Must be called once at app startup before using [TwilioVideo] or
  /// [TwilioVoice]. Each project supplies its own [TwilioCredentials].
  ///
  /// ```dart
  /// await TwilioCommKit.initialize(
  ///   config: TwilioCommKitConfig(
  ///     credentials: TwilioCredentials(
  ///       accountSid: 'ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  ///       apiKeySid:  'SKxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  ///       outgoingApplicationSid: 'APxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  ///       pushCredentialSid:      'CRxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  ///     ),
  ///     accessTokenProvider: () async => await myServer.fetchToken(),
  ///     videoConfig: TwilioVideoConfig(roomType: TwilioRoomType.group),
  ///     voiceConfig: TwilioVoiceConfig(callerIdName: 'MyApp'),
  ///     logLevel: TwilioLogLevel.debug,
  ///   ),
  /// );
  /// ```
  static Future<void> initialize({required TwilioCommKitConfig config}) async {
    if (_initialized) {
      TwilioLogger.warning('TwilioCommKit is already initialized.');
      return;
    }

    // Validate SID formats before touching native layer
    config.credentials.validate();

    _config = config;
    TwilioLogger.configure(config.logLevel);
    TwilioLogger.debug('TwilioCommKit initializing...');
    TwilioLogger.debug(
      'Credentials: ${config.credentials.toSafeMap()}',
    );

    await TwilioCommKitPlatform.instance.initialize(
      logLevel: config.logLevel.name,
      credentials: TwilioCredentialsModel(
        accountSid: config.credentials.accountSid,
        apiKeySid: config.credentials.apiKeySid,
        pushCredentialSid: config.credentials.pushCredentialSid,
        outgoingApplicationSid: config.credentials.outgoingApplicationSid,
      ),
      videoConfig: config.videoConfig.toMap(),
      voiceConfig: config.voiceConfig.toMap(),
    );

    _initialized = true;

    // Apply Dart-layer config to singletons
    TwilioVideo.instance.applyConfig(
      maxParticipants: config.videoConfig.maxParticipants,
    );

    TwilioLogger.debug('TwilioCommKit initialized successfully.');
  }

  /// Disposes all SDK resources.
  static Future<void> dispose() async {
    TwilioVideo.instance.dispose();
    TwilioVoice.instance.dispose();
    _initialized = false;
    _config = null;
    TwilioLogger.debug('TwilioCommKit disposed.');
  }

  static void _assertInitialized() {
    assert(
      _initialized,
      'TwilioCommKit is not initialized. '
      'Call TwilioCommKit.initialize() first.',
    );
  }
}
