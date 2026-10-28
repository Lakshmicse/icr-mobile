import '../../core/config.dart';
import 'council_format.dart';
import 'council_models.dart';
import 'councils_repository.dart';

/// The Councils design's sample content, bundled for design review.
class DemoCouncilsRepository implements CouncilsRepository {
  DemoCouncilsRepository();

  /// IST moments, so the tiles read as the design does whatever the clock.
  static DateTime _ist(int month, int day, [int hour = 0, int minute = 0]) =>
      DateTime.utc(2026, month, day, hour, minute).subtract(istOffset);

  static final sustainability = Council(
    id: 'demo-sustainability',
    name: 'Sustainability, ESG & Net- Zero Council',
    slug: 'sustainability-esg-net-zero',
    focus: 'Scope 1-3 auditing benchmarks, green lease clauses, and BRSR core frameworks.',
    // The design's copy, with its own line breaks and its clamp ("...").
    description: 'Setting technical decarbonization benchmarks,\nScope 1-3 auditing frameworks, and green...',
    segments: const ['Net-Zero & ESG'],
    tags: const ['#NetZero', '#Decarbonization', '#Scope3'],
    cover: const FeedPicture.asset('assets/images/demo/councils/cover_sustainability.png'),
    memberCount: 642,
    upcomingEventCount: 3,
    createdAt: DateTime(2023, 3, 1),
    chair: const CouncilChair(name: 'Vikram Malhotra', title: 'Director ESG @ DLF'),
    nextEventAt: _ist(4, 18, 15, 30),
    activityLabel: '3 Working Groups',
    established: 'Est. 2023',
  );

  static final cxo = Council(
    id: 'demo-cxo',
    name: 'CXO Workplace Strategy & FM Leadership',
    slug: 'cxo-workplace-strategy',
    focus: 'Campus consolidation, hybrid occupancy calibrations & CapEx lifecycles.',
    description: 'Executive strategy table for regional campus\nconsolidation, post-pandemic occupancy...',
    segments: const ['CXO & Workplace'],
    tags: const ['#WorkplaceStrategy', '#CampusOps', '#CapEx'],
    cover: const FeedPicture.asset('assets/images/demo/councils/cover_cxo.png'),
    memberCount: 580,
    upcomingEventCount: 2,
    createdAt: DateTime(2022, 9, 1),
    chair: const CouncilChair(name: 'Rajesh Sharma', title: 'VP Facilities @ Infosys'),
    membership: CouncilRole.lead,
    nextEventAt: _ist(4, 22, 16, 0),
    activityLabel: '2 Live Groups',
    unread: 3,
  );

  static final smartBuildings = Council(
    id: 'demo-smart-buildings',
    name: 'Smart Buildings, BMS & PropTech Council',
    slug: 'smart-buildings-bms-proptech',
    focus: 'BACnet interoperability, smart metering and HVAC optimisation.',
    description: 'Interoperability standards for BACnet, smart metering\nprotocols, HVAC optimization...',
    segments: const ['Smart Buildings'],
    tags: const ['#BMS', '#DigitalTwins', '#PropTech', '#IoT'],
    cover: const FeedPicture.asset('assets/images/demo/councils/cover_smart_buildings.png'),
    memberCount: 415,
    upcomingEventCount: 4,
    createdAt: DateTime(2024, 1, 15),
    chair: const CouncilChair(name: 'Ananya Rao', title: 'Workplace Head @ Cisco GCC'),
    nextEventAt: _ist(4, 25, 16, 0),
    activityLabel: '4 Working Groups',
    badge: 'CHARTERED 2024',
  );

  static final legal = Council(
    id: 'demo-legal',
    name: 'Legal, Compliance & Procurement Council',
    slug: 'legal-compliance-procurement',
    focus: 'RFP standardization, anti-trust compliance and vendor SLA governance.',
    description: 'RFP standardization, anti-trust compliance frameworks,\nvendor SLA governance, and...',
    segments: const ['Legal & Procurement'],
    tags: const ['#SLACompliance', '#Procurement', '#Contracts'],
    cover: const FeedPicture.asset('assets/images/demo/councils/cover_legal.png'),
    memberCount: 340,
    upcomingEventCount: 2,
    createdAt: DateTime(2023, 6, 1),
    chair: const CouncilChair(name: 'Arvind Swamy', title: 'General Counsel @ Brookfield\nIndia'),
    nextEventAt: _ist(5, 2, 11, 0),
    activityLabel: '2 Live Groups',
  );

  static final construction = Council(
    id: 'demo-construction',
    name: 'Construction, Projects & MEP Council',
    slug: 'construction-projects-mep',
    focus: 'Fit-out schedules, MEP commissioning standards and modular build.',
    description: 'Accelerated fit-out schedules, MEP commissioning\nstandards, modular...',
    segments: const ['Construction & MEP'],
    tags: const ['#MEPDesign', '#ProjectGovernance', '#ModularBuild'],
    cover: const FeedPicture.asset('assets/images/demo/councils/cover_construction.png'),
    memberCount: 395,
    upcomingEventCount: 3,
    createdAt: DateTime(2024, 2, 1),
    chair: const CouncilChair(name: 'Meenakshi Sundaram', title: 'Head PMO @ L&T Realty'),
    nextEventAt: _ist(5, 8, 10, 0),
    activityLabel: '3 Working Groups',
    badge: 'CHARTERED 2024',
  );

