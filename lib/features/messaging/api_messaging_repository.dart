import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/config.dart';
import 'messaging_models.dart';
import 'messaging_repository.dart';

/// Messages from the API (`/messaging/*`), the website's workspace one call at
/// a time: the inbox switcher, the filtered list, pinned threads, search,
/// the paged thread, its context, sending (with a file uploaded first), read
/// receipts, star and pin, a company inbox's sorting, and the record
/// endpoints a "Message" button opens a thread through.
class ApiMessagingRepository implements MessagingRepository {
  ApiMessagingRepository({required this.api, String? viewerId}) : _viewerId = viewerId;

  final ApiClient api;
  String? _viewerId;

  static const pageSize = 25;

  String get _base => api.dio.options.baseUrl;

  @override
  Future<String> viewerId() async {
    final known = _viewerId;
    if (known != null) return known;
    final me = await _get('/auth/me');
    final user = (me['user'] as Map<String, dynamic>?) ?? me;
    return _viewerId = user['id'] as String;
  }

  @override
  Future<List<MessagingInbox>> inboxes() async {
    final res = await api.dio.get<List<dynamic>>('/messaging/inboxes');
    return (res.data ?? const []).cast<Map<String, dynamic>>().map(_inbox).toList();
  }

  @override
  Future<ConversationPage> conversations(ConversationQuery query, {int page = 1}) async {
    final res = await _get('/messaging/conversations', listQuery(query, page: page));
    final rows = (res['data'] as List? ?? const []).cast<Map<String, dynamic>>();
    final meta = res['meta'] as Map<String, dynamic>? ?? const {};
    return ConversationPage(
      conversations: rows.map(conversation).toList(),
      total: (meta['total'] as num?)?.toInt() ?? rows.length,
      hasMore: meta['hasNext'] == true,
    );
  }

  /// The query of one list page, as the website's `useConversationList` sends it.
  static Map<String, dynamic> listQuery(ConversationQuery q, {int page = 1, int limit = pageSize}) {
    final search = q.search.trim();
    return {
      'page': page,
      'limit': limit,
      'inbox': q.inbox,
      if (!q.companyInbox) 'filter': q.filter.name,
      if (!q.companyInbox && q.kind != null) 'kind': q.kind!.name,
      if (search.isNotEmpty) 'search': search,
      if (q.excludePinned) 'excludePinned': true,
      if (q.companyInbox && q.topic != null) 'topic': q.topic,
      if (q.companyInbox)
        ...switch (q.view) {
          CompanyInboxView.open => const <String, dynamic>{},
          CompanyInboxView.unread => const {'filter': 'unread'},
          CompanyInboxView.mine => const {'assignedToMe': true},
          CompanyInboxView.done => const {'status': 'DONE'},
          CompanyInboxView.spam => const {'status': 'SPAM'},
        },
    };
  }

  @override
  Future<List<Conversation>> pinned() async {
    final res = await _get('/messaging/conversations', {'filter': 'pinned', 'limit': 10});
    return (res['data'] as List? ?? const []).cast<Map<String, dynamic>>().map(conversation).toList();
  }

  @override
  Future<List<MessageSearchHit>> searchMessages(String q, {String? inbox}) async {
    final term = q.trim();
    if (term.length < 2) return const [];
    final res = await _get('/messaging/search', {'q': term, 'limit': 20, 'inbox': ?inbox});
    return (res['data'] as List? ?? const []).cast<Map<String, dynamic>>().map((h) {
      return MessageSearchHit(
        messageId: h['messageId'] as String,
        conversationId: h['conversationId'] as String,
        conversationTitle: h['conversationTitle'] as String?,
        participants: _people(h['participants']),
        sender: _personOrNull(h['sender']),
        snippet: h['snippet'] as String? ?? '',
        createdAt: _date(h['createdAt']) ?? DateTime.now(),
      );
    }).toList();
  }

  @override
  Future<MessagingUnread> unreadCount() async {
    final res = await _get('/messaging/unread-count');
    final companies = (res['companies'] as Map<String, dynamic>? ?? const {}).map(
      (k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0),
    );
    return MessagingUnread(
      count: (res['count'] as num?)?.toInt() ?? 0,
      personal: (res['personal'] as num?)?.toInt() ?? 0,
      companies: companies,
    );
  }

