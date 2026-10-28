@Tags(['golden'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/councils/councils_controller.dart';
import 'package:icr_mobile/features/councils/councils_screen.dart';
import 'package:icr_mobile/features/councils/demo_councils_repository.dart';
import 'package:provider/provider.dart';

import '../helpers/fonts.dart';

/// The Councils screen at the design's frame (390 × 2829.5, the full
/// export), rendered at 2x and written to build/screens/councils.png for
/// `tool/design/compare.py`.
void main() {
  setUpAll(loadAppFonts);

  Future<void> precacheAll(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element);
      }
    });
    await tester.pumpAndSettle();
  }

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

  testWidgets('councils (demo content) at 390 × 2829.5', (tester) async {
    tester.view.physicalSize = const Size(780, 5659);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final councils = CouncilsController(DemoCouncilsRepository());
    await tester.runAsync(councils.start);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: ChangeNotifierProvider.value(
          value: councils,
          child: CouncilsScreen(onBack: () {}),
        ),
      ),
    );
    await precacheAll(tester);
    await export(tester, find.byType(CouncilsScreen), 'councils');
    await expectLater(find.byType(CouncilsScreen), matchesGoldenFile('goldens/councils.png'));
  });
}
