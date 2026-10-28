import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/features/marketplace/catalog_models.dart';
import 'package:icr_mobile/features/marketplace/marketplace_controller.dart';
import 'package:icr_mobile/features/marketplace/marketplace_filters.dart';
import 'package:icr_mobile/features/marketplace/marketplace_links.dart';
import 'package:icr_mobile/features/marketplace/marketplace_models.dart';

import 'marketplace_fakes.dart';

/// What the Marketplace reads from the API, and what its controller does with
/// it. The fixtures are the portal's own answers, captured from the local API
/// with the Marketplace seed in (`tool/seed/marketplace.ts`).
void main() {
  group('the API\'s answers, read as the portal sends them', () {
    test('a supplier row of GET /vendors', () async {
      final repo = apiRepo(MartApi(realRoutes()));
      final page = await repo.suppliers(const MarketplaceFilters());
      expect(page.suppliers, hasLength(3));
      expect(page.total, 184);
      expect(page.hasMore, isTrue);

      final s = page.suppliers.first;
      expect(s.name, 'BlueDot');
      expect(s.headline, 'Corporate Security');
      expect(s.blurb, 'Biometric systems, CCTV & Manpower');
      expect(s.ratingLabel, '4.8');
      expect(s.ratingCount, 124);
      expect(s.level, SupplierLevel.elite);
      expect(s.level.tier, 'Tier-1');
      expect(s.isPremium, isTrue);
      expect(s.categories, ['PHYSICAL_SECURITY', 'ELECTRONIC_SECURITY']);
      // A stored /uploads path becomes a URL beside the API.
      expect(s.logoUrl, 'http://api.test/uploads/design-mkt-logo_bluedot.png');
      // A list row has no offices or ratings: it is not the full listing.
      expect(s.detailed, isFalse);
      expect(s.initial, 'B');
    });

    test('GET /vendors is asked what the filters say, and nothing else', () async {
      final api = MartApi(realRoutes());
      await apiRepo(api, pageSize: 12).suppliers(const MarketplaceFilters(), page: 2);
      expect(api.queryOf('GET /vendors'), {
        'page': 2,
        'limit': 12,
        'minVerificationLevel': 'VERIFIED',
        'sortBy': 'rating',
        'sortDir': 'desc',
      });

      await apiRepo(api).suppliers(
        const MarketplaceFilters(
          search: 'duct',
          categories: {'HVAC', 'PEST_CONTROL'},
          city: 'Pune',
          minLevel: SupplierLevel.certified,
          minRating: 4.5,
          sizes: {'51-200', '201-500'},
          gst: true,
          msme: true,
          sort: SupplierSort.mostReviewed,
        ),
      );
      expect(api.queryOf('GET /vendors'), {
        'page': 1,
        'limit': 12,
        'search': 'duct',
        'categories': 'HVAC,PEST_CONTROL',
        'city': 'Pune',
        'minVerificationLevel': 'CERTIFIED',
        'minRating': 4.5,
        'size': '51-200,201-500',
        'gst': 'true',
        'msme': 'true',
        'sortBy': 'ratingCount',
        'sortDir': 'desc',
      });

      // "Recommended" leaves the order to the API; "every supplier" sends no level.
      await apiRepo(api).suppliers(const MarketplaceFilters(minLevel: null, sort: SupplierSort.recommended));
      expect(api.queryOf('GET /vendors').containsKey('sortBy'), isFalse);
      expect(api.queryOf('GET /vendors').containsKey('minVerificationLevel'), isFalse);
    });

    test('the full listing of GET /vendors/:id: offices, registration, ratings', () async {
      final repo = apiRepo(MartApi(realRoutes()));
      final s = await repo.supplier('design-mkt-v-vikasha');
      expect(s.detailed, isTrue);
      expect(s.name, 'Vikasha Aero Tech');
      expect(s.legalStructure, 'PRIVATE_LIMITED');
      expect(s.registrationLine, 'Pvt Ltd • Reg. CIN-U74999KA2019PTC1');
      expect(s.ratingLabel, '4.9');
      expect(s.reviewsLabel, '84 Enterprise Reviews');
      expect(s.level.tier, 'Tier-1');
      expect(s.website, 'https://vikasha.example.in');

      expect(s.hubs, hasLength(4));
      expect(s.headOffice!.name, 'Bengaluru HQ');
      expect(s.phone, '+91 80 4000 1100');
      expect(s.hubCities, ['Bengaluru', 'Hyderabad', 'Pune', 'Chennai']);

      // The API publishes no reviewer: a rating is a score and what was said.
      expect(s.reviews, hasLength(2));
      expect(s.reviews.first.score, 5);
      expect(s.reviews.first.comment, startsWith('Transitioned our 14-tower'));
      expect(s.reviews.first.byline, isNull);
      expect(s.reviews.first.role, isNull);
    });

    test('the track record is what the listing can back, and the hubs band reads the offices', () async {
      final s = await apiRepo(MartApi(realRoutes())).supplier('design-mkt-v-vikasha');
      final tiles = s.trackRecord;
      expect([for (final t in tiles) t.value], ['150+', '7', '4 Hubs']);
      expect(
        [for (final t in tiles) t.caption],
        ['Projects Executed', 'Years of Experience', 'Bengaluru, Hyderabad, Pune & Chennai'],
      );
      final band = s.dispatch!;
      expect(band.kicker, 'PAN-INDIA PRESENCE');
      expect(band.title, '4 Operational Hubs');
      expect(band.line, 'Bengaluru • Hyderabad • Pune • Chennai • replies within 4 hours');
    });

    test('a supplier with one office has no hubs band, and a missing number no tile', () {
      const s = Supplier(
        id: 'a',
        companyId: 'c',
        name: 'Solo',
        hubs: [SupplierHub(id: 'h', name: 'HQ', city: 'Pune', headOffice: true)],
        projectsCompleted: 0,
      );
      expect(s.dispatch, isNull);
      expect(s.trackRecord.map((t) => t.value), ['1 Hub']);
    });

    test('the certifications: category from the type list, status from the kind of document', () async {
      final repo = apiRepo(MartApi(realRoutes()));
      final rows = await repo.compliances('design-mkt-co-vikasha');
      expect(rows.map((c) => c.title), [
        'DGCA Commercial Drone License',
        'ISO 9001:2015 Quality Management',
        'ISO 45001 Occupational Safety',
        'Escrow & Trade Assurance Policy',
      ]);
      expect(rows.map((c) => c.status), ['Active', 'Certified', 'Certified', 'Insured']);
      expect(rows.map((c) => c.detail), [
        'Reg: #DGCA-KA-2024-UAV-781',
        'Audited by TUV Rheinland',
        'Zero-Elevation Worker Hazard Compliant',
        '₹10 Crore Comprehensive Aviation Risk Coverage',
      ]);
      expect(rows.map((c) => c.glyph), [
        ComplianceGlyph.licence,
        ComplianceGlyph.quality,
        ComplianceGlyph.safety,
        ComplianceGlyph.insurance,
      ]);
      expect(rows.map((c) => c.tone), [
        ComplianceTone.positive,
        ComplianceTone.positive,
        ComplianceTone.positive,
        ComplianceTone.neutral,
      ]);
    });

    test('a company\'s services and products', () async {
      final api = MartApi(realRoutes());
      final repo = apiRepo(api);
      final services = await repo.servicesOf('design-mkt-co-vikasha');
      expect(api.queryOf('GET /services'), {'companyId': 'design-mkt-co-vikasha', 'limit': 50});
      expect(services, hasLength(6));
      expect(services.first.name, 'Drone Facade Cleaning');
      expect(services.first.turnaround, 'SLA: 24h Setup • BLR / HYD');
      expect(services.first.bookable, isFalse);
      expect(services.first.action, 'Get Quote');
      final inspection = services.firstWhere((s) => s.name == 'Robotic HVAC Inspection');
      expect(inspection.bookable, isTrue);
      expect(inspection.action, 'Book Service');
      expect(inspection.rateLabel, '₹18,000 per inspection');
      expect(inspection.subcategory, 'HVAC');

      final products = await repo.productsOf('design-mkt-co-securetech');
      expect(products, hasLength(3));
      final terminal = products.first;
      expect(terminal.name, 'Biometric Access Terminal');
      expect(terminal.priceLabel, '₹18,500 / piece');
      expect(terminal.stock, ProductStock.inStock);
      expect(terminal.terms, [
        '2-year warranty',
        '7-day returns',
        'Free delivery over ₹25,000',
        'Bulk pricing from 10 piece',
      ]);
      expect(terminal.categoryName, 'Access Control');
      expect(products.last.stock, ProductStock.madeToOrder);
      expect(products.last.terms, ['1-year warranty']);
    });

    test('the category tree and its counts, the cities and the numbers on the chips', () async {
      final repo = apiRepo(MartApi(realRoutes()));
      final tree = await repo.categories();
      expect(tree.map((n) => n.key), ['FACILITY_MANAGEMENT', 'SECURITY']);
      final security = tree.last;
      expect(security.name, 'Security Services');
      expect(security.children.map((n) => n.name), ['Physical Security', 'Electronic Security']);
      expect(security.count, greaterThan(0));

      expect(await repo.cities(), ['Bengaluru', 'Chennai', 'Delhi', 'Hyderabad', 'Mumbai', 'Pune']);
      expect(await repo.savedIds(), isEmpty);
      expect(await repo.unreadNotifications(), 7);
      final counts = await repo.counts();
      // Every requirement the My RFQ's screen opens on (its All tab), not only the live and the drafts: the fixture
      // holds 3 live, 1 draft, 1 awarded and 1 ended, and a chip that said 4 led to a list of 6.
      final views = (fixture('rfq_summary.json') as Map)['views'] as Map;
      expect(counts.myRfqs, views['ALL']);
      expect(counts.myRfqs, 6);
      expect(counts.myRfqs, isNot((views['LIVE'] as int) + (views['DRAFT'] as int)));
      expect(counts.newAlerts, 0);
    });

    test('Alerts counts the unread notifications that are about requirements', () async {
      final api = MartApi({
        ...realRoutes(),
        'GET /notifications': (_) => pageJson([
          {'id': 'n1', 'type': 'bid_received', 'link': '/manage/requirements/r1'},
          {'id': 'n2', 'type': 'message', 'link': '/messaging?c=x'},
          {'id': 'n3', 'type': 'info', 'link': '/manage/bids/b9'},
          {'id': 'n4', 'type': 'rfq_match', 'link': null},
        ]),
      });
      final counts = await apiRepo(api).counts();
      expect(counts.newAlerts, 3);
      expect(api.queryOf('GET /notifications'), {'limit': 100, 'unread': 'true'});
    });

    test('a member who cannot post requirements simply has none', () async {
      final api = MartApi({...realRoutes(), 'GET /rfq/mine/summary': (_) => (403, '{"message":"Forbidden"}')});
      final counts = await apiRepo(api).counts();
      expect(counts.myRfqs, 0);
    });

    test('saving and un-saving a supplier go to its /save route', () async {
      final api = MartApi({
        ...realRoutes(),
        'POST /vendors/v1/save': (_) => {'saved': true},
        'DELETE /vendors/v1/save': (_) => {'saved': false},
      });
      final repo = apiRepo(api);
      await repo.setSaved('v1', true);
      await repo.setSaved('v1', false);
      expect(api.calls, ['POST /vendors/v1/save', 'DELETE /vendors/v1/save']);
    });

    test('a rating is posted with its score, and its comment only when there is one', () async {
      final api = MartApi({
        ...realRoutes(),
        'POST /vendors/v1/ratings': (_) => {'id': 'v1', 'rating': 4.5, 'ratingCount': 3},
      });
      final repo = apiRepo(api);
      await repo.rate('v1', score: 4, comment: '  Fast and tidy  ');
      expect(api.bodyOf('POST /vendors/v1/ratings'), {'score': 4, 'comment': 'Fast and tidy'});
      await repo.rate('v1', score: 5, comment: '   ');
      expect(api.bodyOf('POST /vendors/v1/ratings'), {'score': 5});
    });

    test('a conversation with a supplier is opened through its listing', () async {
      final api = MartApi({
        ...realRoutes(),
        'POST /messaging/conversations/supplier': (_) => {'id': 'conv-1'},
      });
      final id = await apiRepo(api).startConversation('v1', message: 'Hello');
      expect(id, 'conv-1');
      expect(api.bodyOf('POST /messaging/conversations/supplier'), {'vendorId': 'v1', 'message': 'Hello'});
    });

    test('a shape the app does not expect reads as nothing, not as a crash', () {
      final s = Supplier.fromJson({
        'id': 7,
        'rating': '4.5',
        'ratingCount': null,
        'categories': 'oops',
        'company': {'name': null, 'branches': 'x'},
      }, absolute: (p) => p);
      expect(s.id, '7');
      expect(s.name, 'Supplier');
      expect(s.rating, 4.5);
      expect(s.ratingCount, 0);
      expect(s.categories, isEmpty);
      expect(s.hubs, isEmpty);
    });
  });

  group('the words on a profile', () {
    test('the response-time buckets are the API\'s (WITHIN_1H, not WITHIN_HOUR)', () {
      expect(responseTimeLabel('WITHIN_1H'), 'within an hour');
      expect(responseTimeLabel('WITHIN_4H'), 'within 4 hours');
      expect(responseTimeLabel('WITHIN_24H'), 'within a day');
      expect(responseTimeLabel('WITHIN_48H'), 'within 2 days');
      expect(responseTimeLabel('WITHIN_WEEK'), 'within a week');
      expect(responseTimeLabel(null), '');
    });

    test('the trust ladder: Verified and above wear the seal, the top rung is Tier-1', () {
      expect(SupplierLevel.registered.isVerified, isFalse);
      expect(SupplierLevel.verified.isVerified, isTrue);
      expect([for (final l in SupplierLevel.values) l.tier], [null, 'Tier-4', 'Tier-3', 'Tier-2', 'Tier-1']);
      expect(SupplierLevel.parse('PREFERRED'), SupplierLevel.preferred);
      expect(SupplierLevel.parse('nonsense'), SupplierLevel.registered);
    });

    test('a long count is rounded down to tens', () {
      expect(roughTotal(184), '180+');
      expect(roughTotal(99), '99');
      expect(roughTotal(100), '100+');
    });

    test('a phone number becomes a WhatsApp number, with India put in front of a bare mobile', () {
      expect(whatsAppNumber('+91 80 4000 1100'), '918040001100');
      expect(whatsAppNumber('98765 43210'), '919876543210');
      expect(whatsAppNumber('098765 43210'), '919876543210');
      expect(whatsAppNumber('+44 7700 900123'), '447700900123');
      expect(whatsAppNumber(null), isNull);
      expect(whatsAppNumber('n/a'), isNull);
    });

    test('a website the way a person typed it', () {
      expect(websiteUri('vikasha.example.in')?.toString(), 'https://vikasha.example.in');
      expect(websiteUri(' http://a.example/x ')?.toString(), 'http://a.example/x');
      expect(websiteUri(''), isNull);
      expect(websiteUri(null), isNull);
    });

    test('a rupee amount in Indian grouping', () {
      expect(formatRupees(480), '₹480');
      expect(formatRupees(18500), '₹18,500');
      expect(formatRupees(1250000), '₹12,50,000');
      expect(formatRupees(99.5), '₹99.50');
    });
  });

  group('the filters', () {
    test('what counts on "Filters (n)": the sheet\'s filters, not the chips\' own', () {
      expect(const MarketplaceFilters().sheetCount, 0);
      expect(const MarketplaceFilters(minRating: 4, sort: SupplierSort.newest).sheetCount, 0);
      expect(
        const MarketplaceFilters(
          categories: {'A', 'B'},
          city: 'Pune',
          sizes: {'11-50'},
          gst: true,
          msme: true,
          minLevel: SupplierLevel.elite,
          savedOnly: true,
        ).sheetCount,
        8,
      );
      // Verified is the default rung (the "Verified only" chip), so it does not count.
      expect(const MarketplaceFilters(minLevel: SupplierLevel.verified).sheetCount, 0);
    });

    test('"Clear all" keeps the search, the order, the rating and "Verified only"', () {
      const f = MarketplaceFilters(
        search: 'duct',
        categories: {'HVAC'},
        city: 'Pune',
        minRating: 4,
        sort: SupplierSort.newest,
        gst: true,
      );
      final cleared = f.clearedSheet();
      expect(cleared.search, 'duct');
      expect(cleared.minRating, 4);
      expect(cleared.sort, SupplierSort.newest);
      expect(cleared.sheetCount, 0);
      expect(cleared.verifiedOnly, isTrue);
      expect(f.copyWith(clearLevel: true).clearedSheet().verifiedOnly, isFalse);
    });

    test('what narrows the list', () {
      expect(const MarketplaceFilters().narrows, isFalse);
      expect(const MarketplaceFilters(search: 'x').narrows, isTrue);
      expect(const MarketplaceFilters(minRating: 3).narrows, isTrue);
      expect(const MarketplaceFilters(minLevel: null).narrows, isTrue);
      expect(const MarketplaceFilters(sort: SupplierSort.newest).narrows, isFalse);
    });

    test('two filters with the same choices are equal, whatever order a set was built in', () {
      expect(
        const MarketplaceFilters(categories: {'A', 'B'}),
        equals(const MarketplaceFilters(categories: {'B', 'A'})),
      );
      expect(const MarketplaceFilters(city: 'Pune'), isNot(equals(const MarketplaceFilters(city: 'Delhi'))));
    });

    test('the rating steps read as the chip says them', () {
      expect(ratingStepLabel(4.5), '4.5★ & up');
      expect(ratingStepLabel(4), '4★ & up');
    });
  });

  group('the controller', () {
    late SpyMarketplaceRepository repo;
    late MarketplaceController market;

    setUp(() {
      repo = SpyMarketplaceRepository();
      market = MarketplaceController(repo);
    });

    tearDown(() => market.dispose());

    test('starting reads the list, the bookmarks, the chip numbers and the bell', () async {
      await market.start();
      expect(market.started, isTrue);
      expect(market.suppliers, hasLength(10));
      expect(market.total, 184);
      expect(market.hasMore, isTrue);
      expect(market.counts.myRfqs, 3);
      expect(market.counts.newAlerts, 2);
      expect(market.unread, 1);
      expect(market.error, isNull);
      expect(repo.searches.single.filters, const MarketplaceFilters());
    });

    test('the chip numbers can come from the app\'s own source instead', () async {
      market.useCounts(() async => const MarketplaceCounts(myRfqs: 9, newAlerts: 4));
      await market.start();
      expect(market.counts.myRfqs, 9);
      expect(market.counts.newAlerts, 4);
      expect(repo.calls, isNot(contains('counts')));
    });

    test('a search reloads the list inside the same filters, and asks for the services and requirements too', () async {
      await market.start();
      repo.searchAnswer = (f, p) => pageOf(2, total: 2, hasMore: false);
      await market.setSearch('  duct care ');
      expect(market.filters.search, 'duct care');
      expect(market.suppliers, hasLength(2));
      expect(repo.searches.last.filters.search, 'duct care');
      await pumpEventQueue();
      expect(repo.calls, contains('searchExtras:duct care'));

      // The same words again are not a new search.
      final before = repo.searches.length;
      await market.setSearch('duct care');
      expect(repo.searches, hasLength(before));
    });

    test('the other answers to a search are dropped when the search is cleared', () async {
      repo.extrasAnswer = SearchExtras(
        services: [CatalogService(id: 's', companyId: 'c', name: 'Duct care')],
      );
      await market.start();
      await market.setSearch('duct');
      await pumpEventQueue();
      expect(market.extras.services, hasLength(1));
      await market.setSearch('');
      await pumpEventQueue();
      expect(market.extras.isEmpty, isTrue);
    });

    test('the order, the rating and "Verified only" each reload the list', () async {
      await market.start();
      await market.setSort(SupplierSort.mostProjects);
      expect(repo.searches.last.filters.sort, SupplierSort.mostProjects);
      await market.setMinRating(4.5);
      expect(repo.searches.last.filters.minRating, 4.5);
      await market.setMinRating(null);
      expect(repo.searches.last.filters.minRating, isNull);

      expect(market.filters.verifiedOnly, isTrue);
      await market.toggleVerifiedOnly();
      expect(market.filters.verifiedOnly, isFalse);
      expect(repo.searches.last.filters.minLevel, isNull);
      await market.toggleVerifiedOnly();
      expect(repo.searches.last.filters.minLevel, SupplierLevel.verified);
    });

    test('"Load more suppliers" adds the next page once, and each supplier once', () async {
      repo.searchAnswer = (f, p) => switch (p) {
        1 => pageOf(3, total: 6),
        2 => pageOf(4, from: 3, total: 6, hasMore: false, page: 2), // s3 comes again
        _ => throw StateError('page $p'),
      };
      await market.start();
      expect(market.suppliers.map((s) => s.id), ['s1', 's2', 's3']);
      await market.loadMore();
      expect(market.suppliers.map((s) => s.id), ['s1', 's2', 's3', 's4', 's5', 's6']);
      expect(market.hasMore, isFalse);
      await market.loadMore();
      expect(repo.searches.where((s) => s.page == 2), hasLength(1));
    });

    test('a page that fails to load leaves the list and lets the next tap try again', () async {
      repo.searchAnswer = (f, p) => p == 1 ? pageOf(3, total: 6) : throw ApiError('boom');
      await market.start();
      await market.loadMore();
      expect(market.suppliers, hasLength(3));
      expect(market.hasMore, isTrue);
      expect(market.loadingMore, isFalse);
    });

    test('a failed load says why and keeps nothing', () async {
      repo.failing['suppliers'] = ApiError('The mart is down.');
      await market.start();
      expect(market.error, 'The mart is down.');
      expect(market.suppliers, isEmpty);
      repo.failing.clear();
      await market.refresh();
      expect(market.error, isNull);
      expect(market.suppliers, isNotEmpty);
    });

    test('an answer that comes late, for an earlier search, is dropped', () async {
      await market.start();
      repo.searchAnswer = (f, p) => pageOf(1, from: f.search == 'first' ? 100 : 200, total: 1, hasMore: false);
      final first = market.setSearch('first');
      final second = market.setSearch('second');
      await Future.wait([first, second]);
      expect(market.suppliers.single.id, 's200');
    });

    test('"Clear filters" drops the search and the sheet\'s filters and keeps the order and "Verified only"', () async {
      await market.start();
      await market.setFilters(
        const MarketplaceFilters(search: 'x', categories: {'HVAC'}, minRating: 4, sort: SupplierSort.newest),
      );
      await market.clearFilters();
      expect(market.filters.search, '');
      expect(market.filters.categories, isEmpty);
      expect(market.filters.minRating, isNull);
      expect(market.filters.sort, SupplierSort.newest);
      expect(market.filters.verifiedOnly, isTrue);
    });

    test('the saved list replaces the directory while "only my saved suppliers" is on', () async {
      repo.savedAnswer = (p) => pageOf(2, total: 2, hasMore: false);
      await market.start();
      await market.setFilters(market.filters.copyWith(savedOnly: true));
      expect(repo.calls, contains('savedSuppliers'));
      expect(market.suppliers, hasLength(2));
      expect(market.narrowed, isTrue); // "only my saved suppliers" narrows the list
    });

    test('a bookmark is applied at once and kept when the API accepts it', () async {
      await market.start();
      final id = market.suppliers.first.id;
      expect(market.isSaved(id), isFalse);
      final pending = market.toggleSave(id);
      expect(market.isSaved(id), isTrue);
      expect(await pending, isNull);
      expect(repo.saves.single, (id: id, saved: true));
      expect(market.savedIds, contains(id));
      expect(await market.toggleSave(id), isNull);
      expect(market.isSaved(id), isFalse);
    });

    test('a bookmark the API refuses is taken back, with its sentence', () async {
      await market.start();
      repo.failing['setSaved'] = ApiError('Sign in to save suppliers.', statusCode: 401);
      final id = market.suppliers.first.id;
      expect(await market.toggleSave(id), 'Sign in to save suppliers.');
      expect(market.isSaved(id), isFalse);
    });

    test('un-saving on the saved list takes the card off it', () async {
      repo.savedAnswer = (p) => pageOf(2, total: 2, hasMore: false);
      await market.start();
      await market.setFilters(market.filters.copyWith(savedOnly: true));
      market.markSaved('s1', true);
      await market.toggleSave('s1');
      expect(market.suppliers.map((s) => s.id), ['s2']);
      expect(market.total, 1);
    });

    test('a category is called what the tree calls it, else its key set in sentence case', () async {
      expect(market.categoryName('PHYSICAL_SECURITY'), 'Physical security');
      await market.start();
      expect(market.categoryName('PHYSICAL_SECURITY'), 'Physical Security');
      expect(market.categoryName('SOMETHING_NEW'), 'Something new');
    });

    test('the cities load once they are asked for, and a failure is tried again', () async {
      expect(market.cities, isNull);
      expect(await market.loadCities(), contains('Pune'));
      expect(market.cities, contains('Pune'));
    });
  });
}
