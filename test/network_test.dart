import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/auth/token_store.dart';
import 'package:icr_mobile/core/config.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/network/api_network_repository.dart';
import 'package:icr_mobile/features/network/demo_network_repository.dart';
import 'package:icr_mobile/features/network/network_controller.dart';
import 'package:icr_mobile/features/network/network_models.dart';
import 'package:icr_mobile/features/network/network_repository.dart';
import 'package:icr_mobile/features/network/network_screen.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import 'helpers/fonts.dart';

class _Tokens extends TokenStore {
  @override
  Future<String?> accessToken() async => 'token';
  @override
  Future<String?> refreshToken() async => null;
}

// ---------------------------------------------------------------------------
// A fake API that answers the way the portal's members module does
// ---------------------------------------------------------------------------

const _me = 'me-1';

/// A row of `/members/me/following` and `/members/:id/followers`: `company` is
/// `{ name }` or null, and `followedAt` is there.
Map<String, dynamic> _row(
  String id,
  String first,
  String last, {
  String? company,
  String? avatar,
  String followedAt = '2026-10-16T12:38:36.050Z',
}) => {
  'id': id,
  'firstName': first,
  'lastName': last,
  'avatarUrl': avatar,
  'company': company == null ? null : {'name': company},
  'followedAt': followedAt,
};

/// A row of `/members/me/suggestions`: `company` is a name or null, with
/// `followers` and `reason`, and no `followedAt`.
Map<String, dynamic> _suggestion(
  String id,
  String first,
  String last, {
  String? company,
  int followers = 1,
  String reason = 'Active in the community',
}) => {
  'id': id,
  'firstName': first,
  'lastName': last,
  'avatarUrl': null,
  'company': company,
  'followers': followers,
  'reason': reason,
};

/// A row of `/members/me/feed`: its author's `company` is a name or null.
Map<String, dynamic> _post(
  String kind,
  String id,
  String title, {
  String author = 'elena',
  String first = 'Elena',
  String last = 'Rostova',
  String? company,
  String excerpt = 'Just wrapped up an incredible site visit.',
  Duration ago = const Duration(hours: 2),
}) => {
  'kind': kind,
  'id': id,
  'title': title,
  'excerpt': excerpt,
  'link': kind == 'ARTICLE' ? '/blogs/$id' : '/community/$id',
  'at': DateTime.now().toUtc().subtract(ago).toIso8601String(),
  'author': {'id': author, 'firstName': first, 'lastName': last, 'avatarUrl': null, 'company': company},
};

Map<String, dynamic> _meta(int total, int page, int limit) {
  final pages = total == 0 ? 1 : (total / limit).ceil();
  return {
    'page': page,
    'limit': limit,
    'total': total,
    'totalPages': pages,
    'hasNext': page < pages,
    'hasPrev': page > 1,
  };
}

/// `paginate()`'s envelope over [rows].
Map<String, dynamic> _paged(List<Map<String, dynamic>> rows, Map<String, dynamic> query) {
  final page = int.parse('${query['page'] ?? 1}');
  final limit = int.parse('${query['limit'] ?? 20}');
  final from = (page - 1) * limit;
  final slice = rows.skip(from).take(limit).toList();
  return {'data': slice, 'meta': _meta(rows.length, page, limit)};
}

/// The members module, in memory: follows move people between the lists the
/// way the real service does.
class _Server {
  _Server({
    List<Map<String, dynamic>>? following,
    List<Map<String, dynamic>>? followers,
    List<Map<String, dynamic>>? feed,
    List<Map<String, dynamic>>? suggestions,
  }) : following = following ?? [],
       followers = followers ?? [],
       feed = feed ?? [],
       suggestions = suggestions ?? [];

  final List<Map<String, dynamic>> following;
  final List<Map<String, dynamic>> followers;
  final List<Map<String, dynamic>> feed;
  final List<Map<String, dynamic>> suggestions;
  int unread = 3;

  /// Route key (`POST /members/x/follow`) → a status and body to answer with.
  final refusals = <String, (int, String)>{};

  /// Route key → held until completed.
  final gates = <String, Completer<void>>{};

  final calls = <String>[];
  final queries = <Map<String, dynamic>>[];
  final bodies = <Map<String, dynamic>?>[];

  int count(String key) => calls.where((c) => c == key).length;

  /// The query of the [n]th call of [key] (0 = first).
  Map<String, dynamic> queryOf(String key, [int n = 0]) {
    var seen = -1;
    for (var i = 0; i < calls.length; i++) {
      if (calls[i] == key && ++seen == n) return queries[i];
    }
    throw StateError('no call $n of $key in $calls');
  }

  Future<Object> answer(RequestOptions o) async {
    final key = '${o.method} ${o.path}';
    calls.add(key);
    queries.add(o.queryParameters);
    bodies.add(o.data is Map ? (o.data as Map).cast<String, dynamic>() : null);
    final gate = gates[key];
    if (gate != null) await gate.future;
    final refusal = refusals[key];
    if (refusal != null) return refusal;

    if (key == 'GET /auth/me') return {'id': _me, 'firstName': 'Bharat', 'lastName': 'Buyer', 'role': 'BUYER'};
    if (key == 'GET /notifications/unread-count') return {'unread': unread};
    if (key == 'GET /members/me/feed') return _paged(feed, o.queryParameters);
    if (key == 'GET /members/me/following') return _paged(following, o.queryParameters);
    if (key == 'GET /members/me/suggestions') {
      return suggestions.take(int.parse('${o.queryParameters['limit'] ?? 6}')).toList();
    }
    if (key == 'GET /members/$_me/followers') return _paged(followers, o.queryParameters);

    final follow = RegExp(r'^/members/([^/]+)/follow$').firstMatch(o.path);
    if (follow != null) {
      final id = follow.group(1)!;
      if (o.method == 'POST') {
        final known = [...suggestions, ...followers].where((p) => p['id'] == id).firstOrNull;
        if (known != null && !following.any((p) => p['id'] == id)) {
          following.insert(
            0,
            _row(
              id,
              known['firstName'] as String,
              known['lastName'] as String,
              followedAt: DateTime.now().toUtc().toIso8601String(),
            ),
          );
        }
        suggestions.removeWhere((p) => p['id'] == id);
      } else {
        following.removeWhere((p) => p['id'] == id);
      }
      // The PERSON's counts, as FollowService.counts answers.
      return {'followers': 7, 'following': 3, 'viewerFollows': o.method == 'POST'};
    }
    return (404, '{"statusCode":404,"message":"Not found"}');
  }
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.server);

  final _Server server;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final result = await server.answer(options);
    if (result is (int, String)) return ResponseBody.fromString(result.$2, result.$1, headers: _json);
    return ResponseBody.fromString(jsonEncode(result), 200, headers: _json);
  }

  static final _json = {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  };

  @override
  void close({bool force = false}) {}
}

const _apiBase = 'http://api.test/api/v1';

ApiClient _client(_Server server) {
  final client = ApiClient(tokens: _Tokens(), baseUrl: _apiBase);
  client.dio.httpClientAdapter = _Adapter(server);
  return client;
}

(int, String) _refusal(int status, String message) => (status, jsonEncode({'statusCode': status, 'message': message}));

