/// The Requirements board (everything posted on ICR, the website's `/rfq`) against the LOCAL portal API, through the
/// app's own repository and controller. It is the same list for every reader; who reads decides only where a card
/// opens and which chips the toolbar offers.
///
/// Personas: Bhavya of Sunrise Facilities (`tool/seed/rfq.ts`), Bela of Bluepeak (a supplier), Pooja (no company),
/// and the e2e recruiter (`irc-portal/e2e/fixtures/users.json`; skipped without it). The one write, a requirement
/// Sunrise posts to see it on the board, is deleted when the test ends.
///
///     flutter test test/live/rfq_posted_live_test.dart --concurrency=1
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/features/rfq/api_rfq_repository.dart';
import 'package:icr_mobile/features/rfq/post_rfq_controller.dart';
import 'package:icr_mobile/features/rfq/requirements_board_controller.dart';
import 'package:icr_mobile/features/rfq/rfq_models.dart';

import 'live.dart';
import 'role_company_support.dart' show recruiter;

const _password = 'Rfq@12345';
const _sunrise = LivePerson('rfq.buyer@rfq-design.icr.test', _password, 'Bhavya Buyer (Sunrise)');
const _bluepeak = LivePerson('rfq.bluedot@rfq-design.icr.test', _password, 'Bela (Bluepeak, Gold)');

/// A seeded requirement of Sunrise's, public and live.
const _sunriseCctv = 'design-rfq-s-cctv';

Future<ApiRfqRepository> _repo(LivePerson who) async => ApiRfqRepository(api: await liveClient(who));

Future<RequirementsBoardController> _board(LivePerson who, {int? pageSize}) async {
  final repo = await _repo(who);
  final c = pageSize == null
      ? RequirementsBoardController(repo)
      : RequirementsBoardController(repo, pageSize: pageSize);
  await c.start();
  expect(c.error, isNull, reason: '${who.label}: ${c.error}');
  return c;
}

/// Every row of the board, page by page.
Future<List<Requirement>> _all(RequirementsBoardController c) async {
  while (c.hasMore) {
    final before = c.rows.length;
    await c.loadMore();
    if (c.rows.length == before) break;
  }
  return c.rows;
}

