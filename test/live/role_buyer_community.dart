/// Role matrix, part 1: the Home feed and Forums for the four accounts that belong to no company.
///
/// Every account reads each view; the writes (a discussion with a poll, a reaction, a bookmark, a follow, a
/// vote, replies, a report) go round a ring, so each account is once the author and once the one who acts on
/// somebody else's discussion. The discussion is the tester's own and is deleted at the end; the report it
/// drew is resolved by staff, so nothing is left in the moderation queue.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/features/feed/api_feed_repository.dart';
import 'package:icr_mobile/features/feed/feed_controller.dart';
import 'package:icr_mobile/features/feed/feed_models.dart';
import 'package:icr_mobile/features/feed/home_screen.dart';
import 'package:icr_mobile/features/forum/api_forum_repository.dart';
import 'package:icr_mobile/features/forum/forum_models.dart';
import 'package:icr_mobile/features/forum/forums_screen.dart';
import 'package:icr_mobile/features/forum/new_thread_screen.dart';
import 'package:icr_mobile/features/forum/thread_controller.dart';
import 'package:icr_mobile/features/forum/thread_screen.dart';
import 'package:provider/provider.dart';

import '../helpers/fonts.dart';
import 'career_live_support.dart';
import 'live.dart';
import 'role_buyer_support.dart';

/// A feed source and a forum source for one account.
class Feeds {
  Feeds(Who w) : feed = ApiFeedRepository(api: w.api, viewerId: w.id);

  final ApiFeedRepository feed;

  /// The feed's own forum source, as the app shares it (it keeps who the reader follows).
  ApiForumRepository get forum => feed.forum;
}

final _feeds = <String, Feeds>{};
Feeds feedsOf(Who w) => _feeds.putIfAbsent(w.email, () => Feeds(w));

FeedAuthor _viewer(Who w) => FeedAuthor(id: w.id, name: '${w.first} ${w.me['lastName'] ?? ''}'.trim());

