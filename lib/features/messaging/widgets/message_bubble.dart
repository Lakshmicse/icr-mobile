import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../conversation_controller.dart';
import '../messaging_context.dart';
import '../messaging_format.dart';
import '../messaging_models.dart';
import '../messaging_styles.dart';
import 'record_card.dart';

// --- avatars ---------------------------------------------------------------------------------------------------------

/// A person's photo (their initials without one), a company's logo or a room's glyph, in the design's rounded
/// square, with the small verified badge at its bottom-right corner when [verified].
class ThreadAvatar extends StatelessWidget {
  const ThreadAvatar({
    super.key,
    required this.picture,
    required this.name,
    this.size = 32,
    this.company = false,
    this.group = false,
    this.verified = false,
  });

  /// How a conversation draws: its display's kind decides the picture.
  factory ThreadAvatar.forDisplay(ConversationDisplay d, {double size = 36, bool verified = false}) =>
      switch (d.avatar) {
        AvatarKind.person => ThreadAvatar(picture: d.person?.photo, name: d.name, size: size, verified: verified),
        AvatarKind.company => ThreadAvatar(
          picture: d.company?.logo,
          name: d.name,
          size: size,
          company: true,
          verified: verified,
        ),
        AvatarKind.group => ThreadAvatar(picture: null, name: d.name, size: size, group: true),
      };

  final ChatPicture? picture;
  final String name;
  final double size;
  final bool company;
  final bool group;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    final badge = size * 0.39;
    return Semantics(
      image: true,
      label: name,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: ClipRRect(borderRadius: BorderRadius.circular(size * 0.36), child: _face()),
            ),
            if (verified)
              Positioned(
                right: -size * 0.06,
                bottom: -size * 0.06,
                child: Container(
                  key: const ValueKey('verified-badge'),
                  width: badge,
                  height: badge,
                  decoration: const BoxDecoration(color: ThreadColors.deepBlue, shape: BoxShape.circle),
                  child: Icon(LucideIcons.check, size: badge * 0.64, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _face() {
    if (group) {
      return ColoredBox(
        color: const Color(0xFFE7EEFF),
        child: Icon(LucideIcons.users, size: size * 0.45, color: AppColors.primary),
      );
    }
    final fallback = ColoredBox(
      color: company ? AppColors.slate100 : const Color(0xFFDCE6F2),
      child: Center(
        child: Text(
          initialsOf(name),
          style: TextStyle(
            fontFamily: AppText.work,
            fontWeight: FontWeight.w600,
            fontSize: size * 0.36,
            color: company ? AppColors.slate600 : AppColors.primary,
            height: 1,
          ),
        ),
      ),
    );
    final p = picture;
    if (p?.asset != null) return Image.asset(p!.asset!, fit: BoxFit.cover, width: size, height: size);
    if (p?.url != null) {
      return CachedNetworkImage(
        imageUrl: p!.url!,
        fit: company ? BoxFit.contain : BoxFit.cover,
        width: size,
        height: size,
        placeholder: (_, _) => fallback,
        errorWidget: (_, _, _) => fallback,
      );
    }
    return fallback;
  }
}

// --- text with links ---------------------------------------------------------------------------------------------------

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

// --- day pill and events -------------------------------------------------------------------------------------------

/// A day separator: a white pill with a calendar and the day in lower case ("today, april 16").
class DayDivider extends StatelessWidget {
  const DayDivider({super.key, required this.date, this.now});

  final DateTime date;
  final DateTime? now;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: ThreadColors.lift,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.calendar, size: 16, color: AppColors.onSurfaceVariant),
            const SizedBox(width: 6),
            Flexible(
              child: Text(threadDayLabel(date, now: now), style: ChatText.dayPill),
            ),
          ],
        ),
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
        const Expanded(child: Divider(height: 1, color: ThreadColors.edge)),
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
        const Expanded(child: Divider(height: 1, color: ThreadColors.edge)),
      ],
    ),
  );
}

// --- one message -----------------------------------------------------------------------------------------------------

/// A bubble's corners: [round] everywhere, but the first message of a block ([tail]) has the corner nearest its
/// avatar side (top-left for theirs, top-right for mine) nearly square.
BorderRadius _corners({required bool mine, required bool tail, required double round}) {
  final big = Radius.circular(round);
  final small = tail ? const Radius.circular(2) : big;
  return BorderRadius.only(
    topLeft: mine ? big : small,
    topRight: mine ? small : big,
    bottomLeft: big,
    bottomRight: big,
  );
}

