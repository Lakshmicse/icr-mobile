import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../chapters/community_api.dart';
import 'contact_models.dart';
import 'contact_repository.dart';

/// The website's contact form, from the app: `POST /contact` (public and
/// throttled to 5 a minute per IP; the API files the message as a CRM lead and
/// tells the ICR inbox). The form is filled in from `GET /auth/me`.
class ApiContactRepository implements ContactRepository {
  ApiContactRepository({required ApiClient api}) : _api = CommunityApi(api);

  final CommunityApi _api;

  /// A visitor has no session, and `/auth/me` answers 401: that is "nobody is
  /// signed in", not a failure. Anything else (offline, a 5xx) is thrown, so the
  /// screen can say it could not check.
  @override
  Future<ContactSender?> sender() async {
    final Map<String, dynamic> json;
    try {
      json = await _api.getMap('/auth/me');
    } on ApiError catch (e) {
      if (e.statusCode == 401) return null;
      rethrow;
    }
    if (json.isEmpty) return null;
    final me = Viewer.fromJson(json);
    return ContactSender(name: me.name, email: me.email, phone: me.phone);
  }

  @override
  Future<String> send(ContactMessage message) async {
    final res = await _api.send('POST', '/contact', data: message.toJson());
    return (res as Map?)?['id'] as String? ?? '';
  }

  /// Soft: the bell is a nicety, and a visitor's 401 is simply "none".
  @override
  Future<int> unreadNotifications() async {
    try {
      return await _api.unreadNotifications();
    } on ApiError {
      return 0;
    }
  }
}
