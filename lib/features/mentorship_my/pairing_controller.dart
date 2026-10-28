import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import 'mentoring_clock.dart';
import 'mentoring_models.dart';
import 'mentoring_repository.dart';

/// One pairing's page: the pairing, its sessions, goals, tasks, timeline,
/// shared resources, the plan behind it and the viewer's feedback, and every
/// action on them. An action answers the API's refusal as a sentence, or null
/// when it went through, and reloads what it changed.
class PairingController extends ChangeNotifier {
  PairingController(this.repository, this.mentorshipId);

  final MentoringRepository repository;
  final String mentorshipId;

  Pairing? _pairing;
  List<PairingSession> _sessions = const [];
  List<PairingGoal> _goals = const [];
  List<PairingTask> _tasks = const [];
  List<TimelineEntry> _timeline = const [];
  List<SharedResource> _resources = const [];
  PairingFeedback? _feedback;
  PlanTerm? _term;
  bool _termIsMine = false;
  MentoringCertificate? _certificate;
  bool _loading = false;
  bool _started = false;
  String? _error;
  bool _busy = false;
  bool _disposed = false;

  Pairing? get pairing => _pairing;
  List<PairingSession> get sessions => _sessions;
  List<PairingGoal> get goals => _goals;
  List<PairingTask> get tasks => _tasks;
  List<TimelineEntry> get timeline => _timeline;
  List<SharedResource> get resources => _resources;
  PairingFeedback? get feedback => _feedback;

  /// The programme or plan term that paid for this pairing, if any.
  PlanTerm? get term => _term;

  /// The caller bought [term] (only the buyer may stop it renewing).
  bool get termIsMine => _termIsMine;

  /// The certificate this mentorship earned, once it is complete.
  MentoringCertificate? get certificate => _certificate;
  bool get loading => _loading;
  bool get started => _started;
  String? get error => _error;
  bool get busy => _busy;

  bool get isMentor => _pairing?.viewerIsMentor ?? false;
  bool get live => _pairing?.status.live ?? false;
  bool get active => _pairing?.status == PairingStatus.active;

  /// Programme steps nobody has booked yet, in order: what a programme's booking form offers.
  List<PlanStep> get openSteps => [
    for (final s in _term?.steps ?? const <PlanStep>[])
      if (!s.booked && !s.done) s,
  ];

  /// The programme is running a syllabus: a session is booked against one of its steps.
  bool get isProgramme => (_term?.programme ?? false) && (_term?.open ?? false) && (_term?.steps.isNotEmpty ?? false);

  /// The session the page leads with: the oldest that slipped, then an unanswered ask, then the next one.
  PairingSession? featured([DateTime? now]) {
    final at = now ?? mentoringNow();
    PairingSession? best;
    int? bestRank;
    for (final s in _sessions) {
      final rank = _rank(s, at);
      if (rank == null) continue;
      if (best == null || rank < bestRank! || (rank == bestRank && s.scheduledAt.isBefore(best.scheduledAt))) {
        best = s;
        bestRank = rank;
      }
    }
    return best;
  }

  /// 0 overdue, 1 an unanswered ask, 2 upcoming; null for history.
  static int? _rank(PairingSession s, DateTime now) {
    if (s.status == SessionStatus.scheduled && s.scheduledAt.isBefore(now)) return 0;
    if (s.status == SessionStatus.requested) return 1;
    if (s.status == SessionStatus.scheduled) return 2;
    return null;
  }

  /// A booked hour that has gone by and nobody closed.
  bool overdue(PairingSession s, [DateTime? now]) => _rank(s, now ?? mentoringNow()) == 0;

  /// Live sessions: overdue first, then asks, then upcoming by date.
  List<PairingSession> upcoming([DateTime? now]) {
    final at = now ?? mentoringNow();
    final rows = [
      for (final s in _sessions)
        if (_rank(s, at) != null) s,
    ];
    rows.sort((a, b) {
      final ra = _rank(a, at)!;
      final rb = _rank(b, at)!;
      return ra != rb ? ra - rb : a.scheduledAt.compareTo(b.scheduledAt);
    });
    return rows;
  }

  /// Everything else (held, cancelled, no-show), newest first.
  List<PairingSession> past([DateTime? now]) {
    final at = now ?? mentoringNow();
    final rows = [
      for (final s in _sessions)
        if (_rank(s, at) == null) s,
    ];
    rows.sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
    return rows;
  }

  /// The mentor confirms a session once it has happened.
  bool canComplete(PairingSession s, [DateTime? now]) =>
      isMentor && s.status == SessionStatus.scheduled && !s.scheduledAt.isAfter(now ?? mentoringNow());

