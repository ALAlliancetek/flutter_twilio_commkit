import 'package:flutter/material.dart';

import 'twilio_theme_data.dart';

/// Provides [TwilioThemeData] to the widget tree.
///
/// Wrap your call screens or the entire app:
/// ```dart
/// TwilioTheme(
///   data: TwilioThemeData.dark(),
///   child: TwilioVideoCallScreen(...),
/// )
/// ```
class TwilioTheme extends InheritedWidget {
  const TwilioTheme({
    super.key,
    required this.data,
    required super.child,
  });

  final TwilioThemeData data;

  static TwilioThemeData of(BuildContext context) {
    final theme = context.dependOnInheritedWidgetOfExactType<TwilioTheme>();
    return theme?.data ?? TwilioThemeData.light();
  }

  @override
  bool updateShouldNotify(TwilioTheme oldWidget) => data != oldWidget.data;
}

