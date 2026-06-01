import '../utils/twilio_logger.dart';
import 'twilio_credentials.dart';
import 'twilio_video_config.dart';
import 'twilio_voice_config.dart';

export 'twilio_credentials.dart';
export 'twilio_video_config.dart';
export 'twilio_voice_config.dart';

/// Top-level SDK configuration passed to [TwilioCommKit.initialize].
///
/// Every project passes its own [credentials] so different apps (or
/// different environments within the same app) can use different
/// Twilio projects without recompiling.
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
class TwilioCommKitConfig {
  const TwilioCommKitConfig({
    required this.credentials,
    required this.accessTokenProvider,
    this.videoConfig = const TwilioVideoConfig(),
    this.voiceConfig = const TwilioVoiceConfig(),
    this.logLevel = TwilioLogLevel.none,
    this.enableAnalytics = false,
    this.tokenRefreshMarginSeconds = 30,
  });

  /// Twilio project credentials (Account SID, API Key SID, etc.).
  /// Required — each project must supply its own credentials.
  final TwilioCredentials credentials;

  /// Async callback that returns a valid Twilio access token.
  ///
  /// This is called by the SDK whenever a fresh token is needed.
  /// The token MUST be generated server-side using [credentials.apiKeySid]
  /// and [credentials.apiKeySecret].
  ///
  /// The SDK **never** generates tokens internally.
  final Future<String> Function() accessTokenProvider;

  /// Twilio Video feature configuration.
  final TwilioVideoConfig videoConfig;

  /// Twilio Voice feature configuration.
  final TwilioVoiceConfig voiceConfig;

  /// Log verbosity level.
  final TwilioLogLevel logLevel;

  /// Whether to emit analytics events to external hooks.
  final bool enableAnalytics;

  /// Seconds before token expiry at which the SDK requests a refresh.
  final int tokenRefreshMarginSeconds;
}
