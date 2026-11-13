import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/auth/token_store.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/core/widgets/buttons.dart';
import 'package:icr_mobile/core/widgets/detail_sheet.dart';
import 'package:icr_mobile/features/learning/api_learning_repository.dart';
import 'package:icr_mobile/features/learning/course_sheet.dart';
import 'package:icr_mobile/features/learning/course_sheet_controller.dart';
import 'package:icr_mobile/features/learning/demo_learning_repository.dart';
import 'package:icr_mobile/features/learning/learning_controller.dart';
import 'package:icr_mobile/features/learning/learning_format.dart';
import 'package:icr_mobile/features/learning/learning_models.dart';
import 'package:icr_mobile/features/learning/learning_repository.dart';
import 'package:icr_mobile/features/learning/learning_screen.dart';
import 'package:icr_mobile/features/learning/learning_styles.dart';
import 'package:icr_mobile/features/learning/widgets/course_bottom_bar.dart';
import 'package:icr_mobile/features/learning/widgets/course_card.dart';
import 'package:icr_mobile/features/learning/widgets/cover_pill.dart';
import 'package:icr_mobile/features/learning/widgets/run_tile.dart';
import 'package:icr_mobile/features/learning_hub/learning_doors.dart';
import 'package:icr_mobile/features/library/pdf_engine.dart';
import 'package:icr_mobile/features/library/preview_runner.dart';
import 'package:icr_mobile/features/library/widgets/document_viewer_screen.dart';
import 'package:icr_mobile/features/notifications/demo_notifications_repository.dart';
import 'package:icr_mobile/features/notifications/notifications_repository.dart';
import 'package:icr_mobile/features/notifications/notifications_screen.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import 'helpers/community_fakes.dart';
import 'helpers/fonts.dart';
import 'package:icr_mobile/features/payments/payment_screen.dart';
import 'package:icr_mobile/features/payments/checkout_start.dart';
import 'package:icr_mobile/features/learning/course_checkout.dart';

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
  final List<Map<String, dynamic>> queries = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final key = '${options.method} ${options.path}';
    calls.add(key);
    bodies.add(options.data);
    queries.add(options.queryParameters);
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

// Noon UTC, as the seed writes dates, so the calendar day reads the same in every time zone.
const _batch = {
  'id': 'b1',
  'courseId': 'c1',
  'code': 'CALS-202408',
  'mode': 'IN_PERSON',
  'status': 'OPEN',
  'startsAt': '2024-08-23T12:00:00.000Z',
  'endsAt': '2024-08-27T12:00:00.000Z',
  'location': 'Riyadh, KSA',
  'seatsCapacity': 20,
  'seatsRemaining': 3,
  'full': false,
  'waitlistEnabled': true,
  'priceAmount': null,
  'priceCurrency': 'INR',
  'enrolmentSpecialist': {
    'id': 't1',
    'name': 'Bushra A.',
    'title': 'Specialist – Program Enrollment',
    'photoUrl': '/uploads/bushra.jpg',
  },
};

const _courseRow = {
  'id': 'c1',
  'kind': 'DEVELOPMENT',
  'code': 'CALS',
  'slug': 'certificate-in-advanced-leadership-skills',
  'title': 'Certificate in Advanced Leadership Skills',
  'summary': 'Future-ready insights.',
  'description': '<p>Leadership can be learnt.</p><p>Second paragraph.</p>',
  'level': 'LEADERSHIP',
  'access': 'PAID',
  'priceAmount': 1180000,
  'priceCurrency': 'INR',
  'durationLabel': '5 days · 35 hours',
  'deliveryMode': 'Face to face and live virtual training',
  'cpdCredits': 35,
  'certificateEnabled': true,
  'enrollmentOpen': true,
  'imageUrl': '/uploads/cals.jpg',
  'brochureUrl': '/uploads/cals.pdf',
  'audience': ['Executive Management', 'VP Operations'],
  'learningOutcomes': ['Self-evaluate your leadership style.'],
  'prerequisites': [],
  'provider': {
    'id': 'p1',
    'name': 'Vinfraa Institute',
    'slug': 'vinfraa',
    'logoUrl': '/uploads/vinfraa.png',
    'verified': true,
  },
  'batches': [_batch],
  'modules': [
    {
      'id': 'm1',
      'title': 'Leadership Intelligence',
      'topics': ['Leadership in a Disruptive World'],
      'sortOrder': 0,
    },
  ],
};

ApiLearningRepository _repo(_Api api) {
  final client = ApiClient(tokens: _NoTokens(), baseUrl: 'http://api.test/api/v1');
  client.dio.httpClientAdapter = api;
  return ApiLearningRepository(api: client);
}

// --- fixtures for the screens -----------------------------------------------------------------

const _provider = CourseProvider(id: 'p1', name: 'Vinfraa Institute', verified: true);

CourseRun _run(
  String id,
  DeliveryMode mode,
  DateTime start, {
  String? location,
  int capacity = 20,
  int remaining = 20,
  bool full = false,
}) => CourseRun(
  id: id,
  courseId: 'c-RICH',
  code: 'C-$id',
  mode: mode,
  startsAt: start,
  endsAt: start.add(const Duration(days: 4)),
  location: location,
  seatsCapacity: capacity,
  seatsRemaining: remaining,
  full: full,
);

/// A course with four face-to-face runs (one behind "See More Dates") and two virtual ones.
Course _rich({
  String code = 'RICH',
  CourseProvider? provider = _provider,
  int? price,
  String? brochure = 'https://files.test/brochure.pdf',
  MyEnrolment? enrolment,
  bool certificate = true,
  int cpd = 0,
  String? title,
}) => Course(
  id: 'c-$code',
  code: code,
  title: title ?? 'Rich course $code',
  summary: 'A summary.',
  description: '${'First paragraph of the overview. ' * 12}\n\nSecond paragraph that only shows when unfolded.',
  level: 'Leadership',
  provider: provider,
  badge: coverBadge('LEADERSHIP', CourseKind.development, certificateEnabled: certificate),
  priceAmount: price,
  durationLabel: '5 days · 35 hours',
  certificateEnabled: certificate,
  cpdCredits: cpd,
  brochureUrl: brochure,
  runs: [
    _run('r1', DeliveryMode.inPerson, DateTime(2027, 8, 23), location: 'Riyadh, KSA'),
    _run('r2', DeliveryMode.inPerson, DateTime(2027, 9, 14), location: 'London, UK'),
    _run('r3', DeliveryMode.inPerson, DateTime(2027, 10, 5), location: 'Dubai, UAE', capacity: 5, remaining: 1),
    _run('r4', DeliveryMode.inPerson, DateTime(2027, 11, 15), location: 'Singapore, SG'),
    _run('v1', DeliveryMode.virtual, DateTime(2027, 11, 2), location: 'Live online'),
    _run('v2', DeliveryMode.virtual, DateTime(2027, 12, 7), location: 'Live online'),
  ],
  modules: const [
    CourseModule(id: 'm1', title: 'Leadership Intelligence', lessons: ['Lesson A', 'Lesson B', 'Lesson C']),
    CourseModule(id: 'm2', title: 'Personal Mastery'),
  ],
  outcomes: const ['Outcome one.', 'Outcome two.'],
  audience: const ['Executive Management', 'VP Operations'],
  aboutCertificate: aboutCertificateText(provider: provider, certificateEnabled: certificate),
  contact: const CourseContact(name: 'Bushra A.', role: 'specialist – program enrollment'),
  enrolment: enrolment,
  detailLoaded: true,
);

Course _plain(String code, String title, {CourseKind kind = CourseKind.development, MyEnrolment? enrolment}) => Course(
  id: 'c-$code',
  code: code,
  title: title,
  kind: kind,
  level: 'Foundation',
  enrolment: enrolment,
  detailLoaded: true,
);

CourseReview _review(int n, {String? role}) =>
    CourseReview(id: 'rv$n', body: 'Review body number $n, long enough to read.', author: 'Reviewer $n', role: role);

/// The repository the screens run against in widget tests: what it is told to
/// hold, and a record of everything the controls asked of it.
class _Fake implements LearningRepository {
  _Fake({required this.catalogue, this.reviewList = const CourseReviews(), this.enrolError, this.listError});

  final List<Course> catalogue;
  CourseReviews reviewList;
  List<MyEnrolment> mine = [];
  String? enrolError;
  String? listError;

  /// What taking a place back answers with: a refusal's sentence, or null to allow it.
  String? withdrawError;

  int courseCalls = 0;
  final enrols = <(String, String?)>[];
  final withdrawals = <String>[];
  final enquiries = <({String code, String message, EnquiryKind kind, String? company, int? headcount})>[];
  final brochureLeads = <(String code, BrochureLead lead, BrochureIntent intent)>[];
  String? brochureRefusal;
  List<int>? brochurePdf = [0x25, 0x50, 0x44, 0x46];

  MyEnrolment? _mineFor(Course c) {
    for (final m in mine) {
      if (m.courseId == c.id) return m;
    }
    return null;
  }

  @override
  Future<void> withdraw(Course course) async {
    withdrawals.add(course.code);
    if (withdrawError != null) throw ApiError(withdrawError!, statusCode: 403);
    mine = [
      for (final m in mine)
        if (m.courseId != course.id) m,
    ];
  }

  @override
  Future<List<Course>> courses() async {
    courseCalls++;
    if (listError != null) throw ApiError(listError!, statusCode: 500);
    return [for (final c in catalogue) c.copyWith(enrolment: _mineFor(c))];
  }

  @override
  Future<Course> detail(Course course) async =>
      catalogue.firstWhere((c) => c.id == course.id).copyWith(enrolment: _mineFor(course));

  @override
  Future<List<MyEnrolment>> myEnrolments() async => mine;

  @override
  Future<CourseReviews> reviews(Course course) async => reviewList;

  @override
  Future<MyEnrolment> enrol(Course course, {CourseRun? run}) async {
    enrols.add((course.code, run?.id));
    if (enrolError != null) throw ApiError(enrolError!, statusCode: 400);
    final placed = MyEnrolment(
      id: 'e1',
      courseId: course.id,
      runId: run?.id,
      status: EnrolmentStatus.pending,
      startsAt: run?.startsAt,
      endsAt: run?.endsAt,
      location: run?.location,
    );
    mine = [...mine.where((m) => m.courseId != course.id), placed];
    return placed;
  }

  @override
  Future<void> enquire(
    Course course, {
    required String message,
    EnquiryKind kind = EnquiryKind.question,
    String? company,
    int? headcount,
  }) async {
    enquiries.add((code: course.code, message: message, kind: kind, company: company, headcount: headcount));
  }

  /// The account read behind the brochure form fails (a phone with a stale session, a slow network).
  bool contactFails = false;

  @override
  Future<BrochureLead> brochureContact() async {
    if (contactFails) throw ApiError('Session expired.', statusCode: 401);
    return const BrochureLead(name: 'Bharat Buyer', email: 'buyer@icr.dev', phone: '+91 98450 12345');
  }

  @override
  Future<void> requestBrochure(Course course, BrochureLead lead, {required BrochureIntent intent}) async {
    if (brochureRefusal != null) throw ApiError(brochureRefusal!, statusCode: 400);
    brochureLeads.add((course.code, lead, intent));
  }

