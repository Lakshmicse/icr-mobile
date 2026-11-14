import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/auth/auth_controller.dart';
import 'package:icr_mobile/features/auth/auth_palette.dart';
import 'package:icr_mobile/features/auth/forgot_password_screen.dart';
import 'package:icr_mobile/features/auth/recovery_repository.dart';
import 'package:icr_mobile/features/auth/reset_password_screen.dart';
import 'package:icr_mobile/features/auth/verify_email_screen.dart';

import 'helpers/account_harness.dart';
import 'helpers/fonts.dart';

/// Forgot password, choosing a new one, and confirming an email, in the app:
/// what each control sends and what each refusal shows.
void main() {
  setUpAll(loadAppFonts);

  const resetUrl = 'http://localhost:3000/reset-password?token=0123456789abcdef0123456789abcdef';
  const token = '0123456789abcdef0123456789abcdef';

  AccountHarness harness({Map<String, ApiHandler> routes = const {}}) => AccountHarness(
    routes: {
      'POST /auth/forgot-password': (_) => {'sent': true},
      'POST /auth/reset-password': (_) => {'success': true},
      'POST /auth/verify-email': (_) => {'success': true, 'alreadyVerified': false},
      'POST /auth/resend-verification': (_) => {'sent': true},
      ...routes,
    },
  );

  Future<void> pump(
    WidgetTester tester,
    AccountHarness h,
    Widget screen, {
    double width = 390,
    double height = 844,
  }) async {
    usePhone(tester, width: width, height: height);
    await tester.pumpWidget(h.app(screen));
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
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  }

  group('tokenFromLink', () {
    test('takes the token out of the emailed link, its query, or the bare token', () {
      expect(tokenFromLink(resetUrl), token);
      expect(tokenFromLink('  $resetUrl \n'), token);
      expect(tokenFromLink('https://icr.org.in/verify-email?token=$token'), token);
      expect(tokenFromLink('?token=$token'), token);
      expect(tokenFromLink('token=$token'), token);
      expect(tokenFromLink(token), token);
    });

    test('is null for anything that is not a link or a token', () {
      expect(tokenFromLink(''), isNull);
      expect(tokenFromLink('   '), isNull);
      expect(tokenFromLink('hello'), isNull);
      expect(tokenFromLink('https://icr.org.in/reset-password'), isNull);
      expect(tokenFromLink('please reset my password'), isNull);
    });
  });

  group('Forgot password', () {
    Future<AccountHarness> open(WidgetTester tester, {Map<String, ApiHandler> routes = const {}, String? email}) async {
      final h = harness(routes: routes);
      await pump(tester, h, ForgotPasswordScreen(initialEmail: email));
      return h;
    }

    testWidgets('asks for an address, and says what is wrong with one, before any call', (tester) async {
      final h = await open(tester);

      await tapKey(tester, 'forgot.send');
      expect(find.text('Enter your email.'), findsOneWidget);

      await type(tester, 'forgot.email', 'samacme.com');
      await tapKey(tester, 'forgot.send');
      expect(find.text('Your email is missing an "@". It should look like name@company.com.'), findsOneWidget);
      expect(h.api.count('POST /auth/forgot-password'), 0);
    });

    testWidgets('starts from the address typed on Sign in', (tester) async {
      await open(tester, email: 'sam@acme.com');
      expect(find.text('sam@acme.com'), findsOneWidget);
    });

    testWidgets('reads "Reset Your Password", "Send Reset Link" and "Remember your password? Sign In", which returns '
        'to Sign In', (tester) async {
      // The client's words on the manual, 13 Nov 2026 (they replace the 12 Nov "Forgot Password" / "Submit" /
      // "Back to Login").
      final h = harness();
      usePhone(tester);
      await tester.pumpWidget(
        h.app(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () =>
                      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ForgotPasswordScreen())),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Reset Your Password'), findsOneWidget);
      expect(find.text('Enter your email address to receive a password reset link.'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Send Reset Link'), findsOneWidget);
      expect(find.text('Remember your password? '), findsOneWidget);
      expect(find.widgetWithText(InkWell, 'Sign In'), findsOneWidget);
      expect(
        find.text('Signed in with Google or LinkedIn? You can sign in directly without setting a password.'),
        findsOneWidget,
      );
      expect(find.text('Submit'), findsNothing);
      expect(find.text('Back to Login'), findsNothing);

      await tapKey(tester, 'forgot.signIn');
      await tester.pumpAndSettle();
      expect(find.text('Reset Your Password'), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    for (final dark in [false, true]) {
      testWidgets('the page is one plain colour, edge to edge: ${dark ? 'dark' : 'white in light'}', (tester) async {
        tester.platformDispatcher.platformBrightnessTestValue = dark ? Brightness.dark : Brightness.light;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        final palette = dark ? AuthPalette.dark : AuthPalette.light;
        Color? pageOf(Type screen) => tester
            .widget<Scaffold>(find.descendant(of: find.byType(screen), matching: find.byType(Scaffold)))
            .backgroundColor;

        // The form, then "Check Your Inbox", then the pasted link: no grey page behind any of them.
        await open(tester, email: 'sam@acme.com');
        expect(pageOf(ForgotPasswordScreen), palette.card);
        if (!dark) expect(pageOf(ForgotPasswordScreen), const Color(0xFFFFFFFF));
        await tapKey(tester, 'forgot.send');
        await settle(tester);
        expect(pageOf(ForgotPasswordScreen), palette.card);
        await tapKey(tester, 'forgot.haveLink');
        await settle(tester);
        expect(pageOf(ResetPasswordScreen), palette.card);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('sends the cleaned address and says to check the inbox', (tester) async {
      final h = await open(tester);

      await type(tester, 'forgot.email', ' sam@acme.com ');
      await tapKey(tester, 'forgot.send');
      await settle(tester);

      expect(h.api.last('POST /auth/forgot-password').json, {'email': 'sam@acme.com'});
      expect(find.text('Check Your Inbox'), findsOneWidget);
      expect(find.byKey(const Key('forgot.sent')), findsOneWidget);
      // The client's words, 13 Nov 2026. The API's link lasts one hour (`RESET_TTL_HOURS = 1`).
      expect(
        find.text(
          'If an ICR account exists for this email, we’ve sent a password reset link. The link expires in 1 hour.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Open your email, copy the reset link and paste it here to create a new password.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(OutlinedButton, 'I have the Link'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Back to Sign In'), findsOneWidget);
      expect(find.text('Resend Link'), findsOneWidget);
      expect(find.text('Registered with Google or LinkedIn? Sign in directly using the same account.'), findsOneWidget);
      // A real mail provider hands no link back: nothing to use in test mode.
      expect(find.byKey(const Key('forgot.useLink')), findsNothing);
    });

    testWidgets('on an API with no mail the link comes back and "Use the Link" opens the new-password form', (
      tester,
    ) async {
      final h = await open(
        tester,
        routes: {
          'POST /auth/forgot-password': (_) => {'sent': true, 'resetUrl': resetUrl},
        },
      );
      await type(tester, 'forgot.email', 'sam@acme.com');
      await tapKey(tester, 'forgot.send');
      await settle(tester);

      expect(find.byKey(const Key('forgot.testLink')), findsOneWidget);
      await tapKey(tester, 'forgot.useLink');
      await settle(tester);

      expect(find.text('Create a New Password'), findsOneWidget);
      expect(find.byKey(const Key('reset.password')), findsOneWidget);
      await type(tester, 'reset.password', 'Brand-new-pass1');
      await type(tester, 'reset.confirm', 'Brand-new-pass1');
      await tapKey(tester, 'reset.submit');
      await settle(tester);
      expect(h.api.last('POST /auth/reset-password').json, {'token': token, 'password': 'Brand-new-pass1'});
    });

    testWidgets('"I have the Link" opens the form that takes the pasted link', (tester) async {
      await open(tester);
      await type(tester, 'forgot.email', 'sam@acme.com');
      await tapKey(tester, 'forgot.send');
      await settle(tester);

      await tapKey(tester, 'forgot.haveLink');
      await settle(tester);

      expect(find.text('Enter Your Reset Link'), findsOneWidget);
      expect(find.byKey(const Key('reset.link')), findsOneWidget);

      // "Resend Reset Link" goes back to "Check Your Inbox", where the link is sent again.
      await tapKey(tester, 'reset.requestNew');
      await settle(tester);
      expect(find.text('Check Your Inbox'), findsOneWidget);
    });

    testWidgets("a refusal shows the API's sentence and keeps the address", (tester) async {
      final h = await open(
        tester,
        routes: {'POST /auth/forgot-password': (_) => ApiReply.refusal(429, 'ThrottlerException: Too Many Requests')},
      );
      await type(tester, 'forgot.email', 'sam@acme.com');
      await tapKey(tester, 'forgot.send');
      await settle(tester);

      expect(find.text('Too many requests. Wait a minute and try again.'), findsOneWidget);
      expect(find.text('sam@acme.com'), findsOneWidget);
      expect(find.text('Check Your Inbox'), findsNothing);
      expect(h.api.count('POST /auth/forgot-password'), 1);
    });

    testWidgets('offline says so, keeps the address, and works on the next try', (tester) async {
      var online = false;
      final h = await open(
        tester,
        routes: {
          'POST /auth/forgot-password': (_) {
            if (!online) throwOffline();
            return {'sent': true};
          },
        },
      );
      await type(tester, 'forgot.email', 'sam@acme.com');
      await tapKey(tester, 'forgot.send');
      await settle(tester);
      expect(find.textContaining("Can't reach ICR"), findsOneWidget);

      online = true;
      await tapKey(tester, 'forgot.send');
      await settle(tester);
      expect(find.text('Check Your Inbox'), findsOneWidget);
      expect(h.api.count('POST /auth/forgot-password'), 2);
    });

    testWidgets('"Resend Link" returns to the form with the address kept', (tester) async {
      await open(tester, email: 'sam@acme.com');
      await tapKey(tester, 'forgot.send');
      await settle(tester);

      await tapKey(tester, 'forgot.again');
      await settle(tester);

      expect(find.byKey(const Key('forgot.send')), findsOneWidget);
      expect(find.text('sam@acme.com'), findsOneWidget);
    });

    testWidgets('a signed-in person changing their password cannot edit the address', (tester) async {
      final h = harness();
      await pump(tester, h, const ForgotPasswordScreen(email: 'sam@acme.com', title: 'Change Password'));

      // The client's words for the screen Settings opens, 13 Nov 2026.
      expect(find.text('Change Password'), findsOneWidget);
      expect(find.text('Enter your work email to receive a password reset link.'), findsOneWidget);
      expect(find.text('Work Email'), findsOneWidget);
      expect(find.text('Send Reset Link'), findsOneWidget);
      expect(find.text('Changed your mind? '), findsOneWidget);
      expect(find.text('Go Back'), findsOneWidget);
      expect(find.text('Registered with Google or LinkedIn? Sign in using the same account.'), findsOneWidget);
      final field = tester.widget<TextFormField>(find.byKey(const Key('forgot.email')));
      expect(field.enabled, isFalse);
      await tapKey(tester, 'forgot.send');
      await settle(tester);
      expect(h.api.last('POST /auth/forgot-password').json, {'email': 'sam@acme.com'});
      // Back from here is Settings, so the button does not promise Sign In.
      expect(find.widgetWithText(FilledButton, 'Go Back'), findsOneWidget);
      expect(find.text('Back to Sign In'), findsNothing);
    });

    testWidgets('double tapping sends one request', (tester) async {
      final h = await open(tester, email: 'sam@acme.com');
      final button = find.byKey(const Key('forgot.send'));
      await tester.tap(button);
      await tester.tap(button, warnIfMissed: false);
      await settle(tester);
      expect(h.api.count('POST /auth/forgot-password'), 1);
    });
  });

  group('Create a New Password', () {
    Future<AccountHarness> open(
      WidgetTester tester, {
      String? tokenArg = token,
      Map<String, ApiHandler> routes = const {},
      bool signedIn = false,
      double width = 390,
      double height = 844,
    }) async {
      final h = harness(routes: routes);
      if (signedIn) await h.signIn(tester);
      await pump(
        tester,
        h,
        ResetPasswordScreen(token: tokenArg),
        width: width,
        height: height,
      );
      return h;
    }

    testWidgets('without a token it asks for the link, in words, before any call', (tester) async {
      final h = await open(tester, tokenArg: null);
      // The client's words, 13 Nov 2026.
      expect(find.text('Enter Your Reset Link'), findsOneWidget);
      expect(find.text('Paste the link from your password reset email to create a new password.'), findsOneWidget);
      expect(find.text('Reset Link'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Resend Reset Link'), findsOneWidget);

      await tapKey(tester, 'reset.useLink');
      expect(find.text('Paste the link from your email.'), findsOneWidget);

      await type(tester, 'reset.link', 'please help');
      await tapKey(tester, 'reset.useLink');
      expect(find.text('This is not a valid reset link. Paste the full link from the email.'), findsOneWidget);
      expect(h.api.calls.where((c) => c.method == 'POST'), isEmpty);
    });

    testWidgets('a pasted link opens the two password fields', (tester) async {
      await open(tester, tokenArg: null);
      await type(tester, 'reset.link', resetUrl);
      await tapKey(tester, 'reset.useLink');
      await settle(tester);

      expect(find.text('Create a New Password'), findsOneWidget);
      expect(find.byKey(const Key('reset.password')), findsOneWidget);
      expect(find.byKey(const Key('reset.confirm')), findsOneWidget);
    });

    testWidgets('asks for eight characters and a matching second field before any call', (tester) async {
      final h = await open(tester);

      await tapKey(tester, 'reset.submit');
      expect(find.text('Enter a new password.'), findsOneWidget);
      expect(find.text('Re-enter your new password.'), findsOneWidget);

      await type(tester, 'reset.password', 'short');
      await type(tester, 'reset.confirm', 'short');
      await tapKey(tester, 'reset.submit');
      expect(find.text('Use at least 8 characters.'), findsWidgets);

      await type(tester, 'reset.password', 'long-enough-1');
      await type(tester, 'reset.confirm', 'long-enough-2');
      await tapKey(tester, 'reset.submit');
      expect(find.text('The passwords do not match.'), findsOneWidget);
      expect(h.api.count('POST /auth/reset-password'), 0);
    });

    testWidgets('the eye shows both fields', (tester) async {
      await open(tester);
      EditableText field(String key) =>
          tester.widget<EditableText>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(EditableText)));
      expect(field('reset.password').obscureText, isTrue);
      await tester.tap(find.byTooltip('Show Password').first);
      await tester.pump();
      expect(field('reset.password').obscureText, isFalse);
      expect(field('reset.confirm').obscureText, isFalse);
    });

    testWidgets('Update Password sends the token and the password, then says it worked', (tester) async {
      final h = await open(tester);

      await type(tester, 'reset.password', 'Brand-new-pass1');
      await type(tester, 'reset.confirm', 'Brand-new-pass1');
      await tapKey(tester, 'reset.submit');
      await settle(tester);

      expect(h.api.last('POST /auth/reset-password').json, {'token': token, 'password': 'Brand-new-pass1'});
      expect(find.text('Password Updated'), findsOneWidget);
      expect(find.byKey(const Key('reset.done')), findsOneWidget);
    });

    testWidgets('a person who was signed in is signed out, since the API ended every session', (tester) async {
      final h = await open(tester, signedIn: true);
      expect(h.auth.status, SessionStatus.signedIn);

      await type(tester, 'reset.password', 'Brand-new-pass1');
      await type(tester, 'reset.confirm', 'Brand-new-pass1');
      await tapKey(tester, 'reset.submit');
      await settle(tester);

      expect(h.auth.status, SessionStatus.signedOut);
      expect(await h.tokens.refreshToken(), isNull);
      // The API is not asked to log out: its refresh token was revoked by the reset.
      expect(h.api.count('POST /auth/logout'), 0);
    });

    testWidgets('an expired link shows the API sentence, keeps the passwords, and offers a new link', (tester) async {
      final h = await open(
        tester,
        routes: {
          'POST /auth/reset-password': (_) => ApiReply.refusal(400, 'This reset link has expired. Request a new one.'),
        },
      );
      await type(tester, 'reset.password', 'Brand-new-pass1');
      await type(tester, 'reset.confirm', 'Brand-new-pass1');
      await tapKey(tester, 'reset.submit');
      await settle(tester);

      expect(find.text('This reset link has expired. Request a new one.'), findsOneWidget);
      EditableText field(String key) =>
          tester.widget<EditableText>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(EditableText)));
      expect(field('reset.password').obscureText, isTrue, reason: 'the typed password is never shown');
      expect(tester.widget<TextFormField>(find.byKey(const Key('reset.password'))).controller!.text, 'Brand-new-pass1');
      expect(tester.widget<TextFormField>(find.byKey(const Key('reset.confirm'))).controller!.text, 'Brand-new-pass1');
      expect(find.byKey(const Key('reset.requestNew')), findsOneWidget);
      expect(h.auth.status, SessionStatus.unknown);

      await tapKey(tester, 'reset.requestNew');
      await settle(tester);
      expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    });

    testWidgets('a dead connection keeps the passwords and does not offer a new link', (tester) async {
      var online = false;
      final h = await open(
        tester,
        routes: {
          'POST /auth/reset-password': (_) {
            if (!online) throwOffline();
            return {'success': true};
          },
        },
      );
      await type(tester, 'reset.password', 'Brand-new-pass1');
      await type(tester, 'reset.confirm', 'Brand-new-pass1');
      await tapKey(tester, 'reset.submit');
      await settle(tester);
      expect(find.textContaining("Can't reach ICR"), findsOneWidget);
      expect(find.byKey(const Key('reset.requestNew')), findsNothing);

      online = true;
      await tapKey(tester, 'reset.submit');
      await settle(tester);
      expect(find.text('Password Updated'), findsOneWidget);
      expect(h.api.count('POST /auth/reset-password'), 2);
    });

    testWidgets('double tapping Update sends one request', (tester) async {
      final h = await open(tester);
      await type(tester, 'reset.password', 'Brand-new-pass1');
      await type(tester, 'reset.confirm', 'Brand-new-pass1');
      final button = find.byKey(const Key('reset.submit'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.tap(button, warnIfMissed: false);
      await settle(tester);
      expect(h.api.count('POST /auth/reset-password'), 1);
    });

    testWidgets('fits a 320 x 568 phone', (tester) async {
      await open(tester, width: 320, height: 568);
      await type(tester, 'reset.password', 'Brand-new-pass1');
      await tapKey(tester, 'reset.submit');
      expect(tester.takeException(), isNull);
    });
  });

  group('Verify Your Email', () {
    testWidgets('a link confirms the address and refreshes the person', (tester) async {
      final h = harness();
      await h.signIn(tester, userJson(emailVerified: false));
      expect(h.auth.user!.emailVerified, isFalse);
      // From now on the API answers "verified", as it does once the link is used.
      h.api.routes['GET /auth/me'] = (_) => userJson(emailVerified: true);
      await pump(tester, h, const VerifyEmailScreen(token: token));
      await settle(tester);

      expect(h.api.last('POST /auth/verify-email').json, {'token': token});
      expect(find.text('Email Verified'), findsOneWidget);
      expect(h.auth.user!.emailVerified, isTrue);
    });

    testWidgets('an address that was already confirmed says so', (tester) async {
      final h = harness(
        routes: {
          'POST /auth/verify-email': (_) => {'success': true, 'alreadyVerified': true},
        },
      );
      await pump(tester, h, const VerifyEmailScreen(token: token));
      await settle(tester);
      expect(find.text('Already Verified'), findsOneWidget);
    });

    testWidgets("a link the API refuses shows its sentence and offers a new one to a signed-in person", (tester) async {
      final h = harness(
        routes: {
          'POST /auth/verify-email': (_) =>
              ApiReply.refusal(400, 'This verification link has expired. Request a new one.'),
        },
      );
      await h.signIn(tester, userJson(emailVerified: false));
      await pump(tester, h, const VerifyEmailScreen(token: token));
      await settle(tester);

      expect(find.text('This Link Did Not Work'), findsOneWidget);
      expect(find.text('This verification link has expired. Request a new one.'), findsOneWidget);

      await tapKey(tester, 'verify.resend');
      await settle(tester);
      expect(h.api.count('POST /auth/resend-verification'), 1);
      expect(find.byKey(const Key('verify.resent')), findsOneWidget);
    });

    testWidgets('without a session the way to a new link is signing in', (tester) async {
      final h = harness();
      await pump(tester, h, const VerifyEmailScreen());
      expect(find.byKey(const Key('verify.resend')), findsNothing);
      expect(find.byKey(const Key('verify.signIn')), findsOneWidget);
    });

    testWidgets('without a token it takes the pasted link', (tester) async {
      final h = harness();
      await h.signIn(tester, userJson(emailVerified: false));
      await pump(tester, h, const VerifyEmailScreen());

      await tapKey(tester, 'verify.useLink');
      expect(find.text('Paste the link from your email.'), findsOneWidget);
      await type(tester, 'verify.link', 'https://icr.org.in/verify-email?token=$token');
      await tapKey(tester, 'verify.useLink');
      await settle(tester);

      expect(h.api.last('POST /auth/verify-email').json, {'token': token});
      expect(find.text('Email Verified'), findsOneWidget);
    });

    testWidgets('a resend for an address already confirmed says so', (tester) async {
      final h = harness(
        routes: {
          'POST /auth/resend-verification': (_) => {'sent': false},
        },
      );
      await h.signIn(tester);
      await pump(tester, h, const VerifyEmailScreen());
      await tapKey(tester, 'verify.resend');
      await settle(tester);
      expect(find.text('This email is already verified.'), findsOneWidget);
    });
  });
}
