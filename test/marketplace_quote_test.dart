import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/features/marketplace/catalog_models.dart';
import 'package:icr_mobile/features/marketplace/marketplace_navigation.dart';
import 'package:icr_mobile/features/marketplace/quote_models.dart';
import 'package:icr_mobile/features/marketplace/widgets/supplier_card.dart';

import 'helpers/fonts.dart';
import 'marketplace_fakes.dart';
import 'marketplace_harness.dart';

/// The request-a-quote form: what it asks, what it refuses before the API does,
/// what it sends (`POST /rfq`, a private requirement for one supplier), and that a
/// refusal never costs the member what they typed. The real API's answer to the
/// same request is in `test/live/marketplace_live_test.dart`.

const _id = 'v1';

const _facade = CatalogService(
  id: 'sv1',
  companyId: 'co-v1',
  name: 'Drone Facade Cleaning',
  category: 'FACILITY_MANAGEMENT',
  subcategory: 'HOUSEKEEPING',
  description: 'Precision wash for high-rise glass towers.',
);
const _duct = CatalogService(
  id: 'sv2',
  companyId: 'co-v1',
  name: 'HVAC Duct Care',
  category: 'FACILITY_MANAGEMENT',
  subcategory: 'HVAC',
  rate: 45000,
  rateUnit: 'per visit',
);
const _terminal = CatalogProduct(
  id: 'p1',
  companyId: 'co-v1',
  name: 'Biometric Access Terminal',
  price: 18500,
  unit: 'piece',
  stock: ProductStock.inStock,
);

SpyMarketplaceRepository repoFor({
  List<CatalogService> services = const [_facade, _duct],
  List<CatalogProduct> products = const [_terminal],
}) => SpyMarketplaceRepository()
  ..searchAnswer = ((f, p) => pageWith([fakeSupplier(_id, name: 'Vikasha Aero Tech')]))
  ..supplierAnswer = ((id) => fullSupplier(_id))
  ..servicesAnswer = ((id) => services)
  ..productsAnswer = ((id) => products);

/// Opens the first supplier's profile and taps its "Request for Quote (RFQ)".
Future<MartUnderTest> openForm(
  WidgetTester tester, {
  SpyMarketplaceRepository? repo,
  MarketplaceNavigation navigation = MarketplaceNavigation.none,
}) async {
  final mart = await pumpMart(tester, repo: repo ?? repoFor(), size: const Size(390, 1000), navigation: navigation);
  await tester.tap(find.byType(SupplierCard).first);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('request-quote')));
  await tester.pumpAndSettle();
  expect(find.text('Request a quote'), findsOneWidget);
  return mart;
}