// A member who follows four people, has seven followers, three posts in the
// feed and two suggestions: what the screen tests start from unless they say.
_Server _usual() => _Server(
  following: [
    _row('lakshmi', 'Lakshmi', 'Prasad', company: 'Mumbai Facility 100'),
    _row('elena', 'Elena', 'Rostova', followedAt: '2026-07-18T12:38:36.050Z'),
    _row('marcus', 'Marcus', 'Reed', followedAt: '2026-03-21T12:38:36.050Z'),
    _row('rajesh', 'Rajesh', 'Menon', company: 'Mumbai Facility 100', followedAt: '2026-09-13T12:38:36.050Z'),
  ],
  followers: [
    _row('sarah', 'Sarah', 'Thomas', company: 'Hyderabad Services 104', followedAt: '2026-10-22T12:38:36.050Z'),
    _row('ishaan', 'Ishaan', 'Invitee', followedAt: '2026-10-21T12:38:36.050Z'),
    _row('marcus', 'Marcus', 'Reed', followedAt: '2026-10-20T12:38:36.050Z'),
    _row('uma', 'Uma', 'Verify', company: 'One Verify', followedAt: '2026-10-19T12:38:36.050Z'),
    _row('fiona', 'Fiona', 'Founder', followedAt: '2026-10-16T12:38:36.050Z'),
    _row('pranav', 'Pranav', 'Kulkarni', followedAt: '2026-10-12T12:38:36.050Z'),
    _row('rajesh2', 'Rajesh', 'Sharma', followedAt: '2026-10-11T12:38:36.050Z'),
  ],
  feed: [
    _post('THREAD', 'site-audit', 'Site Audit: Implementing Sustainable Net-Zero Solutions', company: null),
    _post(
      'ARTICLE',
      'gcc-campus',
      'What a GCC campus taught us about IFM contracts',
      author: 'rajesh',
      first: 'Rajesh',
      last: 'Menon',
      company: 'Mumbai Facility 100',
      ago: const Duration(hours: 9),
    ),
    _post(
      'THREAD',
      'fm-software',
      'What is your primary FM Software in 2026?',
      author: 'marcus',
      first: 'Marcus',
      last: 'Reed',
      excerpt: 'Select the ecosystem your team relies on for facility workflows.',
      ago: const Duration(days: 1),
    ),
  ],
  suggestions: [
    _suggestion('admin', 'Super', 'Admin', followers: 1),
    _suggestion(
      'nikhil',
      'Nikhil',
      'Rao',
      company: 'TechCorp',
      followers: 7,
      reason: 'Followed by 2 people you follow',
    ),
  ],
);

/// [count] rows named `<prefix>01`… for the paging tests.
List<Map<String, dynamic>> _rows(String prefix, int count) => [
  for (var i = 1; i <= count; i++) _row('$prefix$i', 'Follower', '${prefix.toUpperCase()}$i'),
];

List<Map<String, dynamic>> _posts(int count) => [
  for (var i = 1; i <= count; i++) _post('THREAD', 'post-$i', 'Post number $i', ago: Duration(hours: i)),
];

// ---------------------------------------------------------------------------
// A repository the controller tests drive by hand
// ---------------------------------------------------------------------------

class _FakeRepo implements NetworkRepository {
  _FakeRepo({
    List<NetworkPerson> following = const [],
    this.followingTotal,
    List<NetworkPerson> followers = const [],
    this.followersTotal,
  }) : followingRows = following,
       followersRows = followers;

  List<NetworkPerson> followingRows;
  int? followingTotal;
  List<NetworkPerson> followersRows;
  int? followersTotal;
  List<NetworkPost> feedRows = const [];
  bool feedHasNext = false;
  List<NetworkPerson> suggestionRows = const [];

  Future<FollowCounts> Function(String id)? onFollow;
  Future<FollowCounts> Function(String id)? onUnfollow;
  Future<ApiPage<NetworkPost>> Function(int page)? onFeed;
  Future<ApiPage<NetworkPerson>> Function(int page)? onFollowers;
  Object? loadError;
  Object? unreadError;
  final calls = <String>[];

  @override
  Future<String> viewerId() async => _me;

  @override
  Future<ApiPage<NetworkPost>> feed({int page = 1}) async {
    calls.add('feed:$page');
    if (loadError != null) throw loadError!;
    if (onFeed != null) return onFeed!(page);
    return ApiPage(items: feedRows, total: feedRows.length, page: page, hasNext: feedHasNext);
  }

  @override
  Future<List<NetworkPerson>> suggestions({int limit = 12}) async => suggestionRows;

  @override
  Future<ApiPage<NetworkPerson>> following() async =>
      ApiPage(items: followingRows, total: followingTotal ?? followingRows.length, page: 1, hasNext: false);

  @override
  Future<ApiPage<NetworkPerson>> followers(String userId, {int page = 1}) async {
    calls.add('followers:$page');
    if (onFollowers != null) return onFollowers!(page);
    return ApiPage(items: followersRows, total: followersTotal ?? followersRows.length, page: page, hasNext: false);
  }

  @override
  Future<FollowCounts> follow(String userId) async {
    calls.add('follow:$userId');
    return onFollow != null ? onFollow!(userId) : const FollowCounts(followers: 1, following: 0, viewerFollows: true);
  }

  @override
  Future<FollowCounts> unfollow(String userId) async {
    calls.add('unfollow:$userId');
    return onUnfollow != null
        ? onUnfollow!(userId)
        : const FollowCounts(followers: 0, following: 0, viewerFollows: false);
  }

  @override
  Future<int> unreadNotifications() async {
    if (unreadError != null) throw unreadError!;
    return 2;
  }
}

NetworkPerson _person(String id, [String first = 'Test', String last = 'Person']) =>
    NetworkPerson(id: id, firstName: first, lastName: last, company: 'Acme');

NetworkPost _netPost(String id, {PostKind kind = PostKind.thread}) => NetworkPost(
  kind: kind,
  id: id,
  title: 'Post $id',
  excerpt: 'About $id',
  link: '/community/$id',
  at: DateTime.utc(2026, 10, 20),
  author: _person('author-$id'),
);

// ---------------------------------------------------------------------------
// The screen
// ---------------------------------------------------------------------------

class _Screen {
  _Screen(this.server, this.controller);

  final _Server server;
  final NetworkController controller;
  final profiles = <String>[];
  final posts = <NetworkPost>[];
  final opened = <Uri>[];
  int writes = 0;
  int bells = 0;
  int backs = 0;

  Future<void> open(BuildContext context, Uri uri) async => opened.add(uri);
}