void main() {
  group('the board is everything posted, for every reader', () {
    liveTest('a person with no company sees every public requirement in every status, drafts never', () async {
      final c = await _board(pooja);
      expect(c.total, greaterThan(0));
      expect(c.total, lessThanOrEqualTo(c.pageSize), reason: 'the board reads one page of 100 (§3); past that it says it shows only the newest');
      final rows = await _all(c);
      expect(rows, hasLength(c.total), reason: 'the board holds every one the API counts');
      expect(rows.map((r) => r.id).toSet(), hasLength(rows.length), reason: 'no row twice');
      expect(rows.every((r) => r.status != RfqStatus.draft), isTrue);
      expect(rows.every((r) => r.visibility == RfqVisibility.public), isTrue);
      // The list is newest first.
      final dates = [for (final r in rows) r.createdAt!];
      for (var i = 1; i < dates.length; i++) {
        expect(dates[i].isAfter(dates[i - 1]), isFalse, reason: 'row $i is older than row ${i - 1}');
      }
      // The buyer is named on every card.
      expect(rows.where((r) => r.buyer != null), isNotEmpty);
      // Ended ones are on it too.
      expect(rows.map((r) => r.status).toSet(), containsAll([RfqStatus.published, RfqStatus.awarded]));
      c.dispose();
    });

    liveTest(
      "the portal's list answers every page with the first (backend-requests/rfq.md §3), and the board stops there",
      () async {
        final repo = await _repo(pooja);
        final first = await repo.posted(limit: 5);
        expect(first.hasMore, isTrue, reason: 'needs more than five posted');
        final second = await repo.posted(page: 2, limit: 5);
        // When §3 ships this flips: page two holds the next five, and the board pages through them all.
        expect(second.rows.map((r) => r.id), first.rows.map((r) => r.id), reason: 'page 2 repeats page 1 today');

        final c = RequirementsBoardController(repo, pageSize: 5);
        await c.start();
        await c.loadMore();
        expect(c.rows, hasLength(5));
        expect(c.hasMore, isFalse, reason: 'a page with nothing new stops the paging');
        c.dispose();
      },
    );

    liveTest('each tab is one status, and the tabs add up to no more than All', () async {
      final c = await _board(pooja, pageSize: 100);
      final all = c.total;
      var sum = 0;
      for (final tab in [PostedTab.open, PostedTab.awarded, PostedTab.closed]) {
        await c.setTab(tab);
        expect(c.error, isNull);
        final rows = await _all(c);
        expect(rows.every((r) => r.status == tab.status), isTrue, reason: tab.label);
        sum += c.total;
      }
      expect(sum, lessThanOrEqualTo(all), reason: 'cancelled ones are under All only');
      c.dispose();
    });

    liveTest('a search is the API\'s, over titles and descriptions', () async {
      final c = await _board(pooja);
      await c.setSearch('CCTV');
      expect(c.error, isNull);
      expect(c.rows, isNotEmpty);
      expect(c.total, lessThan((await _board(pooja)).total));
      c.dispose();
    });

    liveTest('a recruiter reads the same list, is offered nothing to post, and runs none of it', () async {
      final everyone = await _board(pooja, pageSize: 100);
      final c = await _board(recruiter, pageSize: 100);
      expect(c.total, everyone.total);
      expect(c.offersPost, isFalse);
      expect(c.offersMine, isFalse);
      expect(c.offersFindWork, isFalse);
      expect(c.rows.where(c.manages), isEmpty);
      c.dispose();
      everyone.dispose();
    });
  });

  group('where a card opens', () {
    liveTest("Sunrise's buyer runs Sunrise's requirements, and a supplier reads them", () async {
      final buyer = await _board(_sunrise, pageSize: 100);
      final rows = await _all(buyer);
      final cctv = rows.firstWhere((r) => r.id == _sunriseCctv);
      expect(buyer.manages(cctv), isTrue);
      expect(buyer.poster?.role, 'COMPANY_ADMIN');
      expect(buyer.offersPost && buyer.offersMine && buyer.offersFindWork, isTrue, reason: 'a company buys and sells');
      expect(rows.where((r) => r.companyId != cctv.companyId).where(buyer.manages), isEmpty);

      final supplier = await _board(_bluepeak, pageSize: 100);
      final seen = (await _all(supplier)).firstWhere((r) => r.id == _sunriseCctv);
      expect(supplier.manages(seen), isFalse);
      expect(supplier.offersFindWork, isTrue);
      buyer.dispose();
      supplier.dispose();
    });
  });

  liveTest('a requirement is on the board the moment it is published, and never as a draft', () async {
    final repo = await _repo(_sunrise);
    final c = PostRfqController(repository: repo, initialKind: RfqKind.enquiry);
    await c.start();
    final pune = (await c.searchPlaces('Pune')).first;
    expect(c.addPlace(pune), isTrue);
    c.update(
      (d) => d
        ..facilityType = 'IT & ITES'
        ..category = 'SECURITY'
        ..subcategory = 'PHYSICAL_SECURITY'
        ..text = 'Round-the-clock guarding for a Pune campus: 24 guards, three shifts, from 1 December.'
        ..budget = '6,50,000',
    );
    final title = 'zz posted ${DateTime.now().millisecondsSinceEpoch}';
    c.setTitle(title);
    expect(await c.submit(publish: false), isTrue, reason: c.error ?? '${c.problems}');
    final id = c.result!.id;
    addTearDown(() async {
      try {
        await repo.deleteDraft(id);
      } catch (_) {}
    });

    final reader = await _board(pooja);
    await reader.setSearch(title);
    expect(reader.rows, isEmpty, reason: 'a draft is its poster\'s alone');

    await repo.act(id, RfqAction.publish);
    await reader.refresh();
    expect(reader.rows.map((r) => r.id), [id]);
    await reader.setSearch('');
    expect(reader.rows.first.id, id, reason: 'the newest is first');
    reader.dispose();
  });
}
