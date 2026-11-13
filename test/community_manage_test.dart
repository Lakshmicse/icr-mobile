import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/features/account/widgets/account_kit.dart' show EditSheet;
import 'package:icr_mobile/features/community_manage/community_manage_kit.dart';
import 'package:icr_mobile/features/community_manage/community_manage_memory_repository.dart';
import 'package:icr_mobile/features/community_manage/community_manage_models.dart';
import 'package:icr_mobile/features/community_manage/community_manage_repository.dart';
import 'package:icr_mobile/features/community_manage/community_manage_rules.dart';
import 'package:icr_mobile/features/community_manage/manage_chapter_screen.dart';
import 'package:icr_mobile/features/community_manage/manage_chapters_screen.dart';
import 'package:icr_mobile/features/community_manage/manage_council_screen.dart';
import 'package:icr_mobile/features/community_manage/manage_councils_screen.dart';
import 'package:icr_mobile/features/workspaces/page_kit.dart' show WsColors;

import 'helpers/account_harness.dart';
import 'helpers/fonts.dart';

/// The phone's pickers, answering what a test set.
class FakePickers extends ManagePickers {
  FakePickers({this.image, this.day});

  UploadFile? image;
  DateTime? day;
  int imagePicks = 0;

  @override
  Future<UploadFile?> pickImage({int maxBytes = ManageLimits.coverBytes}) async {
    imagePicks += 1;
    return image;
  }

  @override
  Future<DateTime?> pickDay(BuildContext context, {required DateTime initial, String? help}) async => day;
}

UploadFile png(String name, {int bytes = 8}) =>
    UploadFile(name: name, bytes: Uint8List(bytes), mimeType: 'image/png');

const _fast = Duration(milliseconds: 10);

