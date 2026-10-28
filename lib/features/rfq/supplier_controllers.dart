import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import 'rfq_links.dart' show RfqClock;
import 'rfq_models.dart';
import 'rfq_repository.dart';
import 'rfq_rules.dart';

/// Why the supplier's screens cannot show the board, and the next step.
enum SupplierGate {
  /// The account's role is not one that sells (a buyer, a professional).
  role,

  /// The company has no supplier listing yet.
  noListing,
}

/// The board's tabs: matched to the supplier's services, everything open, or
/// the requirements the supplier was invited to.
enum BoardTab {
  recommended('Recommended'),
  open('All open'),
  invited('Invited');

  const BoardTab(this.label);
  final String label;
}

/// Reads who is asking and what their company may do, and says why not.
mixin _SupplierAccess on ChangeNotifier {
  RfqRepository get repository;

  Poster? poster;
  VendorAccess? access;
  SupplierGate? gate;
  String? gateMessage;

  /// Null when the supplier screens may show; the gate otherwise.
  Future<void> readAccess() async {
    final results = await Future.wait<Object?>([
      repository.me().then<Object?>((p) => p, onError: (Object _) => null),
      repository.access().then<Object?>((a) => a, onError: (Object e) => ApiError.from(e)),
    ]);
    poster = results[0] as Poster?;
    final a = results[1];
    if (a is ApiError) {
      if (a.statusCode == 403) {
        gate = SupplierGate.role;
        gateMessage = a.message;
        return;
      }
      throw a;
    }
    access = a as VendorAccess;
    if (!access!.hasListing) {
      gate = SupplierGate.noListing;
      gateMessage = null;
    } else {
      gate = null;
      gateMessage = null;
    }
  }

  /// "Start selling": the company's supplier listing, one tap, as the website.
  Future<String?> startSelling() async {
    final companyId = poster?.companyId;
    if (companyId == null) return 'Selling starts from a company page.';
    try {
      await repository.startSelling(companyId);
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    }
  }
}

/// "Find work & bid": the open board for a supplier, by tab, search, sort and
/// filters, with what they were invited to.
class SupplierBoardController extends ChangeNotifier with _SupplierAccess {
  SupplierBoardController(this.repository, {this.pageSize = 20});

  @override
  final RfqRepository repository;
  final int pageSize;

  BoardTab _tab = BoardTab.recommended;
  BoardQuery _query = const BoardQuery(matchedOnly: true);
  List<Requirement> _rows = const [];
  List<Requirement> _invited = const [];
  int _page = 1;
  bool _hasMore = false;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  int _unread = 0;
  int _myBids = 0;
  bool _started = false;
  int _generation = 0;

  BoardTab get tab => _tab;
  BoardQuery get query => _query;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  String? get error => _error;
  int get unread => _unread;
  bool get started => _started;
  bool get hasMore => _tab != BoardTab.invited && _hasMore;

  /// Invitations still waiting for a reply (the tab's count).
  int get invitedOpen => _invited.where((r) => r.inviteStatus == InviteStatus.invited).length;
  int get myBidCount => _myBids;

  /// The rows of the tab on show. Invitations still waiting lead; declined ones are left out.
  List<Requirement> get rows {
    if (_tab != BoardTab.invited) return _rows;
    final q = _query.search.trim().toLowerCase();
    final list = _invited
        .where((r) => r.inviteStatus != InviteStatus.declined)
        .where((r) => q.isEmpty || r.title.toLowerCase().contains(q) || (r.city ?? '').toLowerCase().contains(q))
        .toList();
    return [
      ...list.where((r) => r.inviteStatus == InviteStatus.invited),
      ...list.where((r) => r.inviteStatus != InviteStatus.invited),
    ];
  }

  /// How many pages one read may walk to fill a screenful when the "Verified buyers" filter thins them out.
  static const _fillPages = 5;

