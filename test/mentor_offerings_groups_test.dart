import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/features/mentorship_my/mentoring_clock.dart';

import 'helpers/fonts.dart';
import 'mentor_offerings_fakes.dart';
import 'mentoring_fakes.dart';

/// The week after the fixtures' sessions: their first day has started.
final _later = offeringsNow.add(const Duration(days: 7));

Map<String, Object?> _programme({String id = 'plan-programme', bool active = true}) => planJson(
  id,
  kind: 'CURRICULUM',
  title: 'Site to portfolio: a 3-session programme',
  blurb: 'A fixed run for the jump from a site to a portfolio.',
  price: 599900,
  compareAt: 899900,
  billing: 3,
  access: 3,
  sessionMin: 60,
  inclusions: ['Notes After Every Session'],
  modules: [
    moduleJson(1, 'Where you are', outline: 'Scope and gaps'),
    moduleJson(2, 'Vendor and SLA governance'),
    moduleJson(3, 'The portfolio business case', minutes: 90),
  ],
  active: active,
);

/// Opens the date and time pickers on their defaults (tomorrow, the same hour) and accepts them.
Future<void> acceptPickers(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

/// The Offerings panel's own tabs (owner, 7 Nov 2026): 1:1 mentoring, Group mentoring, Resources.
Future<void> openOfferingsTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);
  setUp(() => mentoringNow = () => offeringsNow);
  tearDown(() => mentoringNow = DateTime.now);

  group('plans and programmes', () {
    testWidgets('the list tells an ongoing plan from a programme, and what each holds', (tester) async {
      final w = OfferingsWorld(plans: [planJson('plan-coaching', subscribers: 2), _programme()]);
      await pumpOfferings(tester, w);
      expect(find.text('Monthly leadership coaching'), findsOneWidget);
      expect(find.text('Ongoing plan · ₹2,999 a month'), findsOneWidget);
      expect(find.text('2 sessions a month of 45 min'), findsOneWidget);
      expect(find.text('2 members'), findsOneWidget);
      expect(find.text('Site to portfolio: a 3-session programme'), findsOneWidget);
      expect(find.text('Programme · ₹5,999 (was ₹8,999)'), findsOneWidget);
      expect(find.text('3 sessions · 3 months to use them'), findsOneWidget);
      expect(find.text('No ongoing plans. A plan is a prepaid term with sessions every month.'), findsNothing);
    });

    testWidgets('an empty list says what a plan is', (tester) async {
      await pumpOfferings(tester, OfferingsWorld(plans: []));
      expect(find.text('No ongoing plans. A plan is a prepaid term with sessions every month.'), findsOneWidget);
    });

    testWidgets('a plans list that fails says why and Try again asks again', (tester) async {
      var fail = true;
      final w = OfferingsWorld();
      final (api, _) = await pumpOfferings(
        tester,
        w,
        extra: {
          'GET /mentor-plans/mine': (_) => fail ? refuse('You do not have a mentor profile.', status: 404) : w.plans,
        },
      );
      expect(find.text('Unable to Load Your Plans'), findsOneWidget);
      expect(find.text('Career clarity call'), findsOneWidget, reason: 'the storefront still shows');
      fail = false;
      await tapText(tester, 'Try Again');
      expect(find.text('Monthly leadership coaching'), findsOneWidget);
      expect(api.count('GET /mentor-plans/mine'), 2);
    });

    testWidgets('adding an ongoing plan: each field is checked as the API checks it, then the plan is sent as typed', (
      tester,
    ) async {
      final changes = <String>[];
      final (api, _) = await pumpOfferings(tester, OfferingsWorld(plans: []), changes: changes);
      await tapKey(tester, 'add-plan');
      expect(find.text('Add an Ongoing Plan'), findsWidgets);
      expect(find.byKey(const ValueKey('kind-recurring')), findsOneWidget);

      await submit(tester, 'Add');
      expect(find.text('Enter a title of at least 3 characters.'), findsOneWidget);
      await typeKey(tester, 'offering-title', 'Monthly leadership coaching');
      await submit(tester, 'Add');
      expect(find.text('Enter the price in rupees, or turn on Free.'), findsOneWidget);
      await typeKey(tester, 'offering-price', '499');
      await submit(tester, 'Add');
      expect(
        find.text('An ongoing plan is either free, or priced between ₹500 and ₹5,00,000 per term.'),
        findsOneWidget,
      );
      await typeKey(tester, 'offering-price', '2999');
      await typeKey(tester, 'plan-per-month', '0');
      await submit(tester, 'Add');
      expect(find.text('Enter how many sessions a month the plan includes, from 1 to 12.'), findsOneWidget);
      await typeKey(tester, 'plan-per-month', '2');
      await typeKey(tester, 'plan-length', '10');
      await submit(tester, 'Add');
      expect(find.text('A session runs 15 to 480 minutes.'), findsOneWidget);
      await typeKey(tester, 'plan-length', '45');
      await typeKey(tester, 'plan-inclusions', List.generate(9, (i) => 'Line $i').join('\n'));
      await submit(tester, 'Add');
      expect(find.text('List up to 8 things the plan includes.'), findsOneWidget);
      expect(api.count('POST /mentor-plans'), 0, reason: 'nothing was sent while a field was wrong');

      await typeKey(tester, 'plan-inclusions', 'Two 45-minute calls a month\n\nChat support between calls');
      await tapKey(tester, 'period-3');
      await submit(tester, 'Add');
      expect(api.bodyOf('POST /mentor-plans'), {
        'title': 'Monthly leadership coaching',
        'kind': 'RECURRING',
        'pricePaisa': 299900,
        'billingPeriodMonths': 3,
        'sessionsPerMonth': 2,
        'sessionDurationMin': 45,
        'inclusions': ['Two 45-minute calls a month', 'Chat support between calls'],
        'active': true,
      });
      expect(find.text('Added.'), findsOneWidget);
      expect(find.text('Ongoing plan · ₹2,999 a month'), findsNothing, reason: 'a 3-month term is not "a month"');
      expect(find.text('Ongoing plan · ₹2,999 every 3 months'), findsOneWidget);
      expect(changes, ['changed']);
    });

    testWidgets('a free plan sends price 0, and the API\'s refusal keeps the sheet open', (tester) async {
      final (api, _) = await pumpOfferings(
        tester,
        OfferingsWorld(plans: []),
        extra: {'POST /mentor-plans': (_) => refuse('Accept the marketplace seller terms first.', status: 403)},
      );
      await tapKey(tester, 'add-plan');
      await typeKey(tester, 'offering-title', 'Free office hours');
      await tapKey(tester, 'offering-free');
      await submit(tester, 'Add');
      expect((api.bodyOf('POST /mentor-plans') as Map)['pricePaisa'], 0);
      expect(find.text('Accept the marketplace seller terms first.'), findsOneWidget);
      expect(find.byKey(const ValueKey('offering-title')), findsOneWidget, reason: 'the sheet stays open');
    });

    testWidgets(
      'adding a programme: a syllabus of 2 to 24 sessions, no price floor of the app\'s own, and a body without a monthly cadence',
      (tester) async {
        final (api, _) = await pumpOfferings(tester, OfferingsWorld(plans: []));
        await tapKey(tester, 'add-programme');
        expect(find.text('Add a Programme'), findsWidgets);
        expect(find.byKey(const ValueKey('module-0')), findsOneWidget);
        expect(find.byKey(const ValueKey('module-1')), findsOneWidget);
        expect(find.byKey(const ValueKey('module-remove-0')), findsNothing, reason: 'two sessions is the least');
        expect(
          find.byKey(const ValueKey('plan-per-month')),
          findsNothing,
          reason: 'a programme has no sessions a month',
        );

        await typeKey(tester, 'offering-title', 'Site to portfolio');
        // No ₹499 floor of the app's own (owner, 7 Nov 2026): the API answers for its rule.
        await typeKey(tester, 'offering-price', '5999');
        await typeKey(tester, 'plan-access', '30');
        await submit(tester, 'Add');
        expect(find.text('Access: 1 to 24 months to use the sessions.'), findsOneWidget);
        await typeKey(tester, 'plan-access', '3');
        await submit(tester, 'Add');
        expect(find.text('Session 1: enter a title of at least 3 characters.'), findsOneWidget);
        await typeKey(tester, 'module-title-0', 'Where you are');
        await typeKey(tester, 'module-outline-0', 'Scope and gaps');
        await typeKey(tester, 'module-title-1', 'Vendor and SLA governance');
        await typeKey(tester, 'module-minutes-1', '5');
        await submit(tester, 'Add');
        expect(find.text('Session 2: 15 to 480 minutes.'), findsOneWidget);
        await typeKey(tester, 'module-minutes-1', '60');
        await tapKey(tester, 'module-add');
        expect(find.byKey(const ValueKey('module-2')), findsOneWidget);
        expect(find.byKey(const ValueKey('module-remove-2')), findsOneWidget);
        await submit(tester, 'Add');
        expect(find.text('Session 3: enter a title of at least 3 characters.'), findsOneWidget);
        await tapKey(tester, 'module-remove-2');
        expect(find.byKey(const ValueKey('module-2')), findsNothing);
        await typeKey(tester, 'plan-inclusions', 'Notes After Every Session');
        expect(api.count('POST /mentor-plans'), 0);
        await submit(tester, 'Add');
        expect(api.bodyOf('POST /mentor-plans'), {
          'title': 'Site to portfolio',
          'kind': 'CURRICULUM',
          'pricePaisa': 599900,
          'accessMonths': 3,
          'modules': [
            {'title': 'Where you are', 'outline': 'Scope and gaps'},
            {'title': 'Vendor and SLA governance', 'durationMin': 60},
          ],
          'inclusions': ['Notes After Every Session'],
          'active': true,
        });
        expect(find.text('Programme · ₹5,999'), findsOneWidget);
        expect(find.text('2 sessions · 3 months to use them'), findsOneWidget);
      },
    );

    testWidgets('switching the kind in the form switches its fields', (tester) async {
      await pumpOfferings(tester, OfferingsWorld(plans: []));
      await tapKey(tester, 'add-plan');
      expect(find.byKey(const ValueKey('plan-per-month')), findsOneWidget);
      await tapKey(tester, 'kind-programme');
      expect(find.byKey(const ValueKey('plan-per-month')), findsNothing);
      expect(find.byKey(const ValueKey('plan-access')), findsOneWidget);
      expect(find.byKey(const ValueKey('module-0')), findsOneWidget);
      await tapKey(tester, 'kind-recurring');
      expect(find.byKey(const ValueKey('plan-per-month')), findsOneWidget);
    });

    testWidgets('editing a programme starts from its syllabus and sends it back, without a kind', (tester) async {
      final w = OfferingsWorld(plans: [_programme()]);
      final (api, _) = await pumpOfferings(tester, w);
      await tapIn(tester, 'plan-plan-programme', 'Edit');
      expect(find.text('Edit Programme'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const ValueKey('offering-price'))).controller!.text, '5999');
      // No strikethrough field any more (owner, 9 Nov 2026); the listing's own stays as it is.
      expect(find.byKey(const ValueKey('offering-compare')), findsNothing);
      expect(tester.widget<TextField>(find.byKey(const ValueKey('plan-access'))).controller!.text, '3');
      expect(
        tester.widget<TextField>(find.byKey(const ValueKey('module-title-2'))).controller!.text,
        'The portfolio business case',
      );
      expect(tester.widget<TextField>(find.byKey(const ValueKey('module-minutes-2'))).controller!.text, '90');
      expect(find.byKey(const ValueKey('kind-programme')), findsNothing, reason: 'the API refuses a change of kind');
      await typeKey(tester, 'module-title-1', 'Vendor governance');
      await submit(tester, 'Save');
      final body = api.bodyOf('PATCH /mentor-plans/plan-programme') as Map;
      expect(body.containsKey('kind'), isFalse);
      expect(body['compareAtPaisa'], 899900, reason: 'the strikethrough the plan already carries is kept');
      expect(body['accessMonths'], 3);
      expect(body['sessionDurationMin'], 60);
      expect((body['modules'] as List).map((m) => (m as Map)['title']), [
        'Where you are',
        'Vendor governance',
        'The portfolio business case',
      ]);
      expect((body['modules'] as List)[2], {'title': 'The portfolio business case', 'durationMin': 90});
      expect(body.containsKey('sessionsPerMonth'), isFalse);
      expect(find.text('Saved.'), findsOneWidget);
      expect(find.text('Programme · ₹5,999 (was ₹8,999)'), findsOneWidget);
    });

    testWidgets('editing an ongoing plan sends its cadence and leaves the strikethrough alone when it had none', (
      tester,
    ) async {
      final (api, _) = await pumpOfferings(tester, OfferingsWorld());
      await tapIn(tester, 'plan-plan-coaching', 'Edit');
      expect(find.text('Edit Plan'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const ValueKey('plan-per-month'))).controller!.text, '2');
      expect(tester.widget<TextField>(find.byKey(const ValueKey('plan-length'))).controller!.text, '45');
      await typeKey(tester, 'plan-per-month', '4');
      await submit(tester, 'Save');
      final body = api.bodyOf('PATCH /mentor-plans/plan-coaching') as Map;
      expect(body['sessionsPerMonth'], 4);
      expect(body['billingPeriodMonths'], 1);
      expect(body.containsKey('compareAtPaisa'), isFalse);
      expect(body.containsKey('kind'), isFalse);
      expect(find.text('4 sessions a month of 45 min'), findsOneWidget);
    });

    testWidgets('pausing and resuming a plan patch active alone', (tester) async {
      final (api, _) = await pumpOfferings(tester, OfferingsWorld(plans: [_programme()]));
      await tapIn(tester, 'plan-plan-programme', 'Pause');
      expect(api.bodyOf('PATCH /mentor-plans/plan-programme'), {'active': false});
      expect(find.text('Paused. Members no longer see it.'), findsOneWidget);
      expect(find.text('Paused'), findsOneWidget);
      await tapIn(tester, 'plan-plan-programme', 'Resume');
      expect(api.bodyOf('PATCH /mentor-plans/plan-programme'), {'active': true});
      expect(find.text('Live on your storefront.'), findsOneWidget);
    });

    testWidgets('deleting a plan asks first', (tester) async {
      final (api, _) = await pumpOfferings(tester, OfferingsWorld());
      await tapIn(tester, 'plan-plan-coaching', 'Delete');
      await tester.tap(inDialog('Keep It'));
      await tester.pumpAndSettle();
      expect(api.count('DELETE /mentor-plans/plan-coaching'), 0);
      await tapIn(tester, 'plan-plan-coaching', 'Delete');
      await tester.tap(inDialog('Delete'));
      await settle(tester);
      expect(api.count('DELETE /mentor-plans/plan-coaching'), 1);
      expect(find.text('Monthly leadership coaching'), findsNothing);
    });
  });

  group('group sessions: the list', () {
    testWidgets('a draft, an open session, a held one and a cancelled one each read as what they are', (tester) async {
      final w = OfferingsWorld(
        sessions: [
          hostedJson('grp-draft', title: 'Salary negotiation circle', status: 'DRAFT', capacity: 25),
          hostedJson('grp-clinic', title: 'Open clinic', taken: 3, waiting: 2),
          hostedJson('grp-paid', title: 'Panel masterclass', price: 29900, capacity: 15),
          hostedJson(
            'grp-past',
            title: 'Reading an SLA',
            status: 'COMPLETED',
            taken: 2,
            at: offeringsNow.subtract(const Duration(days: 12)),
          ),
          hostedJson('newg-1', title: 'A cancelled clinic', status: 'CANCELLED'),
        ],
      );
      await pumpOfferings(tester, w);
      await openOfferingsTab(tester, 'Group Mentoring');
      expect(find.text('Draft'), findsOneWidget);
      expect(find.text('Open for Registration'), findsNWidgets(2));
      expect(find.text('Held'), findsOneWidget);
      expect(find.text('Cancelled'), findsOneWidget);
      expect(find.text('Free · 3 of 25 seats · 2 waiting'), findsOneWidget);
      expect(find.text('₹299 · 0 of 15 seats'), findsOneWidget);
      expect(inRow('session-grp-draft', 'Publish'), findsOneWidget);
      expect(inRow('session-grp-clinic', 'Publish'), findsNothing);
    });

    testWidgets('a series reads as its first day and how many more', (tester) async {
      final start = offeringsNow.add(const Duration(days: 3));
      final w = OfferingsWorld(
        sessions: [
          hostedJson(
            'grp-clinic',
            title: 'Bootcamp',
            at: start,
            occurrences: [
              for (var i = 0; i < 3; i++)
                {
                  'id': 'o$i',
                  'seq': i + 1,
                  'title': null,
                  'scheduledAt': iso(start.add(Duration(days: i))),
                  'durationMin': 60,
                  'status': 'SCHEDULED',
                  'completedAt': null,
                  'cancelledAt': null,
                },
            ],
          ),
        ],
      );
      await pumpOfferings(tester, w);
      await openOfferingsTab(tester, 'Group Mentoring');
      expect(find.textContaining('and 2 more days'), findsOneWidget);
    });

    testWidgets('an empty list says what a clinic is, and a failing list says why', (tester) async {
      var fail = true;
      final w = OfferingsWorld(sessions: []);
      final (api, _) = await pumpOfferings(
        tester,
        w,
        extra: {
          'GET /mentorship/group-sessions': (_) =>
              fail ? refuse('Sign in to see your own sessions.', status: 403) : page(w.sessions),
        },
      );
      await openOfferingsTab(tester, 'Group Mentoring');
      expect(find.text('Unable to Load Your Group Sessions'), findsOneWidget);
      fail = false;
      await tapText(tester, 'Try Again');
      expect(
        find.text('No group sessions yet. A clinic is an hour with a group of members. Free sessions keep a waitlist.'),
        findsOneWidget,
      );
      expect(api.count('GET /mentorship/group-sessions'), 2);
    });
  });

  group('group sessions: hosting one', () {
    testWidgets('each field is checked as the API checks it, then the session is sent as a draft', (tester) async {
      final changes = <String>[];
      final (api, _) = await pumpOfferings(tester, OfferingsWorld(sessions: []), changes: changes);
      await openOfferingsTab(tester, 'Group Mentoring');
      await tapKey(tester, 'add-group');
      expect(find.text('Host a Group Session'), findsWidgets);
      expect(find.text('Save Draft'), findsOneWidget);

      await submit(tester, 'Save Draft');
      expect(find.text('Enter a title of at least 5 characters.'), findsOneWidget);
      await typeKey(tester, 'group-title', 'From site to portfolio: an open clinic');
      await typeKey(tester, 'group-link', 'not a link');
      await submit(tester, 'Save Draft');
      expect(find.textContaining('Enter a full web address'), findsOneWidget);
      await typeKey(tester, 'group-link', 'meet.google.com/abc-defg-hij');
      await submit(tester, 'Save Draft');
      expect(find.text('Select a date and time for every day.'), findsOneWidget);

      await tapKey(tester, 'day-pick-0');
      await acceptPickers(tester);
      expect(find.textContaining('Tue 27 Oct'), findsOneWidget);
      await typeKey(tester, 'day-minutes-0', '10');
      await submit(tester, 'Save Draft');
      expect(find.text('A day runs 15 to 480 minutes.'), findsOneWidget);
      await typeKey(tester, 'day-minutes-0', '60');
      await typeKey(tester, 'group-capacity', '1');
      await submit(tester, 'Save Draft');
      expect(find.textContaining('Enter seats as a number from 2 to 50'), findsOneWidget);
      await typeKey(tester, 'group-capacity', '25');
      await typeKey(tester, 'group-price', '50001');
      await submit(tester, 'Save Draft');
      expect(find.text('Prices go up to ₹50,000.'), findsOneWidget);
      await typeKey(tester, 'group-price', '');
      expect(api.count('POST /mentorship/group-sessions'), 0, reason: 'nothing was sent while a field was wrong');

      await typeKey(tester, 'group-summary', 'An hour on how to frame a portfolio case.');
      await typeKey(tester, 'group-agenda', 'Bring a real case.\n\nWe start with scope.');
      await submit(tester, 'Save Draft');
      expect(api.bodyOf('POST /mentorship/group-sessions'), {
        'title': 'From site to portfolio: an open clinic',
        'summary': 'An hour on how to frame a portfolio case.',
        'agendaHtml': '<p>Bring a real case.</p><p>We start with scope.</p>',
        'mode': 'VIDEO',
        'meetingLink': 'https://meet.google.com/abc-defg-hij',
        'occurrences': [
          {'scheduledAt': DateTime(2026, 10, 27, 10).toUtc().toIso8601String(), 'durationMin': 60},
        ],
        'capacity': 25,
        'pricePaisa': null,
        'waitlistEnabled': true,
      });
      expect(find.text('Saved.'), findsOneWidget);
      expect(find.text('Draft'), findsOneWidget);
      expect(changes, ['changed']);
    });

    testWidgets('open for registration now publishes in the same call', (tester) async {
      final (api, _) = await pumpOfferings(tester, OfferingsWorld(sessions: []));
      await openOfferingsTab(tester, 'Group Mentoring');
      await tapKey(tester, 'add-group');
      await typeKey(tester, 'group-title', 'An open clinic');
      await typeKey(tester, 'group-link', 'https://meet.google.com/abc-defg-hij');
      await tapKey(tester, 'day-pick-0');
      await acceptPickers(tester);
      await tapKey(tester, 'group-publish');
      expect(find.text('Publish'), findsWidgets);
      await submit(tester, 'Publish');
      expect((api.bodyOf('POST /mentorship/group-sessions') as Map)['publish'], isTrue);
      expect(find.text('Open for Registration'), findsOneWidget);
    });

    testWidgets(
      'an in-person session needs a venue and sends no link; the joining link is the API\'s to judge when blank',
      (tester) async {
        final (api, _) = await pumpOfferings(
          tester,
          OfferingsWorld(sessions: []),
          extra: {'POST /mentorship/group-sessions': (_) => refuse('Add the joining link people will use.')},
        );
        await openOfferingsTab(tester, 'Group Mentoring');
        await tapKey(tester, 'add-group');
        await typeKey(tester, 'group-title', 'A site visit morning');
        await tapKey(tester, 'day-pick-0');
        await acceptPickers(tester);
        // Video with no link: the mentor's standing link may stand in, so the API decides.
        await submit(tester, 'Save Draft');
        expect(api.count('POST /mentorship/group-sessions'), 1);
        expect(find.text('Add the joining link people will use.'), findsOneWidget);
        expect((api.bodyOf('POST /mentorship/group-sessions') as Map).containsKey('meetingLink'), isFalse);

        await tapKey(tester, 'mode-IN_PERSON');
        expect(find.byKey(const ValueKey('group-link')), findsNothing);
        await submit(tester, 'Save Draft');
        expect(find.text('Add the venue where people will meet.'), findsOneWidget);
        expect(api.count('POST /mentorship/group-sessions'), 1);
        await typeKey(tester, 'group-venue', 'Prestige Tech Park, Bengaluru');
        await submit(tester, 'Save Draft');
        final body = api.bodyOf('POST /mentorship/group-sessions') as Map;
        expect(body['mode'], 'IN_PERSON');
        expect(body['location'], 'Prestige Tech Park, Bengaluru');
        expect(body.containsKey('meetingLink'), isFalse);
      },
    );

    testWidgets('a seat price needs seats, turns the waitlist off, and is sent in paisa', (tester) async {
      final (api, _) = await pumpOfferings(tester, OfferingsWorld(sessions: []));
      await openOfferingsTab(tester, 'Group Mentoring');
      await tapKey(tester, 'add-group');
      await typeKey(tester, 'group-title', 'Panel interview masterclass');
      await typeKey(tester, 'group-link', 'https://meet.google.com/abc-defg-hij');
      await tapKey(tester, 'day-pick-0');
      await acceptPickers(tester);
      expect(tester.widget<SwitchListTile>(find.byKey(const ValueKey('group-waitlist'))).onChanged, isNotNull);
      await typeKey(tester, 'group-price', '499');
      await typeKey(tester, 'group-capacity', '');
      await submit(tester, 'Save Draft');
      expect(find.text('A paid session needs a number of seats.'), findsOneWidget);
      await typeKey(tester, 'group-capacity', '15');
      expect(
        tester.widget<SwitchListTile>(find.byKey(const ValueKey('group-waitlist'))).onChanged,
        isNull,
        reason: 'a paid session keeps no waitlist',
      );
      await submit(tester, 'Save Draft');
      final body = api.bodyOf('POST /mentorship/group-sessions') as Map;
      expect(body['pricePaisa'], 49900);
      expect(body['capacity'], 15);
      expect(body['waitlistEnabled'], isFalse);
      expect(find.text('₹499 · 0 of 15 seats'), findsOneWidget);
    });

    testWidgets('no seat limit is sent as null, and a series of days must not overlap', (tester) async {
      final (api, _) = await pumpOfferings(tester, OfferingsWorld(sessions: []));
      await openOfferingsTab(tester, 'Group Mentoring');
      await tapKey(tester, 'add-group');
      await typeKey(tester, 'group-title', 'A two day bootcamp');
      await typeKey(tester, 'group-link', 'https://meet.google.com/abc-defg-hij');
      await typeKey(tester, 'group-capacity', '');
      await tapKey(tester, 'day-pick-0');
      await acceptPickers(tester);
      await tapKey(tester, 'day-add');
      expect(find.byKey(const ValueKey('day-pick-1')), findsOneWidget);
      await tapKey(tester, 'day-pick-1');
      await acceptPickers(tester);
      await submit(tester, 'Save Draft');
      expect(find.text('Days must not overlap.'), findsOneWidget, reason: 'the same start twice');
      // The second day moves to the 28th.
      await tapKey(tester, 'day-pick-1');
      await tester.pumpAndSettle();
      await tester.tap(find.text('28'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await submit(tester, 'Save Draft');
      final body = api.bodyOf('POST /mentorship/group-sessions') as Map;
      expect(body['capacity'], isNull);
      expect(body.containsKey('capacity'), isTrue);
      expect((body['occurrences'] as List), hasLength(2));
      expect(find.textContaining('and 1 more day'), findsOneWidget);
      // A day can be taken out again.
    });

    testWidgets('a day can be removed from a series while there are two', (tester) async {
      await pumpOfferings(tester, OfferingsWorld(sessions: []));
      await openOfferingsTab(tester, 'Group Mentoring');
      await tapKey(tester, 'add-group');
      expect(find.byKey(const ValueKey('day-remove-0')), findsNothing, reason: 'one day is the least');
      await tapKey(tester, 'day-add');
      expect(find.byKey(const ValueKey('day-remove-1')), findsOneWidget);
      await tapKey(tester, 'day-remove-1');
      expect(find.byKey(const ValueKey('day-pick-1')), findsNothing);
    });
  });

  group('group sessions: one in full', () {
    final roster = [
      attendeeJson('a0', 'Meera', 'Nair', question: 'How do I present a portfolio case to finance?'),
      attendeeJson('a1', 'Tanvi', 'Joshi'),
      attendeeJson('a2', 'Sana', 'Qureshi', status: 'WAITLISTED'),
    ];

    testWidgets('opening a row reads the session and shows the roster, each person\'s question, and the waitlist', (
      tester,
    ) async {
      final w = OfferingsWorld(sessions: [hostedJson('grp-clinic', taken: 2, waiting: 1, attendees: roster)]);
      final (api, _) = await pumpOfferings(tester, w);
      await openOfferingsTab(tester, 'Group Mentoring');
      await tapIn(tester, 'session-grp-clinic', 'Details');
      expect(api.count('GET /mentorship/group-sessions/grp-clinic'), 1);
      expect(find.byKey(const ValueKey('session-title')), findsOneWidget);
      expect(find.text('Virtual'), findsOneWidget, reason: 'VIDEO reads "Virtual" (owner, 7 Nov 2026)');
      expect(find.text('https://meet.google.com/icr-demo'), findsOneWidget);
      expect(find.text('2 seats taken of 25 · 1 waiting'), findsOneWidget);
      expect(find.text('Attendees (2)'), findsOneWidget);
      expect(find.text('Meera Nair'), findsOneWidget);
      expect(find.text('"How do I present a portfolio case to finance?"'), findsOneWidget);
      expect(find.text('WAITLIST'), findsOneWidget);
      expect(find.text('Sana Qureshi'), findsOneWidget);
      expect(find.byKey(const ValueKey('session-attendance')), findsNothing, reason: 'it has not started');
    });

    testWidgets('a session that cannot be read says why, and Try again reads it again', (tester) async {
      var fail = true;
      final w = OfferingsWorld(sessions: [hostedJson('grp-clinic')]);
      final (api, _) = await pumpOfferings(
        tester,
        w,
        extra: {
          'GET /mentorship/group-sessions/grp-clinic': (_) =>
              fail ? refuse('Session not found', status: 404) : w.sessions.first,
        },
      );
      await openOfferingsTab(tester, 'Group Mentoring');
      await tapIn(tester, 'session-grp-clinic', 'Details');
      expect(find.text('Unable to Open This Session'), findsOneWidget);
      expect(find.text('Session not found'), findsOneWidget);
      fail = false;
      await tapText(tester, 'Try Again');
      expect(find.byKey(const ValueKey('session-title')), findsOneWidget);
      expect(api.count('GET /mentorship/group-sessions/grp-clinic'), 2);
    });

    testWidgets('editing keeps what the API would otherwise blank: its days, cover, zone, and the published state', (
      tester,
    ) async {
      final w = OfferingsWorld(sessions: [hostedJson('grp-clinic', taken: 2, attendees: roster)]);
      final (api, _) = await pumpOfferings(tester, w);
      await openOfferingsTab(tester, 'Group Mentoring');
      await tapIn(tester, 'session-grp-clinic', 'Details');
      await tapKey(tester, 'session-edit');
      expect(find.text('Edit Group Session'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byKey(const ValueKey('group-title'))).controller!.text,
        'From site to portfolio: an open clinic',
      );
      expect(
        tester.widget<TextField>(find.byKey(const ValueKey('group-agenda'))).controller!.text,
        'Bring a real case.\n\nWe start with scope.',
      );
      expect(
        tester.widget<TextField>(find.byKey(const ValueKey('group-link'))).controller!.text,
        'https://meet.google.com/icr-demo',
      );
      expect(tester.widget<TextField>(find.byKey(const ValueKey('group-capacity'))).controller!.text, '25');
      expect(find.byKey(const ValueKey('group-publish')), findsNothing, reason: 'it is already published');
      expect(find.byKey(const ValueKey('group-waitlist')), findsNothing, reason: 'the waitlist is kept as it is');
      await typeKey(tester, 'group-title', 'Portfolio clinic, second edition');
      await submit(tester, 'Save');
      final body = api.bodyOf('PATCH /mentorship/group-sessions/grp-clinic') as Map;
      expect(body['title'], 'Portfolio clinic, second edition');
      expect(body['coverUrl'], '/uploads/cover.jpg');
      expect(body['timezone'], 'Asia/Kolkata');
      expect(body['capacity'], 25);
      expect(body['pricePaisa'], isNull);
      expect(body['meetingLink'], 'https://meet.google.com/icr-demo');
      expect(body.containsKey('publish'), isFalse);
      expect(body.containsKey('waitlistEnabled'), isFalse);
      final occ = (body['occurrences'] as List).single as Map;
      expect(occ['id'], 'grp-clinic-occ1');
      expect(occ['scheduledAt'], iso(offeringsNow.add(const Duration(days: 6))));
      expect(find.text('Saved.'), findsOneWidget);
      expect(find.text('Portfolio clinic, second edition'), findsWidgets);
    });

    testWidgets('a day that has run is shown and sent back untouched', (tester) async {
      mentoringNow = () => _later;
      final held = offeringsNow.subtract(const Duration(days: 3));
      final next = _later.add(const Duration(days: 2));
      final w = OfferingsWorld(
        sessions: [
          hostedJson(
            'grp-clinic',
            at: held,
            taken: 1,
            attendees: [attendeeJson('a0', 'Meera', 'Nair')],
            occurrences: [
              {
                'id': 'o1',
                'seq': 1,
                'title': null,
                'scheduledAt': iso(held),
                'durationMin': 60,
                'status': 'COMPLETED',
                'completedAt': iso(held),
                'cancelledAt': null,
              },
              {
                'id': 'o2',
                'seq': 2,
                'title': null,
                'scheduledAt': iso(next),
                'durationMin': 60,
                'status': 'SCHEDULED',
                'completedAt': null,
                'cancelledAt': null,
              },
            ],
          ),
        ],
      );
      final (api, _) = await pumpOfferings(tester, w);
      await openOfferingsTab(tester, 'Group Mentoring');
      await tapIn(tester, 'session-grp-clinic', 'Details');
      await tapKey(tester, 'session-edit');
      expect(find.byKey(const ValueKey('day-locked-0')), findsOneWidget);
      expect(find.textContaining('Held'), findsWidgets);
      expect(find.byKey(const ValueKey('day-pick-0')), findsNothing, reason: 'a closed day cannot be moved');
      expect(find.byKey(const ValueKey('day-pick-1')), findsOneWidget);
      await submit(tester, 'Save');
      final occ = (api.bodyOf('PATCH /mentorship/group-sessions/grp-clinic') as Map)['occurrences'] as List;
      expect((occ[0] as Map)['id'], 'o1');
      expect((occ[0] as Map)['scheduledAt'], iso(held));
      expect((occ[1] as Map)['id'], 'o2');
    });

    testWidgets('a refused save keeps the form and shows the API\'s sentence', (tester) async {
      final w = OfferingsWorld(sessions: [hostedJson('grp-clinic', taken: 2, attendees: roster)]);
      final (api, _) = await pumpOfferings(
        tester,
        w,
        extra: {
          'PATCH /mentorship/group-sessions/grp-clinic': (_) =>
              refuse('Seats are already sold at the current price — run this one and schedule another.'),
        },
      );
      await openOfferingsTab(tester, 'Group Mentoring');
      await tapIn(tester, 'session-grp-clinic', 'Details');
      await tapKey(tester, 'session-edit');
      await typeKey(tester, 'group-price', '499');
      await submit(tester, 'Save');
      expect(api.count('PATCH /mentorship/group-sessions/grp-clinic'), 1);
      expect(
        find.text('Seats are already sold at the current price — run this one and schedule another.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('group-title')), findsOneWidget);
    });

    testWidgets(
      'a draft is published from its row, or from its sheet after a confirm; editing a draft can publish too',
      (tester) async {
        final w = OfferingsWorld(
          sessions: [
            hostedJson('grp-draft', title: 'Salary negotiation circle', status: 'DRAFT'),
            hostedJson('newg-1', title: 'Second draft', status: 'DRAFT'),
          ],
        );
        final (api, _) = await pumpOfferings(tester, w);
        await openOfferingsTab(tester, 'Group Mentoring');
        await tapIn(tester, 'session-grp-draft', 'Publish');
        expect(api.count('POST /mentorship/group-sessions/grp-draft/publish'), 1);
        expect(find.text('Published. Members can register.'), findsOneWidget);
        expect(inRow('session-grp-draft', 'Publish'), findsNothing);

        await openOfferingsTab(tester, 'Group Mentoring');

        await tapIn(tester, 'session-newg-1', 'Details');
        await tapKey(tester, 'session-publish');
        expect(find.text('Publish This Session?'), findsOneWidget);
        await tester.tap(inDialog('Not Yet'));
        await tester.pumpAndSettle();
        expect(api.count('POST /mentorship/group-sessions/newg-1/publish'), 0);
        await tapKey(tester, 'session-publish');
        await tester.tap(inDialog('Publish'));
        await settle(tester);
        expect(api.count('POST /mentorship/group-sessions/newg-1/publish'), 1);
        expect(find.text('Open for Registration'), findsWidgets);
      },
    );

    testWidgets('a draft edited with the publish switch on goes live in the same save', (tester) async {
      final w = OfferingsWorld(
        sessions: [hostedJson('grp-draft', title: 'Salary negotiation circle', status: 'DRAFT')],
      );
      final (api, _) = await pumpOfferings(tester, w);
      await openOfferingsTab(tester, 'Group Mentoring');
      await tapIn(tester, 'session-grp-draft', 'Details');
      await tapKey(tester, 'session-edit');
      expect(find.byKey(const ValueKey('group-publish')), findsOneWidget);
      await tapKey(tester, 'group-publish');
      expect(find.text('Save and Publish'), findsOneWidget);
      await submit(tester, 'Save and Publish');
      expect((api.bodyOf('PATCH /mentorship/group-sessions/grp-draft') as Map)['publish'], isTrue);
    });

    testWidgets('cancelling needs a reason of at least three characters, and tells the room', (tester) async {
      final w = OfferingsWorld(sessions: [hostedJson('grp-clinic', taken: 2, attendees: roster)]);
      final (api, _) = await pumpOfferings(tester, w);
      await openOfferingsTab(tester, 'Group Mentoring');
      await tapIn(tester, 'session-grp-clinic', 'Details');
      await tapKey(tester, 'session-cancel');
      expect(find.textContaining('Everyone registered is notified, with your reason.'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('form-text')), 'No');
      await tester.tap(find.text('Cancel Session').last);
      await tester.pump();
      expect(find.text('Enter at least 3 characters.'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('form-text')), 'I have to travel that week');
      await tester.tap(find.text('Cancel Session').last);
      await settle(tester);
      expect(api.bodyOf('POST /mentorship/group-sessions/grp-clinic/cancel'), {'reason': 'I have to travel that week'});
      expect(find.text('Session cancelled.'), findsOneWidget);
      expect(find.text('Cancelled: I have to travel that week'), findsOneWidget);
      expect(find.byKey(const ValueKey('session-cancel')), findsNothing);
      expect(find.byKey(const ValueKey('session-edit')), findsNothing, reason: 'a closed session is not edited');
    });

    testWidgets('recording attendance appears once a day has started: tick who came, the rest are no-shows', (
      tester,
    ) async {
      mentoringNow = () => _later;
      final w = OfferingsWorld(sessions: [hostedJson('grp-clinic', taken: 2, attendees: roster)]);
      final (api, _) = await pumpOfferings(tester, w);
      await openOfferingsTab(tester, 'Group Mentoring');
      await tapIn(tester, 'session-grp-clinic', 'Details');
      await tapKey(tester, 'session-attendance');
      expect(find.text('Who Attended?'), findsOneWidget);
      expect(find.byKey(const ValueKey('present-a0')), findsOneWidget);
      expect(find.byKey(const ValueKey('present-a1')), findsOneWidget);
      expect(find.byKey(const ValueKey('present-a2')), findsNothing, reason: 'a waitlisted person held no seat');
      await tester.tap(find.byKey(const ValueKey('present-a1')));
      await tester.pump();
      await typeKey(tester, 'attendance-minutes', '5');
      await submit(tester, 'Record Attendance');
      expect(find.text('Enter the minutes it ran, from 15 to 480, or leave it empty.'), findsOneWidget);
      expect(api.count('POST /mentorship/group-sessions/grp-clinic/complete'), 0);
      await typeKey(tester, 'attendance-minutes', '50');
      await typeKey(tester, 'attendance-note', 'Good questions');
      await submit(tester, 'Record Attendance');
      expect(api.bodyOf('POST /mentorship/group-sessions/grp-clinic/complete'), {
        'attendedIds': ['a0'],
        'durationMin': 50,
        'note': 'Good questions',
      });
      expect(find.text('Attendance recorded.'), findsOneWidget);
      expect(find.text('Held'), findsWidgets);
      expect(find.byKey(const ValueKey('session-attendance')), findsNothing);
    });

    testWidgets('a refused attendance keeps the form and says why', (tester) async {
      mentoringNow = () => _later;
      final w = OfferingsWorld(sessions: [hostedJson('grp-clinic', taken: 2, attendees: roster)]);
      final (api, _) = await pumpOfferings(
        tester,
        w,
        extra: {
          'POST /mentorship/group-sessions/grp-clinic/complete': (_) =>
              refuse('This session hasn’t started yet — you can record attendance once it begins.'),
        },
      );
      await openOfferingsTab(tester, 'Group Mentoring');
      await tapIn(tester, 'session-grp-clinic', 'Details');
      await tapKey(tester, 'session-attendance');
      await submit(tester, 'Record Attendance');
      expect(api.count('POST /mentorship/group-sessions/grp-clinic/complete'), 1);
      expect(find.text('This session hasn’t started yet — you can record attendance once it begins.'), findsOneWidget);
      expect(find.byKey(const ValueKey('present-a0')), findsOneWidget);
    });
  });
}