/// One message in a thread, as the design draws it. Theirs: their avatar, "Name  10:14 AM", then a white
/// bubble (the first of a block with its top-left corner small); mine: a blue bubble at the right with the time
/// and a tick under it. A file, a photo or a shared record sits under the bubble as its own card.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.mine,
    required this.continued,
    required this.controller,
    required this.onLink,
    required this.onOpenAttachment,
    this.endsBlock = true,
    this.seen = false,
    this.verified = false,
    this.onLongPress,
    this.onOpenRecord,
    this.onJumpToReply,
  });

  final ChatMessage message;
  final bool mine;

  /// Same sender as the row above, within five minutes: no avatar or name, tighter.
  final bool continued;

  /// The last message of its block: mine carries its time and tick here.
  final bool endsBlock;
  final ConversationController controller;

  /// The other person has read this message of mine (a one-to-one thread).
  final bool seen;

  /// Their avatar wears the verified badge (the other side's company is verified).
  final bool verified;
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
    final hasQuote = !m.deleted && m.replyTo != null;
    final maxWidth = mine ? width * 0.8 : math.min(width * 0.7, width - 72.5);
    final solid = mine && !m.deleted;

    final bubble = !(m.deleted || hasText || hasQuote)
        ? null
        : Container(
            constraints: BoxConstraints(maxWidth: maxWidth),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: solid ? ChatColors.myBubble : Colors.white,
              borderRadius: _corners(mine: mine, tail: !continued, round: mine ? 16 : 10),
              border: solid ? null : Border.all(color: ThreadColors.edge),
              boxShadow: solid ? null : ThreadColors.lift,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (m.deleted)
                  Text('This message was deleted', style: ChatText.deleted)
                else ...[
                  if (hasQuote) _Quote(reply: m.replyTo!, mine: mine, onTap: onJumpToReply),
                  if (hasText)
                    LinkedText(
                      text: shared.text,
                      style: mine ? ChatText.bubbleMineText : ChatText.bubbleTheirs,
                      linkColor: mine ? Colors.white : AppColors.primary,
                      onLink: onLink,
                    ),
                ],
              ],
            ),
          );

    final pieces = <Widget>[
      ?bubble,
      if (!m.deleted && m.hasAttachment)
        AttachmentView(
          message: m,
          mine: mine,
          controller: controller,
          width: maxWidth,
          onOpen: () => onOpenAttachment(m),
        ),
      if (!m.deleted)
        for (final ref in shared.records)
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: RecordCard(ref: ref, load: controller.record, onOpen: onOpenRecord, now: controller.clock()),
          ),
    ];
    final stacked = <Widget>[
      for (var i = 0; i < pieces.length; i++) ...[
        if (i > 0) const SizedBox(height: 4),
        GestureDetector(onLongPress: onLongPress, child: pieces[i]),
      ],
    ];

    if (mine) {
      return Padding(
        padding: EdgeInsets.fromLTRB(16, continued ? 4 : 8, 16, 0),
        child: Align(
          alignment: Alignment.centerRight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              ...stacked,
              if (endsBlock)
                Padding(
                  padding: const EdgeInsets.only(top: 6, right: 4),
                  child: SentLine(at: m.createdAt, seen: seen),
                ),
            ],
          ),
        ),
      );
    }

    final sender = m.senderCompany?.name ?? m.sender?.fullName ?? '';
    return Padding(
      padding: EdgeInsets.fromLTRB(16, continued ? 4 : 14, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: continued
                ? null
                : m.senderCompany != null
                ? ThreadAvatar(
                    picture: m.senderCompany!.logo,
                    name: m.senderCompany!.name,
                    company: true,
                    verified: verified,
                  )
                : ThreadAvatar(picture: m.sender?.photo, name: sender, verified: verified),
          ),
          const SizedBox(width: 8.5),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!continued)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(5.5, 0, 0, 6),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(sender, maxLines: 1, overflow: TextOverflow.ellipsis, style: ChatText.senderName),
                        ),
                        const SizedBox(width: 8),
                        Text(messageTime(m.createdAt), style: ChatText.senderTime),
                      ],
                    ),
                  ),
                ...stacked,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Under one of my messages: "10:30 AM" and a tick, double and green once the other person has read it.
class SentLine extends StatelessWidget {
  const SentLine({super.key, required this.at, required this.seen});

