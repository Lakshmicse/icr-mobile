import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart';
import '../../core/widgets/search_field.dart';
import '../../core/widgets/section_heading.dart';
import '../../core/widgets/title_bar.dart';
import '../feed/feed_controller.dart';
import '../feed/feed_models.dart';
import '../feed/widgets/composer_and_filters.dart';
import '../feed/widgets/post_card.dart';
import 'forum_callbacks.dart';
import 'forum_flows.dart';
import 'repost.dart';
import 'forum_models.dart';
import 'forum_repository.dart';
import 'forum_styles.dart';
import 'forums_controller.dart';
import 'thread_screen.dart';
import 'widgets/forum_bits.dart';
import 'widgets/forum_filters_sheet.dart';
import 'widgets/forum_sheets.dart';

/// The Forums tab: the community's discussions to browse. A search box with its filters, the views (All Feed,
/// Trending, Following, Unanswered, Polls, and the reader's Saved and My posts), the topics, then the same cards
/// the Home feed draws. A card opens its discussion on its own page.
///
/// With no [repository] it reads the Home feed's forum (`FeedController.repository.forum`, from Provider), so one
/// widget in the shell is all the wiring it needs; a [controller] may be handed in instead (the tests do).
class ForumsScreen extends StatefulWidget {
  const ForumsScreen({
    super.key,
    required this.viewer,
    required this.onBack,
    this.callbacks = const ForumCallbacks(),
    this.repository,
    this.controller,
  });

  /// The signed-in person, as the screens draw them (the reply box's photo, "your own" tests).
  final FeedAuthor viewer;

  /// The arrow at the top left; the shell goes back to Home.
  final VoidCallback onBack;

  /// A member's profile, the bell: what the rest of the app answers.
  final ForumCallbacks callbacks;
  final ForumRepository? repository;
  final ForumsController? controller;

  @override
  State<ForumsScreen> createState() => _ForumsScreenState();
}

