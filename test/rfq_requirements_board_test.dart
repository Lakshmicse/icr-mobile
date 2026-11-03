import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/app_screens.dart';
import 'package:icr_mobile/features/feed/feed_models.dart';
import 'package:icr_mobile/features/rfq/demo_rfq_repository.dart';
import 'package:icr_mobile/features/rfq/my_rfqs_screen.dart';
import 'package:icr_mobile/features/rfq/open_requirements_screen.dart';
import 'package:icr_mobile/features/rfq/opportunity_screen.dart';
import 'package:icr_mobile/features/rfq/requirements_board_controller.dart';
import 'package:icr_mobile/features/rfq/requirements_board_screen.dart';
import 'package:icr_mobile/features/rfq/rfq_detail_screen.dart';
import 'package:icr_mobile/features/rfq/rfq_links.dart';
import 'package:icr_mobile/features/rfq/rfq_models.dart';
import 'package:icr_mobile/features/rfq/widgets/board_parts.dart';
import 'package:icr_mobile/features/rfq/widgets/rfq_widgets.dart' show PillTabs;

import 'helpers/fonts.dart';
import 'rfq_fakes.dart';

/// "Requirements": everything posted on ICR (the website's `/rfq`), which the profile menu's Requirements row opens
/// (owner, 3 Nov 2026: "whatever is posted needs to be seen"). The demo holds five public requirements that are not
/// drafts: two of Bharat's company's own and three of other buyers'; a draft of Bharat's and an invite-only one stay
/// off. What the API returns for `GET /rfq` is proved in `test/live/rfq_posted_live_test.dart`.
void main() {
  late FlakyRfqRepository repo;

  setUpAll(loadAppFonts);
  setUp(() {
    RfqClock.now = () => DateTime.utc(2026, 10, 25, 9);
    repo = FlakyRfqRepository(now: RfqClock.now());
  });
  tearDown(RfqClock.reset);

  Future<void> open(WidgetTester tester) =>
      pumpScreen(tester, RequirementsBoardScreen(repository: repo, links: RecordingRfqLinks()));

  Finder card(String id) => find.byKey(ValueKey('posted-$id'));
  Finder chip(String key) => find.byKey(ValueKey(key));

  Poster as(String role, {String? companyId = DemoRfqRepository.companyId}) => Poster(
    id: DemoRfqRepository.bharatId,
    name: 'Bharat Buyer',
    email: 'buyer@icr.dev',
    role: role,
    companyId: companyId,
    companyName: companyId == null ? null : 'Bharat Facilities',
  );

  group('the list', () {
    testWidgets("everything posted shows, newest first, other buyers' and the reader's own alike", (tester) async {
      await open(tester);
      final ids = [
        for (final w in tester.widgetList<OpportunityCard>(find.byType(OpportunityCard, skipOffstage: false))) w.rfq.id,
      ];
      expect(ids, [
        'demo-board-housekeeping',
        DemoRfqRepository.boardId,
        DemoRfqRepository.securityId,
        'demo-board-pest',
        DemoRfqRepository.ifmId,
      ]);
      expect(find.text('5 requirements posted'), findsOneWidget);
      // A draft is the poster's alone, and an invite-only requirement is for the suppliers invited.
      expect(card(DemoRfqRepository.homeId), findsNothing);
      expect(card(DemoRfqRepository.invitedId), findsNothing);
      expect(repo.postedCalls.first, '||1|100', reason: 'every status, no search, the first page');
    });

    testWidgets('each card says where the requirement stands and what it has drawn', (tester) async {
      await open(tester);
      final hvac = card(DemoRfqRepository.boardId);
      expect(find.descendant(of: hvac, matching: find.text('Live')), findsOneWidget);
      expect(
        find.descendant(of: hvac, matching: find.text('4 replies')),
        findsOneWidget,
        reason: 'an enquiry draws replies',
      );
      expect(
        find.descendant(of: hvac, matching: find.text('Alpha Tech Parks')),
        findsOneWidget,
        reason: 'the buyer',
      );
      final security = card(DemoRfqRepository.securityId);
      await tester.ensureVisible(security);
      expect(find.descendant(of: security, matching: find.text('3 replies')), findsOneWidget);
      // An RFQ nobody has quoted on yet carries its status and no count.
      final housekeeping = card('demo-board-housekeeping');
      expect(find.descendant(of: housekeeping, matching: find.text('Live')), findsOneWidget);
      expect(find.descendant(of: housekeeping, matching: find.textContaining('bid')), findsNothing);
    });

    testWidgets('an RFQ counts bids, one or many, and an ended one says how it ended', (tester) async {
      Future<void> show(Requirement r) => pumpScreen(
        tester,
        Scaffold(
          body: OpportunityCard(rfq: r, nameOf: (k) => k, onOpen: () {}, showStatus: true),
        ),
      );
      const base = Requirement(id: 'x', title: 'Lifts', kind: RfqKind.rfq, status: RfqStatus.published, quoteCount: 1);
      await show(base);
      expect(find.text('1 bid'), findsOneWidget);
      await show(base.copyWith(status: RfqStatus.awarded));
      expect(find.text('Awarded'), findsOneWidget);
      await show(
        const Requirement(id: 'y', title: 'Lifts', kind: RfqKind.rfq, status: RfqStatus.cancelled, quoteCount: 2),
      );
      expect(find.text('Cancelled'), findsOneWidget);
      expect(find.text('2 bids'), findsOneWidget);
    });

    testWidgets('the supplier board draws its cards as before: no status and no count', (tester) async {
      const r = Requirement(id: 'x', title: 'Lifts', kind: RfqKind.rfq, status: RfqStatus.published, quoteCount: 2);
      await pumpScreen(
        tester,
        Scaffold(
          body: OpportunityCard(rfq: r, nameOf: (k) => k, onOpen: () {}),
        ),
      );
      expect(find.text('Live'), findsNothing);
      expect(find.text('2 bids'), findsNothing);
    });

    testWidgets('a tab asks the API for that status only, and an empty one points back to All', (tester) async {
      repo.setBoardStatus('demo-board-pest', RfqStatus.awarded);
      await open(tester);
      Finder tabNamed(String label) =>
          find.descendant(of: find.byType(PillTabs<PostedTab>), matching: find.text(label));
      await tester.tap(tabNamed('Awarded'));
      await settle(tester);
      expect(repo.postedCalls.last, 'AWARDED||1|100');
      expect(find.byType(OpportunityCard), findsOneWidget);
      expect(card('demo-board-pest'), findsOneWidget);
      expect(find.text('1 awarded'), findsOneWidget);

      await tester.tap(tabNamed('Closed'));
      await settle(tester);
      expect(find.text('None closed right now'), findsOneWidget);
      await tester.tap(find.text('See all'));
      await settle(tester);
      expect(find.text('5 requirements posted'), findsOneWidget);
    });

    testWidgets('a search narrows the list, and one that finds nothing offers to clear it', (tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextField), 'Zenith');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await settle(tester);
      expect(repo.postedCalls.last, '|Zenith|1|100');
      expect(find.byType(OpportunityCard), findsOneWidget);
      expect(card('demo-board-housekeeping'), findsOneWidget);
      expect(find.text('1 requirement posted'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'submarine');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await settle(tester);
      expect(find.text('No requirements match'), findsOneWidget);
      await tester.tap(find.text('Clear search'));
      await settle(tester);
      expect(find.byType(OpportunityCard, skipOffstage: false), findsNWidgets(5));
    });

    testWidgets('a list that cannot be read says so, and Try again reads it', (tester) async {
      repo.failReads = true;
      await open(tester);
      expect(find.text("Couldn't load the requirements"), findsOneWidget);
      expect(find.text('The server said no.'), findsOneWidget);
      repo.failReads = false;
      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(find.byType(OpportunityCard, skipOffstage: false), findsNWidgets(5));
    });

    test('pages are read as the list is scrolled, and stop at the last', () async {
      final c = RequirementsBoardController(repo, pageSize: 2);
      await c.start();
      expect(c.rows, hasLength(2));
      expect(c.total, 5);
      expect(c.hasMore, isTrue);
      await c.loadMore();
      await c.loadMore();
      expect(c.rows.map((r) => r.id).toSet(), hasLength(5));
      expect(c.hasMore, isFalse);
      expect(repo.postedCalls, ['||1|2', '||2|2', '||3|2']);
      c.dispose();
    });

    test('a page that only repeats the last stops the paging, and the board says it shows only the newest', () async {
      // The portal's `GET /rfq` answers every page with the first (docs/backend-requests/rfq.md §3), and stays so:
      // the owner changes the portal only for payments and the forum.
      final stuck = _FirstPageOnly(now: RfqClock.now());
      final c = RequirementsBoardController(stuck, pageSize: 2);
      await c.start();
      expect(c.hasMore, isTrue);
      expect(c.cutShort, isFalse, reason: 'more may still come');
      await c.loadMore();
      expect(c.rows, hasLength(2));
      expect(c.hasMore, isFalse);
      expect(c.cutShort, isTrue, reason: '2 shown of the 5 the API counts');
      await c.loadMore();
      expect(stuck.pages, [1, 2], reason: 'no third request');
      c.dispose();
    });

    test('a list read whole is never called short', () async {
      final c = RequirementsBoardController(repo, pageSize: 2);
      await c.start();
      await c.loadMore();
      await c.loadMore();
      expect(c.rows, hasLength(5));
      expect(c.cutShort, isFalse);
      c.dispose();
    });
  });

  group('where a card opens', () {
    testWidgets("the reader's own company's requirement opens on the owner's page", (tester) async {
      await open(tester);
      await tester.ensureVisible(card(DemoRfqRepository.securityId));
      await tester.tap(card(DemoRfqRepository.securityId));
      await settle(tester, 8);
      expect(find.byType(RfqDetailScreen), findsOneWidget);
      expect(find.byType(OpportunityScreen), findsNothing);
    });

    testWidgets("another buyer's opens on the page suppliers read", (tester) async {
      await open(tester);
      await tester.tap(card(DemoRfqRepository.boardId));
      await settle(tester, 8);
      expect(find.byType(OpportunityScreen), findsOneWidget);
      expect(find.byType(RfqDetailScreen), findsNothing);
    });

    testWidgets('a recruiter at the same company reads its requirement as a supplier would: it is not theirs to run', (
      tester,
    ) async {
      repo.poster = as('RECRUITER');
      await open(tester);
      await tester.ensureVisible(card(DemoRfqRepository.securityId));
      await tester.tap(card(DemoRfqRepository.securityId));
      await settle(tester, 8);
      expect(find.byType(OpportunityScreen), findsOneWidget);
    });
  });

  group('the toolbar follows the role', () {
    testWidgets("a company admin posts, opens their own list with its count, and finds work", (tester) async {
      await open(tester);
      expect(chip('posted-post'), findsOneWidget);
      expect(chip('posted-mine'), findsOneWidget);
      expect(
        find.descendant(of: chip('posted-mine'), matching: find.text('3')),
        findsOneWidget,
        reason: 'draft included',
      );
      expect(chip('posted-find-work'), findsOneWidget);

      await tester.tap(chip('posted-mine'));
      await settle(tester, 8);
      expect(find.byType(MyRfqsScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(MyRfqsScreen))).pop();
      // The page transition runs out before the board takes taps again.
      await tester.pump(const Duration(seconds: 1));
      await settle(tester, 8);
      expect(find.byType(MyRfqsScreen), findsNothing);
      await tester.tap(chip('posted-find-work'));
      await settle(tester, 8);
      expect(find.byType(OpenRequirementsScreen), findsOneWidget);
    });

    testWidgets('a buyer posts and has their list, but does not sell', (tester) async {
      repo.poster = as('BUYER');
      await open(tester);
      expect(chip('posted-post'), findsOneWidget);
      expect(chip('posted-mine'), findsOneWidget);
      expect(chip('posted-find-work'), findsNothing);
    });

    testWidgets('a recruiter reads the list but is offered nothing to post or run', (tester) async {
      repo.poster = as('RECRUITER');
      await open(tester);
      expect(find.byType(OpportunityCard, skipOffstage: false), findsNWidgets(5));
      expect(chip('posted-post'), findsNothing);
      expect(chip('posted-mine'), findsNothing);
      expect(chip('posted-find-work'), findsNothing);
    });

    testWidgets('someone acting as themselves may post an enquiry and keep a list of their own', (tester) async {
      repo.poster = as('PROFESSIONAL', companyId: null);
      await open(tester);
      expect(chip('posted-post'), findsOneWidget);
      expect(chip('posted-mine'), findsOneWidget);
      expect(chip('posted-find-work'), findsNothing);
    });
  });

  group('who runs a requirement (the portal\'s managesRequirement)', () {
    const ofCompany = Requirement(
      id: 'r1',
      title: 'A',
      kind: RfqKind.rfq,
      status: RfqStatus.published,
      buyerId: 'someone',
      companyId: 'c1',
    );
    const personal = Requirement(
      id: 'r2',
      title: 'B',
      kind: RfqKind.enquiry,
      status: RfqStatus.published,
      buyerId: 'me',
    );
    Poster p(String role, {String? companyId}) =>
        Poster(id: 'me', name: 'Me', email: 'me@x', role: role, companyId: companyId);

    test('the company\'s buyers, sellers and admins run its requirements; its other roles do not', () {
      for (final role in ['BUYER', 'VENDOR', 'COMPANY_ADMIN']) {
        expect(p(role, companyId: 'c1').manages(ofCompany), isTrue, reason: role);
      }
      for (final role in ['RECRUITER', 'BRANCH_ADMIN', 'HIRING_MANAGER', 'PROFESSIONAL']) {
        expect(p(role, companyId: 'c1').manages(ofCompany), isFalse, reason: role);
      }
      expect(p('COMPANY_ADMIN', companyId: 'c2').manages(ofCompany), isFalse, reason: 'another company');
    });

    test('acting as themselves, a person runs only what they posted with no company', () {
      expect(p('PROFESSIONAL').manages(personal), isTrue);
      expect(p('PROFESSIONAL').manages(ofCompany), isFalse);
      expect(p('COMPANY_ADMIN', companyId: 'c1').manages(personal), isFalse, reason: 'while acting for a company');
    });

    test('ICR staff run every one', () => expect(p('SUPER_ADMIN').manages(ofCompany), isTrue));
  });

  test("the website's /rfq is the app's own Requirements board", () {
    final screens = inAppScreens(
      viewer: const FeedAuthor(id: 'u1', name: 'Bharat Buyer'),
      demo: true,
    );
    expect(screens.containsKey('/rfq'), isTrue);
  });
}

/// The sample repository with the portal's paging fault: whatever page is asked for, the first comes back.
class _FirstPageOnly extends DemoRfqRepository {
  _FirstPageOnly({super.now});

  final List<int> pages = [];

  @override
  Future<RequirementPage> posted({String search = '', RfqStatus? status, int page = 1, int limit = 20}) {
    pages.add(page);
    return super.posted(search: search, status: status, limit: limit);
  }
}
