/// Stand-ins shared by the notifications and messaging tests.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/auth/token_store.dart';
import 'package:icr_mobile/features/messaging/messaging_models.dart';
import 'package:icr_mobile/features/messaging/messaging_repository.dart';

class FixedTokens extends TokenStore {
  @override
  Future<String?> accessToken() async => 'token';
  @override
  Future<String?> refreshToken() async => null;
}

/// Answers each route from a table and records the calls: the way the API's
/// real JSON reaches a repository in a test.
class TableAdapter implements HttpClientAdapter {
  TableAdapter(this.routes);

  /// `'GET /notifications'` to what it answers: a JSON-able value, or `(status, body)`.
  final Map<String, Object Function(RequestOptions options)> routes;
  final List<RequestOptions> requests = [];

  List<String> get calls => [for (final o in requests) '${o.method} ${o.path}'];

  /// The last request to [route].
  RequestOptions last(String route) =>
      requests.lastWhere((o) => '${o.method} ${o.path}' == route, orElse: () => throw StateError('no call to $route'));

  Map<String, dynamic> queryOf(String route) => last(route).queryParameters;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final handler = routes['${options.method} ${options.path}'];
    if (handler == null) return ResponseBody.fromString('{"message":"Not found"}', 404, headers: _json);
    final result = handler(options);
    if (result is (int, String)) return ResponseBody.fromString(result.$2, result.$1, headers: _json);
    return ResponseBody.fromString(jsonEncode(result), 200, headers: _json);
  }

  static final _json = {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  };

  @override
  void close({bool force = false}) {}
}

/// An [ApiClient] that talks to [adapter] instead of the network.
ApiClient clientFor(TableAdapter adapter) {
  final client = ApiClient(tokens: FixedTokens(), baseUrl: 'http://api.test/api/v1');
  client.dio.httpClientAdapter = adapter;
  return client;
}

// --- people, messages and conversations in one line --------------------------------------------------------------

const meId = 'me';
const me = ChatPerson(id: meId, firstName: 'Bharat', lastName: 'Buyer');
const sarah = ChatPerson(id: 'sarah', firstName: 'Sarah', lastName: 'Jenkins');
const david = ChatPerson(id: 'david', firstName: 'David', lastName: 'Chen');
const priya = ChatPerson(id: 'priya', firstName: 'Priya', lastName: 'Sharma');
const globalInfra = ChatCompany(id: 'co-gi', name: 'Global Infra Solutions');
const careSupplier = ChatCompany(id: 'co-care', name: 'Bengaluru Care 101');

/// The clock the screens' tests keep: Sunday 25 Oct 2026, 15:00.
final testNow = DateTime(2026, 10, 25, 15);

DateTime minutesAgo(int minutes) => testNow.subtract(Duration(minutes: minutes));

ChatMessage msg(
  String id,
  String conversationId,
  ChatPerson from,
  String body, {
  int ago = 10,
  bool read = false,
  ChatCompany? company,
  String? attachment,
  String? attachmentMime,
  int? attachmentSize,
  MessageReply? replyTo,
  bool deleted = false,
}) => ChatMessage(
  id: id,
  conversationId: conversationId,
  senderId: from.id,
  sender: from,
  senderCompany: company,
  body: deleted ? '' : body,
  attachmentUrl: attachment == null || deleted ? null : '/uploads/$attachment',
  attachmentName: attachment == null || deleted ? null : attachment,
  attachmentSize: attachmentSize,
  attachmentMime: attachmentMime,
  replyTo: replyTo,
  createdAt: minutesAgo(ago),
  readAt: read ? minutesAgo(ago - 1) : null,
  deletedAt: deleted ? minutesAgo(ago - 2) : null,
);

