import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/features/marketplace/catalog_models.dart';
import 'package:icr_mobile/features/marketplace/marketplace_controller.dart';
import 'package:icr_mobile/features/marketplace/marketplace_models.dart';
import 'package:icr_mobile/features/marketplace/widgets/supplier_card.dart';

import 'helpers/fonts.dart';
import 'marketplace_fakes.dart';
import 'marketplace_harness.dart';

/// The search box's suggestions: what it offers while it has focus, with nothing
/// typed and with words, and what a tap on one does.

const _tree = [
  CategoryNode(
    key: 'FACILITY_MANAGEMENT',
    name: 'Integrated Facility Management',
    children: [
      CategoryNode(key: 'HVAC', name: 'HVAC'),
      CategoryNode(key: 'HOUSEKEEPING', name: 'Housekeeping'),
    ],
  ),
  CategoryNode(key: 'SECURITY', name: 'Security Services'),
];

SpyMarketplaceRepository repoWithMatches() => SpyMarketplaceRepository()
  ..treeAnswer = (() => _tree)
  ..supplierAnswer = ((id) => fullSupplier(id))
  ..searchAnswer = ((f, p) => f.search.isEmpty
      ? pageOf(4, total: 4, hasMore: false)
      : pageWith([
          fakeSupplier('d1', name: 'Duct Masters', headline: 'HVAC duct cleaning'),
          fakeSupplier('d2', name: 'Airflow Co', headline: 'Duct balancing'),
        ]));

Future<void> focusBox(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('market-search')));
  await tester.pump();
}

