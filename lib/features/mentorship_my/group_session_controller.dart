import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import 'loader.dart';
import 'mentoring_models.dart';
import 'mentoring_repository.dart';

/// One group session as a member sees it: the session, their own rating once
/// it is held, and the actions on it (take a free seat, give it up, buy a seat,
/// rate it, report a concern). An action answers the API's refusal as a
/// sentence, or null when it went through, and reads the session again.
class GroupSessionController extends ChangeNotifier {
  GroupSessionController(this.repository, this.id);

  final MentoringRepository repository;
  final String id;

  GroupSession? _session;
  GroupFeedback? _feedback;
  MemberDiscounts? _discounts;
  bool _loading = false;
  bool _busy = false;
  String? _error;
  bool _disposed = false;

  GroupSession? get session => _session;
  GroupFeedback? get feedback => _feedback;
  MemberDiscounts? get discounts => _discounts;
  bool get loading => _loading;
  bool get busy => _busy;
  String? get error => _error;

  /// The price of a seat after the member's plan (list price when the plan holds no discount).
  PriceQuote? get seatQuote {
    final s = _session;
    if (s == null || !s.paid) return null;
    return PriceQuote.service(s.pricePaisa!, _discounts);
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    _notify();
    try {
      final s = await repository.groupSession(id);
      _session = s;
      _discounts = await _quiet<MemberDiscounts>(repository.memberDiscounts);
      _feedback = s.status == 'COMPLETED' && s.myStatus == 'ATTENDED' && !s.paid
          ? await _quiet<GroupFeedback?>(() => repository.myGroupFeedback(id))
          : null;
    } catch (e) {
      _error = ApiError.from(e).message;
    }
    _loading = false;
    _notify();
  }

  /// A free seat (or the waitlist once it fills).
  Future<String?> register({String? question}) => _act(() async {
    await repository.registerGroup(id, question: question);
    _session = await repository.groupSession(id);
  });

  Future<String?> leave() => _act(() async {
    await repository.leaveGroup(id);
    _session = await repository.groupSession(id);
  });

  /// Buys a seat. Throws the API's refusal as an [ApiError] (the sheet shows it in place).
  Future<PaymentOutcome> buySeat({String? question}) async {
    final s = _session!;
    final outcome = await repository.buyGroupSeat(
      s,
      question: question,
      quote: seatQuote ?? PriceQuote.service(0, null),
    );
    if (outcome.completed) {
      _session = await repository.groupSession(id);
      _notify();
    }
    return outcome;
  }

  Future<String?> rate({required int rating, String? comment, bool anonymous = false}) => _act(() async {
    await repository.rateGroupSession(id, rating: rating, comment: comment, anonymous: anonymous);
    _feedback = await repository.myGroupFeedback(id);
  });

  Future<String?> rateSeat({required int rating, String? comment, bool anonymous = false}) => _act(() async {
    final pid = _session?.myPurchaseId;
    if (pid == null) throw ApiError('There is no seat purchase to review.');
    await repository.reviewPurchase(pid, rating: rating, comment: comment, anonymous: anonymous);
    _session = await repository.groupSession(id);
  });

  Future<String?> raiseConcern({required ConcernCategory category, required String detail, bool urgent = false}) =>
      _act(() => repository.raiseGroupConcern(id, category: category, detail: detail, urgent: urgent));

  Future<String?> _act(Future<void> Function() action) async {
    _busy = true;
    _notify();
    try {
      await action();
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    } finally {
      _busy = false;
      _notify();
    }
  }

  static Future<T?> _quiet<T>(Future<T> Function() call) async {
    try {
      return await call();
    } catch (_) {
      return null;
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

/// The browse list of group sessions: open ones (or those the member holds a seat at), filtered, a page at a time.
class GroupSessionsController extends ChangeNotifier {
  GroupSessionsController(this.repository, {this.programId, this.registeredOnly = false});

  final MentoringRepository repository;
  final String? programId;
  bool registeredOnly;
  String? mode;
  bool availableOnly = false;
  String search = '';

  late final Loader<PageOf<GroupSession>> _first = Loader(_fetchFirst, _notify);
  final List<GroupSession> _more = [];
  int _page = 1;
  bool _hasNext = false;
  bool _loadingMore = false;
  String? _moreError;
  bool _disposed = false;

  Loader<PageOf<GroupSession>> get first => _first;
  List<GroupSession> get items => [...?_first.data?.items, ..._more];
  bool get hasNext => _hasNext;
  bool get loadingMore => _loadingMore;
  String? get moreError => _moreError;
  int get total => _first.data?.total ?? 0;

  Future<PageOf<GroupSession>> _fetchFirst() async {
    _more.clear();
    _page = 1;
    final page = await repository.groupSessions(
      mode: mode,
      availableOnly: availableOnly,
      registered: registeredOnly,
      search: search,
      programId: programId,
    );
    _hasNext = page.hasNext;
    return page;
  }

  Future<void> load() => _first.load();

  /// Changes a filter and reads the first page again.
  Future<void> apply({
    String? mode,
    bool? availableOnly,
    bool? registeredOnly,
    String? search,
    bool clearMode = false,
  }) {
    if (clearMode) {
      this.mode = null;
    } else if (mode != null) {
      this.mode = mode;
    }
    if (availableOnly != null) this.availableOnly = availableOnly;
    if (registeredOnly != null) this.registeredOnly = registeredOnly;
    if (search != null) this.search = search;
    return load();
  }

  Future<void> loadMore() async {
    if (!_hasNext || _loadingMore) return;
    _loadingMore = true;
    _moreError = null;
    _notify();
    try {
      final page = await repository.groupSessions(
        page: _page + 1,
        mode: mode,
        availableOnly: availableOnly,
        registered: registeredOnly,
        search: search,
        programId: programId,
      );
      _page += 1;
      _more.addAll(page.items);
      _hasNext = page.hasNext;
    } catch (e) {
      _moreError = ApiError.from(e).message;
    }
    _loadingMore = false;
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
