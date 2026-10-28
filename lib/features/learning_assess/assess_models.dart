/// What the Assess Your Knowledge and Mock Exams doors draw. The live source
/// fills it from `GET /learning/courses?kind=ASSESSMENT`, `/learning/papers`,
/// `/learning/topics`, the member's `me/paper-unlocks`, `me/attempts` and
/// `me/certificates`, and the paper and bundle quotes; the demo source holds a
/// little sample content.
library;

import '../feed/feed_models.dart' show FeedPicture;

export '../feed/feed_models.dart' show FeedPicture;

/// `LearningPaperKind`: a certification level, or a set of a mock exam.
enum PaperKind {
  assessment,
  mock;

  String get api => this == assessment ? 'ASSESSMENT' : 'MOCK';

  static PaperKind fromApi(String? v) => v == 'MOCK' ? mock : assessment;
}

/// Where a course or a mock exam stands against the member's plan: `open`
/// (every level or set is, or they opened it with their plan), `pick` (their
/// plan has a place free for it, not used yet) or `locked` (credits or payment
/// open its levels or sets one at a time). The website's `TargetState`.
enum PlaceState { open, pick, locked }

/// What a card says about one paper: it can be sat now, it opens with a free
/// place of the plan, or it takes ICR credits or a payment.
enum PaperAccess { open, planPlace, closed }

/// The rungs of the assessment ladder, lowest first; `LearningLevel` has two
/// more (Leadership, Specialist) that no assessment is filed at.
const assessLadder = ['FOUNDATION', 'INTERMEDIATE', 'ADVANCED'];

/// The order of the level cards on a programme's page: the ladder, Foundation, Professional, Advanced. The
/// website lays them Foundation, Advanced, Professional left to right (owner's call, 1 Oct 2026, a choice of its
/// three columns); stacked on a phone they read as the climb they are.
const assessCardOrder = assessLadder;

/// "Professional" for the middle rung: the name nobody should see is "Intermediate".
String? assessLevelLabel(String? level) => switch (level) {
  'FOUNDATION' => 'Foundation',
  'INTERMEDIATE' => 'Professional',
  'ADVANCED' => 'Advanced',
  'LEADERSHIP' => 'Leadership',
  'SPECIALIST' => 'Specialist',
  _ => null,
};

/// One paper: an assessment level (`kind` assessment, filed under a programme)
/// or a set of a mock exam (`kind` mock, filed under a topic).
class AssessPaper {
  const AssessPaper({
    required this.id,
    required this.slug,
    required this.title,
    required this.kind,
    this.subtitle,
    this.description,
    this.level,
    this.free = true,
    this.priceAmount,
    this.priceCurrency = 'INR',
    this.creditCost,
    this.questions = 0,
    this.durationMinutes = 0,
    this.passPercentage = 0,
    this.attemptLimit,
    this.certificateEnabled = false,
    this.courseId,
    this.topicId,
    this.sortOrder = 0,
    this.cover,
  });

  final String id;

  /// `GET /learning/papers/:slug` and `POST …/attempts` take this.
  final String slug;

  /// The rung ("Foundation") or the set ("Set 1").
  final String title;
  final PaperKind kind;
  final String? subtitle;
  final String? description;

  /// The API's `LearningLevel` for an assessment level; null for a mock set.
  final String? level;

  /// `access` is FREE. A free paper is still locked to a member whose plan opens
  /// no courses (the plan, not the price, is the gate), so the cards go by the
  /// member's own state and show this only as the catalogue's fact.
  final bool free;

  /// Paise, before GST.
  final int? priceAmount;
  final String priceCurrency;

  /// ICR credits that open it when staff set them.
  final int? creditCost;

  /// How many questions a sitting serves.
  final int questions;
  final int durationMinutes;
  final int passPercentage;

  /// Null: unlimited attempts.
  final int? attemptLimit;
  final bool certificateEnabled;
  final String? courseId;
  final String? topicId;
  final int sortOrder;

  /// The paper's own artwork; a programme with none of its own borrows its first paper's.
  final FeedPicture? cover;

  bool get priced => (priceAmount ?? 0) > 0;

  /// "Professional" for a level, null for a set.
  String? get levelName => assessLevelLabel(level);

  /// The course or exam it sits under: what a plan place opens.
  String? get targetId => kind == PaperKind.mock ? topicId : courseId;
}