/// Manage Chapters and Manage Councils (the website's `/admin/community`), native since 13 Nov 2026: the staff
/// lists and their search, the record's manage page with every content section, the forms held to the API's rules,
/// members' applications and proposals, and what a role over only some records is not offered.
void main() {
  setUpAll(loadAppFonts);

  late AccountHarness h;
  late MemoryCommunityManageRepository repo;
  var backs = 0;

  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpAndSettle();
  }

  /// Lets a "saved" message leave, so it does not sit over what is tapped next.
  Future<void> clearMessage(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  Future<void> pump(WidgetTester tester, Widget screen, {double width = 390}) async {
    h = AccountHarness();
    await h.signIn(tester, userJson(role: 'SUPER_ADMIN'));
    usePhone(tester, width: width);
    backs = 0;
    await tester.pumpWidget(h.app(screen));
    await settle(tester);
  }

  Future<void> pumpChapters(
    WidgetTester tester, {
    bool everywhere = true,
    MemoryCommunityManageRepository? repository,
    FakePickers? pickers,
    String? initialTab,
    String? initialSearch,
    String? focusApplicationId,
    Widget Function(Widget page)? pageWrap,
    double width = 390,
  }) async {
    repo = repository ?? MemoryCommunityManageRepository();
    await pump(
      tester,
      ManageChaptersScreen(
        repository: repo,
        everywhere: everywhere,
        onBack: () => backs += 1,
        onBell: () {},
        initialTab: initialTab,
        initialSearch: initialSearch,
        focusApplicationId: focusApplicationId,
        pageWrap: pageWrap,
        pickers: pickers ?? FakePickers(),
        searchDelay: _fast,
      ),
      width: width,
    );
  }

  Future<void> pumpCouncils(
    WidgetTester tester, {
    bool everywhere = true,
    MemoryCommunityManageRepository? repository,
    String? initialTab,
    String? focusProposalId,
  }) async {
    repo = repository ?? MemoryCommunityManageRepository();
    await pump(
      tester,
      ManageCouncilsScreen(
        repository: repo,
        everywhere: everywhere,
        onBack: () => backs += 1,
        onBell: () {},
        initialTab: initialTab,
        focusProposalId: focusProposalId,
        pickers: FakePickers(),
        searchDelay: _fast,
      ),
    );
  }

  Future<void> pumpChapter(
    WidgetTester tester, {
    String id = 'ch-blr',
    bool everywhere = true,
    MemoryCommunityManageRepository? repository,
    FakePickers? pickers,
    double width = 390,
  }) async {
    repo = repository ?? MemoryCommunityManageRepository();
    await pump(
      tester,
      ManageChapterScreen(
        repository: repo,
        chapterId: id,
        everywhere: everywhere,
        onBack: () => backs += 1,
        onBell: () {},
        pickers: pickers ?? FakePickers(),
        searchDelay: _fast,
        now: () => DateTime(2026, 11, 13),
      ),
      width: width,
    );
  }

  Future<void> pumpCouncil(WidgetTester tester, {String id = 'co-health', bool everywhere = true}) async {
    repo = MemoryCommunityManageRepository();
    await pump(
      tester,
      ManageCouncilScreen(
        repository: repo,
        councilId: id,
        everywhere: everywhere,
        onBack: () => backs += 1,
        onBell: () {},
        pickers: FakePickers(),
        now: () => DateTime(2026, 11, 13),
      ),
    );
  }

  /// Scrolls the page until [finder] is built and on screen.
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 160, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  /// Back to the top of the page (a later look-up scrolls down from there).
  Future<void> toTop(WidgetTester tester) async {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 4000));
    await settle(tester);
  }

  /// Something with these words inside the open sheet (the page under it may say the same).
  Finder inSheet(String text) => find.descendant(of: find.byType(EditSheet), matching: find.text(text));

  Future<void> tapOnPage(WidgetTester tester, Finder finder) async {
    await reveal(tester, finder);
    await tester.tap(finder);
    await settle(tester);
  }

  Future<void> tapInSheet(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await settle(tester);
  }

  Future<void> type(WidgetTester tester, String key, String text) async {
    final field = find.byKey(Key(key));
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.enterText(field, text);
    await settle(tester);
  }

  Future<void> save(WidgetTester tester) => tapInSheet(tester, find.byKey(const Key('sheet.save')));

  Future<void> confirm(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('confirm.ok')));
    await settle(tester);
  }

  /// Opens a select field (its own tap target, not its clear button).
  Future<void> openSelect(WidgetTester tester, String key) async {
    final field = find.descendant(of: find.byKey(Key(key)), matching: find.byType(InkWell)).first;
    await tapInSheet(tester, field);
  }

  String sheetError(WidgetTester tester) => tester
      .widget<Text>(find.descendant(of: find.byKey(const Key('sheet.error')), matching: find.byType(Text)))
      .data!;

  Map<String, Object?> lastBody() => repo.sent.last['body']! as Map<String, Object?>;

  group('rules', () {
    test('a chapter draft refuses what CreateChapterDto refuses', () {
      expect(ChapterDraft().problems(), {
        'name': 'Give the chapter a name.',
        'city': 'Choose the city this regional chapter covers.',
      });
      expect(ChapterDraft(name: 'UAE', scope: ChapterScope.country, country: '').problems(), {
        'country': 'Choose the country this chapter covers.',
      });
      final bad = ChapterDraft(name: 'Pune Chapter', city: 'Pune', foundedYear: '1899', contactEmail: 'not-an-email');
      expect(bad.problems(), {
        'foundedYear': 'The founded year must be 1900 or later.',
        'contactEmail': 'Enter a valid email address.',
      });
      expect(ChapterDraft(name: 'Pune Chapter', city: 'Pune', foundedYear: 'MMXX').problems().keys, ['foundedYear']);
      expect(ChapterDraft(name: 'x' * 121, city: 'Pune').problems().keys, ['name']);
      expect(ChapterDraft(name: 'Pune Chapter', city: 'Pune', description: 'd' * 4001).problems().keys, [
        'description',
      ]);
      expect(ChapterDraft(name: 'Pune Chapter', city: 'Pune', foundedYear: '2020').problems(), isEmpty);
    });

    test("a chapter's body is the website's: no slug, the About always sent, a cleared field sent as null", () {
      final created = ChapterDraft(name: ' Pune Chapter ', city: 'Pune', region: 'Maharashtra', foundedYear: '2021');
      created.about = {'mission': 'Bring Pune together.', 'activities': 'Meetups\n- Site visits'};
      expect(created.body(), {
        'name': 'Pune Chapter',
        'scope': 'REGIONAL',
        'city': 'Pune',
        'country': 'India',
        'region': 'Maharashtra',
        'foundedYear': 2021,
        'galleryUrls': <String>[],
        'published': true,
        'aboutHtml':
            '<h3>Mission</h3>\n<p>Bring Pune together.</p>\n'
            '<h3>What we do</h3>\n<ul>\n<li>Meetups</li>\n<li>Site visits</li>\n</ul>',
      });

      const was = AdminChapter(
        id: 'c1',
        name: 'Pune Chapter',
        city: 'Pune',
        description: 'Old words',
        contactEmail: 'pune@icr.org.in',
        foundedYear: 2021,
        coverUrl: '/uploads/cover.png',
      );
      final edit = ChapterDraft.of(was)
        ..description = ''
        ..contactEmail = ''
        ..foundedYear = ''
        ..coverUrl = '';
      final body = edit.body(was: was);
      expect(body['description'], isNull);
      expect(body.containsKey('description'), isTrue);
      expect(body['contactEmail'], isNull);
      expect(body['foundedYear'], isNull);
      expect(body['coverUrl'], '', reason: 'an empty path removes the banner');
      expect(body.containsKey('logoUrl'), isFalse, reason: 'a picture is sent only when it changed');
      expect(body.containsKey('slug'), isFalse);

      final country = ChapterDraft(name: 'UAE Chapter', scope: ChapterScope.country, country: 'United Arab Emirates')
        ..city = 'Dubai'
        ..region = 'Dubai';
      expect(country.body()['city'], '');
      expect(country.body()['region'], isNull);
    });

    test('a council draft needs a name and a slug; the focus line defaults to the segments', () {
      expect(CouncilDraft().problems().keys, ['name', 'slug']);
      final d = CouncilDraft(name: 'Healthcare', slug: 'healthcare', segments: ['Hospitals', 'Pharma']);
      expect(d.problems(), isEmpty);
      expect(d.body()['focus'], 'Hospitals · Pharma');
      expect(CouncilDraft(name: 'A', slug: 'a', focus: 'f' * 161).problems().keys, ['focus']);
      expect(CouncilDraft(name: 'A', slug: 'a', contactEmail: 'x@').problems().keys, ['contactEmail']);
      expect(slugify('  Data Centre & Ops Council! '), 'data-centre-ops-council');
    });

    test('the About splits into its fields and builds back, keeping what no field covers', () {
      const html =
          '<p>An intro written before the fields existed.</p>'
          '<h3>Mission</h3><p>First.</p><p>Second &amp; last.</p>'
          '<h3>What we do</h3><ul><li>Meetups</li><li>Visits</li></ul>'
          '<h3>History</h3><p>Founded in 2019.</p>';
      final parsed = parseAbout(html, chapterAboutSections);
      expect(parsed.values['mission'], 'First.\n\nSecond & last.');
      expect(parsed.values['activities'], 'Meetups\nVisits');
      expect(parsed.values['vision'], '');
      expect(parsed.extra, contains('An intro written before the fields existed.'));
      expect(parsed.extra, contains('<h3>History</h3>'));
      final back = composeAbout(parsed.values, chapterAboutSections, parsed.extra);
      expect(back, startsWith('<h3>Mission</h3>\n<p>First.</p>\n<p>Second &amp; last.</p>'));
      expect(back, contains('<h3>What we do</h3>\n<ul>\n<li>Meetups</li>\n<li>Visits</li>\n</ul>'));
      expect(back, endsWith('<h3>History</h3><p>Founded in 2019.</p>'));
      expect(composeAbout({'mission': '  '}, chapterAboutSections), '');
    });

    test('content rules: required fields, limits, a term that ends before it starts, a decline without a reason', () {
      expect(sponsorProblem(name: ' ', tier: ''), 'Give the sponsor a name.');
      expect(sponsorProblem(name: 'Acme', tier: 't' * 41), isNotNull);
      expect(sponsorProblem(name: 'Acme', tier: 'Gold'), isNull);
      expect(resourceProblem(title: 'Report', url: '', sizeLabel: ''), 'Add the resource’s URL.');
      expect(resourceProblem(title: '', url: 'https://x', sizeLabel: ''), 'Give the resource a title.');
      expect(announcementProblem(title: 'Hello', body: ' '), 'Write the update.');
      expect(announcementProblem(title: 'Hello', body: 'b' * 4001), isNotNull);
      expect(
        leadProblem(termStartsOn: '2026-06-01', termEndsOn: '2026-05-31'),
        'A term can’t end before it starts.',
      );
      expect(leadProblem(termStartsOn: '2026-06-01', termEndsOn: ''), isNull);
      expect(leadProblem(title: 't' * 121), isNotNull);
      expect(decisionProblem(declining: true, reason: '  '), 'Say why it isn’t approved. The member reads this.');
      expect(decisionProblem(declining: false, reason: ''), isNull);
      expect(leadTermEnded('2026-11-12', '2026-11-13'), isTrue);
      expect(leadTermEnded('2026-11-13', '2026-11-13'), isFalse, reason: 'a term ending today is still in force');
      expect(leadTermEnded(null, '2026-11-13'), isFalse);
    });
  });

  group('the API repository', () {
    late ApiCommunityManageRepository api;

    AccountHarness harness(Map<String, ApiHandler> routes) {
      final harness = AccountHarness(routes: routes);
      api = ApiCommunityManageRepository(api: harness.client);
      return harness;
    }

    test('mayManage: 200 on the content read is yes; 403 and 404 are no', () async {
      harness({
        'GET /chapters/mine/content': (_) => {'sponsors': [], 'resources': [], 'announcements': [], 'leads': []},
        'GET /chapters/theirs/content': (_) => ApiReply.refusal(403, "Your role doesn't reach this record."),
        'GET /councils/mine/content': (_) => {'resources': [], 'announcements': [], 'leads': [], 'members': []},
        'GET /councils/theirs/content': (_) => ApiReply.refusal(403, 'Insufficient permissions'),
      });
      expect(await api.mayManageChapter('mine'), isTrue);
      expect(await api.mayManageChapter('theirs'), isFalse);
      expect(await api.mayManageChapter('gone'), isFalse, reason: 'no such chapter: 404');
      expect(await api.mayManageCouncil('mine'), isTrue);
      expect(await api.mayManageCouncil('theirs'), isFalse);
      expect(await api.mayManageCouncil('gone'), isFalse);
    });

    test('mayManage passes on a failure that is not an answer about the role', () async {
      harness({'GET /chapters/c1/content': (_) => ApiReply.refusal(500, 'Internal server error')});
      await expectLater(api.mayManageChapter('c1'), throwsA(isA<ApiError>()));
    });

    test('the lists ask by page of twenty with the search; one record is found in the staff list', () async {
      final h = harness({
        'GET /chapters/admin': (call) => {
          'data': [
            {'id': 'c1', 'name': 'Pune Chapter', 'scope': 'REGIONAL', 'city': 'Pune', 'country': 'India'},
            {'id': 'c2', 'name': 'UAE Chapter', 'scope': 'COUNTRY', 'city': '', 'country': 'United Arab Emirates'},
          ],
          'meta': {'page': 1, 'limit': call.query['limit'], 'total': 2, 'totalPages': 1},
        },
      });
      final page = await api.chapters(page: 2, search: ' pune ');
      expect(h.api.last('GET /chapters/admin').query, {'page': 2, 'limit': 20, 'search': 'pune'});
      expect(page.rows.map((c) => c.name), ['Pune Chapter', 'UAE Chapter']);
      expect(page.rows.last.countryWide, isTrue);

      final found = await api.chapter('c2');
      expect(found?.name, 'UAE Chapter');
      expect(h.api.last('GET /chapters/admin').query, {'page': 1, 'limit': 100});
      expect(await api.chapter('nope'), isNull);
    });

    test('each write goes where the website sends it', () async {
      final h = harness({
        'POST /chapters': (_) => {'id': 'c9'},
        'PATCH /councils/co1': (_) => {'id': 'co1'},
        'DELETE /chapters/c1': (_) => {'id': 'c1'},
        'POST /chapters/c1/sponsors': (_) => {'id': 's1'},
        'DELETE /chapters/c1/sponsors/s1': (_) => {'deleted': true},
        'POST /councils/co1/resources': (_) => {'id': 'r1'},
        'DELETE /councils/co1/announcements/a1': (_) => {'deleted': true},
        'POST /chapters/c1/leads': (_) => {'userId': 'u1'},
        'PATCH /councils/co1/members/u1': (_) => {'userId': 'u1'},
        'GET /chapters/c1/lead-candidates': (_) => [
          {'id': 'u1', 'firstName': 'Anil', 'lastName': 'Kumar', 'email': 'anil@acme.com', 'isMember': true},
        ],
        'GET /admin/chapter-applications': (_) => {
          'data': [
            {
              'id': 'a1',
              'kind': 'LEAD_EXISTING',
              'chapter': {'id': 'c1', 'name': 'Pune Chapter', 'slug': 'pune'},
              'city': 'Pune',
              'country': 'India',
              'motivation': 'm',
              'experience': 'e',
              'status': 'PENDING',
              'createdAt': '2026-11-02T10:00:00.000Z',
              'applicant': {'id': 'u1', 'firstName': 'Anil', 'lastName': 'Kumar', 'email': 'anil@acme.com'},
            },
          ],
          'meta': {'page': 1, 'limit': 20, 'total': 1, 'totalPages': 1},
        },
        'POST /admin/chapter-applications/a1/decide': (_) => {'id': 'a1'},
        'POST /admin/council-proposals/p1/decide': (_) => {'id': 'p1'},
      });
      await api.createChapter({'name': 'Pune Chapter'});
      expect(h.api.last('POST /chapters').json, {'name': 'Pune Chapter'});
      await api.updateCouncil('co1', {'published': false});
      expect(h.api.last('PATCH /councils/co1').json, {'published': false});
      await api.retire(OrgKind.chapter, 'c1');
      await api.addSponsor('c1', {'name': 'Acme'});
      await api.removeSponsor('c1', 's1');
      await api.addResource(OrgKind.council, 'co1', {'title': 'T', 'kind': 'OTHER', 'url': 'https://x'});
      await api.removeAnnouncement(OrgKind.council, 'co1', 'a1');
      await api.addLead('c1', {'userId': 'u1'});
      await api.updateMember(OrgKind.council, 'co1', 'u1', {'role': 'MEMBER'});
      expect(h.api.last('PATCH /councils/co1/members/u1').json, {'role': 'MEMBER'});

      expect(await api.leadCandidates('c1', 'a'), isEmpty, reason: 'nothing is asked under two letters');
      expect(h.api.count('GET /chapters/c1/lead-candidates'), 0);
      final people = await api.leadCandidates('c1', 'an');
      expect(people.single.name, 'Anil Kumar');
      expect(people.single.isMember, isTrue);

      final applications = await api.chapterApplications(status: 'PENDING');
      expect(h.api.last('GET /admin/chapter-applications').query, {'page': 1, 'limit': 20, 'status': 'PENDING'});
      expect(applications.rows.single.title, 'Lead Pune Chapter');
      expect(applications.rows.single.applicant?.line, 'Anil Kumar · anil@acme.com');

      await api.decide(OrgKind.chapter, 'a1', decision: 'DECLINED', reason: ' Not now. ');
      expect(h.api.last('POST /admin/chapter-applications/a1/decide').json, {
        'decision': 'DECLINED',
        'reason': 'Not now.',
      });
      await api.decide(OrgKind.council, 'p1', decision: 'APPROVED');
      expect(h.api.last('POST /admin/council-proposals/p1/decide').json, {'decision': 'APPROVED'});
      for (final key in [
        'DELETE /chapters/c1',
        'POST /chapters/c1/sponsors',
        'DELETE /chapters/c1/sponsors/s1',
        'POST /councils/co1/resources',
        'DELETE /councils/co1/announcements/a1',
        'POST /chapters/c1/leads',
      ]) {
        expect(h.api.count(key), 1, reason: key);
      }
    });

    test("a refusal carries the API's own message", () async {
      harness({'PATCH /chapters/c1': (_) => ApiReply.refusal(400, 'Choose the city this regional chapter covers.')});
      await expectLater(
        api.updateChapter('c1', {'city': ''}),
        throwsA(
          isA<ApiError>().having((e) => e.message, 'message', 'Choose the city this regional chapter covers.'),
        ),
      );
    });
  });

  group('Manage Chapters', () {
    testWidgets('lists every chapter with its place, size and whether it is listed; the search asks the API', (
      tester,
    ) async {
      await pumpChapters(tester);
      expect(find.text('Manage Chapters'), findsOneWidget);
      expect(find.text('Chapters'), findsOneWidget, reason: 'the tab, and no heading repeating it');
      expect(find.text('Applications'), findsOneWidget);
      final blr = find.byKey(const ValueKey('chapter-row-ch-blr'));
      expect(find.descendant(of: blr, matching: find.text('Bengaluru Chapter')), findsOneWidget);
      expect(
        find.descendant(of: blr, matching: find.text('Regional chapter · Bengaluru · Karnataka · India')),
        findsOneWidget,
      );
      expect(find.descendant(of: blr, matching: find.text('128 members · 3 upcoming events')), findsOneWidget);
      expect(find.descendant(of: blr, matching: find.text('Published')), findsOneWidget);
      final mumbai = find.byKey(const ValueKey('chapter-row-ch-mum'));
      expect(find.descendant(of: mumbai, matching: find.text('Hidden')), findsOneWidget);
      final uae = find.byKey(const ValueKey('chapter-row-ch-uae'));
      expect(
        find.descendant(of: uae, matching: find.text('Country chapter · United Arab Emirates')),
        findsOneWidget,
      );
      expect(find.descendant(of: uae, matching: find.text('41 members · 1 upcoming event')), findsOneWidget);
      expect(find.byKey(const ValueKey('manage-new')), findsOneWidget);
      expect(find.text('New Chapter'), findsOneWidget);
      expect(find.byType(Card), findsNothing, reason: 'rows the whole width, hairlines between');
      expect(find.byKey(const ValueKey('manage-page-label')), findsNothing, reason: 'one page: no pager');

      await tester.enterText(find.byKey(const ValueKey('manage-search')), 'mum');
      await settle(tester);
      expect(find.byKey(const ValueKey('chapter-row-ch-mum')), findsOneWidget);
      expect(find.byKey(const ValueKey('chapter-row-ch-blr')), findsNothing);

      await tester.enterText(find.byKey(const ValueKey('manage-search')), 'nowhere');
      await settle(tester);
      expect(find.text('No chapters'), findsOneWidget);
    });

    testWidgets('pages by twenty', (tester) async {
      final many = MemoryCommunityManageRepository(
        chapters: [
          for (var i = 1; i <= 23; i++)
            AdminChapter(id: 'c$i', name: 'Chapter ${i.toString().padLeft(2, '0')}', city: 'City $i'),
        ],
        content: {},
      );
      await pumpChapters(tester, repository: many);
      expect(find.byKey(const ValueKey('chapter-row-c1')), findsOneWidget);
      await reveal(tester, find.byKey(const ValueKey('manage-page-label')));
      expect(find.text('Page 1 of 2'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('manage-page-next')));
      await settle(tester);
      expect(find.byKey(const ValueKey('chapter-row-c21')), findsOneWidget);
      expect(find.byKey(const ValueKey('chapter-row-c1')), findsNothing);
      expect(find.text('Page 2 of 2'), findsOneWidget);
    });

    testWidgets('a role over some chapters sees those, with no New Chapter; its page has no Retire or Add Leader', (
      tester,
    ) async {
      await pumpChapters(
        tester,
        everywhere: false,
        repository: MemoryCommunityManageRepository(reach: {'ch-blr'}),
      );
      expect(find.byKey(const ValueKey('chapter-row-ch-blr')), findsOneWidget);
      expect(find.byKey(const ValueKey('chapter-row-ch-mum')), findsNothing);
      expect(find.byKey(const ValueKey('manage-new')), findsNothing);
      expect(find.text('New Chapter'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('chapter-row-ch-blr')));
      await settle(tester);
      expect(find.text('Manage Chapter'), findsOneWidget);
      expect(find.byKey(const ValueKey('record-edit')), findsOneWidget, reason: 'editing its own chapter is theirs');
      await reveal(tester, find.byKey(const ValueKey('section-members')));
      expect(find.byKey(const ValueKey('leader-add')), findsNothing);
      expect(find.byKey(const ValueKey('member-make-lead')), findsOneWidget, reason: 'the scoped call still works');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
      await settle(tester);
      expect(find.byKey(const ValueKey('record-retire')), findsNothing);
      expect(find.text('Retire Chapter'), findsNothing);

      // And the Applications tab says what the API says: its lists need the key everywhere.
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('manage-tab-1')));
      await settle(tester);
      expect(
        find.text("Your role doesn't reach this record. Ask a Super Admin to widen it if you need to."),
        findsOneWidget,
      );
    });

    testWidgets('New Chapter: the form refuses what the API would, then sends the website\'s body', (tester) async {
      await pumpChapters(tester);
      await tester.tap(find.byKey(const ValueKey('manage-new')));
      await settle(tester);
      expect(find.text('Create Chapter'), findsWidgets);
      expect(find.text('Country-wise chapter'), findsOneWidget);
      expect(find.text('Regional chapter (a city)'), findsOneWidget);

      await save(tester);
      expect(sheetError(tester), 'Give the chapter a name.');
      expect(repo.sent, isEmpty);

      await type(tester, 'chapter.name', 'Pune Chapter');
      await save(tester);
      expect(sheetError(tester), 'Choose the city this regional chapter covers.');
      expect(repo.sent, isEmpty);

      await openSelect(tester, 'chapter.city');
      await tester.enterText(find.byKey(const Key('citySheet.search')), 'pun');
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('city-Pune')));
      await settle(tester);
      expect(find.text('Pune · Maharashtra · India'), findsOneWidget);

      await type(tester, 'chapter.foundedYear', '1850');
      await save(tester);
      expect(sheetError(tester), 'The founded year must be 1900 or later.');
      await type(tester, 'chapter.foundedYear', '2024');
      await type(tester, 'chapter.contactEmail', 'pune@');
      await save(tester);
      expect(sheetError(tester), 'Enter a valid email address.');
      expect(repo.sent, isEmpty);
      await type(tester, 'chapter.contactEmail', 'pune@icr.org.in');
      await type(tester, 'about.mission', 'Bring Pune’s facility leaders together.');
      await type(tester, 'about.activities', 'Monthly meetups\nSite visits');
      await tapInSheet(tester, find.byKey(const Key('chapter.published')));
      expect(find.text('Unpublished (hidden)'), findsOneWidget);

      await save(tester);
      expect(repo.sent.last['action'], 'createChapter');
      expect(lastBody(), {
        'name': 'Pune Chapter',
        'scope': 'REGIONAL',
        'city': 'Pune',
        'country': 'India',
        'region': 'Maharashtra',
        'contactEmail': 'pune@icr.org.in',
        'foundedYear': 2024,
        'galleryUrls': <String>[],
        'published': false,
        'aboutHtml':
            '<h3>Mission</h3>\n<p>Bring Pune’s facility leaders together.</p>\n'
            '<h3>What we do</h3>\n<ul>\n<li>Monthly meetups</li>\n<li>Site visits</li>\n</ul>',
      });
      expect(find.text('Chapter created.'), findsOneWidget);
      final row = find.widgetWithText(InkWell, 'Pune Chapter');
      expect(row, findsOneWidget);
      expect(find.descendant(of: row, matching: find.text('Hidden')), findsOneWidget);
    });

    testWidgets('a country-wise chapter is placed by its country alone; a city anywhere fills its country', (
      tester,
    ) async {
      await pumpChapters(tester);
      await tester.tap(find.byKey(const ValueKey('manage-new')));
      await settle(tester);
      await type(tester, 'chapter.name', 'Dubai Chapter');
      await openSelect(tester, 'chapter.city');
      await tester.enterText(find.byKey(const Key('citySheet.search')), 'dubai');
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('city-Dubai, United Arab Emirates')));
      await settle(tester);
      expect(find.text('Dubai · Dubai · United Arab Emirates'), findsOneWidget);

      await tapInSheet(tester, find.byKey(const ValueKey('choice-COUNTRY')));
      expect(find.byKey(const Key('chapter.city')), findsNothing);
      expect(find.text('The chapter covers the whole country.'), findsOneWidget);
      await openSelect(tester, 'chapter.country');
      await tester.enterText(find.byKey(const Key('countrySheet.search')), 'Kenya');
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('country-other')));
      await settle(tester);
      await save(tester);
      expect(lastBody()['scope'], 'COUNTRY');
      expect(lastBody()['country'], 'Kenya');
      expect(lastBody()['city'], '');
      expect(lastBody()['region'], isNull);
    });

    testWidgets("the API's refusal is shown in its own words, and the form keeps what was typed", (tester) async {
      await pumpChapter(tester);
      repo.refuse['updateChapter'] = ApiError('A chapter with this name already exists.', statusCode: 409);
      await tester.tap(find.byKey(const ValueKey('record-edit')));
      await settle(tester);
      await type(tester, 'chapter.name', 'Mumbai Chapter');
      await save(tester);
      expect(sheetError(tester), 'A chapter with this name already exists.');
      expect(find.text('Mumbai Chapter'), findsOneWidget);
      await save(tester);
      expect(repo.sent.last['action'], 'updateChapter');
      expect(find.text('Chapter saved.'), findsOneWidget);
    });

    testWidgets('pages it pushes go through pageWrap', (tester) async {
      var wrapped = 0;
      await pumpChapters(
        tester,
        pageWrap: (page) {
          wrapped += 1;
          return KeyedSubtree(key: const ValueKey('wrapped'), child: page);
        },
      );
      await tester.tap(find.byKey(const ValueKey('chapter-row-ch-blr')));
      await settle(tester);
      expect(wrapped, greaterThan(0));
      expect(
        find.descendant(of: find.byKey(const ValueKey('wrapped')), matching: find.text('Manage Chapter')),
        findsOneWidget,
      );
    });

    testWidgets('lays out on a 360 dp phone', (tester) async {
      await pumpChapters(tester, width: 360);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('manage-tab-1')));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('request-filter-DECLINED')));
      await settle(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('a chapter\'s manage page', () {
    testWidgets('shows the details and every content section the website\'s drawer has', (tester) async {
      await pumpChapter(tester);
      expect(find.text('Manage Chapter'), findsOneWidget);
      expect(find.text('Bengaluru Chapter'), findsOneWidget);
      expect(find.text('Regional chapter · Bengaluru · Karnataka · India'), findsOneWidget);
      expect(find.text('128 members · 3 upcoming events'), findsOneWidget);
      expect(find.text('bengaluru@icr.org.in'), findsOneWidget);
      expect(find.text('Mission, What we do'), findsOneWidget, reason: 'the About, by the headings that hold words');
      await reveal(tester, find.byKey(const ValueKey('sponsor-sp-1')));
      expect(find.text('Acme Facilities'), findsOneWidget);
      await reveal(tester, find.byKey(const ValueKey('resource-rs-1')));
      expect(find.text('Whitepaper · 2 MB'), findsOneWidget);
      await reveal(tester, find.byKey(const ValueKey('announcement-an-1')));
      expect(find.text('Pinned'), findsOneWidget);
      await reveal(tester, find.byKey(const ValueKey('lead-u-asha')));
      expect(find.text('Chapter President'), findsOneWidget);
      expect(find.text('Term: 1 Jan 2026 – open'), findsOneWidget);
      await toTop(tester);
      for (final section in ['sponsors', 'resources', 'updates', 'leadership', 'members', 'retire']) {
        await reveal(tester, find.byKey(ValueKey('section-$section')));
      }
    });

    testWidgets('Edit opens every field of the website\'s dialog and sends the change', (tester) async {
      final pickers = FakePickers(image: png('hall.png'));
      await pumpChapter(tester, pickers: pickers);
      await tester.tap(find.byKey(const ValueKey('record-edit')));
      await settle(tester);
      expect(find.text('Edit Chapter'), findsOneWidget);
      for (final label in [
        'Name *',
        'Chapter Type',
        'City *',
        'Founded Year',
        'Short Description',
        'About',
        'Mission',
        'Vision',
        'What we do',
        'Membership benefits',
        'Industries served',
        'Banner',
        'Chapter Picture',
        'Gallery Images',
        'Contact Email',
      ]) {
        expect(inSheet(label), findsOneWidget, reason: label);
      }
      expect(find.text('Published (listed publicly)'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byKey(const Key('about.activities'))).controller!.text,
        'Monthly meetups\nSite visits',
      );

      await type(tester, 'chapter.description', '');
      await type(tester, 'about.vision', 'Every site well run.');
      await tapInSheet(tester, find.byKey(const ValueKey('gallery-add')));
      expect(find.byKey(const ValueKey('gallery-0')), findsOneWidget);
      await tapInSheet(tester, find.byKey(const ValueKey('picture-pick-Banner')));
      await save(tester);

      expect(repo.sent.where((s) => s['action'] == 'upload').map((s) => s['purpose']), [
        'chapter-gallery',
        'chapter-cover',
      ]);
      expect(repo.sent.last['action'], 'updateChapter');
      expect(repo.sent.last['id'], 'ch-blr');
      final body = lastBody();
      expect(body['description'], isNull, reason: 'cleared');
      expect(body['galleryUrls'], ['/uploads/demo/hall.png']);
      expect(body['coverUrl'], '/uploads/demo/hall.png');
      expect(body.containsKey('logoUrl'), isFalse);
      expect(body['aboutHtml'], contains('<h3>Vision</h3>\n<p>Every site well run.</p>'));
      expect(body['aboutHtml'], contains('<li>Monthly meetups</li>'));
      expect(find.text('Chapter saved.'), findsOneWidget);
      expect(find.text('Mission, Vision, What we do'), findsOneWidget);
    });

    testWidgets('a picture of the wrong kind or weight is refused before it is sent', (tester) async {
      final pickers = FakePickers(
        image: UploadFile(name: 'scan.gif', bytes: Uint8List(4), mimeType: 'image/gif'),
      );
      await pumpChapter(tester, pickers: pickers);
      await tester.tap(find.byKey(const ValueKey('record-edit')));
      await settle(tester);
      await tapInSheet(tester, find.byKey(const ValueKey('gallery-add')));
      expect(find.text('Only PNG, JPG or WEBP images are supported.'), findsOneWidget);
      pickers.image = png('big.png', bytes: ManageLimits.coverBytes + 1);
      await tapInSheet(tester, find.byKey(const ValueKey('picture-pick-Banner')));
      expect(find.text('Each image must be 5 MB or smaller. Compress it or choose a smaller one.'), findsOneWidget);
      expect(repo.sent, isEmpty);
    });

    testWidgets('Sponsors: add one, then remove one (asked first)', (tester) async {
      await pumpChapter(tester);
      await tapOnPage(tester, find.byKey(const ValueKey('sponsor-add')));
      expect(find.text('Add Sponsor'), findsWidgets);
      await save(tester);
      expect(sheetError(tester), 'Give the sponsor a name.');
      await type(tester, 'sponsor.name', 'Northwind Estates');
      await type(tester, 'sponsor.tier', 'Silver');
      await type(tester, 'sponsor.url', 'https://northwind.example');
      await save(tester);
      expect(repo.sent.last['action'], 'addSponsor');
      expect(lastBody(), {'name': 'Northwind Estates', 'url': 'https://northwind.example', 'tier': 'Silver'});
      await reveal(tester, find.text('Northwind Estates'));
      await clearMessage(tester);

      await tapOnPage(tester, find.byKey(const ValueKey('sponsor-remove-sp-1')));
      expect(find.text('Remove “Acme Facilities”?'), findsOneWidget);
      await confirm(tester);
      expect(repo.sent.last, {'action': 'removeSponsor', 'id': 'ch-blr', 'sponsorId': 'sp-1'});
      expect(find.text('Acme Facilities'), findsNothing);
      expect(find.text('Northwind Estates'), findsOneWidget);
    });

    testWidgets('Resources: add one with its kind, then remove one', (tester) async {
      await pumpChapter(tester);
      await tapOnPage(tester, find.byKey(const ValueKey('resource-add')));
      await type(tester, 'resource.title', 'Site Visit Deck');
      await save(tester);
      expect(sheetError(tester), 'Add the resource’s URL.');
      await openSelect(tester, 'resource.kind');
      await tester.tap(find.descendant(of: find.byType(ListTile), matching: find.text('Presentation')));
      await settle(tester);
      await type(tester, 'resource.sizeLabel', '4 MB');
      await type(tester, 'resource.url', 'https://files.example/deck.pdf');
      await save(tester);
      expect(repo.sent.last['action'], 'addResource');
      expect(repo.sent.last['kind'], 'chapter');
      expect(lastBody(), {
        'title': 'Site Visit Deck',
        'kind': 'PRESENTATION',
        'url': 'https://files.example/deck.pdf',
        'sizeLabel': '4 MB',
      });
      await reveal(tester, find.text('Presentation · 4 MB'));
      await clearMessage(tester);

      await tapOnPage(tester, find.byKey(const ValueKey('resource-remove-rs-1')));
      await confirm(tester);
      expect(repo.sent.last['action'], 'removeResource');
      expect(repo.sent.last['resourceId'], 'rs-1');
      expect(find.text('Annual Report 2025'), findsNothing);
    });

    testWidgets('Updates: post an announcement, pinned, then remove one', (tester) async {
      await pumpChapter(tester);
      await tapOnPage(tester, find.byKey(const ValueKey('announcement-add')));
      expect(find.text('Post Announcement'), findsWidgets);
      await type(tester, 'announcement.title', 'Call for volunteers');
      await save(tester);
      expect(sheetError(tester), 'Write the update.');
      await type(tester, 'announcement.body', 'We need four people for the December site visit.');
      await tapInSheet(tester, find.byKey(const Key('announcement.pinned')));
      await save(tester);
      expect(repo.sent.last['action'], 'addAnnouncement');
      expect(lastBody(), {
        'title': 'Call for volunteers',
        'body': 'We need four people for the December site visit.',
        'pinned': true,
      });
      await reveal(tester, find.text('Call for volunteers'));
      await clearMessage(tester);

      await tapOnPage(tester, find.byKey(const ValueKey('announcement-remove-an-1')));
      await confirm(tester);
      expect(repo.sent.last['action'], 'removeAnnouncement');
      expect(repo.sent.last['announcementId'], 'an-1');
      expect(find.text('November meetup'), findsNothing);
    });

    testWidgets('Leadership: add a leader found by name, who is joined if they were not a member', (tester) async {
      await pumpChapter(tester);
      await tapOnPage(tester, find.byKey(const ValueKey('leader-add')));
      expect(find.text('Add a Leader'), findsOneWidget);
      expect(find.text('Type at least 2 letters of a name or email'), findsOneWidget);
      await type(tester, 'leader.search', 'zo');
      await tapInSheet(tester, find.byKey(const ValueKey('leader-option-u-zoya')));
      expect(
        find.text('Zoya is not a member of this chapter yet; adding them as a leader joins them.'),
        findsOneWidget,
      );
      await type(tester, 'leader.title', 'Vice President');
      await save(tester);
      expect(repo.sent.last['action'], 'addLead');
      expect(lastBody(), {'userId': 'u-zoya', 'title': 'Vice President'});
      await reveal(tester, find.byKey(const ValueKey('lead-u-zoya')));
      expect(find.text('Zoya Khan'), findsOneWidget);
    });

    testWidgets('Leadership: a lead\'s term cannot end before it starts; a good one is saved; Step Down asks first', (
      tester,
    ) async {
      final pickers = FakePickers(day: DateTime(2025, 12, 31));
      await pumpChapter(tester, pickers: pickers);
      await tapOnPage(tester, find.byKey(const ValueKey('lead-u-asha')));
      expect(find.text('Leave empty for an open term'), findsOneWidget);
      await openSelect(tester, 'lead.termEnds');
      expect(find.text('31 Dec 2025'), findsOneWidget);
      await save(tester);
      expect(sheetError(tester), 'A term can’t end before it starts.');
      expect(repo.sent, isEmpty);

      pickers.day = DateTime(2026, 12, 31);
      await openSelect(tester, 'lead.termEnds');
      await type(tester, 'lead.title', 'President');
      await save(tester);
      expect(repo.sent.last['action'], 'updateMember');
      expect(lastBody(), {
        'title': 'President',
        'linkedinUrl': '',
        'termStartsOn': '2026-01-01',
        'termEndsOn': '2026-12-31',
      });
      await reveal(tester, find.text('Term: 1 Jan 2026 – 31 Dec 2026'));
      await clearMessage(tester);

      await tapOnPage(tester, find.byKey(const ValueKey('lead-u-asha')));
      await tapInSheet(tester, find.byKey(const Key('sheet.delete')));
      expect(find.text('Step Asha Rao Down to Member?'), findsOneWidget);
      await confirm(tester);
      expect(lastBody(), {'role': 'MEMBER'});
      expect(repo.sent.last['userId'], 'u-asha');
      await reveal(tester, find.byKey(const ValueKey('leads-empty')));
      expect(find.byKey(const ValueKey('lead-u-asha')), findsNothing);
    });

    testWidgets('Members: make a member a lead, with a term starting today', (tester) async {
      await pumpChapter(tester);
      await tapOnPage(tester, find.byKey(const ValueKey('member-make-lead')));
      expect(find.text('Make a Member a Lead'), findsOneWidget);
      expect(find.text('13 Nov 2026'), findsOneWidget, reason: 'the term starts today unless changed');
      await openSelect(tester, 'makeLead.member');
      await tester.tap(find.descendant(of: find.byType(ListTile), matching: find.text('Ravi Menon')));
      await settle(tester);
      await save(tester);
      expect(repo.sent.last['action'], 'updateMember');
      expect(repo.sent.last['userId'], 'u-ravi');
      expect(lastBody(), {'role': 'LEAD', 'termStartsOn': '2026-11-13', 'termEndsOn': ''});
      await reveal(tester, find.byKey(const ValueKey('lead-u-ravi')));
    });

    testWidgets('a term that has run out is marked', (tester) async {
      final repository = MemoryCommunityManageRepository();
      repository.contents['ch-blr'] = const OrgContent(
        leads: [ContentLead(userId: 'u-old', firstName: 'Old', lastName: 'Lead', termEndsOn: '2026-11-12')],
      );
      await pumpChapter(tester, repository: repository);
      await reveal(tester, find.byKey(const ValueKey('lead-u-old')));
      expect(find.text('Term ended'), findsOneWidget);
      expect(find.text('Term ends 12 Nov 2026'), findsOneWidget);
    });

    testWidgets('Retire asks first, then leaves the page', (tester) async {
      await pumpChapter(tester);
      await tapOnPage(tester, find.byKey(const ValueKey('record-retire')));
      expect(find.text('Retire “Bengaluru Chapter”?'), findsOneWidget);
      expect(find.text('It disappears from the public directory.'), findsOneWidget);
      await confirm(tester);
      expect(repo.sent.last, {'action': 'retire', 'kind': 'chapter', 'id': 'ch-blr'});
      expect(backs, 1);
    });

    testWidgets('a chapter the role does not reach shows the API\'s words', (tester) async {
      await pumpChapter(tester, repository: MemoryCommunityManageRepository(reach: {'ch-mum'}), everywhere: false);
      expect(
        find.text("Your role doesn't reach this record. Ask a Super Admin to widen it if you need to."),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('record-edit')), findsNothing);
    });

    testWidgets('lays out on a 360 dp phone, the edit form included', (tester) async {
      await pumpChapter(tester, width: 360);
      for (final section in ['sponsors', 'resources', 'updates', 'leadership', 'members', 'retire']) {
        await reveal(tester, find.byKey(ValueKey('section-$section')));
        expect(tester.takeException(), isNull, reason: section);
      }
      await toTop(tester);
      await tester.tap(find.byKey(const ValueKey('record-edit')));
      await settle(tester);
      await tester.ensureVisible(find.byKey(const Key('chapter.published')));
      await settle(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('chapter applications', () {
    testWidgets('lists the ones to review; a decline needs its reason; an approval takes an optional note', (
      tester,
    ) async {
      await pumpChapters(tester, initialTab: 'applications');
      expect(find.text('To review'), findsOneWidget);
      expect(find.text('New chapter: Hyderabad Chapter'), findsOneWidget);
      expect(find.text('Start a new chapter'), findsOneWidget);
      expect(find.text('Kiran Reddy · kiran@estate.in'), findsOneWidget);
      expect(find.text('Hyderabad, India · sent 2 Nov 2026'), findsOneWidget);
      expect(find.text('Why, and what the chapter would do'), findsOneWidget);
      expect(find.text('Experience'), findsOneWidget);
      expect(find.text('Lead Mumbai Chapter'), findsNothing, reason: 'declined already');

      await tapOnPage(tester, find.byKey(const ValueKey('request-decline-app-1')));
      expect(find.text('The member reads this reason in their notifications and on their application.'), findsOneWidget);
      expect(find.text('Reason (required)'), findsOneWidget);
      await save(tester);
      expect(sheetError(tester), 'Say why it isn’t approved. The member reads this.');
      expect(repo.sent, isEmpty);
      await type(tester, 'decide.reason', 'Hyderabad is covered by the Telangana chapter.');
      await save(tester);
      expect(repo.sent.last, {
        'action': 'decide',
        'kind': 'chapter',
        'id': 'app-1',
        'decision': 'DECLINED',
        'reason': 'Hyderabad is covered by the Telangana chapter.',
      });
      expect(find.text('No chapter applications here'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('request-filter-DECLINED')));
      await settle(tester);
      expect(find.text('New chapter: Hyderabad Chapter'), findsOneWidget);
      expect(find.text('Lead Mumbai Chapter'), findsOneWidget);
      expect(find.text('The chapter already has a lead in place.'), findsOneWidget);
      expect(find.text('Declined 20 Oct 2026'), findsOneWidget);
      expect(find.byKey(const ValueKey('request-approve-app-2')), findsNothing, reason: 'decided: no buttons');
    });

    testWidgets('approving sets the chapter up; Find It shows it in the Chapters tab', (tester) async {
      await pumpChapters(tester, initialTab: 'applications');
      await tapOnPage(tester, find.byKey(const ValueKey('request-approve-app-1')));
      expect(find.text('Note to the Member (optional)'), findsOneWidget);
      expect(
        find.text(
          'Approving makes the member lead from today. A new chapter is created unpublished: finish its page in '
          'the Chapters tab, then publish it.',
        ),
        findsOneWidget,
      );
      await save(tester);
      expect(repo.sent.last['decision'], 'APPROVED');
      expect(repo.sent.last['reason'], '');
      expect(find.text('Application approved.'), findsOneWidget);
      await clearMessage(tester);

      await tester.tap(find.byKey(const ValueKey('request-filter-APPROVED')));
      await settle(tester);
      expect(
        find.text('Result: Hyderabad Chapter (unpublished — publish it from its tab when ready)'),
        findsOneWidget,
      );
      await tapOnPage(tester, find.byKey(const ValueKey('request-find-app-1')));
      expect(find.byKey(const ValueKey('chapters-tab')), findsOneWidget);
      final search = find.descendant(of: find.byKey(const ValueKey('manage-search')), matching: find.byType(TextField));
      expect(tester.widget<TextField>(search).controller!.text, 'Hyderabad Chapter');
    });

    testWidgets("the API's refusal of a decision is shown in the sheet", (tester) async {
      await pumpChapters(tester, initialTab: 'applications');
      repo.refuse['decide'] = ApiError('This request has already been decided or withdrawn.', statusCode: 400);
      await tapOnPage(tester, find.byKey(const ValueKey('request-approve-app-1')));
      await save(tester);
      expect(sheetError(tester), 'This request has already been decided or withdrawn.');
    });

    testWidgets('a notification\'s application opens on its tab, marked', (tester) async {
      await pumpChapters(tester, focusApplicationId: 'app-1');
      expect(find.byKey(const ValueKey('applications-tab')), findsOneWidget);
      expect(find.text('New chapter: Hyderabad Chapter'), findsOneWidget);
      final tinted = find.ancestor(
        of: find.text('New chapter: Hyderabad Chapter'),
        matching: find.byWidgetPredicate((w) => w is ColoredBox && w.color == WsColors.tint),
      );
      expect(tinted, findsOneWidget);
    });
  });

  group('Manage Councils', () {
    testWidgets('lists every council with its segments; New Council only when the key is held everywhere', (
      tester,
    ) async {
      await pumpCouncils(tester);
      expect(find.text('Manage Councils'), findsOneWidget);
      expect(find.text('Councils'), findsOneWidget);
      expect(find.text('Proposals'), findsOneWidget);
      final health = find.byKey(const ValueKey('council-row-co-health'));
      expect(find.descendant(of: health, matching: find.text('Hospitals · Pharma')), findsOneWidget);
      expect(find.descendant(of: health, matching: find.text('52 members')), findsOneWidget);
      expect(find.descendant(of: health, matching: find.text('Published')), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(const ValueKey('council-row-co-proc')), matching: find.text('Hidden')),
        findsOneWidget,
      );
      expect(find.text('New Council'), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('manage-search')), 'procurement');
      await settle(tester);
      expect(find.byKey(const ValueKey('council-row-co-health')), findsNothing);
      expect(find.byKey(const ValueKey('council-row-co-proc')), findsOneWidget);
    });

    testWidgets('a role over some councils sees those, with no New Council and no Retire on its page', (tester) async {
      await pumpCouncils(tester, everywhere: false, repository: MemoryCommunityManageRepository(reach: {'co-health'}));
      expect(find.byKey(const ValueKey('council-row-co-health')), findsOneWidget);
      expect(find.byKey(const ValueKey('council-row-co-proc')), findsNothing);
      expect(find.text('New Council'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('council-row-co-health')));
      await settle(tester);
      expect(find.text('Manage Council'), findsOneWidget);
      await reveal(tester, find.byKey(const ValueKey('section-members')));
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
      await settle(tester);
      expect(find.byKey(const ValueKey('record-retire')), findsNothing);
    });

    testWidgets('New Council: the slug follows the name, segments are typed, and the form is held to the DTO', (
      tester,
    ) async {
      await pumpCouncils(tester);
      await tester.tap(find.byKey(const ValueKey('manage-new')));
      await settle(tester);
      expect(find.text('Create Council'), findsWidgets);
      await save(tester);
      expect(sheetError(tester), 'Give the council a name.');
      expect(repo.sent, isEmpty);

      await type(tester, 'council.name', 'Data Centre Operations');
      expect(
        tester.widget<TextField>(find.byKey(const Key('council.slug'))).controller!.text,
        'data-centre-operations',
      );
      await type(tester, 'council.segment', 'Data Centres,');
      expect(find.text('Data Centres'), findsOneWidget);
      await type(tester, 'council.segment', 'Colocation');
      await type(tester, 'about.objectives', 'Share uptime practice\nPublish a checklist');
      await type(tester, 'council.contactEmail', 'dc@');
      await save(tester);
      expect(sheetError(tester), 'Enter a valid email address.');
      await type(tester, 'council.contactEmail', 'dc@icr.org.in');
      await save(tester);
      expect(repo.sent.last['action'], 'createCouncil');
      expect(lastBody(), {
        'name': 'Data Centre Operations',
        'slug': 'data-centre-operations',
        'focus': 'Data Centres · Colocation',
        'segments': ['Data Centres', 'Colocation'],
        'contactEmail': 'dc@icr.org.in',
        'galleryUrls': <String>[],
        'published': true,
        'aboutHtml': '<h3>Objectives</h3>\n<ul>\n<li>Share uptime practice</li>\n<li>Publish a checklist</li>\n</ul>',
      });
      expect(find.text('Council created.'), findsOneWidget);
      expect(find.text('Data Centre Operations'), findsOneWidget);
    });

    testWidgets('a council\'s manage page: Resources, Updates, Leadership and Members, and no Sponsors', (
      tester,
    ) async {
      await pumpCouncil(tester);
      expect(find.text('Manage Council'), findsOneWidget);
      expect(find.text('Healthcare Facilities Council'), findsOneWidget);
      expect(find.byKey(const ValueKey('section-sponsors')), findsNothing);
      for (final section in ['resources', 'updates', 'leadership', 'members', 'retire']) {
        await reveal(tester, find.byKey(ValueKey('section-$section')));
      }
      expect(find.byKey(const ValueKey('leader-add')), findsNothing, reason: 'the API has no lead search for a council');
      await toTop(tester);

      await tapOnPage(tester, find.byKey(const ValueKey('resource-add')));
      await type(tester, 'resource.title', 'Standards Pack');
      await type(tester, 'resource.url', 'https://files.example/pack.pdf');
      await save(tester);
      expect(repo.sent.last['action'], 'addResource');
      expect(repo.sent.last['kind'], 'council');
      expect(lastBody(), {'title': 'Standards Pack', 'kind': 'OTHER', 'url': 'https://files.example/pack.pdf'});
      await clearMessage(tester);

      await tapOnPage(tester, find.byKey(const ValueKey('announcement-remove-an-9')));
      await confirm(tester);
      expect(repo.sent.last['action'], 'removeAnnouncement');
      expect(repo.sent.last['kind'], 'council');
      await clearMessage(tester);

      await tapOnPage(tester, find.byKey(const ValueKey('member-make-lead')));
      await openSelect(tester, 'makeLead.member');
      await tester.tap(find.descendant(of: find.byType(ListTile), matching: find.text('Mira Nair')));
      await settle(tester);
      await save(tester);
      expect(lastBody(), {'role': 'LEAD', 'termStartsOn': '2026-11-13', 'termEndsOn': ''});
      expect(repo.sent.last['kind'], 'council');
      await clearMessage(tester);

      await toTop(tester);
      await tapOnPage(tester, find.byKey(const ValueKey('record-edit')));
      expect(find.text('Edit Council'), findsOneWidget);
      for (final label in [
        'Name *',
        'Slug *',
        'Member Segments',
        'Focus Line',
        'Description',
        'Mission',
        'Vision',
        'Objectives',
        'Member benefits',
        'Industries covered',
        'Cover',
        'Gallery Images',
        'Contact Email',
      ]) {
        expect(inSheet(label), findsOneWidget, reason: label);
      }
      await tapInSheet(tester, find.byKey(const Key('council.published')));
      await save(tester);
      expect(repo.sent.last['action'], 'updateCouncil');
      expect(lastBody()['published'], isFalse);
      expect(lastBody()['slug'], 'healthcare-facilities');
    });

    testWidgets('Proposals: what the member proposed, approved with a note', (tester) async {
      await pumpCouncils(tester, initialTab: 'proposals');
      expect(find.byKey(const ValueKey('proposals-tab')), findsOneWidget);
      expect(find.text('Data Centre Operations Council'), findsOneWidget);
      expect(find.text('Omar Sheikh · omar@gridline.in'), findsOneWidget);
      for (final label in ['Focus', 'Objectives', 'Why ICR needs it']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('Colocation'), findsOneWidget);

      await tapOnPage(tester, find.byKey(const ValueKey('request-approve-prop-1')));
      expect(
        find.text(
          'Approving creates the council unpublished with the member as lead: finish its page in the Councils '
          'tab, then publish it.',
        ),
        findsOneWidget,
      );
      await type(tester, 'decide.reason', 'Welcome aboard.');
      await save(tester);
      expect(repo.sent.last, {
        'action': 'decide',
        'kind': 'council',
        'id': 'prop-1',
        'decision': 'APPROVED',
        'reason': 'Welcome aboard.',
      });
      expect(find.text('Proposal approved.'), findsOneWidget);
      expect(find.text('No council proposals here'), findsOneWidget);
    });
  });
}
