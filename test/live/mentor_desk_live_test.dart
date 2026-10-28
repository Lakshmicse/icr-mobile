/// The mentor's desk against the LOCAL API, as Anand Iyer (the seeded mentor with a live storefront; run
/// `tool/seed/mentoring.ts` first). Each control that reads or writes through the API is exercised through the
/// desk's own repository and controller and proved by reading the effect back. What a test changes about Anand
/// it puts back (hours, settings, visibility); what needs a second person (a request, a purchase) is made fresh
/// by Rohan Das, who has no other part in the fixtures, and ended in a state the seed's `--remove` sweeps:
/// cancelled, declined or withdrawn.
///
///     flutter test --timeout=60s test/live/mentor_desk_live_test.dart --concurrency=1
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/features/mentor_desk/mentor_desk_controller.dart';
import 'package:icr_mobile/features/mentor_desk/mentor_desk_models.dart';
import 'package:icr_mobile/features/mentor_desk/mentor_desk_repository.dart';
import 'package:icr_mobile/features/mentorship_my/mentoring_models.dart';
import 'package:icr_mobile/features/mentorship_my/mentoring_repository.dart';

import 'live.dart';

const _password = 'Password123!';
const anand = LivePerson('mentoring.anand@design.icr.test', _password, 'Anand Iyer (mentor desk)');
const rohan = LivePerson('mentoring.rohan@design.icr.test', _password, 'Rohan Das (buyer)');
const bharat = LivePerson('buyer@icr.dev', 'Buyer@123', 'Bharat Buyer (a mentee only)');
const kiran = LivePerson('mentoring.kiran@design.icr.test', _password, 'Kiran Shah (has not applied)');

const anandProfile = 'dsgn-mentoring-mp-anand';

/// A number the API takes as a mobile; the person who sends a request with it gets it saved, so a test clears it.
const aPhone = '9876501234';

Future<MentorDeskRepository> deskFor(LivePerson who) async => MentorDeskRepository(api: await liveClient(who));

Future<MentorDeskController> loadedDesk() async {
  final c = MentorDeskController(await deskFor(anand));
  await c.start();
  return c;
}

Future<void> clearPhone(ApiClient api) async {
  await api.dio.patch<dynamic>('/users/me', data: {'phone': ''});
}

/// Rohan asks for a session; returns the purchase id.
Future<String> requestSession(String serviceId, {String topic = 'Mapping my next two years in facilities'}) async {
  final api = await liveClient(rohan);
  try {
    final res = await api.dio.post<Map<String, dynamic>>(
      '/mentor-services/$serviceId/request',
      data: {'topic': topic, 'mode': 'VIDEO', 'phone': aPhone},
    );
    return res.data!['id'] as String;
  } finally {
    await clearPhone(api);
  }
}

SoldRow rowOf(MentorDeskController c, String id) => c.sold.data!.firstWhere((r) => r.id == id);

Future<ServicePurchase> buyerView(String id) async => MentoringRepository(api: await liveClient(rohan)).purchase(id);

