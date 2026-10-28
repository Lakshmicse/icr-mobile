/// The Learning tab and the course sheet against the LOCAL portal API, signed in
/// as the seeded personas (tool/seed/learning-jobs.ts seeds the course "CALS":
/// six runs, three reviews, a brochure, and Bharat Buyer's CONFIRMED place on the
/// Riyadh run). Run with the API up: `flutter test test/live/learning_live_test.dart`.
///
/// What a test writes it undoes: a place taken as Pooja is withdrawn again (the
/// API's `DELETE /learning/courses/:id/enroll`; the row stays as CANCELLED and
/// the next run re-uses it). The one thing the API cannot take back is an
/// enquiry: each run leaves three leads at the seeded institute, tagged
/// "live test" in their text (removing the seed deletes them with the institute).
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/learning/api_learning_repository.dart';
import 'package:icr_mobile/features/learning/course_sheet_controller.dart';
import 'package:icr_mobile/features/learning/learning_controller.dart';
import 'package:icr_mobile/features/learning/learning_format.dart';
import 'package:icr_mobile/features/learning/learning_models.dart';
import 'package:icr_mobile/features/learning/learning_repository.dart';
import 'package:icr_mobile/features/learning/learning_screen.dart';
import 'package:icr_mobile/features/learning/widgets/course_card.dart';
import 'package:icr_mobile/features/learning/widgets/run_tile.dart';
import 'package:provider/provider.dart';

import '../helpers/fonts.dart';
import 'live.dart';

const _calsId = 'design-lj-course-cals';
const _riyadhRun = 'design-lj-cals-run-1';
const _londonRun = 'design-lj-cals-run-2';

/// ICR staff, who can read the institute's enquiries back (a member cannot).
const _staff = LivePerson('superadmin@icr.test', 'Test@12345', 'Sana Admin');

/// One sign-in per person for the whole file: the API allows ten logins a minute from one address, and
/// every other live test file shares that allowance.
final _clients = <String, Future<ApiClient>>{};

Future<ApiClient> _as(LivePerson who) => _clients[who.email] ??= liveClient(who);

/// A repository with nothing cached, signed in as [who].
Future<ApiLearningRepository> _repoFor(LivePerson who) async => ApiLearningRepository(api: await _as(who));

Course _cals(Iterable<Course> courses) => courses.firstWhere((c) => c.code == 'CALS');

Future<void> _withdraw(Dio dio) async {
  try {
    await dio.delete<dynamic>('/learning/courses/$_calsId/enroll');
  } on DioException catch (_) {
    // Nothing to withdraw: 404 (never enrolled) or 403 (a paid place), neither is ours to undo here.
  }
}

/// The live source with the pictures it would fetch left out: a widget test cannot reach the network for
/// images, and the grid's counts, texts and taps do not depend on them.
class _WithoutPictures implements LearningRepository {
  _WithoutPictures(this.inner);

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
        : CourseProvider(id: c.provider!.id, name: c.provider!.name, verified: c.provider!.verified),
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
    brochureUrl: c.brochureUrl,
    runs: c.runs,
    modules: c.modules,
    outcomes: c.outcomes,
    prerequisites: c.prerequisites,
    audience: c.audience,
    aboutCertificate: c.aboutCertificate,
    contact: c.contact == null ? null : CourseContact(name: c.contact!.name, role: c.contact!.role),
    enrolment: c.enrolment,
    detailLoaded: c.detailLoaded,
  );

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
  Future<int> unreadNotifications() => inner.unreadNotifications();
  @override
  Uri link(Course course) => inner.link(course);
  @override
  Uri checkoutLink(Course course, CourseRun? run) => inner.checkoutLink(course, run);
}

/// A live test that draws the Learning tab: skipped, with a reason, when the API is not running. Real network
/// calls inside it go through `tester.runAsync`.
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

