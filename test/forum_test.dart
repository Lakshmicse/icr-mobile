import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/features/feed/feed_models.dart';
import 'package:icr_mobile/features/feed/forum_json.dart';
import 'package:icr_mobile/features/feed/post_reactions.dart';
import 'package:icr_mobile/features/forum/api_forum_repository.dart';
import 'package:icr_mobile/features/forum/forum_html.dart';
import 'package:icr_mobile/features/forum/forum_models.dart';
import 'package:icr_mobile/features/forum/reply_tree.dart';
import 'package:icr_mobile/features/forum/thread_controller.dart';

import 'helpers/feed_fixtures.dart';
import 'helpers/forum_fakes.dart';

/// The forum's mapping and rules without a screen. The JSON in `test/fixtures/forum/` is the portal's own: each file
/// was read from the running API (`GET /forum/threads`, `/forum/threads/:slug`, `/replies`, `/categories`...), so a
/// parser here is proved against what the forum really sends, not against what a builder expected.
Object? fixture(String name) => jsonDecode(File('test/fixtures/forum/$name.json').readAsStringSync());

void main() {
  late FakeForum api;
  late ApiForumRepository repo;

  setUp(() {
    api = FakeForum({
      'GET /forum/threads': (_) => fixture('threads_list'),
      'GET /forum/threads/sarah': (_) => fixture('thread_sarah'),
      'GET /forum/threads/sarah/replies': (_) => fixture('replies_sarah'),
      'GET /forum/threads/poll': (_) => fixture('thread_poll'),
      'GET /forum/categories': (_) => fixture('categories'),
      'GET /categories/tree': (_) => fixture('taxonomy'),
      'GET /forum/me': (_) => fixture('me'),
      'GET /notifications/unread-count': (_) => fixture('unread'),
      'GET /members/me/following': (_) => fixture('following'),
      'GET /forum/threads/design-home-thread-sarah/reactions': (_) => fixture('reactions'),
      'GET /forum/threads/design-home-thread-sarah/viewers': (_) => fixture('viewers'),
    });
    repo = forumOn(api, viewerId: 'someone-else');
  });

  group('what the forum really sends', () {
    test('a discussion: filing, author, counts, reactions, the reader\'s state', () async {
      final thread = await repo.thread('sarah');
      final card = thread.card;
      expect(card.title, 'Implementing IoT sensors for HVAC efficiency: Best practices?');
      expect(card.slug, startsWith('implementing-iot-sensors'));
      expect(card.kind, ThreadKind.question);
      expect(card.tags, ['#HVAC', '#PropTech', '#SmartBMS']);
      expect(thread.category?.key, 'SUSTAINABILITY_ESG');
      expect(thread.category?.name, 'ESG & Sustainability');
      expect(thread.subcategory?.name, 'Sustainability');
      expect(card.topic, 'Sustainability');
      expect(card.topicTone, TopicTone.green);
      expect(card.author.name, 'Sarah Jenkins');
      expect(card.author.headline, 'Senior Facilities Manager at Google');
      // An upload path becomes an address beside the API, outside its /api/v1 prefix.
      expect(card.author.photo?.url, 'http://api.test/uploads/design-home-avatar_sarah.jpg');
      expect(card.comments, 52);
      expect(card.views, 4210);
      expect(card.reactions, 184);
      expect(card.reactionCounts, {ReactionKind.like: 104, ReactionKind.insightful: 50, ReactionKind.celebrate: 30});
      // The stack is the three most used kinds, most first.
      expect(card.reactionKinds, [ReactionKind.like, ReactionKind.insightful, ReactionKind.celebrate]);
      expect(card.myReaction, isNull);
      expect(card.saved, isFalse);
      expect(card.answered, isFalse);
      expect(card.locked, isFalse);
      expect(card.pinned, isTrue);
      expect(thread.status, 'OPEN');
      expect(thread.moderation, 'APPROVED');
      expect(thread.open, isTrue);
      expect(thread.canEdit, isFalse);
      expect(thread.canModerate, isFalse);
      expect(thread.subscribed, isFalse);
      expect(thread.attachment, isNull);
      expect(thread.bodyHtml, startsWith('<p>We are currently looking to retrofit'));
      expect(card.body, startsWith('We are currently looking to retrofit'));
      expect(thread.lastActivityAt.isUtc, isTrue);
    });

    test('the author is follow-able unless the reader already follows them or is them', () async {
      // The captured following list holds other people.
      expect((await repo.thread('sarah')).followsAuthor, isFalse);
      final own = forumOn(api, viewerId: 'design-home-user-sarah');
      final mine = await own.thread('sarah');
      expect(mine.card.showFollow, isFalse);
    });

    test('a poll: options, votes, the reader\'s option, open while the discussion is', () async {
      final thread = await repo.thread('poll');
      final poll = thread.card.poll!;
      expect(poll.options.map((o) => o.label), ['IBM TRIRIGA', 'Planon', 'Archibus', 'Other / Custom In-House']);
      expect(poll.totalVotes, 192);
      expect(poll.myOptionId, 'design-home-poll-marcus-opt3');
      expect(poll.open, isTrue);
      expect(poll.percents.reduce((a, b) => a + b), 100);
      expect(thread.card.topic, 'Poll');
    });

    test('the replies: nested, with each author\'s role and company read from their headline', () async {
      final page = await repo.replies('sarah');
      expect(page.total, 52);
      expect(page.hasMore, isFalse);
      expect(page.replies, hasLength(6));
      final first = page.replies.first;
      expect(first.author.name, 'Arvind Swamy');
      expect(first.role, 'General Counsel');
      expect(first.meta, 'Brookfield Properties');
      expect(first.likes, 3);
      expect(first.liked, isFalse);
      expect(first.children, hasLength(6));
      expect(first.children.first.children, hasLength(2));
      expect(first.children.first.children.first.children, hasLength(1));
      expect(flattenReplies(page.replies).length, greaterThan(6));
      expect(first.children.first.parentId, first.id);
      // A headline that names no company is the line under the name, whole, with no role chip.
      final vikram = page.replies.firstWhere((r) => r.author.name.startsWith('Vikram'));
      expect(vikram.role, isNull);
      expect(vikram.meta, startsWith('Smart buildings, BMS and the IoT retrofit'));
      expect(vikram.body, isNotEmpty);
      expect(vikram.canEdit, isFalse);
      expect(vikram.accepted, isFalse);
    });

    test('a page of discussions, the way the Home feed and the Forums tab both read it', () async {
      final page = await repo.threads(const ForumQuery());
      expect(page.posts, hasLength(4));
      expect(page.hasMore, isTrue);
      expect(page.total, 9);
      expect(page.posts.first.pinned, isTrue);
      final marcus = page.posts.firstWhere((p) => p.poll != null);
      expect(marcus.title, 'What is your primary FM Software in 2026?');
      expect(marcus.topic, 'Poll');
      // "Follow" is offered for everyone the reader does not follow, and not for themselves.
      expect(page.posts.every((p) => p.showFollow || p.author.id == 'someone-else'), isTrue);
    });

    test('topics, the composer\'s taxonomy, the reader\'s standing, the bell', () async {
      final topics = await repo.topics();
      expect(topics.map((t) => t.name), contains('Technology'));
      expect(topics.first.threadCount, greaterThan(0));
      expect(topics.first.slug, isNotEmpty);
      expect(topics.first.blurb, isNotNull);

      final taxonomy = await repo.taxonomy();
      expect(taxonomy, isNotEmpty);
      expect(taxonomy.first.key, 'CORPORATE_REAL_ESTATE');
      expect(taxonomy.first.children.first.key, 'REAL_ESTATE_ADVISORY');
      // The taxonomy is read once and kept.
      await repo.taxonomy();
      expect(api.count('GET', '/categories/tree'), 1);
      expect(api.to('GET', '/categories/tree').single.queryParameters, {'kind': 'SERVICE', 'depth': 2});

      final access = await repo.access();
      expect(access.level, 'NEW');
      expect(access.levelLabel, 'New member');
      expect(access.requiresApproval, isFalse);
      expect(await repo.unreadNotifications(), (fixture('unread') as Map)['unread']);
    });

    test('who reacted and who viewed', () async {
      final reactors = await repo.reactors('design-home-thread-sarah');
      expect(reactors, isNotEmpty);
      expect(reactors.first.person.name, isNotEmpty);
      expect(reactors.first.reaction, ReactionKind.like);
      final viewers = await repo.viewers('design-home-thread-sarah');
      expect(viewers.viewers, isEmpty);
      expect(viewers.hidden, 0);
      expect(viewers.total, 0);
    });
  });

  group('what the app asks the forum for', () {
    Map<String, dynamic> lastList() => api.to('GET', '/forum/threads').last.queryParameters;

    test('each view of the Forums tab is the forum\'s own filter', () async {
      await repo.threads(const ForumQuery(view: ForumView.saved));
      expect(lastList()['savedOnly'], true);
      await repo.threads(const ForumQuery(view: ForumView.mine));
      expect(lastList()['mineOnly'], true);
      await repo.threads(const ForumQuery(view: ForumView.trending));
      expect(lastList()['sort'], 'top');
      await repo.threads(const ForumQuery(view: ForumView.unanswered));
      expect(lastList()['sort'], 'unanswered');
      await repo.threads(const ForumQuery(sort: ForumSort.newest));
      expect(lastList()['sort'], 'newest');
    });

    test('search, tag, topic, sub-topic and kind are sent as the website sends them', () async {
      await repo.threads(
        const ForumQuery(
          search: '  chillers ',
          tag: 'HVAC',
          category: ForumTopic(id: 'c', name: 'Technology', slug: 'technology'),
          subcategory: TaxonomyNode(key: 'BMS', name: 'BMS', slug: 'bms'),
          kind: ForumKindFilter.questions,
        ),
        page: 2,
      );
      expect(lastList(), {
        'page': 2,
        'limit': 20,
        'sort': 'latest',
        'search': 'chillers',
        'tag': 'HVAC',
        'categorySlug': 'technology',
        'subcategorySlug': 'bms',
        'kind': 'QUESTION',
      });
    });

    test('a new discussion is the website composer\'s body: escaped paragraphs, tags, a poll\'s options', () async {
      final a = FakeForum({
        'POST /forum/threads': (o) => fixture('thread_sarah'),
        'GET /members/me/following': (_) => fixture('following'),
      });
      final r = forumOn(a);
      await r.create(
        const ForumDraft(
          categoryKey: 'TECHNOLOGY_INNOVATION',
          subcategoryKey: 'BMS',
          title: '  What chiller do you run?  ',
          body: 'Line one <b>bold?</b>\n\nSecond paragraph\nsame paragraph',
          tags: ['hvac'],
          pollOptions: ['A', ' ', 'B'],
        ),
      );
      final body = a.bodyOf('POST', '/forum/threads');
      expect(body, {
        'topicCategory': 'TECHNOLOGY_INNOVATION',
        'topicSubcategory': 'BMS',
        'title': 'What chiller do you run?',
        'bodyHtml': '<p>Line one &lt;b&gt;bold?&lt;/b&gt;</p><p>Second paragraph<br>same paragraph</p>',
        'kind': 'DISCUSSION',
        'tags': ['hvac'],
        'pollOptions': ['A', 'B'],
      });
    });

    test('an edit that leaves the body alone sends no body, so the website\'s formatting survives', () async {
      final a = FakeForum({'PATCH /forum/threads/t1': (_) => fixture('thread_sarah')});
      final r = forumOn(a);
      await r.update('t1', const ForumDraft(categoryKey: 'TECHNOLOGY_INNOVATION', title: 'A new title here', body: null));
      expect(a.bodyOf('PATCH', '/forum/threads/t1').containsKey('bodyHtml'), isFalse);
      // A poll cannot be changed once posted: an edit never sends options.
      await r.update(
        't1',
        const ForumDraft(categoryKey: 'TECHNOLOGY_INNOVATION', title: 'A new title here', body: 'x', pollOptions: ['A', 'B']),
      );
      expect(a.bodyOf('PATCH', '/forum/threads/t1').containsKey('pollOptions'), isFalse);
    });
  });

  group('the reply tree', () {
    FeedReply reply(String id, {String? parent, List<FeedReply> kids = const []}) => FeedReply(
      id: id,
      author: const FeedAuthor(id: 'a', name: 'A'),
      body: id,
      createdAt: DateTime(2026, 10, 24),
      parentId: parent,
      children: kids,
    );

    test('a second page is laid under the first: an answer goes back under its parent', () {
      final first = [
        reply('r1', kids: [reply('r2', parent: 'r1')]),
        reply('r3'),
      ];
      final second = [
        reply('r4', parent: 'r1'), // the forum promoted it: its parent is on page 1
        reply('r5', parent: 'r2'),
        reply('r6'),
      ];
      final merged = mergeReplyPages(first, second);
      expect(merged.map((r) => r.id), ['r1', 'r3', 'r6']);
      expect(merged.first.children.map((r) => r.id), ['r2', 'r4']);
      expect(merged.first.children.first.children.map((r) => r.id), ['r5']);
      expect(countReplies(merged), 6);
    });

    test('a reply read twice is kept once, the newer copy winning', () {
      final merged = mergeReplyPages([reply('r1')], [reply('r1').copyWith(likes: 9)]);
      expect(merged, hasLength(1));
      expect(merged.single.likes, 9);
    });

    test('a reply whose parent is nowhere stays at the top, as the forum shows it', () {
      expect(mergeReplyPages(const [], [reply('x', parent: 'gone')]).single.id, 'x');
      expect(insertReply([reply('a')], reply('b', parent: 'gone')).map((r) => r.id), ['a', 'b']);
    });

    test('a reply sent joins its parent, or the end', () {
      final tree = [reply('r1', kids: [reply('r2', parent: 'r1')])];
      expect(findReply(insertReply(tree, reply('r3', parent: 'r2')), 'r2')!.children.single.id, 'r3');
      expect(insertReply(tree, reply('r4')).map((r) => r.id), ['r1', 'r4']);
    });

    test('deleting a reply leaves its answers in the thread, at the top', () {
      final tree = [
        reply('r1', kids: [reply('r2', parent: 'r1', kids: [reply('r3', parent: 'r2')])]),
        reply('r4'),
      ];
      final after = removeReplyKeepAnswers(tree, 'r2');
      expect(after.map((r) => r.id), ['r1', 'r4', 'r3']);
      expect(findReply(after, 'r2'), isNull);
      expect(findReply(after, 'r1')!.children, isEmpty);
    });

    test('accepting an answer marks that one and no other, and lifts it first', () {
      final tree = [reply('r1'), reply('r2', kids: [reply('r3', parent: 'r2')])];
      final accepted = markAccepted(markAccepted(tree, 'r1'), 'r3');
      expect(accepted.every((r) => !r.accepted), isTrue);
      expect(findReply(accepted, 'r3')!.accepted, isTrue);
      final first = markAccepted(tree, 'r2');
      expect(first.first.id, 'r2');
      expect(first.first.accepted, isTrue);
    });
  });

  group('a body written in the website\'s editor', () {
    test('paragraphs, bold, italic, links and lists keep their shape', () {
      final blocks = parseForumHtml(
        '<h2>Heading</h2><p>One <strong>bold</strong> and <em>italic</em> with <a href="https://example.com/a?b=1&amp;c=2">a link</a>.</p>'
        '<ul><li>first</li><li>second<ul><li>nested</li></ul></li></ul>'
        '<ol><li>one</li><li>two</li></ol>'
        '<blockquote><p>quoted</p></blockquote>'
        '<pre><code>a = 1\nb = 2</code></pre>',
      );
      expect(blocks.map((b) => b.kind), [
        BlockKind.heading,
        BlockKind.paragraph,
        BlockKind.listItem,
        BlockKind.listItem,
        BlockKind.listItem,
        BlockKind.listItem,
        BlockKind.listItem,
        BlockKind.quote,
        BlockKind.codeBlock,
      ]);
      expect(blocks[0].text, 'Heading');
      expect(blocks[0].level, 2);
      final p = blocks[1];
      expect(p.text, 'One bold and italic with a link.');
      expect(p.runs.firstWhere((r) => r.text == 'bold').bold, isTrue);
      expect(p.runs.firstWhere((r) => r.text == 'italic').italic, isTrue);
      expect(p.runs.firstWhere((r) => r.text == 'a link').href, 'https://example.com/a?b=1&c=2');
      expect(blocks[2].text, 'first');
      expect(blocks[2].ordinal, isNull);
      expect(blocks[4].depth, 1);
      expect(blocks[5].ordinal, 1);
      expect(blocks[6].ordinal, 2);
      expect(blocks[8].text, 'a = 1\nb = 2');
    });

    test('a link that is not http, https or mailto is not a link; markup the forum does not draw is looked through', () {
      final blocks = parseForumHtml('<p><a href="javascript:alert(1)">bad</a> <span style="x">kept</span> <img src="/uploads/a.jpg"></p>');
      expect(blocks.single.text, 'bad kept');
      expect(blocks.single.runs.every((r) => r.href == null), isTrue);
    });

    test('entities are decoded, whitespace between tags is layout, a break is a line break', () {
      final blocks = parseForumHtml('<p>Tom &amp; Jerry<br>next &lt;line&gt;</p>\n<p>  two  </p>');
      expect(blocks, hasLength(2));
      expect(blocks[0].text, 'Tom & Jerry\nnext <line>');
      expect(blocks[1].text, 'two');
    });

    test('what the app wrote reads back as the words typed; a body with formatting is known', () {
      const typed = 'First <b>line</b> & more\n\nSecond paragraph\nsame one';
      final html = ForumJson.textToHtml(typed);
      expect(html, '<p>First &lt;b&gt;line&lt;/b&gt; &amp; more</p><p>Second paragraph<br>same one</p>');
      expect(ForumJson.htmlToText(html), typed);
      final plain = ForumThread(
        card: FeedPost(
          id: 'x',
          slug: 'x',
          author: const FeedAuthor(id: 'a', name: 'A'),
          createdAt: DateTime(2026),
          title: 't',
          body: 'b',
        ),
        bodyHtml: html,
        lastActivityAt: DateTime(2026),
      );
      expect(plain.hasRichBody, isFalse);
      expect(
        ForumThread(card: plain.card, bodyHtml: '<p>Hi <strong>there</strong></p>', lastActivityAt: DateTime(2026)).hasRichBody,
        isTrue,
      );
    });
  });

  group('reactions', () {
    final base = FeedPost(
      id: 'p',
      slug: 'p',
      author: const FeedAuthor(id: 'a', name: 'A'),
      createdAt: DateTime(2026),
      title: 't',
      body: 'b',
      reactions: 3,
      reactionCounts: const {ReactionKind.like: 2, ReactionKind.insightful: 1},
      reactionKinds: const [ReactionKind.like, ReactionKind.insightful],
    );

    test('reacting adds one, changing moves it, taking it back removes it; the stack follows the most used', () {
      final liked = withReaction(base, ReactionKind.like);
      expect(liked.reactions, 4);
      expect(liked.reactionCounts[ReactionKind.like], 3);
      expect(liked.myReaction, ReactionKind.like);
      final moved = withReaction(liked, ReactionKind.celebrate);
      expect(moved.reactions, 4);
      expect(moved.reactionCounts[ReactionKind.like], 2);
      expect(moved.reactionCounts[ReactionKind.celebrate], 1);
      // Ties between kinds go in the picker's order (Like, Celebrate, Support, Insightful, Sustainable).
      expect(moved.reactionKinds, [ReactionKind.like, ReactionKind.celebrate, ReactionKind.insightful]);
      final back = withReaction(moved, null);
      expect(back.reactions, 3);
      expect(back.myReaction, isNull);
      expect(withReaction(base, null), same(base));
    });

    test('the only reaction taken back empties the stack', () {
      final one = base.copyWith(reactions: 1, reactionCounts: {ReactionKind.like: 1}, reactionKinds: [ReactionKind.like], myReaction: ReactionKind.like);
      final none = withReaction(one, null);
      expect(none.reactions, 0);
      expect(none.reactionKinds, isEmpty);
    });
  });

  group('refusals are the API\'s own words', () {
    test('an error body\'s message reaches the screen as it is written', () async {
      final a = FakeForum({
        'POST /forum/threads/t/replies': (_) => (400, jsonEncode({'statusCode': 400, 'message': 'Write something before posting.'})),
      });
      final r = forumOn(a);
      await expectLater(
        r.reply('t', 'x'),
        throwsA(isA<ApiError>().having((e) => e.message, 'message', 'Write something before posting.')),
      );
    });

    test('a validation failure lists every sentence', () async {
      final a = FakeForum({
        'POST /forum/threads': (_) => (400, jsonEncode({'message': ['title must be longer than or equal to 8 characters', 'pollOptions must contain at least 2 elements']})),
        'GET /members/me/following': (_) => fixture('following'),
      });
      await expectLater(
        forumOn(a).create(const ForumDraft(categoryKey: 'X', title: 'short', body: 'b')),
        throwsA(isA<ApiError>().having((e) => e.message, 'message', contains('title must be longer'))),
      );
    });
  });

  group('the controller', () {
    ThreadController controllerOn(ForumWorld world, {String viewer = 'me'}) {
      final a = FakeForum(world.routes());
      return ThreadController(repository: forumOn(a, viewerId: viewer), slug: ForumWorld.slug, viewer: reader);
    }

    test('it reads the discussion, then its replies, and counts the read once', () async {
      final world = ForumWorld();
      final c = controllerOn(world);
      await c.start();
      expect(c.thread, isNotNull);
      expect(c.replies, hasLength(3));
      expect(c.totalReplies, 6);
      expect(world.viewCalls, 1);
      await c.refresh();
      expect(world.viewCalls, 1);
      c.dispose();
    });

    test('a like shows at once, is the forum\'s, and a refusal puts it back with the forum\'s sentence', () async {
      final world = ForumWorld();
      final c = controllerOn(world);
      await c.start();
      final before = c.post!.reactions;
      final pending = c.toggleLike();
      expect(c.post!.myReaction, ReactionKind.like);
      expect(c.post!.reactions, before + 1);
      expect(await pending, isNull);
      expect(world.myReaction, 'LIKE');

      world.refusals['DELETE /forum/threads/t-q/vote'] = (400, 'Not today.');
      final message = await c.toggleLike();
      expect(message, 'Not today.');
      expect(c.post!.myReaction, ReactionKind.like);
      expect(c.post!.reactions, before + 1);
      c.dispose();
    });

    test('a member cannot react to their own discussion or reply, and nothing is asked of the forum', () async {
      final world = ForumWorld(authorId: 'me');
      final a = FakeForum(world.routes());
      final c = ThreadController(repository: forumOn(a), slug: ForumWorld.slug, viewer: reader);
      await c.start();
      expect(await c.toggleLike(), 'You cannot vote on your own discussion.');
      final mine = findReply(c.replies, 'r5')!;
      expect(await c.toggleReplyLike(mine), 'You cannot vote on your own reply.');
      expect(a.calls.where((x) => x.contains('/vote')), isEmpty);
      c.dispose();
    });

    test('an empty or over-long reply is refused before it is sent', () async {
      final world = ForumWorld();
      final a = FakeForum(world.routes());
      final c = ThreadController(repository: forumOn(a), slug: ForumWorld.slug, viewer: reader);
      await c.start();
      expect(await c.sendReply('   '), 'Write something before posting.');
      expect(await c.sendReply('x' * (ForumLimits.replyMax + 1)), contains('at most'));
      expect(a.count('POST', '/forum/threads/t-q/replies'), 0);
      c.dispose();
    });

    test('a reply that waits for a moderator is shown to its author and not counted', () async {
      final world = ForumWorld();
      final a = FakeForum({
        ...world.routes(),
        'POST /forum/threads/t-q/replies': (_) => replyJson('wait', by: 'Bharat Buyer', authorId: 'me', headline: null, body: 'Hold.')
          ..['moderation'] = 'PENDING'
          ..['canEdit'] = true,
      });
      final c = ThreadController(repository: forumOn(a), slug: ForumWorld.slug, viewer: reader);
      await c.start();
      final total = c.totalReplies;
      final comments = c.post!.comments;
      expect(await c.sendReply('Hold.'), isNull);
      expect(findReply(c.replies, 'wait')!.pending, isTrue);
      expect(c.totalReplies, total);
      expect(c.post!.comments, comments);
      c.dispose();
    });

    test('an edit that changes nothing sends nothing', () async {
      final world = ForumWorld();
      final a = FakeForum(world.routes());
      final c = ThreadController(repository: forumOn(a), slug: ForumWorld.slug, viewer: reader);
      await c.start();
      final mine = findReply(c.replies, 'r5')!;
      expect(await c.editReply(mine, ForumJson.htmlToText(mine.bodyHtml!)), isNull);
      expect(a.count('PATCH', '/forum/replies/r5'), 0);
      expect(await c.editReply(mine, 'Better words'), isNull);
      expect(findReply(c.replies, 'r5')!.body, 'Better words');
      expect(findReply(c.replies, 'r5')!.edited, isTrue);
      c.dispose();
    });

    test('whether a discussion takes replies, and why not', () async {
      Future<ThreadController> read(ForumWorld w) async {
        final c = controllerOn(w);
        await c.start();
        return c;
      }

      var c = await read(ForumWorld());
      expect(c.takesReplies, isTrue);
      expect(c.lockedReason, isNull);
      c.dispose();
      c = await read(ForumWorld(status: 'LOCKED'));
      expect(c.takesReplies, isFalse);
      expect(c.lockedReason, 'This discussion is locked, so it is not taking new replies.');
      c.dispose();
      c = await read(ForumWorld(status: 'ARCHIVED'));
      expect(c.lockedReason, 'This discussion has been archived.');
      c.dispose();
      c = await read(ForumWorld(moderation: 'PENDING', authorId: 'me', canEdit: true));
      expect(c.lockedReason, 'This discussion is still awaiting review.');
      c.dispose();
      c = await read(ForumWorld(status: 'LOCKED', canModerate: true));
      expect(c.takesReplies, isTrue);
      c.dispose();
    });

    test('only the asker, or a moderator, may accept an answer, and only on a question', () async {
      var c = await _read(ForumWorld(authorId: 'me'));
      expect(c.canAccept, isTrue);
      c.dispose();
      c = await _read(ForumWorld());
      expect(c.canAccept, isFalse);
      c.dispose();
      c = await _read(ForumWorld(authorId: 'me', kind: 'DISCUSSION'));
      expect(c.canAccept, isFalse);
      c.dispose();
      c = await _read(ForumWorld(canModerate: true));
      expect(c.canAccept, isTrue);
      c.dispose();
    });
  });
}

Future<ThreadController> _read(ForumWorld world) async {
  final a = FakeForum(world.routes());
  final c = ThreadController(repository: forumOn(a), slug: ForumWorld.slug, viewer: reader);
  await c.start();
  return c;
}
