/// Stand-ins for the notifications tests: a repository whose answers and
/// failures the test decides, with every call written down.
library;

import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/features/messaging/messaging_models.dart';
import 'package:icr_mobile/features/notifications/notification_models.dart';
import 'package:icr_mobile/features/notifications/notifications_repository.dart';

AppNotification note(
  String id, {
  String title = 'Something happened',
  String? body,
  String type = 'info',
  String? link,
  DateTime? at,
  bool read = false,
  int count = 1,
  ChatPerson? actor,
  ChatCompany? company,
  ChatCompany? actorCompany,
}) => AppNotification(
  id: id,
  title: title,
  body: body,
  type: type,
  link: link,
  count: count,
  actor: actor,
  company: company,
  actorCompany: actorCompany,
  createdAt: at ?? DateTime(2026, 10, 25, 9),
  readAt: read ? DateTime(2026, 10, 25, 10) : null,
);

class FakeNotificationsRepository implements NotificationsRepository {
  FakeNotificationsRepository({List<AppNotification>? items, int? unread, this.pageSize = 20})
    : items = List.of(items ?? const []),
      _unread = unread;

  List<AppNotification> items;
  final int pageSize;
  int? _unread;
  final calls = <String>[];

  /// When set, the matching call throws it.
  ApiError? listError;
  ApiError? markReadError;
  ApiError? markAllError;
  ApiError? preferencesError;
  ApiError? saveError;
  ApiError? switchError;
  ApiError? seenError;

  /// How many rows `markSeen` says it read.
  int seenAnswer = 0;

  NotificationViewer viewerAnswer = const NotificationViewer(id: 'me');
  late List<NotificationPreference> prefs = [
    for (final c in notificationCategories)
      NotificationPreference(category: c, inApp: true, email: true, locked: c.locked),
  ];

  int get unread => _unread ?? items.where((n) => n.unread).length;

  @override
  Future<NotificationPage> list({int page = 1, bool unreadOnly = false}) async {
    calls.add('list page=$page unread=$unreadOnly');
    if (listError != null) throw listError!;
    final rows = unreadOnly ? items.where((n) => n.unread).toList() : items;
    final from = (page - 1) * pageSize;
    final slice = rows.skip(from).take(pageSize).toList();
    return NotificationPage(items: slice, total: rows.length, hasMore: from + pageSize < rows.length);
  }

  @override
  Future<int> unreadCount() async {
    calls.add('unreadCount');
    return unread;
  }

  @override
  Future<void> markRead(String id) async {
    calls.add('markRead $id');
    if (markReadError != null) throw markReadError!;
    items = [for (final n in items) n.id == id ? n.read(DateTime(2026, 10, 25, 11)) : n];
    _unread = null;
  }

  @override
  Future<int> markAllRead() async {
    calls.add('markAllRead');
    if (markAllError != null) throw markAllError!;
    final count = unread;
    items = [for (final n in items) n.read(DateTime(2026, 10, 25, 11))];
    _unread = null;
    return count;
  }

  @override
  Future<int> markSeen(String kind, String id) async {
    calls.add('markSeen $kind $id');
    if (seenError != null) throw seenError!;
    return seenAnswer;
  }

  @override
  Future<List<NotificationPreference>> preferences() async {
    calls.add('preferences');
    if (preferencesError != null) throw preferencesError!;
    return prefs;
  }

  @override
  Future<List<NotificationPreference>> savePreference(NotificationPreference preference) async {
    calls.add('savePreference ${preference.category.id} in=${preference.inApp} mail=${preference.email}');
    if (saveError != null) throw saveError!;
    prefs = [for (final p in prefs) p.category.id == preference.category.id ? preference : p];
    return prefs;
  }

  @override
  Future<NotificationViewer> viewer() async {
    calls.add('viewer');
    return viewerAnswer;
  }

  @override
  Future<void> switchCompany(String companyId) async {
    calls.add('switchCompany $companyId');
    if (switchError != null) throw switchError!;
  }
}
