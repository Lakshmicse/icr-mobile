/// What the company workspace reads: the active company as `GET /users/me/profile` returns it (its row, its supplier
/// listing and its completeness), the company check (`/employer-verification`), the supplier level
/// (`/vendors/me/access`, the evidence and the history), the plans, the team's size and the certifications.
library;

String? _str(Object? v) {
  if (v == null) return null;
  final s = '$v'.trim();
  return s.isEmpty ? null : s;
}

int? _int(Object? v) => v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);

double? _num(Object? v) => v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);

Map<String, dynamic> _map(Object? v) => v is Map ? v.cast<String, dynamic>() : const {};

List<String> _strings(Object? v) => v is List ? [for (final x in v) '$x'] : const [];

DateTime? _date(Object? v) => v == null ? null : DateTime.tryParse('$v');

/// The company row as the profile endpoint returns it (`MyProfile.company`). [raw] keeps every column, so the field
/// table can read a value by its column name (`company.text('gstNumber')`).
class CompanyDetails {
  const CompanyDetails(this.raw);

  final Map<String, dynamic> raw;

  factory CompanyDetails.fromJson(Map<String, dynamic> json) => CompanyDetails(Map<String, dynamic>.from(json));

  /// A column's text, trimmed; null when blank.
  String? text(String column) => _str(raw[column]);

  String get id => '${raw['id'] ?? ''}';
  String get name => text('name') ?? '';
  String? get legalName => text('legalName');
  String? get legalStructure => text('legalStructure');
  String? get description => text('description');
  String? get logoUrl => text('logoUrl');
  String? get website => text('website');
  String? get email => text('email');
  String? get phone => text('phone');
  String? get gstNumber => text('gstNumber');
  String? get panNumber => text('panNumber');
  String? get addressLine => text('addressLine');
  String? get city => text('city');
  String? get state => text('state');
  String? get postalCode => text('postalCode');
  String? get country => text('country');
  String? get size => text('size');
  String? get industry => text('industry');
  int? get foundedYear => _int(raw['foundedYear']);
  String? get presence => text('presence');
  String? get contactName => text('contactName');
  String? get contactDesignation => text('contactDesignation');
  String? get contactAltPhone => text('contactAltPhone');
  String? get incorporationDocUrl => text('incorporationDocUrl');
  String? get incorporationDocName => text('incorporationDocName');
  String? get gstDocUrl => text('gstDocUrl');
  String? get gstDocName => text('gstDocName');
  String? get panDocUrl => text('panDocUrl');
  String? get panDocName => text('panDocName');

  /// `PENDING`, `VERIFIED`, `REJECTED` or `DOCS_REQUESTED`: the company check writes through to this, so the
  /// verified lock on the identity fields reads it.
  String? get verificationStatus => text('verificationStatus');

  /// The same row with [patch] laid over it: what the API would hold after a save.
  CompanyDetails merged(Map<String, Object?> patch) => CompanyDetails({...raw, ...patch});
}

/// The company's supplier listing (`MyProfile.vendor`), present once it sells.
class SupplierListing {
  const SupplierListing({
    required this.id,
    this.headline,
    this.categories = const [],
    this.serviceAreas = const [],
    this.yearsExperience,
    this.verificationLevel,
    this.rating,
    this.ratingCount = 0,
  });

  final String id;
  final String? headline;
  final List<String> categories;
  final List<String> serviceAreas;
  final int? yearsExperience;

  /// The supplier ladder's rung — never the company row's, which the company check writes through to.
  final String? verificationLevel;
  final double? rating;
  final int ratingCount;

  factory SupplierListing.fromJson(Map<String, dynamic> json) => SupplierListing(
    id: '${json['id']}',
    headline: _str(json['headline']),
    categories: _strings(json['categories']),
    serviceAreas: _strings(json['serviceAreas']),
    yearsExperience: _int(json['yearsExperience']),
    verificationLevel: _str(json['verificationLevel']),
    rating: _num(json['rating']),
    ratingCount: _int(json['ratingCount']) ?? 0,
  );
}

/// A completeness score and what is still missing (`Completeness`).
class Completeness {
  const Completeness({required this.score, required this.missing});

  final int score;
  final List<String> missing;

  factory Completeness.fromJson(Map<String, dynamic> json) =>
      Completeness(score: _int(json['score']) ?? 0, missing: _strings(json['missing']));
}

