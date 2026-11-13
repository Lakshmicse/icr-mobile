/// What the staff console for chapters and councils reads and writes (the website's `/admin/community`): the admin
/// rows (`AdminChapterRow`, `AdminCouncilRow`), a record's content (`ChapterContent`, `CouncilContent`), the people a
/// lead is picked from, and members' applications and proposals (`ChapterApplicationDto`, `CouncilProposalDto`).
library;

String _s(Object? v) => v is String ? v : '';
String? _sn(Object? v) => v is String && v.trim().isNotEmpty ? v : null;
int _i(Object? v) => v is num ? v.toInt() : 0;
int? _in(Object? v) => v is num ? v.toInt() : null;
bool _b(Object? v, {bool or = false}) => v is bool ? v : or;
List<String> _strings(Object? v) => [
  for (final x in v is List ? v : const [])
    if (x is String && x.trim().isNotEmpty) x,
];
Map<String, dynamic>? _map(Object? v) => v is Map ? v.cast<String, dynamic>() : null;
DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;

/// One page of a list (`{ data, meta }`).
class ManagePage<T> {
  const ManagePage({required this.rows, this.page = 1, this.totalPages = 1, this.total = 0});

  final List<T> rows;
  final int page;
  final int totalPages;
  final int total;

  static ManagePage<T> fromJson<T>(Object? json, T Function(Map<String, dynamic>) row) {
    final map = _map(json) ?? const <String, dynamic>{};
    final meta = _map(map['meta']) ?? const <String, dynamic>{};
    final rows = [
      for (final r in map['data'] is List ? map['data'] as List : const [])
        if (r is Map) row(r.cast<String, dynamic>()),
    ];
    final totalPages = _i(meta['totalPages']);
    return ManagePage(
      rows: rows,
      page: _in(meta['page']) ?? 1,
      totalPages: totalPages < 1 ? 1 : totalPages,
      total: _in(meta['total']) ?? rows.length,
    );
  }
}

/// `COUNTRY`: the whole country, no city. `REGIONAL`: one city.
class ChapterScope {
  ChapterScope._();

  static const country = 'COUNTRY';
  static const regional = 'REGIONAL';
}

/// A chapter as the staff list gives it (`GET /chapters/admin`): the card plus what only staff edit.
class AdminChapter {
  const AdminChapter({
    required this.id,
    required this.name,
    this.slug = '',
    this.scope = ChapterScope.regional,
    this.city = '',
    this.country = 'India',
    this.region,
    this.description,
    this.coverUrl,
    this.logoUrl,
    this.contactEmail,
    this.foundedYear,
    this.aboutHtml,
    this.galleryUrls = const [],
    this.published = true,
    this.memberCount = 0,
    this.upcomingEventCount = 0,
  });

  final String id;
  final String name;
  final String slug;
  final String scope;
  final String city;
  final String country;
  final String? region;
  final String? description;
  final String? coverUrl;
  final String? logoUrl;
  final String? contactEmail;
  final int? foundedYear;
  final String? aboutHtml;
  final List<String> galleryUrls;
  final bool published;
  final int memberCount;
  final int upcomingEventCount;

  bool get countryWide => scope == ChapterScope.country;

  /// "Regional chapter" or "Country chapter", as the website's list names it.
  String get scopeLabel => countryWide ? 'Country chapter' : 'Regional chapter';

  /// City, region and country, each once ("Bengaluru · Karnataka · India").
  String get place {
    final seen = <String>[];
    for (final v in [city, region ?? '', country]) {
      if (v.trim().isNotEmpty && !seen.contains(v)) seen.add(v);
    }
    return seen.join(' · ');
  }

  factory AdminChapter.fromJson(Map<String, dynamic> j) => AdminChapter(
    id: _s(j['id']),
    name: _s(j['name']),
    slug: _s(j['slug']),
    scope: _sn(j['scope']) ?? ChapterScope.regional,
    city: _s(j['city']),
    country: _s(j['country']),
    region: _sn(j['region']),
    description: _sn(j['description']),
    coverUrl: _sn(j['coverUrl']),
    logoUrl: _sn(j['logoUrl']),
    contactEmail: _sn(j['contactEmail']),
    foundedYear: _in(j['foundedYear']),
    aboutHtml: _sn(j['aboutHtml']),
    galleryUrls: _strings(j['galleryUrls']),
    published: _b(j['published'], or: true),
    memberCount: _i(j['memberCount']),
    upcomingEventCount: _i(j['upcomingEventCount']),
  );
}