/// Mounts the Network screen on the fake API. [wired] false leaves every
/// callback out, so the screen falls back to the website (recorded in
/// `opened`). [size] is in logical pixels.
Future<_Screen> _pump(
  WidgetTester tester, {
  _Server? server,
  Size size = const Size(390, 3600),
  bool wired = true,
  bool settle = true,
  NetworkTab tab = NetworkTab.feed,
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final s = server ?? _usual();
  final controller = NetworkController(ApiNetworkRepository(api: _client(s)), initialTab: tab);
  final screen = _Screen(s, controller);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: ChangeNotifierProvider.value(
        value: controller,
        child: NetworkScreen(
          onBack: () => screen.backs++,
          onBell: wired ? () => screen.bells++ : null,
          onOpenProfile: wired ? screen.profiles.add : null,
          onOpenPost: wired ? screen.posts.add : null,
          onWriteArticle: wired ? () => screen.writes++ : null,
          opener: screen.open,
        ),
      ),
    ),
  );
  await tester.pump();
  if (settle) await tester.pumpAndSettle();
  return screen;
}

Finder _key(String key) => find.byKey(ValueKey(key));

/// The label drawn on a person's Follow button.
Finder _followLabel(String id, String label) => find.descendant(of: _key('follow-$id'), matching: find.text(label));

Finder _inTile(String key, String text) => find.descendant(of: _key(key), matching: find.text(text));

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// A pull-to-refresh from the top of the page: the indicator arms at a quarter
/// of the viewport's height, so the pull is 40% of it.
Future<void> _pull(WidgetTester tester) async {
  final height = tester.view.physicalSize.height / tester.view.devicePixelRatio;
  await tester.dragFrom(const Offset(195, 70), Offset(0, height * 0.4));
  await tester.pumpAndSettle();
}

Uri _site(String path) => AppConfig.sitePage(path);

