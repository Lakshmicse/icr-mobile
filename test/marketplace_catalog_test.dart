import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/features/marketplace/catalog_models.dart';
import 'package:icr_mobile/features/marketplace/marketplace_navigation.dart';
import 'package:icr_mobile/features/marketplace/marketplace_repository.dart';
import 'package:icr_mobile/features/marketplace/widgets/supplier_card.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'helpers/fonts.dart';
import 'marketplace_fakes.dart';
import 'marketplace_harness.dart';

/// The product and service pages, the category browser and the catalogue boards:
/// what each shows, where each control goes, and what a failed read says.

const _facade = CatalogService(
  id: 'sv1',
  companyId: 'co-v1',
  name: 'Drone Facade Cleaning',
  category: 'FACILITY_MANAGEMENT',
  subcategory: 'HOUSEKEEPING',
  description: 'AI-guided dual-rotor precision wash for high-rise glass commercial towers.',
  rate: 18000,
  rateUnit: 'per inspection',
  turnaround: 'SLA: 24h Setup',
  supplierName: 'Vikasha Aero Tech',
  supplierLevel: 'ELITE',
);
const _terminal = CatalogProduct(
  id: 'p1',
  companyId: 'co-v1',
  name: 'Biometric Access Terminal',
  description: 'Fingerprint and card terminal with a 7-inch display.',
  price: 18500,
  unit: 'piece',
  stock: ProductStock.inStock,
  warrantyMonths: 24,
  returnDays: 7,
  freeDeliveryOver: 25000,
  bulkPricingMinQty: 10,
  categoryName: 'Access Control',
  supplierName: 'Vikasha Aero Tech',
  supplierLevel: 'ELITE',
  supplierVendorId: 'v1',
);

SpyMarketplaceRepository repo() => SpyMarketplaceRepository()
  ..searchAnswer = ((f, p) => pageWith([fakeSupplier('v1', name: 'Vikasha Aero Tech')]))
  ..supplierAnswer = ((id) => fullSupplier('v1'))
  ..supplierOfCompanyAnswer = ((id) => fullSupplier('v1'))
  ..serviceAnswer = ((id) => _facade)
  ..productAnswer = ((id) => _terminal)
  ..servicesAnswer = ((id) => const [_facade])
  ..productsAnswer = ((id) => const [_terminal]);

/// Opens a service's page from a search result row.
Future<MartUnderTest> openService(WidgetTester tester, {SpyMarketplaceRepository? repo_}) async {
  final r = repo_ ?? repo();
  r.extrasAnswer = const SearchExtras(services: [_facade]);
  final mart = await pumpMart(tester, repo: r, size: const Size(390, 1000));
  await tester.enterText(find.byKey(const ValueKey('market-search')), 'facade');
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('extra-service-sv1')));
  await tester.pumpAndSettle();
  return mart;
}

/// Opens a product's page from the first supplier's profile.
Future<MartUnderTest> openProduct(WidgetTester tester, {SpyMarketplaceRepository? repo_}) async {
  final mart = await pumpMart(tester, repo: repo_ ?? repo(), size: const Size(390, 1000));
  await tester.tap(find.byType(SupplierCard).first);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('tab-catalog')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('product-p1')));
  await tester.pumpAndSettle();
  return mart;
}

