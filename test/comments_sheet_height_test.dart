import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/features/feed/feed_models.dart';
import 'package:icr_mobile/features/feed/widgets/comments_sheet.dart';

import 'helpers/fonts.dart';

/// The comments sheet is as tall as what it holds (owner, 13 Nov 2026): low with no comments, taller with a few,
/// and at 94% of the screen it stops growing and the comments scroll.
void main() {
  setUpAll(loadAppFonts);

  const viewer = FeedAuthor(id: 'me', name: 'Pooja Rao');
  final at = DateTime.utc(2026, 11, 13, 9);

  FeedPost post(int comments) => FeedPost(
    id: 'p1',
    slug: 'p1',
    author: const FeedAuthor(id: 'a', name: 'Anita Raghavan'),
    createdAt: at,
    title: 'A discussion',
    body: 'Its words.',
    comments: comments,
    repliesLoaded: true,
    replies: [
      for (var i = 0; i < comments; i++)
        FeedReply(
          id: 'r$i',
          author: FeedAuthor(id: 'u$i', name: 'Member $i', headline: 'Facility manager'),
          body: 'Comment number $i on this discussion.',
          createdAt: at,
        ),
    ],
  );

  Future<void> open(WidgetTester tester, FeedPost p) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final host = CommentsHost(
      listenable: ChangeNotifier(),
      post: () => p,
      loading: () => false,
      viewer: viewer,
      onLike: (_) async => null,
      onSend: (_, _, _) async => null,
      onMore: (_, _) {},
      now: at.add(const Duration(hours: 1)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(onPressed: () => showCommentsSheet(context, host: host), child: const Text('open')),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  double sheetHeight(WidgetTester tester) => tester.getSize(find.byKey(const ValueKey('comments-sheet'))).height;

  testWidgets('with no comments the sheet sits low, with only the room it needs', (tester) async {
    await open(tester, post(0));
    expect(find.text('No Comments Yet'), findsOneWidget);
    expect(find.text('Add a comment...'), findsOneWidget);
    expect(sheetHeight(tester), lessThan(844 * 0.45), reason: 'not the tall sheet of a long thread');
    // Its foot is the screen's foot.
    expect(tester.getBottomLeft(find.byKey(const ValueKey('comments-sheet'))).dy, 844);
  });

  testWidgets('it grows with the comments, and stops at 94% of the screen, where they scroll', (tester) async {
    await open(tester, post(2));
    final few = sheetHeight(tester);
    expect(few, lessThan(844 * 0.94));
    expect(find.text('Comment number 1 on this discussion.'), findsOneWidget);

    Navigator.of(tester.element(find.byType(CommentsSheet))).pop();
    await tester.pumpAndSettle();

    await open(tester, post(40));
    final many = sheetHeight(tester);
    expect(many, greaterThan(few));
    expect(many, moreOrLessEquals(844 * 0.94, epsilon: 1));
    // The last comment is reached by scrolling the list, and the box stays at the foot.
    expect(find.text('Comment number 39 on this discussion.'), findsNothing);
    await tester.dragUntilVisible(
      find.text('Comment number 39 on this discussion.'),
      find.byKey(const ValueKey('comments-list')),
      const Offset(0, -400),
    );
    expect(find.text('Comment number 39 on this discussion.'), findsOneWidget);
    expect(find.text('Add a comment...'), findsOneWidget);
  });

  testWidgets('a tap on the feed above the sheet closes it', (tester) async {
    await open(tester, post(0));
    expect(find.byType(CommentsSheet), findsOneWidget);
    await tester.tapAt(const Offset(195, 120));
    await tester.pumpAndSettle();
    expect(find.byType(CommentsSheet), findsNothing);
  });
}
