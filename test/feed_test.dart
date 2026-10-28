import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/auth/token_store.dart';
import 'package:icr_mobile/core/util/time_ago.dart';
import 'package:icr_mobile/features/feed/api_feed_repository.dart';
import 'package:icr_mobile/features/feed/demo_feed_repository.dart';
import 'package:icr_mobile/features/feed/feed_controller.dart';
import 'package:icr_mobile/features/feed/feed_models.dart';
import 'package:icr_mobile/features/feed/feed_repository.dart';
import 'helpers/feed_fixtures.dart';

/// Answers requests from a table instead of the network.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.routes);

  final Map<String, Object? Function(RequestOptions)> routes;
  final List<RequestOptions> seen = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    seen.add(options);
    final handler = routes['${options.method} ${options.path}'];
    if (handler == null) {
      return ResponseBody.fromString('{"statusCode":404,"message":"Not found"}', 404, headers: _json);
    }
    final body = handler(options);
    if (body is (int, String)) return ResponseBody.fromString(body.$2, body.$1, headers: _json);
    return ResponseBody.fromString(body == null ? '' : jsonEncode(body), 200, headers: _json);
  }

  static final _json = {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  };

  @override
  void close({bool force = false}) {}
}

Map<String, Object?> _thread({
  String id = 't1',
  Map<String, Object?>? poll,
  Map<String, Object?> reactions = const {'LIKE': 5, 'INSIGHTFUL': 9, 'CELEBRATE': 1, 'SUPPORT': 2},
  String authorId = 'u2',
}) => {
  'id': id,
  'slug': 'slug-$id',
  'title': 'Chiller retrofit',
  'excerpt': 'Has anyone…',
  'kind': 'QUESTION',
  'status': 'OPEN',
  'tags': ['HVAC', 'PropTech'],
  'category': {'id': 'c', 'key': 'MEP', 'name': 'Smart Buildings & IoT', 'slug': 'smart'},
  'subcategory': null,
  'author': {
    'id': authorId,
    'firstName': 'Sarah',
    'lastName': 'Jenkins',
    'avatarUrl': '/uploads/a.jpg',
    'headline': 'FM at Google',
  },
  'replyCount': 3,
  'likes': 17,
  'createdAt': '2026-10-22T08:00:00.000Z',
  'myVote': null,
  'myReaction': null,
  'reactions': reactions,
  'poll': poll,
  'saved': true,
  'latestReply': null,
};

ApiClient _client(_FakeAdapter adapter) {
  final api = ApiClient(tokens: _MemoryTokens(), baseUrl: 'http://api.test/api/v1');
  api.dio.httpClientAdapter = adapter;
  return api;
}

class _MemoryTokens extends TokenStore {
  _MemoryTokens() : super();
  @override
  Future<String?> accessToken() async => null;
  @override
  Future<String?> refreshToken() async => null;
}

