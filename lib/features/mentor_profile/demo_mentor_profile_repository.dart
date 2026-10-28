import '../../core/config.dart';
import 'mentor_profile_models.dart';
import 'mentor_profile_repository.dart';

/// The Mentor Profile designs' sample content, bundled for design review.
class DemoMentorProfileRepository implements MentorProfileRepository {
  DemoMentorProfileRepository();

  static const _assets = 'assets/images/demo/mentorship';

  /// Requests the member has sent in this session.
  final _requested = <String>{};
  bool _askedMentoring = false;

  static final mentor = MentorProfile(
    id: 'demo-srikanth',
    userId: 'demo-srikanth-user',
    firstName: 'Srikanth',
    lastName: 'Sriramagiri',
    // As live: the current role is the first row of the Career Journey, and the
    // mentor's own headline carries the line the design draws under the name.
    roleTitle: 'APAC Lead, Azure Planning & Execution',
    roleOrganisation: 'Microsoft',
    headline: 'Supply Chain Leader at Microsoft • Ex-Tata Aerospace • BITS Pilani • IIT KGP',
    bioHtml:
        '<p>Result-oriented professional with ~15 years of management experience in Technology and Aerospace '
        '&amp; Defense sectors with a proven track record across Operations, Supply Chain and Project Management.</p>'
        '<p>Have been the founding member of Supply Planning at Microsoft and established the CoE for Aero Engines '
        'Manufacturing at Tata Advanced Systems, scaling a greenfield site into a full production line while '
        'building the supplier base behind it.</p>',
    photo: const FeedPicture.asset('$_assets/profile_avatar.png'),
    cover: const FeedPicture.asset('$_assets/profile_cover.jpg'),
    yearsExperience: 15,
    city: 'Hyderabad',
    modes: const ['Video', 'In person'],
    modeKeys: const ['VIDEO', 'IN_PERSON'],
    languages: const ['English', 'Telugu', 'Hindi', 'Kannada'],
    competencies: const [
      'Supply Chain Optimization',
      'Strategic Capacity Planning',
      'Project Management',
      'Executive Team Leadership',
    ],
    topics: const ['Azure Cloud Planning', 'Power BI & Analytics', 'Advanced Financial Modeling', 'SAP S/4HANA ERP'],
    competenciesLabel: 'Domain Expertise',
    topicsLabel: 'Softwares & Frameworks',
    rating: 5,
    ratingCount: 42,
    stats: const MentorStats(
      sessions: '26+',
      sessionsBadge: 'Top 5% Mentor',
      mentees: '12',
      menteesCaption: 'Active Mentees',
      menteesNote: 'Across 4 countries',
    ),
    experience: const [
      MentorRole(
        title: 'APAC Lead, Azure Planning & Execution',
        organisation: 'Microsoft Corporation',
        organisationLinked: true,
        startYear: 2022,
        isCurrent: true,
        place: 'Hyderabad',
        description:
            'Orchestrating hyperscale cloud capacity allocation, datacenter supply continuity, and cross-functional '
            'APAC infrastructure planning.',
        durationLabel: '2 yrs 4 mos',
      ),
      MentorRole(
        title: 'Head - Projects, PPC & Industrial Eng.',
        organisation: 'Tata Advanced Systems Ltd (TASL)',
        startYear: 2012,
        endYear: 2022,
        place: 'Aerospace & Defense CoE',
        description:
            'Pioneered aerostructures assembly facilities, strategic supplier ecosystems, and lean manufacturing '
            'processes for global defense partners.',
        durationLabel: '10 Yrs',
      ),
      MentorRole(
        title: 'Senior Consultant - Supply Chain',
        organisation: 'Infosys Consulting',
        startYear: 2009,
        endYear: 2012,
        place: 'Global Operations Practice',
        description:
            'Executed end-to-end procurement transformation, inventory turn optimization, and ERP integration for '
            'Fortune 100 industrial clients.',
        durationLabel: '3 Yrs',
      ),
    ],
    education: const [
      MentorEducation(
        institution: 'Vinod Gupta School of Management, IIT Kharagpur',
        degree: 'Master of Business Administration (MBA)',
        field: 'Operations & Strategy',
        startYear: 2009,
        endYear: 2011,
      ),
      MentorEducation(
        institution: 'Birla Institute of Technology and Science (BITS), Pilani',
        degree: 'Bachelor of Engineering (B.E. Hons)',
        field: 'Engineering Honors',
        startYear: 2005,
        endYear: 2009,
      ),
      MentorEducation(
        institution: 'Birla Institute of Technology and Science (BITS), Pilani',
        degree: 'Bachelor of Engineering (B.E. Hons)',
        field: 'Engineering Honors',
        startYear: 2005,
        endYear: 2009,
      ),
    ],
    availability: const [
      AvailabilityBlock(weekday: 1, startMin: 19 * 60, endMin: 21 * 60),
      AvailabilityBlock(weekday: 4, startMin: 19 * 60, endMin: 21 * 60),
      AvailabilityBlock(weekday: 6, startMin: 19 * 60, endMin: 21 * 60),
    ],
    viewer: const MentorViewer(),
    openSlots: 2,
    capacity: 10,
    yearsLabel: '15+ Years Leadership',
    slotLabel: 'Next Slot: Tomorrow, 7:00 PM',
  );

