import '../feed/feed_models.dart';
import '../learning_assess/assess_models.dart';
import '../learning_study/study_models.dart';

/// How a member came to hold something: a place on their plan (a whole course, exam or deck), ICR credits (a
/// level or set), or buying it.
enum OpenedVia { plan, credits, bought }

/// What an opened item is: an Assess your knowledge course (or one of its levels), a mock exam (or one of its
/// sets), or a flash-card deck.
enum OpenedKind { course, mock, deck }

/// A course, mock exam or deck a member holds outside an enrolment (the website's `OpenedLearningItem`): the whole
/// programme or subject opened with a plan place, a single level or set redeemed with ICR credits or bought on its
/// own, or a deck that came with a course or took a deck place on the plan.
class OpenedItem {
  const OpenedItem({this.group, this.paper, this.deck, required this.via})
    : assert(group != null || deck != null, 'a course, a mock exam or a deck');

  final PaperGroup? group;

  /// A single level or set held on its own; null when the whole course or exam is open.
  final AssessPaper? paper;
  final StudyTopic? deck;
  final OpenedVia via;

  OpenedKind get kind => deck != null
      ? OpenedKind.deck
      : group!.kind == PaperKind.mock
      ? OpenedKind.mock
      : OpenedKind.course;

  String get key => deck != null
      ? 'deck:${deck!.id}'
      : paper == null
      ? '${group!.kind.name}:${group!.id}'
      : 'paper:${paper!.id}';

  /// The tile's name: the course's, as in the catalogue; a level or set held on its own is named after it
  /// ("AEE CBCP · Set 1"); a deck its own.
  String get title => deck != null
      ? deck!.title
      : paper == null
      ? group!.title
      : '${group!.title} · ${paper!.title}';

  /// The catalogue tile's photo: the course's or exam's, else the paper's own, else a level's; the deck's own;
  /// null with none.
  FeedPicture? get cover => deck != null
      ? deck!.cover
      : group!.cover ?? paper?.cover ?? group!.papers.map((p) => p.cover).whereType<FeedPicture>().firstOrNull;
}

/// One of the My courses shelves of opened learning: Mock Exams, Assess Your Knowledge, or Flash Cards.
class OpenedShelf {
  const OpenedShelf({required this.kind, required this.title, required this.items});

  final OpenedKind kind;
  final String title;
  final List<OpenedItem> items;
}

/// What a member holds outside an enrolment, as the website's `useOpenedLearning` reads it: the Assess Your
/// Knowledge courses and mock exams they opened with a place on their plan, the single levels or sets they
/// redeemed ICR credits for or bought, and the flash-card decks that came with either (a deck linked to a course
/// opens with it) or took a deck place on their plan. Whole courses and exams a plan opened are listed only while
/// the plan counts them — a plan that opens everything would list the catalogue — but what the member bought or
/// redeemed is their own whatever their plan, unless its whole course or exam is open anyway.
List<OpenedItem> openedLearning({
  required MemberAccess? access,
  required List<PaperGroup> courses,
  required List<PaperGroup> mocks,
  List<StudyTopic> decks = const [],
}) {
  if (access == null) return const [];
  final out = <OpenedItem>[];
  final openGroups = <String>{};
  if (!access.allOpen) {
    for (final (kind, groups) in [(PaperKind.assessment, courses), (PaperKind.mock, mocks)]) {
      final places = access.places(kind);
      // Oldest first: the first `limit` opened are the open ones.
      final open = places.limit == null ? places.opened : places.opened.take(places.limit!);
      for (final id in open) {
        final group = groups.where((g) => g.id == id).firstOrNull;
        if (group == null) continue;
        openGroups.add(id);
        out.add(OpenedItem(group: group, via: OpenedVia.plan));
      }
    }
  }
  for (final group in [...courses, ...mocks]) {
    if (openGroups.contains(group.id)) continue;
    for (final paper in group.papers) {
      if (!access.paperIds.contains(paper.id)) continue;
      out.add(
        OpenedItem(
          group: group,
          paper: paper,
          via: access.creditPaperIds.contains(paper.id) ? OpenedVia.credits : OpenedVia.bought,
        ),
      );
    }
  }
  // A deck: with a plan deck place, with its course when the course is open on the plan, or held for good with a
  // course a level of which was redeemed or bought (the same rule that opens a deck, so nothing listed is closed).
  final onPlanDecks = access.allOpen ? const <String>[] : access.decks.opened;
  for (final deck in decks) {
    if (deck.kind != StudyKind.qna) continue;
    final courseId = deck.courseId;
    final onPlan = onPlanDecks.contains(deck.id) || (courseId != null && openGroups.contains(courseId));
    final held = courseId != null && access.unlockedCourseIds.contains(courseId);
    if (!onPlan && !held) continue;
    final withCredits = courses.any(
      (c) => c.id == courseId && c.papers.any((p) => access.creditPaperIds.contains(p.id)),
    );
    out.add(
      OpenedItem(
        deck: deck,
        via: onPlan
            ? OpenedVia.plan
            : withCredits
            ? OpenedVia.credits
            : OpenedVia.bought,
      ),
    );
  }
  return out;
}

/// The website's shelves of opened learning on My courses, in its order: Mock Exams, Assess Your Knowledge, then
/// Flash Cards; a shelf with nothing is left out.
List<OpenedShelf> openedShelvesOf(List<OpenedItem> items) => [
  for (final (kind, title) in [
    (OpenedKind.mock, 'Mock Exams'),
    (OpenedKind.course, 'Assess Your Knowledge'),
    (OpenedKind.deck, 'Flash Cards'),
  ])
    if (items.any((i) => i.kind == kind))
      OpenedShelf(kind: kind, title: title, items: items.where((i) => i.kind == kind).toList()),
];
