import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/feed/feed_models.dart';
import 'package:icr_mobile/features/feed/widgets/post_card.dart';
import 'package:icr_mobile/features/feed/widgets/post_photo_viewer.dart';

import 'helpers/fonts.dart';

/// A post's photos as LinkedIn draws them (owner, 14 Nov 2026): on the card one large photo with a column of smaller
/// ones, and full screen a dark page to swipe through with Like, Comment and Repost beside the photo and the post's
/// words under it, whose "…more" opens them whole in a sheet.
void main() {
  setUpAll(loadAppFonts);

  const demo = 'assets/images/demo';
  const pictures = ['$demo/post_green_tower.jpg', '$demo/post_rooftop_hvac.jpg', '$demo/post_control_room.jpg'];
  final long = List.filled(12, 'Regular calibration keeps every reading honest.').join(' ');

  FeedPost post({
    int photos = 4,
    List<String> videos = const [],
    String? body,
    ReactionKind? mine,
    bool showFollow = false,
    int reactions = 164,
  }) => FeedPost(
    id: 'p1',
    slug: 'p1',
    author: const FeedAuthor(id: 'a', name: 'Mithesh K', headline: 'Calibration Lead'),
    createdAt: DateTime(2026, 11, 14, 9),
    title: 'Importance of Regular Equipment Calibration',
    body: body ?? long,
    topic: 'Calibration, Testing & Inspection',
    tags: const ['#calibration', '#quality'],
    images: [for (var i = 0; i < photos; i++) FeedPicture.asset(pictures[i % pictures.length])],
    videos: videos,
    reactions: reactions,
    myReaction: mine,
    comments: 46,
    shares: 3,
    showFollow: showFollow,
  );

  group('the card', () {
    final opened = <int>[];
    final played = <String>[];

    setUp(() {
      opened.clear();
      played.clear();
    });

    Future<void> pumpCard(WidgetTester tester, FeedPost p, {bool opens = true}) async {
      tester.view.physicalSize = const Size(780, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: PostCard(
                post: p,
                commentsOpen: false,
                onFollow: () {},
                onSave: () {},
                onMore: () {},
                onLike: () {},
                onComments: () {},
                onRepost: () {},
                onShare: () {},
                onVote: (_) {},
                onOpenVideo: played.add,
                onOpenPhoto: opens ? opened.add : null,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    Finder photo(int i) => find.byKey(ValueKey('post-photo:p1:$i'));
    Size sizeOf(WidgetTester tester, int i) => tester.getSize(photo(i));

    testWidgets('two photos sit side by side, as before', (tester) async {
      await pumpCard(tester, post(photos: 2));
      expect(sizeOf(tester, 0), const Size(194, 194));
      expect(sizeOf(tester, 1), const Size(194, 194));
      expect(tester.getTopLeft(photo(1)).dy, tester.getTopLeft(photo(0)).dy);
      expect(find.textContaining('+'), findsNothing);
    });

    testWidgets('three photos: a large one with two beside it, one above the other', (tester) async {
      await pumpCard(tester, post(photos: 3));
      final large = tester.getRect(photo(0));
      final upper = tester.getRect(photo(1));
      final lower = tester.getRect(photo(2));
      expect(large.width, closeTo(390 * 2 / 3, 2));
      expect(large.height, closeTo(260, 0.5), reason: 'the block is three wide by two tall');
      expect(upper.width, closeTo(390 / 3, 2));
      expect(upper.left, greaterThan(large.right));
      expect(lower.left, upper.left);
      expect(lower.top, greaterThan(upper.bottom));
      expect(lower.bottom, large.bottom);
      expect(find.textContaining('+'), findsNothing);
    });

    testWidgets('four photos: a tall one with three beside it, and nothing counted', (tester) async {
      await pumpCard(tester, post(photos: 4));
      final large = tester.getRect(photo(0));
      expect(large.height, closeTo(390, 0.5), reason: 'the block is square');
      expect(large.width, closeTo(390 * 2 / 3, 2));
      final column = [for (var i = 1; i < 4; i++) tester.getRect(photo(i))];
      expect(column.map((r) => r.left).toSet(), hasLength(1), reason: 'one column');
      expect(column[0].top, large.top);
      expect(column[2].bottom, large.bottom);
      expect(column[1].top, greaterThan(column[0].bottom));
      for (final r in column) {
        expect(r.height, closeTo(390 / 3, 2));
      }
      expect(find.textContaining('+'), findsNothing);
    });

    testWidgets('more than four: four tiles, the last counting the rest', (tester) async {
      await pumpCard(tester, post(photos: 7));
      expect(photo(3), findsOneWidget);
      expect(photo(4), findsNothing);
      expect(find.descendant(of: photo(3), matching: find.text('+3')), findsOneWidget);
    });

    testWidgets('a photo opens the photos at that photo; the counted tile opens at itself', (tester) async {
      await pumpCard(tester, post(photos: 6));
      await tester.tap(photo(0));
      await tester.tap(photo(2));
      await tester.tap(photo(3));
      expect(opened, [0, 2, 3]);
      expect(played, isEmpty);
    });

    testWidgets('one photo opens too', (tester) async {
      await pumpCard(tester, post(photos: 1));
      await tester.tap(photo(0));
      expect(opened, [0]);
    });

    testWidgets('a video among the tiles still plays, and the photos keep their places', (tester) async {
      await pumpCard(tester, post(photos: 2, videos: const ['https://cdn.test/clip.mp4']));
      expect(photo(0), findsOneWidget);
      expect(photo(1), findsOneWidget);
      expect(photo(2), findsNothing, reason: 'the third tile is the video');
      await tester.tap(find.byKey(const ValueKey('post-video:https://cdn.test/clip.mp4')));
      await tester.tap(photo(1));
      expect(played, ['https://cdn.test/clip.mp4']);
      expect(opened, [1]);
    });

    testWidgets('a screen that opens no photos leaves them as pictures', (tester) async {
      await pumpCard(tester, post(photos: 4), opens: false);
      expect(photo(0), findsNothing);
      expect(find.byType(Image), findsNWidgets(4));
    });
  });

  group('the photos, full screen', () {
    late ValueNotifier<FeedPost?> shown;
    final did = <String>[];
    final holds = <Rect>[];
    final profiles = <String>[];

    setUp(() {
      did.clear();
      holds.clear();
      profiles.clear();
    });

    Future<void> pumpViewer(WidgetTester tester, FeedPost p, {int initial = 0, bool follow = true}) async {
      tester.view.physicalSize = const Size(780, 1688);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      shown = ValueNotifier(p);
      addTearDown(shown.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: PostPhotoViewer(
            initial: initial,
            host: PhotoViewerHost(
              listenable: shown,
              post: () => shown.value,
              onLike: (_) => did.add('like'),
              onPickReaction: (_, rect) => holds.add(rect),
              onComments: (_) => did.add('comments'),
              onRepost: (_) => did.add('repost'),
              onShare: (_) => did.add('share'),
              onMore: (_) => did.add('more'),
              onFollow: follow ? (_) => did.add('follow') : null,
              onOpenAuthor: () => did.add('author'),
              onOpenMention: profiles.add,
              now: DateTime(2026, 11, 14, 9, 11),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    Finder key(String k) => find.byKey(ValueKey(k));

    testWidgets('a dark page that opens at the photo tapped and counts the photos in dots', (tester) async {
      await pumpViewer(tester, post(photos: 4), initial: 1);
      expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, PhotoViewerLook.page);
      expect(key('viewer-photo:1'), findsOneWidget);
      expect(find.bySemanticsLabel('Photo 2 of 4'), findsOneWidget);
      expect(tester.getSize(key('viewer-dot:1')).width, greaterThan(tester.getSize(key('viewer-dot:0')).width));
      for (var i = 0; i < 4; i++) {
        expect(key('viewer-dot:$i'), findsOneWidget);
      }
    });

    testWidgets('swiping moves through the photos, to the last and no further', (tester) async {
      await pumpViewer(tester, post(photos: 3));
      expect(find.bySemanticsLabel('Photo 1 of 3'), findsOneWidget);
      await tester.fling(key('viewer-pages'), const Offset(-300, 0), 1200);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Photo 2 of 3'), findsOneWidget);
      await tester.fling(key('viewer-pages'), const Offset(-300, 0), 1200);
      await tester.pumpAndSettle();
      await tester.fling(key('viewer-pages'), const Offset(-300, 0), 1200);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Photo 3 of 3'), findsOneWidget);
      expect(key('viewer-photo:2'), findsOneWidget);
    });

    testWidgets('one photo has no dots', (tester) async {
      await pumpViewer(tester, post(photos: 1));
      expect(key('viewer-dots'), findsNothing);
      expect(key('viewer-photo:0'), findsOneWidget);
    });

    testWidgets('Like, Comment and Repost stand down the right edge with their numbers', (tester) async {
      await pumpViewer(tester, post());
      final like = tester.getRect(key('viewer-like'));
      final comments = tester.getRect(key('viewer-comments'));
      final repost = tester.getRect(key('viewer-repost'));
      expect(like.center.dx, greaterThan(390 - 60));
      expect(comments.top, greaterThanOrEqualTo(like.bottom));
      expect(repost.top, greaterThanOrEqualTo(comments.bottom));
      expect(find.descendant(of: key('viewer-like'), matching: find.text('164')), findsOneWidget);
      expect(find.descendant(of: key('viewer-comments'), matching: find.text('46')), findsOneWidget);
      expect(find.descendant(of: key('viewer-repost'), matching: find.text('3')), findsOneWidget);

      await tester.tap(key('viewer-like'));
      await tester.tap(key('viewer-comments'));
      await tester.tap(key('viewer-repost'));
      await tester.tap(key('viewer-share'));
      await tester.tap(key('viewer-more'));
      expect(did, ['like', 'comments', 'repost', 'share', 'more']);
    });

    testWidgets('a count of nothing is not written', (tester) async {
      await pumpViewer(tester, post(reactions: 0));
      expect(find.descendant(of: key('viewer-like'), matching: find.byType(Text)), findsNothing);
    });

    testWidgets('holding Like asks for the reactions, from the button\'s place', (tester) async {
      await pumpViewer(tester, post());
      await tester.longPress(key('viewer-like'));
      expect(holds, hasLength(1));
      expect(holds.single.overlaps(tester.getRect(key('viewer-like'))), isTrue);
      expect(did, isEmpty);
    });

    testWidgets('the reader\'s own reaction is drawn as its badge, and follows the post', (tester) async {
      await pumpViewer(tester, post());
      expect(key('viewer-my-reaction'), findsNothing);
      shown.value = post(mine: ReactionKind.celebrate, reactions: 165);
      await tester.pump();
      expect(tester.widget<ReactionBadge>(key('viewer-my-reaction')).kind, ReactionKind.celebrate);
      expect(find.descendant(of: key('viewer-like'), matching: find.text('165')), findsOneWidget);
    });

    testWidgets('under the photo: the author, "Follow" for someone not followed, and Send', (tester) async {
      await pumpViewer(tester, post(showFollow: true));
      expect(find.text('Mithesh K'), findsOneWidget);
      expect(find.text('Calibration Lead'), findsOneWidget);
      await tester.tap(key('viewer-follow'));
      await tester.tap(key('viewer-author'));
      expect(did, ['follow', 'author']);

      await pumpViewer(tester, post());
      expect(key('viewer-follow'), findsNothing, reason: 'someone already followed');
    });

    testWidgets('the words are cut at two lines, and "…more" opens them whole in a sheet', (tester) async {
      await pumpViewer(tester, post());
      final cut = find.descendant(of: key('viewer-words'), matching: key('post-body-more'));
      expect(cut, findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(find.descendant(of: cut, matching: find.byType(RichText)));
      expect(paragraph.size.height, lessThanOrEqualTo(41), reason: 'two lines of 20');
      final words = paragraph.text.toPlainText();
      expect(words, startsWith('Importance of Regular Equipment Calibration\n'));
      expect(key('post-text-sheet'), findsNothing);

      final at = words.indexOf('…more');
      final box = paragraph.getBoxesForSelection(TextSelection(baseOffset: at, extentOffset: at + 5)).first;
      await tester.tapAt(paragraph.localToGlobal(box.toRect().center));
      await tester.pumpAndSettle();

      expect(key('post-text-sheet'), findsOneWidget);
      expect(tester.widget<Material>(key('post-text-sheet')).color, Colors.white);
      final sheet = find.descendant(of: key('post-text-sheet'), matching: find.byType(RichText));
      final all = tester.widgetList<RichText>(sheet).map((t) => t.text.toPlainText()).join('\n');
      expect(all, contains('11m ago • Calibration, Testing & Inspection'));
      expect(all, contains('Importance of Regular Equipment Calibration'));
      expect(all, contains(long), reason: 'every word of the post');
      expect(all, contains('#calibration'));
      expect(key('viewer-words'), findsOneWidget, reason: 'the photos stay under the sheet');
      // The sheet leaves the top of the photos showing, as LinkedIn's does.
      expect(tester.getTopLeft(key('post-text-sheet')).dy, greaterThan(100));
    });

    testWidgets('a long post scrolls inside its sheet', (tester) async {
      await pumpViewer(tester, post(body: List.filled(30, long).join('\n\n')));
      final cut = find.descendant(of: key('viewer-words'), matching: key('post-body-more'));
      final paragraph = tester.renderObject<RenderParagraph>(find.descendant(of: cut, matching: find.byType(RichText)));
      final at = paragraph.text.toPlainText().indexOf('…more');
      final box = paragraph.getBoxesForSelection(TextSelection(baseOffset: at, extentOffset: at + 5)).first;
      await tester.tapAt(paragraph.localToGlobal(box.toRect().center));
      await tester.pumpAndSettle();
      expect(tester.getSize(key('post-text-sheet')).height, closeTo(844 * 0.83, 1));
      final scroll = tester.widget<SingleChildScrollView>(key('post-text-scroll'));
      expect(scroll, isNotNull);
      await tester.drag(key('post-text-scroll'), const Offset(0, -400));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('words that fit are drawn whole, with no "…more"', (tester) async {
      await pumpViewer(tester, post(body: 'Short.'));
      expect(find.descendant(of: key('viewer-words'), matching: key('post-body-more')), findsNothing);
      expect(find.textContaining('Short.'), findsOneWidget);
    });

    testWidgets('the back arrow leaves the photos', (tester) async {
      tester.view.physicalSize = const Size(780, 1688);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      shown = ValueNotifier(post());
      addTearDown(shown.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showPostPhotoViewer(
                  context,
                  initial: 2,
                  host: PhotoViewerHost(
                    listenable: shown,
                    post: () => shown.value,
                    onLike: (_) {},
                    onComments: (_) {},
                    onRepost: (_) {},
                    onShare: (_) {},
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Photo 3 of 4'), findsOneWidget);
      expect(key('viewer-more'), findsNothing, reason: 'no menu handed over, no three dots');
      await tester.tap(key('viewer-back'));
      await tester.pumpAndSettle();
      expect(find.byType(PostPhotoViewer), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('a post that goes while it is open keeps what was last read on screen', (tester) async {
      await pumpViewer(tester, post(photos: 2));
      shown.value = null;
      await tester.pump();
      expect(find.text('Mithesh K'), findsOneWidget);
      expect(key('viewer-photo:0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
