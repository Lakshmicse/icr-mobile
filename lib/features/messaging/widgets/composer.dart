import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../conversation_controller.dart';
import '../messaging_format.dart';
import '../messaging_models.dart';
import '../messaging_styles.dart';

/// The box a message is written in, with what hangs off it, as the thread design draws it: a row of pills (the
/// paperclip, "RFQ", "Meet", an emoji, and "Draft Saved" once a draft is kept), then the input as a grey pill and
/// the send arrow. Above the input: the message being answered, a file waiting to go, "writing as the company",
/// and the character count near the limit.
class Composer extends StatelessWidget {
  const Composer({
    super.key,
    required this.controller,
    required this.text,
    required this.focus,
    required this.onSend,
    this.onAttach,
    this.onShareRecord,
    this.onMeet,
    this.onEmoji,
    this.asCompany,
    this.draftSaved = false,
  });

  final ConversationController controller;
  final TextEditingController text;
  final FocusNode focus;
  final VoidCallback onSend;

  /// Null when the app has no file picker: no paperclip is drawn.
  final VoidCallback? onAttach;

  /// The "RFQ" pill: "Share an ICR record", opened on Requirements.
  final VoidCallback? onShareRecord;

  /// The "Meet" pill: the thread's own session record. Null when the thread has none: no pill is drawn.
  final VoidCallback? onMeet;
  final VoidCallback? onEmoji;

  /// The company the person answers as, when they read the thread from its inbox.
  final String? asCompany;

  /// A draft of the box is kept: "Draft Saved".
  final bool draftSaved;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final reply = c.replyTo;
    final file = c.attachment;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (asCompany != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    const Icon(LucideIcons.building2, size: 12, color: AppColors.slate500),
                    const SizedBox(width: 4),
                    Flexible(child: Text('Replying as $asCompany', style: ChatText.hint)),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Row(
                children: [
                  if (onAttach != null) ...[
                    IconButton(
                      key: const ValueKey('attach'),
                      tooltip: 'Attach a file',
                      onPressed: c.uploading ? null : onAttach,
                      icon: const Icon(LucideIcons.paperclip, size: 18),
                      style: _circle,
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (onShareRecord != null) ...[
                    _Pill(
                      key: const ValueKey('share-record'),
                      icon: LucideIcons.indianRupee,
                      label: 'RFQ',
                      hint: 'Share an ICR record',
                      onTap: onShareRecord!,
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (onMeet != null) ...[
                    _Pill(
                      key: const ValueKey('meet'),
                      icon: LucideIcons.calendarClock,
                      label: 'Meet',
                      hint: "Open this conversation's session",
                      onTap: onMeet!,
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (onEmoji != null)
                    IconButton(
                      key: const ValueKey('emoji'),
                      tooltip: 'Add an emoji',
                      onPressed: onEmoji,
                      icon: const Icon(LucideIcons.smile, size: 18),
                      style: _circle,
                    ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: text,
                        builder: (context, value, _) {
                          final length = value.text.length;
                          if (length > messageBodyMax - 500) {
                            return Text(
                              '$length/$messageBodyMax',
                              style: ChatText.draftSaved.copyWith(
                                color: length > messageBodyMax ? ChatColors.failed : null,
                              ),
                            );
                          }
                          return draftSaved
                              ? Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Text(
                                    'Draft Saved',
                                    key: const ValueKey('draft-saved'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: ChatText.draftSaved,
                                  ),
                                )
                              : const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (reply != null)
              _Bar(
                key: const ValueKey('reply-bar'),
                icon: LucideIcons.reply,
                title: 'Replying to ${reply.sender?.firstName ?? reply.senderCompany?.name ?? 'message'}',
                detail: reply.deleted
                    ? 'Deleted message'
                    : (reply.body.isNotEmpty ? reply.body : (reply.attachmentName ?? 'Attachment')),
                onClose: () => c.setReplyTo(null),
              ),
            if (c.uploading)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 8),
                    Flexible(child: Text('Uploading ${c.uploadingName}…', style: ChatText.hint)),
                  ],
                ),
              ),
            if (file != null)
              _Bar(
                key: const ValueKey('attachment-bar'),
                icon: LucideIcons.paperclip,
                title: file.name,
                detail: fileSize(file.size),
                onClose: c.removeAttachment,
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 10, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: ChatColors.search,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.outlineVariant),
                      ),
                      child: TextField(
                        key: const ValueKey('composer'),
                        controller: text,
                        focusNode: focus,
                        minLines: 1,
                        maxLines: 5,
                        style: ChatText.composer,
                        textCapitalization: TextCapitalization.sentences,
                        keyboardType: TextInputType.multiline,
                        decoration: InputDecoration(
                          isCollapsed: false,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          border: InputBorder.none,
                          hintText: 'Write a message or attach RFP...',
                          hintStyle: ChatText.composerHintDesign,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: text,
                    builder: (context, value, _) {
                      final can = !c.uploading && (value.text.trim().isNotEmpty || file != null);
                      return Material(
                        color: Colors.transparent,
                        shape: const CircleBorder(),
                        child: InkWell(
                          key: const ValueKey('send'),
                          customBorder: const CircleBorder(),
                          onTap: can ? onSend : null,
                          child: Semantics(
                            button: true,
                            label: 'Send',
                            enabled: can,
                            child: SizedBox(
                              width: 44,
                              height: 40,
                              child: Icon(
                                Icons.send,
                                size: 22,
                                // The design's idle arrow is slate; it turns blue once there is something to send.
                                color: can ? AppColors.primary : AppColors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The paperclip and the emoji: a grey circle.
  static final _circle = IconButton.styleFrom(
    backgroundColor: ChatColors.composerChip,
    disabledBackgroundColor: ChatColors.composerChip,
    foregroundColor: AppColors.onSurfaceVariant,
    disabledForegroundColor: AppColors.slate400,
    fixedSize: const Size(36, 36),
    minimumSize: const Size(36, 36),
    padding: EdgeInsets.zero,
    shape: const CircleBorder(),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );
}

/// "RFQ" or "Meet": an icon and a word on a grey pill.
class _Pill extends StatelessWidget {
  const _Pill({super.key, required this.icon, required this.label, required this.hint, required this.onTap});

  final IconData icon;
  final String label;

  /// What a screen reader says in place of the short label.
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: hint,
    excludeSemantics: true,
    child: Material(
      color: ChatColors.composerChip,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: SizedBox(
          height: 36,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: AppColors.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(label, style: ChatText.composerChip),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _Bar extends StatelessWidget {
  const _Bar({super.key, required this.icon, required this.title, required this.detail, required this.onClose});

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
    padding: const EdgeInsets.fromLTRB(10, 6, 2, 6),
    decoration: BoxDecoration(
      color: ChatColors.strip,
      borderRadius: BorderRadius.circular(10),
      border: const Border(left: BorderSide(color: AppColors.primary, width: 3)),
    ),
    child: Row(
      children: [
        Icon(icon, size: 15, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: ChatText.quoteName),
              if (detail.isNotEmpty)
                Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: ChatText.quoteText),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Remove',
          visualDensity: VisualDensity.compact,
          onPressed: onClose,
          icon: const Icon(LucideIcons.x, size: 16, color: AppColors.slate500),
        ),
      ],
    ),
  );
}
