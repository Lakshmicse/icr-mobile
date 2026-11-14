import '../../core/api/api_error.dart';
import 'community_manage_models.dart';
import 'community_manage_repository.dart';
import 'community_manage_rules.dart';

/// The console's data kept in memory and changed in place, for the demo build and for tests: a few chapters and
/// councils with their content, and some requests waiting. Every write is recorded in [sent]; [refuse] makes the
/// next call of an action fail with the API's own words; [reach] narrows the reader to some records, as a role
/// given over only those does.
class MemoryCommunityManageRepository implements CommunityManageRepository {
  MemoryCommunityManageRepository({
    List<AdminChapter>? chapters,
    List<AdminCouncil>? councils,
    Map<String, OrgContent>? content,
    List<ChapterApplication>? applications,
    List<CouncilProposal>? proposals,
    this.reach,
  }) : chapterRows = chapters ?? _sampleChapters(),
       councilRows = councils ?? _sampleCouncils(),
       contents = content ?? _sampleContent(),
       applications = applications ?? _sampleApplications(),
       proposals = proposals ?? _sampleProposals();

  final List<AdminChapter> chapterRows;
  final List<AdminCouncil> councilRows;

  /// A record's content, by its id.
  final Map<String, OrgContent> contents;
  final List<ChapterApplication> applications;
  final List<CouncilProposal> proposals;

  /// The record ids a scoped role reaches; null reaches everything.
  final Set<String>? reach;

  /// Every write, in order: `{ action, … }`.
  final List<Map<String, Object?>> sent = [];

  /// An action's next refusal (`'updateChapter'`, `'decide'`, `'content'`…), used once.
  final Map<String, ApiError> refuse = {};

  /// People the leader search finds.
  List<LeadCandidate> candidates = const [
    LeadCandidate(id: 'u-anil', firstName: 'Anil', lastName: 'Kumar', email: 'anil@acme.com', isMember: true),
    LeadCandidate(id: 'u-zoya', firstName: 'Zoya', lastName: 'Khan', email: 'zoya@north.in'),
  ];

  List<PlaceOption> cityRows = const [
    PlaceOption(label: 'Bengaluru', city: 'Bengaluru', state: 'Karnataka', country: 'India', countryCode: 'IN'),
    PlaceOption(label: 'Mumbai', city: 'Mumbai', state: 'Maharashtra', country: 'India', countryCode: 'IN'),
    PlaceOption(label: 'Pune', city: 'Pune', state: 'Maharashtra', country: 'India', countryCode: 'IN'),
  ];

  List<PlaceOption> worldRows = const [
    PlaceOption(
      label: 'Dubai, United Arab Emirates',
      city: 'Dubai',
      state: 'Dubai',
      country: 'United Arab Emirates',
      countryCode: 'AE',
    ),
  ];

  int _seq = 0;
  String _newId(String prefix) => '$prefix-new-${++_seq}';

  void _gate(String action) {
    final refusal = refuse.remove(action);
    if (refusal != null) throw refusal;
  }

  bool _reaches(String id) => reach == null || reach!.contains(id);

  void _needEverywhere() {
    if (reach != null) {
      throw ApiError(
        "Your role doesn't reach this record. Ask a Super Admin to widen it if you need to.",
        statusCode: 403,
      );
    }
  }

  void _needRecord(String id) {
    if (!_reaches(id)) {
      throw ApiError(
        "Your role doesn't reach this record. Ask a Super Admin to widen it if you need to.",
        statusCode: 403,
      );
    }
  }

  ManagePage<T> _page<T>(List<T> all, int page) {
    final totalPages = all.isEmpty ? 1 : ((all.length - 1) ~/ managePageSize) + 1;
    final from = (page - 1) * managePageSize;
    final rows = from >= all.length ? <T>[] : all.sublist(from, (from + managePageSize).clamp(0, all.length));
    return ManagePage(rows: rows, page: page, totalPages: totalPages, total: all.length);
  }

  @override
  Future<ManagePage<AdminChapter>> chapters({int page = 1, String? search}) async {
    _gate('chapters');
    final q = (search ?? '').trim().toLowerCase();
    final all = [
      for (final c in chapterRows)
        if (_reaches(c.id) && (q.isEmpty || c.name.toLowerCase().contains(q) || c.city.toLowerCase().contains(q))) c,
    ]..sort((a, b) => a.name.compareTo(b.name));
    return _page(all, page);
  }

