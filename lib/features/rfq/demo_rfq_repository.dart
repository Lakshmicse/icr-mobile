import '../../core/api/api_error.dart';
import '../../core/config.dart';
import 'rfq_format.dart' show titleFromFileName;
import 'rfq_links.dart';
import 'rfq_models.dart';
import 'rfq_repository.dart';

/// Sample content for the requirements screens, in the Marketplace design's
/// world: Bharat's three requirements, bids from the design's suppliers
/// (BlueDot, InnoWork, SecureTech, GreenGuard, SafeHome, Vikasha Aero Tech),
/// a board of other buyers' requirements and two new alerts. It keeps what
/// is done to it, so the demo app (and the widget tests) can act on it.
class DemoRfqRepository implements RfqRepository {
  DemoRfqRepository({DateTime? now}) : now = now ?? RfqClock.now() {
    _seed();
  }

  /// The moment the sample dates are counted from.
  final DateTime now;

  static const bharatId = 'demo-bharat';
  static const companyId = 'demo-bharat-facilities';

  /// The three requirements of Bharat's (the "My RFQ's 3").
  static const securityId = 'demo-rfq-security';
  static const ifmId = 'demo-rfq-ifm';
  static const homeId = 'demo-rfq-home-security';

  /// A requirement on the open board, and the one Bharat's company was invited to.
  static const boardId = 'demo-board-hvac';
  static const invitedId = 'demo-board-facade';

  /// A staged RFQ at the quote stage: the supplier was shortlisted and may send a detailed quote.
  static const guardingId = 'demo-board-guarding';

  Poster poster = const Poster(
    id: bharatId,
    name: 'Bharat Buyer',
    email: 'buyer@icr.dev',
    role: 'COMPANY_ADMIN',
    phone: '+919879879898',
    companyId: companyId,
    companyName: 'Bharat Facilities',
  );

  VendorAccess vendorAccess = const VendorAccess(
    vendorId: 'demo-vendor-bharat',
    verified: true,
    canBid: true,
    canRespondToEnquiry: true,
    bidLimit: null,
    canRevealContact: true,
    verificationLevel: 'VERIFIED',
    tier: 'GOLD',
  );

  final Map<String, Requirement> _rfqs = {};
  final Map<String, List<Bid>> _bids = {};
  final Map<String, List<PreQualResponse>> _responses = {};
  final Map<String, List<SupplierInvite>> _invites = {};
  final List<Requirement> _board = [];
  final List<MyBid> _myBids = [];
  final List<RfqAlert> _alerts = [];
  final Set<String> _declined = {};
  int _ids = 0;

  DateTime _days(int n, {int hour = 18}) => DateTime.utc(now.year, now.month, now.day + n, hour, 29);

  static const blueDot = SupplierRef(
    vendorId: 'demo-v-bluedot',
    name: 'BlueDot',
    companyId: 'demo-c-bluedot',
    rating: 4.8,
    ratingCount: 124,
    headline: 'Corporate Security • Biometric systems, CCTV & Manpower',
    city: 'Mumbai',
    verificationLevel: 'VERIFIED',
  );
  static const innoWork = SupplierRef(
    vendorId: 'demo-v-innowork',
    name: 'InnoWork',
    companyId: 'demo-c-innowork',
    rating: 4.8,
    ratingCount: 124,
    headline: 'Corporate Security • Biometric systems, CCTV & Manpower',
    city: 'Pune',
    verificationLevel: 'CERTIFIED',
  );
  static const secureTech = SupplierRef(
    vendorId: 'demo-v-securetech',
    name: 'SecureTech',
    companyId: 'demo-c-securetech',
    rating: 4.7,
    ratingCount: 150,
    headline: 'Network Security • Firewalls, VPNs & Threat Detection',
    city: 'Bengaluru',
    verificationLevel: 'VERIFIED',
  );
  static const greenGuard = SupplierRef(
    vendorId: 'demo-v-greenguard',
    name: 'GreenGuard',
    companyId: 'demo-c-greenguard',
    rating: 4.5,
    ratingCount: 98,
    headline: 'Home Security • Alarm system, Surveillance cameras & Monitoring',
    city: 'Hyderabad',
    verificationLevel: 'VERIFIED',
  );
  static const safeHome = SupplierRef(
    vendorId: 'demo-v-safehome',
    name: 'SafeHome',
    companyId: 'demo-c-safehome',
    rating: 4.6,
    ratingCount: 85,
    headline: 'Residential Security • Smart locks, Home automation & Motion',
    city: 'Chennai',
    verificationLevel: 'REGISTERED',
  );
  static const vikasha = SupplierRef(
    vendorId: 'demo-v-vikasha',
    name: 'Vikasha Aero Tech',
    companyId: 'demo-c-vikasha',
    rating: 4.9,
    ratingCount: 84,
    headline: 'Robotic high-rise maintenance & drone facade engineering',
    city: 'Bengaluru',
    verificationLevel: 'PREFERRED',
  );

  static const _names = {
    'SECURITY': 'Security Services',
    'PHYSICAL_SECURITY': 'Physical Security',
    'ELECTRONIC_SECURITY': 'Electronic Security',
    'FACILITY_MANAGEMENT': 'Integrated Facility Management',
    'HOUSEKEEPING': 'Housekeeping',
    'MEP': 'Engineering Services',
    'HVAC': 'HVAC',
    'FACADE_CLEANING': 'Facade Cleaning',
  };