void main() {
  group('ApiFeedRepository', () {
    test('maps a forum thread onto a feed post', () async {
      final adapter = _FakeAdapter({
        'GET /members/me/following': (_) => {'data': [], 'meta': {}},
        'GET /forum/threads': (_) => {
          'data': [_thread()],
          'meta': {'hasNext': true},
        },
      });
      final repo = ApiFeedRepository(api: _client(adapter), viewerId: 'me');
      final page = await repo.load(FeedFilter.all);
      final post = page.posts.single;

      expect(page.hasMore, isTrue);
      expect(post.author.name, 'Sarah Jenkins');
      expect(post.author.headline, 'FM at Google');
      expect(post.author.photo?.url, 'http://api.test/uploads/a.jpg');
      expect(post.topic, 'Smart Buildings & IoT', reason: 'the category as the forum names it, not a hashtag');
      expect(post.tags, ['#HVAC', '#PropTech']);
      expect(post.reactions, 17);
      expect(post.reactionKinds, [ReactionKind.insightful, ReactionKind.like, ReactionKind.support]);
      expect(post.comments, 3);
      expect(post.shares, isNull, reason: 'the API counts no shares');
      expect(post.saved, isTrue);
      expect(post.showFollow, isTrue);
      expect(adapter.seen.last.queryParameters['sort'], 'latest');
    });

    test('maps the chips onto the forum sorts', () async {
      final adapter = _FakeAdapter({
        'GET /members/me/following': (_) => {'data': [], 'meta': {}},
        'GET /forum/threads': (_) => {
          'data': [],
          'meta': {'hasNext': false},
        },
      });
      final repo = ApiFeedRepository(api: _client(adapter), viewerId: 'me');
      await repo.load(FeedFilter.trending);
      expect(adapter.seen.last.queryParameters['sort'], 'top');
      await repo.load(FeedFilter.unanswered, search: ' chiller ');
      expect(adapter.seen.last.queryParameters['sort'], 'unanswered');
      expect(adapter.seen.last.queryParameters['search'], 'chiller');
    });

    test('Polls keeps only threads with a poll; Following only followed authors', () async {
      final poll = {
        'id': 'p',
        'totalVotes': 4,
        'myOptionId': 'b',
        'options': [
          {'id': 'a', 'label': 'Planon', 'votes': 1},
          {'id': 'b', 'label': 'Archibus', 'votes': 3},
        ],
      };
      final adapter = _FakeAdapter({
        'GET /members/me/following': (_) => {
          'data': [
            {'id': 'u9'},
          ],
          'meta': {},
        },
        'GET /forum/threads': (_) => {
          'data': [_thread(id: 'a'), _thread(id: 'b', poll: poll, authorId: 'u9')],
          'meta': {'hasNext': true},
        },
      });
      final repo = ApiFeedRepository(api: _client(adapter), viewerId: 'me');

      final polls = await repo.load(FeedFilter.polls);
      expect(polls.posts.map((p) => p.id), ['b']);
      expect(polls.posts.single.topic, 'Poll');
      expect(polls.posts.single.poll!.percents, [25, 75]);
      expect(polls.hasMore, isFalse);

      final following = await repo.load(FeedFilter.following);
      expect(following.posts.map((p) => p.id), ['b']);
      expect(following.posts.single.showFollow, isFalse);
    });

    test("an API refusal arrives as the API's sentence", () async {
      final adapter = _FakeAdapter({
        'POST /forum/threads/t1/vote': (_) =>
            (400, '{"statusCode":400,"message":"You cannot vote on your own discussion."}'),
      });
      final repo = ApiFeedRepository(api: _client(adapter), viewerId: 'me');
      final post = FeedPost(
        id: 't1',
        slug: 's',
        author: const FeedAuthor(id: 'me', name: 'Me'),
        createdAt: DateTime(2026),
        title: 't',
        body: 'b',
      );
      expect(
        () => repo.setReaction(post, ReactionKind.like),
        throwsA(isA<ApiError>().having((e) => e.message, 'message', 'You cannot vote on your own discussion.')),
      );
    });
  });

  group('FeedController', () {
    test('undoes a like the API refuses', () async {
      final repo = _RefusingRepository();
      final feed = FeedController(repo);
      await feed.refresh();
      final before = feed.posts.first;

      final message = await feed.toggleLike(before);

      expect(message, 'No');
      expect(feed.posts.first.reactions, before.reactions);
      expect(feed.posts.first.myReaction, isNull);
    });

    test('liking then unliking a post with no other reactions empties the stack', () async {
      final feed = FeedController(_BareRepository());
      await feed.refresh();
      await feed.toggleLike(feed.posts.first);
      expect(feed.posts.first.reactions, 1);
      expect(feed.posts.first.reactionKinds, [ReactionKind.like]);
      await feed.toggleLike(feed.posts.first);
      expect(feed.posts.first.reactions, 0);
      expect(feed.posts.first.reactionKinds, isEmpty);
      expect(feed.posts.first.myReaction, isNull);
    });

    test('a topic chip loads that tag, and tapping it again goes back', () async {
      final feed = FeedController(DemoFeedRepository());
      await feed.refresh();
      await feed.setTag('HVAC');
      expect(feed.tag, 'HVAC');
      expect(feed.posts.map((p) => p.id), ['iot-hvac']);
      await feed.setTag('HVAC');
      expect(feed.tag, isNull);
      expect(feed.posts, hasLength(4));
    });

    test('the demo opens the first post with its replies', () async {
      final feed = FeedController(DemoFeedRepository());
      await feed.refresh();
      expect(feed.posts, hasLength(4));
      expect(feed.isOpen(feed.posts.first), isTrue);
      expect(feed.posts.first.moreReplies, 8);
    });
  });

  test('poll shares add up to 100', () {
    const poll = FeedPoll(
      id: 'p',
      totalVotes: 842,
      options: [
        FeedPollOption(id: 'a', label: 'a', votes: 236),
        FeedPollOption(id: 'b', label: 'b', votes: 118),
        FeedPollOption(id: 'c', label: 'c', votes: 387),
        FeedPollOption(id: 'd', label: 'd', votes: 101),
      ],
    );
    expect(poll.percents, [28, 14, 46, 12]);
  });

  test('timeAgo', () {
    final now = DateTime(2026, 10, 22, 12);
    expect(timeAgo(now.subtract(const Duration(seconds: 20)), now: now), 'just now');
    expect(timeAgo(now.subtract(const Duration(minutes: 42)), now: now), '42m ago');
    expect(timeAgo(now.subtract(const Duration(hours: 5)), now: now), '5h ago');
    expect(timeAgo(now.subtract(const Duration(days: 3)), now: now), '3d ago');
    expect(timeAgo(DateTime(2026, 9, 1), now: now), '1 Sep');
    expect(timeAgo(DateTime(2025, 9, 1), now: now), '1 Sep 2025');
  });

  group('the replies of a thread', () {
    FeedReply reply(String id, String name, {int minutesAgo = 10, List<FeedReply> children = const []}) => FeedReply(
      id: id,
      author: FeedAuthor(id: 'u-$name', name: name),
      body: 'b',
      createdAt: DateTime(2026, 10, 23, 12).subtract(Duration(minutes: minutesAgo)),
      children: children,
    );

    FeedPost post(List<FeedReply> replies, {int comments = 0}) => FeedPost(
      id: 'p',
      slug: 's',
      author: const FeedAuthor(id: 'a', name: 'Author'),
      createdAt: DateTime(2026),
      title: 't',
      body: 'b',
      comments: comments,
      replies: replies,
      repliesLoaded: true,
    );

    test('"+N replies in this thread" counts what the first thread\'s preview leaves out', () {
      // The design's thread: a reply, its first answer drawn, eight more in that thread.
      final inThread = [for (var i = 0; i < 9; i++) reply('c$i', 'Member $i')];
      final p = post([
        reply('r1', 'Arvind', children: inThread),
        reply('r2', 'Anita'),
        reply('r3', 'Karthik'),
      ], comments: 12);
      expect(p.moreReplies, 8);
    });

    test(
      'with nothing more in the first thread it counts every reply still out of sight, so the rest can be opened',
      () {
        final p = post([reply('r1', 'Arvind'), reply('r2', 'Anita'), reply('r3', 'Karthik')], comments: 3);
        expect(p.moreReplies, 2);
        // A first reply with one answer, and two more threads: the answer is drawn, the other two hidden.
        expect(
          post([
            reply('r1', 'A', children: [reply('c', 'B')]),
            reply('r2', 'C'),
            reply('r3', 'D'),
          ], comments: 4).moreReplies,
          2,
        );
      },
    );

    test('a count the API gives beyond what was loaded still shows, and nothing hidden shows nothing', () {
      expect(post([reply('r1', 'A')], comments: 5).moreReplies, 4);
      expect(post([reply('r1', 'A')], comments: 1).moreReplies, 0);
      expect(post(const [], comments: 4).moreReplies, 0, reason: 'nothing is loaded to open yet');
    });

    test('the sample\'s own count wins, as the design sets it by hand', () {
      final p = FeedPost(
        id: 'p',
        slug: 's',
        author: const FeedAuthor(id: 'a', name: 'A'),
        createdAt: DateTime(2026),
        title: 't',
        body: 'b',
        moreRepliesOverride: 8,
        replies: [reply('r1', 'Arvind')],
      );
      expect(p.moreReplies, 8);
    });

    test('the box continues the newest reply that is not the reader\'s own', () {
      final replies = [
        reply('r1', 'Arvind', minutesAgo: 42, children: [reply('r2', 'Priya', minutesAgo: 3)]),
        reply('r3', 'Me', minutesAgo: 1),
        reply('r4', 'Anita', minutesAgo: 20),
      ];
      expect(replyTargetFor(replies, 'u-Me')?.id, 'r2');
      expect(replyTargetFor(replies, 'u-Priya')?.id, 'r3');
      expect(replyTargetFor([reply('x', 'Me')], 'u-Me'), isNull);
      expect(replyTargetFor(const [], 'u-Me'), isNull);
    });
  });

  group('ApiFeedRepository: the discussion\'s own page', () {
    ApiFeedRepository repo(Map<String, Object?> detail) =>
        repositoryOn(FakeForum({'GET /forum/threads/slug': (_) => detail}));
    final post = FeedPost(
      id: 't',
      slug: 'slug',
      author: const FeedAuthor(id: 'a', name: 'A'),
      createdAt: DateTime(2026),
      title: 't',
      body: 'excerpt…',
    );

    test('the whole text comes back as plain words, paragraphs on their own lines, entities decoded', () async {
      final d = await repo({
        'bodyHtml': '<p>One &amp; two.</p><p>Three<br>four &quot;five&quot;.</p>',
        'attachment': null,
      }).detail(post);
      expect(d!.body, 'One & two.\nThree\nfour "five".');
      expect(d.images, isEmpty);
      expect(d.morePhotos, 0);
      expect(d.caption, isNull);
    });

    test('an attachment that is a picture is the photo, and a file name that reads as words is its caption', () async {
      final d = await repo({
        'bodyHtml': '<p>x</p>',
        'attachment': {'uploadId': 'abc123.jpg', 'fileName': 'BIM Feasibility Lab.jpg', 'fileSize': 100},
      }).detail(post);
      expect(d!.images.single.url, 'http://api.test/uploads/abc123.jpg');
      expect(d.caption, 'BIM Feasibility Lab');
    });

    test('a camera\'s file name is no caption, nor is a name too long for the pill', () async {
      for (final name in [
        'IMG_20260922_134512.jpg',
        'DSC0042.PNG',
        'A really quite long photograph title that cannot fit.jpg',
      ]) {
        final d = await repo({
          'bodyHtml': '<p>x</p>',
          'attachment': {'uploadId': 'abc.jpg', 'fileName': name, 'fileSize': 1},
        }).detail(post);
        expect(d!.images, hasLength(1), reason: name);
        expect(d.caption, isNull, reason: name);
      }
    });

    test('an attachment that is a document is not a photo', () async {
      final d = await repo({
        'bodyHtml': '<p>x</p>',
        'attachment': {'uploadId': 'spec.pdf', 'fileName': 'Spec sheet.pdf', 'fileSize': 1},
      }).detail(post);
      expect(d!.images, isEmpty);
      expect(d.caption, isNull);
    });

    test(
      'images in the body follow the attachment: two are drawn, the rest counted, and a caption only on one',
      () async {
        final d = await repo({
          'bodyHtml':
              '<p>x</p><img src="/uploads/a.jpg" alt="a"><IMG alt="b" SRC=\'/uploads/b.png\'><img src="https://cdn.test/c.webp">',
          'attachment': {'uploadId': 'main.jpg', 'fileName': 'Green tower.jpg', 'fileSize': 1},
        }).detail(post);
        expect(d!.images.map((p) => p.url), ['http://api.test/uploads/main.jpg', 'http://api.test/uploads/a.jpg']);
        expect(d.morePhotos, 2);
        expect(d.caption, isNull, reason: 'a caption is drawn on a lone photo');
        expect(d.body, 'x', reason: 'the images are not text');
      },
    );

    test('a failing page is an ApiError, and the controller keeps the list\'s excerpt', () async {
      final api = FakeForum({
        'GET /forum/threads': (_) => page([threadCard('t1', excerpt: 'Just the excerpt.')]),
        'GET /members/me/following': (_) => page(const []),
        'GET /forum/threads/slug-t1': (_) => (500, '{"message":"down"}'),
      });
      final feed = FeedController(repositoryOn(api));
      await feed.refresh();
      expect(feed.posts.single.body, 'Just the excerpt.');
      expect(feed.posts.single.detailLoaded, isFalse);
      feed.dispose();
    });
  });

  group('FeedController: reading cards, refreshing, answers that arrive late', () {
    test('a card is read once however often it comes on screen, and a pull reads it again', () async {
      final world = FeedWorld();
      final api = FakeForum(world.routes());
      final feed = FeedController(repositoryOn(api));
      await feed.start();
      expect(api.to('GET', '/forum/threads/slug-iot'), hasLength(1));
      await feed.ensureDetail(feed.posts.first);
      await feed.ensureDetail(feed.posts.first);
      expect(api.to('GET', '/forum/threads/slug-iot'), hasLength(1));
      await feed.pullToRefresh();
      expect(api.to('GET', '/forum/threads/slug-iot'), hasLength(2));
      feed.dispose();
    });

    test('only the first cards are read before the feed shows; the others when they come on screen', () async {
      final world = FeedWorld();
      world.threads = [for (var i = 0; i < 10; i++) threadCard('t$i', title: 'Discussion $i')];
      world.replies = {};
      world.details = {};
      final api = FakeForum(world.routes());
      final feed = FeedController(repositoryOn(api));
      await feed.refresh();
      expect(feed.posts.take(FeedController.prefetchedCards).every((p) => p.detailLoaded), isTrue);
      expect(feed.posts.skip(FeedController.prefetchedCards).any((p) => p.detailLoaded), isFalse);
      expect(
        api.calls.where((c) => c.startsWith('GET /forum/threads/slug-')),
        hasLength(FeedController.prefetchedCards),
      );

      await feed.ensureDetail(feed.posts.last);
      expect(feed.posts.last.detailLoaded, isTrue);
      feed.dispose();
    });

    test('a refresh keeps the replies a thread was showing while they are read again', () async {
      final world = FeedWorld();
      final api = FakeForum(world.routes());
      final feed = FeedController(repositoryOn(api));
      await feed.start();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(feed.isOpen(feed.posts.first), isTrue);
      expect(feed.posts.first.repliesLoaded, isTrue);
      final before = feed.posts.first.replies.length;

      final refreshing = feed.refresh();
      // While the list is read again nothing is blanked.
      await Future<void>.delayed(Duration.zero);
      await refreshing;
      expect(feed.posts.first.repliesLoaded, isTrue);
      expect(feed.posts.first.replies, hasLength(before));
      feed.dispose();
    });

    test('an answer that arrives after the screen has gone does nothing', () async {
      final world = FeedWorld();
      final api = FakeForum(world.routes());
      final feed = FeedController(repositoryOn(api));
      await feed.start();
      feed.dispose();
      // The replies the lead thread asked for may land now: no error, no rebuild of a disposed controller.
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(feed.posts, isNotEmpty);
    });

    test('taking a reply back asks the API and counts it out; a refusal says why', () async {
      final world = FeedWorld();
      final api = FakeForum({
        ...world.routes(),
        'DELETE /forum/replies/a2': (_) => {'success': true},
        'DELETE /forum/replies/a1': (_) => (403, '{"message":"You can only delete your own replies."}'),
      });
      final feed = FeedController(repositoryOn(api));
      await feed.start();
      final audit = feed.posts.firstWhere((p) => p.id == 'audit');
      feed.toggleReplies(audit);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final read = feed.posts.firstWhere((p) => p.id == 'audit');
      expect(await feed.deleteReply(read, read.replies.last), isNull);
      expect(feed.posts.firstWhere((p) => p.id == 'audit').comments, 1);
      expect(await feed.deleteReply(read, read.replies.first), 'You can only delete your own replies.');
      expect(feed.posts.firstWhere((p) => p.id == 'audit').comments, 1);
      feed.dispose();
    });

    test('the lead thread opens once, on the first All Feed load, and a closed thread stays closed', () async {
      final world = FeedWorld();
      final api = FakeForum(world.routes());
      final feed = FeedController(repositoryOn(api));
      await feed.start();
      expect(feed.isOpen(feed.posts.first), isTrue);
      feed.toggleReplies(feed.posts.first);
      expect(feed.isOpen(feed.posts.first), isFalse);
      await feed.refresh();
      expect(feed.isOpen(feed.posts.first), isFalse, reason: 'a person closed it');
      feed.dispose();
    });

    test('the demo opens only what it says and has no lead thread of its own', () async {
      final repo = DemoFeedRepository();
      expect(repo.opensLeadThread, isFalse);
      expect(repo.initiallyOpen, {'iot-hvac'});
      expect(await repo.detail((await repo.load(FeedFilter.all)).posts.first), isNull);
    });
  });

  group('ApiFeedRepository: the rest of the mapping', () {
    test('the sponsored placement carries the design\'s copy and points at the Supplier Mart', () {
      final s = repositoryOn(FakeForum({})).sponsored;
      expect(s.label, 'SPONSORED PARTNER');
      expect(s.title, 'The Future of FM Operations');
      expect(s.body, startsWith('Automated spatial control, predictive fault detection, and seamless BMS telemetry.'));
      expect(s.body, endsWith('Benchmark leases and cut OPEX by 18%.'));
      expect(s.cta, 'Learn More');
      expect(s.link, '/vendors');
    });

    test('a headline gives its organisation for a reply\'s line: after "at", "@" or the dot, else the whole', () {
      expect(ApiFeedRepository.organisationOf('General Counsel at Brookfield Properties'), 'Brookfield Properties');
      expect(ApiFeedRepository.organisationOf('Director · Brookfield'), 'Brookfield');
      expect(ApiFeedRepository.organisationOf('VP Facilities @ Infosys'), 'Infosys');
      expect(ApiFeedRepository.organisationOf('Civil & Sustainability Engineer'), 'Civil & Sustainability Engineer');
      expect(ApiFeedRepository.organisationOf('  '), isNull);
      expect(ApiFeedRepository.organisationOf(null), isNull);
    });

    test('the reader follows more than a hundred people: every page of them is read', () async {
      final api = FakeForum({
        'GET /members/me/following': (o) {
          final p = o.queryParameters['page'] as int;
          return {
            'data': [for (var i = 0; i < (p == 1 ? 100 : 5); i++) member('u-$p-$i', 'Member $p $i')],
            'meta': {'hasNext': p == 1},
          };
        },
        'GET /forum/threads': (_) => page([
          threadCard('x', author: member('u-1-3', 'On the first page')),
          threadCard('y', author: member('u-2-4', 'On the second page')),
          threadCard('z', author: member('u-9-9', 'Not followed')),
        ]),
      });
      final posts = (await repositoryOn(api).load(FeedFilter.all)).posts;
      expect(api.to('GET', '/members/me/following'), hasLength(2));
      expect(posts.map((p) => p.showFollow), [false, false, true]);
    });

    test('a topic is tinted green for the sustainability families and blue for the rest and for polls', () async {
      final api = FakeForum({
        'GET /members/me/following': (_) => page(const []),
        'GET /forum/threads': (_) => page([
          threadCard(
            'a',
            categoryKey: 'SUSTAINABILITY_ESG',
            categoryName: 'ESG & Sustainability',
            subName: 'Site Audit',
          ),
          threadCard(
            'b',
            categoryKey: 'TECHNOLOGY_INNOVATION',
            categoryName: 'Technology',
            subName: 'Real Estate Tech',
          ),
          threadCard('c', categoryKey: 'SUSTAINABILITY_ESG', categoryName: 'ESG & Sustainability', poll: pollJson()),
        ]),
      });
      final posts = (await repositoryOn(api).load(FeedFilter.all)).posts;
      expect(posts.map((p) => p.topic), ['Site Audit', 'Real Estate Tech', 'Poll']);
      expect(posts.map((p) => p.topicTone), [TopicTone.green, TopicTone.blue, TopicTone.blue]);
      expect(posts[0].views, 0);
    });

    test('a discussion\'s link and a reply\'s link are the website\'s own', () {
      final p = FeedPost(
        id: 'p',
        slug: 'my-slug',
        author: const FeedAuthor(id: 'a', name: 'A'),
        createdAt: DateTime(2026),
        title: 't',
        body: 'b',
      );
      expect(discussionLink(p).toString(), 'https://icr.org.in/community/my-slug');
      final r = FeedReply(
        id: 'r9',
        author: const FeedAuthor(id: 'a', name: 'A'),
        body: 'b',
        createdAt: DateTime(2026),
      );
      expect(discussionLink(p, r).toString(), 'https://icr.org.in/community/my-slug#reply-r9');
    });
  });
}

class _RefusingRepository extends DemoFeedRepository {
  @override
  Future<void> setReaction(FeedPost post, ReactionKind? kind) async => throw ApiError('No', statusCode: 400);
}

/// One post nobody has reacted to.
class _BareRepository extends DemoFeedRepository {
  @override
  Future<FeedPage> load(FeedFilter filter, {int page = 1, String? search, String? tag}) async => FeedPage(
    posts: [
      FeedPost(
        id: 'p',
        slug: 'p',
        author: const FeedAuthor(id: 'a', name: 'A B'),
        createdAt: DateTime(2026),
        title: 't',
        body: 'b',
      ),
    ],
    hasMore: false,
  );
}
