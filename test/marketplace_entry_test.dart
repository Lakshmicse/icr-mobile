import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/marketplace/marketplace_controller.dart';
import 'package:icr_mobile/features/marketplace/marketplace_models.dart';
import 'package:icr_mobile/features/marketplace/marketplace_navigation.dart';
import 'package:icr_mobile/features/marketplace/marketplace_repository.dart';
import 'package:icr_mobile/features/marketplace/supplier_controller.dart';
import 'package:icr_mobile/features/marketplace/supplier_sheet.dart';
import 'package:provider/provider.dart';

import 'helpers/fonts.dart';
import 'marketplace_fakes.dart';

/// The doors for the rest of the app: a supplier's profile by its listing id or its
/// company's id, from a screen that is not the Marketplace (the requirements, a job's
/// company link, a notification).

const _vendorId = 'v7';

SpyMarketplaceRepository repoWithListing() => SpyMarketplaceRepository()
  ..supplierAnswer = ((id) => fullSupplier(id))
  ..supplierOfCompanyAnswer = ((companyId) => companyId == 'co-none' ? null : fullSupplier(_vendorId))
  ..compliancesAnswer = ((id) => const [])
  ..servicesAnswer = ((id) => const [])
  ..productsAnswer = ((id) => const []);

/// A page that is not the Marketplace, with one button that runs [open].
Future<void> pumpHost(
  WidgetTester tester, {
  required SpyMarketplaceRepository repo,
  required Future<void> Function(BuildContext context) open,
  bool provideRepository = true,
}) async {
  tester.view.physicalSize = const Size(390, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  Widget home = Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: TextButton(key: const ValueKey('open'), onPressed: () => open(context), child: const Text('Open')),
      ),
    ),
  );
  if (provideRepository) home = Provider<MarketplaceRepository>.value(value: repo, child: home);
  await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: home));
}

Finder get _sheet => find.byKey(const ValueKey('request-quote'));

