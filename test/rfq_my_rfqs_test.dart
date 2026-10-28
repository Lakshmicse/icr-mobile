import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/features/rfq/demo_rfq_repository.dart';
import 'package:icr_mobile/features/rfq/my_rfqs_controller.dart';
import 'package:icr_mobile/features/rfq/my_rfqs_screen.dart';
import 'package:icr_mobile/features/rfq/post_rfq_screen.dart';
import 'package:icr_mobile/features/rfq/rfq_alerts_screen.dart';
import 'package:icr_mobile/features/rfq/rfq_detail_screen.dart';
import 'package:icr_mobile/features/rfq/rfq_links.dart';
import 'package:icr_mobile/features/rfq/rfq_models.dart';
import 'package:icr_mobile/features/rfq/widgets/rfq_widgets.dart' show PillTabs;

import 'helpers/fonts.dart';
import 'rfq_fakes.dart';

/// Every control of "My RFQ's" (the buyer's list), tapped. What the API does with the filters is proved in
/// `test/live/rfq_live_test.dart`.
void main() {
  late FlakyRfqRepository repo;

  setUpAll(loadAppFonts);
  setUp(() {
    RfqClock.now = () => DateTime.utc(2026, 10, 25, 9);
    repo = FlakyRfqRepository(now: RfqClock.now());
  });
  tearDown(RfqClock.reset);

  Future<void> open(WidgetTester tester, {VoidCallback? onBack, VoidCallback? onBell}) =>
      pumpScreen(tester, MyRfqsScreen(repository: repo, links: RecordingRfqLinks(), onBack: onBack, onBell: onBell));

  Finder row(String id) => find.byKey(ValueKey('rfq-row-$id'));
  Finder chip(String key) => find.byKey(ValueKey(key));

  /// The "⋮" of one row.
  Future<void> openMenu(WidgetTester tester, String id) async {
    await tester.tap(find.descendant(of: row(id), matching: find.byTooltip('More')));
    // The sheet slides up for a quarter of a second: its last rows are off screen until it lands.
    await settle(tester, 10);
  }

  /// The tabs run past the edge of a phone: scroll them sideways until [label] is built.
  Future<void> tapTab(WidgetTester tester, String label) async {
    final sideways = find.descendant(of: find.byType(PillTabs<MyView>), matching: find.byType(Scrollable));
    await tester.scrollUntilVisible(find.text(label), 200, scrollable: sideways);
    await tester.tap(find.text(label));
    await settle(tester);
  }

  testWidgets('lists the buyer\'s requirements, newest change first, with what each has drawn', (tester) async {
    await open(tester);
    expect(find.byType(RequirementCard), findsNWidgets(3));
    // "Recently updated": the draft (today), the RFQ, then the enquiry.
    final order = tester.widgetList<RequirementCard>(find.byType(RequirementCard)).map((c) => c.rfq.id).toList();
    expect(order, [DemoRfqRepository.homeId, DemoRfqRepository.ifmId, DemoRfqRepository.securityId]);
    expect(find.text('3 replies · 2 new'), findsOneWidget);
    expect(find.textContaining('2 to screen'), findsOneWidget);
    expect(find.text('Draft'), findsOneWidget);
    expect(find.text('Live'), findsNWidgets(2));
    expect(find.text('Replies due in 9 days'), findsOneWidget);
    expect(find.text('Pre-qual closes in 5 days'), findsOneWidget);
  });

  testWidgets('the tabs carry their counts and each one narrows the list', (tester) async {
    await open(tester);
    expect(find.text('All 3'), findsOneWidget);
    expect(find.text('Live 2'), findsOneWidget);
    expect(find.text('Drafts 1'), findsOneWidget);
    expect(find.text('Awarded 0'), findsOneWidget);
    await tester.tap(find.text('Drafts 1'));
    await settle(tester);
    expect(find.byType(RequirementCard), findsOneWidget);
    expect(row(DemoRfqRepository.homeId), findsOneWidget);
    await tester.tap(find.text('Live 2'));
    await settle(tester);
    expect(find.byType(RequirementCard), findsNWidgets(2));
    await tester.tap(find.text('Awarded 0'));
    await settle(tester);
    expect(find.byType(RequirementCard), findsNothing);
    expect(find.text('Nothing in awarded'), findsOneWidget);
    await tapTab(tester, 'Waiting on you 2');
    expect(find.byType(RequirementCard), findsNWidgets(2));
    await tapTab(tester, 'Closing this week 1');
    expect(row(DemoRfqRepository.ifmId), findsOneWidget);
    expect(find.byType(RequirementCard), findsOneWidget);
  });

  testWidgets('a search is sent, narrows the list, and Clear search brings everything back', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField).first, 'security');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await settle(tester);
    expect(find.byType(RequirementCard), findsNWidgets(2), reason: 'the enquiry and the draft both say security');
    await tester.enterText(find.byType(TextField).first, 'zzqx');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await settle(tester);
    expect(find.text('No requirements match'), findsOneWidget);
    await tester.tap(find.text('Clear search'));
    await settle(tester);
    expect(find.byType(RequirementCard), findsNWidgets(3));
    expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text, isEmpty);
  });

  testWidgets('the type chip picks Enquiries or RFQs, and "All types" puts them back', (tester) async {
    await open(tester);
    await tester.tap(chip('rfq-kind'));
    await settle(tester);
    await tester.tap(find.text('RFQs'));
    await settle(tester);
    expect(find.byType(RequirementCard), findsOneWidget);
    expect(row(DemoRfqRepository.ifmId), findsOneWidget);
    expect(find.text('RFQs'), findsOneWidget, reason: 'the chip now carries the type');
    await tester.tap(chip('rfq-kind'));
    await settle(tester);
    await tester.tap(find.text('Enquiries'));
    await settle(tester);
    expect(find.byType(RequirementCard), findsNWidgets(2));
    await tester.tap(chip('rfq-kind'));
    await settle(tester);
    await tester.tap(find.text('All types').last);
    await settle(tester);
    expect(find.byType(RequirementCard), findsNWidgets(3));
  });

  testWidgets('the sort chip reorders the list', (tester) async {
    await open(tester);
    await tester.tap(chip('rfq-sort'));
    await settle(tester);
    await tester.tap(find.text('Title A–Z'));
    await settle(tester);
    final titles = tester.widgetList<RequirementCard>(find.byType(RequirementCard)).map((c) => c.rfq.title).toList();
    expect(titles, [...titles]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())));
    expect(find.text('Sort: Title A–Z'), findsOneWidget);
  });

  testWidgets('a row opens the requirement, and its button opens it at what is waiting', (tester) async {
    await open(tester);
    // The title is on the row and again in "Waiting on you": the row's is the one that opens it.
    await tester.tap(
      find.descendant(
        of: row(DemoRfqRepository.securityId),
        matching: find.text('Corporate Security — Biometric systems, CCTV & Manpower'),
      ),
    );
    await settle(tester, 8);
    expect(find.byType(RfqDetailScreen), findsOneWidget);
    expect(tester.widget<RfqDetailScreen>(find.byType(RfqDetailScreen)).rfqId, DemoRfqRepository.securityId);
    await tester.tap(find.bySemanticsLabel('Back').last);
    await settle(tester, 14);
    await tester.tap(find.text('Screen (2)'));
    await settle(tester, 8);
    final detail = tester.widget<RfqDetailScreen>(find.byType(RfqDetailScreen));
    expect(detail.rfqId, DemoRfqRepository.ifmId);
    expect(detail.section, 'prequal');
  });

  testWidgets('"Waiting on you" lists what needs a decision and each line opens its requirement', (tester) async {
    await open(tester);
    expect(find.text('Waiting on you'), findsOneWidget);
    expect(find.textContaining('2 pre-qualification responses to screen'), findsOneWidget);
    await tester.tap(chip('rfq-action-${DemoRfqRepository.ifmId}'));
    await settle(tester, 8);
    final detail = tester.widget<RfqDetailScreen>(find.byType(RfqDetailScreen));
    expect(detail.rfqId, DemoRfqRepository.ifmId);
    expect(detail.section, 'prequal');
  });

  testWidgets('Post RFQ opens the composer', (tester) async {
    await open(tester);
    await tester.tap(chip('rfq-post'));
    await settle(tester, 8);
    expect(find.byType(PostRfqScreen), findsOneWidget);
  });

  testWidgets('the arrow goes back and the bell opens the alerts (or what the lead wires)', (tester) async {
    var back = 0;
    var bell = 0;
    await open(tester, onBack: () => back++, onBell: () => bell++);
    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.tap(find.bySemanticsLabel(RegExp('Notifications')));
    expect(back, 1);
    expect(bell, 1);
  });

  testWidgets('with nothing wired the bell opens Alerts', (tester) async {
    await open(tester);
    await tester.tap(find.bySemanticsLabel(RegExp('Notifications')));
    await settle(tester, 8);
    expect(find.byType(RfqAlertsScreen), findsOneWidget);
  });

  group('the row menu', () {
    testWidgets('a draft offers View, Edit, Publish, a similar one and Delete', (tester) async {
      await open(tester);
      await openMenu(tester, DemoRfqRepository.homeId);
      for (final label in ['View', 'Edit', 'Publish', 'Post a similar requirement', 'Delete draft']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('Close enquiry'), findsNothing);
      expect(find.text('Cancel enquiry'), findsNothing);
    });

    testWidgets('a live enquiry offers Close and Cancel, never Publish or Delete', (tester) async {
      await open(tester);
      await openMenu(tester, DemoRfqRepository.securityId);
      expect(find.text('Close enquiry'), findsOneWidget);
      expect(find.text('Cancel enquiry'), findsOneWidget);
      expect(find.text('Publish'), findsNothing);
      expect(find.text('Delete draft'), findsNothing);
    });

    testWidgets('a live RFQ is "requirement", not "enquiry", in its words', (tester) async {
      await open(tester);
      await openMenu(tester, DemoRfqRepository.ifmId);
      expect(find.text('Close requirement'), findsOneWidget);
      expect(find.text('Cancel requirement'), findsOneWidget);
    });

    testWidgets('View opens the requirement', (tester) async {
      await open(tester);
      await openMenu(tester, DemoRfqRepository.securityId);
      await tester.tap(find.text('View'));
      await settle(tester, 8);
      expect(find.byType(RfqDetailScreen), findsOneWidget);
    });

    testWidgets('Edit and "Post a similar requirement" open the composer on that requirement', (tester) async {
      await open(tester);
      await openMenu(tester, DemoRfqRepository.homeId);
      await tester.tap(find.text('Edit'));
      await settle(tester, 8);
      var composer = tester.widget<PostRfqScreen>(find.byType(PostRfqScreen));
      expect(composer.editRfqId, DemoRfqRepository.homeId);
      expect(composer.copyFromRfqId, isNull);
      await tester.tap(find.bySemanticsLabel('Back').last);
      await settle(tester, 14);
      await openMenu(tester, DemoRfqRepository.securityId);
      await tester.tap(find.text('Post a similar requirement'));
      await settle(tester, 8);
      composer = tester.widget<PostRfqScreen>(find.byType(PostRfqScreen));
      expect(composer.copyFromRfqId, DemoRfqRepository.securityId);
      expect(composer.editRfqId, isNull);
    });

    testWidgets('Publish makes the draft live at once', (tester) async {
      await open(tester);
      await openMenu(tester, DemoRfqRepository.homeId);
      await tester.tap(find.text('Publish'));
      await settle(tester);
      expect(repo.calls, contains('act'));
      expect(find.text('Live 3'), findsOneWidget);
      expect(find.text('Drafts 0'), findsOneWidget);
    });

    testWidgets('Close asks first; keeping it changes nothing, confirming closes it', (tester) async {
      await open(tester);
      await openMenu(tester, DemoRfqRepository.securityId);
      await tester.tap(find.text('Close enquiry'));
      await settle(tester);
      expect(find.text('Close this requirement?'), findsOneWidget);
      await tester.tap(find.text('Keep it'));
      await settle(tester);
      expect(find.text('Live 2'), findsOneWidget);
      await openMenu(tester, DemoRfqRepository.securityId);
      await tester.tap(find.text('Close enquiry'));
      await settle(tester);
      await tester.tap(find.text('Close it'));
      await settle(tester);
      expect(find.text('Live 1'), findsOneWidget);
      expect(find.text('Ended 1'), findsOneWidget);
    });

    testWidgets('Cancel asks first and says it cannot be undone', (tester) async {
      await open(tester);
      await openMenu(tester, DemoRfqRepository.ifmId);
      await tester.tap(find.text('Cancel requirement'));
      await settle(tester);
      expect(find.textContaining('can’t be undone'), findsOneWidget);
      await tester.tap(find.text('Cancel requirement').last);
      await settle(tester);
      expect(find.text('Ended 1'), findsOneWidget);
    });

    testWidgets('Delete draft asks, then removes it from the list', (tester) async {
      await open(tester);
      await openMenu(tester, DemoRfqRepository.homeId);
      await tester.tap(find.text('Delete draft'));
      await settle(tester);
      expect(find.text('Delete this draft?'), findsOneWidget);
      await tester.tap(find.text('Delete draft').last);
      await settle(tester);
      expect(row(DemoRfqRepository.homeId), findsNothing);
      expect(find.text('All 2'), findsOneWidget);
    });

    testWidgets('a refusal comes back as the API\'s own sentence and the row is put back', (tester) async {
      await open(tester);
      repo.refuseNextWrite = 'Your company is suspended.';
      await openMenu(tester, DemoRfqRepository.homeId);
      await tester.tap(find.text('Publish'));
      await settle(tester);
      expect(find.text('Your company is suspended.'), findsOneWidget);
      expect(find.text('Draft'), findsOneWidget, reason: 'the row went back to what it was');
      expect(find.text('Drafts 1'), findsOneWidget);
    });
  });

  group('when the list cannot be shown', () {
    testWidgets('a failed load says so, and Try again reads it again', (tester) async {
      repo.failReads = true;
      await open(tester);
      expect(find.text("Couldn't load your requirements"), findsOneWidget);
      repo.failReads = false;
      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(find.byType(RequirementCard), findsNWidgets(3));
    });

    testWidgets('an account that may not post sees why, with the way to a company', (tester) async {
      repo.forbidMine = true;
      final links = RecordingRfqLinks();
      await pumpScreen(tester, MyRfqsScreen(repository: repo, links: links));
      expect(find.text('Requirements are posted by buyers and companies'), findsOneWidget);
    });

    testWidgets('nothing posted yet offers the first requirement', (tester) async {
      repo.emptyMine = true;
      await open(tester);
      expect(find.text('Post your first requirement'), findsOneWidget);
      await tester.tap(find.text('Post RFQ').last);
      await settle(tester, 8);
      expect(find.byType(PostRfqScreen), findsOneWidget);
    });

    testWidgets('pulling the list down reads it again', (tester) async {
      await open(tester);
      final before = repo.calls.where((c) => c == 'mine').length;
      await tester.fling(find.byType(RequirementCard).first, const Offset(0, 300), 1000);
      await settle(tester, 12);
      expect(repo.calls.where((c) => c == 'mine').length, greaterThan(before));
    });
  });

  test('the list reads more as it is scrolled and stops when a page is short', () async {
    final paged = _PagedMine();
    final c = MyRfqsController(paged);
    await c.start();
    expect(c.rows, hasLength(20));
    expect(c.hasMore, isTrue);
    await c.loadMore();
    expect(c.rows, hasLength(23));
    expect(c.hasMore, isFalse);
    await c.loadMore();
    expect(paged.pages, [1, 2]);
    await c.setSearch('x');
    expect(paged.pages.last, 1, reason: 'a new search starts from the first page');
  });

  test('a view, a type and a sort are sent as the API names them', () async {
    final seen = _PagedMine();
    final c = MyRfqsController(seen);
    await c.start();
    await c.setView(MyView.attention);
    await c.setKind(RfqKind.rfq);
    await c.setSort(MySort.closing);
    expect(seen.last, (view: MyView.attention, kind: RfqKind.rfq, sort: MySort.closing, search: '', page: 1));
  });

  test('a 403 on the list is the account\'s role, not a failure', () async {
    final c = MyRfqsController(_Forbidden());
    await c.start();
    expect(c.forbidden, isTrue);
    expect(c.rows, isEmpty);
  });
}

/// 23 requirements, 20 to a page.
class _PagedMine extends DemoRfqRepository {
  final pages = <int>[];
  ({MyView view, RfqKind? kind, MySort sort, String search, int page})? last;

  @override
  Future<RequirementPage> mine({
    MyView view = MyView.all,
    String search = '',
    RfqKind? kind,
    MySort sort = MySort.updated,
    int page = 1,
  }) async {
    pages.add(page);
    last = (view: view, kind: kind, sort: sort, search: search, page: page);
    final count = page == 1 ? 20 : 3;
    return RequirementPage(
      rows: [
        for (var i = 0; i < count; i++)
          Requirement(
            id: 'p$page-$i',
            title: 'Requirement $page-$i',
            kind: RfqKind.enquiry,
            status: RfqStatus.published,
          ),
      ],
      total: 23,
      hasMore: page == 1,
    );
  }
}

class _Forbidden extends DemoRfqRepository {
  @override
  Future<RequirementsSummary> summary() => Future.error(ApiError('Insufficient role permissions', statusCode: 403));
}
