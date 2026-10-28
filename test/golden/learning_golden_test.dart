@Tags(['golden'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/auth/token_store.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/core/widgets/detail_sheet.dart';
import 'package:icr_mobile/features/feed/demo_feed_repository.dart' show DemoFeedRepository;
import 'package:icr_mobile/features/learning/api_learning_repository.dart';
import 'package:icr_mobile/features/learning/course_sheet.dart';
import 'package:icr_mobile/features/learning/course_sheet_controller.dart';
import 'package:icr_mobile/features/learning/demo_learning_repository.dart';
import 'package:icr_mobile/features/learning/learning_controller.dart';
import 'package:icr_mobile/features/learning/learning_format.dart';
import 'package:icr_mobile/features/learning/learning_models.dart';
import 'package:icr_mobile/features/learning/learning_repository.dart';
import 'package:icr_mobile/features/learning/learning_screen.dart';
import 'package:icr_mobile/features/learning_assess/demo_assess_repository.dart';
import 'package:icr_mobile/features/learning_study/demo_study_repository.dart';
import 'package:icr_mobile/features/learning_hub/hub_controller.dart';
import 'package:icr_mobile/features/learning_hub/hub_models.dart';
import 'package:icr_mobile/features/learning_hub/hub_repository.dart';
import 'package:icr_mobile/features/learning_hub/learning_hub_screen.dart';
import 'package:icr_mobile/features/learning_hub/partner_courses_screen.dart';
import 'package:icr_mobile/features/learning_hub/partner_screen.dart';
import 'package:provider/provider.dart';

import '../helpers/fonts.dart';

const _cover = FeedPicture.asset('assets/images/demo/learning/course_cover_clean.png');
const _specialist = FeedPicture.asset('assets/images/demo/learning/specialist.png');
const _badge = FeedPicture.asset('assets/images/demo/learning/badge_icr.png');

class _NoTokens extends TokenStore {
  @override
  Future<String?> accessToken() async => 'token';
  @override
  Future<String?> refreshToken() async => null;
}

/// Serves the recorded responses of the local API (`test/fixtures/learning/`:
/// the seeded CALS course, its reviews and Bharat Buyer's places), so the
/// course sheet is drawn from what the live API sends, not from the design's
/// sample content.
class _Recorded implements HttpClientAdapter {
  _Recorded({required this.enrolled});

  final bool enrolled;

  static Object _json(String name) =>
      jsonDecode(File('test/fixtures/learning/$name.json').readAsStringSync()) as Object;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final Object body = switch ('${options.method} ${options.path}') {
      'GET /learning/me/enrollments' => enrolled ? _json('bharat_enrollments') : <Object>[],
      'GET /learning/courses' => [_json('cals_detail')],
      'GET /learning/courses/CALS' => _json('cals_detail'),
      'GET /learning/courses/CALS/reviews' => _json('cals_reviews'),
      _ => <String, Object>{},
    };
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// The live source, with the pictures it would fetch swapped for bundled ones
/// (a widget test cannot reach the network).
class _WithBundledPictures implements LearningRepository {
  _WithBundledPictures(this.inner);

  final ApiLearningRepository inner;

  Course _swap(Course c) => Course(
    id: c.id,
    code: c.code,
    title: c.title,
    slug: c.slug,
    summary: c.summary,
    description: c.description,
    kind: c.kind,
    level: c.level,
    provider: c.provider,
    cover: _cover,
    badge: c.badge,
    priceAmount: c.priceAmount,
    durationLabel: c.durationLabel,
    deliveryMode: c.deliveryMode,
    language: c.language,
    cpdCredits: c.cpdCredits,
    certificateEnabled: c.certificateEnabled,
    enrollmentOpen: c.enrollmentOpen,
    brochureUrl: c.brochureUrl,
    runs: c.runs,
    modules: c.modules,
    outcomes: c.outcomes,
    prerequisites: c.prerequisites,
    audience: c.audience,
    aboutCertificate: c.aboutCertificate,
    certificateBadges: c.certificateBadges.isEmpty ? const [] : const [_badge],
    contact: c.contact == null
        ? null
        : CourseContact(name: c.contact!.name, role: c.contact!.role, photo: _specialist, email: c.contact!.email),
    enrolment: c.enrolment,
    detailLoaded: c.detailLoaded,
  );

  @override
  Future<List<Course>> courses() async => [for (final c in await inner.courses()) _swap(c)];
  @override
  Future<Course> detail(Course course) async => _swap(await inner.detail(course));
  @override
  Future<List<MyEnrolment>> myEnrolments() => inner.myEnrolments();
  @override
  Future<CourseReviews> reviews(Course course) => inner.reviews(course);
  @override
  Future<MyEnrolment> enrol(Course course, {CourseRun? run}) => inner.enrol(course, run: run);
  @override
  Future<void> enquire(
    Course course, {
    required String message,
    EnquiryKind kind = EnquiryKind.question,
    String? company,
    int? headcount,
  }) => inner.enquire(course, message: message, kind: kind, company: company, headcount: headcount);
  @override
  Future<int> unreadNotifications() async => 1;
  @override
  Uri link(Course course) => inner.link(course);
  @override
  Uri checkoutLink(Course course, CourseRun? run) => inner.checkoutLink(course, run);
}

/// A catalogue that shows every part of a card: a course Bharat holds a place on, a paid one with credits and
/// an institute's logo, and certification programmes (one with no cover, so it wears its initials).
class _Catalogue extends DemoLearningRepository {
  @override
  Future<List<Course>> courses() async => [
    course.copyWith(
      enrolment: MyEnrolment(
        id: 'e',
        courseId: course.id,
        runId: 'demo-run-1',
        status: EnrolmentStatus.confirmed,
        startsAt: DateTime(2027, 8, 23),
        endsAt: DateTime(2027, 8, 27),
        location: 'Riyadh, KSA',
      ),
    ),
    Course(
      id: 'adv',
      code: 'ADV',
      title: 'Advanced Facilities Asset Management and Lifecycle Planning',
      kind: CourseKind.development,
      level: 'Advanced',
      provider: const CourseProvider(id: 'p', name: 'Vinfraa Institute', logo: _badge, verified: true),
      cover: const FeedPicture.asset('assets/images/demo/post_control_room.jpg'),
      badge: coverBadge('ADVANCED', CourseKind.development, certificateEnabled: true),
      certificateEnabled: true,
      priceAmount: 1180000,
      durationLabel: '3 days · 24 hours',
      deliveryMode: 'Virtual live training',
      cpdCredits: 24,
    ),
    Course(
      id: 'cp',
      code: 'CP',
      title: 'Capital Planning',
      kind: CourseKind.assessment,
      level: 'Foundation',
      cover: const FeedPicture.asset('assets/images/demo/post_green_tower.jpg'),
      badge: coverBadge('FOUNDATION', CourseKind.assessment),
    ),
    Course(
      id: 'cm',
      code: 'CM',
      title: 'Contract Management',
      kind: CourseKind.assessment,
      level: 'Foundation',
      cover: const FeedPicture.asset('assets/images/demo/post_rooftop_hvac.jpg'),
      badge: coverBadge('FOUNDATION', CourseKind.assessment),
    ),
    Course(
      id: 'em',
      code: 'EM',
      title: 'Energy Management',
      kind: CourseKind.assessment,
      level: 'Foundation',
      badge: coverBadge('FOUNDATION', CourseKind.assessment),
    ),
  ];
}

/// The hub's own repository, filled with what the local API holds (an institute with a logo and its one course) and
/// two more so every card variant shows: a verified one, and one with no logo that has published nothing.
class _HubSource implements LearningHubRepository {
  @override
  Future<List<Institute>> institutes() async => const [
    Institute(
      id: 'p',
      name: 'Vinfraa Institute',
      slug: 'vinfraa',
      summary: 'Facility management certifications, delivered through ICR in Riyadh, London and Dubai.',
      logo: _badge,
      verified: true,
      courseCount: 1,
      website: 'https://vinfraa.example',
    ),
    Institute(
      id: 'icr',
      name: 'ICR Institute',
      slug: 'icr-institute',
      summary: "ICR's own institute for professional development and certification.",
      logo: _badge,
      courseCount: 0,
    ),
    Institute(id: 'ald', name: 'Aldersgate Training Academy', slug: 'aldersgate', courseCount: 0),
  ];

  @override
  Future<MyLearning> myLearning() async => const MyLearning(attempts: 3, certificates: 1);

  @override
  Future<void> enquireInstitute(Institute institute, {required String message}) async {}
}

/// The Learning screens at the designs' frames, exported at 2x to build/screens/.
void main() {
  setUpAll(loadAppFonts);

  // flutter_test draws every shadow as a hard-edged offset shape (debugDisableShadows), which hides the
  // design's soft ones (the pinned bar, the selected tile, the title bar). Each test draws with real blur,
  // and puts the flag back before it ends: the test binding checks it then.
  void shadowedWidgets(String name, Future<void> Function(WidgetTester tester) body) {
    testWidgets(name, (tester) async {
      debugDisableShadows = false;
      try {
        await body(tester);
      } finally {
        debugDisableShadows = true;
      }
    });
  }

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

  Future<void> pumpSheet(WidgetTester tester, LearningRepository repo, Course seed, double heightDp) async {
    tester.view.physicalSize = Size(780, heightDp * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final controller = CourseSheetController(repository: repo, seed: seed);
    await tester.runAsync(controller.load);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: ChangeNotifierProvider<LearningController>(
          create: (_) => LearningController(repo),
          child: ChangeNotifierProvider.value(
            value: controller,
            child: const Scaffold(
              backgroundColor: Colors.black,
              body: DetailSheetFrame(topInset: 0, body: CourseSheetBody(), bottomBar: CourseSheetBar()),
            ),
          ),
        ),
      ),
    );
    await precacheAll(tester);
  }

  shadowedWidgets('learning list (demo content) at 390 × 844', (tester) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final learning = LearningController(DemoLearningRepository());
    await tester.runAsync(learning.start);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: ChangeNotifierProvider.value(
          value: learning,
          child: LearningScreen(onBack: () {}),
        ),
      ),
    );
    await precacheAll(tester);
    await export(tester, find.byType(LearningScreen), 'learning_list');
    await expectLater(find.byType(LearningScreen), matchesGoldenFile('goldens/learning_list.png'));
  });

  Future<void> pumpList(WidgetTester tester, LearningRepository repo, Size physical) async {
    tester.view.physicalSize = physical;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final learning = LearningController(repo);
    await tester.runAsync(learning.start);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: ChangeNotifierProvider.value(
          value: learning,
          child: LearningScreen(onBack: () {}),
        ),
      ),
    );
    await precacheAll(tester);
  }

  shadowedWidgets('learning grid (a held course, a paid one, programmes) at 390 × 1160', (tester) async {
    await pumpList(tester, _Catalogue(), const Size(780, 2320));
    await export(tester, find.byType(LearningScreen), 'learning_grid');
    await expectLater(find.byType(LearningScreen), matchesGoldenFile('goldens/learning_grid.png'));
  });

  shadowedWidgets('learning grid at 320 × 1500 (export only)', (tester) async {
    await pumpList(tester, _Catalogue(), const Size(640, 3000));
    await export(tester, find.byType(LearningScreen), 'learning_grid_320');
  });

  Future<LearningHubController> pumpHubScreen(
    WidgetTester tester,
    Widget Function(LearningHubController c) screen, {
    required Size physical,
  }) async {
    tester.view.physicalSize = physical;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    // The papers and the decks are the sample content's: the design's grids need six cards and a rail of decks.
    final hub = LearningHubController(
      repository: _HubSource(),
      learning: LearningController(_Catalogue()),
      assess: DemoAssessRepository(),
      study: DemoStudyRepository(),
    );
    addTearDown(hub.dispose);
    await tester.runAsync(hub.start);
    await tester.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, theme: buildAppTheme(), home: screen(hub)));
    await precacheAll(tester);
    return hub;
  }

  /// The hub as the app mounts it on the Learning tab: the reader in the header, the design's foot.
  Widget hubTab(LearningHubController c) =>
      LearningHubScreen(onBack: () {}, viewer: DemoFeedRepository.me, onAccount: () {}, controller: c);

  // The design is a 390 × 2815 frame (docs/designs/hires/learning-centre.png at 4x): the phone-height export is
  // the first fold, the whole-page export the design's full height, for compare.py.
  shadowedWidgets('learning hub (the tab) at 390 × 844', (tester) async {
    await pumpHubScreen(tester, hubTab, physical: const Size(780, 1688));
    await export(tester, find.byType(LearningHubScreen), 'learning_hub');
    await expectLater(find.byType(LearningHubScreen), matchesGoldenFile('goldens/learning_hub.png'));
  });

  shadowedWidgets('learning hub, the whole page, at 390 × 2815', (tester) async {
    await pumpHubScreen(tester, hubTab, physical: const Size(780, 5630));
    await export(tester, find.byType(LearningHubScreen), 'learning_hub_full');
    await expectLater(find.byType(LearningHubScreen), matchesGoldenFile('goldens/learning_hub_full.png'));
  });

  shadowedWidgets('learning hub at 320 × 1500 (export only)', (tester) async {
    await pumpHubScreen(tester, hubTab, physical: const Size(640, 3000));
    await export(tester, find.byType(LearningHubScreen), 'learning_hub_320');
  });

  shadowedWidgets('partner courses (the institute directory) at 390 × 844', (tester) async {
    await pumpHubScreen(
      tester,
      (c) => PartnerCoursesScreen(onBack: () {}, hub: c),
      physical: const Size(780, 1688),
    );
    await export(tester, find.byType(PartnerCoursesScreen), 'partner_courses');
    await expectLater(find.byType(PartnerCoursesScreen), matchesGoldenFile('goldens/partner_courses.png'));
  });

  shadowedWidgets('one partner institute at 390 × 844', (tester) async {
    await pumpHubScreen(
      tester,
      (c) => PartnerScreen(institute: c.institutes.first, onBack: () {}, hub: c),
      physical: const Size(780, 1688),
    );
    await export(tester, find.byType(PartnerScreen), 'partner_institute');
    await expectLater(find.byType(PartnerScreen), matchesGoldenFile('goldens/partner_institute.png'));
  });

  shadowedWidgets('course sheet (demo content) at 390 × 2063.5', (tester) async {
    final repo = DemoLearningRepository();
    await pumpSheet(tester, repo, repo.course, 2063.5);
    await export(tester, find.byType(DetailSheetFrame), 'course_sheet');
    await expectLater(find.byType(DetailSheetFrame), matchesGoldenFile('goldens/course_sheet.png'));
  });

  shadowedWidgets("course sheet (the live API's CALS, Bharat holding the Riyadh place) at 390 × 2400", (tester) async {
    final client = ApiClient(tokens: _NoTokens(), baseUrl: 'http://api.test/api/v1');
    client.dio.httpClientAdapter = _Recorded(enrolled: true);
    final repo = _WithBundledPictures(ApiLearningRepository(api: client));
    final seed = (await tester.runAsync(repo.courses))!.single;
    await pumpSheet(tester, repo, seed, 2400);
    await export(tester, find.byType(DetailSheetFrame), 'course_sheet_live');
    await expectLater(find.byType(DetailSheetFrame), matchesGoldenFile('goldens/course_sheet_live.png'));
  });

  shadowedWidgets("course sheet (the live API's CALS, no place held) at 390 × 2400", (tester) async {
    final client = ApiClient(tokens: _NoTokens(), baseUrl: 'http://api.test/api/v1');
    client.dio.httpClientAdapter = _Recorded(enrolled: false);
    final repo = _WithBundledPictures(ApiLearningRepository(api: client));
    final seed = (await tester.runAsync(repo.courses))!.single;
    await pumpSheet(tester, repo, seed, 2400);
    await export(tester, find.byType(DetailSheetFrame), 'course_sheet_live_open');
  });
}
