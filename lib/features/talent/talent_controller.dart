import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import 'talent_labels.dart';
import 'talent_models.dart';
import 'talent_repository.dart';

/// Browse the pool, or rank it against one of the company's jobs (the website's two toggles).
enum TalentMode { browse, match }

/// The talent search on screen: who is looking and what the paywall allows, the filters and the free-text search
/// (debounced, as the website's), the page read and the pages after it, the saved searches, and Match to a job.
class TalentController extends ChangeNotifier {
  TalentController(this.repository, {this.pageSize = 12, this.debounce = const Duration(milliseconds: 350)});

  final TalentRepository repository;
  final int pageSize;
  final Duration debounce;

  TalentViewer? _viewer;
  TalentAccess? _access;
  TalentMasters _masters = const TalentMasters();
  List<JobOption> _jobs = const [];
  List<SavedSearch> _saved = const [];
  bool _starting = true;
  String? _startError;

  TalentMode _mode = TalentMode.browse;
  TalentFilters _filters = const TalentFilters();
  String _query = '';
  Timer? _debounce;

  List<Candidate> _rows = const [];
  int _total = 0;
  int _page = 1;
  int _totalPages = 1;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  int _generation = 0;

  String? _matchJobId;
  List<Candidate> _matches = const [];
  bool _matchLoading = false;
  String? _matchError;
  int _matchGeneration = 0;

  String? _activeSearchId;
  ParsedQuery? _lastParse;

  TalentViewer? get viewer => _viewer;
  TalentAccess? get access => _access;
  TalentMasters get masters => _masters;
  List<JobOption> get jobs => _jobs;
  List<SavedSearch> get savedSearches => _saved;

  /// Reading who is looking (nothing else is drawn until then).
  bool get starting => _starting;
  String? get startError => _startError;

  /// A hiring role, acting for a company (or ICR staff): the search is theirs.
  bool get allowed => _viewer?.canSearch ?? false;

  /// Searching needs no company, but matching to its jobs and the quick view's contact, invitation, message and
  /// notes do — the API refuses each without one (the website's `lacksCompany`).
  bool get noCompany => _viewer != null && !_viewer!.hasCompany;

  TalentMode get mode => _mode;
  TalentFilters get filters => _filters;

  /// What the search box holds (the filter's `q` once the debounce runs).
  String get query => _query;
  int get filterCount => _filters.count;
  List<FilterChipLabel> get chips => _filters.chips(_masters);

  List<Candidate> get rows => _rows;
  int get total => _total;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  bool get hasMore => _page < _totalPages;
  String? get error => _error;

  String? get matchJobId => _matchJobId;
  JobOption? get matchJob => _jobs.where((j) => j.id == _matchJobId).firstOrNull;
  List<Candidate> get matches => _matches;
  bool get matchLoading => _matchLoading;
  String? get matchError => _matchError;

  /// The saved search the list is showing, until a filter changes.
  String? get activeSearchId => _activeSearchId;

  /// The last brief read into filters, for the "Read as …" line.
  ParsedQuery? get lastParse => _lastParse;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> start() async {
    _starting = true;
    _startError = null;
    notifyListeners();
    try {
      _viewer = await repository.viewer();
    } catch (e) {
      _startError = ApiError.from(e).message;
      _starting = false;
      notifyListeners();
      return;
    }
    if (!allowed) {
      _starting = false;
      notifyListeners();
      return;
    }
    // Each is its own read; one failing leaves the rest standing (a plan with no masters still searches).
    await Future.wait([
      repository.access().then((a) => _access = a, onError: (_) {}),
      repository.savedSearches().then((s) => _saved = s, onError: (_) {}),
      repository.masters().then((m) => _masters = m, onError: (_) {}),
      if (_viewer!.hasCompany) repository.companyJobs().then((j) => _jobs = j, onError: (_) {}),
    ]);
    _starting = false;
    notifyListeners();
    await refresh();
  }

