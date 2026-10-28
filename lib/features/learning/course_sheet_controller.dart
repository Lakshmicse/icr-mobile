import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import 'learning_models.dart';
import 'learning_repository.dart';
import 'notify_safely.dart';

/// One course's sheet: the course in full, the tab and run the person is
/// looking at, what a past learner said, and the person's actions on it.
class CourseSheetController extends ChangeNotifier with NotifySafely {
  CourseSheetController({required this.repository, required Course seed, this.onChanged}) : _course = seed;

  final LearningRepository repository;

  /// Tells the list when the course's enrolment changes.
  final ValueChanged<Course>? onChanged;

  /// Runs shown under a tab before "See More Dates".
  static const previewRuns = 3;

  Course _course;
  CourseReviews _reviews = const CourseReviews();
  bool _allReviews = false;
  bool _loading = true;
  bool _enrolling = false;
  String? _error;
  DeliveryMode _mode = DeliveryMode.inPerson;
  String? _runId;
  bool _allDates = false;

  Course get course => _course;

  /// The published reviews, newest first; the sheet draws the first as the
  /// design's testimonial and the rest on "see all".
  List<CourseReview> get reviews => _reviews.items;
  int get reviewTotal => _reviews.total;
  CourseReview? get review => _reviews.items.isEmpty ? null : _reviews.items.first;
  bool get allReviews => _allReviews;
  bool get loading => _loading;
  bool get enrolling => _enrolling;
  String? get error => _error;
  DeliveryMode get mode => _mode;
  bool get allDates => _allDates;

  List<CourseRun> get runsInMode => _course.runsIn(_mode);

  /// The runs the grid draws: the first few, or all of them.
  List<CourseRun> get shownRuns => _allDates ? runsInMode : runsInMode.take(previewRuns).toList();

  bool get hasMoreRuns => runsInMode.length > previewRuns;

  /// The awarding body can be written to; ICR's own course goes to the contact page.
  bool get canEnquire => _course.provider != null;

  CourseRun? get selectedRun {
    for (final r in _course.runs) {
      if (r.id == _runId) return r;
    }
    return null;
  }

  /// A place on what is selected costs money, so it is bought on the website.
  /// A full run's waitlist stays free.
  bool get paidPlace {
    final run = selectedRun;
    final full = run?.full ?? _course.full;
    return _course.isPaid(run) && !full;
  }

  /// What the big button says.
  String get ctaLabel {
    final mine = _course.enrolment;
    if (mine != null && mine.status.active) return mine.status.label.toUpperCase();
    if (_course.closed) return 'ENROLMENT CLOSED';
    final run = selectedRun;
    if (run?.full ?? _course.full) return (run?.waitlistEnabled ?? _course.waitlistEnabled) ? 'JOIN WAITLIST' : 'FULL';
    return 'ADD TO CART';
  }

  bool get canAct => !_course.enrolled && !_course.closed && !_enrolling && ctaLabel != 'FULL';

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final full = await repository.detail(_course);
      _course = _course.copyWith(detail: full);
      _pickDefaults();
      _loading = false;
      notifyListeners();
      _reviews = await repository.reviews(_course);
    } catch (e) {
      _error = ApiError.from(e).message;
      _loading = false;
    }
    notifyListeners();
  }

  void _pickDefaults() {
    // A member who holds a place opens on it: that run's tab, that run selected
    // (and the grid unfolded when it sits behind "See More Dates").
    final mine = _course.enrolment;
    if (mine != null && mine.status.active) {
      for (final r in _course.runs) {
        if (r.id != mine.runId) continue;
        _mode = r.mode;
        _runId = r.id;
        _allDates = runsInMode.indexOf(r) >= previewRuns;
        return;
      }
    }
    final modes = _course.scheduledModes;
    if (!modes.contains(_mode)) _mode = modes.isEmpty ? DeliveryMode.inPerson : modes.first;
    final inMode = runsInMode;
    if (selectedRun == null || selectedRun!.mode != _mode) _runId = inMode.isEmpty ? null : inMode.first.id;
  }

  void selectMode(DeliveryMode mode) {
    if (mode == _mode) return;
    _mode = mode;
    _allDates = false;
    final inMode = runsInMode;
    _runId = inMode.isEmpty ? null : inMode.first.id;
    notifyListeners();
  }

  void selectRun(CourseRun run) {
    _runId = run.id;
    notifyListeners();
  }

  void toggleAllDates() {
    _allDates = !_allDates;
    notifyListeners();
  }

  /// Takes the place at once; a sentence when the API refuses, after taking
  /// it back.
  Future<String?> enrol() async {
    final run = selectedRun;
    final before = _course.enrolment;
    final status = (run?.full ?? _course.full) ? EnrolmentStatus.waitlisted : EnrolmentStatus.pending;
    _enrolling = true;
    _set(
      _course.copyWith(
        enrolment: MyEnrolment(id: '', courseId: _course.id, runId: run?.id, status: status),
      ),
    );
    try {
      final mine = await repository.enrol(_course, run: run);
      _set(_course.copyWith(enrolment: mine));
      return null;
    } catch (e) {
      _set(before == null ? _course.copyWith(clearEnrolment: true) : _course.copyWith(enrolment: before));
      return ApiError.from(e).message;
    } finally {
      _enrolling = false;
      notifyListeners();
    }
  }

  void toggleAllReviews() {
    _allReviews = !_allReviews;
    notifyListeners();
  }

  /// Writes to the institute; a sentence when the API refuses.
  Future<String?> enquire(
    String message, {
    EnquiryKind kind = EnquiryKind.question,
    String? company,
    int? headcount,
  }) async {
    try {
      await repository.enquire(_course, message: message, kind: kind, company: company, headcount: headcount);
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    }
  }

  void _set(Course course) {
    _course = course;
    onChanged?.call(course);
    notifyListeners();
  }
}