  void _seed() {
    _rfqs[securityId] = Requirement(
      id: securityId,
      title: 'Corporate Security — Biometric systems, CCTV & Manpower',
      kind: RfqKind.enquiry,
      status: RfqStatus.published,
      description:
          'Round-the-clock guarding for our Mumbai HQ (3 floors, 600 staff), biometric access at two entrances '
          'and a CCTV refresh of 48 cameras with 30-day retention.',
      buyerId: bharatId,
      companyId: companyId,
      category: 'SECURITY',
      subcategory: 'PHYSICAL_SECURITY',
      facilityType: 'Corporate Offices',
      locations: const ['Mumbai'],
      city: 'Mumbai',
      state: 'Maharashtra',
      country: 'India',
      budget: 1200000,
      dueDate: _days(9),
      contactName: 'Bharat Buyer',
      contactEmail: 'buyer@icr.dev',
      contactPhone: '+91 98798 79898',
      companyName: 'Bharat Facilities',
      items: const [
        RfqItem(name: 'Security guards (24×7)', quantity: 12, unit: 'guards'),
        RfqItem(name: 'Biometric access readers', quantity: 4, unit: 'units'),
        RfqItem(name: 'CCTV cameras, 4 MP', quantity: 48, unit: 'cameras'),
      ],
      files: const [
        RfqFile(id: 'demo-file-1', title: 'Floor plan — HQ', url: '/uploads/demo-floor-plan.pdf', name: 'floor-plan.pdf', mimeType: 'application/pdf'),
      ],
      quoteCount: 3,
      createdAt: _days(-4, hour: 6),
      publishedAt: _days(-4, hour: 6),
      updatedAt: _days(-1, hour: 6),
      responses: const ResponseCounts(bids: 3, bidsPending: 2),
    );
    _bids[securityId] = [
      Bid(
        id: 'demo-bid-bluedot',
        rfqId: securityId,
        supplier: blueDot,
        status: BidStatus.pending,
        amount: 1140000,
        leadTimeDays: 10,
        message: 'Twelve PSARA-licensed guards across three shifts, four biometric readers with a year of AMC, and 48 cameras installed in two weekends.',
        createdAt: _days(-1, hour: 4),
        files: const [
          RfqFile(
            id: 'demo-bidfile-1',
            title: 'Quotation',
            url: '/uploads/demo-quotation.pdf',
            name: 'quotation.pdf',
            mimeType: 'application/pdf',
            size: 245000,
          ),
        ],
        conversationId: 'demo-thread-bluedot',
      ),
      Bid(
        id: 'demo-bid-innowork',
        rfqId: securityId,
        supplier: innoWork,
        status: BidStatus.shortlisted,
        amount: 1250000,
        leadTimeDays: 7,
        message: 'Manpower and systems from one team, with a supervisor on site every day.',
        createdAt: _days(-2, hour: 9),
        conversationId: 'demo-thread-innowork',
      ),
      Bid(
        id: 'demo-bid-securetech',
        rfqId: securityId,
        supplier: secureTech,
        status: BidStatus.pending,
        amount: 1080000,
        leadTimeDays: 14,
        message: 'We can start with the CCTV refresh and add guarding from the first of next month.',
        createdAt: _days(-3, hour: 11),
      ),
    ];
    _invites[securityId] = [
      SupplierInvite(supplier: blueDot, status: InviteStatus.responded, createdAt: _days(-4, hour: 6)),
      SupplierInvite(supplier: vikasha, status: InviteStatus.invited, createdAt: _days(-4, hour: 6)),
    ];

    _rfqs[ifmId] = Requirement(
      id: ifmId,
      title: 'Bharat Facilities — Integrated Facility Management RFQ',
      kind: RfqKind.rfq,
      status: RfqStatus.published,
      stage: RfqStage.prequalification,
      scope:
          'Integrated facility management for a 12-acre tech park in Bengaluru: housekeeping, MEP operations, '
          'landscaping and helpdesk, with monthly SLA reporting.',
      buyerId: bharatId,
      companyId: companyId,
      category: 'FACILITY_MANAGEMENT',
      subcategory: 'HOUSEKEEPING',
      facilityType: 'IT & ITES',
      locations: const ['Bengaluru'],
      city: 'Bengaluru',
      state: 'Karnataka',
      country: 'India',
      budget: 25000000,
      preQualEndDate: _days(5),
      dueDate: _days(19),
      criteria: const SupplierCriteria(
        minYearsInBusiness: 5,
        minAnnualTurnover: 50000000,
        minEmployees: '201-500',
        requiredPresence: Presence.panIndia,
        statutoryCompliance: ['GST', 'PF', 'ESI'],
      ),
      contactName: 'Bharat Buyer',
      contactEmail: 'buyer@icr.dev',
      contactPhone: '+91 98798 79898',
      companyName: 'Bharat Facilities',
      createdAt: _days(-6, hour: 6),
      publishedAt: _days(-6, hour: 6),
      updatedAt: _days(-1, hour: 8),
      responses: const ResponseCounts(prequal: 2, prequalPending: 2),
    );
    _responses[ifmId] = [
      PreQualResponse(
        supplier: greenGuard,
        status: PreQualStatus.pending,
        yearsInBusiness: 11,
        annualTurnover: 82000000,
        employeeCount: '500+',
        presence: Presence.panIndia,
        statutoryCompliance: const ['GST', 'PF', 'ESI', 'PT'],
        submittedAt: _days(-2, hour: 5),
      ),
      PreQualResponse(
        supplier: safeHome,
        status: PreQualStatus.pending,
        yearsInBusiness: 6,
        annualTurnover: 31000000,
        employeeCount: '201-500',
        presence: Presence.local,
        statutoryCompliance: const ['GST', 'PF'],
        meetsCriteria: false,
        failures: const ['Annual turnover', 'Presence', 'Statutory compliance (ESI)'],
        submittedAt: _days(-1, hour: 7),
      ),
    ];

    _rfqs[homeId] = Requirement(
      id: homeId,
      title: 'Residential Communities — Home Security',
      kind: RfqKind.enquiry,
      status: RfqStatus.draft,
      description: 'Alarm systems, surveillance cameras and 24×7 monitoring for a 320-flat gated community in Pune.',
      buyerId: bharatId,
      companyId: companyId,
      category: 'SECURITY',
      subcategory: 'ELECTRONIC_SECURITY',
      facilityType: 'Residential Communities',
      locations: const ['Pune'],
      city: 'Pune',
      state: 'Maharashtra',
      country: 'India',
      contactName: 'Bharat Buyer',
      contactPhone: '+91 98798 79898',
      companyName: 'Bharat Facilities',
      createdAt: _days(-1, hour: 10),
      updatedAt: _days(0, hour: 3),
      responses: const ResponseCounts(),
    );

    const alpha = BuyerInfo(
      name: 'Nita Rao',
      companyId: 'demo-c-alpha',
      companyName: 'Alpha Tech Parks',
      verified: true,
      verificationLevel: 'VERIFIED',
      gstVerified: true,
    );
    const zenith = BuyerInfo(name: 'Arjun Mehta', companyId: 'demo-c-zenith', companyName: 'Zenith Hospitals', verified: true);
    _board.addAll([
      Requirement(
        id: boardId,
        title: 'Annual HVAC AMC — Alpha Tech Park, Hyderabad',
        kind: RfqKind.enquiry,
        status: RfqStatus.published,
        description: 'Quarterly preventive maintenance of two 400 TR chiller plants and 60 AHUs, with breakdown cover.',
        category: 'MEP',
        subcategory: 'HVAC',
        facilityType: 'IT & ITES',
        locations: const ['Hyderabad'],
        city: 'Hyderabad',
        country: 'India',
        budget: 1800000,
        dueDate: _days(6),
        quoteCount: 4,
        createdAt: _days(-2, hour: 6),
        buyer: alpha,
        matchScore: 82,
        matched: true,
        matchReasons: const [
          MatchReason(key: 'category', label: 'Matches your service category', points: 50, hit: true),
          MatchReason(key: 'location', label: 'In your service area', points: 0, hit: false),
          MatchReason(key: 'rating', label: 'Your buyer rating', points: 14, hit: true),
          MatchReason(key: 'trust', label: 'Your verification level', points: 4, hit: true),
          MatchReason(key: 'premium', label: 'Premium membership boost', points: 5, hit: true),
        ],
      ),
      Requirement(
        id: 'demo-board-housekeeping',
        title: 'Zenith Hospitals — Housekeeping RFQ',
        kind: RfqKind.rfq,
        status: RfqStatus.published,
        stage: RfqStage.prequalification,
        scope: 'Hospital-grade housekeeping for a 300-bed hospital: wards, OTs and common areas, three shifts.',
        category: 'FACILITY_MANAGEMENT',
        subcategory: 'HOUSEKEEPING',
        facilityType: 'Hospitals',
        locations: const ['Chennai'],
        city: 'Chennai',
        country: 'India',
        budget: 9600000,
        preQualEndDate: _days(3),
        dueDate: _days(15),
        quoteCount: 0,
        createdAt: _days(-1, hour: 9),
        buyer: zenith,
        matchScore: 64,
        matched: true,
      ),
      Requirement(
        id: 'demo-board-pest',
        title: 'Retail — Pest Control',
        kind: RfqKind.enquiry,
        status: RfqStatus.published,
        description: 'Monthly pest control across 14 stores in Pune and Mumbai.',
        category: 'FACILITY_MANAGEMENT',
        facilityType: 'Retail',
        locations: const ['Pune', 'Mumbai'],
        city: 'Pune',
        country: 'India',
        createdAt: _days(-5, hour: 9),
        buyer: const BuyerInfo(name: 'Leela Shah', companyName: 'Urban Basket'),
        matchScore: 31,
      ),
    ]);
    _board.add(
      Requirement(
        id: invitedId,
        title: 'Drone facade cleaning — four towers',
        kind: RfqKind.enquiry,
        status: RfqStatus.published,
        visibility: RfqVisibility.targeted,
        description: 'Facade cleaning of four 22-storey towers by drone, twice a year.',
        category: 'FACILITY_MANAGEMENT',
        subcategory: 'FACADE_CLEANING',
        facilityType: 'Corporate Offices',
        locations: const ['Bengaluru'],
        city: 'Bengaluru',
        country: 'India',
        dueDate: _days(12),
        createdAt: _days(-1, hour: 4),
        buyer: alpha,
        matchScore: 75,
        matched: true,
        inviteStatus: InviteStatus.invited,
        invitedAt: _days(-1, hour: 4),
      ),
    );
    _linked[guardingId] = Requirement(
      id: guardingId,
      title: 'Manned guarding: Alpha Tech Park, Mumbai',
      kind: RfqKind.rfq,
      status: RfqStatus.published,
      stage: RfqStage.quotation,
      scope: '24 guards across three shifts, a control room and quarterly audits.',
      category: 'SECURITY',
      subcategory: 'PHYSICAL_SECURITY',
      facilityType: 'IT & ITES',
      locations: const ['Mumbai'],
      city: 'Mumbai',
      country: 'India',
      budget: 4200000,
      preQualEndDate: _days(-6),
      dueDate: _days(12),
      quoteCount: 1,
      createdAt: _days(-9, hour: 6),
      buyer: alpha,
      matchScore: 70,
      matched: true,
      );
    _myBids.addAll([
      MyBid(
        id: 'demo-mybid-1',
        rfqId: 'demo-board-cafeteria',
        status: BidStatus.shortlisted,
        amount: 420000,
        leadTimeDays: 5,
        message: 'Cafeteria deep cleaning every Sunday, our own chemicals.',
        createdAt: _days(-3, hour: 6),
        requirement: Requirement(
          id: 'demo-board-cafeteria',
          title: 'Corporate Offices — Cafeteria deep cleaning',
          kind: RfqKind.enquiry,
          status: RfqStatus.published,
          city: 'Pune',
          dueDate: _days(4),
          quoteCount: 3,
          createdAt: _days(-6, hour: 6),
          buyer: const BuyerInfo(name: 'Ola Owner', companyName: 'Owner Buyers'),
        ),
      ),
      MyBid(
        id: 'demo-mybid-2',
        rfqId: 'demo-board-lifts',
        status: BidStatus.awarded,
        isAwarded: true,
        amount: 860000,
        leadTimeDays: 21,
        createdAt: _days(-20, hour: 6),
        poNumber: 'PO-MH3K9Z',
        requirement: Requirement(
          id: 'demo-board-lifts',
          title: 'Lift modernisation — two passenger lifts',
          kind: RfqKind.rfq,
          status: RfqStatus.awarded,
          city: 'Mumbai',
          createdAt: _days(-30, hour: 6),
          buyer: zenith,
        ),
      ),
    ]);

    _alerts.addAll([
      RfqAlert(
        id: 'demo-alert-1',
        title: 'New bid on "Corporate Security — Biometric systems, CCTV & Manpower"',
        body: 'BlueDot quoted ₹11,40,000 with a 10-day lead time.',
        type: 'bid_received',
        link: '/manage/requirements/$securityId?bid=demo-bid-bluedot',
        createdAt: _days(-1, hour: 4),
      ),
      RfqAlert(
        id: 'demo-alert-2',
        title: 'SafeHome sent a pre-qualification response',
        body: 'Bharat Facilities — Integrated Facility Management RFQ',
        type: 'prequal_submitted',
        link: '/manage/requirements/$ifmId?section=prequal',
        createdAt: _days(-1, hour: 7),
      ),
      RfqAlert(
        id: 'demo-alert-3',
        title: 'You were invited to quote',
        body: 'Drone facade cleaning — four towers',
        type: 'rfq_invite',
        link: '/manage/bids/$invitedId',
        readAt: _days(-1, hour: 8),
        createdAt: _days(-1, hour: 4),
        companyName: 'Bharat Facilities',
      ),
      RfqAlert(
        id: 'demo-alert-4',
        title: 'A new enquiry matches your services',
        body: 'Annual HVAC AMC — Alpha Tech Park, Hyderabad',
        type: 'enquiry_match',
        link: '/manage/bids/$boardId',
        readAt: _days(-2, hour: 8),
        createdAt: _days(-2, hour: 6),
        companyName: 'Bharat Facilities',
      ),
    ]);
  }

