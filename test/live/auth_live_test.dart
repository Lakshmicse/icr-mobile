import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/auth/auth_controller.dart';
import 'package:icr_mobile/core/auth/social_sign_in.dart';

import 'live.dart';

AuthController _controller(MemoryTokens tokens) => AuthController(
  api: ApiClient(tokens: tokens, baseUrl: liveBaseUrl),
  tokens: tokens,
  retryDelay: Duration.zero,
);

void main() {
  liveTest('the sign-in card signs a seeded person in, and a saved session resumes', () async {
    final tokens = MemoryTokens();
    final auth = _controller(tokens);

    await auth.signIn(email: bharat.email, password: bharat.password, rememberMe: false);

    expect(auth.status, SessionStatus.signedIn);
    expect(auth.user?.email, bharat.email);
    expect(await tokens.accessToken(), isNotEmpty);

    // A new controller over the same saved tokens is signed in without a password.
    final resumed = _controller(tokens);
    await resumed.restore();
    expect(resumed.status, SessionStatus.signedIn);
    expect(resumed.user?.email, bharat.email);

    await auth.signOut();
    expect(auth.status, SessionStatus.signedOut);
    expect(await tokens.refreshToken(), isNull);
  });

  liveTest('the sign-in card asks for Remember me and the API accepts either choice', () async {
    for (final remember in [true, false]) {
      final auth = _controller(MemoryTokens());
      await auth.signIn(email: pooja.email, password: pooja.password, rememberMe: remember);
      expect(auth.status, SessionStatus.signedIn, reason: 'rememberMe: $remember');
      expect(auth.user?.email, pooja.email);
      await auth.signOut();
    }
  });

  liveTest('a wrong password is refused in the sentence the card shows', () async {
    final auth = _controller(MemoryTokens());

    await expectLater(
      auth.signIn(email: bharat.email, password: 'definitely-wrong', rememberMe: false),
      throwsA(isA<ApiError>().having((e) => e.message, 'message', 'Invalid email or password.')),
    );
    expect(auth.status, SessionStatus.unknown);
  });

  liveTest('the marks on the card are drawn for the providers this server has keys for', () async {
    final auth = _controller(MemoryTokens());

    final providers = await auth.configuredProviders();

    // Either, both or none have keys locally; the call itself must work and only name known providers.
    expect(SocialProvider.values.toSet().containsAll(providers), isTrue);
  });
}
