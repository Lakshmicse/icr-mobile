import 'dart:convert';

import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/features/feed/feed_models.dart';
import 'package:icr_mobile/features/forum/api_forum_repository.dart';

import 'feed_fixtures.dart';

/// The forum as the discussion page's tests need it: one discussion, its replies (one or two pages), and every route
/// a reader's action calls, answered from state the tests can read and change. Built on `feed_fixtures.dart`.
class ForumWorld {
  ForumWorld({
    this.kind = 'QUESTION',
    this.status = 'OPEN',
    this.moderation = 'APPROVED',
    this.canEdit = false,
    this.canModerate = false,
    this.authorId = 'u-sarah',
    this.withPoll = false,
    String? bodyHtml,
    this.attachment,
    this.followsAuthor = false,
    this.subscribed = false,
  }) : bodyHtml =
           bodyHtml ??
           '<p>We need <strong>sensors</strong> for the <em>HVAC</em> load.</p><ul><li>BMS</li><li>BACnet</li></ul>' {
    // Replies: Arvind's thread (answers under it), a second root, and one of the reader's own.
    page1 = [
      replyJson(
        'r1',
        body: 'Spot on Priya.',
        likes: 3,
        children: [
          replyJson(
            'r2',
            by: 'Priya Nambiar',
            authorId: 'u-priya',
            headline: 'Facilities Lead at Infosys',
            body: 'Thanks Arvind.',
            age: const Duration(minutes: 33),
            children: [replyJson('r3', body: 'Kept the old controllers.', age: const Duration(minutes: 29))],
          ),
        ],
      ),
      replyJson(
        'r4',
        by: 'Anita Raghavan',
        authorId: 'u-anita',
        headline: 'Campus FM leader',
        body: 'Pilot on one floor first.',
        age: const Duration(minutes: 70),
        likes: 1,
      ),
      replyJson(
        'r5',
        by: 'Bharat Buyer',
        authorId: 'me',
        headline: null,
        body: 'Mine: check the PICS.',
        age: const Duration(minutes: 5),
      )..['canEdit'] = true,
    ];
  }

  final String kind;
  String status;
  String moderation;
  bool canEdit;
  bool canModerate;
  final String authorId;
  final bool withPoll;
  String bodyHtml;
  final Map<String, Object?>? attachment;
  bool followsAuthor;
  bool subscribed;

  static const slug = 'slug-q';
  static const id = 't-q';

  late List<Map<String, Object?>> page1;

  /// A second page, flat as the forum cuts it (a child whose parent is on page 1 comes back at its top).
  List<Map<String, Object?>> page2 = [];
  bool saved = false;
  String? myReaction;
  String? myOption;
  String? acceptedReplyId;
  int viewCalls = 0;
  int unread = 2;
  final following = <String>{};
  int replyCount = 6;
  int likes = 12;

  /// Bodies the API refuses, by route (`'POST /forum/threads/t-q/replies'` -> `(400, message)`).
  final refusals = <String, (int, String)>{};

  Map<String, Object?> get poll => pollJson(
    mine: myOption,
    options: const [('o1', 'IBM TRIRIGA', 53), ('o2', 'Planon', 27), ('o3', 'Archibus', 87)],
  );

  Map<String, Object?> detail() => {
    ...threadCard(
      id,
      title: 'Implementing IoT sensors for HVAC efficiency: Best practices?',
      kind: kind,
      tags: ['HVAC', 'PropTech'],
      categoryKey: 'SUSTAINABILITY_ESG',
      categoryName: 'ESG & Sustainability',
      subName: 'Sustainability',
      author: member(authorId, 'Sarah Jenkins', headline: 'Senior Facilities Manager at Google'),
      replyCount: replyCount,
      likes: likes,
      views: 4210,
      reactions: {'LIKE': likes},
      myReaction: myReaction,
      saved: saved,
      poll: withPoll ? poll : null,
      status: status,
    ),
    'slug': slug,
    'moderation': moderation,
    'hasAcceptedAnswer': acceptedReplyId != null,
    'bodyHtml': bodyHtml,
    'attachment': attachment,
    'acceptedReplyId': acceptedReplyId,
    'subscribed': subscribed,
    'canEdit': canEdit,
    'canModerate': canModerate,
    'updatedAt': DateTime.now().toUtc().toIso8601String(),
  };

  (int, String)? _refuse(String key) => refusals[key];

