import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/features/feed/feed_models.dart';
import 'package:icr_mobile/features/learning/demo_learning_repository.dart';
import 'package:icr_mobile/features/learning/learning_controller.dart';
import 'package:icr_mobile/features/learning/learning_screen.dart';
import 'package:icr_mobile/features/learning/opened_learning.dart';
import 'package:icr_mobile/features/learning_assess/assess_models.dart';
import 'package:icr_mobile/features/learning_assess/demo_assess_repository.dart';
import 'package:icr_mobile/features/learning_hub/widgets/learn_card.dart';
import 'package:icr_mobile/features/learning_study/demo_study_repository.dart';
import 'package:icr_mobile/features/learning_study/study_models.dart';
import 'package:provider/provider.dart';

/// My courses lists what the member opened outside an enrolment, as the website's `/learning/courses` does on
/// its Mock Exams and Assess Your Knowledge shelves (owner's report, 2 Nov 2026: a member with open levels and
/// sat mock exams saw "No courses yet").
AssessPaper _paper(String id, String title, {String? courseId, String? topicId, FeedPicture? cover}) => AssessPaper(
  id: id,
  slug: id,
  title: title,
  kind: topicId == null ? PaperKind.assessment : PaperKind.mock,
  courseId: courseId,
  topicId: topicId,
  cover: cover,
);

const _tower = FeedPicture.asset('assets/images/demo/post_green_tower.jpg');

PaperGroup _course(String id, String title, {FeedPicture? cover, List<String> levels = const ['Foundation']}) =>
    PaperGroup(
      kind: PaperKind.assessment,
      id: id,
      key: id,
      title: title,
      cover: cover,
      papers: [for (final l in levels) _paper('$id-${l.toLowerCase()}', l, courseId: id)],
    );

PaperGroup _topic(String id, String title) => PaperGroup(
  kind: PaperKind.mock,
  id: id,
  key: id,
  title: title,
  papers: [
    for (final s in ['Set 1', 'Set 2']) _paper('$id-${s.replaceAll(' ', '').toLowerCase()}', s, topicId: id),
  ],
);

final _courses = [
  _course('c1', 'Capital Planning', cover: _tower, levels: ['Foundation', 'Professional']),
  _course('c2', 'Colloboration'),
  _course('c3', 'Communication'),
];
final _topics = [_topic('t1', 'AEE CBCP'), _topic('t2', 'AEE CEM')];

/// Decks: one with Capital Planning (c1), one with Communication (c3), one of its own, and a formula sheet.
final _decks = [
  const StudyTopic(id: 'd1', slug: 'capital-planning', title: 'Capital Planning cards', courseId: 'c1'),
  const StudyTopic(id: 'd3', slug: 'communication', title: 'Communication cards', courseId: 'c3'),
  const StudyTopic(id: 'd9', slug: 'hvac', title: 'HVAC', cover: _tower),
  const StudyTopic(id: 'f1', slug: 'formulas', title: 'Formulas', kind: StudyKind.formula),
];

/// The sample decks replaced by the ones above.
class _Study extends DemoStudyRepository {
  @override
  Future<List<StudyTopic>> topics() async => _decks;
}

/// The sample assessments with the member's own access put in.
class _Assess extends DemoAssessRepository {
  _Assess(this.access);

  final MemberAccess? access;

  @override
  Future<List<PaperGroup>> groups(PaperKind kind) async => kind == PaperKind.mock ? _topics : _courses;

  @override
  Future<MemberLearning> member(PaperKind kind) async => MemberLearning(access: access);
}

