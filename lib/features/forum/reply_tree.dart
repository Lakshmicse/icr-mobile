/// Rules for a discussion's replies as a tree, kept apart from the controller so each is testable alone.
///
/// The forum pages its replies as a flat window of rows ordered by time, nests each page itself, and promotes a
/// reply whose parent is on another page to the top of that page (`buildReplyTree`). So a second page cannot be
/// laid under the first as it arrives: [mergeReplyPages] puts it back where it belongs.
library;

import '../feed/feed_models.dart';

/// The replies read so far ([current]) with a newly read page ([page]) merged in: every reply is kept once (the
/// newer copy wins), and each sits under its parent wherever the page it came on put it.
List<FeedReply> mergeReplyPages(List<FeedReply> current, List<FeedReply> page) {
  final order = <String>[];
  final byId = <String, FeedReply>{};
  void take(List<FeedReply> list) {
    for (final r in list) {
      if (!byId.containsKey(r.id)) order.add(r.id);
      byId[r.id] = r.copyWith(children: const []);
      take(r.children);
    }
  }

  take(current);
  take(page);

  final children = <String, List<String>>{};
  final roots = <String>[];
  for (final id in order) {
    final parent = byId[id]!.parentId;
    if (parent != null && byId.containsKey(parent) && parent != id) {
      (children[parent] ??= []).add(id);
    } else {
      roots.add(id);
    }
  }

  FeedReply build(String id) =>
      byId[id]!.copyWith(children: [for (final c in children[id] ?? const <String>[]) build(c)]);
  return [for (final id in roots) build(id)];
}

/// [reply] added to the tree: under its parent when the tree holds it, else at the top.
List<FeedReply> insertReply(List<FeedReply> replies, FeedReply reply) {
  final parent = reply.parentId;
  if (parent == null || findReply(replies, parent) == null) return [...replies, reply];
  return mapReplies(replies, parent, (r) => r.copyWith(children: [...r.children, reply]));
}

/// The reply with [id] at any depth, or null.
FeedReply? findReply(List<FeedReply> replies, String id) {
  for (final r in replies) {
    if (r.id == id) return r;
    final inside = findReply(r.children, id);
    if (inside != null) return inside;
  }
  return null;
}

/// The tree without the reply [id]; its answers stay in the thread, at the top level, as the forum shows them
/// once their parent is gone (it nests only what it can find).
List<FeedReply> removeReplyKeepAnswers(List<FeedReply> replies, String id) {
  final promoted = <FeedReply>[];
  List<FeedReply> walk(List<FeedReply> list) {
    final out = <FeedReply>[];
    for (final r in list) {
      if (r.id == id) {
        promoted.addAll(r.children);
        continue;
      }
      out.add(r.children.isEmpty ? r : r.copyWith(children: walk(r.children)));
    }
    return out;
  }

  final kept = walk(replies);
  return [...kept, ...promoted];
}

/// How many replies the tree holds.
int countReplies(List<FeedReply> replies) => replies.fold(0, (n, r) => n + 1 + countReplies(r.children));

/// The tree with [id]'s reply the accepted answer (and no other): the forum holds one per question, and shows it
/// first among its siblings.
List<FeedReply> markAccepted(List<FeedReply> replies, String? id) {
  List<FeedReply> walk(List<FeedReply> list) => [
    for (final r in list) r.copyWith(accepted: r.id == id, children: walk(r.children)),
  ];
  final marked = walk(replies);
  if (id == null) return marked;
  final accepted = [
    for (final r in marked)
      if (r.accepted) r,
  ];
  return [
    ...accepted,
    for (final r in marked)
      if (!r.accepted) r,
  ];
}
