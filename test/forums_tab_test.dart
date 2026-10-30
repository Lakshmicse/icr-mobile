import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/feed/feed_models.dart';
import 'package:icr_mobile/features/forum/forum_callbacks.dart';
import 'package:icr_mobile/features/forum/forums_controller.dart';
import 'package:icr_mobile/features/forum/forums_screen.dart';
import 'package:icr_mobile/features/forum/thread_screen.dart';

import 'helpers/feed_fixtures.dart';
import 'helpers/fonts.dart';
import 'helpers/forum_fakes.dart';

/// Every control of the Forums tab, pressed on the real screen over the real repository, with only the forum faked.
/// A small forum is built here (`_Board`): topics with sub-topics, questions, a poll, the reader's own and saved
/// discussions, and it answers `GET /forum/threads` the way the portal's `ForumThreadsService.list` does: each
/// filter narrows, a sort orders, a page is cut.
class _Board {
  _Board({this.extra = 0}) {
    Map<String, Object?> t(
      String id,
      String title, {
      String kind = 'DISCUSSION',
      String cat = 'TECHNOLOGY_INNOVATION',
      String catName = 'Technology',
      String catSlug = 'technology',
      String? sub,
      String? subSlug,
      List<String> tags = const [],
      int replies = 0,
      int likes = 0,
      Map<String, Object?>? author,
      Map<String, Object?>? poll,
      bool saved = false,
      Duration age = const Duration(hours: 3),
    }) {
      final row = threadCard(
        id,
        title: title,
        kind: kind,
        tags: tags,
        categoryKey: cat,
        categoryName: catName,
        subName: sub,
        author: author,
        replyCount: replies,
        likes: likes,
        views: 100,
        reactions: likes > 0 ? {'LIKE': likes} : const {},
        poll: poll,
        saved: saved,
        age: age,
      );
      (row['category']! as Map)['slug'] = catSlug;
      if (sub != null) (row['subcategory']! as Map)['slug'] = subSlug;
      return row;
    }

    threads = [
      t(
        'a',
        'Chiller plant retrofit for a 12 year old building',
        kind: 'QUESTION',
        sub: 'BMS',
        subSlug: 'bms',
        tags: ['hvac', 'bms'],
        replies: 4,
        likes: 30,
        author: member('u-sarah', 'Sarah Jenkins', headline: 'Facilities Lead at Google'),
      ),
      t(
        'b',
        'What is your primary FM software in 2026',
        poll: pollJson(mine: 'o3'),
        author: member('u-marcus', 'Marcus Reed', headline: 'Architect at DesignCo'),
        likes: 10,
        age: const Duration(hours: 5),
      ),
      t(
        'c',
        'Net zero reporting that survives an audit',
        cat: 'SUSTAINABILITY_ESG',
        catName: 'ESG & Sustainability',
        catSlug: 'esg-sustainability',
        tags: ['esg'],
        replies: 2,
        likes: 60,
        author: member('u-elena', 'Elena Rostova', headline: 'Sustainability Engineer'),
        age: const Duration(hours: 8),
      ),
      t(
        'd',
        'Which AMC clause survives multiple cities',
        kind: 'QUESTION',
        cat: 'PROCUREMENT_SUPPLY_CHAIN',
        catName: 'Procurement & Supply Chain',
        catSlug: 'procurement-supply-chain',
        tags: ['amc'],
        author: member('u-rajesh', 'Rajesh Kumar', headline: 'Procurement Lead at Tata Realty'),
        age: const Duration(days: 1),
      ),
      t(
        'e',
        'Shortlisting a BMS retrofit partner',
        kind: 'QUESTION',
        author: member('me', 'Bharat Buyer', headline: 'Operations at TechCorp'),
        likes: 3,
        age: const Duration(days: 3),
      ),
      t(
        'f',
        'IoT sensors for return air paths',
        sub: 'BMS',
        subSlug: 'bms',
        tags: ['hvac'],
        saved: true,
        author: member('u-vikram', 'Vikram Iyer', headline: 'Head of FM at Prestige'),
        likes: 22,
        age: const Duration(days: 4),
      ),
    ];
    for (var i = 0; i < extra; i++) {
      threads.add(
        t(
          'x$i',
          'Older discussion number $i here',
          author: member('u-x$i', 'Member $i'),
          age: Duration(days: 10 + i),
        ),
      );
    }
  }

