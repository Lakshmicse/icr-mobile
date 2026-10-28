/// Shared pieces of the company-account role pass (`role_company_live_test.dart`,
/// `docs/ROLE_TEST_company.md`): the accounts, a throwaway applicant, a text dump of a drawn screen.
///
/// The e2e accounts' passwords are NOT written here: they are read from the portal's
/// `e2e/fixtures/users.json` when a test runs (set `ICR_USERS_JSON` to move the file), and a run without the
/// file skips its tests.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/auth/auth_controller.dart';
import 'package:icr_mobile/features/jobs/employer/hiring_models.dart';
import 'package:icr_mobile/features/rfq/api_rfq_repository.dart';
import 'package:icr_mobile/features/rfq/post_rfq_controller.dart';
import 'package:icr_mobile/features/rfq/rfq_models.dart';
import 'package:icr_mobile/features/rfq/rfq_rules.dart';

import 'live.dart';

const _fixtureFiles = [r'E:\ICR\irc-portal\e2e\fixtures\users.json', '../irc-portal/e2e/fixtures/users.json'];

Map<String, String>? _passwords;

/// email -> password, from the e2e fixture file; empty when the file cannot be found.
Map<String, String> fixturePasswords() {
  final cached = _passwords;
  if (cached != null) return cached;
  final found = <String, String>{};
  final candidates = [
    if (Platform.environment['ICR_USERS_JSON'] != null) Platform.environment['ICR_USERS_JSON']!,
    ..._fixtureFiles,
  ];
  for (final path in candidates) {
    final file = File(path);
    if (!file.existsSync()) continue;
    try {
      for (final row in jsonDecode(file.readAsStringSync()) as List<dynamic>) {
        final map = row as Map<String, dynamic>;
        final email = map['email'] as String?;
        final password = map['password'] as String?;
        if (email != null && password != null) found[email] = password;
      }
      break;
    } catch (_) {
      // Not the file we wanted: try the next.
    }
  }
  return _passwords = found;
}

bool get fixturesAvailable => fixturePasswords().isNotEmpty;

LivePerson _fixture(String email, String label) => LivePerson(email, fixturePasswords()[email] ?? '', label);

/// COMPANY_ADMIN of E2E Test Vendor Co (a company that buys, sells and hires; verified; phone on file).
final companyAdmin = _fixture('companyadmin@icr.test', 'Chetan (COMPANY_ADMIN)');

/// BRANCH_ADMIN placed at the company's Head Office: office-scoped.
final branchAdmin = _fixture('branchadmin@icr.test', 'Bina (BRANCH_ADMIN, Head Office)');
final recruiter = _fixture('recruiter@icr.test', 'Rahul (RECRUITER, Head Office)');

/// Interview panelist: the narrow surface.
final hiringManager = _fixture('hiringmanager@icr.test', 'Hema (HIRING_MANAGER)');

/// A professional who founded the company and acts as its COMPANY_ADMIN.
final founder = _fixture('founder.professional@icr.test', 'Farah (COMPANY_ADMIN, personally PROFESSIONAL)');

/// The Marketplace seed's buyer company (`tool/seed/marketplace.ts`): an admin with a phone, a buyer without.
const marketBuyer = LivePerson(
  'marketplace.buyer@marketplace-design.icr.test',
  'Market@12345',
  'Maya (COMPANY_ADMIN, phone)',
);
const marketNoPhone = LivePerson(
  'marketplace.nophone@marketplace-design.icr.test',
  'Market@12345',
  'Nikhil (BUYER, no phone)',
);

/// The RFQ seed's suppliers (`tool/seed/rfq.ts`): who bids on the company's requirements in these tests.
const _rfqPassword = 'Rfq@12345';
const bluepeak = LivePerson('rfq.bluedot@rfq-design.icr.test', _rfqPassword, 'Bela (Bluepeak, Gold)');
const innova = LivePerson('rfq.innowork@rfq-design.icr.test', _rfqPassword, 'Ivan (Innova, Gold)');

