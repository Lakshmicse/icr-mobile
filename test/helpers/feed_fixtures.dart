import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/auth/token_store.dart';
import 'package:icr_mobile/features/feed/api_feed_repository.dart';

/// The Home tests' stand-in for the portal's forum: an adapter that answers each route from a table, records
/// every call, and a small world (threads, replies, a poll, who the reader follows) the table is built from.
class SignedIn extends TokenStore {
  @override
  Future<String?> accessToken() async => 'token';
  @override
  Future<String?> refreshToken() async => null;
}

typedef Handler = Object? Function(RequestOptions options);

class FakeForum implements HttpClientAdapter {
  FakeForum(this.routes);

  final Map<String, Handler> routes;
  final List<RequestOptions> seen = [];

  /// `GET /forum/threads`, `POST /forum/threads/t1/vote`...
  List<String> get calls => [for (final o in seen) '${o.method} ${o.path}'];

  /// The calls to one route, in order.
  List<RequestOptions> to(String method, String path) => [
    for (final o in seen)
      if (o.method == method && o.path == path) o,
  ];

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
    return ResponseBody.fromString(body == null ? '{}' : jsonEncode(body), 200, headers: _json);
  }

  static final _json = {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  };

  @override
  void close({bool force = false}) {}
}

ApiClient clientOn(FakeForum api) {
  final client = ApiClient(tokens: SignedIn(), baseUrl: 'http://api.test/api/v1');
  client.dio.httpClientAdapter = api;
  return client;
}

ApiFeedRepository repositoryOn(FakeForum api, {String viewerId = 'me'}) =>
    ApiFeedRepository(api: clientOn(api), viewerId: viewerId);

// --- JSON the forum answers with ---------------------------------------------------------------------------

Map<String, Object?> member(String id, String name, {String? headline}) {
  final parts = name.split(' ');
  return {
    'id': id,
    'firstName': parts.first,
    'lastName': parts.skip(1).join(' '),
    // No picture: a widget test cannot fetch one, and the avatar then draws the person's initials.
    'avatarUrl': null,
    'headline': headline,
    'reputation': 0,
  };
}

/// A thread as `GET /forum/threads` lists it.
Map<String, Object?> threadCard(
  String id, {
  String? title,
  String excerpt = 'A short excerpt of the discussion.',
  String kind = 'DISCUSSION',
  List<String> tags = const [],
  String categoryKey = 'TECHNOLOGY_INNOVATION',
  String categoryName = 'Technology',
  String? subName,
  Map<String, Object?>? author,
  int replyCount = 0,
  int likes = 0,
  int views = 0,
  Map<String, Object?> reactions = const {},
  String? myReaction,
  bool saved = false,
  Map<String, Object?>? poll,
  Duration age = const Duration(hours: 2),
  String status = 'OPEN',
}) => {
  'id': id,
  'slug': 'slug-$id',
  'title': title ?? 'Discussion $id',
  'excerpt': excerpt,
  'kind': kind,
  'status': status,
  'moderation': 'APPROVED',
  'pinned': false,
  'tags': tags,
  'category': {'id': 'c-$categoryKey', 'key': categoryKey, 'name': categoryName, 'slug': 'c'},
  'subcategory': subName == null ? null : {'id': 's-$id', 'key': 'S_$id', 'name': subName, 'slug': 's'},
  'author': author ?? member('u-$id', 'Author $id'),
  'replyCount': replyCount,
  'viewCount': views,
  'score': likes,
  'likes': likes,
  'hasAcceptedAnswer': false,
  'lastActivityAt': DateTime.now().toUtc().subtract(age).toIso8601String(),
  'createdAt': DateTime.now().toUtc().subtract(age).toIso8601String(),
  'myVote': myReaction == null ? null : 1,
  'myReaction': myReaction,
  'reactions': reactions,
  'poll': poll,
  'saved': saved,
  'latestReply': null,
};

