import 'dart:convert';
import 'dart:typed_data';

import '../../core/api/api_error.dart';
import 'support_models.dart';
import 'support_repository.dart';

/// The support desk over a small in-memory sample, for design review (`FEED_SOURCE=demo`) and for tests. Every call
/// is written to [calls]; [failures] makes the named call refuse with an [ApiError].
class DemoSupportRepository implements SupportRepository {
  DemoSupportRepository({List<SupportTicket>? tickets, List<SupportFaq>? faqs, this.manager, DateTime? now})
    : _now = now ?? DateTime.now() {
    _tickets = [...(tickets ?? _sample(_now))];
    _faqs = [...(faqs ?? _sampleFaqs)];
  }

  final DateTime _now;
  late List<SupportTicket> _tickets;
  late List<SupportFaq> _faqs;

  /// Who looks after the member; null for nobody.
  AccountManager? manager;

  final List<String> calls = [];
  final Map<String, ApiError> failures = {};
  var _next = 100;

  /// Bytes returned for any private file.
  Uint8List fileContent = Uint8List.fromList(utf8.encode('Sample attachment'));

  void _enter(String name, [String detail = '']) {
    calls.add(detail.isEmpty ? name : '$name $detail');
    final failure = failures[name];
    if (failure != null) throw failure;
  }

  int count(String name) => calls.where((c) => c == name || c.startsWith('$name ')).length;

  @override
  Future<TicketPage> tickets({String status = 'OPEN_ONLY', String? search, int page = 1, int limit = 20}) async {
    _enter('tickets', '$status ${search ?? ''} $page'.trim());
    final q = search?.trim().toLowerCase() ?? '';
    final rows = [
      for (final t in _tickets)
        if (_matches(t, status) && (q.isEmpty || t.subject.toLowerCase().contains(q))) t,
    ]..sort((a, b) => (b.lastActivityAt ?? _now).compareTo(a.lastActivityAt ?? _now));
    final pages = rows.isEmpty ? 1 : (rows.length / limit).ceil();
    final from = (page - 1) * limit;
    final slice = from >= rows.length ? <SupportTicket>[] : rows.sublist(from, (from + limit).clamp(0, rows.length));
    return TicketPage(items: [for (final t in slice) _listRow(t)], page: page, totalPages: pages, total: rows.length);
  }

  static bool _matches(SupportTicket t, String status) => switch (status) {
    'OPEN_ONLY' => const {'NEW', 'OPEN', 'AWAITING_USER'}.contains(t.status),
    'ALL' => true,
    _ => t.status == status,
  };

  SupportTicket _listRow(SupportTicket t) => SupportTicket(
    id: t.id,
    reference: t.reference,
    subject: t.subject,
    category: t.category,
    status: t.status,
    contextLabel: t.contextLabel,
    contextHref: t.contextHref,
    firstResponseHours: t.firstResponseHours,
    firstRespondedAt: t.firstRespondedAt,
    ratingScore: t.ratingScore,
    reopenable: t.reopenable,
    messageCount: t.messages?.length ?? t.messageCount,
    lastActivityAt: t.lastActivityAt,
    createdAt: t.createdAt,
  );

  SupportTicket _find(String id) {
    final i = _tickets.indexWhere((t) => t.id == id);
    if (i < 0) throw ApiError('Request not found.', statusCode: 404);
    return _tickets[i];
  }

  void _replace(SupportTicket t) {
    final i = _tickets.indexWhere((x) => x.id == t.id);
    _tickets[i] = t;
  }

  @override
  Future<SupportTicket> ticket(String id) async {
    _enter('ticket', id);
    return _find(id);
  }

