import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import 'assistant_models.dart';
import 'assistant_repository.dart';

/// Saathi over the API: `POST /ai/chat`, a public route. The reply streams as server-sent events (`{delta}`
/// frames, then one `{actions}` frame, then `[DONE]`; `{error: true}` when the reply failed midway), as the
/// website's `lib/assistant.ts` reads it. When the stream cannot be had, one plain JSON reply is asked for
/// instead (`Accept: application/json` → `{ reply, actions }`).
class ApiAssistantRepository implements AssistantRepository {
  ApiAssistantRepository({required this.api});

  final ApiClient api;

  /// How much of the conversation is sent: the API refuses more than 40 messages, and the latest few are all an
  /// answer needs (the website sends the same).
  static const maxSent = 20;

  /// How long a reply may go without a word before it is given up on.
  static const stall = Duration(seconds: 30);

  @override
  Stream<AssistantEvent> ask(List<AssistantMessage> history, AssistantContext context) async* {
    final sent = history.length > maxSent ? history.sublist(history.length - maxSent) : history;
    final body = {
      'messages': [for (final m in sent) m.toJson()],
      'context': context.toJson(),
    };

    Response<ResponseBody> res;
    try {
      res = await api.dio.post<ResponseBody>(
        '/ai/chat',
        data: body,
        options: Options(
          responseType: ResponseType.stream,
          headers: {'Accept': 'text/event-stream'},
          receiveTimeout: stall,
        ),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        yield const AssistantDelta(AssistantCopy.rateLimited);
        return;
      }
      yield* _json(body);
      return;
    }

    final stream = res.data?.stream;
    final type = res.headers.value(Headers.contentTypeHeader) ?? '';
    if (stream == null) {
      yield* _json(body);
      return;
    }
    if (!type.contains('text/event-stream')) {
      // Answered as JSON after all (a proxy, or an older API): read it whole.
      final text = await stream.cast<List<int>>().transform(utf8.decoder).join();
      yield* _replyEvents(_decode(text));
      return;
    }

    var buffer = '';
    var said = false;
    await for (final chunk in stream.cast<List<int>>().transform(utf8.decoder)) {
      buffer += chunk;
      // Frames are separated by a blank line; the last piece may be a frame still arriving.
      final frames = buffer.split('\n\n');
      buffer = frames.removeLast();
      for (final frame in frames) {
        final line = frame.trim();
        if (!line.startsWith('data:')) continue;
        final payload = line.substring(5).trim();
        if (payload == '[DONE]') return;
        final Object? obj;
        try {
          obj = jsonDecode(payload);
        } catch (_) {
          continue; // a malformed frame
        }
        if (obj is! Map) continue;
        // The API writes this instead of [DONE] when its reply failed midway. What was said stays; with nothing
        // said the screen shows its "trouble responding" line.
        if (obj['error'] == true) {
          if (said) return;
          throw const AssistantUnavailable('the reply failed');
        }
        final delta = obj['delta'];
        if (delta is String && delta.isNotEmpty) {
          said = true;
          yield AssistantDelta(delta);
        }
        final actions = obj['actions'];
        if (actions is List) yield AssistantActions(_actions(actions));
      }
    }
    if (!said) throw const AssistantUnavailable('the stream ended with no reply');
  }

  /// One whole reply, when streaming is not to be had.
  Stream<AssistantEvent> _json(Map<String, dynamic> body) async* {
    Map<String, dynamic>? json;
    try {
      final res = await api.dio.post<Map<String, dynamic>>(
        '/ai/chat',
        data: body,
        options: Options(headers: {'Accept': 'application/json'}),
      );
      json = res.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        yield const AssistantDelta(AssistantCopy.rateLimited);
        return;
      }
      throw AssistantUnavailable('${e.response?.statusCode ?? e.type}');
    }
    yield* _replyEvents(json);
  }

  Stream<AssistantEvent> _replyEvents(Map<String, dynamic>? json) async* {
    final reply = json?['reply'];
    if (reply is! String || reply.isEmpty) throw const AssistantUnavailable('no reply');
    yield AssistantDelta(reply);
    final actions = json?['actions'];
    if (actions is List && actions.isNotEmpty) yield AssistantActions(_actions(actions));
  }

  static Map<String, dynamic>? _decode(String text) {
    try {
      final v = jsonDecode(text);
      return v is Map ? Map<String, dynamic>.from(v) : null;
    } catch (_) {
      return null;
    }
  }

  static List<QuickAction> _actions(List<dynamic> raw) => [
    for (final a in raw)
      if (a is Map && '${a['href'] ?? ''}'.isNotEmpty) QuickAction.fromJson(Map<String, dynamic>.from(a)),
  ];
}
