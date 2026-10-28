@Tags(['golden'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/feed/demo_feed_repository.dart';
import 'package:icr_mobile/features/forum/demo_forum_repository.dart';
import 'package:icr_mobile/features/forum/thread_controller.dart';
import 'package:icr_mobile/features/forum/thread_screen.dart';
import 'package:provider/provider.dart';

import '../helpers/fonts.dart';

/// The forum's screens at the phone's frame (390 wide, 2x), drawn from the design's sample content. The Forums
/// tab and the discussion page have no design of their own (the reply thread is `forum-replies.png`), so these are
/// the pictures the app's screens are reviewed by. Refresh with
/// `flutter test --update-goldens --tags golden test/golden/forum_golden_test.dart`.
void main() {
  setUpAll(loadAppFonts);

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

  testWidgets('a discussion with its replies (demo content) at 390 x 1500', (tester) async {
    tester.view.physicalSize = const Size(780, 3000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final repository = DemoForumRepository();
    final controller = ThreadController(
      repository: repository,
      slug: 'implementing-iot-sensors-for-hvac-efficiency',
      viewer: DemoFeedRepository.me,
    );
    addTearDown(controller.dispose);
    await tester.runAsync(controller.start);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: ChangeNotifierProvider.value(value: controller, child: const ThreadScreen(unread: 3)),
      ),
    );
    await precacheAll(tester);
    await export(tester, find.byType(ThreadScreen), 'forum_thread');
    await expectLater(find.byType(ThreadScreen), matchesGoldenFile('goldens/forum_thread.png'));
  });
}
