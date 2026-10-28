import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/util/time_ago.dart';
import '../feed_models.dart';
import '../feed_styles.dart';
import 'feed_avatar.dart';

/// The pieces of the reply section: a reply's tile, the "+N replies in this thread" pill, the reply box, and the
/// branch line that joins them. The Home feed's open thread draws them as the Home design does
/// ([ReplyLook.home], `forums-new-home.png`); the discussion page draws the "Branching Nested Replies Section"
/// ([ReplyLook.section], `forum-replies.png`). Every control is the same in both looks.

/// One row of a thread: [child] hangs off the thread's line by a rounded elbow [armY] dp below its top, [indent]
/// dp further in for a reply to a reply. The line runs through every row but the last, which ends a little below
/// its elbow (section) or curves into it (home), as the designs' do.
class ThreadBranch extends StatelessWidget {
  const ThreadBranch({
    super.key,
    required this.child,
    required this.armY,
    this.gap = 0,
    this.indent = 0,
    this.last = false,
    this.look = ReplyLook.section,
    this.lineFrom = 0,
  });

  final Widget child;
  final double armY;

  /// Space above the row, which the line crosses.
  final double gap;
  final double indent;
  final bool last;
  final ReplyLook look;

  /// Where the line begins inside this row (the Home thread's starts under its first avatar).
  final double lineFrom;

  @override
  Widget build(BuildContext context) {
    final g = ReplyGeometry.of(look);
    return CustomPaint(
      painter: look == ReplyLook.home
          ? _HomeBranchPainter(
              g: g,
              armY: gap + armY,
              armEnd: g.avatarLeft + indent - 1,
              last: last,
              from: lineFrom == 0 ? 0 : gap + lineFrom,
            )
          : _BranchPainter(g: g, armY: gap + armY, armEnd: g.avatarLeft + indent - 1, last: last),
      child: Padding(
        padding: EdgeInsets.only(top: gap, left: g.avatarLeft + indent),
        child: child,
      ),
    );
  }
}

class _BranchPainter extends CustomPainter {
  _BranchPainter({required this.g, required this.armY, required this.armEnd, required this.last});

  final ReplyGeometry g;
  final double armY;
  final double armEnd;
  final bool last;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = g.lineColor
      ..style = PaintingStyle.fill;
    const half = ReplyDesign.lineWidth / 2;
    final x = g.lineX;
    // The last row's line stops 3 dp under its arm (the design leaves that stub).
    final bottom = last ? armY + half + 3.25 : size.height;
    canvas.drawRect(Rect.fromLTRB(x - half, 0, x + half, bottom), paint);
    canvas.drawRect(Rect.fromLTRB(x - half, armY - half, armEnd, armY + half), paint);
    // The corner above the arm is rounded; the corner below it is the line's own.
    final fillet = Path()
      ..moveTo(x + half, armY - half)
      ..lineTo(x + half + g.arcRadius, armY - half)
      ..quadraticBezierTo(x + half, armY - half, x + half, armY - half - g.arcRadius)
      ..close();
    canvas.drawPath(fillet, paint);
  }

  @override
  bool shouldRepaint(_BranchPainter old) => old.armY != armY || old.armEnd != armEnd || old.last != last;
}

/// The Home design's connector: a 2 dp line, and each arm leaves it on a curve. The last arm is the line itself
/// turning the corner, so nothing runs past it.
class _HomeBranchPainter extends CustomPainter {
  _HomeBranchPainter({
    required this.g,
    required this.armY,
    required this.armEnd,
    required this.last,
    required this.from,
  });

  final ReplyGeometry g;
  final double armY;
  final double armEnd;
  final bool last;
  final double from;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = g.lineColor;
    const half = 1.0;
    final x = g.lineX;
    final r = g.arcRadius;
    final hasArm = armEnd > x + half;
    final bottom = last ? (hasArm ? armY - r : armY + half) : size.height;
    if (bottom > from) canvas.drawRect(Rect.fromLTRB(x - half, from, x + half, bottom), paint);
    if (!hasArm) return;
    final stroke = Paint()
      ..color = g.lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path()
      ..moveTo(x, armY - r)
      ..arcToPoint(Offset(x + r, armY), radius: Radius.circular(r), clockwise: false)
      ..lineTo(armEnd, armY);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(_HomeBranchPainter old) =>
      old.armY != armY || old.armEnd != armEnd || old.last != last || old.from != from;
}

