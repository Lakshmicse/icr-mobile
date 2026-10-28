import 'dart:convert';

import 'package:dio/dio.dart';

import '../auth/token_store.dart';
import '../config.dart';

/// HTTP to the ICR API (`/api/v1`), bearer-authenticated like the web app.
///
/// The access token lives 15 minutes. It is refreshed before it runs out,
/// because the forum's public reads treat an expired token as anonymous
/// (200 with no `myReaction`/`saved`, never a 401), and once more on any 401.
/// Refresh tokens are single use, so concurrent callers share one refresh.
class ApiClient {
  ApiClient({required this.tokens, String? baseUrl}) : dio = Dio(_options(baseUrl)), _plain = Dio(_options(baseUrl)) {
    dio.interceptors.add(InterceptorsWrapper(onRequest: _onRequest, onError: _onError));
  }

  final TokenStore tokens;
  final Dio dio;
  final Dio _plain;
  Future<bool>? _refreshing;

  /// Called when the session cannot be renewed (refresh token expired or revoked).
  void Function()? onSessionExpired;

  static BaseOptions _options(String? baseUrl) => BaseOptions(
    baseUrl: baseUrl ?? AppConfig.apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
    headers: {'Accept': 'application/json', 'Accept-Language': 'en'},
  );

  static bool _isAuthRoute(String path) =>
      path.startsWith('/auth/login') || path.startsWith('/auth/refresh') || path.startsWith('/auth/logout');

  Future<void> _onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (!_isAuthRoute(options.path)) {
      var access = await tokens.accessToken();
      if (access != null && _expiresSoon(access) && await tokens.refreshToken() != null) {
        if (await refresh()) access = await tokens.accessToken();
      }
      if (access != null) options.headers['Authorization'] = 'Bearer $access';
    }
    handler.next(options);
  }

  Future<void> _onError(DioException error, ErrorInterceptorHandler handler) async {
    final options = error.requestOptions;
    final retried = options.extra['retried'] == true;
    if (error.response?.statusCode != 401 || retried || _isAuthRoute(options.path)) {
      return handler.next(error);
    }
    if (await tokens.refreshToken() == null || !await refresh()) {
      onSessionExpired?.call();
      return handler.next(error);
    }
    try {
      options.extra['retried'] = true;
      options.headers['Authorization'] = 'Bearer ${await tokens.accessToken()}';
      handler.resolve(await dio.fetch(options));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  /// Swaps the refresh token for a new pair. One request at a time.
  Future<bool> refresh() => _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);

  Future<bool> _doRefresh() async {
    final refreshToken = await tokens.refreshToken();
    if (refreshToken == null) return false;
    try {
      final res = await _plain.post<Map<String, dynamic>>('/auth/refresh', data: {'refreshToken': refreshToken});
      final data = res.data!;
      await tokens.save(accessToken: data['accessToken'] as String, refreshToken: data['refreshToken'] as String);
      return true;
    } on DioException catch (e) {
      // A network failure is not a lost session; only the API's refusal is.
      if (e.response?.statusCode == 401) await tokens.clear();
      return false;
    }
  }

  static bool _expiresSoon(String jwt) {
    try {
      final payload = jwt.split('.')[1];
      final json = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(payload)))) as Map<String, dynamic>;
      final exp = json['exp'];
      if (exp is! num) return false;
      final expiry = DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
      return expiry.isBefore(DateTime.now().add(const Duration(seconds: 30)));
    } catch (_) {
      return false;
    }
  }
}
