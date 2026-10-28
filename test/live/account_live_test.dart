/// The account screens' controls against the LOCAL portal API: each one does the real thing, the effect is
/// read back through the API, and what can be undone is undone.
///
/// People it uses (`tool/seed/account.ts`, run it first):
///  - Bharat Buyer (the emulator's person): only READ here, except saved items (saved, read back, un-saved)
///    and following (followed, read back, unfollowed).
///  - Anita Account (`acct.persona@account-design.icr.test`): the person whose profile, settings and company
///    list the write tests change. Each write is put back before the test ends; the few things the API
///    cannot take back (a phone confirmed by code, an uploaded picture's file) are named in the test, and
///    running the seed again resets her.
///  - Throwaway people (`acctlive.tester.<time>@account-live.icr.test`): sign-up, recovery, founding a company,
///    asking to join, being approved and leaving. They cannot be deleted through the API (`DELETE /users/me`
///    only anonymises, and a company has no delete), so `tool/seed/account.ts --cleanup-live` removes them.
///
/// Rate limits that matter: `POST /auth/forgot-password` is 5 an hour per address, `email/send-code` 20 an
/// hour, `register` 10 a minute, `POST /contact` 5 a minute. A run uses 1, 2, 2 and 1.
@Tags(['live'])
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/auth/auth_controller.dart';
import 'package:icr_mobile/features/account/account_models.dart';
import 'package:icr_mobile/features/account/api_account_repository.dart';
import 'package:icr_mobile/features/account/phone/phone_sheets.dart';
import 'package:icr_mobile/features/account/profile/profile_controller.dart';
import 'package:icr_mobile/features/account/saved/saved_models.dart';
import 'package:icr_mobile/features/account/saved/saved_repository.dart';
import 'package:icr_mobile/features/auth/recovery_repository.dart';
import 'package:icr_mobile/features/contact/api_contact_repository.dart';
import 'package:icr_mobile/features/contact/contact_models.dart';
import 'package:icr_mobile/features/network/api_network_repository.dart';
import 'package:icr_mobile/features/auth/your_work_step.dart';

import 'live.dart';

/// Anita Account, who the write tests change (`tool/seed/account.ts`).
const anita = LivePerson('acct.persona@account-design.icr.test', 'Account@12345', 'Anita Account');

const techcorpId = 'design-acct-co-techcorp';
const northwindId = 'design-acct-co-northwind';
const harbourId = 'design-acct-co-harbour';

int _counter = 0;

/// A new address nobody has used: the time plus a counter, on the domain `--cleanup-live` removes.
String throwawayEmail() =>
    'acctlive.tester.${DateTime.now().millisecondsSinceEpoch}${_counter++}@account-live.icr.test';

const throwawayPassword = 'Account-live-1';

Future<ApiAccountRepository> repoOf(LivePerson who) async => ApiAccountRepository(api: await liveClient(who));

/// A throwaway person, signed up through the app's own `AuthController` the way the screens do it:
/// the emailed code (returned by a non-production API), the code checked, then the account.
Future<({AuthController auth, ApiClient api, String email})> signUpThrowaway({String first = 'Acctlive'}) async {
  final api = liveAnonymous();
  final auth = AuthController(api: api, tokens: api.tokens);
  final email = throwawayEmail();
  final code = await auth.sendEmailCode(email);
  expect(
    code,
    matches(RegExp(r'^\d{6}$')),
    reason: 'a non-production API hands the code back, for "Test mode: your code is…"',
  );
  await auth.verifyEmailCode(email, code!);
  await auth.register(email: email, password: throwawayPassword, firstName: first, lastName: 'Tester');
  expect(auth.status, SessionStatus.signedIn);
  return (auth: auth, api: api, email: email);
}

/// The API's answer as a map, for what the app has no repository method for.
Future<Map<String, dynamic>> getMap(ApiClient api, String path, [Map<String, dynamic>? query]) async =>
    (await api.dio.get<Map<String, dynamic>>(path, queryParameters: query)).data!;

Future<ApiError> refusalOf(Future<Object?> call) async {
  try {
    await call;
  } on ApiError catch (e) {
    return e;
  } on DioException catch (e) {
    return ApiError.from(e);
  }
  fail('the API should have refused');
}

