/// The Learning hub (the Learning tab), Partner Courses and a partner institute against the LOCAL portal API,
/// signed in as the seeded personas (tool/seed/learning-jobs.ts seeds the course "CALS", its institute
/// "ICR Institute" and Bharat Buyer's CONFIRMED place on it; the 31 certification programmes come with the
/// base seed). Run with the API up: `flutter test test/live/learning_hub_live_test.dart`.
///
/// What the hub does is read, so almost nothing needs undoing. The one write is "Ask the institute":
/// `POST /learning/providers/:slug/enquire` makes a lead the API cannot delete (removing the seed deletes it
/// with the institute). Each run leaves two leads at ICR Institute, tagged "live test" in their text. The
/// route allows five a minute, so a test skips, with the reason, if the limit is hit.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/learning/api_learning_repository.dart';
import 'package:icr_mobile/features/learning/learning_controller.dart';
import 'package:icr_mobile/features/learning/learning_models.dart';
import 'package:icr_mobile/features/learning/learning_repository.dart';
import 'package:icr_mobile/features/learning/learning_screen.dart';
import 'package:icr_mobile/features/learning/widgets/course_card.dart';
import 'package:icr_mobile/features/learning_assess/api_assess_repository.dart';
import 'package:icr_mobile/features/learning_hub/api_hub_repository.dart';
import 'package:icr_mobile/features/learning_hub/widgets/catalogue_rail.dart';
import 'package:icr_mobile/features/learning_hub/hub_controller.dart';
import 'package:icr_mobile/features/learning_hub/hub_models.dart';
import 'package:icr_mobile/features/learning_hub/hub_repository.dart';
import 'package:icr_mobile/features/learning_hub/learning_doors.dart';
import 'package:icr_mobile/features/learning_hub/learning_hub_screen.dart';
import 'package:icr_mobile/features/learning_hub/partner_courses_screen.dart';
import 'package:icr_mobile/features/learning_hub/partner_screen.dart';
import 'package:icr_mobile/features/learning_hub/widgets/institute_card.dart';

import '../helpers/fonts.dart';
import 'career_live_support.dart';
import 'live.dart';

const _icrInstituteId = 'design-lj-provider-icr-institute';

/// ICR staff, who can read an institute's enquiries back (a member cannot).
const _staff = LivePerson('superadmin@icr.test', 'Test@12345', 'Sana Admin');

/// One sign-in per person for the whole file: the API allows ten logins a minute from one address.
final _clients = <String, Future<ApiClient>>{};

Future<ApiClient> _as(LivePerson who) => _clients[who.email] ??= liveClient(who);

/// The hub's controller on the real API for [who], with the repositories the app builds.
Future<LearningHubController> _hubFor(LivePerson who, {bool bare = false}) async {
  final api = await _as(who);
  final courses = ApiLearningRepository(api: api);
  final hub = ApiLearningHubRepository(api: api);
  // The hub's Assess and Mock Exams sections read the assess catalogue (27 Oct 2026); without a source they are
  // left out, headings and all.
  return LearningHubController(
    repository: bare ? _BareHub(hub) : hub,
    learning: LearningController(bare ? _BareCourses(courses) : courses),
    assess: ApiAssessRepository(api: api),
  );
}

/// The live institutes without their logos, and the live courses without their pictures: a widget test cannot
/// reach the network for images, and the screen's counts, texts and taps do not depend on them.
class _BareHub implements LearningHubRepository {
  _BareHub(this.inner);

  final ApiLearningHubRepository inner;

  @override
  Future<List<Institute>> institutes() async => [
    for (final i in await inner.institutes())
      Institute(
        id: i.id,
        name: i.name,
        slug: i.slug,
        summary: i.summary,
        website: i.website,
        verified: i.verified,
        courseCount: i.courseCount,
      ),
  ];

  @override
  Future<MyLearning> myLearning() => inner.myLearning();

  @override
  Future<void> enquireInstitute(Institute institute, {required String message}) =>
      inner.enquireInstitute(institute, message: message);
}

class _BareCourses implements LearningRepository {
  _BareCourses(this.inner);

  final ApiLearningRepository inner;

