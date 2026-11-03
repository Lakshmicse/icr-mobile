import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import 'rfq_models.dart';
import 'rfq_repository.dart';

/// The board's tabs: everything posted, or one status of it (`GET /rfq?status=`). A cancelled requirement shows
/// under All only, as on the website.
enum PostedTab {
  all(null, 'All'),
  open(RfqStatus.published, 'Open'),
  awarded(RfqStatus.awarded, 'Awarded'),
  closed(RfqStatus.closed, 'Closed');

  const PostedTab(this.status, this.label);
  final RfqStatus? status;
  final String label;
}

/// "Requirements": every requirement posted on ICR, newest first (the website's `/rfq`), with search, a tab per
/// status and paging. Who is reading decides only where a card opens (their own requirement opens the owner's page)
/// and which of Post RFQ, My RFQ's and Find work the toolbar offers; the list is the same for everyone.
class RequirementsBoardController extends ChangeNotifier {
  RequirementsBoardController(this.repository, {this.pageSize = 100});

  final RfqRepository repository;

  /// The API's largest page. Large on purpose: the portal's `GET /rfq` answers every page with the first one
  /// (`docs/backend-requests/rfq.md` §3), and the owner keeps the portal as it is (portal changes are for payments
  /// and the forum only, 3 Nov 2026), so the first page is all the board can show of a tab or a search. [cutShort]
  /// says so; the tabs and the search reach the rest.
  final int pageSize;

  List<Requirement> _rows = const [];
  PostedTab _tab = PostedTab.all;
  String _search = '';
  int _page = 1;
  bool _hasMore = false;
  int _total = 0;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  Poster? _poster;
  int _unread = 0;
  int? _mine;
  bool _started = false;
  int _generation = 0;

  List<Requirement> get rows => _rows;
  PostedTab get tab => _tab;
  String get search => _search;
  bool get hasMore => _hasMore;

  /// How many the API holds for this tab and search (the line above the cards).
  int get total => _total;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  String? get error => _error;

  /// Who is reading; null until read (or when it could not be, which only hides the toolbar's role-bound chips).
  Poster? get poster => _poster;
  int get unread => _unread;

  /// How many requirements the reader's own list holds, for the My RFQ's chip (the figure the Marketplace's chip
  /// shows); null when not known.
  int? get mine => _mine;
  bool get started => _started;

  /// A search narrows the list (the empty state says so and offers to clear it).
  bool get narrowed => _search.isNotEmpty;

  /// The API counts more than the board could read (see [pageSize]): the board says it shows only the newest.
  bool get cutShort => !_loading && !_hasMore && _rows.isNotEmpty && _rows.length < _total;

  /// The reader runs [r]: it opens on the owner's page rather than the one suppliers read.
  bool manages(Requirement r) => _poster?.manages(r) ?? false;

  /// Post RFQ: for everyone but a company member whose role does not post (the composer itself explains a missing
  /// company to someone acting as themselves).
  bool get offersPost => !(_poster?.roleCannotPost ?? false);

  /// My RFQ's: the roles that run requirements, and anyone acting as themselves (whose enquiries the list holds).
  bool get offersMine {
    final p = _poster;
    return p != null && (p.canPost || p.companyId == null);
  }

  /// Find work: the roles the supplier board is open to.
  bool get offersFindWork => _poster?.canSell ?? false;

  Future<void> start() async {
    _started = true;
    await Future.wait([_load(notify: false), _readAround()]);
  }

  Future<void> refresh() => Future.wait([_load(notify: true), _readAround()]).then((_) {});

  /// Who is reading, the bell's count and the reader's own count: none of them may keep the board from showing.
  Future<void> _readAround() async {
    try {
      _poster = await repository.me();
    } catch (_) {}
    try {
      _unread = await repository.unreadNotifications();
    } catch (_) {}
    final p = _poster;
    if (p != null && (p.canPost || p.companyId == null)) {
      try {
        _mine = (await repository.summary()).open;
      } catch (_) {
        _mine = null;
      }
    }
    notifyListeners();
  }

  Future<void> _load({required bool notify}) async {
    final generation = ++_generation;
    _loading = true;
    _error = null;
    if (notify) notifyListeners();
    try {
      final page = await repository.posted(search: _search, status: _tab.status, limit: pageSize);
      if (generation != _generation) return;
      _rows = page.rows;
      _hasMore = page.hasMore;
      _total = page.total;
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

  Future<void> setTab(PostedTab tab) async {
    if (tab == _tab) return;
    _tab = tab;
    _rows = const [];
    await _load(notify: true);
  }

  Future<void> setSearch(String query) async {
    if (query.trim() == _search) return;
    _search = query.trim();
    await _load(notify: true);
  }

  Future<void> loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    final generation = _generation;
    _loadingMore = true;
    notifyListeners();
    try {
      final page = await repository.posted(search: _search, status: _tab.status, page: _page + 1, limit: pageSize);
      if (generation != _generation) return;
      final fresh = page.rows.where((r) => !_rows.any((x) => x.id == r.id)).toList();
      _rows = [..._rows, ...fresh];
      // A page that brings nothing new is the list repeating itself (the portal's paging fault, see [pageSize]):
      // stop rather than ask again on every scroll.
      _hasMore = page.hasMore && fresh.isNotEmpty;
      _total = page.total;
      _page++;
    } catch (_) {
      // The next scroll tries again.
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }
}