  Map<String, Handler> routes() {
    Object? answer(String key, Object? Function() ok) {
      final refused = _refuse(key);
      if (refused != null) return (refused.$1, jsonEncode({'statusCode': refused.$1, 'message': refused.$2}));
      return ok();
    }

    return {
      'GET /forum/threads/$slug': (_) => answer('GET /forum/threads/$slug', detail),
      'GET /forum/threads/$slug/replies': (o) {
        final pageNo = (o.queryParameters['page'] as int?) ?? 1;
        if (pageNo == 1) {
          return answer(
            'GET /forum/threads/$slug/replies',
            () => {
              'data': page1,
              'meta': {
                'page': 1,
                'limit': 100,
                'total': replyCount,
                'totalPages': page2.isEmpty ? 1 : 2,
                'hasNext': page2.isNotEmpty,
                'hasPrev': false,
              },
            },
          );
        }
        return {
          'data': page2,
          'meta': {'page': 2, 'limit': 100, 'total': replyCount, 'totalPages': 2, 'hasNext': false, 'hasPrev': true},
        };
      },
      'POST /forum/threads/$id/view': (_) {
        viewCalls++;
        return {'success': true};
      },
      'GET /members/me/following': (_) => page([for (final m in following) member(m, 'Followed $m')]),
      'GET /notifications/unread-count': (_) => {'unread': unread},
      'POST /forum/threads/$id/vote': (o) => answer('POST /forum/threads/$id/vote', () {
        myReaction = (o.data as Map)['reaction'] as String? ?? 'LIKE';
        return {'value': 1, 'reaction': myReaction, 'changed': 1};
      }),
      'DELETE /forum/threads/$id/vote': (_) => answer('DELETE /forum/threads/$id/vote', () {
        myReaction = null;
        return {'value': 0, 'reaction': null, 'changed': -1};
      }),
      'POST /forum/threads/$id/save': (_) => answer('POST /forum/threads/$id/save', () {
        saved = true;
        return {'saved': true};
      }),
      'DELETE /forum/threads/$id/save': (_) => answer('DELETE /forum/threads/$id/save', () {
        saved = false;
        return {'saved': false};
      }),
      'POST /forum/threads/$id/subscribe': (_) => answer('POST /forum/threads/$id/subscribe', () {
        subscribed = true;
        return {'subscribed': true};
      }),
      'DELETE /forum/threads/$id/subscribe': (_) => answer('DELETE /forum/threads/$id/subscribe', () {
        subscribed = false;
        return {'subscribed': false};
      }),
      'POST /members/$authorId/follow': (_) => answer('POST /members/$authorId/follow', () {
        following.add(authorId);
        return {'followers': 1, 'following': 0, 'viewerFollows': true};
      }),
      'DELETE /members/$authorId/follow': (_) => answer('DELETE /members/$authorId/follow', () {
        following.remove(authorId);
        return {'followers': 0, 'following': 0, 'viewerFollows': false};
      }),
      'POST /forum/threads/$id/poll/vote': (o) => answer('POST /forum/threads/$id/poll/vote', () {
        myOption = (o.data as Map)['optionId'] as String;
        return poll;
      }),
      'POST /forum/threads/$id/replies': (o) => answer('POST /forum/threads/$id/replies', () {
        final body = Map<String, Object?>.from(o.data as Map);
        final html = body['bodyHtml'] as String;
        final reply =
            replyJson(
                'new${_n++}',
                by: 'Bharat Buyer',
                authorId: 'me',
                headline: null,
                body: html.replaceAll(RegExp(r'</?p>'), ''),
                age: Duration.zero,
              )
              ..['bodyHtml'] = html
              ..['parentId'] = body['parentId']
              ..['canEdit'] = true;
        replyCount++;
        return reply;
      }),
      'PATCH /forum/replies/r5': (o) => answer('PATCH /forum/replies/r5', () {
        final html = (o.data as Map)['bodyHtml'] as String;
        return replyJson('r5', by: 'Bharat Buyer', authorId: 'me', headline: null, body: html)
          ..['bodyHtml'] = html
          ..['canEdit'] = true;
      }),
      'DELETE /forum/replies/r5': (_) => answer('DELETE /forum/replies/r5', () => {'success': true}),
      for (final r in const ['r1', 'r2', 'r3', 'r4']) ...{
        'POST /forum/replies/$r/vote': (_) =>
            answer('POST /forum/replies/$r/vote', () => {'value': 1, 'reaction': 'LIKE', 'changed': 1}),
        'DELETE /forum/replies/$r/vote': (_) =>
            answer('DELETE /forum/replies/$r/vote', () => {'value': 0, 'reaction': null, 'changed': -1}),
        'POST /forum/threads/$id/accept/$r': (_) => answer('POST /forum/threads/$id/accept/$r', () {
          acceptedReplyId = r;
          return {'acceptedReplyId': r};
        }),
      },
      'POST /forum/reports': (o) => answer('POST /forum/reports', () => {'id': 'report-1', 'status': 'PENDING'}),
      'DELETE /forum/threads/$id': (_) => answer('DELETE /forum/threads/$id', () => {'success': true}),
      'GET /forum/threads/$id/reactions': (_) => page([
        {
          'user': member('u-a', 'Anita Raghavan', headline: 'Campus FM leader'),
          'reaction': 'INSIGHTFUL',
          'reactedAt': DateTime.now().toUtc().toIso8601String(),
        },
        {'user': member('u-b', 'Karthik S'), 'reaction': 'LIKE', 'reactedAt': DateTime.now().toUtc().toIso8601String()},
      ]),
      'GET /forum/threads/$id/viewers': (_) => {
        ...page([
          {
            'user': member('u-v', 'Vikram Iyer', headline: 'Head of FM at Prestige'),
            'viewedAt': DateTime.now().toUtc().toIso8601String(),
          },
        ]),
        'hidden': 4,
      },
    };
  }

  int _n = 1;
}

/// The repository the screen reads and writes through, on [api].
ApiForumRepository forumOn(FakeForum api, {String viewerId = 'me'}) =>
    ApiForumRepository(api: clientOn(api), viewerId: viewerId);

/// The reader the page draws (the reply box's photo, "your own" tests).
const reader = FeedAuthor(id: 'me', name: 'Bharat Buyer');

/// Re-exported so a test needs one import for the client.
ApiClient clientFor(FakeForum api) => clientOn(api);

extension FakeForumX on FakeForum {
  /// How many times a route was called.
  int count(String method, String path) => to(method, path).length;

  /// The body of the latest call to a route.
  Map<String, dynamic> bodyOf(String method, String path) =>
      Map<String, dynamic>.from(to(method, path).last.data as Map);
}
