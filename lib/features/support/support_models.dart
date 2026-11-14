import 'dart:typed_data';

/// What the support desk reads and writes (`SupportTicketDto` and friends in `@icr/shared`).

String? _str(Object? v) => v is String && v.isNotEmpty ? v : null;

int? _int(Object? v) => v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);

DateTime? _time(Object? v) => v is String ? DateTime.tryParse(v) : null;

Map<String, dynamic> _map(Object? v) => v is Map ? v.cast<String, dynamic>() : const {};

/// The tabs over the list (`FILTERS` of the website's `MyTicketsList`): [api] is the `status` it asks for.
enum SupportFilter {
  open('OPEN_ONLY', 'Open'),
  waiting('AWAITING_USER', 'Waiting on You'),
  resolved('RESOLVED', 'Resolved'),
  all('ALL', 'All');

  const SupportFilter(this.api, this.label);

  final String api;
  final String label;
}

/// A person on a message or an event (`UserSummaryDto`).
class SupportAuthor {
  const SupportAuthor({required this.id, this.firstName = '', this.lastName = '', this.avatarUrl});

  final String id;
  final String firstName;
  final String lastName;
  final String? avatarUrl;

  String get fullName => '$firstName $lastName'.trim();

  String get initials {
    final a = firstName.isNotEmpty ? firstName[0] : '';
    final b = lastName.isNotEmpty ? lastName[0] : '';
    final both = '$a$b'.toUpperCase();
    return both.isEmpty ? '?' : both;
  }

  static SupportAuthor? fromJson(Object? json) {
    if (json is! Map) return null;
    final m = _map(json);
    return SupportAuthor(
      id: m['id'] as String? ?? '',
      firstName: m['firstName'] as String? ?? '',
      lastName: m['lastName'] as String? ?? '',
      avatarUrl: _str(m['avatarUrl']),
    );
  }
}

/// A file on a message (`SupportTicketAttachmentDto`): a private upload, read with the session.
class SupportAttachment {
  const SupportAttachment({required this.id, required this.fileUrl, required this.fileName, this.mimeType});

  final String id;

  /// Root-relative (`/uploads/ab12.pdf`).
  final String fileUrl;
  final String fileName;
  final String? mimeType;

  factory SupportAttachment.fromJson(Map<String, dynamic> json) => SupportAttachment(
    id: json['id'] as String? ?? json['fileUrl'] as String? ?? '',
    fileUrl: json['fileUrl'] as String? ?? '',
    fileName: json['fileName'] as String? ?? 'File',
    mimeType: _str(json['mimeType']),
  );
}

/// One message of the thread (`SupportTicketMessageDto`). An internal note never arrives.
class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.body,
    this.author,
    this.attachments = const [],
    this.createdAt,
  });

  final String id;

  /// Null for a message from ICR with no named person: drawn as "ICR".
  final SupportAuthor? author;
  final String body;
  final List<SupportAttachment> attachments;
  final DateTime? createdAt;

  factory SupportMessage.fromJson(Map<String, dynamic> json) => SupportMessage(
    id: json['id'] as String? ?? '',
    author: SupportAuthor.fromJson(json['author']),
    body: json['body'] as String? ?? '',
    attachments: [
      for (final a in (json['attachments'] as List? ?? const []))
        if (a is Map) SupportAttachment.fromJson(a.cast<String, dynamic>()),
    ],
    createdAt: _time(json['createdAt']),
  );
}

/// One line of the request's history (`SupportTicketEventDto`; the staff-only kinds are dropped by the API).
class SupportEvent {
  const SupportEvent({required this.id, required this.type, this.fromValue, this.toValue, this.note, this.createdAt});

  final String id;
  final String type;
  final String? fromValue;
  final String? toValue;
  final String? note;
  final DateTime? createdAt;

  factory SupportEvent.fromJson(Map<String, dynamic> json) => SupportEvent(
    id: json['id'] as String? ?? '',
    type: json['type'] as String? ?? '',
    fromValue: _str(json['fromValue']),
    toValue: _str(json['toValue']),
    note: _str(json['note']),
    createdAt: _time(json['createdAt']),
  );
}

