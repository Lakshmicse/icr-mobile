import 'package:flutter/widgets.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/features/learning_assess/assess_models.dart';
import 'package:icr_mobile/features/learning_assess/assess_repository.dart';
import 'package:icr_mobile/features/learning_exam/open_paper.dart';

/// A recording stand-in for the Assess and Mock Exams source: every call is logged by name, a call can be made to
/// fail with an [ApiError], and the member's unlocks change as redemptions and plan places are taken, the way the
/// API's do.
class FakeAssess implements AssessRepository {
  FakeAssess({
    List<PaperGroup>? programmes,
    List<PaperGroup>? topics,
    MemberLearning? member,
    Map<String, PaperQuote>? quotes,
    BundleQuote? bundle,
    this.pricingNow = const AssessmentPricing(),
    this.unread = 0,
    this.gate,
  }) : programmes = programmes ?? assessWorld(),
       topics = topics ?? mockWorld(),
       memberNow = member ?? assessMember(),
       quotes = quotes ?? assessQuotes(),
       bundleQuoteNow = bundle ?? const BundleQuote(courseCode: 'CM');

  List<PaperGroup> programmes;
  List<PaperGroup> topics;
  MemberLearning memberNow;
  Map<String, PaperQuote> quotes;
  BundleQuote bundleQuoteNow;
  AssessmentPricing pricingNow;
  int unread;

  /// Calls wait on this when set (to see a loading state).
  Future<void>? gate;

  final calls = <String>[];

  /// Method name (or `method:arg`) → what to throw.
  final failures = <String, Object>{};

  Future<T> _call<T>(String name, T Function() body, [String? arg]) async {
    calls.add(arg == null ? name : '$name:$arg');
    if (gate != null) await gate;
    final failure = failures[arg == null ? name : '$name:$arg'] ?? failures[name];
    if (failure != null) throw failure;
    return body();
  }

  int count(String name) => calls.where((c) => c == name || c.startsWith('$name:')).length;

  @override
  Future<List<PaperGroup>> groups(PaperKind kind) =>
      _call('groups', () => kind == PaperKind.mock ? topics : programmes, kind.name);

  @override
  Future<PaperGroup> group(PaperKind kind, String key) => _call('group', () {
    final all = kind == PaperKind.mock ? topics : programmes;
    for (final g in all) {
      if (g.key == key) return g;
    }
    throw ApiError('Not found', statusCode: 404);
  }, key);

  @override
  Future<MemberLearning> member(PaperKind kind) => _call('member', () => memberNow, kind.name);

  @override
  Future<PaperQuote> quote(AssessPaper paper) => _call('quote', () {
    final q = quotes[paper.id];
    if (q == null) throw ApiError('No quote', statusCode: 404);
    return q;
  }, paper.slug);

  @override
  Future<BundleQuote> bundleQuote(String key, {PaperKind kind = PaperKind.assessment}) =>
      _call('bundleQuote', () => bundleQuoteNow, '${kind.name}:$key');

  /// What a bundle redemption answers with; null: the real rule (the quote's credits, spent from the balance).
  RedeemBundleResult? redeemBundleAnswer;

  @override
  Future<RedeemBundleResult> redeemBundle(PaperKind kind, String key) => _call('redeemBundle', () {
    final access = memberNow.access!;
    final quote = bundleQuoteNow;
    final cost = quote.inCredits;
    if (cost == null) throw ApiError('This bundle is not on offer.', statusCode: 400);
    if (access.icrCredits < cost) {
      throw ApiError(
        'Every ${kind == PaperKind.mock ? 'set' : 'level'} together takes $cost ICR credits, and you have ${access.icrCredits}.',
        statusCode: 403,
        code: 'NO_CREDIT_LEFT',
      );
    }
    final ids = [for (final l in quote.creditLevels) l.paperId];
    // The courses the opened levels belong to, as the API's `unlockedCourseIds` names them.
    final courses = {
      for (final g in [...programmes, ...topics])
        for (final p in g.papers)
          if (ids.contains(p.id) && p.courseId != null) p.courseId!,
    };
    memberNow = memberNow.copyWith(
      access: access.copyWith(
        paperIds: {...access.paperIds, ...ids},
        creditPaperIds: {...access.creditPaperIds, ...ids},
        unlockedCourseIds: {...access.unlockedCourseIds, ...courses},
        icrCredits: access.icrCredits - cost,
      ),
    );
    // Once opened there is nothing left to bundle.
    bundleQuoteNow = BundleQuote(courseCode: key, kind: kind, programmeTitle: quote.programmeTitle);
    return redeemBundleAnswer ?? RedeemBundleResult(spent: cost, credits: access.icrCredits - cost, paperIds: ids);
  }, '${kind.name}:$key');

