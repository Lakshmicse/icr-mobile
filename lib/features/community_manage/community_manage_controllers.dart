import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import 'community_manage_models.dart';
import 'community_manage_repository.dart';
import 'community_manage_rules.dart';

/// One staff list (chapters or councils): a page of twenty, searched by name as the API searches, the search
/// settling for a moment before it is asked (the website's `useListControls`).
class OrgListController<T> extends ChangeNotifier {
  OrgListController({
    required Future<ManagePage<T>> Function(int page, String search) fetch,
    String initialSearch = '',
    this.searchDelay = const Duration(milliseconds: 350),
  }) : _fetch = fetch,
       _search = initialSearch.trim();

  final Future<ManagePage<T>> Function(int page, String search) _fetch;
  final Duration searchDelay;

  List<T> _rows = const [];
  int _page = 1;
  int _totalPages = 1;
  int _total = 0;
  bool _loading = false;
  bool _loaded = false;
  String? _error;
  String _search;
  Timer? _settle;
  int _generation = 0;
  bool _disposed = false;

  List<T> get rows => _rows;
  int get page => _page;
  int get totalPages => _totalPages;
  int get total => _total;
  bool get loading => _loading;
  bool get loaded => _loaded;
  String? get error => _error;
  String get search => _search;

  /// The first read. Called from `initState`, so it tells no one it has begun: the first build reads [loading].
  Future<void> start() => _load(announce: false);

  Future<void> refresh() => _load();

  /// What is typed in the search box: asked once typing rests, from the first page.
  void setSearch(String value) {
    final next = value.trim();
    if (next == _search) return;
    _search = next;
    _settle?.cancel();
    _settle = Timer(searchDelay, () {
      _page = 1;
      _load();
    });
  }

  /// The search set at once (a request's "Find it").
  void searchNow(String value) {
    _settle?.cancel();
    _search = value.trim();
    _page = 1;
    _load();
  }

  void setPage(int page) {
    if (page < 1 || page > _totalPages || page == _page) return;
    _page = page;
    _load();
  }

  Future<void> _load({bool announce = true}) async {
    final generation = ++_generation;
    _loading = true;
    _error = null;
    if (announce) _notify();
    try {
      final got = await _fetch(_page, _search);
      if (generation != _generation) return;
      _rows = got.rows;
      _totalPages = got.totalPages;
      _total = got.total;
      _loaded = true;
      // A page past the end (a record retired from the last page): step back to the last one there is.
      if (_rows.isEmpty && _page > 1 && _page > _totalPages) {
        _page = _totalPages;
        _loading = false;
        return _load();
      }
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

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _settle?.cancel();
    super.dispose();
  }
}

/// Members' requests of one kind (chapter applications or council proposals): the ones in one state, a page at a
/// time, and the decision staff take on one.
class RequestsController<T> extends ChangeNotifier {
  RequestsController({
    required Future<ManagePage<T>> Function(String status, int page) fetch,
    required Future<void> Function(String id, String decision, String? reason) decide,
  }) : _fetch = fetch,
       _decide = decide;

  final Future<ManagePage<T>> Function(String status, int page) _fetch;
  final Future<void> Function(String id, String decision, String? reason) _decide;

  List<T> _rows = const [];
  String _status = RequestStatus.pending;
  int _page = 1;
  int _totalPages = 1;
  bool _loading = false;
  bool _loaded = false;
  bool _started = false;
  String? _error;
  int _generation = 0;
  bool _disposed = false;

  List<T> get rows => _rows;
  String get status => _status;
  int get page => _page;
  int get totalPages => _totalPages;
  bool get loading => _loading;
  bool get loaded => _loaded;
  bool get started => _started;
  String? get error => _error;

  /// The first read, when the tab is first shown. From `initState` it tells no one it has begun.
  Future<void> start({bool announce = false}) {
    _started = true;
    return _load(announce: announce);
  }

  Future<void> refresh() => _load();

  void setStatus(String status) {
    if (status == _status) return;
    _status = status;
    _page = 1;
    _rows = const [];
    _loaded = false;
    _load();
  }

  void setPage(int page) {
    if (page < 1 || page > _totalPages || page == _page) return;
    _page = page;
    _load();
  }

  /// Approves or declines one request. Null when done; the API's own words when it refuses.
  Future<String?> decide(String id, {required String decision, String? reason}) async {
    try {
      await _decide(id, decision, reason);
    } catch (e) {
      return ApiError.from(e).message;
    }
    await _load();
    return null;
  }

