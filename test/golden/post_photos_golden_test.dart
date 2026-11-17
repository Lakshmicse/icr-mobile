@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/feed/feed_models.dart';
import 'package:icr_mobile/features/feed/widgets/post_card.dart';
import 'package:icr_mobile/features/feed/widgets/post_photo_viewer.dart';

import '../helpers/fonts.dart';

/// A post's photos as LinkedIn draws them (owner, 14 Nov 2026): the card's grid, the dark full-screen viewer and
/// the sheet "…more" opens. Refresh with
/// `flutter test --update-goldens --tags golden test/golden/post_photos_golden_test.dart`.
void main() {
  setUpAll(loadAppFonts);

  const demo = 'assets/images/demo';
  const pictures = ['$demo/post_green_tower.jpg', '$demo/post_rooftop_hvac.jpg', '$demo/post_control_room.jpg'];
  // A year gone: the card prints the date, which no later day changes ("6h ago" would).
  final now = DateTime(2025, 10, 12, 9, 11);

  FeedPost post(int photos) => FeedPost(
    id: 'p1',
    slug: 'p1',
    author: const FeedAuthor(
      id: 'a',
      name: 'Mithesh K',
      headline: 'Calibration Lead at Precision Labs',
      photo: FeedPicture.asset('$demo/avatar_arvind.jpg'),
    ),
    createdAt: DateTime(2025, 10, 12, 9),
    title: 'Importance of Regular Equipment Calibration',
    body:
        'Why Is Regular Equipment Calibration Important?\n'
        'Accuracy is the foundation of quality and reliability. Regular calibration ensures that measuring '
        'instruments stay within tolerance, so every reading a team acts on can be trusted.\n\n'
        'A drifting gauge is rarely noticed on the day it drifts. It is noticed weeks later, in rework, in a failed '
        'audit, or in a customer complaint. A calibration schedule turns that surprise into a routine check.\n\n'
        'Start with the instruments that decide whether a part ships, then work outward.',
    topic: 'Calibration, Testing & Inspection',
    tags: const ['#calibration', '#quality', '#inspection'],
    images: [for (var i = 0; i < photos; i++) FeedPicture.asset(pictures[i % pictures.length])],
    reactions: 164,
    reactionKinds: const [ReactionKind.like, ReactionKind.celebrate],
    comments: 46,
    shares: 3,
    showFollow: true,
  );

  Future<void> precacheAll(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element);
      }
    });
    await tester.pumpAndSettle();
  }

  for (final photos in [3, 4, 6]) {
    testWidgets('a card with $photos photos at 390 wide', (tester) async {
      tester.view.physicalSize = const Size(780, 1400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: RepaintBoundary(
                key: const ValueKey('frame'),
                child: PostCard(
                  post: post(photos),
                  commentsOpen: false,
                  onFollow: () {},
                  onSave: () {},
                  onMore: () {},
                  onLike: () {},
                  onComments: () {},
                  onRepost: () {},
                  onShare: () {},
                  onVote: (_) {},
                  onOpenPhoto: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await precacheAll(tester);
      await expectLater(find.byKey(const ValueKey('frame')), matchesGoldenFile('goldens/post_photos_card_$photos.png'));
    });
  }

  Future<ValueNotifier<FeedPost?>> pumpViewer(WidgetTester tester, {int initial = 1}) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final shown = ValueNotifier<FeedPost?>(post(4));
    addTearDown(shown.dispose);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: PostPhotoViewer(
          initial: initial,
          host: PhotoViewerHost(
            listenable: shown,
            post: () => shown.value,
            onLike: (_) {},
            onPickReaction: (_, _) {},
            onComments: (_) {},
            onRepost: (_) {},
            onShare: (_) {},
            onMore: (_) {},
            onFollow: (_) {},
            now: now,
          ),
        ),
      ),
    );
    await precacheAll(tester);
    return shown;
  }

  testWidgets('the photos full screen at 390 × 844', (tester) async {
    await pumpViewer(tester);
    await expectLater(find.byType(PostPhotoViewer), matchesGoldenFile('goldens/post_photo_viewer.png'));
  });

  testWidgets('the post\'s words in their sheet, over the photos', (tester) async {
    await pumpViewer(tester);
    final cut = find.descendant(
      of: find.byKey(const ValueKey('viewer-words')),
      matching: find.byKey(const ValueKey('post-body-more')),
    );
    final paragraph = tester.renderObject<RenderParagraph>(find.descendant(of: cut, matching: find.byType(RichText)));
    final at = paragraph.text.toPlainText().indexOf('…more');
    final box = paragraph.getBoxesForSelection(TextSelection(baseOffset: at, extentOffset: at + 5)).first;
    await tester.tapAt(paragraph.localToGlobal(box.toRect().center));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/post_photo_text_sheet.png'));
  });
}