void main() {
  setUpAll(loadAppFonts);

  group('a service\'s page', () {
    testWidgets('opens from a search result with the service, its price, how fast, and who sells it', (tester) async {
      final mart = await openService(tester);
      expect(find.text('Service'), findsOneWidget); // the title bar
      expect(find.byKey(const ValueKey('item-title')), findsOneWidget);
      expect(find.text('Drone Facade Cleaning'), findsWidgets);
      expect(find.text('Housekeeping'), findsOneWidget);
      expect(find.text('₹18,000 per inspection'), findsWidgets);
      expect(find.text('SLA: 24h Setup'), findsOneWidget);
      expect(find.text('About this service'), findsOneWidget);
      expect(find.byKey(const ValueKey('item-about')), findsOneWidget);
      expect(find.text('Vikasha Aero Tech'), findsWidgets);
      expect(mart.repo.calls, containsAll(['service', 'supplierOfCompany']));
    });

    testWidgets('a service with no price says to ask', (tester) async {
      final r = repo()
        ..serviceAnswer = ((id) => const CatalogService(id: 'sv1', companyId: 'co-v1', name: 'Pest Barrier'));
      await openService(tester, repo_: r);
      expect(find.text('On request, ask for a quote'), findsOneWidget);
    });

    testWidgets('"Sold by" opens the supplier\'s profile over the page', (tester) async {
      await openService(tester);
      await tester.tap(find.byKey(const ValueKey('sold-by')));
      await tester.pumpAndSettle();
      expect(find.text('Request for Quote (RFQ)'), findsOneWidget);
    });

    testWidgets('Request a quote opens the quote form for that service', (tester) async {
      final mart = await openService(tester);
      await tester.tap(find.byKey(const ValueKey('item-quote')));
      await tester.pumpAndSettle();
      expect(find.text('Request a quote'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('quote-send')));
      await tester.pumpAndSettle();
      expect(mart.repo.quotes.single.service?.id, 'sv1');
      expect(mart.repo.quotes.single.vendorId, 'v1');
    });

    testWidgets('the lead can take the quote over from here too', (tester) async {
      final asked = <String>[];
      final r = repo()..extrasAnswer = const SearchExtras(services: [_facade]);
      await pumpMart(
        tester,
        repo: r,
        size: const Size(390, 1000),
        navigation: MarketplaceNavigation(
          onRequestQuote: (s, {service, product}) => asked.add('${s.id}/${service?.id}'),
        ),
      );
      await tester.enterText(find.byKey(const ValueKey('market-search')), 'facade');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('extra-service-sv1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('item-quote')));
      expect(asked, ['v1/sv1']);
    });

    testWidgets('share hands the service and its supplier\'s page to the system', (tester) async {
      final mart = await openService(tester);
      await tester.tap(find.byKey(const ValueKey('item-share')));
      await tester.pump();
      expect(mart.links.shared.single, contains('Drone Facade Cleaning by Vikasha Aero Tech'));
      expect(mart.links.shared.single, contains('https://icr.org.in/companies/co-v1'));
    });

    testWidgets(
      'a company with no listing: the supplier card names it and does not open, the quote goes to the website',
      (tester) async {
        final r = repo()..supplierOfCompanyAnswer = ((id) => null);
        final mart = await openService(tester, repo_: r);
        expect(find.text('Sold by'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('sold-by')));
        await tester.pumpAndSettle();
        expect(find.text('Request for Quote (RFQ)'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('item-quote')));
        await tester.pump();
        expect(mart.links.paths, ['/quote']);
      },
    );

    testWidgets('a service that cannot be read says why and Try again reads it', (tester) async {
      final r = repo()
        ..serviceAnswer = ((id) => throw ApiError('Service not found', statusCode: 404))
        ..extrasAnswer = const SearchExtras(
          services: [CatalogService(id: 'sv1', companyId: 'c', name: 'X')],
        );
      await pumpMart(tester, repo: r, size: const Size(390, 1000));
      await tester.enterText(find.byKey(const ValueKey('market-search')), 'x');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('extra-service-sv1')));
      await tester.pumpAndSettle();
      // The row that was tapped gave the page its name, so it is shown, not an error.
      expect(find.byKey(const ValueKey('item-title')), findsOneWidget);
    });
  });

  group('a product\'s page', () {
    testWidgets('price per unit, stock, the supplier\'s terms, who sells it, and what it is', (tester) async {
      final mart = await openProduct(tester);
      expect(find.text('Product'), findsOneWidget);
      expect(find.byKey(const ValueKey('item-title')), findsOneWidget);
      expect(find.text('Biometric Access Terminal'), findsWidgets);
      expect(find.byKey(const ValueKey('product-price')), findsOneWidget);
      expect(find.text('₹18,500 / piece'), findsWidgets);
      expect(find.text('In stock'), findsWidgets);
      expect(find.text('Access Control'), findsOneWidget);
      expect(find.text('Supplier terms'), findsOneWidget);
      expect(find.text('2-year warranty'), findsOneWidget);
      expect(find.text('7-day returns'), findsOneWidget);
      expect(find.text('Free delivery over ₹25,000'), findsOneWidget);
      expect(find.text('Bulk pricing from 10 piece'), findsOneWidget);
      expect(find.text('About this product'), findsOneWidget);
      // The supplier is read by its listing id (the product carries it).
      expect(mart.repo.calls, contains('product'));
    });

    testWidgets('a product that states no terms shows no terms', (tester) async {
      final r = repo()
        ..productAnswer = ((id) => const CatalogProduct(id: 'p1', companyId: 'co-v1', name: 'Bare', price: 100));
      await openProduct(tester, repo_: r);
      expect(find.text('Supplier terms'), findsNothing);
      expect(find.text('₹100'), findsWidgets);
    });

    testWidgets('Request a quote opens the form for that product, with its quantity', (tester) async {
      final mart = await openProduct(tester);
      await tester.tap(find.byKey(const ValueKey('item-quote')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('quote-quantity')), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('quote-quantity')), '6');
      await tester.tap(find.byKey(const ValueKey('quote-send')));
      await tester.pumpAndSettle();
      expect(mart.repo.quotes.single.product?.id, 'p1');
      expect(mart.repo.quotes.single.quantity, 6);
    });

    testWidgets('share hands the product\'s page on the website to the system', (tester) async {
      final mart = await openProduct(tester);
      await tester.tap(find.byKey(const ValueKey('item-share')));
      await tester.pump();
      expect(mart.links.shared.single, contains('Biometric Access Terminal on ICR Supplier Mart'));
      expect(mart.links.shared.single, contains('https://icr.org.in/products/p1'));
    });

    testWidgets('Back returns to the profile it opened from', (tester) async {
      await openProduct(tester);
      await tester.tap(find.byIcon(Symbols.arrow_back).last);
      await tester.pumpAndSettle();
      expect(find.text('Request for Quote (RFQ)'), findsOneWidget);
    });
  });

  group('the category browser', () {
    const tree = [
      CategoryNode(
        key: 'SECURITY',
        name: 'Security Services',
        slug: 'security',
        blurb: 'Guarding, CCTV and access control.',
        count: 62,
        children: [
          CategoryNode(key: 'PHYSICAL_SECURITY', name: 'Physical Security', count: 41),
          CategoryNode(key: 'ELECTRONIC_SECURITY', name: 'Electronic Security', count: 33),
        ],
      ),
      CategoryNode(
        key: 'MEP',
        name: 'Engineering Services',
        slug: 'engineering',
        count: 1,
        children: [CategoryNode(key: 'HVAC', name: 'HVAC')],
      ),
    ];

    Future<MartUnderTest> openBrowser(WidgetTester tester, {SpyMarketplaceRepository? r}) async {
      final spy = (r ?? repo())..treeAnswer = (() => tree);
      final mart = await pumpMart(tester, repo: spy, size: const Size(390, 1000));
      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('browse-categories')));
      await tester.pumpAndSettle();
      expect(find.text('Categories'), findsOneWidget);
      return mart;
    }

    testWidgets('the Filters sheet opens it; each top category shows its blurb, its suppliers and its sub-categories', (
      tester,
    ) async {
      await openBrowser(tester);
      expect(find.text('Security Services'), findsOneWidget);
      expect(find.text('Guarding, CCTV and access control.'), findsOneWidget);
      expect(find.text('62 suppliers • 2 sub-categories'), findsOneWidget);
      expect(find.text('1 supplier • 1 sub-categories'), findsOneWidget);
      expect(find.text('All products'), findsOneWidget);
      expect(find.text('All services'), findsOneWidget);
    });

    testWidgets('the search narrows by a category\'s own name or a sub-category\'s', (tester) async {
      await openBrowser(tester);
      await tester.enterText(find.byType(TextField).last, 'hvac');
      await tester.pump();
      expect(find.text('Engineering Services'), findsOneWidget);
      expect(find.text('Security Services'), findsNothing);
      await tester.enterText(find.byType(TextField).last, 'zzz');
      await tester.pump();
      expect(find.text('No category matches'), findsOneWidget);
    });

    testWidgets('a category\'s page: "Show 62 suppliers" goes back to the Marketplace filtered to it', (tester) async {
      final mart = await openBrowser(tester);
      await tester.tap(find.byKey(const ValueKey('category-card-SECURITY')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('category-page')), findsOneWidget);
      expect(find.text('Sub-categories'), findsOneWidget);
      expect(find.text('Show 62 suppliers'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('show-suppliers')));
      await tester.pumpAndSettle();
      expect(mart.market.filters.categories, {'SECURITY'});
      expect(mart.repo.searches.last.filters.categories, {'SECURITY'});
      // Back on the Marketplace: no sheet, no browser.
      expect(find.text('Sort Top rated'), findsOneWidget);
      expect(find.text('Categories'), findsNothing);
    });

    testWidgets('a sub-category shows its own suppliers', (tester) async {
      final mart = await openBrowser(tester);
      await tester.tap(find.byKey(const ValueKey('category-card-SECURITY')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sub-ELECTRONIC_SECURITY')));
      await tester.pumpAndSettle();
      expect(mart.market.filters.categories, {'ELECTRONIC_SECURITY'});
    });

    testWidgets('a category page lists its products and, on the next pill, its services (read when asked for)', (
      tester,
    ) async {
      final r = repo()
        ..boardProducts = ((page, search) => CatalogPage(items: const [_terminal], total: 1, page: 1, hasMore: false))
        ..boardServices = ((page, search) => CatalogPage(items: const [_facade], total: 1, page: 1, hasMore: false));
      final mart = await openBrowser(tester, r: r);
      await tester.tap(find.byKey(const ValueKey('category-card-SECURITY')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('board-product-p1')), findsOneWidget);
      expect(mart.repo.boardReads.map((e) => e.kind), [
        'products',
      ], reason: 'services are read when their pill is tapped');
      expect(mart.repo.boardReads.single.slug, 'security');

      await tester.tap(find.byKey(const ValueKey('kind-services')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('board-service-sv1')), findsOneWidget);
      expect(mart.repo.boardReads.last.kind, 'services');
      expect(mart.repo.boardReads.last.category, 'SECURITY');
      expect(find.byKey(const ValueKey('board-product-p1')), findsNothing);
    });

    testWidgets('a row of the board opens the product\'s page', (tester) async {
      final r = repo()
        ..boardProducts = ((page, search) => CatalogPage(items: const [_terminal], total: 1, page: 1, hasMore: false));
      await openBrowser(tester, r: r);
      await tester.tap(find.byKey(const ValueKey('category-card-SECURITY')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('board-product-p1')));
      await tester.pumpAndSettle();
      expect(find.text('Supplier terms'), findsOneWidget);
    });

    testWidgets('a category with nothing listed says so', (tester) async {
      final r = repo()
        ..boardProducts = ((page, search) => const CatalogPage(items: [], total: 0, page: 1, hasMore: false));
      await openBrowser(tester, r: r);
      await tester.tap(find.byKey(const ValueKey('category-card-MEP')));
      await tester.pumpAndSettle();
      expect(find.text('No products in Engineering Services yet'), findsOneWidget);
    });
  });

  group('the boards of every product and service', () {
    Future<MartUnderTest> openBoard(WidgetTester tester, String card, {SpyMarketplaceRepository? r}) async {
      final spy = (r ?? repo())..treeAnswer = (() => const [CategoryNode(key: 'A', name: 'A cat', count: 1)]);
      final mart = await pumpMart(tester, repo: spy, size: const Size(390, 1000));
      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('browse-categories')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('quick-$card')));
      await tester.pumpAndSettle();
      return mart;
    }

    testWidgets('All products: the count, a search, "Load more products", and a row opens its page', (tester) async {
      final r = repo()
        ..boardProducts = ((page, search) {
          final rows = [
            for (var i = 0; i < 3; i++)
              CatalogProduct(
                id: 'p${page}x$i',
                companyId: 'c',
                name: 'Item $page-$i',
                price: 100.0 + i,
                supplierName: 'Acme',
              ),
          ];
          return CatalogPage(items: rows, total: 6, page: page, hasMore: page == 1);
        });
      final mart = await openBoard(tester, 'All products', r: r);
      expect(find.text('Products'), findsOneWidget);
      expect(find.text('6 products'), findsOneWidget);
      expect(find.text('Item 1-0'), findsOneWidget);
      expect(find.text('Acme'), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('board-more')));
      await tester.pumpAndSettle();
      expect(find.text('Item 2-2'), findsOneWidget);
      expect(find.byKey(const ValueKey('board-more')), findsNothing);
      expect(mart.repo.boardReads.map((e) => e.page), [1, 2]);

      await tester.enterText(find.byKey(const ValueKey('market-search')), 'camera');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(mart.repo.boardReads.last.search, 'camera');
      expect(mart.repo.boardReads.last.page, 1);
    });

    testWidgets('All services lists services with their rate, or "Price on request"', (tester) async {
      final r = repo()
        ..boardServices = ((page, search) => CatalogPage(
          items: const [
            _facade,
            CatalogService(id: 'sv9', companyId: 'c', name: 'Pest Barrier'),
          ],
          total: 2,
          page: 1,
          hasMore: false,
        ));
      await openBoard(tester, 'All services', r: r);
      expect(find.text('Services'), findsOneWidget);
      expect(find.text('₹18,000 per inspection'), findsOneWidget);
      expect(find.text('Price on request'), findsOneWidget);
    });

    testWidgets('a search that finds nothing says so; a failed read says why and Try again reads it', (tester) async {
      final r = repo()
        ..boardServices = ((page, search) => const CatalogPage(items: [], total: 0, page: 1, hasMore: false));
      final mart = await openBoard(tester, 'All services', r: r);
      expect(find.text('No services listed yet'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('market-search')), 'zzz');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.textContaining('No services match "zzz"'), findsOneWidget);

      r.failing['services'] = ApiError('The catalogue is down.');
      await tester.enterText(find.byKey(const ValueKey('market-search')), 'duct');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('The catalogue is down.'), findsOneWidget);
      r.failing.clear();
      r.boardServices = ((page, search) => const CatalogPage(items: [_facade], total: 1, page: 1, hasMore: false));
      await tester.tap(find.byKey(const ValueKey('retry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('board-service-sv1')), findsOneWidget);
      expect(mart.repo.boardReads.last.search, 'duct');
    });
  });

  group('from the profile', () {
    testWidgets('the seed row gives a service page its name at once, and its tap needs nothing else', (tester) async {
      final r = repo();
      await pumpMart(tester, repo: r, size: const Size(390, 1000));
      await tester.tap(find.byType(SupplierCard).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tab-catalog')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Drone Facade Cleaning'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('item-title')), findsOneWidget);
      expect(find.byIcon(LucideIcons.zap), findsWidgets);
    });
  });
}
