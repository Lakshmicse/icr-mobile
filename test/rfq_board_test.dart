import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/widgets/chips.dart' show ChipRow;
import 'package:icr_mobile/features/rfq/my_bids_screen.dart';
import 'package:icr_mobile/features/rfq/open_requirements_screen.dart';
import 'package:icr_mobile/features/rfq/opportunity_screen.dart';
import 'package:icr_mobile/features/rfq/rfq_links.dart';
import 'package:icr_mobile/features/rfq/rfq_models.dart';
import 'package:icr_mobile/features/rfq/supplier_controllers.dart';
import 'package:icr_mobile/features/rfq/widgets/board_parts.dart';
import 'package:icr_mobile/features/rfq/widgets/rfq_widgets.dart' show MatchRing;

import 'helpers/fonts.dart';
import 'rfq_fakes.dart';

/// Every control of the supplier's board ("Find work"), tapped. What the API
/// does with the filters is proved in `test/live/rfq_live_test.dart`.
void main() {
  late FlakyRfqRepository repo;

  setUpAll(loadAppFonts);
  setUp(() {
    RfqClock.now = () => DateTime.utc(2026, 10, 25, 9);
    repo = FlakyRfqRepository(now: RfqClock.now());
  });
  tearDown(RfqClock.reset);

  Future<void> open(WidgetTester tester) =>
      pumpScreen(tester, OpenRequirementsScreen(repository: repo, links: RecordingRfqLinks()));

  Finder card(String id) => find.byKey(ValueKey('board-$id'));
  Finder chip(String key) => find.byKey(ValueKey(key));

  Future<void> tapChip(WidgetTester tester, String key) async {
    // The chips run past the edge of a phone: scroll the row until it is built.
    if (chip(key).evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        chip(key),
        120,
        scrollable: find.descendant(of: find.byType(ChipRow), matching: find.byType(Scrollable)).first,
      );
    }
    await tester.ensureVisible(chip(key));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(chip(key));
    await settle(tester);
  }

  testWidgets('Recommended lists the requirements matched to the supplier, best match first', (tester) async {
    await open(tester);
    expect(find.byType(OpportunityCard), findsNWidgets(2));
    expect(card('demo-board-hvac'), findsOneWidget);
    expect(card('demo-board-housekeeping'), findsOneWidget);
    expect(card('demo-board-pest'), findsNothing);
    // The match ring and the buyer.
    expect(find.byWidgetPredicate((w) => w is MatchRing && w.score == 82), findsOneWidget);
    expect(find.text('Alpha Tech Parks'), findsOneWidget);
    expect(find.text('Verified buyer'), findsWidgets);
    expect(find.text('ENQUIRY · ENGINEERING SERVICES'), findsNothing);
  });

  testWidgets('All open adds the ones that do not match', (tester) async {
    await open(tester);
    await tester.tap(find.text('All open'));
    await settle(tester);
    expect(find.byType(OpportunityCard), findsNWidgets(3));
    expect(card('demo-board-pest'), findsOneWidget);
  });

  testWidgets('a card shows where, how much and by when', (tester) async {
    await open(tester);
    final hvac = card('demo-board-hvac');
    expect(find.descendant(of: hvac, matching: find.text('Hyderabad')), findsOneWidget);
    expect(find.descendant(of: hvac, matching: find.text('₹18 L')), findsOneWidget);
    expect(find.descendant(of: hvac, matching: find.textContaining('Replies due in 6 days')), findsOneWidget);
  });

  testWidgets('searching narrows the board and clearing brings it back', (tester) async {
    await open(tester);
    await tester.tap(find.text('All open'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'pest');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await settle(tester);
    expect(find.byType(OpportunityCard), findsOneWidget);
    expect(card('demo-board-pest'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'zzz nothing');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await settle(tester);
    expect(find.text('No requirements match'), findsOneWidget);
    await tester.tap(find.text('Clear search and filters'));
    await settle(tester);
    expect(find.byType(OpportunityCard), findsNWidgets(3));
  });

  testWidgets('Sort puts the highest budget first', (tester) async {
    await open(tester);
    await tapChip(tester, 'board-sort');
    await tester.tap(find.text('Highest budget'));
    await settle(tester);
    final order = tester.widgetList<OpportunityCard>(find.byType(OpportunityCard)).map((c) => c.rfq.id).toList();
    expect(order, ['demo-board-housekeeping', 'demo-board-hvac']);
    expect(find.text('Sort: Highest budget'), findsOneWidget);
  });

  testWidgets('Closing soon keeps what closes within a week, and turns off again', (tester) async {
    await open(tester);
    await tapChip(tester, 'board-closing');
    expect(find.byType(OpportunityCard), findsOneWidget);
    expect(card('demo-board-hvac'), findsOneWidget);
    await tapChip(tester, 'board-closing');
    expect(find.byType(OpportunityCard), findsNWidgets(2));
  });

  testWidgets('Verified buyers drops the buyer that is not', (tester) async {
    await open(tester);
    await tester.tap(find.text('All open'));
    await settle(tester);
    await tapChip(tester, 'board-verified');
    expect(find.byType(OpportunityCard), findsNWidgets(2));
    expect(card('demo-board-pest'), findsNothing);
  });

  group('Verified buyers, where the API filters after it has cut the page', () {
    testWidgets('the verified buyers on later pages are found, not hidden behind a page of the others', (tester) async {
      final paged = _FiltersAfterPaging(pageSize: 5);
      // The controller reads 20 to a page; this board's pages are of 5, so ask it for the same.
      final board = SupplierBoardController(paged, pageSize: 5);
      await board.start();
      await board.setTab(BoardTab.open);
      expect(board.rows.map((r) => r.id), ['r0', 'r1', 'r2', 'r3', 'r4'], reason: 'the first page, all of the others');
      await board.toggleVerifiedBuyers();
      expect(board.rows.map((r) => r.id), [
        'r5',
        'r6',
        'r7',
        'r8',
        'r9',
      ], reason: 'page one of the API holds none of them');
      expect(board.error, isNull);
      expect(board.hasMore, isTrue, reason: "the API's second page was full");
      await board.loadMore();
      expect(board.rows.map((r) => r.id), ['r5', 'r6', 'r7', 'r8', 'r9', 'r10', 'r11']);
      expect(board.hasMore, isFalse, reason: 'the third page came back short');
      board.dispose();
    });

    testWidgets('the chip shows them instead of "No requirements match"', (tester) async {
      final paged = _FiltersAfterPaging(pageSize: 20, unverifiedFirst: 20);
      await pumpScreen(tester, OpenRequirementsScreen(repository: paged, links: RecordingRfqLinks()));
      await tester.tap(find.text('All open'));
      await settle(tester);
      expect(find.byType(OpportunityCard), findsWidgets);
      await tapChip(tester, 'board-verified');
      expect(
        find.text('No requirements match'),
        findsNothing,
        reason: 'the first twenty of the API are not verified; the next are',
      );
      expect(find.byType(OpportunityCard), findsWidgets);
      expect(card('r20'), findsOneWidget);
    });
  });

  testWidgets('Filters narrows by city and budget, counts them on the chip and clears', (tester) async {
    await open(tester);
    await tapChip(tester, 'board-filters');
    await tester.enterText(find.byKey(const ValueKey('filter-city')), 'Hyderabad');
    await tester.tap(find.byKey(const ValueKey('filters-apply')));
    await settle(tester);
    expect(find.byType(OpportunityCard), findsOneWidget);
    expect(find.text('Filters (1)'), findsOneWidget);

    await tapChip(tester, 'board-filters');
    await tester.tap(find.byKey(const ValueKey('filters-clear')));
    await settle(tester);
    expect(find.byType(OpportunityCard), findsNWidgets(2));
    expect(find.text('Filters'), findsOneWidget);
  });

  testWidgets('Filters refuses a budget that is not an amount, in the sheet', (tester) async {
    await open(tester);
    await tapChip(tester, 'board-filters');
    await tester.enterText(find.byKey(const ValueKey('filter-min')), 'lots');
    await tester.tap(find.byKey(const ValueKey('filters-apply')));
    await tester.pump();
    expect(find.text('Enter an amount in rupees'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('filter-min')), '5,00,000');
    await tester.enterText(find.byKey(const ValueKey('filter-max')), '100000');
    await tester.tap(find.byKey(const ValueKey('filters-apply')));
    await tester.pump();
    expect(find.text('The most cannot be below the least'), findsOneWidget);
  });

  testWidgets('Invited shows the invitation, marked, with its count on the tab', (tester) async {
    await open(tester);
    expect(find.text('Invited 1'), findsOneWidget);
    await tester.tap(find.text('Invited 1'));
    await settle(tester);
    expect(card('demo-board-facade'), findsOneWidget);
    expect(find.text('Invited to quote'), findsOneWidget);
  });

  testWidgets('a card opens the requirement as the supplier reads it', (tester) async {
    await open(tester);
    await tester.tap(card('demo-board-hvac'));
    await settle(tester, 8);
    expect(find.byType(OpportunityScreen), findsOneWidget);
  });

  testWidgets('the My Bids chip opens the supplier bids with their count', (tester) async {
    await open(tester);
    expect(find.descendant(of: chip('board-mybids'), matching: find.text('2')), findsOneWidget);
    await tapChip(tester, 'board-mybids');
    expect(find.byType(MyBidsScreen), findsOneWidget);
  });

  testWidgets('a bid already sent is marked on its card', (tester) async {
    await repo.placeBid('demo-board-hvac', {'message': 'Ready to start.'});
    await open(tester);
    expect(find.descendant(of: card('demo-board-hvac'), matching: find.text('Bid sent')), findsOneWidget);
  });

  testWidgets('an unverified listing is told it cannot bid yet', (tester) async {
    repo.vendorAccess = const VendorAccess(vendorId: 'v', verified: false);
    await open(tester);
    expect(find.textContaining('not verified yet'), findsOneWidget);
  });

  testWidgets('a plan with a limit shows how many quotes are used', (tester) async {
    repo.vendorAccess = const VendorAccess(vendorId: 'v', verified: true, canBid: true, bidsUsed: 2, bidLimit: 5);
    await open(tester);
    expect(find.text('2 of 5 quotes used this month'), findsOneWidget);
  });

  testWidgets('with no listing the board offers to start selling, and does', (tester) async {
    repo.vendorAccess = const VendorAccess();
    await open(tester);
    expect(find.text('Start selling to find work'), findsOneWidget);
    await tester.tap(find.text('Start selling'));
    await settle(tester);
    expect(find.byType(OpportunityCard), findsWidgets);
  });

  testWidgets('a buyer account is told the board is for suppliers', (tester) async {
    repo.accessError = ApiError('Insufficient role permissions', statusCode: 403);
    await open(tester);
    expect(find.text('This is for supplier accounts'), findsOneWidget);
  });

  testWidgets('a failed load says so and Try again reads it again; pull down reads it again', (tester) async {
    repo.failReads = true;
    await open(tester);
    expect(find.text("Couldn't load the board"), findsOneWidget);
    repo.failReads = false;
    await tester.tap(find.text('Try again'));
    await settle(tester);
    expect(find.byType(OpportunityCard), findsNWidgets(2));

    final before = repo.calls.where((c) => c == 'openBoard').length;
    await tester.fling(find.byType(OpportunityCard).first, const Offset(0, 300), 1000);
    await settle(tester, 12);
    expect(repo.calls.where((c) => c == 'openBoard').length, greaterThan(before));
  });

  testWidgets('with nothing matched, Recommended says so and All open is the way on', (tester) async {
    await pumpScreen(tester, OpenRequirementsScreen(repository: _EmptyBoard(), links: RecordingRfqLinks()));
    expect(find.text('Nothing matched to your services yet'), findsOneWidget);
    await tester.tap(find.text('See all open'));
    await settle(tester);
    expect(find.text('No open requirements right now'), findsOneWidget);
    await tester.tap(find.text('Invited'));
    await settle(tester);
    expect(find.text('No invitations'), findsOneWidget);
  });

  test('more is read as the list is scrolled, and stops when a page is short', () async {
    final paged = _PagedBoard();
    final c = SupplierBoardController(paged, pageSize: 20);
    await c.start();
    expect(c.rows, hasLength(20));
    expect(c.hasMore, isTrue);
    await c.loadMore();
    expect(c.rows, hasLength(25));
    expect(c.hasMore, isFalse);
    await c.loadMore();
    expect(paged.pages, [1, 2]);
  });

  test('a change of search or filter starts again from the first page', () async {
    final paged = _PagedBoard();
    final c = SupplierBoardController(paged, pageSize: 20);
    await c.start();
    await c.loadMore();
    await c.setSearch('x');
    expect(paged.pages.last, 1);
    expect(c.query.search, 'x');
    await c.setFilters(city: 'Pune', minBudget: 1000);
    expect(c.query.filterCount, 2);
    await c.clearFilters();
    expect(c.query.filterCount, 0);
    expect(c.query.search, 'x', reason: 'clearing the filters leaves the search');
  });

  test('the board asks the API for what the chips say', () {
    const q = BoardQuery(
      matchedOnly: true,
      sort: BoardSort.closing,
      city: ' Pune ',
      minBudget: 10,
      verifiedBuyer: true,
    );
    expect(q.toQuery(page: 2, limit: 20), {
      'page': 2,
      'limit': 20,
      'matchedOnly': 'true',
      'sort': 'closing',
      'city': 'Pune',
      'minBudget': 10.0,
      'verifiedBuyer': 'true',
    });
    expect(const BoardQuery().toQuery(page: 1, limit: 20), {'page': 1, 'limit': 20, 'sort': 'match'});
  });
}

/// A board of 25 requirements in pages of 20.
class _PagedBoard extends FlakyRfqRepository {
  final List<int> pages = [];

  @override
  Future<List<Requirement>> openBoard(BoardQuery query, {int page = 1, int limit = 20}) async {
    pages.add(page);
    final from = (page - 1) * limit;
    return [
      for (var i = from; i < 25 && i < from + limit; i++)
        Requirement(id: 'p$i', title: 'Requirement $i', kind: RfqKind.enquiry, status: RfqStatus.published),
    ];
  }
}

/// A board with nothing on it and no invitations.
class _EmptyBoard extends FlakyRfqRepository {
  @override
  Future<List<Requirement>> openBoard(BoardQuery query, {int page = 1, int limit = 20}) async => const [];

  @override
  Future<List<Requirement>> invited() async => const [];
}

/// A board like the portal's: the page is cut first and "Verified buyers" is applied to the page afterwards, so a page
/// can come back short, or empty, with more behind it. [unverifiedFirst] rows of an unverified buyer, then verified ones
/// up to twelve past them.
class _FiltersAfterPaging extends FlakyRfqRepository {
  _FiltersAfterPaging({required this.pageSize, this.unverifiedFirst = 5});

  final int pageSize;
  final int unverifiedFirst;

  late final List<Requirement> raw = [
    for (var i = 0; i < unverifiedFirst + 7; i++)
      Requirement(
        id: 'r$i',
        title: 'Requirement $i',
        kind: RfqKind.enquiry,
        status: RfqStatus.published,
        buyer: BuyerInfo(name: 'Buyer $i', verified: i >= unverifiedFirst),
      ),
  ];

  @override
  Future<List<Requirement>> openBoard(BoardQuery query, {int page = 1, int limit = 20}) async {
    final slice = raw.skip((page - 1) * limit).take(limit);
    return [
      for (final r in slice)
        if (!query.verifiedBuyer || (r.buyer?.verified ?? false)) r,
    ];
  }
}
