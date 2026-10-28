import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import 'career_models.dart';
import 'career_repository.dart';

/// The tabs of a company's insights screen: what people say about working
/// there, what it pays, how its interviews go, who works there, its open jobs.
enum InsightsTab {
  jobs('Jobs'),
  people('People'),
  reviews('Reviews'),
  salaries('Salaries'),
  interviews('Interviews');

  const InsightsTab(this.label);
  final String label;
}

/// One tab's rows: loaded on first show, paged with "View More", reloaded by a pull.
class InsightList<T> {
  List<T> items = const [];
  bool loaded = false;
  bool loading = false;
  bool loadingMore = false;
  bool hasMore = false;
  int page = 0;
  int? total;
  String? error;
  Map<String, double> averages = const {};
}

/// A company's reviews, salaries, interviews, people and jobs, read tab by tab,
/// and the three forms that add to them.
class CompanyInsightsController extends ChangeNotifier {
  CompanyInsightsController({
    required this.repository,
    required JobCompany company,
    InsightsTab tab = InsightsTab.reviews,
  }) : _company = company,
       _tab = tab;

  final CareerRepository repository;
  JobCompany _company;

  /// The company: what the opener knew of it, filled in from `GET /companies/:id`.
  JobCompany get company => _company;

  InsightsTab _tab;
  RatingSummary? _summary;
  String? _summaryError;
  EmployerReview? _mine;
  SalaryInsights? _salaries;
  bool _disposed = false;
  int _unread = 0;

  final reviews = InsightList<EmployerReview>();
  final interviews = InsightList<InterviewReview>();
  final people = InsightList<CompanyPerson>();
  final jobs = InsightList<Job>();
  final salaryState = InsightList<SalaryRole>();

  InsightsTab get tab => _tab;

  /// Unread notifications, for the bell.
  int get unread => _unread;
  RatingSummary? get summary => _summary;
  String? get summaryError => _summaryError;

  /// The member's own review, in whatever state moderation has it.
  EmployerReview? get mine => _mine;
  SalaryInsights? get salaries => _salaries;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Reads the rating summary and the member's own review, and the open tab.
  Future<void> start() async {
    await Future.wait([_loadCompany(), _loadSummary(), _loadMine(), _ensure(_tab), _loadUnread()]);
  }

  Future<void> _loadCompany() async {
    try {
      final more = await repository.company(_company.id);
      if (more != null) _company = _company.name.isEmpty ? more : _company.merge(more);
    } catch (_) {
      // The header keeps what the opener knew.
    }
    notifyListeners();
  }

  Future<void> _loadUnread() async {
    try {
      _unread = await repository.unreadNotifications();
      notifyListeners();
    } catch (_) {
      // The bell shows no dot.
    }
  }

  Future<void> select(InsightsTab tab) async {
    if (tab == _tab) return;
    _tab = tab;
    notifyListeners();
    await _ensure(tab);
  }

  /// Pull to refresh: the summary, and the open tab from its first page.
  Future<void> refresh() async {
    await Future.wait([_loadSummary(), _loadMine(), _fill(_tab, refresh: true)]);
  }

  /// "View More" on the open tab.
  Future<void> loadMore([InsightsTab? tab]) => _fill(tab ?? _tab, more: true);

  Future<void> retry([InsightsTab? tab]) => _fill(tab ?? _tab, refresh: true);

  Future<void> _ensure(InsightsTab tab) async {
    final list = _list(tab);
    if (list.loaded || list.loading) return;
    await _fill(tab);
  }

  InsightList<Object?> _list(InsightsTab tab) => switch (tab) {
    InsightsTab.reviews => reviews,
    InsightsTab.salaries => salaryState,
    InsightsTab.interviews => interviews,
    InsightsTab.people => people,
    InsightsTab.jobs => jobs,
  };

  Future<void> _loadSummary() async {
    try {
      _summary = await repository.ratingSummary(company.id);
      _summaryError = null;
    } catch (e) {
      _summaryError = ApiError.from(e).message;
    }
    notifyListeners();
  }

  Future<void> _loadMine() async {
    try {
      _mine = await repository.myReview(company.id);
    } catch (_) {
      // Signed out, or no review of theirs: the button just says "Write a review".
    }
    notifyListeners();
  }

