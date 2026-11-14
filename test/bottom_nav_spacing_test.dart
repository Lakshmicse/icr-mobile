import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/shell/icr_bottom_nav.dart';
import 'package:icr_mobile/features/shell/nav_icons.dart';

import 'helpers/fonts.dart';

/// The owner, 13 Nov 2026: "Bottom navigation bar has uneven spacing some icons have the space more some small
/// space." Six equal slots had put the long labels almost touching and left the short ones adrift; each tab now
/// takes its label's width and an equal share of the spare room, so neighbours stand the same distance apart.
void main() {
  setUpAll(loadAppFonts);

  Future<void> pumpBar(WidgetTester tester, double width, {double textScale = 1, AppTab current = AppTab.home}) async {
    tester.view.physicalSize = Size(width * 2, 400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: MediaQuery(
          data: MediaQueryData(size: Size(width, 200), textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            bottomNavigationBar: IcrBottomNav(current: current, onSelect: (_) {}),
          ),
        ),
      ),
    );
  }

  /// The space between each tab and the next. A tab is its label, or its glyph where the word is the narrower.
  List<double> gaps(WidgetTester tester) {
    final spans = [
      for (final tab in IcrBottomNav.tabs)
        () {
          final label = tester.getRect(find.text(tab.label));
          final half = (label.width < IcrBottomNav.glyphWidth ? IcrBottomNav.glyphWidth : label.width) / 2;
          return (left: label.center.dx - half, right: label.center.dx + half);
        }(),
    ];
    return [for (var i = 1; i < spans.length; i++) spans[i].left - spans[i - 1].right];
  }

  for (final width in [360.0, 390.0, 412.0]) {
    testWidgets('the six tabs stand the same distance apart at ${width.toInt()} dp', (tester) async {
      await pumpBar(tester, width);
      final between = gaps(tester);
      final least = between.reduce((a, b) => a < b ? a : b);
      final most = between.reduce((a, b) => a > b ? a : b);
      expect(most - least, lessThan(0.5), reason: 'gaps $between');
      expect(least, greaterThan(IcrBottomNav.minGap));
      // The bar is filled edge to edge and nothing overflows.
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('each glyph sits over the middle of its own label', (tester) async {
    await pumpBar(tester, 390);
    for (final tab in IcrBottomNav.tabs) {
      final item = tester.getRect(find.bySemanticsLabel(tab.label));
      final label = tester.getRect(find.text(tab.label));
      expect(label.center.dx, closeTo(item.center.dx, 0.6), reason: tab.label);
    }
  });

  testWidgets('a tab is its outline until it is the open one, then the filled glyph', (tester) async {
    // Owner, 13 Nov 2026: "before selection it should be outlined icons once selected convert it to filled".
    IconData? glyphOf(AppTab tab) {
      final icon = find.descendant(of: find.bySemanticsLabel(tab.label), matching: find.byType(Icon));
      return icon.evaluate().isEmpty ? null : tester.widget<Icon>(icon).icon;
    }

    bool? drawnFilled(AppTab tab) {
      final item = find.bySemanticsLabel(tab.label);
      final house = find.descendant(of: item, matching: find.byType(HouseIcon));
      if (house.evaluate().isNotEmpty) return tester.widget<HouseIcon>(house).filled;
      final briefcase = find.descendant(of: item, matching: find.byType(BriefcaseIcon));
      if (briefcase.evaluate().isNotEmpty) return tester.widget<BriefcaseIcon>(briefcase).filled;
      return null;
    }

    await pumpBar(tester, 390);
    expect(drawnFilled(AppTab.home), isTrue, reason: 'Home is open');
    expect(drawnFilled(AppTab.jobs), isFalse);
    expect(glyphOf(AppTab.learning), Icons.school_outlined);
    expect(glyphOf(AppTab.mentorship), Icons.group_outlined);
    expect(glyphOf(AppTab.marketplace), Icons.storefront_outlined);
    expect(glyphOf(AppTab.discover), Icons.grid_view_outlined);

    await pumpBar(tester, 390, current: AppTab.learning);
    expect(drawnFilled(AppTab.home), isFalse);
    expect(glyphOf(AppTab.learning), Icons.school_rounded);

    await pumpBar(tester, 390, current: AppTab.jobs);
    expect(drawnFilled(AppTab.jobs), isTrue);
    expect(glyphOf(AppTab.learning), Icons.school_outlined);
    await pumpBar(tester, 390, current: AppTab.discover);
    expect(glyphOf(AppTab.discover), Icons.grid_view_rounded);
    await pumpBar(tester, 390, current: AppTab.marketplace);
    expect(glyphOf(AppTab.marketplace), Icons.storefront_rounded);
    await pumpBar(tester, 390, current: AppTab.mentorship);
    expect(glyphOf(AppTab.mentorship), Icons.group_rounded);
  });

  testWidgets('with a very large font the bar falls back to equal slots and nothing overflows', (tester) async {
    await pumpBar(tester, 360, textScale: 2);
    expect(tester.takeException(), isNull);
    final widths = {
      for (final tab in IcrBottomNav.tabs) tester.getSize(find.bySemanticsLabel(tab.label)).width.round(),
    };
    expect(widths, hasLength(1), reason: 'equal slots');
  });
}
