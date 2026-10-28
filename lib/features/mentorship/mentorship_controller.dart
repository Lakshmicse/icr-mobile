import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import 'mentorship_models.dart';
import 'mentorship_repository.dart';

/// The Mentorship tab's state: the landing's shelves and bands, the selected
/// category, and the member's saved mentors (applied at once, rolled back if
/// the API refuses).
class MentorshipController extends ChangeNotifier {
  MentorshipController(this.repository);

  final MentorshipRepository repository;

  MentorshipOverview? _overview;
  String? _category;
  bool _loading = false;
  String? _error;
  int _unread = 0;
  int _generation = 0;
  bool _started = false;

  bool get started => _started;
  MentorshipOverview? get overview => _overview;
  bool get loading => _loading;
  String? get error => _error;
  int get unread => _unread;

  /// The category chip that is on, if any.
  String? get selectedCategory => _category ?? _overview?.selectedCategory;

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
      final overview = await repository.overview(category: _category);
      if (generation != _generation) return;
      _overview = overview;
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

  /// Scopes the mentor shelves to a domain; the same chip again clears it.
  Future<void> selectCategory(String? label) async {
    _category = label == selectedCategory ? null : label;
    await refresh();
  }

  /// Bookmarks the mentor (or takes the bookmark back); a sentence when it fails.
  Future<String?> toggleSave(Mentor mentor) async {
    final saved = !mentor.saved;
    _apply(mentor.id, saved);
    try {
      await repository.setSaved(mentor, saved);
      return null;
    } catch (e) {
      _apply(mentor.id, !saved);
      return ApiError.from(e).message;
    }
  }

  Mentor? find(String id) {
    for (final shelf in _overview?.shelves ?? const <MentorShelf>[]) {
      for (final m in shelf.mentors) {
        if (m.id == id) return m;
      }
    }
    return null;
  }

  void _apply(String id, bool saved) {
    final overview = _overview;
    if (overview == null) return;
    _overview = overview.copyWith(
      shelves: [
        for (final s in overview.shelves)
          s.copyWith(mentors: [for (final m in s.mentors) m.id == id ? m.copyWith(saved: saved) : m]),
      ],
    );
    notifyListeners();
  }

  Future<void> _loadUnread() async {
    try {
      _unread = await repository.unreadNotifications();
      notifyListeners();
    } catch (_) {}
  }
}

/// The Find Mentors screen's state: the filters, the pages read so far and the
/// directory's total.
class FindMentorsController extends ChangeNotifier {
  FindMentorsController(
    this.repository, {
    String? category,
    String search = '',
    String? company,
    bool companyOnAccount = false,
    int? minExperience,
  }) : _filters = MentorFilters(
         category: category,
         search: search,
         company: company,
         companyOnAccount: company != null && companyOnAccount,
         minExperience: minExperience,
       );

  final MentorshipRepository repository;

  MentorFilters _filters;
  List<MentorCategory> _categories = const [];
  List<Mentor> _mentors = const [];
  int _total = 0;
  bool _hasMore = false;
  int _page = 1;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  int _unread = 0;
  int _generation = 0;

  MentorFilters get filters => _filters;

  /// The category chips: every domain a listed mentor has.
  List<MentorCategory> get categories => _categories;
  List<Mentor> get mentors => _mentors;
  int get total => _total;
  bool get hasMore => _hasMore;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  String? get error => _error;
  int get unread => _unread;

  Future<void> start() async {
    await Future.wait([_load(notify: false), _loadUnread(), _loadCategories()]);
  }

  Future<void> _loadCategories() async {
    try {
      _categories = await repository.categories();
      notifyListeners();
    } catch (_) {
      // The chips are an aid; the list still works without them.
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
      final page = await repository.search(_filters);
      if (generation != _generation) return;
      _mentors = page.mentors;
      _total = page.total;
      _hasMore = page.hasMore;
      _page = 1;
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

  /// "Load more mentors": the next page, appended.
  Future<void> loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    _loadingMore = true;
    notifyListeners();
    try {
      final page = await repository.search(_filters, page: _page + 1);
      _mentors = [..._mentors, ...page.mentors.where((m) => !_mentors.any((r) => r.id == m.id))];
      _total = page.total;
      _hasMore = page.hasMore;
      _page++;
    } catch (_) {
      // The next tap tries again.
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  Future<void> setCategory(String? label) => _set(
    label == null || label == _filters.category
        ? _filters.copyWith(clearCategory: true)
        : _filters.copyWith(category: label),
  );

  /// Searches by words. A company known only from a current-role line is itself
  /// found by words, so typing others replaces its chip; a company on mentors'
  /// ICR accounts is a filter of its own and stays.
  Future<void> setSearch(String query) async {
    final words = query.trim();
    if (words == _filters.search) return;
    final replacesCompany = words.isNotEmpty && _filters.company != null && !_filters.companyOnAccount;
    await _set(_filters.copyWith(search: words, clearCompany: replacesCompany));
  }

  /// The cross on the "Company: SpaceX" chip.
  Future<void> clearCompany() => _set(_filters.copyWith(clearCompany: true));

  Future<void> setSort(MentorSort sort) => _set(_filters.copyWith(sort: sort));

  Future<void> setMinExperience(int? years) =>
      _set(years == null ? _filters.copyWith(clearExperience: true) : _filters.copyWith(minExperience: years));

  Future<void> setAvailableOnly(bool on) => _set(_filters.copyWith(availableOnly: on));

  Future<void> setFilters(MentorFilters filters) => _set(filters);

  Future<void> _set(MentorFilters filters) async {
    _filters = filters;
    await refresh();
  }

  Future<String?> toggleSave(Mentor mentor) async {
    final saved = !mentor.saved;
    _apply(mentor.id, saved);
    try {
      await repository.setSaved(mentor, saved);
      return null;
    } catch (e) {
      _apply(mentor.id, !saved);
      return ApiError.from(e).message;
    }
  }

  void _apply(String id, bool saved) {
    _mentors = [for (final m in _mentors) m.id == id ? m.copyWith(saved: saved) : m];
    notifyListeners();
  }

  Future<void> _loadUnread() async {
    try {
      _unread = await repository.unreadNotifications();
      notifyListeners();
    } catch (_) {}
  }
}