  final DateTime at;
  final bool seen;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(messageTime(at), style: ChatText.sentTime),
      const SizedBox(width: 6),
      Icon(
        seen ? LucideIcons.checkCheck : LucideIcons.check,
        key: ValueKey(seen ? 'tick-seen' : 'tick-sent'),
        size: 16,
        color: seen ? ThreadColors.tick : AppColors.outline,
        semanticLabel: seen ? 'Seen' : 'Sent',
      ),
    ],
  );
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
          color: mine ? Colors.white.withValues(alpha: 0.16) : ChatColors.composerChip,
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

// --- a file in a message ---------------------------------------------------------------------------------------------

/// A file in a message: a photo drawn from its (private) bytes, anything else as the design's file card — a deep
/// blue tile, the name, "680 KB • DOCX", and Preview and a download glyph, both of which open it. A tap opens it:
/// the session fetches it and the phone gets it.
class AttachmentView extends StatelessWidget {
  const AttachmentView({
    super.key,
    required this.message,
    required this.mine,
    required this.controller,
    required this.onOpen,
    this.width = 273,
  });

  final ChatMessage message;
  final bool mine;
  final ConversationController controller;
  final VoidCallback onOpen;

  /// How wide the file card is: the bubbles' width.
  final double width;

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
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ThreadColors.edge),
            boxShadow: ThreadColors.lift,
          ),
          clipBehavior: Clip.antiAlias,
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
                  // Keeps the card's size while the picture decodes, so the thread does not jump.
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
    final meta = [fileSize(m.attachmentSize), fileKind(m.attachmentName, m.attachmentMime)].where((s) => s.isNotEmpty);
    final radius = BorderRadius.circular(10);
    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: radius,
          border: Border.all(color: ThreadColors.edge),
          boxShadow: ThreadColors.lift,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: ValueKey('attachment-${m.id}'),
            onTap: onOpen,
            borderRadius: radius,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(color: ThreadColors.deepBlue, borderRadius: BorderRadius.circular(8)),
                        child: const Icon(LucideIcons.fileText, size: 20, color: Colors.white),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: ChatText.fileName),
                            if (meta.isNotEmpty)
                              Text(
                                meta.join(' • '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: ChatText.fileMeta,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 36,
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(LucideIcons.eye, size: 16, color: ThreadColors.deepBlue),
                            const SizedBox(width: 6),
                            Text('Preview', style: ChatText.fileAction.copyWith(color: ThreadColors.deepBlue)),
                          ],
                        ),
                      ),
                      Semantics(
                        label: 'Download',
                        child: const SizedBox(
                          width: 52,
                          child: Icon(LucideIcons.download, size: 18, color: AppColors.onSurface),
                        ),
                      ),
                    ],
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

// --- a message on its way ------------------------------------------------------------------------------------------

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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Align(
        alignment: Alignment.centerRight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Opacity(
              opacity: p.failed ? 1 : 0.7,
              child: Container(
                constraints: BoxConstraints(maxWidth: width * 0.8),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: ChatColors.myBubble,
                  borderRadius: _corners(mine: true, tail: true, round: 16),
                  border: p.failed ? Border.all(color: ChatColors.failed, width: 1.5) : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (p.body.isNotEmpty) Text(p.body, style: ChatText.bubbleMineText),
                    if (p.attachment != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.paperclip, size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(p.attachment!.name, style: ChatText.bubbleMineText.copyWith(fontSize: 13)),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 4),
              child: p.failed
                  ? Wrap(
                      spacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          p.error ?? 'Not sent',
                          style: ChatText.sentTime.copyWith(color: ChatColors.failed, fontWeight: FontWeight.w600),
                        ),
                        GestureDetector(
                          key: const ValueKey('pending-retry'),
                          onTap: onRetry,
                          child: Text(
                            'Retry',
                            style: ChatText.sentTime.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                          ),
                        ),
                        GestureDetector(
                          key: const ValueKey('pending-discard'),
                          onTap: onDiscard,
                          child: Text('Discard', style: ChatText.sentTime.copyWith(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    )
                  : Text('Sending…', style: ChatText.sentTime),
            ),
          ],
        ),
      ),
    );
  }
}

// --- the booked session ------------------------------------------------------------------------------------------------

/// A session is 20 minutes when the thread's record gives no end.
const defaultSessionLength = Duration(minutes: 20);

/// A session the thread has booked: what the meeting card says and where its buttons go.
class MeetingFacts {
  const MeetingFacts({
    required this.title,
    required this.sub,
    required this.start,
    required this.end,
    this.href,
    this.joinUrl,
  });

  final String title;

  /// The thread's topic, else the kind of session.
  final String sub;
  final DateTime start;
  final DateTime end;

  /// The record the session belongs to (the pairing, the group session, the purchase).
  final String? href;

