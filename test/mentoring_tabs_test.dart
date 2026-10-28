import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/features/mentorship_my/mentoring_clock.dart';
import 'package:icr_mobile/features/mentorship_my/mentoring_models.dart';
import 'package:icr_mobile/features/mentorship_my/my_mentoring_controller.dart';
import 'package:icr_mobile/features/mentorship_my/widgets/kit.dart';
import 'package:icr_mobile/features/mentorship_my/widgets/month_grid.dart';

import 'helpers/fonts.dart';
import 'mentoring_fakes.dart';

Finder inDialog(String text) => find.descendant(of: find.byType(AlertDialog), matching: find.text(text));

Future<void> openTab(WidgetTester tester, String label) async {
  final tab = find.descendant(of: find.byType(SegmentTabs), matching: find.text(label));
  await tester.ensureVisible(tab);
  await tester.pumpAndSettle();
  await tester.tap(tab);
  await settle(tester);
}

final _neha = personJson(
  'u-neha',
  'Neha',
  'Kapoor',
  headline: 'Workplace Experience Manager at Wipro',
  mentorProfileId: 'mp-neha',
);

Map<String, Reply> _mentorRoutes({List<Object?>? incoming}) => menteeRoutes(
  sent: [],
  pairings: [pairingJson('pair-meera', side: 'MENTOR', mentor: anand, mentee: personJson('u-meera', 'Meera', 'Nair'))],
  summary: summaryJson(asMentor: 1, asMentee: 0, incoming: 1, outgoing: 0, isMentor: true, mentorStatus: 'APPROVED'),
  incoming:
      incoming ??
      [
        requestJson(
          'r-isha',
          mentor: anand,
          mentee: personJson('u-isha', 'Isha', 'Verma', careerStage: 'MID_CAREER'),
          signals: ['Same city'],
        ),
      ],
);

