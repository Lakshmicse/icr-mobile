/// Assess Your Knowledge and Mock Exams against the LOCAL portal API, signed in as the seeded personas (Bharat
/// Buyer: 100 ICR credits, two levels opened with them, and plan places that vary: none from the seed, twelve while
/// `learning-study.ts --grant-bharat` is in; Pooja Professional: about 150 credits, a number of sets opened, one
/// empty sitting, and **no plan places**). Run with the API up: `flutter test test/live/learning_assess_live_test.dart`.
///
/// Nothing here depends on how many places Bharat holds: what needs an account with none (a refused plan place,
/// closed priced levels, the sale and the bundle) runs as Pooja, and what Bharat is used for is derived from the API's
/// own answers (its quote's `alreadyOpen`, its unlock list, his attempt history).
///
/// What a test writes it undoes, with two exceptions the API gives no way back from:
///
///  * ICR credits spent on a paper. `POST /learning/papers/:slug/redeem` opens a paper "for good" and the API has no
///    route that takes it back. The one test that redeems does it as Pooja, on a set she does not hold yet, and
///    leaves it open: each run uses one set and its credits (about 5 of her 180). When she holds every set she can
///    afford, that test says so and skips instead of failing.
///  * Nothing else is left behind: the global discount the sale test switches on (as ICR staff) is put back.
///
/// The screens are drawn from the real API with the pictures it would fetch left out (a widget test cannot reach the
/// network for images); real calls run outside the test's fake clock.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/learning_assess/api_assess_repository.dart';
import 'package:icr_mobile/features/learning_assess/assess_format.dart';
import 'package:icr_mobile/features/learning_assess/assess_models.dart';
import 'package:icr_mobile/features/learning_assess/assess_repository.dart';
import 'package:icr_mobile/features/learning_assess/assessment_screen.dart';
import 'package:icr_mobile/features/learning_assess/catalogue_controller.dart';
import 'package:icr_mobile/features/learning_assess/group_controller.dart';
import 'package:icr_mobile/features/learning_assess/mock_tests_screen.dart';
import 'package:icr_mobile/features/learning_assess/widgets/group_card.dart';
import 'package:icr_mobile/features/learning_assess/widgets/paper_card.dart';

import '../helpers/assess_fixtures.dart';
import '../helpers/fonts.dart';
import 'live.dart';

/// ICR staff, who may switch the global discount on and off.
const _staff = LivePerson('superadmin@icr.test', 'Test@12345', 'Sana Admin');

/// One sign-in per person for the whole file: the API allows ten logins a minute from one address, and every
/// other live test file shares that allowance.
final _clients = <String, Future<ApiClient>>{};

Future<ApiClient> _as(LivePerson who) => _clients[who.email] ??= liveClient(who);

Future<ApiAssessRepository> _repoFor(LivePerson who) async => ApiAssessRepository(api: await _as(who));

/// A client for a screen: its own connection pool (and the same sign-in), because a socket opened while a widget
/// test's fake clock drives the page belongs to that clock's zone, and a request from the real zone that reuses it
/// is never answered until the next pump. The file's `_as` clients are for reads made outside the screen; a 429 is
/// waited out as the file's own clients do.
ApiClient _screenClient(ApiClient signedIn) {
  final client = ApiClient(tokens: signedIn.tokens, baseUrl: liveBaseUrl);
  client.dio.interceptors.add(
    InterceptorsWrapper(
      onError: (error, handler) async {
        final tries = (error.requestOptions.extra['throttled'] as int?) ?? 0;
        if (error.response?.statusCode != 429 || tries >= 6) return handler.next(error);
        final wait = int.tryParse(error.response?.headers.value('retry-after') ?? '') ?? 6;
        await Future<void>.delayed(Duration(seconds: wait.clamp(2, 20)));
        error.requestOptions.extra['throttled'] = tries + 1;
        try {
          handler.resolve(await client.dio.fetch(error.requestOptions));
        } on DioException catch (again) {
          handler.next(again);
        }
      },
    ),
  );
  return client;
}

Future<List<Map<String, dynamic>>> _rows(ApiClient api, String path, [Map<String, dynamic>? query]) async {
  final res = await api.dio.get<dynamic>(path, queryParameters: query);
  return (res.data as List).cast<Map<String, dynamic>>();
}

Future<Map<String, dynamic>> _json(ApiClient api, String path) async =>
    (await api.dio.get<Map<String, dynamic>>(path)).data!;

/// The live source with the pictures it would fetch left out.
class _Bare implements AssessRepository {
  _Bare(this.inner);

  final AssessRepository inner;

  AssessPaper _paper(AssessPaper p) => AssessPaper(
    id: p.id,
    slug: p.slug,
    title: p.title,
    kind: p.kind,
    subtitle: p.subtitle,
    description: p.description,
    level: p.level,
    free: p.free,
    priceAmount: p.priceAmount,
    priceCurrency: p.priceCurrency,
    creditCost: p.creditCost,
    questions: p.questions,
    durationMinutes: p.durationMinutes,
    passPercentage: p.passPercentage,
    attemptLimit: p.attemptLimit,
    certificateEnabled: p.certificateEnabled,
    courseId: p.courseId,
    topicId: p.topicId,
    sortOrder: p.sortOrder,
  );

