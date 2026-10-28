import 'dart:math' as math;

import 'package:dio/dio.dart' show DioMediaType, FormData, MultipartFile, Options;

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../core/config.dart';
import '../feed/feed_models.dart';
import '../feed/forum_json.dart';
import 'forum_models.dart';
import 'forum_repository.dart';

/// The community forum (`/forum/*`), read and written as the signed-in member, the way the website's community
/// pages do it.
///
/// The forum has no "following" or "polls" filter, so those two views read the latest 100 discussions and keep
/// the matching ones, as the Home feed does.
class ApiForumRepository implements ForumRepository {
  ApiForumRepository({required this.api, required this.viewerId});

  final ApiClient api;
  @override
  final String? viewerId;
  Set<String>? _following;
  List<TaxonomyNode>? _taxonomy;

  static const pageSize = 20;
  static const _filteredWindow = 100;
  static const _repliesPage = 100;

  ForumJson get _json => ForumJson(apiBase: api.dio.options.baseUrl, viewerId: viewerId);

  // --- reading -----------------------------------------------------------------------------------------------

  @override
  Future<ForumPage> threads(ForumQuery query, {int page = 1}) async {
    final view = query.view;
    final signedIn = viewerId != null;
    final following = signedIn ? await followingIds() : <String>{};
    if (view == ForumView.following && following.isEmpty) return const ForumPage(posts: [], hasMore: false, total: 0);
    final filtered = view == ForumView.following || view == ForumView.polls;
    final res = await _get('/forum/threads', {
      'page': filtered ? 1 : page,
      'limit': filtered ? _filteredWindow : pageSize,
      'sort': query.effectiveSort.api,
      if (query.search.trim().isNotEmpty) 'search': query.search.trim(),
      'tag': ?query.tag,
      'categorySlug': ?query.category?.slug,
      'subcategorySlug': ?query.subcategory?.slug,
      'kind': ?query.kind.api,
      if (view == ForumView.saved) 'savedOnly': true,
      if (view == ForumView.mine) 'mineOnly': true,
    });
    final rows = (res['data'] as List).cast<Map<String, dynamic>>();
    final meta = res['meta'] as Map<String, dynamic>? ?? const {};
    var posts = rows.map((r) => _json.post(r, following: following)).toList();
    if (view == ForumView.following) {
      posts = posts.where((p) => following.contains(p.author.id)).toList();
    } else if (view == ForumView.polls) {
      posts = posts.where((p) => p.poll != null).toList();
    }
    return ForumPage(
      posts: posts,
      hasMore: !filtered && meta['hasNext'] == true,
      total: filtered ? posts.length : (meta['total'] as num?)?.toInt(),
    );
  }

  @override
  Future<List<ForumTopic>> topics() async {
    final rows = await _getList('/forum/categories');
    return [
      for (final r in rows.cast<Map<String, dynamic>>())
        ForumTopic(
          id: r['id'] as String,
          name: r['name'] as String? ?? '',
          slug: r['slug'] as String? ?? '',
          threadCount: (r['threadCount'] as num?)?.toInt() ?? 0,
          blurb: r['description'] as String?,
        ),
    ];
  }

  @override
  Future<List<TaxonomyNode>> taxonomy() async {
    if (_taxonomy != null) return _taxonomy!;
    // The composer's own query on the website (`useCategoryTree({ kind: 'SERVICE', depth: 2 })`).
    final rows = await _getList('/categories/tree', {'kind': 'SERVICE', 'depth': 2});
    TaxonomyNode node(Map<String, dynamic> r) => TaxonomyNode(
      key: r['key'] as String? ?? '',
      name: r['name'] as String? ?? '',
      slug: r['slug'] as String? ?? '',
      children: [
        for (final c in (r['children'] as List? ?? const []).cast<Map<String, dynamic>>())
          if (c['active'] != false && c['key'] != null) node(c),
      ],
    );
    return _taxonomy = [
      for (final r in rows.cast<Map<String, dynamic>>())
        if (r['active'] != false && r['key'] != null) node(r),
    ];
  }

