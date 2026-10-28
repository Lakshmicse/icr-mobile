import '../../../core/api/api_error.dart';
import 'hiring_models.dart';
import 'post_job_controller.dart';

/// Where an application may be moved from each stage (`ALLOWED_APPLICATION_TRANSITIONS`).
const stageMoves = <String, List<String>>{
  'APPLIED': ['SCREENING', 'INTERVIEW', 'REJECTED'],
  'SCREENING': ['INTERVIEW', 'REJECTED'],
  'INTERVIEW': ['OFFER', 'REJECTED'],
  'OFFER': ['HIRED', 'REJECTED'],
  'HIRED': [],
  'REJECTED': ['SCREENING', 'INTERVIEW'],
  'WITHDRAWN': [],
};

/// The stage as the hiring team words it.
String stageWord(String stage) => switch (stage) {
  'APPLIED' => 'Applied',
  'SCREENING' => 'In review',
  'INTERVIEW' => 'Interview',
  'OFFER' => 'Offer',
  'HIRED' => 'Hired',
  'REJECTED' => 'Not selected',
  'WITHDRAWN' => 'Withdrawn',
  _ => stage,
};

/// The verb on the button that moves an application to [stage].
String moveVerb(String stage) => switch (stage) {
  'SCREENING' => 'Move to review',
  'INTERVIEW' => 'Move to interview',
  'OFFER' => 'Move to offer',
  'HIRED' => 'Mark as hired',
  'REJECTED' => 'Reject',
  _ => 'Move to ${stageWord(stage).toLowerCase()}',
};

/// The stages the pipeline shows, in order.
const pipelineStages = ['APPLIED', 'SCREENING', 'INTERVIEW', 'OFFER', 'HIRED', 'REJECTED'];

/// How the applicants are ordered (`GET /jobs/:id/applications?sort=`).
enum ApplicantSort {
  recent('recent', 'Most recent'),
  match('match', 'Best match'),
  qualifications('qualifications', 'Most qualified');

  const ApplicantSort(this.api, this.label);
  final String api;
  final String label;
}

/// A job's pipeline: its applicants by stage, with sort and filters, and the moves a recruiter makes
/// from the list (move, reject, rate). Applied at once and rolled back with the API's sentence if refused.
class ApplicantsController extends HiringController {
  ApplicantsController(super.repository, {required this.jobId, this.jobTitle, super.clock, String? stage})
    : _stage = stage;

  final String jobId;
  String? jobTitle;

  List<Applicant> _applicants = const [];
  Map<String, int> _counts = const {};
  String? _stage;
  ApplicantSort _sort = ApplicantSort.recent;
  int? _minRating;
  bool _qualifiedOnly = false;
  bool _loading = false;
  bool _loaded = false;
  String? _error;
  final Set<String> _busy = {};

  List<Applicant> get applicants => _applicants;
  Map<String, int> get counts => _counts;

  /// The stage on show; null is every stage.
  String? get stage => _stage;
  ApplicantSort get sort => _sort;
  int? get minRating => _minRating;
  bool get qualifiedOnly => _qualifiedOnly;
  bool get loading => _loading;
  bool get loaded => _loaded;
  String? get error => _error;

  bool busy(String id) => _busy.contains(id);

  int get total => _counts.entries.where((e) => e.key != 'WITHDRAWN').fold(0, (n, e) => n + e.value);
  int count(String? stage) => stage == null ? total : (_counts[stage] ?? 0);

  /// Applicants nobody on the team has opened.
  int get unviewed => _applicants.where((a) => !a.viewed && a.stage == 'APPLIED').length;

  Future<void> start() async {
    await Future.wait([_load(), loadUnread()]);
  }

  Future<void> refresh() async {
    await Future.wait([_load(), loadUnread()]);
  }

