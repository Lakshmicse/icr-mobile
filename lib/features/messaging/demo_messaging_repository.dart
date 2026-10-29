import 'dart:typed_data';

import '../../core/api/api_error.dart';
import '../../core/config.dart';
import 'messaging_models.dart';
import 'messaging_repository.dart';

const _demo = 'assets/images/demo';

/// Messages with the designs' people — the inbox design's five threads (Dr. Radhika Iyer, Srikanth
/// Sriramagiri, Vikasha Aero Tech, Rajesh Sharma, Marcus Reed; docs/designs/messaging-inbox.png and
/// messaging-thread.png) and the older ones (Arvind Swamy, Priya Nambiar, Sarah Jenkins) — bundled for design review
/// (`--dart-define=FEED_SOURCE=demo`). Everything works in memory: sending,
/// reading, star and pin, deleting; nothing leaves the phone.
class DemoMessagingRepository implements MessagingRepository {
  DemoMessagingRepository({DateTime? now}) : _now = now ?? DateTime.now() {
    _seed();
  }

  final DateTime _now;

  static const meId = 'me';

  static const me = ChatPerson(
    id: meId,
    firstName: 'Rahul',
    lastName: 'Mehta',
    photo: ChatPicture.asset('$_demo/avatar_me.jpg'),
  );
  static const arvind = ChatPerson(
    id: 'arvind',
    firstName: 'Arvind',
    lastName: 'Swamy',
    photo: ChatPicture.asset('$_demo/avatar_arvind.jpg'),
  );
  static const priya = ChatPerson(
    id: 'priya',
    firstName: 'Priya',
    lastName: 'Nambiar',
    photo: ChatPicture.asset('$_demo/jobs/avatar_priya.png'),
  );
  static const sarah = ChatPerson(
    id: 'sarah',
    firstName: 'Sarah',
    lastName: 'Jenkins',
    photo: ChatPicture.asset('$_demo/avatar_sarah.jpg'),
  );
  static const david = ChatPerson(
    id: 'david',
    firstName: 'David',
    lastName: 'Chen',
    photo: ChatPicture.asset('$_demo/avatar_david.jpg'),
  );
  static const marcus = ChatPerson(
    id: 'marcus',
    firstName: 'Marcus',
    lastName: 'Reed',
    photo: ChatPicture.asset('$_demo/messaging/avatar_marcus.png'),
    headline: 'Lead IoT Architect @ Schneider Electric',
    online: false,
  );
  static const radhika = ChatPerson(
    id: 'radhika',
    firstName: 'Dr. Radhika',
    lastName: 'Iyer',
    photo: ChatPicture.asset('$_demo/messaging/avatar_radhika.png'),
    headline: 'Head of Energy & Climate, CBRE',
    online: true,
  );
  static const srikanth = ChatPerson(
    id: 'srikanth',
    firstName: 'Srikanth',
    lastName: 'Sriramagiri',
    photo: ChatPicture.asset('$_demo/messaging/avatar_srikanth.png'),
    headline: 'Supply Chain Leader @ Microsoft',
    online: true,
  );
  static const rajesh = ChatPerson(
    id: 'rajesh',
    firstName: 'Rajesh',
    lastName: 'Sharma',
    photo: ChatPicture.asset('$_demo/messaging/avatar_rajesh.png'),
    headline: 'VP Facilities @ Infosys',
    online: true,
  );
  static const karthik = ChatPerson(id: 'karthik', firstName: 'Karthik', lastName: 'Rao', online: false);
  static const vikasha = ChatCompany(id: 'vikasha', name: 'Vikasha Aero Tech');
  static const brookfield = ChatCompany(id: 'brookfield', name: 'Brookfield Properties');

  final _threads = <String, _Thread>{};
  var _nextId = 1;

  DateTime _ago({int days = 0, int hours = 0, int minutes = 0}) =>
      _now.subtract(Duration(days: days, hours: hours, minutes: minutes));

  /// Today at [hour]:[minute] on the demo's clock (the design's "10:42 AM").
  DateTime _todayAt(int hour, int minute) => DateTime(_now.year, _now.month, _now.day, hour, minute);