  /// Puts a requirement of the buyer's at a stage (a test of what each stage offers).
  void setRfqStage(String id, RfqStage stage) => _rfqs[id] = _rfqs[id]!.copyWith(stage: stage);

  /// Adds a bid to one of the buyer's requirements (a test of an RFQ's quote stage, which no seeded RFQ has reached).
  void addBidFor(String rfqId, Bid bid) => _bids[rfqId] = [...?_bids[rfqId], bid];

  /// Moves a requirement on the board to another status (a test of a requirement that has closed since it was listed).
  void setBoardStatus(String id, RfqStatus status) {
    final i = _board.indexWhere((r) => r.id == id);
    if (i >= 0) _board[i] = _board[i].copyWith(status: status);
  }

  /// Requirements a supplier can open (from a notification, from My Bids) that are not on the open board's lists.
  final Map<String, Requirement> _linked = {};

  Never _refuse(String message, [int status = 400]) => throw ApiError(message, statusCode: status);

  Requirement _rfq(String id) =>
      _rfqs[id] ??
      _linked[id] ??
      _board.firstWhere((r) => r.id == id, orElse: () => _refuse('Requirement not found', 404));

  Future<T> _later<T>(T value) => Future.value(value);

  // ---- Who is asking ------------------------------------------------------------