  /// Reads the board from [first]. The API applies "Verified buyers" after it has cut the page, so a page can come back
  /// short, or empty, with more waiting behind it: the board asks for whole pages, keeps the verified buyers' itself,
  /// and walks on while a page of rows has not been gathered. [hasMore] is about the API's pages, never the kept rows.
  Future<({List<Requirement> rows, int page, bool hasMore})> _readBoard(int first) async {
    final rows = <Requirement>[];
    var page = first;
    var hasMore = false;
    for (var walked = 0; walked < _fillPages; walked++) {
      final raw = await repository.openBoard(_query.copyWith(verifiedBuyer: false), page: page, limit: pageSize);
      for (final r in raw) {
        if (_query.verifiedBuyer && !(r.buyer?.verified ?? false)) continue;
        if (!rows.any((x) => x.id == r.id)) rows.add(r);
      }
      hasMore = raw.length >= pageSize;
      if (!_query.verifiedBuyer || !hasMore || rows.length >= pageSize) break;
      page++;
    }
    return (rows: rows, page: page, hasMore: hasMore);
  }

  Future<void> start() async {
    _started = true;
    await _load(notify: false);
  }

  Future<void> refresh() => _load(notify: true);

  Future<void> _load({required bool notify}) async {
    final generation = ++_generation;
    _loading = true;
    _error = null;
    if (notify) notifyListeners();
    try {
      await readAccess();
      if (generation != _generation) return;
      if (gate == null) {
        final results = await Future.wait<Object?>([
          _tab == BoardTab.invited
              ? Future.value((rows: const <Requirement>[], page: 1, hasMore: false))
              : _readBoard(1),
          repository.invited().catchError((Object _) => const <Requirement>[]),
          repository.myBids().then<Object?>((b) => b.length, onError: (Object _) => 0),
          repository.unreadNotifications().then<Object?>((n) => n, onError: (Object _) => 0),
        ]);
        if (generation != _generation) return;
        final board = results[0] as ({List<Requirement> rows, int page, bool hasMore});
        _rows = board.rows;
        _invited = results[1] as List<Requirement>;
        _myBids = results[2] as int;
        _unread = results[3] as int;
        _page = board.page;
        _hasMore = board.hasMore;
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

  Future<void> _reloadBoard() async {
    if (_tab == BoardTab.invited) {
      notifyListeners();
      return;
    }
    final generation = ++_generation;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final board = await _readBoard(1);
      if (generation != _generation) return;
      _rows = board.rows;
      _page = board.page;
      _hasMore = board.hasMore;
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

  Future<void> setTab(BoardTab tab) async {
    if (tab == _tab) return;
    _tab = tab;
    _query = _query.copyWith(matchedOnly: tab == BoardTab.recommended);
    await _reloadBoard();
  }

  Future<void> setSearch(String text) async {
    if (text.trim() == _query.search) return;
    _query = _query.copyWith(search: text.trim());
    await _reloadBoard();
  }

  Future<void> setSort(BoardSort sort) async {
    if (sort == _query.sort) return;
    _query = _query.copyWith(sort: sort);
    await _reloadBoard();
  }

  /// "Closing soon": requirements closing within a week, on and off.
  Future<void> toggleClosingSoon() async {
    _query = _query.closingInDays == null ? _query.copyWith(closingInDays: 7) : _query.copyWith(clearClosing: true);
    await _reloadBoard();
  }

  Future<void> toggleVerifiedBuyers() async {
    _query = _query.copyWith(verifiedBuyer: !_query.verifiedBuyer);
    await _reloadBoard();
  }

  Future<void> setFilters({String? city, double? minBudget, double? maxBudget}) async {
    _query = _query.copyWith(
      city: city,
      clearCity: city == null || city.trim().isEmpty,
      minBudget: minBudget,
      clearMin: minBudget == null,
      maxBudget: maxBudget,
      clearMax: maxBudget == null,
    );
    await _reloadBoard();
  }

  Future<void> clearFilters() async {
    _query = _query.cleared();
    await _reloadBoard();
  }

  Future<void> loadMore() async {
    if (_loading || _loadingMore || !hasMore) return;
    _loadingMore = true;
    notifyListeners();
    try {
      final next = await _readBoard(_page + 1);
      _rows = [..._rows, ...next.rows.where((r) => !_rows.any((x) => x.id == r.id))];
      _page = next.page;
      _hasMore = next.hasMore;
    } catch (_) {
      // The next scroll tries again.
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  Future<String?> startSellingAndReload() async {
    final message = await startSelling();
    if (message == null) await refresh();
    return message;
  }
}

/// What the response card of a requirement shows the supplier.
enum ResponseState {
  /// Their bid or reply is in.
  sent,

  /// The requirement is their own company's: the API refuses a bid on it.
  own,

  /// The account is not a supplier's (a buyer, a professional): nothing to respond with.
  notSupplier,

  /// The requirement no longer takes responses.
  closed,

  /// They declined the invitation.
  declined,

  /// Their company has no supplier listing.
  noListing,

  /// A staged RFQ in pre-qualification: the criteria answers.
  preQual,

  /// Pre-qualification answers are in and being screened.
  screening,

  /// Quotes are closed and being weighed.
  evaluation,

  /// The bid (or reply) form.
  form,
}

/// A requirement as a supplier reads it: the brief, the buyer, the match and
/// their own response, and every way they answer it (bid, change or withdraw a
/// bid where the API allows it, pre-qualify, decline an invitation, message the
/// buyer, see the buyer's contact).
class OpportunityController extends ChangeNotifier with _SupplierAccess {
  OpportunityController({required this.repository, required this.rfqId});

  @override
  final RfqRepository repository;
  final String rfqId;

  Requirement? _rfq;
  OpportunityContext? _context;
  bool _loading = false;
  String? _error;
  int? _errorStatus;
  bool _declined = false;
  bool _preQualSent = false;
  bool _sending = false;
  BuyerContact? _contact;
  int _unread = 0;
  bool _started = false;

  Requirement? get rfq => _rfq;
  OpportunityContext? get context => _context;
  MyBid? get myBid => _context?.myBid;
  bool get loading => _loading;
  String? get error => _error;

  /// The status of the API's refusal to show the requirement: 403 is the early-access window (the sentence says
  /// when it opens and which plan sees it now), 404 a draft, a private requirement or one that does not exist.
  int? get errorStatus => _errorStatus;
  bool get declined => _declined;
  bool get sending => _sending;
  BuyerContact? get contact => _contact;
  int get unread => _unread;
  bool get started => _started;

  /// Invited to it: a private requirement only the invited suppliers read.
  bool get invitedOnly => _rfq?.visibility == RfqVisibility.targeted;

  /// The company's own requirement, or one this person posted: the API refuses a bid on it.
  bool get own {
    final r = _rfq;
    final p = poster;
    if (r == null || p == null) return false;
    return (r.buyerId != null && r.buyerId == p.id) || (r.companyId != null && r.companyId == p.companyId);
  }

  ResponseState get state {
    final r = _rfq;
    if (own) return ResponseState.own;
    if (myBid != null) return ResponseState.sent;
    if (gate == SupplierGate.role) return ResponseState.notSupplier;
    if (r == null || !r.live) return ResponseState.closed;
    if (_declined) return ResponseState.declined;
    if (access != null && !access!.hasListing) return ResponseState.noListing;
    if (r.staged && r.stage == RfqStage.prequalification) {
      return _preQualSent ? ResponseState.screening : ResponseState.preQual;
    }
    if (r.staged && r.stage == RfqStage.shortlisting) return ResponseState.screening;
    if (r.staged && (r.stage == RfqStage.evaluation || r.stage == RfqStage.completed)) return ResponseState.evaluation;
    return ResponseState.form;
  }

  /// The words under the reply form about the allowance.
  String? get allowance {
    final a = access;
    final r = _rfq;
    if (a == null || r == null) return null;
    if (r.isEnquiry) return "Replying to an enquiry doesn't use your monthly bids.";
    return a.bidLimit == null
        ? 'Your plan includes unlimited bids.'
        : '${a.bidsUsed} of ${a.bidLimit} bids used this month.';
  }

  /// Why the form cannot send yet, before the API says so.
  String? get blocker {
    final a = access;
    final r = _rfq;
    if (a == null || r == null) return null;
    if (!a.verified) return 'Your supplier listing must be verified before you can respond.';
    if (!r.isEnquiry && !a.canBid) return "You've used this month's bids. Your plan includes more on a higher tier.";
    return null;
  }

  /// The bid already sent is still being weighed on a requirement that still takes responses: the only time a
  /// change or a withdrawal would make sense.
  bool get _bidStillOpen {
    final b = myBid;
    final r = _rfq;
    if (b == null || r == null || !r.live) return false;
    if (b.isAwarded || b.status == BidStatus.awarded || b.status == BidStatus.rejected) return false;
    final due = r.dueDate;
    return due == null || due.isAfter(RfqClock.now());
  }

  /// The supplier may change or withdraw the bid already sent: the API allows it ([RfqRepository.supportsBidChanges])
  /// and the bid is still being weighed on a requirement that still takes responses.
  bool get canChangeBid => repository.supportsBidChanges && _bidStillOpen;

  /// The bid could still be corrected, but the portal has no call for it (`docs/backend-requests/rfq.md`): the page
  /// says so and sends the supplier to the buyer, instead of leaving two missing buttons unexplained.
  bool get bidChangesNeedBuyer => !repository.supportsBidChanges && _bidStillOpen;

  Future<void> start() async {
    _started = true;
    await _load(notify: false);
    try {
      await repository.markSeen(AlertSide.supplier, rfqId);
    } catch (_) {}
  }

  Future<void> refresh() => _load(notify: true);

  Future<void> _load({required bool notify}) async {
    _loading = true;
    _error = null;
    _errorStatus = null;
    if (notify) notifyListeners();
    try {
      final results = await Future.wait<Object?>([
        repository.requirement(rfqId),
        repository.opportunity(rfqId).then<Object?>((c) => c, onError: (Object e) => ApiError.from(e)),
        readAccess().then<Object?>((_) => null, onError: (Object e) => ApiError.from(e)),
        repository.unreadNotifications().then<Object?>((n) => n, onError: (Object _) => 0),
      ]);
      _rfq = results[0] as Requirement;
      final ctx = results[1];
      if (ctx is OpportunityContext) {
        _context = ctx;
      } else if (ctx is ApiError && ctx.statusCode != 403) {
        throw ctx;
      }
      // `GET /rfq/:id` does not say whether this supplier declined; only the invitation list does, so a private
      // requirement asks it once (a failure leaves the page as it was: the form, which the API still guards).
      var invite = _rfq!.inviteStatus;
      if (invite == null && _rfq!.visibility == RfqVisibility.targeted) {
        try {
          for (final row in await repository.invited()) {
            if (row.id == rfqId) invite = row.inviteStatus;
          }
        } catch (_) {}
      }
      _declined = invite == InviteStatus.declined;
      _unread = results[3] as int;
    } catch (e) {
      final error = ApiError.from(e);
      _error = error.message;
      _errorStatus = error.statusCode;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Sends the bid (or the reply). Null when it went; else the sentence to show.
  Future<String?> placeBid(BidDraft draft) async {
    final r = _rfq;
    if (r == null || _sending) return null;
    final problems = draft.problems(enquiry: r.isEnquiry);
    if (problems.isNotEmpty) return problems.values.first;
    _sending = true;
    notifyListeners();
    try {
      final bid = await repository.placeBid(rfqId, draft.toJson());
      _context = _withBid(bid);
      _rfq = r.copyWith(hasBid: true);
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  /// Changes the bid already sent. Null when it went; else the sentence to show (the form keeps what was typed).
  Future<String?> updateBid(BidDraft draft) async {
    final r = _rfq;
    if (r == null || _sending) return null;
    final problems = draft.problems(enquiry: r.isEnquiry);
    if (problems.isNotEmpty) return problems.values.first;
    _sending = true;
    notifyListeners();
    try {
      final bid = await repository.updateBid(rfqId, draft.toJson());
      _context = _withBid(bid);
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  /// Takes the bid back: the form is open again (and the invitation, if there was one).
  Future<String?> withdrawBid() async {
    final r = _rfq;
    if (r == null || _sending || myBid == null) return null;
    _sending = true;
    notifyListeners();
    try {
      await repository.withdrawBid(rfqId);
      _context = _withBid(null);
      _rfq = r.copyWith(hasBid: false);
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  OpportunityContext _withBid(MyBid? bid) => OpportunityContext(
    buyer: _context?.buyer,
    matchScore: _context?.matchScore,
    matched: _context?.matched ?? false,
    reasons: _context?.reasons ?? const [],
    myBid: bid,
  );

  Future<String?> submitPreQual(PreQualDraft draft) async {
    if (_sending) return null;
    final problems = draft.problems();
    if (problems.isNotEmpty) return problems.values.first;
    _sending = true;
    notifyListeners();
    try {
      await repository.submitPreQual(rfqId, draft.toJson());
      _preQualSent = true;
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  /// Declines the invitation: shown at once, taken back if refused.
  Future<String?> decline() async {
    if (_declined || _sending) return null;
    _declined = true;
    notifyListeners();
    try {
      await repository.declineInvite(rfqId);
      return null;
    } catch (e) {
      _declined = false;
      notifyListeners();
      return ApiError.from(e).message;
    }
  }

  /// The thread with the buyer about it.
  Future<({String? id, String? error})> messageBuyer() async {
    try {
      return (id: await repository.openConversation(rfqId), error: null);
    } catch (e) {
      return (id: null, error: ApiError.from(e).message);
    }
  }

  Future<String?> revealContact() async {
    try {
      _contact = await repository.revealContact(rfqId);
      notifyListeners();
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    }
  }

  Future<String?> startSellingAndReload() async {
    final message = await startSelling();
    if (message == null) await refresh();
    return message;
  }
}

/// The supplier's bids by where they stand.
enum BidsTab {
  submitted('Submitted'),
  shortlisted('Shortlisted'),
  awarded('Won'),
  archived('Archived');

  const BidsTab(this.label);
  final String label;
}

/// "My bids": what the supplier sent, by where it stands (the website's
/// pipeline tabs), and the invitations they declined among the archived.
class MyBidsController extends ChangeNotifier with _SupplierAccess {
  MyBidsController(this.repository);

  @override
  final RfqRepository repository;

  List<MyBid> _bids = const [];
  List<Requirement> _declined = const [];
  BidsTab _tab = BidsTab.submitted;
  bool _loading = false;
  String? _error;
  int _unread = 0;
  bool _started = false;

  BidsTab get tab => _tab;
  bool get loading => _loading;
  String? get error => _error;
  int get unread => _unread;
  bool get started => _started;
  List<Requirement> get declinedInvites => _declined;

  bool _ended(MyBid b) => b.requirement?.status == RfqStatus.closed || b.requirement?.status == RfqStatus.cancelled;

  List<MyBid> bidsIn(BidsTab tab) => switch (tab) {
    BidsTab.submitted => [
      for (final b in _bids)
        if (b.status == BidStatus.pending && !_ended(b)) b,
    ],
    BidsTab.shortlisted => [
      for (final b in _bids)
        if (b.status == BidStatus.shortlisted && !_ended(b)) b,
    ],
    BidsTab.awarded => [
      for (final b in _bids)
        if (b.isAwarded) b,
    ],
    BidsTab.archived => [
      for (final b in _bids)
        if (!b.isAwarded && (b.status == BidStatus.rejected || _ended(b))) b,
    ],
  };

  int count(BidsTab tab) => bidsIn(tab).length + (tab == BidsTab.archived ? _declined.length : 0);

  Future<void> start() async {
    _started = true;
    await _load(notify: false);
  }

  Future<void> refresh() => _load(notify: true);

  Future<void> _load({required bool notify}) async {
    _loading = true;
    _error = null;
    if (notify) notifyListeners();
    try {
      await readAccess();
      if (gate == null) {
        final results = await Future.wait<Object?>([
          repository.myBids(),
          repository.invited().catchError((Object _) => const <Requirement>[]),
          repository.unreadNotifications().then<Object?>((n) => n, onError: (Object _) => 0),
        ]);
        _bids = results[0] as List<MyBid>;
        _declined = [
          for (final r in results[1] as List<Requirement>)
            if (r.inviteStatus == InviteStatus.declined) r,
        ];
        _unread = results[2] as int;
      }
    } catch (e) {
      _error = ApiError.from(e).message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void setTab(BidsTab tab) {
    if (tab == _tab) return;
    _tab = tab;
    notifyListeners();
  }

  /// The thread with the buyer of a requirement the supplier bid on: how a
  /// quote is changed or withdrawn, as the API has no call for either.
  Future<({String? id, String? error})> messageBuyer(String rfqId) async {
    try {
      return (id: await repository.openConversation(rfqId), error: null);
    } catch (e) {
      return (id: null, error: ApiError.from(e).message);
    }
  }

  Future<String?> startSellingAndReload() async {
    final message = await startSelling();
    if (message == null) await refresh();
    return message;
  }
}

/// "Alerts": notifications about requirements, newest first, with read state.
class RfqAlertsController extends ChangeNotifier {
  RfqAlertsController(this.repository);

  final RfqRepository repository;

  List<RfqAlert> _alerts = const [];
  bool _unreadOnly = false;
  bool _loading = false;
  String? _error;
  bool _started = false;
  int _unread = 0;

  List<RfqAlert> get alerts => _unreadOnly
      ? [
          for (final a in _alerts)
            if (a.unread) a,
        ]
      : _alerts;
  bool get unreadOnly => _unreadOnly;
  bool get loading => _loading;
  String? get error => _error;
  bool get started => _started;
  int get newCount => _alerts.where((a) => a.unread).length;
  int get unread => _unread;

  Future<void> start() async {
    _started = true;
    await _load(notify: false);
  }

  Future<void> refresh() => _load(notify: true);

  Future<void> _load({required bool notify}) async {
    _loading = true;
    _error = null;
    if (notify) notifyListeners();
    try {
      final results = await Future.wait<Object?>([
        repository.alerts(),
        repository.unreadNotifications().then<Object?>((n) => n, onError: (Object _) => 0),
      ]);
      _alerts = results[0] as List<RfqAlert>;
      _unread = results[1] as int;
    } catch (e) {
      _error = ApiError.from(e).message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void setUnreadOnly(bool value) {
    if (value == _unreadOnly) return;
    _unreadOnly = value;
    notifyListeners();
  }

  /// Marks one read: at once, and back to unread if the API refuses.
  Future<String?> markRead(RfqAlert alert) async {
    if (!alert.unread) return null;
    _swap(alert.id, (a) => a.read());
    try {
      await repository.markAlertRead(alert.id);
      return null;
    } catch (e) {
      _swap(alert.id, (_) => alert);
      return ApiError.from(e).message;
    }
  }

  /// Marks every unread alert read; those the API refuses stay unread.
  Future<String?> markAllRead() async {
    final unread = [
      for (final a in _alerts)
        if (a.unread) a,
    ];
    if (unread.isEmpty) return null;
    for (final a in unread) {
      _swap(a.id, (x) => x.read(), notify: false);
    }
    notifyListeners();
    String? message;
    for (final a in unread) {
      try {
        await repository.markAlertRead(a.id);
      } catch (e) {
        _swap(a.id, (_) => a, notify: false);
        message ??= ApiError.from(e).message;
      }
    }
    notifyListeners();
    return message;
  }

  void _swap(String id, RfqAlert Function(RfqAlert) change, {bool notify = true}) {
    _alerts = [for (final a in _alerts) a.id == id ? change(a) : a];
    if (notify) notifyListeners();
  }
}