  @override
  Future<AssessmentPricing> pricing() => _call('pricing', () => pricingNow);

  @override
  Future<RedeemResult> redeem(AssessPaper paper) => _call('redeem', () {
    final access = memberNow.access!;
    final cost = quotes[paper.id]?.credits ?? 5;
    if (access.icrCredits < cost) {
      throw ApiError(
        'This level takes $cost ICR credits, and you have ${access.icrCredits}.',
        statusCode: 403,
        code: 'NO_CREDIT_LEFT',
      );
    }
    memberNow = memberNow.copyWith(
      access: access.copyWith(
        paperIds: {...access.paperIds, paper.id},
        creditPaperIds: {...access.creditPaperIds, paper.id},
        icrCredits: access.icrCredits - cost,
      ),
    );
    return RedeemResult(unlocked: true, spent: cost, credits: access.icrCredits - cost);
  }, paper.slug);

  @override
  Future<void> openWithPlan(PaperKind kind, String targetId) => _call('openWithPlan', () {
    final access = memberNow.access!;
    final places = access.places(kind);
    final limit = places.limit ?? 0;
    if (places.opened.length >= limit) {
      throw ApiError(
        'Your plan has no ${kind == PaperKind.mock ? 'mock exam' : 'course'} left to open. Redeem ICR credits for a level, or buy one.',
        statusCode: 403,
        code: 'NO_PLAN_PLACE_LEFT',
      );
    }
    final next = PlanPlaces(limit: places.limit, opened: [...places.opened, targetId]);
    memberNow = memberNow.copyWith(
      access: kind == PaperKind.mock ? access.copyWith(mocks: next) : access.copyWith(courses: next),
    );
  }, '${kind.name}:$targetId');

  @override
  Future<int> unreadNotifications() => _call('unread', () => unread);

  @override
  Uri paperLink(PaperGroup group, AssessPaper paper) => Uri.parse('https://site.test/paper/${group.key}/${paper.slug}');

  @override
  Uri groupLink(PaperGroup group) => Uri.parse('https://site.test/group/${group.key}');

  @override
  Uri plansLink() => Uri.parse('https://site.test/pricing/professional');

  @override
  Uri partnerLink() => Uri.parse('https://site.test/partners');
}

/// A paper opener that records what it was asked to open and, when [onOpen] is given, does something as the
/// exam would (take an attempt, say) before it returns.
class RecordingOpener {
  RecordingOpener({this.onOpen});

  final Future<void> Function(PaperRef paper)? onOpen;
  final opened = <PaperRef>[];

  Future<void> call(BuildContext context, PaperRef paper) async {
    opened.add(paper);
    await onOpen?.call(paper);
  }
}

/// A launcher that records the pages handed to the browser.
class RecordingLauncher {
  final uris = <Uri>[];

  Future<void> call(BuildContext context, Uri uri) async => uris.add(uri);
}

// --- a small world shaped like the local API's ------------------------------------------------

AssessPaper level(
  String course,
  String level, {
  int? price,
  int questions = 10,
  int minutes = 30,
  int pass = 70,
  int? limit,
  String? slug,
  bool certificate = true,
}) => AssessPaper(
  id: '$course-${level.toLowerCase()}',
  slug: slug ?? '$course-${level.toLowerCase()}',
  title: assessLevelLabel(level) ?? level,
  kind: PaperKind.assessment,
  level: level,
  free: price == null,
  priceAmount: price,
  questions: questions,
  durationMinutes: minutes,
  passPercentage: pass,
  attemptLimit: limit,
  certificateEnabled: certificate,
  courseId: 'course-$course',
);

