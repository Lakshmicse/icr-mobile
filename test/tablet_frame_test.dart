import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/widgets/tablet_frame.dart';

/// The centred page frame a wide window gets (owner, 6 Nov 2026: the app should be friendly with tablets).
void main() {
  Future<Size> pumpAt(WidgetTester tester, Size window) async {
    tester.view.physicalSize = window;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late Size seen;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => TabletFrame(child: child!),
        home: Builder(
          builder: (context) {
            seen = MediaQuery.sizeOf(context);
            return const Scaffold(body: SizedBox.expand(key: ValueKey('page')));
          },
        ),
      ),
    );
    return seen;
  }

  testWidgets('a tablet sideways: an 840 dp column in the middle, and the page reads that width', (tester) async {
    final seen = await pumpAt(tester, const Size(1280, 800));
    expect(find.byKey(const ValueKey('tablet-frame')), findsOneWidget);
    final page = tester.getRect(find.byKey(const ValueKey('page')));
    expect(page.width, 840);
    expect(page.left, 220);
    expect(seen.width, 840, reason: 'what is inside lays out by the column, not the window');
  });

  testWidgets('a phone, or a tablet upright, is left alone', (tester) async {
    for (final window in const [Size(390, 844), Size(800, 1280)]) {
      final seen = await pumpAt(tester, window);
      expect(find.byKey(const ValueKey('tablet-frame')), findsNothing, reason: '$window');
      expect(tester.getRect(find.byKey(const ValueKey('page'))).width, window.width, reason: '$window');
      expect(seen.width, window.width);
    }
  });
}
