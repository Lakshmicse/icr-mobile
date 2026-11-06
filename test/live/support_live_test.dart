@Tags(['live'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/features/support/api_support_repository.dart';
import 'package:icr_mobile/features/support/support_words.dart';

import 'live.dart';

/// The support desk against the local API, READ-ONLY: a ticket cannot be deleted, so nothing is raised, replied to,
/// reopened or rated here. The reads are the screens' own: the member's requests under each tab, one request with
/// its thread and history, the common questions, and the account manager (nobody, for the e2e personas).
///
/// Signed in as Pooja Professional, the e2e persona who has requests in several states.
///
/// Run: `flutter test test/live/support_live_test.dart`
void main() {
  liveTest('the member\'s requests read under every tab, a page at a time', () async {
    final repo = ApiSupportRepository(api: await liveClient(pooja));
    final all = await repo.tickets(status: 'ALL', limit: 50);
    expect(all.items, isNotEmpty, reason: 'the e2e seed gives Pooja requests');
    for (final t in all.items) {
      expect(t.id, isNotEmpty);
      expect(t.reference, greaterThan(0));
      expect(t.subject, isNotEmpty);
      expect(SupportWords.statusLabels.keys, contains(t.status));
      expect(SupportWords.categories.map((c) => c.$1), contains(t.category));
      expect(t.messages, isNull, reason: 'a list row carries no thread');
    }

    final open = await repo.tickets();
    expect(open.items.map((t) => t.status), everyElement(isIn(['NEW', 'OPEN', 'AWAITING_USER'])));
    final resolved = await repo.tickets(status: 'RESOLVED');
    expect(resolved.items.map((t) => t.status), everyElement('RESOLVED'));

    if (all.total > 1) {
      final first = await repo.tickets(status: 'ALL', limit: 1);
      expect(first.items, hasLength(1));
      expect(first.hasNext, isTrue);
      final second = await repo.tickets(status: 'ALL', limit: 1, page: 2);
      expect(second.items.single.id, isNot(first.items.single.id));
    }

    final hit = await repo.tickets(status: 'ALL', search: all.items.first.subject.split(' ').first);
    expect(hit.items.map((t) => t.id), contains(all.items.first.id));
  });

  liveTest('one request: its thread, in order, with the history the member may see', () async {
    final repo = ApiSupportRepository(api: await liveClient(pooja));
    final all = await repo.tickets(status: 'ALL', limit: 50);
    final closed = all.items.firstWhere((t) => t.closed, orElse: () => all.items.first);
    final ticket = await repo.ticket(closed.id);
    expect(ticket.reference, closed.reference);
    expect(ticket.messages, isNotNull);
    expect(ticket.messages, isNotEmpty);
    expect(ticket.messages!.first.body, isNotEmpty);
    expect(ticket.messages!.first.author?.fullName, isNotEmpty);
    final times = [for (final m in ticket.messages!) m.createdAt!];
    expect([...times]..sort(), times, reason: 'oldest first');
    expect(ticket.events, isNotNull);
    expect(ticket.events!.map((e) => e.type), contains('RAISED'));
    // The staff-only kinds never reach the requester.
    expect(ticket.events!.map((e) => e.type), isNot(anyOf(contains('ASSIGNED'), contains('PRIORITY_CHANGED'))));
    for (final e in ticket.events!) {
      expect(SupportWords.eventLabels.keys, contains(e.type));
    }
  });

  liveTest('the common questions read without signing in; the account manager is nobody for this persona', () async {
    final anonymous = ApiSupportRepository(api: liveAnonymous());
    final faqs = await anonymous.faqs(limit: 4);
    expect(faqs, isNotEmpty);
    expect(faqs.first.question, isNotEmpty);
    expect(faqs.first.answer, isNotEmpty);

    final repo = ApiSupportRepository(api: await liveClient(pooja));
    expect(await repo.accountManager(), isNull);
  });

  liveTest('a request that is not the person\'s is refused with a sentence', () async {
    final repo = ApiSupportRepository(api: await liveClient(pooja));
    await expectLater(repo.ticket('not-a-real-request'), throwsA(anything));
  });
}