class _ForumsScreenState extends State<ForumsScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  late final ForumsController _forums;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _forums =
        widget.controller ?? ForumsController(widget.repository ?? context.read<FeedController>().repository.forum);
    _forums.start();
    _search.text = _forums.query.search;
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 600) _forums.loadMore();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    if (_ownsController) _forums.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String?> action) async {
    final message = await action;
    if (message != null && mounted) showMessage(context, message);
  }

  ForumCallbacks get _threadCallbacks => ForumCallbacks(
    onOpenMember: widget.callbacks.onOpenMember,
    onBell: widget.callbacks.onBell,
    // A tag or a topic chosen on a discussion's page filters this tab.
    onOpenTag: (tag) {
      _search.clear();
      _forums.setTag(tag);
      widget.callbacks.onOpenTag?.call(tag);
    },
    onOpenTopic: (topic) {
      _forums.showTopic(topic);
      widget.callbacks.onOpenTopic?.call(topic);
    },
  );

  /// Opens a discussion on its own page and takes in what the reader did there.
  Future<void> _open(FeedPost post, {bool toReplies = false}) async {
    final result = await openThreadPage(
      context,
      repository: _forums.repository,
      viewer: widget.viewer,
      slug: post.slug,
      preview: post,
      unread: _forums.unread,
      callbacks: _threadCallbacks,
      scrollToReplies: toReplies,
    );
    if (result == null || !mounted) return;
    if (result.deleted) {
      _forums.removePost(post.id);
    } else if (result.post != null) {
      _forums.adopt(result.post!);
    }
  }

  Future<void> _filters() async {
    await _forums.readTaxonomy();
    if (!mounted) return;
    final next = await showForumFilters(
      context,
      query: _forums.query,
      topics: _forums.topics,
      taxonomy: _forums.taxonomy,
    );
    if (next != null) await _forums.apply(next);
  }

  void _menu(FeedPost post) {
    final mine = post.author.id == widget.viewer.id;
    showActionSheet(
      context,
      title: post.title,
      actions: [
        SheetAction(
          key: const ValueKey('menu-open'),
          label: 'Open discussion',
          icon: LucideIcons.expand,
          onTap: () => _open(post),
        ),
        SheetAction(
          key: const ValueKey('menu-copy'),
          label: 'Copy link',
          icon: LucideIcons.link,
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: _forums.repository.link(post.slug).toString()));
            if (mounted) showMessage(context, 'Link copied');
          },
        ),
        if (!mine)
          SheetAction(
            key: const ValueKey('menu-report'),
            label: 'Report',
            icon: LucideIcons.flag,
            onTap: () => _report(post),
          ),
      ],
    );
  }

  Future<void> _report(FeedPost post) async {
    final sent = await showReportSheet(
      context,
      reply: false,
      onSend: (reason, note) async {
        try {
          await _forums.repository.report(threadId: post.id, reason: reason, note: note);
          return null;
        } catch (e) {
          return e.toString();
        }
      },
    );
    if (sent && mounted) showMessage(context, 'Thanks. A moderator will take a look.');
  }

  Future<void> _pickReaction(FeedPost post, Rect anchor) async {
    final picked = await showReactionPicker(context, anchor: anchor, current: post.myReaction);
    if (picked == null || !mounted) return;
    _run(_forums.react(post, picked == post.myReaction ? null : picked));
  }

  void _share(FeedPost post) {
    final link = _forums.repository.link(post.slug);
    SharePlus.instance.share(ShareParams(text: '${post.title}\n$link', subject: post.title));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _forums,
      builder: (context, _) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.white),
        child: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                Positioned.fill(
                  top: TitleBar.height,
                  child: RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: _forums.pullToRefresh,
                    child: CustomScrollView(
                      controller: _scroll,
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: _Header(forums: _forums, search: _search, onFilters: _filters, onCompose: _compose),
                        ),
                        ..._body(),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: TitleBar(
                    title: 'Forums',
                    onBack: widget.onBack,
                    unread: _forums.unread,
                    onBell: widget.callbacks.onBell ?? () => openSitePage(context, '/notifications'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Starts a discussion in the topic being browsed; the new card joins the top of the list.
  Future<void> _compose() async {
    final saved = await startDiscussion(
      context,
      repository: _forums.repository,
      viewer: widget.viewer,
      callbacks: _threadCallbacks,
      topicSlug: _forums.query.category?.slug,
      unread: _forums.unread,
    );
    if (saved != null) _forums.addPosted(saved.card);
  }

  List<Widget> _body() {
    final f = _forums;
    if (f.loading && f.posts.isEmpty) {
      return const [SliverFillRemaining(hasScrollBody: false, child: ForumSpinner())];
    }
    if (f.error != null && f.posts.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ForumMessage(
            icon: LucideIcons.cloudOff,
            title: "Couldn't load the discussions",
            body: f.error!,
            action: 'Try again',
            onAction: f.refresh,
          ),
        ),
      ];
    }
    if (f.posts.isEmpty) {
      final e = _Empty.of(f.query);
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ForumMessage(
            icon: e.icon,
            title: e.title,
            body: e.body,
            action: f.query.refinements > 0 ? 'Clear filters' : null,
            onAction: f.query.refinements > 0 ? f.clearFilters : null,
          ),
        ),
      ];
    }
    final children = <Widget>[];
    for (final (i, post) in f.posts.indexed) {
      children.add(
        PostCard(
          key: ValueKey('forum-card:${post.id}'),
          post: post,
          commentsOpen: false,
          onFollow: () => _run(f.follow(post)),
          onSave: () => _run(f.toggleSave(post)),
          onMore: () => _menu(post),
          onLike: () => _run(f.toggleLike(post)),
          onComments: () => _open(post, toReplies: true),
          onRepost: () => repostDiscussion(
            context,
            post: post,
            link: f.repository.link(post.slug),
            repository: f.repository,
            viewer: widget.viewer,
            callbacks: _threadCallbacks,
            unread: f.unread,
            onReposted: f.refresh,
          ),
          onShare: () => _share(post),
          onVote: (option) => _run(f.vote(post, option)),
          onOpen: () => _open(post),
          onTag: (tag) {
            _search.clear();
            f.setTag(tag);
          },
          onReactions: () => showReactorsSheet(
            context,
            load: () => f.repository.reactors(post.id),
            onOpenMember: widget.callbacks.onOpenMember,
          ),
          onPickReaction: (rect) => _pickReaction(post, rect),
          onOpenAuthor: widget.callbacks.onOpenMember == null
              ? null
              : () => widget.callbacks.onOpenMember!(post.author.id),
        ),
      );
      children.add(const SizedBox(height: 6));
      if (i < f.posts.length - 1) children.add(const Divider(height: 0.5, thickness: 0.5));
    }
    children.add(
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: f.loadingMore
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : f.hasMore
              ? const SizedBox(height: 20)
              : Text("You're all caught up", key: const ValueKey('forums-end'), style: ForumDesign.meta),
        ),
      ),
    );
    return [SliverList(delegate: SliverChildListDelegate(children))];
  }
}

