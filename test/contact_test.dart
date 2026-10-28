import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/auth/token_store.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/core/widgets/chips.dart';
import 'package:icr_mobile/features/contact/api_contact_repository.dart';
import 'package:icr_mobile/features/contact/contact_controller.dart';
import 'package:icr_mobile/features/contact/contact_models.dart';
import 'package:icr_mobile/features/contact/contact_screen.dart';
import 'package:icr_mobile/features/contact/demo_contact_repository.dart';
import 'package:provider/provider.dart';

import 'helpers/fonts.dart';

// ---------------------------------------------------------------------------
// The fake API
// ---------------------------------------------------------------------------

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

typedef _Handler = FutureOr<Object> Function(Map<String, dynamic>? body);

/// A handler's answer for "the phone has no network".
class _Offline {
  const _Offline();
}

/// Answers each request from a table and records it with its body. A handler may
/// answer later (a Future it holds open), with `(status, rawBody)`, or `_Offline`.
class _Api implements HttpClientAdapter {
  _Api(this.routes);

  final Map<String, _Handler> routes;
  final List<(String, Map<String, dynamic>?)> calls = [];

  int count(String key) => calls.where((c) => c.$1 == key).length;
  Map<String, dynamic>? lastBody(String key) => calls.lastWhere((c) => c.$1 == key).$2;

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
    final result = await handler(body);
    if (result is _Offline) throw DioException.connectionError(requestOptions: options, reason: 'no network');
    if (result is (int, String)) return ResponseBody.fromString(result.$2, result.$1, headers: _json);
    return ResponseBody.fromString(jsonEncode(result), 200, headers: _json);
  }

  static final _json = {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  };

  @override
  void close({bool force = false}) {}
}

const _me = {
  'id': 'u1',
  'email': 'buyer@icr.dev',
  'firstName': 'Bharat',
  'lastName': 'Buyer',
  'role': 'BUYER',
  'phone': '+919879879898',
};
const _unauthorized = (401, '{"statusCode":401,"message":"Unauthorized"}');
const _serverError = (500, '{"statusCode":500,"message":"Internal server error"}');

/// What the API answers a refused body with: Nest's 400 and its list of reasons.
final _badRequest = (
  400,
  jsonEncode({
    'statusCode': 400,
    'message': ['email must be an email', 'message must be shorter than or equal to 4000 characters'],
    'path': '/api/v1/contact',
    'timestamp': '2026-10-25T09:00:00.000Z',
  }),
);
const _throttled = (429, '{"statusCode":429,"message":"ThrottlerException: Too Many Requests"}');

class _H {
  _H(this.api, this.client, this.controller);

  final _Api api;
  final ApiClient client;
  final ContactController controller;
}

_H _harness({Map<String, _Handler> routes = const {}, bool signedIn = true, String? subject, ContactTopic? topic}) {
  final api = _Api({
    'GET /auth/me': (_) => signedIn ? _me : _unauthorized,
    'GET /notifications/unread-count': (_) => signedIn ? {'unread': 2} : _unauthorized,
    'POST /contact': (_) => {'id': 'lead-1'},
    ...routes,
  });
  final tokens = _MemoryTokens()
    ..access = signedIn ? 'a1' : null
    ..refresh = signedIn ? 'r1' : null;
  final client = ApiClient(tokens: tokens, baseUrl: 'http://api.test/api/v1');
  client.dio.httpClientAdapter = api;
  return _H(
    api,
    client,
    ContactController(
      ApiContactRepository(api: client),
      subject: subject,
      topic: topic,
    ),
  );
}

// ---------------------------------------------------------------------------
// Driving the screen
// ---------------------------------------------------------------------------

const _phone = Size(390, 844);
const _small = Size(320, 568);

