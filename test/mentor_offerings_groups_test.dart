import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/features/mentor_desk/offerings/group_form.dart';
import 'package:icr_mobile/features/mentor_desk/offerings/offerings_controller.dart';
import 'package:icr_mobile/features/mentor_desk/offerings/offerings_files.dart';
import 'package:icr_mobile/features/mentor_desk/offerings/offerings_models.dart';
import 'package:icr_mobile/features/mentor_desk/offerings/offerings_repository.dart';
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

/// An instant on the Indian clock, as the composer turns a date and a wall time in Asia/Kolkata into one.
String _kolkata(int month, int day, {int hour = 18, int minute = 0}) =>
    DateTime.utc(2026, month, day, hour, minute).subtract(const Duration(hours: 5, minutes: 30)).toIso8601String();

String _fieldText(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.byKey(ValueKey(key))).controller!.text;

/// Opens the group composer over a bare page, as the desk's buttons do, on a controller over the fake API (its
/// storefront read first, so the seller gate is known).
Future<(FakeApi, OfferingsController, List<bool>)> pumpComposer(
  WidgetTester tester,
  OfferingsWorld w, {
  HostedSession? existing,
  HostedSession? copyFrom,
  Map<String, Reply> extra = const {},
  OfferingFilePicker? pickFile,
}) async {
  phone(tester, height: 16000);
  final api = w.api(extra: extra);
  final c = OfferingsController(OfferingsRepository(api: api.client()));
  await tester.runAsync(c.storefront.load);
  final results = <bool>[];
  await pumpApp(
    tester,
    Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            key: const ValueKey('open-composer'),
            onPressed: () async => results.add(
              await openGroupComposer(
                context,
                controller: c,
                existing: existing,
                copyFrom: copyFrom,
                pickFile: pickFile ?? ({required bool imageOnly}) async => pdfFile(name: 'cover.png'),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tapKey(tester, 'open-composer');
  return (api, c, results);
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
      expect(find.text('No Ongoing Plans Yet'), findsNothing);
    });

    testWidgets('an empty list says what a plan is', (tester) async {
      await pumpOfferings(tester, OfferingsWorld(plans: []));
      expect(find.text('No Ongoing Plans Yet'), findsOneWidget);
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

    testWidgets('Create a Plan opens the ongoing plan form; Edit opens a plan there and a programme in the composer', (
      tester,
    ) async {
      final w = OfferingsWorld(plans: [planJson('plan-coaching'), _programme()]);
      final (api, _) = await pumpOfferings(tester, w);
      await tapKey(tester, 'add-plan');
      expect(find.text('New Ongoing Plan'), findsOneWidget);
      await typeKey(tester, 'plan-title', 'Quarterly review circle');
      await tapKey(tester, 'composer-save');
      expect((api.bodyOf('POST /mentor-plans') as Map)['kind'], 'RECURRING');
      expect(find.text('Added.'), findsOneWidget);
      // Let the message go: it sits over the foot of the next page while it shows.
      await tester.pump(const Duration(seconds: 5));
      await settle(tester);

      await tapIn(tester, 'plan-plan-coaching', 'Edit');
      expect(find.text('Edit Ongoing Plan'), findsOneWidget);
      await tapKey(tester, 'composer-cancel');

      await tapIn(tester, 'plan-${_programme()['id']}', 'Edit');
      expect(find.text('Edit 1:1 Mentoring'), findsOneWidget);
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
        find.text('No group sessions yet. Host a single clinic or a multi-day series, free or paid.'),
        findsOneWidget,
      );
      expect(api.count('GET /mentorship/group-sessions'), 2);
    });
  });

  group('group sessions: the composer', () {
    testWidgets('each field is checked as the website checks it, then the session is sent as a draft', (tester) async {
      final (api, _, results) = await pumpComposer(tester, OfferingsWorld(sessions: []));
      expect(find.text('Host a Group Session'), findsOneWidget);
      expect(
        find.text('Host a group session with its own agenda and meeting room. Your 1:1 availability stays unaffected.'),
        findsOneWidget,
      );
      for (final t in ['The Pitch', 'When', 'Where', 'The Room', 'The Price', 'Get Found']) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      expect(
        _fieldText(tester, 'group-link'),
        'https://meet.google.com/icr-standing',
        reason: 'the standing link on the profile fills a new session',
      );
      expect(_fieldText(tester, 'group-capacity'), '12');
      expect(find.text('No Dates Selected Yet'), findsOneWidget);
      expect(find.text('Select a Date'), findsOneWidget);
      expect(
        find.text('Publish opens registration right away. A draft stays invisible until you publish it.'),
        findsOneWidget,
      );

      await submit(tester, 'Save as Draft');
      expect(
        find.text('Some details need fixing before this can be saved. They are highlighted below.'),
        findsOneWidget,
      );
      expect(find.text('Give the session a title.'), findsOneWidget);
      await typeKey(tester, 'group-title', 'Talk');
      expect(find.text('Use at least 5 characters.'), findsOneWidget);
      await typeKey(tester, 'group-title', 'From site to portfolio: an open clinic');
      expect(find.text('What people see when they browse the session list. · 38/160'), findsOneWidget);
      await typeKey(tester, 'group-link', 'not a link');
      expect(find.text('Enter a full link, starting with https://'), findsOneWidget);
      await typeKey(tester, 'group-link', '');
      expect(find.text('Add the joining link people will use.'), findsOneWidget);
      await typeKey(tester, 'group-link', 'meet.google.com/abc-defg-hij');
      await typeKey(tester, 'group-outcomes', List.generate(7, (i) => 'Outcome $i').join('\n'));
      expect(find.text('Keep it to 6 lines.'), findsOneWidget);
      await typeKey(tester, 'group-outcomes', 'Read a facilities budget\n\nFrame a portfolio case');
      await typeKey(tester, 'group-capacity', '1');
      expect(find.text('Enter a whole number of seats from 2 to 50.'), findsOneWidget);
      await typeKey(tester, 'group-capacity', '25');
      await submit(tester, 'Save as Draft');
      expect(api.count('POST /mentorship/group-sessions'), 0, reason: 'nothing is sent without a date');

      await tapKey(tester, 'cal-2026-10-27');
      expect(find.text('1 Date'), findsOneWidget);
      expect(find.text('Tue, 27 Oct · 6:00 PM–7:00 PM'), findsOneWidget);
      expect(find.text('Free in your calendar'), findsOneWidget);
      expect(find.text('Tuesday, 27 October 2026'), findsOneWidget, reason: 'the day in view');
      expect(find.text('This session · free in your calendar'), findsOneWidget);
      expect(find.text('Your usual hours: 5:00 PM–9:00 PM'), findsOneWidget);

      await typeKey(tester, 'group-summary', 'An hour on how to frame a portfolio case.');
      expect(find.text('41/500'), findsOneWidget);
      await typeKey(tester, 'group-agenda', 'Bring a real case.\n\nWe start with scope.');
      await tapKey(tester, 'group-topics');
      await tapKey(tester, 'topic-Facility Management');
      await tapKey(tester, 'topic-Workplace Strategy');
      await tapKey(tester, 'topics-done');
      expect(find.text('2 selected'), findsOneWidget);
      expect(find.byKey(const ValueKey('topic-chip-Workplace Strategy')), findsOneWidget);

      await submit(tester, 'Save as Draft');
      expect(api.bodyOf('POST /mentorship/group-sessions'), {
        'title': 'From site to portfolio: an open clinic',
        'summary': 'An hour on how to frame a portfolio case.',
        'outcomes': ['Read a facilities budget', 'Frame a portfolio case'],
        'agendaHtml': '<p>Bring a real case.</p><p>We start with scope.</p>',
        'coverUrl': null,
        'mode': 'VIDEO',
        'meetingLink': 'https://meet.google.com/abc-defg-hij',
        'timezone': 'Asia/Kolkata',
        'capacity': 25,
        'waitlistEnabled': true,
        'competencies': ['Facility Management', 'Workplace Strategy'],
        'pricePaisa': null,
        'publish': false,
        'occurrences': [
          {'title': null, 'scheduledAt': _kolkata(10, 27), 'durationMin': 60},
        ],
      });
      expect(results, [true]);
      expect(find.text('Host a Group Session'), findsNothing, reason: 'the composer closed');
    });

    testWidgets('Publish opens it in the same call; the length chips, a day\'s own time and the start time', (
      tester,
    ) async {
      final (api, _, _) = await pumpComposer(tester, OfferingsWorld(sessions: []));
      await typeKey(tester, 'group-title', 'A two-evening bootcamp');
      await tapKey(tester, 'cal-2026-10-27');
      await tapKey(tester, 'cal-2026-10-29');
      expect(find.text('2 Dates · 27 Oct – 29 Oct'), findsOneWidget);
      expect(find.text('How People Register'), findsOneWidget, reason: 'several new dates ask how people register');
      await tapKey(tester, 'length-90');
      expect(find.text('Tue, 27 Oct · 6:00 PM–7:30 PM'), findsOneWidget);
      expect(find.text('Thu, 29 Oct · 6:00 PM–7:30 PM'), findsOneWidget);

      // Day 2 runs shorter: its own length, from its own sheet.
      await tapKey(tester, 'date-time-1');
      expect(find.text('Day 2 · Its Own Time'), findsOneWidget);
      await tapKey(tester, 'row-length-45');
      await tapKey(tester, 'row-time-done');
      expect(find.text('Thu, 29 Oct · 6:00 PM–6:45 PM'), findsOneWidget);

      // The shared start time moves every open date: 7:30 PM, typed into the clock's keyboard mode.
      await tapKey(tester, 'group-start-time');
      await tester.tap(find.byIcon(Icons.keyboard_outlined));
      await tester.pumpAndSettle();
      final fields = find.descendant(of: find.byType(Dialog), matching: find.byType(TextField));
      await tester.enterText(fields.at(0), '7');
      await tester.enterText(fields.at(1), '30');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('7:30 PM'), findsOneWidget);
      expect(find.text('Tue, 27 Oct · 7:30 PM–9:00 PM'), findsOneWidget);
      expect(find.text('Thu, 29 Oct · 7:30 PM–8:15 PM'), findsOneWidget);

      await typeKey(tester, 'date-topic-0', 'Before the keys');
      await submit(tester, 'Publish');
      final body = api.bodyOf('POST /mentorship/group-sessions') as Map;
      expect(body['publish'], isTrue);
      expect(body['occurrences'], [
        {'title': 'Before the keys', 'scheduledAt': _kolkata(10, 27, hour: 19, minute: 30), 'durationMin': 90},
        {'title': null, 'scheduledAt': _kolkata(10, 29, hour: 19, minute: 30), 'durationMin': 45},
      ]);
    });

    testWidgets('several dates as separate sessions go through the batch, one draft each', (tester) async {
      final w = OfferingsWorld(sessions: []);
      final (api, c, results) = await pumpComposer(tester, w);
      await typeKey(tester, 'group-title', 'Thursday office hours');
      await tapKey(tester, 'cal-2026-10-29');
      await tapKey(tester, 'cal-2026-11-05');
      expect(find.text('Save as Draft'), findsOneWidget);
      await tapKey(tester, 'registration-separate');
      expect(find.text('Save 2 Drafts'), findsOneWidget);
      expect(find.text('Publish 2 Sessions'), findsOneWidget);
      expect(
        find.text(
          'Each date becomes its own listing. Publish opens registration for all 2. '
          'Drafts stay invisible until you publish each one.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('date-topic-0')), findsNothing, reason: 'a day topic belongs to a series');
      await submit(tester, 'Save 2 Drafts');
      expect(api.count('POST /mentorship/group-sessions'), 0);
      final body = api.bodyOf('POST /mentorship/group-sessions/batch') as Map;
      expect(body['dates'], [
        {'scheduledAt': _kolkata(10, 29), 'durationMin': 60},
        {'scheduledAt': _kolkata(11, 5), 'durationMin': 60},
      ]);
      expect(body.containsKey('occurrences'), isFalse);
      expect(body['publish'], isFalse);
      expect(body['title'], 'Thursday office hours');
      expect(w.batched, hasLength(2));
      expect(results, [true]);
      expect(c.sessions.data, hasLength(2), reason: 'the list is read again');
    });

    testWidgets('Repeat builds the dates from the first one; a series holds ten; a custom repeat', (tester) async {
      await pumpComposer(tester, OfferingsWorld(sessions: []));
      expect(find.text('Select the first session date before setting a recurrence pattern.'), findsOneWidget);
      await tapKey(tester, 'cal-2026-10-27');
      await tapKey(tester, 'group-repeat');
      expect(find.text('Weekly on Tuesday'), findsOneWidget);
      expect(find.text('Every 2 Weeks on Tuesday'), findsOneWidget);
      expect(find.text('Monthly on the Fourth Tuesday'), findsOneWidget);
      await tapKey(tester, 'repeat-weekly');
      expect(find.text('6 Dates · 27 Oct – 1 Dec'), findsOneWidget);
      expect(find.text('Weekly on Tuesday'), findsOneWidget);
      await tapKey(tester, 'repeat-ends-times-more');
      expect(find.text('7 Dates · 27 Oct – 8 Dec'), findsOneWidget);
      for (var i = 0; i < 5; i++) {
        await tapKey(tester, 'repeat-ends-times-more');
      }
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('repeat-ends-times-value'))).data,
        '10',
        reason: 'a series holds ten dates',
      );
      expect(find.text('10 Dates · 27 Oct – 29 Dec'), findsOneWidget);

      await tapKey(tester, 'group-repeat');
      await tapKey(tester, 'repeat-custom');
      expect(find.text('Custom Repeat'), findsOneWidget);
      await tapKey(tester, 'custom-ends-times-less');
      await tapKey(tester, 'custom-ends-times-less');
      await tapKey(tester, 'custom-ends-times-less');
      await tapKey(tester, 'custom-ends-times-less');
      await tapKey(tester, 'custom-weekday-4');
      await tapKey(tester, 'custom-done');
      expect(find.text('Custom: Weekly on Tue, Thu'), findsOneWidget);
      expect(find.text('6 Dates · 27 Oct – 12 Nov'), findsOneWidget);

      // A date taken off by hand: the rule no longer describes the list.
      await tapKey(tester, 'date-remove-1');
      expect(find.text('5 Dates · 27 Oct – 12 Nov'), findsOneWidget);
      expect(find.text('Does Not Repeat'), findsOneWidget);
    });

    testWidgets('the calendar shows what is booked; a date over it is refused; the API\'s clash lands on its day', (
      tester,
    ) async {
      final w = OfferingsWorld(sessions: [])..busy = [busyJson(DateTime.utc(2026, 10, 27, 12, 30), 60)];
      final (api, _, _) = await pumpComposer(
        tester,
        w,
        extra: {
          'POST /mentorship/group-sessions': (_) => (
            409,
            jsonEncode({
              'statusCode': 409,
              'message': 'Day 1 clashes with a paid session with Tanvi Joshi.',
              'code': 'GROUP_DAY_CLASH',
              'day': 1,
              'kind': 'BOOKING',
            }),
          ),
        },
      );
      expect(find.byKey(const ValueKey('cal-dot-2026-10-27')), findsOneWidget);
      for (final t in ['This Session', 'Already Booked', 'Clash']) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      final asked = api.queryOf('GET /mentorship/group-sessions/mine/busy')!;
      expect(asked['from'], '2026-09-23T18:30:00.000Z', reason: 'the month on screen and a week either side');
      expect(asked.containsKey('except'), isFalse);

      await typeKey(tester, 'group-title', 'An open clinic');
      await tapKey(tester, 'cal-2026-10-27');
      expect(
        find.text('Clashes with 1:1 session with Meera Nair, 6:00 PM–7:00 PM. Change the time or remove this date.'),
        findsOneWidget,
      );
      expect(find.text('Day 1 clashes with a booking. Change its time or remove it.'), findsOneWidget);
      expect(find.text('1:1 session with Meera Nair'), findsOneWidget, reason: 'the day in view lists the booking');
      await submit(tester, 'Save as Draft');
      expect(api.count('POST /mentorship/group-sessions'), 0, reason: 'a clash is refused before the API sees it');

      await tapKey(tester, 'cal-2026-10-27');
      await tapKey(tester, 'cal-2026-10-28');
      expect(find.text('Free in your calendar'), findsOneWidget);
      await submit(tester, 'Save as Draft');
      expect(api.count('POST /mentorship/group-sessions'), 1);
      expect(
        find.text('Day 1 clashes with a paid session with Tanvi Joshi.'),
        findsNWidgets(2),
        reason: 'above the buttons, and on the day it names',
      );
      expect(find.text('Host a Group Session'), findsOneWidget, reason: 'the composer stays open');
    });

    testWidgets('a paid seat needs seats and turns the waitlist off; the price is whole rupees from ₹1', (
      tester,
    ) async {
      final (api, _, _) = await pumpComposer(tester, OfferingsWorld(sessions: []));
      await typeKey(tester, 'group-title', 'Panel interview masterclass');
      await tapKey(tester, 'cal-2026-10-27');
      expect(find.byKey(const ValueKey('group-waitlist')), findsOneWidget);
      await tapKey(tester, 'group-price-paid');
      expect(find.byKey(const ValueKey('group-waitlist')), findsNothing, reason: 'a paid session keeps no waitlist');
      expect(find.text('At least ₹1. GST is added at checkout.'), findsOneWidget);
      await submit(tester, 'Save as Draft');
      expect(find.text('Enter a price per seat.'), findsOneWidget);
      await typeKey(tester, 'group-price', '99.5');
      expect(find.text('Enter the price in whole rupees.'), findsOneWidget);
      await typeKey(tester, 'group-price', '0');
      expect(find.text('Between ₹1 and ₹50,000.'), findsOneWidget);
      await typeKey(tester, 'group-price', '50001');
      expect(find.text('Between ₹1 and ₹50,000.'), findsOneWidget);
      await typeKey(tester, 'group-price', '250');
      expect(find.text('ICR keeps 20%. You receive ₹200 per seat.'), findsOneWidget);
      await tapKey(tester, 'group-capped');
      await submit(tester, 'Save as Draft');
      expect(find.text('A paid session needs a number of seats.'), findsOneWidget);
      expect(api.count('POST /mentorship/group-sessions'), 0);
      await tapKey(tester, 'group-capped');
      await typeKey(tester, 'group-capacity', '15');
      await submit(tester, 'Save as Draft');
      final body = api.bodyOf('POST /mentorship/group-sessions') as Map;
      expect(body['pricePaisa'], 25000);
      expect(body['capacity'], 15);
      expect(body['waitlistEnabled'], isFalse);
    });

    testWidgets('no seat limit is sent as null, and the waitlist switch goes with it', (tester) async {
      final (api, _, _) = await pumpComposer(tester, OfferingsWorld(sessions: []));
      await typeKey(tester, 'group-title', 'An open clinic');
      await tapKey(tester, 'cal-2026-10-27');
      await tapKey(tester, 'group-waitlist');
      await tapKey(tester, 'group-capped');
      expect(find.byKey(const ValueKey('group-capacity')), findsNothing);
      expect(find.byKey(const ValueKey('group-waitlist')), findsNothing);
      await submit(tester, 'Save as Draft');
      final body = api.bodyOf('POST /mentorship/group-sessions') as Map;
      expect(body.containsKey('capacity'), isTrue);
      expect(body['capacity'], isNull);
      expect(body['waitlistEnabled'], isFalse, reason: 'switched off before the limit went');
    });

    testWidgets('while the storefront is closed a seat cannot be priced, and it says why', (tester) async {
      await pumpComposer(tester, OfferingsWorld(sessions: [], accepted: null));
      expect(
        find.text(
          'Accept the seller terms to open your storefront. '
          'Charging for seats needs the same seller terms as the rest of your storefront.',
        ),
        findsOneWidget,
      );
      await tapKey(tester, 'group-price-paid');
      expect(find.byKey(const ValueKey('group-price')), findsNothing, reason: 'Paid stays off');
    });

    testWidgets('a cover is uploaded as a group-session image; one over 2 MB is refused before it is sent', (
      tester,
    ) async {
      var big = true;
      final (api, _, _) = await pumpComposer(
        tester,
        OfferingsWorld(sessions: []),
        pickFile: ({required bool imageOnly}) async => big
            ? PickedUpload(bytes: Uint8List(3 * 1024 * 1024), name: 'cover.png', mimeType: 'image/png')
            : pdfFile(name: 'cover.png'),
      );
      await tapKey(tester, 'group-cover');
      expect(find.text('The image is larger than 2 MB.'), findsOneWidget);
      expect(api.count('POST /uploads'), 0);
      big = false;
      await tapKey(tester, 'group-cover');
      expect(api.queryOf('POST /uploads')!['purpose'], 'group-session');
      expect(find.text('Replace Image'), findsOneWidget);
      await typeKey(tester, 'group-title', 'An open clinic');
      await tapKey(tester, 'cal-2026-10-27');
      await submit(tester, 'Save as Draft');
      expect((api.bodyOf('POST /mentorship/group-sessions') as Map)['coverUrl'], '/uploads/group-session-stored.pdf');
    });

    testWidgets('an in-person session needs a venue in place of the joining link', (tester) async {
      final (api, _, _) = await pumpComposer(tester, OfferingsWorld(sessions: []));
      await typeKey(tester, 'group-title', 'A site visit morning');
      await tapKey(tester, 'cal-2026-10-27');
      await tapKey(tester, 'group-format');
      await tester.tap(find.text('In Person').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('group-link')), findsNothing);
      await submit(tester, 'Save as Draft');
      expect(find.text('Add the venue where people will meet.'), findsOneWidget);
      expect(api.count('POST /mentorship/group-sessions'), 0);
      await typeKey(tester, 'group-venue', 'Prestige Tech Park, Bengaluru');
      await submit(tester, 'Save as Draft');
      final body = api.bodyOf('POST /mentorship/group-sessions') as Map;
      expect(body['mode'], 'IN_PERSON');
      expect(body['location'], 'Prestige Tech Park, Bengaluru');
      expect(
        body['meetingLink'],
        'https://meet.google.com/icr-standing',
        reason: 'the website sends the filled-in link whatever the format',
      );
    });

    testWidgets('a new session starts from the mentor\'s stored defaults: seats, length and waitlist', (tester) async {
      final w = OfferingsWorld(sessions: [])..mentorProfile = mentorMeJson(seats: 20, durationMin: 45, waitlist: false);
      await pumpComposer(tester, w);
      expect(_fieldText(tester, 'group-capacity'), '20');
      expect(tester.widget<Switch>(find.byKey(const ValueKey('group-waitlist'))).value, isFalse);
      await tapKey(tester, 'cal-2026-10-27');
      expect(find.text('Tue, 27 Oct · 6:00 PM–6:45 PM'), findsOneWidget);
    });

    testWidgets('running a session again copies everything but its dates, and saves a new draft', (tester) async {
      final past = HostedSession.fromJson({
        ...hostedJson(
          'grp-past',
          title: 'Reading an SLA',
          status: 'COMPLETED',
          at: offeringsNow.subtract(const Duration(days: 12)),
        ),
        'outcomes': ['Spot the penalty clause'],
      });
      final (api, _, _) = await pumpComposer(tester, OfferingsWorld(sessions: []), copyFrom: past);
      expect(find.text('Host a Group Session'), findsOneWidget);
      expect(_fieldText(tester, 'group-title'), 'Reading an SLA');
      expect(_fieldText(tester, 'group-outcomes'), 'Spot the penalty clause');
      expect(
        find.byKey(const ValueKey('date-undated-0')),
        findsOneWidget,
        reason: 'the day is copied without its date',
      );
      await tapKey(tester, 'cal-2026-10-28');
      expect(find.byKey(const ValueKey('date-undated-0')), findsNothing);
      expect(find.text('Wed, 28 Oct · 6:00 PM–7:00 PM'), findsOneWidget);
      await submit(tester, 'Save as Draft');
      expect(api.count('PATCH /mentorship/group-sessions/grp-past'), 0);
      final body = api.bodyOf('POST /mentorship/group-sessions') as Map;
      expect(body['title'], 'Reading an SLA');
      expect(body['coverUrl'], '/uploads/cover.jpg');
      expect(body['meetingLink'], 'https://meet.google.com/icr-demo');
      expect(body['occurrences'], [
        {'title': null, 'scheduledAt': _kolkata(10, 28), 'durationMin': 60},
      ]);
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

    testWidgets('editing keeps what the API would otherwise blank: days, cover, zone, topics, outcomes, waitlist', (
      tester,
    ) async {
      final w = OfferingsWorld(
        sessions: [
          {
            ...hostedJson('grp-clinic', taken: 2, attendees: roster),
            'outcomes': ['Frame a portfolio case'],
            'waitlistEnabled': true,
          },
        ],
      );
      final (api, _) = await pumpOfferings(tester, w);
      await openOfferingsTab(tester, 'Group Mentoring');
      await tapIn(tester, 'session-grp-clinic', 'Details');
      await tapKey(tester, 'session-edit');
      expect(find.text('Edit Group Session'), findsOneWidget);
      expect(_fieldText(tester, 'group-title'), 'From site to portfolio: an open clinic');
      expect(_fieldText(tester, 'group-agenda'), 'Bring a real case.\n\nWe start with scope.');
      expect(_fieldText(tester, 'group-link'), 'https://meet.google.com/icr-demo');
      expect(_fieldText(tester, 'group-capacity'), '25');
      expect(_fieldText(tester, 'group-outcomes'), 'Frame a portfolio case');
      expect(find.text('Save Changes'), findsOneWidget);
      expect(find.byKey(const ValueKey('composer-secondary')), findsNothing, reason: 'it is already published');
      expect(find.text('Moving the date re-sends the reminders to everyone registered.'), findsOneWidget);
      expect(find.text('One registration covers every date · 2 registered.'), findsOneWidget);
      expect(find.byKey(const ValueKey('registration-separate')), findsNothing, reason: 'an edit stays one series');
      expect(
        api.queryOf('GET /mentorship/group-sessions/mine/busy')!['except'],
        'grp-clinic',
        reason: 'its own days are not its clashes',
      );
      await typeKey(tester, 'group-title', 'Portfolio clinic, second edition');
      await submit(tester, 'Save Changes');
      expect(api.bodyOf('PATCH /mentorship/group-sessions/grp-clinic'), {
        'title': 'Portfolio clinic, second edition',
        'summary': 'An hour on how to frame a portfolio case.',
        'outcomes': ['Frame a portfolio case'],
        'agendaHtml': '<p>Bring a real case.</p><p>We start with scope.</p>',
        'coverUrl': '/uploads/cover.jpg',
        'mode': 'VIDEO',
        'meetingLink': 'https://meet.google.com/icr-demo',
        'timezone': 'Asia/Kolkata',
        'capacity': 25,
        'waitlistEnabled': true,
        'competencies': ['Career transitions'],
        'pricePaisa': null,
        'publish': false,
        'occurrences': [
          {
            'id': 'grp-clinic-occ1',
            'title': null,
            'scheduledAt': iso(offeringsNow.add(const Duration(days: 6))),
            'durationMin': 60,
          },
        ],
      });
      expect(find.text('Saved.'), findsOneWidget);
      expect(find.text('Portfolio clinic, second edition'), findsWidgets);
    });

    testWidgets('a day that has run is shown locked and sent back untouched', (tester) async {
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
      expect(find.text('Ran on Fri, 23 Oct. The date cannot change.'), findsOneWidget);
      expect(find.byKey(const ValueKey('date-remove-0')), findsNothing, reason: 'a day that ran cannot be removed');
      expect(find.byKey(const ValueKey('date-time-0')), findsNothing, reason: 'nor moved');
      expect(find.byKey(const ValueKey('date-remove-1')), findsOneWidget);
      expect(
        find.text('One registration covers every date · 1 registered. New dates are added after Day 1.'),
        findsOneWidget,
      );
      // Tapping the day that ran does not take it away.
      await tapKey(tester, 'cal-2026-10-23');
      expect(find.text('Ran on Fri, 23 Oct. The date cannot change.'), findsOneWidget);
      await submit(tester, 'Save Changes');
      final occ = (api.bodyOf('PATCH /mentorship/group-sessions/grp-clinic') as Map)['occurrences'] as List;
      expect(occ, [
        {'id': 'o1', 'title': null, 'scheduledAt': iso(held), 'durationMin': 60},
        {'id': 'o2', 'title': null, 'scheduledAt': iso(next), 'durationMin': 60},
      ]);
    });

    testWidgets('a refused save keeps the composer and shows the API\'s sentence', (tester) async {
      final w = OfferingsWorld(sessions: [hostedJson('grp-clinic', taken: 2, attendees: roster)]);
      final (api, _) = await pumpOfferings(
        tester,
        w,
        extra: {
          'PATCH /mentorship/group-sessions/grp-clinic': (_) =>
              refuse('People have already registered for free — you cannot start charging for this one.'),
        },
      );
      await openOfferingsTab(tester, 'Group Mentoring');
      await tapIn(tester, 'session-grp-clinic', 'Details');
      await tapKey(tester, 'session-edit');
      await tapKey(tester, 'group-price-paid');
      await typeKey(tester, 'group-price', '499');
      await submit(tester, 'Save Changes');
      expect(api.count('PATCH /mentorship/group-sessions/grp-clinic'), 1);
      expect(
        find.text('People have already registered for free — you cannot start charging for this one.'),
        findsOneWidget,
      );
      expect(find.text('Edit Group Session'), findsOneWidget);
      expect(_fieldText(tester, 'group-price'), '499', reason: 'what was typed is kept');
    });

    testWidgets('a paid session with seats sold keeps its price locked', (tester) async {
      final w = OfferingsWorld(
        sessions: [
          hostedJson('grp-paid', title: 'Panel masterclass', price: 29900, capacity: 15, taken: 2, attendees: roster),
        ],
      );
      final (api, _) = await pumpOfferings(tester, w);
      await openOfferingsTab(tester, 'Group Mentoring');
      await tapIn(tester, 'session-grp-paid', 'Details');
      await tapKey(tester, 'session-edit');
      expect(find.text('Seats are already sold at this price.'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const ValueKey('group-price'))).enabled, isFalse);
      await tapKey(tester, 'group-price-free');
      expect(find.byKey(const ValueKey('group-price')), findsOneWidget, reason: 'Free cannot be chosen either');
      await submit(tester, 'Save Changes');
      final body = api.bodyOf('PATCH /mentorship/group-sessions/grp-paid') as Map;
      expect(body['pricePaisa'], 29900);
      expect(body['waitlistEnabled'], isFalse);
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

    testWidgets('a draft is saved as a draft again, or published in the same save', (tester) async {
      final w = OfferingsWorld(
        sessions: [hostedJson('grp-draft', title: 'Salary negotiation circle', status: 'DRAFT')],
      );
      final (api, _) = await pumpOfferings(tester, w);
      await openOfferingsTab(tester, 'Group Mentoring');
      await tapIn(tester, 'session-grp-draft', 'Details');
      await tapKey(tester, 'session-edit');
      expect(find.text('Save as Draft'), findsOneWidget);
      expect(find.text('Save and Publish'), findsOneWidget);
      await submit(tester, 'Save as Draft');
      expect((api.bodyOf('PATCH /mentorship/group-sessions/grp-draft') as Map)['publish'], isFalse);
      expect(find.text('Saved.'), findsOneWidget);
      // The "Saved." note covers the foot of any page for a few seconds: let it go before the composer opens again.
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      await tapKey(tester, 'session-edit');
      await submit(tester, 'Save and Publish');
      expect((api.bodyOf('PATCH /mentorship/group-sessions/grp-draft') as Map)['publish'], isTrue);
      expect(find.text('Open for Registration'), findsWidgets);
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
