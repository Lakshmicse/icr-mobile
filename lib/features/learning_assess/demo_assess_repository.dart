import '../../core/api/api_error.dart';
import '../../core/config.dart';
import 'assess_models.dart';
import 'assess_repository.dart';

/// A little sample content for `--dart-define=FEED_SOURCE=demo`: three programmes and three mock subjects, a
/// member with one level open, one passed, and some ICR credits to spend. Redeeming and opening with a plan
/// place change it, so the controls can be tried without the API.
class DemoAssessRepository implements AssessRepository {
  DemoAssessRepository({int credits = 20}) : _credits = credits;

  static const _tower = FeedPicture.asset('assets/images/demo/post_green_tower.jpg');
  static const _roof = FeedPicture.asset('assets/images/demo/post_rooftop_hvac.jpg');
  static const _control = FeedPicture.asset('assets/images/demo/post_control_room.jpg');

  int _credits;
  final _unlocked = <String>{'cp-foundation'};
  final _byCredits = <String>{};
  final _openCourses = <String>[];

  static AssessPaper _level(
    String course,
    String level, {
    int? price,
    int questions = 10,
    int minutes = 30,
    int pass = 70,
    int? limit,
  }) => AssessPaper(
    id: '$course-${level.toLowerCase()}',
    slug: '$course-${level.toLowerCase()}',
    title: assessLevelLabel(level) ?? level,
    kind: PaperKind.assessment,
    level: level,
    free: price == null,
    priceAmount: price,
    questions: questions,
    durationMinutes: minutes,
    passPercentage: pass,
    attemptLimit: limit,
    certificateEnabled: true,
    courseId: course,
  );

  late final _programmes = <PaperGroup>[
    PaperGroup(
      kind: PaperKind.assessment,
      id: 'cp',
      key: 'CP',
      title: 'Capital Planning',
      summary: 'Plan, prioritise and fund capital projects.',
      cover: _tower,
      knowledgeAreas: const [
        'Capital Planning Fundamentals',
        'Facility Condition Assessment (FCA)',
        'Total Cost of Ownership (TCO)',
        'Capital Budget Process',
      ],
      papers: [_level('cp', 'FOUNDATION'), _level('cp', 'INTERMEDIATE'), _level('cp', 'ADVANCED')],
    ),
    PaperGroup(
      kind: PaperKind.assessment,
      id: 'cm',
      key: 'CM',
      title: 'Contract Management',
      summary: 'From tender to close-out.',
      cover: _roof,
      knowledgeAreas: const ['Contract Strategy', 'Procurement Routes', 'Claims and Variations'],
      papers: [
        _level('cm', 'FOUNDATION', price: 49900),
        _level('cm', 'INTERMEDIATE', price: 99900),
        _level('cm', 'ADVANCED', price: 79900),
      ],
    ),
    PaperGroup(
      kind: PaperKind.assessment,
      id: 'pm',
      key: 'PM',
      title: 'Procurement Management',
      cover: _control,
      knowledgeAreas: const ['Sourcing', 'Supplier Performance'],
      papers: [_level('pm', 'FOUNDATION', price: 49900), _level('pm', 'INTERMEDIATE')],
    ),
  ];

  static AssessPaper _set(String topic, int n, {int? price, int questions = 10, int minutes = 30, int? limit}) =>
      AssessPaper(
        id: '$topic-set-$n',
        slug: '$topic-set-$n',
        title: 'Set $n',
        kind: PaperKind.mock,
        free: price == null,
        priceAmount: price,
        questions: questions,
        durationMinutes: minutes,
        passPercentage: 70,
        attemptLimit: limit,
        topicId: topic,
        sortOrder: n,
      );

  late final _topics = <PaperGroup>[
    PaperGroup(
      kind: PaperKind.mock,
      id: 'aee-cbcp',
      key: 'aee-cbcp',
      title: 'AEE CBCP',
      summary: 'Certified Business Continuity Professional practice papers.',
      cover: _control,
      papers: [_set('aee-cbcp', 1, limit: 3), _set('aee-cbcp', 2, limit: 3)],
    ),
    PaperGroup(
      kind: PaperKind.mock,
      id: 'aee-cem',
      key: 'aee-cem',
      title: 'AEE CEM',
      cover: _tower,
      papers: [_set('aee-cem', 1, price: 29900), _set('aee-cem', 2, price: 29900), _set('aee-cem', 3, price: 29900)],
    ),
    PaperGroup(
      kind: PaperKind.mock,
      id: 'ifma-fmp',
      key: 'ifma-fmp',
      title: 'IFMA FMP',
      cover: _roof,
      papers: [_set('ifma-fmp', 1, questions: 25, minutes: 45)],
    ),
  ];

