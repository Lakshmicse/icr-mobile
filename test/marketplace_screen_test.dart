import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/features/marketplace/catalog_models.dart';
import 'package:icr_mobile/features/marketplace/marketplace_filters.dart';
import 'package:icr_mobile/features/marketplace/marketplace_models.dart';
import 'package:icr_mobile/features/marketplace/widgets/supplier_card.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'helpers/fonts.dart';
import 'marketplace_fakes.dart';
import 'marketplace_harness.dart';

/// Every control of the Marketplace tab, tapped: what it does here, and where it
/// leaves the app. What the API does with a tap is proved in
/// `test/live/marketplace_live_test.dart`.

void main() {
  setUpAll(loadAppFonts);

  group('the title bar', () {
    testWidgets('Back goes back', (tester) async {
      final mart = await pumpMart(tester);
      await tester.tap(find.byIcon(Symbols.arrow_back));
      expect(mart.events, ['back']);
    });

    testWidgets('the bell goes where the lead sent it', (tester) async {
      final mart = await pumpMart(tester, wireNavigation: true);
      await tester.tap(find.byIcon(LucideIcons.bell));
      expect(mart.events, ['bell']);
    });

    testWidgets('with nothing wired the bell opens the notifications on the website', (tester) async {
      final mart = await pumpMart(tester);
      await tester.tap(find.byIcon(LucideIcons.bell));
      await tester.pump();
      expect(mart.links.paths, ['/notifications']);
    });

    testWidgets('the bell says how many notifications are unread', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpMart(tester);
      expect(find.bySemanticsLabel('Notifications, 1 unread'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the screen is named Marketplace', (tester) async {
      await pumpMart(tester);
      expect(find.text('Marketplace'), findsOneWidget);
    });
  });

  group('the quick chips', () {
    testWidgets('Post RFQ, My RFQ\'s and Alerts call what the lead wired', (tester) async {
      final mart = await pumpMart(tester, wireNavigation: true);
      await tester.tap(find.text('Post RFQ'));
      await tester.tap(find.text('My RFQ’s'));
      await tester.tap(find.text('Alerts'));
      expect(mart.events, ['postRfq', 'myRfqs', 'alerts']);
      expect(mart.links.opened, isEmpty);
    });

    testWidgets('with nothing wired each opens its page on the website', (tester) async {
      final mart = await pumpMart(tester);
      await tester.tap(find.text('Post RFQ'));
      await tester.tap(find.text('My RFQ’s'));
      await tester.tap(find.text('Alerts'));
      await tester.pump();
      expect(mart.links.paths, ['/quote', '/manage/requirements', '/manage/requirements']);
    });

    testWidgets('a page the phone cannot open is said so', (tester) async {
      final mart = await pumpMart(tester);
      mart.links.opens = false;
      await tester.tap(find.text('Post RFQ'));
      await tester.pump();
      expect(find.text("Couldn't open icr.org.in/quote"), findsOneWidget);
    });

    testWidgets('the numbers are the API\'s: My RFQ\'s 3 and Alerts 2 new', (tester) async {
      await pumpMart(tester);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('2 new'), findsOneWidget);
    });

    testWidgets('the numbers can come from the app\'s own source', (tester) async {
      await pumpMart(tester, start: false, counts: () async => const MarketplaceCounts(myRfqs: 12, newAlerts: 5));
      await tester.pumpAndSettle();
      expect(find.text('12'), findsOneWidget);
      expect(find.text('5 new'), findsOneWidget);
    });

    testWidgets('no number, no badge', (tester) async {
      final repo = SpyMarketplaceRepository()..countsAnswer = const MarketplaceCounts();
      await pumpMart(tester, repo: repo);
      expect(find.text('2 new'), findsNothing);
      expect(find.byType(Text).evaluate().where((e) => (e.widget as Text).data == '3'), isEmpty);
    });
  });

  group('the search', () {
    testWidgets('typing words and submitting searches the suppliers', (tester) async {
      final mart = await pumpMart(tester);
      await tester.enterText(find.byKey(const ValueKey('market-search')), 'duct care');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(mart.repo.searches.last.filters.search, 'duct care');
      expect(mart.market.filters.search, 'duct care');
    });

    testWidgets('the cross in the box clears the search and shows every supplier again', (tester) async {
      final mart = await pumpMart(tester);
      await tester.enterText(find.byKey(const ValueKey('market-search')), 'duct');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(mart.repo.searches.last.filters.search, '');
      expect(find.byType(SupplierCard), findsWidgets);
    });

    testWidgets('services and requirements the words also match are listed above the suppliers', (tester) async {
      final repo = SpyMarketplaceRepository()
        ..extrasAnswer = SearchExtras(
          services: [
            CatalogService(
              id: 'sv1',
              companyId: 'c',
              name: 'Duct care',
              supplierName: 'Vikasha',
              rate: 4500,
              rateUnit: 'per visit',
            ),
          ],
          rfqs: const [RfqHit(id: 'r1', title: 'Duct cleaning, tower B', city: 'Pune', mine: true)],
        );
      final mart = await pumpMart(tester, repo: repo);
      await tester.enterText(find.byKey(const ValueKey('market-search')), 'duct');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('Services matching "duct"'), findsOneWidget);
      expect(find.text('Duct care'), findsOneWidget);
      expect(find.text('Vikasha • ₹4,500 per visit'), findsOneWidget);
      expect(find.text('Requirements matching "duct"'), findsOneWidget);
      expect(find.text('Pune • Your requirement'), findsOneWidget);

      // A requirement opens on the website until the lead wires its page (`onOpenRfq`).
      await tester.tap(find.byKey(const ValueKey('extra-rfq-r1')));
      await tester.pump();
      expect(mart.links.paths, ['/rfq/r1']);
    });

    testWidgets('Clear filters on an empty search result empties the box too', (tester) async {
      final repo = SpyMarketplaceRepository()
        ..searchAnswer = (f, p) =>
            f.search.isEmpty ? pageOf(2, total: 2, hasMore: false) : pageOf(0, total: 0, hasMore: false);
      final mart = await pumpMart(tester, repo: repo);
      await tester.enterText(find.byKey(const ValueKey('market-search')), 'zzzz');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('No suppliers match'), findsOneWidget);
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(mart.market.filters.search, '');
      expect(tester.widget<TextField>(find.byKey(const ValueKey('market-search'))).controller!.text, '');
      expect(find.byType(SupplierCard), findsNWidgets(2));
    });
  });

  group('the order', () {
    testWidgets('Sort opens the orders, Top rated is on, and a pick reorders the list', (tester) async {
      final mart = await pumpMart(tester);
      expect(find.text('Sort Top rated'), findsOneWidget);
      await tapChip(tester, 'Sort Top rated');
      expect(find.text('Sort suppliers'), findsOneWidget);
      for (final label in [
        'Recommended',
        'Top rated',
        'Most reviewed',
        'Most projects',
        'Most experienced',
        'Newest',
      ]) {
        expect(find.byKey(ValueKey('sort-$label')), findsOneWidget, reason: label);
      }
      await tester.tap(find.byKey(const ValueKey('sort-Most reviewed')));
      await tester.pumpAndSettle();
      expect(mart.repo.searches.last.filters.sort, SupplierSort.mostReviewed);
      expect(find.text('Sort Most reviewed'), findsOneWidget);
    });

    testWidgets('closing the sheet without a pick changes nothing', (tester) async {
      final mart = await pumpMart(tester);
      final before = mart.repo.searches.length;
      await tapChip(tester, 'Sort Top rated');
      await tester.tapAt(const Offset(195, 40)); // the scrim
      await tester.pumpAndSettle();
      expect(mart.repo.searches, hasLength(before));
      expect(find.text('Sort Top rated'), findsOneWidget);
    });
  });

  group('By ratings', () {
    testWidgets('a minimum rating narrows the list and the chip says what it is set to', (tester) async {
      final mart = await pumpMart(tester);
      await tapChip(tester, 'By ratings');
      expect(find.text('Minimum rating'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('rating-4.5★ & up')));
      await tester.pumpAndSettle();
      expect(mart.repo.searches.last.filters.minRating, 4.5);
      expect(find.text('4.5★ & up'), findsOneWidget);
      expect(find.text('By ratings'), findsNothing);
    });

    testWidgets('"Any rating" takes the minimum off again', (tester) async {
      final mart = await pumpMart(tester, initial: const MarketplaceFilters(minRating: 4));
      await tapChip(tester, '4★ & up');
      await tester.tap(find.byKey(const ValueKey('rating-Any rating')));
      await tester.pumpAndSettle();
      expect(mart.repo.searches.last.filters.minRating, isNull);
      expect(find.text('By ratings'), findsOneWidget);
    });
  });

  group('Verified only', () {
    testWidgets('is on to begin with (the mart opens on verified suppliers); a tap widens to every supplier and back', (
      tester,
    ) async {
      final mart = await pumpMart(tester);
      expect(mart.repo.searches.last.filters.minLevel, SupplierLevel.verified);
      await tapChip(tester, 'Verified only');
      expect(mart.repo.searches.last.filters.minLevel, isNull);
      expect(find.textContaining('enterprise suppliers'), findsOneWidget);
      expect(find.textContaining('verified enterprise'), findsNothing);
      await tapChip(tester, 'Verified only');
      expect(mart.repo.searches.last.filters.minLevel, SupplierLevel.verified);
      expect(find.textContaining('verified enterprise suppliers'), findsOneWidget);
    });
  });

  group('the Filters sheet', () {
    testWidgets('opens with every filter, and "Filters" carries no number until one is set', (tester) async {
      await pumpMart(tester);
      expect(find.text('Filters'), findsOneWidget);
      await tapChip(tester, 'Filters');
      expect(find.text('Trust level'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('City'), findsOneWidget);
      expect(find.text('Company size'), findsOneWidget);
      expect(find.text('Registrations'), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);
      expect(find.byKey(const ValueKey('filters-apply')), findsOneWidget);
    });

    testWidgets('a category, a city, a size and GST narrow the list and count on the chip', (tester) async {
      final mart = await pumpMart(tester);
      await tapChip(tester, 'Filters');
      // Security Services opens to its sub-categories.
      await tester.tap(find.byKey(const ValueKey('open-SECURITY')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('category-PHYSICAL_SECURITY')));
      await tester.pump();
      await tester.ensureVisible(find.text('Pune'));
      await tester.tap(find.text('Pune'));
      await tester.pump();
      await tester.ensureVisible(find.text('51-200 employees'));
      await tester.tap(find.text('51-200 employees'));
      await tester.ensureVisible(find.text('GST registered'));
      await tester.tap(find.text('GST registered'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('filters-apply')));
      await tester.pumpAndSettle();

      final f = mart.repo.searches.last.filters;
      expect(f.categories, {'PHYSICAL_SECURITY'});
      expect(f.city, 'Pune');
      expect(f.sizes, {'51-200'});
      expect(f.gst, isTrue);
      expect(find.text('Filters (4)'), findsOneWidget);
    });

    testWidgets('a tap on a picked city takes it back', (tester) async {
      final mart = await pumpMart(tester, initial: const MarketplaceFilters(city: 'Pune'));
      await tapChip(tester, 'Filters (1)');
      await tester.ensureVisible(find.text('Pune'));
      await tester.tap(find.text('Pune'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('filters-apply')));
      await tester.pumpAndSettle();
      expect(mart.repo.searches.last.filters.city, isNull);
    });

    testWidgets('a trust level above Verified asks for it', (tester) async {
      final mart = await pumpMart(tester);
      await tapChip(tester, 'Filters');
      await tester.tap(find.text('Certified & up'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('filters-apply')));
      await tester.pumpAndSettle();
      expect(mart.repo.searches.last.filters.minLevel, SupplierLevel.certified);
      expect(find.text('Filters (1)'), findsOneWidget);
    });

    testWidgets('the category list can be searched', (tester) async {
      await pumpMart(tester);
      await tapChip(tester, 'Filters');
      expect(find.byKey(const ValueKey('category-MEP')), findsNothing); // the demo tree has security and FM
      await tester.enterText(find.byKey(const ValueKey('category-search')), 'hvac');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('category-HVAC')), findsOneWidget);
      expect(find.byKey(const ValueKey('category-PHYSICAL_SECURITY')), findsNothing);
      await tester.enterText(find.byKey(const ValueKey('category-search')), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('No category matches.'), findsOneWidget);
    });

    testWidgets('Clear all empties the sheet\'s choices without closing it', (tester) async {
      final mart = await pumpMart(tester, initial: const MarketplaceFilters(city: 'Pune', gst: true));
      await tapChip(tester, 'Filters (2)');
      await tester.tap(find.byKey(const ValueKey('filters-clear')));
      await tester.pump();
      expect(find.byKey(const ValueKey('filters-apply')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('filters-apply')));
      await tester.pumpAndSettle();
      final f = mart.repo.searches.last.filters;
      expect(f.city, isNull);
      expect(f.gst, isFalse);
      expect(find.text('Filters'), findsOneWidget);
    });

    testWidgets('"Only my saved suppliers" shows the saved list instead of the directory', (tester) async {
      final repo = SpyMarketplaceRepository()..savedAnswer = (p) => pageOf(2, total: 2, hasMore: false);
      final mart = await pumpMart(tester, repo: repo);
      await tapChip(tester, 'Filters');
      await tester.ensureVisible(find.text('Only my saved suppliers'));
      await tester.tap(find.text('Only my saved suppliers'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('filters-apply')));
      await tester.pumpAndSettle();
      expect(mart.repo.calls, contains('savedSuppliers'));
      expect(find.byType(SupplierCard), findsNWidgets(2));
      expect(find.text('Showing 2 of 2 saved suppliers'), findsOneWidget);
    });

    testWidgets('an empty saved list says so and offers every supplier', (tester) async {
      final repo = SpyMarketplaceRepository()..savedAnswer = (p) => pageOf(0, total: 0, hasMore: false);
      final mart = await pumpMart(tester, repo: repo, initial: const MarketplaceFilters(savedOnly: true));
      expect(find.text('No saved suppliers yet'), findsOneWidget);
      await tester.tap(find.text('Show all suppliers'));
      await tester.pumpAndSettle();
      expect(mart.market.filters.savedOnly, isFalse);
      expect(find.byType(SupplierCard), findsWidgets);
    });
  });

  group('the cards', () {
    testWidgets('each shows its logo or lockup, rating, reviews, title and two lines', (tester) async {
      await pumpMart(tester);
      expect(find.byType(SupplierCard), findsWidgets);
      expect(find.text('4.8'), findsWidgets);
      expect(find.text('(124 reviews)'), findsWidgets);
      expect(find.text('Corporate Security'), findsWidgets);
      expect(find.text('Biometric systems, CCTV & Manpower'), findsWidgets);
    });

    testWidgets('a live card draws the name beside the logo, and a tile with its initial when there is no logo', (
      tester,
    ) async {
      final repo = SpyMarketplaceRepository()
        ..searchAnswer = (f, p) => SupplierPage(
          suppliers: [
            fakeSupplier(
              'a',
              name: 'Meridian Facility Services',
              headline: null,
              about: null,
              categories: const ['HVAC'],
            ),
          ],
          total: 1,
          page: 1,
          hasMore: false,
        );
      await pumpMart(tester, repo: repo);
      expect(find.text('Meridian Facility Services'), findsOneWidget);
      expect(find.text('M'), findsOneWidget);
      // With no headline the card is titled by its main category, as the tree names it.
      expect(find.text('HVAC'), findsOneWidget);
    });

    testWidgets('a single review is not "1 reviews"', (tester) async {
      final repo = SpyMarketplaceRepository()
        ..searchAnswer = (f, p) =>
            SupplierPage(suppliers: [fakeSupplier('a', ratingCount: 1)], total: 1, page: 1, hasMore: false);
      await pumpMart(tester, repo: repo);
      expect(find.text('(1 review)'), findsOneWidget);
    });

    testWidgets('a long headline keeps to one line and a long description to two', (tester) async {
      final repo = SpyMarketplaceRepository()
        ..searchAnswer = (f, p) => SupplierPage(
          suppliers: [
            fakeSupplier(
              'a',
              headline:
                  'AI-Guided Robotic High-Rise Maintenance & Drone Facade Engineering Solutions for Tier-1 Commercial Campuses.',
              about:
                  'Revolutionizing commercial facility maintenance through DGCA-licensed robotic and drone-based cleaning solutions, completely eliminating human rigging risk.',
            ),
          ],
          total: 1,
          page: 1,
          hasMore: false,
        );
      await pumpMart(tester, repo: repo);
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(SupplierCard)).height, supplierCardBaseHeight);
    });

    testWidgets('every card is the same height, so a row is always even', (tester) async {
      await pumpMart(tester);
      final heights = {
        for (final e in find.byType(SupplierCard).evaluate()) tester.getSize(find.byWidget(e.widget)).height,
      };
      expect(heights, {supplierCardBaseHeight});
    });

    testWidgets('a tap opens the supplier profile over the list', (tester) async {
      final mart = await pumpMart(tester);
      await tester.tap(find.byType(SupplierCard).first);
      await tester.pumpAndSettle();
      expect(find.text('Request for Quote (RFQ)'), findsOneWidget);
      expect(find.text('Overview'), findsOneWidget);
      expect(mart.links.opened, isEmpty);
    });
  });

  group('the foot of the list', () {
    testWidgets('says how many are shown of how many there are, rounded down to tens', (tester) async {
      await pumpMart(tester);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('showing')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Showing 10 of 180+ verified enterprise suppliers'), findsOneWidget);
    });

    testWidgets('"Load more suppliers" brings the next page and the line follows', (tester) async {
      final repo = SpyMarketplaceRepository()
        ..searchAnswer = (f, p) => switch (p) {
          1 => pageOf(4, total: 6),
          _ => pageOf(2, from: 5, total: 6, hasMore: false, page: 2),
        };
      final mart = await pumpMart(tester, repo: repo);
      final more = find.byKey(const ValueKey('load-more'));
      await tester.scrollUntilVisible(more, 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('Showing 4 of 6 verified enterprise suppliers'), findsOneWidget);
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(mart.repo.searches.last.page, 2);
      expect(find.text('Showing 6 of 6 verified enterprise suppliers'), findsOneWidget);
      // Nothing more to load: the button goes.
      expect(find.byKey(const ValueKey('load-more')), findsNothing);
    });
  });

  group('the other states', () {
    testWidgets('loading shows placeholder cards', (tester) async {
      final gate = Completer<void>();
      final repo = SpyMarketplaceRepository()..gate = gate;
      await pumpMart(tester, repo: repo, start: false);
      expect(find.byType(SupplierCardSkeleton), findsWidgets);
      expect(find.byType(SupplierCard), findsNothing);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(SupplierCardSkeleton), findsNothing);
      expect(find.byType(SupplierCard), findsWidgets);
    });

    testWidgets('a failed load says why and Try again reads it again', (tester) async {
      final repo = SpyMarketplaceRepository()..failing['suppliers'] = ApiError("Can't reach ICR right now.");
      final mart = await pumpMart(tester, repo: repo);
      expect(find.text("Couldn't load suppliers"), findsOneWidget);
      expect(find.text("Can't reach ICR right now."), findsOneWidget);
      repo.failing.clear();
      await tester.runAsync(() async {
        await tester.tap(find.text('Try again'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      expect(mart.market.error, isNull);
      expect(find.byType(SupplierCard), findsWidgets);
    });

    testWidgets('no supplier at all says so without offering to clear anything', (tester) async {
      final repo = SpyMarketplaceRepository()..searchAnswer = (f, p) => pageOf(0, total: 0, hasMore: false);
      await pumpMart(tester, repo: repo);
      expect(find.text('No suppliers listed yet'), findsOneWidget);
      expect(find.text('Clear filters'), findsNothing);
    });

    testWidgets('a search with no match offers to clear the filters', (tester) async {
      final repo = SpyMarketplaceRepository()..searchAnswer = (f, p) => pageOf(0, total: 0, hasMore: false);
      await pumpMart(
        tester,
        repo: repo,
        initial: const MarketplaceFilters(city: 'Pune'),
      );
      expect(find.text('No suppliers match'), findsOneWidget);
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(repo.searches.last.filters.city, isNull);
    });

    testWidgets('pulling the list down reads it again', (tester) async {
      final mart = await pumpMart(tester);
      final before = mart.repo.searches.length;
      await tester.fling(find.byType(CustomScrollView), const Offset(0, 400), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(mart.repo.searches.length, before + 1);
    });
  });

  group('the columns', () {
    testWidgets('a phone draws two, a tablet three, from 600 dp wide', (tester) async {
      await pumpMart(tester);
      final phone = [
        for (final e in find.byType(SupplierCard).evaluate().take(4)) tester.getTopLeft(find.byWidget(e.widget)),
      ];
      expect(phone[0].dy, phone[1].dy);
      expect(phone[2].dy, greaterThan(phone[0].dy));
      expect(phone[0].dx, 12);
    });

    testWidgets('three columns at 600 dp and up, at the same card size', (tester) async {
      await pumpMart(tester, size: const Size(700, 1000));
      final tops = [
        for (final e in find.byType(SupplierCard).evaluate().take(4)) tester.getTopLeft(find.byWidget(e.widget)),
      ];
      expect(tops[0].dy, tops[1].dy);
      expect(tops[1].dy, tops[2].dy);
      expect(tops[3].dy, greaterThan(tops[0].dy));
      // Full-size cards: no shrinking while the cell is at least a phone card wide.
      expect(tester.getSize(find.byType(SupplierCard).first).width, greaterThanOrEqualTo(supplierCardBaseWidth));
      expect(tester.takeException(), isNull);
    });

    testWidgets('three columns on a phone\'s width shrink the card as a whole and keep its shape', (tester) async {
      await pumpMart(tester, columns: 3);
      final size = tester.getSize(find.byType(SupplierCard).first);
      expect(size.width, lessThan(supplierCardBaseWidth));
      expect(size.height / size.width, closeTo(supplierCardBaseHeight / supplierCardBaseWidth, 0.03));
      expect(tester.takeException(), isNull);
    });
  });
}
