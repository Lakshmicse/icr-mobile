import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import 'partner_console_models.dart';
import 'partner_console_repository.dart';
import 'partner_console_rules.dart';

/// What every console page has: the viewer and the console's context, and from the two whether a part of the
/// console may be used — the member's learning roles (`learningCan`) and, for a change, what the institute's
/// agreement covers (`partnerMayChange`), as the website's `useLearningCan`.
abstract class _ConsoleController extends ChangeNotifier {
  _ConsoleController(this.repository, {required this.viewer});

  final PartnerConsoleRepository repository;
  final PartnerConsoleViewer viewer;

  ConsoleContext? _context;
  ConsoleContext? get context => _context;

  /// Whether the viewer may change [area]; `edit: false` asks only to see it.
  bool can(String area, {bool edit = true}) {
    if (edit && _context != null && !_context!.mayChange(area)) return false;
    return viewer.can(area, edit: edit);
  }

  /// ICR reviews this institute's courses before they go live.
  bool get underReview => _context?.courseReviewRequired ?? false;

  Future<void> _readContext() async {
    try {
      _context = await repository.context();
    } catch (_) {
      // The console still draws without it; the API refuses what it must.
    }
  }
}

/// The institute's courses (`DevelopmentPanel` + `CoursesTable`): the list, and what the status cell, the sheet
/// and the row's actions change.
class CoursesController extends _ConsoleController {
  CoursesController(super.repository, {super.viewer = PartnerConsoleViewer.full});

  List<ConsoleCourse> _courses = const [];
  bool _loading = false;
  bool _loaded = false;
  String? _error;
  final Set<String> _busy = {};
  int _generation = 0;

  List<ConsoleCourse> get courses => _courses;
  bool get loading => _loading;
  bool get loaded => _loaded;
  String? get error => _error;
  bool busy(String id) => _busy.contains(id);

  int get batchCount => _courses.fold(0, (n, c) => n + c.batches.length);

  /// Courses that exist here but nowhere a candidate can see.
  int get unpublished => _courses.where((c) => !c.published).length;

  Future<void> start() => refresh();

  Future<void> refresh() async {
    final generation = ++_generation;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([_readContext(), repository.courses()]);
      if (generation != _generation) return;
      _courses = results[1] as List<ConsoleCourse>;
      _loaded = true;
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

  /// Whether the status cell shows "Add a batch to publish": a partner's taught course needs a batch still going
  /// ahead before the API lets it go live.
  bool needsBatch(ConsoleCourse c) => (_context?.isPartner ?? true) && c.kind == 'DEVELOPMENT' && !c.hasActiveBatch;

  Future<String?> _change(String id, Future<void> Function() run) async {
    _busy.add(id);
    _error = null;
    notifyListeners();
    try {
      await run();
      await refresh();
      return null;
    } catch (e) {
      final message = ApiError.from(e).message;
      _error = message;
      return message;
    } finally {
      _busy.remove(id);
      notifyListeners();
    }
  }

  /// Put the course on the public site (the status cell's Publish). Returns the API's refusal, or null.
  Future<String?> publish(ConsoleCourse c) =>
      _change(c.id, () => repository.updateCourse(c.id, {'status': 'PUBLISHED'}));

  /// Take it off the site (Unpublish).
  Future<String?> unpublish(ConsoleCourse c) => _change(c.id, () => repository.updateCourse(c.id, {'status': 'DRAFT'}));

  /// Hand the course to ICR's reviewers (Submit for review).
  Future<String?> submit(ConsoleCourse c) => _change(c.id, () => repository.submitCourse(c.id));

  /// Pull it back while ICR has not ruled (Withdraw).
  Future<String?> withdraw(ConsoleCourse c) => _change(c.id, () => repository.withdrawCourse(c.id));

  Future<String?> delete(ConsoleCourse c) => _change(c.id, () => repository.deleteCourse(c.id));

  /// Saves the sheet: a new course, or an edit, published too when [publish]. Returns the API's refusal, or null.
  Future<String?> save(ConsoleCourse? existing, CourseDraft draft, {bool publish = false}) async {
    try {
      if (existing == null) {
        await repository.createCourse(draft.toJson(create: true));
      } else {
        await repository.updateCourse(existing.id, draft.toJson(create: false, publish: publish));
      }
    } catch (e) {
      return ApiError.from(e).message;
    }
    await refresh();
    return null;
  }
}

/// The institute's batches (`BatchesPanel`): every run of every course, soonest first, unscheduled last, narrowed
/// to one course when asked; the team for the sheet's pickers.
class BatchesController extends _ConsoleController {
  BatchesController(super.repository, {super.viewer = PartnerConsoleViewer.full, String? courseId})
    : _courseId = courseId ?? '';

  List<ConsoleCourse> _courses = const [];
  List<ConsoleBatch> _batches = const [];
  List<FacultyMember>? _faculty;
  String _courseId;
  bool _loading = false;
  bool _loaded = false;
  String? _error;
  final Set<String> _busy = {};
  int _generation = 0;

  List<ConsoleCourse> get courses => _courses;

  /// `''` for every course, else one course's id (the website's `?course=`).
  String get courseId => _courseId;
  ConsoleCourse? get selectedCourse => _courses.where((c) => c.id == _courseId).firstOrNull;
  bool get loading => _loading;
  bool get loaded => _loaded;
  String? get error => _error;
  bool busy(String id) => _busy.contains(id);

  /// The rows in view: soonest first.
  List<ConsoleBatch> get rows {
    final shown = [
      for (final b in _batches)
        if (_courseId.isEmpty || b.courseId == _courseId) b,
    ]..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return shown;
  }

  ConsoleCourse? courseOf(ConsoleBatch b) => _courses.where((c) => c.id == b.courseId).firstOrNull;

