import '../../core/api/api_error.dart';
import '../../core/config.dart';
import '../feed/feed_models.dart' show FeedPicture;
import 'study_models.dart';
import 'study_repository.dart';

/// A little sample content for `--dart-define=FEED_SOURCE=demo`: three decks, two formula groups, a plan that opens
/// two courses (or decks on their own). Capital Planning and Contract Management go with the Assess your knowledge
/// courses of the same name, Energy Management is on its own: the sample's plan has opened the Capital Planning
/// course (so its deck is open, taking no place), not Contract Management (its deck is locked, and names the
/// course), and Energy Management would take one of the two places. Stars are kept in memory.
class DemoStudyRepository implements StudyRepository {
  final _stars = <String>{};

  /// The course a deck goes with, by deck id.
  static const _courses = {
    'demo-capital': StudyCourseRef(id: 'demo-course-capital', code: 'CP', title: 'Capital Planning'),
    'demo-contracts': StudyCourseRef(id: 'demo-course-contracts', code: 'CM', title: 'Contract Management'),
  };

  /// The courses the sample's plan has opened.
  static const _openCourses = ['demo-course-capital'];

  static const _decks = [
    ('demo-capital', 'capital-planning', 'Capital Planning', 'assets/images/demo/post_green_tower.jpg'),
    ('demo-contracts', 'contract-management', 'Contract Management', 'assets/images/demo/post_rooftop_hvac.jpg'),
    ('demo-energy', 'energy-management', 'Energy Management', 'assets/images/demo/post_control_room.jpg'),
  ];

  static const _qa = [
    (
      'What is capital planning in CRE & FM?',
      'A structured process for forecasting, prioritising, funding and governing investments in buildings and assets.',
      'Strategy & Fundamentals',
      'Beginner',
    ),
    (
      'What is the difference between CapEx and OpEx?',
      'CapEx creates or materially improves an asset; OpEx covers the recurring costs of running and maintaining it.',
      'Strategy & Fundamentals',
      'Beginner',
    ),
    (
      'Why is a lifecycle cost view useful?',
      'It compares options on what they cost to own over their whole life, not only what they cost to buy.',
      'Lifecycle Planning',
      'Intermediate',
    ),
    (
      'What does a replacement reserve do?',
      'It sets money aside each year so a known future replacement is funded when it falls due.',
      'Financial Planning',
      'Intermediate',
    ),
    (
      'Name one test for prioritising capital projects.',
      'Risk: what is the consequence, and how likely, if the asset fails before the project is done?',
      'Prioritisation & Risk',
      'Advanced',
    ),
    (
      'What is a capital plan?',
      'A multi-year roadmap of proposed projects, costs, timing, priorities and funding.',
      'Strategy & Fundamentals',
      'Beginner',
    ),
  ];

  static const _shelves = [
    ('demo-tvm', 'time-value-of-money', 'Time Value of Money'),
    ('demo-cost', 'cost-analysis', 'Cost Analysis'),
  ];

  static StudyCard _formula(
    String id,
    String topicId,
    String front,
    String back, [
    List<FormulaExample> examples = const [],
  ]) => StudyCard(id: id, topicId: topicId, front: front, back: back, examples: examples);

