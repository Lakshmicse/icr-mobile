@Tags(['golden'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/rfq/demo_rfq_repository.dart';
import 'package:icr_mobile/features/rfq/my_bids_screen.dart';
import 'package:icr_mobile/features/rfq/my_rfqs_screen.dart';
import 'package:icr_mobile/features/rfq/open_requirements_screen.dart';
import 'package:icr_mobile/features/rfq/rfq_alerts_screen.dart';
import 'package:icr_mobile/features/rfq/rfq_links.dart';

import '../helpers/fonts.dart';
import '../rfq_fakes.dart';

/// The requirements screens drawn from the sample content, at a phone's 390 dp, exported at 2x to
/// build/screens/rfq_*.png and pinned to goldens/rfq_*.png. There is no design for these screens: they are
/// judged beside the Marketplace, Supplier and Jobs designs (docs/screens/rfq.md), and the golden keeps
/// them from drifting. The clock is pinned, because every deadline on them is relative to it.
void main() {
  setUpAll(() async {
    RfqClock.now = () => DateTime.utc(2026, 10, 25, 9);
    await loadAppFonts();
  });
  tearDownAll(RfqClock.reset);

  /// Draws [screen] in a window [height] dp tall, exports it and compares it with the golden [name].
  Future<void> shoot(WidgetTester tester, Widget screen, String name, {double height = 844}) async {
    tester.view.physicalSize = Size(780, height * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, theme: buildAppTheme(), home: screen));
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element);
      }
    });
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.ancestor(of: find.byType(Scaffold).first, matching: find.byType(RepaintBoundary)).first,
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('build/screens').createSync(recursive: true);
      File('build/screens/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
  }

  DemoRfqRepository demo() => DemoRfqRepository(now: RfqClock.now());

  testWidgets('My RFQ\'s', (tester) async {
    await shoot(tester, MyRfqsScreen(repository: demo(), links: RecordingRfqLinks()), 'rfq_my_rfqs', height: 900);
  });

  testWidgets('Alerts', (tester) async {
    await shoot(tester, RfqAlertsScreen(repository: demo(), links: RecordingRfqLinks()), 'rfq_alerts');
  });

  testWidgets('Find work (the open board)', (tester) async {
    await shoot(
      tester,
      OpenRequirementsScreen(repository: demo(), links: RecordingRfqLinks()),
      'rfq_board',
      height: 900,
    );
  });

  testWidgets('My Bids', (tester) async {
    await shoot(tester, MyBidsScreen(repository: demo(), links: RecordingRfqLinks()), 'rfq_my_bids');
  });
}
