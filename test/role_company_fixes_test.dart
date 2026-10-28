/// The bugs the company-accounts role pass (`docs/ROLE_TEST_company.md`) found and fixed, each pinned without the
/// API: the live proof against the real answers is in `test/live/role_company_*_live_test.dart`.
///
///  1. A passed deadline read "Pre-qual closes closed 8 days ago" (the label and the relative day both said it).
///  2. The composer said "The list of services could not load." for the moment the list was still being fetched.
///  3. An office admin, a recruiter and a hiring manager (members of a company whose role does not post requirements)
///     were told on My RFQ's to "Create a company page", were let fill in the whole composer to be refused with the
///     guard's "Insufficient role permissions", and were told on the requirement page it "belongs to another company".
///  4. The Request for Quote form offered the same members "Create a company" for the same guard sentence.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/features/marketplace/quote_controller.dart';
import 'package:icr_mobile/features/rfq/demo_rfq_repository.dart';
import 'package:icr_mobile/features/rfq/my_rfqs_screen.dart';
import 'package:icr_mobile/features/rfq/post_rfq_controller.dart';
import 'package:icr_mobile/features/rfq/post_rfq_screen.dart';
import 'package:icr_mobile/features/rfq/rfq_detail_controller.dart';
import 'package:icr_mobile/features/rfq/rfq_format.dart';
import 'package:icr_mobile/features/rfq/rfq_links.dart' show RfqClock;
import 'package:icr_mobile/features/rfq/rfq_models.dart';

import 'helpers/fonts.dart';
import 'marketplace_fakes.dart';
import 'rfq_fakes.dart';

Poster _member(String role, {String? companyId = DemoRfqRepository.companyId, String? company = 'Acme Facilities'}) =>
    Poster(
      id: 'u-$role',
      name: 'A Member',
      email: 'member@example.test',
      role: role,
      phone: '+919879879898',
      companyId: companyId,
      companyName: company,
    );

/// The sample source, with who is asking replaced and the buyer's list refused the way the API refuses a role.
class _RoleRepo extends FlakyRfqRepository {
  _RoleRepo(Poster who) {
    poster = who;
    forbidMine = true;
    forbidBids = true;
  }

  /// The service list: answered when this completes.
  Completer<List<CategoryNode>>? categoryGate;

  @override
  Future<List<CategoryNode>> categories() => categoryGate?.future ?? super.categories();
}

