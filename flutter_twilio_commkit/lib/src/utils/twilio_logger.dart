// ignore_for_file: avoid_print

/// Configurable logging levels for the SDK.
enum TwilioLogLevel { debug, warning, error, none }

/// Internal SDK logger. Client apps can configure or disable logging.
class TwilioLogger {
  TwilioLogger._();

  static TwilioLogLevel _level = TwilioLogLevel.none;

  /// Custom log handler override (e.g. for crash reporting).
  static void Function(TwilioLogLevel level, String message)? onLog;

  /// Configure the minimum log level.
  static void configure(TwilioLogLevel level) => _level = level;

  static void debug(String message) {
    if (_shouldLog(TwilioLogLevel.debug)) _emit(TwilioLogLevel.debug, message);
  }

  static void warning(String message) {
    if (_shouldLog(TwilioLogLevel.warning)) {
      _emit(TwilioLogLevel.warning, message);
    }
  }

  static void error(String message, [Object? error]) {
    if (_shouldLog(TwilioLogLevel.error)) {
      _emit(TwilioLogLevel.error, error != null ? '$message | $error' : message);
    }
  }

  static bool _shouldLog(TwilioLogLevel level) {
    if (_level == TwilioLogLevel.none) return false;
    return level.index >= _level.index;
  }

  static void _emit(TwilioLogLevel level, String message) {
    final tag = '[TwilioCommKit/${level.name.toUpperCase()}]';
    if (onLog != null) {
      onLog!(level, message);
    } else {
      print('$tag $message');
    }
  }
}

