import '../messaging/demo_messaging_repository.dart';
import '../messaging/messaging_models.dart';
import 'notification_models.dart';
import 'notification_target.dart';
import 'notifications_repository.dart';

/// Notifications about the designs' people and records, bundled for design
/// review. Reading them works in memory.
class DemoNotificationsRepository implements NotificationsRepository {
  DemoNotificationsRepository({DateTime? now}) : _now = now ?? DateTime.now() {
    _items = _seed();
  }

  final DateTime _now;
  late List<AppNotification> _items;
  var _preferences = [
    for (final c in notificationCategories)
      NotificationPreference(category: c, inApp: true, email: c.id != 'community', locked: c.locked),
  ];

  DateTime _ago({int days = 0, int hours = 0, int minutes = 0}) =>
      _now.subtract(Duration(days: days, hours: hours, minutes: minutes));

  List<AppNotification> _seed() => [
    AppNotification(
      id: 'n-arvind',
      title: 'Arvind Swamy sent you 2 messages',
      type: 'message',
      link: '/messaging?c=c-arvind',
      count: 2,
      actor: DemoMessagingRepository.arvind,
      createdAt: _ago(minutes: 42),
    ),
    AppNotification(
      id: 'n-vikasha',
      title: 'Vikasha Aero Tech replied to “Drone facade cleaning — Tower B, Whitefield”',
      body: 'Quote: ₹4,85,000 · valid for 30 days',
      type: 'bid_received',
      link: '/manage/requirements/rfq-facade?bid=bid-vikasha',
      company: const ChatCompany(id: 'techcorp', name: 'TechCorp Facilities'),
      createdAt: _ago(hours: 1, minutes: 5),
    ),
    AppNotification(
      id: 'n-sarah',
      title: 'Sarah Jenkins replied to your discussion',
      body: '“Implementing IoT sensors for HVAC efficiency: Best practices?”',
      type: 'forum_reply',
      link: '/community/iot-hvac-home-design#reply-r1',
      actor: DemoMessagingRepository.sarah,
      createdAt: _ago(hours: 2),
    ),
    AppNotification(
      id: 'n-priya',
      title: 'Priya Nambiar booked your next session',
      body: 'Net-zero retrofits · Saturday, 11:00 am IST',
      type: 'mentorship_session_scheduled',
      link: '/mentorship/my/mentorship-priya?session=s-3',
      actor: DemoMessagingRepository.priya,
      readAt: _ago(hours: 3),
      createdAt: _ago(hours: 5),
    ),
    AppNotification(
      id: 'n-event',
      title: 'Smart Buildings Summit starts tomorrow',
      body: 'Bengaluru International Exhibition Centre · 9:30 am',
      type: 'event_reminder',
      link: '/events/smart-buildings-summit-design',
      createdAt: _ago(days: 1, hours: 2),
    ),
    AppNotification(
      id: 'n-job',
      title: 'New job matching your alert: Senior Facilities Manager',
      body: 'Global Infra Solutions · Bengaluru (Hybrid)',
      type: 'job_alert',
      link: '/jobs/design-lj-job-sfm',
      readAt: _ago(days: 2),
      createdAt: _ago(days: 3),
    ),
    AppNotification(
      id: 'n-plan',
      title: 'Your Pro Plus plan renews in 7 days',
      body: '₹11,800 on 31 Oct 2026. Nothing is charged automatically.',
      type: 'subscription_expiring',
      link: '/career/plans',
      readAt: _ago(days: 8),
      createdAt: _ago(days: 9),
    ),
  ];

  @override
  Future<NotificationPage> list({int page = 1, bool unreadOnly = false}) async {
    final rows = unreadOnly ? _items.where((n) => n.unread).toList() : _items;
    return NotificationPage(items: page == 1 ? rows : const [], total: rows.length, hasMore: false);
  }

  @override
  Future<int> unreadCount() async => _items.where((n) => n.unread).length;

  @override
  Future<void> markRead(String id) async {
    _items = [for (final n in _items) n.id == id ? n.read(_now) : n];
  }

  @override
  Future<int> markAllRead() async {
    final count = _items.where((n) => n.unread).length;
    _items = [for (final n in _items) n.read(_now)];
    return count;
  }

  @override
  Future<int> markSeen(String kind, String id) async {
    var count = 0;
    _items = [
      for (final n in _items)
        if (n.unread &&
            NotificationTarget.parse(n.link).kind == kind &&
            NotificationTarget.parse(n.link).recordId == id)
          () {
            count++;
            return n.read(_now);
          }()
        else
          n,
    ];
    return count;
  }

  @override
  Future<List<NotificationPreference>> preferences() async => _preferences;

  @override
  Future<List<NotificationPreference>> savePreference(NotificationPreference preference) async {
    if (preference.locked) return _preferences;
    _preferences = [for (final p in _preferences) p.category.id == preference.category.id ? preference : p];
    return _preferences;
  }

  @override
  Future<NotificationViewer> viewer() async =>
      const NotificationViewer(id: DemoMessagingRepository.meId, activeCompanyId: 'techcorp', companyCount: 2);

  @override
  Future<void> switchCompany(String companyId) async {}
}
