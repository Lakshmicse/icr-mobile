import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../api/api_error.dart';
import '../config.dart';

/// The sign-in providers the API knows (`AuthProvider`).
enum SocialProvider { linkedin, google }

extension SocialProviderInfo on SocialProvider {
  String get label => switch (this) {
    SocialProvider.google => 'Google',
    SocialProvider.linkedin => 'LinkedIn',
  };

  String get apiName => name.toUpperCase();

  String get icon => 'assets/images/brand/$name.svg';
}

/// Where a provider round-trip ended up.
sealed class SocialResult {
  const SocialResult();
}

/// The person has an ICR account: [code] swaps for a session.
class SocialCode extends SocialResult {
  const SocialCode(this.code, this.verifier);
  final String code;
  final String verifier;
}

/// First time on ICR: [token] starts the short sign-up (`/auth/register`).
class SocialSignup extends SocialResult {
  const SocialSignup(this.token, this.verifier);
  final String token;
  final String verifier;
}

/// The person closed the browser tab.
class SocialCancelled extends SocialResult {
  const SocialCancelled();
}

/// Which return address the provider round-trip ends on.
enum SocialFlow {
  /// The server as deployed today: the API sends the browser back to the
  /// WEBSITE's `/auth/callback?code=…`, and the app takes that address from
  /// Chrome's Auth Tab, which hands an `https` return to the app only for a
  /// site that vouches for it (`/.well-known/assetlinks.json` on the website,
  /// `docs/GOOGLE_SIGN_IN_ANDROID.md`). Needs no backend change.
  website,

  /// The mobile addition to the API (not deployed yet): the app asks for
  /// `client=app` and the API returns to `in.org.icr://auth`.
  appRedirect,
}

/// Google / LinkedIn sign-in through the API's own OAuth flow, the one the
/// website uses, run in a secure browser tab.
///
/// [SocialFlow.website] (the default against an `https` API) needs nothing new
/// on the server. [SocialFlow.appRedirect] (the default against a local API,
/// or `--dart-define=SOCIAL_FLOW=app`) starts it with `client=app` and the S256
/// challenge of a secret the app keeps; the API returns to `in.org.icr://auth`
/// with a one-time code (or a sign-up token, or an error code), and only this
/// secret can redeem it. See `backend/src/modules/auth/social/app-challenge.ts`.
class SocialSignIn {
  static const callbackScheme = 'in.org.icr';

  /// The website page the API returns to after a successful provider sign-in.
  static const websiteCallbackPath = '/auth/callback';

  static const _flowDefine = String.fromEnvironment('SOCIAL_FLOW');

  static SocialFlow get flow => switch (_flowDefine) {
    'app' => SocialFlow.appRedirect,
    'website' => SocialFlow.website,
    _ => AppConfig.apiBaseUrl.startsWith('https://') ? SocialFlow.website : SocialFlow.appRedirect,
  };

  /// The website's sentences for the callback's error codes (`SOCIAL_ERRORS`).
  static const errors = {
    'provider_unavailable': 'That sign-in method is not available right now. Please use your password.',
    'state_invalid': 'That sign-in link expired before you got back. Please try again.',
    'exchange_failed': "We couldn't complete the sign-in. Please try again.",
    'no_email': 'That account has no email address we can use. Try another sign-in method.',
    'verify_with_password':
        'An ICR account already uses that email. Sign in with your password first, and we will link the two.',
    'account_disabled': 'That account has been disabled. Contact support if you think this is wrong.',
  };

  Future<SocialResult> run(SocialProvider provider) =>
      flow == SocialFlow.website ? _runWebsite(provider) : _runAppRedirect(provider);

  /// Starts the round-trip exactly as the website does and waits for the
  /// browser to land on the website's `/auth/callback?code=…`. A first-time
  /// member (`/register?social=…`) or a refusal (`/login?error=…`) lands on a
  /// different page of the website, which stays open in the tab: the person
  /// finishes there, or closes it, which reads as [SocialCancelled].
  Future<SocialResult> _runWebsite(SocialProvider provider) async {
    final start = Uri.parse('${AppConfig.apiBaseUrl}/auth/${provider.name}/start').replace(queryParameters: {'mode': 'login'});
    final String returned;
    try {
      returned = await FlutterWebAuth2.authenticate(
        url: start.toString(),
        callbackUrlScheme: 'https',
        options: FlutterWebAuth2Options(httpsHost: Uri.parse(AppConfig.siteUrl).host, httpsPath: websiteCallbackPath),
      );
    } on PlatformException catch (e) {
      if (e.code == 'CANCELED') return const SocialCancelled();
      throw ApiError("Couldn't open ${provider.label} sign-in. Please try again.");
    }
    final params = Uri.parse(returned).queryParameters;
    if (params['code'] case final code?) return SocialCode(code, '');
    if (params['social'] case final token?) return SocialSignup(token, '');
    throw ApiError(errors[params['error']] ?? "We couldn't complete the sign-in. Please try again.");
  }

  Future<SocialResult> _runAppRedirect(SocialProvider provider) async {
    final verifier = _randomSecret();
    final challenge = base64Url.encode(sha256.convert(ascii.encode(verifier)).bytes).replaceAll('=', '');
    final start = Uri.parse(
      '${AppConfig.apiBaseUrl}/auth/${provider.name}/start',
    ).replace(queryParameters: {'client': 'app', 'appChallenge': challenge, 'mode': 'login'});

    final String returned;
    try {
      returned = await FlutterWebAuth2.authenticate(url: start.toString(), callbackUrlScheme: callbackScheme);
    } on PlatformException catch (e) {
      if (e.code == 'CANCELED') return const SocialCancelled();
      throw ApiError("Couldn't open ${provider.label} sign-in. Please try again.");
    }

    final params = Uri.parse(returned).queryParameters;
    if (params['code'] case final code?) return SocialCode(code, verifier);
    if (params['signup'] case final token?) return SocialSignup(token, verifier);
    // The person turned the provider down: as quiet as closing the tab.
    if (params['error'] == 'cancelled') return const SocialCancelled();
    throw ApiError(errors[params['error']] ?? "We couldn't complete the sign-in. Please try again.");
  }

  /// 48 random bytes, base64url without padding: 64 characters.
  static String _randomSecret() {
    final random = Random.secure();
    final bytes = List<int>.generate(48, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}
