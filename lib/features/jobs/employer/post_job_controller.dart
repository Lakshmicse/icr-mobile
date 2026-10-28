import 'package:flutter/foundation.dart';

import '../../../core/api/api_error.dart';
import 'hiring_models.dart';
import 'hiring_repository.dart';
import 'job_rules.dart';

/// The base of the employer controllers: the source, the bell's count, and a guard so an
/// answer arriving after the screen closed has nobody to tell.
abstract class HiringController extends ChangeNotifier {
  HiringController(this.repository, {DateTime Function()? clock}) : clock = clock ?? DateTime.now;

  final HiringRepository repository;
  final DateTime Function() clock;

  bool _disposed = false;
  int _unread = 0;

  int get unread => _unread;
  bool get disposed => _disposed;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> loadUnread() async {
    try {
      _unread = await repository.unreadNotifications();
      notifyListeners();
    } catch (_) {
      // The bell shows no dot.
    }
  }
}

/// How a save, a publish or a send to review went.
class PostOutcome {
  const PostOutcome.ok(this.jobId, this.status, {this.note}) : message = null;
  const PostOutcome.refused(String this.message, {this.jobId, this.status}) : note = null;

  /// The posting, once it exists: a refused publish still leaves a saved draft.
  final String? jobId;
  final PostingStatus? status;

  /// The API's sentence, or ours, when it did not go through.
  final String? message;

  /// Something to tell the member beyond "done".
  final String? note;

  bool get ok => message == null;
}

/// "Post a job": the composer's state. Saving keeps a draft (a posting may be half-filled);
/// publishing needs the checklist clear and the company verified, and the API has the last
/// word (the plan's live-post room, ICR's review).
class PostJobController extends HiringController {
  PostJobController(super.repository, {JobDraft? initial, this.jobId, super.clock})
    : _draft = initial ?? const JobDraft();

  /// The posting being edited; null makes a new one.
  final String? jobId;

  JobDraft _draft;
  HiringAccess? _access;
  List<JobTitleOption> _titles = const [];
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  bool _screeningDirty = false;
  String? _error;
  String? _id;

  JobDraft get draft => _draft;
  HiringAccess? get access => _access;
  bool get loading => _loading;

  /// A save or publish is on its way: its buttons wait.
  bool get saving => _saving;
  bool get dirty => _dirty;

  /// The posting's id once it has been saved.
  String? get id => _id ?? jobId;
  String? get error => _error;

  /// Editing a posting that already exists (it may be live).
  bool get editing => id != null;

  /// The posting is on the board or in review now.
  bool get live => _draft.status == PostingStatus.open || _draft.status == PostingStatus.inReview;

