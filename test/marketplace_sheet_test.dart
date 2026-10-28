import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/features/marketplace/catalog_models.dart';
import 'package:icr_mobile/features/marketplace/marketplace_models.dart';
import 'package:icr_mobile/features/marketplace/marketplace_navigation.dart';
import 'package:icr_mobile/features/marketplace/supplier_sheet.dart';
import 'package:icr_mobile/features/marketplace/widgets/supplier_card.dart';
import 'package:icr_mobile/features/marketplace/widgets/supplier_proofs_tab.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'helpers/fonts.dart';
import 'marketplace_fakes.dart';
import 'marketplace_harness.dart';

/// Every control of a supplier's profile sheet, tapped: what it does here, and
/// where it leaves the app. What the API does with a tap is proved in
/// `test/live/marketplace_live_test.dart`.

const _supplierId = 'v1';

/// A repository whose one listing is [full], opened from its card.
SpyMarketplaceRepository repoWith(
  Supplier full, {
  List<Compliance>? compliances,
  List<CatalogService>? services,
  List<CatalogProduct>? products,
}) {
  final repo = SpyMarketplaceRepository()
    ..searchAnswer = ((f, p) => pageWith([fakeSupplier(full.id, name: full.name)]))
    ..supplierAnswer = ((id) => full)
    ..compliancesAnswer = ((id) => compliances ?? const [])
    ..servicesAnswer = ((id) => services ?? const [])
    ..productsAnswer = ((id) => products ?? const []);
  return repo;
}

/// Opens the first card's profile sheet.
Future<MartUnderTest> openSheet(
  WidgetTester tester, {
  SpyMarketplaceRepository? repo,
  bool wire = false,
  MarketplaceNavigation navigation = MarketplaceNavigation.none,
}) async {
  final mart = await pumpMart(
    tester,
    repo: repo ?? repoWith(fullSupplier(_supplierId)),
    size: const Size(390, 1000),
    wireNavigation: wire,
    navigation: navigation,
  );
  await tester.tap(find.byType(SupplierCard).first);
  await tester.pumpAndSettle();
  return mart;
}

/// A finder limited to the open profile sheet (the list behind it has the same names).
Finder inSheet(Finder finder) => find.descendant(of: find.byType(SupplierSheetFrame), matching: finder);

Finder get _sheetScroll =>
    find.descendant(of: find.byKey(const ValueKey('supplier-scroll')), matching: find.byType(Scrollable)).first;

Future<void> scrollSheetTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200, scrollable: _sheetScroll);
  await tester.pumpAndSettle();
}

Future<void> openTab(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(ValueKey('tab-$name')));
  await tester.pumpAndSettle();
}

const _service = CatalogService(
  id: 'sv1',
  companyId: 'co-v1',
  name: 'Drone Facade Cleaning',
  category: 'FACILITY_MANAGEMENT',
  subcategory: 'HOUSEKEEPING',
  description: 'AI-guided dual-rotor precision wash for high-rise glass commercial towers up to 150m.',
  turnaround: 'SLA: 24h Setup',
);
const _bookable = CatalogService(
  id: 'sv2',
  companyId: 'co-v1',
  name: 'Robotic HVAC Inspection',
  category: 'FACILITY_MANAGEMENT',
  subcategory: 'HVAC',
  description: 'Remote camera crawler with HEPA extraction.',
  rate: 18000,
  rateUnit: 'per inspection',
);
const _product = CatalogProduct(
  id: 'p1',
  companyId: 'co-v1',
  name: 'Biometric Access Terminal',
  description: 'Fingerprint and card terminal.',
  price: 18500,
  unit: 'piece',
  stock: ProductStock.inStock,
);

