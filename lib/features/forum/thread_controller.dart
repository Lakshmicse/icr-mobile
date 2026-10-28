import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import '../feed/feed_models.dart';
import '../feed/forum_json.dart';
import '../feed/post_reactions.dart';
import 'forum_models.dart';
import 'forum_repository.dart';
import 'reply_tree.dart';

/// One discussion's page: the discussion itself, its replies as the forum nests them, and what the reader does to
/// either. Every action shows at once and is put back when the API refuses; each returns the refusal's sentence
/// (or null) for the screen to show, and none throws.
class ThreadController extends ChangeNotifier {
  ThreadController({
    required this.repository,
    required this.slug,
    required this.viewer,
    this.preview,
    this.focusReplyId,
  });

  final ForumRepository repository;
  final String slug;

  /// The reader, as the page draws them (the reply box's photo, "your own" tests).
  final FeedAuthor viewer;

  /// The discussion's card as the list that opened it had it: drawn at once, while the page is read.
  final FeedPost? preview;

  /// A reply a link named (a notification, "Open the whole discussion"): brought into view once it is read.
  final String? focusReplyId;

  /// How many pages of replies a link to one reply reads in search of it, before it gives up.
  static const maxPagesForAReply = 10;

  ForumThread? _thread;
  bool _loading = false;
  String? _error;
  bool _notFound = false;

  List<FeedReply> _replies = const [];
  int _totalReplies = 0;
  bool _repliesLoading = false;
  bool _loadingMoreReplies = false;
  bool _hasMoreReplies = false;
  String? _repliesError;
  int _repliesPage = 0;
  bool _focusFound = false;
  String? _lastSentId;

  bool _viewCounted = false;
  int _generation = 0;
  bool _disposed = false;

  ForumThread? get thread => _thread;

  /// The discussion's card: the page's own when it has been read, else the list's.
  FeedPost? get post => _thread?.card ?? preview;
  bool get loading => _loading;
  String? get error => _error;

  /// The discussion is gone, or never was (404): the page says so instead of offering a retry.
  bool get notFound => _notFound;

  List<FeedReply> get replies => _replies;
  int get totalReplies => _totalReplies;
  bool get repliesLoading => _repliesLoading;
  bool get loadingMoreReplies => _loadingMoreReplies;
  bool get hasMoreReplies => _hasMoreReplies;
  String? get repliesError => _repliesError;

  /// The reply [focusReplyId] names is in the tree now.
  bool get focusFound => _focusFound;

  /// The reply the reader sent last, which the page scrolls to.
  String? get lastSentId => _lastSentId;

  bool get isOwn => post?.author.id == viewer.id;
  bool get isQuestion => post?.kind == ThreadKind.question;
  bool get canModerate => _thread?.canModerate ?? false;

  /// The discussion takes replies: it is open and approved (a moderator may reply to any).
  bool get takesReplies {
    final t = _thread;
    if (t == null) return false;
    if (t.canModerate) return true;
    return t.open && t.moderation == 'APPROVED';
  }

  /// Why a reply cannot be sent, in the forum's words; null when it can.
  String? get lockedReason {
    final t = _thread;
    if (t == null) return null;
    if (takesReplies) return null;
    if (t.moderation != 'APPROVED') return 'This discussion is still awaiting review.';
    return t.status == 'LOCKED'
        ? 'This discussion is locked, so it is not taking new replies.'
        : 'This discussion has been archived.';
  }

  /// Only the asker (or a moderator) marks the answer, and only on a question.
  bool get canAccept => isQuestion && (isOwn || canModerate);

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  // --- reading -----------------------------------------------------------------------------------------------

  /// Reads the discussion, then its replies, and counts the read once.
  Future<void> start() async {
    await _loadThread();
    if (_thread != null) {
      _countView();
      await _loadReplies();
    }
  }

  /// Pull to refresh: the discussion and its replies as the forum holds them now.
  Future<void> refresh() async {
    await _loadThread(keepShown: true);
    if (_thread != null) await _loadReplies();
  }

