import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/site/advertise_screen.dart';
import 'package:icr_mobile/features/site/blog_screens.dart';
import 'package:icr_mobile/features/site/html_view.dart';
import 'package:icr_mobile/features/site/legal_page.dart';
import 'package:icr_mobile/features/site/legal_page_screen.dart';
import 'package:icr_mobile/features/site/partner_apply_screen.dart';
import 'package:icr_mobile/features/site/refer_screen.dart';

import 'helpers/fonts.dart';

/// The website's small pages, drawn by the app itself: nothing here reaches a web view or the browser.
void main() {
  setUpAll(loadAppFonts);

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(780, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, theme: buildAppTheme(), home: screen));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  group('the legal pages (bundled from the website\'s own source)', () {
    test('both are there, with their sections, and the privacy policy has its lawful-basis table', () async {
      final terms = await loadLegalPage('terms');
      final privacy = await loadLegalPage('privacy');
      expect(terms.title, 'Terms of Service');
      expect(terms.sections.length, greaterThanOrEqualTo(10));
      expect(terms.contactEmail, contains('@'));
      expect(privacy.title, 'Privacy Policy');
      expect(privacy.updated, isNotEmpty);
      final tables = [
        for (final s in privacy.sections) ...[
          if (s.table != null) s.table,
          for (final sub in s.subsections)
            if (sub.table != null) sub.table,
        ],
      ];
      expect(tables, isNotEmpty, reason: 'the website draws a table; so does the app');
      expect(tables.first!.rows.first.length, tables.first!.columns.length);
    });

    testWidgets('Terms draw as a title, the date, the introduction and numbered sections', (tester) async {
      // The asset is read on the real clock, outside the test's fake one.
      final terms = (await tester.runAsync(() => loadLegalPage('terms')))!;
      await pump(tester, LegalPageScreen(page: 'terms', load: (_) async => terms));
      await tester.pumpAndSettle();
      expect(find.text('Terms of Service'), findsWidgets);
      expect(find.textContaining('Last updated'), findsOneWidget);
      expect(find.textContaining('1. Agreement to these terms'), findsOneWidget);
      expect(find.byKey(const Key('legal.contact')), findsNothing, reason: 'the contact line is at the foot');
      await tester.dragUntilVisible(
        find.byKey(const Key('legal.contact')),
        find.byKey(const Key('legal.body')),
        const Offset(0, -400),
      );
      expect(find.byKey(const Key('legal.contact')), findsOneWidget);
    });

    testWidgets('while it reads it shows the app\'s own spinner, and a failure offers to try again', (tester) async {
      var tries = 0;
      final privacy = (await tester.runAsync(() => loadLegalPage('privacy')))!;
      await pump(
        tester,
        LegalPageScreen(
          page: 'privacy',
          load: (page) async {
            tries++;
            if (tries == 1) throw Exception('gone');
            return privacy;
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text("This page couldn't be read."), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('legal.body')), findsOneWidget);
      expect(tries, 2);
    });
  });

  group('HtmlView (a blog post\'s body)', () {
    test('reads paragraphs, headings, lists, quotes, links, bold and pictures', () {
      final blocks = parseHtml(
        '<h2>Title</h2><p>One <strong>bold</strong> and <em>soft</em> <a href="/jobs">link</a>.</p>'
        '<ul><li>a</li><li>b</li></ul><ol><li>x</li></ol><blockquote><p>quote</p></blockquote>'
        '<img src="/uploads/p.png"/><script>alert(1)</script>',
      );
      expect(blocks.map((b) => b.kind), [
        HtmlBlockKind.heading,
        HtmlBlockKind.paragraph,
        HtmlBlockKind.listItem,
        HtmlBlockKind.listItem,
        HtmlBlockKind.listItem,
        HtmlBlockKind.quote,
        HtmlBlockKind.image,
      ]);
      expect(blocks[0].level, 2);
      final runs = blocks[1].inline;
      expect(runs.firstWhere((r) => r.text == 'bold').bold, isTrue);
      expect(runs.firstWhere((r) => r.text == 'soft').italic, isTrue);
      expect(runs.firstWhere((r) => r.text == 'link').href, '/jobs');
      expect(blocks[4].ordered, isTrue);
      expect(blocks[4].index, 1, reason: 'an ordered list is numbered from 1');
      expect(blocks.last.src, '/uploads/p.png');
    });

    test('a text with no tags is a paragraph per blank line', () {
      final blocks = parseHtml('ICR connects people.\n\nSecond paragraph.');
      expect(blocks.length, 2);
      expect(blocks.first.inline.single.text, 'ICR connects people.');
    });

    testWidgets('a link in the text hands its address to the screen', (tester) async {
      final links = <String>[];
      await pump(
        tester,
        Scaffold(
          body: HtmlView(html: '<p>Read <a href="/blogs/x">this</a>.</p>', onLink: links.add),
        ),
      );
      TextSpan? link;
      for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
        rich.text.visitChildren((span) {
          if (span is TextSpan && span.text == 'this') link = span;
          return true;
        });
      }
      expect(link, isNotNull);
      (link!.recognizer! as TapGestureRecognizer).onTap!();
      expect(links, ['/blogs/x']);
    });
  });

  group('the blog', () {
    final repo = _Blog();

    testWidgets('the list shows each post and opens one', (tester) async {
      BlogPost? opened;
      await pump(tester, BlogsScreen(repository: repo, onOpenPost: (p) => opened = p));
      await tester.pumpAndSettle();
      expect(find.text('Welcome to ICR'), findsOneWidget);
      expect(find.text('A second post'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('blog:welcome-to-icr')));
      expect(opened?.slug, 'welcome-to-icr');
    });

    testWidgets('a post draws its title, who wrote it and its body', (tester) async {
      await pump(tester, BlogPostScreen(slug: 'welcome-to-icr', repository: repo));
      await tester.pumpAndSettle();
      expect(find.text('Welcome to ICR'), findsWidgets);
      expect(find.textContaining('Super Admin'), findsOneWidget);
      expect(find.textContaining('ICR connects corporates'), findsOneWidget);
    });

    testWidgets('a post that cannot be read says so and can be tried again', (tester) async {
      await pump(tester, BlogPostScreen(slug: 'nope', repository: repo));
      await tester.pumpAndSettle();
      expect(find.text('Post not found'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('Invite (/refer)', () {
    final mine = const MyReferrals(
      code: 'Y9QTMANV',
      link: 'https://icr.org.in/register?ref=Y9QTM',
      shareText: 'Bharat Buyer is inviting you to join ICR',
      programme: 'Buyer invites a supplier',
      refereeReward: '1 free month',
      referrerReward: 'nothing extra (Once verified)',
      invited: 3,
      verified: 2,
      rewarded: 1,
      capPerYear: 12,
      usedThisYear: 1,
    );

    testWidgets(
      'shows the code, the rewards and the counts; Copy puts the code on the clipboard; Share hands the invitation over',
      (tester) async {
        var copied = '';
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
            return null;
          },
        );
        addTearDown(
          () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        final shared = <String>[];
        await pump(tester, ReferScreen(repository: _Refer(mine), share: (t) async => shared.add(t)));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('refer.code')), findsOneWidget);
        expect(find.text('Y9QTMANV'), findsOneWidget);
        expect(find.text('They get 1 free month'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
        expect(find.textContaining('1 of 12'), findsOneWidget);

        await tester.tap(find.byKey(const Key('refer.copy.code')));
        await tester.pump();
        expect(copied, 'Y9QTMANV');

        await tester.tap(find.text('Share invitation'));
        expect(shared.single, 'Bharat Buyer is inviting you to join ICR');
      },
    );
  });

  group('Advertise (/advertise)', () {
    testWidgets('describes both placements with the person\'s own price and opens the contact form for "Talk to us"', (
      tester,
    ) async {
      String? subject;
      await pump(
        tester,
        AdvertiseScreen(
          repository: _Advertise(
            AdvertiseData(
              offers: const [
                PlacementOffer(
                  sku: 'DIRECTORY',
                  title: 'Featured in Supplier Mart',
                  body: 'Ahead of other suppliers.',
                  monthlyPaisa: 200000,
                ),
                PlacementOffer(sku: 'HERO', title: 'Homepage hero', body: 'A banner in the hero.'),
              ],
              mine: [MyPlacement(label: 'Featured in Supplier Mart', status: 'ACTIVE', endsAt: DateTime(2026, 12, 1))],
            ),
          ),
          onTalk: (s) => subject = s,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Featured in Supplier Mart'), findsWidgets);
      expect(find.textContaining('₹2,000', findRichText: true), findsOneWidget);
      expect(find.textContaining('a month + GST', findRichText: true), findsOneWidget);
      expect(find.text('Homepage hero'), findsOneWidget);
      expect(find.textContaining('ACTIVE'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('talk:HERO')));
      expect(subject, 'Advertise: Homepage hero');
    });
  });

  group('Become a partner (/learning/partners/apply)', () {
    /// Scrolls to a control the form draws below the fold and taps it.
    Future<void> tapKey(WidgetTester tester, Key key) async {
      await tester.ensureVisible(find.byKey(key));
      await tester.pump();
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
    }

    testWidgets('a company administrator says what courses they would offer, and is told the application is with ICR', (
      tester,
    ) async {
      final repo = _Partner([const PartnerCompany(id: 'c1', name: 'Northwind Facilities')]);
      await pump(tester, PartnerApplyScreen(repository: repo));
      await tester.pumpAndSettle();
      // The website's dialog: its title and introduction, the company to apply as, and one optional box.
      expect(find.text('Apply to become a learning partner'), findsOneWidget);
      expect(find.textContaining('Partners apply as a company.'), findsOneWidget);
      expect(find.text('Apply as'), findsOneWidget);
      expect(find.text('Northwind Facilities'), findsOneWidget);
      expect(find.text('Only companies you are an admin of are listed.'), findsOneWidget);
      expect(find.text('What courses would you like to offer? (optional)'), findsOneWidget);
      expect(find.text('Subjects, accreditations, the courses you run today…'), findsOneWidget);
      expect(
        find.byType(TextField),
        findsOneWidget,
        reason: 'the website asks the notes alone, no areas or accreditation',
      );
      await tester.enterText(find.byType(TextField), '  Weekend batches for site engineers  ');
      await tapKey(tester, const Key('partner.send'));
      expect(repo.sent.single, {'companyId': 'c1', 'proposalNotes': 'Weekend batches for site engineers'});
      // The sent state, in the website's words.
      expect(find.text('Application sent'), findsOneWidget);
      expect(find.text("Northwind Facilities's application is with ICR."), findsOneWidget);
      expect(find.textContaining('Our team reviews every application by hand.'), findsOneWidget);
      expect(find.text('Go to dashboard'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      expect(find.byKey(const Key('partner.send')), findsNothing, reason: 'it cannot be sent twice');
    });

    testWidgets('the notes are optional: nothing written, only the company is sent', (tester) async {
      final repo = _Partner([const PartnerCompany(id: 'c1', name: 'Northwind')]);
      await pump(tester, PartnerApplyScreen(repository: repo));
      await tester.pumpAndSettle();
      await tapKey(tester, const Key('partner.send'));
      expect(repo.sent.single['companyId'], 'c1');
      expect(repo.sent.single['proposalNotes'], isNull);
    });

    testWidgets('the notes take no more than the API keeps (4,000 characters), as the website cuts them', (
      tester,
    ) async {
      await pump(
        tester,
        PartnerApplyScreen(
          repository: _Partner([const PartnerCompany(id: 'c1', name: 'Northwind')]),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'a' * 4100);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text.length, 4000);
    });

    testWidgets("the API's refusal is shown under the form and nothing is lost", (tester) async {
      final repo = _Partner([const PartnerCompany(id: 'c1', name: 'Northwind')])
        ..refusal = 'Northwind already has an application with our team.';
      await pump(tester, PartnerApplyScreen(repository: repo));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'HVAC');
      await tapKey(tester, const Key('partner.send'));
      expect(find.text('Northwind already has an application with our team.'), findsOneWidget);
      expect(find.byKey(const Key('partner.send')), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'HVAC');
    });

    testWidgets('a failure the API gave no sentence for reads "Could not send the application."', (tester) async {
      final repo = _Partner([const PartnerCompany(id: 'c1', name: 'Northwind')])..crash = true;
      await pump(tester, PartnerApplyScreen(repository: repo));
      await tester.pumpAndSettle();
      await tapKey(tester, const Key('partner.send'));
      expect(find.text('Could not send the application.'), findsOneWidget);
    });

    testWidgets("a failed read of the companies says so in the website's sentence, and Try again reads them again", (
      tester,
    ) async {
      final repo = _Partner([const PartnerCompany(id: 'c1', name: 'Northwind')])..readFails = true;
      await pump(tester, PartnerApplyScreen(repository: repo));
      await tester.pumpAndSettle();
      expect(find.text('Could not load your companies. Try again in a moment.'), findsOneWidget);
      repo.readFails = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Northwind'), findsOneWidget);
    });

    testWidgets("a member with no company is told so, in the website's words, and asked to register one", (
      tester,
    ) async {
      var created = 0;
      await pump(tester, PartnerApplyScreen(repository: _Partner(const []), onCreateCompany: () => created++));
      await tester.pumpAndSettle();
      expect(find.text('Apply to become a learning partner'), findsOneWidget);
      expect(
        find.text('You are not an admin of any company on ICR yet. Register your company to apply.'),
        findsOneWidget,
        reason: "the website's note",
      );
      expect(find.byType(TextField), findsNothing, reason: 'the website shows no box until a company is listed');
      await tester.tap(find.text('Register a new company'));
      await tester.pumpAndSettle();
      expect(created, 1);
    });

    testWidgets('registering a company reads the list again, so the new company is there to apply as', (tester) async {
      final repo = _Partner(const []);
      await pump(
        tester,
        PartnerApplyScreen(
          repository: repo,
          onCreateCompany: () async =>
              repo.companiesList = [const PartnerCompany(id: 'new', name: 'Fresh Co', active: true)],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('partner.register')));
      await tester.pumpAndSettle();
      expect(find.text('Fresh Co'), findsOneWidget);
      await tapKey(tester, const Key('partner.send'));
      expect(repo.sent.single['companyId'], 'new');
    });

    testWidgets('opens on the first company that can apply, not on a partner (no "already a learning partner" wall)', (
      tester,
    ) async {
      final repo = _Partner([
        const PartnerCompany(id: 'c1', name: 'Skystar', providerName: 'Skystar'),
        const PartnerCompany(id: 'c2', name: 'Northwind'),
      ]);
      await pump(tester, PartnerApplyScreen(repository: repo));
      await tester.pumpAndSettle();
      expect(find.textContaining('already a learning partner'), findsNothing);
      expect(find.byKey(const Key('partner.send')), findsOneWidget);
      await tapKey(tester, const Key('partner.send'));
      expect(repo.sent.single['companyId'], 'c2');
    });

    testWidgets('prefers the company being acted for, and any eligible one can be picked', (tester) async {
      final repo = _Partner([
        const PartnerCompany(id: 'c1', name: 'First Co'),
        const PartnerCompany(id: 'c2', name: 'Acting Co', active: true),
        const PartnerCompany(id: 'c3', name: 'Third Co'),
      ]);
      await pump(tester, PartnerApplyScreen(repository: repo));
      await tester.pumpAndSettle();
      await tapKey(tester, const Key('partner.send'));
      expect(repo.sent.single['companyId'], 'c2');

      final other = _Partner([
        const PartnerCompany(id: 'c1', name: 'First Co'),
        const PartnerCompany(id: 'c3', name: 'Third Co'),
      ]);
      await tester.pumpWidget(const SizedBox());
      await pump(tester, PartnerApplyScreen(repository: other));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('partner.company.c3')));
      await tester.pumpAndSettle();
      await tapKey(tester, const Key('partner.send'));
      expect(other.sent.single['companyId'], 'c3');
    });

    testWidgets('the acting company is skipped when it cannot apply', (tester) async {
      final repo = _Partner([
        const PartnerCompany(id: 'c1', name: 'First Co'),
        const PartnerCompany(id: 'c2', name: 'Acting Co', active: true, providerName: 'Acting Academy'),
      ]);
      await pump(tester, PartnerApplyScreen(repository: repo));
      await tester.pumpAndSettle();
      await tapKey(tester, const Key('partner.send'));
      expect(repo.sent.single['companyId'], 'c1');
    });

    testWidgets('a partner and a company with its application at ICR are listed, marked, and cannot be picked', (
      tester,
    ) async {
      final repo = _Partner([
        const PartnerCompany(id: 'c1', name: 'Skystar', providerName: 'Skystar'),
        const PartnerCompany(id: 'c2', name: 'Northwind', applicationStatus: 'PENDING'),
        const PartnerCompany(id: 'c3', name: 'Reviewing Co', applicationStatus: 'UNDER_REVIEW'),
        const PartnerCompany(id: 'c4', name: 'Open Co', applicationStatus: 'REJECTED', reviewNote: 'Add detail.'),
      ]);
      await pump(tester, PartnerApplyScreen(repository: repo));
      await tester.pumpAndSettle();
      expect(find.text('Partner'), findsOneWidget);
      expect(find.text('With ICR'), findsNWidgets(2), reason: "PENDING and UNDER_REVIEW are the API's waiting states");
      expect(find.text('Declined'), findsOneWidget);
      // The form is for Open Co, the one that can apply (its last application was declined), with ICR's note.
      expect(find.text('Add detail.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('partner.company.c1')));
      await tester.tap(find.byKey(const Key('partner.company.c2')));
      await tester.tap(find.byKey(const Key('partner.company.c3')));
      await tapKey(tester, const Key('partner.send'));
      expect(repo.sent.single['companyId'], 'c4');
    });

    testWidgets("a company ICR asked for more of can apply again, and ICR's note is shown", (tester) async {
      final repo = _Partner([
        const PartnerCompany(
          id: 'c1',
          name: 'Asked Co',
          applicationStatus: 'INFO_REQUESTED',
          reviewNote: 'Send your accreditation.',
        ),
      ]);
      await pump(tester, PartnerApplyScreen(repository: repo));
      await tester.pumpAndSettle();
      expect(find.text('More info requested'), findsOneWidget);
      expect(find.text('Send your accreditation.'), findsOneWidget);
      await tapKey(tester, const Key('partner.send'));
      expect(repo.sent.single['companyId'], 'c1');
    });

    testWidgets('with every company a partner or at ICR the list says so and Submit stays off, as in the website', (
      tester,
    ) async {
      final repo = _Partner([
        const PartnerCompany(id: 'c1', name: 'Skystar', providerName: 'Skystar'),
        const PartnerCompany(id: 'c2', name: 'Northwind', applicationStatus: 'UNDER_REVIEW'),
      ]);
      await pump(tester, PartnerApplyScreen(repository: repo));
      await tester.pumpAndSettle();
      expect(find.text('Skystar'), findsOneWidget);
      expect(find.text('Northwind'), findsOneWidget);
      expect(find.textContaining('already a learning partner'), findsNothing);
      expect(find.byType(TextField), findsOneWidget, reason: 'the website still draws its notes box');
      await tester.ensureVisible(find.byKey(const Key('partner.send')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('partner.send')), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(repo.sent, isEmpty);
    });

    testWidgets('Close leaves the page', (tester) async {
      var backs = 0;
      await pump(
        tester,
        PartnerApplyScreen(
          repository: _Partner([const PartnerCompany(id: 'c1', name: 'Northwind')]),
          onBack: () => backs++,
        ),
      );
      await tester.pumpAndSettle();
      await tapKey(tester, const Key('partner.send'));
      await tapKey(tester, const Key('partner.close'));
      expect(backs, 1);
    });

    test("waiting is the API's PENDING and UNDER_REVIEW, and other states are not", () {
      for (final status in ['PENDING', 'UNDER_REVIEW']) {
        expect(
          PartnerCompany(id: 'c', name: 'C', applicationStatus: status).pending,
          isTrue,
          reason: status,
        );
      }
      for (final status in ['SUBMITTED', 'IN_REVIEW', 'INFO_REQUESTED', 'REJECTED', 'APPROVED', null]) {
        expect(
          PartnerCompany(id: 'c', name: 'C', applicationStatus: status).pending,
          isFalse,
          reason: '$status',
        );
      }
      final json = PartnerCompany.fromJson({'companyId': 'c9', 'name': 'Nine', 'active': true});
      expect(json.active, isTrue);
      expect(defaultPartnerCompany([json])?.id, 'c9');
      expect(defaultPartnerCompany([PartnerCompany(id: 'c', name: 'C', providerName: 'C')]), isNull);
    });

    test("the chip words are the website's", () {
      String? chip(Map<String, dynamic> json) =>
          PartnerCompany.fromJson({'companyId': 'c', 'name': 'C', ...json}).statusLabel;
      expect(
        chip({
          'provider': {'name': 'C'},
        }),
        'Partner',
      );
      expect(
        chip({
          'application': {'status': 'PENDING'},
        }),
        'With ICR',
      );
      expect(
        chip({
          'application': {'status': 'UNDER_REVIEW'},
        }),
        'With ICR',
      );
      expect(
        chip({
          'application': {'status': 'INFO_REQUESTED'},
        }),
        'More info requested',
      );
      expect(
        chip({
          'application': {'status': 'REJECTED'},
        }),
        'Declined',
      );
      expect(chip({}), isNull);
    });
  });
}

class _Blog implements BlogRepository {
  final _posts = [
    BlogPost(
      slug: 'welcome-to-icr',
      title: 'Welcome to ICR',
      excerpt: 'India\'s largest FM ecosystem.',
      content: '<p>ICR connects corporates, vendors and professionals.</p>',
      cover: null,
      author: 'Super Admin',
      publishedAt: DateTime(2026, 10, 1),
    ),
    BlogPost(
      slug: 'second',
      title: 'A second post',
      excerpt: 'More.',
      content: '',
      cover: null,
      author: 'ICR',
      publishedAt: null,
    ),
  ];

  @override
  Future<List<BlogPost>> posts({int page = 1}) async => _posts;

  @override
  Future<BlogPost> post(String slug) async {
    final found = _posts.where((p) => p.slug == slug);
    if (found.isEmpty) throw ApiError('Post not found');
    return found.first;
  }
}

class _Refer implements ReferralsRepository {
  _Refer(this._mine);

  final MyReferrals _mine;

  @override
  Future<MyReferrals> mine() async => _mine;
}

class _Advertise implements AdvertiseRepository {
  _Advertise(this._data);

  final AdvertiseData _data;

  @override
  Future<AdvertiseData> read() async => _data;
}

class _Partner implements PartnerApplyRepository {
  _Partner(this.companiesList);

  List<PartnerCompany> companiesList;
  final sent = <Map<String, Object?>>[];
  String? refusal;

  /// An error that is no `ApiError` (nothing the app could word).
  bool crash = false;

  /// The read of the companies fails with an `ApiError`.
  bool readFails = false;

  @override
  Future<List<PartnerCompany>> companies() async {
    if (readFails) throw ApiError('The companies are down.');
    return companiesList;
  }

  @override
  Future<void> apply({required String companyId, String? proposalNotes}) async {
    if (refusal != null) throw ApiError(refusal!);
    if (crash) throw StateError('boom');
    sent.add({'companyId': companyId, 'proposalNotes': proposalNotes});
  }
}
