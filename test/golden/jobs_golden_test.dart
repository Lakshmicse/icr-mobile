@Tags(['golden'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/core/widgets/detail_sheet.dart';
import 'package:icr_mobile/features/jobs/demo_jobs_repository.dart';
import 'package:icr_mobile/features/jobs/job_detail_controller.dart';
import 'package:icr_mobile/features/jobs/job_detail_sheet.dart';
import 'package:icr_mobile/features/jobs/jobs_controller.dart';
import 'package:icr_mobile/features/jobs/jobs_screen.dart';
import 'package:provider/provider.dart';

import '../helpers/fonts.dart';

/// The Jobs screens at the designs' frames, exported at 2x to build/screens/.
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

  testWidgets('jobs board (demo content) at 390 × 1030.5', (tester) async {
    tester.view.physicalSize = const Size(780, 2061);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final jobs = JobsController(DemoJobsRepository());
    await tester.runAsync(jobs.start);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: ChangeNotifierProvider.value(
          value: jobs,
          child: JobsScreen(onBack: () {}),
        ),
      ),
    );
    await precacheAll(tester);
    await export(tester, find.byType(JobsScreen), 'jobs_board');
    await expectLater(find.byType(JobsScreen), matchesGoldenFile('goldens/jobs_board.png'));
  });

  testWidgets('job sheet (demo content) at 390 × 1372', (tester) async {
    tester.view.physicalSize = const Size(780, 2744);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final repo = DemoJobsRepository();
    final controller = JobDetailController(repository: repo, seed: repo.detailJob);
    await tester.runAsync(controller.load);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: ChangeNotifierProvider<JobsController>(
          create: (_) => JobsController(repo),
          child: ChangeNotifierProvider.value(
            value: controller,
            child: const Scaffold(
              backgroundColor: Colors.black,
              body: DetailSheetFrame(topInset: 0, body: JobSheetBody(), bottomBar: JobSheetBar()),
            ),
          ),
        ),
      ),
    );
    await precacheAll(tester);
    await export(tester, find.byType(DetailSheetFrame), 'job_sheet');
    await expectLater(find.byType(DetailSheetFrame), matchesGoldenFile('goldens/job_sheet.png'));
  });
}
