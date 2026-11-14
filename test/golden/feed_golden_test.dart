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
import 'package:icr_mobile/features/feed/feed_styles.dart';
import 'package:icr_mobile/features/feed/widgets/comment_widgets.dart';
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

  testWidgets('comments, drawn as LinkedIn draws them, at 360 × 520', (tester) async {
    tester.view.physicalSize = const Size(1080, 1560);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final now = DateTime(2026, 11, 13, 12);
    FeedReply reply(
      String id,
      String name,
      String headline,
      String photo,
      String body,
      Duration ago, {
      int likes = 0,
    }) => FeedReply(
      id: id,
      author: FeedAuthor(id: id, name: name, headline: headline, photo: FeedPicture.asset(photo)),
      body: body,
      createdAt: now.subtract(ago),
      likes: likes,
    );
    final top = reply(
      'c1',
      'Arvind Swamy',
      'VP Sustainability at Brookfield Properties',
      'assets/images/demo/avatar_arvind.jpg',
      'Niagara framework BACnet/IP telemetry cut vendor lock-in completely across our commercial assets.',
      const Duration(days: 3),
      likes: 9,
    );
    final answers = [
      reply(
        'c2',
        'Priya Nambiar',
        'Head of Facilities at TechCorp',
        'assets/images/demo/avatar_me.jpg',
        'Which supervisor version are you on?',
        const Duration(days: 3),
        likes: 36,
      ),
      reply(
        'c3',
        'Arvind Swamy',
        'VP Sustainability at Brookfield Properties',
        'assets/images/demo/avatar_arvind.jpg',
        'Niagara 4.13, with the analytics pack.',
        const Duration(days: 2),
      ),
    ];
    final controller = TextEditingController();
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    Widget tile(FeedReply r, {int replies = 0, String? to, bool follow = false}) => CommentTile(
      reply: r,
      now: now,
      replyCount: replies,
      replyingTo: to,
      onFollow: follow ? () {} : null,
      onLike: () {},
      onReply: () {},
      onMore: () {},
    );
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
                  width: 360,
                  height: 520,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: CommentDesign.pad),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: CommentSortButton(sort: CommentSort.relevant, onChanged: (_) {}),
                        ),
                        tile(top, replies: 2, follow: true),
                        CommentReplies(
                          children: [
                            tile(answers[0], to: 'Arvind Swamy', follow: true),
                            tile(answers[1], to: 'Priya Nambiar'),
                          ],
                        ),
                        const Spacer(),
                        ReplyBox(
                          look: ReplyLook.home,
                          viewer: const FeedAuthor(
                            id: 'me',
                            name: 'Rahul Mehta',
                            photo: FeedPicture.asset('assets/images/demo/avatar_me.jpg'),
                          ),
                          controller: controller,
                          focusNode: focus,
                          sending: false,
                          hint: 'Add a comment...',
                          onSend: () {},
                        ),
                        const SizedBox(height: 8),
                      ],
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
    await expectLater(find.byKey(const ValueKey('frame')), matchesGoldenFile('goldens/feed_comments.png'));
  });
}