/// What the tab says when nothing matches, by what was asked.
class _Empty {
  const _Empty(this.icon, this.title, this.body);

  final IconData icon;
  final String title;
  final String body;

  factory _Empty.of(ForumQuery q) {
    if (q.search.isNotEmpty) {
      return _Empty(
        LucideIcons.searchX,
        'No discussions match "${q.search}"',
        'Try different words, or start the discussion yourself.',
      );
    }
    if (q.tag != null) {
      return _Empty(LucideIcons.hash, 'No discussions tagged #${q.tag} yet', 'Try another tag, or clear the filters.');
    }
    if (q.refinements > 0 || q.category != null) {
      return const _Empty(
        LucideIcons.listFilter,
        'No discussions match these filters',
        'Try other filters, or clear them.',
      );
    }
    return switch (q.view) {
      ForumView.following => const _Empty(
        LucideIcons.users,
        'Nothing from people you follow yet',
        'Follow members from their posts to see what they share here.',
      ),
      ForumView.unanswered => const _Empty(
        LucideIcons.circleCheck,
        'Every question has an answer',
        'New questions without replies will show up here.',
      ),
      ForumView.polls => const _Empty(
        LucideIcons.chartBar,
        'No polls right now',
        'Polls members start in the community will show up here.',
      ),
      ForumView.saved => const _Empty(
        LucideIcons.bookmark,
        'Nothing saved yet',
        'Bookmark a discussion and it will show up here.',
      ),
      ForumView.mine => const _Empty(
        LucideIcons.pencil,
        "You haven't posted yet",
        'Questions and discussions you start show up here, including any still awaiting approval.',
      ),
      _ => const _Empty(LucideIcons.messagesSquare, 'No discussions yet', 'Start one with "Start a discussion...".'),
    };
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.forums, required this.search, required this.onFilters, required this.onCompose});

  final ForumsController forums;
  final TextEditingController search;
  final VoidCallback onFilters;
  final VoidCallback onCompose;

  @override
  Widget build(BuildContext context) {
    final q = forums.query;
    final topics = forums.topics;
    final subtopics = forums.subtopics;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: IcrSearchField(
            controller: search,
            height: 34,
            hint: 'Search discussions...',
            onSubmitted: forums.setSearch,
            trailing: FilterButton(count: q.refinements, onTap: onFilters),
          ),
        ),
        const SizedBox(height: 10),
        ComposerBar(onTap: onCompose, label: 'Start a discussion...'),
        if (forums.access.requiresApproval) ...[
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: ForumNotice(
              key: ValueKey('forums-approval'),
              warn: true,
              icon: LucideIcons.clock,
              text:
                  'Your first few posts are read by a moderator before they go public. Once a couple are approved, everything you write publishes straight away.',
            ),
          ),
        ],
        const SizedBox(height: 14),
        SizedBox(
          height: 28,
          child: ListView.separated(
            key: const ValueKey('forum-views'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: ForumView.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: 5),
            itemBuilder: (context, i) {
              final view = ForumView.values[i];
              return FeedChip(
                key: ValueKey('view:${view.name}'),
                label: view.label,
                large: i >= 4,
                active: q.view == view,
                onTap: () => forums.setView(view),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        const SectionHeading(title: 'Topics', padding: EdgeInsets.symmetric(horizontal: 16)),
        const SizedBox(height: 8),
        if (!forums.topicsRead)
          const SizedBox(height: 28)
        else if (forums.topicsError != null && topics.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: Text("Couldn't load the topics", style: ForumDesign.meta)),
                GestureDetector(
                  key: const ValueKey('topics-retry'),
                  onTap: forums.pullToRefresh,
                  child: Text('Try again', style: ForumDesign.metaLink),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 28,
            child: ListView.separated(
              key: const ValueKey('forum-topics'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: topics.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 5),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return FeedChip(
                    key: const ValueKey('topic:all'),
                    label: 'All topics',
                    active: q.category == null,
                    onTap: () => forums.setTopic(null),
                  );
                }
                final t = topics[i - 1];
                return FeedChip(
                  key: ValueKey('topic:${t.slug}'),
                  label: '${t.name} (${t.threadCount})',
                  active: q.category?.slug == t.slug,
                  onTap: () => forums.setTopic(q.category?.slug == t.slug ? null : t),
                );
              },
            ),
          ),
        if (subtopics.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 28,
            child: ListView.separated(
              key: const ValueKey('forum-subtopics'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: subtopics.length,
              separatorBuilder: (_, _) => const SizedBox(width: 5),
              itemBuilder: (context, i) {
                final n = subtopics[i];
                return FeedChip(
                  key: ValueKey('sub:${n.slug}'),
                  label: n.name,
                  large: true,
                  emphasis: q.subcategory?.slug != n.slug,
                  active: q.subcategory?.slug == n.slug,
                  onTap: () => forums.setSubtopic(q.subcategory?.slug == n.slug ? null : n),
                );
              },
            ),
          ),
        ],
        _ActiveFilters(forums: forums, search: search),
        const SizedBox(height: 10),
      ],
    );
  }
}