/// A council as the staff list gives it (`GET /councils/admin`).
class AdminCouncil {
  const AdminCouncil({
    required this.id,
    required this.name,
    this.slug = '',
    this.focus,
    this.segments = const [],
    this.description,
    this.coverUrl,
    this.contactEmail,
    this.aboutHtml,
    this.galleryUrls = const [],
    this.published = true,
    this.memberCount = 0,
    this.upcomingEventCount = 0,
  });

  final String id;
  final String name;
  final String slug;
  final String? focus;
  final List<String> segments;
  final String? description;
  final String? coverUrl;
  final String? contactEmail;
  final String? aboutHtml;
  final List<String> galleryUrls;
  final bool published;
  final int memberCount;
  final int upcomingEventCount;

  factory AdminCouncil.fromJson(Map<String, dynamic> j) => AdminCouncil(
    id: _s(j['id']),
    name: _s(j['name']),
    slug: _s(j['slug']),
    focus: _sn(j['focus']),
    segments: _strings(j['segments']),
    description: _sn(j['description']),
    coverUrl: _sn(j['coverUrl']),
    contactEmail: _sn(j['contactEmail']),
    aboutHtml: _sn(j['aboutHtml']),
    galleryUrls: _strings(j['galleryUrls']),
    published: _b(j['published'], or: true),
    memberCount: _i(j['memberCount']),
    upcomingEventCount: _i(j['upcomingEventCount']),
  );
}

class ContentSponsor {
  const ContentSponsor({required this.id, required this.name, this.logoUrl, this.url, this.tier});

  final String id;
  final String name;
  final String? logoUrl;
  final String? url;
  final String? tier;

  factory ContentSponsor.fromJson(Map<String, dynamic> j) => ContentSponsor(
    id: _s(j['id']),
    name: _s(j['name']),
    logoUrl: _sn(j['logoUrl']),
    url: _sn(j['url']),
    tier: _sn(j['tier']),
  );
}

class ContentResource {
  const ContentResource({required this.id, required this.title, this.kind = 'OTHER', this.url = '', this.sizeLabel});

  final String id;
  final String title;
  final String kind;
  final String url;
  final String? sizeLabel;

  factory ContentResource.fromJson(Map<String, dynamic> j) => ContentResource(
    id: _s(j['id']),
    title: _s(j['title']),
    kind: _sn(j['kind']) ?? 'OTHER',
    url: _s(j['url']),
    sizeLabel: _sn(j['sizeLabel']),
  );
}

