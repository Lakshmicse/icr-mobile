import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/util/time_ago.dart';
import '../feed_models.dart';
import '../feed_styles.dart';
import 'feed_avatar.dart';
import 'poll_view.dart';

/// One discussion in the feed, drawn as a LinkedIn post: a white card with the author's 48 dp photo, name,
/// headline and age, the title and the first three lines of the words ("…more" opens the rest), the tags as
/// blue hashtags, the photos across the card, and one row of Like · Comment · Repost · Send, each with its count,
/// the reaction badges at the right.
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.commentsOpen,
    required this.onFollow,
    required this.onSave,
    required this.onMore,
    required this.onLike,
    required this.onComments,
    required this.onRepost,
    required this.onShare,
    required this.onVote,
    this.replies,
    this.afterPlacement = false,
    this.onOpen,
    this.onReactions,
    this.onPickReaction,
    this.onOpenAuthor,
    this.onTag,
  });

  final FeedPost post;
  final bool commentsOpen;
  final VoidCallback onFollow;
  final VoidCallback onSave;
  final VoidCallback onMore;
  final VoidCallback onLike;
  final VoidCallback onComments;
  final VoidCallback onRepost;
  final VoidCallback onShare;
  final ValueChanged<String> onVote;

  /// The open comment thread, drawn under the actions.
  final Widget? replies;

  /// Kept for callers; every card is spaced the same in this look.
  final bool afterPlacement;

  /// The title and the words open the discussion's page.
  final VoidCallback? onOpen;

  /// The reaction badges: who reacted.
  final VoidCallback? onReactions;

  /// Holding Like: pick another reaction. Gets the Like button's place on screen.
  final ValueChanged<Rect>? onPickReaction;

  /// The photo and the name: the author's profile.
  final VoidCallback? onOpenAuthor;

  /// A tag chip: show the discussions with that tag (without the "#"). Absent, the chips are plain.
  final ValueChanged<String>? onTag;

  @override
  Widget build(BuildContext context) {
    final poll = post.poll;
    return ColoredBox(
      color: HomeLook.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(HomeLook.pad, 12, HomeLook.pad, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PostHeader(
                  post: post,
                  onFollow: onFollow,
                  onSave: onSave,
                  onMore: onMore,
                  onOpenAuthor: onOpenAuthor,
                ),
                const SizedBox(height: 6),
                _Openable(
                  id: post.id,
                  onOpen: onOpen,
                  child: Text(post.title, style: poll != null ? HomeType.pollQuestion : HomeType.title),
                ),
                if (poll != null) ...[
                  if (post.body.isNotEmpty) ...[const SizedBox(height: 2), Text(post.body, style: HomeType.pollHint)],
                  const SizedBox(height: 10),
                  PollView(poll: poll, onVote: onVote, onViewDiscussion: onOpen ?? onComments),
                ] else ...[
                  if (post.body.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    _Openable(
                      id: '${post.id}-body',
                      onOpen: onOpen,
                      child: _ClampedText(text: post.body, style: HomeType.body, moreStyle: HomeType.more),
                    ),
                  ],
                  if (post.tags.isNotEmpty) ...[const SizedBox(height: 4), _Tags(tags: post.tags, onTag: onTag)],
                ],
              ],
            ),
          ),
          if (poll == null && post.images.isNotEmpty) ...[const SizedBox(height: 10), _PostImages(post: post)],
          _Footer(
            post: post,
            commentsOpen: commentsOpen,
            onLike: onLike,
            onComments: onComments,
            onRepost: onRepost,
            onShare: onShare,
            onPickReaction: onPickReaction,
            onReactions: onReactions,
          ),
          ?replies,
        ],
      ),
    );
  }
}

/// A card's title or words, tappable to open the discussion when the screen gives it a way to.
class _Openable extends StatelessWidget {
  const _Openable({required this.id, required this.onOpen, required this.child});

  final String id;
  final VoidCallback? onOpen;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (onOpen == null) return child;
    return GestureDetector(key: ValueKey('open:$id'), behavior: HitTestBehavior.opaque, onTap: onOpen, child: child);
  }
}

