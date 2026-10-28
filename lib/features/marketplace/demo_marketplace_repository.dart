import 'dart:ui' show Color;

import '../../core/api/api_error.dart';
import '../../core/config.dart';
import 'catalog_models.dart';
import 'marketplace_filters.dart';
import 'marketplace_models.dart';
import 'marketplace_repository.dart';
import 'quote_models.dart';

const _art = 'assets/images/demo/marketplace';

/// The Marketplace as the designs draw it, with no API: the supplier cards
/// (BlueDot, InnoWork, GreenGuard...), Vikasha Aero Tech's profile, its six
/// services, four compliances and two audited proofs. For design review
/// (`--dart-define=FEED_SOURCE=demo`) and the golden tests.
///
/// The design's reviewer names, roles and quotes live here only: the API
/// publishes ratings anonymously, so the live screen says "Verified buyer".
class DemoMarketplaceRepository implements MarketplaceRepository {
  DemoMarketplaceRepository({List<Supplier>? cards, this.total = 184}) : _cards = cards ?? phoneCards;

  final List<Supplier> _cards;

  /// What the header counts: "Showing 10 of 180+".
  final int total;

  final Set<String> _saved = {};

  /// A first page of the phone design: ten cards, five rows of two.
  static final List<Supplier> phoneCards = [for (final (i, c) in _phoneOrder.indexed) _card(c, i)];

  /// The tablet design's cards: the same nine in turn, three to a row.
  static List<Supplier> tabletCards({int count = 27}) => [
    for (var i = 0; i < count; i++) _card(_tabletOrder[i % _tabletOrder.length], i),
  ];

  static const _phoneOrder = [
    _Card.blueDot,
    _Card.innoWork,
    _Card.innoWork,
    _Card.greenGuard,
    _Card.secureTech,
    _Card.innoWorkDark,
    _Card.safeHome,
    _Card.innoWork,
    _Card.innoWork,
    _Card.innoWork,
  ];

  static const _tabletOrder = [
    _Card.blueDot,
    _Card.innoWork,
    _Card.innoWork,
    _Card.greenGuard,
    _Card.secureTech,
    _Card.innoWorkDark,
    _Card.safeHome,
    _Card.innoWork,
    _Card.innoWork,
  ];

  static Supplier _card(_Card c, int index) => Supplier(
    id: 'demo-card-$index',
    companyId: 'demo-company-$index',
    name: c.name,
    lockupAsset: '$_art/${c.lockup}.png',
    brandColor: c.color,
    headline: c.title,
    about: c.body,
    rating: c.rating,
    ratingCount: c.reviews,
    level: SupplierLevel.verified,
  );

  // ---- The directory ------------------------------------------------------------------

  @override
  Future<SupplierPage> suppliers(MarketplaceFilters filters, {int page = 1}) async {
    final narrowed = filters.search.isNotEmpty || filters.minRating != null;
    // The designed cards are the first page; "Load more suppliers" brings the
    // profile the other designs draw.
    var rows = narrowed || page == 1 ? [..._cards, vikasha] : [vikasha];
    final q = filters.search.toLowerCase();
    if (q.isNotEmpty) {
      rows = [
        for (final s in rows)
          if ('${s.name} ${s.headline} ${s.about}'.toLowerCase().contains(q)) s,
      ];
    }
    final min = filters.minRating;
    if (min != null) {
      rows = [
        for (final s in rows)
          if (s.rating >= min) s,
      ];
    }
    if (narrowed) return SupplierPage(suppliers: rows, total: rows.length, page: 1, hasMore: false);
    final first = page == 1;
    return SupplierPage(suppliers: first ? _cards : rows, total: total, page: page, hasMore: first);
  }

  @override
  Future<SupplierPage> savedSuppliers({int page = 1}) async {
    final rows = [
      for (final s in [..._cards, vikasha])
        if (_saved.contains(s.id)) s,
    ];
    return SupplierPage(suppliers: rows, total: rows.length, page: 1, hasMore: false);
  }

  @override
  Future<Set<String>> savedIds() async => {..._saved};

  @override
  Future<void> setSaved(String vendorId, bool saved) async {
    saved ? _saved.add(vendorId) : _saved.remove(vendorId);
  }

