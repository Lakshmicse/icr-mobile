import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../conversation_controller.dart';
import '../messaging_format.dart';
import '../messaging_models.dart';
import '../messaging_styles.dart';
import 'chat_avatar.dart';
import 'record_card.dart';

/// Text whose web links are tappable. A link the reader taps goes to [onLink].
class LinkedText extends StatefulWidget {
  const LinkedText({super.key, required this.text, required this.style, required this.linkColor, required this.onLink});

  final String text;
  final TextStyle style;
  final Color linkColor;
  final ValueChanged<String> onLink;

  @override
  State<LinkedText> createState() => _LinkedTextState();
}

class _LinkedTextState extends State<LinkedText> {
  final _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
    final spans = <InlineSpan>[];
    var at = 0;
    for (final m in linksIn(widget.text)) {
      if (m.start > at) spans.add(TextSpan(text: widget.text.substring(at, m.start)));
      // Trailing punctuation belongs to the sentence, not the link.
      final raw = m.group(0)!;
      final url = raw.replaceFirst(RegExp(r'[.,;:!?)\]]+$'), '');
      final tap = TapGestureRecognizer()..onTap = () => widget.onLink(url);
      _recognizers.add(tap);
      spans.add(
        TextSpan(
          text: url,
          recognizer: tap,
          style: TextStyle(
            color: widget.linkColor,
            decoration: TextDecoration.underline,
            decorationColor: widget.linkColor,
          ),
        ),
      );
      if (url.length < raw.length) spans.add(TextSpan(text: raw.substring(url.length)));
      at = m.end;
    }
    if (at < widget.text.length) spans.add(TextSpan(text: widget.text.substring(at)));
    return Text.rich(TextSpan(children: spans), style: widget.style);
  }
}

/// A day separator.
class DayDivider extends StatelessWidget {
  const DayDivider({super.key, required this.date, this.now});

  final DateTime date;
  final DateTime? now;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: AppColors.slate100, borderRadius: BorderRadius.circular(10)),
        child: Text(dayLabel(date, now: now), style: ChatText.day),
      ),
    ),
  );
}