/// The first [maxLines] lines of a text, with "…more" closing the last line when there is more, as LinkedIn
/// cuts a post. A text that fits is drawn whole. Tapping "…more" opens the rest in place, in the feed itself; a tap
/// anywhere else on the words is the card's own (the discussion's page).
class _ClampedText extends StatefulWidget {
  const _ClampedText({required this.text, required this.style, required this.moreStyle});

  final String text;
  final TextStyle style;
  final TextStyle moreStyle;

  static const maxLines = 3;

  @override
  State<_ClampedText> createState() => _ClampedTextState();
}

class _ClampedTextState extends State<_ClampedText> {
  static const _more = '…more';

  bool _expanded = false;
  late final TapGestureRecognizer _open = TapGestureRecognizer()..onTap = () => setState(() => _expanded = true);

  @override
  void dispose() {
    _open.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.text;
    final style = widget.style;
    if (_expanded) return Text(text, key: const ValueKey('post-body-open'), style: style);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final scale = MediaQuery.textScalerOf(context);
        final whole = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: TextDirection.ltr,
          textScaler: scale,
          maxLines: _ClampedText.maxLines,
        )..layout(maxWidth: width);
        if (!whole.didExceedMaxLines) return Text(text, style: style);

        final tail = TextPainter(
          text: TextSpan(text: ' $_more', style: widget.moreStyle),
          textDirection: TextDirection.ltr,
          textScaler: scale,
        )..layout();
        final last = whole.computeLineMetrics().last;
        // The character under the point where "…more" has to start on the last line.
        final cut = whole.getPositionForOffset(Offset(width - tail.width - 1, last.baseline - 1)).offset;
        var head = text.substring(0, cut.clamp(0, text.length)).trimRight();
        final space = head.lastIndexOf(' ');
        if (space > head.length - 12 && space > 0) head = head.substring(0, space);
        return Text.rich(
          TextSpan(
            children: [
              TextSpan(text: head, style: style),
              TextSpan(text: ' $_more', style: widget.moreStyle, recognizer: _open),
            ],
          ),
          key: const ValueKey('post-body-more'),
          maxLines: _ClampedText.maxLines,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}

class _PostHeader extends StatelessWidget {
  const _PostHeader({
    required this.post,
    required this.onFollow,
    required this.onSave,
    required this.onMore,
    this.onOpenAuthor,
  });

  final FeedPost post;
  final VoidCallback onFollow;
  final VoidCallback onSave;
  final VoidCallback onMore;
  final VoidCallback? onOpenAuthor;

  @override
  Widget build(BuildContext context) {
    final author = post.author;
    final topic = post.topic;
    final headline = author.headline ?? '';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          key: ValueKey('author:${post.id}'),
          onTap: onOpenAuthor,
          child: FeedAvatar(photo: author.photo, initials: author.initials, size: 48, label: author.name),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LinkedIn's name line: the name, then "• Follow" in blue for someone the reader does not follow.
              Row(
                children: [
                  Flexible(
                    child: GestureDetector(
                      onTap: onOpenAuthor,
                      behavior: HitTestBehavior.opaque,
                      child: Text(author.name, style: HomeType.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  if (post.showFollow) ...[
                    Text('  •  ', style: HomeType.meta),
                    Semantics(
                      button: true,
                      label: 'Follow ${author.name}',
                      excludeSemantics: true,
                      child: GestureDetector(
                        key: ValueKey('follow:${post.id}'),
                        onTap: onFollow,
                        behavior: HitTestBehavior.opaque,
                        child: Text('Follow', style: HomeType.follow),
                      ),
                    ),
                  ],
                ],
              ),
              if (headline.isNotEmpty)
                Text(headline, style: HomeType.headline, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: timeAgo(post.createdAt)),
                    if (topic != null) ...[
                      const TextSpan(text: ' • '),
                      TextSpan(
                        text: topic,
                        style: HomeType.topic.copyWith(
                          color: post.topicTone == TopicTone.green ? AppColors.tertiary : HomeLook.blue,
                        ),
                      ),
                    ],
                  ],
                ),
                style: HomeType.meta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        _HeaderIcon(
          key: ValueKey('save:${post.id}'),
          icon: post.saved ? LucideIcons.bookmarkCheck : LucideIcons.bookmark,
          filled: post.saved,
          label: post.saved ? 'Remove bookmark' : 'Bookmark',
          onTap: onSave,
        ),
        _HeaderIcon(
          key: ValueKey('more:${post.id}'),
          icon: LucideIcons.ellipsisVertical,
          label: 'More options',
          onTap: onMore,
        ),
      ],
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({super.key, required this.icon, required this.label, required this.onTap, this.filled = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 20,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, size: 20, color: filled ? HomeLook.blue : HomeLook.soft),
            ),
          ),
        ),
      ),
    );
  }
}