  @override
  Future<int> markAllRead({String? inbox}) async {
    final res = await api.dio.post<Map<String, dynamic>>(
      '/messaging/conversations/read-all',
      queryParameters: {'inbox': ?inbox},
    );
    return (res.data?['read'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<ThreadWindow> thread(String conversationId, {int take = 50, String? asCompanyId}) async {
    final res = await _get('/messaging/conversations/${_seg(conversationId)}', {
      'take': take,
      'asCompanyId': ?asCompanyId,
    });
    return ThreadWindow(
      conversation: conversation(res),
      messages: _messages(res['messages']),
      hasMore: res['hasMore'] == true,
      seen: _seen(res['seen']),
    );
  }

  @override
  Future<MessageWindow> older(String conversationId, String beforeId, {int take = 50, String? asCompanyId}) =>
      _window(conversationId, {'before': beforeId, 'take': take, 'asCompanyId': ?asCompanyId});

  @override
  Future<MessageWindow> newer(String conversationId, String afterId, {String? asCompanyId}) =>
      _window(conversationId, {'after': afterId, 'asCompanyId': ?asCompanyId});

  Future<MessageWindow> _window(String conversationId, Map<String, dynamic> query) async {
    final res = await _get('/messaging/conversations/${_seg(conversationId)}/messages', query);
    return MessageWindow(messages: _messages(res['data']), hasMore: res['hasMore'] == true, seen: _seen(res['seen']));
  }

  @override
  Future<ConversationContext?> context(String conversationId, {String? asCompanyId}) async {
    final res = await _get('/messaging/conversations/${_seg(conversationId)}/context', {'asCompanyId': ?asCompanyId});
    return contextFrom(res);
  }

  @override
  Future<ChatMessage> send(
    String conversationId, {
    required String body,
    String? attachmentUrl,
    String? replyToId,
    String? asCompanyId,
  }) async {
    final res = await api.dio.post<Map<String, dynamic>>(
      '/messaging/conversations/${_seg(conversationId)}/messages',
      data: {'body': body, 'attachmentUrl': ?attachmentUrl, 'replyToId': ?replyToId, 'asCompanyId': ?asCompanyId},
    );
    return message(res.data!);
  }

  @override
  Future<UploadedAttachment> upload(PickedAttachment file) async {
    final mime = attachmentMimeFor(file.name, file.mimeType);
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        file.bytes,
        filename: file.name,
        contentType: mime == null ? null : DioMediaType.parse(mime),
      ),
    });
    final res = await api.dio.post<Map<String, dynamic>>(
      '/uploads',
      data: form,
      queryParameters: {'purpose': 'message-attachment'},
    );
    final data = res.data!;
    return UploadedAttachment(
      url: data['url'] as String,
      name: data['name'] as String? ?? file.name,
      size: (data['size'] as num?)?.toInt() ?? file.size,
      mimeType: data['mimeType'] as String? ?? mime,
    );
  }