  @override
  Future<ForumAccess> access() async {
    if (viewerId == null) return const ForumAccess();
    final res = await _get('/forum/me');
    return ForumAccess(
      reputation: (res['reputation'] as num?)?.toInt() ?? 0,
      level: res['level'] as String? ?? 'NEW',
      requiresApproval: res['requiresApproval'] == true,
      canModerate: res['canModerate'] == true,
    );
  }

  @override
  Future<int> unreadNotifications() async {
    if (viewerId == null) return 0;
    final res = await _get('/notifications/unread-count');
    return (res['unread'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<ForumThread> thread(String slug) async {
    final json = await _get('/forum/threads/$slug');
    final following = viewerId == null ? <String>{} : await followingIds();
    return _thread(json, following);
  }

  ForumThread _thread(Map<String, dynamic> json, Set<String> following) {
    final card = _json.post(json, following: following);
    final html = json['bodyHtml'] as String? ?? '';
    final base = api.dio.options.baseUrl;
    final attachmentJson = json['attachment'] as Map<String, dynamic>?;
    final uploadId = attachmentJson?['uploadId'] as String?;
    final attachment = uploadId == null
        ? null
        : ForumAttachment(
            uploadId: uploadId,
            fileName: attachmentJson?['fileName'] as String?,
            fileSize: (attachmentJson?['fileSize'] as num?)?.toInt(),
            url: AppConfig.absoluteUrl('/uploads/$uploadId', apiBase: base),
          );
    final photos = <String>[
      if (attachment != null && attachment.isPicture) attachment.url!,
      for (final src in ForumJson.imageSources(html)) ?AppConfig.absoluteUrl(src, apiBase: base),
    ];
    ForumTopicRef? topic(Object? raw) {
      if (raw is! Map<String, dynamic>) return null;
      return ForumTopicRef(
        id: raw['id'] as String? ?? '',
        key: raw['key'] as String? ?? '',
        name: raw['name'] as String? ?? '',
        slug: raw['slug'] as String? ?? '',
      );
    }

    return ForumThread(
      card: card.copyWith(
        body: ForumJson.plainText(html),
        images: [for (final url in photos.take(2)) FeedPicture.network(url)],
        imageCaption: photos.length == 1 && attachment != null ? ForumJson.caption(attachment.fileName) : null,
        morePhotos: math.max(0, photos.length - 2),
        detailLoaded: true,
      ),
      bodyHtml: html,
      lastActivityAt: DateTime.tryParse(json['lastActivityAt'] as String? ?? '') ?? card.createdAt,
      category: topic(json['category']),
      subcategory: topic(json['subcategory']),
      attachment: attachment,
      images: [for (final url in photos) FeedPicture.network(url)],
      subscribed: json['subscribed'] == true,
      canEdit: json['canEdit'] == true,
      canModerate: json['canModerate'] == true,
      acceptedReplyId: json['acceptedReplyId'] as String?,
      pending: json['moderation'] == 'PENDING',
      followsAuthor: following.contains(card.author.id),
      status: json['status'] as String? ?? 'OPEN',
      moderation: json['moderation'] as String? ?? 'APPROVED',
    );
  }

  @override
  Future<ForumReplyPage> replies(String slug, {int page = 1}) async {
    final res = await _get('/forum/threads/$slug/replies', {'page': page, 'limit': _repliesPage});
    final meta = res['meta'] as Map<String, dynamic>? ?? const {};
    return ForumReplyPage(
      replies: (res['data'] as List).cast<Map<String, dynamic>>().map(_json.reply).toList(),
      total: (meta['total'] as num?)?.toInt() ?? 0,
      hasMore: meta['hasNext'] == true,
    );
  }

  @override
  Future<ForumViewersPage> viewers(String threadId, {int page = 1}) async {
    final res = await _get('/forum/threads/$threadId/viewers', {'page': page, 'limit': 50});
    final meta = res['meta'] as Map<String, dynamic>? ?? const {};
    return ForumViewersPage(
      viewers: [
        for (final r in (res['data'] as List).cast<Map<String, dynamic>>())
          ForumViewer(
            person: _json.author(r['user'] as Map<String, dynamic>),
            viewedAt: DateTime.tryParse(r['viewedAt'] as String? ?? '') ?? DateTime.now(),
          ),
      ],
      total: (meta['total'] as num?)?.toInt() ?? 0,
      hidden: (res['hidden'] as num?)?.toInt() ?? 0,
      hasMore: meta['hasNext'] == true,
    );
  }

  @override
  Future<List<ForumReactor>> reactors(String threadId) async {
    final res = await _get('/forum/threads/$threadId/reactions', {'page': 1, 'limit': 50});
    return [
      for (final r in (res['data'] as List).cast<Map<String, dynamic>>())
        ForumReactor(
          person: _json.author(r['user'] as Map<String, dynamic>),
          reaction: reactionKindFromApi(r['reaction'] as String?) ?? ReactionKind.like,
          at: DateTime.tryParse(r['reactedAt'] as String? ?? '') ?? DateTime.now(),
        ),
    ];
  }

  // --- the reader's actions ----------------------------------------------------------------------------------

  @override
  Future<void> recordView(String threadId) => _send('POST', '/forum/threads/$threadId/view');

  @override
  Future<void> react(String threadId, ReactionKind? kind) => kind == null
      ? _send('DELETE', '/forum/threads/$threadId/vote')
      : _send('POST', '/forum/threads/$threadId/vote', {'value': 1, 'reaction': reactionKindToApi(kind)});

  @override
  Future<void> setSaved(String threadId, bool saved) =>
      _send(saved ? 'POST' : 'DELETE', '/forum/threads/$threadId/save');

  @override
  Future<void> setSubscribed(String threadId, bool subscribed) =>
      _send(subscribed ? 'POST' : 'DELETE', '/forum/threads/$threadId/subscribe');

  @override
  Future<void> setFollowing(String memberId, bool follow) async {
    await _send(follow ? 'POST' : 'DELETE', '/members/$memberId/follow');
    if (follow) {
      _following?.add(memberId);
    } else {
      _following?.remove(memberId);
    }
  }

  @override
  Future<bool> follows(String memberId) async => (await followingIds()).contains(memberId);

  @override
  Future<FeedPoll> vote(String threadId, String optionId, {required bool open}) async {
    final res = await _send('POST', '/forum/threads/$threadId/poll/vote', {'optionId': optionId});
    return _json.poll(res as Map<String, dynamic>, open: open);
  }

  @override
  Future<ForumThread> create(ForumDraft draft) async {
    final res = await _send('POST', '/forum/threads', _draftBody(draft, creating: true));
    return _thread(res as Map<String, dynamic>, _following ?? const {});
  }

  @override
  Future<ForumThread> update(String threadId, ForumDraft draft) async {
    final res = await _send('PATCH', '/forum/threads/$threadId', _draftBody(draft, creating: false));
    return _thread(res as Map<String, dynamic>, _following ?? const {});
  }

  /// The DTO the website's composer sends. A poll left without details sends an empty body on a new post (the
  /// API takes it) and no body on an edit (the API refuses to empty one); an edit that leaves the body alone
  /// (`ForumDraft.body` null) sends none, so a body the website's editor formatted is kept as it is.
  Map<String, dynamic> _draftBody(ForumDraft d, {required bool creating}) {
    final html = d.body == null ? '' : ForumJson.textToHtml(d.body!);
    final poll = d.pollOptions?.map((o) => o.trim()).where((o) => o.isNotEmpty).toList();
    return {
      if (d.categoryKey != null) ...{'topicCategory': d.categoryKey, 'topicSubcategory': d.subcategoryKey},
      'title': d.title.trim(),
      if (creating || html.isNotEmpty) 'bodyHtml': html,
      'kind': switch (d.kind) {
        ThreadKind.question => 'QUESTION',
        ThreadKind.announcement => 'ANNOUNCEMENT',
        ThreadKind.discussion => 'DISCUSSION',
      },
      'tags': d.tags,
      'uploadId': ?d.attachment?.uploadId,
      'fileName': ?d.attachment?.fileName,
      'fileSize': ?d.attachment?.fileSize,
      if (creating && poll != null && poll.isNotEmpty) 'pollOptions': poll,
    };
  }

  @override
  Future<void> deleteThread(String threadId) => _send('DELETE', '/forum/threads/$threadId');

  @override
  Future<FeedReply> reply(String threadId, String text, {String? parentId}) async {
    final res = await _send('POST', '/forum/threads/$threadId/replies', {
      'bodyHtml': ForumJson.textToHtml(text),
      'parentId': ?parentId,
    });
    return _json.reply(res as Map<String, dynamic>);
  }

  @override
  Future<FeedReply> editReply(String replyId, String text) async {
    final res = await _send('PATCH', '/forum/replies/$replyId', {'bodyHtml': ForumJson.textToHtml(text)});
    return _json.reply(res as Map<String, dynamic>);
  }

  @override
  Future<void> deleteReply(String replyId) => _send('DELETE', '/forum/replies/$replyId');

  @override
  Future<void> setReplyLiked(String replyId, bool like) =>
      _send(like ? 'POST' : 'DELETE', '/forum/replies/$replyId/vote', like ? {'value': 1, 'reaction': 'LIKE'} : null);

  @override
  Future<void> accept(String threadId, String replyId) => _send('POST', '/forum/threads/$threadId/accept/$replyId');

  @override
  Future<void> report({String? threadId, String? replyId, required ReportReason reason, String? note}) =>
      _send('POST', '/forum/reports', {
        'threadId': ?threadId,
        'replyId': ?replyId,
        'reason': reason.api,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      });

  @override
  Future<ForumAttachment> upload(ForumFile file) async {
    try {
      // The forum takes a photo or a PDF by the type it is sent as, so the type is named from the file's own.
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          file.bytes,
          filename: file.name,
          contentType: DioMediaType.parse(mimeTypeFor(file.name)),
        ),
      });
      final res = await api.dio.post<Map<String, dynamic>>(
        '/uploads',
        data: form,
        queryParameters: {'purpose': 'forum-attachment'},
      );
      final data = res.data ?? const {};
      final url = data['url'] as String? ?? '';
      final uploadId = url.split('/').last;
      return ForumAttachment(
        uploadId: uploadId,
        fileName: data['name'] as String? ?? file.name,
        fileSize: (data['size'] as num?)?.toInt() ?? file.bytes.length,
        url: AppConfig.absoluteUrl(url, apiBase: api.dio.options.baseUrl),
      );
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  @override
  Uri link(String slug, {String? replyId}) => threadLink(slug, replyId: replyId);

  // --- transport ---------------------------------------------------------------------------------------------

  /// Everyone the reader follows, a page of 100 at a time. Read once and kept (the Home feed shares it), and
  /// changed by [setFollowing].
  Future<Set<String>> followingIds() async {
    if (_following != null) return _following!;
    final ids = <String>{};
    try {
      for (var page = 1; page <= 5; page++) {
        final res = await _get('/members/me/following', {'page': page, 'limit': 100});
        ids.addAll((res['data'] as List).map((m) => (m as Map<String, dynamic>)['id'] as String));
        if ((res['meta'] as Map<String, dynamic>?)?['hasNext'] != true) break;
      }
    } on ApiError {
      // Without the list every author reads as not followed; the next read asks again.
      return ids;
    }
    return _following = ids;
  }

  Future<Map<String, dynamic>> _get(String path, [Map<String, dynamic>? query]) async {
    try {
      final res = await api.dio.get<Map<String, dynamic>>(path, queryParameters: query);
      return res.data ?? const {};
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<List<dynamic>> _getList(String path, [Map<String, dynamic>? query]) async {
    try {
      final res = await api.dio.get<List<dynamic>>(path, queryParameters: query);
      return res.data ?? const [];
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

/// The type a file is sent as, by its extension: what the forum's upload takes (a photo, or a PDF).
String mimeTypeFor(String name) {
  final dot = name.lastIndexOf('.');
  final ext = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  return switch (ext) {
    'pdf' => 'application/pdf',
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    'webp' => 'image/webp',
    _ => 'application/octet-stream',
  };
}

/// A discussion's page on the website (`/community/<slug>`), with the reply it scrolls to (`#reply-<id>`).
Uri threadLink(String slug, {String? replyId}) {
  final page = AppConfig.sitePage('/community/$slug');
  return replyId == null ? page : page.replace(fragment: 'reply-$replyId');
}
