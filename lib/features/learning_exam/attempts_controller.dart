import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import 'exam_models.dart';
import 'exam_repository.dart';
import '../learning/notify_safely.dart';

enum AttemptsFilter { all, assessments, mocks }

/// The member's sittings, newest first, narrowed by kind.
class AttemptsController extends ChangeNotifier with NotifySafely {
  AttemptsController(this.repository);

  final ExamRepository repository;

  List<Attempt> _attempts = const [];
  bool _loading = true;
  bool _started = false;
  String? _error;
  int _unread = 0;
  AttemptsFilter _filter = AttemptsFilter.all;
  int _generation = 0;

  List<Attempt> get all => _attempts;
  bool get loading => _loading;
  bool get started => _started;
  String? get error => _error;
  int get unread => _unread;
  AttemptsFilter get filter => _filter;

  List<Attempt> get shown => switch (_filter) {
    AttemptsFilter.all => _attempts,
    AttemptsFilter.assessments => [
      for (final a in _attempts)
        if (a.paper?.kind != PaperKind.mock) a,
    ],
    AttemptsFilter.mocks => [
      for (final a in _attempts)
        if (a.paper?.kind == PaperKind.mock) a,
    ],
  };

  int get passed => _attempts.where((a) => a.passed).length;
  int? get best => _attempts.isEmpty ? null : _attempts.map((a) => a.percentage).reduce((a, b) => a > b ? a : b);

  Future<void> start() async {
    _started = true;
    await Future.wait([load(notify: false), _loadUnread()]);
  }

  Future<void> refresh() => load(notify: true);

  Future<void> load({required bool notify}) async {
    final generation = ++_generation;
    _loading = true;
    _error = null;
    if (notify) notifyListeners();
    try {
      final rows = await repository.attempts();
      if (generation != _generation) return;
      _attempts = rows;
    } catch (e) {
      if (generation != _generation) return;
      _error = ApiError.from(e).message;
    } finally {
      if (generation == _generation) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  void setFilter(AttemptsFilter filter) {
    if (filter == _filter) return;
    _filter = filter;
    notifyListeners();
  }

  Future<void> _loadUnread() async {
    try {
      _unread = await repository.unreadNotifications();
      notifyListeners();
    } catch (_) {}
  }
}