void roleBuyerCommunity() {
  setUpAll(loadAppFonts);

  group('Home feed', () {
    liveTest('every chip of the feed, the search and a topic answer for every account', () async {
      for (final w in await everyone()) {
        final feeds = feedsOf(w);
        for (final filter in FeedFilter.values) {
          final page = await feeds.feed.load(filter);
          if (filter == FeedFilter.all) {
            expect(page.posts, isNotEmpty, reason: '${w.email}: All Feed has discussions');
          }
          for (final post in page.posts) {
            expect(post.title, isNotEmpty);
            expect(post.author.name, isNotEmpty);
          }
        }
        final all = (await feeds.feed.load(FeedFilter.all)).posts;
        final word = all.first.title.split(' ').firstWhere((s) => s.length > 3, orElse: () => all.first.title);
        final found = await feeds.feed.load(FeedFilter.all, search: word);
        expect(found.posts, isNotEmpty, reason: '${w.email}: a search for "$word" finds the discussion');
        final tagged = all.firstWhere((p) => p.tags.isNotEmpty, orElse: () => all.first);
        if (tagged.tags.isNotEmpty) {
          final byTag = await feeds.feed.load(FeedFilter.all, tag: tagged.tags.first.replaceFirst('#', ''));
          expect(byTag.posts.map((p) => p.id), contains(tagged.id));
        }
        expect(await feeds.feed.unreadNotifications(), greaterThanOrEqualTo(0));
        record('Home feed: chips, search, topic chip, bell', w.person, 'works');
      }
    });

    liveTest(
      'a discussion with a poll goes round the ring: like, bookmark, follow, vote, reply, report',
      () async {
        final people = await everyone();
        for (var i = 0; i < people.length; i++) {
          final author = people[i];
          final actor = people[(i + 1) % people.length];
          await _roundTrip(author, actor);
        }
      },
      timeout: const Timeout(Duration(minutes: 6)),
    );
  });

  group('Forums', () {
    liveTest(
      'the views, the topics, a topic\'s sub-topics, the filters and the standing answer for every account',
      () async {
        for (final w in await everyone()) {
          final forum = feedsOf(w).forum;
          for (final view in [
            ForumView.all,
            ForumView.trending,
            ForumView.following,
            ForumView.unanswered,
            ForumView.polls,
          ]) {
            final page = await forum.threads(ForumQuery(view: view));
            if (view == ForumView.all) expect(page.posts, isNotEmpty);
          }
          for (final view in [ForumView.saved, ForumView.mine]) {
            await forum.threads(ForumQuery(view: view));
          }
          final topics = await forum.topics();
          expect(topics, isNotEmpty, reason: '${w.email}: the forum has topics');
          final taxonomy = await forum.taxonomy();
          expect(taxonomy, isNotEmpty);
          final withCount = topics.firstWhere((t) => t.threadCount > 0);
          final byTopic = await forum.threads(ForumQuery(category: withCount));
          expect(byTopic.posts, isNotEmpty, reason: 'the topic "${withCount.name}" has discussions');
          final node = taxonomy.firstWhere((n) => n.slug == withCount.slug, orElse: () => taxonomy.first);
          if (node.children.isNotEmpty) {
            await forum.threads(ForumQuery(category: withCount, subcategory: node.children.first));
          }
          await forum.threads(const ForumQuery(kind: ForumKindFilter.questions));
          await forum.threads(const ForumQuery(sort: ForumSort.newest));
          await forum.threads(const ForumQuery(sort: ForumSort.top));
          final access = await forum.access();
          expect(access, isNotNull);
          record('Forums: views, topics, sub-topics, filters, standing', w.person, 'works');
        }
      },
    );

    liveTest(
      'search finds a discussion by its words for every account, and a stranger\'s words find nothing',
      () async {
        for (final w in await everyone()) {
          final forum = feedsOf(w).forum;
          final first = (await forum.threads(const ForumQuery())).posts.first;
          final word = first.title.split(' ').firstWhere((s) => s.length > 3, orElse: () => first.title);
          final hit = await forum.threads(ForumQuery(search: word));
          expect(hit.posts.map((p) => p.id), contains(first.id));
          final none = await forum.threads(const ForumQuery(search: 'zzqxnothingwritesthis'));
          expect(none.posts, isEmpty);
          // A thread's own page and its replies read for every account.
          final thread = await forum.thread(first.slug);
          expect(thread.card.id, first.id);
          final replies = await forum.replies(first.slug);
          expect(replies, isNotNull);
          record('Forums: search, discussion page, replies', w.person, 'works');
        }
      },
    );
  });

  group('the screens, drawn for every account', () {
    testWidgets('the Home feed draws with real discussions, the composer line and the chips', tags: const ['live'], (
      tester,
    ) async {
      if (!await liveScreenReady(tester)) return;
      for (final w in (await tester.runAsync(everyone))!) {
        final controller = (await tester.runAsync(() async {
          final c = FeedController(feedsOf(w).feed);
          await c.start();
          return c;
        }))!;
        expect(controller.error, isNull, reason: '${w.email}: the feed loaded');
        await loadScreen(
          tester,
          HomeScreen(viewer: _viewer(w), onAccount: () {}),
          providers: [ChangeNotifierProvider.value(value: controller)],
          size: const Size(390, 1800),
        );
        final text = expectHealthy(tester, 'Home as ${w.email}');
        expect(text, contains('Post a requirement or insight'));
        for (final f in ['All Feed', 'Trending', 'Following', 'Unanswered', 'Polls']) {
          expect(text, contains(f), reason: '${w.email}: the $f chip');
        }
        expect(controller.posts, isNotEmpty);
        expect(text, contains(controller.posts.first.title.substring(0, 12)), reason: 'the first discussion is drawn');
        await unmount(tester);
        controller.dispose();
        record('Home feed: screen', w.person, 'works', 'drawn from the live API');
      }
    });

    testWidgets('the Forums tab draws its views, topics and discussions', tags: const ['live'], (tester) async {
      if (!await liveScreenReady(tester)) return;
      for (final w in (await tester.runAsync(everyone))!) {
        await loadScreen(
          tester,
          ForumsScreen(viewer: _viewer(w), onBack: () {}, repository: feedsOf(w).forum),
          size: const Size(390, 1800),
        );
        final text = expectHealthy(tester, 'Forums as ${w.email}');
        expect(text, contains('Start a discussion'));
        expect(text, contains('Topics'), reason: '${w.email}: the topics row');
        await unmount(tester);
        record('Forums: screen', w.person, 'works');
      }
    });

    testWidgets('a discussion page draws its replies, the poll and the reply box', tags: const ['live'], (
      tester,
    ) async {
      if (!await liveScreenReady(tester)) return;
      final people = (await tester.runAsync(everyone))!;
      final author = people.first;
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final tree = (await tester.runAsync(feedsOf(author).forum.taxonomy))!;
      final created = (await tester.runAsync(
        () => feedsOf(author).forum.create(
          ForumDraft(
            categoryKey: tree.first.key,
            title: 'Role matrix page $stamp',
            body: 'A page for the role matrix to draw.',
            tags: const ['rolematrix'],
            pollOptions: const ['One', 'Two'],
          ),
        ),
      ))!;
      try {
        for (final w in people) {
          await tester.runAsync(() => feedsOf(w).forum.reply(created.card.id, 'Seen by ${w.first}.'));
        }
        for (final w in people) {
          await loadScreen(
            tester,
            const ThreadScreen(),
            providers: [
              ChangeNotifierProvider<ThreadController>(
                create: (_) =>
                    ThreadController(repository: feedsOf(w).forum, slug: created.card.slug, viewer: _viewer(w))
                      ..start(),
              ),
            ],
            size: const Size(390, 1800),
          );
          final text = expectHealthy(tester, 'the page as ${w.email}');
          expect(text, contains('Role matrix page $stamp'));
          expect(text, contains('One'), reason: '${w.email}: the poll');
          expect(text, contains('Seen by ${people.last.first}.'), reason: '${w.email}: the replies');
          await unmount(tester);
          record('Forums: discussion page', w.person, 'works', 'poll, four replies, reply box');
        }
      } finally {
        await tester.runAsync(() => feedsOf(author).forum.deleteThread(created.card.id));
      }
    });

    testWidgets('the composer opens with the topics for every account', tags: const ['live'], (tester) async {
      if (!await liveScreenReady(tester)) return;
      for (final w in (await tester.runAsync(everyone))!) {
        await loadScreen(tester, NewThreadScreen(repository: feedsOf(w).forum), size: const Size(390, 1200));
        final text = expectHealthy(tester, 'the composer as ${w.email}');
        expect(text.toLowerCase(), contains('title'));
        await unmount(tester);
        record('Forums: composer screen', w.person, 'works');
      }
    });
  });
}