/// A business event across the timeline: a bid placed, a session held.
class EventLine extends StatelessWidget {
  const EventLine({super.key, required this.title, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
    child: Row(
      children: [
        const Expanded(child: Divider(height: 1, color: ChatColors.rule)),
        const SizedBox(width: 10),
        Flexible(
          flex: 4,
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              Text(title, textAlign: TextAlign.center, style: ChatText.event),
              if (action != null && onAction != null)
                GestureDetector(
                  onTap: onAction,
                  child: Text(
                    action!,
                    style: ChatText.event.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(child: Divider(height: 1, color: ChatColors.rule)),
      ],
    ),
  );
}

/// One message in a thread: the bubble, what it quotes, its file and the
/// records it shares, and under it the time (and "Seen").
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.mine,
    required this.continued,
    required this.controller,
    required this.onLink,
    required this.onOpenAttachment,
    this.showSender = false,
    this.seen = false,
    this.onLongPress,
    this.onOpenRecord,
    this.onJumpToReply,
  });

  final ChatMessage message;
  final bool mine;

  /// Same sender as the row above, within five minutes: no name, tighter.
  final bool continued;
  final ConversationController controller;
  final bool showSender;
  final bool seen;
  final VoidCallback? onLongPress;
  final ValueChanged<String> onLink;
  final ValueChanged<RecordRef>? onOpenRecord;
  final void Function(ChatMessage message) onOpenAttachment;
  final ValueChanged<String>? onJumpToReply;

  @override
  Widget build(BuildContext context) {
    final m = message;
    final width = MediaQuery.sizeOf(context).width;
    final shared = m.deleted ? (text: '', records: const <RecordRef>[]) : splitRecordLinks(m.body, recordOrigins());
    final hasText = shared.text.trim().isNotEmpty;
    final sender = m.senderCompany?.name ?? m.sender?.fullName ?? '';
    final color = mine ? ChatColors.myBubble : ChatColors.theirBubble;
    final ink = mine ? Colors.white : AppColors.onSurface;

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: width * 0.78),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: m.deleted ? Colors.white : color,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(mine ? 16 : 4),
          bottomRight: Radius.circular(mine ? 4 : 16),
        ),
        border: m.deleted ? Border.all(color: AppColors.slate200) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showSender && !mine && !continued && sender.isNotEmpty) ...[
            Text(sender, style: ChatText.sender),
            const SizedBox(height: 2),
          ],
          if (m.deleted)
            Text('This message was deleted', style: ChatText.deleted)
          else ...[
            if (m.replyTo != null) _Quote(reply: m.replyTo!, mine: mine, onTap: onJumpToReply),
            if (hasText)
              LinkedText(
                text: shared.text,
                style: mine ? ChatText.bubbleMine : ChatText.bubble,
                linkColor: mine ? Colors.white : AppColors.primary,
                onLink: onLink,
              ),
            if (m.hasAttachment) ...[
              if (hasText || m.replyTo != null) const SizedBox(height: 6),
              AttachmentView(message: m, mine: mine, controller: controller, onOpen: () => onOpenAttachment(m)),
            ],
            for (final ref in shared.records) ...[
              SizedBox(height: hasText || m.hasAttachment ? 6 : 0),
              RecordCard(ref: ref, load: controller.record, onOpen: onOpenRecord, now: controller.clock()),
            ],
          ],
        ],
      ),
    );

    final footer = <Widget>[
      Text(
        clockTime(m.createdAt),
        style: ChatText.meta.copyWith(color: ink == Colors.white ? AppColors.outline : null),
      ),
      if (seen) ...[
        const SizedBox(width: 6),
        const Icon(LucideIcons.checkCheck, size: 12, color: AppColors.primary),
        const SizedBox(width: 2),
        Text('Seen', style: ChatText.meta.copyWith(color: AppColors.primary)),
      ],
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(12, continued ? 2 : 8, 12, 0),
      child: Row(
        mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                GestureDetector(onLongPress: onLongPress, child: bubble),
                if (!continued || seen)
                  Padding(
                    padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                    child: Row(mainAxisSize: MainAxisSize.min, children: footer),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Quote extends StatelessWidget {
  const _Quote({required this.reply, required this.mine, this.onTap});

  final MessageReply reply;
  final bool mine;
  final ValueChanged<String>? onTap;

  @override
  Widget build(BuildContext context) {
    final text = reply.deleted
        ? 'Deleted message'
        : (reply.excerpt.isNotEmpty ? reply.excerpt : (reply.attachmentName ?? 'Attachment'));
    return GestureDetector(
      onTap: onTap == null ? null : () => onTap!(reply.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        decoration: BoxDecoration(
          color: mine ? Colors.white.withValues(alpha: 0.16) : Colors.white,
          border: Border(left: BorderSide(color: mine ? Colors.white70 : ChatColors.quoteBar, width: 3)),
          borderRadius: const BorderRadius.horizontal(right: Radius.circular(6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(reply.senderName, style: ChatText.quoteName.copyWith(color: mine ? Colors.white : null)),
            Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: ChatText.quoteText.copyWith(
                color: mine ? Colors.white.withValues(alpha: 0.9) : null,
                fontStyle: reply.deleted ? FontStyle.italic : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A file in a message: a photo drawn from its (private) bytes, anything
/// else as a row with its name and size. A tap opens it.
class AttachmentView extends StatelessWidget {
  const AttachmentView({
    super.key,
    required this.message,
    required this.mine,
    required this.controller,
    required this.onOpen,
  });

  final ChatMessage message;
  final bool mine;
  final ConversationController controller;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final m = message;
    final name = m.attachmentName ?? 'Attachment';
    if (m.isImage) {
      return GestureDetector(
        key: ValueKey('attachment-${m.id}'),
        // A picture is not hit-testable by itself: without this a tap on the photo goes nowhere.
        behavior: HitTestBehavior.opaque,
        onTap: onOpen,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: FutureBuilder<Uint8List>(
            future: controller.attachmentBytes(m.attachmentUrl!),
            builder: (context, snap) {
              final bytes = snap.data;
              if (bytes != null && bytes.isNotEmpty) {
                return Image.memory(
                  bytes,
                  width: 220,
                  fit: BoxFit.cover,
                  semanticLabel: name,
                  // Keeps the bubble's size while the picture decodes, so the thread does not jump.
                  frameBuilder: (context, child, frame, sync) => sync || frame != null
                      ? child
                      : const SizedBox(width: 220, height: 120, child: ColoredBox(color: AppColors.slate200)),
                );
              }
              return Container(
                width: 220,
                height: 120,
                color: AppColors.slate200,
                alignment: Alignment.center,
                child: snap.connectionState == ConnectionState.done
                    ? const Icon(LucideIcons.imageOff, color: AppColors.slate500)
                    : const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              );
            },
          ),
        ),
      );
    }
    final size = fileSize(m.attachmentSize);
    return InkWell(
      key: ValueKey('attachment-${m.id}'),
      onTap: onOpen,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        constraints: const BoxConstraints(minWidth: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: mine ? Colors.white.withValues(alpha: 0.16) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: mine ? Colors.white30 : AppColors.slate200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.fileText, size: 20, color: mine ? Colors.white : AppColors.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ChatText.label.copyWith(color: mine ? Colors.white : null),
                  ),
                  if (size.isNotEmpty) Text(size, style: ChatText.hint.copyWith(color: mine ? Colors.white70 : null)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(LucideIcons.download, size: 16, color: mine ? Colors.white : AppColors.slate500),
          ],
        ),
      ),
    );
  }
}

/// A message on its way (or one the API refused): the person's own words
/// where they will be, "Sending…" or Retry / Discard under them.
class PendingBubble extends StatelessWidget {
  const PendingBubble({super.key, required this.pending, required this.onRetry, required this.onDiscard});

  final PendingMessage pending;
  final VoidCallback onRetry;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final p = pending;
    final width = MediaQuery.sizeOf(context).width;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Align(
        alignment: Alignment.centerRight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Opacity(
              opacity: p.failed ? 1 : 0.7,
              child: Container(
                constraints: BoxConstraints(maxWidth: width * 0.78),
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                decoration: BoxDecoration(
                  color: ChatColors.myBubble,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(4),
                  ),
                  border: p.failed ? Border.all(color: ChatColors.failed, width: 1.5) : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (p.body.isNotEmpty) Text(p.body, style: ChatText.bubbleMine),
                    if (p.attachment != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.paperclip, size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                          Flexible(child: Text(p.attachment!.name, style: ChatText.bubbleMine.copyWith(fontSize: 13))),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 3, right: 4),
              child: p.failed
                  ? Wrap(
                      spacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          p.error ?? 'Not sent',
                          style: ChatText.meta.copyWith(color: ChatColors.failed, fontWeight: FontWeight.w600),
                        ),
                        GestureDetector(
                          key: const ValueKey('pending-retry'),
                          onTap: onRetry,
                          child: Text(
                            'Retry',
                            style: ChatText.meta.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                          ),
                        ),
                        GestureDetector(
                          key: const ValueKey('pending-discard'),
                          onTap: onDiscard,
                          child: Text('Discard', style: ChatText.meta.copyWith(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    )
                  : Text('Sending…', style: ChatText.meta),
            ),
          ],
        ),
      ),
    );
  }
}

/// Everyone's avatar for a room's header or an inbox row, by the display's kind.
Widget displayAvatar(ConversationDisplay d, {double size = 36}) => ChatAvatar.forDisplay(d, size: size);
