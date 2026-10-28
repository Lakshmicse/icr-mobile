import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/api/api_client.dart';

/// Reads the two counts the app's badges show.
abstract class UnreadSource {
  /// Every unread notification (`GET /notifications/unread-count`).
  Future<int> notifications();

  /// Unread messages from the other side, every inbox (`GET /messaging/unread-count`).
  Future<int> messages();
}

class ApiUnreadSource implements UnreadSource {
  ApiUnreadSource(this.api);

  final ApiClient api;

  @override
  Future<int> notifications() async {
    final res = await api.dio.get<Map<String, dynamic>>('/notifications/unread-count');
    return (res.data?['unread'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<int> messages() async {
    final res = await api.dio.get<Map<String, dynamic>>('/messaging/unread-count');
    return (res.data?['count'] as num?)?.toInt() ?? 0;
  }
}

/// The bell's red dot and the Messages badge, for the whole app.
///
/// Two small reads (the counts, never the lists) on [start], every [interval]
/// while the app is in front, and again when it comes back from the
/// background. The notifications and messages screens set the numbers
/// themselves the moment something is read, so the dot moves at once.
///
/// Provide one per signed-in person, above the screens that draw a bell:
///
///     ChangeNotifierProvider<UnreadCounts>(
///       create: (c) => UnreadCounts.api(c.read<ApiClient>())..start(),
///       child: …,
///     )
class UnreadCounts extends ChangeNotifier with WidgetsBindingObserver {
  UnreadCounts(this.source, {this.interval = const Duration(seconds: 60)});

  factory UnreadCounts.api(ApiClient api, {Duration interval = const Duration(seconds: 60)}) =>
      UnreadCounts(ApiUnreadSource(api), interval: interval);

  final UnreadSource source;
  final Duration interval;

  int _notifications = 0;
  int _messages = 0;
  Timer? _timer;
  bool _observing = false;
  bool _disposed = false;
  Future<void>? _refreshing;

  /// Unread notifications: the bell's dot.
  int get notifications => _notifications;

  /// Unread messages, every inbox.
  int get messages => _messages;

  /// Anything waiting at all.
  int get total => _notifications + _messages;

  bool get running => _timer != null;

  /// Reads now, then every [interval]; reads again when the app resumes.
  void start() {
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    _schedule();
    unawaited(refresh());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => refresh());
  }

  /// One read of both counts at a time; a failure keeps the last numbers.
  Future<void> refresh() => _refreshing ??= _read().whenComplete(() => _refreshing = null);

  Future<void> _read() async {
    final results = await Future.wait([
      source.notifications().then<int?>((n) => n).catchError((Object _) => null),
      source.messages().then<int?>((n) => n).catchError((Object _) => null),
    ]);
    if (_disposed) return;
    final n = results[0] ?? _notifications;
    final m = results[1] ?? _messages;
    if (n == _notifications && m == _messages) return;
    _notifications = n;
    _messages = m;
    notifyListeners();
  }

  /// A screen read something: the dot follows without waiting for the next read.
  void setNotifications(int count) {
    final next = count < 0 ? 0 : count;
    if (next == _notifications || _disposed) return;
    _notifications = next;
    notifyListeners();
  }

  void setMessages(int count) {
    final next = count < 0 ? 0 : count;
    if (next == _messages || _disposed) return;
    _messages = next;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _schedule();
      unawaited(refresh());
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      // Nothing to show in the background; the timer starts again on resume.
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    super.dispose();
  }
}