  @override
  Future<Poster> me() => _later(poster);

  // ---- The buyer's requirements ---------------------------------------------------

  bool _inView(Requirement r, MyView v) => switch (v) {
    MyView.all => true,
    MyView.live => r.status == RfqStatus.published,
    MyView.draft => r.status == RfqStatus.draft,
    MyView.awarded => r.status == RfqStatus.awarded,
    MyView.ended => r.status == RfqStatus.closed || r.status == RfqStatus.cancelled,
    MyView.attention =>
      r.status == RfqStatus.published &&
          ((r.responses?.bidsPending ?? 0) > 0 || (r.responses?.prequalPending ?? 0) > 0),
    MyView.closing =>
      r.status == RfqStatus.published &&
          r.currentDeadline != null &&
          r.currentDeadline!.isAfter(now) &&
          r.currentDeadline!.difference(now).inDays < 7,
  };

  Requirement _withCounts(Requirement r) {
    final bids = _bids[r.id] ?? const [];
    final responses = _responses[r.id] ?? const [];
    return r.copyWith(
      responses: ResponseCounts(
        bids: bids.length,
        bidsPending: bids.where((b) => b.status == BidStatus.pending).length,
        prequal: responses.length,
        prequalPending: responses.where((p) => p.status == PreQualStatus.pending).length,
        invites: (_invites[r.id] ?? const []).length,
      ),
    );
  }

