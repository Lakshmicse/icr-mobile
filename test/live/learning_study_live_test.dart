/// Flash Cards and the Knowledge Center against the LOCAL portal API. Run with the API up:
/// `flutter test test/live/learning_study_live_test.dart`.
///
/// The people:
///  * Bharat Buyer (the emulator's person) and Pooja Professional hold plans that open **no** flash-card decks, so
///    for them every deck is Locked and the API refuses a deck, and a star, with its own sentence: that refusal is
///    what the lock tests prove.
///  * `study.cards@learning-study.icr.test` (`tool/seed/learning-study.ts`) holds three places, so it can study.
///    Run the seed first; without it the tests that need it skip with that reason.
///
/// What a test writes it undoes where the API allows: a star it gives is taken back. One thing the API cannot
/// take back is a place: opening a deck as the study persona takes one of its three for good (an opened deck
/// stays opened). The tests only ever open the persona's first three decks, and re-opening one takes nothing, so
/// they can run again and again; `learning-study.ts --remove` forgets them.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/learning_study/api_study_repository.dart';
import 'package:icr_mobile/features/learning_study/deck_study_screen.dart';
import 'package:icr_mobile/features/learning_study/decks_controller.dart';
import 'package:icr_mobile/features/learning_study/flash_cards_screen.dart';
import 'package:icr_mobile/features/learning_study/knowledge_center_screen.dart';
import 'package:icr_mobile/features/learning_study/knowledge_controller.dart';
import 'package:icr_mobile/features/learning_study/study_controller.dart';
import 'package:icr_mobile/features/learning_study/study_format.dart';
import 'package:icr_mobile/features/learning_study/study_models.dart';
import 'package:icr_mobile/features/learning_study/study_repository.dart';
import 'package:icr_mobile/features/learning_study/widgets/formula_math.dart';

import '../helpers/fonts.dart';
import 'live.dart';

/// Three flash-card places, from `tool/seed/learning-study.ts`.
const _study = LivePerson('study.cards@learning-study.icr.test', 'Study@12345', 'Study Persona');

const _locked = 'Flash-card decks are not included in your plan.';

/// A repository signed in as [who]; null (and the test skips) when that person does not exist yet.
Future<ApiStudyRepository?> _repoFor(LivePerson who) async {
  try {
    return ApiStudyRepository(api: await liveClient(who));
  } on DioException catch (e) {
    if (who == _study && (e.response?.statusCode == 401 || e.response?.statusCode == 400)) {
      markTestSkipped('run tool/seed/learning-study.ts first: ${_study.email} does not exist');
      return null;
    }
    rethrow;
  }
}

