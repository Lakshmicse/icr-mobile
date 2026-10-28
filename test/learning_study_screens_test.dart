import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/core/widgets/chips.dart';
import 'package:icr_mobile/features/learning_study/deck_study_screen.dart';
import 'package:icr_mobile/features/learning_study/demo_study_repository.dart';
import 'package:icr_mobile/features/learning_study/flash_cards_screen.dart';
import 'package:icr_mobile/features/learning_study/knowledge_center_screen.dart';
import 'package:icr_mobile/features/notifications/demo_notifications_repository.dart';
import 'package:icr_mobile/features/notifications/notifications_repository.dart';
import 'package:icr_mobile/features/notifications/notifications_screen.dart';
import 'package:icr_mobile/features/learning_study/study_models.dart';
import 'package:icr_mobile/features/learning_study/widgets/flip_card.dart';

import 'package:provider/provider.dart';

import 'helpers/fonts.dart';
import 'learning_study_fakes.dart';

/// The study screens, driven through the real API source over the recorded portal (`learning_study_fakes.dart`):
/// every control is tapped and what it did is read back from the screen and from the calls the portal saw.
void main() {
  setUpAll(loadAppFonts);

  final launches = _Launches();
  setUp(launches.install);
  tearDown(launches.remove);

  group('the flip card', () {
    testWidgets('a turn is a real animation: the front is still showing a third of the way, the back by the end', (
      tester,
    ) async {
      var back = false;
      late StateSetter set;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              set = setState;
              return SizedBox(
                width: 300,
                height: 200,
                child: FlipCard(
                  showBack: back,
                  onTap: () {},
                  front: const SizedBox.expand(child: Center(child: Text('the question'))),
                  back: const SizedBox.expand(child: Center(child: Text('the answer'))),
                ),
              );
            },
          ),
        ),
      );
      expect(find.text('the question'), findsOneWidget);
      expect(find.text('the answer'), findsNothing);
      expect(_turn(tester), 0);

      set(() => back = true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 140));
      expect(_turn(tester), inExclusiveRange(0.05, 0.5), reason: 'part of the way round, not jumped');
      expect(find.text('the question'), findsOneWidget, reason: 'the front shows until the card is edge-on');

      await tester.pump(const Duration(milliseconds: 160));
      expect(_turn(tester), inExclusiveRange(0.5, 1.0));
      expect(find.text('the answer'), findsOneWidget, reason: 'past the edge-on moment the back faces out');
      expect(find.text('the question'), findsNothing);

      await tester.pumpAndSettle();
      expect(_turn(tester), closeTo(1, 1e-6));
      expect(find.text('the answer'), findsOneWidget);

      set(() => back = false);
      await tester.pumpAndSettle();
      expect(_turn(tester), 0);
      expect(find.text('the question'), findsOneWidget);
    });

    testWidgets('with animations removed in the system settings the faces swap at once', (tester) async {
      var back = false;
      late StateSetter set;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: StatefulBuilder(
                builder: (context, setState) {
                  set = setState;
                  return FlipCard(
                    showBack: back,
                    onTap: () {},
                    front: const SizedBox(height: 100, child: Text('front')),
                    back: const SizedBox(height: 100, child: Text('back')),
                  );
                },
              ),
            ),
          ),
        ),
      );
      set(() => back = true);
      await tester.pump();
      expect(find.text('back'), findsOneWidget);
      expect(find.text('front'), findsNothing);
    });

    testWidgets('a tap is passed on, and the card says what it is to a screen reader', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: FlipCard(
            showBack: false,
            onTap: () => taps++,
            semanticLabel: 'Question: What is CapEx? Tap to see the answer.',
            front: const SizedBox(width: 200, height: 100, child: Text('What is CapEx?')),
            back: const SizedBox(width: 200, height: 100),
          ),
        ),
      );
      await tester.tap(find.text('What is CapEx?'));
      expect(taps, 1);
      expect(find.bySemanticsLabel(RegExp('Tap to see the answer')), findsOneWidget);
      handle.dispose();
    });
  });

  group('Flash Cards: the decks', () {
    testWidgets(
      'a deck is a card with its name and how many cards it holds; a member whose plan opens three sees the line and no locks',
      (tester) async {
        await _pump(tester, FlashCardsScreen(onBack: () {}, repository: repoOn(FakePortal())));
        expect(find.text('Flash Cards'), findsOneWidget);
        for (final name in ['Capital Planning', 'Collabaration', 'Communication', 'ESG and Sustainability']) {
          expect(find.text(name), findsOneWidget);
        }
        expect(find.text('200 CARDS'), findsNWidgets(2), reason: 'Capital Planning and ESG hold 200');
        expect(find.text('199 CARDS'), findsNWidgets(2));
        expect(find.text('4 decks'), findsOneWidget);
        expect(find.text('Your plan opens 3 flash-card decks (1 used).'), findsOneWidget);
        expect(find.text('Locked'), findsNothing);
        expect(find.text('Study'), findsNWidgets(4));
      },
    );

    testWidgets(
      'a plan that opens none marks every deck Locked and says so; "See plans" opens the website\'s plans page',
      (tester) async {
        await _pump(
          tester,
          FlashCardsScreen(
            onBack: () {},
            repository: repoOn(FakePortal(unlocks: 'paper_unlocks_bharat')),
          ),
        );
        expect(find.text('Flash cards are not included in your plan.'), findsOneWidget);
        expect(find.text('Locked'), findsNWidgets(4));
        expect(find.text('Study'), findsNothing);
        await tester.tap(find.text('See plans'));
        await tester.pump();
        expect(launches.urls, ['https://icr.org.in/pricing/professional']);
      },
    );

    testWidgets('a plan with no number draws no line and no lock', (tester) async {
      final portal = FakePortal()..unlocks['allOpen'] = true;
      portal.unlocks['plan'] = {
        'flashCardDecks': {'limit': null, 'openedDeckIds': <String>[]},
      };
      await _pump(tester, FlashCardsScreen(onBack: () {}, repository: repoOn(portal)));
      expect(find.byKey(const ValueKey('study-plan-note')), findsNothing);
      expect(find.text('Locked'), findsNothing);
    });

    testWidgets(
      'the search narrows the grid as you type; no match says so; Clear search and the clear button give the decks back',
      (tester) async {
        await _pump(tester, FlashCardsScreen(onBack: () {}, repository: repoOn(FakePortal())));
        await tester.enterText(find.byType(TextField), 'comm');
        await tester.pumpAndSettle();
        expect(find.text('Communication'), findsOneWidget);
        expect(find.text('Capital Planning'), findsNothing);
        expect(find.text('Showing 1 of 4 decks'), findsOneWidget);

        await tester.enterText(find.byType(TextField), 'zebra');
        await tester.pumpAndSettle();
        expect(find.text('No deck matches'), findsOneWidget);
        expect(find.textContaining('Nothing matches "zebra"'), findsOneWidget);
        await tester.tap(find.text('Clear search'));
        await tester.pumpAndSettle();
        expect(find.text('Capital Planning'), findsOneWidget);
        expect(find.text('4 decks'), findsOneWidget);

        await tester.enterText(find.byType(TextField), 'ESG');
        await tester.pumpAndSettle();
        expect(find.text('Capital Planning'), findsNothing);
        await tester.tap(find.byTooltip('Clear search'));
        await tester.pumpAndSettle();
        expect(find.text('Capital Planning'), findsOneWidget);
      },
    );

    testWidgets('a lone deck takes the left half of its row, two decks share it', (tester) async {
      await _pump(tester, FlashCardsScreen(onBack: () {}, repository: repoOn(FakePortal())));
      await tester.enterText(find.byType(TextField), 'comm');
      await tester.pumpAndSettle();
      final lone = tester.getRect(find.text('Communication'));
      expect(lone.left, lessThan(30));
      expect(lone.right, lessThan(195), reason: 'the first column, not the full width');
    });

    testWidgets('while loading it shows placeholders; with no decks it says so', (tester) async {
      final portal = FakePortal()..list = [];
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_host(FlashCardsScreen(onBack: () {}, repository: repoOn(portal))));
      expect(find.text('4 decks'), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('No flash-card decks yet'), findsOneWidget);
    });

    testWidgets('a failed load says why, Try again reads the list again', (tester) async {
      final portal = FakePortal()..listFails = 'The catalogue is down.';
      await _pump(tester, FlashCardsScreen(onBack: () {}, repository: repoOn(portal)));
      expect(find.text("Couldn't load the decks"), findsOneWidget);
      expect(find.text('The catalogue is down.'), findsOneWidget);
      portal.listFails = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Capital Planning'), findsOneWidget);
      expect(find.text("Couldn't load the decks"), findsNothing);
    });

    testWidgets('pulling down reads the decks again', (tester) async {
      final portal = FakePortal();
      await _pump(tester, FlashCardsScreen(onBack: () {}, repository: repoOn(portal)));
      final before = portal.calls.where((c) => c == 'GET /learning/resources').length;
      await tester.fling(find.text('4 decks'), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      expect(portal.calls.where((c) => c == 'GET /learning/resources').length, before + 1);
    });

    testWidgets("Back goes back; the bell opens the app's notifications and shows the unread count", (tester) async {
      final handle = tester.ensureSemantics();
      var backs = 0;
      await _pump(tester, FlashCardsScreen(onBack: () => backs++, repository: repoOn(FakePortal(unread: 2))));
      await tester.tap(find.bySemanticsLabel('Back'));
      expect(backs, 1);
      expect(find.bySemanticsLabel('Notifications, 2 unread'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Notifications, 2 unread'));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsScreen), findsOneWidget, reason: "the app's notifications, not the website");
      expect(launches.urls, isEmpty);
      handle.dispose();
    });

    testWidgets('a deck opens its study screen, and Back returns to the grid and re-reads the places', (tester) async {
      final portal = FakePortal();
      await _pump(tester, FlashCardsScreen(onBack: () {}, repository: repoOn(portal)));
      await tester.tap(find.text('Capital Planning'));
      await tester.pumpAndSettle();
      expect(portal.calls, contains('GET /learning/resources/capital-planning'));
      expect(find.byKey(const ValueKey('study-position')), findsOneWidget);
      expect(find.text('1 of 14'), findsOneWidget);
      final unlocksBefore = portal.calls.where((c) => c == 'GET /learning/me/paper-unlocks').length;
      await tester.tap(find.byKey(const ValueKey('study-back')));
      await tester.pumpAndSettle();
      expect(find.text('4 decks'), findsOneWidget);
      expect(portal.calls.where((c) => c == 'GET /learning/me/paper-unlocks').length, unlocksBefore + 1);
    });

    testWidgets('a locked deck still opens, and the study screen shows the API\'s sentence', (tester) async {
      final portal = FakePortal(unlocks: 'paper_unlocks_bharat', locked: ['capital-planning'])
        ..lockMessage = 'Flash-card decks are not included in your plan.';
      await _pump(tester, FlashCardsScreen(onBack: () {}, repository: repoOn(portal)));
      await tester.tap(find.text('Capital Planning'));
      await tester.pumpAndSettle();
      expect(find.text("This deck isn't open on your plan"), findsOneWidget);
      expect(find.text('Flash-card decks are not included in your plan.'), findsWidgets);
    });

    testWidgets(
      'Study starred appears once something is starred, shows the star on its deck, and opens the starred cards',
      (tester) async {
        final portal = FakePortal(starred: ['cmv6lubcf01dfmyt8t4g9it5d']);
        await _pump(tester, FlashCardsScreen(onBack: () {}, repository: repoOn(portal)));
        expect(find.text('Study starred (1)'), findsOneWidget);
        expect(find.text('1'), findsOneWidget, reason: 'the star count on Capital Planning');
        await tester.tap(find.byKey(const ValueKey('study-starred-chip')));
        await tester.pumpAndSettle();
        expect(find.text('Starred cards'), findsOneWidget);
        expect(find.text('What is capital planning in CRE & FM?'), findsOneWidget);
        expect(find.text('CAPITAL PLANNING · STRATEGY & FUNDAMENTALS'), findsOneWidget);
      },
    );

    testWidgets('with nothing starred there is no Study starred chip', (tester) async {
      await _pump(tester, FlashCardsScreen(onBack: () {}, repository: repoOn(FakePortal())));
      expect(find.byKey(const ValueKey('study-starred-chip')), findsNothing);
    });
  });

  group('Flash Cards: studying a deck', () {
    testWidgets(
      'the first card shows its question, its category and its level, and a tap flips it to the answer and back',
      (tester) async {
        await _pump(tester, _deck(FakePortal()));
        expect(find.text('What is capital planning in CRE & FM?'), findsOneWidget);
        expect(find.text('STRATEGY & FUNDAMENTALS'), findsOneWidget);
        expect(find.text('Beginner'), findsOneWidget);
        expect(find.text('Tap to see the answer'), findsOneWidget);
        expect(find.textContaining('A structured process for forecasting'), findsNothing);

        await tester.tap(find.byKey(const ValueKey('study-flip')));
        await tester.pumpAndSettle();
        expect(find.textContaining('A structured process for forecasting'), findsOneWidget);
        expect(find.text('ANSWER'), findsOneWidget);
        expect(find.text('Tap to flip back'), findsOneWidget);
        expect(find.text('What is capital planning in CRE & FM?'), findsNothing);

        await tester.tap(find.byKey(const ValueKey('study-flip')));
        await tester.pumpAndSettle();
        expect(find.text('What is capital planning in CRE & FM?'), findsOneWidget);
        expect(find.text('Did you get it?'), findsNothing);
      },
    );

    testWidgets(
      'Next and Previous move through the deck and always show the next card\'s question; the position and the progress follow',
      (tester) async {
        await _pump(tester, _deck(FakePortal()));
        expect(find.text('1 of 14'), findsOneWidget);
        expect(_progress(tester), closeTo(1 / 14, 1e-6));

        await tester.tap(find.byKey(const ValueKey('study-flip')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('study-next')));
        await tester.pumpAndSettle();
        expect(find.text('2 of 14'), findsOneWidget);
        expect(find.text('What is the difference between CapEx and OpEx?'), findsOneWidget, reason: 'front up again');
        expect(_progress(tester), closeTo(2 / 14, 1e-6));

        await tester.tap(find.byKey(const ValueKey('study-previous')));
        await tester.pumpAndSettle();
        expect(find.text('1 of 14'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('study-previous')));
        await tester.pumpAndSettle();
        expect(find.text('1 of 14'), findsOneWidget, reason: 'nothing before the first card');
      },
    );

    testWidgets('a swipe left goes on and a swipe right comes back', (tester) async {
      await _pump(tester, _deck(FakePortal()));
      await tester.fling(find.byKey(const ValueKey('study-flip')), const Offset(-300, 0), 1500);
      await tester.pumpAndSettle();
      expect(find.text('2 of 14'), findsOneWidget);
      await tester.fling(find.byKey(const ValueKey('study-flip')), const Offset(300, 0), 1500);
      await tester.pumpAndSettle();
      expect(find.text('1 of 14'), findsOneWidget);
    });

    testWidgets('Shuffle reorders the deck from the first card and a second press restores it', (tester) async {
      await _pump(tester, _deck(FakePortal(), random: math.Random(5)));
      final handle = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Shuffle the deck'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('study-next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('study-shuffle')));
      await tester.pumpAndSettle();
      expect(find.text('1 of 14'), findsOneWidget, reason: 'a shuffled deck starts again');
      expect(find.bySemanticsLabel('Restore the original order'), findsOneWidget);
      expect(find.text('What is capital planning in CRE & FM?'), findsNothing, reason: 'another card is first');
      await tester.tap(find.byKey(const ValueKey('study-shuffle')));
      await tester.pumpAndSettle();
      expect(find.text('What is capital planning in CRE & FM?'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the star is kept by the API and taken back with a second tap', (tester) async {
      final portal = FakePortal();
      final handle = tester.ensureSemantics();
      await _pump(tester, _deck(portal));
      expect(find.bySemanticsLabel('Star this card'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('study-star')));
      await tester.pumpAndSettle();
      expect(portal.starred, ['cmv6lubcf01dfmyt8t4g9it5d']);
      expect(find.bySemanticsLabel('Remove star'), findsOneWidget);
      expect(find.byKey(const ValueKey('study-flip')), findsOneWidget);
      expect(find.text('Tap to see the answer'), findsOneWidget, reason: 'starring does not flip the card');
      await tester.tap(find.byKey(const ValueKey('study-star')));
      await tester.pumpAndSettle();
      expect(portal.starred, isEmpty);
      expect(find.bySemanticsLabel('Star this card'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a refused star is put back and the API\'s sentence is shown', (tester) async {
      final portal = FakePortal()
        ..starStatus = 403
        ..starMessage = 'Flash-card decks are not included in your plan.';
      final handle = tester.ensureSemantics();
      await _pump(tester, _deck(portal));
      await tester.tap(find.byKey(const ValueKey('study-star')));
      await tester.pumpAndSettle();
      expect(find.text('Flash-card decks are not included in your plan.'), findsOneWidget);
      expect(find.bySemanticsLabel('Star this card'), findsOneWidget);
      expect(portal.starred, isEmpty);
      handle.dispose();
    });

    testWidgets('the category chips narrow the deck; All brings it back; Starred keeps the starred cards', (
      tester,
    ) async {
      final portal = FakePortal(starred: ['alpha-c1', 'alpha-c6']);
      portal.extra['alpha'] = bigDeck('alpha', count: 20, categories: 4);
      await _pump(tester, DeckStudyScreen.deck(repository: repoOn(portal), deck: _topic('alpha')));
      expect(find.text('All 20'), findsOneWidget);
      expect(find.text('Starred 2'), findsOneWidget);
      expect(find.text('1 of 20'), findsOneWidget);

      await _tapChip(tester, 'study-chip-Category 2');
      expect(find.text('1 of 5'), findsOneWidget);
      expect(find.text('Question 2 of alpha?'), findsOneWidget);

      await _tapChip(tester, 'study-chip-starred');
      expect(find.text('1 of 2'), findsOneWidget);
      expect(find.text('Question 1 of alpha?'), findsOneWidget);

      await _tapChip(tester, 'study-chip-all');
      expect(find.text('1 of 20'), findsOneWidget);
    });

    testWidgets('Got it and Still learning mark the card, move on and keep the tally', (tester) async {
      final portal = FakePortal();
      portal.extra['alpha'] = bigDeck('alpha', count: 5);
      await _pump(tester, DeckStudyScreen.deck(repository: repoOn(portal), deck: _topic('alpha')));
      expect(find.byKey(const ValueKey('study-tally')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('study-got-it')));
      await tester.pumpAndSettle();
      expect(find.text('2 of 5'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('study-still-learning')));
      await tester.pumpAndSettle();
      expect(find.text('3 of 5'), findsOneWidget);
      expect(find.text('Got it 1 · Still learning 1'), findsOneWidget);
    });

    testWidgets('the last card\'s Next finishes the pass; the summary has the numbers and the way on', (tester) async {
      final portal = FakePortal();
      portal.extra['alpha'] = bigDeck('alpha', count: 4);
      final handle = tester.ensureSemantics();
      await _pump(tester, DeckStudyScreen.deck(repository: repoOn(portal), deck: _topic('alpha')));
      await tester.tap(find.byKey(const ValueKey('study-got-it')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('study-still-learning')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('study-next'))); // the third card, skipped
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Next card'), findsNothing, reason: 'on the last card the button finishes the pass');
      expect(find.bySemanticsLabel('Finish'), findsOneWidget);
      handle.dispose();
      await tester.tap(find.byKey(const ValueKey('study-next')));
      await tester.pumpAndSettle();

      expect(find.text('Deck complete'), findsOneWidget);
      expect(find.text('You went through 4 cards.'), findsOneWidget);
      expect(_stat(tester, 'known'), '1');
      expect(_stat(tester, 'learning'), '1');
      expect(_stat(tester, 'unmarked'), '2');
      expect(find.text('Study the 3 you have not got'), findsOneWidget);

      // Study the rest: three cards, the restriction banner, Whole deck leaves it.
      await tester.tap(find.byKey(const ValueKey('study-summary-rest')));
      await tester.pumpAndSettle();
      expect(find.text('1 of 3'), findsOneWidget);
      expect(find.text('Studying the 3 you have not got yet'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('study-show-all')));
      await tester.pumpAndSettle();
      expect(find.text('1 of 4'), findsOneWidget);
      expect(find.byKey(const ValueKey('study-restricted')), findsNothing);
    });

    testWidgets('a summary of a deck that is all known offers to study it again; Back to the last card goes back', (
      tester,
    ) async {
      final portal = FakePortal();
      portal.extra['alpha'] = bigDeck('alpha', count: 3);
      await _pump(tester, DeckStudyScreen.deck(repository: repoOn(portal), deck: _topic('alpha')));
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const ValueKey('study-got-it')));
        await tester.pumpAndSettle();
      }
      expect(find.text('You know all 3 cards.'), findsOneWidget);
      expect(find.text('Study them again'), findsOneWidget);
      expect(find.byKey(const ValueKey('study-summary-again')), findsNothing, reason: 'nothing left to study over');

      await tester.tap(find.byKey(const ValueKey('study-summary-last')));
      await tester.pumpAndSettle();
      expect(find.text('3 of 3'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('study-next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('study-summary-rest'))); // "Study them again"
      await tester.pumpAndSettle();
      expect(find.text('1 of 3'), findsOneWidget);
      expect(find.byKey(const ValueKey('study-tally')), findsNothing, reason: 'the marks are cleared');
    });

    testWidgets('Start over on a summary with cards still to learn begins the whole deck again', (tester) async {
      final portal = FakePortal();
      portal.extra['alpha'] = bigDeck('alpha', count: 3);
      await _pump(tester, DeckStudyScreen.deck(repository: repoOn(portal), deck: _topic('alpha')));
      await tester.tap(find.byKey(const ValueKey('study-got-it')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('study-still-learning')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('study-still-learning')));
      await tester.pumpAndSettle();
      expect(find.text('Study the 2 you have not got'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('study-summary-again')));
      await tester.pumpAndSettle();
      expect(find.text('1 of 3'), findsOneWidget);
      expect(find.byKey(const ValueKey('study-tally')), findsNothing);
      expect(find.byKey(const ValueKey('study-restricted')), findsNothing);
    });

    testWidgets('the starred cards of a summary are counted', (tester) async {
      final portal = FakePortal(starred: ['alpha-c0']);
      portal.extra['alpha'] = bigDeck('alpha', count: 2);
      await _pump(tester, DeckStudyScreen.deck(repository: repoOn(portal), deck: _topic('alpha')));
      await tester.tap(find.byKey(const ValueKey('study-got-it')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('study-got-it')));
      await tester.pumpAndSettle();
      expect(find.text('1 starred for another pass'), findsOneWidget);
    });

    testWidgets('Back leaves the study screen', (tester) async {
      final portal = FakePortal();
      await _pump(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _deck(portal))),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('study-position')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('study-back')));
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('All decks on the summary leaves the study screen', (tester) async {
      final portal = FakePortal();
      portal.extra['alpha'] = bigDeck('alpha', count: 1);
      await _pump(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DeckStudyScreen.deck(repository: repoOn(portal), deck: _topic('alpha')),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('study-got-it')));
      await tester.pumpAndSettle();
      expect(find.text('Deck complete'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('study-summary-back')));
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets(
      'a deck the plan does not open shows the API\'s sentence, See plans opens the plans page, All decks leaves',
      (tester) async {
        final portal = FakePortal(locked: ['capital-planning'])
          ..lockMessage = 'Your plan opens 3 flash-card decks, and you have opened them all.';
        await _pump(
          tester,
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _deck(portal))),
                child: const Text('open'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.text("This deck isn't open on your plan"), findsOneWidget);
        expect(find.text('Your plan opens 3 flash-card decks, and you have opened them all.'), findsOneWidget);
        expect(find.byKey(const ValueKey('study-flip')), findsNothing);
        await tester.tap(find.text('See plans'));
        await tester.pump();
        expect(launches.urls, ['https://icr.org.in/pricing/professional']);
        await tester.tap(find.text('All decks'));
        await tester.pumpAndSettle();
        expect(find.text('open'), findsOneWidget);
      },
    );

    testWidgets('a failed load says why and Try again reads the deck again', (tester) async {
      final portal = FakePortal()..shelfFails.add('capital-planning');
      await _pump(tester, _deck(portal));
      expect(find.text("Couldn't load the cards"), findsOneWidget);
      expect(find.text('The shelf capital-planning is not available.'), findsOneWidget);
      portal.shelfFails.clear();
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('1 of 14'), findsOneWidget);
    });

    testWidgets('a deck with no cards says so', (tester) async {
      final portal = FakePortal();
      portal.extra['empty'] = bigDeck('empty', count: 0);
      await _pump(tester, DeckStudyScreen.deck(repository: repoOn(portal), deck: _topic('empty')));
      expect(find.text('No cards in this deck yet'), findsOneWidget);
      expect(find.text('Back to decks'), findsOneWidget);
    });

    testWidgets('a starred session with nothing starred says how to star', (tester) async {
      await _pump(tester, DeckStudyScreen.starred(repository: repoOn(FakePortal())));
      expect(find.text('No starred cards yet'), findsOneWidget);
    });

    testWidgets('a long answer scrolls inside the card; the card, its star and both faces read to a screen reader', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final portal = FakePortal();
      portal.extra['long'] = bigDeck('long', count: 2)
        ..['cards'][0]['back'] = List.filled(60, 'A long, long explanation that keeps going.').join(' ')
        ..['cards'][0]['example'] = 'Worked example text.'
        ..['cards'][0]['resourceUrl'] = 'https://icr.org.in/templates/business-case.pdf'
        ..['cards'][0]['resourceLabel'] = 'Business case template';
      await _pump(tester, DeckStudyScreen.deck(repository: repoOn(portal), deck: _topic('long')));
      expect(find.bySemanticsLabel(RegExp(r'^Question: Question 0 of long\?')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('study-flip')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'no overflow on a long answer');
      expect(find.bySemanticsLabel(RegExp(r'^Answer: A long')), findsOneWidget);
      expect(find.text('EXAMPLE'), findsOneWidget);
      final cardScroll = find
          .descendant(of: find.byKey(const ValueKey('study-flip')), matching: find.byType(Scrollable))
          .first;
      await tester.scrollUntilVisible(find.text('Business case template'), 200, scrollable: cardScroll);
      await tester.tap(find.text('Business case template'));
      await tester.pump();
      expect(launches.urls, ['https://icr.org.in/templates/business-case.pdf']);
      handle.dispose();
    });
  });

  group('Knowledge Center', () {
    testWidgets(
      'the formulas are one list under their group\'s heading, numbered within the group, with a chip per group',
      (tester) async {
        await _pump(tester, KnowledgeCenterScreen(onBack: () {}, repository: repoOn(FakePortal())));
        expect(find.text('Knowledge Center'), findsOneWidget);
        expect(find.text('Corporate Real Estate (CRE)'), findsOneWidget);
        expect(find.text('25 formulas'), findsWidgets);
        expect(find.text('All 87'), findsOneWidget);
        expect(find.text('Cost Analysis 25'), findsOneWidget);
        expect(find.text('Portfolio Occupancy Rate'), findsOneWidget);
        expect(find.text('01'), findsWidgets);
      },
    );

    testWidgets(
      'the search finds a formula by name, by its expression and by its worked numbers; Clear search brings the list back',
      (tester) async {
        await _pump(tester, KnowledgeCenterScreen(onBack: () {}, repository: repoOn(FakePortal())));
        await tester.enterText(find.byType(TextField), 'perpetuity');
        await tester.pumpAndSettle();
        expect(find.text('Perpetuity'), findsOneWidget);
        expect(find.text('Growing Perpetuity'), findsOneWidget);
        expect(find.text('Portfolio Occupancy Rate'), findsNothing);
        expect(find.text('Showing 2 formulas of 87'), findsOneWidget);
        expect(find.text('13'), findsOneWidget, reason: 'Perpetuity keeps its place in its group');

        await tester.enterText(find.byType(TextField), '11.66');
        await tester.pumpAndSettle();
        expect(find.text('Present Value (PV)'), findsOneWidget);

        await tester.enterText(find.byType(TextField), 'qqqq');
        await tester.pumpAndSettle();
        expect(find.text('No formula matches'), findsOneWidget);
        await tester.tap(find.text('Clear search'));
        await tester.pumpAndSettle();
        expect(find.text('All 87'), findsOneWidget);
        expect(find.text('Portfolio Occupancy Rate'), findsOneWidget);
      },
    );

    testWidgets('a group chip narrows the list to that group and pressing it again shows them all', (tester) async {
      await _pump(tester, KnowledgeCenterScreen(onBack: () {}, repository: repoOn(FakePortal())));
      await _tapChip(tester, 'knowledge-chip-cost-analysis');
      expect(find.text('Fixed Cost (FC)'), findsOneWidget);
      expect(find.text('Portfolio Occupancy Rate'), findsNothing);
      await _tapChip(tester, 'knowledge-chip-cost-analysis');
      expect(find.text('Portfolio Occupancy Rate'), findsOneWidget);
      await _tapChip(tester, 'knowledge-chip-time-value-of-money');
      await _tapChip(tester, 'knowledge-chip-all');
      expect(find.text('Portfolio Occupancy Rate'), findsOneWidget);
    });

    testWidgets('a formula opens in a sheet: its expression drawn as math, its variables, its worked examples', (
      tester,
    ) async {
      await _pump(tester, KnowledgeCenterScreen(onBack: () {}, repository: repoOn(FakePortal())));
      await _tapChip(tester, 'knowledge-chip-time-value-of-money');
      await tester.tap(find.text('Present Value (PV)'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('formula-title')), findsOneWidget);
      expect(find.text('1 of 22'), findsOneWidget);
      expect(find.byKey(const ValueKey('formula-math')), findsOneWidget, reason: 'LaTeX is typeset, not shown as text');
      expect(find.byKey(const ValueKey('formula-plain')), findsNothing);
      expect(find.textContaining(r'\div'), findsNothing);

      // The variables from the note.
      expect(find.text('Where'), findsOneWidget);
      for (final v in ['PV', 'FV', 'r', 'n', 'Present Value', 'Discount Rate', 'Number of Years']) {
        expect(
          find.descendant(of: find.byKey(const ValueKey('formula-variables')), matching: find.text(v)),
          findsOneWidget,
          reason: v,
        );
      }

      // Both worked examples: figures, working, answer, analysis and decision.
      expect(find.text('Worked example 1'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Worked example 2'), 300, scrollable: _sheetScroll());
      expect(find.text('Worked example 2'), findsOneWidget);
      expect(find.text('Given'), findsWidgets);
      expect(find.text('Future Building Value'), findsOneWidget);
      expect(find.text('₹25 Crores'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('PV = ₹11.66 Crores'), 200, scrollable: _sheetScroll());
      expect(find.text('PV = 25/(1.10)^8'), findsOneWidget);
      expect(find.text('Result'), findsWidgets);
      expect(find.text('Decision'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Next and Previous page through the list the person was looking at; the first has no previous', (
      tester,
    ) async {
      await _pump(tester, KnowledgeCenterScreen(onBack: () {}, repository: repoOn(FakePortal())));
      await tester.enterText(find.byType(TextField), 'perpetuity');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Perpetuity'));
      await tester.pumpAndSettle();
      expect(find.text('1 of 2'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('formula-previous')));
      await tester.pumpAndSettle();
      expect(find.text('1 of 2'), findsOneWidget, reason: 'nothing before the first');
      await tester.tap(find.byKey(const ValueKey('formula-next')));
      await tester.pumpAndSettle();
      expect(find.text('2 of 2'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey('formula-title'))).data, 'Growing Perpetuity');
      await tester.tap(find.byKey(const ValueKey('formula-next')));
      await tester.pumpAndSettle();
      expect(find.text('2 of 2'), findsOneWidget, reason: 'nothing after the last');
      await tester.tap(find.byKey(const ValueKey('formula-previous')));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(const ValueKey('formula-title'))).data, 'Perpetuity');
    });

    testWidgets('Copy formula puts the name, the formula and the variables on the clipboard and says Copied', (
      tester,
    ) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await _pump(tester, KnowledgeCenterScreen(onBack: () {}, repository: repoOn(FakePortal())));
      await tester.enterText(find.byType(TextField), 'present value (pv)');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Present Value (PV)'));
      await tester.pumpAndSettle();
      expect(find.text('Copy formula'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('formula-copy')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        copied.single,
        'Present Value (PV)\nPV = FV ÷ (1+r)^n\nPV = Present Value\nFV = Future Value\nr = Discount Rate\nn = Number of Years',
      );
      expect(find.text('Copied'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Copy formula'), findsOneWidget);
    });

    testWidgets(
      'an expression that is plain text, one the renderer cannot read, and a free-text example all show as text',
      (tester) async {
        final portal = FakePortal();
        portal.extra['mixed'] = {
          'id': 't-mixed',
          'slug': 'mixed',
          'title': 'Mixed',
          'kind': 'FORMULA',
          'cardCount': 3,
          'cards': [
            {
              'id': 'm1',
              'front': 'Plain',
              'back': 'Cost = Price × Quantity\n\nWhere price is per unit.',
              'example': 'Price 5, quantity 4 = 20.\n---\nPrice 2, quantity 3 = 6.',
              'examples': null,
              'tags': ['KPI'],
            },
            {'id': 'm2', 'front': 'Broken', 'back': r'$$\frac{1$$', 'examples': []},
            {
              'id': 'm3',
              'front': 'Linked',
              'back': r'$$a = b$$',
              'resourceUrl': 'https://icr.org.in/x.pdf',
              'resourceLabel': 'The source',
            },
          ],
        };
        portal.list = [
          {'id': 't-mixed', 'slug': 'mixed', 'title': 'Mixed', 'kind': 'FORMULA', 'cardCount': 3, 'sortOrder': 0},
        ];
        await _pump(tester, KnowledgeCenterScreen(onBack: () {}, repository: repoOn(portal)));
        await tester.tap(find.text('Plain'));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('formula-plain')), findsOneWidget);
        expect(find.byKey(const ValueKey('formula-math')), findsNothing);
        expect(find.byKey(const ValueKey('formula-note')), findsOneWidget);
        expect(find.text('Where price is per unit.'), findsOneWidget);
        expect(find.text('Worked example 1'), findsOneWidget);
        await tester.scrollUntilVisible(find.text('Price 2, quantity 3 = 6.'), 200, scrollable: _sheetScroll());
        expect(find.text('Worked example 2'), findsOneWidget);
        expect(find.text('KPI'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('formula-next')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('formula-plain')),
          findsOneWidget,
          reason: 'unreadable LaTeX falls back to its text',
        );
        expect(find.textContaining('KaTeX'), findsNothing);
        expect(find.textContaining('ParseException'), findsNothing);

        await tester.tap(find.byKey(const ValueKey('formula-next')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('formula-resource')));
        await tester.pump();
        expect(launches.urls, ['https://icr.org.in/x.pdf']);
      },
    );

    testWidgets('a group that did not load says why next to the others and Try again reads it again', (tester) async {
      final portal = FakePortal()..shelfFails.add('cost-analysis');
      await _pump(tester, KnowledgeCenterScreen(onBack: () {}, repository: repoOn(portal)));
      // The group that failed sits after the 25 formulas of the one before it.
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('knowledge-shelf-error')),
        400,
        scrollable: find.descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable)).first,
      );
      expect(find.byKey(const ValueKey('knowledge-shelf-error')), findsOneWidget);
      expect(find.textContaining('The shelf cost-analysis is not available.'), findsOneWidget);
      expect(find.text('Cost Analysis'), findsOneWidget, reason: 'the failed group keeps its heading');
      portal.shelfFails.clear();
      await tester.tap(
        find.descendant(of: find.byKey(const ValueKey('knowledge-shelf-error')), matching: find.text('Try again')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('knowledge-shelf-error')), findsNothing);
      expect(find.text('Fixed Cost (FC)'), findsOneWidget, reason: 'the formulas of the group are where its error was');
    });

    testWidgets('a failed load says why and Try again recovers; no formulas published says so', (tester) async {
      final portal = FakePortal()..listFails = 'Down.';
      await _pump(tester, KnowledgeCenterScreen(onBack: () {}, repository: repoOn(portal)));
      expect(find.text("Couldn't load the formulas"), findsOneWidget);
      portal.listFails = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Portfolio Occupancy Rate'), findsOneWidget);

      final empty = FakePortal()..list = [];
      await _pump(tester, KnowledgeCenterScreen(key: UniqueKey(), onBack: () {}, repository: repoOn(empty)));
      expect(find.text('No formulas yet'), findsOneWidget);
    });

    testWidgets("pulling down reads the groups again; Back goes back; the bell opens the app's notifications", (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final portal = FakePortal(unread: 1);
      var backs = 0;
      await _pump(tester, KnowledgeCenterScreen(onBack: () => backs++, repository: repoOn(portal)));
      final before = portal.calls.where((c) => c == 'GET /learning/resources').length;
      await tester.fling(find.text('Portfolio Occupancy Rate'), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      expect(portal.calls.where((c) => c == 'GET /learning/resources').length, before + 1);
      await tester.tap(find.bySemanticsLabel('Back'));
      expect(backs, 1);
      await tester.tap(find.bySemanticsLabel('Notifications, 1 unread'));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsScreen), findsOneWidget, reason: "the app's notifications, not the website");
      expect(launches.urls, isEmpty);
      handle.dispose();
    });

    testWidgets('on a 320 dp phone nothing overflows, the sheet included', (tester) async {
      tester.view.physicalSize = const Size(960, 1920);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_host(KnowledgeCenterScreen(onBack: () {}, repository: repoOn(FakePortal()))));
      await tester.pumpAndSettle();
      await _tapChip(tester, 'knowledge-chip-corporate-real-estate-cre');
      await tester.tap(find.text('Portfolio Occupancy Rate'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('formula-detail')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('the sample content (FEED_SOURCE=demo)', () {
    testWidgets(
      'the decks: one open through its course, one locked and naming its course, one on its own; a star comes back as Study starred',
      (tester) async {
        final demo = DemoStudyRepository();
        await _pump(tester, FlashCardsScreen(onBack: () {}, repository: demo));
        expect(find.text('Capital Planning'), findsOneWidget);
        expect(find.text('Contract Management'), findsOneWidget);
        expect(find.text('Energy Management'), findsOneWidget);
        // The plan opens two places; only the deck on its own (Energy Management) could take one.
        expect(
          find.text(
            'Your plan opens 2 flash-card decks (0 used). A deck that goes with an Assess your knowledge course opens with that course.',
          ),
          findsOneWidget,
        );
        expect(find.text('Included in the course'), findsOneWidget, reason: 'Capital Planning: its course is open');
        expect(find.text('Opens with the course'), findsOneWidget, reason: 'Contract Management: its course is closed');
        expect(find.text('Locked'), findsOneWidget, reason: 'Contract Management: its course is closed');

        await tester.tap(find.text('Contract Management'));
        await tester.pumpAndSettle();
        expect(find.text('Opens with “Contract Management”'), findsOneWidget);
        expect(find.text('Open Contract Management'), findsOneWidget);
        await tester.tap(find.text('All decks'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Energy Management'));
        await tester.pumpAndSettle();
        expect(find.text('1 of 6'), findsOneWidget, reason: 'a deck on its own with a place to spare opens');
        await tester.tap(find.byKey(const ValueKey('study-back')));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Capital Planning'));
        await tester.pumpAndSettle();
        expect(find.text('1 of 6'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('study-star')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('study-back')));
        await tester.pumpAndSettle();
        expect(find.text('Study starred (1)'), findsOneWidget);
      },
    );

    testWidgets('the formulas: two groups, and Present Value opens with its math, variables and example', (
      tester,
    ) async {
      await _pump(tester, KnowledgeCenterScreen(onBack: () {}, repository: DemoStudyRepository()));
      expect(find.text('Time Value of Money'), findsOneWidget);
      expect(find.text('All 6'), findsOneWidget);
      await tester.tap(find.text('Present Value (PV)'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('formula-math')), findsOneWidget);
      expect(find.byKey(const ValueKey('formula-variables')), findsOneWidget);
      expect(find.text('Worked example'), findsOneWidget);
    });
  });
}

// ----------------------------------------------------------------------------------------------------------

/// The bell opens the app's notifications, which read their repository from above the screen.
Widget _host(Widget home) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: buildAppTheme(),
  home: Provider<NotificationsRepository>.value(value: DemoNotificationsRepository(), child: home),
);

/// 390 × 844 dp, the design's frame.
Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_host(home));
  await tester.pumpAndSettle();
}

StudyTopic _topic(String slug) => StudyTopic(id: 'topic-$slug', slug: slug, title: 'Deck $slug');

/// Capital Planning, the recorded deck (14 cards), studied from its first card.
Widget _deck(FakePortal portal, {math.Random? random}) => DeckStudyScreen.deck(
  repository: repoOn(portal),
  deck: const StudyTopic(id: 'cmv6lubc001demyt83o222rgr', slug: 'capital-planning', title: 'Capital Planning'),
  random: random,
);

/// How far round the card is: 0 for the front square on, 1 for the back.
double _turn(WidgetTester tester) {
  final t = tester.widget<Transform>(
    find.descendant(of: find.byType(FlipCard), matching: find.byType(Transform)).first,
  );
  // rotateY(a): entry (0,0) is cos(a).
  final cos = t.transform.entry(0, 0).clamp(-1.0, 1.0);
  return math.acos(cos) / math.pi;
}

double _progress(WidgetTester tester) =>
    tester.widget<LinearProgressIndicator>(find.byKey(const ValueKey('study-progress'))).value!;

/// A chip in a row that scrolls sideways (the row builds only the chips near the screen): scroll to it, tap it.
Future<void> _tapChip(WidgetTester tester, String key) async {
  final chip = find.byKey(ValueKey(key));
  final row = find.descendant(of: find.byType(ChipRow), matching: find.byType(Scrollable)).first;
  if (chip.evaluate().isEmpty) {
    await tester.drag(row, const Offset(3000, 0)); // back to the start
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(chip, 100, scrollable: row);
  }
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

/// The formula sheet's own scroll view.
Finder _sheetScroll() =>
    find.descendant(of: find.byKey(const ValueKey('formula-detail')), matching: find.byType(Scrollable)).first;

String _stat(WidgetTester tester, String which) {
  final tile = find.byKey(ValueKey('study-stat-$which'));
  return tester.widget<Text>(find.descendant(of: tile, matching: find.byType(Text)).first).data!;
}

/// Records what the app hands to the browser.
class _Launches {
  final urls = <String>[];

  void install() {
    urls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      (call) async {
        if (call.method == 'launch') urls.add((call.arguments as Map)['url'] as String);
        return true;
      },
    );
  }

  void remove() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/url_launcher'),
    null,
  );
}
