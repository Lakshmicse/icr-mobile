import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/features/mentor_desk/offerings/offerings_files.dart';
import 'package:icr_mobile/features/mentor_desk/offerings/offerings_models.dart';
import 'package:icr_mobile/features/mentor_desk/offerings/offerings_repository.dart';
import 'package:icr_mobile/features/mentor_desk/offerings/offerings_rules.dart';
import 'package:icr_mobile/features/mentorship_my/mentoring_clock.dart';

import 'helpers/fonts.dart';
import 'mentor_offerings_fakes.dart';
import 'mentoring_fakes.dart';

/// The Offerings panel's own tabs (owner, 7 Nov 2026): 1:1 mentoring, Group mentoring, Resources.
Future<void> openOfferingsTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);
  setUp(() => mentoringNow = () => offeringsNow);
  tearDown(() => mentoringNow = DateTime.now);

  group('the rules, as the API holds them', () {
    test('rupees as typed become paisa, and only a plain amount does', () {
      expect(paisaOf('1499'), 149900);
      expect(paisaOf('1,499'), 149900);
      expect(paisaOf('₹499.50'), 49950);
      expect(paisaOf(' 12 '), 1200);
      expect(paisaOf('abc'), isNull);
      expect(paisaOf(''), isNull);
      expect(paisaOf('12.345'), isNull);
      expect(paisaOf('-5'), isNull);
      expect(rupeesOf(149900), '1499');
      expect(rupeesOf(null), '');
    });

    test(
      'a service is free, or priced up to ₹50,000 (no floor of the app\'s own); its strikethrough is higher and at most 50% off',
      () {
        String? p(String price, {bool free = false, String compare = ''}) =>
            servicePriceProblem(free: free, price: price, compareAt: compare);
        expect(p('', free: true), isNull);
        expect(p(''), 'Enter the price in rupees, or turn on Free.');
        // The ₹499 floor is the API's rule, not the app's (owner, 7 Nov 2026).
        expect(p('100'), isNull);
        expect(p('498.99'), isNull);
        expect(p('499'), isNull);
        expect(p('50000'), isNull);
        expect(p('50001'), 'Prices go up to ₹50,000.');
        expect(p('499', compare: '499'), 'The compare-at price must be higher than the price.');
        expect(p('499', compare: '300'), 'The compare-at price must be higher than the price.');
        expect(p('499', compare: '999'), startsWith('Discounts are capped at 50%'));
        expect(p('499', compare: '998'), isNull, reason: 'half, to the paisa, is allowed');
        expect(p('499', compare: 'lots'), 'Enter the strikethrough price in rupees, or leave it empty.');
      },
    );

    test('lengths, seats and titles carry the DTO\'s bounds', () {
      expect(minutesProblem('14'), 'A session runs 15 to 480 minutes.');
      expect(minutesProblem('15'), isNull);
      expect(minutesProblem('480'), isNull);
      expect(minutesProblem('481', what: 'A 1:1 call'), 'A 1:1 call runs 15 to 480 minutes.');
      expect(minutesProblem(''), 'A session runs 15 to 480 minutes.');
      expect(seatsProblem('1'), 'Enter seats as a number from 2 to 500.');
      expect(seatsProblem('500'), isNull);
      expect(seatsProblem('501'), 'Enter seats as a number from 2 to 500.');
      expect(serviceTitleProblem('abc'), 'Enter a title of at least 4 characters.');
      expect(serviceTitleProblem('abcd'), isNull);
      expect(serviceTitleProblem('x' * 121), 'Keep the title under 120 characters.');
      expect(blurbProblem('x' * 601, max: maxServiceBlurb), 'Keep the description under 600 characters.');
      expect(blurbProblem('x' * 600, max: maxServiceBlurb), isNull);
    });

    test('an ongoing plan is free or ₹500 to ₹5,00,000 a term', () {
      String? p(String price, {bool free = false, String compare = ''}) =>
          recurringPriceProblem(free: free, price: price, compareAt: compare);
      expect(p('', free: true), isNull);
      expect(p('499'), 'An ongoing plan is either free, or priced between ₹500 and ₹5,00,000 per term.');
      expect(p('500'), isNull);
      expect(p('500000'), isNull);
      expect(p('500001'), 'An ongoing plan is either free, or priced between ₹500 and ₹5,00,000 per term.');
      expect(p('1000', compare: '1000'), 'The strikethrough price must be higher than the price you charge.');
      expect(p('1000', compare: '1500'), isNull, reason: 'an ongoing plan has no discount cap');
    });

    test(
      'a programme is free or priced (no floor of the app\'s own), and its strikethrough follows a session\'s rule',
      () {
        String? p(String price, {bool free = false, String compare = ''}) =>
            programmePriceProblem(free: free, price: price, compareAt: compare);
        expect(p('498'), isNull, reason: 'the ₹499 floor is the API\'s rule (owner, 7 Nov 2026)');
        expect(p('499'), isNull);
        expect(p('5999'), isNull);
        expect(p('6000', compare: '6000'), 'The strikethrough price must be higher than the price you charge.');
        expect(p('1000', compare: '2500'), 'A discount can be at most 50% off the strikethrough price.');
        expect(p('1000', compare: '2000'), isNull);
      },
    );

    test('a syllabus is 2 to 24 sessions, each with a title and sane numbers', () {
      expect(modulesProblem([ModuleDraft(title: 'One')]), 'A structured programme runs between 2 and 24 sessions.');
      expect(
        modulesProblem([ModuleDraft(title: 'One'), ModuleDraft(title: 'ab')]),
        'Session 2: enter a title of at least 3 characters.',
      );
      expect(
        modulesProblem([ModuleDraft(title: 'One'), ModuleDraft(title: 'Two', minutes: '5')]),
        'Session 2: 15 to 480 minutes.',
      );
      expect(
        modulesProblem([ModuleDraft(title: 'One'), ModuleDraft(title: 'Two', outline: 'x' * 601)]),
        contains('outline'),
      );
      expect(modulesProblem([ModuleDraft(title: 'One'), ModuleDraft(title: 'Two', minutes: '60')]), isNull);
      expect(
        modulesProblem([for (var i = 0; i < 25; i++) ModuleDraft(title: 'Session $i')]),
        contains('between 2 and 24'),
      );
      expect(inclusionsProblem(List.filled(9, 'x')), 'List up to 8 things the plan includes.');
      expect(inclusionsProblem(['x' * 81]), 'Keep each line under 80 characters.');
      expect(inclusionsProblem(['one', '', '  ', 'two']), isNull, reason: 'blank lines are dropped');
      expect(planTitleProblem('ab'), 'Enter a title of at least 3 characters.');
      expect(planTitleProblem('x' * 81), 'Keep the title under 80 characters.');
    });

    test('a group session needs a title, a place, days that do not overlap, seats, and seats for a price', () {
      expect(groupTitleProblem('abcd'), 'Enter a title of at least 5 characters.');
      expect(groupTitleProblem('abcde'), isNull);
      expect(groupPlaceProblem(inPerson: true, location: ' ', link: ''), 'Add the venue where people will meet.');
      expect(groupPlaceProblem(inPerson: true, location: 'Bengaluru', link: ''), isNull);
      expect(groupPlaceProblem(inPerson: false, location: '', link: ''), 'Add the joining link people will use.');
      expect(groupPlaceProblem(inPerson: false, location: '', link: '', standingLink: true), isNull);
      expect(
        groupPlaceProblem(inPerson: false, location: '', link: 'not a link'),
        startsWith('Enter a full web address'),
      );
      expect(groupPlaceProblem(inPerson: false, location: '', link: 'meet.google.com/abc'), isNull);

      final now = DateTime(2026, 10, 26, 10);
      expect(daysProblem([], now), 'Add at least one day to the session.');
      expect(daysProblem([(DateTime(2026, 10, 26, 9), 60)], now), 'Select a time in the future.');
      expect(daysProblem([(DateTime(2026, 10, 27, 9), 10)], now), 'A day runs 15 to 480 minutes.');
      expect(
        daysProblem([(DateTime(2026, 10, 27, 9), 60), (DateTime(2026, 10, 27, 9, 30), 60)], now),
        'Days must not overlap.',
      );
      expect(
        daysProblem([(DateTime(2026, 10, 27, 9), 60), (DateTime(2026, 10, 27, 10), 60)], now),
        isNull,
        reason: 'back to back is fine',
      );
      expect(
        daysProblem([for (var i = 0; i < 11; i++) (DateTime(2026, 11, 1 + i, 9), 60)], now),
        startsWith('A session spans at most 10 days'),
      );

      expect(capacityProblem(''), isNull, reason: 'empty is no limit');
      expect(capacityProblem('1'), startsWith('Enter seats as a number from 2 to 50'));
      expect(capacityProblem('51'), startsWith('Enter seats as a number from 2 to 50'));
      expect(capacityProblem('50'), isNull);
      expect(seatPriceProblem(price: '', capacity: ''), isNull);
      expect(seatPriceProblem(price: '100', capacity: '25'), isNull, reason: 'no price floor');
      expect(seatPriceProblem(price: '100', capacity: ''), 'A paid session needs a number of seats.');
      expect(seatPriceProblem(price: '499', capacity: ''), 'A paid session needs a number of seats.');
      expect(seatPriceProblem(price: '499', capacity: '25'), isNull);
      expect(seatPriceProblem(price: '50001', capacity: '25'), 'Prices go up to ₹50,000.');
      expect(cancelReasonProblem('ab'), 'Enter at least 3 characters.');
      expect(cancelReasonProblem('abc'), isNull);
    });

    test('an agenda is plain paragraphs out and escaped HTML in, and back again', () {
      expect(agendaHtmlOf('One\n\nTwo & <three>\nline'), '<p>One</p><p>Two &amp; &lt;three&gt;<br>line</p>');
      expect(
        agendaTextOf('<p>Bring a real case.</p><p>We start with scope.</p>'),
        'Bring a real case.\n\nWe start with scope.',
      );
      expect(agendaTextOf(null), '');
      expect(agendaTextOf(agendaHtmlOf('A & B\n\nC')), 'A & B\n\nC');
    });

    test('a file is checked as the API checks it before it is sent', () {
      expect(uploadProblem(pdfFile(), imageOnly: false), isNull);
      expect(uploadProblem(pdfFile(name: 'a.PNG'), imageOnly: true), isNull);
      expect(uploadProblem(pdfFile(name: 'a.pdf'), imageOnly: true), 'A cover is a PNG, JPG or WebP image.');
      expect(
        uploadProblem(pdfFile(name: 'a.docx'), imageOnly: false),
        'A resource is a PDF or an image (PNG, JPG, WebP).',
      );
      expect(uploadProblem(pdfFile(name: 'noext'), imageOnly: false), isNotNull);
      expect(uploadProblem(pdfFile(bytes: maxUploadBytes + 1), imageOnly: false), 'The file is larger than 10 MB.');
      expect(mimeOfName('a.JPG'), 'image/jpeg');
      expect(mimeOfName('a.zip'), isNull);
    });
  });

  group('what the API sends', () {
    test('the storefront reads the gates and every service, as the real answer is shaped', () async {
      final w = OfferingsWorld(
        services: [
          serviceJson(
            'svc-kit',
            type: 'RESOURCE',
            title: 'FM interview question bank',
            price: 49900,
            compareAt: 99900,
            duration: null,
            fileName: 'bank',
            fileSize: 705,
            sales: 5,
            rating: 4.5,
            ratingCount: 2,
          ),
          serviceJson('svc-draft', title: 'Salary negotiation clinic', active: false),
          serviceJson('svc-query', type: 'QUERY', title: 'Old consultation', active: false),
        ],
      );
      final repo = OfferingsRepository(api: w.api().client());
      final s = await repo.storefront();
      expect(s.gates.live, isTrue);
      expect(s.gates.optedIn, isTrue);
      expect(s.gates.termsCurrent, isTrue);
      expect(s.gates.termsCurrentVersion, '2026.1');
      expect(s.gates.blockedReason, isNull);
      final kit = s.services.first;
      expect(kit.kind, ServiceKind.resource);
      expect(kit.pricePaisa, 49900);
      expect(kit.compareAtPaisa, 99900);
      expect(kit.fileName, 'bank');
      expect(kit.fileSize, 705);
      expect(kit.salesCount, 5);
      expect(kit.rating, 4.5);
      expect(kit.isBestSeller, isTrue);
      expect(kit.blocker, isNull);
      expect(s.services[1].active, isFalse);
      expect(s.services[2].kind.retired, isTrue);
      expect(s.services[2].blocker, 'Written consultations are no longer sold.');
    });

    test(
      'a closed storefront carries the API\'s own sentence, and the terms are the blocker only when it says so',
      () async {
        final w = OfferingsWorld(optedIn: false, accepted: null);
        final s = await OfferingsRepository(api: w.api().client()).storefront();
        expect(s.gates.live, isFalse);
        expect(s.gates.blockedReason, 'Accept the seller terms to open your storefront.');
        expect(s.gates.termsAreTheBlocker, isTrue);
        final suspended = await OfferingsRepository(api: OfferingsWorld(suspended: true).api().client()).storefront();
        expect(suspended.gates.blockedReason, 'Your storefront is suspended. Contact the ICR team.');
        expect(suspended.gates.termsAreTheBlocker, isFalse);
      },
    );

    test('a resource with no file cannot be live, in the API\'s words', () {
      final s = OfferedService.fromJson(serviceJson('x', type: 'RESOURCE', duration: null, active: false));
      expect(s.blocker, 'Upload the file before publishing a resource.');
      final live = OfferedService.fromJson(serviceJson('x', type: 'RESOURCE', duration: null, fileName: 'f'));
      expect(live.blocker, isNull);
    });

    test('a service goes back whole when it is paused: the API takes the full shape', () {
      final s = OfferedService.fromJson(
        serviceJson('x', title: 'Strategy', price: 149900, compareAt: 199900, duration: 45, blurb: 'Plan'),
      );
      expect(s.body(active: false), {
        'type': 'ONE_ON_ONE',
        'title': 'Strategy',
        'blurb': 'Plan',
        'pricePaisa': 149900,
        'compareAtPaisa': 199900,
        'durationMin': 45,
        'active': false,
      });
    });

    test('plans: an ongoing plan and a programme with its syllabus', () async {
      final w = OfferingsWorld(
        plans: [
          planJson('p1'),
          planJson(
            'p2',
            kind: 'CURRICULUM',
            title: 'Site to portfolio',
            price: 599900,
            billing: 3,
            access: 3,
            sessionMin: 60,
            inclusions: ['Notes After Every Session'],
            modules: [
              moduleJson(1, 'Where you are', outline: 'Scope and gaps'),
              moduleJson(2, 'The business case'),
            ],
          ),
        ],
      );
      final plans = await OfferingsRepository(api: w.api().client()).plans();
      expect(plans[0].programme, isFalse);
      expect(plans[0].sessionsPerMonth, 2);
      expect(plans[0].billingPeriodMonths, 1);
      expect(plans[1].programme, isTrue);
      expect(plans[1].totalSessions, 2);
      expect(plans[1].accessMonths, 3);
      expect(plans[1].steps.map((s) => s.title), ['Where you are', 'The business case']);
      expect(plans[1].steps.first.outline, 'Scope and gaps');
      expect(plans[1].inclusions, ['Notes After Every Session']);
    });

    test('a hosted session: days, seats, price, and a roster with each person\'s question', () async {
      final w = OfferingsWorld(
        sessions: [
          hostedJson(
            'grp-paid',
            taken: 2,
            waiting: 1,
            price: 29900,
            attendees: [
              attendeeJson('a0', 'Meera', 'Nair', question: 'How do I present a case?'),
              attendeeJson('a1', 'Tanvi', 'Joshi', status: 'ATTENDED'),
              attendeeJson('a2', 'Sana', 'Qureshi', status: 'WAITLISTED'),
            ],
          ),
        ],
      );
      final repo = OfferingsRepository(api: w.api().client());
      final list = await repo.sessions();
      expect(
        list.single.roster,
        isNotNull,
        reason: 'the mock list carries the roster; the real list has none and the sheet reads the detail',
      );
      final d = await repo.session('grp-paid');
      expect(d.title, 'From site to portfolio: an open clinic');
      expect(d.paid, isTrue);
      expect(d.pricePaisa, 29900);
      expect(d.seatsTaken, 2);
      expect(d.waitlistCount, 1);
      expect(d.days.single.scheduled, isTrue);
      expect(d.roster!.map((r) => r.name), ['Meera Nair', 'Tanvi Joshi', 'Sana Qureshi']);
      expect(d.roster![0].question, 'How do I present a case?');
      expect(d.roster![0].holdsSeat, isTrue);
      expect(d.roster![1].statusLabel, 'Attended');
      expect(d.roster![2].holdsSeat, isFalse);
      expect(d.startedBy(offeringsNow), isFalse);
      expect(d.startedBy(offeringsNow.add(const Duration(days: 7))), isTrue);
    });

    test('an upload goes to the purpose it is for, and the stored name is what a resource saves', () async {
      final w = OfferingsWorld();
      final api = w.api();
      final stored = await OfferingsRepository(api: api.client()).upload(pdfFile(), purpose: 'mentor-resource');
      expect(stored.url, '/uploads/mentor-resource-stored.pdf');
      expect(stored.uploadId, 'mentor-resource-stored.pdf');
      expect(stored.name, 'probe.pdf');
      expect(api.queryOf('POST /uploads'), {'purpose': 'mentor-resource'});
    });

    test('a refusal arrives as the API\'s own sentence', () async {
      final w = OfferingsWorld();
      final api = w.api(extra: {'POST /mentor-services/mine': (_) => refuse('Priced services start at ₹499.')});
      await expectLater(
        OfferingsRepository(api: api.client()).createService({'type': 'ONE_ON_ONE', 'title': 'x', 'pricePaisa': 100}),
        throwsA(predicate((e) => e.toString() == 'Priced services start at ₹499.')),
      );
    });
  });

  group('the storefront and its gates', () {
    testWidgets('a live storefront draws no storefront card: the three tabs stand alone (owner, 7 Nov 2026)', (
      tester,
    ) async {
      await pumpOfferings(tester, OfferingsWorld());
      expect(find.text('Storefront'), findsNothing);
      expect(find.text('Not suspended'), findsNothing);
      expect(find.text('Seller Terms 2026.1 accepted'), findsNothing);
      expect(find.byKey(const ValueKey('accept-terms')), findsNothing);
      expect(find.byKey(const ValueKey('gate-reason')), findsNothing);
      for (final tab in ['1:1 Mentoring', 'Group Mentoring', 'Resources']) {
        expect(find.text(tab), findsWidgets, reason: tab);
      }
    });

    testWidgets('when the seller terms are the one thing missing, the API\'s sentence shows and they can be accepted', (
      tester,
    ) async {
      final w = OfferingsWorld(optedIn: false, accepted: null, services: []);
      final changes = <String>[];
      final (api, rec) = await pumpOfferings(tester, w, changes: changes);
      // No Storefront card, pill or checklist (owner, 9 Nov 2026): the API's sentence and the terms alone.
      expect(find.text('Not open'), findsNothing);
      expect(find.text('Storefront'), findsNothing);
      expect(find.text('Accept the seller terms to open your storefront.'), findsOneWidget);
      expect(find.text('Accept Seller Terms (2026.1)'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('accept-terms')));
      await tester.pumpAndSettle();
      expect(find.text('Seller Terms 2026.1'), findsOneWidget);
      // The accept button waits for the tick.
      await tester.tap(inDialog('Accept and Open'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(
        api.count('POST /mentor-services/mine/terms'),
        0,
        reason: 'nothing is sent until the terms are ticked as read',
      );
      await tester.tap(find.byKey(const ValueKey('read-terms')));
      await tester.pump();
      expect(rec.sites, ['/terms']);
      await tester.tap(find.byKey(const ValueKey('terms-read')));
      await tester.pump();
      await tester.tap(inDialog('Accept and Open'));
      await settle(tester);
      expect(api.bodyOf('POST /mentor-services/mine/terms'), {'version': '2026.1'});
      expect(find.text('Your storefront is open.'), findsOneWidget);
      expect(find.byKey(const ValueKey('accept-terms')), findsNothing);
      expect(find.text('Storefront'), findsNothing, reason: 'the card goes once the storefront is live');
      expect(changes, ['changed'], reason: 'the desk is told so its overview can read again');
    });

    testWidgets('Not now sends nothing', (tester) async {
      final (api, _) = await pumpOfferings(tester, OfferingsWorld(optedIn: false, accepted: null));
      await tester.tap(find.byKey(const ValueKey('accept-terms')));
      await tester.pumpAndSettle();
      await tester.tap(inDialog('Not Now'));
      await tester.pumpAndSettle();
      expect(api.count('POST /mentor-services/mine/terms'), 0);
    });

    testWidgets('a refused acceptance shows the API\'s sentence and leaves the storefront closed', (tester) async {
      final (api, _) = await pumpOfferings(
        tester,
        OfferingsWorld(optedIn: false, accepted: null),
        extra: {
          'POST /mentor-services/mine/terms': (_) =>
              refuse('Only listed (approved) mentors can sell services.', status: 403),
        },
      );
      await tester.tap(find.byKey(const ValueKey('accept-terms')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('terms-read')));
      await tester.pump();
      await tester.tap(inDialog('Accept and Open'));
      await settle(tester);
      expect(api.count('POST /mentor-services/mine/terms'), 1);
      expect(find.text('Only listed (approved) mentors can sell services.'), findsOneWidget);
      expect(find.text('Not open'), findsNothing);
    });

    testWidgets('a suspended storefront says so and offers no way round it', (tester) async {
      await pumpOfferings(tester, OfferingsWorld(suspended: true));
      expect(find.text('Your storefront is suspended. Contact the ICR team.'), findsOneWidget);
      expect(find.byKey(const ValueKey('accept-terms')), findsNothing);
    });

    testWidgets('while the storefront is closed, adding a service or a plan says why without asking the API', (
      tester,
    ) async {
      final (api, _) = await pumpOfferings(tester, OfferingsWorld(optedIn: false, accepted: null, services: []));
      await tapKey(tester, 'add-mentoring');
      expect(find.text('Accept the seller terms to open your storefront.'), findsWidgets);
      expect(find.text('New 1:1 Mentoring'), findsNothing, reason: 'no composer opens');
      await tapKey(tester, 'add-plan');
      expect(find.text('New Ongoing Plan'), findsNothing);
      await openOfferingsTab(tester, 'Resources');
      await tapKey(tester, 'add-resource');
      expect(api.count('POST /mentor-services/mine'), 0);
      expect(api.count('POST /mentor-plans'), 0);
      // A group session is hosted by approved mentors, free or not: its form opens.
      await openOfferingsTab(tester, 'Group Mentoring');
      await tapKey(tester, 'add-group');
      expect(find.text('Host a Group Session'), findsWidgets);
      expect(find.byKey(const ValueKey('group-title')), findsOneWidget);
    });

    testWidgets('each section says what it holds and how many, with the website\'s words and buttons', (tester) async {
      final (_, _) = await pumpOfferings(tester, OfferingsWorld(services: [], plans: [], sessions: []));
      expect(find.text('1:1 Mentoring'), findsWidgets);
      expect(find.text('Single sessions and programmes, one mentee at a time.'), findsOneWidget);
      expect(find.text('Add 1:1 Mentoring'), findsOneWidget);
      expect(
        find.text('No 1:1 mentoring offerings yet. Offer a single session or a programme of up to 24 sessions.'),
        findsOneWidget,
      );
      expect(find.text('Ongoing Plans'), findsOneWidget);
      expect(find.text('A set number of sessions a month for a term, booked as needed.'), findsOneWidget);
      expect(find.text('Create a Plan'), findsOneWidget);
      expect(find.text('No Ongoing Plans Yet'), findsOneWidget);
      expect(
        find.text('For example, offer 2 sessions a month for 3 months. Plans do not count toward your listing limit.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('add-mentoring-count')), findsOneWidget);
      await openOfferingsTab(tester, 'Resources');
      expect(find.text('Guides and templates mentees download after paying.'), findsOneWidget);
      expect(find.text('Add Resource'), findsOneWidget);
      expect(find.text('No resources yet. Add a downloadable guide or template, delivered on payment.'), findsOneWidget);
      await openOfferingsTab(tester, 'Group Mentoring');
      expect(find.text('Clinics and multi-day series you host for several mentees at once.'), findsOneWidget);
      expect(find.text('No group sessions yet. Host a single clinic or a multi-day series, free or paid.'), findsOneWidget);
    });

    testWidgets('a storefront that fails to load says why and Try again asks again, while the rest still shows', (
      tester,
    ) async {
      var fail = true;
      final w = OfferingsWorld();
      final (api, _) = await pumpOfferings(
        tester,
        w,
        extra: {
          'GET /mentor-services/mine': (_) =>
              fail ? refuse('Create your mentor profile first.', status: 404) : w.storefront,
        },
      );
      expect(find.text('Unable to Load Your Storefront'), findsOneWidget);
      expect(find.text('Create your mentor profile first.'), findsOneWidget);
      expect(find.text('Ongoing Plans'), findsOneWidget, reason: 'plans and sessions are their own reads');
      expect(find.text('Monthly leadership coaching'), findsOneWidget);
      fail = false;
      await tapText(tester, 'Try Again');
      expect(find.text('Unable to Load Your Storefront'), findsNothing);
      expect(find.text('Career clarity call'), findsOneWidget);
      expect(api.count('GET /mentor-services/mine'), 2);
    });

    testWidgets('pulling down reads all three lists again', (tester) async {
      final (api, _) = await pumpOfferings(tester, OfferingsWorld(), height: 3000);
      await tester.fling(find.byType(ListView).first, const Offset(0, 400), 1000);
      await settle(tester);
      expect(api.count('GET /mentor-services/mine'), 2);
      expect(api.count('GET /mentor-plans/mine'), 2);
      expect(api.count('GET /mentorship/group-sessions'), 2);
    });
  });

  group('services', () {
    testWidgets('the list: 1:1 sessions, resources and older listings, each with its state', (tester) async {
      final w = OfferingsWorld(
        services: [
          serviceJson('svc-discovery'),
          serviceJson(
            'svc-strategy',
            title: 'Strategy session',
            price: 149900,
            compareAt: 199900,
            duration: 45,
            sales: 4,
            rating: 4.7,
            ratingCount: 3,
          ),
          serviceJson(
            'svc-resource',
            type: 'RESOURCE',
            title: 'Question bank',
            price: 49900,
            duration: null,
            fileName: 'bank.pdf',
            fileSize: 2048,
          ),
          serviceJson(
            'svc-seat',
            type: 'GROUP_SESSION',
            title: 'An older seat',
            price: 29900,
            duration: 60,
            seats: 12,
            active: false,
          ),
          serviceJson('svc-query', type: 'QUERY', title: 'Old consultation', active: false),
        ],
      );
      await pumpOfferings(tester, w);
      expect(find.text('1:1 Mentoring'), findsNWidgets(2), reason: 'the tab and the section');
      expect(find.text('Career clarity call'), findsOneWidget);
      expect(find.text('1:1 Session · Free'), findsOneWidget);
      expect(find.text('1:1 Session · ₹1,499 (was ₹1,999)'), findsOneWidget);
      expect(find.text('4 sales · 4.7 from 3 reviews'), findsOneWidget);
      expect(find.text('45 min'), findsOneWidget);
      await openOfferingsTab(tester, 'Resources');
      expect(find.text('Resource · ₹499'), findsOneWidget);
      expect(find.text('bank.pdf'), findsOneWidget);
      expect(find.text('Older Listings'), findsOneWidget);
      expect(find.text('An older seat'), findsOneWidget);
      expect(find.text('Group Seat · ₹299'), findsOneWidget);
      expect(find.text('1 hr · 12 seats'), findsOneWidget);
      expect(find.text('Written consultations are no longer sold.'), findsOneWidget);
      expect(find.text('Paused'), findsNWidgets(2));
      expect(inRow('service-svc-query', 'Resume'), findsNothing, reason: 'a retired type cannot be switched back on');
      expect(inRow('service-svc-query', 'Delete'), findsOneWidget);
      await openOfferingsTab(tester, 'Group Mentoring');
      expect(find.byKey(const ValueKey('add-group')), findsOneWidget);
    });

    testWidgets(
      'a resource needs its file: it is picked, checked, uploaded to mentor-resource and saved by its stored name',
      (tester) async {
        PickedUpload? next = pdfFile(name: 'notes.docx');
        final (api, _) = await pumpOfferings(
          tester,
          OfferingsWorld(services: []),
          pickFile: ({required bool imageOnly}) async => next,
        );
        await openOfferingsTab(tester, 'Resources');
        await tapKey(tester, 'add-resource');
        await typeKey(tester, 'offering-title', 'Interview question bank');
        await tapKey(tester, 'offering-free');
        await submit(tester, 'Add');
        expect(find.text('Upload the file before publishing a resource.'), findsOneWidget);
        expect(api.count('POST /mentor-services/mine'), 0);

        // A file the API would refuse never leaves the phone.
        await tapKey(tester, 'offering-file');
        expect(find.text('A resource is a PDF or an image (PNG, JPG, WebP).'), findsOneWidget);
        expect(api.count('POST /uploads'), 0);

        next = pdfFile(name: 'bank.pdf', bytes: 2048);
        await tapKey(tester, 'offering-file');
        expect(api.count('POST /uploads'), 1);
        expect(api.queryOf('POST /uploads'), {'purpose': 'mentor-resource'});
        expect(find.byKey(const ValueKey('offering-file-name')), findsOneWidget);
        expect(find.text('probe.pdf · 1 KB'), findsOneWidget);
        await submit(tester, 'Add');
        final body = api.bodyOf('POST /mentor-services/mine') as Map;
        expect(body['type'], 'RESOURCE');
        expect(body['uploadId'], 'mentor-resource-stored.pdf');
        expect(body['fileName'], 'probe.pdf');
        expect(body['fileSize'], 69);
        expect(body.containsKey('durationMin'), isFalse);
        expect(find.text('Resource · Free'), findsOneWidget);
      },
    );

    // "A resource saved paused needs no file yet" went with the form's Live switch (owner, 7 Nov 2026): a new
    // listing goes live, and is paused from its row once posted.

    testWidgets('a refused upload says why and the form keeps going', (tester) async {
      final (api, _) = await pumpOfferings(
        tester,
        OfferingsWorld(services: []),
        extra: {'POST /uploads': (_) => refuse('application/zip is not an accepted file type for this upload.')},
      );
      await openOfferingsTab(tester, 'Resources');
      await tapKey(tester, 'add-resource');
      await tapKey(tester, 'offering-file');
      expect(api.count('POST /uploads'), 1);
      expect(find.text('application/zip is not an accepted file type for this upload.'), findsOneWidget);
      expect(find.byKey(const ValueKey('offering-file-name')), findsNothing);
    });

    testWidgets('Add 1:1 Mentoring opens the composer; what it saves joins the list', (tester) async {
      final changes = <String>[];
      final (api, _) = await pumpOfferings(tester, OfferingsWorld(services: []), changes: changes);
      await tapKey(tester, 'add-mentoring');
      expect(find.text('New 1:1 Mentoring'), findsOneWidget);
      await typeKey(tester, 'composer-title', 'Career clarity call');
      await typeKey(tester, 'composer-price', '1499');
      // The fake mentor meets in person too, and every format is picked: the venue is asked (as on the website).
      await typeKey(tester, 'composer-venue', 'ICR Bengaluru, 4th floor');
      await tapKey(tester, 'composer-save');
      expect((api.bodyOf('POST /mentor-services/mine') as Map)['type'], 'ONE_ON_ONE');
      expect(find.text('New 1:1 Mentoring'), findsNothing);
      expect(find.text('Added.'), findsOneWidget);
      expect(find.text('Career clarity call'), findsOneWidget);
      expect(changes, ['changed']);
    });

    testWidgets('Edit on a 1:1 session opens it in the composer, held to one session', (tester) async {
      final (api, _) = await pumpOfferings(tester, OfferingsWorld());
      await tapIn(tester, 'service-svc-strategy', 'Edit');
      expect(find.text('Edit 1:1 Mentoring'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const ValueKey('composer-title'))).controller!.text, 'Strategy session');
      await typeKey(tester, 'composer-title', 'Facilities strategy session');
      if (find.byKey(const ValueKey('composer-venue')).evaluate().isNotEmpty) {
        await typeKey(tester, 'composer-venue', 'ICR Bengaluru, 4th floor');
      }
      await tapKey(tester, 'composer-save');
      expect((api.bodyOf('PATCH /mentor-services/mine/svc-strategy') as Map)['title'], 'Facilities strategy session');
      expect(find.text('Saved.'), findsOneWidget);
    });

    testWidgets('pausing sends the whole row back with only active changed, and resuming puts it back', (tester) async {
      final (api, _) = await pumpOfferings(tester, OfferingsWorld());
      expect(inRow('service-svc-strategy', 'Pause'), findsOneWidget);
      await tapIn(tester, 'service-svc-strategy', 'Pause');
      expect(api.bodyOf('PATCH /mentor-services/mine/svc-strategy'), {
        'type': 'ONE_ON_ONE',
        'title': 'Strategy session',
        'blurb': 'A call to map where you are.',
        'pricePaisa': 149900,
        'compareAtPaisa': 199900,
        'durationMin': 45,
        'active': false,
      });
      expect(find.text('Paused. Members no longer see it.'), findsOneWidget);
      expect(inRow('service-svc-strategy', 'Resume'), findsOneWidget);
      await tapIn(tester, 'service-svc-strategy', 'Resume');
      expect((api.bodyOf('PATCH /mentor-services/mine/svc-strategy') as Map)['active'], isTrue);
      expect(find.text('Live on your storefront.'), findsOneWidget);
      expect(inRow('service-svc-strategy', 'Pause'), findsOneWidget);
    });

    testWidgets('a refused pause says why and leaves the row as it was', (tester) async {
      final (_, _) = await pumpOfferings(
        tester,
        OfferingsWorld(),
        extra: {'PATCH /mentor-services/mine/svc-strategy': (_) => refuse('Service not found', status: 404)},
      );
      await tapIn(tester, 'service-svc-strategy', 'Pause');
      expect(find.text('Service not found'), findsOneWidget);
      expect(inRow('service-svc-strategy', 'Pause'), findsOneWidget);
    });

    testWidgets('resuming a resource the API will not publish without its file opens the form to choose the file', (
      tester,
    ) async {
      final w = OfferingsWorld(
        services: [
          serviceJson(
            'svc-resource',
            type: 'RESOURCE',
            title: 'Question bank',
            price: 49900,
            duration: null,
            fileName: 'bank.pdf',
            fileSize: 2048,
            active: false,
          ),
        ],
      );
      final (api, _) = await pumpOfferings(
        tester,
        w,
        extra: {
          'PATCH /mentor-services/mine/svc-resource': (_) => refuse('Upload the file before publishing a resource.'),
        },
      );
      await openOfferingsTab(tester, 'Resources');
      await tapIn(tester, 'service-svc-resource', 'Resume');
      expect(api.count('PATCH /mentor-services/mine/svc-resource'), 1);
      expect(find.text('Edit Resource'), findsOneWidget, reason: 'the form opens so the file can be chosen again');
      expect(find.text('Upload the file before publishing a resource.'), findsWidgets);
    });

    testWidgets('deleting asks first; keeping it sends nothing, deleting takes it off', (tester) async {
      final (api, _) = await pumpOfferings(tester, OfferingsWorld());
      await tapIn(tester, 'service-svc-discovery', 'Delete');
      expect(find.text('Delete "Career clarity call"?'), findsOneWidget);
      await tester.tap(inDialog('Keep It'));
      await tester.pumpAndSettle();
      expect(api.count('DELETE /mentor-services/mine/svc-discovery'), 0);
      await tapIn(tester, 'service-svc-discovery', 'Delete');
      await tester.tap(inDialog('Delete'));
      await settle(tester);
      expect(api.count('DELETE /mentor-services/mine/svc-discovery'), 1);
      expect(find.text('Deleted.'), findsOneWidget);
      expect(find.text('Career clarity call'), findsNothing);
    });

    testWidgets('an older group seat keeps its seats field and cannot be created new', (tester) async {
      final w = OfferingsWorld(
        services: [
          serviceJson('svc-seat', type: 'GROUP_SESSION', title: 'An older seat', price: 59900, duration: 60, seats: 12),
        ],
      );
      final (api, _) = await pumpOfferings(tester, w);
      await openOfferingsTab(tester, 'Resources');
      await tapIn(tester, 'service-svc-seat', 'Edit');
      expect(find.text('Edit Group Seat'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const ValueKey('offering-seats'))).controller!.text, '12');
      await typeKey(tester, 'offering-seats', '1');
      await submit(tester, 'Save');
      expect(find.text('Enter seats as a number from 2 to 500.'), findsOneWidget);
      await typeKey(tester, 'offering-seats', '20');
      await submit(tester, 'Save');
      final body = api.bodyOf('PATCH /mentor-services/mine/svc-seat') as Map;
      expect(body['seats'], 20);
      expect(body['durationMin'], 60);
      expect(body.containsKey('coverUrl'), isFalse, reason: 'a seat\'s cover is the session\'s own');
      expect(find.byKey(const ValueKey('add-seat')), findsNothing);
    });
  });
}
