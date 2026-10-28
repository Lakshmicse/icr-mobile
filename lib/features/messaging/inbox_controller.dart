import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import 'messaging_models.dart';
import 'messaging_repository.dart';

/// The inbox: which inbox is on screen (the person's own, or a company's they
/// answer for), its filters, the pinned threads above the rest, the pages read
/// so far, message search, and the person's star, pin and "mark all as read".
class InboxController extends ChangeNotifier {
  InboxController(this.repository, {String? viewerId, DateTime Function()? clock, this.onRead})
    : _viewerId = viewerId,
      clock = clock ?? DateTime.now;

  final MessagingRepository repository;
  final DateTime Function() clock;

  /// Called after something was read here, so the bell and badges can move.
  final VoidCallback? onRead;

  ConversationQuery _query = const ConversationQuery();
  String? _viewerId;
  List<MessagingInbox> _inboxes = const [];
  List<Conversation> _conversations = const [];
  List<Conversation> _pinned = const [];
  List<MessageSearchHit> _hits = const [];
  int _total = 0;
  bool _hasMore = false;
  int _page = 1;
  bool _loading = false;
  bool _loadingMore = false;
  bool _started = false;
  String? _error;
  int _generation = 0;
  bool _disposed = false;
  Timer? _timer;

  ConversationQuery get query => _query;
  String? get viewerId => _viewerId;
  List<MessagingInbox> get inboxes => _inboxes;

  /// The company inboxes; the switcher is hidden while there are none.
  List<MessagingInbox> get companyInboxes => _inboxes.where((i) => !i.personal).toList();
  MessagingInbox? get currentInbox {
    for (final i in _inboxes) {
      if (i.id == _query.inbox) return i;
    }
    return null;
  }

  /// Unread in the other inboxes: the switcher's dot.
  int get unreadElsewhere => _inboxes.where((i) => i.id != _query.inbox).fold(0, (n, i) => n + i.unread);

  /// Unread in the inbox on screen.
  int get unreadHere => currentInbox?.unread ?? _conversations.fold(0, (n, c) => n + c.unread);

  List<Conversation> get conversations => _conversations;

  /// Shown above the list on the personal inbox's All tab, with no search.
  List<Conversation> get pinned => _query.excludePinned ? _pinned : const [];
  List<MessageSearchHit> get hits => _hits;
  int get total => _total;
  bool get hasMore => _hasMore;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  bool get started => _started;
  String? get error => _error;
  bool get searching => _query.search.trim().isNotEmpty;

  Future<void> start() async {
    _started = true;
    await Future.wait([_load(notify: false), _loadInboxes(), _loadViewer()]);
  }

  Future<void> refresh() => Future.wait([_load(notify: true), _loadInboxes()]).then((_) {});

  /// Reloads the first page without a spinner: a poll, or coming back from a thread.
  Future<void> refreshQuietly() => Future.wait([_load(notify: false, quiet: true), _loadInboxes()]).then((_) {});

  void startPolling([Duration every = const Duration(seconds: 30)]) {
    _timer?.cancel();
    _timer = Timer.periodic(every, (_) => refreshQuietly());
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _loadViewer() async {
    if (_viewerId != null) return;
    try {
      _viewerId = await repository.viewerId();
      _notify();
    } catch (_) {}
  }

  Future<void> _loadInboxes() async {
    try {
      _inboxes = await repository.inboxes();
      // An inbox the person no longer answers for falls back to their own.
      if (_query.companyInbox && !_inboxes.any((i) => i.id == _query.inbox)) {
        _query = const ConversationQuery();
        unawaited(_load(notify: true));
      }
      _notify();
    } catch (_) {
      // The switcher is an aid; the list still works without it.
    }
  }

  Future<void> _load({required bool notify, bool quiet = false}) async {
    final generation = ++_generation;
    final query = _query;
    if (!quiet) {
      _loading = true;
      _error = null;
      if (notify) _notify();
    }
    try {
      final term = query.search.trim();
      final results = await Future.wait<Object>([
        repository.conversations(query),
        if (query.excludePinned) repository.pinned() else Future.value(const <Conversation>[]),
        if (term.length >= 2)
          repository.searchMessages(term, inbox: query.inbox)
        else
          Future.value(const <MessageSearchHit>[]),
      ]);
      if (generation != _generation) return;
      final page = results[0] as ConversationPage;
      _conversations = page.conversations;
      _total = page.total;
      _hasMore = page.hasMore;
      _page = 1;
      _pinned = results[1] as List<Conversation>;
      _hits = results[2] as List<MessageSearchHit>;
      _error = null;
    } catch (e) {
      if (generation != _generation) return;
      if (!quiet) _error = ApiError.from(e).message;
    } finally {
      if (generation == _generation) {
        _loading = false;
        _notify();
      }
    }
  }

  Future<void> loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    _loadingMore = true;
    _notify();
    try {
      final page = await repository.conversations(_query, page: _page + 1);
      final known = _conversations.map((c) => c.id).toSet();
      _conversations = [..._conversations, ...page.conversations.where((c) => !known.contains(c.id))];
      _total = page.total;
      _hasMore = page.hasMore;
      _page++;
    } catch (_) {
      // The next tap tries again.
    } finally {
      _loadingMore = false;
      _notify();
    }
  }

