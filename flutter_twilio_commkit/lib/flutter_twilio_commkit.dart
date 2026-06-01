/// Flutter Twilio CommKit — Production-grade Flutter Twilio Communication SDK.
///
/// Supports Video Calling, Voice Calling, and future Chat integration.
///
/// ## Quick Start
/// ```dart
/// import 'package:flutter_twilio_commkit/flutter_twilio_commkit.dart';
///
/// await TwilioCommKit.initialize(
///   config: TwilioCommKitConfig(
///     credentials: TwilioCredentials(
///       accountSid: 'ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
///       apiKeySid:  'SKxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
///       outgoingApplicationSid: 'APxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
///       pushCredentialSid:      'CRxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
///     ),
///     accessTokenProvider: () async => await myServer.fetchToken(),
///   ),
/// );
/// ```
library;

// Core
export 'src/core/twilio_commkit.dart';
export 'src/core/twilio_commkit_config.dart';
export 'src/core/twilio_user_preferences.dart';

// Config
export 'src/config/twilio_commkit_config.dart';
export 'src/config/twilio_credentials.dart';
export 'src/config/twilio_video_config.dart';
export 'src/config/twilio_voice_config.dart';

// Video
export 'src/video/twilio_video.dart';
export 'src/video/video_room.dart';

// Voice
export 'src/voice/twilio_voice.dart';
export 'src/voice/voice_call.dart';


// Models
export 'src/models/participant.dart';
export 'src/models/call_state.dart';
export 'src/models/room_state.dart';
export 'src/models/network_quality.dart';
export 'src/models/audio_route.dart';

// Events
export 'src/events/video_events.dart';
export 'src/events/voice_events.dart';

// Exceptions
export 'src/exceptions/twilio_exceptions.dart';

// Theme
export 'src/theme/twilio_theme.dart';
export 'src/theme/twilio_theme_data.dart'; // includes TwilioCallButtonStyle

// UI — Video
export 'src/ui/video/twilio_video_call_screen.dart';
export 'src/ui/video/twilio_participant_tile.dart';
export 'src/ui/video/twilio_video_preview.dart';
export 'src/ui/video/twilio_video_view.dart';

// UI — Voice
export 'src/ui/voice/twilio_voice_call_screen.dart';
export 'src/ui/voice/twilio_incoming_call_screen.dart';
export 'src/ui/voice/twilio_call_handler.dart';

// UI — Widgets
export 'src/ui/widgets/twilio_call_controls.dart';
export 'src/ui/widgets/twilio_audio_controls.dart';
export 'src/ui/widgets/twilio_avatar.dart';

// Permissions
export 'src/permissions/twilio_permissions.dart';

// Logging
export 'src/utils/twilio_logger.dart';
