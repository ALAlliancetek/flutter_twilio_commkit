/// Strongly-typed exceptions thrown by the Twilio CommKit SDK.
library;

/// Base class for all Twilio SDK exceptions.
abstract class TwilioException implements Exception {
  const TwilioException(this.message, {this.code});
  final String message;
  final int? code;

  @override
  String toString() => '$runtimeType(code: $code, message: $message)';
}

/// Thrown when authentication or token issues occur.
class TwilioAuthException extends TwilioException {
  const TwilioAuthException(super.message, {super.code});
}

/// Thrown on network-related failures.
class TwilioNetworkException extends TwilioException {
  const TwilioNetworkException(super.message, {super.code});
}

/// Thrown when required permissions are not granted.
class TwilioPermissionException extends TwilioException {
  const TwilioPermissionException(super.message, {super.code});
  final String? permission = null;
}

/// Thrown on call-level failures (video or voice).
class TwilioCallException extends TwilioException {
  const TwilioCallException(super.message, {super.code, this.callSid, this.errorCode});
  final String? callSid;
  /// Optional string error code (e.g. `'ROOM_FULL'`).
  final String? errorCode;

  @override
  String toString() => 'TwilioCallException(code: $code, errorCode: $errorCode, message: $message)';
}

/// Thrown when the SDK is used before initialization.
class TwilioNotInitializedException extends TwilioException {
  const TwilioNotInitializedException()
      : super('TwilioCommKit is not initialized. '
            'Call TwilioCommKit.initialize() first.');
}

