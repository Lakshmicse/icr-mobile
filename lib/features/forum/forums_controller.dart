import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import '../feed/feed_models.dart';
import '../feed/post_reactions.dart';
import 'forum_models.dart';
import 'forum_repository.dart';

/// The Forums tab's state: what the reader asked the forum for (a view, a search, a topic, a tag, a sort), the
/// discussions that came back a page at a time, the topics along the top and the reader's standing. Every action on
/// a card shows at once and is put back when the API refuses; each returns the refusal's sentence, or null.
class ForumsController extends ChangeNotifier {
  ForumsController(this.repository);

  final ForumRepository repository;

  ForumQuery _query = const ForumQuery();
  List<FeedPost> _posts = const [];
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _page = 1;
  int? _total;
  String? _error;
  int _unread = 0;
  bool _started = false;

  List<ForumTopic> _topics = const [];
  bool _topicsRead = false;
  String? _topicsError;
  ForumAccess _access = const ForumAccess();
  List<TaxonomyNode> _taxonomy = const [];
  bool _taxonomyRead = false;

  int _generation = 0;
  bool _disposed = false;

  ForumQuery get query => _query;
  List<FeedPost> get posts => _posts;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;
  int get unread => _unread;
  bool get started => _started;

  /// How many discussions match, when the forum counted them.
  int? get total => _total;
  List<ForumTopic> get topics => _topics;
  bool get topicsRead => _topicsRead;
  String? get topicsError => _topicsError;
  ForumAccess get access => _access;

  /// Every topic with its sub-topics, once read (`readTaxonomy`).
  List<TaxonomyNode> get taxonomy => _taxonomy;

  /// The sub-topics of the chosen topic (level 2 of the taxonomy), once read.
  List<TaxonomyNode> get subtopics {
    final topic = _query.category;
    if (topic == null) return const [];
    for (final node in _taxonomy) {
      if (node.slug == topic.slug) return node.children;
    }
    return const [];
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  /// Reads the topics, the reader's standing, the bell and the first page.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    await Future.wait([refresh(), _readTopics(), _readAccess(), _readUnread()]);
  }

  Future<void> _readTopics() async {
    try {
      _topics = await repository.topics();
      _topicsError = null;
    } catch (e) {
      _topicsError = ApiError.from(e).message;
    } finally {
      _topicsRead = true;
      notifyListeners();
    }
  }

  Future<void> _readAccess() async {
    try {
      _access = await repository.access();
      notifyListeners();
    } catch (_) {
      // The notice about moderation is a nicety; the tab works without it.
    }
  }

  Future<void> _readUnread() async {
    try {
      _unread = await repository.unreadNotifications();
      notifyListeners();
    } catch (_) {}
  }

  /// Reads the whole taxonomy once, for the sub-topic row and the filter sheet.
  Future<void> readTaxonomy() async {
    if (_taxonomyRead) return;
    try {
      _taxonomy = await repository.taxonomy();
      _taxonomyRead = true;
      notifyListeners();
    } catch (_) {
      // Tried again the next time a sub-topic is asked for.
    }
  }

  Future<void> pullToRefresh() async {
    await Future.wait([refresh(), _readTopics(), _readAccess(), _readUnread()]);
  }

