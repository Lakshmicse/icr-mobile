import 'network_models.dart';
import 'network_repository.dart';

/// The sample source: a member following four people, with a feed, three
/// suggestions and a handful of followers. Follows are kept in memory.
class DemoNetworkRepository implements NetworkRepository {
  DemoNetworkRepository({DateTime? now}) : _now = now ?? DateTime.utc(2026, 10, 24, 9);

  final DateTime _now;

  static const _people = <String, NetworkPerson>{
    'sarah': NetworkPerson(
      id: 'sarah',
      firstName: 'Sarah',
      lastName: 'Jenkins',
      company: 'JLL',
      photo: FeedPicture.asset('assets/images/demo/avatar_sarah.jpg'),
    ),
    'david': NetworkPerson(
      id: 'david',
      firstName: 'David',
      lastName: 'Chen',
      company: 'BIM Feasibility Lab',
      photo: FeedPicture.asset('assets/images/demo/avatar_david.jpg'),
    ),
    'marcus': NetworkPerson(
      id: 'marcus',
      firstName: 'Marcus',
      lastName: 'Reed',
      company: 'Cushman & Wakefield',
      photo: FeedPicture.asset('assets/images/demo/avatar_marcus.jpg'),
    ),
    'elena': NetworkPerson(
      id: 'elena',
      firstName: 'Elena',
      lastName: 'Rostova',
      company: 'Brookfield Properties',
      photo: FeedPicture.asset('assets/images/demo/avatar_elena.jpg'),
    ),
    'arvind': NetworkPerson(
      id: 'arvind',
      firstName: 'Arvind',
      lastName: 'Swamy',
      company: 'Brookfield Properties',
      photo: FeedPicture.asset('assets/images/demo/avatar_arvind.jpg'),
    ),
    'nikhil': NetworkPerson(
      id: 'nikhil',
      firstName: 'Nikhil',
      lastName: 'Rao',
      company: 'TechCorp',
      photo: FeedPicture.asset('assets/images/demo/avatar_nikhil.jpg'),
    ),
    'priya': NetworkPerson(id: 'priya', firstName: 'Priya', lastName: 'Nambiar', company: 'IGBC'),
    'rajesh': NetworkPerson(id: 'rajesh', firstName: 'Rajesh', lastName: 'Menon', company: 'Mumbai Facility 100'),
    'fatima': NetworkPerson(id: 'fatima', firstName: 'Fatima', lastName: 'Sheikh'),
  };

  final _following = <String>['marcus', 'elena', 'sarah', 'rajesh'];
  final _followers = <String>['marcus', 'elena', 'arvind', 'priya', 'fatima', 'david'];

  /// Calls, for tests.
  final calls = <String>[];

  @override
  Future<String> viewerId() async => 'me';

  @override
  Future<ApiPage<NetworkPost>> feed({int page = 1}) async {
    calls.add('feed:$page');
    final posts = [
      NetworkPost(
        kind: PostKind.thread,
        id: 't1',
        title: 'Site Audit: Implementing Sustainable Net-Zero Solutions',
        excerpt:
            'Just wrapped up an incredible site visit. Integrating smart climate control and on-site renewables '
            'can turn an existing structure into a net-zero showcase.',
        link: '/community/site-audit-net-zero',
        at: _now.subtract(const Duration(hours: 2)),
        author: _people['elena']!,
      ),
      NetworkPost(
        kind: PostKind.article,
        id: 'a1',
        title: 'What a GCC campus taught us about IFM contracts',
        excerpt:
            'Bundled services looked cheaper on paper. Twelve months in, the metrics that mattered were response '
            'times and energy per seat — here is how we rewrote the scope.',
        link: '/blogs/gcc-campus-ifm-contracts',
        at: _now.subtract(const Duration(hours: 9)),
        author: _people['sarah']!,
      ),
      NetworkPost(
        kind: PostKind.thread,
        id: 't2',
        title: 'What is your primary FM Software in 2026?',
        excerpt: 'Select the ecosystem your team relies on for facility workflows.',
        link: '/community/primary-fm-software-2026',
        at: _now.subtract(const Duration(days: 1)),
        author: _people['marcus']!,
      ),
    ];
    return ApiPage(items: page == 1 ? posts : const [], total: posts.length, page: page, hasNext: false);
  }

  @override
  Future<List<NetworkPerson>> suggestions({int limit = 12}) async {
    calls.add('suggestions');
    final picks = [
      ('david', 'Followed by 2 people you follow', 41),
      ('arvind', 'Followed by someone you follow', 18),
      ('nikhil', 'Works at TechCorp', 7),
      ('priya', 'Active in the community', 52),
    ];
    return [
      for (final (id, reason, followers) in picks)
        if (!_following.contains(id))
          NetworkPerson(
            id: id,
            firstName: _people[id]!.firstName,
            lastName: _people[id]!.lastName,
            photo: _people[id]!.photo,
            company: _people[id]!.company,
            reason: reason,
            followers: followers,
          ),
    ].take(limit).toList();
  }

  @override
  Future<ApiPage<NetworkPerson>> following() async {
    calls.add('following');
    final all = [for (final id in _following) _people[id]!];
    return ApiPage(items: all, total: all.length, page: 1, hasNext: false);
  }

  @override
  Future<ApiPage<NetworkPerson>> followers(String userId, {int page = 1}) async {
    calls.add('followers:$page');
    final all = [for (final id in _followers) _people[id]!];
    return ApiPage(items: page == 1 ? all : const [], total: all.length, page: page, hasNext: false);
  }

  @override
  Future<FollowCounts> follow(String userId) async {
    calls.add('follow:$userId');
    if (!_following.contains(userId)) _following.insert(0, userId);
    return FollowCounts(followers: 1, following: _following.length, viewerFollows: true);
  }

  @override
  Future<FollowCounts> unfollow(String userId) async {
    calls.add('unfollow:$userId');
    _following.remove(userId);
    return FollowCounts(followers: 0, following: _following.length, viewerFollows: false);
  }

  @override
  Future<int> unreadNotifications() async => 3;
}
