import 'package:flutter/foundation.dart';

import '../../../core/api/api_error.dart';
import 'hiring_repository.dart';
import 'interview_brief_models.dart';

/// One interview's page for its panel: reads the brief, sends the viewer's scorecard, fetches the résumé.
class InterviewBriefController extends ChangeNotifier {
  InterviewBriefController(this.repository, this.interviewId);

  final HiringRepository repository;
  final String interviewId;

  InterviewBrief? brief;

  /// Why the page could not be read, in the website's words.
  String? error;

  /// False when the API refused or the round is gone: a retry would say the same.
  bool canRetry = true;
  bool submitting = false;
  int unread = 0;

  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    error = null;
    _notify();
    try {
      brief = await repository.interviewBrief(interviewId);
    } catch (e) {
      final err = ApiError.from(e);
      final status = err.statusCode;
      error = switch (status) {
        404 => 'This interview no longer exists.',
        403 => "You are not on this interview's panel.",
        _ => err.message.isEmpty ? 'Unable to load this interview.' : err.message,
      };
      canRetry = status == null || status >= 500;
    }
    _notify();
    try {
      unread = await repository.unreadNotifications();
      _notify();
    } catch (_) {
      // The bell catches up later.
    }
  }

  /// Sends the scorecard and reads the round again (the rest of the panel's scorecards open once it is in).
  /// Null when it went in; otherwise the API's sentence.
  Future<String?> submit(ScorecardDraft draft) async {
    if (!draft.ready || submitting) return null;
    submitting = true;
    _notify();
    try {
      await repository.submitScorecard(interviewId, draft);
      brief = await repository.interviewBrief(interviewId);
      return null;
    } catch (e) {
      final message = ApiError.from(e).message;
      return message.isEmpty ? 'Unable to submit feedback.' : message;
    } finally {
      submitting = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