  @override
  Future<List<PaperGroup>> groups(PaperKind kind) async => kind == PaperKind.mock ? _topics : _programmes;

  @override
  Future<PaperGroup> group(PaperKind kind, String key) async {
    final all = kind == PaperKind.mock ? _topics : _programmes;
    for (final g in all) {
      if (g.key.toLowerCase() == key.toLowerCase()) return g;
    }
    throw ApiError('Not found', statusCode: 404);
  }

  @override
  Future<MemberLearning> member(PaperKind kind) async => MemberLearning(
    access: MemberAccess(
      paperIds: {..._unlocked, ..._byCredits},
      creditPaperIds: {..._byCredits},
      icrCredits: _credits,
      courses: PlanPlaces(limit: 0, opened: _openCourses),
      mocks: const PlanPlaces(limit: 0),
    ),
    progress: kind == PaperKind.assessment
        ? {'cp-foundation': const PaperProgress(attempts: 2, bestPercent: 80, bestScore: 8, maxScore: 10, passed: true)}
        : const {},
    certified: kind == PaperKind.assessment ? {'cp-foundation'} : const {},
  );

  @override
  Future<PaperQuote> quote(AssessPaper paper) async {
    final price = paper.priceAmount ?? 0;
    final tax = (price * 0.18).round();
    return PaperQuote(
      paperId: paper.id,
      listPaisa: price,
      salePaisa: price,
      taxBps: 1800,
      taxPaisa: tax,
      totalPaisa: price + tax,
      credits: price == 0 ? 5 : (price / 10000).ceil(),
    );
  }

  /// The sample's bundle in credits follows the API's rule (`bundleCreditCost`): the closed ones' credits summed,
  /// less 10, never below the dearest. Nothing is offered in money.
  @override
  Future<BundleQuote> bundleQuote(String key, {PaperKind kind = PaperKind.assessment}) async {
    final group = await this.group(kind, key);
    final closed = [
      for (final p in group.papers)
        if (!_unlocked.contains(p.id) && !_byCredits.contains(p.id)) p,
    ];
    final costs = [for (final p in closed) (await quote(p)).credits ?? 5];
    if (costs.length < 2) return BundleQuote(courseCode: key, kind: kind, programmeTitle: group.title);
    final separate = costs.fold<int>(0, (a, b) => a + b);
    final dearest = costs.reduce((a, b) => a > b ? a : b);
    final bundle = (separate - 10) > dearest ? separate - 10 : dearest;
    return BundleQuote(
      courseCode: key,
      kind: kind,
      programmeTitle: group.title,
      credits: bundle,
      separateCredits: separate,
      creditsSaved: separate - bundle,
      creditsOffered: separate - bundle > 0,
      creditLevels: [
        for (final (i, p) in closed.indexed) BundleLevel(paperId: p.id, title: p.title, level: p.level, credits: costs[i]),
      ],
    );
  }

  @override
  Future<RedeemBundleResult> redeemBundle(PaperKind kind, String key) async {
    final quote = await bundleQuote(key, kind: kind);
    final cost = quote.inCredits;
    if (cost == null) throw ApiError('This bundle is not on offer.', statusCode: 400);
    if (_credits < cost) {
      throw ApiError(
        'Every ${kind == PaperKind.mock ? 'set' : 'level'} together takes $cost ICR credits, and you have $_credits.',
        statusCode: 403,
      );
    }
    _credits -= cost;
    final ids = [for (final l in quote.creditLevels) l.paperId];
    _byCredits.addAll(ids);
    return RedeemBundleResult(spent: cost, credits: _credits, paperIds: ids);
  }

  @override
  Future<AssessmentPricing> pricing() async => const AssessmentPricing();

  @override
  Future<RedeemResult> redeem(AssessPaper paper) async {
    final cost = (await quote(paper)).credits ?? 5;
    if (_credits < cost) throw ApiError('This level takes $cost ICR credits, and you have $_credits.', statusCode: 403);
    _credits -= cost;
    _byCredits.add(paper.id);
    return RedeemResult(unlocked: true, spent: cost, credits: _credits);
  }

  @override
  Future<void> openWithPlan(PaperKind kind, String targetId) async {
    throw ApiError('Your plan has no course left to open.', statusCode: 403);
  }

  @override
  Future<int> unreadNotifications() async => 0;

  @override
  Uri paperLink(PaperGroup group, AssessPaper paper) => AppConfig.sitePage('/learning/assessment/${group.key}');

  @override
  Uri groupLink(PaperGroup group) => AppConfig.sitePage('/learning/assessment/${group.key}');

  @override
  Uri plansLink() => AppConfig.sitePage('/pricing/professional');

  @override
  Uri partnerLink() => AppConfig.sitePage('/learning/professional-development');
}
