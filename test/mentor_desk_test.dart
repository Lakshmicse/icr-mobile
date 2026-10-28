import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/widgets/title_bar.dart';
import 'package:icr_mobile/features/mentor_desk/mentor_desk_controller.dart';
import 'package:icr_mobile/features/mentor_desk/offerings/offerings_panel.dart';
import 'package:icr_mobile/features/mentorship_my/mentoring_clock.dart';
import 'package:icr_mobile/features/mentorship_my/mentoring_models.dart';
import 'package:icr_mobile/features/mentorship_my/pairing_screen.dart';
import 'package:icr_mobile/features/mentorship_my/widgets/kit.dart';
import 'package:icr_mobile/features/mentorship_my/widgets/month_grid.dart';

import 'helpers/fonts.dart';
import 'mentor_desk_fakes.dart';
import 'mentoring_fakes.dart';

final _now = DateTime(2026, 10, 26, 10);

Finder inDialog(String text) => find.descendant(of: find.byType(AlertDialog), matching: find.text(text));

Future<void> openTab(WidgetTester tester, String label) async {
  final tab = find.descendant(of: find.byType(SegmentTabs), matching: find.text(label));
  await tester.ensureVisible(tab);
  await tester.pumpAndSettle();
  await tester.tap(tab);
  await settle(tester);
}

Future<void> tapText(WidgetTester tester, String text, {int index = 0}) async {
  final f = find.text(text).at(index);
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await settle(tester);
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(ValueKey(key));
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await settle(tester);
}

Finder inCard(String key, String text) => find.descendant(of: find.byKey(ValueKey(key)), matching: find.text(text));

