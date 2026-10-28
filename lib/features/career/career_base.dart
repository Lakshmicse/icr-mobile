import 'package:flutter/foundation.dart';

import 'career_repository.dart';

/// The clock the career screens read "now" from, so a test (and a golden) can pin it.
typedef CareerClock = DateTime Function();

DateTime systemClock() => DateTime.now();

/// What every career screen's state shares: the source, the bell's unread count,
/// and a guard so an answer that arrives after the screen closed has nobody to tell.
abstract class CareerController extends ChangeNotifier {
  CareerController(this.repository, {CareerClock? clock}) : clock = clock ?? systemClock;

  final CareerRepository repository;
  final CareerClock clock;

  bool _disposed = false;
  int _unread = 0;

  /// Unread notifications, for the bell.
  int get unread => _unread;

  bool get disposed => _disposed;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> loadUnread() async {
    try {
      _unread = await repository.unreadNotifications();
      notifyListeners();
    } catch (_) {
      // The bell shows no dot.
    }
  }
}
