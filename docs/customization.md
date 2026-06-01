# Customization Guide

## Theme

```dart
final myTheme = TwilioThemeData.dark().copyWith(
  backgroundColor: const Color(0xFF0A1628),
  controlBarColor: const Color(0xFF1B2A4A),
  controlIconColor: const Color(0xFF00D9FF),
  controlIconActiveColor: const Color(0xFFFF4081),
  participantTileRadius: 20.0,
  controlIconSize: 28.0,
);
```

## Apply theme globally

```dart
TwilioTheme(
  data: myTheme,
  child: TwilioVideoCallScreen(...),
)
```

## Custom Controls Bar

```dart
TwilioVideoCallScreen(
  roomName: 'my-room',
  accessToken: token,
  controlsBuilder: (context, state) {
    return Row(children: [
      IconButton(
        icon: Icon(state.isAudioMuted ? Icons.mic_off : Icons.mic),
        onPressed: () => TwilioVideo.instance.muteAudio(muted: !state.isAudioMuted),
      ),
      // ... your buttons
    ]);
  },
)
```

## Custom Participant Tile

```dart
TwilioVideoCallScreen(
  roomName: 'my-room',
  accessToken: token,
  participantBuilder: (context, participant) {
    return Container(
      decoration: BoxDecoration(
        border: participant.isDominantSpeaker
            ? Border.all(color: Colors.green, width: 2)
            : null,
      ),
      child: Text(participant.identity),
    );
  },
)
```

## Headless Mode

Use APIs directly, build your own UI:

```dart
// Join room
final room = await TwilioVideo.instance.joinRoom(
  accessToken: token,
  roomName: 'my-room',
);

// React to events
TwilioVideo.instance.onRoomEvent.listen((event) {
  switch (event) {
    case ParticipantConnectedRoomEvent(:final participant):
      setState(() => participants.add(participant));
    default: break;
  }
});

// Build your own participant grid
GridView.builder(
  itemCount: participants.length,
  itemBuilder: (ctx, i) => MyCustomTile(participant: participants[i]),
);
```

## Logger Hook

```dart
TwilioLogger.onLog = (level, message) {
  // Forward to your analytics/crash reporting
  myAnalytics.log('[TwilioCommKit/$level] $message');
};
```

