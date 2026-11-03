import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/core/util/links.dart';
import 'package:icr_mobile/features/feed/feed_controller.dart';
import 'package:icr_mobile/features/feed/feed_models.dart';
import 'package:icr_mobile/features/feed/home_screen.dart';
import 'package:icr_mobile/features/forum/forum_callbacks.dart';
import 'package:icr_mobile/features/forum/new_thread_screen.dart';
import 'package:icr_mobile/features/forum/thread_controller.dart';
import 'package:icr_mobile/features/forum/thread_screen.dart';
import 'package:provider/provider.dart';

import 'helpers/feed_fixtures.dart';
import 'helpers/fonts.dart';
import 'helpers/forum_fakes.dart';
import 'helpers/offline_feed.dart';

/// The "@" picker and the tagged names, on the three screens that write words (a discussion's reply bar, the Home
/// feed's reply box, the composer) and the two that show them (the discussion's page, the Home cards), over the real
/// repository with only the forum faked. What the portal does with a tag is the portal's own tests'.
void main() {
  setUpAll(loadAppFonts);

  final launched = <Uri>[];

  setUp(() {
    launched.clear();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/url_launcher'), (call) async {
      if (call.method == 'launch') launched.add(Uri.parse((call.arguments as Map)['url'] as String));
      return call.method == 'launch' || call.method == 'canLaunch';
    });
  });

  tearDown(() {
    SiteRoutes.resolver = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      null,
    );
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pumpAndSettle();
  }

  Finder key(String k) => find.byKey(ValueKey(k));

  /// The people `GET /members/mentionable` knows: whoever's name holds what was asked for.
  final directory = <Map<String, Object?>>[
    {
      'id': 'u-rahul',
      'firstName': 'Rahul',
      'lastName': 'Sharma',
      'avatarUrl': null,
      'headline': 'Head of FM at Prestige',
      'profileSlug': 'rahul-sharma',
    },
    {
      'id': 'u-rakesh',
      'firstName': 'Rakesh',
      'lastName': 'Iyer',
      'avatarUrl': null,
      'headline': null,
      'profileSlug': 'rakesh-iyer',
    },
    {
      'id': 'u-priya',
      'firstName': 'Priya',
      'lastName': 'Nambiar',
      'avatarUrl': null,
      'headline': 'Facilities Lead',
      'profileSlug': 'priya-nambiar',
    },
  ];

  Map<String, Handler> mentionable() => {
    'GET /members/mentionable': (o) {
      final q = (o.queryParameters['search'] as String).toLowerCase();
      return [
        if (q.length >= 2)
          for (final p in directory)
            if ('${p['firstName']} ${p['lastName']}'.toLowerCase().contains(q)) p,
      ];
    },
  };

  /// Types [text] into [field], waits out the pause, lets the answer arrive.
  Future<void> typeInto(WidgetTester tester, String field, String text) async {
    await tester.tap(key(field));
    await tester.enterText(key(field), text);
    await tester.pump(const Duration(milliseconds: 300));
    await settle(tester);
  }

  String fieldText(WidgetTester tester, String field) => tester.widget<TextField>(key(field)).controller!.text;

  group('a discussion\'s reply bar', () {
    late ForumWorld world;
    late FakeForum api;
    late ThreadController controller;
    final members = <String>[];

    Future<void> pumpThread(WidgetTester tester, {ForumWorld? custom, bool memberCallback = true}) async {
      tester.view.physicalSize = const Size(780, 6000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      members.clear();
      world = custom ?? ForumWorld();
      api = FakeForum({...world.routes(), ...mentionable()});
      controller = ThreadController(repository: forumOn(api), slug: ForumWorld.slug, viewer: reader);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: ChangeNotifierProvider<ThreadController>.value(
            value: controller,
            child: ThreadScreen(callbacks: ForumCallbacks(onOpenMember: memberCallback ? members.add : null)),
          ),
        ),
      );
      await tester.runAsync(controller.start);
      await settle(tester);
    }

    Future<void> send(WidgetTester tester) async {
      await tester.tap(key('reply-send'));
      await settle(tester);
    }

    Map<String, dynamic> sent(String method, String path) => api.bodyOf(method, path);

    testWidgets('"@ra" lists the people who match, with photo, name and headline; a pick is sent as a link to them', (
      tester,
    ) async {
      await pumpThread(tester);
      await typeInto(tester, 'reply-input', 'Thanks @ra');
      expect(api.to('GET', '/members/mentionable').last.queryParameters, {'search': 'ra', 'limit': 8});
      expect(key('mention-option:u-rahul'), findsOneWidget);
      expect(key('mention-option:u-rakesh'), findsOneWidget);
      expect(key('mention-option:u-priya'), findsNothing);
      expect(find.text('Head of FM at Prestige'), findsOneWidget);
      await tester.tap(key('mention-option:u-rahul'));
      await tester.pump();
      expect(fieldText(tester, 'reply-input'), 'Thanks @Rahul Sharma ');
      expect(key('mention-panel'), findsNothing);

      await tester.enterText(key('reply-input'), 'Thanks @Rahul Sharma for the pointer & the <b>link</b>');
      await tester.pump();
      await send(tester);
      expect(
        sent('POST', '/forum/threads/t-q/replies')['bodyHtml'],
        '<p>Thanks <a href="/members/u-rahul">@Rahul Sharma</a> for the pointer &amp; the &lt;b&gt;link&lt;/b&gt;</p>',
      );
      expect(fieldText(tester, 'reply-input'), isEmpty);
      // The reply that came back shows the name as a link to the member.
      await tester.tapOnText(find.textRange.ofSubstring('@Rahul Sharma'));
      expect(members, ['u-rahul']);
    });

    testWidgets('a mention deleted from the words is not sent', (tester) async {
      await pumpThread(tester);
      await typeInto(tester, 'reply-input', 'Thanks @ra');
      await tester.tap(key('mention-option:u-rahul'));
      await tester.pump();
      await tester.enterText(key('reply-input'), 'Thanks Rahul');
      await tester.pump();
      await send(tester);
      expect(sent('POST', '/forum/threads/t-q/replies')['bodyHtml'], '<p>Thanks Rahul</p>');
    });

    testWidgets('nobody picked: the words go as they always did', (tester) async {
      await pumpThread(tester);
      await typeInto(tester, 'reply-input', 'No @one is here today');
      expect(key('mention-panel'), findsNothing, reason: 'the caret is off the name');
      await send(tester);
      expect(sent('POST', '/forum/threads/t-q/replies')['bodyHtml'], '<p>No @one is here today</p>');
    });

    testWidgets('no one found, and Escape', (tester) async {
      await pumpThread(tester);
      await typeInto(tester, 'reply-input', 'Hi @zzz');
      expect(find.text('No one found'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(key('mention-panel'), findsNothing);
    });

    testWidgets('editing a reply keeps the people already tagged in it, and tags another', (tester) async {
      final w = ForumWorld();
      (w.page1[2])['bodyHtml'] = '<p>Mine: ping <a href="/members/u-rahul">@Rahul Sharma</a> today</p>';
      await pumpThread(tester, custom: w);
      await tester.tap(key('reply-more:r5'));
      await settle(tester);
      await tester.tap(key('reply-menu-edit'));
      await settle(tester);
      expect(fieldText(tester, 'reply-input'), 'Mine: ping @Rahul Sharma today');
      await tester.enterText(key('reply-input'), 'Mine: ping @Rahul Sharma today, thanks');
      await tester.pump();
      await send(tester);
      expect(
        sent('PATCH', '/forum/replies/r5')['bodyHtml'],
        '<p>Mine: ping <a href="/members/u-rahul">@Rahul Sharma</a> today, thanks</p>',
      );
    });

    testWidgets('a name tagged in someone\'s reply opens that member\'s profile', (tester) async {
      final w = ForumWorld();
      (w.page1[0])['bodyHtml'] = '<p>Cc <a href="/members/u-priya">@Priya Nambiar</a> please.</p>';
      await pumpThread(tester, custom: w);
      expect(find.textContaining('Cc @Priya Nambiar please.', findRichText: true), findsOneWidget);
      await tester.tapOnText(find.textRange.ofSubstring('@Priya Nambiar'));
      expect(members, ['u-priya']);
    });

    testWidgets('a link to a member in the discussion\'s own words opens their profile in the app', (tester) async {
      final w = ForumWorld(bodyHtml: '<p>Ping <a href="/members/u-rahul">@Rahul Sharma</a> about it.</p>');
      await pumpThread(tester, custom: w);
      await tester.tapOnText(find.textRange.ofSubstring('@Rahul Sharma'));
      expect(members, ['u-rahul']);
      expect(launched, isEmpty, reason: 'not the browser');
    });

    testWidgets('with no member handler the link goes through the app\'s site routes, as the website\'s page', (
      tester,
    ) async {
      final opened = <Uri>[];
      SiteRoutes.resolver = (uri) =>
          (context) async => opened.add(uri);
      final w = ForumWorld(bodyHtml: '<p>Ping <a href="/members/u-rahul">@Rahul Sharma</a> about it.</p>');
      await pumpThread(tester, custom: w, memberCallback: false);
      await tester.tapOnText(find.textRange.ofSubstring('@Rahul Sharma'));
      expect(opened, [Uri.parse('https://icr.org.in/members/u-rahul')]);
      expect(launched, isEmpty);
    });
  });

  group('the Home feed', () {
    late FeedWorld world;
    late FakeForum api;
    late FeedController feed;
    final members = <String>[];
    final tags = <String>[];

    Future<void> pumpHome(WidgetTester tester, {FeedWorld? custom, Map<String, Handler> extra = const {}}) async {
      tester.view.physicalSize = const Size(780, 7600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      members.clear();
      tags.clear();
      world = custom ?? FeedWorld();
      api = FakeForum({...world.routes(), ...mentionable(), ...extra});
      feed = FeedController(OfflineFeed(repositoryOn(api)));
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
              callbacks: ForumCallbacks(onOpenMember: members.add, onOpenTag: tags.add),
            ),
          ),
        ),
      );
      await settle(tester);
    }

    Future<void> tapIn(WidgetTester tester, String postId, String k) async {
      await tester.tap(find.descendant(of: key(postId), matching: key(k)));
      await settle(tester);
    }

    testWidgets('a plain tag on a card does nothing on Home, even when the app could show its discussions', (
      tester,
    ) async {
      // Owner, 3 Nov 2026: a Home tag never opens the Forums tab; only a person's tag ("#@name") opens anything
      // (their profile — test/home_tags_test.dart).
      await pumpHome(tester);
      await tapIn(tester, 'iot', 'tag:#HVAC');
      await tapIn(tester, 'iot', 'tag:#SmartBMS');
      expect(tags, isEmpty);
      expect(members, isEmpty);
      expect(find.byType(ThreadScreen), findsNothing);
    });

    testWidgets('a tagged name in a card\'s words opens that member, not the discussion', (tester) async {
      final w = FeedWorld();
      w.details['slug-iot'] = {
        'bodyHtml': '<p>Ping <a href="/members/u-rahul">@Rahul Sharma</a> on the retrofit.</p>',
        'attachment': null,
      };
      await pumpHome(tester, custom: w);
      expect(
        find.descendant(of: key('iot'), matching: find.textContaining('Ping @Rahul Sharma', findRichText: true)),
        findsOneWidget,
      );
      await tester.tapOnText(find.textRange.ofSubstring('@Rahul Sharma'));
      await settle(tester);
      expect(members, ['u-rahul']);
      expect(find.byType(ThreadScreen), findsNothing);
      // The rest of the words still open the discussion.
      await tester.tapOnText(find.textRange.ofSubstring('on the retrofit.'));
      await settle(tester);
      expect(find.byType(ThreadScreen), findsOneWidget);
    });

    testWidgets('a tagged name in a comment opens that member', (tester) async {
      final w = FeedWorld();
      w.replies['slug-iot']![0]['bodyHtml'] = '<p>Spot on, <a href="/members/u-rahul">@Rahul Sharma</a>.</p>';
      await pumpHome(tester, custom: w);
      // The lead discussion's comments are open when the feed loads.
      await tester.tapOnText(find.textRange.ofSubstring('@Rahul Sharma'));
      expect(members, ['u-rahul']);
    });

    testWidgets('"@" in a card\'s comment box lists people; a pick is sent as a link to them', (tester) async {
      await pumpHome(tester);
      await typeInto(tester, 'reply-input', 'Thanks @pri');
      expect(key('mention-option:u-priya'), findsOneWidget);
      expect(find.text('Facilities Lead'), findsWidgets);
      await tester.tap(key('mention-option:u-priya'));
      await tester.pump();
      expect(fieldText(tester, 'reply-input'), 'Thanks @Priya Nambiar ');
      await tester.enterText(key('reply-input'), 'Thanks @Priya Nambiar for this');
      await tester.pump();
      await tester.tap(key('reply-send'));
      await settle(tester);
      expect(
        api.bodyOf('POST', '/forum/threads/iot/replies')['bodyHtml'],
        '<p>Thanks <a href="/members/u-priya">@Priya Nambiar</a> for this</p>',
      );
    });

    testWidgets('a comment with no tag is sent exactly as before', (tester) async {
      await pumpHome(tester);
      await tester.enterText(key('reply-input'), 'Plain words');
      await tester.pump();
      await tester.tap(key('reply-send'));
      await settle(tester);
      expect(api.bodyOf('POST', '/forum/threads/iot/replies')['bodyHtml'], '<p>Plain words</p>');
    });

    Map<String, Handler> composing() => {
      'GET /categories/tree': (_) => [
        {
          'id': 'SUSTAINABILITY_ESG',
          'key': 'SUSTAINABILITY_ESG',
          'name': 'ESG & Sustainability',
          'slug': 'esg-sustainability',
          'active': true,
          'level': 1,
          'children': <Object?>[],
        },
      ],
      'GET /forum/me': (_) => {'reputation': 0, 'level': 'NEW', 'requiresApproval': false, 'canModerate': false},
      'POST /forum/threads': (o) => {
        ...threadCard('new', title: (o.data as Map)['title'] as String, author: member('me', 'Bharat Buyer')),
        'slug': 'slug-new',
        'bodyHtml': (o.data as Map)['bodyHtml'],
        'moderation': 'PENDING',
        'canEdit': true,
      },
    };

    testWidgets('"Repost" names the discussion it brings to the feed', (tester) async {
      await pumpHome(tester, extra: composing());
      await tapIn(tester, 'iot', 'repost:iot');
      await tester.tap(key('repost-instant'));
      await settle(tester);
      final posted = api.bodyOf('POST', '/forum/threads');
      expect(posted['repostOfId'], 'iot');
      expect(posted['title'], startsWith('Repost: Implementing IoT sensors'));
    });

    testWidgets('"Repost with your thoughts" sends it too, once the reader posts', (tester) async {
      await pumpHome(tester, extra: composing());
      await tapIn(tester, 'iot', 'repost:iot');
      await tester.tap(key('repost-thoughts'));
      await settle(tester);
      expect(find.byType(NewThreadScreen), findsOneWidget);
      expect(api.to('POST', '/forum/threads'), isEmpty);
      await tester.tap(key('composer-topic'));
      await tester.pumpAndSettle();
      await tester.tap(key('topic-option:SUSTAINABILITY_ESG'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(key('composer-bar-send'));
      await tester.pumpAndSettle();
      await tester.tap(key('composer-bar-send'));
      await settle(tester);
      expect(api.bodyOf('POST', '/forum/threads')['repostOfId'], 'iot');
    });
  });

  group('the composer', () {
    late FakeForum api;

    Map<String, Handler> routes() => {
      ...mentionable(),
      // The public company list, as `GET /companies?search=` pages it.
      'GET /companies': (o) {
        final q = (o.queryParameters['search'] as String).toLowerCase();
        return {
          'data': [
            for (final c in const [
              {'id': 'co-acme', 'name': 'Acme Facility Services', 'city': 'Pune', 'logoUrl': null},
              {'id': 'co-rajan', 'name': 'Rajan Estates', 'city': 'Chennai', 'logoUrl': null},
            ])
              if ((c['name'] as String).toLowerCase().contains(q)) c,
          ],
          'meta': {'page': 1, 'limit': 5, 'total': 2},
        };
      },
      'GET /categories/tree': (_) => [
        {
          'id': 'TECHNOLOGY_INNOVATION',
          'key': 'TECHNOLOGY_INNOVATION',
          'name': 'Technology',
          'slug': 'technology',
          'active': true,
          'level': 1,
          'children': <Object?>[],
        },
      ],
      'GET /forum/me': (_) => {'reputation': 0, 'level': 'NEW', 'requiresApproval': false, 'canModerate': false},
      'POST /forum/threads': (o) => {
        ...threadCard('t-new', title: (o.data as Map)['title'] as String, author: member('me', 'Bharat Buyer')),
        'slug': 'slug-new',
        'bodyHtml': (o.data as Map)['bodyHtml'],
        'moderation': 'APPROVED',
        'canEdit': true,
      },
    };

    Future<void> pumpComposer(WidgetTester tester, {String? repostOfId, String? initialBody}) async {
      tester.view.physicalSize = const Size(780, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      api = FakeForum(routes());
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                key: const ValueKey('open'),
                onPressed: () => openComposer(
                  context,
                  repository: forumOn(api),
                  repostOfId: repostOfId,
                  initialTitle: initialBody == null ? null : 'Repost: A discussion worth sharing',
                  initialBody: initialBody,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(key('open'));
      await tester.pumpAndSettle();
      await settle(tester);
      await tester.tap(key('composer-topic'));
      await tester.pumpAndSettle();
      await tester.tap(key('topic-option:TECHNOLOGY_INNOVATION'));
      await tester.pumpAndSettle();
    }

    Future<void> post(WidgetTester tester) async {
      await tester.ensureVisible(key('composer-bar-send'));
      await tester.pumpAndSettle();
      await tester.tap(key('composer-bar-send'));
      await settle(tester);
    }

    testWidgets('"@" in the details lists people above the keyboard; a pick is sent as a link to them', (tester) async {
      await pumpComposer(tester);
      await tester.enterText(key('composer-title'), 'Who reviews the retrofit plan?');
      await typeInto(tester, 'composer-body', 'Please review @ra');
      expect(key('mention-option:u-rahul'), findsOneWidget);
      await tester.tap(key('mention-option:u-rahul'));
      await tester.pump();
      expect(fieldText(tester, 'composer-body'), 'Please review @Rahul Sharma ');
      await tester.enterText(key('composer-body'), 'Please review @Rahul Sharma today');
      await tester.pump();
      await post(tester);
      expect(
        api.bodyOf('POST', '/forum/threads')['bodyHtml'],
        '<p>Please review <a href="/members/u-rahul">@Rahul Sharma</a> today</p>',
      );
    });

    testWidgets('a mention deleted from the details is not sent', (tester) async {
      await pumpComposer(tester);
      await tester.enterText(key('composer-title'), 'Who reviews the retrofit plan?');
      await typeInto(tester, 'composer-body', 'Please review @ra');
      await tester.tap(key('mention-option:u-rahul'));
      await tester.pump();
      await tester.enterText(key('composer-body'), 'Please review it');
      await tester.pump();
      await post(tester);
      expect(api.bodyOf('POST', '/forum/threads')['bodyHtml'], '<p>Please review it</p>');
    });

    testWidgets('a repost sends the discussion it reposts; an ordinary post sends none', (tester) async {
      await pumpComposer(tester, repostOfId: 't-orig', initialBody: '↻ Reposted from Sarah Jenkins');
      await post(tester);
      expect(api.bodyOf('POST', '/forum/threads')['repostOfId'], 't-orig');
    });

    // Owner, 3 Nov 2026: "@vinay" in the Tags should offer the people and companies it may mean, in a discussion and
    // a poll alike (one composer).
    testWidgets('"@" in the Tags lists people and companies; a pick adds a person by handle, a company by name', (
      tester,
    ) async {
      await pumpComposer(tester);
      await tester.enterText(key('composer-title'), 'Who reviews the retrofit plan?');
      await tester.enterText(key('composer-body'), 'Please review the retrofit plan before Friday.');
      await tester.pump();
      await tester.ensureVisible(key('composer-tag'));
      await typeInto(tester, 'composer-tag', '@ra');
      expect(api.to('GET', '/members/mentionable').last.queryParameters['search'], 'ra');
      expect(api.to('GET', '/companies').last.queryParameters['search'], 'ra');
      expect(key('tag-person:u-rahul'), findsOneWidget);
      expect(key('tag-person:u-rakesh'), findsOneWidget);
      expect(find.text('Head of FM at Prestige'), findsOneWidget, reason: "a person's headline under their name");
      expect(key('tag-company:co-rajan'), findsOneWidget);
      expect(find.text('Chennai'), findsOneWidget, reason: "a company's city under its name");

      await tester.tap(key('tag-person:u-rahul'));
      await tester.pump();
      expect(find.text('#@rahul-sharma'), findsOneWidget, reason: 'the person by their profile handle');
      expect(fieldText(tester, 'composer-tag'), isEmpty);
      expect(key('tag-suggestions'), findsNothing);

      await typeInto(tester, 'composer-tag', '#@acme');
      await tester.tap(key('tag-company:co-acme'));
      await tester.pump();
      expect(find.text('#@acme-facility-services'), findsOneWidget, reason: 'the company by its name');

      await post(tester);
      expect(api.bodyOf('POST', '/forum/threads')['tags'], ['@rahul-sharma', '@acme-facility-services']);
    });

    testWidgets('a plain tag lists no one, and a name nobody has says so', (tester) async {
      await pumpComposer(tester);
      await tester.ensureVisible(key('composer-tag'));
      await typeInto(tester, 'composer-tag', 'hvac');
      expect(key('tag-suggestions'), findsNothing);
      expect(api.to('GET', '/members/mentionable'), isEmpty);
      await typeInto(tester, 'composer-tag', '@zz');
      expect(key('tag-suggest-empty'), findsOneWidget);
    });

    testWidgets('an ordinary post carries no repostOfId', (tester) async {
      await pumpComposer(tester);
      await tester.enterText(key('composer-title'), 'Who reviews the retrofit plan?');
      await tester.enterText(key('composer-body'), 'Some details here');
      await tester.pump();
      await post(tester);
      expect(api.bodyOf('POST', '/forum/threads'), isNot(contains('repostOfId')));
    });
  });
}
