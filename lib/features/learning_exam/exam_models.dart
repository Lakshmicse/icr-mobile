/// What the exam flow draws and sends: a paper and its served questions, the
/// refusal to open one, a sitting's result and review, and a certificate.
///
/// Filled from `GET /learning/papers/:slug` (the paper with its questions, the
/// answer key stripped), `GET /learning/papers/:slug/quote`, the member's
/// attempts (`/learning/me/attempts`) and certificates
/// (`/learning/me/certificates`). Every field here is one the API sends; the
/// parsing is lenient (a missing number reads as zero, a missing list as
/// empty) because the screens must still draw something from an older row.
library;

/// `LearningPaperKind`: a level paper under a certification programme, or a
/// set of a mock exam subject.
enum PaperKind {
  assessment,
  mock;

  static PaperKind fromApi(String? v) => v == 'MOCK' ? mock : assessment;
}

/// `LearningQuestionType`. SINGLE has one right option; MULTIPLE is scored only
/// when every right option (and no other) is picked.
enum QuestionType {
  single,
  multiple;

  static QuestionType fromApi(String? v) => v == 'MULTIPLE' ? multiple : single;
}

int _int(Object? v, [int fallback = 0]) =>
    v is num ? v.toInt() : (v is String ? int.tryParse(v) ?? fallback : fallback);

int? _intOrNull(Object? v) => v is num ? v.toInt() : null;

