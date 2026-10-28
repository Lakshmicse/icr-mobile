import '../../../core/api/api_error.dart';
import 'hiring_models.dart';
import 'post_job_controller.dart';

/// The ways the company's list can be ordered.
enum JobsSort {
  recent('recent', 'Newest first'),
  closing('closing', 'Closing soonest'),
  applicants('applicants', 'Most applicants'),
  title('title', 'Title A to Z');

  const JobsSort(this.api, this.label);
  final String api;
  final String label;
}

/// "Jobs you posted": the figures across every posting, what needs doing, and the postings by
/// status with search and sort. Pause, resume, close, reopen, duplicate and delete are applied
/// at once and rolled back with the API's sentence if it refuses.
class EmployerJobsController extends HiringController {
  EmployerJobsController(super.repository, {super.clock, PostingStatus? status}) : _status = status;

  HiringAccess? _access;
  HiringOverview? _overview;
  List<PostedJob> _jobs = const [];
  Map<PostingStatus, int> _counts = const {};
  PostingStatus? _status;
  String _search = '';
  bool _mine = false;
  JobsSort _sort = JobsSort.recent;
  int _page = 0;
  bool _hasMore = false;
  bool _loading = false;
  bool _loadingMore = false;
  bool _loaded = false;
  String? _error;
  final Set<String> _busy = {};

  HiringAccess? get access => _access;
  HiringOverview? get overview => _overview;
  List<PostedJob> get jobs => _jobs;
  Map<PostingStatus, int> get counts => _counts;
  PostingStatus? get status => _status;
  String get search => _search;
  bool get mine => _mine;
  JobsSort get sort => _sort;
  bool get hasMore => _hasMore;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  bool get loaded => _loaded;
  String? get error => _error;

  /// Nothing was ever posted (not just nothing matching the filters).
  bool get noJobsAtAll => _loaded && _counts.values.fold(0, (a, b) => a + b) == 0 && _search.isEmpty && !_mine;

  bool busy(String id) => _busy.contains(id);

  int count(PostingStatus? s) => s == null ? _counts.values.fold(0, (a, b) => a + b) : (_counts[s] ?? 0);

  Future<void> start() async {
    await Future.wait([_loadAccess(), _loadOverview(), _load(), loadUnread()]);
  }

  Future<void> refresh() async {
    await Future.wait([_loadOverview(), _load(), loadUnread()]);
  }

  Future<void> _loadAccess() async {
    try {
      _access = await repository.access();
      notifyListeners();
    } catch (_) {
      // The list itself says what the API refuses.
    }
  }

  Future<void> _loadOverview() async {
    try {
      _overview = await repository.overview();
      notifyListeners();
    } catch (_) {
      // The figures are left out; the list is the page.
    }
  }

  Future<void> _load() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final page = await repository.jobs(status: _status, search: _search, mine: _mine, sort: _sort.api);
      _jobs = page.jobs;
      _counts = page.statusCounts;
      _hasMore = page.hasMore;
      _page = 1;
      _loaded = true;
    } catch (e) {
      _error = ApiError.from(e).message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_loadingMore || !_hasMore) return;
    _loadingMore = true;
    notifyListeners();
    try {
      final page = await repository.jobs(
        status: _status,
        search: _search,
        mine: _mine,
        sort: _sort.api,
        page: _page + 1,
      );
      final seen = {for (final j in _jobs) j.id};
      _jobs = [..._jobs, ...page.jobs.where((j) => !seen.contains(j.id))];
      _hasMore = page.hasMore;
      _page++;
    } catch (_) {
      // A failed "View More" keeps what is on show; the button tries again.
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  Future<void> selectTab(PostingStatus? status) {
    if (status == _status) return Future.value();
    _status = status;
    return _load();
  }

  Future<void> setSearch(String query) {
    if (query.trim() == _search) return Future.value();
    _search = query.trim();
    return _load();
  }

  Future<void> setSort(JobsSort sort) {
    if (sort == _sort) return Future.value();
    _sort = sort;
    return _load();
  }

  Future<void> setMine(bool on) {
    if (on == _mine) return Future.value();
    _mine = on;
    return _load();
  }

  /// Moves a posting between OPEN, PAUSED and CLOSED. A sentence when the API refuses (the plan's
  /// live-post room, a posting that no longer passes the checklist).
  Future<String?> move(PostedJob job, PostingStatus to) async {
    if (_busy.contains(job.id)) return null;
    _busy.add(job.id);
    notifyListeners();
    try {
      await repository.setStatus(job.id, to);
      await refresh();
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    } finally {
      _busy.remove(job.id);
      notifyListeners();
    }
  }

  /// Deletes the posting (it leaves the list and the board); a sentence when refused.
  Future<String?> delete(PostedJob job) async {
    if (_busy.contains(job.id)) return null;
    _busy.add(job.id);
    notifyListeners();
    try {
      await repository.deleteJob(job.id);
      _jobs = _jobs.where((j) => j.id != job.id).toList();
      await refresh();
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    } finally {
      _busy.remove(job.id);
      notifyListeners();
    }
  }

  /// Makes a draft copy of the posting, with its questions; returns the copy's id, or throws the sentence.
  Future<({String? id, String? error})> duplicate(PostedJob job) async {
    if (_busy.contains(job.id)) return (id: null, error: null);
    _busy.add(job.id);
    notifyListeners();
    try {
      final original = await repository.job(job.id);
      final copy = original.copyWith(title: _copyTitle(original.title), status: PostingStatus.draft);
      final id = await repository.createJob(_stripId(copy), PostingStatus.draft);
      if (original.screening.isNotEmpty) {
        await repository.setScreeningQuestions(id, [
          for (final q in original.screening)
            ScreeningDraft(
              type: q.type,
              prompt: q.prompt,
              options: q.options,
              scaleMax: q.scaleMax,
              idealAnswer: q.idealAnswer,
              mustHave: q.mustHave,
            ),
        ]);
      }
      await refresh();
      return (id: id, error: null);
    } catch (e) {
      return (id: null, error: ApiError.from(e).message);
    } finally {
      _busy.remove(job.id);
      notifyListeners();
    }
  }

  static String _copyTitle(String title) {
    final t = '$title (copy)';
    return t.length > 120 ? '${title.substring(0, 112)} (copy)' : t;
  }

  /// The copy is a new posting: no id.
  static JobDraft _stripId(JobDraft d) => JobDraft.fromJson({...d.toJson(status: PostingStatus.draft)});
}