  final int extra;
  late List<Map<String, Object?>> threads;
  int unread = 5;
  bool requiresApproval = false;
  final following = <String>{'u-marcus'};
  final topics = [
    {
      'id': 'c1',
      'name': 'Technology',
      'slug': 'technology',
      'description': 'BMS and IoT',
      'icon': 'Laptop',
      'order': 2,
      'published': true,
      'threadCount': 3,
    },
    {
      'id': 'c2',
      'name': 'ESG & Sustainability',
      'slug': 'esg-sustainability',
      'description': null,
      'icon': 'Grass',
      'order': 14,
      'published': true,
      'threadCount': 1,
    },
    {
      'id': 'c3',
      'name': 'Procurement & Supply Chain',
      'slug': 'procurement-supply-chain',
      'description': null,
      'icon': 'Cart',
      'order': 5,
      'published': true,
      'threadCount': 1,
    },
  ];
  final refusals = <String, (int, String)>{};

  Map<String, Object?> taxonomyNode(
    String key,
    String name,
    String slug, {
    List<Map<String, Object?>> children = const [],
  }) => {'id': key, 'key': key, 'name': name, 'slug': slug, 'active': true, 'level': 1, 'children': children};

  Map<String, Handler> routes() {
    return {
      'GET /forum/threads': (o) {
        final refused = refusals['GET /forum/threads'];
        if (refused != null) return (refused.$1, '{"message":"${refused.$2}"}');
        final q = o.queryParameters;
        var rows = threads.where((r) {
          final tag = q['tag'] as String?;
          if (tag != null && !(r['tags'] as List).contains(tag)) return false;
          final search = (q['search'] as String?)?.toLowerCase();
          if (search != null && !'${r['title']} ${r['excerpt']}'.toLowerCase().contains(search)) return false;
          final cat = q['categorySlug'] as String?;
          if (cat != null && (r['category'] as Map)['slug'] != cat) return false;
          final sub = q['subcategorySlug'] as String?;
          if (sub != null && (r['subcategory'] as Map?)?['slug'] != sub) return false;
          final kind = q['kind'] as String?;
          if (kind != null && r['kind'] != kind) return false;
          if (q['sort'] == 'unanswered' && !(r['kind'] == 'QUESTION' && r['replyCount'] == 0)) return false;
          if (q['savedOnly'] == true && r['saved'] != true) return false;
          if (q['mineOnly'] == true && (r['author'] as Map)['id'] != 'me') return false;
          return true;
        }).toList();
        if (q['sort'] == 'top') rows = [...rows]..sort((a, b) => (b['likes'] as int).compareTo(a['likes'] as int));
        final limit = (q['limit'] as int?) ?? 20;
        final pageNo = (q['page'] as int?) ?? 1;
        final slice = rows.skip((pageNo - 1) * limit).take(limit).toList();
        return page(slice, hasNext: rows.length > pageNo * limit, total: rows.length);
      },
      'GET /forum/categories': (_) {
        final refused = refusals['GET /forum/categories'];
        if (refused != null) return (refused.$1, '{"message":"${refused.$2}"}');
        return topics;
      },
      'GET /categories/tree': (_) => [
        taxonomyNode(
          'TECHNOLOGY_INNOVATION',
          'Technology',
          'technology',
          children: [
            {
              'id': 's1',
              'key': 'BMS',
              'name': 'Building Management Systems',
              'slug': 'bms',
              'active': true,
              'level': 2,
              'children': [],
            },
            {
              'id': 's2',
              'key': 'IWMS',
              'name': 'IWMS & CAFM',
              'slug': 'iwms-cafm',
              'active': true,
              'level': 2,
              'children': [],
            },
          ],
        ),
        taxonomyNode('SUSTAINABILITY_ESG', 'ESG & Sustainability', 'esg-sustainability'),
        taxonomyNode('PROCUREMENT_SUPPLY_CHAIN', 'Procurement & Supply Chain', 'procurement-supply-chain'),
      ],
      'GET /forum/me': (_) => {
        'reputation': 12,
        'level': 'NEW',
        'requiresApproval': requiresApproval,
        'canModerate': false,
      },
      'GET /notifications/unread-count': (_) => {'unread': unread},
      'GET /members/me/following': (_) => page([for (final id in following) member(id, 'Followed $id')]),
      for (final r in threads) ...{
        'POST /forum/threads/${r['id']}/vote': (_) => {'value': 1, 'reaction': 'LIKE', 'changed': 1},
        'DELETE /forum/threads/${r['id']}/vote': (_) => {'value': 0, 'reaction': null, 'changed': -1},
        'POST /forum/threads/${r['id']}/save': (_) {
          final refused = refusals['POST /forum/threads/${r['id']}/save'];
          if (refused != null) return (refused.$1, '{"message":"${refused.$2}"}');
          r['saved'] = true;
          return {'saved': true};
        },
        'DELETE /forum/threads/${r['id']}/save': (_) {
          r['saved'] = false;
          return {'saved': false};
        },
        'POST /forum/threads/${r['id']}/poll/vote': (o) => pollJson(
          mine: (o.data as Map)['optionId'] as String,
          options: const [('o1', 'IBM TRIRIGA', 53), ('o2', 'Planon', 28), ('o3', 'Archibus', 86), ('o4', 'Other', 23)],
        ),
        'POST /forum/threads/${r['id']}/view': (_) => {'success': true},
        'GET /forum/threads/slug-${r['id']}': (_) => {
          ...r,
          'bodyHtml': '<p>The words of ${r['id']}.</p>',
          'attachment': null,
        },
        'GET /forum/threads/slug-${r['id']}/replies': (_) => page(const []),
        'GET /forum/threads/${r['id']}/reactions': (_) => page([
          {
            'user': member('u-a', 'Anita Raghavan', headline: 'Campus FM leader'),
            'reaction': 'LIKE',
            'reactedAt': DateTime.now().toUtc().toIso8601String(),
          },
        ]),
      },
      'POST /members/u-sarah/follow': (_) => {'followers': 1, 'following': 0, 'viewerFollows': true},
      'POST /forum/reports': (_) => {'id': 'rep'},
    };
  }
}

