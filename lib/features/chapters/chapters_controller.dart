import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import 'chapter_models.dart';
import 'chapters_repository.dart';

/// The Chapters board's state: the chapters, the search, the scope and country
/// chips, the filters and sort the directory is narrowed by, and the member's places
/// (taken at once, rolled back if the API refuses). The rules are the website
/// board's (`filterAndSortChapters` in its `chapters/helpers.ts`).
class ChaptersController extends ChangeNotifier {
  ChaptersController(this.repository, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final ChaptersRepository repository;
  final DateTime Function() _clock;

  ChaptersOverview? _overview;
  String _search = '';
  ChapterScope _scope = ChapterScope.all;
  String? _country;
  String? _region;
  String? _city;
  ChapterSize _size = ChapterSize.any;
  ChapterActivity _activity = ChapterActivity.any;
  ChapterSort _sort = ChapterSort.recommended;
  bool _started = false;
  bool _loading = false;
  bool _disposed = false;
  String? _error;
  int _generation = 0;
  int _unread = 0;
  final Set<String> _busy = {};

  bool get started => _started;
  bool get loading => _loading;
  String? get error => _error;
  int get unread => _unread;
  ChaptersOverview? get overview => _overview;
  ChaptersStats? get stats => _overview?.stats;
  String get search => _search;
  ChapterScope get scope => _scope;
  String? get country => _country;
  String? get region => _region;
  String? get city => _city;

  /// The board's clock, for "New" on a card.
  DateTime get now => _clock();
  ChapterSize get size => _size;
  ChapterActivity get activity => _activity;
  ChapterSort get sort => _sort;

  /// A join or leave in flight.
  bool isBusy(ChapterSummary c) => _busy.contains(c.id);

  List<ChapterSummary> get _all => _overview?.chapters ?? const [];

  /// The member's chapters: leads first, then by name.
  List<ChapterSummary> get joined {
    final mine = _all.where((c) => c.joined).toList()
      ..sort((a, b) {
        if (a.role != b.role) return a.role == ChapterRole.lead ? -1 : 1;
        return a.name.compareTo(b.name);
      });
    return mine;
  }

  /// The next few chapter events, soonest first.
  List<ChapterEvent> get meetups => (_overview?.meetups ?? const []).take(3).toList();

  /// The country chips: every country with a chapter, alphabetised.
  List<String> get countries => ({for (final c in _all) c.country}.where((c) => c.isNotEmpty).toList())..sort();

  /// The regions (states) the filter sheet offers, within the country chip when one is on.
  List<String> get regions => ({
    for (final c in _all)
      if (_country == null || c.country == _country) ?c.region,
  }.toList()..sort());

  /// The cities the filter sheet offers, within the country and region on.
  List<String> get cities => ({
    for (final c in _all)
      if ((_country == null || c.country == _country) && (_region == null || c.region == _region)) c.city,
  }.where((c) => c.isNotEmpty).toList()..sort());

  /// How many chapters sit behind a scope chip (the chip's own count).
  int scopeCount(ChapterScope scope) => switch (scope) {
    ChapterScope.all => _all.length,
    ChapterScope.joined => _all.where((c) => c.joined).length,
    ChapterScope.nearby => _all.where(isNearby).length,
  };

  /// A filter other than the search, the scope and the country is on (the sliders glyph wears a dot).
  bool get filtered => _size != ChapterSize.any || _activity != ChapterActivity.any || _region != null || _city != null;

  bool get narrowed => _search.trim().isNotEmpty || _scope != ChapterScope.all || _country != null || filtered;

  /// A chapter the member does not belong to, in a region or country one of their chapters is in.
  bool isNearby(ChapterSummary c) => !c.joined && recommendScore(c) > 0;

  /// The places the member already meets in (country and region), for the
  /// recommendations.
  Set<String> get _myPlaces => {
    for (final c in _all.where((c) => c.joined)) ...[
      'country:${c.country}',
      if (c.region != null) 'region:${c.region}',
    ],
  };

  /// The website's place-overlap score: a shared region counts two, a shared
  /// country one.
  int recommendScore(ChapterSummary c, [Set<String>? places]) {
    final mine = places ?? _myPlaces;
    if (mine.isEmpty) return 0;
    return (mine.contains('region:${c.region}') ? 2 : 0) + (mine.contains('country:${c.country}') ? 1 : 0);
  }

  /// The directory narrowed by the search, the country and the filters, in
  /// the chosen order.
  List<ChapterSummary> get chapters {
    final q = _search.trim().toLowerCase();
    final now = _clock();
    final out = _all.where((c) {
      if (q.isNotEmpty) {
        final hay = '${c.name} ${c.city} ${c.region ?? ''} ${c.country} ${c.description ?? ''}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      if (_scope == ChapterScope.joined && !c.joined) return false;
      if (_scope == ChapterScope.nearby && !isNearby(c)) return false;
      if (_country != null && c.country != _country) return false;
      if (_region != null && c.region != _region) return false;
      if (_city != null && c.city != _city) return false;
      if (!_size.matches(c.memberCount)) return false;
      if (_activity == ChapterActivity.events && c.upcomingEventCount == 0) return false;
      if (_activity == ChapterActivity.fresh && !c.isNew(now)) return false;
      return true;
    }).toList();
    final places = _myPlaces;
    int byName(ChapterSummary a, ChapterSummary b) => a.name.compareTo(b.name);
    out.sort((a, b) {
      switch (_sort) {
        case ChapterSort.members:
          final r = b.memberCount - a.memberCount;
          return r != 0 ? r : byName(a, b);
        case ChapterSort.active:
          final r = b.activity - a.activity;
          return r != 0 ? r : byName(a, b);
        case ChapterSort.newest:
          final r = (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0));
          return r != 0 ? r : byName(a, b);
        case ChapterSort.az:
          return byName(a, b);
        case ChapterSort.recommended:
          var r = recommendScore(b, places) - recommendScore(a, places);
          if (r != 0) return r;
          r = b.activity - a.activity;
          return r != 0 ? r : byName(a, b);
      }
    });
    return out;
  }

  Future<void> start() async {
    _started = true;
    await Future.wait([_load(notify: false), _loadUnread()]);
  }

  /// Pull to refresh: everything again, the bell included.
  Future<void> refresh() => Future.wait([_load(notify: true), _loadUnread()]);

  /// [notify] is false for the first load: `start()` runs from `initState`,
  /// before the first build reads `loading`.
  Future<void> _load({required bool notify}) async {
    final generation = ++_generation;
    _loading = true;
    _error = null;
    if (notify) _notify();
    try {
      final overview = await repository.overview();
      if (generation != _generation) return;
      _overview = overview;
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

  Future<void> _loadUnread() async {
    try {
      _unread = await repository.unreadNotifications();
      _notify();
    } catch (_) {}
  }

  void setSearch(String query) {
    if (query.trim() == _search) return;
    _search = query.trim();
    _notify();
  }

  void setScope(ChapterScope scope) {
    _scope = scope;
    _notify();
  }

  /// A country chip; moving to another country drops a region or city the new one has no chapter in.
  void setCountry(String? country) {
    _country = country;
    if (_region != null && !regions.contains(_region)) _region = null;
    if (_city != null && !cities.contains(_city)) _city = null;
    _notify();
  }

  /// A region (state) filter from the sheet; its city, if one was on, goes unless it is in the region.
  void setRegion(String? region) {
    _region = region;
    if (_city != null && !cities.contains(_city)) _city = null;
    _notify();
  }

  void setCity(String? city) {
    _city = city;
    _notify();
  }

  /// [clearRegion] / [clearCity] put "Any" back (a null argument means "leave it").
  void setFilters({
    ChapterSize? size,
    ChapterActivity? activity,
    ChapterSort? sort,
    bool clearRegion = false,
    bool clearCity = false,
  }) {
    _size = size ?? _size;
    _activity = activity ?? _activity;
    _sort = sort ?? _sort;
    if (clearRegion) _region = null;
    if (clearCity) _city = null;
    _notify();
  }

  void clearFilters() {
    _search = '';
    _scope = ChapterScope.all;
    _country = null;
    _region = null;
    _city = null;
    _size = ChapterSize.any;
    _activity = ChapterActivity.any;
    _notify();
  }

  ChapterSummary? find(String id) => _all.where((c) => c.id == id).firstOrNull;

  /// Takes a place in the chapter; a sentence when the API refuses.
  Future<String?> join(ChapterSummary chapter) async {
    if (chapter.joined || _busy.contains(chapter.id)) return null;
    _busy.add(chapter.id);
    _apply(chapter.id, (c) => c.copyWith(role: ChapterRole.member, memberCount: c.memberCount + 1));
    try {
      final role = await repository.join(chapter);
      _apply(chapter.id, (c) => c.copyWith(role: role));
      return null;
    } catch (e) {
      _apply(chapter.id, (c) => c.copyWith(clearRole: true, memberCount: c.memberCount - 1));
      return ApiError.from(e).message;
    } finally {
      _busy.remove(chapter.id);
      _notify();
    }
  }

  /// Gives the place up; a sentence when the API refuses.
  Future<String?> leave(ChapterSummary chapter) async {
    if (!chapter.joined || _busy.contains(chapter.id)) return null;
    final role = chapter.role!;
    _busy.add(chapter.id);
    _apply(chapter.id, (c) => c.copyWith(clearRole: true, memberCount: c.memberCount - 1));
    try {
      await repository.leave(chapter);
      return null;
    } catch (e) {
      _apply(chapter.id, (c) => c.copyWith(role: role, memberCount: c.memberCount + 1));
      return ApiError.from(e).message;
    } finally {
      _busy.remove(chapter.id);
      _notify();
    }
  }

  /// A chapter's page changed the member's place: the board follows it.
  void update(ChapterSummary changed) {
    if (find(changed.id) == null) return;
    _apply(changed.id, (_) => changed);
  }

  void _apply(String id, ChapterSummary Function(ChapterSummary) change) {
    final o = _overview;
    if (o == null) return;
    _overview = o.copyWith(chapters: [for (final c in o.chapters) c.id == id ? change(c) : c]);
    _notify();
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
