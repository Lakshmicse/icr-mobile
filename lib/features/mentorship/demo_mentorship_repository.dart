import '../../core/config.dart';
import 'mentorship_format.dart';
import 'mentorship_models.dart';
import 'mentorship_repository.dart';

/// The Mentorship designs' sample content, bundled for design review.
class DemoMentorshipRepository implements MentorshipRepository {
  DemoMentorshipRepository();

  static const _dir = 'assets/images/demo/mentorship';

  static Mentor _mentor(String id, String name, String role, List<String> expertise) => Mentor(
    id: id,
    name: name,
    role: role,
    avatar: FeedPicture.asset('$_dir/avatar_$id.jpg'),
    cover: FeedPicture.asset('$_dir/cover_$id.jpg'),
    expertise: expertise,
    approved: true,
    rating: 4.8,
    ratingCount: 12,
    yearsExperience: 14,
  );

  /// The eight cards of both designs, in their order.
  static final mentors = <Mentor>[
    _mentor('rajesh', 'Rajesh Sharma', 'VP Facility Ops @ Infosys', ['Smart Campuses', 'Smart Campuses', 'BMS']),
    _mentor('rajesh2', 'Rajesh Sharma', 'VP Facility Ops @ Infosys', ['Smart Campuses', 'Smart Campuses', 'BMS']),
    _mentor('lisa', 'Lisa Cheng', 'Director of Sustainability @ Google', [
      'Green Initiatives',
      'Renewable Energy',
      'Design',
    ]),
    _mentor('david', 'David Kim', 'Chief Technology Officer @ Cisco', [
      'Smart Cities',
      'IoT Solutions',
      'Network Optimization',
    ]),
    _mentor('sophia', 'Sophia Patel', 'Head of Innovation @ Microsoft', [
      'Digital Transformation',
      'AI Integration',
      'Cloud Solutions',
    ]),
    _mentor('michael', 'Michael Johnson', 'Product Manager @ Amazon', [
      'E-Commerce',
      'User Experience',
      'Data Analytics',
    ]),
    _mentor('emma', 'Emma Thompson', 'Lead Architect @ Tesla', ['Electric Vehicles', 'Sustainable Engineering', 'FCM']),
    _mentor('james', 'James Rodriguez', 'Operations Manager @ SpaceX', ['Aerospace', 'Launch Operations']),
  ];

  static const categoryList = [
    MentorCategory(label: 'Operations & FM', count: 48),
    MentorCategory(label: 'Sustainability & ESG', count: 31),
    MentorCategory(label: 'Smart Buildings & IoT', count: 19),
    MentorCategory(label: 'Workplace Strategy', count: 12),
    MentorCategory(label: 'Energy Management', count: 9),
  ];

  static const companies = [
    MentorCompany(name: 'Microsoft', mentors: 6, onAccount: true),
    MentorCompany(name: 'Amazon', mentors: 5, onAccount: true),
    MentorCompany(name: 'JLL', mentors: 5, onAccount: true),
    MentorCompany(name: 'CBRE', mentors: 4, onAccount: true),
    MentorCompany(name: 'CBRE', mentors: 4, onAccount: true),
    MentorCompany(name: 'JLL', mentors: 3, onAccount: true),
    MentorCompany(name: 'Google', mentors: 3, onAccount: true),
    MentorCompany(name: 'Infosys', mentors: 2, onAccount: true),
  ];

  static const topics = [
    MentorTopic('Space Optimization', selected: true),
    MentorTopic('Sustainability'),
    MentorTopic('Workplace Safety', tone: TopicTone.red),
    MentorTopic('Budgeting & Costing', tone: TopicTone.blue),
    MentorTopic('Vendor Management', tone: TopicTone.blue),
    MentorTopic('Employee Wellbeing', tone: TopicTone.red),
    MentorTopic('Technology Integration'),
    MentorTopic('Energy Management'),
    MentorTopic('Energy Management'),
  ];

  static const banner = MentorBanner(
    title: 'Become an ICR Mentor & Shape the Next Generation',
    body: 'Join 3,000+ senior leaders guiding emerging facility managers and corporate real estate professionals.',
    cta: 'Apply as Mentor',
    photo: FeedPicture.asset('$_dir/banner_photo.jpg'),
    link: '/become-a-mentor',
  );