/// Types [words], waits out the pause before the suppliers are asked for, and settles.
Future<void> type(WidgetTester tester, String words) async {
  await tester.enterText(find.byKey(const ValueKey('market-search')), words);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  group('with nothing typed', () {
    testWidgets('focusing the box offers a few searches to try, and the list gives way to them', (tester) async {
      await pumpMart(tester, repo: repoWithMatches());
      expect(find.byType(SupplierCard), findsWidgets);
      await focusBox(tester);
      expect(find.text('Try searching'), findsOneWidget);
      expect(find.text('Housekeeping in Bangalore'), findsOneWidget);
      expect(find.text('Fire safety companies'), findsOneWidget);
      expect(find.text('Facility management Mumbai'), findsOneWidget);
      expect(find.text('Recent searches'), findsNothing);
      expect(find.byType(SupplierCard), findsNothing);
    });

    testWidgets('a suggestion runs as a search, fills the box and puts the list back', (tester) async {
      final mart = await pumpMart(tester, repo: repoWithMatches());
      await focusBox(tester);
      await tester.tap(find.byKey(const ValueKey('try-Fire safety companies')));
      await tester.pumpAndSettle();
      expect(mart.repo.searches.last.filters.search, 'Fire safety companies');
      expect(
        tester.widget<TextField>(find.byKey(const ValueKey('market-search'))).controller!.text,
        'Fire safety companies',
      );
      expect(find.text('Try searching'), findsNothing);
      expect(find.byType(SupplierCard), findsWidgets);
    });

    testWidgets('searches made are remembered, newest first, and offered again', (tester) async {
      final mart = await pumpMart(tester, repo: repoWithMatches());
      for (final words in ['duct', 'pest']) {
        await tester.enterText(find.byKey(const ValueKey('market-search')), words);
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(const ValueKey('market-search')));
      await tester.pump();
      // Typed words are still in the box: clear it to see the recent ones.
      await tester.enterText(find.byKey(const ValueKey('market-search')), '');
      await tester.pumpAndSettle();
      expect(find.text('Recent searches'), findsOneWidget);
      final duct = tester.getTopLeft(find.byKey(const ValueKey('recent-duct'))).dy;
      final pest = tester.getTopLeft(find.byKey(const ValueKey('recent-pest'))).dy;
      expect(pest, lessThan(duct), reason: 'the newest first');

      await tester.tap(find.byKey(const ValueKey('recent-duct')));
      await tester.pumpAndSettle();
      expect(mart.repo.searches.last.filters.search, 'duct');
    });
  });

  group('with words typed', () {
    testWidgets('one character asks for nothing; two or more read the suppliers whose name matches', (tester) async {
      final mart = await pumpMart(tester, repo: repoWithMatches());
      final before = mart.repo.searches.length;
      await type(tester, 'd');
      expect(mart.repo.searches, hasLength(before));
      expect(find.byKey(const ValueKey('search-for')), findsNothing, reason: 'one letter is too little to search for');
      expect(find.text('Try searching'), findsOneWidget);

      await type(tester, 'duct');
      expect(mart.repo.searches.last.filters.search, 'duct');
      expect(find.text('Search for "duct"'), findsOneWidget);
      expect(find.text('Suppliers'), findsOneWidget);
      expect(find.text('Duct Masters'), findsOneWidget);
      expect(find.text('HVAC duct cleaning'), findsOneWidget);
      expect(find.byKey(const ValueKey('suggest-supplier-d2')), findsOneWidget);
    });

    testWidgets('"Search for ..." runs the words as a search', (tester) async {
      final mart = await pumpMart(tester, repo: repoWithMatches());
      await type(tester, 'duct');
      await tester.tap(find.byKey(const ValueKey('search-for')));
      await tester.pumpAndSettle();
      expect(mart.market.filters.search, 'duct');
      expect(find.byType(SupplierCard), findsWidgets);
    });

    testWidgets('a supplier suggestion opens its profile', (tester) async {
      final mart = await pumpMart(tester, repo: repoWithMatches());
      await type(tester, 'duct');
      await tester.tap(find.byKey(const ValueKey('suggest-supplier-d1')));
      await tester.pumpAndSettle();
      expect(find.text('Request for Quote (RFQ)'), findsOneWidget);
      expect(mart.repo.calls, contains('supplier'));
    });

    testWidgets('a category suggestion filters the Marketplace to it', (tester) async {
      final mart = await pumpMart(tester, repo: repoWithMatches());
      await type(tester, 'hvac');
      expect(find.text('Categories'), findsOneWidget);
      expect(find.text('in Integrated Facility Management'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('suggest-category-HVAC')));
      await tester.pumpAndSettle();
      expect(mart.market.filters.categories, {'HVAC'});
      expect(mart.repo.searches.last.filters.categories, {'HVAC'});
    });

    testWidgets('the cross clears the box and searches for nothing', (tester) async {
      final mart = await pumpMart(tester, repo: repoWithMatches());
      await type(tester, 'duct');
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(mart.market.filters.search, '');
      expect(find.byType(SupplierCard), findsWidgets);
    });
  });

  group('the controller', () {
    late SpyMarketplaceRepository repo;
    late MarketplaceController market;

    setUp(() {
      repo = repoWithMatches();
      market = MarketplaceController(repo);
    });

    tearDown(() => market.dispose());

    test('the last six searches are kept, a repeat moves to the front, blanks are not kept', () {
      for (final w in ['a1', 'b2', 'c3', 'd4', 'e5', 'f6', 'g7']) {
        market.rememberSearch(w);
      }
      market.rememberSearch('  ');
      market.rememberSearch('c3');
      expect(market.recentSearches, ['c3', 'g7', 'f6', 'e5', 'd4', 'b2']);
    });

    test('an answer for words that are no longer in the box is dropped', () async {
      await market.start();
      repo.searchAnswer = (f, p) => pageWith([fakeSupplier('x-${f.search}', name: 'For ${f.search}')]);
      final slow = market.suggest('duct');
      final fast = market.suggest('ducts');
      await Future.wait([slow, fast]);
      expect(market.suggestedFor, 'ducts');
      expect(market.suggestedSuppliers.single.id, 'x-ducts');
    });

    test('words under two characters clear the suggestions', () async {
      await market.start();
      await market.suggest('duct');
      expect(market.suggestedSuppliers, isNotEmpty);
      await market.suggest('d');
      expect(market.suggestedSuppliers, isEmpty);
      expect(market.suggestedFor, '');
    });

    test('suggested suppliers stay within the member\'s trust level and are at most five', () async {
      await market.start();
      repo.searchAnswer = (f, p) => pageOf(9, total: 9, hasMore: false);
      await market.suggest('supplier');
      expect(market.suggestedSuppliers, hasLength(5));
      expect(repo.searches.last.filters.minLevel, SupplierLevel.verified);
    });

    test('categories match by name, top level and below, at most four, with the parent named', () async {
      await market.start();
      repo.treeAnswer = () => _tree;
      await market.loadCategories();
      expect(market.suggestedCategories('house').map((c) => (c.node.key, c.parent)), [
        ('HOUSEKEEPING', 'Integrated Facility Management'),
      ]);
      expect(market.suggestedCategories('security').map((c) => c.node.key), ['SECURITY']);
      expect(market.suggestedCategories('x'), isEmpty);
    });

    test('a failed read of the suggestions says nothing and leaves the last ones', () async {
      await market.start();
      await market.suggest('duct');
      final before = market.suggestedSuppliers;
      repo.failing['suppliers'] = Exception('boom');
      await market.suggest('ducts');
      expect(market.suggestedSuppliers, before);
    });
  });
}
