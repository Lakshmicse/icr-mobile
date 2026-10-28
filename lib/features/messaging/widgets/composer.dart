import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../conversation_controller.dart';
import '../messaging_format.dart';
import '../messaging_models.dart';
import '../messaging_styles.dart';

/// The box a message is written in, with what hangs off it: the message being
/// answered, a file waiting to go, "writing as the company", the character count
/// near the limit, and the send button.
class Composer extends StatelessWidget {
  const Composer({
    super.key,
    required this.controller,
    required this.text,
    required this.focus,
    required this.onSend,
    this.onAttach,
    this.onShareRecord,
    this.asCompany,
  });

  final ConversationController controller;
  final TextEditingController text;
  final FocusNode focus;
  final VoidCallback onSend;

  /// Null when the app has no file picker: no paperclip is drawn.
  final VoidCallback? onAttach;
  final VoidCallback? onShareRecord;

  /// The company the person answers as, when they read the thread from its inbox.
  final String? asCompany;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final reply = c.replyTo;
    final file = c.attachment;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: ChatColors.rule)),
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
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (onAttach != null)
                    IconButton(
                      key: const ValueKey('attach'),
                      tooltip: 'Attach a file',
                      onPressed: c.uploading ? null : onAttach,
                      icon: const Icon(LucideIcons.paperclip, size: 22, color: AppColors.slate500),
                    ),
                  if (onShareRecord != null)
                    IconButton(
                      key: const ValueKey('share-record'),
                      tooltip: 'Share an ICR record',
                      onPressed: onShareRecord,
                      icon: const Icon(LucideIcons.link2, size: 22, color: AppColors.slate500),
                    ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.slate50,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: AppColors.slate200),
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
                          hintText: 'Write a message',
                          hintStyle: ChatText.composerHint,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: text,
                    builder: (context, value, _) {
                      final can = !c.uploading && (value.text.trim().isNotEmpty || file != null);
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (value.text.length > messageBodyMax - 500)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                '${value.text.length}/$messageBodyMax',
                                style: ChatText.meta.copyWith(
                                  color: value.text.length > messageBodyMax ? ChatColors.failed : null,
                                ),
                              ),
                            ),
                          Material(
                            color: can ? AppColors.primary : AppColors.slate200,
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
                                  width: 42,
                                  height: 42,
                                  child: Icon(
                                    LucideIcons.send,
                                    size: 19,
                                    color: can ? Colors.white : AppColors.slate400,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
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