  static const cohort = MentorCohort(
    id: 'demo-cohort',
    slug: 'fm-leadership-esg-masterclass',
    name: 'FM Leadership & ESG Masterclass',
    registeredLabel: '32 Leaders Registered',
    avatars: [
      CohortAvatar(initials: 'RK'),
      CohortAvatar(initials: 'AN'),
      CohortAvatar(initials: 'SJ'),
    ],
    link: '/mentorship/programmes',
  );

  static const services = [
    MentorService(
      id: 'demo-diagnostic',
      mentorId: 'rajesh',
      kind: MentorServiceKind.oneOnOne,
      kindLabel: '1:1 Diagnostic Call',
      title: "What's going wrong? Discovery Call",
      blurb: "Stuck in your career trajectory or struggling with enterprise interviews? Let's diagnose the root cause.",
      durationMin: 30,
      pricePaisa: 0,
      cta: 'Book Diagnostic (Free)',
      featured: true,
      glyph: ServiceGlyph.diagnostic,
    ),
    MentorService(
      id: 'demo-session',
      mentorId: 'rajesh',
      kind: MentorServiceKind.oneOnOne,
      title: 'Personal Interview & Leadership Strategy',
      blurb: 'Tailored mock interview frameworks, behavioral STAR storytelling, and executive salary negotiation.',
      durationMin: 45,
      pricePaisa: 149900,
      cta: 'Book Session',
    ),
    MentorService(
      id: 'demo-review',
      mentorId: 'rajesh',
      kind: MentorServiceKind.query,
      title: 'Enterprise Resume & LinkedIn Niche Review',
      blurb: 'Detailed audit of your CV mapped to hiring criteria of JLL, CBRE, and Fortune 500 tech campuses.',
      slaHours: 24,
      pricePaisa: 0,
      cta: 'Request Review',
    ),
  ];

  /// The design's "48 matches".
  static const total = 48;

  final _saved = <String>{};

  List<Mentor> get _withSaves => [for (final m in mentors) m.copyWith(saved: _saved.contains(m.id))];

  @override
  Future<MentorshipOverview> overview({String? category}) async {
    final shelf = _withSaves;
    return MentorshipOverview(
      categories: categoryList,
      selectedCategory: category ?? categoryList.first.label,
      domainsBadge: domainsBadgeFor(8),
      companies: companies,
      shelves: [
        MentorShelf(key: 'network', title: mentorNetworkTitle, mentors: shelf),
        MentorShelf(key: 'network-2', title: mentorNetworkTitle, mentors: shelf),
      ],
      topics: topics,
      banner: banner,
      cohort: cohort,
      services: services,
    );
  }

  @override
  Future<List<MentorCategory>> categories() async => categoryList;

  @override
  Future<MentorPage> search(MentorFilters filters, {int page = 1}) async {
    final q = filters.search.toLowerCase();
    final company = filters.company?.toLowerCase();
    final rows = _withSaves
        .where((m) => q.isEmpty || m.name.toLowerCase().contains(q))
        .where((m) => company == null || (m.role ?? '').toLowerCase().endsWith('@ $company'))
        .toList();
    if (q.isNotEmpty || company != null) return MentorPage(mentors: rows, total: rows.length, hasMore: false);
    // Further pages repeat the design's eight under new ids, up to the 48.
    final shown = page * rows.length;
    return MentorPage(
      mentors: page == 1 ? rows : [for (final m in rows) _copy(m, '${m.id}-p$page')],
      total: total,
      hasMore: shown < total,
    );
  }

  static Mentor _copy(Mentor m, String id) => Mentor(
    id: id,
    name: m.name,
    role: m.role,
    avatar: m.avatar,
    cover: m.cover,
    expertise: m.expertise,
    approved: m.approved,
    rating: m.rating,
    ratingCount: m.ratingCount,
    yearsExperience: m.yearsExperience,
    saved: m.saved,
  );

  @override
  Future<void> setSaved(Mentor mentor, bool saved) async => saved ? _saved.add(mentor.id) : _saved.remove(mentor.id);

  @override
  Future<int> unreadNotifications() async => 1;

  @override
  Uri link(Mentor mentor) => AppConfig.sitePage('/mentorship/mentors');
}