  Future<void> refresh() async {
    final generation = ++_generation;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final page = await repository.threads(_query);
      if (generation != _generation) return;
      _posts = page.posts;
      _hasMore = page.hasMore;
      _total = page.total;
      _page = 1;
    } catch (e) {
      if (generation != _generation) return;
      _error = ApiError.from(e).message;
    } finally {
      if (generation == _generation) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    final generation = _generation;
    _loadingMore = true;
    notifyListeners();
    try {
      final page = await repository.threads(_query, page: _page + 1);
      if (generation != _generation) return;
      final seen = _posts.map((p) => p.id).toSet();
      _posts = [..._posts, ...page.posts.where((p) => !seen.contains(p.id))];
      _hasMore = page.hasMore;
      _page++;
    } catch (_) {
      // The next scroll tries again.
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  // --- what the reader asks for ------------------------------------------------------------------------------

  /// Asks for [next]: the list is emptied and the first page read again. The same question asks nothing.
  Future<void> apply(ForumQuery next) async {
    if (_sameQuery(next, _query)) return;
    _query = next;
    _posts = const [];
    _total = null;
    _hasMore = false;
    notifyListeners();
    if (next.category != null) readTaxonomy();
    await refresh();
  }

  Future<void> setView(ForumView view) => apply(_query.copyWith(view: view));

  Future<void> setSearch(String text) => apply(_query.copyWith(search: text.trim()));

  Future<void> setSort(ForumSort sort) => apply(_query.copyWith(sort: sort));

  Future<void> setKind(ForumKindFilter kind) => apply(_query.copyWith(kind: kind));

  /// A topic (a level-1 category), or all topics when null. Changing the topic drops the sub-topic.
  Future<void> setTopic(ForumTopic? topic) => apply(
    topic == null ? _query.copyWith(clearCategory: true) : _query.copyWith(category: topic, clearSubcategory: true),
  );

  Future<void> setSubtopic(TaxonomyNode? node) =>
      apply(node == null ? _query.copyWith(clearSubcategory: true) : _query.copyWith(subcategory: node));

  /// A tag (without "#"), or none when null.
  Future<void> setTag(String? tag) => apply(tag == null ? _query.copyWith(clearTag: true) : _query.copyWith(tag: tag));

  /// Shows the discussions of the topic with this slug (a topic chip on a discussion's page), whether or not the
  /// topic row has it: a topic the forum lists is used as it is, any other is filed under its own name.
  Future<void> showTopic(ForumTopicRef ref) {
    for (final t in _topics) {
      if (t.slug == ref.slug) return setTopic(t);
    }
    return setTopic(ForumTopic(id: ref.id, name: ref.name, slug: ref.slug));
  }

  /// Everything but the view and the search: back to the plain list.
  Future<void> clearFilters() => apply(ForumQuery(view: _query.view, search: _query.search));

  /// Everything but the view: no search, topic, tag, kind or sort.
  Future<void> clearAll() => apply(ForumQuery(view: _query.view));

  static bool _sameQuery(ForumQuery a, ForumQuery b) =>
      a.view == b.view &&
      a.sort == b.sort &&
      a.search == b.search &&
      a.tag == b.tag &&
      a.category?.slug == b.category?.slug &&
      a.subcategory?.slug == b.subcategory?.slug &&
      a.kind == b.kind;

  // --- a card's actions --------------------------------------------------------------------------------------

  FeedPost? _find(String id) {
    for (final p in _posts) {
      if (p.id == id) return p;
    }
    return null;
  }

  void _replace(FeedPost? post) {
    if (post == null) return;
    _posts = [for (final p in _posts) p.id == post.id ? post : p];
    notifyListeners();
  }

  Future<String?> _optimistic(FeedPost before, FeedPost after, Future<void> Function() send) async {
    _replace(after);
    try {
      await send();
      return null;
    } catch (e) {
      _replace(before);
      return ApiError.from(e).message;
    }
  }

  Future<String?> toggleLike(FeedPost post) => react(post, post.myReaction == null ? ReactionKind.like : null);

  Future<String?> react(FeedPost post, ReactionKind? kind) {
    if (post.myReaction == kind) return Future.value(null);
    return _optimistic(post, withReaction(post, kind), () => repository.react(post.id, kind));
  }

  /// Bookmarks the discussion, or lets it go. On the Saved view a card the reader lets go leaves the list.
  Future<String?> toggleSave(FeedPost post) async {
    final message = await _optimistic(
      post,
      post.copyWith(saved: !post.saved),
      () => repository.setSaved(post.id, !post.saved),
    );
    if (message == null && post.saved && _query.view == ForumView.saved) removePost(post.id);
    return message;
  }

  Future<String?> follow(FeedPost post) async {
    final before = _posts;
    _posts = [for (final p in _posts) p.author.id == post.author.id ? p.copyWith(showFollow: false) : p];
    notifyListeners();
    try {
      await repository.setFollowing(post.author.id, true);
      return null;
    } catch (e) {
      _posts = before;
      notifyListeners();
      return ApiError.from(e).message;
    }
  }

  Future<String?> vote(FeedPost post, String optionId) async {
    final poll = post.poll;
    if (poll == null || !poll.open || poll.myOptionId == optionId) return null;
    try {
      final updated = await repository.vote(post.id, optionId, open: poll.open);
      _replace(_find(post.id)?.copyWith(poll: updated));
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    }
  }

  /// Takes in a discussion as its own page left it.
  void adopt(FeedPost page) {
    final current = _find(page.id);
    if (current == null) return;
    if (_query.view == ForumView.saved && !page.saved) {
      removePost(page.id);
      return;
    }
    _replace(
      current.copyWith(
        reactions: page.reactions,
        reactionKinds: page.reactionKinds,
        reactionCounts: page.reactionCounts,
        myReaction: page.myReaction,
        clearMyReaction: page.myReaction == null,
        comments: page.comments,
        saved: page.saved,
        poll: page.poll,
        answered: page.answered,
      ),
    );
  }

  /// A discussion the reader deleted, or let go of on the Saved view, leaves the list.
  void removePost(String id) {
    _posts = [
      for (final p in _posts)
        if (p.id != id) p,
    ];
    if (_total != null) _total = (_total! - 1).clamp(0, 1 << 30);
    notifyListeners();
  }

  /// A discussion just posted: at the top of the reader's list when it is the plain one or their own.
  void addPosted(FeedPost post) {
    if (_query.view != ForumView.all && _query.view != ForumView.mine) return;
    if (_posts.any((p) => p.id == post.id)) return;
    _posts = [post, ..._posts];
    if (_total != null) _total = _total! + 1;
    notifyListeners();
  }
}
