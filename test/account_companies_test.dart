import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/features/account/account_models.dart';
import 'package:icr_mobile/features/account/companies/ask_to_join_sheet.dart';
import 'package:icr_mobile/features/account/companies/create_company_screen.dart';
import 'package:icr_mobile/features/account/companies/my_companies_screen.dart';
import 'package:icr_mobile/features/account/demo_account_repository.dart';

import 'helpers/account_harness.dart';
import 'helpers/fonts.dart';

/// "My companies" (act for one, or for yourself; leave; withdraw a request; ask
/// to join; create) and "Create a company page", with the fresh token pair
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
  }) async {
    final r = repo ?? DemoAccountRepository(companies: companies ?? MyCompanies(personalRole: 'PROFESSIONAL', companies: const [tech, north]));
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
    testWidgets('each company with its role, place, size and what waits; the personal account is always there and Active when none is', (tester) async {
      await pumpList(tester);
      expect(find.text('My companies'), findsOneWidget);
      expect(find.text('TechCorp'), findsOneWidget);
      expect(find.byKey(const Key('company.role.co-techcorp')), findsOneWidget);
      expect(find.text('Company Admin'), findsOneWidget);
      expect(find.text('Bengaluru, Karnataka'), findsOneWidget);
      expect(find.text('14 members'), findsOneWidget);
      expect(find.text('2 awaiting approval'), findsOneWidget);
      expect(find.text('Northwind Facilities'), findsOneWidget);
      await reveal(tester, find.byKey(const Key('company.personal')));
      expect(find.text('Personal account'), findsOneWidget);
      expect(find.byKey(const Key('company.personal.active')), findsOneWidget);
      expect(find.byKey(const Key('company.switch.personal')), findsNothing);
      expect(find.text('3'), findsOneWidget, reason: 'two companies and the personal account');
    });

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
      expect(find.text('You are not part of a company yet'), findsOneWidget);
      expect(find.byKey(const Key('companies.empty.create')), findsOneWidget);
      expect(find.byKey(const Key('companies.empty.join')), findsOneWidget);
    });

    testWidgets('an ICR staff account is told it is personal: no create, no join', (tester) async {
      await pumpList(tester, companies: const MyCompanies(personalRole: 'SUPER_ADMIN', canJoinCompanies: false));
      expect(find.byKey(const Key('companies.staff')), findsOneWidget);
      expect(find.byKey(const Key('companies.create')), findsNothing);
      expect(find.byKey(const Key('companies.join')), findsNothing);
    });

    testWidgets('with six or more companies a search appears and narrows the list; nothing matching says so', (tester) async {
      final many = [for (var i = 0; i < 6; i++) MyCompany(companyId: 'c$i', name: 'Company $i', role: 'PROFESSIONAL', city: i == 3 ? 'Kochi' : 'Pune')];
      await pumpList(tester, companies: MyCompanies(personalRole: 'PROFESSIONAL', companies: many));
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
    testWidgets('Switch acts for the company: the new session is adopted, the app is told, and the row says Active', (tester) async {
      final log = <String>[];
      final repo = await pumpList(tester, log: log);
      final before = await h.tokens.accessToken();
      await tapKey(tester, 'company.switch.co-techcorp');
      expect(repo.calls, contains('switchCompany:co-techcorp'));
      expect(await h.tokens.accessToken(), isNot(before), reason: 'the role rides in the token, so the pair is replaced');
      expect(log, ['session']);
      expect(find.text('Now acting for TechCorp.'), findsOneWidget);
      expect(find.byKey(const Key('company.switch.co-techcorp')), findsNothing, reason: 'it is the active one now');
      await reveal(tester, find.byKey(const Key('company.switch.personal')));
      expect(find.byKey(const Key('company.personal.active')), findsNothing);
    });

    testWidgets('Switch to personal account goes back to acting as yourself', (tester) async {
      final repo = await pumpList(tester, companies: const MyCompanies(personalRole: 'PROFESSIONAL', companies: [mine]));
      await tapKey(tester, 'company.switch.personal');
      expect(repo.calls, contains('switchCompany:personal'));
      expect(find.text('Now acting as yourself.'), findsOneWidget);
      await reveal(tester, find.byKey(const Key('company.personal.active')));
    });

    testWidgets("a refused switch shows the API's sentence and changes nothing", (tester) async {
      final repo = DemoAccountRepository(companies: const MyCompanies(personalRole: 'PROFESSIONAL', companies: [tech]))
        ..failures['switchCompany'] = ApiError('That company is suspended.', statusCode: 403);
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
      final repo = DemoAccountRepository(companies: const MyCompanies(personalRole: 'PROFESSIONAL', companies: [tech, north]));
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
    testWidgets('asks first, says what is lost; Cancel leaves nothing; Leave ends the place and adopts the new session', (tester) async {
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
    });

    testWidgets('the only admin cannot leave: the row says so and has no Leave', (tester) async {
      await pumpList(tester, companies: const MyCompanies(personalRole: 'PROFESSIONAL', companies: [mine]));
      expect(find.byKey(const Key('company.onlyAdmin.co-mine')), findsOneWidget);
      expect(find.byKey(const Key('company.leave.co-mine')), findsNothing);
    });

    testWidgets("the API's refusal stays in the dialog, beside the button that caused it", (tester) async {
      final repo = DemoAccountRepository(companies: const MyCompanies(personalRole: 'PROFESSIONAL', companies: [north]))
        ..failures['leaveCompany'] = ApiError('You still own open requirements here.', statusCode: 400);
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
    const asked = JoinRequest(companyId: 'co-global', name: 'Global Infra Solutions', role: 'PROFESSIONAL', note: 'I work with them on the Pune campus.');

    testWidgets('a waiting request shows who, as what and the note; Withdraw takes it back', (tester) async {
      final repo = await pumpList(tester, companies: const MyCompanies(personalRole: 'PROFESSIONAL', companies: [tech], requests: [asked]));
      expect(find.text('Awaiting approval'), findsOneWidget);
      expect(find.text('Global Infra Solutions'), findsOneWidget);
      expect(find.text('Requested as Professional'), findsOneWidget);
      expect(find.text('“I work with them on the Pune campus.”'), findsOneWidget);
      await tapKey(tester, 'request.withdraw.co-global');
      expect(repo.calls, contains('withdrawRequest:co-global'));
      expect(find.byKey(const Key('companies.requests')), findsNothing);
      expect(find.text('Request to join Global Infra Solutions withdrawn.'), findsOneWidget);
    });

    testWidgets('a request already decided is the API sentence, and the list is read again', (tester) async {
      final repo = DemoAccountRepository(companies: const MyCompanies(personalRole: 'PROFESSIONAL', requests: [asked]))
        ..failures['withdrawRequest'] = ApiError('That request is no longer waiting.', statusCode: 404);
      await pumpList(tester, repo: repo);
      await tapKey(tester, 'request.withdraw.co-global');
      await tester.drag(find.byKey(const Key('companies.list')), const Offset(0, 2000));
      await tester.pumpAndSettle();
      expect(find.text('That request is no longer waiting.'), findsOneWidget);
    });

    testWidgets('Ask to join: find the company, say why, send; it shows under Awaiting approval and the note goes with it', (tester) async {
      final repo = await pumpList(tester, companies: const MyCompanies(personalRole: 'PROFESSIONAL'));
      await tapKey(tester, 'companies.join');
      expect(find.text('Ask to join a company'), findsWidgets);
      await tester.enterText(find.byKey(const Key('join.search')), 'Global');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('join.hit.co-global')));
      await tester.pumpAndSettle();
      expect(find.text('Ask to join Global Infra Solutions'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('join.note')), 'I am their site lead.');
      await tester.pump();
      await tester.tap(find.byKey(const Key('sheet.save')));
      await tester.pumpAndSettle();
      expect(repo.sent['requestToJoin'], {'companyId': 'co-global', 'note': 'I am their site lead.'});
      expect(find.text('Request sent to Global Infra Solutions.'), findsOneWidget);
      expect(find.text('Awaiting approval'), findsOneWidget);
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
                      search: search ?? (q) async => [const CompanyHit(id: 'a', name: 'Alpha Estates', city: 'Pune'), const CompanyHit(id: 'b', name: 'Alpha Labs')],
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
      await pumpSheet(tester, search: (q) async {
        asked++;
        return const [];
      });
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
      expect(find.text('Request sent'), findsOneWidget);
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

    testWidgets('Create sends exactly what was chosen, adopts the new session and turns into the welcome page', (tester) async {
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
      expect(find.text('Acme Facility Services is on ICR'), findsOneWidget);
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
      expect(log, ['team:Acme Facility Services', 'verify:Acme Facility Services', 'sell:Acme Facility Services', 'details:Acme Facility Services']);
      await tapKey(tester, 'create.done');
    });

    testWidgets('an empty form is refused with every missing detail named, and a tap takes you to it; nothing is sent', (tester) async {
      final repo = await pumpCreate(tester);
      await tapKey(tester, 'create.submit');
      expect(repo.count('createCompany'), 0);
      expect(find.text('6 details need attention'), findsOneWidget);
      expect(find.text('Enter the company name.'), findsOneWidget);
      expect(find.text('Choose the industry it works in.'), findsOneWidget);
      expect(find.text('Choose where the head office is.'), findsOneWidget);
      expect(find.text('Choose how many people work there.'), findsOneWidget);
      expect(find.text('Choose how the organisation is set up.'), findsOneWidget);
      expect(find.text('Confirm that you may create this page for the company.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('create.summary.industry')));
      await tester.pumpAndSettle();
      // Fixing one removes its message at once.
      await pick(tester, 'create.industry', 'Facility management services');
      expect(find.text('Choose the industry it works in.'), findsNothing);
      expect(find.text('5 details need attention'), findsOneWidget);
    });

    testWidgets('a different legal name is asked only when ticked, and a bad website is refused in the website\'s words', (tester) async {
      await pumpCreate(tester);
      expect(find.byKey(const Key('create.legalName')), findsNothing);
      await tapKey(tester, 'create.legalDiffers');
      expect(find.byKey(const Key('create.legalName')), findsOneWidget);
      await type(tester, 'create.legalName', '1');
      await type(tester, 'create.website', 'not a site');
      await tapKey(tester, 'create.submit');
      expect(find.text('Enter the registered legal name — it needs at least one letter.'), findsOneWidget);
      expect(find.text('Enter a website like acme.com or https://acme.com'), findsOneWidget);
    });

    testWidgets("the API's refusal shows above the buttons and every answer stays", (tester) async {
      final repo = DemoAccountRepository()..failures['createCompany'] = ApiError('That industry is no longer offered.', statusCode: 400);
      await pumpCreate(tester, repo: repo);
      await fillAll(tester);
      await tapKey(tester, 'create.submit');
      expect(find.byKey(const Key('create.error')), findsOneWidget);
      expect(find.text('That industry is no longer offered.'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('create.name'))).controller!.text, 'Acme Facility Services');
      expect(find.byKey(const Key('create.welcome')), findsNothing);
    });

    testWidgets('companies that look alike are offered: Ask to join sends the request and marks it sent; View page calls out', (tester) async {
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
    });

    testWidgets('a logo is uploaded with its preview; one over 2 MB or of another type is refused before upload; Remove takes it off', (tester) async {
      final repo = await pumpCreate(tester, pickPhoto: () async => PickedPhoto(bytes: List.filled(64, 1), name: 'logo.png'));
      await tapKey(tester, 'create.logo.add');
      expect(repo.calls, contains('upload:company'));
      expect(find.text('Logo uploaded. It appears on your company page, job posts and supplier card.'), findsOneWidget);
      await tapKey(tester, 'create.logo.remove');
      expect(find.byKey(const Key('create.logo.add')), findsOneWidget);

      final big = await pumpCreate(tester, pickPhoto: () async => PickedPhoto(bytes: List.filled(2 * 1024 * 1024 + 1, 1), name: 'big.png'));
      await tapKey(tester, 'create.logo.add');
      expect(find.text('That image is over 2MB. Compress it or choose a smaller one.'), findsOneWidget);
      expect(big.count('upload'), 0);

      await pumpCreate(tester, pickPhoto: () async => PickedPhoto(bytes: List.filled(64, 1), name: 'logo.gif', mimeType: 'image/gif'));
      await tapKey(tester, 'create.logo.add');
      expect(find.text('That file is not accepted. Use a PNG, JPG or WEBP image.'), findsOneWidget);
    });

    testWidgets('Back with something typed asks to discard; without, it just leaves', (tester) async {
      await pumpCreate(tester);
      await tapKey(tester, 'create.cancel');
      expect(find.text('Create a company page'), findsNothing, reason: 'nothing typed: it left');
    });

    testWidgets('Cancel after typing asks first', (tester) async {
      await pumpCreate(tester);
      await type(tester, 'create.name', 'Half done Ltd');
      await tapKey(tester, 'create.cancel');
      expect(find.text('Discard this company page?'), findsOneWidget);
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      expect(find.text('Create a company page'), findsWidgets);
      expect(tester.widget<TextField>(find.byKey(const Key('create.name'))).controller!.text, 'Half done Ltd');
    });
  });
}