  @override
  Future<RequirementsSummary> summary() {
    final mine = _rfqs.values.map(_withCounts).toList();
    final actions = <ActionItem>[];
    for (final r in mine.where((r) => r.live)) {
      final c = r.responses!;
      if (c.prequalPending > 0) {
        actions.add(
          ActionItem(kind: 'SCREEN', rfqId: r.id, title: r.title, rfqKind: r.kind, count: c.prequalPending, deadline: r.preQualEndDate),
        );
      } else if (c.bidsPending > 0) {
        actions.add(ActionItem(kind: 'BIDS', rfqId: r.id, title: r.title, rfqKind: r.kind, count: c.bidsPending, deadline: r.dueDate));
      }
    }
    return _later(
      RequirementsSummary(
        views: {for (final v in MyView.values) v: mine.where((r) => _inView(r, v)).length},
        pendingResponses: mine.fold(0, (n, r) => n + (r.live ? r.responses!.bidsPending + r.responses!.prequalPending : 0)),
        enquiries: mine.where((r) => r.isEnquiry).length,
        rfqs: mine.where((r) => !r.isEnquiry).length,
        actionItems: actions,
        actionCount: actions.length,
      ),
    );
  }

  @override
  Future<RequirementPage> mine({
    MyView view = MyView.all,
    String search = '',
    RfqKind? kind,
    MySort sort = MySort.updated,
    int page = 1,
  }) {
    final q = search.trim().toLowerCase();
    final rows = _rfqs.values
        .map(_withCounts)
        .where((r) => _inView(r, view))
        .where((r) => kind == null || r.kind == kind)
        .where((r) => q.isEmpty || r.title.toLowerCase().contains(q) || (r.text ?? '').toLowerCase().contains(q))
        .toList();
    int byDate(DateTime? a, DateTime? b) => (b ?? DateTime(0)).compareTo(a ?? DateTime(0));
    rows.sort(
      (a, b) => switch (sort) {
        MySort.updated => byDate(a.updatedAt, b.updatedAt),
        MySort.newest => byDate(a.createdAt, b.createdAt),
        MySort.title => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        MySort.closing => (a.dueDate ?? DateTime(9999)).compareTo(b.dueDate ?? DateTime(9999)),
      },
    );
    return _later(RequirementPage(rows: rows, total: rows.length, hasMore: false));
  }

  @override
  Future<Requirement> requirement(String id) async => _withCounts(_rfq(id));

  @override
  Future<PostResult> create(Map<String, dynamic> body) async {
    final id = 'demo-new-${++_ids}';
    final vendorIds = asStrings(body['vendorIds']);
    final status = RfqStatus.parse(body['status'] ?? (vendorIds.isEmpty ? 'DRAFT' : 'PUBLISHED'));
    final kind = RfqKind.parse(body['kind'] ?? (vendorIds.isEmpty ? 'RFQ' : 'ENQUIRY'));
    final json = <String, dynamic>{
      ...body,
      'id': id,
      'kind': kind.wire,
      'status': status.wire,
      'visibility': vendorIds.isEmpty ? (body['visibility'] ?? 'PUBLIC') : 'TARGETED',
      'stage': kind == RfqKind.rfq && status == RfqStatus.published ? 'PREQUALIFICATION' : null,
      'buyerId': bharatId,
      'companyId': poster.companyId,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };
    _rfqs[id] = Requirement.fromJson(json);
    _invites[id] = [
      for (final v in vendorIds)
        SupplierInvite(
          supplier: [blueDot, innoWork, secureTech, greenGuard, safeHome, vikasha].firstWhere(
            (s) => s.vendorId == v,
            orElse: () => SupplierRef(vendorId: v, name: 'Supplier'),
          ),
          status: InviteStatus.invited,
          createdAt: now,
        ),
    ];
    return PostResult(id: id, kind: kind, status: status, alertedNow: vendorIds.isEmpty ? 6 : vendorIds.length, alertedLater: 0);
  }

  @override
  Future<void> update(String id, Map<String, dynamic> patch) async {
    final r = _rfq(id);
    final merged = <String, dynamic>{..._toJson(r), ...patch, 'updatedAt': now.toIso8601String()};
    _rfqs[id] = Requirement.fromJson(merged);
  }

  @override
  Future<void> act(String id, RfqAction action) async {
    final r = _rfq(id);
    final to = switch (action) {
      RfqAction.publish => RfqStatus.published,
      RfqAction.close => RfqStatus.closed,
      RfqAction.cancel => RfqStatus.cancelled,
    };
    final allowed = switch (r.status) {
      RfqStatus.draft => {RfqStatus.published, RfqStatus.cancelled},
      RfqStatus.published => {RfqStatus.closed, RfqStatus.cancelled},
      RfqStatus.awarded => {RfqStatus.closed},
      _ => <RfqStatus>{},
    };
    if (!allowed.contains(to)) _refuse('Cannot move a requirement from ${r.status.wire} to ${to.wire}');
    _rfqs[id] = r.copyWith(
      status: to,
      stage: to == RfqStatus.published && r.kind == RfqKind.rfq && r.stage == null ? RfqStage.prequalification : null,
    );
  }

  @override
  Future<void> deleteDraft(String id) async {
    if (_rfq(id).status != RfqStatus.draft) _refuse('Only a draft can be deleted');
    _rfqs.remove(id);
  }

  @override
  Future<void> setStage(String id, RfqStage stage) async {
    final r = _rfq(id);
    if (r.stage?.next != stage && stage != r.stage) _refuse('Cannot move the RFQ to ${stage.label}');
    _rfqs[id] = r.copyWith(stage: stage);
  }

  // ---- Responses, for the owner ---------------------------------------------------

  @override
  Future<List<Bid>> bids(String rfqId) async => List.of(_bids[rfqId] ?? const []);

  @override
  Future<void> triageBid(String rfqId, String bidId, BidStatus status) async {
    final list = _bids[rfqId] ?? const [];
    final bid = list.firstWhere((b) => b.id == bidId, orElse: () => _refuse('Bid not found', 404));
    if (bid.isAwarded) _refuse('An awarded bid cannot change status');
    _bids[rfqId] = [for (final b in list) b.id == bidId ? b.withStatus(status) : b];
  }

