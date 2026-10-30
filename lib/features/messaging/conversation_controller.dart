import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import 'messaging_format.dart';
import 'messaging_models.dart';
import 'messaging_repository.dart';

/// A message the person sent that the API has not taken yet, or refused.
class PendingMessage {
  PendingMessage({required this.localId, required this.body, required this.at, this.attachment, this.replyTo});

  final String localId;
  final String body;
  final UploadedAttachment? attachment;
  final ChatMessage? replyTo;
  final DateTime at;
  bool failed = false;
  String? error;
}

/// One row of an open thread, in order: a day, a message, a business event, or
/// a message on its way.
sealed class ThreadItem {
  const ThreadItem();
}

class DayItem extends ThreadItem {
  const DayItem(this.date);
  final DateTime date;
}

class MessageItem extends ThreadItem {
  const MessageItem(this.message, {required this.continued});
  final ChatMessage message;

  /// Same sender as the row above, within five minutes: drawn without the name.
  final bool continued;
}

class EventItem extends ThreadItem {
  const EventItem(this.event);
  final ThreadEvent event;
}

class PendingItem extends ThreadItem {
  const PendingItem(this.pending);
  final PendingMessage pending;
}

/// Consecutive messages from one person this close together read as one block.
const groupWindow = Duration(minutes: 5);

/// The words half-written in each conversation's box, kept in memory for the life of the app so a thread
/// left and opened again finds them where they were. The screen writes a second after typing stops and on
/// leaving, and clears it on send.
abstract final class DraftStore {
  static final _drafts = <String, String>{};

  /// The draft kept for [conversationId], if any.
  static String? of(String conversationId) => _drafts[conversationId];

  static bool has(String conversationId) => _drafts.containsKey(conversationId);

  /// Keeps [text] as the draft; an empty box keeps nothing.
  static void save(String conversationId, String text) {
    if (text.trim().isEmpty) {
      _drafts.remove(conversationId);
    } else {
      _drafts[conversationId] = text;
    }
  }

  static void clear(String conversationId) => _drafts.remove(conversationId);

  /// Forgets every draft (tests, sign-out).
  static void clearAll() => _drafts.clear();
}

/// An open conversation: the newest window of messages and older pages as the
/// person scrolls back, new ones caught up by a poll every few seconds while
/// the screen is open, sending (with retry), a file uploaded before it is
/// sent, a reply, read receipts, star and pin, withdrawing and reporting a
/// message, and a company inbox's sorting. Every write moves the screen at
/// once and is put back if the API refuses it.
class ConversationController extends ChangeNotifier {
  ConversationController(
    this.repository, {
    required this.conversationId,
    this.asCompanyId,
    Conversation? initial,
    String? viewerId,
    this.pollInterval = const Duration(seconds: 4),
    DateTime Function()? clock,
    this.onRead,
  }) : _conversation = initial,
       _viewerId = viewerId,
       clock = clock ?? DateTime.now;

  final MessagingRepository repository;
  final String conversationId;

  /// Read from this company's inbox (the one the thread was opened from).
  final String? asCompanyId;
  final Duration pollInterval;
  final DateTime Function() clock;

  /// Called after the thread was read, so the bell and the inbox badge can move.
  final VoidCallback? onRead;

  Conversation? _conversation;
  ConversationContext? _context;
  String? _viewerId;
  List<ChatMessage> _messages = const [];
  final List<PendingMessage> _pending = [];
  MessageSeen? _seen;
  bool _hasMore = false;
  bool _loaded = false;
  bool _loading = false;
  bool _loadingOlder = false;
  String? _error;
  bool _cannotOpen = false;
  ChatMessage? _replyTo;
  UploadedAttachment? _attachment;
  String? _uploadingName;
  Timer? _timer;
  bool _polling = false;
  bool _disposed = false;
  int _localIds = 0;
  final _bytes = <String, Future<Uint8List>>{};
  final _records = <RecordRef, Future<RecordFacts>>{};

