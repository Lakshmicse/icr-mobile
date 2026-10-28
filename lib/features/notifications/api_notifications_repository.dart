import '../../core/api/api_client.dart';
import '../../core/config.dart';
import '../messaging/messaging_models.dart';
import 'notification_models.dart';
import 'notifications_repository.dart';

/// Notifications from the API: `GET /notifications` (paged, `?unread=true`),
/// `GET /notifications/unread-count`, `PATCH /notifications/:id/read`,
/// `PATCH /notifications/read-all`, `PATCH /notifications/seen`, `GET|PUT /notifications/preferences`, and
/// the person's companies for a row about another company (`POST /me/companies/switch`).
class ApiNotificationsRepository implements NotificationsRepository {
  ApiNotificationsRepository({required this.api});

  final ApiClient api;

  static const pageSize = 20;

  @override
  Future<NotificationPage> list({int page = 1, bool unreadOnly = false}) async {
    final res = await api.dio.get<Map<String, dynamic>>(
      '/notifications',
      queryParameters: {'page': page, 'limit': pageSize, if (unreadOnly) 'unread': true},
    );
    final data = res.data ?? const {};
    final rows = (data['data'] as List? ?? const []).cast<Map<String, dynamic>>();
    final meta = data['meta'] as Map<String, dynamic>? ?? const {};
    return NotificationPage(
      items: rows.map(notification).toList(),
      total: (meta['total'] as num?)?.toInt() ?? rows.length,
      hasMore: meta['hasNext'] == true,
    );
  }

  AppNotification notification(Map<String, dynamic> n) {
    final actor = n['actor'] as Map<String, dynamic>?;
    final company = n['company'] as Map<String, dynamic>?;
    final actorCompany = n['actorCompany'] as Map<String, dynamic>?;
    return AppNotification(
      id: n['id'] as String,
      title: n['title'] as String? ?? '',
      body: _text(n['body']),
      type: n['type'] as String? ?? 'info',
      link: _text(n['link']),
      company: company == null
          ? null
          : ChatCompany(id: company['id'] as String, name: company['name'] as String? ?? ''),
      count: (n['count'] as num?)?.toInt() ?? 1,
      readAt: _date(n['readAt']),
      createdAt: _date(n['createdAt']) ?? DateTime.now(),
      actorCompany: actorCompany == null
          ? null
          : ChatCompany(
              id: actorCompany['id'] as String? ?? '',
              name: actorCompany['name'] as String? ?? '',
              logo: _picture(actorCompany['logoUrl']),
            ),
      actor: actor == null
          ? null
          : ChatPerson(
              id: actor['id'] as String? ?? '',
              firstName: actor['firstName'] as String? ?? '',
              lastName: actor['lastName'] as String? ?? '',
              photo: _picture(actor['avatarUrl']),
            ),
    );
  }

  @override
  Future<int> unreadCount() async {
    final res = await api.dio.get<Map<String, dynamic>>('/notifications/unread-count');
    return (res.data?['unread'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<void> markRead(String id) async {
    await api.dio.patch<dynamic>('/notifications/${Uri.encodeComponent(id)}/read');
  }

  @override
  Future<int> markAllRead() async {
    final res = await api.dio.patch<Map<String, dynamic>>('/notifications/read-all');
    return (res.data?['updated'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<int> markSeen(String kind, String id) async {
    final res = await api.dio.patch<Map<String, dynamic>>('/notifications/seen', data: {'kind': kind, 'id': id});
    return (res.data?['updated'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<List<NotificationPreference>> preferences() async {
    final res = await api.dio.get<List<dynamic>>('/notifications/preferences');
    return _preferences(res.data);
  }

  @override
  Future<List<NotificationPreference>> savePreference(NotificationPreference preference) async {
    final res = await api.dio.put<List<dynamic>>(
      '/notifications/preferences',
      data: {
        'preferences': [
          {'category': preference.category.id, 'inApp': preference.inApp, 'email': preference.email},
        ],
      },
    );
    return _preferences(res.data);
  }

  List<NotificationPreference> _preferences(List<dynamic>? rows) => (rows ?? const [])
      .cast<Map<String, dynamic>>()
      .map(
        (p) => NotificationPreference(
          category: categoryById(p['category'] as String? ?? 'general'),
          inApp: p['inApp'] != false,
          email: p['email'] != false,
          locked: p['locked'] == true,
        ),
      )
      .toList();

  @override
  Future<NotificationViewer> viewer() async {
    final meRead = api.dio.get<Map<String, dynamic>>('/auth/me');
    final companiesRead = _companies();
    final me = (await meRead).data ?? const <String, dynamic>{};
    final user = (me['user'] as Map<String, dynamic>?) ?? me;
    final companies = await companiesRead;
    return NotificationViewer(
      id: user['id'] as String? ?? '',
      activeCompanyId: user['companyId'] as String?,
      companyCount: (companies?['companies'] as List?)?.length ?? 0,
    );
  }

  /// The person's companies; none when the read fails (a row then names no company).
  Future<Map<String, dynamic>?> _companies() async {
    try {
      return (await api.dio.get<Map<String, dynamic>>('/me/companies')).data;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> switchCompany(String companyId) async {
    final res = await api.dio.post<Map<String, dynamic>>('/me/companies/switch', data: {'companyId': companyId});
    final data = res.data ?? const {};
    final access = data['accessToken'];
    final refresh = data['refreshToken'];
    // The role rides in the token, so the session is the new one from here on.
    if (access is String && refresh is String) await api.tokens.save(accessToken: access, refreshToken: refresh);
  }

  ChatPicture? _picture(Object? raw) {
    final url = AppConfig.absoluteUrl(raw is String ? raw : null, apiBase: api.dio.options.baseUrl);
    return url == null ? null : ChatPicture.network(url);
  }

  static String? _text(Object? v) => v is String && v.trim().isNotEmpty ? v : null;
  static DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;
}
