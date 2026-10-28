import 'dart:typed_data';

import 'package:dio/dio.dart' show FormData;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/widgets/title_bar.dart';
import 'package:icr_mobile/features/mentorship_my/mentoring_clock.dart';
import 'package:icr_mobile/features/mentorship_my/pairing_controller.dart';
import 'package:icr_mobile/features/mentorship_my/mentoring_models.dart' show PickedShare;
import 'package:icr_mobile/features/mentorship_my/pairing_forms.dart' show SharePicker;

import 'helpers/fonts.dart';
import 'mentoring_fakes.dart';
import 'mentoring_pairing_world.dart';

final _now = DateTime(2026, 10, 26, 10);

Finder inCard(String sessionId, String text) =>
    find.descendant(of: find.byKey(ValueKey('session-$sessionId')), matching: find.text(text));

Finder inDialog(String text) => find.descendant(of: find.byType(AlertDialog), matching: find.text(text));

Future<(FakeApi, LinkRecorder, PairingWorld)> pump(
  WidgetTester tester, {
  PairingWorld? world,
  Map<String, Reply> extra = const {},
  SharePicker? pickFile,
}) async {
  final w = world ?? PairingWorld();
  final api = w.api(extra: extra);
  final (a, rec) = await pumpPairingScreen(tester, api, id: w.id, height: 14000, pickFile: pickFile);
  return (a, rec, w);
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

void main() {
  setUpAll(loadAppFonts);
  setUp(() => mentoringNow = () => _now);
  tearDown(() => mentoringNow = DateTime.now);

  group('the page', () {
    testWidgets('a mentee sees who it is with, what needs attention first, and every section', (tester) async {
      await pump(tester);
      expect(find.text('Your mentor'), findsOneWidget);
      expect(find.text('Anand Iyer'), findsWidgets);
      expect(find.textContaining('Mentor since'), findsOneWidget);
      expect(find.text('Needs you: a session to close'), findsOneWidget);
      expect(find.text('Overdue'), findsOneWidget);
      expect(find.text('Sessions'), findsOneWidget);
      expect(find.text('Ask for a time'), findsOneWidget);
      expect(find.text('Goals'), findsOneWidget);
      expect(find.text('Between sessions'), findsOneWidget);
      expect(find.text('Shared resources'), findsOneWidget);
      expect(find.text('Timeline'), findsOneWidget);
      expect(find.text('This mentorship'), findsOneWidget);
      expect(find.text('Mark held'), findsNothing, reason: 'only the mentor confirms a session happened');
      expect(find.text('Awaiting Anand'), findsOneWidget);
    });

    testWidgets('a mentor sees Book a session, and Mark held on the session that slipped', (tester) async {
      await pump(tester, world: PairingWorld(side: 'MENTOR'));
      expect(find.text('Your mentee'), findsOneWidget);
      expect(find.textContaining('Mentee since'), findsOneWidget);
      expect(find.text('Book a session'), findsOneWidget);
      expect(find.text('Mark held'), findsWidgets);
      expect(find.text('Asks for this time'), findsOneWidget);
    });

    testWidgets('a load that fails says why and Try again reads it again', (tester) async {
      final w = PairingWorld();
      var fail = true;
      final (api, _, _) = await pump(
        tester,
        world: w,
        extra: {'GET /mentorship/pair-anand': (_) => fail ? refuse('Mentorship not found', status: 404) : w.pairing},
      );
      expect(find.text("Couldn't load this mentorship"), findsOneWidget);
      expect(find.text('Mentorship not found'), findsOneWidget);
      fail = false;
      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(find.text('Your mentor'), findsOneWidget);
      expect(api.count('GET /mentorship/pair-anand'), 2);
    });

    testWidgets('Message opens the pairing\'s thread through the record', (tester) async {
      final (api, rec, _) = await pump(tester);
      await tester.tap(find.text('Message'));
      await settle(tester);
      expect(api.count('POST /mentorship/pair-anand/conversation'), 1);
      expect(rec.opened, ['conversation:conv-1']);
    });

    testWidgets('Mentor profile opens the mentor', (tester) async {
      final (_, rec, _) = await pump(tester);
      await tester.tap(find.text('Mentor profile'));
      expect(rec.opened, ['mentor:mp-anand']);
    });

    testWidgets('a mentor has no Mentor profile button: the other person is their mentee', (tester) async {
      await pump(tester, world: PairingWorld(side: 'MENTOR'));
      expect(find.text('Mentor profile'), findsNothing);
    });

    testWidgets('the bell opens the notifications', (tester) async {
      final (_, rec, _) = await pump(tester);
      await tester.tap(find.byType(BellButton));
      await tester.pump();
      expect(rec.opened, ['bell']);
    });
  });

  group('sessions', () {
    testWidgets('a mentee asks for a time from the mentor\'s free hours, and it waits for the mentor', (tester) async {
      final w = PairingWorld()..slots = [DateTime(2026, 10, 28, 18), DateTime(2026, 10, 28, 19)];
      final (api, _, _) = await pump(tester, world: w);
      await tapText(tester, 'Ask for a time');
      expect(find.text('Free times in their hours'), findsOneWidget);
      await tester.tap(find.text('45 min'));
      await settle(tester);
      await tester.tap(find.text('6:00 PM'));
      await tester.pump();
      await tester.enterText(find.byKey(const ValueKey('session-agenda')), 'Prepare for the panel');
      await tester.tap(find.text('Send request'));
      await settle(tester);
      final body = api.bodyOf('POST /mentorship/pair-anand/sessions') as Map;
      expect(body['durationMin'], 45);
      expect(body['mode'], 'VIDEO');
      expect(body['agenda'], 'Prepare for the panel');
      expect(DateTime.parse(body['scheduledAt'] as String).isAtSameMomentAs(DateTime(2026, 10, 28, 18)), isTrue);
      expect(find.text('Asked. Your mentor confirms the time.'), findsOneWidget);
      expect(find.text('Prepare for the panel'), findsOneWidget);
      expect(api.queryOf('GET /mentorship/mentors/mp-anand/slots'), {'durationMin': 45, 'days': 14});
    });

    testWidgets('the form checks the time and the length before it sends, and keeps what was typed on a refusal', (
      tester,
    ) async {
      final w = PairingWorld()..slots = [DateTime(2026, 10, 28, 18)];
      final (api, _, _) = await pump(
        tester,
        world: w,
        extra: {
          'POST /mentorship/pair-anand/sessions': (_) => refuse(
            'The mentor already has a session booked around that time — pick a slot that does not overlap it.',
          ),
        },
      );
      await tapText(tester, 'Ask for a time');
      await tester.tap(find.text('Send request'));
      await tester.pump();
      expect(find.text('Pick a time first.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('length-other')));
      await tester.pump();
      await tester.enterText(find.byKey(const ValueKey('session-minutes')), '10');
      await tester.tap(find.text('6:00 PM'));
      await tester.pump();
      await tester.tap(find.text('Send request'));
      await tester.pump();
      expect(find.text('A session runs 15 to 480 minutes.'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('session-minutes')), '50');
      await settle(tester); // a new length reads the free times again, and drops the pick
      await tester.tap(find.text('6:00 PM'));
      await tester.enterText(find.byKey(const ValueKey('session-agenda')), 'Prepare for the panel');
      await tester.tap(find.text('Send request'));
      await settle(tester);
      expect(api.count('POST /mentorship/pair-anand/sessions'), 1);
      expect((api.bodyOf('POST /mentorship/pair-anand/sessions') as Map)['durationMin'], 50);
      expect(find.textContaining('The mentor already has a session booked'), findsOneWidget);
      expect(find.text('Prepare for the panel'), findsOneWidget, reason: 'what was typed stays');
    });

    testWidgets('a time of the phone\'s own can be picked when the mentor lists no free hours', (tester) async {
      final w = PairingWorld();
      final (api, _, _) = await pump(tester, world: w);
      await tapText(tester, 'Ask for a time');
      expect(find.text('No open times in the next two weeks; pick a day and time.'), findsOneWidget);
      await tester.tap(find.text('Pick a day and time'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send request'));
      await settle(tester);
      final at = DateTime.parse(
        (api.bodyOf('POST /mentorship/pair-anand/sessions') as Map)['scheduledAt'] as String,
      ).toLocal();
      expect(at.day, 27, reason: 'the pickers open on tomorrow');
    });

    testWidgets('a mentor books straight onto both calendars, and only in the modes they offer', (tester) async {
      final w = PairingWorld(side: 'MENTOR')
        ..slots = [DateTime(2026, 10, 28, 18)]
        ..modes = ['PHONE'];
      final (api, _, _) = await pump(tester, world: w);
      await tapText(tester, 'Book a session');
      expect(find.text('Video call'), findsNothing, reason: 'the mentor does not meet by video');
      expect(find.text('Phone'), findsOneWidget);
      await tester.tap(find.text('6:00 PM'));
      await tester.pump();
      await tester.tap(find.text('Book session'));
      await settle(tester);
      expect((api.bodyOf('POST /mentorship/pair-anand/sessions') as Map)['mode'], 'PHONE');
      expect(find.text('Booked. Meera has been told.'), findsOneWidget);
    });

    testWidgets('either person moves a booked session; the API gets the new time', (tester) async {
      final w = PairingWorld()..slots = [DateTime(2026, 10, 30, 19)];
      final (api, _, _) = await pump(tester, world: w);
      await tester.ensureVisible(inCard('s-next', 'Move'));
      await tester.tap(inCard('s-next', 'Move'));
      await settle(tester);
      expect(find.text('Move this session'), findsOneWidget);
      await tester.tap(find.text('7:00 PM'));
      await tester.pump();
      await tester.tap(find.text('Move session'));
      await settle(tester);
      final body = api.bodyOf('PATCH /mentorship/pair-anand/sessions/s-next') as Map;
      expect(DateTime.parse(body['scheduledAt'] as String).isAtSameMomentAs(DateTime(2026, 10, 30, 19)), isTrue);
      expect(body['agenda'], 'Mock panel interview', reason: 'the agenda travels with the move');
      expect(find.textContaining('Moved. Anand has been told.'), findsOneWidget);
    });

    testWidgets('cancelling asks for a reason of at least three characters and moves it to the past', (tester) async {
      final (api, _, _) = await pump(tester);
      expect(find.text('Past sessions (2)'), findsOneWidget);
      await tester.ensureVisible(inCard('s-next', 'Cancel'));
      await tester.tap(inCard('s-next', 'Cancel'));
      await settle(tester);
      await tester.enterText(find.byKey(const ValueKey('form-text')), 'No');
      await tester.tap(find.text('Cancel session'));
      await tester.pump();
      expect(find.text('Write at least 3 characters.'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('form-text')), 'Away that week');
      await tester.tap(find.text('Cancel session'));
      await settle(tester);
      expect(api.bodyOf('POST /mentorship/pair-anand/sessions/s-next/cancel'), {'reason': 'Away that week'});
      expect(find.text('Past sessions (3)'), findsOneWidget);
    });

    testWidgets('a mentee withdraws a request they made', (tester) async {
      final (api, _, _) = await pump(tester);
      await tester.ensureVisible(inCard('s-req', 'Withdraw'));
      await tester.tap(inCard('s-req', 'Withdraw'));
      await settle(tester);
      expect(api.bodyOf('POST /mentorship/pair-anand/sessions/s-req/cancel'), {'reason': 'Withdrawn by the mentee.'});
      expect(find.text('Request withdrawn.'), findsOneWidget);
    });

    testWidgets('a mentor approves a request, which puts it on both calendars', (tester) async {
      final (api, _, _) = await pump(tester, world: PairingWorld(side: 'MENTOR'));
      await tester.ensureVisible(inCard('s-req', 'Approve'));
      await tester.tap(inCard('s-req', 'Approve'));
      await settle(tester);
      expect(api.count('POST /mentorship/pair-anand/sessions/s-req/approve'), 1);
      expect(find.text('Approved. It is on both calendars.'), findsOneWidget);
    });

    testWidgets('a mentor answers a request with another time, which books it', (tester) async {
      final w = PairingWorld(side: 'MENTOR')..slots = [DateTime(2026, 11, 5, 18)];
      final (api, _, _) = await pump(tester, world: w);
      await tester.ensureVisible(inCard('s-req', 'Offer another time'));
      await tester.tap(inCard('s-req', 'Offer another time'));
      await settle(tester);
      expect(find.text('Offer another time'), findsWidgets);
      await tester.tap(find.text('6:00 PM'));
      await tester.pump();
      await tester.tap(find.text('Book this time'));
      await settle(tester);
      final body = api.bodyOf('PATCH /mentorship/pair-anand/sessions/s-req') as Map;
      expect(DateTime.parse(body['scheduledAt'] as String).isAtSameMomentAs(DateTime(2026, 11, 5, 18)), isTrue);
      expect(find.text('Booked at the new time.'), findsOneWidget);
    });

    testWidgets('a mentor declines a request with a reason the mentee reads', (tester) async {
      final (api, _, _) = await pump(tester, world: PairingWorld(side: 'MENTOR'));
      await tester.ensureVisible(inCard('s-req', 'Decline'));
      await tester.tap(inCard('s-req', 'Decline'));
      await settle(tester);
      await tester.enterText(find.byKey(const ValueKey('form-text')), 'I am travelling that day');
      await tester.tap(find.text('Decline').last);
      await settle(tester);
      expect(api.bodyOf('POST /mentorship/pair-anand/sessions/s-req/cancel'), {'reason': 'I am travelling that day'});
    });

    testWidgets('a mentor closes a session with the minutes it ran, and the pairing\'s counters are read again', (
      tester,
    ) async {
      final (api, _, w) = await pump(tester, world: PairingWorld(side: 'MENTOR'));
      await tester.ensureVisible(inCard('s-overdue', 'Mark held'));
      await tester.tap(inCard('s-overdue', 'Mark held'));
      await settle(tester);
      expect(find.textContaining('45 min was booked'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('held-minutes')), '5');
      await tester.tap(find.text('Mark held').last);
      await tester.pump();
      expect(find.text('Enter the minutes it ran: 15 to 480.'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('held-minutes')), '50');
      await tester.enterText(find.byKey(const ValueKey('held-note')), 'Agreed the scorecard');
      await tester.tap(find.text('Mark held').last);
      await settle(tester);
      expect(api.bodyOf('POST /mentorship/pair-anand/sessions/s-overdue/complete'), {
        'durationMin': 50,
        'note': 'Agreed the scorecard',
      });
      expect(find.text('Marked as held.'), findsOneWidget);
      expect(find.text('Needs you: a session to close'), findsNothing);
      expect(w.sessions.firstWhere((s) => s['id'] == 's-overdue')['status'], 'COMPLETED');
    });

    testWidgets('the mentor sets a meeting link, which is checked as the API checks it', (tester) async {
      final (api, _, _) = await pump(tester, world: PairingWorld(side: 'MENTOR'));
      expect(find.text('No meeting link yet'), findsOneWidget);
      await tester.ensureVisible(inCard('s-req', 'Meeting link'));
      await tester.tap(inCard('s-req', 'Meeting link'));
      await settle(tester);
      await tester.enterText(find.byKey(const ValueKey('meeting-link')), 'not a link');
      await tester.tap(find.text('Save link'));
      await tester.pump();
      expect(find.textContaining('Enter a full web address'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('meeting-link')), 'meet.google.com/abc-defg-hij');
      await tester.tap(find.text('Save link'));
      await settle(tester);
      expect(api.bodyOf('PATCH /mentorship/pair-anand/sessions/s-req/meeting-link'), {
        'meetingLink': 'https://meet.google.com/abc-defg-hij',
      });
      expect(find.text('Link saved.'), findsOneWidget);
      expect(find.text('No meeting link yet'), findsNothing);
    });

    testWidgets('Join opens the session\'s meeting link', (tester) async {
      await pump(tester);
      final urls = launches(tester);
      await tester.ensureVisible(inCard('s-next', 'Join'));
      await tester.tap(inCard('s-next', 'Join'));
      await tester.pump();
      expect(urls, ['https://meet.google.com/icr-demo']);
    });

    testWidgets('a paused pairing offers no booking until it is resumed', (tester) async {
      await pump(tester, world: PairingWorld(status: 'PAUSED'));
      expect(find.text('Ask for a time'), findsNothing);
      expect(find.text('This mentorship is paused. Resume it to book a session.'), findsOneWidget);
      expect(find.text('Resume'), findsOneWidget);
    });

    testWidgets(
      'the notes of a held session are saved, and a summary is asked for only when the notes are long enough',
      (tester) async {
        final (api, _, w) = await pump(tester);
        await tester.tap(find.byKey(const ValueKey('toggle-past')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(inCard('s-held', 'Notes'));
        await tester.tap(inCard('s-held', 'Notes'));
        await settle(tester);
        expect(find.text('Agreed a 90-day target.'), findsWidgets);
        expect(find.text('A summary needs at least 200 characters of notes.'), findsOneWidget);
        await tester.enterText(find.byKey(const ValueKey('record-link')), 'nope');
        await tester.enterText(find.byKey(const ValueKey('record-notes')), 'x' * 220);
        await tester.pump();
        expect(find.text('Save your changes first: a summary is made from the saved notes.'), findsOneWidget);
        await tester.tap(find.text('Save notes'));
        await tester.pump();
        expect(find.textContaining('Enter a full web address'), findsOneWidget);
        await tester.enterText(find.byKey(const ValueKey('record-link')), 'https://example.com/rec');
        await tester.tap(find.text('Save notes'));
        await settle(tester);
        expect(api.bodyOf('PATCH /mentorship/pair-anand/sessions/s-held/record'), {
          'notes': 'x' * 220,
          'recordingUrl': 'https://example.com/rec',
        });
        expect(w.sessions.firstWhere((s) => s['id'] == 's-held')['notes'], 'x' * 220);
        expect(find.text('Notes saved.'), findsOneWidget);

        await tester.tap(inCard('s-held', 'Notes'));
        await settle(tester);
        await tester.tap(find.text('Summarise these notes'));
        await settle(tester);
        expect(api.count('POST /mentorship/pair-anand/sessions/s-held/summarise'), 1);
        expect(find.textContaining('Discussed the 90-day target.'), findsWidgets);
      },
    );

    testWidgets('a summary the site cannot make says so', (tester) async {
      final w = PairingWorld();
      (w.sessions.firstWhere((s) => s['id'] == 's-held'))['notes'] = 'y' * 250;
      final (api, _, _) = await pump(
        tester,
        world: w,
        extra: {
          'POST /mentorship/pair-anand/sessions/s-held/summarise': (_) => {
            'summary': null,
            'cached': false,
            'unavailable': true,
          },
        },
      );
      await tester.tap(find.byKey(const ValueKey('toggle-past')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(inCard('s-held', 'Notes'));
      await tester.tap(inCard('s-held', 'Notes'));
      await settle(tester);
      await tester.tap(find.text('Summarise these notes'));
      await settle(tester);
      expect(api.count('POST /mentorship/pair-anand/sessions/s-held/summarise'), 1);
      expect(find.text('Summaries are not switched on here yet.'), findsOneWidget);
    });
  });

  group('goals and tasks', () {
    testWidgets('a goal is added (3 characters at least), moved along, achieved, dropped, reopened and removed', (
      tester,
    ) async {
      final (api, _, w) = await pump(tester);
      await tapText(tester, 'Add goal');
      await tester.enterText(find.byKey(const ValueKey('goal-title')), 'ab');
      await tester.tap(find.text('Add goal').last);
      await tester.pump();
      expect(find.text('Name the goal: at least 3 characters.'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('goal-title')), 'Run a vendor review');
      await tester.enterText(find.byKey(const ValueKey('goal-detail')), 'Quarterly');
      await tester.tap(find.text('Add goal').last);
      await settle(tester);
      expect((api.bodyOf('POST /mentorship/pair-anand/goals') as Map)['title'], 'Run a vendor review');
      expect(find.text('Goal added.'), findsOneWidget);
      expect(find.text('Run a vendor review'), findsOneWidget);

      // Progress: the slider's value is what is sent.
      final card = find.byKey(const ValueKey('goal-g1'));
      await tester.ensureVisible(card);
      await tester.tap(find.descendant(of: card, matching: find.text('Progress')));
      await settle(tester);
      expect(find.text('40%'), findsWidgets);
      await tester.drag(find.byKey(const ValueKey('progress-slider')), const Offset(120, 0));
      await tester.pump();
      await tester.tap(find.text('Save progress'));
      await settle(tester);
      final sent = (api.bodyOf('POST /mentorship/pair-anand/goals/g1/progress') as Map)['progress'] as int;
      expect(sent, greaterThan(40));
      expect(w.goals.firstWhere((g) => g['id'] == 'g1')['progress'], sent);

      await tester.ensureVisible(card);
      await tester.tap(find.descendant(of: card, matching: find.text('Achieved')));
      await settle(tester);
      expect(api.bodyOf('POST /mentorship/pair-anand/goals/g1/status'), {'status': 'ACHIEVED'});
      expect(find.text('Goal achieved.'), findsOneWidget);
      await tester.tap(find.descendant(of: card, matching: find.text('Reopen')));
      await settle(tester);
      expect(api.bodyOf('POST /mentorship/pair-anand/goals/g1/status'), {'status': 'OPEN'});
      await tester.tap(find.descendant(of: card, matching: find.text('Drop')));
      await settle(tester);
      expect(api.bodyOf('POST /mentorship/pair-anand/goals/g1/status'), {'status': 'DROPPED'});
      await tester.tap(find.descendant(of: card, matching: find.text('Remove')));
      await settle(tester);
      expect(api.count('DELETE /mentorship/pair-anand/goals/g1'), 1);
      expect(find.byKey(const ValueKey('goal-g1')), findsNothing);
    });

    testWidgets('a task is added, ticked, unticked and deleted (only the author deletes)', (tester) async {
      final (api, _, w) = await pump(tester);
      await tapText(tester, 'Add task');
      await tester.enterText(find.byKey(const ValueKey('task-title')), 'x');
      await tester.tap(find.text('Add task').last);
      await tester.pump();
      expect(find.text('Name the task: at least 2 characters.'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('task-title')), 'Send the site list');
      await tester.tap(find.text('Add task').last);
      await settle(tester);
      expect((api.bodyOf('POST /mentorship/pair-anand/tasks') as Map)['title'], 'Send the site list');
      expect(find.text('Task added.'), findsOneWidget);

      final row = find.byKey(const ValueKey('task-t1'));
      await tester.ensureVisible(row);
      expect(
        find.descendant(of: row, matching: find.byTooltip('Delete task')),
        findsNothing,
        reason: 'not their task',
      );
      await tester.tap(find.descendant(of: row, matching: find.byType(Checkbox)));
      await settle(tester);
      expect(api.bodyOf('PATCH /mentorship/pair-anand/tasks/t1'), {'status': 'DONE'});
      expect(w.tasks.firstWhere((t) => t['id'] == 't1')['status'], 'DONE');
      await tester.tap(find.descendant(of: row, matching: find.byType(Checkbox)));
      await settle(tester);
      expect(api.bodyOf('PATCH /mentorship/pair-anand/tasks/t1'), {'status': 'OPEN'});

      final mine = find.byKey(const ValueKey('task-t3'));
      await tester.ensureVisible(mine);
      await tester.tap(find.descendant(of: mine, matching: find.byTooltip('Delete task')));
      await settle(tester);
      expect(api.count('DELETE /mentorship/pair-anand/tasks/t3'), 1);
      expect(find.byKey(const ValueKey('task-t3')), findsNothing);
    });

    testWidgets('goals and tasks are read-only once the mentorship has ended', (tester) async {
      await pump(tester, world: PairingWorld(status: 'ENDED_EARLY'));
      expect(find.text('Add goal'), findsNothing);
      expect(find.text('Add task'), findsNothing);
      expect(find.text('Drop'), findsNothing);
      expect(find.text('Pause'), findsNothing);
    });
  });

  group('shared resources and the timeline', () {
    testWidgets('a link is shared (checked first), opened by the other person and removed by its author', (
      tester,
    ) async {
      final (api, _, w) = await pump(tester);
      await tapText(tester, 'Share a link or file');
      await tester.tap(find.text('Share').last);
      await tester.pump();
      expect(find.text('Give it a title: at least 2 characters.'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('resource-title')), 'Handover checklist');
      await tester.tap(find.text('Share').last);
      await tester.pump();
      expect(find.text('Paste the link to share.'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('resource-url')), 'not a link');
      await tester.tap(find.text('Share').last);
      await tester.pump();
      expect(find.textContaining('Enter a full web address'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('resource-url')), 'example.com/checklist');
      await tester.tap(find.text('Template'));
      await tester.enterText(find.byKey(const ValueKey('resource-note')), 'Start with section 3');
      await tester.tap(find.text('Share').last);
      await settle(tester);
      expect(api.bodyOf('POST /mentorship/resources'), {
        'mentorshipId': 'pair-anand',
        'title': 'Handover checklist',
        'kind': 'TEMPLATE',
        'url': 'https://example.com/checklist',
        'note': 'Start with section 3',
      });
      expect(find.text('Shared.'), findsOneWidget);
      expect(find.text('Handover checklist'), findsOneWidget);
      expect(w.resources, hasLength(1));
      final urls = launches(tester);
      await tester.tap(find.text('Handover checklist'));
      await tester.pump();
      expect(urls, ['https://example.com/checklist']);
      await tester.tap(find.byTooltip('Remove'));
      await settle(tester);
      expect(api.count('DELETE /mentorship/resources/r-1'), 1);
      expect(find.text('Handover checklist'), findsNothing);
    });

    testWidgets('a shared file is read with the session\'s token and handed to the share sheet', (tester) async {
      final w = PairingWorld()
        ..resources = [
          {
            'id': 'r-2',
            'title': 'Org chart',
            'kind': 'WHITEPAPER',
            'note': null,
            'url': '/uploads/org-chart.pdf',
            'fileName': 'org-chart.pdf',
            'fileSize': 2048,
            'addedBy': {'id': 'u-anand', 'firstName': 'Anand', 'lastName': 'Iyer'},
            'canRemove': false,
            'createdAt': iso(_now),
          },
        ];
      final (api, rec, _) = await pump(
        tester,
        world: w,
        extra: {'GET http://api.test/uploads/org-chart.pdf': fileReply},
      );
      expect(find.text('Whitepaper · 2 KB · Anand Iyer'), findsOneWidget);
      expect(find.byTooltip('Remove'), findsNothing, reason: 'it is the mentor\'s file');
      await tester.tap(find.text('Org chart'));
      await settle(tester);
      expect(api.requests.any((r) => r.path.endsWith('/uploads/org-chart.pdf')), isTrue);
      expect(rec.shared.single, startsWith('org-chart.pdf:'));
    });

    testWidgets('a file is shared from the phone: chosen, checked, uploaded as the API wants it, then listed', (
      tester,
    ) async {
      final w = PairingWorld();
      final (api, _, _) = await pump(
        tester,
        world: w,
        pickFile: () async => PickedShare(
          bytes: Uint8List.fromList(List.filled(2048, 1)),
          name: 'org-chart.pdf',
          mimeType: 'application/pdf',
        ),
        extra: {
          'POST /uploads': (_) => {
            'url': '/uploads/ab12cd.pdf',
            'name': 'org-chart.pdf',
            'size': 2048,
            'mimeType': 'application/pdf',
          },
        },
      );
      await tapText(tester, 'Share a link or file');
      await tester.tap(find.byKey(const ValueKey('share-file')));
      await tester.pump();
      await tester.tap(find.text('Share').last);
      await tester.pump();
      expect(find.text('Give it a title: at least 2 characters.'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('resource-title')), 'Org chart');
      await tester.tap(find.text('Share').last);
      await tester.pump();
      expect(find.text('Choose the file to share.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('choose-file')));
      await settle(tester);
      expect(find.text('org-chart.pdf · 2 KB'), findsOneWidget);
      await tester.tap(find.text('Whitepaper'));
      await tester.tap(find.text('Share').last);
      await settle(tester);
      expect(api.queryOf('POST /uploads'), {'purpose': 'mentorship-resource'});
      expect(api.requests.firstWhere((r) => r.path == '/uploads').data, isA<FormData>());
      expect(api.bodyOf('POST /mentorship/resources'), {
        'mentorshipId': 'pair-anand',
        'title': 'Org chart',
        'kind': 'WHITEPAPER',
        'uploadId': 'ab12cd.pdf',
        'fileName': 'org-chart.pdf',
        'fileSize': 2048,
      });
      expect(find.text('Shared.'), findsOneWidget);
    });

    testWidgets('a file that is not a PDF or an image is refused before it is sent, and a refused upload says why', (
      tester,
    ) async {
      var picks = 0;
      final (api, _, _) = await pump(
        tester,
        pickFile: () async {
          picks++;
          return picks == 1
              ? PickedShare(bytes: Uint8List.fromList([1, 2, 3]), name: 'macros.exe')
              : PickedShare(bytes: Uint8List.fromList([1, 2, 3]), name: 'notes.pdf', mimeType: 'application/pdf');
        },
        extra: {'POST /uploads': (_) => refuse('application/pdf is not an accepted file type for this upload.')},
      );
      await tapText(tester, 'Share a link or file');
      await tester.tap(find.byKey(const ValueKey('share-file')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('choose-file')));
      await settle(tester);
      expect(find.text('Share a PDF or an image (PNG, JPG or WebP).'), findsOneWidget);
      expect(find.byKey(const ValueKey('picked-file')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('choose-file')));
      await settle(tester);
      expect(find.byKey(const ValueKey('picked-file')), findsOneWidget);
      expect(find.byKey(const ValueKey('resource-title')).evaluate().isNotEmpty, isTrue);
      await tester.tap(find.text('Share').last);
      await settle(tester);
      expect(find.text('application/pdf is not an accepted file type for this upload.'), findsOneWidget);
      expect(api.count('POST /mentorship/resources'), 0, reason: 'nothing is shared when the upload fails');
    });

    testWidgets('a file the API refuses says why instead of failing quietly', (tester) async {
      final w = PairingWorld()
        ..resources = [
          {
            'id': 'r-2',
            'title': 'Org chart',
            'kind': 'OTHER',
            'url': '/uploads/gone.pdf',
            'fileName': 'gone.pdf',
            'fileSize': 10,
            'addedBy': {'id': 'u-anand', 'firstName': 'Anand', 'lastName': 'Iyer'},
            'canRemove': false,
            'createdAt': iso(_now),
          },
        ];
      final (_, rec, _) = await pump(
        tester,
        world: w,
        extra: {'GET http://api.test/uploads/gone.pdf': (_) => refuse('Sign in to view this file.', status: 403)},
      );
      await tester.tap(find.text('Org chart'));
      await settle(tester);
      expect(find.text('Sign in to view this file.'), findsOneWidget);
      expect(rec.shared, isEmpty);
    });

    testWidgets('a note goes on the timeline, shared or kept to the author', (tester) async {
      final (api, _, _) = await pump(tester);
      await tapText(tester, 'Add a note');
      await tester.tap(find.text('Add note').last);
      await tester.pump();
      expect(find.text('Write the note first.'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('note-text')), 'Sent him the org chart');
      await tester.tap(find.byKey(const ValueKey('note-private')));
      await tester.pump();
      await tester.tap(find.text('Add note').last);
      await settle(tester);
      expect(api.bodyOf('POST /mentorship/pair-anand/notes'), {'note': 'Sent him the org chart', 'privateToMe': true});
      expect(find.text('Note added.'), findsOneWidget);
      expect(find.text('Sent him the org chart'), findsOneWidget);
      expect(find.text('Private'), findsOneWidget);
    });

    testWidgets('the timeline shows four entries and opens the rest', (tester) async {
      final w = PairingWorld();
      for (var i = 0; i < 5; i++) {
        w.timeline = [
          ...w.timeline,
          {
            'id': 'e$i',
            'type': 'GOAL_ADDED',
            'note': 'Goal $i',
            'visibility': 'SHARED',
            'actor': null,
            'metadata': null,
            'createdAt': iso(_now.subtract(Duration(days: 5 - i))),
          },
        ];
      }
      await pump(tester, world: w);
      expect(find.text('All 6 entries'), findsOneWidget);
      expect(find.text('Goal 4'), findsOneWidget, reason: 'newest first');
      expect(find.text('Mentorship started'), findsNothing);
      await tapKey(tester, 'timeline-all');
      expect(find.text('Mentorship started'), findsOneWidget);
      expect(find.text('Show less'), findsOneWidget);
    });
  });

  group('the plan behind it', () {
    testWidgets('an ongoing plan shows what is left of it, and its buyer may stop it renewing', (tester) async {
      final (api, _, w) = await pump(tester, world: PairingWorld(withPlan: true));
      expect(find.text('Your plan'), findsOneWidget);
      expect(find.text('Monthly leadership coaching'), findsOneWidget);
      expect(find.text('1 of 2 sessions left'), findsOneWidget);
      await tapText(tester, 'Do not renew');
      expect(api.count('POST /mentor-plans/subscriptions/term-1/cancel'), 1);
      expect(w.term!['cancelAtPeriodEnd'], isTrue);
      expect(find.text('It will not renew.'), findsOneWidget);
      expect(find.textContaining('It will not renew: it ends at the close'), findsOneWidget);
    });

    testWidgets('the mentor sees the plan too, but cannot stop it', (tester) async {
      await pump(tester, world: PairingWorld(side: 'MENTOR', withPlan: true));
      expect(find.text('Monthly leadership coaching'), findsOneWidget);
      expect(find.text('Do not renew'), findsNothing);
    });

    testWidgets('a programme lists its sessions in order and a booking is made against one of them', (tester) async {
      final w = PairingWorld(withPlan: true, programme: true)..slots = [DateTime(2026, 10, 28, 18)];
      final (api, _, _) = await pump(tester, world: w);
      expect(find.text('The programme'), findsOneWidget);
      expect(find.text('Held'), findsWidgets);
      expect(find.text('Next to book'), findsOneWidget);
      expect(find.text('No goals yet. A goal is what the two of you are working towards.'), findsNothing);
      await tapText(tester, 'Ask for a time');
      expect(find.text('Which session of the programme?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('step-step-3')));
      await tester.tap(find.text('6:00 PM'));
      await tester.pump();
      await tester.tap(find.text('Send request'));
      await settle(tester);
      expect((api.bodyOf('POST /mentorship/pair-anand/sessions') as Map)['planStepId'], 'step-3');
    });
  });

  group('the mentorship itself', () {
    testWidgets('pause, resume and the rhythm change what the API holds', (tester) async {
      final (api, _, w) = await pump(tester);
      await tapText(tester, 'Pause');
      expect(api.bodyOf('PATCH /mentorship/pair-anand'), {'status': 'PAUSED'});
      expect(find.text('Paused.'), findsOneWidget);
      expect(find.text('Paused. Resume it to book sessions.'), findsOneWidget);
      await tapText(tester, 'Resume');
      expect(api.bodyOf('PATCH /mentorship/pair-anand'), {'status': 'ACTIVE'});
      await tapKey(tester, 'cadence-WEEKLY');
      expect(api.bodyOf('PATCH /mentorship/pair-anand'), {'cadence': 'WEEKLY'});
      expect(w.cadence, 'WEEKLY');
      expect(find.text('Rhythm changed.'), findsOneWidget);
    });

    testWidgets('ending early asks for a reason both of them read', (tester) async {
      final (api, _, w) = await pump(tester);
      await tapText(tester, 'End early');
      await tester.tap(find.text('End mentorship'));
      await tester.pump();
      expect(find.text('Write at least 3 characters.'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('form-text')), 'Our schedules no longer line up');
      await tester.tap(find.text('End mentorship'));
      await settle(tester);
      expect(api.bodyOf('PATCH /mentorship/pair-anand'), {
        'status': 'ENDED_EARLY',
        'endedReason': 'Our schedules no longer line up',
      });
      expect(w.status, 'ENDED_EARLY');
      expect(find.text('Ended: Our schedules no longer line up'), findsOneWidget);
      expect(find.text('Pause'), findsNothing);
    });

    testWidgets('completing it asks first, then the review and the certificate appear', (tester) async {
      final (api, _, _) = await pump(tester);
      await tapText(tester, 'Mark complete');
      await tester.tap(inDialog('Not yet'));
      await tester.pumpAndSettle();
      expect(api.count('PATCH /mentorship/pair-anand'), 0);
      await tapText(tester, 'Mark complete');
      await tester.tap(inDialog('Mark complete'));
      await settle(tester);
      expect(api.bodyOf('PATCH /mentorship/pair-anand'), {'status': 'COMPLETED'});
      expect(find.text('Your review'), findsOneWidget);
      expect(find.text('Rate this mentorship'), findsOneWidget);
      expect(find.text('Your certificate'), findsOneWidget);
      expect(find.text('Mentoring completion certificate'), findsOneWidget);
      await tapKey(tester, 'certificate-card');
      expect(find.text('ICR-MENTEE-2026-BHARATXX'), findsOneWidget);
    });

    testWidgets('a completed mentorship is rated once, with a recommendation', (tester) async {
      final w = PairingWorld(status: 'COMPLETED');
      final (api, _, _) = await pump(tester, world: w);
      await tapText(tester, 'Rate this mentorship');
      await tester.tap(find.text('Send review'));
      await tester.pump();
      expect(find.text('Choose a rating from one to five stars.'), findsOneWidget);
      await tester.tap(find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.star_outline_rounded).last);
      await tester.pump();
      await tester.enterText(find.byKey(const ValueKey('review-comment')), 'Clear and practical');
      await tester.tap(find.text('Send review'));
      await settle(tester);
      expect(api.bodyOf('POST /mentorship/pair-anand/feedback'), {
        'rating': 5,
        'comment': 'Clear and practical',
        'wouldRecommend': true,
      });
      expect(find.byKey(const ValueKey('my-review')), findsOneWidget);
      expect(find.text('Rate this mentorship'), findsNothing);
    });

    testWidgets('a concern needs ten characters, goes to ICR, and a safety concern is always urgent', (tester) async {
      final (api, _, _) = await pump(tester);
      await tapText(tester, 'Report a concern');
      await tester.enterText(find.byKey(const ValueKey('concern-detail')), 'short');
      await tester.tap(find.text('Send to ICR'));
      await tester.pump();
      expect(find.text('Tell ICR what happened: at least 10 characters.'), findsOneWidget);
      await tester.tap(find.text('Safety'));
      await tester.enterText(find.byKey(const ValueKey('concern-detail')), 'I felt unsafe at the site visit');
      await tester.tap(find.text('Send to ICR'));
      await settle(tester);
      expect(api.bodyOf('POST /mentorship/pair-anand/concerns'), {
        'category': 'SAFETY',
        'detail': 'I felt unsafe at the site visit',
        'urgent': true,
      });
      expect(find.textContaining('Sent to ICR.'), findsOneWidget);
    });

    testWidgets('support is an ordinary request about this mentorship', (tester) async {
      final (api, _, _) = await pump(tester);
      await tapText(tester, 'Contact ICR support');
      await tester.enterText(find.byKey(const ValueKey('support-subject')), 'Hi');
      await tester.tap(find.text('Send'));
      await tester.pump();
      expect(find.text('Give it a subject: at least 5 characters.'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('support-subject')), 'The booking will not load');
      await tester.enterText(find.byKey(const ValueKey('support-body')), 'It spins forever when I tap Move.');
      await tester.tap(find.text('Send'));
      await settle(tester);
      expect(api.bodyOf('POST /support/tickets'), {
        'subject': 'The booking will not load',
        'category': 'MENTORSHIP',
        'body': 'It spins forever when I tap Move.',
        'contextType': 'MENTORSHIP',
        'contextId': 'pair-anand',
      });
      expect(find.text('Sent. ICR support will reply to you.'), findsOneWidget);
    });
  });

  group('the controller', () {
    test('the session to lead with is the oldest that slipped, then an ask, then the next', () async {
      final w = PairingWorld();
      final c = PairingController(repoOf(w.api()), 'pair-anand');
      await c.load();
      expect(c.featured(_now)!.id, 's-overdue');
      expect(c.overdue(c.featured(_now)!, _now), isTrue);
      expect(c.upcoming(_now).map((s) => s.id), [
        's-overdue',
        's-req',
        's-next',
      ], reason: 'overdue, then an ask, then upcoming');
    });
  });
}