void main() {
  // ---------------------------------------------------------------------------------------------------
  // Reads: every parser against the real answer
  // ---------------------------------------------------------------------------------------------------

  group('reads: the parsers against the real answers', () {
    liveTest('my profile is the person, their headline and what the résumé holds', () async {
      final repo = await repoOf(bharat);
      final me = await repo.myProfile();
      expect(me.email, 'buyer@icr.dev');
      expect(me.fullName, 'Bharat Buyer');
      expect(me.designation, 'Lead Operations Manager at TechCorp');
      expect(me.headline, me.designation);
      expect(me.profileSlug, 'bharat-buyer');
      expect(me.avatarUrl, isNotNull);
      expect(me.coverImage, isNotNull);
      expect(me.hasResume, isTrue);
      expect(me.summary, contains('Facilities leader'));
      expect(me.location, 'Bengaluru, Karnataka');
      expect(me.skills, containsAll(['BMS Automation', 'HVAC Chillers']));
      expect(me.languages, containsAll(['English', 'Hindi']));
      expect(me.phone, startsWith('+91'));
      expect(me.completeness.score, inInclusiveRange(0, 100));
      expect(me.publicPath, '/members/bharat-buyer');
    });

    liveTest('experience, education, links and credentials read as the profile lists them', () async {
      final repo = await repoOf(bharat);
      final roles = await repo.experience();
      expect(roles.length, greaterThanOrEqualTo(2));
      final current = roles.firstWhere((r) => r.isCurrent);
      expect(current.title, 'Lead Operations Manager');
      expect(current.organisation, 'TechCorp');
      expect(current.company?.id, techcorpId, reason: 'a role linked to a company page');
      expect(current.startYear, 2019);
      expect(current.startMonth, 4);
      expect(current.id, isNotNull);

      final degrees = await repo.education();
      expect(degrees.first.institution, 'Visvesvaraya Technological University');
      expect(degrees.first.degree, 'B.Tech');
      expect(degrees.first.endYear, 2012);

      final links = await repo.links();
      expect(links.linkedin, 'https://linkedin.com/in/bharat-buyer');
      expect(links.present.keys, ['linkedinUrl']);

      expect(await repo.careerBreaks(), isEmpty);

      final credentials = await repo.credentials();
      final issued = credentials.firstWhere((c) => c.source == 'ICR_EXAM');
      expect(issued.name, 'Capital Planning');
      expect(issued.editable, isFalse, reason: 'ICR issued it: read-only');
      expect(issued.statusLabel, isNull);
      expect(issued.sourceLabel, 'Issued by ICR');
      expect(issued.href, '/learning/certificates/capital-planning-foundation');
      final own = credentials.firstWhere((c) => c.source == 'EXTERNAL');
      expect(own.editable, isTrue);
      expect(own.statusLabel, 'Self-declared');
      expect(own.code, 'NEBOSH-IGC');
    });

    liveTest('a member page: the headline, the lists, the groups and the counts', () async {
      final repo = await repoOf(bharat);
      final m = await repo.member('bharat-buyer');
      expect(m.fullName, 'Bharat Buyer');
      expect(m.isOwner, isTrue);
      expect(m.signedIn, isTrue);
      expect(m.headline, 'Lead Operations Manager · TechCorp');
      expect(m.city, 'Bengaluru, Karnataka');
      expect(m.about, contains('Facilities leader'));
      expect(m.skills, isNotEmpty);
      expect(m.experience.first.title, 'Lead Operations Manager');
      expect(m.education, isNotEmpty);
      expect(m.chapters.map((c) => c.slug), contains('bengaluru'));
      expect(m.councils, isNotEmpty);
      expect(m.follow.followers, greaterThan(0));
      expect(m.threads, greaterThanOrEqualTo(3));
      expect(m.memberSince, isNotNull);
      // By id too (the drawer links by slug, a feed by id).
      expect((await repo.member(m.id)).profileSlug, 'bharat-buyer');
      final posts = await repo.memberPosts(m.id);
      expect(posts, isNotEmpty);
      expect(posts.first.title, isNotEmpty);
    });

    liveTest('a member who does not exist is a refusal with a sentence, not a crash', () async {
      final repo = await repoOf(bharat);
      final e = await refusalOf(repo.member('no-such-member-anywhere'));
      expect(e.statusCode, 404);
      expect(e.message, isNotEmpty);
    });

    liveTest('the lookups: job titles, cities, company search and lookalikes', () async {
      final repo = await repoOf(bharat);
      final titles = await repo.jobTitles();
      expect(titles, contains('Facility Manager'));
      final cities = await repo.cities();
      final pune = cities.firstWhere((c) => c.name == 'Pune');
      expect(pune.state, 'Maharashtra');
      expect(pune.label, 'Pune, Maharashtra');
      final hits = await repo.searchCompanies('TechCorp');
      expect(hits.map((h) => h.id), contains(techcorpId));
      // The legal form is dropped from the name ("Pvt Ltd"); a company the person already belongs to is not offered.
      final like = await repo.lookalikes(name: 'Northwind Facilities Pvt Ltd');
      expect(like.map((c) => c.id), contains(northwindId));
      expect(like.first.name, 'Northwind Facilities');
      expect(like.first.reasonLabel, 'Similar name');
      expect((await repo.lookalikes(name: 'TechCorp Pvt Ltd')).map((c) => c.id), isNot(contains(techcorpId)));
    });

    liveTest('my companies: a place at TechCorp that is not the one acted for', () async {
      final repo = await repoOf(bharat);
      final mine = await repo.myCompanies();
      expect(mine.canJoinCompanies, isTrue);
      final tc = mine.companies.firstWhere((c) => c.companyId == techcorpId);
      expect(tc.name, 'TechCorp');
      expect(tc.active, isFalse);
      expect(tc.role, 'PROFESSIONAL');
      expect(tc.city, 'Bengaluru');
      expect(tc.verified, isTrue);
      expect(tc.memberCount, greaterThanOrEqualTo(2));
      expect(mine.active, isNull);
    });
  });

  // ---------------------------------------------------------------------------------------------------
  // Saved items: every kind saved, read back and un-saved
  // ---------------------------------------------------------------------------------------------------

  group('saved items', () {
    /// An id the kind's own list offers and Bharat has not saved.
    Future<String> candidate(ApiClient api, SavedKind kind, Set<String> saved) async {
      final rows = switch (kind) {
        SavedKind.jobs => (await getMap(api, '/jobs', {'limit': 30}))['data'],
        SavedKind.mentors => (await getMap(api, '/mentorship/mentors', {'limit': 30}))['data'],
        SavedKind.suppliers => (await getMap(api, '/vendors', {'limit': 30}))['data'],
        SavedKind.councils => (await getMap(api, '/councils'))['data'],
        SavedKind.discussions => (await getMap(api, '/forum/threads', {'limit': 30}))['data'],
      };
      for (final r in rows as List) {
        final id = '${(r as Map)['id']}';
        if (!saved.contains(id)) return id;
      }
      fail('no ${kind.label} to save');
    }

    for (final kind in SavedKind.values) {
      liveTest('${kind.label}: the list parses, save adds it, un-save takes it away', () async {
        final api = await liveClient(bharat);
        final repo = ApiSavedRepository(api: api);
        final before = await repo.load(kind);
        for (final item in before.items) {
          expect(item.id, isNotEmpty);
          expect(item.title, isNotEmpty);
          expect(item.kind, kind);
        }
        final id = await candidate(api, kind, {for (final i in before.items) i.id});
        final SavedItem probe = switch (kind) {
          SavedKind.jobs => SavedJob(id: id),
          SavedKind.mentors => SavedMentor(id: id, name: 'x'),
          SavedKind.suppliers => SavedSupplier(id: id, companyId: '', name: 'x'),
          SavedKind.councils => SavedCouncil(id: id, slug: '', name: 'x'),
          SavedKind.discussions => SavedThread(id: id, slug: '', threadTitle: 'x'),
        };
        await repo.save(probe);
        try {
          final saved = await repo.load(kind);
          expect(saved.items.map((i) => i.id), contains(id));
          expect(saved.total, before.total + 1);
          final row = saved.items.firstWhere((i) => i.id == id);
          expect(row.title, isNot('x'), reason: 'the list carries the item itself, not just its id');
        } finally {
          await repo.unsave(probe);
        }
        final after = await repo.load(kind);
        expect(after.items.map((i) => i.id), isNot(contains(id)));
        expect(after.total, before.total);
      });
    }
  });

  // ---------------------------------------------------------------------------------------------------
  // Sign-up and recovery: a throwaway person
  // ---------------------------------------------------------------------------------------------------

  group('sign-up and recovery', () {
    liveTest('three screens: the emailed code, the account, then "Your work" written to the profile', () async {
      final api = liveAnonymous();
      final auth = AuthController(api: api, tokens: api.tokens);
      final email = throwawayEmail();

      // The address is asked once; a wrong code is the API's own sentence.
      final code = await auth.sendEmailCode(email);
      expect(code, matches(RegExp(r'^\d{6}$')));
      final wrong = await refusalOf(auth.verifyEmailCode(email, code == '000000' ? '111111' : '000000'));
      expect(wrong.statusCode, 401);
      expect(wrong.message, 'That code is not right. Check the email and try again.');

      // No account until the code is right.
      expect(
        (await refusalOf(
          auth.register(email: email, password: throwawayPassword, firstName: 'Acctlive', lastName: 'Tester'),
        )).statusCode,
        isNotNull,
      );
      expect(auth.status, isNot(SessionStatus.signedIn));

      await auth.verifyEmailCode(email, code!);
      await auth.register(email: email, password: throwawayPassword, firstName: 'Acctlive', lastName: 'Tester');
      expect(auth.status, SessionStatus.signedIn);
      expect(auth.user!.email, email);
      expect(auth.user!.role, 'PROFESSIONAL', reason: 'a self-serve sign-up has no account type');

      // The address is taken now: another sign-up with it is a 409 ("That email already has an ICR account").
      final code2 = await auth.sendEmailCode(email).then<String?>((c) => c, onError: (Object e) => null);
      if (code2 != null) {
        // The API may still send a code; what matters is that registering again is refused.
        await auth.verifyEmailCode(email, code2);
      }
      final other = AuthController(api: liveAnonymous(), tokens: MemoryTokens());
      final duplicate = await refusalOf(
        other.register(email: email, password: throwawayPassword, firstName: 'Acctlive', lastName: 'Tester'),
      );
      expect(duplicate.statusCode, anyOf(409, 400));

      // "Your work": what the third screen writes, through the same function.
      final repo = ApiAccountRepository(api: api);
      final warning = await saveYourWork(
        repo,
        WorkAnswer(
          working: true,
          title: 'Facility Manager',
          company: 'TechCorp',
          picked: const CompanyHit(id: techcorpId, name: 'TechCorp', city: 'Bengaluru'),
          since: 2021,
          city: const CityOption(id: 'x', name: 'Pune', state: 'Maharashtra'),
        ),
      );
      expect(warning, isNull);
      final profile = await repo.myProfile();
      expect(profile.designation, 'Facility Manager');
      expect(profile.jobTitle, 'Facility Manager');
      expect(profile.location, 'Pune, Maharashtra');
      final roles = await repo.experience();
      expect(roles.single.title, 'Facility Manager');
      expect(roles.single.isCurrent, isTrue);
      expect(roles.single.startYear, 2021);
      expect(roles.single.company?.id, techcorpId, reason: 'the company picked from ICR is linked');
      // "Ask to join" went with it: a request is waiting at TechCorp.
      final mine = await repo.myCompanies();
      expect(mine.requests.map((r) => r.companyId), contains(techcorpId));
      // …and can be taken back.
      final after = await repo.withdrawRequest(techcorpId);
      expect(after.requests, isEmpty);
    });

    liveTest('between roles asks for no company and can say recruiters may know', () async {
      final who = await signUpThrowaway();
      final repo = ApiAccountRepository(api: who.api);
      final warning = await saveYourWork(
        repo,
        WorkAnswer(working: false, title: 'Site Engineer', company: '', readyNext: true),
      );
      expect(warning, isNull);
      expect(await repo.experience(), isEmpty, reason: 'no role is invented for someone between roles');
      final p = await repo.myProfile();
      expect(p.jobTitle, 'Site Engineer');
      final raw = await getMap(who.api, '/users/me/profile');
      expect((raw['resume'] as Map)['nextRoleStatus'], 'READY_NOW');
      expect((raw['resume'] as Map)['nextRoleVisibility'], 'RECRUITERS');
    });

    liveTest('forgot password, the reset link, a new password, then sign in with it', () async {
      final who = await signUpThrowaway();
      final repo = ApiRecoveryRepository(api: liveAnonymous());

      final ResetRequested asked;
      try {
        asked = await repo.requestReset(who.email);
      } on ApiError catch (e) {
        if (e.statusCode == 429) {
          markTestSkipped('POST /auth/forgot-password is throttled to 5 an hour per address: ${e.message}');
          return;
        }
        rethrow;
      }
      // With no mail provider the API hands the link back ("Test mode: use the link").
      expect(
        asked.resetUrl,
        isNotNull,
        reason: 'a local API with no mail provider returns the link it would have sent',
      );
      final token = tokenFromLink(asked.resetUrl!);
      expect(token, isNotNull);

      // A mistyped token is the API's sentence.
      final bad = await refusalOf(repo.resetPassword(token: 'x' * 40, password: 'Brand-new-pass1'));
      expect(bad.statusCode, 400);

      await repo.resetPassword(token: token!, password: 'Brand-new-pass1');
      // The old password is gone, the new one signs in, and the link is spent.
      final fresh = liveAnonymous();
      final auth = AuthController(api: fresh, tokens: fresh.tokens);
      expect(
        (await refusalOf(auth.signIn(email: who.email, password: throwawayPassword, rememberMe: false))).statusCode,
        401,
      );
      await auth.signIn(email: who.email, password: 'Brand-new-pass1', rememberMe: false);
      expect(auth.status, SessionStatus.signedIn);
      expect((await refusalOf(repo.resetPassword(token: token, password: 'Another-pass-2'))).statusCode, 400);
    });

    liveTest('an unknown address gets the same answer as a known one', () async {
      final repo = ApiRecoveryRepository(api: liveAnonymous());
      try {
        final asked = await repo.requestReset('nobody.${DateTime.now().millisecondsSinceEpoch}@account-live.icr.test');
        expect(asked.resetUrl, isNull, reason: 'no link for an address with no account');
      } on ApiError catch (e) {
        if (e.statusCode == 429) {
          markTestSkipped('forgot-password is throttled: ${e.message}');
          return;
        }
        rethrow;
      }
    });

    liveTest('verify-email: a link that is not one is the API\'s sentence; resend needs a session', () async {
      final repo = ApiRecoveryRepository(api: liveAnonymous());
      final bad = await refusalOf(repo.verifyEmail('y' * 40));
      expect(bad.statusCode, 400);
      expect(bad.message, isNotEmpty);
      // A new account starts confirmed, so a resend says there is nothing to confirm.
      final who = await signUpThrowaway();
      final signedIn = ApiRecoveryRepository(api: who.api);
      final sent = await signedIn.resendVerification();
      expect(sent.sent, isFalse);
    });
  });

  // ---------------------------------------------------------------------------------------------------
  // Companies: found one, ask to join, be approved, switch, leave
  // ---------------------------------------------------------------------------------------------------

  group('companies', () {
    liveTest('found a company, a second person asks to join, the admin approves, they switch and leave', () async {
      final founder = await signUpThrowaway(first: 'Acctlive');
      final fRepo = ApiAccountRepository(api: founder.api);
      final name = 'Account Live Test Co ${DateTime.now().millisecondsSinceEpoch}';

      // Create: the founder becomes its admin and acts for it, with a fresh token pair.
      final made = await fRepo.createCompany(
        CompanyDraft(
          name: name,
          industry: 'FM_SERVICES',
          size: '11-50',
          legalStructure: 'PRIVATE_LIMITED',
          city: 'Pune',
          state: 'Maharashtra',
          description: 'Made by the app\'s live test.',
        ),
      );
      await founder.auth.adoptSession(accessToken: made.accessToken, refreshToken: made.refreshToken, user: made.user);
      expect(founder.auth.user!.role, 'COMPANY_ADMIN');
      expect(founder.auth.user!.companyId, isNotNull);
      final companyId = founder.auth.user!.companyId!;
      var mine = await fRepo.myCompanies();
      expect(mine.active?.companyId, companyId);
      expect(mine.active?.name, name);
      expect(mine.active?.role, 'COMPANY_ADMIN');
      expect(mine.active?.soleAdmin, isTrue);

      // The only admin cannot leave: the API's sentence.
      final stuck = await refusalOf(fRepo.leaveCompany(companyId));
      expect(stuck.statusCode, anyOf(400, 403, 409));
      expect(stuck.message, isNotEmpty);

      // Lookalikes: typing the same name offers the page to join.
      final like = await ApiAccountRepository(api: (await signUpThrowaway()).api).lookalikes(name: name);
      expect(like.map((c) => c.id), contains(companyId));

      // A second person asks to join (with a note), sees the request, and can see it is waiting.
      final joiner = await signUpThrowaway(first: 'Acctjoiner');
      final jRepo = ApiAccountRepository(api: joiner.api);
      await jRepo.requestToJoin(companyId, note: 'I work on the Pune campus.');
      var theirs = await jRepo.myCompanies();
      expect(theirs.requests.single.companyId, companyId);
      expect(theirs.requests.single.note, 'I work on the Pune campus.');
      expect(
        (await refusalOf(jRepo.requestToJoin(companyId))).statusCode,
        anyOf(400, 409),
        reason: 'a second request is refused',
      );

      // Withdrawing takes it back; asking again works.
      theirs = await jRepo.withdrawRequest(companyId);
      expect(theirs.requests, isEmpty);
      await jRepo.requestToJoin(companyId);

      // The admin decides at /manage/team: approve.
      final joinerId = joiner.auth.user!.id;
      await founder.api.dio.post<Object?>('/team/requests/$joinerId/approve');

      theirs = await jRepo.myCompanies();
      expect(theirs.requests, isEmpty);
      final place = theirs.companies.single;
      expect(place.companyId, companyId);
      expect(place.active, isTrue, reason: 'someone acting for no company is moved into the first one that takes them');

      // Switch to themselves and back: a fresh token pair each time, which carries the company.
      final out = await jRepo.switchCompany(null);
      await joiner.auth.adoptSession(accessToken: out.accessToken, refreshToken: out.refreshToken, user: out.user);
      expect(joiner.auth.user!.companyId, isNull);
      expect(joiner.auth.user!.role, 'PROFESSIONAL');
      expect((await jRepo.myCompanies()).active, isNull);
      final into = await jRepo.switchCompany(companyId);
      await joiner.auth.adoptSession(accessToken: into.accessToken, refreshToken: into.refreshToken, user: into.user);
      expect(joiner.auth.user!.companyId, companyId);
      expect((await jRepo.myCompanies()).active?.companyId, companyId);

      // Leave: ends the place and answers with a fresh session.
      final left = await jRepo.leaveCompany(companyId);
      await joiner.auth.adoptSession(accessToken: left.accessToken, refreshToken: left.refreshToken, user: left.user);
      expect((await jRepo.myCompanies()).companies, isEmpty);
    });

    liveTest('Anita: switch into TechCorp and back, a request she can withdraw and ask again', () async {
      final repo = await repoOf(anita);
      var mine = await repo.myCompanies();
      expect(mine.companies.map((c) => c.companyId), containsAll([northwindId, techcorpId]));
      expect(mine.requests.map((r) => r.companyId), contains(harbourId));
      expect(
        mine.requests.firstWhere((r) => r.companyId == harbourId).note,
        'I work with Harbour on the Bandra campus.',
      );

      // Withdraw the waiting request and ask again (the note she wrote is kept off, the API takes none).
      mine = await repo.withdrawRequest(harbourId);
      expect(mine.requests, isEmpty);
      await repo.requestToJoin(harbourId, note: 'I work with Harbour on the Bandra campus.');
      expect((await repo.myCompanies()).requests.single.companyId, harbourId);

      // A client of her own, since switching changes the role its token carries.
      final api = await liveClient(anita, true);
      final mineRepo = ApiAccountRepository(api: api);
      final into = await mineRepo.switchCompany(northwindId);
      expect(into.user!['companyId'], northwindId);
      await api.tokens.save(accessToken: into.accessToken, refreshToken: into.refreshToken);
      expect((await mineRepo.myCompanies()).active?.companyId, northwindId);
      final back = await mineRepo.switchCompany(null);
      expect(back.user!['companyId'], isNull);
      await api.tokens.save(accessToken: back.accessToken, refreshToken: back.refreshToken);
      expect((await mineRepo.myCompanies()).active, isNull);
    });

    liveTest('the create form is refused with the API\'s own sentences', () async {
      final repo = await repoOf(anita);
      final e = await refusalOf(
        repo.createCompany(
          const CompanyDraft(
            name: 'X',
            industry: 'FM_SERVICES',
            size: '11-50',
            legalStructure: 'PRIVATE_LIMITED',
            city: 'Pune',
          ),
        ),
      );
      expect(e.statusCode, 400);
      expect(e.message, isNotEmpty);
      // Nothing was made, so she is still acting for no company.
      expect((await repo.myCompanies()).active, isNull);
    });
  });

  // ---------------------------------------------------------------------------------------------------
  // The person's profile: every sheet's write, read back, and put back
  // ---------------------------------------------------------------------------------------------------

  group('the profile page writes (Anita; each put back)', () {
    /// A 1 x 1 picture, for the photo and cover uploads.
    final png = PickedPhoto(
      bytes: base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
      ),
      name: 'live.png',
    );

    Future<MyProfileController> loaded() async {
      final c = MyProfileController(await repoOf(anita));
      await c.load();
      for (final s in [c.profile, c.experience, c.education, c.breaks, c.links, c.credentials]) {
        expect(s.error, isNull);
        expect(s.ready, isTrue);
      }
      return c;
    }

    liveTest('the page loads whole: the person, two roles, a degree, a break, a credential and the link', () async {
      final c = await loaded();
      final me = c.profile.value!;
      expect(me.fullName, 'Anita Account');
      expect(me.designation, 'Senior Facilities Analyst');
      expect(me.skills, contains('Space Planning'));
      expect(me.languages, ['English', 'Hindi', 'Kannada']);
      // Newest first, with the break among the roles in date order.
      expect(c.experience.value!.map((r) => r.title), ['Senior Facilities Analyst', 'Facilities Executive']);
      expect(c.experience.value!.first.company?.id, techcorpId);
      expect(c.timeline.where((e) => e.pause != null), hasLength(1));
      expect(c.education.value!.single.institution, 'Savitribai Phule Pune University');
      expect(c.links.value!.linkedin, 'https://linkedin.com/in/anita-account');
      expect(c.credentials.value!.single.statusLabel, 'Self-declared');
    });

    liveTest('the intro: name, headline, years and city are written, the résumé follows, and it is put back', () async {
      final c = await loaded();
      final api = await liveClient(anita);
      final before = c.profile.value!;
      try {
        await c.saveIntro(
          firstName: 'Anita',
          lastName: 'Account',
          headline: 'Lead Facilities Analyst',
          years: 7,
          location: 'Mumbai, Maharashtra',
        );
        final raw = await getMap(api, '/users/me/profile');
        expect((raw['user'] as Map)['designation'], 'Lead Facilities Analyst');
        expect((raw['user'] as Map)['yearsExperience'], 7);
        expect((raw['resume'] as Map)['jobTitle'], 'Lead Facilities Analyst');
        expect((raw['resume'] as Map)['location'], 'Mumbai, Maharashtra');
        expect(c.profile.value!.headline, 'Lead Facilities Analyst');
        // The API's own refusal is the sentence the sheet shows.
        final refused = await refusalOf(
          c.saveIntro(firstName: '', lastName: 'Account', headline: 'X', years: 7, location: ''),
        );
        expect(refused.statusCode, 400);
        expect(refused.message, isNotEmpty);
      } finally {
        await c.saveIntro(
          firstName: before.firstName,
          lastName: before.lastName,
          headline: before.headline ?? '',
          years: before.yearsExperience,
          location: before.location ?? '',
        );
      }
      expect(c.profile.value!.designation, 'Senior Facilities Analyst');
      expect(c.profile.value!.location, 'Pune, Maharashtra');
    });

    liveTest('About, Skills and Languages', () async {
      final c = await loaded();
      final before = c.profile.value!;
      try {
        await c.saveAbout('  A new summary written on the phone.  ');
        await c.saveSkills(['Space Planning', 'HVAC', 'Chillers']);
        await c.saveLanguages(['English', 'Tamil']);
        final me = await (await repoOf(anita)).myProfile();
        expect(me.summary, 'A new summary written on the phone.');
        expect(me.skills, ['Space Planning', 'HVAC', 'Chillers']);
        expect(me.languages, ['English', 'Tamil']);
        // Nine languages are one too many: the API's sentence.
        final tooMany = await refusalOf(c.saveLanguages(['A1', 'A2', 'A3', 'A4', 'A5', 'A6', 'A7', 'A8', 'A9']));
        expect(tooMany.statusCode, 400);
      } finally {
        await c.saveAbout(before.summary ?? '');
        await c.saveSkills(before.skills);
        await c.saveLanguages(before.languages);
      }
      final restored = await (await repoOf(anita)).myProfile();
      expect(restored.skills, before.skills);
      expect(restored.languages, before.languages);
    });

    liveTest('a role is added, edited and deleted through the whole-list save, and the list is put back', () async {
      final c = await loaded();
      final original = [...c.experience.value!];
      try {
        await c.saveRole(
          const Experience(
            title: 'Site Engineer',
            organisation: 'Harbour Builders',
            startYear: 2018,
            startMonth: 1,
            endYear: 2018,
            endMonth: 6,
          ),
        );
        expect(c.experience.value!.map((r) => r.title), contains('Site Engineer'));
        expect(c.experience.value!.length, original.length + 1);
        final added = c.experience.value!.firstWhere((r) => r.title == 'Site Engineer');
        expect(added.id, isNotNull);
        await c.saveRole(
          Experience(
            id: added.id,
            title: 'Senior Site Engineer',
            organisation: 'Harbour Builders',
            startYear: 2018,
            startMonth: 1,
            endYear: 2018,
            endMonth: 6,
          ),
        );
        expect(c.experience.value!.map((r) => r.title), contains('Senior Site Engineer'));
        // A role that starts in the future is the API's refusal.
        final future = await refusalOf(
          c.saveRole(
            Experience(title: 'Time Traveller', organisation: 'Later Ltd', startYear: DateTime.now().year + 2),
          ),
        );
        expect(future.statusCode, 400);
        final again = c.experience.value!.firstWhere((r) => r.title == 'Senior Site Engineer');
        await c.deleteRole(again.id!);
        expect(c.experience.value!.map((r) => r.title), isNot(contains('Senior Site Engineer')));
      } finally {
        await (await repoOf(anita)).saveExperience(original);
      }
      expect((await (await repoOf(anita)).experience()).map((r) => r.title), [
        'Senior Facilities Analyst',
        'Facilities Executive',
      ]);
    });

    liveTest('a qualification and a career break the same way', () async {
      final c = await loaded();
      final degrees = [...c.education.value!];
      final pauses = [...c.breaks.value!];
      try {
        await c.saveDegree(
          const Education(institution: 'IIM Bangalore', degree: 'PGDM', startYear: 2016, endYear: 2018),
        );
        expect(c.education.value!.map((e) => e.institution), contains('IIM Bangalore'));
        final bad = await refusalOf(
          c.saveDegree(const Education(institution: 'X Univ', startYear: 2015, endYear: 2012)),
        );
        expect(bad.statusCode, 400);
        await c.savePause(
          const CareerBreak(reason: 'TRAVEL', startYear: 2016, startMonth: 1, endYear: 2016, endMonth: 3),
        );
        expect(c.breaks.value!.length, pauses.length + 1);
        expect(c.timeline.where((e) => e.pause?.reason == 'TRAVEL'), hasLength(1));
      } finally {
        final repo = await repoOf(anita);
        await repo.saveEducation(degrees);
        await repo.saveCareerBreaks(pauses);
      }
      expect((await (await repoOf(anita)).education()).length, degrees.length);
      expect((await (await repoOf(anita)).careerBreaks()).length, pauses.length);
    });

    liveTest('a credential is added with its certificate, edited and deleted', () async {
      final c = await loaded();
      final evidence = await c.uploadEvidence(PickedPhoto(bytes: utf8.encode('%PDF-1.4 live'), name: 'cert.pdf'));
      expect(evidence.url, startsWith('/uploads/'));
      expect(evidence.name, 'cert.pdf');
      await c.addCredential(
        CredentialDraft(
          name: 'Live Test Certificate',
          code: 'LTC',
          issuer: 'Live Issuer',
          issuedOn: DateTime(2024, 1, 15),
          fileUrl: evidence.url,
          fileName: evidence.name,
        ),
      );
      final made = c.credentials.value!.firstWhere((x) => x.name == 'Live Test Certificate');
      try {
        expect(made.code, 'LTC');
        expect(made.editable, isTrue);
        expect(made.statusLabel, 'Certificate on file');
        expect(made.issuedAt, startsWith('2024-01-15'));
        await c.updateCredential(
          made.id,
          CredentialDraft(
            name: 'Live Test Certificate II',
            code: 'LTC',
            issuer: 'Live Issuer',
            issuedOn: DateTime(2024, 1, 15),
            fileUrl: evidence.url,
            fileName: evidence.name,
          ),
        );
        expect(c.credentials.value!.map((x) => x.name), contains('Live Test Certificate II'));
        // The same code twice is the API's refusal.
        final twice = await refusalOf(c.addCredential(const CredentialDraft(name: 'Another', code: 'LTC')));
        expect(twice.statusCode, anyOf(400, 409));
      } finally {
        final now = c.credentials.value!.where((x) => x.name.startsWith('Live Test Certificate')).toList();
        for (final x in now) {
          await c.deleteCredential(x.id);
        }
      }
      expect(c.credentials.value!.map((x) => x.name), isNot(contains('Live Test Certificate II')));
    });

    liveTest('the photo is uploaded and set, served back, then removed; the cover too', () async {
      final c = await loaded();
      final api = await liveClient(anita);
      await c.uploadPhoto(png);
      try {
        final url = c.profile.value!.avatarUrl!;
        expect(url, startsWith('/uploads/'));
        final res = await Dio().get<List<int>>(
          'http://localhost:3001$url',
          options: Options(responseType: ResponseType.bytes),
        );
        expect(res.statusCode, 200);
        expect(res.headers.value('content-type'), startsWith('image/png'));
        expect(
          (await api.dio.get<Map<String, dynamic>>('/auth/me')).data!['avatarUrl'],
          url,
          reason: 'the session sees it too',
        );
      } finally {
        await c.removePhoto();
      }
      expect(c.profile.value!.avatarUrl, isNull);

      await c.setCover('skyline');
      expect(c.profile.value!.coverImage, 'skyline');
      expect((await getMap(api, '/members/anita-account'))['coverImage'], 'skyline');
      final own = await c.uploadCover(png);
      expect(c.profile.value!.coverImage, own);
      await c.setCover(null);
      expect(c.profile.value!.coverImage, isNull);
      // Nothing but a ready-made cover or an uploaded file is a cover.
      final bad = await refusalOf(c.setCover('https://example.com/x.png'));
      expect(bad.statusCode, 400);
    });

    liveTest('contact info: a work email, a second number and the links, saved together and put back', () async {
      final c = await loaded();
      try {
        await c.saveContact(
          workEmail: 'anita@work.example.com',
          altPhone: '+919800000001',
          changedLinks: {
            'linkedinUrl': 'https://linkedin.com/in/anita-account',
            'websiteUrl': 'https://anita.example.com',
            'twitterUrl': '',
            'githubUrl': '',
            'portfolioUrl': '',
          },
        );
        final again = await loaded();
        expect(again.profile.value!.workEmail, 'anita@work.example.com');
        expect(again.profile.value!.altPhone, '+919800000001');
        expect(again.links.value!.website, 'https://anita.example.com');
        // The links go first: a refusal there writes nothing else.
        final bad = await refusalOf(
          c.saveContact(
            workEmail: 'second@work.example.com',
            altPhone: '',
            changedLinks: {
              'linkedinUrl': 'https://example.com/me',
              'websiteUrl': '',
              'twitterUrl': '',
              'githubUrl': '',
              'portfolioUrl': '',
            },
          ),
        );
        expect(bad.statusCode, 400);
        expect((await (await repoOf(anita)).myProfile()).workEmail, 'anita@work.example.com');
      } finally {
        await (await loaded()).saveContact(
          workEmail: '',
          altPhone: '',
          changedLinks: {
            'linkedinUrl': 'https://linkedin.com/in/anita-account',
            'websiteUrl': '',
            'twitterUrl': '',
            'githubUrl': '',
            'portfolioUrl': '',
          },
        );
      }
      final after = await loaded();
      expect(after.profile.value!.workEmail, isNull);
      expect(after.links.value!.present.keys, ['linkedinUrl']);
    });
  });

  // ---------------------------------------------------------------------------------------------------
  // The mobile number: the code, the number kept as typed, the number asked for
  // ---------------------------------------------------------------------------------------------------

  group('the mobile number', () {
    liveTest(
      "another country's number is kept as typed; an Indian one is confirmed with the code the API hands back",
      () async {
        final repo = await repoOf(anita);
        final api = await liveClient(anita);
        await repo.updateMe({'phone': '+971501234567'});
        expect((await repo.myProfile()).phone, '+971501234567');
        expect((await repo.myProfile()).phoneVerified, isFalse);
        // A code cannot reach it: the API refuses to send one.
        final cannot = await refusalOf(repo.sendPhoneCode('+971501234567'));
        expect(cannot.statusCode, 400);

        await repo.updateMe({'phone': '+919812340000'});
        final code = await repo.sendPhoneCode('+919812340000');
        expect(
          code,
          matches(RegExp(r'^\d{6}$')),
          reason: 'a non-production API hands the code back: "Test mode: your code is …"',
        );
        final wrong = await refusalOf(repo.verifyPhoneCode('+919812340000', code == '000000' ? '111111' : '000000'));
        expect(wrong.statusCode, anyOf(400, 401));
        expect(wrong.message, isNotEmpty);
        await repo.verifyPhoneCode('+919812340000', code!);
        final me = await repo.myProfile();
        expect(me.phone, '+919812340000');
        expect(me.phoneVerified, isTrue);
        expect((await api.dio.get<Map<String, dynamic>>('/auth/me')).data!['phoneVerified'], isTrue);
        // Cannot be undone through the API: `tool/seed/account.ts` resets her to "not verified".
      },
    );

    liveTest(
      'PhoneNeededController: not asked of someone with a number; asked of someone with none, and once saved never again',
      () async {
        final bharatRepo = await repoOf(bharat);
        final has = PhoneNeededController(lookup: () async => (await bharatRepo.myProfile()).phone);
        await has.load();
        expect(has.needed, isFalse);
        expect(has.payload, isEmpty);

        final who = await signUpThrowaway();
        final repo = ApiAccountRepository(api: who.api);
        final needs = PhoneNeededController(lookup: () async => (await repo.myProfile()).phone);
        await needs.load();
        expect(needs.needed, isTrue);
        expect(needs.check(), isFalse);
        needs.setPhone('+919812349999');
        expect(needs.check(), isTrue);
        expect(needs.payload, {'phone': '+919812349999'});
        // An action that takes `phone` (applying for a job, asking a mentor) saves it with the action;
        // the plain profile write stands for that here: the number lands on the account.
        await repo.updateMe({'phone': needs.payload['phone']});
        expect((await repo.myProfile()).phone, '+919812349999');
        final after = PhoneNeededController(lookup: () async => (await repo.myProfile()).phone);
        await after.load();
        expect(after.needed, isFalse, reason: 'once saved it is never asked again');
      },
    );
  });

  // ---------------------------------------------------------------------------------------------------
  // Settings: language, notification preferences, the export, deleting the account
  // ---------------------------------------------------------------------------------------------------

  group('settings', () {
    liveTest('the language is saved on the account and read back; English clears it', () async {
      final repo = await repoOf(anita);
      expect(await repo.accountLocale(), isNull);
      try {
        await repo.updateMe({'locale': 'hi'});
        expect(await repo.accountLocale(), 'hi');
        await repo.updateMe({'locale': 'kn'});
        expect(await repo.accountLocale(), 'kn');
      } finally {
        await repo.updateMe({'locale': null});
      }
      expect(await repo.accountLocale(), isNull);
      expect((await refusalOf(repo.updateMe({'locale': 'xx'}))).statusCode, 400);
    });

    liveTest(
      'notification preferences: every kind, one switch changed alone, locked ones refuse, and it is put back',
      () async {
        final repo = await repoOf(anita);
        final before = await repo.notificationPreferences();
        expect(before.map((r) => r.category), containsAll(['messages', 'jobs', 'payments', 'security']));
        final jobs = before.firstWhere((r) => r.category == 'jobs');
        expect(jobs.locked, isFalse);
        expect(before.firstWhere((r) => r.category == 'security').locked, isTrue);
        try {
          final saved = await repo.saveNotificationPreferences([jobs.copyWith(email: !jobs.email)]);
          expect(saved.firstWhere((r) => r.category == 'jobs').email, !jobs.email);
          expect(
            saved.firstWhere((r) => r.category == 'messages').email,
            before.firstWhere((r) => r.category == 'messages').email,
            reason: 'only that row changed',
          );
          expect((await repo.notificationPreferences()).firstWhere((r) => r.category == 'jobs').email, !jobs.email);
          // A locked kind stays on whatever is sent.
          final locked = before.firstWhere((r) => r.category == 'security');
          final after = await repo.saveNotificationPreferences([locked.copyWith(email: false, inApp: false)]);
          expect(after.firstWhere((r) => r.category == 'security').email, isTrue);
        } finally {
          await repo.saveNotificationPreferences([jobs]);
        }
        expect((await repo.notificationPreferences()).firstWhere((r) => r.category == 'jobs').email, jobs.email);
      },
    );

    liveTest("Download my data is the account's personal data as JSON", () async {
      final data = await (await repoOf(anita)).exportData();
      expect(data['exportedAt'], isNotNull);
      expect((data['account'] as Map)['email'], 'acct.persona@account-design.icr.test');
      expect(data['note'], contains('personal data'));
    });

    liveTest('Delete my account anonymises it and ends the session; the old sign-in no longer works', () async {
      final who = await signUpThrowaway(first: 'Acctdelete');
      final repo = ApiAccountRepository(api: who.api);
      await repo.deleteAccount();
      await who.auth.forgetSession();
      expect(who.auth.status, SessionStatus.signedOut);
      final fresh = liveAnonymous();
      final auth = AuthController(api: fresh, tokens: fresh.tokens);
      final e = await refusalOf(auth.signIn(email: who.email, password: throwawayPassword, rememberMe: false));
      expect(e.statusCode, 401);
    });
  });

  // ---------------------------------------------------------------------------------------------------
  // Another member's page, follow and message
  // ---------------------------------------------------------------------------------------------------

  group("a member's public page", () {
    liveTest("Anita's page as Bharat sees it: headline, roles with their company, groups, counts", () async {
      final repo = await repoOf(bharat);
      final m = await repo.member('anita-account');
      expect(m.isOwner, isFalse);
      expect(m.signedIn, isTrue);
      expect(m.fullName, 'Anita Account');
      expect(m.headline, 'Senior Facilities Analyst · TechCorp');
      expect(m.about, contains('Facilities analyst'));
      expect(m.skills, contains('Space Planning'));
      expect(m.experience.first.company?.id, techcorpId);
      expect(m.education.single.institution, 'Savitribai Phule Pune University');
      expect(m.links.linkedin, 'https://linkedin.com/in/anita-account');
      expect(m.languages, contains('Hindi'));
      // Her own view of herself says so.
      final own = await (await repoOf(anita)).member('anita-account');
      expect(own.isOwner, isTrue);
    });

    liveTest('Follow and Unfollow are kept by the API and counted', () async {
      final repo = await repoOf(bharat);
      final anitaId = (await repo.member('anita-account')).id;
      final before = (await repo.member(anitaId)).follow;
      try {
        final on = await repo.follow(anitaId);
        expect(on.viewerFollows, isTrue);
        expect(on.followers, before.followers + (before.viewerFollows ? 0 : 1));
        expect((await repo.member(anitaId)).follow.viewerFollows, isTrue);
      } finally {
        final off = await repo.unfollow(anitaId);
        expect(off.viewerFollows, isFalse);
      }
      expect((await repo.member(anitaId)).follow.followers, before.followers - (before.viewerFollows ? 1 : 0));
      // Following yourself is the API's sentence.
      final me = (await repo.myProfile()).id;
      expect((await refusalOf(repo.follow(me))).statusCode, 400);
    });

    liveTest('Message finds or opens the one plain thread with the member, and a second time finds the same', () async {
      final repo = await repoOf(bharat);
      final id = (await repo.member('anita-account')).id;
      final first = await repo.startConversation(id);
      expect(first, isNotEmpty);
      expect(await repo.startConversation(id), first);
      // It is a real conversation Anita can read: the thread exists on her side too.
      final api = await liveClient(anita);
      final mine = await getMap(api, '/messaging/conversations/$first');
      expect(mine['id'], first);
      // Cannot be undone through the API; the same thread is reused every run.
    });
  });

  // ---------------------------------------------------------------------------------------------------
  // Network and contact: proof against the real API
  // ---------------------------------------------------------------------------------------------------

  group('network', () {
    liveTest('the four lists parse, and a follow from suggestions shows in Following until it is taken back', () async {
      final repo = ApiNetworkRepository(api: await liveClient(bharat));
      final me = await repo.viewerId();
      expect(me, isNotEmpty);
      final feed = await repo.feed();
      expect(feed.total, greaterThanOrEqualTo(0));
      for (final post in feed.items) {
        expect(post.title, isNotEmpty);
        expect(post.author.name, isNotEmpty);
      }
      final following = await repo.following();
      expect(following.items, isNotEmpty);
      final followers = await repo.followers(me);
      expect(followers.total, greaterThan(0));
      final suggestions = await repo.suggestions();
      expect(suggestions, isNotEmpty);
      final pick = suggestions.firstWhere((p) => !following.items.any((f) => f.id == p.id));
      expect(pick.reason, isNotNull);
      try {
        final counts = await repo.follow(pick.id);
        expect(counts.viewerFollows, isTrue);
        expect((await repo.following()).items.map((p) => p.id), contains(pick.id));
      } finally {
        await repo.unfollow(pick.id);
      }
      expect((await repo.following()).items.map((p) => p.id), isNot(contains(pick.id)));
    });
  });

  group('contact', () {
    liveTest(
      'the form fills in from the person; a message is filed and answered with its id; a bad one is refused with sentences',
      () async {
        final repo = ApiContactRepository(api: await liveClient(bharat));
        final sender = await repo.sender();
        expect(sender?.name, 'Bharat Buyer');
        expect(sender?.email, 'buyer@icr.dev');
        expect(await ApiContactRepository(api: liveAnonymous()).sender(), isNull, reason: 'a visitor is not an error');

        final id = await repo.send(
          const ContactMessage(
            name: 'Account Live',
            email: 'acctlive.contact@account-live.icr.test',
            topic: ContactTopic.other,
            message: "A message from the app's live test: please ignore.",
          ),
        );
        expect(id, isNotEmpty);
        final bad = await refusalOf(
          repo.send(const ContactMessage(name: 'X', email: 'not-an-email', topic: ContactTopic.support, message: 'Hi')),
        );
        expect(bad.statusCode, 400);
        expect(bad.message, isNotEmpty);
        // Cannot be undone through the API: `tool/seed/account.ts --cleanup-live` removes messages from @account-live.icr.test.
      },
    );
  });
}
