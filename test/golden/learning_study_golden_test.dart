@Tags(['golden'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/feed/feed_models.dart' show FeedPicture;
import 'package:icr_mobile/features/learning_study/deck_study_screen.dart';
import 'package:icr_mobile/features/learning_study/flash_cards_screen.dart';
import 'package:icr_mobile/features/learning_study/formula_sheet.dart';
import 'package:icr_mobile/features/learning_study/knowledge_center_screen.dart';
import 'package:icr_mobile/features/learning_study/study_models.dart';
import 'package:icr_mobile/features/learning_study/study_repository.dart';
import 'package:icr_mobile/core/widgets/detail_sheet.dart';

import '../helpers/fonts.dart';
import '../learning_study_fakes.dart';

/// The recorded API source with the pictures it would fetch swapped for bundled ones (a widget test cannot reach
/// the network), so the covers show in the goldens.
class _Bundled implements StudyRepository {
  _Bundled(this.inner);

  final StudyRepository inner;

  static const _covers = [
    'assets/images/demo/post_green_tower.jpg',
    'assets/images/demo/post_rooftop_hvac.jpg',
    'assets/images/demo/post_control_room.jpg',
  ];

  @override
  Future<List<StudyTopic>> topics() async {
    final all = await inner.topics();
    var i = 0;
    return [
      for (final t in all)
        StudyTopic(
          id: t.id,
          slug: t.slug,
          title: t.title,
          description: t.description,
          kind: t.kind,
          cover: t.kind == StudyKind.formula
              ? const FeedPicture.asset('assets/images/demo/learning/hub_knowledge.jpg')
              : t.cover == null
              ? null
              : FeedPicture.asset(_covers[i++ % _covers.length]),
          cardCount: t.cardCount,
          sortOrder: t.sortOrder,
          courseId: t.courseId,
          course: t.course,
        ),
    ];
  }

  @override
  Future<StudyTopic> topic(String slug) => inner.topic(slug);
  @override
  Future<DeckPlan?> deckPlan() => inner.deckPlan();
  @override
  Future<List<StudyCard>> starredCards() => inner.starredCards();
  @override
  Future<void> setStar(String cardId, bool starred) => inner.setStar(cardId, starred);
  @override
  Future<int> unreadNotifications() => inner.unreadNotifications();
  @override
  Uri plansLink([String slug = 'professional']) => inner.plansLink(slug);
}

/// The study screens at the phone's frame (390 × 844 dp), exported at 2x to build/screens/.
void main() {
  setUpAll(loadAppFonts);

  // flutter_test draws every shadow as a hard-edged shape; the card's and the title bar's are soft.
  void shadowedWidgets(String name, Future<void> Function(WidgetTester tester) body) {
    testWidgets(name, (tester) async {
      debugDisableShadows = false;
      try {
        await body(tester);
      } finally {
        debugDisableShadows = true;
      }
    });
  }

  Future<void> precacheAll(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element);
      }
    });
    await tester.pumpAndSettle();
  }

  Future<void> export(WidgetTester tester, Finder finder, String name) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.ancestor(of: finder, matching: find.byType(RepaintBoundary)).first,
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('build/screens').createSync(recursive: true);
      File('build/screens/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  Future<void> show(WidgetTester tester, Widget home, {Size physical = const Size(780, 1688)}) async {
    tester.view.physicalSize = physical;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, theme: buildAppTheme(), home: home));
    await tester.pumpAndSettle();
    await precacheAll(tester);
  }

  Future<void> shoot(WidgetTester tester, Type screen, String name) async {
    await export(tester, find.byType(screen), name);
    await expectLater(find.byType(screen), matchesGoldenFile('goldens/$name.png'));
  }

  StudyRepository decksRepo(FakePortal portal) => _Bundled(repoOn(portal));

  const capital = StudyTopic(id: 'cmv6lubc001demyt83o222rgr', slug: 'capital-planning', title: 'Capital Planning');

  shadowedWidgets('flash cards: the decks, a plan that opens three and one card starred', (tester) async {
    final portal = FakePortal(starred: ['cmv6lubcf01dfmyt8t4g9it5d'], unread: 2);
    await show(tester, FlashCardsScreen(onBack: () {}, repository: decksRepo(portal)));
    await shoot(tester, FlashCardsScreen, 'study_decks');
  });

  shadowedWidgets('flash cards: a plan that opens none, every deck locked', (tester) async {
    await show(
      tester,
      FlashCardsScreen(
        onBack: () {},
        repository: decksRepo(FakePortal(unlocks: 'paper_unlocks_bharat')),
      ),
    );
    await shoot(tester, FlashCardsScreen, 'study_decks_locked');
  });

  shadowedWidgets('flash cards: decks that go with Assess courses, one open through its course and one locked', (
    tester,
  ) async {
    // Capital Planning's course is open (a plan place), Communication's is not; Collabaration and ESG are on
    // their own and the plan has places for them.
    final portal = FakePortal()
      ..list = linkedDeckList()
      ..unlocks = unlocksOf(courses: ['course-cp'], decks: ['cmv6lubhu01izmyt8gsor0pwa']);
    await show(tester, FlashCardsScreen(onBack: () {}, repository: decksRepo(portal)));
    await shoot(tester, FlashCardsScreen, 'study_decks_linked');
  });

  shadowedWidgets('flash cards: a deck whose course is closed names it and offers it', (tester) async {
    final portal = FakePortal()
      ..lockedByCourse['capital-planning'] = {'id': 'course-cp', 'code': 'CP', 'title': 'Capital Planning'};
    await show(
      tester,
      DeckStudyScreen.deck(
        repository: repoOn(portal),
        deck: const StudyTopic(
          id: 'cmv6lubc001demyt83o222rgr',
          slug: 'capital-planning',
          title: 'Capital Planning',
          courseId: 'course-cp',
          course: StudyCourseRef(id: 'course-cp', code: 'CP', title: 'Capital Planning'),
        ),
      ),
    );
    await shoot(tester, DeckStudyScreen, 'study_deck_course_lock');
  });

  shadowedWidgets('flash cards: the first card, its question', (tester) async {
    await show(tester, DeckStudyScreen.deck(repository: repoOn(FakePortal()), deck: capital));
    await shoot(tester, DeckStudyScreen, 'study_card_front');
  });

  shadowedWidgets('flash cards: the same card half way through its flip (export only)', (tester) async {
    await show(tester, DeckStudyScreen.deck(repository: repoOn(FakePortal()), deck: capital));
    await tester.tap(find.byKey(const ValueKey('study-flip')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 190));
    await export(tester, find.byType(DeckStudyScreen), 'study_card_flip');
    await tester.pumpAndSettle();
  });

  shadowedWidgets('flash cards: the answer, starred', (tester) async {
    final portal = FakePortal(starred: ['cmv6lubcf01dfmyt8t4g9it5d']);
    await show(tester, DeckStudyScreen.deck(repository: repoOn(portal), deck: capital));
    await tester.tap(find.byKey(const ValueKey('study-flip')));
    await tester.pumpAndSettle();
    await shoot(tester, DeckStudyScreen, 'study_card_back');
  });

  shadowedWidgets('flash cards: the end of a pass', (tester) async {
    final portal = FakePortal(starred: ['alpha-c1']);
    portal.extra['alpha'] = bigDeck('alpha', count: 10);
    await show(
      tester,
      DeckStudyScreen.deck(
        repository: repoOn(portal),
        deck: const StudyTopic(id: 'topic-alpha', slug: 'alpha', title: 'Capital Planning'),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.tap(find.byKey(ValueKey(i % 3 == 2 ? 'study-still-learning' : 'study-got-it')));
      await tester.pumpAndSettle();
    }
    await shoot(tester, DeckStudyScreen, 'study_summary');
  });

  shadowedWidgets('flash cards: a deck the plan does not open', (tester) async {
    final portal = FakePortal(locked: ['capital-planning'])
      ..lockMessage = 'Your plan opens 3 flash-card decks, and you have opened them all.';
    await show(tester, DeckStudyScreen.deck(repository: repoOn(portal), deck: capital));
    await shoot(tester, DeckStudyScreen, 'study_locked');
  });

  shadowedWidgets('knowledge center: the formulas', (tester) async {
    await show(tester, KnowledgeCenterScreen(onBack: () {}, repository: decksRepo(FakePortal(unread: 1))));
    await shoot(tester, KnowledgeCenterScreen, 'study_knowledge');
  });

  Future<void> openFormula(
    WidgetTester tester,
    String slug,
    String name, {
    Size physical = const Size(780, 1688),
  }) async {
    final entries = <FormulaEntry>[];
    final shelf = await tester.runAsync(() => repoOn(FakePortal()).topic(slug));
    for (final (i, c) in shelf!.cards.indexed) {
      entries.add(FormulaEntry(card: c, shelf: shelf.title, number: i + 1));
    }
    final index = entries.indexWhere((e) => e.card.front == name);
    tester.view.physicalSize = physical;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: TextButton(
                onPressed: () => showFormulaSheet(context, entries: entries, index: index),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  shadowedWidgets('knowledge center: Present Value in its sheet', (tester) async {
    await openFormula(tester, 'time-value-of-money', 'Present Value (PV)');
    await shoot(tester, DetailSheetFrame, 'study_formula');
  });

  shadowedWidgets('knowledge center: the worked example further down the sheet', (tester) async {
    await openFormula(tester, 'time-value-of-money', 'Present Value (PV)');
    await tester.drag(find.byKey(const ValueKey('formula-detail')), const Offset(0, -520));
    await tester.pumpAndSettle();
    await shoot(tester, DetailSheetFrame, 'study_formula_example');
  });

  shadowedWidgets('knowledge center: a long formula breaks across lines (export only)', (tester) async {
    await openFormula(tester, 'cost-analysis', 'Cost of Acquisition');
    await export(tester, find.byType(DetailSheetFrame), 'study_formula_long');
  });

  shadowedWidgets('knowledge center: a formula with a fraction-like layout (export only)', (tester) async {
    await openFormula(tester, 'time-value-of-money', 'Weighted Average Cost of Capital (WACC)');
    await export(tester, find.byType(DetailSheetFrame), 'study_formula_wacc');
  });

  shadowedWidgets('flash cards at 320 dp (export only)', (tester) async {
    await show(
      tester,
      DeckStudyScreen.deck(repository: repoOn(FakePortal()), deck: capital),
      physical: const Size(640, 1136),
    );
    await export(tester, find.byType(DeckStudyScreen), 'study_card_front_320');
  });
}