/// `GET /users/me/profile`, the parts the company workspace reads: who is signed in (their role and the company they
/// act for), the company, its listing and the company's own completeness — never blended with the person's.
class CompanyProfile {
  const CompanyProfile({required this.role, this.activeCompanyId, this.company, this.vendor, this.companyCompleteness});

  /// The role the person holds at the company they act for (their own, with none active).
  final String role;

  /// `user.companyId`: null while the person acts as themselves.
  final String? activeCompanyId;
  final CompanyDetails? company;
  final SupplierListing? vendor;
  final Completeness? companyCompleteness;

  /// The company sells: it has a supplier listing. Read from the profile, as the website does, never from a second
  /// call that could arrive after the tabs were decided.
  bool get sells => vendor != null;

  /// A company is acted for and present.
  bool get hasCompany => activeCompanyId != null && company != null;

  factory CompanyProfile.fromJson(Map<String, dynamic> json) {
    final user = _map(json['user']);
    final company = json['company'];
    final vendor = json['vendor'];
    final completeness = json['companyCompleteness'];
    return CompanyProfile(
      role: '${user['role'] ?? 'PROFESSIONAL'}',
      activeCompanyId: _str(user['companyId']),
      company: company is Map ? CompanyDetails.fromJson(company.cast<String, dynamic>()) : null,
      vendor: vendor is Map ? SupplierListing.fromJson(vendor.cast<String, dynamic>()) : null,
      companyCompleteness: completeness is Map ? Completeness.fromJson(completeness.cast<String, dynamic>()) : null,
    );
  }

  CompanyProfile copyWith({CompanyDetails? company, Completeness? companyCompleteness}) => CompanyProfile(
    role: role,
    activeCompanyId: activeCompanyId,
    company: company ?? this.company,
    vendor: vendor,
    companyCompleteness: companyCompleteness ?? this.companyCompleteness,
  );
}

/// ICR asked a verified company for fresh copies of named documents (`ReverifyRequestDto`): it stays verified until
/// [dueAt], and the request waits on ICR once [submittedAt] is set.
class ReverifyRequest {
  const ReverifyRequest({
    required this.dueAt,
    required this.documents,
    this.requestedAt,
    this.reason,
    this.note,
    this.submittedAt,
  });

  final DateTime? requestedAt;
  final DateTime dueAt;

  /// `EmployerDocumentKind`s: `PAN_CARD`, `GST_CERTIFICATE`, `INCORPORATION_PROOF`…
  final List<String> documents;
  final String? reason;
  final String? note;
  final DateTime? submittedAt;

  bool get open => submittedAt == null;

  static ReverifyRequest? fromJson(Object? json) {
    if (json is! Map) return null;
    final due = _date(json['dueAt']);
    if (due == null) return null;
    return ReverifyRequest(
      requestedAt: _date(json['requestedAt']),
      dueAt: due,
      documents: _strings(json['documents']),
      reason: _str(json['reason']),
      note: _str(json['note']),
      submittedAt: _date(json['submittedAt']),
    );
  }
}

/// What the employer may do (`GET /employer-verification/gate`): `verified` is the one bit every gate reads.
class EmployerGate {
  const EmployerGate({
    required this.verified,
    this.status,
    this.canPublishJobs = false,
    this.decisionNote,
    this.decisionReason,
    this.suspended = false,
    this.reverify,
  });

  final bool verified;

  /// `SUBMITTED`, `DOCS_REQUESTED`, `VERIFIED`, `REJECTED`, `SUSPENDED`; null when nothing was ever filed.
  final String? status;
  final bool canPublishJobs;
  final String? decisionNote;
  final String? decisionReason;
  final bool suspended;
  final ReverifyRequest? reverify;

  factory EmployerGate.fromJson(Map<String, dynamic> json) => EmployerGate(
    verified: json['verified'] == true,
    status: _str(json['status']),
    canPublishJobs: json['canPublishJobs'] == true,
    decisionNote: _str(json['decisionNote']),
    decisionReason: _str(json['decisionReason']),
    suspended: json['suspended'] == true,
    reverify: ReverifyRequest.fromJson(json['reverify']),
  );
}

/// A document on the dossier as filed.
class DossierDocument {
  const DossierDocument({required this.kind, this.name, this.url});

  final String kind;
  final String? name;
  final String? url;

  factory DossierDocument.fromJson(Map<String, dynamic> json) =>
      DossierDocument(kind: '${json['kind']}', name: _str(json['name']), url: _str(json['url']));
}

