import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/util/link_spans.dart';
import '../../../core/util/time_ago.dart';
import '../../forum/mentions/mention_text.dart';
import '../../forum/mentions/mention_widgets.dart';
import '../feed_models.dart';
import '../feed_styles.dart';
import '../repost_quote.dart';
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
    this.onOpenMention,
    this.isOwn = false,
    this.onVoters,
    this.quotedLoader,
    this.onQuotedVote,
    this.onOpenQuoted,
    this.onOpenVideo,
  });

  /// A video tile, tapped: gets the video's URL to play.
  final ValueChanged<String>? onOpenVideo;

  /// Reads the discussion a repost quotes (by slug), so the original is drawn inside the repost with its photos
  /// and poll (owner, 11 Nov 2026); absent, the repost's words show the quote as text.
  final Future<FeedPost?> Function(String slug)? quotedLoader;

  /// A vote on the quoted original's poll.
  final void Function(FeedPost original, String optionId)? onQuotedVote;

  /// The quoted original, tapped: its discussion.
  final ValueChanged<FeedPost>? onOpenQuoted;

  /// A member tagged in the words ("@Name") was tapped: gets their id. Absent, the names are plain.
  final ValueChanged<String>? onOpenMention;

  /// "N votes" under a poll: who voted and for what.
  final VoidCallback? onVoters;

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

  /// The reader wrote this post: a poll of theirs shows its results and takes no vote from them.
  final bool isOwn;

  /// The photo and the name: the author's profile.
  final VoidCallback? onOpenAuthor;

  /// A tag chip: show the discussions with that tag (without the "#"). Absent, the chips are plain.
  final ValueChanged<String>? onTag;

  @override
  Widget build(BuildContext context) {
    final poll = post.poll;
    // A repost's quote lines are drawn as the original itself when the screen can read it; the words left are
    // the reposter's own.
    final quote = quotedLoader == null ? null : RepostQuote.of(post.body);
    final body = quote == null ? post.body : quote.rest;
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
                _PostHeader(post: post, onFollow: onFollow, onSave: onSave, onMore: onMore, onOpenAuthor: onOpenAuthor),
                const SizedBox(height: 6),
                _Openable(
                  id: post.id,
                  onOpen: onOpen,
                  child: MentionText(text: post.title, style: poll != null ? HomeType.pollQuestion : HomeType.title),
                ),
                if (poll != null) ...[
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    MentionText(text: body, style: HomeType.pollHint, mentions: post.mentions, onOpen: onOpenMention),
                  ],
                  const SizedBox(height: 10),
                  PollView(
                    poll: poll,
                    isAuthor: isOwn,
                    onVote: onVote,
                    onVoters: onVoters,
                    onViewDiscussion: onOpen ?? onComments,
                  ),
                ] else ...[
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    _Openable(
                      id: '${post.id}-body',
                      onOpen: onOpen,
                      child: _ClampedText(
                        text: body,
                        style: HomeType.body,
                        moreStyle: HomeType.more,
                        mentions: post.mentions,
                        onOpenMention: onOpenMention,
                      ),
                    ),
                  ],
                  if (quote != null) ...[
                    const SizedBox(height: 8),
                    _QuotedPost(
                      quote: quote,
                      loader: quotedLoader!,
                      onVote: onQuotedVote,
                      onOpen: onOpenQuoted,
                      onOpenVideo: onOpenVideo,
                    ),
                  ],
                  if (post.tags.isNotEmpty) ...[const SizedBox(height: 4), _Tags(tags: post.tags, onTag: onTag)],
                ],
              ],
            ),
          ),
          // The quoted original carries its own photos; a repost's copy of them is not drawn twice.
          if (poll == null && quote == null && (post.images.isNotEmpty || post.videos.isNotEmpty)) ...[
            const SizedBox(height: 10),
            _PostImages(post: post, onOpenVideo: onOpenVideo),
          ],
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