  Conversation? get conversation => _conversation;
  ConversationContext? get context => _context;
  String? get viewerId => _viewerId;
  List<ChatMessage> get messages => _messages;
  List<PendingMessage> get pending => List.unmodifiable(_pending);
  MessageSeen? get seen => _seen;
  bool get hasMore => _hasMore;
  bool get loaded => _loaded;
  bool get loading => _loading;
  bool get loadingOlder => _loadingOlder;
  String? get error => _error;

  /// The thread is not the person's (another account's, or they left it).
  bool get cannotOpen => _cannotOpen;
  ChatMessage? get replyTo => _replyTo;
  UploadedAttachment? get attachment => _attachment;
  bool get uploading => _uploadingName != null;
  String? get uploadingName => _uploadingName;
  bool get polling => _timer != null;

  /// The side the person reads the thread as.
  String? get side => _conversation?.asCompanyId ?? asCompanyId;

  /// How the header names the thread: the context's kind and company once loaded.
  ConversationDisplay get display {
    final c = _conversation;
    final ctx = _context;
    return conversationDisplay(
      participants: c?.participants ?? const [],
      meId: _viewerId,
      title: c?.title,
      kind: ctx?.kind ?? c?.kind,
      counterpartCompany: ctx != null ? ctx.company?.ref : c?.counterpartCompany,
      contextLabel: ctx?.requirement?.title ?? ctx?.groupSession?.title ?? ctx?.consultation?.title ?? c?.contextLabel,
    );
  }

  /// The company inbox the person answers this thread in, when they do.
  ThreadParty? get myParty => _conversation?.myParty;

  bool isMine(ChatMessage m) => m.fromMySide(_viewerId, side);

  /// "Seen" goes under this message: the newest of the person's the other side read.
  String? get seenMessageId => _seen?.messageId;

  Future<void> start() {
    // Who "me" is names the header from the inbox row at once, without waiting for the thread.
    if (_viewerId == null) unawaited(_resolveViewer());
    return _load(notify: false);
  }

  Future<void> _resolveViewer() async {
    try {
      final id = await repository.viewerId();
      if (_viewerId != null) return;
      _viewerId = id;
      _notify();
    } catch (_) {
      // The thread's own read asks again.
    }
  }

  Future<void> retry() => _load(notify: true);

  Future<void> _load({required bool notify}) async {
    _loading = true;
    _error = null;
    _cannotOpen = false;
    if (notify) notifyListeners();
    try {
      final results = await Future.wait([
        repository.thread(conversationId, asCompanyId: asCompanyId),
        if (_viewerId == null) repository.viewerId(),
      ]);
      final window = results[0] as ThreadWindow;
      if (results.length > 1) _viewerId = results[1] as String;
      _conversation = _keepListFacts(window.conversation);
      _messages = window.messages;
      _hasMore = window.hasMore;
      _seen = window.seen;
      _loaded = true;
      unawaited(_markRead());
      unawaited(_loadContext());
    } catch (e) {
      final error = ApiError.from(e);
      _cannotOpen = error.statusCode == 403 || error.statusCode == 404;
      _error = _cannotOpen ? "You can't open this conversation" : 'Unable to load this conversation.';
    } finally {
      _loading = false;
      _notify();
    }
  }

  /// The detail read has no kind or counterpart; the list row it was opened from does.
  Conversation _keepListFacts(Conversation fresh) {
    final known = _conversation;
    if (known == null) return fresh;
    return fresh.copyWith(
      kind: fresh.kind ?? known.kind,
      counterpartCompany: fresh.counterpartCompany ?? known.counterpartCompany,
      contextLabel: fresh.contextLabel ?? known.contextLabel,
    );
  }

  Future<void> _loadContext() async {
    try {
      _context = await repository.context(conversationId, asCompanyId: side);
      _notify();
    } catch (_) {
      // The header falls back on the list's copy of the thread.
    }
  }