  @override
  Future<List<String>> cities() async => const ['Bengaluru', 'Chennai', 'Hyderabad', 'Mumbai', 'Pune'];

  @override
  Future<List<CategoryNode>> categories() async => const [
    CategoryNode(
      key: 'SECURITY',
      name: 'Security Services',
      count: 62,
      children: [
        CategoryNode(key: 'PHYSICAL_SECURITY', name: 'Physical Security', count: 41),
        CategoryNode(key: 'ELECTRONIC_SECURITY', name: 'Electronic Security', count: 33),
      ],
    ),
    CategoryNode(
      key: 'FACILITY_MANAGEMENT',
      name: 'Integrated Facility Management',
      count: 118,
      children: [
        CategoryNode(key: 'HOUSEKEEPING', name: 'Housekeeping', count: 54),
        CategoryNode(key: 'HVAC', name: 'HVAC', count: 37),
      ],
    ),
  ];

  @override
  Future<MarketplaceCounts> counts() async => const MarketplaceCounts(myRfqs: 3, newAlerts: 2);

  @override
  Future<int> unreadNotifications() async => 1;

  @override
  Future<SearchExtras> searchExtras(String query) async => SearchExtras.none;

  // ---- One supplier ---------------------------------------------------------------------

  @override
  Future<Supplier> supplier(String id) async {
    if (id == vikasha.id) return vikasha;
    final card = [..._cards, vikasha].firstWhere((s) => s.id == id, orElse: () => vikasha);
    // The ten cards open the same design profile under their own name.
    return Supplier(
      id: card.id,
      companyId: card.companyId,
      name: card.name,
      brandColor: card.brandColor,
      lockupAsset: card.lockupAsset,
      headline: vikasha.headline,
      about: vikasha.about,
      rating: card.rating,
      ratingCount: card.ratingCount,
      level: SupplierLevel.elite,
      legalStructure: vikasha.legalStructure,
      registrationNumber: vikasha.registrationNumber,
      website: vikasha.website,
      hubs: vikasha.hubs,
      reviews: vikasha.reviews,
      detailed: true,
      demoTiles: vikasha.demoTiles,
      demoDispatch: vikasha.demoDispatch,
    );
  }

  @override
  Future<Supplier?> supplierOfCompany(String companyId) async => vikasha;

  @override
  Future<List<Compliance>> compliances(String companyId) async => designCompliances;

  @override
  Future<List<CatalogService>> servicesOf(String companyId) async => designServices;

  @override
  Future<List<CatalogProduct>> productsOf(String companyId) async => const [];

  @override
  Future<String> startConversation(String vendorId, {String? message}) async => 'demo-conversation';

  @override
  Future<void> rate(String vendorId, {required int score, String? comment}) async {}

  // ---- The catalogue ---------------------------------------------------------------------

  @override
  Future<CatalogProduct> product(String id) async => throw ApiError('Product not found.', statusCode: 404);

  @override
  Future<CatalogService> service(String id) async {
    for (final s in designServices) {
      if (s.id == id) return s;
    }
    throw ApiError('Service not found.', statusCode: 404);
  }

  @override
  Future<CatalogPage<CatalogProduct>> products({
    String? categorySlug,
    String? companyId,
    String search = '',
    int page = 1,
  }) async => const CatalogPage(items: [], total: 0, page: 1, hasMore: false);

  @override
  Future<CatalogPage<CatalogService>> services({
    String? category,
    String? companyId,
    String search = '',
    int page = 1,
  }) async => CatalogPage(items: designServices, total: designServices.length, page: 1, hasMore: false);

  @override
  Future<bool> hasPhone() async => true;

  @override
  Future<String?> myCompanyId() async => null;

  @override
  Future<QuoteSent> requestQuote(QuoteRequest request) async => QuoteSent(id: 'demo-rfq', title: request.title);

  @override
  Uri sitePage(String path) => AppConfig.sitePage(path);

  // ---- Vikasha Aero Tech, the profile the designs draw -------------------------------------------

