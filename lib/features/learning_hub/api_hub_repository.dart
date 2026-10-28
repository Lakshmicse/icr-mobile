import 'package:dio/dio.dart' show Options;

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../core/config.dart';
import 'hub_models.dart';
import 'hub_repository.dart';

/// The hub's extra reads and its institute enquiry, against the API.
class ApiLearningHubRepository implements LearningHubRepository {
  ApiLearningHubRepository({required this.api});

  final ApiClient api;

  @override
  Future<List<Institute>> institutes() async {
    final rows = await _list('/learning/providers');
    return [
      for (final r in rows)
        if ((r['name'] as String? ?? '').trim().isNotEmpty) _institute(r),
    ];
  }

  Institute _institute(Map<String, dynamic> json) {
    final company = json['company'] as Map<String, dynamic>?;
    // Its own mark, or its company's when the two records are linked.
    final logoPath = _text(json['logoUrl']) ?? _text(company?['logoUrl']);
    final logo = AppConfig.absoluteUrl(logoPath, apiBase: api.dio.options.baseUrl);
    return Institute(
      id: json['id'] as String? ?? '',
      name: (json['name'] as String).trim(),
      slug: _text(json['slug']),
      summary: _text(json['summary']),
      logo: logo == null ? null : FeedPicture.network(logo),
      website: _text(json['website']),
      verified: json['verified'] == true,
      courseCount: (json['courseCount'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<MyLearning> myLearning() async {
    // Each count stands on its own: one refused read must not blank the other.
    Future<int?> count(String path) async {
      try {
        return (await _list(path)).length;
      } catch (_) {
        return null;
      }
    }

    final results = await Future.wait([count('/learning/me/attempts'), count('/learning/me/certificates')]);
    return MyLearning(attempts: results[0], certificates: results[1]);
  }

  @override
  Future<void> enquireInstitute(Institute institute, {required String message}) async {
    final slug = institute.slug;
    if (slug == null || slug.isEmpty) throw ApiError('This institute cannot be written to from the app.');
    final me = await _get('/auth/me');
    final user = (me['user'] as Map<String, dynamic>?) ?? me;
    final name = '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
    try {
      await api.dio.request<dynamic>(
        '/learning/providers/${Uri.encodeComponent(slug)}/enquire',
        data: {'name': name.isEmpty ? 'ICR member' : name, 'email': user['email'], 'message': message.trim()},
        options: Options(method: 'POST'),
      );
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  static String? _text(Object? v) {
    if (v is! String) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  Future<List<Map<String, dynamic>>> _list(String path) async {
    try {
      final res = await api.dio.get<dynamic>(path);
      final data = res.data;
      final rows = data is List ? data : (data is Map ? data['data'] as List? : null);
      return (rows ?? const []).cast<Map<String, dynamic>>();
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<Map<String, dynamic>> _get(String path) async {
    try {
      final res = await api.dio.get<Map<String, dynamic>>(path);
      return res.data ?? const {};
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}