  Future<void> _markRead() async {
    try {
      await repository.markRead(conversationId, asCompanyId: side);
      final now = clock();
      _messages = [for (final m in _messages) !isMine(m) && m.readAt == null ? _read(m, now) : m];
      _conversation = _conversation?.copyWith(unread: 0);
      onRead?.call();
      _notify();
    } catch (_) {
      // Read again on the next poll that brings something new.
    }
  }

  ChatMessage _read(ChatMessage m, DateTime at) => ChatMessage(
    id: m.id,
    conversationId: m.conversationId,
    senderId: m.senderId,
    sender: m.sender,
    senderCompany: m.senderCompany,
    body: m.body,
    attachmentUrl: m.attachmentUrl,
    attachmentName: m.attachmentName,
    attachmentSize: m.attachmentSize,
    attachmentMime: m.attachmentMime,
    replyTo: m.replyTo,
    readAt: at,
    deletedAt: m.deletedAt,
    createdAt: m.createdAt,
  );

  // --- paging and live updates ---------------------------------------------

  /// "Load earlier messages": the page before the oldest one held.
  Future<void> loadOlder() async {
    if (!_hasMore || _loadingOlder || _messages.isEmpty) return;
    _loadingOlder = true;
    _notify();
    try {
      final page = await repository.older(conversationId, _messages.first.id, asCompanyId: side);
      _messages = _merge(page.messages, _messages);
      _hasMore = page.hasMore;
    } catch (_) {
      // The next scroll to the top tries again.
    } finally {
      _loadingOlder = false;
      _notify();
    }
  }

  /// Pages back until [messageId] is held: a search hit or a notification can name a
  /// message older than the newest window. False when the thread does not have it.
  Future<bool> ensureLoaded(String messageId, {int maxPages = 20}) async {
    for (var page = 0; page < maxPages; page++) {
      if (_messages.any((m) => m.id == messageId)) return true;
      if (!_hasMore || _messages.isEmpty) return false;
      final before = _messages.length;
      await loadOlder();
      if (_messages.length == before) return false;
    }
    return _messages.any((m) => m.id == messageId);
  }

  /// Polls for new messages every [pollInterval] while the screen is open.
  void startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(pollInterval, (_) => poll());
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  /// Catches up with what was sent since the newest message held, and with
  /// the other side reading the person's own.
  Future<void> poll() async {
    if (!_loaded || _polling || _disposed) return;
    _polling = true;
    try {
      List<ChatMessage> fresh;
      MessageSeen? seen;
      if (_messages.isEmpty) {
        final window = await repository.thread(conversationId, asCompanyId: side);
        fresh = window.messages;
        seen = window.seen;
      } else {
        final page = await repository.newer(conversationId, _messages.last.id, asCompanyId: side);
        fresh = page.messages;
        seen = page.seen;
      }
      if (_disposed) return;
      final known = _messages.map((m) => m.id).toSet();
      final arrived = fresh.where((m) => !known.contains(m.id)).toList();
      final changed = arrived.isNotEmpty || seen?.messageId != _seen?.messageId;
      _messages = _merge(_messages, fresh);
      _seen = seen ?? _seen;
      if (changed) _notify();
      if (arrived.any((m) => !isMine(m))) await _markRead();
    } catch (_) {
      // A missed poll is caught up by the next one.
    } finally {
      _polling = false;
    }
  }

  static List<ChatMessage> _merge(List<ChatMessage> a, List<ChatMessage> b) {
    final byId = <String, ChatMessage>{for (final m in a) m.id: m, for (final m in b) m.id: m};
    final list = byId.values.toList()
      ..sort((x, y) {
        final at = x.createdAt.compareTo(y.createdAt);
        return at != 0 ? at : x.id.compareTo(y.id);
      });
    return list;
  }