  Future<void> start() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait<Object?>([
        repository.access(),
        _tryTitles(),
        if (jobId != null) repository.job(jobId!),
      ]);
      _access = results[0] as HiringAccess;
      _titles = results[1] as List<JobTitleOption>;
      if (jobId != null) _draft = results[2] as JobDraft;
    } catch (e) {
      _error = ApiError.from(e).message;
    } finally {
      _loading = false;
      notifyListeners();
    }
    await loadUnread();
  }

  Future<List<JobTitleOption>> _tryTitles() async {
    try {
      return await repository.jobTitles();
    } catch (_) {
      return const [];
    }
  }

  /// Changes the draft: what the form edits.
  void update(JobDraft Function(JobDraft draft) change, {bool screening = false}) {
    _draft = change(_draft);
    _dirty = true;
    if (screening) _screeningDirty = true;
    notifyListeners();
  }

  /// Sets the title, and the function of a listed title with it: any other title clears the function
  /// (the composer is the only writer of `jobFunctions`, so it always follows the title).
  void setTitle(String title) {
    final key = jobTitleKey(title);
    final listed = _titles.where((t) => jobTitleKey(t.name) == key);
    final function = listed.isEmpty ? null : listed.first.jobFunction;
    final next = function == null ? const <String>[] : [function];
    update((d) => d.copyWith(title: title, jobFunctions: next));
  }

  /// The staff-managed titles that contain what was typed, best first, at most [max]. A title the
  /// recruiter types themselves is fine too: suggested, never enforced.
  List<String> titleSuggestions(String typed, {int max = 6}) {
    final q = typed.trim().toLowerCase();
    if (q.length < 2) return const [];
    final starts = <String>[];
    final inside = <String>[];
    for (final option in _titles) {
      final t = option.name;
      final l = t.toLowerCase();
      if (l == q) continue;
      if (l.startsWith(q)) {
        starts.add(t);
      } else if (l.contains(q)) {
        inside.add(t);
      }
    }
    return [...starts, ...inside].take(max).toList();
  }

  Future<List<String>> skillSuggestions(String typed) async {
    try {
      final got = await repository.skillSuggestions(typed);
      final have = {
        ..._draft.skills.map((s) => s.toLowerCase()),
        ..._draft.preferredSkills.map((s) => s.toLowerCase()),
      };
      return [
        for (final s in got)
          if (!have.contains(s.toLowerCase())) s,
      ];
    } catch (_) {
      return const [];
    }
  }

  /// What stands between the posting and going live (empty: it may publish).
  List<JobBlocker> get blockers => _draft.blockers;

  /// Why Publish cannot even be tried: the company is not verified.
  String? get publishBlockedReason {
    final a = _access;
    if (a == null || a.canPublish) return null;
    return a.publishNote?.trim().isNotEmpty == true
        ? a.publishNote
        : 'Verify your company before publishing jobs. Your drafts are saved — finish verification and publish them in one click.';
  }

  /// Why the questions cannot be saved, if any.
  String? get screeningProblem {
    if (_draft.screening.length > JobLimits.screeningQuestionsMax) {
      return 'Ask at most ${JobLimits.screeningQuestionsMax} questions.';
    }
    for (final q in _draft.screening) {
      final p = q.problem;
      if (p != null) return p;
    }
    return null;
  }

  /// Saves the posting as it stands, a draft if it is new. A live posting stays live; the API checks it.
  Future<PostOutcome> save() async {
    final problem = _draft.saveProblem ?? screeningProblem;
    if (problem != null) return PostOutcome.refused(problem);
    return _run(() async {
      await _ensureSaved(live ? null : PostingStatus.draft);
      return PostOutcome.ok(id, _draft.status, note: live ? 'Changes saved.' : 'Draft saved.');
    });
  }

  /// Publishes the posting: saved first (so nothing typed is lost whatever the API says), then moved to OPEN.
  Future<PostOutcome> publish() async {
    final problem = _draft.saveProblem ?? screeningProblem;
    if (problem != null) return PostOutcome.refused(problem);
    final missing = blockers;
    if (missing.isNotEmpty) {
      return PostOutcome.refused(
        missing.length == 1 ? missing.first.message : 'Finish ${missing.length} things before publishing.',
      );
    }
    final gate = publishBlockedReason;
    if (gate != null) return PostOutcome.refused(gate);
    return _run(() async {
      await _ensureSaved(live ? null : PostingStatus.draft);
      if (_draft.status != PostingStatus.open) {
        try {
          await repository.updateJob(id!, _draft, status: PostingStatus.open);
        } on ApiError catch (e) {
          // The posting stays a saved draft: the API's sentence says why (the plan's room, verification).
          return PostOutcome.refused(e.message, jobId: id, status: _draft.status);
        }
        _draft = _draft.copyWith(status: PostingStatus.open);
      }
      return PostOutcome.ok(id, PostingStatus.open, note: 'Published. It is live on the job board.');
    });
  }

  /// Sends the draft to ICR's review instead of publishing it directly.
  Future<PostOutcome> submitForReview() async {
    final problem = _draft.saveProblem ?? screeningProblem;
    if (problem != null) return PostOutcome.refused(problem);
    final missing = blockers;
    if (missing.isNotEmpty) {
      return PostOutcome.refused(
        missing.length == 1 ? missing.first.message : 'Finish ${missing.length} things before sending it to review.',
      );
    }
    return _run(() async {
      await _ensureSaved(PostingStatus.draft);
      try {
        await repository.submitForReview(id!);
      } on ApiError catch (e) {
        return PostOutcome.refused(e.message, jobId: id, status: _draft.status);
      }
      _draft = _draft.copyWith(status: PostingStatus.inReview);
      return PostOutcome.ok(id, PostingStatus.inReview, note: 'Sent to ICR for review. It goes live once approved.');
    });
  }

  /// Creates or updates the posting; [createAs] is the status a new one is made with.
  Future<void> _ensureSaved(PostingStatus? createAs) async {
    if (id == null) {
      _id = await repository.createJob(_draft, createAs ?? PostingStatus.draft);
      _draft = _draft.copyWith(status: createAs ?? PostingStatus.draft);
    } else {
      await repository.updateJob(id!, _draft);
    }
    if (_screeningDirty || (_draft.screening.isNotEmpty && jobId == null)) {
      await repository.setScreeningQuestions(id!, _draft.screening);
      _screeningDirty = false;
    }
    _dirty = false;
  }

  Future<PostOutcome> _run(Future<PostOutcome> Function() work) async {
    _saving = true;
    notifyListeners();
    try {
      return await work();
    } catch (e) {
      return PostOutcome.refused(ApiError.from(e).message, jobId: id);
    } finally {
      _saving = false;
      notifyListeners();
    }
  }
}