/// A programme (a course with assessment levels) or a mock exam subject (a
/// topic with its sets): one card in a door's grid, and the page of its papers.
class PaperGroup {
  const PaperGroup({
    required this.kind,
    required this.id,
    required this.key,
    required this.title,
    this.summary,
    this.cover,
    this.knowledgeAreas = const [],
    this.papers = const [],
    this.sortOrder = 0,
    this.partner,
  });

  final PaperKind kind;
  final String id;

  /// The programme's code or the topic's slug: what the website puts in the route.
  final String key;
  final String title;
  final String? summary;
  final FeedPicture? cover;

  /// What the programme's papers test (`knowledgeAreas`).
  final List<String> knowledgeAreas;
  final List<AssessPaper> papers;
  final int sortOrder;

  /// The awarding institute's name when the programme belongs to one: ICR's own
  /// are listed here, a partner's are catalogued under Professional Development.
  final String? partner;

  bool get isPartner => partner != null;

  /// Free before paid is not a ladder: this is the order a candidate climbs.
  List<AssessPaper> get ladder {
    final rank = {for (final (i, l) in assessLadder.indexed) l: i};
    final sorted = [...papers];
    sorted.sort((a, b) {
      final ra = rank[a.level] ?? 99;
      final rb = rank[b.level] ?? 99;
      return ra != rb ? ra.compareTo(rb) : a.sortOrder.compareTo(b.sortOrder);
    });
    return sorted;
  }

  /// A mock subject's sets, in the order staff set.
  List<AssessPaper> get sets {
    final sorted = [...papers];
    sorted.sort((a, b) => a.sortOrder != b.sortOrder ? a.sortOrder.compareTo(b.sortOrder) : a.title.compareTo(b.title));
    return sorted;
  }

  /// The words a search looks in: the website's `searchProgrammes` fields (the title, the code, the summary and
  /// the papers' titles and subtitles). The knowledge areas are left out on purpose: a dozen programmes cover
  /// "contract" and a search for it should find Contract Management.
  String get haystack => [
    title,
    key,
    summary,
    for (final p in papers) ...[p.title, p.subtitle, p.levelName],
  ].whereType<String>().join(' ').toLowerCase();

  bool get anyFree => papers.any((p) => p.free);
  bool get anyPaid => papers.any((p) => !p.free);
}

/// One member's sittings of one paper, from `GET /learning/me/attempts`.
class PaperProgress {
  const PaperProgress({
    this.attempts = 0,
    this.bestPercent = 0,
    this.bestScore,
    this.maxScore,
    this.passed = false,
    this.lastAt,
  });

  static const none = PaperProgress();

  final int attempts;

  /// The best percentage over every sitting.
  final int bestPercent;

  /// Marks and the paper's marks, from the best sitting.
  final int? bestScore;
  final int? maxScore;

  /// Some sitting passed.
  final bool passed;
  final DateTime? lastAt;

  bool get started => attempts > 0;

  PaperProgress withAttempt({required int percent, int? score, int? maxScore, required bool passed, DateTime? at}) =>
      PaperProgress(
        attempts: attempts + 1,
        bestPercent: percent > bestPercent || attempts == 0 ? percent : bestPercent,
        bestScore: percent > bestPercent || attempts == 0 ? score : bestScore,
        maxScore: percent > bestPercent || attempts == 0 ? maxScore : this.maxScore,
        passed: this.passed || passed,
        lastAt: at != null && (lastAt == null || at.isAfter(lastAt!)) ? at : lastAt,
      );
}

/// How many courses or mock exams a plan opens, and which the member opened.
class PlanPlaces {
  const PlanPlaces({this.limit, this.opened = const []});

  /// Null: every one is open.
  final int? limit;

  /// Oldest first: the first `limit` are the open ones.
  final List<String> opened;

  int? get left => limit == null ? null : (limit! - opened.length).clamp(0, limit!);
  int get used => limit == null ? opened.length : opened.length.clamp(0, limit!);
}

/// The member's own unlocks, ICR credits and plan places (`GET /learning/me/paper-unlocks`).
class MemberAccess {
  const MemberAccess({
    this.allOpen = false,
    this.paperIds = const {},
    this.creditPaperIds = const {},
    this.unlockedCourseIds = const {},
    this.icrCredits = 0,
    this.rupeesPerCredit = 100,
    this.courses = const PlanPlaces(),
    this.mocks = const PlanPlaces(),
    this.upgradePlan,
    this.mockUpgradePlan,
  });

  /// Nothing is locked: staff, or plans that open every course, level, set and deck.
  final bool allOpen;

