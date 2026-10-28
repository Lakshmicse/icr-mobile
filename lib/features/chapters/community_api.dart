/// The calls the community screens' API sources share: reads that turn a
/// transport failure into an [ApiError], the paginated `{ data, meta }`
/// envelope, the signed-in person (`GET /auth/me`) and the bell's count.
library;

import 'package:dio/dio.dart' show Options;

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../core/config.dart';
import 'community_kit.dart' show FeedPicture;

/// One page of a paginated list, as `paginate()` answers it.
class ApiPage<T> {
  const ApiPage({required this.items, required this.total, required this.page, required this.hasNext});

  final List<T> items;
  final int total;
  final int page;
  final bool hasNext;

  ApiPage<R> map<R>(R Function(T) f) =>
      ApiPage(items: items.map(f).toList(), total: total, page: page, hasNext: hasNext);
}

/// Who is signed in, as `GET /auth/me` says.
class Viewer {
  const Viewer({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    this.companyId,
    this.phone,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String role;
  final String? companyId;
  final String? phone;

  String get name => '$firstName $lastName'.trim();
  bool get isAdmin => role == 'SUPER_ADMIN';

  factory Viewer.fromJson(Map<String, dynamic> json) => Viewer(
    id: json['id'] as String,
    firstName: json['firstName'] as String? ?? '',
    lastName: json['lastName'] as String? ?? '',
    email: json['email'] as String? ?? '',
    role: json['role'] as String? ?? 'PROFESSIONAL',
    companyId: json['companyId'] as String?,
    phone: json['phone'] as String?,
  );
}

/// The transport the community repositories share.
class CommunityApi {
  CommunityApi(this.client);

  final ApiClient client;

  Future<Map<String, dynamic>> getMap(String path, [Map<String, dynamic>? query]) async {
    try {
      final res = await client.dio.get<Map<String, dynamic>>(path, queryParameters: query);
      return res.data ?? const {};
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<List<Map<String, dynamic>>> getList(String path, [Map<String, dynamic>? query]) async {
    try {
      final res = await client.dio.get<dynamic>(path, queryParameters: query);
      return (res.data as List? ?? const []).cast<Map<String, dynamic>>();
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  /// A list that is the member's own: signed out it answers 401, read as none.
  Future<List<Map<String, dynamic>>> mine(String path) async {
    try {
      return await getList(path);
    } on ApiError catch (e) {
      if (e.statusCode == 401) return const [];
      rethrow;
    }
  }

  Future<ApiPage<Map<String, dynamic>>> page(String path, Map<String, dynamic> query) async {
    final res = await getMap(path, query);
    final meta = res['meta'] as Map<String, dynamic>? ?? const {};
    final rows = rows0(res);
    return ApiPage(
      items: rows,
      total: (meta['total'] as num?)?.toInt() ?? rows.length,
      page: (meta['page'] as num?)?.toInt() ?? 1,
      hasNext: meta['hasNext'] == true,
    );
  }

  /// Every row of a paginated list, a page at a time (up to [maxPages]).
  Future<(List<Map<String, dynamic>>, int)> all(String path, [Map<String, dynamic>? query, int maxPages = 10]) async {
    final rows = <Map<String, dynamic>>[];
    var total = 0;
    for (var p = 1; p <= maxPages; p++) {
      final res = await page(path, {...?query, 'page': p, 'limit': 100});
      rows.addAll(res.items);
      total = res.total;
      if (!res.hasNext) break;
    }
    return (rows, total);
  }

  Future<dynamic> send(String method, String path, {Object? data, Map<String, dynamic>? query}) async {
    try {
      final res = await client.dio.request<dynamic>(
        path,
        data: data,
        queryParameters: query,
        options: Options(method: method),
      );
      return res.data;
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  /// The signed-in person; null when nobody is (or the read fails).
  Future<Viewer?> viewer() async {
    try {
      final res = await client.dio.get<Map<String, dynamic>>('/auth/me');
      final data = res.data;
      return data == null ? null : Viewer.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<int> unreadNotifications() async {
    final res = await getMap('/notifications/unread-count');
    return (res['unread'] as num?)?.toInt() ?? 0;
  }

  /// A stored `/uploads/...` path (or a full URL) as a picture.
  FeedPicture? picture(String? path) {
    final url = AppConfig.absoluteUrl(path, apiBase: client.dio.options.baseUrl);
    return url == null ? null : FeedPicture.network(url);
  }

  static List<Map<String, dynamic>> rows0(Map<String, dynamic> page) =>
      (page['data'] as List? ?? const []).cast<Map<String, dynamic>>();

  static String? text(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;

  static DateTime? date(Object? v) => v is String ? DateTime.tryParse(v) : null;

  static int count(Object? v) => (v as num?)?.toInt() ?? 0;
}
