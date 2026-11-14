import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/features/feed/widgets/poll_view.dart';
import 'package:icr_mobile/core/theme/app_colors.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/core/util/app_actions.dart';
import 'package:icr_mobile/features/feed/feed_controller.dart';
import 'package:icr_mobile/features/feed/feed_models.dart';
import 'package:icr_mobile/features/feed/home_screen.dart';
import 'package:icr_mobile/features/feed/widgets/comments_sheet.dart';
import 'package:icr_mobile/features/feed/widgets/composer_and_filters.dart';
import 'package:icr_mobile/features/forum/new_thread_screen.dart';
import 'package:icr_mobile/features/forum/thread_screen.dart';
import 'package:provider/provider.dart';

import 'helpers/feed_fixtures.dart';
import 'helpers/fonts.dart';
import 'helpers/offline_feed.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/auth/auth_controller.dart';
import 'package:icr_mobile/features/feed/demo_feed_repository.dart';
import 'package:icr_mobile/features/profile/profile_drawer.dart';
import 'package:icr_mobile/features/profile/profile_drawer_data.dart';
import 'package:icr_mobile/features/shell/app_shell.dart';
import 'live/live.dart' show MemoryTokens;

/// Every control of the Home feed, pressed on the real screen over the real repository, with only the forum
/// faked (`helpers/feed_fixtures.dart`) and the platform channels the screen ends in (the browser, the share
/// sheet, the clipboard) listened to. What the portal does in answer is proved by `test/live/feed_live_test.dart`.
/// The red dot on the bell.
Finder _dot() => find.byWidgetPredicate(
  (w) => w is Container && w.decoration is BoxDecoration && (w.decoration as BoxDecoration).color == AppColors.error,
);

