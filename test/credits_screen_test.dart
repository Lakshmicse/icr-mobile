import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/features/site/credits_screen.dart';
import 'package:provider/provider.dart';

import 'helpers/fonts.dart';
import 'mentoring_fakes.dart';

/// Credits & redemptions (the website's `/refer/credits`): the balance, then Redemptions, Credits earned and Referred
/// and Joined as tabs, as the website has them (owner, 5 Nov 2026: "like the tabs, not the vertical scrolling").
void main() {
  setUpAll(loadAppFonts);

  final history = {
    'balances': [
      {'kind': 'ICR_CREDIT', 'granted': 50, 'used': 30, 'remaining': 20, 'expired': 0},
    ],
    'redeemed': [
      {
        'kind': 'ICR_CREDIT',
        'quantity': 20,
        'at': '2026-10-29T06:00:00.000Z',
        'spentOn': 'PAPER',
        'paper': {
          'kind': 'ASSESSMENT',
          'title': 'Foundation',
          'parentTitle': 'Colloboration',
          'courseCode': 'COL',
          'slug': 'foundation',
        },
      },
      {
        'kind': 'ICR_CREDIT',
        'quantity': 5,
        'at': '2026-10-23T06:00:00.000Z',
        'spentOn': 'PAPER',
        'paper': {
          'kind': 'MOCK',
          'title': 'Set 1',
          'parentTitle': 'AEE CBCP',
          'topicSlug': 'aee-cbcp',
          'slug': 'set-1',
        },
      },
    ],
    'earned': [
      {
        'kind': 'ICR_CREDIT',
        'quantity': 20,
        'source': 'ADMIN',
        'reason': 'Special occasion — Deepavali',
        'at': '2026-10-28T06:00:00.000Z',
        'expiresAt': '2026-11-16T00:00:00.000Z',
      },
    ],
    'invites': <Object>[],
  };

  Future<List<String>> pump(WidgetTester tester) async {
    phone(tester);
    final api = FakeApi({'GET /referrals/me/credits': (_) => history});
    await tester.pumpWidget(
      Provider<ApiClient>.value(
        value: api.client(),
        child: const MaterialApp(home: CreditsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return launches(tester);
  }

  testWidgets('the three lists are tabs with their counts; Redemptions is open first', (tester) async {
    await pump(tester);
    expect(find.text('Redemptions (2)'), findsOneWidget);
    expect(find.text('Credits earned (1)'), findsOneWidget);
    expect(find.text('Referred and Joined (0)'), findsOneWidget);
    expect(find.text('REDEMPTIONS (2)'), findsNothing, reason: 'no stacked section headings any more');
    // Redemptions, captioned as the website does, with the credit as one phrase.
    expect(find.text('Opened the assessment'), findsOneWidget);
    expect(find.text('Opened the mock exam'), findsOneWidget);
    expect(find.text('Colloboration – Foundation'), findsOneWidget);
    expect(find.textContaining('20 ICR credits · Redeemed'), findsOneWidget);
    expect(find.textContaining('Deepavali'), findsNothing, reason: 'Credits earned is another tab');
  });

  testWidgets('a tab shows its own list', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('credits-tab-1')));
    await tester.pumpAndSettle();
    expect(find.text('Added by ICR: Special occasion — Deepavali'), findsOneWidget);
    expect(find.text('Opened the assessment'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('credits-tab-2')));
    await tester.pumpAndSettle();
    expect(
      find.text('Nobody has joined through your invite yet. Share your link from Refer a friend.'),
      findsOneWidget,
    );
  });

  testWidgets('a redeemed paper opens its page, as the website links it', (tester) async {
    final urls = await pump(tester);
    await tester.tap(find.text('Colloboration – Foundation'));
    await tester.pumpAndSettle();
    expect(urls.single, endsWith('/learning/assessment/col/foundation'));
  });
}