/// The Inbox Persona (`tool/seed/inbox.ts`): a member outside the company who writes to it.
const outsider = LivePerson('inbox.friend@inbox-seed.icr.test', 'Inbox@12345', 'Anita Rao (a member outside)');

const companyName = 'E2E Test Vendor Co';
const marketCompanyId = 'design-mkt-co-buyer';

/// Declares a live test that also needs the e2e fixture file for the account passwords.
void companyTest(String description, Future<void> Function() body, {Timeout? timeout}) =>
    liveTest(description, () async {
      if (!fixturesAvailable) {
        markTestSkipped('the e2e fixture file with the account passwords was not found (ICR_USERS_JSON)');
        return;
      }
      await body();
    }, timeout: timeout ?? const Timeout(Duration(minutes: 3)));

int _counter = 0;

/// A new address on the domain the account seed's `--cleanup-live` sweeps.
String throwawayEmail() =>
    'rolecompany.tester.${DateTime.now().millisecondsSinceEpoch}${_counter++}@account-live.icr.test';

const throwawayPassword = 'Account-live-1';

/// A throwaway person signed up the way the screens do it (the code a non-production API hands back).
Future<({AuthController auth, ApiClient api, String email})> signUpThrowaway({String first = 'Rolecompany'}) async {
  final api = liveAnonymous();
  final auth = AuthController(api: api, tokens: api.tokens);
  final email = throwawayEmail();
  final code = await auth.sendEmailCode(email);
  expect(code, matches(RegExp(r'^\d{6}$')), reason: 'a non-production API hands the code back');
  await auth.verifyEmailCode(email, code!);
  await auth.register(email: email, password: throwawayPassword, firstName: first, lastName: 'Tester');
  expect(auth.status, SessionStatus.signedIn);
  return (auth: auth, api: api, email: email);
}

/// Every string a drawn screen shows, in order: what a reader of the screen would read.
List<String> shownText(WidgetTester tester) => [
  for (final t in tester.widgetList<Text>(find.byType(Text)))
    if ((t.data ?? t.textSpan?.toPlainText() ?? '').trim().isNotEmpty) (t.data ?? t.textSpan!.toPlainText()).trim(),
];

/// All of [shownText] as one string, for `contains`.
String shownBlob(WidgetTester tester) => shownText(tester).join(' | ');

/// A published enquiry posted as [who] through the composer's own controller, deleted when the test ends.
Future<PostResult> postRequirement(LivePerson who, {String? expectCompany}) async {
  final repo = ApiRfqRepository(api: await liveClient(who));
  final c = PostRfqController(repository: repo);
  await c.start();
  expect(c.loadError, isNull);
  expect(c.companyFromAccount, expectCompany ?? companyName);
  final pune = (await c.searchPlaces('Pune')).first;
  expect(c.addPlace(pune), isTrue);
  c.update((RequirementDraft d) {
    d
      ..facilityType = 'IT & ITES'
      ..category = 'SECURITY'
      ..subcategory = 'PHYSICAL_SECURITY'
      ..text = 'Round-the-clock guarding for a Pune campus: 24 guards, three shifts, from 1 December.'
      ..budget = '6,50,000';
  });
  c.setTitle('zz company live ${DateTime.now().millisecondsSinceEpoch}');
  expect(await c.submit(publish: true), isTrue, reason: c.error ?? '${c.problems}');
  final result = c.result!;
  addTearDown(() async {
    try {
      await repo.deleteDraft(result.id);
    } catch (_) {}
  });
  return result;
}

const longDescription =
    'Run the sites.\n\n## What you will do\n\n- Own shifts\n- Hold vendors to SLAs\n\n'
    'Lead day-to-day facilities operations across four logistics parks: rosters, statutory audits and the vendors who run them.';

/// A posting that passes the checklist, with no salary at all (salary is optional).
JobDraft readyDraft(String title) =>
    JobDraft(title: title, description: longDescription, cities: const ['Pune'], skills: const ['HVAC']);