  @override
  Future<ManagePage<AdminCouncil>> councils({int page = 1, String? search}) async {
    _gate('councils');
    final q = (search ?? '').trim().toLowerCase();
    final all = [
      for (final c in councilRows)
        if (_reaches(c.id) &&
            (q.isEmpty || c.name.toLowerCase().contains(q) || (c.focus ?? '').toLowerCase().contains(q)))
          c,
    ]..sort((a, b) => a.name.compareTo(b.name));
    return _page(all, page);
  }

  @override
  Future<AdminChapter?> chapter(String id) async {
    _gate('chapter');
    return chapterRows.where((c) => c.id == id && _reaches(id)).firstOrNull;
  }

  @override
  Future<AdminCouncil?> council(String id) async {
    _gate('council');
    return councilRows.where((c) => c.id == id && _reaches(id)).firstOrNull;
  }

  AdminChapter _chapterFrom(String id, Map<String, Object?> b, {AdminChapter? was}) => AdminChapter(
    id: id,
    name: b['name'] as String? ?? was?.name ?? '',
    slug: was?.slug ?? slugify(b['name'] as String? ?? ''),
    scope: b['scope'] as String? ?? was?.scope ?? ChapterScope.regional,
    city: b['city'] as String? ?? was?.city ?? '',
    country: b['country'] as String? ?? was?.country ?? 'India',
    region: b.containsKey('region') ? b['region'] as String? : was?.region,
    description: b.containsKey('description') ? b['description'] as String? : was?.description,
    coverUrl: b.containsKey('coverUrl') ? _blankToNull(b['coverUrl']) : was?.coverUrl,
    logoUrl: b.containsKey('logoUrl') ? _blankToNull(b['logoUrl']) : was?.logoUrl,
    contactEmail: b.containsKey('contactEmail') ? b['contactEmail'] as String? : was?.contactEmail,
    foundedYear: b.containsKey('foundedYear') ? b['foundedYear'] as int? : was?.foundedYear,
    aboutHtml: b.containsKey('aboutHtml') ? _blankToNull(b['aboutHtml']) : was?.aboutHtml,
    galleryUrls: (b['galleryUrls'] as List?)?.cast<String>() ?? was?.galleryUrls ?? const [],
    published: b['published'] as bool? ?? was?.published ?? true,
    memberCount: was?.memberCount ?? 0,
    upcomingEventCount: was?.upcomingEventCount ?? 0,
  );

  AdminCouncil _councilFrom(String id, Map<String, Object?> b, {AdminCouncil? was}) => AdminCouncil(
    id: id,
    name: b['name'] as String? ?? was?.name ?? '',
    slug: b['slug'] as String? ?? was?.slug ?? '',
    focus: b.containsKey('focus') ? b['focus'] as String? : was?.focus,
    segments: (b['segments'] as List?)?.cast<String>() ?? was?.segments ?? const [],
    description: b.containsKey('description') ? b['description'] as String? : was?.description,
    coverUrl: b.containsKey('coverUrl') ? _blankToNull(b['coverUrl']) : was?.coverUrl,
    contactEmail: b.containsKey('contactEmail') ? b['contactEmail'] as String? : was?.contactEmail,
    aboutHtml: b.containsKey('aboutHtml') ? _blankToNull(b['aboutHtml']) : was?.aboutHtml,
    galleryUrls: (b['galleryUrls'] as List?)?.cast<String>() ?? was?.galleryUrls ?? const [],
    published: b['published'] as bool? ?? was?.published ?? true,
    memberCount: was?.memberCount ?? 0,
    upcomingEventCount: was?.upcomingEventCount ?? 0,
  );

  static String? _blankToNull(Object? v) => v is String && v.isNotEmpty ? v : null;

  @override
  Future<void> createChapter(Map<String, Object?> body) async {
    _gate('createChapter');
    _needEverywhere();
    sent.add({'action': 'createChapter', 'body': body});
    final id = _newId('ch');
    chapterRows.add(_chapterFrom(id, body));
    contents[id] = const OrgContent();
  }

  @override
  Future<void> updateChapter(String id, Map<String, Object?> body) async {
    _gate('updateChapter');
    _needRecord(id);
    sent.add({'action': 'updateChapter', 'id': id, 'body': body});
    final i = chapterRows.indexWhere((c) => c.id == id);
    if (i < 0) throw ApiError('Chapter not found', statusCode: 404);
    chapterRows[i] = _chapterFrom(id, body, was: chapterRows[i]);
  }

