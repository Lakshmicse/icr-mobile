import 'dart:async';
import 'dart:convert';

import 'package:icr_mobile/core/util/app_actions.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/auth/token_store.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/core/widgets/title_bar.dart';
import 'package:icr_mobile/features/feed/widgets/home_header.dart';
import 'package:icr_mobile/features/learning/course_sheet.dart';
import 'package:icr_mobile/features/learning/demo_learning_repository.dart';
import 'package:icr_mobile/features/learning/learning_controller.dart';
import 'package:icr_mobile/features/learning/learning_models.dart';
import 'package:icr_mobile/features/learning/learning_repository.dart';
import 'package:icr_mobile/features/learning/learning_screen.dart';
import 'package:icr_mobile/features/learning/widgets/course_card.dart';
import 'package:icr_mobile/features/learning_assess/assess_models.dart';
import 'package:icr_mobile/features/learning_assess/assess_repository.dart';
import 'package:icr_mobile/features/learning_assess/demo_assess_repository.dart';
import 'package:icr_mobile/features/learning_assess/group_screen.dart';
import 'package:icr_mobile/features/learning_hub/api_hub_repository.dart';
import 'package:icr_mobile/features/learning_hub/demo_hub_repository.dart';
import 'package:icr_mobile/features/learning_hub/hub_controller.dart';
import 'package:icr_mobile/features/learning_hub/hub_models.dart';
import 'package:icr_mobile/features/learning_hub/hub_repository.dart';
import 'package:icr_mobile/features/learning_hub/my_courses_screen.dart';
import 'package:icr_mobile/features/learning_hub/catalogue_screen.dart';
import 'package:icr_mobile/features/payments/checkout_start.dart';
import 'package:icr_mobile/features/learning_hub/learning_doors.dart';
import 'package:icr_mobile/features/learning_hub/learning_hub_screen.dart';
import 'package:icr_mobile/features/learning_hub/partner_courses_screen.dart';
import 'package:icr_mobile/features/learning_hub/partner_screen.dart';
import 'package:icr_mobile/features/learning_hub/widgets/catalogue_rail.dart';
import 'package:icr_mobile/features/learning_hub/widgets/hub_section.dart';
import 'package:icr_mobile/features/learning_hub/widgets/institute_card.dart';
import 'package:icr_mobile/features/learning_hub/widgets/learn_card.dart';
import 'package:icr_mobile/features/learning_hub/widgets/masterclass_banner.dart';
import 'package:icr_mobile/features/site/partner_apply_screen.dart' show ApiPartnerApplyRepository;
import 'package:icr_mobile/features/learning_study/deck_study_screen.dart';
import 'package:icr_mobile/features/learning_study/demo_study_repository.dart';
import 'package:icr_mobile/features/learning_study/study_models.dart';
import 'package:icr_mobile/features/learning_study/study_repository.dart';
import 'package:icr_mobile/features/notifications/demo_notifications_repository.dart';
import 'package:icr_mobile/features/notifications/notifications_repository.dart';
import 'package:icr_mobile/features/notifications/notifications_screen.dart';
import 'package:icr_mobile/features/shell/app_shell.dart';
import 'package:icr_mobile/features/shell/icr_bottom_nav.dart';
import 'package:provider/provider.dart';

import 'helpers/fonts.dart';
import 'helpers/layout_audit.dart';

// --- fakes ----------------------------------------------------------------------------------------------

/// The course repository the hub's controller runs on: what it holds, and what it was asked.
class _Courses implements LearningRepository {
  _Courses(this.catalogue, {this.listError});

  final List<Course> catalogue;
  String? listError;

  int courseCalls = 0;

  @override
  Future<void> withdraw(Course course) async {}

  @override
  Future<List<Course>> courses() async {
    courseCalls++;
    if (listError != null) throw ApiError(listError!, statusCode: 500);
    return catalogue;
  }

  @override
  Future<Course> detail(Course course) async => catalogue.firstWhere((c) => c.id == course.id);

  @override
  Future<List<MyEnrolment>> myEnrolments() async => [
    for (final c in catalogue)
      if (c.enrolment != null) c.enrolment!,
  ];

  @override
  Future<CourseReviews> reviews(Course course) async => const CourseReviews();

  @override
  Future<MyEnrolment> enrol(Course course, {CourseRun? run}) async =>
      MyEnrolment(id: 'e-${course.code}', courseId: course.id, runId: run?.id, status: EnrolmentStatus.confirmed);

  @override
  Future<void> enquire(
    Course course, {
    required String message,
    EnquiryKind kind = EnquiryKind.question,
    String? company,
    int? headcount,
  }) async {}

  @override
  Future<BrochureLead> brochureContact() async => const BrochureLead();

  @override
  Future<void> requestBrochure(Course course, BrochureLead lead, {required BrochureIntent intent}) async {}

  @override
  Future<List<int>> brochureBytes(Course course) async => throw UnsupportedError('no brochure bytes');

  @override
  Future<int> unreadNotifications() async => 2;

  @override
  Uri link(Course course) => Uri.parse('https://icr.org.in/learning/professional-development/${course.code}');

  @override
  Uri checkoutLink(Course course, CourseRun? run) => link(course);
}

/// The hub's own repository: institutes, the counts and the enquiry.
class _Hub implements LearningHubRepository {
  _Hub({
    this.list = const [],
    this.mine = const MyLearning(attempts: 4, certificates: 2),
    this.institutesError,
    this.enquireError,
  });

  List<Institute> list;
  MyLearning mine;
  String? institutesError;
  String? enquireError;

  int instituteCalls = 0;
  int mineCalls = 0;
  final enquiries = <({String slug, String message})>[];

  @override
  Future<List<Institute>> institutes() async {
    instituteCalls++;
    if (institutesError != null) throw ApiError(institutesError!, statusCode: 500);
    return list;
  }

  @override
  Future<MyLearning> myLearning() async {
    mineCalls++;
    return mine;
  }

  @override
  Future<void> enquireInstitute(Institute institute, {required String message}) async {
    if (enquireError != null) throw ApiError(enquireError!, statusCode: 429);
    enquiries.add((slug: institute.slug ?? '', message: message));
  }
}

class _NoTokens extends TokenStore {
  @override
  Future<String?> accessToken() async => 'token';
  @override
  Future<String?> refreshToken() async => null;
}

/// Answers each route from a table and records the calls.
class _Api implements HttpClientAdapter {
  _Api(this.routes);

  final Map<String, Object Function(RequestOptions options)> routes;
  final List<String> calls = [];
  final List<Object?> bodies = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final key = '${options.method} ${options.path}';
    calls.add(key);
    bodies.add(options.data);
    final handler = routes[key];
    if (handler == null) return ResponseBody.fromString('{"message":"Not found"}', 404, headers: _json);
    final result = handler(options);
    if (result is (int, String)) return ResponseBody.fromString(result.$2, result.$1, headers: _json);
    return ResponseBody.fromString(jsonEncode(result), 200, headers: _json);
  }

  static final _json = {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  };

  @override
  void close({bool force = false}) {}
}

ApiClient _client(_Api api) {
  final client = ApiClient(tokens: _NoTokens(), baseUrl: 'http://api.test/api/v1');
  client.dio.httpClientAdapter = api;
  return client;
}

/// Records what the app hands to the browser.
class _Launches {
  final urls = <String>[];

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      (call) async {
        if (call.method == 'launch') urls.add((call.arguments as Map)['url'] as String);
        return true;
      },
    );
  }

  void remove() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/url_launcher'),
    null,
  );
}

/// The papers the hub's grids read: programmes and subjects under the test's control. Whatever the group page
/// asks beyond the group itself and the member's standing waits for ever (the hub never needs it).
class _Assess implements AssessRepository {
  @override
  Future<CheckoutStart> checkout(AssessPaper paper) async => const CheckoutStart(devActivated: true);

  @override
  Future<CheckoutStart> checkoutBundle(PaperKind kind, String key) async => const CheckoutStart(devActivated: true);

  _Assess({List<PaperGroup>? assessments, List<PaperGroup>? mocks, this.assessError, this.access})
    : assessments = assessments ?? _programmes(3),
      mocks = mocks ?? _subjects();

  List<PaperGroup> assessments;
  List<PaperGroup> mocks;
  String? assessError;

  /// What the member holds (plan places, levels opened with credits or bought); nothing known when null.
  MemberAccess? access;
  int memberReads = 0;
  final groupsReads = <String>[];
  final groupReads = <String>[];

  @override
  Future<List<PaperGroup>> groups(PaperKind kind) async {
    groupsReads.add(kind.api);
    final error = kind == PaperKind.assessment ? assessError : null;
    if (error != null) throw ApiError(error, statusCode: 500);
    return kind == PaperKind.assessment ? assessments : mocks;
  }

  @override
  Future<PaperGroup> group(PaperKind kind, String key) async {
    groupReads.add('${kind.api}:$key');
    return [...assessments, ...mocks].firstWhere((g) => g.key == key);
  }

  @override
  Future<MemberLearning> member(PaperKind kind) async {
    memberReads++;
    return MemberLearning(access: access);
  }

  @override
  Future<int> unreadNotifications() async => 0;

  @override
  Uri plansLink() => Uri.parse('https://icr.org.in/pricing/professional');

  @override
  Uri partnerLink() => Uri.parse('https://icr.org.in/learning');

  @override
  Uri paperLink(PaperGroup group, AssessPaper paper) => Uri.parse('https://icr.org.in/learning/${group.key}');

  @override
  Uri groupLink(PaperGroup group) => Uri.parse('https://icr.org.in/learning/${group.key}');

  @override
  dynamic noSuchMethod(Invocation invocation) => Completer<Never>().future;
}

PaperGroup _programme(int i) => PaperGroup(
  kind: PaperKind.assessment,
  id: 'g$i',
  key: 'prog-$i',
  title: 'Programme $i',
  papers: [
    AssessPaper(
      id: 'p$i',
      slug: 'prog-$i-foundation',
      title: 'Foundation',
      kind: PaperKind.assessment,
      level: 'FOUNDATION',
    ),
  ],
);

