import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import 'project_models.dart';
import 'projects_repository.dart';

/// The company's projects on screen (the website's `/manage/projects` list): the page read with its search and the
/// two switches (My Projects, Show Archived), more pages as the list is scrolled, and a new project created through
/// the sheet.
class ProjectsController extends ChangeNotifier {
  ProjectsController(this.repository);

  final ProjectsRepository repository;

  List<Project> _rows = const [];
  String _search = '';
  bool _mine = false;
  bool _includeArchived = false;
  bool _loading = false;
  bool _loadingMore = false;
  bool _loaded = false;
  int _page = 1;
  int _totalPages = 1;
  String? _error;
  int _generation = 0;
  bool _disposed = false;

  List<Project> get rows => _rows;
  String get search => _search;
  bool get mine => _mine;
  bool get includeArchived => _includeArchived;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;

  /// Whether a read has ever finished (an empty list is a state; "not read yet" is not).
  bool get loaded => _loaded;
  bool get hasMore => _page < _totalPages;
  String? get error => _error;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> start() => refresh();

  /// Reads the first page again with the filters as they stand. [quiet] keeps the rows on screen while it reads (a
  /// pull to refresh, a return from the project page).
  Future<void> refresh({bool quiet = false}) async {
    final generation = ++_generation;
    if (!quiet) _loading = true;
    _error = null;
    _notify();
    try {
      final page = await repository.list(search: _search, mine: _mine, includeArchived: _includeArchived, page: 1);
      if (generation != _generation) return;
      _rows = page.rows;
      _page = page.page;
      _totalPages = page.totalPages;
      _loaded = true;
    } catch (e) {
      if (generation != _generation) return;
      _error = ApiError.from(e).message;
    } finally {
      if (generation == _generation) {
        _loading = false;
        _notify();
      }
    }
  }

  Future<void> setSearch(String q) {
    final next = q.trim();
    if (next == _search) return Future.value();
    _search = next;
    return refresh(quiet: _rows.isNotEmpty);
  }

  Future<void> setMine(bool on) {
    if (on == _mine) return Future.value();
    _mine = on;
    return refresh();
  }

  Future<void> setIncludeArchived(bool on) {
    if (on == _includeArchived) return Future.value();
    _includeArchived = on;
    return refresh();
  }

  Future<void> loadMore() async {
    if (_loadingMore || _loading || !hasMore) return;
    final generation = _generation;
    _loadingMore = true;
    _notify();
    try {
      final page = await repository.list(
        search: _search,
        mine: _mine,
        includeArchived: _includeArchived,
        page: _page + 1,
      );
      if (generation != _generation) return;
      _rows = [..._rows, ...page.rows];
      _page = page.page;
      _totalPages = page.totalPages;
    } catch (e) {
      if (generation != _generation) return;
      _error = ApiError.from(e).message;
    } finally {
      if (generation == _generation) {
        _loadingMore = false;
        _notify();
      }
    }
  }

  /// Creates a project and puts it at the top of the list. Returns the API's refusal, or null.
  Future<String?> create(ProjectDraft draft) async {
    try {
      final created = await repository.create(draft);
      _rows = [created, ..._rows.where((p) => p.id != created.id)];
      _loaded = true;
      _notify();
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    }
  }

  /// Takes a project as the page left it (archived, edited, or gone when null).
  void took(String id, Project? project) {
    final i = _rows.indexWhere((p) => p.id == id);
    if (project == null) {
      if (i >= 0) {
        _rows = [..._rows]..removeAt(i);
        _notify();
      }
      return;
    }
    if (project.archived && !_includeArchived) {
      if (i >= 0) {
        _rows = [..._rows]..removeAt(i);
        _notify();
      }
      return;
    }
    if (i >= 0) {
      _rows = [..._rows]..[i] = project;
    } else {
      _rows = [project, ..._rows];
    }
    _notify();
  }
}

/// One project on its page (the website's `/manage/projects/[id]`): the project with its criteria and counts, the
/// roster by stage (the Pipeline tab), the people its criteria match (Find candidates), and every change the page
/// makes — archive, edit, delete, a candidate moved or removed, a match saved.
class ProjectController extends ChangeNotifier {
  ProjectController(this.repository, {required this.projectId, Project? initial}) : _project = initial;

  final ProjectsRepository repository;
  final String projectId;

  Project? _project;
  List<ProjectCandidate> _candidates = const [];
  List<CandidateMatch>? _matches;
  bool _loading = false;
  bool _rosterLoading = false;
  bool _matchesLoading = false;
  bool _busy = false;
  String? _error;
  String? _matchesError;
  String? _saveError;
  final Set<String> _busyCandidates = {};
  bool _changed = false;
  bool _deleted = false;
  bool _disposed = false;

  Project? get project => _project;
  List<ProjectCandidate> get candidates => _candidates;

  /// Null until the Find candidates tab has read them.
  List<CandidateMatch>? get matches => _matches;
  bool get loading => _loading;
  bool get rosterLoading => _rosterLoading;
  bool get matchesLoading => _matchesLoading;

  /// A change to the project itself (archive, edit, delete) is on its way.
  bool get busy => _busy;
  String? get error => _error;
  String? get matchesError => _matchesError;

  /// The website's warning above the matches when a save was refused.
  String? get saveError => _saveError;

  /// Whether anything about the project changed here, so the list behind reads it again.
  bool get changed => _changed;
  bool get deleted => _deleted;