Conversation convo(
  String id, {
  List<ChatPerson> people = const [me, sarah],
  ChatMessage? last,
  int unread = 0,
  bool starred = false,
  bool pinned = false,
  ConversationKind? kind = ConversationKind.direct,
  String? title,
  String? contextLabel,
  ChatCompany? counterpart,
  List<ThreadParty> parties = const [],
  String? asCompanyId,
  int updatedAgo = 10,
}) => Conversation(
  id: id,
  title: title,
  participants: people,
  lastMessage: last,
  unread: unread,
  starred: starred,
  pinned: pinned,
  kind: kind,
  contextLabel: contextLabel,
  counterpartCompany: counterpart,
  parties: parties,
  asCompanyId: asCompanyId,
  updatedAt: minutesAgo(updatedAgo),
);

/// A repository the test steers: what it answers, what it refuses, and when it answers.
///
/// Every call is written to [calls] as `name arg=value`. Put an [ApiError] in
/// [errors] under a method's name to make it refuse, and a [Completer] in
/// [holds] to make it wait (a test can then look at the screen "in flight").
class FakeMessagingRepository implements MessagingRepository {
  FakeMessagingRepository({
    List<Conversation>? rows,
    Map<String, List<ChatMessage>>? threads,
    Map<String, ConversationContext>? contexts,
    List<MessagingInbox>? inboxList,
    this.pageSize = 25,
  }) : rows = List.of(rows ?? const []),
       threads = {for (final e in (threads ?? const <String, List<ChatMessage>>{}).entries) e.key: List.of(e.value)},
       contexts = Map.of(contexts ?? const {}),
       inboxList = inboxList ?? [const MessagingInbox(id: MessagingInbox.personalId, personal: true, unread: 0)];

  List<Conversation> rows;
  final Map<String, List<ChatMessage>> threads;
  final Map<String, ConversationContext> contexts;
  List<MessagingInbox> inboxList;
  final int pageSize;

  final calls = <String>[];
  final errors = <String, ApiError>{};
  final holds = <String, Completer<void>>{};

  /// What each `send` was given.
  final sent =
      <({String conversationId, String body, String? attachmentUrl, String? replyToId, String? asCompanyId})>[];
  final uploads = <PickedAttachment>[];
  final reports = <({String messageId, String reason, String? note})>[];

  /// Who "seen" points at in a thread (the other side read up to there).
  final seenAt = <String, MessageSeen>{};
  var _ids = 0;

  /// The thread the `start…` and `openFor…` calls answer with.
  String startAnswer = 'conv-started';
  Recipients recipientsAnswer = const Recipients();
  final recordAnswers = <RecordRef, RecordFacts>{};
  final searchRecordsAnswers = <RecordType, List<RecordFacts>>{};
  List<MessageSearchHit> hits = const [];
  Uint8List downloadAnswer = Uint8List.fromList([1, 2, 3]);

  Future<void> _enter(String name, [String detail = '']) async {
    calls.add(detail.isEmpty ? name : '$name $detail');
    final hold = holds[name];
    if (hold != null) await hold.future;
    final error = errors[name];
    if (error != null) throw error;
  }

  /// How many list pages were asked for.
  int get listCalls => calls.where((c) => c.startsWith('conversations')).length;

  @override
  Future<String> viewerId() async => meId;

  @override
  Future<List<MessagingInbox>> inboxes() async {
    await _enter('inboxes');
    return inboxList;
  }