  static const _month1 = RoadmapModule(
    title: 'Root Cause Analysis & Strategy',
    badge: 'Month 1',
    steps: [
      'Week 1: Career Diagnostic & Gap Analysis',
      'Week 2: Strategic Positioning & Resume',
      'Week 3: Mock Case Studies & Leadership Drills',
      'Week 4: Action Plan & Referral Cadence',
    ],
  );

  static final discoveryCall = MentorOffering(
    id: 'demo-discovery',
    kind: OfferingKind.oneOnOne,
    title: '"What\'s going wrong?" Discovery Call',
    blurb: 'Diagnostic session uncovering key blockers in your job hunt, supply chain switch, or promotion path.',
    durationMin: 15,
    tags: const [OfferingTag('BEST SELLER'), OfferingTag('15 Min')],
    ctaLabel: 'Book Now',
    isBestSeller: true,
    rating: 4.96,
    ratingCount: 128,
    cover: const FeedPicture.asset('$_assets/profile_offering_cover.jpg'),
    kicker: 'DISCOVERY CALL',
    sheetTitle: "What's going wrong?",
    sheetBlurb:
        'A diagnostic 1:1 mentorship program to identify and resolve career bottlenecks in corporate real estate & FM.',
    facts: const [
      OfferingFact(glyph: OfferingGlyph.person, label: '1:1 Live Call'),
      OfferingFact(glyph: OfferingGlyph.clock, label: '30 Minutes'),
      OfferingFact(glyph: OfferingGlyph.calendar, label: 'Mon, Thu, Sat slots'),
    ],
    details: const [
      OfferingDetail(
        glyph: OfferingGlyph.calendar,
        title: '2 Sessions / Week',
        body: 'Consistent touchpoints to maintain momentum.',
      ),
      OfferingDetail(
        glyph: OfferingGlyph.clock,
        title: '30 Minutes / session',
        body: 'Focused, high-impact diagnostic discussions.',
      ),
      OfferingDetail(
        glyph: OfferingGlyph.list,
        title: '8 Sessions/ month',
        body: 'Comprehensive coverage over a four-week period.',
      ),
      OfferingDetail(
        glyph: OfferingGlyph.chat,
        title: 'Unlimited support',
        body: 'Direct access between sessions for quick questions.',
      ),
    ],
    roadmap: const [
      RoadmapTerm(label: '1 Month', modules: [_month1]),
      RoadmapTerm(
        label: '3 Months',
        modules: [
          _month1,
          RoadmapModule(title: 'Positioning & Network Leverage', badge: 'Month 2'),
          RoadmapModule(title: 'Interview Mastery & Offers', badge: 'Month 3'),
        ],
      ),
      RoadmapTerm(
        label: '6 Months',
        modules: [
          _month1,
          RoadmapModule(title: 'Positioning & Network Leverage', badge: 'Month 2'),
          RoadmapModule(title: 'Interview Mastery & Offers', badge: 'Month 3'),
          RoadmapModule(title: 'First 90 Days in the Role', badge: 'Months 4–6'),
        ],
      ),
    ],
    previewLabel: 'Inspect 4-week diagnostic preview',
  );