/// The company check as filed (`GET /employer-verification/me`, `EmployerVerificationDto`).
class EmployerDossier {
  const EmployerDossier({
    required this.id,
    required this.status,
    required this.legalName,
    required this.panNumber,
    required this.gstNotRegistered,
    required this.attemptCount,
    this.legalStructure,
    this.gstNumber,
    this.submittedAt,
    this.reviewedAt,
    this.decisionNote,
    this.decisionReason,
    this.reverify,
    this.documents = const [],
  });

  final String id;
  final String status;
  final String legalName;
  final String? legalStructure;
  final String panNumber;
  final bool gstNotRegistered;
  final String? gstNumber;
  final DateTime? submittedAt;
  final int attemptCount;
  final DateTime? reviewedAt;
  final String? decisionNote;
  final String? decisionReason;
  final ReverifyRequest? reverify;
  final List<DossierDocument> documents;

  factory EmployerDossier.fromJson(Map<String, dynamic> json) => EmployerDossier(
    id: '${json['id']}',
    status: '${json['status']}',
    legalName: _str(json['legalName']) ?? '',
    legalStructure: _str(json['legalStructure']),
    panNumber: _str(json['panNumber']) ?? '',
    gstNotRegistered: json['gstNotRegistered'] == true,
    gstNumber: _str(json['gstNumber']),
    submittedAt: _date(json['submittedAt']),
    attemptCount: _int(json['attemptCount']) ?? 1,
    reviewedAt: _date(json['reviewedAt']),
    decisionNote: _str(json['decisionNote']),
    decisionReason: _str(json['decisionReason']),
    reverify: ReverifyRequest.fromJson(json['reverify']),
    documents: [
      for (final d in json['documents'] is List ? json['documents'] as List : const [])
        if (d is Map) DossierDocument.fromJson(d.cast<String, dynamic>()),
    ],
  );
}

/// The dossier the company files (`POST /employer-verification/submit`, `SubmitEmployerVerificationDto`).
class EmployerDossierDraft {
  const EmployerDossierDraft({
    required this.legalName,
    required this.legalStructure,
    required this.panNumber,
    required this.gstNotRegistered,
    required this.addressLine,
    required this.city,
    required this.country,
    required this.contactEmail,
    this.gstNumber,
    this.state,
    this.postalCode,
    this.website,
    this.contactPhone,
    this.documents = const [],
  });

  final String legalName;
  final String legalStructure;
  final String panNumber;
  final bool gstNotRegistered;
  final String? gstNumber;
  final String addressLine;
  final String city;
  final String? state;
  final String? postalCode;
  final String country;
  final String? website;
  final String contactEmail;
  final String? contactPhone;
  final List<DossierDocument> documents;

  Map<String, Object?> toJson() => {
    'legalName': legalName,
    'legalStructure': legalStructure,
    'panNumber': panNumber,
    'gstNotRegistered': gstNotRegistered,
    'gstNumber': ?gstNumber,
    'addressLine': addressLine,
    'city': city,
    'state': ?state,
    'postalCode': ?postalCode,
    'country': country,
    'website': ?website,
    'contactEmail': contactEmail,
    'contactPhone': ?contactPhone,
    'documents': [
      for (final d in documents) {'kind': d.kind, 'url': d.url, 'name': ?d.name},
    ],
  };
}

/// Where the supplier listing stands (`GET /vendors/me/access`): its level, a level under review, and what ICR asked.
class SupplierAccess {
  const SupplierAccess({
    this.vendorId,
    this.verificationLevel,
    this.pendingLevel,
    this.verificationStatus,
    this.docsRequestMessage,
    this.trustScore,
    this.ratingCount = 0,
  });

  final String? vendorId;
  final String? verificationLevel;
  final String? pendingLevel;
  final String? verificationStatus;
  final String? docsRequestMessage;
  final double? trustScore;
  final int ratingCount;

  bool get docsRequested => verificationStatus == 'DOCS_REQUESTED' && pendingLevel != null;

  factory SupplierAccess.fromJson(Map<String, dynamic> json) => SupplierAccess(
    vendorId: _str(json['vendorId']),
    verificationLevel: _str(json['verificationLevel']),
    pendingLevel: _str(json['pendingLevel']),
    verificationStatus: _str(json['verificationStatus']),
    docsRequestMessage: _str(json['docsRequestMessage']),
    trustScore: _num(json['trustScore']),
    ratingCount: _int(json['ratingCount']) ?? 0,
  );
}