  Future<void> _load() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final page = await repository.applicants(
        jobId,
        stage: _stage,
        sort: _sort.api,
        minRating: _minRating,
        qualifiedOnly: _qualifiedOnly,
      );
      _applicants = [
        for (final a in page.applicants)
          if (a.stage != 'WITHDRAWN') a,
      ];
      _counts = page.stageCounts.isNotEmpty || _stage == null ? page.stageCounts : _counts;
      _loaded = true;
    } catch (e) {
      _error = ApiError.from(e).message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> selectStage(String? stage) {
    if (stage == _stage) return Future.value();
    _stage = stage;
    return _load();
  }

  Future<void> setSort(ApplicantSort sort) {
    if (sort == _sort) return Future.value();
    _sort = sort;
    return _load();
  }

  Future<void> setMinRating(int? rating) {
    if (rating == _minRating) return Future.value();
    _minRating = rating;
    return _load();
  }

  Future<void> setQualifiedOnly(bool on) {
    if (on == _qualifiedOnly) return Future.value();
    _qualifiedOnly = on;
    return _load();
  }

  void _swap(String id, Applicant Function(Applicant) change) {
    _applicants = [for (final a in _applicants) a.id == id ? change(a) : a];
  }

  void _count(String from, String to) {
    final next = {..._counts};
    next[from] = ((next[from] ?? 1) - 1).clamp(0, 1 << 30);
    next[to] = (next[to] ?? 0) + 1;
    _counts = next;
  }

  /// Moves an application to [to]; the row follows at once (and leaves the list if another stage is on
  /// show), put back with the API's sentence if refused.
  Future<String?> move(Applicant a, String to, {String? note}) async {
    if (_busy.contains(a.id)) return null;
    final from = a.stage;
    _busy.add(a.id);
    _swap(a.id, (x) => x.copyWith(stage: to));
    _count(from, to);
    notifyListeners();
    try {
      await repository.moveStage(a.id, to, note: note);
      if (_stage != null && _stage != to) _applicants = _applicants.where((x) => x.id != a.id).toList();
      return null;
    } catch (e) {
      _swap(a.id, (x) => x.copyWith(stage: from));
      _count(to, from);
      return ApiError.from(e).message;
    } finally {
      _busy.remove(a.id);
      notifyListeners();
    }
  }

  /// Gives the application 1-5 stars; null when saved, else the API's sentence.
  Future<String?> rate(Applicant a, int rating) async {
    final before = a.rating;
    _swap(a.id, (x) => x.copyWith(rating: rating));
    notifyListeners();
    try {
      await repository.addNote(a.id, rating: rating);
      return null;
    } catch (e) {
      _swap(a.id, (x) => x.copyWith(rating: before ?? 0));
      notifyListeners();
      return ApiError.from(e).message;
    }
  }

  /// The detail screen changed an application: keep the pipeline's row in step.
  void changed(Applicant updated) {
    final old = _applicants.where((a) => a.id == updated.id);
    if (old.isNotEmpty && old.first.stage != updated.stage) _count(old.first.stage, updated.stage);
    _swap(updated.id, (_) => updated);
    if (_stage != null && updated.stage != _stage) _applicants = _applicants.where((a) => a.id != updated.id).toList();
    notifyListeners();
  }
}

/// One applicant's page: the whole application and what the hiring team does to it.
class ApplicantDetailController extends HiringController {
  ApplicantDetailController(super.repository, {required Applicant seed, this.onChanged, super.clock}) : _seed = seed;

  final Applicant _seed;

  /// Tells the pipeline a change so its row follows.
  final void Function(Applicant applicant)? onChanged;

  ApplicantDetail? _detail;
  List<TeamMember> _team = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  ApplicantDetail? get detail => _detail;
  Applicant get applicant => _detail?.applicant ?? _seed;
  List<TeamMember> get team => _team;
  bool get loading => _loading;
  bool get busy => _busy;
  String? get error => _error;

  Future<void> start() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _detail = await repository.applicant(_seed.id);
      // Opening an application is how the team's "viewed" receipt is written.
      onChanged?.call(_detail!.applicant);
    } catch (e) {
      _error = ApiError.from(e).message;
    } finally {
      _loading = false;
      notifyListeners();
    }
    await loadUnread();
  }

  Future<void> _reload() async {
    final fresh = await repository.applicant(_seed.id);
    _detail = fresh;
    onChanged?.call(fresh.applicant);
  }

  Future<String?> _run(Future<void> Function() work) async {
    _busy = true;
    notifyListeners();
    try {
      await work();
      await _reload();
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<String?> move(String to, {String? note}) => _run(() => repository.moveStage(_seed.id, to, note: note));

  Future<String?> addNote({String? note, int? rating}) {
    if ((note ?? '').trim().isEmpty && rating == null) return Future.value('Write a note or give a rating.');
    return _run(() => repository.addNote(_seed.id, note: note, rating: rating));
  }

  Future<String?> schedule(InterviewDraft draft) {
    final problem = draft.problem(clock());
    if (problem != null) return Future.value(problem);
    return _run(() async {
      await repository.scheduleInterview(_seed.id, draft);
    });
  }

  /// A new time or place for a round.
  Future<String?> reschedule(TeamInterview interview, InterviewDraft draft) {
    final problem = draft.problem(clock());
    if (problem != null) return Future.value(problem);
    return _run(() async {
      await repository.updateInterview(interview.id, draft: draft);
    });
  }

  /// CANCELLED, COMPLETED or NO_SHOW.
  Future<String?> setInterviewStatus(TeamInterview interview, String status) => _run(() async {
    await repository.updateInterview(interview.id, status: status);
  });

  Future<String?> makeOffer(OfferDraft draft, {bool send = true}) {
    final problem = draft.problem(clock());
    if (problem != null) return Future.value(problem);
    return _run(() async {
      await repository.makeOffer(_seed.id, draft, send: send);
    });
  }

  /// Changes a drafted or sent offer.
  Future<String?> editOffer(TeamOffer offer, OfferDraft draft) {
    final problem = draft.problem(clock());
    if (problem != null) return Future.value(problem);
    return _run(() async {
      await repository.updateOffer(offer.id, draft);
    });
  }

  /// Sends a drafted offer; the application moves to Offer.
  Future<String?> sendOffer(TeamOffer offer) => _run(() async {
    await repository.sendOffer(offer.id);
  });

  Future<({String? conversationId, String? error})> message() async {
    try {
      return (conversationId: await repository.messageApplicant(_seed.id), error: null);
    } catch (e) {
      return (conversationId: null, error: ApiError.from(e).message);
    }
  }

  /// The people who can be on a panel, read the first time they are asked for.
  Future<void> loadTeam() async {
    if (_team.isNotEmpty) return;
    try {
      _team = await repository.teamMembers();
      notifyListeners();
    } catch (_) {
      // The sheet offers "me" alone.
    }
  }
}
