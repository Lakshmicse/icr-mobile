import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../core/config.dart';
import 'exam_models.dart';
import 'exam_repository.dart';

/// The exam flow from the API: the paper (`GET /learning/papers/:slug`), what it
/// costs (`/quote`, `/redeem`, `POST /learning/me/opens`), the answers
/// (`POST /learning/papers/:slug/attempts`), and the member's sittings and
/// certificates.
class ApiExamRepository implements ExamRepository {
  ApiExamRepository({required this.api});

  final ApiClient api;

  Dio get _dio => api.dio;

  @override
  Future<PaperSitting> sitting(String slug) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/learning/papers/${Uri.encodeComponent(slug)}');
      return PaperSitting.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      final lock = _lockOf(e);
      if (lock != null) throw PaperLockedException(lock);
      throw ApiError.from(e);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  /// `403 PAPER_LOCKED` (and `NO_CREDIT_LEFT`) carry what would open the paper.
  static PaperLock? _lockOf(DioException e) {
    final res = e.response;
    final data = res?.data;
    if (res?.statusCode != 403 || data is! Map) return null;
    final code = data['code'];
    if (code != 'PAPER_LOCKED' && code != 'NO_CREDIT_LEFT') return null;
    return PaperLock.fromJson(data.cast<String, dynamic>());
  }

  @override
  Future<PaperInfo> info(PaperRef ref) async {
    try {
      // The kind narrows the public list; a landing that got it wrong costs one more read, not a failure.
      for (final kind in [ref.isMock ? 'MOCK' : 'ASSESSMENT', null]) {
        final res = await _dio.get<dynamic>('/learning/papers', queryParameters: {'kind': ?kind});
        final rows = (res.data is List ? res.data as List : const []).cast<Map<String, dynamic>>();
        final row = rows.where((r) => r['slug'] == ref.slug).firstOrNull;
        if (row != null) return PaperInfo.fromJson(row);
      }
      throw ApiError('This paper is not available right now.', statusCode: 404);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  @override
  Future<PaperQuote> quote(String slug) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/learning/papers/${Uri.encodeComponent(slug)}/quote');
      return PaperQuote.fromJson(res.data ?? const {});
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  @override
  Future<RedeemResult> redeem(String slug) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>('/learning/papers/${Uri.encodeComponent(slug)}/redeem');
      final j = res.data ?? const {};
      return RedeemResult(spent: (j['spent'] as num?)?.toInt() ?? 0, credits: (j['credits'] as num?)?.toInt() ?? 0);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  @override
  Future<void> openWithPlan({required String target, required String targetId}) async {
    try {
      await _dio.post<dynamic>('/learning/me/opens', data: {'target': target, 'targetId': targetId});
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  @override
  Future<List<Attempt>> attempts({String? paperId}) async {
    try {
      final res = await _dio.get<dynamic>('/learning/me/attempts', queryParameters: {'paperId': ?paperId});
      final rows = (res.data is List ? res.data as List : const []).cast<Map<String, dynamic>>();
      return [for (final r in rows) Attempt.fromJson(r)];
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  @override
  Future<AttemptResult> attempt(String id) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/learning/me/attempts/${Uri.encodeComponent(id)}');
      return AttemptResult.fromJson(res.data ?? const {});
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  @override
  Future<AttemptResult> submit(
    String slug, {
    required DateTime startedAt,
    required List<SubmittedAnswer> answers,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/learning/papers/${Uri.encodeComponent(slug)}/attempts',
        data: {
          'startedAt': startedAt.millisecondsSinceEpoch,
          'answers': [for (final a in answers) a.toJson()],
        },
      );
      return AttemptResult.fromJson(res.data ?? const {});
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  @override
  Future<List<ExamCertificate>> certificates() async {
    try {
      final res = await _dio.get<dynamic>('/learning/me/certificates');
      final rows = (res.data is List ? res.data as List : const []).cast<Map<String, dynamic>>();
      return [for (final r in rows) ExamCertificate.fromJson(r)];
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  @override
  Future<ExamCertificate?> verifyCertificate(String certificateId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/learning/certificates/${Uri.encodeComponent(certificateId.trim())}',
      );
      final data = res.data;
      return data == null ? null : ExamCertificate.fromJson(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw ApiError.from(e);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  @override
  Future<int> unreadNotifications() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/notifications/unread-count');
      return (res.data?['unread'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  @override
  Uri sitePage(String path) => AppConfig.sitePage(path);
}
