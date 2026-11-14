import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/features/account/account_models.dart';
import 'package:icr_mobile/features/account/api_account_repository.dart';
import 'package:icr_mobile/features/account/companies/ask_to_join_sheet.dart';
import 'package:icr_mobile/features/account/companies/create_company_controller.dart';
import 'package:icr_mobile/features/account/companies/create_company_screen.dart';
import 'package:icr_mobile/features/account/companies/my_companies_screen.dart';
import 'package:icr_mobile/features/account/demo_account_repository.dart';

import 'helpers/account_harness.dart';
import 'helpers/fonts.dart';

/// "My companies" (act for one, or for yourself; leave; withdraw a request; ask
/// to join; create) and "Create a Company Page", with the fresh token pair
/// every switch, leave and create hands back, taken through the app's own
/// `AuthController`.
void main() {
  setUpAll(loadAppFonts);

  const tech = MyCompany(
    companyId: 'co-techcorp',
    name: 'TechCorp',
    role: 'COMPANY_ADMIN',
    city: 'Bengaluru',
    state: 'Karnataka',
    industry: 'CORPORATE_OCCUPIER',
    verified: true,
    memberCount: 14,
    soleAdmin: false,
    pendingJoinRequests: 2,
  );
  const north = MyCompany(
    companyId: 'co-north',
    name: 'Northwind Facilities',
    role: 'PROFESSIONAL',
    city: 'Pune',
    state: 'Maharashtra',
    industry: 'FM_SERVICES',
    memberCount: 51,
  );
  const mine = MyCompany(
    companyId: 'co-mine',
    name: 'My Own Co',
    role: 'COMPANY_ADMIN',
    memberCount: 1,
    soleAdmin: true,
    active: true,
  );

  late AccountHarness h;

  Future<DemoAccountRepository> pumpList(
    WidgetTester tester, {
    MyCompanies? companies,
    List<String>? log,
    DemoAccountRepository? repo,
    Map<String, ApiHandler> routes = const {},
    bool focusInvitations = false,
  }) async {
    final r =
        repo ??
        DemoAccountRepository(
          companies: companies ?? MyCompanies(personalRole: 'PROFESSIONAL', companies: const [tech, north]),
        );
    h = AccountHarness(routes: routes);
    await h.signIn(tester);
    usePhone(tester);
    await tester.pumpWidget(
      h.app(
        MyCompaniesScreen(
          repository: r,
          onSessionChanged: () => log?.add('session'),
          onOpenCompany: (id) => log?.add('open:$id'),
          searchDelay: Duration.zero,
          focusInvitations: focusInvitations,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return r;
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 250, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final target = find.byKey(Key(key));
    await reveal(tester, target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  group('the list', () {
    testWidgets(
      'each company with its role, place, size and what waits; the personal account is always there and Active when none is',
      (tester) async {
        await pumpList(tester);
        expect(find.text('My Companies'), findsOneWidget);
        expect(find.text('TechCorp'), findsOneWidget);
        expect(find.byKey(const Key('company.role.co-techcorp')), findsOneWidget);
        expect(find.text('Company Admin'), findsOneWidget);
        expect(find.text('Bengaluru, Karnataka'), findsOneWidget);
        expect(find.text('14 members'), findsOneWidget);
        expect(find.text('2 awaiting approval'), findsOneWidget);
        expect(find.text('Northwind Facilities'), findsOneWidget);
        await reveal(tester, find.byKey(const Key('company.personal')));
        expect(find.text('Personal Account'), findsOneWidget);
        expect(find.byKey(const Key('company.personal.active')), findsOneWidget);
        expect(find.byKey(const Key('company.switch.personal')), findsNothing);
        expect(find.text('3'), findsOneWidget, reason: 'two companies and the personal account');
      },
    );

    testWidgets('loading, then a failure says why with Try again; a pull reads again', (tester) async {
      final repo = DemoAccountRepository()..failures['myCompanies'] = ApiError('The server is busy.', statusCode: 503);
      await pumpList(tester, repo: repo);
      expect(find.text('The server is busy.'), findsOneWidget);
      repo.failures.clear();
      await tester.tap(find.byKey(const Key('account.retry')));
      await tester.pumpAndSettle();
      expect(find.text('TechCorp'), findsOneWidget);
      final before = repo.count('myCompanies');
      await tester.fling(find.byKey(const Key('companies.list')), const Offset(0, 400), 1000);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(repo.count('myCompanies'), before + 1);
    });

    testWidgets('someone in no company sees what to do: create or ask to join', (tester) async {
      await pumpList(tester, companies: const MyCompanies(personalRole: 'PROFESSIONAL'));
      await reveal(tester, find.byKey(const Key('companies.empty')));
      expect(find.text('You Are Not Part of a Company Yet'), findsOneWidget);
      expect(find.byKey(const Key('companies.empty.create')), findsOneWidget);
      expect(find.byKey(const Key('companies.empty.join')), findsOneWidget);
    });

    testWidgets('an ICR staff account is told it is personal: no create, no join', (tester) async {
      await pumpList(tester, companies: const MyCompanies(personalRole: 'SUPER_ADMIN', canJoinCompanies: false));
      expect(find.byKey(const Key('companies.staff')), findsOneWidget);
      expect(find.byKey(const Key('companies.create')), findsNothing);
      expect(find.byKey(const Key('companies.join')), findsNothing);
    });

    testWidgets('with six or more companies a search appears and narrows the list; nothing matching says so', (
      tester,
    ) async {
      final many = [
        for (var i = 0; i < 6; i++)
          MyCompany(companyId: 'c$i', name: 'Company $i', role: 'PROFESSIONAL', city: i == 3 ? 'Kochi' : 'Pune'),
      ];
      await pumpList(
        tester,
        companies: MyCompanies(personalRole: 'PROFESSIONAL', companies: many),
      );
      await reveal(tester, find.byKey(const Key('companies.search')));
      await tester.enterText(find.byKey(const Key('companies.search')), 'kochi');
      await tester.pumpAndSettle();
      expect(find.text('Company 3'), findsOneWidget);
      expect(find.text('Company 1'), findsNothing);
      await tester.enterText(find.byKey(const Key('companies.search')), 'zzz');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('companies.noMatch')), findsOneWidget);
    });

    testWidgets('View page opens the company through the lead\'s callback', (tester) async {
      final log = <String>[];
      await pumpList(tester, log: log);
      await tapKey(tester, 'company.open.co-techcorp');
      expect(log, ['open:co-techcorp']);
    });
  });

  group('acting for a company or for yourself (a fresh token pair each time)', () {
    testWidgets('Switch acts for the company: the new session is adopted, the app is told, and the row says Active', (
      tester,
    ) async {
      final log = <String>[];
      final repo = await pumpList(tester, log: log);
      final before = await h.tokens.accessToken();
      await tapKey(tester, 'company.switch.co-techcorp');
      expect(repo.calls, contains('switchCompany:co-techcorp'));
      expect(
        await h.tokens.accessToken(),
        isNot(before),
        reason: 'the role rides in the token, so the pair is replaced',
      );
      expect(log, ['session']);
      expect(find.text('Now acting for TechCorp.'), findsOneWidget);
      expect(find.byKey(const Key('company.switch.co-techcorp')), findsNothing, reason: 'it is the active one now');
      await reveal(tester, find.byKey(const Key('company.switch.personal')));
      expect(find.byKey(const Key('company.personal.active')), findsNothing);
    });

    testWidgets('Switch to personal account goes back to acting as yourself', (tester) async {
      final repo = await pumpList(
        tester,
        companies: const MyCompanies(personalRole: 'PROFESSIONAL', companies: [mine]),
      );
      await tapKey(tester, 'company.switch.personal');
      expect(repo.calls, contains('switchCompany:personal'));
      expect(find.text('Now acting as yourself.'), findsOneWidget);
      await reveal(tester, find.byKey(const Key('company.personal.active')));
    });

    testWidgets("a refused switch shows the API's sentence and changes nothing", (tester) async {
      final repo = DemoAccountRepository(
        companies: const MyCompanies(personalRole: 'PROFESSIONAL', companies: [tech]),
      )..failures['switchCompany'] = ApiError('That company is suspended.', statusCode: 403);
      final log = <String>[];
      await pumpList(tester, repo: repo, log: log);
      await tapKey(tester, 'company.switch.co-techcorp');
      await tester.drag(find.byKey(const Key('companies.list')), const Offset(0, 2000));
      await tester.pumpAndSettle();
      expect(find.text('That company is suspended.'), findsOneWidget);
      expect(log, isEmpty);
      await tester.tap(find.byKey(const Key('companies.error.close')));
      await tester.pump();
      expect(find.byKey(const Key('companies.error')), findsNothing);
    });

    testWidgets('while one action runs, no other starts', (tester) async {
      final repo = DemoAccountRepository(
        companies: const MyCompanies(personalRole: 'PROFESSIONAL', companies: [tech, north]),
      );
      await pumpList(tester, repo: repo);
      repo.gate = Future<void>.delayed(const Duration(seconds: 1));
      await tester.ensureVisible(find.byKey(const Key('company.switch.co-techcorp')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('company.switch.co-techcorp')));
      await tester.pump();
      expect(find.text('Switching…'), findsOneWidget);
      await tester.tap(find.byKey(const Key('company.switch.co-north')), warnIfMissed: false);
      await tester.pump();
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(repo.count('switchCompany'), 1);
    });
  });

  group('leaving', () {
    testWidgets(
      'asks first, says what is lost; Cancel leaves nothing; Leave ends the place and adopts the new session',
      (tester) async {
        final log = <String>[];
        final repo = await pumpList(tester, log: log);
        await tapKey(tester, 'company.leave.co-north');
        expect(find.text('Leave Northwind Facilities?'), findsOneWidget);
        expect(find.textContaining('You lose access to Northwind Facilities’s team'), findsOneWidget);
        await tester.tap(find.byKey(const Key('leave.cancel')));
        await tester.pumpAndSettle();
        expect(repo.count('leaveCompany'), 0);

        await tapKey(tester, 'company.leave.co-north');
        await tester.tap(find.byKey(const Key('leave.confirm')));
        await tester.pumpAndSettle();
        expect(repo.calls, contains('leaveCompany:co-north'));
        expect(find.text('Northwind Facilities'), findsNothing);
        expect(find.text('You left Northwind Facilities.'), findsOneWidget);
        expect(log, ['session']);
      },
    );

    testWidgets('the only admin cannot leave: the row says so and has no Leave', (tester) async {
      await pumpList(
        tester,
        companies: const MyCompanies(personalRole: 'PROFESSIONAL', companies: [mine]),
      );
      expect(find.byKey(const Key('company.onlyAdmin.co-mine')), findsOneWidget);
      expect(find.byKey(const Key('company.leave.co-mine')), findsNothing);
    });

    testWidgets("the API's refusal stays in the dialog, beside the button that caused it", (tester) async {
      final repo = DemoAccountRepository(
        companies: const MyCompanies(personalRole: 'PROFESSIONAL', companies: [north]),
      )..failures['leaveCompany'] = ApiError('You still own open requirements here.', statusCode: 400);
      await pumpList(tester, repo: repo);
      await tapKey(tester, 'company.leave.co-north');
      await tester.tap(find.byKey(const Key('leave.confirm')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('leave.error')), findsOneWidget);
      expect(find.text('You still own open requirements here.'), findsOneWidget);
      expect(find.text('Leave Northwind Facilities?'), findsOneWidget, reason: 'the dialog stays open');
    });
  });

  group('requests to join', () {
    const asked = JoinRequest(
      companyId: 'co-global',
      name: 'Global Infra Solutions',
      role: 'PROFESSIONAL',
      note: 'I work with them on the Pune campus.',
    );

    testWidgets('a waiting request shows who, as what and the note; Withdraw takes it back', (tester) async {
      final repo = await pumpList(
        tester,
        companies: const MyCompanies(personalRole: 'PROFESSIONAL', companies: [tech], requests: [asked]),
      );
      expect(find.text('Awaiting Approval'), findsOneWidget);
      expect(find.text('Global Infra Solutions'), findsOneWidget);
      expect(find.text('Requested as Professional'), findsOneWidget);
      expect(find.text('“I work with them on the Pune campus.”'), findsOneWidget);
      await tapKey(tester, 'request.withdraw.co-global');
      expect(repo.calls, contains('withdrawRequest:co-global'));
      expect(find.byKey(const Key('companies.requests')), findsNothing);
      expect(find.text('Request to join Global Infra Solutions withdrawn.'), findsOneWidget);
    });

    testWidgets('a request already decided is the API sentence, and the list is read again', (tester) async {
      final repo = DemoAccountRepository(
        companies: const MyCompanies(personalRole: 'PROFESSIONAL', requests: [asked]),
      )..failures['withdrawRequest'] = ApiError('That request is no longer waiting.', statusCode: 404);
      await pumpList(tester, repo: repo);
      await tapKey(tester, 'request.withdraw.co-global');
      await tester.drag(find.byKey(const Key('companies.list')), const Offset(0, 2000));
      await tester.pumpAndSettle();
      expect(find.text('That request is no longer waiting.'), findsOneWidget);
    });

    testWidgets(
      'Ask to join: find the company, say why, send; it shows under Awaiting approval and the note goes with it',
      (tester) async {
        final repo = await pumpList(tester, companies: const MyCompanies(personalRole: 'PROFESSIONAL'));
        await tapKey(tester, 'companies.join');
        expect(find.text('Ask to Join a Company'), findsWidgets);
        await tester.enterText(find.byKey(const Key('join.search')), 'Global');
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('join.hit.co-global')));
        await tester.pumpAndSettle();
        expect(find.text('Ask to Join Global Infra Solutions'), findsOneWidget);
        await tester.enterText(find.byKey(const Key('join.note')), 'I am their site lead.');
        await tester.pump();
        await tester.tap(find.byKey(const Key('sheet.save')));
        await tester.pumpAndSettle();
        expect(repo.sent['requestToJoin'], {'companyId': 'co-global', 'note': 'I am their site lead.'});
        expect(find.text('Request sent to Global Infra Solutions.'), findsOneWidget);
        expect(find.text('Awaiting Approval'), findsOneWidget);
      },
    );
  });

  group('invitations: places an admin added you to', () {
    final now = DateTime.now().toUtc();
    final added = CompanyInvitation(
      companyId: 'co-global',
      name: 'Global Infra Solutions',
      role: 'RECRUITER',
      branchName: 'Pune campus',
      invitedBy: 'Asha Rao',
      invitedAt: now.subtract(const Duration(days: 2)).toIso8601String(),
    );
    final addedAlone = CompanyInvitation(
      companyId: 'co-alone',
      name: 'Alone Estates',
      role: 'BUYER',
      invitedAt: now.subtract(const Duration(hours: 5)).toIso8601String(),
    );
    MyCompanies waiting({List<MyCompany> companies = const [], List<CompanyInvitation>? invitations}) => MyCompanies(
      personalRole: 'PROFESSIONAL',
      companies: companies,
      invitations: invitations ?? [added, addedAlone],
    );

    testWidgets('"Waiting for You" lists each one: who added you, as what, how long ago, in which office', (
      tester,
    ) async {
      await pumpList(tester, companies: waiting(companies: const [tech]));
      expect(find.text('Waiting for You'), findsOneWidget);
      expect(find.text('(2)'), findsOneWidget);
      expect(
        find.text('An admin added you to their team. You join only when you accept, and you can decline.'),
        findsOneWidget,
      );
      expect(find.text('Global Infra Solutions'), findsOneWidget);
      expect(find.byKey(const Key('invitation.added.co-global')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('invitation.added.co-global'))).data,
        'Added as Recruiter by Asha Rao · 2d ago · Pune campus',
      );
      expect(tester.widget<Text>(find.byKey(const Key('invitation.added.co-alone'))).data, 'Added as Buyer · 5h ago');
      expect(find.byKey(const Key('invitation.accept.co-global')), findsOneWidget);
      expect(find.byKey(const Key('invitation.decline.co-global')), findsOneWidget);
    });

    testWidgets('no invitations, no card', (tester) async {
      await pumpList(tester, companies: waiting(invitations: const []));
      expect(find.byKey(const Key('companies.invitations')), findsNothing);
      expect(find.text('Waiting for You'), findsNothing);
    });

    testWidgets(
      'Accept joins: the fresh session is adopted, the app is told, and the company is listed (Active when none was)',
      (tester) async {
        final log = <String>[];
        final repo = await pumpList(tester, companies: waiting(), log: log);
        final before = await h.tokens.accessToken();
        await tapKey(tester, 'invitation.accept.co-global');
        expect(repo.calls, contains('acceptInvitation:co-global'));
        expect(
          await h.tokens.accessToken(),
          isNot(before),
          reason: 'the role rides in the token, so the pair is replaced',
        );
        expect(log, ['session']);
        expect(find.text('You joined Global Infra Solutions.'), findsOneWidget);
        expect(find.byKey(const Key('invitation.row.co-global')), findsNothing);
        expect(find.byKey(const Key('invitation.row.co-alone')), findsOneWidget, reason: 'the other one still waits');
        expect(find.text('(1)'), findsOneWidget);
        await reveal(tester, find.byKey(const Key('company.row.co-global')));
        expect(find.byKey(const Key('company.role.co-global')), findsOneWidget);
        expect(
          find.descendant(of: find.byKey(const Key('company.row.co-global')), matching: find.text('Active')),
          findsOneWidget,
          reason: 'they had no company in use, so this one becomes the one they act for',
        );
      },
    );

    testWidgets('Accept while acting for another company leaves that one active', (tester) async {
      const acting = MyCompany(
        companyId: 'co-mine',
        name: 'My Own Co',
        role: 'COMPANY_ADMIN',
        active: true,
        soleAdmin: true,
      );
      await pumpList(
        tester,
        companies: waiting(companies: const [acting], invitations: [added]),
      );
      await tapKey(tester, 'invitation.accept.co-global');
      await reveal(tester, find.byKey(const Key('company.row.co-global')));
      expect(
        find.descendant(of: find.byKey(const Key('company.row.co-global')), matching: find.text('Active')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('company.switch.co-global')),
        findsOneWidget,
        reason: 'they can switch to it when they like',
      );
      expect(find.byKey(const Key('companies.invitations')), findsNothing, reason: 'nothing left to answer');
    });

    testWidgets('Decline turns it down: no session, the card shrinks, a line says so', (tester) async {
      final log = <String>[];
      final repo = await pumpList(tester, companies: waiting(), log: log);
      await tapKey(tester, 'invitation.decline.co-alone');
      expect(repo.calls, contains('declineInvitation:co-alone'));
      expect(repo.count('acceptInvitation'), 0);
      expect(log, isEmpty, reason: 'declining changes nothing about the session');
      expect(find.text('You declined the invitation from Alone Estates.'), findsOneWidget);
      expect(find.byKey(const Key('invitation.row.co-alone')), findsNothing);
      await tester.drag(find.byKey(const Key('companies.list')), const Offset(0, 2000));
      await tester.pumpAndSettle();
      expect(find.text('(1)'), findsOneWidget);
      expect(find.byKey(const Key('invitation.row.co-global')), findsOneWidget);
    });

    testWidgets("a refusal (a full team) shows the API's sentence above the list and the invitation stays", (
      tester,
    ) async {
      final repo = DemoAccountRepository(companies: waiting(invitations: [added]))
        ..failures['acceptInvitation'] = ApiError(
          "Global Infra Solutions's team is full: its plan includes 5 team members.",
          statusCode: 400,
        );
      final log = <String>[];
      await pumpList(tester, repo: repo, log: log);
      await tapKey(tester, 'invitation.accept.co-global');
      await tester.drag(find.byKey(const Key('companies.list')), const Offset(0, 2000));
      await tester.pumpAndSettle();
      expect(find.text("Global Infra Solutions's team is full: its plan includes 5 team members."), findsOneWidget);
      expect(find.byKey(const Key('invitation.row.co-global')), findsOneWidget);
      expect(log, isEmpty);
    });

    testWidgets('while one is being answered both buttons wait and the one pressed says what it is doing', (
      tester,
    ) async {
      final repo = DemoAccountRepository(companies: waiting());
      await pumpList(tester, repo: repo);
      repo.gate = Future<void>.delayed(const Duration(seconds: 1));
      await tester.ensureVisible(find.byKey(const Key('invitation.accept.co-global')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('invitation.accept.co-global')));
      await tester.pump();
      expect(find.text('Joining…'), findsOneWidget);
      await tester.tap(find.byKey(const Key('invitation.decline.co-alone')), warnIfMissed: false);
      await tester.tap(find.byKey(const Key('invitation.accept.co-alone')), warnIfMissed: false);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(repo.count('acceptInvitation'), 1);
      expect(repo.count('declineInvitation'), 0);
    });

    BoxDecoration cardDecoration(WidgetTester tester) =>
        tester
                .widget<AnimatedContainer>(
                  find.ancestor(
                    of: find.byKey(const Key('companies.invitations')),
                    matching: find.byType(AnimatedContainer),
                  ),
                )
                .decoration!
            as BoxDecoration;

    testWidgets('?focus=invitations washes the card in blue for a moment and brings it into view', (tester) async {
      // Enough companies above the foot to push the card's neighbours around; the card itself stays reachable.
      await pumpList(tester, companies: waiting(companies: const [tech, north]), focusInvitations: true);
      expect(cardDecoration(tester).color, const Color(0xFFE3EEFB), reason: 'focused: washed in blue');
      final top = tester.getTopLeft(find.byKey(const Key('companies.invitations'))).dy;
      expect(top, lessThan(844), reason: 'on screen');
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(cardDecoration(tester).color, Colors.white, reason: 'the wash fades once it has been seen');
    });

    testWidgets('without the focus the card is plain white', (tester) async {
      await pumpList(tester, companies: waiting());
      expect(cardDecoration(tester).color, Colors.white);
    });

    testWidgets('focus with nothing waiting does nothing and does not fail', (tester) async {
      await pumpList(tester, companies: waiting(invitations: const []), focusInvitations: true);
      expect(find.byKey(const Key('companies.invitations')), findsNothing);
      expect(find.text('My Companies'), findsOneWidget);
    });

    testWidgets('the API repository posts to the invitation and reads the list it answers with', (tester) async {
      final harness = AccountHarness(
        routes: {
          'POST /me/companies/invitations/co-global/accept': (_) => sessionJson(
            user: userJson(role: 'RECRUITER', companyId: 'co-global'),
          ),
          'POST /me/companies/invitations/co-alone/decline': (_) => {
            'personalRole': 'PROFESSIONAL',
            'canJoinCompanies': true,
            'companies': <Object>[],
            'requests': <Object>[],
            'invitations': [
              {
                'companyId': 'co-global',
                'name': 'Global Infra Solutions',
                'logoUrl': null,
                'role': 'RECRUITER',
                'branchName': null,
                'learningRoles': ['TRAINER'],
                'invitedBy': 'Asha Rao',
                'invitedAt': '2026-11-03T08:00:00.000Z',
              },
            ],
          },
        },
      );
      final repo = ApiAccountRepository(api: harness.client);
      final tokens = await tester.runAsync(() => repo.acceptInvitation('co-global'));
      expect(tokens!.accessToken, 'a1');
      expect(tokens.user!['companyId'], 'co-global');
      expect(harness.api.count('POST /me/companies/invitations/co-global/accept'), 1);
      final left = await tester.runAsync(() => repo.declineInvitation('co-alone'));
      expect(left!.invitations.single.companyId, 'co-global');
      expect(left.invitations.single.invitedBy, 'Asha Rao');
      expect(left.invitations.single.learningRoles, ['TRAINER']);
      expect(harness.api.count('POST /me/companies/invitations/co-alone/decline'), 1);
    });
  });

  group('the ask-to-join sheet on its own', () {
    Future<List<String>> pumpSheet(
      WidgetTester tester, {
      Future<List<CompanyHit>> Function(String)? search,
      Future<String?> Function(String, String?)? send,
      Set<String> member = const {},
      Set<String> requested = const {},
      CompanyHit? initial,
    }) async {
      final results = <String>[];
      usePhone(tester);
      await tester.pumpWidget(
        h.app(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('open'),
                  onPressed: () async {
                    final hit = await showAskToJoinSheet(
                      context,
                      search:
                          search ??
                          (q) async => [
                            const CompanyHit(id: 'a', name: 'Alpha Estates', city: 'Pune'),
                            const CompanyHit(id: 'b', name: 'Alpha Labs'),
                          ],
                      send: send ?? (id, note) async => null,
                      memberOf: member,
                      requested: requested,
                      initial: initial,
                      searchDelay: Duration.zero,
                    );
                    results.add(hit?.id ?? 'none');
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      return results;
    }

    testWidgets('one letter searches nothing; two do; no hit offers to create the company instead', (tester) async {
      h = AccountHarness();
      var asked = 0;
      await pumpSheet(
        tester,
        search: (q) async {
          asked++;
          return const [];
        },
      );
      await tester.enterText(find.byKey(const Key('join.search')), 'A');
      await tester.pumpAndSettle();
      expect(asked, 0);
      await tester.enterText(find.byKey(const Key('join.search')), 'Zeta');
      await tester.pumpAndSettle();
      expect(asked, 1);
      expect(find.text('No company called “Zeta” is on ICR yet. You can create it instead.'), findsOneWidget);
    });

    testWidgets('a company the person belongs to, or has asked, is shown but cannot be chosen', (tester) async {
      h = AccountHarness();
      await pumpSheet(tester, member: const {'a'}, requested: const {'b'});
      await tester.enterText(find.byKey(const Key('join.search')), 'Alpha');
      await tester.pumpAndSettle();
      expect(find.text('Member'), findsOneWidget);
      expect(find.text('Request Sent'), findsOneWidget);
      await tester.tap(find.byKey(const Key('join.hit.a')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('join.note')), findsNothing, reason: 'it stayed on the search step');
    });

    testWidgets('a refused request shows the sentence and keeps the note; a failed search says so', (tester) async {
      h = AccountHarness();
      final results = await pumpSheet(
        tester,
        initial: const CompanyHit(id: 'a', name: 'Alpha Estates'),
        send: (id, note) async => 'You already asked to join this company.',
      );
      await tester.enterText(find.byKey(const Key('join.note')), 'Hello there');
      await tester.pump();
      await tester.tap(find.byKey(const Key('sheet.save')));
      await tester.pumpAndSettle();
      expect(find.text('You already asked to join this company.'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('join.note'))).controller!.text, 'Hello there');
      expect(results, isEmpty);
    });

    testWidgets('a search that fails shows its sentence', (tester) async {
      h = AccountHarness();
      await pumpSheet(tester, search: (q) async => throw ApiError('Search is down.', statusCode: 500));
      await tester.enterText(find.byKey(const Key('join.search')), 'Alpha');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('join.searchError')), findsOneWidget);
      expect(find.text('Search is down.'), findsOneWidget);
    });
  });

  group('create a company page', () {
    Future<DemoAccountRepository> pumpCreate(
      WidgetTester tester, {
      DemoAccountRepository? repo,
      List<String>? log,
      Future<PickedPhoto?> Function()? pickPhoto,
      Future<PickedPhoto?> Function()? pickDocument,
      Future<List<CityOption>> Function(String query)? placeSearch,
    }) async {
      final r = repo ?? DemoAccountRepository();
      h = AccountHarness();
      await h.signIn(tester);
      usePhone(tester);
      await tester.pumpWidget(
        h.app(
          CreateCompanyScreen(
            repository: r,
            onSessionChanged: () => log?.add('session'),
            onCreated: (c) => log?.add('created:${c.name}'),
            onNextStep: (step, c) => log?.add('${step.name}:${c.name}'),
            onViewCompany: (id) => log?.add('view:$id'),
            pickPhoto: pickPhoto,
            pickDocument: pickDocument,
            placeSearch: placeSearch,
            searchDelay: Duration.zero,
          ),
        ),
      );
      await tester.pumpAndSettle();
      return r;
    }

    Future<void> type(WidgetTester tester, String key, String text) async {
      final field = find.byKey(Key(key));
      await reveal(tester, field);
      await tester.enterText(field, text);
      await tester.pump();
    }

    Future<void> pick(WidgetTester tester, String key, String label) async {
      await tapKey(tester, key);
      if (find.byKey(const Key('accountPicker.search')).evaluate().isNotEmpty) {
        await tester.enterText(find.byKey(const Key('accountPicker.search')), label);
        await tester.pumpAndSettle();
      }
      final item = find.widgetWithText(ListTile, label);
      await tester.scrollUntilVisible(item, 100, scrollable: find.byType(Scrollable).last);
      await tester.tap(item);
      await tester.pumpAndSettle();
    }

    Future<void> fillAll(WidgetTester tester) async {
      await type(tester, 'create.name', 'Acme Facility Services');
      await pick(tester, 'create.industry', 'Facility management services');
      await pick(tester, 'create.city', 'Pune, Maharashtra');
      await tapKey(tester, 'create.size.11-50');
      await pick(tester, 'create.structure', 'Private limited');
      await tapKey(tester, 'create.authorised');
    }

    testWidgets('Create sends exactly what was chosen, adopts the new session and turns into the welcome page', (
      tester,
    ) async {
      final log = <String>[];
      final repo = await pumpCreate(tester, log: log);
      final before = await h.tokens.accessToken();
      await fillAll(tester);
      await type(tester, 'create.website', 'acme.com');
      await type(tester, 'create.description', 'Integrated facility services.');
      await tapKey(tester, 'create.submit');

      expect(repo.sent['createCompany'], {
        'name': 'Acme Facility Services',
        'website': 'acme.com',
        'industry': 'FM_SERVICES',
        'size': '11-50',
        'legalStructure': 'PRIVATE_LIMITED',
        'city': 'Pune',
        'state': 'Maharashtra',
        'description': 'Integrated facility services.',
      });
      expect(await h.tokens.accessToken(), isNot(before));
      expect(log, ['session', 'created:Acme Facility Services']);
      expect(find.byKey(const Key('create.welcome')), findsOneWidget);
      expect(find.text('Welcome to ICR, Acme Facility Services!'), findsOneWidget);
    });

    testWidgets('the welcome steps go where the lead sends them; Done leaves', (tester) async {
      final log = <String>[];
      await pumpCreate(tester, log: log);
      await fillAll(tester);
      await tapKey(tester, 'create.submit');
      log.clear();
      for (final step in ['team', 'verify', 'sell', 'details']) {
        await tapKey(tester, 'welcome.go.$step');
      }
      expect(log, [
        'team:Acme Facility Services',
        'verify:Acme Facility Services',
        'sell:Acme Facility Services',
        'details:Acme Facility Services',
      ]);
      await tapKey(tester, 'create.done');
    });

    testWidgets(
      'an empty form is refused with every missing detail named, and a tap takes you to it; nothing is sent',
      (tester) async {
        final repo = await pumpCreate(tester);
        await tapKey(tester, 'create.submit');
        expect(repo.count('createCompany'), 0);
        expect(find.text('6 details need attention'), findsOneWidget);
        expect(find.text('Enter the company name.'), findsOneWidget);
        expect(find.text('Select the industry it works in.'), findsOneWidget);
        expect(find.text('Select where the head office is.'), findsOneWidget);
        expect(find.text('Select how many people work there.'), findsOneWidget);
        expect(find.text('Select how the organisation is set up.'), findsOneWidget);
        expect(find.text('Confirm that you may create this page for the company.'), findsOneWidget);
        await tester.tap(find.byKey(const Key('create.summary.industry')));
        await tester.pumpAndSettle();
        // Fixing one removes its message at once.
        await pick(tester, 'create.industry', 'Facility management services');
        expect(find.text('Select the industry it works in.'), findsNothing);
        expect(find.text('5 details need attention'), findsOneWidget);
      },
    );

    testWidgets(
      'a different legal name is asked only when ticked, and a bad website is refused in the website\'s words',
      (tester) async {
        await pumpCreate(tester);
        expect(find.byKey(const Key('create.legalName')), findsNothing);
        await tapKey(tester, 'create.legalDiffers');
        expect(find.byKey(const Key('create.legalName')), findsOneWidget);
        await type(tester, 'create.legalName', '1');
        await type(tester, 'create.website', 'not a site');
        await tapKey(tester, 'create.submit');
        expect(find.text('Enter the registered legal name. It needs at least one letter.'), findsOneWidget);
        expect(find.text('Enter a website like acme.com or https://acme.com'), findsOneWidget);
      },
    );

    testWidgets('Year Founded is optional; a year outside 1800 to this year is refused, a good one is sent', (
      tester,
    ) async {
      final repo = await pumpCreate(tester);
      await fillAll(tester);
      await type(tester, 'create.foundedYear', '1799');
      await tapKey(tester, 'create.submit');
      final latest = DateTime.now().year;
      expect(find.text('Enter a year between 1800 and $latest.'), findsOneWidget);
      expect(find.text('1 detail needs attention'), findsOneWidget);
      expect(repo.count('createCompany'), 0);

      await type(tester, 'create.foundedYear', '${latest + 1}');
      await tapKey(tester, 'create.submit');
      expect(find.text('Enter a year between 1800 and $latest.'), findsOneWidget, reason: 'not a year to come');
      expect(repo.count('createCompany'), 0);

      await type(tester, 'create.foundedYear', '2014');
      await tapKey(tester, 'create.submit');
      expect((repo.sent['createCompany']! as Map)['foundedYear'], 2014);
    });

    testWidgets('the owner\'s wording (12 Nov 2026): the tips, the intro and the footer are gone', (tester) async {
      await pumpCreate(tester);
      expect(find.text('Company Details'), findsWidgets);
      expect(find.text('Company identity'), findsNothing);
      expect(find.text('How members find and recognise it.'), findsNothing);
      expect(find.text('Company Brand Name / Legal Name'), findsOneWidget);
      expect(find.textContaining('You become the page’s admin'), findsNothing);
      expect(find.text('Buyers and candidates read this first.'), findsNothing);
      expect(
        find.text(
          'I agree to the terms and policies of ICR and I am an authorised representative of this company to create '
          'and manage this page on ICR.',
        ),
        findsOneWidget,
      );
    });

    testWidgets("the API's refusal shows above the buttons and every answer stays", (tester) async {
      final repo = DemoAccountRepository()
        ..failures['createCompany'] = ApiError('That industry is no longer offered.', statusCode: 400);
      await pumpCreate(tester, repo: repo);
      await fillAll(tester);
      await tapKey(tester, 'create.submit');
      expect(find.byKey(const Key('create.error')), findsOneWidget);
      expect(find.text('That industry is no longer offered.'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('create.name'))).controller!.text, 'Acme Facility Services');
      expect(find.byKey(const Key('create.welcome')), findsNothing);
    });

    testWidgets(
      'companies that look alike are offered: Ask to join sends the request and marks it sent; View page calls out',
      (tester) async {
        final log = <String>[];
        final repo = await pumpCreate(tester, log: log);
        await type(tester, 'create.name', 'TechCorp');
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pumpAndSettle();
        await reveal(tester, find.byKey(const Key('create.lookalikes')));
        expect(find.text('Is your company already on ICR?'), findsOneWidget);
        await tester.tap(find.byKey(const Key('lookalike.ask.co-techcorp')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('sheet.save')));
        await tester.pumpAndSettle();
        expect(repo.sent['requestToJoin'], {'companyId': 'co-techcorp'});
        expect(find.byKey(const Key('lookalike.sent.co-techcorp')), findsOneWidget);
        // A suggestion never blocks creating the page.
        expect(find.byKey(const Key('create.submit')), findsOneWidget);
      },
    );

    testWidgets(
      'a logo is uploaded with its preview; one over 2 MB or of another type is refused before upload; Remove takes it off',
      (tester) async {
        final repo = await pumpCreate(
          tester,
          pickPhoto: () async => PickedPhoto(bytes: List.filled(64, 1), name: 'logo.png'),
        );
        await tapKey(tester, 'create.logo.add');
        expect(repo.calls, contains('upload:company'));
        expect(
          find.text('Logo uploaded. It appears on your company page, job posts and supplier card.'),
          findsOneWidget,
        );
        await tapKey(tester, 'create.logo.remove');
        expect(find.byKey(const Key('create.logo.add')), findsOneWidget);

        final big = await pumpCreate(
          tester,
          pickPhoto: () async => PickedPhoto(bytes: List.filled(2 * 1024 * 1024 + 1, 1), name: 'big.png'),
        );
        await tapKey(tester, 'create.logo.add');
        expect(find.text('That image is over 2MB. Compress it or choose a smaller one.'), findsOneWidget);
        expect(big.count('upload'), 0);

        await pumpCreate(
          tester,
          pickPhoto: () async => PickedPhoto(bytes: List.filled(64, 1), name: 'logo.gif', mimeType: 'image/gif'),
        );
        await tapKey(tester, 'create.logo.add');
        expect(find.text('GIF files are not accepted. Use PNG, JPG or WEBP.'), findsOneWidget);

        await pumpCreate(
          tester,
          pickPhoto: () async => PickedPhoto(bytes: List.filled(64, 1), name: 'brochure.pdf'),
        );
        await tapKey(tester, 'create.logo.add');
        expect(find.text('That is not an image. Choose a PNG, JPG or WEBP file.'), findsOneWidget);
      },
    );

    testWidgets('the logo is offered whatever the lead hands in: the phone\'s own picture chooser stands behind it', (
      tester,
    ) async {
      await pumpCreate(tester);
      expect(find.byKey(const Key('create.logo.add')), findsOneWidget);
      expect(find.text('PNG, JPG or WEBP, up to 2MB.'), findsOneWidget);
    });

    testWidgets('a failed logo upload says why in the API\'s words, else the website\'s', (tester) async {
      final repo = DemoAccountRepository()
        ..failures['upload:company'] = ApiError('That image is corrupt.', statusCode: 400);
      await pumpCreate(
        tester,
        repo: repo,
        pickPhoto: () async => PickedPhoto(bytes: List.filled(64, 1), name: 'logo.png'),
      );
      await tapKey(tester, 'create.logo.add');
      expect(find.text('That image is corrupt.'), findsOneWidget);
      repo.failures['upload:company'] = ApiError('Something went wrong (500). Try again.', statusCode: 500);
      await tapKey(tester, 'create.logo.add');
      expect(find.text('Upload failed. Try again.'), findsOneWidget);
    });

    testWidgets('an ICR staff account is told it is personal and gets no form; the API would refuse it anyway', (
      tester,
    ) async {
      final repo = DemoAccountRepository(
        companies: const MyCompanies(personalRole: 'SUPER_ADMIN', canJoinCompanies: false),
      );
      await pumpCreate(tester, repo: repo);
      expect(find.byKey(const Key('create.staff')), findsOneWidget);
      expect(find.text('Staff Accounts Don’t Create Companies'), findsOneWidget);
      expect(find.text('ICR staff accounts are personal: they do not create or join companies.'), findsOneWidget);
      expect(find.byKey(const Key('create.form')), findsNothing);
      expect(find.byKey(const Key('create.submit')), findsNothing);
    });

    testWidgets('a member already acting for a company may found another: the new one becomes the active one', (
      tester,
    ) async {
      final repo = DemoAccountRepository(
        companies: const MyCompanies(personalRole: 'PROFESSIONAL', companies: [mine]),
      );
      await pumpCreate(tester, repo: repo);
      expect(find.byKey(const Key('create.staff')), findsNothing);
      await fillAll(tester);
      await tapKey(tester, 'create.submit');
      expect(find.byKey(const Key('create.welcome')), findsOneWidget);
      final now = repo.companiesNow.companies;
      expect(now.map((c) => c.name), ['My Own Co', 'Acme Facility Services']);
      expect(now.where((c) => c.active).map((c) => c.name), ['Acme Facility Services']);
    });

    testWidgets('a company the person has already asked to join shows Request sent, not another Ask to join', (
      tester,
    ) async {
      final repo = DemoAccountRepository(
        companies: const MyCompanies(
          personalRole: 'PROFESSIONAL',
          requests: [JoinRequest(companyId: 'co-techcorp', name: 'TechCorp', role: 'PROFESSIONAL')],
        ),
      );
      await pumpCreate(tester, repo: repo);
      await type(tester, 'create.name', 'TechCorp');
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const Key('create.lookalikes')));
      expect(find.byKey(const Key('lookalike.sent.co-techcorp')), findsOneWidget);
      expect(find.byKey(const Key('lookalike.ask.co-techcorp')), findsNothing);
    });

    testWidgets(
      'the documents the organisation type files open under it, all optional; an upload is private and goes with the page',
      (tester) async {
        final repo = await pumpCreate(
          tester,
          pickDocument: () async => PickedPhoto(bytes: List.filled(64, 1), name: 'coi.pdf'),
        );
        expect(find.byKey(const Key('create.docs')), findsNothing, reason: 'nothing until a type is chosen');
        await fillAll(tester);
        expect(find.text('Documents for a Private Limited Company'), findsOneWidget);
        expect(find.textContaining('Optional now.'), findsOneWidget);
        expect(find.textContaining('Certificate of Incorporation', findRichText: true), findsOneWidget);
        expect(find.textContaining('PAN Card', findRichText: true), findsOneWidget);
        expect(find.textContaining('GST Certificate', findRichText: true), findsOneWidget);
        expect(find.text('Only if the business is registered for GST.'), findsOneWidget);
        expect(
          find.text('Kept private, never shown on the company page. PDF, JPG, PNG or WebP, up to 10 MB each.'),
          findsOneWidget,
        );

        await tapKey(tester, 'create.doc.incorporationDoc.upload');
        expect(repo.calls, contains('upload:employer-kyc'));
        expect(find.text('coi.pdf'), findsOneWidget);
        expect(find.text('1 of 3 added'), findsOneWidget);
        await tapKey(tester, 'create.submit');
        final sent = repo.sent['createCompany']! as Map<String, dynamic>;
        expect(sent['incorporationDocUrl'], startsWith('/uploads/'));
        expect(sent['incorporationDocName'], 'coi.pdf');
        expect(sent.containsKey('panDocUrl'), isFalse);
        expect(sent.containsKey('gstDocUrl'), isFalse);
      },
    );

    testWidgets(
      'a type with no registration certificate says so; the certificate is dropped when the type changes; Remove takes a file off',
      (tester) async {
        final repo = await pumpCreate(
          tester,
          pickDocument: () async => PickedPhoto(bytes: List.filled(64, 1), name: 'doc.pdf'),
        );
        await fillAll(tester);
        await tapKey(tester, 'create.doc.incorporationDoc.upload');
        await tapKey(tester, 'create.doc.panDoc.upload');
        expect(find.text('2 of 3 added'), findsOneWidget);
        await tapKey(tester, 'create.doc.panDoc.remove');
        expect(find.byKey(const Key('create.doc.panDoc.upload')), findsOneWidget);
        expect(find.text('1 of 3 added'), findsOneWidget);

        await pick(tester, 'create.structure', 'Sole proprietorship');
        expect(find.text('Documents for a Sole Proprietorship'), findsOneWidget);
        expect(find.byKey(const Key('create.doc.incorporationDoc')), findsNothing);
        expect(find.text('A sole proprietorship has no registration certificate, so none is asked.'), findsOneWidget);
        expect(find.text('The proprietor’s own PAN card.'), findsOneWidget);
        await tapKey(tester, 'create.submit');
        final sent = repo.sent['createCompany']! as Map<String, dynamic>;
        expect(sent['legalStructure'], 'SOLE_PROPRIETORSHIP');
        expect(
          sent.containsKey('incorporationDocUrl'),
          isFalse,
          reason: 'a certificate uploaded under another type is not sent',
        );
        expect(sent.containsKey('incorporationDocName'), isFalse);
      },
    );

    testWidgets('a document over 10 MB or of another kind is refused before upload; a refused upload says why', (
      tester,
    ) async {
      final repo = DemoAccountRepository();
      var bytes = 10 * 1024 * 1024 + 1;
      var name = 'huge.pdf';
      String? mime;
      await pumpCreate(
        tester,
        repo: repo,
        pickDocument: () async => PickedPhoto(bytes: List.filled(bytes, 1), name: name, mimeType: mime),
      );
      await pick(tester, 'create.structure', 'Private limited');
      await tapKey(tester, 'create.doc.panDoc.upload');
      expect(find.text('Upload failed. Use a PDF or image under 10 MB.'), findsOneWidget);
      expect(repo.count('upload'), 0);

      bytes = 64;
      name = 'movie.mp4';
      mime = 'video/mp4';
      await tapKey(tester, 'create.doc.panDoc.upload');
      expect(find.text('Upload failed. Use a PDF or image under 10 MB.'), findsOneWidget);
      expect(repo.count('upload'), 0, reason: 'a video is no PDF or picture');

      name = 'pan.pdf';
      mime = null;
      repo.failures['upload:employer-kyc'] = ApiError('That file type is not allowed.', statusCode: 400);
      await tapKey(tester, 'create.doc.panDoc.upload');
      expect(find.text('That file type is not allowed.'), findsOneWidget);
      expect(
        find.byKey(const Key('create.doc.panDoc.upload')),
        findsOneWidget,
        reason: 'the row stays ready for another try',
      );

      repo.failures.clear();
      await tapKey(tester, 'create.doc.panDoc.upload');
      expect(find.text('That file type is not allowed.'), findsNothing, reason: 'a new try clears the old line');
      expect(find.text('pan.pdf'), findsOneWidget);
    });

    testWidgets('a head office beyond ICR\'s cities is found by typing; its name goes as picked, with no state', (
      tester,
    ) async {
      final asked = <String>[];
      final repo = await pumpCreate(
        tester,
        placeSearch: (q) async {
          asked.add(q);
          return q.startsWith('Dub')
              ? const [CityOption(id: 'place:dubai', name: 'Dubai, United Arab Emirates')]
              : const [];
        },
      );
      await type(tester, 'create.name', 'Gulf Facilities');
      await pick(tester, 'create.industry', 'Facility management services');
      await tapKey(tester, 'create.city');
      await tester.enterText(find.byKey(const Key('accountPicker.search')), 'D');
      await tester.pumpAndSettle();
      expect(asked, isEmpty, reason: 'one letter searches nothing');
      await tester.enterText(find.byKey(const Key('accountPicker.search')), 'Zzz');
      await tester.pumpAndSettle();
      expect(find.text('No city found with that name.'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('accountPicker.search')), 'Dub');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Dubai, United Arab Emirates'));
      await tester.pumpAndSettle();
      expect(asked, ['Zzz', 'Dub']);
      await tapKey(tester, 'create.size.11-50');
      await pick(tester, 'create.structure', 'Private limited');
      await tapKey(tester, 'create.authorised');
      await tapKey(tester, 'create.submit');
      final sent = repo.sent['createCompany']! as Map<String, dynamic>;
      expect(sent['city'], 'Dubai, United Arab Emirates');
      expect(sent.containsKey('state'), isFalse);
    });

    testWidgets('a refused Create says what the API said, else the website\'s line; a busy hour has its own', (
      tester,
    ) async {
      final repo = DemoAccountRepository();
      await pumpCreate(tester, repo: repo);
      await fillAll(tester);
      repo.failures['createCompany'] = ApiError('Something went wrong (500). Try again.', statusCode: 500);
      await tapKey(tester, 'create.submit');
      expect(find.text('Unable to create the company page.'), findsOneWidget);

      repo.failures['createCompany'] = ApiError("Can't reach ICR right now. Check your connection and try again.");
      await tapKey(tester, 'create.submit');
      expect(find.text('Unable to create the company page.'), findsOneWidget);

      repo.failures['createCompany'] = ApiError(
        'ICR staff accounts cannot create or join a company. Use a separate account.',
        statusCode: 403,
      );
      await tapKey(tester, 'create.submit');
      expect(find.text('ICR staff accounts cannot create or join a company. Use a separate account.'), findsOneWidget);

      repo.failures['createCompany'] = ApiError(
        'name must be longer than or equal to 2 characters\nwebsite must be a URL address',
        statusCode: 400,
      );
      await tapKey(tester, 'create.submit');
      expect(
        find.text('name must be longer than or equal to 2 characters website must be a URL address'),
        findsOneWidget,
      );

      repo.failures['createCompany'] = ApiError('Too many requests. Wait a minute and try again.', statusCode: 429);
      await tapKey(tester, 'create.submit');
      expect(find.text('You have created several companies in the last hour. Try again later.'), findsOneWidget);
      expect(find.byKey(const Key('create.welcome')), findsNothing, reason: 'every answer stays');
    });

    testWidgets(
      'a website is judged by the website\'s rule on Create; blank is fine; the fixed field drops its message',
      (tester) async {
        final repo = await pumpCreate(tester);
        await fillAll(tester);
        await type(tester, 'create.website', 'acme-.com');
        await tapKey(tester, 'create.submit');
        expect(find.text('Enter a website like acme.com or https://acme.com'), findsOneWidget);
        expect(find.text('1 detail needs attention'), findsOneWidget);
        expect(repo.count('createCompany'), 0);
        await type(tester, 'create.website', 'https://www.acme.co.in/about');
        expect(find.text('Enter a website like acme.com or https://acme.com'), findsNothing);
        await tapKey(tester, 'create.submit');
        expect((repo.sent['createCompany']! as Map<String, dynamic>)['website'], 'https://www.acme.co.in/about');
      },
    );

    testWidgets('Back with something typed asks to discard; without, it just leaves', (tester) async {
      await pumpCreate(tester);
      await tapKey(tester, 'create.cancel');
      expect(find.text('Create a Company Page'), findsNothing, reason: 'nothing typed: it left');
    });

    testWidgets('Cancel after typing asks first', (tester) async {
      await pumpCreate(tester);
      await type(tester, 'create.name', 'Half done Ltd');
      await tapKey(tester, 'create.cancel');
      expect(find.text('Discard This Company Page?'), findsOneWidget);
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      expect(find.text('Create a Company Page'), findsWidgets);
      expect(tester.widget<TextField>(find.byKey(const Key('create.name'))).controller!.text, 'Half done Ltd');
    });
  });

  group('the create page against the API', () {
    test('the website field follows the website\'s own rule, case by case', () {
      const accepted = [
        'acme.com',
        'www.acme.co.in',
        'https://acme.com/path?x=1#y',
        'HTTP://ACME.COM',
        'ftp://files.acme.com',
        'acme.com:8080',
        '192.168.1.10',
        'my-company.co',
        'bücher.de',
      ];
      const refused = [
        '',
        'acme',
        'localhost',
        'acme.c',
        'acme.123',
        'a..com',
        '-acme.com',
        'acme-.com',
        'acme_shop.com',
        'acme .com',
        'acme.com\tfoo',
        'javascript://acme.com',
        'mailto://acme.com',
        'https://',
        'acme.com:99999',
        'http://acme.com.',
      ];
      for (final v in accepted) {
        expect(isWebsiteUrl(v), isTrue, reason: v);
        expect(websiteProblem(v), isNull, reason: v);
      }
      for (final v in refused) {
        expect(isWebsiteUrl(v), isFalse, reason: v);
      }
      expect(isWebsiteUrl('${'a' * 2090}.com'), isFalse, reason: 'over 2,084 characters');
      expect(websiteProblem('acme'), 'Enter a website like acme.com or https://acme.com');
      expect(websiteProblem('   '), isNull, reason: 'blank is not set, not wrong');
    });

    testWidgets(
      'places beyond ICR\'s cities come from /locations/search, minus the ones ICR lists, with a state only for India',
      (tester) async {
        final harness = AccountHarness(
          routes: {
            'GET /locations/cities': (_) => [
              {
                'id': 'c-pune',
                'name': 'Pune',
                'state': {'name': 'Maharashtra'},
              },
            ],
            'GET /locations/search': (_) => [
              {
                'label': 'Dubai, United Arab Emirates',
                'city': 'Dubai',
                'state': null,
                'country': 'United Arab Emirates',
                'countryCode': 'AE',
              },
              {'label': 'Pune', 'city': 'Pune', 'state': 'Maharashtra', 'country': 'India', 'countryCode': 'IN'},
              {'label': 'Hubballi', 'city': 'Hubballi', 'state': 'Karnataka', 'country': 'India', 'countryCode': 'IN'},
            ],
          },
        );
        final c = CreateCompanyController(
          repository: ApiAccountRepository(api: harness.client),
          adopt: (_) async {},
        );
        addTearDown(c.dispose);
        await tester.runAsync(c.loadCities);
        expect(await tester.runAsync(() => c.searchPlaces('D')), isEmpty);
        expect(harness.api.count('GET /locations/search'), 0, reason: 'one letter asks nothing');
        final found = (await tester.runAsync(() => c.searchPlaces('Dub')))!;
        expect(harness.api.last('GET /locations/search').query, {'q': 'Dub'});
        expect(found.map((p) => (p.name, p.state)), [('Dubai, United Arab Emirates', null), ('Hubballi', 'Karnataka')]);
        expect(found.first.id, startsWith('place:'));
      },
    );

    testWidgets('POST /me/companies carries the answers and the documents the type is offered, nothing else', (
      tester,
    ) async {
      final harness = AccountHarness(
        routes: {
          'POST /me/companies': (_) => sessionJson(
            user: userJson(role: 'COMPANY_ADMIN', companyId: 'co-new'),
          ),
          'GET /me/companies': (_) => {
            'personalRole': 'PROFESSIONAL',
            'canJoinCompanies': true,
            'companies': [
              {'companyId': 'co-new', 'name': 'Acme', 'role': 'COMPANY_ADMIN', 'active': true},
            ],
            'requests': <Object>[],
            'invitations': <Object>[],
          },
        },
      );
      String? adopted;
      final c = CreateCompanyController(
        repository: ApiAccountRepository(api: harness.client),
        adopt: (t) async => adopted = t.accessToken,
      );
      addTearDown(c.dispose);
      c
        ..name = '  Acme Facility Services '
        ..industry = 'FM_SERVICES'
        ..city = const CityOption(id: 'c-pune', name: 'Pune', state: 'Maharashtra')
        ..size = '11-50'
        ..legalStructure = 'PRIVATE_LIMITED'
        ..description = '  Integrated services.  '
        ..authorised = true;
      c.documents[CompanyDocument.panDoc] = (url: '/uploads/pan.pdf', name: 'pan.pdf');
      c.documents[CompanyDocument.incorporationDoc] = (url: '/uploads/coi.pdf', name: 'coi.pdf');
      expect(await tester.runAsync(c.submit), isTrue);
      expect(adopted, 'a1');
      expect(harness.api.last('POST /me/companies').json, {
        'name': 'Acme Facility Services',
        'industry': 'FM_SERVICES',
        'size': '11-50',
        'legalStructure': 'PRIVATE_LIMITED',
        'city': 'Pune',
        'state': 'Maharashtra',
        'description': 'Integrated services.',
        'incorporationDocUrl': '/uploads/coi.pdf',
        'incorporationDocName': 'coi.pdf',
        'panDocUrl': '/uploads/pan.pdf',
        'panDocName': 'pan.pdf',
      });
      expect(c.created?.companyId, 'co-new');
    });
  });
}
