/// The requirements (RFQ) screens against the LOCAL portal API: the app's own repository and controllers, the
/// way the screens use them, with every effect read back through the API.
///
/// Personas (`tool/seed/rfq.ts` creates them: run it first, `tool/seed/README.md`):
///  - Bharat Buyer (`buyer@icr.dev`, the emulator's person) has no company, so the API lets him read and manage
///    his five seeded requirements but not post: the reading flows use him.
///  - Bhavya Buyer of Sunrise Facilities posts, edits, invites, shortlists and awards: the writing flows use her.
///  - Bela of Bluepeak Security (Gold plan, unlimited bids) is the supplier; Sana of SecureNet is on the free
///    plan (3 RFQ quotes a month); Gita of GreenShield is not verified.
///
/// Every write this file makes is undone: a requirement a test posts is deleted by the test (which takes its bids
/// and invitations with it), so the run can be repeated. What cannot be undone through the API (a notification
/// read, a thread opened) is left, and `tool/seed/rfq.ts --remove` clears it.
///
///     flutter test test/live/rfq_live_test.dart --concurrency=1
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/features/rfq/api_rfq_repository.dart';
import 'package:icr_mobile/features/rfq/my_rfqs_controller.dart';
import 'package:icr_mobile/features/rfq/post_rfq_controller.dart';
import 'package:icr_mobile/features/rfq/rfq_detail_controller.dart';
import 'package:icr_mobile/features/rfq/rfq_links.dart' show PickedRfqFile;
import 'package:icr_mobile/features/rfq/rfq_models.dart';
import 'package:icr_mobile/features/rfq/rfq_rules.dart';
import 'package:icr_mobile/features/rfq/supplier_controllers.dart';
import 'package:icr_mobile/features/rfq/widgets/response_parts.dart' show mentionsPlan;

import 'live.dart';

const _password = 'Rfq@12345';
const sunrise = LivePerson('rfq.buyer@rfq-design.icr.test', _password, 'Bhavya Buyer (Sunrise)');
const bluepeak = LivePerson('rfq.bluedot@rfq-design.icr.test', _password, 'Bela (Bluepeak, Gold)');
const innova = LivePerson('rfq.innowork@rfq-design.icr.test', _password, 'Ivan (Innova, Gold)');
const secureNet = LivePerson('rfq.securetech@rfq-design.icr.test', _password, 'Sana (SecureNet, free)');
const greenShield = LivePerson('rfq.greenguard@rfq-design.icr.test', _password, 'Gita (GreenShield, unverified)');

Future<ApiRfqRepository> _repo(LivePerson who) async => ApiRfqRepository(api: await liveClient(who));

/// A seeded requirement of Bharat's.
const security = 'design-rfq-security';
const ifm = 'design-rfq-ifm';
const home = 'design-rfq-home';
const lifts = 'design-rfq-lifts';
const hvac = 'design-rfq-hvac';

/// A seeded requirement of Sunrise's.
const sCctv = 'design-rfq-s-cctv';
const sGuarding = 'design-rfq-s-guarding';
const sFacade = 'design-rfq-s-facade';
const sCafeteria = 'design-rfq-s-cafeteria';

/// A tiny, real PDF to attach.
List<int> _pdf() => '%PDF-1.4\n1 0 obj << /Type /Catalog >> endobj\ntrailer << /Root 1 0 R >>\n%%EOF\n'.codeUnits;

DateTime _inDays(int n) => todayIst().add(Duration(days: n));