void main() {
  setUpAll(loadAppFonts);
  tearDown(RfqClock.reset);

  group('a deadline that has passed', () {
    final now = DateTime.utc(2026, 10, 25, 9);
    Requirement live({RfqKind kind = RfqKind.enquiry, RfqStage? stage, DateTime? due, DateTime? preQual}) =>
        Requirement(
          id: 'r1',
          title: 'Guarding',
          kind: kind,
          status: RfqStatus.published,
          stage: stage,
          dueDate: due,
          preQualEndDate: preQual,
        );

    test('is worded once: "closed 8 days ago", never "closes closed"', () {
      expect(
        deadlineOf(
          live(kind: RfqKind.rfq, stage: RfqStage.prequalification, preQual: now.subtract(const Duration(days: 8))),
          now,
        ).toString(),
        'Pre-qual closed 8 days ago',
      );
      expect(
        deadlineOf(
          live(kind: RfqKind.rfq, stage: RfqStage.quotation, due: now.subtract(const Duration(days: 2))),
          now,
        ).toString(),
        'Quotes closed 2 days ago',
      );
      expect(deadlineOf(live(due: now.subtract(const Duration(days: 1))), now).toString(), 'Replies closed 1 day ago');
      expect(deadlineOf(live(due: now.subtract(const Duration(hours: 3))), now).toString(), 'Replies closed today');
    });

    test('a deadline still to come keeps its wording', () {
      expect(deadlineOf(live(due: now.add(const Duration(days: 9))), now).toString(), 'Replies due in 9 days');
      expect(
        deadlineOf(
          live(kind: RfqKind.rfq, stage: RfqStage.prequalification, preQual: now.add(const Duration(days: 5))),
          now,
        ).toString(),
        'Pre-qual closes in 5 days',
      );
      expect(
        deadlineOf(
          live(kind: RfqKind.rfq, stage: RfqStage.quotation, due: now.add(const Duration(days: 1))),
          now,
        ).toString(),
        'Quotes due tomorrow',
      );
    });
  });

  group('the list of services', () {
    testWidgets('says it is loading while it loads, and "could not load" only once it has failed', (tester) async {
      final repo = _RoleRepo(_member('COMPANY_ADMIN'))..categoryGate = Completer<List<CategoryNode>>();
      await pumpScreen(tester, PostRfqScreen(key: UniqueKey(), repository: repo));
      tester.view.physicalSize = const Size(390, 3600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await settle(tester, 14);
      expect(find.byKey(const ValueKey('services-loading')), findsOneWidget);
      expect(
        find.text('The list of services could not load.'),
        findsNothing,
        reason: 'it has not failed, it is on its way',
      );

      repo.categoryGate!.completeError(ApiError('The server said no.', statusCode: 500));
      await settle(tester, 14);
      expect(find.byKey(const ValueKey('services-loading')), findsNothing);
      expect(find.text('The list of services could not load.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('arrives, and the picker replaces the sentence', (tester) async {
      final repo = _RoleRepo(_member('COMPANY_ADMIN'))..categoryGate = Completer<List<CategoryNode>>();
      await pumpScreen(tester, PostRfqScreen(key: UniqueKey(), repository: repo));
      tester.view.physicalSize = const Size(390, 3600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await settle(tester, 14);
      expect(find.byKey(const ValueKey('services-loading')), findsOneWidget);
      repo.categoryGate!.complete(await DemoRfqRepository().categories());
      await settle(tester, 14);
      expect(find.byKey(const ValueKey('category-field')), findsOneWidget);
      expect(find.byKey(const ValueKey('services-loading')), findsNothing);
    });
  });

  group('an office admin, a recruiter and a hiring manager', () {
    const roles = {'BRANCH_ADMIN': 'an office admin', 'RECRUITER': 'a recruiter', 'HIRING_MANAGER': 'a hiring manager'};

    test('are named by the model as a company role that does not post', () {
      for (final entry in roles.entries) {
        final p = _member(entry.key);
        expect(p.roleCannotPost, isTrue, reason: entry.key);
        expect(p.cannotPostMessage, contains(entry.value));
        expect(p.cannotPostMessage, contains('Acme Facilities'));
        expect(p.cannotPostMessage, contains("company's admins"));
      }
      expect(_member('COMPANY_ADMIN').roleCannotPost, isFalse);
      expect(_member('BUYER').roleCannotPost, isFalse);
      expect(
        _member('PROFESSIONAL', companyId: null, company: null).roleCannotPost,
        isFalse,
        reason: 'no company: the other notice',
      );
    });

    testWidgets('My RFQ\'s says what their role may do and offers no new company', (tester) async {
      for (final entry in roles.entries) {
        final repo = _RoleRepo(_member(entry.key));
        await pumpScreen(tester, MyRfqsScreen(key: UniqueKey(), repository: repo, links: RecordingRfqLinks()));
        await settle(tester, 16);
        expect(find.byKey(const ValueKey('role-cannot-post')), findsOneWidget, reason: entry.key);
        expect(find.textContaining(entry.value), findsOneWidget, reason: entry.key);
        expect(find.text('Create a company page'), findsNothing, reason: entry.key);
        expect(find.text('Requirements are posted by buyers and companies'), findsNothing, reason: entry.key);
      }
    });

    testWidgets('My RFQ\'s still sends a person with no company to found one', (tester) async {
      final repo = _RoleRepo(_member('PROFESSIONAL', companyId: null, company: null));
      await pumpScreen(tester, MyRfqsScreen(key: UniqueKey(), repository: repo, links: RecordingRfqLinks()));
      await settle(tester, 16);
      expect(find.byKey(const ValueKey('role-cannot-post')), findsNothing);
      expect(find.text('Requirements are posted by buyers and companies'), findsOneWidget);
      expect(find.text('Create a company page'), findsOneWidget);
    });

    testWidgets('the composer says so before the form, and draws no Send', (tester) async {
      for (final entry in roles.entries) {
        final repo = _RoleRepo(_member(entry.key));
        await pumpScreen(tester, PostRfqScreen(key: UniqueKey(), repository: repo));
        await settle(tester, 16);
        expect(find.byKey(const ValueKey('role-cannot-post')), findsOneWidget, reason: entry.key);
        expect(find.textContaining(entry.value), findsOneWidget, reason: entry.key);
        expect(find.byKey(const ValueKey('send')), findsNothing, reason: entry.key);
        expect(find.byKey(const ValueKey('save-draft')), findsNothing, reason: entry.key);
        expect(find.byKey(const ValueKey('category-field')), findsNothing, reason: 'no form to fill in');
      }
    });

    testWidgets('the composer stays a form for an admin, a buyer and a person with no company', (tester) async {
      for (final p in [_member('COMPANY_ADMIN'), _member('BUYER')]) {
        await pumpScreen(tester, PostRfqScreen(key: UniqueKey(), repository: _RoleRepo(p)));
        await settle(tester, 16);
        expect(find.byKey(const ValueKey('role-cannot-post')), findsNothing, reason: p.role);
        expect(find.byKey(const ValueKey('send')), findsOneWidget, reason: p.role);
      }
      await pumpScreen(
        tester,
        PostRfqScreen(key: UniqueKey(), repository: _RoleRepo(_member('PROFESSIONAL', companyId: null, company: null))),
      );
      await settle(tester, 16);
      expect(find.byKey(const ValueKey('role-cannot-post')), findsNothing);
      expect(find.text('Requirements are posted for a company'), findsOneWidget);
    });

    test('the composer\'s controller knows it too', () async {
      final c = PostRfqController(repository: _RoleRepo(_member('RECRUITER')));
      await c.start();
      expect(c.roleCannotPost, isTrue);
      expect(c.roleCannotPostMessage, contains('a recruiter'));
      final admin = PostRfqController(repository: _RoleRepo(_member('COMPANY_ADMIN')));
      await admin.start();
      expect(admin.roleCannotPost, isFalse);
      expect(admin.roleCannotPostMessage, isEmpty);
    });

    test(
      'the requirement page calls a requirement of their own company theirs, and another company\'s another\'s',
      () async {
        final own = RfqDetailController(
          repository: _RoleRepo(_member('BRANCH_ADMIN')),
          rfqId: DemoRfqRepository.securityId,
        );
        await own.start();
        expect(own.rfq, isNotNull, reason: 'the brief reads');
        expect(own.notOwner, contains('a requirement of Acme Facilities'));
        expect(own.notOwner, contains('as an office admin you can read the brief only'));
        expect(own.notOwner, isNot(contains('another company')));

        final other = RfqDetailController(
          repository: _RoleRepo(_member('BRANCH_ADMIN', companyId: 'some-other-company', company: 'Elsewhere Ltd')),
          rfqId: DemoRfqRepository.securityId,
        );
        await other.start();
        expect(other.notOwner, contains('belongs to another company or person'));

        // An admin of the same company is the owner side and gets no sentence at all when the API lets them in.
        final repo = _RoleRepo(_member('COMPANY_ADMIN'))..forbidBids = false;
        final admin = RfqDetailController(repository: repo, rfqId: DemoRfqRepository.securityId);
        await admin.start();
        expect(admin.notOwner, isNull);
      },
    );
  });

  group('Request for Quote for a member of a company whose role does not post', () {
    SpyMarketplaceRepository refusing({required String? company}) =>
        _QuoteRepo(company)..failing['requestQuote'] = ApiError('Insufficient role permissions', statusCode: 403);

    test('is told who can send it, and is not offered a new company', () async {
      final c = QuoteController(
        repository: refusing(company: 'co-mine'),
        supplier: fakeSupplier('v1'),
      );
      addTearDown(c.dispose);
      await c.load();
      expect(await c.submit(), isFalse);
      expect(c.error, contains("Ask your company's admin"));
      expect(c.error, isNot(contains('Insufficient')));
      expect(c.error, isNot(contains('Create a company page')));
      expect(c.needsCompany, isFalse, reason: 'founding another company is not the way for someone who has one');
    });

    test('a source that cannot tell, or a person with no company, is told to found one, with the button', () async {
      final c = QuoteController(repository: refusing(company: null), supplier: fakeSupplier('v1'));
      addTearDown(c.dispose);
      await c.load();
      expect(await c.submit(), isFalse);
      expect(c.error, contains('Only a company can ask suppliers for quotes'));
      expect(c.error, contains('Create a company page on ICR first'));
      expect(c.needsCompany, isTrue);
    });
  });

  group('Request for Quote to the own listing of a company', () {
    test('is told a company cannot ask itself, not "No valid companies to invite."', () async {
      final supplier = fakeSupplier('v1'); // its company is `co-v1` in the fakes
      final repo = _QuoteRepo(supplier.companyId)
        ..failing['requestQuote'] = ApiError('No valid companies to invite.', statusCode: 400);
      final c = QuoteController(repository: repo, supplier: supplier);
      addTearDown(c.dispose);
      await c.load();
      expect(await c.submit(), isFalse);
      expect(c.error, contains('your own company'));
      expect(c.error, isNot(contains('No valid companies')));
    });

    test('the same sentence for someone else listing is shown as the API says it', () async {
      final repo = _QuoteRepo('co-mine')
        ..failing['requestQuote'] = ApiError('No valid companies to invite.', statusCode: 400);
      final c = QuoteController(repository: repo, supplier: fakeSupplier('v1'));
      addTearDown(c.dispose);
      await c.load();
      expect(await c.submit(), isFalse);
      expect(c.error, 'No valid companies to invite.');
    });
  });
}

class _QuoteRepo extends SpyMarketplaceRepository {
  _QuoteRepo(this.company);

  final String? company;

  @override
  Future<String?> myCompanyId() async => company;
}
