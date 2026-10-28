import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import 'exam_models.dart';
import 'exam_progress_store.dart';
import 'exam_repository.dart';

/// Where an exam stands: being sat, being sent, refused or failed (the answers
/// are kept and sending can be tried again), or done.
enum ExamPhase { running, submitting, failed, done }

/// A question's place in the palette, with the conventional CBT vocabulary.
enum QuestionMark { notVisited, notAnswered, answered, flagged, answeredFlagged }

/// The numbers the submit overview and the palette legend show.
class ExamCounts {
  const ExamCounts({
    required this.total,
    required this.answered,
    required this.flagged,
    required this.notVisited,
    required this.byMark,
  });

  final int total;
  final int answered;
  final int flagged;
  final int notVisited;
  final Map<QuestionMark, int> byMark;

  int get skipped => total - answered;
}

/// One sitting of a paper: the answers, flags and place in the paper, the clock,
/// and sending the answers.
///
/// The clock is the wall clock: the time left is always `startedAt + the time
/// limit - now`, recomputed on every tick and when the app comes back to the
/// front, so a backgrounded or throttled timer can never grant or lose time.
/// Reaching zero submits what is answered. Everything that changes is kept to
/// [store] so the sitting survives the app being closed.
class ExamController extends ChangeNotifier {
  ExamController({
    required this.sitting,
    required this.repository,
    required this.store,
    required this.userId,
    DateTime Function()? now,
    ExamSnapshot? resume,
    this.tickEvery = const Duration(seconds: 1),
  }) : _now = now ?? DateTime.now {
    final snapshot = resume;
    if (snapshot != null) {
      startedAt = snapshot.startedAt;
      _current = snapshot.currentIndex;
      for (final e in snapshot.answers.entries) {
        if (e.value.isNotEmpty) _answers[e.key] = _normalised(e.value);
      }
      _flagged.addAll(snapshot.flagged);
      _visited.addAll(snapshot.visited);
      resumed = true;
    } else {
      startedAt = _now();
    }
    remaining = ValueNotifier(_timeLeft());
  }

  final PaperSitting sitting;
  final ExamRepository repository;
  final ExamProgressStore store;
  final String userId;
  final Duration tickEvery;
  final DateTime Function() _now;

  late final DateTime startedAt;

  /// This sitting was picked up from a saved one.
  bool resumed = false;

  /// The time left, ticking; separate from the controller so only the clock
  /// rebuilds each second.
  late final ValueNotifier<Duration> remaining;

  final Map<String, List<int>> _answers = {};
  final Set<String> _flagged = {};
  final Set<String> _visited = {};
  int _current = 0;
  Timer? _timer;
  bool _disposed = false;

  ExamPhase _phase = ExamPhase.running;
  String? _error;
  int? _errorStatus;
  AttemptResult? _result;
  bool _autoSubmitted = false;
  bool _posted = false;
  Future<bool>? _inFlight;
  Future<void>? _flushFuture;
  bool _dirty = false;

  PaperInfo get paper => sitting.paper;
  List<ServedQuestion> get questions => sitting.questions;
  int get total => questions.length;
  int get current => _current;
  ServedQuestion get question => questions[_current];
  ExamPhase get phase => _phase;
  String? get error => _error;
  AttemptResult? get result => _result;

  /// The clock ran out and the answers were sent by the app, not the candidate.
  bool get autoSubmitted => _autoSubmitted;

  /// Sending again can help: not when the API refused for good (the attempts
  /// are used up, the paper is closed).
  bool get retryable {
    final s = _errorStatus;
    return s == null || s >= 500 || s == 408 || s == 429 || s == 401;
  }

  DateTime get deadline => startedAt.add(paper.duration);
  bool get timeUp => !_now().isBefore(deadline);
  bool get editable => _phase == ExamPhase.running && !timeUp;

  /// Under five minutes left: the clock turns red.
  bool get lowTime => remaining.value < const Duration(minutes: 5);

  Duration _timeLeft() {
    final left = deadline.difference(_now());
    return left.isNegative ? Duration.zero : left;
  }

  // --- the clock ------------------------------------------------------------------------------------

  /// Marks the opening question seen, starts the clock's ticks and keeps the
  /// sitting. A sitting resumed after its time ran out is sent at once.
  void start() {
    if (total == 0) return;
    _visited.add(question.id);
    _timer?.cancel();
    _timer = Timer.periodic(tickEvery, (_) => tick());
    tick();
    _persist();
  }

  /// Recomputes the time left; at zero, sends what is answered. Also called
  /// when the app returns to the front.
  void tick() {
    if (_disposed) return;
    final left = _timeLeft();
    if (remaining.value != left) remaining.value = left;
    if (left == Duration.zero && _phase == ExamPhase.running) submit(auto: true);
  }

  // --- the answers ----------------------------------------------------------------------------------

  List<int> picked(String questionId) => _answers[questionId] ?? const [];
  bool isAnswered(int index) => picked(questions[index].id).isNotEmpty;
  bool isFlagged(int index) => _flagged.contains(questions[index].id);

  /// Taps an option: a single-choice question takes just that one; a
  /// multiple-choice one toggles it.
  void select(int option) {
    if (!editable || option < 0 || option >= question.options.length) return;
    final id = question.id;
    if (question.multiple) {
      final now = {...picked(id)};
      if (!now.add(option)) now.remove(option);
      _setAnswer(id, now.toList());
    } else {
      _setAnswer(id, [option]);
    }
    _changed();
  }

