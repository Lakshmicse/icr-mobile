import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/api/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/util/time_ago.dart';
import '../../forum/mentions/mention_widgets.dart';
import '../feed_models.dart';
import '../feed_styles.dart';
import 'feed_avatar.dart';

/// A comment as LinkedIn draws one (owner, 13 Nov 2026: "Redesign the Comment like this", with LinkedIn's comment
/// sheet beside it): no bubble. The photo, then the name with the age, "Follow" and the three dots at the row's
/// end, the headline on one line, the words, and under them the like and reply glyphs with their counts. Answers
/// hang one step in off a thin line that drops from the comment's photo, however deep the forum nests them, each
/// opening on the name of the person it answers.
class CommentDesign {
  CommentDesign._();

  static const avatar = 32.0;
  static const gap = 8.0;

  /// A page's side margin around a list of comments.
  static const pad = 12.0;
  static const line = Color(0xFFE0DFDC);
  static const focusFill = Color(0xFFEDF3F8);

  static final name = roboto(15, FontWeight.w600, HomeLook.ink, lineHeight: 20);
  static final age = roboto(12, FontWeight.w400, HomeLook.soft, lineHeight: 20);
  static final follow = roboto(14, FontWeight.w600, AppColors.primary, lineHeight: 20);
  static final headline = roboto(12, FontWeight.w400, HomeLook.soft, lineHeight: 16);
  static final body = roboto(14, FontWeight.w400, HomeLook.ink, lineHeight: 20);
  static final count = roboto(13, FontWeight.w400, HomeLook.soft, lineHeight: 18);
  static final sort = roboto(14, FontWeight.w500, HomeLook.ink, lineHeight: 20);
}

/// Whom the reader follows, as far as a list of comments needs to know: "Follow" is offered beside a comment only
/// once the forum has said the reader does not follow its author, and goes the moment it is tapped.
class FollowBook extends ChangeNotifier {
  FollowBook({required this.viewerId, required this.follows, required this.follow});

  final String viewerId;

  /// Whether the reader follows a member (the forum answers from the list it keeps for the session).
  final Future<bool> Function(String memberId) follows;

  /// Follows a member.
  final Future<void> Function(String memberId) follow;

  final Map<String, bool> _known = {};
  final Set<String> _asked = {};
  bool _gone = false;

  /// "Follow" is drawn beside [author]: someone else, known not to be followed. Asks once for anyone not yet known.
  bool offers(FeedAuthor author) {
    if (viewerId.isEmpty || author.id.isEmpty || author.id == viewerId) return false;
    final known = _known[author.id];
    if (known == null) _ask(author.id);
    return known == false;
  }

  Future<void> _ask(String id) async {
    if (!_asked.add(id)) return;
    try {
      final answer = await follows(id);
      if (_gone) return;
      _known[id] = answer;
      notifyListeners();
    } catch (_) {
      // Not known: no button, which is the safe reading.
    }
  }

  /// Follows [author]; a sentence when the forum refuses, and the button comes back.
  Future<String?> followAuthor(FeedAuthor author) async {
    _known[author.id] = true;
    notifyListeners();
    try {
      await follow(author.id);
      return null;
    } catch (e) {
      if (_gone) return null;
      _known[author.id] = false;
      notifyListeners();
      return ApiError.from(e).message;
    }
  }

  @override
  void dispose() {
    _gone = true;
    super.dispose();
  }
}

/// One comment and every answer under it, in the order they are drawn: the comment, then its answers flattened to
/// one step. An answer to an answer names whom it answers ([replyingTo]) unless its words already open on them.
List<({FeedReply reply, bool nested, String? replyingTo})> commentRows(FeedReply top) {
  final rows = <({FeedReply reply, bool nested, String? replyingTo})>[(reply: top, nested: false, replyingTo: null)];
  void walk(FeedReply parent) {
    for (final child in parent.children) {
      final name = parent.author.name;
      final opens = child.body.trimLeft().toLowerCase();
      final named = opens.startsWith(name.toLowerCase()) || opens.startsWith('@${name.toLowerCase()}');
      rows.add((reply: child, nested: true, replyingTo: named || name.isEmpty ? null : name));
      walk(child);
    }
  }

  walk(top);
  return rows;
}