  Future<void> _fill(InsightsTab tab, {bool refresh = false, bool more = false}) {
    final id = company.id;
    return switch (tab) {
      InsightsTab.reviews => _page(
        reviews,
        (p) => repository.reviews(id, page: p),
        refresh: refresh,
        more: more,
      ),
      InsightsTab.interviews => _page(
        interviews,
        (p) => repository.interviewReviews(id, page: p),
        refresh: refresh,
        more: more,
      ),
      InsightsTab.people => _page(
        people,
        (p) => repository.people(id, page: p),
        refresh: refresh,
        more: more,
      ),
      InsightsTab.jobs => _page(
        jobs,
        (p) async {
          final page = await repository.companyJobs(id, page: p);
          return InsightPage(items: page.jobs, hasMore: page.hasMore);
        },
        refresh: refresh,
        more: more,
      ),
      InsightsTab.salaries => _salariesFill(refresh: refresh),
    };
  }

  Future<void> _salariesFill({required bool refresh}) async {
    final list = salaryState;
    if (list.loading) return;
    list.loading = true;
    list.error = null;
    notifyListeners();
    try {
      _salaries = await repository.salaries(company.id);
      list.items = _salaries!.roles;
      list.loaded = true;
    } catch (e) {
      list.error = ApiError.from(e).message;
    } finally {
      list.loading = false;
      notifyListeners();
    }
  }

  Future<void> _page<T>(
    InsightList<T> list,
    Future<InsightPage<T>> Function(int page) fetch, {
    required bool refresh,
    required bool more,
  }) async {
    if (list.loading || list.loadingMore) return;
    if (more && !list.hasMore) return;
    if (more) {
      list.loadingMore = true;
    } else {
      list.loading = true;
      list.error = null;
    }
    notifyListeners();
    try {
      final page = await fetch(more ? list.page + 1 : 1);
      if (more) {
        final seen = {for (final i in list.items) _key(i)};
        list.items = [...list.items, ...page.items.where((i) => !seen.contains(_key(i)))];
      } else {
        list.items = page.items;
      }
      list.page = more ? list.page + 1 : 1;
      list.hasMore = page.hasMore;
      list.total = page.total;
      list.averages = page.averages;
      list.loaded = true;
    } catch (e) {
      // A failed "View More" keeps what is on show; the button tries again.
      if (!more) list.error = ApiError.from(e).message;
    } finally {
      list.loading = false;
      list.loadingMore = false;
      notifyListeners();
    }
  }

  static Object _key(Object? item) => switch (item) {
    EmployerReview r => r.id,
    InterviewReview r => r.id,
    CompanyPerson p => p.id,
    Job j => j.id,
    _ => item ?? '',
  };

  // --- what the member adds ----------------------------------------------------

  /// Sends the review (replacing the member's earlier one); null when sent,
  /// else the sentence the form shows. The review enters moderation, so it is
  /// not in the list yet: [mine] reads PENDING.
  Future<String?> submitReview(ReviewDraft draft) async {
    final problem = draft.problem;
    if (problem != null) return problem;
    try {
      await repository.submitReview(company.id, draft);
    } catch (e) {
      return ApiError.from(e).message;
    }
    await Future.wait([_loadMine(), _loadSummary()]);
    return null;
  }

  /// Sends a salary report; it counts once the company has enough of them.
  Future<String?> submitSalary(SalaryDraft draft) async {
    final problem = draft.problem;
    if (problem != null) return problem;
    try {
      await repository.submitSalary(company.id, draft);
    } catch (e) {
      return ApiError.from(e).message;
    }
    if (salaryState.loaded) await _salariesFill(refresh: true);
    return null;
  }

  Future<String?> submitInterview(InterviewReviewDraft draft) async {
    final problem = draft.problem;
    if (problem != null) return problem;
    try {
      await repository.submitInterviewReview(company.id, draft);
    } catch (e) {
      return ApiError.from(e).message;
    }
    return null;
  }

  // --- the jobs tab -----------------------------------------------------------

  /// Bookmarks (or un-bookmarks) a job of the company's: applied at once,
  /// rolled back with the API's sentence when refused.
  Future<String?> toggleSave(Job job) async {
    final saved = !job.saved;
    _swap(job.id, (j) => j.copyWith(saved: saved));
    try {
      await repository.jobs.setSaved(job, saved);
      return null;
    } catch (e) {
      _swap(job.id, (j) => j.copyWith(saved: !saved));
      return ApiError.from(e).message;
    }
  }

  /// The job sheet changed a job (saved it, applied): keep the row in step.
  void jobChanged(Job job) => _swap(job.id, (_) => job);

  void _swap(String id, Job Function(Job) change) {
    jobs.items = [for (final j in jobs.items) j.id == id ? change(j) : j];
    notifyListeners();
  }
}