  static final _formulaCards = <String, List<StudyCard>>{
    'time-value-of-money': [
      _formula(
        'f-pv',
        'demo-tvm',
        'Present Value (PV)',
        '\$\$PV = FV\\div (1+r)^{n}\$\$\n\nPV=Present Value\nFV=Future Value\nr=Discount Rate\nn=Number of Years',
        const [
          FormulaExample(
            given: [
              FormulaGiven('Future Building Value', '₹25 Crores'),
              FormulaGiven('Discount Rate', '10%'),
              FormulaGiven('Years', '8'),
            ],
            working: 'PV = 25/(1.10)^8',
            result: 'PV = ₹11.66 Crores',
            analysis: 'The future value of ₹25 Cr is worth only ₹11.66 Cr today.',
            decision: 'If the purchase cost today is less than ₹11.66 Cr, the investment is financially attractive.',
          ),
        ],
      ),
      _formula('f-fv', 'demo-tvm', 'Future Value (FV)', '\$\$FV=PV(1+r)^{n}\$\$'),
      _formula('f-perp', 'demo-tvm', 'Perpetuity', '\$\$PV = C\\div r\$\$'),
    ],
    'cost-analysis': [
      _formula('f-unit', 'demo-cost', 'Unit Cost', '\$\$Unit Cost = Total Cost ÷ Total Units Produced\$\$'),
      _formula('f-cv', 'demo-cost', 'Cost Variance (CV)', '\$\$CV = Budgeted Cost − Actual Cost\$\$'),
      _formula('f-roc', 'demo-cost', 'Return on Cost (ROC)', '\$\$ROC = Net Profit ÷ Total Cost × 100\$\$'),
    ],
  };

  List<StudyCard> _cards(String topicId) => [
    for (var i = 0; i < _qa.length; i++)
      StudyCard(
        id: '$topicId-$i',
        topicId: topicId,
        front: _qa[i].$1,
        back: _qa[i].$2,
        category: _qa[i].$3,
        tags: [_qa[i].$4],
      ),
  ];

  @override
  Future<List<StudyTopic>> topics() async => [
    for (final (i, d) in _decks.indexed)
      StudyTopic(
        id: d.$1,
        slug: d.$2,
        title: d.$3,
        cover: FeedPicture.asset(d.$4),
        cardCount: _qa.length,
        sortOrder: i,
        courseId: _courses[d.$1]?.id,
        course: _courses[d.$1],
      ),
    for (final (i, s) in _shelves.indexed)
      StudyTopic(
        id: s.$1,
        slug: s.$2,
        title: s.$3,
        kind: StudyKind.formula,
        cover: const FeedPicture.asset('assets/images/demo/learning/hub_knowledge.jpg'),
        cardCount: _formulaCards[s.$2]!.length,
        sortOrder: i,
      ),
  ];

  @override
  Future<StudyTopic> topic(String slug) async {
    for (final s in _shelves) {
      if (s.$2 == slug) {
        return StudyTopic(id: s.$1, slug: s.$2, title: s.$3, kind: StudyKind.formula).withCards(_formulaCards[slug]!);
      }
    }
    final at = _decks.indexWhere((d) => d.$2 == slug);
    if (at < 0) throw ApiError('Resource topic not found', statusCode: 404);
    final d = _decks[at];
    // A deck that goes with a course is open exactly when the course is, as the API decides it.
    final course = _courses[d.$1];
    if (course != null && !_openCourses.contains(course.id)) {
      throw DeckLocked(
        'These flash cards open with “${course.title}”. Your plan includes 2 Assess your knowledge courses, and 1 is still free: open the course with your plan to read its cards and sit its levels.',
        reason: 'PICK',
        course: course,
        placesLeft: 1,
      );
    }
    return StudyTopic(
      id: d.$1,
      slug: d.$2,
      title: d.$3,
      cover: FeedPicture.asset(d.$4),
      courseId: course?.id,
      course: course,
    ).withCards(_cards(d.$1));
  }

  @override
  Future<DeckPlan?> deckPlan() async => const DeckPlan(limit: 2, openedCourseIds: _openCourses);

  @override
  Future<List<StudyCard>> starredCards() async => [
    for (final id in _stars)
      for (final d in _decks)
        for (final c in _cards(d.$1))
          if (c.id == id)
            StudyCard(
              id: c.id,
              front: c.front,
              back: c.back,
              topicId: d.$1,
              topicTitle: d.$3,
              topicSlug: d.$2,
              category: c.category,
              tags: c.tags,
            ),
  ];

  @override
  Future<void> setStar(String cardId, bool starred) async {
    starred ? _stars.add(cardId) : _stars.remove(cardId);
  }

  @override
  Future<int> unreadNotifications() async => 0;

  @override
  Uri plansLink([String slug = 'professional']) => AppConfig.sitePage('/pricing/$slug');
}