/// The answers under a comment: one step in, off the line that drops from the comment's photo.
class CommentReplies extends StatelessWidget {
  const CommentReplies({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    const half = CommentDesign.avatar / 2 - 1;
    return Container(
      margin: const EdgeInsets.only(left: half),
      padding: const EdgeInsets.only(left: half + CommentDesign.gap),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: CommentDesign.line, width: 2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

class CommentTile extends StatelessWidget {
  const CommentTile({
    super.key,
    required this.reply,
    required this.onLike,
    required this.onReply,
    required this.onMore,
    this.replyCount = 0,
    this.replyingTo,
    this.onFollow,
    this.onOpenAuthor,
    this.onOpenMention,
    this.actions = const [],
    this.badge,
    this.below,
    this.focused = false,
    this.maxBodyLines,
    this.now,
  });

  final FeedReply reply;
  final VoidCallback onLike;
  final VoidCallback onReply;
  final VoidCallback onMore;

  /// How many answers hang under it, beside the reply glyph; none, the glyph alone.
  final int replyCount;

  /// The person this answer is to, drawn in blue before its words.
  final String? replyingTo;

  /// "Follow" beside the age; absent, no button (the reader's own comment, or someone already followed).
  final VoidCallback? onFollow;
  final VoidCallback? onOpenAuthor;

  /// A member tagged in the words ("@Name") was tapped: gets their id.
  final ValueChanged<String>? onOpenMention;

  /// More beside Like and Reply (Accept answer).
  final List<Widget> actions;

  /// At the row's end, in place of the reaction disc (Accepted answer, Awaiting review).
  final Widget? badge;

  /// Under the words: the comment's attached file.
  final Widget? below;

  /// The comment a link named: tinted.
  final bool focused;
  final int? maxBodyLines;

  /// The clock the age reads against (a golden pins it).
  final DateTime? now;

  String? get _headline {
    final headline = reply.author.headline;
    if (headline != null && headline.trim().isNotEmpty) return headline.trim();
    final parts = [reply.role, reply.meta].whereType<String>().where((p) => p.trim().isNotEmpty).toList();
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final headline = _headline;
    final lead = replyingTo;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: focused
          ? BoxDecoration(color: CommentDesign.focusFill, borderRadius: BorderRadius.circular(8))
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onOpenAuthor,
            child: FeedAvatar(
              photo: reply.author.photo,
              initials: reply.author.initials,
              size: CommentDesign.avatar,
              label: reply.author.name,
            ),
          ),
          const SizedBox(width: CommentDesign.gap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onOpenAuthor,
                        child: Text(
                          reply.author.name,
                          style: CommentDesign.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${compactAge(reply.createdAt, now: now)}${reply.edited ? ' (edited)' : ''}',
                      style: CommentDesign.age,
                    ),
                    if (onFollow != null)
                      InkWell(
                        key: ValueKey('reply-follow:${reply.id}'),
                        onTap: onFollow,
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 2, 2, 2),
                          child: Text('Follow', style: CommentDesign.follow),
                        ),
                      ),
                    Semantics(
                      button: true,
                      label: 'Reply options',
                      excludeSemantics: true,
                      child: InkResponse(
                        key: ValueKey('reply-more:${reply.id}'),
                        onTap: onMore,
                        radius: 16,
                        child: const SizedBox(
                          width: 28,
                          height: 24,
                          child: Icon(Icons.more_vert, size: 20, color: HomeLook.soft),
                        ),
                      ),
                    ),
                  ],
                ),
                if (headline != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 28),
                    child: Text(headline, style: CommentDesign.headline, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: MentionText(
                    text: reply.body,
                    style: CommentDesign.body,
                    mentions: reply.mentions,
                    onOpen: onOpenMention,
                    maxLines: maxBodyLines,
                    overflow: maxBodyLines == null ? TextOverflow.clip : TextOverflow.ellipsis,
                    lead: lead == null
                        ? null
                        : TextSpan(
                            text: '$lead ',
                            style: CommentDesign.body.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontVariations: const [FontVariation('wght', 600)],
                            ),
                          ),
                  ),
                ),
                if (below != null) Padding(padding: const EdgeInsets.only(top: 6), child: below),
                SizedBox(
                  height: 34,
                  child: Row(
                    children: [
                      CommentAction(
                        key: ValueKey('reply-like:${reply.id}'),
                        // Filled once liked, as LinkedIn's (owner, 6 Nov 2026).
                        icon: reply.liked ? Icons.thumb_up : LucideIcons.thumbsUp,
                        count: reply.likes,
                        semantics: reply.liked ? 'Unlike' : 'Like',
                        active: reply.liked,
                        onTap: onLike,
                      ),
                      const SizedBox(width: 18),
                      CommentAction(
                        key: ValueKey('reply-reply:${reply.id}'),
                        icon: LucideIcons.messageSquareText,
                        count: replyCount,
                        semantics: 'Reply',
                        onTap: onReply,
                      ),
                      for (final action in actions) ...[const SizedBox(width: 14), action],
                      const Spacer(),
                      if (badge != null)
                        Flexible(flex: 0, child: badge!)
                      else if (reply.likes > 0)
                        const Padding(padding: EdgeInsets.only(right: 6), child: _ReactionDisc()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A glyph under a comment with its count beside it once there is one: like, reply.
class CommentAction extends StatelessWidget {
  const CommentAction({
    super.key,
    required this.icon,
    required this.count,
    required this.semantics,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final int count;
  final String semantics;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final tint = active ? AppColors.primary : HomeLook.soft;
    return Semantics(
      button: true,
      label: count > 0 ? '$semantics, $count' : semantics,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          height: 32,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: tint),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Text('$count', style: CommentDesign.count.copyWith(color: tint)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The small blue thumb at a liked comment's end.
class _ReactionDisc extends StatelessWidget {
  const _ReactionDisc();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: const Icon(Icons.thumb_up, size: 9, color: Colors.white),
    );
  }
}

/// How a list of comments is ordered.
enum CommentSort {
  relevant('Most Relevant'),
  recent('Most Recent');

  const CommentSort(this.label);

  final String label;

  /// [comments] in this order: the accepted answer first, then by likes and answers (relevant), or newest first.
  List<FeedReply> apply(List<FeedReply> comments) {
    final sorted = [...comments];
    if (this == CommentSort.recent) {
      sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return sorted;
    }
    int weight(FeedReply r) => r.likes * 2 + r.descendants.length;
    final at = {for (var i = 0; i < comments.length; i++) comments[i].id: i};
    sorted.sort((a, b) {
      if (a.accepted != b.accepted) return a.accepted ? -1 : 1;
      final byWeight = weight(b).compareTo(weight(a));
      return byWeight != 0 ? byWeight : at[a.id]!.compareTo(at[b.id]!);
    });
    return sorted;
  }
}

/// "Most relevant ▾": the order of the comments under it.
class CommentSortButton extends StatelessWidget {
  const CommentSortButton({super.key, required this.sort, required this.onChanged});

  final CommentSort sort;
  final ValueChanged<CommentSort> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<CommentSort>(
      key: const ValueKey('comments-sort'),
      initialValue: sort,
      onSelected: onChanged,
      position: PopupMenuPosition.under,
      color: Colors.white,
      itemBuilder: (_) => [
        for (final s in CommentSort.values)
          PopupMenuItem(
            value: s,
            height: 40,
            child: Text(s.label, style: CommentDesign.sort),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(sort.label, style: CommentDesign.sort),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 20, color: HomeLook.ink),
          ],
        ),
      ),
    );
  }
}
