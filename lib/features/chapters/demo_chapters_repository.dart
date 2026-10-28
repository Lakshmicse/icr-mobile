import '../../core/api/api_error.dart';
import '../../core/config.dart';
import 'chapter_models.dart';
import 'chapters_repository.dart';

/// The sample source: six city chapters (the member leads Bengaluru and
/// belongs to Pune), their events, committees, rosters, dispatches and decks.
/// Joins and leaves are kept in memory.
class DemoChaptersRepository implements ChaptersRepository {
  DemoChaptersRepository({DateTime? now}) : now = now ?? DateTime.utc(2026, 10, 24, 9);

  final DateTime now;

  /// Calls, for tests.
  final calls = <String>[];

  final Map<String, ChapterRole> _roles = {'ch-bengaluru': ChapterRole.lead, 'ch-pune': ChapterRole.member};
  static const _initial = {'ch-bengaluru', 'ch-pune'};

  /// The member's RSVPs by event id (null for none), kept in memory; the design's Bengaluru meetup starts GOING.
  final Map<String, String?> _rsvps = {'ev-blr-meetup': 'GOING'};

  late final List<ChapterSummary> _chapters = [
    _c(
      'bengaluru',
      'ICR Bengaluru Chapter',
      'Bengaluru',
      'India',
      'Karnataka',
      128,
      2,
      'India’s tech-campus capital. '
          'Monthly meetups on workplace experience, GCC facilities and campus operations.',
      DateTime.utc(2024, 2, 1),
    ),
    _c(
      'mumbai',
      'ICR Mumbai Chapter',
      'Mumbai',
      'India',
      'Maharashtra',
      96,
      2,
      'High-rise portfolios, BFSI campuses '
          'and coastal-climate building operations in India’s financial capital.',
      DateTime.utc(2023, 6, 1),
    ),
    _c(
      'delhi-ncr',
      'ICR Delhi NCR Chapter',
      'Delhi NCR',
      'India',
      'Delhi / Gurugram / Noida',
      84,
      1,
      'The NCR '
          'corridor — corporate parks in Gurugram and Noida, government-adjacent facilities and large campuses.',
      DateTime.utc(2023, 9, 1),
    ),
    _c(
      'hyderabad',
      'ICR Hyderabad Chapter',
      'Hyderabad',
      'India',
      'Telangana',
      61,
      1,
      'HITEC City’s GCCs, data '
          'centres and life-science campuses, and the people who run them.',
      DateTime.utc(2024, 11, 1),
    ),
    _c(
      'pune',
      'ICR Pune Chapter',
      'Pune',
      'India',
      'Maharashtra',
      9,
      0,
      'Manufacturing campuses, IT parks and the '
          'auto corridor’s facility teams.',
      DateTime.utc(2026, 9, 10),
    ),
    _c(
      'singapore',
      'ICR Singapore Chapter',
      'Singapore',
      'Singapore',
      null,
      2,
      0,
      'Regional headquarters and the '
          'APAC portfolio teams that run them from the Lion City.',
      DateTime.utc(2025, 3, 1),
    ),
  ];

  ChapterSummary _c(
    String slug,
    String name,
    String city,
    String country,
    String? region,
    int members,
    int upcoming,
    String description,
    DateTime createdAt,
  ) => ChapterSummary(
    id: 'ch-$slug',
    name: name,
    slug: slug,
    city: city,
    country: country,
    region: region,
    description: description,
    createdAt: createdAt,
    memberCount: members,
    upcomingEventCount: upcoming,
    role: _roles['ch-$slug'],
  );

  List<ChapterEvent> get _events => [for (final e in _baseEvents) _withRsvp(e)];

