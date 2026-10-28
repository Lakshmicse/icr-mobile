/// A stand-in for the ICR API for the account, auth, companies and saved-items
/// widget tests: an [HttpClientAdapter] that answers each `METHOD /path` from a
/// table, records every call with its body and query, and builds the same
/// `ApiClient` / `AuthController` the app uses over it.
library;

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/auth/auth_controller.dart';
import 'package:icr_mobile/core/auth/social_sign_in.dart';
import 'package:icr_mobile/core/auth/token_store.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:provider/provider.dart';

/// Tokens kept in memory instead of the platform keystore.
class MemoryTokenStore extends TokenStore {
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

/// One request the app made.
class ApiCall {
  ApiCall(this.method, this.path, this.query, this.body);

  final String method;
  final String path;
  final Map<String, dynamic> query;

  /// The decoded JSON body, a [FormData], or null.
  final Object? body;

  String get key => '$method $path';

  Map<String, dynamic> get json => body is Map ? (body as Map).cast<String, dynamic>() : const {};

  @override
  String toString() => '$key $query $body';
}

/// An answer other than 200 with JSON.
class ApiReply {
  const ApiReply(this.status, this.body);

  /// The API's refusal shape: `{ statusCode, message, path, timestamp }`.
  factory ApiReply.refusal(int status, Object message, {String? code}) =>
      ApiReply(status, {'statusCode': status, 'message': message, 'code': ?code});

  final int status;
  final Object? body;
}

typedef ApiHandler = FutureOr<Object?> Function(ApiCall call);

/// Answers from [routes], keyed `'GET /me/companies'` (the path has no query).
/// A handler returns the JSON to send (200), an [ApiReply], or throws a
/// [DioException] for a transport failure ([offline]). A route with no handler
/// answers 404.
class FakeApi implements HttpClientAdapter {
  FakeApi(Map<String, ApiHandler> routes) : routes = {...routes};

  final Map<String, ApiHandler> routes;
  final List<ApiCall> calls = [];

  /// Calls wait on this when set (to show a loading state).
  Completer<void>? gate;

  static final _json = {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  };

  /// What a dead connection looks like to the app.
  static DioException offline(RequestOptions o) =>
      DioException(requestOptions: o, type: DioExceptionType.connectionError);

  Iterable<ApiCall> where(String key) => calls.where((c) => c.key == key);
  int count(String key) => where(key).length;
  ApiCall last(String key) => where(key).last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final data = options.data;
    final call = ApiCall(options.method, options.path, options.queryParameters, data);
    calls.add(call);
    if (gate != null) await gate!.future;
    final handler = routes[call.key];
    if (handler == null) {
      return ResponseBody.fromString(jsonEncode({'statusCode': 404, 'message': 'Not found'}), 404, headers: _json);
    }
    final Object? result;
    try {
      result = await handler(call);
    } on _Offline {
      throw offline(options);
    }
    if (result is ApiReply) {
      return ResponseBody.fromString(jsonEncode(result.body), result.status, headers: _json);
    }
    return ResponseBody.fromString(jsonEncode(result), 200, headers: _json);
  }

  @override
  void close({bool force = false}) {}
}

class _Offline implements Exception {
  const _Offline();
}

/// Throw from a handler for "the phone has no connection".
Never throwOffline() => throw const _Offline();

/// A provider round trip that never happens.
class NoSocial extends SocialSignIn {
  @override
  Future<SocialResult> run(SocialProvider provider) async => const SocialCancelled();
}

/// The signed-in person, as `POST /auth/login` and `GET /auth/me` give them.
Map<String, dynamic> userJson({
  String id = 'u1',
  String email = 'sam@acme.com',
  String first = 'Sam',
  String last = 'Rao',
  String role = 'PROFESSIONAL',
  bool emailVerified = true,
  String? companyId,
}) => {
  'id': id,
  'email': email,
  'firstName': first,
  'lastName': last,
  'role': role,
  'avatarUrl': null,
  'companyId': companyId,
  'emailVerified': emailVerified,
};

Map<String, dynamic> sessionJson({Map<String, dynamic>? user}) => {
  'accessToken': 'a1',
  'refreshToken': 'r1',
  'user': user ?? userJson(),
};

/// The app's own client and auth controller over a [FakeApi].
class AccountHarness {
  AccountHarness._(this.api, this.tokens, this.client, this.auth);

  factory AccountHarness({Map<String, ApiHandler> routes = const {}}) {
    final api = FakeApi({
      'GET /auth/social/providers': (_) => {
        'providers': ['GOOGLE'],
      },
      ...routes,
    });
    final tokens = MemoryTokenStore();
    final client = ApiClient(tokens: tokens, baseUrl: 'http://api.test/api/v1');
    client.dio.httpClientAdapter = api;
    final auth = AuthController(api: client, tokens: tokens, social: NoSocial(), retryDelay: Duration.zero);
    return AccountHarness._(api, tokens, client, auth);
  }

  final FakeApi api;
  final MemoryTokenStore tokens;
  final ApiClient client;
  final AuthController auth;

  /// Signs the harness in as [user] without a round trip. Inside `testWidgets`
  /// call [signIn] instead: the HTTP stack needs real event-loop turns, which
  /// the test's fake clock never gives a bare `await`.
  Future<void> signedIn([Map<String, dynamic>? user]) async {
    await tokens.save(accessToken: 'a1', refreshToken: 'r1');
    api.routes['GET /auth/me'] = (_) => user ?? userJson();
    await auth.restore();
  }

  /// [signedIn] from inside a widget test.
  Future<void> signIn(WidgetTester tester, [Map<String, dynamic>? user]) async {
    await tester.runAsync(() => signedIn(user));
  }

  /// [child] under the app's theme with the auth controller and client in
  /// `Provider`, as the app mounts every screen.
  Widget app(Widget child, {NavigatorObserver? observer}) => MultiProvider(
    providers: [
      Provider<ApiClient>.value(value: client),
      ChangeNotifierProvider<AuthController>.value(value: auth),
    ],
    child: MaterialApp(theme: buildAppTheme(), navigatorObservers: [?observer], home: child),
  );
}

/// Sizes the test view to a phone 390 dp wide (2x), or [width] x [height] dp.
void usePhone(WidgetTester tester, {double width = 390, double height = 844}) {
  tester.view.physicalSize = Size(width * 2, height * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}
