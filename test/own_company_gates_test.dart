/// Nothing is offered on what the member's own company owns that the website does not offer (owner, 5 Nov 2026: "if
/// he has the company he can't hire for the same company, and if he has the requirement post he can't bid for his own
/// requirement"). Each gate is the website's, and the API's refusal behind it:
///
///  * a job: someone who posts the company's jobs (any company they belong to) is not offered Easy Apply, the match
///    or "Meet the hiring team" (`JobDetailPane`'s `postsHere`; `errors.applications.ownCompanyJob`);
///  * a requirement: the company's own is not bid on (`managesRequirement`; `errors.rfq.youCannotBidOnYourOwn`);
///  * a supplier listing: the company it is acting for is not asked for a quote, its team is not offered Message or
///    Rate (`SupplierQuoteCard`'s owner note; `errors.messaging.ownListing`, `errors.vendors.youCannotRateYourOwnListing`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/jobs/job_detail_controller.dart';
import 'package:icr_mobile/features/jobs/job_detail_sheet.dart';
import 'package:icr_mobile/features/jobs/job_models.dart';
import 'package:icr_mobile/features/marketplace/catalog_models.dart';
import 'package:icr_mobile/features/marketplace/marketplace_controller.dart';
import 'package:icr_mobile/features/marketplace/marketplace_models.dart';
import 'package:icr_mobile/features/marketplace/quote_controller.dart';
import 'package:icr_mobile/features/marketplace/quote_models.dart';
import 'package:icr_mobile/features/marketplace/widgets/request_quote_sheet.dart';
import 'package:icr_mobile/features/marketplace/widgets/supplier_card.dart';
import 'package:icr_mobile/features/rfq/demo_rfq_repository.dart';
import 'package:icr_mobile/features/rfq/rfq_links.dart' show RfqClock;
import 'package:icr_mobile/features/rfq/rfq_models.dart';
import 'package:icr_mobile/features/rfq/supplier_controllers.dart';
import 'package:provider/provider.dart';

import 'helpers/fonts.dart';
import 'jobs_fakes.dart';
import 'marketplace_fakes.dart';
import 'marketplace_harness.dart';
import 'rfq_fakes.dart';

/// The job source, with the answer to "does this member post the company's jobs?" replaced.
class _PostsRepo extends SpyJobsRepository {
  _PostsRepo({required this.posts});

  final bool posts;

  @override
  Future<bool> postsJobsFor(JobCompany company) async => posts;
}

/// The sample source, its one board requirement owned by [companyId] and posted by [buyerId].
class _OwnedRepo extends FlakyRfqRepository {
  _OwnedRepo({required this.buyerId, required this.companyId});

  final String buyerId;
  final String companyId;

  @override
  Future<Requirement> requirement(String id) async {
    final r = await super.requirement(id);
    return Requirement(
      id: r.id,
      title: r.title,
      kind: r.kind,
      status: r.status,
      buyerId: buyerId,
      companyId: companyId,
      dueDate: r.dueDate,
      createdAt: r.createdAt,
    );
  }
}

const _hiringContact = JobContact(name: 'Priya Nair', role: 'Recruiter');

