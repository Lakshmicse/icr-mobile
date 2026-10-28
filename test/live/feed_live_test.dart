/// The Home feed against the LOCAL portal API, seeded by `tool/seed/home.ts`: the app's own repository and
/// controller, the way the screen uses them, with the effect of every write read back through the API.
///
/// Writes use Pooja Professional and undo themselves: the like, the bookmark, the follow, the poll vote (moved
/// and put back: the API cannot take a poll vote away, so the seed gives her one first) and the reply (deleted
/// again). Bharat Buyer, the person the emulator is signed in as, is only read: his votes, saves and follows
/// are never touched.
///
/// **A reply is never sent to a designed post.** The forum sets a thread's `lastActivityAt` to now on every reply
/// and deleting the reply does not put it back; the feed is ordered pinned first, then by `lastActivityAt`, and the
/// seed gives the four designed posts times ahead of now so they lead in the design's order. A reply to one of them
/// would drop it below the others. Every test that replies, likes a reply or sends a refused reply therefore uses
/// the seed's sandbox discussion (`_sandbox`, unpinned and already the newest unpinned thread), and the designed
/// posts are only read, liked and unliked, saved and unsaved, followed and unfollowed, and voted on and put back:
/// none of those touch `lastActivityAt`. A run leaves the feed as the seed made it, so a second run passes too;
/// the only things left behind are harmless: Pooja follows the sandbox thread (the forum subscribes a replier)
/// and its `lastActivityAt` is a little later than the seed's.
///
/// The forum's limiter allows 120 calls a minute from one address, so the tests share one signed-in client and
/// one loaded feed per person instead of starting over each time.
///
///     flutter test test/live/feed_live_test.dart
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart' show Options, ResponseType;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/feed/api_feed_repository.dart';
import 'package:icr_mobile/features/feed/feed_controller.dart';
import 'package:icr_mobile/features/feed/feed_models.dart';
import 'package:icr_mobile/features/feed/home_screen.dart';
import 'package:provider/provider.dart';

import '../helpers/fonts.dart';
import '../helpers/offline_feed.dart';
import 'live.dart';

/// The four designed discussions, in the design's order, by slug (`home.ts`).
const _sarah = 'implementing-iot-sensors-for-hvac-efficiency-best-practices-home-design';
const _david = 'the-impact-of-ai-on-preliminary-site-feasibility-analysis-home-design';
const _marcus = 'what-is-your-primary-fm-software-in-2026-home-design';
const _elena = 'site-audit-implementing-sustainable-net-zero-solutions-home-design';
const _designSlugs = [_sarah, _david, _marcus, _elena];

/// The discussion the tests that write replies use (`home.ts` THREADS 'sandbox'): by Marcus, unpinned, three replies
/// (Arvind's with two likes and Priya's answer under it, then Priya's newest), no reactions and no views.
const _sandbox = 'handing-bim-data-over-to-the-fm-team-without-rekeying-it-home-design';

/// One person's signed-in client and loaded feed, made once and shared by the tests that use them.
class _Person {
  _Person(this.who);

  final LivePerson who;
  late final ApiClient api;
  late final String id;
  late final ApiFeedRepository repository;
  late final FeedController feed;
  var _ready = false;

  Future<_Person> open() async {
    if (_ready) return this;
    api = await liveClient(who);
    id = (await api.dio.get<Map<String, dynamic>>('/auth/me')).data!['id'] as String;
    repository = ApiFeedRepository(api: api, viewerId: id);
    feed = FeedController(repository);
    await feed.start();
    await _repliesRead(feed);
    _ready = true;
    return this;
  }

  FeedPost? post(String slug) {
    for (final p in feed.posts) {
      if (p.slug == slug) return p;
    }
    return null;
  }

  /// The discussion as the API holds it right now (`GET /forum/threads/:slug`).
  Future<Map<String, dynamic>> thread(String slug) async =>
      (await api.dio.get<Map<String, dynamic>>('/forum/threads/$slug')).data!;

