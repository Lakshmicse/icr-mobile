import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/util/time_ago.dart';
import '../../forum/mentions/mention_widgets.dart';
import '../../forum/widgets/forum_bits.dart' show ForumPicture;
import '../feed_models.dart';
import '../feed_styles.dart';
import 'feed_avatar.dart';
import 'post_card.dart';

/// What the photo viewer reads and does, handed over by the screen that opens it (the Home feed, the Forums tab).
/// Every action gets a context inside the viewer, so a message or a menu it shows lands over the photos.
class PhotoViewerHost {
  const PhotoViewerHost({
    required this.listenable,
    required this.post,
    required this.onLike,
    required this.onComments,
    required this.onRepost,
    required this.onShare,
    this.onPickReaction,
    this.onMore,
    this.onFollow,
    this.onOpenAuthor,
    this.onOpenMention,
    this.now,
  });

  /// Tells the viewer the post changed (a like landed, a comment was counted).
  final Listenable listenable;

  /// The post as it is now; null once it has gone.
  final FeedPost? Function() post;

  final void Function(BuildContext viewer) onLike;

  /// Holding Like: gets the button's place on screen, for the reactions.
  final void Function(BuildContext viewer, Rect anchor)? onPickReaction;
  final void Function(BuildContext viewer) onComments;
  final void Function(BuildContext viewer) onRepost;
  final void Function(BuildContext viewer) onShare;

  /// The three dots: the post's own menu.
  final void Function(BuildContext viewer)? onMore;

  /// "Follow" beside the name, for someone the reader does not follow.
  final void Function(BuildContext viewer)? onFollow;

  /// The author's photo and name.
  final VoidCallback? onOpenAuthor;

  /// A member tagged in the words: gets their id.
  final ValueChanged<String>? onOpenMention;

  /// The clock the age reads against (a golden pins it).
  final DateTime? now;
}

/// The viewer's own colours: LinkedIn's dark photo page, whatever the app's theme.
abstract final class PhotoViewerLook {
  static const page = Color(0xFF000000);
  static const panel = Color(0xFF1B1F23);
  static const ink = Color(0xFFFFFFFF);
  static const soft = Color(0xB3FFFFFF);
  static const follow = Color(0xFF71B7FB);
  static const shadow = [Shadow(color: Color(0x99000000), blurRadius: 6)];
}

/// Opens a post's photos full screen, as LinkedIn does (owner, 14 Nov 2026): a dark page with the photos to swipe
/// through and dots counting them, Like, Comment and Repost with their numbers down the right edge, and under the
/// photo the author, Send, the start of the post's words with "…more" (which opens them whole in a sheet) and the
/// three dots. [initial] is the photo shown first.
Future<void> showPostPhotoViewer(BuildContext context, {required PhotoViewerHost host, int initial = 0}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => PostPhotoViewer(host: host, initial: initial),
    ),
  );
}

class PostPhotoViewer extends StatefulWidget {
  const PostPhotoViewer({super.key, required this.host, this.initial = 0});

  final PhotoViewerHost host;
  final int initial;

  @override
  State<PostPhotoViewer> createState() => _PostPhotoViewerState();
}

class _PostPhotoViewerState extends State<PostPhotoViewer> {
  late final PageController _pages = PageController(initialPage: widget.initial);
  late int _index = widget.initial;

  /// The post as last read: drawn while it is gone for a moment (the feed reading again).
  FeedPost? _last;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  static String? _count(int? n) => n == null || n <= 0 ? null : groupedCount(n);