Future<void> _pump(
  WidgetTester tester,
  _H h, {
  Size size = _phone,
  double keyboard = 0,
  double textScale = 1,
  bool settle = true,
  VoidCallback? onBack,
  VoidCallback? onBell,
  VoidCallback? onRaise,
  VoidCallback? onQuote,
  Future<void> Function(BuildContext, Uri)? opener,
  String? subject,
}) async {
  tester.view.physicalSize = Size(size.width * 2, size.height * 2);
  tester.view.devicePixelRatio = 2;
  if (keyboard > 0) tester.view.viewInsets = FakeViewPadding(bottom: keyboard * 2);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const SizedBox()); // a second screen in one test starts afresh
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      builder: textScale == 1
          ? null
          : (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
      home: ChangeNotifierProvider<ContactController>.value(
        value: h.controller,
        child: ContactScreen(
          subject: subject,
          onBack: onBack,
          onBell: onBell,
          onRaiseRequest: onRaise,
          onRequestQuote: onQuote,
          opener: opener ?? (_, _) async {},
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Finder _key(String k) => find.byKey(ValueKey(k));

/// Scrolls [finder] into view and lets the frame settle (a tap reads the new position).
Future<void> _see(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
}

Future<void> _type(WidgetTester tester, String field, String text) async {
  await _see(tester, _key('contact-$field'));
  await tester.enterText(_key('contact-$field'), text);
  await tester.pump();
}

Future<void> _topic(WidgetTester tester, ContactTopic t) async {
  await _see(tester, _key('topic-${t.api}'));
  await tester.tap(_key('topic-${t.api}'));
  await tester.pump();
}

Future<void> _tapSend(WidgetTester tester) async {
  await _see(tester, _key('contact-send'));
  await tester.pump();
  await tester.tap(_key('contact-send'));
  await tester.pump();
}

Future<void> _fill(
  WidgetTester tester, {
  String name = 'Sam Rao',
  String email = 'sam@acme.com',
  String? message,
}) async {
  await _type(tester, 'name', name);
  await _type(tester, 'email', email);
  await _type(tester, 'message', message ?? 'We would like to know more about chapter membership.');
}

String _text(WidgetTester tester, String field) => tester.widget<TextField>(_key('contact-$field')).controller!.text;

ChipTone _tone(WidgetTester tester, ContactTopic t) => tester.widget<IcrChip>(_key('topic-${t.api}')).tone;

String _error(WidgetTester tester) => tester.widget<Text>(_key('contact-error')).data!;

Future<void> _shot(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.ancestor(of: find.byType(ContactScreen), matching: find.byType(RepaintBoundary)).first,
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory('build/screens').createSync(recursive: true);
    File('build/screens/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

// ---------------------------------------------------------------------------
// What `class-validator`'s `@IsEmail()` answered in the portal (node, 25 Oct
// 2026, class-validator 0.14.4 / validator 13.15), recorded verbatim.
// ---------------------------------------------------------------------------

String _a(int n) => 'a' * n;

final _recorded = <(String, bool)>[
  ('sam@acme.com', true),
  ('sam.rao@acme.co.in', true),
  ('sam+tag@acme.com', true),
  ('o\'brien@acme.com', true),
  ('a@b.co', true),
  ('x_y@acme.io', true),
  ('sam@acme', false),
  ('sam@', false),
  ('@acme.com', false),
  ('sam', false),
  ('', false),
  ('sam acme@acme.com', false),
  ('sam@acme .com', false),
  ('sam@@acme.com', false),
  ('.sam@acme.com', false),
  ('sam.@acme.com', false),
  ('sa..m@acme.com', false),
  ('sam@acme..com', false),
  ('sam@-acme.com', false),
  ('sam@acme-.com', false),
  ('sam@acme.c', false),
  ('sam@acme.123', false),
  ('sam@acme.com.', false),
  ('sam@sub.acme.com', true),
  ('sam@ac_me.com', false),
  ('Sam@ACME.COM', true),
  ('sam@acme.co.uk', true),
  ('sam@xn--bcher-kva.de', true),
  ('jos\u{e9}@acme.com', true),
  ('sam@b\u{fc}cher.de', true),
  ('"sam rao"@acme.com', true),
  ('"sam@acme.com', false),
  ('sam@[127.0.0.1]', false),
  ('sam@127.0.0.1', false),
  ('sam@acme.com ', false),
  (' sam@acme.com', false),
  ('sam@acme.c0m', false),
  ('sam@acme.com\n', false),
  ('sam,rao@acme.com', false),
  ('sam(rao)@acme.com', false),
  ('sam@acme.technology', true),
  ('sam@acme.photography', true),
  ('\u{ff53}am@acme.com', true),
  ('\u{65e5}\u{672c}@acme.com', true),
  ('sam@\u{65e5}\u{672c}.jp', true),
  ('sam@acme.\u{65e5}\u{672c}', true),
  ('!#\$%&\'*+-/=?^_`{|}~@acme.com', true),
  ('sam<rao>@acme.com', false),
  ('Sam Rao <sam@acme.com>', false),
  ('sam@a.b', false),
  ('sam@a-b.co', true),
  ('sam@1acme.com', true),
  ('sam@acme.com@acme.com', false),
  ('${_a(64)}@acme.com', true),
  ('${_a(65)}@acme.com', false),
  ('sam@${_a(63)}.com', true),
  ('sam@${_a(64)}.com', false),
  ('a@${_a(60)}.${_a(60)}.${_a(60)}.${_a(60)}.com', true),
  ('a@${_a(60)}.${_a(60)}.${_a(60)}.${_a(60)}.${_a(10)}.com', false),
];

void main() {
  setUpAll(loadAppFonts);

  // -------------------------------------------------------------------------
  group('the API\'s rules (CreateContactDto)', () {
    test('the email check answers exactly what the API\'s @IsEmail() answered, case by case', () {
      final wrong = [
        for (final (value, accepted) in _recorded)
          if (isApiEmail(value) != accepted)
            '"${value.length > 40 ? '${value.substring(0, 40)}...' : value}" ($accepted)',
      ];
      expect(wrong, isEmpty);
      expect(_recorded.length, greaterThan(55));
    });

    test('the form words every refusal, and only refuses what the API refuses', () {
      expect(ContactRules.name(''), 'Enter your name.');
      expect(ContactRules.name('   '), 'Enter your name.');
      expect(ContactRules.name('a' * 120), isNull);
      expect(ContactRules.name('a' * 121), 'Use 120 characters or fewer for your name.');
      expect(ContactRules.name('  ${'a' * 120}  '), isNull, reason: 'it is sent trimmed');

      expect(ContactRules.email(''), 'Enter your email address.');
      expect(ContactRules.email('sam'), 'Enter a valid email address.');
      expect(ContactRules.email('sam@acme'), 'Enter a valid email address.');
      expect(ContactRules.email('  sam@acme.com  '), isNull, reason: 'it is sent trimmed');

      expect(ContactRules.phone(''), isNull, reason: 'the phone is optional');
      expect(ContactRules.phone('not a number but short'), isNull, reason: 'the DTO checks the length, not the shape');
      expect(ContactRules.phone('1' * 30), isNull);
      expect(ContactRules.phone('1' * 31), 'Use 30 characters or fewer for the phone number.');

      expect(ContactRules.message(''), 'Write your message.');
      expect(ContactRules.message(' \n '), 'Write your message.');
      expect(ContactRules.message('a' * 4000), isNull);
      expect(ContactRules.message('a' * 4001), 'Use 4,000 characters or fewer for your message.');
    });

    test('the limits are the DTO\'s', () {
      expect(ContactLimits.name, 120);
      expect(ContactLimits.phone, 30);
      expect(ContactLimits.message, 4000);
    });

    test('the topics are the website\'s seven, in its order, with its words', () {
      expect(
        [for (final t in ContactTopic.values) (t.api, t.label)],
        [
          ('MEMBERSHIP', 'Membership & chapters'),
          ('VENDOR', 'Becoming a supplier'),
          ('VOLUNTEER', 'Volunteering with ICR'),
          ('PARTNERSHIP', 'Partnerships & sponsorship'),
          ('PRESS', 'Press & media'),
          ('SUPPORT', 'Product support'),
          ('OTHER', 'Something else'),
        ],
      );
      expect(ContactTopic.fromApi('PRESS'), ContactTopic.press);
      expect(ContactTopic.fromApi('CERTIFICATION'), isNull, reason: 'a topic the API would refuse');
      expect(ContactTopic.fromApi(null), isNull);
    });

    test('the body is the DTO\'s fields and nothing else: no empty phone, never the honeypot', () {
      const withPhone = ContactMessage(
        name: 'Sam Rao',
        email: 'sam@acme.com',
        phone: '+91 98765 43210',
        topic: ContactTopic.support,
        message: 'Hello',
      );
      expect(withPhone.toJson(), {
        'name': 'Sam Rao',
        'email': 'sam@acme.com',
        'phone': '+91 98765 43210',
        'topic': 'SUPPORT',
        'message': 'Hello',
      });
      const noPhone = ContactMessage(
        name: 'S',
        email: 'sam@acme.com',
        phone: '',
        topic: ContactTopic.other,
        message: 'm',
      );
      expect(noPhone.toJson().containsKey('phone'), isFalse);
      expect(noPhone.toJson().containsKey('website'), isFalse);
    });

    test('a subject picks the topic the way a person would', () {
      expect(ContactTopic.guess(null), ContactTopic.membership, reason: 'the website\'s default');
      expect(ContactTopic.guess('  '), ContactTopic.membership);
      expect(ContactTopic.guess('Host or propose an event'), ContactTopic.partnership);
      expect(ContactTopic.guess('Sponsor the summit'), ContactTopic.partnership);
      expect(ContactTopic.guess('Volunteer for a committee'), ContactTopic.volunteer);
      expect(ContactTopic.guess('I\'d like to talk about the Supplier Enterprise plan.'), ContactTopic.membership);
      expect(ContactTopic.guess('Join a chapter'), ContactTopic.membership);
      expect(ContactTopic.guess('Become a supplier'), ContactTopic.vendor);
      expect(ContactTopic.guess('Press enquiry'), ContactTopic.press);
      expect(ContactTopic.guess('I cannot log in'), ContactTopic.support);
      expect(ContactTopic.guess('Express delivery'), ContactTopic.other, reason: '"express" is not "press"');
      expect(ContactTopic.guess('Date and location request: Facility Management (FM101)'), ContactTopic.other);
    });
  });

  // -------------------------------------------------------------------------
  group('the API repository', () {
    test('a signed-in member is read from /auth/me, phone included', () async {
      final h = _harness();
      final sender = await ApiContactRepository(api: h.client).sender();
      expect(sender!.name, 'Bharat Buyer');
      expect(sender.email, 'buyer@icr.dev');
      expect(sender.phone, '+919879879898');
    });

    test('a visitor (401) is nobody, not a failure; a 500 or no network is a failure', () async {
      expect(await ApiContactRepository(api: _harness(signedIn: false).client).sender(), isNull);

      final broken = _harness(routes: {'GET /auth/me': (_) => _serverError});
      await expectLater(
        ApiContactRepository(api: broken.client).sender(),
        throwsA(isA<ApiError>().having((e) => e.statusCode, 'status', 500)),
      );

      final offline = _harness(routes: {'GET /auth/me': (_) => const _Offline()});
      await expectLater(
        ApiContactRepository(api: offline.client).sender(),
        throwsA(isA<ApiError>().having((e) => e.isOffline, 'offline', isTrue)),
      );
    });

    test('send posts the body to /contact and answers the API\'s id', () async {
      final h = _harness(
        routes: {
          'POST /contact': (_) => {'id': 'lead-9'},
        },
      );
      final id = await ApiContactRepository(
        api: h.client,
      ).send(const ContactMessage(name: 'Sam', email: 'sam@acme.com', topic: ContactTopic.vendor, message: 'Hi'));
      expect(id, 'lead-9');
      expect(h.api.lastBody('POST /contact'), {
        'name': 'Sam',
        'email': 'sam@acme.com',
        'topic': 'VENDOR',
        'message': 'Hi',
      });
    });

    test('a refusal arrives as the API\'s own sentences', () async {
      final h = _harness(routes: {'POST /contact': (_) => _badRequest});
      await expectLater(
        ApiContactRepository(
          api: h.client,
        ).send(const ContactMessage(name: 'Sam', email: 'x', topic: ContactTopic.vendor, message: 'Hi')),
        throwsA(
          isA<ApiError>()
              .having((e) => e.statusCode, 'status', 400)
              .having(
                (e) => e.message,
                'message',
                'email must be an email\nmessage must be shorter than or equal to 4000 characters',
              ),
        ),
      );
    });

    test('the bell is 0 for a visitor, and for an API that does not answer', () async {
      expect(await ApiContactRepository(api: _harness(signedIn: false).client).unreadNotifications(), 0);
      final broken = _harness(routes: {'GET /notifications/unread-count': (_) => _serverError});
      expect(await ApiContactRepository(api: broken.client).unreadNotifications(), 0);
      expect(await ApiContactRepository(api: _harness().client).unreadNotifications(), 2);
    });
  });

  // -------------------------------------------------------------------------
  group('an anonymous visitor', () {
    testWidgets('gets an empty form that works: nothing prefilled, no support-request note', (tester) async {
      final h = _harness(signedIn: false);
      await _pump(tester, h, onRaise: () {});

      expect(h.api.count('GET /auth/me'), 1);
      expect(_text(tester, 'name'), '');
      expect(_text(tester, 'email'), '');
      expect(_text(tester, 'phone'), '');
      expect(_text(tester, 'message'), '');
      expect(_key('contact-raise'), findsNothing, reason: 'only a signed-in member is pointed to a support request');
      expect(_key('contact-identity-failed'), findsNothing, reason: 'a 401 is "nobody is signed in", not a failure');
      expect(_key('contact-checking'), findsNothing);
      expect(find.text('Talk to the ICR team'), findsOneWidget);
      expect(find.text('Send message'), findsOneWidget);
    });

    testWidgets('sends the DTO\'s body: trimmed, no website, phone only when typed', (tester) async {
      final h = _harness(signedIn: false);
      await _pump(tester, h);

      await _type(tester, 'name', '  Sam Rao  ');
      await _type(tester, 'email', '  sam@acme.com ');
      await _type(tester, 'phone', '  +91 98765 43210 ');
      await _topic(tester, ContactTopic.support);
      await _type(tester, 'message', '  Hello team \n');
      await _tapSend(tester);
      await tester.pumpAndSettle();

      expect(h.api.count('POST /contact'), 1);
      expect(h.api.lastBody('POST /contact'), {
        'name': 'Sam Rao',
        'email': 'sam@acme.com',
        'phone': '+91 98765 43210',
        'topic': 'SUPPORT',
        'message': 'Hello team',
      });
      expect(h.api.lastBody('POST /contact')!.containsKey('website'), isFalse);
    });

    testWidgets('leaves the phone out of the body when it was not typed, and the topic starts on Membership', (
      tester,
    ) async {
      final h = _harness(signedIn: false);
      await _pump(tester, h);
      expect(_tone(tester, ContactTopic.membership), ChipTone.primary);

      await _fill(tester);
      await _tapSend(tester);
      await tester.pumpAndSettle();

      expect(h.api.lastBody('POST /contact'), {
        'name': 'Sam Rao',
        'email': 'sam@acme.com',
        'topic': 'MEMBERSHIP',
        'message': 'We would like to know more about chapter membership.',
      });
    });
  });

  // -------------------------------------------------------------------------
  group('a signed-in member', () {
    testWidgets('has name, email and phone filled in from /auth/me, and the bell count', (tester) async {
      final handle = tester.ensureSemantics();
      final h = _harness();
      await _pump(tester, h);

      expect(_text(tester, 'name'), 'Bharat Buyer');
      expect(_text(tester, 'email'), 'buyer@icr.dev');
      expect(_text(tester, 'phone'), '+919879879898');
      expect(_text(tester, 'message'), '');
      expect(find.bySemanticsLabel('Notifications, 2 unread'), findsOneWidget);
      expect(h.controller.signedIn, isTrue);
      handle.dispose();
    });

    testWidgets('can still change what was filled in, and what is sent is what the form says', (tester) async {
      final h = _harness();
      await _pump(tester, h);

      await _type(tester, 'name', 'B. Buyer');
      await _type(tester, 'phone', '');
      await _type(tester, 'message', 'A question');
      await _tapSend(tester);
      await tester.pumpAndSettle();

      expect(h.api.lastBody('POST /contact'), {
        'name': 'B. Buyer',
        'email': 'buyer@icr.dev',
        'topic': 'MEMBERSHIP',
        'message': 'A question',
      });
    });

    testWidgets('is told a support request serves them better, and the button calls the lead\'s callback', (
      tester,
    ) async {
      var raised = 0;
      final h = _harness();
      await _pump(tester, h, onRaise: () => raised++);

      expect(find.textContaining('raising a request gives you a reference number'), findsOneWidget);
      await _see(tester, _key('contact-raise'));
      await tester.tap(_key('contact-raise'));
      expect(raised, 1);
    });

    testWidgets('is not pointed anywhere when the lead gave no callback, and not after the message is sent', (
      tester,
    ) async {
      final h = _harness();
      await _pump(tester, h);
      expect(_key('contact-raise'), findsNothing);

      var raised = 0;
      final again = _harness();
      await _pump(tester, again, onRaise: () => raised++);
      expect(_key('contact-raise'), findsOneWidget);
      await _type(tester, 'message', 'Hello');
      await _tapSend(tester);
      await tester.pumpAndSettle();
      expect(_key('contact-sent'), findsOneWidget);
      expect(_key('contact-raise'), findsNothing);
      expect(raised, 0);
    });
  });

  // -------------------------------------------------------------------------
  group('reading who is signed in', () {
    testWidgets('shows a loading line while it is asked, and the form is usable at once', (tester) async {
      final gate = Completer<void>();
      final h = _harness(
        routes: {
          'GET /auth/me': (_) async {
            await gate.future;
            return _me;
          },
        },
      );
      await _pump(tester, h, settle: false);

      expect(_key('contact-checking'), findsOneWidget);
      expect(find.text('Checking whether you are signed in…'), findsOneWidget);
      await _type(tester, 'name', 'Early Bird');

      gate.complete();
      await tester.pumpAndSettle();
      expect(_key('contact-checking'), findsNothing);
      expect(_text(tester, 'name'), 'Early Bird', reason: 'what the person typed is never overwritten');
      expect(_text(tester, 'email'), 'buyer@icr.dev', reason: 'the empty fields are filled in');
      expect(_text(tester, 'phone'), '+919879879898');
    });

    testWidgets('a failed read says so with a Retry, the form still sends, and Retry fills it in', (tester) async {
      var asked = 0;
      final h = _harness(routes: {'GET /auth/me': (_) => ++asked == 1 ? _serverError : _me});
      await _pump(tester, h);

      expect(_key('contact-identity-failed'), findsOneWidget);
      expect(find.textContaining("We couldn't check whether you are signed in"), findsOneWidget);
      expect(_text(tester, 'name'), '');
      expect(h.controller.signedIn, isFalse);

      await tester.tap(_key('contact-identity-retry'));
      await tester.pumpAndSettle();
      expect(asked, 2);
      expect(_key('contact-identity-failed'), findsNothing);
      expect(_text(tester, 'name'), 'Bharat Buyer');
      expect(h.controller.signedIn, isTrue);
    });

    testWidgets('with no network the visitor can still write, and the send then says what is wrong', (tester) async {
      final h = _harness(
        routes: {
          'GET /auth/me': (_) => const _Offline(),
          'GET /notifications/unread-count': (_) => const _Offline(),
          'POST /contact': (_) => const _Offline(),
        },
      );
      await _pump(tester, h);
      expect(_key('contact-identity-failed'), findsOneWidget);

      await _fill(tester);
      await _tapSend(tester);
      await tester.pumpAndSettle();
      expect(_error(tester), "Can't reach ICR right now. Check your connection and try again.");
      expect(_text(tester, 'message'), 'We would like to know more about chapter membership.');
    });
  });

  // -------------------------------------------------------------------------
  group('a subject handed in by another screen', () {
    testWidgets('opens the message, picks the topic and puts the cursor after it', (tester) async {
      final h = _harness(signedIn: false, subject: 'Host or propose an event');
      await _pump(tester, h);

      expect(_text(tester, 'message'), 'Host or propose an event\n\n');
      expect(h.controller.message.selection, const TextSelection.collapsed(offset: 26));
      expect(_tone(tester, ContactTopic.partnership), ChipTone.primary);
      expect(_tone(tester, ContactTopic.membership), ChipTone.outlined);
    });

    testWidgets('a topic named outright wins over the guess; the person can still change it', (tester) async {
      final h = _harness(signedIn: false, subject: 'Host or propose an event', topic: ContactTopic.press);
      await _pump(tester, h);
      expect(_tone(tester, ContactTopic.press), ChipTone.primary);
      expect(_tone(tester, ContactTopic.partnership), ChipTone.outlined);

      await _topic(tester, ContactTopic.vendor);
      expect(_tone(tester, ContactTopic.vendor), ChipTone.primary);
      expect(_tone(tester, ContactTopic.press), ChipTone.outlined);
    });

    testWidgets('the screen hands its own subject to a controller built without one, once', (tester) async {
      final h = _harness(signedIn: false);
      await _pump(tester, h, subject: 'Volunteer for a committee');

      expect(_text(tester, 'message'), 'Volunteer for a committee\n\n');
      expect(_tone(tester, ContactTopic.volunteer), ChipTone.primary);
    });

    testWidgets('never writes over a message the person has begun', (tester) async {
      final h = _harness(signedIn: false);
      h.controller.message.text = 'Already typing';
      h.controller.applySubject('Host or propose an event');
      expect(h.controller.message.text, 'Already typing');
      expect(h.controller.topic, ContactTopic.membership);
      await _pump(tester, h);
      expect(_text(tester, 'message'), 'Already typing');
    });

    testWidgets('the subject goes out as the first line of the message', (tester) async {
      final h = _harness(signedIn: false, subject: 'Host or propose an event');
      await _pump(tester, h);
      await _type(tester, 'name', 'Sam');
      await _type(tester, 'email', 'sam@acme.com');
      await _type(tester, 'message', 'Host or propose an event\n\nA summit in Pune in March.');
      await _tapSend(tester);
      await tester.pumpAndSettle();

      final body = h.api.lastBody('POST /contact')!;
      expect(body['topic'], 'PARTNERSHIP');
      expect(body['message'], 'Host or propose an event\n\nA summit in Pune in March.');
    });
  });

  // -------------------------------------------------------------------------
  group('the topic chips', () {
    testWidgets('show all seven in the website\'s words, one selected at a time', (tester) async {
      final h = _harness(signedIn: false);
      await _pump(tester, h);

      for (final t in ContactTopic.values) {
        expect(find.text(t.label), findsOneWidget);
      }
      expect(ContactTopic.values.where((t) => _tone(tester, t) == ChipTone.primary), [ContactTopic.membership]);

      await _topic(tester, ContactTopic.press);
      expect(ContactTopic.values.where((t) => _tone(tester, t) == ChipTone.primary), [ContactTopic.press]);
    });

    for (final t in ContactTopic.values) {
      testWidgets('${t.label} is sent as ${t.api}', (tester) async {
        final h = _harness(signedIn: false);
        await _pump(tester, h);
        await _fill(tester);
        await _topic(tester, t);
        await _tapSend(tester);
        await tester.pumpAndSettle();

        expect(h.api.lastBody('POST /contact')!['topic'], t.api);
      });
    }
  });

  // -------------------------------------------------------------------------
  group('validation', () {
    testWidgets('shows nothing until a send is tried, then names every field that is wrong, and sends nothing', (
      tester,
    ) async {
      final h = _harness(signedIn: false);
      await _pump(tester, h);
      expect(find.text('Enter your name.'), findsNothing);

      await _tapSend(tester);
      await tester.pumpAndSettle();

      expect(find.text('Enter your name.'), findsOneWidget);
      expect(find.text('Enter your email address.'), findsOneWidget);
      expect(find.text('Write your message.'), findsOneWidget);
      expect(h.api.count('POST /contact'), 0);
    });

    testWidgets('then follows the typing: the reason changes, and goes when the field is right', (tester) async {
      final h = _harness(signedIn: false);
      await _pump(tester, h);
      await _tapSend(tester);
      await tester.pumpAndSettle();

      await _type(tester, 'email', 'sam');
      expect(find.text('Enter your email address.'), findsNothing);
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      await _type(tester, 'email', 'sam@acme');
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      await _type(tester, 'email', 'sam@acme.com');
      expect(find.text('Enter a valid email address.'), findsNothing);

      await _type(tester, 'name', 'Sam');
      expect(find.text('Enter your name.'), findsNothing);
      expect(find.text('Write your message.'), findsOneWidget, reason: 'the fields not touched keep their reason');

      await _type(tester, 'message', 'Hello');
      expect(find.text('Write your message.'), findsNothing);
      expect(h.api.count('POST /contact'), 0, reason: 'fixing the fields does not send by itself');
    });

    testWidgets('refuses an email the API\'s @IsEmail() refuses', (tester) async {
      final h = _harness(signedIn: false);
      await _pump(tester, h);
      await _fill(tester, email: 'sam@acme..com');
      await _tapSend(tester);
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(h.api.count('POST /contact'), 0);
    });

    testWidgets('a name over 120 characters and a phone over 30 are refused before the API', (tester) async {
      final h = _harness(signedIn: false);
      await _pump(tester, h);
      await _fill(tester, name: 'n' * 121);
      await _type(tester, 'phone', '9' * 31);
      await _tapSend(tester);
      await tester.pumpAndSettle();

      expect(find.text('Use 120 characters or fewer for your name.'), findsOneWidget);
      expect(find.text('Use 30 characters or fewer for the phone number.'), findsOneWidget);
      expect(h.api.count('POST /contact'), 0);

      await _type(tester, 'name', 'n' * 120);
      await _type(tester, 'phone', '9' * 30);
      await _tapSend(tester);
      await tester.pumpAndSettle();
      expect(h.api.count('POST /contact'), 1, reason: 'exactly at the limits is accepted');
    });

    testWidgets('the message box stops at 4000 characters, and a longer one set from code is still refused', (
      tester,
    ) async {
      final h = _harness(signedIn: false);
      await _pump(tester, h);
      await _fill(tester);
      await _type(tester, 'message', 'a' * 4100);
      expect(_text(tester, 'message').length, 4000);

      h.controller.message.text = 'a' * 4001;
      await _tapSend(tester);
      await tester.pumpAndSettle();
      expect(find.text('Use 4,000 characters or fewer for your message.'), findsOneWidget);
      expect(h.api.count('POST /contact'), 0);
    });

    testWidgets('a message of only spaces is not a message', (tester) async {
      final h = _harness(signedIn: false);
      await _pump(tester, h);
      await _fill(tester, message: '   \n  ');
      await _tapSend(tester);
      await tester.pumpAndSettle();
      expect(find.text('Write your message.'), findsOneWidget);
      expect(h.api.count('POST /contact'), 0);
    });
  });

  // -------------------------------------------------------------------------
  group('when the API refuses', () {
    testWidgets('a 400 with a list of reasons is shown line by line, and everything typed stays', (tester) async {
      final h = _harness(signedIn: false, routes: {'POST /contact': (_) => _badRequest});
      await _pump(tester, h);
      await _fill(tester);
      await _type(tester, 'phone', '+91 98765 43210');
      await _topic(tester, ContactTopic.vendor);
      await _tapSend(tester);
      await tester.pumpAndSettle();

      expect(_error(tester), 'email must be an email\nmessage must be shorter than or equal to 4000 characters');
      expect(_text(tester, 'name'), 'Sam Rao');
      expect(_text(tester, 'email'), 'sam@acme.com');
      expect(_text(tester, 'phone'), '+91 98765 43210');
      expect(_text(tester, 'message'), 'We would like to know more about chapter membership.');
      expect(_tone(tester, ContactTopic.vendor), ChipTone.primary);
      expect(_key('contact-sent'), findsNothing);
      // The button is usable again.
      expect(find.text('Send message'), findsOneWidget);
      expect(h.controller.sending, isFalse);
    });

    testWidgets('a 429 says to wait a minute and that the message is kept; typing again clears it', (tester) async {
      final h = _harness(signedIn: false, routes: {'POST /contact': (_) => _throttled});
      await _pump(tester, h);
      await _fill(tester);
      await _tapSend(tester);
      await tester.pumpAndSettle();

      expect(
        _error(tester),
        'You have sent a few messages in a short while. Wait a minute, then send again: what you wrote is kept.',
      );
      expect(_text(tester, 'message'), 'We would like to know more about chapter membership.');

      await _type(tester, 'message', 'We would like to know more about chapter membership. Thanks.');
      expect(_key('contact-error'), findsNothing, reason: 'the person is answering it');
    });

    testWidgets('with no network the message says so in words, and keeps everything', (tester) async {
      final h = _harness(signedIn: false, routes: {'POST /contact': (_) => const _Offline()});
      await _pump(tester, h);
      await _fill(tester);
      await _tapSend(tester);
      await tester.pumpAndSettle();

      expect(_error(tester), "Can't reach ICR right now. Check your connection and try again.");
      expect(_text(tester, 'name'), 'Sam Rao');
      expect(_text(tester, 'message'), 'We would like to know more about chapter membership.');
    });

    testWidgets('a 500 shows the API\'s sentence', (tester) async {
      final h = _harness(signedIn: false, routes: {'POST /contact': (_) => _serverError});
      await _pump(tester, h);
      await _fill(tester);
      await _tapSend(tester);
      await tester.pumpAndSettle();
      expect(_error(tester), 'Internal server error');
    });

    testWidgets('after a refusal the same text can be sent again, and goes through', (tester) async {
      var answers = 0;
      final h = _harness(
        signedIn: false,
        routes: {
          'POST /contact': (_) => ++answers == 1 ? _badRequest : {'id': 'lead-2'},
        },
      );
      await _pump(tester, h);
      await _fill(tester);
      await _tapSend(tester);
      await tester.pumpAndSettle();
      expect(_key('contact-error'), findsOneWidget);

      await _tapSend(tester);
      await tester.pumpAndSettle();
      expect(h.api.count('POST /contact'), 2);
      expect(
        h.api.calls.where((c) => c.$1 == 'POST /contact').map((c) => jsonEncode(c.$2)).toSet().length,
        1,
        reason: 'the very same body',
      );
      expect(_key('contact-sent'), findsOneWidget);
      expect(h.controller.sentId, 'lead-2');
    });
  });

  // -------------------------------------------------------------------------
  group('sending', () {
    testWidgets('blocks a double send: one request however often the button is hit', (tester) async {
      final gate = Completer<void>();
      final h = _harness(
        signedIn: false,
        routes: {
          'POST /contact': (_) async {
            await gate.future;
            return {'id': 'lead-1'};
          },
        },
      );
      await _pump(tester, h);
      await _fill(tester);

      await _tapSend(tester);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Sending…'), findsOneWidget);
      await tester.tap(_key('contact-send'), warnIfMissed: false);
      await tester.pump();
      await tester.tap(_key('contact-send'), warnIfMissed: false);
      await tester.pump();
      expect(await h.controller.send(), isFalse, reason: 'the controller refuses too, whatever the button does');
      expect(h.api.count('POST /contact'), 1);

      // The form is held still while it goes: no editing, no topic change.
      expect(tester.widget<TextField>(_key('contact-name')).enabled, isFalse);
      await tester.tap(_key('topic-PRESS'), warnIfMissed: false);
      await tester.pump();
      expect(h.controller.topic, ContactTopic.membership);

      gate.complete();
      await tester.pumpAndSettle();
      expect(h.api.count('POST /contact'), 1);
      expect(_key('contact-sent'), findsOneWidget);
    });

    testWidgets('a sent message shows Message sent, who the reply goes to, and hides the form', (tester) async {
      final h = _harness(signedIn: false);
      await _pump(tester, h);
      await _fill(tester);
      await _tapSend(tester);
      await tester.pumpAndSettle();

      expect(find.text('Message sent'), findsOneWidget);
      expect(find.textContaining('your message is in'), findsOneWidget);
      expect(find.text('We will reply to sam@acme.com.'), findsOneWidget);
      expect(find.text('Send another'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(_key('contact-send'), findsNothing);
      expect(h.controller.sentId, 'lead-1');
    });

    testWidgets('Send another brings the form back: sender and topic kept, the message gone, and it sends again', (
      tester,
    ) async {
      final h = _harness();
      await _pump(tester, h);
      await _topic(tester, ContactTopic.press);
      await _type(tester, 'message', 'First message');
      await _tapSend(tester);
      await tester.pumpAndSettle();
      expect(h.api.count('POST /contact'), 1);

      await tester.tap(_key('contact-another'));
      await tester.pumpAndSettle();
      expect(_key('contact-sent'), findsNothing);
      expect(_text(tester, 'name'), 'Bharat Buyer');
      expect(_text(tester, 'email'), 'buyer@icr.dev');
      expect(_text(tester, 'message'), '');
      expect(_tone(tester, ContactTopic.press), ChipTone.primary);
      expect(find.text('Write your message.'), findsNothing, reason: 'a fresh form does not scold');

      await _type(tester, 'message', 'Second message');
      await _tapSend(tester);
      await tester.pumpAndSettle();
      expect(h.api.count('POST /contact'), 2);
      expect(h.api.lastBody('POST /contact')!['message'], 'Second message');
      expect(h.api.lastBody('POST /contact')!['topic'], 'PRESS');
    });

    testWidgets('Done leaves the screen through the lead\'s onBack', (tester) async {
      var left = 0;
      final h = _harness(signedIn: false);
      await _pump(tester, h, onBack: () => left++);
      await _fill(tester);
      await _tapSend(tester);
      await tester.pumpAndSettle();

      await tester.tap(_key('contact-done'));
      expect(left, 1);
    });
  });

  // -------------------------------------------------------------------------
  group('pull to refresh', () {
    testWidgets('asks who is signed in and the bell again, and never touches what was typed', (tester) async {
      final handle = tester.ensureSemantics();
      var bell = 0;
      final h = _harness(
        routes: {
          'GET /notifications/unread-count': (_) => {'unread': ++bell == 1 ? 2 : 5},
        },
      );
      await _pump(tester, h);
      await _type(tester, 'message', 'A draft that must survive');
      await _type(tester, 'name', 'Changed Name');
      expect(find.bySemanticsLabel('Notifications, 2 unread'), findsOneWidget);

      // Back at the very top: a pull only refreshes when the gesture starts at offset 0.
      await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
      await tester.pumpAndSettle();
      await tester.fling(find.byType(ListView).first, const Offset(0, 400), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(h.api.count('GET /auth/me'), 2);
      expect(h.api.count('GET /notifications/unread-count'), 2);
      expect(find.bySemanticsLabel('Notifications, 5 unread'), findsOneWidget);
      expect(_text(tester, 'message'), 'A draft that must survive');
      expect(_text(tester, 'name'), 'Changed Name');
      handle.dispose();
    });

    testWidgets('works on a short page too, and recovers a failed sign-in read', (tester) async {
      var asked = 0;
      final h = _harness(routes: {'GET /auth/me': (_) => ++asked == 1 ? _serverError : _me});
      await _pump(tester, h);
      expect(_key('contact-identity-failed'), findsOneWidget);

      await tester.fling(find.byType(ListView).first, const Offset(0, 400), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(_key('contact-identity-failed'), findsNothing);
      expect(_text(tester, 'name'), 'Bharat Buyer');
    });
  });

  // -------------------------------------------------------------------------
  group('reaching the team directly', () {
    testWidgets('shows the address and the hours as the website does', (tester) async {
      final h = _harness(signedIn: false);
      await _pump(tester, h);
      await _see(tester, find.text('Reach us directly'));
      expect(find.text('hello@icr.network'), findsOneWidget);
      expect(find.text('Mon–Fri, 9:30–18:30 IST'), findsOneWidget);
    });

    testWidgets('the address opens a mailto: link', (tester) async {
      final opened = <Uri>[];
      final h = _harness(signedIn: false);
      await _pump(tester, h, opener: (_, uri) async => opened.add(uri));

      await _see(tester, _key('contact-mail'));
      await tester.tap(_key('contact-mail'));
      await tester.pump();
      expect(opened.map((u) => u.toString()), ['mailto:hello@icr.network']);
    });

    testWidgets('a phone with no mail app is told so, with the address to copy', (tester) async {
      final h = _harness(signedIn: false);
      await _pump(tester, h, opener: (_, _) async => throw PlatformException(code: 'ACTIVITY_NOT_FOUND'));

      await _see(tester, _key('contact-mail'));
      await tester.tap(_key('contact-mail'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('No email app found. Write to hello@icr.network.'), findsOneWidget);
    });

    testWidgets('the copy button puts the address on the clipboard', (tester) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      final h = _harness(signedIn: false);
      await _pump(tester, h);

      await _see(tester, _key('contact-copy'));
      await tester.tap(_key('contact-copy'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(copied, ['hello@icr.network']);
      expect(find.text('Email address copied'), findsOneWidget);
    });

    testWidgets('the quote line shows only when the lead wires it, and calls it', (tester) async {
      final none = _harness(signedIn: false);
      await _pump(tester, none);
      expect(_key('contact-quote'), findsNothing);

      var quotes = 0;
      final h = _harness(signedIn: false);
      await _pump(tester, h, onQuote: () => quotes++);
      await _see(tester, _key('contact-quote'));
      await tester.tap(_key('contact-quote'));
      expect(quotes, 1);
    });
  });

  // -------------------------------------------------------------------------
  group('the title bar', () {
    testWidgets('Back calls onBack; the bell calls onBell, or opens the website\'s notifications by default', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var back = 0;
      var bell = 0;
      final h = _harness(signedIn: false);
      await _pump(tester, h, onBack: () => back++, onBell: () => bell++);
      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.tap(find.bySemanticsLabel('Notifications'));
      expect(back, 1);
      expect(bell, 1);

      final opened = <Uri>[];
      final plain = _harness(signedIn: false);
      await _pump(tester, plain, opener: (_, uri) async => opened.add(uri));
      await tester.tap(find.bySemanticsLabel('Notifications'));
      await tester.pump();
      expect(opened.map((u) => u.toString()), ['https://icr.org.in/notifications']);
      handle.dispose();
    });
  });

  // -------------------------------------------------------------------------
  group('as a route (contactRoute)', () {
    Future<void> openRoute(
      WidgetTester tester,
      _H h, {
      String? subject,
      ContactTopic? topic,
      VoidCallback? onRaise,
      bool demo = false,
    }) async {
      tester.view.physicalSize = const Size(780, 1688);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        Provider<ApiClient>.value(
          value: h.client,
          child: MaterialApp(
            theme: buildAppTheme(),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (c) =>
                          contactRoute(c, subject: subject, topic: topic, onRaiseRequest: onRaise, demo: demo),
                    ),
                  ),
                  child: const Text('open contact'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open contact'));
      await tester.pumpAndSettle();
    }

    testWidgets('builds its own controller on the API, applies the subject, and Back pops it', (tester) async {
      final handle = tester.ensureSemantics();
      var raised = 0;
      final h = _harness();
      await openRoute(tester, h, subject: 'Host or propose an event', onRaise: () => raised++);

      expect(find.text('Contact us'), findsOneWidget);
      expect(_text(tester, 'name'), 'Bharat Buyer');
      expect(_text(tester, 'message'), 'Host or propose an event\n\n');
      expect(_tone(tester, ContactTopic.partnership), ChipTone.primary);
      await tester.tap(_key('contact-raise'));
      expect(raised, 1);

      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();
      expect(find.text('open contact'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('sends through the API client it was given, and Done pops it', (tester) async {
      final h = _harness();
      await openRoute(tester, h, topic: ContactTopic.volunteer);
      await _type(tester, 'message', 'I can help');
      await _tapSend(tester);
      await tester.pumpAndSettle();

      expect(h.api.lastBody('POST /contact'), {
        'name': 'Bharat Buyer',
        'email': 'buyer@icr.dev',
        'phone': '+919879879898',
        'topic': 'VOLUNTEER',
        'message': 'I can help',
      });
      await tester.tap(_key('contact-done'));
      await tester.pumpAndSettle();
      expect(find.text('open contact'), findsOneWidget);
    });

    testWidgets('the sample source works without the API (FEED_SOURCE=demo)', (tester) async {
      final h = _harness();
      await openRoute(tester, h, demo: true);
      expect(_text(tester, 'name'), 'Bharat Buyer');
      expect(h.api.calls, isEmpty, reason: 'the sample source never calls the API');
      await _type(tester, 'message', 'Hello');
      await _tapSend(tester);
      await tester.pumpAndSettle();
      expect(_key('contact-sent'), findsOneWidget);
      expect(h.api.calls, isEmpty);
    });

    test('the sample repository keeps what it is sent', () async {
      final demo = DemoContactRepository();
      final id = await demo.send(
        const ContactMessage(name: 'S', email: 'sam@acme.com', topic: ContactTopic.other, message: 'm'),
      );
      expect(id, 'demo-1');
      expect(demo.sent.single.message, 'm');
    });
  });

  // -------------------------------------------------------------------------
  group('on a small phone', () {
    testWidgets('320 × 568 with the keyboard up scrolls instead of overflowing, and reaches Send', (tester) async {
      final h = _harness();
      await _pump(tester, h, size: _small, keyboard: 260, onRaise: () {}, onQuote: () {});
      expect(tester.takeException(), isNull);

      await _see(tester, _key('contact-send'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getRect(_key('contact-send')).bottom, lessThanOrEqualTo(568 - 260 + 1));

      await _see(tester, _key('contact-quote'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('a send that is refused brings the first problem into view', (tester) async {
      final h = _harness(signedIn: false);
      await _pump(tester, h, size: _small, keyboard: 260);
      await _see(tester, _key('contact-send'));
      await tester.pumpAndSettle();
      expect(tester.getRect(_key('contact-name')).top, lessThan(56), reason: 'the name is scrolled off the top');

      await tester.tap(_key('contact-send'));
      await tester.pumpAndSettle();
      final name = tester.getRect(_key('contact-name'));
      expect(name.top, greaterThanOrEqualTo(56));
      expect(name.bottom, lessThanOrEqualTo(568 - 260 + 1));
      expect(find.text('Enter your name.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the API\'s refusal is brought into view too', (tester) async {
      final h = _harness(signedIn: false, routes: {'POST /contact': (_) => _badRequest});
      await _pump(tester, h, size: _small, keyboard: 260);
      await _fill(tester);
      await _tapSend(tester);
      await tester.pumpAndSettle();

      final error = tester.getRect(_key('contact-error'));
      expect(error.top, greaterThanOrEqualTo(56));
      expect(error.bottom, lessThanOrEqualTo(568 - 260 + 1));
    });

    testWidgets('the sent card fits 320 wide, and the page returns to the top', (tester) async {
      final h = _harness(signedIn: false);
      await _pump(tester, h, size: _small);
      await _fill(tester);
      await _tapSend(tester);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getRect(_key('contact-sent')).top, lessThan(568));
      expect(tester.getRect(_key('contact-sent')).right, lessThanOrEqualTo(320));
    });

    testWidgets('a large text size still fits 320 wide with no overflow', (tester) async {
      final h = _harness(signedIn: false);
      await _pump(tester, h, size: _small, textScale: 1.6, onQuote: () {});
      expect(tester.takeException(), isNull);
      await _see(tester, _key('contact-quote'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('a tablet keeps the form to a readable column', (tester) async {
      final h = _harness(signedIn: false);
      await _pump(tester, h, size: const Size(820, 1180));
      expect(tester.getSize(_key('contact-name')).width, lessThan(560));
      expect(tester.takeException(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // Pictures of the screen, for a look (build/screens/contact_*.png). They assert only that it draws.
  group('draws', () {
    testWidgets('the form, its reasons, a refusal and the sent card', (tester) async {
      final h = _harness(routes: {'POST /contact': (_) => _badRequest});
      await _pump(tester, h, size: const Size(390, 1250), onRaise: () {}, onQuote: () {});
      await _shot(tester, 'contact_form');

      await _type(tester, 'name', '');
      await _type(tester, 'email', 'bharat@');
      await _tapSend(tester);
      await tester.pumpAndSettle();
      await _shot(tester, 'contact_reasons');

      await _type(tester, 'name', 'Bharat Buyer');
      await _type(tester, 'email', 'buyer@icr.dev');
      await _type(tester, 'message', 'We would like to know more about chapter membership.');
      await _topic(tester, ContactTopic.partnership);
      await _tapSend(tester);
      await tester.pumpAndSettle();
      await _shot(tester, 'contact_refused');

      h.api.routes['POST /contact'] = (_) => {'id': 'lead-1'};
      await _tapSend(tester);
      await tester.pumpAndSettle();
      await _shot(tester, 'contact_sent');
      expect(_key('contact-sent'), findsOneWidget);
    });

    testWidgets('a small phone with the keyboard up', (tester) async {
      final h = _harness(signedIn: false);
      await _pump(tester, h, size: _small, keyboard: 260);
      await _shot(tester, 'contact_small');
      expect(tester.takeException(), isNull);
    });
  });
}