  /// Days, messages, the thread's business events and what is on its way, in order.
  List<ThreadItem> get timeline {
    final floor = _hasMore && _messages.isNotEmpty ? _messages.first.createdAt : null;
    final events = (_context?.events ?? const <ThreadEvent>[]).where((e) => floor == null || !e.at.isBefore(floor));
    final entries = <(DateTime, Object)>[for (final m in _messages) (m.createdAt, m), for (final e in events) (e.at, e)]
      ..sort((a, b) => a.$1.compareTo(b.$1));

    final items = <ThreadItem>[];
    DateTime? lastDay;
    ChatMessage? previous;
    for (final (at, entry) in entries) {
      if (lastDay == null || !sameDay(lastDay, at)) {
        items.add(DayItem(at));
        lastDay = at;
        previous = null;
      }
      if (entry is ThreadEvent) {
        items.add(EventItem(entry));
        previous = null;
        continue;
      }
      final m = entry as ChatMessage;
      final continued =
          previous != null &&
          previous.senderId == m.senderId &&
          previous.senderCompany?.id == m.senderCompany?.id &&
          !previous.deleted &&
          m.replyTo == null &&
          m.createdAt.difference(previous.createdAt) <= groupWindow;
      items.add(MessageItem(m, continued: continued));
      previous = m;
    }
    if (_pending.isNotEmpty) {
      final now = clock();
      if (lastDay == null || !sameDay(lastDay, now)) items.add(DayItem(now));
      items.addAll(_pending.map(PendingItem.new));
    }
    return items;
  }

  // --- writing --------------------------------------------------------------

  void setReplyTo(ChatMessage? message) {
    _replyTo = message;
    _notify();
  }

  /// Uploads a file to send with the next message. A sentence when it cannot.
  Future<String?> attach(PickedAttachment file) async {
    if (file.size > attachmentMaxBytes) return 'That file is over 10 MB.';
    if (attachmentMimeFor(file.name, file.mimeType) == null) {
      return "That kind of file can't be sent. Send a photo, a PDF or an Office document.";
    }
    _uploadingName = file.name;
    _notify();
    try {
      _attachment = await repository.upload(file);
      return null;
    } catch (e) {
      final error = ApiError.from(e);
      return error.statusCode == null ? error.message : "The file couldn't be uploaded. ${error.message}";
    } finally {
      _uploadingName = null;
      _notify();
    }
  }

  void removeAttachment() {
    _attachment = null;
    _notify();
  }

  /// Why [text] cannot be sent as it stands, or null.
  String? problemWith(String text) {
    if (text.trim().isEmpty && _attachment == null) return 'Write a message or attach a file.';
    if (text.length > messageBodyMax) return 'A message can be at most $messageBodyMax characters.';
    return null;
  }

  /// Sends [text] (with the attached file and the reply, if any). The message
  /// shows at once as "Sending…"; a refusal leaves it in the thread with
  /// Retry, and returns the API's sentence.
  Future<String?> send(String text) async {
    final problem = problemWith(text);
    if (problem != null) return problem;
    final pending = PendingMessage(
      localId: 'pending-${_localIds++}',
      body: text.trim(),
      attachment: _attachment,
      replyTo: _replyTo,
      at: clock(),
    );
    _pending.add(pending);
    _attachment = null;
    _replyTo = null;
    _notify();
    return _deliver(pending);
  }

  Future<String?> _deliver(PendingMessage p) async {
    try {
      final message = await repository.send(
        conversationId,
        body: p.body,
        attachmentUrl: p.attachment?.url,
        replyToId: p.replyTo?.id,
        asCompanyId: side,
      );
      _pending.remove(p);
      _messages = _merge(_messages, [message]);
      _conversation = _conversation?.copyWith(lastMessage: message, updatedAt: message.createdAt);
      _notify();
      return null;
    } catch (e) {
      p
        ..failed = true
        ..error = ApiError.from(e).message;
      _notify();
      return p.error;
    }
  }