void main() {
  setUpAll(loadAppFonts);

  group('Requests', () {
    testWidgets('a mentee sees what they asked, how long it has, and withdraws one', (tester) async {
      var withdrawn = false;
      final routes = menteeRoutes();
      routes['GET /mentorship/requests/mine'] = (_) => page([
        requestJson('req-neha', status: withdrawn ? 'WITHDRAWN' : 'PENDING', mentor: _neha),
        requestJson(
          'req-old',
          status: 'DECLINED',
          responseNote: 'My cohort is full until the new year.',
          mentor: divya,
        ),
      ]);
      routes['POST /mentorship/requests/req-neha/withdraw'] = (_) {
        withdrawn = true;
        return {'ok': true};
      };
      final (api, rec) = await pumpMyMentoring(tester, routes);
      await openTab(tester, 'Requests');
      expect(find.text('Sent by you'.toUpperCase()), findsOneWidget);
      expect(find.text('You have 1 of 3 open requests on your plan.'), findsOneWidget);
      expect(find.text('Neha Kapoor'), findsOneWidget);
      expect(find.text('Awaiting reply'), findsOneWidget);
      expect(find.textContaining('Lapses in 10 days if nobody answers'), findsOneWidget);
      expect(find.text('Declined'), findsOneWidget);
      expect(find.textContaining('Divya replied: My cohort is full'), findsOneWidget);

      await tester.tap(find.text('View profile'));
      expect(rec.opened, ['mentor:mp-neha']);
      await tester.tap(find.text('Find similar mentors'));
      expect(rec.opened.last, 'directory');

      await tester.tap(find.text('Withdraw'));
      await tester.pumpAndSettle();
      await tester.tap(inDialog('Keep it'));
      await tester.pumpAndSettle();
      expect(api.count('POST /mentorship/requests/req-neha/withdraw'), 0, reason: 'keeping it sends nothing');

      await tester.tap(find.text('Withdraw'));
      await tester.pumpAndSettle();
      await tester.tap(inDialog('Withdraw'));
      await settle(tester);
      expect(api.count('POST /mentorship/requests/req-neha/withdraw'), 1);
      expect(find.text('Request withdrawn.'), findsOneWidget);
      expect(find.text('Awaiting reply'), findsNothing);
      expect(find.text('Withdrawn'), findsOneWidget, reason: 'the list is read again');
    });

    testWidgets('a refused withdrawal says why and leaves the request', (tester) async {
      final routes = menteeRoutes();
      routes['POST /mentorship/requests/req-neha/withdraw'] = (_) => refuse('This request was already answered.');
      await pumpMyMentoring(tester, routes);
      await openTab(tester, 'Requests');
      await tester.tap(find.text('Withdraw'));
      await tester.pumpAndSettle();
      await tester.tap(inDialog('Withdraw'));
      await settle(tester);
      expect(find.text('This request was already answered.'), findsOneWidget);
      expect(find.text('Awaiting reply'), findsOneWidget);
    });

    testWidgets('a mentor answers a request: accept with a rhythm and a note', (tester) async {
      final routes = _mentorRoutes();
      routes['POST /mentorship/requests/r-isha/accept'] = (_) => {'id': 'pair-isha'};
      final (api, _) = await pumpMyMentoring(tester, routes);
      await openTab(tester, 'Requests');
      expect(find.text('ASKED OF YOU'), findsOneWidget);
      expect(find.text('SENT BY YOU'), findsNothing, reason: 'a mentor only sees the mentee side when they are one');
      expect(find.text('Isha Verma'), findsOneWidget);
      expect(find.textContaining('Mid career'), findsOneWidget);

      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();
      expect(find.text('Accept Isha'), findsOneWidget);
      await tester.tap(find.text('Weekly'));
      await tester.enterText(find.byKey(const ValueKey('accept-note')), 'Bring your org chart.');
      await tester.tap(find.text('Accept and start'));
      await settle(tester);
      expect(api.bodyOf('POST /mentorship/requests/r-isha/accept'), {
        'responseNote': 'Bring your org chart.',
        'cadence': 'WEEKLY',
      });
      expect(find.textContaining("You are now Isha's mentor."), findsOneWidget);
    });

    testWidgets('declining sends the note, and a refusal keeps the sheet and what was typed', (tester) async {
      var refuseFirst = true;
      final routes = _mentorRoutes();
      routes['POST /mentorship/requests/r-isha/decline'] = (_) {
        if (refuseFirst) {
          refuseFirst = false;
          return refuse('Could not record your answer. Try again.');
        }
        return {'ok': true};
      };
      final (api, _) = await pumpMyMentoring(tester, routes);
      await openTab(tester, 'Requests');
      await tester.tap(find.text('Decline'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('form-text')), 'Full until the new year, please ask again');
      await tester.tap(find.text('Decline request'));
      await settle(tester);
      expect(find.text('Could not record your answer. Try again.'), findsOneWidget);
      expect(find.text('Full until the new year, please ask again'), findsOneWidget, reason: 'what was typed stays');
      await tester.tap(find.text('Decline request'));
      await settle(tester);
      expect(api.bodyOf('POST /mentorship/requests/r-isha/decline'), {
        'responseNote': 'Full until the new year, please ask again',
      });
      expect(find.textContaining('Declined. Isha has been told.'), findsOneWidget);
    });
  });

  group('Calendar', () {
    Map<String, Reply> calendarRoutes(DateTime day) => {
      ...menteeRoutes(),
      'GET /mentorship/sessions': (_) => [sessionJson('s1', at: day)],
      'GET /mentor-services/bookings/range': (_) => [
        {
          'id': 'b1',
          'purchaseId': 'p1',
          'title': 'Career clarity call',
          'scheduledAt': iso(day.add(const Duration(days: 3))),
          'durationMin': 30,
          'mode': 'VIDEO',
          'status': 'SCHEDULED',
          'meetingLink': null,
          'counterpart': {'id': 'u-anand', 'firstName': 'Anand', 'lastName': 'Iyer'},
        },
      ],
      'GET /mentorship/group-sessions/mine/upcoming': (_) => [],
    };

    DateTime midMonth() {
      final now = mentoringNow();
      return DateTime(now.year, now.month, 15, 12);
    }

    testWidgets('the month marks the days that hold something, and a day shows its agenda', (tester) async {
      final (api, _) = await pumpMyMentoring(tester, calendarRoutes(midMonth()));
      await openTab(tester, 'Calendar');
      expect(api.count('GET /mentorship/sessions'), 1);
      final grid = tester.widget<MonthGrid>(find.byType(MonthGrid));
      expect(grid.marks[15], {CalendarKind.session});
      expect(grid.marks[18], {CalendarKind.booking});
      await tester.tap(find.byKey(const ValueKey('day-15')));
      await tester.pumpAndSettle();
      expect(find.text('Reviewing the scorecard draft'), findsOneWidget);
      expect(find.textContaining('Anand Iyer'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('day-16')));
      await tester.pumpAndSettle();
      expect(find.text('Nothing on this day.'), findsOneWidget);
    });

    testWidgets('an entry opens in full, with Join and the way to its mentorship', (tester) async {
      await pumpMyMentoring(tester, calendarRoutes(midMonth()));
      final urls = launches(tester);
      await openTab(tester, 'Calendar');
      await tester.tap(find.byKey(const ValueKey('day-15')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reviewing the scorecard draft'));
      await tester.pumpAndSettle();
      expect(find.text('MENTORING SESSION'), findsOneWidget);
      expect(find.text('Open mentorship'), findsOneWidget);
      await tester.tap(find.text('Join'));
      await tester.pump();
      expect(urls, ['https://meet.google.com/icr-demo']);
    });

    testWidgets('the arrows read the neighbouring month', (tester) async {
      final (api, _) = await pumpMyMentoring(tester, calendarRoutes(midMonth()));
      await openTab(tester, 'Calendar');
      final now = mentoringNow();
      final first = DateTime(now.year, now.month);
      await tester.tap(find.byTooltip('Next month'));
      await settle(tester);
      final q = api.queryOf('GET /mentorship/sessions')!;
      expect(q['from'], iso(DateTime(first.year, first.month + 1)));
      expect(q['to'], iso(DateTime(first.year, first.month + 2)));
      expect(api.count('GET /mentorship/sessions'), 2);
      await tester.tap(find.byTooltip('Previous month'));
      await settle(tester);
      expect(api.queryOf('GET /mentorship/sessions')!['from'], iso(first));
    });
  });

  group('Goals', () {
    Map<String, Reply> goalRoutes({required Object Function() intent, List<Object?>? goals}) => {
      ...menteeRoutes(),
      'GET /mentorship/mentees/me': (_) => intent(),
      'GET /mentorship/mentors/facets': (_) => {
        'competencies': [
          {'label': 'Career transitions', 'count': 4},
          {'label': 'Workplace leadership', 'count': 2},
        ],
      },
      'GET /mentorship/goals/mine': (_) =>
          goals ??
          [goalJson('g1'), goalJson('g3', title: 'Understand SLA reporting', status: 'ACHIEVED', progress: 100)],
    };

    testWidgets('shows the goals across the pairings, open ones first', (tester) async {
      await pumpMyMentoring(tester, goalRoutes(intent: () => ''));
      await openTab(tester, 'Goals');
      expect(find.text('Lead my first site audit on my own'), findsOneWidget);
      expect(find.text('Understand SLA reporting'), findsOneWidget);
      expect(find.text('FINISHED OR DROPPED'), findsOneWidget);
      expect(find.textContaining('40% · by'), findsOneWidget);
      expect(find.text('Set it up'), findsOneWidget, reason: 'no intent written yet');
    });

    testWidgets('what the member wants from mentoring is saved as the API wants it, and shown', (tester) async {
      Map<String, Object?>? held;
      late FakeApi api;
      final routes = goalRoutes(intent: () => held ?? '', goals: []);
      routes['PUT /mentorship/mentees/me'] = (o) {
        held = {...(o.data as Map<String, dynamic>)};
        return {'ok': true};
      };
      (api, _) = await pumpMyMentoring(tester, routes, height: 2600);
      await openTab(tester, 'Goals');
      await tester.tap(find.text('Set it up'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Tell us where you are in your career first.'), findsOneWidget);
      await tester.tap(find.text('Mid career'));
      await tester.tap(find.text('Career transitions'));
      await tester.tap(find.text('Video call'));
      await tester.tap(find.text('Monthly'));
      await tester.enterText(find.byKey(const ValueKey('intent-goal')), 'Move from a site to a portfolio.');
      await tester.tap(find.text('Save'));
      await settle(tester);
      expect(api.bodyOf('PUT /mentorship/mentees/me'), {
        'careerStage': 'MID_CAREER',
        'focusAreas': ['Career transitions'],
        'goalSummary': 'Move from a site to a portfolio.',
        'preferredModes': ['VIDEO'],
        'cadence': 'MONTHLY',
        'timezone': 'Asia/Kolkata',
        'discoverable': true,
      });
      expect(find.text('What you want from mentoring'), findsOneWidget);
      expect(find.text('Mid career'), findsOneWidget);
      expect(find.text('Move from a site to a portfolio.'), findsOneWidget);
      expect(find.text('Visible to mentors'), findsOneWidget);
    });
  });

  group('Saved', () {
    testWidgets('lists the shortlist, opens a profile and takes one off', (tester) async {
      var removed = false;
      final routes = {
        ...menteeRoutes(),
        'GET /mentorship/mentors/saved': (_) => page(
          removed
              ? []
              : [
                  {
                    'id': 'mp-anand',
                    'headline': 'Head of Facilities Strategy at Prestige Group',
                    'rating': 4.8,
                    'ratingCount': 14,
                    'openSlots': 2,
                    'city': 'Bengaluru',
                    'user': {'id': 'u-anand', 'firstName': 'Anand', 'lastName': 'Iyer', 'avatarUrl': null},
                  },
                ],
        ),
        'DELETE /mentorship/mentors/mp-anand/save': (_) {
          removed = true;
          return {'saved': false};
        },
      };
      final (api, rec) = await pumpMyMentoring(tester, routes);
      await openTab(tester, 'Saved');
      expect(find.text('Anand Iyer'), findsOneWidget);
      expect(find.text('4.8 · 14 reviews'), findsOneWidget);
      expect(find.text('2 open mentoring slots'), findsOneWidget);
      await tester.tap(find.text('View profile'));
      expect(rec.opened, ['mentor:mp-anand']);
      await tester.tap(find.text('Remove'));
      await settle(tester);
      expect(api.count('DELETE /mentorship/mentors/mp-anand/save'), 1);
      expect(find.text('Nothing saved yet'), findsOneWidget);
      expect(find.text('Anand removed from your list.'), findsOneWidget);
    });

    testWidgets('an empty list sends the member to the directory', (tester) async {
      final routes = {...menteeRoutes(), 'GET /mentorship/mentors/saved': (_) => page([])};
      final (_, rec) = await pumpMyMentoring(tester, routes);
      await openTab(tester, 'Saved');
      await tester.tap(find.text('Browse mentors'));
      expect(rec.opened, ['directory']);
    });
  });

  group('Certificates', () {
    testWidgets('a certificate opens in full and is verified on the website by its number', (tester) async {
      final routes = {
        ...menteeRoutes(),
        'GET /mentorship/mine/certificates': (_) => [certificateJson()],
      };
      final (_, rec) = await pumpMyMentoring(tester, routes);
      await openTab(tester, 'Certificates');
      expect(find.text('Mentoring completion certificate'), findsOneWidget);
      await tester.tap(find.text('Mentoring completion certificate'));
      await tester.pumpAndSettle();
      expect(find.text('ICR-MENTEE-2026-BHARATXX'), findsOneWidget);
      expect(find.textContaining('5 sessions · 3.75 hr'), findsOneWidget);
      await tester.tap(find.text('Verify online'));
      await tester.pump();
      expect(rec.sites, ['/mentorship/certificates/ICR-MENTEE-2026-BHARATXX']);
    });

    testWidgets('none yet says when one is issued', (tester) async {
      final routes = {...menteeRoutes(), 'GET /mentorship/mine/certificates': (_) => []};
      await pumpMyMentoring(tester, routes);
      await openTab(tester, 'Certificates');
      expect(find.text('No certificates yet'), findsOneWidget);
    });
  });

  group('Reports', () {
    testWidgets('the tab is there once a concern was raised, with what ICR told them', (tester) async {
      final routes = {
        ...menteeRoutes(),
        'GET /mentorship/concerns/mine': (_) => [concernJson()],
      };
      final (api, _) = await pumpMyMentoring(tester, routes, tab: MyTab.reports);
      expect(tester.widget<SegmentTabs>(find.byType(SegmentTabs)).labels, contains('Reports'));
      expect(api.count('GET /mentorship/concerns/mine'), 1);
      expect(find.text('Not responding'), findsOneWidget);
      expect(find.text('Acted on'), findsOneWidget);
      expect(find.text('We spoke to the mentor and a session is booked.'), findsOneWidget);
      expect(find.text('FROM ICR'), findsOneWidget);
    });
  });

  testWidgets('a mentor who is not also a mentee has no Saved, Purchases or Goals tab', (tester) async {
    await pumpMyMentoring(tester, _mentorRoutes(incoming: []));
    final tabs = tester.widget<SegmentTabs>(find.byType(SegmentTabs)).labels;
    expect(tabs, ['Mentoring', 'Requests', 'Calendar', 'Certificates']);
    expect(find.text('Your mentees'), findsOneWidget);
  });
}