  PaperGroup _group(PaperGroup g) => PaperGroup(
    kind: g.kind,
    id: g.id,
    key: g.key,
    title: g.title,
    summary: g.summary,
    knowledgeAreas: g.knowledgeAreas,
    papers: [for (final p in g.papers) _paper(p)],
    sortOrder: g.sortOrder,
    partner: g.partner,
  );

  @override
  Future<List<PaperGroup>> groups(PaperKind kind) async => [for (final g in await inner.groups(kind)) _group(g)];
  @override
  Future<PaperGroup> group(PaperKind kind, String key) async => _group(await inner.group(kind, key));
  @override
  Future<MemberLearning> member(PaperKind kind) => inner.member(kind);
  @override
  Future<PaperQuote> quote(AssessPaper paper) => inner.quote(paper);
  @override
  Future<BundleQuote> bundleQuote(String key, {PaperKind kind = PaperKind.assessment}) =>
      inner.bundleQuote(key, kind: kind);
  @override
  Future<RedeemBundleResult> redeemBundle(PaperKind kind, String key) => inner.redeemBundle(kind, key);
  @override
  Future<AssessmentPricing> pricing() => inner.pricing();
  @override
  Future<RedeemResult> redeem(AssessPaper paper) => inner.redeem(paper);
  @override
  Future<void> openWithPlan(PaperKind kind, String targetId) => inner.openWithPlan(kind, targetId);
  @override
  Future<int> unreadNotifications() => inner.unreadNotifications();
  @override
  Uri paperLink(PaperGroup group, AssessPaper paper) => inner.paperLink(group, paper);
  @override
  Uri groupLink(PaperGroup group) => inner.groupLink(group);
  @override
  Uri plansLink() => inner.plansLink();
  @override
  Uri partnerLink() => inner.partnerLink();
}