  /// Its replies, as a flat list in tree order.
  Future<List<Map<String, dynamic>>> replies(String slug) async {
    final res = await api.dio.get<Map<String, dynamic>>(
      '/forum/threads/$slug/replies',
      queryParameters: {'page': 1, 'limit': 100},
    );
    final out = <Map<String, dynamic>>[];
    void walk(List<dynamic> nodes) {
      for (final n in nodes.cast<Map<String, dynamic>>()) {
        out.add(n);
        walk(n['children'] as List);
      }
    }

    walk(res.data!['data'] as List);
    return out;
  }
}

final _bharat = _Person(bharat);
final _pooja = _Person(pooja);

/// Waits for the replies a feed opens by itself (the first post's) to arrive; they are asked for in the
/// background, and a screen drawn before they land would still be spinning.
Future<void> _repliesRead(FeedController feed) async {
  for (
    var i = 0;
    i < 100 && feed.posts.any((p) => feed.isLoadingReplies(p) || (feed.isOpen(p) && !p.repliesLoaded));
    i++
  ) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

/// A thread's replies as one list, each followed by its answers.
List<FeedReply> _flatten(List<FeedReply> replies) => [
  for (final r in replies) ...[r, ..._flatten(r.children)],
];

/// Skips the rest of a test when the designed discussions are not in the database.
bool _seeded(_Person person) {
  if (_designSlugs.every((s) => person.post(s) != null)) return true;
  markTestSkipped('the designed posts are not seeded: run tool/seed/run.ps1');
  return false;
}

/// Skips the rest of a test when the sandbox discussion is missing (a database seeded before it existed).
bool _sandboxed(_Person person) {
  if (person.post(_sandbox) != null) return true;
  markTestSkipped('the sandbox discussion is not seeded: run tool/seed/run.ps1 (home) again');
  return false;
}

/// The first four slugs of the feed as the API orders it now (`GET /forum/threads?sort=latest`).
Future<List<String>> _topSlugs(_Person person) async {
  final res = await person.api.dio.get<Map<String, dynamic>>(
    '/forum/threads',
    queryParameters: {'limit': 5, 'sort': 'latest'},
  );
  return [for (final t in (res.data!['data'] as List).take(4)) (t as Map)['slug'] as String];
}

void main() {
  setUpAll(loadAppFonts);

  liveTest(
    'the feed is the API\'s, with the designed posts first and in the design\'s order, worded as the design words them',
    () async {
      final me = await _bharat.open();
      expect(me.feed.error, isNull, reason: 'the feed should load from the local API');
      if (!_seeded(me)) return;

      // Every discussion the API lists is a card, in the API's order.
      final raw = (await me.api.dio.get<Map<String, dynamic>>('/forum/threads', queryParameters: {'limit': 20})).data!;
      final rows = (raw['data'] as List).cast<Map<String, dynamic>>();
      expect(me.feed.posts.map((p) => p.id), rows.map((r) => r['id']));
      expect(me.feed.posts.take(4).map((p) => p.slug), _designSlugs);

      final sarah = me.post(_sarah)!, david = me.post(_david)!, marcus = me.post(_marcus)!, elena = me.post(_elena)!;
      expect([sarah, david, marcus, elena].map((p) => p.title), [
        'Implementing IoT sensors for HVAC efficiency: Best practices?',
        'The impact of AI on preliminary site feasibility analysis',
        'What is your primary FM Software in 2026?',
        'Site Audit: Implementing Sustainable Net-Zero Solutions',
      ]);
      expect([sarah, david, marcus, elena].map((p) => p.author.name), [
        'Sarah Jenkins',
        'David Chen',
        'Marcus Reed',
        'Elena Rostova',
      ]);
      expect(sarah.author.headline, 'Senior Facilities Manager at Google');
      expect(david.author.headline, 'Project Director at BuildCo');
      expect(marcus.author.headline, 'Lead Architect at DesignCo');
      expect(elena.author.headline, 'Civil & Sustainability Engineer');
      expect([sarah, david, marcus, elena].every((p) => p.author.photo?.url != null), isTrue, reason: 'their photos');

      // The word beside the time, and its tint: green for sustainability, blue for the rest.
      expect([sarah, david, marcus, elena].map((p) => p.topic), [
        '#SUSTAINABILITY',
        '#REALESTATETECH',
        '#POLL',
        '#SITEAUDIT',
      ]);
      expect([sarah, david, marcus, elena].map((p) => p.topicTone), [
        TopicTone.green,
        TopicTone.blue,
        TopicTone.blue,
        TopicTone.green,
      ]);
      expect(sarah.tags, ['#HVAC', '#PropTech', '#SmartBMS']);
      expect(david.tags, isEmpty);
      expect(elena.tags, isEmpty);

      // Reactions: the API's count, the three glyphs in the design's order. 184 when the accounts reach it.
      final card = rows.firstWhere((r) => r['slug'] == _sarah);
      expect(sarah.reactions, card['likes']);
      expect(sarah.reactions, greaterThan(100));
      expect(sarah.reactionKinds, [ReactionKind.like, ReactionKind.insightful, ReactionKind.celebrate]);
      expect(sarah.comments, 52);
      expect(sarah.shares, isNull, reason: 'the API counts no shares');
      expect(sarah.views, card['viewCount']);

      // The Follow link: the design's first two posts are not followed, the last two are.
      expect([sarah, david, marcus, elena].map((p) => p.showFollow), [true, true, false, false]);

      // The poll: the design's split, the reader's own vote.
      final poll = marcus.poll!;
      expect(poll.options.map((o) => o.label), ['IBM TRIRIGA', 'Planon', 'Archibus', 'Other / Custom In-House']);
      expect(poll.percents, [28, 14, 46, 12]);
      expect(poll.options.firstWhere((o) => o.id == poll.myOptionId).label, 'Archibus');
      expect(poll.open, isTrue);
      expect(poll.totalVotes, greaterThan(100));

      // The photos: read from each discussion's own page. One for David, captioned; five for Elena.
      expect([sarah, david, marcus, elena].every((p) => p.detailLoaded), isTrue);
      expect(david.images, hasLength(1));
      expect(david.imageCaption, 'BIM Feasibility Lab');
      expect(elena.images, hasLength(2));
      expect(elena.morePhotos, 3);
      expect(sarah.images, isEmpty);
      // And the whole text, not the list's 220-character excerpt.
      final sarahPage = await me.thread(_sarah);
      expect(sarah.body.length, greaterThan(250));
      expect(sarah.body, startsWith('We are currently looking to retrofit a 15- year-old commercial building'));
      expect(sarahPage['bodyHtml'], contains('with reliability.'));
      expect(sarah.body, endsWith('with reliability.'));

      // The reader's own discussions carry no Follow.
      final mine = me.feed.posts.where((p) => p.author.id == me.id);
      expect(mine, isNotEmpty);
      expect(mine.every((p) => !p.showFollow), isTrue);
    },
  );

  liveTest(
    'the first post\'s comments open by themselves: its first reply, its first answer, the rest of that thread, the box',
    () async {
      final me = await _bharat.open();
      if (!_seeded(me)) return;
      final sarah = me.post(_sarah)!;
      expect(me.feed.isOpen(sarah), isTrue);
      expect(sarah.repliesLoaded, isTrue);

      final first = sarah.replies.first;
      expect(first.author.name, 'Arvind Swamy');
      expect(first.meta, 'Brookfield Properties', reason: 'the organisation after "at" in the headline');
      expect(
        first.body,
        'Spot on Priya. Niagara framework BACnet/IP telemetry cut vendor lock-in completely across our commercial assets.',
      );
      expect(first.likes, 3);
      expect(first.children.first.author.name, 'Arvind Swamy');
      expect(first.children.first.likes, 3);
      // "+8 replies in this thread": the first thread's replies its preview leaves out.
      expect(sarah.moreReplies, 8);
      // "Reply to Priya Nambiar...": the newest reply is hers.
      expect(replyTargetFor(sarah.replies, me.id)?.author.name, 'Priya Nambiar');

      // The tree is the API's: the same replies, the same likes.
      final all = await me.replies(_sarah);
      expect(all, hasLength(52));
      expect(all.first['id'], first.id);
      expect(all.first['likes'], 3);
    },
  );

  liveTest('each chip reads what it names, and the search and the topic chip narrow the live forum', () async {
    final me = await _bharat.open();
    if (!_seeded(me)) return;
    final feed = FeedController(me.repository);
    try {
      await feed.setFilter(FeedFilter.trending);
      expect(feed.posts.take(3).map((p) => p.slug), [_sarah, _david, _elena], reason: 'the most reacted, newest first');

      await feed.setFilter(FeedFilter.polls);
      expect(feed.posts.every((p) => p.poll != null), isTrue);
      expect(feed.posts.map((p) => p.slug), contains(_marcus));

      await feed.setFilter(FeedFilter.following);
      final following = feed.posts.map((p) => p.slug).toList();
      expect(following, containsAll([_marcus, _elena]));
      expect(following, isNot(contains(_sarah)));
      expect(following, isNot(contains(_david)));
      expect(feed.posts.every((p) => !p.showFollow), isTrue);

      await feed.setFilter(FeedFilter.unanswered);
      expect(feed.posts.every((p) => p.comments == 0), isTrue);
      expect(feed.posts.map((p) => p.slug), isNot(contains(_sarah)), reason: 'it has replies');

      await feed.setFilter(FeedFilter.all);
      await feed.setTag('HVAC');
      expect(feed.posts.map((p) => p.slug), contains(_sarah));
      expect(feed.posts.every((p) => p.tags.contains('#HVAC')), isTrue);
      await feed.setTag('HVAC');
      expect(feed.tag, isNull);
      expect(feed.posts.map((p) => p.slug).take(4), _designSlugs);

      await feed.setSearch('IoT sensors');
      expect(feed.posts.map((p) => p.slug), contains(_sarah));
      await feed.setSearch('no discussion has this phrase');
      expect(feed.posts, isEmpty);
      await feed.setSearch('');
      expect(feed.posts, isNotEmpty);
    } finally {
      feed.dispose();
    }
  });

  liveTest('the bell\'s count is the member\'s unread notifications', () async {
    final me = await _bharat.open();
    final raw = (await me.api.dio.get<Map<String, dynamic>>('/notifications/unread-count')).data!['unread'] as int;
    expect(await me.repository.unreadNotifications(), raw);
    expect(me.feed.unread, raw);
  });

  liveTest('a like is the API\'s: kept across a fresh read, counted, and taken back', () async {
    final me = await _pooja.open();
    if (!_seeded(me)) return;
    final before = me.post(_sarah)!;
    expect(before.myReaction, isNull, reason: 'the seed leaves the personas without a reaction on the designed posts');
    final rawBefore = await me.thread(_sarah);
    var liked = false;
    addTearDown(() async {
      if (liked) await me.api.dio.delete<dynamic>('/forum/threads/${before.id}/vote');
    });

    liked = true;
    expect(await me.feed.toggleLike(before), isNull);
    expect(me.post(_sarah)!.reactions, before.reactions + 1);
    expect(me.post(_sarah)!.myReaction, ReactionKind.like);

    // The API says the same: the count, the kind, and that it is hers.
    final page = await me.thread(_sarah);
    expect(page['likes'], before.reactions + 1);
    expect((page['reactions'] as Map)['LIKE'], ((rawBefore['reactions'] as Map)['LIKE'] as int) + 1);
    expect(page['myReaction'], 'LIKE');
    await me.feed.refresh();
    expect(me.post(_sarah)!.myReaction, ReactionKind.like, reason: 'kept across a fresh read');

    expect(await me.feed.toggleLike(me.post(_sarah)!), isNull);
    liked = false;
    expect(me.post(_sarah)!.reactions, before.reactions);
    final after = await me.thread(_sarah);
    expect(after['likes'], before.reactions);
    expect(after['myReaction'], isNull);
    expect((after['reactions'] as Map)['LIKE'], (rawBefore['reactions'] as Map)['LIKE']);
  });

  liveTest('a refusal rolls the like back and says why: the reader\'s own discussion cannot be liked', () async {
    final me = await _bharat.open();
    // One of the three the Home seed gives him: `forums.ts` adds a discussion of his that waits for a moderator, which
    // nobody can react to (the forum answers "not found").
    final mine = me.feed.posts.firstWhere((p) => p.author.id == me.id && p.slug.endsWith('-home-design'));
    final message = await me.feed.toggleLike(mine);
    expect(message, 'You cannot vote on your own discussion.');
    expect(me.feed.posts.firstWhere((p) => p.id == mine.id).myReaction, isNull);
    expect(me.feed.posts.firstWhere((p) => p.id == mine.id).reactions, mine.reactions);
    // Following oneself is refused too, with its own sentence.
    expect(
      await me.feed.follow(me.feed.posts.firstWhere((p) => p.author.id == me.id).copyWith(showFollow: true)),
      'You cannot follow yourself.',
    );
  });

  liveTest('a bookmark is kept, listed among the reader\'s saves, and taken back', () async {
    final me = await _pooja.open();
    if (!_seeded(me)) return;
    final david = me.post(_david)!;
    expect(david.saved, isFalse);
    var saved = false;
    addTearDown(() async {
      if (saved) await me.api.dio.delete<dynamic>('/forum/threads/${david.id}/save');
    });

    saved = true;
    expect(await me.feed.toggleSave(david), isNull);
    final mine = (await me.api.dio.get<Map<String, dynamic>>(
      '/forum/saves/mine',
      queryParameters: {'limit': 100},
    )).data!;
    expect((mine['data'] as List).map((t) => (t as Map)['slug']), contains(_david));
    await me.feed.refresh();
    expect(me.post(_david)!.saved, isTrue);

    expect(await me.feed.toggleSave(me.post(_david)!), isNull);
    saved = false;
    final after = (await me.api.dio.get<Map<String, dynamic>>(
      '/forum/saves/mine',
      queryParameters: {'limit': 100},
    )).data!;
    expect((after['data'] as List).map((t) => (t as Map)['slug']), isNot(contains(_david)));
    await me.feed.refresh();
    expect(me.post(_david)!.saved, isFalse);
  });

  liveTest(
    'Follow is kept: the author joins the reader\'s following and the link goes away, until it is undone',
    () async {
      final me = await _pooja.open();
      if (!_seeded(me)) return;
      final sarah = me.post(_sarah)!;
      expect(sarah.showFollow, isTrue);
      var followed = false;
      addTearDown(() async {
        if (followed) await me.api.dio.delete<dynamic>('/members/${sarah.author.id}/follow');
      });

      followed = true;
      expect(await me.feed.follow(sarah), isNull);
      expect(me.post(_sarah)!.showFollow, isFalse);
      Future<List<String>> following() async =>
          ((await me.api.dio.get<Map<String, dynamic>>(
                    '/members/me/following',
                    queryParameters: {'limit': 100},
                  )).data!['data']
                  as List)
              .map((m) => (m as Map)['id'] as String)
              .toList();
      expect(await following(), contains(sarah.author.id));

      // A reader who follows no one else sees them in the Following chip.
      final fresh = FeedController(ApiFeedRepository(api: me.api, viewerId: me.id));
      try {
        await fresh.setFilter(FeedFilter.following);
        expect(fresh.posts.map((p) => p.slug), contains(_sarah));
      } finally {
        fresh.dispose();
      }

      await me.api.dio.delete<dynamic>('/members/${sarah.author.id}/follow');
      followed = false;
      expect(await following(), isNot(contains(sarah.author.id)));
    },
  );

  liveTest('a poll vote moves, the counts follow, and it is put back where it was', () async {
    final me = await _pooja.open();
    if (!_seeded(me)) return;
    final marcus = me.post(_marcus)!;
    final poll = marcus.poll!;
    final original = poll.myOptionId;
    expect(original, isNotNull, reason: 'the seed gives Pooja a vote, since the API cannot take one away');
    final other = poll.options.firstWhere((o) => o.id != original && o.label != 'Archibus');
    addTearDown(() async {
      await me.api.dio.post<dynamic>('/forum/threads/${marcus.id}/poll/vote', data: {'optionId': original});
    });

    expect(await me.feed.vote(marcus, other.id), isNull);
    final moved = me.post(_marcus)!.poll!;
    expect(moved.myOptionId, other.id);
    expect(moved.totalVotes, poll.totalVotes, reason: 'moving a vote adds none');
    expect(moved.options.firstWhere((o) => o.id == other.id).votes, other.votes + 1);
    expect(
      moved.options.firstWhere((o) => o.id == original).votes,
      poll.options.firstWhere((o) => o.id == original).votes - 1,
    );

    // The API holds the same.
    final api = (await me.thread(_marcus))['poll'] as Map<String, dynamic>;
    expect(api['myOptionId'], other.id);
    expect((api['options'] as List).map((o) => (o as Map)['votes']), moved.options.map((o) => o.votes));

    // The same option again asks nothing; the original puts everything back.
    expect(await me.feed.vote(me.post(_marcus)!, other.id), isNull);
    expect(await me.feed.vote(me.post(_marcus)!, original!), isNull);
    final back = me.post(_marcus)!.poll!;
    expect(back.myOptionId, original);
    expect(back.options.map((o) => o.votes), poll.options.map((o) => o.votes));
    expect(back.totalVotes, poll.totalVotes);
  });

  liveTest('a reply is sent under the newest reply, shown, liked by the reader, and taken back', () async {
    final me = await _pooja.open();
    if (!_seeded(me) || !_sandboxed(me)) return;
    // Opening the discussion reads its replies, the way tapping the speech bubble does.
    me.feed.openReplies(me.post(_sandbox)!);
    await _repliesRead(me.feed);
    final sandbox = me.post(_sandbox)!;
    expect(sandbox.repliesLoaded, isTrue);
    final before = sandbox.comments;
    expect(before, 3, reason: 'the seed gives it three replies');
    // "Reply to Priya Nambiar...": the newest reply that is not the reader's, here Priya's third.
    final target = replyTargetFor(sandbox.replies, me.id)!;
    expect(target.author.name, 'Priya Nambiar');
    expect(target.body, startsWith('Whoever runs the CAFM'));
    const text = 'Live test: thanks, the COBie point is useful. <b>Not markup</b> & more.';
    String? sentId;
    addTearDown(() async {
      if (sentId != null) await me.api.dio.delete<dynamic>('/forum/replies/$sentId');
    });

    expect(await me.feed.sendReply(sandbox, text, parentId: target.id), isNull);
    expect(me.post(_sandbox)!.comments, before + 1);
    final sent = (await me.replies(_sandbox)).firstWhere((r) => (r['author'] as Map)['id'] == me.id);
    sentId = sent['id'] as String;
    expect(sent['parentId'], target.id, reason: 'under the reply the box named');
    expect(
      sent['bodyHtml'],
      '<p>Live test: thanks, the COBie point is useful. &lt;b&gt;Not markup&lt;/b&gt; &amp; more.</p>',
      reason: 'a reply is plain text: what looks like markup is kept as the words typed',
    );
    // The app reads it back in the thread, under Priya's reply.
    final mine = _flatten(me.post(_sandbox)!.replies).firstWhere((r) => r.id == sentId);
    expect(mine.author.id, me.id);
    expect(
      (_flatten(me.post(_sandbox)!.replies).firstWhere((r) => r.id == target.id)).children.map((r) => r.id),
      contains(sentId),
    );
    // The reply made the sandbox "active now", and that is all it moved: the designed posts still lead, in order.
    expect(await _topSlugs(me), _designSlugs, reason: 'a reply must never reorder the designed posts');

    // Like another reply of the thread, and take it back.
    final arvind = me.post(_sandbox)!.replies.first;
    expect(arvind.author.name, 'Arvind Swamy');
    expect(arvind.liked, isFalse);
    final likes = arvind.likes;
    expect(likes, 2);
    expect(await me.feed.toggleReplyLike(me.post(_sandbox)!, arvind), isNull);
    expect(me.post(_sandbox)!.replies.first.likes, likes + 1);
    expect((await me.replies(_sandbox)).first['likes'], likes + 1);
    await me.feed.refresh();
    expect(me.post(_sandbox)!.replies.first.liked, isTrue, reason: 'kept across a fresh read');
    expect(await me.feed.toggleReplyLike(me.post(_sandbox)!, me.post(_sandbox)!.replies.first), isNull);
    expect((await me.replies(_sandbox)).first['likes'], likes);

    // The reader's own reply cannot be liked: the API says so, and the like is not kept.
    expect(await me.feed.toggleReplyLike(me.post(_sandbox)!, mine), 'You cannot vote on your own reply.');
    expect(_flatten(me.post(_sandbox)!.replies).firstWhere((r) => r.id == sentId).liked, isFalse);

    // Taken back: the reply is gone and the count is the seed's again.
    expect(await me.feed.deleteReply(me.post(_sandbox)!, mine), isNull);
    sentId = null;
    expect(me.post(_sandbox)!.comments, before);
    expect((await me.replies(_sandbox)).where((r) => (r['author'] as Map)['id'] == me.id), isEmpty);
    expect((await me.thread(_sandbox))['replyCount'], before);
    expect(await _topSlugs(me), _designSlugs);
  });

  liveTest('a refused reply says why: a reply to a reply the forum no longer has', () async {
    final me = await _pooja.open();
    if (!_seeded(me) || !_sandboxed(me)) return;
    await me.feed.refresh();
    final before = me.post(_sandbox)!.comments;
    final message = await me.feed.sendReply(me.post(_sandbox)!, 'This goes nowhere.', parentId: 'no-such-reply');
    expect(message, 'The reply you are answering is no longer here.');
    expect(me.post(_sandbox)!.comments, before);
    expect((await me.thread(_sandbox))['replyCount'], before);
    expect(await _topSlugs(me), _designSlugs);
  });

  liveTest('pulling down reads what the server holds now', () async {
    final watcher = await _bharat.open();
    final actor = await _pooja.open();
    if (!_seeded(watcher)) return;
    final david = actor.post(_david)!;
    final before = watcher.post(_david)!.reactions;
    var liked = false;
    addTearDown(() async {
      if (liked) await actor.api.dio.delete<dynamic>('/forum/threads/${david.id}/vote');
    });

    liked = true;
    await actor.api.dio.post<dynamic>('/forum/threads/${david.id}/vote', data: {'value': 1, 'reaction': 'LIKE'});
    // Bharat's screen shows it only after the pull.
    expect(watcher.post(_david)!.reactions, before);
    await watcher.feed.pullToRefresh();
    await _repliesRead(watcher.feed);
    expect(watcher.post(_david)!.reactions, before + 1);

    await actor.api.dio.delete<dynamic>('/forum/threads/${david.id}/vote');
    liked = false;
    await watcher.feed.pullToRefresh();
    await _repliesRead(watcher.feed);
    expect(watcher.post(_david)!.reactions, before);
    expect(watcher.post(_david)!.detailLoaded, isTrue, reason: 'the full texts and photos are read again with it');
  });

  liveTest('the links open pages the API knows: the discussion, and a reply on it', () async {
    final me = await _bharat.open();
    if (!_seeded(me)) return;
    final sarah = me.post(_sarah)!;
    final link = me.repository.link(sarah);
    expect(link.path, '/community/$_sarah');
    expect((await me.thread(_sarah))['id'], sarah.id);
    final reply = sarah.replies.first;
    expect(me.repository.link(sarah, reply: reply).fragment, 'reply-${reply.id}');
    expect(me.repository.link(sarah, reply: reply).path, '/community/$_sarah');
  });

  liveTest('the designed photos and avatars are real uploads the API serves', () async {
    final me = await _bharat.open();
    if (!_seeded(me)) return;
    for (final p in [me.post(_sarah)!, me.post(_david)!, me.post(_marcus)!, me.post(_elena)!]) {
      final res = await me.api.dio.get<List<int>>(
        p.author.photo!.url!,
        options: Options(responseType: ResponseType.bytes),
      );
      expect(res.statusCode, 200);
      expect(res.data, isNotEmpty);
    }
    for (final picture in [...me.post(_david)!.images, ...me.post(_elena)!.images]) {
      final res = await me.api.dio.get<List<int>>(picture.url!, options: Options(responseType: ResponseType.bytes));
      expect(res.statusCode, 200);
      expect(res.data!.length, greaterThan(10000));
    }
  });

  group('the screen, drawn from the live API', () {
    Future<void> pumpLive(WidgetTester tester, {required String shot, double height = 3992}) async {
      final person = (await tester.runAsync(_bharat.open))!;
      // A feed of its own, so the screen starts from a fresh load (and its replies, which open by themselves).
      final controller = await tester.runAsync(() async {
        final c = FeedController(OfflineFeed(person.repository, assets: _designPhotos));
        await c.start();
        await _repliesRead(c);
        return c;
      });
      if (controller == null || controller.error != null) fail('the feed did not load: ${controller?.error}');
      tester.view.physicalSize = Size(780, height);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: ChangeNotifierProvider.value(
            value: controller,
            child: HomeScreen(
              viewer: const FeedAuthor(
                id: 'me',
                name: 'Bharat Buyer',
                photo: FeedPicture.asset('assets/images/demo/avatar_me.jpg'),
              ),
              onAccount: () {},
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        for (final element in find.byType(Image).evaluate()) {
          await precacheImage((element.widget as Image).image, element);
        }
        final context = tester.element(find.byType(Scaffold).first);
        await precacheImage(const AssetImage('assets/images/demo/sponsored_bg.jpg'), context);
      });
      await tester.pumpAndSettle();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.ancestor(of: find.byType(HomeScreen), matching: find.byType(RepaintBoundary)).first,
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory('build/screens').createSync(recursive: true);
        File('build/screens/$shot.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }

    testWidgets('the top of the feed reads as the design, with the local database\'s content', tags: const ['live'], (
      tester,
    ) async {
      if (!(await tester.runAsync(liveApiReachable))!) {
        markTestSkipped('the local API is not running at $liveBaseUrl');
        return;
      }
      await pumpLive(tester, shot: 'home_live');
      expect(tester.takeException(), isNull);
      if (find.text('Sarah Jenkins').evaluate().isEmpty) {
        markTestSkipped('the designed posts are not seeded: run tool/seed/run.ps1');
        return;
      }

      // The four posts and the placement, in the design's words.
      expect(find.text('Sarah Jenkins'), findsOneWidget);
      expect(find.text('Follow'), findsNWidgets(2), reason: 'Sarah and David are not followed; Marcus and Elena are');
      expect(find.text('Senior Facilities Manager at Google'), findsOneWidget);
      expect(find.textContaining('#SUSTAINABILITY', findRichText: true), findsOneWidget);
      expect(find.textContaining('#REALESTATETECH', findRichText: true), findsOneWidget);
      expect(find.textContaining('#POLL', findRichText: true), findsOneWidget);
      expect(find.textContaining('#SITEAUDIT', findRichText: true), findsOneWidget);
      expect(find.text('#HVAC'), findsWidgets);
      expect(find.text('#SmartBMS'), findsOneWidget);
      expect(find.text('184 reactions'), findsNWidgets(3));
      expect(find.text('52 comments'), findsNWidgets(3));
      expect(find.textContaining(RegExp(r'^ · [\d,]+ views$')), findsNWidgets(3));
      expect(find.text('BIM Feasibility Lab'), findsOneWidget);
      expect(find.text('+3 photos'), findsOneWidget);
      expect(find.text('Archibus (Your vote)'), findsOneWidget);
      expect(find.textContaining(RegExp(r'^\d+ votes • Open$')), findsOneWidget);
      expect(find.text('SPONSORED PARTNER'), findsOneWidget);
      expect(find.text('The Future of FM Operations'), findsOneWidget);

      // The first post's comments, open, as the design draws them.
      expect(find.text('Arvind Swamy'), findsNWidgets(2));
      expect(find.text('+8 replies in this thread'), findsOneWidget);
      expect(find.text('Reply to Priya Nambiar...'), findsOneWidget);
    });
  });
}

/// The design's photos and avatars, which the seed uploads as `design-home-*`, by their bundled twins.
const _designPhotos = {
  'design-home-avatar_sarah.jpg': 'avatar_sarah.jpg',
  'design-home-avatar_david.jpg': 'avatar_david.jpg',
  'design-home-avatar_marcus.jpg': 'avatar_marcus.jpg',
  'design-home-avatar_elena.jpg': 'avatar_elena.jpg',
  'design-home-avatar_arvind.jpg': 'avatar_arvind.jpg',
  'design-persona-me.jpg': 'avatar_me.jpg',
  'design-home-post_control_room.jpg': 'post_control_room.jpg',
  'design-home-post_green_tower.jpg': 'post_green_tower.jpg',
  'design-home-post_rooftop_hvac.jpg': 'post_rooftop_hvac.jpg',
};
