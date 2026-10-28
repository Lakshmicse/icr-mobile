import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart';
import '../forum/forum_callbacks.dart';
import '../forum/forum_flows.dart';
import '../forum/repost.dart';
import '../forum/thread_screen.dart';
import '../forum/widgets/forum_sheets.dart';
import 'feed_controller.dart';
import 'feed_models.dart';
import 'feed_styles.dart';
import 'widgets/composer_and_filters.dart';
import 'widgets/home_header.dart';
import 'widgets/post_card.dart';
import 'widgets/reply_thread.dart';
import 'widgets/sponsored_card.dart';

/// The Home feed.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.viewer, required this.onAccount, this.callbacks = const ForumCallbacks()});

  /// The signed-in person, as the feed draws them (header photo, reply box).
  final FeedAuthor viewer;
  final VoidCallback onAccount;

  /// What a discussion's page, opened from a card, asks the app to do (a member's profile, the bell, a tag).
  final ForumCallbacks callbacks;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 600) context.read<FeedController>().loadMore();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String?> action) async {
    final message = await action;
    if (message != null && mounted) showMessage(context, message);
  }

  /// The three dots on a post, or on a reply: open the discussion, copy its link, report it (not one's own), and
  /// take back a reply of one's own.
  void _menu(
    Uri link, {
    required String title,
    required VoidCallback onOpen,
    VoidCallback? onReport,
    VoidCallback? onDelete,
  }) {
    showActionSheet(
      context,
      title: title,
      actions: [
        SheetAction(
          key: const ValueKey('menu-open'),
          label: 'Open discussion',
          icon: Symbols.open_in_full,
          onTap: onOpen,
        ),
        SheetAction(
          key: const ValueKey('menu-copy'),
          label: 'Copy link',
          icon: Symbols.link,
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: link.toString()));
            if (mounted) showMessage(context, 'Link copied');
          },
        ),
        if (onReport != null)
          SheetAction(key: const ValueKey('menu-report'), label: 'Report', icon: Symbols.flag, onTap: onReport),
        if (onDelete != null)
          SheetAction(
            key: const ValueKey('menu-delete'),
            label: 'Delete reply',
            icon: Symbols.delete,
            destructive: true,
            onTap: onDelete,
          ),
      ],
    );
  }

  void _postMenu(FeedPost post) => _menu(
    context.read<FeedController>().repository.link(post),
    title: post.title,
    onOpen: () => _openThread(post),
    onReport: post.author.id == widget.viewer.id ? null : () => _report(post),
  );

  void _replyMenu(FeedPost post, FeedReply reply) {
    final feed = context.read<FeedController>();
    final own = reply.author.id == widget.viewer.id;
    _menu(
      feed.repository.link(post, reply: reply),
      title: reply.author.name,
      onOpen: () => _openThread(post, reply: reply),
      onReport: own ? null : () => _report(post, reply: reply),
      onDelete: own ? () => _confirmDelete(post, reply) : null,
    );
  }

  /// Flags a discussion, or one of its replies, for the moderators (the same sheet as the discussion's page).
  Future<void> _report(FeedPost post, {FeedReply? reply}) async {
    final forum = context.read<FeedController>().repository.forum;
    final sent = await showReportSheet(
      context,
      reply: reply != null,
      onSend: (reason, note) async {
        try {
          await forum.report(threadId: reply == null ? post.id : null, replyId: reply?.id, reason: reason, note: note);
          return null;
        } catch (e) {
          return e.toString();
        }
      },
    );
    if (sent && mounted) showMessage(context, 'Thanks. A moderator will take a look.');
  }

  /// "Post a requirement or insight...": the composer, then the new discussion's page; the feed reads again so
  /// the new card is at its top.
  Future<void> _compose() async {
    final feed = context.read<FeedController>();
    final saved = await startDiscussion(
      context,
      repository: feed.repository.forum,
      viewer: widget.viewer,
      callbacks: widget.callbacks,
      unread: feed.unread,
    );
    if (saved != null) feed.refresh();
  }

  /// Opens the discussion's own page over the feed, and takes in what the reader did there.
  Future<void> _openThread(FeedPost post, {FeedReply? reply}) async {
    final feed = context.read<FeedController>();
    final result = await openThreadPage(
      context,
      repository: feed.repository.forum,
      viewer: widget.viewer,
      slug: post.slug,
      preview: post,
      focusReplyId: reply?.id,
      unread: feed.unread,
      callbacks: widget.callbacks,
    );
    if (result == null || !mounted) return;
    if (result.deleted) {
      feed.removePost(post.id);
    } else if (result.post != null) {
      feed.adopt(result.post!);
    }
  }

  /// Holding Like: the five reactions; the one picked is sent (the one the reader has takes it back).
  Future<void> _pickReaction(FeedPost post, Rect anchor) async {
    final feed = context.read<FeedController>();
    final picked = await showReactionPicker(context, anchor: anchor, current: post.myReaction);
    if (picked == null || !mounted) return;
    _run(feed.react(post, picked == post.myReaction ? null : picked));
  }

  void _reactors(FeedPost post) {
    final forum = context.read<FeedController>().repository.forum;
    showReactorsSheet(context, load: () => forum.reactors(post.id), onOpenMember: widget.callbacks.onOpenMember);
  }

  Future<void> _confirmDelete(FeedPost post, FeedReply reply) async {
    final feed = context.read<FeedController>();
    final sure = await confirm(
      context,
      title: 'Delete your reply?',
      body: 'It is taken out of the discussion for everyone.',
      action: 'Delete',
    );
    if (sure) _run(feed.deleteReply(post, reply));
  }

  /// Repost: with the reader's thoughts in the composer, or as it stands; the feed reads again so the repost is at
  /// its top.
  Future<void> _repost(FeedPost post) {
    final feed = context.read<FeedController>();
    return repostDiscussion(
      context,
      post: post,
      link: feed.repository.link(post),
      repository: feed.repository.forum,
      viewer: widget.viewer,
      callbacks: widget.callbacks,
      unread: feed.unread,
      onReposted: feed.refresh,
    );
  }

  void _share(FeedPost post) {
    final link = context.read<FeedController>().repository.link(post);
    SharePlus.instance.share(ShareParams(text: '${post.title}\n$link', subject: post.title));
  }

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<FeedController>();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.white),
      child: Scaffold(
        backgroundColor: HomeLook.canvas,
        body: SafeArea(
          bottom: false,
          // The header is painted over the list, so the list scrolls under it.
          child: Stack(
            children: [
              Positioned.fill(
                top: HomeHeader.height,
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: feed.pullToRefresh,
                  child: CustomScrollView(
                    controller: _scroll,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // The filters, one white card. There is no "Start a post" card: the
                      // header's "+" starts a post, as LinkedIn's does.
                      SliverToBoxAdapter(
                        child: ColoredBox(
                          color: HomeLook.card,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 10),
                              FeedFilterChips(
                                selected: feed.filter,
                                selectedTag: feed.tag,
                                onSelected: feed.setFilter,
                                onTopic: feed.setTag,
                                topics: feed.topics,
                              ),
                              const SizedBox(height: 10),
                            ],
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: HomeLook.gap)),
                      ..._body(feed),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: HomeHeader(
                  photo: widget.viewer.photo,
                  initials: widget.viewer.initials,
                  unread: feed.unread,
                  onCompose: _compose,
                  onAvatarTap: widget.onAccount,
                  onBellTap: widget.callbacks.onBell ?? () => openSitePage(context, '/notifications'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _body(FeedController feed) {
    if (feed.loading && feed.posts.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4))),
        ),
      ];
    }
    if (feed.error != null && feed.posts.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _Notice(
            icon: Symbols.cloud_off,
            title: "Couldn't load the feed",
            body: feed.error!,
            action: 'Try again',
            onAction: feed.refresh,
          ),
        ),
      ];
    }
    if (feed.posts.isEmpty) {
      final searching = feed.search.isNotEmpty;
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _Notice(
            icon: Symbols.forum,
            title: searching
                ? 'No discussions match "${feed.search}"'
                : feed.tag != null
                ? 'No discussions tagged #${feed.tag} yet'
                : _emptyTitle(feed.filter),
            body: searching ? 'Try different words, or clear the search.' : _emptyBody(feed.filter),
          ),
        ),
      ];
    }

    final children = <Widget>[];
    final posts = feed.posts;
    for (var i = 0; i < posts.length; i++) {
      final post = posts[i];
      final open = feed.isOpen(post);
      children.add(
        _ReadOnShow(
          key: ValueKey(post.id),
          post: post,
          child: PostCard(
            post: post,
            commentsOpen: open,
            onFollow: () => _run(feed.follow(post)),
            onSave: () => _run(feed.toggleSave(post)),
            onMore: () => _postMenu(post),
            onLike: () => _run(feed.toggleLike(post)),
            onOpen: () => _openThread(post),
            onReactions: () => _reactors(post),
            onPickReaction: (rect) => _pickReaction(post, rect),
            onOpenAuthor: widget.callbacks.onOpenMember == null
                ? null
                : () => widget.callbacks.onOpenMember!(post.author.id),
            onComments: () => feed.toggleReplies(post),
            onRepost: () => _repost(post),
            onShare: () => _share(post),
            onVote: (option) => _run(feed.vote(post, option)),
            afterPlacement: i == 2,
            replies: open
                ? ReplyThread(
                    post: post,
                    loading: feed.isLoadingReplies(post),
                    viewer: widget.viewer,
                    onLike: (reply) => _run(feed.toggleReplyLike(post, reply)),
                    onSend: (text, parentId) async {
                      final message = await feed.sendReply(post, text, parentId: parentId);
                      if (message != null && mounted) showMessage(context, message);
                      return message == null;
                    },
                    onMore: (reply) => _replyMenu(post, reply),
                    onOpenThread: () => _openThread(post),
                    onOpenAuthor: widget.callbacks.onOpenMember == null
                        ? null
                        : (reply) => widget.callbacks.onOpenMember!(reply.author.id),
                  )
                : null,
          ),
        ),
      );
      // Cards sit 8 dp apart on the canvas; the placement takes the second gap.
      children.add(const SizedBox(height: HomeLook.gap));
      if (i == 1 || (posts.length == 1 && i == 0)) {
        children.add(
          SponsoredCardView(
            card: feed.sponsored,
            onOpen: () => openSitePage(context, feed.sponsored.link),
            onInfo: () => showMessage(context, 'A placement shown to members of the ICR community.'),
          ),
        );
        children.add(const SizedBox(height: HomeLook.gap));
      }
    }
    children.add(
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: feed.loadingMore
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : feed.hasMore
              ? const SizedBox(height: 20)
              : Text("You're all caught up", style: HomeType.footer),
        ),
      ),
    );
    return [SliverList(delegate: SliverChildListDelegate(children))];
  }

  static String _emptyTitle(FeedFilter filter) => switch (filter) {
    FeedFilter.following => 'Nothing from people you follow yet',
    FeedFilter.unanswered => 'Every question has an answer',
    FeedFilter.polls => 'No polls right now',
    _ => 'No discussions yet',
  };

  static String _emptyBody(FeedFilter filter) => switch (filter) {
    FeedFilter.following => 'Follow members from their posts to see what they share here.',
    FeedFilter.unanswered => 'New questions without replies will show up here.',
    FeedFilter.polls => 'Polls members start in the community will show up here.',
    _ => 'Start one with the + at the top.',
  };
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.title, required this.body, this.action, this.onAction});

  final IconData icon;
  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: HomeLook.soft),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: HomeType.noticeTitle),
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center, style: HomeType.noticeBody),
          if (action != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                foregroundColor: HomeLook.blue,
                side: const BorderSide(color: HomeLook.blue),
                shape: const StadiumBorder(),
              ),
              child: Text(action!, style: HomeType.sectionAction),
            ),
          ],
        ],
      ),
    );
  }
}

/// Reads a card's discussion (its whole text and photos) when the card comes on screen, which is when a
/// scrolling list builds it; the controller reads each once.
class _ReadOnShow extends StatefulWidget {
  const _ReadOnShow({super.key, required this.post, required this.child});

  final FeedPost post;
  final Widget child;

  @override
  State<_ReadOnShow> createState() => _ReadOnShowState();
}

class _ReadOnShowState extends State<_ReadOnShow> {
  @override
  void initState() {
    super.initState();
    _ask();
  }

  @override
  void didUpdateWidget(_ReadOnShow old) {
    super.didUpdateWidget(old);
    _ask();
  }

  void _ask() {
    if (widget.post.detailLoaded) return;
    final post = widget.post;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<FeedController>().ensureDetail(post);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
