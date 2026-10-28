import 'network_models.dart';

/// Where the Network screen gets its people: the API, or the sample source.
abstract class NetworkRepository {
  /// The signed-in member's id (their followers are read by it). Throws when
  /// nobody is signed in or the API cannot be reached.
  Future<String> viewerId();

  /// What the people the member follows published, newest first.
  Future<ApiPage<NetworkPost>> feed({int page = 1});

  /// Who to follow, with the reason each one is there.
  Future<List<NetworkPerson>> suggestions({int limit = 12});

  /// Everyone the member follows, newest first: every page the API has (up to
  /// a cap), with `total` the API's own count (`meta.total`), which can be
  /// larger than the rows when the cap is reached.
  Future<ApiPage<NetworkPerson>> following();

  /// The member's followers, a page at a time; `total` is all of them.
  Future<ApiPage<NetworkPerson>> followers(String userId, {int page = 1});

  Future<FollowCounts> follow(String userId);

  Future<FollowCounts> unfollow(String userId);

  Future<int> unreadNotifications();
}