  bool candidateBusy(String candidateId) => _busyCandidates.contains(candidateId);

  /// The roster split by board stage, in the board's order; Archived apart.
  List<ProjectCandidate> inStage(String stage) => [
    for (final c in _candidates)
      if (c.stage == stage) c,
  ];

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Reads the project and its roster.
  Future<void> start() async {
    _loading = _project == null;
    _rosterLoading = true;
    _error = null;
    _notify();
    try {
      final results = await Future.wait<Object>([repository.project(projectId), repository.candidates(projectId)]);
      _project = results[0] as Project;
      _candidates = results[1] as List<ProjectCandidate>;
    } catch (e) {
      _error = ApiError.from(e).message;
    } finally {
      _loading = false;
      _rosterLoading = false;
      _notify();
    }
  }

  Future<void> refresh() => start();

  /// Reads the roster and the counts again after a change to who is in the project.
  Future<void> _reloadRoster() async {
    try {
      final results = await Future.wait<Object>([repository.project(projectId), repository.candidates(projectId)]);
      _project = results[0] as Project;
      _candidates = results[1] as List<ProjectCandidate>;
    } catch (_) {
      // What was shown stands; the next pull reads it again.
    }
    _notify();
  }

  /// Reads the matches (once, then on [refreshMatches]).
  Future<void> loadMatches() {
    if (_matches != null || _matchesLoading) return Future.value();
    return refreshMatches();
  }

  Future<void> refreshMatches() async {
    _matchesLoading = true;
    _matchesError = null;
    _notify();
    try {
      _matches = await repository.matches(projectId);
    } catch (e) {
      _matchesError = ApiError.from(e).message;
    } finally {
      _matchesLoading = false;
      _notify();
    }
  }

  void dismissSaveError() {
    if (_saveError == null) return;
    _saveError = null;
    _notify();
  }

  // --- the project itself --------------------------------------------------------------------------------------------

  Future<String?> _change(Future<Project> Function() write) async {
    if (_busy) return null;
    _busy = true;
    _notify();
    try {
      _project = await write();
      _changed = true;
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    } finally {
      _busy = false;
      _notify();
    }
  }

  /// The website's Archive / Un-archive button. Returns the API's refusal, or null.
  Future<String?> setArchived(bool archived) => _change(() => repository.update(projectId, {'archived': archived}));

  /// Saves the edit sheet's changes (only what changed). Returns the API's refusal, or null.
  Future<String?> update(Map<String, Object?> changes) {
    if (changes.isEmpty) return Future.value();
    return _change(() async {
      final saved = await repository.update(projectId, changes);
      // The API's row carries no counts; keep the ones the page read.
      final before = _project;
      return before == null
          ? saved
          : saved.copyWith(stageCounts: before.stageCounts, candidateCount: before.candidateCount);
    });
  }

  /// Deletes the project. Returns the API's refusal, or null.
  Future<String?> delete() async {
    if (_busy) return null;
    _busy = true;
    _notify();
    try {
      await repository.remove(projectId);
      _deleted = true;
      _changed = true;
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    } finally {
      _busy = false;
      _notify();
    }
  }

  // --- the people in it ----------------------------------------------------------------------------------------------

  Future<String?> _candidateChange(String candidateId, Future<void> Function() write) async {
    _busyCandidates.add(candidateId);
    _notify();
    try {
      await write();
      _changed = true;
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    } finally {
      _busyCandidates.remove(candidateId);
      _notify();
    }
  }

  /// Moves a candidate to [stage] (the arrow, or the menu). Returns the API's refusal, or null.
  Future<String?> moveCandidate(ProjectCandidate c, String stage) async {
    final refusal = await _candidateChange(
      c.candidateId,
      () => repository.moveCandidate(projectId, c.candidateId, stage),
    );
    if (refusal == null) {
      final i = _candidates.indexWhere((r) => r.id == c.id);
      if (i >= 0) _candidates = [..._candidates]..[i] = c.copyWith(stage: stage);
      _project = _recounted();
      _notify();
    }
    return refusal;
  }

  /// Takes a candidate out of the project. Returns the API's refusal, or null.
  Future<String?> removeCandidate(ProjectCandidate c) async {
    final refusal = await _candidateChange(c.candidateId, () => repository.removeCandidate(projectId, c.candidateId));
    if (refusal == null) {
      _candidates = [..._candidates]..removeWhere((r) => r.id == c.id);
      _project = _recounted();
      // The person may match the criteria again.
      _matches = null;
      _notify();
    }
    return refusal;
  }

  /// Saves a match into the project (the website's Save). The refusal is kept as [saveError], and returned.
  Future<String?> saveMatch(CandidateMatch m) async {
    _saveError = null;
    final refusal = await _candidateChange(m.userId, () => repository.addCandidate(projectId, m.userId));
    if (refusal != null) {
      _saveError = refusal;
      _notify();
      return refusal;
    }
    _matches = [...?_matches?.where((x) => x.userId != m.userId)];
    _notify();
    await _reloadRoster();
    return null;
  }

  /// The project's counts as the roster now stands.
  Project? _recounted() {
    final p = _project;
    if (p == null) return null;
    final counts = <String, int>{};
    for (final c in _candidates) {
      counts[c.stage] = (counts[c.stage] ?? 0) + 1;
    }
    return p.copyWith(stageCounts: counts, candidateCount: _candidates.length);
  }
}
