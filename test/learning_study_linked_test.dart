import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/learning_assess/group_screen.dart';
import 'package:icr_mobile/features/learning_study/deck_study_screen.dart';
import 'package:icr_mobile/features/learning_study/flash_cards_screen.dart';
import 'package:icr_mobile/features/learning_study/open_course.dart';
import 'package:icr_mobile/features/learning_study/study_models.dart';

import 'helpers/assess_fixtures.dart';
import 'helpers/fonts.dart';
import 'learning_study_fakes.dart';

/// A flash-card deck follows the Assess your knowledge course of the same name (owner's call, 27 Oct 2026): it is
/// open exactly when the course is (a plan place, or any level redeemed with ICR credits or bought) and takes none
/// of the plan's deck places; a deck on its own still counts against the plan's number. The API decides, and the
/// app's marks on the grid are the preview of its answer.
///
/// Ids of the recorded decks (`test/fixtures/learning_study/resources_list.json`).
const _capital = 'cmv6lubc001demyt83o222rgr';
const _collab = 'cmv6lubhu01izmyt8gsor0pwa';
const _comm = 'cmv6lublz01ojmyt8owsfaw1n';

/// What the note under a deck's name says about its course ("Opens with the course"), by deck id; null when the
/// deck has none (it is on its own).
String? courseNote(String deckId) {
  final found = find.byKey(ValueKey('deck-course:$deckId')).evaluate();
  return found.isEmpty ? null : (found.single.widget as Text).data;
}

