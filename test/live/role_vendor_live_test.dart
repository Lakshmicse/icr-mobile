/// The supplier (VENDOR) side of the app against the LOCAL portal API, account by account
/// (`docs/TEST_PLAN_ROLES.md`, results in `docs/ROLE_TEST_vendor.md`).
///
/// Accounts (passwords: the e2e fixture for the portal's own, `tool/seed/README.md` for the seeds'):
///  - Vivek Vendor `vendor@icr.test` (E2E Test Vendor Co, Gold, verified, no phone on file) is read from
///    `irc-portal/e2e/fixtures/users.json` at run time; this file holds no password of his;
///  - Vikram Vendor `vendor@icr.dev` (Bengaluru Care 101, the inbox seed's seller);
///  - the rfq seed's suppliers: Bluepeak (Gold), Innova (Gold), SecureNet (free plan), GreenShield (not verified);
///  - no supplier listing: Bhavya of Sunrise (COMPANY_ADMIN), Maya of Meridian (COMPANY_ADMIN);
///  - a buyer with no company (Bharat), who is not a supplier at all.
/// The buyer that posts what the suppliers answer is Bhavya of Sunrise (`tool/seed/rfq.ts`).
///
/// Every requirement a test posts is deleted when it ends (which takes its bids, invitations and responses with
/// it). What the API cannot take back, and what the file does about it:
///  - a bid opens a conversation between the supplier and the buyer's company, and a conversation outlives its
///    requirement: bids are placed by the rfq seed's suppliers wherever the test does not need Vivek, and by
///    Vivek in exactly three tests (his thread titles start "zz live");
///  - a notification cannot be deleted (read ones stay);
///  - the threads Vivek's replies leave are put in Done by `tearDownAll`, out of his Open view;
///  - `POST /rfq/:id/conversation` ("Message the buyer") is capped at 30 an hour for everyone on this machine (the
///    limiter is keyed on the IP, and the other roles' runs spend it too): this file makes one call a run;
///  - starting to sell is undone by the staff delete (`DELETE /vendors/:id`, SUPER_ADMIN), which the API keeps as a
///    soft delete and revives on the next "Start selling".
///
///     flutter test --no-pub test/live/role_vendor_live_test.dart --concurrency=1
@Tags(['live'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/app_screens.dart' show inAppScreens;
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/widgets/chips.dart' show ChipRow;
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/marketplace/supplier_controller.dart' show SupplierTab;
import 'package:icr_mobile/features/marketplace/supplier_sheet.dart' show showSupplierSheetById;
import 'package:icr_mobile/features/messaging/conversation_screen.dart' show ConversationScreen;
import 'package:icr_mobile/features/messaging/inbox_screen.dart' show InboxScreen;
import 'package:icr_mobile/features/messaging/widgets/conversation_tile.dart' show ConversationTile;
import 'package:icr_mobile/features/notifications/notification_models.dart' show AppNotification;
import 'package:icr_mobile/features/notifications/notification_router.dart' show NotificationRouter;
import 'package:icr_mobile/features/notifications/notifications_screen.dart' show NotificationsScreen;
import 'package:provider/provider.dart';
import 'package:icr_mobile/features/messaging/api_messaging_repository.dart';
import 'package:icr_mobile/features/feed/demo_feed_repository.dart' show DemoFeedRepository;
import 'package:icr_mobile/features/marketplace/api_marketplace_repository.dart';
import 'package:icr_mobile/features/marketplace/marketplace_filters.dart';
import 'package:icr_mobile/features/marketplace/marketplace_models.dart';
import 'package:icr_mobile/features/marketplace/quote_models.dart';
import 'package:icr_mobile/features/messaging/messaging_models.dart';
import 'package:icr_mobile/features/messaging/messaging_repository.dart';
import 'package:icr_mobile/features/notifications/api_notifications_repository.dart';
import 'package:icr_mobile/features/notifications/notification_target.dart';
import 'package:icr_mobile/features/rfq/api_rfq_repository.dart';
import 'package:icr_mobile/features/rfq/my_bids_screen.dart';
import 'package:icr_mobile/features/rfq/my_rfqs_controller.dart' show MyRfqsController;
import 'package:icr_mobile/features/rfq/open_requirements_screen.dart';
import 'package:icr_mobile/features/rfq/opportunity_screen.dart';
import 'package:icr_mobile/features/rfq/post_rfq_controller.dart';
import 'package:icr_mobile/features/rfq/rfq_links.dart' show PickedRfqFile;
import 'package:icr_mobile/features/rfq/rfq_alerts_screen.dart' show RfqAlertsScreen;
import 'package:icr_mobile/features/rfq/rfq_models.dart';
import 'package:icr_mobile/features/rfq/rfq_rules.dart';
import 'package:icr_mobile/features/rfq/supplier_controllers.dart';
import 'package:icr_mobile/features/rfq/widgets/board_parts.dart' show OpportunityCard;
import 'package:icr_mobile/features/rfq/widgets/supplier_parts.dart' show MyBidCard;

import '../helpers/fonts.dart';
import '../rfq_fakes.dart' show RecordingRfqLinks;
import 'career_live_support.dart';
import 'live.dart';

// ---- The accounts -------------------------------------------------------------------------------------------

const _rfqPassword = 'Rfq@12345';
const sunrise = LivePerson('rfq.buyer@rfq-design.icr.test', _rfqPassword, 'Bhavya Buyer (Sunrise, no listing)');
const bluepeak = LivePerson('rfq.bluedot@rfq-design.icr.test', _rfqPassword, 'Bela (Bluepeak, Gold)');
const innova = LivePerson('rfq.innowork@rfq-design.icr.test', _rfqPassword, 'Ivan (Innova, Gold)');
const secureNet = LivePerson('rfq.securetech@rfq-design.icr.test', _rfqPassword, 'Sana (SecureNet, free)');
const greenShield = LivePerson('rfq.greenguard@rfq-design.icr.test', _rfqPassword, 'Gita (GreenShield, not verified)');
const vikram = LivePerson('vendor@icr.dev', 'Vendor@123', 'Vikram Vendor (Bengaluru Care 101)');
const meridian = LivePerson(
  'marketplace.buyer@marketplace-design.icr.test',
  'Market@12345',
  'Maya Mehta (Meridian, no listing)',
);

/// The portal's e2e accounts live in its fixture file; their passwords are read from it and kept out of this one.
const _fixturePath = 'E:/ICR/irc-portal/e2e/fixtures/users.json';
Map<String, String>? _fixture;

LivePerson? _fromFixture(String email, String label) {
  try {
    _fixture ??= {
      for (final u in (jsonDecode(File(_fixturePath).readAsStringSync()) as List<dynamic>).cast<Map<String, dynamic>>())
        u['email'] as String: u['password'] as String,
    };
    final password = _fixture![email];
    return password == null ? null : LivePerson(email, password, label);
  } catch (_) {
    return null;
  }
}

/// Vivek Vendor, or null (and the test skipped) when the portal's fixture file is not where it is expected.
LivePerson? _vivekOrSkip() {
  final who = _fromFixture('vendor@icr.test', 'Vivek Vendor (E2E Test Vendor Co, Gold)');
  if (who == null) markTestSkipped('$_fixturePath is not readable');
  return who;
}

LivePerson? _superAdminOrSkip() {
  final who = _fromFixture('superadmin@icr.test', 'Sana Admin (SUPER_ADMIN)');
  if (who == null) markTestSkipped('$_fixturePath is not readable');
  return who;
}

const vivekVendorId = 'cmuwohgpy0004myasczs89p7p';
const vivekCompanyId = 'cmuwohgpl0001myasc9zghopt';
const vikramCompanyId = 'cmupai6jm01esmyzcwg2fprhe';
const sandbox = 'design-mkt-v-sandbox';

Future<ApiRfqRepository> _repo(LivePerson who) async => ApiRfqRepository(api: await liveClient(who));

Future<ApiRfqRepository> _repoT(WidgetTester tester, LivePerson who) async =>
    ApiRfqRepository(api: (await tester.runAsync(() => liveClient(who)))!);

// ---- Buyer-side fixtures ---------------------------------------------------------------------------------------

/// A tiny, real PDF to attach.
List<int> _pdf([String tag = '']) =>
    '%PDF-1.4\n1 0 obj << /Type /Catalog >> endobj\ntrailer << /Root 1 0 R >>\n%%EOF\n% $tag\n'.codeUnits;

DateTime _inDays(int n) => todayIst().add(Duration(days: n));

/// A requirement posted as Sunrise through the composer's own controller, and deleted when the test ends. It is filed
/// under Landscape, which none of the personas serve, so the posting does not add a notice to their bells (a supplier
/// is told about every requirement that matches, and the bell keeps them for good); the two tests that are about
/// being told or being matched pass `SECURITY`.
Future<PostResult> _post(
  ApiRfqRepository repo, {
  RfqKind kind = RfqKind.enquiry,
  void Function(RequirementDraft d)? tweak,
  String category = 'LANDSCAPE',
  String sub = 'LANDSCAPE_MAINTENANCE',
  bool deleteAtEnd = true,
}) async {
  final c = PostRfqController(repository: repo, initialKind: kind);
  await c.start();
  expect(c.loadError, isNull);
  expect(c.mustRegisterCompany, isFalse);
  final pune = (await c.searchPlaces('Pune')).first;
  expect(c.addPlace(pune), isTrue);
  c.update((d) {
    d
      ..facilityType = 'IT & ITES'
      ..category = category
      ..subcategory = sub
      ..text = 'Round-the-clock guarding for a Pune campus: 24 guards, three shifts, from 1 December.'
      ..budget = '6,50,000';
    if (kind == RfqKind.rfq) {
      d
        ..preQualEndDate = _inDays(3)
        ..dueDate = _inDays(10)
        ..minYears = '3'
        ..compliance = {'PSARA'};
    }
    tweak?.call(d);
  });
  c.setTitle('zz live vendor ${DateTime.now().millisecondsSinceEpoch}');
  final ok = await c.submit(publish: true);
  expect(ok, isTrue, reason: c.error ?? '${c.problems}');
  final result = c.result!;
  if (deleteAtEnd) {
    addTearDown(() async {
      try {
        await repo.deleteDraft(result.id);
      } catch (_) {
        // Already gone.
      }
    });
  }
  return result;
}

/// A private enquiry to one supplier's listing (what "Request for Quote" sends), deleted when the test ends.
Future<String> _postInvitation(ApiRfqRepository buyer, String vendorId) async {
  final r = await buyer.create({
    'title': 'zz live vendor invite ${DateTime.now().millisecondsSinceEpoch}',
    'kind': 'ENQUIRY',
    'status': 'PUBLISHED',
    'visibility': 'TARGETED',
    'vendorIds': [vendorId],
    'description': 'Please quote for weekly deep cleaning of two floors in Pune.',
    'category': 'FACILITY_MANAGEMENT',
    'budget': 90000,
  });
  addTearDown(() async {
    try {
      await buyer.deleteDraft(r.id);
    } catch (_) {}
  });
  return r.id;
}

/// The supplier's page controller for [id], loaded.
Future<OpportunityController> _page(LivePerson who, String id) async {
  final c = OpportunityController(repository: await _repo(who), rfqId: id);
  addTearDown(c.dispose);
  await c.start();
  expect(c.error, isNull, reason: 'the page of $id for ${who.label}');
  return c;
}

/// An RFQ from posting to the quote stage, with each of [suppliers] pre-qualified, screened in and shortlisted.
Future<String> _toQuotation(ApiRfqRepository buyer, List<LivePerson> suppliers) async {
  final id = (await _post(buyer, kind: RfqKind.rfq)).id;
  final vendorIds = <String>[];
  for (final who in suppliers) {
    final page = await _page(who, id);
    expect(page.state, ResponseState.preQual);
    final answers = PreQualDraft()
      ..yearsInBusiness = '9'
      ..annualTurnover = '9,00,00,000'
      ..compliance = {'PSARA'};
    expect(await page.submitPreQual(answers), isNull);
    vendorIds.add(page.access!.vendorId!);
  }
  for (final v in vendorIds) {
    await buyer.screen(id, v, PreQualStatus.qualified);
  }
  await buyer.setStage(id, RfqStage.shortlisting);
  await buyer.shortlist(id, vendorIds);
  await buyer.setStage(id, RfqStage.quotation);
  return id;
}

Future<String?> _refusal(Future<Object?> call) async {
  try {
    await call;
    return null;
  } catch (e) {
    return ApiError.from(e).message;
  }
}

Matcher _status(int code) => throwsA(isA<Object>().having((e) => ApiError.from(e).statusCode, 'status', code));

RfqFile _file(String title, PickedRfqFile up, RfqFile stored) => RfqFile(
  id: '',
  title: title,
  url: stored.url,
  name: stored.name,
  mimeType: stored.mimeType,
  size: stored.size ?? up.size,
);

/// [settleLive] twice, with a breath of real time between: a screen that reads in two steps (who is asking, then the
/// list) has a moment with no spinner between them, and one pass takes it for the end.
Future<void> settled(WidgetTester tester) async {
  await settleLive(tester, timeout: const Duration(seconds: 6));
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
  await tester.pump(const Duration(milliseconds: 50));
  await settleLive(tester, timeout: const Duration(seconds: 6));
}

/// Lets real time pass between frames until [finder] matches (or [timeout] is up): a screen that loads in two
/// steps has a moment with no spinner between them, which `settleLive` takes for the end.
Future<void> pumpUntilFound(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 8)}) async {
  final until = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(until) && finder.evaluate().isEmpty) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUpAll(loadAppFonts);

  // A reply opens a thread between the supplier and the buyer's company, and the API cannot delete a thread. Vivek is
  // the portal's e2e vendor, so the threads this file's replies leave in his company inbox are put in Done, out of
  // the Open view he works from (the title says "zz live vendor"; Bluepeak's and the other seed suppliers' are
  // swept by `tool/seed/rfq.ts`).
  tearDownAll(() async {
    final vivek = _fromFixture('vendor@icr.test', 'Vivek');
    if (vivek == null || !await liveApiReachable()) return;
    try {
      final messaging = ApiMessagingRepository(api: await liveClient(vivek));
      final open = await messaging.conversations(const ConversationQuery(inbox: vivekCompanyId));
      for (final c in open.conversations) {
        if ((c.title ?? '').startsWith('zz live vendor') || (c.title ?? '').startsWith('zz probe vendor')) {
          await messaging.updateCompanyThread(c.id, companyId: vivekCompanyId, status: ThreadStatus.done);
        }
      }
    } catch (_) {
      // Tidying is a courtesy; a failure here must not fail the run.
    }
  });

  // =========================================================================================================
  group('Who may do what: every account reads its own listing, plan and limits', () {
    liveTest('the supplier accounts have a listing, are verified and bid; the plans differ as seeded', () async {
      final vivek = _vivekOrSkip();
      if (vivek == null) return;
      final accounts = <String, (LivePerson, {bool verified, int? limit, String tier})>{
        'Vivek': (vivek, verified: true, limit: null, tier: 'GOLD'),
        'Vikram': (vikram, verified: true, limit: null, tier: 'GOLD'),
        'Bluepeak': (bluepeak, verified: true, limit: null, tier: 'GOLD'),
        'Innova': (innova, verified: true, limit: null, tier: 'GOLD'),
        'SecureNet': (secureNet, verified: true, limit: 3, tier: 'FREE'),
        'GreenShield': (greenShield, verified: false, limit: 3, tier: 'FREE'),
      };
      for (final e in accounts.entries) {
        final a = await (await _repo(e.value.$1)).access();
        expect(a.hasListing, isTrue, reason: e.key);
        expect(a.verified, e.value.verified, reason: e.key);
        expect(a.bidLimit, e.value.limit, reason: '${e.key}: a null limit is unlimited');
        expect(a.tier, e.value.tier, reason: e.key);
        expect(a.canBid, e.value.verified, reason: '${e.key}: only a verified listing may bid');
        expect(a.canRespondToEnquiry, e.value.verified, reason: e.key);
        expect(a.canRevealContact, e.value.tier != 'FREE', reason: '${e.key}: the free plan has no buyer contact');
      }
      expect((await (await _repo(vivek)).access()).vendorId, vivekVendorId);
    });

    liveTest(
      'an account with no supplier listing is told so by the gate, with the way in; a buyer is told it is not a supplier',
      () async {
        for (final who in [sunrise, meridian]) {
          final board = SupplierBoardController(await _repo(who));
          addTearDown(board.dispose);
          await board.start();
          expect(board.gate, SupplierGate.noListing, reason: who.label);
          expect(board.access!.hasListing, isFalse, reason: who.label);
          final bids = MyBidsController(await _repo(who));
          addTearDown(bids.dispose);
          await bids.start();
          expect(bids.gate, SupplierGate.noListing, reason: who.label);
          final page = await _page(who, 'design-rfq-security');
          expect(page.state, ResponseState.noListing, reason: who.label);
          expect(page.poster!.companyId, isNotNull);
        }
        final bharatBoard = SupplierBoardController(await _repo(bharat));
        addTearDown(bharatBoard.dispose);
        await bharatBoard.start();
        expect(bharatBoard.gate, SupplierGate.role);
        expect(bharatBoard.gateMessage, isNotEmpty, reason: 'the API\'s own sentence');
      },
    );
  });

  // =========================================================================================================
  group('A supplier is a buyer too: their own requirements are theirs to post and run', () {
    liveTest(
      "a supplier's company can post: the composer opens on the company's name and a list of their own requirements loads (Vivek, Vikram)",
      () async {
        final vivek = _vivekOrSkip();
        if (vivek == null) return;
        for (final (who, company) in [(vivek, 'E2E Test Vendor Co'), (vikram, 'Bengaluru Care 101')]) {
          final repo = await _repo(who);
          final composer = PostRfqController(repository: repo);
          addTearDown(composer.dispose);
          await composer.start();
          expect(composer.loadError, isNull, reason: who.label);
          expect(composer.mustRegisterCompany, isFalse, reason: '${who.label}: a company that sells may buy');
          expect(composer.companyFromAccount, company);
          final mine = MyRfqsController(repo);
          addTearDown(mine.dispose);
          await mine.start();
          expect(mine.error, isNull, reason: who.label);
          expect(mine.forbidden, isFalse);
          expect(mine.summary, isNotNull);
          // Their own requirement never shows on their own board.
          final board = await repo.openBoard(const BoardQuery(), limit: 100);
          for (final r in board) {
            expect(
              r.companyId,
              isNot((await repo.me()).companyId),
              reason: '${who.label}: ${r.title} is the company own',
            );
          }
        }
      },
    );
  });

  // =========================================================================================================
  group('Find work: Recommended, All open and Invited', () {
    liveTest(
      'Recommended is the matched part of All open, best match first; both parse for every supplier account',
      () async {
        final vivek = _vivekOrSkip();
        if (vivek == null) return;
        for (final who in [vivek, vikram, bluepeak]) {
          final repo = await _repo(who);
          final recommended = await repo.openBoard(const BoardQuery(matchedOnly: true), limit: 100);
          final all = await repo.openBoard(const BoardQuery(), limit: 100);
          expect(all, isNotEmpty, reason: who.label);
          expect(recommended.every((r) => r.matched), isTrue, reason: who.label);
          expect(all.map((r) => r.id), containsAll(recommended.map((r) => r.id)), reason: who.label);
          for (final r in all) {
            expect(r.status, RfqStatus.published);
            expect(r.visibility, RfqVisibility.public, reason: 'an invite-only requirement is not on the open board');
            expect(r.buyer, isNotNull, reason: r.title);
            expect(r.contactName, isNull, reason: 'a supplier never gets the buyer\'s contact on the board');
          }
          final scores = all.map((r) => r.matchScore ?? 0).toList();
          expect(scores, [...scores]..sort((a, b) => b.compareTo(a)), reason: '${who.label}: best match first');
        }
      },
    );

    liveTest('search, sort, Closing soon, Verified buyers, city and budget keep to what they say (Vivek)', () async {
      final vivek = _vivekOrSkip();
      if (vivek == null) return;
      final repo = await _repo(vivek);
      final c = SupplierBoardController(repo, pageSize: 50);
      addTearDown(c.dispose);
      await c.start();
      expect(c.error, isNull);
      expect(c.gate, isNull);
      expect(c.access!.vendorId, vivekVendorId);
      expect(c.tab, BoardTab.recommended);
      expect(c.query.matchedOnly, isTrue);
      expect(c.rows.every((r) => r.matched), isTrue);
      final recommendedCount = c.rows.length;

      await c.setTab(BoardTab.open);
      expect(c.query.matchedOnly, isFalse);
      expect(c.rows.length, greaterThanOrEqualTo(recommendedCount));
      final titleWord = c.rows.first.title.split(' ').firstWhere((w) => w.length > 3, orElse: () => c.rows.first.title);
      await c.setSearch(titleWord);
      expect(c.rows, isNotEmpty);
      for (final r in c.rows) {
        expect('${r.title} ${r.description ?? ''} ${r.city ?? ''}'.toLowerCase(), contains(titleWord.toLowerCase()));
      }
      await c.setSearch('zzqx-nothing-like-this');
      expect(c.rows, isEmpty);
      await c.setSearch('');

      await c.setSort(BoardSort.newest);
      final dates = c.rows.map((r) => r.createdAt!).toList();
      expect(dates, [...dates]..sort((a, b) => b.compareTo(a)));
      await c.setSort(BoardSort.budget);
      final budgets = c.rows.map((r) => r.budget).whereType<double>().toList();
      expect(budgets, [...budgets]..sort((a, b) => b.compareTo(a)));
      await c.setSort(BoardSort.closing);
      expect(c.rows, isNotNull);
      await c.setSort(BoardSort.match);

      await c.toggleClosingSoon();
      expect(c.query.closingInDays, 7);
      for (final r in c.rows) {
        expect(r.dueDate, isNotNull);
        expect(r.dueDate!.isBefore(DateTime.now().add(const Duration(days: 8))), isTrue);
      }
      await c.toggleClosingSoon();
      expect(c.query.closingInDays, isNull);

      await c.toggleVerifiedBuyers();
      expect(c.rows.every((r) => r.buyer!.verified), isTrue);
      await c.toggleVerifiedBuyers();

      await c.setFilters(city: 'Pune', minBudget: 100000, maxBudget: 1000000);
      expect(c.query.filterCount, 3);
      for (final r in c.rows) {
        expect(r.places.join(' ').toLowerCase(), contains('pune'));
        expect(r.budget! >= 100000 && r.budget! <= 1000000, isTrue);
      }
      await c.clearFilters();
      expect(c.query.filterCount, 0);
      expect(c.rows, isNotEmpty);
    });

    liveTest(
      'paging the open board in small pages, with or without "Verified buyers", reaches the same rows as one big read (Vivek)',
      () async {
        final vivek = _vivekOrSkip();
        if (vivek == null) return;
        final repo = await _repo(vivek);
        for (final verified in [false, true]) {
          final query = BoardQuery(verifiedBuyer: verified);
          final whole = await repo.openBoard(query, limit: 100);
          final c = SupplierBoardController(repo, pageSize: 2);
          addTearDown(c.dispose);
          await c.start();
          await c.setTab(BoardTab.open);
          if (verified) await c.toggleVerifiedBuyers();
          for (var i = 0; i < 30 && c.hasMore; i++) {
            await c.loadMore();
          }
          expect(c.hasMore, isFalse);
          expect(
            c.rows.map((r) => r.id).toSet(),
            whole.map((r) => r.id).toSet(),
            reason: 'verified buyers only: $verified',
          );
          expect(c.rows.map((r) => r.id).toSet(), hasLength(c.rows.length), reason: 'no row twice');
          if (verified) expect(c.rows.every((r) => r.buyer!.verified), isTrue);
        }
      },
    );

    liveTest(
      'a requirement posted for suppliers reaches Recommended for the one whose services match, and the page reads it (Vivek)',
      () async {
        final vivek = _vivekOrSkip();
        if (vivek == null) return;
        final buyer = await _repo(sunrise);
        final posted = await _post(buyer, category: 'SECURITY', sub: 'PHYSICAL_SECURITY');
        final title = (await buyer.requirement(posted.id)).title;
        final repo = await _repo(vivek);
        final recommended = await repo.openBoard(BoardQuery(search: title, matchedOnly: true));
        expect(recommended.map((r) => r.id), contains(posted.id), reason: 'Vivek serves SECURITY');
        final row = recommended.firstWhere((r) => r.id == posted.id);
        expect(row.hasBid, isFalse);
        expect(row.buyer!.companyName, 'Sunrise Facilities Pvt Ltd');
        expect(row.matchScore, isNotNull);
        final page = await _page(vivek, posted.id);
        expect(page.state, ResponseState.form);
        expect(page.own, isFalse);
        expect(page.context!.buyer!.verified, isTrue);
        expect(page.context!.matched, isTrue);
        expect(page.allowance, contains('enquiry'), reason: 'an enquiry reply does not use the monthly bids');
        expect(page.blocker, isNull);
        expect(page.rfq!.contactName, isNull, reason: 'no buyer contact before a reply');
      },
    );

    liveTest(
      'Invited: a private enquiry reaches only the invited supplier, waiting ones lead, a declined one leaves the tab (Vivek)',
      () async {
        final vivek = _vivekOrSkip();
        if (vivek == null) return;
        final buyer = await _repo(sunrise);
        final id = await _postInvitation(buyer, vivekVendorId);
        final repo = await _repo(vivek);
        final invited = await repo.invited();
        final mine = invited.firstWhere((r) => r.id == id);
        expect(mine.inviteStatus, InviteStatus.invited);
        expect(mine.visibility, RfqVisibility.targeted);
        expect((await repo.openBoard(const BoardQuery(), limit: 100)).map((r) => r.id), isNot(contains(id)));
        await expectLater((await _repo(secureNet)).requirement(id), _status(404));

        final board = SupplierBoardController(repo);
        addTearDown(board.dispose);
        await board.start();
        expect(board.invitedOpen, greaterThanOrEqualTo(1));
        await board.setTab(BoardTab.invited);
        expect(board.rows.first.inviteStatus, InviteStatus.invited, reason: 'waiting invitations lead');
        expect(board.rows.map((r) => r.id), contains(id));

        final page = await _page(vivek, id);
        expect(page.invitedOnly, isTrue);
        expect(page.state, ResponseState.form);
        expect(await page.decline(), isNull);
        expect(page.state, ResponseState.declined);
        await board.refresh();
        expect(board.rows.map((r) => r.id), isNot(contains(id)), reason: 'declined ones leave the Invited tab');
        final bids = MyBidsController(repo);
        addTearDown(bids.dispose);
        await bids.start();
        expect(bids.declinedInvites.map((r) => r.id), contains(id));
        expect(bids.count(BidsTab.archived), greaterThanOrEqualTo(1), reason: 'a declined invitation is archived');
        expect((await _page(vivek, id)).state, ResponseState.declined, reason: 'the API keeps the decline');
      },
    );
  });

  // =========================================================================================================
  group('Bidding with every field and file, and what becomes of the bid', () {
    liveTest(
      'an enquiry reply with price, lead time, a 4,000-character message and two files is kept as sent, private to its two sides, and travels Submitted, Shortlisted, Won (Vivek)',
      () async {
        final vivek = _vivekOrSkip();
        if (vivek == null) return;
        final buyer = await _repo(sunrise);
        final mine = await _repo(vivek);
        final posted = await _post(buyer);

        final quote = PickedRfqFile(name: 'quotation.pdf', bytes: _pdf('quotation'));
        final cert = PickedRfqFile(name: 'certificate.pdf', bytes: _pdf('certificate'));
        final storedQuote = await mine.uploadFile(quote, purpose: 'bid-attachment');
        final storedCert = await mine.uploadFile(cert, purpose: 'bid-attachment');
        expect(storedQuote.url, startsWith('/uploads/'));
        final longTitle = 'T' * RfqLimits.attachmentTitle;
        final message = '${'Vivek replies. ' * 270}End'.substring(0, RfqLimits.bidMessage);
        expect(message.length, RfqLimits.bidMessage);

        final page = await _page(vivek, posted.id);
        expect(page.state, ResponseState.form);
        final draft = BidDraft()
          ..amount = '5,90,000.50'
          ..leadTime = '10'
          ..message = message
          ..attachments = [_file(longTitle, quote, storedQuote), _file('Safety certificate', cert, storedCert)];
        expect(draft.problems(enquiry: true), isEmpty);
        expect(await page.placeBid(draft), isNull);
        expect(page.state, ResponseState.sent);
        expect(page.canChangeBid, isFalse, reason: 'the portal has no call to change a bid yet');

        final reread = await _page(vivek, posted.id);
        final bid = reread.myBid!;
        expect(bid.amount, 590000.5);
        expect(bid.leadTimeDays, 10);
        expect(bid.message, message.trim());
        expect(bid.status, BidStatus.pending);
        expect(bid.files.map((f) => f.title), [longTitle, 'Safety certificate']);
        expect(bid.files.map((f) => f.name), ['quotation.pdf', 'certificate.pdf']);

        // The buyer reads the same bid; its files open for the buyer and the supplier, and for nobody else.
        final owner = (await buyer.bids(posted.id)).single;
        expect(owner.supplier.name, 'E2E Test Vendor Co');
        expect(owner.amount, 590000.5);
        expect(owner.files.map((f) => f.title), [longTitle, 'Safety certificate']);
        expect(await File(await buyer.saveFile(owner.files.first)).readAsBytes(), _pdf('quotation'));
        expect(await File(await mine.saveFile(owner.files.first)).readAsBytes(), _pdf('quotation'));
        await expectLater((await _repo(secureNet)).saveFile(owner.files.first), _status(403));
        final nobody = ApiRfqRepository(api: liveAnonymous());
        await expectLater(
          nobody.saveFile(owner.files.first),
          throwsA(isA<Object>().having((e) => ApiError.from(e).statusCode, 'status', anyOf(401, 403))),
        );

        // One reply per requirement; nothing the portal offers changes or withdraws it.
        expect(await page.placeBid(draft), contains('already'));
        expect(mine.supportsBidChanges, isFalse);

        // My Bids: Submitted, then the buyer shortlists it, then selects it.
        final list = MyBidsController(mine);
        addTearDown(list.dispose);
        await list.start();
        expect(list.error, isNull);
        expect(list.bidsIn(BidsTab.submitted).map((b) => b.rfqId), contains(posted.id));
        final row = list.bidsIn(BidsTab.submitted).firstWhere((b) => b.rfqId == posted.id);
        expect(row.amount, 590000.5);
        expect(row.requirement!.title, startsWith('zz live vendor'));
        expect(row.requirement!.buyer!.companyName, 'Sunrise Facilities Pvt Ltd');

        await buyer.triageBid(posted.id, owner.id, BidStatus.shortlisted);
        await list.refresh();
        expect(list.bidsIn(BidsTab.shortlisted).map((b) => b.rfqId), contains(posted.id));
        expect(list.bidsIn(BidsTab.submitted).map((b) => b.rfqId), isNot(contains(posted.id)));

        await buyer.triageBid(posted.id, owner.id, BidStatus.pending);
        final po = await buyer.award(posted.id, owner.id);
        expect(po, isNull, reason: 'an enquiry has no purchase order');
        await list.refresh();
        expect(list.bidsIn(BidsTab.awarded).map((b) => b.rfqId), contains(posted.id));
        expect(list.count(BidsTab.awarded), greaterThanOrEqualTo(1));
        final won = list.bidsIn(BidsTab.awarded).firstWhere((b) => b.rfqId == posted.id);
        expect(won.isAwarded, isTrue);
        final afterAward = await _page(vivek, posted.id);
        expect(afterAward.myBid!.isAwarded, isTrue);
        expect(afterAward.canChangeBid, isFalse);

        // The bell: the buyer's choice reached him, its link names this requirement's supplier page, and opening
        // the page (as the screen does) reads it.
        final alerts = (await mine.alerts()).where((a) => a.rfqId == posted.id).toList();
        expect(alerts.map((a) => a.type), contains('bid_awarded'));
        for (final a in alerts) {
          expect(a.side, AlertSide.supplier);
          final target = NotificationTarget.parse(a.link);
          expect(target.kind, NotificationKinds.rfqSupplier, reason: a.link);
          expect(target['rfqId'], posted.id);
        }
        expect(
          alerts.where((a) => a.unread),
          isEmpty,
          reason: 'opening the requirement page read what told him about it',
        );
      },
    );

    liveTest(
      'the other bidder on that enquiry is told it was not chosen: Not selected, in Archived (Innova)',
      () async {
        final buyer = await _repo(sunrise);
        final posted = await _post(buyer);
        final first = await _page(bluepeak, posted.id);
        final second = await _page(innova, posted.id);
        expect(await first.placeBid(BidDraft()..message = 'Bluepeak can start on 1 December.'), isNull);
        expect(await second.placeBid(BidDraft()..message = 'Innova can start sooner.'), isNull);
        final bids = await buyer.bids(posted.id);
        final chosen = bids.firstWhere((b) => b.supplier.name == 'Bluepeak Security');
        await buyer.award(posted.id, chosen.id);

        final lost = MyBidsController(await _repo(innova));
        addTearDown(lost.dispose);
        await lost.start();
        expect(lost.bidsIn(BidsTab.archived).map((b) => b.rfqId), contains(posted.id));
        final row = lost.bidsIn(BidsTab.archived).firstWhere((b) => b.rfqId == posted.id);
        expect(row.status, BidStatus.rejected);
        final alerts = (await (await _repo(innova)).alerts()).where((a) => a.rfqId == posted.id);
        expect(alerts.map((a) => a.type), contains('bid_rejected'));
        final page = await _page(innova, posted.id);
        expect(page.state, ResponseState.sent, reason: 'the page still shows what was sent');
        expect(page.canChangeBid, isFalse);
      },
    );

    liveTest(
      'an RFQ is answered in stages: pre-qualification, shortlist, then a priced quote with files that wins a purchase order (Vivek)',
      () async {
        final vivek = _vivekOrSkip();
        if (vivek == null) return;
        final buyer = await _repo(sunrise);
        final mine = await _repo(vivek);
        final id = await _toQuotation(buyer, [vivek]);

        // The supplier's page is at the quote stage: a price is required, the allowance is Gold's (unlimited).
        final page = await _page(vivek, id);
        expect(page.state, ResponseState.form);
        expect(page.rfq!.stage, RfqStage.quotation);
        expect(page.allowance, 'Your plan includes unlimited bids.');
        expect(
          await page.placeBid(BidDraft()..message = 'No price.'),
          contains('price'),
          reason: 'the form says so before the API does',
        );
        expect(await _refusal(mine.placeBid(id, {'message': 'No price.'})), isNotNull, reason: 'and so does the API');

        final up = PickedRfqFile(name: 'priced-quotation.pdf', bytes: _pdf('rfq'));
        final stored = await mine.uploadFile(up, purpose: 'bid-attachment');
        final draft = BidDraft()
          ..amount = '5,25,000'
          ..leadTime = '14'
          ..message = 'Detailed quote attached. Price holds for 30 days.'
          ..attachments = [_file('Priced quotation', up, stored)];
        expect(await page.placeBid(draft), isNull);
        expect(page.myBid!.files.single.title, 'Priced quotation');

        final bid = (await buyer.bids(id)).single;
        final po = await buyer.award(id, bid.id);
        expect(po, startsWith('PO-'));

        final list = MyBidsController(mine);
        addTearDown(list.dispose);
        await list.start();
        final won = list.bidsIn(BidsTab.awarded).firstWhere((b) => b.rfqId == id);
        expect(won.poNumber, po);
        expect(won.amount, 525000);
        expect(won.leadTimeDays, 14);
        expect(won.requirement!.kind, RfqKind.rfq);

        // What the bell told him on the way.
        final told = (await mine.alerts()).where((a) => a.rfqId == id).toList();
        final types = told.map((a) => a.type).toSet();
        expect(
          types,
          containsAll(['prequal_result', 'shortlisted', 'rfq_quotes_open', 'bid_awarded']),
          reason: '$types',
        );
        expect(types.every(RfqAlert.types.contains), isTrue, reason: 'every one is an alert the app knows: $types');
        for (final a in told) {
          expect(a.side, AlertSide.supplier, reason: a.type);
          expect(NotificationTarget.parse(a.link).kind, NotificationKinds.rfqSupplier, reason: a.link);
        }
        expect(
          told.firstWhere((a) => a.type == 'rfq_quotes_open').section,
          'response',
          reason: 'the notice that quotes are open lands on the quote form',
        );
      },
    );
  });

  // =========================================================================================================
  group('The rules the API holds on a reply, and the form holds the same (Bluepeak)', () {
    liveTest(
      'every refusal the API gives is said by the form before it is sent, and the largest valid reply goes through',
      () async {
        final buyer = await _repo(sunrise);
        final posted = await _post(buyer);
        final mine = await _repo(bluepeak);
        final up = PickedRfqFile(name: 'q.pdf', bytes: _pdf('limits'));
        final stored = await mine.uploadFile(up, purpose: 'bid-attachment');
        RfqFile file(String title) => _file(title, up, stored);

        // (what is wrong, the draft the form would hold, the payload the API gets for the same thing)
        final cases = <(String, BidDraft, Map<String, dynamic>)>[
          (
            'a negative price',
            BidDraft()
              ..amount = '-1'
              ..message = 'x',
            {'totalAmount': -1, 'message': 'x'},
          ),
          ('a message of 4001 characters', BidDraft()..message = 'a' * 4001, {'message': 'a' * 4001}),
          (
            'a negative lead time',
            BidDraft()
              ..message = 'x'
              ..leadTime = '-1',
            {'message': 'x', 'leadTimeDays': -1},
          ),
          (
            'a lead time of 1.5 days',
            BidDraft()
              ..message = 'x'
              ..leadTime = '1.5',
            {'message': 'x', 'leadTimeDays': 1.5},
          ),
          (
            'eleven files',
            BidDraft()
              ..message = 'x'
              ..attachments = [for (var i = 0; i < 11; i++) file('File $i')],
            {
              'message': 'x',
              'attachments': [
                for (var i = 0; i < 11; i++) {'title': 'File $i', 'url': stored.url},
              ],
            },
          ),
          (
            'a file title of 121 characters',
            BidDraft()
              ..message = 'x'
              ..attachments = [file('T' * 121)],
            {
              'message': 'x',
              'attachments': [
                {'title': 'T' * 121, 'url': stored.url},
              ],
            },
          ),
          (
            'a file with no title',
            BidDraft()
              ..message = 'x'
              ..attachments = [file('   ')],
            {
              'message': 'x',
              'attachments': [
                {'title': '   ', 'url': stored.url},
              ],
            },
          ),
          ('nothing at all', BidDraft(), <String, dynamic>{}),
        ];
        for (final (what, draft, payload) in cases) {
          expect(draft.problems(enquiry: true), isNotEmpty, reason: 'the form lets $what through');
          final refusal = await _refusal(mine.placeBid(posted.id, payload));
          expect(refusal, isNotNull, reason: 'the API takes $what');
        }
        expect((await mine.opportunity(posted.id)).myBid, isNull, reason: 'none of those left a reply behind');

        // The largest reply the form accepts is one the API stores.
        final biggest = BidDraft()
          ..amount = '999999999999'
          ..leadTime = '${RfqLimits.maxLeadTimeDays}'
          ..message = 'm' * RfqLimits.bidMessage
          ..attachments = [for (var i = 0; i < RfqLimits.maxBidAttachments; i++) file('${'T' * 110} $i')];
        expect(biggest.problems(enquiry: true), isEmpty);
        final sent = await mine.placeBid(posted.id, biggest.toJson());
        expect(sent.amount, 999999999999);
        expect(sent.leadTimeDays, RfqLimits.maxLeadTimeDays);
        expect(sent.message, hasLength(RfqLimits.bidMessage));
        expect(sent.files, hasLength(RfqLimits.maxBidAttachments));
      },
    );

    liveTest(
      'the portal has no call to change or withdraw a bid, and a supplier cannot triage or award their own',
      () async {
        // `docs/backend-requests/rfq.md` section 1. When the portal gets `PATCH|DELETE /rfq/:id/bids/mine` these two
        // answer 200, this test says so, and `ApiRfqRepository(supportsBidChanges: true)` is the line to change.
        final buyer = await _repo(sunrise);
        final posted = await _post(buyer);
        final page = await _page(bluepeak, posted.id);
        expect(await page.placeBid(BidDraft()..message = 'A reply.'), isNull);
        final blue = ApiRfqRepository(api: await liveClient(bluepeak), supportsBidChanges: true);
        final inRange = throwsA(
          isA<Object>().having((e) => ApiError.from(e).statusCode, 'status', inInclusiveRange(400, 404)),
        );
        await expectLater(blue.updateBid(posted.id, {'message': 'Changed'}), inRange);
        await expectLater(blue.withdrawBid(posted.id), inRange);
        final own = page.myBid!;
        await expectLater(blue.triageBid(posted.id, own.id, BidStatus.shortlisted), _status(403));
        await expectLater(blue.award(posted.id, own.id), _status(403));
        expect((await blue.opportunity(posted.id)).myBid!.message, 'A reply.', reason: 'untouched');
      },
    );
  });

  // =========================================================================================================
  group('The bell: what a supplier is told, and where each notice leads', () {
    liveTest(
      'every notice a supplier holds names a page the app can read, and the requirement ones name their supplier page',
      () async {
        final vivek = _vivekOrSkip();
        if (vivek == null) return;
        const requirementTypes = {
          'bid_awarded',
          'bid_rejected',
          'rfq_invite',
          'enquiry_match',
          'rfq_match',
          'rfq_quotes_open',
          'shortlisted',
          'prequal_result',
        };
        for (final who in [vivek, vikram, bluepeak]) {
          final repo = ApiNotificationsRepository(api: await liveClient(who));
          var page = 1;
          var seen = 0;
          final types = <String>{};
          while (true) {
            final p = await repo.list(page: page);
            for (final n in p.items) {
              seen++;
              types.add(n.type);
              expect(n.title, isNotEmpty, reason: who.label);
              final link = n.link;
              if (link == null) continue;
              final target = NotificationTarget.parse(link);
              expect(target.kind, isNot(NotificationKinds.none), reason: '${n.type}: $link');
              if (requirementTypes.contains(n.type)) {
                expect(target.kind, NotificationKinds.rfqSupplier, reason: '${n.type}: $link');
                expect(target['rfqId'], isNotEmpty, reason: link);
              }
            }
            if (!p.hasMore || ++page > 6) break;
          }
          expect(seen, greaterThan(0), reason: '${who.label} holds notices');
          expect(types, isNotEmpty);
        }
      },
    );

    liveTest(
      'a new requirement, a private quote request and the buyer\'s choice each reach the supplier, and opening the page reads them',
      () async {
        final buyer = await _repo(sunrise);
        final posted = await _post(buyer, category: 'SECURITY', sub: 'PHYSICAL_SECURITY');
        final invited = await _postInvitation(buyer, (await (await _repo(bluepeak)).access()).vendorId!);

        // The public requirement: told to the suppliers whose services match, as many as the API says it reached.
        expect(posted.alertedNow, isNotNull);
        final told = <String>[];
        for (final who in [bluepeak, innova]) {
          final mine = await (await _repo(who)).alerts();
          final match = mine.where((a) => a.rfqId == posted.id && a.type == 'enquiry_match');
          if (match.isNotEmpty) told.add(who.label);
          for (final a in match) {
            expect(a.unread, isTrue, reason: who.label);
            expect(a.side, AlertSide.supplier);
            expect(NotificationTarget.parse(a.link).kind, NotificationKinds.rfqSupplier);
          }
        }
        expect(
          told,
          isNotEmpty,
          reason: 'at least one of the Security suppliers was told about a Security requirement',
        );

        // The private request: an invitation to the one supplier, naming its supplier page.
        final blue = await _repo(bluepeak);
        final invites = (await blue.alerts()).where((a) => a.rfqId == invited);
        expect(invites.map((a) => a.type), contains('rfq_invite'));
        final invite = invites.firstWhere((a) => a.type == 'rfq_invite');
        expect(invite.unread, isTrue);
        expect(NotificationTarget.parse(invite.link)['rfqId'], invited);
        expect((await blue.counts()).newAlerts, greaterThanOrEqualTo(1));

        // Opening the requirement (as a tap on the notice does) reads what announced it.
        final page = await _page(bluepeak, invited);
        expect(page.invitedOnly, isTrue);
        expect(page.state, ResponseState.form);
        expect((await blue.alerts()).where((a) => a.rfqId == invited && a.unread), isEmpty);

        // Choosing the supplier tells them.
        expect(await page.placeBid(BidDraft()..message = 'We would be glad to quote.'), isNull);
        final bid = (await buyer.bids(invited)).single;
        await buyer.award(invited, bid.id);
        final after = (await blue.alerts()).where((a) => a.rfqId == invited).map((a) => a.type);
        expect(after, containsAll(['rfq_invite', 'bid_awarded']));
      },
    );
  });

  // =========================================================================================================
  group('Enquiries and messages from buyers reach the company inbox', () {
    liveTest('every supplier account answers for its company inbox, which takes Sales and Procurement', () async {
      final vivek = _vivekOrSkip();
      if (vivek == null) return;
      final accounts = {vivek: vivekCompanyId, vikram: vikramCompanyId, bluepeak: 'design-rfq-co-bluedot'};
      for (final e in accounts.entries) {
        final repo = ApiMessagingRepository(api: await liveClient(e.key));
        final inboxes = await repo.inboxes();
        expect(inboxes.first.personal, isTrue, reason: e.key.label);
        final company = inboxes.firstWhere((i) => !i.personal);
        expect(company.id, e.value, reason: e.key.label);
        expect(company.topics, containsAll(['SALES', 'PROCUREMENT']), reason: e.key.label);
        final list = await repo.conversations(ConversationQuery(inbox: e.value));
        for (final c in list.conversations) {
          expect(c.asCompanyId, e.value);
          expect(c.myParty, isNotNull, reason: c.id);
        }
        expect((await repo.unreadCount()).companies.keys, contains(e.value), reason: e.key.label);
      }
    });

    liveTest(
      'a buyer\'s message to a supplier lands in its sales inbox; the seller answers as the company and sorts the thread; the buyer reads the answer',
      () async {
        final buyer = ApiMessagingRepository(api: await liveClient(sunrise));
        final seller = ApiMessagingRepository(api: await liveClient(bluepeak));
        final vendorId = (await (await _repo(bluepeak)).access()).vendorId!;
        const company = 'design-rfq-co-bluedot';
        final sent = <(ApiMessagingRepository, String, String)>[];
        final id = await buyer.startWithSupplier(vendorId);
        addTearDown(() async {
          try {
            await seller.updateCompanyThread(id, companyId: company, status: ThreadStatus.open);
          } catch (_) {}
          for (final (repo, thread, message) in sent) {
            try {
              await repo.deleteMessage(thread, message);
            } catch (_) {}
          }
        });

        final asked = await buyer.send(id, body: 'zz live: do you cover night shifts in Pune?');
        sent.add((buyer, id, asked.id));
        expect(await buyer.startWithSupplier(vendorId), id, reason: 'one thread per member and supplier');

        // The company inbox lists it as a Sales thread with the message waiting.
        final waiting = await seller.conversations(const ConversationQuery(inbox: company));
        final row = waiting.conversations.firstWhere((c) => c.id == id);
        expect(row.asCompanyId, company);
        expect(row.myParty!.topic, 'SALES');
        expect(row.myParty!.status, ThreadStatus.open);
        expect(row.unread, greaterThanOrEqualTo(1));
        expect((await seller.unreadCount()).companies[company], greaterThanOrEqualTo(1));
        expect(
          (await seller.conversations(
            const ConversationQuery(inbox: company, topic: 'SALES'),
          )).conversations.map((c) => c.id),
          contains(id),
        );

        // Read as the company, answered as the company.
        final window = await seller.thread(id, asCompanyId: company);
        expect(window.messages.map((m) => m.body), contains('zz live: do you cover night shifts in Pune?'));
        await seller.markRead(id, asCompanyId: company);
        final answer = await seller.send(id, body: 'zz live: yes, three shifts.', asCompanyId: company);
        sent.add((seller, id, answer.id));
        expect(answer.senderCompany?.id, company);
        final theirs = await buyer.thread(id);
        expect(theirs.messages.last.body, 'zz live: yes, three shifts.');
        expect(theirs.messages.last.senderCompany?.name, 'Bluepeak Security');

        // Sorting it: Done leaves the Open view, back to Open returns it.
        final done = await seller.updateCompanyThread(id, companyId: company, status: ThreadStatus.done);
        expect(done.status, ThreadStatus.done);
        expect(
          (await seller.conversations(const ConversationQuery(inbox: company))).conversations.map((c) => c.id),
          isNot(contains(id)),
        );
        expect(
          (await seller.conversations(
            const ConversationQuery(inbox: company, view: CompanyInboxView.done),
          )).conversations.map((c) => c.id),
          contains(id),
        );
        await seller.updateCompanyThread(id, companyId: company, status: ThreadStatus.open);
        expect(
          (await seller.conversations(const ConversationQuery(inbox: company))).conversations.map((c) => c.id),
          contains(id),
        );
      },
    );

    liveTest('a bid opens the requirement thread in the supplier\'s inbox, with the reply as its first word', () async {
      final buyer = await _repo(sunrise);
      final posted = await _post(buyer);
      final page = await _page(bluepeak, posted.id);
      expect(await page.placeBid(BidDraft()..message = 'Reply that opens a thread.'), isNull);
      final seller = ApiMessagingRepository(api: await liveClient(bluepeak));
      final threads = (await seller.conversations(
        const ConversationQuery(inbox: 'design-rfq-co-bluedot'),
      )).conversations;
      final row = threads.firstWhere((c) => c.rfqId == posted.id);
      expect(row.kind, ConversationKind.enquiry, reason: 'a thread about an enquiry');
      expect(row.myParty!.topic, 'SALES');
      final window = await seller.thread(row.id, asCompanyId: 'design-rfq-co-bluedot');
      expect(window.messages.first.body, 'Reply that opens a thread.');
      final ctx = (await seller.context(row.id, asCompanyId: 'design-rfq-co-bluedot'))!;
      expect(ctx.perspective, Perspective.supplier);

      // "Message the buyer" finds that same thread. The route allows 30 calls an hour per client address for every
      // role's run, and the client waits out a refusal for minutes: it is given 25 seconds, and the test says so
      // (skipped, after everything above has held) rather than hanging when the hour's budget is spent.
      final opened = await page.messageBuyer().timeout(
        const Duration(seconds: 25),
        onTimeout: () => (id: null, error: 'timed out'),
      );
      if (opened.id == null) {
        markTestSkipped('POST /rfq/:id/conversation is throttled for this address (30 an hour): ${opened.error}');
        return;
      }
      expect(opened.id, row.id, reason: 'Message the buyer opens the same thread');
    });
  });

  // =========================================================================================================
  group('The supplier\'s own listing, seen by its owner in the Marketplace', () {
    liveTest('the owner finds the listing by name and reads what any buyer reads; ratings carry no reviewer', () async {
      final vivek = _vivekOrSkip();
      if (vivek == null) return;
      final mine = ApiMarketplaceRepository(api: await liveClient(vivek));
      final found = await mine.suppliers(const MarketplaceFilters(search: 'E2E Test Vendor'));
      expect(found.suppliers.map((s) => s.id), contains(vivekVendorId));
      final own = await mine.supplier(vivekVendorId);
      expect(own.name, 'E2E Test Vendor Co');
      expect(own.rating, 4.7);
      expect(own.ratingCount, 42);
      expect(own.level, SupplierLevel.verified);
      expect(own.companyId, vivekCompanyId);
      expect(own.hubs, isNotEmpty);

      // The same listing, read by a buyer, is the same.
      final buyerSide = ApiMarketplaceRepository(api: await liveClient(sunrise));
      final theirs = await buyerSide.supplier(vivekVendorId);
      expect(
        [theirs.name, theirs.rating, theirs.ratingCount, theirs.level],
        [own.name, own.rating, own.ratingCount, own.level],
      );

      // A supplier with written ratings: nobody's name or company comes with them.
      final withReviews = await mine.supplier('design-mkt-v-vikasha');
      expect(withReviews.reviews, isNotEmpty);
      for (final r in withReviews.reviews) {
        expect(r.byline, isNull, reason: 'the API gives no reviewer company');
        expect(r.role, isNull, reason: 'and no reviewer role');
        expect(r.score, inInclusiveRange(1, 5));
      }
    });

    liveTest(
      'a supplier bookmarks another supplier and takes it back; their own listing refuses a rating, a message and a quote in the API\'s words',
      () async {
        final vivek = _vivekOrSkip();
        if (vivek == null) return;
        final mine = ApiMarketplaceRepository(api: await liveClient(vivek));
        addTearDown(() async {
          try {
            await mine.setSaved(sandbox, false);
            await mine.setSaved(vivekVendorId, false);
          } catch (_) {}
        });
        expect(await mine.savedIds(), isNot(contains(sandbox)));
        await mine.setSaved(sandbox, true);
        expect(await mine.savedIds(), contains(sandbox));
        expect((await mine.savedSuppliers()).suppliers.map((s) => s.id), contains(sandbox));
        await mine.setSaved(sandbox, false);
        expect(await mine.savedIds(), isNot(contains(sandbox)));

        expect(
          await _refusal(mine.rate(vivekVendorId, score: 5, comment: 'ours')),
          'You cannot rate your own listing.',
        );
        expect(await _refusal(mine.startConversation(vivekVendorId)), 'This is your own listing.');
        final quote = await _refusal(
          mine.requestQuote(
            QuoteRequest(
              vendorId: vivekVendorId,
              supplierName: 'E2E Test Vendor Co',
              scope: 'Deep cleaning',
              phone: null,
            ),
          ),
        );
        expect(quote, isNotNull, reason: 'a quote request to one\'s own listing is refused');
      },
    );

    liveTest(
      'a supplier asking another supplier for a quote with no mobile number on file is asked for one, in the API\'s words',
      () async {
        final vivek = _vivekOrSkip();
        if (vivek == null) return;
        final mine = ApiMarketplaceRepository(api: await liveClient(vivek));
        expect(await mine.hasPhone(), isFalse, reason: 'Vivek has no number: the quote sheet asks for one');
        final refusal = await _refusal(
          mine.requestQuote(
            const QuoteRequest(vendorId: 'design-rfq-v-bluedot', supplierName: 'Bluepeak Security', scope: 'Guarding'),
          ),
        );
        expect(refusal, contains('mobile number'));
      },
    );
  });

  // =========================================================================================================
  group('The real screens over the real API', () {
    Finder key(String k) => find.byKey(ValueKey(k));

    Future<void> tapKey(WidgetTester tester, String k) async {
      await tester.ensureVisible(key(k));
      await tester.tap(key(k));
      await settled(tester);
    }

    Future<void> type(WidgetTester tester, String k, String text) async {
      await tester.ensureVisible(key(k));
      await tester.enterText(key(k), text);
      await tester.pump();
    }

    /// The screen drew without a thrown error, and none of the states a failure draws.
    void expectNoFailure(WidgetTester tester) {
      expect(tester.takeException(), isNull);
      expect(find.textContaining("Couldn't load"), findsNothing);
      expect(find.textContaining('Exception'), findsNothing);
      expect(find.textContaining('DioException'), findsNothing);
    }

    testWidgets(
      'Find work draws Vivek\'s board: tabs, the My Bids chip, real cards; a card opens its page; All open lists more',
      tags: const ['live'],
      (tester) async {
        if (!await liveScreenReady(tester)) return;
        final vivek = _vivekOrSkip();
        if (vivek == null) return;
        final repo = await _repoT(tester, vivek);
        await pumpLive(
          tester,
          OpenRequirementsScreen(key: UniqueKey(), repository: repo, links: RecordingRfqLinks()),
          size: const Size(390, 900),
        );
        await settled(tester);
        expectNoFailure(tester);
        expect(find.text('Find work'), findsOneWidget);
        for (final tab in ['Recommended', 'All open', 'Invited']) {
          expect(find.text(tab), findsWidgets, reason: tab);
        }
        // The chips run past the edge of a phone: scroll the row until each is built.
        for (final chip in ['board-mybids', 'board-sort', 'board-closing', 'board-verified', 'board-filters']) {
          if (key(chip).evaluate().isEmpty) {
            await tester.scrollUntilVisible(
              key(chip),
              120,
              scrollable: find.descendant(of: find.byType(ChipRow), matching: find.byType(Scrollable)).first,
            );
          }
          expect(key(chip), findsOneWidget, reason: chip);
        }
        await tester.drag(find.byType(ChipRow).first, const Offset(900, 0));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.textContaining('not verified yet'), findsNothing, reason: 'Vivek is verified');
        expect(find.textContaining('quotes used this month'), findsNothing, reason: 'Gold has no limit');
        await pumpUntilFound(tester, find.byType(OpportunityCard));
        final recommended = find.byType(OpportunityCard).evaluate().length;
        expect(recommended, greaterThan(0));

        await tester.tap(find.text('All open'));
        await settled(tester);
        await pumpUntilFound(tester, find.byType(OpportunityCard));
        expectNoFailure(tester);
        expect(find.byType(OpportunityCard).evaluate().length, greaterThanOrEqualTo(recommended));

        final first = tester.widgetList<OpportunityCard>(find.byType(OpportunityCard)).first.rfq;
        await tester.tap(key('board-${first.id}'));
        await pumpUntilFound(tester, key('response-card'));
        await settled(tester);
        expectNoFailure(tester);
        expect(find.text('Requirement'), findsOneWidget);
        expect(key('response-card'), findsOneWidget, reason: 'the page of ${first.title} says what Vivek can do');
        expect(key('response-title'), findsOneWidget);
        await finishLive(tester);
      },
    );

    testWidgets(
      'Find work for the others: a free plan shows its allowance, an unverified listing is told so, and an account with no listing is offered Start selling',
      tags: const ['live'],
      (tester) async {
        if (!await liveScreenReady(tester)) return;
        // [until] is what that account's board says once it has read who is asking.
        Future<void> board(LivePerson who, Finder until) async {
          final repo = await _repoT(tester, who);
          await pumpLive(
            tester,
            OpenRequirementsScreen(key: UniqueKey(), repository: repo, links: RecordingRfqLinks()),
            size: const Size(390, 900),
          );
          await pumpUntilFound(tester, until);
          await settled(tester);
          expectNoFailure(tester);
        }

        await board(secureNet, find.textContaining('quotes used this month'));
        expect(find.textContaining('of 3 quotes used this month'), findsOneWidget);
        await pumpUntilFound(tester, find.byType(OpportunityCard));
        expect(find.byType(OpportunityCard), findsWidgets);

        await board(greenShield, find.textContaining('not verified yet'));
        expect(find.textContaining('not verified yet'), findsOneWidget);
        await pumpUntilFound(tester, find.byType(OpportunityCard));
        expect(find.byType(OpportunityCard), findsWidgets, reason: 'an unverified supplier may still read');

        await board(sunrise, find.text('Start selling'));
        expect(find.text('Start selling to find work'), findsOneWidget);
        expect(find.text('Start selling'), findsOneWidget);
        expect(find.byType(OpportunityCard), findsNothing);

        await board(bharat, find.text('This is for supplier accounts'));
        expect(find.text('This is for supplier accounts'), findsOneWidget);
        expect(find.text('Start selling'), findsNothing);
        await finishLive(tester);
      },
    );

    testWidgets(
      'My Bids draws every tab for Vivek from the API: the counts and the cards match the controller',
      tags: const ['live'],
      (tester) async {
        if (!await liveScreenReady(tester)) return;
        final vivek = _vivekOrSkip();
        if (vivek == null) return;
        final repo = await _repoT(tester, vivek);
        final truth = MyBidsController(repo);
        await tester.runAsync(truth.start);
        await pumpLive(
          tester,
          MyBidsScreen(key: UniqueKey(), repository: repo, links: RecordingRfqLinks()),
          size: const Size(390, 1400),
        );
        await settled(tester);
        expectNoFailure(tester);
        expect(find.text('My Bids'), findsOneWidget);
        for (final tab in BidsTab.values) {
          expect(
            find.text('${tab.label} ${truth.count(tab)}'),
            findsOneWidget,
            reason: 'the count on the ${tab.label} tab',
          );
        }
        for (final tab in BidsTab.values) {
          await tester.tap(find.text('${tab.label} ${truth.count(tab)}'));
          await settled(tester);
          expectNoFailure(tester);
          final want = truth.bidsIn(tab).length;
          expect(find.byType(MyBidCard), findsNWidgets(want), reason: '${tab.label}: ${truth.count(tab)} on the tab');
          if (want == 0 && truth.count(tab) == 0) {
            expect(find.byType(MyBidCard), findsNothing);
            expect(
              find.textContaining('No bids waiting').evaluate().length +
                  find.textContaining('Nothing').evaluate().length +
                  find.textContaining('No wins').evaluate().length,
              greaterThan(0),
              reason: '${tab.label} says it is empty',
            );
          }
        }
        truth.dispose();
        await finishLive(tester);
      },
    );

    testWidgets(
      'a requirement Vivek answered is read back by its page: price, lead time, message, files; and it says plainly that the bid cannot be changed here',
      tags: const ['live'],
      (tester) async {
        if (!await liveScreenReady(tester)) return;
        final vivek = _vivekOrSkip();
        if (vivek == null) return;
        final buyer = await _repoT(tester, sunrise);
        final mine = await _repoT(tester, vivek);
        final posted = (await tester.runAsync(() => _post(buyer, deleteAtEnd: false)))!;
        try {
          final stored = (await tester.runAsync(
            () => mine.uploadFile(
              PickedRfqFile(name: 'quotation.pdf', bytes: _pdf('screen')),
              purpose: 'bid-attachment',
            ),
          ))!;
          final up = PickedRfqFile(name: 'quotation.pdf', bytes: _pdf('screen'));
          final draft = BidDraft()
            ..amount = '4,50,000'
            ..leadTime = '7'
            ..message = 'Vivek here: we can mobilise within a week.'
            ..attachments = [_file('Our quotation', up, stored)];
          await tester.runAsync(() => mine.placeBid(posted.id, draft.toJson()));

          await pumpLive(
            tester,
            OpportunityScreen(posted.id, key: UniqueKey(), repository: mine, links: RecordingRfqLinks()),
            size: const Size(390, 3200),
          );
          await settled(tester);
          expectNoFailure(tester);
          expect(key('my-reply'), findsOneWidget);
          expect(find.text('Your reply'), findsOneWidget);
          expect(find.text('₹4,50,000'), findsWidgets);
          expect(find.text('7 days'), findsOneWidget);
          expect(find.text('Vivek here: we can mobilise within a week.'), findsOneWidget);
          expect(find.text('Our quotation'), findsOneWidget);
          expect(key('reply-edit'), findsNothing, reason: 'the portal has no call to change a bid');
          expect(key('reply-withdraw'), findsNothing);
          expect(key('reply-form'), findsNothing, reason: 'one reply per requirement');
          expect(key('bid-changes-note'), findsOneWidget, reason: 'the page says why there is no Edit or Withdraw');
          expect(find.textContaining('message the buyer'), findsWidgets);
          expect(key('see-all-bids'), findsOneWidget);
          expect(find.text('Sunrise Facilities Pvt Ltd'), findsWidgets);
          await finishLive(tester);
        } finally {
          await tester.runAsync(() => buyer.deleteDraft(posted.id));
        }
      },
    );

    testWidgets(
      'a reply typed into the real form with a file goes to the API and is read back (Bluepeak)',
      tags: const ['live'],
      (tester) async {
        if (!await liveScreenReady(tester)) return;
        final buyer = await _repoT(tester, sunrise);
        final mine = await _repoT(tester, bluepeak);
        final posted = (await tester.runAsync(() => _post(buyer, deleteAtEnd: false)))!;
        try {
          final links = RecordingRfqLinks()..toPick = [PickedRfqFile(name: 'quotation.pdf', bytes: _pdf('form'))];
          await pumpLive(
            tester,
            OpportunityScreen(posted.id, key: UniqueKey(), repository: mine, links: links),
            size: const Size(390, 3200),
          );
          await settled(tester);
          expectNoFailure(tester);
          expect(find.text('Reply to this enquiry'), findsOneWidget);
          expect(find.text("Replying to an enquiry doesn't use your monthly bids."), findsOneWidget);

          // Too short a reply is said before anything is sent.
          await tapKey(tester, 'reply-send');
          expect(find.text('Write a reply, or give an indicative price'), findsOneWidget);
          expect((await tester.runAsync(() => mine.opportunity(posted.id)))!.myBid, isNull);

          await type(tester, 'reply-message', 'We can mobilise within a week with a supervisor on site.');
          await type(tester, 'reply-amount', '5,90,000');
          await type(tester, 'reply-lead', '10');
          await tapKey(tester, 'attach-add');
          expect(key('file-row-0'), findsOneWidget, reason: 'the file went up as it was chosen');
          await type(tester, 'file-title-0', 'Priced quotation');
          await tapKey(tester, 'reply-send');
          expectNoFailure(tester);
          expect(key('my-reply'), findsOneWidget);
          expect(find.text('Your reply was sent.'), findsOneWidget);
          expect(find.text('Priced quotation'), findsOneWidget);

          final stored = (await tester.runAsync(() => buyer.bids(posted.id)))!.single;
          expect(stored.amount, 590000);
          expect(stored.leadTimeDays, 10);
          expect(stored.message, 'We can mobilise within a week with a supervisor on site.');
          expect(stored.files.single.title, 'Priced quotation');
          await finishLive(tester);
        } finally {
          await tester.runAsync(() => buyer.deleteDraft(posted.id));
        }
      },
    );

    testWidgets(
      'an unverified supplier sees the API\'s refusal in the form, and the form keeps what was typed (GreenShield)',
      tags: const ['live'],
      (tester) async {
        if (!await liveScreenReady(tester)) return;
        final buyer = await _repoT(tester, sunrise);
        final mine = await _repoT(tester, greenShield);
        final posted = (await tester.runAsync(() => _post(buyer, deleteAtEnd: false)))!;
        try {
          await pumpLive(
            tester,
            OpportunityScreen(posted.id, key: UniqueKey(), repository: mine, links: RecordingRfqLinks()),
            size: const Size(390, 3200),
          );
          await settled(tester);
          expectNoFailure(tester);
          expect(
            find.textContaining('must be verified before you can respond'),
            findsOneWidget,
            reason: 'said up front',
          );
          await type(tester, 'reply-message', 'We would like to reply.');
          await tapKey(tester, 'reply-send');
          expect(key('reply-error'), findsOneWidget);
          expect(find.descendant(of: key('reply-error'), matching: find.textContaining('verified')), findsOneWidget);
          expect(tester.widget<TextField>(key('reply-message')).controller!.text, 'We would like to reply.');
          // Read back from the buyer's side (the screen's own connection is left alone after its refusal).
          expect(await tester.runAsync(() => buyer.bids(posted.id)), isEmpty, reason: 'no reply was left behind');
          await finishLive(tester);
        } finally {
          await tester.runAsync(() => buyer.deleteDraft(posted.id));
        }
      },
    );

    testWidgets(
      'an invitation is read in the form, declined from the page, and the page keeps the decline (Vivek)',
      tags: const ['live'],
      (tester) async {
        if (!await liveScreenReady(tester)) return;
        final vivek = _vivekOrSkip();
        if (vivek == null) return;
        final buyer = await _repoT(tester, sunrise);
        final mine = await _repoT(tester, vivek);
        final id = (await tester.runAsync(
          () => buyer.create({
            'title': 'zz live vendor invite screen',
            'kind': 'ENQUIRY',
            'status': 'PUBLISHED',
            'visibility': 'TARGETED',
            'vendorIds': [vivekVendorId],
            'description': 'Please quote for weekly deep cleaning of two floors in Pune.',
            'category': 'FACILITY_MANAGEMENT',
          }),
        ))!.id;
        try {
          await pumpLive(
            tester,
            OpportunityScreen(id, key: UniqueKey(), repository: mine, links: RecordingRfqLinks()),
            size: const Size(390, 3200),
          );
          await settled(tester);
          expectNoFailure(tester);
          expect(find.textContaining("You've been invited to reply"), findsOneWidget);
          await tapKey(tester, 'reply-decline');
          expect(find.text('Decline this invitation?'), findsOneWidget, reason: 'it asks first');
          await tester.tap(find.text('Decline').last);
          await settled(tester);
          expect(find.text('Invitation declined'), findsOneWidget);
          expect(key('reply-form'), findsNothing);

          // Read again from the API: still declined, and on the Invited tab of the board it is gone.
          await pumpLive(
            tester,
            OpportunityScreen(id, repository: mine, links: RecordingRfqLinks(), key: UniqueKey()),
            size: const Size(390, 3200),
          );
          await settled(tester);
          expect(find.text('Invitation declined'), findsOneWidget);
          await finishLive(tester);
        } finally {
          await tester.runAsync(() => buyer.deleteDraft(id));
        }
      },
    );

    testWidgets(
      'a company with no supplier listing is offered Start selling, with the sentence that says what it does (Maya of Meridian)',
      tags: const ['live'],
      (tester) async {
        if (!await liveScreenReady(tester)) return;
        final repo = await _repoT(tester, meridian);
        for (final screen in <Widget>[
          OpenRequirementsScreen(key: UniqueKey(), repository: repo, links: RecordingRfqLinks()),
          MyBidsScreen(key: UniqueKey(), repository: repo, links: RecordingRfqLinks()),
        ]) {
          await pumpLive(tester, screen, size: const Size(390, 900));
          await settled(tester);
          expectNoFailure(tester);
          expect(find.textContaining('Start selling to '), findsOneWidget);
          expect(
            find.text('Your company has no supplier listing yet. One tap creates it from your company profile.'),
            findsOneWidget,
          );
          expect(find.text('Start selling'), findsOneWidget);
        }
        await finishLive(tester);
      },
    );
  });

  // =========================================================================================================
  group('Starting to sell', () {
    liveTest(
      "'Start selling' makes the company's listing from its profile in one call, the gate lifts, and staff take it away again (Maya of Meridian)",
      () async {
        final staff = _superAdminOrSkip();
        if (staff == null) return;
        final repo = await _repo(meridian);
        // Meridian is shared with the other roles' runs: if one of them holds its listing right now, wait a moment
        // for it to give it back, and skip (never delete a listing this test did not make) if it does not.
        var before = await repo.access();
        if (before.hasListing) {
          await Future<void>.delayed(const Duration(seconds: 15));
          before = await repo.access();
        }
        if (before.hasListing) {
          markTestSkipped('Meridian sells right now: another run holds its listing');
          return;
        }
        String? vendorId;
        addTearDown(() async {
          // The staff delete is a soft delete; the next "Start selling" revives the row.
          vendorId ??= (await repo.access()).vendorId;
          if (vendorId != null) await (await liveClient(staff)).dio.delete<dynamic>('/vendors/$vendorId');
        });

        final board = SupplierBoardController(repo);
        addTearDown(board.dispose);
        await board.start();
        expect(board.gate, SupplierGate.noListing);
        expect(board.rows, isEmpty);
        expect(
          await board.startSellingAndReload(),
          isNull,
          reason: "the listing is made from the company's own profile",
        );
        vendorId = board.access!.vendorId;
        expect(board.gate, isNull, reason: 'the board is shown in its place');
        expect(board.access!.hasListing, isTrue);
        expect(board.error, isNull);
        // A company verified by employer KYC starts as a Verified supplier; one that is not starts at Registered and
        // may read the board while it waits for the supplier review.
        expect(
          board.access!.verified,
          board.access!.listingStartsVerified || board.access!.verificationLevel != 'REGISTERED',
        );
        expect(board.query.matchedOnly, isTrue);
        await board.setTab(BoardTab.open);
        expect(board.rows, isNotEmpty, reason: 'a new listing can read the open board');
        // A second tap changes nothing: the API hands back the listing it has.
        expect(await board.startSellingAndReload(), isNull);
        expect(board.access!.vendorId, vendorId);
      },
    );
  });

  // =========================================================================================================
  group('The bell, the inbox and the Marketplace as screens', () {
    Finder key(String k) => find.byKey(ValueKey(k));

    testWidgets(
      'a supplier taps each requirement notice and is taken to that requirement\'s supplier page (Bluepeak)',
      tags: const ['live'],
      (tester) async {
        if (!await liveScreenReady(tester)) return;
        final api = (await tester.runAsync(() => liveClient(bluepeak)))!;
        final repo = ApiNotificationsRepository(api: api);
        const requirement = {
          'bid_awarded',
          'bid_rejected',
          'rfq_invite',
          'enquiry_match',
          'rfq_quotes_open',
          'shortlisted',
        };
        final first = (await tester.runAsync(repo.list))!;
        // One notice of each requirement type the first page holds.
        final byType = <String, AppNotification>{};
        for (final n in first.items) {
          if (requirement.contains(n.type) && n.link != null) byType.putIfAbsent(n.type, () => n);
        }
        expect(byType, isNotEmpty, reason: 'run tool/seed/rfq.ts: Bluepeak holds requirement notices');

        final opened = <NotificationTarget>[];
        await pumpLive(
          tester,
          NotificationsScreen(
            key: UniqueKey(),
            repository: repo,
            onOpenTarget: (context, target) async => opened.add(target),
          ),
          size: const Size(390, 2400),
        );
        await settled(tester);
        expect(tester.takeException(), isNull);
        expect(find.text('Notifications'), findsWidgets);
        for (final n in byType.values) {
          final row = key('notification-${n.id}');
          await tester.ensureVisible(row);
          await tester.tap(row);
          await settled(tester);
          final target = opened.last;
          expect(target.kind, NotificationKinds.rfqSupplier, reason: '${n.type}: ${n.link}');
          expect(target['rfqId'], isNotEmpty, reason: n.link);
        }
        expect(opened, hasLength(byType.length));
        await finishLive(tester);

        // And the page it names opens: the supplier's page of that requirement, never an error.
        final seen = <String>{};
        for (final t in opened) {
          final id = t['rfqId']!;
          if (!seen.add(id)) continue;
          final page = ApiRfqRepository(api: (await tester.runAsync(() => liveClient(bluepeak)))!);
          await pumpLive(
            tester,
            OpportunityScreen(id, key: UniqueKey(), repository: page, links: RecordingRfqLinks()),
            size: const Size(390, 3200),
          );
          await settled(tester);
          expect(tester.takeException(), isNull, reason: id);
          final shown =
              key('response-card').evaluate().isNotEmpty ||
              find.text('This requirement is not available').evaluate().isNotEmpty;
          expect(shown, isTrue, reason: 'the page of $id says what the supplier can do, or that it is gone');
          expect(find.textContaining("Couldn't load"), findsNothing, reason: id);
          await finishLive(tester);
        }
      },
    );

    testWidgets(
      "Alerts draws a supplier's requirement alerts, and a tap opens the supplier's page of that requirement, never the buyer's (Bluepeak)",
      tags: const ['live'],
      (tester) async {
        if (!await liveScreenReady(tester)) return;
        final repo = await _repoT(tester, bluepeak);
        final alerts = (await tester.runAsync(repo.alerts))!;
        final pick = alerts.firstWhere((a) => a.side == AlertSide.supplier && a.rfqId != null);
        await pumpLive(
          tester,
          RfqAlertsScreen(key: UniqueKey(), repository: repo, links: RecordingRfqLinks()),
          size: const Size(390, 2400),
        );
        await settled(tester);
        expect(tester.takeException(), isNull);
        expect(find.text('Alerts'), findsWidgets);
        final tile = find.byKey(ValueKey('alert-${pick.id}'));
        expect(tile, findsOneWidget, reason: pick.title);
        await tester.ensureVisible(tile);
        await tester.tap(tile);
        await settled(tester);
        expect(tester.takeException(), isNull);
        expect(find.byType(OpportunityScreen), findsOneWidget, reason: 'the supplier page, not the owner page');
        expect(find.text('Requirement'), findsOneWidget);
        final shown =
            find.byKey(const ValueKey('response-card')).evaluate().isNotEmpty ||
            find.text('This requirement is not available').evaluate().isNotEmpty;
        expect(shown, isTrue);
        expect(find.textContaining("Couldn't load"), findsNothing);
        await finishLive(tester);
      },
    );

    testWidgets(
      'a notice with no page of its own in the app (an advertising placement, a team request) is read and left to the website (Vivek)',
      tags: const ['live'],
      (tester) async {
        if (!await liveScreenReady(tester)) return;
        final vivek = _vivekOrSkip();
        if (vivek == null) return;
        final repo = ApiNotificationsRepository(api: (await tester.runAsync(() => liveClient(vivek)))!);
        // Every page he holds: the newest notices are about requirements, the older ones about his listing.
        final all = <AppNotification>[];
        for (var page = 1; page <= 6; page++) {
          final p = (await tester.runAsync(() => repo.list(page: page)))!;
          all.addAll(p.items);
          if (!p.hasMore) break;
        }
        expect(all, isNotEmpty);
        // The router lets the website take what no screen of the app registered for.
        final sites = <String>[];
        final router = NotificationRouter(openSite: (context, path) async => sites.add(path));
        for (final n in all) {
          final target = NotificationTarget.parse(n.link);
          if (target.kind == NotificationKinds.advertise ||
              target.kind == NotificationKinds.team ||
              target.kind == NotificationKinds.membershipHistory) {
            await pumpLive(
              tester,
              Builder(
                builder: (context) {
                  return TextButton(onPressed: () => router.open(context, target), child: const Text('go'));
                },
              ),
            );
            await tester.tap(find.text('go'));
            await tester.pump();
            expect(sites.last, n.link, reason: '${n.type} opens the website page the API stored');
          }
        }
        expect(sites, isNotEmpty, reason: 'Vivek holds notices of those kinds');
        await finishLive(tester);
      },
    );

    testWidgets(
      'the company inbox of each supplier draws its views and topics, and a thread opens as the company (Vikram)',
      tags: const ['live'],
      (tester) async {
        if (!await liveScreenReady(tester)) return;
        final vivek = _vivekOrSkip();
        if (vivek == null) return;
        Future<MessagingRepository> messaging(LivePerson who) async =>
            ApiMessagingRepository(api: (await tester.runAsync(() => liveClient(who)))!);

        // Vivek and Bluepeak: the inbox draws (nothing is opened, so nothing is read).
        for (final (who, name, company) in [
          (vivek, 'E2E Test Vendor Co', vivekCompanyId),
          (bluepeak, 'Bluepeak Security', 'design-rfq-co-bluedot'),
        ]) {
          final repo = await messaging(who);
          await pumpLive(
            tester,
            Provider<MessagingRepository>.value(
              value: repo,
              child: InboxScreen(key: UniqueKey(), repository: repo, initialInbox: company, poll: false),
            ),
            size: const Size(390, 1200),
          );
          await pumpUntilFound(tester, find.text('My messages'));
          await settled(tester);
          expect(tester.takeException(), isNull, reason: who.label);
          expect(find.text('My messages'), findsOneWidget, reason: who.label);
          expect(find.text(name), findsWidgets, reason: who.label);
          for (final view in ['Open', 'Unread', 'Mine', 'Done', 'Spam']) {
            expect(find.text(view), findsWidgets, reason: '${who.label}: $view');
          }
          expect(find.text('Sales & quotes'), findsWidgets, reason: '${who.label}: the topic chip');
          expect(find.text('Requirements & buying'), findsWidgets);
          expect(find.byType(ConversationTile), findsWidgets, reason: '${who.label} has threads');
          await finishLive(tester);
        }

        // Vikram: open a thread; the composer answers as the company.
        final repo = await messaging(vikram);
        await pumpLive(
          tester,
          Provider<MessagingRepository>.value(
            value: repo,
            child: InboxScreen(key: UniqueKey(), repository: repo, initialInbox: vikramCompanyId, poll: false),
          ),
          size: const Size(390, 1200),
        );
        await pumpUntilFound(tester, find.text('Bengaluru Care 101'));
        await settled(tester);
        expect(find.text('Bengaluru Care 101'), findsWidgets);
        final thread = tester.widget<ConversationTile>(find.byType(ConversationTile).first).conversation;
        expect(thread.asCompanyId, vikramCompanyId);
        await finishLive(tester);

        // The thread the row opens, read as the company: the composer answers as the company.
        await pumpLive(
          tester,
          ConversationScreen(
            key: UniqueKey(),
            conversationId: thread.id,
            asCompanyId: thread.asCompanyId,
            initial: thread,
            repository: repo,
            poll: false,
          ),
          size: const Size(390, 1200),
        );
        await pumpUntilFound(tester, find.text('Replying as Bengaluru Care 101'));
        await settled(tester);
        expect(tester.takeException(), isNull);
        expect(find.text('Replying as Bengaluru Care 101'), findsOneWidget);
        await finishLive(tester);
      },
    );

    testWidgets(
      'the owner opens their own listing as buyers see it; rating it is refused in the API\'s words and the sheet keeps the stars (Vivek)',
      tags: const ['live'],
      (tester) async {
        if (!await liveScreenReady(tester)) return;
        final vivek = _vivekOrSkip();
        if (vivek == null) return;
        final repo = ApiMarketplaceRepository(api: (await tester.runAsync(() => liveClient(vivek)))!);
        tester.view.physicalSize = const Size(390, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    key: const ValueKey('open'),
                    onPressed: () =>
                        showSupplierSheetById(context, vivekVendorId, tab: SupplierTab.proofs, repository: repo),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(key('open'));
        await pumpUntilFound(tester, find.text('Rate this supplier'));
        await settled(tester);
        expect(tester.takeException(), isNull);
        expect(find.textContaining('E2E Test Vendor Co'), findsWidgets);
        expect(find.text('42 Enterprise Reviews'), findsWidgets, reason: 'the count a buyer reads');
        expect(find.text('Request for Quote (RFQ)'), findsOneWidget);
        expect(find.text('Compliances & Audited Proofs'), findsOneWidget);
        expect(find.text('Rate this supplier'), findsOneWidget, reason: 'the sheet is the one a buyer sees');

        await tester.tap(find.text('Rate this supplier'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 900)); // the sheet slides in
        await tester.tap(key('star-5'));
        await tester.pump();
        await tester.enterText(key('rating-comment'), 'Our own listing');
        await tester.pump();
        await tester.tap(key('rating-send'));
        await pumpUntilFound(tester, key('rating-error'));
        await settled(tester);
        expect(find.byKey(const ValueKey('rating-error')), findsOneWidget);
        expect(find.text('You cannot rate your own listing.'), findsOneWidget, reason: 'the API\'s own sentence');
        expect(
          tester.widget<TextField>(key('rating-comment')).controller!.text,
          'Our own listing',
          reason: 'what was typed stays',
        );
        await finishLive(tester);
      },
    );
  });

  // =========================================================================================================
  group("Plan limits, said in the API's own words", () {
    liveTest('the free plan counts its monthly quotes on the quote page, and a quote spends one (SecureNet)', () async {
      final buyer = await _repo(sunrise);
      final mine = await _repo(secureNet);
      final before = (await mine.access()).bidsUsed;
      final id = await _toQuotation(buyer, [secureNet]);
      final page = await _page(secureNet, id);
      expect(page.state, ResponseState.form);
      expect(page.allowance, '$before of 3 bids used this month.');
      expect(page.blocker, isNull);
      expect(await page.placeBid(BidDraft()..amount = '4,00,000'), isNull);
      expect((await mine.access()).bidsUsed, before + 1);
      expect(page.state, ResponseState.sent);
    });

    liveTest(
      "an unverified listing is refused a reply in the API's words, which the form shows (GreenShield)",
      () async {
        final buyer = await _repo(sunrise);
        final posted = await _post(buyer);
        final page = await _page(greenShield, posted.id);
        expect(page.blocker, 'Your supplier listing must be verified before you can respond.');
        final refusal = await page.placeBid(BidDraft()..message = 'We would like to reply.');
        expect(refusal, 'Your company must be verified to bid.', reason: "the API's sentence, not a rewording");
        expect(page.myBid, isNull);
      },
    );
  });

  // =========================================================================================================
  group('Open bugs, kept visible', () {
    test(
      'a supplier can reach Find work and My Bids from the app',
      () {
        final doors = inAppScreens(viewer: DemoFeedRepository.me, demo: true);
        expect(doors.keys, contains('/manage/bids'), reason: 'Find work has a door');
        expect(doors.keys, contains('/manage/bids/mine'), reason: 'My Bids has a door');
      },
      skip:
          'open bug 1 of docs/ROLE_TEST_vendor.md: nothing in the shell, the Discover sheet or the profile drawer '
          'opens Find work or My Bids (pushBoard and pushMyBids are called only from inside the rfq folder)',
    );
  });
}