  @override
  Future<SupportTicketRaised> raise(RaiseDraft draft) async {
    _enter('raise', draft.subject);
    final id = 'demo-${_next++}';
    final reference = _next + 20;
    final at = _now;
    _tickets.insert(
      0,
      SupportTicket(
        id: id,
        reference: reference,
        subject: draft.subject,
        category: draft.category,
        status: 'NEW',
        contextType: draft.contextType ?? 'NONE',
        contextId: draft.contextId,
        firstResponseHours: 24,
        messages: [
          SupportMessage(
            id: 'm-$id',
            body: draft.body,
            author: const SupportAuthor(id: 'me', firstName: 'Priya', lastName: 'Rao'),
            attachments: [
              for (final a in draft.attachments)
                SupportAttachment(id: a.fileUrl, fileUrl: a.fileUrl, fileName: a.fileName, mimeType: a.mimeType),
            ],
            createdAt: at,
          ),
        ],
        events: [SupportEvent(id: 'e-$id', type: 'RAISED', createdAt: at)],
        messageCount: 1,
        lastActivityAt: at,
        createdAt: at,
      ),
    );
    return SupportTicketRaised(id: id, reference: reference);
  }

  @override
  Future<SupportTicket> reply(String id, String body, List<SupportAttachmentDraft> attachments) async {
    _enter('reply', id);
    final t = _find(id);
    if (t.closed) throw ApiError('This request is closed. Please raise a new one.', statusCode: 400);
    final messages = [
      ...?t.messages,
      SupportMessage(
        id: 'm-${_next++}',
        body: body.trim(),
        author: const SupportAuthor(id: 'me', firstName: 'Priya', lastName: 'Rao'),
        attachments: [
          for (final a in attachments)
            SupportAttachment(id: a.fileUrl, fileUrl: a.fileUrl, fileName: a.fileName, mimeType: a.mimeType),
        ],
        createdAt: _now,
      ),
    ];
    _replace(_copy(t, status: t.waitingOnYou ? 'OPEN' : t.status, messages: messages, messageCount: messages.length));
    return _listRow(_find(id));
  }

  @override
  Future<SupportTicket> reopen(String id) async {
    _enter('reopen', id);
    final t = _find(id);
    if (!t.resolved) throw ApiError('Only a resolved request can be reopened.', statusCode: 400);
    _replace(_copy(t, status: 'OPEN', reopenable: false));
    return _listRow(_find(id));
  }

  @override
  Future<SupportTicket> rate(String id, int score) async {
    _enter('rate', '$id $score');
    final t = _find(id);
    if (t.rated) throw ApiError('You have already rated this request.', statusCode: 400);
    _replace(_copy(t, ratingScore: score));
    return _listRow(_find(id));
  }

  SupportTicket _copy(
    SupportTicket t, {
    String? status,
    List<SupportMessage>? messages,
    int? messageCount,
    bool? reopenable,
    int? ratingScore,
  }) => SupportTicket(
    id: t.id,
    reference: t.reference,
    subject: t.subject,
    category: t.category,
    status: status ?? t.status,
    priority: t.priority,
    contextType: t.contextType,
    contextId: t.contextId,
    contextLabel: t.contextLabel,
    contextHref: t.contextHref,
    firstResponseHours: t.firstResponseHours,
    firstRespondedAt: t.firstRespondedAt,
    resolvedAt: t.resolvedAt,
    closedAt: t.closedAt,
    ratingScore: ratingScore ?? t.ratingScore,
    reopenable: reopenable ?? t.reopenable,
    messages: messages ?? t.messages,
    events: t.events,
    messageCount: messageCount ?? t.messageCount,
    lastActivityAt: _now,
    createdAt: t.createdAt,
  );

  @override
  Future<List<SupportFaq>> faqs({String? category, String? search, int limit = 4}) async {
    _enter('faqs', category ?? '');
    return [
      for (final f in _faqs)
        if (category == null || f.category == null || f.category == category) f,
    ].take(limit).toList();
  }

  @override
  Future<void> markFaqViewed(String id) async => calls.add('viewed $id');

  @override
  Future<void> markFaqHelpful(String id) async => calls.add('helpful $id');

  @override
  Future<AccountManager?> accountManager() async {
    _enter('accountManager');
    return manager;
  }

  @override
  Future<SupportAttachmentDraft> upload(SupportPickedFile file) async {
    _enter('upload', file.name);
    return SupportAttachmentDraft(
      fileUrl: '/uploads/${file.name}',
      fileName: file.name,
      mimeType: file.contentType,
      sizeBytes: file.bytes.length,
    );
  }

  @override
  Future<Uint8List> fileBytes(String url) async {
    _enter('fileBytes', url);
    return fileContent;
  }

