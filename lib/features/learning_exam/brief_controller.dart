import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import 'exam_models.dart';
import 'exam_progress_store.dart';
import 'exam_repository.dart';
import '../learning/notify_safely.dart';

enum BriefStatus { loading, ready, locked, failed }

/// A sitting the brief hands the exam to open: a fresh one, or a saved one to pick up.
class ExamStart {
  const ExamStart({required this.sitting, this.resume});

  final PaperSitting sitting;
  final ExamSnapshot? resume;
}

/// What the brief of a paper knows: whether the member may sit it, what it
/// takes to open it if not, their record on it, and a sitting left unfinished.
class BriefController extends ChangeNotifier with NotifySafely {
  BriefController({
    required this.repository,
    required this.ref,
    required this.store,
    required this.userId,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final ExamRepository repository;
  final PaperRef ref;
  final ExamProgressStore store;
  final String userId;
  final DateTime Function() _now;

  BriefStatus _status = BriefStatus.loading;
  String? _error;
  PaperInfo? _paper;
  PaperSitting? _sitting;
  PaperLock? _lock;
  PaperQuote? _quote;
  List<Attempt> _attempts = const [];
  ExamCertificate? _certificate;
  ExamSnapshot? _saved;
  bool _working = false;
  String? _actionError;
  int _generation = 0;

  BriefStatus get status => _status;
  String? get error => _error;
  PaperInfo? get paper => _paper;
  PaperLock? get lock => _lock;
  PaperQuote? get quote => _quote;
  List<Attempt> get attempts => _attempts;

  /// The certificate the member holds for this paper, if any.
  ExamCertificate? get certificate => _certificate;

  /// Redeeming or opening is under way.
  bool get working => _working;

  /// The API's sentence when redeeming or opening was refused.
  String? get actionError => _actionError;

  int get attemptsUsed => _attempts.length;

  /// The best percentage across recorded attempts, or null for a first sitting.
  int? get best => _attempts.isEmpty ? null : _attempts.map((a) => a.percentage).reduce((a, b) => a > b ? a : b);

  bool get exhausted {
    final limit = _paper?.attemptLimit;
    return limit != null && attemptsUsed >= limit;
  }

  bool get noQuestions => _sitting != null && _sitting!.questions.isEmpty;

  /// An unfinished sitting from before, if there is one.
  ExamSnapshot? get saved => _saved;

  /// The unfinished sitting's time ran out while the member was away: its
  /// answers go in as they are.
  bool get savedExpired => _saved != null && !_now().isBefore(_saved!.deadline);

  Duration get savedLeft {
    final s = _saved;
    if (s == null) return Duration.zero;
    final left = s.deadline.difference(_now());
    return left.isNegative ? Duration.zero : left;
  }

  /// There is a paper to sit now, and it can be started (or picked up).
  bool get canStart => _status == BriefStatus.ready && !noQuestions && (!exhausted || _saved != null);

  Future<void> load() async {
    final generation = ++_generation;
    _status = BriefStatus.loading;
    _error = null;
    _actionError = null;
    notifyListeners();
    try {
      PaperSitting? sitting;
      PaperLock? lock;
      PaperInfo info;
      PaperQuote? quote;
      try {
        sitting = await repository.sitting(ref.slug);
        info = sitting.paper;
      } on PaperLockedException catch (e) {
        lock = e.lock;
        info = await repository.info(ref);
        quote = await _tryQuote();
      }
      final results = await Future.wait<Object?>([_tryAttempts(info.id), _tryCertificate(info.id)]);
      final saved = sitting == null ? null : await _trySaved(ref.slug);
      if (generation != _generation) return;
      _paper = info;
      _sitting = sitting;
      _lock = lock;
      _quote = quote;
      _attempts = results[0]! as List<Attempt>;
      _certificate = results[1] as ExamCertificate?;
      _saved = saved;
      _status = lock == null ? BriefStatus.ready : BriefStatus.locked;
    } catch (e) {
      if (generation != _generation) return;
      _error = ApiError.from(e).message;
      _status = BriefStatus.failed;
    }
    notifyListeners();
  }

  Future<PaperQuote?> _tryQuote() async {
    try {
      return await repository.quote(ref.slug);
    } catch (_) {
      return null;
    }
  }

  Future<List<Attempt>> _tryAttempts(String paperId) async {
    try {
      return await repository.attempts(paperId: paperId);
    } catch (_) {
      return const [];
    }
  }

  Future<ExamCertificate?> _tryCertificate(String paperId) async {
    try {
      final all = await repository.certificates();
      return all.where((c) => c.paperId == paperId).firstOrNull;
    } catch (_) {
      return null;
    }
  }

  Future<ExamSnapshot?> _trySaved(String slug) async {
    try {
      return await store.load(userId, slug);
    } catch (_) {
      return null;
    }
  }

  /// Spends the credits the paper takes; the brief then loads again, open.
  /// Returns false with [actionError] set when the API refused.
  Future<bool> redeem() => _act(() => repository.redeem(ref.slug));

  /// Opens the course or mock exam with one of the plan's places.
  Future<bool> openWithPlan() {
    final lock = _lock;
    if (lock == null || !lock.planCanOpen) return Future.value(false);
    return _act(() => repository.openWithPlan(target: lock.opensTarget!, targetId: lock.opensId!));
  }

  Future<bool> _act(Future<Object?> Function() run) async {
    if (_working) return false;
    _working = true;
    _actionError = null;
    notifyListeners();
    try {
      await run();
    } catch (e) {
      _actionError = ApiError.from(e).message;
      _working = false;
      notifyListeners();
      // A refusal can mean the member's credits or places changed since: show them as they are now.
      await load();
      _actionError = ApiError.from(e).message;
      notifyListeners();
      return false;
    }
    _working = false;
    await load();
    return true;
  }

  /// A fresh sitting of the paper, to hand the exam.
  ExamStart? begin() {
    final s = _sitting;
    if (s == null || s.questions.isEmpty || exhausted) return null;
    return ExamStart(sitting: s);
  }

  /// The unfinished sitting, to pick up where it was left.
  ExamStart? resume() {
    final s = _saved;
    if (s == null) return null;
    return ExamStart(sitting: s.sitting, resume: s);
  }

  /// Forgets the unfinished sitting, so the next start is a fresh one.
  Future<void> discardSaved() async {
    try {
      await store.clear(userId, ref.slug);
    } catch (_) {}
    _saved = null;
    notifyListeners();
  }
}