  @override
  Future<List<int>> brochureBytes(Course course) async {
    final pdf = brochurePdf;
    if (pdf == null) throw UnsupportedError('no brochure bytes');
    return pdf;
  }

  @override
  Future<int> unreadNotifications() async => 2;

  @override
  Uri link(Course course) => Uri.parse('https://icr.org.in/learning/professional-development/${course.code}');

  @override
  Uri checkoutLink(Course course, CourseRun? run) =>
      Uri.parse('https://icr.org.in/learning/professional-development/${course.code}#enrol');
}

/// Records what the app hands to the browser or the mail app.
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

/// The bell opens the app's notifications, which read their repository from above the screen.
Widget _app(Widget home) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: buildAppTheme(),
  home: Provider<NotificationsRepository>.value(value: DemoNotificationsRepository(), child: home),
);

/// Stands where another builder's Learning screen goes: says which one it is and has a Back.
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

/// Routes whose screens are stubs, so a chip can be tapped without building a screen that needs the API.
const _stubRoutes = LearningRoutes(
  assessment: _assessment,
  mockTests: _mockTests,
  flashCards: _flashCards,
  knowledgeCenter: _knowledgeCenter,
  myAttempts: _myAttempts,
  certificates: _certificates,
);
Widget _assessment(BuildContext c, VoidCallback back) => _Stub('assessment', back);
Widget _mockTests(BuildContext c, VoidCallback back) => _Stub('mockTests', back);
Widget _flashCards(BuildContext c, VoidCallback back) => _Stub('flashCards', back);
Widget _knowledgeCenter(BuildContext c, VoidCallback back) => _Stub('knowledgeCenter', back);
Widget _myAttempts(BuildContext c, VoidCallback back) => _Stub('myAttempts', back);
Widget _certificates(BuildContext c, VoidCallback back) => _Stub('certificates', back);

