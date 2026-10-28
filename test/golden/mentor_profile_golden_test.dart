@Tags(['golden'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/core/widgets/detail_sheet.dart';
import 'package:icr_mobile/features/mentor_profile/demo_mentor_profile_repository.dart';
import 'package:icr_mobile/features/mentor_profile/mentor_profile_controller.dart';
import 'package:icr_mobile/features/mentor_profile/mentor_profile_screen.dart';
import 'package:icr_mobile/features/mentor_profile/offering_sheet.dart';
import 'package:provider/provider.dart';

import '../helpers/fonts.dart';

/// The Mentor Profile screens at the designs' frames, exported at 2x to build/screens/.
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

  Future<MentorProfileController> loaded(WidgetTester tester, {ProfileTab tab = ProfileTab.overview}) async {
    final controller = MentorProfileController(
      repository: DemoMentorProfileRepository(),
      mentorId: DemoMentorProfileRepository.mentor.id,
    );
    await tester.runAsync(controller.load);
    controller.selectTab(tab);
    return controller;
  }

  testWidgets('mentor profile, Overview (demo content) at 390 × 2272', (tester) async {
    tester.view.physicalSize = const Size(780, 4544);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final controller = await loaded(tester);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: ChangeNotifierProvider.value(
          value: controller,
          child: MentorProfileScreen(mentorId: controller.mentorId, onBack: () {}),
        ),
      ),
    );
    await precacheAll(tester);
    await export(tester, find.byType(MentorProfileScreen), 'mentor_profile_overview');
    await expectLater(find.byType(MentorProfileScreen), matchesGoldenFile('goldens/mentor_profile_overview.png'));
  });

  testWidgets('mentor profile, Offerings (demo content) at 390 × 1595', (tester) async {
    tester.view.physicalSize = const Size(780, 3190);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final controller = await loaded(tester, tab: ProfileTab.offerings);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: ChangeNotifierProvider.value(
          value: controller,
          child: MentorProfileScreen(mentorId: controller.mentorId, onBack: () {}),
        ),
      ),
    );
    await precacheAll(tester);
    await export(tester, find.byType(MentorProfileScreen), 'mentor_profile_offerings');
    await expectLater(find.byType(MentorProfileScreen), matchesGoldenFile('goldens/mentor_profile_offerings.png'));
  });

  testWidgets('offering sheet (demo content) at 390 × 951.6', (tester) async {
    tester.view.physicalSize = const Size(780, 1903);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final offering = DemoMentorProfileRepository.discoveryCall;
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: Scaffold(
          backgroundColor: Colors.black,
          body: DetailSheetFrame(
            topInset: 0,
            body: OfferingSheetBody(offering: offering),
            bottomBar: OfferingSheetBar(
              offering: offering,
              plan: DemoMentorProfileRepository.proTier,
              onPlans: () {},
              onPrimary: () {},
            ),
          ),
        ),
      ),
    );
    await precacheAll(tester);
    await export(tester, find.byType(DetailSheetFrame), 'offering_sheet');
    await expectLater(find.byType(DetailSheetFrame), matchesGoldenFile('goldens/offering_sheet.png'));
  });
}