Map<String, Object?> pollJson({String? mine, List<(String, String, int)>? options}) {
  final rows =
      options ?? const [('o1', 'IBM TRIRIGA', 53), ('o2', 'Planon', 27), ('o3', 'Archibus', 87), ('o4', 'Other', 23)];
  return {
    'id': 'poll-1',
    'totalVotes': rows.fold<int>(0, (n, o) => n + o.$3),
    'myOptionId': mine,
    'options': [
      for (final o in rows) {'id': o.$1, 'label': o.$2, 'votes': o.$3},
    ],
  };
}

/// A reply as the replies endpoint nests it.
Map<String, Object?> replyJson(
  String id, {
  String by = 'Arvind Swamy',
  String authorId = 'u-arvind',
  String? headline = 'General Counsel at Brookfield Properties',
  String body = 'Spot on Priya.',
  Duration age = const Duration(minutes: 42),
  int likes = 0,
  bool liked = false,
  List<Map<String, Object?>> children = const [],
}) => {
  'id': id,
  'threadId': 't',
  'parentId': null,
  'bodyHtml': '<p>$body</p>',
  'moderation': 'APPROVED',
  'author': member(authorId, by, headline: headline),
  'score': likes,
  'likes': likes,
  'accepted': false,
  'attachment': null,
  'myVote': liked ? 1 : null,
  'myReaction': liked ? 'LIKE' : null,
  'reactions': likes > 0 ? {'LIKE': likes} : {},
  'canEdit': false,
  'createdAt': DateTime.now().toUtc().subtract(age).toIso8601String(),
  'updatedAt': DateTime.now().toUtc().subtract(age).toIso8601String(),
  'children': children,
};

Map<String, Object?> page(List<Map<String, Object?>> rows, {bool hasNext = false, int? total}) => {
  'data': rows,
  'meta': {
    'page': 1,
    'limit': 20,
    'total': total ?? rows.length,
    'totalPages': 1,
    'hasNext': hasNext,
    'hasPrev': false,
  },
};