  bool _matches(Conversation c, ConversationQuery q) {
    if (q.companyInbox ? c.asCompanyId != q.inbox : c.asCompanyId != null) return false;
    if (q.excludePinned && c.pinned) return false;
    if (!q.companyInbox) {
      if (q.filter == InboxFilter.unread && c.unread == 0) return false;
      if (q.filter == InboxFilter.starred && !c.starred) return false;
      final k = c.kind;
      switch (q.kind) {
        case InboxKind.requirement:
          if (!(k?.isRequirement ?? false)) return false;
        case InboxKind.mentorship:
          if (k != ConversationKind.mentorship &&
              k != ConversationKind.groupSession &&
              k != ConversationKind.consultation) {
            return false;
          }
        case InboxKind.direct:
          if (k != ConversationKind.direct && k != ConversationKind.company) return false;
        case null:
      }
    } else {
      final party = c.parties.where((p) => p.companyId == q.inbox).firstOrNull;
      switch (q.view) {
        case CompanyInboxView.open:
          if (party?.status != ThreadStatus.open) return false;
        case CompanyInboxView.unread:
          if (c.unread == 0) return false;
        case CompanyInboxView.mine:
          if (party?.assignee == null) return false;
        case CompanyInboxView.done:
          if (party?.status != ThreadStatus.done) return false;
        case CompanyInboxView.spam:
          if (party?.status != ThreadStatus.spam) return false;
      }
      if (q.topic != null && party?.topic != q.topic) return false;
    }
    final term = q.search.trim().toLowerCase();
    if (term.isNotEmpty) {
      final hay = [
        c.title ?? '',
        c.contextLabel ?? '',
        c.counterpartCompany?.name ?? '',
        for (final p in c.participants) p.fullName,
      ].join(' ').toLowerCase();
      if (!hay.contains(term)) return false;
    }
    return true;
  }

  @override
  Future<ConversationPage> conversations(ConversationQuery query, {int page = 1}) async {
    await _enter(
      'conversations',
      'page=$page inbox=${query.inbox} filter=${query.filter.name} kind=${query.kind?.name} search="${query.search}" '
          'view=${query.view.name} topic=${query.topic} excludePinned=${query.excludePinned}',
    );
    final matching = rows.where((c) => _matches(c, query)).toList();
    final from = (page - 1) * pageSize;
    return ConversationPage(
      conversations: matching.skip(from).take(pageSize).toList(),
      total: matching.length,
      hasMore: from + pageSize < matching.length,
    );
  }

  @override
  Future<List<Conversation>> pinned() async {
    await _enter('pinned');
    return rows.where((c) => c.pinned && c.asCompanyId == null).toList();
  }

  @override
  Future<List<MessageSearchHit>> searchMessages(String q, {String? inbox}) async {
    await _enter('search', 'q="$q" inbox=$inbox');
    return hits;
  }

  @override
  Future<MessagingUnread> unreadCount() async {
    await _enter('unreadCount');
    final n = rows.fold(0, (a, c) => a + c.unread);
    return MessagingUnread(count: n, personal: n);
  }

  @override
  Future<int> markAllRead({String? inbox}) async {
    await _enter('markAllRead', 'inbox=$inbox');
    final n = rows.fold(0, (a, c) => a + c.unread);
    rows = [for (final c in rows) c.copyWith(unread: 0)];
    inboxList = [
      for (final i in inboxList)
        i.id == (inbox ?? MessagingInbox.personalId)
            ? MessagingInbox(id: i.id, personal: i.personal, name: i.name, topics: i.topics, unread: 0)
            : i,
    ];
    return n;
  }

  List<ChatMessage> _thread(String id) => threads[id] ?? const [];

  Conversation _row(String id) =>
      rows.where((c) => c.id == id).firstOrNull ??
      (throw ApiError('This conversation could not be found.', statusCode: 404));

  @override
  Future<ThreadWindow> thread(String conversationId, {int take = 50, String? asCompanyId}) async {
    await _enter('thread', '$conversationId take=$take as=$asCompanyId');
    final all = _thread(conversationId);
    final start = all.length > take ? all.length - take : 0;
    final row = _row(conversationId);
    // The detail read carries no kind, counterpart or label: the list row does.
    final detail = Conversation(
      id: row.id,
      title: row.title,
      participants: row.participants,
      updatedAt: row.updatedAt,
      starred: row.starred,
      pinned: row.pinned,
      parties: row.parties,
      asCompanyId: row.asCompanyId,
    );
    return ThreadWindow(
      conversation: detail,
      messages: all.sublist(start),
      hasMore: start > 0,
      seen: seenAt[conversationId],
    );
  }