  @override
  Future<void> createCouncil(Map<String, Object?> body) async {
    _gate('createCouncil');
    _needEverywhere();
    sent.add({'action': 'createCouncil', 'body': body});
    final id = _newId('co');
    councilRows.add(_councilFrom(id, body));
    contents[id] = const OrgContent();
  }

  @override
  Future<void> updateCouncil(String id, Map<String, Object?> body) async {
    _gate('updateCouncil');
    _needRecord(id);
    sent.add({'action': 'updateCouncil', 'id': id, 'body': body});
    final i = councilRows.indexWhere((c) => c.id == id);
    if (i < 0) throw ApiError('Council not found', statusCode: 404);
    councilRows[i] = _councilFrom(id, body, was: councilRows[i]);
  }

  @override
  Future<void> retire(OrgKind kind, String id) async {
    _gate('retire');
    _needEverywhere();
    sent.add({'action': 'retire', 'kind': kind.name, 'id': id});
    if (kind == OrgKind.chapter) {
      chapterRows.removeWhere((c) => c.id == id);
    } else {
      councilRows.removeWhere((c) => c.id == id);
    }
  }

  OrgContent _contentOf(String id) {
    _needRecord(id);
    final known = chapterRows.any((c) => c.id == id) || councilRows.any((c) => c.id == id);
    if (!known) throw ApiError('Not found', statusCode: 404);
    return contents[id] ?? const OrgContent();
  }

  void _put(
    String id, {
    List<ContentSponsor>? sponsors,
    List<ContentResource>? resources,
    List<ContentAnnouncement>? announcements,
    List<ContentLead>? leads,
    List<ContentMember>? members,
  }) {
    final c = contents[id] ?? const OrgContent();
    contents[id] = OrgContent(
      sponsors: sponsors ?? c.sponsors,
      resources: resources ?? c.resources,
      announcements: announcements ?? c.announcements,
      leads: leads ?? c.leads,
      members: members ?? c.members,
    );
  }

  @override
  Future<OrgContent> content(OrgKind kind, String id) async {
    _gate('content');
    return _contentOf(id);
  }

  @override
  Future<void> addSponsor(String chapterId, Map<String, Object?> body) async {
    _gate('addSponsor');
    final c = _contentOf(chapterId);
    sent.add({'action': 'addSponsor', 'id': chapterId, 'body': body});
    _put(
      chapterId,
      sponsors: [
        ...c.sponsors,
        ContentSponsor(
          id: _newId('sp'),
          name: body['name'] as String? ?? '',
          logoUrl: body['logoUrl'] as String?,
          url: body['url'] as String?,
          tier: body['tier'] as String?,
        ),
      ],
    );
  }

  @override
  Future<void> removeSponsor(String chapterId, String sponsorId) async {
    _gate('removeSponsor');
    final c = _contentOf(chapterId);
    sent.add({'action': 'removeSponsor', 'id': chapterId, 'sponsorId': sponsorId});
    _put(chapterId, sponsors: [...c.sponsors.where((s) => s.id != sponsorId)]);
  }

  @override
  Future<void> addResource(OrgKind kind, String id, Map<String, Object?> body) async {
    _gate('addResource');
    final c = _contentOf(id);
    sent.add({'action': 'addResource', 'kind': kind.name, 'id': id, 'body': body});
    _put(
      id,
      resources: [
        ContentResource(
          id: _newId('rs'),
          title: body['title'] as String? ?? '',
          kind: body['kind'] as String? ?? 'OTHER',
          url: body['url'] as String? ?? '',
          sizeLabel: body['sizeLabel'] as String?,
        ),
        ...c.resources,
      ],
    );
  }

  @override
  Future<void> removeResource(OrgKind kind, String id, String resourceId) async {
    _gate('removeResource');
    final c = _contentOf(id);
    sent.add({'action': 'removeResource', 'kind': kind.name, 'id': id, 'resourceId': resourceId});
    _put(id, resources: [...c.resources.where((r) => r.id != resourceId)]);
  }