/// Evidence the supplier uploaded for a level request (`GET /vendors/:id/verification-documents`).
class VerificationDocument {
  const VerificationDocument({required this.id, required this.name, required this.status, this.url, this.reviewNote});

  final String id;
  final String name;

  /// `PENDING`, `APPROVED` or `REJECTED`.
  final String status;
  final String? url;
  final String? reviewNote;

  factory VerificationDocument.fromJson(Map<String, dynamic> json) => VerificationDocument(
    id: '${json['id']}',
    name: _str(json['name']) ?? 'document',
    status: _str(json['status']) ?? 'PENDING',
    url: _str(json['url']),
    reviewNote: _str(json['reviewNote']),
  );
}

/// One decision on the listing (`GET /vendors/:id/verification-history`).
class VerificationEvent {
  const VerificationEvent({
    required this.id,
    required this.type,
    required this.status,
    required this.toLevel,
    required this.createdAt,
    this.note,
  });

  final String id;

  /// `SUBMITTED`, `DOCS_REQUESTED`, `APPROVED`, `REJECTED`, `REVALIDATION_FLAGGED`, `REVOKED`…
  final String type;
  final String status;
  final String toLevel;
  final String? note;
  final DateTime createdAt;

  factory VerificationEvent.fromJson(Map<String, dynamic> json) => VerificationEvent(
    id: '${json['id']}',
    type: _str(json['type']) ?? '',
    status: _str(json['status']) ?? 'PENDING',
    toLevel: _str(json['toLevel']) ?? '',
    note: _str(json['note']),
    createdAt: _date(json['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
  );
}

/// A level request (`PATCH /vendors/:id/request-upgrade`): the level and the evidence, with the upload's own facts so
/// reviewers see real file names.
class LevelRequest {
  const LevelRequest({required this.level, required this.documents});

  final String level;
  final List<UploadedEvidence> documents;

  Map<String, Object?> toJson() => {
    'level': level,
    'evidenceUrls': [for (final d in documents) d.url],
    'documents': [
      for (final d in documents) {'url': d.url, 'name': d.name, 'mimeType': ?d.mimeType, 'size': ?d.size},
    ],
  };
}

/// A file the API took (`POST /uploads`), with what the request forms send on.
class UploadedEvidence {
  const UploadedEvidence({required this.url, required this.name, this.mimeType, this.size});

  final String url;
  final String name;
  final String? mimeType;
  final int? size;
}

/// One plan the company holds (`GET /subscriptions/me?audience=`): its name and when it renews or ends.
class CompanyPlan {
  const CompanyPlan({
    required this.audience,
    this.planName,
    this.tier = 'FREE',
    this.currentPeriodEnd,
    this.autoRenew = false,
    this.cancelAtPeriodEnd = false,
  });

  /// `COMPANY` (the Job Portal plan) or `SUPPLIER` (the Market Place plan).
  final String audience;
  final String? planName;
  final String tier;
  final DateTime? currentPeriodEnd;
  final bool autoRenew;
  final bool cancelAtPeriodEnd;

  /// The free plan: the website offers "See plans" rather than "Manage plan".
  bool get free => tier == 'FREE';

  /// Whether the term renews by itself, or simply ends.
  bool get renews => autoRenew && !cancelAtPeriodEnd;

  factory CompanyPlan.fromJson(String audience, Map<String, dynamic> json) {
    final sub = _map(json['subscription']);
    return CompanyPlan(
      audience: audience,
      planName: _str(_map(sub['plan'])['name']),
      tier: _str(json['tier']) ?? 'FREE',
      currentPeriodEnd: _date(sub['currentPeriodEnd']),
      autoRenew: sub['autoRenew'] == true,
      cancelAtPeriodEnd: sub['cancelAtPeriodEnd'] == true,
    );
  }
}

/// The person's companies (`GET /me/companies`), as the workspace reads them: how many members the active company
/// has, how many companies the person belongs to, and whether they may found one.
class CompanyStanding {
  const CompanyStanding({this.memberCount, this.companiesHeld = 0, this.canJoinCompanies = true});

  /// The active company's member count; null when none is active.
  final int? memberCount;
  final int companiesHeld;
  final bool canJoinCompanies;

  factory CompanyStanding.fromJson(Map<String, dynamic> json) {
    final companies = json['companies'] is List ? json['companies'] as List : const [];
    int? members;
    for (final c in companies) {
      if (c is Map && c['active'] == true) members = _int(c['memberCount']);
    }
    return CompanyStanding(
      memberCount: members,
      companiesHeld: companies.length,
      canJoinCompanies: json['canJoinCompanies'] != false,
    );
  }
}

/// A certification on the company's record (`GET /certifications/me`, `CompanyCertification`).
class CompanyCertification {
  const CompanyCertification({
    required this.id,
    required this.certificationTypeId,
    required this.status,
    this.typeName,
    this.documentUrls = const [],
    this.issuer,
    this.issuedOn,
    this.certificateNumber,
    this.expiresAt,
    this.supersededAt,
    this.shownPublicly = false,
    this.reviewNote,
    this.note,
  });

  final String id;
  final String certificationTypeId;

  /// `VERIFIED` (on file), `PENDING` (a claim with no certificate) or `REJECTED` (not accepted).
  final String status;
  final String? typeName;
  final List<String> documentUrls;
  final String? issuer;
  final DateTime? issuedOn;
  final String? certificateNumber;
  final DateTime? expiresAt;
  final DateTime? supersededAt;

  /// Whether buyers see it now: on file, held and the company verified (the API's rule).
  final bool shownPublicly;
  final String? reviewNote;
  final String? note;

  String get name => typeName ?? 'Certification';

  factory CompanyCertification.fromJson(Map<String, dynamic> json) => CompanyCertification(
    id: '${json['id']}',
    certificationTypeId: '${json['certificationTypeId'] ?? _map(json['certificationType'])['id'] ?? ''}',
    status: _str(json['status']) ?? 'VERIFIED',
    typeName: _str(_map(json['certificationType'])['name']),
    documentUrls: _strings(json['documentUrls']),
    issuer: _str(json['issuer']),
    issuedOn: _date(json['issuedOn']),
    certificateNumber: _str(json['certificateNumber']),
    expiresAt: _date(json['expiresAt']),
    supersededAt: _date(json['supersededAt']),
    shownPublicly: json['shownPublicly'] == true,
    reviewNote: _str(json['reviewNote']),
    note: _str(json['note']),
  );
}

/// A certification ICR lists (`GET /certifications/types`), with the bodies it knows issue it.
class CertificationType {
  const CertificationType({required this.id, required this.name, this.issuers = const []});

  final String id;
  final String name;
  final List<String> issuers;

  /// The body to fill in when picked: only when ICR knows of exactly one (`soleIssuer`).
  String? get soleIssuer => issuers.length == 1 ? issuers.first : null;

  factory CertificationType.fromJson(Map<String, dynamic> json) =>
      CertificationType(id: '${json['id']}', name: _str(json['name']) ?? '', issuers: _strings(json['issuers']));
}

/// A certification the company records (`POST /certifications/me`, `RecordCertificationDto`).
class CertificationDraft {
  const CertificationDraft({
    required this.certificationTypeId,
    required this.documentUrls,
    this.issuer,
    this.certificateNumber,
    this.issuedOn,
    this.expiresAt,
    this.note,
  });

  final String certificationTypeId;
  final List<String> documentUrls;
  final String? issuer;
  final String? certificateNumber;

  /// `YYYY-MM-DD`.
  final String? issuedOn;
  final String? expiresAt;
  final String? note;

  Map<String, Object?> toJson() => {
    'certificationTypeId': certificationTypeId,
    'documentUrls': documentUrls,
    'issuer': ?issuer,
    'certificateNumber': ?certificateNumber,
    'issuedOn': ?issuedOn,
    'expiresAt': ?expiresAt,
    'note': ?note,
  };
}

/// A state from the masters (`GET /locations/states`).
class StateOption {
  const StateOption({required this.id, required this.name, this.code});

  final String id;
  final String name;
  final String? code;

  factory StateOption.fromJson(Map<String, dynamic> json) =>
      StateOption(id: '${json['id']}', name: _str(json['name']) ?? '', code: _str(json['code']));
}

/// The figures the overview's glance panel shows; null while unread or when the read failed.
class CompanyGlance {
  const CompanyGlance({this.offices, this.openJobs, this.products, this.services});

  final int? offices;
  final int? openJobs;
  final int? products;
  final int? services;

  CompanyGlance copyWith({int? offices, int? openJobs, int? products, int? services}) => CompanyGlance(
    offices: offices ?? this.offices,
    openJobs: openJobs ?? this.openJobs,
    products: products ?? this.products,
    services: services ?? this.services,
  );
}