void main() {
  setUpAll(loadAppFonts);

  group('formatting', () {
    test("a run's dates read as the design's tiles", () {
      expect(runDates(DateTime(2024, 8, 23), DateTime(2024, 8, 27)), 'Aug 23 - 27, 2024');
      expect(runDates(DateTime(2024, 8, 30), DateTime(2024, 9, 3)), 'Aug 30 - Sep 03, 2024');
      expect(runDates(DateTime(2024, 12, 30), DateTime(2025, 1, 3)), 'Dec 30, 2024 - Jan 03, 2025');
      expect(runDates(DateTime(2024, 10, 5), null), 'Oct 05, 2024');
    });

    test("the pinned bar's words are in Title Case, small words kept lower-case", () {
      expect(titleCase('ENROL NOW'), 'Enrol Now');
      expect(titleCase('ENROLMENT CLOSED'), 'Enrolment Closed');
      expect(titleCase('Place requested'), 'Place Requested');
      expect(titleCase('On the waitlist'), 'On the Waitlist');
    });

    test('a price reads in rupees from paise, and Free for nothing', () {
      expect(priceLabel(1180000), '₹11,800');
      expect(priceLabel(58882), '₹588.82');
      expect(priceLabel(118000000), '₹11,80,000');
      expect(priceLabel(null), 'Free');
      expect(priceLabel(0), 'Free');
      expect(priceLabel(120000, 'AED'), 'AED 1,200');
    });

    test('the schedule names the year of the shown runs', () {
      final repo = DemoLearningRepository();
      expect(scheduleLabel(repo.course.runs), '2024 Schedule');
      expect(scheduleLabel(const []), isNull);
    });

    test('the cover pill reads from the course: certificate first, then level', () {
      // A certificate-issuing course: premium at the senior levels, plain below them.
      expect(coverBadge('LEADERSHIP', CourseKind.development, certificateEnabled: true), 'PREMIUM CERTIFICATION');
      expect(coverBadge('ADVANCED', CourseKind.development, certificateEnabled: true), 'PREMIUM CERTIFICATION');
      expect(coverBadge('SPECIALIST', CourseKind.development, certificateEnabled: true), 'PREMIUM CERTIFICATION');
      expect(coverBadge('FOUNDATION', CourseKind.development, certificateEnabled: true), 'CERTIFICATION');
      expect(coverBadge('INTERMEDIATE', CourseKind.development, certificateEnabled: true), 'CERTIFICATION');
      expect(coverBadge(null, CourseKind.development, certificateEnabled: true), 'CERTIFICATION');
      // Otherwise its level and what it is.
      expect(coverBadge('LEADERSHIP', CourseKind.development), 'LEADERSHIP COURSE');
      expect(coverBadge('ADVANCED', CourseKind.assessment), 'ADVANCED CERTIFICATION');
      expect(coverBadge(null, CourseKind.development), isNull);
      expect(coverBadge(null, CourseKind.assessment), 'CERTIFICATION');
    });

    test('the certificate paragraph says only what the record holds', () {
      final text = aboutCertificateText(
        provider: _provider,
        cpdCredits: 35,
        certificateEnabled: true,
        deliveryMode: 'Face to face and live virtual training',
      );
      expect(text, contains('delivered through ICR as face to face and live virtual training'));
      expect(text, contains('awarded by Vinfraa Institute, a partner institute ICR has verified.'));
      expect(text, contains('participants receive a certificate'));
      expect(text, contains('logs 35 CPD credits'));
      expect(aboutCertificateText(cpdCredits: 1), contains('logs 1 CPD credit on'));
      expect(
        aboutCertificateText(certificateEnabled: true),
        startsWith('This programme is delivered and awarded by ICR Institute.'),
      );
      expect(aboutCertificateText(provider: _provider), isNull, reason: 'no certificate and no CPD: nothing to say');
    });

    test('a row says when and how long, or what the course is', () {
      expect(courseMeta(_rich()), '5 days · 35 hours • In person');
      final programme = _plain('CP', 'Capital Planning', kind: CourseKind.assessment);
      expect(courseMeta(programme), 'Foundation • Certification programme');
      expect(courseMetaTimed(programme), isFalse);
      expect(courseMeta(_plain('X', 'X')), 'Foundation • Course');
      final held = MyEnrolment(
        id: 'e',
        courseId: 'c',
        status: EnrolmentStatus.confirmed,
        startsAt: DateTime(2027, 8, 23),
        endsAt: DateTime(2027, 8, 27),
        location: 'Riyadh, KSA',
      );
      expect(enrolmentMeta(held), 'Aug 23 - 27, 2027 • Riyadh, KSA');
      expect(enrolmentMeta(const MyEnrolment(id: 'e', courseId: 'c', status: EnrolmentStatus.pending)), isNull);
    });

    test('availability follows the seats left', () {
      CourseRun run({int? remaining, bool full = false}) => CourseRun(
        id: 'r',
        courseId: 'c',
        code: 'X',
        mode: DeliveryMode.inPerson,
        startsAt: DateTime(2024, 8, 23),
        seatsCapacity: 20,
        seatsRemaining: remaining,
        full: full,
      );
      expect(run(remaining: 12).availability, RunAvailability.open);
      expect(run(remaining: 3).availability, RunAvailability.limited);
      expect(run(remaining: 0, full: true).availability, RunAvailability.full);
    });

    test("a tile's corner word is the member's own place first, then the seats", () {
      final run = _run('r', DeliveryMode.inPerson, DateTime(2027, 8, 23), remaining: 3);
      final flagged = CourseRun(
        id: 'r',
        courseId: 'c',
        code: 'X',
        mode: DeliveryMode.inPerson,
        startsAt: DateTime(2027, 8, 23),
        confirmed: true,
      );
      RunTile tile(CourseRun r, EnrolmentStatus? mine) => RunTile(run: r, selected: false, onTap: () {}, mine: mine);
      expect(tile(run, null).status.$1, 'Limited');
      expect(tile(run, EnrolmentStatus.confirmed).status.$1, 'CONFIRMED');
      expect(tile(run, EnrolmentStatus.completed).status.$1, 'CONFIRMED');
      expect(tile(run, EnrolmentStatus.pending).status.$1, 'REQUESTED');
      expect(tile(run, EnrolmentStatus.waitlisted).status.$1, 'WAITLISTED');
      expect(tile(flagged, null).status.$1, 'CONFIRMED', reason: "the demo's flagged run");
    });
  });

  group('the API source', () {
    test('maps a course with its runs, syllabus, provider, certificate and specialist', () async {
      final api = _Api({
        'GET /learning/me/enrollments': (_) => [
          {
            'id': 'e1',
            'courseId': 'c1',
            'batchId': 'b1',
            'status': 'CONFIRMED',
            'batch': {
              'id': 'b1',
              'startsAt': '2024-08-23T12:00:00.000Z',
              'endsAt': '2024-08-27T12:00:00.000Z',
              'location': 'Riyadh, KSA',
            },
          },
        ],
        'GET /learning/courses': (_) => [_courseRow],
        'GET /learning/courses/CALS': (_) => _courseRow,
      });
      final repo = _repo(api);
      final rows = await repo.courses();
      final row = rows.single;
      expect(row.title, 'Certificate in Advanced Leadership Skills');
      expect(row.kind, CourseKind.development);
      expect(row.level, 'Leadership');
      expect(row.certificateEnabled, isTrue);
      expect(row.badge, 'PREMIUM CERTIFICATION', reason: 'a certificate-issuing course at the Leadership level');
      expect(row.cover?.url, 'http://api.test/uploads/cals.jpg');
      expect(row.brochureUrl, 'http://api.test/uploads/cals.pdf');
      expect(row.provider?.name, 'Vinfraa Institute');
      expect(row.provider?.verified, isTrue);
      expect(row.priceAmount, 1180000);
      expect(row.enrolled, isTrue);
      expect(row.enrolment?.status, EnrolmentStatus.confirmed);
      expect(row.enrolment?.runId, 'b1');
      expect(row.enrolment?.location, 'Riyadh, KSA', reason: "the enrolment carries its run's place and dates");
      expect(enrolmentMeta(row.enrolment), 'Aug 23 - 27, 2024 • Riyadh, KSA');
      expect(courseMeta(row), '5 days · 35 hours • In person');

      final course = await repo.detail(row);
      expect(course.detailLoaded, isTrue);
      expect(course.runs.single.location, 'Riyadh, KSA');
      expect(course.runs.single.mode, DeliveryMode.inPerson);
      expect(course.runs.single.availability, RunAvailability.limited);
      expect(course.runs.single.confirmed, isFalse, reason: 'the API has no "confirmed to go ahead"');
      expect(course.contact?.name, 'Bushra A.');
      expect(course.contact?.photo?.url, 'http://api.test/uploads/bushra.jpg');
      expect(course.contact?.email, isNull, reason: "the API never publishes a trainer's contact");
      expect(course.contact?.whatsapp, isNull);
      expect(course.modules.single.lessons, ['Leadership in a Disruptive World']);
      expect(course.certificateBadges.single.url, 'http://api.test/uploads/vinfraa.png');
      expect(course.aboutCertificate, contains('awarded by Vinfraa Institute'));
      expect(course.aboutCertificate, contains('35 CPD credits'));
      expect(course.aboutCertificate, contains('as face to face and live virtual training'));
      expect(plainText(course.description!), 'Leadership can be learnt.\n\nSecond paragraph.');
      expect(course.isPaid(course.runs.single), isTrue);
    });

    test('a course that issues no certificate and logs no CPD has no certificate section', () async {
      final api = _Api({
        'GET /learning/me/enrollments': (_) => [],
        'GET /learning/courses/PLAIN': (_) => {
          ..._courseRow,
          'code': 'PLAIN',
          'certificateEnabled': false,
          'cpdCredits': 0,
        },
      });
      final course = await _repo(api).detail(_plain('PLAIN', 'Plain'));
      expect(course.aboutCertificate, isNull);
      expect(course.badge, 'LEADERSHIP COURSE', reason: 'no certificate: the level and what it is');
    });

    test('a free place is taken through the enrol endpoint with the run it was taken on', () async {
      final api = _Api({
        'GET /learning/me/enrollments': (_) => [],
        'POST /learning/courses/CALS/enroll': (_) => {
          'enrollment': {'id': 'e2', 'courseId': 'c1', 'batchId': 'b1', 'status': 'PENDING'},
          'seats': {'capacity': 20, 'taken': 18, 'remaining': 2, 'full': false, 'waitlisted': 0},
        },
      });
      final repo = _repo(api);
      final course = DemoLearningRepository().course;
      final mine = await repo.enrol(course, run: course.runs.first);
      expect(mine.status, EnrolmentStatus.pending);
      expect(mine.runId, 'b1');
      expect(mine.location, 'Riyadh, KSA');
      expect(api.bodies.last, {'batchId': 'demo-run-1'});
    });

    test('a place is taken back through the withdraw endpoint, by the course id', () async {
      final course = DemoLearningRepository().course;
      final api = _Api({
        'GET /learning/me/enrollments': (_) => [
          {'id': 'e1', 'courseId': course.id, 'batchId': 'b1', 'status': 'PENDING'},
        ],
        'DELETE /learning/courses/${course.id}/enroll': (_) => {'id': 'e1', 'status': 'CANCELLED'},
      });
      final repo = _repo(api);
      expect((await repo.myEnrolments()).map((m) => m.courseId), [course.id]);
      await repo.withdraw(course);
      expect(api.calls.last, 'DELETE /learning/courses/${course.id}/enroll');
    });

    test('a paid place is refused by the API and the sentence reaches the caller', () async {
      final course = DemoLearningRepository().course;
      final api = _Api({
        'DELETE /learning/courses/${course.id}/enroll': (_) => (
          403,
          '{"message":"Your place is paid for. To withdraw, contact ICR support, who will arrange any refund."}',
        ),
      });
      final repo = _repo(api);
      await expectLater(
        repo.withdraw(course),
        throwsA(isA<ApiError>().having((e) => e.message, 'message', startsWith('Your place is paid for.'))),
      );
    });

    test('the reviews are the published page, newest first, with the count of them all', () async {
      final api = _Api({
        'GET /learning/courses/CALS/reviews': (_) => {
          'data': [
            {
              'id': 'r1',
              'body': 'Very professional.',
              'rating': 5,
              'roleLabel': 'Facilities Manager',
              'author': {'id': 'u1', 'name': 'Charles Tuffour', 'avatarUrl': null},
            },
            {
              'id': 'r2',
              'body': 'Well structured.',
              'rating': 4,
              'roleLabel': null,
              'author': {'id': 'u2', 'name': 'Anjali Bhatt', 'avatarUrl': '/uploads/a.png'},
            },
          ],
          'meta': {'total': 41, 'page': 1, 'limit': 20},
        },
      });
      final page = await _repo(api).reviews(DemoLearningRepository().course);
      expect(page.total, 41);
      expect(page.items.map((r) => r.author), ['Charles Tuffour', 'Anjali Bhatt']);
      expect(page.items.first.role, 'Facilities Manager');
      expect(page.items.last.role, isNull);
      expect(page.items.last.photo?.url, 'http://api.test/uploads/a.png');
      expect(api.queries.last, {'page': 1, 'limit': ApiLearningRepository.reviewsPerPage});
    });

    test('a refused review list is an empty one, never an error on the sheet', () async {
      final page = await _repo(_Api({})).reviews(DemoLearningRepository().course);
      expect(page.items, isEmpty);
      expect(page.total, 0);
    });

    test("an enquiry carries the member's own name and email; an in-house one is a corporate lead", () async {
      final api = _Api({
        'GET /auth/me': (_) => {'firstName': 'Pooja', 'lastName': 'Professional', 'email': 'professional@icr.test'},
        'POST /learning/courses/CALS/enquire': (_) => {'ok': true},
      });
      final repo = _repo(api);
      final course = DemoLearningRepository().course;
      await repo.enquire(course, message: ' Which cities? ');
      expect(api.bodies.last, {
        'name': 'Pooja Professional',
        'email': 'professional@icr.test',
        'message': 'Which cities?',
      });
      await repo.enquire(
        course,
        message: 'In-house delivery request: 30 people.',
        kind: EnquiryKind.inHouse,
        company: ' Acme FM ',
        headcount: 30,
      );
      expect(api.bodies.last, {
        'name': 'Pooja Professional',
        'email': 'professional@icr.test',
        'message': 'In-house delivery request: 30 people.',
        'kind': 'CORPORATE',
        'company': 'Acme FM',
        'headcount': 30,
      });
      await repo.enquire(
        course,
        message: 'Date and location request: Pune in March.',
        kind: EnquiryKind.dateRequest,
        company: 'ignored',
      );
      expect(api.bodies.last, isNot(contains('kind')), reason: 'only an in-house request is a corporate lead');
      expect(api.bodies.last, isNot(contains('company')));
    });

    test('a paid place opens the website, and a full run is a free waitlist place', () {
      final repo = DemoLearningRepository();
      final paid = Course(id: 'p', code: 'P', title: 'Paid', priceAmount: 500000, runs: repo.course.runs);
      final sheet = CourseSheetController(repository: repo, seed: paid);
      expect(sheet.paidPlace, isTrue, reason: 'a paid course costs money whichever run is picked');
      final fullRun = CourseRun(
        id: 'f',
        courseId: 'p',
        code: 'F',
        mode: DeliveryMode.inPerson,
        startsAt: DateTime(2024, 8, 23),
        full: true,
        priceAmount: 500000,
      );
      final withFull = Course(id: 'p', code: 'P', title: 'Paid', priceAmount: 500000, runs: [fullRun]);
      final full = CourseSheetController(repository: repo, seed: withFull)..selectRun(fullRun);
      expect(full.paidPlace, isFalse);
      expect(full.ctaLabel, 'JOIN WAITLIST');
    });
  });

  group('the controllers', () {
    test('groups courses by kind, searches them, and rolls a refused place back', () async {
      final learning = LearningController(_Refusing(DemoLearningRepository()));
      await learning.start();
      expect(
        learning.sections.single.title,
        'ICR Certification Programmes',
        reason: 'the demo course has no awarding body',
      );
      learning.setSearch('nothing like this');
      expect(learning.sections, isEmpty);
      learning.setSearch('leadership');
      expect(learning.sections.single.courses.single.code, 'CALS');

      final course = learning.courses.single;
      final message = await learning.enrol(course, run: course.runs.first);
      expect(message, 'No places today.');
      expect(learning.find(course.id)!.enrolled, isFalse);
    });

    test('the search matches title, summary, code and awarding body; the API has no search to ask', () async {
      final fake = _Fake(
        catalogue: [
          _rich(code: 'AAA'),
          _plain('BBB', 'Colloboration'),
          _plain('CCC', 'Communication'),
          _plain('DDD', 'Capital Planning', kind: CourseKind.assessment),
        ],
      );
      final learning = LearningController(fake);
      await learning.start();
      // The website's /learning/professional-development: ICR's own taught courses, then the institutes'.
      expect(learning.sections.map((s) => s.title), [
        'ICR Certification Programmes',
        'Related Courses from Our Partners',
      ]);
      expect(learning.sections.first.courses.map((c) => c.code), ['BBB', 'CCC']);
      expect(learning.sections.last.courses.map((c) => c.code), ['AAA']);
      learning.setSearch('capital');
      expect(learning.sections, isEmpty, reason: 'a certification programme has Assess Your Knowledge, not this grid');
      learning.setSearch('icr');
      expect(learning.sections.single.courses.map((c) => c.code), ['BBB', 'CCC'], reason: "ICR's own, by ICR");
      learning.setSearch('collo');
      expect(learning.sections.single.courses.single.code, 'BBB');
      learning.setSearch('vinfraa');
      expect(learning.sections.single.courses.single.code, 'AAA', reason: 'by awarding body');
      learning.setSearch('ccc');
      expect(learning.sections.single.courses.single.code, 'CCC', reason: 'by code');
      learning.clearSearch();
      expect(learning.sections.expand((s) => s.courses), hasLength(3));
      expect(fake.courseCalls, 1, reason: 'narrowing never goes back to the API');
    });

    test("the My courses chip shows only the member's own places, and reads them afresh as it goes on", () async {
      final held = _plain('HELD', 'Held course');
      final fake = _Fake(
        catalogue: [
          _rich(code: 'AAA'),
          held,
          _plain('OTHER', 'Not mine'),
        ],
      );
      final learning = LearningController(fake);
      await learning.start();
      expect(learning.mine, isEmpty);
      learning.toggleMine();
      expect(learning.mineOnly, isTrue);
      expect(learning.sections, isEmpty, reason: 'no places yet');
      fake.mine = [
        MyEnrolment(
          id: 'e',
          courseId: held.id,
          status: EnrolmentStatus.confirmed,
          startsAt: DateTime(2027, 8, 23),
          location: 'Riyadh, KSA',
        ),
      ];
      learning.toggleMine(); // off
      learning.toggleMine(); // on again: reads the places afresh
      await Future<void>.delayed(Duration.zero);
      expect(fake.courseCalls, 3);
      final section = learning.sections.single;
      expect(section.title, 'ICR Programmes', reason: "the website's shelves file a place by who runs the course");
      expect(section.courses.single.code, 'HELD');
      learning.setSearch('zzz');
      expect(learning.sections, isEmpty, reason: 'the search narrows within My courses');
      learning.clearSearch();
      learning.toggleMine();
      expect(learning.sections.expand((s) => s.courses), hasLength(3));
    });

    test('the sheet picks the first scheduled tab and run, takes a place and tells the list', () async {
      final repo = DemoLearningRepository();
      final learning = LearningController(repo);
      await learning.start();
      final sheet = CourseSheetController(repository: repo, seed: learning.courses.single, onChanged: learning.update);
      await sheet.load();
      expect(sheet.mode, DeliveryMode.inPerson);
      expect(sheet.selectedRun?.location, 'Riyadh, KSA');
      expect(sheet.shownRuns.length, 3);
      expect(sheet.hasMoreRuns, isFalse);
      expect(sheet.review?.author, 'Charles Selasie Tuffour');
      expect(sheet.reviewTotal, 1);
      expect(sheet.ctaLabel, 'ENROL NOW');
      sheet.selectMode(DeliveryMode.virtual);
      expect(sheet.selectedRun, isNull);
      sheet.selectMode(DeliveryMode.inPerson);
      sheet.selectRun(sheet.course.runs[2]);
      final message = await sheet.enrol();
      expect(message, isNull);
      expect(sheet.course.enrolment?.status, EnrolmentStatus.confirmed);
      expect(sheet.course.enrolment?.runId, 'demo-run-3');
      expect(sheet.ctaLabel, 'ENROLLED');
      expect(learning.courses.single.enrolled, isTrue);
    });

    test(
      'the sheet filters the runs by tab, folds the fourth behind "See More Dates", and opens on a held run',
      () async {
        final fake = _Fake(catalogue: [_rich()]);
        final sheet = CourseSheetController(repository: fake, seed: fake.catalogue.single);
        await sheet.load();
        expect(sheet.mode, DeliveryMode.inPerson);
        expect(sheet.runsInMode.map((r) => r.id), ['r1', 'r2', 'r3', 'r4']);
        expect(sheet.shownRuns.map((r) => r.id), ['r1', 'r2', 'r3']);
        expect(sheet.hasMoreRuns, isTrue);
        sheet.toggleAllDates();
        expect(sheet.shownRuns.map((r) => r.id), ['r1', 'r2', 'r3', 'r4']);
        sheet.selectMode(DeliveryMode.virtual);
        expect(sheet.runsInMode.map((r) => r.id), ['v1', 'v2']);
        expect(sheet.allDates, isFalse, reason: 'a tab opens folded');
        expect(sheet.selectedRun?.id, 'v1', reason: 'and selects its first run');
        expect(sheet.hasMoreRuns, isFalse);

        // A member whose place is on the fourth face-to-face run opens on it, unfolded.
        final held = fake.catalogue.single.copyWith(
          enrolment: const MyEnrolment(id: 'e', courseId: 'c-RICH', runId: 'r4', status: EnrolmentStatus.confirmed),
        );
        final heldSheet = CourseSheetController(
          repository: _Fake(catalogue: [held]),
          seed: held,
        );
        await heldSheet.load();
        expect(heldSheet.selectedRun?.id, 'r4');
        expect(heldSheet.allDates, isTrue);
        expect(heldSheet.ctaLabel, 'ENROLLED');
        expect(heldSheet.canAct, isFalse);
      },
    );

    test('the reviews fold to the first until "see all" is pressed', () async {
      final fake = _Fake(
        catalogue: [_rich()],
        reviewList: CourseReviews(items: [_review(1), _review(2), _review(3)], total: 3),
      );
      final sheet = CourseSheetController(repository: fake, seed: fake.catalogue.single);
      await sheet.load();
      expect(sheet.reviews, hasLength(3));
      expect(sheet.review?.author, 'Reviewer 1');
      expect(sheet.allReviews, isFalse);
      sheet.toggleAllReviews();
      expect(sheet.allReviews, isTrue);
    });

    test('the sheet puts a refused place back', () async {
      final repo = _Refusing(DemoLearningRepository());
      final sheet = CourseSheetController(repository: repo, seed: DemoLearningRepository().course);
      await sheet.load();
      expect(await sheet.enrol(), 'No places today.');
      expect(sheet.course.enrolled, isFalse);
      expect(sheet.ctaLabel, 'ENROL NOW');
    });

    test('an enquiry passes its kind, company and headcount to the repository', () async {
      final fake = _Fake(catalogue: [_rich()]);
      final sheet = CourseSheetController(repository: fake, seed: fake.catalogue.single);
      await sheet.load();
      expect(sheet.canEnquire, isTrue);
      expect(
        await sheet.enquire('Hello there, friends', kind: EnquiryKind.inHouse, company: 'Acme', headcount: 12),
        isNull,
      );
      expect(fake.enquiries.single.kind, EnquiryKind.inHouse);
      expect(fake.enquiries.single.company, 'Acme');
      expect(fake.enquiries.single.headcount, 12);
      final own = CourseSheetController(repository: fake, seed: _rich(provider: null));
      expect(own.canEnquire, isFalse, reason: "ICR's own course has no institute to write to");
    });
  });

  group('the Learning tab', () {
    late _Launches launches;
    late int backs;

    setUp(() {
      launches = _Launches()..install();
      backs = 0;
    });
    tearDown(() => launches.remove());

    Future<_Fake> pumpTab(
      WidgetTester tester,
      _Fake fake, {
      Size size = const Size(780, 1688),
      String title = 'Learning',
      void Function(LearningController learning)? prepare,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final learning = LearningController(fake);
      prepare?.call(learning);
      await tester.pumpWidget(
        _app(
          ChangeNotifierProvider.value(
            value: learning,
            child: LearningScreen(onBack: () => backs++, title: title, routes: _stubRoutes),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return fake;
    }

    /// Two of ICR's own taught courses, a partner's, and a certification programme the grid leaves to Assess Your
    /// Knowledge.
    _Fake threeCourses() => _Fake(
      catalogue: [
        _rich(code: 'AAA'),
        _plain('BBB', 'Colloboration'),
        _plain('CCC', 'Communication'),
        _plain('DDD', 'Capital Planning', kind: CourseKind.assessment),
      ],
    );

    testWidgets("lists ICR's own courses, then the partners' under their own heading, as cards", (tester) async {
      await pumpTab(tester, threeCourses());
      expect(find.text('ICR Certification Programmes'), findsOneWidget);
      expect(find.text('Related Courses from Our Partners'), findsOneWidget);
      expect(find.text('Professional development'), findsNothing, reason: 'one heading for both read as ICR’s own');
      expect(find.text('Certification programmes'), findsNothing);
      expect(find.text('Capital Planning'), findsNothing, reason: 'the programme has its own door');
      expect(find.byType(CourseCard), findsNWidgets(3));
      expect(find.text('Rich course AAA'), findsOneWidget);
      expect(find.text('5 days · 35 hours • In person'), findsOneWidget);
      final icr = tester.getTopLeft(find.text('Colloboration')).dy;
      final partner = tester.getTopLeft(find.text('Rich course AAA')).dy;
      expect(icr, lessThan(partner), reason: "ICR's own come first");
    });

    testWidgets("Back goes back, the bell opens the app's notifications", (tester) async {
      await pumpTab(tester, threeCourses());
      await tester.tap(find.byIcon(Symbols.arrow_back));
      expect(backs, 1);
      await tester.tap(find.byIcon(LucideIcons.bell));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsScreen), findsOneWidget);
      expect(launches.urls, isEmpty, reason: 'the website is not opened');
    });

    testWidgets('the search narrows the list as you type and clears with its button', (tester) async {
      final fake = await pumpTab(tester, threeCourses());
      await tester.enterText(find.byType(TextField), 'collo');
      await tester.pump();
      expect(find.byType(CourseCard), findsOneWidget);
      expect(find.text('Colloboration'), findsOneWidget);
      expect(
        find.text('Related Courses from Our Partners'),
        findsNothing,
        reason: 'a heading with no row under it goes',
      );
      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pump();
      expect(find.text('No Courses Match'), findsOneWidget);
      await tester.tap(find.text('Clear Search'));
      await tester.pumpAndSettle();
      expect(find.byType(CourseCard), findsNWidgets(3));
      expect(fake.courseCalls, 1, reason: 'the API has no search; the loaded list is what narrows');
    });

    testWidgets('My courses shows the places the member holds; the catalogue is back when the hub turns it off', (
      tester,
    ) async {
      final fake = threeCourses();
      final aaa = fake.catalogue.first;
      fake.mine = [
        MyEnrolment(
          id: 'e',
          courseId: aaa.id,
          runId: 'r1',
          status: EnrolmentStatus.confirmed,
          startsAt: DateTime(2027, 8, 23),
          endsAt: DateTime(2027, 8, 27),
          location: 'Riyadh, KSA',
        ),
      ];
      await pumpTab(tester, fake);
      expect(find.text('Enrolled'), findsOneWidget, reason: 'the row says so in the catalogue too');
      // The hub turns My courses on and off; the chip that did is gone (owner, 7 Nov 2026).
      final learning = Provider.of<LearningController>(tester.element(find.byType(LearningScreen)), listen: false);
      learning.setMineOnly(true);
      await tester.pumpAndSettle();
      expect(find.byType(CourseCard), findsOneWidget);
      expect(find.text('Rich course AAA'), findsOneWidget);
      expect(find.text('Aug 23 - 27, 2027 • Riyadh, KSA'), findsOneWidget, reason: 'the run the place is on');
      expect(find.text('Professional development'), findsNothing);
      expect(find.text('My Courses'), findsNothing, reason: 'no chip; the shelf is named by who runs the course');
      expect(find.text('Partner Programmes'), findsNWidgets(2), reason: 'AAA is an institute\'s');
      learning.setMineOnly(false);
      await tester.pumpAndSettle();
      expect(find.byType(CourseCard), findsNWidgets(3));
    });

    testWidgets('My courses with no places says so and offers the catalogue', (tester) async {
      // The hub opens the screen on the member's own courses; there is no chip to toggle it (owner, 7 Nov 2026).
      await pumpTab(tester, threeCourses(), prepare: (l) => l.setMineOnly(true));
      expect(find.text('No Courses Yet'), findsOneWidget);
      await tester.tap(find.text('Browse Courses'));
      await tester.pumpAndSettle();
      expect(find.byType(CourseCard), findsNWidgets(3));
    });

    testWidgets('no row of chips under the search: the hub\'s tabs are the way around (owner, 7 Nov 2026)', (
      tester,
    ) async {
      await pumpTab(tester, threeCourses());
      for (final label in ['Mock Exams', 'Certificates', 'Flash cards', 'Knowledge center', 'My Attempts']) {
        expect(find.text(label), findsNothing, reason: label);
      }
      expect(launches.urls, isEmpty);
    });

    testWidgets('the title bar says what the hub called the screen', (tester) async {
      await pumpTab(tester, threeCourses(), title: 'ICR Courses');
      expect(find.text('ICR Courses'), findsOneWidget);
      expect(find.text('Learning'), findsNothing);
    });

    testWidgets('a controller that arrives narrowed shows its search in the box, and the grid is narrowed', (
      tester,
    ) async {
      await pumpTab(tester, threeCourses(), prepare: (l) => l.setSearch('Communication'));
      expect(find.widgetWithText(TextField, 'Communication'), findsOneWidget);
      expect(find.byType(CourseCard), findsOneWidget);
    });

    testWidgets('a card opens the course sheet on that course', (tester) async {
      await pumpTab(tester, threeCourses());
      await tester.tap(find.text('Rich course AAA'));
      await tester.pumpAndSettle();
      expect(find.text('Select Batch'), findsOneWidget);
      expect(find.text('PREMIUM CERTIFICATION'), findsNWidgets(2), reason: "the card behind and the sheet's cover");
      expect(find.text('Rich course AAA'), findsNWidgets(2), reason: 'the card behind and the sheet title');
    });

    testWidgets('a card of the second column opens its own course', (tester) async {
      await pumpTab(tester, threeCourses());
      await tester.tap(find.text('Communication'));
      await tester.pumpAndSettle();
      expect(find.text('Select Batch'), findsNothing, reason: 'a programme with no runs has no date grid');
      expect(find.text('Communication'), findsNWidgets(2), reason: 'the card behind and the sheet title');
    });

    testWidgets('pulling down reads the courses again', (tester) async {
      final fake = threeCourses();
      await pumpTab(tester, fake);
      expect(fake.courseCalls, 1);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 400));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(fake.courseCalls, 2);
      expect(find.byType(CourseCard), findsNWidgets(3));
    });

    testWidgets('a failed load says why and Try again reads the courses again', (tester) async {
      final broken = _Fake(catalogue: const [], listError: 'The server is down.');
      await pumpTab(tester, broken);
      expect(find.text("Unable to Load Courses"), findsOneWidget);
      expect(find.text('The server is down.'), findsOneWidget);
      broken.listError = null;
      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();
      expect(broken.courseCalls, 2);
      expect(find.text('No Courses Published Yet'), findsOneWidget);
    });
  });

  group('the catalogue grid', () {
    late _Launches launches;

    setUp(() {
      launches = _Launches()..install();
    });
    tearDown(() => launches.remove());

    // 390 dp: the Events agenda's frame — 9 dp in on the left, 9.5 on the right, 3 dp between the columns.
    const phone = Size(780, 3400);
    const small = Size(640, 4400); // 320 dp wide

    Future<_Fake> pump(WidgetTester tester, _Fake fake, {Size size = phone}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final learning = LearningController(fake);
      await tester.pumpWidget(
        _app(
          ChangeNotifierProvider.value(
            value: learning,
            child: LearningScreen(onBack: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return fake;
    }

    Finder card(String title) => find.ancestor(of: find.text(title), matching: find.byType(CourseCard)).first;

    testWidgets(
      'two columns on the Events frame, a lone course half width at the left, rows as tall as their taller card',
      (tester) async {
        final fake = _Fake(
          catalogue: [
            _rich(code: 'AAA'),
            _plain('BBB', 'Colloboration'),
            _plain('CCC', 'Communication'),
            _plain('DDD', 'Contract Management'),
          ],
        );
        await pump(tester, fake);
        expect(find.byType(CourseCard), findsNWidgets(4));
        final cardWidth = (390 - 9 - 9.5 - 3) / 2;

        final lone = tester.getRect(card('Rich course AAA'));
        expect(lone.left, closeTo(9, 0.01));
        expect(lone.width, closeTo(cardWidth, 0.01), reason: 'a section with one course draws a half-width card');

        final left = tester.getRect(card('Colloboration'));
        final right = tester.getRect(card('Communication'));
        expect(left.left, closeTo(9, 0.01));
        expect(right.left, closeTo(9 + cardWidth + 3, 0.01), reason: '3 dp between the columns');
        expect(right.right, closeTo(390 - 9.5, 0.01));
        expect(left.top, right.top);
        expect(left.height, right.height, reason: 'one row: equal heights');

        final next = tester.getRect(card('Contract Management'));
        expect(next.left, closeTo(9, 0.01));
        expect(next.top - left.bottom, closeTo(4, 0.01), reason: '4 dp between rows');

        // The cover is 16:10, as the Events photo (184.5 × 114).
        final cover = tester.getRect(find.descendant(of: card('Colloboration'), matching: find.byType(AspectRatio)));
        expect(cover.width / cover.height, closeTo(184.5 / 114, 0.001));
      },
    );

    testWidgets("each section keeps its heading: ICR's own courses, then the partners'", (tester) async {
      final fake = _Fake(
        catalogue: [
          _rich(code: 'AAA'),
          _plain('BBB', 'Colloboration'),
          _plain('CCC', 'Communication'),
        ],
      );
      await pump(tester, fake);
      final icr = tester.getRect(find.text('ICR Certification Programmes'));
      final partners = tester.getRect(find.text('Related Courses from Our Partners'));
      expect(icr.top, lessThan(tester.getRect(card('Colloboration')).top));
      expect(partners.top, greaterThan(tester.getRect(card('Colloboration')).bottom));
      expect(partners.top, lessThan(tester.getRect(card('Rich course AAA')).top));
      expect(
        find.descendant(of: find.byType(CourseCard), matching: find.text('ICR Certification Programmes')),
        findsNothing,
      );
    });

    testWidgets('a card carries what the row did: cover pill, title, awarding body, meta, price, place', (
      tester,
    ) async {
      final held = MyEnrolment(
        id: 'e',
        courseId: 'c-HELD',
        runId: 'r1',
        status: EnrolmentStatus.confirmed,
        startsAt: DateTime(2027, 8, 23),
        endsAt: DateTime(2027, 8, 27),
        location: 'Riyadh, KSA',
      );
      final fake = _Fake(
        catalogue: [
          _rich(code: 'HELD', enrolment: held),
          _plain('CP', 'Capital Planning'),
        ],
      );
      await pump(tester, fake);
      final c = card('Rich course HELD');
      expect(find.descendant(of: c, matching: find.text('PREMIUM CERTIFICATION')), findsOneWidget);
      expect(find.descendant(of: c, matching: find.text('Rich course HELD')), findsOneWidget);
      expect(find.descendant(of: c, matching: find.text('Vinfraa Institute')), findsOneWidget);
      expect(find.descendant(of: c, matching: find.text('5 days · 35 hours • In person')), findsOneWidget);
      expect(find.descendant(of: c, matching: find.byIcon(LucideIcons.clock3)), findsOneWidget);
      expect(find.descendant(of: c, matching: find.text('Free')), findsOneWidget);
      expect(
        find.descendant(of: c, matching: find.text('Enrolled')),
        findsOneWidget,
        reason: 'the place sits in the footer',
      );

      // Free and the place share the footer row, the place to the right of the price.
      final free = tester.getRect(find.descendant(of: c, matching: find.text('Free')));
      final place = tester.getRect(find.descendant(of: c, matching: find.text('Enrolled')));
      expect(place.left, greaterThan(free.right));
      expect((place.center.dy - free.center.dy).abs(), lessThan(1));

      // A course with no duration keeps its "what it is" line and its ribbon glyph.
      final programme = card('Capital Planning');
      expect(find.descendant(of: programme, matching: find.text('Foundation • Course')), findsOneWidget);
      expect(find.descendant(of: programme, matching: find.byIcon(LucideIcons.award)), findsOneWidget);
      expect(find.descendant(of: programme, matching: find.byIcon(LucideIcons.clock3)), findsNothing);
      expect(
        find.descendant(of: programme, matching: find.text('ICR Institute')),
        findsOneWidget,
        reason: "ICR's own: no logo, its name",
      );
      expect(find.descendant(of: programme, matching: find.text('Enrolled')), findsNothing);
    });

    testWidgets(
      'the meta line wraps to a second line instead of losing a word, and footers line up along the foot of a row',
      (tester) async {
        final fake = _Fake(
          catalogue: [
            const Course(
              id: 'c-CP',
              code: 'CP',
              title: 'Capital Planning',
              level: 'Foundation Practitioner Level',
              detailLoaded: true,
            ),
            const Course(
              id: 'c-TIMED',
              code: 'TIMED',
              title: 'Timed programme',
              level: 'Foundation',
              durationLabel: '2 days',
              detailLoaded: true,
            ),
          ],
        );
        await pump(tester, fake);
        const long = 'Foundation Practitioner Level • Course';
        final meta = tester.widget<Text>(find.text(long));
        expect(meta.maxLines, 2);
        expect(
          tester.renderObject<RenderParagraph>(find.text(long)).didExceedMaxLines,
          isFalse,
          reason: 'the whole line is shown, on two lines at 390 dp',
        );
        final a = tester.getRect(find.descendant(of: card('Capital Planning'), matching: find.byType(CourseFooter)));
        final b = tester.getRect(find.descendant(of: card('Timed programme'), matching: find.byType(CourseFooter)));
        expect(a.bottom, closeTo(b.bottom, 0.01), reason: "the footers share the card's bottom edge");
        expect(
          tester.getRect(card('Capital Planning')).bottom,
          closeTo(a.bottom + 9, 0.01),
          reason: '9 dp under the footer',
        );
      },
    );

    testWidgets('the footer: a rupee price, credits and every kind of place', (tester) async {
      Course withPlace(String code, EnrolmentStatus status) => _rich(
        code: code,
        title: 'Place $code',
        enrolment: MyEnrolment(id: code, courseId: 'c-$code', status: status),
      );
      final fake = _Fake(
        catalogue: [
          _rich(code: 'PAID', title: 'Paid course', price: 1180000, cpd: 35),
          withPlace('PEND', EnrolmentStatus.pending),
          withPlace('WAIT', EnrolmentStatus.waitlisted),
          withPlace('DONE', EnrolmentStatus.completed),
        ],
      );
      await pump(tester, fake);
      final paid = card('Paid course');
      expect(find.descendant(of: paid, matching: find.text('₹11,800')), findsOneWidget);
      expect(find.descendant(of: paid, matching: find.text('Free')), findsNothing);
      expect(find.descendant(of: paid, matching: find.text('35 CPD')), findsOneWidget);
      expect(find.descendant(of: card('Place PEND'), matching: find.text('Place requested')), findsOneWidget);
      expect(find.descendant(of: card('Place WAIT'), matching: find.text('On the waitlist')), findsOneWidget);
      expect(find.descendant(of: card('Place DONE'), matching: find.text('Completed')), findsOneWidget);
      expect(find.text('35 CPD'), findsOneWidget, reason: 'credits only where the course has them');
    });

    testWidgets('a course with no cover gets its initials on a plate, one with a logo shows it by the awarding body', (
      tester,
    ) async {
      const logo = FeedPicture.asset('assets/images/demo/learning/badge_icr.png');
      final fake = _Fake(
        catalogue: [
          _rich(
            code: 'LOGO',
            provider: const CourseProvider(id: 'p2', name: 'Logo Institute', logo: logo),
          ),
          _plain('NOCOVER', 'Certificate in Advanced Leadership Skills'),
        ],
      );
      await pump(tester, fake);
      expect(
        find.descendant(of: card('Certificate in Advanced Leadership Skills'), matching: find.text('CA')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card('Rich course LOGO'), matching: find.byType(Image)),
        findsOneWidget,
        reason: 'the logo',
      );
      expect(
        find.descendant(of: card('Certificate in Advanced Leadership Skills'), matching: find.byType(Image)),
        findsNothing,
      );
    });

    testWidgets('a long title is cut at two lines; a long awarding body and meta at one', (tester) async {
      final fake = _Fake(
        catalogue: [
          _rich(
            code: 'LONG',
            title:
                'The Complete Programme in Strategic Facilities Management Leadership for Senior Executives Worldwide',
            provider: const CourseProvider(
              id: 'p3',
              name: 'The International Institute of Facilities, Real Estate and Asset Management Professionals',
            ),
          ),
          _plain('SHORT', 'Short'),
          _plain('TINY', 'Tiny'),
          _plain('MINI', 'Mini'),
        ],
      );
      await pump(tester, fake);
      final title = tester.widget<Text>(
        find.descendant(
          of: card(
            'The Complete Programme in Strategic Facilities Management Leadership for Senior Executives Worldwide',
          ),
          matching: find.text(
            'The Complete Programme in Strategic Facilities Management Leadership for Senior Executives Worldwide',
          ),
        ),
      );
      expect(title.maxLines, 2);
      expect(title.overflow, TextOverflow.ellipsis);
      final long = tester.getRect(
        card('The Complete Programme in Strategic Facilities Management Leadership for Senior Executives Worldwide'),
      );
      final plainRow = tester.getRect(card('Tiny'));
      // A line of the title (cardTitle: size × height) is what a long title costs the row at most once; the
      // card's meta line may wrap to a second line at the app's 12 sp caption, one more `cardMeta` line.
      final titleLine = LearningText.cardTitle.fontSize! * LearningText.cardTitle.height!;
      final metaLine = LearningText.cardMeta.fontSize! * LearningText.cardMeta.height!;
      final extra = long.height - plainRow.height;
      expect(
        extra,
        inInclusiveRange(titleLine - 1, titleLine + metaLine + 1),
        reason: 'a long title costs its row one extra line (two lines at most), a long awarding body nothing',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a 320 dp phone: no overflow with a long title, awarding body, meta, price, place and credits', (
      tester,
    ) async {
      final longTitle = 'The Complete Programme in Strategic Facilities Management Leadership for Senior Executives';
      final long = _rich(
        code: 'LONG',
        title: longTitle,
        price: 118000000,
        cpd: 120,
        provider: const CourseProvider(
          id: 'p3',
          name: 'The International Institute of Facilities, Real Estate and Asset Management Professionals',
        ),
        enrolment: const MyEnrolment(id: 'e', courseId: 'c-LONG', status: EnrolmentStatus.pending),
      );
      final fake = _Fake(
        catalogue: [
          long,
          _rich(code: 'TWO', title: 'Second', price: 5000),
          _plain('BBB', 'Colloboration'),
          _plain('CCC', 'Communication'),
          _plain('DDD', 'Contract Management'),
        ],
      );
      await pump(tester, fake, size: small);
      expect(tester.takeException(), isNull);
      expect(find.byType(CourseCard), findsNWidgets(5));
      final cardWidth = (320 - 9 - 9.5 - 3) / 2;
      final a = tester.getRect(card(longTitle));
      final b = tester.getRect(card('Second'));
      expect(a.width, closeTo(cardWidth, 0.01));
      expect(a.right, lessThanOrEqualTo(b.left));
      expect(b.right, lessThanOrEqualTo(320));
      expect(a.height, b.height, reason: 'equal heights in the row even where one footer wraps');
      // The footer wraps to a second line instead of overflowing.
      final footerOfLong = tester.getRect(find.descendant(of: card(longTitle), matching: find.byType(CourseFooter)));
      expect(footerOfLong.right, lessThanOrEqualTo(a.right));
      expect(footerOfLong.height, greaterThan(20));
    });

    testWidgets('My courses shows the places the member holds as cards, with their run', (tester) async {
      final fake = _Fake(
        catalogue: [
          _rich(code: 'AAA'),
          _plain('BBB', 'Colloboration', kind: CourseKind.assessment),
        ],
      );
      fake.mine = [
        MyEnrolment(
          id: 'e',
          courseId: 'c-AAA',
          runId: 'r1',
          status: EnrolmentStatus.confirmed,
          startsAt: DateTime(2027, 8, 23),
          endsAt: DateTime(2027, 8, 27),
          location: 'Riyadh, KSA',
        ),
      ];
      await pump(tester, fake);
      Provider.of<LearningController>(tester.element(find.byType(LearningScreen)), listen: false).setMineOnly(true);
      await tester.pumpAndSettle();
      expect(find.byType(CourseCard), findsOneWidget);
      final c = card('Rich course AAA');
      expect(find.descendant(of: c, matching: find.text('Aug 23 - 27, 2027 • Riyadh, KSA')), findsOneWidget);
      expect(find.descendant(of: c, matching: find.byIcon(LucideIcons.calendar)), findsOneWidget);
      expect(find.descendant(of: c, matching: find.text('Enrolled')), findsOneWidget);
      expect(find.text('Colloboration'), findsNothing);
      expect(
        tester.getRect(c).width,
        closeTo((390 - 9 - 9.5 - 3) / 2, 0.01),
        reason: 'one place: a half-width card at the left',
      );
    });
  });

  group('the course sheet', () {
    late _Launches launches;

    setUp(() {
      launches = _Launches()..install();
    });
    tearDown(() => launches.remove());

    Future<(_Fake, CourseSheetController)> pumpSheet(WidgetTester tester, _Fake fake, {Course? seed}) async {
      tester.view.physicalSize = const Size(780, 6400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final learning = LearningController(fake);
      final controller = CourseSheetController(
        repository: fake,
        seed: seed ?? fake.catalogue.first,
        onChanged: learning.update,
      );
      await tester.runAsync(controller.load);
      await tester.pumpWidget(
        _app(
          ChangeNotifierProvider<LearningController>.value(
            value: learning,
            child: ChangeNotifierProvider.value(
              value: controller,
              child: const Scaffold(
                body: DetailSheetFrame(topInset: 0, body: CourseSheetBody(), bottomBar: CourseSheetBar()),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (fake, controller);
    }

    CourseReviews three() => CourseReviews(
      items: [
        _review(1, role: 'Facilities Manager'),
        _review(2),
        _review(3),
      ],
      total: 3,
    );

    testWidgets("the pinned bar's button is the design's 123 × 35 dp for \"add to cart\" and widens for longer words", (
      tester,
    ) async {
      Future<Size> button(String label) async {
        await tester.pumpWidget(
          _app(
            Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: CourseBottomBar(label: label, onAction: () {}, onBrochure: () {}),
              ),
            ),
          ),
        );
        return tester.getSize(find.ancestor(of: find.text(label), matching: find.byType(Container)).first);
      }

      final normal = await button('add to cart');
      expect(normal.width, closeTo(123, 0.01));
      expect(normal.height, closeTo(35, 0.01));
      final long = await button('enrolment closed');
      expect(long.width, greaterThan(123));
      expect(long.height, closeTo(35, 0.01));
      expect(tester.takeException(), isNull, reason: 'a long word widens the button, it never overflows it');
    });

    testWidgets('draws the pill from the course, over the cover', (tester) async {
      await pumpSheet(tester, _Fake(catalogue: [_rich()]));
      expect(find.byType(CoverPill), findsOneWidget);
      expect(find.text('PREMIUM CERTIFICATION'), findsOneWidget);
      final size = tester.getSize(find.byType(CoverPill));
      expect(size.height, closeTo(25.8, 0.01), reason: "the design's pill is 25.8 dp tall");
      // As wide as its words (now set at the app's 12 sp, so 168 dp rather than the design's 133) with 11.4 dp
      // of padding and a 1 dp hairline each side.
      final words = tester.getSize(find.text('PREMIUM CERTIFICATION')).width;
      expect(
        size.width,
        closeTo(words + 2 * 11.4 + 2, 1.5),
        reason: 'the pill is as wide as its words plus its padding',
      );
    });

    testWidgets('the two tabs filter the runs by mode, and each tab opens on its own first run', (tester) async {
      final (_, sheet) = await pumpSheet(tester, _Fake(catalogue: [_rich()]));
      expect(find.byType(RunTile), findsNWidgets(3), reason: 'three of the four, before See More Dates');
      expect(find.text('Singapore, SG'), findsNothing);
      expect(find.text('Live online'), findsNothing);
      await tester.tap(find.text('Live Virtual Training'));
      await tester.pumpAndSettle();
      expect(sheet.mode, DeliveryMode.virtual);
      expect(find.byType(RunTile), findsNWidgets(2));
      expect(find.text('Live online'), findsNWidgets(2));
      expect(find.text('Riyadh, KSA'), findsNothing);
      expect(sheet.selectedRun?.id, 'v1');
      await tester.tap(find.text('Classroom Training'));
      await tester.pumpAndSettle();
      expect(find.text('Riyadh, KSA'), findsOneWidget);
      expect(sheet.selectedRun?.id, 'r1');
    });

    testWidgets('a tab with no runs says so and keeps the Suggest tile', (tester) async {
      final (_, sheet) = await pumpSheet(tester, _Fake(catalogue: [DemoLearningRepository().course]));
      await tester.tap(find.text('Live Virtual Training'));
      await tester.pumpAndSettle();
      expect(find.text('No live virtual training dates are scheduled yet.'), findsOneWidget);
      expect(find.text('Suggest a Date &\nLocation'), findsOneWidget);
      expect(sheet.selectedRun, isNull);
    });

    testWidgets('a date tile selects its run; the schedule caption is a caption, not a way out', (tester) async {
      final (_, sheet) = await pumpSheet(tester, _Fake(catalogue: [_rich()]));
      expect(sheet.selectedRun?.id, 'r1');
      await tester.tap(find.text('London, UK'));
      await tester.pump();
      expect(sheet.selectedRun?.id, 'r2');
      expect(find.text('2027 Schedule'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('schedule-link')), warnIfMissed: false);
      await tester.pump();
      expect(launches.urls, isEmpty, reason: 'the grid is the schedule; the website page was this sheet');
    });

    testWidgets('See More Dates unfolds the fourth run', (tester) async {
      final (_, sheet) = await pumpSheet(tester, _Fake(catalogue: [_rich()]));
      await tester.tap(find.text('See More Dates'));
      await tester.pump();
      expect(sheet.allDates, isTrue);
      expect(find.byType(RunTile), findsNWidgets(4));
      expect(find.text('Singapore, SG'), findsOneWidget);
      expect(find.text('Show Fewer Dates'), findsOneWidget);
      await tester.tap(find.text('Show Fewer Dates'));
      await tester.pump();
      expect(find.byType(RunTile), findsNWidgets(3));
      expect(launches.urls, isEmpty);
    });

    testWidgets('with no further run there is no See More Dates (it opened this sheet again)', (tester) async {
      await pumpSheet(tester, _Fake(catalogue: [DemoLearningRepository().course]));
      expect(find.text('See More Dates'), findsNothing);
      expect(launches.urls, isEmpty);
    });

    testWidgets('a held place reads CONFIRMED on its tile and the big button says so; Add to cart is off', (
      tester,
    ) async {
      final held = _rich().copyWith(
        enrolment: const MyEnrolment(id: 'e', courseId: 'c-RICH', runId: 'r1', status: EnrolmentStatus.confirmed),
      );
      final (fake, _) = await pumpSheet(tester, _Fake(catalogue: [held]));
      expect(find.text('CONFIRMED'), findsOneWidget);
      expect(find.text('ENROLLED'), findsNothing, reason: 'the big button gives way to the place itself');
      expect(find.text('You are confirmed on Riyadh, KSA, Aug 23 - 27, 2027.'), findsOneWidget);
      expect(find.text('ENROL NOW'), findsNothing);
      expect(find.text('Enrolled'), findsOneWidget, reason: 'the pinned bar still says so');
      await tester.tap(find.text('Enrolled'));
      await tester.pump();
      expect(fake.enrols, isEmpty, reason: 'a held place is never taken twice');
      expect(
        find.text('Your place on Rich course RICH is confirmed.'),
        findsOneWidget,
        reason: 'it says where it stands',
      );
    });

    testWidgets('ENROL NOW on a free course takes the selected run through the enrol endpoint', (tester) async {
      final (fake, sheet) = await pumpSheet(tester, _Fake(catalogue: [_rich()]));
      await tester.tap(find.text('London, UK'));
      await tester.pump();
      await tester.tap(find.text('ENROL NOW'));
      await tester.pumpAndSettle();
      expect(fake.enrols, [('RICH', 'r2')]);
      expect(sheet.course.enrolment?.status, EnrolmentStatus.pending);
      expect(
        find.text('You are pending on London, UK, Sep 14 - 18, 2027. The ICR team will confirm your place.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('withdraw')), findsOneWidget, reason: 'a request can be taken back');
      expect(find.text('REQUESTED'), findsOneWidget, reason: 'London reads REQUESTED on its tile');
      expect(find.text('Place requested. ICR will confirm it by email.'), findsOneWidget);
      expect(launches.urls, isEmpty);
    });

    testWidgets('ENROL NOW on a paid course pays for the place in the app, never on the website', (tester) async {
      final bought = <String>[];
      CourseCheckout.start = (context, course, run) async {
        bought.add(course.code);
        return const CheckoutStart(action: 'https://test.payu.in/_payment', fields: {'txnid': 't1'});
      };
      final posted = <String>[];
      PaymentServices.pay = (context, {required action, required fields, String title = ''}) async {
        posted.add(action);
        return PaymentOutcome.success;
      };
      addTearDown(CourseCheckout.reset);
      addTearDown(PaymentServices.reset);
      final (fake, _) = await pumpSheet(tester, _Fake(catalogue: [_rich(code: 'PAID', price: 1180000)]));
      await tester.tap(find.text('ENROL NOW'));
      await tester.pumpAndSettle();
      expect(bought, ['PAID']);
      expect(posted, ['https://test.payu.in/_payment'], reason: "the gateway's form, in the app's payment view");
      expect(launches.urls, isEmpty);
      expect(fake.enrols, isEmpty, reason: 'a paid place is bought, not asked for');
    });

    testWidgets("a refused place is put back and the API's sentence shown", (tester) async {
      final (_, sheet) = await pumpSheet(tester, _Fake(catalogue: [_rich()], enrolError: 'This batch is full.'));
      await tester.tap(find.text('ENROL NOW'));
      await tester.pumpAndSettle();
      expect(find.text('This batch is full.'), findsOneWidget);
      expect(sheet.course.enrolled, isFalse);
      expect(find.text('ENROL NOW'), findsOneWidget);
    });

    group('withdrawing a place, as the website does', () {
      MyEnrolment held(EnrolmentStatus status, {String? runId = 'r2'}) =>
          MyEnrolment(id: 'e', courseId: 'c-RICH', runId: runId, status: status);

      Future<(_Fake, CourseSheetController)> pumpHeld(WidgetTester tester, MyEnrolment mine, {String? refusal}) {
        final fake = _Fake(catalogue: [_rich()])..mine = [mine];
        fake.withdrawError = refusal;
        return pumpSheet(tester, fake, seed: _rich(enrolment: mine));
      }

      testWidgets('a request is taken back after one question, and "add to cart" returns', (tester) async {
        final (fake, sheet) = await pumpHeld(tester, held(EnrolmentStatus.pending));
        expect(find.text('REQUESTED'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('withdraw')));
        await tester.pumpAndSettle();
        expect(find.text('Withdraw Your Request?'), findsOneWidget);
        await tester.tap(find.text('Withdraw').last);
        await tester.pumpAndSettle();
        expect(fake.withdrawals, ['RICH']);
        expect(sheet.course.enrolled, isFalse);
        expect(find.text('ENROL NOW'), findsOneWidget, reason: 'the member can ask again, here or on another date');
        expect(find.byKey(const ValueKey('place-status')), findsNothing);
        expect(find.text('REQUESTED'), findsNothing, reason: 'the date tile is plain again');
        expect(find.text('Your request was withdrawn.'), findsOneWidget);
      });

      testWidgets('"Keep it" sends nothing', (tester) async {
        final (fake, sheet) = await pumpHeld(tester, held(EnrolmentStatus.pending));
        await tester.tap(find.byKey(const ValueKey('withdraw')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Keep It'));
        await tester.pumpAndSettle();
        expect(fake.withdrawals, isEmpty);
        expect(sheet.course.enrolled, isTrue);
      });

      testWidgets('a confirmed place says it is given up', (tester) async {
        final (fake, sheet) = await pumpHeld(tester, held(EnrolmentStatus.confirmed));
        await tester.tap(find.byKey(const ValueKey('withdraw')));
        await tester.pumpAndSettle();
        expect(find.text('Withdraw Your Place?'), findsOneWidget);
        await tester.tap(find.text('Withdraw').last);
        await tester.pumpAndSettle();
        expect(fake.withdrawals, ['RICH']);
        expect(sheet.course.enrolled, isFalse);
        expect(find.text('Your place was withdrawn.'), findsOneWidget);
      });

      testWidgets("a paid place is refused in the API's own words and stays held", (tester) async {
        const refusal = 'Your place is paid for. To withdraw, contact ICR support, who will arrange any refund.';
        final (_, sheet) = await pumpHeld(tester, held(EnrolmentStatus.confirmed), refusal: refusal);
        await tester.tap(find.byKey(const ValueKey('withdraw')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Withdraw').last);
        await tester.pumpAndSettle();
        expect(find.text(refusal), findsOneWidget);
        expect(find.byKey(const ValueKey('withdraw-refused')), findsOneWidget);
        expect(sheet.course.enrolled, isTrue);
        expect(find.byKey(const ValueKey('withdraw')), findsOneWidget, reason: 'still there to try again');
      });

      testWidgets('a waitlist place is told what happens next, and can be withdrawn', (tester) async {
        await pumpHeld(tester, held(EnrolmentStatus.waitlisted));
        expect(
          find.text(
            'You are waitlisted on London, UK, Sep 14 - 18, 2027. We will contact you if a seat becomes available.',
          ),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('withdraw')), findsOneWidget);
      });

      testWidgets('a completed course has nothing to withdraw', (tester) async {
        await pumpHeld(tester, held(EnrolmentStatus.completed));
        expect(find.text('You have completed this course.'), findsOneWidget);
        expect(find.byKey(const ValueKey('withdraw')), findsNothing);
      });

      testWidgets('a place on no run names none', (tester) async {
        await pumpHeld(tester, held(EnrolmentStatus.pending, runId: null));
        expect(find.text('You are pending. The ICR team will confirm your place.'), findsOneWidget);
      });
    });

    testWidgets('DOWNLOAD BROCHURE asks who is reading, prefilled; Download sends the lead, then hands the file '
        'to the phone', (tester) async {
      final (fake, _) = await pumpSheet(tester, _Fake(catalogue: [_rich()]));
      await tester.tap(find.text('DOWNLOAD BROCHURE'));
      await tester.pumpAndSettle();
      expect(find.text('Get the Brochure'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const ValueKey('brochure-name'))).controller!.text, 'Bharat Buyer');
      expect(tester.widget<TextField>(find.byKey(const ValueKey('brochure-email'))).controller!.text, 'buyer@icr.dev');
      expect(launches.urls, isEmpty, reason: 'nothing opens before the lead is sent');
      await tester.enterText(find.byKey(const ValueKey('brochure-company')), 'TechCorp');
      await tester.tap(find.byKey(const ValueKey('brochure-download')));
      await tester.pumpAndSettle();
      expect(fake.brochureLeads, hasLength(1));
      expect(fake.brochureLeads.single.$1, 'RICH');
      expect(fake.brochureLeads.single.$2.company, 'TechCorp');
      expect(fake.brochureLeads.single.$2.phone, '+919845012345', reason: 'the phone is normalised');
      expect(fake.brochureLeads.single.$3, BrochureIntent.download);
      expect(launches.urls, ['https://files.test/brochure.pdf']);
      expect(find.text('Get the Brochure'), findsNothing);
    });

    testWidgets('View brochure sends the lead and opens the PDF in the app, nothing downloaded', (tester) async {
      final pdf = FakePdfEngine();
      CourseSheetBody.brochurePdf = () => pdf;
      CourseSheetBody.brochureRunner = runHere;
      addTearDown(() {
        CourseSheetBody.brochurePdf = PlatformPdfEngine.new;
        CourseSheetBody.brochureRunner = runInBackground;
      });
      final (fake, _) = await pumpSheet(tester, _Fake(catalogue: [_rich()]));
      await tester.tap(find.byIcon(Symbols.download).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('brochure-view')));
      await tester.pumpAndSettle();
      expect(fake.brochureLeads.single.$3, BrochureIntent.view);
      expect(find.byType(DocumentViewerScreen), findsOneWidget);
      // Download and Share in the viewer's bar, as for every file (no screenshot lock anywhere since 5 Nov 2026).
      expect(find.byTooltip('Download'), findsOneWidget);
      expect(find.byTooltip('Share'), findsOneWidget);
      expect(pdf.opened, hasLength(1), reason: 'the brochure bytes went to the viewer');
      expect(launches.urls, isEmpty);

      // Back on the sheet, the form comes back prefilled with what was sent, and the same lead goes only once.
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('DOWNLOAD BROCHURE'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('brochure-download')));
      await tester.pumpAndSettle();
      expect(fake.brochureLeads, hasLength(1), reason: 'one brochure, one lead');
      expect(launches.urls, ['https://files.test/brochure.pdf']);
    });

    testWidgets('the brochure form wants a name, a real email and a phone, and shows a refusal', (tester) async {
      final (fake, _) = await pumpSheet(tester, _Fake(catalogue: [_rich()]));
      await tester.tap(find.text('DOWNLOAD BROCHURE'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('brochure-phone')), '');
      await tester.tap(find.byKey(const ValueKey('brochure-download')));
      await tester.pump();
      expect(find.text('Enter your mobile number so the institute can call you.'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('brochure-phone')), '+91 98450 12345');
      await tester.enterText(find.byKey(const ValueKey('brochure-email')), 'nope');
      await tester.tap(find.byKey(const ValueKey('brochure-download')));
      await tester.pump();
      expect(find.text('Enter the email address to send the brochure to.'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('brochure-email')), 'buyer@icr.dev');
      fake.brochureRefusal = 'Too many requests. Wait a minute and try again.';
      await tester.tap(find.byKey(const ValueKey('brochure-download')));
      await tester.pumpAndSettle();
      expect(find.text('Too many requests. Wait a minute and try again.'), findsOneWidget);
      expect(launches.urls, isEmpty);
      expect(fake.brochureLeads, isEmpty);
    });

    testWidgets('a course with no brochure offers none, as the website shows no prospectus link', (tester) async {
      await pumpSheet(tester, _Fake(catalogue: [_rich(code: 'NOB', brochure: null)]));
      expect(find.text('DOWNLOAD BROCHURE'), findsNothing);
      expect(find.text('ENROL NOW'), findsOneWidget, reason: 'the rest of the sheet stands');
      expect(launches.urls, isEmpty);
    });

    testWidgets('the form works with the account read failing: blank fields, live buttons', (tester) async {
      final (fake, _) = await pumpSheet(tester, _Fake(catalogue: [_rich()])..contactFails = true);
      await tester.tap(find.text('DOWNLOAD BROCHURE'));
      await tester.pumpAndSettle();
      expect(find.text('Get the Brochure'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const ValueKey('brochure-name'))).controller!.text, '');
      expect(
        tester.widget<PrimaryButton>(find.byKey(const ValueKey('brochure-view'))).onPressed,
        isNotNull,
        reason: 'a read that failed must not hold the form',
      );
      await tester.enterText(find.byKey(const ValueKey('brochure-name')), 'Chetan S M');
      await tester.enterText(find.byKey(const ValueKey('brochure-email')), 'chetan@example.com');
      await tester.enterText(find.byKey(const ValueKey('brochure-phone')), '9876543210');
      await tester.tap(find.byKey(const ValueKey('brochure-download')));
      await tester.pumpAndSettle();
      expect(fake.brochureLeads, hasLength(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the overview folds after four lines and "show more" unfolds it', (tester) async {
      await pumpSheet(tester, _Fake(catalogue: [_rich()]));
      expect(find.text('Show More'), findsOneWidget);
      await tester.tap(find.text('Show More'));
      await tester.pump();
      expect(find.text('Show Less'), findsOneWidget);
      await tester.tap(find.text('Show Less'));
      await tester.pump();
      expect(find.text('Show More'), findsOneWidget);
    });

    testWidgets('"view full outline" opens every module; each module folds on its own', (tester) async {
      await pumpSheet(tester, _Fake(catalogue: [_rich()]));
      expect(find.text('Lesson A'), findsOneWidget, reason: 'the first module opens');
      expect(find.text('Details for this module will be available soon.'), findsNothing);
      await tester.tap(find.text('View Full Outline'));
      await tester.pump();
      expect(find.text('Details for this module will be available soon.'), findsOneWidget);
      expect(find.text('Collapse Outline'), findsOneWidget);
      await tester.tap(find.text('Module 1: Leadership Intelligence'));
      await tester.pump();
      expect(find.text('Lesson A'), findsNothing);
      expect(find.text('Details for this module will be available soon.'), findsOneWidget);
      await tester.tap(find.text('Collapse Outline'));
      await tester.pump();
      expect(find.text('Lesson A'), findsOneWidget, reason: 'back to the first module open, the rest folded');
      expect(find.text('Details for this module will be available soon.'), findsNothing);
    });

    testWidgets('the specialist: the email line mails ICR on a live course, the third button asks the institute', (
      tester,
    ) async {
      final (fake, _) = await pumpSheet(tester, _Fake(catalogue: [_rich()]));
      expect(find.text('Bushra A.'), findsOneWidget);
      expect(find.text(icrEnquiryEmail), findsOneWidget);
      await tester.tap(find.text(icrEnquiryEmail));
      await tester.pump();
      expect(launches.urls.single, startsWith('mailto:$icrEnquiryEmail?subject='));
      expect(launches.urls.single, contains('Rich%20course%20RICH%20(RICH)'));

      await tester.tap(find.text('Ask the Institute'));
      await tester.pumpAndSettle();
      expect(find.text('Ask Vinfraa Institute'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('enquiry-send')));
      await tester.pump();
      expect(find.text('Add more detail to your message.'), findsOneWidget, reason: 'too short to send');
      await tester.enterText(find.byKey(const ValueKey('enquiry-message')), 'Do you run this in Pune?');
      await tester.tap(find.byKey(const ValueKey('enquiry-send')));
      await tester.pumpAndSettle();
      expect(fake.enquiries.single.kind, EnquiryKind.question);
      expect(fake.enquiries.single.message, 'Do you run this in Pune?');
      expect(find.text('Sent to Vinfraa Institute. They will reply by email.'), findsOneWidget);
    });

    testWidgets("on the demo the specialist's own email opens the mail app and WhatsApp opens WhatsApp", (
      tester,
    ) async {
      await pumpSheet(tester, _Fake(catalogue: [DemoLearningRepository().course]));
      expect(find.text("Let's Talk on WhatsApp"), findsOneWidget);
      await tester.tap(find.text('contact@icrvinfraa.com'));
      await tester.pump();
      await tester.tap(find.text("Let's Talk on WhatsApp"));
      await tester.pump();
      expect(launches.urls.first, startsWith('mailto:contact@icrvinfraa.com?subject='));
      expect(launches.urls.last, 'https://wa.me/');
    });

    testWidgets('"Request Corporate Training" is a corporate enquiry with company and headcount', (tester) async {
      final (fake, _) = await pumpSheet(tester, _Fake(catalogue: [_rich()]));
      await tester.tap(find.text('Request Corporate Training'));
      await tester.pumpAndSettle();
      expect(find.text('Request Corporate Training'), findsNWidgets(2), reason: 'the button, and the form it opens');
      await tester.enterText(find.byKey(const ValueKey('enquiry-company')), 'Acme Facilities');
      await tester.enterText(find.byKey(const ValueKey('enquiry-message')), 'Two cohorts in Pune, March.');
      await tester.enterText(find.byKey(const ValueKey('enquiry-headcount')), '0');
      await tester.tap(find.byKey(const ValueKey('enquiry-send')));
      await tester.pump();
      expect(find.text('Enter the number of people as a whole number, 1 or more.'), findsOneWidget);
      expect(fake.enquiries, isEmpty);
      await tester.enterText(find.byKey(const ValueKey('enquiry-headcount')), '30');
      await tester.tap(find.byKey(const ValueKey('enquiry-send')));
      await tester.pumpAndSettle();
      final sent = fake.enquiries.single;
      expect(sent.kind, EnquiryKind.inHouse);
      expect(sent.message, 'In-house delivery request: Two cohorts in Pune, March.');
      expect(sent.company, 'Acme Facilities');
      expect(sent.headcount, 30);
    });

    testWidgets("ICR's own course has no institute: in-house, Suggest and the third button open the contact page", (
      tester,
    ) async {
      final (fake, _) = await pumpSheet(tester, _Fake(catalogue: [_rich(code: 'OWN', provider: null)]));
      await tester.tap(find.text('Request Corporate Training'));
      await tester.pump();
      await tester.tap(find.text('Ask the Institute'));
      await tester.pump();
      await tester.tap(find.text('Suggest a Date &\nLocation'));
      await tester.pump();
      expect(launches.urls, hasLength(3));
      expect(launches.urls[0], startsWith('https://icr.org.in/contact?subject=In-house+delivery%3A+'));
      expect(launches.urls[1], startsWith('https://icr.org.in/contact?subject=Rich+course+OWN'));
      expect(launches.urls[2], startsWith('https://icr.org.in/contact?subject=Date+and+location+request%3A+'));
      expect(fake.enquiries, isEmpty);
    });

    testWidgets('"Suggest a Date & Location" sends a date and location request to the institute', (tester) async {
      final (fake, _) = await pumpSheet(tester, _Fake(catalogue: [_rich()]));
      await tester.tap(find.text('Suggest a Date &\nLocation'));
      await tester.pumpAndSettle();
      expect(find.text('Suggest a Date & Location'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('enquiry-company')),
        findsNothing,
        reason: 'only the in-house form asks for a company',
      );
      await tester.enterText(find.byKey(const ValueKey('enquiry-message')), 'Pune, the first week of March.');
      await tester.tap(find.byKey(const ValueKey('enquiry-send')));
      await tester.pumpAndSettle();
      final sent = fake.enquiries.single;
      expect(sent.kind, EnquiryKind.dateRequest);
      expect(sent.message, 'Date and location request: Pune, the first week of March.');
      expect(sent.company, anyOf(isNull, isEmpty));
      expect(launches.urls, isEmpty);
    });

    testWidgets('the testimonial is the first review; "see all" opens the rest, "show fewer" folds them', (
      tester,
    ) async {
      await pumpSheet(tester, _Fake(catalogue: [_rich()], reviewList: three()));
      expect(find.textContaining('Review body number 1'), findsOneWidget);
      expect(find.text('Reviewer 1'), findsOneWidget);
      expect(find.text('Facilities Manager'), findsOneWidget);
      expect(find.textContaining('Review body number 2'), findsNothing);
      await tester.tap(find.text('See All 3 Reviews'));
      await tester.pump();
      expect(find.textContaining('Review body number 2'), findsOneWidget);
      expect(find.textContaining('Review body number 3'), findsOneWidget);
      await tester.tap(find.text('Show Fewer Reviews'));
      await tester.pump();
      expect(find.textContaining('Review body number 2'), findsNothing);
    });

    testWidgets('a course with more reviews than the page says how many are shown, and stays in the app', (
      tester,
    ) async {
      final fake = _Fake(
        catalogue: [_rich()],
        reviewList: CourseReviews(items: [_review(1), _review(2)], total: 41),
      );
      await pumpSheet(tester, fake);
      await tester.tap(find.text('See All 41 Reviews'));
      await tester.pump();
      expect(find.textContaining('Review body number 2'), findsOneWidget);
      expect(find.text('Showing the newest 2 of 41.'), findsOneWidget);
      expect(find.text('read all 41 reviews on the website'), findsNothing);
      await tester.tap(find.text('Show Fewer Reviews'));
      await tester.pump();
      expect(find.textContaining('Review body number 2'), findsNothing);
      expect(launches.urls, isEmpty);
    });

    testWidgets('one review has no list to open, and no reviews draws nothing', (tester) async {
      await pumpSheet(
        tester,
        _Fake(
          catalogue: [_rich()],
          reviewList: CourseReviews(items: [_review(1)], total: 1),
        ),
      );
      expect(find.textContaining('Review body number 1'), findsOneWidget);
      expect(find.byKey(const ValueKey('reviews-toggle')), findsNothing);
      await pumpSheet(tester, _Fake(catalogue: [_rich()]));
      expect(find.textContaining('Review body'), findsNothing);
    });

    testWidgets('a course with no certificate has no About the Certificate section', (tester) async {
      await pumpSheet(tester, _Fake(catalogue: [_rich(code: 'NOC', certificate: false)]));
      expect(find.text('About the Certificate'), findsNothing);
      expect(find.text('LEADERSHIP COURSE'), findsOneWidget, reason: 'the pill falls back to the level');
    });
  });
}

/// The demo source, except that enrolling fails.
class _Refusing implements LearningRepository {
  _Refusing(this.inner);

  final LearningRepository inner;

  @override
  Future<void> withdraw(Course course) => inner.withdraw(course);

  @override
  Future<MyEnrolment> enrol(Course course, {CourseRun? run}) async =>
      throw ApiError('No places today.', statusCode: 400);

  @override
  Future<List<Course>> courses() => inner.courses();
  @override
  Future<Course> detail(Course course) => inner.detail(course);
  @override
  Future<List<MyEnrolment>> myEnrolments() => inner.myEnrolments();
  @override
  Future<CourseReviews> reviews(Course course) => inner.reviews(course);
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
