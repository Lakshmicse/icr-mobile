/// Role matrix, part 2: the Marketplace and the requirements (RFQ) screens for the four accounts that belong to
/// no company. A person with no company cannot post a requirement or ask a supplier for a quote: the API says so
/// in a sentence, the screens show that sentence and offer "Create a company".
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/features/marketplace/api_marketplace_repository.dart';
import 'package:icr_mobile/features/marketplace/marketplace_filters.dart';
import 'package:icr_mobile/features/marketplace/quote_models.dart';
import 'package:icr_mobile/features/rfq/api_rfq_repository.dart';
import 'package:icr_mobile/features/rfq/rfq_models.dart';

import 'live.dart';
import 'role_buyer_support.dart';

final _markets = <String, ApiMarketplaceRepository>{};
ApiMarketplaceRepository marketOf(Who w) =>
    _markets.putIfAbsent(w.email, () => ApiMarketplaceRepository(api: w.api, pageSize: 12));

final _rfqs = <String, ApiRfqRepository>{};
ApiRfqRepository rfqOf(Who w) => _rfqs.putIfAbsent(w.email, () => ApiRfqRepository(api: w.api));

void roleBuyerMarket() {
  group('Marketplace', () {
    liveTest(
      'browse, sort, search, every filter, the category tree and the chip numbers answer for every account',
      () async {
        for (final w in await everyone()) {
          final repo = marketOf(w);
          final page = await repo.suppliers(const MarketplaceFilters());
          expect(page.suppliers, isNotEmpty, reason: '${w.email}: the mart opens on verified suppliers');
          expect(page.total, greaterThan(0));
          for (final sort in SupplierSort.values) {
            expect((await repo.suppliers(MarketplaceFilters(sort: sort))).suppliers, isNotEmpty, reason: sort.label);
          }
          final first = page.suppliers.first;
          final byName = await repo.suppliers(MarketplaceFilters(search: first.name));
          expect(byName.suppliers.map((s) => s.id), contains(first.id));
          expect((await repo.suppliers(const MarketplaceFilters(search: 'zzzzqqxx'))).suppliers, isEmpty);
          await repo.suppliers(const MarketplaceFilters(minRating: 4));
          await repo.suppliers(const MarketplaceFilters(gst: true));
          await repo.suppliers(const MarketplaceFilters(msme: true));
          await repo.suppliers(const MarketplaceFilters(minLevel: null));
          final cities = await repo.cities();
          if (cities.isNotEmpty) await repo.suppliers(MarketplaceFilters(city: cities.first));
          final tree = await repo.categories();
          expect(tree, isNotEmpty);
          await repo.suppliers(MarketplaceFilters(categories: {tree.first.key}));
          final extras = await repo.searchExtras('HVAC');
          expect(extras, isNotNull);
          final counts = await repo.counts();
          expect(counts.myRfqs, greaterThanOrEqualTo(0));
          expect(await repo.unreadNotifications(), greaterThanOrEqualTo(0));
          record('Marketplace: browse, sort, search, filters, categories, chips', w.person, 'works');
        }
      },
    );

    liveTest(
      'a supplier opens with its offices, services, products and compliances, and can be saved and unsaved',
      () async {
        for (final w in await everyone()) {
          final repo = marketOf(w);
          final supplier = (await repo.suppliers(const MarketplaceFilters(search: 'Vikasha'))).suppliers.firstWhere(
            (s) => s.name.contains('Vikasha'),
            orElse: () => throw StateError('the Marketplace seed is not in: run tool/seed/run.ps1'),
          );
          final full = await repo.supplier(supplier.id);
          expect(full.name, supplier.name);
          await repo.compliances(full.companyId);
          expect(await repo.servicesOf(full.companyId), isNotEmpty);
          await repo.productsOf(full.companyId);

          final before = await repo.savedIds();
          final was = before.contains(supplier.id);
          await repo.setSaved(supplier.id, !was);
          expect((await repo.savedIds()).contains(supplier.id), !was);
          final saved = await repo.savedSuppliers();
          expect(saved.suppliers.map((s) => s.id).contains(supplier.id), !was);
          await repo.setSaved(supplier.id, was);
          expect((await repo.savedIds()).contains(supplier.id), was);
          record('Marketplace: supplier sheet, save and unsave', w.person, 'works');
        }
      },
    );

    liveTest('products, services and the category browser read for every account', () async {
      for (final w in await everyone()) {
        final repo = marketOf(w);
        final products = await repo.products();
        final services = await repo.services();
        expect(services.items, isNotEmpty);
        if (products.items.isNotEmpty) await repo.product(products.items.first.id);
        await repo.service(services.items.first.id);
        record('Marketplace: products, services, boards', w.person, 'works');
      }
    });

    liveTest(
      'a person with no company who asks for a quote is refused in the API\'s own sentence, and nothing is written',
      () async {
        for (final w in await everyone()) {
          final repo = marketOf(w);
          final supplier = (await repo.suppliers(const MarketplaceFilters())).suppliers.first;
          final before = await _requirementCount(w);
          final err = await thrownBy(
            () => repo.requestQuote(
              QuoteRequest(
                vendorId: supplier.id,
                supplierName: supplier.name,
                scope: 'A role-matrix test of the refusal.',
                notes: 'Nothing should be written.',
              ),
            ),
          );
          expect(statusOf(err), 403, reason: '${w.email}: ${sentenceOf(err)}');
          final sentence = sentenceOf(err);
          expect(sentence, isNotEmpty);
          expect(await _requirementCount(w), before, reason: 'the refusal wrote no requirement');
          record('Marketplace: quote request without a company', w.person, 'refused correctly', '403 "$sentence"');
        }
      },
    );
  });

  group('Requirements (RFQ)', () {
    liveTest('the buyer\'s list and counts answer, or refuse in a sentence, for every account', () async {
      for (final w in await everyone()) {
        final repo = rfqOf(w);
        final isBuyerRole = w.me['role'] == 'BUYER';
        if (isBuyerRole) {
          final s = await repo.summary();
          final mine = await repo.mine();
          expect(mine.total, s.count(MyView.all), reason: '${w.email}: the list holds what the All tab counts');
          for (final v in [MyView.live, MyView.draft, MyView.awarded, MyView.ended]) {
            expect((await repo.mine(view: v)).total, s.count(v), reason: '${w.email}: ${v.label}');
          }
          // The chip on the Marketplace is the number of requirements the screen lists when it opens.
          final chip = (await marketOf(w).counts()).myRfqs;
          expect(chip, s.count(MyView.all), reason: '${w.email}: the Marketplace chip and the list agree');
          final rfqChip = (await repo.counts()).myRfqs;
          expect(rfqChip, s.count(MyView.all));
          record('Requirements: My RFQ\'s counts, list, chip', w.person, 'works', 'chip $chip = list ${mine.total}');
        } else {
          final err = await thrownBy(() => repo.summary());
          expect(statusOf(err), 403);
          expect((await marketOf(w).counts()).myRfqs, 0, reason: 'a refused list leaves the chip plain');
          record('Requirements: My RFQ\'s', w.person, 'refused correctly', '403 "${sentenceOf(err)}"');
        }
        final alerts = await repo.alerts();
        expect(alerts, isNotNull);
        record('Requirements: alerts', w.person, 'works');
      }
    });

    liveTest('posting a requirement without a company is refused in a sentence', () async {
      for (final w in await everyone()) {
        final repo = rfqOf(w);
        final err = await thrownBy(
          () => repo.create({
            'title': 'zz role matrix refusal',
            'kind': 'ENQUIRY',
            'status': 'PUBLISHED',
            'description': 'A requirement of twenty characters, never written.',
          }),
        );
        expect(statusOf(err), 403);
        record('Requirements: post without a company', w.person, 'refused correctly', '403 "${sentenceOf(err)}"');
      }
    });

    liveTest('the supplier side says it is for suppliers: the board, my bids', () async {
      for (final w in await everyone()) {
        final repo = rfqOf(w);
        // The supplier side reads `GET /vendors/me/access`: a person who sells nothing is refused it.
        final refused = await thrownBy(() => repo.access());
        expect(statusOf(refused), 403, reason: '${w.email}: ${sentenceOf(refused)}');
        final err = await thrownBy(() => repo.myBids());
        record(
          'Requirements: Find work and My Bids (supplier side)',
          w.person,
          'refused correctly',
          'access ${statusOf(refused)} "${sentenceOf(refused)}"; My Bids ${statusOf(err)}',
        );
      }
    });
  });
}

Future<int> _requirementCount(Who w) async {
  if (w.me['role'] != 'BUYER') return 0;
  return (await rfqOf(w).summary()).count(MyView.all);
}
