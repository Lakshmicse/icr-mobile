import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/mentor_profile/demo_mentor_profile_repository.dart';
import 'package:icr_mobile/features/mentor_profile/mentor_profile_controller.dart';
import 'package:icr_mobile/features/mentor_profile/mentor_profile_screen.dart';
import 'package:icr_mobile/features/mentor_profile/widgets/overview_sections.dart';
import 'package:provider/provider.dart';

import 'helpers/clipped_text.dart';
import 'helpers/fonts.dart';

void main() {
  setUpAll(loadAppFonts);

  /// A design's fixed heights were set for text under the app's 12 sp floor, so a label in a short box was cut
  /// at the bottom (the skill labels, the reviewer's line) and a row that no longer fitted overflowed. Both the
  /// common 390 dp phone and a narrow 360 dp one, where chips wrap onto more rows.
  group('no text on the Mentor Profile is cut off by its box', () {
    Future<MentorProfileController> pump(WidgetTester tester, {required double width}) async {
      tester.view.physicalSize = Size(width * 2, 4600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final controller = MentorProfileController(repository: DemoMentorProfileRepository(), mentorId: 'demo-srikanth');
      await tester.runAsync(controller.load);
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
      await tester.pumpAndSettle();
      return controller;
    }

    // A tablet too (owner, 16 Nov 2026): the designs' phone measures must give way, never cut or overflow.
    for (final width in [390.0, 360.0, 1000.0]) {
      for (final tab in ProfileTab.values) {
        testWidgets('the ${tab.name} tab at ${width.toInt()} dp', (tester) async {
          final controller = await pump(tester, width: width);
          controller.selectTab(tab);
          await tester.pumpAndSettle();
          expect(clippedText(tester), isEmpty);
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets("on a tablet the About text runs the width of the page, not the phone design's 305 dp", (tester) async {
      await pump(tester, width: 1000);
      final about = find.descendant(of: find.byType(AboutSection), matching: find.byType(Text));
      // The heading, then the bio's paragraphs.
      expect(tester.getSize(about.at(1)).width, closeTo(1000 - 2 * 22.7, 0.5));
    });

    testWidgets("on a phone the About text keeps the design's 305 dp", (tester) async {
      await pump(tester, width: 390);
      final about = find.descendant(of: find.byType(AboutSection), matching: find.byType(Text));
      expect(tester.getSize(about.at(1)).width, 305);
    });
  });
}
