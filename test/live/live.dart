/// Helpers for the live tests: the app's own repositories against the LOCAL
/// portal API (http://localhost:3001/api/v1), signed in as a seeded persona.
///
/// A live test proves a control works end to end: it does the real thing
/// (an RSVP, a bookmark, an application) and reads the effect back through
/// the API, then undoes it where the API allows. When the API is not running
/// the tests are skipped, so `flutter test` stays green offline. Run only
/// them with `flutter test --tags live`; leave them out with `--exclude-tags live`.
///
/// The personas are the ones `tool/seed` fills in (see tool/seed/README.md).
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/auth/token_store.dart';

const liveBaseUrl = 'http://localhost:3001/api/v1';

/// A seeded account the tests sign in as.
class LivePerson {
  const LivePerson(this.email, this.password, this.label);

  final String email;
  final String password;
  final String label;
}

/// Bharat Buyer: the person the Android emulator is signed in as.
const bharat = LivePerson('buyer@icr.dev', 'Buyer@123', 'Bharat Buyer');

/// Pooja Professional: the e2e persona, a second person for two-sided checks.
const pooja = LivePerson('professional@icr.test', 'Test@12345', 'Pooja Professional');

/// Tokens kept in memory, so a live test never touches the platform keystore.
class MemoryTokens extends TokenStore {
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

bool? _reachable;

/// True when the local API answers; cached for the test run.
Future<bool> liveApiReachable() async {
  if (_reachable != null) return _reachable!;
  HttpOverrides.global = null; // flutter_test blocks HTTP by default
  try {
    final res = await Dio(
      BaseOptions(baseUrl: liveBaseUrl, connectTimeout: const Duration(seconds: 3)),
    ).get<dynamic>('/events', queryParameters: {'limit': 1});
    _reachable = res.statusCode == 200;
  } catch (_) {
    _reachable = false;
  }
  return _reachable!;
}

final _signedIn = <String, Future<ApiClient>>{};

/// An API client signed in as [who], one per person for the whole test file
/// (the API allows only a few sign-ins a minute). It waits out a "too many
/// requests" instead of failing: the portal allows 120 requests a minute for
/// everyone on this machine, and the other screens' live tests share that.
/// Pass [fresh] for a session of its own (one a test may sign out of).
///
/// Throws when the API is down: call [liveApiReachable] first and skip the test
/// when it is false.
Future<ApiClient> liveClient([LivePerson who = bharat, bool fresh = false]) async {
  if (fresh) return _signIn(who);
  try {
    return await _signedIn.putIfAbsent(who.email, () => _signIn(who));
  } catch (_) {
    _signedIn.remove(who.email); // do not keep a failed sign-in
    rethrow;
  }
}

Future<ApiClient> _signIn(LivePerson who) async {
  HttpOverrides.global = null;
  for (var attempt = 0; ; attempt++) {
    final tokens = MemoryTokens();
    final client = ApiClient(tokens: tokens, baseUrl: liveBaseUrl);
    try {
      final res = await client.dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'email': who.email, 'password': who.password, 'rememberMe': false},
      );
      await tokens.save(
        accessToken: res.data!['accessToken'] as String,
        refreshToken: res.data!['refreshToken'] as String,
      );
      client.dio.interceptors.add(_waitWhenThrottled(client.dio));
      return client;
    } on DioException catch (e) {
      if (e.response?.statusCode != 429 || attempt >= 6) rethrow;
      final wait = int.tryParse(e.response?.headers.value('retry-after') ?? '') ?? 12;
      await Future<void>.delayed(Duration(seconds: wait.clamp(2, 40)));
    }
  }
}

/// Retries a request the API refused as "too many", after the wait it asks for.
Interceptor _waitWhenThrottled(Dio dio) => InterceptorsWrapper(
  onError: (error, handler) async {
    final tries = (error.requestOptions.extra['throttled'] as int?) ?? 0;
    if (error.response?.statusCode != 429 || tries >= 6) return handler.next(error);
    final wait = int.tryParse(error.response?.headers.value('retry-after') ?? '') ?? 8;
    await Future<void>.delayed(Duration(seconds: wait.clamp(2, 30)));
    error.requestOptions.extra['throttled'] = tries + 1;
    try {
      handler.resolve(await dio.fetch(error.requestOptions));
    } on DioException catch (again) {
      handler.next(again);
    }
  },
);

/// An anonymous client, for the public reads.
ApiClient liveAnonymous() {
  HttpOverrides.global = null;
  final client = ApiClient(tokens: MemoryTokens(), baseUrl: liveBaseUrl);
  client.dio.interceptors.add(_waitWhenThrottled(client.dio));
  return client;
}

/// Declares a live test: skipped, with a reason, when the API is not running.
///
///     liveTest('an RSVP is kept and can be taken back', () async { ... });
void liveTest(String description, Future<void> Function() body, {Timeout? timeout}) {
  test(
    description,
    () async {
      if (!await liveApiReachable()) {
        markTestSkipped('the local API is not running at $liveBaseUrl');
        return;
      }
      await body();
    },
    tags: const ['live'],
    timeout: timeout ?? const Timeout(Duration(minutes: 2)),
  );
}
