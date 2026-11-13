import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/site/about_screen.dart';

import 'helpers/fonts.dart';

/// The website's About page, drawn by the app (7 Nov 2026: Saathi's "About ICR" opened the website in the web
/// view, and Back from it showed `/robots.txt`).
void main() {
  setUpAll(loadAppFonts);

  Future<List<String>> pump(WidgetTester tester, {bool signedIn = true}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final opened = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: AboutScreen(signedIn: signedIn, onOpenPage: (_, href) => opened.add(href)),
      ),
    );
    await tester.pump();
    return opened;
  }

  testWidgets("draws the website's sections in its words, on white, with no cards", (tester) async {
    await pump(tester);
    expect(find.text('About ICR'), findsOneWidget);
    expect(find.text('Institute for Corporate Real Estate (ICR)'), findsOneWidget);
    expect(find.text('Shaping the Future of Corporate Real Estate, Workplace & Facility Management'), findsOneWidget);
    expect(find.byKey(const ValueKey('about-stats')), findsOneWidget);
    expect(find.text('10,000+'), findsOneWidget);
    expect(find.text('businesses on ICR'), findsOneWidget);
    expect(find.text('WHO WE ARE'), findsOneWidget);
    expect(find.text('A Global Professional Association for the Built Workplace'), findsOneWidget);
    expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, Colors.white);
    expect(find.byType(Card), findsNothing);
    // Signed in, the page offers no sign-up.
    expect(find.byKey(const ValueKey('about-join')), findsNothing);
    expect(find.byKey(const ValueKey('about-create-account')), findsNothing);
  });

  testWidgets('"Explore the Ecosystem" scrolls to the nine modules, and each opens its page in the app', (
    tester,
  ) async {
    final opened = await pump(tester);
    await tester.tap(find.byKey(const ValueKey('about-explore')));
    await tester.pumpAndSettle();
    expect(find.text('One Integrated Ecosystem'), findsOneWidget);
    expect(aboutModules.map((m) => m.label), [
      'Mentorship',
      'Jobs',
      'Marketplace',
      'Community',
      'Documents',
      'Learning',
      'Chapters & Councils',
      'Events',
      'Get Involved',
    ]);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('about-module-/learning')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('about-module-/learning')));
    expect(opened, ['/learning']);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('about-talk')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('about-talk')));
    expect(opened, ['/learning', '/contact']);
  });

  testWidgets('signed out, it offers to join as the website does', (tester) async {
    final opened = await pump(tester, signedIn: false);
    await tester.tap(find.byKey(const ValueKey('about-join')));
    expect(opened, ['/register']);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('about-create-account')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('about-create-account')));
    expect(opened, ['/register', '/register']);
  });
}