void main() {
  setUpAll(loadAppFonts);

  /// The addresses the browser was asked to open, what the share sheet was given, and what was copied.
  final launched = <Uri>[];
  final shared = <Map<String, dynamic>>[];
  var copied = '';
  var accountTapped = 0;

  setUp(() {
    launched.clear();
    shared.clear();
    copied = '';
    accountTapped = 0;
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/url_launcher'), (call) async {
      if (call.method == 'launch') launched.add(Uri.parse((call.arguments as Map)['url'] as String));
      return call.method == 'launch' || call.method == 'canLaunch';
    });
    messenger.setMockMethodCallHandler(const MethodChannel('dev.fluttercommunity.plus/share'), (call) async {
      shared.add(Map<String, dynamic>.from(call.arguments as Map));
      return null;
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
  });

  tearDown(() {
    AppActions.openSearch = null;
    AppActions.openMessages = null;
    AppActions.composePost = null;
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/url_launcher'), null);
    messenger.setMockMethodCallHandler(const MethodChannel('dev.fluttercommunity.plus/share'), null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  /// Lets work that waits on the real event loop (the fake API's futures) finish, then draws.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pumpAndSettle();
  }

  late FeedWorld world;
  late FakeForum api;
  late FeedController feed;

  FeedPost post(String id) => feed.posts.firstWhere((p) => p.id == id);

  Future<void> pumpHome(
    WidgetTester tester, {
    FeedWorld? custom,
    Map<String, Handler> extra = const {},
    double height = 7600,
  }) async {
    tester.view.physicalSize = Size(780, height);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    world = custom ?? FeedWorld();
    api = FakeForum({...world.routes(), ...extra});
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
            onAccount: () => accountTapped++,
          ),
        ),
      ),
    );
    await settle(tester);
  }

  /// A world with two reposts at the top: one of the poll, one of the discussion with the photo.
  FeedWorld worldWithReposts() {
    final w = FeedWorld();
    w.threads.insert(
      0,
      threadCard(
        'rp-poll',
        title: 'Repost: What is your primary FM Software in 2026?',
        excerpt:
            '↻ Reposted from Author poll\n“What is your primary FM Software in 2026?”\nhttps://icr.org.in/community/slug-poll',
      ),
    );
    w.threads.insert(
      1,
      threadCard(
        'rp-photo',
        title: 'Repost: Discussion photo',
        excerpt:
            'My take first.\n↻ Reposted from Author photo\n“Discussion photo”\nhttps://icr.org.in/community/slug-photo',
      ),
    );
    return w;
  }

  /// A chip in the row that scrolls sideways (the topic chips sit past the screen's edge).
  Future<void> tapChip(WidgetTester tester, String label) async {
    final chip = find.descendant(of: find.byType(FeedFilterChips), matching: find.text(label));
    // The row builds only what it shows: slide it until the chip is there.
    for (var i = 0; i < 4 && chip.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(FeedFilterChips), const Offset(-300, 0));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await settle(tester);
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(ValueKey(key)));
    await settle(tester);
  }

  group('the header, the composer and the chips', () {
    testWidgets('the header photo opens the profile menu', (tester) async {
      await pumpHome(tester);
      await tapKey(tester, 'home-avatar');
      expect(accountTapped, 1);
    });

    testWidgets('the bell opens the notifications page, and its dot is the unread count', (tester) async {
      await pumpHome(tester);
      expect(api.calls, contains('GET /notifications/unread-count'));
      expect(feed.unread, 3);
      expect(_dot(), findsOneWidget);
      await tapKey(tester, 'home-bell');
      expect(launched.single.path, '/notifications');
    });

    testWidgets('without unread notifications the bell has no dot', (tester) async {
      final quiet = FeedWorld()..unread = 0;
      await pumpHome(tester, custom: quiet);
      expect(feed.unread, 0);
      expect(_dot(), findsNothing);
    });

    testWidgets(
      'the header\'s + opens the composer in the app, not the website; there is no second "Start a post" card',
      (tester) async {
        await pumpHome(tester);
        expect(
          find.byKey(const ValueKey('home-composer')),
          findsNothing,
          reason: 'the + is the one way to start a post',
        );
        expect(find.text('Start a post'), findsNothing);
        await tapKey(tester, 'home-compose');
        expect(find.byType(NewThreadScreen), findsOneWidget);
        expect(find.text('New Discussion'), findsOneWidget);
        expect(launched, isEmpty);
      },
    );

    group('"…more" on the words of a post', () {
      Finder card() => find.byKey(const ValueKey('iot'));
      Finder cut() => find.descendant(of: card(), matching: find.byKey(const ValueKey('post-body-more')));

      testWidgets('opens the rest in the feed itself, without leaving it', (tester) async {
        await pumpHome(tester);
        expect(cut(), findsOneWidget, reason: 'a long post is cut at three lines');
        // Where the "…more" words sit in the paragraph.
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: cut(), matching: find.byType(RichText)),
        );
        final at = paragraph.text.toPlainText().indexOf('…more');
        final box = paragraph.getBoxesForSelection(TextSelection(baseOffset: at, extentOffset: at + 5)).first;
        await tester.tapAt(paragraph.localToGlobal(box.toRect().center));
        await settle(tester);
        expect(cut(), findsNothing);
        expect(find.descendant(of: card(), matching: find.byKey(const ValueKey('post-body-open'))), findsOneWidget);
        expect(find.byType(ThreadScreen), findsNothing, reason: '"…more" does not open the discussion page');
      });

      testWidgets('the words themselves still open the detailed view', (tester) async {
        await pumpHome(tester);
        final r = tester.getRect(cut());
        await tester.tapAt(Offset(r.left + 30, r.top + 9)); // on the first line's words
        await settle(tester);
        expect(find.byType(ThreadScreen), findsOneWidget);
      });
    });

    group('Repost', () {
      testWidgets('a repost draws the original inside it — its poll, its photo — and not the quote\'s link', (
        tester,
      ) async {
        await pumpHome(tester, custom: worldWithReposts());
        // The poll's repost: the original's poll inside, the link line gone.
        expect(find.byKey(const ValueKey('quoted:slug-poll')), findsOneWidget);
        expect(find.textContaining('icr.org.in/community/slug-poll'), findsNothing);
        expect(find.byType(PollView), findsNWidgets(2), reason: 'the original and its repost both show the poll');
        // The photo's repost keeps the reposter's own words and shows the original with its photo.
        expect(find.byKey(const ValueKey('quoted:slug-photo')), findsOneWidget);
        expect(find.text('My take first.'), findsOneWidget);
        expect(find.textContaining('icr.org.in/community/slug-photo'), findsNothing);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('quoted:slug-photo')),
            matching: find.text('The impact of AI on preliminary site feasibility analysis'),
          ),
          findsOneWidget,
          reason: "the original's own title, not the quote's",
        );
      });

      Map<String, Handler> createRoute({String moderation = 'APPROVED'}) => {
        'POST /forum/threads': (o) => {
          ...threadCard('new', title: (o.data as Map)['title'] as String, author: member('me', 'Bharat Buyer')),
          'slug': 'slug-new',
          'bodyHtml': (o.data as Map)['bodyHtml'],
          'moderation': moderation,
          'canEdit': true,
        },
      };

      testWidgets('offers a repost with your thoughts or as it stands, instead of "not available"', (tester) async {
        await pumpHome(tester);
        await tapKey(tester, 'repost:iot');
        expect(find.text('Repost with Your Thoughts'), findsOneWidget);
        expect(find.text('Share this post to your feed immediately.'), findsOneWidget);
        expect(find.textContaining("isn't available"), findsNothing);
      });

      testWidgets('"Repost with Your Thoughts" opens the composer with the quote already in it', (tester) async {
        await pumpHome(tester, extra: createRoute());
        await tapKey(tester, 'repost:iot');
        await tapKey(tester, 'repost-thoughts');
        expect(find.byType(NewThreadScreen), findsOneWidget);
        expect(find.textContaining('Repost: Implementing IoT sensors'), findsOneWidget);
        expect(find.textContaining('Reposted from Sarah Jenkins'), findsOneWidget);
        expect(api.to('POST', '/forum/threads'), isEmpty, reason: 'nothing is filed until the reader posts');
      });

      testWidgets('"Repost" files the quote under the original\'s topic, with its tags, and reads the feed again', (
        tester,
      ) async {
        await pumpHome(tester, extra: createRoute());
        final before = api.to('GET', '/forum/threads').length;
        await tapKey(tester, 'repost:iot');
        await tapKey(tester, 'repost-instant');

        final posted = api.to('POST', '/forum/threads').single.data as Map;
        expect(posted['title'], startsWith('Repost: Implementing IoT sensors'));
        expect(posted['topicCategory'], 'SUSTAINABILITY_ESG');
        expect(posted['topicSubcategory'], 'S_iot');
        expect(posted['bodyHtml'], contains('Reposted from Sarah Jenkins'));
        expect(posted['bodyHtml'], contains('/community/'), reason: 'it links to the original');
        expect(posted['tags'], containsAll(['hvac', 'proptech', 'smartbms']));
        expect(find.text('Reposted to your feed.'), findsOneWidget);
        expect(api.to('GET', '/forum/threads').length, greaterThan(before), reason: 'the feed reads again');
        expect(launched, isEmpty);
      });

      testWidgets('a post held for a moderator says so', (tester) async {
        await pumpHome(tester, extra: createRoute(moderation: 'PENDING'));
        await tapKey(tester, 'repost:iot');
        await tapKey(tester, 'repost-instant');
        expect(find.textContaining('A moderator will review it'), findsOneWidget);
      });

      testWidgets('a refusal from the forum is shown, not swallowed', (tester) async {
        await pumpHome(
          tester,
          extra: {
            'POST /forum/threads': (_) =>
                (400, '{"statusCode":400,"message":"You have reached your daily posting limit."}'),
          },
        );
        await tapKey(tester, 'repost:iot');
        await tapKey(tester, 'repost-instant');
        expect(find.text('You have reached your daily posting limit.'), findsOneWidget);
      });
    });

    testWidgets('the search field is a button that opens the global search, and Messages opens the inbox', (
      tester,
    ) async {
      var searched = 0;
      var messaged = 0;
      AppActions.openSearch = (context, {query}) async => searched++;
      AppActions.openMessages = (context) async => messaged++;
      await pumpHome(tester);
      expect(
        find.descendant(of: find.byKey(const ValueKey('home-search')), matching: find.byType(TextField)),
        findsNothing,
        reason: 'nothing is typed into the header any more',
      );
      expect(find.text('Search'), findsOneWidget);
      await tapKey(tester, 'home-search');
      expect(searched, 1);
      await tapKey(tester, 'home-messages');
      expect(messaged, 1);
      // The feed was not asked to search: the global search screen does that.
      expect(api.to('GET', '/forum/threads').last.queryParameters.containsKey('search'), isFalse);
    });

    testWidgets('the "+" in the header starts a post, as the composer card does', (tester) async {
      await pumpHome(tester);
      await tapKey(tester, 'home-compose');
      expect(find.byType(NewThreadScreen), findsOneWidget);
      expect(launched, isEmpty);
    });

    testWidgets('each chip asks the forum for what it names', (tester) async {
      await pumpHome(tester);
      Map<String, dynamic> lastQuery() => api.to('GET', '/forum/threads').last.queryParameters;

      // The chips scroll sideways (LinkedIn's size no longer fits five in 390): bring the one named into view.
      Future<void> tapChip(String label) async {
        final row = find.descendant(of: find.byType(FeedFilterChips), matching: find.byType(Scrollable)).first;
        if (find.text(label).hitTestable().evaluate().isEmpty) {
          await tester.drag(row, const Offset(600, 0));
          await settle(tester);
          await tester.scrollUntilVisible(find.text(label), 60, scrollable: row);
          await settle(tester);
        }
        await tester.tap(find.text(label));
      }

      await tapChip('Trending Discussions');
      await settle(tester);
      expect(lastQuery()['sort'], 'top');
      expect(feed.filter, FeedFilter.trending);
      expect(feed.posts.first.id, 'iot', reason: 'the most reacted first');

      await tapChip('Unanswered');
      await settle(tester);
      expect(lastQuery()['sort'], 'unanswered');
      expect(feed.posts.map((p) => p.id), ['mine', 'unanswered']);

      await tapChip('Polls');
      await settle(tester);
      // The forum has no polls filter: the latest 100 are read and the ones with a poll kept.
      expect(lastQuery()['limit'], 100);
      expect(feed.posts.map((p) => p.id), ['poll']);

      await tapChip('Following');
      await settle(tester);
      expect(feed.posts.map((p) => p.id), ['unanswered'], reason: 'only the author the reader follows');
      expect(feed.posts.single.showFollow, isFalse);

      await tapChip('All Feed');
      await settle(tester);
      expect(lastQuery()['sort'], 'newest');
      expect(feed.posts, hasLength(6));
    });

    testWidgets('Following with nobody followed says so', (tester) async {
      final lonely = FeedWorld()..following = [];
      await pumpHome(tester, custom: lonely);
      await tester.tap(find.text('Following'));
      await settle(tester);
      expect(feed.posts, isEmpty);
      expect(find.text('No Posts from People You Follow Yet'), findsOneWidget);
      expect(find.text('Follow members from their posts to see what they share here.'), findsOneWidget);
    });

    testWidgets('the topic chips are the tags the discussions carry, most used first, never a fixed list', (
      tester,
    ) async {
      await pumpHome(tester);
      expect(feed.topics.map((t) => t.tag), ['AMC', 'HVAC', 'PropTech', 'SmartBMS']);
      expect(feed.topics.length, lessThanOrEqualTo(FeedController.maxTopics));
      // The row scrolls sideways and builds what it shows: slide to the topic chips.
      await tester.drag(find.byType(FeedFilterChips), const Offset(-900, 0));
      await tester.pumpAndSettle();
      final chips = find.descendant(of: find.byType(FeedFilterChips), matching: find.textContaining('#'));
      expect(chips, findsWidgets);
      expect(find.text('#ESG'), findsNothing, reason: 'no discussion carries it');
    });

    testWidgets('a topic chip loads that tag, and tapping it again goes back to All Feed', (tester) async {
      await pumpHome(tester);
      await tapChip(tester, '#HVAC');
      expect(api.to('GET', '/forum/threads').last.queryParameters['tag'], 'HVAC');
      expect(feed.posts.map((p) => p.id), ['iot']);
      expect(feed.tag, 'HVAC');

      await tapChip(tester, '#HVAC');
      expect(feed.tag, isNull);
      expect(feed.posts, hasLength(6));

      // A tag nobody carries: the controller still filters by it, and shows it as the chip in use so it can be turned off.
      await tester.runAsync(() => feed.setTag('ESG'));
      await settle(tester);
      expect(api.to('GET', '/forum/threads').last.queryParameters['tag'], 'ESG');
      expect(feed.posts, isEmpty);
      expect(feed.topics.first.tag, 'ESG');
      expect(find.text('No Discussions Tagged #ESG Yet'), findsOneWidget);
    });
  });

  group('a post and its actions', () {
    testWidgets("a card shows the forum's reactions, comments, views, topic and tags as the design draws them", (
      tester,
    ) async {
      await pumpHome(tester);
      final iot = post('iot');
      expect(iot.reactions, 184);
      expect(iot.reactionKinds, [ReactionKind.like, ReactionKind.insightful, ReactionKind.celebrate]);
      // LinkedIn's one row: each count sits beside its glyph (the API counts no shares, so Repost has none).
      expect(find.descendant(of: find.byKey(const ValueKey('like:iot')), matching: find.text('184')), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(const ValueKey('comments:iot')), matching: find.text('12')),
        findsOneWidget,
      );
      expect(find.descendant(of: find.byKey(const ValueKey('repost:iot')), matching: find.byType(Text)), findsNothing);
      expect(find.textContaining('views'), findsNothing);
      expect(find.textContaining('Sustainability', findRichText: true), findsWidgets);
      expect(
        find.textContaining('#SUSTAINABILITY', findRichText: true),
        findsNothing,
        reason: 'a label, not a hashtag',
      );
      expect(iot.topicTone, TopicTone.green);
      expect(post('photo').topic, 'Real Estate Tech');
      expect(post('photo').topicTone, TopicTone.blue);
      expect(post('poll').topic, 'Poll');
      expect(find.text('#SmartBMS'), findsOneWidget);
      expect(find.text('Senior Facilities Manager at Google'), findsOneWidget);
    });

    testWidgets('the card reads the whole discussion: its text, its photo and a caption from the file name', (
      tester,
    ) async {
      await pumpHome(tester);
      // The list's excerpt was cut at 220 characters; the discussion's own page has the rest.
      expect(post('iot').body, contains('Has anyone integrated with legacy BMS?'));
      expect(post('iot').detailLoaded, isTrue);
      expect(api.to('GET', '/forum/threads/slug-iot'), hasLength(1));
      // One photo: its file name is the caption.
      expect(post('photo').images, hasLength(1));
      expect(post('photo').imageCaption, 'BIM Feasibility Lab');
      expect(find.text('BIM Feasibility Lab'), findsOneWidget);
      // Five photos: the attachment and four images in the body; two drawn, three counted.
      expect(post('audit').images, hasLength(2));
      expect(post('audit').morePhotos, 3);
      expect(post('audit').imageCaption, isNull);
      expect(find.text('+3 photos'), findsOneWidget);
    });

    testWidgets("Like reacts at once, again takes it back, and the reader's own post is liked like any other", (
      tester,
    ) async {
      await pumpHome(tester);
      expect(post('photo').reactions, 20);
      await tapKey(tester, 'like:photo');
      expect(api.to('POST', '/forum/threads/photo/vote').single.data, {'value': 1, 'reaction': 'LIKE'});
      expect(post('photo').myReaction, ReactionKind.like);
      expect(post('photo').reactions, 21);
      expect(find.descendant(of: find.byKey(const ValueKey('like:photo')), matching: find.text('21')), findsOneWidget);

      await tapKey(tester, 'like:photo');
      expect(api.to('DELETE', '/forum/threads/photo/vote'), hasLength(1));
      expect(post('photo').myReaction, isNull);
      expect(post('photo').reactions, 20);

      // A member may like their own post (owner, 7 Nov 2026: "remove this restriction"); the API allows it.
      await tapKey(tester, 'like:mine');
      expect(find.text('You cannot react to your own post.'), findsNothing);
      expect(api.to('POST', '/forum/threads/mine/vote').single.data, {'value': 1, 'reaction': 'LIKE'});
      expect(post('mine').myReaction, ReactionKind.like);
      expect(post('mine').reactions, 1);
    });

    testWidgets('the votes count opens who voted, with the option each person picked', (tester) async {
      await pumpHome(
        tester,
        extra: {
          'GET /forum/threads/poll/poll/voters': (_) => (
            200,
            '{"data":[{"user":{"id":"u-priya","firstName":"Priya","lastName":"Nambiar","headline":"FM Lead"},'
                '"optionId":"o3","votedAt":"2026-10-30T10:00:00Z"},'
                '{"user":{"id":"u-arvind","firstName":"Arvind","lastName":"Swamy"},"optionId":"o1",'
                '"votedAt":"2026-10-29T10:00:00Z"}],"meta":{"total":2}}',
          ),
        },
      );
      await tapKey(tester, 'poll-voters');
      await tester.pumpAndSettle();
      expect(find.text('Votes'), findsOneWidget);
      expect(find.text('Priya Nambiar'), findsOneWidget);
      expect(find.text('Arvind Swamy'), findsWidgets, reason: 'in the sheet (and as a reply author on the feed)');
      // The option each picked, under the name (the bars carry the same words, so more than one).
      expect(find.text('Archibus'), findsWidgets);
      expect(find.text('IBM TRIRIGA'), findsWidgets);
      expect(api.to('GET', '/forum/threads/poll/poll/voters'), hasLength(1));
    });

    testWidgets("someone who has not voted reads the API's sentence instead of the list", (tester) async {
      await pumpHome(
        tester,
        extra: {
          'GET /forum/threads/poll/poll/voters': (_) =>
              (403, '{"statusCode":403,"message":"Vote in the poll to see who voted."}'),
        },
      );
      await tapKey(tester, 'poll-voters');
      await tester.pumpAndSettle();
      expect(find.text('Vote in the poll to see who voted.'), findsOneWidget);
    });

    testWidgets('the bookmark saves and unsaves, and a refusal leaves it as it was', (tester) async {
      await pumpHome(
        tester,
        extra: {'POST /forum/threads/audit/save': (_) => (503, '{"statusCode":503,"message":"Saving is paused."}')},
      );
      expect(post('photo').saved, isFalse);
      await tapKey(tester, 'save:photo');
      expect(api.to('POST', '/forum/threads/photo/save'), hasLength(1));
      expect(post('photo').saved, isTrue);

      await tapKey(tester, 'save:photo');
      expect(api.to('DELETE', '/forum/threads/photo/save'), hasLength(1));
      expect(post('photo').saved, isFalse);

      await tapKey(tester, 'save:audit');
      expect(find.text('Saving is paused.'), findsOneWidget);
      expect(post('audit').saved, isFalse);
    });

    testWidgets('Follow follows the author and goes away; a followed author shows none; a refusal keeps it', (
      tester,
    ) async {
      await pumpHome(
        tester,
        extra: {'POST /members/u-david/follow': (_) => (404, '{"statusCode":404,"message":"Member not found"}')},
      );
      // Sarah and David are not followed; Fatima (the reader follows her) and the reader's own post show none.
      expect(find.byKey(const ValueKey('follow:iot')), findsOneWidget);
      expect(find.byKey(const ValueKey('follow:photo')), findsOneWidget);
      expect(find.byKey(const ValueKey('follow:unanswered')), findsNothing);
      expect(find.byKey(const ValueKey('follow:mine')), findsNothing);

      await tapKey(tester, 'follow:iot');
      expect(api.to('POST', '/members/u-sarah/follow'), hasLength(1));
      expect(find.byKey(const ValueKey('follow:iot')), findsNothing);
      expect(post('iot').showFollow, isFalse);

      await tapKey(tester, 'follow:photo');
      expect(find.text('Member not found'), findsOneWidget);
      expect(find.byKey(const ValueKey('follow:photo')), findsOneWidget);
    });

    testWidgets(
      'the repost glyph asks how to repost and files nothing by itself, and Share hands the discussion to the share sheet',
      (tester) async {
        await pumpHome(tester);
        final calls = api.calls.length;
        await tapKey(tester, 'repost:iot');
        expect(find.text('Repost with Your Thoughts'), findsOneWidget);
        expect(api.calls.length, calls, reason: 'asking how to repost asks the forum for nothing');
        await tester.tapAt(const Offset(10, 10)); // the scrim
        await settle(tester);
        expect(find.text('Repost with Your Thoughts'), findsNothing);

        await tapKey(tester, 'share:iot');
        expect(shared.single['text'], contains('Implementing IoT sensors for HVAC efficiency: Best practices?'));
        expect(shared.single['text'], endsWith('https://icr.org.in/community/slug-iot'));
        expect(shared.single['subject'], 'Implementing IoT sensors for HVAC efficiency: Best practices?');
      },
    );

    testWidgets("the three dots copy the discussion's link or open the discussion", (tester) async {
      await pumpHome(tester);
      await tapKey(tester, 'more:photo');
      expect(find.text('Copy Link'), findsOneWidget);
      await tester.tap(find.text('Copy Link'));
      await settle(tester);
      expect(copied, 'https://icr.org.in/community/slug-photo');
      expect(find.text('Link copied.'), findsOneWidget);

      // The discussion opens in the app, on its own page; nothing is handed to the browser.
      await tapKey(tester, 'more:photo');
      await tester.tap(find.text('Open Discussion'));
      await settle(tester);
      expect(find.byType(ThreadScreen), findsOneWidget);
      expect(find.text('The impact of AI on preliminary site feasibility analysis'), findsWidgets);
      expect(launched, isEmpty);
    });

    testWidgets('the speech bubble and the comment count open the comments in a sheet over the feed', (tester) async {
      // Owner, 13 Nov 2026: comments as LinkedIn shows them, in a sheet, never inside the card.
      await pumpHome(tester);
      expect(find.text('The data gap is real.'), findsNothing);
      await tapKey(tester, 'comments:photo');
      expect(find.byType(CommentsSheet), findsOneWidget);
      expect(api.to('GET', '/forum/threads/slug-photo/replies'), hasLength(1));
      expect(find.text('The data gap is real.'), findsOneWidget);
      expect(find.text('Most Relevant'), findsOneWidget);
      expect(find.text('Add a comment...'), findsOneWidget);

      // Leaving the sheet leaves the feed as it was: nothing stays open inside the card.
      Navigator.of(tester.element(find.byType(CommentsSheet))).pop();
      await settle(tester);
      expect(find.byType(CommentsSheet), findsNothing);
      expect(find.text('The data gap is real.'), findsNothing);

      // The count beside the bubble is part of the same button.
      await tester.tap(find.descendant(of: find.byKey(const ValueKey('comments:photo')), matching: find.text('5')));
      await settle(tester);
      expect(find.byType(CommentsSheet), findsOneWidget);
      expect(find.text('The data gap is real.'), findsOneWidget);
    });

    testWidgets("the first post's comments are read ahead, and show only once its sheet is opened", (tester) async {
      await pumpHome(tester);
      expect(api.to('GET', '/forum/threads/slug-iot/replies'), hasLength(1));
      expect(find.byType(CommentsSheet), findsNothing);
      expect(find.textContaining('Spot on Priya. Niagara framework'), findsNothing);

      await tapKey(tester, 'comments:iot');
      expect(find.textContaining('Spot on Priya. Niagara framework'), findsOneWidget);
      // Every answer is there, one step in under its comment: no "+8 replies in this thread" to open.
      expect(find.textContaining('Spot on Priya.'), findsWidgets);
      expect(find.textContaining('replies in this thread'), findsNothing);
      expect(find.textContaining('Great tips everyone.'), findsOneWidget);
    });

    testWidgets("a feed whose first post is a poll opens nothing by itself", (tester) async {
      final polls = FeedWorld();
      polls.threads = [
        for (final t in polls.threads)
          if (t['id'] == 'poll') t,
      ];
      await pumpHome(tester, custom: polls);
      expect(feed.posts.single.id, 'poll');
      expect(feed.isOpen(post('poll')), isFalse);
    });
  });

  group('a poll', () {
    testWidgets("it shows its bars, the reader's vote and what it knows of its end; an option moves the vote", (
      tester,
    ) async {
      final moves = FeedWorld().routes()['POST /forum/threads/poll/poll/vote']!;
      await pumpHome(
        tester,
        extra: {
          // The forum refuses a vote for the last option, as it would on a poll that closed meanwhile.
          'POST /forum/threads/poll/poll/vote': (o) => (o.data as Map)['optionId'] == 'o4'
              ? (400, '{"message":"This discussion and its poll are closed."}')
              : moves(o),
        },
      );
      expect(post('poll').poll!.percents, [28, 14, 46, 12]);
      expect(find.text('Archibus (Your vote)'), findsOneWidget);
      expect(find.text('46%'), findsOneWidget);
      // The forum gives a poll no closing date, so the footer says it is open.
      expect(find.text('190 votes • Open'), findsOneWidget);

      await tapKey(tester, 'poll-option:o2');
      expect(api.to('POST', '/forum/threads/poll/poll/vote').single.data, {'optionId': 'o2'});
      expect(find.text('Planon (Your vote)'), findsOneWidget);
      expect(find.text('Archibus (Your vote)'), findsNothing);
      expect(post('poll').poll!.myOptionId, 'o2');
      expect(find.text('190 votes • Open'), findsOneWidget);

      // The option already chosen asks nothing.
      await tapKey(tester, 'poll-option:o2');
      expect(api.to('POST', '/forum/threads/poll/poll/vote'), hasLength(1));

      // A refusal leaves the vote where it was, and says why.
      await tapKey(tester, 'poll-option:o4');
      expect(find.text('This discussion and its poll are closed.'), findsOneWidget);
      expect(post('poll').poll!.myOptionId, 'o2');
    });

    testWidgets('a closed poll takes no vote and says Closed', (tester) async {
      final closed = FeedWorld();
      closed.threads = [
        for (final t in closed.threads)
          if (t['id'] == 'poll') {...t, 'status': 'LOCKED'},
      ];
      await pumpHome(tester, custom: closed);
      expect(find.text('190 votes • Closed'), findsOneWidget);
      await tapKey(tester, 'poll-option:o1');
      expect(api.to('POST', '/forum/threads/poll/poll/vote'), isEmpty);
      expect(post('poll').poll!.myOptionId, 'o3');
    });

    testWidgets("View Discussion opens the poll's discussion on its own page", (tester) async {
      await pumpHome(tester);
      await tapKey(tester, 'view-discussion');
      expect(find.byType(ThreadScreen), findsOneWidget);
      expect(api.to('GET', '/forum/threads/slug-poll/replies'), hasLength(1));
      expect(find.text('What is your primary FM Software in 2026?'), findsWidgets);
    });
  });

  group('the replies', () {
    Future<void> typeAndSend(WidgetTester tester, String text) async {
      await tester.ensureVisible(find.byKey(const ValueKey('reply-input')));
      await tester.enterText(find.byKey(const ValueKey('reply-input')), text);
      await tester.pump();
      await tapKey(tester, 'reply-send');
    }

    testWidgets('the box adds a comment to the post itself, and the comment sent shows at once', (tester) async {
      await pumpHome(tester);
      await tapKey(tester, 'comments:iot');
      expect(find.text('Add a comment...'), findsOneWidget);
      final reads = api.to('GET', '/forum/threads/slug-iot/replies').length;

      await typeAndSend(tester, 'Thanks all, very helpful.');
      final sent = api.to('POST', '/forum/threads/iot/replies').single.data as Map;
      expect(sent['bodyHtml'], '<p>Thanks all, very helpful.</p>');
      expect(sent['parentId'], isNull, reason: 'a comment on the post, as LinkedIn\'s box');
      expect(post('iot').comments, 13);
      expect(
        find.descendant(of: find.byKey(const ValueKey('comments:iot')), matching: find.text('13')),
        findsOneWidget,
      );
      // The comments were read again, so the new one is there to see.
      expect(api.to('GET', '/forum/threads/slug-iot/replies'), hasLength(reads + 1));
      expect(find.textContaining('replies in this thread'), findsNothing);
      expect(tester.widget<TextField>(find.byKey(const ValueKey('reply-input'))).controller!.text, isEmpty);
    });

    testWidgets('Reply on a reply addresses that person and sends under that reply', (tester) async {
      await pumpHome(tester);
      await tapKey(tester, 'comments:iot');
      await tapKey(tester, 'reply-reply:r1');
      expect(find.text('Reply to Arvind Swamy...'), findsOneWidget);
      expect(find.text('Replying to Arvind Swamy'), findsOneWidget);
      await typeAndSend(tester, 'Which supervisor version?');
      expect((api.to('POST', '/forum/threads/iot/replies').single.data as Map)['parentId'], 'r1');
      // Back to a comment on the post afterwards.
      expect(find.text('Add a comment...'), findsOneWidget);
      expect(find.text('Replying to Arvind Swamy'), findsNothing);
    });

    testWidgets('a reply is plain text: markup is escaped and line breaks are kept; an empty box sends nothing', (
      tester,
    ) async {
      await pumpHome(tester);
      await tapKey(tester, 'comments:iot');
      await typeAndSend(tester, '   ');
      expect(api.to('POST', '/forum/threads/iot/replies'), isEmpty);

      await typeAndSend(tester, 'Use <b>BACnet</b> & Niagara\nsecond line');
      expect(
        (api.to('POST', '/forum/threads/iot/replies').single.data as Map)['bodyHtml'],
        '<p>Use &lt;b&gt;BACnet&lt;/b&gt; &amp; Niagara<br>second line</p>',
      );
    });

    testWidgets("a refused reply keeps what was typed and says why", (tester) async {
      await pumpHome(
        tester,
        extra: {
          'POST /forum/threads/iot/replies': (_) =>
              (403, '{"statusCode":403,"message":"This discussion is locked and does not accept new replies."}'),
        },
      );
      await tapKey(tester, 'comments:iot');
      await typeAndSend(tester, 'Anyone there?');
      expect(find.text('This discussion is locked and does not accept new replies.'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const ValueKey('reply-input'))).controller!.text, 'Anyone there?');
      expect(post('iot').comments, 12);
    });

    testWidgets('a reply is liked and unliked, and a refusal puts the count back', (tester) async {
      await pumpHome(
        tester,
        extra: {'POST /forum/replies/r2/vote': (_) => (400, '{"message":"You cannot vote on your own reply."}')},
      );
      Finder count(String id, String text) =>
          find.descendant(of: find.byKey(ValueKey('reply-like:$id')), matching: find.text(text));
      await tapKey(tester, 'comments:iot');
      expect(count('r1', '3'), findsOneWidget);
      await tapKey(tester, 'reply-like:r1');
      expect(api.to('POST', '/forum/replies/r1/vote').single.data, {'value': 1, 'reaction': 'LIKE'});
      expect(count('r1', '4'), findsOneWidget);

      await tapKey(tester, 'reply-like:r1');
      expect(api.to('DELETE', '/forum/replies/r1/vote'), hasLength(1));
      expect(count('r1', '3'), findsOneWidget);

      await tapKey(tester, 'reply-like:r2');
      expect(find.text('You cannot vote on your own reply.'), findsOneWidget);
      expect(count('r2', '3'), findsOneWidget);
    });

    testWidgets('the sheet shows the whole discussion, and its order can be switched', (tester) async {
      await pumpHome(tester);
      await tapKey(tester, 'comments:iot');
      expect(find.textContaining('Answer 3'), findsOneWidget);
      expect(find.textContaining('Pilot on one floor first.'), findsOneWidget, reason: 'the other threads too');
      expect(find.textContaining('replies in this thread'), findsNothing);

      await tapKey(tester, 'comments-sort');
      await tester.tap(find.text('Most Recent').last);
      await settle(tester);
      expect(find.text('Most Recent'), findsOneWidget);
      expect(find.textContaining('Pilot on one floor first.'), findsOneWidget);
    });

    testWidgets(
      "a reply's three dots copy its link or open the discussion at it, and offer Delete on the reader's own only",
      (tester) async {
        await pumpHome(tester);
        await tapKey(tester, 'comments:iot');
        await tapKey(tester, 'reply-more:r1');
        expect(find.text('Delete Reply'), findsNothing, reason: "Arvind's reply is not the reader's");
        expect(find.text('Report'), findsOneWidget);
        await tester.tap(find.text('Copy Link'));
        await settle(tester);
        expect(copied, 'https://icr.org.in/community/slug-iot#reply-r1');
        expect(find.text('Link copied.'), findsOneWidget);

        await tapKey(tester, 'reply-more:r1');
        await tester.tap(find.text('Open Discussion'));
        await settle(tester);
        expect(find.byType(ThreadScreen), findsOneWidget);
        expect(find.byType(CommentsSheet), findsNothing, reason: 'the sheet goes, so the page is not under it');
        expect(launched, isEmpty);
      },
    );

    testWidgets('the reader can take back their own reply after confirming, and not by accident', (tester) async {
      await pumpHome(tester);
      await tapKey(tester, 'comments:audit');
      expect(find.textContaining('Great photos.'), findsOneWidget);
      expect(post('audit').comments, 2);

      await tapKey(tester, 'reply-more:a2');
      expect(find.text('Delete Reply'), findsOneWidget);
      await tester.tap(find.text('Delete Reply'));
      await settle(tester);
      expect(find.text('Delete Your Reply?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(api.to('DELETE', '/forum/replies/a2'), isEmpty);

      await tapKey(tester, 'reply-more:a2');
      await tester.tap(find.text('Delete Reply'));
      await settle(tester);
      await tester.tap(find.text('Delete'));
      await settle(tester);
      expect(api.to('DELETE', '/forum/replies/a2'), hasLength(1));
      expect(post('audit').comments, 1);
    });
  });

  group('refreshing, paging and the states', () {
    testWidgets('pulling down reads the forum, the bell and the discussions again', (tester) async {
      // A short screen: the indicator arms after a quarter of the screen's height.
      await pumpHome(tester, height: 2400);
      expect(api.to('GET', '/forum/threads'), hasLength(1));
      expect(api.to('GET', '/forum/threads/slug-iot'), hasLength(1));
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 600));
      await settle(tester);
      expect(api.to('GET', '/forum/threads'), hasLength(2));
      expect(api.to('GET', '/notifications/unread-count'), hasLength(2));
      expect(
        api.to('GET', '/forum/threads/slug-iot'),
        hasLength(2),
        reason: 'the full texts and photos are read again',
      );
    });

    testWidgets("scrolling to the end reads the next page, and the end says you're all caught up", (tester) async {
      final many = FeedWorld();
      many.threads = [
        for (var i = 0; i < 25; i++) threadCard('t$i', title: 'Discussion number $i', excerpt: 'Body $i.'),
      ];
      many.replies = {};
      many.details = {};
      await pumpHome(tester, custom: many, height: 3000);
      expect(feed.posts, hasLength(20));
      expect(feed.hasMore, isTrue);
      for (var i = 0; i < 10 && feed.posts.length < 25; i++) {
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -1500));
        await settle(tester);
      }
      expect(api.to('GET', '/forum/threads').last.queryParameters['page'], 2);
      expect(feed.posts, hasLength(25));
      expect(feed.hasMore, isFalse);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -6000));
      await settle(tester);
      expect(find.text("No more discussions."), findsOneWidget);
    });

    testWidgets('no sponsored placement sits between the posts (owner, 6 Nov 2026)', (tester) async {
      await pumpHome(tester);
      expect(find.text('SPONSORED PARTNER'), findsNothing);
      expect(find.text('Learn More'), findsNothing);
    });

    testWidgets('a failed read says so, and Try again reads again', (tester) async {
      var failing = true;
      final ok = FeedWorld().routes()['GET /forum/threads']!;
      await pumpHome(
        tester,
        extra: {
          'GET /forum/threads': (o) => failing ? (500, '{"statusCode":500,"message":"The forum is down."}') : ok(o),
        },
      );
      expect(find.text("Unable to Load the Feed"), findsOneWidget);
      expect(find.text('The forum is down.'), findsOneWidget);
      failing = false;
      await tester.tap(find.text('Try Again'));
      await settle(tester);
      expect(find.text("Unable to Load the Feed"), findsNothing);
      expect(feed.posts, hasLength(6));
    });

    testWidgets('an empty chip says what it is waiting for', (tester) async {
      final answered = FeedWorld();
      answered.threads = [
        for (final t in answered.threads)
          if (t['replyCount'] != 0 || t['kind'] != 'QUESTION') t,
      ];
      await pumpHome(tester, custom: answered);
      await tester.tap(find.text('Unanswered'));
      await settle(tester);
      expect(find.text('No Unanswered Questions'), findsOneWidget);
      expect(find.text('New questions without replies will appear here.'), findsOneWidget);

      await tester.tap(find.text('All Feed'));
      await settle(tester);
      expect(feed.posts, isNotEmpty);
    });
  });

  group('inside the shell', () {
    testWidgets(
      'the header photo opens the real profile menu over the feed; Back closes it and the feed is as it was',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.75;
        addTearDown(tester.view.reset);
        final tokens = MemoryTokens();
        final auth = AuthController(
          api: ApiClient(tokens: tokens),
          tokens: tokens,
        );
        final demo = FeedController(DemoFeedRepository());
        await tester.runAsync(demo.start);
        addTearDown(demo.dispose);
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: auth),
              ChangeNotifierProvider(create: (_) => ProfileDrawerController.demo()),
              ChangeNotifierProvider.value(value: demo),
            ],
            child: MaterialApp(
              theme: buildAppTheme(),
              home: AppShell(
                drawer: const ProfileDrawer(),
                home: Builder(
                  builder: (ctx) =>
                      HomeScreen(viewer: DemoFeedRepository.me, onAccount: () => AppShell.openDrawer(ctx)),
                ),
              ),
            ),
          ),
        );
        await settle(tester);
        expect(find.text('MY ACTIVITY'), findsNothing);

        await tapKey(tester, 'home-avatar');
        expect(find.text('MY ACTIVITY'), findsOneWidget, reason: 'the menu is open');
        expect(find.text('Nikhil Majjagi'), findsOneWidget);
        expect(find.text('View Full Profile'), findsNothing, reason: 'the photo and name are the way to the profile');

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('MY ACTIVITY'), findsNothing);
        expect(find.text('Sarah Jenkins'), findsOneWidget);
      },
    );
  });
}
