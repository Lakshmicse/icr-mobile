import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/feed/feed_controller.dart';
import 'package:icr_mobile/features/feed/feed_models.dart';
import 'package:icr_mobile/features/feed/home_screen.dart';
import 'package:icr_mobile/features/forum/forum_callbacks.dart';
import 'package:icr_mobile/features/forum/thread_screen.dart';
import 'package:provider/provider.dart';

import 'helpers/feed_fixtures.dart';
import 'helpers/fonts.dart';
import 'helpers/forum_fakes.dart';
import 'helpers/offline_feed.dart';

/// The Home feed and a discussion's page together: a card opens its page, and what the reader does there shows on
/// the card when they come back. The page's own controls are proved in `forum_thread_test.dart`; the Home card's in
/// `feed_screen_test.dart`.
void main() {
  setUpAll(loadAppFonts);

  var copied = '';

  setUp(() {
    copied = '';
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pumpAndSettle();
  }

  late FeedWorld world;
  late FakeForum api;
  late FeedController feed;
  final members = <String>[];
  var bells = 0;

  FeedPost post(String id) => feed.posts.firstWhere((p) => p.id == id);
  Finder key(String k) => find.byKey(ValueKey(k));

  Future<void> tapKey(WidgetTester tester, String k, {bool within = true}) async {
    await tester.ensureVisible(key(k).first);
    await tester.pumpAndSettle();
    await tester.tap(key(k).first);
    await settle(tester);
  }

  Future<void> pumpHome(WidgetTester tester, {Map<String, Handler> extra = const {}}) async {
    tester.view.physicalSize = const Size(780, 7600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    members.clear();
    bells = 0;
    world = FeedWorld();
    final mine = world.threads.firstWhere((t) => t['id'] == 'mine');
    api = FakeForum({
      ...world.routes(),
      // The reader's own discussion, as its page reads it: they may edit and delete it.
      'GET /forum/threads/slug-mine': (_) => {...mine, 'bodyHtml': '<p>Mine.</p>', 'canEdit': true},
      'GET /forum/threads/slug-mine/replies': (_) => page(const []),
      'DELETE /forum/threads/mine': (_) => {'success': true},
      'GET /forum/threads/iot/reactions': (_) => page([
        {
          'user': member('u-a', 'Anita Raghavan', headline: 'Campus FM leader'),
          'reaction': 'INSIGHTFUL',
          'reactedAt': DateTime.now().toUtc().toIso8601String(),
        },
      ]),
      'POST /forum/threads/iot/view': (_) => {'success': true},
      'POST /forum/threads/photo/view': (_) => {'success': true},
      'POST /forum/reports': (_) => {'id': 'rep'},
      ...extra,
    });
    feed = FeedController(
      OfflineFeed(
        repositoryOn(api),
        assets: const {
          'control-room.jpg': 'post_control_room.jpg',
          'green-tower.jpg': 'post_green_tower.jpg',
          'rooftop.jpg': 'post_rooftop_hvac.jpg',
        },
      ),
    );
    await tester.runAsync(() async {
      await feed.start();
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    addTearDown(feed.dispose);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: ChangeNotifierProvider.value(
          value: feed,
          child: HomeScreen(
            viewer: const FeedAuthor(id: 'me', name: 'Bharat Buyer'),
            onAccount: () {},
            callbacks: ForumCallbacks(onOpenMember: members.add, onBell: () => bells++),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  testWidgets('a card\'s title opens its discussion on its own page, and Back returns to the feed', (tester) async {
    await pumpHome(tester);
    await tapKey(tester, 'open:iot');
    expect(find.byType(ThreadScreen), findsOneWidget);
    expect(find.text('Discussion'), findsWidgets);
    expect(api.to('GET', '/forum/threads/slug-iot'), hasLength(2)); // the card's own read, then the page's
    await tester.tap(find.bySemanticsLabel('Back').first);
    await settle(tester);
    expect(find.byType(ThreadScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('what the reader does on the page shows on the card when they come back', (tester) async {
    await pumpHome(tester);
    expect(post('iot').myReaction, isNull);
    final before = post('iot').reactions;
    await tapKey(tester, 'open:iot');
    await tester.tap(key('thread-like'));
    await settle(tester);
    await tester.tap(key('thread-save'));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('Back').first);
    await settle(tester);
    expect(post('iot').myReaction, ReactionKind.like);
    expect(post('iot').reactions, before + 1);
    expect(post('iot').saved, isTrue);
  });

  testWidgets('a reply sent on the page changes the card\'s comment count', (tester) async {
    await pumpHome(tester);
    final before = post('iot').comments;
    await tapKey(tester, 'open:iot');
    await tester.enterText(key('reply-input'), 'From the page');
    await tester.pump();
    await tester.tap(key('reply-send'));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('Back').first);
    await settle(tester);
    expect(post('iot').comments, before + 1);
  });

  testWidgets('a discussion deleted from its page leaves the feed', (tester) async {
    await pumpHome(tester);
    expect(feed.posts.any((p) => p.id == 'mine'), isTrue);
    await tapKey(tester, 'open:mine');
    await tester.tap(key('thread-menu'));
    await settle(tester);
    await tester.tap(key('menu-delete'));
    await settle(tester);
    await tester.tap(key('confirm-yes'));
    await settle(tester);
    expect(find.byType(ThreadScreen), findsNothing);
    expect(feed.posts.any((p) => p.id == 'mine'), isFalse);
    expect(api.to('DELETE', '/forum/threads/mine'), hasLength(1));
  });

  testWidgets('"184 reactions" lists who reacted; holding Like offers the five reactions', (tester) async {
    await pumpHome(tester);
    await tapKey(tester, 'reactions:iot');
    expect(find.text('Reactions'), findsOneWidget);
    expect(find.text('Anita Raghavan'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tester.longPress(key('like:iot'));
    await tester.pumpAndSettle();
    await tester.tap(key('reaction:CELEBRATE'));
    await settle(tester);
    expect(post('iot').myReaction, ReactionKind.celebrate);
    expect(api.to('POST', '/forum/threads/iot/vote').last.data, {'value': 1, 'reaction': 'CELEBRATE'});
  });

  testWidgets('a card\'s three dots can report it; one\'s own has no Report', (tester) async {
    await pumpHome(tester);
    await tapKey(tester, 'more:photo');
    await tester.tap(key('menu-report'));
    await settle(tester);
    expect(find.text('Report this discussion'), findsOneWidget);
    await tester.tap(key('report-reason:ABUSE'));
    await tester.pump();
    await tester.tap(key('report-send'));
    await settle(tester);
    expect(api.bodyOf('POST', '/forum/reports'), {'threadId': 'photo', 'reason': 'ABUSE'});
    expect(
      find.descendant(of: find.byType(SnackBar), matching: find.textContaining('A moderator will take a look.')),
      findsOneWidget,
    );

    await tapKey(tester, 'more:mine');
    expect(key('menu-report'), findsNothing);
    expect(key('menu-copy'), findsOneWidget);
    expect(copied, isEmpty);
  });

  testWidgets('a card\'s photo opens its author, and so does a reply\'s; the bell goes where the app wires it', (
    tester,
  ) async {
    await pumpHome(tester);
    await tester.ensureVisible(key('author:photo'));
    await tester.tap(key('author:photo'));
    await tester.pumpAndSettle();
    expect(members, ['u-david']);
    await tester.tap(find.bySemanticsLabel(RegExp('Notifications')).first);
    await tester.pumpAndSettle();
    expect(bells, 1);
  });
}
