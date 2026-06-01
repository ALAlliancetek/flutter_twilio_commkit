import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/twilio_app_config.dart';

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
class TwilioTokenService {
  TwilioTokenService._();

  static final TwilioTokenService instance = TwilioTokenService._();

  String _baseUrl = TwilioAppConfig.tokenServerBaseUrl;
  String _identity = TwilioAppConfig.userIdentity;

  void setBaseUrl(String url) =>
      _baseUrl = url.trimRight().replaceAll(RegExp(r'/$'), '');
  void setIdentity(String identity) => _identity = identity;

  String get currentBaseUrl => _baseUrl;
  String get currentIdentity => _identity;

  Future<TokenResult> fetchVideoToken({
    required String roomName,
    String? identity,
  }) async =>
      _fetch(type: 'video', extraParams: {
        'room': roomName,
        'identity': identity ?? _identity,
      });

  Future<String> fetchVideoTokenOrThrow({required String roomName}) async {
    final result = await fetchVideoToken(roomName: roomName);
    return switch (result) {
      TokenSuccess(:final token) => token,
      TokenFailure(:final message, :final statusCode) =>
        throw Exception('Token fetch failed [$statusCode]: $message'),
    };
  }

  Future<TokenResult> fetchVoiceToken({String? identity}) async =>
      _fetch(type: 'voice', extraParams: {'identity': identity ?? _identity});

  Future<String> fetchVoiceTokenOrThrow() async {
    final result = await fetchVoiceToken();
    return switch (result) {
      TokenSuccess(:final token) => token,
      TokenFailure(:final message, :final statusCode) =>
        throw Exception('Voice token fetch failed [$statusCode]: $message'),
    };
  }

  Future<String> fetchToken() async {
    final result = await _fetch(type: 'video', extraParams: {
      'identity': _identity,
      'room': TwilioAppConfig.defaultVideoRoom,
    });
    return switch (result) {
      TokenSuccess(:final token) => token,
      TokenFailure(:final message, :final statusCode) =>
        throw Exception('Token refresh failed [$statusCode]: $message'),
    };
  }

  Future<TokenResult> _fetch({
    required String type,
    Map<String, String> extraParams = const {},
  }) async {
    final uri = Uri.parse('$_baseUrl/token')
        .replace(queryParameters: {'type': type, ...extraParams});
    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final token = body['token'] as String?;
        if (token == null || token.isEmpty) {
          return const TokenFailure('Server returned empty token.');
        }
        return TokenSuccess(token);
      } else {
        return TokenFailure(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
          statusCode: response.statusCode,
        );
      }
    } on SocketException catch (e) {
      return TokenFailure('Cannot reach server at $_baseUrl\n${e.message}');
    } on http.ClientException catch (e) {
      return TokenFailure('HTTP client error: ${e.message}');
    } on FormatException catch (e) {
      return TokenFailure('Invalid JSON from server: ${e.message}');
    } catch (e) {
      return TokenFailure('Unexpected error: $e');
    }
  }
}
