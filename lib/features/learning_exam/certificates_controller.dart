import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import 'exam_models.dart';
import 'exam_repository.dart';
import '../learning/notify_safely.dart';

/// The member's certificates, newest first, narrowed by who awarded them.
class CertificatesController extends ChangeNotifier with NotifySafely {
  CertificatesController(this.repository);

  final ExamRepository repository;

  List<ExamCertificate> _all = const [];
  bool _loading = true;
  String? _error;
  int _unread = 0;
  String? _body;
  int _generation = 0;

  List<ExamCertificate> get all => _all;
  bool get loading => _loading;
  String? get error => _error;
  int get unread => _unread;

  /// The awarding body the list is narrowed to; null shows every certificate.
  String? get body => _body;

  /// The awarding bodies there are, ICR as one of them.
  List<String> get bodies => ({for (final c in _all) c.awardedBy}.toList()..sort());

  List<ExamCertificate> get shown => _body == null
      ? _all
      : [
          for (final c in _all)
            if (c.awardedBy == _body) c,
        ];

  int? get best => _all.isEmpty ? null : _all.map((c) => c.percentage).reduce((a, b) => a > b ? a : b);

  Future<void> start() async {
    await Future.wait([load(notify: false), _loadUnread()]);
  }

  Future<void> refresh() => load(notify: true);

  Future<void> load({required bool notify}) async {
    final generation = ++_generation;
    _loading = true;
    _error = null;
    if (notify) notifyListeners();
    try {
      final rows = await repository.certificates();
      if (generation != _generation) return;
      _all = rows;
      if (_body != null && !bodies.contains(_body)) _body = null;
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

  void setBody(String? body) {
    if (body == _body) return;
    _body = body;
    notifyListeners();
  }

  Future<void> _loadUnread() async {
    try {
      _unread = await repository.unreadNotifications();
      notifyListeners();
    } catch (_) {}
  }
}