  @override
  Future<String?> award(String rfqId, String bidId) async {
    final r = _rfq(rfqId);
    if (!r.live && !r.expiredEnquiry) _refuse('Only a published requirement that is still open can be awarded');
    final list = _bids[rfqId] ?? const [];
    final bid = list.firstWhere((b) => b.id == bidId, orElse: () => _refuse('Bid not found', 404));
    if (!r.isEnquiry && bid.amount == null) _refuse('Only a priced quote can be awarded');
    _bids[rfqId] = [
      for (final b in list) b.id == bidId ? b.withStatus(BidStatus.awarded) : b.withStatus(BidStatus.rejected),
    ];
    _rfqs[rfqId] = r.copyWith(status: RfqStatus.awarded, stage: r.stage == null ? null : RfqStage.completed);
    return r.isEnquiry ? null : 'PO-DEMO${++_ids}';
  }

  @override
  Future<List<PreQualResponse>> responses(String rfqId) async => List.of(_responses[rfqId] ?? const []);

  @override
  Future<void> screen(String rfqId, String vendorId, PreQualStatus status) async {
    _responses[rfqId] = [
      for (final p in _responses[rfqId] ?? const <PreQualResponse>[])
        p.supplier.vendorId == vendorId ? p.copyWith(status: status) : p,
    ];
  }

  @override
  Future<void> shortlist(String rfqId, List<String> vendorIds) async {
    final r = _rfq(rfqId);
    if (r.stage != RfqStage.shortlisting) _refuse('Move the RFQ to the shortlisting stage first');
    final list = _responses[rfqId] ?? const <PreQualResponse>[];
    if (list.any((p) => vendorIds.contains(p.supplier.vendorId) && p.status != PreQualStatus.qualified)) {
      _refuse('Only qualified suppliers can be shortlisted');
    }
    _responses[rfqId] = [
      for (final p in list) vendorIds.contains(p.supplier.vendorId) ? p.copyWith(shortlisted: true) : p,
    ];
  }

  @override
  Future<List<SupplierInvite>> invites(String rfqId) async => List.of(_invites[rfqId] ?? const []);

  @override
  Future<List<SupplierHit>> suggested(String rfqId) async {
    final invited = {for (final i in _invites[rfqId] ?? const <SupplierInvite>[]) i.supplier.vendorId};
    return [
      for (final (i, s) in [greenGuard, secureTech, innoWork, safeHome, vikasha, blueDot].indexed)
        if (!invited.contains(s.vendorId)) SupplierHit(supplier: s, matchScore: 80 - i * 7),
    ];
  }

  @override
  Future<List<SupplierHit>> findSuppliers(String query) async {
    final q = query.trim().toLowerCase();
    return [
      for (final s in [blueDot, innoWork, secureTech, greenGuard, safeHome, vikasha])
        if (q.isEmpty || s.name.toLowerCase().contains(q) || (s.headline ?? '').toLowerCase().contains(q))
          SupplierHit(supplier: s),
    ];
  }

  @override
  Future<List<SupplierInvite>> invite(String rfqId, List<String> vendorIds) async {
    if (vendorIds.isEmpty) _refuse('Select at least one vendor');
    final hits = await findSuppliers('');
    final list = _invites[rfqId] ?? <SupplierInvite>[];
    for (final id in vendorIds) {
      if (list.any((i) => i.supplier.vendorId == id)) continue;
      final s = hits.map((h) => h.supplier).firstWhere((s) => s.vendorId == id, orElse: () => SupplierRef(vendorId: id, name: 'Supplier'));
      list.add(SupplierInvite(supplier: s, status: InviteStatus.invited, createdAt: now));
    }
    _invites[rfqId] = list;
    return List.of(list);
  }

  @override
  Future<List<SupplierThread>> threads(String rfqId) async => [
    if (rfqId == securityId) ...[
      SupplierThread(
        conversationId: 'demo-thread-bluedot',
        companyId: blueDot.companyId!,
        companyName: blueDot.name,
        lastMessage: 'Happy to walk the floors with your admin team this week.',
        lastAt: _days(-1, hour: 5),
        unread: 1,
      ),
      SupplierThread(
        conversationId: 'demo-thread-innowork',
        companyId: innoWork.companyId!,
        companyName: innoWork.name,
        lastMessage: 'Sharing our PSARA licence and references.',
        lastAt: _days(-2, hour: 10),
      ),
    ],
  ];

  @override
  Future<String> openConversation(String rfqId, {String? supplierCompanyId}) async =>
      'demo-thread-${supplierCompanyId ?? 'buyer'}-$rfqId';

  // ---- The supplier's side ----------------------------------------------------------

  @override
  Future<VendorAccess> access() async => vendorAccess;

  @override
  Future<List<Requirement>> openBoard(BoardQuery query, {int page = 1, int limit = 20}) async {
    if (page > 1) return const [];
    final q = query.search.trim().toLowerCase();
    final bid = {for (final b in _myBids) b.rfqId};
    final rows = _board
        .where((r) => r.visibility == RfqVisibility.public)
        .where((r) => !query.matchedOnly || r.matched)
        .where((r) => q.isEmpty || r.title.toLowerCase().contains(q) || (r.city ?? '').toLowerCase().contains(q))
        .where((r) => query.city == null || r.places.any((p) => p.toLowerCase().contains(query.city!.toLowerCase())))
        .where((r) => !query.verifiedBuyer || (r.buyer?.verified ?? false))
        .where((r) => query.minBudget == null || (r.budget ?? -1) >= query.minBudget!)
        .where((r) => query.maxBudget == null || (r.budget != null && r.budget! <= query.maxBudget!))
        .where(
          (r) =>
              query.closingInDays == null ||
              (r.dueDate != null && r.dueDate!.isAfter(now) && r.dueDate!.difference(now).inDays <= query.closingInDays!),
        )
        .map((r) => r.copyWith(hasBid: bid.contains(r.id)))
        .toList();
    if (query.sort == BoardSort.match) rows.sort((a, b) => (b.matchScore ?? 0).compareTo(a.matchScore ?? 0));
    if (query.sort == BoardSort.budget) rows.sort((a, b) => (b.budget ?? -1).compareTo(a.budget ?? -1));
    if (query.sort == BoardSort.closing) {
      rows.sort((a, b) => (a.dueDate ?? DateTime(9999)).compareTo(b.dueDate ?? DateTime(9999)));
    }
    if (query.sort == BoardSort.newest) {
      rows.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    }
    return rows;
  }

