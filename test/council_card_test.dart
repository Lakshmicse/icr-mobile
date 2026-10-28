import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/councils/council_models.dart';
import 'package:icr_mobile/features/councils/widgets/council_card.dart';
import 'package:icr_mobile/features/councils/widgets/joined_council_card.dart';
import 'package:icr_mobile/features/councils/widgets/roundtable_row.dart';
import 'package:icr_mobile/features/councils/widgets/stat_tiles.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'helpers/fonts.dart';

Future<void> _pump(WidgetTester tester, Council council) => tester.pumpWidget(
  MaterialApp(
    theme: buildAppTheme(),
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: JoinedCouncilCard(council: council, onOpen: () {}),
      ),
    ),
  ),
);

/// A directory card at the design's 362 dp, with its five callbacks counted.
class _Taps {
  int join = 0;
  int leave = 0;
  int open = 0;
  int preview = 0;
}

Future<_Taps> _card(WidgetTester tester, Council council, {bool busy = false}) async {
  final taps = _Taps();
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 362,
            child: CouncilCard(
              council: council,
              busy: busy,
              onJoin: () => taps.join++,
              onLeave: () => taps.leave++,
              onOpen: () => taps.open++,
              onPreview: () => taps.preview++,
            ),
          ),
        ),
      ),
    ),
  );
  return taps;
}

const _chair = CouncilChair(name: 'Vikram Malhotra', title: 'Director ESG @ DLF');

Council _council({
  CouncilRole? role,
  String? badge,
  String? established,
  List<String> tags = const ['#NetZero', '#Decarbonization', '#Scope3'],
  int upcoming = 3,
  DateTime? next,
  int unread = 0,
}) => Council(
  id: 'c1',
  name: 'Sustainability, ESG & Net-Zero Council',
  slug: 'sustainability',
  description: 'Setting technical decarbonization benchmarks.',
  segments: const ['Net-Zero & ESG', 'NetZero'],
  tags: tags,
  memberCount: 642,
  upcomingEventCount: upcoming,
  activityLabel: upcoming == 0 ? null : '$upcoming Upcoming Events',
  chair: _chair,
  membership: role,
  badge: badge,
  established: established,
  nextEventAt: next ?? DateTime.utc(2027, 4, 18, 10),
  unread: unread,
);