  /// Papers unlocked one at a time with credits, a purchase or earlier sittings.
  final Set<String> paperIds;

  /// The ones of those opened with ICR credits.
  final Set<String> creditPaperIds;

  /// The courses with a level opened for good (credits or payment): a flash-card deck of the same name opens with
  /// them (`unlockedCourseIds` of `me/paper-unlocks`; empty against an API that does not send it).
  final Set<String> unlockedCourseIds;
  final int icrCredits;
  final int rupeesPerCredit;
  final PlanPlaces courses;
  final PlanPlaces mocks;

  /// The Professional plan that opens more, named on "See plan".
  final String? upgradePlan;
  final String? mockUpgradePlan;

  PlanPlaces places(PaperKind kind) => kind == PaperKind.mock ? mocks : courses;

  /// Where a course (assessment) or a mock exam stands for this member.
  PlaceState stateOf(PaperKind kind, String? id) {
    if (allOpen) return PlaceState.open;
    final places = this.places(kind);
    final limit = places.limit;
    if (id == null || limit == null) return PlaceState.open;
    final at = places.opened.indexOf(id);
    if (at != -1 && at < limit) return PlaceState.open;
    return places.opened.length < limit ? PlaceState.pick : PlaceState.locked;
  }

  PaperAccess accessOf(AssessPaper paper) {
    if (allOpen || paperIds.contains(paper.id)) return PaperAccess.open;
    return switch (stateOf(paper.kind, paper.targetId)) {
      PlaceState.open => PaperAccess.open,
      PlaceState.pick => PaperAccess.planPlace,
      PlaceState.locked => PaperAccess.closed,
    };
  }

  bool redeemedWithCredits(AssessPaper paper) => creditPaperIds.contains(paper.id);

  /// What a plan with no number for this kind says: not included at all.
  bool noneIncluded(PaperKind kind) => places(kind).limit == 0;

  MemberAccess copyWith({
    Set<String>? paperIds,
    Set<String>? creditPaperIds,
    Set<String>? unlockedCourseIds,
    int? icrCredits,
    PlanPlaces? courses,
    PlanPlaces? mocks,
  }) => MemberAccess(
    allOpen: allOpen,
    paperIds: paperIds ?? this.paperIds,
    creditPaperIds: creditPaperIds ?? this.creditPaperIds,
    unlockedCourseIds: unlockedCourseIds ?? this.unlockedCourseIds,
    icrCredits: icrCredits ?? this.icrCredits,
    rupeesPerCredit: rupeesPerCredit,
    courses: courses ?? this.courses,
    mocks: mocks ?? this.mocks,
    upgradePlan: upgradePlan,
    mockUpgradePlan: mockUpgradePlan,
  );
}

/// What the screens know about the member: what they hold, how each paper went.
class MemberLearning {
  const MemberLearning({this.access, this.progress = const {}, this.certified = const {}});

  /// Nothing known (not signed in, or the reads failed): every paper reads as open and `openPaper` decides.
  static const none = MemberLearning();

  final MemberAccess? access;

  /// Keyed by paper id.
  final Map<String, PaperProgress> progress;

  /// Paper ids a certificate was issued for.
  final Set<String> certified;

  PaperProgress progressOf(String paperId) => progress[paperId] ?? PaperProgress.none;

  PaperAccess accessOf(AssessPaper paper) => access?.accessOf(paper) ?? PaperAccess.open;

  MemberLearning copyWith({MemberAccess? access}) =>
      MemberLearning(access: access ?? this.access, progress: progress, certified: certified);
}

/// `PaperQuoteDto`: what a level or set would cost this member, in money and in ICR credits. Takes nothing.
class PaperQuote {
  const PaperQuote({
    required this.paperId,
    this.listPaisa = 0,
    this.discountBps = 0,
    this.discountPaisa = 0,
    this.salePaisa = 0,
    this.taxBps = 0,
    this.taxPaisa = 0,
    this.totalPaisa = 0,
    this.currency = 'INR',
    this.payable = false,
    this.alreadyOpen = false,
    this.memberDiscount = false,
    this.memberPlan,
    this.credits,
    this.rupeesPerCredit = 100,
  });

  final String paperId;
  final int listPaisa;
  final int discountBps;
  final int discountPaisa;

  /// After the discount, before GST: what a card shows.
  final int salePaisa;
  final int taxBps;
  final int taxPaisa;
  final int totalPaisa;
  final String currency;