  static const vikasha = Supplier(
    id: 'demo-vikasha',
    companyId: 'demo-vikasha-company',
    name: 'Vikasha Aero Tech',
    headline:
        'AI-Guided Robotic High-Rise Maintenance & Drone Facade Engineering Solutions for Tier-1 Commercial Campuses.',
    about:
        'Revolutionizing commercial facility maintenance through DGCA-licensed robotic and drone-based cleaning '
        'solutions, completely eliminating human rigging risk on high-rise glass facades. Our certified pilots and '
        'robotics engineers deliver audited, insured and fully documented service across four operational hubs.',
    rating: 4.9,
    ratingCount: 84,
    level: SupplierLevel.elite,
    legalStructure: 'PRIVATE_LIMITED',
    registrationNumber: 'CIN-U74999KA2019PTC1',
    website: 'https://vikasha.example.in',
    detailed: true,
    hubs: [
      SupplierHub(
        id: 'h1',
        name: 'Bengaluru HQ',
        city: 'Bengaluru',
        state: 'Karnataka',
        phone: '+91 80 4000 1100',
        headOffice: true,
      ),
      SupplierHub(id: 'h2', name: 'Hyderabad Hub', city: 'Hyderabad', state: 'Telangana', phone: '+91 40 4000 1200'),
      SupplierHub(id: 'h3', name: 'Pune Hub', city: 'Pune', state: 'Maharashtra', phone: '+91 20 4000 1300'),
      SupplierHub(id: 'h4', name: 'Chennai Hub', city: 'Chennai', state: 'Tamil Nadu', phone: '+91 44 4000 1400'),
    ],
    reviews: [
      SupplierReview(
        id: 'r1',
        score: 5,
        byline: 'Embassy TechZone (Pune SEZ Campus)',
        role: 'Facilities Director • 14 Towers Project',
        comment: 'Transitioned our 14-tower glass facade cleaning to Vikasha Aero Tech drones..',
      ),
      SupplierReview(
        id: 'r2',
        score: 5,
        byline: 'Bagmane Tech Park (Bengaluru)',
        role: 'Head of Technical Operations',
        comment:
            'Their robotic duct inspection system uncovered and resolved microbial build-ups that manual inspection teams missed completely..',
      ),
    ],
    demoTiles: [
      TrackTile(
        value: '150+',
        caption: 'Projects Executed Across Tech Parks',
        tone: TrackTone.blue,
        glyph: TrackGlyph.check,
      ),
      TrackTile(
        value: '0',
        caption: 'Safety Incidents (Zero Human Rigging Risk)',
        tone: TrackTone.green,
        glyph: TrackGlyph.shield,
      ),
      TrackTile(
        value: '42+',
        caption: 'Commercial Towers Under Active AMCs',
        tone: TrackTone.ink,
        glyph: TrackGlyph.building,
      ),
      TrackTile(
        value: '4 Hubs',
        caption: 'Bengaluru, Hyderabad, Pune & Chennai',
        tone: TrackTone.blue,
        glyph: TrackGlyph.hubs,
      ),
    ],
    demoDispatch: DispatchBand(
      kicker: 'PAN-INDIA FAST DISPATCH',
      title: '4 Operational Tech Hubs with Ready Fleets',
      line: 'BLR • HYD • PNQ • MAA with < 2hr SLA',
    ),
  );

  static const designCompliances = [
    Compliance(
      id: 'c1',
      title: 'DGCA Commercial Drone License',
      category: 'GOVERNMENT',
      number: 'DGCA-KA-2024-UAV-781',
      statusOverride: 'Active',
    ),
    Compliance(
      id: 'c2',
      title: 'ISO 9001:2015 Quality Management',
      category: 'ISO',
      issuer: 'TUV Rheinland',
      statusOverride: 'Certified',
    ),
    Compliance(
      id: 'c3',
      title: 'ISO 45001 Occupational Safety',
      category: 'SAFETY',
      note: 'Zero-Elevation Worker Hazard Compliant',
      statusOverride: 'Certified',
    ),
    Compliance(
      id: 'c4',
      title: 'Escrow & Trade Assurance Policy',
      category: 'OTHER',
      note: '₹10 Crore Comprehensive Aviation Risk Coverage',
      statusOverride: 'Insured',
    ),
  ];

