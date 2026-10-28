import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import 'network_models.dart';
import 'network_repository.dart';

/// The Network screen's state: the four lists, which one is showing, and the
/// member's follows (taken and given back at once, rolled back if the API
/// refuses).
///
/// The member's own figures are the API's: [followingCount] is the following
/// list's `meta.total` and [followersCount] the followers list's, each moved by
/// one for a follow or unfollow that is on its way.
class NetworkController extends ChangeNotifier {
  NetworkController(this.repository, {NetworkTab initialTab = NetworkTab.feed}) : _tab = initialTab;

  final NetworkRepository repository;

  NetworkTab _tab;
  String? _viewerId;
  bool _started = false;
  bool _loading = false;
  bool _loadingMore = false;
  bool _disposed = false;
  bool _loadedOnce = false;
  String? _error;
  int _generation = 0;
  int _unread = 0;

  List<NetworkPost> _feed = const [];
  int _feedPage = 1;
  bool _feedHasNext = false;

  List<NetworkPerson> _suggestions = const [];

  /// The "Following" list as shown: everyone read, plus anyone followed since.
  /// Someone unfollowed since stays in it (button turns back to Follow) until
  /// the next refresh, so a slip can be undone.
  List<NetworkPerson> _following = const [];
  int _followingTotal = 0;

  List<NetworkPerson> _followers = const [];
  int _followersTotal = 0;
  int _followersPage = 1;
  bool _followersHasNext = false;

  /// Whom the member follows, by id: the truth every Follow button reads.
  final Set<String> _followingIds = {};
  final Set<String> _busy = {};

  bool get started => _started;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;

  /// Why the first load failed (null once something has been read).
  String? get error => _error;
  int get unread => _unread;
  NetworkTab get tab => _tab;

  /// Something has been read: the lists stand while a refresh runs.
  bool get loaded => _loadedOnce;

  List<NetworkPost> get feed => _feed;
  bool get feedHasNext => _feedHasNext;
  List<NetworkPerson> get suggestions => _suggestions;
  List<NetworkPerson> get following => _following;
  List<NetworkPerson> get followers => _followers;
  bool get followersHasNext => _followersHasNext;

  /// Everyone the member follows, as the API counts them.
  int get followingCount => _followingTotal;
  int get followersCount => _followersTotal;

  /// The member follows nobody: the feed cannot fill, so it offers people.
  bool get followsNobody => _followingTotal == 0;

  bool follows(NetworkPerson person) => _followingIds.contains(person.id);
  bool isBusy(NetworkPerson person) => _busy.contains(person.id);

  Future<void> start() async {
    _started = true;
    await _load(notify: false);
  }

  /// Reads everything again. Null when it worked; when it fails after the
  /// lists were read once they stand and the sentence is returned for a
  /// snackbar, and before that [error] holds it for the Retry notice.
  Future<String?> refresh() async {
    await _load(notify: true);
    return _loadedOnce ? _refreshError : null;
  }

  String? _refreshError;

  /// [notify] is false for the first load, which runs from `initState`.
  Future<void> _load({required bool notify}) async {
    final generation = ++_generation;
    _loading = true;
    _error = null;
    _refreshError = null;
    if (notify) _notify();
    try {
      final viewerId = _viewerId ?? await repository.viewerId();
      final results = await Future.wait<Object?>([
        repository.feed(),
        repository.suggestions(),
        repository.following(),
        repository.followers(viewerId),
        repository.unreadNotifications().catchError((_) => 0),
      ]);
      if (generation != _generation) return;
      _viewerId = viewerId;
      final feed = results[0] as ApiPage<NetworkPost>;
      _feed = feed.items;
      _feedPage = 1;
      _feedHasNext = feed.hasNext;
      _suggestions = results[1] as List<NetworkPerson>;
      final following = results[2] as ApiPage<NetworkPerson>;
      _following = following.items;
      _followingTotal = following.total;
      _followingIds
        ..clear()
        ..addAll(_following.map((p) => p.id));
      final followers = results[3] as ApiPage<NetworkPerson>;
      _followers = followers.items;
      _followersTotal = followers.total;
      _followersPage = 1;
      _followersHasNext = followers.hasNext;
      _unread = results[4] as int? ?? 0;
      _loadedOnce = true;
    } catch (e) {
      if (generation != _generation) return;
      final message = _sentence(e);
      if (_loadedOnce) {
        _refreshError = message;
      } else {
        _error = message;
      }
    } finally {
      if (generation == _generation) {
        _loading = false;
        _notify();
      }
    }
  }

