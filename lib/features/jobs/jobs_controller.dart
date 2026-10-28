import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import 'employer/hiring_factory.dart';
import 'employer/hiring_models.dart';
import 'employer/hiring_repository.dart';
import 'job_links.dart';
import 'job_models.dart';
import 'jobs_repository.dart';

/// The Jobs tab's state: the board's sections, or the results of a search,
/// the filters, and the member's bookmarks (applied at once, rolled back if
/// the API refuses).
class JobsController extends ChangeNotifier {
  JobsController(this.repository, {JobLinks? links, HiringRepository? hiring})
    : links = links ?? const SystemJobLinks(),
      hiring = hiring ?? hiringRepositoryFor(repository);

  final JobsRepository repository;

  /// The employer side of the same account: who may post jobs, and the company's postings.
  final HiringRepository hiring;

  /// Where a tap leaves the app (the website, the share sheet).
  final JobLinks links;

  JobsOverview? _overview;
  JobFilters _filters = const JobFilters();
  List<Job> _results = const [];
  bool _resultsHaveMore = false;
  int _resultsPage = 1;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  int _unread = 0;
  bool _scopeCleared = false;
  final Set<String> _expanded = {};
  final Map<String, int> _sectionPages = {};
  int _generation = 0;
  bool _started = false;
  HiringAccess? _hiringAccess;

  bool get started => _started;

  /// The member is on a company's hiring team (owner, admin or recruiter); the employer entries show for them alone.
  bool get canHire => _hiringAccess?.canManage ?? false;
  JobFilters get filters => _filters;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  String? get error => _error;
  int get unread => _unread;
  int get myJobs => _overview?.myJobs ?? 0;
  int get newAlerts => _overview?.newAlerts ?? 0;

  /// The saved search the board is scoped to, until the member drops it.
  JobContext? get context => _scopeCleared ? null : _overview?.alert;

  /// The member has a saved search to run, whether or not its scope is on.
  bool get hasAlert => _overview?.alert?.alertId != null;

  /// The number on the "Filters" chip: every filter in force, which is what
  /// the member picked (Easy Apply, the date, work modes, types, a city) and,
  /// while the board is scoped to a saved search, each filter that search holds
  /// (a city the member picked themselves takes the place of the search's).
  int get filterCount {
    final scope = context;
    if (scope == null) return _filters.count;
    final held = scope.criteria.keys.where((k) => !(k == 'city' && _filters.hasCity));
    return _filters.count + held.length;
  }

  /// A search or a filter narrows the board to one list of results.
  bool get narrowed => _filters.narrows;

  List<JobSection> get sections => narrowed
      ? [JobSection(key: 'results', title: _resultsTitle, jobs: _results, hasMore: _resultsHaveMore)]
      : _overview?.sections ?? const [];

  String get _resultsTitle =>
      _filters.search.isNotEmpty ? 'Jobs matching "${_filters.search}"' : 'Jobs matching your filters';

  /// How many rows a section shows before "View More".
  static const previewRows = 3;

  /// A section's jobs as the board lists them: with Easy Apply on, only those
  /// that take applications on ICR (the API cannot filter on that).
  List<Job> jobsOf(JobSection section) =>
      _filters.easyApply ? section.jobs.where((j) => j.easyApply).toList() : section.jobs;

  bool isExpanded(JobSection section) => narrowed || _expanded.contains(section.key);

  /// The rows on show: three until "View More", then all that are loaded.
  List<Job> visible(JobSection section) {
    final jobs = jobsOf(section);
    return isExpanded(section) ? jobs : jobs.take(previewRows).toList();
  }

  /// "View More": there are more to show, here or on the next page.
  bool showsMore(JobSection section) =>
      isExpanded(section) ? section.hasMore : jobsOf(section).length > previewRows || section.hasMore;

  /// Everything is on show and it is more than three: "Show Less" folds it back.
  bool canCollapse(JobSection section) =>
      !narrowed && isExpanded(section) && !section.hasMore && jobsOf(section).length > previewRows;

