import 'dart:math' as math;

import '../../core/api/api_error.dart';
import '../feed/feed_models.dart' show FeedPicture;

/// What a Resource Center shelf holds (`LearningResourceKind`): question cards read by flipping them, formulas
/// read as a reference. The two doors of the Learning hub, Flash Cards and Knowledge Center, are the two kinds.
enum StudyKind {
  qna,
  formula;

  static StudyKind fromApi(String? value) => value == 'FORMULA' ? StudyKind.formula : StudyKind.qna;
}

/// The Assess your knowledge course a flash-card deck belongs with (`LearningResourceTopic.courseId`, and the
/// `course` the API sends beside it): the deck opens whenever the course does.
class StudyCourseRef {
  const StudyCourseRef({required this.id, required this.code, required this.title});

  final String id;

  /// The programme's code (`CP`): what its page on the website, and in the app, is found by.
  final String code;
  final String title;

  static StudyCourseRef? fromApi(Object? json) {
    if (json is! Map) return null;
    final id = json['id'] as String?;
    if (id == null || id.isEmpty) return null;
    return StudyCourseRef(
      id: id,
      code: (json['code'] as String? ?? '').trim(),
      title: (json['title'] as String? ?? '').trim(),
    );
  }
}

/// A shelf: a flash-card deck, or a Knowledge Center formula group (`GET /learning/resources`). The list carries
/// no cards, only [cardCount]; a deck's own call (`/resources/:slug`) fills [cards].
///
/// A deck may belong with an Assess your knowledge course ([courseId], [course]; owner's call, 27 Oct 2026: a course
/// and its flash cards are one thing). It is then open exactly when the course is, and takes none of the plan's
/// deck places. The production API before that change sends neither, and every deck is on its own.
class StudyTopic {
  const StudyTopic({
    required this.id,
    required this.slug,
    required this.title,
    this.description,
    this.kind = StudyKind.qna,
    this.cover,
    this.cardCount = 0,
    this.sortOrder = 0,
    this.cards = const [],
    this.courseId,
    this.course,
  });

  final String id;
  final String slug;
  final String title;
  final String? description;
  final StudyKind kind;
  final FeedPicture? cover;
  final int cardCount;
  final int sortOrder;
  final List<StudyCard> cards;

  /// The Assess your knowledge course this deck belongs with, when staff linked one.
  final String? courseId;
  final StudyCourseRef? course;

  bool get isDeck => kind == StudyKind.qna;

  /// Opens with a course instead of taking one of the plan's deck places.
  bool get linked => courseId != null && courseId!.isNotEmpty;

  StudyTopic withCards(List<StudyCard> next) => StudyTopic(
    id: id,
    slug: slug,
    title: title,
    description: description,
    kind: kind,
    cover: cover,
    cardCount: next.length,
    sortOrder: sortOrder,
    cards: next,
    courseId: courseId,
    course: course,
  );
}

/// One card: a term or question on the [front], its explanation on the [back]. A formula card keeps its
/// expression (LaTeX between `$$`) and an optional note on how to read it in [back], and its worked examples
/// in [examples].
class StudyCard {
  const StudyCard({
    required this.id,
    required this.front,
    required this.back,
    this.topicId,
    this.topicTitle,
    this.topicSlug,
    this.example,
    this.examples = const [],
    this.resourceUrl,
    this.resourceLabel,
    this.category,
    this.tags = const [],
  });

  final String id;
  final String front;
  final String back;

  /// The shelf it sits on. Always set for the member's starred cards, which come from many decks.
  final String? topicId;
  final String? topicTitle;
  final String? topicSlug;

  /// Free-text worked example (formulas written before examples had parts, and any card an editor filled in).
  final String? example;
  final List<FormulaExample> examples;
  final String? resourceUrl;
  final String? resourceLabel;

  /// The filter chips inside a deck ("Strategy & Fundamentals").
  final String? category;

  /// A deck's difficulty tag ("Beginner") and the like.
  final List<String> tags;
}

/// One figure an example starts from: "Discount Rate" / "10%".
class FormulaGiven {
  const FormulaGiven(this.label, this.value);

  final String label;
  final String value;
}

/// A formula's worked example in parts (`FormulaExampleDto`): the figures it starts from, the working, the answer,
/// then the analysis and the decision it leads to.
class FormulaExample {
  const FormulaExample({this.given = const [], this.working, this.result, this.analysis, this.decision});

  final List<FormulaGiven> given;
  final String? working;
  final String? result;
  final String? analysis;
  final String? decision;

  bool get hasContent =>
      given.any((g) => g.label.trim().isNotEmpty || g.value.trim().isNotEmpty) ||
      [working, result, analysis, decision].any((s) => (s ?? '').trim().isNotEmpty);
}

/// Where a deck stands against the plan's number of decks, as the website's `slotState`: [open] (counted and within
/// the number), [free] (not counted, with a place to spare: opening it takes one) or [locked].
enum DeckState { open, free, locked }

