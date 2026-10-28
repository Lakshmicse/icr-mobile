import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/util/time_ago.dart';
import '../../feed/feed_models.dart';
import '../../feed/widgets/feed_avatar.dart';
import '../../feed/widgets/poll_view.dart';
import '../../feed/widgets/post_card.dart';
import '../forum_models.dart';
import '../forum_styles.dart';
import '../thread_controller.dart';
import 'forum_bits.dart';
import 'forum_rich_text.dart';

/// What the reader can do from the discussion's own block; the screen wires each to the controller.
class ThreadHeaderActions {
  const ThreadHeaderActions({
    required this.onMenu,
    required this.onFollowAuthor,
    required this.onLike,
    required this.onPickReaction,
    required this.onReply,
    required this.onSubscribe,
    required this.onSave,
    required this.onShare,
    required this.onVote,
    required this.onReactors,
    required this.onViewers,
    this.onOpenAuthor,
    this.onTag,
    this.onTopic,
    this.onLink,
    this.onOpenAttachment,
  });

  final VoidCallback onMenu;
  final VoidCallback onFollowAuthor;
  final VoidCallback onLike;
  final ValueChanged<Rect> onPickReaction;
  final VoidCallback onReply;
  final VoidCallback onSubscribe;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final ValueChanged<String> onVote;
  final VoidCallback onReactors;
  final VoidCallback onViewers;
  final VoidCallback? onOpenAuthor;
  final ValueChanged<String>? onTag;
  final ValueChanged<ForumTopicRef>? onTopic;
  final ValueChanged<String>? onLink;
  final ValueChanged<ForumAttachment>? onOpenAttachment;
}

/// The discussion itself, as its own page draws it: where it is filed, its title and numbers, who wrote it, the
/// whole body, its photos, file and poll, its tags, who reacted, and the actions. Built in the Home feed's
/// visual language; the body is set larger than a card's, since this is the page it is read on.
class ThreadHeader extends StatelessWidget {
  const ThreadHeader({super.key, required this.controller, required this.actions});

  final ThreadController controller;
  final ThreadHeaderActions actions;

  @override
  Widget build(BuildContext context) {
    final post = controller.post!;
    final thread = controller.thread;
    final own = controller.isOwn;
    final poll = post.poll;
    final images = thread?.images ?? post.images;
    final attachment = thread?.attachment;
    final showFile = attachment != null && !attachment.isPicture;
    final waiting = thread != null && thread.moderation != 'APPROVED';
    final pictures = [...images];
    return Padding(
      padding: const EdgeInsets.fromLTRB(ForumDesign.gutter, 14, ForumDesign.gutter, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (waiting) ...[
            ForumNotice(
              warn: true,
              icon: LucideIcons.clock,
              title: 'Waiting for review',
              text: 'Only you and the moderators can see this until it is approved.',
            ),
            const SizedBox(height: 12),
          ] else if (thread != null && !thread.open) ...[
            ForumNotice(
              icon: LucideIcons.lock,
              title: thread.status == 'LOCKED' ? 'Locked' : 'Archived',
              text: thread.status == 'LOCKED'
                  ? 'This discussion is not taking new replies, and its poll takes no votes.'
                  : 'This discussion has been archived.',
            ),
            const SizedBox(height: 12),
          ],
          _Chips(post: post, thread: thread, onTopic: actions.onTopic),
          const SizedBox(height: 12),
          Text(post.title, key: const ValueKey('thread-title'), style: ForumDesign.threadTitle),
          const SizedBox(height: 6),
          _MetaLine(controller: controller, post: post, thread: thread, onViewers: actions.onViewers),
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 1, color: AppColors.outlineVariant),
          const SizedBox(height: 12),
          _AuthorRow(
            post: post,
            thread: thread,
            own: own,
            onFollow: actions.onFollowAuthor,
            onMenu: actions.onMenu,
            onOpenAuthor: actions.onOpenAuthor,
          ),
          const SizedBox(height: 12),
          ?_body(post, thread),
          for (final (i, picture) in pictures.indexed) ...[
            const SizedBox(height: 12),
            GestureDetector(
              key: ValueKey('thread-image:$i'),
              onTap: () => showImageViewer(context, pictures, initial: i),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(
                  aspectRatio: 358 / 208,
                  child: ForumPicture(picture: picture),
                ),
              ),
            ),
          ],
          if (showFile) ...[
            const SizedBox(height: 12),
            AttachmentTile(
              key: const ValueKey('thread-attachment'),
              attachment: attachment,
              onTap: actions.onOpenAttachment == null ? null : () => actions.onOpenAttachment!(attachment),
            ),
          ],
          if (poll != null) ...[
            const SizedBox(height: 14),
            PollView(poll: poll, onVote: actions.onVote, onViewDiscussion: () {}, showLink: false),
          ],
          if (post.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in post.tags)
                  Material(
                    color: AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(6),
                    child: InkWell(
                      key: ValueKey('thread-tag:$tag'),
                      borderRadius: BorderRadius.circular(6),
                      onTap: actions.onTag == null
                          ? null
                          : () => actions.onTag!(tag.startsWith('#') ? tag.substring(1) : tag),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Text(tag, style: ForumDesign.tag),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          _Reactions(post: post, onReactors: actions.onReactors),
          const SizedBox(height: 8),
          const Divider(height: 1, thickness: 1, color: AppColors.outlineVariant),
          _ActionBar(post: post, thread: thread, own: own, actions: actions),
          const Divider(height: 1, thickness: 1, color: AppColors.outlineVariant),
        ],
      ),
    );
  }

  /// The words: the whole body once the page is read, the list's excerpt until then.
  Widget? _body(FeedPost post, ForumThread? thread) {
    if (thread == null) return post.body.isEmpty ? null : Text(post.body, style: ForumDesign.body);
    if (thread.bodyHtml.trim().isEmpty) return null;
    return ForumRichText(html: thread.bodyHtml, style: ForumDesign.body, onLink: actions.onLink);
  }
}