/// The decks as the grid orders them (A to Z).
Future<List<StudyTopic>> _decksOf(StudyRepository repo) async {
  final decks = (await repo.topics()).where((t) => t.isDeck).toList()
    ..sort((a, b) {
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      return byOrder != 0 ? byOrder : a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
  return decks;
}

/// What the persona's three places open. The decks go with Assess your knowledge courses (27 Oct 2026), so a place
/// opens a COURSE (`POST /learning/me/opens`, which the course's own page does) and the decks of that course open
/// with it. Opens the courses of the first linked decks, in the grid's order, until the plan's number of courses is
/// open; a course that is open already takes nothing, so this can run again and again (`learning-study.ts --remove`
/// forgets the places). Returns the plan, the decks that are open and the ones that are not.
Future<({DeckPlan plan, List<StudyTopic> open, List<StudyTopic> shut})> _fillPlaces(ApiStudyRepository repo) async {
  final decks = (await _decksOf(repo)).where((d) => d.linked).toList();
  var plan = (await repo.deckPlan())!;
  for (final deck in decks) {
    if (plan.openedCourseIds.length >= (plan.limit ?? 3)) break;
    if (plan.courseOpen(deck.courseId!)) continue;
    await repo.api.dio.post<dynamic>('/learning/me/opens', data: {'target': 'COURSE', 'targetId': deck.courseId});
    plan = (await repo.deckPlan())!;
  }
  return (
    plan: plan,
    open: [for (final d in decks) if (plan.stateFor(d) == DeckState.open) d],
    shut: [for (final d in decks) if (plan.stateFor(d) == DeckState.locked) d],
  );
}

/// The real answers, read once, handed back as they were: a widget test cannot wait on the network inside its
/// fake clock, so the screens are given what the live API said. A star is the exception: it goes to the API.
class _Snapshot implements StudyRepository {
  _Snapshot._(this.live, this._topics, this._shelves, this._plan, this._starred, this._unread);

  static Future<_Snapshot> take(StudyRepository live, {Iterable<String> shelves = const []}) async {
    // A visitor has no stars to read (the API says Unauthorized); that is an empty list here.
    Future<List<StudyCard>> stars() async {
      try {
        return await live.starredCards();
      } catch (_) {
        return const [];
      }
    }

    return _Snapshot._(
      live,
      await live.topics(),
      {for (final slug in shelves) slug: await live.topic(slug)},
      await live.deckPlan(),
      await stars(),
      await live.unreadNotifications(),
    );
  }

  final StudyRepository live;
  final List<StudyTopic> _topics;
  final Map<String, StudyTopic> _shelves;
  final DeckPlan? _plan;
  final List<StudyCard> _starred;
  final int _unread;

  @override
  Future<List<StudyTopic>> topics() async => _topics;
  @override
  Future<StudyTopic> topic(String slug) async => _shelves[slug] ?? await live.topic(slug);
  @override
  Future<DeckPlan?> deckPlan() async => _plan;
  @override
  Future<List<StudyCard>> starredCards() async => _starred;
  @override
  Future<void> setStar(String cardId, bool starred) => live.setStar(cardId, starred);
  @override
  Future<int> unreadNotifications() async => _unread;
  @override
  Uri plansLink([String slug = 'professional']) => live.plansLink(slug);
}

/// A live test that draws a screen: skipped, with a reason, when the API is not running. Real network calls inside
/// it go through `tester.runAsync`.
void liveWidgetTest(String description, Future<void> Function(WidgetTester tester) body) {
  testWidgets(
    description,
    (tester) async {
      if (await tester.runAsync(liveApiReachable) != true) {
        markTestSkipped('the local API is not running at $liveBaseUrl');
        return;
      }
      await body(tester);
    },
    tags: const ['live'],
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

/// A tap whose handler talks to the network: it runs outside the test's fake clock.
Future<void> _tapOnline(WidgetTester tester, Finder finder) async {
  await tester.runAsync(() => tester.tap(finder));
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _show(WidgetTester tester, Widget home, {Size physical = const Size(780, 1688)}) async {
  tester.view.physicalSize = physical;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, theme: buildAppTheme(), home: home));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  group('the shelves are public', () {
    liveTest('the decks and the formula groups list with their covers, counts and trimmed names', () async {
      final repo = ApiStudyRepository(api: liveAnonymous());
      final topics = await repo.topics();
      final decks = topics.where((t) => t.isDeck).toList();
      final groups = topics.where((t) => !t.isDeck).toList();
      expect(decks.length, greaterThanOrEqualTo(30), reason: 'the local database holds 31 decks');
      expect(groups.length, greaterThanOrEqualTo(4), reason: 'and four formula groups');
      expect(topics.every((t) => t.cardCount > 0), isTrue, reason: 'the API drops empty shelves');
      expect(topics.every((t) => t.title == t.title.trim() && t.title.isNotEmpty), isTrue);
      expect(groups.map((g) => g.title), contains('Time Value of Money'));
      expect(
        groups.map((g) => g.title),
        contains('Corporate Real Estate (CRE)'),
        reason: 'stored with a trailing space',
      );

      final withCover = decks.firstWhere((d) => d.cover != null);
      final cover = await Dio().get<List<int>>(
        withCover.cover!.url!,
        options: Options(responseType: ResponseType.bytes),
      );
      expect(cover.statusCode, 200, reason: 'a cover URL is a real picture');
    });

    liveTest('a deck read without signing in is refused with "Sign in to open ..." and the plans page', () async {
      final repo = ApiStudyRepository(api: liveAnonymous());
      final deck = (await _decksOf(repo)).first;
      await expectLater(
        repo.topic(deck.slug),
        throwsA(
          isA<DeckLocked>()
              .having((e) => e.message, 'message', startsWith('Sign in to open'))
              .having((e) => e.reason, 'reason', 'SIGN_IN')
              .having((e) => e.pricingSlug, 'pricingSlug', 'professional'),
        ),
      );
    });
  });

  group('the Knowledge Center', () {
    liveTest('every formula of every group is drawn as math, reads as plain text and is found by its name', () async {
      final repo = ApiStudyRepository(api: liveAnonymous());
      final listed = (await repo.topics()).where((t) => !t.isDeck).fold<int>(0, (sum, t) => sum + t.cardCount);
      final c = KnowledgeController(repo);
      await c.start();
      expect(c.hasFailures, isFalse);
      expect(c.error, isNull);
      expect(c.totalFormulas, listed, reason: 'every card the list counts is on a group');
      expect(c.totalFormulas, greaterThanOrEqualTo(80));

      var drawn = 0;
      for (final shelf in c.shelves) {
        for (final card in shelf.cards) {
          final expression = parseExpression(splitBack(card.back).expression);
          expect(card.front, isNotEmpty);
          expect(plainFormula(expression), isNotEmpty, reason: '${shelf.topic.title}: ${card.front}');
          if (expression.isTex) {
            expect(FormulaMath.parse(expression.tex!), isNotNull, reason: '${shelf.topic.title}: ${card.front}');
            drawn++;
          }
        }
      }
      expect(drawn, c.totalFormulas, reason: 'the seeded formulas are all LaTeX');

      c.setSearch('present value');
      expect(c.sections.expand((s) => s.rows).map((r) => r.card.front), contains('Present Value (PV)'));
      c.setSearch('11.66');
      expect(
        c.sections.expand((s) => s.rows).map((r) => r.card.front),
        contains('Present Value (PV)'),
        reason: 'by its worked numbers',
      );
    });

    liveTest(
      'Present Value has its four variables and two worked examples with figures, answer and decision',
      () async {
        final c = KnowledgeController(ApiStudyRepository(api: liveAnonymous()));
        await c.start();
        final pv = c.shelves.expand((s) => s.cards).firstWhere((card) => card.front == 'Present Value (PV)');
        final parts = splitBack(pv.back);
        expect(parseVariables(parts.note)!.map((v) => v.symbol), ['PV', 'FV', 'r', 'n']);
        final examples = examplesOf(pv).parts;
        expect(examples, hasLength(2));
        expect(examples.first.given.first.label, 'Future Building Value');
        expect(examples.first.result, 'PV = ₹11.66 Crores');
        expect(examples.first.decision, isNotEmpty);
        expect(formulaCopyText(pv), startsWith('Present Value (PV)\nPV = FV ÷ (1+r)^n\nPV = Present Value'));
      },
    );

    liveWidgetTest(
      'the screen lists the real groups; a formula opens its sheet with the math drawn and its variables',
      (tester) async {
        final live = ApiStudyRepository(api: liveAnonymous());
        final snapshot = (await tester.runAsync(() async {
          final all = await live.topics();
          return _Snapshot.take(
            live,
            shelves: [
              for (final t in all)
                if (!t.isDeck) t.slug,
            ],
          );
        }))!;
        await _show(tester, KnowledgeCenterScreen(onBack: () {}, repository: snapshot));
        expect(find.text('Corporate Real Estate (CRE)'), findsOneWidget);
        expect(find.textContaining('formulas'), findsWidgets);

        await tester.enterText(find.byType(TextField), 'present value (pv)');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Present Value (PV)'));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('formula-math')), findsOneWidget);
        expect(find.byKey(const ValueKey('formula-plain')), findsNothing);
        expect(find.text('Discount Rate'), findsWidgets, reason: 'a variable and a figure of the example');
        expect(find.text('Worked example 1'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('the plan locks decks', () {
    liveTest(
      'a plan with no deck places marks every deck Locked and the API refuses a deck and a star with its own sentence',
      () async {
        final repo = await _repoFor(bharat);
        final decks = DecksController(repo!);
        await decks.start();
        if (decks.plan?.limit != 0) {
          markTestSkipped(
            'Bharat has been given deck places (learning-study.ts --grant-bharat): this proves the plan with none',
          );
          return;
        }
        expect(decks.planNote, 'Flash cards are not included in your plan.');
        expect(decks.decks.every((d) => decks.stateOf(d) == DeckState.locked), isTrue);

        await expectLater(
          repo.topic(decks.decks.first.slug),
          throwsA(
            isA<DeckLocked>()
                .having((e) => e.message, 'message', _locked)
                .having((e) => e.pricingSlug, 'pricingSlug', 'professional')
                .having((e) => e.statusCode, 'statusCode', 403),
          ),
        );

        // A card of a deck the persona may open: starring it is held to the same plan rule.
        final study = await _repoFor(_study);
        if (study == null) return;
        final deck = (await _fillPlaces(study)).open.first;
        final card = (await study.topic(deck.slug)).cards.first;
        await expectLater(
          repo.setStar(card.id, true),
          throwsA(isA<DeckLocked>().having((e) => e.message, 'message', _locked)),
        );
        expect(await repo.starredCards(), isEmpty, reason: 'the refused star was not kept');
      },
    );

    liveTest(
      'with three places the decks of the first three courses open and the next is refused naming its course; a deck read again takes no place',
      () async {
        final repo = await _repoFor(_study);
        if (repo == null) return;
        final filled = await _fillPlaces(repo);
        var plan = filled.plan;
        expect(plan.limit, 3);
        expect(plan.openedCourseIds, hasLength(3));
        expect(filled.open, isNotEmpty);
        expect(filled.shut, isNotEmpty, reason: 'more courses than places');

        for (final deck in filled.open.take(3)) {
          final full = await repo.topic(deck.slug);
          expect(full.cards, isNotEmpty);
          expect(full.cards.length, deck.cardCount, reason: 'the list counted what the deck holds');
        }
        plan = (await repo.deckPlan())!;
        expect(plan.openedCourseIds, hasLength(3), reason: 'reading a deck takes no place: the course holds it');

        final shut = filled.shut.first;
        await expectLater(
          repo.topic(shut.slug),
          throwsA(
            isA<DeckLocked>()
                .having((e) => e.reason, 'reason', 'COURSES')
                .having((e) => e.course?.code, 'course', shut.course?.code)
                .having((e) => e.message, 'message', contains('you have opened them all')),
          ),
        );
        expect((await repo.deckPlan())!.openedCourseIds, hasLength(3), reason: 'a refusal takes none');

        final grid = DecksController(repo);
        await grid.start();
        expect(grid.stateOf(shut), DeckState.locked);
        expect(grid.stateOf(filled.open.first), DeckState.open);
      },
    );
  });

  group('studying a deck', () {
    liveTest(
      'a pass over a real deck: the category chips, shuffle, marks, the summary and a second pass over the rest',
      () async {
        final repo = await _repoFor(_study);
        if (repo == null) return;
        final deck = (await _fillPlaces(repo)).open.first;
        final c = DeckStudyController.deck(repo, deck);
        await c.load();
        expect(c.loaded, isTrue);
        expect(c.total, deck.cardCount);
        expect(c.categories.length, greaterThanOrEqualTo(2));
        expect(
          c.categories.fold<int>(0, (s, e) => s + e.count),
          c.allCards.length,
          reason: 'every card has a category',
        );

        final first = c.categories.first;
        c.setCategory(first.name);
        expect(c.total, first.count);
        expect(c.visible.every((card) => card.category == first.name), isTrue);
        c.setCategory(null);

        c.toggleShuffle();
        expect({for (final card in c.visible) card.id}.length, c.total);
        c.toggleShuffle();
        expect(c.current!.id, c.allCards.first.id);

        // Mark a short category: known, learning, unmarked; then the summary and the second pass.
        c.setCategory(first.name);
        c.mark(known: true);
        c.mark(known: false);
        while (!c.finished) {
          c.next();
        }
        expect(c.knownCount, 1);
        expect(c.learningCount, 1);
        expect(c.unmarkedCount, first.count - 2);
        c.studyTheRest();
        expect(c.total, first.count - 1);
        expect(c.restricted, isTrue);
      },
    );

    liveTest('a star is kept by the API, read back by the grid and by the starred session, and taken back', () async {
      final repo = await _repoFor(_study);
      if (repo == null) return;
      final deck = (await _fillPlaces(repo)).open.first;
      final c = DeckStudyController.deck(repo, deck);
      await c.load();
      final card = c.allCards[3];

      final before = (await repo.starredCards()).map((s) => s.id).toSet();
      if (before.contains(card.id)) await repo.setStar(card.id, false);
      try {
        expect(await c.toggleStar(card), isNull);
        expect(c.isStarred(card), isTrue);

        final read = ApiStudyRepository(api: await liveClient(_study));
        final starred = await read.starredCards();
        expect(starred.first.id, card.id, reason: 'newest first');
        expect(starred.first.topicSlug, deck.slug);
        expect(starred.first.topicTitle, deck.title);
        expect(starred.first.front, card.front);

        final grid = DecksController(read);
        await grid.start();
        expect(grid.starredIn(deck), greaterThanOrEqualTo(1), reason: 'the card of the deck shows its star count');

        final session = DeckStudyController.starred(read);
        await session.load();
        expect(session.title, 'Starred cards');
        expect(session.allCards.first.id, card.id);
        expect(session.isStarred(session.allCards.first), isTrue);

        final reopened = DeckStudyController.deck(read, deck);
        await reopened.load();
        expect(reopened.isStarred(reopened.allCards[3]), isTrue, reason: 'a deck opened later shows the star');

        expect(await c.toggleStar(card), isNull);
        expect((await read.starredCards()).map((s) => s.id), isNot(contains(card.id)));
      } finally {
        if (before.contains(card.id)) await repo.setStar(card.id, true);
      }
    });

    liveTest('the bell reads the same unread count the API gives', () async {
      final api = await liveClient(bharat);
      final res = await api.dio.get<Map<String, dynamic>>('/notifications/unread-count');
      expect(await ApiStudyRepository(api: api).unreadNotifications(), (res.data!['unread'] as num).toInt());
    });
  });

  group('the screens, drawn from the live API', () {
    liveWidgetTest('the grid shows the real decks, the API\'s note and a Locked pill on each for a plan with none', (
      tester,
    ) async {
      final live = (await tester.runAsync(() => _repoFor(bharat)))!;
      final snapshot = (await tester.runAsync(() => _Snapshot.take(live)))!;
      if (snapshot._plan?.limit != 0) {
        markTestSkipped('Bharat has been given deck places (--grant-bharat)');
        return;
      }
      await _show(
        tester,
        FlashCardsScreen(onBack: () {}, repository: snapshot),
        physical: const Size(780, 14000),
      );
      final decks = snapshot._topics.where((t) => t.isDeck).toList();
      expect(find.text('Flash cards are not included in your plan.'), findsOneWidget);
      expect(find.text('${decks.length} decks'), findsOneWidget);
      expect(find.text('Locked'), findsNWidgets(decks.length));
      expect(find.text('Study'), findsNothing);
      expect(find.text('Capital Planning'), findsOneWidget);
    });

    liveWidgetTest(
      'on the study screen a tap flips the card, Next moves on, and the star is kept by the API and taken back',
      (tester) async {
        final live = await tester.runAsync(() => _repoFor(_study));
        if (live == null) return;
        final deck = (await tester.runAsync(() async => (await _fillPlaces(live)).open.first))!;
        final snapshot = (await tester.runAsync(() => _Snapshot.take(live, shelves: [deck.slug])))!;
        final card = snapshot._shelves[deck.slug]!.cards.first;
        final before = snapshot._starred.map((c) => c.id).toSet();
        if (before.contains(card.id)) await tester.runAsync(() => live.setStar(card.id, false));
        // The screen starts from what the API said (the snapshot's star list may have held this card).
        final clean = (await tester.runAsync(() => _Snapshot.take(live, shelves: [deck.slug])))!;

        await _show(tester, DeckStudyScreen.deck(repository: clean, deck: deck));
        expect(find.text(card.front), findsOneWidget);
        expect(find.text('1 of ${deck.cardCount}'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('study-flip')));
        await tester.pumpAndSettle();
        expect(find.text('Tap to flip back'), findsOneWidget);
        expect(find.textContaining(card.back.substring(0, 20)), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('study-next')));
        await tester.pumpAndSettle();
        expect(find.text('2 of ${deck.cardCount}'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('study-previous')));
        await tester.pumpAndSettle();
        expect(find.text('1 of ${deck.cardCount}'), findsOneWidget);

        try {
          await _tapOnline(tester, find.byKey(const ValueKey('study-star')));
          final kept = (await tester.runAsync(live.starredCards))!;
          expect(kept.map((c) => c.id), contains(card.id), reason: 'the star was sent to the API');
          await _tapOnline(tester, find.byKey(const ValueKey('study-star')));
          final gone = (await tester.runAsync(live.starredCards))!;
          expect(gone.map((c) => c.id), isNot(contains(card.id)), reason: 'and taken back');
        } finally {
          if (before.contains(card.id)) await tester.runAsync(() => live.setStar(card.id, true));
        }
      },
    );
  });

  group('decks that go with an Assess your knowledge course (read-only)', () {
    liveTest('a deck carries the course it goes with, and the plan carries the courses that are open', () async {
      final repo = (await _repoFor(bharat))!;
      final decks = (await repo.topics()).where((t) => t.isDeck).toList();
      final linked = decks.where((d) => d.linked).toList();
      if (linked.isEmpty) {
        markTestSkipped('this API does not link decks to courses yet (the website change of 27 Oct 2026)');
        return;
      }
      for (final d in linked) {
        expect(d.course, isNotNull, reason: '${d.title} names its course beside the id');
        expect(d.course!.id, d.courseId);
        expect(d.course!.code, isNotEmpty);
      }
      final plan = (await repo.deckPlan())!;
      // Bharat's plan opens courses; the lists are there even when empty.
      expect(plan.openedCourseIds, isA<List<String>>());
      expect(plan.unlockedCourseIds, isA<List<String>>());
    });

    liveTest('the grid mark of a linked deck is what the API answers for it: open exactly when its course is', () async {
      final repo = (await _repoFor(bharat))!;
      final decks = (await repo.topics()).where((t) => t.isDeck && t.linked).toList();
      if (decks.isEmpty) {
        markTestSkipped('this API does not link decks to courses yet');
        return;
      }
      final plan = (await repo.deckPlan())!;
      var open = 0, closed = 0;
      for (final deck in decks) {
        // Reading a deck that goes with a course takes none of the plan's places, so this changes nothing.
        final preview = plan.stateFor(deck);
        try {
          await repo.topic(deck.slug);
          expect(preview, DeckState.open, reason: '${deck.title}: the API opened it, so the grid must not mark it locked');
          open++;
        } on DeckLocked catch (lock) {
          expect(preview, DeckState.locked, reason: '${deck.title}: the API refused it (${lock.message})');
          expect(lock.course?.code, deck.course?.code, reason: 'the refusal names the own course of the deck');
          expect(lock.opensWithCourse, isTrue);
          closed++;
        }
      }
      // ignore: avoid_print
      print('linked decks for Bharat: $open open, $closed closed, of ${decks.length}');
    });

    liveTest('signed out, a deck that goes with a course is refused naming its course', () async {
      final visitor = ApiStudyRepository(api: liveAnonymous());
      final linked = (await visitor.topics()).where((t) => t.isDeck && t.linked).toList();
      if (linked.isEmpty) {
        markTestSkipped('this API does not link decks to courses yet');
        return;
      }
      // Read-only: a visitor cannot take a place.
      await expectLater(
        visitor.topic(linked.first.slug),
        throwsA(
          isA<DeckLocked>()
              .having((e) => e.reason, 'reason', 'SIGN_IN')
              .having((e) => e.course?.code, 'course', linked.first.course?.code),
        ),
      );
    });
  });
}