  Future<void> refresh() async {
    final generation = ++_generation;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final page = await repository.search(_filters, page: 1, limit: pageSize);
      if (generation != _generation) return;
      _rows = page.rows;
      _total = page.total;
      _page = page.page;
      _totalPages = page.totalPages;
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

  Future<void> loadMore() async {
    if (_loadingMore || _loading || !hasMore) return;
    final generation = _generation;
    _loadingMore = true;
    notifyListeners();
    try {
      final page = await repository.search(_filters, page: _page + 1, limit: pageSize);
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

  Future<void> refreshMatch() async {
    final jobId = _matchJobId;
    final generation = ++_matchGeneration;
    if (jobId == null) {
      _matches = const [];
      _matchError = null;
      _matchLoading = false;
      notifyListeners();
      return;
    }
    _matchLoading = true;
    _matchError = null;
    notifyListeners();
    try {
      final rows = await repository.match(jobId, _filters);
      if (generation != _matchGeneration) return;
      _matches = rows;
    } catch (e) {
      if (generation != _matchGeneration) return;
      _matchError = ApiError.from(e).message;
    } finally {
      if (generation == _matchGeneration) {
        _matchLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> _reload() => _mode == TalentMode.match ? refreshMatch() : refresh();

  /// Typed into the search box: applied after [debounce], every other facet at once.
  void setQuery(String text) {
    _query = text;
    _debounce?.cancel();
    _debounce = Timer(debounce, () => _applyQuery());
    notifyListeners();
  }

  /// The search key: applied now.
  Future<void> submitQuery(String text) {
    _query = text;
    _debounce?.cancel();
    return _applyQuery();
  }

  Future<void> _applyQuery() {
    final q = _query.trim();
    final next = _filters.copyWith(q: q.isEmpty ? null : q);
    if (next.q == _filters.q) {
      notifyListeners();
      return Future.value();
    }
    _filters = next;
    _activeSearchId = null;
    _lastParse = null;
    return _reload();
  }

  Future<void> setFilters(TalentFilters next) {
    _filters = next.copyWith(q: _filters.q, sort: _filters.sort);
    _activeSearchId = null;
    _lastParse = null;
    return _reload();
  }

  Future<void> setSort(TalentSort sort) {
    if (sort == _filters.sort) return Future.value();
    _filters = _filters.copyWith(sort: sort);
    return refresh();
  }

  Future<void> removeChip(String key) {
    _filters = _filters.dropChip(key);
    if (key == 'q') _query = '';
    _activeSearchId = null;
    _lastParse = null;
    return _reload();
  }

  Future<void> reset() {
    _debounce?.cancel();
    _filters = TalentFilters(sort: _filters.sort);
    _query = '';
    _activeSearchId = null;
    _lastParse = null;
    return _reload();
  }

  Future<void> setMode(TalentMode mode) {
    if (mode == _mode) return Future.value();
    _mode = mode;
    notifyListeners();
    if (mode == TalentMode.match) return refreshMatch();
    return _rows.isEmpty && _error == null ? refresh() : Future.value();
  }

  Future<void> setMatchJob(String? jobId) {
    _matchJobId = jobId;
    return refreshMatch();
  }

  // ---- Saved searches -------------------------------------------------------

  /// Keeps the current filters under [name]. Returns the API's refusal, or null.
  Future<String?> saveSearch(String name, {bool alertsEnabled = true}) async {
    try {
      final s = await repository.saveSearch(name.trim(), _filters, alertsEnabled: alertsEnabled);
      _saved = [..._saved, s];
      _activeSearchId = s.id;
      notifyListeners();
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    }
  }

  /// Shows a saved search's candidates, its criteria as the filters.
  Future<void> applySaved(SavedSearch s) {
    _debounce?.cancel();
    _filters = s.criteria;
    _query = s.criteria.q ?? '';
    _activeSearchId = s.id;
    _lastParse = null;
    return _reload();
  }

  Future<String?> toggleAlerts(SavedSearch s) => _updateSaved(s.id, alertsEnabled: !s.alertsEnabled);

  Future<String?> updateSavedToCurrent(SavedSearch s) => _updateSaved(s.id, criteria: _filters);

  Future<String?> _updateSaved(String id, {TalentFilters? criteria, bool? alertsEnabled}) async {
    try {
      final next = await repository.updateSearch(id, criteria: criteria, alertsEnabled: alertsEnabled);
      _saved = [for (final s in _saved) s.id == id ? next : s];
      if (criteria != null) _activeSearchId = id;
      notifyListeners();
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    }
  }

  Future<String?> deleteSaved(SavedSearch s) async {
    try {
      await repository.deleteSearch(s.id);
      _saved = [
        for (final x in _saved)
          if (x.id != s.id) x,
      ];
      if (_activeSearchId == s.id) _activeSearchId = null;
      notifyListeners();
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    }
  }

  // ---- Plain-English brief -------------------------------------------------

  /// Turns a brief into filters and applies them. Throws the API's refusal ([ApiError]); a brief nothing could be
  /// read from comes back with an empty `matched` and changes nothing.
  Future<ParsedQuery> describe(String text) async {
    final parsed = await repository.parse(text.trim());
    if (parsed.matched.isEmpty) return parsed;
    _debounce?.cancel();
    _filters = parsed.filters.copyWith(sort: _filters.sort);
    _query = parsed.filters.q ?? '';
    _activeSearchId = null;
    _lastParse = parsed;
    await _reload();
    return parsed;
  }

  void dismissParse() {
    _lastParse = null;
    notifyListeners();
  }
}

/// One candidate's quick view: the detail, the hiring team's notes and tags, the contact behind the paywall, an
/// invitation to one of the company's jobs, and a first message. Each write returns the API's refusal, or null.
class CandidateQuickViewController extends ChangeNotifier {
  CandidateQuickViewController(this.repository, this.userId, {required this.hasCompany, this.card});

  final TalentRepository repository;
  final String userId;

  /// Contact, invitation, message and notes need a company; without one the quick view offers none of them.
  final bool hasCompany;

  /// The card the list showed, drawn while the detail loads.
  final Candidate? card;

  CandidateDetail? _detail;
  bool _loading = true;
  String? _error;
  List<CandidateNote> _notes = const [];
  List<String> _tags = const [];
  CandidateContact? _contact;
  bool _revealing = false;
  bool _inviting = false;
  bool _sending = false;
  bool _savingNote = false;
  bool _savingTag = false;

  Candidate? get candidate => _detail?.card ?? card;
  CandidateDetail? get detail => _detail;
  bool get loading => _loading;
  String? get error => _error;
  List<CandidateNote> get notes => _notes;
  List<String> get tags => _tags;
  CandidateContact? get contact => _contact;
  bool get revealing => _revealing;
  bool get inviting => _inviting;
  bool get sending => _sending;
  bool get savingNote => _savingNote;
  bool get savingTag => _savingTag;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final reads = <Future<void>>[
        repository.detail(userId).then((d) => _detail = d),
        if (hasCompany) repository.notes(userId).then((n) => _notes = n, onError: (_) {}),
        if (hasCompany) repository.tags(userId).then((t) => _tags = t, onError: (_) {}),
      ];
      await Future.wait(reads);
    } catch (e) {
      _error = ApiError.from(e).message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<String?> reveal() async {
    _revealing = true;
    notifyListeners();
    try {
      _contact = await repository.revealContact(userId);
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    } finally {
      _revealing = false;
      notifyListeners();
    }
  }

  Future<String?> invite(String jobId) async {
    _inviting = true;
    notifyListeners();
    try {
      await repository.invite(jobId: jobId, candidateId: userId);
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    } finally {
      _inviting = false;
      notifyListeners();
    }
  }

  /// Sends the first message; the conversation's id on success, else the refusal in [error].
  Future<({String? conversationId, String? error})> send(String message, {String? jobTitle}) async {
    _sending = true;
    notifyListeners();
    try {
      final id = await repository.message(userId, message.trim(), jobTitle: jobTitle);
      return (conversationId: id, error: null);
    } catch (e) {
      return (conversationId: null, error: ApiError.from(e).message);
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  Future<String?> addNote(String body) async {
    final clean = body.trim();
    if (clean.isEmpty) return null;
    _savingNote = true;
    notifyListeners();
    try {
      final note = await repository.addNote(userId, clean);
      _notes = [note, ..._notes];
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    } finally {
      _savingNote = false;
      notifyListeners();
    }
  }

  Future<String?> addTag(String label) async {
    final clean = label.trim();
    if (clean.isEmpty) return null;
    _savingTag = true;
    notifyListeners();
    try {
      _tags = await repository.addTag(userId, clean);
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    } finally {
      _savingTag = false;
      notifyListeners();
    }
  }

  Future<String?> removeTag(String label) async {
    try {
      _tags = await repository.removeTag(userId, label);
      notifyListeners();
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    }
  }
}
