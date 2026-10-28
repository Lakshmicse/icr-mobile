/// After a mentor is found (My mentoring, a pairing, purchases, group sessions,
/// programmes, becoming a mentor, the mentor's desk) against the LOCAL API,
/// with the people `tool/seed/mentoring.ts` makes. Each control that reads or
/// writes through the API is exercised through the screens' own repository and
/// controllers and proved by reading the effect back; what a test does it
/// undoes where the API allows, and says so where it cannot (a request that was
/// answered stays answered: the test sends a fresh one, from a person who has
/// no other part in the fixtures, and the seed's `--remove` sweeps it).
///
///     flutter test test/live/mentoring_live_test.dart --concurrency=1
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/features/mentorship_my/mentoring_models.dart';
import 'package:icr_mobile/features/mentorship_my/mentoring_repository.dart';
import 'package:icr_mobile/features/mentorship_my/my_mentoring_controller.dart';

import 'live.dart';
import 'package:icr_mobile/features/mentorship_my/pairing_controller.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/features/mentorship_my/mentoring_format.dart';
import 'package:icr_mobile/features/mentorship_my/purchases_tab.dart';
import 'dart:typed_data';

const _password = 'Password123!';
const anand = LivePerson('mentoring.anand@design.icr.test', _password, 'Anand Iyer (mentor desk)');
const rohan = LivePerson('mentoring.rohan@design.icr.test', _password, 'Rohan Das (sender)');
const meera = LivePerson('mentoring.meera@design.icr.test', _password, 'Meera Nair (mentee)');
const kiran = LivePerson('mentoring.kiran@design.icr.test', _password, 'Kiran Shah (applicant)');

const anandProfile = 'dsgn-mentoring-mp-anand';
const nehaProfile = 'dsgn-mentoring-mp-neha';
const bharatLivePairing = 'dsgn-mentoring-pair-bharat-anand';
const bharatDonePairing = 'dsgn-mentoring-pair-bharat-divya';

/// A number the API takes as a mobile; the person who sends a request with it gets it saved, so a test clears it.
const aPhone = '9876501234';

Future<MentoringRepository> repoFor(LivePerson who) async => MentoringRepository(api: await liveClient(who));

Future<MyMentoringController> loadedFor(LivePerson who) async {
  final c = MyMentoringController(await repoFor(who));
  await c.start();
  return c;
}

/// Sends a mentoring request the way the Mentor Profile does (a number rides along), and returns its id.
Future<String> sendRequest(ApiClient api, String mentorProfileId, {String? message}) async {
  final res = await api.dio.post<Map<String, dynamic>>(
    '/mentorship/requests',
    data: {
      'mentorProfileId': mentorProfileId,
      'message': message ?? 'I would like to learn how you plan workplace programmes for a campus site.',
      'phone': aPhone,
    },
  );
  return res.data!['id'] as String;
}

/// The test persona's number back to what the seed left: none.
Future<void> clearPhone(ApiClient api) async {
  await api.dio.patch<dynamic>('/users/me', data: {'phone': ''});
}

const neha = LivePerson('mentoring.neha@design.icr.test', _password, 'Neha Kapoor (mentor)');

/// A pairing made for one test: Rohan asks Neha, Neha accepts. Nothing else in the fixtures has a part in it, so a
/// test may do what cannot be undone (complete it, review it, report a concern) and [end] closes it.
class FreshPairing {
  FreshPairing(this.id, this.mentee, this.mentor);

  final String id;
  final PairingController mentee;
  final PairingController mentor;

  static Future<FreshPairing> start() async {
    final rohanApi = await liveClient(rohan);
    final requestId = await sendRequest(
      rohanApi,
      nehaProfile,
      message: 'Could you guide me through campus workplace programme design?',
    );
    await clearPhone(rohanApi);
    final nehaRepo = await repoFor(neha);
    await nehaRepo.respondToRequest(requestId, accept: true, note: 'Welcome.', cadence: 'FORTNIGHTLY');
    final pairings = await nehaRepo.pairings();
    final id = pairings.firstWhere((p) => p.status.live && p.counterpart.name == 'Rohan Das').id;
    final mentee = PairingController(await repoFor(rohan), id);
    final mentor = PairingController(nehaRepo, id);
    await Future.wait([mentee.load(), mentor.load()]);
    return FreshPairing(id, mentee, mentor);
  }

  /// The first free start (in Neha's weekly hours) on the [day]th distinct day with one, so two picks never overlap.
  Future<DateTime> slot({int day = 0, int minutes = 45}) async {
    final slots = await mentee.repository.slots(nehaProfile, durationMin: minutes);
    final firsts = <String, DateTime>{};
    for (final s in slots) {
      final l = s.at.toLocal();
      firsts.putIfAbsent('${l.year}-${l.month}-${l.day}', () => s.at);
    }
    return firsts.values.elementAt(day);
  }

  Future<void> end() async {
    try {
      await mentor.load();
      if (mentor.pairing?.status.live ?? false) {
        await mentor.repository.updatePairing(
          id,
          PairingStatus.endedEarly,
          endedReason: 'A live test: ending the fixture pairing.',
        );
      }
    } on Object {
      // already closed
    }
  }
}

const anandUserProfile = 'dsgn-mentoring-mp-anand';
const discoveryService = 'dsgn-mentoring-svc-discovery';
const strategyService = 'dsgn-mentoring-svc-strategy';
const workbookService = 'dsgn-mentoring-svc-workbook';
const programmePlan = 'dsgn-mentoring-plan-programme';
const circleSlug = 'early-career-mentoring-circle-design';
const clinicGroup = 'dsgn-mentoring-group-clinic';
const paidGroup = 'dsgn-mentoring-group-paid';
const pastGroup = 'dsgn-mentoring-group-past';

/// A first start Anand can take, [days] days out or later, for a [minutes]-minute call.
Future<DateTime> anandSlot({int minutes = 30, int skipDays = 1}) async {
  final repo = await repoFor(anand);
  final slots = await repo.slots(anandUserProfile, durationMin: minutes);
  final firsts = <String, DateTime>{};
  for (final s in slots) {
    final l = s.at.toLocal();
    firsts.putIfAbsent('${l.year}-${l.month}-${l.day}', () => s.at);
  }
  return firsts.values.elementAt(skipDays);
}

/// Rohan asks Anand for a session (the way the Mentor Profile does, a number riding along), and returns its id.
Future<String> askAnand(String serviceId, {String? topic}) async {
  final api = await liveClient(rohan);
  final res = await api.dio.post<Map<String, dynamic>>(
    '/mentor-services/$serviceId/request',
    data: {
      'topic': topic ?? 'I would like to talk through my move from running a site to a portfolio role.',
      'mode': 'VIDEO',
      'phone': aPhone,
    },
  );
  await clearPhone(api);
  return res.data!['id'] as String;
}

/// Anand sets the time on a request (the mentor's half, done as the API takes it).
Future<void> anandAccepts(String purchaseId, DateTime at) async {
  final api = await liveClient(anand);
  await api.dio.post<dynamic>(
    '/mentor-services/purchases/$purchaseId/accept',
    data: {'scheduledAt': at.toUtc().toIso8601String()},
  );
}

/// Takes a fixture session back whatever state a failed test left it in.
Future<void> cleanUpPurchase(String id) async {
  final repo = await repoFor(rohan);
  try {
    await repo.cancelBooking(id, 'A live test: cleaning up');
  } on Object {
    await repo.withdrawPurchaseRequest(id).then((_) {}, onError: (_) {});
  }
}