String? _text(Object? v) {
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;

List<String> _strings(Object? v) => (v as List? ?? const []).map((e) => e.toString()).toList();

List<int> _ints(Object? v) => (v as List? ?? const []).whereType<num>().map((e) => e.toInt()).toList();

/// "Foundation", "Professional" (the assessment side's name for INTERMEDIATE),
/// "Advanced"...: `ASSESSMENT_LEVEL_LABELS`.
String? assessmentLevelLabel(String? level) => switch (level) {
  'FOUNDATION' => 'Foundation',
  'INTERMEDIATE' => 'Professional',
  'ADVANCED' => 'Advanced',
  'LEADERSHIP' => 'Leadership',
  'SPECIALIST' => 'Specialist',
  _ => null,
};

/// A paper's parameters: what the brief says before anyone sits it.
class PaperInfo {
  const PaperInfo({
    required this.id,
    required this.slug,
    required this.title,
    required this.kind,
    this.level,
    this.subtitle,
    this.description,
    this.instructions,
    this.imageUrl,
    this.durationMinutes = 30,
    this.passPercentage = 70,
    this.questionCount = 0,
    this.totalMarks = 0,
    this.attemptLimit,
    this.certificateEnabled = false,
    this.priceAmount,
    this.creditCost,
    this.courseId,
    this.courseCode,
    this.courseTitle,
    this.topicId,
    this.topicSlug,
    this.topicTitle,
  });

  final String id;
  final String slug;

  /// The rung ("Foundation") or the set ("Set 2"): not the whole name.
  final String title;
  final PaperKind kind;

  /// `LearningLevel`, as the API sends it.
  final String? level;
  final String? subtitle;
  final String? description;

  /// Staff-written copy that takes the place of the default "before you start".
  final String? instructions;
  final String? imageUrl;
  final int durationMinutes;
  final int passPercentage;

  /// How many questions a sitting serves.
  final int questionCount;
  final int totalMarks;

  /// Null is unlimited.
  final int? attemptLimit;
  final bool certificateEnabled;

  /// Paise.
  final int? priceAmount;
  final int? creditCost;
  final String? courseId;
  final String? courseCode;
  final String? courseTitle;
  final String? topicId;
  final String? topicSlug;
  final String? topicTitle;

  /// The programme or subject the paper sits under, or its own subtitle.
  String? get context => courseTitle ?? topicTitle ?? subtitle;

  /// "Capital Planning – Foundation": the subject in front of the rung, as the
  /// website names a sitting everywhere.
  String get name => context == null ? title : '$context – $title';

  /// "Foundation" for a level paper; null for a mock set.
  String? get levelLabel => kind == PaperKind.assessment ? assessmentLevelLabel(level) : null;

  bool get isMock => kind == PaperKind.mock;

  Duration get duration => Duration(minutes: durationMinutes);

  /// The page for this paper on the website, where a paid paper is bought.
  String get sitePath {
    if (kind == PaperKind.mock) {
      return topicSlug == null ? '/learning/mock-tests' : '/learning/mock-tests/$topicSlug/$slug';
    }
    return courseCode == null ? '/learning/assessment' : '/learning/assessment/${courseCode!.toLowerCase()}/$slug';
  }

  factory PaperInfo.fromJson(Map<String, dynamic> j) {
    final course = j['course'] as Map<String, dynamic>?;
    final topic = j['topic'] as Map<String, dynamic>?;
    return PaperInfo(
      id: j['id'] as String? ?? '',
      slug: j['slug'] as String? ?? '',
      title: j['title'] as String? ?? '',
      kind: PaperKind.fromApi(j['kind'] as String?),
      level: _text(j['level']),
      subtitle: _text(j['subtitle']),
      description: _text(j['description']),
      instructions: _text(j['instructions']),
      imageUrl: _text(j['imageUrl']),
      durationMinutes: _int(j['durationMinutes'], 30),
      passPercentage: _int(j['passPercentage'], 70),
      // The detail carries the served count in `questionCount`; the list leaves it null and says
      // `servedQuestions` instead.
      questionCount: _int(j['questionCount'] ?? j['servedQuestions']),
      totalMarks: _int(j['totalMarks']),
      attemptLimit: _intOrNull(j['attemptLimit']),
      certificateEnabled: j['certificateEnabled'] == true,
      priceAmount: _intOrNull(j['priceAmount']),
      creditCost: _intOrNull(j['creditCost']),
      courseId: _text(j['courseId']) ?? _text(course?['id']),
      courseCode: _text(course?['code']),
      courseTitle: _text(course?['title']),
      topicId: _text(j['topicId']) ?? _text(topic?['id']),
      topicSlug: _text(topic?['slug']),
      topicTitle: _text(topic?['title']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'slug': slug,
    'title': title,
    'kind': kind == PaperKind.mock ? 'MOCK' : 'ASSESSMENT',
    'level': level,
    'subtitle': subtitle,
    'description': description,
    'instructions': instructions,
    'imageUrl': imageUrl,
    'durationMinutes': durationMinutes,
    'passPercentage': passPercentage,
    'questionCount': questionCount,
    'totalMarks': totalMarks,
    'attemptLimit': attemptLimit,
    'certificateEnabled': certificateEnabled,
    'priceAmount': priceAmount,
    'creditCost': creditCost,
    'courseId': courseId,
    'course': courseCode == null ? null : {'id': courseId, 'code': courseCode, 'title': courseTitle},
    'topicId': topicId,
    'topic': topicSlug == null ? null : {'id': topicId, 'slug': topicSlug, 'title': topicTitle},
  };
}

/// A question as served to a candidate: the answer key stays on the server.
class ServedQuestion {
  const ServedQuestion({
    required this.id,
    required this.prompt,
    required this.options,
    this.type = QuestionType.single,
    this.marks = 1,
    this.category,
  });

  final String id;
  final String prompt;
  final List<String> options;
  final QuestionType type;
  final int marks;
  final String? category;

  bool get multiple => type == QuestionType.multiple;

  factory ServedQuestion.fromJson(Map<String, dynamic> j) => ServedQuestion(
    id: j['id'] as String? ?? '',
    prompt: j['prompt'] as String? ?? '',
    options: _strings(j['options']),
    type: QuestionType.fromApi(j['type'] as String?),
    marks: _int(j['marks'], 1),
    category: _text(j['category']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'prompt': prompt,
    'options': options,
    'type': multiple ? 'MULTIPLE' : 'SINGLE',
    'marks': marks,
    'category': category,
  };
}

/// A paper ready to sit: its parameters and the questions the sitting serves,
/// in the order served.
class PaperSitting {
  const PaperSitting({required this.paper, required this.questions});

  final PaperInfo paper;
  final List<ServedQuestion> questions;

  factory PaperSitting.fromJson(Map<String, dynamic> j) => PaperSitting(
    paper: PaperInfo.fromJson(j),
    questions: [
      for (final q in (j['questions'] as List? ?? const []).cast<Map<String, dynamic>>()) ServedQuestion.fromJson(q),
    ],
  );

  Map<String, dynamic> toJson() => {
    ...paper.toJson(),
    'questions': [for (final q in questions) q.toJson()],
  };
}

/// The API's refusal to open a paper (`403 PAPER_LOCKED` / `NO_CREDIT_LEFT`):
/// what would open it, and what the member holds.
class PaperLock {
  const PaperLock({
    required this.message,
    this.code = 'PAPER_LOCKED',
    this.reason,
    this.credits = 0,
    this.opensTarget,
    this.opensId,
    this.placesLeft,
    this.plan,
    this.pricingSlug = 'professional',
  });

  final String message;
  final String code;

  /// PICK (the plan has a place for this course or exam), COURSES or MOCKS
  /// (the plan's places are used up, or it has none), SIGN_IN.
  final String? reason;

  /// ICR credits the member holds.
  final int credits;

  /// `COURSE` or `MOCK_EXAM`, and the id of the course or subject a plan place would open whole.
  final String? opensTarget;
  final String? opensId;
  final int? placesLeft;

  /// The plan that opens more, for an upgrade link.
  final String? plan;
  final String pricingSlug;

  /// The plan has a place free for this course or mock exam: opening it costs nothing.
  bool get planCanOpen => reason == 'PICK' && opensTarget != null && opensId != null;

  factory PaperLock.fromJson(Map<String, dynamic> j) {
    final opens = j['opens'] as Map<String, dynamic>?;
    return PaperLock(
      message: j['message'] is String ? j['message'] as String : 'This paper is locked.',
      code: j['code'] as String? ?? 'PAPER_LOCKED',
      reason: _text(j['reason']),
      credits: _int(j['remaining']),
      opensTarget: _text(opens?['target']),
      opensId: _text(opens?['id']),
      placesLeft: _intOrNull(j['placesLeft']),
      plan: _text(j['plan']),
      pricingSlug: _text(j['pricingSlug']) ?? 'professional',
    );
  }
}

/// `GET /learning/papers/:slug/quote`: what opening the paper costs this member.
class PaperQuote {
  const PaperQuote({
    required this.listPaisa,
    required this.salePaisa,
    required this.taxPaisa,
    required this.totalPaisa,
    this.discountPaisa = 0,
    this.discountBps = 0,
    this.taxBps = 0,
    this.payable = false,
    this.alreadyOpen = false,
    this.credits,
    this.rupeesPerCredit = 100,
    this.memberPlan,
  });

  final int listPaisa;
  final int discountPaisa;
  final int discountBps;
  final int salePaisa;
  final int taxBps;
  final int taxPaisa;
  final int totalPaisa;

  /// Online payment is available and the paper has a price.
  final bool payable;
  final bool alreadyOpen;

  /// ICR credits that open it instead; null when it cannot be redeemed.
  final int? credits;
  final int rupeesPerCredit;
  final String? memberPlan;

  bool get priced => listPaisa > 0;

  factory PaperQuote.fromJson(Map<String, dynamic> j) => PaperQuote(
    listPaisa: _int(j['listPaisa']),
    discountPaisa: _int(j['discountPaisa']),
    discountBps: _int(j['discountBps']),
    salePaisa: _int(j['salePaisa']),
    taxBps: _int(j['taxBps']),
    taxPaisa: _int(j['taxPaisa']),
    totalPaisa: _int(j['totalPaisa']),
    payable: j['payable'] == true,
    alreadyOpen: j['alreadyOpen'] == true,
    credits: _intOrNull(j['credits']),
    rupeesPerCredit: _int(j['rupeesPerCredit'], 100),
    memberPlan: _text(j['memberPlan']),
  );
}

/// What `POST /learning/papers/:slug/redeem` answers.
class RedeemResult {
  const RedeemResult({required this.spent, required this.credits});

  /// The credits it took; 0 when it was open already.
  final int spent;

  /// ICR credits left.
  final int credits;
}

/// The parent a past sitting's paper sits under, as `/me/attempts` sends it.
class AttemptPaper {
  const AttemptPaper({
    required this.id,
    required this.slug,
    required this.title,
    required this.kind,
    this.level,
    this.certificateEnabled,
    this.topicSlug,
    this.topicTitle,
    this.courseCode,
    this.courseTitle,
  });

  final String id;
  final String slug;
  final String title;
  final PaperKind kind;
  final String? level;

  /// Only the single-attempt read says; null in the list.
  final bool? certificateEnabled;
  final String? topicSlug;
  final String? topicTitle;
  final String? courseCode;
  final String? courseTitle;

  String? get context => courseTitle ?? topicTitle;
  String get name => context == null ? title : '$context – $title';
  String? get levelLabel => kind == PaperKind.assessment ? assessmentLevelLabel(level) : null;

  /// What a landing screen would pass to `openPaper` to sit this paper (again).
  PaperRef get ref => PaperRef(slug: slug, title: name, id: id, isMock: kind == PaperKind.mock, courseCode: courseCode);

  factory AttemptPaper.fromJson(Map<String, dynamic> j) {
    final topic = j['topic'] as Map<String, dynamic>?;
    final course = j['course'] as Map<String, dynamic>?;
    return AttemptPaper(
      id: j['id'] as String? ?? '',
      slug: j['slug'] as String? ?? '',
      title: j['title'] as String? ?? '',
      kind: PaperKind.fromApi(j['kind'] as String?),
      level: _text(j['level']),
      certificateEnabled: j['certificateEnabled'] as bool?,
      topicSlug: _text(topic?['slug']),
      topicTitle: _text(topic?['title']),
      courseCode: _text(course?['code']),
      courseTitle: _text(course?['title']),
    );
  }
}

/// What a landing screen (Assess Your Knowledge, Mock Exams, My attempts)
/// knows about a paper when it opens one.
class PaperRef {
  const PaperRef({required this.slug, required this.title, this.id, this.isMock = false, this.courseCode});

  /// `GET /learning/papers/:slug` and `POST /learning/papers/:slug/attempts` take this.
  final String slug;
  final String title;
  final String? id;

  /// A mock exam set, rather than an assessment level.
  final bool isMock;
  final String? courseCode;
}

/// One completed sitting, as the server recorded it.
class Attempt {
  const Attempt({
    required this.id,
    required this.paperId,
    required this.attempt,
    required this.startedAt,
    required this.submittedAt,
    required this.timeTakenMs,
    required this.totalQuestions,
    required this.correct,
    required this.wrong,
    required this.unanswered,
    required this.score,
    required this.maxScore,
    required this.percentage,
    required this.passPercentage,
    required this.passed,
    this.paper,
  });

  final String id;
  final String paperId;

  /// 1-based, in submission order.
  final int attempt;
  final DateTime? startedAt;
  final DateTime? submittedAt;
  final int timeTakenMs;
  final int totalQuestions;
  final int correct;
  final int wrong;
  final int unanswered;
  final int score;
  final int maxScore;
  final int percentage;
  final int passPercentage;
  final bool passed;
  final AttemptPaper? paper;

  Duration get timeTaken => Duration(milliseconds: timeTakenMs);

  factory Attempt.fromJson(Map<String, dynamic> j) => Attempt(
    id: j['id'] as String? ?? '',
    paperId: j['paperId'] as String? ?? '',
    attempt: _int(j['attempt'], 1),
    startedAt: _date(j['startedAt']),
    submittedAt: _date(j['submittedAt']),
    timeTakenMs: _int(j['timeTakenMs']),
    totalQuestions: _int(j['totalQuestions']),
    correct: _int(j['correct']),
    wrong: _int(j['wrong']),
    unanswered: _int(j['unanswered']),
    score: _int(j['score']),
    maxScore: _int(j['maxScore']),
    percentage: _int(j['percentage']),
    passPercentage: _int(j['passPercentage'], 70),
    passed: j['passed'] == true,
    paper: j['paper'] is Map<String, dynamic> ? AttemptPaper.fromJson(j['paper'] as Map<String, dynamic>) : null,
  );
}

/// One reviewed question, returned with a result: the key, the explanation, and
/// what the candidate picked.
class ReviewItem {
  const ReviewItem({
    required this.id,
    required this.prompt,
    required this.options,
    required this.correctIndexes,
    required this.selected,
    this.explanation,
    this.category,
  });

  final String id;
  final String prompt;
  final List<String> options;
  final List<int> correctIndexes;
  final List<int> selected;
  final String? explanation;
  final String? category;

  ReviewOutcome get outcome {
    if (selected.isEmpty) return ReviewOutcome.skipped;
    final key = [...correctIndexes]..sort();
    final given = [...selected]..sort();
    if (key.length != given.length) return ReviewOutcome.incorrect;
    for (var i = 0; i < key.length; i++) {
      if (key[i] != given[i]) return ReviewOutcome.incorrect;
    }
    return ReviewOutcome.correct;
  }

  factory ReviewItem.fromJson(Map<String, dynamic> j) => ReviewItem(
    id: j['id'] as String? ?? '',
    prompt: j['prompt'] as String? ?? '',
    options: _strings(j['options']),
    correctIndexes: _ints(j['correctIndexes']),
    selected: _ints(j['selected']),
    explanation: _text(j['explanation']),
    category: _text(j['category']),
  );
}

enum ReviewOutcome { correct, incorrect, skipped }

/// A certificate: the credential number and what it certifies.
class ExamCertificate {
  const ExamCertificate({
    required this.id,
    required this.certificateId,
    required this.title,
    required this.issuedAt,
    this.paperId = '',
    this.certificationCode,
    this.level,
    this.providerName,
    this.providerLogoUrl,
    this.clearedAt,
    this.attempt = 1,
    this.percentage = 0,
    this.passPercentage = 0,
    this.paperSlug,
    this.paperTitle,
    this.holder,
  });

  final String id;

  /// The printed credential number: ICR-CCREA-2026-8ZQ4R1KD.
  final String certificateId;
  final String title;
  final String paperId;
  final String? certificationCode;
  final String? level;

  /// The awarding body when it is not ICR (a copy, frozen at issue).
  final String? providerName;
  final String? providerLogoUrl;
  final DateTime? issuedAt;
  final DateTime? clearedAt;
  final int attempt;
  final int percentage;
  final int passPercentage;
  final String? paperSlug;
  final String? paperTitle;

  /// The holder, on the public verification answer only.
  final String? holder;

  String get awardedBy => providerName ?? 'ICR';
  String? get levelLabel => assessmentLevelLabel(level);

  factory ExamCertificate.fromJson(Map<String, dynamic> j) {
    final paper = j['paper'] as Map<String, dynamic>?;
    final user = j['user'] as Map<String, dynamic>?;
    final holder = user == null ? null : '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
    return ExamCertificate(
      id: j['id'] as String? ?? '',
      certificateId: j['certificateId'] as String? ?? '',
      title: j['title'] as String? ?? '',
      paperId: j['paperId'] as String? ?? '',
      certificationCode: _text(j['certificationCode']),
      level: _text(j['level']),
      providerName: _text(j['providerName']),
      providerLogoUrl: _text(j['providerLogoUrl']),
      issuedAt: _date(j['issuedAt']),
      clearedAt: _date(j['clearedAt']) ?? _date(j['issuedAt']),
      attempt: _int(j['attempt'], 1),
      percentage: _int(j['percentage']),
      passPercentage: _int(j['passPercentage']),
      paperSlug: _text(paper?['slug']),
      paperTitle: _text(paper?['title']),
      holder: (holder == null || holder.isEmpty) ? null : holder,
    );
  }
}

/// What `POST /learning/papers/:slug/attempts` and `GET /learning/me/attempts/:id` answer.
class AttemptResult {
  const AttemptResult({required this.attempt, required this.review, this.certificate});

  final Attempt attempt;
  final ExamCertificate? certificate;
  final List<ReviewItem> review;

  /// Questions the attempt counted that the review no longer has (deleted since).
  int get missing => (attempt.totalQuestions - review.length).clamp(0, attempt.totalQuestions);

  factory AttemptResult.fromJson(Map<String, dynamic> j) => AttemptResult(
    attempt: Attempt.fromJson(j['attempt'] as Map<String, dynamic>? ?? const {}),
    certificate: j['certificate'] is Map<String, dynamic>
        ? ExamCertificate.fromJson(j['certificate'] as Map<String, dynamic>)
        : null,
    review: [for (final r in (j['review'] as List? ?? const []).cast<Map<String, dynamic>>()) ReviewItem.fromJson(r)],
  );
}
