import 'assistant_models.dart';

/// Where Saathi's replies come from: the API (`POST /ai/chat`), or sample answers.
abstract class AssistantRepository {
  /// Answers the conversation so far: the reply's text as it arrives, then the pages it points to. Throws when
  /// no reply could be had (the screen then shows its "trouble responding" line in place of an empty bubble).
  Stream<AssistantEvent> ask(List<AssistantMessage> history, AssistantContext context);
}

/// Thrown when the assistant could not answer at all.
class AssistantUnavailable implements Exception {
  const AssistantUnavailable(this.reason);

  final String reason;

  @override
  String toString() => 'AssistantUnavailable($reason)';
}