  @override
  Future<List<Requirement>> invited() async => [
    for (final r in _board)
      if (r.inviteStatus != null)
        r.copyWith(
          hasBid: _myBids.any((b) => b.rfqId == r.id),
          inviteStatus: _declined.contains(r.id)
              ? InviteStatus.declined
              : (_myBids.any((b) => b.rfqId == r.id) ? InviteStatus.responded : r.inviteStatus!),
        ),
  ];

  @override
  Future<List<MyBid>> myBids() async => List.of(_myBids);

  @override
  Future<OpportunityContext> opportunity(String rfqId) async {
    final r = _rfq(rfqId);
    final mine = _myBids.where((b) => b.rfqId == rfqId).firstOrNull;
    return OpportunityContext(
      buyer: r.buyer,
      matchScore: r.matchScore,
      matched: r.matched,
      reasons: r.matchReasons,
      myBid: mine,
    );
  }

  @override
  Future<MyBid> placeBid(String rfqId, Map<String, dynamic> body) async {
    final r = _rfq(rfqId);
    if (!r.live) _refuse('This requirement is not open for bids');
    if (_myBids.any((b) => b.rfqId == rfqId)) _refuse('You have already bid on this requirement');
    if (!r.isEnquiry && body['totalAmount'] == null) _refuse('A quote needs your price');
    final bid = MyBid(
      id: 'demo-mybid-${++_ids}',
      rfqId: rfqId,
      status: BidStatus.pending,
      amount: asDouble(body['totalAmount']),
      leadTimeDays: asInt(body['leadTimeDays']),
      message: asText(body['message']),
      createdAt: now,
      files: [
        for (final (i, f) in asMaps(body['attachments']).indexed)
          RfqFile.fromJson({'id': 'demo-sent-file-$_ids-$i', ...f}),
      ],
      requirement: r,
    );
    _myBids.insert(0, bid);
    return bid;
  }

  @override
  bool get supportsBidChanges => true;

  @override
  Future<MyBid> updateBid(String rfqId, Map<String, dynamic> body) async {
    final i = _myBids.indexWhere((b) => b.rfqId == rfqId);
    if (i < 0) _refuse('Bid not found', 404);
    final r = _rfq(rfqId);
    final old = _myBids[i];
    if (!r.live) _refuse('This requirement is not open for bids');
    if (old.isAwarded || old.status == BidStatus.rejected) _refuse('An awarded bid cannot change status');
    final amount = body.containsKey('totalAmount') ? asDouble(body['totalAmount']) : old.amount;
    if (!r.isEnquiry && amount == null) _refuse('A quote needs your price');
    final changed = MyBid(
      id: old.id,
      rfqId: rfqId,
      status: old.status,
      amount: amount,
      leadTimeDays: body.containsKey('leadTimeDays') ? asInt(body['leadTimeDays']) : old.leadTimeDays,
      message: body.containsKey('message') ? asText(body['message']) : old.message,
      createdAt: old.createdAt,
      files: body['attachments'] is List
          ? [for (final f in asMaps(body['attachments'])) RfqFile.fromJson(f)]
          : old.files,
      requirement: old.requirement,
    );
    _myBids[i] = changed;
    return changed;
  }

  @override
  Future<void> withdrawBid(String rfqId) async {
    final i = _myBids.indexWhere((b) => b.rfqId == rfqId);
    if (i < 0) _refuse('Bid not found', 404);
    if (_myBids[i].isAwarded) _refuse('An awarded bid cannot change status');
    _myBids.removeAt(i);
  }

  @override
  Future<void> declineInvite(String rfqId) async {
    if (_myBids.any((b) => b.rfqId == rfqId)) _refuse('You have already responded to this invitation');
    _declined.add(rfqId);
  }

  @override
  Future<void> submitPreQual(String rfqId, Map<String, dynamic> body) async {
    final r = _rfq(rfqId);
    if (r.stage != RfqStage.prequalification) _refuse('Pre-qualification is not open for this RFQ');
  }

  @override
  Future<BuyerContact> revealContact(String rfqId) async {
    if (!_myBids.any((b) => b.rfqId == rfqId)) _refuse('Place a bid before contacting the buyer', 403);
    final r = _rfq(rfqId);
    return BuyerContact(name: r.buyer?.name ?? 'The buyer', companyName: r.buyer?.companyName, email: 'procurement@example.com', phone: '+91 80 4000 1234');
  }

  @override
  Future<void> startSelling(String companyId) async {
    vendorAccess = const VendorAccess(vendorId: 'demo-vendor-new', verified: true, canBid: true, canRespondToEnquiry: true);
  }

  // ---- Alerts and counts --------------------------------------------------------------

  @override
  Future<List<RfqAlert>> alerts({bool unreadOnly = false}) async => [
    for (final a in _alerts)
      if (!unreadOnly || a.unread) a,
  ];

  @override
  Future<void> markAlertRead(String id) async {
    final i = _alerts.indexWhere((a) => a.id == id);
    if (i < 0) _refuse('Notification not found', 404);
    _alerts[i] = _alerts[i].read(now);
  }