void main() {
  group('openedLearning', () {
    test("a plan's open courses and exams, then the levels and sets held on their own", () {
      const access = MemberAccess(
        courses: PlanPlaces(limit: 2, opened: ['c1', 'c2', 'c3']),
        mocks: PlanPlaces(opened: ['t1']),
        paperIds: {'c3-foundation', 't2-set1', 'c1-professional'},
        creditPaperIds: {'t2-set1'},
      );
      final items = openedLearning(access: access, courses: _courses, mocks: _topics);
      expect(items.map((i) => i.key), [
        'assessment:c1',
        'assessment:c2',
        'mock:t1',
        'paper:c3-foundation',
        'paper:t2-set1',
      ], reason: "c3 is past the plan's two places; c1's bought level is inside an open course");
      expect(items.map((i) => i.via), [
        OpenedVia.plan,
        OpenedVia.plan,
        OpenedVia.plan,
        OpenedVia.bought,
        OpenedVia.credits,
      ]);
      expect(items[3].title, 'Communication · Foundation');
      expect(items[4].title, 'AEE CEM · Set 1');
      expect(items[0].cover, _tower);
      expect(items[1].cover, isNull, reason: 'no artwork anywhere');
    });

    test('a deck comes with its open course, takes a plan deck place, or is held with a bought course', () {
      const access = MemberAccess(
        courses: PlanPlaces(limit: 1, opened: ['c1']),
        decks: PlanPlaces(limit: 1, opened: ['d9']),
        paperIds: {'c3-foundation'},
        creditPaperIds: {'c3-foundation'},
        unlockedCourseIds: {'c3'},
      );
      final items = openedLearning(access: access, courses: _courses, mocks: _topics, decks: _decks);
      expect(items.map((i) => i.key), ['assessment:c1', 'paper:c3-foundation', 'deck:d1', 'deck:d3', 'deck:d9']);
      final decks = {for (final i in items.where((i) => i.kind == OpenedKind.deck)) i.deck!.id: i.via};
      expect(decks, {'d1': OpenedVia.plan, 'd3': OpenedVia.credits, 'd9': OpenedVia.plan});
      expect(items.last.title, 'HVAC');
      expect(items.last.cover, _tower);
      expect(openedShelvesOf(items).map((s) => s.title), ['Assess Your Knowledge', 'Flash Cards']);
      // A formula sheet is never a deck, and a deck with nothing behind it is not listed.
      expect(items.any((i) => i.deck?.id == 'f1'), isFalse);
      final none = openedLearning(access: const MemberAccess(), courses: _courses, mocks: _topics, decks: _decks);
      expect(none, isEmpty);
    });

    test('a plan that opens everything lists only what was bought or redeemed; no access lists nothing', () {
      const access = MemberAccess(
        allOpen: true,
        courses: PlanPlaces(opened: ['c1']),
        paperIds: {'t2-set1'},
        creditPaperIds: {'t2-set1'},
      );
      final items = openedLearning(access: access, courses: _courses, mocks: _topics);
      expect(items.map((i) => i.key), ['paper:t2-set1']);
      expect(openedLearning(access: null, courses: _courses, mocks: _topics), isEmpty);
    });

    test('the shelves: Mock Exams first, then Assess Your Knowledge, and none for an empty kind', () {
      final shelves = openedShelvesOf([
        OpenedItem(group: _courses[0], via: OpenedVia.plan),
        OpenedItem(group: _topics[0], via: OpenedVia.plan),
      ]);
      expect(shelves.map((s) => s.title), ['Mock Exams', 'Assess Your Knowledge']);
      expect(openedShelvesOf([OpenedItem(group: _courses[0], via: OpenedVia.plan)]).map((s) => s.title), [
        'Assess Your Knowledge',
      ]);
    });
  });

  group('My courses', () {
    const access = MemberAccess(
      courses: PlanPlaces(limit: 1, opened: ['c1']),
      mocks: PlanPlaces(limit: 1, opened: ['t1']),
      paperIds: {'t2-set1'},
      creditPaperIds: {'t2-set1'},
    );

    test('the controller reads the shelves as the chip goes on, narrowed by the search', () async {
      final learning = LearningController(DemoLearningRepository(), assess: _Assess(access));
      await learning.start();
      expect(learning.openedShelves, isEmpty, reason: 'the chip is off');
      learning.toggleMine();
      await Future<void>.delayed(Duration.zero);
      expect(learning.openedShelves.map((s) => s.title), ['Mock Exams', 'Assess Your Knowledge']);
      expect(learning.openedShelves.first.items.map((i) => i.title), ['AEE CBCP', 'AEE CEM · Set 1']);
      learning.setSearch('capital');
      expect(learning.openedShelves.map((s) => s.title), ['Assess Your Knowledge']);
      learning.clearSearch();
      learning.toggleMine();
      expect(learning.openedShelves, isEmpty);
    });

    test('with a decks source the Flash Cards shelf follows the other two', () async {
      final learning = LearningController(DemoLearningRepository(), assess: _Assess(access), study: _Study());
      await learning.start();
      learning.toggleMine();
      await Future<void>.delayed(Duration.zero);
      expect(learning.openedShelves.map((s) => s.title), ['Mock Exams', 'Assess Your Knowledge', 'Flash Cards']);
      expect(learning.openedShelves.last.items.map((i) => i.title), ['Capital Planning cards']);
    });

    test('without an assessments source the shelves are left out and the places still show', () async {
      final learning = LearningController(DemoLearningRepository());
      await learning.start();
      learning.toggleMine();
      await Future<void>.delayed(Duration.zero);
      expect(learning.openedShelves, isEmpty);
    });

    testWidgets('the shelves draw the opened courses and exams as the hub\'s cards, credits badged', (tester) async {
      tester.view.physicalSize = const Size(780, 1688);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final learning = LearningController(DemoLearningRepository(), assess: _Assess(access));
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<LearningController>.value(
            value: learning,
            child: LearningScreen(onBack: () {}, title: 'ICR Courses'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('My courses'));
      await tester.pumpAndSettle();
      expect(find.text('Mock Exams'), findsOneWidget);
      expect(find.text('Assess Your Knowledge'), findsOneWidget);
      expect(find.byKey(const ValueKey('opened-mock:t1')), findsOneWidget);
      expect(find.byKey(const ValueKey('opened-paper:t2-set1')), findsOneWidget);
      expect(find.byKey(const ValueKey('opened-assessment:c1')), findsOneWidget);
      expect(find.text('AEE CEM · Set 1'), findsOneWidget);
      expect(find.text('Credits'), findsOneWidget, reason: 'only a place redeemed with credits is badged');
      expect(find.byType(LearnCard), findsNWidgets(3));
      expect(find.text('No courses yet'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