class _Chips extends StatelessWidget {
  const _Chips({required this.post, required this.thread, this.onTopic});

  final FeedPost post;
  final ForumThread? thread;
  final ValueChanged<ForumTopicRef>? onTopic;

  @override
  Widget build(BuildContext context) {
    final category = thread?.category;
    final sub = thread?.subcategory;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (post.pinned) const ForumChip(label: 'Pinned', icon: LucideIcons.pin),
        if (category != null)
          ForumChip(
            key: const ValueKey('thread-category'),
            label: category.name,
            onTap: onTopic == null ? null : () => onTopic!(category),
          ),
        if (sub != null)
          ForumChip(
            key: const ValueKey('thread-subcategory'),
            label: sub.name,
            onTap: onTopic == null ? null : () => onTopic!(sub),
          ),
        ForumChip(
          label: switch (post.kind) {
            ThreadKind.question => 'Question',
            ThreadKind.announcement => 'Announcement',
            ThreadKind.discussion => post.poll != null ? 'Poll' : 'Discussion',
          },
        ),
        if (post.kind == ThreadKind.question && post.answered)
          const ForumChip.success(key: ValueKey('thread-answered'), label: 'Answered', icon: LucideIcons.circleCheck),
        if (thread != null && thread!.status == 'LOCKED') const ForumChip(label: 'Locked', icon: LucideIcons.lock),
      ],
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.controller, required this.post, required this.thread, required this.onViewers});

  final ThreadController controller;
  final FeedPost post;
  final ForumThread? thread;
  final VoidCallback onViewers;

  @override
  Widget build(BuildContext context) {
    final replies = post.comments;
    final views = post.views ?? 0;
    final started = 'Started ${timeAgo(post.createdAt)}';
    final last = thread == null ? null : 'last activity ${timeAgo(thread!.lastActivityAt)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text([started, ?last].join(' · '), style: ForumDesign.meta),
        const SizedBox(height: 2),
        Wrap(
          children: [
            Text(
              '$replies ${replies == 1 ? 'reply' : 'replies'}',
              key: const ValueKey('thread-reply-count'),
              style: ForumDesign.meta,
            ),
            Text(' · ', style: ForumDesign.meta),
            GestureDetector(
              key: const ValueKey('thread-views'),
              onTap: onViewers,
              behavior: HitTestBehavior.opaque,
              child: Text('${groupedCount(views)} ${views == 1 ? 'view' : 'views'}', style: ForumDesign.metaLink),
            ),
            if (controller.isQuestion && !post.answered) Text(' · Still unanswered', style: ForumDesign.meta),
          ],
        ),
      ],
    );
  }
}

class _AuthorRow extends StatelessWidget {
  const _AuthorRow({
    required this.post,
    required this.thread,
    required this.own,
    required this.onFollow,
    required this.onMenu,
    this.onOpenAuthor,
  });

  final FeedPost post;
  final ForumThread? thread;
  final bool own;
  final VoidCallback onFollow;
  final VoidCallback onMenu;
  final VoidCallback? onOpenAuthor;