  static const designServices = [
    CatalogService(
      id: 's1',
      companyId: 'demo-vikasha-company',
      name: 'Drone Facade Cleaning',
      description: 'AI-guided dual-rotor precision wash for high-rise glass commercial towers up to 150m.',
      turnaround: 'SLA: 24h Setup • BLR / HYD',
      imageAsset: '$_art/service_drone_facade.png',
      group: 'Facade',
      ctaLabel: 'Get Quote',
    ),
    CatalogService(
      id: 's2',
      companyId: 'demo-vikasha-company',
      name: 'Robotic HVAC Inspection',
      description: 'Remote camera crawler with HEPA extraction, rotary brush modules, and sanitisation.',
      turnaround: 'Video Report Included',
      imageAsset: '$_art/service_hvac_inspection.png',
      group: 'Robotics & MEP',
      ctaLabel: 'Book Inspection',
    ),
    CatalogService(
      id: 's3',
      companyId: 'demo-vikasha-company',
      name: 'High-Rise Cobweb Vacuuming',
      description: 'Cleanrooms, industrial logistics parks & 20m atrium ceiling dust extraction systems.',
      turnaround: 'Night Shifts Available',
      imageAsset: '$_art/service_cobweb.png',
      group: 'Facade',
      ctaLabel: 'Get Quote',
    ),
    CatalogService(
      id: 's4',
      companyId: 'demo-vikasha-company',
      name: 'Specialized Industrial Cleaning',
      description: 'Degreasing, epoxy floor treatment & mechanical plant room deep sanitation drives.',
      turnaround: 'Industrial Grade',
      imageAsset: '$_art/service_industrial_cleaning.png',
      group: 'Hygiene',
      ctaLabel: 'Get Quote',
    ),
    CatalogService(
      id: 's5',
      companyId: 'demo-vikasha-company',
      name: 'Comprehensive HVAC Duct Care',
      description: 'Airflow volume balancing, motorized damper servicing, and IAQ particulate monitoring.',
      turnaround: 'IAQ Certified',
      imageAsset: '$_art/service_duct_care.png',
      group: 'Robotics & MEP',
      ctaLabel: 'Book Service',
    ),
    CatalogService(
      id: 's6',
      companyId: 'demo-vikasha-company',
      name: 'Commercial Pest Barrier',
      description: 'Targeted gel baited and ultrasonic termite barriers for commercial food courts.',
      turnaround: 'Odorless Formula',
      imageAsset: '$_art/service_pest_barrier.png',
      group: 'Hygiene',
      ctaLabel: 'Get Quote',
    ),
  ];
}

/// One of the designed supplier cards.
enum _Card {
  blueDot(
    'BlueDot',
    'lockup_bluedot',
    Color(0xFF1B3F8F),
    'Corporate Security',
    'Biometric systems, CCTV & Manpower',
    4.8,
    124,
  ),
  innoWork(
    'InnoWork',
    'lockup_innowork',
    Color(0xFF0B3FCC),
    'Corporate Security',
    'Biometric systems, CCTV & Manpower',
    4.8,
    124,
  ),
  innoWorkDark(
    'InnoWork',
    'lockup_innowork_dark',
    Color(0xFF111111),
    'Corporate Security',
    'Biometric systems, CCTV & Manpower',
    4.8,
    124,
  ),
  greenGuard(
    'GreenGuard',
    'lockup_greenguard',
    Color(0xFF1B3F8F),
    'Home Security',
    'Alarm system, Surveillance cameras & Monitoring',
    4.5,
    98,
  ),
  secureTech(
    'SecureTech',
    'lockup_securetech',
    Color(0xFF00B67A),
    'Network Security',
    'Firewalls, VPNs & Threat Detection',
    4.7,
    150,
  ),
  safeHome(
    'SafeHome',
    'lockup_safehome',
    Color(0xFF1B3F8F),
    'Residential Security',
    'Smart locks, Home automation & Motion',
    4.6,
    85,
  );

  const _Card(this.name, this.lockup, this.color, this.title, this.body, this.rating, this.reviews);

  final String name;
  final String lockup;
  final Color color;
  final String title;
  final String body;
  final double rating;
  final int reviews;
}
