import 'feed_models.dart';

/// The discussion as it reads once the reader reacts with [kind] (changing an earlier reaction), or takes the
/// reaction back when [kind] is null: the totals, the per-kind counts and the stack of the three most used kinds.
/// One rule for the Home feed, the Forums tab and the discussion page, so a card reads the same in each.
FeedPost withReaction(FeedPost post, ReactionKind? kind) {
  final before = post.myReaction;
  if (before == kind) return post;
  final counts = {...post.reactionCounts};
  if (before != null) counts[before] = ((counts[before] ?? 1) - 1).clamp(0, 1 << 30);
  if (kind != null) counts[kind] = (counts[kind] ?? 0) + 1;
  final total = (post.reactions + (before == null ? 1 : 0) - (kind == null ? 1 : 0)).clamp(0, 1 << 30);
  // A card whose per-kind counts were not read keeps a stack of the kinds it knows plus the new one.
  final known = post.reactionCounts.isNotEmpty;
  final kinds = known
      ? topReactionKinds(counts)
      : [
          ?kind,
          for (final k in post.reactionKinds)
            if (k != kind && (k != before || post.reactions > 1)) k,
        ].take(3).toList();
  return post.copyWith(
    reactions: total,
    reactionCounts: counts,
    // Taking back the only reaction empties the stack too.
    reactionKinds: total == 0 ? const [] : kinds,
    myReaction: kind,
    clearMyReaction: kind == null,
  );
}
