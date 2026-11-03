import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import '../learning_assess/assess_models.dart';
import '../learning_assess/assess_repository.dart';
import '../learning_study/study_models.dart';
import '../learning_study/study_repository.dart';
import 'learning_models.dart';
import 'learning_repository.dart';
import 'notify_safely.dart';
import 'opened_learning.dart';

/// The Learning tab's state: the published courses grouped by kind, a search
/// over them, and the member's own places (taken at once, rolled back if the
/// API refuses).
class LearningController extends ChangeNotifier with NotifySafely {
  LearningController(this.repository, {this.assess, this.study});

  final LearningRepository repository;

  /// The assessments and mock exams, for the My courses shelves of what the member opened; null leaves them out.
  final AssessRepository? assess;

  /// The flash-card decks, for the Flash Cards shelf (a deck that came with an open course, or took a deck place);
  /// null leaves that shelf out.
  final StudyRepository? study;

  List<OpenedItem> _opened = const [];

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

  /// What the member opened outside an enrolment (a plan place, ICR credits or a purchase), read while the
  /// My courses chip is on.
  List<OpenedItem> get opened => _opened;

  /// The My courses shelves of opened learning (Mock Exams, Assess Your Knowledge), narrowed by the search; empty
  /// while the chip is off.
  List<OpenedShelf> get openedShelves {
    if (!_mineOnly) return const [];
    final q = _search.toLowerCase();
    return openedShelvesOf([
      for (final i in _opened)
        if (q.isEmpty || i.title.toLowerCase().contains(q)) i,
    ]);
  }

  /// The courses that match the search, under who runs them.
  List<CourseSection> get sections {
    final q = _search.toLowerCase();
    // The website's search also finds ICR's own courses by "ICR" (`c.provider?.name ?? 'ICR'`).
    bool matches(Course c) =>
        q.isEmpty ||
        c.title.toLowerCase().contains(q) ||
        (c.summary?.toLowerCase().contains(q) ?? false) ||
        (c.provider?.name ?? 'ICR').toLowerCase().contains(q) ||
        c.code.toLowerCase().contains(q);
    if (_mineOnly) {
      // The website's My Courses files a place by who runs the course: ICR's own, then the partner institutes'.
      final rows = mine.where(matches).toList();
      return [
        for (final (title, own) in [('ICR Courses', true), ('Partner Courses', false)])
          if (rows.any((c) => (c.provider == null) == own))
            CourseSection(
              kind: CourseKind.development,
              courses: rows.where((c) => (c.provider == null) == own).toList(),
              heading: title,
            ),
      ];
    }
    // The catalogue is the website's /learning/professional-development: taught courses only (the certification
    // programmes have Assess Your Knowledge), ICR's own first and the institutes' under their own heading, never
    // mixed. One "Professional development" list of every course read as ICR's (owner's report, 3 Nov 2026:
    // production's website shows one ICR course, the app showed Skystar's, Moon studio's and BrightCore's).
    final taught = _courses.where((c) => c.kind == CourseKind.development && matches(c)).toList();
    return [
      for (final (title, own) in [
        ('ICR certified programs', true),
        ('Related courses from our partners', false),
      ])
        if (taught.any((c) => (c.provider == null) == own))
          CourseSection(
            kind: CourseKind.development,
            courses: taught.where((c) => (c.provider == null) == own).toList(),
            heading: title,
          ),
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
      if (_mineOnly) await _loadOpened(generation);
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

  /// The My courses shelves of what the member opened, read beside the enrolments while the chip is on. An aside:
  /// a read that fails leaves the shelves empty and the places shown.
  Future<void> _loadOpened(int generation) async {
    final a = assess;
    if (a == null) return;
    try {
      final s = study;
      final results = await Future.wait<Object>([
        a.member(PaperKind.assessment),
        a.groups(PaperKind.assessment),
        a.groups(PaperKind.mock),
        // The decks are an aside of the aside: a failed read leaves that shelf out, the others stand.
        if (s != null) s.topics().catchError((Object _) => const <StudyTopic>[]),
      ]);
      if (generation != _generation) return;
      _opened = openedLearning(
        access: (results[0] as MemberLearning).access,
        courses: results[1] as List<PaperGroup>,
        mocks: results[2] as List<PaperGroup>,
        decks: results.length > 3 ? results[3] as List<StudyTopic> : const [],
      );
    } catch (_) {
      if (generation == _generation) _opened = const [];
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
