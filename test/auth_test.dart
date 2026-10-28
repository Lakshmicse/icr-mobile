import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/auth/auth_controller.dart';
import 'package:icr_mobile/core/auth/social_sign_in.dart';
import 'package:icr_mobile/core/auth/token_store.dart';

/// Tokens kept in memory instead of the platform keystore.
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

/// Records each request and answers from a table.
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

/// Plays back a provider round-trip without a browser.
class _FakeSocial extends SocialSignIn {
  _FakeSocial(this.result);
  final SocialResult result;

  @override
  Future<SocialResult> run(SocialProvider provider) async => result;
}

const _session = {
  'accessToken': 'a1',
  'refreshToken': 'r1',
  'user': {'id': 'u1', 'email': 'sam@acme.com', 'firstName': 'Sam', 'lastName': 'Rao', 'role': 'PROFESSIONAL'},
};

AuthController _auth(_Api api, _MemoryTokens tokens, SocialResult result) {
  final client = ApiClient(tokens: tokens, baseUrl: 'http://api.test/api/v1');
  client.dio.httpClientAdapter = api;
  return AuthController(api: client, tokens: tokens, social: _FakeSocial(result));
}

void main() {
  test('a returning member swaps the code, with the app secret, for a session', () async {
    final api = _Api({'POST /auth/social/exchange': (_) => _session});
    final tokens = _MemoryTokens();
    final auth = _auth(api, tokens, const SocialCode('code-1', 'secret-1'));

    final signup = await auth.signInWith(SocialProvider.google);

    expect(signup, isNull);
    expect(api.calls.single.$2, {'code': 'code-1', 'verifier': 'secret-1'});
    expect(auth.status, SessionStatus.signedIn);
    expect(auth.user?.fullName, 'Sam Rao');
    expect(tokens.refresh, 'r1');
  });

  test('the website flow (the server as deployed) swaps the code alone, with no app secret', () async {
    final api = _Api({'POST /auth/social/exchange': (_) => _session});
    final tokens = _MemoryTokens();
    final auth = _auth(api, tokens, const SocialCode('code-2', ''));

    expect(await auth.signInWith(SocialProvider.google), isNull);

    expect(api.calls.single.$2, {'code': 'code-2'}, reason: 'the deployed exchange takes only the one-time code');
    expect(auth.status, SessionStatus.signedIn);
  });

  test('someone new gets the sign-up, which sends the token and the app secret', () async {
    final api = _Api({'POST /auth/register': (_) => _session});
    final tokens = _MemoryTokens();
    final auth = _auth(api, tokens, const SocialSignup('pending-1', 'secret-2'));

    final signup = await auth.signInWith(SocialProvider.linkedin);
    expect(signup, isA<SocialSignup>());
    expect(auth.status, isNot(SessionStatus.signedIn));

    await auth.completeSocialSignup(signup: signup!, firstName: ' Sam ', lastName: 'Rao');

    final sent = api.calls.single.$2!;
    expect(sent['socialToken'], 'pending-1');
    expect(sent['socialVerifier'], 'secret-2');
    expect(sent['firstName'], 'Sam');
    expect(sent['acceptTerms'], isTrue);
    expect(auth.status, SessionStatus.signedIn);
  });

  test('closing the browser tab changes nothing', () async {
    final api = _Api({});
    final auth = _auth(api, _MemoryTokens(), const SocialCancelled());
    expect(await auth.signInWith(SocialProvider.google), isNull);
    expect(api.calls, isEmpty);
    expect(auth.status, SessionStatus.unknown);
  });

  test("an expired code shows the API's sentence", () async {
    final api = _Api({
      'POST /auth/social/exchange': (_) => (401, '{"statusCode":401,"message":"This sign-in link has expired."}'),
    });
    final auth = _auth(api, _MemoryTokens(), const SocialCode('old', 'secret'));
    await expectLater(
      auth.signInWith(SocialProvider.google),
      throwsA(isA<ApiError>().having((e) => e.message, 'message', 'This sign-in link has expired.')),
    );
  });

  test('only the providers this server has keys for are offered', () async {
    final api = _Api({
      'GET /auth/social/providers': (_) => {
        'providers': ['GOOGLE'],
      },
    });
    final auth = _auth(api, _MemoryTokens(), const SocialCancelled());
    expect(await auth.configuredProviders(), {SocialProvider.google});
  });

  group('resuming a saved session', () {
    const me = {'id': 'u1', 'email': 'sam@acme.com', 'firstName': 'Sam', 'lastName': 'Rao', 'role': 'PROFESSIONAL'};

    AuthController resume(_Api api) {
      final tokens = _MemoryTokens()
        ..access = 'a1'
        ..refresh = 'r1';
      final client = ApiClient(tokens: tokens, baseUrl: 'http://api.test/api/v1');
      client.dio.httpClientAdapter = api;
      return AuthController(api: client, tokens: tokens, retryDelay: Duration.zero);
    }

    test('an API that cannot answer yet is asked again, and then the person is known', () async {
      var asked = 0;
      final api = _Api({'GET /auth/me': (_) => ++asked < 3 ? (503, '{"message":"Busy"}') : me});
      final auth = resume(api);

      await auth.restore();

      expect(asked, 3);
      expect(auth.status, SessionStatus.signedIn);
      expect(auth.user?.id, 'u1');
    });

    test('a launch that keeps failing opens signed in, and the details arrive when the API answers', () async {
      var asked = 0;
      final api = _Api({'GET /auth/me': (_) => ++asked <= 3 ? (429, '{"message":"Too Many Requests"}') : me});
      final auth = resume(api);

      await auth.restore();
      expect(auth.status, SessionStatus.signedIn);
      expect(auth.user, isNull);

      // The background ask, with no delay in the test.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(auth.user?.id, 'u1');
      expect(asked, 4);
    });

    test('a refused token signs the person out', () async {
      final api = _Api({'GET /auth/me': (_) => (401, '{"message":"Unauthorized"}')});
      final auth = resume(api);

      await auth.restore();

      expect(auth.status, SessionStatus.signedOut);
      expect(auth.user, isNull);
    });
  });
}
