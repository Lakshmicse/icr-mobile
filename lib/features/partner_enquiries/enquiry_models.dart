/// An enquiry a partner institute received from one of its course pages or its own page (the website's
/// `LearningLead`, read from `GET /learning/admin/leads`).
class Enquiry {
  const Enquiry({
    required this.id,
    required this.name,
    required this.email,
    required this.kind,
    required this.status,
    required this.revealed,
    required this.createdAt,
    this.phone,
    this.company,
    this.headcount,
    this.message,
    this.note,
    this.courseCode,
    this.courseTitle,
    this.source = 'course',
  });

  final String id;
  final String name;

  /// Masked (`a•••••@x.com`) when [revealed] is false: past the plan's monthly number.
  final String email;
  final String? phone;
  final String? company;
  final int? headcount;
  final String? message;

  /// `INDIVIDUAL` or `CORPORATE`.
  final String kind;

  /// `NEW`, `CONTACTED`, `CONVERTED` or `CLOSED`.
  final String status;

  /// Whether the plan's monthly number reached this enquiry, so its contact details are open.
  final bool revealed;

  /// The institute's own working note.
  final String? note;
  final String? courseCode;
  final String? courseTitle;

  /// `course` or `institute`: which page the form was on.
  final String source;
  final DateTime createdAt;

  bool get corporate => kind == 'CORPORATE';

  Enquiry copyWith({String? status, String? note, bool clearNote = false}) => Enquiry(
    id: id,
    name: name,
    email: email,
    kind: kind,
    status: status ?? this.status,
    revealed: revealed,
    createdAt: createdAt,
    phone: phone,
    company: company,
    headcount: headcount,
    message: message,
    note: clearNote ? null : (note ?? this.note),
    courseCode: courseCode,
    courseTitle: courseTitle,
    source: source,
  );

  factory Enquiry.fromJson(Map<String, dynamic> json) {
    final course = json['course'];
    return Enquiry(
      id: '${json['id']}',
      name: '${json['name'] ?? ''}',
      email: '${json['email'] ?? ''}',
      phone: _text(json['phone']),
      company: _text(json['company']),
      headcount: (json['headcount'] as num?)?.toInt(),
      message: _text(json['message']),
      kind: '${json['kind'] ?? 'INDIVIDUAL'}',
      status: '${json['status'] ?? 'NEW'}',
      revealed: json['revealed'] != false,
      note: _text(json['note']),
      courseCode: course is Map ? _text(course['code']) : null,
      courseTitle: course is Map ? _text(course['title']) : null,
      source: '${json['source'] ?? 'course'}',
      createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}') ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static String? _text(Object? v) {
    if (v == null) return null;
    final s = '$v'.trim();
    return s.isEmpty ? null : s;
  }
}

/// Where this month stands against the plan's monthly number of enquiries with contact details (`reveal` on the
/// list). [monthly] null means every enquiry arrives with its details.
class EnquiryReveal {
  const EnquiryReveal({this.monthly, required this.receivedThisMonth, required this.revealedThisMonth});

  final int? monthly;
  final int receivedThisMonth;
  final int revealedThisMonth;

  /// The website's banner, when the plan sets a number.
  String? get sentence {
    final n = monthly;
    if (n == null) return null;
    final s =
        '$revealedThisMonth of $receivedThisMonth enquiries this month came with contact details. Your plan '
        'includes $n a month.';
    return receivedThisMonth > n ? '$s The rest are here, with the details masked.' : s;
  }

  bool get overPlan => monthly != null && receivedThisMonth > monthly!;

  factory EnquiryReveal.fromJson(Map<String, dynamic> json) => EnquiryReveal(
    monthly: (json['monthly'] as num?)?.toInt(),
    receivedThisMonth: (json['receivedThisMonth'] as num?)?.toInt() ?? 0,
    revealedThisMonth: (json['revealedThisMonth'] as num?)?.toInt() ?? 0,
  );
}

/// One page of the institute's enquiries, newest first.
class EnquiriesPage {
  const EnquiriesPage({required this.rows, required this.page, required this.totalPages, this.reveal});

  final List<Enquiry> rows;
  final int page;
  final int totalPages;
  final EnquiryReveal? reveal;

  bool get hasMore => page < totalPages;

  factory EnquiriesPage.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'];
    final rows = json['data'];
    return EnquiriesPage(
      rows: [
        for (final r in rows is List ? rows : const [])
          if (r is Map) Enquiry.fromJson(r.cast<String, dynamic>()),
      ],
      page: meta is Map ? (meta['page'] as num?)?.toInt() ?? 1 : 1,
      totalPages: meta is Map ? (meta['totalPages'] as num?)?.toInt() ?? 1 : 1,
      reveal: json['reveal'] is Map ? EnquiryReveal.fromJson((json['reveal'] as Map).cast<String, dynamic>()) : null,
    );
  }
}

/// The statuses an enquiry moves through, in the website's order, with its words (`LEARNING_LEAD_STATUS_LABELS`).
const enquiryStatuses = ['NEW', 'CONTACTED', 'CONVERTED', 'CLOSED'];

String enquiryStatusLabel(String status) => switch (status) {
  'NEW' => 'New',
  'CONTACTED' => 'Contacted',
  'CONVERTED' => 'Converted',
  'CLOSED' => 'Closed',
  _ => status,
};

/// `LEARNING_LEAD_KIND_LABELS`.
String enquiryKindLabel(String kind) => kind == 'CORPORATE' ? 'Corporate training' : 'Individual';