  Future<void> _set(ConversationQuery query) async {
    _query = query;
    await _load(notify: true);
  }

  /// Another inbox opens on its first view, with no filter carried over.
  Future<void> setInbox(String inbox) => inbox == _query.inbox ? Future.value() : _set(ConversationQuery(inbox: inbox));

  Future<void> setFilter(InboxFilter filter) => _set(_query.copyWith(filter: filter));

  /// The same kind again clears it.
  Future<void> setKind(InboxKind? kind) =>
      _set(kind == null || kind == _query.kind ? _query.copyWith(clearKind: true) : _query.copyWith(kind: kind));

  Future<void> setView(CompanyInboxView view) => _set(_query.copyWith(view: view));

  Future<void> setTopic(String? topic) =>
      _set(topic == null ? _query.copyWith(clearTopic: true) : _query.copyWith(topic: topic));

  Future<void> setSearch(String search) {
    if (search.trim() == _query.search.trim()) return Future.value();
    return _set(_query.copyWith(search: search.trim()));
  }

  /// "Mark all as read" for the inbox on screen. Moves the badges at once.
  Future<String?> markAllRead() async {
    final beforeConversations = _conversations;
    final beforePinned = _pinned;
    final beforeInboxes = _inboxes;
    _conversations = [for (final c in _conversations) c.copyWith(unread: 0)];
    _pinned = [for (final c in _pinned) c.copyWith(unread: 0)];
    _inboxes = [
      for (final i in _inboxes)
        i.id == _query.inbox
            ? MessagingInbox(id: i.id, personal: i.personal, name: i.name, logo: i.logo, topics: i.topics, unread: 0)
            : i,
    ];
    _notify();
    try {
      await repository.markAllRead(inbox: _query.inbox);
      onRead?.call();
      if (_query.filter == InboxFilter.unread || _query.view == CompanyInboxView.unread) unawaited(refreshQuietly());
      return null;
    } catch (e) {
      _conversations = beforeConversations;
      _pinned = beforePinned;
      _inboxes = beforeInboxes;
      _notify();
      return ApiError.from(e).message;
    }
  }

  /// A thread the person just read: its row loses its count.
  void markedRead(String conversationId) {
    _conversations = [for (final c in _conversations) c.id == conversationId ? c.copyWith(unread: 0) : c];
    _pinned = [for (final c in _pinned) c.id == conversationId ? c.copyWith(unread: 0) : c];
    _notify();
  }

  Future<String?> toggleStar(Conversation c) => _preference(c, starred: !c.starred);

  /// Pinning moves the thread between the pinned list and the rest.
  Future<String?> togglePin(Conversation c) => _preference(c, pinned: !c.pinned);

  Future<String?> _preference(Conversation c, {bool? starred, bool? pinned}) async {
    final beforeConversations = _conversations;
    final beforePinned = _pinned;
    Conversation apply(Conversation x) => x.id == c.id ? x.copyWith(starred: starred, pinned: pinned) : x;
    _conversations = _conversations.map(apply).toList();
    _pinned = _pinned.map(apply).toList();
    if (pinned != null && _query.excludePinned) {
      final moved = c.copyWith(starred: starred, pinned: pinned);
      if (pinned) {
        _conversations = _conversations.where((x) => x.id != c.id).toList();
        _pinned = [moved, ..._pinned.where((x) => x.id != c.id)];
      } else {
        _pinned = _pinned.where((x) => x.id != c.id).toList();
        _conversations = [moved, ..._conversations.where((x) => x.id != c.id)]
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      }
    }
    _notify();
    try {
      await repository.setPreference(c.id, starred: starred, pinned: pinned);
      if (starred != null && _query.filter == InboxFilter.starred) unawaited(refreshQuietly());
      return null;
    } catch (e) {
      _conversations = beforeConversations;
      _pinned = beforePinned;
      _notify();
      return ApiError.from(e).message;
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    stopPolling();
    super.dispose();
  }
}
