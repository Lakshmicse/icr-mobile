import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/feed/demo_feed_repository.dart';
import 'package:icr_mobile/features/mentorship/demo_mentorship_repository.dart';
import 'package:icr_mobile/features/mentorship/find_mentors_screen.dart';
import 'package:icr_mobile/features/mentorship/mentorship_controller.dart';
import 'package:icr_mobile/features/mentorship/mentorship_models.dart';
import 'package:icr_mobile/features/mentorship/mentorship_repository.dart';
import 'package:icr_mobile/features/mentorship/mentorship_screen.dart';
import 'package:provider/provider.dart';

import 'helpers/fonts.dart';
import 'helpers/layout_audit.dart';

/// The demo's landing with the cohort's avatars the way the live API ends them: the organiser's initials and a
/// count, "+31".
class _WithCount extends DemoMentorshipRepository {
  @override
  Future<MentorshipOverview> overview({String? category}) async {
    final o = await super.overview(category: category);
    final c = o.cohort!;
    return MentorshipOverview(
      categories: o.categories,
      selectedCategory: o.selectedCategory,
      domainsBadge: o.domainsBadge,
      companies: o.companies,
      shelves: o.shelves,
      topics: o.topics,
      banner: o.banner,
      cohort: MentorCohort(
        id: c.id,
        name: c.name,
        registeredLabel: '32 Registered',
        avatars: const [
          CohortAvatar(initials: 'RK'),
          CohortAvatar(initials: '+31'),
        ],
        cover: c.cover,
      ),
      services: o.services,
    );
  }
}

void main() {
  setUpAll(loadAppFonts);

  /// A design's fixed heights were set for text under the app's 12 sp floor, so a mentor's name, the cohort
  /// card's kicker and the "+31" of its avatars were cut at the bottom (or wrapped inside a circle too small
  /// for them). Both the common 390 dp phone and a narrow 360 dp one, where the cards are narrower still.
  group('no text on the Mentorship screens is cut off by its box', () {
    void sized(WidgetTester tester, double width, double height) {
      tester.view.physicalSize = Size(width * 2, height * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
    }

    Future<void> pumpLanding(WidgetTester tester, MentorshipRepository repository) async {
      final mentorship = MentorshipController(repository);
      await tester.runAsync(mentorship.start);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: ChangeNotifierProvider.value(
            value: mentorship,
            child: MentorshipScreen(
              onBack: () {},
              onOpenMentor: (context, id) {},
              viewer: DemoFeedRepository.me,
              onAccount: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    void expectNothingCut(WidgetTester tester) {
      expect(layoutProblems().where((p) => p.startsWith('clipped')), isEmpty);
      expect(tester.takeException(), isNull);
    }

    for (final width in [390.0, 360.0]) {
      testWidgets('the landing at ${width.toInt()} dp', (tester) async {
        sized(tester, width, 4600);
        await pumpLanding(tester, DemoMentorshipRepository());
        expect(find.text('UPCOMING COHORT'), findsOneWidget);
        expectNothingCut(tester);
      });

      testWidgets('the landing with a "+31" cohort count at ${width.toInt()} dp', (tester) async {
        sized(tester, width, 4600);
        await pumpLanding(tester, _WithCount());
        expect(find.text('+31'), findsOneWidget);
        // The count stays on one line, in a pill at least as wide as its words.
        final count = tester.getSize(find.text('+31'));
        expect(count.height, lessThan(20));
        expectNothingCut(tester);
      });

      testWidgets('Find Mentors at ${width.toInt()} dp', (tester) async {
        sized(tester, width, 2400);
        // The design's state: Operations & FM, with a 10+ years experience filter.
        final controller = FindMentorsController(DemoMentorshipRepository(), category: 'Operations & FM');
        await tester.runAsync(() async {
          await controller.start();
          await controller.setMinExperience(10);
        });
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(),
            home: FindMentorsScreen(
              onBack: () {},
              onOpenMentor: (context, id) {},
              category: 'Operations & FM',
              controller: controller,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Rajesh Sharma'), findsWidgets);
        expectNothingCut(tester);
      });
    }
  });
}
