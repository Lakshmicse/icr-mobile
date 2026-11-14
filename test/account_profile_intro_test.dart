import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/account/account_models.dart';
import 'package:icr_mobile/features/account/demo_account_repository.dart';
import 'package:icr_mobile/features/account/profile/intro_line.dart';
import 'package:icr_mobile/features/account/profile/my_profile_screen.dart';
import 'package:icr_mobile/features/account/profile/profile_controller.dart';
import 'package:icr_mobile/features/account/profile/sheets/career_sheets.dart';
import 'package:icr_mobile/features/account/settings/contact_sheet.dart';
import 'package:icr_mobile/features/account/widgets/account_kit.dart' show CoverBand;

import 'helpers/account_harness.dart';
import 'helpers/fonts.dart';

/// LinkedIn's intro line ("Company · School" under the headline) and the
/// Organisation and Education lists in Edit Intro that choose it.
void main() {
  setUpAll(() async {
    await loadAppFonts();
    CoverBand.loadArt = false;
  });

  Experience role(String org, int year, {int? month, bool current = true, String title = 'Manager'}) => Experience(
    title: title,
    organisation: org,
    startYear: year,
    startMonth: month,
    isCurrent: current,
    endYear: current ? null : year + 2,
  );

  const rv = Education(
    id: 'edu-rv',
    institution: 'RV College of Engineering',
    degree: 'B.E.',
    startYear: 2008,
    endYear: 2012,
  );
  const iim = Education(id: 'edu-iim', institution: 'IIM Bangalore', degree: 'MBA', startYear: 2014, endYear: 2016);

  group('the rule', () {
    test('Organisation offers the current roles, the one that started last first, one per company', () {
      final options = introRoles([
        role('TechCorp', 2021, month: 4),
        role('Global Infra', 2016, current: false),
        role('Upscaled', 2023, month: 1),
        role('techcorp ', 2020),
        role('  ', 2024),
      ]);
      expect([for (final r in options) r.organisation.trim()], ['Upscaled', 'TechCorp']);
    });

    test('by default the line is the newest current company and the newest school', () {
      expect(
        introLine(roles: [role('TechCorp', 2021), role('Upscaled', 2023)], education: const [iim, rv]),
        'Upscaled · IIM Bangalore',
      );
    });

    test('a choice is followed; "Please Select" leaves that half out', () {
      final roles = [role('TechCorp', 2021), role('Upscaled', 2023)];
      expect(
        introLine(
          roles: roles,
          education: const [iim, rv],
          choice: const IntroChoice(organisation: 'TechCorp', school: 'RV College of Engineering'),
        ),
        'TechCorp · RV College of Engineering',
      );
      expect(
        introLine(
          roles: roles,
          education: const [iim, rv],
          choice: const IntroChoice(organisation: ''),
        ),
        'IIM Bangalore',
      );
      expect(
        introLine(
          roles: roles,
          education: const [iim],
          choice: const IntroChoice(organisation: '', school: ''),
        ),
        isNull,
      );
    });

    test('a chosen company that is no longer a current role falls back to the default', () {
      expect(
        introLine(
          roles: [role('TechCorp', 2021), role('Global Infra', 2016, current: false)],
          education: const [],
          choice: const IntroChoice(organisation: 'Global Infra'),
        ),
        'TechCorp',
      );
    });

    test('with no current role the company they act for is named, unless they chose none', () {
      expect(introLine(roles: const [], education: const [rv], actingFor: 'Acme'), 'Acme · RV College of Engineering');
      expect(
        introLine(
          roles: const [],
          education: const [],
          actingFor: 'Acme',
          choice: const IntroChoice(organisation: ''),
        ),
        isNull,
      );
      expect(introLine(roles: const [], education: const []), isNull);
    });
  });

  group('the controller', () {
    test('reads this account\'s choice from the phone and keeps a new one there', () async {
      final store = MemoryIntroChoiceStore({'me': const IntroChoice(school: '')});
      final c = MyProfileController(DemoAccountRepository(), introStore: store);
      await c.load();
      expect(c.introAffiliation, 'TechCorp', reason: 'the school was switched off on this phone');
      await c.saveIntroChoice(const IntroChoice());
      expect(c.introAffiliation, 'TechCorp · RV College of Engineering');
      expect(await store.load('me'), const IntroChoice());
      c.dispose();
    });
  });

  group('the page and Edit Intro', () {
    PickedPhoto photo() => PickedPhoto(bytes: List.filled(64, 7), name: 'me.png');

    Future<DemoAccountRepository> pump(WidgetTester tester, {DemoAccountRepository? repo}) async {
      final r = repo ?? DemoAccountRepository();
      usePhone(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: MyProfileScreen(repository: r, pickPhoto: () async => photo(), now: DateTime.utc(2026, 10, 26)),
        ),
      );
      await tester.pumpAndSettle();
      return r;
    }

    Future<void> tapKey(WidgetTester tester, String key) async {
      final target = find.byKey(Key(key));
      await tester.ensureVisible(target);
      await tester.pump();
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    Future<void> choose(WidgetTester tester, String item) async {
      await tester.tap(find.widgetWithText(ListTile, item));
      await tester.pumpAndSettle();
    }

    Future<void> save(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('sheet.save')));
      await tester.pumpAndSettle();
    }

    testWidgets('under the headline: the current company and the school; the place on its own line', (tester) async {
      await pump(tester);
      expect(find.text('TechCorp · RV College of Engineering'), findsOneWidget);
      expect(find.text('Bengaluru, Karnataka'), findsOneWidget);
    });

    testWidgets('Organisation lists the current roles only, filled with the one the line shows', (tester) async {
      final repo = await pump(tester);
      await tapKey(tester, 'profile.editIntro');
      expect(find.text('Organisation'), findsOneWidget);
      expect(find.text('Education'), findsWidgets);
      expect(
        find.descendant(of: find.byKey(const Key('intro.organisation')), matching: find.text('TechCorp')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byKey(const Key('intro.education')), matching: find.text('RV College of Engineering')),
        findsOneWidget,
      );

      await tapKey(tester, 'intro.organisation');
      expect(find.widgetWithText(ListTile, 'Please Select'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'TechCorp'), findsOneWidget);
      expect(
        find.descendant(of: find.byType(ListTile), matching: find.text('Lead Operations Manager')),
        findsOneWidget,
        reason: 'each company with its role under it',
      );
      expect(find.widgetWithText(ListTile, 'Global Infra Solutions'), findsNothing, reason: 'that role has ended');
      await choose(tester, 'Please Select');
      await save(tester);

      expect(find.text('Edit Intro'), findsNothing);
      expect(find.text('RV College of Engineering'), findsWidgets);
      expect(find.text('TechCorp · RV College of Engineering'), findsNothing);
      expect(repo.count('updateMe'), 0, reason: 'only the line changed, and it is kept on the phone');
      expect(find.text('Intro saved.'), findsOneWidget);

      await tapKey(tester, 'profile.editIntro');
      expect(
        find.descendant(of: find.byKey(const Key('intro.organisation')), matching: find.text('Please Select')),
        findsOneWidget,
        reason: 'the sheet opens on what was saved',
      );
    });

    testWidgets('with two current roles the newer is the default and the other can be chosen', (tester) async {
      final repo = DemoAccountRepository(
        experience: [
          ...demoExperience,
          const Experience(
            id: 'exp-3',
            title: 'Council Member',
            organisation: 'ICR Workplace Council',
            startYear: 2024,
            startMonth: 2,
            isCurrent: true,
          ),
        ],
      )..educationNow = const [rv, iim];
      await pump(tester, repo: repo);
      expect(find.text('ICR Workplace Council · IIM Bangalore'), findsOneWidget);

      await tapKey(tester, 'profile.editIntro');
      await tapKey(tester, 'intro.organisation');
      await choose(tester, 'TechCorp');
      await tapKey(tester, 'intro.education');
      expect(
        find.descendant(of: find.byType(ListTile), matching: find.text('B.E.')),
        findsOneWidget,
        reason: 'each school with its degree under it',
      );
      await choose(tester, 'RV College of Engineering');
      await save(tester);
      expect(find.text('TechCorp · RV College of Engineering'), findsOneWidget);
    });

    testWidgets('a pick makes the sheet dirty: Cancel asks to discard, and nothing changes', (tester) async {
      await pump(tester);
      await tapKey(tester, 'profile.editIntro');
      await tapKey(tester, 'intro.education');
      await choose(tester, 'Please Select');
      await tester.tap(find.byKey(const Key('sheet.cancel')));
      await tester.pumpAndSettle();
      expect(find.text('Discard Your Changes?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm.ok')));
      await tester.pumpAndSettle();
      expect(find.text('TechCorp · RV College of Engineering'), findsOneWidget);
    });

    testWidgets('with no current role and no education both lists are off and say what to add', (tester) async {
      final repo = DemoAccountRepository(experience: const [])..educationNow = const [];
      await pump(tester, repo: repo);
      await tapKey(tester, 'profile.editIntro');
      expect(find.text('Add your current role to show your company under your headline.'), findsOneWidget);
      expect(find.text('Add your education to show your school under your headline.'), findsOneWidget);
      await tapKey(tester, 'intro.organisation');
      expect(find.text('Please Select').evaluate().length, 2, reason: 'no list opened');
      expect(find.byType(ListTile), findsNothing);
    });

    testWidgets('Add New Position and Add New Education open their sheets over the intro', (tester) async {
      await pump(tester);
      await tapKey(tester, 'profile.editIntro');
      await tapKey(tester, 'intro.addPosition');
      expect(find.byType(ExperienceSheet), findsOneWidget);
      await tester.tap(find.byKey(const Key('sheet.cancel')).last);
      await tester.pumpAndSettle();
      expect(find.text('Edit Intro'), findsOneWidget);
      await tapKey(tester, 'intro.addEducation');
      expect(find.byType(EducationSheet), findsOneWidget);
    });

    testWidgets('Edit Contact Information opens the contact sheet', (tester) async {
      await pump(tester);
      await tapKey(tester, 'profile.editIntro');
      expect(find.text('Edit Contact Information'), findsOneWidget);
      await tapKey(tester, 'intro.contactInfo');
      expect(find.byType(ContactSheet), findsOneWidget);
    });

    testWidgets('the longer sheet fits a 320 x 568 phone', (tester) async {
      usePhone(tester, width: 320, height: 568);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: MyProfileScreen(repository: DemoAccountRepository(), now: DateTime.utc(2026, 10, 26)),
        ),
      );
      await tester.pumpAndSettle();
      await tapKey(tester, 'profile.editIntro');
      await tester.drag(find.byKey(const Key('intro.firstName')), const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