  /// Clears the response to the open question.
  void clearAnswer() {
    if (!editable || picked(question.id).isEmpty) return;
    _answers.remove(question.id);
    _changed();
  }

  /// Flags the open question for review, or takes the flag off.
  void toggleFlag() {
    if (!editable) return;
    if (!_flagged.add(question.id)) _flagged.remove(question.id);
    _changed();
  }

  void goTo(int index) {
    if (_phase != ExamPhase.running || index < 0 || index >= total || index == _current) return;
    _current = index;
    _visited.add(question.id);
    _changed();
  }

  void next() => goTo(_current + 1);
  void previous() => goTo(_current - 1);

  void _setAnswer(String id, List<int> picks) {
    if (picks.isEmpty) {
      _answers.remove(id);
    } else {
      _answers[id] = _normalised(picks);
    }
  }

  static List<int> _normalised(List<int> picks) => ({...picks}.toList()..sort());

  QuestionMark markOf(int index) {
    final q = questions[index];
    final answered = picked(q.id).isNotEmpty;
    final flagged = _flagged.contains(q.id);
    if (answered && flagged) return QuestionMark.answeredFlagged;
    if (flagged) return QuestionMark.flagged;
    if (answered) return QuestionMark.answered;
    return _visited.contains(q.id) ? QuestionMark.notAnswered : QuestionMark.notVisited;
  }

  ExamCounts get counts {
    final by = {for (final m in QuestionMark.values) m: 0};
    var answered = 0;
    var flagged = 0;
    var unseen = 0;
    for (var i = 0; i < total; i++) {
      final m = markOf(i);
      by[m] = by[m]! + 1;
      if (m == QuestionMark.answered || m == QuestionMark.answeredFlagged) answered++;
      if (m == QuestionMark.flagged || m == QuestionMark.answeredFlagged) flagged++;
      if (m == QuestionMark.notVisited) unseen++;
    }
    return ExamCounts(total: total, answered: answered, flagged: flagged, notVisited: unseen, byMark: by);
  }

  void _changed() {
    notifyListeners();
    _persist();
  }

  // --- keeping the sitting --------------------------------------------------------------------------

  ExamSnapshot snapshot() => ExamSnapshot(
    userId: userId,
    sitting: sitting,
    startedAtMs: startedAt.millisecondsSinceEpoch,
    currentIndex: _current,
    answers: {
      for (final e in _answers.entries) e.key: [...e.value],
    },
    flagged: _flagged.toList(),
    visited: _visited.toList(),
  );

  /// Writes the sitting to the store; writes that arrive while one is running
  /// are folded into a last write, so the store ends with the newest state.
  Future<void> _persist() {
    if (_phase == ExamPhase.done) return Future.value();
    _dirty = true;
    return _flushFuture ??= _drain();
  }

  Future<void> _drain() async {
    try {
      while (_dirty) {
        _dirty = false;
        try {
          await store.save(snapshot());
        } catch (_) {
          // Not keeping the sitting is no reason to stop it.
        }
      }
    } finally {
      _flushFuture = null;
    }
  }

  /// Completes when everything changed so far has been written.
  Future<void> flushed() => _flushFuture ?? Future.value();

  /// Gives the saved sitting up: leaving for good without sending.
  Future<void> discard() => store.clear(userId, paper.slug);

  // --- sending --------------------------------------------------------------------------------------

  List<SubmittedAnswer> get payload => [
    for (final q in questions) SubmittedAnswer(q.id, [...picked(q.id)]),
  ];

  /// Sends the answers. Pressing it twice, or the clock running out while a send
  /// is under way, joins the send in flight: one sitting, one attempt.
  ///
  /// Returns true once the result is in. A refusal or a failure leaves the
  /// answers where they are and [phase] at [ExamPhase.failed]; call again to retry.
  Future<bool> submit({bool auto = false}) {
    if (_phase == ExamPhase.done) return Future.value(true);
    return _inFlight ??= _send(auto).whenComplete(() => _inFlight = null);
  }

  Future<bool> _send(bool auto) async {
    _phase = ExamPhase.submitting;
    _autoSubmitted = _autoSubmitted || auto;
    _error = null;
    _errorStatus = null;
    _notify();
    try {
      // A send that timed out may still have landed: look for it before sending the sitting twice.
      final earlier = _posted ? await _alreadySent() : null;
      _posted = true;
      final result = earlier ?? await repository.submit(paper.slug, startedAt: startedAt, answers: payload);
      _result = result;
      _phase = ExamPhase.done;
      _timer?.cancel();
      await _flushFuture;
      try {
        await store.clear(userId, paper.slug);
      } catch (_) {}
      _notify();
      return true;
    } catch (e) {
      final err = ApiError.from(e);
      _error = err.message;
      _errorStatus = err.statusCode;
      _phase = ExamPhase.failed;
      _notify();
      return false;
    }
  }

  /// After a failed send with time still on the clock: back to the paper, to go on answering.
  bool reopen() {
    if (_phase != ExamPhase.failed || timeUp) return false;
    _phase = ExamPhase.running;
    _error = null;
    _errorStatus = null;
    _notify();
    return true;
  }

  /// The sitting with this start time, if the server already holds it.
  Future<AttemptResult?> _alreadySent() async {
    try {
      final mine = await repository.attempts(paperId: paper.id);
      final match = mine.where((a) => a.startedAt?.millisecondsSinceEpoch == startedAt.millisecondsSinceEpoch);
      if (match.isEmpty) return null;
      return await repository.attempt(match.first.id);
    } catch (_) {
      return null;
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    remaining.dispose();
    super.dispose();
  }
}
