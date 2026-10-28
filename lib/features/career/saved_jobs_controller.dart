import '../../core/api/api_error.dart';
import 'career_base.dart';
import 'career_models.dart';

/// The two shelves of "Saved jobs": what the member bookmarked and what they
/// told the board they are not interested in.
enum SavedTab {
  saved('Saved'),
  hidden('Hidden');

  const SavedTab(this.label);
  final String label;
}

/// The member's bookmarks (`GET /jobs/saved`, paged) and hidden jobs
/// (`GET /jobs/actions`, then each job). Taking a bookmark off or bringing a hidden
/// job back is applied at once and rolled back with the API's sentence if refused.
class SavedJobsController extends CareerController {
  SavedJobsController(super.repository, {super.clock, SavedTab tab = SavedTab.saved}) : _tab = tab;

  SavedTab _tab;
  List<Job> _saved = const [];
  List<Job> _hidden = const [];
  bool _savedLoaded = false;
  bool _hiddenLoaded = false;
  bool _loadingSaved = false;
  bool _loadingHidden = false;
  bool _loadingMore = false;
  bool _savedHasMore = false;
  int _savedPage = 0;
  String? _savedError;
  String? _hiddenError;

  SavedTab get tab => _tab;
  List<Job> get saved => _saved;
  List<Job> get hidden => _hidden;
  bool get savedLoaded => _savedLoaded;
  bool get hiddenLoaded => _hiddenLoaded;
  bool get loadingSaved => _loadingSaved;
  bool get loadingHidden => _loadingHidden;
  bool get loadingMore => _loadingMore;
  bool get savedHasMore => _savedHasMore;
  String? get savedError => _savedError;
  String? get hiddenError => _hiddenError;

  /// The shelf the member is on has nothing to show yet.
  bool get loading => _tab == SavedTab.saved ? _loadingSaved && !_savedLoaded : _loadingHidden && !_hiddenLoaded;

  Future<void> start() async {
    await Future.wait([_loadSaved(), loadUnread(), if (_tab == SavedTab.hidden) _loadHidden()]);
  }

  Future<void> select(SavedTab tab) async {
    if (tab == _tab) return;
    _tab = tab;
    notifyListeners();
    if (tab == SavedTab.hidden && !_hiddenLoaded && !_loadingHidden) await _loadHidden();
  }

  /// Pull to refresh: the open shelf again from its first page.
  Future<void> refresh() => _tab == SavedTab.saved ? _loadSaved() : _loadHidden();

  Future<void> _loadSaved() async {
    if (_loadingSaved) return;
    _loadingSaved = true;
    _savedError = null;
    notifyListeners();
    try {
      final page = await repository.savedJobs();
      _saved = page.jobs;
      _savedHasMore = page.hasMore;
      _savedPage = 1;
      _savedLoaded = true;
    } catch (e) {
      _savedError = ApiError.from(e).message;
    } finally {
      _loadingSaved = false;
      notifyListeners();
    }
  }

  Future<void> _loadHidden() async {
    if (_loadingHidden) return;
    _loadingHidden = true;
    _hiddenError = null;
    notifyListeners();
    try {
      _hidden = await repository.hiddenJobs();
      _hiddenLoaded = true;
    } catch (e) {
      _hiddenError = ApiError.from(e).message;
    } finally {
      _loadingHidden = false;
      notifyListeners();
    }
  }

  /// "View More" under the saved shelf.
  Future<void> loadMore() async {
    if (_loadingMore || !_savedHasMore) return;
    _loadingMore = true;
    notifyListeners();
    try {
      final page = await repository.savedJobs(page: _savedPage + 1);
      final seen = {for (final j in _saved) j.id};
      _saved = [..._saved, ...page.jobs.where((j) => !seen.contains(j.id))];
      _savedHasMore = page.hasMore;
      _savedPage++;
    } catch (_) {
      // A failed "View More" keeps what is on show; the button tries again.
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  /// Takes the bookmark off [job]: it leaves the shelf at once; a sentence when the API refuses.
  Future<String?> unsave(Job job) async {
    final index = _saved.indexWhere((j) => j.id == job.id);
    if (index < 0) return null;
    _saved = [..._saved]..removeAt(index);
    notifyListeners();
    try {
      await repository.jobs.setSaved(job, false);
      return null;
    } catch (e) {
      _saved = [..._saved]..insert(index.clamp(0, _saved.length), job);
      notifyListeners();
      return ApiError.from(e).message;
    }
  }

  /// "Undo" after [unsave]: the bookmark comes back where it was.
  Future<String?> resave(Job job, {int at = 0}) async {
    if (_saved.any((j) => j.id == job.id)) return null;
    final back = job.copyWith(saved: true);
    _saved = [..._saved]..insert(at.clamp(0, _saved.length), back);
    notifyListeners();
    try {
      await repository.jobs.setSaved(job, true);
      return null;
    } catch (e) {
      _saved = _saved.where((j) => j.id != job.id).toList();
      notifyListeners();
      return ApiError.from(e).message;
    }
  }

  /// Where [job] sits on the saved shelf, for an Undo.
  int indexOfSaved(Job job) => _saved.indexWhere((j) => j.id == job.id);

  /// The job sheet bookmarked or applied: keep the shelf's copy in step. A job
  /// whose bookmark was taken off in the sheet leaves the shelf.
  void jobChanged(Job job) {
    _saved = job.saved
        ? [for (final j in _saved) j.id == job.id ? job : j]
        : _saved.where((j) => j.id != job.id).toList();
    notifyListeners();
  }

  /// "Show again": the job comes back to the board; a sentence when the API refuses.
  Future<String?> unhide(Job job) async {
    final index = _hidden.indexWhere((j) => j.id == job.id);
    if (index < 0) return null;
    _hidden = [..._hidden]..removeAt(index);
    notifyListeners();
    try {
      await repository.jobs.setHidden(job, false);
      return null;
    } catch (e) {
      _hidden = [..._hidden]..insert(index.clamp(0, _hidden.length), job);
      notifyListeners();
      return ApiError.from(e).message;
    }
  }

  /// "Undo" after [unhide]: the job is hidden again.
  Future<String?> rehide(Job job) async {
    if (_hidden.any((j) => j.id == job.id)) return null;
    _hidden = [job, ..._hidden];
    notifyListeners();
    try {
      await repository.jobs.setHidden(job, true);
      return null;
    } catch (e) {
      _hidden = _hidden.where((j) => j.id != job.id).toList();
      notifyListeners();
      return ApiError.from(e).message;
    }
  }
}