  /// The words at the right of a section's heading, if it has any.
  String? actionLabel(JobSection section) => showsMore(section)
      ? 'View More'
      : canCollapse(section)
      ? 'Show Less'
      : null;

  Future<void> start() async {
    _started = true;
    await Future.wait([_load(notify: false), _loadUnread(), hiringAccess()]);
  }

  /// Who the member is to the hiring side (read once; [refresh] true reads it again). Null when it cannot be told.
  Future<HiringAccess?> hiringAccess({bool refresh = false}) async {
    if (_hiringAccess != null && !refresh) return _hiringAccess;
    try {
      _hiringAccess = await hiring.access();
      notifyListeners();
      return _hiringAccess;
    } catch (_) {
      return null;
    }
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
      if (narrowed) {
        final page = await repository.search(_filters, scope: context);
        if (generation != _generation) return;
        _results = page.jobs;
        _resultsHaveMore = page.hasMore;
        _resultsPage = 1;
      } else {
        final overview = await repository.overview(scoped: !_scopeCleared);
        if (generation != _generation) return;
        _overview = overview;
        _sectionPages.clear();
      }
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

  Future<void> setSearch(String query) async {
    if (query.trim() == _filters.search) return;
    _filters = _filters.copyWith(search: query.trim());
    await refresh();
  }

  /// Easy Apply on keeps the jobs that take applications on ICR; off shows
  /// every job. Applied to what is loaded, so it needs no reload.
  void toggleEasyApply() {
    _filters = _filters.copyWith(easyApply: !_filters.easyApply);
    notifyListeners();
  }

  Future<void> setPostedWithin(int? days) async {
    _filters = days == null ? _filters.copyWith(clearPosted: true) : _filters.copyWith(postedWithinDays: days);
    await refresh();
  }

  Future<void> setFilters(JobFilters filters) async {
    _filters = filters;
    await refresh();
  }

  Future<void> clearFilters() => setFilters(JobFilters(search: _filters.search, easyApply: _filters.easyApply));

  /// The cross on the scope bar: the board stops being scoped to the saved
  /// search, so its section gives way to the latest jobs and a search typed
  /// over it covers every job.
  Future<void> clearContext() async {
    if (context == null) return;
    _scopeCleared = true;
    notifyListeners();
    await refresh();
  }

  /// "Alerts": runs the saved search (which counts its new matches as seen),
  /// puts its results on the board, open, and puts the scope back if it was
  /// dropped. A sentence when the API refuses.
  Future<String?> runAlert() async {
    final overview = _overview;
    final alert = overview?.alert;
    if (overview == null || alert == null) return null;
    try {
      final page = await repository.runAlert(alert);
      var fresh = 0;
      try {
        fresh = await repository.newAlertMatches();
      } catch (_) {
        // The badge reads zero until the next refresh says otherwise.
      }
      // A search or filters laid over the board would hide the section.
      _filters = JobFilters(easyApply: _filters.easyApply);
      _scopeCleared = false;
      final section = JobSection(key: 'alert', title: alert.label, jobs: page.jobs, hasMore: page.hasMore);
      _overview = overview.copyWith(
        sections: [...overview.sections.where((s) => s.key != 'alert' && s.key != 'latest'), section],
        newAlerts: fresh,
      );
      _sectionPages['alert'] = 1;
      _expanded.add('alert');
      notifyListeners();
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    }
  }

  /// The "N new" on Alerts again (after matches were seen somewhere else), and "My jobs".
  Future<void> refreshAlertCount() async {
    try {
      final fresh = await repository.newAlertMatches();
      final overview = _overview;
      if (overview != null) {
        _overview = overview.copyWith(newAlerts: fresh);
        notifyListeners();
      }
    } catch (_) {
      // The badge keeps what it had until the board is next refreshed.
    }
  }

  /// The member's applications and saved jobs, for the "My jobs" sheet.
  Future<MyJobs> loadMyJobs() => repository.myJobs();

  /// "View More": the rest of a section, then its next page.
  Future<void> expand(JobSection section) async {
    if (!_expanded.contains(section.key)) {
      _expanded.add(section.key);
      notifyListeners();
      if (jobsOf(section).length > previewRows) return;
    }
    await loadMore(section);
  }

  /// "Show Less".
  void collapse(JobSection section) {
    if (_expanded.remove(section.key)) notifyListeners();
  }

  /// What a tap on a section's heading action does.
  Future<void> act(JobSection section) async {
    if (showsMore(section)) {
      await expand(section);
    } else {
      collapse(section);
    }
  }

  Future<void> loadMore([JobSection? section]) async {
    if (_loading || _loadingMore) return;
    if (narrowed) {
      if (!_resultsHaveMore) return;
      _loadingMore = true;
      notifyListeners();
      try {
        final page = await repository.search(_filters, page: _resultsPage + 1, scope: context);
        _results = [..._results, ...page.jobs.where((j) => !_results.any((r) => r.id == j.id))];
        _resultsHaveMore = page.hasMore;
        _resultsPage++;
      } catch (_) {
        // The next "View More" tries again.
      } finally {
        _loadingMore = false;
        notifyListeners();
      }
      return;
    }
    if (section == null || !section.hasMore) return;
    _loadingMore = true;
    notifyListeners();
    try {
      final next = (_sectionPages[section.key] ?? 1) + 1;
      final page = await repository.more(section, next);
      _sectionPages[section.key] = next;
      _replaceSection(
        section.copyWith(
          jobs: [...section.jobs, ...page.jobs.where((j) => !section.jobs.any((r) => r.id == j.id))],
          hasMore: page.hasMore,
        ),
      );
    } catch (_) {
      // The next "View More" tries again.
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  Future<void> _loadUnread() async {
    try {
      _unread = await repository.unreadNotifications();
      notifyListeners();
    } catch (_) {}
  }

  /// Bookmarks the job (or takes the bookmark back); a sentence when it fails.
  Future<String?> toggleSave(Job job) async {
    final saved = !job.saved;
    _apply(job.id, (j) => j.copyWith(saved: saved));
    try {
      await repository.setSaved(job, saved);
      return null;
    } catch (e) {
      _apply(job.id, (j) => j.copyWith(saved: !saved));
      return ApiError.from(e).message;
    }
  }

  /// The sheet changed a job (saved it, applied): keep the board in step.
  void update(Job job) => _apply(job.id, (_) => job.copyWith());

  /// The sheet sent an application: "My jobs" has one more.
  void applied(Job job) {
    final overview = _overview;
    if (overview != null) {
      _overview = JobsOverview(
        sections: overview.sections,
        myJobs: overview.myJobs + 1,
        newAlerts: overview.newAlerts,
        alert: overview.alert,
      );
    }
    update(job);
  }

  /// The member hid the job ("Not interested"): it leaves the board at once,
  /// as the API leaves it out of the next read.
  void hidden(Job job) {
    bool keep(Job j) => j.id != job.id;
    _results = _results.where(keep).toList();
    final overview = _overview;
    if (overview != null) {
      _overview = overview.copyWith(
        sections: [for (final s in overview.sections) s.copyWith(jobs: s.jobs.where(keep).toList())],
      );
    }
    notifyListeners();
  }

  Job? find(String id) {
    for (final s in sections) {
      for (final j in s.jobs) {
        if (j.id == id) return j;
      }
    }
    return null;
  }

  void _apply(String id, Job Function(Job) change) {
    Job swap(Job j) => j.id == id ? change(j) : j;
    _results = _results.map(swap).toList();
    final overview = _overview;
    if (overview != null) {
      _overview = overview.copyWith(
        sections: [for (final s in overview.sections) s.copyWith(jobs: s.jobs.map(swap).toList())],
      );
    }
    notifyListeners();
  }

  void _replaceSection(JobSection section) {
    final overview = _overview;
    if (overview == null) return;
    _overview = overview.copyWith(sections: [for (final s in overview.sections) s.key == section.key ? section : s]);
  }
}
