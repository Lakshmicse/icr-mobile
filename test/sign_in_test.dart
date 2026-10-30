import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/auth/auth_controller.dart';
import 'package:icr_mobile/core/auth/social_sign_in.dart';
import 'package:icr_mobile/core/auth/token_store.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/auth/linkedin_style.dart';
import 'package:icr_mobile/features/auth/sign_in_screen.dart';
import 'package:icr_mobile/features/auth/social_signup_screen.dart';
import 'package:provider/provider.dart';

import 'helpers/fonts.dart';

class _MemoryTokens extends TokenStore {
  String? access;
  String? refresh;

  @override
  Future<String?> accessToken() async => access;
  @override
  Future<String?> refreshToken() async => refresh;
  @override
  Future<void> save({required String accessToken, required String refreshToken}) async {
    access = accessToken;
    refresh = refreshToken;
  }

  @override
  Future<void> clear() async => access = refresh = null;
}

/// Answers each request from a table and records it with its body.
class _Api implements HttpClientAdapter {
  _Api(this.routes);

  final Map<String, Object Function(Map<String, dynamic>? body)> routes;
  final List<(String, Map<String, dynamic>?)> calls = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = options.data is Map ? (options.data as Map).cast<String, dynamic>() : null;
    final key = '${options.method} ${options.path}';
    calls.add((key, body));
    final handler = routes[key];
    if (handler == null) return ResponseBody.fromString('{"message":"Not found"}', 404, headers: _json);
    final result = handler(body);
    if (result is (int, String)) return ResponseBody.fromString(result.$2, result.$1, headers: _json);
    return ResponseBody.fromString(jsonEncode(result), 200, headers: _json);
  }

  static final _json = {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  };

  @override
  void close({bool force = false}) {}
}

class _CountingSocial extends SocialSignIn {
  final List<SocialProvider> started = [];

  @override
  Future<SocialResult> run(SocialProvider provider) async {
    started.add(provider);
    return const SocialCancelled();
  }
}

const _session = {
  'accessToken': 'a1',
  'refreshToken': 'r1',
  'user': {'id': 'u1', 'email': 'sam@acme.com', 'firstName': 'Sam', 'lastName': 'Rao', 'role': 'PROFESSIONAL'},
};

class _Harness {
  _Harness(this.api, this.auth, this.social);

  final _Api api;
  final AuthController auth;
  final _CountingSocial social;
}

_Harness _harness({Map<String, Object Function(Map<String, dynamic>? body)> routes = const {}}) {
  final api = _Api({
    'GET /auth/social/providers': (_) => {
      'providers': ['GOOGLE'],
    },
    ...routes,
  });
  final tokens = _MemoryTokens();
  final client = ApiClient(tokens: tokens, baseUrl: 'http://api.test/api/v1');
  client.dio.httpClientAdapter = api;
  final social = _CountingSocial();
  return _Harness(api, AuthController(api: client, tokens: tokens, social: social), social);
}

Future<void> _pump(WidgetTester tester, _Harness h, {Widget? screen}) async {
  tester.view.physicalSize = const Size(780, 1688);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: ChangeNotifierProvider.value(value: h.auth, child: screen ?? const SignInScreen()),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pumpAndSettle();
}

