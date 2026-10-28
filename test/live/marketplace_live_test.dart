/// The Marketplace controls against the LOCAL portal API: each one does the real
/// thing through the app's own repository and controller, the effect is read back
/// through the API, and what can be undone is undone (a bookmark taken back).
///
/// Needs the Marketplace seed (`tool/seed/marketplace.ts`, see tool/seed/README.md):
/// the ten designed suppliers lead the "Top rated" order, Vikasha Aero Tech has the
/// profile, and the sandbox supplier is the one the tests act on (saving, rating,
/// asking for a quote), which every run of the seed puts back as it was.
///
/// What cannot be undone through the API, and what the test does about it:
///  - A rating cannot be deleted (`POST /vendors/:id/ratings` replaces the member's
///    own). The rating test acts on the sandbox supplier only, whose numbers the
///    seed resets.
@Tags(['live'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/features/marketplace/api_marketplace_repository.dart';
import 'package:icr_mobile/features/marketplace/catalog_board_controller.dart';
import 'package:icr_mobile/features/marketplace/catalog_item_controller.dart';
import 'package:icr_mobile/features/marketplace/catalog_models.dart';
import 'package:icr_mobile/features/marketplace/marketplace_controller.dart';
import 'package:icr_mobile/features/marketplace/marketplace_filters.dart';
import 'package:icr_mobile/features/marketplace/marketplace_models.dart';
import 'package:icr_mobile/features/marketplace/quote_controller.dart';
import 'package:icr_mobile/features/marketplace/quote_models.dart';
import 'package:icr_mobile/features/marketplace/supplier_controller.dart';

import 'live.dart';

/// The listing the live tests act on (`tool/seed/marketplace.ts`).
const sandbox = 'design-mkt-v-sandbox';
const vikasha = 'design-mkt-v-vikasha';

/// The two buyers of the seed's company (`tool/seed/marketplace.ts`): an admin with a mobile number on file and a
/// buyer with none (taken off again by every run of the seed). The portal's own Bharat Buyer has no active company
/// on this database, and a requirement is a company's.
const marketBuyer = LivePerson('marketplace.buyer@marketplace-design.icr.test', 'Market@12345', 'Maya Mehta');
const marketNoPhone = LivePerson('marketplace.nophone@marketplace-design.icr.test', 'Market@12345', 'Nikhil Nair');

Future<ApiMarketplaceRepository> repoFor([LivePerson who = bharat, int pageSize = 12]) async =>
    ApiMarketplaceRepository(api: await liveClient(who), pageSize: pageSize);

Future<Map<String, dynamic>> getMap(ApiClient api, String path, [Map<String, dynamic>? query]) async =>
    (await api.dio.get<Map<String, dynamic>>(path, queryParameters: query)).data!;

void main() {
  group('the directory', () {
    liveTest(
      'opens on the designed suppliers in "Top rated" order, with their logos, and says how many there are',
      () async {
        final repo = await repoFor();
        final market = MarketplaceController(repo);
        addTearDown(market.dispose);
        await market.start();
        expect(market.error, isNull);
        expect(market.suppliers, hasLength(12));
        expect(market.hasMore, isTrue);
        expect(market.total, greaterThanOrEqualTo(100));

        final names = market.suppliers.map((s) => s.name).toList();
        expect(names.take(2), ['BlueDot', 'InnoWork']);
        expect(names, containsAll(['SecureTech', 'SafeHome', 'GreenGuard']));
        final blueDot = market.suppliers.first;
        expect(blueDot.headline, 'Corporate Security');
        expect(blueDot.blurb, 'Biometric systems, CCTV & Manpower');
        expect(blueDot.ratingLabel, '4.8');
        expect(blueDot.ratingCount, 124);
        expect(blueDot.logoUrl, startsWith('http://localhost:3001/uploads/design-mkt-logo_'));
        // Every card has what the card draws.
        for (final s in market.suppliers) {
          expect(s.name, isNotEmpty);
          expect(s.rating, inInclusiveRange(0, 5));
          expect(s.level.isVerified, isTrue, reason: '"Verified only" is on to begin with');
        }
      },
    );

    liveTest('every order the Sort sheet offers is one the API accepts, and the order is the one asked for', () async {
      final repo = await repoFor();
      for (final sort in SupplierSort.values) {
        final page = await repo.suppliers(MarketplaceFilters(sort: sort));
        expect(page.suppliers, isNotEmpty, reason: sort.label);
      }
      // Within one rung of paid placement and trust (the API always puts those first) the order is the sort's.
      final byReviews = (await repo.suppliers(
        const MarketplaceFilters(sort: SupplierSort.mostReviewed, minLevel: null),
      )).suppliers;
      for (var i = 1; i < byReviews.length; i++) {
        final a = byReviews[i - 1], b = byReviews[i];
        if (a.isPremium == b.isPremium && a.level == b.level) {
          expect(a.ratingCount, greaterThanOrEqualTo(b.ratingCount), reason: '${a.name} before ${b.name}');
        }
      }
      final byRating = (await repo.suppliers(const MarketplaceFilters())).suppliers;
      for (var i = 1; i < byRating.length; i++) {
        final a = byRating[i - 1], b = byRating[i];
        if (a.isPremium == b.isPremium && a.level == b.level) {
          expect(a.rating, greaterThanOrEqualTo(b.rating), reason: '${a.name} before ${b.name}');
        }
      }
    });

    liveTest(
      'a search finds a supplier by its name, its headline and its category, and says when nothing matches',
      () async {
        final repo = await repoFor();
        final byName = await repo.suppliers(const MarketplaceFilters(search: 'Vikasha'));
        expect(byName.suppliers.map((s) => s.id), contains(vikasha));

        final byHeadline = await repo.suppliers(const MarketplaceFilters(search: 'Network Security'));
        expect(byHeadline.suppliers.map((s) => s.name), contains('SecureTech'));

        final byCategory = await repo.suppliers(const MarketplaceFilters(search: 'ELECTRONIC_SECURITY'));
        expect(byCategory.suppliers.map((s) => s.name), containsAll(['SecureTech', 'GreenGuard']));

        final nothing = await repo.suppliers(const MarketplaceFilters(search: 'zzzzqqxx'));
        expect(nothing.suppliers, isEmpty);
        expect(nothing.total, 0);
        expect(nothing.hasMore, isFalse);
      },
    );

    liveTest('the search also finds the services and requirements the words match', () async {
      final repo = await repoFor();
      final extras = await repo.searchExtras('Duct');
      expect(extras.services.map((s) => s.name), contains('Comprehensive HVAC Duct Care'));
      final service = extras.services.firstWhere((s) => s.name == 'Comprehensive HVAC Duct Care');
      expect(service.supplierName, 'Vikasha Aero Tech');
      expect(service.rateLabel, '₹45,000 per visit');
    });

    liveTest('each filter narrows the list the way its chip says', () async {
      final repo = await repoFor();

      final rated = await repo.suppliers(const MarketplaceFilters(minRating: 4.7));
      expect(rated.suppliers, isNotEmpty);
      expect(rated.suppliers.every((s) => s.rating >= 4.7), isTrue);

      final pune = await repo.suppliers(const MarketplaceFilters(city: 'Pune'));
      expect(pune.suppliers, isNotEmpty);
      expect(pune.suppliers.every((s) => (s.city ?? '').contains('Pune')), isTrue);

      final size = await repo.suppliers(const MarketplaceFilters(sizes: {'201-500'}));
      expect(size.suppliers, isNotEmpty);
      expect(size.suppliers.every((s) => s.size == '201-500'), isTrue);

      final gst = await repo.suppliers(const MarketplaceFilters(gst: true));
      expect(gst.suppliers, isNotEmpty);
      expect(gst.suppliers.every((s) => s.gstRegistered), isTrue);

      final msme = await repo.suppliers(const MarketplaceFilters(msme: true));
      expect(msme.suppliers, isNotEmpty);
      expect(msme.suppliers.every((s) => s.msmeNumber != null), isTrue);

      final elite = await repo.suppliers(const MarketplaceFilters(minLevel: SupplierLevel.elite));
      expect(elite.suppliers.every((s) => s.level == SupplierLevel.elite), isTrue);

      // A category finds what is filed under it or under its sub-categories.
      final security = await repo.suppliers(const MarketplaceFilters(categories: {'SECURITY'}));
      expect(security.suppliers.map((s) => s.name), containsAll(['BlueDot', 'SecureTech']));
      final physical = await repo.suppliers(const MarketplaceFilters(categories: {'PHYSICAL_SECURITY'}));
      expect(physical.suppliers.every((s) => s.categories.contains('PHYSICAL_SECURITY')), isTrue);
      expect(physical.suppliers.map((s) => s.name), isNot(contains('GreenGuard')));

      // "Verified only" off widens the list.
      final everyone = await repo.suppliers(const MarketplaceFilters(minLevel: null));
      final verified = await repo.suppliers(const MarketplaceFilters());
      expect(everyone.total, greaterThanOrEqualTo(verified.total));
    });

    liveTest('"Load more suppliers" pages through a whole result, each supplier once', () async {
      final repo = await repoFor(bharat, 10);
      final market = MarketplaceController(repo, initial: const MarketplaceFilters(city: 'Pune'));
      addTearDown(market.dispose);
      await market.start();
      final total = market.total;
      expect(total, greaterThan(10), reason: 'enough Pune suppliers for more than a page');
      var pages = 1;
      while (market.hasMore) {
        await market.loadMore();
        pages++;
        expect(pages, lessThan(30));
      }
      final ids = market.suppliers.map((s) => s.id).toList();
      expect(ids.toSet(), hasLength(ids.length), reason: 'each supplier once');
      expect(ids, hasLength(total));
      expect(pages, (total / 10).ceil());
    });

    liveTest('the category tree, its counts and the cities the filters offer', () async {
      final repo = await repoFor();
      final tree = await repo.categories();
      expect(tree, isNotEmpty);
      final security = tree.firstWhere((n) => n.key == 'SECURITY');
      expect(security.name, 'Security Services');
      expect(security.children.map((c) => c.key), containsAll(['PHYSICAL_SECURITY', 'ELECTRONIC_SECURITY']));
      expect(security.count, greaterThan(0));
      expect(await repo.cities(), containsAll(['Bengaluru', 'Pune']));
    });

    liveTest(
      'the search box\'s suggestions: suppliers whose name matches, and the categories, as the member types',
      () async {
        final repo = await repoFor();
        final market = MarketplaceController(repo);
        addTearDown(market.dispose);
        await market.loadCategories();

        await market.suggest('vikasha');
        expect(market.suggestedFor, 'vikasha');
        expect(market.suggestedSuppliers.map((s) => s.name), contains('Vikasha Aero Tech'));
        expect(market.suggestedSuppliers.length, lessThanOrEqualTo(5));

        await market.suggest('zzzzqqxx');
        expect(market.suggestedSuppliers, isEmpty);

        expect(market.suggestedCategories('security').map((c) => c.node.key), contains('SECURITY'));
        final sub = market.suggestedCategories('electronic');
        expect(sub.map((c) => c.node.key), contains('ELECTRONIC_SECURITY'));
        expect(sub.firstWhere((c) => c.node.key == 'ELECTRONIC_SECURITY').parent, 'Security Services');
      },
    );
  });

  group('the chips', () {
    liveTest('My RFQ\'s counts every requirement the screen lists; the bell counts what is unread', () async {
      final api = await liveClient();
      final repo = ApiMarketplaceRepository(api: api);
      final summary = await getMap(api, '/rfq/mine/summary');
      final views = summary['views'] as Map<String, dynamic>;
      final counts = await repo.counts();
      // The chip opens the My RFQ's list on its All tab: live, drafts, awarded and ended.
      expect(counts.myRfqs, views['ALL']);
      expect(counts.newAlerts, greaterThanOrEqualTo(0));
      final unread = (await getMap(api, '/notifications/unread-count'))['unread'] as int;
      expect(await repo.unreadNotifications(), unread);
    });
  });

  group('the bookmarks', () {
    liveTest('a supplier saved from the app is on the member\'s saved list, and taking it back takes it off', () async {
      final repo = await repoFor();
      final market = MarketplaceController(repo);
      addTearDown(market.dispose);
      await market.start();
      addTearDown(() async {
        try {
          await repo.setSaved(sandbox, false);
        } catch (_) {}
      });
      await repo.setSaved(sandbox, false);
      expect((await repo.savedIds()), isNot(contains(sandbox)));

      // The controller's own toggle: applied at once, kept by the API.
      expect(await market.toggleSave(sandbox), isNull);
      expect(market.isSaved(sandbox), isTrue);
      expect(await repo.savedIds(), contains(sandbox));
      final saved = await repo.savedSuppliers();
      expect(saved.suppliers.map((s) => s.id), contains(sandbox));
      expect(saved.suppliers.firstWhere((s) => s.id == sandbox).name, 'Sandbox Facility Services');

      // "Only my saved suppliers" lists it, and only saved ones.
      await market.setFilters(market.filters.copyWith(savedOnly: true));
      expect(market.suppliers.map((s) => s.id), contains(sandbox));
      expect(market.suppliers.every((s) => market.isSaved(s.id)), isTrue);

      // Taking it back from that list drops the card; the API agrees.
      expect(await market.toggleSave(sandbox), isNull);
      expect(market.suppliers.map((s) => s.id), isNot(contains(sandbox)));
      expect(await repo.savedIds(), isNot(contains(sandbox)));
    });

    liveTest('saving is idempotent, and a read of the saved ids refreshes the bookmarks', () async {
      final repo = await repoFor();
      addTearDown(() async {
        try {
          await repo.setSaved(sandbox, false);
        } catch (_) {}
      });
      await repo.setSaved(sandbox, true);
      await repo.setSaved(sandbox, true);
      expect((await repo.savedIds()).where((id) => id == sandbox), hasLength(1));
      await repo.setSaved(sandbox, false);
      await repo.setSaved(sandbox, false);
      expect(await repo.savedIds(), isNot(contains(sandbox)));
    });

    liveTest(
      'an anonymous reader reads the directory but cannot save: the API refuses and the bookmark rolls back',
      () async {
        final repo = ApiMarketplaceRepository(api: liveAnonymous());
        final market = MarketplaceController(repo);
        addTearDown(market.dispose);
        await market.start();
        expect(market.suppliers, isNotEmpty, reason: 'the directory is public');
        final message = await market.toggleSave(market.suppliers.first.id);
        expect(message, isNotNull);
        expect(market.isSaved(market.suppliers.first.id), isFalse);
        await expectLater(
          repo.savedSuppliers(),
          throwsA(isA<Object>().having((e) => ApiError.from(e).statusCode, 'status', 401)),
        );
      },
    );
  });

  group('a supplier\'s profile', () {
    liveTest(
      'the full listing: offices, registration, rating, ratings with no name, the track record it can back',
      () async {
        final repo = await repoFor();
        final s = await repo.supplier(vikasha);
        expect(s.detailed, isTrue);
        expect(s.name, 'Vikasha Aero Tech');
        expect(s.registrationLine, 'Pvt Ltd • Reg. CIN-U74999KA2019PTC1');
        expect(s.ratingLabel, '4.9');
        expect(s.reviewsLabel, '84 Enterprise Reviews');
        expect(s.level.tier, 'Tier-1');
        expect(s.hubs, hasLength(4));
        expect(s.headOffice!.name, 'Bengaluru HQ');
        expect(s.phone, '+91 80 4000 1100');
        expect(s.website, 'https://vikasha.example.in');
        expect(s.reviews, hasLength(2));
        expect(s.reviews.every((r) => r.byline == null && r.role == null), isTrue);
        expect(s.reviews.first.comment, startsWith('Transitioned our 14-tower'));
        expect(s.trackRecord.map((t) => t.value), ['150+', '7', '4 Hubs']);
        expect(s.dispatch!.title, '4 Operational Hubs');
      },
    );

    liveTest('a plain listing with no offices or ratings reads without a hitch', () async {
      final repo = await repoFor();
      final s = await repo.supplier('design-mkt-v-fill-001');
      expect(s.name, isNotEmpty);
      expect(s.detailed, isTrue);
      expect(s.reviews, isEmpty);
      expect(s.dispatch, isNull);
    });

    liveTest('an unknown supplier is refused with the API\'s sentence', () async {
      final repo = await repoFor();
      await expectLater(
        repo.supplier('no-such-supplier'),
        throwsA(isA<Object>().having((e) => ApiError.from(e).statusCode, 'status', 404)),
      );
    });

    liveTest('the tabs read what they show: services, products, compliances', () async {
      final repo = await repoFor();
      final market = MarketplaceController(repo);
      addTearDown(market.dispose);
      await market.start();
      final seed = await repo.supplier(vikasha);
      final c = SupplierController(repository: repo, seed: seed);
      addTearDown(c.dispose);
      await c.load();
      expect(c.supplier.name, 'Vikasha Aero Tech');
      expect(c.services.loaded, isFalse);

      await c.select(SupplierTab.catalog);
      final services = c.services.value!;
      expect(services.map((s) => s.name), [
        'Drone Facade Cleaning',
        'Robotic HVAC Inspection',
        'High-Rise Cobweb Vacuuming',
        'Specialized Industrial Cleaning',
        'Comprehensive HVAC Duct Care',
        'Commercial Pest Barrier',
      ]);
      expect(services.where((s) => s.bookable).map((s) => s.name), [
        'Robotic HVAC Inspection',
        'Comprehensive HVAC Duct Care',
      ]);
      expect(
        {for (final s in services) market.categoryName(s.subcategory ?? s.category!)},
        {'Housekeeping', 'HVAC', 'Pest Management'},
      );
      expect(c.products.value, isEmpty);

      await c.select(SupplierTab.proofs);
      final rows = c.compliances.value!;
      expect(rows.map((r) => r.title), [
        'DGCA Commercial Drone License',
        'ISO 9001:2015 Quality Management',
        'ISO 45001 Occupational Safety',
        'Escrow & Trade Assurance Policy',
      ]);
      expect(rows.map((r) => r.status), ['Active', 'Certified', 'Certified', 'Insured']);
      expect(rows.first.detail, 'Reg: #DGCA-KA-2024-UAV-781');
    });

    liveTest('a supplier\'s products: price, stock and terms as the supplier states them', () async {
      final repo = await repoFor();
      final securetech = await repo.supplier('design-mkt-v-securetech');
      final products = await repo.productsOf(securetech.companyId);
      expect(products.map((p) => p.name), [
        'Biometric Access Terminal',
        'IP CCTV Dome Camera, 4 MP',
        'Command Centre Video Wall Controller',
      ]);
      final terminal = products.first;
      expect(terminal.priceLabel, '₹18,500 / piece');
      expect(terminal.stock, ProductStock.inStock);
      expect(terminal.terms, contains('2-year warranty'));
      expect(terminal.supplierVendorId, isNotNull);
    });

    liveTest('the bookmark in the sheet: saved through the API, then taken back', () async {
      final repo = await repoFor();
      final market = MarketplaceController(repo);
      addTearDown(market.dispose);
      await market.start();
      final listed = await repo.supplier(sandbox);
      final c = SupplierController(
        repository: repo,
        seed: listed,
        saved: market.isSaved(sandbox),
        onSaved: market.markSaved,
      );
      addTearDown(c.dispose);
      addTearDown(() async {
        try {
          await repo.setSaved(sandbox, false);
        } catch (_) {}
      });
      await repo.setSaved(sandbox, false);
      expect(await c.toggleSave(), isNull);
      expect(c.saved, isTrue);
      expect(market.isSaved(sandbox), isTrue);
      expect(await repo.savedIds(), contains(sandbox));
      expect(await c.toggleSave(), isNull);
      expect(c.saved, isFalse);
      expect(await repo.savedIds(), isNot(contains(sandbox)));
    });

    liveTest('a rating: the API keeps one per member and replaces it, and the average follows', () async {
      final repo = await repoFor();
      final first = await repo.supplier(sandbox);
      final c = SupplierController(repository: repo, seed: first);
      addTearDown(c.dispose);

      expect(await c.rate(score: 4, comment: 'Quick and tidy.'), isNull);
      final after = await repo.supplier(sandbox);
      expect(after.reviews.any((r) => r.comment == 'Quick and tidy.' && r.score == 4), isTrue);
      expect(after.ratingCount, 1, reason: 'the API recounts from the ratings it holds (the seed resets them)');
      expect(after.rating, 4);

      // Rating again replaces the member's rating, it does not add one.
      expect(await c.rate(score: 2), isNull);
      final again = await repo.supplier(sandbox);
      expect(again.ratingCount, 1);
      expect(again.rating, 2);
      expect(again.reviews.single.comment, isNull);
    });

    liveTest('a supplier with nobody to receive a message: the API\'s own sentence, nothing opened', () async {
      final repo = await repoFor();
      final c = SupplierController(repository: repo, seed: await repo.supplier(sandbox));
      addTearDown(c.dispose);
      final result = await c.startConversation(message: 'Hello');
      expect(result.conversationId, isNull);
      expect(result.error, isNotEmpty);
    });
  });

  group('asking for a quote', () {
    /// Deletes a requirement the test made (`DELETE /rfq/:id` removes the member's own, its invitation with it).
    Future<void> remove(LivePerson who, String id) async => (await liveClient(who)).dio.delete<dynamic>('/rfq/$id');

    liveTest(
      'a quote request to one supplier is a private published enquiry the API keeps, and it goes away again',
      () async {
        final api = await liveClient(marketBuyer);
        final repo = ApiMarketplaceRepository(api: api);
        final supplier = await repo.supplier(sandbox);
        final services = await repo.servicesOf(supplier.companyId);
        expect(services, isNotEmpty);
        expect(await repo.hasPhone(), isTrue, reason: 'the seeded admin has a number on file');

        final sent = await repo.requestQuote(
          QuoteRequest(
            vendorId: supplier.id,
            supplierName: supplier.name,
            service: services.first,
            scope: '14 towers, 600,000 sq ft',
            timeline: QuoteTimeline.within30,
            notes: 'Live test: night shifts only.',
          ),
        );
        addTearDown(() => remove(marketBuyer, sent.id));
        expect(sent.id, isNotEmpty);
        expect(sent.title, 'Housekeeping contract — quote request');

        final rfq = await getMap(api, '/rfq/${sent.id}');
        expect(rfq['kind'], 'ENQUIRY');
        expect(rfq['status'], 'PUBLISHED');
        expect(rfq['visibility'], 'TARGETED');
        expect(rfq['category'], services.first.category);
        expect(rfq['subcategory'], services.first.subcategory);
        expect(
          rfq['description'],
          'Scope: 14 towers, 600,000 sq ft\nTimeline: Within 30 days\nLive test: night shifts only.',
        );
        // It counts on the member's "My RFQ's" chip.
        expect((await repo.counts()).myRfqs, greaterThan(0));
      },
    );

    liveTest('a product is the requirement\'s one line item', () async {
      final api = await liveClient(marketBuyer);
      final repo = ApiMarketplaceRepository(api: api);
      final securetech = await repo.supplier('design-mkt-v-securetech');
      final product = (await repo.productsOf(securetech.companyId)).first;
      final sent = await repo.requestQuote(
        QuoteRequest(vendorId: securetech.id, supplierName: securetech.name, product: product, quantity: 12),
      );
      addTearDown(() => remove(marketBuyer, sent.id));
      final rfq = await getMap(api, '/rfq/${sent.id}');
      final items = (rfq['items'] as List).cast<Map<String, dynamic>>();
      expect(items.single['name'], 'Biometric Access Terminal');
      expect(items.single['quantity'], 12);
      expect(items.single['unit'], 'piece');
    });

    liveTest('the form\'s controller sends through the API and reports the requirement', () async {
      final repo = ApiMarketplaceRepository(api: await liveClient(marketBuyer));
      final supplier = await repo.supplier(sandbox);
      final controller = QuoteController(repository: repo, supplier: supplier);
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.needsPhone, isFalse);
      expect(controller.options, isNotNull);
      controller.pickService(controller.options!.first);
      expect(await controller.submit(), isTrue, reason: controller.error ?? '');
      addTearDown(() => remove(marketBuyer, controller.sent!.id));
      expect(controller.sent!.title, contains('quote request'));
    });

    liveTest(
      'a buyer with no number on file is asked for one: refused without it, saved to the profile with it',
      () async {
        final repo = ApiMarketplaceRepository(api: await liveClient(marketNoPhone));
        if (await repo.hasPhone()) {
          // A run saves his number to his profile and the API has no way to take it off: the seed does.
          markTestSkipped('his number is on file from an earlier run; run tool/seed/marketplace.ts to take it off');
          return;
        }
        final supplier = await repo.supplier(sandbox);

        // The API refuses with its own sentence when no number comes with the request.
        await expectLater(
          repo.requestQuote(QuoteRequest(vendorId: supplier.id, supplierName: supplier.name)),
          throwsA(
            isA<Object>().having(
              (e) => ApiError.from(e).message,
              'message',
              'Add a mobile number so the supplier can reach you.',
            ),
          ),
        );

        // The form asks for it up front, refuses a short one itself, and sends a good one.
        final controller = QuoteController(repository: repo, supplier: supplier);
        addTearDown(controller.dispose);
        await controller.load();
        expect(controller.needsPhone, isTrue);
        expect(await controller.submit(), isFalse);
        expect(controller.phoneProblem, startsWith('Add a mobile number'));
        controller.phone.text = '12345';
        expect(await controller.submit(), isFalse);
        expect(controller.phoneProblem, startsWith('Enter a valid mobile number'));
        controller.phone.text = '+91 98765 43210';
        expect(await controller.submit(), isTrue, reason: controller.error ?? '');
        addTearDown(() => remove(marketNoPhone, controller.sent!.id));
        // The number is on his profile now.
        expect(await repo.hasPhone(), isTrue);
      },
    );

    liveTest('a member who is not a company\'s buyer is refused, and the form says what to do', () async {
      final repo = ApiMarketplaceRepository(api: await liveClient(pooja));
      final supplier = await repo.supplier(sandbox);
      final controller = QuoteController(repository: repo, supplier: supplier);
      addTearDown(controller.dispose);
      await controller.load();
      controller.notes.text = 'Live test, expected to be refused.';
      expect(await controller.submit(), isFalse);
      expect(controller.sent, isNull);
      expect(controller.error, isNotEmpty);
      expect(controller.notes.text, 'Live test, expected to be refused.', reason: 'what was typed stays');
    });
  });

  group('products, services and categories', () {
    liveTest('a product\'s own read: price, stock, terms, category and who sells it', () async {
      final repo = await repoFor();
      final p = await repo.product('design-mkt-pr-1');
      expect(p.name, 'Biometric Access Terminal');
      expect(p.priceLabel, '₹18,500 / piece');
      expect(p.stock, ProductStock.inStock);
      expect(p.terms, ['2-year warranty', '7-day returns', 'Free delivery over ₹25,000', 'Bulk pricing from 10 piece']);
      expect(p.categoryName, 'Access Control');
      expect(p.supplierName, 'SecureTech');
      expect(p.supplierVendorId, 'design-mkt-v-securetech');
      expect(p.supplierLevel, 'ELITE');
      // The page's "Sold by" reads the listing the product names.
      final controller = CatalogItemController<CatalogProduct>(
        read: () => repo.product('design-mkt-pr-1'),
        supplierFor: (p) async => repo.supplier(p.supplierVendorId!),
      );
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.error, isNull);
      expect(controller.item!.name, 'Biometric Access Terminal');
      expect(controller.supplier!.name, 'SecureTech');
      expect(controller.supplier!.detailed, isTrue);
    });

    liveTest('a service\'s own read, and the supplier of its company', () async {
      final repo = await repoFor();
      final s = await repo.service('design-mkt-sv-2');
      expect(s.name, 'Robotic HVAC Inspection');
      expect(s.subcategory, 'HVAC');
      expect(s.bookable, isTrue);
      expect(s.rateLabel, '₹18,000 per inspection');
      expect(s.supplierName, 'Vikasha Aero Tech');
      final controller = CatalogItemController<CatalogService>(
        read: () => repo.service('design-mkt-sv-2'),
        supplierFor: (s) => repo.supplierOfCompany(s.companyId),
      );
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.supplier!.id, vikasha);
      expect(controller.supplier!.level.tier, 'Tier-1');
    });

    liveTest('an unknown product or service is refused, and the page says so', () async {
      final repo = await repoFor();
      final controller = CatalogItemController<CatalogProduct>(
        read: () => repo.product('no-such-product'),
        supplierFor: (_) async => null,
      );
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.item, isNull);
      expect(controller.error, isNotEmpty);
    });

    liveTest('the product board: search, a category, and a page at a time', () async {
      final repo = await repoFor(bharat, 5);
      final found = await repo.products(search: 'terminal');
      expect(found.items.map((p) => p.name), contains('Biometric Access Terminal'));

      final raw = await getMap(await liveClient(), '/products/design-mkt-pr-1');
      final slug = (raw['category'] as Map<String, dynamic>)['slug'] as String;
      final inCategory = await repo.products(categorySlug: slug);
      expect(inCategory.items.map((p) => p.id), contains('design-mkt-pr-1'));

      final nothing = await repo.products(search: 'zzzzqqxx');
      expect(nothing.items, isEmpty);
      expect(nothing.total, 0);

      final first = await repo.products();
      expect(first.items, hasLength(5));
      expect(first.hasMore, isTrue);
    });

    liveTest(
      'the products of one supplier page one after the other, none twice (its own products have distinct dates)',
      () async {
        final repo = await repoFor(bharat, 2);
        final securetech = await repo.supplier('design-mkt-v-securetech');
        final first = await repo.products(companyId: securetech.companyId);
        final second = await repo.products(companyId: securetech.companyId, page: 2);
        expect(first.items.map((p) => p.name), ['Biometric Access Terminal', 'IP CCTV Dome Camera, 4 MP']);
        expect(first.hasMore, isTrue);
        expect(second.items.map((p) => p.name), ['Command Centre Video Wall Controller']);
        expect(second.hasMore, isFalse);
      },
    );

    liveTest('the service board: search, a category, and the supplier\'s own services', () async {
      final repo = await repoFor();
      final found = await repo.services(search: 'Duct');
      expect(found.items.map((s) => s.name), contains('Comprehensive HVAC Duct Care'));

      final inCategory = await repo.services(category: 'FACILITY_MANAGEMENT');
      expect(inCategory.total, greaterThan(0));
      expect(inCategory.items.every((s) => s.category == 'FACILITY_MANAGEMENT'), isTrue);

      final board = CatalogBoardController(repository: repo, kind: CatalogKind.services);
      addTearDown(board.dispose);
      await board.start();
      expect(board.items, isNotEmpty);
      await board.setSearch('Pest Barrier');
      expect(board.items.map((s) => (s as CatalogService).name), contains('Commercial Pest Barrier'));
      await board.setSearch('zzzzqqxx');
      expect(board.items, isEmpty);
    });

    liveTest('a catalogue board of products pages on and shows each product once', () async {
      // The API breaks ties between equal rows differently from one page's query to the next (request 1 in
      // docs/backend-requests/marketplace.md), so the board can miss a row; what it must never do is show one twice.
      final repo = await repoFor(bharat, 4);
      final board = CatalogBoardController(repository: repo, kind: CatalogKind.products);
      addTearDown(board.dispose);
      await board.start();
      var pages = 1;
      while (board.hasMore && pages < 40) {
        await board.loadMore();
        pages++;
      }
      expect(pages, greaterThan(2));
      final ids = board.items.map((p) => (p as CatalogProduct).id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      expect(ids.length, lessThanOrEqualTo(board.total));
    });

    liveTest(
      'the category tree the browser lists: top categories with their sub-categories and how many suppliers each holds',
      () async {
        final repo = await repoFor();
        final tree = await repo.categories();
        expect(tree.length, greaterThan(10));
        final security = tree.firstWhere((n) => n.key == 'SECURITY');
        expect(security.slug, isNotEmpty);
        expect(security.blurb ?? '', isNotNull);
        expect(security.children.map((c) => c.key), containsAll(['PHYSICAL_SECURITY', 'ELECTRONIC_SECURITY']));
        expect(security.count, greaterThan(0));
        // A category's page offers its suppliers: the count is what the directory returns for it.
        final page = await repo.suppliers(const MarketplaceFilters(categories: {'SECURITY'}));
        expect(page.total, security.count);
      },
    );
  });
}
