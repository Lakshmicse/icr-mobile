@Tags(['live'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/features/membership/api_membership_repository.dart';
import 'package:icr_mobile/features/membership/membership_models.dart';

import 'live.dart';

/// The plans screen's reads against the local API: every audience's catalogue
/// parses, each plan is priced and carries benefits (the card is built from
/// them), and the signed-in person's own plan and history read.
///
/// Reads only: no checkout runs here (a simulated one would buy the person a
/// plan). Run: `flutter test test/live/membership_live_test.dart --concurrency=1`
void main() {
  liveTest('the catalogue: every audience reads, with priced plans and benefits', () async {
    final repo = ApiMembershipRepository(api: await liveClient());
    var seen = 0;
    for (final audience in MembershipAudience.values) {
      final plans = await repo.plans(audience);
      for (final p in plans) {
        seen++;
        expect(p.id, isNotEmpty);
        expect(p.name, isNotEmpty);
        expect(p.audience, audience, reason: '${p.name} is listed under ${audience.name}');
        if (!p.contactSales && p.tier != 'FREE') {
          expect(p.prices, isNotEmpty, reason: '${p.name} (${audience.name}) is sold, so it has a price');
        }
      }
    }
    expect(seen, greaterThan(0), reason: 'the seed (prisma/seed-membership.ts) gives every audience a ladder');
  });

  liveTest('the Professional ladder carries benefit lines a card can draw', () async {
    final repo = ApiMembershipRepository(api: await liveClient());
    final plans = await repo.plans(MembershipAudience.seeker);
    expect(plans, isNotEmpty);
    expect(plans.any((p) => p.benefits.isNotEmpty), isTrue, reason: 'cards are built from the plan\'s benefits');
    for (final b in plans.expand((p) => p.benefits)) {
      expect(b.text, isNotEmpty);
    }
  });

  liveTest('my plan and my history read for every audience', () async {
    final repo = ApiMembershipRepository(api: await liveClient());
    for (final audience in MembershipAudience.values) {
      final mine = await repo.mine(audience);
      expect(mine, isNotNull);
      final history = await repo.history(audience);
      expect(history, isNotNull);
    }
  });
}