  Future<void> load() async {
    _started = true;
    _loading = true;
    _error = null;
    _notify();
    try {
      final pairing = await repository.pairing(mentorshipId);
      final results = await Future.wait([
        repository.sessions(mentorshipId),
        repository.goals(mentorshipId),
        repository.tasks(mentorshipId),
        if (pairing.status == PairingStatus.completed)
          _quiet<PairingFeedback?>(() => repository.myFeedback(mentorshipId)),
      ]);
      _pairing = pairing;
      _sessions = results[0] as List<PairingSession>;
      _goals = results[1] as List<PairingGoal>;
      _tasks = results[2] as List<PairingTask>;
      _feedback = results.length > 3 ? results[3] as PairingFeedback? : null;
    } catch (e) {
      _error = ApiError.from(e).message;
    }
    _loading = false;
    _notify();
    if (_pairing != null) await _loadExtras();
  }

  /// What sits beside the core page. None of it may fail the page, so each read is quiet.
  Future<void> _loadExtras() async {
    final pairing = _pairing!;
    final results = await Future.wait<Object?>([
      _quiet<List<TimelineEntry>>(() => repository.timeline(mentorshipId)),
      _quiet<List<SharedResource>>(() => repository.resources(mentorshipId)),
      _quiet<List<PlanTerm>>(repository.planTerms),
      _quiet<List<PlanTerm>>(repository.soldTerms),
      if (pairing.status == PairingStatus.completed) _quiet<List<MentoringCertificate>>(repository.certificates),
    ]);
    _timeline = (results[0] as List<TimelineEntry>?) ?? _timeline;
    _resources = (results[1] as List<SharedResource>?) ?? _resources;
    final mine = (results[2] as List<PlanTerm>?)?.where((t) => t.mentorshipId == mentorshipId).firstOrNull;
    final sold = (results[3] as List<PlanTerm>?)?.where((t) => t.mentorshipId == mentorshipId).firstOrNull;
    _term = mine ?? sold;
    _termIsMine = mine != null;
    if (results.length > 4) {
      _certificate = (results[4] as List<MentoringCertificate>?)
          ?.where((c) => c.mentorshipId == mentorshipId)
          .firstOrNull;
    }
    _notify();
  }

  /// The thread "Message" opens, through the pairing.
  Future<String?> conversation() async {
    final known = _pairing?.conversationId;
    if (known != null) return known;
    final id = await repository.pairingConversation(mentorshipId);
    if (id != null && _pairing != null) _pairing = _pairing!.copyWith(conversationId: id);
    return id;
  }

  // --- sessions -----------------------------------------------------------------

  Future<String?> schedule({
    required DateTime at,
    required int durationMin,
    required String mode,
    String? agenda,
    String? planStepId,
  }) => _run(() async {
    await repository.scheduleSession(
      mentorshipId,
      at: at,
      durationMin: durationMin,
      mode: mode,
      agenda: agenda,
      planStepId: planStepId,
    );
    await _reloadSessions();
    await _reloadTerm();
  });

  /// Moves a booked session (either person), or answers a request with another time (the mentor).
  Future<String?> reschedule(
    PairingSession s, {
    required DateTime at,
    required int durationMin,
    required String mode,
    String? agenda,
  }) => _run(() async {
    await repository.rescheduleSession(
      mentorshipId,
      s.id,
      at: at,
      durationMin: durationMin,
      mode: mode,
      agenda: agenda ?? s.agenda,
    );
    await _reloadSessions();
  });

  Future<String?> approve(PairingSession s) => _run(() async {
    await repository.approveSession(mentorshipId, s.id);
    await _reloadSessions();
  });

  Future<String?> cancel(PairingSession s, String reason) => _run(() async {
    await repository.cancelSession(mentorshipId, s.id, reason);
    await _reloadSessions();
    await _reloadTerm();
  });

  /// The mentor marks a session held, with the minutes it actually ran: what CPD and the counters claim.
  Future<String?> complete(PairingSession s, {int? durationMin, String? note}) => _run(() async {
    await repository.completeSession(mentorshipId, s.id, durationMin: durationMin, note: note);
    _pairing = await repository.pairing(mentorshipId);
    await _reloadSessions();
  });

  Future<String?> setMeetingLink(PairingSession s, String? link) => _run(() async {
    await repository.setSessionLink(mentorshipId, s.id, link);
    await _reloadSessions();
  });

  Future<String?> saveRecord(PairingSession s, {String? notes, String? recordingUrl}) => _run(() async {
    await repository.saveSessionRecord(mentorshipId, s.id, notes: notes, recordingUrl: recordingUrl);
    await _reloadSessions();
  });

  /// Asks for a summary of the notes. Throws the API's refusal as an [ApiError].
  Future<SessionRecord> summarise(PairingSession s) async {
    final record = await repository.summariseSession(mentorshipId, s.id);
    await _reloadSessions();
    return record;
  }

  Future<void> _reloadSessions() async {
    _sessions = await repository.sessions(mentorshipId);
    _notify();
  }

  /// A booked or cancelled session moves the plan's allowance and its steps.
  Future<void> _reloadTerm() async {
    if (_term == null) return;
    final terms = await _quiet<List<PlanTerm>>(_termIsMine ? repository.planTerms : repository.soldTerms);
    _term = terms?.where((t) => t.mentorshipId == mentorshipId).firstOrNull ?? _term;
  }