AssessPaper mockSet(
  String topic,
  int n, {
  int? price,
  int questions = 10,
  int minutes = 30,
  int? limit,
  String? description,
}) => AssessPaper(
  id: '$topic-set-$n',
  slug: '$topic-set-$n',
  title: 'Set $n',
  kind: PaperKind.mock,
  description: description,
  free: price == null,
  priceAmount: price,
  questions: questions,
  durationMinutes: minutes,
  passPercentage: 70,
  attemptLimit: limit,
  topicId: 'topic-$topic',
  sortOrder: n,
);

PaperGroup programme(
  String code,
  String title,
  List<AssessPaper> papers, {
  List<String> areas = const [],
  String? summary,
  String? partner,
  int sortOrder = 0,
  FeedPicture? cover,
}) => PaperGroup(
  kind: PaperKind.assessment,
  id: 'course-${code.toLowerCase()}',
  key: code,
  title: title,
  summary: summary,
  cover: cover,
  knowledgeAreas: areas,
  papers: papers,
  partner: partner,
  sortOrder: sortOrder,
);

PaperGroup topic(
  String slug,
  String title,
  List<AssessPaper> sets, {
  String? description,
  int sortOrder = 0,
  FeedPicture? cover,
}) => PaperGroup(
  kind: PaperKind.mock,
  id: 'topic-$slug',
  key: slug,
  title: title,
  summary: description,
  cover: cover,
  papers: sets,
  sortOrder: sortOrder,
);

/// Four of ICR's programmes in the catalogue's order, and a partner's (which this door leaves out):
/// Capital Planning (three free levels), Contract Management (three priced), Human Capital (two levels, the
/// Professional one not published), Procurement Management (Foundation priced, the others free).
List<PaperGroup> assessWorld({FeedPicture? cover}) => [
  programme('PM', 'Procurement Management', [
    level('pm', 'FOUNDATION', price: 49900, slug: 'procurement-management-foundation'),
    level('pm', 'INTERMEDIATE', slug: 'procurement-management-professional'),
    level('pm', 'ADVANCED', slug: 'procurement-management-advanced'),
  ], cover: cover),
  programme(
    'CP',
    'Capital Planning',
    [
      level('cp', 'FOUNDATION', slug: 'capital-planning-foundation'),
      level('cp', 'INTERMEDIATE', slug: 'capital-planning-professional'),
      level('cp', 'ADVANCED', slug: 'capital-planning-advanced'),
    ],
    areas: const [
      'Capital Planning Fundamentals',
      'Facilities Asset Management Cycle',
      'Facility Condition Assessment (FCA)',
      'Facility Condition Index (FCI)',
      'Portfolio Review and Analysis',
      'Asset Inventory Analysis',
      'Total Cost of Ownership (TCO)',
      'Life Cycle Cost Analysis (LCCA)',
      'Capital Budget Process',
      'Risk-Based Capital Planning',
    ],
    cover: cover,
  ),
  programme('CM', 'Contract Management', [
    level('cm', 'FOUNDATION', price: 49900, slug: 'contract-management-foundation'),
    level('cm', 'INTERMEDIATE', price: 99900, slug: 'contract-management-professional'),
    level('cm', 'ADVANCED', price: 79900, slug: 'contract-management-advanced'),
  ], cover: cover),
  programme('HC', 'Human Capital', [
    level('hc', 'FOUNDATION', slug: 'human-capital-foundation'),
    level('hc', 'ADVANCED', slug: 'human-capital-advanced'),
  ], cover: cover),
  programme('LEO', 'Leoron Certified Planner', [
    level('leo', 'FOUNDATION', slug: 'leoron-foundation'),
  ], partner: 'Leoron Institute'),
];

