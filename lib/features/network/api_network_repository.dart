import '../../core/api/api_client.dart';
import '../chapters/community_api.dart';
import 'network_models.dart';
import 'network_repository.dart';

/// The Network screen from the API (the portal's members module):
/// `GET /members/me/feed`, `/members/me/suggestions`, `/members/me/following`,
/// `/members/:id/followers`, and `POST|DELETE /members/:id/follow`.
///
/// Shapes, as the running API answers them:
/// * feed, following, followers: `{ data: [...], meta: { page, limit, total,
///   totalPages, hasNext, hasPrev } }`;
/// * suggestions: a bare list, `limit` at most 12;
/// * a feed author's and a suggestion's `company` is a name (or null), a
///   following or follower row's is `{ name }` (or null), and only those two
///   carry `followedAt`;
/// * follow and unfollow answer `{ followers, following, viewerFollows }` about
///   the person followed, not about the member.
class ApiNetworkRepository implements NetworkRepository {
  ApiNetworkRepository({required ApiClient api}) : _api = CommunityApi(api);

  final CommunityApi _api;

  static const feedPageSize = 20;
  static const followersPageSize = 30;

  /// `following` is read whole (every Follow button needs to know who is
  /// followed), 100 a page, up to this many pages: 2,000 people, which is as
  /// many as the API's own feed reads.
  static const followingPageSize = 100;
  static const followingMaxPages = 20;

  @override
  Future<String> viewerId() async {
    final me = await _api.getMap('/auth/me');
    final id = me['id'];
    if (id is! String) throw StateError('/auth/me answered without an id');
    return id;
  }

  @override
  Future<ApiPage<NetworkPost>> feed({int page = 1}) async {
    final res = await _api.page('/members/me/feed', {'page': page, 'limit': feedPageSize});
    return ApiPage(
      items: [for (final row in res.items) ?_post(row)],
      total: res.total,
      page: res.page,
      hasNext: res.hasNext,
    );
  }

  @override
  Future<List<NetworkPerson>> suggestions({int limit = 12}) async {
    final rows = await _api.getList('/members/me/suggestions', {'limit': limit});
    return rows.map(_person).toList();
  }

  @override
  Future<ApiPage<NetworkPerson>> following() async {
    final rows = <Map<String, dynamic>>[];
    var total = 0;
    for (var page = 1; page <= followingMaxPages; page++) {
      final res = await _api.page('/members/me/following', {'page': page, 'limit': followingPageSize});
      rows.addAll(res.items);
      total = res.total;
      if (!res.hasNext) break;
    }
    return ApiPage(items: rows.map(_person).toList(), total: total, page: 1, hasNext: rows.length < total);
  }

  @override
  Future<ApiPage<NetworkPerson>> followers(String userId, {int page = 1}) async {
    final res = await _api.page('/members/$userId/followers', {'page': page, 'limit': followersPageSize});
    return res.map(_person);
  }

  @override
  Future<FollowCounts> follow(String userId) async => _counts(await _api.send('POST', '/members/$userId/follow'));

  @override
  Future<FollowCounts> unfollow(String userId) async => _counts(await _api.send('DELETE', '/members/$userId/follow'));

  @override
  Future<int> unreadNotifications() => _api.unreadNotifications();

  // --- mapping -------------------------------------------------------------

  FollowCounts _counts(Object? res) {
    final json = res is Map ? res : const {};
    return FollowCounts(
      followers: CommunityApi.count(json['followers']),
      following: CommunityApi.count(json['following']),
      viewerFollows: json['viewerFollows'] == true,
    );
  }

  /// A person card: `company` is a name on suggestions and the feed, and
  /// `{ name }` on the follow lists.
  NetworkPerson _person(Map<String, dynamic> json) {
    final company = json['company'];
    return NetworkPerson(
      id: json['id'] as String,
      firstName: CommunityApi.text(json['firstName']) ?? '',
      lastName: CommunityApi.text(json['lastName']) ?? '',
      photo: _api.picture(CommunityApi.text(json['avatarUrl'])),
      company: company is Map ? CommunityApi.text(company['name']) : CommunityApi.text(company),
      reason: CommunityApi.text(json['reason']),
      followers: (json['followers'] as num?)?.toInt(),
      since: CommunityApi.date(json['followedAt']),
    );
  }

  /// A feed row; null (left out) when it has no author to show.
  NetworkPost? _post(Map<String, dynamic> json) {
    final author = json['author'];
    if (author is! Map || json['id'] is! String) return null;
    return NetworkPost(
      kind: json['kind'] == 'ARTICLE' ? PostKind.article : PostKind.thread,
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      excerpt: (json['excerpt'] as String? ?? '').trim(),
      link: CommunityApi.text(json['link']) ?? '/network',
      at: CommunityApi.date(json['at']) ?? DateTime.now(),
      author: _person(author.cast<String, dynamic>()),
    );
  }
}
