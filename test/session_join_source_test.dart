/// The messaging Join sheet's reader (`readSessionJoin`): the thread's booked session from its own record, with the
/// call's link and its windows, by the rule its own page's Join follows (owner, 14 Nov 2026: the old "Meet" landed on
/// a page with no Join).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/util/join_window.dart';
import 'package:icr_mobile/features/mentorship_my/session_join_source.dart';
import 'package:icr_mobile/features/messaging/messaging_models.dart';

import 'mentoring_fakes.dart';
import 'mentoring_purchases_world.dart';

void main() {
  final now = DateTime(2026, 10, 26, 10);
  DateTime clock() => now;

  ConversationContext pairing({DateTime? next}) => ConversationContext(
    kind: ConversationKind.mentorship,
    mentorship: ContextMentorship(
      id: 'pair-anand',
      mentee: true,
      mentorProfileId: 'p1',
      sessionsCount: 1,
      nextSessionAt: next,
    ),
  );

  ConversationContext consultation() => ConversationContext(
    kind: ConversationKind.consultation,
    consultation: ContextConsultation(
      id: 'k1',
      title: 'Strategy session',
      buyer: true,
      oneOnOne: true,
      scheduledAt: now.add(const Duration(hours: 2)),
    ),
  );

  group("a pairing's next session", () {
    test('the one the thread names as next, with its own link and length', () async {
      final api = FakeApi({
        'GET /mentorship/pair-anand/sessions': (_) => [
          sessionJson('s-old', at: now.subtract(const Duration(days: 3)), status: 'COMPLETED'),
          sessionJson('s-next', at: now.add(const Duration(minutes: 10)), link: 'https://meet.google.com/next'),
          sessionJson('s-later', at: now.add(const Duration(days: 7)), link: 'https://meet.google.com/later'),
        ],
      });
      final join = await readSessionJoin(
        repoOf(api),
        pairing(next: now.add(const Duration(minutes: 10))),
        clock: clock,
      );
      expect(join!.link, Uri.parse('https://meet.google.com/next'));
      expect(join.windows.single.stateAt(now), JoinState.open, reason: 'ten minutes before a 45-minute session');
      expect(join.windows.single.closesAt.isAtSameMomentAs(now.add(const Duration(minutes: 10 + 45 + 30))), isTrue);
      expect(join.end!.difference(join.start!), const Duration(minutes: 45), reason: "the record's length, not 20");
    });

    test('no session to come: no windows, and why', () async {
      final api = FakeApi({
        'GET /mentorship/pair-anand/sessions': (_) => [
          sessionJson('s-old', at: now.subtract(const Duration(days: 3)), status: 'COMPLETED'),
        ],
      });
      final join = await readSessionJoin(repoOf(api), pairing(), clock: clock);
      expect(join!.windows, isEmpty);
      expect(join.link, isNull);
      expect(join.note, 'No session is booked yet.');
    });
  });

  group('a booked 1:1', () {
    test('paid and scheduled: its call', () async {
      final api = FakeApi({
        'GET /mentor-services/purchases/k1': (_) => purchaseJson(
          'k1',
          status: 'PAID',
          booking: bookingBlock(at: now.add(const Duration(hours: 2)), link: 'https://meet.google.com/k1'),
        ),
      });
      final join = await readSessionJoin(repoOf(api), consultation(), clock: clock);
      expect(join!.link, Uri.parse('https://meet.google.com/k1'));
      expect(join.windows.single.stateAt(now), JoinState.early);
    });

    test('not paid yet: no call, and the reason', () async {
      final api = FakeApi({
        'GET /mentor-services/purchases/k1': (_) => purchaseJson(
          'k1',
          status: 'PENDING_PAYMENT',
          booking: bookingBlock(at: now.add(const Duration(hours: 2))),
        ),
      });
      final join = await readSessionJoin(repoOf(api), consultation(), clock: clock);
      expect(join!.link, isNull);
      expect(join.windows, hasLength(1));
      expect(join.note, 'Pay for the booking to confirm it. The call opens once it is paid.');
    });
  });

  test("a group session: its link for someone with a seat, and every day it runs", () async {
    final api = FakeApi({
      'GET /mentorship/group-sessions/g1': (_) => groupJson(
        'g1',
        detail: true,
        myStatus: 'REGISTERED',
        meetingLink: 'https://meet.google.com/g1',
        at: now.add(const Duration(days: 1)),
      ),
    });
    final join = await readSessionJoin(
      repoOf(api),
      ConversationContext(
        kind: ConversationKind.groupSession,
        groupSession: ContextGroupSession(id: 'g1', title: 'Clinic', nextAt: now.add(const Duration(days: 1))),
      ),
      clock: clock,
    );
    expect(join!.link, Uri.parse('https://meet.google.com/g1'));
    expect(join.windows, hasLength(1));
    expect(join.note, isNull);
  });

  test('a thread with no session record reads nothing', () async {
    final api = FakeApi({});
    expect(await readSessionJoin(repoOf(api), const ConversationContext(kind: ConversationKind.direct)), isNull);
    expect(api.calls, isEmpty);
  });
}
