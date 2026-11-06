import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/core/util/links.dart' show SiteRoutes;
import 'package:icr_mobile/features/feed/feed_models.dart';
import 'package:icr_mobile/features/feed/widgets/post_card.dart';

import 'helpers/fonts.dart';

/// A web address typed into a post on the Home feed is a link (owner, 5 Nov 2026): an ICR address opens the app's own
/// screen, any other the phone's browser, a tagged name beside it still opens its profile, and "…more" never leaves a
/// half address behind it.
void main() {
  setUpAll(loadAppFonts);

  const address = 'https://icr.org.in/community/digital-library-top-stats-d6a080';
  const rahul = Mention(id: 'u-rahul', name: 'Rahul Sharma');

  final launched = <Uri>[];
  final pages = <Uri>[];
  final profiles = <String>[];

  setUp(() {
    launched.clear();
    pages.clear();
    profiles.clear();
    SiteRoutes.resolver = (uri) => uri.host == 'icr.org.in' ? (context) async => pages.add(uri) : null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      (call) async {
        if (call.method == 'launch') launched.add(Uri.parse((call.arguments as Map)['url'] as String));
        return call.method == 'launch' || call.method == 'canLaunch';
      },
    );
  });

  tearDown(() {
    SiteRoutes.resolver = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      null,
    );
  });

  FeedPost post({String title = 'A repost', required String body, List<Mention> mentions = const [], FeedPoll? poll}) =>
      FeedPost(
        id: 'p1',
        slug: 'p1',
        author: const FeedAuthor(id: 'a', name: 'Asha Rao'),
        createdAt: DateTime(2026, 11, 5),
        title: title,
        body: body,
        mentions: mentions,
        poll: poll,
      );

  Future<void> pump(WidgetTester tester, FeedPost p, {bool tagged = true}) async {
    tester.view.physicalSize = const Size(780, 1600);
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
              onOpenMention: tagged ? profiles.add : null,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('an ICR address in the words opens the app screen, the words around it do not', (tester) async {
    await pump(tester, post(body: 'Worth a read $address.'));
    await tester.tapOnText(find.textRange.ofSubstring(address));
    expect(pages.single.toString(), address);
    expect(launched, isEmpty, reason: 'an ICR page stays in the app');
    await tester.tapOnText(find.textRange.ofSubstring('Worth a read'));
    expect(pages.length, 1, reason: 'the words are not a link');
  });

  testWidgets('another site opens in the phone\'s browser', (tester) async {
    await pump(tester, post(body: 'See www.example.org/report for the figures'));
    await tester.tapOnText(find.textRange.ofSubstring('www.example.org/report'));
    expect(launched.single.toString(), 'https://www.example.org/report');
    expect(pages, isEmpty);
  });

  testWidgets('a tagged name beside an address still opens the profile', (tester) async {
    await pump(tester, post(body: '@Rahul Sharma shared $address', mentions: const [rahul]));
    await tester.tapOnText(find.textRange.ofSubstring('@Rahul Sharma'));
    expect(profiles, ['u-rahul']);
    expect(pages, isEmpty);
    await tester.tapOnText(find.textRange.ofSubstring(address));
    expect(pages.single.toString(), address);
    expect(profiles.length, 1);
  });

  testWidgets('a cut post never keeps half an address, and the full one opens once it is expanded', (tester) async {
    final long = 'x' * 40;
    final body = '${List.filled(8, 'Plenty of words before the link.').join(' ')} $long $address tail';
    await pump(tester, post(body: body));
    final cut = find.byKey(const ValueKey('post-body-more'));
    expect(cut, findsOneWidget);
    final shown = tester.widget<Text>(cut).textSpan!.toPlainText();
    expect(shown, isNot(contains('https://icr.org')), reason: 'the cut falls before the address, not inside it');

    final paragraph = tester.renderObject<RenderParagraph>(find.descendant(of: cut, matching: find.byType(RichText)));
    final at = paragraph.text.toPlainText().indexOf('…more');
    final box = paragraph.getBoxesForSelection(TextSelection(baseOffset: at, extentOffset: at + 5)).first;
    await tester.tapAt(paragraph.localToGlobal(box.toRect().center));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('post-body-open')), findsOneWidget);
    await tester.tapOnText(find.textRange.ofSubstring(address));
    expect(pages.single.toString(), address);
  });

  testWidgets('a poll\'s words and a post\'s title carry links too', (tester) async {
    await pump(
      tester,
      post(
        title: 'Read $address first',
        body: 'Background: www.example.org/poll',
        poll: const FeedPoll(
          id: 'poll',
          totalVotes: 0,
          options: [
            FeedPollOption(id: 'a', label: 'Yes', votes: 0),
            FeedPollOption(id: 'b', label: 'No', votes: 0),
          ],
        ),
      ),
    );
    await tester.tapOnText(find.textRange.ofSubstring(address));
    expect(pages.single.toString(), address);
    await tester.tapOnText(find.textRange.ofSubstring('www.example.org/poll'));
    expect(launched.single.toString(), 'https://www.example.org/poll');
  });

  testWidgets('a post with no address stays plain text', (tester) async {
    await pump(tester, post(body: 'Just words, no link here'));
    expect(find.text('Just words, no link here'), findsOneWidget);
  });
}