  ChapterEvent _withRsvp(ChapterEvent e) {
    final seat = _rsvps.containsKey(e.id) ? _rsvps[e.id] : e.myStatus;
    final base = e.myStatus == 'GOING' && seat != 'GOING' ? e.attendeeCount - 1 : e.attendeeCount;
    final count = seat == 'GOING' && e.myStatus != 'GOING' ? base + 1 : base;
    return ChapterEvent(
      id: e.id,
      slug: e.slug,
      title: e.title,
      kind: e.kind,
      description: e.description,
      location: e.location,
      startsAt: e.startsAt,
      endsAt: e.endsAt,
      capacity: e.capacity,
      attendeeCount: count,
      priceAmount: e.priceAmount,
      inviteOnly: e.inviteOnly,
      chapterSlug: e.chapterSlug,
      chapterName: e.chapterName,
      myStatus: seat,
    );
  }

  late final List<ChapterEvent> _baseEvents = [
    ChapterEvent(
      id: 'ev-blr-meetup',
      slug: 'bengaluru-monthly-meetup',
      title: 'Campus FM at GCC scale',
      kind: 'CHAPTER_MEET',
      description:
          'A GCC facilities head walks through running a 12,000-seat campus: the vendor stack, IFM against bundled '
          'contracts, and the metrics that matter.',
      location: 'Koramangala, Bengaluru',
      startsAt: DateTime.utc(2026, 11, 1, 5, 30),
      endsAt: DateTime.utc(2026, 11, 1, 8, 30),
      capacity: 60,
      attendeeCount: 42,
      chapterSlug: 'bengaluru',
      chapterName: 'ICR Bengaluru Chapter',
      myStatus: 'GOING',
    ),
    ChapterEvent(
      id: 'ev-mum-roundtable',
      slug: 'mumbai-high-rise-roundtable',
      title: 'High-rise façade maintenance roundtable',
      kind: 'ROUNDTABLE',
      location: 'BKC, Mumbai',
      startsAt: DateTime.utc(2026, 11, 8, 10),
      capacity: 30,
      attendeeCount: 30,
      chapterSlug: 'mumbai',
      chapterName: 'ICR Mumbai Chapter',
    ),
    ChapterEvent(
      id: 'ev-ncr-tour',
      slug: 'ncr-campus-tour',
      title: 'Net-zero campus site tour',
      kind: 'SITE_VISIT',
      location: 'Gurugram',
      startsAt: DateTime.utc(2026, 11, 15, 4, 30),
      capacity: 40,
      attendeeCount: 18,
      chapterSlug: 'delhi-ncr',
      chapterName: 'ICR Delhi NCR Chapter',
    ),
    ChapterEvent(
      id: 'ev-blr-summit',
      slug: 'bengaluru-chapter-summit',
      title: 'Bengaluru Chapter Summit',
      kind: 'CONFERENCE',
      location: 'Whitefield, Bengaluru',
      startsAt: DateTime.utc(2026, 11, 22, 4),
      capacity: 200,
      attendeeCount: 96,
      chapterSlug: 'bengaluru',
      chapterName: 'ICR Bengaluru Chapter',
    ),
  ];

  static const _photos = [
    FeedPicture.asset('assets/images/demo/events/card_gcc.jpg'),
    FeedPicture.asset('assets/images/demo/events/card_summit.jpg'),
    FeedPicture.asset('assets/images/demo/post_control_room.jpg'),
    FeedPicture.asset('assets/images/demo/post_green_tower.jpg'),
  ];

  static const _people = [
    ChapterPerson(
      id: 'u-vikram',
      firstName: 'Vikram',
      lastName: 'Malhotra',
      title: 'Chapter President',
      company: 'DLF',
      linkedinUrl: 'https://www.linkedin.com/in/vikram-malhotra',
      role: ChapterRole.lead,
    ),
    ChapterPerson(
      id: 'u-ananya',
      firstName: 'Ananya',
      lastName: 'Rao',
      title: 'Vice President',
      company: 'Cisco GCC',
      role: ChapterRole.lead,
    ),
    ChapterPerson(
      id: 'u-bharat',
      firstName: 'Bharat',
      lastName: 'Buyer',
      title: 'Secretary',
      company: 'TechCorp',
      photo: FeedPicture.asset('assets/images/demo/avatar_me.jpg'),
      role: ChapterRole.lead,
    ),
  ];

