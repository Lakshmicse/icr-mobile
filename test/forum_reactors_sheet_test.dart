import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/feed/feed_models.dart';
import 'package:icr_mobile/features/forum/forum_models.dart';
import 'package:icr_mobile/features/forum/widgets/forum_sheets.dart';

import 'helpers/fonts.dart';

void main() {
  setUpAll(loadAppFonts);
  // Who reacted, as the owner's reference draws it (13 Nov 2026): tabs with counts, then the people.
  testWidgets('tabs: All with its count, then each reaction given; a tab narrows the people to that reaction', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(780, 1500);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    ForumReactor r(String n, String h, ReactionKind k) => ForumReactor(
      person: FeedAuthor(id: n, name: n, headline: h),
      reaction: k,
      at: DateTime(2026, 11, 13),
    );
    final people = [
      r(
        'Devvrat Rajgopal',
        'VP ANSR | RE Acquisition | Leasing | Asset Mgmt | CoUP, Ex Strata, Embassy REIT, Cushman',
        ReactionKind.like,
      ),
      r(
        'Robbi Rajasekharam',
        'CEO at KPI Green Hydrogen, leading sustainable energy transition efforts.',
        ReactionKind.like,
      ),
      r('Rahul George', 'Co-Founder | Fragrances @ ARI Fragrances', ReactionKind.celebrate),
      r('Venkatesh Jaggumantry', 'Director @ Cushman and Wakefield', ReactionKind.support),
      r('GuruRaja Kumar BV, FMP', 'Associate Director at LTIMindtree', ReactionKind.like),
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          backgroundColor: Colors.grey,
          body: Builder(
            builder: (c) => Center(
              child: TextButton(
                onPressed: () => showReactorsSheet(c, load: () async => people),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('All 5'), findsOneWidget);
    expect(find.byKey(const ValueKey('reactors-tab:like')), findsOneWidget);
    expect(find.byKey(const ValueKey('reactors-tab:insightful')), findsNothing, reason: 'nobody gave it');
    expect(find.text('Devvrat Rajgopal'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('reactors-tab:celebrate')));
    await tester.pumpAndSettle();
    expect(find.text('Rahul George'), findsOneWidget);
    expect(find.text('Devvrat Rajgopal'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('reactors-tab:all')));
    await tester.pumpAndSettle();
    expect(find.text('Devvrat Rajgopal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // Owner, 14 Nov 2026: with two people the sheet opened as a sliver and its last row sat under the phone's
  // navigation bar. It opens at three quarters of the screen whatever the count, and the list ends above the bar.
  testWidgets('opens tall with a short list; the last row stays clear of the navigation bar', (tester) async {
    tester.view.physicalSize = const Size(780, 1500); // 390 x 750 dp
    tester.view.devicePixelRatio = 2;
    tester.view.viewPadding = const FakeViewPadding(bottom: 96); // a 48 dp three-button bar
    tester.view.padding = const FakeViewPadding(bottom: 96);
    addTearDown(tester.view.reset);
    List<ForumReactor> people(int n) => [
      for (var i = 0; i < n; i++)
        ForumReactor(
          person: FeedAuthor(id: 'p$i', name: 'Person $i', headline: 'Facility Manager'),
          reaction: i.isEven ? ReactionKind.like : ReactionKind.celebrate,
          at: DateTime(2026, 11, 14),
        ),
    ];
    var shown = people(2);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Builder(
            builder: (c) => Center(
              child: TextButton(
                onPressed: () => showReactorsSheet(c, load: () async => shown),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final list = tester.getRect(find.byKey(const ValueKey('reactors-list')));
    expect(tester.getTopLeft(find.text('All 2')).dy, lessThan(750 * 0.35), reason: 'three quarters of the screen');
    expect(list.bottom, closeTo(750, 1), reason: 'the sheet runs to the foot of the screen');

    Navigator.of(tester.element(find.text('All 2'))).pop();
    await tester.pumpAndSettle();
    shown = people(30);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.fling(find.byKey(const ValueKey('reactors-list')), const Offset(0, -4000), 3000);
    await tester.pumpAndSettle();
    final last = tester.getRect(find.ancestor(of: find.text('Person 29'), matching: find.byType(InkWell)).first);
    expect(last.bottom, lessThanOrEqualTo(750 - 48 - 24 + 0.5), reason: 'the bar and a gap under the last row');
    expect(tester.takeException(), isNull);
  });
}
