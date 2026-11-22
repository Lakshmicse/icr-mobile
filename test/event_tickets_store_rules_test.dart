// What the App Store build sells of events (lib/core/store_rules.dart): a ticket to an event attended in person
// or hybrid, never one to an online-only event. Run under both rule sets:
//
//   flutter test test/event_tickets_store_rules_test.dart --dart-define=STORE_RULES=ios
//   flutter test test/event_tickets_store_rules_test.dart --dart-define=STORE_RULES=none
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/store_rules.dart';
import 'package:icr_mobile/features/events/demo_events_repository.dart';
import 'package:icr_mobile/features/events/event_models.dart';
import 'package:icr_mobile/features/events/event_tickets.dart';
import 'package:icr_mobile/features/payments/checkout_start.dart';

class _CountingRepository extends DemoEventsRepository {
  final bought = <String>[];

  @override
  Future<CheckoutStart> buyTicket(EventSummary event) {
    bought.add(event.id);
    return super.buyTicket(event);
  }
}

Future<String> _buy(WidgetTester tester, _CountingRepository repo, EventSummary event) async {
  late BuildContext context;
  await tester.pumpWidget(Builder(builder: (c) {
    context = c;
    return const SizedBox();
  }));
  return buyEventTicket(context, repo, event);
}

void main() {
  testWidgets('an online-only event: refused in the App Store build, sold otherwise', (tester) async {
    final repo = _CountingRepository();
    final online = DemoEventsRepository.ai; // EventFormat.online
    final message = await _buy(tester, repo, online);
    if (StoreRules.sellsDigitalGoods) {
      expect(repo.bought, [online.id]);
      expect(message, 'Payment received. Your seat is confirmed.');
    } else {
      expect(repo.bought, isEmpty, reason: 'no checkout may start for an online event on iOS');
      expect(message, StoreRules.notSoldInApp);
    }
  });

  testWidgets('a hybrid event is sold under either rule set', (tester) async {
    final repo = _CountingRepository();
    final hybrid = DemoEventsRepository.summit; // EventFormat.hybrid
    final message = await _buy(tester, repo, hybrid);
    expect(repo.bought, [hybrid.id]);
    expect(message, 'Payment received. Your seat is confirmed.');
  });
}