  void setTab(NetworkTab tab) {
    if (tab == _tab) return;
    _tab = tab;
    _notify();
  }

  /// "Show more" under the feed or the followers; a sentence when it fails.
  Future<String?> loadMore() async {
    if (_loadingMore) return null;
    final feedTab = _tab == NetworkTab.feed;
    if (!feedTab && _tab != NetworkTab.followers) return null;
    if (feedTab ? !_feedHasNext : !_followersHasNext) return null;
    _loadingMore = true;
    _notify();
    try {
      if (feedTab) {
        final next = await repository.feed(page: _feedPage + 1);
        final seen = _feed.map((p) => p.key).toSet();
        _feed = [..._feed, ...next.items.where((p) => !seen.contains(p.key))];
        _feedPage = next.page;
        _feedHasNext = next.hasNext;
      } else if (_viewerId != null) {
        final next = await repository.followers(_viewerId!, page: _followersPage + 1);
        final seen = _followers.map((p) => p.id).toSet();
        _followers = [..._followers, ...next.items.where((p) => !seen.contains(p.id))];
        _followersTotal = next.total;
        _followersPage = next.page;
        _followersHasNext = next.hasNext;
      }
      return null;
    } catch (e) {
      return _sentence(e);
    } finally {
      _loadingMore = false;
      _notify();
    }
  }

  /// Follows [person] at once; a sentence when the API refuses (and the
  /// follow is taken back).
  Future<String?> follow(NetworkPerson person) async {
    if (follows(person) || _busy.contains(person.id)) return null;
    _busy.add(person.id);
    _followingIds.add(person.id);
    final listed = _following.any((p) => p.id == person.id);
    if (!listed) _following = [person.followedAt(DateTime.now()), ..._following];
    _followingTotal++;
    _notify();
    try {
      await repository.follow(person.id);
      _refreshFeed();
      return null;
    } catch (e) {
      _followingIds.remove(person.id);
      if (!listed) _following = _following.where((p) => p.id != person.id).toList();
      _followingTotal = _followingTotal > 0 ? _followingTotal - 1 : 0;
      return _sentence(e);
    } finally {
      _busy.remove(person.id);
      _notify();
    }
  }

  /// Stops following [person] at once; a sentence when the API refuses (and
  /// the follow is put back).
  Future<String?> unfollow(NetworkPerson person) async {
    if (!follows(person) || _busy.contains(person.id)) return null;
    _busy.add(person.id);
    _followingIds.remove(person.id);
    _followingTotal = _followingTotal > 0 ? _followingTotal - 1 : 0;
    _notify();
    try {
      await repository.unfollow(person.id);
      _refreshFeed();
      return null;
    } catch (e) {
      _followingIds.add(person.id);
      _followingTotal++;
      return _sentence(e);
    } finally {
      _busy.remove(person.id);
      _notify();
    }
  }

  /// A follow changes what the feed holds: it is read again quietly.
  void _refreshFeed() {
    repository
        .feed()
        .then((page) {
          _feed = page.items;
          _feedPage = 1;
          _feedHasNext = page.hasNext;
          _notify();
        })
        .catchError((_) {});
  }

  String _sentence(Object error) {
    final e = ApiError.from(error);
    return e.statusCode == 401 ? 'Sign in to see your network.' : e.message;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