  @override
  Widget build(BuildContext context) {
    final host = widget.host;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: PhotoViewerLook.panel,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: PhotoViewerLook.page,
        body: Builder(
          builder: (viewer) => ListenableBuilder(
            listenable: host.listenable,
            builder: (context, _) {
              final post = _last = host.post() ?? _last;
              return Column(
                children: [
                  Expanded(child: _photos(viewer, post)),
                  if (post != null) _Panel(host: host, post: post, viewer: viewer),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _photos(BuildContext viewer, FeedPost? post) {
    final host = widget.host;
    final photos = post?.images ?? const <FeedPicture>[];
    final at = photos.isEmpty ? 0 : _index.clamp(0, photos.length - 1);
    final mine = post?.myReaction;
    return Stack(
      children: [
        if (photos.isNotEmpty)
          Positioned.fill(
            child: PageView.builder(
              key: const ValueKey('viewer-pages'),
              controller: _pages,
              itemCount: photos.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) => InteractiveViewer(
                maxScale: 5,
                child: SizedBox.expand(
                  child: ForumPicture(key: ValueKey('viewer-photo:$i'), picture: photos[i], fit: BoxFit.contain),
                ),
              ),
            ),
          ),
        // The back arrow reads over a pale photo too.
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 112,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xB3000000), Color(0x00000000)],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 4,
          child: SafeArea(
            bottom: false,
            child: IconButton(
              key: const ValueKey('viewer-back'),
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(LucideIcons.arrowLeft, size: 26, color: PhotoViewerLook.ink),
            ),
          ),
        ),
        if (photos.length > 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: 10,
            child: IgnorePointer(
              child: _Dots(count: photos.length, index: at),
            ),
          ),
        if (post != null)
          Positioned(
            right: 6,
            bottom: 22,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SideAction(
                  key: const ValueKey('viewer-like'),
                  glyph: mine == null
                      ? null
                      : ReactionBadge(key: const ValueKey('viewer-my-reaction'), kind: mine, size: 30),
                  icon: reactionIcon(ReactionKind.like),
                  count: _count(post.reactions),
                  label: mine != null ? 'Unlike' : 'Like',
                  onTap: () => host.onLike(viewer),
                  onHold: host.onPickReaction == null ? null : (rect) => host.onPickReaction!(viewer, rect),
                ),
                _SideAction(
                  key: const ValueKey('viewer-comments'),
                  icon: LucideIcons.messageSquareText,
                  count: _count(post.comments),
                  label: 'Comments',
                  onTap: () => host.onComments(viewer),
                ),
                _SideAction(
                  key: const ValueKey('viewer-repost'),
                  icon: LucideIcons.repeat2,
                  count: _count(post.shares),
                  label: 'Repost',
                  onTap: () => host.onRepost(viewer),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// One dot a photo, the one shown drawn as a longer pill.
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Photo ${index + 1} of $count',
      child: Row(
        key: const ValueKey('viewer-dots'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              key: ValueKey('viewer-dot:$i'),
              duration: const Duration(milliseconds: 160),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == index ? 20 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: i == index ? PhotoViewerLook.ink : const Color(0x80FFFFFF),
                borderRadius: BorderRadius.circular(4),
                boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 3)],
              ),
            ),
        ],
      ),
    );
  }
}

/// A button on the photo's right edge: its glyph with the number under it.
class _SideAction extends StatelessWidget {
  const _SideAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.count,
    this.glyph,
    this.onHold,
  });

  final IconData icon;

  /// Drawn in place of [icon]: the reader's own reaction, as its badge.
  final Widget? glyph;
  final String label;
  final String? count;
  final VoidCallback onTap;

  /// Holding the button: gets its place on screen.
  final ValueChanged<Rect>? onHold;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: count == null ? label : '$label, $count',
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
        radius: 30,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 52, minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                glyph ?? Icon(icon, size: 30, color: PhotoViewerLook.ink, shadows: PhotoViewerLook.shadow),
                if (count != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    count!,
                    style: HomeType.name.copyWith(
                      fontSize: 14,
                      height: 18 / 14,
                      color: PhotoViewerLook.ink,
                      shadows: PhotoViewerLook.shadow,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Under the photo: the author and Send, then the start of the post's words with "…more" and the three dots.
class _Panel extends StatelessWidget {
  const _Panel({required this.host, required this.post, required this.viewer});

  final PhotoViewerHost host;
  final FeedPost post;
  final BuildContext viewer;

  /// The post's words as the viewer starts them: its title, then what it says.
  static String wordsOf(FeedPost post) =>
      [post.title.trim(), post.body.trim()].where((part) => part.isNotEmpty).join('\n');

  @override
  Widget build(BuildContext context) {
    final author = post.author;
    final headline = author.headline ?? '';
    final words = wordsOf(post);
    final more = host.onMore == null
        ? null
        : IconButton(
            key: const ValueKey('viewer-more'),
            tooltip: 'More options',
            visualDensity: VisualDensity.compact,
            onPressed: () => host.onMore!(viewer),
            icon: const Icon(LucideIcons.ellipsis, size: 24, color: PhotoViewerLook.ink),
          );
    return ColoredBox(
      color: PhotoViewerLook.panel,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 6, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  GestureDetector(
                    key: const ValueKey('viewer-author'),
                    onTap: host.onOpenAuthor,
                    child: FeedAvatar(photo: author.photo, initials: author.initials, size: 40, label: author.name),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: GestureDetector(
                                onTap: host.onOpenAuthor,
                                behavior: HitTestBehavior.opaque,
                                child: Text(
                                  author.name,
                                  style: HomeType.name.copyWith(color: PhotoViewerLook.ink),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            if (post.showFollow && host.onFollow != null) ...[
                              Text('  •  ', style: HomeType.meta.copyWith(color: PhotoViewerLook.soft)),
                              Semantics(
                                button: true,
                                label: 'Follow ${author.name}',
                                excludeSemantics: true,
                                child: GestureDetector(
                                  key: const ValueKey('viewer-follow'),
                                  onTap: () => host.onFollow!(viewer),
                                  behavior: HitTestBehavior.opaque,
                                  child: Text('Follow', style: HomeType.follow.copyWith(color: PhotoViewerLook.follow)),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (headline.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              headline,
                              style: HomeType.headline.copyWith(color: PhotoViewerLook.soft),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('viewer-share'),
                    tooltip: 'Share',
                    onPressed: () => host.onShare(viewer),
                    icon: const Icon(LucideIcons.send, size: 26, color: PhotoViewerLook.ink),
                  ),
                ],
              ),
              if (words.isNotEmpty || more != null) ...[
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: words.isEmpty
                          ? const SizedBox.shrink()
                          : Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: ClampedText(
                                key: const ValueKey('viewer-words'),
                                text: words,
                                style: HomeType.body.copyWith(
                                  fontSize: 15,
                                  height: 20 / 15,
                                  color: PhotoViewerLook.ink,
                                ),
                                moreStyle: HomeType.more.copyWith(
                                  fontSize: 15,
                                  height: 20 / 15,
                                  color: PhotoViewerLook.soft,
                                ),
                                maxLines: 2,
                                mentions: post.mentions,
                                onOpenMention: host.onOpenMention,
                                onMore: () => showPostTextSheet(
                                  viewer,
                                  post: post,
                                  onOpenMention: host.onOpenMention,
                                  now: host.now,
                                ),
                              ),
                            ),
                    ),
                    ?more,
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The post's words, whole, in a sheet over the photos (LinkedIn's "…more" in its photo viewer): when it was posted
/// and under what, its title, what it says with its tagged members and links, and its tags. The sheet is as tall as
/// the words, up to most of the screen, where they scroll.
Future<void> showPostTextSheet(
  BuildContext context, {
  required FeedPost post,
  ValueChanged<String>? onOpenMention,
  DateTime? now,
}) {
  final topic = post.topic;
  final title = post.title.trim();
  final body = post.body.trim();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheet) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * 0.83),
      child: Material(
        key: const ValueKey('post-text-sheet'),
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 4),
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(color: const Color(0xFF1F1F1F), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  key: const ValueKey('post-text-scroll'),
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: timeAgo(post.createdAt, now: now)),
                            if (topic != null) ...[
                              const TextSpan(text: ' • '),
                              TextSpan(text: topic, style: HomeType.topic),
                            ],
                          ],
                        ),
                        style: HomeType.meta,
                      ),
                      if (title.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          title,
                          key: const ValueKey('post-text-title'),
                          style: HomeType.title.copyWith(fontSize: 16, height: 22 / 16),
                        ),
                      ],
                      if (body.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        MentionText(
                          key: const ValueKey('post-text-body'),
                          text: body,
                          style: HomeType.body.copyWith(fontSize: 15, height: 22 / 15),
                          mentions: post.mentions,
                          onOpen: onOpenMention,
                        ),
                      ],
                      if (post.tags.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 2,
                          children: [for (final tag in post.tags) Text(tag, style: HomeType.hashtag)],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