/// What the member's plan opens of the flash-card decks and of the Assess your knowledge courses they may belong
/// with (`GET /learning/me/paper-unlocks`: `plan.flashCardDecks`, `plan.assessmentCourses`, `unlockedCourseIds`).
///
/// The same number opens courses and decks (`learning.assessmentCourses`). A deck on its own takes one of its
/// places when first opened; a deck that belongs with a course is open exactly when the course is: opened with one
/// of the plan's places, or any of its levels redeemed with ICR credits or bought ([unlockedCourseIds]).
class DeckPlan {
  const DeckPlan({
    this.limit,
    this.opened = const [],
    this.allOpen = false,
    this.upgradePlan,
    this.openedCourseIds = const [],
    this.unlockedCourseIds = const [],
  });

  /// How many decks (and courses) open; null when the plan has no number (every deck opens).
  final int? limit;

  /// The decks the member has opened, oldest first: the oldest [limit] are the open ones.
  final List<String> opened;

  /// Staff, and plans with no number at all, are never held to it.
  final bool allOpen;

  /// The plan that opens more, for the "See plan" wording.
  final String? upgradePlan;

  /// The courses the member opened with the plan's places, oldest first: the oldest [limit] are the open ones.
  final List<String> openedCourseIds;

  /// The courses of which the member holds a level (redeemed with ICR credits, bought, or unlocked before).
  final List<String> unlockedCourseIds;

  bool get unlimited => allOpen || limit == null;

  /// How many of the decks in [alone] (decks that take a place of their own) hold one of the plan's places.
  int usedBy(Iterable<StudyTopic> alone) {
    final held = opened.where((id) => alone.any((d) => d.id == id)).length;
    final cap = limit;
    return cap == null ? held : math.min(held, cap);
  }

  /// Every opened deck counted, whether or not it belongs with a course: what the plan alone says.
  int get used => limit == null ? opened.length : math.min(opened.length, limit!);

  /// Whether the course is open to the member: staff and plans with no number, a plan place among the oldest
  /// [limit], or a level of it held on its own.
  bool courseOpen(String courseId) {
    if (unlimited) return true;
    if (unlockedCourseIds.contains(courseId)) return true;
    final at = openedCourseIds.indexOf(courseId);
    return at != -1 && at < limit!;
  }

  DeckState stateOf(String deckId) {
    final cap = limit;
    if (unlimited || cap == null) return DeckState.open;
    final at = opened.indexOf(deckId);
    if (at != -1) return at < cap ? DeckState.open : DeckState.locked;
    return opened.length < cap ? DeckState.free : DeckState.locked;
  }

  /// Where a deck stands: a deck that belongs with a course, by the course (it is never [DeckState.free]: opening
  /// it opens nothing, the course does); a deck on its own, by the plan's number of decks.
  DeckState stateFor(StudyTopic deck) {
    if (deck.linked) return courseOpen(deck.courseId!) ? DeckState.open : DeckState.locked;
    return stateOf(deck.id);
  }

  /// The line over the decks (the website's `LearningPlanNote`), or null when the plan opens them all. [alone]
  /// are the decks that take a place of their own: a deck that belongs with a course takes none ([anyLinked] says
  /// there are some, and the line then adds how they open). When every deck belongs with a course the plan's number
  /// of decks says nothing, so there is no line.
  String? noteFor(Iterable<StudyTopic> alone, {bool anyLinked = false}) {
    if (unlimited) return null;
    if (anyLinked && alone.isEmpty) return null;
    final cap = limit!;
    final base = cap == 0
        ? 'Flash cards are not included in your plan.'
        : 'Your plan opens $cap flash-card ${cap == 1 ? 'deck' : 'decks'} (${usedBy(alone)} used).';
    return anyLinked ? '$base A deck that goes with an Assess your knowledge course opens with that course.' : base;
  }

  /// The line when no deck is known to belong with a course (the production API before the link existed): every
  /// opened deck counts.
  String? get note => unlimited
      ? null
      : (limit == 0
            ? 'Flash cards are not included in your plan.'
            : 'Your plan opens $limit flash-card ${limit == 1 ? 'deck' : 'decks'} ($used used).');
}

/// The API refused a deck: the member's plan does not open it (`403 DECK_LOCKED`). [message] is the API's own
/// sentence, [pricingSlug] the plans page to send them to (`/pricing/<slug>`). A deck that belongs with a course
/// names it ([course], and `opens` in the payload), so the screen can offer what opens it: the plan while it has
/// a place, ICR credits or payment for one of its levels.
class DeckLocked extends ApiError {
  DeckLocked(super.message, {this.pricingSlug = 'professional', this.plan, this.reason, this.course, this.placesLeft})
    : super(statusCode: 403, code: 'DECK_LOCKED');

  final String pricingSlug;
  final String? plan;

  /// `SIGN_IN`, `DECKS` (a deck on its own), `PICK` (its course is closed, the plan has a place left), `COURSES`
  /// (its course is closed and the plan has none left)...
  final String? reason;

  /// The course the deck opens with; null for a deck on its own.
  final StudyCourseRef? course;

  /// How many of the plan's places are still free (`PICK`).
  final int? placesLeft;

  bool get opensWithCourse => course != null;
}
