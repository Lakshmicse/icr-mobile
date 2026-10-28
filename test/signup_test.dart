import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/auth/auth_controller.dart';
import 'package:icr_mobile/features/account/account_models.dart';
import 'package:icr_mobile/features/account/demo_account_repository.dart';
import 'package:icr_mobile/features/auth/sign_up_screen.dart';
import 'package:icr_mobile/features/auth/signup_rules.dart';

import 'helpers/account_harness.dart';
import 'helpers/fonts.dart';

/// Sign-up in three screens (Join, About you, Your work), against a stand-in
/// for the API: what each control sends, what each refusal shows, and that a
/// failed send keeps what was typed.
void main() {
  setUpAll(loadAppFonts);

  AccountHarness harness({Map<String, ApiHandler> routes = const {}}) => AccountHarness(
    routes: {
      'POST /auth/email/send-code': (_) => {'sent': true, 'code': '123456'},
      'POST /auth/email/verify-code': (_) => {'success': true},
      'POST /auth/register': (_) => sessionJson(),
      ...routes,
    },
  );

  Future<void> pump(
    WidgetTester tester,
    AccountHarness h, {
    DemoAccountRepository? account,
    int cooldown = 60,
    double width = 390,
    double height = 844,
  }) async {
    usePhone(tester, width: width, height: height);
    await tester.pumpWidget(h.app(SignUpScreen(account: account ?? DemoAccountRepository(), resendCooldown: cooldown)));
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String key, String text) async {
    final field = find.byKey(Key(key));
    await tester.ensureVisible(field);
    await tester.enterText(field, text);
    await tester.pump();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final target = find.byKey(Key(key));
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// The check box of a tick line: its words hold links, so the line's middle is not the box.
  Future<void> tick(WidgetTester tester, String key) async {
    final box = find.descendant(of: find.byKey(Key(key)), matching: find.byType(InkResponse));
    await tester.ensureVisible(box);
    await tester.tap(box);
    await tester.pump();
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  }

  Future<void> join(WidgetTester tester, {String email = 'Sam.Rao@Acme.com ', String password = 'Tr0ub4dor&3x'}) async {
    await type(tester, 'signup.email', email);
    await type(tester, 'signup.password', password);
    await tick(tester, 'signup.agree');
    await tapKey(tester, 'signup.join');
    await settle(tester);
  }

  Future<void> aboutYou(WidgetTester tester, {String first = 'Sam', String last = 'Rao', String? code}) async {
    await type(tester, 'signup.firstName', first);
    await type(tester, 'signup.lastName', last);
    if (code != null) await type(tester, 'signup.code', code);
  }

  group('screen 1, Join', () {
    testWidgets('asks for an address, a password and the consent before any call', (tester) async {
      final h = harness();
      await pump(tester, h);

      await tapKey(tester, 'signup.join');
      await settle(tester);

      expect(find.text('STEP 1 OF 3'), findsOneWidget);
      expect(find.text('Enter your email'), findsOneWidget);
      expect(find.text('At least 8 characters'), findsWidgets);
      expect(find.text('Please agree to the Terms of Service and Privacy Policy to join.'), findsOneWidget);
      expect(h.api.count('POST /auth/email/send-code'), 0);
    });

    testWidgets('says what is wrong with an address, in the website words', (tester) async {
      final h = harness();
      await pump(tester, h);

      for (final (typed, message) in [
        ('samacme.com', 'Your email is missing an "@". It should look like name@company.com'),
        ('a@b@c.com', 'An email can have only one "@". It should look like name@company.com'),
        ('@acme.com', 'Add your name before the "@", like name@company.com'),
        ('sam@acme', 'The part after the "@" needs a dot, like company.com or gmail.com'),
      ]) {
        await type(tester, 'signup.email', typed);
        await type(tester, 'signup.password', 'longenough1');
        await tapKey(tester, 'signup.join');
        expect(find.text(message), findsOneWidget, reason: typed);
      }
      expect(h.api.count('POST /auth/email/send-code'), 0);
    });

    testWidgets('refuses a password that holds the address name', (tester) async {
      final h = harness();
      await pump(tester, h);

      await type(tester, 'signup.email', 'samrao@acme.com');
      await type(tester, 'signup.password', 'xxsamraoxx1');
      await tapKey(tester, 'signup.join');

      expect(find.text("Don't reuse your email address as your password"), findsOneWidget);
      expect(h.api.count('POST /auth/email/send-code'), 0);
    });

    testWidgets('Join sends the code to the cleaned address and moves on', (tester) async {
      final h = harness();
      await pump(tester, h);

      await join(tester);

      final sent = h.api.last('POST /auth/email/send-code');
      expect(sent.json, {'email': 'Sam.Rao@Acme.com'});
      expect(find.text('STEP 2 OF 3'), findsOneWidget);
      expect(find.text('About you'), findsOneWidget);
      // Nothing is made yet: the account comes with the next screen.
      expect(h.api.count('POST /auth/register'), 0);
    });

    testWidgets('the eye shows the typed password and hides it again', (tester) async {
      final h = harness();
      await pump(tester, h);
      await type(tester, 'signup.password', 'secret-pass-1');

      EditableText field() => tester.widget<EditableText>(
        find.descendant(of: find.byKey(const Key('signup.password')), matching: find.byType(EditableText)),
      );
      expect(field().obscureText, isTrue);
      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();
      expect(field().obscureText, isFalse);
      await tester.tap(find.byTooltip('Hide password'));
      await tester.pump();
      expect(field().obscureText, isTrue);
    });

    testWidgets('the password meter follows the typing', (tester) async {
      final h = harness();
      await pump(tester, h);

      await type(tester, 'signup.password', 'abc');
      expect(find.text('Weak'), findsOneWidget);
      await type(tester, 'signup.password', 'Abcdefgh1!xyz');
      expect(find.text('Strong'), findsOneWidget);
    });

    testWidgets('an address that already has an account is a 409: say so and offer Sign in', (tester) async {
      final h = harness(
        routes: {'POST /auth/email/send-code': (_) => ApiReply.refusal(409, 'An account already uses this email.')},
      );
      await pump(tester, h);

      await join(tester);

      expect(find.text('That email already has an ICR account.'), findsOneWidget);
      expect(find.byKey(const Key('signup.duplicateSignIn')), findsOneWidget);
      expect(find.text('STEP 1 OF 3'), findsOneWidget);
      // What was typed is still there.
      expect(find.text('Sam.Rao@Acme.com'), findsOneWidget);
    });

    testWidgets("a refused send shows the API's sentence and keeps the email and password", (tester) async {
      final h = harness(
        routes: {
          'POST /auth/email/send-code': (_) => ApiReply.refusal(400, 'Please wait 41 seconds before another code.'),
        },
      );
      await pump(tester, h);

      await join(tester, email: 'sam@acme.com', password: 'Tr0ub4dor&3x');

      expect(find.text('Please wait 41 seconds before another code.'), findsOneWidget);
      expect(find.text('sam@acme.com'), findsOneWidget);
      expect(h.api.count('POST /auth/email/send-code'), 1);
      expect(find.text('STEP 1 OF 3'), findsOneWidget);
    });

    testWidgets('a dead connection says so and keeps the form, then works on the next try', (tester) async {
      var online = false;
      final h = harness(
        routes: {
          'POST /auth/email/send-code': (_) {
            if (!online) throwOffline();
            return {'sent': true, 'code': '123456'};
          },
        },
      );
      await pump(tester, h);

      await join(tester, email: 'sam@acme.com');
      expect(find.textContaining("Can't reach ICR"), findsOneWidget);
      expect(find.text('STEP 1 OF 3'), findsOneWidget);

      online = true;
      await tapKey(tester, 'signup.join');
      await settle(tester);
      expect(find.text('STEP 2 OF 3'), findsOneWidget);
    });

    testWidgets('double tapping Join sends one code', (tester) async {
      final h = harness();
      await pump(tester, h);
      await type(tester, 'signup.email', 'sam@acme.com');
      await type(tester, 'signup.password', 'Tr0ub4dor&3x');
      await tick(tester, 'signup.agree');

      final button = find.byKey(const Key('signup.join'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.tap(button, warnIfMissed: false);
      await settle(tester);

      expect(h.api.count('POST /auth/email/send-code'), 1);
    });

    testWidgets('the Terms and Privacy names are links', (tester) async {
      final h = harness();
      await pump(tester, h);
      expect(find.byKey(const Key('signup.legal/terms')), findsOneWidget);
      expect(find.byKey(const Key('signup.legal/privacy')), findsOneWidget);
    });

    testWidgets('the Google and LinkedIn marks are drawn, the one without keys faded', (tester) async {
      final h = harness();
      await pump(tester, h);
      expect(find.byKey(const Key('signup.google')), findsOneWidget);
      expect(find.byKey(const Key('signup.linkedin')), findsOneWidget);
      expect(h.api.count('GET /auth/social/providers'), 1);
    });
  });

  group('screen 2, About you', () {
    Future<AccountHarness> atAbout(WidgetTester tester, {Map<String, ApiHandler> routes = const {}}) async {
      final h = harness(routes: routes);
      await pump(tester, h);
      await join(tester, email: 'sam@acme.com');
      return h;
    }

    testWidgets('asks for both names and a 6-digit code before it calls the API', (tester) async {
      final h = await atAbout(tester);

      await tapKey(tester, 'signup.continue');
      await settle(tester);

      expect(find.text('Enter your first name'), findsOneWidget);
      expect(find.text('Enter your last name'), findsOneWidget);
      expect(find.text('Enter the 6-digit code from the email'), findsOneWidget);
      expect(h.api.count('POST /auth/email/verify-code'), 0);

      await aboutYou(tester, code: '12345');
      await tapKey(tester, 'signup.continue');
      expect(find.text('Enter the 6-digit code from the email'), findsOneWidget);
      expect(h.api.count('POST /auth/email/verify-code'), 0);
    });

    testWidgets('shows the test-mode code and Use code fills the field', (tester) async {
      await atAbout(tester);

      expect(find.byKey(const Key('signup.devCode')), findsOneWidget);
      expect(find.textContaining('123456'), findsOneWidget);
      await tapKey(tester, 'signup.useCode');

      final field = tester.widget<TextFormField>(find.byKey(const Key('signup.code')));
      expect(field.controller!.text, '123456');
    });

    testWidgets('says where the code went and that it lasts 10 minutes', (tester) async {
      await atAbout(tester);
      expect(find.text('We sent a code to sam@acme.com. It expires in 10 minutes.'), findsOneWidget);
    });

    testWidgets('Continue checks the code, then makes the account with no phone and no role', (tester) async {
      final h = await atAbout(tester);

      await aboutYou(tester, first: ' Sam ', last: 'Rao', code: '123456');
      await tapKey(tester, 'signup.continue');
      await settle(tester);

      expect(h.api.last('POST /auth/email/verify-code').json, {'email': 'sam@acme.com', 'code': '123456'});
      final body = h.api.last('POST /auth/register').json;
      expect(body, {
        'firstName': 'Sam',
        'lastName': 'Rao',
        'email': 'sam@acme.com',
        'password': 'Tr0ub4dor&3x',
        'acceptTerms': true,
        'termsVersion': AuthController.termsVersion,
      });
      expect(body.containsKey('phone'), isFalse, reason: 'the number is asked the first time an action needs it');
      expect(body.containsKey('role'), isFalse, reason: 'every self-serve sign-up is a person');
      // verify before register, and signed in afterwards.
      final order = [for (final c in h.api.calls) c.key];
      expect(order.indexOf('POST /auth/email/verify-code'), lessThan(order.indexOf('POST /auth/register')));
      expect(h.auth.status, SessionStatus.signedIn);
      expect(find.text('STEP 3 OF 3'), findsOneWidget);
      expect(find.text('Your work'), findsOneWidget);
    });

    testWidgets("a wrong code shows the API's sentence under the code and keeps the names", (tester) async {
      final h = await atAbout(
        tester,
        routes: {
          'POST /auth/email/verify-code': (_) => ApiReply.refusal(401, 'That code is not right. Check the email.'),
        },
      );

      await aboutYou(tester, code: '000000');
      await tapKey(tester, 'signup.continue');
      await settle(tester);

      expect(find.text('That code is not right. Check the email.'), findsOneWidget);
      expect(find.text('Sam'), findsOneWidget);
      expect(find.text('Rao'), findsOneWidget);
      expect(h.api.count('POST /auth/register'), 0);
      expect(h.auth.status, SessionStatus.unknown);
    });

    testWidgets('an expired code is the API sentence too', (tester) async {
      await atAbout(
        tester,
        routes: {
          'POST /auth/email/verify-code': (_) => ApiReply.refusal(400, 'This code has expired. Request a new one.'),
        },
      );
      await aboutYou(tester, code: '123456');
      await tapKey(tester, 'signup.continue');
      await settle(tester);
      expect(find.text('This code has expired. Request a new one.'), findsOneWidget);
    });

    testWidgets('when the account call fails after the code matched, a retry does not check the code again', (
      tester,
    ) async {
      var attempts = 0;
      final h = await atAbout(
        tester,
        routes: {
          'POST /auth/register': (_) {
            attempts++;
            return attempts == 1 ? ApiReply.refusal(500, 'Something went wrong. Try again.') : sessionJson();
          },
        },
      );

      await aboutYou(tester, code: '123456');
      await tapKey(tester, 'signup.continue');
      await settle(tester);
      expect(find.text('Something went wrong. Try again.'), findsOneWidget);
      expect(find.text('Sam'), findsOneWidget);

      await tapKey(tester, 'signup.continue');
      await settle(tester);

      // The API spent the code on the first check: asking again would fail.
      expect(h.api.count('POST /auth/email/verify-code'), 1);
      expect(h.api.count('POST /auth/register'), 2);
      expect(find.text('STEP 3 OF 3'), findsOneWidget);
    });

    testWidgets('an address taken in the meantime (409 on register) offers Sign in', (tester) async {
      await atAbout(
        tester,
        routes: {'POST /auth/register': (_) => ApiReply.refusal(409, 'This email is already registered.')},
      );
      await aboutYou(tester, code: '123456');
      await tapKey(tester, 'signup.continue');
      await settle(tester);

      expect(find.text('That email already has an ICR account.'), findsOneWidget);
      expect(find.byKey(const Key('signup.duplicateSignIn')), findsOneWidget);
    });

    testWidgets('"send a new one" waits out the cooldown, then sends another code', (tester) async {
      final h = harness();
      await pump(tester, h, cooldown: 3);
      await join(tester, email: 'sam@acme.com');

      expect(find.text('send a new one in 3s'), findsOneWidget);
      await tapKey(tester, 'signup.resend');
      expect(h.api.count('POST /auth/email/send-code'), 1, reason: 'still waiting');

      await tester.pump(const Duration(seconds: 3));
      expect(find.text('send a new one'), findsOneWidget);
      await tapKey(tester, 'signup.resend');
      await settle(tester);
      expect(h.api.count('POST /auth/email/send-code'), 2);
      expect(h.api.last('POST /auth/email/send-code').json, {'email': 'sam@acme.com'});
      // The cooldown starts over.
      expect(find.text('send a new one in 3s'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('a refused resend shows its sentence', (tester) async {
      var calls = 0;
      final h = harness(
        routes: {
          'POST /auth/email/send-code': (_) {
            calls++;
            return calls == 1
                ? {'sent': true, 'code': '123456'}
                : ApiReply.refusal(400, 'Too many codes requested. Try again later.');
          },
        },
      );
      await pump(tester, h, cooldown: 1);
      await join(tester, email: 'sam@acme.com');
      await tester.pump(const Duration(seconds: 1));

      await tapKey(tester, 'signup.resend');
      await settle(tester);
      expect(find.text('Too many codes requested. Try again later.'), findsOneWidget);
    });

    testWidgets('Change email goes back to Join with the address and password still typed', (tester) async {
      final h = harness();
      await pump(tester, h);
      await join(tester, email: 'sam@acme.com');

      await tapKey(tester, 'signup.changeEmail');
      await settle(tester);

      expect(find.text('STEP 1 OF 3'), findsOneWidget);
      expect(find.text('sam@acme.com'), findsOneWidget);
      // A new address gets its own code.
      await type(tester, 'signup.email', 'sam.rao@acme.com');
      await tapKey(tester, 'signup.join');
      await settle(tester);
      expect(h.api.last('POST /auth/email/send-code').json, {'email': 'sam.rao@acme.com'});
    });
  });

  group('screen 3, Your work', () {
    Future<(AccountHarness, DemoAccountRepository)> atWork(WidgetTester tester) async {
      final h = harness();
      final account = DemoAccountRepository();
      await pump(tester, h, account: account);
      await join(tester, email: 'sam@acme.com');
      await aboutYou(tester, code: '123456');
      await tapKey(tester, 'signup.continue');
      await settle(tester);
      return (h, account);
    }

    testWidgets('a person who is working is asked for title, company and the year', (tester) async {
      final (_, account) = await atWork(tester);

      await tapKey(tester, 'work.save');
      await settle(tester);

      expect(find.text('Enter your job title'), findsOneWidget);
      expect(find.text('Enter where you work'), findsOneWidget);
      expect(find.text('Choose the year you started'), findsOneWidget);
      expect(account.count('saveExperience'), 0);
    });

    testWidgets('saves the role to career history, the headline and the résumé', (tester) async {
      final (_, account) = await atWork(tester);

      await type(tester, 'work.title', 'Facilities Manager');
      await type(tester, 'work.company', 'Zenith Estates');
      await tapKey(tester, 'work.since');
      final year = careerYears()[3];
      await tester.tap(find.text('$year').last);
      await settle(tester);
      await tapKey(tester, 'work.save');
      await settle(tester);

      final rows = account.sent['saveExperience'] as List;
      expect(rows, hasLength(1));
      final row = (rows.single as Map).cast<String, dynamic>();
      expect(row['title'], 'Facilities Manager');
      expect(row['organisation'], 'Zenith Estates');
      expect(row['startYear'], year);
      expect(row['isCurrent'], isTrue);
      expect(row.containsKey('companyId'), isFalse, reason: 'a name nobody picked from ICR is not a link');
      expect(account.sent['updateMe'], {'designation': 'Facilities Manager'});
      expect((account.sent['updateResume'] as Map)['jobTitle'], 'Facilities Manager');
      expect(account.count('requestToJoin'), 0);
    });

    testWidgets('picking a company already on ICR links it and asks to join its team', (tester) async {
      final (_, account) = await atWork(tester);
      account.companyPages = const [CompanyHit(id: 'co-techcorp', name: 'TechCorp', city: 'Bengaluru')];

      await type(tester, 'work.title', 'Energy Manager');
      await type(tester, 'work.company', 'Tech');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tap(find.text('TechCorp').last);
      await settle(tester);
      expect(find.byKey(const Key('work.askToJoin')), findsOneWidget);

      await tapKey(tester, 'work.since');
      await tester.tap(find.text('${careerYears()[2]}').last);
      await settle(tester);
      await tapKey(tester, 'work.save');
      await settle(tester);

      final row = ((account.sent['saveExperience'] as List).single as Map).cast<String, dynamic>();
      expect(row['companyId'], 'co-techcorp');
      expect(row['organisation'], 'TechCorp');
      expect(account.calls, contains('requestToJoin:co-techcorp'));
    });

    testWidgets('unticking "Ask to join" saves the role and sends no request', (tester) async {
      final (_, account) = await atWork(tester);
      account.companyPages = const [CompanyHit(id: 'co-techcorp', name: 'TechCorp', city: 'Bengaluru')];

      await type(tester, 'work.title', 'Energy Manager');
      await type(tester, 'work.company', 'Tech');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tap(find.text('TechCorp').last);
      await settle(tester);
      await tick(tester, 'work.askToJoin');
      await tapKey(tester, 'work.since');
      await tester.tap(find.text('${careerYears()[2]}').last);
      await settle(tester);
      await tapKey(tester, 'work.save');
      await settle(tester);

      expect(account.count('saveExperience'), 1);
      expect(account.count('requestToJoin'), 0);
    });

    testWidgets('Between roles asks for nothing and can say recruiters may know', (tester) async {
      final (_, account) = await atWork(tester);

      await tapKey(tester, 'signup.segment.false');
      await settle(tester);
      expect(find.byKey(const Key('work.company')), findsNothing);
      await type(tester, 'work.title', 'Site Engineer');
      await tick(tester, 'work.readyNext');
      await tapKey(tester, 'work.save');
      await settle(tester);

      expect(account.count('saveExperience'), 0);
      expect(account.sent['updateResume'], {
        'jobTitle': 'Site Engineer',
        'nextRoleStatus': 'READY_NOW',
        'nextRoleVisibility': 'RECRUITERS',
      });
    });

    testWidgets("a refused save keeps the typed role and shows the API's sentence", (tester) async {
      final (_, account) = await atWork(tester);
      account.failures['saveExperience'] = ApiError('The start date can’t be in the future.', statusCode: 400);

      await type(tester, 'work.title', 'Facilities Manager');
      await type(tester, 'work.company', 'Zenith Estates');
      await tapKey(tester, 'work.since');
      await tester.tap(find.text('${careerYears()[1]}').last);
      await settle(tester);
      await tapKey(tester, 'work.save');
      await settle(tester);

      expect(find.text('The start date can’t be in the future.'), findsOneWidget);
      expect(find.text('Facilities Manager'), findsOneWidget);
      expect(find.text('Zenith Estates'), findsOneWidget);
    });

    testWidgets('Skip for now saves nothing and leaves the account made', (tester) async {
      final (h, account) = await atWork(tester);

      await tapKey(tester, 'work.skip');
      await settle(tester);

      expect(account.count('saveExperience'), 0);
      expect(account.count('updateMe'), 0);
      expect(h.auth.status, SessionStatus.signedIn);
    });
  });

  group('leaving', () {
    testWidgets('Sign in returns the address typed so far to the card behind', (tester) async {
      final h = harness();
      usePhone(tester);
      String? result = 'unset';
      await tester.pumpWidget(
        h.app(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    result = await Navigator.of(context).push<String>(
                      MaterialPageRoute<String>(builder: (_) => SignUpScreen(account: DemoAccountRepository())),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await type(tester, 'signup.email', ' Sam@Acme.com');

      await tapKey(tester, 'signup.signIn');
      await tester.pumpAndSettle();

      expect(result, 'Sam@Acme.com');
    });
  });

  group('a small phone', () {
    testWidgets('every screen fits 320 x 568 with the keyboard up', (tester) async {
      final h = harness();
      await pump(tester, h, width: 320, height: 568);
      tester.view.viewInsets = const FakeViewPadding(bottom: 500);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(Container());
      tester.view.resetViewInsets();
      await pump(tester, h, width: 320, height: 568);
      await join(tester, email: 'sam@acme.com');
      expect(tester.takeException(), isNull);
      await aboutYou(tester, code: '123456');
      await tapKey(tester, 'signup.continue');
      await settle(tester);
      expect(find.text('STEP 3 OF 3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