void main() {
  setUpAll(loadAppFonts);

  group('opening a supplier', () {
    testWidgets('a tap on a card opens its profile over the list and reads the full listing', (tester) async {
      final mart = await openSheet(tester);
      expect(inSheet(find.text('Vikasha Aero Tech')), findsOneWidget);
      expect(find.text('Request for Quote (RFQ)'), findsOneWidget);
      expect(mart.repo.calls.where((c) => c == 'supplier'), hasLength(1));
      // The list is still behind it: nothing else was opened.
      expect(mart.links.opened, isEmpty);
    });

    testWidgets('the header: name and seal, how it is incorporated, rating, tier, pitch', (tester) async {
      await openSheet(tester);
      expect(inSheet(find.text('Vikasha Aero Tech')), findsOneWidget);
      expect(find.byIcon(LucideIcons.badgeCheck), findsWidgets);
      expect(find.text('Pvt Ltd • Reg. CIN-U74999KA2019PTC1'), findsOneWidget);
      expect(inSheet(find.text('4.9')), findsOneWidget);
      expect(find.text('84 Enterprise Reviews'), findsOneWidget);
      expect(find.text('Tier-1'), findsOneWidget);
      expect(inSheet(find.text('AI-Guided Robotic High-Rise Maintenance.')), findsOneWidget);
    });

    testWidgets('a supplier that is only Registered has no seal and no tier, and one with no ratings says so', (
      tester,
    ) async {
      final plain = Supplier(
        id: _supplierId,
        companyId: 'co-v1',
        name: 'Plain Co',
        level: SupplierLevel.registered,
        detailed: true,
      );
      await openSheet(tester, repo: repoWith(plain));
      expect(inSheet(find.text('Plain Co')), findsOneWidget);
      expect(find.text('No ratings yet'), findsOneWidget);
      expect(find.textContaining('Tier-'), findsNothing);
      expect(find.textContaining('Reg.'), findsNothing);
      expect(find.byKey(const ValueKey('call-hq')), findsOneWidget);
    });
  });

  group('Call HQ, WhatsApp, Website', () {
    testWidgets('each goes where it says: the dialler, a WhatsApp chat, the supplier\'s own site', (tester) async {
      final mart = await openSheet(tester);
      await tester.tap(find.byKey(const ValueKey('call-hq')));
      await tester.tap(find.byKey(const ValueKey('whatsapp')));
      await tester.tap(find.byKey(const ValueKey('website')));
      await tester.pump();
      expect(mart.links.outside[0], 'tel:+918040001100');
      expect(mart.links.outside[1], startsWith('https://wa.me/918040001100?text='));
      expect(
        Uri.decodeQueryComponent(mart.links.outside[1].split('text=').last).replaceAll('+', ' '),
        contains('Vikasha Aero Tech'),
      );
      expect(mart.links.outside[2], 'https://vikasha.example.in');
    });

    testWidgets('a supplier with no number or site says so instead of doing nothing', (tester) async {
      final mart = await openSheet(
        tester,
        repo: repoWith(fullSupplier(_supplierId, phone: null, website: null, hubs: const [])),
      );
      await tester.tap(find.byKey(const ValueKey('call-hq')));
      await tester.pump();
      expect(find.text('This supplier has not listed a phone number.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('website')));
      await tester.pump();
      expect(find.text('This supplier has not listed a website.'), findsOneWidget);
      expect(mart.links.opened, isEmpty);
    });

    testWidgets('a phone that cannot make the call is said so', (tester) async {
      final mart = await openSheet(tester);
      mart.links.opens = false;
      await tester.tap(find.byKey(const ValueKey('call-hq')));
      await tester.pump();
      expect(find.textContaining("Couldn't open"), findsOneWidget);
    });
  });

  group('save and share', () {
    testWidgets('the bookmark saves the supplier (the API is asked, the list behind follows)', (tester) async {
      final mart = await openSheet(tester);
      expect(mart.market.isSaved(_supplierId), isFalse);
      await tester.tap(find.byKey(const ValueKey('supplier-save')));
      await tester.pumpAndSettle();
      expect(mart.repo.saves.single, (id: _supplierId, saved: true));
      expect(mart.market.isSaved(_supplierId), isTrue);
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('supplier-save')));
      await tester.pumpAndSettle();
      expect(mart.repo.saves.last, (id: _supplierId, saved: false));
      expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
    });

    testWidgets('a bookmark the API refuses is taken back and says why', (tester) async {
      final repo = repoWith(fullSupplier(_supplierId))
        ..failing['setSaved'] = ApiError('Sign in to save suppliers.', statusCode: 401);
      final mart = await openSheet(tester, repo: repo);
      await tester.tap(find.byKey(const ValueKey('supplier-save')));
      await tester.pumpAndSettle();
      expect(find.text('Sign in to save suppliers.'), findsOneWidget);
      expect(mart.market.isSaved(_supplierId), isFalse);
      expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
    });

    testWidgets('a supplier already saved opens with its bookmark filled', (tester) async {
      final repo = repoWith(fullSupplier(_supplierId));
      await repo.setSaved(_supplierId, true);
      await openSheet(tester, repo: repo);
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
    });

    testWidgets('share hands the supplier\'s name and its page on the website to the system', (tester) async {
      final mart = await openSheet(tester);
      await tester.tap(find.byKey(const ValueKey('supplier-share')));
      await tester.pump();
      expect(mart.links.shared.single, contains('Vikasha Aero Tech'));
      expect(mart.links.shared.single, contains('https://icr.org.in/companies/co-$_supplierId'));
    });
  });

  group('the three tabs', () {
    testWidgets('only the open tab is read; each other tab is read the first time it is opened, once', (tester) async {
      final mart = await openSheet(
        tester,
        repo: repoWith(fullSupplier(_supplierId), services: [_service], compliances: const []),
      );
      expect(mart.repo.calls, isNot(contains('servicesOf')));
      expect(mart.repo.calls, isNot(contains('compliances')));

      await openTab(tester, 'catalog');
      expect(mart.repo.calls.where((c) => c == 'servicesOf'), hasLength(1));
      expect(mart.repo.calls.where((c) => c == 'productsOf'), hasLength(1));
      expect(mart.repo.calls, isNot(contains('compliances')));

      await openTab(tester, 'proofs');
      expect(mart.repo.calls.where((c) => c == 'compliances'), hasLength(1));

      await openTab(tester, 'catalog');
      await openTab(tester, 'overview');
      await openTab(tester, 'proofs');
      expect(mart.repo.calls.where((c) => c == 'servicesOf'), hasLength(1));
      expect(mart.repo.calls.where((c) => c == 'compliances'), hasLength(1));
    });
  });

  group('Overview', () {
    testWidgets('the track record: what the listing can back, in tiles', (tester) async {
      await openSheet(tester);
      expect(find.text('Enterprise Track Record'), findsOneWidget);
      expect(find.text('150+'), findsOneWidget);
      expect(find.text('Projects Executed'), findsOneWidget);
      expect(find.text('7'), findsWidgets);
      expect(find.text('Years of Experience'), findsOneWidget);
      expect(find.text('2 Hubs'), findsOneWidget);
    });

    testWidgets('a short description is shown whole; a long one is two lines with "Read full company charter"', (
      tester,
    ) async {
      await openSheet(tester);
      expect(find.byKey(const ValueKey('charter')), findsNothing);

      final long =
          'Revolutionizing commercial facility maintenance through DGCA-licensed robotic and drone-based cleaning solutions, ' *
          4;
      await tester.pumpWidget(const SizedBox());
      await openSheet(tester, repo: repoWith(fullSupplier(_supplierId, about: long)));
      await scrollSheetTo(tester, find.byKey(const ValueKey('about')));
      final collapsed = tester.getSize(find.byKey(const ValueKey('about'))).height;
      expect(find.text('Read full company charter'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('charter')));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(const ValueKey('about'))).height, greaterThan(collapsed * 2));
      expect(find.text('Show less'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('charter')));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(const ValueKey('about'))).height, collapsed);
    });

    testWidgets('the hubs band reads the offices, and View Hubs lists them with a number to call and a map', (
      tester,
    ) async {
      final mart = await openSheet(tester);
      await scrollSheetTo(tester, find.byKey(const ValueKey('view-hubs')));
      expect(find.text('2 Operational Hubs'), findsOneWidget);
      expect(find.textContaining('Bengaluru • Pune'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('view-hubs')));
      await tester.pumpAndSettle();
      expect(find.text('Vikasha Aero Tech offices'), findsOneWidget);
      expect(find.text('Bengaluru HQ'), findsOneWidget);
      expect(find.text('Head office'), findsOneWidget);
      expect(find.text('Pune Hub'), findsOneWidget);
      // The head office is listed first.
      expect(tester.getTopLeft(find.text('Bengaluru HQ')).dy, lessThan(tester.getTopLeft(find.text('Pune Hub')).dy));

      await tester.tap(find.byKey(const ValueKey('hub-call-h2')));
      await tester.pump();
      expect(mart.links.outside.last, 'tel:+912040001300');
      await tester.tap(find.byKey(const ValueKey('hub-map-h1')));
      await tester.pump();
      expect(mart.links.outside.last, 'https://www.google.com/maps/search/?api=1&query=12.97%2C77.59');
    });

    testWidgets('good to know: only the facts the listing declares', (tester) async {
      await openSheet(tester);
      await scrollSheetTo(tester, find.text('Good to know'));
      expect(find.text('2019'), findsOneWidget);
      expect(find.text('51-200 employees'), findsOneWidget);
      expect(find.text('Within 4 hours'), findsOneWidget);
      expect(find.text('Open for new work'), findsOneWidget);
      expect(find.text('Bengaluru, Pune'), findsOneWidget);
    });

    testWidgets('a supplier with one office has no hubs band', (tester) async {
      final solo = fullSupplier(
        _supplierId,
        hubs: const [SupplierHub(id: 'h', name: 'HQ', city: 'Pune', headOffice: true)],
      );
      await openSheet(tester, repo: repoWith(solo));
      expect(find.byKey(const ValueKey('view-hubs')), findsNothing);
    });

    testWidgets('a listing that cannot be read says why and Try again reads it', (tester) async {
      final repo = repoWith(fullSupplier(_supplierId))..failing['supplier'] = ApiError("Can't reach ICR right now.");
      final mart = await openSheet(tester, repo: repo);
      expect(find.text("Can't reach ICR right now."), findsOneWidget);
      expect(find.text('Enterprise Track Record'), findsNothing);
      repo.failing.clear();
      await tester.tap(find.byKey(const ValueKey('retry')));
      await tester.pumpAndSettle();
      expect(find.text("Can't reach ICR right now."), findsNothing);
      expect(find.text('Enterprise Track Record'), findsOneWidget);
      expect(mart.repo.calls.where((c) => c == 'supplier'), hasLength(2));
    });
  });

  group('Products & services', () {
    testWidgets('chips for each kind, the rows of the open kind, and "All (n)" counts everything', (tester) async {
      await openSheet(
        tester,
        repo: repoWith(fullSupplier(_supplierId), services: [_service, _bookable], products: [_product]),
      );
      await openTab(tester, 'catalog');
      expect(find.text('All (3)'), findsOneWidget);
      expect(find.text('Products'), findsOneWidget);
      expect(find.text('Housekeeping'), findsOneWidget);
      expect(find.text('HVAC'), findsOneWidget);
      expect(find.byKey(const ValueKey('service-sv1')), findsOneWidget);
      expect(find.byKey(const ValueKey('service-sv2')), findsOneWidget);
      expect(find.byKey(const ValueKey('product-p1')), findsOneWidget);

      await tester.tap(find.text('HVAC'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('service-sv2')), findsOneWidget);
      expect(find.byKey(const ValueKey('service-sv1')), findsNothing);
      expect(find.byKey(const ValueKey('product-p1')), findsNothing);

      await tester.tap(find.text('Products'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('product-p1')), findsOneWidget);
      expect(find.byKey(const ValueKey('service-sv2')), findsNothing);

      await tester.tap(find.text('All (3)'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('service-sv1')), findsOneWidget);
    });

    testWidgets('a service row: name, two lines, how fast, and a button that names what it does', (tester) async {
      await openSheet(tester, repo: repoWith(fullSupplier(_supplierId), services: [_service, _bookable]));
      await openTab(tester, 'catalog');
      expect(find.text('Drone Facade Cleaning'), findsOneWidget);
      expect(find.text('SLA: 24h Setup'), findsOneWidget);
      // A service with no price is asked for a quote; one with a rate is booked.
      expect(find.text('Get Quote'), findsOneWidget);
      expect(find.text('Book Service'), findsOneWidget);
      // A long description is cut at a word, with the ellipsis against it.
      expect(find.textContaining('…'), findsWidgets);
      expect(find.textContaining(' …'), findsNothing);
    });

    testWidgets('a row\'s button asks for a quote for that service; with nothing wired it opens the quote page', (
      tester,
    ) async {
      final asked = <(String, String?)>[];
      final mart = await openSheet(
        tester,
        repo: repoWith(fullSupplier(_supplierId), services: [_service], products: [_product]),
        navigation: MarketplaceNavigation(
          onRequestQuote: (s, {service, product}) => asked.add((s.id, service?.id ?? product?.id)),
        ),
      );
      await openTab(tester, 'catalog');
      await tester.tap(
        find.descendant(of: find.byKey(const ValueKey('service-sv1')), matching: find.text('Get Quote')),
      );
      await tester.tap(find.descendant(of: find.byKey(const ValueKey('product-p1')), matching: find.text('Get Quote')));
      expect(asked, [(_supplierId, 'sv1'), (_supplierId, 'p1')]);
      expect(mart.links.opened, isEmpty);
    });

    testWidgets('a row opens its service or product page (the lead own, else the Marketplace own)', (tester) async {
      final opened = <String>[];
      final mart = await openSheet(
        tester,
        repo: repoWith(fullSupplier(_supplierId), services: [_service], products: [_product])
          ..productAnswer = ((id) => _product),
        navigation: MarketplaceNavigation(onOpenService: (id) => opened.add('service:$id')),
      );
      await openTab(tester, 'catalog');
      await tester.tap(find.text('Drone Facade Cleaning'));
      await tester.pump();
      expect(opened, ['service:sv1']);
      await tester.tap(find.text('Biometric Access Terminal'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('item-title')), findsOneWidget);
      expect(find.text('Product'), findsOneWidget);
      expect(mart.links.opened, isEmpty);
    });

    testWidgets('nothing listed, and a failed read, say so', (tester) async {
      await openSheet(tester);
      await openTab(tester, 'catalog');
      expect(find.text('Nothing listed yet'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      final repo = repoWith(fullSupplier(_supplierId))..failing['servicesOf'] = ApiError('Services are down.');
      await openSheet(tester, repo: repo);
      await openTab(tester, 'catalog');
      expect(find.text('Services are down.'), findsOneWidget);
    });
  });

  group('Compliances & Proofs', () {
    const compliances = [
      Compliance(
        id: 'c1',
        title: 'DGCA Commercial Drone License',
        category: 'GOVERNMENT',
        number: 'DGCA-KA-2024-UAV-781',
      ),
      Compliance(id: 'c2', title: 'ISO 9001:2015 Quality Management', category: 'ISO', issuer: 'TUV Rheinland'),
      Compliance(id: 'c3', title: 'Escrow & Trade Assurance Policy', category: 'OTHER', note: '₹10 Crore Cover'),
    ];

    testWidgets('each compliance with what it says and where it stands', (tester) async {
      await openSheet(tester, repo: repoWith(fullSupplier(_supplierId), compliances: compliances));
      await openTab(tester, 'proofs');
      expect(find.text('Compliances & Audited Proofs'), findsOneWidget);
      expect(find.text('DGCA Commercial Drone License'), findsOneWidget);
      expect(find.text('Reg: #DGCA-KA-2024-UAV-781'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Audited by TUV Rheinland'), findsOneWidget);
      expect(find.text('Certified'), findsOneWidget);
      expect(find.text('₹10 Crore Cover'), findsOneWidget);
      expect(find.text('Insured'), findsOneWidget);
    });

    testWidgets('a rating is anonymous: "Verified buyer", what they are, the stars and what they said', (tester) async {
      await openSheet(tester, repo: repoWith(fullSupplier(_supplierId), compliances: compliances));
      await openTab(tester, 'proofs');
      await scrollSheetTo(tester, find.text('Audited Enterprise Proofs'));
      expect(find.text('Verified buyer'), findsNWidgets(2));
      expect(find.text('ICR member • Oct 2026'), findsOneWidget);
      expect(find.text('"Transitioned our 14-tower facade cleaning to drones."'), findsOneWidget);
      expect(find.descendant(of: find.byType(ProofItem), matching: find.byIcon(Icons.star)), findsNWidgets(10));
    });

    testWidgets('the demo content keeps the design\'s own reviewers', (tester) async {
      final demo = fullSupplier(
        _supplierId,
        reviews: const [
          SupplierReview(
            id: 'r',
            score: 5,
            byline: 'Embassy TechZone (Pune SEZ Campus)',
            role: 'Facilities Director • 14 Towers Project',
            comment: 'Great.',
          ),
        ],
      );
      await openSheet(tester, repo: repoWith(demo));
      await openTab(tester, 'proofs');
      await scrollSheetTo(tester, find.text('Audited Enterprise Proofs'));
      expect(find.text('Embassy TechZone (Pune SEZ Campus)'), findsOneWidget);
      expect(find.text('Facilities Director • 14 Towers Project'), findsOneWidget);
      expect(find.text('Verified buyer'), findsNothing);
    });

    testWidgets('no compliances and no ratings say so', (tester) async {
      await openSheet(tester, repo: repoWith(fullSupplier(_supplierId, reviews: const [], ratingCount: 0)));
      await openTab(tester, 'proofs');
      expect(find.text('No compliances on file'), findsOneWidget);
      await scrollSheetTo(tester, find.text('Audited Enterprise Proofs'));
      expect(find.textContaining('Be the first to rate'), findsOneWidget);
    });

    testWidgets('a failed read of the compliances says why and Try again reads them', (tester) async {
      final repo = repoWith(fullSupplier(_supplierId), compliances: compliances)
        ..failing['compliances'] = ApiError('Certificates are down.');
      await openSheet(tester, repo: repo);
      await openTab(tester, 'proofs');
      expect(find.text('Certificates are down.'), findsOneWidget);
      repo.failing.clear();
      await tester.tap(find.byKey(const ValueKey('retry')));
      await tester.pumpAndSettle();
      expect(find.text('DGCA Commercial Drone License'), findsOneWidget);
    });
  });

  group('rating a supplier', () {
    Future<MartUnderTest> openRate(WidgetTester tester, {SpyMarketplaceRepository? repo}) async {
      final mart = await openSheet(tester, repo: repo);
      await openTab(tester, 'proofs');
      await scrollSheetTo(tester, find.byKey(const ValueKey('rate-supplier')));
      await tester.tap(find.byKey(const ValueKey('rate-supplier')));
      await tester.pumpAndSettle();
      return mart;
    }

    testWidgets('stars are required; then the rating goes to the API with its comment, and the sheet says thanks', (
      tester,
    ) async {
      final mart = await openRate(tester);
      expect(find.text('Rate Vikasha Aero Tech'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('rating-send')));
      await tester.pump();
      expect(find.text('Pick one to five stars first.'), findsOneWidget);
      expect(mart.repo.ratings, isEmpty);

      await tester.tap(find.byKey(const ValueKey('star-4')));
      await tester.enterText(find.byKey(const ValueKey('rating-comment')), 'Quick and tidy.');
      await tester.tap(find.byKey(const ValueKey('rating-send')));
      await tester.pumpAndSettle();
      expect(mart.repo.ratings.single, (id: _supplierId, score: 4, comment: 'Quick and tidy.'));
      expect(find.text('Rate Vikasha Aero Tech'), findsNothing);
      expect(find.text('Thanks, your rating is saved.'), findsOneWidget);
      // The listing is read again for the new average.
      expect(mart.repo.calls.where((c) => c == 'supplier').length, greaterThanOrEqualTo(2));
    });

    testWidgets('a refusal (your own listing, no sign-in) is shown as the API worded it and what was typed stays', (
      tester,
    ) async {
      final repo = repoWith(fullSupplier(_supplierId))
        ..failing['rate'] = ApiError('You cannot rate your own listing.', statusCode: 403);
      await openRate(tester, repo: repo);
      await tester.tap(find.byKey(const ValueKey('star-5')));
      await tester.enterText(find.byKey(const ValueKey('rating-comment')), 'Best in class');
      await tester.tap(find.byKey(const ValueKey('rating-send')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('rating-error')), findsOneWidget);
      expect(find.text('You cannot rate your own listing.'), findsOneWidget);
      expect(find.text('Best in class'), findsOneWidget);
      expect(find.text('Rate Vikasha Aero Tech'), findsOneWidget);
    });
  });

  group('Request for Quote and Message', () {
    testWidgets(
      'Request for Quote calls the lead\'s screen with the supplier; with nothing wired it opens the quote page',
      (tester) async {
        final asked = <String>[];
        final mart = await openSheet(
          tester,
          navigation: MarketplaceNavigation(onRequestQuote: (s, {service, product}) => asked.add(s.id)),
        );
        await tester.tap(find.byKey(const ValueKey('request-quote')));
        expect(asked, [_supplierId]);
        expect(mart.links.opened, isEmpty);
      },
    );

    testWidgets('with nothing wired, Request for Quote opens the Marketplace own quote form', (tester) async {
      final mart = await openSheet(tester);
      await tester.tap(find.byKey(const ValueKey('request-quote')));
      await tester.pumpAndSettle();
      expect(find.text('Request a quote'), findsOneWidget);
      expect(mart.links.opened, isEmpty);
    });

    testWidgets('Message calls onMessageSupplier with the listing id', (tester) async {
      final mart = await openSheet(tester, wire: true);
      await tester.tap(find.byKey(const ValueKey('message-supplier')));
      expect(mart.events, ['message:$_supplierId']);
      expect(mart.repo.conversations, isEmpty);
    });

    testWidgets('with no callback the Marketplace opens the conversation itself and hands over its id', (tester) async {
      final opened = <String>[];
      final mart = await openSheet(tester, navigation: MarketplaceNavigation(onOpenConversation: opened.add));
      await tester.tap(find.byKey(const ValueKey('message-supplier')));
      await tester.pumpAndSettle();
      expect(mart.repo.conversations, [_supplierId]);
      expect(opened, ['conversation-$_supplierId']);
    });

    testWidgets('and with nowhere to hand it, the website\'s thread', (tester) async {
      final mart = await openSheet(tester);
      await tester.tap(find.byKey(const ValueKey('message-supplier')));
      await tester.pumpAndSettle();
      expect(mart.links.paths, ['/messaging?c=conversation-$_supplierId']);
    });

    testWidgets('a supplier with nobody to receive a message: the API\'s sentence, no conversation', (tester) async {
      final repo = repoWith(fullSupplier(_supplierId))
        ..failing['startConversation'] = ApiError('This supplier has no one to receive messages yet.', statusCode: 400);
      final mart = await openSheet(tester, repo: repo);
      await tester.tap(find.byKey(const ValueKey('message-supplier')));
      await tester.pumpAndSettle();
      expect(find.text('This supplier has no one to receive messages yet.'), findsOneWidget);
      expect(mart.links.opened, isEmpty);
    });
  });
}
