import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/util/links.dart';
import '../../core/util/time_ago.dart';
import '../../core/widgets/chips.dart';
import '../chapters/community_kit.dart';
import 'api_network_repository.dart';
import 'demo_network_repository.dart';
import 'network_controller.dart';
import 'network_models.dart';

/// The Network screen with its controller, for a route:
/// `Navigator.push(context, MaterialPageRoute(builder: (c) => networkRoute(c, onOpenProfile: …)))`.
Widget networkRoute(
  BuildContext context, {
  void Function(String userId)? onOpenProfile,
  void Function(NetworkPost post)? onOpenPost,
  VoidCallback? onWriteArticle,
  VoidCallback? onBell,
  NetworkTab initialTab = NetworkTab.feed,
  bool? demo,
}) {
  final sample = demo ?? AppConfig.demo;
  return ChangeNotifierProvider<NetworkController>(
    create: (c) => NetworkController(
      sample ? DemoNetworkRepository() : ApiNetworkRepository(api: c.read<ApiClient>()),
      initialTab: initialTab,
    ),
    child: Builder(
      builder: (inner) => NetworkScreen(
        onBack: () => Navigator.of(inner).maybePop(),
        onBell: onBell,
        onOpenProfile: onOpenProfile,
        onOpenPost: onOpenPost,
        onWriteArticle: onWriteArticle,
      ),
    ),
  );
}

/// `/network`: what the people the member follows publish, who to follow, and
/// the member's following and followers. Reads a [NetworkController] from
/// `Provider` (see [networkRoute]).
class NetworkScreen extends StatefulWidget {
  const NetworkScreen({
    super.key,
    this.onBack,
    this.onBell,
    this.onOpenProfile,
    this.onOpenPost,
    this.onWriteArticle,
    this.opener = openUrl,
  });

  final VoidCallback? onBack;

  /// The bell: the notifications screen. The website's `/notifications` when
  /// left out.
  final VoidCallback? onBell;

  /// A person's name or photo: their member profile. The website's
  /// `/members/<id>` when left out.
  final void Function(String userId)? onOpenProfile;

  /// A post in the feed (its [NetworkPost.kind] says forum discussion or
  /// article, its [NetworkPost.link] is the website path
  /// `/community/<slug>` or `/blogs/<slug>`). The website's page when left out.
  final void Function(NetworkPost post)? onOpenPost;

  /// "Write an article". The website's article composer when left out.
  final VoidCallback? onWriteArticle;

  final Future<void> Function(BuildContext context, Uri uri) opener;

