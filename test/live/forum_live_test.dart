/// The forum's screens against the LOCAL portal API, seeded by `tool/seed/home.ts` and `tool/seed/forums.ts`: the
/// app's own repository and controllers, the way the screens use them, with the effect of every write read back
/// through the API.
///
/// Every test that writes works on a discussion it creates itself (`_Sandbox`), by Pooja Professional, with Bharat
/// Buyer replying and reacting where a second person is needed, and deletes it at the end; the designed discussions
/// (the Home design's four, `home.ts`) are only read. Reading a discussion's page through a controller counts a
/// view, so the controller is only ever opened on the sandbox: the designed cards' view counts (printed beside
/// "comments") stay as the seed made them.
///
/// The portal's limiter allows 120 calls a minute from one address, shared with every other live test: this file
/// signs each person in once and keeps its calls lean.
///
///     flutter test test/live/forum_live_test.dart --concurrency=1
library;

import 'dart:convert';

import 'package:dio/dio.dart' show Dio, Options, ResponseType;
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/features/feed/feed_models.dart';
import 'package:icr_mobile/features/feed/forum_json.dart';
import 'package:icr_mobile/features/forum/api_forum_repository.dart';
import 'package:icr_mobile/features/forum/composer_controller.dart';
import 'package:icr_mobile/features/forum/forum_html.dart';
import 'package:icr_mobile/features/forum/forum_models.dart';
import 'package:icr_mobile/features/forum/forums_controller.dart';
import 'package:icr_mobile/features/forum/reply_tree.dart';
import 'package:icr_mobile/features/forum/thread_controller.dart';

import 'live.dart';

/// The Home design's discussions (`home.ts`), by slug.
const _sarah = 'implementing-iot-sensors-for-hvac-efficiency-best-practices-home-design';
const _marcus = 'what-is-your-primary-fm-software-in-2026-home-design';

/// One person's signed-in client and forum repository, made once.
class _Person {
  _Person(this.who);

  final LivePerson who;
  late final ApiClient api;
  late final String id;
  late final ApiForumRepository forum;
  var _ready = false;

  Future<_Person> open() async {
    if (_ready) return this;
    api = await liveClient(who);
    id = (await api.dio.get<Map<String, dynamic>>('/auth/me')).data!['id'] as String;
    forum = ApiForumRepository(api: api, viewerId: id);
    _ready = true;
    return this;
  }

  FeedAuthor get asViewer => FeedAuthor(id: id, name: who.label);
}

final _bharat = _Person(bharat);
final _pooja = _Person(pooja);

