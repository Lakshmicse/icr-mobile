import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/widgets/title_bar.dart';
import 'package:icr_mobile/features/notifications/unread_counts.dart';
import 'package:provider/provider.dart';

class _Source implements UnreadSource {
  int unread = 0;

  @override
  Future<int> notifications() async => unread;

  @override
  Future<int> messages() async => 0;
}

/// The bell's red dot (owner, 13 Nov 2026: "red dot even if no unread count, it stays"). A screen reads its own
/// count once, when it loads; the bell must follow the app's live count instead, so the dot goes once the
/// notifications are read.
void main() {
  Widget bar(int screenCount) => MaterialApp(
    home: Scaffold(
      body: TitleBar(title: 'Jobs', unread: screenCount, onBell: () {}),
    ),
  );

  testWidgets('the dot goes when the notifications are read, whatever the screen counted when it loaded', (
    tester,
  ) async {
    final counts = UnreadCounts(_Source())..setNotifications(3);
    addTearDown(counts.dispose);
    // The screen read 3 when it opened and still hands that number over.
    await tester.pumpWidget(ChangeNotifierProvider<UnreadCounts>.value(value: counts, child: bar(3)));
    expect(find.bySemanticsLabel('Notifications, 3 unread'), findsOneWidget);

    // The person reads them all on the notifications screen.
    counts.setNotifications(0);
    await tester.pump();
    expect(find.bySemanticsLabel('Notifications'), findsOneWidget);
    expect(find.bySemanticsLabel('Notifications, 3 unread'), findsNothing);

    // A new one arrives: the dot is back without the screen reading anything.
    counts.setNotifications(1);
    await tester.pump();
    expect(find.bySemanticsLabel('Notifications, 1 unread'), findsOneWidget);
  });

  testWidgets('a route pushed beside the provider follows the same count', (tester) async {
    final counts = UnreadCounts(_Source())..setNotifications(2);
    UnreadCounts.current = counts;
    addTearDown(() {
      UnreadCounts.current = null;
      counts.dispose();
    });
    await tester.pumpWidget(bar(2));
    expect(find.bySemanticsLabel('Notifications, 2 unread'), findsOneWidget);
    counts.setNotifications(0);
    await tester.pump();
    expect(find.bySemanticsLabel('Notifications'), findsOneWidget);
  });

  testWidgets('with no app-wide count (a screen on its own) the bell shows the screen\'s number', (tester) async {
    await tester.pumpWidget(bar(4));
    expect(find.bySemanticsLabel('Notifications, 4 unread'), findsOneWidget);
  });
}
