# flutter_twilio_commkit_platform_interface

Platform interface package for [`flutter_twilio_commkit`](https://pub.dev/packages/flutter_twilio_commkit).

This package defines the abstract platform interface and data models shared between the Android and iOS implementations. It follows the [federated plugin pattern](https://docs.flutter.dev/packages-and-plugins/developing-packages#federated-plugins).

## Usage

This package is not intended to be used directly. Add `flutter_twilio_commkit` to your project instead:

```yaml
dependencies:
  flutter_twilio_commkit: ^0.1.0
```

## Implementing a new platform

To implement this plugin for a new platform, extend `TwilioCommKitPlatform` from `package:flutter_twilio_commkit_platform_interface` and override all abstract methods.

