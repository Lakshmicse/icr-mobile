import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/auth/auth_controller.dart';
import 'package:icr_mobile/features/account/account_models.dart';
import 'package:icr_mobile/features/account/demo_account_repository.dart';
import 'package:icr_mobile/features/account/settings/notification_preferences_screen.dart';
import 'package:icr_mobile/features/account/settings/security_screen.dart';
import 'package:icr_mobile/features/account/settings/settings_screen.dart';
import 'package:icr_mobile/features/account/widgets/account_kit.dart' show CoverBand;

import 'helpers/account_harness.dart';
import 'helpers/fonts.dart';

/// Settings and what hangs off it: language, notification preferences, Sign-in &
/// security (email, mobile number and its code, contact info, password), the
/// data export, deleting the account and signing out.
FilledButton _saveButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.descendant(of: find.byKey(const Key('sheet.save')), matching: find.byType(FilledButton)));

void main() {
  setUpAll(() async {
    await loadAppFonts();
    CoverBand.loadArt = false;
  });

  late AccountHarness h;

  /// The settings screen inside the app's providers (a session, an API client).
  Future<void> pumpSettings(
    WidgetTester tester,
    DemoAccountRepository repo, {
    Map<String, dynamic>? user,
    List<String>? log,
    List<Uri>? opened,
    List<String>? shared,
  }) async {
    h = AccountHarness(routes: {'POST /auth/logout': (_) => {'success': true}});
    await h.signIn(tester, user ?? userJson(first: 'Nikhil', last: 'Majjagi', email: 'nikhil@techcorp.example'));
    usePhone(tester);
    await tester.pumpWidget(
      h.app(
        SettingsScreen(
          repository: repo,
          onOpenProfile: () => log?.add('profile'),
          onOpenCompanies: () => log?.add('companies'),
          onOpenSaved: () => log?.add('saved'),
          onContact: () => log?.add('contact'),
          opener: (context, uri) async => opened?.add(uri),
          share: (text, subject) async => shared?.add('$subject|$text'),
        ),
      ),
    );
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

  group('settings', () {
    testWidgets('shows the person and every group of rows', (tester) async {
      await pumpSettings(tester, DemoAccountRepository());
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Nikhil Majjagi'), findsOneWidget);
      expect(find.text('nikhil@techcorp.example'), findsOneWidget);
      for (final t in ['ACCOUNT', 'PREFERENCES', 'PRIVACY & DATA']) {
        expect(find.text(t), findsOneWidget);
      }
      for (final t in ['Sign-in & security', 'Your companies', 'Saved items', 'Language', 'Notifications', 'Download my data']) {
        expect(find.text(t), findsOneWidget);
      }
      expect(find.text('Acting as yourself'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
    });

    testWidgets('the row for companies names the company being acted for', (tester) async {
      final repo = DemoAccountRepository();
      repo.companiesNow = MyCompanies(
        personalRole: 'PROFESSIONAL',
        companies: [const MyCompany(companyId: 'co-1', name: 'TechCorp', role: 'COMPANY_ADMIN', active: true)],
      );
      await pumpSettings(tester, repo);
      expect(find.text('Acting for TechCorp'), findsOneWidget);
    });

    testWidgets('View profile, Your companies, Saved items and Contact us call out to the app', (tester) async {
      final log = <String>[];
      await pumpSettings(tester, DemoAccountRepository(), log: log);
      await tester.tap(find.byKey(const Key('settings.profile')));
      await tester.tap(find.byKey(const Key('settings.companies')));
      await tester.tap(find.byKey(const Key('settings.saved')));
      await tester.scrollUntilVisible(find.byKey(const Key('settings.contact')), 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.byKey(const Key('settings.contact')));
      expect(log, ['profile', 'companies', 'saved', 'contact']);
    });

    testWidgets('Terms and Privacy are the only rows that open the website', (tester) async {
      final opened = <Uri>[];
      await pumpSettings(tester, DemoAccountRepository(), opened: opened);
      await tester.scrollUntilVisible(find.byKey(const Key('settings.terms')), 200, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(find.byKey(const Key('settings.terms')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('settings.terms')));
      await tester.scrollUntilVisible(find.byKey(const Key('settings.privacy')), 200, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(find.byKey(const Key('settings.privacy')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('settings.privacy')));
      expect(opened.map((u) => u.toString()), ['https://icr.org.in/terms', 'https://icr.org.in/privacy']);
    });

    testWidgets('Sign-in & security and Notifications open their screens', (tester) async {
      await pumpSettings(tester, DemoAccountRepository());
      await tester.tap(find.byKey(const Key('settings.security')));
      await tester.pumpAndSettle();
      expect(find.text('Sign-in & security'), findsWidgets);
      expect(find.text('Contact info'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings.notifications')));
      await tester.pumpAndSettle();
      expect(find.text('Choose how ICR tells you about each kind of update: in the app, and by email.'), findsOneWidget);
    });

    testWidgets('Sign out asks first, then ends the session on this phone and at the API', (tester) async {
      await pumpSettings(tester, DemoAccountRepository());
      await tester.scrollUntilVisible(find.byKey(const Key('settings.signOut')), 200, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(find.byKey(const Key('settings.signOut')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('settings.signOut')));
      await tester.pumpAndSettle();
      expect(find.text('Sign out of ICR?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(h.auth.status, SessionStatus.signedIn);

      await tester.tap(find.byKey(const Key('settings.signOut')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm.ok')));
      await tester.pumpAndSettle();
      expect(h.auth.status, SessionStatus.signedOut);
      expect(h.api.count('POST /auth/logout'), 1);
    });
  });

  group('language', () {
    testWidgets('the row opens the languages; Hindi saves as the account\'s locale and the row says so', (tester) async {
      final repo = DemoAccountRepository();
      await pumpSettings(tester, repo);
      await tapKey(tester, 'settings.language');
      expect(find.text('The language of ICR’s emails, notifications and replies. The app’s screens stay in English for now.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('language.hi')));
      await tester.pump();
      await save(tester);
      expect(repo.sent['updateMe'], {'locale': 'hi'});
      expect(find.text('हिन्दी'), findsOneWidget);
      expect(find.text('Language saved.'), findsOneWidget);
    });

    testWidgets('English saves as none, so ICR follows the phone again', (tester) async {
      final repo = DemoAccountRepository()..localeNow = 'kn';
      await pumpSettings(tester, repo);
      expect(find.text('ಕನ್ನಡ'), findsOneWidget);
      await tapKey(tester, 'settings.language');
      await tester.tap(find.byKey(const Key('language.en')));
      await tester.pump();
      await save(tester);
      expect(repo.sent['updateMe'], {'locale': null});
      expect(find.text('English'), findsOneWidget);
    });

    testWidgets('Save with the same language closes without a call; a refusal stays open with its sentence', (tester) async {
      final repo = DemoAccountRepository();
      await pumpSettings(tester, repo);
      await tapKey(tester, 'settings.language');
      await save(tester);
      expect(repo.count('updateMe'), 0);

      repo.failures['updateMe'] = ApiError('That language is not available.', statusCode: 400);
      await tapKey(tester, 'settings.language');
      await tester.tap(find.byKey(const Key('language.kn')));
      await tester.pump();
      await save(tester);
      expect(find.text('That language is not available.'), findsOneWidget);
      expect(find.text('Language'), findsWidgets);
    });
  });

  group('privacy and data', () {
    testWidgets('Download my data reads the export, shows it, and Copy and Share send it', (tester) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      final repo = DemoAccountRepository();
      final shared = <String>[];
      await pumpSettings(tester, repo, shared: shared);
      await tester.scrollUntilVisible(find.byKey(const Key('settings.export')), 200, scrollable: find.byType(Scrollable).first);
      await tapKey(tester, 'settings.export');
      expect(find.byKey(const Key('export.preview')), findsNothing);
      await tapKey(tester, 'export.read');
      expect(repo.calls, contains('exportData'));
      expect(find.byKey(const Key('export.preview')), findsOneWidget);
      expect(find.textContaining('This is the personal data ICR holds for your account.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('export.copy')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(copied.single, contains('"email": "nikhil@techcorp.example"'));
      expect(find.text('Your data was copied.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('export.share')));
      await tester.pump();
      expect(shared.single, startsWith('My ICR data|{'));
    });

    testWidgets('a refused export says why', (tester) async {
      final repo = DemoAccountRepository()..failures['exportData'] = ApiError('Try again in a minute.', statusCode: 429);
      await pumpSettings(tester, repo);
      await tester.scrollUntilVisible(find.byKey(const Key('settings.export')), 200, scrollable: find.byType(Scrollable).first);
      await tapKey(tester, 'settings.export');
      await tapKey(tester, 'export.read');
      expect(find.text('Try again in a minute.'), findsOneWidget);
    });

    testWidgets('Delete my account needs the word DELETE, then closes the account and signs this phone out', (tester) async {
      final repo = DemoAccountRepository();
      await pumpSettings(tester, repo);
      await tester.scrollUntilVisible(find.byKey(const Key('settings.delete')), 200, scrollable: find.byType(Scrollable).first);
      await tapKey(tester, 'settings.delete');
      expect(find.textContaining('It cannot be undone.'), findsOneWidget);
      // Disabled until the word is typed.
      await type(tester, 'delete.word', 'delet');
      await tester.tap(find.byKey(const Key('sheet.save')));
      await tester.pumpAndSettle();
      expect(repo.count('deleteAccount'), 0);
      await type(tester, 'delete.word', 'delete');
      await save(tester);
      expect(repo.count('deleteAccount'), 1);
      expect(h.auth.status, SessionStatus.signedOut);
      expect(h.api.count('POST /auth/logout'), 0, reason: 'the API already ended every session');
    });

    testWidgets('a refused deletion keeps the sheet and the session', (tester) async {
      final repo = DemoAccountRepository()..failures['deleteAccount'] = ApiError('Close your company first.', statusCode: 400);
      await pumpSettings(tester, repo);
      await tester.scrollUntilVisible(find.byKey(const Key('settings.delete')), 200, scrollable: find.byType(Scrollable).first);
      await tapKey(tester, 'settings.delete');
      await type(tester, 'delete.word', 'DELETE');
      await save(tester);
      expect(find.text('Close your company first.'), findsOneWidget);
      expect(h.auth.status, SessionStatus.signedIn);
    });
  });

  group('notification preferences', () {
    Future<DemoAccountRepository> pumpPrefs(WidgetTester tester, {DemoAccountRepository? repo}) async {
      final r = repo ?? DemoAccountRepository();
      usePhone(tester);
      await tester.pumpWidget(AccountHarness().app(NotificationPreferencesScreen(repository: r)));
      await tester.pumpAndSettle();
      return r;
    }

    testWidgets('every kind of update has an in-app and an email switch, with its words', (tester) async {
      await pumpPrefs(tester);
      expect(find.text('Messages'), findsOneWidget);
      expect(find.text('New direct messages.'), findsOneWidget);
      expect(find.text('Jobs and applications'), findsOneWidget);
      expect(tester.widget<Switch>(find.byKey(const Key('pref.jobs.email'))).value, isTrue);
    });

    testWidgets('a switch saves at once with only its own row, and the screen shows what the API answered', (tester) async {
      final repo = await pumpPrefs(tester);
      await tester.tap(find.byKey(const Key('pref.jobs.email')));
      await tester.pumpAndSettle();
      expect(repo.sent['saveNotificationPreferences'], [
        {'category': 'jobs', 'inApp': true, 'email': false},
      ]);
      expect(tester.widget<Switch>(find.byKey(const Key('pref.jobs.email'))).value, isFalse);
      expect(tester.widget<Switch>(find.byKey(const Key('pref.jobs.inApp'))).value, isTrue);
    });

    testWidgets('receipts, support and security notices are always sent: their switches cannot be changed', (tester) async {
      await pumpPrefs(tester);
      await tester.scrollUntilVisible(find.byKey(const Key('pref.security.email')), 300, scrollable: find.byType(Scrollable).first);
      expect(tester.widget<Switch>(find.byKey(const Key('pref.security.email'))).onChanged, isNull);
      expect(tester.widget<Switch>(find.byKey(const Key('pref.payments.inApp'))).value, isTrue);
      expect(find.text('Always sent'), findsWidgets);
    });

    testWidgets('a refused change goes back and says why', (tester) async {
      final repo = DemoAccountRepository()..failures['saveNotificationPreferences'] = ApiError('Could not save.', statusCode: 500);
      await pumpPrefs(tester, repo: repo);
      await tester.tap(find.byKey(const Key('pref.messages.inApp')));
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(find.byKey(const Key('pref.messages.inApp'))).value, isTrue, reason: 'it went back');
      expect(find.text('Could not save.'), findsOneWidget);
      await tester.tap(find.byTooltip('Dismiss'));
      await tester.pump();
      expect(find.byKey(const Key('prefs.error')), findsNothing);
    });

    testWidgets('a failed read shows its sentence with Try again; pull to refresh reads again', (tester) async {
      final repo = DemoAccountRepository()..failures['notificationPreferences'] = ApiError('The server is busy.', statusCode: 503);
      await pumpPrefs(tester, repo: repo);
      expect(find.text('The server is busy.'), findsOneWidget);
      repo.failures.clear();
      await tester.tap(find.byKey(const Key('account.retry')));
      await tester.pumpAndSettle();
      expect(find.text('Messages'), findsOneWidget);
      await tester.fling(find.byType(ListView).first, const Offset(0, 400), 1000);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(repo.count('notificationPreferences'), 3);
    });
  });

  group('sign-in & security', () {
    Future<DemoAccountRepository> pumpSecurity(
      WidgetTester tester, {
      DemoAccountRepository? repo,
      bool confirmed = true,
    }) async {
      final r = repo ?? DemoAccountRepository();
      h = AccountHarness();
      await h.signIn(tester, userJson(email: 'nikhil@techcorp.example', emailVerified: confirmed));
      usePhone(tester);
      await tester.pumpWidget(h.app(SignInSecurityScreen(repository: r)));
      await tester.pumpAndSettle();
      return r;
    }

    testWidgets('the email with its confirmation, the verified mobile number and the LinkedIn link', (tester) async {
      await pumpSecurity(tester);
      expect(find.text('nikhil@techcorp.example'), findsOneWidget);
      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.text('+91 9876543210'), findsOneWidget);
      expect(find.text('India'), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);
      expect(find.text('linkedin.com/in/nikhil-majjagi'), findsOneWidget);
      expect(find.byKey(const Key('security.confirmEmail')), findsNothing);
    });

    testWidgets('an email that was never confirmed offers Confirm, which opens the confirmation', (tester) async {
      await pumpSecurity(tester, confirmed: false);
      expect(find.text('Not confirmed'), findsOneWidget);
      await tester.tap(find.byKey(const Key('security.confirmEmail')));
      await tester.pumpAndSettle();
      expect(find.text('Confirm your email'), findsOneWidget);
    });

    testWidgets('Change password sends the reset link to the account\'s own address, fixed', (tester) async {
      await pumpSecurity(tester);
      await tester.tap(find.byKey(const Key('security.changePassword')));
      await tester.pumpAndSettle();
      expect(find.text('Change your password'), findsOneWidget);
      expect(tester.widget<TextFormField>(find.byKey(const Key('forgot.email'))).enabled, isFalse);
      expect(find.text('nikhil@techcorp.example'), findsWidgets);
    });

    testWidgets('a number with no code to confirm it is not marked "Not verified"; an Indian one that is, offers Verify', (tester) async {
      final repo = DemoAccountRepository(
        profile: MyProfile.fromJson({
          'user': {'id': 'me', 'email': 'a@b.co', 'firstName': 'A', 'lastName': 'B', 'role': 'PROFESSIONAL', 'phone': '+447700900123', 'phoneVerified': false},
        }),
      );
      await pumpSecurity(tester, repo: repo);
      expect(find.text('+44 7700900123'), findsOneWidget);
      expect(find.text('Not verified'), findsNothing);
      expect(find.text('Edit'), findsOneWidget);

      repo.profileNow = MyProfile.fromJson({
        'user': {'id': 'me', 'email': 'a@b.co', 'firstName': 'A', 'lastName': 'B', 'role': 'PROFESSIONAL', 'phone': '+919812340000', 'phoneVerified': false},
      });
      await tester.fling(find.byType(ListView).first, const Offset(0, 400), 1000);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.text('Not verified'), findsOneWidget);
      expect(find.text('Verify'), findsOneWidget);
    });

    testWidgets('a read that fails shows its sentence with Try again', (tester) async {
      final repo = DemoAccountRepository()..failures['myProfile'] = ApiError('The server is busy.', statusCode: 503);
      await pumpSecurity(tester, repo: repo);
      expect(find.text('The server is busy.'), findsOneWidget);
      repo.failures.clear();
      await tester.tap(find.byKey(const Key('account.retry')));
      await tester.pumpAndSettle();
      expect(find.text('Mobile number'), findsOneWidget);
    });

    group('the mobile number', () {
      DemoAccountRepository noPhone() => DemoAccountRepository(
        profile: MyProfile.fromJson({
          'user': {'id': 'me', 'email': 'a@b.co', 'firstName': 'A', 'lastName': 'B', 'role': 'PROFESSIONAL'},
        }),
      );

      testWidgets('Add: an Indian number is confirmed with a code; the test code is shown and Use code fills it', (tester) async {
        final repo = await pumpSecurity(tester, repo: noPhone());
        expect(find.text('Not added'), findsOneWidget);
        await tapKey(tester, 'security.phone');
        expect(find.text('Mobile number'), findsWidgets);
        await type(tester, 'phone.number', '98765 43210');
        expect(find.text('Send code'), findsOneWidget);
        await save(tester);
        expect(repo.calls, contains('sendPhoneCode:+919876543210'));
        expect(find.text('Test mode: your code is 246810.'), findsOneWidget);
        expect(find.text('We sent a code to +91 9876543210.'), findsOneWidget);

        await tester.tap(find.byKey(const Key('testCode.use')));
        await tester.pump();
        expect(tester.widget<TextField>(find.byKey(const Key('phone.code'))).controller!.text, '246810');
        await save(tester);
        expect(repo.calls, contains('verifyPhoneCode:+919876543210'));
        expect(repo.profileNow.phoneVerified, isTrue);
        expect(find.text('Mobile number saved.'), findsOneWidget);
        expect(find.text('+91 9876543210'), findsOneWidget);
        expect(find.text('Verified'), findsOneWidget);
      });

      testWidgets('a wrong code is the API\'s sentence under the code, and the sheet stays', (tester) async {
        final repo = await pumpSecurity(tester, repo: noPhone());
        await tapKey(tester, 'security.phone');
        await type(tester, 'phone.number', '9876543210');
        await save(tester);
        await type(tester, 'phone.code', '111111');
        await save(tester);
        expect(find.text('Invalid code. Please try again.'), findsOneWidget);
        expect(repo.profileNow.phoneVerified, isFalse);
        // A short code is refused before any call.
        await type(tester, 'phone.code', '12');
        expect(_saveButton(tester).onPressed, isNull, reason: 'Verify waits for six digits');
      });

      testWidgets('Send a new code asks again; changing the number goes back to Send code', (tester) async {
        final repo = await pumpSecurity(tester, repo: noPhone());
        await tapKey(tester, 'security.phone');
        await type(tester, 'phone.number', '9876543210');
        await save(tester);
        await tapKey(tester, 'phone.resend');
        expect(repo.count('sendPhoneCode'), 2);
        await type(tester, 'phone.number', '9876543211');
        expect(find.byKey(const Key('phone.code')), findsNothing);
        expect(find.text('Send code'), findsOneWidget);
      });

      testWidgets('a number typed wrongly is refused with the website\'s words, before any call', (tester) async {
        final repo = await pumpSecurity(tester, repo: noPhone());
        await tapKey(tester, 'security.phone');
        await type(tester, 'phone.number', '12345');
        expect(find.text('Enter a 10-digit Indian mobile number.'), findsOneWidget);
        expect(_saveButton(tester).onPressed, isNull, reason: 'Send code is off');
        expect(repo.count('sendPhoneCode'), 0);
      });

      testWidgets('another country\'s number cannot be texted: Save number keeps it as typed', (tester) async {
        final repo = await pumpSecurity(tester, repo: noPhone());
        await tapKey(tester, 'security.phone');
        await tester.tap(find.byKey(const Key('phone.country')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('accountPicker.search')), 'United Arab');
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ListTile, 'United Arab Emirates  +971'));
        await tester.pumpAndSettle();
        await type(tester, 'phone.number', '501234567');
        expect(find.text('Save number'), findsOneWidget);
        expect(find.text('We can only text codes to +91 numbers, so this one is saved as typed.'), findsOneWidget);
        await save(tester);
        expect(repo.sent['updateMe'], {'phone': '+971501234567'});
        expect(repo.count('sendPhoneCode'), 0);
        expect(find.text('Not verified'), findsNothing);
      });

      testWidgets('Remove number asks first, then clears it', (tester) async {
        final repo = await pumpSecurity(tester);
        await tapKey(tester, 'security.phone');
        await tester.tap(find.byKey(const Key('sheet.delete')));
        await tester.pumpAndSettle();
        expect(find.text('Remove your number?'), findsOneWidget);
        await tester.tap(find.byKey(const Key('confirm.ok')));
        await tester.pumpAndSettle();
        expect(repo.sent['updateMe'], {'phone': ''});
        expect(find.text('Not added'), findsOneWidget);
      });

      testWidgets('a verified number shows as verified in its sheet and cannot be re-verified until it changes', (tester) async {
        await pumpSecurity(tester);
        await tapKey(tester, 'security.phone');
        expect(find.text('This number is verified.'), findsOneWidget);
        expect(find.text('Verified'), findsWidgets);
        expect(_saveButton(tester).onPressed, isNull);
      });
    });

    group('contact info', () {
      testWidgets('the work email, a second number and links are saved together; a link gets https://', (tester) async {
        final repo = await pumpSecurity(tester);
        await tapKey(tester, 'security.editContact');
        expect(find.text('Contact info'), findsWidgets);
        await type(tester, 'contact.workEmail', 'nikhil@work.example.com');
        await type(tester, 'contact.githubUrl', 'github.com/nikhil');
        await save(tester);
        expect(repo.sent['saveLinks'], {
          'linkedinUrl': 'https://linkedin.com/in/nikhil-majjagi',
          'websiteUrl': '',
          'twitterUrl': '',
          'githubUrl': 'https://github.com/nikhil',
          'portfolioUrl': '',
        });
        expect(repo.sent['updateMe'], {'workEmail': 'nikhil@work.example.com'});
        expect(find.text('Contact info saved.'), findsOneWidget);
        expect(find.text('nikhil@work.example.com'), findsOneWidget);
        expect(find.text('github.com/nikhil'), findsOneWidget);
      });

      testWidgets('a blank field clears it; Save with nothing changed closes without a call', (tester) async {
        final repo = DemoAccountRepository(
          profile: MyProfile.fromJson({
            'user': {'id': 'me', 'email': 'a@b.co', 'firstName': 'A', 'lastName': 'B', 'role': 'PROFESSIONAL', 'workEmail': 'old@work.example.com', 'altPhone': '+919800000000'},
          }),
        );
        await pumpSecurity(tester, repo: repo);
        await tapKey(tester, 'security.editContact');
        await save(tester);
        expect(repo.count('updateMe'), 0);
        expect(repo.count('saveLinks'), 0);

        await tester.tap(find.byKey(const Key('security.editContact')));
        await tester.pumpAndSettle();
        await type(tester, 'contact.workEmail', '');
        await save(tester);
        expect(repo.sent['updateMe'], {'workEmail': null});
      });

      testWidgets('what the API refuses is refused here first, in the same words, and nothing is sent', (tester) async {
        final repo = await pumpSecurity(tester);
        await tapKey(tester, 'security.editContact');
        await type(tester, 'contact.workEmail', 'not-an-email');
        await type(tester, 'contact.websiteUrl', 'not a web address');
        await type(tester, 'contact.linkedinUrl', 'https://example.com/me');
        await tester.tap(find.byKey(const Key('sheet.save')));
        await tester.pumpAndSettle();
        expect(find.text('Enter a valid email address, like name@company.com.'), findsOneWidget);
        expect(find.text('Enter a full web address, like https://yourname.com'), findsOneWidget);
        expect(find.text('Enter your LinkedIn profile address, like https://linkedin.com/in/your-name'), findsOneWidget);
        expect(repo.count('saveLinks'), 0);
        expect(repo.count('updateMe'), 0);
      });

      testWidgets('the API\'s refusal of a link shows above the buttons and keeps what was typed', (tester) async {
        final repo = await pumpSecurity(tester);
        repo.failures['saveLinks'] = ApiError('That address is not reachable.', statusCode: 400);
        await tapKey(tester, 'security.editContact');
        await type(tester, 'contact.githubUrl', 'https://github.com/nikhil');
        await save(tester);
        expect(find.text('That address is not reachable.'), findsOneWidget);
        expect(tester.widget<TextField>(find.byKey(const Key('contact.githubUrl'))).controller!.text, 'https://github.com/nikhil');
        expect(repo.count('updateMe'), 0, reason: 'the links go first; a refusal there writes nothing else');
      });
    });
  });
}