/// What is narrowing the list, each with an x, and how many discussions are left.
class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({required this.forums, required this.search});

  final ForumsController forums;
  final TextEditingController search;

  @override
  Widget build(BuildContext context) {
    final q = forums.query;
    final pills = <(String key, String label, VoidCallback onRemove)>[
      if (q.search.isNotEmpty)
        (
          'search',
          '"${q.search}"',
          () {
            search.clear();
            forums.setSearch('');
          },
        ),
      if (q.tag != null) ('tag', '#${q.tag}', () => forums.setTag(null)),
      if (q.subcategory != null) ('sub', q.subcategory!.name, () => forums.setSubtopic(null)),
      if (q.kind != ForumKindFilter.any) ('kind', q.kind.label, () => forums.setKind(ForumKindFilter.any)),
      if (q.sortable && q.sort != ForumSort.latest) ('sort', q.sort.label, () => forums.setSort(ForumSort.latest)),
    ];
    final total = forums.total;
    final summary = total == null || forums.loading
        ? null
        : '${groupedCount(total)} ${total == 1 ? 'discussion' : 'discussions'}';
    if (pills.isEmpty && summary == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final p in pills)
            Material(
              color: AppColors.chipEmphasis,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                key: ValueKey('active:${p.$1}'),
                borderRadius: BorderRadius.circular(12),
                onTap: p.$3,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 5, 7, 5),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(p.$2, style: ForumDesign.chip.copyWith(color: AppColors.primary)),
                      const SizedBox(width: 4),
                      const Icon(LucideIcons.x, size: 12, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            ),
          if (pills.length > 1)
            GestureDetector(
              key: const ValueKey('active:clear'),
              onTap: () {
                search.clear();
                forums.clearAll();
              },
              child: Text('Clear all', style: ForumDesign.metaLink),
            ),
          if (summary != null) Text(summary, key: const ValueKey('forums-total'), style: ForumDesign.meta),
        ],
      ),
    );
  }
}
