import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../messaging_format.dart';
import '../messaging_models.dart';
import '../messaging_styles.dart';
import 'chat_avatar.dart';

/// The inbox's stamp: "10:42 AM" for today, "Yesterday", a weekday, else "Apr 14" (the design's order), on
/// the website's `useListTime` rules.
String inboxStamp(DateTime at, {DateTime? now}) {
  final stamp = listTime(at, now: now);
  final clock = RegExp(r'^(\d{1,2}:\d{2}) (am|pm)$').firstMatch(stamp);
  if (clock != null) return '${clock.group(1)} ${clock.group(2)!.toUpperCase()}';
  final date = RegExp(r'^(\d{1,2}) ([A-Z][a-z]{2})(?: (\d{4}))?$').firstMatch(stamp);
  if (date != null) return '${date.group(2)} ${date.group(1)}${date.group(3) == null ? '' : ', ${date.group(3)}'}';
  return stamp;
}

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

/// Whether the other side carries ICR's verified check in the list. The list's [Conversation] has no such
/// flag yet (the check belongs to the thread's context company, which only the thread's own read carries), so
/// this is false until the model does; a test or a caller with the fact passes it to [ConversationTile].
bool conversationVerified(Conversation c) => c.verified;

enum _ChipTone { blue, grey, amber }

/// The thread's one context chip: the requirement or room or topic it is about, else why it exists. Never the
/// same words as the name above it.
({String label, _ChipTone tone})? _contextChip(Conversation c, ConversationDisplay display, String? about) {
  final kind = c.kind;
  String? pick(List<String?> options) {
    for (final o in options) {
      final text = o?.trim();
      if (text != null && text.isNotEmpty && text.toLowerCase() != display.name.trim().toLowerCase()) return text;
    }
    return null;
  }

  final label = pick([c.contextLabel, about, kind?.label]);
  if (label == null) return null;
  if (kind != null && kind.isRequirement) return (label: label, tone: _ChipTone.amber);
  if (kind == ConversationKind.mentorship ||
      kind == ConversationKind.groupSession ||
      kind == ConversationKind.consultation) {
    return (label: label, tone: _ChipTone.grey);
  }
  // A council or chapter, and a company inbox's topic, read blue; anything else a plain grey chip.
  final council = RegExp(r'council|chapter', caseSensitive: false).hasMatch(label);
  final topic = c.asCompanyId != null && label == about;
  return (label: label, tone: council || topic ? _ChipTone.blue : _ChipTone.grey);
}

/// One conversation in the inbox: who it is with, the line that says who they are, the context chip, the last
/// word, when, and whether anything is waiting. Unread is said by a tinted row with a bar down its edge, a bold
/// time, a count and words for a screen reader, never by colour alone.
class ConversationTile extends StatelessWidget {
  const ConversationTile({
    super.key,
    required this.conversation,
    required this.meId,
    required this.onTap,
    this.onLongPress,
    this.now,
    this.verified,
  });

  final Conversation conversation;
  final String? meId;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final DateTime? now;

  /// The verified check after a person's name; defaults to [conversationVerified].
  final bool? verified;

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
    final isUnread = unread > 0;
    final about = conversationAbout(c, display);
    final chip = _contextChip(c, display, about);
    final kindLabel = c.kind?.label;
    final personHeadline = display.person?.headline?.trim();
    // The line under the name: who they are, else (the chip having named the context) why the thread exists.
    final headline = personHeadline != null && personHeadline.isNotEmpty
        ? personHeadline
        : (kindLabel != null && chip != null && chip.label != kindLabel ? kindLabel : null);
    final last = c.lastMessage;
    final preview = messagePreview(last, meId: meId, asCompanyId: c.asCompanyId);
    final when = inboxStamp(last?.createdAt ?? c.updatedAt, now: now);
    // One sentence for a screen reader, in reading order, instead of every piece read out on its own.
    final spoken = [
      display.name,
      if (isUnread) '$unread unread',
      if (c.pinned) 'pinned',
      if (c.starred) 'starred',
      ?kindLabel,
      if (chip != null && chip.label != kindLabel) chip.label,
      ?headline,
      preview,
      when,
    ].join(', ');
    final requirement = c.kind?.isRequirement ?? false;
    // The design tints and bars the unread row, but a requirement thread's unread is its green count alone.
    final emphasised = isUnread && !requirement;
    final showCheck = display.avatar == AvatarKind.person && (verified ?? conversationVerified(c));
    final mentor =
        display.avatar == AvatarKind.person &&
        (c.kind == ConversationKind.mentorship || c.kind == ConversationKind.consultation);