/// The mock exam subjects: AEE CBCP (two free sets, three attempts each), AEE CEM (three priced sets), IFMA FMP (one).
List<PaperGroup> mockWorld({FeedPicture? cover}) => [
  topic('aee-cbcp', 'AEE CBCP', [
    mockSet('aee-cbcp', 1, limit: 3),
    mockSet('aee-cbcp', 2, limit: 3, description: 'Business continuity: the second paper.'),
  ], cover: cover),
  topic('aee-cem', 'AEE CEM', [
    mockSet('aee-cem', 1, price: 29900),
    mockSet('aee-cem', 2, price: 29900),
    mockSet('aee-cem', 3, price: 29900),
  ], cover: cover),
  topic(
    'ifma-fmp',
    'IFMA FMP',
    [mockSet('ifma-fmp', 1, questions: 25, minutes: 45)],
    description: 'Facility management practice papers.',
    cover: cover,
  ),
];

/// Bharat Buyer as the local API knows him: his plan opens no course and no mock exam, he holds 100 ICR credits,
/// and one paper (Capital Planning, Advanced) is open to him because he redeemed credits for it.
MemberLearning assessMember({
  int credits = 100,
  Set<String> open = const {'cp-advanced'},
  Set<String> redeemed = const {'cp-advanced'},
  PlanPlaces courses = const PlanPlaces(limit: 0),
  PlanPlaces mocks = const PlanPlaces(limit: 0),
  bool allOpen = false,
  Map<String, PaperProgress> progress = const {},
  Set<String> certified = const {},
  String? upgradePlan,
  String? mockUpgradePlan,
}) => MemberLearning(
  access: MemberAccess(
    allOpen: allOpen,
    paperIds: open,
    creditPaperIds: redeemed,
    icrCredits: credits,
    courses: courses,
    mocks: mocks,
    upgradePlan: upgradePlan,
    mockUpgradePlan: mockUpgradePlan,
  ),
  progress: progress,
  certified: certified,
);

/// What the quote endpoint says for the papers of [assessWorld] and [mockWorld] that are closed to Bharat.
Map<String, PaperQuote> assessQuotes() {
  PaperQuote priced(String id, int list, {int credits = 5, int discountBps = 0, bool payable = true}) {
    final discount = (list * discountBps / 10000).round();
    final sale = list - discount;
    final tax = (sale * 0.18).round();
    return PaperQuote(
      paperId: id,
      listPaisa: list,
      discountBps: discountBps,
      discountPaisa: discount,
      salePaisa: sale,
      taxBps: 1800,
      taxPaisa: tax,
      totalPaisa: sale + tax,
      payable: payable,
      credits: credits,
    );
  }

  PaperQuote creditsOnly(String id, {int credits = 5}) => PaperQuote(paperId: id, credits: credits);
  return {
    'pm-foundation': priced('pm-foundation', 49900, credits: 4),
    'pm-intermediate': creditsOnly('pm-intermediate'),
    'pm-advanced': creditsOnly('pm-advanced'),
    'cp-foundation': creditsOnly('cp-foundation'),
    'cp-intermediate': creditsOnly('cp-intermediate'),
    'cm-foundation': priced('cm-foundation', 49900, credits: 5),
    'cm-intermediate': priced('cm-intermediate', 99900, credits: 10),
    'cm-advanced': priced('cm-advanced', 79900, credits: 8),
    'hc-foundation': creditsOnly('hc-foundation'),
    'hc-advanced': creditsOnly('hc-advanced'),
    'aee-cbcp-set-1': creditsOnly('aee-cbcp-set-1'),
    'aee-cbcp-set-2': creditsOnly('aee-cbcp-set-2'),
    'aee-cem-set-1': priced('aee-cem-set-1', 29900, credits: 3),
    'aee-cem-set-2': priced('aee-cem-set-2', 29900, credits: 3),
    'aee-cem-set-3': priced('aee-cem-set-3', 29900, credits: 3),
    'ifma-fmp-set-1': creditsOnly('ifma-fmp-set-1'),
  };
}