  static final realEstate = Council(
    id: 'demo-real-estate',
    name: 'Corporate & Commercial Real Estate Council',
    slug: 'corporate-commercial-real-estate',
    focus: 'Lease restructuring, transaction benchmarking and SEZ policy.',
    description: 'Lease restructuring, commercial transaction benchmarking,\nSEZ policy shifts, and flexible...',
    segments: const ['Real Estate'],
    tags: const ['#TransactionMgmt', '#PortfolioStrategy', '#SEZRegs'],
    cover: const FeedPicture.asset('assets/images/demo/councils/cover_real_estate.png'),
    memberCount: 512,
    upcomingEventCount: 2,
    createdAt: DateTime(2023, 1, 10),
    chair: const CouncilChair(name: 'Pooja Chhabra', title: 'Global Portfolio Head @ Standard Chartered'),
    nextEventAt: _ist(5, 15, 15, 0),
    activityLabel: '2 Live Groups',
  );

  /// The rail under the stats: the design's two cards (an executive seat
  /// and a membership) plus the third its "3 Active" promises.
  static final joined = <Council>[
    cxo,
    // The design spells the name without the directory card's stray space.
    sustainability.copyWith(name: 'Sustainability, ESG & Net-Zero Council', membership: CouncilRole.member),
    smartBuildings.copyWith(membership: CouncilRole.member),
  ];

  static final roundtables = <Roundtable>[
    Roundtable(
      id: 'demo-rt-1',
      title: 'ESG Mandates: BRSR Core & Scope 3',
      startsAt: _ist(4, 18, 15, 30),
      endsAt: _ist(4, 18, 17, 0),
      mode: 'VIRTUAL',
      tone: RoundtableTone.blue,
      detail: 'Lead: Vikram Malhotra (DLF) • 82 seats claimed',
      councilId: 'demo-sustainability',
      location: 'Online',
    ),
    Roundtable(
      id: 'demo-rt-2',
      title: 'GCC Workplace Leadership & AI FM',
      startsAt: _ist(4, 25, 16, 0),
      endsAt: _ist(4, 25, 17, 30),
      mode: 'HYBRID BLR',
      tone: RoundtableTone.green,
      detail: 'Lead: Rajesh Sharma (Infosys) • 120 seats claimed',
      councilId: 'demo-cxo',
      location: 'Bengaluru (Hybrid)',
    ),
    Roundtable(
      id: 'demo-rt-3',
      title: 'Vendor RFP Standardization & AMCs',
      startsAt: _ist(5, 3, 11, 0),
      endsAt: _ist(5, 3, 12, 30),
      mode: 'CLOSED-DOOR',
      tone: RoundtableTone.dark,
      detail: 'Lead: Arvind Swamy (Brookfield) • 64 seats claimed',
      councilId: 'demo-legal',
      location: 'Mumbai',
    ),
  ];

  static final chapters = <ChapterSummit>[
    ChapterSummit(id: 'demo-blr', slug: 'bengaluru', city: 'Bengaluru', nextEventAt: _ist(4, 26)),
    ChapterSummit(id: 'demo-bom', slug: 'mumbai', city: 'Mumbai', nextEventAt: _ist(5, 10)),
    ChapterSummit(id: 'demo-del', slug: 'delhi-ncr', city: 'Delhi-NCR', nextEventAt: _ist(5, 17)),
    ChapterSummit(id: 'demo-hyd', slug: 'hyderabad', city: 'Hyderabad', nextEventAt: _ist(6, 5)),
  ];

  final _memberships = <String, CouncilRole>{cxo.id: CouncilRole.lead};

  @override
  Future<CouncilsOverview> overview() async {
    final councils = [sustainability, cxo, smartBuildings, legal, construction, realEstate];
    return CouncilsOverview(
      stats: const CouncilStats(
        activeCouncils: 39,
        newThisQuarter: 3,
        quarter: 'Q1',
        peerMembers: 2530,
        peerMembersLabel: '2,530+',
        domains: 152,
        activeRoundtables: 14,
      ),
      councils: [
        for (final c in councils)
          _memberships.containsKey(c.id)
              ? c.copyWith(membership: _memberships[c.id])
              : c.copyWith(clearMembership: true),
      ],
      joined: joined,
      roundtables: roundtables,
      roundtablesCaption: 'Live Chatham-House',
      chapters: chapters,
    );
  }

  @override
  Future<CouncilRole> join(Council council) async => _memberships[council.id] = CouncilRole.member;

  @override
  Future<void> leave(Council council) async => _memberships.remove(council.id);

  @override
  Future<int> unreadNotifications() async => 1;

  @override
  Uri link(Council council, {String? tab}) =>
      AppConfig.sitePage('/councils/${council.slug}${tab == null ? '' : '?tab=$tab'}');

  @override
  Uri eventLink(Roundtable roundtable) => AppConfig.sitePage('/events');

  @override
  Uri calendarLink(Roundtable roundtable) => calendarEntry(
    title: roundtable.title,
    start: roundtable.startsAt,
    end: roundtable.endsAt,
    location: roundtable.location,
  );

  @override
  Uri chapterLink(ChapterSummit chapter) => AppConfig.sitePage('/chapters/${chapter.slug}');
}