    final badge = display.avatar == AvatarKind.company
        ? const Icon(Symbols.apartment, fill: 1, size: 14, color: InboxColors.navy, semanticLabel: 'Company')
        : showCheck
        ? const Icon(Symbols.verified, fill: 1, size: 16, color: InboxColors.navy, semanticLabel: 'Verified')
        : mentor
        ? const Icon(Symbols.shield, fill: 1, size: 13, color: InboxColors.green, semanticLabel: 'Mentorship')
        : null;

    final amber = chip?.tone == _ChipTone.amber;
    return Semantics(
      button: true,
      label: spoken,
      excludeSemantics: true,
      onTap: onTap,
      onLongPress: onLongPress,
      onLongPressHint: 'Star or pin',
      child: Material(
        color: emphasised ? InboxColors.unreadTint : Colors.white,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.only(left: emphasised ? 12 : 8, right: 9),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: ChatAvatar.forDisplay(display, size: 45, round: true, online: display.person?.online),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        // An unread row leaves the count's column (14 gap, 16 circle) clear at the right.
                        padding: EdgeInsets.only(top: 6, bottom: 8, right: isUnread ? 30 : 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Align(
                                    alignment: AlignmentDirectional.centerStart,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            display.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: InboxText.name,
                                          ),
                                        ),
                                        if (badge != null) ...[const SizedBox(width: 4), badge],
                                      ],
                                    ),
                                  ),
                                ),
                                if (c.pinned) ...[
                                  const SizedBox(width: 6),
                                  const Icon(
                                    LucideIcons.pin,
                                    size: 13,
                                    color: AppColors.slate500,
                                    semanticLabel: 'Pinned',
                                  ),
                                ],
                                if (c.starred) ...[
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.star_rounded,
                                    size: 15,
                                    color: AppColors.amber500,
                                    semanticLabel: 'Starred',
                                  ),
                                ],
                                const SizedBox(width: 8),
                                Text(when, style: emphasised ? InboxText.timeUnread : InboxText.time),
                              ],
                            ),
                            if (headline != null)
                              Text(headline, maxLines: 1, overflow: TextOverflow.ellipsis, style: InboxText.headline),
                            if (chip != null)
                              Padding(
                                // The amber chip's edge hangs 1 dp outside the text box the others share.
                                padding: EdgeInsets.only(top: amber ? 6 : 7, bottom: 1.5),
                                child: _ContextChip(label: chip.label, tone: chip.tone),
                              )
                            else
                              const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (last != null && last.hasAttachment)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 3, right: 4),
                                    child: Icon(LucideIcons.paperclip, size: 13, color: AppColors.slate500),
                                  ),
                                Expanded(
                                  child: Text(
                                    preview,
                                    maxLines: emphasised ? 2 : 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: (emphasised ? InboxText.previewUnread : InboxText.preview).copyWith(
                                      fontStyle: last?.deleted == true ? FontStyle.italic : null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (emphasised)
                const Positioned(left: 0, top: 0, bottom: 0, width: 4, child: ColoredBox(color: InboxColors.navy)),
              if (isUnread)
                Positioned(
                  right: 9,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _CountDot(count: unread, color: requirement ? InboxColors.green : InboxColors.navy),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContextChip extends StatelessWidget {
  const _ContextChip({required this.label, required this.tone});

  final String label;
  final _ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final amber = tone == _ChipTone.amber;
    return Container(
      height: amber ? 21 : 19,
      padding: EdgeInsets.symmetric(horizontal: amber ? 7 : 6),
      decoration: BoxDecoration(
        color: switch (tone) {
          _ChipTone.blue => InboxColors.blueTint,
          _ChipTone.grey => InboxColors.grey,
          _ChipTone.amber => InboxColors.amberTint,
        },
        borderRadius: BorderRadius.circular(3),
        border: amber ? Border.all(color: InboxColors.amberEdge) : null,
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: switch (tone) {
            _ChipTone.blue => InboxText.chipBlue,
            _ChipTone.grey => InboxText.chipGrey,
            _ChipTone.amber => InboxText.chipAmber,
          },
        ),
      ),
    );
  }
}

/// The unread count: a 16 dp disc (it stretches into a pill for two digits).
class _CountDot extends StatelessWidget {
  const _CountDot({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
    padding: const EdgeInsets.symmetric(horizontal: 4),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
    child: Center(widthFactor: 1, heightFactor: 1, child: Text(count > 99 ? '99+' : '$count', style: InboxText.count)),
  );
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
        Text(kind.label, style: InboxText.chipGrey),
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
        padding: const EdgeInsets.fromLTRB(8, 10, 9, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ChatAvatar.forDisplay(display, size: 36, round: true),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(display.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: InboxText.name),
                      ),
                      Text(inboxStamp(hit.createdAt, now: now), style: InboxText.time),
                    ],
                  ),
                  Text('$from${hit.snippet}', maxLines: 2, overflow: TextOverflow.ellipsis, style: InboxText.preview),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