  /// False for a level with no price and while online payment is not available.
  final bool payable;
  final bool alreadyOpen;
  final bool memberDiscount;
  final String? memberPlan;

  /// ICR credits that open it; null when it has neither credits nor a price.
  final int? credits;
  final int rupeesPerCredit;

  bool get priced => listPaisa > 0;
  bool get discounted => priced && discountPaisa > 0;

  /// What the credits are worth in rupees.
  int? get creditsWorthRupees => credits == null ? null : credits! * rupeesPerCredit;
}

/// One level or set a bundle covers, with its own ICR credits (`creditLevels` of the bundle quote).
class BundleLevel {
  const BundleLevel({required this.paperId, required this.title, this.level, this.credits});

  final String paperId;
  final String title;
  final String? level;

  /// ICR credits this one takes on its own; set in `creditLevels`.
  final int? credits;
}

/// `AssessmentBundleQuoteDto`: the offer to open every level of a programme, or every set of a mock exam, that this
/// member does not hold yet, together: in money (the priced ones, at the bundle discount) and in ICR credits (every
/// closed one at its own credits, summed, less the bundle credit discount: `bundleCreditCost`). The API's figures are
/// shown as they come; nothing here recomputes them. Every credit field is optional: an API that does not send them
/// (production, until the portal's bundle credits are deployed) leaves [creditsOffered] false.
class BundleQuote {
  const BundleQuote({
    required this.courseCode,
    this.kind = PaperKind.assessment,
    this.offered = false,
    this.payable = false,
    this.programmeTitle = '',
    this.levels = const [],
    this.separateSalePaisa = 0,
    this.salePaisa = 0,
    this.savePaisa = 0,
    this.discountBps = 0,
    this.currency = 'INR',
    this.offerEndsOn,
    this.credits,
    this.separateCredits,
    this.creditsSaved = 0,
    this.creditsOffered = false,
    this.creditLevels = const [],
  });

  /// The programme's code, or the mock exam's slug.
  final String courseCode;
  final PaperKind kind;

  /// The money bundle: false while fewer than two priced levels are still closed, or it is off or no better.
  final bool offered;
  final bool payable;
  final String programmeTitle;

  /// The priced levels or sets it covers, in order (their titles).
  final List<String> levels;
  final int separateSalePaisa;
  final int salePaisa;
  final int savePaisa;
  final int discountBps;
  final String currency;

  /// "Offer valid till" (an ISO day), when the discount is a limited one.
  final String? offerEndsOn;

  /// The credit bundle: every closed level or set, redeemed together.
  final int? credits;
  final int? separateCredits;

  /// How many fewer credits the bundle takes than redeeming them one at a time.
  final int creditsSaved;
  final bool creditsOffered;

  /// Every closed level or set the credit bundle opens, each with its own credits.
  final List<BundleLevel> creditLevels;

  bool get mock => kind == PaperKind.mock;

  /// The bundle's credits when it is on offer in credits, else null.
  int? get inCredits => creditsOffered && credits != null ? credits : null;

  /// Something is on offer: money, credits, or both.
  bool get hasOffer => offered || inCredits != null;

  /// The levels or sets the offer names: the priced ones when it is paid for, else every closed one.
  List<String> get shownTitles => offered ? levels : [for (final l in creditLevels) l.title];
  int get count => shownTitles.length;
}

/// `AssessmentPricingDto`: the global discounts staff set.
class AssessmentPricing {
  const AssessmentPricing({this.discountPercent = 0, this.bundleDiscountPercent = 0});

  final int discountPercent;
  final int bundleDiscountPercent;
}

/// `RedeemPaperResultDto`.
class RedeemResult {
  const RedeemResult({required this.unlocked, required this.spent, required this.credits});

  final bool unlocked;

  /// ICR credits it took; 0 when it was already open.
  final int spent;

  /// What is left.
  final int credits;
}

/// `RedeemBundleResultDto`: what redeeming a whole bundle in ICR credits did.
class RedeemBundleResult {
  const RedeemBundleResult({
    required this.spent,
    required this.credits,
    this.paperIds = const [],
    this.unlockedCourseIds = const [],
  });

  /// ICR credits it took; 0 when nothing was left to open.
  final int spent;

  /// What is left.
  final int credits;

  /// The levels or sets it opened.
  final List<String> paperIds;

  /// The courses with one of those levels: a flash-card deck linked to one opens with it.
  final List<String> unlockedCourseIds;
}