/// An update on the record's page (the API's "announcement").
class ContentAnnouncement {
  const ContentAnnouncement({
    required this.id,
    required this.title,
    this.body = '',
    this.pinned = false,
    this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final bool pinned;
  final DateTime? createdAt;

  factory ContentAnnouncement.fromJson(Map<String, dynamic> j) => ContentAnnouncement(
    id: _s(j['id']),
    title: _s(j['title']),
    body: _s(j['body']),
    pinned: _b(j['pinned']),
    createdAt: _date(j['createdAt']),
  );
}

/// A member of the record: someone who could be made a lead.
class ContentMember {
  const ContentMember({required this.userId, this.firstName = '', this.lastName = ''});

  final String userId;
  final String firstName;
  final String lastName;

  String get name => '$firstName $lastName'.trim();

  factory ContentMember.fromJson(Map<String, dynamic> j) =>
      ContentMember(userId: _s(j['userId']), firstName: _s(j['firstName']), lastName: _s(j['lastName']));
}

/// A lead: their title, LinkedIn link and term (`YYYY-MM-DD`; no end is an open term).
class ContentLead extends ContentMember {
  const ContentLead({
    required super.userId,
    super.firstName,
    super.lastName,
    this.title,
    this.linkedinUrl,
    this.termStartsOn,
    this.termEndsOn,
  });

  final String? title;
  final String? linkedinUrl;
  final String? termStartsOn;
  final String? termEndsOn;

  factory ContentLead.fromJson(Map<String, dynamic> j) => ContentLead(
    userId: _s(j['userId']),
    firstName: _s(j['firstName']),
    lastName: _s(j['lastName']),
    title: _sn(j['title']),
    linkedinUrl: _sn(j['linkedinUrl']),
    termStartsOn: _sn(j['termStartsOn']),
    termEndsOn: _sn(j['termEndsOn']),
  );
}

/// What a record's manage page lists under its details (`GET /chapters/:id/content`, `GET /councils/:id/content`).
/// A council has no sponsors.
class OrgContent {
  const OrgContent({
    this.sponsors = const [],
    this.resources = const [],
    this.announcements = const [],
    this.leads = const [],
    this.members = const [],
  });

  final List<ContentSponsor> sponsors;
  final List<ContentResource> resources;
  final List<ContentAnnouncement> announcements;
  final List<ContentLead> leads;
  final List<ContentMember> members;

  factory OrgContent.fromJson(Map<String, dynamic> j) {
    List<T> rows<T>(String key, T Function(Map<String, dynamic>) of) => [
      for (final r in j[key] is List ? j[key] as List : const [])
        if (r is Map) of(r.cast<String, dynamic>()),
    ];
    return OrgContent(
      sponsors: rows('sponsors', ContentSponsor.fromJson),
      resources: rows('resources', ContentResource.fromJson),
      announcements: rows('announcements', ContentAnnouncement.fromJson),
      leads: rows('leads', ContentLead.fromJson),
      members: rows('members', ContentMember.fromJson),
    );
  }
}

/// Someone a chapter lead can be picked from (`GET /chapters/:id/lead-candidates`).
class LeadCandidate {
  const LeadCandidate({
    required this.id,
    this.firstName = '',
    this.lastName = '',
    this.email = '',
    this.isMember = false,
    this.isLead = false,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final bool isMember;
  final bool isLead;

  String get name {
    final n = '$firstName $lastName'.trim();
    return n.isEmpty ? email : n;
  }

  factory LeadCandidate.fromJson(Map<String, dynamic> j) => LeadCandidate(
    id: _s(j['id']),
    firstName: _s(j['firstName']),
    lastName: _s(j['lastName']),
    email: _s(j['email']),
    isMember: _b(j['isMember']),
    isLead: _b(j['isLead']),
  );
}

/// The four states of a member's request (`AssociationRequestStatus`).
class RequestStatus {
  RequestStatus._();

  static const pending = 'PENDING';
  static const approved = 'APPROVED';
  static const declined = 'DECLINED';
  static const withdrawn = 'WITHDRAWN';

  /// The order the website's filter offers them in.
  static const all = [pending, approved, declined, withdrawn];
}

/// Who sent a request (staff lists only).
class RequestPerson {
  const RequestPerson({this.firstName = '', this.lastName = '', this.email = ''});

  final String firstName;
  final String lastName;
  final String email;

  /// "Asha Rao · asha@acme.com"
  String get line => ['$firstName $lastName'.trim(), email].where((v) => v.isNotEmpty).join(' · ');

  static RequestPerson? fromJson(Object? json) {
    final j = _map(json);
    if (j == null) return null;
    return RequestPerson(firstName: _s(j['firstName']), lastName: _s(j['lastName']), email: _s(j['email']));
  }
}

/// Where an approval led: the new (unpublished) chapter or council, or the chapter now led.
class RequestResult {
  const RequestResult({required this.id, required this.name, this.published = false});

  final String id;
  final String name;
  final bool published;

  static RequestResult? fromJson(Object? json) {
    final j = _map(json);
    if (j == null) return null;
    return RequestResult(id: _s(j['id']), name: _s(j['name']), published: _b(j['published']));
  }
}

/// A member asking to start a chapter, or to lead one (`ChapterApplicationDto`).
class ChapterApplication {
  const ChapterApplication({
    required this.id,
    this.kind = 'NEW_CHAPTER',
    this.chapterName,
    this.proposedName,
    this.city = '',
    this.country = '',
    this.motivation = '',
    this.experience = '',
    this.linkedinUrl,
    this.status = RequestStatus.pending,
    this.decisionReason,
    this.decidedAt,
    this.result,
    this.createdAt,
    this.applicant,
  });

  final String id;

  /// `NEW_CHAPTER` or `LEAD_EXISTING`.
  final String kind;
  final String? chapterName;
  final String? proposedName;
  final String city;
  final String country;
  final String motivation;
  final String experience;
  final String? linkedinUrl;
  final String status;
  final String? decisionReason;
  final DateTime? decidedAt;
  final RequestResult? result;
  final DateTime? createdAt;
  final RequestPerson? applicant;

  bool get newChapter => kind == 'NEW_CHAPTER';
  bool get pending => status == RequestStatus.pending;

  /// The row's heading, as the website words it.
  String get title => newChapter ? 'New chapter: ${proposedName ?? city}' : 'Lead ${chapterName ?? 'a chapter'}';

  factory ChapterApplication.fromJson(Map<String, dynamic> j) => ChapterApplication(
    id: _s(j['id']),
    kind: _sn(j['kind']) ?? 'NEW_CHAPTER',
    chapterName: _sn(_map(j['chapter'])?['name']),
    proposedName: _sn(j['proposedName']),
    city: _s(j['city']),
    country: _s(j['country']),
    motivation: _s(j['motivation']),
    experience: _s(j['experience']),
    linkedinUrl: _sn(j['linkedinUrl']),
    status: _sn(j['status']) ?? RequestStatus.pending,
    decisionReason: _sn(j['decisionReason']),
    decidedAt: _date(j['decidedAt']),
    result: RequestResult.fromJson(j['resultChapter']),
    createdAt: _date(j['createdAt']),
    applicant: RequestPerson.fromJson(j['applicant']),
  );
}

/// A member proposing a new council (`CouncilProposalDto`).
class CouncilProposal {
  const CouncilProposal({
    required this.id,
    this.name = '',
    this.focus = '',
    this.objectives = '',
    this.segments = const [],
    this.motivation = '',
    this.status = RequestStatus.pending,
    this.decisionReason,
    this.decidedAt,
    this.result,
    this.createdAt,
    this.proposer,
  });

  final String id;
  final String name;
  final String focus;
  final String objectives;
  final List<String> segments;
  final String motivation;
  final String status;
  final String? decisionReason;
  final DateTime? decidedAt;
  final RequestResult? result;
  final DateTime? createdAt;
  final RequestPerson? proposer;

  bool get pending => status == RequestStatus.pending;

  factory CouncilProposal.fromJson(Map<String, dynamic> j) => CouncilProposal(
    id: _s(j['id']),
    name: _s(j['name']),
    focus: _s(j['focus']),
    objectives: _s(j['objectives']),
    segments: _strings(j['segments']),
    motivation: _s(j['motivation']),
    status: _sn(j['status']) ?? RequestStatus.pending,
    decisionReason: _sn(j['decisionReason']),
    decidedAt: _date(j['decidedAt']),
    result: RequestResult.fromJson(j['resultCouncil']),
    createdAt: _date(j['createdAt']),
    proposer: RequestPerson.fromJson(j['proposer']),
  );
}

/// A place the city search offers (`GET /locations/cities`, `GET /locations/search`): the pick fills the chapter's
/// city, its state and its country.
class PlaceOption {
  const PlaceOption({required this.label, this.city, this.state, this.country, this.countryCode});

  final String label;
  final String? city;
  final String? state;
  final String? country;
  final String? countryCode;

  factory PlaceOption.fromJson(Map<String, dynamic> j) => PlaceOption(
    label: _s(j['label']),
    city: _sn(j['city']),
    state: _sn(j['state']),
    country: _sn(j['country']),
    countryCode: _sn(j['countryCode']),
  );

  /// A row of ICR's own city list (`{ name, state: { name } }`): an Indian city.
  factory PlaceOption.fromCity(Map<String, dynamic> j) {
    final name = _s(j['name']);
    return PlaceOption(
      label: name,
      city: name,
      state: _sn(_map(j['state'])?['name']),
      country: 'India',
      countryCode: 'IN',
    );
  }
}