  @override
  Future<void> markSeen(AlertSide side, String rfqId) async {
    for (final (i, a) in _alerts.indexed) {
      if (a.unread && a.rfqId == rfqId && a.side == side) _alerts[i] = a.read(now);
    }
  }

  @override
  Future<int> unreadNotifications() async => _alerts.where((a) => a.unread).length + 1;

  @override
  Future<RfqCounts> counts() async =>
      RfqCounts(myRfqs: (await summary()).open, newAlerts: _alerts.where((a) => a.unread).length);

  // ---- The composer's lookups ---------------------------------------------------------

  static const _tree = [
    CategoryNode(
      id: 'cat-security',
      key: 'SECURITY',
      name: 'Security Services',
      children: [
        CategoryNode(id: 'cat-physical', key: 'PHYSICAL_SECURITY', name: 'Physical Security'),
        CategoryNode(id: 'cat-electronic', key: 'ELECTRONIC_SECURITY', name: 'Electronic Security'),
      ],
    ),
    CategoryNode(
      id: 'cat-ifm',
      key: 'FACILITY_MANAGEMENT',
      name: 'Integrated Facility Management',
      children: [
        CategoryNode(id: 'cat-housekeeping', key: 'HOUSEKEEPING', name: 'Housekeeping'),
        CategoryNode(id: 'cat-facade', key: 'FACADE_CLEANING', name: 'Facade Cleaning'),
      ],
    ),
    CategoryNode(
      id: 'cat-mep',
      key: 'MEP',
      name: 'Engineering Services',
      children: [CategoryNode(id: 'cat-hvac', key: 'HVAC', name: 'HVAC')],
    ),
  ];

  @override
  Future<List<CategoryNode>> categories() async => _tree;

  @override
  Future<List<CategoryNode>> specialisations(String parentId) async => parentId == 'cat-physical'
      ? const [
          CategoryNode(id: 'cat-guarding', key: 'MANNED_GUARDING', name: 'Manned Guarding'),
          CategoryNode(id: 'cat-access', key: 'ACCESS_CONTROL', name: 'Access Control'),
        ]
      : const [];

  static const _places = [
    RfqPlace(label: 'Bengaluru', city: 'Bengaluru', state: 'Karnataka', country: 'India', countryCode: 'IN'),
    RfqPlace(label: 'Mumbai', city: 'Mumbai', state: 'Maharashtra', country: 'India', countryCode: 'IN'),
    RfqPlace(label: 'Pune', city: 'Pune', state: 'Maharashtra', country: 'India', countryCode: 'IN'),
    RfqPlace(label: 'Chennai', city: 'Chennai', state: 'Tamil Nadu', country: 'India', countryCode: 'IN'),
    RfqPlace(label: 'Hyderabad', city: 'Hyderabad', state: 'Telangana', country: 'India', countryCode: 'IN'),
    RfqPlace(label: 'Dubai, United Arab Emirates', city: 'Dubai', country: 'United Arab Emirates', countryCode: 'AE'),
  ];

  @override
  Future<List<RfqPlace>> searchPlaces(String query) async {
    final q = query.trim().toLowerCase();
    if (q.length < 2) return const [];
    return [
      for (final p in _places)
        if (p.label.toLowerCase().contains(q)) p,
    ];
  }

  /// What was uploaded, by name, so a test can see which files a post carried.
  final uploads = <RfqFile>[];

  /// The purpose each upload was sent with (`rfq-attachment` for a requirement, `bid-attachment` for a reply).
  final uploadPurposes = <String>[];

  @override
  Future<RfqFile> uploadFile(PickedRfqFile file, {required String purpose}) async {
    final stored = RfqFile(
      id: '',
      title: titleFromFileName(file.name),
      url: '/uploads/demo-${++_ids}-${file.name}',
      name: file.name,
      mimeType: file.mimeType,
      size: file.size,
    );
    uploads.add(stored);
    uploadPurposes.add(purpose);
    return stored;
  }

  @override
  Future<String> saveFile(RfqFile file) async => '/tmp/demo-${file.name ?? file.title}';

  @override
  String? categoryName(String key) => _names[key];

  @override
  Uri sitePage(String path) => AppConfig.sitePage(path);

  Map<String, dynamic> _toJson(Requirement r) => {
    'id': r.id,
    'title': r.title,
    'kind': r.kind.wire,
    'status': r.status.wire,
    'description': r.description,
    'stage': r.stage?.wire,
    'visibility': r.visibility.wire,
    'buyerId': r.buyerId,
    'companyId': r.companyId,
    'category': r.category,
    'subcategory': r.subcategory,
    'service': r.service,
    'facilityType': r.facilityType,
    'locations': r.locations,
    'city': r.city,
    'state': r.state,
    'country': r.country,
    'scope': r.scope,
    'budget': r.budget,
    'dueDate': r.dueDate?.toIso8601String(),
    'preQualEndDate': r.preQualEndDate?.toIso8601String(),
    'minYearsInBusiness': r.criteria.minYearsInBusiness,
    'minAnnualTurnover': r.criteria.minAnnualTurnover,
    'minLast3YrTurnover': r.criteria.minLast3YrTurnover,
    'minEmployees': r.criteria.minEmployees,
    'requiredPresence': r.criteria.requiredPresence?.wire,
    'statutoryCompliance': r.criteria.statutoryCompliance,
    'contactName': r.contactName,
    'contactEmail': r.contactEmail,
    'contactPhone': r.contactPhone,
    'companyName': r.companyName,
    'items': [for (final i in r.items) i.toJson()],
    'attachments': [
      for (final f in r.files) {'id': f.id, 'title': f.title, 'url': f.url, 'name': f.name, 'mimeType': f.mimeType},
    ],
    'createdAt': r.createdAt?.toIso8601String(),
    'publishedAt': r.publishedAt?.toIso8601String(),
  };
}
