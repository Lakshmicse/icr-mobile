import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import 'learning_models.dart';
import 'learning_repository.dart';
import 'notify_safely.dart';

/// The Learning tab's state: the published courses grouped by kind, a search
/// over them, and the member's own places (taken at once, rolled back if the
/// API refuses).
class LearningController extends ChangeNotifier with NotifySafely {
  LearningController(this.repository);

  final LearningRepository repository;

  List<Course> _courses = const [];
  String _search = '';
  bool _mineOnly = false;
  bool _loading = false;
  String? _error;
  int _unread = 0;
  bool _started = false;
  int _generation = 0;

  bool get started => _started;
  bool get loading => _loading;
  String? get error => _error;
  int get unread => _unread;
  String get search => _search;
  bool get narrowed => _search.isNotEmpty;
  List<Course> get courses => _courses;

  /// The "My courses" chip is on: only the courses the member holds a place on.
  bool get mineOnly => _mineOnly;

  /// The courses the member holds a place on (waitlist and requests included,
  /// withdrawn ones not), from `GET /learning/me/enrollments`.
  List<Course> get mine => [
    for (final c in _courses)
      if (c.enrolled) c,
  ];

  /// The courses that match the search, under their kind's heading.
  List<CourseSection> get sections {
    final q = _search.toLowerCase();
    bool matches(Course c) =>
        q.isEmpty ||
        c.title.toLowerCase().contains(q) ||
        (c.summary?.toLowerCase().contains(q) ?? false) ||
        (c.provider?.name.toLowerCase().contains(q) ?? false) ||
        c.code.toLowerCase().contains(q);
    if (_mineOnly) {
      final rows = mine.where(matches).toList();
      return rows.isEmpty
          ? const []
          : [CourseSection(kind: CourseKind.development, courses: rows, heading: 'My courses')];
    }
    return [
      for (final kind in CourseKind.values)
        if (_courses.any((c) => c.kind == kind && matches(c)))
          CourseSection(kind: kind, courses: _courses.where((c) => c.kind == kind && matches(c)).toList()),
    ];
  }

  Future<void> start() async {
    _started = true;
    await Future.wait([_load(notify: false), _loadUnread()]);
  }

  Future<void> refresh() => _load(notify: true);

  /// [notify] is false for the first load: `start()` runs from `initState`,
  /// before the first build reads `loading`, and a notification there lands in
  /// the middle of a build (a provider made with its screen asserts on it).
  Future<void> _load({required bool notify}) async {
    final generation = ++_generation;
    _loading = true;
    _error = null;
    if (notify) notifyListeners();
    try {
      final courses = await repository.courses();
      if (generation != _generation) return;
      _courses = courses;
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

  void setSearch(String query) {
    if (query.trim() == _search) return;
    _search = query.trim();
    notifyListeners();
  }

  void clearSearch() => setSearch('');

  /// The "My courses" chip: switches between the catalogue and the member's
  /// own places, reading the places afresh when it goes on.
  void toggleMine() => setMineOnly(!_mineOnly);

  /// Sets the "My courses" chip as [on] says: the Learning hub opens the grid
  /// with it on from "My learning" and off from the ICR Courses door.
  void setMineOnly(bool on) {
    if (_mineOnly == on) return;
    _mineOnly = on;
    notifyListeners();
    if (_mineOnly) refresh();
  }

  /// Takes a place on [run] (or the course), showing it at once; a sentence
  /// when the API refuses, after putting the row back.
  Future<String?> enrol(Course course, {CourseRun? run}) async {
    final before = find(course.id)?.enrolment ?? course.enrolment;
    final status = (run?.full ?? course.full) ? EnrolmentStatus.waitlisted : EnrolmentStatus.pending;
    _apply(
      course.id,
      (c) => c.copyWith(
        enrolment: MyEnrolment(id: '', courseId: c.id, runId: run?.id, status: status),
      ),
    );
    try {
      final mine = await repository.enrol(course, run: run);
      _apply(course.id, (c) => c.copyWith(enrolment: mine));
      return null;
    } catch (e) {
      _apply(course.id, (c) => before == null ? c.copyWith(clearEnrolment: true) : c.copyWith(enrolment: before));
      return ApiError.from(e).message;
    }
  }

  /// The sheet learned more about a course (its detail, its enrolment): keep
  /// the list in step.
  void update(Course course) => _apply(course.id, (_) => course);

  Course? find(String id) {
    for (final c in _courses) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> _loadUnread() async {
    try {
      _unread = await repository.unreadNotifications();
      notifyListeners();
    } catch (_) {}
  }

  void _apply(String id, Course Function(Course) change) {
    _courses = [for (final c in _courses) c.id == id ? change(c) : c];
    notifyListeners();
  }
}
