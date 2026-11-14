import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/features/payments/payment_screen.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/auth/token_store.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/core/widgets/title_bar.dart';
import 'package:icr_mobile/features/learning_assess/api_assess_repository.dart';
import 'package:icr_mobile/features/learning_assess/assess_format.dart';
import 'package:icr_mobile/features/learning_assess/assess_models.dart';
import 'package:icr_mobile/features/learning_assess/assess_styles.dart';
import 'package:icr_mobile/features/learning_assess/assessment_screen.dart';
import 'package:icr_mobile/features/learning_assess/catalogue_controller.dart';
import 'package:icr_mobile/features/learning_assess/demo_assess_repository.dart';
import 'package:icr_mobile/features/learning_assess/group_controller.dart';
import 'package:icr_mobile/features/learning_assess/mock_tests_screen.dart';
import 'package:icr_mobile/features/learning_assess/widgets/assess_bar.dart';
import 'package:icr_mobile/features/learning_assess/widgets/group_card.dart';
import 'package:icr_mobile/features/learning_assess/widgets/knowledge_areas.dart'
    show KnowledgeAreas, TopicChip, defaultAreasBlurb;
import 'package:icr_mobile/features/learning_assess/widgets/paper_card.dart';
import 'package:icr_mobile/features/learning_assess/widgets/states.dart';
import 'package:icr_mobile/features/learning_exam/certificate_marks.dart';
import 'package:icr_mobile/features/learning_exam/certificate_pdf.dart' show CertificateMarks;
import 'package:icr_mobile/features/notifications/demo_notifications_repository.dart';
import 'package:icr_mobile/features/notifications/notifications_repository.dart';
import 'package:icr_mobile/features/notifications/notifications_screen.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import 'helpers/assess_fixtures.dart';
import 'helpers/layout_audit.dart';
import 'helpers/fonts.dart';

// --- harness --------------------------------------------------------------------------------------

/// Stands in for the app's payment view: records the gateway's form and answers that the payment went through.
List<({String action, Map<String, String> fields})> _stubPayments({PaymentOutcome outcome = PaymentOutcome.success}) {
  final paid = <({String action, Map<String, String> fields})>[];
  PaymentServices.pay = (_, {required action, required fields, title = 'Payment'}) async {
    paid.add((action: action, fields: fields));
    return outcome;
  };
  addTearDown(PaymentServices.reset);
  return paid;
}

class _H {
  _H(this.fake, this.opener);

  final FakeAssess fake;
  final RecordingOpener opener;
  final launcher = RecordingLauncher();

  /// Where payment pages go: the phone's browser, kept apart from the pages the app may draw itself.
  final pay = RecordingLauncher();
  int backs = 0;

  /// What was handed to the phone's share sheet.
  final shared = <(String, Uri)>[];
}

void _phone(WidgetTester tester, double height) {
  tester.view.physicalSize = Size(780, height * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

Future<_H> _landing(
  WidgetTester tester, {
  FakeAssess? fake,
  RecordingOpener? opener,
  bool mock = false,
  double height = 1500,
  bool settle = true,
}) async {
  _phone(tester, height);
  final h = _H(fake ?? FakeAssess(), opener ?? RecordingOpener());
  final Widget screen = mock
      ? MockTestsScreen(
          onBack: () => h.backs++,
          repository: h.fake,
          opener: h.opener.call,
          launcher: h.launcher.call,
          payLauncher: h.pay.call,
          share: (title, link) async => h.shared.add((title, link)),
        )
      : AssessmentScreen(
          onBack: () => h.backs++,
          repository: h.fake,
          opener: h.opener.call,
          launcher: h.launcher.call,
          payLauncher: h.pay.call,
          share: (title, link) async => h.shared.add((title, link)),
        );
  // A tree left from an earlier landing in the same test would keep its controller: start from nothing.
  await tester.pumpWidget(const SizedBox());
  // The bell opens the app's notifications, which read their repository from above the screen.
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: Provider<NotificationsRepository>.value(value: DemoNotificationsRepository(), child: screen),
    ),
  );
  if (settle) await tester.pumpAndSettle();
  return h;
}

/// Opens a group from the landing, with a tall view so every card is laid out and tappable.
Future<_H> _group(
  WidgetTester tester,
  String title, {
  FakeAssess? fake,
  RecordingOpener? opener,
  bool mock = false,
  double height = 3600,
}) async {
  final h = await _landing(tester, fake: fake, opener: opener, mock: mock, height: height);
  await tester.tap(find.descendant(of: find.byType(GroupCard), matching: find.text(title)).first);
  await tester.pumpAndSettle();
  return h;
}

Finder _card(String paperId) => find.byKey(ValueKey('paper-$paperId'));

Finder _button(String paperId, String label) =>
    find.descendant(of: _card(paperId), matching: find.widgetWithText(RowButton, label));

Finder _in(String paperId, Finder what) => find.descendant(of: _card(paperId), matching: what);

/// The certificate the API returns for a paper the member passed.
ExamCertificate _certificate(String paperId) => ExamCertificate(
  id: 'cert-$paperId',
  certificateId: 'ICR-CP-2026-TEST0001',
  title: 'Capital Planning',
  paperId: paperId,
  level: 'FOUNDATION',
  issuedAt: DateTime(2026, 11, 3),
  clearedAt: DateTime(2026, 11, 3),
  percentage: 100,
  passPercentage: 70,
);

RowButton _btn(WidgetTester tester, Finder finder) => tester.widget<RowButton>(finder);

/// Pulls a list down far enough for its refresh indicator (a quarter of its height).
Future<void> _pull(WidgetTester tester, Finder list) async {
  await tester.fling(list, const Offset(0, 1800), 2000);
  await tester.pumpAndSettle();
}

Future<void> _back(WidgetTester tester) async {
  await tester.tap(find.byIcon(Symbols.arrow_back).last);
  await tester.pumpAndSettle();
}

List<String> _titles(WidgetTester tester) => [
  for (final c in tester.widgetList<GroupCard>(find.byType(GroupCard))) c.group.title,
];

// --- the API as a table ------------------------------------------------------------------------------

class _NoTokens extends TokenStore {
  @override
  Future<String?> accessToken() async => 'token';
  @override
  Future<String?> refreshToken() async => null;
}

class _Api implements HttpClientAdapter {
  _Api(this.routes);

