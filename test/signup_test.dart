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
      'POST /auth/phone/send-otp': (_) => {'sent': true, 'code': '654321'},
      'POST /auth/phone/verify-otp': (_) => {'success': true},
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

  /// The number defaults to a British one: saved as typed, no OTP (the Indian path has its own tests).
  Future<void> aboutYou(
    WidgetTester tester, {
    String first = 'Sam',
    String last = 'Rao',
    String? phone = '+44 7700 900123',
    String? code,
  }) async {
    await type(tester, 'signup.firstName', first);
    await type(tester, 'signup.lastName', last);
    if (phone != null) await type(tester, 'signup.phone', phone);
    if (code != null) await type(tester, 'signup.code', code);
  }

  group('screen 1, Join', () {
    testWidgets('asks for an address, a password and the consent before any call', (tester) async {
      final h = harness();
      await pump(tester, h);

      await tapKey(tester, 'signup.join');
      await settle(tester);

      expect(find.text('STEP 1 OF 3'), findsOneWidget);
      expect(find.text('Enter your email.'), findsOneWidget);
      expect(find.text('Use at least 8 characters.'), findsOneWidget);
      expect(find.text('Agree to the Terms of Service and Privacy Policy to join.'), findsOneWidget);
      expect(h.api.count('POST /auth/email/send-code'), 0);
    });

    testWidgets('says what is wrong with an address, a reason for each', (tester) async {
      final h = harness();
      await pump(tester, h);

      for (final (typed, message) in [
        ('samacme.com', 'Your email is missing an "@". It should look like name@company.com.'),
        ('a@b@c.com', 'An email can have only one "@". It should look like name@company.com.'),
        ('@acme.com', 'Add your name before the "@", like name@company.com.'),
        ('sam@acme', 'The part after the "@" needs a dot, like company.com or gmail.com.'),
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

      expect(find.text('Do not use your email address as your password.'), findsOneWidget);
      expect(h.api.count('POST /auth/email/send-code'), 0);
    });

    testWidgets('Join sends the code to the cleaned address and moves on', (tester) async {
      final h = harness();
      await pump(tester, h);

      await join(tester);

      final sent = h.api.last('POST /auth/email/send-code');
      expect(sent.json, {'email': 'Sam.Rao@Acme.com'});
      expect(find.text('STEP 2 OF 3'), findsOneWidget);
      expect(find.text('About You'), findsOneWidget);
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
      await tester.tap(find.byTooltip('Show Password'));
      await tester.pump();
      expect(field().obscureText, isFalse);
      await tester.tap(find.byTooltip('Hide Password'));
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

    testWidgets('an address that already has an account is a 409: say so and offer Sign In', (tester) async {
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

    testWidgets('the Google and LinkedIn pills sit under Join, headed "Sign Up Using"; the one without keys is faded', (
      tester,
    ) async {
      final h = harness();
      await pump(tester, h);
      // Owner, 12 Nov 2026: the marks moved from the top of the card to under the form, with their names.
      expect(find.text('Sign Up Using'), findsOneWidget);
      expect(find.text('OR'), findsNothing);
      final join = tester.getRect(find.byKey(const Key('signup.join')));
      final linkedin = tester.getRect(find.byKey(const Key('signup.linkedin')));
      final google = tester.getRect(find.byKey(const Key('signup.google')));
      expect(tester.getRect(find.text('Sign Up Using')).top, greaterThan(join.bottom));
      expect(linkedin.top, greaterThan(join.bottom));
      expect(linkedin.top, google.top, reason: 'side by side on a 390 dp phone');
      expect(google.left, greaterThan(linkedin.right));
      expect(find.text('LinkedIn'), findsOneWidget);
      expect(find.text('Google'), findsOneWidget);
      expect(tester.getRect(find.byKey(const Key('signup.signIn'))).top, greaterThan(google.bottom));
      // Both have keys on this server, so both are drawn, neither faded.
      double opacityOf(String key) => tester
          .widget<Opacity>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(Opacity)).first)
          .opacity;
      expect(opacityOf('signup.google'), 1);
      expect(opacityOf('signup.linkedin'), 1);
      expect(h.api.count('GET /auth/social/providers'), 1);
    });

    testWidgets('a provider the server does not offer is not drawn', (tester) async {
      // Owner, 13 Nov 2026: hide what the server has no keys for (the dev site has none).
      final one = harness(
        routes: {
          'GET /auth/social/providers': (_) => {
            'providers': ['GOOGLE'],
          },
        },
      );
      await pump(tester, one);
      expect(find.text('Sign Up Using'), findsOneWidget);
      expect(find.byKey(const Key('signup.google')), findsOneWidget);
      expect(find.byKey(const Key('signup.linkedin')), findsNothing);
    });

    testWidgets('a server that offers no provider shows no provider row', (tester) async {
      final none = harness(
        routes: {
          'GET /auth/social/providers': (_) => {'providers': <String>[]},
        },
      );
      await pump(tester, none);
      expect(find.text('Sign Up Using'), findsNothing);
      expect(find.byKey(const Key('signup.google')), findsNothing);
      expect(find.byKey(const Key('signup.linkedin')), findsNothing);
      expect(find.byKey(const Key('signup.join')), findsOneWidget);
    });
  });

  group('screen 2, About You', () {
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

      expect(find.text('Enter your first name.'), findsOneWidget);
      expect(find.text('Enter your last name.'), findsOneWidget);
      expect(find.text('Enter the 6-digit code from your email.'), findsOneWidget);
      expect(h.api.count('POST /auth/email/verify-code'), 0);

      await aboutYou(tester, code: '12345');
      await tapKey(tester, 'signup.continue');
      expect(find.text('Enter the 6-digit code from your email.'), findsOneWidget);
      expect(h.api.count('POST /auth/email/verify-code'), 0);
    });

    testWidgets('shows the test-mode code and Use Code fills the field', (tester) async {
      await atAbout(tester);

      expect(find.byKey(const Key('signup.devCode')), findsOneWidget);
      expect(find.textContaining('123456'), findsOneWidget);
      await tapKey(tester, 'signup.useCode');

      final field = tester.widget<TextFormField>(find.byKey(const Key('signup.code')));
      expect(field.controller!.text, '123456');
    });

    testWidgets(
      'the code field is "Email Verification Code"; under it, where the code went and that it lasts 10 minutes',
      (tester) async {
        await atAbout(tester);
        expect(find.text('Email Verification Code'), findsOneWidget);
        expect(find.text('Code sent to sam@acme.com. It expires in 10 minutes.'), findsOneWidget);
        // The client's words (13 Nov 2026) for the rest of the screen's labels.
        for (final label in ['First Name', 'Last Name', 'Mobile Number', 'Change Email']) {
          expect(find.text(label), findsOneWidget, reason: label);
        }
      },
    );

    testWidgets('Continue checks the code, then makes the account with the number and no role', (tester) async {
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
        // Required by the API since 29 Oct 2026; a British number is saved as typed, with no OTP.
        'phone': '+447700900123',
        'acceptTerms': true,
        'termsVersion': AuthController.termsVersion,
      });
      expect(h.api.calls.where((c) => c.key == 'POST /auth/phone/send-otp'), isEmpty, reason: 'no OTP outside India');
      expect(body.containsKey('role'), isFalse, reason: 'every self-serve sign-up is a person');
      // verify before register, and signed in afterwards.
      final order = [for (final c in h.api.calls) c.key];
      expect(order.indexOf('POST /auth/email/verify-code'), lessThan(order.indexOf('POST /auth/register')));
      expect(h.auth.status, SessionStatus.signedIn);
      expect(find.text('STEP 3 OF 3'), findsOneWidget);
      expect(find.text('Your Work'), findsOneWidget);
    });

    testWidgets('an Indian number is proven with its texted OTP before the account is made', (tester) async {
      final h = await atAbout(tester);
      await aboutYou(tester, phone: '98765 43210', code: '123456');

      // Continue before the OTP: asked to send it first; nothing is made.
      await tapKey(tester, 'signup.continue');
      await settle(tester);
      expect(find.text('Send the OTP to your mobile number first.'), findsOneWidget);
      expect(h.api.calls.where((c) => c.key == 'POST /auth/register'), isEmpty);

      await tapKey(tester, 'signup.sendOtp');
      await settle(tester);
      expect(h.api.last('POST /auth/phone/send-otp').json, {'phone': '+919876543210'});
      expect(find.text('OTP sent to 98765 43210.'), findsOneWidget);
      // Off production the API hands the OTP back; the note shows it and Use code fills the field (the phone's
      // note comes before the email code's).
      expect(find.textContaining('654321'), findsOneWidget);
      await tester.tap(find.text('Use Code').first);
      await tester.pump();
      expect(tester.widget<TextFormField>(find.byKey(const Key('signup.phoneCode'))).controller!.text, '654321');

      await tapKey(tester, 'signup.continue');
      await settle(tester);
      expect(h.api.last('POST /auth/phone/verify-otp').json, {'phone': '+919876543210', 'code': '654321'});
      expect(h.api.last('POST /auth/register').json['phone'], '+919876543210');
      final order = [for (final c in h.api.calls) c.key];
      expect(order.indexOf('POST /auth/phone/verify-otp'), lessThan(order.indexOf('POST /auth/email/verify-code')));
      expect(order.indexOf('POST /auth/email/verify-code'), lessThan(order.indexOf('POST /auth/register')));
      expect(h.auth.status, SessionStatus.signedIn);
    });

    testWidgets("a wrong OTP shows the API's sentence under it and nothing is made", (tester) async {
      final h = await atAbout(
        tester,
        routes: {'POST /auth/phone/verify-otp': (_) => ApiReply.refusal(401, 'Invalid OTP. Please try again.')},
      );
      await aboutYou(tester, phone: '98765 43210', code: '123456');
      await tapKey(tester, 'signup.sendOtp');
      await settle(tester);
      await type(tester, 'signup.phoneCode', '111111');
      await tapKey(tester, 'signup.continue');
      await settle(tester);
      expect(find.text('Invalid OTP. Please try again.'), findsOneWidget);
      expect(h.api.calls.where((c) => c.key == 'POST /auth/email/verify-code'), isEmpty);
      expect(h.api.calls.where((c) => c.key == 'POST /auth/register'), isEmpty);
      expect(find.byKey(const Key('signup.phoneCode')), findsOneWidget, reason: 'the OTP field stays for another try');
    });

    testWidgets('a number the API would refuse, or none, is said before any call', (tester) async {
      final h = await atAbout(tester);
      await aboutYou(tester, phone: null, code: '123456');
      await tapKey(tester, 'signup.continue');
      await settle(tester);
      expect(find.text('Enter your mobile number.'), findsOneWidget);
      await type(tester, 'signup.phone', '12345');
      await tapKey(tester, 'signup.continue');
      await settle(tester);
      expect(find.text('Enter your mobile number.'), findsNothing);
      expect(find.byKey(const Key('signup.phone')), findsOneWidget);
      expect(h.api.calls.where((c) => c.key == 'POST /auth/register'), isEmpty);
      expect(h.api.calls.where((c) => c.key == 'POST /auth/phone/send-otp'), isEmpty);
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

    testWidgets('an address taken in the meantime (409 on register) offers Sign In', (tester) async {
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

    testWidgets('"Resend Code" waits out the cooldown, then sends another code', (tester) async {
      final h = harness();
      await pump(tester, h, cooldown: 3);
      await join(tester, email: 'sam@acme.com');

      expect(find.text('Resend in 3s'), findsOneWidget);
      await tapKey(tester, 'signup.resend');
      expect(h.api.count('POST /auth/email/send-code'), 1, reason: 'still waiting');

      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Resend Code'), findsOneWidget);
      await tapKey(tester, 'signup.resend');
      await settle(tester);
      expect(h.api.count('POST /auth/email/send-code'), 2);
      expect(h.api.last('POST /auth/email/send-code').json, {'email': 'sam@acme.com'});
      // The cooldown starts over.
      expect(find.text('Resend in 3s'), findsOneWidget);
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

    testWidgets('Change Email goes back to Join with the address and password still typed', (tester) async {
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

  group('screen 3, Your Work', () {
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

    /// Picks Pune in the city sheet (required on this screen since 13 Nov 2026).
    Future<void> pickCity(WidgetTester tester) async {
      await tapKey(tester, 'work.city');
      await settle(tester);
      await tester.tap(find.text('Pune').last);
      await settle(tester);
    }

    testWidgets('a person who is working is asked for title, company, the year and the city', (tester) async {
      final (_, account) = await atWork(tester);

      // The client's words (13 Nov 2026): title case, and City is no longer optional.
      for (final label in ['I’m Working', 'Between Roles', 'Job Title', 'Company', 'Since', 'City', 'Skip for Now']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.textContaining('optional'), findsNothing);

      await tapKey(tester, 'work.save');
      await settle(tester);

      expect(find.text('Enter your job title.'), findsOneWidget);
      expect(find.text('Enter your company.'), findsOneWidget);
      expect(find.text('Select the year you started.'), findsOneWidget);
      expect(find.text('Select your city.'), findsOneWidget);
      expect(account.count('saveExperience'), 0);
    });

    testWidgets('Continue asks for the city when everything else is filled in, and saves once it is picked', (
      tester,
    ) async {
      final (_, account) = await atWork(tester);

      await type(tester, 'work.title', 'Facilities Manager');
      await type(tester, 'work.company', 'Zenith Estates');
      await tapKey(tester, 'work.since');
      await tester.tap(find.text('${careerYears()[3]}').last);
      await settle(tester);
      await tapKey(tester, 'work.save');
      await settle(tester);

      expect(find.text('Select your city.'), findsOneWidget);
      expect(account.count('saveExperience'), 0);
      expect(account.count('updateResume'), 0);

      await pickCity(tester);
      expect(find.text('Select your city.'), findsNothing, reason: 'picking one clears the problem');
      expect(find.text('Pune, Maharashtra'), findsOneWidget);
      await tapKey(tester, 'work.save');
      await settle(tester);

      final row = ((account.sent['saveExperience'] as List).single as Map).cast<String, dynamic>();
      expect(row['city'], 'Pune');
      expect((account.sent['updateResume'] as Map)['location'], 'Pune, Maharashtra');
    });

    testWidgets('saves the role to career history, the headline and the résumé', (tester) async {
      final (_, account) = await atWork(tester);

      await type(tester, 'work.title', 'Facilities Manager');
      await type(tester, 'work.company', 'Zenith Estates');
      await tapKey(tester, 'work.since');
      final year = careerYears()[3];
      await tester.tap(find.text('$year').last);
      await settle(tester);
      await pickCity(tester);
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
      await pickCity(tester);
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
      await pickCity(tester);
      await tapKey(tester, 'work.save');
      await settle(tester);

      expect(account.count('saveExperience'), 1);
      expect(account.count('requestToJoin'), 0);
    });

    testWidgets('Between Roles asks only for the city and can say recruiters may know', (tester) async {
      final (_, account) = await atWork(tester);

      await tapKey(tester, 'signup.segment.false');
      await settle(tester);
      expect(find.byKey(const Key('work.company')), findsNothing);
      expect(find.text('Most Recent Job Title (Optional)'), findsOneWidget);
      await type(tester, 'work.title', 'Site Engineer');
      await tick(tester, 'work.readyNext');
      await tapKey(tester, 'work.save');
      await settle(tester);

      // The city is required here too; the title stays optional.
      expect(find.text('Select your city.'), findsOneWidget);
      expect(find.text('Enter your job title.'), findsNothing);
      expect(account.count('updateResume'), 0);

      await pickCity(tester);
      await tapKey(tester, 'work.save');
      await settle(tester);

      expect(account.count('saveExperience'), 0);
      expect(account.sent['updateResume'], {
        'jobTitle': 'Site Engineer',
        'location': 'Pune, Maharashtra',
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
      await pickCity(tester);
      await tapKey(tester, 'work.save');
      await settle(tester);

      expect(find.text('The start date can’t be in the future.'), findsOneWidget);
      expect(find.text('Facilities Manager'), findsOneWidget);
      expect(find.text('Zenith Estates'), findsOneWidget);
    });

    testWidgets('Skip for Now saves nothing, asks for no city, and leaves the account made', (tester) async {
      final (h, account) = await atWork(tester);

      await tapKey(tester, 'work.skip');
      await settle(tester);

      expect(find.text('Select your city.'), findsNothing);
      expect(account.count('saveExperience'), 0);
      expect(account.count('updateResume'), 0);
      expect(account.count('updateMe'), 0);
      expect(h.auth.status, SessionStatus.signedIn);
    });
  });

  group('leaving', () {
    testWidgets('Sign In returns the address typed so far to the card behind', (tester) async {
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