  static final proTier = MentorOffering(
    id: 'demo-pro-tier',
    kind: OfferingKind.plan,
    title: 'Pro Mentorship Tier',
    pricePaisa: 1250000,
    perMonthPaisa: 1250000,
    billingPeriodMonths: 1,
    sessionsPerMonth: 2,
    tags: const [OfferingTag('2 Sessions / mo')],
    ctaLabel: 'Subscribe',
    inclusions: const [
      '2 dedicated live 1:1 strategy calls each month',
      'Unlimited async Slack / WhatsApp query support',
      'Direct resume & LinkedIn profile optimization',
    ],
    kicker: 'ONGOING PLAN',
    facts: const [
      OfferingFact(glyph: OfferingGlyph.sessions, label: '2 / month'),
      OfferingFact(glyph: OfferingGlyph.calendar, label: '1-month term'),
    ],
    details: const [
      OfferingDetail(glyph: OfferingGlyph.sessions, title: '2 Sessions / Month', body: 'Booked as you go.'),
      OfferingDetail(glyph: OfferingGlyph.calendar, title: '1-month term', body: 'Paid per term; never auto-renewed.'),
    ],
    planKicker: 'FLAGSHIP COHORT',
    seatsNote: 'Only 2 slots left',
    applyLabel: 'Apply for Pro Mentorship',
  );

  static final sampleOfferings = <MentorOffering>[
    discoveryCall,
    const MentorOffering(
      id: 'demo-interview',
      kind: OfferingKind.oneOnOne,
      title: 'Personal Interview & GD Preparation',
      blurb: 'Structured STAR framework drills, case interview frameworks & behavioral narrative refinement.',
      durationMin: 15,
      tags: [OfferingTag('15 Min • 1:1 Video')],
      ctaLabel: 'Book Now',
      kicker: 'FREE SESSION',
      facts: [
        OfferingFact(glyph: OfferingGlyph.person, label: '1:1 Video'),
        OfferingFact(glyph: OfferingGlyph.clock, label: '15 Minutes'),
        OfferingFact(glyph: OfferingGlyph.calendar, label: 'Mon, Thu, Sat slots'),
      ],
      details: [
        OfferingDetail(
          glyph: OfferingGlyph.sessions,
          title: '1 Session',
          body: 'One live call; the mentor sets the time.',
        ),
        OfferingDetail(glyph: OfferingGlyph.clock, title: '15 Minutes', body: 'A focused drill.'),
      ],
    ),
    const MentorOffering(
      id: 'demo-linkedin',
      kind: OfferingKind.resource,
      title: 'LinkedIn Niche Bible (Strategy Handbook)',
      blurb: 'Step-by-step executive profile playbook to attract global recruiters and Fortune 500 hiring managers.',
      pricePaisa: 900,
      compareAtPaisa: 49900,
      tags: [OfferingTag('Digital Guide'), OfferingTag('Instant Download', green: true)],
      ctaLabel: 'Purchase Guide',
      fileName: 'linkedin-niche-bible.pdf',
      kicker: 'RESOURCE',
      facts: [
        OfferingFact(glyph: OfferingGlyph.download, label: 'Instant download'),
        OfferingFact(glyph: OfferingGlyph.list, label: 'PDF'),
      ],
      details: [
        OfferingDetail(glyph: OfferingGlyph.download, title: 'Instant download', body: 'Yours as soon as it clears.'),
      ],
    ),
    const MentorOffering(
      id: 'demo-prompts',
      kind: OfferingKind.resource,
      title: 'AI & ChatGPT Prompts for Resume Building',
      blurb: '50+ battle-tested prompts engineered for ATS parsing and impactful achievement metrics.',
      pricePaisa: 900,
      compareAtPaisa: 39900,
      tags: [OfferingTag('Curated Prompts')],
      ctaLabel: 'Purchase Guide',
      fileName: 'resume-prompts.pdf',
      kicker: 'RESOURCE',
      facts: [OfferingFact(glyph: OfferingGlyph.download, label: 'Instant download')],
      details: [
        OfferingDetail(glyph: OfferingGlyph.download, title: 'Instant download', body: 'Yours as soon as it clears.'),
      ],
    ),
    const MentorOffering(
      id: 'demo-sop',
      kind: OfferingKind.query,
      title: 'Statement of Purpose (SOP) Review',
      blurb: "Line-by-line feedback on academic, master's or executive business school admissions essays.",
      tags: [OfferingTag('Async Query • 24h TAT')],
      ctaLabel: 'Ask Query',
      slaHours: 24,
      kicker: 'WRITTEN CONSULTATION',
      facts: [
        OfferingFact(glyph: OfferingGlyph.chat, label: 'Written answer'),
        OfferingFact(glyph: OfferingGlyph.clock, label: 'Within 24 hours'),
      ],
      details: [
        OfferingDetail(glyph: OfferingGlyph.clock, title: '24-hour answer', body: 'A reply in a private thread.'),
      ],
    ),
    const MentorOffering(
      id: 'demo-mba',
      kind: OfferingKind.resource,
      title: 'MBA Placements Bible (Summer & Finals)',
      blurb: 'Comprehensive consulting & supply chain placement prep kit with previous interview transcripts.',
      pricePaisa: 900,
      compareAtPaisa: 59900,
      tags: [OfferingTag('PDF & Templates')],
      ctaLabel: 'Purchase Guide',
      fileName: 'mba-placements-bible.pdf',
      kicker: 'RESOURCE',
      facts: [OfferingFact(glyph: OfferingGlyph.download, label: 'Instant download')],
      details: [
        OfferingDetail(glyph: OfferingGlyph.download, title: 'Instant download', body: 'Yours as soon as it clears.'),
      ],
    ),
    proTier,
  ];

