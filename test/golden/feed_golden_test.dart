@Tags(['golden'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/feed/demo_feed_repository.dart';
import 'package:icr_mobile/features/feed/feed_controller.dart';
import 'package:icr_mobile/features/feed/feed_models.dart';
import 'package:icr_mobile/features/feed/home_screen.dart';
import 'package:icr_mobile/features/feed/widgets/reply_widgets.dart';
import 'package:provider/provider.dart';

import '../helpers/fonts.dart';

/// The Home feed and its reply section at the design's frame, laid over `docs/designs/hires/forum-replies.png`
/// and `forums-new-home.png`. Refresh with `flutter test --update-goldens --tags golden test/golden/feed_golden_test.dart`.
void main() {
  setUpAll(loadAppFonts);

  Future<void> precacheAll(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element);
      }
      final context = tester.element(find.byType(Scaffold).first);
      await precacheImage(const AssetImage('assets/images/demo/sponsored_bg.jpg'), context);
    });
    await tester.pumpAndSettle();
  }

  Future<void> export(WidgetTester tester, Finder finder, String name, double ratio) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      finder.evaluate().first.renderObject is RenderRepaintBoundary
          ? finder
          : find.ancestor(of: finder, matching: find.byType(RepaintBoundary)).first,
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: ratio);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('build/screens').createSync(recursive: true);
      File('build/screens/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  testWidgets('home (demo content) at 390 × 1996', (tester) async {
    tester.view.physicalSize = const Size(780, 3992);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final feed = FeedController(DemoFeedRepository());
    await tester.runAsync(feed.start);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: ChangeNotifierProvider.value(
          value: feed,
          child: HomeScreen(viewer: DemoFeedRepository.me, onAccount: () {}),
        ),
      ),
    );
    await precacheAll(tester);
    await export(tester, find.byType(HomeScreen), 'home_demo', 2);
    await expectLater(find.byType(HomeScreen), matchesGoldenFile('goldens/feed_home_demo.png'));
  });

  testWidgets('the reply section at 328 × 283, the size of forum-replies.png at 4x', (tester) async {
    tester.view.physicalSize = const Size(1312, 1132);
    tester.view.devicePixelRatio = 4;
    addTearDown(tester.view.reset);

    final reply = FeedReply(
      id: 'r1',
      author: const FeedAuthor(
        id: 'arvind',
        name: 'Arvind Swamy',
        headline: 'VP Sustainability at Brookfield Properties',
        photo: FeedPicture.asset('assets/images/demo/avatar_arvind.jpg'),
      ),
      body:
          'Spot on Priya. Niagara framework BACnet/IP telemetry cut vendor lock-in completely across our commercial assets.',
      createdAt: DateTime.now().subtract(const Duration(minutes: 42)),
      meta: 'Brookfield Properties',
      role: 'VP Sustainability',
      likes: 3,
    );
    final controller = TextEditingController();
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Align(
            alignment: Alignment.topLeft,
            child: RepaintBoundary(
              key: const ValueKey('frame'),
              child: ColoredBox(
                color: Colors.white,
                child: SizedBox(
                  width: 328,
                  height: 283,
                  child: OverflowBox(
                    alignment: Alignment.topLeft,
                    minHeight: 0,
                    maxHeight: 400,
                    child: SizedBox(
                      width: 326,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ThreadBranch(
                            gap: 12,
                            armY: 11,
                            child: ReplyTile(reply: reply, onLike: () {}, onReply: () {}, onMore: () {}),
                          ),
                          ThreadBranch(gap: 10, armY: 5, child: MoreRepliesPill(count: 8, onTap: () {})),
                          ThreadBranch(
                            gap: 9,
                            armY: 10,
                            last: true,
                            child: ReplyBox(
                              viewer: const FeedAuthor(
                                id: 'me',
                                name: 'Rahul Mehta',
                                photo: FeedPicture.asset('assets/images/demo/avatar_me.jpg'),
                              ),
                              controller: controller,
                              focusNode: focus,
                              sending: false,
                              hint: 'Reply to Priya Nambiar...',
                              onSend: () {},
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await precacheAll(tester);
    await export(tester, find.byKey(const ValueKey('frame')), 'forum_replies', 4);
  });
}