/// A request, as the person who raised it sees it (`SupportTicketDto`). A list row carries no [messages] or
/// [events]; the detail does.
class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.reference,
    required this.subject,
    required this.category,
    required this.status,
    this.priority = 'NORMAL',
    this.contextType = 'NONE',
    this.contextId,
    this.contextLabel,
    this.contextHref,
    this.firstResponseHours = 24,
    this.firstRespondedAt,
    this.resolvedAt,
    this.closedAt,
    this.ratingScore,
    this.reopenable = false,
    this.messages,
    this.events,
    this.messageCount = 0,
    this.lastActivityAt,
    this.createdAt,
  });

  final String id;

  /// The number quoted in email and read out on a call: shown as `ICR-<n>`.
  final int reference;
  final String subject;
  final String category;
  final String status;
  final String priority;
  final String contextType;
  final String? contextId;

  /// What the request is attached to and where it lives, resolved by the API.
  final String? contextLabel;
  final String? contextHref;
  final int firstResponseHours;
  final DateTime? firstRespondedAt;
  final DateTime? resolvedAt;
  final DateTime? closedAt;
  final int? ratingScore;

  /// The requester may still reopen it.
  final bool reopenable;
  final List<SupportMessage>? messages;
  final List<SupportEvent>? events;
  final int messageCount;
  final DateTime? lastActivityAt;
  final DateTime? createdAt;

  bool get closed => status == 'CLOSED';
  bool get waitingOnYou => status == 'AWAITING_USER';
  bool get resolved => status == 'RESOLVED';
  bool get rated => ratingScore != null;

  factory SupportTicket.fromJson(Map<String, dynamic> json) => SupportTicket(
    id: json['id'] as String? ?? '',
    reference: _int(json['reference']) ?? 0,
    subject: json['subject'] as String? ?? '',
    category: json['category'] as String? ?? 'OTHER',
    status: json['status'] as String? ?? 'NEW',
    priority: json['priority'] as String? ?? 'NORMAL',
    contextType: json['contextType'] as String? ?? 'NONE',
    contextId: _str(json['contextId']),
    contextLabel: _str(json['contextLabel']),
    contextHref: _str(json['contextHref']),
    firstResponseHours: _int(json['firstResponseHours']) ?? 24,
    firstRespondedAt: _time(json['firstRespondedAt']),
    resolvedAt: _time(json['resolvedAt']),
    closedAt: _time(json['closedAt']),
    ratingScore: _int(json['ratingScore']),
    reopenable: json['reopenable'] == true,
    messages: json['messages'] is List
        ? [
            for (final m in (json['messages'] as List))
              if (m is Map) SupportMessage.fromJson(m.cast<String, dynamic>()),
          ]
        : null,
    events: json['events'] is List
        ? [
            for (final e in (json['events'] as List))
              if (e is Map) SupportEvent.fromJson(e.cast<String, dynamic>()),
          ]
        : null,
    messageCount: _int(json['messageCount']) ?? 0,
    lastActivityAt: _time(json['lastActivityAt']),
    createdAt: _time(json['createdAt']),
  );

  /// This request with the fields an action's answer carries: the answer is the list-shaped ticket (no thread),
  /// so the thread already on screen is kept until it is read again.
  SupportTicket withAnswer(SupportTicket answer) => SupportTicket(
    id: id,
    reference: answer.reference == 0 ? reference : answer.reference,
    subject: answer.subject.isEmpty ? subject : answer.subject,
    category: answer.category,
    status: answer.status,
    priority: answer.priority,
    contextType: contextType,
    contextId: contextId,
    contextLabel: contextLabel,
    contextHref: contextHref,
    firstResponseHours: answer.firstResponseHours,
    firstRespondedAt: answer.firstRespondedAt,
    resolvedAt: answer.resolvedAt,
    closedAt: answer.closedAt,
    ratingScore: answer.ratingScore,
    reopenable: answer.reopenable,
    messages: answer.messages ?? messages,
    events: answer.events ?? events,
    messageCount: answer.messageCount,
    lastActivityAt: answer.lastActivityAt ?? lastActivityAt,
    createdAt: createdAt,
  );
}

/// A page of the member's requests (`Paginated<SupportTicketDto>`).
class TicketPage {
  const TicketPage({required this.items, required this.page, required this.totalPages, required this.total});

  final List<SupportTicket> items;
  final int page;
  final int totalPages;
  final int total;