  @override
  Future<MessageWindow> older(String conversationId, String beforeId, {int take = 50, String? asCompanyId}) async {
    await _enter('older', '$conversationId before=$beforeId take=$take');
    final all = _thread(conversationId);
    final index = all.indexWhere((m) => m.id == beforeId);
    if (index <= 0) return const MessageWindow(messages: [], hasMore: false);
    final start = index > take ? index - take : 0;
    return MessageWindow(messages: all.sublist(start, index), hasMore: start > 0, seen: seenAt[conversationId]);
  }

  @override
  Future<MessageWindow> newer(String conversationId, String afterId, {String? asCompanyId}) async {
    await _enter('newer', '$conversationId after=$afterId');
    final all = _thread(conversationId);
    final index = all.indexWhere((m) => m.id == afterId);
    return MessageWindow(
      messages: index < 0 ? const [] : all.sublist(index + 1),
      hasMore: false,
      seen: seenAt[conversationId],
    );
  }

  @override
  Future<ConversationContext?> context(String conversationId, {String? asCompanyId}) async {
    await _enter('context', '$conversationId as=$asCompanyId');
    return contexts[conversationId];
  }

  /// A message arrives from the other side (what a poll will find).
  ChatMessage arrive(String conversationId, ChatPerson from, String body, {ChatCompany? company, DateTime? at}) {
    final m = ChatMessage(
      id: 'arrived-${_ids++}',
      conversationId: conversationId,
      senderId: from.id,
      sender: from,
      senderCompany: company,
      body: body,
      createdAt: at ?? testNow.add(Duration(minutes: _ids)),
    );
    threads[conversationId] = [..._thread(conversationId), m];
    return m;
  }

  @override
  Future<ChatMessage> send(
    String conversationId, {
    required String body,
    String? attachmentUrl,
    String? replyToId,
    String? asCompanyId,
  }) async {
    await _enter('send', '$conversationId body="$body" file=$attachmentUrl reply=$replyToId as=$asCompanyId');
    sent.add((
      conversationId: conversationId,
      body: body,
      attachmentUrl: attachmentUrl,
      replyToId: replyToId,
      asCompanyId: asCompanyId,
    ));
    final quoted = replyToId == null ? null : _thread(conversationId).where((m) => m.id == replyToId).firstOrNull;
    final up = _uploaded[attachmentUrl];
    final m = ChatMessage(
      id: 'sent-${_ids++}',
      conversationId: conversationId,
      senderId: meId,
      sender: me,
      senderCompany: asCompanyId == null ? null : ChatCompany(id: asCompanyId, name: 'Acme'),
      body: body,
      attachmentUrl: attachmentUrl,
      attachmentName: up?.name,
      attachmentSize: up?.size,
      attachmentMime: up?.mimeType,
      replyTo: quoted == null
          ? null
          : MessageReply(
              id: quoted.id,
              senderId: quoted.senderId,
              senderName: quoted.sender?.fullName ?? '',
              excerpt: quoted.body,
            ),
      createdAt: testNow.add(Duration(minutes: _ids)),
    );
    threads[conversationId] = [..._thread(conversationId), m];
    return m;
  }

  final _uploaded = <String?, UploadedAttachment>{};

  @override
  Future<UploadedAttachment> upload(PickedAttachment file) async {
    await _enter('upload', file.name);
    uploads.add(file);
    final url = '/uploads/up-${_ids++}-${file.name}';
    return _uploaded[url] = UploadedAttachment(
      url: url,
      name: file.name,
      size: file.size,
      mimeType: attachmentMimeFor(file.name, file.mimeType),
    );
  }

  @override
  Future<Uint8List> download(String url) async {
    await _enter('download', url);
    return downloadAnswer;
  }