/// The tags as blue hashtags on one line, wrapping when there are many.
class _Tags extends StatelessWidget {
  const _Tags({required this.tags, this.onTag});

  final List<String> tags;
  final ValueChanged<String>? onTag;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 2,
      children: [
        for (final tag in tags)
          GestureDetector(
            key: ValueKey('tag:$tag'),
            onTap: onTag == null ? null : () => onTag!(tag.startsWith('#') ? tag.substring(1) : tag),
            behavior: HitTestBehavior.opaque,
            child: Text(tag, style: HomeType.hashtag),
          ),
      ],
    );
  }
}

/// The photos, across the whole card, as LinkedIn lays a post's picture.
class _PostImages extends StatelessWidget {
  const _PostImages({required this.post});

  final FeedPost post;

  @override
  Widget build(BuildContext context) {
    final images = post.images;
    if (images.length == 1) {
      return AspectRatio(
        aspectRatio: 390 / 227,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _Picture(picture: images.first),
            if (post.imageCaption != null) Positioned(right: 12, bottom: 12, child: _Caption(text: post.imageCaption!)),
          ],
        ),
      );
    }
    return Row(
      children: [
        Expanded(child: _Tile(picture: images[0])),
        const SizedBox(width: 2),
        Expanded(
          child: _Tile(picture: images[1], more: images.length - 2 + post.morePhotos),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.picture, this.more = 0});

  final FeedPicture picture;
  final int more;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _Picture(picture: picture),
          if (more > 0) ...[
            const ColoredBox(color: AppColors.imageDim),
            Center(child: Text('+$more photos', style: HomeType.morePhotos)),
          ],
        ],
      ),
    );
  }
}

class _Picture extends StatelessWidget {
  const _Picture({required this.picture});

  final FeedPicture picture;

  @override
  Widget build(BuildContext context) {
    if (picture.asset != null) return Image.asset(picture.asset!, fit: BoxFit.cover);
    return CachedNetworkImage(
      imageUrl: picture.url!,
      fit: BoxFit.cover,
      placeholder: (_, _) => const ColoredBox(color: AppColors.surfaceContainer),
      errorWidget: (_, _, _) => const ColoredBox(color: AppColors.surfaceContainer),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    // rgba(38,49,67,.8) over a blur of the photo.
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
        child: Container(
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          color: AppColors.imageCaption,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.camera, size: 12.5, color: AppColors.onImage),
              const SizedBox(width: 4),
              Text(text, style: HomeType.imageCaption),
            ],
          ),
        ),
      ),
    );
  }
}

/// "1,284" for a count that reaches a thousand.
String groupedCount(int n) => n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

/// The glyph of each reaction (`FORUM_REACTION_META`), as the cards' stacks and the picker draw it.
IconData reactionIcon(ReactionKind kind) => switch (kind) {
  ReactionKind.like => LucideIcons.thumbsUp,
  ReactionKind.insightful => LucideIcons.lightbulb,
  ReactionKind.celebrate => LucideIcons.partyPopper,
  ReactionKind.support => LucideIcons.handHeart,
  ReactionKind.sustainable => LucideIcons.leaf,
};

/// The overlapping round badges of the kinds a discussion was reacted with, most used first.
class ReactionStack extends StatelessWidget {
  const ReactionStack({super.key, required this.kinds, this.size = 20, this.stepFactor = 0.8});

  final List<ReactionKind> kinds;
  final double size;

  /// How far each badge sits from the one before it, in badge widths (LinkedIn's card overlaps them by half).
  final double stepFactor;

  @override
  Widget build(BuildContext context) {
    final step = size * stepFactor;
    return SizedBox(
      width: size + step * (kinds.length - 1),
      height: size + 0.5,
      child: Stack(
        children: [
          for (var i = kinds.length - 1; i >= 0; i--)
            Positioned(
              left: step * i,
              top: 0.25,
              child: ReactionBadge(kind: kinds[i], size: size),
            ),
        ],
      ),
    );
  }
}