  final Map<String, Object Function(RequestOptions options)> routes;
  final calls = <String>[];
  final bodies = <Object?>[];
  final queries = <Map<String, dynamic>>[];

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

ApiAssessRepository _repo(_Api api) {
  final client = ApiClient(tokens: _NoTokens(), baseUrl: 'http://api.test/api/v1');
  client.dio.httpClientAdapter = api;
  return ApiAssessRepository(api: client);
}

Map<String, Object?> _paperJson(
  String id,
  String slug,
  String title, {
  String kind = 'ASSESSMENT',
  String? level,
  String access = 'FREE',
  int? price,
  int? questionCount,
  int? served = 10,
  int? limit,
  String? courseId,
  String? topicId,
  String? image,
}) => {
  'id': id,
  'kind': kind,
  'slug': slug,
  'title': title,
  'subtitle': null,
  'description': '',
  'level': level,
  'access': access,
  'priceAmount': price,
  'priceCurrency': 'INR',
  'creditCost': null,
  'durationMinutes': 30,
  'passPercentage': 70,
  'questionCount': questionCount,
  'servedQuestions': served,
  'availableQuestions': 10,
  'attemptLimit': limit,
  'certificateEnabled': kind == 'ASSESSMENT',
  'courseId': courseId,
  'topicId': topicId,
  'sortOrder': 0,
  'imageUrl': image,
};

Map<String, Object?> _courseJson(
  String id,
  String code,
  String title, {
  String? image,
  Map<String, Object?>? provider,
  List<Object?> papers = const [],
  List<String> areas = const [],
}) => {
  'id': id,
  'kind': 'ASSESSMENT',
  'code': code,
  'title': title,
  'slug': title.toLowerCase().replaceAll(' ', '-'),
  'summary': '',
  'imageUrl': image,
  'knowledgeAreas': areas,
  'sortOrder': 0,
  'provider': provider,
  'papers': papers,
};

void main() {
  setUpAll(loadAppFonts);

  // --- formatting ----------------------------------------------------------------------------------

  group('format', () {
    test('rupees keeps paise only when there are some, with Indian grouping', () {
      expect(rupees(49900), '₹499');
      expect(rupees(1180000), '₹11,800');
      expect(rupees(58882), '₹588.82');
      expect(rupees(12345600), '₹1,23,456');
      expect(rupees(100, 'AED'), 'AED 1');
    });

    test('credits, durations, attempts and plurals read as sentences', () {
      expect(creditsLabel(1), '1 ICR credit');
      expect(creditsLabel(5), '5 ICR credits');
      expect(creditsShort(1), '1 credit');
      expect(creditsLabelTitle(1), '1 ICR Credit', reason: 'a button and a dialog title are in Title Case');
      expect(creditsLabelTitle(5), '5 ICR Credits');
      expect(creditsShortTitle(3), '3 Credits');
      expect(durationLabel(30), '30 min');
      expect(durationLabel(60), '1 h');
      expect(durationLabel(90), '1 h 30 min');
      expect(attemptsLabel(1), '1 attempt');
      expect(attemptsUsedLabel(2, 3), '2 of 3 attempts used');
      expect(attemptsUsedLabel(2, null), '2 attempts');
      expect(attemptsUsedLabel(0, null), 'Unlimited attempts');
      expect(plural(1, 'set'), '1 set');
      expect(plural(2, 'mock exam', 'mock exams'), '2 mock exams');
      expect(setNumber(0), 'SET 01');
      expect(setNumber(11), 'SET 12');
    });

    test('a programme card says its levels in the order they are climbed, a subject its sets and questions', () {
      final cp = assessWorld().firstWhere((g) => g.key == 'CP');
      expect(levelsLine(cp), 'Foundation · Professional · Advanced');
      final hc = assessWorld().firstWhere((g) => g.key == 'HC');
      expect(levelsLine(hc), 'Foundation · Advanced');
      final topics = mockWorld();
      expect(setsLine(topics.first), '2 sets · 10 questions');
      final mixed = topic('t', 'T', [mockSet('t', 1, questions: 10), mockSet('t', 2, questions: 25)]);
      expect(setsLine(mixed), '2 sets · 10–25 questions');
      expect(paperName(cp.papers.first, cp), 'Capital Planning – Foundation');
      expect(showingLine(2, 9, 'subjects'), 'Showing 2 of 9 subjects.');
    });
  });

  // --- the model's rules -----------------------------------------------------------------------------

  group('what the member holds', () {
    test('a course stands open, pick or locked against the plan places, as the website counts them', () {
      const none = MemberAccess(courses: PlanPlaces(limit: 0));
      expect(none.stateOf(PaperKind.assessment, 'c1'), PlaceState.locked);
      const two = MemberAccess(courses: PlanPlaces(limit: 2, opened: ['a']));
      expect(two.stateOf(PaperKind.assessment, 'a'), PlaceState.open);
      expect(two.stateOf(PaperKind.assessment, 'b'), PlaceState.pick);
      const used = MemberAccess(courses: PlanPlaces(limit: 2, opened: ['a', 'b']));
      expect(used.stateOf(PaperKind.assessment, 'c'), PlaceState.locked);
      // The oldest `limit` opens are the open ones: a plan whose number dropped locks the later choice.
      const dropped = MemberAccess(courses: PlanPlaces(limit: 1, opened: ['a', 'b']));
      expect(dropped.stateOf(PaperKind.assessment, 'a'), PlaceState.open);
      expect(dropped.stateOf(PaperKind.assessment, 'b'), PlaceState.locked);
      expect(const MemberAccess().stateOf(PaperKind.assessment, 'x'), PlaceState.open, reason: 'no number: all open');
      expect(none.stateOf(PaperKind.assessment, null), PlaceState.open);
      expect(
        const MemberAccess(allOpen: true, courses: PlanPlaces(limit: 0)).stateOf(PaperKind.mock, 'x'),
        PlaceState.open,
      );
    });

    test('mock exams count against their own number, not the courses', () {
      const m = MemberAccess(courses: PlanPlaces(limit: 5), mocks: PlanPlaces(limit: 0));
      expect(m.stateOf(PaperKind.assessment, 'c'), PlaceState.pick);
      expect(m.stateOf(PaperKind.mock, 't'), PlaceState.locked);
      expect(m.noneIncluded(PaperKind.mock), isTrue);
      expect(m.noneIncluded(PaperKind.assessment), isFalse);
    });

    test('a paper unlocked on its own is open whatever the plan says', () {
      final paper = level('cp', 'FOUNDATION');
      const locked = MemberAccess(courses: PlanPlaces(limit: 0));
      expect(locked.accessOf(paper), PaperAccess.closed);
      expect(locked.copyWith(paperIds: {paper.id}).accessOf(paper), PaperAccess.open);
      const pick = MemberAccess(courses: PlanPlaces(limit: 1));
      expect(pick.accessOf(paper), PaperAccess.planPlace);
      expect(MemberLearning.none.accessOf(paper), PaperAccess.open, reason: 'unknown: openPaper decides');
    });

    test('best score, passes and attempts add up one sitting at a time', () {
      var p = PaperProgress.none;
      expect(p.started, isFalse);
      p = p.withAttempt(percent: 40, score: 4, maxScore: 10, passed: false, at: DateTime.utc(2026, 10, 1));
      p = p.withAttempt(percent: 80, score: 8, maxScore: 10, passed: true, at: DateTime.utc(2026, 10, 3));
      p = p.withAttempt(percent: 60, score: 6, maxScore: 10, passed: false, at: DateTime.utc(2026, 10, 2));
      expect(p.attempts, 3);
      expect(p.bestPercent, 80);
      expect(p.bestScore, 8);
      expect(p.passed, isTrue, reason: 'a later weaker sitting does not take the pass back');
      expect(p.lastAt, DateTime.utc(2026, 10, 3));
    });

    test('a group lists its levels as they are climbed and is found by any word of its text', () {
      final g = programme(
        'X',
        'Xylo Planning',
        [level('x', 'ADVANCED'), level('x', 'FOUNDATION'), level('x', 'INTERMEDIATE')],
        areas: const ['Alpha Beta'],
        summary: 'Gamma',
      );
      expect([for (final p in g.ladder) p.level], ['FOUNDATION', 'INTERMEDIATE', 'ADVANCED']);
      expect(
        g.haystack,
        allOf(contains('xylo planning'), contains('gamma'), contains('professional'), isNot(contains('alpha beta'))),
      );
      expect(
        assessLevelLabel('INTERMEDIATE'),
        'Professional',
        reason: '"Intermediate" is not a name anyone should see',
      );
    });
  });

  // --- the API source -------------------------------------------------------------------------------

  group('the API source', () {
    test('programmes are the assessment courses paired with their papers; one with none is left out', () async {
      final api = _Api({
        'GET /learning/courses': (_) => [
          _courseJson('c1', 'CP', 'Capital Planning', image: '/uploads/cp.png', areas: ['Alpha', ' ', 'Beta']),
          _courseJson('c2', 'EMPTY', 'Nothing Yet'),
          _courseJson('c3', 'LEO', 'Leoron Planner', provider: {'id': 'p', 'name': 'Leoron Institute'}),
          _courseJson('c4', 'CM', 'Contract Management'),
        ],
        'GET /learning/papers': (_) => [
          _paperJson('p1', 'cp-foundation', 'Foundation', level: 'FOUNDATION', courseId: 'c1'),
          _paperJson(
            'p2',
            'cp-advanced',
            'Advanced',
            level: 'ADVANCED',
            courseId: 'c1',
            access: 'PAID',
            price: 79900,
            limit: 3,
          ),
          _paperJson('p3', 'leo-1', 'Foundation', level: 'FOUNDATION', courseId: 'c3'),
          _paperJson('p4', 'cm-1', 'Foundation', level: 'FOUNDATION', courseId: 'c4', image: '/uploads/cm-paper.png'),
          _paperJson('p5', 'orphan', 'Loose', courseId: null),
        ],
      });
      final groups = await _repo(api).groups(PaperKind.assessment);
      expect(groups.map((g) => g.key), ['CP', 'LEO', 'CM']);
      expect(api.queries[api.calls.indexOf('GET /learning/courses')]['kind'], 'ASSESSMENT');
      expect(api.queries[api.calls.indexOf('GET /learning/papers')]['kind'], 'ASSESSMENT');

      final cp = groups.first;
      expect(cp.kind, PaperKind.assessment);
      expect(cp.id, 'c1');
      expect(cp.title, 'Capital Planning');
      expect(cp.summary, isNull, reason: 'a blank summary is no summary');
      expect(cp.knowledgeAreas, ['Alpha', 'Beta']);
      expect(cp.cover!.url, 'http://api.test/uploads/cp.png', reason: '/uploads paths are served beside the API');
      expect(cp.isPartner, isFalse);
      expect(cp.papers.length, 2);
      final adv = cp.papers.last;
      expect(adv.slug, 'cp-advanced');
      expect(adv.free, isFalse);
      expect(adv.priceAmount, 79900);
      expect(adv.priced, isTrue);
      expect(adv.attemptLimit, 3);
      expect(adv.questions, 10);
      expect(adv.durationMinutes, 30);
      expect(adv.passPercentage, 70);
      expect(adv.courseId, 'c1');
      expect(adv.targetId, 'c1');
      expect(adv.levelName, 'Advanced');

      expect(groups[1].partner, 'Leoron Institute');
      expect(groups[1].isPartner, isTrue);
      // A programme with no artwork borrows its first paper's.
      expect(groups.last.cover!.url, 'http://api.test/uploads/cm-paper.png');
    });

    test('the questions a sitting serves come from the served count, then the paper\'s own, then the bank', () async {
      final api = _Api({
        'GET /learning/courses': (_) => [_courseJson('c1', 'CP', 'Capital Planning')],
        'GET /learning/papers': (_) => [
          _paperJson('p1', 'a', 'Foundation', level: 'FOUNDATION', courseId: 'c1', served: 7),
          _paperJson('p2', 'b', 'Advanced', level: 'ADVANCED', courseId: 'c1', served: null, questionCount: 12),
        ],
      });
      final cp = (await _repo(api).groups(PaperKind.assessment)).single;
      expect([for (final p in cp.papers) p.questions], [7, 12]);
    });

    test('subjects come from the topics, each paper filed under its topic; one with no set is left out', () async {
      final api = _Api({
        'GET /learning/topics': (_) => [
          {
            'id': 't1',
            'slug': 'aee-cbcp',
            'title': 'AEE CBCP',
            'description': 'Practice',
            'imageUrl': '/uploads/t1.png',
            'sortOrder': 2,
            'papers': [_paperJson('s1', 'aee-cbcp-set-1', 'Set 1', kind: 'MOCK', limit: 3)],
          },
          {'id': 't2', 'slug': 'empty', 'title': 'Empty', 'papers': []},
        ],
      });
      final topics = await _repo(api).groups(PaperKind.mock);
      expect(topics.length, 1);
      final t = topics.single;
      expect(t.kind, PaperKind.mock);
      expect(t.key, 'aee-cbcp');
      expect(t.summary, 'Practice');
      expect(t.sortOrder, 2);
      expect(t.cover!.url, 'http://api.test/uploads/t1.png');
      final set = t.papers.single;
      expect(set.kind, PaperKind.mock);
      expect(set.topicId, 't1');
      expect(set.targetId, 't1', reason: 'a mock set opens with its subject');
      expect(set.attemptLimit, 3);
    });

    test('one programme is read by its code, keeping its assessment levels and dropping any other paper', () async {
      final api = _Api({
        'GET /learning/courses/CP': (_) => _courseJson(
          'c1',
          'CP',
          'Capital Planning',
          areas: ['Alpha'],
          papers: [
            _paperJson('p1', 'cp-foundation', 'Foundation', level: 'FOUNDATION', courseId: 'c1'),
            _paperJson('m1', 'a-mock', 'Set 1', kind: 'MOCK', topicId: 't'),
          ],
        ),
        'GET /learning/topics/aee-cbcp': (_) => {
          'id': 't1',
          'slug': 'aee-cbcp',
          'title': 'AEE CBCP',
          'papers': [_paperJson('s1', 'aee-cbcp-set-1', 'Set 1', kind: 'MOCK')],
        },
      });
      final repo = _repo(api);
      final cp = await repo.group(PaperKind.assessment, 'CP');
      expect(cp.papers.map((p) => p.slug), ['cp-foundation']);
      expect(cp.knowledgeAreas, ['Alpha']);
      final t = await repo.group(PaperKind.mock, 'aee-cbcp');
      expect(t.papers.single.topicId, 't1', reason: 'a set carries the topic it was read under');

      await expectLater(
        repo.group(PaperKind.assessment, 'NOPE'),
        throwsA(isA<ApiError>().having((e) => e.statusCode, 'status', 404)),
      );
    });

    test('the member: unlocks, plan places, credits, certificates and each paper\'s attempts', () async {
      final api = _Api({
        'GET /learning/me/paper-unlocks': (_) => {
          'allOpen': false,
          'paperIds': ['p1', 'p2'],
          'creditPaperIds': ['p2'],
          'icrCredits': 100,
          'rupeesPerCredit': 100,
          'plan': {
            'assessmentCourses': {
              'limit': 2,
              'openedCourseIds': ['c1'],
            },
            'mockExams': {'limit': 0, 'openedTopicIds': <String>[]},
            'flashCardDecks': {'limit': 0, 'openedDeckIds': <String>[]},
            'upgradePlan': 'Pro Plus',
            'mockUpgradePlan': null,
          },
        },
        'GET /learning/me/attempts': (_) => [
          {
            'paperId': 'p1',
            'attempt': 2,
            'percentage': 80,
            'score': 8,
            'maxScore': 10,
            'passed': true,
            'submittedAt': '2026-10-02T10:00:00.000Z',
          },
          {
            'paperId': 'p1',
            'attempt': 1,
            'percentage': 40,
            'score': 4,
            'maxScore': 10,
            'passed': false,
            'submittedAt': '2026-10-01T10:00:00.000Z',
          },
          {
            'paperId': 'p3',
            'attempt': 1,
            'percentage': 55,
            'score': 5,
            'maxScore': 10,
            'passed': false,
            'submittedAt': '2026-10-01T10:00:00.000Z',
          },
        ],
        'GET /learning/me/certificates': (_) => [
          // Newest first: a paper holds the certificate it was issued once, the first record for it.
          {'paperId': 'p1', 'certificateId': 'ICR-1', 'title': 'Capital Planning', 'level': 'FOUNDATION'},
          {'paperId': 'p1', 'certificateId': 'ICR-OLD'},
        ],
      });
      final m = await _repo(api).member(PaperKind.assessment);
      expect(api.queries[1]['kind'], 'ASSESSMENT', reason: 'only this door\'s attempts are read');
      final a = m.access!;
      expect(a.allOpen, isFalse);
      expect(a.paperIds, {'p1', 'p2'});
      expect(a.creditPaperIds, {'p2'});
      expect(a.icrCredits, 100);
      expect(a.rupeesPerCredit, 100);
      expect(a.courses.limit, 2);
      expect(a.courses.opened, ['c1']);
      expect(a.courses.left, 1);
      expect(a.mocks.limit, 0);
      expect(a.upgradePlan, 'Pro Plus');
      expect(a.mockUpgradePlan, isNull);
      expect(m.certified, {'p1'});
      expect(m.certificates.keys, ['p1'], reason: 'the record a certified level opens');
      expect(m.certificates['p1']!.certificateId, 'ICR-1');
      expect(m.certificates['p1']!.levelLabel, 'Foundation');
      final p1 = m.progressOf('p1');
      expect(p1.attempts, 2);
      expect(p1.bestPercent, 80);
      expect(p1.bestScore, 8);
      expect(p1.maxScore, 10);
      expect(p1.passed, isTrue);
      expect(m.progressOf('p3').passed, isFalse);
      expect(m.progressOf('unknown').started, isFalse);
    });

    test('reads that fail leave their part empty rather than the whole screen', () async {
      final api = _Api({
        // No route for the unlocks (404), the attempts fail outright, the certificates answer.
        'GET /learning/me/attempts': (_) => (500, '{"message":"boom"}'),
        'GET /learning/me/certificates': (_) => [
          {'paperId': 'p9'},
        ],
      });
      final m = await _repo(api).member(PaperKind.mock);
      expect(m.access, isNull, reason: 'unknown unlocks: every paper reads open and openPaper decides');
      expect(m.progress, isEmpty);
      expect(m.certified, {'p9'});
      expect(api.queries[api.calls.indexOf('GET /learning/me/attempts')]['kind'], 'MOCK');
    });

    test('a quote carries the price after the discount and the credits that open the paper', () async {
      final api = _Api({
        'GET /learning/papers/cp-advanced/quote': (_) => {
          'listPaisa': 49900,
          'discountBps': 2500,
          'discountPaisa': 12475,
          'salePaisa': 37425,
          'taxBps': 1800,
          'taxPaisa': 6737,
          'totalPaisa': 44162,
          'paperId': 'p2',
          'levelTitle': 'Advanced',
          'programmeTitle': 'Capital Planning',
          'currency': 'INR',
          'payable': true,
          'alreadyOpen': false,
          'kind': 'ASSESSMENT',
          'memberDiscount': true,
          'memberPlan': 'Pro Plus',
          'credits': 4,
          'rupeesPerCredit': 100,
        },
      });
      final q = await _repo(api).quote(level('cp', 'ADVANCED', slug: 'cp-advanced'));
      expect(q.paperId, 'p2');
      expect(q.listPaisa, 49900);
      expect(q.salePaisa, 37425);
      expect(q.discountPaisa, 12475);
      expect(q.discountBps, 2500);
      expect(q.discounted, isTrue);
      expect(q.priced, isTrue);
      expect(q.payable, isTrue);
      expect(q.memberDiscount, isTrue);
      expect(q.memberPlan, 'Pro Plus');
      expect(q.credits, 4);
      expect(q.creditsWorthRupees, 400);
    });

    test('the bundle offer and the global discount', () async {
      final api = _Api({
        'GET /learning/assessment-bundles/CM/quote': (_) => {
          'offered': true,
          'payable': false,
          'courseCode': 'CM',
          'programmeTitle': 'Contract Management',
          'salePaisa': 160790,
          'separateSalePaisa': 183760,
          'savePaisa': 22970,
          'discountBps': 3000,
          'levels': [
            {'paperId': 'a', 'title': 'Foundation', 'level': 'FOUNDATION', 'listPaisa': 49900},
            {'paperId': 'b', 'title': 'Advanced', 'level': 'ADVANCED', 'listPaisa': 79900},
          ],
        },
        'GET /learning/assessment-pricing': (_) => {'discountPercent': 20, 'bundleDiscountPercent': 30},
      });
      final repo = _repo(api);
      final b = await repo.bundleQuote('CM');
      expect(b.offered, isTrue);
      expect(b.payable, isFalse);
      expect(b.levels, ['Foundation', 'Advanced']);
      expect(b.salePaisa, 160790);
      expect(b.savePaisa, 22970);
      expect(b.discountBps, 3000);
      final p = await repo.pricing();
      expect(p.discountPercent, 20);
      expect(p.bundleDiscountPercent, 30);
    });

    test(
      'redeeming posts to the paper\'s redeem route and reads what was spent; a refusal keeps the API\'s words',
      () async {
        var refuse = false;
        final api = _Api({
          'POST /learning/papers/cp-advanced/redeem': (_) => refuse
              ? (
                  403,
                  '{"statusCode":403,"code":"NO_CREDIT_LEFT","message":"This level takes 5 ICR credits, and you have 2. Buy it, or invite colleagues to ICR to earn more."}',
                )
              : {'unlocked': true, 'spent': 5, 'credits': 95},
        });
        final repo = _repo(api);
        final r = await repo.redeem(level('cp', 'ADVANCED', slug: 'cp-advanced'));
        expect(r.unlocked, isTrue);
        expect(r.spent, 5);
        expect(r.credits, 95);

        refuse = true;
        await expectLater(
          repo.redeem(level('cp', 'ADVANCED', slug: 'cp-advanced')),
          throwsA(
            isA<ApiError>()
                .having((e) => e.statusCode, 'status', 403)
                .having((e) => e.code, 'code', 'NO_CREDIT_LEFT')
                .having((e) => e.message, 'message', contains('you have 2')),
          ),
        );
      },
    );

    test(
      'opening with a plan place posts the target the API names: COURSE for a programme, MOCK_EXAM for a subject',
      () async {
        final api = _Api({
          'POST /learning/me/opens': (_) => {'opened': true, 'via': 'PLAN'},
        });
        final repo = _repo(api);
        await repo.openWithPlan(PaperKind.assessment, 'course-1');
        await repo.openWithPlan(PaperKind.mock, 'topic-1');
        expect(api.bodies, [
          {'target': 'COURSE', 'targetId': 'course-1'},
          {'target': 'MOCK_EXAM', 'targetId': 'topic-1'},
        ]);
      },
    );

    test('the bell reads the unread count; the links go to the website\'s own routes', () async {
      final api = _Api({
        'GET /notifications/unread-count': (_) => {'unread': 4},
      });
      final repo = _repo(api);
      expect(await repo.unreadNotifications(), 4);
      final cp = programme('CP', 'Capital Planning', [level('cp', 'FOUNDATION', slug: 'capital-planning-foundation')]);
      expect(repo.paperLink(cp, cp.papers.single).path, '/learning/assessment/cp/capital-planning-foundation');
      expect(repo.groupLink(cp).path, '/learning/assessment/cp');
      final t = topic('aee-cem', 'AEE CEM', [mockSet('aee-cem', 1)]);
      expect(repo.paperLink(t, t.papers.single).path, '/learning/mock-tests/aee-cem/aee-cem-set-1');
      expect(repo.groupLink(t).path, '/learning/mock-tests/aee-cem');
      expect(repo.plansLink().path, '/pricing/professional');
      expect(repo.partnerLink().path, '/learning/professional-development');
    });

    test('a failed read is an ApiError with the API\'s sentence', () async {
      final api = _Api({'GET /learning/topics': (_) => (500, '{"message":"The database is down."}')});
      await expectLater(
        _repo(api).groups(PaperKind.mock),
        throwsA(isA<ApiError>().having((e) => e.message, 'message', 'The database is down.')),
      );
    });
  });

  // --- the landing controller ---------------------------------------------------------------------------

  group('the landing controller', () {
    test('groups are ICR\'s own in the catalogue\'s order; the search needs every word somewhere in a group', () async {
      final fake = FakeAssess();
      final c = CatalogueController(repository: fake, kind: PaperKind.assessment);
      await c.start();
      expect(c.groups.map((g) => g.title), [
        'Capital Planning',
        'Contract Management',
        'Human Capital',
        'Procurement Management',
      ]);
      expect(c.hasPartner, isTrue);

      c.setSearch('contract');
      expect(c.visible.map((g) => g.key), ['CM']);
      c.setSearch('  foundation   advanced ');
      expect(c.visible.length, 4, reason: 'the words may land in different fields');
      c.setSearch('cp');
      expect(c.visible.map((g) => g.key), ['CP'], reason: 'the code is searched');
      c.setSearch('fca');
      expect(c.visible, isEmpty, reason: 'knowledge areas are not: a dozen programmes cover the same words');
      c.setSearch('professional human');
      expect(c.visible, isEmpty, reason: 'Human Capital has no Professional paper, and its level names are searched');
      c.reset();
      expect(c.narrowed, isFalse);
      expect(fake.count('groups'), 1, reason: 'the search narrows what is loaded; the API has no search');
    });

    test('the access facet keeps groups with a free paper, or a paid one', () async {
      final c = CatalogueController(repository: FakeAssess(), kind: PaperKind.assessment);
      await c.start();
      c.setFilter(AccessFilter.free);
      expect(c.visible.map((g) => g.key), ['CP', 'HC', 'PM']);
      c.setFilter(AccessFilter.paid);
      expect(c.visible.map((g) => g.key), ['CM', 'PM']);
      c.setFilter(AccessFilter.all);
      expect(c.visible.length, 4);
    });

    test('a subject is found by a set title too', () async {
      final c = CatalogueController(repository: FakeAssess(), kind: PaperKind.mock);
      await c.start();
      c.setSearch('set 3');
      expect(c.visible.map((g) => g.key), ['aee-cem']);
    });

    test('the summary counts what is open, passed and started for this member', () async {
      final fake = FakeAssess(
        member: assessMember(
          open: {'cp-foundation', 'cp-advanced'},
          progress: {
            'cp-foundation': const PaperProgress(attempts: 2, bestPercent: 40),
            'cp-advanced': const PaperProgress(attempts: 1, bestPercent: 90, passed: true),
          },
        ),
      );
      final c = CatalogueController(repository: fake, kind: PaperKind.assessment);
      await c.start();
      final s = c.summaryOf(c.groups.first);
      expect((s.total, s.open, s.passed, s.started, s.bestPercent, s.known), (3, 2, 1, 2, 90, true));
      expect(s.allOpen, isFalse);
      expect(c.summaryOf(c.groups[1]).noneOpen, isTrue);
    });

    test('a failed load keeps its words, and refreshing recovers', () async {
      final fake = FakeAssess()..failures['groups'] = ApiError('Offline.');
      final c = CatalogueController(repository: fake, kind: PaperKind.assessment);
      await c.start();
      expect(c.error, 'Offline.');
      expect(c.groups, isEmpty);
      fake.failures.clear();
      await c.refresh();
      expect(c.error, isNull);
      expect(c.groups, isNotEmpty);
    });

    test('a paper opened with credits shows open at once, and a plan place taken shows open at once', () async {
      final c = CatalogueController(
        repository: FakeAssess(
          member: assessMember(courses: const PlanPlaces(limit: 2), open: {}),
        ),
        kind: PaperKind.assessment,
      );
      await c.start();
      final p = level('cp', 'FOUNDATION');
      expect(c.member.accessOf(p), PaperAccess.planPlace);
      c.openPlaceLocally(PaperKind.assessment, 'course-cp');
      expect(c.member.accessOf(p), PaperAccess.open);
      c.openPlaceLocally(PaperKind.assessment, 'course-cp');
      expect(c.member.access!.courses.opened, ['course-cp'], reason: 'twice takes one place');

      final locked = CatalogueController(repository: FakeAssess(), kind: PaperKind.assessment);
      await locked.start();
      final q = level('cm', 'FOUNDATION');
      expect(locked.member.accessOf(q), PaperAccess.closed);
      locked.unlockLocally(q.id, credits: 95, withCredits: true);
      expect(locked.member.accessOf(q), PaperAccess.open);
      expect(locked.member.access!.icrCredits, 95);
      expect(locked.member.access!.redeemedWithCredits(q), isTrue);
    });
  });

  // --- the group controller ------------------------------------------------------------------------------

  group('the group controller', () {
    Future<(FakeAssess, CatalogueController, GroupController)> start(
      PaperGroup Function(List<PaperGroup>) pick, {
      FakeAssess? fake,
    }) async {
      final f = fake ?? FakeAssess();
      final catalogue = CatalogueController(repository: f, kind: PaperKind.assessment);
      await catalogue.start();
      final g = GroupController(repository: f, catalogue: catalogue, seed: pick(catalogue.groups));
      addTearDown(g.dispose);
      await g.start();
      return (f, catalogue, g);
    }

    test('a page opened from a catalogue nobody started still reads what the member holds', () async {
      // A flash-card deck's "Open the course", or a hub card, builds the catalogue and goes straight to the page:
      // without this the member's places are unknown and every level would read open.
      final f = FakeAssess();
      final seeded = CatalogueController(repository: f, kind: PaperKind.assessment);
      await seeded.start();
      final seed = seeded.groups.firstWhere((x) => x.key == 'CP');

      final fresh = CatalogueController(repository: f, kind: PaperKind.assessment); // never started
      expect(fresh.member.access, isNull);
      final g = GroupController(repository: f, catalogue: fresh, seed: seed);
      addTearDown(g.dispose);
      await g.start();

      expect(fresh.member.access, isNotNull, reason: "the page read the member's unlocks itself");
      expect(
        seed.papers.where((p) => fresh.member.accessOf(p) != PaperAccess.open),
        isNotEmpty,
        reason: 'the levels the member has not opened are not drawn open',
      );
    });

    test('quotes are read only for the papers closed to the member, once each', () async {
      final (fake, _, g) = await start((all) => all.firstWhere((x) => x.key == 'CP'));
      // Capital Planning: Advanced is open to Bharat; Foundation and Professional are closed.
      expect(
        fake.calls.where((c) => c.startsWith('quote:')),
        unorderedEquals(['quote:capital-planning-foundation', 'quote:capital-planning-professional']),
      );
      final open = g.entry(g.group.papers.firstWhere((p) => p.level == 'ADVANCED'));
      expect(open.isOpen, isTrue);
      expect(open.quote, isNull, reason: 'an open paper costs nothing, whatever a stale quote says');
      final closed = g.entry(g.group.papers.firstWhere((p) => p.level == 'FOUNDATION'));
      expect(closed.access, PaperAccess.closed);
      expect(closed.credits, 5);
      expect(closed.priced, isFalse);
    });

    test('a quote that fails leaves its card without a price rather than the page without cards', () async {
      final fake = FakeAssess()..failures['quote:capital-planning-foundation'] = ApiError('Quote failed');
      final (_, _, g) = await start((all) => all.firstWhere((x) => x.key == 'CP'), fake: fake);
      expect(g.error, isNull);
      expect(g.entry(g.group.papers.firstWhere((p) => p.level == 'FOUNDATION')).quote, isNull);
      expect(g.entry(g.group.papers.firstWhere((p) => p.level == 'INTERMEDIATE')).quote, isNotNull);
    });

    test('redeeming opens the paper and spends the credits; the bundle is read again', () async {
      final (fake, catalogue, g) = await start((all) => all.firstWhere((x) => x.key == 'CM'));
      final paper = g.group.papers.firstWhere((p) => p.level == 'FOUNDATION');
      final bundlesBefore = fake.count('bundleQuote');
      final message = await g.redeem(paper);
      expect(message, isNull);
      expect(fake.calls, contains('redeem:contract-management-foundation'));
      expect(catalogue.member.access!.icrCredits, 95);
      expect(g.entry(paper).isOpen, isTrue);
      expect(g.entry(paper).redeemed, isTrue);
      expect(g.redeemedPapers.map((p) => p.id), ['cm-foundation']);
      expect(fake.count('bundleQuote'), bundlesBefore + 1);
    });

    test('a refused redemption changes nothing and returns the API\'s sentence', () async {
      final fake = FakeAssess(member: assessMember(credits: 2, open: {}));
      final (_, catalogue, g) = await start((all) => all.firstWhere((x) => x.key == 'CM'), fake: fake);
      final paper = g.group.papers.firstWhere((p) => p.level == 'FOUNDATION');
      final message = await g.redeem(paper);
      expect(message, 'This level takes 5 ICR credits, and you have 2.');
      expect(g.entry(paper).isOpen, isFalse);
      expect(g.entry(paper).busy, isFalse, reason: 'the spinner stops');
      expect(catalogue.member.access!.icrCredits, 2);
      expect(g.redeemedPapers, isEmpty);
    });

    test('opening with a plan place takes the course\'s id and opens every level', () async {
      final fake = FakeAssess(
        member: assessMember(open: {}, courses: const PlanPlaces(limit: 1)),
      );
      final (_, catalogue, g) = await start((all) => all.firstWhere((x) => x.key == 'HC'), fake: fake);
      expect(g.placeState, PlaceState.pick);
      expect(await g.openWithPlan(), isNull);
      expect(fake.calls, contains('openWithPlan:assessment:course-hc'));
      expect(g.placeState, PlaceState.open);
      expect(g.group.papers.every((p) => g.entry(p).isOpen), isTrue);
      expect(catalogue.member.access!.courses.opened, ['course-hc']);
    });

    test('a refused plan place leaves the course as it was', () async {
      final fake = FakeAssess(
        member: assessMember(open: {}, courses: const PlanPlaces(limit: 1)),
      )..failures['openWithPlan'] = ApiError('Your plan has no course left to open.', statusCode: 403);
      final (_, catalogue, g) = await start((all) => all.firstWhere((x) => x.key == 'HC'), fake: fake);
      expect(await g.openWithPlan(), 'Your plan has no course left to open.');
      expect(g.placeState, PlaceState.pick);
      expect(g.openingWithPlan, isFalse);
      expect(catalogue.member.access!.courses.opened, isEmpty);
    });

    test('a programme that is gone is not found; any other failed refresh keeps what is on show', () async {
      final fake = FakeAssess();
      final (_, catalogue, g) = await start((all) => all.firstWhere((x) => x.key == 'CP'), fake: fake);
      fake.failures['group'] = ApiError('Offline.');
      await g.refresh();
      expect(g.error, 'Offline.');
      expect(g.notFound, isFalse);
      expect(g.group.papers, isNotEmpty);
      fake.failures.clear();
      fake.programmes = [
        for (final p in fake.programmes)
          if (p.key != 'CP') p,
      ];
      await g.refresh();
      expect(g.notFound, isTrue);
      expect(
        catalogue.groups.any((x) => x.key == 'CP'),
        isTrue,
        reason: 'the grid keeps its own copy until it reloads',
      );
    });

    test(
      'the bundle is read for a programme and for a mock subject alike, the discount only for a programme, and the bundle only once the unlocks are known',
      () async {
        final (fake, _, g) = await start((all) => all.firstWhere((x) => x.key == 'CP'));
        expect(fake.count('bundleQuote'), 1);
        expect(fake.calls, contains('bundleQuote:assessment:CP'));
        expect(fake.count('pricing'), 1);
        expect(g.bundle, isNotNull);
        final mockFake = FakeAssess();
        final mockCatalogue = CatalogueController(repository: mockFake, kind: PaperKind.mock);
        await mockCatalogue.start();
        final mg = GroupController(repository: mockFake, catalogue: mockCatalogue, seed: mockCatalogue.groups.first);
        addTearDown(mg.dispose);
        await mg.start();
        expect(mockFake.count('bundleQuote'), 1, reason: 'a mock exam has a bundle of sets (`mock-bundles`)');
        expect(mockFake.calls, contains('bundleQuote:mock:${mg.group.key}'));
        expect(mockFake.count('pricing'), 0);
        expect(mg.bundle, isNotNull);

        final none = FakeAssess(member: MemberLearning.none);
        final catalogue = CatalogueController(repository: none, kind: PaperKind.assessment);
        await catalogue.start();
        final ng = GroupController(repository: none, catalogue: catalogue, seed: catalogue.groups.first);
        addTearDown(ng.dispose);
        await ng.start();
        expect(none.count('bundleQuote'), 0);
      },
    );
  });

  // --- Assess Your Knowledge: the landing ----------------------------------------------------------

  group('Assess Your Knowledge: the landing', () {
    testWidgets(
      'one card per programme of ICR\'s own, in the catalogue\'s order, two to a row; a partner\'s is left out',
      (tester) async {
        await _landing(tester);
        expect(find.text('Knowledge Assessments'), findsOneWidget, reason: 'the title bar');
        expect(find.text('Validate Your Expertise.'), findsNothing, reason: 'no banner (owner, 3 Nov 2026)');
        expect(_titles(tester), ['Capital Planning', 'Contract Management', 'Human Capital', 'Procurement Management']);
        expect(find.text('Leoron Certified Planner'), findsNothing);
        final dxs = [for (final c in tester.widgetList(find.byType(GroupCard))) tester.getTopLeft(find.byWidget(c)).dx];
        expect(dxs[0], dxs[2], reason: 'first column');
        expect(dxs[1], dxs[3], reason: 'second column');
        expect(dxs[1], greaterThan(dxs[0]));
        expect(find.text('3 LEVELS'), findsNWidgets(3));
        expect(find.text('2 LEVELS'), findsOneWidget);
        expect(find.text('Foundation · Professional · Advanced'), findsNWidgets(3));
        expect(find.text('Foundation · Advanced'), findsOneWidget);
      },
    );

    testWidgets("Back goes back; the bell opens the app's notifications and shows the unread count", (tester) async {
      final h = await _landing(tester, fake: FakeAssess(unread: 3));
      expect(tester.widget<BellButton>(find.byType(BellButton)).unread, 3);
      await tester.tap(find.byIcon(Symbols.arrow_back));
      await tester.pump();
      expect(h.backs, 1);
      await tester.tap(find.byIcon(LucideIcons.bell));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsScreen), findsOneWidget);
      expect(h.launcher.uris, isEmpty, reason: 'the website is not opened');
    });

    testWidgets('the search narrows the grid as you type, says how many, and the clear button gives it back', (
      tester,
    ) async {
      final h = await _landing(tester);
      await tester.enterText(find.byType(TextField), 'contract');
      await tester.pumpAndSettle();
      expect(_titles(tester), ['Contract Management']);
      expect(find.text('Showing 1 of 4 certifications.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'cp');
      await tester.pumpAndSettle();
      expect(_titles(tester), ['Capital Planning'], reason: 'the code is searched');
      await tester.tap(find.byIcon(LucideIcons.x));
      await tester.pumpAndSettle();
      expect(_titles(tester).length, 4);
      expect(find.byKey(const ValueKey('showing')), findsNothing);
      expect(h.fake.count('groups'), 1, reason: 'the API cannot search; the loaded list is narrowed');
    });

    testWidgets('a search with no match says so, and Reset filters clears both the words and the facet', (
      tester,
    ) async {
      await _landing(tester);
      await tester.tap(find.text('Paid'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('No Certification Matches'), findsOneWidget);
      expect(find.byType(GroupCard), findsNothing);
      await tester.tap(find.text('Reset Filters'));
      await tester.pumpAndSettle();
      expect(_titles(tester).length, 4);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    });

    testWidgets('Free and Paid keep the programmes with a free paper, or a paid one; All brings them back', (
      tester,
    ) async {
      await _landing(tester);
      await tester.tap(find.text('Free'));
      await tester.pumpAndSettle();
      expect(_titles(tester), ['Capital Planning', 'Human Capital', 'Procurement Management']);
      await tester.tap(find.text('Paid'));
      await tester.pumpAndSettle();
      expect(_titles(tester), ['Contract Management', 'Procurement Management']);
      expect(find.text('Showing 2 of 4 certifications.'), findsOneWidget);
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      expect(_titles(tester).length, 4);
    });

    testWidgets('pulling down reads the programmes again', (tester) async {
      final h = await _landing(tester);
      await _pull(tester, find.byType(CustomScrollView));
      expect(h.fake.count('groups'), 2);
      expect(h.fake.count('member'), 2);
    });

    testWidgets('while it loads there are card-shaped blocks, then the cards', (tester) async {
      final gate = Completer<void>();
      final h = await _landing(tester, fake: FakeAssess()..gate = gate.future, settle: false);
      await tester.pump();
      expect(find.byType(GridSkeleton), findsOneWidget);
      expect(find.byType(GroupCard), findsNothing);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(GridSkeleton), findsNothing);
      expect(find.byType(GroupCard), findsNWidgets(4));
      expect(h.fake.count('groups'), 1);
    });

    testWidgets('a failed load says why, and Try again reads it again', (tester) async {
      final fake = FakeAssess()..failures['groups'] = ApiError("Can't reach ICR right now.");
      await _landing(tester, fake: fake);
      expect(find.text("Unable to Load the Assessments"), findsOneWidget);
      expect(find.text("Can't reach ICR right now."), findsOneWidget);
      fake.failures.clear();
      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();
      expect(find.byType(GroupCard), findsNWidgets(4));
    });

    testWidgets('with nothing published it says so; with only a partner\'s it points at Professional Development', (
      tester,
    ) async {
      await _landing(tester, fake: FakeAssess(programmes: []));
      expect(find.text('No Assessments Available Yet'), findsOneWidget);
      expect(find.text('Partner Certifications'), findsNothing);
    });

    testWidgets('only a partner\'s programmes: the page leads to them on the website', (tester) async {
      final partner = assessWorld().last;
      final h = await _landing(tester, fake: FakeAssess(programmes: [partner]));
      expect(find.text('No Assessments Available Yet'), findsOneWidget);
      expect(find.textContaining('awarded by partner institutes'), findsOneWidget);
      await tester.tap(find.text('Partner Certifications'));
      await tester.pump();
      expect(h.launcher.uris.single, Uri.parse('https://site.test/partners'));
    });

    testWidgets('beside ICR\'s own, a line leads to the partners\' certifications', (tester) async {
      final h = await _landing(tester);
      expect(find.textContaining('Looking for a partner institute'), findsOneWidget);
      await tester.tap(find.text('Partner Certifications'));
      await tester.pump();
      expect(h.launcher.uris.single.path, '/partners');
    });

    testWidgets('each card\'s foot says how much is open to the member and how they did', (tester) async {
      final fake = FakeAssess(
        member: assessMember(
          open: {'cp-advanced', 'cp-foundation', 'hc-foundation'},
          progress: {
            'cp-advanced': const PaperProgress(attempts: 2, bestPercent: 80, passed: true),
            'hc-foundation': const PaperProgress(attempts: 1, bestPercent: 40),
          },
        ),
      );
      await _landing(tester, fake: fake);
      expect(find.text('2 of 3 open'), findsOneWidget, reason: 'Capital Planning');
      expect(find.text('1 passed'), findsOneWidget);
      expect(find.text('1 of 2 open'), findsOneWidget, reason: 'Human Capital');
      expect(find.text('Best 40%'), findsOneWidget);
      expect(find.text('Locked'), findsNWidgets(2), reason: 'Contract and Procurement');
    });

    testWidgets('a programme the plan has a free place for says so rather than Locked', (tester) async {
      final fake = FakeAssess(
        member: assessMember(open: {}, courses: const PlanPlaces(limit: 1)),
      );
      await _landing(tester, fake: fake);
      expect(find.text('In Your Plan'), findsNWidgets(4));
      expect(find.text('Locked'), findsNothing);
    });

    testWidgets('everything open reads Open, and an all-passed programme says so', (tester) async {
      final fake = FakeAssess(
        member: assessMember(
          allOpen: true,
          progress: {
            for (final l in ['foundation', 'intermediate', 'advanced'])
              'cp-$l': const PaperProgress(attempts: 1, bestPercent: 90, passed: true),
          },
        ),
      );
      await _landing(tester, fake: fake);
      expect(find.text('Open'), findsNWidgets(4));
      expect(find.text('All passed'), findsOneWidget);
    });

    testWidgets('with the unlocks unknown the foot falls back to the catalogue\'s own facts', (tester) async {
      await _landing(tester, fake: FakeAssess(member: MemberLearning.none));
      expect(find.text('Free'), findsNWidgets(3), reason: 'two programmes and the facet chip');
      expect(find.text('Paid'), findsNWidgets(2), reason: 'Contract Management and the facet chip');
      expect(find.text('Free + paid'), findsOneWidget, reason: 'Procurement Management');
    });

    testWidgets('a card opens its programme; Back there returns to the grid', (tester) async {
      final h = await _landing(tester);
      await tester.tap(find.descendant(of: find.byType(GroupCard), matching: find.text('Capital Planning')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('hero-title')), findsOneWidget);
      expect(find.text('Capital Planning Assessment'), findsOneWidget);
      expect(h.fake.calls, contains('group:CP'));
      await _back(tester);
      expect(find.byKey(const ValueKey('hero-title')), findsNothing);
      expect(find.byType(GroupCard), findsNWidgets(4));
      expect(h.backs, 0, reason: 'Back on the programme pops it; it does not leave the door');
    });
  });

  // --- a narrow phone, long names ---------------------------------------------------------------------

  group('a 320 dp phone with very long names', () {
    final longProgramme = programme(
      'IWSBT',
      'Intelligent Workplace & Smart Building Technologies and Everything Around Them',
      [
        level('iw', 'FOUNDATION', price: 123456700, slug: 'iw-f'),
        level('iw', 'INTERMEDIATE', slug: 'iw-p'),
        level('iw', 'ADVANCED', slug: 'iw-a'),
      ],
      areas: const ['A knowledge area whose name runs on and on across more than one line of a very narrow screen'],
      summary:
          'A summary that is long enough to wrap over several lines on a narrow phone, to see that nothing is cut.',
    );

    testWidgets('the grid and the programme page lay out without overflow', (tester) async {
      final fake = FakeAssess(programmes: [longProgramme, ...assessWorld().take(2)]);
      fake.quotes = {
        ...fake.quotes,
        'iw-foundation': const PaperQuote(
          paperId: 'iw-foundation',
          listPaisa: 123456700,
          salePaisa: 123456700,
          payable: true,
          credits: 12346,
        ),
      };
      _phone(tester, 3600);
      tester.view.physicalSize = const Size(640, 7200);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: AssessmentScreen(
            onBack: () {},
            repository: fake,
            opener: RecordingOpener().call,
            launcher: RecordingLauncher().call,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.descendant(of: find.byType(GroupCard), matching: find.textContaining('Intelligent')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('hero-title')), findsOneWidget);
      // The priced level shows a six-figure price in full.
      expect(find.textContaining('₹12,34,567'), findsWidgets);
    });

    testWidgets('a mock subject page with long set titles and a long description does too', (tester) async {
      final t = topic('long', 'IFMA Certified Facility Manager Practice Papers For Global Competition', [
        mockSet(
          'long',
          1,
          description:
              'A description that runs over two lines of a narrow phone and is cut with an ellipsis after that second line.',
        ),
        mockSet('long', 2, price: 99999999, limit: 2),
      ]);
      _phone(tester, 3600);
      tester.view.physicalSize = const Size(640, 7200);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: MockTestsScreen(
            onBack: () {},
            repository: FakeAssess(topics: [t]),
            opener: RecordingOpener().call,
            launcher: RecordingLauncher().call,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(GroupCard));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Set 2'), findsOneWidget);
    });
  });

  // --- the widths phones come in --------------------------------------------------------------------------

  group("the programme page and the sets page at 390, 360 and 320 dp (the owner's one-view rule)", () {
    Future<void> at(WidgetTester tester, double width, Widget screen) async {
      tester.view.physicalSize = Size(width * 2, 4800 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: screen));
      await tester.pumpAndSettle();
    }

    final topics = [
      'MEP Systems',
      'HVAC Operations',
      'Life Safety & HSE',
      'Space Management',
      'CMMS/CAFM',
      'Maintenance',
      'Smart BMS/BAS',
      'A knowledge area whose name runs on and on across more than one line of a very narrow screen',
      'Net-Zero ESG',
    ];

    for (final width in [390.0, 360.0, 320.0]) {
      testWidgets('${width.round()} dp: levels open, closed, priced and sat, with no clipped text', (tester) async {
        final world = [
          programme('CP', 'Capital Planning', [
            level('cp', 'FOUNDATION', limit: 3),
            level('cp', 'INTERMEDIATE', price: 123456700, slug: 'cp-p'),
            level('cp', 'ADVANCED'),
          ], areas: topics),
        ];
        final fake = FakeAssess(
          programmes: world,
          member: assessMember(
            open: {'cp-foundation'},
            redeemed: {},
            progress: {'cp-foundation': const PaperProgress(attempts: 2, bestPercent: 40, bestScore: 4, maxScore: 10)},
            certified: {'cp-foundation'},
            // The certificate and the retake share one line, on the narrowest phone too.
            certificates: {'cp-foundation': _certificate('cp-foundation')},
          ),
        );
        fake.quotes = {
          ...fake.quotes,
          'cp-intermediate': const PaperQuote(
            paperId: 'cp-intermediate',
            listPaisa: 123456700,
            discountBps: 2500,
            discountPaisa: 30864175,
            salePaisa: 92592525,
            payable: true,
            memberDiscount: true,
            memberPlan: 'Pro Plus',
            credits: 12346,
          ),
        };
        await at(
          tester,
          width,
          AssessmentScreen(
            onBack: () {},
            repository: fake,
            opener: RecordingOpener().call,
            launcher: RecordingLauncher().call,
          ),
        );
        await tester.tap(find.descendant(of: find.byType(GroupCard), matching: find.text('Capital Planning')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(layoutProblems().where((p) => p.startsWith('clipped')), isEmpty);
        // Every card stays inside the screen, and the pair sits side by side.
        for (final id in ['cp-foundation', 'cp-advanced', 'cp-intermediate']) {
          final r = tester.getRect(_card(id));
          expect(r.left, greaterThanOrEqualTo(0));
          expect(r.right, lessThanOrEqualTo(width));
        }
        // One row per level, one under another (owner, 3 Nov 2026: list rows, not a grid of cards).
        expect(tester.getTopLeft(_card('cp-advanced')).dy, greaterThan(tester.getTopLeft(_card('cp-foundation')).dy));
        expect(find.textContaining('₹9,25,925.25'), findsOneWidget);
        expect(
          tester.getCenter(_button('cp-foundation', 'Certificate')).dy,
          tester.getCenter(_button('cp-foundation', 'Retake')).dy,
        );
      });

      testWidgets('${width.round()} dp: sets open, closed, priced and sat, with no clipped text', (tester) async {
        final t = topic(
          'long',
          'IFMA Certified Facility Manager Practice Papers For Global Competition',
          [
            mockSet(
              'long',
              1,
              limit: 3,
              description: 'A description that runs over three lines of a narrow phone and is cut after that. ' * 3,
            ),
            mockSet('long', 2, price: 99999999, limit: 2),
            mockSet('long', 3),
          ],
          description: 'The exam, in a sentence that is long enough to wrap on a narrow phone.',
        );
        final fake = FakeAssess(
          topics: [t],
          member: assessMember(
            open: {'long-set-1'},
            redeemed: {},
            progress: {'long-set-1': const PaperProgress(attempts: 3, bestPercent: 55, bestScore: 11, maxScore: 20)},
          ),
        );
        await at(
          tester,
          width,
          MockTestsScreen(
            onBack: () {},
            repository: fake,
            opener: RecordingOpener().call,
            launcher: RecordingLauncher().call,
          ),
        );
        await tester.tap(find.byType(GroupCard));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(layoutProblems().where((p) => p.startsWith('clipped')), isEmpty);
        for (final id in ['long-set-1', 'long-set-2', 'long-set-3']) {
          final r = tester.getRect(_card(id));
          expect(r.left, 0);
          expect(r.right, width);
        }
      });
    }
  });

  // --- Assess Your Knowledge: a programme's levels -----------------------------------------------------

  group('a programme\'s levels', () {
    testWidgets("a card per level the programme has, in the design's order; a rung it lacks is not drawn", (
      tester,
    ) async {
      await _group(tester, 'Human Capital');
      expect(_card('hc-foundation'), findsOneWidget);
      expect(_card('hc-advanced'), findsOneWidget);
      expect(find.byType(PaperCard), findsNWidgets(2), reason: 'Human Capital has no Professional paper');
      expect(find.text('Coming soon'), findsNothing);
      // Foundation then Advanced, one row under the other.
      final f = tester.getTopLeft(_card('hc-foundation'));
      final a = tester.getTopLeft(_card('hc-advanced'));
      expect(f.dy, lessThan(a.dy));
      expect(f.dx, a.dx);
      expect(find.text('Select Your Proficiency Level'), findsOneWidget);
    });

    testWidgets('Foundation, Advanced and Professional are full-width rows, one under another, no box', (tester) async {
      await _group(tester, 'Capital Planning');
      final f = tester.getRect(_card('cp-foundation'));
      final a = tester.getRect(_card('cp-advanced'));
      final p = tester.getRect(_card('cp-intermediate'));
      expect(a.top, greaterThanOrEqualTo(f.bottom));
      expect(p.top, greaterThanOrEqualTo(a.bottom));
      expect(f.width, a.width);
      expect(p.width, f.width);
      // No card around a row (owner, 3 Nov 2026: no borders, a thin line between rows is enough).
      expect(
        find.descendant(of: _card('cp-foundation'), matching: find.byType(DecoratedBox)).evaluate().where((e) {
          final d = (e.widget as DecoratedBox).decoration;
          return d is BoxDecoration && d.border != null;
        }),
        isEmpty,
      );
      // Each carries its name and its tagline.
      expect(_in('cp-foundation', find.text('Foundation')), findsOneWidget);
      expect(_in('cp-advanced', find.text('Advanced')), findsOneWidget);
      expect(_in('cp-intermediate', find.text('Professional')), findsOneWidget);
      expect(_in('cp-foundation', find.textContaining('Build your basics')), findsOneWidget);
      expect(_in('cp-advanced', find.textContaining('Go deeper')), findsOneWidget);
      expect(_in('cp-intermediate', find.textContaining('Prove your expertise')), findsOneWidget);
    });

    testWidgets("a paper filed at no known level follows the three rungs, in the API's order", (tester) async {
      final odd = AssessPaper(
        id: 'cp-odd',
        slug: 'cp-odd',
        title: 'Capstone',
        kind: PaperKind.assessment,
        courseId: 'course-cp',
      );
      final fake = FakeAssess(
        programmes: [
          programme('CP', 'Capital Planning', [odd, level('cp', 'ADVANCED'), level('cp', 'FOUNDATION')]),
        ],
      );
      await _group(tester, 'Capital Planning', fake: fake);
      final y = [
        for (final id in ['cp-foundation', 'cp-advanced', 'cp-odd']) tester.getTopLeft(_card(id)),
      ];
      expect(y[1].dy, greaterThan(y[0].dy));
      expect(y[2].dy, greaterThan(y[1].dy));
      expect(_in('cp-odd', find.text('Capstone')), findsOneWidget);
      expect(_in('cp-odd', find.text('Assessment')), findsOneWidget);
    });

    testWidgets("a level says its name, its tagline and the attempts it allows; the numbers are the brief's", (
      tester,
    ) async {
      final fake = FakeAssess(
        programmes: [
          programme('CP', 'Capital Planning', [
            level('cp', 'FOUNDATION', questions: 25, minutes: 90, pass: 60, limit: 3, slug: 'cp-f'),
          ]),
        ],
      );
      await _group(tester, 'Capital Planning', fake: fake);
      expect(_in('cp-foundation', find.text('Foundation')), findsOneWidget);
      // One line of what it is: the tagline, the numbers a candidate decides on, the attempts it allows.
      expect(
        _in(
          'cp-foundation',
          find.text('Build your basics · 25 questions · 1 h 30 min · 60% to pass · Up to 3 attempts'),
        ),
        findsOneWidget,
      );
      expect(find.byType(PaperCard), findsOneWidget, reason: 'the two rungs this programme lacks are not drawn');
    });

    testWidgets('an open level starts the exam; Start hands its paper over, then the sittings are read again', (
      tester,
    ) async {
      late FakeAssess fake;
      final opener = RecordingOpener(
        onOpen: (paper) async {
          // The exam took an attempt and passed.
          fake.memberNow = assessMember(
            open: {'cp-foundation', 'cp-advanced'},
            progress: {
              'cp-foundation': const PaperProgress(
                attempts: 1,
                bestPercent: 80,
                bestScore: 8,
                maxScore: 10,
                passed: true,
              ),
            },
            certified: {'cp-foundation'},
          );
        },
      );
      fake = FakeAssess(member: assessMember(open: {'cp-foundation', 'cp-advanced'}));
      await _group(tester, 'Capital Planning', fake: fake, opener: opener);
      expect(_button('cp-foundation', 'Start Assessment'), findsOneWidget);
      expect(_in('cp-foundation', find.textContaining('Best score 80% (8/10)')), findsNothing, reason: 'not sat yet');
      final membersBefore = fake.count('member');

      await tester.tap(_button('cp-foundation', 'Start Assessment'));
      await tester.pumpAndSettle();

      final ref = opener.opened.single;
      expect(ref.slug, 'capital-planning-foundation');
      expect(ref.title, 'Capital Planning – Foundation');
      expect(ref.id, 'cp-foundation');
      expect(ref.courseCode, 'CP');
      expect(ref.isMock, isFalse);
      expect(fake.count('member'), greaterThan(membersBefore), reason: 'the best score and attempts are read again');
      expect(_in('cp-foundation', find.textContaining('Best score 80% (8/10) · Passed · Certified')), findsOneWidget);
      expect(_button('cp-foundation', 'Retake Assessment'), findsOneWidget);
    });

    testWidgets('a certified level opens its certificate in the app, with Download PDF; Retake still starts again', (
      tester,
    ) async {
      final fake = FakeAssess(
        member: assessMember(
          open: {'cp-foundation', 'cp-advanced'},
          progress: {
            'cp-foundation': const PaperProgress(
              attempts: 1,
              bestPercent: 100,
              bestScore: 50,
              maxScore: 50,
              passed: true,
            ),
            'cp-advanced': const PaperProgress(attempts: 2, bestPercent: 4, bestScore: 2, maxScore: 50),
          },
          certificates: {'cp-foundation': _certificate('cp-foundation')},
        ),
      );
      final opener = RecordingOpener();
      await _group(tester, 'Capital Planning', fake: fake, opener: opener);
      expect(_in('cp-foundation', find.textContaining('Passed · Certified')), findsOneWidget);
      expect(_button('cp-foundation', 'Certificate'), findsOneWidget);
      expect(_button('cp-foundation', 'Retake'), findsOneWidget);
      // Side by side: the certificate first, the retake beside it.
      expect(
        tester.getCenter(_button('cp-foundation', 'Certificate')).dx,
        lessThan(tester.getCenter(_button('cp-foundation', 'Retake')).dx),
      );
      expect(
        tester.getCenter(_button('cp-foundation', 'Certificate')).dy,
        tester.getCenter(_button('cp-foundation', 'Retake')).dy,
      );
      // A level sat but not passed has no certificate to show.
      expect(_button('cp-advanced', 'Certificate'), findsNothing);
      expect(_button('cp-advanced', 'Retake Assessment'), findsOneWidget);

      await tester.tap(_button('cp-foundation', 'Certificate'));
      await tester.pumpAndSettle();
      expect(find.text('Certificate of Knowledge Assessment'), findsOneWidget);
      expect(find.text('ICR-CP-2026-TEST0001'), findsWidgets);
      expect(opener.opened, isEmpty, reason: 'the certificate is not a retake');

      // Download PDF builds it in the app and hands it to the phone's save sheet.
      final saved = <String>[];
      CertificatePdfServices.marks = (c, holder) async => const CertificateMarks();
      CertificatePdfServices.save = (name, bytes) async {
        saved.add(name);
        return Uri.file('/storage/emulated/0/Download/$name');
      };
      addTearDown(CertificatePdfServices.reset);
      await tester.ensureVisible(find.text('Download PDF'));
      await tester.pump();
      await tester.tap(find.text('Download PDF'));
      for (var i = 0; i < 400 && saved.isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(saved, ['ICR-CP-2026-TEST0001.pdf']);
      expect(find.text('Saved ICR-CP-2026-TEST0001.pdf'), findsOneWidget);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await tester.tap(_button('cp-foundation', 'Retake'));
      await tester.pumpAndSettle();
      expect(opener.opened.single.slug, 'capital-planning-foundation');
    });

    testWidgets('a certificate earned on a level that has since closed is still there, above the ways to open it', (
      tester,
    ) async {
      final fake = FakeAssess(
        member: assessMember(
          open: {},
          redeemed: {},
          progress: {'cp-advanced': const PaperProgress(attempts: 1, bestPercent: 90, passed: true)},
          certificates: {'cp-advanced': _certificate('cp-advanced')},
        ),
      );
      await _group(tester, 'Capital Planning', fake: fake);
      final certificate = _button('cp-advanced', 'Certificate');
      expect(certificate, findsOneWidget);
      expect(_btn(tester, certificate).onPressed, isNotNull);
      await tester.tap(certificate);
      await tester.pumpAndSettle();
      expect(find.text('Certificate of Knowledge Assessment'), findsOneWidget);
    });

    testWidgets('a level sat but not passed shows its best score against the pass mark; Retake starts again', (
      tester,
    ) async {
      final fake = FakeAssess(
        member: assessMember(
          open: {'cp-foundation', 'cp-advanced'},
          progress: {'cp-foundation': const PaperProgress(attempts: 2, bestPercent: 40, bestScore: 4, maxScore: 10)},
        ),
      );
      final opener = RecordingOpener();
      await _group(tester, 'Capital Planning', fake: fake, opener: opener);
      expect(_in('cp-foundation', find.text('Best score 40% (4/10) · Not passed yet · 2 attempts')), findsOneWidget);
      await tester.tap(_button('cp-foundation', 'Retake Assessment'));
      await tester.pumpAndSettle();
      expect(opener.opened.single.slug, 'capital-planning-foundation');
    });

    testWidgets('a level whose attempts are all used cannot be started again', (tester) async {
      final fake = FakeAssess(
        programmes: [
          programme('CP', 'Capital Planning', [level('cp', 'FOUNDATION', limit: 2, slug: 'cp-f')]),
        ],
        member: assessMember(
          open: {'cp-foundation'},
          progress: {'cp-foundation': const PaperProgress(attempts: 2, bestPercent: 50)},
        ),
      );
      final opener = RecordingOpener();
      await _group(tester, 'Capital Planning', fake: fake, opener: opener);
      expect(_in('cp-foundation', find.textContaining('All 2 attempts used')), findsOneWidget);
      final button = _button('cp-foundation', 'No Attempts Left');
      expect(_btn(tester, button).onPressed, isNull);
      await tester.tap(button, warnIfMissed: false);
      await tester.pump();
      expect(opener.opened, isEmpty);
    });

    testWidgets(
      'a priced level shows its price and the credits that open it; Pay goes to the paper\'s page on the website',
      (tester) async {
        final h = await _group(tester, 'Contract Management');
        expect(_in('cm-foundation', find.text('₹499 + GST')), findsOneWidget);
        expect(_in('cm-foundation', find.text('or 5 ICR credits')), findsOneWidget);
        expect(_in('cm-intermediate', find.text('₹999 + GST')), findsOneWidget);
        expect(_in('cm-intermediate', find.text('or 10 ICR credits')), findsOneWidget);
        final paid = _stubPayments();
        await tester.tap(_button('cm-foundation', 'Pay Now'));
        await tester.pumpAndSettle();
        expect(h.fake.checkouts, ['contract-management-foundation'], reason: "the level's own checkout");
        expect(paid.single.action, 'https://pay.test/_payment', reason: "the gateway's form, run in the app");
        expect(find.text('Payment received. Contract Management – Foundation is open.'), findsOneWidget);
        expect(h.pay.uris, isEmpty, reason: "a payment runs in the app, never in the phone's browser");
        expect(h.launcher.uris, isEmpty, reason: 'a payment is not a page the app draws itself');
        expect(h.opener.opened, isEmpty, reason: 'a closed level is paid for or redeemed first, never started');
      },
    );

    testWidgets('a discounted price shows the list price struck through, the percent off and what it saves', (
      tester,
    ) async {
      final fake = FakeAssess();
      fake.quotes = {
        ...fake.quotes,
        'cm-foundation': const PaperQuote(
          paperId: 'cm-foundation',
          listPaisa: 49900,
          discountBps: 2500,
          discountPaisa: 12475,
          salePaisa: 37425,
          taxBps: 1800,
          taxPaisa: 6737,
          totalPaisa: 44162,
          payable: true,
          memberDiscount: true,
          memberPlan: 'Pro Plus',
          credits: 4,
        ),
      };
      await _group(tester, 'Contract Management', fake: fake);
      expect(_in('cm-foundation', find.text('₹374.25 + GST')), findsOneWidget);
      // Under it, one line: the list price struck through, the percent off, the plan's price, the credits.
      expect(_in('cm-foundation', find.text('₹499  25% off  Pro Plus member price  or 4 ICR credits')), findsOneWidget);
    });

    testWidgets('while payment is unavailable Pay is off and says why', (tester) async {
      final fake = FakeAssess();
      fake.quotes = {
        ...fake.quotes,
        'cm-foundation': const PaperQuote(paperId: 'cm-foundation', listPaisa: 49900, salePaisa: 49900, credits: 5),
      };
      final h = await _group(tester, 'Contract Management', fake: fake);
      final pay = _button('cm-foundation', 'Pay Now');
      expect(_btn(tester, pay).onPressed, isNull);
      expect(_in('cm-foundation', find.text('Online payment is not available right now.')), findsOneWidget);
      await tester.tap(pay, warnIfMissed: false);
      await tester.pump();
      expect(h.launcher.uris, isEmpty);
    });

    testWidgets(
      'a level with no price shows its credits and what they are worth; Redeem asks first, then opens it for good',
      (tester) async {
        final h = await _group(tester, 'Capital Planning');
        expect(_in('cp-intermediate', find.text('5 ICR credits')), findsOneWidget);
        expect(_in('cp-intermediate', find.text('Worth ₹500')), findsOneWidget);
        // The balance is said once, over the rows, not under each button.
        expect(find.text('You have 100 ICR credits · 1 credit = ₹100'), findsOneWidget);
        expect(_in('cp-intermediate', find.textContaining('You have')), findsNothing);
        expect(_button('cp-advanced', 'Start Assessment'), findsOneWidget, reason: 'Advanced was redeemed earlier');

        await tester.tap(_button('cp-intermediate', 'Redeem 5 ICR Credits'));
        await tester.pumpAndSettle();
        expect(find.text('5 ICR Credits for “Capital Planning” – Professional?'), findsOneWidget);
        expect(find.text('This level opens permanently. You will have 95 ICR credits left.'), findsOneWidget);
        expect(h.fake.count('redeem'), 0, reason: 'nothing is spent before the confirmation');

        await tester.tap(find.widgetWithText(ActionButton, 'Redeem 5 Credits'));
        await tester.pumpAndSettle();
        expect(h.fake.calls, contains('redeem:capital-planning-professional'));
        expect(_in('cp-intermediate', find.text('Worth ₹500')), findsNothing, reason: 'nothing is left to pay');
        expect(_button('cp-intermediate', 'Start Assessment'), findsOneWidget);
        expect(find.textContaining('You have 95 ICR credits'), findsOneWidget);
        expect(find.textContaining('You enrolled into this course'), findsNothing, reason: 'owner, 3 Nov 2026');
        expect(find.text('Professional is open. 5 ICR credits spent.'), findsOneWidget, reason: 'the snackbar');
      },
    );

    testWidgets('Cancel on the confirmation spends nothing', (tester) async {
      final h = await _group(tester, 'Capital Planning');
      await tester.tap(_button('cp-intermediate', 'Redeem 5 ICR Credits'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ActionButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(h.fake.count('redeem'), 0);
      expect(_button('cp-intermediate', 'Redeem 5 ICR Credits'), findsOneWidget);
      expect(h.fake.memberNow.access!.icrCredits, 100);
    });

    testWidgets('a redemption the API refuses puts the card back and shows the API\'s words', (tester) async {
      final fake = FakeAssess()
        ..failures['redeem'] = ApiError(
          'This level takes 5 ICR credits, and you have 100. Buy it, or invite colleagues to ICR to earn more.',
          statusCode: 403,
        );
      await _group(tester, 'Capital Planning', fake: fake);
      await tester.tap(_button('cp-intermediate', 'Redeem 5 ICR Credits'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ActionButton, 'Redeem 5 Credits'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Buy it, or invite colleagues'), findsOneWidget);
      expect(_button('cp-intermediate', 'Start Assessment'), findsNothing);
      expect(_button('cp-intermediate', 'Redeem 5 ICR Credits'), findsOneWidget);
      expect(_btn(tester, _button('cp-intermediate', 'Redeem 5 ICR Credits')).loading, isFalse);
      expect(fake.memberNow.access!.icrCredits, 100);
    });

    testWidgets('while a redemption is in flight the button spins and cannot be pressed twice', (tester) async {
      final h = await _group(tester, 'Capital Planning');
      await tester.tap(_button('cp-intermediate', 'Redeem 5 ICR Credits'));
      await tester.pumpAndSettle();
      final gate = Completer<void>();
      h.fake.gate = gate.future;
      await tester.tap(find.widgetWithText(ActionButton, 'Redeem 5 Credits'));
      await tester.pump();
      await tester.pump();
      final busy = _button('cp-intermediate', 'Redeeming…');
      expect(busy, findsOneWidget);
      expect(_btn(tester, busy).loading, isTrue);
      expect(_btn(tester, busy).onPressed, isNull);
      gate.complete();
      h.fake.gate = null;
      await tester.pumpAndSettle();
      expect(h.fake.count('redeem'), 1);
      expect(_button('cp-intermediate', 'Start Assessment'), findsOneWidget);
    });

    testWidgets('with too few credits Redeem is off; the balance over the rows says what the member has', (
      tester,
    ) async {
      final fake = FakeAssess(member: assessMember(credits: 2, open: {}));
      final h = await _group(tester, 'Capital Planning', fake: fake);
      expect(_in('cp-foundation', find.textContaining('Needs')), findsNothing, reason: 'said once, not per row');
      final redeem = _button('cp-foundation', 'Redeem 5 ICR Credits');
      expect(_btn(tester, redeem).onPressed, isNull);
      await tester.tap(redeem, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('This level opens permanently. You will have 0 ICR credits left.'), findsNothing);
      expect(h.fake.count('redeem'), 0);
      expect(find.text('You have 2 ICR credits · 1 credit = ₹100'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Earn More'), findsOneWidget);
    });

    testWidgets('a level that is neither priced nor open to credits offers the plans', (tester) async {
      final fake = FakeAssess();
      fake.quotes = {...fake.quotes, 'cp-foundation': const PaperQuote(paperId: 'cp-foundation')};
      final h = await _group(tester, 'Capital Planning', fake: fake);
      expect(_in('cp-foundation', find.text('Not on sale right now.')), findsOneWidget);
      await tester.tap(_button('cp-foundation', 'See Plans'));
      await tester.pump();
      expect(h.launcher.uris.single.path, '/pricing/professional');
    });

    testWidgets('a closed level whose price has not arrived says it is locked', (tester) async {
      final fake = FakeAssess()..failures['quote:capital-planning-foundation'] = ApiError('no');
      await _group(tester, 'Capital Planning', fake: fake);
      expect(_in('cp-foundation', find.text('Locked')), findsOneWidget, reason: 'the row says it is locked');
      expect(_in('cp-foundation', find.text('Opens with ICR credits or a purchase.')), findsOneWidget);
      expect(_in('cp-foundation', find.text('See Plans')), findsOneWidget);
    });

    testWidgets('a plan place still free: the course asks to be opened first, and every level says it is included', (
      tester,
    ) async {
      final fake = FakeAssess(
        member: assessMember(
          open: {},
          courses: const PlanPlaces(limit: 2, opened: ['course-pm']),
        ),
      );
      await _group(tester, 'Human Capital', fake: fake);
      expect(
        find.text('Your plan includes 2 courses, and 1 is still free. Every level opens with it.'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(RowButton, 'Open with My Plan'),
        findsNWidgets(3),
        reason: 'the card and the two levels',
      );
      expect(fake.count('quote'), 0, reason: 'a level the plan opens costs nothing, so nothing is priced');
    });

    testWidgets('Open with my plan asks first, then opens every level; the grid shows it open too', (tester) async {
      final fake = FakeAssess(
        member: assessMember(
          open: {},
          courses: const PlanPlaces(limit: 2, opened: ['course-pm']),
        ),
      );
      await _group(tester, 'Human Capital', fake: fake);
      await tester.tap(find.widgetWithText(RowButton, 'Open with My Plan').first);
      await tester.pumpAndSettle();
      expect(find.text('Open “Human Capital” with Your Plan?'), findsOneWidget);
      expect(
        find.text('It takes one of the 2 courses your plan includes, and every level opens. None will be left.'),
        findsOneWidget,
      );
      expect(fake.count('openWithPlan'), 0);
      await tester.tap(find.widgetWithText(ActionButton, 'Open'));
      await tester.pumpAndSettle();
      expect(fake.calls, contains('openWithPlan:assessment:course-hc'));
      expect(find.text('This course is open with your plan. You can take every level.'), findsOneWidget);
      expect(find.widgetWithText(RowButton, 'Start Assessment'), findsNWidgets(2));
      expect(find.text('Open this course'), findsNothing);
      await _back(tester);
      expect(
        find.text('Open'),
        findsNWidgets(2),
        reason: 'Human Capital, and Procurement Management which the plan opened',
      );
    });

    testWidgets('a level\'s own Open with my plan does the same', (tester) async {
      final fake = FakeAssess(
        member: assessMember(open: {}, courses: const PlanPlaces(limit: 1)),
      );
      await _group(tester, 'Human Capital', fake: fake);
      await tester.tap(_button('hc-advanced', 'Open with My Plan'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ActionButton, 'Open'));
      await tester.pumpAndSettle();
      expect(fake.count('openWithPlan'), 1);
      expect(_button('hc-advanced', 'Start Assessment'), findsOneWidget);
    });

    testWidgets('a plan place the API refuses leaves the course closed and shows its words', (tester) async {
      final fake = FakeAssess(
        member: assessMember(open: {}, courses: const PlanPlaces(limit: 1)),
      )..failures['openWithPlan'] = ApiError('Your plan has no course left to open.', statusCode: 403);
      await _group(tester, 'Human Capital', fake: fake);
      await tester.tap(find.widgetWithText(RowButton, 'Open with My Plan').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ActionButton, 'Open'));
      await tester.pumpAndSettle();
      expect(find.text('Your plan has no course left to open.'), findsOneWidget);
      expect(find.byKey(const ValueKey('plan-open-card')), findsOneWidget, reason: 'still offering the plan place');
      expect(find.widgetWithText(RowButton, 'Start Assessment'), findsNothing);
    });

    testWidgets(
      'a plan that opens no courses says so; See plans leads to them, and with no credits there is a way to earn them',
      (tester) async {
        final fake = FakeAssess(
          member: assessMember(open: {}, credits: 0, upgradePlan: 'Pro Plus'),
        );
        final h = await _group(tester, 'Contract Management', fake: fake);
        // One line for the plan, one for the credits — no box, no banner-sized button (owner, 3 Nov 2026).
        expect(find.text('Unlock a level'), findsNothing);
        expect(find.text('Knowledge Assessment courses are not included in your plan.'), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, 'See Pro Plus'));
        await tester.pump();
        expect(h.launcher.uris.last, Uri.parse('https://site.test/pricing/professional'));
        expect(find.text('You have 0 ICR credits · 1 credit = ₹100'), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, 'Earn More'));
        await tester.pump();
        expect(h.launcher.uris.last.path, '/refer');
        // No credits: every Redeem is off.
        expect(_btn(tester, _button('cm-foundation', 'Redeem')).onPressed, isNull);
      },
    );

    testWidgets('a plan whose places are used up says so', (tester) async {
      final fake = FakeAssess(
        member: assessMember(
          open: {},
          courses: const PlanPlaces(limit: 2, opened: ['a', 'b']),
        ),
      );
      await _group(tester, 'Procurement Management', fake: fake);
      expect(find.text('You have opened all 2 courses your plan includes.'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'See Plans'), findsOneWidget);
    });

    testWidgets('a course the plan opened says so in one line; one that opens everything says nothing', (tester) async {
      await _group(
        tester,
        'Capital Planning',
        fake: FakeAssess(
          member: assessMember(
            open: {},
            courses: const PlanPlaces(limit: 1, opened: ['course-cp']),
          ),
        ),
      );
      expect(find.text('This course is open with your plan. You can take every level.'), findsOneWidget);
      expect(find.text('Unlock a level'), findsNothing);
      expect(find.widgetWithText(RowButton, 'Start Assessment'), findsNWidgets(3));
    });

    testWidgets('staff and plans that open everything see no plan card at all', (tester) async {
      await _group(tester, 'Capital Planning', fake: FakeAssess(member: assessMember(allOpen: true)));
      expect(find.text('Unlock a level'), findsNothing);
      expect(find.text('Open this course'), findsNothing);
      expect(find.widgetWithText(RowButton, 'Start Assessment'), findsNWidgets(3));
    });

    testWidgets("the knowledge areas are the programme's own, counted in a pill, with the programme's own blurb", (
      tester,
    ) async {
      await _group(tester, 'Capital Planning');
      expect(find.text('Knowledge Areas Covered'), findsOneWidget);
      expect(find.text('10 Topics'), findsOneWidget);
      expect(find.text('Capital Planning Fundamentals'), findsOneWidget);
      // Long topics take a row each or two to a row: the first two rows show and the rest fold behind View more,
      // so the levels stay in the first view (the owner's rules of 30 Oct and 3 Nov 2026).
      final shown = tester.widgetList<TopicChip>(find.byType(TopicChip)).length;
      expect(shown, lessThan(10), reason: 'ten long topics do not fit two rows at 390 dp');
      expect(find.text('Risk-Based Capital Planning'), findsNothing);
      expect(find.text('View More'), findsOneWidget);
      await tester.tap(find.text('View More'));
      await tester.pumpAndSettle();
      expect(find.byType(TopicChip), findsNWidgets(10));
      expect(find.text('Risk-Based Capital Planning'), findsOneWidget);
      expect(find.text('Facility Condition Index (FCI)'), findsOneWidget);
      // This programme sends no sentence of its own: the design's stands in.
      expect(find.text(defaultAreasBlurb), findsOneWidget);
    });

    testWidgets("a programme's own summary is the blurb; one topic is a Topic, not Topics", (tester) async {
      final fake = FakeAssess(
        programmes: [
          programme(
            'CP',
            'Capital Planning',
            [level('cp', 'FOUNDATION')],
            areas: const ['Capital Planning Fundamentals'],
            summary: 'How a portfolio plans what it will spend.',
          ),
        ],
      );
      await _group(tester, 'Capital Planning', fake: fake);
      expect(find.text('How a portfolio plans what it will spend.'), findsOneWidget);
      expect(find.text(defaultAreasBlurb), findsNothing);
      expect(find.text('1 Topic'), findsOneWidget);
    });

    testWidgets('beyond two rows of topics the rest fold and unfold on View more', (tester) async {
      final areas = [for (var i = 1; i <= 40; i++) 'Topic number $i'];
      final fake = FakeAssess(
        programmes: [
          programme('CP', 'Capital Planning', [level('cp', 'FOUNDATION')], areas: areas),
        ],
      );
      await _group(tester, 'Capital Planning', fake: fake);
      expect(find.text('40 Topics'), findsOneWidget);
      // The rows are what fold, not a count: whatever the chips' widths, the first two rows show, whole.
      final shown = find.byType(TopicChip);
      final count = shown.evaluate().length;
      final rows = {for (var i = 0; i < count; i++) tester.getTopLeft(shown.at(i)).dy.round()};
      expect(KnowledgeAreas.foldedRows, 2);
      expect(rows.length, KnowledgeAreas.foldedRows, reason: 'two rows of topics');
      expect(count, inInclusiveRange(KnowledgeAreas.foldedRows, 39));
      expect(find.text('Topic number 1'), findsOneWidget);
      expect(find.text('Topic number 40'), findsNothing);
      await tester.tap(find.text('View More'));
      await tester.pumpAndSettle();
      expect(find.byType(TopicChip), findsNWidgets(40));
      expect(find.text('Topic number 40'), findsOneWidget);
      await tester.tap(find.text('View Less'));
      await tester.pumpAndSettle();
      expect(find.text('Topic number 40'), findsNothing);
    });

    testWidgets('topics are tinted six to a family: blue, green, blue', (tester) async {
      final areas = [for (var i = 1; i <= 13; i++) 'Topic number $i'];
      final fake = FakeAssess(
        programmes: [
          programme('CP', 'Capital Planning', [level('cp', 'FOUNDATION')], areas: areas),
        ],
      );
      await _group(tester, 'Capital Planning', fake: fake);
      await tester.tap(find.text('View More'));
      await tester.pumpAndSettle();
      Color fill(int i) {
        final chip = find.ancestor(of: find.text('Topic number $i'), matching: find.byType(Container)).first;
        return ((tester.widget<Container>(chip).decoration) as BoxDecoration).color!;
      }

      expect(fill(1), AssessColors.topicBlue);
      expect(fill(6), AssessColors.topicBlue);
      expect(fill(7), AssessColors.topicGreen);
      expect(fill(12), AssessColors.topicGreen);
      expect(fill(13), AssessColors.topicBlueDeep);
    });

    testWidgets('a programme with no areas leaves the section out; its own summary still shows', (tester) async {
      await _group(tester, 'Contract Management');
      expect(find.byKey(const ValueKey('knowledge-areas')), findsNothing);
      expect(find.text('Knowledge Areas Covered'), findsNothing);
      expect(find.text(defaultAreasBlurb), findsNothing, reason: 'the standard sentence belongs to the topics');
      final fake = FakeAssess(
        programmes: [
          programme('CM', 'Contract Management', [level('cm', 'FOUNDATION')], summary: 'Contracts, end to end.'),
        ],
      );
      await _group(tester, 'Contract Management', fake: fake);
      expect(find.byKey(const ValueKey('knowledge-areas')), findsNothing);
      expect(find.text('Contracts, end to end.'), findsOneWidget);
    });

    testWidgets('the bundle offer shows the levels, the price and the saving; Unlock buys every level in the app', (
      tester,
    ) async {
      final fake = FakeAssess(
        bundle: const BundleQuote(
          courseCode: 'CM',
          offered: true,
          payable: true,
          programmeTitle: 'Contract Management',
          levels: ['Foundation', 'Professional', 'Advanced'],
          separateSalePaisa: 229700,
          salePaisa: 160790,
          savePaisa: 68910,
          discountBps: 3000,
        ),
      );
      final h = await _group(tester, 'Contract Management', fake: fake);
      expect(find.byKey(const ValueKey('bundle-offer')), findsOneWidget);
      expect(find.text('BUNDLE · 30% OFF'), findsOneWidget);
      expect(find.text('Get all 3 levels together'), findsOneWidget);
      expect(find.text('Foundation · Professional · Advanced'), findsOneWidget, reason: 'what it opens, in a line');
      expect(find.text('₹2,297  ₹1,607.90 + GST'), findsOneWidget, reason: 'the separate price struck, the bundle');
      expect(find.text('Save ₹689.10 vs buying separately'), findsOneWidget);
      final paid = _stubPayments();
      await tester.tap(find.byKey(const ValueKey('bundle-pay-now')));
      await tester.pumpAndSettle();
      expect(h.fake.checkouts, ['bundle:CM'], reason: "the bundle's own checkout");
      expect(paid.single.action, 'https://pay.test/_payment');
      expect(h.pay.uris, isEmpty, reason: "a payment runs in the app, never in the phone's browser");
      expect(h.launcher.uris, isEmpty);
    });

    testWidgets('no bundle is drawn unless the API offers one; the last level reads as such', (tester) async {
      await _group(tester, 'Contract Management');
      expect(find.byKey(const ValueKey('bundle-offer')), findsNothing);
    });

    testWidgets('a bundle that cannot be paid for online is off and says why', (tester) async {
      final fake = FakeAssess(
        bundle: const BundleQuote(
          courseCode: 'CM',
          offered: true,
          payable: false,
          programmeTitle: 'Contract Management',
          levels: ['Advanced'],
          separateSalePaisa: 79900,
          salePaisa: 55930,
          savePaisa: 23970,
          discountBps: 3000,
        ),
      );
      final h = await _group(tester, 'Contract Management', fake: fake);
      expect(find.text('Get the last level'), findsOneWidget);
      expect(tester.widget<RowButton>(find.byKey(const ValueKey('bundle-pay-now'))).onPressed, isNull);
      await tester.tap(find.byKey(const ValueKey('bundle-pay-now')), warnIfMissed: false);
      await tester.pump();
      expect(h.launcher.uris, isEmpty);
      expect(find.text('Online payment is not available right now.'), findsWidgets);
    });

    testWidgets('the sale strip reads the global discount', (tester) async {
      final fake = FakeAssess(pricingNow: const AssessmentPricing(discountPercent: 20));
      await _group(tester, 'Contract Management', fake: fake);
      expect(find.byKey(const ValueKey('discount-strip')), findsOneWidget);
      expect(find.text('20% off every assessment level'), findsOneWidget);
      expect(find.text('Applied automatically at checkout. No code needed.'), findsOneWidget);
    });

    testWidgets('no sale strip without a discount, or when no level shows a price', (tester) async {
      await _group(tester, 'Contract Management');
      expect(find.byKey(const ValueKey('discount-strip')), findsNothing);
    });

    testWidgets('pulling down reads the programme, what the member holds and the prices again', (tester) async {
      final h = await _group(tester, 'Contract Management');
      final groups = h.fake.count('group');
      final members = h.fake.count('member');
      final quotes = h.fake.count('quote');
      await _pull(tester, find.byType(ListView).last);
      expect(h.fake.count('group'), groups + 1);
      expect(h.fake.count('member'), members + 1);
      expect(h.fake.count('quote'), quotes + 3);
    });

    testWidgets('a refresh that fails keeps the levels and offers Try again', (tester) async {
      final h = await _group(tester, 'Capital Planning');
      h.fake.failures['group'] = ApiError("Can't reach ICR right now.");
      await _pull(tester, find.byType(ListView).last);
      expect(find.byKey(const ValueKey('refresh-failed')), findsOneWidget);
      expect(find.text("Can't reach ICR right now."), findsOneWidget);
      expect(_card('cp-foundation'), findsOneWidget);
      h.fake.failures.clear();
      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('refresh-failed')), findsNothing);
    });

    testWidgets('a programme that has gone says so, and All programmes leaves the page', (tester) async {
      final h = await _group(tester, 'Capital Planning');
      h.fake.programmes = [
        for (final p in h.fake.programmes)
          if (p.key != 'CP') p,
      ];
      await _pull(tester, find.byType(ListView).last);
      expect(find.text('Programme Not Found'), findsOneWidget);
      expect(find.text('Nothing is published at “CP”.'), findsOneWidget);
      await tester.tap(find.text('All Programmes'));
      await tester.pumpAndSettle();
      expect(find.text('Programme Not Found'), findsNothing);
      expect(find.byType(GroupCard), findsNWidgets(4));
    });

    testWidgets('the programme page has the door\'s title and a back arrow, no bell and no share', (tester) async {
      final h = await _group(tester, 'Capital Planning');
      expect(find.text('Knowledge Assessments'), findsOneWidget);
      expect(find.byIcon(LucideIcons.bell), findsNothing);
      expect(find.byIcon(Symbols.share), findsNothing);
      expect(find.byType(BellButton), findsNothing);
      expect(h.launcher.uris, isEmpty);
    });
  });

  // --- Mock Exams ----------------------------------------------------------------------------------------

  group('Mock Exams', () {
    testWidgets('one card per subject with its sets and questions; the search finds a subject by a set\'s title', (
      tester,
    ) async {
      await _landing(tester, mock: true);
      expect(find.text('Mock Exams'), findsOneWidget, reason: 'the title bar');
      expect(find.text('Practice · Prepare · Perform'), findsNothing, reason: 'no banner (owner, 3 Nov 2026)');
      expect(_titles(tester), ['AEE CBCP', 'AEE CEM', 'IFMA FMP']);
      expect(find.text('2 sets · 10 questions'), findsOneWidget);
      expect(find.text('3 sets · 10 questions'), findsOneWidget);
      expect(find.text('1 set · 25 questions'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'set 3');
      await tester.pumpAndSettle();
      expect(_titles(tester), ['AEE CEM']);
      expect(find.text('Showing 1 of 3 subjects.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('No Subject Matches'), findsOneWidget);
      await tester.tap(find.text('Reset Filters'));
      await tester.pumpAndSettle();
      expect(_titles(tester).length, 3);
    });

    testWidgets('Back, the bell, Free and Paid work as on the other door', (tester) async {
      final h = await _landing(tester, mock: true);
      await tester.tap(find.text('Paid'));
      await tester.pumpAndSettle();
      expect(_titles(tester), ['AEE CEM']);
      await tester.tap(find.text('Free'));
      await tester.pumpAndSettle();
      expect(_titles(tester), ['AEE CBCP', 'IFMA FMP']);
      await tester.tap(find.byIcon(Symbols.arrow_back));
      await tester.pump();
      expect(h.backs, 1);
    });

    testWidgets('no subjects and a failed load say so', (tester) async {
      await _landing(tester, mock: true, fake: FakeAssess(topics: []));
      expect(find.text('No Mock Exams Available Yet'), findsOneWidget);
      final fake = FakeAssess()..failures['groups'] = ApiError('Offline.');
      await _landing(tester, mock: true, fake: fake);
      expect(find.text("Unable to Load the Mock Exams"), findsOneWidget);
      fake.failures.clear();
      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();
      expect(find.byType(GroupCard), findsNWidgets(3));
    });

    testWidgets('a subject opens its sets, numbered, each with its numbers and the attempts it allows', (tester) async {
      final h = await _group(tester, 'AEE CBCP', mock: true);
      expect(h.fake.calls, contains('group:aee-cbcp'));
      expect(find.text('Mock Exam'), findsOneWidget, reason: 'the bar');
      expect(find.byKey(const ValueKey('hero-title')), findsOneWidget);
      expect(find.text('AEE CBCP'), findsOneWidget);
      // Attempts are limited on these sets, so the sentence does not promise unlimited ones.
      expect(find.text('2 Sets each with its own questions'), findsOneWidget);
      expect(find.text('01'), findsOneWidget, reason: "the row's number, no faint numeral behind it");
      expect(find.text('02'), findsOneWidget);
      expect(find.text('Set 1'), findsOneWidget);
      expect(find.text('Set 2'), findsOneWidget);
      // One line of what a set is: questions, time, pass mark, the attempts it allows.
      expect(
        _in('aee-cbcp-set-1', find.text('10 questions · 30 min · 70% to pass · Up to 3 attempts')),
        findsOneWidget,
      );
      expect(_in('aee-cbcp-set-2', find.text('Business continuity: the second paper.')), findsOneWidget);
      expect(
        _in('aee-cbcp-set-1', find.text('Practice paper under exam conditions.')),
        findsNothing,
        reason: 'a set with no description of its own shows none',
      );
      expect(find.text('Knowledge Areas Covered'), findsNothing, reason: 'a subject has none');
      expect(find.byType(BellButton), findsNothing);
    });

    testWidgets('the sets sit one under another, full width, a thin line between them', (tester) async {
      await _group(tester, 'AEE CBCP', mock: true);
      final one = tester.getRect(_card('aee-cbcp-set-1'));
      final two = tester.getRect(_card('aee-cbcp-set-2'));
      expect(one.width, 390);
      expect(two.top, closeTo(one.bottom + 1, 0.5), reason: 'a 1 dp hairline, no gap or box');
    });

    testWidgets('a subject with unlimited sets says so, one set says "Set"; its own description follows', (
      tester,
    ) async {
      final fake = FakeAssess(
        topics: [
          topic('solo', 'Solo Exam', [mockSet('solo', 1)], description: 'One long paper.'),
          topic('pair', 'Pair Exam', [mockSet('pair', 1), mockSet('pair', 2)]),
        ],
        member: assessMember(allOpen: true),
      );
      await _group(tester, 'Solo Exam', fake: fake, mock: true);
      expect(find.text('1 Set with its own questions and unlimited attempts'), findsOneWidget);
      expect(find.text('One long paper.'), findsOneWidget);
      await _back(tester);
      await tester.tap(find.descendant(of: find.byType(GroupCard), matching: find.text('Pair Exam')));
      await tester.pumpAndSettle();
      expect(find.text('2 Sets each with its own questions and unlimited attempts'), findsOneWidget);
    });

    testWidgets("a subject with no sets says so; the share glyph and each set's share open the phone's sheet", (
      tester,
    ) async {
      final h = await _group(tester, 'AEE CBCP', mock: true);
      await tester.tap(find.descendant(of: find.byType(AssessBar), matching: find.byIcon(Symbols.share)));
      await tester.pump();
      expect(h.shared, [('AEE CBCP', Uri.parse('https://site.test/group/aee-cbcp'))]);
      await tester.tap(find.descendant(of: _card('aee-cbcp-set-2'), matching: find.byIcon(Symbols.share)));
      await tester.pump();
      expect(h.shared.last, ('AEE CBCP – Set 2', Uri.parse('https://site.test/paper/aee-cbcp/aee-cbcp-set-2')));
      final empty = FakeAssess(
        topics: [
          topic('none', 'Empty Exam', [mockSet('none', 1)]),
        ],
      );
      await _group(tester, 'Empty Exam', fake: empty, mock: true);
      empty.topics = [topic('none', 'Empty Exam', [])];
      await _pull(tester, find.byType(ListView).last);
      expect(find.text('No sets are published under this subject yet.'), findsOneWidget);
    });

    testWidgets('an open set starts as a mock; Retake follows a sitting and the best score is read again', (
      tester,
    ) async {
      late FakeAssess fake;
      final opener = RecordingOpener(
        onOpen: (p) async {
          fake.memberNow = assessMember(
            open: {'aee-cbcp-set-1'},
            progress: {'aee-cbcp-set-1': const PaperProgress(attempts: 1, bestPercent: 60, bestScore: 6, maxScore: 10)},
          );
        },
      );
      fake = FakeAssess(member: assessMember(open: {'aee-cbcp-set-1'}));
      await _group(tester, 'AEE CBCP', fake: fake, opener: opener, mock: true);
      expect(_button('aee-cbcp-set-1', 'Start Test'), findsOneWidget);
      expect(_in('aee-cbcp-set-1', find.text('Locked')), findsNothing);
      await tester.tap(_button('aee-cbcp-set-1', 'Start Test'));
      await tester.pumpAndSettle();
      final ref = opener.opened.single;
      expect(ref.slug, 'aee-cbcp-set-1');
      expect(ref.title, 'AEE CBCP – Set 1');
      expect(ref.id, 'aee-cbcp-set-1');
      expect(ref.isMock, isTrue);
      expect(ref.courseCode, isNull);
      expect(
        _in('aee-cbcp-set-1', find.text('Best score 60% (6/10) · Not passed yet · 1 of 3 attempts used')),
        findsOneWidget,
      );
      expect(_button('aee-cbcp-set-1', 'Retake Test'), findsOneWidget);
    });

    testWidgets(
      'a set closed to the member shows Locked and its credits; Redeem opens it with a note in the owner\'s words',
      (tester) async {
        final h = await _group(tester, 'AEE CBCP', mock: true);
        expect(_in('aee-cbcp-set-1', find.text('Locked')), findsOneWidget);
        expect(find.text('Mock exams are not included in your plan.'), findsOneWidget);
        expect(find.text('Unlock a set'), findsNothing, reason: 'one line for the plan, no box');
        await tester.tap(_button('aee-cbcp-set-1', 'Redeem 5 ICR Credits'));
        await tester.pumpAndSettle();
        expect(find.text('5 ICR Credits for “AEE CBCP” – Set 1?'), findsOneWidget);
        expect(find.text('This set opens permanently. You will have 95 ICR credits left.'), findsOneWidget);
        await tester.tap(find.widgetWithText(ActionButton, 'Redeem 5 Credits'));
        await tester.pumpAndSettle();
        expect(h.fake.calls, contains('redeem:aee-cbcp-set-1'));
        expect(_button('aee-cbcp-set-1', 'Start Test'), findsOneWidget);
        expect(find.textContaining('You enrolled into this mock exam'), findsNothing, reason: 'owner, 3 Nov 2026');
        expect(_in('aee-cbcp-set-1', find.text('Locked')), findsNothing);
      },
    );

    testWidgets('a priced set shows its price and credits; Pay goes to the set\'s page on the website', (tester) async {
      final h = await _group(tester, 'AEE CEM', mock: true);
      expect(_in('aee-cem-set-1', find.text('₹299 + GST')), findsOneWidget);
      expect(_in('aee-cem-set-1', find.text('or 3 ICR credits')), findsOneWidget);
      final paid = _stubPayments();
      await tester.tap(_button('aee-cem-set-1', 'Pay Now'));
      await tester.pumpAndSettle();
      expect(h.fake.checkouts, ['aee-cem-set-1']);
      expect(paid.single.action, 'https://pay.test/_payment');
      expect(h.pay.uris, isEmpty);
      expect(h.launcher.uris, isEmpty);
      expect(
        find.byKey(const ValueKey('bundle-offer')),
        findsNothing,
        reason: 'nothing is on offer unless the API says so',
      );
      expect(h.fake.count('bundleQuote'), 2, reason: 'the subject asks for its bundle, and again after the payment');
    });

    testWidgets('a plan place free for the exam asks to open it; See plans appears only when a plan would open more', (
      tester,
    ) async {
      final fake = FakeAssess(
        member: assessMember(open: {}, mocks: const PlanPlaces(limit: 1), mockUpgradePlan: 'Pro Plus'),
      );
      await _group(tester, 'AEE CBCP', fake: fake, mock: true);
      expect(
        find.text('Your plan includes 1 mock exam, and 1 is still free. Every set opens with it.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(RowButton, 'Open with My Plan'), findsNWidgets(3), reason: 'the card and two sets');
      await tester.tap(find.widgetWithText(RowButton, 'Open with My Plan').first);
      await tester.pumpAndSettle();
      expect(find.text('Open “AEE CBCP” with Your Plan?'), findsOneWidget);
      expect(
        find.text('It takes one of the 1 mock exam your plan includes, and every set opens. None will be left.'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(ActionButton, 'Open'));
      await tester.pumpAndSettle();
      expect(fake.calls, contains('openWithPlan:mock:topic-aee-cbcp'));
      expect(find.text('This mock exam is open with your plan. You can take every set.'), findsOneWidget);
      expect(find.widgetWithText(RowButton, 'Start Test'), findsNWidgets(2));
    });

    testWidgets('no plan opens more mock exams: the card offers no plans link; with one it names it', (tester) async {
      await _group(tester, 'AEE CBCP', mock: true);
      expect(find.widgetWithText(TextButton, 'See Plans'), findsNothing);
      final fake = FakeAssess(
        member: assessMember(open: {}, mockUpgradePlan: 'Pro Plus'),
      );
      final h = await _group(tester, 'AEE CBCP', fake: fake, mock: true);
      expect(find.widgetWithText(TextButton, 'See Pro Plus'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'See Pro Plus'));
      await tester.pump();
      expect(h.launcher.uris.single.path, '/pricing/professional');
    });

    testWidgets('the subject page refreshes by pull, and a subject that is gone says so', (tester) async {
      final h = await _group(tester, 'AEE CBCP', mock: true);
      final before = h.fake.count('group');
      await _pull(tester, find.byType(ListView).last);
      expect(h.fake.count('group'), before + 1);
      h.fake.topics = [
        for (final t in h.fake.topics)
          if (t.key != 'aee-cbcp') t,
      ];
      await _pull(tester, find.byType(ListView).last);
      expect(find.text('Subject Not Found'), findsOneWidget);
      expect(find.text('All Subjects'), findsOneWidget);
    });
  });

  // --- the sample content ---------------------------------------------------------------------------------

  group('the sample content', () {
    testWidgets('draws both doors and the controls work without the API', (tester) async {
      _phone(tester, 3600);
      final demo = DemoAssessRepository();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: AssessmentScreen(
            onBack: () {},
            repository: demo,
            opener: RecordingOpener().call,
            launcher: RecordingLauncher().call,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GroupCard), findsNWidgets(3));
      await tester.tap(find.descendant(of: find.byType(GroupCard), matching: find.text('Contract Management')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('paper-cm-foundation')), findsOneWidget);
      await tester.tap(_button('cm-foundation', 'Redeem'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ActionButton, 'Redeem 5 Credits'));
      await tester.pumpAndSettle();
      expect(_button('cm-foundation', 'Start Assessment'), findsOneWidget);
    });
  });

  // --- bundles in ICR credits and in money, on a programme's page and a mock subject's ---------------------------

  group('bundles: in ICR credits (summed, less the bundle discount) and in money', () {
    // What the API says for AEE CBCP (two sets of 5 credits): 5 + 5 = 10, less 10, never below the dearest (5).
    BundleQuote cbcpCredits({int credits = 5, int separate = 10, int saved = 5}) => BundleQuote(
      courseCode: 'aee-cbcp',
      kind: PaperKind.mock,
      programmeTitle: 'AEE CBCP',
      credits: credits,
      separateCredits: separate,
      creditsSaved: saved,
      creditsOffered: true,
      creditLevels: const [
        BundleLevel(paperId: 'aee-cbcp-set-1', title: 'Set 1', credits: 5),
        BundleLevel(paperId: 'aee-cbcp-set-2', title: 'Set 2', credits: 5),
      ],
    );

    // Contract Management: all three priced, so the money bundle and the credit bundle are both on offer.
    BundleQuote cmBoth({bool payable = true, String? ends}) => BundleQuote(
      courseCode: 'CM',
      programmeTitle: 'Contract Management',
      offered: true,
      payable: payable,
      levels: const ['Foundation', 'Professional', 'Advanced'],
      separateSalePaisa: 229700,
      salePaisa: 160790,
      savePaisa: 68910,
      discountBps: 3000,
      offerEndsOn: ends,
      credits: 13,
      separateCredits: 23,
      creditsSaved: 10,
      creditsOffered: true,
      creditLevels: const [
        BundleLevel(paperId: 'cm-foundation', title: 'Foundation', credits: 5),
        BundleLevel(paperId: 'cm-intermediate', title: 'Professional', credits: 10),
        BundleLevel(paperId: 'cm-advanced', title: 'Advanced', credits: 8),
      ],
    );

    group('the API\'s answers', () {
      test('a mock exam\'s bundle is read from `mock-bundles`, credits and all, and redeemed there', () async {
        final api = _Api({
          'GET /learning/mock-bundles/aee-cem/quote': (_) => {
            'kind': 'MOCK',
            'offered': false,
            'payable': false,
            'courseCode': 'aee-cem',
            'programmeTitle': 'AEE CEM',
            'levels': <Object?>[],
            'credits': 5,
            'separateCredits': 8,
            'creditsSaved': 3,
            'creditsOffered': true,
            'offerEndsOn': '2026-12-31',
            'creditLevels': [
              {'paperId': 'p1', 'title': 'Set 1', 'level': null, 'credits': 3},
              {'paperId': 'p2', 'title': 'Set 2', 'level': null, 'credits': 5},
            ],
          },
          'POST /learning/mock-bundles/aee-cem/redeem': (_) => {
            'unlocked': true,
            'spent': 5,
            'credits': 95,
            'paperIds': ['p1', 'p2'],
            'unlockedCourseIds': <Object?>[],
          },
        });
        final repo = _repo(api);
        final b = await repo.bundleQuote('aee-cem', kind: PaperKind.mock);
        expect(api.calls.single, 'GET /learning/mock-bundles/aee-cem/quote');
        expect(b.mock, isTrue);
        expect(b.offered, isFalse, reason: 'nothing is priced as a bundle in money');
        expect(b.inCredits, 5);
        expect(b.separateCredits, 8);
        expect(b.creditsSaved, 3);
        expect(b.hasOffer, isTrue);
        expect(b.offerEndsOn, '2026-12-31');
        expect([for (final l in b.creditLevels) '${l.title}:${l.credits}'], ['Set 1:3', 'Set 2:5']);
        expect(b.count, 2);

        final r = await repo.redeemBundle(PaperKind.mock, 'aee-cem');
        expect(api.calls.last, 'POST /learning/mock-bundles/aee-cem/redeem');
        expect(r.spent, 5);
        expect(r.credits, 95);
        expect(r.paperIds, ['p1', 'p2']);
      });

      test('a programme\'s bundle is read and redeemed from `assessment-bundles`', () async {
        final api = _Api({
          'GET /learning/assessment-bundles/CP/quote': (_) => {
            'offered': false,
            'courseCode': 'CP',
            'programmeTitle': 'Capital Planning',
            'creditsOffered': true,
            'credits': 10,
            'separateCredits': 15,
            'creditsSaved': 5,
            'creditLevels': [
              {'paperId': 'a', 'title': 'Foundation', 'level': 'FOUNDATION', 'credits': 5},
              {'paperId': 'b', 'title': 'Professional', 'level': 'INTERMEDIATE', 'credits': 5},
              {'paperId': 'c', 'title': 'Advanced', 'level': 'ADVANCED', 'credits': 5},
            ],
          },
          'POST /learning/assessment-bundles/CP/redeem': (_) => {
            'unlocked': true,
            'spent': 10,
            'credits': 90,
            'paperIds': ['a', 'b', 'c'],
            'unlockedCourseIds': ['course-cp'],
          },
        });
        final repo = _repo(api);
        final b = await repo.bundleQuote('CP');
        expect(api.calls.single, 'GET /learning/assessment-bundles/CP/quote');
        expect(b.mock, isFalse);
        expect(b.inCredits, 10);
        final r = await repo.redeemBundle(PaperKind.assessment, 'CP');
        expect(api.calls.last, 'POST /learning/assessment-bundles/CP/redeem');
        expect(r.unlockedCourseIds, ['course-cp'], reason: 'a flashcard deck of the same name follows these');
      });

      test('an API without the credit bundle (production today) offers none, however it answers', () async {
        final api = _Api({
          'GET /learning/mock-bundles/aee-cem/quote': (_) => {
            'offered': false,
            'payable': false,
            'courseCode': 'aee-cem',
            'programmeTitle': 'AEE CEM',
            'levels': <Object?>[],
          },
        });
        final b = await _repo(api).bundleQuote('aee-cem', kind: PaperKind.mock);
        expect(b.creditsOffered, isFalse);
        expect(b.credits, isNull);
        expect(b.creditLevels, isEmpty);
        expect(b.hasOffer, isFalse);
      });

      test('the courses a member opened a level of are read from `me/paper-unlocks`', () async {
        final api = _Api({
          'GET /learning/me/paper-unlocks': (_) => {
            'allOpen': false,
            'paperIds': ['a'],
            'creditPaperIds': ['a'],
            'unlockedCourseIds': ['course-cp', 'course-cm'],
            'icrCredits': 100,
            'rupeesPerCredit': 100,
            'plan': {
              'assessmentCourses': {'limit': 0, 'openedCourseIds': <Object?>[]},
              'mockExams': {'limit': 0, 'openedTopicIds': <Object?>[]},
            },
          },
          'GET /learning/me/attempts': (_) => <Object?>[],
          'GET /learning/me/certificates': (_) => <Object?>[],
        });
        final m = await _repo(api).member(PaperKind.assessment);
        expect(m.access!.unlockedCourseIds, {'course-cp', 'course-cm'});
      });
    });

    group('the controller', () {
      Future<(FakeAssess, GroupController)> mockSubject(FakeAssess fake) async {
        final catalogue = CatalogueController(repository: fake, kind: PaperKind.mock);
        await catalogue.start();
        final g = GroupController(
          repository: fake,
          catalogue: catalogue,
          seed: catalogue.groups.firstWhere((x) => x.key == 'aee-cbcp'),
        );
        addTearDown(g.dispose);
        addTearDown(catalogue.dispose);
        await g.start();
        return (fake, g);
      }

      test(
        'redeeming the bundle opens every set at once, takes the API\'s credits and reads the offer again',
        () async {
          final (fake, g) = await mockSubject(FakeAssess(bundle: cbcpCredits()));
          expect(g.bundle!.inCredits, 5);
          final before = fake.count('bundleQuote');

          final outcome = await g.redeemBundle();

          expect(outcome.ok, isTrue);
          expect(outcome.opened, 2);
          expect(outcome.spent, 5);
          expect(g.member.access!.icrCredits, 95);
          expect(g.entry(g.group.sets[0]).isOpen, isTrue);
          expect(g.entry(g.group.sets[1]).isOpen, isTrue);
          expect(g.member.access!.creditPaperIds, containsAll(['aee-cbcp-set-1', 'aee-cbcp-set-2']));
          expect(fake.count('bundleQuote'), greaterThan(before), reason: 'what is left to bundle is quoted again');
          expect(g.bundle!.hasOffer, isFalse, reason: 'nothing is left to bundle');
          expect(g.redeemingBundle, isFalse);
        },
      );

      test('a programme\'s course is noted as opened, for the flashcard deck of the same name', () async {
        final fake = FakeAssess(
          bundle: const BundleQuote(
            courseCode: 'CP',
            programmeTitle: 'Capital Planning',
            credits: 8,
            separateCredits: 10,
            creditsSaved: 2,
            creditsOffered: true,
            creditLevels: [
              BundleLevel(paperId: 'cp-foundation', title: 'Foundation', credits: 5),
              BundleLevel(paperId: 'cp-intermediate', title: 'Professional', credits: 5),
            ],
          ),
        );
        final catalogue = CatalogueController(repository: fake, kind: PaperKind.assessment);
        await catalogue.start();
        final g = GroupController(
          repository: fake,
          catalogue: catalogue,
          seed: catalogue.groups.firstWhere((x) => x.key == 'CP'),
        );
        addTearDown(g.dispose);
        addTearDown(catalogue.dispose);
        await g.start();
        await g.redeemBundle();
        expect(g.member.access!.unlockedCourseIds, contains('course-cp'));
      });

      test('a refusal is the API\'s sentence, nothing opens, and the offer is quoted again', () async {
        final fake = FakeAssess(bundle: cbcpCredits(), member: assessMember(credits: 3));
        final (_, g) = await mockSubject(fake);
        final before = fake.count('bundleQuote');
        final outcome = await g.redeemBundle();
        expect(outcome.ok, isFalse);
        expect(outcome.error, 'Every set together takes 5 ICR credits, and you have 3.');
        expect(g.member.access!.icrCredits, 3);
        expect(g.entry(g.group.sets[0]).isOpen, isFalse);
        expect(fake.count('bundleQuote'), greaterThan(before));
      });

      test('a second tap while one is in flight does nothing', () async {
        final gate = Completer<void>();
        final (fake, g) = await mockSubject(FakeAssess(bundle: cbcpCredits()));
        fake.gate = gate.future;
        final first = g.redeemBundle();
        final second = await g.redeemBundle();
        expect(second.opened, 0);
        gate.complete();
        await first;
        expect(fake.count('redeemBundle'), 1);
      });
    });

    group('a mock subject\'s page', () {
      testWidgets('shows the credit bundle below the sets: every set summed, less 10, redeemed after a confirmation', (
        tester,
      ) async {
        final h = await _group(tester, 'AEE CBCP', fake: FakeAssess(bundle: cbcpCredits()), mock: true);

        expect(find.byKey(const ValueKey('bundle-offer')), findsOneWidget);
        expect(find.text('BUNDLE · 5 CREDITS OFF'), findsOneWidget);
        expect(find.text('Open all 2 sets with ICR credits'), findsOneWidget);
        expect(find.text('Set 1 · Set 2'), findsOneWidget, reason: 'what it opens, in a line');
        expect(find.text('10 credits  5 ICR credits'), findsOneWidget, reason: 'one at a time struck, the bundle');
        expect(find.text('Save 5 ICR credits vs one at a time'), findsOneWidget);
        // Above the cards, so it is seen before the first set.
        final strip = tester.getTopLeft(find.byKey(const ValueKey('bundle-offer'))).dy;
        final firstSet = tester.getTopLeft(_card('aee-cbcp-set-1')).dy;
        // The sets lead and the bundle follows them (the owner's rule of 30 Oct 2026: the cards stay in the first view).
        expect(strip, greaterThan(firstSet));

        await tester.tap(find.byKey(const ValueKey('bundle-redeem-credits')));
        await tester.pumpAndSettle();
        expect(find.text('5 ICR Credits for “AEE CBCP”?'), findsOneWidget);
        expect(find.text('All 2 sets open permanently. You will have 95 ICR credits left.'), findsOneWidget);
        await tester.tap(find.widgetWithText(ActionButton, 'Redeem 5 Credits'));
        await tester.pumpAndSettle();

        expect(h.fake.calls, contains('redeemBundle:mock:aee-cbcp'));
        expect(_button('aee-cbcp-set-1', 'Start Test'), findsOneWidget);
        expect(_button('aee-cbcp-set-2', 'Start Test'), findsOneWidget);
        expect(find.text('2 sets opened with 5 ICR credits.'), findsOneWidget);
        expect(find.byKey(const ValueKey('bundle-offer')), findsNothing, reason: 'nothing is left to bundle');
      });

      testWidgets('Cancel on the confirmation spends nothing', (tester) async {
        final h = await _group(tester, 'AEE CBCP', fake: FakeAssess(bundle: cbcpCredits()), mock: true);
        await tester.tap(find.byKey(const ValueKey('bundle-redeem-credits')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(h.fake.count('redeemBundle'), 0);
        expect(find.byKey(const ValueKey('bundle-offer')), findsOneWidget);
      });

      testWidgets('a balance that falls short turns the button off; the balance over the sets says what there is', (
        tester,
      ) async {
        final fake = FakeAssess(bundle: cbcpCredits(), member: assessMember(credits: 3));
        await _group(tester, 'AEE CBCP', fake: fake, mock: true);
        expect(find.text('You have 3 ICR credits · 1 credit = ₹100'), findsOneWidget);
        expect(find.widgetWithText(TextButton, 'Earn More'), findsOneWidget);
        expect(tester.widget<RowButton>(find.byKey(const ValueKey('bundle-redeem-credits'))).onPressed, isNull);
        await tester.tap(find.byKey(const ValueKey('bundle-redeem-credits')), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(fake.count('redeemBundle'), 0);
        expect(find.text('5 ICR Credits for “AEE CBCP”?'), findsNothing);
      });

      testWidgets('the API\'s refusal is shown as it is worded', (tester) async {
        final fake = FakeAssess(bundle: cbcpCredits());
        fake.failures['redeemBundle'] = ApiError(
          'A set was opened meanwhile, so what is left costs less. Please look again.',
          statusCode: 400,
        );
        await _group(tester, 'AEE CBCP', fake: fake, mock: true);
        await tester.tap(find.byKey(const ValueKey('bundle-redeem-credits')));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ActionButton, 'Redeem 5 Credits'));
        await tester.pumpAndSettle();
        expect(find.text('A set was opened meanwhile, so what is left costs less. Please look again.'), findsOneWidget);
        expect(_button('aee-cbcp-set-1', 'Start Test'), findsNothing);
      });

      testWidgets('without a credit bundle in the API\'s answer there is no strip (production today)', (tester) async {
        await _group(tester, 'AEE CBCP', mock: true);
        expect(find.byKey(const ValueKey('bundle-offer')), findsNothing);
      });

      testWidgets('while a plan place is free for the exam the plan opens it all, so no bundle is drawn', (
        tester,
      ) async {
        final fake = FakeAssess(
          bundle: cbcpCredits(),
          member: assessMember(open: {}, mocks: const PlanPlaces(limit: 1)),
        );
        await _group(tester, 'AEE CBCP', fake: fake, mock: true);
        expect(find.byKey(const ValueKey('bundle-offer')), findsNothing);
      });

      testWidgets('a priced set shows the list price, the discount, GST, the saving, the credits; Pay and Redeem', (
        tester,
      ) async {
        final quotes = assessQuotes();
        final list = 29900;
        quotes['aee-cem-set-1'] = PaperQuote(
          paperId: 'aee-cem-set-1',
          listPaisa: list,
          discountBps: 2000,
          discountPaisa: 5980,
          salePaisa: 23920,
          taxBps: 1800,
          taxPaisa: 4306,
          totalPaisa: 28226,
          payable: true,
          memberDiscount: true,
          memberPlan: 'Pro Plus',
          credits: 3,
        );
        final h = await _group(tester, 'AEE CEM', fake: FakeAssess(quotes: quotes), mock: true);
        expect(_in('aee-cem-set-1', find.text('₹239.20 + GST')), findsOneWidget);
        expect(
          _in('aee-cem-set-1', find.text('₹299  20% off  Pro Plus member price  or 3 ICR credits')),
          findsOneWidget,
          reason: 'the list price struck through, the percent off, the plan, the credits',
        );
        expect(_button('aee-cem-set-1', 'Pay Now'), findsOneWidget);
        expect(_button('aee-cem-set-1', 'Redeem'), findsOneWidget, reason: 'the credits are said beside the price');
        final paid = _stubPayments();
        await tester.tap(_button('aee-cem-set-1', 'Pay Now'));
        await tester.pumpAndSettle();
        expect(h.fake.checkouts, ['aee-cem-set-1']);
        expect(paid.single.fields, {'txnid': 'T1'});
      });

      testWidgets('a set with no price shows the credits alone, as before', (tester) async {
        await _group(tester, 'AEE CBCP', mock: true);
        expect(_button('aee-cbcp-set-1', 'Pay Now'), findsNothing);
        expect(_button('aee-cbcp-set-1', 'Redeem 5 ICR Credits'), findsOneWidget);
        expect(_in('aee-cbcp-set-1', find.text('5 ICR credits')), findsOneWidget);
      });
    });

    group('a programme\'s page', () {
      testWidgets('offers the money bundle and, beside it, the same levels in credits', (tester) async {
        final h = await _group(
          tester,
          'Contract Management',
          fake: FakeAssess(bundle: cmBoth(ends: '2026-12-31')),
        );
        expect(find.text('BUNDLE · 30% OFF'), findsOneWidget);
        expect(find.text('Get all 3 levels together'), findsOneWidget);
        expect(find.textContaining('₹1,607.90 + GST'), findsOneWidget);
        expect(find.text('Offer valid until 31 Dec 2026'), findsOneWidget);
        expect(find.text('23 credits  13 ICR credits'), findsOneWidget, reason: 'one at a time struck, the bundle');
        expect(find.text('Save 10 ICR credits'), findsOneWidget);
        expect(find.text('You have 100 ICR credits · 1 credit = ₹100'), findsOneWidget, reason: 'once, over the rows');

        final paid = _stubPayments();
        await tester.tap(find.byKey(const ValueKey('bundle-pay-now')));
        await tester.pumpAndSettle();
        expect(h.fake.checkouts, ['bundle:CM'], reason: 'a payment: the bundle\'s checkout, paid in the app');
        expect(paid.single.action, 'https://pay.test/_payment');
        expect(h.launcher.uris, isEmpty, reason: 'never back into the app\'s own screen for the same address');

        await tester.tap(find.byKey(const ValueKey('bundle-redeem-credits')));
        await tester.pumpAndSettle();
        expect(find.text('13 ICR Credits for “Contract Management”?'), findsOneWidget);
        expect(find.text('All 3 levels open permanently. You will have 87 ICR credits left.'), findsOneWidget);
      });

      testWidgets('a bundle that cannot be paid for online still redeems in credits', (tester) async {
        final h = await _group(tester, 'Contract Management', fake: FakeAssess(bundle: cmBoth(payable: false)));
        expect(find.text('Online payment is not available right now.'), findsWidgets);
        await tester.tap(find.byKey(const ValueKey('bundle-pay-now')), warnIfMissed: false);
        await tester.pump();
        expect(h.pay.uris, isEmpty);
        expect(find.byKey(const ValueKey('bundle-redeem-credits')), findsOneWidget);
      });

      testWidgets('with nothing priced the bundle is in credits alone, and a fully open programme shows none', (
        tester,
      ) async {
        final fake = FakeAssess(
          bundle: const BundleQuote(
            courseCode: 'CP',
            programmeTitle: 'Capital Planning',
            credits: 10,
            separateCredits: 15,
            creditsSaved: 5,
            creditsOffered: true,
            creditLevels: [
              BundleLevel(paperId: 'cp-foundation', title: 'Foundation', credits: 5),
              BundleLevel(paperId: 'cp-intermediate', title: 'Professional', credits: 5),
              BundleLevel(paperId: 'cp-advanced', title: 'Advanced', credits: 5),
            ],
          ),
        );
        await _group(tester, 'Capital Planning', fake: fake);
        expect(find.text('Open all 3 levels with ICR credits'), findsOneWidget);
        expect(find.text('15 credits  10 ICR credits'), findsOneWidget);
        expect(find.byKey(const ValueKey('bundle-redeem-credits')), findsOneWidget);
        expect(find.byKey(const ValueKey('bundle-pay-now')), findsNothing);

        final open = FakeAssess(bundle: fake.bundleQuoteNow, member: assessMember(allOpen: true));
        await _group(tester, 'Capital Planning', fake: open);
        expect(find.byKey(const ValueKey('bundle-offer')), findsNothing);
      });
    });

    group('back in front after a payment on the website', () {
      Future<void> comeBack(WidgetTester tester) async {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pumpAndSettle();
      }

      testWidgets('a level paid for in the browser shows open without a pull, and its offer is quoted again', (
        tester,
      ) async {
        final h = await _group(tester, 'Contract Management', fake: FakeAssess(bundle: cmBoth()));
        expect(_button('cm-foundation', 'Start Assessment'), findsNothing);
        final memberReads = h.fake.count('member');
        final bundleReads = h.fake.count('bundleQuote');

        // The person paid for Foundation on the website.
        final access = h.fake.memberNow.access!;
        h.fake.memberNow = h.fake.memberNow.copyWith(
          access: access.copyWith(paperIds: {...access.paperIds, 'cm-foundation'}),
        );
        await comeBack(tester);

        expect(h.fake.count('member'), greaterThan(memberReads));
        expect(h.fake.count('bundleQuote'), greaterThan(bundleReads));
        expect(_button('cm-foundation', 'Start Assessment'), findsOneWidget);
      });

      testWidgets('the landing reads what the member holds again too', (tester) async {
        final h = await _landing(tester);
        final reads = h.fake.count('member');
        await comeBack(tester);
        expect(h.fake.count('member'), greaterThan(reads));
      });
    });
  });
}