  Future<void> _loadThread({bool keepShown = false}) async {
    final generation = ++_generation;
    _loading = true;
    _error = null;
    _notFound = false;
    notifyListeners();
    try {
      final read = await repository.thread(slug);
      if (generation != _generation) return;
      _thread = read;
    } catch (e) {
      if (generation != _generation) return;
      final error = ApiError.from(e);
      _notFound = error.statusCode == 404;
      _error = error.message;
      if (!keepShown) _thread = null;
    } finally {
      if (generation == _generation) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  void _countView() {
    final thread = _thread;
    if (_viewCounted || thread == null) return;
    _viewCounted = true;
    // A lost count costs a number, never the read.
    repository.recordView(thread.id).catchError((Object _) {});
  }

  Future<void> _loadReplies() async {
    final thread = _thread;
    if (thread == null || thread.moderation != 'APPROVED') return;
    _repliesLoading = true;
    _repliesError = null;
    notifyListeners();
    try {
      final page = await repository.replies(slug, page: 1);
      _replies = page.replies;
      _totalReplies = page.total;
      _hasMoreReplies = page.hasMore;
      _repliesPage = 1;
      _repliesError = null;
    } catch (e) {
      _repliesError = ApiError.from(e).message;
    } finally {
      _repliesLoading = false;
      notifyListeners();
    }
    await _seekFocus();
  }

  /// The next page of replies, merged under the ones read.
  Future<void> loadMoreReplies() async {
    if (_repliesLoading || _loadingMoreReplies || !_hasMoreReplies) return;
    _loadingMoreReplies = true;
    notifyListeners();
    try {
      final page = await repository.replies(slug, page: _repliesPage + 1);
      _replies = mergeReplyPages(_replies, page.replies);
      _totalReplies = page.total;
      _hasMoreReplies = page.hasMore;
      _repliesPage++;
      _repliesError = null;
    } catch (e) {
      _repliesError = ApiError.from(e).message;
    } finally {
      _loadingMoreReplies = false;
      notifyListeners();
    }
  }

  /// Reads pages until the reply the link named is in the tree (a notification opens a discussion at
  /// `#reply-<id>`, and replies come a page at a time), then tells the screen to bring it into view.
  Future<void> _seekFocus() async {
    final id = focusReplyId;
    if (id == null || _focusFound) return;
    while (findReply(_replies, id) == null && _hasMoreReplies && _repliesPage < maxPagesForAReply && !_disposed) {
      await loadMoreReplies();
      if (_repliesError != null) return;
    }
    if (findReply(_replies, id) != null) {
      _focusFound = true;
      notifyListeners();
    }
  }

  // --- the discussion ----------------------------------------------------------------------------------------

  void _setCard(FeedPost card) {
    final t = _thread;
    if (t == null) return;
    _thread = t.copyWith(card: card);
    notifyListeners();
  }

  Future<String?> _optimisticCard(FeedPost after, Future<void> Function() send) async {
    final t = _thread;
    if (t == null) return null;
    final before = t.card;
    _setCard(after);
    try {
      await send();
      return null;
    } catch (e) {
      // Put back what the card was, keeping anything that changed meanwhile out of it.
      final now = _thread;
      if (now != null) {
        _thread = now.copyWith(card: before);
        notifyListeners();
      }
      return ApiError.from(e).message;
    }
  }

  /// Like, or take the reader's reaction back when they have one.
  Future<String?> toggleLike() => react(post?.myReaction == null ? ReactionKind.like : null);

  /// Reacts with [kind] (changing an earlier one), or takes the reaction back when it is null. A member cannot
  /// react to their own discussion, which the API refuses; the page says so without asking.
  Future<String?> react(ReactionKind? kind) async {
    final card = post;
    final t = _thread;
    if (card == null || t == null) return null;
    if (isOwn) return 'You cannot vote on your own discussion.';
    if (card.myReaction == kind) return null;
    return _optimisticCard(withReaction(card, kind), () => repository.react(card.id, kind));
  }

  Future<String?> toggleSave() {
    final card = post;
    if (card == null || _thread == null) return Future.value(null);
    return _optimisticCard(card.copyWith(saved: !card.saved), () => repository.setSaved(card.id, !card.saved));
  }

  /// Follows the discussion (new replies reach the notifications), or stops.
  Future<String?> toggleSubscribed() async {
    final t = _thread;
    if (t == null) return null;
    final next = !t.subscribed;
    _thread = t.copyWith(subscribed: next);
    notifyListeners();
    try {
      await repository.setSubscribed(t.id, next);
      return null;
    } catch (e) {
      _thread = _thread?.copyWith(subscribed: !next);
      notifyListeners();
      return ApiError.from(e).message;
    }
  }

  /// Follows the discussion's author, or stops.
  Future<String?> toggleFollowAuthor() async {
    final t = _thread;
    if (t == null || isOwn) return null;
    final next = !t.followsAuthor;
    _thread = t.copyWith(followsAuthor: next);
    notifyListeners();
    try {
      await repository.setFollowing(t.card.author.id, next);
      return null;
    } catch (e) {
      _thread = _thread?.copyWith(followsAuthor: !next);
      notifyListeners();
      return ApiError.from(e).message;
    }
  }

  /// Votes in the poll, or moves the vote; the bars follow what the forum answers with.
  Future<String?> votePoll(String optionId) async {
    final t = _thread;
    final poll = t?.card.poll;
    if (t == null || poll == null) return null;
    if (!poll.open || !t.open) return 'This discussion is closed, and so is its poll.';
    if (poll.myOptionId == optionId) return null;
    try {
      final updated = await repository.vote(t.id, optionId, open: poll.open);
      _setCard(t.card.copyWith(poll: updated));
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    }
  }

  /// Takes the discussion down (its author or a moderator); the screen leaves the page when this succeeds.
  Future<String?> deleteThread() async {
    final t = _thread;
    if (t == null) return null;
    try {
      await repository.deleteThread(t.id);
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    }
  }

  /// Who reacted (signed-in members only).
  Future<List<ForumReactor>> reactors() => repository.reactors(post!.id);

  Future<ForumViewersPage> viewers({int page = 1}) => repository.viewers(post!.id, page: page);

  // --- replies -----------------------------------------------------------------------------------------------

  void _setReplies(List<FeedReply> replies) {
    _replies = replies;
    notifyListeners();
  }

  /// Sends a reply (under [parentId] when it answers one). The reply the forum stored joins the tree; a reply
  /// that waits for a moderator is shown to its author, marked, and not counted.
  Future<String?> sendReply(String text, {String? parentId}) async {
    final t = _thread;
    if (t == null) return null;
    if (text.trim().isEmpty) return 'Write something before posting.';
    if (text.trim().length > ForumLimits.replyMax) {
      return 'A reply can be at most ${ForumLimits.replyMax} characters.';
    }
    try {
      final reply = await repository.reply(t.id, text, parentId: parentId);
      _replies = insertReply(_replies, reply);
      _lastSentId = reply.id;
      if (!reply.pending) {
        _totalReplies++;
        _setCard(t.card.copyWith(comments: t.card.comments + 1));
      } else {
        notifyListeners();
      }
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    }
  }

  /// Saves [text] as the words of [reply]. An edit that changes nothing sends nothing (the forum may have the
  /// website editor's formatting, which the app's plain text would flatten).
  Future<String?> editReply(FeedReply reply, String text) async {
    if (text.trim().isEmpty) return 'The reply cannot be emptied. Delete it instead.';
    final before = ForumJson.htmlToText(reply.bodyHtml ?? '');
    if (reply.bodyHtml != null && text.trim() == before) return null;
    try {
      final saved = await repository.editReply(reply.id, text);
      _setReplies(
        mapReplies(
          _replies,
          reply.id,
          (r) => r.copyWith(body: saved.body, bodyHtml: saved.bodyHtml ?? r.bodyHtml, edited: true),
        ),
      );
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    }
  }

  Future<String?> deleteReply(FeedReply reply) async {
    final t = _thread;
    if (t == null) return null;
    try {
      await repository.deleteReply(reply.id);
      _replies = removeReplyKeepAnswers(_replies, reply.id);
      if (!reply.pending) {
        _totalReplies = (_totalReplies - 1).clamp(0, 1 << 30);
        _setCard(t.card.copyWith(comments: (t.card.comments - 1).clamp(0, 1 << 30)));
      } else {
        notifyListeners();
      }
      // A deleted answer stops being the answer.
      if (t.acceptedReplyId == reply.id) {
        _thread = _thread?.copyWith(clearAccepted: true, card: _thread!.card.copyWith(answered: false));
        notifyListeners();
      }
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    }
  }

  /// Likes or unlikes a reply, shown at once. Not one's own: the API refuses, and so does the page.
  Future<String?> toggleReplyLike(FeedReply reply) async {
    if (reply.author.id == viewer.id) return 'You cannot vote on your own reply.';
    final like = !reply.liked;
    final before = _replies;
    _setReplies(
      mapReplies(
        _replies,
        reply.id,
        (r) => r.copyWith(liked: like, likes: (r.likes + (like ? 1 : -1)).clamp(0, 1 << 30)),
      ),
    );
    try {
      await repository.setReplyLiked(reply.id, like);
      return null;
    } catch (e) {
      _setReplies(
        mapReplies(_replies, reply.id, (r) {
          final original = findReply(before, reply.id);
          return r.copyWith(liked: original?.liked ?? reply.liked, likes: original?.likes ?? reply.likes);
        }),
      );
      return ApiError.from(e).message;
    }
  }

  /// Marks [reply] as the answer to a question (the asker, or a moderator).
  Future<String?> accept(FeedReply reply) async {
    final t = _thread;
    if (t == null) return null;
    final before = _replies;
    final beforeAccepted = t.acceptedReplyId;
    _replies = markAccepted(_replies, reply.id);
    _thread = t.copyWith(acceptedReplyId: reply.id, card: t.card.copyWith(answered: true));
    notifyListeners();
    try {
      await repository.accept(t.id, reply.id);
      return null;
    } catch (e) {
      _replies = before;
      _thread = _thread?.copyWith(
        acceptedReplyId: beforeAccepted,
        clearAccepted: beforeAccepted == null,
        card: _thread!.card.copyWith(answered: beforeAccepted != null),
      );
      notifyListeners();
      return ApiError.from(e).message;
    }
  }

  /// Flags the discussion (or one of its replies) for the moderators.
  Future<String?> report({FeedReply? reply, required ReportReason reason, String? note}) async {
    final t = _thread;
    if (t == null) return null;
    try {
      await repository.report(threadId: reply == null ? t.id : null, replyId: reply?.id, reason: reason, note: note);
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    }
  }

  /// The discussion's page on the website, or one of its replies on it, for "Copy link" and Share.
  Uri link({FeedReply? reply}) => repository.link(slug, replyId: reply?.id);

  /// Replaces what the page shows with a discussion just saved (an edit), keeping the replies already read.
  void adoptEdited(ForumThread saved) {
    final old = _thread;
    final card = old?.card;
    _thread = saved.copyWith(
      // What a save answers with carries nothing of the reader's (their reaction, their save, their poll vote)
      // and counts reactions on its own: the page keeps what it had.
      card: card == null
          ? saved.card
          : saved.card.copyWith(
              comments: card.comments,
              saved: card.saved,
              reactions: card.reactions,
              reactionKinds: card.reactionKinds,
              reactionCounts: card.reactionCounts,
              myReaction: card.myReaction,
              clearMyReaction: card.myReaction == null,
              poll: card.poll,
              answered: card.answered,
            ),
      subscribed: old?.subscribed,
      followsAuthor: old?.followsAuthor,
    );
    notifyListeners();
  }
}