  @override
  Future<Uint8List> download(String url) async {
    final res = await api.dio.get<List<int>>(
      AppConfig.absoluteUrl(url, apiBase: _base)!,
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(res.data ?? const []);
  }

  @override
  Future<void> markRead(String conversationId, {String? asCompanyId}) async {
    await api.dio.post<dynamic>(
      '/messaging/conversations/${_seg(conversationId)}/read',
      queryParameters: {'asCompanyId': ?asCompanyId},
    );
  }

  @override
  Future<DateTime> deleteMessage(String conversationId, String messageId) async {
    final res = await api.dio.delete<Map<String, dynamic>>(
      '/messaging/conversations/${_seg(conversationId)}/messages/${_seg(messageId)}',
    );
    return _date(res.data?['deletedAt']) ?? DateTime.now();
  }

  @override
  Future<void> report(String messageId, String reason, {String? note}) async {
    final text = note?.trim();
    await api.dio.post<dynamic>(
      '/messaging/messages/${_seg(messageId)}/report',
      data: {'reason': reason, if (text != null && text.isNotEmpty) 'note': text},
    );
  }

  @override
  Future<({bool starred, bool pinned})> setPreference(String conversationId, {bool? starred, bool? pinned}) async {
    final res = await api.dio.patch<Map<String, dynamic>>(
      '/messaging/conversations/${_seg(conversationId)}/preferences',
      data: {'starred': ?starred, 'pinned': ?pinned},
    );
    return (starred: res.data?['starred'] == true, pinned: res.data?['pinned'] == true);
  }

  @override
  Future<ThreadParty> updateCompanyThread(
    String conversationId, {
    required String companyId,
    ThreadStatus? status,
    String? assigneeId,
    bool unassign = false,
  }) async {
    final res = await api.dio.patch<Map<String, dynamic>>(
      '/messaging/conversations/${_seg(conversationId)}/company',
      data: {
        'companyId': companyId,
        if (status != null) 'status': threadStatusToApi(status),
        if (unassign) 'assigneeId': null else 'assigneeId': ?assigneeId,
      },
    );
    return _party(res.data!);
  }

  @override
  Future<Recipients> recipients(String search) async {
    final term = search.trim();
    if (term.length < 2) return const Recipients();
    final res = await _get('/messaging/recipients', {'search': term});
    return Recipients(
      people: (res['people'] as List? ?? const []).cast<Map<String, dynamic>>().map((p) {
        return RecipientPerson(
          person: _person(p),
          headline: _text(p['headline']),
          companyName: _text(p['companyName']),
        );
      }).toList(),
      suppliers: (res['suppliers'] as List? ?? const []).cast<Map<String, dynamic>>().map((s) {
        return RecipientSupplier(
          vendorId: s['vendorId'] as String,
          companyId: s['companyId'] as String,
          name: s['name'] as String? ?? '',
          logo: _picture(s['logoUrl']),
          city: _text(s['city']),
        );
      }).toList(),
    );
  }

  @override
  Future<String> startWithPerson(String userId, {String? message}) => _open('/messaging/conversations', {
    'participantIds': [userId],
    if (_has(message)) 'message': message!.trim(),
  });

  @override
  Future<String> startWithSupplier(String vendorId, {String? rfqId, String? message}) => _open(
    '/messaging/conversations/supplier',
    {'vendorId': vendorId, 'rfqId': ?rfqId, if (_has(message)) 'message': message!.trim()},
  );

  @override
  Future<String> startWithCompany(String companyId, String topic, {String? message}) => _open(
    '/messaging/conversations/company',
    {'companyId': companyId, 'topic': topic, if (_has(message)) 'message': message!.trim()},
  );

  @override
  Future<String> startWithJobContact(String jobId, {String? message}) =>
      _open('/messaging/conversations/job', {'jobId': jobId, if (_has(message)) 'message': message!.trim()});

  @override
  Future<String> openForPurchase(String purchaseId) =>
      _open('/mentor-services/purchases/${_seg(purchaseId)}/conversation', null);

  @override
  Future<String> openForMentorship(String mentorshipId) =>
      _open('/mentorship/${_seg(mentorshipId)}/conversation', null);

  @override
  Future<String> openForGroupSession(String sessionId) =>
      _open('/mentorship/group-sessions/${_seg(sessionId)}/conversation', null);

  @override
  Future<String> openForRfq(String rfqId, {String? supplierCompanyId}) =>
      _open('/rfq/${_seg(rfqId)}/conversation', {'supplierCompanyId': ?supplierCompanyId});

  @override
  Future<String> openForApplication(String applicationId) =>
      _open('/applications/${_seg(applicationId)}/conversation', null);

  /// The record endpoints answer `{ conversationId }` or the conversation itself.
  Future<String> _open(String path, Map<String, dynamic>? body) async {
    final res = await api.dio.post<dynamic>(path, data: body ?? const <String, dynamic>{});
    final id = conversationIdOf(res.data);
    if (id == null) throw StateError('The API opened no conversation');
    return id;
  }

  static String? conversationIdOf(Object? data) {
    if (data is! Map) return null;
    final direct = data['conversationId'] ?? data['id'];
    if (direct is String) return direct;
    final nested = data['conversation'];
    if (nested is Map && nested['id'] is String) return nested['id'] as String;
    return null;
  }

  // --- shared records ------------------------------------------------------

  static const _detail = {
    RecordType.job: '/jobs/',
    RecordType.requirement: '/rfq/',
    RecordType.company: '/companies/',
    RecordType.product: '/products/',
    RecordType.mentor: '/mentorship/mentors/',
    RecordType.event: '/events/',
  };

  static const _list = {
    RecordType.job: '/jobs',
    RecordType.requirement: '/rfq',
    RecordType.company: '/companies',
    RecordType.product: '/products',
    RecordType.mentor: '/mentorship/mentors',
    RecordType.event: '/events',
  };

  @override
  Future<RecordFacts> record(RecordRef ref) async {
    final res = await _get('${_detail[ref.type]}${_seg(ref.id)}');
    return recordFacts(ref.type, res, apiBase: _base);
  }

  @override
  Future<List<RecordFacts>> searchRecords(RecordType type, String search) async {
    final q = search.trim();
    Future<List<Map<String, dynamic>>> list(String path, int limit) async {
      final res = await api.dio.get<dynamic>(path, queryParameters: {'limit': limit, if (q.isNotEmpty) 'search': q});
      final data = res.data;
      final rows = data is List ? data : (data is Map ? data['data'] as List? : null);
      return (rows ?? const []).cast<Map<String, dynamic>>();
    }

    if (type == RecordType.requirement) {
      // The person's own first (drafts open for nobody else), then the open board's.
      final results = await Future.wait([
        list('/rfq/mine', 6).catchError((_) => <Map<String, dynamic>>[]),
        list(_list[type]!, 6).catchError((_) => <Map<String, dynamic>>[]),
      ]);
      final mine = results[0].where((r) => r['status'] != 'DRAFT').toList();
      final seen = mine.map((r) => r['id']).toSet();
      return [
        ...mine,
        ...results[1].where((r) => !seen.contains(r['id'])),
      ].take(8).map((r) => recordFacts(type, r, apiBase: _base)).toList();
    }
    return (await list(_list[type]!, 6)).map((r) => recordFacts(type, r, apiBase: _base)).toList();
  }

  /// What a record's card shows, from the module's own row (`messagingRecords.ts`).
  static RecordFacts recordFacts(RecordType type, Map<String, dynamic> r, {String? apiBase}) {
    Map<String, dynamic> obj(Object? v) => v is Map<String, dynamic> ? v : const {};
    String? first(Object? v) => v is List && v.isNotEmpty && v.first is String ? v.first as String : null;
    ChatPicture? pic(Object? v) => _pictureAt(v, apiBase);
    final id = r['id'] as String? ?? '';
    return switch (type) {
      RecordType.job => RecordFacts(
        type: type,
        id: id,
        title: _text(r['title']) ?? '',
        owner: _text(obj(r['company'])['name']),
        image: pic(obj(r['company'])['logoUrl']),
        city: _text(r['city']) ?? first(r['cities']) ?? _text(r['location']),
        kind: _text(r['workMode']),
      ),
      RecordType.requirement => RecordFacts(
        type: type,
        id: id,
        title: _text(r['title']) ?? '',
        owner: _text(r['companyName']),
        city: first(r['locations']) ?? _text(r['city']),
        amount: _num(r['budget']),
        date: _date(r['dueDate']),
        kind: _text(r['kind']),
      ),
      RecordType.company => RecordFacts(
        type: type,
        id: id,
        title: _text(r['name']) ?? '',
        owner: _text(r['industry']),
        image: pic(r['logoUrl']),
        city: _text(r['city']),
      ),
      RecordType.product => RecordFacts(
        type: type,
        id: id,
        title: _text(r['name']) ?? '',
        owner: _text(obj(r['company'])['name']),
        image: pic(r['imageUrl']) ?? pic(obj(r['company'])['logoUrl']),
        amount: _num(r['price']),
        unit: _text(r['unit']),
      ),
      RecordType.mentor => RecordFacts(
        type: type,
        id: id,
        title: '${_text(obj(r['user'])['firstName']) ?? ''} ${_text(obj(r['user'])['lastName']) ?? ''}'.trim(),
        owner: _text(r['headline']),
        image: pic(obj(r['user'])['avatarUrl']),
        years: _num(r['yearsExperience'])?.toInt(),
        city: _text(r['city']),
      ),
      RecordType.event => RecordFacts(
        type: type,
        // An event's page is keyed by its slug.
        id: _text(r['slug']) ?? id,
        title: _text(r['title']) ?? '',
        owner: _text(obj(r['chapter'])['name']) ?? _text(obj(r['council'])['name']),
        image: pic(r['coverUrl']),
        city: _text(r['city']) ?? _text(r['location']),
        date: _date(r['startsAt']),
      ),
    };
  }

  // --- mapping -------------------------------------------------------------

  Conversation conversation(Map<String, dynamic> c) {
    final messages = _messages(c['messages']);
    final rfq = c['rfq'] as Map<String, dynamic>?;
    return Conversation(
      id: c['id'] as String,
      title: _text(c['title']),
      rfqId: c['rfqId'] as String? ?? rfq?['id'] as String?,
      rfqTitle: _text(rfq?['title']),
      participants: _people(c['participants']),
      lastMessage: messages.isEmpty ? null : messages.last,
      unread: (c['unread'] as num?)?.toInt() ?? 0,
      starred: c['starred'] == true,
      pinned: c['pinned'] == true,
      kind: conversationKindFromApi(c['kind'] as String?),
      contextLabel: _text(c['contextLabel']),
      counterpartCompany: _company(c['counterpartCompany']),
      parties: (c['parties'] as List? ?? const []).cast<Map<String, dynamic>>().map(_party).toList(),
      asCompanyId: c['asCompanyId'] as String?,
      updatedAt: _date(c['updatedAt']) ?? _date(c['createdAt']) ?? DateTime.now(),
    );
  }

  ChatMessage message(Map<String, dynamic> m) {
    final reply = m['replyTo'] as Map<String, dynamic>?;
    return ChatMessage(
      id: m['id'] as String,
      conversationId: m['conversationId'] as String? ?? '',
      senderId: m['senderId'] as String? ?? '',
      sender: _personOrNull(m['sender']),
      senderCompany: _company(m['senderCompany']),
      body: m['body'] as String? ?? '',
      attachmentUrl: _text(m['attachmentUrl']),
      attachmentName: _text(m['attachmentName']),
      attachmentSize: (m['attachmentSize'] as num?)?.toInt(),
      attachmentMime: _text(m['attachmentMime']),
      replyTo: reply == null
          ? null
          : MessageReply(
              id: reply['id'] as String,
              senderId: reply['senderId'] as String? ?? '',
              senderName: reply['senderName'] as String? ?? '',
              excerpt: reply['excerpt'] as String? ?? '',
              attachmentName: _text(reply['attachmentName']),
              deleted: reply['deleted'] == true,
            ),
      readAt: _date(m['readAt']),
      deletedAt: _date(m['deletedAt']),
      createdAt: _date(m['createdAt']) ?? DateTime.now(),
    );
  }

  List<ChatMessage> _messages(Object? raw) {
    final list = (raw as List? ?? const []).cast<Map<String, dynamic>>().map(message).toList();
    list.sort((a, b) {
      final at = a.createdAt.compareTo(b.createdAt);
      return at != 0 ? at : a.id.compareTo(b.id);
    });
    return list;
  }

  ConversationContext? contextFrom(Map<String, dynamic> c) {
    final kind = conversationKindFromApi(c['kind'] as String?);
    if (kind == null) return null;
    final counterpart = c['counterpart'] as Map<String, dynamic>? ?? const {};
    final company = counterpart['company'] as Map<String, dynamic>?;
    final requirement = c['requirement'] as Map<String, dynamic>?;
    final bid = c['bid'] as Map<String, dynamic>?;
    final mentorship = c['mentorship'] as Map<String, dynamic>?;
    final group = c['groupSession'] as Map<String, dynamic>?;
    final consultation = c['consultation'] as Map<String, dynamic>?;
    return ConversationContext(
      kind: kind,
      perspective: switch (c['perspective']) {
        'OWNER' => Perspective.owner,
        'SUPPLIER' => Perspective.supplier,
        _ => Perspective.other,
      },
      person: _personOrNull(counterpart['person']),
      company: company == null
          ? null
          : ContextCompany(
              id: company['id'] as String,
              name: company['name'] as String? ?? '',
              logo: _picture(company['logoUrl']),
              industry: _text(company['industry']),
              city: _text(company['city']),
              verified: company['verified'] == true,
              sells: company['sells'] == true,
              role: company['role'] as String?,
            ),
      requirement: requirement == null
          ? null
          : ContextRequirement(
              id: requirement['id'] as String,
              title: requirement['title'] as String? ?? '',
              kind: requirement['kind'] as String? ?? '',
              status: requirement['status'] as String? ?? '',
              budget: _num(requirement['budget']),
              location: _text(requirement['location']),
              dueDate: _date(requirement['dueDate']),
            ),
      bid: bid == null
          ? null
          : ContextBid(
              amount: _num(bid['amount']),
              status: bid['status'] as String? ?? '',
              awarded: bid['awarded'] == true,
              mine: bid['mine'] == true,
            ),
      mentorship: mentorship == null
          ? null
          : ContextMentorship(
              id: mentorship['id'] as String,
              mentee: mentorship['role'] == 'MENTEE',
              mentorProfileId: mentorship['mentorProfileId'] as String? ?? '',
              topics: (mentorship['topics'] as List? ?? const []).whereType<String>().toList(),
              sessionsCount: (mentorship['sessionsCount'] as num?)?.toInt() ?? 0,
              nextSessionAt: _date((mentorship['nextSession'] as Map<String, dynamic>?)?['scheduledAt']),
            ),
      groupSession: group == null
          ? null
          : ContextGroupSession(
              id: group['id'] as String,
              title: group['title'] as String? ?? '',
              nextAt: _date(group['nextAt']),
            ),
      consultation: consultation == null
          ? null
          : ContextConsultation(
              id: consultation['id'] as String,
              title: consultation['title'] as String? ?? '',
              buyer: consultation['role'] == 'BUYER',
              oneOnOne: consultation['type'] != 'QUERY',
              scheduledAt: _date(consultation['scheduledAt']),
            ),
      events: (c['events'] as List? ?? const []).cast<Map<String, dynamic>>().map((e) {
        return ThreadEvent(
          id: e['id'] as String,
          type: e['type'] as String? ?? '',
          at: _date(e['at']) ?? DateTime.now(),
          amount: _num(e['amount']),
          mine: e['mine'] == true,
          label: _text(e['label']),
        );
      }).toList(),
    );
  }

  MessagingInbox _inbox(Map<String, dynamic> i) => MessagingInbox(
    id: i['id'] as String,
    personal: i['kind'] != 'company',
    name: _text(i['name']),
    logo: _picture(i['logoUrl']),
    topics: (i['topics'] as List? ?? const []).whereType<String>().toList(),
    unread: (i['unread'] as num?)?.toInt() ?? 0,
  );

  ThreadParty _party(Map<String, dynamic> p) => ThreadParty(
    companyId: p['companyId'] as String,
    name: p['name'] as String? ?? '',
    logo: _picture(p['logoUrl']),
    topic: p['topic'] as String? ?? 'GENERAL',
    status: threadStatusFromApi(p['status'] as String?),
    assignee: _personOrNull(p['assignee']),
  );

  MessageSeen? _seen(Object? raw) {
    if (raw is! Map) return null;
    final at = _date(raw['at']);
    final id = raw['messageId'];
    if (at == null || id is! String) return null;
    return MessageSeen(messageId: id, at: at);
  }

  List<ChatPerson> _people(Object? raw) =>
      (raw as List? ?? const []).cast<Map<String, dynamic>>().map(_person).toList();

  ChatPerson? _personOrNull(Object? raw) => raw is Map<String, dynamic> ? _person(raw) : null;

  ChatPerson _person(Map<String, dynamic> p) => ChatPerson(
    id: p['id'] as String? ?? '',
    firstName: p['firstName'] as String? ?? '',
    lastName: p['lastName'] as String? ?? '',
    photo: _picture(p['avatarUrl']),
  );

  ChatCompany? _company(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    return ChatCompany(
      id: raw['id'] as String? ?? '',
      name: raw['name'] as String? ?? '',
      logo: _picture(raw['logoUrl']),
    );
  }

  ChatPicture? _picture(Object? raw) => _pictureAt(raw, _base);

  static ChatPicture? _pictureAt(Object? raw, String? apiBase) {
    final url = AppConfig.absoluteUrl(raw is String ? raw : null, apiBase: apiBase);
    return url == null ? null : ChatPicture.network(url);
  }

  Future<Map<String, dynamic>> _get(String path, [Map<String, dynamic>? query]) async {
    final res = await api.dio.get<Map<String, dynamic>>(path, queryParameters: query);
    return res.data ?? const {};
  }

  static String _seg(String id) => Uri.encodeComponent(id);
  static bool _has(String? s) => s != null && s.trim().isNotEmpty;
  static String? _text(Object? v) => v is String && v.trim().isNotEmpty ? v : null;
  static num? _num(Object? v) => v is num ? v : (v is String ? num.tryParse(v) : null);
  static DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;
}
