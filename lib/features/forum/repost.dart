import 'package:flutter/material.dart';

import '../../core/api/api_error.dart';
import '../../core/theme/app_text.dart';
import '../../core/util/links.dart' show showMessage;
import '../feed/feed_models.dart';
import 'forum_callbacks.dart';
import 'forum_flows.dart';
import 'forum_models.dart';
import 'forum_repository.dart';

/// Repost, as the forum can hold it. The API has no repost: a repost here is a new discussion that quotes the
/// original and links to it, filed under the same topic and carrying its tags. "Repost with your thoughts" opens
/// the composer with that quote already in it; "Repost" files it as it stands.

/// The repost's title: the original's, behind "Repost:", kept to the forum's limit.
String repostTitle(FeedPost post) {
  final title = 'Repost: ${post.title.trim()}';
  if (title.length <= ForumLimits.titleMax) return title;
  return '${title.substring(0, ForumLimits.titleMax - 1).trimRight()}…';
}

/// The quote a repost carries: who wrote it, what it was called, and where it is.
String repostQuote(FeedPost post, Uri link) => '↻ Reposted from ${post.author.name}\n“${post.title.trim()}”\n$link';

/// The original's tags in the forum's own form (lower case, no "#"), at most what a discussion may carry.
List<String> repostTags(FeedPost post) => [
  for (final t in post.tags.take(ForumLimits.tags)) t.replaceFirst('#', '').trim().toLowerCase(),
].where((t) => t.isNotEmpty).toList();

enum _RepostChoice { withThoughts, instant }

/// Asks how to repost [post], then does it. [onReposted] runs once a repost is in the forum (the feed reads again
/// so the new card is at its top).
Future<void> repostDiscussion(
  BuildContext context, {
  required FeedPost post,
  required Uri link,
  required ForumRepository repository,
  required FeedAuthor viewer,
  ForumCallbacks callbacks = const ForumCallbacks(),
  int unread = 0,
  VoidCallback? onReposted,
}) async {
  final choice = await showModalBottomSheet<_RepostChoice>(
    context: context,
    backgroundColor: Colors.white,
    showDragHandle: true,
    builder: (_) => const _RepostSheet(),
  );
  if (choice == null || !context.mounted) return;

  Future<void> withThoughts() async {
    final saved = await startDiscussion(
      context,
      repository: repository,
      viewer: viewer,
      callbacks: callbacks,
      unread: unread,
      initialTitle: repostTitle(post),
      initialBody: repostQuote(post, link),
    );
    if (saved != null) onReposted?.call();
  }

  // Filing it as it stands needs the original's topic; a post that does not carry it asks in the composer.
  if (choice == _RepostChoice.withThoughts || post.categoryKey == null) return withThoughts();

  try {
    final saved = await repository.create(
      ForumDraft(
        categoryKey: post.categoryKey,
        subcategoryKey: post.subcategoryKey,
        title: repostTitle(post),
        body: repostQuote(post, link),
        tags: repostTags(post),
      ),
    );
    if (!context.mounted) return;
    showMessage(
      context,
      saved.moderation == 'APPROVED' ? 'Reposted to your feed.' : 'Reposted. A moderator will read it before it goes public.',
    );
    onReposted?.call();
  } catch (e) {
    if (context.mounted) showMessage(context, ApiError.from(e).message);
  }
}

class _RepostSheet extends StatelessWidget {
  const _RepostSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Option(
            key: const ValueKey('repost-thoughts'),
            icon: Icons.edit_outlined,
            title: 'Repost with your thoughts',
            body: 'Create a new post with this one attached.',
            onTap: () => Navigator.of(context).pop(_RepostChoice.withThoughts),
          ),
          _Option(
            key: const ValueKey('repost-instant'),
            icon: Icons.repeat,
            title: 'Repost',
            body: 'Instantly bring this post to your feed.',
            onTap: () => Navigator.of(context).pop(_RepostChoice.instant),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({super.key, required this.icon, required this.title, required this.body, required this.onTap});

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 24, color: const Color(0x99000000)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.plexSans(16, FontWeight.w600, const Color(0xE6000000))),
                  const SizedBox(height: 2),
                  Text(body, style: AppText.plexSans(14, FontWeight.w400, const Color(0x99000000))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