Future<ServicePurchase> purchaseOf(MyMentoringController c, String id) async {
  await c.book.purchases.load();
  return c.book.purchases.data!.firstWhere((p) => p.id == id);
}

void main() {
  group('after finding a mentor: My mentoring', () {
    liveTest('the reads behind every tab parse the API\'s real answers (Bharat, a mentee of two)', () async {
      final c = await loadedFor(bharat);
      for (final tab in MyTab.values) {
        await c.ensureTab(tab);
      }
      expect(c.summary.error, isNull, reason: '${c.summary.error}');
      expect(c.summary.data!.activeAsMentee, greaterThanOrEqualTo(1));
      expect(c.summary.data!.isMentor, isFalse);
      expect(c.actsAsMentee, isTrue);
      expect(c.actsAsMentor, isFalse);

      final live = c.livePairings.firstWhere((p) => p.id == bharatLivePairing);
      expect(live.viewerIsMentor, isFalse);
      expect(live.counterpart.name, 'Anand Iyer');
      expect(live.counterpart.subline, contains('Prestige Group'));
      expect(live.mentorProfileId, anandProfile);
      expect(live.status, PairingStatus.active);
      expect(live.cadence, 'FORTNIGHTLY');
      expect(live.sessionsCount, greaterThan(0));
      final done = c.finishedPairings.firstWhere((p) => p.id == bharatDonePairing);
      expect(done.status, PairingStatus.completed);
      expect(done.completedAt, isNotNull);

      expect(c.sent.error, isNull, reason: '${c.sent.error}');
      final sent = {for (final r in c.sent.data!) r.id: r};
      expect(sent['dsgn-mentoring-req-bharat-pending']!.status, RequestStatus.pending);
      expect(sent['dsgn-mentoring-req-bharat-pending']!.mentor.name, 'Neha Kapoor');
      expect(sent['dsgn-mentoring-req-bharat-pending']!.expiresAt, isNotNull);
      expect(sent['dsgn-mentoring-req-bharat-declined']!.status, RequestStatus.declined);
      expect(sent['dsgn-mentoring-req-bharat-declined']!.responseNote, contains('cohort is full'));
      expect(sent['dsgn-mentoring-pair-bharat-anand-req']!.status, RequestStatus.accepted);

      expect(c.upcoming.error, isNull, reason: '${c.upcoming.error}');
      final next = c.upcoming.data!.firstWhere((s) => s.mentorshipId == bharatLivePairing);
      expect(next.counterpart!.name, 'Anand Iyer');
      expect(next.durationMin, 45);
      expect(next.meetingLink, isNotNull);
      expect(next.status, SessionStatus.scheduled);
      expect(c.nextSessionOf(bharatLivePairing)?.id, next.id);

      expect(c.quota.error, isNull, reason: '${c.quota.error}');
      expect(c.quota.data!.canRequest, isTrue);
      expect(c.quota.data!.tier, isNotNull);

      expect(c.goals.error, isNull, reason: '${c.goals.error}');
      final goals = {for (final g in c.goals.data!) g.id: g};
      expect(goals['$bharatLivePairing-g1']!.progress, 40);
      expect(goals['$bharatLivePairing-g1']!.counterpartName, 'Anand Iyer');
      expect(goals['$bharatLivePairing-g1']!.targetDate, isNotNull);
      expect(goals['$bharatLivePairing-g3']!.status, GoalStatus.achieved);

      expect(c.certificates.error, isNull, reason: '${c.certificates.error}');
      final cert = c.certificates.data!.single;
      expect(cert.certificateId, startsWith('ICR-MENTEE-2026-'));
      expect(cert.counterpartName, 'Divya Rao');
      expect(cert.sessionsCount, 5);
      expect(cert.hours, 3.75);

      expect(c.concerns.error, isNull, reason: '${c.concerns.error}');
      expect(c.saved.error, isNull, reason: '${c.saved.error}');
      expect(c.intent.error, isNull, reason: '${c.intent.error}');
      expect(c.intent.data, isNull, reason: 'Bharat has written no intent: the API answers an empty body');
      expect(c.focusOptions.data, isNotEmpty);
      expect(c.calendar.error, isNull, reason: '${c.calendar.error}');
    });

    liveTest('the calendar reads a month, and the seeded session sits on its day', () async {
      final repo = await repoFor(bharat);
      final next = (await repo.upcomingSessions()).firstWhere((s) => s.mentorshipId == bharatLivePairing);
      final at = next.scheduledAt.toLocal();
      final items = await repo.calendar(DateTime(at.year, at.month), DateTime(at.year, at.month + 1));
      final entry = items.firstWhere((i) => i.id == next.id);
      expect(entry.kind, CalendarKind.session);
      expect(entry.mentorshipId, bharatLivePairing);
      expect(entry.counterpartName, 'Anand Iyer');
      expect(entry.at.isAtSameMomentAs(next.scheduledAt), isTrue);
      expect(items.map((i) => i.at), orderedEquals([...items.map((i) => i.at)]..sort()));
    });

    liveTest('a request sent can be withdrawn from the Requests tab, and the list reads again', () async {
      final rohanApi = await liveClient(rohan);
      final id = await sendRequest(rohanApi, nehaProfile);
      try {
        final c = await loadedFor(rohan);
        final r = c.pendingSent.firstWhere((r) => r.id == id);
        expect(r.mentor.name, 'Neha Kapoor');
        expect(c.quota.data, isNotNull);
        expect(c.quota.data!.pending, greaterThanOrEqualTo(1));
        expect(await c.withdrawRequest(r), isNull);
        expect(c.pendingSent.where((x) => x.id == id), isEmpty);
        expect(c.sent.data!.firstWhere((x) => x.id == id).status, RequestStatus.withdrawn);
        expect(c.summary.data!.pendingOutgoing, 0);
        // The API's own refusal comes back as a sentence, not an exception.
        final again = await c.withdrawRequest(r);
        expect(again, isNotNull);
      } finally {
        await clearPhone(rohanApi);
      }
    });

    liveTest('saving a mentor puts them on the Saved tab, and Remove takes them off', () async {
      final c = await loadedFor(bharat);
      final repo = c.repository;
      await c.saved.load();
      expect(c.saved.data!.any((m) => m.mentorProfileId == nehaProfile), isFalse, reason: 'start clean');
      await repo.saveMentor(nehaProfile);
      try {
        await c.saved.load();
        final m = c.saved.data!.firstWhere((m) => m.mentorProfileId == nehaProfile);
        expect(m.person.name, 'Neha Kapoor');
        expect(m.rating, greaterThan(0));
        expect(m.headline, contains('Wipro'));
        expect(await c.unsave(m), isNull);
        expect(c.saved.data!.any((x) => x.mentorProfileId == nehaProfile), isFalse);
        await c.saved.load();
        expect(c.saved.data!.any((x) => x.mentorProfileId == nehaProfile), isFalse, reason: 'the API agrees');
      } finally {
        try {
          await repo.unsaveMentor(nehaProfile);
        } on Object {
          // already off
        }
      }
    });

    liveTest('what a mentee wants from mentoring is saved, read back and put back (Rohan)', () async {
      final c = await loadedFor(rohan);
      await c.intent.load();
      final before = c.intent.data!;
      try {
        final changed = MenteeIntent(
          careerStage: 'MID_CAREER',
          focusAreas: const ['Career transitions'],
          goalSummary: 'A live test wrote this line.',
          preferredModes: const ['PHONE'],
          cadence: 'MONTHLY',
          discoverable: false,
        );
        expect(await c.saveIntent(changed), isNull);
        final back = c.intent.data!;
        expect(back.careerStage, 'MID_CAREER');
        expect(back.goalSummary, 'A live test wrote this line.');
        expect(back.preferredModes, ['PHONE']);
        expect(back.cadence, 'MONTHLY');
        expect(back.discoverable, isFalse);
        // The API's own rule: a goal summary is at most 2,000 characters.
        final refusal = await c.saveIntent(MenteeIntent(careerStage: 'MID_CAREER', goalSummary: 'x' * 2001));
        expect(refusal, isNotNull);
      } finally {
        await c.saveIntent(before);
      }
      await c.intent.load();
      expect(c.intent.data!.careerStage, before.careerStage);
      expect(c.intent.data!.goalSummary, before.goalSummary);
      expect(c.intent.data!.discoverable, before.discoverable);
      expect(c.intent.data!.cadence, before.cadence);
    });

    liveTest('a mentor sees the requests asked of them and the mentees they have (Anand)', () async {
      final c = await loadedFor(anand);
      expect(c.summary.data!.isMentor, isTrue);
      expect(c.summary.data!.approvedMentor, isTrue);
      expect(c.actsAsMentor, isTrue);
      expect(c.pendingReceived, isNotEmpty);
      final r = c.pendingReceived.first;
      expect(r.mentee.name, isNotEmpty);
      expect(r.message, isNotEmpty);
      expect(r.expiresAt, isNotNull);
      final mine = c.livePairings.where((p) => p.viewerIsMentor);
      expect(mine, isNotEmpty);
      expect(mine.first.counterpart.name, isNot('An ICR member'));
    });

    liveTest('a mentor declines a fresh request with a note the mentee reads as written', () async {
      final rohanApi = await liveClient(rohan);
      final id = await sendRequest(
        rohanApi,
        anandProfile,
        message: 'I would value a call about moving from a site role to a portfolio role.',
      );
      try {
        final mentor = await loadedFor(anand);
        final r = mentor.pendingReceived.firstWhere((r) => r.id == id);
        expect(r.mentee.name, 'Rohan Das');
        expect(await mentor.respond(r, accept: false, note: 'Full until the new year, please ask again.'), isNull);
        expect(mentor.pendingReceived.where((x) => x.id == id), isEmpty);
        final mentee = await loadedFor(rohan);
        final seen = mentee.sent.data!.firstWhere((x) => x.id == id);
        expect(seen.status, RequestStatus.declined);
        expect(seen.responseNote, 'Full until the new year, please ask again.');
      } finally {
        await clearPhone(rohanApi);
      }
    });

    liveTest('a mentor accepts a fresh request, the pairing starts, and ending it early frees the place', () async {
      final rohanApi = await liveClient(rohan);
      final id = await sendRequest(
        rohanApi,
        nehaProfile,
        message: 'Could you guide me through campus workplace programme design?',
      );
      try {
        final mentor = await loadedFor(
          const LivePerson('mentoring.neha@design.icr.test', _password, 'Neha Kapoor (mentor)'),
        );
        final r = mentor.pendingReceived.firstWhere((r) => r.id == id);
        expect(
          await mentor.respond(r, accept: true, note: 'Welcome. Send me your site list.', cadence: 'WEEKLY'),
          isNull,
        );
        await mentor.pairings.load();
        final pairing = mentor.livePairings.firstWhere((p) => p.counterpart.name == 'Rohan Das');
        expect(pairing.viewerIsMentor, isTrue);
        expect(pairing.cadence, 'WEEKLY');
        final mentee = await loadedFor(rohan);
        expect(mentee.livePairings.any((p) => p.id == pairing.id && !p.viewerIsMentor), isTrue);
        expect(mentee.sent.data!.firstWhere((x) => x.id == id).status, RequestStatus.accepted);
        // The API has no way to delete a pairing: ending it early is the way back (the seed's --remove sweeps the row).
        await mentor.repository.updatePairing(
          pairing.id,
          PairingStatus.endedEarly,
          endedReason: 'A live test: ending the fixture pairing.',
        );
      } finally {
        await clearPhone(rohanApi);
      }
    });

    liveTest('a refusal reaches the person as the API words it', () async {
      final c = await loadedFor(bharat);
      final repo = c.repository;
      try {
        await repo.withdrawRequest('no-such-request');
        fail('should have been refused');
      } on Object catch (e) {
        expect(e.toString(), isNot(contains('DioException')));
      }
      final refusal = await c.withdrawRequest(
        MentoringRequest(
          id: 'dsgn-mentoring-pair-bharat-anand-req',
          status: RequestStatus.accepted,
          message: '',
          createdAt: DateTime.now(),
          mentor: const Person(id: 'x', firstName: 'A', lastName: 'B'),
          mentorProfileId: 'x',
          mentee: const Person(id: 'y', firstName: 'C', lastName: 'D'),
        ),
      );
      expect(refusal, isNotNull, reason: 'an accepted request cannot be withdrawn');
      expect(refusal, isNot(contains('Exception')));
    });
  });

  group('a pairing: the page behind "Open"', () {
    liveTest('the page reads what the API holds, as the mentee (Bharat) and as the mentor (Anand)', () async {
      final c = PairingController(await repoFor(bharat), bharatLivePairing);
      await c.load();
      expect(c.error, isNull, reason: '${c.error}');
      expect(c.pairing!.counterpart.name, 'Anand Iyer');
      expect(c.isMentor, isFalse);
      expect(c.active, isTrue);
      final byId = {for (final s in c.sessions) s.id: s};
      expect(byId.keys, containsAll(['$bharatLivePairing-s3', '$bharatLivePairing-s4', '$bharatLivePairing-s5']));
      expect(byId['$bharatLivePairing-s4']!.status, SessionStatus.requested);
      expect(byId['$bharatLivePairing-s4']!.createdById, isNotNull);
      expect(byId['$bharatLivePairing-s3']!.meetingLink, isNotNull);
      expect(byId['$bharatLivePairing-s5']!.status, SessionStatus.cancelled);
      expect(byId['$bharatLivePairing-s5']!.cancelReason, contains('site shutdown'));
      expect(c.goals, hasLength(3));
      expect(c.tasks.firstWhere((t) => t.id.endsWith('-t1')).overdue, isTrue);
      expect(c.tasks.firstWhere((t) => t.id.endsWith('-t3')).isMine, isTrue);
      expect(c.timeline.first.type, 'STARTED');
      expect(c.timeline.first.label, 'Mentorship started');
      expect(c.resources, isEmpty);
      expect(c.term, isNotNull, reason: 'the coaching plan behind this pairing');
      expect(c.term!.title, 'Monthly leadership coaching');
      expect(c.term!.sessionsAllowance, 2);
      expect(c.term!.sessionsUsed, 1);
      expect(c.termIsMine, isTrue);
      expect(c.featured()!.status, SessionStatus.requested, reason: 'an unanswered ask leads, before the next session');

      final m = PairingController(await repoFor(anand), bharatLivePairing);
      await m.load();
      expect(m.error, isNull, reason: '${m.error}');
      expect(m.isMentor, isTrue);
      expect(m.pairing!.counterpart.name, 'Bharat Buyer');
      expect(m.term, isNotNull, reason: 'the mentor sees the plan their mentee bought');
      expect(m.termIsMine, isFalse);
      expect(m.canComplete(m.sessions.firstWhere((s) => s.id.endsWith('-s3'))), isFalse, reason: 'it is still ahead');
    });

    liveTest('a pairing that is not theirs is refused with the API\'s sentence, not a crash', () async {
      final c = PairingController(await repoFor(rohan), bharatLivePairing);
      await c.load();
      expect(c.pairing, isNull);
      expect(c.error, isNotNull);
      expect(c.error, isNot(contains('Exception')));
    });

    liveTest(
      'sessions: asked, approved, moved, cancelled, booked by the mentor, held with its minutes, written up',
      () async {
        final p = await FreshPairing.start();
        try {
          final first = await p.slot();
          expect(
            await p.mentee.schedule(at: first, durationMin: 45, mode: 'VIDEO', agenda: 'Campus programme design'),
            isNull,
          );
          var s = p.mentee.sessions.single;
          expect(s.status, SessionStatus.requested);
          expect(s.agenda, 'Campus programme design');
          expect(s.scheduledAt.isAtSameMomentAs(first), isTrue);

          // A mentee cannot move an ask: their mentor answers it.
          expect(
            await p.mentee.reschedule(s, at: await p.slot(day: 1), durationMin: 45, mode: 'VIDEO'),
            contains('mentor answers this'),
          );

          await p.mentor.load();
          expect(await p.mentor.approve(p.mentor.sessions.single), isNull);
          await p.mentee.load();
          expect(p.mentee.sessions.single.status, SessionStatus.scheduled);

          // Either person moves a booked session.
          final second = await p.slot(day: 1);
          expect(
            await p.mentee.reschedule(p.mentee.sessions.single, at: second, durationMin: 45, mode: 'VIDEO'),
            isNull,
          );
          s = p.mentee.sessions.single;
          expect(s.scheduledAt.isAtSameMomentAs(second), isTrue);
          expect(s.status, SessionStatus.scheduled);

          // The API's rules, in its own words.
          final yesterday = DateTime.now().subtract(const Duration(days: 1));
          expect(await p.mentee.schedule(at: yesterday, durationMin: 45, mode: 'VIDEO'), 'Pick a time in the future.');
          expect(
            await p.mentee.schedule(at: await p.slot(day: 2), durationMin: 45, mode: 'IN_PERSON'),
            contains('is not how this mentor meets'),
          );
          expect(
            await p.mentor.schedule(at: second, durationMin: 45, mode: 'VIDEO'),
            contains('already has a session booked'),
          );
          expect(
            await p.mentee.schedule(at: await p.slot(day: 2), durationMin: 5, mode: 'VIDEO'),
            isNotNull,
            reason: 'a session runs 15 to 480 minutes',
          );
          expect(await p.mentee.cancel(s, 'x'), isNotNull, reason: 'a reason is 3 to 500 characters');

          expect(await p.mentee.cancel(s, 'Something came up at work'), isNull);
          expect(p.mentee.sessions.single.status, SessionStatus.cancelled);
          expect(p.mentee.sessions.single.cancelReason, 'Something came up at work');
          expect(
            await p.mentee.cancel(p.mentee.sessions.single, 'Again'),
            contains('Only a scheduled or requested session'),
          );

          // The mentor books straight in, sets the link, closes the session with the minutes it ran.
          final third = await p.slot(day: 2);
          expect(
            await p.mentor.schedule(at: third, durationMin: 45, mode: 'VIDEO', agenda: 'Programme outline'),
            isNull,
          );
          await p.mentor.load();
          var booked = p.mentor.sessions.firstWhere((x) => x.status == SessionStatus.scheduled);
          expect(booked.agenda, 'Programme outline');
          expect(
            await p.mentee.setMeetingLink(booked, 'https://meet.google.com/abc-defg-hij'),
            isNotNull,
            reason: 'only the mentor sets it',
          );
          expect(await p.mentor.setMeetingLink(booked, 'https://meet.google.com/abc-defg-hij'), isNull);
          booked = p.mentor.sessions.firstWhere((x) => x.id == booked.id);
          expect(booked.meetingLink, 'https://meet.google.com/abc-defg-hij');
          expect(await p.mentor.setMeetingLink(booked, 'not a link'), isNotNull);

          await p.mentee.load();
          expect(
            await p.mentee.complete(p.mentee.sessions.firstWhere((x) => x.id == booked.id), durationMin: 45),
            isNotNull,
            reason: 'only the mentor confirms',
          );
          expect(await p.mentor.complete(booked, durationMin: 50, note: 'Covered the outline'), isNull);
          expect(p.mentor.pairing!.sessionsCount, 1);
          expect(p.mentor.pairing!.totalMinutes, 50);
          expect(p.mentor.sessions.firstWhere((x) => x.id == booked.id).status, SessionStatus.completed);
          expect(await p.mentor.complete(booked, durationMin: 50), contains('already marked complete'));

          // Either person writes the session up; a summary needs enough notes, and is asked for only on request.
          await p.mentee.load();
          final held = p.mentee.sessions.firstWhere((x) => x.id == booked.id);
          expect(
            await p.mentee.saveRecord(held, notes: 'Too short', recordingUrl: 'https://example.com/recording'),
            isNull,
          );
          final saved = p.mentee.sessions.firstWhere((x) => x.id == booked.id);
          expect(saved.notes, 'Too short');
          expect(saved.recordingUrl, 'https://example.com/recording');
          await expectLater(
            p.mentee.summarise(saved),
            throwsA(predicate((e) => e.toString().contains('not enough written down'))),
          );
          expect(
            await p.mentee.saveRecord(
              saved,
              notes: 'We covered the programme outline and the first three sessions. ' * 5,
            ),
            isNull,
          );
          final record = await p.mentee.summarise(p.mentee.sessions.firstWhere((x) => x.id == booked.id));
          expect(
            record.summary != null || record.unavailable,
            isTrue,
            reason: 'a summary, or the site says it has no model',
          );
          // Editing the notes clears a summary.
          expect(await p.mentee.saveRecord(saved, notes: 'Rewritten'), isNull);
          expect(p.mentee.sessions.firstWhere((x) => x.id == booked.id).summary, isNull);
        } finally {
          await p.end();
        }
      },
    );

    liveTest('goals and tasks: added by either, updated by either, removed by their author', () async {
      final p = await FreshPairing.start();
      try {
        expect(await p.mentee.addGoal(title: 'ab'), isNotNull, reason: 'a goal is 3 characters at least');
        expect(
          await p.mentee.addGoal(
            title: 'Run a vendor review',
            detail: 'Quarterly',
            targetDate: DateTime.now().add(const Duration(days: 60)),
          ),
          isNull,
        );
        var g = p.mentee.goals.single;
        expect(g.status, GoalStatus.open);
        expect(g.progress, 0);
        expect(g.targetDate, isNotNull);
        expect(await p.mentee.setGoalProgress(g, 60), isNull);
        expect(p.mentee.goals.single.progress, 60);
        await p.mentor.load();
        expect(p.mentor.goals.single.title, 'Run a vendor review', reason: 'the mentor sees it');
        expect(await p.mentor.setGoalStatus(p.mentor.goals.single, GoalStatus.achieved), isNull);
        expect(p.mentor.goals.single.status, GoalStatus.achieved);
        expect(p.mentor.goals.single.progress, 100);
        expect(await p.mentor.setGoalStatus(p.mentor.goals.single, GoalStatus.open), isNull);
        expect(await p.mentor.setGoalStatus(p.mentor.goals.single, GoalStatus.dropped), isNull);
        expect(p.mentor.goals.single.status, GoalStatus.dropped);
        g = p.mentee.goals.single;
        expect(await p.mentee.removeGoal(g), isNull);
        expect(p.mentee.goals, isEmpty);

        expect(await p.mentor.addTask(title: 'x'), isNotNull, reason: 'a task is 2 characters at least');
        expect(
          await p.mentor.addTask(title: 'Send the site list', dueAt: DateTime.now().add(const Duration(days: 5))),
          isNull,
        );
        expect(p.mentor.tasks.single.isMine, isTrue);
        await p.mentee.load();
        final t = p.mentee.tasks.single;
        expect(t.isMine, isFalse);
        expect(t.dueAt, isNotNull);
        expect(await p.mentee.toggleTask(t), isNull);
        expect(p.mentee.tasks.single.status, TaskStatus.done);
        expect(await p.mentee.toggleTask(p.mentee.tasks.single), isNull);
        expect(p.mentee.tasks.single.status, TaskStatus.open);
        expect(await p.mentee.deleteTask(p.mentee.tasks.single), isNotNull, reason: 'only its author deletes it');
        expect(await p.mentor.deleteTask(p.mentor.tasks.single), isNull);
        expect(p.mentor.tasks, isEmpty);
      } finally {
        await p.end();
      }
    });

    liveTest(
      'notes and shared links: a private note stays with its author, a link is removed by whoever shared it',
      () async {
        final p = await FreshPairing.start();
        try {
          expect(await p.mentee.addNote('   '), isNotNull);
          expect(await p.mentee.addNote('A note only I can read', privateToMe: true), isNull);
          expect(await p.mentee.addNote('A note for both of us'), isNull);
          expect(
            p.mentee.timeline.where((e) => e.type == 'NOTE_ADDED').map((e) => e.note),
            containsAll(['A note only I can read', 'A note for both of us']),
          );
          expect(p.mentee.timeline.firstWhere((e) => e.note == 'A note only I can read').shared, isFalse);
          await p.mentor.load();
          final seen = p.mentor.timeline.where((e) => e.type == 'NOTE_ADDED').map((e) => e.note).toList();
          expect(seen, contains('A note for both of us'));
          expect(seen, isNot(contains('A note only I can read')));

          expect(
            await p.mentee.addResourceLink(title: 'x', url: 'https://example.com/a'),
            isNotNull,
            reason: 'a title is 2 characters at least',
          );
          expect(await p.mentee.addResourceLink(title: 'Handover checklist', url: 'not a url'), isNotNull);
          expect(
            await p.mentee.addResourceLink(
              title: 'Handover checklist',
              url: 'https://example.com/checklist',
              kind: 'TEMPLATE',
              note: 'Start with section 3',
            ),
            isNull,
          );
          final r = p.mentee.resources.single;
          expect(r.kind, 'TEMPLATE');
          expect(r.kindLabel, 'Template');
          expect(r.note, 'Start with section 3');
          expect(r.canRemove, isTrue);
          expect(r.isUpload, isFalse);
          await p.mentor.load();
          expect(p.mentor.resources.single.title, 'Handover checklist');
          expect(
            p.mentor.resources.single.canRemove,
            isTrue,
            reason: 'the mentor owns the pairing, so may clear anything',
          );
          // The mentor shares one too: the mentee reads it, and cannot remove it.
          expect(await p.mentor.addResourceLink(title: 'Site visit guide', url: 'https://example.com/guide'), isNull);
          await p.mentee.load();
          final theirs = p.mentee.resources.firstWhere((x) => x.title == 'Site visit guide');
          expect(theirs.canRemove, isFalse);
          expect(await p.mentee.removeResource(theirs), isNotNull);
          expect(
            await p.mentee.removeResource(p.mentee.resources.firstWhere((x) => x.title == 'Handover checklist')),
            isNull,
          );
          expect(
            await p.mentor.removeResource(p.mentor.resources.firstWhere((x) => x.title == 'Site visit guide')),
            isNull,
          );
          await p.mentee.load();
          expect(p.mentee.resources, isEmpty);
        } finally {
          await p.end();
        }
      },
    );

    liveTest('pause stops booking, resume allows it, the rhythm changes, and completing opens the review', () async {
      final p = await FreshPairing.start();
      try {
        expect(await p.mentee.setStatus(PairingStatus.paused), isNull);
        expect(p.mentee.pairing!.status, PairingStatus.paused);
        expect(p.mentee.active, isFalse);
        expect(await p.mentee.schedule(at: await p.slot(), durationMin: 45, mode: 'VIDEO'), contains('not active'));
        expect(await p.mentee.setStatus(PairingStatus.active), isNull);
        expect(p.mentee.active, isTrue);
        expect(await p.mentee.setCadence('WEEKLY'), isNull);
        expect(p.mentee.pairing!.cadence, 'WEEKLY');

        await p.mentor.load();
        expect(await p.mentor.setStatus(PairingStatus.completed), isNull);
        expect(p.mentor.pairing!.status, PairingStatus.completed);
        await p.mentee.load();
        expect(p.mentee.pairing!.status, PairingStatus.completed);
        expect(p.mentee.feedback, isNull);
        expect(await p.mentee.sendFeedback(rating: 9), isNotNull, reason: 'a rating is one to five');
        expect(await p.mentee.sendFeedback(rating: 5, comment: 'Clear and practical', wouldRecommend: true), isNull);
        expect(p.mentee.feedback!.rating, 5);
        expect(p.mentee.feedback!.comment, 'Clear and practical');
        expect(p.mentee.feedback!.wouldRecommend, isTrue);
        expect(await p.mentee.sendFeedback(rating: 4), isNotNull, reason: 'a review is left once');
        expect(await p.mentee.setStatus(PairingStatus.active), contains('already ended'));
        // The certificate, when the API issues one for a pairing this short, is the member's and carries this pairing's id.
        final certs = await p.mentee.repository.certificates();
        for (final c in certs.where((c) => c.mentorshipId == p.id)) {
          expect(c.certificateId, startsWith('ICR-'));
        }
      } finally {
        await p.end();
      }
    });

    liveTest(
      'ending early needs a reason both read, and a concern and a support request are checked by the API',
      () async {
        final p = await FreshPairing.start();
        try {
          expect(
            await p.mentee.raiseConcern(category: ConcernCategory.other, detail: 'short'),
            isNotNull,
            reason: 'a concern is 10 characters at least',
          );
          expect(
            await p.mentee.askSupport(subject: 'Hi', body: 'x'),
            isNotNull,
            reason: 'a subject is 5 characters at least',
          );
          expect(
            await p.mentee.raiseConcern(
              category: ConcernCategory.unresponsive,
              detail: 'A live test concern about the fixture pairing.',
            ),
            isNull,
          );
          final mine = await (await repoFor(rohan)).concerns();
          final c = mine.firstWhere((x) => x.mentorshipId == p.id);
          expect(c.category, ConcernCategory.unresponsive);
          expect(c.status, 'OPEN');
          expect(c.statusLabel, 'Received');
          expect(c.urgent, isFalse);
          expect(await p.mentor.setStatus(PairingStatus.endedEarly, reason: 'Our schedules no longer line up'), isNull);
          await p.mentee.load();
          expect(p.mentee.pairing!.status, PairingStatus.endedEarly);
          expect(p.mentee.pairing!.endedReason, 'Our schedules no longer line up');
          expect(p.mentee.live, isFalse);
          expect(await p.mentee.schedule(at: await p.slot(), durationMin: 45, mode: 'VIDEO'), contains('not active'));
        } finally {
          await p.end();
        }
      },
    );

    liveTest('Message opens (or reuses) the pairing\'s thread through the record', () async {
      final c = PairingController(await repoFor(bharat), bharatLivePairing);
      await c.load();
      final id = await c.conversation();
      expect(id, isNotNull);
      expect(await c.conversation(), id, reason: 'the same thread again');
    });
  });

  group('purchases, group sessions and programmes', () {
    liveTest('the Purchases tab reads what the API holds, and sorts it (Bharat)', () async {
      final c = await loadedFor(bharat);
      await c.ensureTab(MyTab.purchases);
      final book = c.book;
      for (final l in [book.purchases, book.terms, book.seats, book.enrolments]) {
        expect(l.error, isNull, reason: '${l.error}');
      }
      final byId = {for (final p in book.purchases.data!) p.id: p};
      final requested = byId['dsgn-mentoring-buy-bharat-requested']!;
      expect(requested.status, PurchaseStatus.requested);
      expect(requested.request!.topic, contains('facilities head interview'));
      expect(requested.request!.listPricePaisa, 149900);
      expect(requested.type, ServiceType.oneOnOne);
      expect(requested.mentor!.name, 'Anand Iyer');
      expect(requested.mentorProfileId, anandProfile);
      final accepted = byId['dsgn-mentoring-buy-bharat-accepted']!;
      expect(accepted.status, PurchaseStatus.accepted);
      expect(accepted.request!.scheduledAt, isNotNull);
      expect(accepted.request!.payBy, isNotNull);
      expect(accepted.duePaisa, 79900);
      final booked = byId['dsgn-mentoring-buy-bharat-booked']!;
      expect(booked.status, PurchaseStatus.paid);
      expect(booked.booking!.scheduled, isTrue);
      expect(booked.booking!.meetingLink, isNotNull);
      expect(booked.booking!.durationMin, 30);
      final kit = byId['dsgn-mentoring-buy-bharat-kit']!;
      expect(kit.status, PurchaseStatus.fulfilled);
      expect(kit.type, ServiceType.resource);
      expect(kit.downloadUrl, startsWith('/uploads/'));
      expect(kit.fileName, 'interview-question-bank');
      expect(byId['dsgn-mentoring-buy-bharat-declined']!.request!.declineReason, contains('travelling'));
      expect(bucketOf(accepted), PurchaseBucket.needs);
      expect(bucketOf(requested), PurchaseBucket.active);
      expect(bucketOf(booked), PurchaseBucket.active);
      expect(bucketOf(kit), PurchaseBucket.past);

      final terms = {for (final t in book.terms.data!) t.id: t};
      final programme = terms['dsgn-mentoring-term-bharat-programme']!;
      expect(programme.status, 'PENDING_MENTOR');
      expect(programme.programme, isTrue);
      expect(programme.steps, hasLength(3));
      expect(programme.steps.first.id, isNotEmpty);
      expect(programme.steps.first.isNext, isTrue);
      expect(programme.totalPaisa, 599900);
      expect(programme.pricePaisa, 599900);
      expect(termBucket(programme), PurchaseBucket.active);
      final coaching = terms['dsgn-mentoring-term-bharat-coaching']!;
      expect(coaching.status, 'ACTIVE');
      expect(coaching.programme, isFalse);
      expect(coaching.sessionsLeft, 1);
      expect(coaching.mentorshipId, bharatLivePairing);

      expect(book.seats.data!.any((s) => s.id == clinicGroup && s.myStatus == 'REGISTERED'), isTrue);
      final place = book.enrolments.data!.firstWhere((e) => e.programId.endsWith('programme-circle'));
      expect(place.status, 'ACCEPTED');
      expect(place.role, ProgrammeRole.mentee);
      expect(place.programme!.slug, circleSlug);

      final d = await book.quoteInputs();
      expect(d, isNotNull);
      expect(d!.credits, isNotNull, reason: 'Bharat holds a session credit through his plan');
      expect(d.credits!.remaining, greaterThanOrEqualTo(0));
      expect(d.credits!.capPaisa, greaterThan(0));
      final q = PriceQuote.session(79900, d);
      expect(q.chargedPaisa, d.credits!.remaining > 0 ? 0 : 79900);
    });

    liveTest('a bought guide downloads as the real file, read with the session\'s token', () async {
      final c = await loadedFor(bharat);
      await c.ensureTab(MyTab.purchases);
      final kit = c.book.purchases.data!.firstWhere((p) => p.id == 'dsgn-mentoring-buy-bharat-kit');
      final bytes = await c.book.download(kit);
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
      // Without the token the API refuses: the app never links a browser to a private file.
      final anon = liveAnonymous();
      await expectLater(
        MentoringRepository(api: anon).downloadBytes(kit.downloadUrl!),
        throwsA(predicate((e) => e.toString().contains('Sign in'))),
      );
    });

    liveTest('a free 1:1 session: asked, a time set, accepted, moved by request, withdrawn, cancelled', () async {
      final id = await askAnand(discoveryService);
      final rohanC = await loadedFor(rohan);
      await rohanC.ensureTab(MyTab.purchases);
      try {
        var p = await purchaseOf(rohanC, id);
        expect(p.status, PurchaseStatus.requested);
        expect(p.request!.topic, contains('portfolio role'));
        expect(p.duePaisa, 0);

        final first = await anandSlot(skipDays: 1);
        await anandAccepts(id, first);
        // Free: the mentor setting the time books it, so there is nothing left to accept or pay.
        p = await purchaseOf(rohanC, id);
        expect(p.status, PurchaseStatus.paid);
        expect(p.booking!.scheduled, isTrue);
        expect(p.booking!.scheduledAt.isAtSameMomentAs(first), isTrue);
        expect(bucketOf(p), PurchaseBucket.active);

        // Ask to move; the mentor keeps the booked time; ask again and withdraw it.
        final second = await anandSlot(skipDays: 2);
        expect(await rohanC.book.proposeMove(p, second, 'That day clashes with a site audit'), isNull);
        p = await purchaseOf(rohanC, id);
        expect(movePendingOnThem(p), isTrue);
        expect(p.booking!.proposedNote, 'That day clashes with a site audit');
        expect(p.booking!.proposedAt, isNotNull);
        final anandApi = await liveClient(anand);
        await anandApi.dio.post<dynamic>(
          '/mentor-services/purchases/$id/reschedule/decline',
          data: {'reason': 'That week is full'},
        );
        p = await purchaseOf(rohanC, id);
        expect(movePendingOnThem(p), isFalse);
        expect(await rohanC.book.proposeMove(p, second, ''), isNull);
        p = await purchaseOf(rohanC, id);
        expect(await rohanC.book.answerMove(p, accept: false), isNull);
        p = await purchaseOf(rohanC, id);
        expect(p.booking!.proposedAt, isNull);

        expect(await rohanC.book.cancel(p, 'No'), isNotNull, reason: 'a reason is 5 to 500 characters');
        expect(await rohanC.book.cancel(p, 'Something came up at work'), isNull);
        p = await purchaseOf(rohanC, id);
        expect(p.status, PurchaseStatus.cancelled);
        expect(bucketOf(p), PurchaseBucket.past);
        expect(await rohanC.book.cancel(p, 'Cancelling twice'), isNotNull);
      } finally {
        await cleanUpPurchase(id);
      }
    });

    liveTest('a time that does not suit is sent back, then the ask is withdrawn', () async {
      final id = await askAnand(strategyService, topic: 'A second ask, to learn how the other time works for me.');
      final rohanC = await loadedFor(rohan);
      await rohanC.ensureTab(MyTab.purchases);
      try {
        await anandAccepts(id, await anandSlot(minutes: 45, skipDays: 1));
        var p = await purchaseOf(rohanC, id);
        expect(p.status, PurchaseStatus.accepted);
        expect(await rohanC.book.declineTime(p, 'No'), isNotNull, reason: 'the note is 5 to 500 characters');
        expect(await rohanC.book.declineTime(p, 'Weekday evenings after 7 pm'), isNull);
        p = await purchaseOf(rohanC, id);
        expect(p.status, PurchaseStatus.requested);
        expect(p.request!.timeDeclineNote, 'Weekday evenings after 7 pm');
        expect(p.request!.timeDeclineCount, 1);
        expect(p.request!.scheduledAt, isNull, reason: 'the mentor sets another');
        expect(await rohanC.book.withdrawRequest(p), isNull);
        expect(rohanC.book.purchases.data!.where((x) => x.id == id && x.status.open), isEmpty);
      } finally {
        await cleanUpPurchase(id);
      }
    });

    liveTest(
      'a paid 1:1 session: the quote, the time accepted, payment owed, the website for the money, cancelled',
      () async {
        final id = await askAnand(strategyService, topic: 'Preparing for a facilities head interview next month.');
        final rohanC = await loadedFor(rohan);
        await rohanC.ensureTab(MyTab.purchases);
        try {
          var p = await purchaseOf(rohanC, id);
          expect(p.duePaisa, 149900);
          await anandAccepts(id, await anandSlot(minutes: 45, skipDays: 1));
          p = await purchaseOf(rohanC, id);
          expect(p.status, PurchaseStatus.accepted);
          expect(p.request!.payBy, isNotNull);
          final d = await rohanC.book.quoteInputs();
          expect(d, isNotNull);
          final quote = PriceQuote.session(p.duePaisa, d, useCredit: false);
          expect(quote.chargedPaisa, lessThanOrEqualTo(149900));
          expect(quote.free, isFalse);

          expect(await rohanC.book.acceptTime(p), isNull);
          p = await purchaseOf(rohanC, id);
          expect(p.status, PurchaseStatus.confirmed, reason: 'booked, payment due');
          expect(p.booking, isNotNull);
          expect(bucketOf(p), PurchaseBucket.needs);

          final live = await rohanC.repository.paymentsLive();
          if (live) {
            final outcome = await rohanC.book.payPurchase(p, quote);
            expect(outcome.completed, isFalse, reason: 'real payments continue on the website');
            expect(outcome.sitePath, '/mentorship/my?tab=purchases&purchase=$id');
            p = await purchaseOf(rohanC, id);
            expect(p.status, PurchaseStatus.confirmed, reason: 'nothing was charged');
          }
          expect(await rohanC.book.cancel(p, 'The date no longer works for me'), isNull);
          p = await purchaseOf(rohanC, id);
          expect(p.status, PurchaseStatus.cancelled);
        } finally {
          await (await repoFor(rohan)).withdrawPurchaseRequest(id).then((_) {}, onError: (_) {});
        }
      },
    );

    liveTest('a free guide: bought, downloaded, reviewed once, and a problem reported then taken back', () async {
      final api = await liveClient(rohan);
      final res = await api.dio.post<Map<String, dynamic>>(
        '/mentor-services/$workbookService/checkout',
        data: <String, dynamic>{},
      );
      final id = res.data!['purchaseId'] as String;
      final c = await loadedFor(rohan);
      await c.ensureTab(MyTab.purchases);
      var p = await purchaseOf(c, id);
      expect(p.status, PurchaseStatus.fulfilled);
      expect(p.type, ServiceType.resource);
      expect(p.pricePaisa, 0);
      final bytes = await c.book.download(p);
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');

      expect(
        await c.book.review(p, rating: 5, comment: 'short'),
        isNotNull,
        reason: 'a comment is 10 characters at least',
      );
      expect(await c.book.review(p, rating: 9), isNotNull, reason: 'a rating is one to five');
      if (!p.hasReview) {
        expect(await c.book.review(p, rating: 5, comment: 'Practical and printable'), isNull);
        p = await purchaseOf(c, id);
        expect(p.hasReview, isTrue);
      }
      expect(
        await c.book.review(p, rating: 4, comment: 'A second review, refused'),
        isNotNull,
        reason: 'a purchase is reviewed once',
      );

      expect(await c.book.reportIssue(p, 'short'), isNotNull, reason: 'a report is 10 characters at least');
      expect(await c.book.reportIssue(p, 'The file opened blank on my phone once'), isNull);
      expect(await c.book.withdrawIssue(p), isNull);
    });

    liveTest('a programme asked for shows its quote and syllabus, and is withdrawn while it waits', () async {
      final api = await liveClient(rohan);
      final res = await api.dio.post<Map<String, dynamic>>(
        '/mentor-plans/$programmePlan/request',
        data: {'phone': aPhone},
      );
      await clearPhone(api);
      final id = res.data!['subscriptionId'] as String;
      final c = await loadedFor(rohan);
      await c.ensureTab(MyTab.purchases);
      final t = c.book.terms.data!.firstWhere((x) => x.id == id);
      expect(t.status, 'PENDING_MENTOR');
      expect(t.programme, isTrue);
      expect(t.steps.map((s) => s.title), [
        'Where you are, where you want to be',
        'Vendor and SLA governance',
        'The portfolio business case',
      ]);
      expect(t.totalPaisa, greaterThanOrEqualTo(t.pricePaisa - t.discountPaisa));
      expect(t.counterpart!.name, 'Anand Iyer');
      expect(termBucket(t), PurchaseBucket.active);
      expect(await c.book.cancelTerm(t), isNull);
      final after = c.book.terms.data!.where((x) => x.id == id);
      expect(after.isEmpty || !after.first.open, isTrue);
    });

    liveTest(
      'group sessions: browse and filter, take a seat with a question, the call and the room, give it up',
      () async {
        final repo = await repoFor(rohan);
        final all = await repo.groupSessions();
        expect(all.items.map((s) => s.id), containsAll([clinicGroup, paidGroup]));
        final clinic = all.items.firstWhere((s) => s.id == clinicGroup);
        expect(clinic.host.name, 'Anand Iyer');
        expect(clinic.capacity, 25);
        expect(clinic.seatsLeft, isNotNull);
        expect(clinic.paid, isFalse);
        expect(clinic.occurrences, hasLength(1));
        final paid = all.items.firstWhere((s) => s.id == paidGroup);
        expect(paid.paid, isTrue);
        expect(paid.pricePaisa, 29900);

        expect((await repo.groupSessions(search: 'panel')).items.map((s) => s.id), contains(paidGroup));
        expect((await repo.groupSessions(search: 'panel')).items.map((s) => s.id), isNot(contains(clinicGroup)));
        expect((await repo.groupSessions(mode: 'IN_PERSON')).items.where((s) => s.mode != 'IN_PERSON'), isEmpty);
        expect((await repo.groupSessions(availableOnly: true)).items.where((s) => s.full), isEmpty);
        final first = await repo.groupSessions(limit: 1);
        expect(first.items, hasLength(1));
        expect(first.hasNext, isTrue);
        expect((await repo.groupSessions(limit: 1, page: 2)).items.single.id, isNot(first.items.single.id));
        final mineBharat = await (await repoFor(bharat)).groupSessions(registered: true);
        expect(mineBharat.items.map((s) => s.id), containsAll([clinicGroup, pastGroup]));

        var d = await repo.groupSession(clinicGroup);
        expect(d.holdsSeat, isFalse);
        expect(d.canRegister, isTrue);
        expect(d.meetingLink, isNull, reason: 'the call is for people with a seat');
        expect(d.agendaHtml == null || d.agendaHtml!.isNotEmpty, isTrue);
        try {
          await repo.registerGroup(clinicGroup, question: 'How do I present a case to finance?');
          d = await repo.groupSession(clinicGroup);
          expect(d.myStatus, 'REGISTERED');
          expect(d.meetingLink, isNotNull);
          expect(d.holdsSeat, isTrue);
          expect(d.attendees.any((a) => a.person.firstName == 'Rohan') || d.rosterScope != null, isTrue);
          expect((await repo.groupSeats()).any((s) => s.id == clinicGroup), isTrue);
          final room = await repo.groupConversation(clinicGroup);
          expect(room, isNotNull);
          await expectLater(repo.registerGroup(clinicGroup), throwsA(isNotNull), reason: 'a seat is taken once');
        } finally {
          await repo.leaveGroup(clinicGroup).then((_) {}, onError: (_) {});
        }
        d = await repo.groupSession(clinicGroup);
        expect(d.myStatus, anyOf(isNull, 'CANCELLED'));
      },
    );

    liveTest('a paid seat shows its quote and, with real payments on, sends the money to the website', () async {
      final repo = await repoFor(rohan);
      final d = await repo.groupSession(paidGroup);
      expect(d.seatForSale, isTrue);
      expect(d.paid, isTrue);
      final discounts = await repo.memberDiscounts();
      final quote = PriceQuote.service(d.pricePaisa!, discounts);
      expect(quote.listPaisa, 29900);
      expect(quote.chargedPaisa, lessThanOrEqualTo(29900));
      if (await repo.paymentsLive() && quote.chargedPaisa > 0) {
        final outcome = await repo.buyGroupSeat(d, quote: quote);
        expect(outcome.completed, isFalse);
        expect(outcome.sitePath, '/mentorship/groups/$paidGroup');
        expect((await repo.groupSession(paidGroup)).myStatus, isNull, reason: 'nothing was bought');
      }
    });

    liveTest('a held session is rated once (Meera), and the API checks the rating and a concern', () async {
      final repo = await repoFor(meera);
      final d = await repo.groupSession(pastGroup);
      expect(d.status, 'COMPLETED');
      expect(d.myStatus, 'ATTENDED');
      final before = await repo.myGroupFeedback(pastGroup);
      await expectLater(
        repo.rateGroupSession(pastGroup, rating: 9),
        throwsA(isNotNull),
        reason: 'a rating is one to five',
      );
      await expectLater(
        repo.rateGroupSession(pastGroup, rating: 4, comment: 'short'),
        throwsA(isNotNull),
        reason: 'a comment is 10 characters at least',
      );
      if (before == null) {
        await repo.rateGroupSession(pastGroup, rating: 5, comment: 'Short, practical and well paced', anonymous: true);
        final mine = await repo.myGroupFeedback(pastGroup);
        expect(mine!.rating, 5);
        expect(mine.comment, 'Short, practical and well paced');
        expect(mine.anonymous, isTrue);
      }
      await expectLater(
        repo.rateGroupSession(pastGroup, rating: 4),
        throwsA(isNotNull),
        reason: 'a session is rated once',
      );
      await expectLater(
        repo.raiseGroupConcern(pastGroup, category: ConcernCategory.other, detail: 'short'),
        throwsA(isNotNull),
        reason: 'a concern is 10 characters at least',
      );
    });

    liveTest(
      'programmes: browse, the detail, applying on a side, and the API\'s eligibility refusals by code',
      () async {
        final repo = await repoFor(rohan);
        final open = await repo.programmes(status: 'OPEN');
        expect(open.map((p) => p.slug), contains(circleSlug));
        expect(open.every((p) => p.status == 'OPEN'), isTrue);
        final p = await repo.programme(circleSlug);
        expect(p.name, 'Early-career mentoring circle');
        expect(p.organiser.name, 'Anand Iyer');
        expect(p.menteeCapacity, 12);
        expect(p.mentorCapacity, 4);
        expect(p.menteesTaken, isNotNull);
        expect(p.open, isTrue);
        expect(plainText(p.detailHtml), contains('A small cohort'));
        expect(p.enrolmentAs(ProgrammeRole.mentee), isNull, reason: 'a withdrawn place is not a live one');
        final inside = await repo.groupSessions(programId: p.id);
        expect(inside.items.every((s) => s.id.isNotEmpty), isTrue);

        final bharatView = await (await repoFor(bharat)).programme(circleSlug);
        expect(bharatView.enrolmentAs(ProgrammeRole.mentee)!.status, 'ACCEPTED');

        // Rohan has no mentor profile; Kiran has said nothing about what he wants from mentoring.
        await expectLater(
          repo.enrol(circleSlug, ProgrammeRole.mentor),
          throwsA(predicate((e) => e is ApiError && e.code == 'PROGRAMME_NEEDS_MENTOR_PROFILE')),
        );
        await expectLater(
          (await repoFor(kiran)).enrol(circleSlug, ProgrammeRole.mentee),
          throwsA(
            predicate(
              (e) =>
                  e is ApiError &&
                  e.code == 'PROGRAMME_NEEDS_MENTEE_PROFILE' &&
                  e.message.contains('what you want from mentoring'),
            ),
          ),
        );

        await repo.enrol(circleSlug, ProgrammeRole.mentee, motivation: 'A live test applying to the cohort.');
        try {
          final mine = await repo.myProgrammes();
          final e = mine.firstWhere((x) => x.programId == p.id && x.live);
          expect(e.status, 'APPLIED');
          expect(e.role, ProgrammeRole.mentee);
          expect(e.programme!.slug, circleSlug);
          expect((await repo.programme(circleSlug)).enrolmentAs(ProgrammeRole.mentee)!.id, e.id);
          await expectLater(
            repo.enrol(circleSlug, ProgrammeRole.mentee),
            throwsA(isNotNull),
            reason: 'one application per side',
          );
        } finally {
          final mine = await repo.myProgrammes();
          for (final e in mine.where((x) => x.programId == p.id && x.live)) {
            await repo.withdrawEnrolment(e.id);
          }
        }
        final after = (await repo.myProgrammes()).where((x) => x.programId == p.id && x.live);
        expect(after, isEmpty);
      },
    );
  });

  group('files shared inside a pairing', () {
    liveTest(
      'a PDF is uploaded and shared, read by the other person with their token, and removed by its author',
      () async {
        final p = await FreshPairing.start();
        try {
          final pdf = Uint8List.fromList(
            '%PDF-1.4\n1 0 obj<</Type/Catalog>>endobj\ntrailer<</Root 1 0 R>>\n%%EOF\n'.codeUnits,
          );
          await expectLater(
            p.mentee.repository.addResourceFile(
              p.id,
              bytes: Uint8List.fromList([1, 2, 3]),
              name: 'macros.exe',
              mimeType: 'application/x-msdownload',
              title: 'Not allowed',
            ),
            throwsA(predicate((e) => e.toString().contains('not an accepted file type'))),
          );
          expect(
            await p.mentee.addResourceFile(
              file: PickedShare(bytes: pdf, name: 'handover.pdf', mimeType: 'application/pdf'),
              title: 'Handover checklist',
              kind: 'TEMPLATE',
              note: 'Start with page one',
            ),
            isNull,
          );
          final r = p.mentee.resources.single;
          expect(r.isUpload, isTrue);
          expect(r.fileName, 'handover.pdf');
          expect(r.fileSize, pdf.length);
          expect(r.kind, 'TEMPLATE');
          expect(r.url, startsWith('/uploads/'));
          expect(r.canRemove, isTrue);

          await p.mentor.load();
          final theirs = p.mentor.resources.single;
          final bytes = await p.mentor.download(theirs);
          expect(String.fromCharCodes(bytes.take(4)), '%PDF');
          // Only the two of them may read it.
          await expectLater(
            MentoringRepository(api: liveAnonymous()).downloadBytes(theirs.url!),
            throwsA(predicate((e) => e.toString().contains('Sign in'))),
          );
          expect(await p.mentee.removeResource(r), isNull);
          expect(p.mentee.resources, isEmpty);
        } finally {
          await p.end();
        }
      },
    );
  });
}