/// A reply: the author's photo beside a pale bubble holding their name (and role, in the section look), the time
/// and organisation, the words, and Like and Reply. [actions] adds more beside them (Accept answer), [badge] sits
/// at the row's end.
class ReplyTile extends StatelessWidget {
  const ReplyTile({
    super.key,
    required this.reply,
    required this.onLike,
    required this.onReply,
    required this.onMore,
    this.maxBodyLines,
    this.actions = const [],
    this.badge,
    this.focused = false,
    this.onOpenAuthor,
    this.look = ReplyLook.section,
    this.now,
    this.below,
  });

  final FeedReply reply;
  final VoidCallback onLike;
  final VoidCallback onReply;
  final VoidCallback onMore;
  final int? maxBodyLines;
  final List<Widget> actions;
  final Widget? badge;

  /// The reply a link named: ringed.
  final bool focused;
  final VoidCallback? onOpenAuthor;
  final ReplyLook look;

  /// The clock the time under the name reads against (a golden pins it).
  final DateTime? now;

  /// Something under the words and above Like: the reply's attached file. The section look only.
  final Widget? below;

  String get _meta => [
    '${timeAgo(reply.createdAt, now: now)}${reply.edited ? ' (edited)' : ''}',
    if (reply.meta != null && reply.meta!.isNotEmpty) reply.meta!,
  ].join(' • ');

  @override
  Widget build(BuildContext context) => look == ReplyLook.home ? _home(context) : _section(context);

  // --- the Home feed: LinkedIn's comment -------------------------------------------------------------------