  @override
  Future<void> addAnnouncement(OrgKind kind, String id, Map<String, Object?> body) async {
    _gate('addAnnouncement');
    final c = _contentOf(id);
    sent.add({'action': 'addAnnouncement', 'kind': kind.name, 'id': id, 'body': body});
    _put(
      id,
      announcements: [
        ContentAnnouncement(
          id: _newId('an'),
          title: body['title'] as String? ?? '',
          body: body['body'] as String? ?? '',
          pinned: body['pinned'] as bool? ?? false,
        ),
        ...c.announcements,
      ],
    );
  }

  @override
  Future<void> removeAnnouncement(OrgKind kind, String id, String announcementId) async {
    _gate('removeAnnouncement');
    final c = _contentOf(id);
    sent.add({'action': 'removeAnnouncement', 'kind': kind.name, 'id': id, 'announcementId': announcementId});
    _put(id, announcements: [...c.announcements.where((a) => a.id != announcementId)]);
  }

  @override
  Future<List<LeadCandidate>> leadCandidates(String chapterId, String search) async {
    _gate('leadCandidates');
    _needEverywhere();
    final q = search.trim().toLowerCase();
    if (q.length < 2) return const [];
    return [
      for (final c in candidates)
        if (c.name.toLowerCase().contains(q) || c.email.toLowerCase().contains(q)) c,
    ];
  }

  @override
  Future<void> addLead(String chapterId, Map<String, Object?> body) async {
    _gate('addLead');
    _needEverywhere();
    final c = _contentOf(chapterId);
    sent.add({'action': 'addLead', 'id': chapterId, 'body': body});
    final userId = body['userId'] as String? ?? '';
    final person = candidates.where((p) => p.id == userId).firstOrNull;
    _put(
      chapterId,
      leads: [
        ...c.leads.where((l) => l.userId != userId),
        ContentLead(
          userId: userId,
          firstName: person?.firstName ?? '',
          lastName: person?.lastName ?? '',
          title: body['title'] as String?,
          linkedinUrl: body['linkedinUrl'] as String?,
        ),
      ],
      members: [...c.members.where((m) => m.userId != userId)],
    );
  }

  @override
  Future<void> updateMember(OrgKind kind, String id, String userId, Map<String, Object?> body) async {
    _gate('updateMember');
    final c = _contentOf(id);
    final start = body['termStartsOn'] as String? ?? '';
    final end = body['termEndsOn'] as String? ?? '';
    if (start.isNotEmpty && end.isNotEmpty && end.compareTo(start) < 0) {
      throw ApiError("A term can't end before it starts.", statusCode: 400);
    }
    sent.add({'action': 'updateMember', 'kind': kind.name, 'id': id, 'userId': userId, 'body': body});
    String? day(String key, String? was) => body.containsKey(key) ? _blankToNull(body[key]) : was;
    final lead = c.leads.where((l) => l.userId == userId).firstOrNull;
    final member = c.members.where((m) => m.userId == userId).firstOrNull;
    final role = body['role'] as String?;
    if (role == 'MEMBER' && lead != null) {
      _put(
        id,
        leads: [...c.leads.where((l) => l.userId != userId)],
        members: [...c.members, ContentMember(userId: userId, firstName: lead.firstName, lastName: lead.lastName)],
      );
    } else if (role == 'LEAD' && member != null) {
      _put(
        id,
        members: [...c.members.where((m) => m.userId != userId)],
        leads: [
          ...c.leads,
          ContentLead(
            userId: userId,
            firstName: member.firstName,
            lastName: member.lastName,
            termStartsOn: day('termStartsOn', null),
            termEndsOn: day('termEndsOn', null),
          ),
        ],
      );
    } else if (lead != null) {
      _put(
        id,
        leads: [
          for (final l in c.leads)
            if (l.userId == userId)
              ContentLead(
                userId: userId,
                firstName: l.firstName,
                lastName: l.lastName,
                title: body.containsKey('title') ? _blankToNull(body['title']) : l.title,
                linkedinUrl: body.containsKey('linkedinUrl') ? _blankToNull(body['linkedinUrl']) : l.linkedinUrl,
                termStartsOn: day('termStartsOn', l.termStartsOn),
                termEndsOn: day('termEndsOn', l.termEndsOn),
              )
            else
              l,
        ],
      );
    } else {
      throw ApiError('Member not found', statusCode: 404);
    }
  }

  @override
  Future<ManagePage<ChapterApplication>> chapterApplications({required String status, int page = 1}) async {
    _gate('chapterApplications');
    _needEverywhere();
    return _page([...applications.where((a) => a.status == status)], page);
  }

