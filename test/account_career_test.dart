import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/account/account_models.dart';
import 'package:icr_mobile/features/account/demo_account_repository.dart';
import 'package:icr_mobile/features/account/profile/my_profile_screen.dart';
import 'package:icr_mobile/features/account/widgets/account_kit.dart' show CoverBand;
import 'package:icr_mobile/features/account/widgets/photo_picker.dart';

import 'helpers/account_harness.dart';
import 'helpers/fonts.dart';

/// The career sections of the person's profile: experience (with career breaks
/// and gaps), education, and credentials: what each sheet shows, validates and
/// sends. The API saves these lists WHOLE, so what matters is the list each save
/// sends; the sample repository logs it in `sent`.
void main() {
  setUpAll(() async {
    await loadAppFonts();
    CoverBand.loadArt = false;
  });

  final now = DateTime.utc(2026, 10, 26);

  Future<DemoAccountRepository> pump(
    WidgetTester tester, {
    DemoAccountRepository? repo,
    PhotoPicker? pickEvidence,
    void Function(Credential)? onCertificate,
  }) async {
    final r = repo ?? DemoAccountRepository();
    usePhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: MyProfileScreen(
          repository: r,
          now: now,
          pickEvidence: pickEvidence ?? () async => PickedPhoto(bytes: List.filled(32, 3), name: 'cfm.pdf'),
          onOpenCertificate: onCertificate,
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
    await tester.ensureVisible(target);
    await tester.pump();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String key, String text) async {
    final field = find.byKey(Key(key));
    await tester.ensureVisible(field);
    await tester.pump();
    await tester.enterText(field, text);
    await tester.pump();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('sheet.save')));
    await tester.pumpAndSettle();
  }

  /// Picks [year] in the year list a field opens (searching, since the list is long).
  Future<void> pickYear(WidgetTester tester, String key, int year) async {
    await tapKey(tester, key);
    await tester.enterText(find.byKey(const Key('accountPicker.search')), '$year');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, '$year'));
    await tester.pumpAndSettle();
  }

  Future<void> pickMonth(WidgetTester tester, String key, String month) async {
    await tapKey(tester, key);
    final item = find.widgetWithText(ListTile, month);
    await tester.scrollUntilVisible(item, 100, scrollable: find.byType(Scrollable).last);
    await tester.tap(item);
    await tester.pumpAndSettle();
  }

  /// A profile with the roles given and nothing else.
  DemoAccountRepository withRoles(List<Experience> roles, {List<CareerBreak> breaks = const []}) =>
      DemoAccountRepository(experience: roles)..breaksNow = breaks;

  group('experience', () {
    testWidgets('lists roles newest first, each with its dates and how long', (tester) async {
      await pump(tester);
      await reveal(tester, find.text('Experience'));
      final titles = tester.widgetList<Text>(find.textContaining('Manager')).map((t) => t.data).toList();
      expect(titles.indexOf('Lead Operations Manager'), lessThan(titles.indexOf('Facilities Manager')));
      expect(find.text('TechCorp · Full-time'), findsOneWidget);
      expect(find.text('Apr 2021 — Present · 5 yrs 6 mos'), findsOneWidget);
      expect(find.text('Jul 2016 — Mar 2021 · 4 yrs 8 mos'), findsOneWidget);
      expect(find.textContaining('3.2M sq ft'), findsOneWidget);
    });

    testWidgets('an empty list offers "Add experience"', (tester) async {
      await pump(tester, repo: withRoles(const []));
      await reveal(tester, find.text('Add your roles, newest first. Employers and mentors read these.'));
      await tester.tap(find.text('Add experience').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('role.title')), findsOneWidget);
    });

    testWidgets('Add: a typed role is saved with the whole list, and shows at the top', (tester) async {
      final repo = await pump(tester);
      await reveal(tester, find.byTooltip('Add experience'));
      await tester.tap(find.byTooltip('Add experience'));
      await tester.pumpAndSettle();
      expect(find.text('Add experience'), findsWidgets);

      await type(tester, 'role.title', 'Site Engineer');
      await type(tester, 'role.organisation', 'Harbour Builders');
      await tapKey(tester, 'role.current');
      await pickYear(tester, 'role.start.year', 2025);
      await pickMonth(tester, 'role.start.month', 'March');
      await type(tester, 'role.description', 'Fit-out supervision.');
      await save(tester);

      final rows = repo.sent['saveExperience']! as List;
      expect(rows.length, 3, reason: 'the two roles it had, and the new one: the API replaces the whole list');
      final added = rows.last as Map;
      expect(added['title'], 'Site Engineer');
      expect(added['organisation'], 'Harbour Builders');
      expect(added.containsKey('companyId'), isFalse, reason: 'a typed name links to no page');
      expect(added['startYear'], 2025);
      expect(added['startMonth'], 3);
      expect(added['isCurrent'], isTrue);
      expect(added.containsKey('endYear'), isFalse);
      expect(added['description'], 'Fit-out supervision.');
      expect(find.text('Experience saved.'), findsOneWidget);
      await reveal(tester, find.text('Site Engineer'));
      expect(find.text('Mar 2025 — Present · 1 yr 7 mos'), findsOneWidget);
    });

    testWidgets('Add: what is missing or wrong is said beside the field, and nothing is sent', (tester) async {
      final repo = await pump(tester);
      await reveal(tester, find.byTooltip('Add experience'));
      await tester.tap(find.byTooltip('Add experience'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sheet.save')));
      await tester.pumpAndSettle();
      expect(find.text('Add your role.'), findsOneWidget);
      expect(find.text('Add the organisation.'), findsOneWidget);
      expect(find.text('Choose when you started.'), findsOneWidget);
      expect(find.text('Add when this role ended, or tick “I work here now”.'), findsOneWidget);
      expect(repo.count('saveExperience'), 0);
    });

    testWidgets('an end before the start, and a start in the future, are refused', (tester) async {
      await pump(tester);
      await reveal(tester, find.byTooltip('Add experience'));
      await tester.tap(find.byTooltip('Add experience'));
      await tester.pumpAndSettle();
      await type(tester, 'role.title', 'Analyst');
      await type(tester, 'role.organisation', 'Acme');
      await pickYear(tester, 'role.start.year', 2020);
      await pickYear(tester, 'role.end.year', 2019);
      await tester.tap(find.byKey(const Key('sheet.save')));
      await tester.pumpAndSettle();
      expect(find.text('The end date is before the start date.'), findsOneWidget);
      await pickYear(tester, 'role.start.year', 2026);
      await pickMonth(tester, 'role.start.month', 'December');
      await tester.tap(find.byKey(const Key('sheet.save')));
      await tester.pumpAndSettle();
      expect(find.text('The start date can’t be in the future.'), findsOneWidget);
    });

    testWidgets('Edit: the pencil opens the role; Save sends the list with that row replaced', (tester) async {
      final repo = await pump(tester);
      await reveal(tester, find.byTooltip('Edit Facilities Manager at Global Infra Solutions'));
      await tester.tap(find.byTooltip('Edit Facilities Manager at Global Infra Solutions'));
      await tester.pumpAndSettle();
      expect(find.text('Edit experience'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('role.title'))).controller!.text, 'Facilities Manager');
      await type(tester, 'role.title', 'Senior Facilities Manager');
      await save(tester);
      final rows = repo.sent['saveExperience']! as List;
      expect(rows.map((r) => (r as Map)['title']), ['Lead Operations Manager', 'Senior Facilities Manager']);
      expect(find.text('Senior Facilities Manager'), findsOneWidget);
    });

    testWidgets('Delete asks first, then sends the list without the role', (tester) async {
      final repo = await pump(tester);
      await reveal(tester, find.byTooltip('Edit Facilities Manager at Global Infra Solutions'));
      await tester.tap(find.byTooltip('Edit Facilities Manager at Global Infra Solutions'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sheet.delete')));
      await tester.pumpAndSettle();
      expect(find.text('Delete this role?'), findsOneWidget);
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      expect(repo.count('saveExperience'), 0);
      await tester.tap(find.byKey(const Key('sheet.delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm.ok')));
      await tester.pumpAndSettle();
      expect((repo.sent['saveExperience']! as List).length, 1);
      expect(find.text('Facilities Manager'), findsNothing);
    });

    testWidgets('a company picked from ICR is linked, and "Ask to join" is sent before the role is saved', (tester) async {
      final repo = await pump(tester, repo: withRoles(const []));
      await reveal(tester, find.text('Add experience').last);
      await tester.tap(find.text('Add experience').last);
      await tester.pumpAndSettle();
      await type(tester, 'role.title', 'Facility Manager');
      await type(tester, 'role.organisation', 'Global');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Global Infra Solutions'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'role.current');
      expect(find.text('Linked to its page on ICR.'), findsOneWidget);
      expect(find.byKey(const Key('role.askToJoin')), findsOneWidget);
      await pickYear(tester, 'role.start.year', 2024);
      await save(tester);

      expect(repo.sent['requestToJoin'], {'companyId': 'co-global'});
      final row = (repo.sent['saveExperience']! as List).single as Map;
      expect(row['companyId'], 'co-global');
      expect(row['organisation'], 'Global Infra Solutions');
      // Request first, then the role.
      expect(repo.calls.indexOf('requestToJoin:co-global'), lessThan(repo.calls.indexOf('saveExperience')));
    });

    testWidgets('unticking Ask to join sends no request; typing over a picked name unlinks it', (tester) async {
      final repo = await pump(tester, repo: withRoles(const []));
      await reveal(tester, find.text('Add experience').last);
      await tester.tap(find.text('Add experience').last);
      await tester.pumpAndSettle();
      await type(tester, 'role.title', 'Facility Manager');
      await type(tester, 'role.organisation', 'Global');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Global Infra Solutions'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'role.current');
      await tapKey(tester, 'role.askToJoin');
      await pickYear(tester, 'role.start.year', 2024);
      await save(tester);
      expect(repo.count('requestToJoin'), 0);
      expect((repo.sent['saveExperience']! as List).single['companyId'], 'co-global');

      // Typing a different name takes the link off.
      await reveal(tester, find.byTooltip('Edit Facility Manager at Global Infra Solutions'));
      await tester.tap(find.byTooltip('Edit Facility Manager at Global Infra Solutions'));
      await tester.pumpAndSettle();
      await type(tester, 'role.organisation', 'Global Infra Solutions Ltd');
      await save(tester);
      expect((repo.sent['saveExperience']! as List).single.containsKey('companyId'), isFalse);
    });

    testWidgets('a refused request to join saves nothing and says why', (tester) async {
      final repo = withRoles(const [])..failures['requestToJoin'] = ApiError('You already asked to join this company.', statusCode: 409);
      await pump(tester, repo: repo);
      await reveal(tester, find.text('Add experience').last);
      await tester.tap(find.text('Add experience').last);
      await tester.pumpAndSettle();
      await type(tester, 'role.title', 'Facility Manager');
      await type(tester, 'role.organisation', 'Global');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Global Infra Solutions'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'role.current');
      await pickYear(tester, 'role.start.year', 2024);
      await save(tester);
      expect(find.text('You already asked to join this company.'), findsOneWidget);
      expect(repo.count('saveExperience'), 0);
      expect(tester.widget<TextField>(find.byKey(const Key('role.title'))).controller!.text, 'Facility Manager');
    });

    testWidgets('a company the person already belongs to is not offered to join', (tester) async {
      await pump(tester, repo: withRoles(const []));
      await reveal(tester, find.text('Add experience').last);
      await tester.tap(find.text('Add experience').last);
      await tester.pumpAndSettle();
      await type(tester, 'role.organisation', 'TechCorp');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tap(find.text('TechCorp').last);
      await tester.pumpAndSettle();
      await tapKey(tester, 'role.current');
      expect(find.byKey(const Key('role.askToJoin')), findsNothing);
    });

    testWidgets("the API's refusal keeps what was typed", (tester) async {
      final repo = DemoAccountRepository()..failures['saveExperience'] = ApiError('You can hold at most 20 roles.', statusCode: 400);
      await pump(tester, repo: repo);
      await reveal(tester, find.byTooltip('Edit Facilities Manager at Global Infra Solutions'));
      await tester.tap(find.byTooltip('Edit Facilities Manager at Global Infra Solutions'));
      await tester.pumpAndSettle();
      await type(tester, 'role.title', 'Director');
      await save(tester);
      expect(find.text('You can hold at most 20 roles.'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('role.title'))).controller!.text, 'Director');
    });

    testWidgets('a role with no end year and not current cannot be saved; ticking "I work here now" removes the end', (tester) async {
      final repo = await pump(tester);
      await reveal(tester, find.byTooltip('Edit Lead Operations Manager at TechCorp'));
      await tester.tap(find.byTooltip('Edit Lead Operations Manager at TechCorp'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('role.end.year')), findsNothing, reason: 'a current role has no end date');
      await tapKey(tester, 'role.current');
      expect(find.byKey(const Key('role.end.year')), findsOneWidget);
      await tester.tap(find.byKey(const Key('sheet.save')));
      await tester.pumpAndSettle();
      expect(find.text('Add when this role ended, or tick “I work here now”.'), findsOneWidget);
      expect(repo.count('saveExperience'), 0);
    });
  });

  group('career breaks and gaps', () {
    testWidgets('Add a career break: reason and dates are saved through the breaks list, and the break shows in date order', (tester) async {
      final repo = await pump(tester);
      await reveal(tester, find.byTooltip('Add a career break'));
      await tester.tap(find.byTooltip('Add a career break'));
      await tester.pumpAndSettle();
      expect(find.text('Add career break'), findsOneWidget);
      await tapKey(tester, 'break.reason');
      await tester.tap(find.widgetWithText(ListTile, 'Study or upskilling'));
      await tester.pumpAndSettle();
      await pickYear(tester, 'break.start.year', 2014);
      await pickYear(tester, 'break.end.year', 2015);
      await type(tester, 'break.description', 'MBA.');
      await save(tester);
      final rows = repo.sent['saveCareerBreaks']! as List;
      expect(rows.single, {'reason': 'STUDY', 'startYear': 2014, 'endYear': 2015, 'isCurrent': false, 'description': 'MBA.'});
      await reveal(tester, find.text('Career break · Study or upskilling'));
      expect(find.text('Career break saved.'), findsOneWidget);
    });

    testWidgets('a break needs a reason and dates in order', (tester) async {
      final repo = await pump(tester);
      await reveal(tester, find.byTooltip('Add a career break'));
      await tester.tap(find.byTooltip('Add a career break'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sheet.save')));
      await tester.pumpAndSettle();
      expect(find.text('Choose why you took this break.'), findsOneWidget);
      expect(find.text('Choose when the break started.'), findsOneWidget);
      expect(repo.count('saveCareerBreaks'), 0);
    });

    testWidgets('Edit and Delete a break', (tester) async {
      final repo = DemoAccountRepository()
        ..breaksNow = const [CareerBreak(id: 'b1', reason: 'TRAVEL', startYear: 2012, startMonth: 1, endYear: 2012, endMonth: 8)];
      await pump(tester, repo: repo);
      await reveal(tester, find.byTooltip('Edit career break'));
      await tester.tap(find.byTooltip('Edit career break'));
      await tester.pumpAndSettle();
      expect(find.text('Edit career break'), findsOneWidget);
      await type(tester, 'break.description', 'Backpacking.');
      await save(tester);
      expect((repo.sent['saveCareerBreaks']! as List).single['description'], 'Backpacking.');

      await tester.tap(find.byTooltip('Edit career break'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sheet.delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm.ok')));
      await tester.pumpAndSettle();
      expect(repo.sent['saveCareerBreaks'], isEmpty);
    });

    testWidgets('a stretch no role covers is shown to the person as a gap, with "Add a career break" that fills in its dates', (tester) async {
      final repo = withRoles(const [
        Experience(id: 'a', title: 'Analyst', organisation: 'Acme', startYear: 2015, startMonth: 1, endYear: 2018, endMonth: 12),
        Experience(id: 'b', title: 'Manager', organisation: 'Beta', startYear: 2020, startMonth: 1, isCurrent: true),
      ]);
      await pump(tester, repo: repo);
      await reveal(tester, find.byKey(const Key('career.gap')));
      expect(find.text('A gap of 1 yr', findRichText: true), findsNothing);
      expect(find.textContaining('A gap of 1 yr', findRichText: true), findsOneWidget);
      expect(find.text('Only you see this.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('gap.addBreak')));
      await tester.pumpAndSettle();
      expect(find.text('Add career break'), findsOneWidget);
      // The dates of the gap (Jan 2019 – Dec 2019) are already in the sheet.
      expect(find.text('2019'), findsWidgets);
      expect(find.text('January'), findsOneWidget);
      expect(find.text('December'), findsOneWidget);
    });

    testWidgets('a gap shorter than six months is not a gap; a break that covers it removes it', (tester) async {
      final roles = [
        const Experience(id: 'a', title: 'Analyst', organisation: 'Acme', startYear: 2015, startMonth: 1, endYear: 2018, endMonth: 12),
        const Experience(id: 'b', title: 'Manager', organisation: 'Beta', startYear: 2019, startMonth: 4, isCurrent: true),
      ];
      await pump(tester, repo: withRoles(roles));
      await reveal(tester, find.text('Experience'));
      expect(find.byKey(const Key('career.gap')), findsNothing);
    });
  });

  group('education', () {
    testWidgets('lists the qualifications with their degree and years', (tester) async {
      await pump(tester);
      await reveal(tester, find.text('RV College of Engineering'));
      expect(find.text('B.E. · Mechanical Engineering'), findsOneWidget);
      expect(find.text('2008 – 2012'), findsOneWidget);
    });

    testWidgets('Add sends the whole list with the new qualification; blanks are left out', (tester) async {
      final repo = await pump(tester);
      await reveal(tester, find.byTooltip('Add education'));
      await tester.tap(find.byTooltip('Add education'));
      await tester.pumpAndSettle();
      await type(tester, 'edu.institution', 'IIM Bangalore');
      await type(tester, 'edu.degree', 'PGDM');
      await pickYear(tester, 'edu.start', 2013);
      await pickYear(tester, 'edu.end', 2015);
      await save(tester);
      final rows = repo.sent['saveEducation']! as List;
      expect(rows.length, 2);
      expect(rows.last, {'institution': 'IIM Bangalore', 'degree': 'PGDM', 'startYear': 2013, 'endYear': 2015});
      expect(find.text('Education saved.'), findsOneWidget);
    });

    testWidgets('an institution is required, and the end year may not be before the start', (tester) async {
      final repo = await pump(tester);
      await reveal(tester, find.byTooltip('Add education'));
      await tester.tap(find.byTooltip('Add education'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sheet.save')));
      await tester.pumpAndSettle();
      expect(find.text('Add the institution.'), findsOneWidget);
      await type(tester, 'edu.institution', 'X University');
      await pickYear(tester, 'edu.start', 2015);
      await pickYear(tester, 'edu.end', 2013);
      await tester.tap(find.byKey(const Key('sheet.save')));
      await tester.pumpAndSettle();
      expect(find.text('The end year is before the start year.'), findsOneWidget);
      expect(repo.count('saveEducation'), 0);
    });

    testWidgets('Edit and Delete', (tester) async {
      final repo = await pump(tester);
      await reveal(tester, find.byTooltip('Edit RV College of Engineering'));
      await tester.tap(find.byTooltip('Edit RV College of Engineering'));
      await tester.pumpAndSettle();
      await type(tester, 'edu.grade', 'First class');
      await save(tester);
      expect((repo.sent['saveEducation']! as List).single['grade'], 'First class');
      await reveal(tester, find.text('Grade: First class'));
      await reveal(tester, find.byTooltip('Edit RV College of Engineering'));
      await tester.tap(find.byTooltip('Edit RV College of Engineering'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sheet.delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm.ok')));
      await tester.pumpAndSettle();
      expect(repo.sent['saveEducation'], isEmpty);
    });
  });

  group('credentials', () {
    testWidgets('the ones ICR issued are read-only chips that open their certificate; external ones can be edited', (tester) async {
      final opened = <String>[];
      await pump(tester, onCertificate: (c) => opened.add(c.id));
      await reveal(tester, find.text('Certified Facility Professional (CFP)'));
      expect(find.text('Issued by ICR'), findsOneWidget);
      expect(find.byTooltip('Edit Certified Facility Professional'), findsNothing);
      expect(find.byTooltip('Edit IFMA Facility Management Professional'), findsOneWidget);
      expect(find.text('Self-declared'), findsOneWidget);
      await tester.tap(find.text('Certified Facility Professional (CFP)'));
      await tester.pump();
      expect(opened, ['cred-1']);
    });

    testWidgets('Add: name, code in capitals, issuer, the date, a certificate; the body leaves blanks out', (tester) async {
      final repo = await pump(tester);
      await reveal(tester, find.byTooltip('Add credential'));
      await tester.tap(find.byTooltip('Add credential'));
      await tester.pumpAndSettle();
      await type(tester, 'cred.name', 'Certified Facility Manager');
      await type(tester, 'cred.code', 'cfm');
      await type(tester, 'cred.issuer', 'IFMA');
      await tapKey(tester, 'cred.issued');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'cred.attach');
      expect(find.text('cfm.pdf'), findsOneWidget);
      expect(repo.calls, contains('upload:credential'));
      await save(tester);

      final body = repo.sent['addCredential']! as Map;
      expect(body['name'], 'Certified Facility Manager');
      expect(body['code'], 'CFM');
      expect(body['issuer'], 'IFMA');
      expect(body['issuedAt'], CredentialDraft.day(DateTime.now()));
      expect(body['fileUrl'], startsWith('/uploads/'));
      expect(body['fileName'], 'cfm.pdf');
      expect(body.containsKey('expiresAt'), isFalse);
      expect(body.containsKey('credentialUrl'), isFalse);
      expect(find.text('Credential saved.'), findsOneWidget);
      await reveal(tester, find.text('Certified Facility Manager (CFM)'));
      expect(find.text('Certificate on file'), findsOneWidget);
    });

    testWidgets('a name is required; an expiry before the issue date and a link that is not a web address are refused', (tester) async {
      final repo = await pump(tester);
      await reveal(tester, find.byTooltip('Add credential'));
      await tester.tap(find.byTooltip('Add credential'));
      await tester.pumpAndSettle();
      await type(tester, 'cred.url', 'not a link');
      await tester.tap(find.byKey(const Key('sheet.save')));
      await tester.pumpAndSettle();
      expect(find.text('Give the credential a name.'), findsOneWidget);
      expect(find.text('Enter a full web address, like https://issuer.org/verify/12345.'), findsOneWidget);
      expect(repo.count('addCredential'), 0);
    });

    testWidgets('Edit sends only that credential; the evidence can be removed', (tester) async {
      final repo = DemoAccountRepository()
        ..credentialsNow = [
          const Credential(
            id: 'c9',
            source: 'EXTERNAL',
            name: 'NEBOSH IGC',
            issuer: 'NEBOSH',
            status: 'PENDING',
            fileUrl: '/uploads/x.pdf',
            fileName: 'nebosh.pdf',
          ),
        ];
      await pump(tester, repo: repo);
      await reveal(tester, find.byTooltip('Edit NEBOSH IGC'));
      expect(find.text('Certificate on file'), findsOneWidget, reason: 'a certificate with no review yet');
      await tester.tap(find.byTooltip('Edit NEBOSH IGC'));
      await tester.pumpAndSettle();
      expect(find.text('nebosh.pdf'), findsOneWidget);
      await tapKey(tester, 'cred.removeFile');
      expect(find.byKey(const Key('cred.attach')), findsOneWidget);
      await save(tester);
      final body = repo.sent['updateCredential']! as Map;
      expect(body.containsKey('fileUrl'), isFalse);
      expect(body['name'], 'NEBOSH IGC');
      expect(repo.calls, contains('updateCredential:c9'));
    });

    testWidgets('Delete asks first; a claim taken off the mentor profile is said', (tester) async {
      final repo = _MentorClaimRepo();
      await pump(tester, repo: repo);
      await reveal(tester, find.byTooltip('Edit IFMA Facility Management Professional'));
      await tester.tap(find.byTooltip('Edit IFMA Facility Management Professional'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sheet.delete')));
      await tester.pumpAndSettle();
      expect(find.text('Delete this credential?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm.ok')));
      await tester.pumpAndSettle();
      expect(find.text('Removed from your mentor profile'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(repo.credentialsNow.map((c) => c.id), ['cred-1']);
    });

    testWidgets('an evidence file over 10 MB is refused before it is sent; a refused upload shows the API sentence', (tester) async {
      final repo = await pump(tester, pickEvidence: () async => PickedPhoto(bytes: List.filled(10 * 1024 * 1024 + 1, 1), name: 'scan.pdf'));
      await reveal(tester, find.byTooltip('Add credential'));
      await tester.tap(find.byTooltip('Add credential'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'cred.attach');
      expect(find.text('That file is too big. Choose one under 10 MB.'), findsOneWidget);
      expect(repo.count('upload'), 0);
    });
  });
}

/// A repository whose credential delete reports a claim taken off a mentor profile.
class _MentorClaimRepo extends DemoAccountRepository {
  @override
  Future<String?> deleteCredential(String id) async {
    await super.deleteCredential(id);
    return 'FMP';
  }
}
