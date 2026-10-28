import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import 'feed_models.dart';
import 'feed_repository.dart';
import 'post_reactions.dart';

/// The Home feed's state: the chosen chip, the loaded posts, and the
/// reader's actions on them (applied at once, rolled back if the API refuses).
class FeedController extends ChangeNotifier {
  FeedController(this.repository) : _open = {...repository.initiallyOpen};

  final FeedRepository repository;

  /// How many cards at the top are read in full before the feed is drawn, so the first screen does not grow
  /// photo by photo under the reader's thumb.
  static const prefetchedCards = 6;

  FeedFilter _filter = FeedFilter.all;
  String? _tag;
  String _search = '';
  List<FeedPost> _posts = const [];
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _page = 1;
  String? _error;
  int _unread = 0;
  final Set<String> _open;
  final Set<String> _loadingReplies = {};
  final Set<String> _reading = {};
  final Map<String, FeedPostDetail?> _details = {};

  /// The tags of every discussion read so far, by discussion, so a page read twice counts once. The topic chips
  /// are ranked from it: the forum has no endpoint for its tags, only the discussions that carry them.
  final Map<String, List<String>> _tagsByPost = {};
  bool _leadOpened = false;
  int _generation = 0;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// A read or a reply still on its way when the screen goes away must not wake a controller that is gone.
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  FeedFilter get filter => _filter;

  /// How many topic chips follow the filters.
  static const maxTopics = 6;

  /// The topic chips, most used tag first: the tags of the discussions read so far (the Home feed reads whole
  /// pages, and a filtered view reads the latest hundred), so a chip is there because discussions carry it. The
  /// tag in use is always shown, so it can be turned off again. No tags read, no chips.
  List<FeedTopic> get topics {
    final counts = <String, int>{};
    final shown = <String, String>{};
    for (final tags in _tagsByPost.values) {
      for (final tag in tags) {
        final key = tag.toLowerCase();
        counts[key] = (counts[key] ?? 0) + 1;
        shown.putIfAbsent(key, () => tag);
      }
    }
    final ranked = counts.keys.toList()
      ..sort((a, b) {
        final byCount = counts[b]!.compareTo(counts[a]!);
        return byCount != 0 ? byCount : a.compareTo(b);
      });
    final top = [for (final key in ranked.take(maxTopics)) FeedTopic(shown[key]!)];
    final active = _tag;
    if (active != null && !top.any((t) => t.tag.toLowerCase() == active.toLowerCase())) {
      top.insert(0, FeedTopic(active));
    }
    return top;
  }

  void _noteTags(Iterable<FeedPost> posts) {
    for (final post in posts) {
      _tagsByPost[post.id] = [for (final tag in post.tags) if (tag.length > 1) tag.startsWith('#') ? tag.substring(1) : tag];
    }
  }

  /// The topic chip in use, if any; it replaces the filter chips' selection.
  String? get tag => _tag;
  String get search => _search;
  List<FeedPost> get posts => _posts;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;
  int get unread => _unread;
  SponsoredCard get sponsored => repository.sponsored;

  bool isOpen(FeedPost post) => _open.contains(post.id);
  bool isLoadingReplies(FeedPost post) => _loadingReplies.contains(post.id);

  Future<void> start() async {
    await Future.wait([refresh(), _loadUnread()]);
  }

  Future<void> setFilter(FeedFilter filter) async {
    if (filter == _filter && _tag == null) return;
    _filter = filter;
    _tag = null;
    _posts = const [];
    notifyListeners();
    await refresh();
  }

  /// A topic chip: the latest discussions with that tag. Tapping it again
  /// goes back to All Feed.
  Future<void> setTag(String tag) async {
    _tag = _tag == tag ? null : tag;
    _filter = FeedFilter.all;
    _posts = const [];
    notifyListeners();
    await refresh();
  }

  Future<void> setSearch(String query) async {
    if (query.trim() == _search) return;
    _search = query.trim();
    await refresh();
  }

