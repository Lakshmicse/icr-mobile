@Tags(['golden'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/notifications/demo_notifications_repository.dart';
import 'package:icr_mobile/features/notifications/notifications_screen.dart';

import '../helpers/fonts.dart';

/// The notifications list, drawn like the Android LinkedIn one, at 390 dp (the designs' frame) and at 360 dp (a
/// common phone) with the designs' sample rows; also exported to build/screens/ for a look.
void main() {
  setUpAll(loadAppFonts);

  final now = DateTime(2026, 10, 27, 12);

  /// The demo people's photos are assets: decode them before the frame is taken.
  Future<void> precacheAll(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element);
      }
    });
    await tester.pumpAndSettle();
  }

  Future<void> export(WidgetTester tester, String name) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary).first);
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('build/screens').createSync(recursive: true);
      File('build/screens/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  for (final width in [390.0, 360.0]) {
    testWidgets('the list at ${width.toInt()} dp wide', (tester) async {
      tester.view.physicalSize = Size(width * 2, 1500);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: NotificationsScreen(
            repository: DemoNotificationsRepository(now: now),
            clock: () => now,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await precacheAll(tester);
      await export(tester, 'notifications_${width.toInt()}');
      await expectLater(
        find.byType(NotificationsScreen),
        matchesGoldenFile('goldens/notifications_${width.toInt()}.png'),
      );
    });
  }
}
