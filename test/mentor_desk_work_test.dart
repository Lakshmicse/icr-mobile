import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/features/mentor_desk/desk_setup_tabs.dart';
import 'package:icr_mobile/features/mentor_desk/mentor_desk_controller.dart';
import 'package:icr_mobile/features/mentor_desk/mentor_desk_models.dart';
import 'package:icr_mobile/features/mentor_desk/mentor_desk_repository.dart';
import 'package:icr_mobile/features/mentorship_my/mentoring_clock.dart';
import 'package:icr_mobile/features/mentorship_my/pairing_screen.dart';
import 'package:icr_mobile/features/mentorship_my/widgets/kit.dart';

import 'helpers/fonts.dart';
import 'mentor_desk_fakes.dart';
import 'mentoring_fakes.dart';

final _now = DateTime(2026, 10, 26, 10);

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

Future<void> tapIn(WidgetTester tester, String key, String text) async {
  final f = inCard(key, text);
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await settle(tester);
}

void main() {
  setUpAll(loadAppFonts);
  setUp(() => mentoringNow = () => _now);
  tearDown(() => mentoringNow = DateTime.now);

  group('the desk\'s own rules', () {
    test('weekly windows are checked as the API checks them', () {
      const mon = 1;
      expect(hoursProblem(const []), isNull);
      expect(hoursProblem(const [WeeklyBlock(weekday: mon, startMin: 600, endMin: 720)]), isNull);
      expect(
        hoursProblem(const [WeeklyBlock(weekday: mon, startMin: 720, endMin: 720)]),
        'Each window must end after it starts.',
      );
      expect(
        hoursProblem(const [WeeklyBlock(weekday: mon, startMin: 800, endMin: 700)]),
        'Each window must end after it starts.',
      );
      expect(
        hoursProblem(const [
          WeeklyBlock(weekday: mon, startMin: 600, endMin: 720),
          WeeklyBlock(weekday: mon, startMin: 700, endMin: 800),
        ]),
        'Windows on the same day must not overlap.',
      );
      expect(
        hoursProblem(const [
          WeeklyBlock(weekday: mon, startMin: 600, endMin: 720),
          WeeklyBlock(weekday: mon, startMin: 720, endMin: 800),
        ]),
        isNull,
        reason: 'back to back is not an overlap',
      );
      expect(
        hoursProblem(const [
          WeeklyBlock(weekday: mon, startMin: 600, endMin: 720),
          WeeklyBlock(weekday: 2, startMin: 600, endMin: 720),
        ]),
        isNull,
        reason: 'the same hours on another day are fine',
      );
      final tooMany = [
        for (var i = 0; i < 22; i++)
          WeeklyBlock(weekday: i % 7, startMin: 60 * (i ~/ 7) * 3, endMin: 60 * (i ~/ 7) * 3 + 30),
      ];
      expect(hoursProblem(tooMany), 'You can keep at most 21 windows.');
    });

    test('a bio typed as plain text is sent as escaped paragraphs', () {
      expect(bioToHtml('One.\n\nTwo & <three>.'), '<p>One.</p><p>Two &amp; &lt;three&gt;.</p>');
      expect(bioToHtml('   '), '');
    });

    test('minutes read as the clock', () {
      expect(hm(1080), '18:00');
      expect(hm(605), '10:05');
      const b = WeeklyBlock(weekday: 2, startMin: 1080, endMin: 1230);
      expect(b.span, '18:00 to 20:30');
      expect(weekdayNames[b.weekday], 'Tuesday');
    });

    test('what needs the mentor is derived from the sales, the terms and the pairings, on the pinned clock', () async {
      final w = DeskWorld();
      final c = MentorDeskController(MentorDeskRepository(api: w.api().client()), nowFn: () => _now);
      await c.start();
      await c.mentoring.received.load();
      expect(c.gate, DeskGate.ready);
      expect(c.freeRequests.map((r) => r.id), containsAll(['r-isha', 'r-vikram']));
      expect(c.sessionRequests.map((r) => r.id), ['p-req', 'p-free', 'p-asked-again']);
      expect(c.heldTimes.map((r) => r.id), ['p-held']);
      expect(c.programmeRequests.map((t) => t.id), ['t-prog']);
      expect(c.unpaidTerms.map((t) => t.id), ['t-unpaid']);
      expect(c.activeTerms.map((t) => t.id), ['t-run']);
      expect(c.requestCount, 6);
      expect(c.issues.map((r) => r.id), ['p-issue']);
      expect(c.endedCalls.map((r) => r.id), ['p-ended']);
      expect(c.moveRequests.map((r) => r.id), ['p-move']);
      expect(c.upcomingCalls.map((r) => r.id), ['p-ahead']);
      expect(c.waiting.map((r) => r.id), containsAll(['p-held', 'p-mine']));
      expect(c.workCount, 3);
      c.dispose();
    });

    test('the gate tells no profile from a profile in review from the desk', () async {
      Future<DeskGate> gate(DeskWorld w) async {
        final c = MentorDeskController(MentorDeskRepository(api: w.api().client()), nowFn: () => _now);
        await c.dashboard.load();
        final g = c.gate;
        c.dispose();
        return g;
      }

      expect(await gate(DeskWorld(hasProfile: false)), DeskGate.noProfile);
      expect(await gate(DeskWorld(status: 'PENDING')), DeskGate.notLive);
      expect(await gate(DeskWorld(status: 'DRAFT')), DeskGate.notLive);
      expect(await gate(DeskWorld(status: 'REJECTED')), DeskGate.notLive);
      expect(await gate(DeskWorld()), DeskGate.ready);
      expect(await gate(DeskWorld(status: 'PAUSED')), DeskGate.ready);
    });
  });

  group('Work', () {
    testWidgets('sorts the paid work into what needs the mentor, what is ahead, what waits and what runs', (
      tester,
    ) async {
      await pumpDesk(tester, DeskWorld(), tab: DeskTab.work);
      expect(find.text('NEEDS YOU'), findsOneWidget);
      for (final k in ['issue-p-issue', 'ended-p-ended', 'move-p-move']) {
        expect(find.byKey(ValueKey(k)), findsOneWidget, reason: k);
      }
      expect(find.text('CALLS AHEAD'), findsOneWidget);
      expect(find.byKey(const ValueKey('call-p-ahead')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('call-p-mine')),
        findsNothing,
        reason: 'a move the mentor asked for waits on the mentee',
      );
      expect(find.text('WAITING ON OTHERS'), findsOneWidget);
      expect(find.byKey(const ValueKey('waiting-p-mine')), findsOneWidget);
      expect(find.byKey(const ValueKey('waiting-p-held')), findsOneWidget);
      expect(find.text('PROGRAMMES AND PLANS RUNNING'), findsOneWidget);
      expect(find.byKey(const ValueKey('running-t-run')), findsOneWidget);
      expect(find.textContaining('1 of 2 sessions left'), findsOneWidget);
    });

    testWidgets('nothing owed says so', (tester) async {
      final w = DeskWorld()
        ..sold = []
        ..terms = [];
      await pumpDesk(tester, w, tab: DeskTab.work);
      expect(find.text('No paid work right now'), findsOneWidget);
    });

    testWidgets('a problem a buyer reported is answered (ten characters at least), and the reply shows', (
      tester,
    ) async {
      final (api, _) = await pumpDesk(tester, DeskWorld(), tab: DeskTab.work);
      expect(find.text('"The file would not open on my phone."'), findsOneWidget);
      await tapIn(tester, 'issue-p-issue', 'Reply');
      await tester.enterText(find.byKey(const ValueKey('form-text')), 'Sorry');
      await tester.tap(find.text('Send reply'));
      await tester.pump();
      expect(find.text('Write at least 10 characters.'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('form-text')), 'I have sent the file again as a PDF.');
      await tester.tap(find.text('Send reply'));
      await settle(tester);
      expect(api.bodyOf('POST /mentor-services/purchases/p-issue/respond-issue'), {
        'note': 'I have sent the file again as a PDF.',
      });
      expect(find.textContaining('You replied 26 Oct: I have sent the file again as a PDF.'), findsOneWidget);
      expect(find.text('Reply again'), findsOneWidget);
    });

    testWidgets('a call that ended is confirmed held', (tester) async {
      final (api, _) = await pumpDesk(tester, DeskWorld(), tab: DeskTab.work);
      await tapIn(tester, 'ended-p-ended', 'Mark held');
      expect(api.count('POST /mentor-services/purchases/p-ended/complete'), 1);
      expect(find.text('Marked as held.'), findsOneWidget);
      expect(find.byKey(const ValueKey('ended-p-ended')), findsNothing);
    });

    testWidgets('a call can be cancelled with a reason of five characters', (tester) async {
      final (api, _) = await pumpDesk(tester, DeskWorld(), tab: DeskTab.work);
      await tapIn(tester, 'ended-p-ended', 'Cancel call');
      await tester.enterText(find.byKey(const ValueKey('form-text')), 'Sick');
      await tester.tap(find.text('Cancel call').last);
      await tester.pump();
      expect(find.text('Write at least 5 characters.'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('form-text')), 'I was unwell that day');
      await tester.tap(find.text('Cancel call').last);
      await settle(tester);
      expect(api.bodyOf('POST /mentor-services/purchases/p-ended/cancel'), {'reason': 'I was unwell that day'});
      expect(find.byKey(const ValueKey('ended-p-ended')), findsNothing);
    });

    testWidgets('a move the mentee asked for is accepted, or the booked time is kept', (tester) async {
      final (api, _) = await pumpDesk(tester, DeskWorld(), tab: DeskTab.work);
      expect(find.text('"A site visit that day"'), findsOneWidget);
      await tapIn(tester, 'move-p-move', 'Accept new time');
      expect(api.count('POST /mentor-services/purchases/p-move/reschedule/accept'), 1);
      expect(find.text('Moved to the new time.'), findsOneWidget);
      expect(find.byKey(const ValueKey('move-p-move')), findsNothing);
    });

    testWidgets('keeping the booked time declines the move', (tester) async {
      final (api, _) = await pumpDesk(tester, DeskWorld(), tab: DeskTab.work);
      await tapIn(tester, 'move-p-move', 'Keep the booked time');
      expect(api.count('POST /mentor-services/purchases/p-move/reschedule/decline'), 1);
      expect(find.text('Kept the booked time.'), findsOneWidget);
    });

    testWidgets(
      'another time is offered from the mentor\'s free hours, with a note, and the call waits on the mentee',
      (tester) async {
        final (api, _) = await pumpDesk(tester, DeskWorld(), tab: DeskTab.work);
        await tapIn(tester, 'move-p-move', 'Offer another time');
        expect(find.text('Free times in your hours'), findsOneWidget);
        await tester.tap(find.text('Send new time'));
        await tester.pump();
        expect(find.text('Pick a time first.'), findsOneWidget);
        await tester.tap(find.text('7:00 PM'));
        await tester.pump();
        await tester.enterText(find.byKey(const ValueKey('move-note')), 'Mornings are free');
        await tester.tap(find.text('Send new time'));
        await settle(tester);
        expect(api.queryOf('GET /mentorship/mentors/mp-anand/slots'), {'durationMin': 45, 'days': 14});
        expect(api.bodyOf('POST /mentor-services/purchases/p-move/reschedule'), {
          'scheduledAt': iso(DateTime(2026, 10, 28, 19)),
          'note': 'Mornings are free',
        });
        expect(find.text('Sent. The call stays as booked until they accept.'), findsOneWidget);
        expect(find.byKey(const ValueKey('waiting-p-move')), findsOneWidget);
      },
    );

    testWidgets('the meeting link of a call is set, checked as the API checks it, and Join then opens it', (
      tester,
    ) async {
      final (api, _) = await pumpDesk(tester, DeskWorld(), tab: DeskTab.work);
      final urls = launches(tester);
      expect(find.text('No meeting link yet'), findsOneWidget);
      await tapIn(tester, 'call-p-ahead', 'Meeting link');
      await tester.enterText(find.byKey(const ValueKey('call-link')), 'not a link');
      await tester.tap(find.text('Save link'));
      await tester.pump();
      expect(find.textContaining('Enter a full web address'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('call-link')), 'meet.google.com/abc-defg-hij');
      await tester.tap(find.text('Save link'));
      await settle(tester);
      expect(api.bodyOf('PATCH /mentor-services/purchases/p-ahead/meeting-link'), {
        'meetingLink': 'https://meet.google.com/abc-defg-hij',
      });
      expect(find.text('Link saved.'), findsOneWidget);
      expect(find.text('No meeting link yet'), findsNothing);
      await tapIn(tester, 'call-p-ahead', 'Join');
      expect(urls, ['https://meet.google.com/abc-defg-hij']);
    });

    testWidgets('a call ahead can be cancelled, and a message opens through the purchase', (tester) async {
      final (api, rec) = await pumpDesk(
        tester,
        DeskWorld(),
        tab: DeskTab.work,
        extra: {
          'POST /mentor-services/purchases/p-ahead/conversation': (_) => {'conversationId': 'conv-ahead'},
        },
      );
      await tapIn(tester, 'call-p-ahead', 'Message');
      expect(rec.opened, ['conversation:conv-ahead']);
      await tapIn(tester, 'call-p-ahead', 'Cancel');
      await tester.enterText(find.byKey(const ValueKey('form-text')), 'A site shutdown came up');
      await tester.tap(find.text('Cancel call').last);
      await settle(tester);
      expect(api.bodyOf('POST /mentor-services/purchases/p-ahead/cancel'), {'reason': 'A site shutdown came up'});
      expect(find.byKey(const ValueKey('call-p-ahead')), findsNothing);
    });

    testWidgets('an offer to move can be withdrawn', (tester) async {
      final (api, _) = await pumpDesk(tester, DeskWorld(), tab: DeskTab.work);
      await tapIn(tester, 'waiting-p-mine', 'Withdraw the offer');
      expect(api.count('POST /mentor-services/purchases/p-mine/reschedule/decline'), 1);
      expect(find.text('Offer withdrawn.'), findsOneWidget);
    });

    testWidgets('a running programme or plan opens its mentorship', (tester) async {
      await pumpDesk(tester, DeskWorld(), tab: DeskTab.work);
      await tester.ensureVisible(find.byKey(const ValueKey('running-t-run')));
      await tester.tap(find.byKey(const ValueKey('running-t-run')));
      await settle(tester);
      expect(find.byType(PairingScreen), findsOneWidget);
    });
  });

  group('Hours', () {
    testWidgets('shows the week in the mentor\'s own timezone, Monday first', (tester) async {
      await pumpDesk(tester, DeskWorld(), tab: DeskTab.hours);
      expect(find.textContaining('in Asia/Kolkata'), findsOneWidget);
      for (final d in [1, 2, 3, 4, 5, 6, 0]) {
        expect(find.byKey(ValueKey('day-$d')), findsOneWidget);
      }
      expect(find.text('18:00 to 20:30'), findsNWidgets(2));
      expect(find.text('10:00 to 13:00'), findsOneWidget);
      expect(find.text('Not available'), findsNWidgets(4));
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('day-1'))).dy,
        lessThan(tester.getTopLeft(find.byKey(const ValueKey('day-0'))).dy),
      );
      expect(
        tester.widget<SolidButton>(find.widgetWithText(SolidButton, 'Save hours')).onPressed,
        isNull,
        reason: 'nothing changed',
      );
    });

    testWidgets('a window is added on several days at once, and the API gets the whole week, replaced', (tester) async {
      final w = DeskWorld();
      final (api, _) = await pumpDesk(tester, w, tab: DeskTab.hours);
      await tapKey(tester, 'add-window');
      await tester.tap(find.text('Add window'));
      await tester.pump();
      expect(find.text('Pick at least one day.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('pick-day-1')));
      await tester.tap(find.byKey(const ValueKey('pick-day-3')));
      await tester.pump();
      await tester.tap(find.text('Add window'));
      await settle(tester);
      expect(find.byKey(const ValueKey('window-1-1080-1200')), findsOneWidget);
      expect(find.byKey(const ValueKey('window-3-1080-1200')), findsOneWidget);
      await tester.tap(find.text('Save hours'));
      await settle(tester);
      expect(api.bodyOf('PUT /mentorship/mentors/me/availability'), {
        'blocks': [
          {'weekday': 1, 'startMin': 1080, 'endMin': 1200},
          {'weekday': 2, 'startMin': 1080, 'endMin': 1230},
          {'weekday': 3, 'startMin': 1080, 'endMin': 1200},
          {'weekday': 4, 'startMin': 1080, 'endMin': 1230},
          {'weekday': 6, 'startMin': 600, 'endMin': 780},
        ],
      });
      expect(find.text('Hours saved.'), findsOneWidget);
      expect(w.blocks, hasLength(5));
    });

    testWidgets('a window on top of another is refused before it is added', (tester) async {
      await pumpDesk(tester, DeskWorld(), tab: DeskTab.hours);
      await tapKey(tester, 'add-window');
      await tester.tap(find.byKey(const ValueKey('pick-day-2')));
      await tester.pump();
      await tester.tap(find.text('Add window'));
      await tester.pump();
      expect(find.text('Windows on the same day must not overlap.'), findsOneWidget);
      expect(find.text('Add a window'), findsWidgets);
    });

    testWidgets('a window is removed, saved, and Discard puts the saved week back', (tester) async {
      final (api, _) = await pumpDesk(tester, DeskWorld(), tab: DeskTab.hours);
      await tester.tap(find.byTooltip('Remove Tuesday 18:00 to 20:30'));
      await tester.pump();
      expect(find.byKey(const ValueKey('window-2-1080-1230')), findsNothing);
      await tapText(tester, 'Discard');
      expect(find.byKey(const ValueKey('window-2-1080-1230')), findsOneWidget);
      await tester.tap(find.byTooltip('Remove Tuesday 18:00 to 20:30'));
      await tester.pump();
      await tester.tap(find.text('Save hours'));
      await settle(tester);
      final sent = ((api.bodyOf('PUT /mentorship/mentors/me/availability') as Map)['blocks'] as List).cast<Map>();
      expect(sent.map((b) => b['weekday']), [4, 6]);
    });

    testWidgets('an API refusal on save is shown and the edit is kept', (tester) async {
      final (_, _) = await pumpDesk(
        tester,
        DeskWorld(),
        tab: DeskTab.hours,
        extra: {'PUT /mentorship/mentors/me/availability': (_) => refuse('Each window must end after it starts.')},
      );
      await tester.tap(find.byTooltip('Remove Tuesday 18:00 to 20:30'));
      await tester.pump();
      await tester.tap(find.text('Save hours'));
      await settle(tester);
      expect(find.text('Each window must end after it starts.'), findsOneWidget);
      expect(find.byKey(const ValueKey('window-2-1080-1230')), findsNothing, reason: 'the edit stays');
    });

    testWidgets('with no hours the tab says members can still ask for a time', (tester) async {
      final w = DeskWorld()..blocks = [];
      await pumpDesk(tester, w, tab: DeskTab.hours);
      expect(find.textContaining('No hours set.'), findsOneWidget);
    });
  });

  group('Settings', () {
    testWidgets('only what changed is sent, and a bio left alone keeps its formatting', (tester) async {
      final w = DeskWorld();
      final (api, _) = await pumpDesk(tester, w, tab: DeskTab.settings);
      expect(find.byKey(const ValueKey('capacity-value')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey('capacity-value'))).data, '6');
      await tapKey(tester, 'mode-IN_PERSON');
      await tapKey(tester, 'cadence-MONTHLY');
      await tapKey(tester, 'capacity-up');
      await tester.enterText(find.byKey(const ValueKey('timezone')), 'Asia/Dubai');
      await tester.enterText(find.byKey(const ValueKey('standing-link')), 'meet.google.com/new-room');
      await tester.enterText(find.byKey(const ValueKey('availability-note')), 'Weekday evenings');
      await tapText(tester, 'Save settings');
      expect(api.bodyOf('PUT /mentorship/mentors/me'), {
        'preferredModes': ['VIDEO', 'PHONE', 'IN_PERSON'],
        'cadence': 'MONTHLY',
        'capacity': 7,
        'timezone': 'Asia/Dubai',
        'meetingLink': 'https://meet.google.com/new-room',
        'availabilityNote': 'Weekday evenings',
      });
      expect(find.text('Saved.'), findsOneWidget);
      expect(w.capacity, 7);
      expect(w.bioHtml, '<p>Nine years running facilities for large campuses.</p>');
    });

    testWidgets('a bio that was edited is sent as escaped paragraphs', (tester) async {
      final (api, _) = await pumpDesk(tester, DeskWorld(), tab: DeskTab.settings);
      await tester.enterText(find.byKey(const ValueKey('bio')), 'I help people grow.\n\nSites & portfolios');
      await tapText(tester, 'Save settings');
      expect(api.bodyOf('PUT /mentorship/mentors/me'), {
        'bioHtml': '<p>I help people grow.</p><p>Sites &amp; portfolios</p>',
      });
    });

    testWidgets('saving with nothing changed sends nothing', (tester) async {
      final (api, _) = await pumpDesk(tester, DeskWorld(), tab: DeskTab.settings);
      await tapText(tester, 'Save settings');
      expect(api.count('PUT /mentorship/mentors/me'), 0);
    });

    testWidgets('the form checks what the API checks, before it sends', (tester) async {
      final (api, _) = await pumpDesk(tester, DeskWorld(), tab: DeskTab.settings);
      await tapKey(tester, 'mode-VIDEO');
      await tapKey(tester, 'mode-PHONE');
      await tapText(tester, 'Save settings');
      expect(find.text('Pick at least one way you meet.'), findsOneWidget);
      await tapKey(tester, 'mode-VIDEO');
      await tester.enterText(find.byKey(const ValueKey('standing-link')), 'not a link');
      await tapText(tester, 'Save settings');
      expect(find.textContaining('Enter a full web address'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('standing-link')), 'meet.google.com/ok-room');
      await tester.enterText(find.byKey(const ValueKey('timezone')), '');
      await tapText(tester, 'Save settings');
      expect(find.text('Give your timezone, for example Asia/Kolkata.'), findsOneWidget);
      expect(api.count('PUT /mentorship/mentors/me'), 0);
    });

    testWidgets('a standing link can be cleared', (tester) async {
      final (api, _) = await pumpDesk(tester, DeskWorld(), tab: DeskTab.settings);
      await tester.enterText(find.byKey(const ValueKey('standing-link')), '');
      await tapText(tester, 'Save settings');
      expect(api.bodyOf('PUT /mentorship/mentors/me'), {'meetingLink': ''});
    });

    testWidgets('capacity stays between 1 and 10, and an API refusal keeps what was typed', (tester) async {
      final w = DeskWorld();
      final (_, _) = await pumpDesk(
        tester,
        w,
        tab: DeskTab.settings,
        extra: {'PUT /mentorship/mentors/me': (_) => refuse('You have more active mentees than that.')},
      );
      for (var i = 0; i < 8; i++) {
        await tester.ensureVisible(find.byKey(const ValueKey('capacity-up')));
        await tester.tap(find.byKey(const ValueKey('capacity-up')), warnIfMissed: false);
        await tester.pump();
      }
      expect(tester.widget<Text>(find.byKey(const ValueKey('capacity-value'))).data, '10');
      expect(tester.widget<IconButton>(find.byKey(const ValueKey('capacity-up'))).onPressed, isNull);
      await tester.enterText(find.byKey(const ValueKey('availability-note')), 'Evenings');
      await tapText(tester, 'Save settings');
      expect(find.text('You have more active mentees than that.'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey('capacity-value'))).data, '10');
      expect(find.text('Evenings'), findsOneWidget);
    });
  });

  group('Earnings', () {
    testWidgets('reads what was earned and what is paid out, and changes nothing', (tester) async {
      await pumpDesk(tester, DeskWorld(), tab: DeskTab.earnings);
      expect(find.text('₹8,796'), findsOneWidget);
      expect(find.text('Awaiting payout'), findsOneWidget);
      expect(find.text('₹1,997.60'), findsOneWidget);
      expect(find.text('Paid out'), findsOneWidget);
      expect(find.text('₹1,199.20'), findsOneWidget);
      expect(find.text('Facilities leadership strategy session'), findsOneWidget);
      expect(find.text('Meera Nair · 23 Oct · awaiting payout'), findsOneWidget);
      expect(find.text('Monthly leadership coaching'), findsOneWidget);
      expect(find.text('Meera Nair · 16 Oct · paid out 21 Oct (NEFT-DEMO-0042)'), findsOneWidget);
      expect(find.byType(SolidButton), findsNothing);
      expect(find.byType(QuietButton), findsNothing);
      expect(find.textContaining('Nothing on this page can be changed'), findsOneWidget);
    });

    testWidgets('a mentor with no sales yet is told when earnings appear', (tester) async {
      final w = DeskWorld()..earnings = {'unsettledPaisa': 0, 'settledPaisa': 0, 'entries': <Object?>[]};
      await pumpDesk(tester, w, tab: DeskTab.earnings);
      expect(find.text('No earnings yet'), findsOneWidget);
    });

    testWidgets('a failed read says why and Try again reads it again', (tester) async {
      var fail = true;
      final w = DeskWorld();
      final (api, _) = await pumpDesk(
        tester,
        w,
        tab: DeskTab.earnings,
        extra: {
          'GET /mentor-services/mine/earnings': (_) =>
              fail ? refuse('Earnings are unavailable.', status: 500) : w.earnings,
        },
      );
      expect(find.text("Couldn't load your earnings"), findsOneWidget);
      fail = false;
      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(find.text('₹8,796'), findsOneWidget);
      expect(api.count('GET /mentor-services/mine/earnings'), 2);
    });
  });

  group('Reviews', () {
    testWidgets('lists the anonymous ratings from mentees and the reviews of what the mentor sells', (tester) async {
      await pumpDesk(tester, DeskWorld(), tab: DeskTab.reviews);
      expect(find.text('Rating'), findsOneWidget);
      expect(find.text('4.8'), findsOneWidget);
      expect(find.text('14'), findsOneWidget);
      expect(find.text('Anand asked the questions I had been avoiding.'), findsOneWidget);
      expect(find.text('A mentee'), findsNWidgets(2));
      expect(find.text('Worth every rupee.'), findsOneWidget);
      expect(find.text('Tanvi Joshi'), findsOneWidget);
      expect(find.text('Facilities leadership strategy session'), findsOneWidget);
      expect(find.byType(SolidButton), findsNothing);
    });

    testWidgets('with none yet, each list says so', (tester) async {
      final w = DeskWorld()
        ..feedback = []
        ..serviceReviews = {'svc-strategy': [], 'svc-kit': []};
      await pumpDesk(tester, w, tab: DeskTab.reviews);
      expect(find.textContaining('No mentee has rated a mentorship with you yet'), findsOneWidget);
      expect(find.text('No reviews of your sessions or resources yet.'), findsOneWidget);
    });
  });
}