Future<void> send(WidgetTester tester) async {
  final button = find.byKey(const ValueKey('quote-send'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> pickService(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(const ValueKey('quote-service')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  group('the request as it is sent', () {
    test('a general enquiry: the title names the supplier, the description holds the timeline', () {
      const r = QuoteRequest(vendorId: 'v9', supplierName: 'Vikasha Aero Tech');
      expect(r.title, 'Quote request — Vikasha Aero Tech');
      expect(r.description, 'Timeline: Immediate');
      expect(r.toJson(), {
        'kind': 'ENQUIRY',
        'status': 'PUBLISHED',
        'visibility': 'TARGETED',
        'title': 'Quote request — Vikasha Aero Tech',
        'description': 'Timeline: Immediate',
        'vendorIds': ['v9'],
      });
    });

    test('a service: its name titles it and its taxonomy keys go in the category fields', () {
      const r = QuoteRequest(
        vendorId: 'v9',
        supplierName: 'X',
        service: _facade,
        scope: '  50,000 sq ft  ',
        timeline: QuoteTimeline.amc,
        notes: ' Night shifts only. ',
      );
      expect(r.title, 'Drone Facade Cleaning — quote request');
      expect(r.description, 'Scope: 50,000 sq ft\nTimeline: AMC contract\nNight shifts only.');
      final body = r.toJson();
      expect(body['category'], 'FACILITY_MANAGEMENT');
      expect(body['subcategory'], 'HOUSEKEEPING');
      expect(body.containsKey('items'), isFalse);
    });

    test('a product is the requirement\'s one line item, with its quantity and unit, and no category guessed', () {
      const r = QuoteRequest(
        vendorId: 'v9',
        supplierName: 'X',
        product: _terminal,
        quantity: 12,
        timeline: QuoteTimeline.within30,
      );
      final body = r.toJson();
      expect(body['title'], 'Biometric Access Terminal — quote request');
      expect(body['items'], [
        {'name': 'Biometric Access Terminal', 'quantity': 12, 'unit': 'piece'},
      ]);
      expect(body.containsKey('category'), isFalse);
      expect(body['description'], 'Timeline: Within 30 days');
    });

    test('a phone is sent only when there is one', () {
      expect(
        const QuoteRequest(vendorId: 'v', supplierName: 'X', phone: '  +91 98765 43210 ').toJson()['phone'],
        '+91 98765 43210',
      );
      expect(const QuoteRequest(vendorId: 'v', supplierName: 'X', phone: '  ').toJson().containsKey('phone'), isFalse);
      expect(const QuoteRequest(vendorId: 'v', supplierName: 'X').toJson().containsKey('phone'), isFalse);
    });

    test('a long name never makes a title the API refuses (200 characters at most)', () {
      final r = QuoteRequest(vendorId: 'v', supplierName: 'S' * 400);
      expect(r.title.length, QuoteLimits.title);
    });

    test('the quantity and the mobile are checked the way the API checks them', () {
      expect(quantityIssue(''), isNotNull);
      expect(quantityIssue('abc'), 'Enter a whole number.');
      expect(quantityIssue('1.5'), 'Enter a whole number.');
      expect(quantityIssue('0'), 'Enter a number from 1 to 1,000,000.');
      expect(quantityIssue('1000001'), 'Enter a number from 1 to 1,000,000.');
      expect(quantityIssue('1'), isNull);
      expect(quantityIssue(' 1000000 '), isNull);
      expect(mobileIssue(''), startsWith('Add a mobile number'));
      expect(mobileIssue('12345'), startsWith('Enter a valid mobile number'));
      expect(mobileIssue('+91 98765 43210'), isNull);
    });
  });

  group('the form', () {
    testWidgets('opens from the profile\'s Request for Quote, private to the supplier, and asks only what it needs', (
      tester,
    ) async {
      final mart = await openForm(tester);
      expect(find.text('Sent privately to Vikasha Aero Tech.'), findsOneWidget);
      expect(find.text('Required service'), findsOneWidget);
      expect(find.text('Not sure: a general enquiry'), findsOneWidget);
      expect(find.text('Project scope / area'), findsOneWidget);
      expect(find.text('Target timeline'), findsOneWidget);
      expect(find.text('Brief project notes'), findsOneWidget);
      // A member with a number on file is not asked for one.
      expect(find.text('Your mobile number'), findsNothing);
      expect(mart.repo.calls, containsAll(['hasPhone', 'servicesOf']));
    });

    testWidgets('sent with nothing filled in: a general enquiry that goes out now, then a confirmation', (
      tester,
    ) async {
      final mart = await openForm(tester);
      await send(tester);
      final q = mart.repo.quotes.single;
      expect(q.vendorId, _id);
      expect(q.service, isNull);
      expect(q.title, 'Quote request — Vikasha Aero Tech');
      expect(q.timeline, QuoteTimeline.immediate);
      expect(find.byKey(const ValueKey('quote-sent')), findsOneWidget);
      expect(find.text('Request sent'), findsOneWidget);
      expect(find.textContaining('Vikasha Aero Tech has your request'), findsOneWidget);
    });

    testWidgets('a chosen service, the scope, a timeline and the notes all go in the request', (tester) async {
      final mart = await openForm(tester);
      await pickService(tester, 'HVAC Duct Care');
      await tester.enterText(find.byKey(const ValueKey('quote-scope')), '14 towers, 600,000 sq ft');
      await tester.tap(find.byKey(const ValueKey('timeline-amc')));
      await tester.pump();
      await tester.enterText(find.byKey(const ValueKey('quote-notes')), 'Night shifts only.');
      await send(tester);

      final q = mart.repo.quotes.single;
      expect(q.service?.id, 'sv2');
      expect(q.scope, '14 towers, 600,000 sq ft');
      expect(q.timeline, QuoteTimeline.amc);
      expect(q.toJson()['subcategory'], 'HVAC');
      expect(q.description, 'Scope: 14 towers, 600,000 sq ft\nTimeline: AMC contract\nNight shifts only.');
    });

    testWidgets('a service row\'s Get Quote opens the form for that service', (tester) async {
      final mart = await pumpMart(tester, repo: repoFor(), size: const Size(390, 1000));
      await tester.tap(find.byType(SupplierCard).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tab-catalog')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: find.byKey(const ValueKey('service-sv1')), matching: find.text('Get Quote')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Request a quote'), findsOneWidget);
      expect(find.text('Drone Facade Cleaning'), findsWidgets);
      await send(tester);
      expect(mart.repo.quotes.single.title, 'Drone Facade Cleaning — quote request');
    });

    testWidgets('a product: the product, a quantity that must be a whole number up to a million, its unit', (
      tester,
    ) async {
      final mart = await pumpMart(tester, repo: repoFor(), size: const Size(390, 1000));
      await tester.tap(find.byType(SupplierCard).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tab-catalog')));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byKey(const ValueKey('product-p1')), matching: find.text('Get Quote')));
      await tester.pumpAndSettle();
      expect(find.text('Biometric Access Terminal'), findsWidgets);
      expect(find.text('₹18,500 / piece'), findsWidgets);
      expect(find.text('Project scope / area'), findsNothing);

      const refused = {
        '': 'Enter how many you need.',
        '0': 'Enter a number from 1 to 1,000,000.',
        '2.5': 'Enter a whole number.',
        '1000001': 'Enter a number from 1 to 1,000,000.',
        'ten': 'Enter a whole number.',
      };
      for (final entry in refused.entries) {
        await tester.enterText(find.byKey(const ValueKey('quote-quantity')), entry.key);
        await send(tester);
        expect(find.text(entry.value), findsOneWidget, reason: 'quantity "${entry.key}"');
        expect(mart.repo.quotes, isEmpty, reason: 'quantity "${entry.key}" is refused before the API is asked');
      }

      await tester.enterText(find.byKey(const ValueKey('quote-quantity')), '24');
      await send(tester);
      final body = mart.repo.quotes.single.toJson();
      expect(body['items'], [
        {'name': 'Biometric Access Terminal', 'quantity': 24, 'unit': 'piece'},
      ]);
    });
  });

  group('the mobile number', () {
    testWidgets('asked when the profile has none, refused when short, sent and saved when good', (tester) async {
      final repo = repoFor()..phoneOnFile = false;
      final mart = await openForm(tester, repo: repo);
      expect(find.text('Your mobile number'), findsOneWidget);

      await send(tester);
      expect(find.text('Add a mobile number so the supplier can reach you.'), findsOneWidget);
      expect(mart.repo.quotes, isEmpty);

      await tester.enterText(find.byKey(const ValueKey('quote-phone')), '12345');
      await send(tester);
      expect(find.textContaining('Enter a valid mobile number'), findsOneWidget);
      expect(mart.repo.quotes, isEmpty);

      await tester.enterText(find.byKey(const ValueKey('quote-phone')), '+91 98765 43210');
      await send(tester);
      expect(mart.repo.quotes.single.toJson()['phone'], '+91 98765 43210');
    });

    testWidgets('a profile that cannot be read: the API is asked, and its refusal for a number brings the field up', (
      tester,
    ) async {
      final repo = repoFor()..failing['hasPhone'] = ApiError('offline');
      var refuse = true;
      final mart = await openForm(tester, repo: repo);
      expect(find.text('Your mobile number'), findsNothing);
      repo.failing.remove('hasPhone');
      // The API refuses the first send for want of a number.
      repo.failing['requestQuote'] = ApiError('Add a mobile number so the supplier can reach you.', statusCode: 400);
      await tester.enterText(find.byKey(const ValueKey('quote-notes')), 'Keep this text');
      await send(tester);
      expect(find.text('Add a mobile number so the supplier can reach you.'), findsWidgets);
      expect(find.text('Your mobile number'), findsOneWidget);
      expect(find.text('Keep this text'), findsOneWidget);
      refuse = false;
      repo.failing.clear();
      await tester.enterText(find.byKey(const ValueKey('quote-phone')), '+91 98765 43210');
      await send(tester);
      expect(refuse, isFalse);
      expect(mart.repo.quotes.last.phone, '+91 98765 43210');
      expect(find.byKey(const ValueKey('quote-sent')), findsOneWidget);
    });
  });

  group('when the API refuses', () {
    testWidgets('a member who may not post requirements is told what to do, and keeps what they typed', (tester) async {
      final repo = repoFor()..failing['requestQuote'] = ApiError('Forbidden resource', statusCode: 403);
      final mart = await openForm(tester, repo: repo);
      await pickService(tester, 'Drone Facade Cleaning');
      await tester.enterText(find.byKey(const ValueKey('quote-scope')), '14 towers');
      await tester.enterText(find.byKey(const ValueKey('quote-notes')), 'Night shifts only.');
      await send(tester);

      expect(find.byKey(const ValueKey('quote-error')), findsOneWidget);
      expect(find.textContaining('Only a company can ask suppliers for quotes'), findsOneWidget);
      expect(find.byKey(const ValueKey('quote-create-company')), findsOneWidget);
      // Still the form, with every field as it was.
      expect(find.text('Request a quote'), findsOneWidget);
      expect(find.text('14 towers'), findsOneWidget);
      expect(find.text('Night shifts only.'), findsOneWidget);
      expect(find.text('Drone Facade Cleaning'), findsWidgets);
      expect(mart.repo.quotes, hasLength(1));

      // Trying again sends the same request.
      repo.failing.clear();
      await send(tester);
      expect(mart.repo.quotes, hasLength(2));
      expect(mart.repo.quotes.last.scope, '14 towers');
      expect(find.byKey(const ValueKey('quote-sent')), findsOneWidget);
    });

    testWidgets(
      'a buyer with no company reads the API sentence as it is, and is offered Create a company, keeping the form',
      (tester) async {
        const said =
            'Requirements are posted for a company. Register your company, or switch to one you belong to, then post again.';
        final repo = repoFor()..failing['requestQuote'] = ApiError(said, statusCode: 403);
        var created = 0;
        await openForm(
          tester,
          repo: repo,
          navigation: MarketplaceNavigation(onCreateCompany: () => created++),
        );
        await tester.enterText(find.byKey(const ValueKey('quote-notes')), 'Night shifts only.');
        expect(find.byKey(const ValueKey('quote-create-company')), findsNothing, reason: 'nothing was refused yet');
        await send(tester);

        // The sentence is the API's, word for word, and the way out is right under it.
        expect(find.text(said), findsOneWidget);
        final button = find.byKey(const ValueKey('quote-create-company'));
        expect(button, findsOneWidget);
        expect(find.descendant(of: button, matching: find.text('Create a company')), findsOneWidget);

        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pump();
        expect(created, 1, reason: 'the button founds a company, in the app');
        // The form is still there with what was typed.
        expect(find.text('Request a quote'), findsOneWidget);
        expect(find.text('Night shifts only.'), findsOneWidget);
      },
    );

    testWidgets(
      'a professional is not shown "Insufficient role permissions": the form says why and offers the way out',
      (tester) async {
        final repo = repoFor()..failing['requestQuote'] = ApiError('Insufficient role permissions', statusCode: 403);
        await openForm(tester, repo: repo);
        await send(tester);
        expect(find.text('Insufficient role permissions'), findsNothing);
        expect(find.textContaining('Only a company can ask suppliers for quotes'), findsOneWidget);
        expect(find.byKey(const ValueKey('quote-create-company')), findsOneWidget);
      },
    );

    testWidgets('a refusal that is not about a company offers no Create a company', (tester) async {
      final repo = repoFor()
        ..failing['requestQuote'] = ApiError('You cannot invite your own company.', statusCode: 400);
      await openForm(tester, repo: repo);
      await send(tester);
      expect(find.text('You cannot invite your own company.'), findsOneWidget);
      expect(find.byKey(const ValueKey('quote-create-company')), findsNothing);

      // Nor does a 403 about something else, such as a suspended company.
      repo.failing['requestQuote'] = ApiError('Your company is suspended.', statusCode: 403);
      await send(tester);
      expect(find.text('Your company is suspended.'), findsOneWidget);
      expect(find.byKey(const ValueKey('quote-create-company')), findsNothing);

      // And a later send that goes through leaves no offer behind.
      repo.failing.clear();
      await send(tester);
      expect(find.byKey(const ValueKey('quote-sent')), findsOneWidget);
    });

    testWidgets('any other refusal is shown as the API worded it', (tester) async {
      final repo = repoFor()
        ..failing['requestQuote'] = ApiError('You cannot invite your own company.', statusCode: 400);
      await openForm(tester, repo: repo);
      await send(tester);
      expect(find.text('You cannot invite your own company.'), findsOneWidget);
    });

    testWidgets('while it is sending the form cannot be sent twice', (tester) async {
      final gate = Completer<void>();
      final repo = repoFor()..quoteGate = gate;
      final mart = await openForm(tester, repo: repo);
      await tester.tap(find.byKey(const ValueKey('quote-send')));
      await tester.pump();
      expect(find.text('Sending...'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('quote-send')), warnIfMissed: false);
      await tester.pump();
      expect(mart.repo.quotes, hasLength(1));
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('quote-sent')), findsOneWidget);
    });
  });

  group('after it is sent', () {
    testWidgets('"View my request" goes to the requirement: the lead\'s screen, else its page on the website', (
      tester,
    ) async {
      final opened = <String>[];
      await openForm(tester, navigation: MarketplaceNavigation(onOpenRfq: opened.add));
      await send(tester);
      await tester.tap(find.byKey(const ValueKey('quote-view')));
      await tester.pumpAndSettle();
      expect(opened, ['rfq-1']);

      await tester.pumpWidget(const SizedBox());
      final mart = await openForm(tester);
      await send(tester);
      await tester.tap(find.byKey(const ValueKey('quote-view')));
      await tester.pump();
      expect(mart.links.paths, ['/rfq/rfq-1']);
    });

    testWidgets('Done closes the sheet on the profile', (tester) async {
      await openForm(tester);
      await send(tester);
      await tester.tap(find.byKey(const ValueKey('quote-done')));
      await tester.pumpAndSettle();
      expect(find.text('Request sent'), findsNothing);
      expect(find.text('Request for Quote (RFQ)'), findsOneWidget);
    });

    testWidgets(
      'the lead can take the request over: Request for Quote calls the screen with the supplier, no form is shown',
      (tester) async {
        final asked = <String>[];
        final mart = await pumpMart(
          tester,
          repo: repoFor(),
          size: const Size(390, 1000),
          navigation: MarketplaceNavigation(onRequestQuote: (s, {service, product}) => asked.add(s.id)),
        );
        await tester.tap(find.byType(SupplierCard).first);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('request-quote')));
        await tester.pumpAndSettle();
        expect(asked, [_id]);
        expect(find.text('Request a quote'), findsNothing);
        expect(mart.repo.calls, isNot(contains('hasPhone')));
      },
    );
  });
}
