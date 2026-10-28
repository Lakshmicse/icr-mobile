import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/features/rfq/api_rfq_repository.dart';
import 'package:icr_mobile/features/rfq/rfq_alerts_screen.dart';
import 'package:icr_mobile/features/rfq/rfq_detail_screen.dart';
import 'package:icr_mobile/features/rfq/opportunity_screen.dart';
import 'package:icr_mobile/features/rfq/rfq_links.dart';
import 'package:icr_mobile/features/rfq/rfq_models.dart';

import 'helpers/fonts.dart';
import 'messaging_fakes.dart' show TableAdapter, clientFor;
import 'rfq_fakes.dart';

/// Every control of "Alerts" (the Marketplace's third chip), tapped. What the
/// API does with a tap is proved in `test/live/rfq_live_test.dart`.
void main() {
  late FlakyRfqRepository repo;

  setUpAll(loadAppFonts);

  setUp(() {
    RfqClock.now = () => DateTime.utc(2026, 10, 25, 9);
    repo = FlakyRfqRepository(now: RfqClock.now());
  });
  tearDown(RfqClock.reset);

  Future<void> open(WidgetTester tester) =>
      pumpScreen(tester, RfqAlertsScreen(repository: repo, links: RecordingRfqLinks()));

  Finder alert(String id) => find.byKey(ValueKey('alert-$id'));

  testWidgets('shows the alerts newest first, the unread ones marked', (tester) async {
    await open(tester);
    expect(find.byType(AlertTile), findsNWidgets(4));
    expect(find.byKey(const ValueKey('alert-unread-dot')), findsNWidgets(2));
    expect(find.textContaining('New bid on'), findsOneWidget);
    expect(find.text('Mark all read'), findsOneWidget);
  });

  testWidgets('the Unread tab keeps the unread ones, and says so when there are none', (tester) async {
    await open(tester);
    await tester.tap(find.text('Unread 2'));
    await settle(tester);
    expect(find.byType(AlertTile), findsNWidgets(2));

    await tester.tap(find.text('Mark all read'));
    await settle(tester);
    expect(find.text('No new alerts'), findsOneWidget);
    expect(repo.calls.where((c) => c == 'markAlertRead'), hasLength(2));

    await tester.tap(find.text('Show all alerts'));
    await settle(tester);
    expect(find.byType(AlertTile), findsNWidgets(4));
    expect(find.byKey(const ValueKey('alert-unread-dot')), findsNothing);
  });

  testWidgets('a tap reads the alert and opens the owner page for a bid', (tester) async {
    await open(tester);
    await tester.tap(alert('demo-alert-1'));
    await settle(tester, 8);
    expect(find.byType(RfqDetailScreen), findsOneWidget);
    expect(repo.calls, contains('markAlertRead'));
  });

  testWidgets('a tap on an invitation opens the supplier page', (tester) async {
    await open(tester);
    await tester.tap(alert('demo-alert-3'));
    await settle(tester, 8);
    expect(find.byType(OpportunityScreen), findsOneWidget);
  });

  testWidgets('an alert the API refuses to mark read goes back to unread, and says why', (tester) async {
    await open(tester);
    repo.refuseNextWrite = 'Not yours to read.';
    await tester.tap(find.text('Mark all read'));
    await settle(tester);
    expect(find.text('Not yours to read.'), findsOneWidget);
    // The first alert stayed unread; the second went through.
    expect(find.byKey(const ValueKey('alert-unread-dot')), findsOneWidget);
  });

  testWidgets('a failed load says so and Try again reads it again', (tester) async {
    repo.failReads = true;
    await open(tester);
    expect(find.text("Couldn't load your alerts"), findsOneWidget);
    expect(find.text('The server said no.'), findsOneWidget);

    repo.failReads = false;
    await tester.tap(find.text('Try again'));
    await settle(tester);
    expect(find.byType(AlertTile), findsNWidgets(4));
  });

  testWidgets('pulling the list down reads the alerts again', (tester) async {
    await open(tester);
    final before = repo.calls.where((c) => c == 'alerts').length;
    await tester.fling(find.byType(AlertTile).first, const Offset(0, 300), 1000);
    await settle(tester, 12);
    expect(repo.calls.where((c) => c == 'alerts').length, greaterThan(before));
  });

  testWidgets('the arrow goes back', (tester) async {
    var backs = 0;
    await pumpScreen(tester, RfqAlertsScreen(repository: repo, onBack: () => backs++));
    await tester.tap(find.bySemanticsLabel('Back'));
    expect(backs, 1);
  });

  test('which side an alert is about is read from its link', () {
    expect(const RfqAlert(id: 'a', title: '', type: 'x', link: '/manage/requirements/r1?bid=b').side, AlertSide.owner);
    expect(const RfqAlert(id: 'a', title: '', type: 'x', link: '/manage/bids/r2').side, AlertSide.supplier);
    expect(const RfqAlert(id: 'a', title: '', type: 'x', link: '/manage/bids/r2').rfqId, 'r2');
    expect(const RfqAlert(id: 'a', title: '', type: 'x', link: '/jobs/1').rfqId, isNull);
  });

  group('a supplier who holds hundreds of notices', () {
    // The API lists notifications newest first, a page at a time, and filters by read state only. A supplier is told
    // about every requirement that matches, so the invitation (page 3 here) sits behind newer notices of other kinds.
    Map<String, dynamic> row(String id, String type, String link) => {
      'id': id,
      'title': id,
      'type': type,
      'link': link,
      'readAt': null,
      'createdAt': '2026-10-25T09:00:00Z',
    };

    TableAdapter adapter() => TableAdapter({
      'GET /notifications': (o) {
        final page = o.queryParameters['page'] as int? ?? 1;
        final rows = switch (page) {
          1 => [for (var i = 0; i < 100; i++) row('promo-$i', 'promotion', '/advertise')],
          2 => [for (var i = 0; i < 100; i++) row('referral-$i', 'referral_reward', '/membership/history')],
          _ => [row('invite', 'rfq_invite', '/manage/bids/r9'), row('award', 'bid_awarded', '/manage/bids/r8')],
        };
        return {
          'data': rows,
          'meta': {'page': page, 'limit': 100, 'hasNext': page < 3},
        };
      },
    });

    test('is not hidden behind a hundred newer notices of other kinds: the alerts read on until the end', () async {
      final api = adapter();
      final alerts = await ApiRfqRepository(api: clientFor(api)).alerts();
      expect(alerts.map((a) => a.id), ['invite', 'award']);
      expect(alerts.map((a) => a.rfqId), ['r9', 'r8']);
      expect(api.requests.map((o) => o.queryParameters['page']), [1, 2, 3]);
    });

    test('the unread filter goes with every page, and a supplier with few notices costs one call', () async {
      final api = adapter();
      await ApiRfqRepository(api: clientFor(api)).alerts(unreadOnly: true);
      expect(api.requests.map((o) => o.queryParameters['unread']), ['true', 'true', 'true']);

      final few = TableAdapter({
        'GET /notifications': (o) => {
          'data': [row('invite', 'rfq_invite', '/manage/bids/r9')],
          'meta': {'page': 1, 'limit': 100, 'hasNext': false},
        },
      });
      expect(await ApiRfqRepository(api: clientFor(few)).alerts(), hasLength(1));
      expect(few.requests, hasLength(1));
    });
  });
}
