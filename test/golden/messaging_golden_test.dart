@Tags(['golden'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/messaging/demo_messaging_repository.dart';
import 'package:icr_mobile/features/messaging/inbox_screen.dart';

import '../helpers/fonts.dart';

/// The Messages inbox at the design's frame (docs/designs/messaging-inbox.png, 390 dp at 2x), over the demo
/// content, exported at 2x to build/screens/messaging_inbox.png for tool/design/compare.py.
void main() {
  setUpAll(loadAppFonts);

  /// The design reads "10:42 AM" and "Yesterday" for its first rows and "Apr 14" / "Apr 12" for the last two:
  /// a clock ten minutes past the first message, two weeks after the older ones.
  final now = DateTime(2026, 4, 29, 10, 50);

  Future<void> precacheAll(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element);
      }
    });
    await tester.pumpAndSettle();
  }

  Future<void> export(WidgetTester tester, Finder finder, String name) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.ancestor(of: finder, matching: find.byType(RepaintBoundary)).first,
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('build/screens').createSync(recursive: true);
      File('build/screens/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  testWidgets('messaging inbox (demo content) at 390 × 959', (tester) async {
    tester.view.physicalSize = const Size(780, 1918);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: InboxScreen(
          repository: DemoMessagingRepository(now: now),
          poll: false,
          clock: () => now,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await precacheAll(tester);
    await export(tester, find.byType(InboxScreen), 'messaging_inbox');
    await expectLater(find.byType(InboxScreen), matchesGoldenFile('goldens/messaging_inbox.png'));
  });
}
