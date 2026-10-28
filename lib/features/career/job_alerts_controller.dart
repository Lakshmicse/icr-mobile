import '../../core/api/api_error.dart';
import 'career_base.dart';
import 'career_models.dart';
import 'job_alert_models.dart';

/// "Job alerts": the member's saved searches, each with its new matches, and the
/// ways to change one: switch it on or off, how often it speaks, edit it, delete it,
/// and open it to see what matches (which counts the "new" badge as seen).
class JobAlertsController extends CareerController {
  JobAlertsController(super.repository, {super.clock, this.onSeen});

  /// Told when the board's "N new" may have changed (matches seen, an alert added or removed).
  final void Function()? onSeen;

  List<JobAlert> _alerts = const [];
  bool _loading = false;
  bool _loaded = false;
  String? _error;
  String? _openId;
  final Map<String, AlertMatches> _matches = {};

  List<JobAlert> get alerts => _alerts;
  bool get loading => _loading;
  bool get loaded => _loaded;
  String? get error => _error;

  /// The alert whose matches are open.
  String? get openId => _openId;

  AlertMatches matchesOf(String id) => _matches[id] ?? const AlertMatches();

  /// New matches across every alert: the board's "N new" on Alerts.
  int get totalNew => _alerts.fold(0, (n, a) => n + a.newMatches);

  Future<void> start() async {
    await Future.wait([_load(), loadUnread()]);
  }

  Future<void> refresh() async {
    _matches.clear();
    _openId = null;
    await Future.wait([_load(), loadUnread()]);
  }

  Future<void> _load() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _alerts = await repository.alerts();
      _loaded = true;
    } catch (e) {
      _error = ApiError.from(e).message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Saves a new search; null when saved, else the API's sentence (the plan's limit, a name already taken).
  Future<String?> create(AlertDraft draft) async {
    final problem = draft.problem;
    if (problem != null) return problem;
    try {
      final made = await repository.createAlert(
        name: draft.name,
        criteria: draft.criteria.toMap(),
        alertsEnabled: draft.alertsEnabled,
        frequency: draft.frequency,
      );
      _alerts = [made, ..._alerts];
      notifyListeners();
      onSeen?.call();
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    }
  }

  /// Saves the changes to [alert]; null when saved, else the API's sentence.
  Future<String?> edit(JobAlert alert, AlertDraft draft) async {
    final problem = draft.problem;
    if (problem != null) return problem;
    try {
      final saved = await repository.updateAlert(
        alert.id,
        name: draft.name,
        criteria: draft.criteria.toMap(),
        alertsEnabled: draft.alertsEnabled,
        frequency: draft.frequency,
      );
      _replace(saved);
      // Different filters, different matches.
      _matches.remove(alert.id);
      if (_openId == alert.id) {
        _openId = null;
      }
      notifyListeners();
      onSeen?.call();
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    }
  }

  /// The switch: tell me (or stop telling me) when new jobs match. Applied at once, put back if refused.
  Future<String?> setEnabled(JobAlert alert, bool on) =>
      _change(alert, alert.copyWith(alertsEnabled: on), (id) => repository.updateAlert(id, alertsEnabled: on));

  /// DAILY or WEEKLY.
  Future<String?> setFrequency(JobAlert alert, String frequency) =>
      _change(alert, alert.copyWith(frequency: frequency), (id) => repository.updateAlert(id, frequency: frequency));

  Future<String?> _change(JobAlert before, JobAlert optimistic, Future<JobAlert> Function(String id) send) async {
    _replace(optimistic);
    notifyListeners();
    try {
      final saved = await send(before.id);
      // The API does not repeat the "new" count in a write's answer.
      _replace(saved.copyWith(newMatches: before.newMatches));
      notifyListeners();
      return null;
    } catch (e) {
      _replace(before);
      notifyListeners();
      return ApiError.from(e).message;
    }
  }

  /// Deletes the search; null when gone, else the API's sentence.
  Future<String?> delete(JobAlert alert) async {
    try {
      await repository.deleteAlert(alert.id);
      _alerts = _alerts.where((a) => a.id != alert.id).toList();
      _matches.remove(alert.id);
      if (_openId == alert.id) _openId = null;
      notifyListeners();
      onSeen?.call();
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    }
  }

  /// Opens (or closes) an alert's matches. Opening runs the search, which counts its new matches as seen.
  Future<void> toggleMatches(JobAlert alert) async {
    if (_openId == alert.id) {
      _openId = null;
      notifyListeners();
      return;
    }
    _openId = alert.id;
    _matches[alert.id] = const AlertMatches(loading: true);
    notifyListeners();
    try {
      final page = await repository.runAlert(alert.id);
      _matches[alert.id] = AlertMatches(jobs: page.jobs, hasMore: page.hasMore, page: 1);
      _replace(alert.copyWith(newMatches: 0));
      onSeen?.call();
    } catch (e) {
      _matches[alert.id] = AlertMatches(error: ApiError.from(e).message);
    }
    notifyListeners();
  }

  Future<void> loadMoreMatches(JobAlert alert) async {
    final now = matchesOf(alert.id);
    if (now.loadingMore || !now.hasMore) return;
    _matches[alert.id] = now.copyWith(loadingMore: true);
    notifyListeners();
    try {
      final page = await repository.runAlert(alert.id, page: now.page + 1);
      final seen = {for (final j in now.jobs) j.id};
      _matches[alert.id] = AlertMatches(
        jobs: [...now.jobs, ...page.jobs.where((j) => !seen.contains(j.id))],
        hasMore: page.hasMore,
        page: now.page + 1,
      );
    } catch (_) {
      _matches[alert.id] = now.copyWith(loadingMore: false);
    }
    notifyListeners();
  }

  /// Bookmarks (or un-bookmarks) a job in an open alert's matches: applied at once, rolled back if refused.
  Future<String?> toggleSave(String alertId, Job job) async {
    final saved = !job.saved;
    _swapJob(alertId, job.id, (j) => j.copyWith(saved: saved));
    try {
      await repository.jobs.setSaved(job, saved);
      return null;
    } catch (e) {
      _swapJob(alertId, job.id, (j) => j.copyWith(saved: !saved));
      return ApiError.from(e).message;
    }
  }

  /// The job sheet changed a job in a list of matches.
  void jobChanged(String alertId, Job job) => _swapJob(alertId, job.id, (_) => job);

  void _swapJob(String alertId, String jobId, Job Function(Job) change) {
    final now = matchesOf(alertId);
    _matches[alertId] = now.copyWith(jobs: [for (final j in now.jobs) j.id == jobId ? change(j) : j]);
    notifyListeners();
  }

  void _replace(JobAlert alert) {
    _alerts = [for (final a in _alerts) a.id == alert.id ? alert : a];
  }
}
