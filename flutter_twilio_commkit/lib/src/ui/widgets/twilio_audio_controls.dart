import 'package:flutter/material.dart';

import '../../models/audio_route.dart';
import '../../theme/twilio_theme.dart';

/// Audio route selection widget.
class TwilioAudioControls extends StatelessWidget {
  const TwilioAudioControls({
    super.key,
    required this.availableRoutes,
    required this.currentRoute,
    required this.onRouteSelected,
  });

  final List<AudioRoute> availableRoutes;
  final AudioRoute currentRoute;
  final void Function(AudioRoute route) onRouteSelected;

  @override
  Widget build(BuildContext context) {
    final theme = TwilioTheme.of(context);
    return Wrap(
      spacing: 8,
      children: availableRoutes.map((route) {
        final isSelected = route == currentRoute;
        return ChoiceChip(
          label: Text(_label(route)),
          selected: isSelected,
          selectedColor: theme.controlIconActiveColor,
          onSelected: (_) => onRouteSelected(route),
          avatar: Icon(_icon(route),
              size: 16,
              color: isSelected ? Colors.white : theme.controlIconColor,),
          labelStyle: TextStyle(
              color: isSelected ? Colors.white : theme.participantNameColor,),
        );
      }).toList(),
    );
  }

  String _label(AudioRoute route) => switch (route) {
        AudioRoute.earpiece => 'Earpiece',
        AudioRoute.speaker => 'Speaker',
        AudioRoute.bluetooth => 'Bluetooth',
        AudioRoute.headset => 'Headset',
      };

  IconData _icon(AudioRoute route) => switch (route) {
        AudioRoute.earpiece => Icons.hearing,
        AudioRoute.speaker => Icons.volume_up,
        AudioRoute.bluetooth => Icons.bluetooth_audio,
        AudioRoute.headset => Icons.headset,
      };
}

