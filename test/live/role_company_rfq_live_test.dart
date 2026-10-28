/// Requirements (RFQ) as the BUYING company, for the company accounts, against the LOCAL portal API: the
/// app's own repository and controllers, the way the screens use them, every effect read back.
///
/// Accounts (`role_company_support.dart`): the e2e COMPANY_ADMIN pair (Chetan, Farah) of E2E Test Vendor Co
/// (a company that buys, sells and hires), the Marketplace seed's buyer company (Maya, an admin with a phone;
/// Nikhil, a BUYER with none) and the three company roles the API does not let near requirements (Bina,
/// BRANCH_ADMIN; Rahul, RECRUITER; Hema, HIRING_MANAGER). Suppliers that bid are the RFQ seed's Bluepeak and Innova.
///
/// Every requirement a test posts is deleted when the test ends (which takes its bids and invitations with
/// it); Nikhil's phone is taken off again at the end of his test, as the Marketplace seed leaves it. What
/// cannot be undone through the API: a notification read, a thread opened (both kept, harmless).
///
///     flutter test --no-pub test/live/role_company_rfq_live_test.dart --concurrency=1
@Tags(['live'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/features/marketplace/api_marketplace_repository.dart';
import 'package:icr_mobile/features/marketplace/quote_controller.dart';
import 'package:icr_mobile/features/marketplace/quote_models.dart';
import 'package:icr_mobile/features/rfq/api_rfq_repository.dart';
import 'package:icr_mobile/features/rfq/my_rfqs_controller.dart';
import 'package:icr_mobile/features/rfq/post_rfq_controller.dart';
import 'package:icr_mobile/features/rfq/rfq_detail_controller.dart';
import 'package:icr_mobile/features/rfq/rfq_links.dart' show PickedRfqFile;
import 'package:icr_mobile/features/rfq/rfq_models.dart';
import 'package:icr_mobile/features/rfq/rfq_rules.dart';
import 'package:icr_mobile/features/rfq/supplier_controllers.dart';

import 'live.dart';
import 'role_company_support.dart';

Future<ApiRfqRepository> _repo(LivePerson who) async => ApiRfqRepository(api: await liveClient(who));

/// A tiny, real PDF to attach.
List<int> _pdf() => '%PDF-1.4\n1 0 obj << /Type /Catalog >> endobj\ntrailer << /Root 1 0 R >>\n%%EOF\n'.codeUnits;

DateTime _inDays(int n) => todayIst().add(Duration(days: n));

Future<String?> _refusal(Future<Object?> call) async {
  try {
    await call;
    return null;
  } catch (e) {
    return ApiError.from(e).message;
  }
}

Matcher _status(int code) => throwsA(isA<Object>().having((e) => ApiError.from(e).statusCode, 'status', code));

/// A requirement posted through the composer's own controller as [who], deleted again when the test ends.
Future<PostResult> _post(
  LivePerson who, {
  RfqKind kind = RfqKind.enquiry,
  bool publish = true,
  void Function(RequirementDraft d)? tweak,
  String? expectCompany,
}) async {
  final repo = await _repo(who);
  final c = PostRfqController(repository: repo, initialKind: kind);
  await c.start();
  expect(c.loadError, isNull);
  expect(c.mustRegisterCompany, isFalse);
  expect(c.companyFromAccount, expectCompany ?? companyName);
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
  c.setTitle('zz company live ${DateTime.now().millisecondsSinceEpoch}');
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

Future<OpportunityController> _page(LivePerson who, String id) async {
  final c = OpportunityController(repository: await _repo(who), rfqId: id);
  await c.start();
  expect(c.error, isNull, reason: 'the page of $id for ${who.label}');
  return c;
}

void main() {
  group('who may run requirements', () {
    companyTest(
      'the company\'s admins and its buyer post; an office admin, a recruiter and a hiring manager do not',
      () async {
        final expected = <LivePerson, ({String role, bool canPost, bool hasCompany})>{
          companyAdmin: (role: 'COMPANY_ADMIN', canPost: true, hasCompany: true),
          founder: (role: 'COMPANY_ADMIN', canPost: true, hasCompany: true),
          marketBuyer: (role: 'COMPANY_ADMIN', canPost: true, hasCompany: true),
          marketNoPhone: (role: 'BUYER', canPost: true, hasCompany: true),
          branchAdmin: (role: 'BRANCH_ADMIN', canPost: false, hasCompany: true),
          recruiter: (role: 'RECRUITER', canPost: false, hasCompany: true),
          hiringManager: (role: 'HIRING_MANAGER', canPost: false, hasCompany: true),
        };
        for (final entry in expected.entries) {
          final repo = await _repo(entry.key);
          final me = await repo.me();
          expect(me.role, entry.value.role, reason: entry.key.label);
          expect(me.canPost, entry.value.canPost, reason: entry.key.label);
          expect(me.companyId, isNotNull, reason: entry.key.label);
          // The API says the same: the list opens for the posting roles, and is refused for the others.
          if (entry.value.canPost) {
            expect((await repo.summary()).count(MyView.all), greaterThanOrEqualTo(0), reason: entry.key.label);
          } else {
            await expectLater(repo.summary(), _status(403), reason: entry.key.label);
            await expectLater(repo.mine(), _status(403), reason: entry.key.label);
          }
        }
      },
    );

    companyTest(
      'the company\'s requirements are the whole team\'s: a colleague sees and runs what an admin posted',
      () async {
        final posted = await _post(companyAdmin);
        final colleague = await _repo(founder);
        expect((await colleague.mine(search: 'zz company live')).rows.map((r) => r.id), contains(posted.id));
        final owner = RfqDetailController(repository: colleague, rfqId: posted.id);
        await owner.start();
        expect(owner.notOwner, isNull, reason: 'the second admin runs the first one\'s requirement');
        expect(owner.rfq!.id, posted.id);
        // A person at another company sees the brief, and is told it is not theirs.
        final other = RfqDetailController(repository: await _repo(marketBuyer), rfqId: posted.id);
        await other.start();
        expect(other.notOwner, contains('another company'));
      },
    );

    companyTest(
      'a BUYER with no phone on file posts: the composer asks for the contact number, and the requirement carries it',
      () async {
        final api = await liveClient(marketNoPhone);
        await api.dio.patch<dynamic>('/users/me', data: {'phone': ''});
        final repo = await _repo(marketNoPhone);
        final c = PostRfqController(repository: repo);
        addTearDown(c.dispose);
        await c.start();
        expect(c.roleCannotPost, isFalse);
        expect(c.draft.contactPhone, isEmpty, reason: 'nothing on file to start from');
        c.update((d) => d.text = 'Round-the-clock guarding for a Pune campus: 24 guards, three shifts.');
        expect(c.review(publish: true), isFalse);
        expect(
          c.problems['contactPhone'],
          'Enter a phone number',
          reason: 'the composer asks for it before the API has to',
        );
        final posted = await _post(
          marketNoPhone,
          expectCompany: 'Meridian Corporate Estates',
          tweak: (d) => d.contactPhone = '+91 98765 43210',
        );
        final r = await repo.requirement(posted.id);
        expect(r.contactPhone, '+91 98765 43210');
        expect(r.companyName, 'Meridian Corporate Estates');
        // His own profile is not touched by a contact number typed into a requirement.
        expect(await ApiMarketplaceRepository(api: api).hasPhone(), isFalse);
      },
    );

    companyTest(
      'the company buyer (a BUYER) runs what its admin posted: reads the replies, shortlists, selects and closes',
      () async {
        final posted = await _post(marketBuyer, expectCompany: 'Meridian Corporate Estates');
        expect(
          await (await _page(bluepeak, posted.id)).placeBid(
            BidDraft()
              ..amount = '4,80,000'
              ..message = 'Role test: Meridian bid.',
          ),
          isNull,
        );
        final buyer = await _repo(marketNoPhone);
        expect((await buyer.mine()).rows.map((r) => r.id), contains(posted.id));
        final owner = RfqDetailController(repository: buyer, rfqId: posted.id);
        addTearDown(owner.dispose);
        await owner.start();
        expect(owner.notOwner, isNull, reason: 'a BUYER of the company runs its requirements');
        expect(owner.bids, hasLength(1));
        expect(await owner.triage(owner.bids.single, BidStatus.shortlisted), isNull);
        expect(
          (await (await _repo(marketBuyer)).bids(posted.id)).single.status,
          BidStatus.shortlisted,
          reason: 'the admin sees his move',
        );
        final result = await owner.award(owner.bids.single);
        expect(result.ok, isTrue, reason: result.message);
        expect(await owner.act(RfqAction.close), isNull);
        expect((await (await _repo(marketBuyer)).requirement(posted.id)).status, RfqStatus.closed);
      },
    );

    companyTest(
      'an office admin, a recruiter and a hiring manager are refused in sentences the screens can show',
      () async {
        final posted = await _post(companyAdmin);
        for (final who in [branchAdmin, recruiter, hiringManager]) {
          final repo = await _repo(who);
          final list = MyRfqsController(repo);
          addTearDown(list.dispose);
          await list.start();
          expect(list.forbidden, isTrue, reason: who.label);
          expect(list.error, isNotEmpty, reason: who.label);
          expect(list.rows, isEmpty);

          // The brief reads (it is public to the company's people), the bids and invitations do not.
          final page = RfqDetailController(repository: repo, rfqId: posted.id);
          addTearDown(page.dispose);
          await page.start();
          expect(page.rfq, isNotNull, reason: '${who.label} may read the brief');
          expect(page.notOwner, isNotNull, reason: '${who.label} is told it is not theirs to run');
          expect(
            page.notOwner,
            contains(companyName),
            reason: '${who.label}: it is their own company, and the sentence says so',
          );
          expect(page.notOwner, isNot(contains('another company')), reason: who.label);
          expect(page.bids, isEmpty);

          // Posting is refused by the API with a sentence, and the composer says the same before the form.
          final composer = PostRfqController(repository: repo);
          addTearDown(composer.dispose);
          await composer.start();
          expect(composer.roleCannotPost, isTrue, reason: '${who.label}: the composer says so up front');
          expect(composer.roleCannotPostMessage, contains('company'), reason: who.label);
          final refusal = await _refusal(
            repo.create({
              'title': 'zz company live refused',
              'kind': 'ENQUIRY',
              'status': 'PUBLISHED',
              'description': 'A requirement of more than twenty characters.',
            }),
          );
          expect(refusal, isNotNull, reason: '${who.label} cannot post');
        }
      },
    );
  });

  group('posting from the composer', () {
    companyTest(
      'the composer opens on the account\'s company, contact, phone and email, and every rule refuses what the API refuses',
      () async {
        final repo = await _repo(companyAdmin);
        final me = await repo.me();
        final c = PostRfqController(repository: repo);
        addTearDown(c.dispose);
        await c.start();
        expect(c.loadError, isNull);
        expect(c.companyFromAccount, companyName);
        expect(c.draft.contactName, me.name);
        expect(c.draft.email, 'companyadmin@icr.test');
        expect(c.draft.contactPhone, me.phone, reason: 'the phone on file is the composer\'s own start');
        expect(c.categories, isNotEmpty, reason: 'the service taxonomy loads');
        expect(c.categoriesLoading, isFalse);
        expect(c.askCompany, isFalse, reason: 'a company admin does not name the company');

        // Everything the form needs to go live, named at once.
        expect(c.review(publish: true), isFalse);
        expect(c.problems.keys, containsAll(['facilityType', 'locations', 'category', 'text']));
        // A draft is held only to the fields' own limits.
        expect(c.review(publish: false), isTrue, reason: '${c.problems}');

        final pune = (await c.searchPlaces('Pune')).first;
        c.addPlace(pune);
        c.update((d) {
          d
            ..facilityType = 'IT & ITES'
            ..category = 'SECURITY'
            ..text = 'Too short';
        });
        expect(c.review(publish: true), isFalse);
        expect(c.problems['text'], contains('at least ${RfqLimits.descriptionMin}'));

        // The same refusals from the API, on a draft (so only the field limits): each is a 400 with a sentence.
        String base() => 'A requirement of more than twenty characters.';
        Map<String, dynamic> body(Map<String, dynamic> extra) => {
          'title': 'zz company live rules',
          'kind': 'ENQUIRY',
          'status': 'DRAFT',
          'description': base(),
          ...extra,
        };
        final made = <String>[];
        addTearDown(() async {
          for (final id in made) {
            try {
              await repo.deleteDraft(id);
            } catch (_) {}
          }
        });
        final cases = <String, ({Map<String, dynamic> extra, void Function(RequirementDraft) breakIt, String field})>{
          'a contact name over 80 characters': (
            extra: {'contactName': 'N' * 81},
            breakIt: (d) => d.contactName = 'N' * 81,
            field: 'contactName',
          ),
          'a phone that is not 10 to 15 digits': (
            extra: {'contactPhone': 'call me'},
            breakIt: (d) => d.contactPhone = 'call me',
            field: 'contactPhone',
          ),
          'a title over 200 characters': (
            extra: {'title': 'T' * 201},
            breakIt: (d) => d.title = 'T' * 201,
            field: 'title',
          ),
        };
        for (final entry in cases.entries) {
          final fresh = PostRfqController(repository: repo);
          addTearDown(fresh.dispose);
          await fresh.start();
          fresh.update(entry.value.breakIt);
          if (entry.value.field == 'title') fresh.setTitle('T' * 201);
          fresh.review(publish: false);
          expect(fresh.problems.keys, contains(entry.value.field), reason: 'the form refuses ${entry.key}');
          PostResult? took;
          ApiError? refused;
          try {
            took = await repo.create(body(entry.value.extra));
            made.add(took.id);
          } catch (e) {
            refused = ApiError.from(e);
          }
          expect(took, isNull, reason: 'the API took ${entry.key}');
          expect(refused!.statusCode, 400, reason: entry.key);
          expect(refused.message, isNotEmpty, reason: entry.key);
        }

        // An RFQ: the two deadlines are the form's, in order.
        final rfq = PostRfqController(repository: repo, initialKind: RfqKind.rfq);
        addTearDown(rfq.dispose);
        await rfq.start();
        rfq.review(publish: true);
        expect(rfq.problems.keys, containsAll(['preQualEndDate', 'dueDate']));
        rfq.update((d) {
          d
            ..preQualEndDate = _inDays(5)
            ..dueDate = _inDays(5);
        });
        rfq.review(publish: true);
        expect(rfq.problems['dueDate'], contains('must come after the pre-qualification'));
        rfq.update((d) {
          d
            ..preQualEndDate = _inDays(-1)
            ..dueDate = _inDays(4);
        });
        rfq.review(publish: true);
        expect(rfq.problems['preQualEndDate'], contains('cannot be in the past'));
        rfq.update((d) => d.minYears = '3.5');
        rfq.review(publish: true);
        expect(rfq.problems['minYears'], 'Use a whole number of years');
        rfq.update((d) {
          d
            ..minYears = ''
            ..minAnnualTurnover = '9,00,00,000'
            ..minLast3YrTurnover = '1,00,00,000';
        });
        rfq.review(publish: true);
        expect(rfq.problems['minLast3YrTurnover'], contains('cannot be less than one year'));
      },
    );

    companyTest(
      'an admin posts an enquiry with places, items and a file; it reads back as typed and the team lists it',
      () async {
        final repo = await _repo(companyAdmin);
        final file = await repo.uploadFile(
          PickedRfqFile(name: 'site-layout.pdf', bytes: _pdf()),
          purpose: 'rfq-attachment',
        );
        expect(file.url, startsWith('/uploads/'));
        final posted = await _post(
          companyAdmin,
          tweak: (d) => d
            ..items = [
              const RfqItem(name: 'Security guards', quantity: 24, unit: 'guards', specification: 'PSARA licensed'),
            ]
            ..attachments = [
              RfqFile(
                id: '',
                title: 'Site layout, ground floor',
                url: file.url,
                name: file.name,
                mimeType: file.mimeType,
                size: file.size,
              ),
            ]
            ..dueDate = _inDays(20),
        );
        expect(posted.kind, RfqKind.enquiry);
        expect(posted.status, RfqStatus.published);
        expect(posted.alertedNow, isNotNull, reason: 'the API says how many suppliers it reached');
        final r = await repo.requirement(posted.id);
        expect(r.companyName, companyName);
        expect(r.contactName, isNotEmpty);
        expect(r.contactEmail, 'companyadmin@icr.test');
        expect(r.category, 'SECURITY');
        expect(r.facilityType, 'IT & ITES');
        expect(r.budget, 650000);
        expect(r.locations, ['Pune']);
        expect(r.state, 'Maharashtra');
        expect(r.items.single.name, 'Security guards');
        expect(r.items.single.quantity, 24);
        expect(r.files.single.title, 'Site layout, ground floor');
        expect(r.dueDate, isNotNull);
        expect((await repo.mine(search: 'zz company live')).rows.map((x) => x.id), contains(posted.id));
        final summary = await repo.summary();
        expect(summary.count(MyView.live), greaterThanOrEqualTo(1));
        expect((await repo.counts()).myRfqs, summary.open);
        // A supplier reads the same file list; the public file opens for them.
        expect((await (await _repo(bluepeak)).requirement(posted.id)).files.single.url, file.url);
      },
    );

    companyTest('a draft is saved, edited, published, copied, cancelled and deleted by the second admin', () async {
      final repo = await _repo(founder);
      final posted = await _post(founder, publish: false);
      expect(posted.status, RfqStatus.draft);
      expect((await repo.mine(view: MyView.draft)).rows.map((r) => r.id), contains(posted.id));
      await expectLater((await _repo(bluepeak)).requirement(posted.id), _status(404), reason: 'a draft is not public');
      // The first admin sees and edits the draft too.
      final other = await _repo(companyAdmin);
      expect((await other.mine(view: MyView.draft)).rows.map((r) => r.id), contains(posted.id));

      final edit = PostRfqController(repository: other, editingId: posted.id);
      await edit.start();
      expect(edit.editing, isTrue);
      expect(edit.draft.budget, '650000');
      edit.update((d) => d.budget = '7,25,000');
      expect(await edit.submit(publish: true), isTrue, reason: edit.error ?? '${edit.problems}');
      var r = await repo.requirement(posted.id);
      expect(r.status, RfqStatus.published);
      expect(r.budget, 725000);

      final copy = PostRfqController(repository: repo, copyFromId: posted.id);
      await copy.start();
      expect(copy.draft.text, startsWith('Round-the-clock'));
      expect(copy.draft.title, isEmpty);
      expect(copy.draft.dueDate, isNull);

      final owner = RfqDetailController(repository: repo, rfqId: posted.id);
      await owner.start();
      expect(await owner.act(RfqAction.cancel), isNull);
      r = await repo.requirement(posted.id);
      expect(r.status, RfqStatus.cancelled);
      expect((await repo.mine(view: MyView.ended)).rows.map((x) => x.id), contains(posted.id));

      final draft = await _post(founder, publish: false);
      await repo.deleteDraft(draft.id);
      await expectLater(repo.requirement(draft.id), _status(404));
    });

    companyTest(
      'an invite-only enquiry is seen only by the invited; the buying team invites more and the invited may decline',
      () async {
        final repo = await _repo(companyAdmin);
        final blue = await _repo(bluepeak);
        final bluepeakVendor = (await blue.access()).vendorId!;
        final posted = await _post(
          companyAdmin,
          tweak: (d) => d
            ..audience = Audience.invited
            ..invited = [SupplierRef(vendorId: bluepeakVendor, name: 'Bluepeak Security')],
        );
        final r = await repo.requirement(posted.id);
        expect(r.visibility, RfqVisibility.targeted);
        expect(r.status, RfqStatus.published, reason: 'an invite-only enquiry goes out at once');
        expect((await blue.invited()).map((x) => x.id), contains(posted.id));
        expect((await blue.openBoard(BoardQuery(search: r.title))).map((x) => x.id), isNot(contains(posted.id)));
        await expectLater((await _repo(innova)).requirement(posted.id), _status(404));

        final owner = RfqDetailController(repository: repo, rfqId: posted.id);
        await owner.start();
        expect(owner.invites.single.supplier.vendorId, bluepeakVendor);
        final suggested = await owner.suggested();
        expect(suggested.map((s) => s.supplier.vendorId), isNot(contains(bluepeakVendor)), reason: 'already invited');
        final innovaVendor = (await (await _repo(innova)).access()).vendorId!;
        expect(await owner.invite([innovaVendor]), isNull);
        expect(owner.invites.map((i) => i.supplier.vendorId), containsAll([bluepeakVendor, innovaVendor]));

        final page = await _page(bluepeak, posted.id);
        expect(page.invitedOnly, isTrue);
        expect(await page.decline(), isNull);
        await owner.refresh();
        expect(owner.invites.firstWhere((i) => i.supplier.vendorId == bluepeakVendor).status, InviteStatus.declined);
      },
    );
  });

  group('running the replies', () {
    companyTest(
      'replies arrive, alert the team, are shortlisted and declined and put back, a bidder is written to, one is selected',
      () async {
        final repo = await _repo(companyAdmin);
        final file = await (await _repo(innova)).uploadFile(
          PickedRfqFile(name: 'quotation.pdf', bytes: _pdf()),
          purpose: 'bid-attachment',
        );
        final posted = await _post(companyAdmin);
        final title = (await repo.requirement(posted.id)).title;
        expect(
          (await (await _repo(bluepeak)).openBoard(BoardQuery(search: title))).map((r) => r.id),
          contains(posted.id),
        );

        final blue = await _page(bluepeak, posted.id);
        expect(blue.state, ResponseState.form);
        expect(blue.context!.buyer!.companyName, companyName);
        expect(
          await blue.placeBid(
            BidDraft()
              ..amount = '5,00,000'
              ..leadTime = '10'
              ..message = 'We can mobilise within a week with a supervisor on site.',
          ),
          isNull,
        );
        final inno = await _page(innova, posted.id);
        expect(
          await inno.placeBid(
            BidDraft()
              ..amount = '5,40,000'
              ..leadTime = '7'
              ..message = 'Also ready, with a priced quotation.'
              ..attachments = [
                RfqFile(
                  id: '',
                  title: 'Priced quotation',
                  url: file.url,
                  name: file.name,
                  mimeType: file.mimeType,
                  size: file.size,
                ),
              ],
          ),
          isNull,
        );
        // The company's own supplier side cannot reply to its own requirement.
        final own = await _page(companyAdmin, posted.id);
        expect(own.state, ResponseState.own);

        // Two alerts reach the buying team, each naming its bid; opening the requirement reads them.
        final unread = (await repo.alerts(unreadOnly: true)).where((a) => a.rfqId == posted.id).toList();
        expect(unread, hasLength(2));
        expect(unread.every((a) => a.type == 'bid_received' && a.side == AlertSide.owner && a.bidId != null), isTrue);
        expect((await repo.counts()).newAlerts, greaterThanOrEqualTo(2));

        final owner = RfqDetailController(repository: repo, rfqId: posted.id);
        addTearDown(owner.dispose);
        await owner.start();
        expect(
          (await repo.alerts(unreadOnly: true)).where((a) => a.rfqId == posted.id),
          isEmpty,
          reason: 'opening reads them',
        );
        expect(owner.notOwner, isNull);
        expect(owner.bids, hasLength(2));
        expect(owner.sortedBids.first.supplier.name, 'Bluepeak Security', reason: 'lowest price first');
        expect(owner.rfq!.quoteCount, 2);

        // Shortlist and decline show at once, go to the API, and come back.
        final bid = owner.bids.firstWhere((b) => b.supplier.name == 'Bluepeak Security');
        Future<BidStatus> stored(String name) async =>
            (await repo.bids(posted.id)).firstWhere((b) => b.supplier.name == name).status;
        expect(await owner.triage(bid, BidStatus.shortlisted), isNull);
        expect(await stored('Bluepeak Security'), BidStatus.shortlisted);
        final supplier = MyBidsController(await _repo(bluepeak));
        addTearDown(supplier.dispose);
        await supplier.start();
        expect(supplier.bidsIn(BidsTab.shortlisted).map((b) => b.rfqId), contains(posted.id));
        expect(
          await owner.triage(owner.bids.firstWhere((b) => b.supplier.name == 'Bluepeak Security'), BidStatus.pending),
          isNull,
        );
        final innoBid = owner.bids.firstWhere((b) => b.supplier.name == 'Innova Facility Services');
        expect(await owner.triage(innoBid, BidStatus.rejected), isNull);
        expect(await stored('Innova Facility Services'), BidStatus.rejected);
        expect(
          await owner.triage(
            owner.bids.firstWhere((b) => b.supplier.name == 'Innova Facility Services'),
            BidStatus.pending,
          ),
          isNull,
        );
        expect(await stored('Innova Facility Services'), BidStatus.pending);

        // A bid's file is private: the buyer fetches it with the session, an outsider cannot.
        final stash = owner.bids.firstWhere((b) => b.supplier.name == 'Innova Facility Services').files.single;
        expect(await File(await repo.saveFile(stash)).readAsBytes(), _pdf());
        await expectLater((await _repo(marketBuyer)).saveFile(stash), _status(403));

        // Messages to a bidder: one thread per requirement and supplier company; the supplier finds the same one.
        final first = await owner.conversationWith(
          conversationId: bid.conversationId,
          supplierCompanyId: bid.supplier.companyId,
        );
        expect(first.error, isNull);
        expect(first.id, isNotEmpty);
        final again = await owner.conversationWith(supplierCompanyId: bid.supplier.companyId);
        expect(again.id, first.id);
        expect((await blue.messageBuyer()).id, first.id);
        await owner.refresh();
        expect(owner.threads.map((t) => t.conversationId), contains(first.id));

        // Select one: the enquiry closes for the others, both suppliers are told, a second decision is refused.
        final chosen = owner.bids.firstWhere((b) => b.supplier.name == 'Bluepeak Security');
        final result = await owner.award(chosen);
        expect(result.ok, isTrue, reason: result.message);
        expect(result.message, contains('Bluepeak Security selected'));
        expect((await repo.requirement(posted.id)).status, RfqStatus.awarded);
        expect(await stored('Bluepeak Security'), BidStatus.awarded);
        expect(await stored('Innova Facility Services'), BidStatus.rejected);
        expect(
          (await (await _repo(bluepeak)).alerts()).where((a) => a.rfqId == posted.id).map((a) => a.type),
          contains('bid_awarded'),
        );
        expect(
          (await (await _repo(innova)).alerts()).where((a) => a.rfqId == posted.id).map((a) => a.type),
          contains('bid_rejected'),
        );
        final second = await owner.award(owner.bids.firstWhere((b) => b.supplier.name == 'Innova Facility Services'));
        expect(second.ok, isFalse);
        expect(second.message, isNotEmpty);
        expect(await owner.act(RfqAction.close), isNull);
        expect((await repo.requirement(posted.id)).status, RfqStatus.closed);
        expect((await repo.mine(view: MyView.ended)).rows.map((r) => r.id), contains(posted.id));
      },
    );

    companyTest(
      'a staged RFQ runs from the criteria to a purchase order, and a supplier that misses them is shown as missing them',
      () async {
        final repo = await _repo(companyAdmin);
        final id = (await _post(companyAdmin, kind: RfqKind.rfq)).id;
        final posted = await repo.requirement(id);
        expect(posted.stage, RfqStage.prequalification);
        expect(posted.criteria.minYearsInBusiness, 3);
        expect(posted.criteria.statutoryCompliance, ['PSARA']);
        expect(posted.preQualEndDate, isNotNull);
        expect(posted.dueDate, isNotNull);

        final blue = await _page(bluepeak, id);
        expect(blue.state, ResponseState.preQual);
        expect(
          await _refusal((await _repo(bluepeak)).placeBid(id, {'totalAmount': 100})),
          isNotNull,
          reason: 'no quote yet',
        );
        expect(
          await blue.submitPreQual(
            PreQualDraft()
              ..yearsInBusiness = '9'
              ..annualTurnover = '9,00,00,000'
              ..compliance = {'PSARA'},
          ),
          isNull,
        );
        final inno = await _page(innova, id);
        expect(await inno.submitPreQual(PreQualDraft()..yearsInBusiness = '1'), isNull);

        final owner = RfqDetailController(repository: repo, rfqId: id);
        addTearDown(owner.dispose);
        await owner.start();
        final byName = {for (final r in owner.responses) r.supplier.name: r};
        expect(byName['Bluepeak Security']!.meetsCriteria, isTrue);
        expect(byName['Innova Facility Services']!.meetsCriteria, isFalse);
        expect(byName['Innova Facility Services']!.failures, isNotEmpty);
        expect((await repo.summary()).actionItems.where((a) => a.rfqId == id && a.kind == 'SCREEN'), hasLength(1));

        expect(await owner.screen(byName['Bluepeak Security']!, PreQualStatus.qualified), isNull);
        expect(await owner.screen(byName['Innova Facility Services']!, PreQualStatus.rejected), isNull);
        expect(
          await owner.shortlist(owner.responses.firstWhere((r) => r.supplier.name == 'Bluepeak Security')),
          isNotNull,
          reason: 'waits for its stage',
        );
        expect(await owner.advanceStage(), isNull);
        expect(owner.rfq!.stage, RfqStage.shortlisting);
        expect(
          await owner.shortlist(owner.responses.firstWhere((r) => r.supplier.name == 'Bluepeak Security')),
          isNull,
        );
        expect(await owner.advanceStage(), isNull);
        expect(owner.rfq!.stage, RfqStage.quotation);

        expect(
          await (await _page(innova, id)).placeBid(BidDraft()..amount = '1,00,000'),
          isNotNull,
          reason: 'not shortlisted',
        );
        final quoting = await _page(bluepeak, id);
        expect(quoting.state, ResponseState.form);
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
        expect((await (await _repo(bluepeak)).myBids()).firstWhere((b) => b.rfqId == id).poNumber, startsWith('PO-'));
      },
    );
  });

  group('the Marketplace\'s Request for Quote', () {
    companyTest(
      'the buyer company\'s admin (with a phone) asks a supplier for a quote and a product; each is a private enquiry',
      () async {
        final api = await liveClient(marketBuyer);
        final repo = ApiMarketplaceRepository(api: api);
        final supplier = await repo.supplier('design-mkt-v-sandbox');
        final services = await repo.servicesOf(supplier.companyId);
        expect(services, isNotEmpty);
        expect(await repo.hasPhone(), isTrue);

        final controller = QuoteController(repository: repo, supplier: supplier);
        addTearDown(controller.dispose);
        await controller.load();
        expect(controller.needsPhone, isFalse, reason: 'a number is on file, so the form does not ask');
        controller.pickService(controller.options!.first);
        expect(await controller.submit(), isTrue, reason: controller.error ?? '');
        final sent = controller.sent!;
        addTearDown(() => api.dio.delete<dynamic>('/rfq/${sent.id}'));
        final rfq = (await api.dio.get<Map<String, dynamic>>('/rfq/${sent.id}')).data!;
        expect(rfq['kind'], 'ENQUIRY');
        expect(rfq['status'], 'PUBLISHED');
        expect(rfq['visibility'], 'TARGETED');
        expect(rfq['companyId'], marketCompanyId);
        // It is the company's: it counts on My RFQ's, and its other member (Nikhil, a BUYER) sees it.
        expect((await _repo(marketBuyer).then((r) => r.mine())).rows.map((r) => r.id), contains(sent.id));
        expect((await _repo(marketNoPhone).then((r) => r.mine())).rows.map((r) => r.id), contains(sent.id));

        final securetech = await repo.supplier('design-mkt-v-securetech');
        final product = (await repo.productsOf(securetech.companyId)).first;
        final byProduct = await repo.requestQuote(
          QuoteRequest(vendorId: securetech.id, supplierName: securetech.name, product: product, quantity: 12),
        );
        addTearDown(() => api.dio.delete<dynamic>('/rfq/${byProduct.id}'));
        final items = ((await api.dio.get<Map<String, dynamic>>('/rfq/${byProduct.id}')).data!['items'] as List)
            .cast<Map<String, dynamic>>();
        expect(items.single['quantity'], 12);
      },
    );

    companyTest('the company admin of E2E Test Vendor Co asks a supplier for a quote with the phone on file', () async {
      final api = await liveClient(companyAdmin);
      final repo = ApiMarketplaceRepository(api: api);
      final supplier = await repo.supplier('design-mkt-v-sandbox');
      expect(await repo.hasPhone(), isTrue);
      final controller = QuoteController(repository: repo, supplier: supplier);
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.needsPhone, isFalse);
      controller.notes.text = 'Role test: a quote for the second site.';
      expect(await controller.submit(), isTrue, reason: controller.error ?? '');
      addTearDown(() => api.dio.delete<dynamic>('/rfq/${controller.sent!.id}'));
      expect(controller.sent!.title.toLowerCase(), contains('quote request'));
      // The colleague sees it on My RFQ's.
      expect(
        (await (await _repo(founder)).mine(search: 'quote request')).rows.map((r) => r.id),
        contains(controller.sent!.id),
      );
    });

    companyTest('a company that sells and buys cannot ask its own listing for a quote, and the form says so', () async {
      final api = await liveClient(companyAdmin);
      final repo = ApiMarketplaceRepository(api: api);
      final own = (await ApiRfqRepository(api: api).access()).vendorId!;
      final supplier = await repo.supplier(own);
      expect(supplier.name, companyName);
      final controller = QuoteController(repository: repo, supplier: supplier);
      addTearDown(controller.dispose);
      await controller.load();
      expect(await controller.submit(), isFalse);
      expect(controller.sent, isNull);
      expect(controller.error, contains('your own company'));
      expect(controller.error, isNot(contains('No valid companies')));
    });

    companyTest(
      'a buyer with no phone is asked for one, refused without it, and has it saved with the request',
      () async {
        final api = await liveClient(marketNoPhone);
        final repo = ApiMarketplaceRepository(api: api);
        // The seed leaves him without a number; an earlier run may have left one.
        await api.dio.patch<dynamic>('/users/me', data: {'phone': ''});
        addTearDown(() => api.dio.patch<dynamic>('/users/me', data: {'phone': ''}));
        expect(await repo.hasPhone(), isFalse);
        final supplier = await repo.supplier('design-mkt-v-sandbox');
        await expectLater(
          repo.requestQuote(QuoteRequest(vendorId: supplier.id, supplierName: supplier.name)),
          throwsA(
            isA<Object>().having(
              (e) => ApiError.from(e).message,
              'message',
              'Add a mobile number so the supplier can reach you.',
            ),
          ),
        );
        final controller = QuoteController(repository: repo, supplier: supplier);
        addTearDown(controller.dispose);
        await controller.load();
        expect(controller.needsPhone, isTrue);
        expect(await controller.submit(), isFalse);
        expect(controller.phoneProblem, startsWith('Add a mobile number'));
        controller.phone.text = '12345';
        expect(await controller.submit(), isFalse);
        expect(controller.phoneProblem, startsWith('Enter a valid mobile number'));
        controller.phone.text = '+91 98765 43210';
        expect(await controller.submit(), isTrue, reason: controller.error ?? '');
        addTearDown(() => api.dio.delete<dynamic>('/rfq/${controller.sent!.id}'));
        expect(await repo.hasPhone(), isTrue, reason: 'the number is on his profile now');
      },
    );

    companyTest(
      'an office admin, a recruiter and a hiring manager are refused a quote request in a sentence, and keep what they typed',
      () async {
        for (final who in [branchAdmin, recruiter, hiringManager]) {
          final repo = ApiMarketplaceRepository(api: await liveClient(who));
          final supplier = await repo.supplier('design-mkt-v-sandbox');
          final controller = QuoteController(repository: repo, supplier: supplier);
          addTearDown(controller.dispose);
          await controller.load();
          controller.notes.text = 'Role test, expected to be refused.';
          if (controller.needsPhone) controller.phone.text = '+91 98765 43210';
          expect(await controller.submit(), isFalse, reason: who.label);
          expect(controller.sent, isNull, reason: who.label);
          expect(controller.error, isNotEmpty, reason: who.label);
          expect(
            controller.error,
            isNot(contains('Insufficient')),
            reason: '${who.label}: said in words, not the guard\'s',
          );
          expect(controller.error, contains("Ask your company's admin"), reason: '${who.label}: and the way on');
          expect(
            controller.needsCompany,
            isFalse,
            reason: '${who.label} has a company: founding another is not the way',
          );
          expect(controller.notes.text, 'Role test, expected to be refused.');
        }
      },
    );
  });
}