void main() {
  setUpAll(loadAppFonts);

  group('by listing id', () {
    testWidgets('reads the listing and opens the same profile sheet the Marketplace opens', (tester) async {
      final repo = repoWithListing();
      await pumpHost(tester, repo: repo, open: (c) => showSupplierSheetById(c, _vendorId));
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();
      expect(_sheet, findsOneWidget);
      expect(find.text('Vikasha Aero Tech'), findsOneWidget);
      expect(find.text('Request for Quote (RFQ)'), findsOneWidget);
      expect(repo.calls.where((c) => c == 'supplier').length, greaterThanOrEqualTo(1));
    });

    testWidgets('opens on the tab it is asked for, reading that tab\'s part', (tester) async {
      final repo = repoWithListing();
      await pumpHost(
        tester,
        repo: repo,
        open: (c) => showSupplierSheetById(c, _vendorId, tab: SupplierTab.proofs),
      );
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('compliances'));
      expect(repo.calls, isNot(contains('servicesOf')));
    });

    testWidgets('the bookmark starts as the member left it', (tester) async {
      final repo = repoWithListing();
      await repo.setSaved(_vendorId, true);
      await pumpHost(tester, repo: repo, open: (c) => showSupplierSheetById(c, _vendorId));
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
    });

    testWidgets('the bookmark works from here: the API is asked', (tester) async {
      final repo = repoWithListing();
      await pumpHost(tester, repo: repo, open: (c) => showSupplierSheetById(c, _vendorId));
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.bookmark_border));
      await tester.pumpAndSettle();
      expect(repo.saves, [(id: _vendorId, saved: true)]);
    });

    testWidgets('a listing that cannot be read: the API\'s sentence in a message, no sheet', (tester) async {
      final repo = repoWithListing()..failing['supplier'] = ApiError('Vendor not found', statusCode: 404);
      await pumpHost(tester, repo: repo, open: (c) => showSupplierSheetById(c, 'gone'));
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();
      expect(find.text('Vendor not found'), findsOneWidget);
      expect(_sheet, findsNothing);
    });

    testWidgets('the hand-overs it is given go with the sheet: Message calls the lead\'s screen', (tester) async {
      final messaged = <String>[];
      final repo = repoWithListing();
      await pumpHost(
        tester,
        repo: repo,
        open: (c) => showSupplierSheetById(
          c,
          _vendorId,
          navigation: MarketplaceNavigation(onMessage: (s) => messaged.add(s.id)),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('message-supplier')));
      await tester.pumpAndSettle();
      expect(messaged, [_vendorId]);
    });

    testWidgets('the links it is given carry the calls: a website, recorded', (tester) async {
      final links = RecordingLinks();
      final repo = repoWithListing();
      await pumpHost(
        tester,
        repo: repo,
        open: (c) => showSupplierSheetById(c, _vendorId, links: links),
      );
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('message-supplier')));
      await tester.pumpAndSettle();
      // No conversation wired: the website's thread, through the links it was given.
      expect(links.paths, ['/messaging?c=conversation-$_vendorId']);
    });

    testWidgets('a repository passed in is used in place of the app\'s', (tester) async {
      final mine = repoWithListing();
      final apps = repoWithListing();
      await pumpHost(
        tester,
        repo: apps,
        open: (c) => showSupplierSheetById(c, _vendorId, repository: mine),
      );
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();
      expect(mine.calls, contains('supplier'));
      expect(apps.calls, isEmpty);
    });

    testWidgets('inside the Marketplace it shares the list\'s controller: a bookmark moves the list', (tester) async {
      final repo = repoWithListing();
      final market = MarketplaceController(repo);
      addTearDown(market.dispose);
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ChangeNotifierProvider.value(
            value: market,
            child: Builder(
              builder: (context) => TextButton(
                key: const ValueKey('open'),
                onPressed: () => showSupplierSheetById(context, _vendorId),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.bookmark_border));
      await tester.pumpAndSettle();
      expect(market.isSaved(_vendorId), isTrue);
    });
  });

  group('by company id', () {
    testWidgets('opens the company\'s supplier listing', (tester) async {
      final repo = repoWithListing();
      await pumpHost(tester, repo: repo, open: (c) => showSupplierSheetForCompany(c, 'co-1'));
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('supplierOfCompany'));
      expect(_sheet, findsOneWidget);
      expect(find.text('Vikasha Aero Tech'), findsOneWidget);
    });

    testWidgets('a company that does not sell on ICR says so, and nothing opens', (tester) async {
      final repo = repoWithListing();
      await pumpHost(tester, repo: repo, open: (c) => showSupplierSheetForCompany(c, 'co-none'));
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();
      expect(find.text('This company has no supplier listing.'), findsOneWidget);
      expect(_sheet, findsNothing);
    });

    testWidgets('a company that cannot be read: the API\'s sentence', (tester) async {
      final repo = repoWithListing()..failing['supplierOfCompany'] = ApiError('Please try again.', statusCode: 503);
      await pumpHost(tester, repo: repo, open: (c) => showSupplierSheetForCompany(c, 'co-1'));
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();
      expect(find.text('Please try again.'), findsOneWidget);
      expect(_sheet, findsNothing);
    });
  });

  group('a profile seeded with only a listing id', () {
    test('reads the listing first, then the tab with the company it names', () async {
      final asked = <String>[];
      final repo = SpyMarketplaceRepository()
        ..supplierAnswer = ((id) => fullSupplier(id))
        ..servicesAnswer = ((companyId) {
          asked.add('servicesOf:$companyId');
          return const [];
        })
        ..productsAnswer = ((companyId) {
          asked.add('productsOf:$companyId');
          return const [];
        });
      final controller = SupplierController(
        repository: repo,
        seed: const Supplier(id: 'v9', companyId: '', name: ''),
        tab: SupplierTab.catalog,
      );
      addTearDown(controller.dispose);
      await controller.load();
      expect(repo.calls.first, 'supplier');
      expect(asked, unorderedEquals(['servicesOf:co-v9', 'productsOf:co-v9']));
      expect(controller.supplier.name, 'Vikasha Aero Tech');
    });

    test('and if the listing cannot be read, no tab is asked for with an empty company', () async {
      final repo = SpyMarketplaceRepository()..failing['supplier'] = ApiError('Vendor not found', statusCode: 404);
      final controller = SupplierController(
        repository: repo,
        seed: const Supplier(id: 'v9', companyId: '', name: ''),
        tab: SupplierTab.proofs,
      );
      addTearDown(controller.dispose);
      await controller.load();
      expect(repo.calls, ['supplier']);
      expect(controller.detail.error, 'Vendor not found');
    });

    test('a seed that already names its company reads the listing and the tab together', () async {
      final repo = SpyMarketplaceRepository()
        ..supplierAnswer = ((id) => fullSupplier(id))
        ..compliancesAnswer = ((id) => const []);
      final controller = SupplierController(repository: repo, seed: fakeSupplier('v9'), tab: SupplierTab.proofs);
      addTearDown(controller.dispose);
      await controller.load();
      expect(repo.calls, unorderedEquals(['supplier', 'compliances']));
    });
  });
}
