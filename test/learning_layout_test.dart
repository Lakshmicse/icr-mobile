import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/core/widgets/detail_sheet.dart';
import 'package:icr_mobile/features/feed/demo_feed_repository.dart' show DemoFeedRepository;
import 'package:icr_mobile/features/learning/course_sheet.dart';
import 'package:icr_mobile/features/learning/course_sheet_controller.dart';
import 'package:icr_mobile/features/learning/demo_learning_repository.dart';
import 'package:icr_mobile/features/learning/learning_controller.dart';
import 'package:icr_mobile/features/learning/learning_screen.dart';
import 'package:icr_mobile/features/learning_assess/demo_assess_repository.dart';
import 'package:icr_mobile/features/learning_hub/demo_hub_repository.dart';
import 'package:icr_mobile/features/learning_hub/hub_controller.dart';
import 'package:icr_mobile/features/learning_hub/learning_hub_screen.dart';
import 'package:icr_mobile/features/learning_hub/partner_courses_screen.dart';
import 'package:icr_mobile/features/learning_hub/partner_screen.dart';
import 'package:icr_mobile/features/learning_study/demo_study_repository.dart';
import 'package:provider/provider.dart';

import 'helpers/fonts.dart';
import 'helpers/layout_audit.dart';

/// The Learning screens on the sample content, at the widths phones come in, looked over for text drawn in a box
/// shorter than its own lines (the app's 12 sp floor, 27 Oct 2026, left the design's 14–16 dp boxes too short:
/// the course sheet's tabs and "Select Date" row, the institute line on a course card, the "Free" and
/// "Verified by ICR" pills, the "ICR" tab, the section headings). A `clipped` line from [layoutProblems] is
/// text Flutter cuts off without a sound; none of the Learning screens may have one.
void main() {
  setUpAll(loadAppFonts);

  List<String> clipped() => layoutProblems().where((p) => p.startsWith('clipped')).toList();

  Widget app(Widget home, double scale) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: home,
  );

  /// A phone [width] dp wide and tall enough that the whole page is built.
  void phone(WidgetTester tester, double width, {double height = 4000}) {
    tester.view.physicalSize = Size(width * 2, height * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  const widths = [390.0, 360.0];

  group('the course sheet', () {
    for (final width in widths) {
      testWidgets('has no clipped text at ${width.round()} dp', (tester) async {
        phone(tester, width);
        final repo = DemoLearningRepository();
        final controller = CourseSheetController(repository: repo, seed: repo.course);
        await tester.runAsync(controller.load);
        await tester.pumpWidget(
          app(
            ChangeNotifierProvider<LearningController>(
              create: (_) => LearningController(repo),
              child: ChangeNotifierProvider.value(
                value: controller,
                child: const Scaffold(
                  body: DetailSheetFrame(topInset: 0, body: CourseSheetBody(), bottomBar: CourseSheetBar()),
                ),
              ),
            ),
            1,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Select Date'), findsOneWidget, reason: 'the sheet is drawn, with its dates');
        expect(clipped(), isEmpty);
      });
    }
  });

  group('the course list', () {
    for (final width in widths) {
      testWidgets('has no clipped text at ${width.round()} dp', (tester) async {
        phone(tester, width);
        final learning = LearningController(DemoLearningRepository());
        await tester.runAsync(learning.start);
        await tester.pumpWidget(
          app(
            ChangeNotifierProvider.value(
              value: learning,
              child: LearningScreen(onBack: () {}),
            ),
            1,
          ),
        );
        await tester.pumpAndSettle();
        expect(clipped(), isEmpty);
      });
    }
  });

  group('the hub, the institute directory and an institute', () {
    Future<LearningHubController> start(WidgetTester tester) async {
      final hub = LearningHubController(
        repository: DemoLearningHubRepository(),
        learning: LearningController(DemoLearningRepository()),
        assess: DemoAssessRepository(),
        study: DemoStudyRepository(),
      );
      addTearDown(hub.dispose);
      await tester.runAsync(hub.start);
      return hub;
    }

    // The 130 % pass is what the pills, the "ICR" tab and the section headings are for: boxes that fit at the
    // design's size and cut the text at a larger one.
    for (final scale in [1.0, 1.3]) {
      for (final width in widths) {
        final label = '${width.round()} dp at ${(scale * 100).round()}% text';

        testWidgets('the hub has no clipped text at $label', (tester) async {
          phone(tester, width, height: 5000);
          final hub = await start(tester);
          await tester.pumpWidget(
            app(
              LearningHubScreen(onBack: () {}, viewer: DemoFeedRepository.me, onAccount: () {}, controller: hub),
              scale,
            ),
          );
          await tester.pumpAndSettle();
          expect(clipped(), isEmpty);
        });

        testWidgets('the institute directory has no clipped text at $label', (tester) async {
          phone(tester, width);
          final hub = await start(tester);
          await tester.pumpWidget(app(PartnerCoursesScreen(onBack: () {}, hub: hub), scale));
          await tester.pumpAndSettle();
          expect(find.text('Partner institutes'), findsOneWidget);
          expect(find.text('Verified by ICR'), findsWidgets, reason: 'a verified institute is in the sample content');
          expect(clipped(), isEmpty);
        });

        testWidgets('an institute has no clipped text at $label', (tester) async {
          phone(tester, width);
          final hub = await start(tester);
          final institute = hub.institutes.firstWhere((i) => i.verified);
          await tester.pumpWidget(app(PartnerScreen(institute: institute, onBack: () {}, hub: hub), scale));
          await tester.pumpAndSettle();
          expect(clipped(), isEmpty);
        });
      }
    }
  });
}
