import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../messaging_format.dart';
import '../messaging_models.dart';
import '../messaging_styles.dart';
import 'chat_avatar.dart';

/// Each kind's glyph (the website's `KIND_ICON`).
IconData kindIcon(ConversationKind kind) => switch (kind) {
  ConversationKind.requirement => LucideIcons.clipboardList,
  ConversationKind.bid => LucideIcons.fileText,
  ConversationKind.enquiry => LucideIcons.messageCircleQuestion,
  ConversationKind.mentorship => LucideIcons.graduationCap,
  ConversationKind.groupSession => LucideIcons.users,
  ConversationKind.consultation => LucideIcons.messagesSquare,
  ConversationKind.company => LucideIcons.building2,
  ConversationKind.direct => LucideIcons.user,
};

/// One conversation in the inbox: who it is with, why it exists, the last
/// word, when, and whether anything is waiting. Unread is said three ways:
/// weight, a count and words for a screen reader, never by colour alone.
class ConversationTile extends StatelessWidget {
  const ConversationTile({
    super.key,
    required this.conversation,
    required this.meId,
    required this.onTap,
    this.onLongPress,
    this.now,
  });

  final Conversation conversation;
  final String? meId;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final display = conversationDisplay(
      participants: c.participants,
      meId: meId,
      title: c.title,
      kind: c.kind,
      counterpartCompany: c.counterpartCompany,
      contextLabel: c.contextLabel,
    );
    final unread = c.unread;
    final about = conversationAbout(c, display);
    final last = c.lastMessage;
    final preview = messagePreview(last, meId: meId, asCompanyId: c.asCompanyId);
    final when = listTime(last?.createdAt ?? c.updatedAt, now: now);
    // One sentence for a screen reader, in reading order, instead of every piece read out on its own.
    final spoken = [
      display.name,
      if (unread > 0) '$unread unread',
      if (c.pinned) 'pinned',
      if (c.starred) 'starred',
      if (c.kind != null) c.kind!.label,
      ?about,
      preview,
      when,
    ].join(', ');
    return Semantics(
      button: true,
      label: spoken,
      excludeSemantics: true,
      onTap: onTap,
      onLongPress: onLongPress,
      onLongPressHint: 'Star or pin',
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ChatAvatar.forDisplay(display, size: 46),
                  if (unread > 0)
                    Positioned(
                      top: -1,
                      right: -1,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            display.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: unread > 0 ? ChatText.rowNameUnread : ChatText.rowName,
                          ),
                        ),
                        if (c.pinned) ...[
                          const SizedBox(width: 4),
                          const Icon(LucideIcons.pin, size: 13, color: AppColors.slate500, semanticLabel: 'Pinned'),
                        ],
                        if (c.starred) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.star_rounded, size: 15, color: ChatColors.star, semanticLabel: 'Starred'),
                        ],
                        const SizedBox(width: 8),
                        Text(when, style: unread > 0 ? ChatText.rowTimeUnread : ChatText.rowTime),
                      ],
                    ),
                    if (c.kind != null || about != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (c.kind != null) KindBadge(kind: c.kind!),
                          if (c.kind != null && about != null) const SizedBox(width: 6),
                          if (about != null)
                            Flexible(
                              child: Text(
                                about,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: ChatText.rowAbout,
                              ),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (last != null && last.hasAttachment) ...[
                          const Icon(LucideIcons.paperclip, size: 13, color: AppColors.slate500),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: (unread > 0 ? ChatText.rowPreviewUnread : ChatText.rowPreview).copyWith(
                              fontStyle: last?.deleted == true ? FontStyle.italic : null,
                            ),
                          ),
                        ),
                        if (unread > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            constraints: const BoxConstraints(minWidth: 20),
                            height: 20,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('$unread', style: ChatText.count),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Enquiry", "Mentorship": why the thread exists, as a small outlined badge.
class KindBadge extends StatelessWidget {
  const KindBadge({super.key, required this.kind});

  final ConversationKind kind;

  @override
  Widget build(BuildContext context) => Container(
    height: 20,
    padding: const EdgeInsets.symmetric(horizontal: 6),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.slate200),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(kindIcon(kind), size: 12, color: AppColors.slate600),
        const SizedBox(width: 4),
        Text(kind.label, style: ChatText.kindBadge),
      ],
    ),
  );
}

/// A message that matched a search: the thread it is in, the snippet, when.
class SearchHitTile extends StatelessWidget {
  const SearchHitTile({super.key, required this.hit, required this.meId, required this.onTap, this.now});

  final MessageSearchHit hit;
  final String? meId;
  final VoidCallback onTap;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final display = conversationDisplay(participants: hit.participants, meId: meId, title: hit.conversationTitle);
    final from = hit.sender == null ? '' : (hit.sender!.id == meId ? 'You: ' : '${hit.sender!.firstName}: ');
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ChatAvatar.forDisplay(display, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          display.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ChatText.rowName,
                        ),
                      ),
                      Text(listTime(hit.createdAt, now: now), style: ChatText.rowTime),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('$from${hit.snippet}', maxLines: 2, overflow: TextOverflow.ellipsis, style: ChatText.rowPreview),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
