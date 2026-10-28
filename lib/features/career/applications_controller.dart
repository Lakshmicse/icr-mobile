import '../../core/api/api_error.dart';
import 'application_logic.dart';
import 'career_base.dart';
import 'career_models.dart';

/// What a message to the hiring team came to: the thread's id, or the sentence the API refused with.
typedef MessageResult = ({String? conversationId, String? error});

/// "My applications": every application of the member, the figures above them,
/// what is waiting on them, and the tabs, search and sort the website's tracker has.
/// The API sends the whole list, so all of them work on it here.
class ApplicationsController extends CareerController {
  ApplicationsController(super.repository, {super.clock, ApplicationsTab? tab}) : _tab = tab;

  List<CareerApplication> _apps = const [];
  ApplicationsTab? _tab;
  String _search = '';
  ApplicationsSort _sort = ApplicationsSort.recent;
  bool _loading = false;
  bool _loaded = false;
  String? _error;
  DateTime? _now;
  SeekerQuota? _quota;

  List<CareerApplication> get apps => _apps;
  bool get loading => _loading;
  bool get loaded => _loaded;
  String? get error => _error;
  String get search => _search;
  ApplicationsSort get sort => _sort;
  SeekerQuota? get quota => _quota;

  /// One clock per visit, so a row does not change tab while it is read.
  DateTime get now => _now ??= clock();

  Map<ApplicationsTab, int> get counts => tabCounts(_apps, now);

  /// The tab on show: the one asked for, else Active (All when nothing is in play).
  ApplicationsTab get tab => _tab ?? defaultTab(counts);

  ApplicationsSummary get summary => summaryOf(_apps, now);
  List<UpNextItem> get upNextItems => upNext(_apps, now);

  /// The plan hides the viewed receipts and the timeline.
  bool get locked => _apps.any((a) => a.visibilityLocked);

  /// The applications on the open tab that match the search, in the chosen order.
  List<CareerApplication> get rows => sortApps([
    for (final a in _apps)
      if (inTab(a, tab, now) && matchesSearch(a, _search)) a,
  ], _sort);

  Future<void> start() async {
    await Future.wait([_load(), loadUnread(), _loadQuota()]);
  }

  Future<void> refresh() async {
    _now = null;
    await Future.wait([_load(), loadUnread(), _loadQuota()]);
  }

  Future<void> _load() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _apps = await repository.applications();
      _loaded = true;
    } catch (e) {
      _error = ApiError.from(e).message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _loadQuota() async {
    try {
      _quota = await repository.quota();
      notifyListeners();
    } catch (_) {
      // The allowance line is left out.
    }
  }

  void selectTab(ApplicationsTab tab) {
    if (tab == _tab) return;
    _tab = tab;
    notifyListeners();
  }

  void setSearch(String query) {
    if (query == _search) return;
    _search = query;
    notifyListeners();
  }

  void setSort(ApplicationsSort sort) {
    if (sort == _sort) return;
    _sort = sort;
    notifyListeners();
  }

  /// Puts a changed application (withdrawn, an offer answered) in the list.
  void replace(CareerApplication app) {
    _apps = [for (final a in _apps) a.id == app.id ? app : a];
    notifyListeners();
  }

  /// Withdraws the application; a sentence when the API refuses.
  Future<String?> withdraw(CareerApplication app) async {
    try {
      replace(await repository.withdraw(app.id));
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    }
  }

  /// Accepts or declines the offer waiting on [app], then reads the application again. An
  /// accepted offer is a hire, which lives under Offers: that tab opens so the row stays in view.
  Future<String?> respondToOffer(CareerApplication app, {required bool accept, String? note}) async {
    final offer = app.latestOffer;
    if (offer == null) return 'There is no offer to answer.';
    try {
      await repository.respondToOffer(offer.id, accept: accept, note: note);
      replace(await repository.application(app.id));
      if (accept) selectTab(ApplicationsTab.offers);
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    }
  }

  /// Opens (or finds) the conversation with the job's hiring contact.
  Future<MessageResult> messageHiringTeam(CareerApplication app, {String? message}) async {
    try {
      final id = await repository.messageHiringTeam(app.jobId, message: message);
      return (conversationId: id, error: null);
    } catch (e) {
      return (conversationId: null, error: ApiError.from(e).message);
    }
  }
}

/// One application on its own page: the whole of it (every round, the answers,
/// the timeline), and what the member can do: answer an offer, withdraw, message the team.
class ApplicationDetailController extends CareerController {
  ApplicationDetailController(super.repository, {required CareerApplication seed, this.onChanged, super.clock})
    : _app = seed;

  /// Tells the list a change (withdrawn, an offer answered) so its row follows.
  final void Function(CareerApplication app)? onChanged;

  CareerApplication _app;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  CareerApplication get app => _app;
  bool get loading => _loading;

  /// A write is on its way: its buttons wait.
  bool get busy => _busy;
  String? get error => _error;

  Future<void> start() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _app = await repository.application(_app.id);
      onChanged?.call(_app);
    } catch (e) {
      // The list's copy is still there to read; only a missing application is an error.
      final err = ApiError.from(e);
      if (err.statusCode == 404 || err.statusCode == 403) _error = err.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
    await loadUnread();
  }

  Future<String?> withdraw() => _run(() async {
    _app = await repository.withdraw(_app.id);
  });

  Future<String?> respondToOffer({required bool accept, String? note}) {
    final offer = _app.latestOffer;
    if (offer == null) return Future.value('There is no offer to answer.');
    return _run(() async {
      await repository.respondToOffer(offer.id, accept: accept, note: note);
      _app = await repository.application(_app.id);
    });
  }

  Future<String?> _run(Future<void> Function() work) async {
    _busy = true;
    notifyListeners();
    try {
      await work();
      onChanged?.call(_app);
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<MessageResult> messageHiringTeam({String? message}) async {
    try {
      final id = await repository.messageHiringTeam(_app.jobId, message: message);
      return (conversationId: id, error: null);
    } catch (e) {
      return (conversationId: null, error: ApiError.from(e).message);
    }
  }
}