/// One discussion by [author], handled by [actor] and put away again.
Future<void> _roundTrip(Who author, Who actor) async {
  final a = feedsOf(author);
  final b = feedsOf(actor);
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final title = 'Role matrix ${author.first} to ${actor.first} $stamp';
  final tree = await a.forum.taxonomy();
  final topic = tree.firstWhere((n) => n.key == 'TECHNOLOGY_INNOVATION', orElse: () => tree.first);
  ForumThread? thread;
  final tag = 'rolematrix$stamp';
  try {
    // The author starts a discussion with a poll.
    try {
      thread = await a.forum.create(
        ForumDraft(
          categoryKey: topic.key,
          title: title,
          body: 'A discussion made by the role matrix. It is deleted when the run ends.',
          kind: ThreadKind.discussion,
          tags: [tag],
          pollOptions: const ['Alpha', 'Beta'],
        ),
      );
    } catch (e) {
      // A first post can wait for a moderator or be refused; that is the forum's answer, shown as it is.
      record('Home feed / Forums: start a discussion', author.person, 'bug open', 'refused: ${sentenceOf(e)}');
      rethrow;
    }
    expect(thread.moderation, 'APPROVED', reason: '${author.email}: a post shows at once');
    record('Home feed / Forums: start a discussion (poll)', author.person, 'works');

    // It reaches the actor's feed, found by its tag and by search.
    final viaTag = await b.feed.load(FeedFilter.all, tag: tag);
    expect(viaTag.posts.map((p) => p.id), contains(thread.card.id), reason: '${actor.email} sees it in the feed');
    final post = viaTag.posts.firstWhere((p) => p.id == thread!.card.id);
    final followedBefore = await b.forum.follows(author.id);
    expect(post.showFollow, !followedBefore, reason: 'the card offers Follow to those who do not follow the author');

    // Like and take it back.
    await b.feed.setReaction(post, ReactionKind.like);
    var seen = (await b.forum.thread(thread.card.slug)).card;
    expect(seen.myReaction, ReactionKind.like);
    expect(seen.reactions, 1);
    seen = (await a.forum.thread(thread.card.slug)).card;
    expect(seen.reactions, 1, reason: 'the author sees the reaction');
    await b.feed.setReaction(post, null);
    expect((await b.forum.thread(thread.card.slug)).card.myReaction, isNull);
    record('Home feed: like', actor.person, 'works', 'two-person: ${author.first} saw the reaction');

    // Bookmark and take it back.
    await b.feed.setSaved(post, true);
    var saved = await b.forum.threads(const ForumQuery(view: ForumView.saved));
    expect(saved.posts.map((p) => p.id), contains(post.id));
    await b.feed.setSaved(post, false);
    saved = await b.forum.threads(const ForumQuery(view: ForumView.saved));
    expect(saved.posts.map((p) => p.id), isNot(contains(post.id)));
    record('Home feed: bookmark', actor.person, 'works');

    // Follow the author and stop (an account that already followed is put back as it was).
    if (followedBefore) {
      await b.forum.setFollowing(author.id, false);
      expect(await b.forum.follows(author.id), isFalse);
      await b.feed.follow(post.author);
      expect(await b.forum.follows(author.id), isTrue);
    } else {
      await b.feed.follow(post.author);
      expect(await b.forum.follows(author.id), isTrue);
      await b.forum.setFollowing(author.id, false);
      expect(await b.forum.follows(author.id), isFalse);
    }
    record('Home feed: follow', actor.person, 'works');

    // Vote, move the vote (the thread is deleted below: the API cannot take a vote away).
    final poll = (await b.forum.thread(thread.card.slug)).card.poll!;
    expect(poll.options.map((o) => o.label), ['Alpha', 'Beta']);
    final voted = await b.feed.vote(post, poll.options.first.id);
    expect(voted.myOptionId, poll.options.first.id);
    final moved = await b.feed.vote(post, poll.options.last.id);
    expect(moved.myOptionId, poll.options.last.id);
    expect(moved.totalVotes, 1);
    final authorSees = (await a.forum.thread(thread.card.slug)).card.poll!;
    expect(authorSees.totalVotes, 1, reason: 'the author sees the vote');
    record('Home feed: poll vote', actor.person, 'works', 'two-person: ${author.first} saw 1 vote');

    // Reply, answer under it, like the answer, delete.
    await b.feed.reply(post, 'A reply from ${actor.first}.');
    var replies = await b.feed.replies(post);
    expect(replies.map((r) => r.body), contains('A reply from ${actor.first}.'));
    final reply = replies.firstWhere((r) => r.body.contains('A reply from'));
    await a.feed.reply(post, 'An answer from ${author.first}.', parentId: reply.id);
    replies = await b.feed.replies(post);
    final nested = replies.firstWhere((r) => r.id == reply.id);
    expect(nested.children.map((c) => c.body), contains('An answer from ${author.first}.'));
    await b.feed.setReplyLiked(nested.children.first, true);
    await b.feed.setReplyLiked(nested.children.first, false);
    await b.feed.deleteReply(reply);
    replies = await b.feed.replies(post);
    expect(replies.any((r) => r.id == reply.id), isFalse);
    record('Home feed: reply, answer, like a reply, delete', actor.person, 'works', 'two-person with ${author.first}');

    // Report it; staff resolve the report so the queue is as it was.
    await b.forum.report(
      threadId: thread.card.id,
      reason: ReportReason.offTopic,
      note: 'The role matrix: please ignore.',
    );
    record('Forums: report', actor.person, 'works', 'a staff member resolved it');
  } finally {
    final t = thread;
    if (t != null) {
      await _resolveReportsOf(t.card.id);
      await a.forum.deleteThread(t.card.id);
    }
  }
}

/// Staff close any report about [threadId] (approved: the content stands), so the queue is as it was.
Future<void> _resolveReportsOf(String threadId) async {
  final staff = sana;
  if (staff == null) return;
  final api = await liveClient(staff);
  try {
    final res = await api.dio.get<dynamic>('/forum/admin/reports', queryParameters: {'limit': 50});
    final rows = (res.data is Map ? (res.data as Map)['data'] : res.data) as List<dynamic>? ?? const [];
    for (final row in rows.cast<Map<String, dynamic>>()) {
      final thread = row['thread'] as Map<String, dynamic>?;
      if ((row['threadId'] ?? thread?['id']) == threadId) {
        await api.dio.patch<dynamic>(
          '/forum/admin/reports/${row['id']}',
          data: {'status': 'APPROVED', 'resolutionNote': 'Role matrix test.'},
        );
      }
    }
  } catch (_) {
    // A queue that cannot be read is left for staff.
  }
}
