import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/app.dart';
import 'package:icr_mobile/features/auth/auth_palette.dart';

import 'helpers/fonts.dart';
import 'live/live.dart' show MemoryTokens;

/// A saved session that is never read, so the app stays on its splash.
class _SlowTokens extends MemoryTokens {
  final _never = Completer<String?>();

  @override
  Future<String?> accessToken() => _never.future;
  @override
  Future<String?> refreshToken() => _never.future;
}

/// The owner, 13 Nov 2026: the ICR splash turned dark with the phone's dark mode, while the app itself is light
/// only ("there is no dark theme yet"). It is the white splash with the logo in its own colours on every phone.
void main() {
  setUpAll(loadAppFonts);

  for (final brightness in Brightness.values) {
    testWidgets('the splash is white with the light logo when the phone is in ${brightness.name} mode', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpWidget(IcrApp(tokens: _SlowTokens()));
      await tester.pump();

      final splash = tester.widget<Scaffold>(find.byKey(const ValueKey('splash')));
      expect(splash.backgroundColor, Colors.white);
      final logo = tester.widget<Image>(
        find.descendant(of: find.byKey(const ValueKey('splash')), matching: find.byType(Image)),
      );
      expect((logo.image as AssetImage).assetName, AuthPalette.light.logo);
      expect(AuthPalette.light.logo, isNot(AuthPalette.dark.logo));
    });
  }
}