/// A requirement posted as Sunrise through the composer's own controller, and deleted when the test ends (which
/// takes its bids, invitations and responses with it).
Future<PostResult> _post(
  ApiRfqRepository repo, {
  RfqKind kind = RfqKind.enquiry,
  bool publish = true,
  void Function(RequirementDraft d)? tweak,
}) async {
  final c = PostRfqController(repository: repo, initialKind: kind);
  await c.start();
  expect(c.loadError, isNull);
  expect(c.mustRegisterCompany, isFalse);
  expect(c.companyFromAccount, 'Sunrise Facilities Pvt Ltd');
  final pune = (await c.searchPlaces('Pune')).first;
  expect(c.addPlace(pune), isTrue);
  c.update((d) {
    d
      ..facilityType = 'IT & ITES'
      ..category = 'SECURITY'
      ..subcategory = 'PHYSICAL_SECURITY'
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
  c.setTitle('zz live ${DateTime.now().millisecondsSinceEpoch}');
  final ok = await c.submit(publish: publish);
  expect(ok, isTrue, reason: c.error ?? '${c.problems}');
  final result = c.result!;
  addTearDown(() async {
    try {
      await repo.deleteDraft(result.id);
    } catch (_) {
      // Already gone.
    }
  });
  return result;
}

/// The supplier's page controller, loaded.
Future<OpportunityController> _page(LivePerson who, String id) async {
  final c = OpportunityController(repository: await _repo(who), rfqId: id);
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

/// The message of the error a call throws, or null when it went through.
Future<String?> _refusal(Future<Object?> call) async {
  try {
    await call;
    return null;
  } catch (e) {
    return ApiError.from(e).message;
  }
}

Matcher _status(int code) => throwsA(isA<Object>().having((e) => ApiError.from(e).statusCode, 'status', code));

void main() {
  group('Reading as Bharat (a buyer with no company)', () {
    liveTest('who is asking: the person, and no company', () async {
      final me = await (await _repo(bharat)).me();
      expect(me.email, 'buyer@icr.dev');
      expect(me.name, 'Bharat Buyer');
      expect(me.role, 'BUYER');
      expect(me.companyId, isNull);
      expect(me.hasPhone, isTrue);
      expect(me.canPost, isTrue);
    });

    liveTest('the counts on the tabs add up to what the list holds', () async {
      final repo = await _repo(bharat);
      final s = await repo.summary();
      expect(s.count(MyView.all), greaterThanOrEqualTo(6));
      expect(s.count(MyView.live), greaterThanOrEqualTo(3));
      expect(s.count(MyView.draft), greaterThanOrEqualTo(1));
      expect(s.count(MyView.awarded), greaterThanOrEqualTo(1));
      expect(s.count(MyView.ended), greaterThanOrEqualTo(1));
      expect(s.enquiries + s.rfqs, s.count(MyView.all));
      expect(s.actionItems.map((a) => a.rfqId), containsAll([ifm, security]));
      final screen = s.actionItems.firstWhere((a) => a.rfqId == ifm);
      expect(screen.kind, 'SCREEN');
      expect(screen.count, 2);
      expect(screen.rfqKind, RfqKind.rfq);
      expect(screen.deadline, isNotNull);
      expect(s.actionCount, s.actionItems.length);
      // "My RFQ's n": every requirement the list opens on, whatever its status.
      expect(s.open, s.count(MyView.all));
      expect((await repo.counts()).myRfqs, s.open);
    });

    liveTest('every view lists the rows its tab counts, and each row is what the tab says', () async {
      final repo = await _repo(bharat);
      final s = await repo.summary();
      final expected = <MyView, bool Function(Requirement)>{
        MyView.live: (r) => r.status == RfqStatus.published,
        MyView.draft: (r) => r.status == RfqStatus.draft,
        MyView.awarded: (r) => r.status == RfqStatus.awarded,
        MyView.ended: (r) => r.status == RfqStatus.closed || r.status == RfqStatus.cancelled,
      };
      for (final entry in expected.entries) {
        final page = await repo.mine(view: entry.key);
        expect(page.total, s.count(entry.key), reason: entry.key.label);
        expect(page.rows.every(entry.value), isTrue, reason: entry.key.label);
      }
      final attention = await repo.mine(view: MyView.attention);
      expect(attention.rows.map((r) => r.id), containsAll([ifm, security]));
      expect(
        attention.rows.every((r) => (r.responses?.bidsPending ?? 0) + (r.responses?.prequalPending ?? 0) > 0),
        isTrue,
      );
    });

    liveTest('a row carries its counts, its kind, its places and who awarded what', () async {
      final repo = await _repo(bharat);
      final rows = {for (final r in (await repo.mine()).rows) r.id: r};
      final sec = rows[security]!;
      expect(sec.kind, RfqKind.enquiry);
      expect(sec.status, RfqStatus.published);
      expect(sec.responses!.bids, 3);
      expect(sec.responses!.bidsPending, 2, reason: 'one of the three is already shortlisted');
      expect(sec.responses!.invites, 4);
      expect(sec.quoteCount, 3);
      expect(sec.places, ['Mumbai']);
      expect(sec.dueDate, isNotNull);
      expect(sec.postedBy, isNull, reason: 'his own');
      final plan = rows[ifm]!;
      expect(plan.staged, isTrue);
      expect(plan.stage, RfqStage.prequalification);
      expect(plan.responses!.prequal, 2);
      expect(plan.responses!.prequalPending, 2);
      expect(plan.preQualEndDate, isNotNull);
      expect(rows[home]!.status, RfqStatus.draft);
      final done = rows[lifts]!;
      expect(done.status, RfqStatus.awarded);
      expect(done.awardedTo, isNotNull, reason: 'the company the purchase order went to');
      expect(done.stage, RfqStage.completed);
      expect(rows[hvac]!.status, RfqStatus.closed);
    });

    liveTest('search, type, sort and paging are accepted and keep to what they say', () async {
      final repo = await _repo(bharat);
      final found = await repo.mine(search: 'security');
      expect(found.rows, isNotEmpty);
      for (final r in found.rows) {
        expect('${r.title} ${r.description ?? ''}'.toLowerCase(), contains('security'));
      }
      expect((await repo.mine(search: 'zzqx-nothing-like-this')).rows, isEmpty);
      for (final r in (await repo.mine(kind: RfqKind.rfq)).rows) {
        expect(r.kind, RfqKind.rfq);
      }
      for (final r in (await repo.mine(kind: RfqKind.enquiry)).rows) {
        expect(r.kind, RfqKind.enquiry);
      }
      final titles = (await repo.mine(sort: MySort.title)).rows.map((r) => r.title.toLowerCase()).toList();
      expect(titles, [...titles]..sort());
      final newest = (await repo.mine(sort: MySort.newest)).rows.map((r) => r.createdAt!).toList();
      expect(newest, [...newest]..sort((a, b) => b.compareTo(a)));
      // Pages of two: the first says there is more, the next continues, and none repeats.
      final small = ApiRfqRepository(api: await liveClient(bharat), pageSize: 2);
      final first = await small.mine();
      expect(first.rows, hasLength(2));
      expect(first.hasMore, isTrue);
      expect(first.total, greaterThanOrEqualTo(6));
      final second = await small.mine(page: 2);
      expect(second.rows.map((r) => r.id).toSet().intersection(first.rows.map((r) => r.id).toSet()), isEmpty);
      expect((await small.mine(page: 99)).rows, isEmpty);
    });

    liveTest('a requirement read for the buyer carries its items, files, places and supplier criteria', () async {
      final repo = await _repo(bharat);
      final sec = await repo.requirement(security);
      expect(sec.items.map((i) => i.name), [
        'Security guards (24x7)',
        'Biometric access readers',
        'CCTV cameras, 4 MP',
      ]);
      expect(sec.items.map((i) => i.quantity), [12, 4, 48]);
      expect(sec.items[1].specification, isNotNull);
      expect(sec.files, hasLength(1));
      expect(sec.files.single.title, 'Site plan: Mumbai HQ');
      expect(sec.files.single.mimeType, 'application/pdf');
      expect(sec.files.single.isImage, isFalse);
      expect(sec.budget, 1200000);
      expect(sec.category, 'SECURITY');
      expect(sec.subcategory, 'PHYSICAL_SECURITY');
      expect(sec.facilityType, 'IT & ITES');
      expect(sec.state, 'Maharashtra');
      expect(sec.country, 'India');
      expect(sec.contactName, 'Bharat Buyer', reason: 'the owner reads the contact snapshot');
      expect(sec.contactPhone, isNotNull);
      expect(sec.quoteCount, 3);
      expect(sec.text, contains('Round-the-clock guarding'));

      final plan = await repo.requirement(ifm);
      expect(plan.criteria.minYearsInBusiness, 5);
      expect(plan.criteria.minAnnualTurnover, 50000000);
      expect(plan.criteria.minEmployees, '201-500');
      expect(plan.criteria.requiredPresence, Presence.panIndia);
      expect(plan.criteria.statutoryCompliance, ['GST', 'PF', 'ESI']);
      expect(plan.criteria.count, 5);
      expect(plan.preQualEndDate!.isBefore(plan.dueDate!), isTrue);
      expect(plan.text, contains('Integrated facility management'), reason: 'an RFQ reads its scope');
    });

    liveTest('the bids parse, with price, lead time and who sent them', () async {
      final repo = await _repo(bharat);
      final bids = await repo.bids(security);
      expect(bids, hasLength(3));
      final byName = {for (final b in bids) b.supplier.name: b};
      final blue = byName['Bluepeak Security']!;
      expect(blue.amount, 1140000);
      expect(blue.leadTimeDays, 10);
      expect(blue.status, BidStatus.pending);
      expect(blue.message, contains('PSARA-licensed'));
      expect(blue.supplier.rating, 4.8);
      expect(blue.supplier.ratingCount, 124);
      expect(blue.supplier.vendorId, 'design-rfq-v-bluedot');
      expect(blue.supplier.companyId, 'design-rfq-co-bluedot', reason: 'what "Message" names');
      expect(byName['Innova Facility Services']!.status, BidStatus.shortlisted);
      expect(bids.every((b) => b.rfqId == security && b.createdAt != null), isTrue);
    });

    liveTest('invitations and pre-qualification responses parse, with the API\'s verdict on the criteria', () async {
      final repo = await _repo(bharat);
      final invites = await repo.invites(security);
      expect(invites.map((i) => i.status).toSet(), {InviteStatus.responded, InviteStatus.invited});
      expect(invites.where((i) => i.status == InviteStatus.invited).single.supplier.name, 'GreenShield Services');

      final responses = await repo.responses(ifm);
      expect(responses, hasLength(2));
      final green = responses.firstWhere((r) => r.supplier.name == 'GreenShield Services');
      expect(green.meetsCriteria, isTrue);
      expect(green.failures, isEmpty);
      expect(green.yearsInBusiness, 11);
      expect(green.annualTurnover, 82000000);
      expect(green.employeeCount, '500+');
      expect(green.presence, Presence.panIndia);
      expect(green.statutoryCompliance, ['GST', 'PF', 'ESI', 'PT']);
      expect(green.status, PreQualStatus.pending);
      expect(green.shortlisted, isFalse);
      expect(green.supplier.verificationLevel, 'REGISTERED');
      final net = responses.firstWhere((r) => r.supplier.name == 'SecureNet Systems');
      expect(net.meetsCriteria, isFalse);
      expect(net.failures, ['Annual turnover', 'Presence', 'Statutory compliance (ESI)']);
    });

    liveTest('suppliers that fit are suggested, with their score, and any supplier is found by name', () async {
      final repo = await _repo(bharat);
      final suggested = await repo.suggested(security);
      expect(suggested, isNotEmpty);
      expect(suggested.every((s) => s.matchScore != null && s.supplier.name.isNotEmpty), isTrue);
      final scores = suggested.map((s) => s.matchScore!).toList();
      expect(scores, [...scores]..sort((a, b) => b.compareTo(a)));
      final invited = {for (final i in await repo.invites(security)) i.supplier.vendorId};
      expect(suggested.map((s) => s.supplier.vendorId).toSet().intersection(invited), isEmpty);

      final found = await repo.findSuppliers('Bluepeak');
      expect(found.map((s) => s.supplier.vendorId), contains('design-rfq-v-bluedot'));
      expect(found.firstWhere((s) => s.supplier.vendorId == 'design-rfq-v-bluedot').supplier.name, 'Bluepeak Security');
    });

    liveTest('the threads about a requirement are a list (empty before anyone writes)', () async {
      final threads = await (await _repo(bharat)).threads(ifm);
      expect(threads, isA<List<SupplierThread>>());
    });

    liveTest('someone else\'s requirement refuses its responses with a 403 the page reads as "not yours"', () async {
      final repo = await _repo(bluepeak);
      await expectLater(repo.bids(security), _status(403));
      final c = RfqDetailController(repository: repo, rfqId: security);
      await c.start();
      expect(c.rfq, isNotNull, reason: 'the requirement itself reads for anyone allowed to see it');
      expect(c.notOwner, isNotNull);
    });

    liveTest('the controller loads the owner\'s page: bids, sorted, with the best price marked', () async {
      final c = RfqDetailController(repository: await _repo(bharat), rfqId: security);
      await c.start();
      expect(c.error, isNull);
      expect(c.notOwner, isNull);
      expect(c.bids, hasLength(3));
      expect(c.sortedBids.first.status, BidStatus.shortlisted, reason: 'shortlisted first');
      expect(c.bestPrice, 1080000);
      expect(c.invites, hasLength(4));
      expect(c.canAward, isTrue);
      final staged = RfqDetailController(repository: await _repo(bharat), rfqId: ifm);
      await staged.start();
      expect(staged.bids, isEmpty, reason: 'quotes are not open yet');
      expect(staged.responses, hasLength(2));
      expect(staged.quotesOpen, isFalse);
    });

    liveTest('the buyer\'s list loads through its controller', () async {
      final c = MyRfqsController(await _repo(bharat));
      await c.start();
      expect(c.error, isNull);
      expect(c.forbidden, isFalse);
      expect(c.rows, isNotEmpty);
      expect(c.summary, isNotNull);
      expect(c.unread, greaterThanOrEqualTo(0));
    });
  });

  group('The composer\'s lookups', () {
    liveTest('the service taxonomy comes as categories with sub-categories, and names its keys', () async {
      final repo = await _repo(bharat);
      final tree = await repo.categories();
      expect(tree.length, greaterThan(10));
      final security = tree.firstWhere((c) => c.key == 'SECURITY');
      expect(security.name, 'Security Services');
      expect(security.children.map((c) => c.key), containsAll(['PHYSICAL_SECURITY', 'ELECTRONIC_SECURITY']));
      expect(repo.categoryName('PHYSICAL_SECURITY'), 'Physical Security');
      expect(repo.categoryName('NOT_A_KEY'), isNull);
      // Asked twice, read once.
      expect(identical(await repo.categories(), tree), isTrue);
      final fm = tree.firstWhere((c) => c.key == 'FACILITY_MANAGEMENT');
      expect(fm.children.map((c) => c.key), contains('HOUSEKEEPING'));
      final special = await repo.specialisations(fm.children.firstWhere((c) => c.key == 'HOUSEKEEPING').id);
      expect(special, isA<List<CategoryNode>>());
    });
  });

  group('Alerts', () {
    liveTest('Bharat\'s alerts are the ones about his requirements, each opening its owner page', () async {
      final alerts = await (await _repo(bharat)).alerts();
      final seeded = alerts.where((a) => a.id.startsWith('design-rfq-n')).toList();
      expect(seeded, hasLength(3));
      for (final a in seeded) {
        expect(a.side, AlertSide.owner);
        expect(a.rfqId, anyOf(security, ifm));
        expect(a.title, isNotEmpty);
        expect(a.createdAt, isNotNull);
      }
      final bid = seeded.firstWhere((a) => a.id == 'design-rfq-n1');
      expect(bid.type, 'bid_received');
      expect(bid.link, contains('?bid=design-rfq-q-security-bluedot'));
      expect(seeded.firstWhere((a) => a.id == 'design-rfq-n2').link, endsWith('?section=prequal'));
      // Messages and jobs, the other things in the bell, are not alerts about requirements.
      expect(alerts.every((a) => RfqAlert.types.contains(a.type) || a.rfqId != null), isTrue);
    });

    liveTest('the supplier\'s alerts open the supplier\'s page', () async {
      final alerts = await (await _repo(bluepeak)).alerts();
      final seeded = alerts.where((a) => a.id.startsWith('design-rfq-n')).toList();
      expect(
        seeded.map((a) => a.type),
        containsAll(['rfq_invite', 'enquiry_match', 'rfq_quotes_open', 'bid_awarded', 'bid_rejected']),
      );
      expect(seeded.every((a) => a.side == AlertSide.supplier), isTrue);
      expect(seeded.firstWhere((a) => a.id == 'design-rfq-n6').link, endsWith('?section=response'));
      expect(alerts.every((a) => RfqAlert.types.contains(a.type) || a.rfqId != null), isTrue);
    });

    liveTest('the unread count is a number and "new" counts only the unread requirement alerts', () async {
      final repo = await _repo(bluepeak);
      expect(await repo.unreadNotifications(), greaterThanOrEqualTo(0));
      final fresh = await repo.alerts(unreadOnly: true);
      expect(fresh.every((a) => a.unread), isTrue);
      expect((await repo.counts()).newAlerts, fresh.length);
    });
  });

  group('Reading as a supplier (Bluepeak, Gold)', () {
    liveTest('what the listing may do on the board', () async {
      final a = await (await _repo(bluepeak)).access();
      expect(a.hasListing, isTrue);
      expect(a.verified, isTrue);
      expect(a.canBid, isTrue);
      expect(a.canRespondToEnquiry, isTrue);
      expect(a.bidLimit, isNull, reason: 'Gold: unlimited');
      expect(a.canRevealContact, isTrue);
      expect(a.tier, 'GOLD');
      expect(a.verificationLevel, 'VERIFIED');
    });

    liveTest('the free plan has a monthly quote limit, and an unverified listing may not respond', () async {
      final free = await (await _repo(secureNet)).access();
      expect(free.bidLimit, 3);
      expect(free.bidsUsed, lessThanOrEqualTo(3));
      expect(free.canRevealContact, isFalse);
      final green = await (await _repo(greenShield)).access();
      expect(green.verified, isFalse);
      expect(green.canBid, isFalse);
      expect(green.canRespondToEnquiry, isFalse);
    });

    liveTest('the board parses, with the buyer, the match and "bid sent" on every row, and pages', () async {
      final repo = await _repo(bluepeak);
      final rows = await repo.openBoard(const BoardQuery(), limit: 50);
      expect(rows, isNotEmpty);
      for (final r in rows) {
        expect(r.status, RfqStatus.published);
        expect(r.visibility, RfqVisibility.public);
        expect(r.buyer, isNotNull, reason: '${r.title} has no buyer');
        expect(r.matchScore, isNotNull);
        expect(r.matchReasons, isNotEmpty);
        expect(r.contactName, isNull, reason: 'a supplier never gets the buyer\'s contact on the board');
      }
      expect(rows.map((r) => r.id).toSet(), hasLength(rows.length));
      final cctv = rows.firstWhere((r) => r.id == sCctv);
      expect(cctv.buyer!.companyName, 'Sunrise Facilities Pvt Ltd');
      expect(cctv.buyer!.verified, isTrue);
      expect(cctv.matched, isTrue);
      expect(cctv.hasBid, isFalse);
      expect(cctv.budget, 650000);
      expect(rows.firstWhere((r) => r.id == sCafeteria).hasBid, isTrue);
      expect(rows.every((r) => r.id != sFacade), isTrue, reason: 'an invite-only requirement is not on the open board');
      // Best match first, and a page past the end is empty.
      final scores = rows.map((r) => r.matchScore!).toList();
      expect(scores, [...scores]..sort((a, b) => b.compareTo(a)));
      expect(await repo.openBoard(const BoardQuery(), page: 99, limit: 20), isEmpty);
    });

    liveTest('every sort and filter the chips send is accepted, and the rows keep to it', () async {
      final repo = await _repo(bluepeak);
      for (final sort in BoardSort.values) {
        await repo.openBoard(BoardQuery(sort: sort), limit: 10);
      }
      final newest = await repo.openBoard(const BoardQuery(sort: BoardSort.newest), limit: 50);
      final dates = newest.map((r) => r.createdAt!).toList();
      expect(dates, [...dates]..sort((a, b) => b.compareTo(a)));
      final found = await repo.openBoard(const BoardQuery(search: 'CCTV'), limit: 50);
      expect(found.map((r) => r.id), contains(sCctv));
      expect(await repo.openBoard(const BoardQuery(search: 'zzqx-nothing-like-this')), isEmpty);
      final byBudget = await repo.openBoard(const BoardQuery(minBudget: 600000, maxBudget: 700000), limit: 50);
      expect(byBudget.map((r) => r.id), contains(sCctv));
      for (final r in byBudget) {
        expect(r.budget! >= 600000 && r.budget! <= 700000, isTrue);
      }
      for (final r in await repo.openBoard(const BoardQuery(closingInDays: 7), limit: 50)) {
        expect(r.dueDate, isNotNull);
        expect(r.dueDate!.isBefore(DateTime.now().add(const Duration(days: 8))), isTrue);
      }
      for (final r in await repo.openBoard(const BoardQuery(verifiedBuyer: true), limit: 50)) {
        expect(r.buyer!.verified, isTrue);
      }
      for (final r in await repo.openBoard(const BoardQuery(matchedOnly: true), limit: 50)) {
        expect(r.matched, isTrue);
      }
      for (final r in await repo.openBoard(const BoardQuery(city: 'Pune'), limit: 50)) {
        expect(r.places.join(' ').toLowerCase(), contains('pune'));
      }
    });

    liveTest('the invitations: waiting ones, declined ones and the ones already answered', () async {
      final invited = await (await _repo(bluepeak)).invited();
      final byId = {for (final r in invited) r.id: r};
      expect(byId[sFacade]!.inviteStatus, InviteStatus.invited);
      expect(byId[sFacade]!.visibility, RfqVisibility.targeted);
      expect(byId['design-rfq-s-declined']!.inviteStatus, InviteStatus.declined);
      expect(byId[security]!.inviteStatus, InviteStatus.responded);
      expect(byId[sFacade]!.buyer, isNotNull);
    });

    liveTest('the controller loads the board, counts the bids and reads the invitations', () async {
      final controller = SupplierBoardController(await _repo(bluepeak));
      await controller.start();
      expect(controller.error, isNull);
      expect(controller.gate, isNull);
      expect(controller.access!.verified, isTrue);
      expect(controller.myBidCount, greaterThanOrEqualTo(5));
      expect(controller.invitedOpen, greaterThanOrEqualTo(1));
      await controller.setTab(BoardTab.open);
      expect(controller.rows, isNotEmpty);
      await controller.setTab(BoardTab.invited);
      expect(controller.rows.every((r) => r.inviteStatus != null && r.inviteStatus != InviteStatus.declined), isTrue);
    });

    liveTest('a buyer account is refused the board with a 403, which the screens read as "for suppliers"', () async {
      final board = SupplierBoardController(await _repo(bharat));
      await board.start();
      expect(board.gate, SupplierGate.role);
      final bids = MyBidsController(await _repo(bharat));
      await bids.start();
      expect(bids.gate, SupplierGate.role);
    });

    liveTest('the supplier\'s bids parse, each with the requirement behind it, and fall on the right tab', () async {
      final repo = await _repo(bluepeak);
      final bids = await repo.myBids();
      expect(bids.length, greaterThanOrEqualTo(5));
      for (final b in bids) {
        expect(b.id, isNotEmpty);
        expect(b.rfqId, isNotEmpty);
        expect(b.requirement!.title, isNotEmpty);
        expect(b.requirement!.buyer, isNotNull);
      }
      final byRfq = {for (final b in bids) b.rfqId: b};
      expect(byRfq[sCafeteria]!.status, BidStatus.shortlisted);
      expect(byRfq[sCafeteria]!.amount, 420000);
      expect(byRfq[sCafeteria]!.leadTimeDays, 5);
      expect(byRfq['design-rfq-s-pest']!.amount, isNull, reason: 'an enquiry reply with no price');
      final won = byRfq['design-rfq-s-lifts']!;
      expect(won.isAwarded, isTrue);
      expect(won.status, BidStatus.awarded);
      expect(won.poNumber, 'PO-DSGNRFQ2');
      expect(byRfq['design-rfq-s-lost']!.status, BidStatus.rejected);

      final c = MyBidsController(repo);
      await c.start();
      expect(c.error, isNull);
      final onTabs = BidsTab.values.fold<int>(0, (n, t) => n + c.bidsIn(t).length);
      expect(onTabs, bids.length, reason: 'every bid is on exactly one tab');
      expect(c.bidsIn(BidsTab.awarded).map((b) => b.rfqId), contains('design-rfq-s-lifts'));
      expect(c.bidsIn(BidsTab.shortlisted).map((b) => b.rfqId), contains(sCafeteria));
      expect(c.bidsIn(BidsTab.submitted).map((b) => b.rfqId), contains('design-rfq-s-pest'));
      expect(c.bidsIn(BidsTab.archived).map((b) => b.rfqId), containsAll(['design-rfq-s-old', 'design-rfq-s-lost']));
      expect(c.declinedInvites.map((r) => r.id), contains('design-rfq-s-declined'));
    });

    liveTest('what the board says of one requirement: the buyer, the match and the supplier\'s own bid', () async {
      final repo = await _repo(bluepeak);
      final open = await repo.opportunity(sGuarding);
      expect(open.buyer!.companyName, 'Sunrise Facilities Pvt Ltd');
      expect(open.buyer!.verified, isTrue);
      expect(open.matchScore, 93);
      expect(open.matched, isTrue);
      expect(open.reasons.map((r) => r.key), ['category', 'location', 'rating', 'trust', 'premium']);
      expect(open.reasons.where((r) => r.hit).map((r) => r.key), containsAll(['category', 'location']));
      expect(open.myBid, isNull);
      final replied = await repo.opportunity(sCafeteria);
      expect(replied.myBid!.status, BidStatus.shortlisted);
      expect(replied.myBid!.amount, 420000);
      expect(replied.myBid!.message, contains('deep cleaning'));
    });

    liveTest('the requirement as a supplier reads it: no buyer contact, items and the staged RFQ\'s stage', () async {
      final repo = await _repo(bluepeak);
      final r = await repo.requirement(sGuarding);
      expect(r.contactName, isNull);
      expect(r.contactPhone, isNull);
      expect(r.stage, RfqStage.quotation);
      expect(r.items.map((i) => i.name), ['Security guards', 'Control room supervisor']);
      expect(r.criteria.statutoryCompliance, ['PSARA', 'PF']);
      expect(r.companyName, 'Sunrise Facilities Pvt Ltd');
    });

    liveTest(
      'an invite-only requirement reads for the supplier invited to it, and is not found by anyone else',
      () async {
        expect((await (await _repo(bluepeak)).requirement(sFacade)).visibility, RfqVisibility.targeted);
        await expectLater((await _repo(secureNet)).requirement(sFacade), _status(404));
      },
    );

    liveTest('the buyer\'s contact is shown to a supplier who has bid, and refused before', () async {
      final repo = await _repo(bluepeak);
      final contact = await repo.revealContact(sCafeteria);
      expect(contact.name, 'Bhavya Buyer');
      expect(contact.companyName, 'Sunrise Facilities Pvt Ltd');
      expect(contact.email, isNotNull);
      await expectLater(repo.revealContact(sCctv), _status(403));
    });
  });

  group('Writing as Sunrise, Bluepeak and the others (every write is undone)', () {
    liveTest('an enquiry posted through the composer\'s controller reads back as it was typed', () async {
      final repo = await _repo(sunrise);
      final posted = await _post(
        repo,
        tweak: (d) => d.items = [
          const RfqItem(name: 'Security guards', quantity: 24, unit: 'guards', specification: 'PSARA licensed'),
        ],
      );
      expect(posted.kind, RfqKind.enquiry);
      expect(posted.status, RfqStatus.published);
      expect(posted.alertedNow, isNotNull, reason: 'the API says how many suppliers it reached');
      final r = await repo.requirement(posted.id);
      expect(r.title, startsWith('zz live'));
      expect(r.kind, RfqKind.enquiry);
      expect(r.status, RfqStatus.published);
      expect(r.visibility, RfqVisibility.public);
      expect(r.category, 'SECURITY');
      expect(r.subcategory, 'PHYSICAL_SECURITY');
      expect(r.facilityType, 'IT & ITES');
      expect(r.budget, 650000);
      expect(r.locations, ['Pune']);
      expect(r.state, 'Maharashtra');
      expect(r.country, 'India');
      expect(r.serviceLocations.single.label, 'Pune');
      expect(r.serviceLocations.single.state, 'Maharashtra');
      expect(r.contactName, 'Bhavya Buyer');
      expect(r.companyName, 'Sunrise Facilities Pvt Ltd');
      expect(r.items.single.name, 'Security guards');
      expect(r.items.single.quantity, 24);
      expect(r.description, contains('Round-the-clock'));
      final mine = await repo.mine(search: 'zz live');
      expect(mine.rows.map((x) => x.id), contains(posted.id));
      expect((await repo.summary()).count(MyView.live), greaterThanOrEqualTo(1));
    });

    liveTest(
      'the board lists it, a supplier replies from the page\'s controller, and a second reply is refused',
      () async {
        final repo = await _repo(sunrise);
        final posted = await _post(repo);
        final title = (await repo.requirement(posted.id)).title;
        final blue = await _repo(bluepeak);
        expect((await blue.openBoard(BoardQuery(search: title))).map((r) => r.id), contains(posted.id));

        final page = await _page(bluepeak, posted.id);
        expect(page.state, ResponseState.form);
        expect(page.own, isFalse);
        expect(
          page.allowance,
          anyOf(isNull, contains('free'), contains("doesn't use")),
          reason: 'an enquiry reply is free',
        );
        expect(page.context!.buyer!.companyName, 'Sunrise Facilities Pvt Ltd');
        final reply = BidDraft()
          ..amount = '5,90,000'
          ..leadTime = '10'
          ..message = 'We can mobilise within a week with a supervisor on site.';
        expect(await page.placeBid(reply), isNull);
        expect(page.state, ResponseState.sent);
        expect(page.myBid!.amount, 590000);
        expect(page.myBid!.leadTimeDays, 10);
        expect(page.myBid!.status, BidStatus.pending);
        expect((await blue.openBoard(BoardQuery(search: title))).single.hasBid, isTrue);
        expect(await page.placeBid(reply), isNotNull, reason: 'one reply per requirement');

        final owner = RfqDetailController(repository: repo, rfqId: posted.id);
        await owner.start();
        expect(owner.bids.single.supplier.name, 'Bluepeak Security');
        expect(owner.bids.single.amount, 590000);
        expect(owner.rfq!.quoteCount, 1);
      },
    );

    liveTest(
      'who may not reply is refused in the API\'s words: an unverified listing, and a buyer on its own requirement',
      () async {
        final repo = await _repo(sunrise);
        final posted = await _post(repo);
        final green = await _page(greenShield, posted.id);
        final error = await green.placeBid(BidDraft()..message = 'We would like to reply.');
        expect(error, isNotNull);
        expect(error!.toLowerCase(), contains('verified'));
        expect(green.myBid, isNull);
        expect(green.blocker, isNotNull, reason: 'the page says it up front too');

        final own = await _page(sunrise, posted.id);
        expect(
          own.state,
          ResponseState.own,
          reason: 'the page does not even offer a form on the company\'s own requirement',
        );
        expect(await own.placeBid(BidDraft()..message = 'Our own requirement.'), isNotNull);
      },
    );

    liveTest('an alert about the bid reaches the buyer, names its bid, and is read when the page is opened', () async {
      final repo = await _repo(sunrise);
      final posted = await _post(repo);
      final first = await _page(bluepeak, posted.id);
      expect(await first.placeBid(BidDraft()..message = 'Quotation attached to follow.'), isNull);
      final bid = first.myBid!;
      final alerts = (await repo.alerts(unreadOnly: true)).where((a) => a.rfqId == posted.id).toList();
      expect(alerts, hasLength(1));
      final alert = alerts.single;
      expect(alert.type, 'bid_received');
      expect(alert.side, AlertSide.owner);
      expect(alert.bidId, bid.id, reason: 'the page opens ringing this bid');
      expect(alert.unread, isTrue);
      expect((await repo.counts()).newAlerts, greaterThanOrEqualTo(1));

      // Reading one by itself.
      await repo.markAlertRead(alert.id);
      expect((await repo.alerts()).firstWhere((a) => a.id == alert.id).unread, isFalse);

      // A second bid; opening the requirement reads everything that was about it.
      expect(await (await _page(innova, posted.id)).placeBid(BidDraft()..message = 'Innova can do this too.'), isNull);
      expect((await repo.alerts(unreadOnly: true)).where((a) => a.rfqId == posted.id), hasLength(1));
      final owner = RfqDetailController(repository: repo, rfqId: posted.id);
      await owner.start();
      expect((await repo.alerts(unreadOnly: true)).where((a) => a.rfqId == posted.id), isEmpty);
    });

    liveTest(
      'shortlist and decline are taken back, and what the buyer decided reads the same for the supplier',
      () async {
        final repo = await _repo(sunrise);
        final posted = await _post(repo);
        await (await _page(bluepeak, posted.id)).placeBid(BidDraft()..message = 'Ready to start.');
        final owner = RfqDetailController(repository: repo, rfqId: posted.id);
        await owner.start();
        final bid = owner.bids.single;
        Future<BidStatus> stored() async => (await repo.bids(posted.id)).single.status;

        expect(await owner.triage(bid, BidStatus.shortlisted), isNull);
        expect(await stored(), BidStatus.shortlisted);
        final supplier = MyBidsController(await _repo(bluepeak));
        await supplier.start();
        expect(supplier.bidsIn(BidsTab.shortlisted).map((b) => b.rfqId), contains(posted.id));
        expect(await owner.triage(owner.bids.single, BidStatus.pending), isNull);
        expect(await stored(), BidStatus.pending);
        expect(await owner.triage(owner.bids.single, BidStatus.rejected), isNull);
        expect(await stored(), BidStatus.rejected);
        await supplier.refresh();
        expect(supplier.bidsIn(BidsTab.archived).map((b) => b.rfqId), contains(posted.id));
        expect(await owner.triage(owner.bids.single, BidStatus.pending), isNull, reason: 'restored');
        expect(await stored(), BidStatus.pending);
      },
    );

    liveTest(
      'a thread is opened with a bidder, the supplier finds the same one, and the buyer\'s list names it',
      () async {
        final repo = await _repo(sunrise);
        final posted = await _post(repo);
        final page = await _page(bluepeak, posted.id);
        expect(await page.placeBid(BidDraft()..message = 'Reply with a question.'), isNull);
        final owner = RfqDetailController(repository: repo, rfqId: posted.id);
        await owner.start();
        final bid = owner.bids.single;
        final first = await owner.conversationWith(
          conversationId: bid.conversationId,
          supplierCompanyId: bid.supplier.companyId,
        );
        expect(first.error, isNull);
        expect(first.id, isNotEmpty);
        // The reply opened one thread already (a bid seeds it): asking again is the same thread, not a second.
        final again = await owner.conversationWith(supplierCompanyId: bid.supplier.companyId);
        expect(again.id, first.id);
        final theirs = await page.messageBuyer();
        expect(theirs.id, first.id, reason: 'one thread per requirement and supplier company');
        await owner.refresh();
        expect(owner.threads.map((t) => t.conversationId), contains(first.id));
        expect(owner.threads.single.companyName, 'Bluepeak Security');
      },
    );

    liveTest(
      'selecting a reply closes the enquiry for the others, tells the supplier and refuses a second decision',
      () async {
        final repo = await _repo(sunrise);
        final posted = await _post(repo);
        await (await _page(bluepeak, posted.id)).placeBid(
          BidDraft()
            ..amount = '5,00,000'
            ..message = 'Our best.',
        );
        await (await _page(innova, posted.id)).placeBid(
          BidDraft()
            ..amount = '5,40,000'
            ..message = 'Also ready.',
        );
        final owner = RfqDetailController(repository: repo, rfqId: posted.id);
        await owner.start();
        expect(owner.bids, hasLength(2));
        final chosen = owner.bids.firstWhere((b) => b.supplier.name == 'Bluepeak Security');
        final result = await owner.award(chosen);
        expect(result.ok, isTrue, reason: result.message);
        expect(result.message, contains('Bluepeak Security selected'));
        expect((await repo.requirement(posted.id)).status, RfqStatus.awarded);
        final stored = {for (final b in await repo.bids(posted.id)) b.supplier.name: b.status};
        expect(stored['Bluepeak Security'], BidStatus.awarded);
        expect(stored['Innova Facility Services'], BidStatus.rejected);

        final mine = (await (await _repo(bluepeak)).myBids()).firstWhere((b) => b.rfqId == posted.id);
        expect(mine.isAwarded, isTrue);
        expect(mine.poNumber, isNull, reason: 'an enquiry has no purchase order');
        final alerts = await (await _repo(bluepeak)).alerts();
        expect(alerts.where((a) => a.rfqId == posted.id).map((a) => a.type), contains('bid_awarded'));
        final lost = await (await _repo(innova)).alerts();
        expect(lost.where((a) => a.rfqId == posted.id).map((a) => a.type), contains('bid_rejected'));

        final again = await owner.award(owner.bids.firstWhere((b) => b.supplier.name == 'Innova Facility Services'));
        expect(again.ok, isFalse);
        expect(again.message, isNotEmpty);
        expect(
          await owner.triage(owner.bids.first, BidStatus.pending),
          isNotNull,
          reason: 'a settled bid cannot change status',
        );
        expect(await owner.act(RfqAction.close), isNull);
        expect((await repo.requirement(posted.id)).status, RfqStatus.closed);
      },
    );

    liveTest(
      'a staged RFQ runs from pre-qualification to a purchase order, with the API\'s verdicts on the way',
      () async {
        final repo = await _repo(sunrise);
        final id = (await _post(repo, kind: RfqKind.rfq)).id;
        final posted = await repo.requirement(id);
        expect(posted.stage, RfqStage.prequalification);
        expect(posted.criteria.minYearsInBusiness, 3);
        expect(posted.criteria.statutoryCompliance, ['PSARA']);
        expect(posted.text, contains('Round-the-clock'));

        // A supplier cannot quote yet, and the API says so.
        final blue = await _page(bluepeak, id);
        expect(blue.state, ResponseState.preQual);
        expect(await _refusal((await _repo(bluepeak)).placeBid(id, {'totalAmount': 100})), isNotNull);

        // Two answers: one that meets the criteria, one that does not.
        expect(
          await blue.submitPreQual(
            PreQualDraft()
              ..yearsInBusiness = '9'
              ..annualTurnover = '9,00,00,000'
              ..compliance = {'PSARA'},
          ),
          isNull,
        );
        final net = await _page(secureNet, id);
        expect(await net.submitPreQual(PreQualDraft()..yearsInBusiness = '1'), isNull);

        final owner = RfqDetailController(repository: repo, rfqId: id);
        await owner.start();
        expect(owner.responses, hasLength(2));
        final byName = {for (final r in owner.responses) r.supplier.name: r};
        expect(byName['Bluepeak Security']!.meetsCriteria, isTrue);
        expect(byName['SecureNet Systems']!.meetsCriteria, isFalse);
        expect(byName['SecureNet Systems']!.failures, isNotEmpty);
        expect((await repo.summary()).actionItems.where((a) => a.rfqId == id && a.kind == 'SCREEN'), hasLength(1));

        // Shortlisting waits for its stage.
        expect(await owner.screen(byName['Bluepeak Security']!, PreQualStatus.qualified), isNull);
        expect(
          await owner.shortlist(owner.responses.firstWhere((r) => r.supplier.name == 'Bluepeak Security')),
          isNotNull,
        );
        expect(await owner.advanceStage(), isNull);
        expect(owner.rfq!.stage, RfqStage.shortlisting);
        expect(
          await owner.shortlist(owner.responses.firstWhere((r) => r.supplier.name == 'Bluepeak Security')),
          isNull,
        );
        expect(await owner.advanceStage(), isNull);
        expect(owner.rfq!.stage, RfqStage.quotation);

        // Only the shortlisted supplier may quote, and a quote needs a price.
        final notShortlisted = await _page(secureNet, id);
        expect(await notShortlisted.placeBid(BidDraft()..amount = '1,00,000'), isNotNull);
        final quoting = await _page(bluepeak, id);
        expect(quoting.state, ResponseState.form);
        expect(quoting.rfq!.stage, RfqStage.quotation);
        expect(await _refusal((await _repo(bluepeak)).placeBid(id, {'message': 'no price'})), isNotNull);
        expect(
          await quoting.placeBid(
            BidDraft()
              ..amount = '5,25,000'
              ..leadTime = '14'
              ..message = 'Detailed quote attached.',
          ),
          isNull,
        );

        await owner.refresh();
        expect(owner.quotesOpen, isTrue);
        final result = await owner.award(owner.bids.single);
        expect(result.ok, isTrue, reason: result.message);
        expect(result.message, matches(r'purchase order PO-'));
        final done = await repo.requirement(id);
        expect(done.status, RfqStatus.awarded);
        expect(done.stage, RfqStage.completed);
        final mine = (await (await _repo(bluepeak)).myBids()).firstWhere((b) => b.rfqId == id);
        expect(mine.isAwarded, isTrue);
        expect(mine.poNumber, startsWith('PO-'));
      },
    );

    liveTest(
      'the free plan\'s monthly quotes run out, and the refusal names the plan in the API\'s own words',
      () async {
        final repo = await _repo(sunrise);
        final net = await _repo(secureNet);
        final start = (await net.access()).bidsUsed;
        expect((await net.access()).bidLimit, 3);
        final room = 3 - start;
        final ids = <String>[];
        for (var i = 0; i < room + 1; i++) {
          ids.add(await _toQuotation(repo, [secureNet]));
        }
        for (final id in ids.take(room)) {
          expect(await (await _page(secureNet, id)).placeBid(BidDraft()..amount = '4,00,000'), isNull);
        }
        final used = await net.access();
        expect(used.bidsUsed, 3);
        expect(used.canBid, isFalse);

        final last = await _page(secureNet, ids.last);
        expect(last.blocker, contains('used'), reason: 'the page says it before the API does');
        final refusal = await last.placeBid(BidDraft()..amount = '4,00,000');
        expect(refusal, isNotNull);
        expect(refusal!.toLowerCase(), contains('bid'));
        expect(mentionsPlan(refusal), isTrue, reason: 'so the form offers the plans beside it');
        expect(last.myBid, isNull);
        // An enquiry reply does not use the allowance, so the same supplier may still answer one.
        final enquiry = await _post(repo);
        expect(await (await _page(secureNet, enquiry.id)).placeBid(BidDraft()..message = 'Free to reply.'), isNull);
      },
    );

    liveTest('an invite-only enquiry is seen only by the invited, who may decline it; more can be invited', () async {
      final repo = await _repo(sunrise);
      final blue = await _repo(bluepeak);
      final bluepeakVendor = (await blue.access()).vendorId!;
      final posted = await _post(
        repo,
        tweak: (d) => d
          ..audience = Audience.invited
          ..invited = [SupplierRef(vendorId: bluepeakVendor, name: 'Bluepeak Security')],
      );
      final r = await repo.requirement(posted.id);
      expect(r.visibility, RfqVisibility.targeted);
      expect(r.status, RfqStatus.published, reason: 'an invite-only enquiry goes out at once');
      final invited = (await blue.invited()).firstWhere((x) => x.id == posted.id);
      expect(invited.inviteStatus, InviteStatus.invited);
      expect((await blue.openBoard(BoardQuery(search: r.title))).map((x) => x.id), isNot(contains(posted.id)));
      await expectLater((await _repo(secureNet)).requirement(posted.id), _status(404));

      final owner = RfqDetailController(repository: repo, rfqId: posted.id);
      await owner.start();
      final suggested = await owner.suggested();
      expect(suggested.map((s) => s.supplier.vendorId), isNot(contains(bluepeakVendor)), reason: 'already invited');
      final netVendor = (await (await _repo(secureNet)).access()).vendorId!;
      expect(await owner.invite([netVendor]), isNull);
      expect(owner.invites.map((i) => i.supplier.vendorId), containsAll([bluepeakVendor, netVendor]));
      expect((await (await _repo(secureNet)).requirement(posted.id)).id, posted.id, reason: 'now invited, it reads');

      final page = await _page(bluepeak, posted.id);
      expect(page.invitedOnly, isTrue);
      expect(await page.decline(), isNull);
      expect(page.state, ResponseState.declined);
      await owner.refresh();
      expect(owner.invites.firstWhere((i) => i.supplier.vendorId == bluepeakVendor).status, InviteStatus.declined);
      final reread = await _page(bluepeak, posted.id);
      expect(reread.state, ResponseState.declined, reason: 'the API keeps the decline');
    });

    liveTest('files: a requirement\'s is public, a bid\'s is private to the buyer and its supplier', () async {
      final repo = await _repo(sunrise);
      final file = await repo.uploadFile(
        PickedRfqFile(name: 'site-layout.pdf', bytes: _pdf()),
        purpose: 'rfq-attachment',
      );
      expect(file.url, startsWith('/uploads/'));
      expect(file.name, 'site-layout.pdf');
      expect(file.mimeType, 'application/pdf');
      expect(file.title, 'site-layout');
      final posted = await _post(
        repo,
        tweak: (d) => d.attachments = [
          RfqFile(
            id: '',
            title: 'Site layout, ground floor',
            url: file.url,
            name: file.name,
            mimeType: file.mimeType,
            size: file.size,
          ),
        ],
      );
      final r = await repo.requirement(posted.id);
      expect(r.files.single.title, 'Site layout, ground floor');
      expect(r.files.single.name, 'site-layout.pdf');
      expect(r.files.single.url, file.url);
      // A supplier reads the same file list.
      expect((await (await _repo(bluepeak)).requirement(posted.id)).files.single.url, file.url);

      final blue = await _repo(bluepeak);
      final quote = await blue.uploadFile(
        PickedRfqFile(name: 'quotation.pdf', bytes: _pdf()),
        purpose: 'bid-attachment',
      );
      final page = await _page(bluepeak, posted.id);
      final reply = BidDraft()
        ..amount = '5,00,000'
        ..attachments = [
          RfqFile(
            id: '',
            title: 'Priced quotation',
            url: quote.url,
            name: quote.name,
            mimeType: quote.mimeType,
            size: quote.size,
          ),
        ];
      expect(await page.placeBid(reply), isNull);
      expect(page.myBid!.files.single.title, 'Priced quotation');

      final owner = RfqDetailController(repository: repo, rfqId: posted.id);
      await owner.start();
      final stored = owner.bids.single.files.single;
      expect(stored.title, 'Priced quotation');
      final path = await repo.saveFile(stored);
      expect(await File(path).readAsBytes(), _pdf(), reason: 'the buyer fetches it with their own session');
      expect(await File(await blue.saveFile(stored)).readAsBytes(), _pdf(), reason: 'so does its supplier');
      await expectLater((await _repo(secureNet)).saveFile(stored), _status(403));
    });

    liveTest('a draft is saved, edited through the composer\'s controller, and published', () async {
      final repo = await _repo(sunrise);
      final posted = await _post(repo, publish: false);
      expect(posted.status, RfqStatus.draft);
      expect((await repo.mine(view: MyView.draft)).rows.map((r) => r.id), contains(posted.id));
      await expectLater((await _repo(bluepeak)).requirement(posted.id), _status(404));

      final edit = PostRfqController(repository: repo, editingId: posted.id);
      await edit.start();
      expect(edit.editing, isTrue);
      expect(edit.draft.budget, '650000');
      expect(edit.draft.places.single.label, 'Pune');
      edit.update((d) => d.budget = '7,25,000');
      expect(await edit.submit(publish: true), isTrue, reason: edit.error ?? '${edit.problems}');
      final r = await repo.requirement(posted.id);
      expect(r.status, RfqStatus.published);
      expect(r.budget, 725000);
      expect(r.places, ['Pune'], reason: 'what was not edited is kept');

      // A live requirement is edited the same way, and a copy starts from it.
      final live = PostRfqController(repository: repo, editingId: posted.id);
      await live.start();
      live.update((d) => d.text = 'Changed: 30 guards, three shifts, from 1 January.');
      expect(await live.submit(publish: true), isTrue);
      expect((await repo.requirement(posted.id)).description, startsWith('Changed:'));
      final copy = PostRfqController(repository: repo, copyFromId: posted.id);
      await copy.start();
      expect(copy.draft.text, startsWith('Changed:'));
      expect(copy.draft.title, isEmpty);
      expect(copy.draft.dueDate, isNull);
    });

    liveTest('a draft is deleted for good, and a closed requirement is closed for suppliers', () async {
      final repo = await _repo(sunrise);
      final draft = await _post(repo, publish: false);
      await repo.deleteDraft(draft.id);
      await expectLater(repo.requirement(draft.id), _status(404));
      final live = await _post(repo);
      final owner = RfqDetailController(repository: repo, rfqId: live.id);
      await owner.start();
      expect(await owner.act(RfqAction.close), isNull);
      final page = await _page(bluepeak, live.id);
      expect(page.state, ResponseState.closed);
      expect(await owner.act(RfqAction.publish), isNotNull, reason: 'a closed requirement cannot be published again');
    });

    liveTest(
      'a person with no company reads and manages requirements but is refused posting, in the API\'s words',
      () async {
        final repo = await _repo(bharat);
        final c = PostRfqController(repository: repo);
        await c.start();
        expect(c.mustRegisterCompany, isTrue, reason: 'the form says so before any typing');
        final refusal = await _refusal(
          repo.create({
            'title': 'zz live',
            'kind': 'ENQUIRY',
            'status': 'PUBLISHED',
            'description': 'A requirement of twenty characters.',
          }),
        );
        expect(refusal, contains('Register your company'));
        // But his own earlier requirements are his to run.
        final owner = RfqDetailController(repository: repo, rfqId: security);
        await owner.start();
        expect(owner.notOwner, isNull);
      },
    );

    liveTest('the place search finds a city with its state and country, and a short query is not sent', () async {
      final repo = await _repo(sunrise);
      final found = await repo.searchPlaces('Pune');
      expect(found.first.label, 'Pune');
      expect(found.first.state, 'Maharashtra');
      expect(found.first.country, 'India');
      expect(found.first.countryCode, 'IN');
      expect(await repo.searchPlaces('P'), isEmpty);
      expect(found.first.toJson().keys, containsAll(['label', 'city', 'state', 'country', 'countryCode']));
    });

    liveTest('the portal has no call yet to change or withdraw a bid: the app does not draw the buttons', () async {
      // `docs/backend-requests/rfq.md` section 1. When the portal gets `PATCH|DELETE /rfq/:id/bids/mine`, these two
      // calls answer 200, this test says so, and `ApiRfqRepository(supportsBidChanges: true)` is the line to change.
      final repo = await _repo(sunrise);
      final posted = await _post(repo);
      await (await _page(bluepeak, posted.id)).placeBid(BidDraft()..message = 'A reply.');
      final blue = ApiRfqRepository(api: await liveClient(bluepeak), supportsBidChanges: true);
      // Today `PATCH .../bids/mine` lands on the buyer's `:bidId` route (400: "mine" is no bid) and the DELETE on no
      // route at all, so the test asks only that neither goes through and that the bid is untouched.
      await expectLater(
        blue.updateBid(posted.id, {'message': 'Changed'}),
        throwsA(isA<Object>().having((e) => ApiError.from(e).statusCode, 'status', inInclusiveRange(400, 404))),
      );
      await expectLater(
        blue.withdrawBid(posted.id),
        throwsA(isA<Object>().having((e) => ApiError.from(e).statusCode, 'status', inInclusiveRange(400, 404))),
      );
      expect(ApiRfqRepository(api: await liveClient(bluepeak)).supportsBidChanges, isFalse);
      expect((await blue.opportunity(posted.id)).myBid!.message, 'A reply.');
    });
  });
}