  Future<void> _load({bool announce = true}) async {
    final generation = ++_generation;
    _loading = true;
    _error = null;
    if (announce) _notify();
    try {
      final got = await _fetch(_status, _page);
      if (generation != _generation) return;
      _rows = got.rows;
      _totalPages = got.totalPages;
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

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// One chapter's or council's manage page: its details from the staff list, its content, and every change the
/// website's dialog and content drawer make. A change answers null when done, or the API's refusal in its own
/// words; the page is read again after each one.
class OrgRecordController extends ChangeNotifier {
  OrgRecordController(this.repository, {required this.kind, required this.id, AdminChapter? chapter, AdminCouncil? council})
    : _chapter = chapter,
      _council = council;

  final CommunityManageRepository repository;
  final OrgKind kind;
  final String id;

  AdminChapter? _chapter;
  AdminCouncil? _council;
  OrgContent? _content;
  bool _loading = false;
  bool _loaded = false;
  String? _error;
  bool _gone = false;
  int _generation = 0;
  bool _disposed = false;

  AdminChapter? get chapter => _chapter;
  AdminCouncil? get council => _council;
  OrgContent get content => _content ?? const OrgContent();
  bool get loading => _loading;
  bool get loaded => _loaded;
  String? get error => _error;

  /// Retired here, or no longer in the reader's list.
  bool get gone => _gone;

  bool get hasRecord => kind == OrgKind.chapter ? _chapter != null : _council != null;
  String get name => (kind == OrgKind.chapter ? _chapter?.name : _council?.name) ?? '';
  bool get isChapter => kind == OrgKind.chapter;

  /// The first read. Called from `initState`, so it tells no one it has begun.
  Future<void> start() => _load(announce: false);

  Future<void> refresh() => _load();

  Future<void> _load({bool announce = true}) async {
    final generation = ++_generation;
    _loading = true;
    _error = null;
    if (announce) _notify();
    try {
      final record = isChapter ? repository.chapter(id) : repository.council(id);
      final results = await Future.wait<Object?>([record, repository.content(kind, id)]);
      if (generation != _generation) return;
      final got = results[0];
      if (got is AdminChapter) _chapter = got;
      if (got is AdminCouncil) _council = got;
      _gone = got == null;
      _content = results[1] as OrgContent;
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

  Future<String?> _change(Future<void> Function() change, {bool reload = true}) async {
    try {
      await change();
    } catch (e) {
      return ApiError.from(e).message;
    }
    if (reload) await _load();
    return null;
  }

  Future<String?> saveChapter(ChapterDraft draft) =>
      _change(() => repository.updateChapter(id, draft.body(was: _chapter)));

  Future<String?> saveCouncil(CouncilDraft draft) =>
      _change(() => repository.updateCouncil(id, draft.body(was: _council)));

  /// Retires the record (a soft delete). The page closes after it, so nothing is read again.
  Future<String?> retire() async {
    final refusal = await _change(() => repository.retire(kind, id), reload: false);
    if (refusal == null) {
      _gone = true;
      _notify();
    }
    return refusal;
  }

  Future<String?> addSponsor(Map<String, Object?> body) => _change(() => repository.addSponsor(id, body));

  Future<String?> removeSponsor(String sponsorId) => _change(() => repository.removeSponsor(id, sponsorId));

  Future<String?> addResource(Map<String, Object?> body) => _change(() => repository.addResource(kind, id, body));

  Future<String?> removeResource(String resourceId) => _change(() => repository.removeResource(kind, id, resourceId));

  Future<String?> addAnnouncement(Map<String, Object?> body) =>
      _change(() => repository.addAnnouncement(kind, id, body));

  Future<String?> removeAnnouncement(String announcementId) =>
      _change(() => repository.removeAnnouncement(kind, id, announcementId));

  /// Makes someone a chapter lead, joining them if they have not joined.
  Future<String?> addLead(Map<String, Object?> body) => _change(() => repository.addLead(id, body));

  /// A lead's title, LinkedIn link and term.
  Future<String?> saveLead(String userId, Map<String, Object?> body) =>
      _change(() => repository.updateMember(kind, id, userId, body));

  /// Steps a lead down to member.
  Future<String?> stepDown(String userId) =>
      _change(() => repository.updateMember(kind, id, userId, const {'role': 'MEMBER'}));

  /// Makes a member a lead, with a term (an empty end is an open term).
  Future<String?> makeLead(String userId, {required String termStartsOn, required String termEndsOn}) => _change(
    () => repository.updateMember(kind, id, userId, {
      'role': 'LEAD',
      'termStartsOn': termStartsOn,
      'termEndsOn': termEndsOn,
    }),
  );

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