void main() {
  setUpAll(loadAppFonts);

  // -------------------------------------------------------------------------
  group('the repository reads the API\'s real shapes', () {
    test('the feed: paged, an author\'s company is a name or null, the kind and link come as they are', () async {
      final server = _usual();
      final repo = ApiNetworkRepository(api: _client(server));

      final page = await repo.feed();

      expect(server.queryOf('GET /members/me/feed'), {'page': 1, 'limit': 20});
      expect(page.total, 3);
      expect(page.hasNext, isFalse);
      expect(page.items.map((p) => p.kind), [PostKind.thread, PostKind.article, PostKind.thread]);
      final article = page.items[1];
      expect(article.id, 'gcc-campus');
      expect(article.link, '/blogs/gcc-campus');
      expect(article.title, 'What a GCC campus taught us about IFM contracts');
      expect(article.author.id, 'rajesh');
      expect(article.author.name, 'Rajesh Menon');
      expect(article.author.company, 'Mumbai Facility 100');
      expect(page.items.first.author.company, isNull);
      expect(page.items.first.at.isAfter(DateTime.now().toUtc().subtract(const Duration(hours: 3))), isTrue);
    });

    test('a feed row without an author is left out; a blank excerpt stays blank', () async {
      final server = _Server(
        feed: [
          {..._post('THREAD', 'a', 'Has an author'), 'excerpt': '   '},
          {..._post('THREAD', 'b', 'No author')}..remove('author'),
        ],
      );
      final page = await ApiNetworkRepository(api: _client(server)).feed();

      expect(page.items.map((p) => p.id), ['a']);
      expect(page.items.single.excerpt, '');
    });

    test('the feed asks for the page it is given and reports whether there is another', () async {
      final server = _Server(feed: _posts(25));
      final repo = ApiNetworkRepository(api: _client(server));

      final first = await repo.feed();
      final second = await repo.feed(page: 2);

      expect(first.items, hasLength(20));
      expect(first.hasNext, isTrue);
      expect(first.total, 25);
      expect(second.items, hasLength(5));
      expect(second.hasNext, isFalse);
      expect(server.queryOf('GET /members/me/feed', 1), {'page': 2, 'limit': 20});
    });

    test('suggestions are a bare list: company is a name, with the reason and the follower count', () async {
      final server = _usual();
      final list = await ApiNetworkRepository(api: _client(server)).suggestions();

      expect(server.queryOf('GET /members/me/suggestions'), {'limit': 12});
      expect(list.map((p) => p.id), ['admin', 'nikhil']);
      expect(list.last.name, 'Nikhil Rao');
      expect(list.last.company, 'TechCorp');
      expect(list.last.reason, 'Followed by 2 people you follow');
      expect(list.last.followers, 7);
      expect(list.first.company, isNull);
      expect(list.first.since, isNull);
    });

    test('following: company is {name} or null, followedAt is the date of the follow, uploads become URLs', () async {
      final server = _Server(
        following: [
          _row(
            'lakshmi',
            'Lakshmi',
            'Prasad',
            company: 'Mumbai Facility 100',
            avatar: '/uploads/seed-avatar-female-17.jpg',
          ),
          _row('elena', 'Elena', 'Rostova', followedAt: '2026-07-18T12:38:36.050Z'),
        ],
      );
      final page = await ApiNetworkRepository(api: _client(server)).following();

      expect(page.total, 2);
      final lakshmi = page.items.first;
      expect(lakshmi.company, 'Mumbai Facility 100');
      expect(lakshmi.since, DateTime.utc(2026, 10, 16, 12, 38, 36, 50));
      expect(lakshmi.photo?.url, 'http://api.test/uploads/seed-avatar-female-17.jpg');
      expect(lakshmi.reason, isNull);
      expect(lakshmi.followers, isNull);
      expect(page.items.last.company, isNull);
      expect(page.items.last.photo, isNull);
    });

    test('following is read to the end, 100 a page, and its total is the API\'s meta.total', () async {
      final server = _Server(following: _rows('p', 230));
      final page = await ApiNetworkRepository(api: _client(server)).following();

      expect(server.count('GET /members/me/following'), 3);
      expect(server.queryOf('GET /members/me/following', 2), {'page': 3, 'limit': 100});
      expect(page.items, hasLength(230));
      expect(page.total, 230);
      expect(page.hasNext, isFalse);
    });

    test('followers are read by the member\'s id, 30 a page, and total counts all of them', () async {
      final server = _Server(followers: _rows('f', 35));
      final repo = ApiNetworkRepository(api: _client(server));

      final first = await repo.followers(_me);
      final second = await repo.followers(_me, page: 2);

      expect(server.queryOf('GET /members/$_me/followers'), {'page': 1, 'limit': 30});
      expect(first.items, hasLength(30));
      expect(first.total, 35);
      expect(first.hasNext, isTrue);
      expect(second.items, hasLength(5));
      expect(second.hasNext, isFalse);
      expect(second.items.first.since, isNotNull);
    });

    test('follow and unfollow answer the PERSON\'s counts and whether the member follows them', () async {
      final server = _usual();
      final repo = ApiNetworkRepository(api: _client(server));

      final followed = await repo.follow('nikhil');
      final unfollowed = await repo.unfollow('nikhil');

      expect(server.calls, containsAllInOrder(['POST /members/nikhil/follow', 'DELETE /members/nikhil/follow']));
      expect(followed.viewerFollows, isTrue);
      expect(followed.followers, 7);
      expect(followed.following, 3);
      expect(unfollowed.viewerFollows, isFalse);
    });

    test('the viewer is read from /auth/me and the bell from the unread count', () async {
      final repo = ApiNetworkRepository(api: _client(_usual()));
      expect(await repo.viewerId(), _me);
      expect(await repo.unreadNotifications(), 3);
    });

    test('a refusal arrives as an ApiError carrying the API\'s sentence', () async {
      final server = _usual()..refusals['POST /members/nikhil/follow'] = _refusal(404, 'Member not found');
      final repo = ApiNetworkRepository(api: _client(server));

      await expectLater(
        repo.follow('nikhil'),
        throwsA(isA<ApiError>().having((e) => e.message, 'message', 'Member not found')),
      );
    });
  });

  // -------------------------------------------------------------------------
  group('the controller', () {
    test('start reads the four lists and the bell; the counts are the API\'s totals, not the rows read', () async {
      final repo = _FakeRepo(
        following: [_person('a'), _person('b')],
        followingTotal: 40,
        followers: [_person('c')],
        followersTotal: 255,
      )..suggestionRows = [_person('s')];
      final c = NetworkController(repo);

      await c.start();

      expect(c.loaded, isTrue);
      expect(c.error, isNull);
      expect(c.followingCount, 40);
      expect(c.followersCount, 255);
      expect(c.following, hasLength(2));
      expect(c.unread, 2);
      expect(c.followsNobody, isFalse);
      expect(c.follows(_person('a')), isTrue);
      expect(c.follows(_person('s')), isFalse);
    });

    test('a failing unread count does not fail the load', () async {
      final repo = _FakeRepo()..unreadError = ApiError('nope');
      final c = NetworkController(repo);
      await c.start();
      expect(c.loaded, isTrue);
      expect(c.unread, 0);
    });

    test('a first load that fails keeps the API\'s sentence for the Retry notice, and Retry works', () async {
      final repo = _FakeRepo()..loadError = ApiError('Service unavailable', statusCode: 503);
      final c = NetworkController(repo);

      await c.start();
      expect(c.loaded, isFalse);
      expect(c.error, 'Service unavailable');

      repo.loadError = null;
      expect(await c.refresh(), isNull);
      expect(c.loaded, isTrue);
      expect(c.error, isNull);
    });

    test('a 401 reads as a request to sign in', () async {
      final repo = _FakeRepo()..loadError = ApiError('Unauthorized', statusCode: 401);
      final c = NetworkController(repo);
      await c.start();
      expect(c.error, 'Sign in to see your network.');
    });

    test('a refresh that fails after a good load returns the sentence and leaves the lists standing', () async {
      final repo = _FakeRepo(following: [_person('a')], followers: [_person('c')]);
      final c = NetworkController(repo);
      await c.start();

      repo.loadError = ApiError("Can't reach ICR right now.");
      final message = await c.refresh();

      expect(message, "Can't reach ICR right now.");
      expect(c.loaded, isTrue);
      expect(c.error, isNull);
      expect(c.following, hasLength(1));
      expect(c.followersCount, 1);
    });

    test(
      'follow takes effect at once: followed, counted, listed first and busy, then kept when the API agrees',
      () async {
        final repo = _FakeRepo(following: [_person('a')], followers: []);
        final c = NetworkController(repo);
        await c.start();
        final gate = Completer<FollowCounts>();
        repo.onFollow = (_) => gate.future;
        final nikhil = NetworkPerson(
          id: 'nikhil',
          firstName: 'Nikhil',
          lastName: 'Rao',
          company: 'TechCorp',
          reason: 'Followed by 2 people you follow',
          followers: 7,
        );

        final pending = c.follow(nikhil);

        expect(c.follows(nikhil), isTrue);
        expect(c.isBusy(nikhil), isTrue);
        expect(c.followingCount, 2);
        expect(c.following.first.id, 'nikhil');
        expect(c.following.first.reason, isNull, reason: 'the suggestion\'s reason does not follow them into the list');
        expect(c.following.first.since, isNotNull);

        gate.complete(const FollowCounts(followers: 8, following: 3, viewerFollows: true));
        expect(await pending, isNull);
        await Future<void>.delayed(Duration.zero);

        expect(c.isBusy(nikhil), isFalse);
        expect(c.followingCount, 2, reason: 'the answer\'s counts are Nikhil\'s, not the member\'s');
        expect(repo.calls.where((x) => x == 'feed:1'), hasLength(2), reason: 'the feed is read again');
      },
    );

    test('a follow the API refuses is taken back, and its sentence is returned', () async {
      final repo = _FakeRepo(following: [_person('a')]);
      final c = NetworkController(repo);
      await c.start();
      repo.onFollow = (_) async => throw ApiError('You cannot follow yourself.', statusCode: 400);
      final target = _person('me-1');
      var notified = 0;
      c.addListener(() => notified++);

      final message = await c.follow(target);

      expect(message, 'You cannot follow yourself.');
      expect(c.follows(target), isFalse);
      expect(c.followingCount, 1);
      expect(c.following.map((p) => p.id), ['a']);
      expect(c.isBusy(target), isFalse);
      expect(notified, greaterThanOrEqualTo(2), reason: 'told once when it went in and once when it came out');
    });

    test('unfollow takes effect at once and the row stays listed so it can be undone', () async {
      final repo = _FakeRepo(following: [_person('a'), _person('b')]);
      final c = NetworkController(repo);
      await c.start();
      final gate = Completer<FollowCounts>();
      repo.onUnfollow = (_) => gate.future;

      final pending = c.unfollow(_person('a'));

      expect(c.follows(_person('a')), isFalse);
      expect(c.followingCount, 1);
      expect(c.isBusy(_person('a')), isTrue);
      expect(c.following.map((p) => p.id), ['a', 'b']);

      gate.complete(const FollowCounts(followers: 0, following: 0, viewerFollows: false));
      expect(await pending, isNull);
      expect(c.followingCount, 1);

      // Following them again puts the count back without a second row.
      expect(await c.follow(_person('a')), isNull);
      expect(c.followingCount, 2);
      expect(c.following.where((p) => p.id == 'a'), hasLength(1));
    });

    test('an unfollow the API refuses is put back', () async {
      final repo = _FakeRepo(following: [_person('a')]);
      final c = NetworkController(repo);
      await c.start();
      repo.onUnfollow = (_) async => throw ApiError('Something went wrong (500). Try again.', statusCode: 500);

      final message = await c.unfollow(_person('a'));

      expect(message, 'Something went wrong (500). Try again.');
      expect(c.follows(_person('a')), isTrue);
      expect(c.followingCount, 1);
    });

    test('a second tap while one is on its way does nothing', () async {
      final repo = _FakeRepo();
      final c = NetworkController(repo);
      await c.start();
      final gate = Completer<FollowCounts>();
      repo.onFollow = (_) => gate.future;

      final first = c.follow(_person('x'));
      final second = await c.follow(_person('x'));
      gate.complete(const FollowCounts(followers: 1, following: 0, viewerFollows: true));
      await first;

      expect(second, isNull);
      expect(repo.calls.where((x) => x == 'follow:x'), hasLength(1));
      expect(c.followingCount, 1);
    });

    test('unfollowing someone not followed, or following someone already followed, calls nothing', () async {
      final repo = _FakeRepo(following: [_person('a')]);
      final c = NetworkController(repo);
      await c.start();

      expect(await c.unfollow(_person('zzz')), isNull);
      expect(await c.follow(_person('a')), isNull);
      expect(repo.calls.where((x) => x.startsWith('follow:') || x.startsWith('unfollow:')), isEmpty);
    });

    test('following nobody is told by the API\'s total, and following the first person ends it', () async {
      final repo = _FakeRepo();
      final c = NetworkController(repo);
      await c.start();
      expect(c.followsNobody, isTrue);

      await c.follow(_person('x'));
      expect(c.followsNobody, isFalse);

      await c.unfollow(_person('x'));
      expect(c.followsNobody, isTrue);
    });

    test('Show more on the feed appends the next page without repeating a post', () async {
      final repo = _FakeRepo(following: [_person('a')])
        ..feedRows = [_netPost('1'), _netPost('2')]
        ..feedHasNext = true;
      repo.onFeed = (page) async => page == 1
          ? ApiPage(items: [_netPost('1'), _netPost('2')], total: 4, page: 1, hasNext: true)
          : ApiPage(items: [_netPost('2'), _netPost('3'), _netPost('4')], total: 4, page: 2, hasNext: false);
      final c = NetworkController(repo);
      await c.start();
      expect(c.feedHasNext, isTrue);

      expect(await c.loadMore(), isNull);

      expect(c.feed.map((p) => p.id), ['1', '2', '3', '4']);
      expect(c.feedHasNext, isFalse);
      expect(await c.loadMore(), isNull, reason: 'nothing more to read');
      expect(repo.calls.where((x) => x == 'feed:2'), hasLength(1));
    });

    test('Show more on the followers appends the next page and keeps the API\'s total', () async {
      final repo = _FakeRepo(following: [_person('a')]);
      repo.onFollowers = (page) async => page == 1
          ? ApiPage(items: [_person('f1'), _person('f2')], total: 3, page: 1, hasNext: true)
          : ApiPage(items: [_person('f3')], total: 3, page: 2, hasNext: false);
      final c = NetworkController(repo, initialTab: NetworkTab.followers);
      await c.start();
      expect(c.followersHasNext, isTrue);
      expect(c.followersCount, 3);

      await c.loadMore();

      expect(c.followers.map((p) => p.id), ['f1', 'f2', 'f3']);
      expect(c.followersHasNext, isFalse);
      expect(c.followersCount, 3);
    });

    test('Show more does nothing on the lists that are read whole', () async {
      final repo = _FakeRepo(following: [_person('a')])..feedHasNext = true;
      final c = NetworkController(repo, initialTab: NetworkTab.following);
      await c.start();
      final before = List<String>.of(repo.calls);

      expect(await c.loadMore(), isNull);
      expect(repo.calls, before);
    });

    test('a Show more that fails returns the sentence and keeps what was read', () async {
      final repo = _FakeRepo(following: [_person('a')]);
      repo.onFeed = (page) async => page == 1
          ? ApiPage(items: [_netPost('1')], total: 2, page: 1, hasNext: true)
          : throw ApiError("Can't reach ICR right now.");
      final c = NetworkController(repo);
      await c.start();

      expect(await c.loadMore(), "Can't reach ICR right now.");
      expect(c.feed.map((p) => p.id), ['1']);
      expect(c.feedHasNext, isTrue, reason: 'it can be tried again');
      expect(c.loadingMore, isFalse);
    });

    test('setTab switches the list and tells listeners once', () async {
      final c = NetworkController(_FakeRepo());
      await c.start();
      var notified = 0;
      c.addListener(() => notified++);

      c.setTab(NetworkTab.followers);
      c.setTab(NetworkTab.followers);

      expect(c.tab, NetworkTab.followers);
      expect(notified, 1);
    });

    test('a controller disposed while a follow is on its way does not throw', () async {
      final repo = _FakeRepo();
      final c = NetworkController(repo);
      await c.start();
      final gate = Completer<FollowCounts>();
      repo.onFollow = (_) => gate.future;

      final pending = c.follow(_person('x'));
      c.dispose();
      gate.complete(const FollowCounts(followers: 1, following: 0, viewerFollows: true));

      expect(await pending, isNull);
    });
  });

  // -------------------------------------------------------------------------
  group('the screen: states', () {
    testWidgets('it shows a spinner while it reads, then the network', (tester) async {
      final server = _usual();
      server.gates['GET /members/me/feed'] = Completer<void>();
      await _pump(tester, server: server, settle: false);
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Your network'), findsNothing);

      server.gates['GET /members/me/feed']!.complete();
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Your network'), findsOneWidget);
      expect(find.text('Articles and discussions from the people you follow.'), findsOneWidget);
    });

    testWidgets('an API failure shows its sentence with Retry, and Retry reads again', (tester) async {
      final server = _usual()..refusals['GET /members/me/feed'] = _refusal(503, 'Service unavailable');
      await _pump(tester, server: server);

      expect(find.text("Couldn't load your network"), findsOneWidget);
      expect(find.text('Service unavailable'), findsOneWidget);
      expect(find.text('Your network'), findsNothing);

      server.refusals.clear();
      await _tap(tester, find.text('Retry'));

      expect(find.text("Couldn't load your network"), findsNothing);
      expect(find.text('Your network'), findsOneWidget);
      expect(find.text('Site Audit: Implementing Sustainable Net-Zero Solutions'), findsOneWidget);
    });

    testWidgets('a member who follows nobody is asked to follow someone, with people worth following', (tester) async {
      final server = _usual()
        ..following.clear()
        ..feed.clear();
      await _pump(tester, server: server);

      expect(find.text('Follow someone to start your feed'), findsOneWidget);
      expect(find.text('Nothing new yet'), findsNothing);
      expect(find.text('People worth following'), findsOneWidget);
      expect(_key('person-nikhil'), findsOneWidget);
      expect(_key('person-admin'), findsOneWidget);
      expect(_inTile('stat-following', '0'), findsOneWidget);
    });

    testWidgets('following the first person from there starts the feed', (tester) async {
      final server = _usual()
        ..following.clear()
        ..feed.clear();
      await _pump(tester, server: server);

      await _tap(tester, _key('follow-nikhil'));

      expect(server.calls, contains('POST /members/nikhil/follow'));
      expect(find.text('Follow someone to start your feed'), findsNothing);
      expect(_inTile('stat-following', '1'), findsOneWidget);
    });

    testWidgets('a member who follows people but has a quiet feed is told so, and keeps the suggestions', (
      tester,
    ) async {
      final server = _usual()..feed.clear();
      await _pump(tester, server: server);

      expect(find.text('Nothing new yet'), findsOneWidget);
      expect(find.text('The people you follow have not published anything recently.'), findsOneWidget);
      expect(find.text('Follow someone to start your feed'), findsNothing);
      expect(find.text('Who to follow'), findsOneWidget);
      expect(_key('person-nikhil'), findsOneWidget);
    });

    testWidgets('with no suggestions the Who to follow card is not drawn', (tester) async {
      final server = _usual()..suggestions.clear();
      await _pump(tester, server: server);

      expect(find.text('Who to follow'), findsNothing);
      expect(find.text('Site Audit: Implementing Sustainable Net-Zero Solutions'), findsOneWidget);
    });

    testWidgets('each empty list says what it is for', (tester) async {
      final server = _Server();
      await _pump(tester, server: server);

      await _tap(tester, _key('tab-suggestions'));
      expect(find.text('No suggestions right now'), findsOneWidget);

      await _tap(tester, _key('tab-following'));
      expect(find.text("You don't follow anyone yet"), findsOneWidget);

      await _tap(tester, _key('tab-followers'));
      expect(find.text('No followers yet'), findsOneWidget);
    });

    testWidgets('"Find people" on an empty Following list opens the suggestions', (tester) async {
      await _pump(tester, server: _usual()..following.clear());
      await _tap(tester, _key('tab-following'));

      await _tap(tester, find.text('Find people'));

      expect(_key('person-nikhil'), findsOneWidget);
      expect(find.text("You don't follow anyone yet"), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  group('the screen: the feed', () {
    testWidgets('each post shows its author, company, age, kind, title and opening', (tester) async {
      await _pump(tester);

      final article = _key('post-article:gcc-campus');
      expect(find.descendant(of: article, matching: find.text('Rajesh Menon')), findsOneWidget);
      expect(find.descendant(of: article, matching: find.text('Mumbai Facility 100 · 9h ago')), findsOneWidget);
      expect(find.descendant(of: article, matching: find.text('Article')), findsOneWidget);
      expect(
        find.descendant(of: article, matching: find.text('What a GCC campus taught us about IFM contracts')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: article, matching: find.text('Just wrapped up an incredible site visit.')),
        findsOneWidget,
      );

      final thread = _key('post-thread:site-audit');
      expect(find.descendant(of: thread, matching: find.text('Discussion')), findsOneWidget);
      expect(
        find.descendant(of: thread, matching: find.text('2h ago')),
        findsOneWidget,
        reason: 'no company, only the age',
      );
    });

    testWidgets('tapping a post hands it to onOpenPost', (tester) async {
      final screen = await _pump(tester);

      await _tap(tester, _key('post-article:gcc-campus'));

      expect(screen.posts.map((p) => (p.id, p.kind, p.link)), [('gcc-campus', PostKind.article, '/blogs/gcc-campus')]);
      expect(screen.opened, isEmpty);
    });

    testWidgets('without onOpenPost a post opens its page on the website', (tester) async {
      final screen = await _pump(tester, wired: false);

      await _tap(tester, _key('post-article:gcc-campus'));
      await _tap(tester, _key('post-thread:site-audit'));

      expect(screen.opened, [_site('/blogs/gcc-campus'), _site('/community/site-audit')]);
    });

    testWidgets('tapping an author\'s name or photo opens their profile; the post stays closed', (tester) async {
      final screen = await _pump(tester);

      await _tap(tester, _key('author-name-article:gcc-campus'));
      await _tap(tester, _key('author-photo-thread:fm-software'));

      expect(screen.profiles, ['rajesh', 'marcus']);
      expect(screen.posts, isEmpty);
    });

    testWidgets('without onOpenProfile a person opens /members/<id> on the website', (tester) async {
      final screen = await _pump(tester, wired: false);

      await _tap(tester, _key('author-name-article:gcc-campus'));
      await _tap(tester, _key('person-nikhil'));

      expect(screen.opened, [_site('/members/rajesh'), _site('/members/nikhil')]);
    });

    testWidgets('Show more reads the next page, appends it, and goes away on the last', (tester) async {
      final server = _usual()
        ..feed.clear()
        ..feed.addAll(_posts(25));
      await _pump(tester, server: server);

      expect(_key('post-thread:post-20'), findsOneWidget);
      expect(_key('post-thread:post-21'), findsNothing);
      expect(_key('show-more'), findsOneWidget);

      await _tap(tester, _key('show-more'));

      expect(server.queryOf('GET /members/me/feed', 1), {'page': 2, 'limit': 20});
      expect(_key('post-thread:post-25'), findsOneWidget);
      expect(_key('post-thread:post-1'), findsOneWidget, reason: 'the first page is still there');
      expect(_key('show-more'), findsNothing);
    });

    testWidgets('a Show more that fails says why and can be tried again', (tester) async {
      final server = _usual()
        ..feed.clear()
        ..feed.addAll(_posts(25));
      await _pump(tester, server: server);

      server.refusals['GET /members/me/feed'] = _refusal(500, 'The feed is resting');
      await _tap(tester, _key('show-more'));

      expect(find.text('The feed is resting'), findsOneWidget);
      expect(_key('post-thread:post-20'), findsOneWidget);
      expect(_key('show-more'), findsOneWidget);

      server.refusals.clear();
      await tester.pump(const Duration(seconds: 5));
      await _tap(tester, _key('show-more'));
      expect(_key('post-thread:post-25'), findsOneWidget);
    });

    testWidgets('a short feed has no Show more', (tester) async {
      await _pump(tester);
      expect(_key('show-more'), findsNothing);
    });

    testWidgets('See all under Who to follow opens the suggestions list', (tester) async {
      await _pump(tester);

      await _tap(tester, find.text('See all'));

      expect(find.text('See all'), findsNothing);
      expect(find.text('Site Audit: Implementing Sustainable Net-Zero Solutions'), findsNothing);
      expect(_key('person-nikhil'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  group('the screen: people', () {
    testWidgets('the stat tiles show the API\'s totals and open their lists', (tester) async {
      final server = _usual()..followers.addAll(_rows('f', 40));
      await _pump(tester, server: server);

      expect(_inTile('stat-following', '4'), findsOneWidget);
      expect(_inTile('stat-followers', '47'), findsOneWidget);
      expect(find.text('Following (4)'), findsOneWidget);
      expect(find.text('Followers (47)'), findsOneWidget);

      await _tap(tester, _key('stat-following'));
      expect(_key('person-lakshmi'), findsOneWidget);
      expect(_key('person-sarah'), findsNothing);

      await _tap(tester, _key('stat-followers'));
      expect(_key('person-sarah'), findsOneWidget);
      expect(_key('person-lakshmi'), findsNothing);
    });

    testWidgets('the four chips switch the list, and the one showing is the primary chip', (tester) async {
      await _pump(tester);

      await _tap(tester, _key('tab-suggestions'));
      expect(_key('person-nikhil'), findsOneWidget);
      expect(find.text('Site Audit: Implementing Sustainable Net-Zero Solutions'), findsNothing);

      await _tap(tester, _key('tab-following'));
      expect(_key('person-elena'), findsOneWidget);
      expect(_key('person-nikhil'), findsNothing);

      await _tap(tester, _key('tab-followers'));
      expect(_key('person-uma'), findsOneWidget);

      await _tap(tester, _key('tab-feed'));
      expect(find.text('Site Audit: Implementing Sustainable Net-Zero Solutions'), findsOneWidget);
    });

    testWidgets('a suggestion shows its company, follower count and the API\'s reason', (tester) async {
      await _pump(tester, tab: NetworkTab.suggestions);

      final row = _key('person-nikhil');
      expect(find.descendant(of: row, matching: find.text('Nikhil Rao')), findsOneWidget);
      expect(find.descendant(of: row, matching: find.text('TechCorp · 7 followers')), findsOneWidget);
      expect(find.descendant(of: row, matching: find.text('Followed by 2 people you follow')), findsOneWidget);
      expect(
        find.descendant(of: _key('person-admin'), matching: find.text('1 follower')),
        findsOneWidget,
        reason: 'no company, singular',
      );
    });

    testWidgets('a following row shows the company and since when the member has followed them', (tester) async {
      await _pump(tester, tab: NetworkTab.following);

      final row = _key('person-lakshmi');
      expect(find.descendant(of: row, matching: find.text('Mumbai Facility 100')), findsOneWidget);
      expect(find.descendant(of: row, matching: find.text('Following since 16 Oct 2026')), findsOneWidget);
      expect(_followLabel('lakshmi', 'Following'), findsOneWidget);
    });

    testWidgets('a follower row says since when they follow, and offers Follow back unless already followed', (
      tester,
    ) async {
      await _pump(tester, tab: NetworkTab.followers);

      expect(
        find.descendant(of: _key('person-sarah'), matching: find.text('Follows you since 22 Oct 2026')),
        findsOneWidget,
      );
      expect(_followLabel('sarah', 'Follow back'), findsOneWidget);
      expect(_followLabel('marcus', 'Following'), findsOneWidget, reason: 'Marcus is in both lists');
    });

    testWidgets('Show more on the followers reads the next page of 30', (tester) async {
      final server = _usual()
        ..followers.clear()
        ..followers.addAll(_rows('f', 35));
      await _pump(tester, server: server, tab: NetworkTab.followers, size: const Size(390, 6000));

      expect(_key('person-f30'), findsOneWidget);
      expect(_key('person-f31'), findsNothing);

      await _tap(tester, _key('show-more'));

      expect(server.queryOf('GET /members/$_me/followers', 1), {'page': 2, 'limit': 30});
      expect(_key('person-f35'), findsOneWidget);
      expect(_key('show-more'), findsNothing);
      expect(_inTile('stat-followers', '35'), findsOneWidget);
    });

    testWidgets('tapping a person opens their profile', (tester) async {
      final screen = await _pump(tester, tab: NetworkTab.following);

      await _tap(tester, _key('person-elena'));

      expect(screen.profiles, ['elena']);
    });
  });

  // -------------------------------------------------------------------------
  group('the screen: Follow and Following', () {
    testWidgets('Follow flips to Following at once, calls the API and moves the count', (tester) async {
      final server = _usual();
      server.gates['POST /members/nikhil/follow'] = Completer<void>();
      await _pump(tester, tab: NetworkTab.suggestions, server: server);
      expect(_followLabel('nikhil', 'Follow'), findsOneWidget);
      expect(_inTile('stat-following', '4'), findsOneWidget);

      await tester.tap(_key('follow-nikhil'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(_followLabel('nikhil', 'Following'), findsOneWidget, reason: 'before the API has answered');
      expect(_inTile('stat-following', '5'), findsOneWidget);
      expect(
        find.descendant(of: _key('follow-nikhil'), matching: find.byType(CircularProgressIndicator)),
        findsOneWidget,
      );

      server.gates['POST /members/nikhil/follow']!.complete();
      await tester.pumpAndSettle();

      expect(server.calls, contains('POST /members/nikhil/follow'));
      expect(_followLabel('nikhil', 'Following'), findsOneWidget);
      expect(_inTile('stat-following', '5'), findsOneWidget);
      expect(server.count('GET /members/me/feed'), 2, reason: 'the feed is read again after a follow');
    });

    testWidgets('a follow the API refuses goes back to Follow and shows the API\'s sentence', (tester) async {
      final server = _usual()..refusals['POST /members/nikhil/follow'] = _refusal(404, 'Member not found');
      await _pump(tester, tab: NetworkTab.suggestions, server: server);

      await _tap(tester, _key('follow-nikhil'));

      expect(find.text('Member not found'), findsOneWidget);
      expect(_followLabel('nikhil', 'Follow'), findsOneWidget);
      expect(_inTile('stat-following', '4'), findsOneWidget);
    });

    testWidgets('Follow back from the followers follows them and keeps them in the list', (tester) async {
      final server = _usual();
      await _pump(tester, tab: NetworkTab.followers, server: server);

      await _tap(tester, _key('follow-sarah'));

      expect(server.calls, contains('POST /members/sarah/follow'));
      expect(_followLabel('sarah', 'Following'), findsOneWidget);
      expect(_key('person-sarah'), findsOneWidget);
      expect(_inTile('stat-following', '5'), findsOneWidget);
      expect(
        _inTile('stat-followers', '7'),
        findsOneWidget,
        reason: 'following someone does not change who follows you',
      );
    });

    testWidgets('Following asks first; Cancel leaves the follow as it was', (tester) async {
      final server = _usual();
      await _pump(tester, tab: NetworkTab.following, server: server);

      await _tap(tester, _key('follow-elena'));
      expect(find.text('Unfollow Elena Rostova?'), findsOneWidget);
      expect(find.text("Their articles and discussions leave your feed. They aren't told."), findsOneWidget);

      await _tap(tester, _key('unfollow-cancel'));

      expect(find.text('Unfollow Elena Rostova?'), findsNothing);
      expect(server.calls.where((c) => c.startsWith('DELETE')), isEmpty);
      expect(_followLabel('elena', 'Following'), findsOneWidget);
      expect(_inTile('stat-following', '4'), findsOneWidget);
    });

    testWidgets('dismissing the question also leaves the follow as it was', (tester) async {
      final server = _usual();
      await _pump(tester, tab: NetworkTab.following, server: server);

      await _tap(tester, _key('follow-elena'));
      await tester.tapAt(const Offset(195, 40));
      await tester.pumpAndSettle();

      expect(find.text('Unfollow Elena Rostova?'), findsNothing);
      expect(server.calls.where((c) => c.startsWith('DELETE')), isEmpty);
    });

    testWidgets('confirming Unfollow calls the API, lowers the count, and the row stays to follow again', (
      tester,
    ) async {
      final server = _usual();
      await _pump(tester, tab: NetworkTab.following, server: server);

      await _tap(tester, _key('follow-elena'));
      await _tap(tester, _key('unfollow-confirm'));

      expect(server.calls, contains('DELETE /members/elena/follow'));
      expect(_followLabel('elena', 'Follow'), findsOneWidget);
      expect(_key('person-elena'), findsOneWidget);
      expect(_inTile('stat-following', '3'), findsOneWidget);

      await _tap(tester, _key('follow-elena'));
      expect(server.calls, contains('POST /members/elena/follow'));
      expect(_followLabel('elena', 'Following'), findsOneWidget);
      expect(_inTile('stat-following', '4'), findsOneWidget);
    });

    testWidgets('an Unfollow the API refuses puts the follow back and shows the sentence', (tester) async {
      final server = _usual()..refusals['DELETE /members/elena/follow'] = _refusal(500, 'Try later');
      await _pump(tester, tab: NetworkTab.following, server: server);

      await _tap(tester, _key('follow-elena'));
      await _tap(tester, _key('unfollow-confirm'));

      expect(find.text('Try later'), findsOneWidget);
      expect(_followLabel('elena', 'Following'), findsOneWidget);
      expect(_inTile('stat-following', '4'), findsOneWidget);
    });

    testWidgets('a person followed from the feed\'s Who to follow shows in the Following list', (tester) async {
      await _pump(tester);

      await _tap(tester, _key('follow-nikhil'));
      await _tap(tester, _key('tab-following'));

      expect(find.descendant(of: _key('person-nikhil'), matching: find.text('Nikhil Rao')), findsOneWidget);
      expect(_followLabel('nikhil', 'Following'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  group('the screen: refresh, bell, back and the website', () {
    testWidgets('pulling down on any list reads everything again', (tester) async {
      final server = _usual();
      await _pump(tester, server: server);

      var feeds = server.count('GET /members/me/feed');
      for (final tab in NetworkTab.values) {
        await _tap(tester, _key('tab-${tab.name}'));
        await _pull(tester);
        feeds++;
        expect(server.count('GET /members/me/feed'), feeds, reason: '${tab.name} refreshed');
      }
      expect(server.count('GET /members/me/following'), 5);
      expect(server.count('GET /members/$_me/followers'), 5);
      expect(server.count('GET /members/me/suggestions'), 5);
      expect(server.count('GET /notifications/unread-count'), 5);
    });

    testWidgets('pulling on an empty list works too, and picks up what arrived', (tester) async {
      final server = _Server();
      await _pump(tester, server: server);
      expect(find.text('Follow someone to start your feed'), findsOneWidget);

      server.following.add(_row('elena', 'Elena', 'Rostova'));
      server.feed.add(_post('THREAD', 'late', 'Fresh from Elena'));
      await _pull(tester);

      expect(find.text('Fresh from Elena'), findsOneWidget);
      expect(find.text('Follow someone to start your feed'), findsNothing);
    });

    testWidgets('a pull that fails says why and leaves the lists on screen', (tester) async {
      final server = _usual();
      await _pump(tester, server: server);

      server.refusals['GET /members/me/feed'] = _refusal(500, 'Service unavailable');
      await _pull(tester);

      expect(find.text('Service unavailable'), findsOneWidget);
      expect(find.text('Site Audit: Implementing Sustainable Net-Zero Solutions'), findsOneWidget);
      expect(find.text("Couldn't load your network"), findsNothing);
    });

    testWidgets('the bell shows the unread count and opens notifications', (tester) async {
      final semantics = tester.ensureSemantics();
      final screen = await _pump(tester);

      expect(find.bySemanticsLabel('Notifications, 3 unread'), findsOneWidget);
      await tester.tap(find.byIcon(LucideIcons.bell));
      expect(screen.bells, 1);
      expect(screen.opened, isEmpty);
      semantics.dispose();
    });

    testWidgets('no unread, no badge; without onBell the bell opens /notifications on the website', (tester) async {
      final semantics = tester.ensureSemantics();
      final server = _usual()..unread = 0;
      final screen = await _pump(tester, server: server, wired: false);

      expect(find.bySemanticsLabel('Notifications'), findsOneWidget);
      await tester.tap(find.byIcon(LucideIcons.bell));
      expect(screen.opened, [_site('/notifications')]);
      semantics.dispose();
    });

    testWidgets('Back goes back', (tester) async {
      final screen = await _pump(tester);
      await tester.tap(find.byIcon(Symbols.arrow_back));
      expect(screen.backs, 1);
    });

    testWidgets('Write an article calls onWriteArticle', (tester) async {
      final screen = await _pump(tester);
      await _tap(tester, find.text('Write an article'));
      expect(screen.writes, 1);
      expect(screen.opened, isEmpty);
    });

    testWidgets('without onWriteArticle it opens the website\'s article composer', (tester) async {
      final screen = await _pump(tester, wired: false);
      await _tap(tester, find.text('Write an article'));
      expect(screen.opened, [_site('/manage/articles')]);
    });

    testWidgets('the card says what writing earns', (tester) async {
      await _pump(tester);
      expect(find.text('Be worth following'), findsOneWidget);
      expect(find.text('Members who follow you hear when you publish something new.'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  group('the screen: small phones and long names', () {
    final long = _Server(
      following: [
        _row(
          'long',
          'Venkatanarasimharajuvaripeta',
          'Subramaniam-Ramachandran-Iyer-Venkataraghavan',
          company: 'The Incredibly Long Named Facility Management Services Private Limited',
        ),
      ],
      followers: [
        _row(
          'long2',
          'Chandrasekharan',
          'Vaidyanathaswamy-Krishnamurthy',
          company: 'Hyderabad Services and Solutions 104',
        ),
      ],
      feed: [
        _post(
          'ARTICLE',
          'long-post',
          'An unreasonably long title about integrated facility management contracts, service level agreements, '
              'energy per seat and the metrics that actually mattered twelve months in',
          author: 'long',
          first: 'Venkatanarasimharajuvaripeta',
          last: 'Subramaniam-Ramachandran-Iyer-Venkataraghavan',
          company: 'The Incredibly Long Named Facility Management Services Private Limited',
          excerpt: 'x' * 200,
        ),
      ],
      suggestions: [
        _suggestion(
          'long3',
          'Venkatanarasimharajuvaripeta',
          'Subramaniam-Ramachandran-Iyer',
          company: 'The Incredibly Long Named Facility Management Services Private Limited',
          followers: 1234567,
          reason: 'Followed by 12 people you follow, including several you have worked with for many years',
        ),
      ],
    );

    for (final tab in NetworkTab.values) {
      testWidgets('${tab.name} at 320 x 568 does not overflow, even with very long names', (tester) async {
        await _pump(tester, server: long, size: const Size(320, 568), tab: tab);

        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(RefreshIndicator), const Offset(0, -700));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('every list laid out in full at 320 wide has no overflow', (tester) async {
      await _pump(tester, server: long, size: const Size(320, 2600));
      for (final tab in NetworkTab.values) {
        await _tap(tester, _key('tab-${tab.name}'));
        expect(tester.takeException(), isNull, reason: tab.name);
      }
    });

    testWidgets('the tap targets stay usable at 320 wide: the Follow button is at least 28 high and on screen', (
      tester,
    ) async {
      await _pump(tester, server: long, size: const Size(320, 2600), tab: NetworkTab.suggestions);

      final rect = tester.getRect(_key('follow-long3'));
      expect(rect.height, greaterThanOrEqualTo(28));
      expect(rect.right, lessThanOrEqualTo(320));
      expect(rect.left, greaterThan(150), reason: 'the name keeps the room it needs');
    });
  });

  // -------------------------------------------------------------------------
  group('the sample source and the route', () {
    testWidgets('the demo repository fills the screen without a server', (tester) async {
      tester.view.physicalSize = const Size(780, 7200);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final controller = NetworkController(DemoNetworkRepository());
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ChangeNotifierProvider.value(value: controller, child: const NetworkScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Site Audit: Implementing Sustainable Net-Zero Solutions'), findsOneWidget);
      expect(_inTile('stat-following', '4'), findsOneWidget);
      expect(_inTile('stat-followers', '6'), findsOneWidget);
    });

    test('NetworkTab labels are the chips', () {
      expect(NetworkTab.values.map((t) => t.label), ['Feed', 'People to follow', 'Following', 'Followers']);
    });
  });
}