void main() {
  group('the desk is for an approved mentor', () {
    liveTest(
      'the dashboard reads for a listed mentor, and says there is no profile for a member who has not applied',
      () async {
        final d = await (await deskFor(anand)).dashboard();
        expect(d.hasProfile, isTrue);
        expect(d.usable, isTrue);
        expect(d.profile!.status, DeskStatus.approved);
        expect(d.profile!.id, anandProfile);
        expect(d.profile!.headline, contains('Prestige'));
        expect(d.profile!.discoverable, isTrue);
        expect(d.profile!.rating, greaterThan(0));
        expect(d.profile!.ratingCount, greaterThan(0));
        expect(d.capacityTotal, 6);
        expect(d.capacityActive + d.capacityOpen, d.capacityTotal);
        expect(d.requestsPending, greaterThanOrEqualTo(4));
        expect(d.menteesActive, greaterThanOrEqualTo(2));
        expect(d.completenessScore, inInclusiveRange(1, 100));
        expect(d.recentActivity, isNotEmpty);
        expect(d.recentActivity.first.label, isNotEmpty);
        expect(d.isListed, isTrue);

        // A member with no mentor profile at all (Bharat is a mentee only).
        final none = await (await deskFor(bharat)).dashboard();
        expect(none.hasProfile, isFalse);
        expect(none.profile, isNull);
        expect(none.usable, isFalse);
        final c = MentorDeskController(await deskFor(bharat));
        await c.dashboard.load();
        expect(c.gate, DeskGate.noProfile);
        c.dispose();
        // An applicant whose profile ICR has not approved (Kiran's may be a draft or in review) has no desk yet.
        final applicant = await (await deskFor(kiran)).dashboard();
        expect(applicant.usable, isFalse);
      },
    );

    liveTest('every tab reads the API\'s real answers (requests, mentees, paid work, earnings, reviews)', () async {
      final c = await loadedDesk();
      expect(c.gate, DeskGate.ready);
      for (final tab in DeskTab.values) {
        await c.ensureTab(tab);
      }
      for (final l in [c.sold, c.terms, c.roster, c.settings, c.earnings, c.feedback, c.serviceReviews]) {
        expect(l.error, isNull, reason: '${l.error}');
      }
      expect(c.mentoring.received.error, isNull);
      expect(c.mentoring.pairings.error, isNull);

      // Requests: free ones, sessions asked for, programmes asked for.
      expect(c.freeRequests, isNotEmpty);
      expect(c.freeRequests.first.mentee.name, isNot('An ICR member'));
      expect(c.freeRequests.first.expiresAt, isNotNull);
      final asked = c.sessionRequests.firstWhere((r) => r.id == 'dsgn-mentoring-buy-isha-requested');
      expect(asked.purchase.buyer!.name, 'Isha Verma');
      expect(asked.purchase.request!.topic, contains('regional role'));
      expect(asked.purchase.duePaisa, 149900);
      expect(asked.purchase.request!.durationMin, 45);
      expect(c.heldTimes.map((r) => r.id), contains('dsgn-mentoring-buy-sana-accepted'));
      expect(
        c.heldTimes.firstWhere((r) => r.id == 'dsgn-mentoring-buy-sana-accepted').purchase.request!.payBy,
        isNotNull,
      );
      expect(c.programmeRequests.map((t) => t.id), contains('dsgn-mentoring-term-vikram-programme'));
      final prog = c.programmeRequests.firstWhere((t) => t.id == 'dsgn-mentoring-term-vikram-programme');
      expect(prog.programme, isTrue);
      expect(prog.counterpart!.name, 'Vikram Singh');
      expect(prog.totalPaisa, 599900);
      expect(c.activeTerms.map((t) => t.id), contains('dsgn-mentoring-term-tanvi-coaching'));
      expect(c.requestCount, greaterThanOrEqualTo(8));

      // Mentees.
      expect(c.roster.data!.every((p) => p.viewerIsMentor), isTrue);
      expect(c.roster.data!.map((p) => p.counterpart.name), containsAll(['Bharat Buyer', 'Meera Nair']));
      expect(c.roster.data!.first.conversationId == null || c.roster.data!.first.conversationId!.isNotEmpty, isTrue);
      expect(
        c.mentoring.pairings.data!.where((p) => p.viewerIsMentor && !p.status.live),
        isNotEmpty,
        reason: 'finished mentees',
      );

      // Paid work: a booked call, with its link, and the net the mentor earns.
      final booked = c.sold.data!.firstWhere((r) => r.id == 'dsgn-mentoring-buy-rahul-paid');
      expect(booked.bookedCall, isTrue);
      expect(booked.purchase.booking!.durationMin, 45);
      expect(booked.purchase.booking!.meetingLink, isNotNull);
      expect(booked.purchase.netPaisa, 119920);
      expect(booked.openIssue, isFalse);

      // Settings and hours.
      final s = c.settings.data!;
      expect(s.status, DeskStatus.approved);
      expect(s.capacity, 6);
      expect(s.preferredModes, containsAll(['VIDEO', 'PHONE']));
      expect(s.timezone, 'Asia/Kolkata');
      expect(s.meetingLink, startsWith('https://'));
      expect(s.blocks, isNotEmpty);
      expect(s.blocks.every((b) => b.endMin > b.startMin && b.weekday >= 0 && b.weekday <= 6), isTrue);
      expect(s.bioHtml, contains('<p>'));

      // Earnings.
      final e = c.earnings.data!;
      expect(e.unsettledPaisa, greaterThan(0));
      expect(e.settledPaisa, greaterThan(0));
      expect(e.entries, isNotEmpty);
      final settled = e.entries.firstWhere((x) => x.settled);
      expect(settled.settlementRef, 'NEFT-DEMO-0042');
      expect(settled.amountPaisa, greaterThan(0));
      expect(e.entries.where((x) => !x.settled), isNotEmpty);
      expect(e.entries.firstWhere((x) => x.subscriptionId != null).amountPaisa, 239920);

      // Reviews.
      expect(c.feedback.data!.map((f) => f.rating), containsAll([4, 5]));
      expect(c.feedback.data!.any((f) => (f.comment ?? '').contains('portfolio case')), isTrue);
      final reviews = c.serviceReviews.data!;
      expect(reviews.map((r) => r.comment), contains('Worth every rupee: a concrete 90-day plan.'));
      expect(reviews.firstWhere((r) => r.rating == 5).authorName, isNotNull);
      expect(reviews.every((r) => r.serviceTitle.isNotEmpty), isTrue);
      c.dispose();
    });

    liveTest('the calendar reads across mentees, paid calls and hosted clinics', () async {
      final c = await loadedDesk();
      await c.ensureTab(DeskTab.calendar);
      expect(c.mentoring.calendar.error, isNull);
      final kinds = {for (final i in c.mentoring.calendar.data!) i.kind};
      // The seed dates are relative to when it ran, so a month may hold none of a kind: what is read must parse.
      expect(c.mentoring.calendar.data!.every((i) => i.title.isNotEmpty && i.durationMin > 0), isTrue);
      expect(kinds.difference({CalendarKind.session, CalendarKind.booking, CalendarKind.group}), isEmpty);
      await c.mentoring.nextMonth();
      expect(c.mentoring.calendar.error, isNull);
      c.dispose();
    });
  });

  group('hours, settings and visibility', () {
    liveTest('weekly hours: read, changed, read back and put back; the API\'s own refusals', () async {
      final c = await loadedDesk();
      final repo = c.repository;
      await c.settings.load();
      final original = [...c.settings.data!.blocks];
      try {
        final extra = [...original, const WeeklyBlock(weekday: 1, startMin: 540, endMin: 600)];
        expect(await c.saveHours(extra), isNull);
        expect(c.settings.data!.blocks, hasLength(original.length + 1));
        expect(c.settings.data!.blocks.contains(const WeeklyBlock(weekday: 1, startMin: 540, endMin: 600)), isTrue);
        expect((await repo.settings()).blocks, hasLength(original.length + 1), reason: 'the API agrees');

        // The API's rules, in its own words (the form checks the same before it asks).
        expect(
          await c.saveHours([
            const WeeklyBlock(weekday: 1, startMin: 540, endMin: 600),
            const WeeklyBlock(weekday: 1, startMin: 580, endMin: 640),
          ]),
          'Windows on the same day must not overlap.',
        );
        expect(
          await c.saveHours([const WeeklyBlock(weekday: 1, startMin: 600, endMin: 600)]),
          'Each window must end after it starts.',
        );
        expect(
          await c.saveHours([const WeeklyBlock(weekday: 1, startMin: 700, endMin: 600)]),
          'Each window must end after it starts.',
        );
        expect(await c.saveHours(_tooMany()), isNotNull);
        expect(
          (await repo.settings()).blocks,
          hasLength(original.length + 1),
          reason: 'a refused save changes nothing',
        );
      } finally {
        await c.saveHours(original);
      }
      await c.settings.load();
      expect(c.settings.data!.blocks, unorderedEquals(original));
      c.dispose();
    });

    liveTest('settings: only what changed is sent, read back and put back; a bad link is refused', () async {
      final c = await loadedDesk();
      await c.settings.load();
      final before = c.settings.data!;
      try {
        expect(
          await c.saveSettings({'capacity': before.capacity + 1, 'availabilityNote': 'A live test wrote this note.'}),
          isNull,
        );
        final after = c.settings.data!;
        expect(after.capacity, before.capacity + 1);
        expect(after.availabilityNote, 'A live test wrote this note.');
        expect(after.timezone, before.timezone, reason: 'what was not sent is left alone');
        expect(after.preferredModes, before.preferredModes);
        expect(after.meetingLink, before.meetingLink);
        expect(after.bioHtml, before.bioHtml, reason: 'an untouched bio keeps its formatting');
        expect((await c.dashboard.load().then((_) => c.dashboard.data!)).capacityTotal, before.capacity + 1);

        expect(await c.saveSettings({'meetingLink': 'not a link'}), isNotNull);
        expect(await c.saveSettings({'capacity': 0}), isNotNull, reason: 'a mentor takes at least one mentee');
        expect(await c.saveSettings({'capacity': 11}), isNotNull, reason: 'and at most ten');
        expect(
          await c.saveSettings({
            'preferredModes': ['TELEPATHY'],
          }),
          isNotNull,
        );
        expect(c.settings.data!.capacity, before.capacity + 1);
      } finally {
        await c.saveSettings({'capacity': before.capacity, 'availabilityNote': before.availabilityNote});
      }
      await c.settings.load();
      expect(c.settings.data!.capacity, before.capacity);
      expect(c.settings.data!.availabilityNote, before.availabilityNote);
      c.dispose();
    });

    liveTest('the directory switch hides the profile and lists it again', () async {
      final c = await loadedDesk();
      try {
        expect(c.dashboard.data!.isListed, isTrue);
        expect(await c.setVisibility(false), isNull);
        expect(c.dashboard.data!.profile!.discoverable, isFalse);
        expect(c.dashboard.data!.isListed, isFalse);
        expect((await c.repository.settings()).discoverable, isFalse);
      } finally {
        await c.setVisibility(true);
      }
      expect(c.dashboard.data!.profile!.discoverable, isTrue);
      expect(c.dashboard.data!.isListed, isTrue);
      c.dispose();
    });
  });

  group('requests and paid work, on fresh rows', () {
    liveTest(
      'a free session request is accepted with a suggested time, then the link, a move offered and accepted, a call that has not started, and cancelled',
      () async {
        final id = await requestSession('dsgn-mentoring-svc-discovery');
        final c = await loadedDesk();
        try {
          var row = rowOf(c, id);
          expect(row.sessionRequest, isTrue);
          expect(row.purchase.buyer!.name, 'Rohan Das');
          expect(row.purchase.duePaisa, 0);
          expect(c.sessionRequests.map((r) => r.id), contains(id));

          // Suggested times: free on the calendar, in the mentor's hours.
          final s = await c.repository.suggestedTimes(id);
          expect(s.hasWeeklyHours, isTrue);
          expect(s.timezone, 'Asia/Kolkata');
          expect(s.suggestions, isNotEmpty);
          expect(s.suggestions.every((x) => x.at.isAfter(DateTime.now())), isTrue);
          final slots = await c.repository.slots(anandProfile, durationMin: 30);
          expect(slots, isNotEmpty);

          // Accepting a free session books it at once.
          final first = s.suggestions.first.at;
          expect(
            await c.acceptSession(row, DateTime.now().subtract(const Duration(days: 1))),
            isNotNull,
            reason: 'a time in the past is refused',
          );
          expect(await c.acceptSession(row, first), isNull);
          row = rowOf(c, id);
          expect(row.sessionRequest, isFalse);
          expect(row.bookedCall, isTrue);
          expect(row.purchase.status, PurchaseStatus.paid);
          expect(row.purchase.booking!.scheduledAt.isAtSameMomentAs(first), isTrue);
          expect(c.upcomingCalls.map((r) => r.id), contains(id));
          expect(await c.acceptSession(row, first), isNotNull, reason: 'it is answered once');

          // The meeting link.
          expect(await c.setCallLink(row, 'not a link'), isNotNull);
          expect(await c.setCallLink(row, 'https://meet.google.com/zzz-live-test'), isNull);
          expect(rowOf(c, id).purchase.booking!.meetingLink, 'https://meet.google.com/zzz-live-test');

          // A move the mentor offers waits on the mentee, who accepts it.
          final other = s.suggestions
              .firstWhere(
                (x) => !x.at.isAtSameMomentAs(first) && x.at.difference(first).abs() > const Duration(hours: 2),
              )
              .at;
          expect(await c.proposeMove(rowOf(c, id), other, note: 'Thursday suits me better'), isNull);
          row = rowOf(c, id);
          expect(row.moveAskedByMentor, isTrue);
          expect(row.purchase.booking!.proposedBy, 'MENTOR');
          expect(row.purchase.booking!.proposedAt!.isAtSameMomentAs(other), isTrue);
          expect(row.purchase.booking!.proposedNote, 'Thursday suits me better');
          expect(c.waiting.map((r) => r.id), contains(id));
          expect(c.upcomingCalls.map((r) => r.id), isNot(contains(id)));
          final seen = await buyerView(id);
          expect(seen.booking!.proposedBy, 'MENTOR');
          // The mentor takes the offer back, offers it again, and the buyer accepts.
          expect(await c.answerMove(row, accept: false), isNull);
          expect(rowOf(c, id).moveAskedByMentor, isFalse);
          expect(await c.proposeMove(rowOf(c, id), other), isNull);
          await MentoringRepository(api: await liveClient(rohan)).answerReschedule(id, accept: true);
          await c.sold.load();
          row = rowOf(c, id);
          expect(row.moveAskedByMentor, isFalse);
          expect(row.purchase.booking!.scheduledAt.isAtSameMomentAs(other), isTrue);
          expect(row.purchase.booking!.rescheduleCount, greaterThan(0));

          // A call that has not started cannot be closed.
          expect(await c.completeCall(row), 'This call has not started yet.');
          // Cancelling needs a reason of five characters.
          expect(await c.cancelCall(row, 'Sick'), isNotNull);
          expect(await c.cancelCall(row, 'A live test cancels this call'), isNull);
          expect(c.sold.data!.where((r) => r.id == id && r.bookedCall), isEmpty);
          final after = await buyerView(id);
          expect(after.status, PurchaseStatus.cancelled);
          expect(after.cancelReason, 'A live test cancels this call');
        } finally {
          // Already cancelled on the happy path; on a failure the buyer withdraws what is still open.
          try {
            await MentoringRepository(api: await liveClient(rohan)).cancelBooking(id, 'A live test cleans up');
          } on Object {
            // already closed
          }
          c.dispose();
        }
      },
    );

    liveTest(
      'a paid session request: accepting holds the time, the mentor can withdraw it, and declining carries a reason',
      () async {
        final id = await requestSession('dsgn-mentoring-svc-review', topic: 'Review my portfolio before the panel');
        final c = await loadedDesk();
        try {
          var row = rowOf(c, id);
          expect(row.sessionRequest, isTrue);
          expect(row.purchase.duePaisa, 79900);
          expect(row.purchase.request!.durationMin, 60);
          final at = (await c.repository.suggestedTimes(id)).suggestions.first.at;

          // A paid session is held until the mentee accepts the time and pays.
          expect(await c.acceptSession(row, at), isNull);
          row = rowOf(c, id);
          expect(row.timeHeld, isTrue);
          expect(row.purchase.status, PurchaseStatus.accepted);
          expect(row.purchase.request!.scheduledAt!.isAtSameMomentAs(at), isTrue);
          expect(row.purchase.request!.payBy, isNotNull);
          expect(c.heldTimes.map((r) => r.id), contains(id));
          expect(c.sessionRequests.map((r) => r.id), isNot(contains(id)));
          expect((await buyerView(id)).status, PurchaseStatus.accepted);

          // The mentor takes the time back: that cancels the request (the API says who withdrew it).
          expect(await c.withdrawHeld(row), isNull);
          expect(c.sold.data!.where((r) => r.id == id), isEmpty, reason: 'a cancelled request is no longer open work');
          final seen = await buyerView(id);
          expect(seen.status, PurchaseStatus.cancelled);
          expect(seen.cancelReason, 'Withdrawn by the mentor before payment.');
          expect(await c.withdrawHeld(row), isNotNull, reason: 'it was withdrawn once');

          // Declining (on a second request) needs a reason the buyer reads as written.
          final second = await requestSession('dsgn-mentoring-svc-review', topic: 'Review my CV before the panel');
          await c.sold.load();
          row = rowOf(c, second);
          expect(await c.declineSession(row, 'No'), isNotNull, reason: 'a reason is five characters at least');
          expect(await c.declineSession(row, 'I am not taking new sessions this month'), isNull);
          expect(c.sessionRequests.map((r) => r.id), isNot(contains(second)));
          final declined = await buyerView(second);
          expect(declined.status, PurchaseStatus.declined);
          expect(declined.request!.declineReason, 'I am not taking new sessions this month');
          expect(await c.declineSession(row, 'Declining again'), isNotNull, reason: 'it is answered once');
        } finally {
          c.dispose();
        }
      },
    );

    liveTest(
      'a problem a buyer reports on a resource reaches the desk, is answered, and the buyer closes it',
      () async {
        final buyerApi = await liveClient(rohan);
        final res = await buyerApi.dio.post<Map<String, dynamic>>(
          '/mentor-services/dsgn-mentoring-svc-workbook/checkout',
          data: {},
        );
        final id = res.data!['purchaseId'] as String;
        final c = await loadedDesk();
        try {
          expect(c.issues.map((r) => r.id), isNot(contains(id)));
          await buyerApi.dio.post<dynamic>(
            '/mentor-services/purchases/$id/report-issue',
            data: {'note': 'The workbook will not open on my phone.'},
          );
          await c.sold.load();
          var row = rowOf(c, id);
          expect(row.openIssue, isTrue);
          expect(row.issueNote, 'The workbook will not open on my phone.');
          expect(row.issueReportedAt, isNotNull);
          expect(row.issueRespondedAt, isNull);
          expect(c.issues.map((r) => r.id), contains(id));
          expect(c.workCount, greaterThanOrEqualTo(1));

          expect(await c.respondIssue(row, 'Sorry'), isNotNull, reason: 'a reply is ten characters at least');
          expect(await c.respondIssue(row, 'Sorry, I have re-sent the file as a PDF.'), isNull);
          row = rowOf(c, id);
          expect(row.issueResponseNote, 'Sorry, I have re-sent the file as a PDF.');
          expect(row.issueRespondedAt, isNotNull);
          expect(row.openIssue, isTrue, reason: 'it is closed when the buyer or ICR resolves it');

          await buyerApi.dio.post<dynamic>('/mentor-services/purchases/$id/withdraw-issue');
          await c.sold.load();
          expect(c.issues.map((r) => r.id), isNot(contains(id)));
        } finally {
          try {
            await buyerApi.dio.post<dynamic>('/mentor-services/purchases/$id/withdraw-issue');
          } on Object {
            // not open
          }
          c.dispose();
        }
      },
    );

    liveTest(
      'a programme request: a decline needs a reason, an accept waits on payment, the buyer withdraws',
      () async {
        final buyerApi = await liveClient(rohan);
        Future<String> ask() async {
          try {
            final res = await buyerApi.dio.post<Map<String, dynamic>>(
              '/mentor-plans/dsgn-mentoring-plan-programme/request',
              data: {'phone': aPhone},
            );
            return res.data!['subscriptionId'] as String;
          } finally {
            await clearPhone(buyerApi);
          }
        }

        final first = await ask();
        final c = await loadedDesk();
        try {
          var t = c.programmeRequests.firstWhere((x) => x.id == first);
          expect(t.counterpart!.name, 'Rohan Das');
          expect(t.programme, isTrue);
          expect(t.sessionsAllowance, 3);
          expect(t.status, 'PENDING_MENTOR');

          expect(await c.decideTerm(t, accept: false), contains('Tell them why'), reason: 'the API\'s own sentence');
          expect(await c.decideTerm(t, accept: true), isNull);
          expect(c.programmeRequests.map((x) => x.id), isNot(contains(first)));
          t = c.unpaidTerms.firstWhere((x) => x.id == first);
          expect(t.status, 'PENDING_PAYMENT');
          expect(await c.decideTerm(t, accept: true), contains('already been answered'));
          // The buyer pays on the website; this one withdraws.
          await buyerApi.dio.post<dynamic>(
            '/mentor-plans/subscriptions/$first/cancel',
            data: {'reason': 'A live test withdraws it'},
          );
          await c.terms.load();
          expect(c.unpaidTerms.map((x) => x.id), isNot(contains(first)));

          // The other way: a decline with a reason the buyer reads.
          final second = await ask();
          await c.terms.load();
          final t2 = c.programmeRequests.firstWhere((x) => x.id == second);
          expect(await c.decideTerm(t2, accept: false, reason: 'No'), isNotNull, reason: 'five characters at least');
          expect(await c.decideTerm(t2, accept: false, reason: 'My programme places are full'), isNull);
          final mine = await MentoringRepository(api: buyerApi).planTerms();
          final seen = mine.firstWhere((x) => x.id == second);
          expect(seen.status, 'DECLINED');
          expect(seen.declineReason, 'My programme places are full');
        } finally {
          c.dispose();
        }
      },
    );

    liveTest('a free mentoring request is declined from the desk with a note the mentee reads', () async {
      final buyerApi = await liveClient(rohan);
      final res = await buyerApi.dio.post<Map<String, dynamic>>(
        '/mentorship/requests',
        data: {
          'mentorProfileId': anandProfile,
          'message': 'I would value a call about moving from a site role to a portfolio role.',
          'phone': aPhone,
        },
      );
      await clearPhone(buyerApi);
      final id = res.data!['id'] as String;
      final c = await loadedDesk();
      try {
        final r = c.freeRequests.firstWhere((x) => x.id == id);
        expect(r.mentee.name, 'Rohan Das');
        expect(await c.mentoring.respond(r, accept: false, note: 'Full until the new year, please ask again.'), isNull);
        expect(c.freeRequests.map((x) => x.id), isNot(contains(id)));
        final mine = await MentoringRepository(api: buyerApi).requestsSent();
        final seen = mine.firstWhere((x) => x.id == id);
        expect(seen.status, RequestStatus.declined);
        expect(seen.responseNote, 'Full until the new year, please ask again.');
      } finally {
        c.dispose();
      }
    });
  });
}

List<WeeklyBlock> _tooMany() => [
  for (var i = 0; i < 22; i++) WeeklyBlock(weekday: i % 7, startMin: (i ~/ 7) * 180, endMin: (i ~/ 7) * 180 + 30),
];
