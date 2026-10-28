import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/features/shell/icr_bottom_nav.dart';
import 'package:icr_mobile/features/shell/scroll_hiding_bar.dart';
import 'package:icr_mobile/features/shell/shell_page.dart';

import 'helpers/fonts.dart';

/// The bottom bar leaves while a page scrolls down and returns on the way up, as LinkedIn's does.
void main() {
  setUpAll(loadAppFonts);

  Widget harness(Widget child) => MaterialApp(home: ShellPage(tab: AppTab.home, child: child));

  Widget longList() => ListView(children: [for (var i = 0; i < 60; i++) SizedBox(height: 100, child: Text('row $i'))]);

  bool shown(WidgetTester tester) => tester.widget<HidingBar>(find.byType(HidingBar)).controller.shown;
  double barHeight(WidgetTester tester) => tester.getSize(find.byType(HidingBar)).height;

  testWidgets('scrolling down hides the bar, scrolling up brings it back', (tester) async {
    await tester.pumpWidget(harness(longList()));
    expect(shown(tester), isTrue);
    final open = barHeight(tester);
    expect(open, greaterThan(IcrBottomNav.height - 1));

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(shown(tester), isFalse, reason: 'a drag up of 300 dp is a scroll down');
    expect(barHeight(tester), lessThan(1), reason: 'the bar gives its room back to the page');

    // Inside the settling window nothing moves the bar, so wait it out as a person would.
    await tester.pump(BarVisibility.settle);
    await tester.drag(find.byType(ListView), const Offset(0, 120));
    await tester.pumpAndSettle();
    expect(shown(tester), isTrue, reason: 'a drag down is a scroll up');
    expect(barHeight(tester), open);
  });

  testWidgets('the top of a page always has the bar', (tester) async {
    await tester.pumpWidget(harness(longList()));
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(shown(tester), isFalse);
    await tester.pump(BarVisibility.settle);

    await tester.fling(find.byType(ListView), const Offset(0, 3000), 3000);
    await tester.pumpAndSettle();
    expect(shown(tester), isTrue);
  });

  testWidgets('a short page never hides it', (tester) async {
    await tester.pumpWidget(harness(ListView(children: [for (var i = 0; i < 6; i++) SizedBox(height: 100, child: Text('row $i'))])));
    await tester.drag(find.byType(ListView), const Offset(0, -80));
    await tester.pumpAndSettle();
    expect(shown(tester), isTrue);
  });

  testWidgets('a sideways rail does not hide it', (tester) async {
    await tester.pumpWidget(
      harness(
        ListView(
          children: [
            SizedBox(
              height: 120,
              child: ListView(scrollDirection: Axis.horizontal, children: [for (var i = 0; i < 20; i++) SizedBox(width: 120, child: Text('card $i'))]),
            ),
            for (var i = 0; i < 40; i++) SizedBox(height: 100, child: Text('row $i')),
          ],
        ),
      ),
    );
    await tester.drag(find.text('card 1'), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(shown(tester), isTrue);
  });
}
