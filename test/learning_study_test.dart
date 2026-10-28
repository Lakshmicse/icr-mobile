import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/features/learning_study/decks_controller.dart';
import 'package:icr_mobile/features/learning_study/knowledge_controller.dart';
import 'package:icr_mobile/features/learning_study/study_controller.dart';
import 'package:icr_mobile/features/learning_study/study_format.dart';
import 'package:icr_mobile/features/learning_study/study_models.dart';
import 'package:icr_mobile/features/learning_study/widgets/formula_math.dart';

import 'helpers/fonts.dart';
import 'learning_study_fakes.dart';

/// The logic under the study screens: how a formula is read and drawn, the plan's number of decks, the API
/// source's mapping of the recorded responses, and the three controllers. The screens are in
/// `learning_study_screens_test.dart`.
void main() {
  setUpAll(loadAppFonts);

  group('reading a formula', () {
    test('the back of a card is the expression, then the note after a blank line', () {
      final back = fixtureMap('shelf_time-value-of-money')['cards'][0]['back'] as String;
      final parts = splitBack(back);
      expect(parts.expression, r'$$PV = FV\div (1+r)^{n}$$');
      expect(parts.note, 'PV=Present Value\nFV=Future Value\nr=Discount Rate\nn=Number of Years');
    });

    test('a note that is only the editor\'s invisible characters is no note', () {
      final cards = (fixtureMap('shelf_time-value-of-money')['cards'] as List).cast<Map>();
      final crf = cards.firstWhere((c) => (c['front'] as String).startsWith('Capital Recovery Factor'));
      expect(splitBack(crf['back'] as String).note, isEmpty);
    });

    test('LaTeX is wrapped in dollar signs; anything else is plain text', () {
      expect(parseExpression(r'$$a+b$$').tex, 'a+b');
      expect(parseExpression('Cost = Price').text, 'Cost = Price');
      expect(parseExpression('Cost = Price').isTex, isFalse);
    });

    test('words are wrapped as text so the spaces survive, single letters stay variables', () {
      expect(
        prepareTex('Portfolio Occupancy= Occupied Area \\div Total Portfolio Area ​×100'),
        r'\text{Portfolio Occupancy}= \text{Occupied Area} \div \text{Total Portfolio Area} \times 100',
      );
      expect(prepareTex(r'PV = C\div r'), r'\text{PV} = C\div r');
      expect(prepareTex(r'(1+r)^{n}'), r'(1+r)^{n}');
    });

    test('what is already text, and every other command, is left alone', () {
      expect(prepareTex(r'\text{Net Profit} \div \frac{a}{b}'), r'\text{Net Profit} \div \frac{a}{b}');
      expect(prepareTex(r'\mathrm{ROI} = x'), r'\mathrm{ROI} = x');
    });

    test('subscripts and superscripts keep their words, a hyphen inside a word stays in it, r-g is a subtraction', () {
      expect(prepareTex(r'Return_{Best Alternative}'), r'\text{Return}_{\text{Best Alternative}}');
      expect(prepareTex('Semi-Variable Cost'), r'\text{Semi-Variable Cost}');
      expect(prepareTex(r'C\div r-g'), r'C\div r-g');
    });

    test('a bare percent sign is escaped (TeX would read it as a comment) and the typed signs become commands', () {
      expect(prepareTex('Rate = 5%'), r'\text{Rate} = 5\%');
      expect(prepareTex('A − B ≥ 3'), r'A - B \geq 3');
    });

    test('plain text for the clipboard and the fallback: the signs and the words it was typed from', () {
      expect(plainFormula(parseExpression(r'$$PV = FV\div (1+r)^{n}$$')), 'PV = FV ÷ (1+r)^n');
      expect(
        plainFormula(parseExpression(r'$$\text{Net Profit} \div \text{Total Cost} \times 100$$')),
        'Net Profit ÷ Total Cost × 100',
      );
      expect(plainFormula(parseExpression(r'$$x = \frac{a+b}{2}$$')), 'x = (a+b) / (2)');
      expect(
        plainFormula(parseExpression(r'$$Return_{Best Alternative} − Return_{b}$$')),
        'Return_(Best Alternative) - Return_b',
      );
      expect(plainFormula(parseExpression('Cost = Price')), 'Cost = Price');
    });

    test('the note is a list of variables when every line is "symbol = meaning", else it is prose', () {
      final vars = parseVariables('PV=Present Value\nFV=Future Value\nr=Discount Rate\nn=Number of Years')!;
      expect(vars.map((v) => v.symbol), ['PV', 'FV', 'r', 'n']);
      expect(vars.map((v) => v.meaning), ['Present Value', 'Future Value', 'Discount Rate', 'Number of Years']);
      expect(parseVariables('Use the real rate when prices are rising.'), isNull);
      expect(parseVariables('PV=Present Value\nand some words'), isNull);
      expect(parseVariables(''), isNull);
    });

    test('a free-text example is split at a line of dashes', () {
      expect(splitExamples('One\n---\nTwo'), ['One', 'Two']);
      expect(splitExamples('  '), isEmpty);
      expect(splitExamples(null), isEmpty);
    });

    test('all 87 recorded formulas are drawn as math, none falls back to text, and every plain text is readable', () {
      var drawn = 0;
      for (final slug in [
        'time-value-of-money',
        'cost-analysis',
        'depreciation-analysis',
        'corporate-real-estate-cre',
      ]) {
        for (final c in (fixtureMap('shelf_$slug')['cards'] as List).cast<Map>()) {
          final expression = parseExpression(splitBack(c['back'] as String).expression);
          expect(expression.isTex, isTrue, reason: '${c['front']}');
          expect(
            FormulaMath.parse(expression.tex!),
            isNotNull,
            reason: '${c['front']}: ${prepareTex(expression.tex!)}',
          );
          final plain = plainFormula(expression);
          expect(plain, isNotEmpty);
          expect(plain, isNot(contains('\\')), reason: '${c['front']}: $plain');
          expect(plain, isNot(contains('​')));
          drawn++;
        }
      }
      expect(drawn, 87);
    });

    test('LaTeX the renderer cannot read is not drawn (the screen shows its plain text instead)', () {
      expect(FormulaMath.parse(r'\frac{1'), isNull);
      expect(FormulaMath.parse('   '), isNull);
    });

    test('a long formula is cut after its relations and top-level operators, never inside brackets', () {
      final pieces = splitPieces(r'\text{Cost} = \text{A} + (B+C)^{2} - 3 \times x');
      expect(pieces.map((p) => p.tex), [r'\text{Cost}', r'\text{A}', r'(B+C)^{2}', '3', 'x']);
      expect(pieces.map((p) => p.sign), ['=', '+', '-', r'\times', null]);
      expect(pieces.map((p) => p.relation), [true, false, false, false, false]);
    });

    test('a sign with nothing before it belongs to its number; a formula with no top-level sign is one piece', () {
      expect(splitPieces(r'-5 + x').map((p) => p.tex), ['-5', 'x']);
      expect(splitPieces(r'\text{Net Profit}').map((p) => p.sign), [null]);
      expect(splitPieces(r'C[1-(1+r)^{-n}\div r]').length, 1, reason: 'everything is inside the bracket');
      expect(splitPieces(r'\text{a + b} = 1').map((p) => p.tex), [r'\text{a + b}', '1'], reason: 'text is not cut');
      expect(splitPieces(r'x \geq 3').map((p) => p.relation), [true, false]);
    });

    test('the copied text is the name, the formula, then the variables one to a line', () {
      const card = StudyCard(
        id: 'pv',
        front: 'Present Value (PV)',
        back: '\$\$PV = FV\\div (1+r)^{n}\$\$\n\nPV=Present Value\nFV=Future Value',
      );
      expect(formulaCopyText(card), 'Present Value (PV)\nPV = FV ÷ (1+r)^n\nPV = Present Value\nFV = Future Value');
      const prose = StudyCard(id: 'x', front: 'Rate', back: '\$\$r = a\$\$\n\nUse it with care.');
      expect(formulaCopyText(prose), 'Rate\nr = a\nUse it with care.');
      const bare = StudyCard(id: 'y', front: 'Sunk Cost', back: '\$\$Sunk Cost = Past Spend\$\$');
      expect(formulaCopyText(bare), 'Sunk Cost\nSunk Cost = Past Spend');
    });

    test('a search finds a formula by its name, its expression, its note and its worked numbers', () async {
      final shelf = await repoOn(FakePortal()).topic('time-value-of-money');
      final pv = shelf.cards.first;
      for (final q in ['present value', 'discount rate', '11.66', 'attractive', 'fv ÷ (1+r)']) {
        expect(cardMatches(pv, queryTerms(q)), isTrue, reason: q);
      }
      expect(cardMatches(pv, queryTerms('present zebra')), isFalse);
      expect(cardMatches(pv, const []), isTrue);
    });
  });

  group('the plan and its decks', () {
    test('a plan with a number: the oldest places are open, a free place opens a new deck, the rest are locked', () {
      const plan = DeckPlan(limit: 2, opened: ['a', 'b', 'c']);
      expect(plan.stateOf('a'), DeckState.open);
      expect(plan.stateOf('b'), DeckState.open);
      expect(plan.stateOf('c'), DeckState.locked, reason: 'a third open deck is past the number');
      expect(plan.stateOf('z'), DeckState.locked);
      const roomy = DeckPlan(limit: 3, opened: ['a']);
      expect(roomy.stateOf('a'), DeckState.open);
      expect(roomy.stateOf('z'), DeckState.free);
    });

    test('no number, or staff, opens every deck and has nothing to say', () {
      expect(const DeckPlan().stateOf('z'), DeckState.open);
      expect(const DeckPlan(limit: 0, allOpen: true).stateOf('z'), DeckState.open);
      expect(const DeckPlan().note, isNull);
    });

    test('the line over the grid is the website\'s', () {
      expect(const DeckPlan(limit: 0).note, 'Flash cards are not included in your plan.');
      expect(const DeckPlan(limit: 1, opened: ['a']).note, 'Your plan opens 1 flash-card deck (1 used).');
      expect(const DeckPlan(limit: 3, opened: ['a', 'b']).note, 'Your plan opens 3 flash-card decks (2 used).');
      expect(const DeckPlan(limit: 2, opened: ['a', 'b', 'c']).note, 'Your plan opens 2 flash-card decks (2 used).');
    });
  });

  group('the API source', () {
    test('the shelves: kind, cover as an absolute URL, a trimmed title, the card count', () async {
      final topics = await repoOn(FakePortal()).topics();
      expect(topics, hasLength(8));
      final decks = topics.where((t) => t.isDeck).toList();
      expect(decks.map((t) => t.slug), [
        'capital-planning',
        'collabaration',
        'communication',
        'esg-and-sustainability',
      ]);
      expect(decks.first.cardCount, 200);
      expect(decks.first.cover!.url, startsWith('http://api.test/uploads/'));
      expect(decks.last.cover, isNull, reason: 'a deck with no picture has none');
      final shelves = topics.where((t) => !t.isDeck).toList();
      expect(shelves.map((t) => t.cardCount), containsAll([25, 25, 15, 22]));
      expect(
        shelves.map((t) => t.title),
        contains('Corporate Real Estate (CRE)'),
        reason: 'the stored title ends in a space',
      );
    });

    test('a shelf with its cards: categories, tags and a formula\'s worked examples in parts', () async {
      final repo = repoOn(FakePortal());
      final deck = await repo.topic('capital-planning');
      expect(deck.cards, hasLength(14));
      expect(deck.cards.first.category, 'Strategy & Fundamentals');
      expect(deck.cards.first.tags, ['Beginner']);
      expect(deck.cards.first.example, isNull);
      expect(deck.cards.first.examples, isEmpty);

      final pv = (await repo.topic('time-value-of-money')).cards.first;
      expect(pv.examples, hasLength(2));
      expect(pv.examples.first.given.map((g) => g.label), ['Future Building Value', 'Discount Rate', 'Years']);
      expect(pv.examples.first.given.first.value, '₹25 Crores');
      expect(pv.examples.first.working, 'PV = 25/(1.10)^8');
      expect(pv.examples.first.result, 'PV = ₹11.66 Crores');
      expect(pv.examples.first.decision, contains('financially attractive'));
      expect(pv.category, isNull, reason: 'an empty string is no category');
    });

    test('a deck the plan does not open is refused with the API\'s sentence and the plans page', () async {
      final portal = FakePortal(locked: ['capital-planning'])
        ..lockMessage = 'Flash-card decks are not included in your plan.';
      await expectLater(
        repoOn(portal).topic('capital-planning'),
        throwsA(
          isA<DeckLocked>()
              .having((e) => e.message, 'message', 'Flash-card decks are not included in your plan.')
              .having((e) => e.pricingSlug, 'pricingSlug', 'professional')
              .having((e) => e.reason, 'reason', 'DECKS')
              .having((e) => e.statusCode, 'statusCode', 403),
        ),
      );
    });

    test('any other failure is an ApiError with the API\'s sentence', () async {
      final portal = FakePortal()..shelfFails.add('cost-analysis');
      await expectLater(
        repoOn(portal).topic('cost-analysis'),
        throwsA(isA<ApiError>().having((e) => e.message, 'message', 'The shelf cost-analysis is not available.')),
      );
      portal.listFails = 'The catalogue is down.';
      await expectLater(
        repoOn(portal).topics(),
        throwsA(isA<ApiError>().having((e) => e.message, 'message', 'The catalogue is down.')),
      );
    });

    test('the member\'s stars carry their deck, and a star is a PUT, taking it back a DELETE', () async {
      final portal = FakePortal();
      final repo = repoOn(portal);
      expect(await repo.starredCards(), isEmpty);
      await repo.setStar('c1', true);
      await repo.setStar('c1', false);
      expect(portal.calls, contains('PUT /learning/me/resource-stars/c1'));
      expect(portal.calls, contains('DELETE /learning/me/resource-stars/c1'));

      final one = FakePortal(starred: ['cmv6lubcf01dfmyt8t4g9it5d']);
      final cards = await repoOn(one).starredCards();
      expect(cards.single.front, 'What is capital planning in CRE & FM?');
      expect(cards.single.topicTitle, 'Capital Planning');
      expect(cards.single.topicSlug, 'capital-planning');
    });

    test('a refused star is the plan\'s refusal; a server failure is the API\'s sentence', () async {
      final portal = FakePortal()..starStatus = 403;
      await expectLater(repoOn(portal).setStar('c1', true), throwsA(isA<DeckLocked>()));
      portal.starStatus = 500;
      await expectLater(
        repoOn(portal).setStar('c1', true),
        throwsA(isA<ApiError>().having((e) => e.statusCode, 'status', 500)),
      );
    });

    test('what the plan opens of the decks: a number and the decks opened; null when it cannot be read', () async {
      final study = await repoOn(FakePortal()).deckPlan();
      expect(study!.limit, 3);
      expect(study.opened, ['cmv6lubc001demyt83o222rgr'], reason: 'the recorded persona had opened Capital Planning');
      expect(study.note, 'Your plan opens 3 flash-card decks (1 used).');

      final bharat = await repoOn(FakePortal(unlocks: 'paper_unlocks_bharat')).deckPlan();
      expect(bharat!.limit, 0);
      expect(bharat.stateOf('any-deck'), DeckState.locked);
      expect(bharat.note, 'Flash cards are not included in your plan.');

      final portal = FakePortal();
      portal.unlocks = {};
      expect(await repoOn(portal).deckPlan(), isNull);
    });

    test('the bell reads the unread count and a failure reads as none', () async {
      expect(await repoOn(FakePortal(unread: 4)).unreadNotifications(), 4);
    });

    test('the plans page is the website\'s pricing route', () {
      expect(repoOn(FakePortal()).plansLink().toString(), 'https://icr.org.in/pricing/professional');
      expect(repoOn(FakePortal()).plansLink('supplier').path, '/pricing/supplier');
    });
  });

  group('the decks controller', () {
    test('it lists the question decks only, A to Z, with the bell\'s count', () async {
      final c = DecksController(repoOn(FakePortal(unread: 2)));
      await c.start();
      expect(c.decks.map((d) => d.title), [
        'Capital Planning',
        'Collabaration',
        'Communication',
        'ESG and Sustainability',
      ]);
      expect(c.unread, 2);
      expect(c.loading, isFalse);
      expect(c.planNote, 'Your plan opens 3 flash-card decks (1 used).');
    });

    test('the search narrows as you type, on every word, and clearing gives the decks back', () async {
      final c = DecksController(repoOn(FakePortal()));
      await c.start();
      c.setSearch('comm');
      expect(c.visible.map((d) => d.title), ['Communication']);
      c.setSearch('  planning capital ');
      expect(c.visible.map((d) => d.title), ['Capital Planning']);
      c.setSearch('zzz');
      expect(c.visible, isEmpty);
      expect(c.narrowed, isTrue);
      c.clearSearch();
      expect(c.visible, hasLength(4));
      expect(c.narrowed, isFalse);
    });

    test(
      'the plan decides each deck: open, free to open, or locked; every deck is locked for a plan with none',
      () async {
        final study = DecksController(
          repoOn(
            FakePortal()
              ..unlocks['plan'] = {
                'flashCardDecks': {
                  'limit': 2,
                  'openedDeckIds': ['cmv6lubc001demyt83o222rgr'],
                },
              },
          ),
        );
        await study.start();
        final byId = {for (final d in study.decks) d.id: study.stateOf(d)};
        expect(byId['cmv6lubc001demyt83o222rgr'], DeckState.open);
        expect(study.decks.where((d) => study.stateOf(d) == DeckState.free), hasLength(3));

        final bharat = DecksController(repoOn(FakePortal(unlocks: 'paper_unlocks_bharat')));
        await bharat.start();
        expect(bharat.decks.every((d) => bharat.stateOf(d) == DeckState.locked), isTrue);
      },
    );

    test('a deck that cannot read the plan marks nothing locked', () async {
      final portal = FakePortal()..unlocks = {};
      final c = DecksController(repoOn(portal));
      await c.start();
      expect(c.plan, isNull);
      expect(c.planNote, isNull);
      expect(c.decks.every((d) => c.stateOf(d) == DeckState.open), isTrue);
    });

    test('the member\'s stars are counted per deck', () async {
      final c = DecksController(repoOn(FakePortal(starred: ['cmv6lubcf01dfmyt8t4g9it5d'])));
      await c.start();
      expect(c.starred, hasLength(1));
      expect(c.starredIn(c.decks.first), 1);
      expect(c.starredIn(c.decks.last), 0);
    });

    test('a failed load says why and reading again recovers; reload keeps the grid and re-reads the places', () async {
      final portal = FakePortal()..listFails = 'The catalogue is down.';
      final c = DecksController(repoOn(portal));
      await c.start();
      expect(c.error, 'The catalogue is down.');
      expect(c.decks, isEmpty);
      portal.listFails = null;
      await c.refresh();
      expect(c.error, isNull);
      expect(c.decks, hasLength(4));

      portal.unlocks['plan'] = {
        'flashCardDecks': {
          'limit': 3,
          'openedDeckIds': ['cmv6lubc001demyt83o222rgr'],
        },
      };
      await c.reload();
      expect(c.plan!.used, 1);
      expect(c.decks, hasLength(4));
    });
  });

  group('the study controller', () {
    DeckStudyController study(FakePortal portal, {String slug = 'alpha', int count = 20, math.Random? random}) {
      portal.extra[slug] = bigDeck(slug, count: count);
      final deck = StudyTopic(id: 'topic-$slug', slug: slug, title: 'Deck $slug');
      return DeckStudyController.deck(repoOn(portal), deck, random: random ?? math.Random(7));
    }

    test('it opens on the first card, front side up', () async {
      final c = study(FakePortal());
      await c.load();
      expect(c.loaded, isTrue);
      expect(c.total, 20);
      expect(c.position, 1);
      expect(c.current!.front, 'Question 0 of alpha?');
      expect(c.flipped, isFalse);
      expect(c.progress, closeTo(0.05, 1e-9));
    });

    test('flip turns the card; moving on shows the next one front up; the first card has no previous', () async {
      final c = study(FakePortal());
      await c.load();
      c.flip();
      expect(c.flipped, isTrue);
      c.next();
      expect(c.position, 2);
      expect(c.flipped, isFalse, reason: 'the next card starts on its front');
      c.flip();
      c.previous();
      expect(c.position, 1);
      expect(c.flipped, isFalse);
      c.previous();
      expect(c.position, 1, reason: 'there is nothing before the first card');
      expect(c.atFirst, isTrue);
    });

    test('next on the last card finishes the pass, and previous comes back to that card', () async {
      final c = study(FakePortal(), count: 3);
      await c.load();
      c.next();
      c.next();
      expect(c.atLast, isTrue);
      expect(c.finished, isFalse);
      c.next();
      expect(c.finished, isTrue);
      c.previous();
      expect(c.finished, isFalse);
      expect(c.position, 3);
    });

    test('shuffle keeps the same cards in another order, and turning it off puts them back', () async {
      final c = study(FakePortal(), random: math.Random(3));
      await c.load();
      final plain = [for (var i = 0; i < c.total; i++) c.current!.id.also(c.next)];
      expect(plain.first, 'alpha-c0');
      c.studyAgain();
      c.toggleShuffle();
      expect(c.shuffled, isTrue);
      expect(c.position, 1);
      final shuffled = [for (var i = 0; i < c.total; i++) c.current!.id.also(c.next)];
      expect(shuffled.toSet(), plain.toSet(), reason: 'the same cards');
      expect(shuffled, isNot(plain), reason: 'in another order');
      c.toggleShuffle();
      expect(c.shuffled, isFalse);
      expect(c.current!.id, 'alpha-c0');
    });

    test('a category narrows the deck to its cards, pressing it again goes back to all', () async {
      final c = study(FakePortal());
      await c.load();
      expect(c.categories.map((e) => e.name), ['Category 0', 'Category 1', 'Category 2', 'Category 3']);
      expect(c.categories.every((e) => e.count == 5), isTrue);
      c.next();
      c.setCategory('Category 2');
      expect(c.total, 5);
      expect(c.position, 1, reason: 'back to the first card of what is left');
      expect(c.visible.every((card) => card.category == 'Category 2'), isTrue);
      c.setCategory('Category 2');
      expect(c.category, isNull);
      expect(c.total, 20);
    });

    test('a star is taken at once and kept by the API; taking it back is a DELETE', () async {
      final portal = FakePortal();
      final c = study(portal);
      await c.load();
      final card = c.current!;
      final seen = <bool>[];
      c.addListener(() => seen.add(c.isStarred(card)));
      expect(await c.toggleStar(card), isNull);
      expect(seen.first, isTrue, reason: 'the star shows before the API has answered');
      expect(portal.starred, [card.id]);
      expect(await c.toggleStar(card), isNull);
      expect(c.isStarred(card), isFalse);
      expect(portal.starred, isEmpty);
      expect(
        portal.calls,
        containsAllInOrder([
          'PUT /learning/me/resource-stars/${card.id}',
          'DELETE /learning/me/resource-stars/${card.id}',
        ]),
      );
    });

    test('a refused star is put back and the API\'s sentence is returned', () async {
      final portal = FakePortal()
        ..starStatus = 403
        ..starMessage = 'Flash-card decks are not included in your plan.';
      final c = study(portal);
      await c.load();
      final card = c.current!;
      expect(await c.toggleStar(card), 'Flash-card decks are not included in your plan.');
      expect(c.isStarred(card), isFalse);

      portal.starStatus = null;
      await c.toggleStar(card);
      portal.starStatus = 500;
      portal.starMessage = 'Try later.';
      expect(await c.toggleStar(card), 'Try later.');
      expect(c.isStarred(card), isTrue, reason: 'a failed unstar leaves the star where it was');
    });

    test('the cards starred before are starred on opening', () async {
      final portal = FakePortal(starred: ['alpha-c2', 'alpha-c5']);
      final c = study(portal);
      await c.load();
      expect(c.starredCount, 2);
      expect(c.isStarred(c.allCards[2]), isTrue);
      expect(c.isStarred(c.allCards[3]), isFalse);
    });

    test('the Starred chip freezes the cards starred right now: taking one back leaves it in the pass', () async {
      final portal = FakePortal(starred: ['alpha-c2', 'alpha-c5']);
      final c = study(portal);
      await c.load();
      c.toggleStarredOnly();
      expect(c.starredOnly, isTrue);
      expect(c.total, 2);
      await c.toggleStar(c.current!);
      expect(c.total, 2, reason: 'the card stays with a hollow star');
      c.toggleStarredOnly();
      expect(c.total, 20);
      c.toggleStarredOnly();
      expect(c.total, 1, reason: 'pressed again, only the one still starred');
    });

    test('got it and still learning mark the card and move on; the last mark finishes with the numbers', () async {
      final c = study(FakePortal(), count: 4);
      await c.load();
      c.mark(known: true);
      c.mark(known: false);
      expect(c.position, 3);
      c.previous();
      expect(c.isLearning(c.current!), isTrue);
      c.mark(known: true); // changes its mind
      expect(c.isLearning(c.allCards[1]), isFalse);
      expect(c.isKnown(c.allCards[1]), isTrue);
      c.mark(known: false);
      c.mark(known: false); // the last card
      expect(c.finished, isTrue);
      expect(c.knownCount, 2);
      expect(c.learningCount, 2);
      expect(c.unmarkedCount, 0);
      expect(c.toReview.map((card) => card.id), ['alpha-c2', 'alpha-c3']);
    });

    test(
      'study the rest goes over the cards not known, study again clears the marks, show all leaves the restriction',
      () async {
        final c = study(FakePortal(), count: 4);
        await c.load();
        c.mark(known: true);
        c.mark(known: false);
        c.next();
        c.next(); // finished: one known, one learning, two unmarked
        expect(c.unmarkedCount, 2);
        c.studyTheRest();
        expect(c.finished, isFalse);
        expect(c.restricted, isTrue);
        expect(c.total, 3);
        expect(c.visible.map((card) => card.id), ['alpha-c1', 'alpha-c2', 'alpha-c3']);
        c.showAll();
        expect(c.restricted, isFalse);
        expect(c.total, 4);
        c.mark(known: true);
        c.mark(known: true);
        c.mark(known: true);
        c.mark(known: true);
        expect(c.finished, isTrue);
        expect(c.toReview, isEmpty);
        c.studyAgain();
        expect(c.finished, isFalse);
        expect(c.knownCount, 0);
        expect(c.total, 4);
      },
    );

    test('the starred session is the member\'s starred cards from every deck, and has none to start with', () async {
      final empty = DeckStudyController.starred(repoOn(FakePortal()));
      await empty.load();
      expect(empty.loaded, isTrue);
      expect(empty.allCards, isEmpty);
      expect(empty.title, 'Starred cards');

      final portal = FakePortal(starred: ['cmv6lubcf01dfmyt8t4g9it5d']);
      final one = DeckStudyController.starred(repoOn(portal));
      await one.load();
      expect(one.isStarredSession, isTrue);
      expect(one.total, 1);
      expect(one.current!.topicTitle, 'Capital Planning');
      expect(one.isStarred(one.current!), isTrue);
    });

    test('a deck the plan does not open is a lock with the API\'s sentence, not an error', () async {
      final portal = FakePortal(locked: ['capital-planning'])
        ..lockMessage = 'Sign in to open “Capital Planning”. Every member can open 0 flash-card decks.';
      final deck = StudyTopic(id: 'x', slug: 'capital-planning', title: 'Capital Planning');
      final c = DeckStudyController.deck(repoOn(portal), deck);
      await c.load();
      expect(c.loaded, isFalse);
      expect(c.error, isNull);
      expect(c.lock!.message, startsWith('Sign in to open'));
    });

    test('a failed load says why and loading again recovers', () async {
      final portal = FakePortal()..shelfFails.add('capital-planning');
      final deck = StudyTopic(id: 'x', slug: 'capital-planning', title: 'Capital Planning');
      final c = DeckStudyController.deck(repoOn(portal), deck);
      await c.load();
      expect(c.error, 'The shelf capital-planning is not available.');
      portal.shelfFails.clear();
      await c.load();
      expect(c.error, isNull);
      expect(c.total, 14);
    });
  });

  group('the knowledge controller', () {
    test('it reads every formula group: A to Z, with their formulas, and the total', () async {
      final c = KnowledgeController(repoOn(FakePortal(unread: 1)));
      await c.start();
      expect(c.shelves.map((s) => s.topic.title), [
        'Corporate Real Estate (CRE)',
        'Cost Analysis',
        'Depreciation Analysis',
        'Time Value of Money',
      ]);
      expect(c.shelves.map((s) => s.cards.length), [25, 25, 15, 22]);
      expect(c.totalFormulas, 87);
      expect(c.unread, 1);
      expect(c.sections, hasLength(4));
    });

    test('a search finds formulas across the groups, a formula keeps its number in its own group', () async {
      final c = KnowledgeController(repoOn(FakePortal()));
      await c.start();
      c.setSearch('perpetuity');
      expect(c.sections.map((s) => s.shelf.topic.title), ['Time Value of Money']);
      expect(c.sections.single.rows.map((r) => r.card.front), ['Perpetuity', 'Growing Perpetuity']);
      expect(c.sections.single.rows.map((r) => r.number), [13, 14]);
      expect(c.matchCount, 2);
      c.setSearch('cost');
      expect(c.sections.length, greaterThan(1));
      c.setSearch('qqqqq');
      expect(c.sections, isEmpty);
      c.clearSearch();
      expect(c.matchCount, 87);
    });

    test('a group chip narrows the list to one group, and pressing it again shows them all', () async {
      final c = KnowledgeController(repoOn(FakePortal()));
      await c.start();
      c.selectShelf('cost-analysis');
      expect(c.sections.map((s) => s.shelf.topic.slug), ['cost-analysis']);
      c.setSearch('budgeted cost');
      expect(c.sections.map((s) => s.shelf.topic.slug).toSet(), {
        'cost-analysis',
      }, reason: 'the chip and the search both apply');
      expect(c.matchCount, inInclusiveRange(1, 24));
      c.setSearch('');
      c.selectShelf('cost-analysis');
      expect(c.shelfSlug, isNull);
      expect(c.sections, hasLength(4));
    });

    test('a group that did not load keeps its place with its sentence while the others show', () async {
      final portal = FakePortal()..shelfFails.add('cost-analysis');
      final c = KnowledgeController(repoOn(portal));
      await c.start();
      expect(c.hasFailures, isTrue);
      final failed = c.sections.firstWhere((s) => s.shelf.topic.slug == 'cost-analysis');
      expect(failed.shelf.error, 'The shelf cost-analysis is not available.');
      expect(failed.rows, isEmpty);
      expect(c.totalFormulas, 62);
      c.setSearch('perpetuity');
      expect(c.sections.map((s) => s.shelf.topic.slug), [
        'time-value-of-money',
      ], reason: 'a search drops groups with no match');
      portal.shelfFails.clear();
      c.clearSearch();
      await c.refresh();
      expect(c.hasFailures, isFalse);
      expect(c.totalFormulas, 87);
    });

    test('when not even the list loads, it says why', () async {
      final portal = FakePortal()..listFails = 'Down.';
      final c = KnowledgeController(repoOn(portal));
      await c.start();
      expect(c.error, 'Down.');
      expect(c.shelves, isEmpty);
    });
  });
}

extension on String {
  /// Reads the id, then moves on: `c.current!.id.also(c.next)`.
  String also(void Function() then) {
    then();
    return this;
  }
}
