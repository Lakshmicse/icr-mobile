import 'package:flutter/foundation.dart';

import 'support_controller.dart' show refusalOf;
import 'support_models.dart';
import 'support_repository.dart';
import 'support_words.dart';

/// One request and what the member does to it: reply, reopen, rate. The website's `/support/[id]` (`TicketThread`).
///
/// An action's answer is the ticket without its thread, so every success keeps the thread on screen, takes the
/// answer's status, and reads the thread again.
class TicketController extends ChangeNotifier {
  TicketController({required this.repository, required this.ticketId});

  final SupportRepository repository;
  final String ticketId;

  SupportTicket? ticket;
  bool loading = true;
  String? loadError;

  bool sending = false;
  bool reopening = false;
  bool rating = false;

  /// What the last action was refused with, shown beside the control that caused it.
  String? replyError;
  String? reopenError;
  String? ratingError;

  bool _disposed = false;

  bool get busy => sending || reopening || rating;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load({bool refresh = false}) async {
    if (!refresh) {
      loading = true;
      loadError = null;
      _notify();
    }
    try {
      ticket = await repository.ticket(ticketId);
      loadError = null;
    } catch (e) {
      if (ticket == null || !refresh) loadError = SupportWords.couldNotOpen;
    } finally {
      loading = false;
      _notify();
    }
  }

  /// Sends a reply. True when it went; the sentence is in [replyError] when it did not (the typed text stays).
  Future<bool> reply(String body, List<SupportAttachmentDraft> attachments) async {
    if (busy || body.trim().isEmpty) return false;
    sending = true;
    replyError = null;
    _notify();
    try {
      final answer = await repository.reply(ticketId, body, attachments);
      await _took(answer);
      return true;
    } catch (e) {
      replyError = refusalOf(e, SupportWords.replyNotSent);
      return false;
    } finally {
      sending = false;
      _notify();
    }
  }

  Future<bool> reopen() async {
    if (busy) return false;
    reopening = true;
    reopenError = null;
    _notify();
    try {
      await _took(await repository.reopen(ticketId));
      return true;
    } catch (e) {
      reopenError = refusalOf(e, SupportWords.couldNotReopen);
      return false;
    } finally {
      reopening = false;
      _notify();
    }
  }

  Future<bool> rate(int score) async {
    if (busy || score < 1 || score > 5) return false;
    rating = true;
    ratingError = null;
    _notify();
    try {
      await _took(await repository.rate(ticketId, score));
      return true;
    } catch (e) {
      ratingError = refusalOf(e, SupportWords.couldNotRate);
      return false;
    } finally {
      rating = false;
      _notify();
    }
  }

  /// Takes an action's answer, then reads the thread again (the answer carries none).
  Future<void> _took(SupportTicket answer) async {
    final current = ticket;
    ticket = current == null ? answer : current.withAnswer(answer);
    _notify();
    try {
      ticket = await repository.ticket(ticketId);
    } catch (_) {
      // The answer already says what changed; the thread catches up on the next read.
    }
  }
}
