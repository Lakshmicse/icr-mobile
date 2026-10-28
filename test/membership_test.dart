import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/auth/token_store.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/core/widgets/buttons.dart';
import 'package:icr_mobile/features/contact/contact_screen.dart';
import 'package:icr_mobile/features/membership/demo_membership_repository.dart';
import 'package:icr_mobile/features/membership/membership_controller.dart';
import 'package:icr_mobile/features/membership/membership_format.dart';
import 'package:icr_mobile/features/membership/membership_models.dart';
import 'package:icr_mobile/features/membership/membership_repository.dart';
import 'package:icr_mobile/features/membership/membership_screen.dart';
import 'package:provider/provider.dart';

import 'helpers/fonts.dart';

/// Plans and a held plan under the test's control, recording every checkout.
class _Plans implements MembershipRepository {
  _Plans({this.held, this.canBuy = true, this.reason, this.refusal, this.gateway = false, this.plansError});

  MySubscription? held;
  bool canBuy;
  String? reason;

  /// The API's refusal of a checkout, when set.
  String? refusal;

  /// Answer a checkout with a gateway form instead of activating.
  bool gateway;
  String? plansError;
  final checkouts = <String>[];
  int planReads = 0;
  int mineReads = 0;

  static const _silverPrice = PlanPrice(id: 'price-silver', months: 12, pricePaisa: 499900);
  static const _goldPrice = PlanPrice(id: 'price-gold', months: 12, pricePaisa: 1299900, compareAtPaisa: 1499900);

  List<MembershipPlan> ladder(MembershipAudience a) => [
    MembershipPlan(
      id: 'free',
      name: 'Free',
      tier: 'FREE',
      audience: a,
      prices: const [PlanPrice(id: 'price-free', months: 12, pricePaisa: 0)],
      benefits: const [PlanBenefit(key: 'profile', text: 'A public profile')],
    ),
    MembershipPlan(
      id: 'silver',
      name: 'Silver',
      tier: 'SILVER',
      audience: a,
      description: 'For the active.',
      prices: const [_silverPrice],
      benefits: const [
        PlanBenefit(key: 'apply', text: '30 applications a month'),
        PlanBenefit(key: 'hidden', text: 'Nothing here', shown: false),
      ],
    ),
    MembershipPlan(
      id: 'gold',
      name: 'Gold',
      tier: 'GOLD',
      audience: a,
      prices: const [_goldPrice],
      benefits: const [
        PlanBenefit(key: 'apply', text: 'Unlimited applications'),
        PlanBenefit(key: 'manager', text: 'A named account manager', term: true),
      ],
    ),
    MembershipPlan(id: 'enterprise', name: 'Enterprise', tier: 'ENTERPRISE', audience: a, contactSales: true),
  ];

  @override
  Future<List<MembershipPlan>> plans(MembershipAudience audience) async {
    planReads++;
    if (plansError != null) throw ApiError(plansError!, statusCode: 500);
    return ladder(audience);
  }

  @override
  Future<MyPlan> mine(MembershipAudience audience) async {
    mineReads++;
    return MyPlan(
      audience: audience,
      tier: held?.tier ?? 'FREE',
      subscription: held,
      renewal: held == null ? null : const RenewalQuote(priceId: 'price-silver', totalPaisa: 589882),
      canBuy: canBuy,
      reason: reason,
    );
  }

  @override
  Future<MembershipHistory> history(MembershipAudience audience) async => MembershipHistory(
    audience: audience,
    terms: [
      MembershipTerm(
        id: 't1',
        planName: 'Silver',
        tier: 'SILVER',
        status: 'ACTIVE',
        startsAt: DateTime(2026, 3, 12),
        endsAt: DateTime(2027, 3, 11),
        totalPaisa: 589882,
      ),
      MembershipTerm(
        id: 't0',
        planName: 'Free',
        tier: 'FREE',
        status: 'EXPIRED',
        startsAt: DateTime(2025, 1, 1),
        endsAt: DateTime(2026, 3, 11),
        end: 'CHANGED_PLAN',
      ),
    ],
  );

  @override
  Future<CheckoutOutcome> checkout(String priceId) async {
    checkouts.add(priceId);
    if (refusal != null) throw ApiError(refusal!, statusCode: 409);
    if (gateway) {
      return const CheckoutOutcome(
        subscriptionId: 's2',
        gatewayAction: 'https://test.payu.in/_payment',
        fields: {'key': 'k'},
      );
    }
    final plan = ladder(MembershipAudience.seeker).firstWhere((p) => p.prices.any((x) => x.id == priceId));
    held = MySubscription(id: 's1', planId: plan.id, planName: plan.name, tier: plan.tier, status: 'ACTIVE');
    return const CheckoutOutcome(subscriptionId: 's1', devActivated: true);
  }
}