  void _seed() {
    final tomorrowFour = DateTime(_now.year, _now.month, _now.day + 1, 16);
    _add(
      _Thread(
        id: 'c-radhika',
        participants: const [me, radhika],
        kind: ConversationKind.direct,
        contextLabel: 'Net-Zero Council',
        context: ConversationContext(
          kind: ConversationKind.direct,
          person: radhika,
          company: const ContextCompany(
            id: 'cbre',
            name: 'CBRE',
            industry: 'Chair, Net-Zero Council',
            city: 'Bengaluru',
            verified: true,
          ),
          // The sync call she set up, as the thread's meeting card.
          consultation: ContextConsultation(
            id: 'sync-wg01',
            title: '1:1 Council Pre-Flight Sync',
            buyer: true,
            oneOnOne: true,
            scheduledAt: tomorrowFour,
          ),
        ),
        messages: [
          _m(
            'r1',
            'c-radhika',
            radhika,
            'Good morning Rahul, thank you for sharing the draft Green Lease SLA rider yesterday. Our ESG committee '
                'reviewed Section 4.2 regarding real-time sub-metering data sharing between landlord central BMS and '
                'tenant sub-distributors.',
            _todayAt(10, 14),
            read: true,
          ),
          ChatMessage(
            id: 'r2',
            conversationId: 'c-radhika',
            senderId: radhika.id,
            sender: radhika,
            body: '',
            attachmentUrl: '/uploads/demo-green-sla-rider.docx',
            attachmentName: 'Standardized_Green_SLA_Rider_v2.4.docx',
            attachmentSize: 696320,
            attachmentMime: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            readAt: _todayAt(10, 20),
            createdAt: _todayAt(10, 14),
          ),
          _m(
            'r3',
            'c-radhika',
            me,
            'Glad to hear that, Dr. Radhika. We calibrated the clauses directly against RICS and SEBI BRSR Core '
                'guidelines to make compliance frictionless for Tier-1 multinational tenants. Are we good to present '
                'this at the April 18 roundtable?',
            _todayAt(10, 30),
            read: true,
          ),
          _m(
            'r4',
            'c-radhika',
            radhika,
            "Yes, absolutely. I've scheduled a quick 20-min sync call tomorrow at 4:00 PM to finalize the slide deck "
                'and confirm panel speaking assignments.',
            _todayAt(10, 42),
          ),
        ],
      ),
    );
    _add(
      _Thread(
        id: 'c-srikanth',
        participants: const [me, srikanth],
        kind: ConversationKind.mentorship,
        contextLabel: '1:1 Mentorship',
        context: ConversationContext(
          kind: ConversationKind.mentorship,
          person: srikanth,
          mentorship: ContextMentorship(
            id: 'mentorship-srikanth',
            mentee: true,
            mentorProfileId: 'demo-srikanth',
            topics: const ['Supply chain planning', 'Career transitions'],
            sessionsCount: 2,
            nextSessionAt: _now.add(const Duration(days: 4, hours: 2)),
          ),
        ),
        messages: [
          _m(
            'k1',
            'c-srikanth',
            me,
            'Thank you for the diagnostic session. Could you share the notes when they are ready?',
            _ago(days: 1, hours: 6),
            read: true,
          ),
          _m(
            'k2',
            'c-srikanth',
            srikanth,
            'The diagnostic session notes are ready. I have added two reading links for the planning module.',
            _ago(days: 1, hours: 3),
            read: true,
          ),
        ],
      ),
    );
    _add(
      _Thread(
        id: 'c-rajesh',
        title: 'CXO Workplace Group',
        participants: const [me, rajesh, david],
        kind: ConversationKind.groupSession,
        contextLabel: 'CXO Workplace Group',
        context: ConversationContext(
          kind: ConversationKind.groupSession,
          groupSession: ContextGroupSession(
            id: 'group-cxo',
            title: 'CXO Workplace Group',
            nextAt: _now.add(const Duration(days: 9)),
          ),
        ),
        messages: [
          _m(
            'x1',
            'c-rajesh',
            rajesh,
            'Confirmed for the smart building walkthrough on the 22nd. Bring your BMS integration questions.',
            _ago(days: 15, hours: 2),
            read: true,
          ),
        ],
      ),
    );
    _add(
      _Thread(
        id: 'c-marcus',
        participants: const [me, marcus],
        kind: ConversationKind.direct,
        contextLabel: 'BMS & Energy',
        context: const ConversationContext(kind: ConversationKind.direct, person: marcus),
        messages: [
          _m(
            'mr1',
            'c-marcus',
            me,
            'Marcus, which schema did you settle on for the telemetry feed?',
            _ago(days: 17, hours: 4),
            read: true,
          ),
          _m(
            'mr2',
            'c-marcus',
            marcus,
            'BACnet telemetry integration schema is attached in the shared drive; the object model is flat on purpose.',
            _ago(days: 17, hours: 1),
            read: true,
          ),
        ],
      ),
    );
    _add(
      _Thread(
        id: 'c-arvind',
        participants: const [me, arvind],
        kind: ConversationKind.direct,
        counterpartCompany: brookfield,
        context: const ConversationContext(
          kind: ConversationKind.direct,
          person: arvind,
          company: ContextCompany(
            id: 'brookfield',
            name: 'Brookfield Properties',
            industry: 'Real estate',
            city: 'Mumbai',
            verified: true,
          ),
        ),
        messages: [
          _m(
            'a1',
            'c-arvind',
            me,
            'Arvind, loved your point on BACnet/IP in the HVAC thread.',
            _ago(days: 20, hours: 3, minutes: 10),
            read: true,
          ),
          _m(
            'a2',
            'c-arvind',
            arvind,
            'Thanks! The Niagara framework let us take the legacy controllers off vendor lock-in across the portfolio.',
            _ago(days: 20, hours: 2, minutes: 52),
            read: true,
          ),
          _m(
            'a3',
            'c-arvind',
            me,
            'Did you keep the old controllers or replace them?',
            _ago(days: 20, hours: 2, minutes: 40),
            read: true,
          ),
          _m(
            'a4',
            'c-arvind',
            arvind,
            'Kept them. We wrapped them with JACE gateways, so only the head-end changed.',
            _ago(days: 20, minutes: 48),
            read: true,
          ),
          _m(
            'a5',
            'c-arvind',
            arvind,
            'Happy to share the commissioning checklist we used.',
            _ago(days: 20, minutes: 42),
            read: true,
          ),
        ],
      ),
    );
    _add(
      _Thread(
        id: 'c-vikasha',
        title: 'Enquiry · Vikasha Aero Tech',
        participants: const [me, karthik],
        kind: ConversationKind.enquiry,
        rfqTitle: 'Drone facade cleaning — Tower B, Whitefield',
        contextLabel: 'RFQ #2026-084',
        counterpartCompany: vikasha,
        context: ConversationContext(
          kind: ConversationKind.enquiry,
          perspective: Perspective.owner,
          person: karthik,
          company: const ContextCompany(
            id: 'vikasha',
            name: 'Vikasha Aero Tech',
            industry: 'Drone Facade & AI Robotics',
            city: 'Bengaluru',
            verified: true,
            sells: true,
            role: 'SUPPLIER',
          ),
          requirement: ContextRequirement(
            id: 'rfq-facade',
            title: 'Drone facade cleaning — Tower B, Whitefield',
            kind: 'ENQUIRY',
            status: 'PUBLISHED',
            location: 'Bengaluru',
            dueDate: _now.add(const Duration(days: 9)),
          ),
          bid: const ContextBid(amount: 485000, status: 'PENDING', awarded: false, mine: false),
        ),
        messages: [
          _m(
            'v1',
            'c-vikasha',
            me,
            'Hi team, we need the north and east facades of Tower B cleaned before the December audit. Can you share a quote?',
            _ago(days: 2, hours: 5),
            read: true,
          ),
          _m(
            'v2',
            'c-vikasha',
            karthik,
            'Thanks Rahul. Our DGCA-licensed crew can do both faces in four nights with zero rope access. Quote attached.',
            _ago(days: 2, hours: 2),
            company: vikasha,
            read: true,
          ),
          ChatMessage(
            id: 'v3',
            conversationId: 'c-vikasha',
            senderId: karthik.id,
            sender: karthik,
            senderCompany: vikasha,
            body: '',
            attachmentUrl: '/uploads/demo-vikasha-quote.pdf',
            attachmentName: 'Vikasha_Tower-B_Quote.pdf',
            attachmentSize: 248000,
            attachmentMime: 'application/pdf',
            readAt: _ago(days: 2),
            createdAt: _ago(days: 2, hours: 2),
          ),
          _m(
            'v4',
            'c-vikasha',
            me,
            'Could we visit one of your live sites first?',
            _ago(days: 1, hours: 9),
            read: true,
          ),
          _m(
            'v5',
            'c-vikasha',
            karthik,
            'We have uploaded the revised DGCA crew certificates and the site visit slot: Prestige Tech Park, Thursday 7 am.',
            _ago(days: 1, hours: 4),
            company: vikasha,
          ),
        ],
      ),
    );
    _add(
      _Thread(
        id: 'c-priya',
        participants: const [me, priya],
        kind: ConversationKind.mentorship,
        context: ConversationContext(
          kind: ConversationKind.mentorship,
          person: priya,
          mentorship: ContextMentorship(
            id: 'mentorship-priya',
            mentee: true,
            mentorProfileId: 'priya-profile',
            topics: const ['IGBC certification', 'Net-zero retrofits'],
            sessionsCount: 3,
            nextSessionAt: _now.add(const Duration(days: 2, hours: 3)),
          ),
        ),
        messages: [
          _m(
            'p1',
            'c-priya',
            priya,
            'Great session today. Send me the energy audit when it is ready.',
            _ago(days: 24),
            read: true,
          ),
          _m(
            'p2',
            'c-priya',
            me,
            'Here it is — the chiller plant numbers are on page 4.',
            _ago(days: 23, hours: 20),
            read: true,
          ),
          _m(
            'p3',
            'c-priya',
            priya,
            'Looked through it. Your kW/TR is high; let us start with the condenser approach next time.',
            _ago(days: 22, hours: 3),
            read: true,
          ),
        ],
      ),
    );
    _add(
      _Thread(
        id: 'c-sarah',
        participants: const [me, sarah],
        kind: ConversationKind.direct,
        starred: true,
        context: const ConversationContext(kind: ConversationKind.direct, person: sarah),
        messages: [
          _m(
            's1',
            'c-sarah',
            sarah,
            'Which vendors did you shortlist for the IoT sensor retrofit? Our BMS is 15 years old too.',
            _ago(days: 26, hours: 4),
            read: true,
          ),
          _m(
            's2',
            'c-sarah',
            me,
            'Three on the shortlist, here is the one we liked best:\n${AppConfig.siteUrl}/companies/vikasha',
            _ago(days: 26, hours: 2),
            read: true,
          ),
        ],
      ),
    );
    _add(
      _Thread(
        id: 'c-room',
        title: 'BMS Retrofit Clinic',
        participants: const [me, david, marcus, priya],
        kind: ConversationKind.groupSession,
        contextLabel: 'BMS Retrofit Clinic',
        context: ConversationContext(
          kind: ConversationKind.groupSession,
          groupSession: ContextGroupSession(
            id: 'group-bms',
            title: 'BMS Retrofit Clinic',
            nextAt: _now.add(const Duration(days: 5)),
          ),
        ),
        messages: [
          _m('g1', 'c-room', david, 'Slides for Thursday are up in the session page.', _ago(days: 30), read: true),
          _m(
            'g2',
            'c-room',
            marcus,
            'Can we cover Archibus integration too?',
            _ago(days: 30, minutes: -20),
            read: true,
          ),
        ],
      ),
    );
  }