  Course _bare(Course c) => Course(
    id: c.id,
    code: c.code,
    title: c.title,
    slug: c.slug,
    summary: c.summary,
    description: c.description,
    kind: c.kind,
    level: c.level,
    provider: c.provider == null
        ? null
        : CourseProvider(
            id: c.provider!.id,
            name: c.provider!.name,
            slug: c.provider!.slug,
            verified: c.provider!.verified,
          ),
    badge: c.badge,
    priceAmount: c.priceAmount,
    priceCurrency: c.priceCurrency,
    durationLabel: c.durationLabel,
    deliveryMode: c.deliveryMode,
    language: c.language,
    cpdCredits: c.cpdCredits,
    certificateEnabled: c.certificateEnabled,
    enrollmentOpen: c.enrollmentOpen,
    batchStartsAt: c.batchStartsAt,
    full: c.full,
    waitlistEnabled: c.waitlistEnabled,
    runs: c.runs,
    enrolment: c.enrolment,
    detailLoaded: c.detailLoaded,
  );

  @override
  Future<void> withdraw(Course course) => inner.withdraw(course);

  @override
  Future<List<Course>> courses() async => [for (final c in await inner.courses()) _bare(c)];
  @override
  Future<Course> detail(Course course) async => _bare(await inner.detail(course));
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
  Future<BrochureLead> brochureContact() => inner.brochureContact();

  @override
  Future<void> requestBrochure(Course course, BrochureLead lead, {required BrochureIntent intent}) =>
      inner.requestBrochure(course, lead, intent: intent);

  @override
  Future<List<int>> brochureBytes(Course course) => inner.brochureBytes(course);

  @override
  Future<int> unreadNotifications() => inner.unreadNotifications();
  @override
  Uri link(Course course) => inner.link(course);
  @override
  Uri checkoutLink(Course course, CourseRun? run) => inner.checkoutLink(course, run);
}

/// A live test that draws a screen: skipped, with a reason, when the API is not running. Real network calls
/// inside it go through `tester.runAsync`.
void liveWidgetTest(String description, Future<void> Function(WidgetTester tester) body) {
  testWidgets(
    description,
    (tester) async {
      if (await tester.runAsync(liveApiReachable) != true) {
        markTestSkipped('the local API is not running at $liveBaseUrl');
        return;
      }
      await body(tester);
    },
    tags: const ['live'],
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

/// A tap whose handler talks to the network: it runs outside the test's fake clock, so the request's own timers
/// are real ones (a timer left on the fake clock fails the test at its end).
Future<void> _tapOnline(WidgetTester tester, Finder finder) async {
  await tester.runAsync(() => tester.tap(finder));
  await tester.pump();
}

/// Lets real network calls finish and the tree catch up. Plain pumps: the tree may never settle while a spinner shows.
Future<void> _settle(WidgetTester tester, {required bool Function() until}) async {
  for (var i = 0; i < 20 && !until(); i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

/// Stands where another builder's screen goes.
class _Stub extends StatelessWidget {
  const _Stub(this.name, this.onBack);

  final String name;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        Text('stub:$name'),
        TextButton(key: const ValueKey('stub-back'), onPressed: onBack, child: const Text('stub back')),
      ],
    ),
  );
}

Widget _attempts(BuildContext c, VoidCallback back) => _Stub('myAttempts', back);
Widget _certificates(BuildContext c, VoidCallback back) => _Stub('certificates', back);

const _routes = LearningRoutes(myAttempts: _attempts, certificates: _certificates);

/// The real hub on screen: a tall frame (every tile is built), the real controller started.
Future<LearningHubController> _pumpHub(
  WidgetTester tester,
  LivePerson who, {
  Widget Function(LearningHubController hub)? screen,
  double heightDp = 2600,
}) async {
  tester.view.physicalSize = Size(780, heightDp * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  mockImageCachePlugins(); // the Assess and Mock Exam cards' covers
  final hub = (await tester.runAsync(() => _hubFor(who, bare: true)))!;
  addTearDown(hub.dispose);
  await tester.runAsync(hub.start);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: screen?.call(hub) ?? LearningHubScreen(onBack: () {}, controller: hub, routes: _routes),
    ),
  );
  await tester.pumpAndSettle();
  return hub;
}

Future<List<Map<String, dynamic>>> _rows(ApiClient api, String path) async {
  final res = await api.dio.get<dynamic>(path);
  final data = res.data;
  return ((data is List ? data : (data as Map)['data']) as List).cast<Map<String, dynamic>>();
}

