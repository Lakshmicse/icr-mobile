import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../api/api_error.dart';
import 'session_user.dart';
import 'social_sign_in.dart';
import 'token_store.dart';

enum SessionStatus { unknown, signedOut, signedIn }

/// Who is signed in. Drives the app's first screen.
class AuthController extends ChangeNotifier {
  AuthController({
    required this.api,
    required this.tokens,
    SocialSignIn? social,
    this.retryDelay = const Duration(seconds: 1),
  }) : social = social ?? SocialSignIn() {
    api.onSessionExpired = _expire;
  }

  final ApiClient api;
  final TokenStore tokens;
  final SocialSignIn social;

  /// The pause before asking the API for the person again, after an answer that
  /// was not a refusal. It grows with each try.
  final Duration retryDelay;

  SessionStatus _status = SessionStatus.unknown;
  SessionUser? _user;
  bool _expired = false;
  bool _disposed = false;

  SessionStatus get status => _status;
  SessionUser? get user => _user;

  /// True once, after a session ran out under the person's feet.
  bool takeExpiredNotice() {
    final was = _expired;
    _expired = false;
    return was;
  }

  /// Resumes a saved session, if there is one.
  ///
  /// The API not answering (a slow start, a busy server, a rate limit, a bad
  /// connection) is not a refusal: the person is asked for a few times before the
  /// app opens without their name and photo, and it keeps asking after that, so
  /// the header fills in without a restart.
  Future<void> restore() async {
    if (await tokens.refreshToken() == null) {
      _set(SessionStatus.signedOut, null);
      return;
    }
    for (var attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) await Future<void>.delayed(retryDelay * attempt);
      switch (await _loadUser()) {
        case _UserLoad.loaded:
          return;
        case _UserLoad.refused:
          await tokens.clear();
          _set(SessionStatus.signedOut, null);
          return;
        case _UserLoad.failed:
          break;
      }
    }
    // Offline at launch: keep the session and let the screens retry.
    _set(SessionStatus.signedIn, null);
    unawaited(_loadUserLater());
  }

  Future<_UserLoad> _loadUser() async {
    try {
      final res = await api.dio.get<Map<String, dynamic>>('/auth/me');
      _set(SessionStatus.signedIn, SessionUser.fromJson(res.data!));
      return _UserLoad.loaded;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      return status == 401 || status == 403 ? _UserLoad.refused : _UserLoad.failed;
    }
  }

  /// After opening without the person: ask again, less often each time, until
  /// they are known, the API refuses, or they sign out.
  Future<void> _loadUserLater() async {
    for (var attempt = 1; attempt <= 6; attempt++) {
      await Future<void>.delayed(retryDelay * attempt * 4);
      if (_disposed || _status != SessionStatus.signedIn || _user != null) return;
      if (await _loadUser() != _UserLoad.failed) return;
    }
  }

  /// `POST /auth/login`. Throws [ApiError] with a sentence to show.
  Future<void> signIn({required String email, required String password, required bool rememberMe}) async {
    try {
      final res = await api.dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'email': email.trim(), 'password': password, 'rememberMe': rememberMe},
      );
      await _adopt(res.data!);
    } catch (e) {
      final error = ApiError.from(e);
      // The API answers "Invalid credentials" for both an unknown email and a
      // wrong password; say it the way the website does.
      if (error.statusCode == 401 && error.message == 'Invalid credentials') {
        throw ApiError('Invalid email or password.', statusCode: 401);
      }
      throw error;
    }
  }

  // --- Google / LinkedIn -----------------------------------------------------

  /// `GET /auth/social/providers`: the ones with keys on this server. The
  /// buttons for the others are drawn disabled, as on the website.
  Future<Set<SocialProvider>> configuredProviders() async {
    try {
      final res = await api.dio.get<Map<String, dynamic>>('/auth/social/providers');
      final names = (res.data?['providers'] as List? ?? const []).cast<String>().toSet();
      return {
        for (final p in SocialProvider.values)
          if (names.contains(p.apiName)) p,
      };
    } catch (_) {
      return const {};
    }
  }

  /// Runs the provider round-trip. Someone with an ICR account comes back
  /// signed in (returns null); someone new comes back with a [SocialSignup]
  /// for the short sign-up. Closing the tab changes nothing. Throws [ApiError].
  Future<SocialSignup?> signInWith(SocialProvider provider) async {
    final result = await social.run(provider);
    switch (result) {
      case SocialCancelled():
        return null;
      case SocialSignup():
        return result;
      case SocialCode(:final code, :final verifier):
        try {
          final res = await api.dio.post<Map<String, dynamic>>(
            '/auth/social/exchange',
            data: {'code': code, if (verifier.isNotEmpty) 'verifier': verifier},
          );
          await _adopt(res.data!);
          return null;
        } catch (e) {
          throw ApiError.from(e);
        }
    }
  }

  /// `POST /auth/social/pending`: what the provider told us, to prefill sign-up.
  Future<PendingSocialProfile> readPending(String token) async {
    try {
      final res = await api.dio.post<Map<String, dynamic>>('/auth/social/pending', data: {'token': token});
      return PendingSocialProfile.fromJson(res.data!);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  /// Sends the 6-digit sign-up code. Off production the API hands the code
  /// back instead of mailing it; that comes back here to show on screen.
  Future<String?> sendEmailCode(String email) async {
    try {
      final res = await api.dio.post<Map<String, dynamic>>('/auth/email/send-code', data: {'email': email});
      return res.data?['code'] as String?;
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<void> verifyEmailCode(String email, String code) async {
    try {
      await api.dio.post<void>('/auth/email/verify-code', data: {'email': email, 'code': code});
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  /// `POST /auth/register` with the provider's token (and the app's secret
  /// that unlocks it): the account is made and signed in.
  Future<void> completeSocialSignup({
    required SocialSignup signup,
    required String firstName,
    required String lastName,
  }) async {
    try {
      final res = await api.dio.post<Map<String, dynamic>>(
        '/auth/register',
        data: {
          'socialToken': signup.token,
          if (signup.verifier.isNotEmpty) 'socialVerifier': signup.verifier,
          'firstName': firstName.trim(),
          'lastName': lastName.trim(),
          'acceptTerms': true,
          'termsVersion': termsVersion,
        },
      );
      await _adopt(res.data!);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  /// The terms "Agree & join" accepts; the website's `TERMS_VERSION`.
  static const termsVersion = '2026-07-01';

  /// `POST /auth/register` with an email and password, after the 6-digit code
  /// has been checked (`verifyEmailCode`): the account is made and signed in,
  /// as the website's "About you" screen does. A taken address is a 409.
  Future<void> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    try {
      final res = await api.dio.post<Map<String, dynamic>>(
        '/auth/register',
        data: {
          'firstName': firstName.trim(),
          'lastName': lastName.trim(),
          'email': email.trim().toLowerCase(),
          'password': password,
          'acceptTerms': true,
          'termsVersion': termsVersion,
        },
      );
      await _adopt(res.data!);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  /// `POST /auth/forgot-password`: the API emails a reset link (which opens the
  /// website) when the address has an account, and answers the same either way.
  Future<void> requestPasswordReset(String email) async {
    try {
      await api.dio.post<void>('/auth/forgot-password', data: {'email': email.trim()});
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  /// Takes a fresh token pair the API handed back (switching company, founding
  /// one): every later call uses it. The person is read again, since their role
  /// rides in the token; [user] spares that read when the response carried it.
  Future<void> adoptSession({
    required String accessToken,
    required String refreshToken,
    Map<String, dynamic>? user,
  }) async {
    await tokens.save(accessToken: accessToken, refreshToken: refreshToken);
    if (user != null) {
      _set(SessionStatus.signedIn, SessionUser.fromJson(user));
    } else {
      await refreshUser();
    }
  }

  /// Signs out on this phone without telling the API, for an account that is
  /// already gone (deleted) and whose tokens the API no longer knows.
  Future<void> forgetSession() async {
    await tokens.clear();
    _set(SessionStatus.signedOut, null);
  }

  Future<void> _adopt(Map<String, dynamic> data) async {
    await tokens.save(accessToken: data['accessToken'] as String, refreshToken: data['refreshToken'] as String);
    _set(SessionStatus.signedIn, SessionUser.fromJson(data['user'] as Map<String, dynamic>));
  }

  Future<void> signOut() async {
    final refreshToken = await tokens.refreshToken();
    await tokens.clear();
    _set(SessionStatus.signedOut, null);
    if (refreshToken != null) {
      try {
        await api.dio.post<void>('/auth/logout', data: {'refreshToken': refreshToken});
      } catch (_) {
        // Signing out locally is what matters; the token expires on its own.
      }
    }
  }

  Future<void> refreshUser() async {
    try {
      final res = await api.dio.get<Map<String, dynamic>>('/auth/me');
      _set(SessionStatus.signedIn, SessionUser.fromJson(res.data!));
    } catch (_) {}
  }

  void _expire() {
    if (_status != SessionStatus.signedIn) return;
    _expired = true;
    tokens.clear();
    _set(SessionStatus.signedOut, null);
  }

  void _set(SessionStatus status, SessionUser? user) {
    if (_disposed) return;
    _status = status;
    _user = user;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// A first-time social user, as the provider described them.
class PendingSocialProfile {
  const PendingSocialProfile({
    required this.provider,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.emailVerified,
    this.avatarUrl,
  });

  final String provider;
  final String email;
  final String firstName;
  final String lastName;
  final String? avatarUrl;

  /// False when the provider would not vouch for the address: sign-up then
  /// asks for the emailed 6-digit code, as on the website.
  final bool emailVerified;

  factory PendingSocialProfile.fromJson(Map<String, dynamic> json) => PendingSocialProfile(
    provider: json['provider'] as String? ?? '',
    email: json['email'] as String? ?? '',
    firstName: json['firstName'] as String? ?? '',
    lastName: json['lastName'] as String? ?? '',
    avatarUrl: json['avatarUrl'] as String?,
    emailVerified: json['emailVerified'] != false,
  );
}

enum _UserLoad { loaded, refused, failed }