  ChatMessage _m(
    String id,
    String thread,
    ChatPerson from,
    String body,
    DateTime at, {
    bool read = false,
    ChatCompany? company,
  }) => ChatMessage(
    id: id,
    conversationId: thread,
    senderId: from.id,
    sender: from,
    senderCompany: company,
    body: body,
    createdAt: at,
    readAt: read ? at.add(const Duration(minutes: 5)) : null,
  );

  void _add(_Thread t) => _threads[t.id] = t;

  _Thread _thread(String id) =>
      _threads[id] ?? (throw ApiError('This conversation could not be found.', statusCode: 404));

  int _unread(_Thread t) => t.messages.where((m) => m.senderId != meId && m.readAt == null && !m.deleted).length;

  Conversation _row(_Thread t) => Conversation(
    id: t.id,
    title: t.title,
    rfqTitle: t.rfqTitle,
    participants: t.participants,
    lastMessage: t.messages.isEmpty ? null : t.messages.last,
    unread: _unread(t),
    starred: t.starred,
    pinned: t.pinned,
    verified: t.context?.company?.verified ?? false,
    kind: t.kind,
    contextLabel: t.contextLabel ?? t.rfqTitle,
    counterpartCompany: t.counterpartCompany,
    updatedAt: t.messages.isEmpty ? _now : t.messages.last.createdAt,
  );