  bool get hasNext => page < totalPages;

  factory TicketPage.fromJson(Map<String, dynamic> json) {
    final meta = _map(json['meta']);
    return TicketPage(
      items: [
        for (final t in (json['data'] as List? ?? const []))
          if (t is Map) SupportTicket.fromJson(t.cast<String, dynamic>()),
      ],
      page: _int(meta['page']) ?? 1,
      totalPages: _int(meta['totalPages']) ?? 1,
      total: _int(meta['total']) ?? 0,
    );
  }
}

/// One knowledge-base article (`SupportFaqDto`).
class SupportFaq {
  const SupportFaq({required this.id, required this.question, required this.answer, this.category});

  final String id;
  final String question;
  final String answer;
  final String? category;

  factory SupportFaq.fromJson(Map<String, dynamic> json) => SupportFaq(
    id: json['id'] as String? ?? '',
    question: json['question'] as String? ?? '',
    answer: json['answer'] as String? ?? '',
    category: _str(json['category']),
  );
}

/// The ICR person looking after this member (`AccountManagerDto`).
class AccountManager {
  const AccountManager({required this.name, required this.email, this.phone, this.avatarUrl, this.note});

  final String name;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final String? note;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final both = parts.length == 1 ? parts.first[0] : '${parts.first[0]}${parts.last[0]}';
    return both.toUpperCase();
  }

  /// Null when the body names nobody (the API answers an empty body for "no account manager").
  static AccountManager? fromJson(Object? json) {
    if (json is! Map) return null;
    final m = _map(json);
    final manager = _map(m['manager']);
    if (manager.isEmpty) return null;
    final email = manager['email'] as String? ?? '';
    final name = '${manager['firstName'] ?? ''} ${manager['lastName'] ?? ''}'.trim();
    if (name.isEmpty && email.isEmpty) return null;
    return AccountManager(
      name: name,
      email: email,
      phone: _str(manager['phone']),
      avatarUrl: _str(manager['avatarUrl']),
      note: _str(m['note']),
    );
  }
}

/// A file the person chose on their phone, ready to upload.
class SupportPickedFile {
  const SupportPickedFile({required this.bytes, required this.name, this.mimeType});

  final Uint8List bytes;
  final String name;
  final String? mimeType;

  /// The type the API takes the upload as: named from the file when the phone did not say.
  String get contentType {
    if (mimeType != null && mimeType!.isNotEmpty && mimeType != 'application/octet-stream') return mimeType!;
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    return 'image/jpeg';
  }
}

/// A file already uploaded (`POST /uploads?purpose=support`), carried on a message as the API expects it.
class SupportAttachmentDraft {
  const SupportAttachmentDraft({required this.fileUrl, required this.fileName, this.mimeType, this.sizeBytes});

  final String fileUrl;
  final String fileName;
  final String? mimeType;
  final int? sizeBytes;

  Map<String, Object?> toJson() => {
    'fileUrl': fileUrl,
    'fileName': fileName,
    if (mimeType != null) 'mimeType': mimeType,
    if (sizeBytes != null) 'sizeBytes': sizeBytes,
  };
}

/// A new request (`RaiseSupportTicketInput`).
class RaiseDraft {
  const RaiseDraft({
    required this.subject,
    required this.category,
    required this.body,
    this.contextType,
    this.contextId,
    this.attachments = const [],
  });

  final String subject;
  final String category;
  final String body;

  /// Sent only when it is not `NONE`.
  final String? contextType;
  final String? contextId;
  final List<SupportAttachmentDraft> attachments;

  Map<String, Object?> toJson() => {
    'subject': subject.trim(),
    'category': category,
    'body': body.trim(),
    if (contextType != null && contextType != 'NONE') ...{'contextType': contextType, 'contextId': ?contextId},
    if (attachments.isNotEmpty) 'attachments': [for (final a in attachments) a.toJson()],
  };
}

/// What the desk answers to a new request: enough to open its thread.
class SupportTicketRaised {
  const SupportTicketRaised({required this.id, required this.reference});

  final String id;
  final int reference;
}

/// Asks the phone for files to attach, up to [max]; empty when the person backs out. A screen is handed one so a
/// test can stand in for the system's file chooser.
typedef FilePickFn = Future<List<SupportPickedFile>> Function(int max);
