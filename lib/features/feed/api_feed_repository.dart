import 'dart:math' as math;

import 'package:dio/dio.dart' show Options;

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../core/config.dart';
import '../forum/api_forum_repository.dart';
import 'feed_models.dart';
import 'feed_repository.dart';
import 'forum_json.dart';

/// The Home feed from the community forum (`GET /forum/threads`).
///
/// The forum has no "following" or "polls" filter, so those two chips read
/// the latest 100 discussions and keep the matching ones. A thread's card in
/// the list carries a 220-character excerpt and no photos; the discussion's own
/// page (`GET /forum/threads/:slug`) has the whole text, its one attachment and
/// the images in its body, which [detail] reads for the cards that come on screen.
class ApiFeedRepository implements FeedRepository {
  ApiFeedRepository({required this.api, required this.viewerId});

  final ApiClient api;
  final String? viewerId;

  static const _pageSize = 20;
  static const _filteredWindow = 100;

  ForumJson get _json => ForumJson(apiBase: api.dio.options.baseUrl, viewerId: viewerId);

  /// The Forums tab's, a discussion page's and the composer's source: the same API, as the same reader. It also
  /// keeps who the reader follows, so a follow on a discussion's page is the feed's too.
  @override
  late final ApiForumRepository forum = ApiForumRepository(api: api, viewerId: viewerId);

  /// ICR's own placement between the second and third posts, carrying the design's copy. There is no feed of
  /// placements to read yet (a paid one is a promotion the website draws elsewhere), so the band is the app's.
  @override
  SponsoredCard get sponsored => const SponsoredCard(
    label: 'SPONSORED PARTNER',
    title: 'The Future of FM Operations',
    body:
        'Automated spatial control, predictive fault detection, and seamless BMS telemetry.\n'
        'Benchmark leases and cut OPEX by 18%.',
    cta: 'Learn More',
    link: '/vendors',
    background: 'assets/images/demo/sponsored_bg.jpg',
  );

  @override
  Set<String> get initiallyOpen => const {};

  @override
  bool get opensLeadThread => true;

  @override
  Future<FeedPage> load(FeedFilter filter, {int page = 1, String? search, String? tag}) async {
    final following = viewerId == null ? <String>{} : await _followingIds();
    final filtered = filter == FeedFilter.following || filter == FeedFilter.polls;
    if (filter == FeedFilter.following && following.isEmpty) {
      return const FeedPage(posts: [], hasMore: false);
    }
    final query = <String, dynamic>{
      'page': filtered ? 1 : page,
      'limit': filtered ? _filteredWindow : _pageSize,
      'sort': switch (filter) {
        FeedFilter.trending => 'top',
        FeedFilter.unanswered => 'unanswered',
        _ => 'latest',
      },
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      'tag': ?tag,
    };
    final res = await _get('/forum/threads', query);
    final rows = (res['data'] as List).cast<Map<String, dynamic>>();
    final meta = res['meta'] as Map<String, dynamic>;
    var posts = rows.map((row) => _json.post(row, following: following)).toList();
    if (filter == FeedFilter.following) {
      posts = posts.where((p) => following.contains(p.author.id)).toList();
    } else if (filter == FeedFilter.polls) {
      posts = posts.where((p) => p.poll != null).toList();
    }
    return FeedPage(posts: posts, hasMore: !filtered && meta['hasNext'] == true);
  }

  @override
  Future<int> unreadNotifications() async {
    if (viewerId == null) return 0;
    final res = await _get('/notifications/unread-count');
    return (res['unread'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<void> setReaction(FeedPost post, ReactionKind? kind) => forum.react(post.id, kind);

  @override
  Future<void> setSaved(FeedPost post, bool saved) =>
      _send(saved ? 'POST' : 'DELETE', '/forum/threads/${post.id}/save');

  @override
  Future<void> follow(FeedAuthor author) => forum.setFollowing(author.id, true);

  @override
  Future<FeedPoll> vote(FeedPost post, String optionId) async {
    final res = await _send('POST', '/forum/threads/${post.id}/poll/vote', {'optionId': optionId});
    return _json.poll(res as Map<String, dynamic>, open: post.poll?.open ?? true);
  }

  @override
  Future<FeedPostDetail?> detail(FeedPost post) async {
    final json = await _get('/forum/threads/${post.slug}');
    final html = json['bodyHtml'] as String? ?? '';
    final base = api.dio.options.baseUrl;

    // Photos: the thread's one attachment when it is a picture, then the images in the body.
    final photos = <String>[];
    String? caption;
    final attachment = json['attachment'] as Map<String, dynamic>?;
    final upload = attachment?['uploadId'] as String?;
    if (upload != null && ForumJson.isPicture(upload)) {
      photos.add('/uploads/$upload');
      caption = ForumJson.caption(attachment?['fileName'] as String?);
    }
    photos.addAll(ForumJson.imageSources(html));
    final urls = [for (final p in photos) ?AppConfig.absoluteUrl(p, apiBase: base)];
    return FeedPostDetail(
      body: ForumJson.plainText(html),
      images: [for (final url in urls.take(2)) FeedPicture.network(url)],
      // A caption is drawn on a lone photo only.
      caption: urls.length == 1 ? caption : null,
      morePhotos: math.max(0, urls.length - 2),
    );
  }

  @override
  Future<List<FeedReply>> replies(FeedPost post) async {
    final res = await _get('/forum/threads/${post.slug}/replies', {'page': 1, 'limit': 100});
    return (res['data'] as List).cast<Map<String, dynamic>>().map(_json.reply).toList();
  }

  @override
  Future<void> reply(FeedPost post, String text, {String? parentId}) => _send(
    'POST',
    '/forum/threads/${post.id}/replies',
    {'bodyHtml': ForumJson.textToHtml(text), 'parentId': ?parentId},
  );

  @override
  Future<void> deleteReply(FeedReply reply) => _send('DELETE', '/forum/replies/${reply.id}');

  @override
  Future<void> setReplyLiked(FeedReply reply, bool like) => _send(
    like ? 'POST' : 'DELETE',
    '/forum/replies/${reply.id}/vote',
    like ? {'value': 1, 'reaction': 'LIKE'} : null,
  );

  @override
  Uri link(FeedPost post, {FeedReply? reply}) => discussionLink(post, reply);

  /// The organisation a headline names, for the line under a reply's name (see [ForumJson.organisationOf]).
  static String? organisationOf(String? headline) => ForumJson.organisationOf(headline);

  // --- transport -------------------------------------------------------------

  /// Everyone the reader follows: the card shows "Follow" only for the others.
  Future<Set<String>> _followingIds() => forum.followingIds();

  Future<Map<String, dynamic>> _get(String path, [Map<String, dynamic>? query]) async {
    try {
      final res = await api.dio.get<Map<String, dynamic>>(path, queryParameters: query);
      return res.data ?? const {};
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<dynamic> _send(String method, String path, [Map<String, dynamic>? body]) async {
    try {
      final res = await api.dio.request<dynamic>(
        path,
        data: body,
        options: Options(method: method),
      );
      return res.data;
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}
