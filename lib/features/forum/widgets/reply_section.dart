import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../feed/feed_models.dart';
import '../../feed/feed_styles.dart';
import '../../feed/widgets/reply_widgets.dart';
import '../forum_styles.dart';
import '../thread_controller.dart';
import 'forum_bits.dart';
import 'thread_header.dart';

/// The replies under a discussion, drawn as the "Branching Nested Replies Section": each reply a bubble hung off
/// one line, each answer stepped in under the reply it answers (three steps at most), then a button for the next
/// page. The accepted answer reads first and is tinted green.
class ReplySection extends StatelessWidget {
  const ReplySection({
    super.key,
    required this.controller,
    required this.keyFor,
    required this.onLike,
    required this.onReplyTo,
    required this.onMore,
    required this.onAccept,
    this.onOpenAuthor,
    this.onOpenUrl,
    this.focusId,
  });

  final ThreadController controller;

  /// A key for the reply with this id, so the page can scroll to it.
  final GlobalKey Function(String id) keyFor;
  final ValueChanged<FeedReply> onLike;
  final ValueChanged<FeedReply> onReplyTo;
  final ValueChanged<FeedReply> onMore;
  final ValueChanged<FeedReply> onAccept;
  final ValueChanged<FeedReply>? onOpenAuthor;
  final ValueChanged<String>? onOpenUrl;

  /// The reply a link named: ringed.
  final String? focusId;

  @override
  Widget build(BuildContext context) {
    final replies = controller.replies;
    final question = controller.isQuestion;
    final total = controller.totalReplies;
    final noun = question ? (total == 1 ? 'answer' : 'answers') : (total == 1 ? 'reply' : 'replies');
    final g = ReplyGeometry.section;

    final entries = <({FeedReply reply, int depth})>[];
    void walk(List<FeedReply> list, int depth) {
      for (final r in list) {
        entries.add((reply: r, depth: depth));
        walk(r.children, depth + 1);
      }
    }

    walk(replies, 0);

    final rows = <Widget>[];
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final reply = entry.reply;
      final mine = reply.author.id == controller.viewer.id;
      final last = i == entries.length - 1 && !controller.hasMoreReplies && controller.repliesError == null;
      rows.add(
        ThreadBranch(
          look: ReplyLook.section,
          gap: i == 0 ? 12 : ReplyDesign.gapTile,
          armY: ReplyDesign.armTile,
          indent: g.indentStep * entry.depth.clamp(0, ReplyDesign.maxDepth),
          last: last,
          child: KeyedSubtree(
            key: keyFor(reply.id),
            child: ReplyTile(
              reply: reply,
              focused: reply.id == focusId,
              onLike: () => onLike(reply),
              onReply: () => onReplyTo(reply),
              onMore: () => onMore(reply),
              onOpenAuthor: onOpenAuthor == null ? null : () => onOpenAuthor!(reply),
              below: reply.attachmentUrl == null ? null : ReplyAttachment(reply: reply, onOpen: onOpenUrl),
              actions: [
                if (controller.canAccept && !reply.accepted && !mine)
                  ReplyAction(
                    key: ValueKey('reply-accept:${reply.id}'),
                    icon: LucideIcons.circleCheck,
                    label: 'Accept answer',
                    semantics: 'Accept as the answer',
                    color: ForumDesign.successInk,
                    onTap: () => onAccept(reply),
                  ),
              ],
              badge: reply.accepted
                  ? const ForumChip.success(
                      key: ValueKey('reply-accepted'),
                      label: 'Accepted answer',
                      icon: LucideIcons.circleCheck,
                      height: 22,
                    )
                  : reply.pending
                  ? const ForumChip(
                      key: ValueKey('reply-pending'),
                      label: 'Awaiting review',
                      icon: LucideIcons.clock,
                      fill: ForumDesign.noticeWarnFill,
                      border: ForumDesign.noticeWarnBorder,
                      ink: ForumDesign.noticeWarnInk,
                      height: 22,
                    )
                  : null,
            ),
          ),
        ),
      );
    }

