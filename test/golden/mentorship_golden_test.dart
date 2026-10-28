@Tags(['golden'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/feed/demo_feed_repository.dart';
import 'package:icr_mobile/features/mentorship/api_mentorship_repository.dart';
import 'package:icr_mobile/features/mentorship/demo_mentorship_repository.dart';
import 'package:icr_mobile/features/mentorship/find_mentors_screen.dart';
import 'package:icr_mobile/features/mentorship/mentorship_controller.dart';
import 'package:icr_mobile/features/mentorship/mentorship_format.dart';
import 'package:icr_mobile/features/mentorship/mentorship_models.dart';
import 'package:icr_mobile/features/mentorship/mentorship_screen.dart';
import 'package:provider/provider.dart';

import '../helpers/fonts.dart';

/// The Mentorship screens at the designs' frames, exported at 2x to
/// build/screens/ (mentorship_landing.png, find_mentors.png).
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

  // The landing's frame is 390 × 2829 above the shell's bottom bar.
  testWidgets('mentorship landing (demo content) at 390 × 2829', (tester) async {
    tester.view.physicalSize = const Size(780, 5658);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final mentorship = MentorshipController(DemoMentorshipRepository());
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
    await precacheAll(tester);
    await export(tester, find.byType(MentorshipScreen), 'mentorship_landing');
    await expectLater(find.byType(MentorshipScreen), matchesGoldenFile('goldens/mentorship_landing.png'));
  });

  // Find Mentors' frame is 390 × 937 above the bottom bar the design draws.
  testWidgets('find mentors (demo content) at 390 × 937', (tester) async {
    tester.view.physicalSize = const Size(780, 1874);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

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
    await precacheAll(tester);
    await export(tester, find.byType(FindMentorsScreen), 'find_mentors');
    await expectLater(find.byType(FindMentorsScreen), matchesGoldenFile('goldens/find_mentors.png'));
  });
  // What the landing draws when the API fills it: the live variants of the
  // pill, the tiles, the topic tints, the banner sentence, the cohort card with
  // its cover and "+31", and the design's repeated title. Not a design to
  // compare, a render to look at (and to catch a layout that breaks on it).
  testWidgets('mentorship landing (as the live API fills it) at 390 wide', (tester) async {
    tester.view.physicalSize = const Size(780, 5800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final mentorship = MentorshipController(_LiveShaped());
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
    await precacheAll(tester);
    await export(tester, find.byType(MentorshipScreen), 'mentorship_landing_live');
    await expectLater(find.byType(MentorshipScreen), matchesGoldenFile('goldens/mentorship_landing_live.png'));
  });

  // Find Mentors opened from a company tile: the chip, an empty search box.
  testWidgets('find mentors on a company chip at 390 wide', (tester) async {
    tester.view.physicalSize = const Size(780, 1874);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final controller = FindMentorsController(
      DemoMentorshipRepository(),
      category: 'Operations & FM',
      company: 'Infosys',
      minExperience: 10,
    );
    await tester.runAsync(controller.start);
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
    await precacheAll(tester);
    await export(tester, find.byType(FindMentorsScreen), 'find_mentors_company');
    await expectLater(find.byType(FindMentorsScreen), matchesGoldenFile('goldens/find_mentors_company.png'));
  });
}

/// The demo's people with the live source's wording: what `ApiMentorshipRepository`
/// would send for the seeded database.
class _LiveShaped extends DemoMentorshipRepository {
  @override
  Future<MentorshipOverview> overview({String? category}) async {
    final o = await super.overview(category: category);
    const names = ['Microsoft', 'Amazon', 'JLL', 'CBRE', 'Google', 'Infosys', 'Cisco', 'SpaceX'];
    final topics = ApiMentorshipRepository.toneTopics([
      for (final (i, t) in DemoMentorshipRepository.topics.indexed) MentorCategory(label: t.label, count: 30 - i),
    ], const {});
    return MentorshipOverview(
      categories: o.categories,
      selectedCategory: o.selectedCategory,
      domainsBadge: domainsBadgeFor(58),
      companies: [for (final n in names) MentorCompany(name: n)],
      shelves: o.shelves,
      topics: topics,
      banner: MentorBanner(
        title: o.banner!.title,
        body: ApiMentorshipRepository.bannerBody(64),
        cta: o.banner!.cta,
        photo: mentorBannerPhoto,
        link: o.banner!.link,
      ),
      cohort: const MentorCohort(
        id: 'live-cohort',
        name: 'FM Leadership & ESG Masterclass',
        registeredLabel: '32 Registered',
        avatars: [
          CohortAvatar(initials: 'RK'),
          CohortAvatar(initials: '+31'),
        ],
        cover: FeedPicture.asset('assets/images/demo/mentorship/profile_offering_cover.jpg'),
      ),
      services: o.services,
    );
  }
}