  @override
  Future<ManagePage<CouncilProposal>> councilProposals({required String status, int page = 1}) async {
    _gate('councilProposals');
    _needEverywhere();
    return _page([...proposals.where((p) => p.status == status)], page);
  }

  @override
  Future<void> decide(OrgKind kind, String id, {required String decision, String? reason}) async {
    _gate('decide');
    _needEverywhere();
    final note = (reason ?? '').trim();
    if (decision == RequestStatus.declined && note.isEmpty) {
      throw ApiError("Say why it isn't approved. The member reads this.", statusCode: 400);
    }
    sent.add({'action': 'decide', 'kind': kind.name, 'id': id, 'decision': decision, 'reason': note});
    final approved = decision == RequestStatus.approved;
    if (kind == OrgKind.chapter) {
      final i = applications.indexWhere((a) => a.id == id);
      if (i < 0) throw ApiError('Request not found.', statusCode: 404);
      final a = applications[i];
      applications[i] = ChapterApplication(
        id: a.id,
        kind: a.kind,
        chapterName: a.chapterName,
        proposedName: a.proposedName,
        city: a.city,
        country: a.country,
        motivation: a.motivation,
        experience: a.experience,
        linkedinUrl: a.linkedinUrl,
        status: decision,
        decisionReason: note.isEmpty ? null : note,
        decidedAt: DateTime.now(),
        result: approved ? RequestResult(id: _newId('ch'), name: a.proposedName ?? a.chapterName ?? a.city) : null,
        createdAt: a.createdAt,
        applicant: a.applicant,
      );
    } else {
      final i = proposals.indexWhere((p) => p.id == id);
      if (i < 0) throw ApiError('Request not found.', statusCode: 404);
      final p = proposals[i];
      proposals[i] = CouncilProposal(
        id: p.id,
        name: p.name,
        focus: p.focus,
        objectives: p.objectives,
        segments: p.segments,
        motivation: p.motivation,
        status: decision,
        decisionReason: note.isEmpty ? null : note,
        decidedAt: DateTime.now(),
        result: approved ? RequestResult(id: _newId('co'), name: p.name) : null,
        createdAt: p.createdAt,
        proposer: p.proposer,
      );
    }
  }

  @override
  Future<bool> mayManageChapter(String id) async => _reaches(id) && chapterRows.any((c) => c.id == id);

  @override
  Future<bool> mayManageCouncil(String id) async => _reaches(id) && councilRows.any((c) => c.id == id);

  @override
  Future<String> upload(UploadFile file, {required String purpose}) async {
    _gate('upload');
    sent.add({'action': 'upload', 'name': file.name, 'purpose': purpose, 'size': file.size});
    return '/uploads/demo/${file.name}';
  }

  @override
  Future<List<PlaceOption>> cities() async => cityRows;

  @override
  Future<List<PlaceOption>> searchPlaces(String query) async {
    final q = query.trim().toLowerCase();
    if (q.length < 2) return const [];
    return [
      for (final p in worldRows)
        if (p.label.toLowerCase().contains(q)) p,
    ];
  }
}

List<AdminChapter> _sampleChapters() => [
  const AdminChapter(
    id: 'ch-blr',
    name: 'Bengaluru Chapter',
    slug: 'bengaluru-chapter',
    city: 'Bengaluru',
    region: 'Karnataka',
    country: 'India',
    description: 'Facility and workplace leaders across Bengaluru.',
    contactEmail: 'bengaluru@icr.org.in',
    foundedYear: 2019,
    aboutHtml: '<h3>Mission</h3>\n<p>Bring the city’s facility leaders together.</p>\n'
        '<h3>What we do</h3>\n<ul>\n<li>Monthly meetups</li>\n<li>Site visits</li>\n</ul>',
    memberCount: 128,
    upcomingEventCount: 3,
  ),
  const AdminChapter(
    id: 'ch-mum',
    name: 'Mumbai Chapter',
    slug: 'mumbai-chapter',
    city: 'Mumbai',
    region: 'Maharashtra',
    country: 'India',
    published: false,
    memberCount: 64,
  ),
  const AdminChapter(
    id: 'ch-uae',
    name: 'UAE Chapter',
    slug: 'uae-chapter',
    scope: ChapterScope.country,
    country: 'United Arab Emirates',
    memberCount: 41,
    upcomingEventCount: 1,
  ),
];

