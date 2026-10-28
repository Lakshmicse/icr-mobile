import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';

/// What `POST /auth/forgot-password` answered. The API says the same whether or
/// not the address has an account; only an API with no mail provider (local
/// development) adds [resetUrl], the link it would have emailed.
class ResetRequested {
  const ResetRequested({this.resetUrl});

  final String? resetUrl;
}

/// What `POST /auth/resend-verification` answered: [sent] is false for an
/// address that is already confirmed. [verifyUrl] rides back only when no mail
/// provider can deliver it.
class VerificationRequested {
  const VerificationRequested({required this.sent, this.verifyUrl});

  final bool sent;
  final String? verifyUrl;
}

/// The two emailed links the website finishes on its own pages
/// (`/reset-password?token=`, `/verify-email?token=`), taken in the app: the
/// recovery calls, all public except the resend. Every failure is an
/// [ApiError] carrying the API's own sentence.
abstract class RecoveryRepository {
  /// `POST /auth/forgot-password`.
  Future<ResetRequested> requestReset(String email);

  /// `POST /auth/reset-password`: sets the password and ends every session.
  Future<void> resetPassword({required String token, required String password});

  /// `POST /auth/verify-email`: confirms the address. True when it already was.
  Future<bool> verifyEmail(String token);

  /// `POST /auth/resend-verification` (signed in).
  Future<VerificationRequested> resendVerification();
}

class ApiRecoveryRepository implements RecoveryRepository {
  ApiRecoveryRepository({required this.api});

  final ApiClient api;

  Future<T> _call<T>(Future<T> Function(Dio dio) body) async {
    try {
      return await body(api.dio);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  @override
  Future<ResetRequested> requestReset(String email) => _call((dio) async {
    final res = await dio.post<Map<String, dynamic>>('/auth/forgot-password', data: {'email': email.trim()});
    return ResetRequested(resetUrl: _text(res.data?['resetUrl']));
  });

  @override
  Future<void> resetPassword({required String token, required String password}) =>
      _call((dio) => dio.post<void>('/auth/reset-password', data: {'token': token, 'password': password}));

  @override
  Future<bool> verifyEmail(String token) => _call((dio) async {
    final res = await dio.post<Map<String, dynamic>>('/auth/verify-email', data: {'token': token});
    return res.data?['alreadyVerified'] == true;
  });

  @override
  Future<VerificationRequested> resendVerification() => _call((dio) async {
    final res = await dio.post<Map<String, dynamic>>('/auth/resend-verification');
    return VerificationRequested(sent: res.data?['sent'] == true, verifyUrl: _text(res.data?['verifyUrl']));
  });

  static String? _text(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;
}

/// The token in whatever the person pasted: the emailed link
/// (`https://icr.org.in/reset-password?token=abc…`), the query alone, or the
/// token itself. Null when nothing in it looks like one.
String? tokenFromLink(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  final uri = Uri.tryParse(text);
  final fromQuery = uri?.queryParameters['token'];
  if (fromQuery != null && fromQuery.trim().isNotEmpty) return fromQuery.trim();
  // A bare token: letters, digits and the URL-safe symbols, no spaces or slashes.
  if (RegExp(r'^[A-Za-z0-9_\-.~]{16,}$').hasMatch(text)) return text;
  // "token=abc" with no address in front of it.
  final match = RegExp(r'token=([A-Za-z0-9_\-.~%]+)').firstMatch(text);
  return match == null ? null : Uri.decodeComponent(match.group(1)!);
}