/// The forum as the Home tests need it. Everything can be changed before [routes] is read.
class FeedWorld {
  FeedWorld() {
    final iot = threadCard(
      'iot',
      title: 'Implementing IoT sensors for HVAC efficiency: Best practices?',
      excerpt: 'We are currently looking to retrofit a 15- year-old commercial building with modern IoT sensors…',
      kind: 'QUESTION',
      tags: ['HVAC', 'PropTech', 'SmartBMS'],
      categoryKey: 'SUSTAINABILITY_ESG',
      categoryName: 'ESG & Sustainability',
      subName: 'Sustainability',
      author: member('u-sarah', 'Sarah Jenkins', headline: 'Senior Facilities Manager at Google'),
      replyCount: 12,
      likes: 184,
      views: 4210,
      reactions: {'LIKE': 104, 'INSIGHTFUL': 50, 'CELEBRATE': 30},
    );
    threads = [
      iot,
      threadCard(
        'photo',
        title: 'The impact of AI on preliminary site feasibility analysis',
        categoryName: 'Technology',
        subName: 'Real Estate Tech',
        author: member('u-david', 'David Chen', headline: 'Project Director at BuildCo'),
        replyCount: 5,
        likes: 20,
        views: 1200,
        reactions: {'LIKE': 20},
        age: const Duration(hours: 5),
      ),
      threadCard(
        'poll',
        title: 'What is your primary FM Software in 2026?',
        excerpt: 'Select the ecosystem your team relies on for facility workflows.',
        author: member('u-marcus', 'Marcus Reed', headline: 'Lead Architect at DesignCo'),
        likes: 12,
        views: 800,
        reactions: {'LIKE': 12},
        poll: pollJson(mine: 'o3'),
        age: const Duration(hours: 10),
      ),
      threadCard(
        'audit',
        title: 'Site Audit: Implementing Sustainable Net-Zero Solutions',
        categoryKey: 'SUSTAINABILITY_ESG',
        categoryName: 'ESG & Sustainability',
        subName: 'Site Audit',
        author: member('u-elena', 'Elena Rostova', headline: 'Civil & Sustainability Engineer'),
        replyCount: 2,
        likes: 9,
        views: 300,
        reactions: {'LIKE': 9},
        age: const Duration(hours: 8),
      ),
      threadCard(
        'mine',
        title: 'Shortlisting a BMS retrofit partner',
        kind: 'QUESTION',
        author: member('me', 'Bharat Buyer', headline: 'Lead Operations Manager at TechCorp'),
        views: 640,
        age: const Duration(days: 3),
      ),
      threadCard(
        'unanswered',
        title: 'What does a fair AMC escalation clause look like?',
        kind: 'QUESTION',
        tags: ['AMC'],
        author: member('u-followed', 'Fatima Sheikh', headline: 'ESG and net-zero for buildings'),
        age: const Duration(days: 5),
      ),
    ];

    final inThread = [
      replyJson(
        'r2',
        body: 'Spot on Priya.',
        likes: 3,
        children: [
          replyJson(
            'r3',
            by: 'Priya Nambiar',
            authorId: 'u-priya',
            headline: 'Facilities Lead at Infosys',
            body: 'Thanks Arvind.',
            age: const Duration(minutes: 33),
          ),
        ],
      ),
      for (var i = 0; i < 6; i++)
        replyJson(
          'x$i',
          by: 'Member $i',
          authorId: 'u-m$i',
          headline: null,
          body: 'Answer $i',
          age: Duration(minutes: 30 - i * 4),
        ),
      // The newest reply in the whole thread: the reply box continues it.
      replyJson(
        'r10',
        by: 'Priya Nambiar',
        authorId: 'u-priya',
        headline: 'Facilities Lead at Infosys',
        body: 'Great tips everyone.',
        age: const Duration(minutes: 3),
      ),
    ];
    replies = {
      'slug-iot': [
        replyJson(
          'r1',
          body: 'Spot on Priya. Niagara framework BACnet/IP telemetry cut vendor lock-in.',
          likes: 3,
          children: inThread,
        ),
        replyJson(
          'o1',
          by: 'Anita Raghavan',
          authorId: 'u-anita',
          headline: 'Campus FM leader',
          body: 'Pilot on one floor first.',
          age: const Duration(minutes: 70),
          likes: 1,
        ),
        replyJson(
          'o2',
          by: 'Karthik S',
          authorId: 'u-karthik',
          headline: null,
          body: 'Check the BACnet PICS.',
          age: const Duration(minutes: 20),
        ),
      ],
      'slug-photo': [replyJson('p1', body: 'The data gap is real.')],
      'slug-poll': const [],
      'slug-audit': [
        replyJson('a1', body: 'What was the payback?'),
        replyJson(
          'a2',
          by: 'Bharat Buyer',
          authorId: 'me',
          headline: null,
          body: 'Great photos.',
          age: const Duration(minutes: 5),
        ),
      ],
    };

    details = {
      'slug-iot': {
        'bodyHtml':
            '<p>We are currently looking to retrofit a 15- year-old commercial building with modern IoT sensors to better manage our HVAC load. Has anyone integrated with legacy BMS?</p>',
        'attachment': null,
      },
      'slug-photo': {
        'bodyHtml': '<p>I have been experimenting with several new AI tools.</p>',
        'attachment': {'uploadId': 'control-room.jpg', 'fileName': 'BIM Feasibility Lab.jpg', 'fileSize': 76886},
      },
      'slug-audit': {
        'bodyHtml':
            '<p>Just wrapped up an incredible site visit.</p><img src="/uploads/rooftop.jpg" alt="x"><img src="/uploads/a.jpg"><img src="/uploads/b.jpg"><img src="/uploads/c.jpg">',
        'attachment': {'uploadId': 'green-tower.jpg', 'fileName': 'Green tower.jpg', 'fileSize': 50076},
      },
    };
    following = ['u-followed'];
  }