class _NoTokens extends TokenStore {
  @override
  Future<String?> accessToken() async => 'token';
  @override
  Future<String?> refreshToken() async => null;
}

/// Records what the app hands to the browser.
class _Launches {
  final urls = <String>[];

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      (call) async {
        if (call.method == 'launch') urls.add((call.arguments as Map)['url'] as String);
        return true;
      },
    );
  }

  void remove() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/url_launcher'),
    null,
  );
}

void main() {
  setUpAll(loadAppFonts);

  late _Launches launches;
  setUp(() => launches = _Launches()..install());
  tearDown(() => launches.remove());

  group('the models', () {
    test('a page of the website names its ladder', () {
      MembershipAudience? of(String s) => MembershipAudience.fromSitePath(Uri.parse('https://icr.org.in$s'));
      expect(of('/pricing/supplier'), MembershipAudience.supplier);
      expect(of('/pricing/corporate'), MembershipAudience.company);
      expect(of('/career/plans'), MembershipAudience.seeker);
      expect(of('/membership/history?audience=MENTOR'), MembershipAudience.mentor);
      expect(of('/pricing'), isNull);
      expect(of('/pricing/nothing'), isNull);
    });

    test('rupees group the Indian way and keep paise only when there are some', () {
      expect(rupees(499900), '₹4,999');
      expect(rupees(10000000), '₹1,00,000');
      expect(rupees(589882), '₹5,898.82');
      expect(rupees(0), '₹0');
    });

    test('a plan leads with its annual term, else the shortest; one with no price has none', () {
      const plan = MembershipPlan(
        id: 'p',
        name: 'P',
        tier: 'GOLD',
        audience: MembershipAudience.seeker,
        prices: [
          PlanPrice(id: 'm6', months: 6, pricePaisa: 100),
          PlanPrice(id: 'y', months: 12, pricePaisa: 150),
          PlanPrice(id: 'm1', months: 1, pricePaisa: 20),
        ],
      );
      expect(plan.headlineTerm?.id, 'y');
      const noYear = MembershipPlan(
        id: 'p',
        name: 'P',
        tier: 'GOLD',
        audience: MembershipAudience.seeker,
        prices: [
          PlanPrice(id: 'm6', months: 6, pricePaisa: 100),
          PlanPrice(id: 'm1', months: 1, pricePaisa: 20),
        ],
      );
      expect(noYear.headlineTerm?.id, 'm1');
      expect(const MembershipPlan(id: 'p', name: 'P', tier: 'GOLD', audience: null).headlineTerm, isNull);
    });

    test('the catalogue and the member\'s plan parse from the API\'s shapes', () {
      final plan = MembershipPlan.fromJson({
        'id': 'p1',
        'name': 'Standard',
        'tier': 'SILVER',
        'audience': 'SUPPLIER',
        'contactSales': false,
        'prices': [
          {'id': 'pr1', 'billingPeriodMonths': 12, 'pricePaisa': 499900, 'active': true},
        ],
        'benefits': [
          {'key': 'rfq.bids', 'text': '20 bids a month', 'shown': true, 'style': 'benefit', 'headline': true},
          {'key': 'am', 'text': 'Account manager', 'shown': true, 'style': 'term', 'headline': false},
        ],
      });
      expect(plan.audience, MembershipAudience.supplier);
      expect(plan.features.map((b) => b.text), ['20 bids a month']);
      expect(plan.terms.map((b) => b.text), ['Account manager']);
      final mine = MyPlan.fromJson({
        'subscription': {
          'id': 's',
          'planId': 'p1',
          'status': 'ACTIVE',
          'currentPeriodEnd': '2027-03-11T18:29:59.000Z',
          'cancelAtPeriodEnd': false,
          'autoRenew': false,
          'plan': {'id': 'p1', 'name': 'Standard', 'tier': 'SILVER', 'audience': 'SUPPLIER'},
        },
        'tier': 'SILVER',
        'audience': 'SUPPLIER',
        'renewal': {'priceId': 'pr1', 'totalPaisa': 589882, 'priceChanged': true},
        'canBuy': false,
        'reason': 'Create a company first.',
      }, fallback: MembershipAudience.seeker);
      expect(mine.subscription?.planName, 'Standard');
      expect(mine.renewal?.totalPaisa, 589882);
      expect(mine.canBuy, isFalse);
      expect(mine.reason, 'Create a company first.');
    });
  });

  group('the controller', () {
    test('reads the ladder and the plan held; switching the ladder reads again', () async {
      final repo = _Plans();
      final c = MembershipController(repo, audience: MembershipAudience.supplier);
      await c.start();
      expect(c.plans.map((p) => p.name), ['Free', 'Silver', 'Gold', 'Enterprise']);
      expect(c.mine?.audience, MembershipAudience.supplier);
      expect(c.isCurrent(c.plans.first), isTrue, reason: 'nothing held: the free rung is the current one');
      c.setAudience(MembershipAudience.mentor);
      await Future<void>.delayed(Duration.zero);
      expect(c.audience, MembershipAudience.mentor);
      expect(repo.planReads, 2);
    });

    test('choosing a plan sends its annual price; the API activating it marks it current', () async {
      final repo = _Plans();
      final c = MembershipController(repo);
      await c.start();
      await c.choose(c.plans[2]);
      expect(repo.checkouts, ['price-gold']);
      expect(c.message, "You're on Gold.");
      expect(c.isCurrent(c.plans[2]), isTrue);
      expect(c.busyPriceId, isNull);
    });

    test('a refusal is shown in the API\'s words; a gateway form hands over to the website', () async {
      final repo = _Plans(refusal: 'Your next term on Gold is already paid for.');
      final c = MembershipController(repo);
      await c.start();
      await c.choose(c.plans[1]);
      expect(c.message, 'Your next term on Gold is already paid for.');
      repo
        ..refusal = null
        ..gateway = true;
      await c.choose(c.plans[1]);
      expect(c.gateway?.gatewayAction, 'https://test.payu.in/_payment');
      expect(c.message, contains('continues on the ICR website'));
    });

    test('the free rung, the plan held and a plan with no price are never bought', () async {
      final repo = _Plans(
        held: const MySubscription(id: 's', planId: 'silver', planName: 'Silver', tier: 'SILVER', status: 'ACTIVE'),
      );
      final c = MembershipController(repo);
      await c.start();
      await c.choose(c.plans[0]);
      await c.choose(c.plans[1]);
      await c.choose(c.plans[3]);
      expect(repo.checkouts, isEmpty);
      await c.renew();
      expect(repo.checkouts, ['price-silver']);
    });
  });

  group('the screen', () {
    Future<_Plans> pump(
      WidgetTester tester, {
      _Plans? repo,
      MembershipAudience audience = MembershipAudience.seeker,
    }) async {
      tester.view.physicalSize = const Size(780, 4000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final plans = repo ?? _Plans();
      // The API client sits above the app, so a pushed route (the contact form) finds it.
      await tester.pumpWidget(
        Provider<ApiClient>.value(
          value: ApiClient(tokens: _NoTokens(), baseUrl: 'http://api.test/api/v1'),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(),
            home: MembershipScreen(audience: audience, repository: plans, onBack: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return plans;
    }

    testWidgets('shows the ladder\'s chips, the tagline, Your plan and a card per plan with what it includes', (
      tester,
    ) async {
      await pump(tester, audience: MembershipAudience.supplier);
      expect(find.text('Membership'), findsOneWidget);
      expect(find.byKey(const ValueKey('audience-professional')), findsOneWidget);
      expect(find.byKey(const ValueKey('audience-supplier')), findsOneWidget);
      // The row scrolls: the last ladder is off the edge until it is dragged in.
      await tester.drag(find.byKey(const ValueKey('audience-professional')), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('audience-institution')), findsOneWidget);
      expect(find.text('Showcase. Connect. Grow.'), findsOneWidget);
      expect(find.byKey(const ValueKey('membership-your-plan')), findsOneWidget);
      expect(find.text('YOUR MARKET PLACE PLAN'), findsOneWidget);
      expect(find.text('₹4,999'), findsOneWidget);
      expect(find.text('/year + GST'), findsNWidgets(2));
      expect(find.text('₹14,999'), findsOneWidget, reason: 'the compare-at price, struck through');
      expect(find.text('30 applications a month'), findsOneWidget);
      expect(find.text('Nothing here'), findsNothing, reason: 'a value the API does not show');
      expect(find.text('SERVICE TERMS'), findsOneWidget);
      expect(find.text('Custom pricing'), findsOneWidget);
      expect(find.text('Talk to us'), findsOneWidget);
      expect(find.text('YOURS'), findsOneWidget, reason: 'the free rung, with nothing held');
      expect(find.text('Choose Silver'), findsOneWidget);
      expect(find.text('Choose Gold'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a chip switches the ladder', (tester) async {
      final repo = await pump(tester);
      await tester.tap(find.byKey(const ValueKey('audience-mentor')));
      await tester.pumpAndSettle();
      expect(find.text('Guide. Influence. Lead.'), findsOneWidget);
      expect(repo.planReads, 2);
    });

    testWidgets('Choose starts the checkout and, activated on the spot, says so and marks the plan', (tester) async {
      final repo = await pump(tester);
      await tester.tap(find.byKey(const ValueKey('plan-choose-gold')));
      await tester.pumpAndSettle();
      expect(repo.checkouts, ['price-gold']);
      expect(find.text("You're on Gold."), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(const ValueKey('plan-gold')), matching: find.text('YOURS')),
        findsOneWidget,
      );
      expect(find.text('Current plan'), findsOneWidget);
      await tester.tap(find.byTooltip('Dismiss'));
      await tester.pumpAndSettle();
      expect(find.text("You're on Gold."), findsNothing);
    });

    testWidgets('a refusal shows the API\'s sentence and keeps the card as it was', (tester) async {
      final repo = await pump(tester, repo: _Plans(refusal: 'Gold would replace a plan you have already paid for.'));
      await tester.tap(find.byKey(const ValueKey('plan-choose-gold')));
      await tester.pumpAndSettle();
      expect(find.text('Gold would replace a plan you have already paid for.'), findsOneWidget);
      expect(find.text('Choose Gold'), findsOneWidget);
      expect(repo.checkouts, ['price-gold']);
    });

    testWidgets('a gateway checkout hands the payment to the website\'s plans page, never the app\'s', (tester) async {
      await pump(tester, repo: _Plans(gateway: true));
      await tester.tap(find.byKey(const ValueKey('plan-choose-silver')));
      await tester.pumpAndSettle();
      expect(launches.urls.single, endsWith('/pricing/professional'));
      expect(find.text('The payment for Silver continues on the ICR website.'), findsOneWidget);
    });

    testWidgets('a member who cannot buy here reads why, with no buttons', (tester) async {
      await pump(tester, repo: _Plans(canBuy: false, reason: 'These plans are bought by a company.'));
      expect(find.byKey(const ValueKey('membership-eligibility')), findsOneWidget);
      expect(find.text('These plans are bought by a company.'), findsOneWidget);
      expect(find.byKey(const ValueKey('membership-your-plan')), findsNothing);
      expect(find.byKey(const ValueKey('plan-choose-gold')), findsNothing);
      expect(find.text('Talk to us'), findsOneWidget, reason: 'a conversation is always open');
    });

    testWidgets('a held plan shows its end, renews at today\'s price and opens its history', (tester) async {
      final repo = await pump(
        tester,
        repo: _Plans(
          held: MySubscription(
            id: 's',
            planId: 'silver',
            planName: 'Silver',
            tier: 'SILVER',
            status: 'ACTIVE',
            currentPeriodEnd: DateTime(2027, 3, 11),
          ),
        ),
      );
      expect(find.text('Ends 11 Mar 2027'), findsOneWidget);
      expect(find.widgetWithText(PrimaryButton, 'Renew for ₹5,898.82'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('membership-renew')));
      await tester.pumpAndSettle();
      expect(repo.checkouts, ['price-silver']);
      await tester.tap(find.byKey(const ValueKey('membership-history')));
      await tester.pumpAndSettle();
      expect(find.byType(MembershipHistoryScreen), findsOneWidget);
      expect(find.text('Running · 12 Mar 2026 – 11 Mar 2027'), findsOneWidget);
      expect(find.text('Changed plan · 1 Jan 2025 – 11 Mar 2026'), findsOneWidget);
      expect(find.text('₹5,898.82'), findsOneWidget);
      expect(find.text('Free'), findsWidgets);
    });

    testWidgets('Talk to us opens the contact form, set to membership and naming the plan', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('plan-choose-enterprise')));
      await tester.pumpAndSettle();
      expect(find.byType(ContactScreen), findsOneWidget);
      expect(find.textContaining('Professional Enterprise plan'), findsWidgets);
    });

    testWidgets('a failed read says why and Try again reads again; the sample content draws without overflow', (
      tester,
    ) async {
      final repo = await pump(tester, repo: _Plans(plansError: 'Plans are down'));
      expect(find.text('Plans are down'), findsOneWidget);
      repo.plansError = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Choose Gold'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: MembershipScreen(
            repository: DemoMembershipRepository(clock: () => DateTime(2026, 10, 27)),
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Silver'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}