/// A live test that draws a screen: skipped, with a reason, when the API is not running.
void liveWidgetTest(String description, Future<void> Function(WidgetTester tester) body) {
  testWidgets(
    description,
    (tester) async {
      if (await tester.runAsync(liveApiReachable) != true) {
        markTestSkipped('the local API is not running at $liveBaseUrl');
        return;
      }
      await body(tester);
      // Let what the screen still has in flight finish (its progress bar is the sign), so no request's timeout
      // is left on the fake clock.
      await _settle(tester, until: () => find.byType(LinearProgressIndicator).evaluate().isEmpty);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
      await tester.pump(const Duration(milliseconds: 100));
      // Let go of the screen and run the fake clock past the idle timers the HTTP client left on it (a pooled
      // connection waits three seconds), or the test ends with timers pending.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
    },
    tags: const ['live'],
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

/// Lets real network calls finish and the tree catch up. Plain pumps, never `pumpAndSettle`: while a page loads its
/// progress bar animates for ever, and settling it would run the fake clock past the requests' own timeouts.
Future<void> _settle(WidgetTester tester, {required bool Function() until}) async {
  for (var i = 0; i < 120 && !until(); i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump(const Duration(milliseconds: 300));
}

/// A tap whose handler talks to the network: it runs outside the test's fake clock.
Future<void> _tapOnline(WidgetTester tester, Finder finder) async {
  await tester.runAsync(() => tester.tap(finder));
  await tester.pump();
}

Future<void> _pumpScreen(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(780, 9000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, theme: buildAppTheme(), home: screen));
}

Finder _card(String paperId) => find.byKey(ValueKey('paper-$paperId'));

/// The API's own verdict on every paper of a few programmes and subjects: its quote says `alreadyOpen` for anything
/// the member may sit, or that a plan place would open for nothing. Our derivation must agree on each, whatever the
/// member holds. Returns what came out open, with a plan place free, and closed.
Future<({int open, int plan, int closed, List<AssessPaper> openPapers, List<AssessPaper> closedPapers})> _agreesWithApi(
  ApiClient api,
) async {
  final repo = ApiAssessRepository(api: api);
  final member = await repo.member(PaperKind.assessment);
  final mockMember = await repo.member(PaperKind.mock);
  final raw = await _json(api, '/learning/me/paper-unlocks');
  final access = member.access!;
  expect(access.icrCredits, raw['icrCredits']);
  expect(access.paperIds, (raw['paperIds'] as List).cast<String>().toSet());
  expect(access.allOpen, raw['allOpen']);
  expect(access.courses.limit, (raw['plan'] as Map)['assessmentCourses']['limit']);
  expect(access.courses.opened, ((raw['plan'] as Map)['assessmentCourses']['openedCourseIds'] as List).cast<String>());

  final groups = [
    for (final g in await repo.groups(PaperKind.assessment))
      if (['CP', 'CM', 'PM'].contains(g.key)) g,
  ];
  final topics = [
    for (final g in await repo.groups(PaperKind.mock))
      if (['aee-cbcp', 'aee-cem'].contains(g.key)) g,
  ];
  expect(groups, isNotEmpty);
  expect(topics, isNotEmpty);
  final openPapers = <AssessPaper>[];
  final closedPapers = <AssessPaper>[];
  var plan = 0;
  for (final g in [...groups, ...topics]) {
    final m = g.kind == PaperKind.mock ? mockMember : member;
    for (final p in g.papers) {
      final quote = await _json(api, '/learning/papers/${p.slug}/quote');
      final derived = m.accessOf(p);
      expect(
        derived != PaperAccess.closed,
        quote['alreadyOpen'],
        reason: '${g.title} – ${p.title}: ours says $derived, the API says alreadyOpen=${quote['alreadyOpen']}',
      );
      switch (derived) {
        case PaperAccess.open:
          openPapers.add(p);
        case PaperAccess.planPlace:
          plan++;
        case PaperAccess.closed:
          closedPapers.add(p);
      }
    }
  }
  return (
    open: openPapers.length,
    plan: plan,
    closed: closedPapers.length,
    openPapers: openPapers,
    closedPapers: closedPapers,
  );
}

void main() {
  setUpAll(loadAppFonts);

  // --- the catalogue ------------------------------------------------------------------------------------

  liveTest('the programmes are the assessment courses that have papers, each with exactly the API\'s papers', () async {
    final api = await _as(bharat);
    final groups = await ApiAssessRepository(api: api).groups(PaperKind.assessment);
    final courses = await _rows(api, '/learning/courses', {'kind': 'ASSESSMENT'});
    final papers = await _rows(api, '/learning/papers', {'kind': 'ASSESSMENT'});
    final byCourse = <String, List<Map<String, dynamic>>>{};
    for (final p in papers) {
      final course = p['courseId'] as String?;
      if (course != null) (byCourse[course] ??= []).add(p);
    }
    final expected = [
      for (final c in courses)
        if ((byCourse[c['id']] ?? const []).isNotEmpty) c,
    ];
    expect(groups.map((g) => g.key), expected.map((c) => c['code']));
    for (final g in groups) {
      expect(g.kind, PaperKind.assessment);
      expect(g.papers.length, byCourse[g.id]!.length, reason: '${g.title}: one paper per level the API lists');
      expect(g.papers.every((p) => p.kind == PaperKind.assessment && p.courseId == g.id), isTrue);
      expect(g.papers.every((p) => p.questions > 0 && p.durationMinutes > 0 && p.passPercentage > 0), isTrue);
    }

    final cp = groups.firstWhere((g) => g.key == 'CP', orElse: () => throw TestFailure('the seeded CP programme'));
    expect(cp.title, 'Capital Planning');
    expect([for (final p in cp.ladder) p.level], ['FOUNDATION', 'INTERMEDIATE', 'ADVANCED']);
    expect(cp.knowledgeAreas, isNotEmpty);
    expect(levelsLine(cp), 'Foundation · Professional · Advanced');
    final cm = groups.firstWhere((g) => g.key == 'CM');
    expect(cm.papers.every((p) => p.priced && !p.free), isTrue, reason: 'Contract Management is sold level by level');

    // The cover is a real picture the app will fetch (the upload route sends no content type for it: sniff the bytes).
    final cover = cp.cover!.url!;
    expect(cover, startsWith('http://'));
    final image = await Dio().get<List<int>>(cover, options: Options(responseType: ResponseType.bytes));
    expect(image.statusCode, 200);
    expect(image.data!.take(4).toList(), [0x89, 0x50, 0x4E, 0x47], reason: 'a PNG');
  });

  liveTest('the subjects are the mock topics that have sets, each set filed under its topic', () async {
    final api = await _as(bharat);
    final topics = await ApiAssessRepository(api: api).groups(PaperKind.mock);
    final raw = await _rows(api, '/learning/topics');
    expect(topics.map((t) => t.key), [
      for (final t in raw)
        if ((t['papers'] as List).isNotEmpty) t['slug'],
    ]);
    for (final t in topics) {
      expect(t.kind, PaperKind.mock);
      final rawSets = (raw.firstWhere((r) => r['slug'] == t.key)['papers'] as List);
      expect(t.papers.length, rawSets.length, reason: '${t.title}: its sets');
      expect(t.papers.every((p) => p.kind == PaperKind.mock && p.topicId == t.id && p.targetId == t.id), isTrue);
    }
    expect(topics.length, greaterThanOrEqualTo(20), reason: 'the seeded mock subjects');
    final cbcp = topics.firstWhere((t) => t.key == 'aee-cbcp');
    expect(cbcp.title, 'AEE CBCP');
    expect(cbcp.papers.map((p) => p.title), ['Set 1', 'Set 2']);
    expect(cbcp.papers.first.attemptLimit, 3, reason: 'the seed limits its attempts');
    expect(setsLine(cbcp), '2 sets · 10 questions');
  });

  liveTest('one programme and one subject are read by their own routes', () async {
    final repo = await _repoFor(bharat);
    final cp = await repo.group(PaperKind.assessment, 'CP');
    expect(cp.papers.map((p) => p.slug), containsAll(['capital-planning-foundation', 'capital-planning-advanced']));
    expect(cp.knowledgeAreas.length, greaterThan(5));
    final t = await repo.group(PaperKind.mock, 'aee-cbcp');
    expect(t.papers.length, 2);
    await expectLater(
      repo.group(PaperKind.assessment, 'NO-SUCH-PROGRAMME'),
      throwsA(isA<ApiError>().having((e) => e.statusCode, 'status', 404)),
    );
    await expectLater(
      repo.group(PaperKind.mock, 'no-such-subject'),
      throwsA(isA<ApiError>().having((e) => e.statusCode, 'status', 404)),
    );
  });

  // --- what the member holds ---------------------------------------------------------------------------

  liveTest(
    'which papers are open to a member is what the API itself says: its quote, whatever plan places they hold (Bharat and Pooja)',
    () async {
      // Bharat: his places vary (none, or a grant of twelve), so only the agreement with the API is asserted.
      final bharatApi = await _as(bharat);
      final his = await _agreesWithApi(bharatApi);
      expect(his.open + his.plan + his.closed, greaterThan(5));
      expect(his.open, greaterThan(0), reason: 'two levels were opened with credits');

      // Pooja holds no plan place: most levels are closed to her, and the paper route says the same as the quote.
      final api = await _as(pooja);
      final hers = await _agreesWithApi(api);
      expect(hers.plan, 0, reason: 'a plan with no places leaves nothing for a place to open');
      expect(hers.closed, greaterThan(0));
      expect(hers.open, greaterThan(0), reason: 'and some sets were opened with credits');

      final served = await api.dio.get<Map<String, dynamic>>('/learning/papers/${hers.openPapers.first.slug}');
      expect(served.statusCode, 200, reason: 'a paper open to her is served');
      await expectLater(
        api.dio.get<dynamic>('/learning/papers/${hers.closedPapers.first.slug}'),
        throwsA(
          isA<DioException>()
              .having((e) => e.response?.statusCode, 'status', 403)
              .having((e) => (e.response?.data as Map)['code'], 'code', 'PAPER_LOCKED'),
        ),
      );
    },
  );

  liveTest('each paper\'s attempts, best score and pass are what the API\'s history adds up to (Pooja)', () async {
    final api = await _as(pooja);
    final repo = ApiAssessRepository(api: api);
    final attempts = await _rows(api, '/learning/me/attempts');
    expect(attempts, isNotEmpty, reason: 'Pooja has a sitting on record (the e2e suite\'s)');
    final assessment = await repo.member(PaperKind.assessment);
    final mock = await repo.member(PaperKind.mock);
    final byPaper = <String, List<Map<String, dynamic>>>{};
    for (final a in attempts) {
      (byPaper[a['paperId'] as String] ??= []).add(a);
    }
    for (final e in byPaper.entries) {
      final kind = PaperKind.fromApi((e.value.first['paper'] as Map)['kind'] as String?);
      final progress = (kind == PaperKind.mock ? mock : assessment).progressOf(e.key);
      expect(progress.attempts, e.value.length, reason: 'attempts on ${e.key}');
      expect(
        progress.bestPercent,
        e.value.map((a) => a['percentage'] as int).reduce((a, b) => a > b ? a : b),
        reason: 'best score on ${e.key}',
      );
      expect(progress.passed, e.value.any((a) => a['passed'] == true));
    }
    // A door reads only its own kind's sittings.
    final mockOnly = byPaper.keys.where((id) => (byPaper[id]!.first['paper'] as Map)['kind'] == 'MOCK');
    for (final id in mockOnly) {
      expect(assessment.progressOf(id).started, isFalse, reason: 'a mock sitting is not an assessment\'s');
    }
  });

  // --- what it costs -------------------------------------------------------------------------------------

  liveTest(
    'a closed priced level\'s quote is the API\'s: the price after the better discount, and the credits that open it',
    () async {
      final api = await _as(pooja);
      final repo = ApiAssessRepository(api: api);
      final pm = await repo.group(PaperKind.assessment, 'PM');
      final foundation = pm.papers.firstWhere((p) => p.level == 'FOUNDATION');
      expect(
        foundation.priced,
        isTrue,
        reason: 'Procurement Management\'s Foundation level is the paid one, closed to Pooja (no plan place)',
      );
      final quote = await repo.quote(foundation);
      final raw = await _json(api, '/learning/papers/${foundation.slug}/quote');
      expect(quote.paperId, foundation.id);
      expect(quote.listPaisa, foundation.priceAmount);
      expect(quote.listPaisa, raw['listPaisa']);
      expect(quote.salePaisa, raw['salePaisa']);
      expect(quote.salePaisa, quote.listPaisa - quote.discountPaisa);
      expect(quote.totalPaisa, quote.salePaisa + quote.taxPaisa);
      expect(quote.credits, raw['credits']);
      expect(quote.credits, isNotNull);
      expect(quote.alreadyOpen, isFalse);
      expect(rupees(quote.listPaisa), '₹499');
      // Credits are the price at the credit's value, rounded up, unless staff set them on the paper.
      expect(quote.rupeesPerCredit, greaterThan(0));
    },
  );

  liveTest(
    'a sale and a bundle: staff switch the discounts on, the quotes and the offer follow, and they are put back',
    () async {
      final staff = await _as(_staff);
      // Pooja: no plan place, and Contract Management's Foundation and Professional levels closed to her.
      final repo = await _repoFor(pooja);
      final before = await repo.pricing();
      try {
        final put = await staff.dio.put<Map<String, dynamic>>(
          '/learning/admin/assessment-pricing',
          data: {'discountPercent': 40, 'bundleDiscountPercent': 50},
        );
        expect(put.data!['discountPercent'], 40);
        final pricing = await repo.pricing();
        expect(pricing.discountPercent, 40);
        expect(pricing.bundleDiscountPercent, 50);

        final cm = await repo.group(PaperKind.assessment, 'CM');
        final foundation = cm.papers.firstWhere((p) => p.level == 'FOUNDATION');
        final quote = await repo.quote(foundation);
        expect(quote.discounted, isTrue);
        expect(quote.discountBps, greaterThanOrEqualTo(4000), reason: 'the better of the sale and her plan discount');
        expect(quote.salePaisa, quote.listPaisa - quote.discountPaisa);
        if (quote.discountBps == 4000) expect(quote.salePaisa, 29940, reason: '₹499 less 40%');

        final bundle = await repo.bundleQuote('CM');
        expect(
          bundle.levels.length,
          greaterThanOrEqualTo(2),
          reason: 'at least two of Contract Management\'s priced levels are closed to Pooja',
        );
        expect(bundle.offered, isTrue);
        expect(bundle.discountBps, 5000);
        expect(bundle.salePaisa, lessThan(bundle.separateSalePaisa));
        expect(bundle.savePaisa, bundle.separateSalePaisa - bundle.salePaisa);
        expect(bundle.programmeTitle, 'Contract Management');
      } finally {
        await staff.dio.put<dynamic>(
          '/learning/admin/assessment-pricing',
          data: {'discountPercent': before.discountPercent, 'bundleDiscountPercent': before.bundleDiscountPercent},
        );
      }
      final restored = await repo.pricing();
      expect(restored.discountPercent, before.discountPercent);
      expect(restored.bundleDiscountPercent, before.bundleDiscountPercent);
    },
  );

  // --- what a refusal does -------------------------------------------------------------------------------

  liveTest(
    'a plan place the API refuses, and a paper it does not know, leave the page as it was and say why',
    () async {
      // Pooja's plan has no place for a course (Bharat's may, while the owner's grant is in).
      final repo = await _repoFor(pooja);
      final catalogue = CatalogueController(repository: repo, kind: PaperKind.assessment);
      await catalogue.start();
      final cm = catalogue.groups.firstWhere((g) => g.key == 'CM');
      final g = GroupController(repository: repo, catalogue: catalogue, seed: cm);
      addTearDown(g.dispose);
      await g.start();
      final creditsBefore = catalogue.member.access!.icrCredits;
      final opensBefore = [...catalogue.member.access!.courses.opened];
      final accessBefore = [for (final p in cm.papers) g.entry(p).access];
      expect(g.placeState, PlaceState.locked);
      expect(accessBefore, contains(PaperAccess.closed));

      // The API refuses, and nothing on the page changes.
      final refused = await g.openWithPlan();
      expect(refused, contains('plan'), reason: 'the API\'s own sentence: ${refused ?? ''}');
      expect(g.placeState, PlaceState.locked);
      expect(g.openingWithPlan, isFalse);
      expect(catalogue.member.access!.courses.opened, opensBefore);
      expect([for (final p in cm.papers) g.entry(p).access], accessBefore);

      // A paper nobody published: 404 with the API's words, and the credits stay.
      const ghost = AssessPaper(id: 'ghost', slug: 'no-such-paper-slug', title: 'Ghost', kind: PaperKind.assessment);
      final missing = await g.redeem(ghost);
      expect(missing, isNotNull);
      expect(missing, isNot(contains('Something went wrong')), reason: 'the API\'s own sentence, not a generic one');
      expect(catalogue.member.access!.icrCredits, creditsBefore);
      expect(g.entry(ghost).busy, isFalse);

      await expectLater(
        repo.openWithPlan(PaperKind.assessment, 'no-such-course-id'),
        throwsA(isA<ApiError>().having((e) => e.statusCode, 'status', anyOf(404, 403))),
      );
    },
  );

  liveTest('redeeming a level already open spends nothing', () async {
    final repo = await _repoFor(bharat);
    final member = await repo.member(PaperKind.assessment);
    final groups = await repo.groups(PaperKind.assessment);
    final open = groups
        .expand((g) => g.papers)
        .firstWhere((p) => member.accessOf(p) == PaperAccess.open && member.access!.paperIds.contains(p.id));
    final result = await repo.redeem(open);
    expect(result.unlocked, isTrue);
    expect(result.spent, 0);
    expect(result.credits, member.access!.icrCredits, reason: 'no credit taken for a level already open');
  });

  // --- the screens, drawn from the real API ---------------------------------------------------------------

  liveWidgetTest('Assess Your Knowledge draws the real programmes; the search narrows them; a card opens its levels', (
    tester,
  ) async {
    // Pooja: no plan place, so Contract Management's priced levels that are not hers read closed. What she holds is
    // read from the API outside the screen, and the screen is held to it.
    final api = (await tester.runAsync(() => _as(pooja)))!;
    final raw = (await tester.runAsync(() => _rows(api, '/learning/courses', {'kind': 'ASSESSMENT'})))!;
    final rawPapers = (await tester.runAsync(() => _rows(api, '/learning/papers', {'kind': 'ASSESSMENT'})))!;
    final withPapers = raw.where((c) => rawPapers.any((p) => p['courseId'] == c['id'])).length;
    final reader = ApiAssessRepository(api: api);
    final member = (await tester.runAsync(() => reader.member(PaperKind.assessment)))!;
    final cm = (await tester.runAsync(() => reader.group(PaperKind.assessment, 'CM')))!;
    final closedPriced = [
      for (final p in cm.papers)
        if (member.accessOf(p) == PaperAccess.closed && p.priced) p,
    ];
    final open = cm.papers.where((p) => member.accessOf(p) == PaperAccess.open).length;
    expect(closedPriced, isNotEmpty, reason: 'Pooja\'s plan opens no course: her unopened levels are closed to her');
    final quotes = <String, Map<String, dynamic>>{
      for (final p in closedPriced)
        p.id: (await tester.runAsync(() => _json(api, '/learning/papers/${p.slug}/quote')))!,
    };
    final opener = RecordingOpener();
    final launcher = RecordingLauncher();

    await _pumpScreen(
      tester,
      AssessmentScreen(
        onBack: () {},
        repository: _Bare(ApiAssessRepository(api: _screenClient(api))),
        opener: opener.call,
        launcher: launcher.call,
      ),
    );
    await _settle(tester, until: () => find.byType(GroupCard).evaluate().isNotEmpty);
    expect(
      find.byType(GroupCard),
      findsNWidgets(withPapers),
      reason: 'ICR\'s own programmes (none is a partner\'s here)',
    );
    expect(find.text('Assess Your Knowledge'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'contract');
    await tester.pumpAndSettle();
    expect(find.byType(GroupCard), findsOneWidget);
    expect(find.descendant(of: find.byType(GroupCard), matching: find.text('Contract Management')), findsOneWidget);
    // The foot says how much of it is open to her, as the API counts it.
    final foot = open == 0
        ? 'Locked'
        : open == cm.papers.length
        ? 'Open'
        : '$open of ${cm.papers.length} open';
    expect(find.descendant(of: find.byType(GroupCard), matching: find.text(foot)), findsOneWidget);

    await tester.tap(find.byType(GroupCard));
    await tester.pump();
    // The levels show at once; the prices arrive after them.
    await _settle(tester, until: () => find.text('Pay on the website').evaluate().length >= closedPriced.length);
    expect(find.byType(PaperCard), findsNWidgets(cm.papers.length));
    expect(
      find.text('Pay on the website'),
      findsNWidgets(closedPriced.length),
      reason: 'a Pay button for every priced level that is closed to her, none for one she holds',
    );
    for (final p in closedPriced) {
      final sale = quotes[p.id]!['salePaisa'] as int;
      expect(
        find.descendant(of: _card(p.id), matching: find.text(rupees(sale))),
        findsOneWidget,
        reason: '${p.title}: the price after the discount, as the API quotes it',
      );
    }
    expect(opener.opened, isEmpty);
  });

  liveWidgetTest('a level open to Bharat starts through the exam; Start hands over its slug, name and programme', (
    tester,
  ) async {
    final api = (await tester.runAsync(() => _as(bharat)))!;
    final opener = RecordingOpener();
    await _pumpScreen(
      tester,
      AssessmentScreen(
        onBack: () {},
        repository: _Bare(ApiAssessRepository(api: _screenClient(api))),
        opener: opener.call,
        launcher: RecordingLauncher().call,
      ),
    );
    await _settle(tester, until: () => find.byType(GroupCard).evaluate().isNotEmpty);
    await tester.enterText(find.byType(TextField), 'capital planning');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(GroupCard).first);
    await tester.pump();
    await _settle(tester, until: () => find.byType(PaperCard).evaluate().length >= 3);
    // Wait for the page to finish loading (its progress bar goes): whether a level shows a price, a place to open or
    // a button to redeem depends on what Bharat's plan holds, so no particular button is waited for.
    await _settle(tester, until: () => find.byType(LinearProgressIndicator).evaluate().isEmpty);

    // Capital Planning's Foundation and Advanced were opened with credits, whatever the plan holds.
    final cards = tester.widgetList<PaperCard>(find.byType(PaperCard)).toList();
    final firstOpen = cards.firstWhere((c) => c.entry.isOpen);
    expect(cards.where((c) => c.entry.isOpen).length, greaterThanOrEqualTo(2));
    // What the exam made of earlier sittings shows as the best score the API's history adds up to.
    final raw = (await tester.runAsync(() => _rows(api, '/learning/me/attempts', {'kind': 'ASSESSMENT'})))!;
    final mine = raw.where((a) => a['paperId'] == firstOpen.entry.paper.id).toList();
    final label = mine.isEmpty ? 'Start Assessment' : 'Retake assessment';
    if (mine.isNotEmpty) {
      final best = mine.map((a) => a['percentage'] as int).reduce((a, b) => a > b ? a : b);
      expect(firstOpen.entry.progress.attempts, mine.length);
      expect(firstOpen.entry.progress.bestPercent, best);
      expect(
        find.descendant(of: _card(firstOpen.entry.paper.id), matching: find.textContaining('Best score $best%')),
        findsOneWidget,
      );
    }
    final start = find.descendant(
      of: _card(firstOpen.entry.paper.id),
      matching: find.widgetWithText(ActionButton, label),
    );
    expect(start, findsOneWidget);
    await _tapOnline(tester, start);
    await _settle(tester, until: () => opener.opened.isNotEmpty);
    final ref = opener.opened.single;
    expect(ref.slug, firstOpen.entry.paper.slug);
    expect(ref.title, 'Capital Planning – ${firstOpen.entry.paper.title}');
    expect(ref.courseCode, 'CP');
    expect(ref.isMock, isFalse);
    expect(ref.id, firstOpen.entry.paper.id);
  });

  liveWidgetTest(
    'the sale strip and the bundle offer are drawn from the live discounts (staff set them, then put them back)',
    (tester) async {
      final staff = (await tester.runAsync(() => _as(_staff)))!;
      // Pooja holds no plan place: Contract Management's Foundation and Professional levels are closed to her.
      final api = (await tester.runAsync(() => _as(pooja)))!;
      final reader = ApiAssessRepository(api: api);
      final before = (await tester.runAsync(reader.pricing))!;
      try {
        await tester.runAsync(
          () => staff.dio.put<dynamic>(
            '/learning/admin/assessment-pricing',
            data: {'discountPercent': 40, 'bundleDiscountPercent': 50},
          ),
        );
        // What the API says about it now, to hold the screen to.
        final cm = (await tester.runAsync(() => reader.group(PaperKind.assessment, 'CM')))!;
        final foundation = cm.papers.firstWhere((p) => p.level == 'FOUNDATION');
        final quote = (await tester.runAsync(() => reader.quote(foundation)))!;
        final bundle = (await tester.runAsync(() => reader.bundleQuote('CM')))!;
        expect(bundle.offered, isTrue);
        expect(bundle.levels.length, greaterThanOrEqualTo(2));
        final unlockLabel = bundle.levels.length == 1
            ? 'Unlock it on the website'
            : 'Unlock all ${bundle.levels.length} levels on the website';

        final launcher = RecordingLauncher();
        await _pumpScreen(
          tester,
          AssessmentScreen(
            onBack: () {},
            repository: _Bare(ApiAssessRepository(api: _screenClient(api))),
            opener: RecordingOpener().call,
            launcher: launcher.call,
          ),
        );
        await _settle(tester, until: () => find.byType(GroupCard).evaluate().isNotEmpty);
        await tester.enterText(find.byType(TextField), 'contract');
        await tester.pumpAndSettle();
        await tester.tap(find.byType(GroupCard));
        await tester.pump();
        await _settle(tester, until: () => find.byKey(const ValueKey('bundle-offer')).evaluate().isNotEmpty);
        expect(find.text('40% off every assessment level'), findsOneWidget);
        expect(find.text('${quote.discountBps ~/ 100}% OFF'), findsWidgets);
        expect(
          find.descendant(of: _card(foundation.id), matching: find.text(rupees(quote.salePaisa))),
          findsOneWidget,
          reason: 'the price after the better discount, as the API quotes it',
        );
        expect(find.text('BUNDLE · ${bundle.discountBps ~/ 100}% OFF'), findsOneWidget);
        expect(find.text(rupees(bundle.salePaisa)), findsOneWidget);
        expect(find.text('Save ${rupees(bundle.savePaisa)} vs buying separately'), findsOneWidget);
        final unlock = find.text(unlockLabel);
        expect(unlock, findsOneWidget);
        await tester.ensureVisible(unlock);
        await tester.pumpAndSettle();
        await tester.tap(unlock);
        await tester.pump();
        expect(launcher.uris.single.path, '/learning/assessment/cm', reason: 'the website\'s page for the programme');
      } finally {
        await tester.runAsync(
          () => staff.dio.put<dynamic>(
            '/learning/admin/assessment-pricing',
            data: {'discountPercent': before.discountPercent, 'bundleDiscountPercent': before.bundleDiscountPercent},
          ),
        );
      }
    },
  );

  liveWidgetTest('Mock Exams draws the real subjects; a card opens its sets with their attempts and locks', (
    tester,
  ) async {
    final api = (await tester.runAsync(() => _as(bharat)))!;
    final raw = (await tester.runAsync(() => _rows(api, '/learning/topics')))!;
    final expected = raw.where((t) => (t['papers'] as List).isNotEmpty).length;
    await _pumpScreen(
      tester,
      MockTestsScreen(
        onBack: () {},
        repository: _Bare(ApiAssessRepository(api: _screenClient(api))),
        opener: RecordingOpener().call,
        launcher: RecordingLauncher().call,
      ),
    );
    await _settle(tester, until: () => find.byType(GroupCard).evaluate().isNotEmpty);
    expect(find.byType(GroupCard), findsNWidgets(expected));

    await tester.enterText(find.byType(TextField), 'aee cbcp');
    await tester.pumpAndSettle();
    expect(find.byType(GroupCard), findsOneWidget);
    expect(find.text('2 sets · 10 questions'), findsOneWidget);
    await tester.tap(find.byType(GroupCard));
    await tester.pump();
    await _settle(tester, until: () => find.byType(PaperCard).evaluate().length >= 2);
    expect(find.byType(PaperCard), findsNWidgets(2));
    expect(find.text('SET 01'), findsOneWidget);
    expect(find.text('SET 02'), findsOneWidget);
    expect(find.text('Up to 3 attempts'), findsWidgets);
    expect(find.text('Exam sets'), findsOneWidget);
  });

  liveWidgetTest(
    'Redeem on a set spends the quote\'s credits and opens it for good, as the API reads it back (Pooja; cannot be undone)',
    (tester) async {
      final api = (await tester.runAsync(() => _as(pooja)))!;
      final unlocks = (await tester.runAsync(() => _json(api, '/learning/me/paper-unlocks')))!;
      final held = (unlocks['paperIds'] as List).cast<String>().toSet();
      final credits = unlocks['icrCredits'] as int;
      final topics = (await tester.runAsync(() => _rows(api, '/learning/topics')))!;

      // The last set Pooja does not hold and can afford, so earlier runs and other tests are left their own.
      Map<String, dynamic>? topic;
      Map<String, dynamic>? set;
      int? cost;
      for (final t in topics.reversed) {
        for (final p in (t['papers'] as List).cast<Map<String, dynamic>>().reversed) {
          if (held.contains(p['id'])) continue;
          final quote = await tester.runAsync(() => _json(api, '/learning/papers/${p['slug']}/quote'));
          final c = quote!['credits'] as int?;
          if (quote['alreadyOpen'] == true || c == null || c > credits) continue;
          topic = t;
          set = p;
          cost = c;
          break;
        }
        if (set != null) break;
      }
      if (set == null) {
        markTestSkipped('Pooja holds every set she can afford: each run of this test opens one for good');
        return;
      }

      await _pumpScreen(
        tester,
        MockTestsScreen(
          onBack: () {},
          repository: _Bare(ApiAssessRepository(api: _screenClient(api))),
          opener: RecordingOpener().call,
          launcher: RecordingLauncher().call,
        ),
      );
      await _settle(tester, until: () => find.byType(GroupCard).evaluate().isNotEmpty);
      await tester.enterText(find.byType(TextField), topic!['title'] as String);
      await tester.pumpAndSettle();
      // Another subject's name may contain this one's: open the subject itself.
      final topicId = topic['id'] as String;
      await tester.tap(find.byWidgetPredicate((w) => w is GroupCard && w.group.id == topicId));
      await tester.pump();
      final id = set['id'] as String;
      final redeem = find.descendant(
        of: _card(id),
        matching: find.widgetWithText(ActionButton, 'Redeem ${creditsLabel(cost!)}'),
      );
      // The card shows at once; its price (and the button) when the quote arrives.
      await _settle(tester, until: () => redeem.evaluate().isNotEmpty);
      expect(redeem, findsOneWidget, reason: 'the quote says ${creditsLabel(cost)}');
      await tester.ensureVisible(redeem);
      await tester.pumpAndSettle();
      await tester.tap(redeem);
      await tester.pumpAndSettle();
      expect(find.text('This set opens for good. You will have ${creditsLabel(credits - cost)} left.'), findsOneWidget);
      await _tapOnline(tester, find.widgetWithText(ActionButton, 'Redeem ${creditsShort(cost)}'));
      await _settle(
        tester,
        until: () => find.descendant(of: _card(id), matching: find.text('Unlocked')).evaluate().isNotEmpty,
      );
      expect(find.descendant(of: _card(id), matching: find.text('Unlocked')), findsOneWidget);
      expect(find.descendant(of: _card(id), matching: find.text('Opened with ICR credits')), findsOneWidget);
      expect(find.textContaining('You enrolled into this mock exam'), findsWidgets);

      // The API agrees: the set is Pooja's for good, the credits are gone, and a second redemption costs nothing.
      final after = (await tester.runAsync(() => _json(api, '/learning/me/paper-unlocks')))!;
      expect((after['paperIds'] as List), contains(id));
      expect((after['creditPaperIds'] as List), contains(id));
      expect(after['icrCredits'], credits - cost);
      final quote = (await tester.runAsync(() => _json(api, '/learning/papers/${set!['slug']}/quote')))!;
      expect(quote['alreadyOpen'], isTrue);
      final again = (await tester.runAsync(
        () => ApiAssessRepository(
          api: api,
        ).redeem(AssessPaper(id: id, slug: set!['slug'] as String, title: 'Set', kind: PaperKind.mock)),
      ))!;
      expect(again.spent, 0);
      expect(again.credits, credits - cost);
      // Drain anything the screen still has in flight before the test ends.
      await _settle(tester, until: () => true);
    },
  );
}