  late List<Map<String, Object?>> threads;
  late Map<String, List<Map<String, Object?>>> replies;
  late Map<String, Map<String, Object?>> details;
  late List<String> following;
  int unread = 3;

  /// The routes a feed runs against. `GET /forum/threads` reads the query the way the forum does: `sort`
  /// (`unanswered` keeps open questions with no reply), `tag`, `search`, `page`, `limit`.
  Map<String, Handler> routes() => {
    'GET /forum/threads': (o) {
      final q = o.queryParameters;
      var rows = threads.where((t) {
        final tag = q['tag'] as String?;
        if (tag != null && !(t['tags'] as List).contains(tag)) return false;
        final search = (q['search'] as String?)?.toLowerCase();
        if (search != null && !('${t['title']} ${t['excerpt']}'.toLowerCase().contains(search))) return false;
        if (q['sort'] == 'unanswered' && !(t['kind'] == 'QUESTION' && t['replyCount'] == 0)) return false;
        return true;
      }).toList();
      if (q['sort'] == 'top') rows = [...rows]..sort((a, b) => (b['likes'] as int).compareTo(a['likes'] as int));
      final limit = (q['limit'] as int?) ?? 20;
      final pageNo = (q['page'] as int?) ?? 1;
      final slice = rows.skip((pageNo - 1) * limit).take(limit).toList();
      return page(slice, hasNext: rows.length > pageNo * limit, total: rows.length);
    },
    'GET /members/me/following': (_) => page([for (final id in following) member(id, 'Followed $id')]),
    'GET /notifications/unread-count': (_) => {'unread': unread},
    for (final t in threads) ...{
      'GET /forum/threads/${t['slug']}': (_) => {
        ...t,
        'bodyHtml': details[t['slug']]?['bodyHtml'] ?? '<p>${t['excerpt']}</p>',
        'attachment': details[t['slug']]?['attachment'],
      },
      'GET /forum/threads/${t['slug']}/replies': (_) => page(replies[t['slug']] ?? const []),
      'POST /forum/threads/${t['id']}/vote': (_) => {'value': 1, 'reaction': 'LIKE', 'changed': 1},
      'DELETE /forum/threads/${t['id']}/vote': (_) => {'value': 0, 'reaction': null, 'changed': -1},
      'POST /forum/threads/${t['id']}/save': (_) => {'saved': true},
      'DELETE /forum/threads/${t['id']}/save': (_) => {'saved': false},
      'POST /forum/threads/${t['id']}/replies': (_) => replyJson('new'),
      'POST /forum/threads/${t['id']}/poll/vote': (o) {
        final id = (o.data as Map)['optionId'] as String;
        return pollJson(
          mine: id,
          options: [
            for (final row in const [
              ('o1', 'IBM TRIRIGA', 53),
              ('o2', 'Planon', 27),
              ('o3', 'Archibus', 87),
              ('o4', 'Other', 23),
            ])
              (row.$1, row.$2, row.$3 + (row.$1 == id ? 1 : 0) - (row.$1 == 'o3' ? 1 : 0)),
          ],
        );
      },
    },
    'POST /members/u-sarah/follow': (_) => {'followers': 1, 'following': 0, 'viewerFollows': true},
    'POST /members/u-david/follow': (_) => {'followers': 1, 'following': 0, 'viewerFollows': true},
    for (final id in const ['r1', 'r2', 'r3', 'o1', 'x0', 'p1', 'a1']) ...{
      'POST /forum/replies/$id/vote': (_) => {'value': 1, 'reaction': 'LIKE', 'changed': 1},
      'DELETE /forum/replies/$id/vote': (_) => {'value': 0, 'reaction': null, 'changed': -1},
    },
    'DELETE /forum/replies/a2': (_) => {'success': true},
  };
}