List<PaperGroup> _programmes(int n) => [for (var i = 1; i <= n; i++) _programme(i)];

List<PaperGroup> _subjects() => [
  PaperGroup(
    kind: PaperKind.mock,
    id: 's1',
    key: 'aee-cbcp',
    title: 'AEE CBCP',
    papers: const [AssessPaper(id: 'm1', slug: 'aee-cbcp-1', title: 'Set 1', kind: PaperKind.mock)],
  ),
  PaperGroup(
    kind: PaperKind.mock,
    id: 's2',
    key: 'ifma-fmp',
    title: 'IFMA FMP',
    papers: const [AssessPaper(id: 'm2', slug: 'ifma-fmp-1', title: 'Set 1', kind: PaperKind.mock)],
  ),
];

/// [n] mock exam subjects (`mock-subject-1` …), for a grid three rows deep.
List<PaperGroup> _subjectsOf(int n) => [
  for (var i = 1; i <= n; i++)
    PaperGroup(
      kind: PaperKind.mock,
      id: 'sub$i',
      key: 'subject-$i',
      title: 'Subject $i',
      papers: [AssessPaper(id: 'ms$i', slug: 'subject-$i-1', title: 'Set 1', kind: PaperKind.mock)],
    ),
];

/// The decks the hub's rail reads, with a formula shelf among them that the rail leaves out.
class _Study implements StudyRepository {
  int topicReads = 0;
  final opened = <String>[];
  final shelves = const [
    StudyTopic(id: 'd1', slug: 'hvac', title: 'HVAC Systems', cardCount: 45),
    StudyTopic(id: 'd2', slug: 'leasing', title: 'Leasing', cardCount: 1),
    StudyTopic(id: 'f1', slug: 'formulas', title: 'Formulas', kind: StudyKind.formula, cardCount: 9),
  ];

  @override
  Future<List<StudyTopic>> topics() async {
    topicReads++;
    return shelves;
  }

  @override
  Future<StudyTopic> topic(String slug) async {
    opened.add(slug);
    final shelf = shelves.firstWhere((t) => t.slug == slug);
    return shelf.withCards([
      StudyCard(
        id: 'c1',
        topicId: shelf.id,
        front: 'What is HVAC?',
        back: 'Heating, ventilation and air conditioning.',
      ),
    ]);
  }

  @override
  Future<DeckPlan?> deckPlan() async => null;

  @override
  Future<List<StudyCard>> starredCards() async => const [];

  @override
  Future<void> setStar(String cardId, bool starred) async {}

  @override
  Future<int> unreadNotifications() async => 0;

  @override
  Uri plansLink([String slug = 'professional']) => Uri.parse('https://icr.org.in/pricing/$slug');
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

Widget _assessment(BuildContext c, VoidCallback back) => _Stub('assessment', back);
Widget _mockTests(BuildContext c, VoidCallback back) => _Stub('mockTests', back);
Widget _flashCards(BuildContext c, VoidCallback back) => _Stub('flashCards', back);
Widget _knowledgeCenter(BuildContext c, VoidCallback back) => _Stub('knowledgeCenter', back);
Widget _myAttempts(BuildContext c, VoidCallback back) => _Stub('myAttempts', back);
Widget _certificates(BuildContext c, VoidCallback back) => _Stub('certificates', back);

const _stubRoutes = LearningRoutes(
  assessment: _assessment,
  mockTests: _mockTests,
  flashCards: _flashCards,
  knowledgeCenter: _knowledgeCenter,
  myAttempts: _myAttempts,
  certificates: _certificates,
);

// --- fixtures --------------------------------------------------------------------------------------------

const _icrInstitute = CourseProvider(id: 'p-icr', name: 'ICR Institute', slug: 'icr-institute');
const _vinfraa = CourseProvider(id: 'p-vin', name: 'Vinfraa Institute', slug: 'vinfraa', verified: true);

Course _course(
  String code,
  String title, {
  CourseKind kind = CourseKind.development,
  CourseProvider? provider,
  MyEnrolment? enrolment,
  String? summary,
}) => Course(
  id: 'c-$code',
  code: code,
  title: title,
  summary: summary,
  kind: kind,
  level: 'Foundation',
  provider: provider,
  enrolment: enrolment,
  detailLoaded: true,
);

MyEnrolment _place(String code, {EnrolmentStatus status = EnrolmentStatus.confirmed}) =>
    MyEnrolment(id: 'e-$code', courseId: 'c-$code', status: status);

/// Three taught courses (one of ICR's institute, one of a partner's, one ICR runs itself — production's Facility
/// Management Professional) and twelve certification programmes: more than a rail holds.
List<Course> _catalogue() => [
  _course(
    'CALS',
    'Certificate in Advanced Leadership Skills',
    provider: _icrInstitute,
    enrolment: _place('CALS'),
    summary: 'Lead through disruption.',
  ),
  _course('FAM', 'Facilities Asset Management', provider: _vinfraa),
  _course('FMP', 'Facility Management Professional'),
  for (var i = 1; i <= 12; i++)
    _course('P$i', i == 3 ? 'Communication' : 'Programme number $i', kind: CourseKind.assessment),
];

/// The catalogue for a member who holds no place: the design's page, with no My courses row.
List<Course> _unplaced() => [for (final c in _catalogue()) c.copyWith(clearEnrolment: true)];

const _vinfraaInstitute = Institute(
  id: 'p-vin',
  name: 'Vinfraa Institute',
  slug: 'vinfraa',
  summary: 'Facility management certifications.',
  verified: true,
  courseCount: 1,
  website: 'https://vinfraa.test',
);
const _icrInstituteRow = Institute(id: 'p-icr', name: 'ICR Institute', slug: 'icr-institute', courseCount: 1);
const _emptyInstitute = Institute(id: 'p-new', name: 'Brand New Academy', slug: 'brand-new');

List<Institute> _institutes() => const [_vinfraaInstitute, _icrInstituteRow, _emptyInstitute];

// --- the harness ---------------------------------------------------------------------------------------------

/// Every screen's bell opens the app's notifications, which read their repository from above the screen.
Widget _app(Widget home) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: buildAppTheme(),
  home: Provider<NotificationsRepository>.value(value: DemoNotificationsRepository(), child: home),
);