void main() {
  setUpAll(loadAppFonts);

  testWidgets('the longest seat beside a "Next Sync" date fits the 210 dp card', (tester) async {
    await _pump(
      tester,
      Council(
        id: 'c1',
        name: 'CXO Workplace Strategy & FM Leadership',
        slug: 'cxo',
        description: 'Campus consolidation, hybrid occupancy calibrations & CapEx lifecycles.',
        membership: CouncilRole.lead,
        nextEventAt: DateTime(2026, 10, 30),
        memberCount: 169,
      ),
    );

    // An overflow is reported as an exception; there must be none.
    expect(tester.takeException(), isNull);
    expect(find.text('Next Sync: Oct 30'), findsOneWidget);
  });

  testWidgets('an unread count takes the place of the date, as in the design', (tester) async {
    await _pump(
      tester,
      Council(
        id: 'c2',
        name: 'Sustainability, ESG & Net-Zero Council',
        slug: 'esg',
        membership: CouncilRole.lead,
        nextEventAt: DateTime(2026, 10, 30),
        unread: 3,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('3 unread'), findsOneWidget);
    expect(find.textContaining('Next Sync'), findsNothing);
  });

  group('the joined card', () {
    Future<List<String>> pumpJoined(WidgetTester tester, Council council, {bool withRoom = true}) async {
      final taps = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: JoinedCouncilCard(
                council: council,
                onOpen: () => taps.add('card'),
                onRoom: withRoom ? () => taps.add('room') : null,
                onUnread: withRoom ? () => taps.add('unread') : null,
              ),
            ),
          ),
        ),
      );
      return taps;
    }

    testWidgets('an executive seat has Room Link, a member Meeting link, and each is its own tap', (tester) async {
      var taps = await pumpJoined(tester, _council(role: CouncilRole.lead, unread: 3));
      expect(find.text('Executive Seat'), findsOneWidget);
      expect(find.text('Meeting link'), findsNothing);
      expect(find.text('642 peers'), findsOneWidget);
      await tester.tap(find.text('Room Link'));
      await tester.tap(find.text('3 unread'));
      await tester.tap(find.text('Sustainability, ESG & Net-Zero Council'));
      expect(taps, ['room', 'unread', 'card']);

      taps = await pumpJoined(tester, _council(role: CouncilRole.member));
      expect(find.text('Member'), findsOneWidget);
      expect(find.text('Room Link'), findsNothing);
      expect(find.text('Next Sync: Apr 18'), findsOneWidget);
      await tester.tap(find.text('Meeting link'));
      expect(taps, ['room']);
    });

    testWidgets('without its own taps the buttons open the card\'s page', (tester) async {
      final taps = await pumpJoined(tester, _council(role: CouncilRole.lead, unread: 1), withRoom: false);
      await tester.tap(find.text('Room Link'));
      await tester.tap(find.text('1 unread'));
      expect(taps, ['card', 'card']);
    });

    testWidgets('no unread and no session leaves the pill out', (tester) async {
      await pumpJoined(tester, Council(id: 'c3', name: 'Quiet Council', slug: 'quiet', membership: CouncilRole.member));
      expect(find.textContaining('unread'), findsNothing);
      expect(find.textContaining('Next Sync'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('the directory card', () {
    testWidgets('an established council wears OFFICIAL COUNCIL and Est. beside it', (tester) async {
      await _card(tester, _council(established: 'Est. 2023'));
      expect(find.text('OFFICIAL COUNCIL'), findsOneWidget);
      expect(find.text('Est. 2023'), findsOneWidget);
    });

    testWidgets('a chartered council wears its year alone', (tester) async {
      await _card(tester, _council(badge: 'CHARTERED 2024', established: 'Est. 2023'));
      expect(find.text('CHARTERED 2024'), findsOneWidget);
      expect(find.text('OFFICIAL COUNCIL'), findsNothing);
      expect(find.textContaining('Est.'), findsNothing);
    });

    testWidgets('a new council is OFFICIAL COUNCIL with nothing beside it', (tester) async {
      await _card(tester, _council());
      expect(find.text('OFFICIAL COUNCIL'), findsOneWidget);
      expect(find.textContaining('Est.'), findsNothing);
    });

    testWidgets('a joined council wears JOINED and its seat in place of those', (tester) async {
      await _card(tester, _council(role: CouncilRole.lead, badge: 'CHARTERED 2024'));
      expect(find.text('JOINED'), findsOneWidget);
      expect(find.text('Executive'), findsOneWidget);
      expect(find.text('CHARTERED 2024'), findsNothing);
      expect(find.text('OFFICIAL COUNCIL'), findsNothing);
    });

    testWidgets('it prints the chair, the topics, the members, the sessions and the next date', (tester) async {
      await _card(tester, _council());
      expect(find.textContaining('Vikram Malhotra', findRichText: true), findsOneWidget);
      expect(find.textContaining('Director ESG @ DLF', findRichText: true), findsOneWidget);
      for (final tag in ['#NetZero', '#Decarbonization', '#Scope3']) {
        expect(find.text(tag), findsOneWidget);
      }
      expect(find.text('642 Members'), findsOneWidget);
      expect(find.text('3 Upcoming Events'), findsOneWidget);
      expect(find.text('Next: Apr 18'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a council with no session and no topics leaves those out without overflowing', (tester) async {
      await _card(tester, _council(upcoming: 0, tags: const []).copyWith(clearMembership: true));
      expect(find.textContaining('Upcoming'), findsNothing);
      expect(find.byIcon(LucideIcons.zap), findsNothing);
      expect(find.text('642 Members'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Join Council, Preview Chapter and the lounge each do their own thing', (tester) async {
      var taps = await _card(tester, _council());
      await tester.tap(find.text('Join Council'));
      await tester.tap(find.text('Preview Chapter'));
      expect((taps.join, taps.preview, taps.open, taps.leave), (1, 1, 0, 0));

      taps = await _card(tester, _council(role: CouncilRole.member));
      expect(find.text('Join Council'), findsNothing);
      await tester.tap(find.text('Open Member Lounge'));
      await tester.longPress(find.text('Open Member Lounge'));
      expect((taps.join, taps.open, taps.leave), (0, 1, 1));
    });

    testWidgets('while a join is in flight the button says so and takes no second tap', (tester) async {
      final taps = await _card(tester, _council(), busy: true);
      expect(find.text('Joining…'), findsOneWidget);
      expect(find.text('Join Council'), findsNothing);
      await tester.tap(find.text('Joining…'));
      expect(taps.join, 0);
    });
  });

  group('a roundtable row', () {
    Roundtable rt({RoundtableTone tone = RoundtableTone.blue, String mode = 'VIRTUAL'}) => Roundtable(
      id: 'e1',
      title: 'ESG Mandates: BRSR Core & Scope 3',
      startsAt: DateTime.utc(2027, 4, 18, 10),
      endsAt: DateTime.utc(2027, 4, 18, 11, 30),
      mode: mode,
      tone: tone,
      detail: 'Lead: Vikram Malhotra (DLF) • 82 seats claimed',
    );

    Future<List<String>> pumpRow(WidgetTester tester, Roundtable roundtable) async {
      final taps = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: SizedBox(
              width: 390,
              child: RoundtableRow(
                roundtable: roundtable,
                onTap: () => taps.add('row'),
                onCalendar: () => taps.add('calendar'),
              ),
            ),
          ),
        ),
      );
      return taps;
    }

    testWidgets('draws the date tile, the mode, the Indian-clock time, the title and the lead line', (tester) async {
      final taps = await pumpRow(tester, rt());
      expect(find.text('APR'), findsOneWidget);
      expect(find.text('18'), findsOneWidget);
      expect(find.text('VIRTUAL'), findsOneWidget);
      expect(find.text('15:30 – 17:00 IST'), findsOneWidget);
      expect(find.text('ESG Mandates: BRSR Core & Scope 3'), findsOneWidget);
      expect(find.text('Lead: Vikram Malhotra (DLF) • 82 seats claimed'), findsOneWidget);
      expect(taps, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the row and its calendar glyph are two taps', (tester) async {
      final taps = await pumpRow(tester, rt(tone: RoundtableTone.green, mode: 'HYBRID BLR'));
      expect(find.text('HYBRID BLR'), findsOneWidget);
      await tester.tap(find.byIcon(LucideIcons.calendarPlus));
      await tester.tap(find.text('ESG Mandates: BRSR Core & Scope 3'));
      expect(taps, ['calendar', 'row']);
    });
  });

  group('the stat tiles', () {
    Future<void> pumpTiles(WidgetTester tester, CouncilStats stats) => tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(body: StatTiles(stats: stats)),
      ),
    );

    testWidgets('print the four figures, the quarter pill and the green dot as the design does', (tester) async {
      await pumpTiles(
        tester,
        const CouncilStats(
          activeCouncils: 44,
          newThisQuarter: 3,
          quarter: 'Q4',
          peerMembers: 1016,
          peerMembersLabel: '1,010+',
          domains: 166,
          activeRoundtables: 4,
        ),
      );
      expect(find.text('Active Councils'), findsOneWidget);
      expect(find.text('44'), findsOneWidget);
      expect(find.text('+3 Q4'), findsOneWidget);
      expect(find.text('1,010+'), findsOneWidget);
      expect(find.text('Domains Covered'), findsOneWidget);
      expect(find.text('166'), findsOneWidget);
      expect(find.text('Active Roundtables'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('without a rounded label the exact count is grouped, and no new councils leaves no pill', (
      tester,
    ) async {
      await pumpTiles(
        tester,
        const CouncilStats(activeCouncils: 2, peerMembers: 1222, domains: 3, activeRoundtables: 0),
      );
      expect(find.text('1,222'), findsOneWidget);
      expect(find.textContaining('+'), findsNothing);
    });
  });
}
