import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/account/account_models.dart';
import 'package:icr_mobile/features/account/account_rules.dart';
import 'package:icr_mobile/features/account/demo_account_repository.dart';
import 'package:icr_mobile/features/account/phone/phone_field.dart';
import 'package:icr_mobile/features/account/phone/phone_sheets.dart';

import 'helpers/account_harness.dart';
import 'helpers/fonts.dart';

/// The mobile number an action needs, asked the first time something needs it:
/// the two-part phone field, the `askForPhone` sheet other features call, and
/// the controller + field for a form that wants the number inline.
void main() {
  setUpAll(loadAppFonts);

  MyProfile profile({String? phone}) => MyProfile.fromJson({
    'user': {'id': 'me', 'email': 'a@b.co', 'firstName': 'Anita', 'lastName': 'Rao', 'role': 'PROFESSIONAL', 'phone': ?phone},
  });

  group('the phone rules', () {
    test('splitPhone reads a stored number into its country and the digits after the code', () {
      expect(splitPhone('+919876543210').country?.country, 'India');
      expect(splitPhone('+919876543210').national, '9876543210');
      expect(splitPhone('9876543210').country?.dial, '91', reason: 'a bare Indian mobile reads as India');
      expect(splitPhone('+971501234567').country?.country, 'United Arab Emirates');
      expect(splitPhone('+971501234567').national, '501234567');
      expect(splitPhone('+3197012345678').country, isNull, reason: 'a country outside the list keeps the whole number');
      expect(splitPhone('+3197012345678').national, '+3197012345678');
      expect(splitPhone('').national, '');
    });

    test('joinPhone writes the number to store: the code, the digits, a trunk 0 dropped, a repeated code ignored', () {
      final uk = phoneCountries.firstWhere((c) => c.country == 'UK');
      final india = phoneCountries.first;
      expect(joinPhone(uk, '07700 900123'), '+447700900123');
      expect(joinPhone(uk, '+44 7700 900123'), '+447700900123');
      expect(joinPhone(india, '98765 43210'), '+919876543210');
      expect(joinPhone(india, '919876543210'), '+919876543210');
      expect(joinPhone(null, '+31 970 123 4567'), '+31 970 123 4567');
      expect(joinPhone(india, '  '), '');
    });
  });

  group('the phone field', () {
    Future<List<String>> pumpField(WidgetTester tester, {String value = ''}) async {
      final sent = <String>[];
      usePhone(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: AccountPhoneField(
                fieldKey: const Key('n'),
                countryKey: const Key('c'),
                label: 'Mobile number',
                value: value,
                onChanged: sent.add,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return sent;
    }

    testWidgets('starts on India; the digits typed come out as the number to store', (tester) async {
      final sent = await pumpField(tester);
      expect(find.text('+91'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('n')), '98765 43210');
      expect(sent.last, '+919876543210');
    });

    testWidgets('a stored number is split: the country button and the digits', (tester) async {
      await pumpField(tester, value: '+971501234567');
      expect(find.text('+971'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('n'))).controller!.text, '501234567');
    });

    testWidgets('choosing another country changes the code and keeps the digits', (tester) async {
      final sent = await pumpField(tester);
      await tester.enterText(find.byKey(const Key('n')), '7700900123');
      await tester.tap(find.byKey(const Key('c')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('accountPicker.search')), 'UK');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'UK  +44'));
      await tester.pumpAndSettle();
      expect(find.text('+44'), findsOneWidget);
      expect(sent.last, '+447700900123');
    });

    testWidgets('a full number pasted switches the country by itself', (tester) async {
      final sent = await pumpField(tester);
      await tester.enterText(find.byKey(const Key('n')), '+44 7700 900123');
      await tester.pump();
      expect(find.text('+44'), findsOneWidget);
      expect(sent.last, '+447700900123');
      expect(tester.widget<TextField>(find.byKey(const Key('n'))).controller!.text, '7700900123');
    });

    testWidgets('"Other country" takes the number with its code', (tester) async {
      final sent = await pumpField(tester);
      await tester.tap(find.byKey(const Key('c')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('accountPicker.search')), 'Other');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Other country'));
      await tester.pumpAndSettle();
      expect(find.text('Other'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('n')), '+31 970 1234567');
      expect(sent.last, '+31 970 1234567');
    });

    testWidgets('an error or a helper shows under it', (tester) async {
      usePhone(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: AccountPhoneField(label: 'Mobile', value: '', onChanged: (_) {}, error: 'Enter a 10-digit Indian mobile number.', helper: 'ignored'),
          ),
        ),
      );
      expect(find.text('Enter a 10-digit Indian mobile number.'), findsOneWidget);
      expect(find.text('ignored'), findsNothing);
    });
  });

  group('askForPhone', () {
    Future<void> pumpHost(WidgetTester tester, DemoAccountRepository repo, List<String?> results) async {
      usePhone(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('go'),
                  onPressed: () async => results.add(await askForPhone(context, repository: repo, reason: 'So the employer can call you.')),
                  child: const Text('Apply'),
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('a profile that has a number is never asked: nothing to send', (tester) async {
      final repo = DemoAccountRepository();
      final results = <String?>[];
      await pumpHost(tester, repo, results);
      await tester.tap(find.byKey(const Key('go')));
      await tester.pumpAndSettle();
      expect(results, ['']);
      expect(find.text('Add your mobile number'), findsNothing);
      expect(repo.calls, ['myProfile']);
    });

    testWidgets('with none, the sheet asks, says who needs it, and returns the number to send with the action', (tester) async {
      final repo = DemoAccountRepository(profile: profile());
      final results = <String?>[];
      await pumpHost(tester, repo, results);
      await tester.tap(find.byKey(const Key('go')));
      await tester.pumpAndSettle();
      expect(find.text('Add your mobile number'), findsOneWidget);
      expect(find.text('So the employer can call you.'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('phoneNeeded.number')), '98765 43210');
      await tester.pump();
      await tester.tap(find.byKey(const Key('sheet.save')));
      await tester.pumpAndSettle();
      expect(results, ['+919876543210']);
      expect(find.text('Add your mobile number'), findsNothing);
      expect(repo.count('updateMe'), 0, reason: 'the action saves it, with itself');
    });

    testWidgets('a missing or unreadable number is refused in the website\'s words and the sheet stays', (tester) async {
      final repo = DemoAccountRepository(profile: profile());
      final results = <String?>[];
      await pumpHost(tester, repo, results);
      await tester.tap(find.byKey(const Key('go')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sheet.save')));
      await tester.pumpAndSettle();
      expect(find.text('Add your mobile number.'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('phoneNeeded.number')), '12345');
      await tester.pump();
      await tester.tap(find.byKey(const Key('sheet.save')));
      await tester.pumpAndSettle();
      expect(find.text('Enter a 10-digit Indian mobile number.'), findsOneWidget);
      expect(results, isEmpty);
    });

    testWidgets('backing out returns null: the action must not run', (tester) async {
      final repo = DemoAccountRepository(profile: profile());
      final results = <String?>[];
      await pumpHost(tester, repo, results);
      await tester.tap(find.byKey(const Key('go')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sheet.cancel')));
      await tester.pumpAndSettle();
      expect(results, [null]);
    });

    testWidgets('when the profile cannot be read the number is asked for anyway', (tester) async {
      final repo = DemoAccountRepository()..failures['myProfile'] = ApiError('Offline.', statusCode: null);
      final results = <String?>[];
      await pumpHost(tester, repo, results);
      await tester.tap(find.byKey(const Key('go')));
      await tester.pumpAndSettle();
      expect(find.text('Add your mobile number'), findsOneWidget);
    });
  });

  group('inline in a form', () {
    testWidgets('PhoneNeededField shows only while the profile has no number; payload carries it with the action', (tester) async {
      final controller = PhoneNeededController(lookup: () async => null);
      await tester.runAsync(controller.load);
      usePhone(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(body: PhoneNeededField(controller: controller, reason: 'So your mentor can reach you.')),
        ),
      );
      expect(controller.needed, isTrue);
      expect(find.text('Mobile number *'), findsOneWidget);
      expect(find.textContaining('So your mentor can reach you.'), findsOneWidget);
      expect(controller.check(), isFalse);
      await tester.pump();
      expect(find.text('Add your mobile number.'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('phoneNeeded.number')), '9876543210');
      await tester.pump();
      expect(controller.check(), isTrue);
      expect(controller.payload, {'phone': '+919876543210'});
    });

    testWidgets('with a number on file the field is not drawn and nothing is sent', (tester) async {
      final controller = PhoneNeededController(lookup: () async => '+919812340000');
      await tester.runAsync(controller.load);
      usePhone(tester);
      await tester.pumpWidget(
        MaterialApp(theme: buildAppTheme(), home: Scaffold(body: PhoneNeededField(controller: controller, reason: 'x'))),
      );
      expect(controller.needed, isFalse);
      expect(find.byKey(const Key('phoneNeeded.number')), findsNothing);
      expect(controller.check(), isTrue);
      expect(controller.payload, isEmpty);
      expect(controller.onFile, '+919812340000');
    });
  });
}