  /// A link that opens the call itself. The API's context carries none yet, so the card then opens [href].
  final Uri? joinUrl;
}

/// The thread's next booked session: a consultation or a booked 1:1, a pairing's next session, or a group
/// session's next one. Null when none is still to come.
MeetingFacts? meetingOf(ConversationContext? context, Conversation? conversation, {required DateTime now}) {
  final c = context;
  if (c == null) return null;
  final label = conversation?.contextLabel?.trim();
  String subFor(String title, String kind) => label != null && label.isNotEmpty && label != title ? label : kind;

  MeetingFacts? at(DateTime? start, String title, String kind, String href) {
    if (start == null) return null;
    final end = start.add(defaultSessionLength);
    if (!end.isAfter(now)) return null;
    return MeetingFacts(title: title, sub: subFor(title, kind), start: start, end: end, href: href);
  }

  final k = c.consultation;
  if (k != null) {
    final found = at(k.scheduledAt, k.title, 'Consultation', consultationHref(buyer: k.buyer));
    if (found != null) return found;
  }
  final m = c.mentorship;
  if (m != null) {
    final topics = m.topics.take(2).join(', ');
    final found = at(m.nextSessionAt, topics.isEmpty ? 'Mentoring session' : topics, 'Mentoring', mentorshipHref(m.id));
    if (found != null) return found;
  }
  final g = c.groupSession;
  if (g != null) return at(g.nextAt, g.title, 'Group session', groupSessionHref(g.id));
  return null;
}

/// Where the thread's own session record opens (the pairing, the group session, the booked consultation); null
/// when the thread has none.
String? sessionRecordHref(ConversationContext? context) {
  final c = context;
  if (c == null) return null;
  final k = c.consultation;
  if (k != null && (k.oneOnOne || k.scheduledAt != null)) return consultationHref(buyer: k.buyer);
  final m = c.mentorship;
  if (m != null) return mentorshipHref(m.id);
  final g = c.groupSession;
  if (g != null) return groupSessionHref(g.id);
  return null;
}

/// The design's meeting card: a video tile, the session's title and topic, a panel with when it runs (and the
/// call's address when the session has one), and "Add to Cal" and "Join Meeting".
class MeetingCard extends StatelessWidget {
  const MeetingCard({
    super.key,
    required this.facts,
    required this.now,
    required this.onAddToCalendar,
    required this.onJoin,
  });

  final MeetingFacts facts;
  final DateTime now;
  final VoidCallback onAddToCalendar;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final f = facts;
    final width = MediaQuery.sizeOf(context).width;
    final host = f.joinUrl?.host ?? '';
    final bridge = host.isEmpty
        ? null
        : '${host.contains('meet.google') ? 'Google Meet Bridge' : host} • Encrypted ICR Room';
    return Padding(
      padding: const EdgeInsets.fromLTRB(56.5, 14, 16, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          key: const ValueKey('meeting-card'),
          width: math.min(273, width - 72.5),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ThreadColors.edge),
            boxShadow: ThreadColors.lift,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: ChatColors.composerChip, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(LucideIcons.video, size: 20, color: ThreadColors.deepBlue),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: ChatText.meetingTitle),
                        Text(f.sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: ChatText.meetingSub),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                decoration: BoxDecoration(color: ThreadColors.panel, borderRadius: BorderRadius.circular(8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(LucideIcons.clock, size: 16, color: ThreadColors.deepBlue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            meetingWhen(f.start, f.end, now: now),
                            key: const ValueKey('meeting-when'),
                            style: ChatText.meetingLine.copyWith(color: AppColors.onSurface),
                          ),
                        ),
                      ],
                    ),
                    if (bridge != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(LucideIcons.link, size: 16, color: AppColors.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Expanded(child: Text(bridge, style: ChatText.meetingLine)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _MeetingButton(
                      key: const ValueKey('meeting-calendar'),
                      icon: LucideIcons.calendarPlus,
                      label: 'Add to Cal',
                      onTap: onAddToCalendar,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MeetingButton(
                      key: const ValueKey('meeting-join'),
                      icon: LucideIcons.video,
                      label: 'Join Meeting',
                      filled: true,
                      onTap: onJoin,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MeetingButton extends StatelessWidget {
  const _MeetingButton({super.key, required this.icon, required this.label, required this.onTap, this.filled = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final ink = filled ? Colors.white : AppColors.onSurfaceVariant;
    return Material(
      color: filled ? AppColors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 36,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: ink),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: (filled ? ChatText.meetingButtonOn : ChatText.meetingButton).copyWith(color: ink),
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