  // --- goals and tasks ----------------------------------------------------------

  Future<String?> addGoal({required String title, String? detail, DateTime? targetDate}) => _run(() async {
    await repository.addGoal(mentorshipId, title: title, detail: detail, targetDate: targetDate);
    _goals = await repository.goals(mentorshipId);
  });

  Future<String?> setGoalStatus(PairingGoal g, GoalStatus status) => _run(() async {
    await repository.setGoalStatus(mentorshipId, g.id, status);
    _goals = await repository.goals(mentorshipId);
  });

  Future<String?> setGoalProgress(PairingGoal g, int progress) => _run(() async {
    await repository.setGoalProgress(mentorshipId, g.id, progress);
    _goals = await repository.goals(mentorshipId);
  });

  Future<String?> removeGoal(PairingGoal g) => _run(() async {
    await repository.removeGoal(mentorshipId, g.id);
    _goals = await repository.goals(mentorshipId);
  });

  Future<String?> addTask({required String title, DateTime? dueAt}) => _run(() async {
    await repository.addTask(mentorshipId, title: title, dueAt: dueAt);
    _tasks = await repository.tasks(mentorshipId);
  });

  /// Ticks a task done, or opens it again.
  Future<String?> toggleTask(PairingTask t) => _run(() async {
    await repository.setTaskStatus(mentorshipId, t.id, t.status == TaskStatus.done ? TaskStatus.open : TaskStatus.done);
    _tasks = await repository.tasks(mentorshipId);
  });

  Future<String?> deleteTask(PairingTask t) => _run(() async {
    await repository.deleteTask(mentorshipId, t.id);
    _tasks = await repository.tasks(mentorshipId);
  });

  // --- notes, resources ---------------------------------------------------------

  Future<String?> addNote(String note, {bool privateToMe = false}) => _run(() async {
    await repository.addNote(mentorshipId, note, privateToMe: privateToMe);
    _timeline = await repository.timeline(mentorshipId);
  });

  Future<String?> addResourceLink({required String title, required String url, String kind = 'OTHER', String? note}) =>
      _run(() async {
        await repository.addResourceLink(mentorshipId, title: title, url: url, kind: kind, note: note);
        _resources = await repository.resources(mentorshipId);
      });

  /// Uploads and shares a file (the form has already checked its type and size).
  Future<String?> addResourceFile({
    required PickedShare file,
    required String title,
    String kind = 'OTHER',
    String? note,
  }) => _run(() async {
    await repository.addResourceFile(
      mentorshipId,
      bytes: file.bytes,
      name: file.name,
      mimeType: file.mimeType,
      title: title,
      kind: kind,
      note: note,
    );
    _resources = await repository.resources(mentorshipId);
  });

  Future<String?> removeResource(SharedResource r) => _run(() async {
    await repository.removeResource(r.id);
    _resources = await repository.resources(mentorshipId);
  });

  /// A shared file's bytes, for the share sheet. Throws the API's refusal as an [ApiError].
  Future<Uint8List> download(SharedResource r) => repository.downloadBytes(r.url!);

  // --- the pairing itself -------------------------------------------------------

  /// Pause, resume, complete, or end early with a reason.
  Future<String?> setStatus(PairingStatus status, {String? reason}) => _run(() async {
    _pairing = await repository.updatePairing(mentorshipId, status, endedReason: reason);
    _sessions = await repository.sessions(mentorshipId);
    _timeline = await _quiet<List<TimelineEntry>>(() => repository.timeline(mentorshipId)) ?? _timeline;
    if (status == PairingStatus.completed) {
      _feedback = await _quiet<PairingFeedback?>(() => repository.myFeedback(mentorshipId));
      final certs = await _quiet<List<MentoringCertificate>>(repository.certificates);
      _certificate = certs?.where((c) => c.mentorshipId == mentorshipId).firstOrNull;
    }
  });

  /// The buyer stops the ongoing plan renewing.
  Future<String?> stopRenewing() => _run(() async {
    await repository.cancelPlanTerm(_term!.id);
    await _reloadTerm();
  });

  Future<String?> setCadence(String cadence) => _run(() async {
    await repository.setCadence(mentorshipId, cadence);
    _pairing = await repository.pairing(mentorshipId);
  });

  Future<String?> sendFeedback({required int rating, String? comment, bool? wouldRecommend}) => _run(() async {
    await repository.submitFeedback(mentorshipId, rating: rating, comment: comment, wouldRecommend: wouldRecommend);
    _feedback = await repository.myFeedback(mentorshipId);
  });

  Future<String?> raiseConcern({required ConcernCategory category, required String detail, bool urgent = false}) =>
      _run(() => repository.raiseConcern(mentorshipId, category: category, detail: detail, urgent: urgent));

  Future<String?> askSupport({required String subject, required String body}) =>
      _run(() => repository.raiseSupportTicket(subject: subject, body: body, contextId: mentorshipId));

  Future<String?> _run(Future<void> Function() action) async {
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
