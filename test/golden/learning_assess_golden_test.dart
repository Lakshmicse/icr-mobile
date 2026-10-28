@Tags(['golden'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/learning_assess/assess_models.dart';
import 'package:icr_mobile/features/learning_assess/assessment_screen.dart';
import 'package:icr_mobile/features/learning_assess/mock_tests_screen.dart';
import 'package:icr_mobile/features/shell/shell_page.dart';

import '../helpers/assess_fixtures.dart';
import '../helpers/fonts.dart';

const _tower = FeedPicture.asset('assets/images/demo/post_green_tower.jpg');
const _roof = FeedPicture.asset('assets/images/demo/post_rooftop_hvac.jpg');
const _control = FeedPicture.asset('assets/images/demo/post_control_room.jpg');

/// Every programme with a different cover, so the grid reads as the live one does.
List<PaperGroup> _programmes() {
  final covers = [_tower, _roof, _control, _tower];
  final world = assessWorld();
  return [
    for (final (i, g) in world.indexed)
      PaperGroup(
        kind: g.kind,
        id: g.id,
        key: g.key,
        title: g.title,
        summary: g.summary,
        cover: i < 4 ? covers[i] : null,
        knowledgeAreas: g.knowledgeAreas,
        papers: g.papers,
        sortOrder: g.sortOrder,
        partner: g.partner,
      ),
  ];
}

List<PaperGroup> _topics() {
  final covers = [_control, _tower, _roof];
  final world = mockWorld();
  return [
    for (final (i, g) in world.indexed)
      PaperGroup(
        kind: g.kind,
        id: g.id,
        key: g.key,
        title: g.title,
        summary: g.summary,
        cover: covers[i],
        papers: g.papers,
      ),
  ];
}

/// What Bharat Buyer has done: the Advanced Capital Planning level opened with credits and passed (with its
/// certificate), the Foundation one sat once and failed.
Map<String, PaperProgress> _progress() => {
  'cp-advanced': const PaperProgress(attempts: 2, bestPercent: 80, bestScore: 8, maxScore: 10, passed: true),
  'cp-foundation': const PaperProgress(attempts: 1, bestPercent: 40, bestScore: 4, maxScore: 10),
  'aee-cbcp-set-1': const PaperProgress(attempts: 3, bestPercent: 60, bestScore: 6, maxScore: 10),
};

FakeAssess _fake({
  MemberLearning? member,
  BundleQuote? bundle,
  AssessmentPricing pricing = const AssessmentPricing(),
  int unread = 1,
}) => FakeAssess(
  programmes: _programmes(),
  topics: _topics(),
  member:
      member ??
      assessMember(
        open: {'cp-advanced', 'cp-foundation', 'aee-cbcp-set-1'},
        redeemed: {'cp-advanced'},
        progress: _progress(),
        certified: {'cp-advanced'},
      ),
  bundle: bundle,
  pricingNow: pricing,
  unread: unread,
);

/// The Assess Your Knowledge and Mock Exams screens at 390 dp wide, exported at 2x to build/screens/.
void main() {
  setUpAll(loadAppFonts);

  // flutter_test draws every shadow as a hard-edged offset shape (debugDisableShadows), which hides the soft
  // ones the cards carry. Each test draws with real blur, and puts the flag back before it ends.
  void shadowedWidgets(String name, Future<void> Function(WidgetTester tester) body) {
    testWidgets(name, (tester) async {
      debugDisableShadows = false;
      try {
        await body(tester);
      } finally {
        debugDisableShadows = true;
      }
    });
  }

  Future<void> precacheAll(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element);
      }
    });
    await tester.pumpAndSettle();
  }

  Future<void> export(WidgetTester tester, Finder finder, String name) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.ancestor(of: finder, matching: find.byType(RepaintBoundary)).first,
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('build/screens').createSync(recursive: true);
      File('build/screens/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  Future<void> pump(WidgetTester tester, Widget screen, double heightDp) async {
    tester.view.physicalSize = Size(780, heightDp * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, theme: buildAppTheme(), home: screen));
    await tester.pumpAndSettle();
    await precacheAll(tester);
  }

  Future<void> openGroup(WidgetTester tester, String title) async {
    await tester.tap(find.text(title).first);
    await tester.pumpAndSettle();
    await precacheAll(tester);
  }

  AssessmentScreen assessment(FakeAssess fake) => AssessmentScreen(
    onBack: () {},
    repository: fake,
    opener: RecordingOpener().call,
    launcher: RecordingLauncher().call,
  );

  MockTestsScreen mock(FakeAssess fake) => MockTestsScreen(
    onBack: () {},
    repository: fake,
    opener: RecordingOpener().call,
    launcher: RecordingLauncher().call,
  );

  shadowedWidgets('Assess Your Knowledge: the programmes, at 390 × 1180', (tester) async {
    await pump(tester, assessment(_fake()), 1180);
    await export(tester, find.byType(AssessmentScreen), 'learning_assess_programmes');
    await expectLater(find.byType(AssessmentScreen), matchesGoldenFile('goldens/learning_assess_programmes.png'));
  });

  shadowedWidgets('Assess Your Knowledge: Capital Planning (a level passed and certified, one failed), at 390 × 2300', (
    tester,
  ) async {
    await pump(tester, assessment(_fake()), 2300);
    await openGroup(tester, 'Capital Planning');
    await export(tester, find.byType(ShellPage).last, 'learning_assess_levels_capital');
    await expectLater(find.byType(ShellPage).last, matchesGoldenFile('goldens/learning_assess_levels_capital.png'));
  });

  shadowedWidgets('Assess Your Knowledge: Contract Management (every level priced, a bundle, a sale), at 390 × 2900', (
    tester,
  ) async {
    final fake = _fake(
      member: assessMember(open: {}, redeemed: {}),
      pricing: const AssessmentPricing(discountPercent: 20, bundleDiscountPercent: 30),
      bundle: const BundleQuote(
        courseCode: 'CM',
        offered: true,
        payable: true,
        programmeTitle: 'Contract Management',
        levels: ['Foundation', 'Professional', 'Advanced'],
        separateSalePaisa: 183760,
        salePaisa: 160790,
        savePaisa: 22970,
        discountBps: 3000,
      ),
    );
    fake.quotes = {
      for (final e in fake.quotes.entries)
        e.key: e.value.priced
            ? PaperQuote(
                paperId: e.key,
                listPaisa: e.value.listPaisa,
                discountBps: 2000,
                discountPaisa: (e.value.listPaisa * 0.2).round(),
                salePaisa: e.value.listPaisa - (e.value.listPaisa * 0.2).round(),
                taxBps: 1800,
                payable: true,
                credits: e.value.credits,
              )
            : e.value,
    };
    await pump(tester, assessment(fake), 2900);
    await openGroup(tester, 'Contract Management');
    await export(tester, find.byType(ShellPage).last, 'learning_assess_levels_priced');
    await expectLater(find.byType(ShellPage).last, matchesGoldenFile('goldens/learning_assess_levels_priced.png'));
  });

  shadowedWidgets('Assess Your Knowledge: a plan place free, at 390 × 1700', (tester) async {
    final fake = _fake(
      member: assessMember(
        open: {},
        redeemed: {},
        courses: const PlanPlaces(limit: 2, opened: ['course-pm']),
        upgradePlan: 'Pro Plus',
      ),
    );
    await pump(tester, assessment(fake), 1700);
    await openGroup(tester, 'Human Capital');
    await export(tester, find.byType(ShellPage).last, 'learning_assess_levels_plan');
    await expectLater(find.byType(ShellPage).last, matchesGoldenFile('goldens/learning_assess_levels_plan.png'));
  });

  shadowedWidgets('Mock Exams: the subjects, at 390 × 1000', (tester) async {
    await pump(tester, mock(_fake()), 1000);
    await export(tester, find.byType(MockTestsScreen), 'learning_assess_mock_topics');
    await expectLater(find.byType(MockTestsScreen), matchesGoldenFile('goldens/learning_assess_mock_topics.png'));
  });

  shadowedWidgets('Mock Exams: AEE CBCP (a set sat three times, a set locked), at 390 × 1500', (tester) async {
    await pump(tester, mock(_fake()), 1500);
    await openGroup(tester, 'AEE CBCP');
    await export(tester, find.byType(ShellPage).last, 'learning_assess_mock_sets');
    await expectLater(find.byType(ShellPage).last, matchesGoldenFile('goldens/learning_assess_mock_sets.png'));
  });

  shadowedWidgets('Mock Exams: AEE CBCP, both sets closed, the bundle in ICR credits above the sets, at 390 × 1900', (
    tester,
  ) async {
    final fake = _fake(
      member: assessMember(open: {}, redeemed: {}),
      bundle: const BundleQuote(
        courseCode: 'aee-cbcp',
        kind: PaperKind.mock,
        programmeTitle: 'AEE CBCP',
        credits: 5,
        separateCredits: 10,
        creditsSaved: 5,
        creditsOffered: true,
        creditLevels: [
          BundleLevel(paperId: 'aee-cbcp-set-1', title: 'Set 1', credits: 5),
          BundleLevel(paperId: 'aee-cbcp-set-2', title: 'Set 2', credits: 5),
        ],
      ),
    );
    await pump(tester, mock(fake), 1900);
    await openGroup(tester, 'AEE CBCP');
    await export(tester, find.byType(ShellPage).last, 'learning_assess_mock_bundle_credits');
    await expectLater(find.byType(ShellPage).last, matchesGoldenFile('goldens/learning_assess_mock_bundle_credits.png'));
  });

  shadowedWidgets('Assess Your Knowledge: Contract Management, the bundle in money and in credits, at 390 × 3100', (
    tester,
  ) async {
    final fake = _fake(
      member: assessMember(open: {}, redeemed: {}),
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
        offerEndsOn: '2026-12-31',
        credits: 13,
        separateCredits: 23,
        creditsSaved: 10,
        creditsOffered: true,
        creditLevels: [
          BundleLevel(paperId: 'cm-foundation', title: 'Foundation', credits: 5),
          BundleLevel(paperId: 'cm-intermediate', title: 'Professional', credits: 10),
          BundleLevel(paperId: 'cm-advanced', title: 'Advanced', credits: 8),
        ],
      ),
    );
    await pump(tester, assessment(fake), 3100);
    await openGroup(tester, 'Contract Management');
    await export(tester, find.byType(ShellPage).last, 'learning_assess_levels_bundle_both');
    await expectLater(find.byType(ShellPage).last, matchesGoldenFile('goldens/learning_assess_levels_bundle_both.png'));
  });

}
