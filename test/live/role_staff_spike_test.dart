@Tags(['live'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fonts.dart';
import 'role_staff_support.dart';

void main() {
  setUpAll(loadAppFonts);
  testWidgets('spike srikanth navigation', tags: const ['live'], timeout: const Timeout(Duration(minutes: 5)), (tester) async {
    if (!await liveScreenReady(tester)) return;
    await bootApp(tester, srikanth);
    await pumpUntil(tester, find.byKey(const ValueKey('home-avatar')));
    await settle(tester, timeout: const Duration(seconds: 20));
    await tester.tap(find.bySemanticsLabel('Mentorship').first);
    await settle(tester, timeout: const Duration(seconds: 20));
    final list = find.byWidgetPredicate((w) => w is Scrollable && w.axis == Axis.vertical).first;
    final seen = <String>{};
    for (var i = 0; i < 14; i++) {
      seen.addAll(shownTexts().where((t) => t.isNotEmpty));
      await tester.drag(list, const Offset(0, -500));
      await tester.pump(const Duration(milliseconds: 300));
    }
    print('MENTORSHIP TAB: ${seen.toList()}');
    await tester.tap(find.bySemanticsLabel('Home').first);
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('home-avatar')));
    await pumpUntil(tester, find.text('Settings'));
    await settle(tester);
    print('DRAWER: ${shownTexts().where((t) => t.isNotEmpty).toList()}');
    await finishLive(tester);
  });
}