  static const _roster = [
    ChapterPerson(
      id: 'u-sarah',
      firstName: 'Sarah',
      lastName: 'Jenkins',
      company: 'JLL',
      photo: FeedPicture.asset('assets/images/demo/avatar_sarah.jpg'),
      role: ChapterRole.member,
    ),
    ChapterPerson(
      id: 'u-david',
      firstName: 'David',
      lastName: 'Chen',
      photo: FeedPicture.asset('assets/images/demo/avatar_david.jpg'),
      role: ChapterRole.member,
    ),
    ChapterPerson(
      id: 'u-elena',
      firstName: 'Elena',
      lastName: 'Rostova',
      company: 'Brookfield Properties',
      photo: FeedPicture.asset('assets/images/demo/avatar_elena.jpg'),
      role: ChapterRole.member,
    ),
  ];

  ChapterSummary _withRole(ChapterSummary c) {
    final role = _roles[c.id];
    final next = _events.where((e) => e.chapterSlug == c.slug).map((e) => e.startsAt).firstOrNull;
    return ChapterSummary(
      id: c.id,
      name: c.name,
      slug: c.slug,
      city: c.city,
      country: c.country,
      region: c.region,
      description: c.description,
      cover: c.cover,
      createdAt: c.createdAt,
      // The base counts include the member's two starting places.
      memberCount: c.memberCount + (role != null ? 1 : 0) - (_initial.contains(c.id) ? 1 : 0),
      upcomingEventCount: c.upcomingEventCount,
      role: role,
      nextEventAt: next,
    );
  }

  ChapterSummary _find(String idOrSlug) => _chapters.firstWhere(
    (c) => c.slug == idOrSlug || c.id == idOrSlug,
    orElse: () => throw ApiError('Chapter not found', statusCode: 404),
  );

  @override
  Future<ChaptersOverview> overview() async {
    calls.add('overview');
    return ChaptersOverview(chapters: _chapters.map(_withRole).toList(), meetups: _events);
  }

  @override
  Future<ChapterDetail> detail(String idOrSlug) async {
    calls.add('detail:$idOrSlug');
    final c = _withRole(_find(idOrSlug));
    final events = _events.where((e) => e.chapterSlug == c.slug).toList();
    final big = c.slug == 'bengaluru';
    return ChapterDetail(
      chapter: c,
      contactEmail: big ? 'bengaluru@icr.network' : null,
      foundedYear: big ? 2014 : null,
      about: big
          ? const [
              AboutBlock(AboutKind.heading, 'Mission'),
              AboutBlock(
                AboutKind.paragraph,
                'To connect and elevate the corporate real estate and facility management community in Bengaluru — '
                'advancing professional standards, workplace innovation and career growth.',
              ),
              AboutBlock(AboutKind.heading, 'What we do'),
              AboutBlock(AboutKind.bullet, 'Monthly meetups, site visits and workplace tours'),
              AboutBlock(AboutKind.bullet, 'Expert panels on sustainability, technology and operations'),
              AboutBlock(AboutKind.bullet, 'Mentoring for early-career professionals'),
            ]
          : [if (c.description != null) AboutBlock(AboutKind.paragraph, c.description!)],
      gallery: big ? _photos : const [],
      stats: ChapterStats(
        memberCount: c.memberCount,
        leadershipCount: big ? 3 : 0,
        upcomingEventCount: events.length,
        pastEventCount: big ? 24 : 0,
        memberCompanyCount: big ? 41 : 0,
      ),
      sponsors: big
          ? const [
              ChapterSponsor(id: 's1', name: 'Bengaluru Facilities Group', tier: 'Platinum'),
              ChapterSponsor(id: 's2', name: 'Sodexo India', tier: 'Gold'),
              ChapterSponsor(id: 's3', name: 'CBRE', tier: 'Gold'),
              ChapterSponsor(id: 's4', name: 'Schneider Electric', tier: 'Silver'),
            ]
          : const [],
      leads: big ? _people : const [],
      upcomingEvents: events,
    );
  }