Future<void> _submit(WidgetTester tester) async {
  final button = find.byKey(const Key('signIn.submit'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUpAll(loadAppFonts);

  group('the sign-in card', () {
    testWidgets('asks for both before it calls the API', (tester) async {
      final h = _harness();
      await _pump(tester, h);

      await _submit(tester);

      expect(find.text('Please enter your email address.'), findsOneWidget);
      expect(find.text('Please enter your password.'), findsOneWidget);
      expect(h.api.calls.any((c) => c.$1 == 'POST /auth/login'), isFalse);
    });

    testWidgets('refuses an address that is not one', (tester) async {
      final h = _harness();
      await _pump(tester, h);

      await tester.enterText(find.byKey(const Key('signIn.email')), 'not-an-address');
      await tester.enterText(find.byKey(const Key('signIn.password')), 'secret');
      await _submit(tester);

      expect(find.text('Please enter a valid email address.'), findsOneWidget);
      expect(h.api.calls.any((c) => c.$1 == 'POST /auth/login'), isFalse);
    });

    testWidgets('signs in with the typed address, the password and the Remember me choice', (tester) async {
      final h = _harness(routes: {'POST /auth/login': (_) => _session});
      await _pump(tester, h);

      await tester.enterText(find.byKey(const Key('signIn.email')), '  sam@acme.com ');
      await tester.enterText(find.byKey(const Key('signIn.password')), 'Test@12345');
      await tester.tap(find.byKey(const Key('signIn.remember')));
      await tester.pump();
      await _submit(tester);

      final login = h.api.calls.firstWhere((c) => c.$1 == 'POST /auth/login');
      expect(login.$2, {'email': 'sam@acme.com', 'password': 'Test@12345', 'rememberMe': true});
      expect(h.auth.status, SessionStatus.signedIn);
      expect(h.auth.user?.id, 'u1');
    });

    testWidgets('Remember me starts off, as in the design, and goes out as false', (tester) async {
      final h = _harness(routes: {'POST /auth/login': (_) => _session});
      await _pump(tester, h);

      await tester.enterText(find.byKey(const Key('signIn.email')), 'sam@acme.com');
      await tester.enterText(find.byKey(const Key('signIn.password')), 'pw');
      await _submit(tester);

      expect(h.api.calls.firstWhere((c) => c.$1 == 'POST /auth/login').$2!['rememberMe'], isFalse);
    });

    testWidgets("a refusal is shown under the form, in the API's words, and the card is usable again", (tester) async {
      final h = _harness(
        routes: {'POST /auth/login': (_) => (401, '{"statusCode":401,"message":"Invalid credentials"}')},
      );
      await _pump(tester, h);

      await tester.enterText(find.byKey(const Key('signIn.email')), 'sam@acme.com');
      await tester.enterText(find.byKey(const Key('signIn.password')), 'wrong');
      await _submit(tester);
      await tester.pumpAndSettle();

      expect(find.text('Invalid email or password.'), findsOneWidget);
      expect(h.auth.status, SessionStatus.unknown);
      expect(
        tester
            .widget<FilledButton>(
              find.descendant(of: find.byKey(const Key('signIn.submit')), matching: find.byType(FilledButton)),
            )
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('the eye shows and hides the password', (tester) async {
      final h = _harness();
      await _pump(tester, h);

      EditableText password() => tester.widget<EditableText>(
        find.descendant(of: find.byKey(const Key('signIn.password')), matching: find.byType(EditableText)),
      );
      expect(password().obscureText, isTrue);

      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();
      expect(password().obscureText, isFalse);

      await tester.tap(find.byTooltip('Hide password'));
      await tester.pump();
      expect(password().obscureText, isTrue);
    });

    testWidgets('a provider the server has no keys for says so; one it has starts the round trip', (tester) async {
      final h = _harness();
      await _pump(tester, h);

      await tester.tap(find.byKey(const Key('signIn.linkedin')));
      await tester.pump();
      expect(find.text('LinkedIn sign-in is not available yet'), findsOneWidget);
      expect(h.social.started, isEmpty);

      await tester.tap(find.byKey(const Key('signIn.google')));
      await tester.pumpAndSettle();
      expect(h.social.started, [SocialProvider.google]);
    });

    testWidgets('the marks and the links have names a screen reader can read', (tester) async {
      final h = _harness();
      await _pump(tester, h);

      expect(find.bySemanticsLabel('Continue with LinkedIn'), findsOneWidget);
      expect(find.bySemanticsLabel('Continue with Google'), findsOneWidget);
      expect(find.text('Forgot password?'), findsOneWidget);
      expect(find.text('Join now'), findsOneWidget);
    });

    testWidgets(
      'is laid out as LinkedIn is: heading, labelled fields, Show, or, full-width provider buttons, Join now',
      (tester) async {
        await _pump(tester, _harness());

        // The heading, and the button that carries the same words.
        expect(find.text('Sign in'), findsNWidgets(2));
        expect(find.text('Stay updated on your professional world.'), findsOneWidget);
        expect(find.text('Email'), findsOneWidget);
        expect(find.text('Password'), findsOneWidget);
        expect(find.text('Show'), findsOneWidget);
        expect(find.text('or'), findsOneWidget);
        expect(find.text('Continue with LinkedIn'), findsOneWidget);
        expect(find.text('Continue with Google'), findsOneWidget);
        expect(find.text('New to ICR? '), findsOneWidget);

        // The pill and both provider buttons span the page, the providers one under the other.
        final width = tester.getSize(find.byKey(const Key('signIn.submit'))).width;
        expect(tester.getSize(find.byKey(const Key('signIn.linkedin'))).width, width);
        expect(tester.getSize(find.byKey(const Key('signIn.google'))).width, width);
        expect(
          tester.getTopLeft(find.byKey(const Key('signIn.google'))).dy,
          greaterThan(tester.getBottomLeft(find.byKey(const Key('signIn.linkedin'))).dy),
        );

        // "New to ICR? Join now" sits at the foot of the screen (390 x 844 dp).
        expect(tester.getRect(find.byKey(const Key('signIn.create'))).bottom, greaterThan(844 - 70));
      },
    );

    testWidgets('a small phone with the keyboard up scrolls instead of overflowing', (tester) async {
      final h = _harness();
      tester.view.physicalSize = const Size(640, 1136); // 320 × 568 dp
      tester.view.devicePixelRatio = 2;
      tester.view.viewInsets = const FakeViewPadding(bottom: 520); // keyboard, 260 dp
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ChangeNotifierProvider.value(value: h.auth, child: const SignInScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // The button is somewhere down the card, and scrolling gets to it.
      await tester.ensureVisible(find.byKey(const Key('signIn.submit')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getRect(find.byKey(const Key('signIn.submit'))).bottom, lessThanOrEqualTo(568 - 260 + 1));
    });
  });

  group('light and dark', () {
    for (final dark in [false, true]) {
      testWidgets('the page follows the phone: ${dark ? 'dark' : 'light'}', (tester) async {
        tester.platformDispatcher.platformBrightnessTestValue = dark ? Brightness.dark : Brightness.light;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        final h = _harness();
        await _pump(tester, h);

        final colors = dark ? LiColors.dark : LiColors.light;
        expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, colors.page);
        // LinkedIn's page has no card: nothing on it draws a filled, bordered box.
        final boxes = tester
            .widgetList<DecoratedBox>(find.byType(DecoratedBox))
            .map((b) => b.decoration)
            .whereType<BoxDecoration>();
        expect(boxes.any((d) => d.color == colors.page && d.border != null), isFalse);
        // The logo that reads on the page.
        final logo = tester.widget<Image>(find.byType(Image).first).image as AssetImage;
        expect(logo.assetName, colors.logo);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('typed text is the page ink and labels the secondary grey, in dark', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final h = _harness();
      await _pump(tester, h);

      await tester.enterText(find.byKey(const Key('signIn.email')), 'sam@acme.com');
      await tester.pump();
      final typed = tester.widget<EditableText>(
        find.descendant(of: find.byKey(const Key('signIn.email')), matching: find.byType(EditableText)),
      );
      expect(typed.style.color, LiColors.dark.ink);
      // The label floats inside the field's decoration rather than being a Text of its own.
      final field = tester.widget<TextField>(
        find.descendant(of: find.byKey(const Key('signIn.email')), matching: find.byType(TextField)),
      );
      expect(field.decoration!.labelStyle!.color, LiColors.dark.secondary);
    });
  });

  group('joining after Google or LinkedIn', () {
    Future<void> openJoin(WidgetTester tester, _Harness h) async {
      tester.view.physicalSize = const Size(780, 1688);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ChangeNotifierProvider.value(
            value: h.auth,
            child: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ChangeNotifierProvider.value(
                        value: h.auth,
                        child: const SocialSignupScreen(
                          signup: SocialSignup('tok', 'secret'),
                          provider: SocialProvider.google,
                        ),
                      ),
                    ),
                  ),
                  child: const Text('open join'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open join'));
      await tester.pumpAndSettle();
    }

    final pending = <String, Object Function(Map<String, dynamic>? body)>{
      'POST /auth/social/pending': (_) => {
        'provider': 'GOOGLE',
        'email': 'sam@acme.com',
        'firstName': 'Sam',
        'lastName': 'Rao',
        'emailVerified': true,
      },
      'POST /auth/register': (_) => _session,
    };

    for (final dark in [false, true]) {
      testWidgets('shows the name to confirm and joins on "Agree & join" (${dark ? 'dark' : 'light'})', (tester) async {
        tester.platformDispatcher.platformBrightnessTestValue = dark ? Brightness.dark : Brightness.light;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        final h = _harness(routes: pending);
        await openJoin(tester, h);

        // The social path joins the three screens at the second.
        expect(find.text('STEP 2 OF 3'), findsOneWidget);
        expect(find.text('About you'), findsOneWidget);
        expect(find.textContaining('sam@acme.com'), findsOneWidget);
        expect(find.widgetWithText(TextFormField, 'Sam'), findsOneWidget);
        expect(find.widgetWithText(TextFormField, 'Rao'), findsOneWidget);
        // The provider vouched for the address: no code is asked.
        expect(find.byKey(const Key('signup.code')), findsNothing);

        await tester.ensureVisible(find.text('Agree & join'));
        await tester.tap(find.text('Agree & join'));
        await tester.pumpAndSettle();

        final register = h.api.calls.firstWhere((c) => c.$1 == 'POST /auth/register').$2!;
        expect(register['socialToken'], 'tok');
        expect(register['socialVerifier'], 'secret');
        expect(register['firstName'], 'Sam');
        expect(register['lastName'], 'Rao');
        expect(register['acceptTerms'], isTrue);
        expect(register.containsKey('password'), isFalse, reason: 'the provider is the credential');
        expect(h.auth.status, SessionStatus.signedIn);
        // The account is made; "Your work" follows.
        expect(find.text('STEP 3 OF 3'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('an address the provider did not vouch for needs the emailed code first', (tester) async {
      final h = _harness(
        routes: {
          ...pending,
          'POST /auth/social/pending': (_) => {
            'provider': 'GOOGLE',
            'email': 'sam@acme.com',
            'firstName': 'Sam',
            'lastName': 'Rao',
            'emailVerified': false,
          },
          'POST /auth/email/send-code': (_) => {'code': '123456'},
          'POST /auth/email/verify-code': (_) => {'ok': true},
        },
      );
      await openJoin(tester, h);

      // The code is sent on arrival, and shown on screen off production.
      expect(h.api.calls.any((c) => c.$1 == 'POST /auth/email/send-code'), isTrue);
      expect(find.byKey(const Key('signup.code')), findsOneWidget);
      expect(find.textContaining('Test mode: your code is 123456'), findsOneWidget);

      // Without the code nothing is made.
      await tester.ensureVisible(find.text('Agree & join'));
      await tester.tap(find.text('Agree & join'));
      await tester.pumpAndSettle();
      expect(find.text('Enter the 6-digit code from the email'), findsOneWidget);
      expect(h.api.calls.any((c) => c.$1 == 'POST /auth/register'), isFalse);

      await tester.tap(find.text('Use code'));
      await tester.pump();
      await tester.ensureVisible(find.text('Agree & join'));
      await tester.tap(find.text('Agree & join'));
      await tester.pumpAndSettle();

      expect(
        h.api.calls.map((c) => c.$1),
        containsAllInOrder(['POST /auth/email/send-code', 'POST /auth/email/verify-code', 'POST /auth/register']),
      );
      expect(h.api.calls.firstWhere((c) => c.$1 == 'POST /auth/email/verify-code').$2, {
        'email': 'sam@acme.com',
        'code': '123456',
      });
      expect(h.auth.status, SessionStatus.signedIn);
    });

    testWidgets('a link that will not load says why and offers another try', (tester) async {
      final h = _harness(
        routes: {
          'POST /auth/social/pending': (_) => (400, '{"statusCode":400,"message":"This sign-in link has expired."}'),
        },
      );
      await openJoin(tester, h);

      expect(find.text('This sign-in link has expired.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      await tester.tap(find.text('Back to sign in'));
      await tester.pumpAndSettle();
      expect(find.text('About you'), findsNothing);
    });
  });
}