  @override
  State<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends State<NetworkScreen> {
  @override
  void initState() {
    super.initState();
    final network = context.read<NetworkController>();
    if (!network.started) network.start();
  }

  void _site(String path) => widget.opener(context, AppConfig.sitePage(path));

  void _profile(NetworkPerson p) =>
      widget.onOpenProfile != null ? widget.onOpenProfile!(p.id) : _site('/members/${p.id}');

  void _post(NetworkPost post) => widget.onOpenPost != null ? widget.onOpenPost!(post) : _site(post.link);

  Future<void> _refresh(NetworkController network) async {
    final message = await network.refresh();
    if (message != null && mounted) showMessage(context, message);
  }

  Future<void> _loadMore(NetworkController network) async {
    final message = await network.loadMore();
    if (message != null && mounted) showMessage(context, message);
  }

  Future<void> _toggle(NetworkController network, NetworkPerson person) async {
    String? message;
    if (network.follows(person)) {
      final sure = await _confirmUnfollow(person);
      if (sure != true || !mounted) return;
      message = await network.unfollow(person);
    } else {
      message = await network.follow(person);
    }
    if (message != null && mounted) showMessage(context, message);
  }

  Future<bool?> _confirmUnfollow(NetworkPerson person) => showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Unfollow ${person.name}?', style: CommunityText.sheetTitle),
            const SizedBox(height: 6),
            Text("Their articles and discussions leave your feed. They aren't told.", style: CommunityText.body),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: CommunityButton(
                    key: const ValueKey('unfollow-cancel'),
                    label: 'Cancel',
                    outlined: true,
                    expand: true,
                    height: 40,
                    onPressed: () => Navigator.pop(sheet, false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: CommunityButton(
                    key: const ValueKey('unfollow-confirm'),
                    label: 'Unfollow',
                    color: AppColors.error,
                    expand: true,
                    height: 40,
                    onPressed: () => Navigator.pop(sheet, true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final network = context.watch<NetworkController>();
    return CommunityPage(
      title: 'Network',
      onBack: widget.onBack ?? () => Navigator.of(context).maybePop(),
      onBell: widget.onBell ?? () => _site('/notifications'),
      unread: network.unread,
      onRefresh: () => _refresh(network),
      children: _body(network),
    );
  }

  List<Widget> _body(NetworkController network) {
    if (!network.loaded) {
      if (network.loading || !network.started || network.error == null) return const [CommunityLoading()];
      return [
        CommunityNotice(
          icon: LucideIcons.users,
          title: "Couldn't load your network",
          body: network.error!,
          action: 'Retry',
          onAction: network.refresh,
        ),
      ];
    }
    return [
      const SizedBox(height: 14),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your network', style: AppText.workSans(16, FontWeight.w700, AppColors.slate900, lineHeight: 21)),
            const SizedBox(height: 3),
            Text('Articles and discussions from the people you follow.', style: CommunityText.sectionSubtitle),
          ],
        ),
      ),
      const SizedBox(height: 12),
      CommunityStatGrid(
        tiles: [
          CommunityStatTile(
            key: const ValueKey('stat-following'),
            label: 'Following',
            value: groupThousands(network.followingCount),
            blue: network.tab == NetworkTab.following,
            onTap: () => network.setTab(NetworkTab.following),
          ),
          CommunityStatTile(
            key: const ValueKey('stat-followers'),
            label: 'Followers',
            value: groupThousands(network.followersCount),
            blue: network.tab == NetworkTab.followers,
            onTap: () => network.setTab(NetworkTab.followers),
          ),
        ],
      ),
      const SizedBox(height: 12),
      ChipRow(
        height: 31,
        gap: 7,
        padding: 14,
        children: [
          for (final t in NetworkTab.values)
            IcrChip(
              key: ValueKey('tab-${t.name}'),
              label: switch (t) {
                NetworkTab.following => 'Following (${groupThousands(network.followingCount)})',
                NetworkTab.followers => 'Followers (${groupThousands(network.followersCount)})',
                _ => t.label,
              },
              tone: network.tab == t ? ChipTone.primary : ChipTone.outlined,
              height: 31,
              padding: const EdgeInsets.symmetric(horizontal: 12.5),
              textStyle: CommunityText.chip,
              onTap: () => network.setTab(t),
            ),
        ],
      ),
      const SizedBox(height: 12),
      ..._tab(network),
      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: CommunityHostCard(
          icon: LucideIcons.penLine,
          title: 'Be worth following',
          body: 'Members who follow you hear when you publish something new.',
          action: 'Write an article',
          onAction: widget.onWriteArticle ?? () => _site('/manage/articles'),
        ),
      ),
      const SizedBox(height: 24),
    ];
  }

  List<Widget> _tab(NetworkController network) {
    switch (network.tab) {
      case NetworkTab.feed:
        if (network.followsNobody) {
          return [
            const CommunityNotice(
              icon: LucideIcons.rss,
              title: 'Follow someone to start your feed',
              body: 'When you follow a member, what they publish shows up here.',
              padding: EdgeInsets.fromLTRB(32, 12, 32, 16),
            ),
            if (network.suggestions.isNotEmpty) ...[
              const CommunitySectionHeading(title: 'People worth following'),
              const SizedBox(height: 8),
              ..._people(network, network.suggestions.take(8).toList()),
            ],
          ];
        }
        return [
          if (network.feed.isEmpty)
            const CommunityNotice(
              icon: LucideIcons.rss,
              title: 'Nothing new yet',
              body: 'The people you follow have not published anything recently.',
              padding: EdgeInsets.fromLTRB(32, 12, 32, 16),
            )
          else ...[
            for (final (i, post) in network.feed.indexed) ...[
              if (i > 0) const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: _PostCard(
                  key: ValueKey('post-${post.key}'),
                  post: post,
                  onOpen: () => _post(post),
                  onAuthor: () => _profile(post.author),
                ),
              ),
            ],
            if (network.feedHasNext) _more(network),
          ],
          if (network.suggestions.isNotEmpty) ...[
            const SizedBox(height: 20),
            CommunitySectionHeading(
              title: 'Who to follow',
              action: 'See all',
              onAction: () => network.setTab(NetworkTab.suggestions),
            ),
            const SizedBox(height: 8),
            ..._people(network, network.suggestions.take(5).toList()),
          ],
        ];
      case NetworkTab.suggestions:
        if (network.suggestions.isEmpty) {
          return const [
            CommunityNotice(
              icon: LucideIcons.users,
              title: 'No suggestions right now',
              body: 'As you follow people, the people they follow show up here.',
            ),
          ];
        }
        return _people(network, network.suggestions);
      case NetworkTab.following:
        if (network.following.isEmpty) {
          return [
            CommunityNotice(
              icon: LucideIcons.userPlus,
              title: "You don't follow anyone yet",
              body: 'Follow members to read what they publish.',
              action: 'Find people',
              onAction: () => network.setTab(NetworkTab.suggestions),
            ),
          ];
        }
        return _people(network, network.following, sincePrefix: 'Following since');
      case NetworkTab.followers:
        if (network.followers.isEmpty) {
          return const [
            CommunityNotice(
              icon: LucideIcons.users,
              title: 'No followers yet',
              body: 'Members who follow you show up here.',
            ),
          ];
        }
        return [
          ..._people(network, network.followers, sincePrefix: 'Follows you since', followBack: true),
          if (network.followersHasNext) _more(network),
        ];
    }
  }

  List<Widget> _people(
    NetworkController network,
    List<NetworkPerson> people, {
    String sincePrefix = 'Since',
    bool followBack = false,
  }) => [
    for (final (i, p) in people.indexed) ...[
      if (i > 0) const _Hairline(),
      _PersonRow(
        key: ValueKey('person-${p.id}'),
        person: p,
        following: network.follows(p),
        busy: network.isBusy(p),
        followBackLabel: followBack,
        sincePrefix: sincePrefix,
        onOpen: () => _profile(p),
        onToggle: () => _toggle(network, p),
      ),
    ],
  ];

  Widget _more(NetworkController network) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Center(
      child: network.loadingMore
          ? const SizedBox(
              key: ValueKey('more-loading'),
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : CommunityButton(
              key: const ValueKey('show-more'),
              label: 'Show more',
              outlined: true,
              onPressed: () => _loadMore(network),
            ),
    ),
  );
}