Future<JobDetailController> _pumpJob(WidgetTester tester, {required bool posts}) async {
  tester.view.physicalSize = const Size(390, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = _PostsRepo(posts: posts)
    ..detailAnswer = Job(
      id: 'j1',
      title: 'Facilities Manager',
      company: const JobCompany(id: 'co-1', name: 'Acme Facilities'),
      city: 'Mumbai',
      country: 'India',
      workMode: WorkMode.onsite,
      easyApply: true,
      contact: _hiringContact,
      descriptionHtml: '<p>Run the estate.</p>',
    );
  final controller = JobDetailController(repository: repo, seed: fakeJob('j1'));
  addTearDown(controller.dispose);
  await tester.runAsync(controller.load);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: ChangeNotifierProvider.value(
        value: controller,
        child: const Scaffold(
          body: Column(
            children: [
              Expanded(child: JobSheetBody()),
              JobSheetBar(),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return controller;
}

/// A supplier's listing, [companyId] being the company that owns it.
Supplier _listing({String companyId = 'co-v1'}) => Supplier(
  id: 'v1',
  companyId: companyId,
  name: 'Vikasha Aero Tech',
  rating: 4.6,
  ratingCount: 0,
  level: SupplierLevel.verified,
  categories: const ['PHYSICAL_SECURITY'],
);

Future<MartUnderTest> _openListing(
  WidgetTester tester, {
  String? acting,
  Set<String> member = const {},
  List<CatalogService> services = const [],
}) async {
  final repo = SpyMarketplaceRepository()
    ..actingCompany = acting
    ..memberCompanies = member
    ..searchAnswer = ((f, p) => pageWith([fakeSupplier('v1', name: 'Vikasha Aero Tech')]))
    ..supplierAnswer = ((id) => fullSupplier('v1', name: 'Vikasha Aero Tech'))
    ..compliancesAnswer = ((id) => const [])
    ..servicesAnswer = ((id) => services)
    ..productsAnswer = ((id) => const []);
  final mart = await pumpMart(tester, repo: repo, size: const Size(390, 1000));
  await tester.tap(find.byType(SupplierCard).first);
  await tester.pumpAndSettle();
  return mart;
}

void main() {
  setUpAll(loadAppFonts);
  tearDown(RfqClock.reset);

  group('a job of a company the member posts for', () {
    testWidgets('has no Easy Apply and no hiring contact, only the website\'s sentence', (tester) async {
      await _pumpJob(tester, posts: true);
      expect(find.text('Easy Apply'), findsNothing);
      expect(find.byKey(const ValueKey('posts-here')), findsOneWidget);
      expect(
        find.text('You post jobs for Acme Facilities, so you manage this one rather than apply to it.'),
        findsOneWidget,
      );
      expect(find.text('Meet the Hiring Team'), findsNothing, reason: 'the API refuses the message too');
      expect(find.text('Message'), findsNothing);
    });

    testWidgets('is a job to apply to for everyone else, with its hiring contact', (tester) async {
      await _pumpJob(tester, posts: false);
      expect(find.text('Easy Apply'), findsOneWidget);
      expect(find.byKey(const ValueKey('posts-here')), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Meet the Hiring Team'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Meet the Hiring Team'), findsOneWidget);
      expect(find.text('Message'), findsOneWidget);
    });
  });

  group('a requirement of the company the member acts for', () {
    Future<OpportunityController> opportunity({required String? actingCompany, String user = 'u-seller'}) async {
      final repo = _OwnedRepo(buyerId: 'u-buyer', companyId: 'co-owner')
        ..poster = Poster(
          id: user,
          name: 'A Seller',
          email: 'seller@example.test',
          role: 'VENDOR',
          phone: '+919879879898',
          companyId: actingCompany,
          companyName: 'Acme Facilities',
        );
      final c = OpportunityController(repository: repo, rfqId: DemoRfqRepository.boardId);
      addTearDown(c.dispose);
      await c.start();
      return c;
    }

    test('is not bid on: the response card is the note, not a form', () async {
      final c = await opportunity(actingCompany: 'co-owner');
      expect(c.own, isTrue);
      expect(c.state, ResponseState.own);
    });

    test('is not bid on by the person who posted it, whichever company they act for', () async {
      final c = await opportunity(actingCompany: 'co-other', user: 'u-buyer');
      expect(c.own, isTrue, reason: 'the API refuses "buyer === user" first');
      expect(c.state, ResponseState.own);
    });

    test('is bid on by a seller acting for another company', () async {
      final c = await opportunity(actingCompany: 'co-other');
      expect(c.own, isFalse);
      expect(c.state, isNot(ResponseState.own));
    });
  });

  group('a supplier listing of the company the member acts for', () {
    testWidgets('is not asked for a quote: the bar says so, and offers no Message', (tester) async {
      await _openListing(tester, acting: 'co-v1', member: {'co-v1'});
      expect(find.byKey(const ValueKey('request-quote')), findsNothing);
      expect(find.byKey(const ValueKey('message-supplier')), findsNothing);
      expect(find.byKey(const ValueKey('own-listing')), findsOneWidget);
      expect(find.text(ownListingNote), findsOneWidget);
    });

    testWidgets('keeps both actions for a member of another company', (tester) async {
      await _openListing(tester, acting: 'co-other', member: {'co-other'});
      expect(find.byKey(const ValueKey('request-quote')), findsOneWidget);
      expect(find.byKey(const ValueKey('message-supplier')), findsOneWidget);
      expect(find.byKey(const ValueKey('own-listing')), findsNothing);
    });

    testWidgets('keeps both actions for a signed-in member with no company', (tester) async {
      await _openListing(tester);
      expect(find.byKey(const ValueKey('request-quote')), findsOneWidget);
      expect(find.byKey(const ValueKey('message-supplier')), findsOneWidget);
    });

    testWidgets('has no Message for a member acting as another company, but still takes a quote request', (
      tester,
    ) async {
      // The API refuses a message to a listing of any company the person belongs to; the website's quote card
      // swaps its form only for the company in use.
      await _openListing(tester, acting: 'co-other', member: {'co-other', 'co-v1'});
      expect(find.byKey(const ValueKey('message-supplier')), findsNothing);
      expect(find.byKey(const ValueKey('request-quote')), findsOneWidget);
    });

    testWidgets('has no quote button on its own services', (tester) async {
      const service = CatalogService(
        id: 'sv1',
        companyId: 'co-v1',
        name: 'Drone Facade Cleaning',
        description: 'Precision wash for glass towers.',
        turnaround: 'SLA: 24h Setup',
      );
      await _openListing(tester, acting: 'co-v1', member: {'co-v1'}, services: const [service]);
      await tester.tap(find.byKey(const ValueKey('tab-catalog')));
      await tester.pumpAndSettle();
      expect(find.text('Drone Facade Cleaning'), findsWidgets);
      expect(find.text(service.action), findsNothing);
    });

    testWidgets('the quote sheet opened from a product or service page says the same, in place of its form', (
      tester,
    ) async {
      final repo = SpyMarketplaceRepository()..actingCompany = 'co-v1';
      final market = MarketplaceController(repo);
      addTearDown(market.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ChangeNotifierProvider.value(
            value: market,
            child: Builder(
              builder: (context) => TextButton(
                key: const ValueKey('ask'),
                onPressed: () => showRequestQuoteSheet(context, _listing()),
                child: const Text('Ask'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('ask')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('quote-own-listing')), findsOneWidget);
      expect(find.text(ownListingNote), findsOneWidget);
      expect(find.text('Submit Quote Request'), findsNothing);
    });

    test('the quote controller knows the listing is the member\'s own', () async {
      final repo = SpyMarketplaceRepository()..actingCompany = 'co-v1';
      final own = QuoteController(repository: repo, supplier: _listing());
      addTearDown(own.dispose);
      await own.load();
      expect(own.ownListing, isTrue);

      final other = QuoteController(
        repository: SpyMarketplaceRepository()..actingCompany = 'co-x',
        supplier: _listing(),
      );
      addTearDown(other.dispose);
      await other.load();
      expect(other.ownListing, isFalse);
    });
  });
}
