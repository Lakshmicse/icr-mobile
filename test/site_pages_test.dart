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
    testWidgets('a company administrator sends the areas, proposal and accreditation, and is told it was sent', (
      tester,
    ) async {
      final repo = _Partner([const PartnerCompany(id: 'c1', name: 'Northwind Facilities')]);
      await pump(tester, PartnerApplyScreen(repository: repo));
      await tester.pumpAndSettle();
      expect(find.text('Northwind Facilities'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), 'HVAC, Fire safety, Energy audits');
      await tester.enterText(find.byType(TextField).at(1), 'Weekend batches for site engineers');
      await tester.enterText(find.byType(TextField).at(2), 'NSDC affiliated');
      await tester.tap(find.byKey(const Key('partner.send')));
      await tester.pumpAndSettle();
      expect(repo.sent.single['companyId'], 'c1');
      expect(repo.sent.single['courseAreas'], ['HVAC', 'Fire safety', 'Energy audits']);
      expect(repo.sent.single['proposalNotes'], 'Weekend batches for site engineers');
      expect(repo.sent.single['accreditation'], 'NSDC affiliated');
      expect(find.textContaining('Application sent'), findsWidgets);
      expect(find.byKey(const Key('partner.send')), findsNothing, reason: 'it cannot be sent twice');
    });

    testWidgets('the API\'s refusal is shown in the form and nothing is lost', (tester) async {
      final repo = _Partner([const PartnerCompany(id: 'c1', name: 'Northwind')])
        ..refusal = 'Only a company administrator may apply.';
      await pump(tester, PartnerApplyScreen(repository: repo));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'HVAC');
      await tester.tap(find.byKey(const Key('partner.send')));
      await tester.pumpAndSettle();
      expect(find.text('Only a company administrator may apply.'), findsOneWidget);
      expect(find.byKey(const Key('partner.send')), findsOneWidget);
    });

    testWidgets('a member with no company is asked to create one', (tester) async {
      var created = 0;
      await pump(tester, PartnerApplyScreen(repository: _Partner(const []), onCreateCompany: () => created++));
      await tester.pumpAndSettle();
      expect(find.text('A partner is a company'), findsOneWidget);
      await tester.tap(find.text('Create a company'));
      expect(created, 1);
    });

    testWidgets('a company that is already a partner, or has an application under review, says so', (tester) async {
      await pump(
        tester,
        PartnerApplyScreen(
          repository: _Partner([const PartnerCompany(id: 'c1', name: 'Northwind', applicationStatus: 'PENDING')]),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('being reviewed'), findsOneWidget);
      expect(find.byKey(const Key('partner.send')), findsNothing);
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
  _Partner(this._companies);

  final List<PartnerCompany> _companies;
  final sent = <Map<String, Object?>>[];
  String? refusal;

  @override
  Future<List<PartnerCompany>> companies() async => _companies;

  @override
  Future<void> apply({
    required String companyId,
    required List<String> courseAreas,
    String? proposalNotes,
    String? accreditation,
  }) async {
    if (refusal != null) throw ApiError(refusal!);
    sent.add({
      'companyId': companyId,
      'courseAreas': courseAreas,
      'proposalNotes': proposalNotes,
      'accreditation': accreditation,
    });
  }
}
