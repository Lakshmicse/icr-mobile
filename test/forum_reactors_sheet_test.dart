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
}