/// The 1 dp rule between rows, inset to the rows' text.
class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(left: 64, right: 14),
    child: ColoredBox(
      color: CommunityColors.tileRule,
      child: SizedBox(height: 1, width: double.infinity),
    ),
  );
}

/// A member: photo, name, where they work, why they are listed, and Follow.
class _PersonRow extends StatelessWidget {
  const _PersonRow({
    super.key,
    required this.person,
    required this.following,
    required this.busy,
    required this.onOpen,
    required this.onToggle,
    required this.sincePrefix,
    this.followBackLabel = false,
  });

  final NetworkPerson person;
  final bool following;
  final bool busy;
  final bool followBackLabel;
  final String sincePrefix;
  final VoidCallback onOpen;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final p = person;
    final lines = [
      [?p.company, if (p.followers != null) plural(p.followers!, 'follower')].join(' · '),
      ?p.reason,
      if (p.reason == null && p.since != null) '$sincePrefix ${fullDate(p.since!)}',
    ].where((l) => l.isNotEmpty);
    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(
          children: [
            PersonAvatar(initials: p.initials, photo: p.photo, size: 40),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, style: CommunityText.personName, maxLines: 1, overflow: TextOverflow.ellipsis),
                  for (final line in lines)
                    Text(line, style: CommunityText.personLine, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            CommunityButton(
              key: ValueKey('follow-${p.id}'),
              label: following ? 'Following' : (followBackLabel ? 'Follow back' : 'Follow'),
              icon: following ? LucideIcons.userCheck : LucideIcons.userPlus,
              outlined: following,
              busy: busy,
              height: 28,
              onPressed: onToggle,
            ),
          ],
        ),
      ),
    );
  }
}

/// One post from the feed: who, when, what kind, the title and its opening.
class _PostCard extends StatelessWidget {
  const _PostCard({super.key, required this.post, required this.onOpen, required this.onAuthor});

  final NetworkPost post;
  final VoidCallback onOpen;
  final VoidCallback onAuthor;

  @override
  Widget build(BuildContext context) {
    final a = post.author;
    final article = post.kind == PostKind.article;
    return CommunityCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                key: ValueKey('author-photo-${post.key}'),
                onTap: onAuthor,
                child: PersonAvatar(initials: a.initials, photo: a.photo, size: 34),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: GestureDetector(
                  key: ValueKey('author-name-${post.key}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onAuthor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.name, style: CommunityText.personName, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(
                        [?a.company, timeAgo(post.at)].join(' · '),
                        style: CommunityText.personLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CommunityPill(
                label: post.kind.label,
                icon: article ? LucideIcons.newspaper : LucideIcons.messagesSquare,
                fill: article ? CommunityColors.blue50 : CommunityColors.green50,
                style: CommunityText.pill.copyWith(
                  color: article ? CommunityColors.blue700 : CommunityColors.green700,
                  fontSize: 12,
                ),
                height: 19,
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(post.title, style: CommunityText.cardTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
          if (post.excerpt.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(post.excerpt, style: CommunityText.cardCopy, maxLines: 3, overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }
}