  // --- the sample ---------------------------------------------------------------------------------------------

  static List<SupportTicket> _sample(DateTime now) {
    DateTime ago(Duration d) => now.subtract(d);
    const priya = SupportAuthor(id: 'me', firstName: 'Priya', lastName: 'Rao');
    const asha = SupportAuthor(id: 'staff-1', firstName: 'Asha', lastName: 'Nair');
    return [
      SupportTicket(
        id: 'demo-1',
        reference: 41,
        subject: 'Payment taken twice for the Gold plan',
        category: 'BILLING_PAYMENTS',
        status: 'AWAITING_USER',
        firstResponseHours: 12,
        firstRespondedAt: ago(const Duration(hours: 20)),
        messages: [
          SupportMessage(
            id: 'm1',
            author: priya,
            body: 'I was charged twice for the Gold plan on 2 November.',
            createdAt: ago(const Duration(days: 1, hours: 2)),
          ),
          SupportMessage(
            id: 'm2',
            author: asha,
            body: 'Sorry about that. Could you send the bank statement line for both charges?',
            createdAt: ago(const Duration(hours: 20)),
          ),
        ],
        events: [
          SupportEvent(id: 'e1', type: 'RAISED', createdAt: ago(const Duration(days: 1, hours: 2))),
          SupportEvent(id: 'e2', type: 'FIRST_RESPONSE', createdAt: ago(const Duration(hours: 20))),
          SupportEvent(
            id: 'e3',
            type: 'STATUS_CHANGED',
            fromValue: 'NEW',
            toValue: 'AWAITING_USER',
            createdAt: ago(const Duration(hours: 20)),
          ),
        ],
        messageCount: 2,
        lastActivityAt: ago(const Duration(hours: 20)),
        createdAt: ago(const Duration(days: 1, hours: 2)),
      ),
      SupportTicket(
        id: 'demo-2',
        reference: 38,
        subject: 'Certificate PDF will not download',
        category: 'LEARNING',
        status: 'RESOLVED',
        firstResponseHours: 12,
        firstRespondedAt: ago(const Duration(days: 3)),
        resolvedAt: ago(const Duration(days: 2)),
        reopenable: true,
        messages: [
          SupportMessage(
            id: 'm3',
            author: priya,
            body: 'The certificate button does nothing.',
            createdAt: ago(const Duration(days: 4)),
          ),
          SupportMessage(
            id: 'm4',
            author: asha,
            body: 'Fixed. Please try again.',
            createdAt: ago(const Duration(days: 2)),
          ),
        ],
        events: [
          SupportEvent(id: 'e4', type: 'RAISED', createdAt: ago(const Duration(days: 4))),
          SupportEvent(
            id: 'e5',
            type: 'STATUS_CHANGED',
            fromValue: 'NEW',
            toValue: 'RESOLVED',
            createdAt: ago(const Duration(days: 2)),
          ),
        ],
        messageCount: 2,
        lastActivityAt: ago(const Duration(days: 2)),
        createdAt: ago(const Duration(days: 4)),
      ),
      SupportTicket(
        id: 'demo-3',
        reference: 22,
        subject: 'Statement download fails',
        category: 'OTHER',
        status: 'CLOSED',
        firstResponseHours: 12,
        firstRespondedAt: ago(const Duration(days: 30)),
        ratingScore: 5,
        messages: [
          SupportMessage(
            id: 'm5',
            author: priya,
            body: 'The statement comes back empty.',
            createdAt: ago(const Duration(days: 31)),
          ),
        ],
        events: [SupportEvent(id: 'e6', type: 'RAISED', createdAt: ago(const Duration(days: 31)))],
        messageCount: 3,
        lastActivityAt: ago(const Duration(days: 20)),
        createdAt: ago(const Duration(days: 31)),
      ),
    ];
  }

  static const _sampleFaqs = [
    SupportFaq(
      id: 'faq-1',
      question: 'How do I get verified?',
      answer: 'Submit your GST and certifications from your company profile.',
    ),
    SupportFaq(
      id: 'faq-2',
      question: 'Where is my invoice?',
      answer: 'Your plan history lists every receipt.',
      category: 'BILLING_PAYMENTS',
    ),
  ];
}
