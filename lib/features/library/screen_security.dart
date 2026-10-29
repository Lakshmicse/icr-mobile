import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// What the phone is asked to do: stop (or allow again) screenshots and screen recording of this app's
/// window. One seam, so a test sees the requests and a platform with nothing to ask does nothing.
abstract class ScreenSecurityPlatform {
  Future<void> setSecure(bool on);
}

/// Android's FLAG_SECURE on the window (see `MainActivity.kt`): the system then refuses screenshots and
/// screen recording, and the recent-apps card is blank. Every other platform is left alone, and a phone
/// that cannot be asked (a test, an older build) simply stays as it was.
class MethodChannelScreenSecurity implements ScreenSecurityPlatform {
  const MethodChannelScreenSecurity();

  static const _channel = MethodChannel('org.icr.icr_mobile/secure_screen');

  @override
  Future<void> setSecure(bool on) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('setSecure', {'on': on});
    } on MissingPluginException {
      // Nothing on this side to ask.
    } on PlatformException {
      // The window refused: nothing more to do.
    }
  }
}

/// Who currently wants the window protected. The Digital Library's screens stack (the list, a document, the
/// viewer), so protection is counted: it goes on with the first screen and off only when the last one leaves.
class ScreenSecurity {
  const ScreenSecurity._();

  /// Where the requests go. Tests replace it.
  static ScreenSecurityPlatform platform = const MethodChannelScreenSecurity();

  static int _holds = 0;

  /// How many screens are holding the window protected right now.
  static int get holds => _holds;

  static void hold() {
    if (_holds++ == 0) unawaited(platform.setSecure(true));
  }

  static void release() {
    if (_holds == 0) return;
    if (--_holds == 0) unawaited(platform.setSecure(false));
  }
}

/// Keeps the window protected from screenshots and recording for as long as [child] is on screen.
class ScreenGuard extends StatefulWidget {
  const ScreenGuard({super.key, required this.child});

  final Widget child;

  @override
  State<ScreenGuard> createState() => _ScreenGuardState();
}

class _ScreenGuardState extends State<ScreenGuard> {
  @override
  void initState() {
    super.initState();
    ScreenSecurity.hold();
  }

  @override
  void dispose() {
    ScreenSecurity.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