void main() {
  group('reading, as the Home feed and the Forums tab read the same forum', () {
    liveTest('the list leads with the designed discussions, pinned and in the design\'s order', () async {
      final b = await _bharat.open();
      final page = await b.forum.threads(const ForumQuery());
      expect(page.posts.take(4).map((p) => p.slug), contains(_sarah));
      final sarah = page.posts.firstWhere((p) => p.slug == _sarah);
      expect(sarah.pinned, isTrue);
      expect(sarah.kind, ThreadKind.question);
      expect(sarah.author.name, 'Sarah Jenkins');
      expect(sarah.comments, 52);
      expect(sarah.reactions, 184);
      expect(sarah.topic, '#SUSTAINABILITY');
      expect(sarah.tags, ['#HVAC', '#PropTech', '#SmartBMS']);
      expect(page.total, greaterThanOrEqualTo(9));
      expect(page.hasMore, page.total! > ApiForumRepository.pageSize);
    });

    liveTest(
      'a discussion\'s own page: filing, the whole body, the reader\'s rights, no photo from the list',
      () async {
        final b = await _bharat.open();
        final thread = await b.forum.thread(_sarah);
        expect(thread.category?.key, 'SUSTAINABILITY_ESG');
        expect(thread.subcategory?.name, 'Sustainability');
        expect(thread.bodyHtml, startsWith('<p>'));
        expect(thread.card.body, contains('15- year-old commercial building'));
        expect(thread.status, 'OPEN');
        expect(thread.moderation, 'APPROVED');
        // Bharat neither wrote it nor moderates.
        expect(thread.canEdit, isFalse);
        expect(thread.canModerate, isFalse);
        expect(thread.open, isTrue);
      },
    );

    liveTest(
      'the replies nest as the forum nests them, and each author\'s role and company come from their headline',
      () async {
        final b = await _bharat.open();
        final page = await b.forum.replies(_sarah);
        expect(page.total, 52);
        expect(page.hasMore, isFalse);
        final first = page.replies.first;
        expect(first.author.name, 'Arvind Swamy');
        expect(first.meta, 'Brookfield Properties');
        expect(first.role, isNotEmpty);
        expect(first.likes, 3);
        // Arvind's reply holds a branch: his own answer first, then more.
        expect(first.children.length, greaterThanOrEqualTo(2));
        expect(flattenReplies(page.replies).length, greaterThanOrEqualTo(20));
        expect(findReply(page.replies, first.children.first.id)!.parentId, first.id);
      },
    );

    liveTest('a poll\'s options, its totals and the reader\'s vote', () async {
      final b = await _bharat.open();
      final thread = await b.forum.thread(_marcus);
      final poll = thread.card.poll!;
      expect(poll.options.map((o) => o.label), contains('Archibus'));
      expect(poll.totalVotes, greaterThan(100));
      expect(poll.open, isTrue);
      expect(poll.myOptionId, isNotNull);
      expect(poll.percents.reduce((a, c) => a + c), 100);
    });

    liveTest(
      'topics with their counts, the composer\'s taxonomy, the reader\'s standing, who reacted, who viewed',
      () async {
        final b = await _bharat.open();
        final topics = await b.forum.topics();
        expect(topics.map((t) => t.name), containsAll(['Technology', 'ESG & Sustainability']));
        expect(topics.every((t) => t.threadCount > 0), isTrue);
        final taxonomy = await b.forum.taxonomy();
        expect(taxonomy.length, greaterThan(30));
        expect(taxonomy.firstWhere((n) => n.key == 'TECHNOLOGY_INNOVATION').children, isNotEmpty);
        final access = await b.forum.access();
        expect(access.level, isNotEmpty);
        final thread = await b.forum.thread(_sarah);
        final reactors = await b.forum.reactors(thread.id);
        expect(reactors, isNotEmpty);
        expect(reactors.first.person.id, isNotEmpty);
        final viewers = await b.forum.viewers(thread.id);
        expect(viewers.total, greaterThanOrEqualTo(0));
        expect(viewers.hidden, greaterThanOrEqualTo(0));
      },
    );
  });

  group('a discussion read through its controller', () {
    liveTest('a page the reader opens: the discussion, its replies, and one counted view', () async {
      final p = await _pooja.open();
      final sandbox = await _Sandbox.create(
        p,
        title: 'A sandbox for the app (read ${DateTime.now().millisecondsSinceEpoch})',
      );
      try {
        final c = ThreadController(repository: p.forum, slug: sandbox.slug, viewer: p.asViewer);
        await c.start();
        expect(c.thread, isNotNull);
        expect(c.thread!.canEdit, isTrue);
        expect(c.isOwn, isTrue);
        expect(c.replies, isEmpty);
        expect(c.totalReplies, 0);
        await Future<void>.delayed(const Duration(milliseconds: 300));
        final again = await p.forum.thread(sandbox.slug);
        // One read counted (the controller's), not one per call.
        expect(again.card.views, 1);
        c.dispose();
      } finally {
        await sandbox.remove();
      }
    });
  });

  group('what a reader does to a discussion, read back through the API', () {
    liveTest(
      'a reaction is kept, changed and taken back; the save, the notification and the follow are kept and undone',
      () async {
        final p = await _pooja.open();
        final b = await _bharat.open();
        final sandbox = await _Sandbox.create(
          p,
          title: 'A sandbox for the app (reactions ${DateTime.now().millisecondsSinceEpoch})',
        );
        final c = ThreadController(repository: b.forum, slug: sandbox.slug, viewer: b.asViewer);
        try {
          await c.start();
          expect(c.isOwn, isFalse);
          expect(await c.toggleLike(), isNull);
          var read = await b.forum.thread(sandbox.slug);
          expect(read.card.myReaction, ReactionKind.like);
          expect(read.card.reactions, 1);
          expect(c.post!.reactions, 1);
          // The reaction picker: another reaction replaces the like.
          expect(await c.react(ReactionKind.celebrate), isNull);
          read = await b.forum.thread(sandbox.slug);
          expect(read.card.myReaction, ReactionKind.celebrate);
          expect(read.card.reactionCounts, {ReactionKind.celebrate: 1});
          final reactors = await c.reactors();
          expect(reactors.single.person.id, b.id);
          expect(reactors.single.reaction, ReactionKind.celebrate);
          expect(await c.react(null), isNull);
          read = await b.forum.thread(sandbox.slug);
          expect(read.card.myReaction, isNull);
          expect(read.card.reactions, 0);

          // Save: kept among the reader's saves, and taken back.
          expect(await c.toggleSave(), isNull);
          final saved = await b.forum.threads(const ForumQuery(view: ForumView.saved));
          expect(saved.posts.map((x) => x.id), contains(sandbox.id));
          expect(await c.toggleSave(), isNull);
          final after = await b.forum.threads(const ForumQuery(view: ForumView.saved));
          expect(after.posts.map((x) => x.id), isNot(contains(sandbox.id)));

          // "Notify me": the forum counts the reader as following the discussion.
          expect(c.thread!.subscribed, isFalse);
          expect(await c.toggleSubscribed(), isNull);
          expect((await b.forum.thread(sandbox.slug)).subscribed, isTrue);
          expect(await c.toggleSubscribed(), isNull);
          expect((await b.forum.thread(sandbox.slug)).subscribed, isFalse);

          // Follow the author: in the reader's following, then out again.
          expect(c.thread!.followsAuthor, isFalse);
          expect(await c.toggleFollowAuthor(), isNull);
          expect(await b.forum.follows(p.id), isTrue);
          expect(await c.toggleFollowAuthor(), isNull);
          expect(await b.forum.follows(p.id), isFalse);
        } finally {
          c.dispose();
          await sandbox.remove();
        }
      },
    );

    liveTest('replies: sent under the discussion and under a reply, liked, edited, accepted and deleted', () async {
      final p = await _pooja.open();
      final b = await _bharat.open();
      final sandbox = await _Sandbox.create(
        p,
        title: 'A sandbox for the app (replies ${DateTime.now().millisecondsSinceEpoch})',
      );
      final asker = ThreadController(repository: p.forum, slug: sandbox.slug, viewer: p.asViewer);
      final answerer = ThreadController(repository: b.forum, slug: sandbox.slug, viewer: b.asViewer);
      try {
        await asker.start();
        await answerer.start();
        expect(asker.canAccept, isTrue);
        expect(answerer.canAccept, isFalse);

        // Bharat answers; the reply is the forum's, escaped, and counted.
        expect(await answerer.sendReply('Use <b>BACnet</b> & keep the old controllers.\n\nSecond paragraph'), isNull);
        expect(answerer.post!.comments, 1);
        var page = await p.forum.replies(sandbox.slug);
        expect(page.total, 1);
        final answer = page.replies.single;
        expect(answer.body, 'Use <b>BACnet</b> & keep the old controllers.\nSecond paragraph');
        expect(answer.author.id, b.id);
        expect(
          answer.bodyHtml,
          '<p>Use &lt;b&gt;BACnet&lt;/b&gt; &amp; keep the old controllers.</p><p>Second paragraph</p>',
        );

        // Pooja answers under his answer: the forum nests it.
        await asker.refresh();
        expect(await asker.sendReply('Thanks, which controllers?', parentId: answer.id), isNull);
        page = await b.forum.replies(sandbox.slug);
        expect(page.total, 2);
        expect(page.replies.single.children.single.body, 'Thanks, which controllers?');
        expect(page.replies.single.children.single.parentId, answer.id);

        // Pooja likes Bharat's answer, then takes it back; liking her own reply is refused without asking.
        await asker.refresh();
        expect(await asker.toggleReplyLike(findReply(asker.replies, answer.id)!), isNull);
        expect(findReply((await b.forum.replies(sandbox.slug)).replies, answer.id)!.likes, 1);
        expect(await asker.toggleReplyLike(findReply(asker.replies, answer.id)!), isNull);
        expect(findReply((await b.forum.replies(sandbox.slug)).replies, answer.id)!.likes, 0);
        final own = asker.replies.single.children.single;
        expect(await asker.toggleReplyLike(own), 'You cannot vote on your own reply.');

        // Bharat edits his answer (the forum keeps the new words), and an edit that changes nothing sends nothing.
        await answerer.refresh();
        final mine = findReply(answerer.replies, answer.id)!;
        expect(mine.canEdit, isTrue);
        expect(await answerer.editReply(mine, 'Use BACnet and keep the old controllers.'), isNull);
        expect(
          findReply((await p.forum.replies(sandbox.slug)).replies, answer.id)!.body,
          'Use BACnet and keep the old controllers.',
        );

        // The asker accepts it; a non-asker is refused by the forum in the page's own words.
        expect(await asker.accept(findReply(asker.replies, answer.id)!), isNull);
        final accepted = await b.forum.thread(sandbox.slug);
        expect(accepted.acceptedReplyId, answer.id);
        expect(accepted.card.answered, isTrue);
        expect(findReply((await b.forum.replies(sandbox.slug)).replies, answer.id)!.accepted, isTrue);
        expect(
          await answerer.accept(findReply(answerer.replies, own.id)!),
          'Only the person who asked can mark the answer.',
        );

        // Deleting the accepted answer takes the mark with it; the answer under it stays in the thread.
        expect(await answerer.deleteReply(findReply(answerer.replies, answer.id)!), isNull);
        final left = await p.forum.replies(sandbox.slug);
        expect(left.total, 1);
        expect(left.replies.single.body, 'Thanks, which controllers?');
        final thread = await p.forum.thread(sandbox.slug);
        expect(thread.acceptedReplyId, isNull);
        expect(thread.card.comments, 1);
      } finally {
        asker.dispose();
        answerer.dispose();
        await sandbox.remove();
      }
    });

    liveTest("a poll vote is kept, moves, and the bars follow the forum's own totals", () async {
      final p = await _pooja.open();
      final b = await _bharat.open();
      final sandbox = await _Sandbox.create(
        p,
        title: 'A sandbox for the app (poll ${DateTime.now().millisecondsSinceEpoch})',
        kind: ThreadKind.discussion,
        pollOptions: const ['Chillers', 'Split units', 'VRF'],
      );
      final c = ThreadController(repository: b.forum, slug: sandbox.slug, viewer: b.asViewer);
      try {
        await c.start();
        final poll = c.post!.poll!;
        expect(poll.options.map((o) => o.label), ['Chillers', 'Split units', 'VRF']);
        expect(poll.totalVotes, 0);
        expect(poll.myOptionId, isNull);
        expect(await c.votePoll(poll.options[1].id), isNull);
        expect(c.post!.poll!.myOptionId, poll.options[1].id);
        expect(c.post!.poll!.totalVotes, 1);
        var read = (await b.forum.thread(sandbox.slug)).card.poll!;
        expect(read.options[1].votes, 1);
        expect(read.myOptionId, poll.options[1].id);
        // Moving the vote keeps one vote in all.
        expect(await c.votePoll(poll.options[2].id), isNull);
        read = (await b.forum.thread(sandbox.slug)).card.poll!;
        expect(read.totalVotes, 1);
        expect(read.options.map((o) => o.votes), [0, 0, 1]);
        // The same option asks nothing.
        final before = c.post!.poll!;
        expect(await c.votePoll(poll.options[2].id), isNull);
        expect(c.post!.poll!.totalVotes, before.totalVotes);
        // An option the poll does not have is the forum's refusal.
        await expectLater(
          b.forum.vote(sandbox.id, 'not-an-option', open: true),
          throwsA(isA<ApiError>().having((e) => e.message, 'message', contains("not one of this poll's options"))),
        );
      } finally {
        c.dispose();
        await sandbox.remove();
      }
    });

    liveTest(
      'what the page refuses before asking, the forum refuses too, in the same words; reports go through',
      () async {
        final p = await _pooja.open();
        final b = await _bharat.open();
        final sandbox = await _Sandbox.create(
          p,
          title: 'A sandbox for the app (refusals ${DateTime.now().millisecondsSinceEpoch})',
        );
        final c = ThreadController(repository: b.forum, slug: sandbox.slug, viewer: b.asViewer);
        try {
          await c.start();
          // Reacting to one's own discussion.
          await expectLater(
            p.forum.react(sandbox.id, ReactionKind.like),
            throwsA(isA<ApiError>().having((e) => e.message, 'message', 'You cannot vote on your own discussion.')),
          );
          final own = ThreadController(repository: p.forum, slug: sandbox.slug, viewer: p.asViewer);
          await own.start();
          expect(await own.toggleLike(), 'You cannot vote on your own discussion.');
          own.dispose();
          // Someone else's discussion is not theirs to delete or edit.
          expect(await c.deleteThread(), 'You can only delete your own discussions.');
          await expectLater(
            b.forum.update(
              sandbox.id,
              const ForumDraft(categoryKey: 'TECHNOLOGY_INNOVATION', title: 'Taken over by someone else'),
            ),
            throwsA(isA<ApiError>().having((e) => e.message, 'message', 'You can only edit your own discussions.')),
          );
          // An empty reply, as the forum words it.
          await expectLater(
            b.forum.reply(sandbox.id, '   '),
            throwsA(isA<ApiError>().having((e) => e.message, 'message', 'Write something before posting.')),
          );
          // A reply under a reply that is not there.
          await expectLater(
            b.forum.reply(sandbox.id, 'Hello', parentId: 'no-such-reply'),
            throwsA(
              isA<ApiError>().having((e) => e.message, 'message', 'The reply you are answering is no longer here.'),
            ),
          );
          // A report goes through for the discussion and for a reply.
          expect(await c.report(reason: ReportReason.offTopic, note: 'A test of the app: please ignore.'), isNull);
          expect(await c.sendReply('A reply to report'), isNull);
          final asker = ThreadController(repository: p.forum, slug: sandbox.slug, viewer: p.asViewer);
          await asker.start();
          expect(await asker.report(reply: asker.replies.single, reason: ReportReason.spam), isNull);
          asker.dispose();
        } finally {
          c.dispose();
          await sandbox.remove();
        }
      },
    );

    liveTest('replies read a page at a time and merged equal the replies read whole', () async {
      final b = await _bharat.open();
      Future<Map<String, dynamic>> page(int n, int limit) async {
        final res = await b.api.dio.get<Map<String, dynamic>>(
          '/forum/threads/$_sarah/replies',
          queryParameters: {'page': n, 'limit': limit},
        );
        return res.data!;
      }

      Map<String, String?> parents(List<FeedReply> tree) => {for (final r in flattenReplies(tree)) r.id: r.parentId};

      final whole = (await b.forum.replies(_sarah)).replies;
      final json = ForumJson(apiBase: b.api.dio.options.baseUrl, viewerId: b.id);
      var merged = <FeedReply>[];
      for (var n = 1; n <= 7; n++) {
        final data = await page(n, 9);
        merged = mergeReplyPages(merged, [
          for (final r in (data['data'] as List).cast<Map<String, dynamic>>()) json.reply(r),
        ]);
        if ((data['meta'] as Map)['hasNext'] != true) break;
      }
      expect(parents(merged), parents(whole));
      expect(countReplies(merged), countReplies(whole));
    });
  });

  group('the Forums tab, asked of the real forum', () {
    liveTest('each view, topic, kind, tag and search narrows the list the way the website\'s filters do', () async {
      final b = await _bharat.open();
      final forums = ForumsController(b.forum);
      try {
        await forums.start();
        expect(forums.topics, isNotEmpty);
        expect(forums.posts, isNotEmpty);
        final all = forums.total!;
        expect(all, greaterThanOrEqualTo(9));

        // A topic's list is as long as its chip says (the chip counts what a visitor can open).
        final topic = forums.topics.firstWhere((t) => t.name == 'Technology');
        await forums.setTopic(topic);
        expect(forums.total, topic.threadCount);
        expect(forums.posts.every((p) => p.topic != null), isTrue);
        // The sub-topics come from the taxonomy once a topic is chosen.
        await forums.readTaxonomy();
        expect(forums.subtopics, isNotEmpty);
        await forums.setTopic(null);

        // Questions only; unanswered keeps open questions with no reply.
        await forums.setKind(ForumKindFilter.questions);
        expect(forums.posts, isNotEmpty);
        expect(forums.posts.every((p) => p.kind == ThreadKind.question), isTrue);
        await forums.setKind(ForumKindFilter.any);
        await forums.setView(ForumView.unanswered);
        expect(forums.posts.every((p) => p.kind == ThreadKind.question && p.comments == 0), isTrue);

        // Polls (the forum has no such filter: the app keeps the polls of the latest 100).
        await forums.setView(ForumView.polls);
        expect(forums.posts, isNotEmpty);
        expect(forums.posts.every((p) => p.poll != null), isTrue);

        // The reader's own: Bharat wrote the three discussions the Home seed gives him.
        await forums.setView(ForumView.mine);
        expect(forums.posts.length, greaterThanOrEqualTo(3));
        expect(forums.posts.every((p) => p.author.id == b.id), isTrue);

        // Trending: most reacted first among the pinned.
        await forums.setView(ForumView.trending);
        expect(forums.posts, isNotEmpty);

        // A tag (the forum's tag filter is case-sensitive: the seed stores the design's own writing), and a search.
        await forums.setView(ForumView.all);
        await forums.setTag('HVAC');
        expect(forums.posts, isNotEmpty);
        expect(forums.posts.every((p) => p.tags.contains('#HVAC')), isTrue);
        await forums.setTag(null);
        await forums.setSearch('IoT sensors');
        expect(forums.posts.map((p) => p.slug), contains(_sarah));
        await forums.setSearch('zzzz-nothing-matches-this');
        expect(forums.posts, isEmpty);
        expect(forums.total, 0);
        await forums.clearAll();
        expect(forums.total, all);
      } finally {
        forums.dispose();
      }
    });

    liveTest('the Saved view lists what the reader saved, and unsaving on it takes the card out', () async {
      final p = await _pooja.open();
      final sandbox = await _Sandbox.create(
        p,
        title: 'A sandbox for the app (saved ${DateTime.now().millisecondsSinceEpoch})',
      );
      final forums = ForumsController(p.forum);
      try {
        await forums.start();
        await forums.setView(ForumView.all);
        final card = forums.posts.firstWhere((x) => x.id == sandbox.id);
        expect(await forums.toggleSave(card), isNull);
        await forums.setView(ForumView.saved);
        expect(forums.posts.map((x) => x.id), contains(sandbox.id));
        expect(await forums.toggleSave(forums.posts.firstWhere((x) => x.id == sandbox.id)), isNull);
        expect(forums.posts.map((x) => x.id), isNot(contains(sandbox.id)));
        await forums.refresh();
        expect(forums.posts.map((x) => x.id), isNot(contains(sandbox.id)));
      } finally {
        forums.dispose();
        await sandbox.remove();
      }
    });

    liveTest('a page is twenty discussions and the next page continues it', () async {
      final b = await _bharat.open();
      final first = await b.forum.threads(const ForumQuery());
      expect(first.posts.length, lessThanOrEqualTo(ApiForumRepository.pageSize));
      if (first.hasMore) {
        final second = await b.forum.threads(const ForumQuery(), page: 2);
        expect(second.posts.map((x) => x.id).toSet().intersection(first.posts.map((x) => x.id).toSet()), isEmpty);
      }
    });
  });

  group('the composer, sent to the real forum', () {
    liveTest(
      'a discussion is stored as the composer wrote it; an edit of the title alone keeps its body and topic; a new body replaces it',
      () async {
        final p = await _pooja.open();
        final c = ComposerController(repository: p.forum);
        ForumThread? stored;
        try {
          await c.start();
          final tech = c.taxonomy.firstWhere((n) => n.key == 'TECHNOLOGY_INNOVATION');
          c.setTopic(tech);
          c.setSubtopic(tech.children.first);
          c.setTitle('A composer sandbox ${DateTime.now().millisecondsSinceEpoch}');
          c.setBody('We run <b>two</b> sites & one is old.\n\nSecond paragraph\nsame line');
          expect(c.addTags('HVAC, Retro fit, #hvac'), isNull);
          expect(c.canSend, isTrue);
          stored = await c.send();
          expect(c.error, isNull);
          expect(stored, isNotNull);
          expect(stored!.card.tags, ['#hvac', '#retro-fit']);
          expect(stored.category?.key, 'TECHNOLOGY_INNOVATION');
          expect(stored.subcategory?.key, tech.children.first.key);
          expect(stored.card.kind, ThreadKind.discussion);
          expect(stored.canEdit, isTrue);
          expect(stored.moderation, 'APPROVED');
          expect(
            stored.bodyHtml,
            '<p>We run &lt;b&gt;two&lt;/b&gt; sites &amp; one is old.</p><p>Second paragraph<br />same line</p>',
          );

          // An edit from the page: starts from what the forum holds; the title alone changes.
          final read = await p.forum.thread(stored.slug);
          final editor = ComposerController(repository: p.forum, editing: read);
          await editor.start();
          expect(editor.body, 'We run <b>two</b> sites & one is old.\n\nSecond paragraph\nsame line');
          editor.setTitle('${read.card.title} (edited)');
          expect(editor.draft.body, isNull);
          expect(editor.draft.categoryKey, isNull);
          final after = await editor.send();
          expect(editor.error, isNull);
          expect(after!.card.title, endsWith('(edited)'));
          expect(after.bodyHtml, stored.bodyHtml);
          expect(after.category?.key, 'TECHNOLOGY_INNOVATION');
          expect(after.subcategory?.key, tech.children.first.key);
          expect(after.card.tags, ['#hvac', '#retro-fit']);

          // Changing the words replaces the body; the topic change is re-checked by the forum.
          editor.setBody('Only these words now.');
          editor.setTopic(c.taxonomy.firstWhere((n) => n.key == 'SUSTAINABILITY_ESG'));
          final changed = await editor.send();
          expect(changed!.bodyHtml, '<p>Only these words now.</p>');
          expect(changed.category?.key, 'SUSTAINABILITY_ESG');
          expect(changed.subcategory, isNull);
          editor.dispose();
        } finally {
          c.dispose();
          if (stored != null) await p.forum.deleteThread(stored.id);
        }
      },
    );

    liveTest('a poll is stored with its options, and an edit never sends them; a question keeps its kind', () async {
      final p = await _pooja.open();
      final c = ComposerController(repository: p.forum, mode: ComposerMode.poll);
      ForumThread? stored;
      try {
        await c.start();
        c.setTopic(c.taxonomy.firstWhere((n) => n.key == 'PROCUREMENT_SUPPLY_CHAIN'));
        c.setTitle('A poll sandbox ${DateTime.now().millisecondsSinceEpoch}');
        c.setPollOption(0, 'Chillers');
        c.setPollOption(1, 'VRF');
        expect(c.bodyOptional, isTrue);
        stored = await c.send();
        expect(c.error, isNull);
        expect(stored!.card.poll!.options.map((o) => o.label), ['Chillers', 'VRF']);
        expect(stored.card.topic, '#POLL');
        expect(stored.bodyHtml, isEmpty);

        // Edited later: the options are fixed, the title changes, the details stay optional.
        final editor = ComposerController(repository: p.forum, editing: stored);
        expect(editor.isPoll, isTrue);
        expect(editor.bodyOptional, isTrue);
        editor.setTitle('${stored.card.title} (edited)');
        expect(editor.draft.pollOptions, isNull);
        final after = await editor.send();
        expect(editor.error, isNull);
        expect(after!.card.poll!.options.map((o) => o.label), ['Chillers', 'VRF']);
        editor.dispose();
      } finally {
        c.dispose();
        if (stored != null) await p.forum.deleteThread(stored.id);
      }
    });

    liveTest('a photo is uploaded as the forum takes it, shown on the discussion, and replaced by an edit', () async {
      final p = await _pooja.open();
      final c = ComposerController(repository: p.forum);
      ForumThread? stored;
      try {
        await c.start();
        c.setTopic(c.taxonomy.firstWhere((n) => n.key == 'TECHNOLOGY_INNOVATION'));
        c.setTitle('A file sandbox ${DateTime.now().millisecondsSinceEpoch}');
        c.setBody('With a picture.');
        expect(await c.attach(ForumFile(bytes: _tinyPng, name: 'Site photo.png')), isNull);
        expect(c.attachment!.fileName, 'Site photo.png');
        expect(c.attachment!.uploadId, endsWith('.png'));
        expect(c.attachment!.isPicture, isTrue);
        stored = await c.send();
        expect(c.error, isNull);
        expect(stored!.attachment!.uploadId, c.attachment!.uploadId);
        expect(stored.attachment!.fileName, 'Site photo.png');
        expect(stored.images, hasLength(1));
        // The file is served beside the API.
        final served = await Dio().get<List<int>>(
          stored.attachment!.url!,
          options: Options(responseType: ResponseType.bytes),
        );
        expect(served.statusCode, 200);
        expect(served.data!.length, _tinyPng.length);

        // A file type the forum does not take is its refusal, not a silent drop.
        await expectLater(
          p.forum.upload(ForumFile(bytes: const [1, 2, 3], name: 'notes.docx')),
          throwsA(isA<ApiError>().having((e) => e.message, 'message', contains('not an accepted file type'))),
        );
      } finally {
        c.dispose();
        if (stored != null) await p.forum.deleteThread(stored.id);
      }
    });

    liveTest('what the form checks before sending, the API checks too, in its own words', () async {
      final p = await _pooja.open();
      await expectLater(
        p.forum.create(const ForumDraft(categoryKey: 'TECHNOLOGY_INNOVATION', title: 'short', body: 'x')),
        throwsA(
          isA<ApiError>().having(
            (e) => e.message,
            'message',
            contains('title must be longer than or equal to 8 characters'),
          ),
        ),
      );
      await expectLater(
        p.forum.create(const ForumDraft(categoryKey: 'NOT_A_CATEGORY', title: 'A fine long title', body: 'x')),
        throwsA(isA<ApiError>().having((e) => e.message, 'message', 'Pick a category that exists.')),
      );
      await expectLater(
        p.forum.create(const ForumDraft(categoryKey: 'TECHNOLOGY_INNOVATION', title: 'A fine long title', body: '  ')),
        throwsA(isA<ApiError>().having((e) => e.message, 'message', 'Add something to the body before posting.')),
      );
      await expectLater(
        p.forum.create(
          const ForumDraft(categoryKey: 'TECHNOLOGY_INNOVATION', title: 'A fine long title', pollOptions: ['Only one']),
        ),
        throwsA(
          isA<ApiError>().having((e) => e.message, 'message', contains('pollOptions must contain at least 2 elements')),
        ),
      );
      await expectLater(
        p.forum.create(
          const ForumDraft(
            categoryKey: 'TECHNOLOGY_INNOVATION',
            title: 'A fine long title',
            body: 'x',
            kind: ThreadKind.announcement,
          ),
        ),
        throwsA(isA<ApiError>().having((e) => e.message, 'message', 'Announcements are posted by the ICR team.')),
      );
    });
  });

  group('the discussions `forums.ts` seeds', () {
    const longSlug = 'what-would-you-put-in-a-bms-handover-pack-forums-design';

    liveTest(
      'a discussion of 130 replies reads in two pages, merged back into one tree; a link to a reply on page two finds it',
      () async {
        final b = await _bharat.open();
        final c = ThreadController(repository: b.forum, slug: longSlug, viewer: b.asViewer);
        final linked = ThreadController(
          repository: b.forum,
          slug: longSlug,
          viewer: b.asViewer,
          focusReplyId: 'design-forums-thread-long-reply-z20',
        );
        try {
          await c.start();
          expect(c.totalReplies, 130);
          expect(c.hasMoreReplies, isTrue);
          final firstPage = countReplies(c.replies);
          expect(firstPage, 100);
          await c.loadMoreReplies();
          expect(c.hasMoreReplies, isFalse);
          expect(countReplies(c.replies), 130);
          // Every answer sits under its own parent once both pages are in.
          for (final r in flattenReplies(c.replies)) {
            if (r.parentId != null) expect(findReply(c.replies, r.parentId!), isNotNull, reason: r.id);
          }
          final nested = c.replies.where((r) => r.children.isNotEmpty).length;
          expect(nested, greaterThanOrEqualTo(10));

          // A reply that is only on page two: reading by link pulls the page in.
          await linked.start();
          expect(linked.focusFound, isTrue);
          expect(findReply(linked.replies, 'design-forums-thread-long-reply-z20'), isNotNull);
        } finally {
          c.dispose();
          linked.dispose();
        }
      },
    );

    liveTest(
      'the answered question shows its accepted answer first; the locked discussion and its poll take nothing',
      () async {
        final b = await _bharat.open();
        final answered = await b.forum.thread(
          'how-do-we-map-legacy-bacnet-points-into-a-new-supervisor-without-re-co-forums-design',
        );
        expect(answered.card.kind, ThreadKind.question);
        expect(answered.card.answered, isTrue);
        final replies = (await b.forum.replies(answered.slug)).replies;
        expect(replies.first.accepted, isTrue);
        expect(replies.first.author.name, 'Arvind Swamy');
        expect(replies.first.role, 'VP Sustainability');

        final locked = await b.forum.thread('archive-lessons-from-the-2025-chiller-plant-tender-forums-design');
        expect(locked.status, 'LOCKED');
        expect(locked.open, isFalse);
        final c = ThreadController(repository: b.forum, slug: locked.slug, viewer: b.asViewer);
        await c.start();
        expect(c.takesReplies, isFalse);
        expect(c.lockedReason, 'This discussion is locked, so it is not taking new replies.');
        expect(await c.sendReply('Can I still reply?'), 'This discussion is locked, so it is not taking new replies.');
        c.dispose();

        final poll = await b.forum.thread('which-bms-vendor-did-you-shortlist-last-year-forums-design');
        expect(poll.card.poll!.open, isFalse);
        expect(poll.card.poll!.totalVotes, 80);
        await expectLater(
          b.forum.vote(poll.id, poll.card.poll!.options.first.id, open: false),
          throwsA(
            isA<ApiError>().having((e) => e.message, 'message', 'This discussion is closed, and so is its poll.'),
          ),
        );
      },
    );

    liveTest(
      'a file, a body written on the website, an unanswered question and a discussion waiting for a moderator',
      () async {
        final b = await _bharat.open();
        final spec = await b.forum.thread('our-hvac-retrofit-specification-feedback-welcome-forums-design');
        expect(spec.attachment!.fileName, 'HVAC retrofit spec.pdf');
        expect(spec.attachment!.isPicture, isFalse);
        expect(spec.images, isEmpty);
        final served = await Dio().get<List<int>>(
          spec.attachment!.url!,
          options: Options(responseType: ResponseType.bytes),
        );
        expect(served.statusCode, 200);

        final rich = await b.forum.thread('net-zero-retrofit-twelve-weeks-of-data-from-two-campuses-forums-design');
        expect(rich.hasRichBody, isTrue);
        final blocks = parseForumHtml(rich.bodyHtml);
        expect(blocks.any((x) => x.kind == BlockKind.heading), isTrue);
        expect(blocks.where((x) => x.kind == BlockKind.listItem), hasLength(6));
        expect(blocks.any((x) => x.kind == BlockKind.quote), isTrue);

        final unanswered = await b.forum.threads(const ForumQuery(view: ForumView.unanswered));
        expect(
          unanswered.posts.map((x) => x.slug),
          contains('which-amc-escalation-clause-survives-multiple-cities-forums-design'),
        );

        final mine = await b.forum.threads(const ForumQuery(view: ForumView.mine));
        final pending = mine.posts.firstWhere((x) => x.slug.startsWith('looking-for-a-partner-to-audit'));
        final thread = await b.forum.thread(pending.slug);
        expect(thread.moderation, 'PENDING');
        expect(thread.pending, isTrue);
        expect(thread.canEdit, isTrue);
        final c = ThreadController(repository: b.forum, slug: pending.slug, viewer: b.asViewer);
        await c.start();
        // A discussion waiting for review shows no replies and takes none.
        expect(c.replies, isEmpty);
        expect(c.lockedReason, 'This discussion is still awaiting review.');
        c.dispose();
        // Anyone else gets "not found" for it.
        final p = await _pooja.open();
        await expectLater(
          p.forum.thread(pending.slug),
          throwsA(isA<ApiError>().having((e) => e.statusCode, 'status', 404)),
        );
      },
    );
  });
}

final _tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

/// A discussion made for one test and taken down again.
class _Sandbox {
  _Sandbox(this.owner, this.thread);

  final _Person owner;
  ForumThread thread;

  String get slug => thread.slug;
  String get id => thread.id;

  static Future<_Sandbox> create(
    _Person owner, {
    required String title,
    String body = 'A discussion the app\'s live tests made. It is deleted when the test ends.',
    ThreadKind kind = ThreadKind.question,
    List<String> pollOptions = const [],
  }) async {
    final categories = await owner.forum.taxonomy();
    final tech = categories.firstWhere((n) => n.key == 'TECHNOLOGY_INNOVATION');
    final thread = await owner.forum.create(
      ForumDraft(
        categoryKey: tech.key,
        title: title,
        body: body,
        kind: kind,
        tags: const ['app-live-test'],
        pollOptions: pollOptions.isEmpty ? null : pollOptions,
      ),
    );
    return _Sandbox(owner, thread);
  }

  Future<void> remove() async {
    try {
      await owner.forum.deleteThread(id);
    } catch (_) {
      // Already gone.
    }
  }
}
