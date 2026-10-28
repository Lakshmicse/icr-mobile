import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import 'assess_models.dart';
import 'assess_repository.dart';

/// The website's access facet: a programme or subject that holds a free paper, or a paid one.
enum AccessFilter {
  all('All'),
  free('Free'),
  paid('Paid');

  const AccessFilter(this.label);
  final String label;
}

/// What a card says of a group for this member: how much of it is open to them and how they did.
class GroupSummary {
  const GroupSummary({
    required this.total,
    required this.open,
    required this.passed,
    required this.started,
    required this.known,
    this.included = 0,
    this.bestPercent,
  });

  final int total;

  /// Papers the member may sit now (all of them when [known] is false).
  final int open;
  final int passed;
  final int started;

  /// Papers the plan opens with a free place of its own (the course is not opened yet).
  final int included;

  /// The member's unlocks were read; false leaves every paper reading as open.
  final bool known;
  final int? bestPercent;

  bool get allOpen => open == total;
  bool get noneOpen => open == 0;

  /// None is open yet, but the plan has a place that opens all of it.
  bool get planWouldOpen => noneOpen && included == total;
}

/// One door's landing: the programmes (Assess Your Knowledge) or subjects (Mock Exams), a search over them, the
/// member's unlocks and results, and the bell. The group screens read the same member state, so a level opened
/// there shows on the grid at once.
class CatalogueController extends ChangeNotifier {
  CatalogueController({required this.repository, required this.kind});

  final AssessRepository repository;
  final PaperKind kind;

  List<PaperGroup> _all = const [];
  MemberLearning _member = MemberLearning.none;
  bool _loading = false;
  String? _error;
  String _search = '';
  AccessFilter _filter = AccessFilter.all;
  int _unread = 0;
  bool _started = false;
  bool _disposed = false;
  int _generation = 0;

  bool get started => _started;
  bool get loading => _loading;
  String? get error => _error;
  String get search => _search;
  AccessFilter get filter => _filter;
  int get unread => _unread;
  MemberLearning get member => _member;

  /// Either the search or the facet narrows the grid.
  bool get narrowed => _search.isNotEmpty || _filter != AccessFilter.all;

  /// A partner institute's certification is catalogued under Professional Development, so it is not listed here.
  bool get hasPartner => _all.any((g) => g.isPartner);

  /// ICR's own, in the catalogue's order: the order staff set, ties alphabetical.
  List<PaperGroup> get groups {
    final own = [
      for (final g in _all)
        if (!g.isPartner && g.papers.isNotEmpty) g,
    ];
    own.sort((a, b) {
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      return byOrder != 0 ? byOrder : a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return own;
  }

  /// The groups the search and the facet leave. Every word of the query must appear somewhere in the group's
  /// title, code, summary, knowledge areas or paper titles (the website's `matchesTerms`).
  List<PaperGroup> get visible {
    final terms = _search.toLowerCase().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    return [
      for (final g in groups)
        if (terms.every(g.haystack.contains) &&
            (_filter == AccessFilter.all || (_filter == AccessFilter.free ? g.anyFree : g.anyPaid)))
          g,
    ];
  }

  GroupSummary summaryOf(PaperGroup group) {
    final known = _member.access != null;
    var open = 0;
    var passed = 0;
    var started = 0;
    var included = 0;
    int? best;
    for (final p in group.papers) {
      final access = _member.accessOf(p);
      if (access == PaperAccess.open) open++;
      if (access == PaperAccess.planPlace) included++;
      final progress = _member.progressOf(p.id);
      if (progress.passed) passed++;
      if (progress.started) {
        started++;
        if (best == null || progress.bestPercent > best) best = progress.bestPercent;
      }
    }
    return GroupSummary(
      total: group.papers.length,
      open: open,
      passed: passed,
      started: started,
      known: known,
      included: included,
      bestPercent: best,
    );
  }

  Future<void> start() async {
    _started = true;
    await Future.wait([_load(notify: false), _loadUnread()]);
  }

  Future<void> refresh() => _load(notify: true);

  /// [notify] is false for the first load: `start()` runs from `initState`, before the first build reads
  /// `loading`, and a notification there lands in the middle of a build.
  Future<void> _load({required bool notify}) async {
    final generation = ++_generation;
    _loading = true;
    _error = null;
    if (notify) _notify();
    try {
      final results = await Future.wait<Object>([repository.groups(kind), repository.member(kind)]);
      if (generation != _generation) return;
      _all = results[0] as List<PaperGroup>;
      _member = results[1] as MemberLearning;
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

  /// Reads what the member holds and how they did again (after a sitting, an unlock, a plan place taken).
  Future<void> refreshMember() async {
    try {
      final next = await repository.member(kind);
      _member = next;
      _notify();
    } catch (_) {
      // Keep what is on show.
    }
  }

  /// A paper opened with ICR credits shows open at once (the API's answer is read again straight after).
  void unlockLocally(String paperId, {required int credits, bool withCredits = false}) {
    final access = _member.access;
    if (access == null) return;
    _member = _member.copyWith(
      access: access.copyWith(
        paperIds: {...access.paperIds, paperId},
        creditPaperIds: withCredits ? {...access.creditPaperIds, paperId} : access.creditPaperIds,
        icrCredits: credits,
      ),
    );
    _notify();
  }

  /// Every level or set of a bundle opened with ICR credits shows open at once (the API's answer is read again
  /// straight after); the courses they belong to are noted for the flash-card decks that follow them.
  void unlockBundleLocally(
    Iterable<String> paperIds, {
    required int credits,
    Iterable<String> courseIds = const [],
  }) {
    final access = _member.access;
    if (access == null) return;
    _member = _member.copyWith(
      access: access.copyWith(
        paperIds: {...access.paperIds, ...paperIds},
        creditPaperIds: {...access.creditPaperIds, ...paperIds},
        unlockedCourseIds: {...access.unlockedCourseIds, ...courseIds},
        icrCredits: credits,
      ),
    );
    _notify();
  }

  /// A course or mock exam opened with a plan place shows open at once.
  void openPlaceLocally(PaperKind kind, String id) {
    final access = _member.access;
    if (access == null) return;
    final places = access.places(kind);
    if (places.opened.contains(id)) return;
    final next = PlanPlaces(limit: places.limit, opened: [...places.opened, id]);
    _member = _member.copyWith(
      access: kind == PaperKind.mock ? access.copyWith(mocks: next) : access.copyWith(courses: next),
    );
    _notify();
  }

  /// A group's papers read afresh by its own screen: keep the grid's copy in step.
  void update(PaperGroup group) {
    _all = [for (final g in _all) g.id == group.id ? group : g];
    _notify();
  }

  void setSearch(String query) {
    final q = query.trim();
    if (q == _search) return;
    _search = q;
    _notify();
  }

  void setFilter(AccessFilter filter) {
    if (filter == _filter) return;
    _filter = filter;
    _notify();
  }

  void reset() {
    _search = '';
    _filter = AccessFilter.all;
    _notify();
  }

  Future<void> _loadUnread() async {
    try {
      _unread = await repository.unreadNotifications();
      _notify();
    } catch (_) {}
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
