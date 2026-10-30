import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/feed/feed_models.dart';
import 'package:icr_mobile/features/forum/composer_controller.dart';
import 'package:icr_mobile/features/forum/forum_models.dart';
import 'package:icr_mobile/features/forum/new_thread_screen.dart';
import 'package:icr_mobile/features/forum/rich_text_controller.dart';

import 'helpers/feed_fixtures.dart';
import 'helpers/fonts.dart';
import 'helpers/forum_fakes.dart';

/// The composer: its rules as a controller, then every control of the screen, over the real repository with only the
/// forum faked. What the portal does in answer is proved by `test/live/forum_live_test.dart`.
void main() {
  setUpAll(loadAppFonts);

  Map<String, Object?> node(String key, String name, String slug, {List<Map<String, Object?>> children = const []}) => {
    'id': key,
    'key': key,
    'name': name,
    'slug': slug,
    'active': true,
    'level': 1,
    'children': children,
  };

  Map<String, Object?> sub(String key, String name, String slug) => {
    'id': key,
    'key': key,
    'name': name,
    'slug': slug,
    'active': true,
    'level': 2,
    'children': <Object?>[],
  };

  Map<String, Handler> routes({
    bool requiresApproval = false,
    String moderation = 'APPROVED',
    Map<String, (int, String)> refusals = const {},
    List<Map<String, Object?>>? taxonomy,
  }) {
    Object? answer(String key, Object? Function() ok) {
      final refused = refusals[key];
      if (refused != null) return (refused.$1, '{"statusCode":${refused.$1},"message":${_json(refused.$2)}}');
      return ok();
    }

    Map<String, Object?> stored(String title, Object? body) => {
      ...threadCard('t-new', title: title, author: member('me', 'Bharat Buyer')),
      'slug': 'slug-new',
      'bodyHtml': body ?? '',
      'moderation': moderation,
      'canEdit': true,
    };

    return {
      'GET /categories/tree': (_) => answer(
        'GET /categories/tree',
        () =>
            taxonomy ??
            [
              node(
                'TECHNOLOGY_INNOVATION',
                'Technology',
                'technology',
                children: [sub('BMS', 'Building Management Systems', 'bms'), sub('IWMS', 'IWMS & CAFM', 'iwms')],
              ),
              node('SUSTAINABILITY_ESG', 'ESG & Sustainability', 'esg-sustainability'),
              node('PROCUREMENT_SUPPLY_CHAIN', 'Procurement & Supply Chain', 'procurement'),
            ],
      ),
      'GET /forum/me': (_) => {
        'reputation': 0,
        'level': 'NEW',
        'requiresApproval': requiresApproval,
        'canModerate': false,
      },
      'GET /members/me/following': (_) => page(const []),
      'POST /forum/threads': (o) =>
          answer('POST /forum/threads', () => stored((o.data as Map)['title'] as String, (o.data as Map)['bodyHtml'])),
      'PATCH /forum/threads/t-q': (o) => answer(
        'PATCH /forum/threads/t-q',
        () => {...ForumWorld(authorId: 'me', canEdit: true).detail(), 'title': (o.data as Map)['title'] ?? 'x'},
      ),
      'POST /uploads': (o) => answer(
        'POST /uploads',
        () => {'url': '/uploads/abc123.png', 'name': 'site.png', 'size': 2048, 'mimeType': 'image/png'},
      ),
    };
  }

  group('the rules', () {
    ComposerController make({ForumThread? editing, ComposerMode mode = ComposerMode.discussion}) {
      final api = FakeForum(routes());
      return ComposerController(repository: forumOn(api), editing: editing, mode: mode);
    }

    test('a new discussion needs a topic, a title of 8 to 160 characters and details', () {
      final c = make();
      expect(c.problems, [
        'Choose the topic this belongs to.',
        'The title needs at least 8 characters.',
        'Add some details so people know what you mean.',
      ]);
      expect(c.canSend, isFalse);
      c.setTitle('Short');
      expect(c.titleProblem, 'The title needs at least 8 characters.');
      c.setTitle('A'.padRight(161, 'a'));
      expect(c.titleProblem, 'The title can be at most 160 characters.');
      c.setTitle('A clear title');
      expect(c.titleProblem, isNull);
      c.setBody('x' * (ForumLimits.bodyMax + 1));
      expect(c.bodyProblem, 'The details can be at most 20000 characters.');
      c.setBody('Details');
      expect(c.bodyProblem, isNull);
      c.dispose();
    });

    test('a poll needs two different options and its details are optional', () {
      final c = make(mode: ComposerMode.poll);
      expect(c.isPoll, isTrue);
      expect(c.bodyOptional, isTrue);
      expect(c.pollProblem, 'A poll needs at least 2 options.');
      c.setPollOption(0, 'Chillers');
      expect(c.pollProblem, 'A poll needs at least 2 options.');
      c.setPollOption(1, '  chillers ');
      expect(c.pollProblem, 'Two options read the same: make each one different.');
      c.setPollOption(1, 'VRF');
      expect(c.pollProblem, isNull);
      expect(c.filledOptions, ['Chillers', 'VRF']);
      // Two to four options.
      c.addPollOption();
      c.addPollOption();
      c.addPollOption();
      expect(c.pollOptions, hasLength(4));
      c.removePollOption(3);
      c.removePollOption(2);
      c.removePollOption(1);
      expect(c.pollOptions, hasLength(2), reason: 'a poll cannot go below two');
      c.dispose();
    });

    test('tags are the forum\'s: no #, lower case, spaces to dashes, 32 characters, five at most, no repeats', () {
      final c = make();
      expect(ComposerController.normaliseTag('  #HVAC Controls '), 'hvac-controls');
      expect(ComposerController.normaliseTag('a' * 40), 'a' * 32);
      expect(c.addTags('HVAC, retrofit,#hvac'), isNull);
      expect(c.tags, ['hvac', 'retrofit']);
      expect(c.addTags('a, b, c, d'), 'A discussion can have at most 5 tags.');
      expect(c.tags, hasLength(5));
      c.removeTag('hvac');
      expect(c.tags, isNot(contains('hvac')));
      c.dispose();
    });

    test('what is sent: a discussion, or a discussion carrying options; a poll\'s options only on a new post', () {
      final c = make(mode: ComposerMode.poll);
      c.setTitle('Which chiller do you run?');
      c.setPollOption(0, 'A');
      c.setPollOption(1, 'B');
      final d = c.draft;
      expect(d.kind, ThreadKind.discussion);
      expect(d.pollOptions, ['A', 'B']);
      expect(d.body, '');
      expect(d.attachment, isNull);
      c.dispose();
    });

    test(
      'an edit starts from the discussion: its words, tags and topic; nothing changed sends no body and no topic',
      () {
        final thread = ForumThread(
          card: FeedPost(
            id: 't-q',
            slug: 'slug-q',
            author: const FeedAuthor(id: 'me', name: 'Bharat'),
            createdAt: DateTime(2026, 10, 1),
            title: 'Original title here',
            body: 'Words',
            tags: const ['#hvac', '#bms'],
            kind: ThreadKind.question,
          ),
          bodyHtml: '<p>Words <strong>bold</strong></p>',
          lastActivityAt: DateTime(2026, 10, 1),
          category: const ForumTopicRef(id: 'c', key: 'TECHNOLOGY_INNOVATION', name: 'Technology', slug: 'technology'),
          subcategory: const ForumTopicRef(id: 's', key: 'RETIRED_SUB', name: 'Retired sub-topic', slug: 'retired'),
          canEdit: true,
        );
        final c = make(editing: thread);
        expect(c.isEdit, isTrue);
        expect(c.title, 'Original title here');
        expect(c.body, 'Words bold');
        expect(c.tags, ['hvac', 'bms']);
        expect(c.topicName, 'Technology');
        expect(c.subtopicName, 'Retired sub-topic');
        expect(c.kind, ThreadKind.question);
        expect(c.changed, isFalse);
        expect(c.hasUnsentWork, isFalse);
        expect(c.canSend, isTrue);
        // The title alone changes: no body (the bold survives), no topic (a retired sub-topic would be refused).
        c.setTitle('A better title for it');
        expect(c.changed, isTrue);
        expect(c.draft.body, isNull);
        expect(c.draft.categoryKey, isNull);
        expect(c.draft.attachment, isNull);
        expect(c.draft.pollOptions, isNull);
        expect(c.draft.kind, ThreadKind.question);
        // Changing the words sends them.
        c.setBody('New words');
        expect(c.draft.body, 'New words');
        expect(c.bodyOptional, isFalse);
        c.dispose();
      },
    );
  });

  group('the screen', () {
    late FakeForum api;
    late ThreadResultHolder holder;

    Future<void> settle(WidgetTester tester) async {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pumpAndSettle();
    }

    Finder key(String k) => find.byKey(ValueKey(k));
    Finder snack(String text) => find.descendant(of: find.byType(SnackBar), matching: find.textContaining(text));

    Future<void> pumpComposer(
      WidgetTester tester, {
      Map<String, Handler>? custom,
      ForumThread? editing,
      ComposerMode mode = ComposerMode.discussion,
      Future<ForumFile?> Function()? pickFile,
      String? topicSlug,
    }) async {
      tester.view.physicalSize = const Size(780, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      api = FakeForum(custom ?? routes());
      holder = ThreadResultHolder();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  key: const ValueKey('open'),
                  onPressed: () async {
                    holder.thread = await openComposer(
                      context,
                      repository: forumOn(api),
                      editing: editing,
                      mode: mode,
                      topicSlug: topicSlug,
                      pickFile: pickFile,
                    );
                    holder.closed = true;
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(key('open'));
      await tester.pumpAndSettle();
      await settle(tester);
    }

    Future<void> fill(WidgetTester tester, {String? title, String? body}) async {
      if (title != null) await tester.enterText(key('composer-title'), title);
      if (body != null) await tester.enterText(key('composer-body'), body);
      await tester.pump();
    }

    Future<void> chooseTopic(WidgetTester tester, String optionKey) async {
      await tester.tap(key('composer-topic'));
      await tester.pumpAndSettle();
      await tester.tap(key('topic-option:$optionKey'));
      await tester.pumpAndSettle();
    }

    Future<void> post(WidgetTester tester) async {
      await tester.ensureVisible(key('composer-bar-send'));
      await tester.pumpAndSettle();
      await tester.tap(key('composer-bar-send'));
      await settle(tester);
    }

    testWidgets(
      'it opens as the website\'s Create a post form: the two kinds, Category, Sub-category, Title, Details, Tags, file',
      (tester) async {
        await pumpComposer(tester);
        expect(find.text('New discussion'), findsOneWidget);
        // The two kinds, side by side as the composer first drew them.
        expect(find.text('Discussion'), findsOneWidget);
        expect(find.text('Ask or share'), findsOneWidget);
        expect(find.text('Poll'), findsOneWidget);
        expect(find.text('Let people vote'), findsOneWidget);
        final discussionBox = tester.getRect(key('mode:discussion'));
        final pollBox = tester.getRect(key('mode:poll'));
        expect(discussionBox.top, pollBox.top);
        expect(pollBox.left, greaterThan(discussionBox.right));
        // Category (required) and Sub-category are both on the form; the fields carry the words, no section headers.
        expect(find.text('Category *'), findsOneWidget);
        expect(find.text('Sub-category (optional)'), findsOneWidget);
        expect(find.text('Title'), findsOneWidget);
        expect(find.text('Details'), findsOneWidget);
        expect(find.text('Tags'), findsOneWidget);
        for (final gone in [
          'TOPIC',
          'YOUR POST',
          'YOUR POLL',
          'Your Post',
          'Poll Question',
          'File',
          'Choose a topic',
        ]) {
          expect(find.text(gone), findsNothing, reason: gone);
        }
        expect(key('composer-title'), findsOneWidget);
        expect(key('composer-body'), findsOneWidget);
        expect(key('composer-tag'), findsOneWidget);
        expect(find.text('Attach a file'), findsOneWidget);
        // The website's helper lines.
        expect(find.text('Specific titles get answered. "Pricing question" does not.'), findsOneWidget);
        expect(find.text('Tags are how someone finds this in six months.'), findsOneWidget);
        expect(
          find.text(
            'Give enough context that someone can actually help — portfolio size, what you have tried, what constraints you are under.',
          ),
          findsOneWidget,
        );
        // The editor: its toolbar and its count.
        for (final tool in ['bold', 'italic', 'heading', 'bullets', 'numbers', 'link']) {
          expect(key('rich-$tool'), findsOneWidget, reason: tool);
        }
        expect(find.text('0 / 20,000'), findsOneWidget);
        // One Post, in the title bar (LinkedIn's); no second button under the form.
        expect(find.descendant(of: key('composer-bar-send'), matching: find.text('Post')), findsOneWidget);
        expect(find.text('Post to the community'), findsNothing);
        expect(find.text('Cancel'), findsNothing);
        expect(key('composer-send'), findsNothing);
        expect(api.count('GET', '/categories/tree'), 1);
        expect(api.count('GET', '/forum/me'), 1);
      },
    );

    testWidgets('a category is chosen from the list, which can be searched; the sub-category waits for one', (
      tester,
    ) async {
      await pumpComposer(tester);
      // Always on the form, greyed until there is a category to pick under.
      bool subEnabled() => tester.widget<InkWell>(key('composer-subtopic')).onTap != null;
      expect(key('composer-subtopic'), findsOneWidget);
      expect(subEnabled(), isFalse);
      await chooseTopic(tester, 'TECHNOLOGY_INNOVATION');
      expect(find.text('Technology'), findsOneWidget);
      expect(subEnabled(), isTrue);
      await tester.tap(key('composer-subtopic'));
      await tester.pumpAndSettle();
      expect(find.text('Sub-category (optional)'), findsWidgets);
      await tester.tap(key('topic-option:BMS'));
      await tester.pumpAndSettle();
      expect(find.text('Building Management Systems'), findsOneWidget);
      // Another category drops the sub-category; one with none leaves the field greyed.
      await chooseTopic(tester, 'SUSTAINABILITY_ESG');
      expect(find.text('Building Management Systems'), findsNothing);
      expect(subEnabled(), isFalse);
      expect(find.text('ESG & Sustainability'), findsOneWidget);
    });

    testWidgets('the Category box searches the whole tree, as the website\'s does: a sub-category hit fills both', (
      tester,
    ) async {
      await pumpComposer(tester);
      await tester.tap(key('composer-topic'));
      await tester.pumpAndSettle();
      // Empty: the categories alone, no sub-categories listed yet.
      expect(find.text('Type a category or sub-category'), findsOneWidget);
      expect(key('topic-option:TECHNOLOGY_INNOVATION'), findsOneWidget);
      expect(key('topic-hit:TECHNOLOGY_INNOVATION:BMS'), findsNothing);
      // A word from a sub-category's name finds it, headed by its category.
      await tester.enterText(key('topic-search'), 'building manage');
      await tester.pumpAndSettle();
      expect(key('topic-group:TECHNOLOGY_INNOVATION'), findsOneWidget);
      expect(key('topic-hit:TECHNOLOGY_INNOVATION:BMS'), findsOneWidget);
      expect(key('topic-option:TECHNOLOGY_INNOVATION'), findsNothing);
      // A word from the category's own name lists the category and what is under it.
      await tester.enterText(key('topic-search'), 'techno');
      await tester.pumpAndSettle();
      expect(key('topic-option:TECHNOLOGY_INNOVATION'), findsOneWidget);
      expect(key('topic-hit:TECHNOLOGY_INNOVATION:BMS'), findsOneWidget);
      // Nothing matching says so.
      await tester.enterText(key('topic-search'), 'zzzz');
      await tester.pumpAndSettle();
      expect(find.text('No matching categories'), findsOneWidget);
      // Picking the hit fills the category and the sub-category.
      await tester.enterText(key('topic-search'), 'building');
      await tester.pumpAndSettle();
      await tester.tap(key('topic-hit:TECHNOLOGY_INNOVATION:BMS'));
      await tester.pumpAndSettle();
      expect(find.text('Technology'), findsOneWidget);
      expect(find.text('Building Management Systems'), findsOneWidget);
    });

    testWidgets('the page the composer was opened from presets its topic', (tester) async {
      await pumpComposer(tester, topicSlug: 'esg-sustainability');
      expect(find.text('ESG & Sustainability'), findsOneWidget);
    });

    testWidgets('sending with something missing says what, and sends nothing', (tester) async {
      await pumpComposer(tester);
      await post(tester);
      expect(api.count('POST', '/forum/threads'), 0);
      // The fields turn red and ONE message says what is first missing, under the form: no line under each field.
      // (The website's helper lines stay grey under their fields.)
      expect(find.text('Choose the topic this belongs to.'), findsOneWidget);
      expect(key('composer-problem'), findsOneWidget);
      expect(find.text('The title needs at least 8 characters.'), findsNothing);
      expect(find.text('Add some details so people know what you mean.'), findsNothing);
      expect(holder.closed, isFalse);
    });

    testWidgets('a discussion is sent as the website composer sends it, and the screen hands back what was stored', (
      tester,
    ) async {
      await pumpComposer(tester);
      await chooseTopic(tester, 'TECHNOLOGY_INNOVATION');
      await tester.tap(key('composer-subtopic'));
      await tester.pumpAndSettle();
      await tester.tap(key('topic-option:BMS'));
      await tester.pumpAndSettle();
      await fill(tester, title: '  Which BMS do you run?  ', body: 'We run <b>two</b> sites.\n\nOne on BACnet.');
      await tester.enterText(key('composer-tag'), 'HVAC, Retro fit,');
      await tester.pump();
      await post(tester);
      expect(api.bodyOf('POST', '/forum/threads'), {
        'topicCategory': 'TECHNOLOGY_INNOVATION',
        'topicSubcategory': 'BMS',
        'title': 'Which BMS do you run?',
        'bodyHtml': '<p>We run &lt;b&gt;two&lt;/b&gt; sites.</p><p>One on BACnet.</p>',
        'kind': 'DISCUSSION',
        'tags': ['hvac', 'retro-fit'],
      });
      expect(holder.closed, isTrue);
      expect(holder.thread?.slug, 'slug-new');
      expect(find.byType(NewThreadScreen), findsNothing);
    });

    testWidgets('a tag typed and not yet added is sent too, a tag chip can be taken off, and a sixth is refused', (
      tester,
    ) async {
      await pumpComposer(tester);
      await tester.enterText(key('composer-tag'), 'a, b, c, d, e');
      await tester.pump();
      expect(find.text('#a'), findsOneWidget);
      expect(find.text('#e'), findsOneWidget);
      expect(key('composer-tag'), findsNothing, reason: 'five tags are the most');
      await tester.tap(key('tag-remove:c'));
      await tester.pump();
      expect(find.text('#c'), findsNothing);
      expect(key('composer-tag'), findsOneWidget);
      await tester.enterText(key('composer-tag'), 'f, g');
      await tester.pump();
      expect(key('tag-note'), findsOneWidget);
      expect(find.text('A discussion can have at most 5 tags.'), findsOneWidget);
    });

    testWidgets('a poll: two to four options, details optional, sent with its options', (tester) async {
      await pumpComposer(tester);
      await tester.tap(key('mode:poll'));
      await tester.pumpAndSettle();
      expect(find.text('New poll'), findsOneWidget);
      // The poll is the same form: the website's words for a poll, in the same fields and the same type.
      expect(find.text('Poll question'), findsOneWidget);
      expect(find.text('Title'), findsNothing);
      expect(find.text('One clear question. Members pick one option.'), findsOneWidget);
      expect(find.text('Category *'), findsOneWidget);
      expect(find.text('Sub-category (optional)'), findsOneWidget);
      expect(find.text('Options'), findsOneWidget);
      expect(find.text('2 of 4'), findsOneWidget);
      expect(find.text('Add option'), findsOneWidget);
      expect(find.text('Members pick one; results show once they have voted.'), findsOneWidget);
      expect(find.text('Details (optional)'), findsOneWidget);
      expect(
        find.text('Add context for voters — why you are asking, and anything the options leave out.'),
        findsOneWidget,
      );
      expect(find.text('Option 1'), findsOneWidget);
      expect(find.text('Option 2'), findsOneWidget);
      expect(key('rich-bold'), findsOneWidget, reason: 'the poll has the same editor');
      expect(key('poll-field:0'), findsOneWidget);
      expect(key('poll-field:1'), findsOneWidget);
      expect(key('poll-remove:0'), findsNothing, reason: 'two is the least');
      await tester.ensureVisible(key('poll-add'));
      await tester.tap(key('poll-add'));
      await tester.pump();
      await tester.tap(key('poll-add'));
      await tester.pump();
      expect(find.text('4 of 4'), findsOneWidget);
      expect(key('poll-field:3'), findsOneWidget);
      expect(key('poll-add'), findsNothing, reason: 'four is the most');
      await tester.tap(key('poll-remove:3'));
      await tester.pump();
      expect(key('poll-field:3'), findsNothing);

      await chooseTopic(tester, 'PROCUREMENT_SUPPLY_CHAIN');
      await fill(tester, title: 'What do you use?');
      await tester.enterText(key('poll-field:0'), 'Chillers');
      await tester.enterText(key('poll-field:1'), 'chillers');
      await tester.pump();
      // No line under the options while typing; sending says it, once, under the form.
      expect(key('poll-problem'), findsNothing);
      await post(tester);
      expect(api.count('POST', '/forum/threads'), 0);
      expect(find.text('Two options read the same: make each one different.'), findsOneWidget);
      await tester.enterText(key('poll-field:1'), 'Split units');
      await tester.enterText(key('poll-field:2'), 'VRF');
      await tester.pump();
      await post(tester);
      expect(api.bodyOf('POST', '/forum/threads'), {
        'topicCategory': 'PROCUREMENT_SUPPLY_CHAIN',
        'topicSubcategory': null,
        'title': 'What do you use?',
        'bodyHtml': '',
        'kind': 'DISCUSSION',
        'tags': <String>[],
        'pollOptions': ['Chillers', 'Split units', 'VRF'],
      });
      expect(holder.closed, isTrue);
    });

    testWidgets('the API\'s refusal reads at the top and everything typed stays; the next send can succeed', (
      tester,
    ) async {
      final refusals = <String, (int, String)>{'POST /forum/threads': (400, 'Pick a category that exists.')};
      await pumpComposer(tester, custom: routes(refusals: refusals));
      await chooseTopic(tester, 'TECHNOLOGY_INNOVATION');
      await fill(tester, title: 'A title that is long enough', body: 'Some details');
      await tester.enterText(key('composer-tag'), 'hvac,');
      await tester.pump();
      await post(tester);
      expect(key('composer-error'), findsOneWidget);
      expect(find.text('Pick a category that exists.'), findsOneWidget);
      expect(holder.closed, isFalse);
      expect(tester.widget<TextField>(key('composer-title')).controller!.text, 'A title that is long enough');
      expect(tester.widget<TextField>(key('composer-body')).controller!.text, 'Some details');
      expect(find.text('#hvac'), findsOneWidget);
      expect(find.text('Technology'), findsOneWidget);
      refusals.clear();
      await post(tester);
      expect(holder.closed, isTrue);
      expect(api.count('POST', '/forum/threads'), 2);
    });

    testWidgets('a validation failure lists every sentence the API gave', (tester) async {
      final refusals = {'POST /forum/threads': (400, 'title must be longer than or equal to 8 characters')};
      await pumpComposer(tester, custom: routes(refusals: refusals));
      await chooseTopic(tester, 'TECHNOLOGY_INNOVATION');
      await fill(tester, title: 'A title that is long enough', body: 'x');
      await post(tester);
      expect(find.text('title must be longer than or equal to 8 characters'), findsOneWidget);
    });

    testWidgets('a reader whose posts are reviewed first is told so', (tester) async {
      await pumpComposer(tester, custom: routes(requiresApproval: true));
      expect(key('composer-approval'), findsOneWidget);
    });

    testWidgets('topics that fail to load say so and Try again reads them', (tester) async {
      final refusals = <String, (int, String)>{'GET /categories/tree': (500, 'No taxonomy')};
      await pumpComposer(tester, custom: routes(refusals: refusals));
      expect(find.textContaining("Couldn't load the categories"), findsOneWidget);
      refusals.clear();
      await tester.tap(key('topics-retry'));
      await settle(tester);
      expect(find.text('Category *'), findsOneWidget);
      expect(key('composer-topic'), findsOneWidget);
    });

    testWidgets('a photo or PDF is picked, uploaded and shown; its x takes it off; it is sent with the discussion', (
      tester,
    ) async {
      var picks = 0;
      await pumpComposer(
        tester,
        pickFile: () async {
          picks++;
          return const ForumFile(bytes: [1, 2, 3], name: 'site.png');
        },
      );
      await chooseTopic(tester, 'TECHNOLOGY_INNOVATION');
      await fill(tester, title: 'A title that is long enough', body: 'Some details');
      await tester.ensureVisible(key('composer-attach'));
      await tester.tap(key('composer-attach'));
      await settle(tester);
      expect(picks, 1);
      expect(find.text('site.png · 2 KB'), findsOneWidget);
      expect(api.to('POST', '/uploads').single.queryParameters, {'purpose': 'forum-attachment'});
      expect(find.text('Replace attachment'), findsOneWidget);
      await tester.tap(key('attachment-remove'));
      await tester.pump();
      expect(key('composer-file'), findsNothing);
      await tester.tap(key('composer-attach'));
      await settle(tester);
      await post(tester);
      expect(api.bodyOf('POST', '/forum/threads')['uploadId'], 'abc123.png');
      expect(api.bodyOf('POST', '/forum/threads')['fileName'], 'site.png');
      expect(api.bodyOf('POST', '/forum/threads')['fileSize'], 2048);
    });

    testWidgets('a file the forum refuses says why and attaches nothing; backing out of the chooser does nothing', (
      tester,
    ) async {
      var answer = const ForumFile(bytes: [1], name: 'notes.docx');
      var cancel = true;
      final refusals = {
        'POST /uploads': (400, 'application/octet-stream is not an accepted file type for this upload.'),
      };
      await pumpComposer(
        tester,
        custom: routes(refusals: refusals),
        pickFile: () async => cancel ? null : answer,
      );
      await tester.ensureVisible(key('composer-attach'));
      await tester.tap(key('composer-attach'));
      await settle(tester);
      expect(api.count('POST', '/uploads'), 0);
      cancel = false;
      await tester.tap(key('composer-attach'));
      await settle(tester);
      expect(snack('is not an accepted file type'), findsOneWidget);
      expect(key('composer-file'), findsNothing);
      expect(answer.name, 'notes.docx');
    });

    testWidgets('the toolbar formats what is written, and the HTML sent carries it', (tester) async {
      await pumpComposer(tester);
      await chooseTopic(tester, 'PROCUREMENT_SUPPLY_CHAIN');
      await fill(tester, title: 'How do you price retrofits?');
      final body = tester.widget<TextField>(key('composer-body')).controller! as RichTextController;
      await tester.enterText(key('composer-body'), 'Heading line\nPlan the retrofit\nfirst\nsecond\none\ntwo');
      await tester.pump();

      Future<void> select(String from, String to) async {
        final a = body.text.indexOf(from);
        final b = body.text.indexOf(to) + to.length;
        body.selection = TextSelection(baseOffset: a, extentOffset: b);
        await tester.pump();
      }

      Future<void> tool(String name) async {
        await tester.ensureVisible(key('rich-$name'));
        await tester.tap(key('rich-$name'));
        await tester.pump();
      }

      await select('Heading', 'Heading');
      await tool('heading');
      expect(body.isHeading, isTrue);
      await select('retrofit', 'retrofit');
      await tool('bold');
      expect(body.isBold, isTrue);
      await select('Plan', 'Plan');
      await tool('italic');
      expect(body.isItalic, isTrue);
      await select('first', 'second');
      await tool('bullets');
      expect(body.isBulleted, isTrue);
      await select('one', 'two');
      await tool('numbers');
      expect(body.isNumbered, isTrue);
      expect(body.text, 'Heading line\nPlan the retrofit\n• first\n• second\n1. one\n2. two');
      // The link: the button waits for words, then asks for the address (https:// is added).
      body.selection = TextSelection.collapsed(offset: body.text.indexOf('Plan'));
      await tester.pump();
      await select('the', 'the');
      await tool('link');
      await tester.pumpAndSettle();
      await tester.enterText(key('link-url'), 'icr.org.in/guide');
      await tester.pump();
      await tester.tap(key('link-apply'));
      await tester.pumpAndSettle();
      expect(body.currentLink, 'https://icr.org.in/guide');
      // The count is the words alone.
      expect(find.text('${body.plainLength} / 20,000'), findsOneWidget);

      await post(tester);
      expect(
        api.bodyOf('POST', '/forum/threads')['bodyHtml'],
        '<h3>Heading line</h3><p><em>Plan</em> <a href="https://icr.org.in/guide">the</a> <strong>retrofit</strong></p>'
        '<ul><li>first</li><li>second</li></ul><ol><li>one</li><li>two</li></ol>',
      );
    });

    testWidgets('the link button waits for words to link; a bad address cannot be applied', (tester) async {
      await pumpComposer(tester);
      final body = tester.widget<TextField>(key('composer-body')).controller! as RichTextController;
      expect(tester.widget<InkResponse>(key('rich-link')).onTap, isNull, reason: 'nothing selected');
      await tester.enterText(key('composer-body'), 'Read this');
      body.selection = const TextSelection(baseOffset: 5, extentOffset: 9);
      await tester.pump();
      expect(tester.widget<InkResponse>(key('rich-link')).onTap, isNotNull);
      await tester.ensureVisible(key('rich-link'));
      await tester.tap(key('rich-link'));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(key('link-apply')).onPressed, isNull, reason: 'no address yet');
      await tester.enterText(key('link-url'), 'not an address');
      await tester.pump();
      expect(tester.widget<FilledButton>(key('link-apply')).onPressed, isNull);
      await tester.enterText(key('link-url'), 'javascript:alert(1)');
      await tester.pump();
      expect(tester.widget<FilledButton>(key('link-apply')).onPressed, isNull);
      await tester.enterText(key('link-url'), 'mailto:ops@icr.org.in');
      await tester.pump();
      await tester.tap(key('link-apply'));
      await tester.pumpAndSettle();
      expect(body.doc.toHtml(), '<p>Read <a href="mailto:ops@icr.org.in">this</a></p>');
    });

    testWidgets('a post and a poll are one form in one type', (tester) async {
      await pumpComposer(tester);
      final post = tester.widget<TextField>(key('composer-title')).style!;
      expect(post.fontSize, 16);
      expect(post.fontFamily, 'Roboto');
      await tester.tap(key('mode:poll'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(key('composer-title')).style, post);
      expect(tester.widget<TextField>(key('poll-field:0')).style, post);
      expect(tester.widget<TextField>(key('composer-body')).style, post);
      expect(tester.widget<TextField>(key('composer-tag')).style, post);
    });

    testWidgets('a poll\'s details are optional and rich: they go as HTML beside the options', (tester) async {
      await pumpComposer(tester, mode: ComposerMode.poll);
      await chooseTopic(tester, 'PROCUREMENT_SUPPLY_CHAIN');
      await fill(tester, title: 'What do you use?');
      await tester.enterText(key('poll-field:0'), 'Chillers');
      await tester.enterText(key('poll-field:1'), 'VRF');
      final body = tester.widget<TextField>(key('composer-body')).controller! as RichTextController;
      await tester.enterText(key('composer-body'), 'Context <for> voters');
      body.selection = TextSelection(baseOffset: 0, extentOffset: body.text.length);
      await tester.pump();
      await tester.ensureVisible(key('rich-bold'));
      await tester.tap(key('rich-bold'));
      await tester.pump();
      await post(tester);
      final sent = api.bodyOf('POST', '/forum/threads');
      expect(sent['bodyHtml'], '<p><strong>Context &lt;for&gt; voters</strong></p>');
      expect(sent['pollOptions'], ['Chillers', 'VRF']);
    });

    testWidgets('leaving with something written asks first; leaving a blank form does not', (tester) async {
      await pumpComposer(tester);
      await tester.tap(key('composer-close'));
      await tester.pumpAndSettle();
      expect(find.byType(NewThreadScreen), findsNothing);

      await tester.tap(key('open'));
      await tester.pumpAndSettle();
      await fill(tester, title: 'Half written');
      await tester.tap(key('composer-close'));
      await tester.pumpAndSettle();
      expect(find.text('Discard this draft?'), findsOneWidget);
      await tester.tap(key('confirm-cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(NewThreadScreen), findsOneWidget);
      expect(tester.widget<TextField>(key('composer-title')).controller!.text, 'Half written');
      await tester.tap(key('composer-close'));
      await tester.pumpAndSettle();
      await tester.tap(key('confirm-yes'));
      await tester.pumpAndSettle();
      expect(find.byType(NewThreadScreen), findsNothing);
      expect(holder.thread, isNull);
    });
  });

  group('editing', () {
    Future<void> settle(WidgetTester tester) async {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pumpAndSettle();
    }

    Finder key(String k) => find.byKey(ValueKey(k));

    late FakeForum api;
    ForumThread? saved;
    var closed = false;

    ForumThread existing({String html = '<p>Words <strong>bold</strong></p>', ForumAttachment? attachment}) =>
        ForumThread(
          card: FeedPost(
            id: 't-q',
            slug: 'slug-q',
            author: const FeedAuthor(id: 'me', name: 'Bharat'),
            createdAt: DateTime(2026, 10, 1),
            title: 'Original title here',
            body: 'Words bold',
            tags: const ['#hvac'],
            kind: ThreadKind.question,
          ),
          bodyHtml: html,
          lastActivityAt: DateTime(2026, 10, 1),
          category: const ForumTopicRef(id: 'c', key: 'TECHNOLOGY_INNOVATION', name: 'Technology', slug: 'technology'),
          attachment: attachment,
          canEdit: true,
        );

    Future<void> pumpEdit(WidgetTester tester, ForumThread thread, {Future<ForumFile?> Function()? pickFile}) async {
      tester.view.physicalSize = const Size(780, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      api = FakeForum(routes());
      saved = null;
      closed = false;
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                key: const ValueKey('open'),
                onPressed: () async {
                  saved = await openComposer(context, repository: forumOn(api), editing: thread, pickFile: pickFile);
                  closed = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(key('open'));
      await tester.pumpAndSettle();
      await settle(tester);
    }

    testWidgets('it opens on the discussion as it is: title, words, tags, topic, with no choice of kind', (
      tester,
    ) async {
      await pumpEdit(tester, existing());
      expect(find.text('Edit discussion'), findsOneWidget);
      expect(tester.widget<TextField>(key('composer-title')).controller!.text, 'Original title here');
      expect(tester.widget<TextField>(key('composer-body')).controller!.text, 'Words bold');
      expect(find.text('#hvac'), findsOneWidget);
      expect(find.text('Technology'), findsOneWidget);
      expect(key('mode:poll'), findsNothing);
      expect(find.descendant(of: key('composer-bar-send'), matching: find.text('Save')), findsOneWidget);
      expect(find.text('Save changes'), findsNothing);
    });

    testWidgets('a changed title alone sends the title and tags, no body, no topic, and keeps the kind', (
      tester,
    ) async {
      await pumpEdit(tester, existing());
      await tester.enterText(key('composer-title'), 'A better title for it');
      await tester.pump();
      await tester.ensureVisible(key('composer-bar-send'));
      await tester.tap(key('composer-bar-send'));
      await settle(tester);
      final body = api.bodyOf('PATCH', '/forum/threads/t-q');
      expect(body, {
        'title': 'A better title for it',
        'kind': 'QUESTION',
        'tags': ['hvac'],
      });
      expect(closed, isTrue);
      expect(saved, isNotNull);
    });

    testWidgets('a post with website formatting opens with its formatting, sends it back when the words change', (
      tester,
    ) async {
      await pumpEdit(
        tester,
        existing(
          html:
              '<h3>Plan</h3><p>Words <strong>bold</strong> and <em>slanted</em>, see <a href="https://icr.org.in/x">this</a></p>'
              '<ul><li>BMS</li><li>BACnet</li></ul><ol><li>one</li><li>two</li></ol>',
        ),
      );
      final body = tester.widget<TextField>(key('composer-body')).controller! as RichTextController;
      expect(body.text, 'Plan\nWords bold and slanted, see this\n• BMS\n• BACnet\n1. one\n2. two');
      // No "this will replace the formatting" warning: the editor holds all of it.
      expect(key('composer-rich-note'), findsNothing);
      // Add a word at the end of the paragraph: the rest keeps its formatting.
      final at = body.text.indexOf('this') + 4;
      body.value = TextEditingValue(
        text: body.text.replaceRange(at, at, '!'),
        selection: TextSelection.collapsed(offset: at + 1),
      );
      await tester.pump();
      expect(key('composer-rich-note'), findsNothing);
      await tester.ensureVisible(key('composer-bar-send'));
      await tester.tap(key('composer-bar-send'));
      await settle(tester);
      expect(
        api.bodyOf('PATCH', '/forum/threads/t-q')['bodyHtml'],
        '<h3>Plan</h3><p>Words <strong>bold</strong> and <em>slanted</em>, see <a href="https://icr.org.in/x">this</a>!</p>'
        '<ul><li>BMS</li><li>BACnet</li></ul><ol><li>one</li><li>two</li></ol>',
      );
    });

    testWidgets(
      'typing over all of the words sends the new ones; a quote or code from the website says it will flatten',
      (tester) async {
        await pumpEdit(tester, existing());
        expect(key('composer-rich-note'), findsNothing);
        await tester.enterText(key('composer-body'), 'New words only');
        await tester.pump();
        expect(key('composer-rich-note'), findsNothing);
        await tester.ensureVisible(key('composer-bar-send'));
        await tester.tap(key('composer-bar-send'));
        await settle(tester);
        expect(api.bodyOf('PATCH', '/forum/threads/t-q')['bodyHtml'], '<p>New words only</p>');
      },
    );

    testWidgets('a quote from the website is shown as a paragraph, with a note once its words change', (tester) async {
      await pumpEdit(tester, existing(html: '<blockquote>Said once</blockquote><p>And then</p>'));
      expect(key('composer-rich-note'), findsNothing);
      final body = tester.widget<TextField>(key('composer-body')).controller! as RichTextController;
      expect(body.text, 'Said once\nAnd then');
      await tester.enterText(key('composer-body'), 'Said once\nAnd then more');
      await tester.pump();
      expect(key('composer-rich-note'), findsOneWidget);
    });

    testWidgets('the details cannot be emptied on an edit', (tester) async {
      await pumpEdit(tester, existing(html: '<p>Plain words</p>'));
      await tester.enterText(key('composer-body'), 'Different');
      await tester.pump();
      expect(key('composer-rich-note'), findsNothing);
      await tester.enterText(key('composer-body'), '');
      await tester.pump();
      await tester.ensureVisible(key('composer-bar-send'));
      await tester.tap(key('composer-bar-send'));
      await settle(tester);
      expect(api.count('PATCH', '/forum/threads/t-q'), 0);
      expect(find.text('Add some details so people know what you mean.'), findsWidgets);
    });

    testWidgets('a file the discussion carries can only be replaced, never taken off; a new one is sent', (
      tester,
    ) async {
      await pumpEdit(
        tester,
        existing(
          attachment: const ForumAttachment(uploadId: 'old.pdf', fileName: 'Old spec.pdf', fileSize: 1024),
        ),
        pickFile: () async => const ForumFile(bytes: [9], name: 'site.png'),
      );
      expect(find.text('Old spec.pdf · 1 KB'), findsOneWidget);
      expect(key('attachment-remove'), findsNothing);
      expect(find.text('Replace attachment'), findsOneWidget);
      await tester.ensureVisible(key('composer-attach'));
      await tester.tap(key('composer-attach'));
      await settle(tester);
      expect(find.text('site.png · 2 KB'), findsOneWidget);
      expect(key('attachment-remove'), findsOneWidget, reason: 'a file chosen now can be taken back');
      await tester.ensureVisible(key('composer-bar-send'));
      await tester.tap(key('composer-bar-send'));
      await settle(tester);
      expect(api.bodyOf('PATCH', '/forum/threads/t-q')['uploadId'], 'abc123.png');
    });

    testWidgets(
      'an edit that leaves the file alone does not send it again (the forum checks ownership of a sent file)',
      (tester) async {
        await pumpEdit(
          tester,
          existing(
            attachment: const ForumAttachment(uploadId: 'old.pdf', fileName: 'Old spec.pdf', fileSize: 1024),
          ),
        );
        await tester.enterText(key('composer-title'), 'A better title for it');
        await tester.pump();
        await tester.ensureVisible(key('composer-bar-send'));
        await tester.tap(key('composer-bar-send'));
        await settle(tester);
        expect(api.bodyOf('PATCH', '/forum/threads/t-q').containsKey('uploadId'), isFalse);
      },
    );

    testWidgets('leaving after a change asks; leaving untouched does not', (tester) async {
      await pumpEdit(tester, existing());
      await tester.tap(key('composer-close'));
      await tester.pumpAndSettle();
      expect(closed, isTrue);
      await tester.tap(key('open'));
      await tester.pumpAndSettle();
      await tester.enterText(key('composer-title'), 'Changed my mind');
      await tester.pump();
      await tester.tap(key('composer-close'));
      await tester.pumpAndSettle();
      expect(find.text('Discard your changes?'), findsOneWidget);
    });
  });
}

class ThreadResultHolder {
  ForumThread? thread;
  bool closed = false;
}

String _json(String s) => '"${s.replaceAll('"', '\\"')}"';