  @override
  Future<ChapterMembersPage> members(
    String slug, {
    int page = 1,
    String? search,
    MemberFilter filter = MemberFilter.all,
  }) async {
    calls.add('members:$slug:$page:${filter.name}:${search ?? ''}');
    var all = [..._people, ..._roster];
    if (filter == MemberFilter.committee) all = all.where((p) => p.role == ChapterRole.lead).toList();
    if (filter == MemberFilter.corporate) all = all.where((p) => p.company != null).toList();
    final q = (search ?? '').trim().toLowerCase();
    if (q.isNotEmpty) all = all.where((p) => p.name.toLowerCase().contains(q)).toList();
    return ChapterMembersPage(members: page == 1 ? all : const [], total: all.length, page: page, hasNext: false);
  }

  @override
  Future<List<ChapterEvent>> events(String slug, {bool past = false}) async {
    calls.add('events:$slug:${past ? 'past' : 'upcoming'}');
    if (past) {
      return [
        ChapterEvent(
          id: 'ev-past',
          slug: 'q2-meetup',
          title: 'Q2 meetup: vendor SLAs that hold',
          kind: 'CHAPTER_MEET',
          location: 'Indiranagar, Bengaluru',
          startsAt: DateTime.utc(2026, 6, 14, 5, 30),
          attendeeCount: 54,
          chapterSlug: slug,
        ),
      ];
    }
    return _events.where((e) => e.chapterSlug == slug).toList();
  }

  @override
  Future<List<ChapterUpdate>> updates(String slug) async {
    calls.add('updates:$slug');
    return [
      ChapterUpdate(
        id: 'a1',
        title: 'Welcome to the chapter’s community hub',
        body: 'RSVP to upcoming events, meet the leadership team and download resources. New members welcome!',
        pinned: true,
        createdAt: DateTime.utc(2026, 10, 1),
      ),
      ChapterUpdate(
        id: 'a2',
        title: 'Nominations open for the 2026 committee',
        body: 'We are looking for volunteers to join the chapter committee. Reach out to the leadership team.',
        createdAt: DateTime.utc(2026, 10, 12),
      ),
    ];
  }

  @override
  Future<List<ChapterResource>> resources(String slug) async {
    calls.add('resources:$slug');
    return const [
      ChapterResource(
        id: 'r1',
        title: 'Workplace Experience Benchmark 2026',
        kind: 'WHITEPAPER',
        url: 'https://example.com/whitepaper.pdf',
        sizeLabel: '2.4 MB',
      ),
      ChapterResource(
        id: 'r2',
        title: 'Chapter Meetup — Deck',
        kind: 'PRESENTATION',
        url: 'https://example.com/deck.pdf',
        sizeLabel: '5.1 MB',
      ),
      ChapterResource(
        id: 'r3',
        title: 'Vendor SLA Scorecard Template',
        kind: 'TEMPLATE',
        url: 'https://example.com/template.xlsx',
        sizeLabel: '48 KB',
      ),
    ];
  }

  @override
  Future<List<ChapterSummary>> nearby(ChapterSummary chapter) async {
    calls.add('nearby:${chapter.slug}');
    return _chapters.where((c) => c.country == chapter.country && c.id != chapter.id).take(4).map(_withRole).toList();
  }

  @override
  Future<ChapterRole> join(ChapterSummary chapter) async {
    calls.add('join:${chapter.id}');
    return _roles[chapter.id] ??= ChapterRole.member;
  }

  @override
  Future<void> leave(ChapterSummary chapter) async {
    calls.add('leave:${chapter.id}');
    _roles.remove(chapter.id);
  }

  @override
  Future<String> rsvp(ChapterEvent event) async {
    calls.add('rsvp:${event.id}');
    final status = event.full ? 'WAITLISTED' : 'GOING';
    _rsvps[event.id] = status;
    return status;
  }

  @override
  Future<void> cancelRsvp(ChapterEvent event) async {
    calls.add('cancel:${event.id}');
    _rsvps[event.id] = null;
  }

  @override
  Future<int> unreadNotifications() async => 3;

  @override
  Uri link(ChapterSummary chapter) => AppConfig.sitePage('/chapters/${chapter.slug}');
}