  @override
  Widget build(BuildContext context) {
    final author = post.author;
    final follows = thread?.followsAuthor ?? false;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          key: const ValueKey('thread-author'),
          onTap: onOpenAuthor,
          child: FeedAvatar(photo: author.photo, initials: author.initials, size: 44, label: author.name),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: GestureDetector(
                      onTap: onOpenAuthor,
                      child: Text(author.name, style: ForumDesign.author, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  if (!own && thread != null) ...[
                    const SizedBox(width: 12),
                    Semantics(
                      button: true,
                      label: follows ? 'Unfollow ${author.name}' : 'Follow ${author.name}',
                      excludeSemantics: true,
                      child: GestureDetector(
                        key: const ValueKey('thread-follow-author'),
                        onTap: onFollow,
                        behavior: HitTestBehavior.opaque,
                        child: Text(follows ? 'Following' : 'Follow', style: AppText.follow.copyWith(fontSize: 13)),
                      ),
                    ),
                  ],
                ],
              ),
              if (author.headline != null && author.headline!.isNotEmpty)
                Text(author.headline!, style: ForumDesign.headline, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(timeAgo(post.createdAt), style: ForumDesign.headline),
            ],
          ),
        ),
        Semantics(
          button: true,
          label: 'More options',
          excludeSemantics: true,
          child: InkResponse(
            key: const ValueKey('thread-menu'),
            onTap: onMenu,
            radius: 20,
            child: const SizedBox(
              width: 36,
              height: 36,
              child: Icon(LucideIcons.ellipsisVertical, size: 18, color: AppColors.outline),
            ),
          ),
        ),
      ],
    );
  }
}

class _Reactions extends StatelessWidget {
  const _Reactions({required this.post, required this.onReactors});

  final FeedPost post;
  final VoidCallback onReactors;

  @override
  Widget build(BuildContext context) {
    if (post.reactions <= 0) {
      return Text('No reactions yet', style: ForumDesign.meta);
    }
    final kinds = post.reactionKinds;
    return Semantics(
      button: true,
      label: 'Who reacted',
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('thread-reactions'),
        onTap: onReactors,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 22,
          child: Row(
            children: [
              if (kinds.isNotEmpty) ...[ReactionStack(kinds: kinds), const SizedBox(width: 8.5)],
              Text('${post.reactions} ${post.reactions == 1 ? 'reaction' : 'reactions'}', style: AppText.reactionCount),
              const Spacer(),
              const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.post, required this.thread, required this.own, required this.actions});

  final FeedPost post;
  final ForumThread? thread;
  final bool own;
  final ThreadHeaderActions actions;

  @override
  Widget build(BuildContext context) {
    final liked = post.myReaction != null;
    final subscribed = thread?.subscribed ?? false;
    final open = thread == null || thread!.open || thread!.canModerate;
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          Expanded(
            child: _Act(
              key: const ValueKey('thread-like'),
              icon: reactionIcon(post.myReaction ?? ReactionKind.like),
              label: liked ? reactionLabels[post.myReaction] ?? 'Liked' : 'Like',
              active: liked,
              onTap: actions.onLike,
              onHold: own ? null : actions.onPickReaction,
            ),
          ),
          Expanded(
            child: _Act(
              key: const ValueKey('thread-reply'),
              icon: LucideIcons.messageCircleMore,
              label: 'Reply',
              onTap: open ? actions.onReply : null,
            ),
          ),
          Expanded(
            child: _Act(
              key: const ValueKey('thread-subscribe'),
              icon: subscribed ? LucideIcons.bellRing : LucideIcons.bell,
              label: subscribed ? 'Notifying' : 'Notify me',
              active: subscribed,
              onTap: actions.onSubscribe,
            ),
          ),
          Expanded(
            child: _Act(
              key: const ValueKey('thread-save'),
              icon: post.saved ? LucideIcons.bookmarkCheck : LucideIcons.bookmark,
              label: post.saved ? 'Saved' : 'Save',
              active: post.saved,
              onTap: actions.onSave,
            ),
          ),
          Expanded(
            child: _Act(
              key: const ValueKey('thread-share'),
              icon: LucideIcons.share2,
              label: 'Share',
              onTap: actions.onShare,
            ),
          ),
        ],
      ),
    );
  }
}

class _Act extends StatelessWidget {
  const _Act({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.onHold,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;
  final ValueChanged<Rect>? onHold;

  @override
  Widget build(BuildContext context) {
    final color = onTap == null ? AppColors.outlineVariant : (active ? AppColors.primary : AppColors.icon);
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 19, color: color),
            const SizedBox(height: 4),
            Text(label, style: ForumDesign.action.copyWith(color: color), maxLines: 1),
          ],
        ),
      ),
    );
  }
}

/// A reply's attached file, drawn under its words.
class ReplyAttachment extends StatelessWidget {
  const ReplyAttachment({super.key, required this.reply, this.onOpen});

  final FeedReply reply;
  final ValueChanged<String>? onOpen;

  @override
  Widget build(BuildContext context) {
    final url = reply.attachmentUrl;
    if (url == null) return const SizedBox.shrink();
    return AttachmentTile(
      attachment: ForumAttachment(uploadId: reply.attachmentName ?? 'file', fileName: reply.attachmentName, url: url),
      onTap: onOpen == null ? null : () => onOpen!(url),
    );
  }
}