void main() {
  setUpAll(loadAppFonts);

  late _Launches launches;
  late int backs;

  setUp(() {
    launches = _Launches()..install();
    backs = 0;
  });
  tearDown(() => launches.remove());

  /// A hub over fakes, on a phone as tall as [heightDp] (tall enough to build every tile by default).
  Future<LearningHubController> pumpHub(
    WidgetTester tester, {
    _Courses? courses,
    _Hub? hub,
    _Assess? assess,
    _Study? study,
    double heightDp = 3000,
    bool settle = true,
    Widget Function(Widget child)? wrap,
    VoidCallback? onMasterclasses,
  }) async {
    tester.view.physicalSize = Size(780, heightDp * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final controller = LearningHubController(
      repository: hub ?? _Hub(list: _institutes()),
      learning: LearningController(courses ?? _Courses(_catalogue())),
      assess: assess ?? _Assess(),
      study: study ?? _Study(),
    );
    addTearDown(controller.dispose);
    final screen = LearningHubScreen(
      onBack: () => backs++,
      controller: controller,
      routes: _stubRoutes,
      onMasterclasses: onMasterclasses,
    );
    await tester.pumpWidget(_app(wrap == null ? screen : wrap(screen)));
    if (settle) await tester.pumpAndSettle();
    return controller;
  }

  Future<void> pumpHubWith(WidgetTester tester, LearningHubController controller, {double heightDp = 3000}) async {
    tester.view.physicalSize = Size(780, heightDp * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(LearningHubScreen(onBack: () => backs++, controller: controller, routes: _stubRoutes)),
    );
    await tester.pumpAndSettle();
  }

  Finder doorKey(LearningDoor d) => find.byKey(ValueKey('catalogue-${d.name}'));

  Future<void> tapDoor(WidgetTester tester, LearningDoor door) async {
    await tester.ensureVisible(doorKey(door));
    await tester.tap(doorKey(door));
    await tester.pumpAndSettle();
  }

  Future<void> back(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('stub-back')));
    await tester.pumpAndSettle();
  }

  /// A section's "View More": the one in [heading]'s own row.
  Finder viewMoreOf(String heading) =>
      find.descendant(of: find.widgetWithText(HubSectionHeading, heading), matching: find.text('View More'));

  group('the doors', () {
    test('six, in the order the website lists them, each with its own artwork and words', () {
      expect(LearningDoor.values.map((d) => d.title), [
        'Assess Your Knowledge',
        'Mock Exams',
        'Flash Cards',
        'Knowledge Center',
        'ICR Courses',
        'Partner Courses',
      ]);
      expect(LearningDoor.values.map((d) => d.cta).toSet().length, 6);
      expect(LearningDoor.values.map((d) => d.image).toSet().length, 6, reason: 'one picture twice reads as a mistake');
      for (final d in LearningDoor.values) {
        expect(d.blurb.length, lessThanOrEqualTo(40), reason: '${d.title}: one line on a phone tile');
      }
    });

    test('every door has a picture the app bundles', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      for (final d in LearningDoor.values) {
        final data = await rootBundle.load(d.image);
        expect(data.lengthInBytes, greaterThan(1000), reason: d.image);
      }
    });

    test('a search names a door by its title, its words or what people call it', () {
      expect(LearningDoor.flashCards.matches('flash'), isTrue);
      expect(LearningDoor.flashCards.matches('flashcards'), isTrue);
      expect(LearningDoor.mockTests.matches('mock test'), isTrue);
      expect(LearningDoor.assessment.matches('quiz'), isTrue);
      expect(LearningDoor.knowledgeCenter.matches('formula'), isTrue);
      expect(LearningDoor.partnerCourses.matches('institute'), isTrue);
      expect(LearningDoor.icrCourses.matches('enrol'), isTrue);
      expect(LearningDoor.icrCourses.matches('quiz'), isFalse);
      expect(LearningDoor.mockTests.matches('latest'), isFalse, reason: '"test" inside another word is not a match');
      expect(LearningDoor.mockTests.matches(''), isTrue);
    });

    test('the four doors other builders own have a route; ICR and Partner Courses are the hub’s own', () {
      const routes = LearningRoutes();
      expect(routes.forDoor(LearningDoor.assessment), isNotNull);
      expect(routes.forDoor(LearningDoor.mockTests), isNotNull);
      expect(routes.forDoor(LearningDoor.flashCards), isNotNull);
      expect(routes.forDoor(LearningDoor.knowledgeCenter), isNotNull);
      expect(routes.forDoor(LearningDoor.icrCourses), isNull);
      expect(routes.forDoor(LearningDoor.partnerCourses), isNull);
    });
  });

  group('the hub controller', () {
    test('its counts are the member’s: places from the catalogue, attempts and certificates from the hub', () async {
      final hub = LearningHubController(
        repository: _Hub(list: _institutes(), mine: const MyLearning(attempts: 4, certificates: 2)),
        learning: LearningController(_Courses(_catalogue())),
      );
      expect(hub.coursesHeld, isNull, reason: 'unknown until the catalogue has loaded');
      await hub.start();
      expect(hub.coursesHeld, 1);
      expect(hub.attempts, 4);
      expect(hub.certificates, 2);
      expect(hub.unread, 2);
      hub.dispose();
    });

    test('a refused count is unknown, not zero, and does not blank the other', () async {
      final hub = LearningHubController(
        repository: _Hub(mine: const MyLearning(attempts: null, certificates: 3)),
        learning: LearningController(_Courses(_catalogue())),
      );
      await hub.start();
      expect(hub.attempts, isNull);
      expect(hub.certificates, 3);
      hub.dispose();
    });

    test('a search narrows the doors, the ICR rail and the institutes; clearing gives them back', () async {
      final hub = LearningHubController(
        repository: _Hub(list: _institutes()),
        learning: LearningController(_Courses(_catalogue())),
      );
      await hub.start();
      expect(hub.doors.length, 6);
      expect(hub.courseRail.length, LearningHubController.courseRailLimit);
      expect(hub.institutesShown.length, 3);

      hub.setSearch('  Vinfraa ');
      expect(hub.search, 'vinfraa');
      expect(hub.institutesShown.map((i) => i.id), ['p-vin']);
      expect(hub.courseRail.map((c) => c.code), ['FAM'], reason: "a partner's name finds its courses");
      expect(hub.doors, isEmpty);

      hub.setSearch('communication');
      expect(hub.courseRail.map((c) => c.code), ['P3']);
      expect(hub.institutesShown, isEmpty);
      expect(hub.icrCourses, isEmpty, reason: "a certification programme is Assess Your Knowledge's, not the row's");
      expect(hub.nothingMatches, isTrue, reason: 'no section shows it here, so the page says so rather than go blank');

      hub.setSearch('facility management');
      expect(hub.icrCourses.map((c) => c.code), ['FMP'], reason: 'the taught course ICR runs itself');

      hub.setSearch('flash');
      expect(hub.doors, [LearningDoor.flashCards]);
      expect(hub.courseRail, isEmpty);
      expect(hub.nothingMatches, isTrue, reason: 'the doors are not on the page any more');

      hub.setSearch('zzzz');
      expect(hub.nothingMatches, isTrue);

      hub.clearSearch();
      expect(hub.narrowed, isFalse);
      expect(hub.doors.length, 6);
      hub.dispose();
    });

    test('the rail lists taught courses before certification programmes, capped at nine', () async {
      final hub = LearningHubController(repository: _Hub(), learning: LearningController(_Courses(_catalogue())));
      await hub.start();
      expect(hub.courseRail.map((c) => c.code).take(4), ['CALS', 'FAM', 'FMP', 'P1']);
      expect(hub.courseRail.length, 9);
      expect(hub.matchingCourses.length, 15);
      hub.dispose();
    });

    test('an institute enquiry returns null when sent and the API’s sentence when refused', () async {
      final repo = _Hub();
      final hub = LearningHubController(repository: repo, learning: LearningController(_Courses(const [])));
      expect(await hub.enquireInstitute(_vinfraaInstitute, 'Hello there, institute'), isNull);
      expect(repo.enquiries.single, (slug: 'vinfraa', message: 'Hello there, institute'));
      repo.enquireError = 'Too many requests. Wait a minute and try again.';
      expect(await hub.enquireInstitute(_vinfraaInstitute, 'Hello again, institute'), contains('Too many requests'));
      expect(repo.enquiries.length, 1);
      hub.dispose();
    });

    test('a change in the course controller reaches the hub’s listeners', () async {
      final learning = LearningController(_Courses(_catalogue()));
      final hub = LearningHubController(repository: _Hub(), learning: learning);
      var notified = 0;
      hub.addListener(() => notified++);
      learning.setSearch('x');
      expect(notified, 1);
      hub.dispose();
      learning.setSearch('y'); // after the hub is gone: no error
      learning.dispose();
    });

    test('a hub that owns its course controller disposes it', () {
      final learning = LearningController(_Courses(const []));
      LearningHubController(repository: _Hub(), learning: learning, ownsLearning: true).dispose();
      expect(() => learning.addListener(() {}), throwsFlutterError);
    });
  });

  group('the hub screen (the Learning Centre design)', () {
    testWidgets('opens on the design: the header, Catalogue, the grids, the decks rail and the banner', (tester) async {
      // A member who holds nothing yet: the page is the design's, with no My courses row.
      await pumpHub(tester, courses: _Courses(_unplaced()));
      expect(find.byType(HomeHeader), findsOneWidget, reason: 'the Home header, not a title bar');
      expect(find.byType(TitleBar), findsNothing);
      expect(find.byType(CatalogueRail), findsOneWidget);
      for (final door in CatalogueRail.doors) {
        expect(doorKey(door), findsOneWidget, reason: door.name);
      }
      expect(find.text('Assess your knowledge'), findsOneWidget);
      expect(find.text('Knowledge Centre'), findsOneWidget);
      for (final heading in [
        'Catalogue',
        'Assess Your Knowledge',
        'Mock Exams',
        'Flash Cards',
        'ICR Certifications',
        'Partner Courses',
      ]) {
        expect(find.widgetWithText(HubSectionHeading, heading), findsOneWidget, reason: heading);
      }
      expect(find.text('View More'), findsNWidgets(6));
      expect(find.byType(MasterclassBanner), findsOneWidget);
      expect(find.text('Webinars by the best in the industry!'), findsOneWidget);
      expect(find.text('My learning'), findsNothing, reason: 'not on the design');
      expect(find.text('Choose your training programme'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a catalogue tile opens its door with the Learning tab lit', (tester) async {
      await pumpHub(tester);
      await tapDoor(tester, LearningDoor.mockTests);
      expect(find.text('stub:mockTests'), findsOneWidget);
      await back(tester);
      expect(find.byType(LearningHubScreen), findsOneWidget);
    });

    testWidgets(
      'Assess Your Knowledge holds the first six programmes; View More opens the catalogue, a card its programme',
      (tester) async {
        final assess = _Assess(assessments: _programmes(7));
        await pumpHub(tester, assess: assess);
        for (var i = 1; i <= 6; i++) {
          expect(find.byKey(ValueKey('assess-prog-$i')), findsOneWidget, reason: 'programme $i');
        }
        expect(find.byKey(const ValueKey('assess-prog-7')), findsNothing, reason: 'six, then View More');
        await tester.tap(viewMoreOf('Assess Your Knowledge'));
        await tester.pumpAndSettle();
        expect(find.text('stub:assessment'), findsOneWidget);
        await back(tester);
        await tester.tap(find.byKey(const ValueKey('assess-prog-1')));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(GroupScreen), findsOneWidget);
        expect(assess.groupReads, ['ASSESSMENT:prog-1']);
      },
    );

    testWidgets('Mock Exams holds the subjects; View More opens the mock exams screen', (tester) async {
      await pumpHub(tester);
      expect(find.byKey(const ValueKey('mock-aee-cbcp')), findsOneWidget);
      expect(find.byKey(const ValueKey('mock-ifma-fmp')), findsOneWidget);
      await tester.tap(viewMoreOf('Mock Exams'));
      await tester.pumpAndSettle();
      expect(find.text('stub:mockTests'), findsOneWidget);
    });

    testWidgets('Flash Cards: a tile per deck with its count, never a formula shelf; View More and a tile open', (
      tester,
    ) async {
      final study = _Study();
      await pumpHub(tester, study: study);
      expect(find.byKey(const ValueKey('deck-hvac')), findsOneWidget);
      expect(find.byKey(const ValueKey('deck-leasing')), findsOneWidget);
      expect(find.byKey(const ValueKey('deck-formulas')), findsNothing);
      expect(find.text('45 Cards'), findsOneWidget);
      expect(find.text('1 Card'), findsOneWidget);
      await tester.tap(viewMoreOf('Flash Cards'));
      await tester.pumpAndSettle();
      expect(find.text('stub:flashCards'), findsOneWidget);
      await back(tester);
      await tester.tap(find.byKey(const ValueKey('deck-hvac')));
      await tester.pumpAndSettle();
      expect(find.byType(DeckStudyScreen), findsOneWidget);
      expect(study.opened, ['hvac']);
    });

    testWidgets("ICR Certifications shows ICR's courses with the ICR tab, Partner Courses the institutes'", (
      tester,
    ) async {
      await pumpHub(tester);
      // Only the taught courses with no awarding body are ICR's, as the website's "ICR certifications" rail (it
      // reads kind=DEVELOPMENT, so one card on production); CALS is ICR Institute's and FAM (Vinfraa) is
      // Vinfraa's — the institutes', which Partner Courses lists as the institutes themselves (the website's
      // "Partner institutes" rail), each opening its own course list. The certification programmes (P1…) are
      // Assess Your Knowledge's.
      expect(find.byKey(const ValueKey('cert-c-FMP')), findsOneWidget);
      expect(find.byKey(const ValueKey('cert-c-CALS')), findsNothing, reason: "an institute's, even ICR's own");
      expect(find.byKey(const ValueKey('cert-c-P1')), findsNothing, reason: 'a certification programme (owner, 3 Nov)');
      expect(find.byKey(const ValueKey('cert-c-FAM')), findsNothing);
      expect(find.byKey(const ValueKey('partner-c-FAM')), findsNothing, reason: 'institutes, not their courses');
      expect(find.byKey(const ValueKey('institute-p-vin')), findsOneWidget);
      expect(find.byKey(const ValueKey('institute-p-icr')), findsOneWidget, reason: "ICR's institute is one too");
      expect(find.text('ICR'), findsOneWidget, reason: 'the tab on the ICR card');
      await tester.tap(find.byKey(const ValueKey('institute-p-vin')));
      await tester.pumpAndSettle();
      expect(find.byType(PartnerScreen), findsOneWidget, reason: "the institute's own course list");
      await tester.tap(find.bySemanticsLabel('Back').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('cert-c-FMP')));
      await tester.pumpAndSettle();
      expect(find.byType(CourseSheetBody), findsOneWidget);
    });

    testWidgets("Catalogue's View More opens the six doors as tiles, and a tile its door", (tester) async {
      await pumpHub(tester);
      await tester.tap(viewMoreOf('Catalogue'));
      await tester.pumpAndSettle();
      expect(find.byType(CatalogueScreen), findsOneWidget);
      expect(find.byType(LearningScreen), findsNothing, reason: 'the categories, not the ICR Courses list');
      for (final door in LearningDoor.values) {
        expect(find.byKey(ValueKey('door-${door.name}')), findsOneWidget, reason: door.name);
      }
      await tester.tap(find.byKey(const ValueKey('door-mockTests')));
      await tester.pumpAndSettle();
      expect(find.text('stub:mockTests'), findsOneWidget);
      await back(tester);
      expect(find.byType(CatalogueScreen), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Back').last);
      await tester.pumpAndSettle();
      expect(find.byType(LearningHubScreen), findsOneWidget);
    });

    testWidgets('View More on ICR Certifications opens the course grid, on Partner Courses the directory', (
      tester,
    ) async {
      await pumpHub(tester);
      await tester.tap(viewMoreOf('ICR Certifications'));
      await tester.pumpAndSettle();
      expect(find.byType(LearningScreen), findsOneWidget);
      expect(find.text('ICR Courses'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();
      await tester.tap(viewMoreOf('Partner Courses'));
      await tester.pumpAndSettle();
      expect(find.byType(PartnerCoursesScreen), findsOneWidget);
    });

    testWidgets('a section whose read failed says why, and Try again reads it again; an empty section is left out', (
      tester,
    ) async {
      final assess = _Assess(assessments: _programmes(2), mocks: const [], assessError: 'Papers are down');
      await pumpHub(tester, assess: assess);
      expect(find.text('Papers are down'), findsOneWidget);
      expect(find.widgetWithText(HubSectionHeading, 'Mock Exams'), findsNothing, reason: 'no subjects: no section');
      assess.assessError = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('assess-prog-1')), findsOneWidget);
      expect(assess.groupsReads.where((k) => k == 'ASSESSMENT').length, 2);
    });

    testWidgets('the header search is a button that opens the global search; the hub keeps its sections', (
      tester,
    ) async {
      var opened = 0;
      AppActions.openSearch = (context, {query}) async => opened++;
      addTearDown(() => AppActions.openSearch = null);
      await pumpHub(tester);
      expect(
        find.descendant(of: find.byKey(const ValueKey('home-search')), matching: find.byType(TextField)),
        findsNothing,
        reason: 'nothing is typed into the header: search happens on its own screen',
      );
      await tester.tap(find.byKey(const ValueKey('home-search')));
      await tester.pumpAndSettle();
      expect(opened, 1);
      expect(find.byType(CatalogueRail), findsOneWidget);
      expect(find.byKey(const ValueKey('assess-prog-1')), findsOneWidget);
    });

    testWidgets('pulling down reads every section again', (tester) async {
      final assess = _Assess(assessments: _programmes(2));
      final study = _Study();
      final courses = _Courses(_catalogue());
      await pumpHub(tester, courses: courses, assess: assess, study: study);
      await tester.widget<RefreshIndicator>(find.byType(RefreshIndicator).first).onRefresh();
      await tester.pumpAndSettle();
      expect(assess.groupsReads.length, 4, reason: 'programmes and subjects, twice');
      expect(study.topicReads, 2);
      expect(courses.courseCalls, 2);
    });

    testWidgets("the bell opens the app's notifications, with the dot from the catalogue's count", (tester) async {
      await pumpHub(
        tester,
        wrap: (child) => Provider<NotificationsRepository>.value(value: DemoNotificationsRepository(), child: child),
      );
      expect(find.bySemanticsLabel('Notifications, 2 unread'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('home-bell')));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsScreen), findsOneWidget);
      expect(launches.urls, isEmpty);
    });

    testWidgets('Know more opens the Events screen through the app, the website without it', (tester) async {
      var knowMore = 0;
      await pumpHub(tester, onMasterclasses: () => knowMore++);
      await tester.tap(find.byType(MasterclassBanner));
      await tester.pump();
      expect(knowMore, 1);
      expect(launches.urls, isEmpty);
      await pumpHub(tester);
      await tester.tap(find.byType(MasterclassBanner));
      await tester.pump();
      expect(launches.urls.single, endsWith('/events'));
    });

    group("the page keeps the export's measures (docs/designs/learning-hub-v2.png, below its header)", () {
      // Six programmes and six subjects, so every grid is three rows deep; a member who holds nothing, so no My
      // courses row sits between the Catalogue and the grids.
      Future<void> pumpDesign(WidgetTester tester) => pumpHub(
        tester,
        courses: _Courses(_unplaced()),
        assess: _Assess(assessments: _programmes(6), mocks: _subjectsOf(6)),
        heightDp: 2400,
      );

      testWidgets('the rail, the grids, the decks and the banner sit where the export draws them', (tester) async {
        await pumpDesign(tester);
        Rect rect(Finder f) => tester.getRect(f);
        const top = HomeHeader.height;
        // Catalogue: a 36 dp heading row at the header's foot, the tiles 1 dp under it, 109 × 80 photos 4 apart.
        final catalogue = rect(find.widgetWithText(HubSectionHeading, 'Catalogue'));
        expect(catalogue.top, closeTo(top, 0.1));
        expect(catalogue.height, 36);
        final assessTile = rect(doorKey(LearningDoor.assessment));
        expect(assessTile.top, closeTo(top + 37, 0.1));
        expect(assessTile.left, closeTo(15.25, 0.1));
        expect(assessTile.width, 109);
        expect(
          assessTile.height,
          closeTo(80 + 41.6, 0.4),
          reason: 'the photo and a 41.6 dp pane for two caption lines',
        );
        expect(rect(doorKey(LearningDoor.mockTests)).left - assessTile.right, closeTo(4, 0.1));

        // The cards: 171 × 120, 16 in and 16 apart, rows 127.5 apart.
        final first = rect(find.byKey(const ValueKey('assess-prog-1')));
        final second = rect(find.byKey(const ValueKey('assess-prog-2')));
        expect(first.left, closeTo(16, 0.1));
        expect(first.width, closeTo(171, 0.1));
        expect(first.height, closeTo(120, 0.1));
        expect(second.left - first.right, closeTo(16, 0.1));
        expect(390 - second.right, closeTo(16, 0.1));
        expect(rect(find.byKey(const ValueKey('assess-prog-3'))).top - first.top, closeTo(127.5, 0.1));
        expect(rect(find.byKey(const ValueKey('assess-prog-5'))).top - first.top, closeTo(255, 0.1));
        // The first card starts 207 dp under the header: the rail, a hairline and the 36 dp heading row.
        expect(first.top, closeTo(top + 207, 0.6));

        // Section to section, as the export spaces them (card top to card top).
        final mock = rect(find.byKey(const ValueKey('mock-subject-1')));
        expect(mock.top - first.top, closeTo(428, 0.6), reason: '3 rows, 10 dp, a hairline, 6 dp, the 36 dp heading');
        final tile = rect(find.byKey(const ValueKey('deck-hvac')));
        expect(tile.top - mock.top, closeTo(427, 0.6), reason: '3 rows, 16 dp with no hairline, the 36 dp heading');
        expect(tile.width, closeTo(107.5, 0.1));
        expect(tile.height, 70);
        expect(tile.left, closeTo(16, 0.1));
        final cert = rect(find.byKey(const ValueKey('cert-c-FMP')));
        expect(
          cert.top - tile.top,
          closeTo(123, 0.6),
          reason: '70 dp tiles, 10 dp, a hairline, 6 dp, the 36 dp heading',
        );
        final partner = rect(find.byKey(const ValueKey('institute-p-vin')));
        expect(partner.top - cert.top, closeTo(173.1, 0.6), reason: "one row: production's one ICR course");
        // The banner: 10 dp under the last card (the institutes fill two rows), 92 dp tall, the width of the screen.
        final lastPartner = rect(find.byType(InstituteCard).last);
        final banner = rect(find.byType(MasterclassBanner));
        expect(banner.top - lastPartner.bottom, closeTo(10, 0.1));
        expect(banner.height, closeTo(92, 0.1));
        expect(banner.width, 390);
        expect(tester.takeException(), isNull);
      });

      testWidgets('four hairlines: under the Catalogue, Assess Your Knowledge, Flash Cards and ICR Certifications', (
        tester,
      ) async {
        await pumpDesign(tester);
        Rect rect(Finder f) => tester.getRect(f);
        expect(find.byType(HubRule), findsNWidgets(4), reason: 'none after Mock Exams, none before the banner');
        // A heading row follows the last card of Mock Exams 16 dp under it, as a hairline and its gaps would.
        final lastMock = rect(find.byKey(const ValueKey('mock-subject-5')));
        final flash = rect(find.byKey(const ValueKey('flash-heading')));
        expect(flash.top - lastMock.bottom, closeTo(16, 0.1));
      });

      testWidgets('a search takes the Catalogue and the banner away and starts the first section at the header', (
        tester,
      ) async {
        final hub = await pumpHub(
          tester,
          assess: _Assess(assessments: _programmes(6), mocks: _subjectsOf(6)),
        );
        hub.setSearch('facility management');
        await tester.pumpAndSettle();
        expect(find.byType(MasterclassBanner), findsNothing);
        expect(find.byType(CatalogueRail), findsNothing);
        final heading = tester.getRect(find.byType(HubSectionHeading).first);
        expect(heading.top, closeTo(HomeHeader.height, 0.1), reason: 'the first section starts at the header');
      });
    });
  });

  // Owner, 3 Nov 2026: one horizontal row of what the member holds, under the Catalogue — exams as well as
  // courses — and "View More" to the My courses page, which files them under their own headings.
  group('My courses (the row under the Catalogue)', () {
    // A mock exam on the plan, an Assess Your Knowledge level opened with credits, and the course place in the
    // catalogue (Certificate in Advanced Leadership Skills).
    _Assess holding() => _Assess(
      access: const MemberAccess(
        paperIds: {'p2'},
        creditPaperIds: {'p2'},
        mocks: PlanPlaces(limit: 2, opened: ['s1']),
      ),
    );

    List<String> rowKeys(WidgetTester tester) => [
      for (final card in tester.widgetList<LearnCard>(
        find.descendant(of: find.byKey(const ValueKey('rail-my-courses')), matching: find.byType(LearnCard)),
      ))
        (card.key! as ValueKey<String>).value,
    ];

    testWidgets('sits under the Catalogue: exams first, as My courses shelves them, then the courses held', (
      tester,
    ) async {
      await pumpHub(tester, assess: holding());
      final heading = tester.getRect(find.byKey(const ValueKey('my-courses-heading')));
      expect(
        heading.top,
        greaterThan(tester.getRect(find.byType(CatalogueRail)).bottom),
        reason: 'under the Catalogue',
      );
      expect(
        heading.bottom,
        lessThanOrEqualTo(tester.getRect(find.byKey(const ValueKey('assess-heading'))).top),
        reason: 'above Assess Your Knowledge',
      );
      expect(rowKeys(tester), ['my-mock:s1', 'my-paper:p2', 'my-course:c-CALS']);
      expect(find.text('Programme 2 · Foundation'), findsOneWidget, reason: 'a level held on its own is named');
      // One row that scrolls sideways, not a grid.
      final first = tester.getRect(find.byKey(const ValueKey('my-mock:s1')));
      final second = tester.getRect(find.byKey(const ValueKey('my-paper:p2')));
      expect(second.top, first.top);
      expect(second.left - first.right, closeTo(12, 0.1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a member who holds nothing has no row', (tester) async {
      await pumpHub(tester, courses: _Courses(_unplaced()));
      expect(find.byKey(const ValueKey('my-courses-heading')), findsNothing);
      expect(find.byKey(const ValueKey('rail-my-courses')), findsNothing);
    });

    testWidgets('a course place alone is enough, and a new place joins the row at once', (tester) async {
      final hub = await pumpHub(tester, courses: _Courses(_unplaced()));
      expect(find.byKey(const ValueKey('rail-my-courses')), findsNothing);
      final fam = hub.learning.courses.firstWhere((c) => c.code == 'FAM');
      await tester.runAsync(() => hub.learning.enrol(fam));
      await tester.pumpAndSettle();
      expect(rowKeys(tester), ['my-course:c-FAM']);
    });

    testWidgets('View More opens My courses with its headings; a card opens what it is', (tester) async {
      final assess = holding();
      final study = _Study();
      // As the app builds it (`createHubController`): the course controller reads the exams too, for the page's
      // shelves of what the member opened.
      await pumpHubWith(
        tester,
        LearningHubController(
          repository: _Hub(list: _institutes()),
          learning: LearningController(_Courses(_catalogue()), assess: assess, study: study),
          assess: assess,
          study: study,
          ownsLearning: true,
        ),
      );
      await tester.tap(
        find.descendant(of: find.byKey(const ValueKey('my-courses-heading')), matching: find.text('View More')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LearningScreen), findsOneWidget);
      expect(find.text('My courses'), findsWidgets);
      // The leadership course is the ICR Institute's, an institute's course: Partner Courses.
      for (final heading in ['Mock Exams', 'Assess Your Knowledge', 'Partner Courses']) {
        expect(find.text(heading), findsOneWidget, reason: heading);
      }
      final before = assess.memberReads;
      Navigator.of(tester.element(find.byType(LearningScreen))).pop();
      await tester.pumpAndSettle();
      expect(assess.memberReads, greaterThan(before), reason: 'what the member holds is read again on the way back');

      await tester.tap(find.byKey(const ValueKey('my-mock:s1')));
      // The sets page keeps a spinner going while it reads, so it never settles: two half-second frames, as the
      // other programme taps here.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(GroupScreen), findsOneWidget, reason: "the mock exam's sets");
    });

    testWidgets("the menu's My courses is the page alone: what the member holds, no Learning page around it", (
      tester,
    ) async {
      // Owner, 6 Nov 2026: "My courses means only the courses which are enrolled, not the Learning page."
      tester.view.physicalSize = const Size(780, 6000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final assess = holding();
      final study = _Study();
      final hub = LearningHubController(
        repository: _Hub(list: _institutes()),
        learning: LearningController(_Courses(_catalogue()), assess: assess, study: study),
        assess: assess,
        study: study,
        ownsLearning: true,
      );
      addTearDown(hub.dispose);
      await tester.pumpWidget(_app(MyCoursesScreen(onBack: () => backs++, controller: hub, routes: _stubRoutes)));
      await tester.pumpAndSettle();
      expect(find.byType(LearningHubScreen), findsNothing, reason: 'not the Learning page');
      expect(find.byType(LearningScreen), findsOneWidget);
      expect(hub.learning.mineOnly, isTrue);
      expect(find.text('My courses'), findsWidgets);
      for (final heading in ['Mock Exams', 'Assess Your Knowledge', 'Partner Courses']) {
        expect(find.text(heading), findsOneWidget, reason: heading);
      }
      expect(find.byKey(const ValueKey('my-courses-heading')), findsNothing, reason: "the hub's own row is not here");
      await tester.tap(find.bySemanticsLabel('Back'));
      expect(backs, 1);
    });

    testWidgets('the search narrows the row with the rest of the page', (tester) async {
      final hub = await pumpHub(tester, assess: holding());
      hub.setSearch('leadership');
      await tester.pumpAndSettle();
      expect(rowKeys(tester), ['my-course:c-CALS']);
      hub.setSearch('nothing like this');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('rail-my-courses')), findsNothing);
    });
  });

  group('Partner Courses (the directory)', () {
    Future<LearningHubController> pumpDirectory(
      WidgetTester tester, {
      _Hub? hub,
      Size? size,
      Future<List<PartnerStanding>> Function()? standing,
    }) async {
      tester.view.physicalSize = size ?? const Size(780, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final controller = LearningHubController(
        repository: hub ?? _Hub(list: _institutes()),
        learning: LearningController(_Courses(_catalogue())),
        standingReader: standing,
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_app(PartnerCoursesScreen(onBack: () => backs++, hub: controller)));
      await tester.pumpAndSettle();
      return controller;
    }

    testWidgets('lists every institute with what it has published and whether ICR verified it', (tester) async {
      await pumpDirectory(tester);
      expect(find.text('Partner Courses'), findsOneWidget, reason: 'the title bar');
      expect(find.byType(InstituteCard), findsNWidgets(3));
      expect(find.text('Vinfraa Institute'), findsOneWidget);
      expect(find.text('1 course'), findsNWidgets(2));
      expect(find.text('No courses published yet'), findsOneWidget);
      expect(find.text('Verified by ICR'), findsOneWidget);
    });

    testWidgets("Back goes back and the bell opens the app's notifications", (tester) async {
      await pumpDirectory(tester);
      await tester.tap(find.bySemanticsLabel('Back'));
      expect(backs, 1);
      await tester.tap(find.byType(BellButton));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsScreen), findsOneWidget);
      expect(launches.urls, isEmpty);
    });

    testWidgets('the search narrows by name or summary; with no match it says so and Clear search restores', (
      tester,
    ) async {
      await pumpDirectory(tester);
      await tester.enterText(find.byType(TextField), 'facility');
      await tester.pumpAndSettle();
      expect(find.byType(InstituteCard), findsOneWidget, reason: "found in Vinfraa's summary");
      expect(find.text('1 found'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'nothing like this');
      await tester.pumpAndSettle();
      expect(find.text('No institutes match'), findsOneWidget);
      await tester.tap(find.text('Clear search'));
      await tester.pumpAndSettle();
      expect(find.byType(InstituteCard), findsNWidgets(3));
    });

    testWidgets('a failed load says why and Try again reads the institutes again', (tester) async {
      final hub = _Hub(institutesError: 'Institutes are down.');
      await pumpDirectory(tester, hub: hub);
      expect(find.text("Couldn't load institutes"), findsOneWidget);
      expect(find.text('Institutes are down.'), findsOneWidget);
      hub.institutesError = null;
      hub.list = _institutes();
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(hub.instituteCalls, 2);
      expect(find.byType(InstituteCard), findsNWidgets(3));
    });

    testWidgets('with no institutes it says so', (tester) async {
      await pumpDirectory(tester, hub: _Hub());
      expect(find.text('No institutes yet'), findsOneWidget);
    });

    testWidgets('pulling down reads the institutes again', (tester) async {
      final hub = _Hub(list: _institutes());
      await pumpDirectory(tester, hub: hub);
      expect(hub.instituteCalls, 1);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 400));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(hub.instituteCalls, 2);
    });

    testWidgets('"Apply" opens the partner application on the website', (tester) async {
      await pumpDirectory(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('apply-to-partner')));
      await tester.tap(find.byKey(const ValueKey('apply-to-partner')));
      await tester.pump();
      expect(launches.urls.last, 'https://icr.org.in/learning/partners/apply');
    });

    testWidgets(
      'the banner carries the website\'s words: "Apply to become Partner Institute" and the dialog\'s first lines',
      (tester) async {
        await pumpDirectory(tester);
        expect(find.text('Apply to become Partner Institute'), findsOneWidget);
        expect(
          find.text('Partners apply as a company. Choose a company you run on ICR, or register a new one.'),
          findsOneWidget,
        );
        expect(find.text('Run a training institute?'), findsNothing, reason: 'the old words are gone');
      },
    );

    testWidgets('Apply is there with no institutes listed and when the list failed, as the website\'s heading has it', (
      tester,
    ) async {
      await pumpDirectory(tester, hub: _Hub());
      expect(find.text('No institutes yet'), findsOneWidget);
      expect(find.byKey(const ValueKey('apply-to-partner')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await pumpDirectory(tester, hub: _Hub(institutesError: 'Institutes are down.'));
      expect(find.text("Couldn't load institutes"), findsOneWidget);
      expect(find.byKey(const ValueKey('apply-to-partner')), findsOneWidget);
    });

    testWidgets(
      "a member's standing is read again when the application is closed, so a new application shows at once",
      (tester) async {
        var reads = 0;
        await pumpDirectory(
          tester,
          standing: () async {
            reads++;
            return reads == 1
                ? const <PartnerStanding>[]
                : const [PartnerStanding(companyId: 'c1', name: 'Skystar', applicationStatus: 'PENDING')];
          },
        );
        expect(reads, 1);
        await tester.ensureVisible(find.byKey(const ValueKey('apply-to-partner')));
        await tester.tap(find.byKey(const ValueKey('apply-to-partner')));
        await tester.pumpAndSettle();
        expect(reads, 2, reason: 'back from the application, the companies are read again');
        expect(find.byKey(const ValueKey('apply-to-partner')), findsNothing);
        expect(find.text("Skystar's learning partner application is with ICR"), findsOneWidget);
      },
    );

    group('"Apply" is for someone it applies to', () {
      const apply = ValueKey('apply-to-partner');
      const partner = PartnerStanding(companyId: 'c1', name: 'Skystar', isPartner: true, active: true);

      testWidgets(
        'a member of a company that is already a partner is not asked to apply: the standing, and the console',
        (tester) async {
          await pumpDirectory(tester, standing: () async => [partner]);
          expect(find.byKey(apply), findsNothing);
          expect(find.text('Run a training institute?'), findsNothing);
          expect(find.text('Skystar is a learning partner'), findsOneWidget);
          await tester.ensureVisible(find.byKey(const ValueKey('open-partner-console')));
          await tester.tap(find.byKey(const ValueKey('open-partner-console')));
          await tester.pump();
          expect(launches.urls.last, 'https://icr.org.in/admin/learning');
        },
      );

      testWidgets('a partner company the member is not acting for says how to reach it, with no console button', (
        tester,
      ) async {
        await pumpDirectory(
          tester,
          standing: () async => [const PartnerStanding(companyId: 'c1', name: 'Skystar', isPartner: true)],
        );
        expect(find.byKey(apply), findsNothing);
        expect(find.text('Skystar is a learning partner'), findsOneWidget);
        expect(find.textContaining('Switch to this company'), findsOneWidget);
        expect(find.byKey(const ValueKey('open-partner-console')), findsNothing);
      });

      testWidgets('a company whose application is with ICR (pending or under review) is not asked to apply again', (
        tester,
      ) async {
        await pumpDirectory(
          tester,
          standing: () async => [
            const PartnerStanding(companyId: 'c1', name: 'Skystar', applicationStatus: 'PENDING'),
            const PartnerStanding(companyId: 'c2', name: 'Bluecrest', applicationStatus: 'UNDER_REVIEW'),
          ],
        );
        expect(find.byKey(apply), findsNothing);
        expect(find.text("Skystar's learning partner application is with ICR"), findsOneWidget);
        expect(find.text("Bluecrest's learning partner application is with ICR"), findsOneWidget);
        expect(find.byKey(const ValueKey('open-partner-console')), findsNothing);
      });

      testWidgets(
        'a declined or queried company, a company that never applied, or one of several that can, still sees Apply',
        (tester) async {
          for (final standing in [
            [const PartnerStanding(companyId: 'c1', name: 'Skystar', applicationStatus: 'REJECTED')],
            [const PartnerStanding(companyId: 'c1', name: 'Skystar', applicationStatus: 'INFO_REQUESTED')],
            [const PartnerStanding(companyId: 'c1', name: 'Skystar')],
            [partner, const PartnerStanding(companyId: 'c2', name: 'Bluecrest')],
            const <PartnerStanding>[],
          ]) {
            await pumpDirectory(tester, standing: () async => standing);
            expect(find.byKey(apply), findsOneWidget, reason: '$standing');
            expect(find.textContaining('is a learning partner'), findsNothing);
            await tester.pumpWidget(const SizedBox());
          }
        },
      );

      testWidgets('a visitor, or a read that fails, sees Apply as before', (tester) async {
        await pumpDirectory(tester, standing: () async => throw ApiError('Sign in', statusCode: 401));
        expect(find.byKey(apply), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        await pumpDirectory(tester);
        expect(find.byKey(apply), findsOneWidget);
      });
    });

    test('the application posts what the website\'s dialog posts: the company and the notes, nothing else', () async {
      final api = _Api({
        'POST /learning/partners/applications': (_) => <String, Object?>{'id': 'a1'},
        'GET /learning/partners/companies': (_) => [
          {
            'companyId': 'c1',
            'name': 'Skystar',
            'active': true,
            'provider': null,
            'application': {'status': 'INFO_REQUESTED', 'reviewNote': 'Send your accreditation.'},
          },
        ],
      });
      final repo = ApiPartnerApplyRepository(_client(api));
      final companies = await repo.companies();
      expect(companies.single.statusLabel, 'More info requested');
      expect(companies.single.noteToShow, 'Send your accreditation.');
      expect(companies.single.eligible, isTrue);
      await repo.apply(companyId: 'c1', proposalNotes: 'HVAC and fire safety');
      expect(api.bodies.last, {'companyId': 'c1', 'proposalNotes': 'HVAC and fire safety'});
      await repo.apply(companyId: 'c1', proposalNotes: '   ');
      expect(api.bodies.last, {'companyId': 'c1'}, reason: 'blank notes are not sent');
      await repo.apply(companyId: 'c1');
      expect(api.bodies.last, {'companyId': 'c1'});
    });

    testWidgets('a card opens the institute’s page', (tester) async {
      await pumpDirectory(tester);
      await tester.tap(find.byKey(const ValueKey('institute-p-vin')));
      await tester.pumpAndSettle();
      expect(find.byType(PartnerScreen), findsOneWidget);
    });

    testWidgets('built with no hub, the screen makes its own from the API and lists the institutes', (tester) async {
      tester.view.physicalSize = const Size(780, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final api = _Api({
        'GET /learning/providers': (_) => [
          {'id': 'p1', 'name': 'Vinfraa Institute', 'slug': 'vinfraa', 'courseCount': 2, 'verified': true},
        ],
        'GET /learning/courses': (_) => <Object>[],
        'GET /learning/me/enrollments': (_) => <Object>[],
        'GET /learning/me/attempts': (_) => <Object>[],
        'GET /learning/me/certificates': (_) => <Object>[],
        'GET /notifications/unread-count': (_) => {'unread': 0},
      });
      await tester.pumpWidget(
        _app(
          Provider<ApiClient>.value(
            value: _client(api),
            child: Builder(builder: (context) => PartnerCoursesScreen(onBack: () {})),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Vinfraa Institute'), findsOneWidget);
      expect(find.text('2 courses'), findsOneWidget);
      expect(api.calls, contains('GET /learning/providers'));
    });

    testWidgets("built with no hub, it reads the member's companies from the API and shows a partner's standing", (
      tester,
    ) async {
      tester.view.physicalSize = const Size(780, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final api = _Api({
        'GET /learning/providers': (_) => [
          {'id': 'p1', 'name': 'Vinfraa Institute', 'slug': 'vinfraa', 'courseCount': 2, 'verified': true},
        ],
        'GET /learning/courses': (_) => <Object>[],
        'GET /learning/me/enrollments': (_) => <Object>[],
        'GET /learning/me/attempts': (_) => <Object>[],
        'GET /learning/me/certificates': (_) => <Object>[],
        'GET /notifications/unread-count': (_) => {'unread': 0},
        'GET /learning/partners/companies': (_) => [
          {
            'companyId': 'c1',
            'name': 'Skystar',
            'logoUrl': null,
            'active': true,
            'provider': {'id': 'p9', 'name': 'Skystar'},
            'application': null,
          },
        ],
      });
      await tester.pumpWidget(
        _app(
          Provider<ApiClient>.value(
            value: _client(api),
            child: Builder(builder: (context) => PartnerCoursesScreen(onBack: () {})),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(api.calls, contains('GET /learning/partners/companies'));
      expect(find.text('Skystar is a learning partner'), findsOneWidget);
      expect(find.byKey(const ValueKey('apply-to-partner')), findsNothing);
    });
  });

  group('Partner (one institute)', () {
    Future<(_Hub, LearningHubController)> pumpPartner(
      WidgetTester tester, {
      Institute institute = _vinfraaInstitute,
      List<Course>? courses,
      _Hub? hub,
      _Courses? repo,
    }) async {
      tester.view.physicalSize = const Size(780, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final fake = hub ?? _Hub(list: _institutes());
      final controller = LearningHubController(
        repository: fake,
        learning: LearningController(repo ?? _Courses(courses ?? _catalogue())),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_app(PartnerScreen(institute: institute, onBack: () => backs++, hub: controller)));
      await tester.pumpAndSettle();
      return (fake, controller);
    }

    testWidgets('shows who the institute is: name, verified, how many courses, its own words', (tester) async {
      await pumpPartner(tester);
      expect(find.text('Partner institute'), findsOneWidget, reason: 'the title bar');
      expect(
        find.text('Vinfraa Institute'),
        findsNWidgets(2),
        reason: "its own header, and the awarding body on its course's card",
      );
      expect(find.text('Verified by ICR'), findsOneWidget);
      expect(find.text('1 course'), findsOneWidget);
      expect(find.text('Facility management certifications.'), findsOneWidget);
    });

    testWidgets("lists only this institute's courses, as the grid's cards", (tester) async {
      await pumpPartner(tester);
      expect(find.byType(CourseCard), findsOneWidget);
      expect(find.text('Facilities Asset Management'), findsOneWidget);
      expect(find.text('Certificate in Advanced Leadership Skills'), findsNothing, reason: "another institute's");
      expect(find.text('Professional development'), findsOneWidget, reason: "the kind's heading");
    });

    testWidgets('a card opens the course sheet', (tester) async {
      await pumpPartner(tester);
      await tester.tap(find.byType(CourseCard));
      await tester.pumpAndSettle();
      expect(find.byType(CourseSheetBody), findsOneWidget);
    });

    testWidgets('programmes and taught courses are headed apart; the search narrows within the institute', (
      tester,
    ) async {
      final both = [
        _course('A1', 'Alpha Course', provider: _vinfraa),
        _course('A2', 'Beta Programme', kind: CourseKind.assessment, provider: _vinfraa),
        _course('A3', 'Gamma Course', provider: _vinfraa),
        _course('Z9', 'Elsewhere Course', provider: _icrInstitute),
      ];
      await pumpPartner(tester, courses: both);
      expect(find.text('Professional development'), findsOneWidget);
      expect(find.text('Certification programmes'), findsOneWidget);
      expect(find.byType(CourseCard), findsNWidgets(3));
      await tester.enterText(find.byType(TextField), 'beta');
      await tester.pumpAndSettle();
      expect(find.byType(CourseCard), findsOneWidget);
      expect(find.text('Professional development'), findsNothing);
      await tester.enterText(find.byType(TextField), 'nonsense');
      await tester.pumpAndSettle();
      expect(find.text('No courses match'), findsOneWidget);
      await tester.tap(find.text('Clear search'));
      await tester.pumpAndSettle();
      expect(find.byType(CourseCard), findsNWidgets(3));
    });

    testWidgets('an institute with no published course says so and offers to ask', (tester) async {
      await pumpPartner(tester, institute: _emptyInstitute);
      expect(find.text('No courses published yet'), findsWidgets);
      expect(find.byType(CourseCard), findsNothing);
      expect(find.text('Ask the institute'), findsNWidgets(2), reason: 'the button in the header and in the notice');
    });

    testWidgets("Back goes back; the bell opens the app's notifications", (tester) async {
      await pumpPartner(tester);
      await tester.tap(find.bySemanticsLabel('Back'));
      expect(backs, 1);
      await tester.tap(find.byType(BellButton));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsScreen), findsOneWidget);
      expect(launches.urls, isEmpty);
    });

    testWidgets('there is no Website button, even for an institute that has a site', (tester) async {
      await pumpPartner(tester);
      expect(find.text('Website'), findsNothing);
      expect(find.byKey(const ValueKey('ask-the-institute')), findsOneWidget);
    });

    testWidgets('an institute with no slug cannot be asked', (tester) async {
      await pumpPartner(
        tester,
        institute: const Institute(id: 'p-icr', name: 'ICR Institute'),
      );
      expect(find.byKey(const ValueKey('ask-the-institute')), findsNothing);
    });

    testWidgets('while the courses load there is a spinner; a failed load says why and Try again reads again', (
      tester,
    ) async {
      final repo = _Courses(_catalogue(), listError: 'The server is down.');
      await pumpPartner(tester, repo: repo);
      expect(find.text("Couldn't load courses"), findsOneWidget);
      repo.listError = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.byType(CourseCard), findsOneWidget);
      expect(repo.courseCalls, 2);
    });

    group('Ask the institute', () {
      Future<_Hub> openForm(WidgetTester tester, {_Hub? hub}) async {
        final (fake, _) = await pumpPartner(tester, hub: hub);
        await tester.tap(find.byKey(const ValueKey('ask-the-institute')));
        await tester.pumpAndSettle();
        return fake;
      }

      testWidgets('opens a form that names the institute', (tester) async {
        await openForm(tester);
        expect(find.text('Ask Vinfraa Institute'), findsOneWidget);
        expect(find.byKey(const ValueKey('institute-enquiry-message')), findsOneWidget);
      });

      testWidgets('a message that is too short is refused before anything is sent', (tester) async {
        final hub = await openForm(tester);
        await tester.enterText(find.byKey(const ValueKey('institute-enquiry-message')), 'Hi');
        await tester.tap(find.byKey(const ValueKey('institute-enquiry-send')));
        await tester.pumpAndSettle();
        expect(find.text('Say a little more about what you would like to know.'), findsOneWidget);
        expect(hub.enquiries, isEmpty);
      });

      testWidgets('Send writes to the institute by its slug, closes the form and confirms', (tester) async {
        final hub = await openForm(tester);
        await tester.enterText(
          find.byKey(const ValueKey('institute-enquiry-message')),
          'When does the next intake start?',
        );
        await tester.tap(find.byKey(const ValueKey('institute-enquiry-send')));
        await tester.pumpAndSettle();
        expect(hub.enquiries.single, (slug: 'vinfraa', message: 'When does the next intake start?'));
        expect(find.byKey(const ValueKey('institute-enquiry-message')), findsNothing, reason: 'the form closed');
        expect(find.text('Sent to Vinfraa Institute. They will reply by email.'), findsOneWidget);
      });

      testWidgets('a refused message keeps the form open with the API’s sentence, and can be sent again', (
        tester,
      ) async {
        final hub = await openForm(
          tester,
          hub: _Hub(list: _institutes(), enquireError: 'Too many requests.'),
        );
        await tester.enterText(find.byKey(const ValueKey('institute-enquiry-message')), 'A question about fees please');
        await tester.tap(find.byKey(const ValueKey('institute-enquiry-send')));
        await tester.pumpAndSettle();
        expect(find.text('Too many requests.'), findsOneWidget);
        expect(find.byKey(const ValueKey('institute-enquiry-message')), findsOneWidget);
        expect(hub.enquiries, isEmpty);
        hub.enquireError = null;
        await tester.tap(find.byKey(const ValueKey('institute-enquiry-send')));
        await tester.pumpAndSettle();
        expect(hub.enquiries.length, 1);
        expect(find.text('Sent to Vinfraa Institute. They will reply by email.'), findsOneWidget);
      });
    });
  });

  group('larger text', () {
    for (final scale in [1.3, 1.6]) {
      testWidgets('the hub, the directory and an institute draw without overflow at ${(scale * 100).round()}% text', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(780, 4200);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        final controller = LearningHubController(
          repository: _Hub(list: _institutes()),
          learning: LearningController(_Courses(_catalogue())),
          assess: _Assess(),
          study: _Study(),
        );
        addTearDown(controller.dispose);
        Widget scaled(Widget home) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: home,
        );
        for (final home in [
          LearningHubScreen(onBack: () {}, controller: controller, routes: _stubRoutes),
          PartnerCoursesScreen(onBack: () {}, hub: controller),
          PartnerScreen(institute: _vinfraaInstitute, onBack: () {}, hub: controller),
        ]) {
          await tester.pumpWidget(scaled(home));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '${home.runtimeType} at $scale');
        }
      });
    }
  });

  group('widths', () {
    // The phones come in at 390, 360 and 320 dp: nothing overflows and no text is cut off by a box too short for
    // it (`layoutProblems`, the layout audit's check), at the design's size and at 130 % text.
    for (final width in [390.0, 360.0, 320.0]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets(
          'the hub draws without overflow or clipped text at ${width.round()} dp, ${(scale * 100).round()}% text',
          (tester) async {
            tester.view.physicalSize = Size(width * 2, 5600);
            tester.view.devicePixelRatio = 2;
            addTearDown(tester.view.reset);
            final controller = LearningHubController(
              repository: _Hub(list: _institutes()),
              learning: LearningController(_Courses(_catalogue())),
              assess: _Assess(assessments: _programmes(6), mocks: _subjectsOf(6)),
              study: _Study(),
            );
            addTearDown(controller.dispose);
            await tester.pumpWidget(
              MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: buildAppTheme(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Provider<NotificationsRepository>.value(
                  value: DemoNotificationsRepository(),
                  child: LearningHubScreen(onBack: () {}, controller: controller, routes: _stubRoutes),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(layoutProblems().where((p) => p.startsWith('clipped')), isEmpty);
          },
        );
      }
    }
  });

  group('built into the app', () {
    Widget shellWith(LearningHubController controller) => _app(
      AppShell(
        home: const Scaffold(body: Center(child: Text('the feed'))),
        learning: Builder(
          builder: (ctx) =>
              LearningHubScreen(onBack: () => AppShell.selectHome(ctx), controller: controller, routes: _stubRoutes),
        ),
      ),
    );

    LearningHubController fakeHub() => LearningHubController(
      repository: _Hub(list: _institutes()),
      learning: LearningController(_Courses(_catalogue())),
      assess: _Assess(),
      study: _Study(),
    );

    testWidgets('in the shell, a door screen sits over it with the Learning tab lit, and Home on its bar leaves it', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(780, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final controller = fakeHub();
      addTearDown(controller.dispose);
      await tester.pumpWidget(shellWith(controller));
      await tester.tap(find.descendant(of: find.byType(IcrBottomNav), matching: find.text('Learning')));
      await tester.pumpAndSettle();
      expect(find.byType(LearningHubScreen), findsOneWidget, reason: 'the Learning tab opens on the hub');
      expect(find.byType(CatalogueRail), findsOneWidget);

      await tapDoor(tester, LearningDoor.flashCards);
      expect(find.text('stub:flashCards'), findsOneWidget);
      final bar = tester.widget<IcrBottomNav>(find.byType(IcrBottomNav).hitTestable());
      expect(bar.current, AppTab.learning, reason: 'the pushed screen keeps the bar, lit on Learning');

      await tester.tap(find.descendant(of: find.byType(IcrBottomNav).hitTestable(), matching: find.text('Home')));
      await tester.pumpAndSettle();
      expect(find.text('stub:flashCards'), findsNothing);
      expect(find.text('the feed'), findsOneWidget);
    });

    testWidgets("the phone's Back goes to Home in the shell (the header has no arrow)", (tester) async {
      tester.view.physicalSize = const Size(780, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final controller = fakeHub();
      addTearDown(controller.dispose);
      await tester.pumpWidget(shellWith(controller));
      await tester.tap(find.descendant(of: find.byType(IcrBottomNav), matching: find.text('Learning')));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('the feed'), findsOneWidget);
    });

    testWidgets('mounted as the app mounts it, the hub builds its own controller from the API', (tester) async {
      tester.view.physicalSize = const Size(780, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final api = _Api({
        'GET /learning/courses': (_) => [
          {
            'id': 'c1',
            'kind': 'DEVELOPMENT',
            'code': 'CALS',
            'title': 'Certificate in Advanced Leadership Skills',
            'level': 'LEADERSHIP',
            'provider': {'id': 'p1', 'name': 'ICR Institute', 'slug': 'icr'},
          },
        ],
        'GET /learning/me/enrollments': (_) => [
          {'id': 'e1', 'courseId': 'c1', 'status': 'CONFIRMED'},
        ],
        'GET /learning/providers': (_) => [
          {'id': 'p1', 'name': 'ICR Institute', 'slug': 'icr', 'courseCount': 1},
        ],
        'GET /learning/me/attempts': (_) => [
          {'id': 'a1'},
          {'id': 'a2'},
        ],
        'GET /learning/me/certificates': (_) => <Object>[],
        'GET /notifications/unread-count': (_) => {'unread': 5},
      });
      await tester.pumpWidget(
        _app(
          Provider<ApiClient>.value(
            value: _client(api),
            child: LearningHubScreen(onBack: () => backs++, routes: _stubRoutes),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CatalogueRail), findsOneWidget);
      // The course is the institute's (even ICR's own institute is one): the institute under Partner Courses,
      // nothing under ICR Certifications, as the website files them.
      expect(
        find.byKey(const ValueKey('institute-p1')),
        findsOneWidget,
        reason: 'the institute, under Partner Courses',
      );
      expect(find.byKey(const ValueKey('cert-c1')), findsNothing);
      expect(find.bySemanticsLabel('Notifications, 5 unread'), findsOneWidget);
      expect(
        api.calls.where((c) => c == 'GET /learning/courses'),
        hasLength(2),
        reason: 'the catalogue once, and the assessment programmes once (?kind=ASSESSMENT)',
      );
    });

    testWidgets('on the sample content (FEED_SOURCE=demo) the hub has its catalogue, programmes, decks and cards', (
      tester,
    ) async {
      final hub = LearningHubController(
        repository: DemoLearningHubRepository(),
        learning: LearningController(DemoLearningRepository()),
        assess: DemoAssessRepository(),
        study: DemoStudyRepository(),
      );
      await pumpHubWith(tester, hub);
      expect(find.byType(CatalogueRail), findsOneWidget);
      expect(find.byKey(const ValueKey('deck-capital-planning')), findsOneWidget);
      expect(find.text('Capital Planning'), findsWidgets, reason: 'the programme card and the deck tile');
      expect(find.byType(LearnCard), findsWidgets);
      expect(find.byType(MasterclassBanner), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('the API source', () {
    ApiLearningHubRepository repo(_Api api) => ApiLearningHubRepository(api: _client(api));

    test(
      'institutes: name, slug, summary, an absolute logo, the company logo as a fallback, verified and counts',
      () async {
        final api = _Api({
          'GET /learning/providers': (_) => [
            {
              'id': 'p1',
              'name': ' Vinfraa Institute ',
              'slug': 'vinfraa',
              'summary': 'Facility management.',
              'logoUrl': '/uploads/vinfraa.png',
              'website': 'https://vinfraa.test',
              'verified': true,
              'courseCount': 3,
              'company': {'id': 'c', 'name': 'Vinfraa', 'logoUrl': '/uploads/company.png'},
            },
            {
              'id': 'p2',
              'name': 'Linked Academy',
              'slug': 'linked',
              'logoUrl': null,
              'company': {'id': 'c2', 'name': 'Linked', 'logoUrl': '/uploads/linked-company.png'},
              'courseCount': 0,
            },
            {'id': 'p3', 'name': '   ', 'slug': 'blank'},
            {'id': 'p4', 'name': 'Bare Institute'},
          ],
        });
        final rows = await repo(api).institutes();
        expect(rows.map((i) => i.name), [
          'Vinfraa Institute',
          'Linked Academy',
          'Bare Institute',
        ], reason: 'a nameless row is dropped');
        final first = rows.first;
        expect(first.slug, 'vinfraa');
        expect(first.summary, 'Facility management.');
        expect(first.logo?.url, 'http://api.test/uploads/vinfraa.png', reason: 'uploads live beside /api/v1');
        expect(first.website, 'https://vinfraa.test');
        expect(first.verified, isTrue);
        expect(first.courseCount, 3);
        expect(rows[1].logo?.url, 'http://api.test/uploads/linked-company.png');
        expect(rows[2].logo, isNull);
        expect(rows[2].verified, isFalse);
        expect(rows[2].courseCount, 0);
        expect(rows[2].courseCountLabel, 'No courses published yet');
        expect(first.courseCountLabel, '3 courses');
        expect(first.initials, 'VI');
      },
    );

    test('institutes: a failed read is an ApiError with the API’s sentence', () async {
      final api = _Api({'GET /learning/providers': (_) => (500, '{"message":"Boom"}')});
      expect(repo(api).institutes(), throwsA(isA<ApiError>().having((e) => e.message, 'message', 'Boom')));
    });

    test('myLearning counts attempts and certificates', () async {
      final api = _Api({
        'GET /learning/me/attempts': (_) => [
          {'id': 'a1'},
          {'id': 'a2'},
          {'id': 'a3'},
        ],
        'GET /learning/me/certificates': (_) => [
          {'id': 'x'},
        ],
      });
      final mine = await repo(api).myLearning();
      expect(mine.attempts, 3);
      expect(mine.certificates, 1);
    });

    test('myLearning: one refused read leaves the other count intact', () async {
      final api = _Api({
        'GET /learning/me/attempts': (_) => (403, '{"message":"No"}'),
        'GET /learning/me/certificates': (_) => <Object>[],
      });
      final mine = await repo(api).myLearning();
      expect(mine.attempts, isNull);
      expect(mine.certificates, 0);
    });

    test('enquireInstitute posts the member’s name and email with the message to the institute’s slug', () async {
      final api = _Api({
        'GET /auth/me': (_) => {
          'user': {'firstName': 'Bharat', 'lastName': 'Buyer', 'email': 'buyer@icr.dev'},
        },
        'POST /learning/providers/vinfraa/enquire': (_) => {'ok': true},
      });
      await repo(api).enquireInstitute(_vinfraaInstitute, message: '  When is the next intake?  ');
      final i = api.calls.indexOf('POST /learning/providers/vinfraa/enquire');
      expect(i, greaterThan(-1));
      expect(api.bodies[i], {'name': 'Bharat Buyer', 'email': 'buyer@icr.dev', 'message': 'When is the next intake?'});
    });

    test(
      'enquireInstitute: the API’s refusal comes back as its sentence; an institute with no slug is refused',
      () async {
        final api = _Api({
          'GET /auth/me': (_) => {'firstName': 'Bharat', 'email': 'buyer@icr.dev'},
          'POST /learning/providers/vinfraa/enquire': (_) => (429, '{"message":"Slow down"}'),
        });
        await expectLater(
          repo(api).enquireInstitute(_vinfraaInstitute, message: 'A question for you'),
          throwsA(isA<ApiError>().having((e) => e.message, 'message', contains('Too many requests'))),
        );
        await expectLater(
          repo(api).enquireInstitute(
            const Institute(id: 'x', name: 'No Slug'),
            message: 'A question for you',
          ),
          throwsA(isA<ApiError>()),
        );
      },
    );
  });

  group('the demo source', () {
    test('holds two institutes and some counts, and takes an enquiry', () async {
      final demo = DemoLearningHubRepository();
      expect((await demo.institutes()).length, 2);
      final mine = await demo.myLearning();
      expect(mine.attempts, 3);
      expect(mine.certificates, 1);
      await demo.enquireInstitute(
        const Institute(id: 'x', name: 'X', slug: 'x'),
        message: 'Hello there, X',
      );
      expect(demo.enquiries, ['x: Hello there, X']);
    });
  });
}
