import 'dart:convert';

import '../../core/api/api_client.dart';

/// The person's session, handed to the website inside the in-app web view so a
/// signed-in page opens signed in.
///
/// Only the ACCESS token goes across. The website keeps its tokens in
/// `localStorage` (`icr.accessToken`, `icr.refreshToken`, see
/// `frontend/src/lib/api.ts`), and the API's refresh tokens are single use and
/// rotated: a web view that held the app's refresh token would spend it, and
/// the app's next refresh would end the app's own session. So the page gets a
/// fresh 15-minute access token and none to renew it; the web screen hands it
/// a new one while it is open ([WebSessionBridge.renewEvery]).
class WebSessionBridge {
  WebSessionBridge(this._api);

  final ApiClient _api;

  /// How often an open page gets a fresh access token (the token lives 15 minutes).
  static const renewEvery = Duration(minutes: 9);

  /// Renewed when it has less than this left.
  static const minLifetime = Duration(minutes: 3);

  /// An access token with at least [minLifetime] left, renewing it through the
  /// app's own session when needed; null when signed out.
  Future<String?> freshAccessToken() async {
    var access = await _api.tokens.accessToken();
    if (access == null) return null;
    final left = secondsLeft(access);
    if ((left == null || left < minLifetime.inSeconds) && await _api.tokens.refreshToken() != null) {
      if (await _api.refresh()) access = await _api.tokens.accessToken();
    }
    return access;
  }

  /// Seconds before a JWT's `exp`; null when it carries none.
  static int? secondsLeft(String jwt, {DateTime? now}) {
    final parts = jwt.split('.');
    if (parts.length != 3) return null;
    try {
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))) as Map<String, dynamic>;
      final exp = payload['exp'];
      if (exp is! num) return null;
      return exp.toInt() - ((now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000);
    } catch (_) {
      return null;
    }
  }

  /// The script that puts [accessToken] where the website reads it, and removes
  /// any refresh token an earlier page left, so the page never renews on its own.
  static String script(String accessToken) =>
      "try{localStorage.setItem('icr.accessToken',${jsonEncode(accessToken)});localStorage.removeItem('icr.refreshToken');}catch(e){}";

  /// What clears the session from the page's storage when the screen closes.
  static const clearScript =
      "try{localStorage.removeItem('icr.accessToken');localStorage.removeItem('icr.refreshToken');}catch(e){}";
}