  Widget _home(BuildContext context) {
    final accepted = reply.accepted;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onOpenAuthor,
          child: FeedAvatar(
            photo: reply.author.photo,
            initials: reply.author.initials,
            size: HomeReplyDesign.avatar,
            label: reply.author.name,
          ),
        ),
        const SizedBox(width: HomeReplyDesign.bubbleGap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: accepted ? ReplyDesign.acceptedFill : HomeReplyDesign.bubbleFill,
                  // Square at the photo's corner, as LinkedIn's bubble.
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(HomeReplyDesign.bubbleRadius),
                    bottomLeft: Radius.circular(HomeReplyDesign.bubbleRadius),
                    bottomRight: Radius.circular(HomeReplyDesign.bubbleRadius),
                  ),
                  border: focused
                      ? Border.all(color: AppColors.primary, width: 1.5)
                      : accepted
                      ? Border.all(color: ReplyDesign.acceptedBorder)
                      : null,
                ),
                padding: const EdgeInsets.fromLTRB(12, 8, 4, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                reply.author.name,
                                style: HomeType.replyName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(_meta, style: HomeType.replyMeta, maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        Semantics(
                          button: true,
                          label: 'Reply options',
                          excludeSemantics: true,
                          child: InkResponse(
                            key: ValueKey('reply-more:${reply.id}'),
                            onTap: onMore,
                            radius: 16,
                            child: const SizedBox(
                              width: 28,
                              height: 24,
                              child: Icon(LucideIcons.ellipsis, size: 16, color: HomeLook.soft),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        reply.body,
                        style: HomeType.replyBody,
                        maxLines: maxBodyLines,
                        overflow: maxBodyLines == null ? TextOverflow.clip : TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 28,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Row(
                    children: [
                      ReplyAction(
                        key: ValueKey('reply-like:${reply.id}'),
                        icon: LucideIcons.thumbsUp,
                        label: reply.likes > 0 ? '${reply.likes}' : 'Like',
                        semantics: reply.liked ? 'Unlike' : 'Like',
                        active: reply.liked,
                        onTap: onLike,
                        compact: true,
                      ),
                      const SizedBox(width: 16),
                      ReplyAction(
                        key: ValueKey('reply-reply:${reply.id}'),
                        icon: LucideIcons.reply,
                        label: 'Reply',
                        semantics: 'Reply',
                        onTap: onReply,
                        compact: true,
                      ),
                      for (final action in actions) ...[const SizedBox(width: 16), action],
                      if (badge != null) ...[const Spacer(), badge!],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- the Branching Nested Replies Section -----------------------------------------------------------------

  Widget _section(BuildContext context) {
    final role = reply.role;
    final accepted = reply.accepted;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: GestureDetector(
            onTap: onOpenAuthor,
            child: FeedAvatar(
              photo: reply.author.photo,
              initials: reply.author.initials,
              size: ReplyDesign.avatar,
              label: reply.author.name,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: accepted ? ReplyDesign.acceptedFill : ReplyDesign.bubbleFill,
              borderRadius: BorderRadius.circular(ReplyDesign.bubbleRadius),
              border: Border.all(
                color: focused
                    ? AppColors.primary
                    : accepted
                    ? ReplyDesign.acceptedBorder
                    : ReplyDesign.bubbleBorder,
                width: focused ? 1.5 : 1,
              ),
              boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 3, offset: Offset(0, 1))],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: ReplyDesign.headerTop - 1),
                SizedBox(
                  height: ReplyDesign.headerHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        right: 24,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Flexible(
                              child: Baseline(
                                baseline: ReplyDesign.nameBaseline,
                                baselineType: TextBaseline.alphabetic,
                                child: Text(
                                  reply.author.name,
                                  style: ReplyDesign.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            if (role != null && role.isNotEmpty) ...[
                              const SizedBox(width: 6.25),
                              Flexible(flex: 0, child: _RolePill(role: role)),
                            ],
                          ],
                        ),
                      ),
                      Positioned(
                        right: -6.6,
                        top: -10.6,
                        child: Semantics(
                          button: true,
                          label: 'Reply options',
                          excludeSemantics: true,
                          child: InkResponse(
                            key: ValueKey('reply-more:${reply.id}'),
                            onTap: onMore,
                            radius: 16,
                            child: const SizedBox(width: 28, height: 28, child: Center(child: _Dots())),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: ReplyDesign.metaSlot,
                  child: Baseline(
                    baseline: ReplyDesign.metaBaseline,
                    baselineType: TextBaseline.alphabetic,
                    child: Text(_meta, style: ReplyDesign.meta, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
                Baseline(
                  baseline: ReplyDesign.bodyBaseline,
                  baselineType: TextBaseline.alphabetic,
                  child: Text(
                    reply.body,
                    style: ReplyDesign.body,
                    maxLines: maxBodyLines,
                    overflow: maxBodyLines == null ? TextOverflow.clip : TextOverflow.ellipsis,
                  ),
                ),
                if (below != null) Padding(padding: const EdgeInsets.only(top: 6), child: below),
                const SizedBox(height: 2),
                SizedBox(
                  height: ReplyDesign.actionsHeight,
                  child: Row(
                    children: [
                      ReplyAction(
                        key: ValueKey('reply-like:${reply.id}'),
                        icon: LucideIcons.thumbsUp,
                        label: reply.likes > 0 ? '${reply.likes}' : 'Like',
                        semantics: reply.liked ? 'Unlike' : 'Like',
                        active: reply.liked,
                        onTap: onLike,
                      ),
                      const SizedBox(width: 11),
                      ReplyAction(
                        key: ValueKey('reply-reply:${reply.id}'),
                        icon: LucideIcons.reply,
                        label: 'Reply',
                        semantics: 'Reply',
                        onTap: onReply,
                      ),
                      for (final action in actions) ...[const SizedBox(width: 11), action],
                      if (badge != null) ...[const Spacer(), badge!],
                    ],
                  ),
                ),
                const SizedBox(height: ReplyDesign.bottomPad),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// "VP Sustainability": the author's role, in a tinted box beside their name.
class _RolePill extends StatelessWidget {
  const _RolePill({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: ReplyDesign.headerHeight,
      padding: const EdgeInsets.symmetric(horizontal: 4.4),
      decoration: BoxDecoration(color: ReplyDesign.roleFill, borderRadius: BorderRadius.circular(2)),
      child: Baseline(
        baseline: 18.7,
        baselineType: TextBaseline.alphabetic,
        child: Text(role, style: ReplyDesign.role, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

/// The three dots, lying down: 2.75 dp each, 1.25 dp apart.
class _Dots extends StatelessWidget {
  const _Dots();

  @override
  Widget build(BuildContext context) {
    Widget dot() => Container(
      width: 2.75,
      height: 2.75,
      decoration: const BoxDecoration(color: AppColors.outline, shape: BoxShape.circle),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [dot(), const SizedBox(width: 1.25), dot(), const SizedBox(width: 1.25), dot()],
    );
  }
}

/// An icon and a word under a reply: Like (with its count) and Reply.
class ReplyAction extends StatelessWidget {
  const ReplyAction({
    super.key,
    required this.icon,
    required this.label,
    required this.semantics,
    required this.onTap,
    this.active = false,
    this.color,
    this.compact = false,
    this.iconSize,
    this.gap,
  });

  final IconData icon;
  final String label;
  final String semantics;
  final VoidCallback? onTap;
  final bool active;
  final Color? color;

  /// The Home feed's LinkedIn-style word under a comment (12 sp Roboto, 60 % black).
  final bool compact;
  final double? iconSize;
  final double? gap;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? (active ? AppColors.primary : (compact ? HomeLook.soft : AppColors.outline));
    return Semantics(
      button: true,
      label: semantics,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          height: compact ? 28 : ReplyDesign.actionsHeight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: iconSize ?? (compact ? 16 : 14), color: tint),
              SizedBox(width: gap ?? (compact ? 4 : 3.3)),
              Text(label, style: (compact ? HomeType.replyAction : ReplyDesign.action).copyWith(color: tint)),
            ],
          ),
        ),
      ),
    );
  }
}

/// "+8 replies in this thread", with the arrow that opens it in the section look.
class MoreRepliesPill extends StatelessWidget {
  const MoreRepliesPill({super.key, required this.count, required this.onTap, this.look = ReplyLook.section});

  final int count;
  final VoidCallback onTap;
  final ReplyLook look;

  @override
  Widget build(BuildContext context) {
    final text = '+$count ${count == 1 ? 'reply' : 'replies'} in this thread';
    if (look == ReplyLook.home) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Material(
          color: HomeReplyDesign.bubbleFill,
          shape: const StadiumBorder(),
          child: InkWell(
            key: const ValueKey('more-replies'),
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: SizedBox(
              height: HomeReplyDesign.pillHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(widthFactor: 1, child: Text(text, style: HomeType.morePill)),
              ),
            ),
          ),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: ReplyDesign.pillFill,
        shape: const StadiumBorder(),
        child: InkWell(
          key: const ValueKey('more-replies'),
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: SizedBox(
            height: 32,
            child: Padding(
              padding: const EdgeInsets.only(left: 8, right: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: ReplyDesign.dotRing, shape: BoxShape.circle),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                    ),
                  ),
                  const SizedBox(width: 6.5),
                  Text(text, style: ReplyDesign.pill),
                  const SizedBox(width: 8),
                  const Icon(Symbols.subdirectory_arrow_right, size: 12, weight: 600, color: AppColors.primary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The reply box: the reader's photo, a pale pill to type in, and the send arrow. [hint] says whom the reply
/// goes to ("Reply to Priya Nambiar...").
class ReplyBox extends StatelessWidget {
  const ReplyBox({
    super.key,
    required this.viewer,
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.hint,
    required this.onSend,
    this.enabled = true,
    this.look = ReplyLook.section,
    this.newlines = false,
  });

  final FeedAuthor viewer;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final String hint;
  final VoidCallback onSend;
  final bool enabled;
  final ReplyLook look;

  /// The keyboard's Enter writes a new line (the send arrow sends), as a page where replies run to paragraphs
  /// wants; off, Enter sends, as the Home feed's one-line box does.
  final bool newlines;

  @override
  Widget build(BuildContext context) {
    final home = look == ReplyLook.home;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: home ? 4 : 3.5),
          child: FeedAvatar(photo: viewer.photo, initials: viewer.initials, size: home ? HomeReplyDesign.avatar : 24),
        ),
        SizedBox(width: home ? HomeReplyDesign.bubbleGap : 7),
        Expanded(
          child: Container(
            constraints: BoxConstraints(minHeight: home ? HomeReplyDesign.boxHeight : 31),
            decoration: BoxDecoration(
              color: home ? Colors.white : ReplyDesign.pillFill,
              borderRadius: BorderRadius.circular(home ? 20 : 15.5),
              border: Border.all(color: home ? HomeReplyDesign.inputBorder : ReplyDesign.inputBorder, width: 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(width: home ? 16 : 12.2),
                Expanded(
                  child: TextField(
                    key: const ValueKey('reply-input'),
                    controller: controller,
                    focusNode: focusNode,
                    enabled: enabled && !sending,
                    minLines: 1,
                    maxLines: 4,
                    style: home ? HomeType.replyInput : ReplyDesign.input,
                    textInputAction: newlines ? TextInputAction.newline : TextInputAction.send,
                    keyboardType: newlines ? TextInputType.multiline : null,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: newlines ? null : (_) => onSend(),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: hint,
                      hintStyle: home ? HomeType.replyHint : ReplyDesign.hint,
                      hintMaxLines: 1,
                      contentPadding: EdgeInsets.symmetric(vertical: home ? 9 : 6),
                    ),
                  ),
                ),
                Semantics(
                  button: true,
                  label: 'Send reply',
                  excludeSemantics: true,
                  child: InkResponse(
                    key: const ValueKey('reply-send'),
                    onTap: sending || !enabled ? null : onSend,
                    radius: 18,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(6, 5, home ? 12 : 10.75, 5),
                      child: sending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: Padding(
                                padding: EdgeInsets.all(1),
                                child: CircularProgressIndicator(strokeWidth: 1.6),
                              ),
                            )
                          : home
                          // The arrow is grey until there is something to send.
                          ? ListenableBuilder(
                              listenable: controller,
                              builder: (context, _) => Icon(
                                LucideIcons.send,
                                size: 20,
                                color: enabled && controller.text.trim().isNotEmpty
                                    ? AppColors.primary
                                    : HomeLook.soft,
                              ),
                            )
                          : Icon(Symbols.send, size: 16, color: enabled ? AppColors.primary : AppColors.outline),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
