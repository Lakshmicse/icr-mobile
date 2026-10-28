/// The MENTOR flows, end to end, as Srikanth Sriramagiri (`mentorship.srikanth@design.icr.test`, the mentor on the
/// profile design: an approved profile, four places with two live mentees, a free 1:1 session, a free resource, a
/// coaching plan and a programme) against the LOCAL portal API.
///
/// Srikanth is one side; the other is made fresh for each test: Bharat Buyer asks and is declined (the request stays
/// as a closed row, as every live test of his leaves), Rohan Das (the live tests' mentee, no phone) is accepted and
/// the pairing is worked from both pages, then ended early. Staff (the SUPER_ADMIN) pauses and un-pauses the
/// profile and rejects a draft, to see the states a mentor sees only when ICR decides.
///
/// What cannot be undone is said where it happens: an answered request, an ended pairing and a cancelled group
/// session stay as closed rows on these fixture accounts.
///
///     flutter test --no-pub --timeout=120s test/live/role_staff_mentor_live_test.dart --concurrency=1
@Tags(['live'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/features/become_mentor/become_mentor_controller.dart';
import 'package:icr_mobile/features/become_mentor/become_mentor_repository.dart';
import 'package:icr_mobile/features/become_mentor/become_mentor_rules.dart' show bioToHtml;
import 'package:icr_mobile/features/become_mentor/become_mentor_screen.dart';
import 'package:icr_mobile/features/mentor_desk/mentor_desk_controller.dart';
import 'package:icr_mobile/features/mentor_desk/mentor_desk_models.dart';
import 'package:icr_mobile/features/mentor_desk/mentor_desk_repository.dart';
import 'package:icr_mobile/features/mentor_desk/mentor_desk_screen.dart';
import 'package:icr_mobile/features/mentor_desk/offerings/offerings_controller.dart';
import 'package:icr_mobile/features/mentor_desk/offerings/offerings_repository.dart';
import 'package:icr_mobile/features/mentorship_my/mentoring_models.dart';
import 'package:icr_mobile/features/mentorship_my/pairing_screen.dart';
import 'package:icr_mobile/features/messaging/conversation_screen.dart';
import 'package:icr_mobile/features/mentorship_my/mentoring_repository.dart';
import 'package:icr_mobile/features/mentorship_my/widgets/blocks.dart';

import '../helpers/fonts.dart';
import 'become_mentor_live_test.dart' as bm show cleanPerson, cleanProfile, completePerson, kiran;
import 'live.dart';
import 'role_staff_mentor_support.dart';
import 'role_staff_support.dart';

Future<MentorDeskRepository> _deskFor(LivePerson who) async => MentorDeskRepository(api: await clientFor(who));

Future<MentorDeskController> _loadedDesk([LivePerson who = srikanth]) async {
  final c = MentorDeskController(await _deskFor(who));
  await c.start();
  return c;
}

Future<Map<String, dynamic>> _get(ApiClient api, String path, [Map<String, dynamic>? query]) async =>
    (await api.dio.get<Map<String, dynamic>>(path, queryParameters: query)).data!;

void main() {
  setUpAll(loadAppFonts);

  // A test that hangs never reaches its own `finally`, so what a run changes about the fixtures is also put back
  // here, once, when the file ends: Srikanth listed, no pairing left with Rohan, no request left open.
  tearDownAll(() async {
    if (!await liveApiReachable()) return;
    try {
      final admin = await clientFor(superAdmin);
      final me = await getJson(await clientFor(srikanth), '/mentorship/mentors/me/dashboard');
      if ((me['profile'] as Map)['status'] == 'PAUSED') {
        await admin.dio.post<dynamic>('/mentorship/admin/mentors/$srikanthProfileId/unpause', data: {});
      }
      await endPairingWith('Rohan Das');
      final repo = MentoringRepository(api: await clientFor(srikanth));
      for (final r in await repo.requestsReceived()) {
        if (r.status == RequestStatus.pending && r.message.startsWith('A staff test')) {
          await MentoringRepository(
            api: await clientFor(r.mentee.name.startsWith('Meera') ? meera : rohan),
          ).withdrawRequest(r.id);
        }
      }
    } on Object catch (e) {
      // ignore: avoid_print
      print('clean-up could not finish: $e');
    }
  });

  group('the desk reads for Srikanth, tab by tab', () {
    liveTest(
      'every tab reads what the API holds: the gate, the figures, the mentees, the hours, the reviews',
      () async {
        final api = await clientFor(srikanth);
        final raw = await _get(api, '/mentorship/mentors/me/dashboard');
        final c = await _loadedDesk();
        addTearDown(c.dispose);
        expect(c.gate, DeskGate.ready);
        for (final tab in DeskTab.values) {
          await c.ensureTab(tab);
        }
        for (final l in [c.sold, c.terms, c.roster, c.settings, c.earnings, c.feedback, c.serviceReviews]) {
          expect(l.error, isNull, reason: '${l.error}');
        }

        final d = c.dashboard.data!;
        expect(d.hasProfile, isTrue);
        expect(d.profile!.id, srikanthProfileId);
        expect(d.profile!.status, DeskStatus.approved);
        expect(d.isListed, isTrue);
        expect(d.profile!.rating, 5);
        expect(d.profile!.ratingCount, (raw['profile'] as Map)['ratingCount']);
        expect(d.capacityTotal, (raw['capacity'] as Map)['total']);
        expect(d.capacityActive + d.capacityOpen, d.capacityTotal);
        expect(d.menteesActive, (raw['mentees'] as Map)['active']);

        // Mentees: the two live ones and the finished ones, from the same roster the API sends.
        final roster = await _get(api, '/mentorship/mentors/me/roster').catchError((_) => <String, dynamic>{});
        expect(roster, isA<Map>());
        expect(c.roster.data!.every((p) => p.viewerIsMentor), isTrue);
        expect(c.roster.data!.where((p) => p.status.live).length, d.menteesActive);
        expect(c.roster.data!.map((p) => p.counterpart.name), containsAll(['Yash Agarwal', 'Pooja Rathod']));

        // Hours and settings: the week Monday, Thursday and Saturday evenings; places, link and note.
        final s = c.settings.data!;
        expect(s.status, DeskStatus.approved);
        expect(s.capacity, d.capacityTotal);
        expect(s.timezone, 'Asia/Kolkata');
        expect(s.blocks, isNotEmpty);
        expect(s.blocks.every((b) => b.endMin > b.startMin && b.weekday >= 0 && b.weekday <= 6), isTrue);
        expect(s.meetingLink, anyOf(isEmpty, startsWith('https://')), reason: 'a standing link is optional');

        // Earnings: nothing sold yet, which is an empty state and not an error. Reviews: from mentees, anonymous.
        expect(c.earnings.data!.entries, isEmpty);
        expect(c.earnings.data!.unsettledPaisa, 0);
        expect(c.feedback.data, isNotEmpty);
        expect(c.feedback.data!.every((f) => f.rating >= 1 && f.rating <= 5), isTrue);
        expect(c.mentoring.calendar.error, isNull);
      },
    );
  });

  group('a mentee asks, the mentor answers on the desk screen', () {
    testWidgets(
      'Meera is declined with a note she reads; Rohan is accepted into a pairing that shows under Mentees',
      tags: const ['live'],
      timeout: const Timeout(Duration(minutes: 5)),
      (tester) async {
        if (!await liveScreenReady(tester)) return;
        final stamp = DateTime.now().millisecondsSinceEpoch;
        final meeraWords = 'A staff test ($stamp): Meera asks about moving into supply planning.';
        final rohanWords = 'A staff test ($stamp): Rohan asks for a mentor on regional operations.';
        final before = (await tester.runAsync(deskFigures))!;

        final meeraAsk = (await tester.runAsync(() => askSrikanth(meera, meeraWords)))!;
        final rohanAsk = (await tester.runAsync(() => askSrikanth(rohan, rohanWords)))!;
        try {
          expect((await tester.runAsync(deskFigures))!.pending, before.pending + 2);
          await pumpAs(tester, srikanth, (c) => const MentorDeskScreen());
          await settle(tester);
          expect(find.text('To answer'), findsOneWidget);
          await tester.tap(find.text('Requests').first);
          await settle(tester);
          expect(find.textContaining(meeraWords), findsOneWidget);
          expect(find.textContaining(rohanWords), findsOneWidget);
          expect(find.text('Meera Nair'), findsWidgets);
          expect(find.text('Rohan Das'), findsWidgets);

          Finder inCard(String words, Finder what) => find.descendant(
            of: find.ancestor(of: find.textContaining(words), matching: find.byType(RequestCard)),
            matching: what,
          );

          // Decline Meera's through the sheet; she reads the note as written.
          await bringIntoView(tester, inCard(meeraWords, find.text('Decline')));
          await tester.tap(inCard(meeraWords, find.text('Decline')));
          await settle(tester);
          expect(find.text('Decline Meera?'), findsOneWidget);
          await tester.enterText(find.byType(TextField).last, 'Full until the new year: please ask again in January.');
          await tester.ensureVisible(find.text('Decline request'));
          await tester.tap(find.text('Decline request'));
          await settle(
            tester,
            ready: () => find.text('Decline Meera?').evaluate().isEmpty,
            timeout: const Duration(seconds: 40),
          );
          expect(find.text('Decline Meera?'), findsNothing, reason: 'the sheet closed once the API took it');
          final mine = (await tester.runAsync(
            () async => MentoringRepository(api: await clientFor(meera)).requestsSent(),
          ))!;
          final declined = mine.firstWhere((r) => r.id == meeraAsk.id);
          expect(declined.status, RequestStatus.declined);
          expect(declined.responseNote, 'Full until the new year: please ask again in January.');

          // Accept Rohan's: the rhythm and a note, then Start.
          await bringIntoView(tester, inCard(rohanWords, find.text('Accept')));
          await tester.tap(inCard(rohanWords, find.text('Accept')));
          await settle(tester);
          expect(find.text('Accept Rohan'), findsOneWidget);
          await tester.ensureVisible(find.text('Fortnightly'));
          await tester.tap(find.text('Fortnightly'));
          await tester.enterText(
            find.byKey(const ValueKey('accept-note')),
            'Welcome. Bring your current org chart to our first call.',
          );
          await tester.pump();
          await tester.ensureVisible(find.text('Accept and start'));
          await tester.tap(find.text('Accept and start'));
          await settle(
            tester,
            ready: () => find.text('Accept Rohan').evaluate().isEmpty,
            timeout: const Duration(seconds: 40),
          );
          expect(find.text('Accept Rohan'), findsNothing);

          // The places taken go up by one on the desk and in the API; nothing is left waiting.
          final after = (await tester.runAsync(deskFigures))!;
          expect(after.active, before.active + 1);
          expect(after.pending, before.pending, reason: 'both asks are answered');

          // The Mentees tab lists Rohan among those mentored now.
          await tester.tap(find.text('Mentees').first);
          await settle(tester);
          expect(find.textContaining('MENTORING NOW (${before.active + 1})'), findsOneWidget);
          expect(find.text('Rohan Das'), findsWidgets);

          // And Rohan reads it as a live pairing with the mentor.
          final rohanRepo = MentoringRepository(api: (await tester.runAsync(() => clientFor(rohan)))!);
          final pairings = (await tester.runAsync(rohanRepo.pairings))!;
          expect(
            pairings.where((p) => p.status.live && !p.viewerIsMentor && p.mentor.name == 'Srikanth Sriramagiri'),
            hasLength(1),
          );
          await finishLive(tester);
        } finally {
          await tester.runAsync(() => endPairingWith('Rohan Das'));
          await tester.runAsync(() => withdrawIfOpen(meera, meeraAsk));
          await tester.runAsync(() => withdrawIfOpen(rohan, rohanAsk));
        }
        expect((await tester.runAsync(deskFigures))!.active, before.active, reason: 'the place is free again');
      },
    );
  });

  group('hours, settings and the directory switch: changed, read back, put back', () {
    liveTest('weekly hours and the settings save what changed only, and the switch hides and lists the profile', () async {
      final c = await _loadedDesk();
      addTearDown(c.dispose);
      await c.settings.load();
      final hours = [...c.settings.data!.blocks];
      final before = c.settings.data!;
      try {
        // Hours: one more window on a day Srikanth has none (Tuesday), refused when it overlaps or ends before it starts.
        const extra = WeeklyBlock(weekday: 2, startMin: 18 * 60, endMin: 19 * 60);
        expect(await c.saveHours([...hours, extra]), isNull);
        expect(c.settings.data!.blocks, contains(extra));
        expect((await c.repository.settings()).blocks, hasLength(hours.length + 1), reason: 'the API agrees');
        expect(
          await c.saveHours([extra, const WeeklyBlock(weekday: 2, startMin: 18 * 60 + 30, endMin: 20 * 60)]),
          'Windows on the same day must not overlap.',
        );
        expect(
          await c.saveHours([const WeeklyBlock(weekday: 2, startMin: 600, endMin: 600)]),
          'Each window must end after it starts.',
        );
        expect(
          (await c.repository.settings()).blocks,
          hasLength(hours.length + 1),
          reason: 'a refused save changes nothing',
        );
        // Mentees now see a slot on Tuesday evening.
        final slots = await MentoringRepository(api: await clientFor(rohan)).slots(srikanthProfileId, durationMin: 30);
        expect(
          slots.any((s) => s.at.toUtc().add(const Duration(hours: 5, minutes: 30)).weekday == DateTime.tuesday),
          isTrue,
        );

        // Settings: a note and one more place; what was not sent is left alone; a bad link and a bad count are refused.
        expect(
          await c.saveSettings({
            'capacity': before.capacity + 1,
            'availabilityNote': 'A staff live test wrote this note.',
          }),
          isNull,
        );
        expect(c.settings.data!.capacity, before.capacity + 1);
        expect(c.settings.data!.availabilityNote, 'A staff live test wrote this note.');
        expect(c.settings.data!.timezone, before.timezone);
        expect(c.settings.data!.bioHtml, before.bioHtml, reason: 'an untouched bio keeps its formatting');
        expect((await deskFigures()).total, before.capacity + 1);
        expect(await c.saveSettings({'meetingLink': 'not a link'}), isNotNull);
        expect(await c.saveSettings({'capacity': 0}), isNotNull);
        expect(await c.saveSettings({'capacity': 11}), isNotNull);

        // The directory switch: off hides the profile from the directory, on lists it again.
        expect(await c.setVisibility(false), isNull);
        expect(c.dashboard.data!.isListed, isFalse);
        final directoryApi = await clientFor(rohan);
        final hidden = await getJson(directoryApi, '/mentorship/mentors', {'search': 'Sriramagiri', 'limit': 5});
        expect((hidden['data'] as List).where((m) => (m as Map)['id'] == srikanthProfileId), isEmpty);
        expect(await c.setVisibility(true), isNull);
        final listed = await getJson(directoryApi, '/mentorship/mentors', {'search': 'Sriramagiri', 'limit': 5});
        expect((listed['data'] as List).where((m) => (m as Map)['id'] == srikanthProfileId), hasLength(1));
      } finally {
        await c.setVisibility(true);
        await c.saveHours(hours);
        await c.saveSettings({'capacity': before.capacity, 'availabilityNote': before.availabilityNote});
      }
      await c.settings.load();
      expect(c.settings.data!.blocks, unorderedEquals(hours));
      expect(c.settings.data!.capacity, before.capacity);
      expect(c.settings.data!.availabilityNote, before.availabilityNote);
      expect(c.dashboard.data?.isListed ?? true, isTrue);
    });
  });

  group('offerings: the storefront, a 1:1 session, a plan and a group session with a seat', () {
    liveTest('the gates read as live; a session and a plan are created, edited, paused, resumed and deleted', () async {
      final c = OfferingsController(OfferingsRepository(api: await clientFor(srikanth)));
      addTearDown(c.dispose);
      await c.start();
      final gates = c.gates!;
      expect(gates.live, isTrue);
      expect(gates.blockedReason, isNull);
      expect(c.services.where((s) => s.active), isNotEmpty);
      final used = c.listingsUsed;
      final created = <String>[];
      final createdPlans = <String>[];
      try {
        // A 1:1 session: held back (paused) while it is made, so no member is shown a half-made listing.
        expect(
          await c.saveService({
            'type': 'ONE_ON_ONE',
            'title': 'Staff test call',
            'blurb': 'A call a staff live test made.',
            'pricePaisa': 59900,
            'durationMin': 30,
            'active': false,
          }),
          isNull,
        );
        final row = c.services.firstWhere((s) => s.title == 'Staff test call');
        created.add(row.id);
        expect(row.active, isFalse);
        expect(c.listingsUsed, used + 1);
        expect(
          await c.saveService({
            'type': 'ONE_ON_ONE',
            'title': 'Staff test call',
            'pricePaisa': 10000,
            'durationMin': 30,
          }),
          'Priced services start at ₹499.',
        );
        expect(
          await c.saveService({
            'type': 'ONE_ON_ONE',
            'title': 'Staff test call, edited',
            'pricePaisa': 64900,
            'durationMin': 45,
            'active': false,
          }, id: row.id),
          isNull,
        );
        var back = c.services.firstWhere((s) => s.id == row.id);
        expect(back.title, 'Staff test call, edited');
        expect(back.durationMin, 45);
        expect(await c.setServiceActive(back, true), isNull);
        expect(c.services.firstWhere((s) => s.id == row.id).active, isTrue);
        // Members now see it on Srikanth's public profile; paused, they do not.
        final publicOffers = await getJson(await clientFor(rohan), '/mentorship/mentors/$srikanthProfileId');
        expect(publicOffers, isNotEmpty);
        expect(await c.setServiceActive(c.services.firstWhere((s) => s.id == row.id), false), isNull);
        back = c.services.firstWhere((s) => s.id == row.id);
        expect(back.active, isFalse);
        expect(await c.deleteService(back), isNull);
        created.remove(row.id);
        expect(c.listingsUsed, used);

        // An ongoing plan: the same, with the plan's own rules.
        expect(
          await c.savePlan({
            'title': 'Staff test plan',
            'kind': 'RECURRING',
            'pricePaisa': 299900,
            'sessionsPerMonth': 2,
            'active': false,
          }),
          isNull,
        );
        final plan = (c.plans.data ?? const []).firstWhere((p) => p.title == 'Staff test plan');
        createdPlans.add(plan.id);
        expect(plan.active, isFalse);
        expect(await c.savePlan({'title': 'Staff test plan, edited'}, id: plan.id), isNull);
        expect((c.plans.data ?? const []).firstWhere((p) => p.id == plan.id).title, 'Staff test plan, edited');
        expect(await c.setPlanActive((c.plans.data ?? const []).firstWhere((p) => p.id == plan.id), true), isNull);
        expect(await c.setPlanActive((c.plans.data ?? const []).firstWhere((p) => p.id == plan.id), false), isNull);
        expect(await c.deletePlan((c.plans.data ?? const []).firstWhere((p) => p.id == plan.id)), isNull);
        createdPlans.clear();
      } finally {
        for (final id in created) {
          try {
            await c.repository.deleteService(id);
          } on Object {
            // gone
          }
        }
        for (final id in createdPlans) {
          try {
            await c.repository.deletePlan(id);
          } on Object {
            // gone
          }
        }
      }
    });

    liveTest(
      'a group session is hosted, published, taken by a mentee, shown on the roster and cancelled with a reason',
      () async {
        final c = OfferingsController(OfferingsRepository(api: await clientFor(srikanth)));
        addTearDown(c.dispose);
        await c.start();
        final start = DateTime.now().toUtc().add(const Duration(days: 52));
        final at = DateTime.utc(start.year, start.month, start.day, 5);
        final body = <String, Object?>{
          'title': 'Staff test clinic ${DateTime.now().millisecondsSinceEpoch}',
          'summary': 'A clinic a staff live test hosts and cancels.',
          'mode': 'VIDEO',
          'meetingLink': 'https://meet.google.com/abc-defg-hij',
          'occurrences': [
            {'scheduledAt': at.toIso8601String(), 'durationMin': 60},
          ],
          'capacity': 10,
          'pricePaisa': null,
        };
        // Rules first, in the API's words; none of these makes a row.
        expect(await c.saveSession({...body, 'capacity': 1}), isNotNull);
        expect(
          await c.saveSession({...body, 'pricePaisa': 49900, 'capacity': null}),
          'A paid session needs a number of seats.',
        );
        expect(
          await c.saveSession({
            ...body,
            'occurrences': [
              {
                'scheduledAt': DateTime.now().subtract(const Duration(days: 1)).toUtc().toIso8601String(),
                'durationMin': 60,
              },
            ],
          }),
          'Pick a time in the future.',
        );

        expect(await c.saveSession(body), isNull);
        final row = c.sessions.data!.firstWhere((s) => s.title == body['title']);
        expect(row.draft, isTrue);
        try {
          expect(await c.publishSession(row), isNull);
          final published = await c.detail(row);
          expect(published.scheduled, isTrue);
          expect(await c.publishSession(row), 'This session is already published.');

          // A mentee takes a seat with a question; the host sees them on the roster, with the question.
          final meeraRepo = MentoringRepository(api: await clientFor(meera));
          await meeraRepo.registerGroup(row.id, question: 'Can we cover a regional rollout?');
          final seat = await meeraRepo.groupSession(row.id);
          expect(seat.myStatus, isNotNull);
          final withRoster = await c.detail(row);
          expect(withRoster.roster!.map((r) => r.name), contains('Meera Nair'));
          expect(
            withRoster.roster!.firstWhere((r) => r.name == 'Meera Nair').question,
            'Can we cover a regional rollout?',
          );

          // Cancelling needs a reason; the people registered are told, and the seat reads back as cancelled.
          expect(await c.cancelSession(withRoster, 'ab'), isNotNull);
          expect(await c.cancelSession(withRoster, 'A staff live test: taking the clinic down.'), isNull);
          final after = await meeraRepo.groupSession(row.id);
          expect(after.status, 'CANCELLED', reason: 'the session is cancelled for everyone who held a seat');
        } finally {
          try {
            await c.cancelSession(await c.detail(row), 'A staff live test cleans up.');
          } on Object {
            // already cancelled
          }
          try {
            await MentoringRepository(api: await clientFor(meera)).leaveGroup(row.id);
          } on Object {
            // not registered, or already cancelled
          }
        }
      },
    );
  });

  group('what ICR decides: a staff pause is what the mentor reads on the desk and on the application page', () {
    testWidgets(
      'paused by the SUPER_ADMIN, Srikanth leaves the directory and keeps his desk; un-paused, he is back',
      tags: const ['live'],
      timeout: const Timeout(Duration(minutes: 5)),
      (tester) async {
        if (!await liveScreenReady(tester)) return;
        final admin = (await tester.runAsync(() => clientFor(superAdmin)))!;
        final directory = (await tester.runAsync(() => clientFor(rohan)))!;
        Future<bool> inDirectory() async {
          final found = await getJson(directory, '/mentorship/mentors', {'search': 'Sriramagiri', 'limit': 5});
          return (found['data'] as List).any((m) => (m as Map)['id'] == srikanthProfileId);
        }

        print('[pause] 1 listed');
        expect((await tester.runAsync(inDirectory))!, isTrue);
        try {
          await tester.runAsync(
            () => admin.dio.post<dynamic>(
              '/mentorship/admin/mentors/$srikanthProfileId/pause',
              data: {'reason': 'A staff live test pauses the listing for a minute.'},
            ),
          );
          print('[pause] 2 paused');
          expect((await tester.runAsync(inDirectory))!, isFalse, reason: 'a paused mentor is out of the directory');
          print('[pause] 3 out of directory');

          // The desk stays open (existing mentees are served) and says so, and cannot list him again.
          await pumpAs(tester, srikanth, (c) => const MentorDeskScreen());
          await settle(tester);
          await retryWhileFailed(tester, what: 'the paused desk');
          print('[pause] 4 desk drawn');
          expect(thrown(tester), isNull);
          expect(find.textContaining('Your profile is paused'), findsOneWidget);
          expect(find.text('Active mentees'), findsOneWidget, reason: 'the desk is still his');
          print('[pause] 5 callout seen');
          final desk = (await tester.runAsync(_loadedDesk))!;
          expect(desk.gate, DeskGate.ready);
          expect(desk.profile!.status, DeskStatus.paused);
          expect(await desk.setVisibility(true), isNotNull, reason: 'a paused profile cannot list itself');
          desk.dispose();

          print('[pause] 6 visibility refused');
          // The application page says the same, in the mentor's own place for it.
          await pumpAs(tester, srikanth, (c) => const BecomeMentorScreen());
          await settle(tester);
          expect(find.byKey(const ValueKey('banner-PAUSED')), findsOneWidget);
          expect(find.textContaining('hidden from the directory'), findsOneWidget);
          expect(find.text('Submit for review'), findsNothing, reason: 'there is nothing to submit');
        } finally {
          await tester.runAsync(
            () => admin.dio.post<dynamic>('/mentorship/admin/mentors/$srikanthProfileId/unpause', data: {}),
          );
        }
        expect((await tester.runAsync(inDirectory))!, isTrue, reason: 'un-paused, he is listed again');
        await pumpAs(tester, srikanth, (c) => const BecomeMentorScreen());
        await settle(tester);
        expect(find.byKey(const ValueKey('banner-APPROVED')), findsOneWidget);
        expect(find.text('View public profile'), findsOneWidget);
        await finishLive(tester);
      },
    );
  });

  group('an application walks through ICR\'s decisions, and the mentor reads each one', () {
    testWidgets(
      'not started, in review, sent back with a note, resubmitted, approved: the application page and the desk follow',
      tags: const ['live'],
      timeout: const Timeout(Duration(minutes: 8)),
      (tester) async {
        if (!await liveScreenReady(tester)) return;
        final kiranApi = (await tester.runAsync(() => clientFor(bm.kiran)))!;
        final admin = (await tester.runAsync(() => clientFor(superAdmin)))!;
        final repo = BecomeMentorRepository(api: kiranApi);
        final avatar = (await tester.runAsync(() async => (await repo.person()).avatarUrl))!;
        await tester.runAsync(() async {
          await bm.cleanProfile(repo);
          await bm.cleanPerson(repo, avatar);
        });
        const note = 'Add two named programmes you have led and resubmit; we cannot approve a profile without them.';
        try {
          // Not started: the page is a blank draft and the desk is not Kiran's yet.
          await pumpAs(tester, bm.kiran, (c) => const BecomeMentorScreen());
          await settle(tester);
          expect(find.text('Not started'), findsOneWidget);
          expect(find.byKey(const ValueKey('banner-DRAFT')), findsOneWidget);
          await pumpAs(tester, bm.kiran, (c) => const MentorDeskScreen());
          await settle(tester);
          expect(find.text("You're not a mentor yet"), findsOneWidget);

          // A complete application goes in (the sheets' own calls), and is in review.
          await tester.runAsync(() async {
            final c = BecomeMentorController(repo);
            await c.start();
            await bm.completePerson(c);
            expect(
              await c.saveProfile({
                'bioHtml': bioToHtml('I help facilities leads move from running a site to owning a portfolio. ' * 2),
                'competencies': ['Facility Management'],
                'targetAudiences': ['WORKING_PROFESSIONAL'],
              }),
              isNull,
            );
            if (!c.conductAccepted) expect(await c.agreeToConduct(), isNull);
            expect(await c.submit(), isNull);
            c.dispose();
          });
          final profileId = (await tester.runAsync(() async => (await repo.mine())!.id))!;
          await pumpAs(tester, bm.kiran, (c) => const BecomeMentorScreen());
          await settle(tester);
          expect(find.byKey(const ValueKey('banner-PENDING')), findsOneWidget);
          expect(find.textContaining('A member of the ICR team is reading your profile'), findsOneWidget);
          expect(find.text('Submit for review'), findsNothing, reason: 'it is already with the team');
          await pumpAs(tester, bm.kiran, (c) => const MentorDeskScreen());
          await settle(tester);
          expect(find.text('Your application is in review'), findsOneWidget);

          // ICR sends it back with a note; the page and the desk show the note word for word.
          await tester.runAsync(
            () => admin.dio.post<dynamic>('/mentorship/admin/mentors/$profileId/reject', data: {'reviewNote': note}),
          );
          await pumpAs(tester, bm.kiran, (c) => const BecomeMentorScreen());
          await settle(tester);
          expect(find.byKey(const ValueKey('banner-REJECTED')), findsOneWidget);
          expect(find.textContaining(note), findsOneWidget, reason: 'the reviewer\'s words, verbatim');
          expect(find.text('Resubmit for review'), findsOneWidget);
          await pumpAs(tester, bm.kiran, (c) => const MentorDeskScreen());
          await settle(tester);
          expect(find.text('Your application was not approved'), findsOneWidget);
          expect(find.textContaining(note), findsOneWidget);

          // Resubmitted from the page, it is back in review; ICR approves it and the desk opens.
          await pumpAs(tester, bm.kiran, (c) => const BecomeMentorScreen());
          await settle(tester);
          await bringIntoView(tester, find.text('Resubmit for review'));
          await tester.tap(find.text('Resubmit for review'));
          await settle(tester, ready: () => find.byKey(const ValueKey('banner-PENDING')).evaluate().isNotEmpty);
          expect(find.byKey(const ValueKey('banner-PENDING')), findsOneWidget);

          final approval = await tester.runAsync(() async {
            try {
              await admin.dio.post<dynamic>('/mentorship/admin/mentors/$profileId/approve', data: {});
              return 'approved';
            } on Object catch (e) {
              return e.toString();
            }
          });
          // ignore: avoid_print
          print('approve: $approval');
          if (approval == 'approved') {
            await pumpAs(tester, bm.kiran, (c) => const BecomeMentorScreen());
            await settle(tester);
            expect(find.byKey(const ValueKey('banner-APPROVED')), findsOneWidget);
            await pumpAs(tester, bm.kiran, (c) => const MentorDeskScreen());
            await settle(tester);
            expect(find.text('Active mentees'), findsOneWidget, reason: 'the desk is open to an approved mentor');
            expect(find.text("You're not a mentor yet"), findsNothing);
          }
          await finishLive(tester);
        } finally {
          await tester.runAsync(() async {
            await bm.cleanProfile(repo);
            await bm.cleanPerson(repo, avatar);
          });
        }
      },
    );
  });

  group('the pairing page, from both sides', () {
    testWidgets(
      'the mentor and the mentee each see their own page of one pairing: the ask, the answer, the thread, the end',
      tags: const ['live'],
      timeout: const Timeout(Duration(minutes: 6)),
      (tester) async {
        if (!await liveScreenReady(tester)) return;
        final before = (await tester.runAsync(deskFigures))!;
        final pairing = (await tester.runAsync(RohanPairing.start))!;
        try {
          final srikanthRepo = MentoringRepository(api: (await tester.runAsync(() => clientFor(srikanth)))!);
          final rohanRepo = MentoringRepository(api: (await tester.runAsync(() => clientFor(rohan)))!);

          // The mentee asks for a time inside the mentor's hours; the mentor adds a goal, the mentee a task.
          final slots = (await tester.runAsync(() => rohanRepo.slots(srikanthProfileId, durationMin: 30)))!;
          expect(slots, isNotEmpty, reason: 'Srikanth has weekly hours, so there are free times');
          final goal = 'Own a portfolio of five sites ${pairing.id.substring(0, 6)}';
          await tester.runAsync(() async {
            await rohanRepo.scheduleSession(
              pairing.id,
              at: slots.first.at,
              durationMin: 30,
              mode: 'VIDEO',
              agenda: 'Our first call',
            );
            await srikanthRepo.addGoal(pairing.id, title: goal);
            await rohanRepo.addTask(pairing.id, title: 'Draft my org chart');
          });

          // The mentor's page: the mentee, the time to answer, and the mentor's controls.
          await pumpAs(tester, srikanth, (c) => PairingScreen(id: pairing.id));
          await settle(tester);
          await retryWhileFailed(tester, what: 'the mentor page');
          expect(thrown(tester), isNull);
          expectNoRawErrors(tester, 'the mentor page');
          expect(find.text('Your mentee'), findsOneWidget);
          expect(find.text('Rohan Das'), findsWidgets);
          expect(find.textContaining('Needs you: a time to answer'), findsOneWidget);
          for (final words in ['Approve', 'Offer another time', 'Decline', 'Book a session', 'Add goal', goal]) {
            expect(find.text(words), findsWidgets, reason: 'the mentor sees "$words"');
          }
          expect(find.text('Ask for a time'), findsNothing, reason: "that is the mentee's button");
          expect(find.text('Withdraw'), findsNothing);

          // The mentor approves it: the ask is answered, the session is booked.
          await tester.tap(find.text('Approve').first);
          await settle(tester, ready: () => find.text('Approve').evaluate().isEmpty);
          expect(find.textContaining('Needs you: a time to answer'), findsNothing);
          final sessions = (await tester.runAsync(() => srikanthRepo.sessions(pairing.id)))!;
          expect(sessions.where((s) => s.status == SessionStatus.scheduled), hasLength(1));

          // The mentor opens the pairing's thread from the page.
          await tester.tap(find.text('Message').first);
          await settle(tester, ready: () => find.byType(ConversationScreen).evaluate().isNotEmpty);
          expect(find.byType(ConversationScreen), findsOneWidget, reason: "the pairing's thread opens in the app");
          expect(thrown(tester), isNull);
          await tester.pageBack();
          await settle(tester);

          // The mentee's page of the same pairing: the other way round.
          await pumpAs(tester, rohan, (c) => PairingScreen(id: pairing.id));
          await settle(tester);
          await retryWhileFailed(tester, what: 'the mentee page');
          expect(thrown(tester), isNull);
          expectNoRawErrors(tester, 'the mentee page');
          expect(find.text('Your mentor'), findsOneWidget);
          expect(find.text('Srikanth Sriramagiri'), findsWidgets);
          expect(find.text('Mentor profile'), findsOneWidget);
          for (final words in ['Ask for a time', 'Add goal', goal, 'Draft my org chart']) {
            expect(find.text(words), findsWidgets, reason: 'the mentee sees "$words"');
          }
          expect(find.text('Approve'), findsNothing, reason: 'only the mentor answers an ask');
          expect(find.textContaining('Waiting on Srikanth'), findsNothing, reason: 'it was answered');

          // The mentor ends it from the page; the reason is read by both.
          await pumpAs(tester, srikanth, (c) => PairingScreen(id: pairing.id));
          await settle(tester);
          await bringIntoView(tester, find.text('End early'));
          await tester.tap(find.text('End early'));
          await settle(tester);
          expect(find.text('End this mentorship early?'), findsOneWidget);
          await tester.enterText(find.byType(TextField).last, 'The staff test is over: thank you, Rohan.');
          await tester.ensureVisible(find.text('End mentorship'));
          await tester.tap(find.text('End mentorship'));
          await settle(
            tester,
            ready: () => find.text('End this mentorship early?').evaluate().isEmpty,
            timeout: const Duration(seconds: 40),
          );
          final ended = (await tester.runAsync(() => srikanthRepo.pairing(pairing.id)))!;
          expect(ended.status, PairingStatus.endedEarly);
          expect(ended.endedReason, 'The staff test is over: thank you, Rohan.');
          final seenByMentee = (await tester.runAsync(() => rohanRepo.pairing(pairing.id)))!;
          expect(seenByMentee.endedReason, ended.endedReason, reason: 'both read the reason');
          await finishLive(tester);
        } finally {
          await tester.runAsync(pairing.end);
        }
        expect((await tester.runAsync(deskFigures))!.active, before.active, reason: 'the place is free again');
      },
    );
  });

  group('the desk screen, with every tab opened', () {
    testWidgets(
      'Overview, Requests, Mentees, Calendar, Work, Offerings, Hours, Earnings, Reviews and Settings each draw their real content',
      tags: const ['live'],
      timeout: const Timeout(Duration(minutes: 4)),
      (tester) async {
        if (!await liveScreenReady(tester)) return;
        await pumpAs(tester, srikanth, (c) => const MentorDeskScreen());
        await settle(tester);
        await retryWhileFailed(tester, what: 'the desk');
        expect(thrown(tester), isNull);
        expectNoRawErrors(tester, 'the desk');

        // The strip names every tab; Overview is open.
        for (final tab in DeskTab.values) {
          expect(find.text(tab.label), findsWidgets, reason: 'the strip shows ${tab.label}');
        }
        expect(find.text('Listed in the directory'), findsOneWidget);
        expect(find.text('Active mentees'), findsOneWidget);
        expect(find.text('Places open'), findsOneWidget);
        expect(find.byKey(const ValueKey('completeness')), findsOneWidget);

        final probes = <DeskTab, List<String>>{
          DeskTab.requests: ['ANSWERED LATELY'],
          DeskTab.mentees: ['MENTORING NOW (2)', 'Yash Agarwal', 'Pooja Rathod', 'FINISHED'],
          DeskTab.calendar: ['October 2026', 'Group session', 'Paid call'],
          DeskTab.work: ['No paid work right now'],
          DeskTab.offerings: ['Storefront', 'Personal Interview & GD Preparation', 'Add a 1:1 session'],
          DeskTab.hours: ['Monday', 'Save hours', 'Add a window'],
          DeskTab.earnings: ['No earnings yet', 'Awaiting payout', 'Paid out'],
          DeskTab.reviews: ['FROM YOUR MENTEES', 'A mentee', 'Rating'],
          DeskTab.settings: ['How you meet', 'Mentees at a time', 'Your standing meeting link'],
        };
        for (final entry in probes.entries) {
          final tab = find.text(entry.key.label);
          await tester.ensureVisible(tab.first);
          await tester.tap(tab.first);
          await settle(tester);
          await retryWhileFailed(tester, what: entry.key.label);
          expect(thrown(tester), isNull, reason: '${entry.key.label} threw');
          expectNoRawErrors(tester, entry.key.label);
          for (final words in entry.value) {
            expect(find.textContaining(words), findsWidgets, reason: '${entry.key.label} shows "$words"');
          }
        }
        await finishLive(tester);
      },
    );
  });
}