  static final review = MentorReview(
    id: 'demo-review-1',
    name: 'Dev Mangtani',
    subline: 'Operations Analyst',
    photo: const FeedPicture.asset('$_assets/profile_reviewer.png'),
    rating: 5,
    quote:
        'I really liked how the session provided comprehensive knowledge about upcoming corporate internship '
        'opportunities, clarifying my transition doubts from aerospace to cloud logistics. Srikanth sir is '
        'exceptionally structured!',
    agoLabel: '1 yr ago',
  );

  @override
  Future<MentorProfile> profile(String mentorId) async => _askedMentoring
      ? mentor.copyWith(
          viewer: const MentorViewer(
            canRequest: false,
            blocker: AskBlocker.requestPending,
            blockedReason: 'Your request is with this mentor, awaiting a reply.',
            pendingRequestId: 'demo-request',
          ),
        )
      : mentor;

  @override
  Future<List<MentorOffering>> offerings(MentorProfile mentor) async => [
    for (final o in sampleOfferings)
      _requested.contains(o.id) ? o.copyWith(myOpenRequestId: 'demo-purchase-${o.id}') : o,
  ];

  @override
  Future<List<MentorReview>> reviews(MentorProfile mentor) async => [review];

  @override
  Future<int> unreadNotifications() async => 1;

  @override
  Future<bool> hasPhone() async => true;

  @override
  Future<void> requestMentoring(MentorProfile mentor, {required String message, String? phone}) async =>
      _askedMentoring = true;

  @override
  Future<String?> openConversation(MentorProfile mentor) async => null;

  @override
  Future<String?> requestSession(
    MentorOffering offering, {
    required String topic,
    required String mode,
    String? preferredTimes,
    String? phone,
  }) async {
    _requested.add(offering.id);
    return 'demo-purchase-${offering.id}';
  }

  @override
  Future<CheckoutOutcome> buy(MentorProfile mentor, MentorOffering offering, {String? phone}) async =>
      switch (offering.kind) {
        OfferingKind.resource when offering.free => const CheckoutOutcome(
          CheckoutState.completed,
          message: 'Added to your purchases.',
        ),
        OfferingKind.program => CheckoutOutcome(
          CheckoutState.requested,
          message: 'Request sent. Once ${mentor.firstName} accepts, you pay on the website.',
        ),
        OfferingKind.plan when offering.free => CheckoutOutcome(
          CheckoutState.completed,
          message: 'You are on ${offering.title}.',
        ),
        OfferingKind.groupSession => CheckoutOutcome(
          CheckoutState.website,
          sitePath: '/mentorship/groups/${offering.groupSessionId}',
        ),
        _ => CheckoutOutcome(CheckoutState.website, sitePath: '/mentorship/mentors/${mentor.id}'),
      };

  @override
  Uri link(MentorProfile mentor) => AppConfig.sitePage('/mentorship/mentors');
}