/// One reaction's round badge.
class ReactionBadge extends StatelessWidget {
  const ReactionBadge({super.key, required this.kind, this.size = 20});

  final ReactionKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color background, Color foreground) = switch (kind) {
      ReactionKind.like => (reactionIcon(kind), AppColors.primary, Colors.white),
      ReactionKind.insightful => (reactionIcon(kind), AppColors.tertiary, Colors.white),
      ReactionKind.celebrate => (reactionIcon(kind), AppColors.tertiaryContainer, AppColors.tertiary),
      ReactionKind.support => (reactionIcon(kind), const Color(0xFFF59E0B), Colors.white),
      ReactionKind.sustainable => (reactionIcon(kind), const Color(0xFF2D6A4C), Colors.white),
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: Icon(icon, size: size * 0.575, color: foreground),
    );
  }
}

/// LinkedIn's one-row footer: Like, Comment, Repost and Send as 24 dp outlined glyphs, each with its count in
/// 12.5 sp where it has one, and the reaction badges at the right edge. Grey until on.
class _Footer extends StatelessWidget {
  const _Footer({
    required this.post,
    required this.commentsOpen,
    required this.onLike,
    required this.onComments,
    required this.onRepost,
    required this.onShare,
    this.onPickReaction,
    this.onReactions,
  });

  final FeedPost post;
  final bool commentsOpen;
  final VoidCallback onLike;
  final VoidCallback onComments;
  final VoidCallback onRepost;
  final VoidCallback onShare;
  final ValueChanged<Rect>? onPickReaction;
  final VoidCallback? onReactions;

  static String? _count(int? n) => n == null || n <= 0 ? null : groupedCount(n);

  @override
  Widget build(BuildContext context) {
    final mine = post.myReaction;
    final kinds = post.reactionKinds;
    final badges = kinds.isEmpty ? null : ReactionStack(kinds: kinds.take(3).toList(), size: 18, stepFactor: 0.55);
    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.only(left: 6, right: HomeLook.pad, top: 4),
        child: Row(
          children: [
            _Action(
              key: ValueKey('like:${post.id}'),
              icon: reactionIcon(mine ?? ReactionKind.like),
              count: _count(post.reactions),
              label: mine != null ? 'Unlike' : 'Like',
              active: mine != null,
              onTap: onLike,
              onHold: onPickReaction,
            ),
            _Action(
              key: ValueKey('comments:${post.id}'),
              icon: LucideIcons.messageSquareText,
              count: _count(post.comments),
              label: commentsOpen ? 'Hide comments' : 'Comments',
              active: commentsOpen,
              onTap: onComments,
            ),
            _Action(
              key: ValueKey('repost:${post.id}'),
              icon: LucideIcons.repeat2,
              count: _count(post.shares),
              label: 'Repost',
              onTap: onRepost,
            ),
            _Action(key: ValueKey('share:${post.id}'), icon: LucideIcons.send, label: 'Share', onTap: onShare),
            const Spacer(),
            if (badges != null)
              if (onReactions != null && post.reactions > 0)
                Semantics(
                  button: true,
                  label: 'Who reacted',
                  excludeSemantics: true,
                  child: GestureDetector(
                    key: ValueKey('reactions:${post.id}'),
                    onTap: onReactions,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: badges),
                  ),
                )
              else
                badges,
          ],
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.count,
    this.active = false,
    this.onHold,
  });

  final IconData icon;

  /// What the button is for a screen reader.
  final String label;
  final VoidCallback onTap;

  /// The number beside the glyph, when there is one.
  final String? count;
  final bool active;

  /// Holding the button: gets the button's place on screen.
  final ValueChanged<Rect>? onHold;

  @override
  Widget build(BuildContext context) {
    final color = active ? HomeLook.blue : HomeLook.soft;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        onLongPress: onHold == null
            ? null
            : () {
                final box = context.findRenderObject() as RenderBox?;
                if (box == null || !box.hasSize) return;
                onHold!(box.localToGlobal(Offset.zero) & box.size);
              },
        radius: 28,
        containedInkWell: true,
        highlightShape: BoxShape.rectangle,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 24, color: color),
                if (count != null) ...[
                  const SizedBox(width: 6),
                  Text(count!, style: HomeType.count.copyWith(color: color)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