/// The discussion a repost quotes, drawn inside the repost as LinkedIn draws a shared post: a hairline box with the
/// original's author, title, words, photos and poll, read by [loader]; a tap opens the original, and a vote on its
/// poll is cast on the original. Until it is read, or when it is gone, the box carries the quote's author and title.
class _QuotedPost extends StatelessWidget {
  const _QuotedPost({required this.quote, required this.loader, this.onVote, this.onOpen, this.onOpenVideo});

  final RepostQuote quote;
  final Future<FeedPost?> Function(String slug) loader;
  final void Function(FeedPost original, String optionId)? onVote;
  final ValueChanged<FeedPost>? onOpen;
  final ValueChanged<String>? onOpenVideo;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FeedPost?>(
      future: loader(quote.slug),
      builder: (context, snap) {
        final original = snap.data;
        return Semantics(
          button: original != null && onOpen != null,
          label: 'Reposted from ${quote.author}: ${quote.title}',
          // No box around the original (owner, 12 Nov 2026: "Remove the border like this?"): a hairline above it
          // marks where the repost's own words end, as the rest of the feed draws its rules.
          child: Material(
            color: HomeLook.card,
            shape: const Border(top: BorderSide(color: HomeLook.hairline)),
            child: InkWell(
              key: ValueKey('quoted:${quote.slug}'),
              onTap: original == null || onOpen == null ? null : () => onOpen!(original),
              child: original == null ? _quoteOnly() : _original(original),
            ),
          ),
        );
      },
    );
  }

  Widget _quoteOnly() => Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reposted from ${quote.author}', style: HomeType.meta),
        const SizedBox(height: 4),
        Text(quote.title, style: HomeType.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      ],
    ),
  );

  Widget _original(FeedPost o) {
    final poll = o.poll;
    final headline = o.author.headline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  FeedAvatar(photo: o.author.photo, initials: o.author.initials, size: 32, label: o.author.name),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          o.author.name,
                          style: HomeType.name.copyWith(fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (headline != null && headline.isNotEmpty)
                          Text(headline, style: HomeType.headline, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(o.title, style: HomeType.title, maxLines: 3, overflow: TextOverflow.ellipsis),
              if (o.body.isNotEmpty && poll == null) ...[
                const SizedBox(height: 2),
                Text(o.body, style: HomeType.body, maxLines: 3, overflow: TextOverflow.ellipsis),
              ],
              if (poll != null) ...[
                const SizedBox(height: 8),
                PollView(
                  poll: poll,
                  showLink: false,
                  onVote: (option) => onVote?.call(o, option),
                  onViewDiscussion: () => onOpen?.call(o),
                ),
              ],
            ],
          ),
        ),
        if (poll == null && (o.images.isNotEmpty || o.videos.isNotEmpty)) ...[
          const SizedBox(height: 10),
          _PostImages(post: o, onOpenVideo: onOpenVideo),
        ],
        const SizedBox(height: 12),
      ],
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
  const _ClampedText({
    required this.text,
    required this.style,
    required this.moreStyle,
    this.mentions = const [],
    this.onOpenMention,
  });

  final String text;
  final TextStyle style;
  final TextStyle moreStyle;

  /// The members tagged in [text], whose "@Name" opens their profile through [onOpenMention].
  final List<Mention> mentions;
  final ValueChanged<String>? onOpenMention;

  static const maxLines = 3;

  @override
  State<_ClampedText> createState() => _ClampedTextState();
}

class _ClampedTextState extends State<_ClampedText> {
  static const _more = '…more';

  bool _expanded = false;
  late final TapGestureRecognizer _open = TapGestureRecognizer()..onTap = () => setState(() => _expanded = true);
  final _mentions = MentionSpans();
  final _links = LinkSpans();

  @override
  void dispose() {
    _open.dispose();
    _mentions.dispose();
    _links.dispose();
    super.dispose();
  }

