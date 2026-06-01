import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/twilio_app_config.dart';

/// Represents the result of a token fetch operation.
sealed class TokenResult {
  const TokenResult();
}

class TokenSuccess extends TokenResult {
  const TokenSuccess(this.token);
  final String token;
}

class TokenFailure extends TokenResult {
  const TokenFailure(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
}

/// Fetches Twilio Access Tokens from the configured backend server.
///
/// The server must respond with JSON: `{ "token": "<jwt>" }`
///
/// Example Node.js / Express backend:
/// ```js
/// const AccessToken = require('twilio').jwt.AccessToken;
/// const VideoGrant   = AccessToken.VideoGrant;
/// const VoiceGrant   = AccessToken.VoiceGrant;
///
/// app.get('/token', (req, res) => {
///   const identity = req.query.identity || 'user';
///   const type     = req.query.type     || 'video';
///   const token    = new AccessToken(ACCOUNT_SID, API_KEY, API_SECRET, { identity });
///   if (type === 'video') {
///     token.addGrant(new VideoGrant({ room: req.query.room }));
///   } else {
///     const voiceGrant = new VoiceGrant({
///       outgoingApplicationSid: TWIML_APP_SID,
///       incomingAllow: true,
///     });
///     token.addGrant(voiceGrant);
///   }
///   res.json({ token: token.toJwt() });
/// });
/// ```
class TwilioTokenService {
  TwilioTokenService._();

  static final TwilioTokenService instance = TwilioTokenService._();

  // Override this at runtime via [setBaseUrl] (e.g. from settings screen)
  String _baseUrl = TwilioAppConfig.tokenServerBaseUrl;
  String _identity = TwilioAppConfig.userIdentity;

  /// Update the token server base URL at runtime.
  void setBaseUrl(String url) => _baseUrl = url.trimRight().replaceAll(RegExp(r'/$'), '');

  /// Update the user identity at runtime.
  void setIdentity(String identity) => _identity = identity;

  String get currentBaseUrl => _baseUrl;
  String get currentIdentity => _identity;

  // ─── Video Token ──────────────────────────────────────────────────────────

  /// Fetches a Video access token for the given [roomName].
  ///
  /// Returns [TokenSuccess] with the JWT or [TokenFailure] with a message.
  Future<TokenResult> fetchVideoToken({
    required String roomName,
    String? identity,
  }) async {
    return _fetch(
      type: 'video',
      extraParams: {
        'room': roomName,
        'identity': identity ?? _identity,
      },
    );
  }

  /// Convenience method — throws [Exception] on failure.
  /// Use this as the `accessTokenProvider` callback in [TwilioCommKitConfig].
  Future<String> fetchVideoTokenOrThrow({required String roomName}) async {
    final result = await fetchVideoToken(roomName: roomName);
    return switch (result) {
      TokenSuccess(:final token) => token,
      TokenFailure(:final message, :final statusCode) =>
        throw Exception('Token fetch failed [$statusCode]: $message'),
    };
  }

  // ─── Voice Token ──────────────────────────────────────────────────────────

  /// Fetches a Voice access token.
  Future<TokenResult> fetchVoiceToken({String? identity}) async {
    return _fetch(
      type: 'voice',
      extraParams: {'identity': identity ?? _identity},
    );
  }

  /// Convenience method — throws [Exception] on failure.
  Future<String> fetchVoiceTokenOrThrow() async {
    final result = await fetchVoiceToken();
    return switch (result) {
      TokenSuccess(:final token) => token,
      TokenFailure(:final message, :final statusCode) =>
        throw Exception('Voice token fetch failed [$statusCode]: $message'),
    };
  }

  // ─── Generic Token (used as accessTokenProvider) ──────────────────────────

  /// Generic token provider compatible with [TwilioCommKitConfig.accessTokenProvider].
  ///
  /// Fetches a video token for the default room, suitable for the SDK's
  /// internal token refresh mechanism.
  Future<String> fetchToken() async {
    final result = await _fetch(
      type: 'video',
      extraParams: {
        'identity': _identity,
        'room': TwilioAppConfig.defaultVideoRoom,
      },
    );
    return switch (result) {
      TokenSuccess(:final token) => token,
      TokenFailure(:final message, :final statusCode) =>
        throw Exception('Token refresh failed [$statusCode]: $message'),
    };
  }

  // ─── Internal ─────────────────────────────────────────────────────────────

  Future<TokenResult> _fetch({
    required String type,
    Map<String, String> extraParams = const {},
  }) async {
    final uri = Uri.parse('$_baseUrl/token').replace(
      queryParameters: {
        'type': type,
        ...extraParams,
      },
    );

    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final token = body['token'] as String?;
        if (token == null || token.isEmpty) {
          return const TokenFailure(
              'Server returned empty token. Check server response format: { "token": "<jwt>" }');
        }
        return TokenSuccess(token);
      } else {
        return TokenFailure(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}. '
          'Body: ${response.body}',
          statusCode: response.statusCode,
        );
      }
    } on SocketException catch (e) {
      return TokenFailure(
        'Cannot reach token server at $_baseUrl\n'
        'Check your tokenServerBaseUrl in TwilioAppConfig.\n'
        'Error: ${e.message}',
      );
    } on http.ClientException catch (e) {
      return TokenFailure('HTTP client error: ${e.message}');
    } on FormatException catch (e) {
      return TokenFailure(
          'Invalid JSON from server: ${e.message}. '
          'Expected: { "token": "<jwt>" }');
    } catch (e) {
      return TokenFailure('Unexpected error: $e');
    }
  }
}