  @override
  Future<String> viewerId() async => meId;

  @override
  Future<List<MessagingInbox>> inboxes() async => [
    MessagingInbox(
      id: MessagingInbox.personalId,
      personal: true,
      unread: _threads.values.fold(0, (n, t) => n + _unread(t)),
    ),
  ];

  @override
  Future<ConversationPage> conversations(ConversationQuery query, {int page = 1}) async {
    final q = query.search.trim().toLowerCase();
    var rows = _threads.values.toList()..sort((a, b) => _row(b).updatedAt.compareTo(_row(a).updatedAt));
    rows = rows.where((t) {
      if (query.excludePinned && t.pinned) return false;
      if (query.filter == InboxFilter.unread && _unread(t) == 0) return false;
      if (query.filter == InboxFilter.starred && !t.starred) return false;
      switch (query.kind) {
        case InboxKind.requirement:
          if (!(t.kind?.isRequirement ?? false)) return false;
        case InboxKind.mentorship:
          if (t.kind != ConversationKind.mentorship &&
              t.kind != ConversationKind.groupSession &&
              t.kind != ConversationKind.consultation) {
            return false;
          }
        case InboxKind.direct:
          if (t.kind != ConversationKind.direct && t.kind != ConversationKind.company) return false;
        case null:
          break;
      }
      if (q.isNotEmpty) {
        final hay = [
          t.title ?? '',
          t.rfqTitle ?? '',
          t.counterpartCompany?.name ?? '',
          ...t.participants.where((p) => p.id != meId).map((p) => p.fullName),
        ].join(' ').toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();
    return ConversationPage(conversations: rows.map(_row).toList(), total: rows.length, hasMore: false);
  }

  @override
  Future<List<Conversation>> pinned() async => _threads.values.where((t) => t.pinned).map(_row).toList();

  @override
  Future<List<MessageSearchHit>> searchMessages(String q, {String? inbox}) async {
    final term = q.trim().toLowerCase();
    if (term.length < 2) return const [];
    final hits = <MessageSearchHit>[];
    for (final t in _threads.values) {
      for (final m in t.messages.reversed) {
        if (m.deleted || !m.body.toLowerCase().contains(term)) continue;
        hits.add(
          MessageSearchHit(
            messageId: m.id,
            conversationId: t.id,
            conversationTitle: t.title,
            participants: t.participants,
            sender: m.sender,
            snippet: m.body,
            createdAt: m.createdAt,
          ),
        );
      }
    }
    hits.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return hits;
  }

  @override
  Future<MessagingUnread> unreadCount() async {
    final count = _threads.values.fold(0, (n, t) => n + _unread(t));
    return MessagingUnread(count: count, personal: count);
  }

  @override
  Future<int> markAllRead({String? inbox}) async {
    var read = 0;
    for (final t in _threads.values) {
      read += _unread(t);
      _readAll(t);
    }
    return read;
  }

  void _readAll(_Thread t) {
    t.messages = [
      for (final m in t.messages)
        m.senderId != meId && m.readAt == null
            ? ChatMessage(
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
                createdAt: m.createdAt,
                readAt: _now,
                deletedAt: m.deletedAt,
              )
            : m,
    ];
  }

  @override
  Future<ThreadWindow> thread(String conversationId, {int take = 50, String? asCompanyId}) async {
    final t = _thread(conversationId);
    final start = t.messages.length > take ? t.messages.length - take : 0;
    return ThreadWindow(
      conversation: _row(t),
      messages: t.messages.sublist(start),
      hasMore: start > 0,
      seen: _seenOf(t),
    );
  }

  MessageSeen? _seenOf(_Thread t) {
    if (t.participants.length != 2) return null;
    for (final m in t.messages.reversed) {
      if (m.senderId == meId && m.readAt != null && !m.deleted) return MessageSeen(messageId: m.id, at: m.readAt!);
    }
    return null;
  }

  @override
  Future<MessageWindow> older(String conversationId, String beforeId, {int take = 50, String? asCompanyId}) async {
    final t = _thread(conversationId);
    final index = t.messages.indexWhere((m) => m.id == beforeId);
    if (index <= 0) return const MessageWindow(messages: [], hasMore: false);
    final start = index > take ? index - take : 0;
    return MessageWindow(messages: t.messages.sublist(start, index), hasMore: start > 0, seen: _seenOf(t));
  }

  @override
  Future<MessageWindow> newer(String conversationId, String afterId, {String? asCompanyId}) async {
    final t = _thread(conversationId);
    final index = t.messages.indexWhere((m) => m.id == afterId);
    return MessageWindow(
      messages: index < 0 ? const [] : t.messages.sublist(index + 1),
      hasMore: false,
      seen: _seenOf(t),
    );
  }

  @override
  Future<ConversationContext?> context(String conversationId, {String? asCompanyId}) async =>
      _thread(conversationId).context;

  @override
  Future<ChatMessage> send(
    String conversationId, {
    required String body,
    String? attachmentUrl,
    String? replyToId,
    String? asCompanyId,
  }) async {
    final t = _thread(conversationId);
    if (body.trim().isEmpty && attachmentUrl == null) {
      throw ApiError('Write a message or attach a file.', statusCode: 400);
    }
    final quoted = replyToId == null ? null : t.messages.where((m) => m.id == replyToId).firstOrNull;
    final upload = attachmentUrl == null ? null : _uploads[attachmentUrl];
    final message = ChatMessage(
      id: 'local-${_nextId++}',
      conversationId: conversationId,
      senderId: meId,
      sender: me,
      body: body,
      attachmentUrl: attachmentUrl,
      attachmentName: upload?.name,
      attachmentSize: upload?.size,
      attachmentMime: upload?.mimeType,
      replyTo: quoted == null
          ? null
          : MessageReply(
              id: quoted.id,
              senderId: quoted.senderId,
              senderName: quoted.sender?.fullName ?? '',
              excerpt: quoted.body,
              attachmentName: quoted.attachmentName,
            ),
      createdAt: DateTime.now().isAfter(_now) ? DateTime.now() : _now,
    );
    t.messages = [...t.messages, message];
    return message;
  }

  final _uploads = <String, UploadedAttachment>{};

  @override
  Future<UploadedAttachment> upload(PickedAttachment file) async {
    final url = '/uploads/demo-${_nextId++}-${file.name}';
    return _uploads[url] = UploadedAttachment(
      url: url,
      name: file.name,
      size: file.size,
      mimeType: attachmentMimeFor(file.name, file.mimeType),
    );
  }

  @override
  Future<Uint8List> download(String url) async => Uint8List(0);

  @override
  Future<void> markRead(String conversationId, {String? asCompanyId}) async => _readAll(_thread(conversationId));

  @override
  Future<DateTime> deleteMessage(String conversationId, String messageId) async {
    final t = _thread(conversationId);
    final at = _now;
    t.messages = [for (final m in t.messages) m.id == messageId ? m.asDeleted(at) : m];
    return at;
  }

  @override
  Future<void> report(String messageId, String reason, {String? note}) async {}

  @override
  Future<({bool starred, bool pinned})> setPreference(String conversationId, {bool? starred, bool? pinned}) async {
    final t = _thread(conversationId);
    if (starred != null) t.starred = starred;
    if (pinned != null) t.pinned = pinned;
    return (starred: t.starred, pinned: t.pinned);
  }

  @override
  Future<ThreadParty> updateCompanyThread(
    String conversationId, {
    required String companyId,
    ThreadStatus? status,
    String? assigneeId,
    bool unassign = false,
  }) async => throw ApiError('This conversation is not in a company inbox.', statusCode: 400);

  @override
  Future<Recipients> recipients(String search) async {
    final q = search.trim().toLowerCase();
    if (q.length < 2) return const Recipients();
    const everyone = [arvind, priya, sarah, david, marcus];
    return Recipients(
      people: [
        for (final p in everyone)
          if (p.fullName.toLowerCase().contains(q)) RecipientPerson(person: p),
      ],
      suppliers: [
        if ('vikasha aero tech'.contains(q))
          const RecipientSupplier(
            vendorId: 'vendor-vikasha',
            companyId: 'vikasha',
            name: 'Vikasha Aero Tech',
            city: 'Bengaluru',
          ),
      ],
    );
  }

  String _plainWith(ChatPerson person, String? message) {
    final existing = _threads.values.where(
      (t) =>
          t.participants.length == 2 &&
          t.participants.any((p) => p.id == person.id) &&
          t.kind == ConversationKind.direct,
    );
    final t =
        existing.firstOrNull ??
        _Thread(
          id: 'c-${person.id}-${_nextId++}',
          participants: [me, person],
          kind: ConversationKind.direct,
          context: ConversationContext(kind: ConversationKind.direct, person: person),
          messages: const [],
        );
    _add(t);
    if (message != null && message.trim().isNotEmpty) {
      t.messages = [...t.messages, _m('local-${_nextId++}', t.id, me, message.trim(), _now, read: false)];
    }
    return t.id;
  }

  @override
  Future<String> startWithPerson(String userId, {String? message}) async {
    const everyone = [arvind, priya, sarah, david, marcus];
    final person = everyone.where((p) => p.id == userId).firstOrNull;
    if (person == null) throw ApiError('This person could not be found.', statusCode: 404);
    return _plainWith(person, message);
  }

  @override
  Future<String> startWithSupplier(String vendorId, {String? rfqId, String? message}) async {
    if (message != null && message.trim().isNotEmpty) {
      final t = _thread('c-vikasha');
      t.messages = [...t.messages, _m('local-${_nextId++}', t.id, me, message.trim(), _now)];
    }
    return 'c-vikasha';
  }

  @override
  Future<String> startWithCompany(String companyId, String topic, {String? message}) =>
      startWithSupplier(companyId, message: message);

  @override
  Future<String> startWithJobContact(String jobId, {String? message}) async => _plainWith(arvind, message);

  @override
  Future<String> openForPurchase(String purchaseId) async => 'c-priya';

  @override
  Future<String> openForMentorship(String mentorshipId) async => 'c-priya';

  @override
  Future<String> openForGroupSession(String sessionId) async => 'c-room';

  @override
  Future<String> openForRfq(String rfqId, {String? supplierCompanyId}) async => 'c-vikasha';

  @override
  Future<String> openForApplication(String applicationId) async => 'c-arvind';

  @override
  Future<RecordFacts> record(RecordRef ref) async => switch (ref.type) {
    RecordType.company => const RecordFacts(
      type: RecordType.company,
      id: 'vikasha',
      title: 'Vikasha Aero Tech',
      owner: 'Facade & high-rise maintenance',
      city: 'Bengaluru',
    ),
    _ => RecordFacts(type: ref.type, id: ref.id, title: ref.type.label),
  };

  @override
  Future<List<RecordFacts>> searchRecords(RecordType type, String search) async => [
    if (type == RecordType.company)
      const RecordFacts(
        type: RecordType.company,
        id: 'vikasha',
        title: 'Vikasha Aero Tech',
        owner: 'Facade & high-rise maintenance',
        city: 'Bengaluru',
      ),
  ];
}

class _Thread {
  _Thread({
    required this.id,
    required this.participants,
    required this.messages,
    this.title,
    this.kind,
    this.rfqTitle,
    this.contextLabel,
    this.counterpartCompany,
    this.context,
    this.starred = false,
    // ignore: unused_element_parameter
    this.pinned = false,
  });

  final String id;
  final String? title;
  final List<ChatPerson> participants;
  final ConversationKind? kind;
  final String? rfqTitle;
  final String? contextLabel;
  final ChatCompany? counterpartCompany;
  final ConversationContext? context;
  List<ChatMessage> messages;
  bool starred;
  bool pinned;
}
