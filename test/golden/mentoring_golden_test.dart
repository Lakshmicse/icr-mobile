@Tags(['golden'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/features/mentorship_my/mentoring_clock.dart';
import 'package:icr_mobile/features/mentorship_my/my_mentoring_controller.dart';

import '../helpers/fonts.dart';
import '../mentoring_fakes.dart';

/// The mentoring screens as the API fills them (fixtures with the real shapes) at a phone's 390 dp,
/// exported at 2x to build/screens/ to look at, and pinned as goldens. The clock is pinned: the
/// fixtures are dated from it, and "tomorrow" and "in 3 days" read the same on any day.
void main() {
  setUpAll(loadAppFonts);

  setUp(() => mentoringNow = () => DateTime(2026, 10, 26, 10));
  tearDown(() => mentoringNow = DateTime.now);

  Future<void> export(WidgetTester tester, Finder finder, String name) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.ancestor(of: finder, matching: find.byType(RepaintBoundary)).first,
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('build/screens').createSync(recursive: true);
      File('build/screens/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  Future<void> shot(
    WidgetTester tester,
    String name,
    Map<String, Reply> routes, {
    MyTab tab = MyTab.mentoring,
    double height = 1700,
  }) async {
    await pumpMyMentoring(tester, routes, tab: tab, height: height);
    await export(tester, find.byType(Scaffold).first, name);
  }

  testWidgets('My mentoring, the Mentoring tab', (tester) async {
    await shot(tester, 'mentoring_my', menteeRoutes());
  });

  testWidgets('My mentoring, Requests (mentee)', (tester) async {
    await shot(tester, 'mentoring_requests', menteeRoutes(), tab: MyTab.requests);
  });
}