  /// Pull to refresh: what the server holds now, the photos and full texts read again too.
  Future<void> pullToRefresh() async {
    _details.clear();
    await Future.wait([refresh(), _loadUnread()]);
  }

  Future<void> refresh() async {
    final generation = ++_generation;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final page = await repository.load(_filter, search: _search, tag: _tag);
      if (generation != _generation) return;
      final posts = await _withDetails(page.posts);
      if (generation != _generation) return;
      _noteTags(posts);
      // A thread that was open keeps the replies it showed while they are read again, so it does not blink.
      final shown = {
        for (final p in _posts)
          if (p.repliesLoaded) p.id: p,
      };
      _posts = [
        for (final p in posts)
          if (shown[p.id] case final old?) p.copyWith(replies: old.replies, repliesLoaded: true) else p,
      ];
      _hasMore = page.hasMore;
      _page = 1;
      // The design opens the first post's comments; the live feed does the same, once.
      if (!_leadOpened && repository.opensLeadThread && _filter == FeedFilter.all && _tag == null && _search.isEmpty) {
        _leadOpened = true;
        final lead = _posts.isEmpty ? null : _posts.first;
        if (lead != null && lead.comments > 0 && lead.poll == null) _open.add(lead.id);
      }
      for (final post in _posts.where((p) => _open.contains(p.id) && !p.repliesLoaded)) {
        _fetchReplies(post);
      }
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
      final page = await repository.load(_filter, page: _page + 1, search: _search, tag: _tag);
      if (generation != _generation) return;
      final seen = _posts.map((p) => p.id).toSet();
      _noteTags(page.posts);
      _posts = [..._posts, ...page.posts.where((p) => !seen.contains(p.id)).map(_cached)];
      _hasMore = page.hasMore;
      _page++;
    } catch (_) {
      // The next scroll tries again.
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  Future<void> _loadUnread() async {
    try {
      _unread = await repository.unreadNotifications();
      notifyListeners();
    } catch (_) {}
  }

  // --- the whole text and the photos of a card -------------------------------

  /// A card as it was last read, when it was.
  FeedPost _cached(FeedPost post) => _details.containsKey(post.slug) ? _merge(post, _details[post.slug]) : post;

  static FeedPost _merge(FeedPost post, FeedPostDetail? detail) => detail == null
      ? post.copyWith(detailLoaded: true)
      : post.copyWith(
          body: detail.body.isEmpty ? post.body : detail.body,
          images: detail.images,
          imageCaption: detail.caption,
          morePhotos: detail.morePhotos,
          detailLoaded: true,
        );

  Future<FeedPost> _read(FeedPost post) async {
    if (_details.containsKey(post.slug)) return _merge(post, _details[post.slug]);
    try {
      final detail = await repository.detail(post);
      _details[post.slug] = detail;
      return _merge(post, detail);
    } catch (_) {
      // The card keeps the list's excerpt; coming back to it asks again.
      return post;
    }
  }

  /// The first cards read in full at once, the rest as they are cached.
  Future<List<FeedPost>> _withDetails(List<FeedPost> posts) async {
    final head = await Future.wait(posts.take(prefetchedCards).map(_read));
    return [...head, ...posts.skip(prefetchedCards).map(_cached)];
  }

  /// Reads one card's discussion when it comes on screen: its whole text and photos. Cards read already, and
  /// cards being read, are left alone.
  Future<void> ensureDetail(FeedPost post) async {
    final current = _find(post.id);
    if (current == null || current.detailLoaded || _reading.contains(post.id)) return;
    _reading.add(post.id);
    try {
      final read = await _read(current);
      final latest = _find(post.id);
      if (latest == null) return;
      // The reader may have liked or saved it meanwhile: only the text and photos are taken over.
      _replace(
        latest.copyWith(
          body: read.body,
          images: read.images,
          imageCaption: read.imageCaption,
          morePhotos: read.morePhotos,
          detailLoaded: read.detailLoaded,
        ),
      );
    } finally {
      _reading.remove(post.id);
    }
  }

  // --- actions; each returns a sentence to show when it fails ---------------

  /// Like, or take the reader's reaction back when they have one already.
  Future<String?> toggleLike(FeedPost post) => react(post, post.myReaction == null ? ReactionKind.like : null);

  /// Reacts with [kind] (changing an earlier reaction), or takes the reaction back when it is null. The card
  /// shows it at once and the API's refusal puts it back.
  Future<String?> react(FeedPost post, ReactionKind? kind) {
    if (post.myReaction == kind) return Future.value(null);
    return _optimistic(post, withReaction(post, kind), () => repository.setReaction(post, kind));
  }

  Future<String?> toggleSave(FeedPost post) =>
      _optimistic(post, post.copyWith(saved: !post.saved), () => repository.setSaved(post, !post.saved));

  Future<String?> follow(FeedPost post) async {
    final before = _posts;
    _posts = [for (final p in _posts) p.author.id == post.author.id ? p.copyWith(showFollow: false) : p];
    notifyListeners();
    try {
      await repository.follow(post.author);
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
      final updated = await repository.vote(post, optionId);
      _replace(_find(post.id)?.copyWith(poll: updated));
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    }
  }

  void toggleReplies(FeedPost post) {
    if (!_open.remove(post.id)) {
      _open.add(post.id);
      if (!post.repliesLoaded) _fetchReplies(post);
    }
    notifyListeners();
  }

  void openReplies(FeedPost post) {
    if (_open.contains(post.id)) return;
    toggleReplies(post);
  }

  Future<void> _fetchReplies(FeedPost post) async {
    _loadingReplies.add(post.id);
    notifyListeners();
    try {
      final replies = await repository.replies(post);
      _replace(_find(post.id)?.copyWith(replies: replies, repliesLoaded: true));
    } catch (_) {
      // Leaves the thread closed-looking; opening it again retries.
    } finally {
      _loadingReplies.remove(post.id);
      notifyListeners();
    }
  }

  Future<String?> sendReply(FeedPost post, String text, {String? parentId}) async {
    if (text.trim().isEmpty) return null;
    try {
      await repository.reply(post, text, parentId: parentId);
      final current = _find(post.id) ?? post;
      _replace(current.copyWith(comments: current.comments + 1));
      await _fetchReplies(current);
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    }
  }

  /// Takes the reader's own reply back (`DELETE /forum/replies/:id`).
  Future<String?> deleteReply(FeedPost post, FeedReply reply) async {
    try {
      await repository.deleteReply(reply);
      final current = _find(post.id) ?? post;
      _replace(current.copyWith(comments: (current.comments - 1).clamp(0, 1 << 30)));
      await _fetchReplies(current);
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    }
  }

  Future<String?> toggleReplyLike(FeedPost post, FeedReply reply) async {
    final like = !reply.liked;
    final current = _find(post.id);
    if (current == null) return null;
    return _optimistic(
      current,
      current.copyWith(
        replies: mapReplies(
          current.replies,
          reply.id,
          (r) => r.copyWith(liked: like, likes: (r.likes + (like ? 1 : -1)).clamp(0, 1 << 30)),
        ),
      ),
      () => repository.setReplyLiked(reply, like),
    );
  }

  /// Takes in a discussion as its own page left it (the reader's reaction, save, poll vote, reply count): the card
  /// shows it, keeping what the list read that the page does not carry (its photos, its text). A thread that is
  /// open and has more or fewer replies than before is read again.
  void adopt(FeedPost page) {
    final current = _find(page.id);
    if (current == null) return;
    final repliesChanged = page.comments != current.comments;
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
    if (repliesChanged && _open.contains(page.id)) _fetchReplies(_find(page.id)!);
  }

  /// Drops a discussion the reader deleted from its page.
  void removePost(String id) {
    _posts = [
      for (final p in _posts)
        if (p.id != id) p,
    ];
    _open.remove(id);
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
}
