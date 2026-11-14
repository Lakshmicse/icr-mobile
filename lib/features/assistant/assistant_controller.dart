import 'dart:async';

import 'package:flutter/foundation.dart';

import 'assistant_models.dart';
import 'assistant_repository.dart';

/// One conversation with Saathi, kept for as long as the app runs (the website keeps its for the browser
/// session): what was said, the reply being written, and the sending.
class AssistantController extends ChangeNotifier {
  AssistantController(this.repository, {this.stall = const Duration(seconds: 30), DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AssistantRepository repository;
  final DateTime Function() _clock;

  /// How long a reply may go without a word before the screen gives up on it, so the composer never stays locked
  /// on a connection that will not finish.
  final Duration stall;

  /// How much of the conversation is kept (the website keeps the same).
  static const maxHistory = 30;

  final List<AssistantMessage> _messages = [];
  List<AssistantMessage> get messages => List.unmodifiable(_messages);

  /// A reply is being written.
  bool get streaming => _streaming;
  bool _streaming = false;
  bool _disposed = false;

  /// The reply being written has no words yet (the typing dots).
  bool get awaitingFirstWord =>
      _streaming && _messages.isNotEmpty && _messages.last.isAssistant && _messages.last.content.isEmpty;

  /// Opens with the greeting the first time.
  void open() {
    if (_messages.isNotEmpty) return;
    _messages.add(const AssistantMessage.assistant(AssistantCopy.greeting));
    _notify();
  }

  /// Sends [text] and writes the reply in as it arrives. A second send while one is in flight is ignored.
  Future<void> send(String text, AssistantContext context) async {
    final asked = text.trim();
    if (asked.isEmpty || _streaming) return;
    _streaming = true;
    final now = _clock();
    _messages.add(AssistantMessage.user(asked, at: now));
    _trim();
    final history = List<AssistantMessage>.of(_messages);
    _messages.add(AssistantMessage.assistant('', at: now));
    _notify();
    try {
      await for (final event in repository.ask(history, context).timeout(stall)) {
        switch (event) {
          case AssistantDelta(:final text):
            _updateReply((r) => r.copyWith(content: r.content + text));
          case AssistantActions(:final actions):
            _updateReply((r) => r.copyWith(actions: actions));
        }
      }
    } catch (_) {
      // Only an empty bubble is replaced: a reply cut off midway keeps what it said.
      _updateReply((r) => r.content.isEmpty ? r.copyWith(content: AssistantCopy.troubleResponding) : r);
    } finally {
      _streaming = false;
      _notify();
    }
  }

  void _updateReply(AssistantMessage Function(AssistantMessage reply) change) {
    if (_messages.isEmpty || !_messages.last.isAssistant) return;
    _messages[_messages.length - 1] = change(_messages.last);
    _notify();
  }

  void _trim() {
    while (_messages.length > maxHistory) {
      _messages.removeAt(0);
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