void main() {
  setUpAll(loadAppFonts);

  final launched = <Uri>[];
  final shared = <Map<String, dynamic>>[];
  var copied = '';

  setUp(() {
    launched.clear();
    shared.clear();
    copied = '';
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
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/url_launcher'), null);
    messenger.setMockMethodCallHandler(const MethodChannel('dev.fluttercommunity.plus/share'), null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pumpAndSettle();
  }

  late _Board board;
  late FakeForum api;
  late ForumsController forums;
  var backs = 0;
  var bells = 0;
  final members = <String>[];

  Finder key(String k) => find.byKey(ValueKey(k));
  FeedPost post(String id) => forums.posts.firstWhere((p) => p.id == id);
  Map<String, dynamic> lastQuery() => api.to('GET', '/forum/threads').last.queryParameters;
  Finder snack(String text) => find.descendant(of: find.byType(SnackBar), matching: find.textContaining(text));

  Future<void> tapKey(WidgetTester tester, String k) async {
    await tester.ensureVisible(key(k).first);
    await tester.pumpAndSettle();
    await tester.tap(key(k).first);
    await settle(tester);
  }

  /// A chip in a row that scrolls sideways: slide the row until it is built.
  Future<void> tapChip(WidgetTester tester, String row, String k) async {
    for (var i = 0; i < 5 && key(k).evaluate().isEmpty; i++) {
      await tester.drag(key(row), const Offset(-300, 0));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(key(k));
    await tester.pumpAndSettle();
    await tester.tap(key(k));
    await settle(tester);
  }

  Future<void> pumpForums(
    WidgetTester tester, {
    _Board? custom,
    double height = 5200,
    Map<String, Handler> extra = const {},
  }) async {
    tester.view.physicalSize = Size(780, height);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    backs = 0;
    bells = 0;
    members.clear();
    board = custom ?? _Board();
    api = FakeForum({...board.routes(), ...extra});
    forums = ForumsController(forumOn(api));
    addTearDown(forums.dispose);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: ForumsScreen(
          viewer: reader,
          controller: forums,
          onBack: () => backs++,
          callbacks: ForumCallbacks(onBell: () => bells++, onOpenMember: members.add),
        ),
      ),
    );
    await settle(tester);
  }

  group('the tab as it opens', () {
    testWidgets('it draws the bar, the search, the composer, the views, the topics and the discussions', (
      tester,
    ) async {
      await pumpForums(tester);
      expect(find.text('Forums'), findsOneWidget);
      expect(find.text('Search discussions...'), findsOneWidget);
      expect(find.text('Start a discussion...'), findsOneWidget);
      for (final v in ['All Feed', 'Trending', 'Following', 'Unanswered']) {
        expect(find.text(v), findsOneWidget);
      }
      // The rest of the row is past the screen's edge: it builds as it scrolls in.
      await tester.drag(key('forum-views'), const Offset(-600, 0));
      await tester.pumpAndSettle();
      for (final v in ['Polls', 'Saved', 'My posts']) {
        expect(find.text(v), findsOneWidget);
      }
      await tester.drag(key('forum-views'), const Offset(600, 0));
      await tester.pumpAndSettle();
      expect(find.text('All topics'), findsOneWidget);
      expect(find.text('Technology (3)'), findsOneWidget);
      expect(find.text('ESG & Sustainability (1)'), findsOneWidget);
      expect(find.text('Chiller plant retrofit for a 12 year old building'), findsOneWidget);
      expect(find.text('Sarah Jenkins'), findsOneWidget);
      expect(find.text('Marcus Reed'), findsOneWidget);
      expect(key('forums-total'), findsOneWidget);
      expect(find.text('6 discussions'), findsOneWidget);
      expect(find.text("You're all caught up"), findsOneWidget);
      // The first screen asks the forum for the latest page, the topics, the standing, the bell.
      expect(lastQuery(), {'page': 1, 'limit': 20, 'sort': 'latest'});
      expect(api.count('GET', '/forum/categories'), 1);
      expect(api.count('GET', '/forum/me'), 1);
      expect(api.count('GET', '/notifications/unread-count'), 1);
    });

    testWidgets('the bell shows the unread count and goes where the app wires it; Back goes back', (tester) async {
      await pumpForums(tester);
      await tester.tap(find.bySemanticsLabel('Notifications, 5 unread'));
      await tester.pumpAndSettle();
      expect(bells, 1);
      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();
      expect(backs, 1);
    });

    testWidgets('a reader whose posts are reviewed first is told so', (tester) async {
      await pumpForums(tester, custom: _Board()..requiresApproval = true);
      expect(key('forums-approval'), findsOneWidget);
      expect(find.textContaining('read by a moderator before they go public'), findsOneWidget);
    });

    testWidgets('a failed read says why and Try again reads again; the topics have their own retry', (tester) async {
      final b = _Board()
        ..refusals['GET /forum/threads'] = (500, 'The forum is resting')
        ..refusals['GET /forum/categories'] = (500, 'No topics');
      await pumpForums(tester, custom: b);
      expect(find.text("Couldn't load the discussions"), findsOneWidget);
      expect(find.text('The forum is resting'), findsOneWidget);
      expect(find.text("Couldn't load the topics"), findsOneWidget);
      b.refusals.clear();
      await tester.tap(key('message-action'));
      await settle(tester);
      expect(find.text('Chiller plant retrofit for a 12 year old building'), findsOneWidget);
      await tester.tap(key('topics-retry'));
      await settle(tester);
      expect(find.text('Technology (3)'), findsOneWidget);
    });
  });

  group('the views', () {
    testWidgets('each chip asks the forum for what it names', (tester) async {
      await pumpForums(tester);
      await tapKey(tester, 'view:trending');
      expect(lastQuery()['sort'], 'top');
      // Most upvoted first.
      expect(forums.posts.first.id, 'c');
      await tapKey(tester, 'view:unanswered');
      expect(lastQuery()['sort'], 'unanswered');
      // Open questions with no reply: the portal's own rule, the reader's included.
      expect(forums.posts.map((p) => p.id), ['d', 'e']);
      await tapChip(tester, 'forum-views', 'view:saved');
      expect(lastQuery()['savedOnly'], true);
      expect(forums.posts.map((p) => p.id), ['f']);
      await tapChip(tester, 'forum-views', 'view:mine');
      expect(lastQuery()['mineOnly'], true);
      expect(forums.posts.map((p) => p.id), ['e']);
      await tester.drag(key('forum-views'), const Offset(900, 0));
      await tester.pumpAndSettle();
      await tapKey(tester, 'view:all');
      expect(lastQuery().containsKey('savedOnly'), isFalse);
      expect(forums.posts, hasLength(6));
    });

    testWidgets('Following keeps the people the reader follows; Polls keeps polls', (tester) async {
      await pumpForums(tester);
      await tapKey(tester, 'view:following');
      expect(forums.posts.map((p) => p.id), ['b']);
      await tapChip(tester, 'forum-views', 'view:polls');
      expect(forums.posts.map((p) => p.id), ['b']);
      expect(find.text('Archibus (Your vote)'), findsOneWidget);
    });

    testWidgets('an empty view says what it is waiting for', (tester) async {
      final b = _Board()..following.clear();
      await pumpForums(tester, custom: b);
      await tapKey(tester, 'view:following');
      expect(find.text('Nothing from people you follow yet'), findsOneWidget);
      b.threads.removeWhere((t) => (t['author'] as Map)['id'] == 'me');
      await tapChip(tester, 'forum-views', 'view:mine');
      expect(find.text("You haven't posted yet"), findsOneWidget);
      b.threads.removeWhere((t) => t['saved'] == true);
      await tapChip(tester, 'forum-views', 'view:saved');
      expect(find.text('Nothing saved yet'), findsOneWidget);
    });
  });

  group('search, topics and filters', () {
    testWidgets('a search asks the forum for the words, shows them as a pill, and the x brings the list back', (
      tester,
    ) async {
      await pumpForums(tester);
      await tester.enterText(find.byType(TextField).first, 'chiller');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await settle(tester);
      expect(lastQuery()['search'], 'chiller');
      expect(forums.posts.map((p) => p.id), ['a']);
      expect(find.text('1 discussion'), findsOneWidget);
      expect(find.text('"chiller"'), findsOneWidget);
      await tester.tap(key('active:search'));
      await settle(tester);
      expect(lastQuery().containsKey('search'), isFalse);
      expect(forums.posts, hasLength(6));
      expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text, isEmpty);
    });

    testWidgets('a search that finds nothing says so', (tester) async {
      await pumpForums(tester);
      await tester.enterText(find.byType(TextField).first, 'zzzz');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await settle(tester);
      expect(find.text('No discussions match "zzzz"'), findsOneWidget);
    });

    testWidgets('a topic filters by its slug; its sub-topics appear and filter further; the lit chip again goes back', (
      tester,
    ) async {
      await pumpForums(tester);
      await tapKey(tester, 'topic:technology');
      expect(lastQuery()['categorySlug'], 'technology');
      expect(forums.posts.map((p) => p.id), containsAll(['a', 'b', 'e', 'f']));
      expect(forums.posts.every((p) => p.id != 'c'), isTrue);
      // The sub-topics of Technology come from the taxonomy.
      expect(key('forum-subtopics'), findsOneWidget);
      expect(find.text('Building Management Systems'), findsOneWidget);
      await tapKey(tester, 'sub:bms');
      expect(lastQuery()['subcategorySlug'], 'bms');
      expect(forums.posts.map((p) => p.id), ['a', 'f']);
      await tapKey(tester, 'sub:bms'); // the same chip again
      expect(lastQuery().containsKey('subcategorySlug'), isFalse);
      await tapKey(tester, 'topic:technology');
      expect(lastQuery().containsKey('categorySlug'), isFalse);
      expect(key('forum-subtopics'), findsNothing);
      expect(forums.posts, hasLength(6));
    });

    testWidgets(
      'the filter sheet sets the order, the kind, the topic, the sub-topic and a tag; the button counts what is set',
      (tester) async {
        await pumpForums(tester);
        await tester.tap(key('forum-filters'));
        await settle(tester);
        expect(find.text('Filter discussions'), findsOneWidget);
        await tester.tap(key('filter-sort:top'));
        await tester.tap(key('filter-kind:questions'));
        await tester.pump();
        await tester.tap(key('filter-topic:technology'));
        await tester.pump();
        await tester.tap(key('filter-sub:bms'));
        await tester.pump();
        await tester.enterText(key('filter-tag'), '#HVAC');
        await tester.tap(key('filters-apply'));
        await settle(tester);
        expect(lastQuery(), {
          'page': 1,
          'limit': 20,
          'sort': 'top',
          'tag': 'hvac',
          'categorySlug': 'technology',
          'subcategorySlug': 'bms',
          'kind': 'QUESTION',
        });
        expect(forums.posts.map((p) => p.id), ['a']);
        // Four things narrow the list now: the order, the kind, the sub-topic and the tag.
        expect(find.bySemanticsLabel('Filters, 4 set'), findsOneWidget);
        expect(key('active:tag'), findsOneWidget);
        expect(find.text('Questions'), findsOneWidget);
        // "Clear all" in the sheet: back to the plain list (the view stays).
        await tester.tap(key('forum-filters'));
        await settle(tester);
        await tester.tap(key('filters-clear'));
        await settle(tester);
        expect(lastQuery(), {'page': 1, 'limit': 20, 'sort': 'latest'});
        expect(forums.posts, hasLength(6));
      },
    );

    testWidgets('in Trending and Unanswered the order is the view\'s, and the sheet says so', (tester) async {
      await pumpForums(tester);
      await tapKey(tester, 'view:trending');
      await tester.tap(key('forum-filters'));
      await settle(tester);
      expect(find.text('SORT BY (SET BY THE VIEW)'), findsOneWidget);
      await tester.tap(key('filter-sort:newest'));
      await tester.tap(key('filters-apply'));
      await settle(tester);
      expect(lastQuery()['sort'], 'top');
    });

    testWidgets('a tag on a card filters by it, and its pill takes it off', (tester) async {
      await pumpForums(tester);
      await tester.ensureVisible(find.text('#amc'));
      await tester.tap(key('tag:#amc'));
      await settle(tester);
      expect(lastQuery()['tag'], 'amc');
      expect(forums.posts.map((p) => p.id), ['d']);
      await tester.tap(key('active:tag'));
      await settle(tester);
      expect(forums.posts, hasLength(6));
    });

    testWidgets('filters that match nothing offer to clear them', (tester) async {
      await pumpForums(tester);
      await tapKey(tester, 'topic:procurement-supply-chain');
      await tester.tap(key('forum-filters'));
      await settle(tester);
      await tester.tap(key('filter-kind:discussions'));
      await tester.tap(key('filters-apply'));
      await settle(tester);
      expect(find.text('No discussions match these filters'), findsOneWidget);
      await tester.tap(key('message-action'));
      await settle(tester);
      expect(forums.posts, isNotEmpty);
    });

    testWidgets('a second pill clears everything at once', (tester) async {
      await pumpForums(tester);
      await tester.enterText(find.byType(TextField).first, 'retrofit');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await settle(tester);
      await tapKey(tester, 'topic:technology');
      await tester.tap(key('forum-filters'));
      await settle(tester);
      await tester.tap(key('filter-kind:questions'));
      await tester.tap(key('filters-apply'));
      await settle(tester);
      expect(key('active:clear'), findsOneWidget);
      await tester.tap(key('active:clear'));
      await settle(tester);
      expect(lastQuery(), {'page': 1, 'limit': 20, 'sort': 'latest'});
    });
  });

  group('paging and refreshing', () {
    testWidgets('scrolling to the end reads the next page; the end says you are caught up', (tester) async {
      final b = _Board(extra: 30);
      await pumpForums(tester, custom: b, height: 2400);
      expect(forums.posts, hasLength(20));
      expect(find.text("You're all caught up"), findsNothing);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -30000));
      await settle(tester);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -30000));
      await settle(tester);
      expect(api.to('GET', '/forum/threads').map((o) => o.queryParameters['page']), [1, 2]);
      expect(forums.posts, hasLength(36));
      expect(find.text("You're all caught up"), findsOneWidget);
    });

    testWidgets('pulling down reads the list, the topics, the standing and the bell again', (tester) async {
      await pumpForums(tester, height: 2400);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 600));
      await settle(tester);
      expect(api.count('GET', '/forum/threads'), 2);
      expect(api.count('GET', '/forum/categories'), 2);
      expect(api.count('GET', '/notifications/unread-count'), 2);
    });
  });

  group('a card', () {
    testWidgets(
      'Like reacts at once, again takes it back, a refusal puts it back; holding it offers the five reactions',
      (tester) async {
        await pumpForums(tester);
        await tapKey(tester, 'like:a');
        expect(post('a').myReaction, ReactionKind.like);
        expect(post('a').reactions, 31);
        await tapKey(tester, 'like:a');
        expect(post('a').myReaction, isNull);
        await tester.longPress(key('like:a'));
        await tester.pumpAndSettle();
        await tester.tap(key('reaction:CELEBRATE'));
        await settle(tester);
        expect(post('a').myReaction, ReactionKind.celebrate);
        expect(api.bodyOf('POST', '/forum/threads/a/vote'), {'value': 1, 'reaction': 'CELEBRATE'});
      },
    );

    testWidgets('the bookmark saves and unsaves, a refusal leaves it; on Saved a card let go leaves the list', (
      tester,
    ) async {
      await pumpForums(tester);
      await tapKey(tester, 'save:a');
      expect(post('a').saved, isTrue);
      await tapKey(tester, 'save:a');
      expect(post('a').saved, isFalse);
      board.refusals['POST /forum/threads/a/save'] = (500, 'No saves now.');
      await tapKey(tester, 'save:a');
      expect(snack('No saves now.'), findsOneWidget);
      expect(post('a').saved, isFalse);

      await tapChip(tester, 'forum-views', 'view:saved');
      expect(forums.posts.map((p) => p.id), ['f']);
      await tapKey(tester, 'save:f');
      expect(forums.posts, isEmpty);
      expect(find.text('Nothing saved yet'), findsOneWidget);
    });

    testWidgets('Follow follows the author and goes away for that author; a poll option votes', (tester) async {
      await pumpForums(tester);
      expect(key('follow:a'), findsOneWidget);
      await tapKey(tester, 'follow:a');
      expect(api.count('POST', '/members/u-sarah/follow'), 1);
      expect(key('follow:a'), findsNothing);
      await tapKey(tester, 'poll-option:o2');
      expect(api.bodyOf('POST', '/forum/threads/b/poll/vote'), {'optionId': 'o2'});
      expect(find.text('Planon (Your vote)'), findsOneWidget);
    });

    testWidgets('Share hands the share sheet the title and the link; the repost glyph asks how to repost', (
      tester,
    ) async {
      await pumpForums(tester);
      await tapKey(tester, 'share:a');
      expect(shared.single['text'], endsWith('https://icr.org.in/community/slug-a'));
      await tapKey(tester, 'repost:a');
      expect(find.text('Repost with your thoughts'), findsOneWidget);
      expect(find.text('Repost'), findsOneWidget);
    });

    testWidgets('the three dots: open the discussion, copy its link, report it; one\'s own has no Report', (
      tester,
    ) async {
      await pumpForums(tester);
      await tapKey(tester, 'more:a');
      await tester.tap(key('menu-copy'));
      await settle(tester);
      expect(copied, 'https://icr.org.in/community/slug-a');
      await tapKey(tester, 'more:e');
      expect(key('menu-report'), findsNothing);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await tapKey(tester, 'more:a');
      await tester.tap(key('menu-report'));
      await settle(tester);
      await tester.tap(key('report-reason:SPAM'));
      await tester.pump();
      await tester.tap(key('report-send'));
      await settle(tester);
      expect(api.bodyOf('POST', '/forum/reports'), {'threadId': 'a', 'reason': 'SPAM'});
      expect(snack('A moderator will take a look.'), findsOneWidget);
    });

    testWidgets('"N reactions" lists who reacted; a member\'s photo opens the member', (tester) async {
      await pumpForums(tester);
      await tapKey(tester, 'reactions:a');
      expect(find.text('Anita Raghavan'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await tapKey(tester, 'author:a');
      expect(members, ['u-sarah']);
    });
  });

  group('a card opens its discussion', () {
    testWidgets(
      'the title opens the page; what the reader does there shows on the card; a tag chosen there filters this tab',
      (tester) async {
        await pumpForums(tester);
        await tapKey(tester, 'open:a');
        expect(find.byType(ThreadScreen), findsOneWidget);
        expect(find.text('The words of a.'), findsOneWidget);
        await tester.tap(key('thread-like'));
        await settle(tester);
        await tester.tap(find.bySemanticsLabel('Back').first);
        await settle(tester);
        expect(find.byType(ThreadScreen), findsNothing);
        expect(post('a').myReaction, ReactionKind.like);
        expect(post('a').reactions, 31);

        // A tag on the page narrows the tab and leaves the page.
        await tapKey(tester, 'open:a');
        await tester.tap(key('thread-tag:#hvac'));
        await settle(tester);
        expect(find.byType(ThreadScreen), findsNothing);
        expect(lastQuery()['tag'], 'hvac');
        expect(forums.posts.map((p) => p.id), ['a', 'f']);
      },
    );

    testWidgets('the speech bubble opens the page too, and a topic chosen there filters this tab', (tester) async {
      await pumpForums(tester);
      await tapKey(tester, 'comments:a');
      expect(find.byType(ThreadScreen), findsOneWidget);
      await tester.tap(key('thread-category'));
      await settle(tester);
      expect(find.byType(ThreadScreen), findsNothing);
      expect(lastQuery()['categorySlug'], 'technology');
    });

    testWidgets('a discussion deleted from its page leaves the list', (tester) async {
      await pumpForums(
        tester,
        extra: {
          'GET /forum/threads/slug-e': (_) => {..._Board().threads[4], 'bodyHtml': '<p>Mine.</p>', 'canEdit': true},
          'DELETE /forum/threads/e': (_) => {'success': true},
        },
      );
      await tapKey(tester, 'open:e');
      await tester.tap(key('thread-menu'));
      await settle(tester);
      await tester.tap(key('menu-delete'));
      await settle(tester);
      await tester.tap(key('confirm-yes'));
      await settle(tester);
      expect(forums.posts.any((p) => p.id == 'e'), isFalse);
      expect(find.text('5 discussions'), findsOneWidget);
    });
  });

  group('starting a discussion', () {
    Map<String, Handler> posting({String moderation = 'APPROVED'}) => {
      'POST /forum/threads': (o) => {
        ...threadCard('new', title: (o.data as Map)['title'] as String, author: member('me', 'Bharat Buyer')),
        'slug': 'slug-new',
        'bodyHtml': (o.data as Map)['bodyHtml'],
        'moderation': moderation,
        'canEdit': true,
      },
      'GET /forum/threads/slug-new': (_) => {
        ...threadCard('new', title: 'Which BMS do you run?', author: member('me', 'Bharat Buyer')),
        'slug': 'slug-new',
        'bodyHtml': '<p>We run two sites.</p>',
        'moderation': moderation,
        'canEdit': true,
      },
      'GET /forum/threads/slug-new/replies': (_) => page(const []),
      'POST /forum/threads/new/view': (_) => {'success': true},
    };

    Future<void> writeAndPost(WidgetTester tester) async {
      await tester.ensureVisible(key('home-composer'));
      await tester.tap(key('home-composer'));
      await tester.pumpAndSettle();
      await settle(tester);
      expect(find.text('New discussion'), findsOneWidget);
      await tester.tap(key('composer-topic'));
      await tester.pumpAndSettle();
      await tester.tap(key('topic-option:TECHNOLOGY_INNOVATION'));
      await tester.pumpAndSettle();
      await tester.enterText(key('composer-title'), 'Which BMS do you run?');
      await tester.enterText(key('composer-body'), 'We run two sites.');
      await tester.pump();
      await tester.ensureVisible(key('composer-bar-send'));
      await tester.tap(key('composer-bar-send'));
      await settle(tester);
    }

    testWidgets(
      'the bar opens the composer in the topic being browsed; the new discussion opens on its page and joins the list',
      (tester) async {
        await pumpForums(tester, extra: posting());
        await tapKey(tester, 'topic:technology');
        await tester.ensureVisible(key('home-composer'));
        await tester.tap(key('home-composer'));
        await tester.pumpAndSettle();
        await settle(tester);
        // The topic the reader is browsing is the composer's topic.
        expect(find.text('Technology'), findsWidgets);
        await tester.tap(key('composer-close'));
        await tester.pumpAndSettle();

        await writeAndPost(tester);
        expect(api.bodyOf('POST', '/forum/threads')['topicCategory'], 'TECHNOLOGY_INNOVATION');
        expect(find.byType(ThreadScreen), findsOneWidget);
        expect(find.text('We run two sites.'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('Back').first);
        await settle(tester);
        expect(forums.posts.first.id, 'new');
        expect(find.text('Which BMS do you run?'), findsOneWidget);
      },
    );

    testWidgets('a discussion a moderator must read first says so and does not open', (tester) async {
      await pumpForums(tester, extra: posting(moderation: 'PENDING'));
      await writeAndPost(tester);
      expect(find.byType(ThreadScreen), findsNothing);
      expect(snack('A moderator will read it before it goes public.'), findsOneWidget);
    });
  });
}