List<AdminCouncil> _sampleCouncils() => [
  const AdminCouncil(
    id: 'co-health',
    name: 'Healthcare Facilities Council',
    slug: 'healthcare-facilities',
    focus: 'Hospitals · Pharma',
    segments: ['Hospitals', 'Pharma'],
    description: 'Standards and practice for healthcare estates.',
    memberCount: 52,
  ),
  const AdminCouncil(
    id: 'co-proc',
    name: 'Procurement Excellence Council',
    slug: 'procurement-excellence',
    focus: 'Procurement Excellence',
    segments: ['Procurement'],
    published: false,
    memberCount: 18,
  ),
];

Map<String, OrgContent> _sampleContent() => {
  'ch-blr': const OrgContent(
    sponsors: [ContentSponsor(id: 'sp-1', name: 'Acme Facilities', tier: 'Gold', url: 'https://acme.example')],
    resources: [
      ContentResource(
        id: 'rs-1',
        title: 'Annual Report 2025',
        kind: 'WHITEPAPER',
        url: '/uploads/report.pdf',
        sizeLabel: '2 MB',
      ),
    ],
    announcements: [
      ContentAnnouncement(id: 'an-1', title: 'November meetup', body: 'We meet on the 21st at Koramangala.', pinned: true),
    ],
    leads: [
      ContentLead(
        userId: 'u-asha',
        firstName: 'Asha',
        lastName: 'Rao',
        title: 'Chapter President',
        termStartsOn: '2026-01-01',
      ),
    ],
    members: [
      ContentMember(userId: 'u-ravi', firstName: 'Ravi', lastName: 'Menon'),
      ContentMember(userId: 'u-anil', firstName: 'Anil', lastName: 'Kumar'),
    ],
  ),
  'ch-mum': const OrgContent(),
  'ch-uae': const OrgContent(),
  'co-health': const OrgContent(
    resources: [ContentResource(id: 'rs-9', title: 'Infection Control Checklist', kind: 'TEMPLATE', url: '/uploads/c.pdf')],
    announcements: [ContentAnnouncement(id: 'an-9', title: 'Working group opens', body: 'Join the standards group.')],
    leads: [ContentLead(userId: 'u-dev', firstName: 'Dev', lastName: 'Shah', title: 'Chair')],
    members: [ContentMember(userId: 'u-mira', firstName: 'Mira', lastName: 'Nair')],
  ),
  'co-proc': const OrgContent(),
};

List<ChapterApplication> _sampleApplications() => [
  ChapterApplication(
    id: 'app-1',
    kind: 'NEW_CHAPTER',
    proposedName: 'Hyderabad Chapter',
    city: 'Hyderabad',
    country: 'India',
    motivation: 'Hyderabad has a large community of facility managers with no local chapter.',
    experience: 'Ten years running workplace operations; organised three regional meetups.',
    linkedinUrl: 'https://www.linkedin.com/in/kiran',
    createdAt: DateTime(2026, 11, 2),
    applicant: const RequestPerson(firstName: 'Kiran', lastName: 'Reddy', email: 'kiran@estate.in'),
  ),
  ChapterApplication(
    id: 'app-2',
    kind: 'LEAD_EXISTING',
    chapterName: 'Mumbai Chapter',
    city: 'Mumbai',
    country: 'India',
    motivation: 'The Mumbai chapter has been without a lead since March.',
    experience: 'Chapter volunteer for two years.',
    status: RequestStatus.declined,
    decisionReason: 'The chapter already has a lead in place.',
    decidedAt: DateTime(2026, 10, 20),
    createdAt: DateTime(2026, 10, 12),
    applicant: const RequestPerson(firstName: 'Neha', lastName: 'Joshi', email: 'neha@harbour.in'),
  ),
];

List<CouncilProposal> _sampleProposals() => [
  CouncilProposal(
    id: 'prop-1',
    name: 'Data Centre Operations Council',
    focus: 'Running critical facilities',
    objectives: 'Share uptime practice, publish a commissioning checklist, and run two forums a year.',
    segments: const ['Data Centres', 'Colocation'],
    motivation: 'Members running critical sites have no forum of their own on ICR.',
    createdAt: DateTime(2026, 11, 5),
    proposer: const RequestPerson(firstName: 'Omar', lastName: 'Sheikh', email: 'omar@gridline.in'),
  ),
];