  @override
  Future<void> markRead(String conversationId, {String? asCompanyId}) async {
    await _enter('markRead', '$conversationId as=$asCompanyId');
    rows = [for (final c in rows) c.id == conversationId ? c.copyWith(unread: 0) : c];
  }

  @override
  Future<DateTime> deleteMessage(String conversationId, String messageId) async {
    await _enter('deleteMessage', '$conversationId $messageId');
    threads[conversationId] = [for (final m in _thread(conversationId)) m.id == messageId ? m.asDeleted(testNow) : m];
    return testNow;
  }

  @override
  Future<void> report(String messageId, String reason, {String? note}) async {
    await _enter('report', '$messageId $reason note=$note');
    reports.add((messageId: messageId, reason: reason, note: note));
  }

  @override
  Future<({bool starred, bool pinned})> setPreference(String conversationId, {bool? starred, bool? pinned}) async {
    await _enter('setPreference', '$conversationId starred=$starred pinned=$pinned');
    final c = _row(conversationId).copyWith(starred: starred, pinned: pinned);
    rows = [for (final x in rows) x.id == conversationId ? c : x];
    return (starred: c.starred, pinned: c.pinned);
  }

  @override
  Future<ThreadParty> updateCompanyThread(
    String conversationId, {
    required String companyId,
    ThreadStatus? status,
    String? assigneeId,
    bool unassign = false,
  }) async {
    await _enter(
      'updateCompanyThread',
      '$conversationId company=$companyId status=${status?.name} assignee=$assigneeId unassign=$unassign',
    );
    final c = _row(conversationId);
    final party = c.parties.firstWhere((p) => p.companyId == companyId);
    final next = party.copyWith(
      status: status,
      assignee: assigneeId == null ? null : ChatPerson(id: assigneeId, firstName: 'You', lastName: ''),
      clearAssignee: unassign,
    );
    rows = [
      for (final x in rows)
        x.id == conversationId ? x.copyWith(parties: [for (final p in c.parties) p == party ? next : p]) : x,
    ];
    return next;
  }

  @override
  Future<Recipients> recipients(String search) async {
    await _enter('recipients', search);
    return recipientsAnswer;
  }

  Future<String> _start(String call, String detail) async {
    await _enter(call, detail);
    return startAnswer;
  }

  @override
  Future<String> startWithPerson(String userId, {String? message}) =>
      _start('startWithPerson', '$userId message=$message');

  @override
  Future<String> startWithSupplier(String vendorId, {String? rfqId, String? message}) =>
      _start('startWithSupplier', '$vendorId rfq=$rfqId message=$message');

  @override
  Future<String> startWithCompany(String companyId, String topic, {String? message}) =>
      _start('startWithCompany', '$companyId topic=$topic message=$message');

  @override
  Future<String> startWithJobContact(String jobId, {String? message}) =>
      _start('startWithJobContact', '$jobId message=$message');

  @override
  Future<String> openForPurchase(String purchaseId) => _start('openForPurchase', purchaseId);

  @override
  Future<String> openForMentorship(String mentorshipId) => _start('openForMentorship', mentorshipId);

  @override
  Future<String> openForGroupSession(String sessionId) => _start('openForGroupSession', sessionId);

  @override
  Future<String> openForRfq(String rfqId, {String? supplierCompanyId}) =>
      _start('openForRfq', '$rfqId supplier=$supplierCompanyId');

  @override
  Future<String> openForApplication(String applicationId) => _start('openForApplication', applicationId);

  @override
  Future<RecordFacts> record(RecordRef ref) async {
    await _enter('record', '${ref.type.name}/${ref.id}');
    return recordAnswers[ref] ?? (throw ApiError(ref.type.unavailable, statusCode: 404));
  }

  @override
  Future<List<RecordFacts>> searchRecords(RecordType type, String search) async {
    await _enter('searchRecords', '${type.name} "$search"');
    return searchRecordsAnswers[type] ?? const [];
  }
}