void main() {
  setUpAll(loadAppFonts);
  setUp(() => mentoringNow = () => _now);
  tearDown(() => mentoringNow = DateTime.now);

  group('the desk is for a mentor with an approved profile', () {
    testWidgets('a member with no mentor profile is offered to become one, and sees no desk', (tester) async {
      final became = <String>[];
      await pumpDesk(tester, DeskWorld(hasProfile: false), becameMentor: became);
      expect(find.text("You're not a mentor yet"), findsOneWidget);
      expect(find.byType(SegmentTabs), findsNothing);
      await tester.tap(find.text('Become a mentor'));
      expect(became, ['become']);
    });

    testWidgets('an application in review says so, and the button leads back to it', (tester) async {
      final became = <String>[];
      await pumpDesk(tester, DeskWorld(status: 'PENDING'), becameMentor: became);
      expect(find.text('Your application is in review'), findsOneWidget);
      expect(find.text('Status: In review'), findsOneWidget);
      expect(find.byType(SegmentTabs), findsNothing);
      await tester.tap(find.text('See my application'));
      expect(became, ['become']);
    });

    testWidgets('a rejected application shows the reviewer\'s note as written', (tester) async {
      await pumpDesk(tester, DeskWorld(status: 'REJECTED'));
      expect(find.text('Your application was not approved'), findsOneWidget);
      expect(find.text('Please add a second reference.'), findsOneWidget);
      expect(find.text('Change my application'), findsOneWidget);
    });

    testWidgets('a draft is to be finished', (tester) async {
      await pumpDesk(tester, DeskWorld(status: 'DRAFT'));
      expect(find.text('Finish your application'), findsOneWidget);
      expect(find.text('Continue your application'), findsOneWidget);
    });

    testWidgets('a desk that cannot load says why, and Try again reads it again', (tester) async {
      final w = DeskWorld()..offline = true;
      final (api, _) = await pumpDesk(tester, w);
      expect(find.text("Couldn't load your desk"), findsOneWidget);
      expect(find.text('The desk is down.'), findsOneWidget);
      w.offline = false;
      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(find.byType(SegmentTabs), findsOneWidget);
      expect(api.count('GET /mentorship/mentors/me/dashboard'), greaterThanOrEqualTo(2));
    });

    testWidgets('the tabs are the website\'s, with a count on Requests and Work', (tester) async {
      await pumpDesk(tester, DeskWorld());
      final tabs = tester.widget<SegmentTabs>(find.byType(SegmentTabs));
      expect(tabs.labels, [
        'Overview',
        'Requests',
        'Mentees',
        'Calendar',
        'Work',
        'Offerings',
        'Hours',
        'Earnings',
        'Reviews',
        'Settings',
      ]);
      expect(tabs.badges![1], 6, reason: '2 free requests, 3 session requests, 1 programme request');
      expect(tabs.badges![4], 3, reason: 'a problem, a call to close, a move asked');
    });

    testWidgets('the bell opens the notifications', (tester) async {
      final (_, rec) = await pumpDesk(tester, DeskWorld());
      await tester.tap(find.byType(BellButton));
      await tester.pump();
      expect(rec.opened, ['bell']);
    });
  });

  group('Overview', () {
    testWidgets('shows how the mentor stands and what needs them, each line a way in', (tester) async {
      await pumpDesk(tester, DeskWorld());
      expect(find.text('Active mentees'), findsOneWidget);
      expect(find.text('5 of 6'), findsOneWidget);
      expect(find.text('Places open'), findsOneWidget);
      expect(find.text('4.8'), findsOneWidget);
      expect(find.text('14 reviews'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('2 mentoring requests to answer'), findsOneWidget);
      expect(find.text('3 session requests to accept or decline'), findsOneWidget);
      expect(find.text('1 programme request to answer'), findsOneWidget);
      expect(find.text('1 time your mentees asked for to approve'), findsOneWidget);
      expect(find.text('1 problem a buyer reported'), findsOneWidget);
      expect(find.text('1 paid call to confirm held'), findsOneWidget);
      expect(find.text('1 move asked of you'), findsOneWidget);
      await tester.tap(find.text('2 mentoring requests to answer'));
      await settle(tester);
      expect(find.text('MENTORING REQUESTS'), findsOneWidget);
    });

    testWidgets('a line about paid work opens the Work tab', (tester) async {
      await pumpDesk(tester, DeskWorld());
      await tapText(tester, '1 paid call to confirm held');
      expect(find.text('NEEDS YOU'), findsOneWidget);
      expect(find.byKey(const ValueKey('ended-p-ended')), findsOneWidget);
    });

    testWidgets('a time a mentee asked for inside a pairing opens that pairing', (tester) async {
      await pumpDesk(tester, DeskWorld());
      await tapText(tester, '1 time your mentees asked for to approve');
      expect(find.byType(PairingScreen), findsOneWidget);
    });

    testWidgets('Up next shows the next session across every mentee, and opens it', (tester) async {
      await pumpDesk(tester, DeskWorld());
      expect(find.text('Up next'), findsOneWidget);
      expect(find.text('Meera Nair · 45 min · Video call'), findsOneWidget);
      expect(find.text('in 3 days'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('up-next')));
      await settle(tester);
      expect(find.byType(PairingScreen), findsOneWidget);
    });

    testWidgets('the directory switch lists or hides the profile, and goes back when the API refuses', (tester) async {
      final w = DeskWorld();
      var refuseOnce = true;
      final (api, _) = await pumpDesk(
        tester,
        w,
        extra: {
          'PATCH /mentorship/mentors/me/visibility': (o) {
            final v = (o.data as Map<String, dynamic>)['discoverable'] as bool;
            if (!v && refuseOnce) {
              refuseOnce = false;
              return refuse('Could not change your listing. Try again.');
            }
            w.discoverable = v;
            return {'discoverable': v};
          },
        },
      );
      expect(find.text('Listed'), findsOneWidget);
      await tapKey(tester, 'visibility-switch');
      expect(find.text('Could not change your listing. Try again.'), findsOneWidget);
      expect(
        tester.widget<SwitchListTile>(find.byKey(const ValueKey('visibility-switch'))).value,
        isTrue,
        reason: 'the switch goes back',
      );
      await tapKey(tester, 'visibility-switch');
      expect(api.bodyOf('PATCH /mentorship/mentors/me/visibility'), {'discoverable': false});
      expect(find.text('Hidden from the directory.'), findsOneWidget);
      expect(find.text('Not listed'), findsOneWidget);
      await tapKey(tester, 'visibility-switch');
      expect(api.bodyOf('PATCH /mentorship/mentors/me/visibility'), {'discoverable': true});
      expect(find.text('You are listed again.'), findsOneWidget);
      expect(find.text('Listed'), findsOneWidget);
    });

    testWidgets('the profile\'s completeness lists what is missing, and finishing it is the website\'s', (
      tester,
    ) async {
      final (_, rec) = await pumpDesk(tester, DeskWorld());
      expect(find.byKey(const ValueKey('completeness')), findsOneWidget);
      expect(find.text('73%'), findsOneWidget);
      expect(find.text('List your certifications'), findsOneWidget);
      expect(find.text('Add your work history'), findsOneWidget);
      await tapText(tester, 'Finish my profile');
      expect(rec.sites, ['/profile']);
    });

    testWidgets('with every place taken, a request cannot be accepted: the desk says so and points to Settings', (
      tester,
    ) async {
      final w = DeskWorld()..capacity = 1;
      await pumpDesk(tester, w);
      expect(find.textContaining('All 1 of your places are taken'), findsOneWidget);
      await tapText(tester, 'Open Settings');
      expect(find.text('Save settings'), findsOneWidget);
    });

    testWidgets('a paused profile says so, switches the directory control off, and leads back to the application', (
      tester,
    ) async {
      final became = <String>[];
      await pumpDesk(tester, DeskWorld(status: 'PAUSED'), becameMentor: became);
      expect(find.textContaining('Your profile is paused'), findsOneWidget);
      expect(tester.widget<SwitchListTile>(find.byKey(const ValueKey('visibility-switch'))).onChanged, isNull);
      await tapText(tester, 'Review my profile');
      expect(became, ['become']);
    });

    testWidgets('the recent activity lists what happened lately', (tester) async {
      await pumpDesk(tester, DeskWorld());
      expect(find.text('Lately'), findsOneWidget);
      expect(find.byKey(const ValueKey('activity-ev-1')), findsOneWidget);
      expect(find.text('Marked complete by the mentor.'), findsOneWidget);
    });
  });

  group('Requests', () {
    testWidgets('a free mentoring request is accepted with a rhythm and a note, and the place is used', (tester) async {
      final (api, _) = await pumpDesk(tester, DeskWorld(), tab: DeskTab.requests);
      expect(find.text('Isha Verma'), findsWidgets);
      await tester.tap(find.text('Accept').first);
      await settle(tester);
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
      expect(find.text('Accepted'), findsOneWidget, reason: 'it moves to Answered lately');
    });

    testWidgets('declining sends the note as written, and the mentee is told', (tester) async {
      final (api, _) = await pumpDesk(tester, DeskWorld(), tab: DeskTab.requests);
      await tester.tap(find.text('Decline').at(1));
      await settle(tester);
      expect(find.text('Decline Vikram?'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('form-text')), 'Full until the new year');
      await tester.tap(find.text('Decline request'));
      await settle(tester);
      expect(api.bodyOf('POST /mentorship/requests/r-vikram/decline'), {'responseNote': 'Full until the new year'});
      expect(find.textContaining('Declined. Vikram has been told.'), findsOneWidget);
      expect(find.text('Declined'), findsOneWidget);
    });

    testWidgets('a session request is accepted by choosing a suggested time (a star is the mentee\'s own pick)', (
      tester,
    ) async {
      final w = DeskWorld();
      final (api, _) = await pumpDesk(tester, w, tab: DeskTab.requests);
      expect(find.text('Preparing for a facilities head interview'), findsNothing);
      expect(find.textContaining('Preparing for a facilities head interview'), findsOneWidget);
      expect(find.text('Suits them: Weekday evenings'), findsOneWidget);
      await tester.ensureVisible(inCard('sreq-p-req', 'Accept and set time'));
      await tester.tap(inCard('sreq-p-req', 'Accept and set time'));
      await settle(tester);
      expect(find.text('Accept Isha Verma'), findsOneWidget);
      expect(find.text('Suggested times'), findsOneWidget);
      await tester.tap(find.text('Accept').last);
      await tester.pump();
      expect(find.text('Pick a time first.'), findsOneWidget);
      final first = find.byKey(ValueKey('suggest-${iso(DateTime(2026, 10, 28, 18))}'));
      expect(find.descendant(of: first, matching: find.textContaining('★')), findsOneWidget);
      await tester.tap(first);
      await tester.pump();
      await tester.tap(find.text('Accept').last);
      await settle(tester);
      expect(api.bodyOf('POST /mentor-services/purchases/p-req/accept'), {
        'scheduledAt': iso(DateTime(2026, 10, 28, 18)),
      });
      expect(find.text('Time set. Isha Verma confirms it and pays.'), findsOneWidget);
      expect(find.byKey(const ValueKey('sreq-p-req')), findsNothing);
      expect(find.byKey(const ValueKey('held-p-req')), findsOneWidget, reason: 'it now waits on the mentee');
    });

    testWidgets('a free session is booked at once, and a time of the mentor\'s own can be chosen', (tester) async {
      final (api, _) = await pumpDesk(tester, DeskWorld(), tab: DeskTab.requests);
      await tester.ensureVisible(inCard('sreq-p-free', 'Accept and set time'));
      await tester.tap(inCard('sreq-p-free', 'Accept and set time'));
      await settle(tester);
      expect(find.text('Accept and book'), findsOneWidget);
      expect(find.text('It is booked on both calendars at once.'), findsOneWidget);
      await tester.tap(find.text('Pick a day and time'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Accept and book'));
      await settle(tester);
      final at = DateTime.parse(
        (api.bodyOf('POST /mentor-services/purchases/p-free/accept') as Map)['scheduledAt'] as String,
      ).toLocal();
      expect(at.day, 27, reason: 'the pickers open on tomorrow');
      expect(find.text('Booked. Vikram Singh has been told.'), findsOneWidget);
    });

    testWidgets('the whole of the mentor\'s free hours can be opened, and a refusal keeps the sheet', (tester) async {
      final (api, _) = await pumpDesk(
        tester,
        DeskWorld(),
        tab: DeskTab.requests,
        extra: {
          'POST /mentor-services/purchases/p-req/accept': (_) => refuse(
            'The mentor already has a session booked around that time — pick a slot that does not overlap it.',
          ),
        },
      );
      await tester.ensureVisible(inCard('sreq-p-req', 'Accept and set time'));
      await tester.tap(inCard('sreq-p-req', 'Accept and set time'));
      await settle(tester);
      await tapKey(tester, 'see-all-slots');
      expect(api.queryOf('GET /mentorship/mentors/mp-anand/slots'), {'durationMin': 45, 'days': 14});
      expect(find.text('Hide the full list'), findsOneWidget);
      await tester.tap(find.text('7:00 PM'));
      await tester.pump();
      await tester.tap(find.text('Accept').last);
      await settle(tester);
      expect(find.textContaining('The mentor already has a session booked'), findsOneWidget);
      expect(find.text('Accept Isha Verma'), findsOneWidget, reason: 'the sheet stays open');
    });

    testWidgets('a mentee who sent a time back is heard in the request and in the sheet', (tester) async {
      await pumpDesk(tester, DeskWorld(), tab: DeskTab.requests);
      expect(find.textContaining('Asked for another time (25 Oct): Evenings after 7 suit me better.'), findsOneWidget);
      await tester.ensureVisible(inCard('sreq-p-asked-again', 'Accept and set time'));
      await tester.tap(inCard('sreq-p-asked-again', 'Accept and set time'));
      await settle(tester);
      expect(find.textContaining('Sana Qureshi asked for another time'), findsOneWidget);
    });

    testWidgets('declining a session needs a reason of five characters, which the mentee reads', (tester) async {
      final (api, _) = await pumpDesk(tester, DeskWorld(), tab: DeskTab.requests);
      await tester.ensureVisible(inCard('sreq-p-req', 'Decline'));
      await tester.tap(inCard('sreq-p-req', 'Decline'));
      await settle(tester);
      await tester.enterText(find.byKey(const ValueKey('form-text')), 'No');
      await tester.tap(find.text('Send decline'));
      await tester.pump();
      expect(find.text('Write at least 5 characters.'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('form-text')), 'I am travelling that month');
      await tester.tap(find.text('Send decline'));
      await settle(tester);
      expect(api.bodyOf('POST /mentor-services/purchases/p-req/decline'), {'reason': 'I am travelling that month'});
      expect(find.byKey(const ValueKey('sreq-p-req')), findsNothing);
    });

    testWidgets('Message on a request opens the thread through the purchase', (tester) async {
      final (api, rec) = await pumpDesk(
        tester,
        DeskWorld(),
        tab: DeskTab.requests,
        extra: {
          'POST /mentor-services/purchases/p-req/conversation': (_) => {'conversationId': 'conv-p-req'},
        },
      );
      await tester.ensureVisible(inCard('sreq-p-req', 'Message'));
      await tester.tap(inCard('sreq-p-req', 'Message'));
      await settle(tester);
      expect(api.count('POST /mentor-services/purchases/p-req/conversation'), 1);
      expect(rec.opened, ['conversation:conv-p-req']);
    });

    testWidgets('a time the mentee has not answered can be withdrawn: it cancels the request, after asking', (
      tester,
    ) async {
      final (api, _) = await pumpDesk(tester, DeskWorld(), tab: DeskTab.requests);
      expect(find.byKey(const ValueKey('held-p-held')), findsOneWidget);
      await tester.ensureVisible(inCard('held-p-held', 'Withdraw this time'));
      await tester.tap(inCard('held-p-held', 'Withdraw this time'));
      await tester.pumpAndSettle();
      expect(find.text('Withdraw this time?'), findsOneWidget);
      await tester.tap(inDialog('Keep it'));
      await tester.pumpAndSettle();
      expect(api.count('POST /mentor-services/purchases/p-held/withdraw'), 0, reason: 'keeping it sends nothing');
      await tester.tap(inCard('held-p-held', 'Withdraw this time'));
      await tester.pumpAndSettle();
      await tester.tap(inDialog('Withdraw'));
      await settle(tester);
      expect(api.count('POST /mentor-services/purchases/p-held/withdraw'), 1);
      expect(find.text('Request withdrawn.'), findsOneWidget);
      expect(find.byKey(const ValueKey('held-p-held')), findsNothing);
    });

    testWidgets('a programme request is accepted (nothing is charged yet) or declined with a reason', (tester) async {
      final w = DeskWorld();
      final (api, _) = await pumpDesk(tester, w, tab: DeskTab.requests);
      expect(find.text('Programme · 3 sessions · ₹5,999'), findsOneWidget);
      await tester.ensureVisible(inCard('term-t-prog', 'Accept'));
      await tester.tap(inCard('term-t-prog', 'Accept'));
      await settle(tester);
      expect(api.bodyOf('POST /mentor-plans/subscriptions/t-prog/decide'), {'decision': 'ACCEPT'});
      expect(find.text('Accepted. They can now pay to start.'), findsOneWidget);
      expect(find.byKey(const ValueKey('unpaid-t-prog')), findsOneWidget);
      expect(find.byKey(const ValueKey('term-t-prog')), findsNothing);
    });

    testWidgets('declining a programme request needs a reason the buyer reads', (tester) async {
      final (api, _) = await pumpDesk(tester, DeskWorld(), tab: DeskTab.requests);
      await tester.ensureVisible(inCard('term-t-prog', 'Decline'));
      await tester.tap(inCard('term-t-prog', 'Decline'));
      await settle(tester);
      await tester.enterText(find.byKey(const ValueKey('form-text')), 'full');
      await tester.tap(find.text('Send decline'));
      await tester.pump();
      expect(find.text('Write at least 5 characters.'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('form-text')), 'My programme places are full');
      await tester.tap(find.text('Send decline'));
      await settle(tester);
      expect(api.bodyOf('POST /mentor-plans/subscriptions/t-prog/decide'), {
        'decision': 'DECLINE',
        'reason': 'My programme places are full',
      });
      expect(find.byKey(const ValueKey('term-t-prog')), findsNothing);
    });

    testWidgets('an accepted programme waits on the buyer, who pays on the website', (tester) async {
      await pumpDesk(tester, DeskWorld(), tab: DeskTab.requests);
      expect(find.text('Accepted, waiting for payment'.toUpperCase()), findsOneWidget);
      expect(find.text('They pay on the website; the mentorship starts when they do.'), findsOneWidget);
    });

    testWidgets('with nothing asked, the tab says so', (tester) async {
      final w = DeskWorld()
        ..freeRequests = []
        ..sold = []
        ..terms = [];
      await pumpDesk(tester, w, tab: DeskTab.requests);
      expect(find.text('Nothing is waiting on you'), findsOneWidget);
    });

    testWidgets('a failed read says why and Try again reads it again', (tester) async {
      final w = DeskWorld();
      var fail = true;
      final (api, _) = await pumpDesk(
        tester,
        w,
        tab: DeskTab.requests,
        extra: {
          'GET /mentorship/requests/incoming': (_) =>
              fail ? refuse('We could not reach the requests.', status: 500) : page(w.freeRequests),
          'GET /mentor-services/purchases/mine': (_) =>
              fail ? refuse('We could not reach the requests.', status: 500) : page(w.sold),
          'GET /mentor-plans/subscriptions/sold': (_) =>
              fail ? refuse('We could not reach the requests.', status: 500) : w.terms,
        },
      );
      expect(find.text("Couldn't load your requests"), findsOneWidget);
      fail = false;
      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(find.text("Couldn't load your requests"), findsNothing);
      expect(api.count('GET /mentorship/requests/incoming'), greaterThanOrEqualTo(2));
    });
  });

  group('Mentees', () {
    testWidgets('lists the live mentees and the finished ones, and opens a pairing', (tester) async {
      await pumpDesk(tester, DeskWorld(), tab: DeskTab.mentees);
      expect(find.text('MENTORING NOW (1)'), findsOneWidget);
      expect(find.text('Meera Nair'), findsOneWidget);
      expect(find.text('FINISHED (1)'), findsOneWidget);
      expect(find.text('Tanvi Joshi'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('mentee-pair-meera')));
      await settle(tester);
      expect(find.byType(PairingScreen), findsOneWidget);
    });

    testWidgets('Message opens the pairing\'s thread through the record', (tester) async {
      final (api, rec) = await pumpDesk(
        tester,
        DeskWorld(),
        tab: DeskTab.mentees,
        extra: {
          'POST /mentorship/pair-meera/conversation': (_) => {'conversationId': 'conv-meera'},
        },
      );
      await tester.tap(find.text('Message'));
      await settle(tester);
      expect(api.count('POST /mentorship/pair-meera/conversation'), 1);
      expect(rec.opened, ['conversation:conv-meera']);
    });

    testWidgets('with no mentees the tab says when one appears', (tester) async {
      final w = DeskWorld()
        ..roster = []
        ..finished = [];
      await pumpDesk(tester, w, tab: DeskTab.mentees);
      expect(find.text('No mentees yet'), findsOneWidget);
    });
  });

  group('Calendar', () {
    testWidgets(
      'the month marks the days that hold something, across every mentee, and an entry opens its mentorship',
      (tester) async {
        final w = DeskWorld();
        final (api, _) = await pumpDesk(
          tester,
          w,
          tab: DeskTab.calendar,
          extra: {
            'GET /mentorship/sessions': (_) => [
              sessionJson(
                's-29',
                mentorshipId: 'pair-meera',
                at: DateTime(2026, 10, 29, 18, 30),
                side: 'MENTOR',
                agenda: 'Reviewing the scorecard draft',
              ),
            ],
          },
        );
        expect(find.text('October 2026'), findsOneWidget);
        final grid = tester.widget<MonthGrid>(find.byType(MonthGrid));
        expect(grid.marks[29], {CalendarKind.session});
        await tester.tap(find.byKey(const ValueKey('day-29')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Reviewing the scorecard draft'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open mentorship'));
        await settle(tester);
        expect(find.byType(PairingScreen), findsOneWidget);
        expect(api.count('GET /mentorship/sessions'), 1);
      },
    );

    testWidgets('the arrows read the next month', (tester) async {
      final (api, _) = await pumpDesk(tester, DeskWorld(), tab: DeskTab.calendar);
      await tester.tap(find.byTooltip('Next month'));
      await settle(tester);
      expect(find.text('November 2026'), findsOneWidget);
      expect(api.count('GET /mentorship/sessions'), 2);
    });
  });

  group('Offerings', () {
    testWidgets('the tab mounts the offerings panel on the mentor\'s own API client', (tester) async {
      await pumpDesk(tester, DeskWorld(), tab: DeskTab.offerings);
      expect(find.byType(OfferingsPanel), findsOneWidget);
    });
  });
}