  Future<void> start() => refresh();

  Future<void> refresh() async {
    final generation = ++_generation;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([_readContext(), repository.courses(), repository.batches()]);
      if (generation != _generation) return;
      _courses = results[1] as List<ConsoleCourse>;
      _batches = results[2] as List<ConsoleBatch>;
      _loaded = true;
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

  void setCourse(String id) {
    if (id == _courseId) return;
    _courseId = id;
    notifyListeners();
  }

  /// The institute's team, read once for the sheet's trainer and specialist pickers.
  Future<List<FacultyMember>> faculty() async {
    if (_faculty != null) return _faculty!;
    try {
      return _faculty = await repository.faculty();
    } catch (_) {
      return const [];
    }
  }

  Future<String?> _change(String id, Future<void> Function() run) async {
    _busy.add(id);
    _error = null;
    notifyListeners();
    try {
      await run();
      await refresh();
      return null;
    } catch (e) {
      final message = ApiError.from(e).message;
      _error = message;
      return message;
    } finally {
      _busy.remove(id);
      notifyListeners();
    }
  }

  Future<String?> delete(ConsoleBatch b) => _change(b.id, () => repository.deleteBatch(b.id));

  /// Ask a trainer on the batch again, after they declined.
  Future<String?> reinvite(ConsoleBatch b, String trainerId) async {
    try {
      await repository.reinviteTrainer(b.id, trainerId);
      await refresh();
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    }
  }

  /// Saves the sheet. Returns the API's refusal, or null.
  Future<String?> save(ConsoleCourse course, ConsoleBatch? existing, Map<String, Object?> body) async {
    try {
      if (existing == null) {
        await repository.createBatch(course.id, body);
      } else {
        await repository.updateBatch(existing.id, body);
      }
    } catch (e) {
      return ApiError.from(e).message;
    }
    await refresh();
    return null;
  }
}

/// Who has enrolled, and the decision on each (`EnrollmentsTable`): the page read, the course and status
/// filters, and each decision written to the API and then into the row.
class EnrolmentsController extends _ConsoleController {
  EnrolmentsController(super.repository, {super.viewer = PartnerConsoleViewer.full, String? courseId})
    : _courseId = courseId ?? '';

  List<ConsoleCourse> _courses = const [];
  List<ConsoleEnrolment> _rows = const [];
  String _courseId;
  String _status = '';
  bool _loading = false;
  bool _loadingMore = false;
  bool _loaded = false;
  int _page = 1;
  int _totalPages = 1;
  int _total = 0;
  String? _error;
  String? _lock;
  final Set<String> _busy = {};
  int _generation = 0;

  List<ConsoleCourse> get courses => _courses;
  List<ConsoleEnrolment> get rows => _rows;
  String get courseId => _courseId;
  ConsoleCourse? get selectedCourse => _courses.where((c) => c.id == _courseId).firstOrNull;

  /// `''` for every status, else one of [enrolmentStatuses].
  String get status => _status;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  bool get loaded => _loaded;
  bool get hasMore => _page < _totalPages;
  int get total => _total;
  String? get error => _error;

  /// The institute's plan leaves participant management out (the API's 403): its sentence.
  String? get lock => _lock;
  bool busy(String id) => _busy.contains(id);

  Future<void> start() => refresh();

  Future<void> refresh() async {
    final generation = ++_generation;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _readContext(),
        _courses.isEmpty ? repository.courses() : Future.value(_courses),
        repository.enrolments(courseId: _courseId, status: _status, page: 1),
      ]);
      if (generation != _generation) return;
      _courses = results[1] as List<ConsoleCourse>;
      final page = results[2] as EnrolmentsPage;
      _rows = page.rows;
      _page = page.page;
      _totalPages = page.totalPages;
      _total = page.total;
      _lock = null;
      _loaded = true;
    } catch (e) {
      if (generation != _generation) return;
      final err = ApiError.from(e);
      if (err.statusCode == 403) {
        _lock = err.message;
        _rows = const [];
        _total = 0;
        _loaded = true;
      } else {
        _error = err.message;
      }
    } finally {
      if (generation == _generation) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> setCourse(String id) {
    if (id == _courseId) return Future.value();
    _courseId = id;
    return refresh();
  }

  Future<void> setStatus(String status) {
    if (status == _status) return Future.value();
    _status = status;
    return refresh();
  }

  Future<void> loadMore() async {
    if (_loadingMore || !hasMore || _loading) return;
    final generation = _generation;
    _loadingMore = true;
    notifyListeners();
    try {
      final page = await repository.enrolments(courseId: _courseId, status: _status, page: _page + 1);
      if (generation != _generation) return;
      _rows = [..._rows, ...page.rows];
      _page = page.page;
      _totalPages = page.totalPages;
      _total = page.total;
    } catch (e) {
      if (generation != _generation) return;
      _error = ApiError.from(e).message;
    } finally {
      if (generation == _generation) {
        _loadingMore = false;
        notifyListeners();
      }
    }
  }

  /// Confirms a place or cancels an enrolment. Returns the API's refusal, or null; the refusal is also kept as
  /// [error], shown above the list as the website shows it.
  Future<String?> decide(ConsoleEnrolment e, String status) async {
    _busy.add(e.id);
    _error = null;
    notifyListeners();
    try {
      final next = await repository.setEnrolmentStatus(e.id, status);
      final i = _rows.indexWhere((r) => r.id == e.id);
      if (i >= 0) _rows = [..._rows]..[i] = _rows[i].copyWith(status: next.status, decidedAt: next.decidedAt);
      return null;
    } catch (err) {
      final message = ApiError.from(err).message;
      _error = message;
      return message;
    } finally {
      _busy.remove(e.id);
      notifyListeners();
    }
  }
}