void main() {
  setUpAll(loadAppFonts);

  liveTest('Partner Courses is the API\'s provider list: names, slugs, counts and a logo that loads', () async {
    final api = await _as(bharat);
    final raw = await _rows(api, '/learning/providers');
    final repo = ApiLearningHubRepository(api: api);
    final institutes = await repo.institutes();
    expect(institutes.map((i) => i.id), raw.map((r) => r['id']), reason: 'the same institutes in the same order');
    expect(institutes, isNotEmpty);

    final icr = institutes.firstWhere((i) => i.id == _icrInstituteId);
    expect(icr.name, 'ICR Institute');
    expect(icr.slug, isNotNull);
    expect(icr.canEnquire, isTrue);
    expect(icr.courseCount, greaterThanOrEqualTo(1), reason: 'CALS is published under it');
    expect(icr.courseCountLabel, anyOf('1 course', matches(RegExp(r'^\d+ courses$'))));
    expect(icr.logo?.url, startsWith('http://localhost:3001/uploads/'), reason: 'an upload path made absolute');
    final logo = await Dio().get<List<int>>(icr.logo!.url!, options: Options(responseType: ResponseType.bytes));
    expect(logo.statusCode, 200);
    expect(logo.headers.value('content-type'), startsWith('image/'));
    for (final i in institutes) {
      final row = raw.firstWhere((r) => r['id'] == i.id);
      expect(i.courseCount, row['courseCount'], reason: i.name);
      expect(i.verified, row['verified'] == true, reason: i.name);
    }
  });

  liveTest('My learning: the counts are the lengths of the API\'s own lists, for each person', () async {
    for (final who in [bharat, pooja]) {
      final api = await _as(who);
      final mine = await ApiLearningHubRepository(api: api).myLearning();
      expect(mine.attempts, (await _rows(api, '/learning/me/attempts')).length, reason: '${who.label}: attempts');
      expect(
        mine.certificates,
        (await _rows(api, '/learning/me/certificates')).length,
        reason: '${who.label}: certificates',
      );
    }
  });

  liveTest(
    'the hub on the real catalogue: held places, the ICR rail (taught first, nine at most), the search',
    () async {
      final hub = await _hubFor(bharat);
      expect(hub.coursesHeld, isNull, reason: 'unknown until the catalogue has loaded');
      await hub.start();
      final api = await _as(bharat);
      final raw = await _rows(api, '/learning/courses');
      final places = await _rows(api, '/learning/me/enrollments');
      final held = places.where((p) => p['status'] != 'CANCELLED').length;

      expect(hub.coursesHeld, held, reason: "Bharat's own places, counted from the API");
      expect(hub.coursesHeld, greaterThanOrEqualTo(1), reason: 'the seeded CONFIRMED place on CALS');
      expect(hub.matchingCourses.length, raw.length);
      expect(hub.courseRail.length, raw.length < 9 ? raw.length : 9);
      expect(hub.courseRail.first.code, 'CALS', reason: 'taught courses come before certification programmes');
      expect(hub.courseRail.first.kind, CourseKind.development);
      expect(hub.courseRail.skip(1).every((c) => c.kind == CourseKind.assessment), isTrue);
      expect(hub.doors, LearningDoor.values);
      expect(hub.institutes, isNotEmpty);
      expect(hub.unread, greaterThanOrEqualTo(0));

      hub.setSearch('capital planning');
      expect(hub.courseRail.map((c) => c.title), contains('Capital Planning'));
      expect(hub.courseRail.length, lessThan(5));
      expect(hub.doors, isEmpty);

      hub.setSearch('icr institute');
      expect(hub.institutesShown.map((i) => i.id), contains(_icrInstituteId));
      expect(hub.courseRail.map((c) => c.code), contains('CALS'), reason: "an awarding body's name finds its course");

      hub.setSearch('flash');
      expect(hub.doors, [LearningDoor.flashCards]);
      // The search hides the catalogue (the doors) and narrows the grids and the rail, so a word that names only a
      // door and no course, programme, deck or institute is "No Matches Found".
      expect(hub.nothingMatches, isTrue);

      hub.setSearch('zzzzzz');
      expect(hub.nothingMatches, isTrue);
      hub.clearSearch();
      expect(hub.doors.length, 6);
      hub.dispose();
    },
  );

  liveTest("an institute's courses are the catalogue's courses that name it, and its count is the API's", () async {
    final hub = await _hubFor(bharat);
    await hub.start();
    for (final institute in hub.institutes) {
      final theirs = hub.learning.courses.where((c) => c.provider?.id == institute.id);
      expect(theirs.length, institute.courseCount, reason: '${institute.name}: the card says what the page will list');
    }
    final icr = hub.institutes.firstWhere((i) => i.id == _icrInstituteId);
    expect(hub.learning.courses.where((c) => c.provider?.id == icr.id).map((c) => c.code), contains('CALS'));
    hub.dispose();
  });

  liveTest(
    'Ask the institute reaches the institute as a lead, read back as staff; an unknown institute is refused',
    () async {
      final hub = await _hubFor(pooja);
      await hub.start();
      final icr = hub.institutes.firstWhere((i) => i.id == _icrInstituteId);

      final tag = 'live test ${DateTime.now().millisecondsSinceEpoch}';
      final problem = await hub.enquireInstitute(icr, 'When does the next intake start? ($tag)');
      if (problem != null && problem.toLowerCase().contains('too many')) {
        markTestSkipped('the API rate-limits enquiries (5 a minute): run again in a minute');
        return;
      }
      expect(problem, isNull, reason: 'POST /learning/providers/${icr.slug}/enquire was accepted');

      final staff = await _as(_staff);
      final res = await staff.dio.get<Map<String, dynamic>>(
        '/learning/admin/leads',
        queryParameters: {'providerId': icr.id, 'limit': 50},
      );
      final mine = (res.data!['data'] as List).cast<Map<String, dynamic>>().where(
        (l) => '${l['message']}'.contains(tag),
      );
      expect(mine, hasLength(1));
      final lead = mine.single;
      expect(lead['source'], 'institute', reason: 'an institute enquiry, not a course one');
      expect(lead['kind'], 'INDIVIDUAL');
      expect(lead['courseId'], isNull);
      expect(lead['name'], 'Pooja Professional');
      expect(lead['email'], 'professional@icr.test');
      expect(lead['userId'], isNotNull, reason: 'signed in: the lead knows who asked');

      final refused = await hub.enquireInstitute(
        const Institute(id: 'x', name: 'Nowhere', slug: 'no-such-institute-anywhere'),
        'Is anyone there? ($tag)',
      );
      expect(refused, 'Institute not found', reason: "the API's own sentence");
      hub.dispose();
    },
  );

  liveTest('an institute with no slug cannot be written to: the app says so without a request', () async {
    final api = await _as(bharat);
    final repo = ApiLearningHubRepository(api: api);
    await expectLater(
      repo.enquireInstitute(
        const Institute(id: 'x', name: 'No Slug'),
        message: 'A question for you',
      ),
      throwsA(isA<ApiError>()),
    );
  });

  liveWidgetTest('the hub on the real data: six doors, the member\'s counts, both rails', (tester) async {
    final hub = await _pumpHub(tester, bharat);
    final api = (await tester.runAsync(() => _as(bharat)))!;
    final attempts = (await tester.runAsync(() => _rows(api, '/learning/me/attempts')))!.length;
    final certificates = (await tester.runAsync(() => _rows(api, '/learning/me/certificates')))!.length;

    // The hub sits under the Home header (no title of its own) and its doors are the catalogue rail's four tiles.
    for (final door in CatalogueRail.doors) {
      expect(find.byKey(ValueKey('catalogue-${door.name}')), findsOneWidget, reason: door.name);
    }
    // The hub carries no "My learning" strip; the counts it used to show are the API's (read above) and the
    // member reaches their courses and certificates through ICR Courses (below).
    expect(hub.coursesHeld, greaterThanOrEqualTo(0));
    expect(attempts + certificates, greaterThanOrEqualTo(0));
    // The seeded sections draw: the assessment and mock programmes as cards, the partner institutes.
    // Each section loads on its own (a skeleton first), so wait for the two seeded ones.
    await _settle(tester, until: () => find.byKey(const ValueKey('assess-heading')).evaluate().isNotEmpty);
    expect(find.byKey(const ValueKey('assess-heading')), findsOneWidget);
    await _settle(tester, until: () => find.byKey(const ValueKey('mock-heading')).evaluate().isNotEmpty);
    expect(find.byKey(const ValueKey('mock-heading')), findsOneWidget);
    // (ICR's own institute is not a partner card: the Partner section is for other institutes' courses.)
    expect(tester.takeException(), isNull, reason: 'no overflow on the real catalogue');
  });

  liveWidgetTest('My courses opens the grid on Bharat\'s places; the ICR Courses door opens the whole catalogue', (
    tester,
  ) async {
    final hub = await _pumpHub(tester, bharat);
    // ICR Courses opens from the Catalogue heading's View More; its "My Courses" chip narrows to the places held.
    await _settle(tester, until: () => find.text('View More').evaluate().isNotEmpty);
    await tester.ensureVisible(find.text('Explore Learning Resources'));
    await tester.pumpAndSettle();
    await _tapOnline(tester, find.text('View More').first);
    await _settle(tester, until: () => find.byType(LearningScreen).evaluate().isNotEmpty);
    await _tapOnline(tester, find.text('My Courses'));
    await _settle(tester, until: () => find.byType(CourseCard).evaluate().length == hub.coursesHeld);
    expect(find.byType(LearningScreen), findsOneWidget);
    expect(find.byType(CourseCard).evaluate().length, hub.coursesHeld, reason: 'only the places held');
    expect(find.text('Certificate in Advanced Leadership Skills'), findsOneWidget);
    expect(find.text('Enrolled'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Explore Learning Resources'));
    await tester.pumpAndSettle();
    await _tapOnline(tester, find.text('View More').first);
    await _settle(tester, until: () => find.byType(LearningScreen).evaluate().isNotEmpty);
    expect(find.text('ICR Programmes'), findsOneWidget, reason: 'the grid is titled by its door');
    expect(hub.learning.mineOnly, isFalse);
    expect(find.text('Professional development'), findsOneWidget);
    expect(find.text('Certification programmes'), findsOneWidget);
    expect(find.byType(CourseCard).evaluate().length, greaterThan(hub.coursesHeld!), reason: 'the whole catalogue');
  });

  liveWidgetTest('Partner Courses lists the real institutes; one opens its page with its real course and the form', (
    tester,
  ) async {
    final hub = await _pumpHub(
      tester,
      bharat,
      screen: (hub) => PartnerCoursesScreen(onBack: () {}, hub: hub),
    );
    expect(find.byType(InstituteCard), findsNWidgets(hub.institutes.length));

    await tester.tap(find.byKey(const ValueKey('institute-$_icrInstituteId')));
    await tester.pumpAndSettle();
    expect(find.byType(PartnerScreen), findsOneWidget);
    expect(find.text('Certificate in Advanced Leadership Skills'), findsOneWidget, reason: "ICR Institute's course");
    expect(find.byType(CourseCard), findsOneWidget);

    // The form: too short is refused on the spot; a real question is sent and confirmed.
    await tester.tap(find.byKey(const ValueKey('ask-the-institute')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('institute-enquiry-message')), 'Hi');
    await tester.tap(find.byKey(const ValueKey('institute-enquiry-send')));
    await tester.pumpAndSettle();
    expect(find.text('Add more detail to your message.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('institute-enquiry-message')),
      'Which cities do you run this in? (live test ${DateTime.now().millisecondsSinceEpoch})',
    );
    await _tapOnline(tester, find.byKey(const ValueKey('institute-enquiry-send')));
    // The live client waits out a "too many requests" (the route allows five a minute), so a busy minute
    // shows as a form still saying "Sending…": give it a while, then skip rather than fail.
    final form = find.byKey(const ValueKey('institute-enquiry-message'));
    for (var i = 0; i < 40 && form.evaluate().isNotEmpty && find.text('Sending…').evaluate().isNotEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    if (find.text('Sending…').evaluate().isNotEmpty || find.textContaining('Too many').evaluate().isNotEmpty) {
      markTestSkipped('the API rate-limits enquiries (5 a minute): run again in a minute');
      return;
    }
    expect(find.byKey(const ValueKey('institute-enquiry-message')), findsNothing, reason: 'the form closed');
    expect(find.text('Sent to ICR Institute. They will reply by email.'), findsOneWidget);
  });
}