/// Lets real network calls finish and the tree catch up. Plain pumps: while a sheet shows its spinner the tree
/// never settles.
Future<void> _settle(WidgetTester tester, {required bool Function() until}) async {
  for (var i = 0; i < 20 && !until(); i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

/// The real catalogue on screen: a tall frame (every card is built), the real controller started.
Future<LearningController> _pumpGrid(WidgetTester tester, LivePerson who) async {
  tester.view.physicalSize = const Size(780, 12000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final api = (await tester.runAsync(() => _as(who)))!;
  final learning = LearningController(_WithoutPictures(ApiLearningRepository(api: api)));
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
  await tester.pumpAndSettle();
  return learning;
}

void main() {
  setUpAll(loadAppFonts);

  liveTest('the catalogue lists the seeded course first with its pill, institute and a cover that loads', () async {
    final repo = await _repoFor(bharat);
    final courses = await repo.courses();
    final cals = courses.first;
    expect(cals.code, 'CALS', reason: 'sorted first in its list');
    expect(cals.kind, CourseKind.development);
    expect(cals.certificateEnabled, isTrue);
    expect(cals.badge, 'PREMIUM CERTIFICATION', reason: 'a certificate-issuing course at the Leadership level');
    expect(cals.provider?.name, 'ICR Institute');
    expect(courseMeta(cals), '5 days · 35 hours • In person');
    expect(cals.priceAmount ?? 0, 0, reason: 'free: ADD TO CART takes the place in the app');

    final cover = await Dio().get<List<int>>(cals.cover!.url!, options: Options(responseType: ResponseType.bytes));
    expect(cover.statusCode, 200);
    expect(cover.headers.value('content-type'), startsWith('image/'));

    final programmes = courses.where((c) => c.kind == CourseKind.assessment).toList();
    expect(programmes, isNotEmpty, reason: 'the certification programmes are listed too');
    expect(courseMeta(programmes.first), 'Foundation • Certification programme', reason: 'never a blank third line');

    final learning = LearningController(repo);
    await learning.start();
    expect(learning.sections.map((s) => s.title), ['Professional development', 'Certification programmes']);
    expect(learning.sections.first.courses.first.code, 'CALS');
  });

  liveTest('search: the API ignores a search parameter, so the loaded list is what narrows', () async {
    final api = await _as(bharat);
    final all = await api.dio.get<List<dynamic>>('/learning/courses');
    final searched = await api.dio.get<List<dynamic>>('/learning/courses', queryParameters: {'search': 'zzzznothing'});
    expect(searched.data!.length, all.data!.length, reason: 'GET /learning/courses?search= is not a thing');

    final repo = await _repoFor(bharat);
    final learning = LearningController(repo);
    await learning.start();
    final total = learning.sections.expand((s) => s.courses).length;
    expect(total, all.data!.length);
    learning.setSearch('cals');
    expect(learning.sections.single.courses.single.code, 'CALS');
    learning.setSearch('leadership');
    expect(learning.sections.expand((s) => s.courses).map((c) => c.code), contains('CALS'));
    learning.setSearch('certificate in advanced');
    expect(learning.sections.single.courses.single.code, 'CALS', reason: 'by title');
    learning.setSearch('icr institute');
    expect(learning.sections.expand((s) => s.courses).map((c) => c.code), contains('CALS'), reason: 'by awarding body');
    learning.setSearch('zzzznothing');
    expect(learning.sections, isEmpty);
    learning.clearSearch();
    expect(learning.sections.expand((s) => s.courses), hasLength(total));
  });

  liveTest("Bharat's seeded place reads CONFIRMED on the Riyadh tile, and My courses lists it", () async {
    final repo = await _repoFor(bharat);
    final learning = LearningController(repo);
    await learning.start();
    final cals = _cals(learning.courses);
    expect(
      cals.enrolled,
      isTrue,
      reason: 'the seed holds a place for Bharat (tool/seed/learning-jobs.ts, not --no-enrol)',
    );
    expect(cals.enrolment?.status, EnrolmentStatus.confirmed);
    expect(cals.enrolment?.runId, _riyadhRun);
    expect(cals.enrolment?.location, 'Riyadh, KSA');
    expect(enrolmentMeta(cals.enrolment), startsWith('Aug 23 - 27, '));

    learning.toggleMine();
    await learning.refresh();
    expect(learning.sections.single.title, 'My courses');
    expect(learning.sections.single.courses.map((c) => c.code), contains('CALS'));
    expect(learning.sections.single.courses.every((c) => c.enrolled), isTrue);

    final sheet = CourseSheetController(repository: repo, seed: cals);
    await sheet.load();
    expect(sheet.selectedRun?.id, _riyadhRun, reason: 'the sheet opens on the run the place is on');
    final riyadh = sheet.course.runs.firstWhere((r) => r.id == _riyadhRun);
    final tile = RunTile(run: riyadh, selected: true, onTap: () {}, mine: sheet.course.enrolment?.status);
    expect(tile.status.$1, 'CONFIRMED');
    final london = sheet.course.runs.firstWhere((r) => r.id == _londonRun);
    expect(RunTile(run: london, selected: false, onTap: () {}).status.$1, 'Open');
    expect(sheet.ctaLabel, 'ENROLLED');
    expect(sheet.canAct, isFalse);
  });

  liveTest('the two tabs filter the real runs by mode, and See More Dates unfolds the fourth', () async {
    final repo = await _repoFor(bharat);
    final sheet = CourseSheetController(repository: repo, seed: _cals(await repo.courses()));
    await sheet.load();
    expect(sheet.mode, DeliveryMode.inPerson);
    expect(sheet.runsInMode.every((r) => r.mode == DeliveryMode.inPerson), isTrue);
    expect(sheet.shownRuns.map((r) => r.location), ['Riyadh, KSA', 'London, UK', 'Dubai, UAE']);
    expect(sheet.hasMoreRuns, isTrue);
    expect(sheet.runsInMode.length, greaterThanOrEqualTo(4));
    sheet.toggleAllDates();
    expect(sheet.shownRuns.map((r) => r.location), contains('Singapore, SG'));
    expect(sheet.shownRuns.length, sheet.runsInMode.length);

    final dubai = sheet.course.runs.firstWhere((r) => r.location == 'Dubai, UAE');
    expect(dubai.availability, RunAvailability.limited, reason: 'one public place left');
    expect(sheet.course.runs.firstWhere((r) => r.location == 'London, UK').availability, RunAvailability.open);

    sheet.selectMode(DeliveryMode.virtual);
    expect(sheet.runsInMode.length, greaterThanOrEqualTo(2));
    expect(sheet.runsInMode.every((r) => r.mode == DeliveryMode.virtual), isTrue);
    expect(sheet.runsInMode.map((r) => r.location), everyElement('Live online'));
    expect(sheet.selectedRun?.mode, DeliveryMode.virtual, reason: 'each tab selects its own first run');
    expect(sheet.allDates, isFalse);
    expect(scheduleLabel(sheet.runsInMode), endsWith(' Schedule'));

    sheet.selectRun(sheet.runsInMode.last);
    expect(sheet.selectedRun?.id, sheet.runsInMode.last.id);
    sheet.selectMode(DeliveryMode.inPerson);
    expect(sheet.selectedRun?.mode, DeliveryMode.inPerson);
  });

  liveTest('the reviews are the real list, newest first, with the design\'s as the testimonial', () async {
    final repo = await _repoFor(bharat);
    final sheet = CourseSheetController(repository: repo, seed: _cals(await repo.courses()));
    await sheet.load();
    expect(sheet.reviewTotal, greaterThanOrEqualTo(3));
    expect(sheet.reviews.length, greaterThanOrEqualTo(3));
    final first = sheet.review!;
    expect(first.author, 'Charles Selasie Tuffour');
    expect(first.role, 'Facilities Manager');
    expect(
      first.body,
      startsWith('The staffs are very professional'),
      reason: 'stored bare; the sheet adds the quotes',
    );
    expect(sheet.reviews.map((r) => r.author).toSet().length, sheet.reviews.length, reason: 'one review per person');
    expect(sheet.allReviews, isFalse);
    sheet.toggleAllReviews();
    expect(sheet.allReviews, isTrue);
  });

  liveTest('DOWNLOAD BROCHURE opens a real PDF', () async {
    final repo = await _repoFor(bharat);
    final cals = _cals(await repo.courses());
    expect(cals.brochureUrl, isNotNull);
    final res = await Dio().get<List<int>>(cals.brochureUrl!, options: Options(responseType: ResponseType.bytes));
    expect(res.statusCode, 200);
    expect(res.headers.value('content-type'), contains('pdf'));
    expect(String.fromCharCodes(res.data!.take(5)), '%PDF-');
  });

  liveTest('the bell reads the unread count', () async {
    final repo = await _repoFor(bharat);
    expect(await repo.unreadNotifications(), greaterThanOrEqualTo(0));
  });

  liveTest(
    'ADD TO CART on a free course takes the selected run as Pooja; the place is the API\'s; withdrawing gives it back',
    () async {
      final api = await _as(pooja);
      await _withdraw(api.dio); // a place left by an interrupted run
      final repo = ApiLearningRepository(api: api);
      final learning = LearningController(repo);
      await learning.start();
      final seed = _cals(learning.courses);
      expect(seed.enrolled, isFalse, reason: 'Pooja holds no place on CALS: the seed leaves her free for this test');
      final sheet = CourseSheetController(repository: repo, seed: seed, onChanged: learning.update);
      await sheet.load();
      sheet.selectRun(sheet.course.runs.firstWhere((r) => r.id == _londonRun));
      expect(sheet.ctaLabel, 'ADD TO CART');
      expect(sheet.paidPlace, isFalse, reason: 'CALS is free, so the app takes the place itself');

      try {
        expect(await sheet.enrol(), isNull);
        expect(sheet.course.enrolment?.runId, _londonRun);
        expect(sheet.course.enrolment?.status, anyOf(EnrolmentStatus.pending, EnrolmentStatus.confirmed));
        expect(learning.find(seed.id)!.enrolled, isTrue, reason: 'the list is told');
        expect(sheet.ctaLabel, anyOf('PLACE REQUESTED', 'ENROLLED'));

        // Read it back through a repository with nothing cached: the place is the API's, not the app's.
        final fresh = await _repoFor(pooja);
        final place = (await fresh.myEnrolments()).singleWhere((m) => m.courseId == _calsId);
        expect(place.runId, _londonRun);
        expect(place.location, 'London, UK');
        expect(place.startsAt, isNotNull);

        final again = LearningController(fresh);
        await again.start();
        again.toggleMine();
        await again.refresh();
        expect(again.sections.single.courses.map((c) => c.code), contains('CALS'), reason: 'My courses lists it');

        final reopened = CourseSheetController(repository: fresh, seed: _cals(await fresh.courses()));
        await reopened.load();
        expect(reopened.selectedRun?.id, _londonRun, reason: 'a sheet opened afresh opens on the held run');
        expect(reopened.canAct, isFalse);
        final held = reopened.course.runs.firstWhere((r) => r.id == _londonRun);
        expect(
          RunTile(run: held, selected: true, onTap: () {}, mine: reopened.course.enrolment?.status).status.$1,
          anyOf('REQUESTED', 'CONFIRMED'),
        );
      } finally {
        await _withdraw(api.dio);
      }

      final after = await (await _repoFor(pooja)).myEnrolments();
      expect(after.where((m) => m.courseId == _calsId), isEmpty, reason: 'withdrawn: nothing left behind');
      final reopenedFree = CourseSheetController(
        repository: await _repoFor(pooja),
        seed: _cals(await (await _repoFor(pooja)).courses()),
      );
      await reopenedFree.load();
      expect(reopenedFree.ctaLabel, 'ADD TO CART', reason: 'and the button is the design\'s again');
    },
  );

  liveTest(
    'holding two places on one course is refused by the API (the app never offers a second ADD TO CART)',
    () async {
      final api = await _as(pooja);
      await _withdraw(api.dio);
      final repo = ApiLearningRepository(api: api);
      final course = _cals(await repo.courses());
      final sheet = CourseSheetController(repository: repo, seed: course);
      await sheet.load();
      final riyadh = sheet.course.runs.firstWhere((r) => r.id == _riyadhRun);
      try {
        sheet.selectRun(riyadh);
        expect(await sheet.enrol(), isNull);
        // Asking the API for a place on the run already held says no.
        String? second;
        try {
          await repo.enrol(sheet.course, run: riyadh);
        } catch (e) {
          second = ApiError.from(e).message;
        }
        expect(second, 'You are already enrolled on this course.');
      } finally {
        await _withdraw(api.dio);
      }
    },
  );

  liveTest('Suggest A Date, ask the institute and in-house reach the institute as leads, read back as staff', () async {
    final repo = await _repoFor(pooja);
    final course = _cals(await repo.courses());
    final sheet = CourseSheetController(repository: repo, seed: course);
    await sheet.load();
    expect(sheet.canEnquire, isTrue);

    final tag = 'live test ${DateTime.now().millisecondsSinceEpoch}';
    final sent = <String?>[
      await sheet.enquire('Date and location request: Pune, first week of March ($tag)', kind: EnquiryKind.dateRequest),
      await sheet.enquire(
        'In-house delivery request: two cohorts in Pune ($tag)',
        kind: EnquiryKind.inHouse,
        company: 'Live Test Co',
        headcount: 12,
      ),
      await sheet.enquire('Which cities do you run this in? ($tag)'),
    ];
    final limited = sent.whereType<String>().where((m) => m.toLowerCase().contains('too many'));
    if (limited.isNotEmpty) {
      markTestSkipped('the API rate-limits enquiries (5 a minute): run again in a minute');
      return;
    }
    expect(sent, [null, null, null], reason: 'each POST /learning/courses/CALS/enquire was accepted');

    final staff = await _as(_staff);
    final res = await staff.dio.get<Map<String, dynamic>>(
      '/learning/admin/leads',
      queryParameters: {'courseId': course.id, 'limit': 50},
    );
    final mine = (res.data!['data'] as List).cast<Map<String, dynamic>>().where((l) => '${l['message']}'.contains(tag));
    expect(mine, hasLength(3), reason: 'no de-duplication: three enquiries, three leads');
    Map<String, dynamic> lead(String starts) => mine.firstWhere((l) => '${l['message']}'.startsWith(starts));

    final date = lead('Date and location request: ');
    expect(date['kind'], 'INDIVIDUAL');
    expect(date['source'], 'course');
    expect(date['name'], 'Pooja Professional');
    expect(date['email'], 'professional@icr.test');
    expect(date['userId'], isNotNull, reason: 'signed in: the lead knows who asked');

    final inHouse = lead('In-house delivery request: ');
    expect(inHouse['kind'], 'CORPORATE');
    expect(inHouse['company'], 'Live Test Co');
    expect(inHouse['headcount'], 12);

    expect(lead('Which cities')['kind'], 'INDIVIDUAL');
  });

  liveTest(
    "ICR's own certification programmes have no institute: the API refuses an enquiry, so the app uses the contact page",
    () async {
      final repo = await _repoFor(pooja);
      final programme = (await repo.courses()).firstWhere((c) => c.kind == CourseKind.assessment && c.provider == null);
      final sheet = CourseSheetController(repository: repo, seed: programme);
      expect(sheet.canEnquire, isFalse, reason: 'so Suggest, ask and in-house open /contact instead of the form');
      final refused = await sheet.enquire('Is this running in Pune this year?');
      if (refused != null && refused.toLowerCase().contains('too many')) {
        markTestSkipped('the API rate-limits enquiries (5 a minute): run again in a minute');
        return;
      }
      expect(refused, contains('run by ICR'));
    },
  );

  liveWidgetTest('the grid has one card per course in each section of the real catalogue, two to a row', (
    tester,
  ) async {
    final api = (await tester.runAsync(() => _as(bharat)))!;
    final raw = (await tester.runAsync(() => api.dio.get<List<dynamic>>('/learning/courses')))!.data!;
    final development = raw.where((c) => (c as Map)['kind'] == 'DEVELOPMENT').length;
    final programmes = raw.where((c) => (c as Map)['kind'] == 'ASSESSMENT').length;
    expect(development, greaterThanOrEqualTo(1));
    expect(programmes, greaterThanOrEqualTo(1));

    final learning = await _pumpGrid(tester, bharat);
    expect(learning.sections.map((s) => s.title), ['Professional development', 'Certification programmes']);
    expect(learning.sections[0].courses, hasLength(development));
    expect(learning.sections[1].courses, hasLength(programmes));
    expect(find.byType(CourseCard), findsNWidgets(raw.length), reason: 'every published course is a card');

    // Each card sits under its own heading.
    final programmesTop = tester.getRect(find.text('Certification programmes')).top;
    final cards = tester.widgetList<CourseCard>(find.byType(CourseCard)).toList();
    var above = 0;
    var below = 0;
    for (final c in cards) {
      final top = tester.getRect(find.byWidget(c)).top;
      top < programmesTop ? above++ : below++;
    }
    expect(above, development);
    expect(below, programmes);

    // Two columns on the Events frame: 9 dp in, 3 dp between, 9.5 dp out.
    final lefts = {for (final c in cards) tester.getRect(find.byWidget(c)).left.toStringAsFixed(2)};
    final cardWidth = (390 - 9 - 9.5 - 3) / 2;
    expect(lefts, {'9.00', (9 + cardWidth + 3).toStringAsFixed(2)});

    // The first card is the seeded course, with its pill, awarding body, meta, price and Bharat's place.
    final first = find.byWidget(cards.first);
    expect(cards.first.course.code, 'CALS');
    expect(find.descendant(of: first, matching: find.text('PREMIUM CERTIFICATION')), findsOneWidget);
    expect(find.descendant(of: first, matching: find.text('ICR Institute')), findsOneWidget);
    expect(find.descendant(of: first, matching: find.text('5 days · 35 hours • In person')), findsOneWidget);
    expect(find.descendant(of: first, matching: find.text('Free')), findsOneWidget);
    expect(find.descendant(of: first, matching: find.text('Enrolled')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  liveWidgetTest('a card opens the real course sheet', (tester) async {
    await _pumpGrid(tester, bharat);
    await _tapOnline(tester, find.text('Certificate in Advanced Leadership Skills'));
    await _settle(tester, until: () => find.text('Select Date').evaluate().isNotEmpty);
    expect(find.text('Select Date'), findsOneWidget);
    expect(find.text('Riyadh, KSA'), findsOneWidget);
    expect(find.text('CONFIRMED'), findsOneWidget, reason: "Bharat's seeded place");
    expect(
      find.text('Certificate in Advanced Leadership Skills'),
      findsNWidgets(2),
      reason: 'the card behind, the sheet',
    );
    expect(tester.takeException(), isNull);
  });

  liveWidgetTest('the search narrows the grid; the clear button gives it back', (tester) async {
    final learning = await _pumpGrid(tester, bharat);
    final all = find.byType(CourseCard).evaluate().length;
    expect(all, greaterThan(1));
    await tester.enterText(find.byType(TextField), 'cals');
    await tester.pump();
    expect(find.byType(CourseCard), findsOneWidget);
    expect(find.text('Certification programmes'), findsNothing, reason: 'a heading with no card under it goes');
    await tester.enterText(find.byType(TextField), 'zzzznothing');
    await tester.pump();
    expect(find.byType(CourseCard), findsNothing);
    expect(find.text('No courses match'), findsOneWidget);
    await tester.tap(find.text('Clear search'));
    await tester.pumpAndSettle();
    expect(find.byType(CourseCard), findsNWidgets(all));
    expect(learning.search, '');
  });

  liveWidgetTest("My courses shows the member's places as cards, with the run each is on", (tester) async {
    await _pumpGrid(tester, bharat);
    await _tapOnline(tester, find.text('My courses'));
    await _settle(tester, until: () => find.byType(CourseCard).evaluate().length == 1);
    expect(find.byType(CourseCard), findsOneWidget);
    expect(find.text('Certificate in Advanced Leadership Skills'), findsOneWidget);
    expect(find.textContaining('Riyadh, KSA'), findsOneWidget, reason: 'the run the place is on');
    expect(find.text('Enrolled'), findsOneWidget);
    expect(find.text('Certification programmes'), findsNothing);
    final card = tester.getRect(find.byType(CourseCard));
    expect(card.left, closeTo(9, 0.01));
    expect(card.width, closeTo((390 - 9 - 9.5 - 3) / 2, 0.01), reason: 'one place: a half-width card at the left');
    await tester.tap(find.text('My courses').first); // off: no request, the catalogue is already loaded
    await tester.pumpAndSettle();
    expect(find.byType(CourseCard).evaluate().length, greaterThan(1), reason: 'pressed again: the catalogue is back');
  });
}