    if (controller.hasMoreReplies || controller.repliesError != null && entries.isNotEmpty) {
      rows.add(
        ThreadBranch(
          look: ReplyLook.section,
          gap: entries.isEmpty ? 12 : ReplyDesign.gapPill,
          armY: ReplyDesign.armPill,
          last: true,
          child: Align(
            alignment: Alignment.centerLeft,
            child: _MoreButton(
              loading: controller.loadingMoreReplies,
              error: controller.repliesError,
              onTap: controller.loadMoreReplies,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(ForumDesign.gutter, 20, ForumDesign.gutter, 0),
          child: Text(
            question ? '$total $noun' : '$total $noun',
            key: const ValueKey('replies-heading'),
            style: ForumDesign.sectionTitle,
          ),
        ),
        if (controller.repliesLoading && entries.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(vertical: 28), child: ForumSpinner())
        else if (controller.repliesError != null && entries.isEmpty)
          ForumMessage(
            icon: LucideIcons.cloudOff,
            title: "Couldn't load the replies",
            body: controller.repliesError!,
            action: 'Try again',
            onAction: controller.refresh,
          )
        else if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(ForumDesign.gutter, 10, ForumDesign.gutter, 10),
            child: ForumNotice(
              key: const ValueKey('replies-empty'),
              icon: LucideIcons.messageCircle,
              title: 'No replies yet',
              text: controller.takesReplies ? 'Be the first to share what you know.' : 'Replies will show up here.',
            ),
          )
        else
          Padding(
            padding: EdgeInsets.only(right: ForumDesign.gutter, left: g.inset),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
          ),
      ],
    );
  }
}

class _MoreButton extends StatelessWidget {
  const _MoreButton({required this.loading, required this.error, required this.onTap});

  final bool loading;
  final String? error;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ReplyDesign.pillFill,
      shape: const StadiumBorder(),
      child: InkWell(
        key: const ValueKey('replies-more'),
        customBorder: const StadiumBorder(),
        onTap: loading ? null : onTap,
        child: SizedBox(
          height: 32,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (loading)
                  const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  const Icon(LucideIcons.chevronDown, size: 14, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  loading
                      ? 'Loading replies...'
                      : error != null
                      ? "Couldn't load more. Try again"
                      : 'Show more replies',
                  style: ReplyDesign.pill.copyWith(
                    color: error != null && !loading ? AppColors.error : AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The text a reply box shows before anything is typed, and the note over it.
class ReplyTarget {
  const ReplyTarget._(this.hint, this.label);

  final String hint;
  final String? label;

  factory ReplyTarget.discussion() => const ReplyTarget._('Write a reply...', null);
  factory ReplyTarget.reply(FeedReply reply) =>
      ReplyTarget._('Reply to ${reply.author.name}...', 'Replying to ${reply.author.name}');
  factory ReplyTarget.editing() => const ReplyTarget._('Edit your reply...', 'Editing your reply');
}

/// The reply box pinned under the page: the reader's photo, a pill to type in and the send arrow, a line saying
/// whom the reply answers (or that an edit is under way) with an x to drop it, the refusal when a send failed, and
/// in place of all of it the reason a discussion takes no replies.
class ReplyComposerBar extends StatelessWidget {
  const ReplyComposerBar({
    super.key,
    required this.viewer,
    required this.input,
    required this.focus,
    required this.sending,
    required this.target,
    required this.onSend,
    required this.onClearTarget,
    this.error,
    this.lockedReason,
  });

  final FeedAuthor viewer;
  final TextEditingController input;
  final FocusNode focus;
  final bool sending;
  final ReplyTarget target;
  final VoidCallback onSend;
  final VoidCallback onClearTarget;
  final String? error;
  final String? lockedReason;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: lockedReason != null
              ? ForumNotice(key: const ValueKey('replies-locked'), icon: LucideIcons.lock, text: lockedReason!)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (target.label != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                target.label!,
                                key: const ValueKey('reply-target'),
                                style: ForumDesign.meta,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            InkResponse(
                              key: const ValueKey('reply-target-clear'),
                              onTap: onClearTarget,
                              radius: 16,
                              child: const Padding(
                                padding: EdgeInsets.all(2),
                                child: Icon(LucideIcons.x, size: 16, color: AppColors.outline),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 6),
                        child: Text(
                          error!,
                          key: const ValueKey('reply-error'),
                          style: AppText.small.copyWith(fontSize: 12, color: AppColors.error),
                        ),
                      ),
                    ReplyBox(
                      viewer: viewer,
                      controller: input,
                      focusNode: focus,
                      sending: sending,
                      hint: target.hint,
                      onSend: onSend,
                      newlines: true,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
