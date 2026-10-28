import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/features/account/saved/saved_items_screen.dart';
import 'package:icr_mobile/features/account/saved/saved_models.dart';
import 'package:icr_mobile/features/account/saved/saved_repository.dart';
import 'package:icr_mobile/features/account/saved/widgets/saved_cards.dart';

import 'helpers/account_harness.dart';
import 'helpers/fonts.dart';

/// "Saved Items & Jobs": every kind's mapping from an answer shaped like the
/// real API's (captured from the local portal on 26 Oct 2026), every state of
/// every kind, the un-save with its rollback and Undo, the chips, the
/// callbacks, paging, pull to refresh and a small phone.
void main() {
  setUpAll(loadAppFonts);

  // --- answers shaped like the real API's ---------------------------------------------------------------------

  /// `GET /jobs/saved`: the public job card plus `savedAt` (decimals arrive as strings).
  Map<String, dynamic> jobRow({
    String id = 'job1',
    String title = 'Senior Facility Manager',
    String companyName = 'Acme Facilities',
    String? city = 'Mumbai',
    String status = 'OPEN',
    Object? salaryMin = '1000000',
    Object? salaryMax = '1500000',
    bool salaryVisible = true,
  }) => {
    'id': id,
    'title': title,
    'description': '<p>We are hiring</p>',
    'location': null,
    'city': city,
    'cities': <String>[],
    'state': null,
    'country': 'India',
    'status': status,
    'companyId': 'co1',
    'salaryMin': salaryMin,
    'salaryMax': salaryMax,
    'salaryCurrency': 'INR',
    'salaryPeriod': 'YEARLY',
    'salaryVisible': salaryVisible,
    'employmentType': 'FULL_TIME',
    'workMode': 'ONSITE',
    'skills': ['HVAC'],
    'createdAt': '2026-10-19T12:43:36.311Z',
    'publishedAt': '2026-10-19T12:43:36.311Z',
    'company': {
      'id': 'co1',
      'name': companyName,
      'logoUrl': null,
      'city': 'Bengaluru',
      'ratingAvg': null,
      'ratingCount': 0,
    },
    'branch': {'id': 'b1', 'name': 'Head Office', 'city': 'Bengaluru'},
    'savedAt': '2026-10-19T12:43:47.541Z',
  };

  /// A job that is no longer open: the API sends only that, and whose it was.
  Map<String, dynamic> stubRow({String id = 'gone1'}) => {
    'id': id,
    'status': 'CLOSED',
    'company': {'id': 'co9', 'name': 'Old Employer', 'logoUrl': null},
    'savedAt': '2026-10-01T09:00:00.000Z',
  };

  /// `GET /mentorship/mentors/saved`: a mentor card (no `savedAt`).
  Map<String, dynamic> mentorRow({String id = 'mp1', String first = 'Rajesh', String last = 'Sharma'}) => {
    'id': id,
    'user': {'id': 'u-$id', 'firstName': first, 'lastName': last, 'avatarUrl': null, 'title': null, 'company': null},
    'coverImage': null,
    'headline': 'VP Facility Ops @ Infosys',
    'yearsExperience': 14,
    'competencies': ['Smart Campuses', 'Smart Campuses', 'BMS', 'Operations & FM', 'Sustainability & ESG'],
    'planFromPaisa': 799900,
    'city': null,
    'rating': 4.8,
    'ratingCount': 12,
    'isTopMentor': true,
    'featured': false,
    'status': 'APPROVED',
    'createdAt': '2026-10-23T03:33:38.390Z',
    'career': {
      'currentRole': {'title': 'VP Facility Ops', 'organisation': 'Infosys'},
      'topQualification': null,
    },
  };

  /// `GET /vendors/saved`: a `GET /vendors` row plus `savedAt`.
  Map<String, dynamic> supplierRow({String id = 'v1', String name = 'Delhi Services 114'}) => {
    'id': id,
    'companyId': 'co-$id',
    'headline': '$name — trusted supplier',
    'categories': ['PEST_CONTROL'],
    'serviceAreas': ['Delhi'],
    'rating': 4.4,
    'ratingCount': 28,
    'isPremium': true,
    'verificationLevel': 'ELITE',
    'company': {
      'id': 'co-$id',
      'name': name,
      'logoUrl': null,
      'city': 'Delhi',
      'state': 'Delhi',
      'verificationLevel': 'ELITE',
      'ratingAvg': null,
      'ratingCount': 0,
      'gstRegistered': true,
      'panOnRecord': true,
    },
    'savedAt': '2026-10-26T07:27:22.572Z',
  };

  /// `GET /councils/saves/mine` answers a bare list of these.
  Map<String, dynamic> councilRow({
    String id = 'c1',
    String name = 'Sustainability Council',
    String slug = 'sustainability',
  }) => {
    'councilId': id,
    'savedAt': '2026-10-26T07:27:22.650Z',
    'council': {'id': id, 'name': name, 'slug': slug, 'memberCount': 4, 'upcomingEventCount': 2},
  };

  /// `GET /forum/saves/mine`: a thread card.
  Map<String, dynamic> threadRow({String id = 't1', String title = 'Implementing IoT sensors for HVAC efficiency'}) => {
    'id': id,
    'slug': 'slug-$id',
    'title': title,
    'excerpt': 'We are looking to retrofit a 15-year-old building with modern IoT sensors.',
    'kind': 'QUESTION',
    'status': 'OPEN',
    'pinned': false,
    'tags': ['HVAC'],
    'category': {'id': 'cat1', 'key': 'ESG', 'name': 'ESG & Sustainability', 'slug': 'esg', 'icon': 'Grass'},
    'subcategory': null,
    'author': {
      'id': 'a1',
      'firstName': 'Sarah',
      'lastName': 'Jenkins',
      'avatarUrl': null,
      'headline': 'Senior Facilities Manager',
      'reputation': 0,
    },
    'replyCount': 52,
    'viewCount': 4210,
    'score': 184,
    'likes': 184,
    'hasAcceptedAnswer': false,
    'lastActivityAt': '2026-10-24T12:38:36.050Z',
    'createdAt': '2026-10-23T10:36:36.050Z',
    'saved': true,
  };

  Map<String, dynamic> pageJson(List<Map<String, dynamic>> all, ApiCall call) {
    final page = int.parse('${call.query['page'] ?? 1}');
    final limit = int.parse('${call.query['limit'] ?? 20}');
    final totalPages = (all.length / limit).ceil().clamp(1, 1 << 30);
    final from = (page - 1) * limit;
    return {
      'data': all.skip(from).take(limit).toList(),
      'meta': {
        'page': page,
        'limit': limit,
        'total': all.length,
        'totalPages': totalPages,
        'hasNext': page < totalPages,
        'hasPrev': page > 1,
      },
    };
  }

  /// A stand-in API holding the lists given; each can be replaced by a handler.
  AccountHarness harness({
    List<Map<String, dynamic>>? jobs,
    List<Map<String, dynamic>>? mentors,
    List<Map<String, dynamic>>? suppliers,
    List<Map<String, dynamic>>? councils,
    List<Map<String, dynamic>>? threads,
    Map<String, ApiHandler> routes = const {},
  }) {
    final j = jobs ?? [jobRow()];
    final m = mentors ?? [mentorRow()];
    final s = suppliers ?? [supplierRow()];
    final c = councils ?? [councilRow()];
    final t = threads ?? [threadRow()];
    return AccountHarness(
      routes: {
        'GET /jobs/saved': (call) => pageJson(j, call),
        'GET /mentorship/mentors/saved': (call) => pageJson(m, call),
        'GET /vendors/saved': (call) => pageJson(s, call),
        'GET /councils/saves/mine': (_) => c,
        'GET /forum/saves/mine': (call) => pageJson(t, call),
        // The saves and un-saves answer as the real API does.
        'POST /jobs/job1/save': (_) => {'saved': true},
        'DELETE /jobs/job1/save': (_) => {'saved': false},
        'DELETE /mentorship/mentors/mp1/save': (_) => {'status': 'NONE'},
        'POST /mentorship/mentors/mp1/save': (_) => {'status': 'SAVED'},
        'DELETE /vendors/v1/save': (_) => {'status': 'NONE'},
        'POST /vendors/v1/save': (_) => {'status': 'SAVED'},
        'DELETE /councils/c1/save': (_) => {'status': 'NONE'},
        'POST /councils/c1/save': (_) => {'status': 'SAVED'},
        'DELETE /forum/threads/t1/save': (_) => {'saved': false},
        'POST /forum/threads/t1/save': (_) => {'saved': true},
        ...routes,
      },
    );
  }

  Future<void> pump(
    WidgetTester tester,
    AccountHarness h, {
    double width = 390,
    double height = 844,
    SavedKind initial = SavedKind.jobs,
    List<Uri>? opened,
    void Function(String)? onOpenJob,
    void Function(String)? onOpenMentor,
    void Function(String)? onOpenSupplier,
    void Function(String)? onOpenCouncil,
    void Function(String)? onOpenThread,
    void Function(String)? onOpenCompany,
    void Function(SavedKind)? onBrowse,
    VoidCallback? onBack,
    VoidCallback? onBell,
    bool settle = true,
  }) async {
    usePhone(tester, width: width, height: height);
    await tester.pumpWidget(
      h.app(
        SavedItemsScreen(
          initialKind: initial,
          onBack: onBack,
          onBell: onBell,
          onOpenJob: onOpenJob,
          onOpenMentor: onOpenMentor,
          onOpenSupplier: onOpenSupplier,
          onOpenCouncil: onOpenCouncil,
          onOpenThread: onOpenThread,
          onOpenCompany: onOpenCompany,
          onBrowse: onBrowse,
          opener: (context, uri) async => opened?.add(uri),
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final target = find.byKey(ValueKey(key));
    await tester.ensureVisible(target);
    await tester.pump();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> tab(WidgetTester tester, SavedKind kind) => tapKey(tester, 'saved.tab.${kind.name}');

  ApiHandler fail(int status, String message) =>
      (_) => ApiReply.refusal(status, message);

  // --- the mapping --------------------------------------------------------------------------------------------

  group('the mapping, from answers shaped like the real API', () {
    ApiSavedRepository repo(AccountHarness h) => ApiSavedRepository(api: h.client);

    test('a saved job is the job card with its salary, place and when it was saved', () async {
      final h = harness();
      final page = await repo(h).load(SavedKind.jobs);
      final job = page.items.single as SavedJob;

      expect(job.id, 'job1');
      expect(job.title, 'Senior Facility Manager');
      expect(job.companyName, 'Acme Facilities');
      expect(job.companyId, 'co1');
      expect(job.place, 'Mumbai, India');
      expect(job.facts, 'Mumbai, India • On-site • Full-time');
      // The API sends a decimal column as a string.
      expect(job.salary, '₹10L - ₹15L / yr');
      expect(job.savedAt, DateTime.parse('2026-10-19T12:43:47.541Z'));
      expect(job.postedAt, DateTime.parse('2026-10-19T12:43:36.311Z'));
      expect(job.closed, isFalse);
      expect(page.total, 1);
      expect(page.hasNext, isFalse);
      expect(h.api.last('GET /jobs/saved').query, {'page': 1, 'limit': 20});
    });

    test('a job with no city of its own takes its company\'s, and a hidden salary is not shown', () async {
      final row = jobRow(city: null, salaryVisible: false);
      final job = SavedJob.fromJson(row);
      expect(job.place, 'Bengaluru, India');
      expect(job.salary, isNull);
      expect(SavedJob.fromJson(jobRow(salaryMin: null, salaryMax: null)).salary, isNull);
      expect(
        SavedJob.fromJson({...jobRow(), 'salaryMin': 85000, 'salaryMax': null, 'salaryPeriod': 'MONTHLY'}).salary,
        '₹85K / mo',
      );
      expect(
        SavedJob.fromJson({...jobRow(), 'salaryCurrency': 'USD', 'salaryMin': 120000, 'salaryMax': 150000}).salary,
        'USD 120K - USD 150K / yr',
      );
    });

    test('a job that is no longer open arrives as a stub: closed, with no title of its own', () async {
      final job = SavedJob.fromJson(stubRow());
      expect(job.closed, isTrue);
      expect(job.jobTitle, isNull);
      expect(job.title, 'A role at Old Employer');
      expect(job.companyId, 'co9');
      expect(job.salary, isNull);
      expect(job.facts, isEmpty);
      // A job the API still sends whole but that is paused is closed to the member too.
      expect(SavedJob.fromJson(jobRow(status: 'PAUSED')).closed, isTrue);
    });

    test('a saved mentor is the mentor card: name, role, competencies once each, rating and price', () async {
      final page = await repo(harness()).load(SavedKind.mentors);
      final m = page.items.single as SavedMentor;

      expect(m.id, 'mp1');
      expect(m.name, 'Rajesh Sharma');
      expect(m.userId, 'u-mp1');
      expect(m.roleLine, 'VP Facility Ops @ Infosys');
      expect(m.expertise, ['Smart Campuses', 'BMS', 'Operations & FM', 'Sustainability & ESG']);
      expect(m.rating, 4.8);
      expect(m.ratingCount, 12);
      expect(m.topMentor, isTrue);
      expect(m.approved, isTrue);
      expect(m.planFromPaisa, 799900);
      // The mentors' list does not say when a mentor was saved.
      expect(m.savedAt, isNull);
      expect(m.initials, 'RS');
    });

    test('a mentor with no current role reads the headline instead', () {
      final row = mentorRow()..['career'] = {'currentRole': null, 'topQualification': null};
      expect(SavedMentor.fromJson(row).roleLine, 'VP Facility Ops @ Infosys');
      final bare = {...row, 'headline': null};
      expect(SavedMentor.fromJson(bare).roleLine, '');
    });

    test('a saved supplier is the listing row: its own id, the company page, level, rating and place', () async {
      final page = await repo(harness()).load(SavedKind.suppliers);
      final s = page.items.single as SavedSupplier;

      expect(s.id, 'v1', reason: 'the listing id, which the save endpoints take');
      expect(s.companyId, 'co-v1');
      expect(s.name, 'Delhi Services 114');
      expect(s.headline, 'Delhi Services 114 — trusted supplier');
      expect(s.level, 'Elite');
      expect(s.rating, 4.4);
      expect(s.ratingCount, 28);
      expect(s.premium, isTrue);
      expect(s.gstRegistered, isTrue);
      expect(s.place, 'Delhi, Delhi');
      expect(s.savedAt, isNotNull);
      expect(SavedSupplier.fromJson({...supplierRow(), 'verificationLevel': 'REGISTERED'}).level, isNull);
    });

    test('saved councils are a bare list, keyed by the council\'s id, with the slug for its page', () async {
      final h = harness(
        councils: [
          councilRow(),
          councilRow(id: 'c2', name: 'Legal Council', slug: 'legal'),
        ],
      );
      final page = await repo(h).load(SavedKind.councils);

      expect(page.items.map((i) => i.id), ['c1', 'c2']);
      final c = page.items.first as SavedCouncil;
      expect(c.name, 'Sustainability Council');
      expect(c.slug, 'sustainability');
      expect(c.memberCount, 4);
      expect(c.upcomingEventCount, 2);
      expect(page.total, 2, reason: 'a bare list has no meta: the total is its length');
      expect(page.hasNext, isFalse);
      expect(h.api.last('GET /councils/saves/mine').query, isEmpty, reason: 'the API does not page councils');
    });

    test('a saved discussion is the thread card: slug, excerpt, kind, topic, author and counts', () async {
      final page = await repo(harness()).load(SavedKind.discussions);
      final t = page.items.single as SavedThread;

      expect(t.id, 't1');
      expect(t.slug, 'slug-t1');
      expect(t.title, 'Implementing IoT sensors for HVAC efficiency');
      expect(t.excerpt, startsWith('We are looking to retrofit'));
      expect(t.kindLabel, 'Question');
      expect(t.topic, 'ESG & Sustainability');
      expect(t.authorName, 'Sarah Jenkins');
      expect(t.authorInitials, 'SJ');
      expect(t.replyCount, 52);
      expect(t.likes, 184);
      expect(t.answered, isFalse);
      expect(t.savedAt, isNull);
      expect(SavedThread.fromJson({...threadRow(), 'kind': 'DISCUSSION'}).kindLabel, isNull);
    });

    test('a page carries the member\'s total and whether another follows, and the paging query', () async {
      final h = harness(jobs: [for (var i = 0; i < 45; i++) jobRow(id: 'j$i')]);
      final first = await repo(h).load(SavedKind.jobs);
      expect(first.items, hasLength(20));
      expect(first.total, 45);
      expect(first.hasNext, isTrue);

      final last = await repo(h).load(SavedKind.jobs, page: 3);
      expect(last.items, hasLength(5));
      expect(last.hasNext, isFalse);
      expect(h.api.last('GET /jobs/saved').query, {'page': 3, 'limit': 20});
    });

    test('a row with no id is dropped, for it could not be un-saved', () async {
      final h = harness(
        jobs: [
          jobRow(),
          {...jobRow(), 'id': null},
        ],
      );
      final page = await repo(h).load(SavedKind.jobs);
      expect(page.items, hasLength(1));
    });

    test('each kind reads its own endpoint and saves and un-saves on its own', () async {
      final h = harness();
      final r = repo(h);
      for (final kind in SavedKind.values) {
        final page = await r.load(kind);
        final item = page.items.single;
        await r.unsave(item);
        await r.save(item);
      }
      expect(h.api.calls.map((c) => c.key), [
        'GET /jobs/saved',
        'DELETE /jobs/job1/save',
        'POST /jobs/job1/save',
        'GET /mentorship/mentors/saved',
        'DELETE /mentorship/mentors/mp1/save',
        'POST /mentorship/mentors/mp1/save',
        'GET /vendors/saved',
        'DELETE /vendors/v1/save',
        'POST /vendors/v1/save',
        'GET /councils/saves/mine',
        'DELETE /councils/c1/save',
        'POST /councils/c1/save',
        'GET /forum/saves/mine',
        'DELETE /forum/threads/t1/save',
        'POST /forum/threads/t1/save',
      ]);
    });

    test('a refusal arrives as the API\'s own sentence, with its status', () async {
      final h = harness(routes: {'GET /jobs/saved': fail(403, 'You do not have permission.')});
      await expectLater(
        repo(h).load(SavedKind.jobs),
        throwsA(
          isA<ApiError>()
              .having((e) => e.message, 'message', 'You do not have permission.')
              .having((e) => e.statusCode, 'status', 403),
        ),
      );
    });

    test('rupees from paise use lakh grouping, as an Indian price reads', () {
      expect(rupeesFromPaise(799900), '₹7,999');
      expect(rupeesFromPaise(250000), '₹2,500');
      expect(rupeesFromPaise(12345600), '₹1,23,456');
      expect(rupeesFromPaise(50000), '₹500');
    });
  });

  // --- the screen ---------------------------------------------------------------------------------------------

  group('the screen: chips, cards and every state', () {
    testWidgets('loading shows a spinner for the kind while the API has not answered', (tester) async {
      final h = harness();
      h.api.gate = Completer<void>();
      await pump(tester, h, settle: false);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Saved items'), findsOneWidget);
      // Chips are drawn at once, without counts.
      expect(find.text('Jobs'), findsOneWidget);
      expect(find.text('Jobs (1)'), findsNothing);

      h.api.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Jobs (1)'), findsOneWidget);
    });

    testWidgets('every kind is read once on opening, and each chip shows its count', (tester) async {
      final h = harness(
        jobs: [
          jobRow(),
          jobRow(id: 'job2'),
        ],
        councils: [
          councilRow(),
          councilRow(id: 'c2', slug: 'b'),
          councilRow(id: 'c3', slug: 'c'),
        ],
      );
      await pump(tester, h);

      expect(find.text('Jobs (2)'), findsOneWidget);
      expect(find.text('Mentors (1)'), findsOneWidget);
      expect(find.text('Suppliers (1)'), findsOneWidget);
      expect(find.text('Councils (3)'), findsOneWidget);
      expect(find.text('Discussions (1)'), findsOneWidget);
      for (final key in [
        'GET /jobs/saved',
        'GET /mentorship/mentors/saved',
        'GET /vendors/saved',
        'GET /councils/saves/mine',
        'GET /forum/saves/mine',
      ]) {
        expect(h.api.count(key), 1, reason: key);
      }
      expect(find.byKey(const ValueKey('saved.count.jobs')), findsOneWidget);
      expect(find.text('2 saved jobs'), findsOneWidget);
    });

    testWidgets('it opens on the chip asked for', (tester) async {
      await pump(tester, harness(), initial: SavedKind.suppliers);
      expect(find.byKey(const ValueKey('saved.card.supplier.v1')), findsOneWidget);
      expect(find.byKey(const ValueKey('saved.card.job.job1')), findsNothing);
    });

    testWidgets('the job card shows title, company, place, work mode, salary and when it was saved', (tester) async {
      await pump(tester, harness());

      expect(find.text('Senior Facility Manager'), findsOneWidget);
      expect(find.text('Acme Facilities'), findsOneWidget);
      expect(find.text('Mumbai, India • On-site • Full-time'), findsOneWidget);
      expect(find.textContaining('₹10L - ₹15L / yr'), findsOneWidget);
      expect(find.textContaining('Saved '), findsWidgets);
      expect(find.byKey(const ValueKey('saved.unsave.jobs.job1')), findsOneWidget);
    });

    testWidgets('a job that closed says so, and does not look like a posting', (tester) async {
      await pump(tester, harness(jobs: [stubRow()]));

      expect(find.text('No longer open'), findsOneWidget);
      expect(find.text('A role at Old Employer'), findsOneWidget);
      expect(find.textContaining('This job has closed'), findsOneWidget);
    });

    testWidgets('the mentor card shows the name, the seal, the role, rating, price and three competencies', (
      tester,
    ) async {
      await pump(tester, harness(), initial: SavedKind.mentors);

      expect(find.text('Rajesh Sharma'), findsOneWidget);
      expect(find.text('VP Facility Ops @ Infosys'), findsOneWidget);
      expect(find.text('4.8 (12)'), findsOneWidget);
      expect(find.text('Top mentor'), findsOneWidget);
      expect(find.text('From ₹7,999/mo'), findsOneWidget);
      expect(find.text('Smart Campuses'), findsOneWidget);
      expect(find.text('BMS'), findsOneWidget);
      expect(find.text('Operations & FM'), findsOneWidget);
      expect(find.text('Sustainability & ESG'), findsNothing, reason: 'three at most');
    });

    testWidgets('the supplier card shows the name, pitch, level, rating, place and GST', (tester) async {
      await pump(tester, harness(), initial: SavedKind.suppliers);

      expect(find.text('Delhi Services 114'), findsOneWidget);
      expect(find.text('Delhi Services 114 — trusted supplier'), findsOneWidget);
      expect(find.text('Elite'), findsOneWidget);
      expect(find.text('Premium'), findsOneWidget);
      expect(find.text('4.4 (28)'), findsOneWidget);
      expect(find.text('Delhi, Delhi'), findsOneWidget);
      expect(find.textContaining('GST registered'), findsOneWidget);
    });

    testWidgets('the council card shows the name, members and upcoming events', (tester) async {
      await pump(tester, harness(), initial: SavedKind.councils);

      expect(find.text('Sustainability Council'), findsOneWidget);
      expect(find.textContaining('4 members · 2 upcoming events'), findsOneWidget);
    });

    testWidgets('the discussion card shows the kind, topic, title, excerpt, author, replies and likes', (tester) async {
      await pump(tester, harness(), initial: SavedKind.discussions);

      expect(find.text('Question'), findsOneWidget);
      expect(find.text('ESG & Sustainability'), findsOneWidget);
      expect(find.text('Implementing IoT sensors for HVAC efficiency'), findsOneWidget);
      expect(find.textContaining('retrofit a 15-year-old building'), findsOneWidget);
      expect(find.textContaining('Sarah Jenkins'), findsOneWidget);
      expect(find.textContaining('52 replies · 184 likes'), findsOneWidget);
    });

    testWidgets('chips switch the list, and the one on is filled', (tester) async {
      final h = harness();
      await pump(tester, h);
      expect(find.byKey(const ValueKey('saved.card.job.job1')), findsOneWidget);

      await tab(tester, SavedKind.mentors);
      expect(find.byKey(const ValueKey('saved.card.job.job1')), findsNothing);
      expect(find.byKey(const ValueKey('saved.card.mentor.mp1')), findsOneWidget);
      expect(find.text('1 saved mentor'), findsOneWidget);

      await tab(tester, SavedKind.discussions);
      expect(find.byKey(const ValueKey('saved.card.thread.t1')), findsOneWidget);

      await tab(tester, SavedKind.jobs);
      expect(find.byKey(const ValueKey('saved.card.job.job1')), findsOneWidget);

      // The chip that is on is blue; the others are white with a border.
      Color? fill(SavedKind k) {
        final material = tester.widget<Material>(
          find.descendant(of: find.byKey(ValueKey('saved.tab.${k.name}')), matching: find.byType(Material)).first,
        );
        return material.color;
      }

      expect(fill(SavedKind.jobs), const Color(0xFF1D63A3));
      expect(fill(SavedKind.mentors), Colors.white);
      // Switching chips reads nothing again.
      expect(h.api.count('GET /mentorship/mentors/saved'), 1);
    });
  });
}