  Future<String?> retrySend(PendingMessage p) {
    p
      ..failed = false
      ..error = null;
    _notify();
    return _deliver(p);
  }

  /// Drops a message that was not sent; returns its words, for the composer.
  String discard(PendingMessage p) {
    _pending.remove(p);
    if (p.attachment != null && _attachment == null) _attachment = p.attachment;
    _notify();
    return p.body;
  }

  /// Withdraws one of the person's own messages, for everyone in the thread.
  Future<String?> delete(ChatMessage message) async {
    final before = _messages;
    final at = clock();
    _messages = [
      for (final m in _messages)
        if (m.id == message.id) m.asDeleted(at) else if (m.replyTo?.id == message.id) m.withReplyDeleted() else m,
    ];
    _notify();
    try {
      await repository.deleteMessage(conversationId, message.id);
      return null;
    } catch (e) {
      _messages = before;
      _notify();
      return ApiError.from(e).message;
    }
  }

  Future<String?> report(ChatMessage message, String reason, {String? note}) async {
    try {
      await repository.report(message.id, reason, note: note);
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    }
  }

  Future<String?> toggleStar() => _preference(starred: !(_conversation?.starred ?? false));

  Future<String?> togglePin() => _preference(pinned: !(_conversation?.pinned ?? false));

  Future<String?> _preference({bool? starred, bool? pinned}) async {
    final before = _conversation;
    if (before == null) return null;
    _conversation = before.copyWith(starred: starred, pinned: pinned);
    _notify();
    try {
      final saved = await repository.setPreference(conversationId, starred: starred, pinned: pinned);
      _conversation = _conversation?.copyWith(starred: saved.starred, pinned: saved.pinned);
      _notify();
      return null;
    } catch (e) {
      _conversation = before;
      _notify();
      return ApiError.from(e).message;
    }
  }

  /// A company inbox's sorting: done, spam, back to open.
  Future<String?> setStatus(ThreadStatus status) => _company((p) => p.copyWith(status: status), status: status);

  Future<String?> assignToMe() async {
    final me = _viewerId;
    if (me == null) return null;
    ChatPerson? person;
    for (final p in _conversation?.participants ?? const <ChatPerson>[]) {
      if (p.id == me) person = p;
    }
    return _company(
      (p) => p.copyWith(
        assignee: person ?? ChatPerson(id: me, firstName: 'You', lastName: ''),
      ),
      assigneeId: me,
    );
  }

  Future<String?> unassign() => _company((p) => p.copyWith(clearAssignee: true), unassign: true);

  Future<String?> _company(
    ThreadParty Function(ThreadParty) change, {
    ThreadStatus? status,
    String? assigneeId,
    bool unassign = false,
  }) async {
    final party = myParty;
    final before = _conversation;
    if (party == null || before == null) return null;
    _conversation = before.copyWith(
      parties: [for (final p in before.parties) p.companyId == party.companyId ? change(p) : p],
    );
    _notify();
    try {
      final saved = await repository.updateCompanyThread(
        conversationId,
        companyId: party.companyId,
        status: status,
        assigneeId: assigneeId,
        unassign: unassign,
      );
      _conversation = _conversation?.copyWith(
        parties: [for (final p in _conversation!.parties) p.companyId == saved.companyId ? saved : p],
      );
      _notify();
      return null;
    } catch (e) {
      _conversation = before;
      _notify();
      return ApiError.from(e).message;
    }
  }

  /// A private attachment's bytes (images are drawn from them), read once.
  Future<Uint8List> attachmentBytes(String url) => _bytes.putIfAbsent(url, () {
    final future = repository.download(url);
    future.catchError((Object _) {
      _bytes.remove(url);
      return Uint8List(0);
    });
    return future;
  });

  /// A shared record's card facts, read once through the record's own endpoint
  /// (a refusal stays cached: the card says "isn't available to you").
  Future<RecordFacts> record(RecordRef ref) => _records.putIfAbsent(ref, () => repository.record(ref));

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