  /// [text] cut back to before the address its end falls inside, or null when it ends outside any: a cut link
  /// would open half an address.
  static String? _beforeCutLink(String text, String head) {
    var at = 0;
    for (final part in splitLinks(text)) {
      final end = at + part.text.length;
      if (part.link != null && at < head.length && end > head.length) return text.substring(0, at).trimRight();
      at = end;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    _mentions.clear();
    _links.clear();
    final text = widget.text;
    final style = widget.style;
    final tagged = widget.onOpenMention != null && widget.mentions.isNotEmpty;
    final linked = tagged || LinkSpans.hasLink(text);
    // Placed once on the whole text, so a namesake is told apart by order; a cut keeps those inside it.
    final found = tagged ? mentionSpans(text, widget.mentions) : const <MentionSpan>[];

    // [part] is the text or a start of it: its web addresses open (the ICR ones in the app), its tagged members open
    // their profile.
    List<InlineSpan> spansOf(String part) {
      final inPart = [
        for (final m in found)
          if (m.end <= part.length) m,
      ];
      List<InlineSpan> plain(String run, List<MentionSpan> mentions) =>
          tagged ? _mentions.spansFor(run, mentions, onOpen: widget.onOpenMention) : [TextSpan(text: run)];
      if (!LinkSpans.hasLink(part)) return plain(part, inPart);
      final starts = <int>[];
      var at = 0;
      for (final p in splitLinks(part)) {
        if (p.link == null) starts.add(at);
        at += p.text.length;
      }
      var run = 0;
      return _links.build(
        context,
        part,
        plain: (r) {
          final from = starts[run++];
          return plain(r, [
            for (final m in inPart)
              if (m.start >= from && m.end <= from + r.length)
                (start: m.start - from, end: m.end - from, mention: m.mention),
          ]);
        },
      );
    }

    if (_expanded) {
      if (!linked) return Text(text, key: const ValueKey('post-body-open'), style: style);
      return Text.rich(
        TextSpan(style: style, children: spansOf(text)),
        key: const ValueKey('post-body-open'),
      );
    }
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
        if (!whole.didExceedMaxLines) {
          return linked ? Text.rich(TextSpan(style: style, children: spansOf(text))) : Text(text, style: style);
        }

        final tail = TextPainter(
          text: TextSpan(text: ' $_more', style: widget.moreStyle),
          textDirection: TextDirection.ltr,
          textScaler: scale,
        )..layout();
        final last = whole.computeLineMetrics().last;
        // The character under the point where "…more" has to start on the last line.
        final cut = whole.getPositionForOffset(Offset(width - tail.width - 1, last.baseline - 1)).offset;
        var head = text.substring(0, cut.clamp(0, text.length)).trimRight();
        final beforeLink = _beforeCutLink(text, head);
        if (beforeLink != null) {
          head = beforeLink;
        } else {
          final space = head.lastIndexOf(' ');
          if (space > head.length - 12 && space > 0) head = head.substring(0, space);
        }
        return Text.rich(
          TextSpan(
            children: [
              TextSpan(style: style, children: spansOf(head)),
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

/// The photos and videos, across the whole card, as LinkedIn lays a post's media: one alone fills the width, more
/// sit two across with "+N" on the second; a video tile carries a play glyph and opens the player.
class _PostImages extends StatelessWidget {
  const _PostImages({required this.post, this.onOpenVideo});

  final FeedPost post;
  final ValueChanged<String>? onOpenVideo;

  @override
  Widget build(BuildContext context) {
    final media = <_Media>[
      for (final i in post.images) _Media(picture: i),
      for (final v in post.videos) _Media(video: v),
    ];
    if (media.length == 1) {
      final m = media.first;
      return AspectRatio(
        aspectRatio: 390 / 227,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _MediaView(media: m, onOpenVideo: onOpenVideo),
            if (m.picture != null && post.imageCaption != null)
              Positioned(right: 12, bottom: 12, child: _Caption(text: post.imageCaption!)),
          ],
        ),
      );
    }
    final more = media.length - 2 + post.morePhotos;
    return Row(
      children: [
        Expanded(
          child: _Tile(media: media[0], onOpenVideo: onOpenVideo),
        ),
        const SizedBox(width: 2),
        Expanded(
          child: _Tile(
            media: media[1],
            more: more,
            moreLabel: post.videos.isEmpty ? '+$more photos' : '+$more more',
            onOpenVideo: onOpenVideo,
          ),
        ),
      ],
    );
  }
}

/// One thing on a card: a photo, or a video (its URL).
class _Media {
  const _Media({this.picture, this.video});

  final FeedPicture? picture;
  final String? video;
}

/// A photo as it is, or a video's dark tile with a play glyph that opens the player.
class _MediaView extends StatelessWidget {
  const _MediaView({required this.media, this.onOpenVideo});

  final _Media media;
  final ValueChanged<String>? onOpenVideo;

  @override
  Widget build(BuildContext context) {
    final video = media.video;
    if (video == null) return _Picture(picture: media.picture!);
    return Semantics(
      button: true,
      label: 'Play video',
      child: GestureDetector(
        key: ValueKey('post-video:$video'),
        behavior: HitTestBehavior.opaque,
        onTap: onOpenVideo == null ? null : () => onOpenVideo!(video),
        child: const ColoredBox(
          color: Color(0xFF1F1F1F),
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(color: Color(0xE6FFFFFF), shape: BoxShape.circle),
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Icon(LucideIcons.play, size: 28, color: Color(0xFF1F1F1F)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.media, this.more = 0, this.moreLabel = '', this.onOpenVideo});

  final _Media media;
  final int more;
  final String moreLabel;
  final ValueChanged<String>? onOpenVideo;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _MediaView(media: media, onOpenVideo: onOpenVideo),
          if (more > 0) ...[
            const ColoredBox(color: AppColors.imageDim),
            Center(child: Text(moreLabel, style: HomeType.morePhotos)),
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

/// The glyph of each reaction (`FORUM_REACTION_META`), as the cards' stacks and the picker draw it; [filled] is the
/// solid glyph a card's own button shows once the reader has reacted, as LinkedIn fills its Like (owner, 6 Nov 2026).
IconData reactionIcon(ReactionKind kind, {bool filled = false}) => switch (kind) {
  ReactionKind.like => filled ? Icons.thumb_up : LucideIcons.thumbsUp,
  ReactionKind.insightful => filled ? Icons.lightbulb : LucideIcons.lightbulb,
  ReactionKind.celebrate => filled ? Icons.celebration : LucideIcons.partyPopper,
  ReactionKind.support => filled ? Icons.volunteer_activism : LucideIcons.handHeart,
  ReactionKind.sustainable => filled ? Icons.eco : LucideIcons.leaf,
};

/// The colour of the count or word beside the reader's own reaction: its badge's colour, darkened where the badge
/// is too pale to read as text.
Color reactionInk(ReactionKind kind) => switch (kind) {
  ReactionKind.like => AppColors.primary,
  ReactionKind.insightful => AppColors.tertiary,
  ReactionKind.celebrate => AppColors.tertiary,
  ReactionKind.support => const Color(0xFFB45309),
  ReactionKind.sustainable => const Color(0xFF2D6A4C),
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
              icon: reactionIcon(ReactionKind.like),
              // Once the reader has reacted the button is that reaction as the picker drew it, its round badge
              // (owner, 13 Nov 2026: "same to same ... not the blue colored icon").
              glyph: mine == null ? null : ReactionBadge(key: ValueKey('my-reaction:${post.id}'), kind: mine, size: 24),
              ink: mine == null ? null : reactionInk(mine),
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
    this.glyph,
    this.ink,
  });

  final IconData icon;

  /// Drawn in place of [icon]: the reader's own reaction, as its badge.
  final Widget? glyph;

  /// The count's colour when [glyph] is drawn.
  final Color? ink;

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
    final color = ink ?? (active ? HomeLook.blue : HomeLook.soft);
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
                glyph ?? Icon(icon, size: 24, color: color),
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