void main() {
  setUpAll(loadAppFonts);

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: screen));
    await tester.pumpAndSettle();
  }

  FakePortal portalWith(Map<String, dynamic> unlocks, {Set<String> linked = const {'capital-planning', 'communication'}}) =>
      FakePortal()
        ..list = linkedDeckList(linkedSlugs: linked)
        ..unlocks = unlocks;

  group('DeckPlan: where a deck stands', () {
    const cp = StudyTopic(
      id: 'd1',
      slug: 'capital-planning',
      title: 'Capital Planning',
      courseId: 'course-cp',
      course: StudyCourseRef(id: 'course-cp', code: 'CP', title: 'Capital Planning'),
    );
    const alone = StudyTopic(id: 'd2', slug: 'collabaration', title: 'Collabaration');

    test('a deck that goes with a course is open exactly when the course is, never "free"', () {
      expect(const DeckPlan(limit: 3).stateFor(cp), DeckState.locked, reason: 'a place left does not open the deck');
      expect(const DeckPlan(limit: 3, openedCourseIds: ['course-cp']).stateFor(cp), DeckState.open);
      expect(const DeckPlan(limit: 3, unlockedCourseIds: ['course-cp']).stateFor(cp), DeckState.open);
      expect(const DeckPlan(limit: 0, unlockedCourseIds: ['course-cp']).stateFor(cp), DeckState.open, reason: 'bought');
      expect(const DeckPlan(allOpen: true).stateFor(cp), DeckState.open);
      expect(const DeckPlan().stateFor(cp), DeckState.open, reason: 'a plan with no number opens everything');
    });

    test('only the oldest places of the plan count: a course past the number is closed', () {
      const plan = DeckPlan(limit: 1, openedCourseIds: ['course-x', 'course-cp']);
      expect(plan.courseOpen('course-x'), isTrue);
      expect(plan.courseOpen('course-cp'), isFalse, reason: 'the plan dropped to one place');
      expect(const DeckPlan(limit: 1, openedCourseIds: ['course-x', 'course-cp'], unlockedCourseIds: ['course-cp']).courseOpen('course-cp'), isTrue);
    });

    test('a deck on its own keeps the number of decks', () {
      expect(const DeckPlan(limit: 2, opened: ['d2']).stateFor(alone), DeckState.open);
      expect(const DeckPlan(limit: 2).stateFor(alone), DeckState.free);
      expect(const DeckPlan(limit: 1, opened: ['x']).stateFor(alone), DeckState.locked);
      expect(const DeckPlan(limit: 0).stateFor(alone), DeckState.locked);
    });

    test('the line counts only the decks on their own, and adds how the others open', () {
      const plan = DeckPlan(limit: 3, opened: ['d2', 'd1']);
      expect(plan.noteFor([alone], anyLinked: true), startsWith('Your plan opens 3 flash-card decks (1 used).'));
      expect(plan.noteFor([alone], anyLinked: true), endsWith('opens with that course.'));
      expect(plan.noteFor([alone]), 'Your plan opens 3 flash-card decks (1 used).');
      expect(plan.noteFor(const [], anyLinked: true), isNull, reason: 'every deck goes with a course: no number to tell');
      expect(const DeckPlan(limit: 0).noteFor([alone]), 'Flash cards are not included in your plan.');
      expect(const DeckPlan(allOpen: true).noteFor([alone]), isNull);
    });
  });

  group('the API as the app reads it', () {
    test('a deck carries the course it belongs with; one on its own carries none', () async {
      final topics = await repoOn(portalWith(unlocksOf())).topics();
      final cp = topics.firstWhere((t) => t.slug == 'capital-planning');
      expect(cp.linked, isTrue);
      expect(cp.courseId, 'course-cp');
      expect(cp.course?.code, 'CP');
      expect(cp.course?.title, 'Capital Planning');
      expect(topics.firstWhere((t) => t.slug == 'collabaration').linked, isFalse);
    });

    test('the plan carries the courses it opened and the ones of which a level is held', () async {
      final plan = await repoOn(portalWith(unlocksOf(courses: ['course-cp'], unlockedCourses: ['course-comm']))).deckPlan();
      expect(plan!.openedCourseIds, ['course-cp']);
      expect(plan.unlockedCourseIds, ['course-comm']);
      expect(plan.limit, 3);
    });

    test('an older API (no courses in the plan, no course on a deck) reads as every deck on its own', () async {
      final portal = FakePortal(); // the recorded answers: no `unlockedCourseIds`, no `courseId`
      final topics = await repoOn(portal).topics();
      expect(topics.where((t) => t.isDeck).every((t) => !t.linked), isTrue);
      final plan = await repoOn(portal).deckPlan();
      expect(plan!.unlockedCourseIds, isEmpty);
      expect(plan.stateFor(topics.firstWhere((t) => t.slug == 'capital-planning')), DeckState.open);
    });

    test('a refusal that names a course says which, and how many places are free', () async {
      final portal = portalWith(unlocksOf())
        ..lockedByCourse['capital-planning'] = {'id': 'course-cp', 'code': 'CP', 'title': 'Capital Planning'};
      Object? thrown;
      try {
        await repoOn(portal).topic('capital-planning');
      } catch (e) {
        thrown = e;
      }
      expect(thrown, isA<DeckLocked>());
      final lock = thrown! as DeckLocked;
      expect(lock.opensWithCourse, isTrue);
      expect(lock.course?.code, 'CP');
      expect(lock.reason, 'PICK');
      expect(lock.placesLeft, 3);
      expect(lock.message, contains('Capital Planning'));
    });

    test('a refusal of a deck on its own names no course', () async {
      final portal = FakePortal(locked: ['collabaration']);
      Object? thrown;
      try {
        await repoOn(portal).topic('collabaration');
      } catch (e) {
        thrown = e;
      }
      expect((thrown! as DeckLocked).opensWithCourse, isFalse);
    });
  });

  group('Flash Cards: the grid', () {
    testWidgets('a deck whose course is closed is Locked and names it; a deck on its own keeps the plan\'s number', (
      tester,
    ) async {
      final portal = portalWith(unlocksOf(decks: [_collab]));
      await pump(tester, FlashCardsScreen(onBack: () {}, repository: repoOn(portal)));

      expect(courseNote(_capital), 'Opens with the course');
      expect(courseNote(_comm), 'Opens with the course');
      expect(courseNote(_collab), isNull, reason: 'a deck on its own says nothing of a course');
      expect(find.text('Locked'), findsNWidgets(2));
      // Collabaration (opened on its own) and ESG (a place to spare) are on their own: both read Study.
      expect(find.text('Study'), findsNWidgets(2));
      // The line counts only the decks on their own: 1 of 3 used, and the course decks take no place.
      expect(
        find.text(
          'Your plan opens 3 flash-card decks (1 used). A deck that goes with an Assess your knowledge course opens with that course.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a course opened with a plan place opens its deck, which then says where it comes from', (tester) async {
      final portal = portalWith(unlocksOf(courses: ['course-cp']));
      await pump(tester, FlashCardsScreen(onBack: () {}, repository: repoOn(portal)));
      expect(courseNote(_capital), 'Included in the course');
      expect(courseNote(_comm), 'Opens with the course');
      expect(find.text('Locked'), findsOneWidget);
    });

    testWidgets('a level redeemed with ICR credits (or bought) opens the deck, even on a plan with no decks', (
      tester,
    ) async {
      final portal = portalWith(unlocksOf(limit: 0, unlockedCourses: ['course-comm']));
      await pump(tester, FlashCardsScreen(onBack: () {}, repository: repoOn(portal)));
      expect(courseNote(_comm), 'Included in the course');
      expect(courseNote(_capital), 'Opens with the course');
      // Collabaration and ESG are on their own, on a plan that opens none: locked, as before.
      expect(find.text('Locked'), findsNWidgets(3));
    });

    testWidgets('a deck whose name differs from its course says which course', (tester) async {
      // Collabaration (the deck) goes with the course "Collaboration": the names differ, so the note names it.
      final portal = portalWith(unlocksOf(), linked: {'collabaration'});
      await pump(tester, FlashCardsScreen(onBack: () {}, repository: repoOn(portal)));
      expect(courseNote(_collab), 'Opens with Collaboration');
    });

    testWidgets('a plan with no number draws no line and no lock, linked decks included', (tester) async {
      final portal = portalWith(unlocksOf(limit: null, allOpen: true));
      await pump(tester, FlashCardsScreen(onBack: () {}, repository: repoOn(portal)));
      expect(find.byKey(const ValueKey('study-plan-note')), findsNothing);
      expect(find.text('Locked'), findsNothing);
    });

    testWidgets('when every deck goes with a course there is no line about the plan\'s number of decks', (tester) async {
      final portal = portalWith(
        unlocksOf(),
        linked: {'capital-planning', 'collabaration', 'communication', 'esg-and-sustainability'},
      );
      await pump(tester, FlashCardsScreen(onBack: () {}, repository: repoOn(portal)));
      expect(find.byKey(const ValueKey('study-plan-note')), findsNothing);
      expect(find.text('Locked'), findsNWidgets(4));
    });

    testWidgets('the old API (decks without a course): the grid is as it was', (tester) async {
      await pump(tester, FlashCardsScreen(onBack: () {}, repository: repoOn(FakePortal())));
      expect(find.text('Your plan opens 3 flash-card decks (1 used).'), findsOneWidget);
      expect(find.textContaining('Opens with'), findsNothing);
      expect(find.text('Locked'), findsNothing);
    });

    testWidgets('back in front, the courses that are open are read again and the deck opens at once', (tester) async {
      final portal = portalWith(unlocksOf());
      await pump(tester, FlashCardsScreen(onBack: () {}, repository: repoOn(portal)));
      expect(courseNote(_capital), 'Opens with the course');
      final before = portal.calls.where((c) => c == 'GET /learning/me/paper-unlocks').length;

      // The member paid for a level of Capital Planning in the browser, then came back to the app.
      portal.unlocks = unlocksOf(unlockedCourses: ['course-cp']);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(portal.calls.where((c) => c == 'GET /learning/me/paper-unlocks').length, before + 1);
      expect(courseNote(_capital), 'Included in the course');
    });
  });

  group('Flash Cards: a deck that goes with a closed course', () {
    testWidgets('opening it shows what opens it: the course\'s name, the API\'s sentence and a button to the course', (
      tester,
    ) async {
      final portal = portalWith(unlocksOf())
        ..lockedByCourse['capital-planning'] = {'id': 'course-cp', 'code': 'CP', 'title': 'Capital Planning'};
      await pump(tester, FlashCardsScreen(onBack: () {}, repository: repoOn(portal)));
      await tester.tap(find.text('Capital Planning'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('deck-course-lock')), findsOneWidget);
      expect(find.text('Opens with “Capital Planning”'), findsOneWidget);
      expect(find.textContaining('open the course with your plan'), findsOneWidget, reason: 'the API\'s own sentence');
      expect(find.text('Open Capital Planning'), findsOneWidget);
      expect(find.text('All decks'), findsOneWidget);
      expect(find.text('See plans'), findsNothing, reason: 'the course is the way in, not the plans page');
      expect(find.text("This deck isn't open on your plan"), findsNothing);
    });

    testWidgets('the button opens the course\'s page; coming back, the deck is asked for again and opens', (
      tester,
    ) async {
      final portal = portalWith(unlocksOf())
        ..lockedByCourse['capital-planning'] = {'id': 'course-cp', 'code': 'CP', 'title': 'Capital Planning'};
      final repo = repoOn(portal);
      final deck = (await tester.runAsync(repo.topics))!.firstWhere((t) => t.slug == 'capital-planning');
      final opened = <String>[];
      await pump(
        tester,
        DeckStudyScreen.deck(
          repository: repo,
          deck: deck,
          onOpenCourse: (context, course) async {
            opened.add(course.code);
            // On the course's page the member opens it (a plan place, credits, payment): the deck opens with it.
            portal.lockedByCourse.remove('capital-planning');
          },
        ),
      );
      expect(find.text('Open Capital Planning'), findsOneWidget);

      await tester.tap(find.text('Open Capital Planning'));
      await tester.pumpAndSettle();

      expect(opened, ['CP']);
      expect(find.byKey(const ValueKey('deck-course-lock')), findsNothing);
      expect(find.byKey(const ValueKey('study-position')), findsOneWidget, reason: 'the cards are there');
      expect(portal.calls.where((c) => c == 'GET /learning/resources/capital-planning').length, 2);
    });

    testWidgets('back in front on the lock screen, the deck is asked for again: it opens if its course did', (
      tester,
    ) async {
      final portal = portalWith(unlocksOf())
        ..lockedByCourse['capital-planning'] = {'id': 'course-cp', 'code': 'CP', 'title': 'Capital Planning'};
      final repo = repoOn(portal);
      final deck = (await tester.runAsync(repo.topics))!.firstWhere((t) => t.slug == 'capital-planning');
      await pump(tester, DeckStudyScreen.deck(repository: repo, deck: deck));
      expect(find.byKey(const ValueKey('deck-course-lock')), findsOneWidget);

      portal.lockedByCourse.remove('capital-planning'); // paid in the browser
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('deck-course-lock')), findsNothing);
      expect(find.byKey(const ValueKey('study-position')), findsOneWidget);
    });

    testWidgets('a deck on its own that the plan refuses keeps its old notice and "See plans"', (tester) async {
      final portal = FakePortal(unlocks: 'paper_unlocks_bharat', locked: ['capital-planning'])
        ..lockMessage = 'Flash-card decks are not included in your plan.';
      await pump(tester, FlashCardsScreen(onBack: () {}, repository: repoOn(portal)));
      await tester.tap(find.text('Capital Planning'));
      await tester.pumpAndSettle();
      expect(find.text("This deck isn't open on your plan"), findsOneWidget);
      expect(find.text('See plans'), findsWidgets);
      expect(find.byKey(const ValueKey('deck-course-lock')), findsNothing);
    });
  });

  group('the course\'s page', () {
    testWidgets('opens in the app: the programme the deck goes with, read by its code', (tester) async {
      final assess = FakeAssess();
      late BuildContext at;
      await pump(
        tester,
        Builder(
          builder: (context) {
            at = context;
            return const Scaffold(body: SizedBox());
          },
        ),
      );
      const course = StudyCourseRef(id: 'course-cp', code: 'CP', title: 'Capital Planning');
      final done = openAssessCourse(at, course, repository: assess);
      await tester.pumpAndSettle();

      expect(assess.calls, contains('group:CP'));
      expect(find.byType(GroupScreen), findsOneWidget);
      expect(find.text('Capital Planning'), findsWidgets);

      // Leaving the page completes the future: that is when the caller reads what the member opened.
      Navigator.of(tester.element(find.byType(GroupScreen))).pop();
      await tester.pumpAndSettle();
      await done;
      expect(find.byType(GroupScreen), findsNothing);
    });

    testWidgets('a course that cannot be read says so and opens nothing', (tester) async {
      final assess = FakeAssess();
      late BuildContext at;
      await pump(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) {
              at = context;
              return const SizedBox();
            },
          ),
        ),
      );
      await openAssessCourse(
        at,
        const StudyCourseRef(id: 'course-zz', code: 'ZZ', title: 'Nope'),
        repository: assess,
      );
      await tester.pumpAndSettle();
      expect(find.byType(GroupScreen), findsNothing);
      expect(find.text('Not found'), findsOneWidget);
    });
  });
}
