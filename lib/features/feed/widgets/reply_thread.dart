import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../feed_models.dart';
import '../feed_styles.dart';
import 'reply_widgets.dart';

/// The open comments under a post, as `forum-replies.png` draws them: the first reply and its first answer, the
/// "+N replies in this thread" pill, and the reply box, all hung off one branch line. The pill opens the rest of
/// the discussion in place, and a link under it carries on to the discussion's own page.
class ReplyThread extends StatefulWidget {
  const ReplyThread({
    super.key,
    required this.post,
    required this.loading,
    required this.viewer,
    required this.onLike,
    required this.onSend,
    required this.onMore,
    this.onOpenThread,
    this.onOpenAuthor,
    this.look = ReplyLook.home,
    this.now,
  });

  final FeedPost post;
  final bool loading;
  final FeedAuthor viewer;
  final ValueChanged<FeedReply> onLike;
  final Future<bool> Function(String text, String? parentId) onSend;

  /// A reply's three dots: its menu.
  final ValueChanged<FeedReply> onMore;

  /// Opens the discussion's page; null leaves the link out.
  final VoidCallback? onOpenThread;

  /// A reply's photo: opens its author.
  final ValueChanged<FeedReply>? onOpenAuthor;

  /// Which of the two designs of a reply thread to draw (see [ReplyLook]); Home draws its own.
  final ReplyLook look;

  /// The clock the times under the names read against (a golden pins it).
  final DateTime? now;

  @override
  State<ReplyThread> createState() => _ReplyThreadState();
}

class _ReplyThreadState extends State<ReplyThread> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  bool _showAll = false;
  bool _sending = false;
  FeedReply? _replyingTo;

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Whom the box answers when no reply was picked: the newest reply by someone else, as the design's box reads
  /// "Reply to Priya Nambiar...". The design's own sample names its addressee by hand ([FeedPost.replyTo]), and a
  /// thread with no other voice is answered at the top level.
  FeedReply? get _defaultTarget =>
      widget.post.replyTo == null ? replyTargetFor(widget.post.replies, widget.viewer.id) : null;

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final ok = await widget.onSend(text, (_replyingTo ?? _defaultTarget)?.id);
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (ok) {
        _input.clear();
        _replyingTo = null;
        // Show the whole thread, so the reply just sent is there to see.
        _showAll = true;
        _focus.unfocus();
      }
    });
  }

  void _replyTo(FeedReply reply) {
    setState(() => _replyingTo = reply);
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final rows = <Widget>[];

    // The preview is the design's: the first reply and its first answer. The whole thread is every reply, each
    // answer stepped in under the one it answers.
    final entries = <({FeedReply reply, int depth})>[];
    void walk(List<FeedReply> list, int depth) {
      for (final r in list) {
        entries.add((reply: r, depth: depth));
        walk(r.children, depth + 1);
      }
    }

    if (_showAll) {
      walk(post.replies, 0);
    } else if (post.replies.isNotEmpty) {
      final first = post.replies.first;
      entries.add((reply: first, depth: 0));
      if (first.children.isNotEmpty) entries.add((reply: first.children.first, depth: 1));
    }
    final hidden = _showAll ? 0 : post.moreReplies;

    final home = widget.look == ReplyLook.home;
    final g = ReplyGeometry.of(widget.look);
    // The Home design hangs its pill and its box one step in, under the answer it draws; the section look keeps
    // them at the top level.
    final tail = home ? g.indentStep : 0.0;

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      rows.add(
        ThreadBranch(
          look: widget.look,
          gap: i == 0 ? (home ? 4 : 10) : (home ? HomeReplyDesign.gapTile : ReplyDesign.gapTile),
          armY: home ? HomeReplyDesign.armTile : ReplyDesign.armTile,
          indent: g.indentStep * entry.depth.clamp(0, ReplyDesign.maxDepth),
          // The Home thread's line starts under its first avatar, not above it.
          lineFrom: home && i == 0 ? HomeReplyDesign.avatarTop + HomeReplyDesign.avatar - 1 : 0,
          child: ReplyTile(
            look: widget.look,
            now: widget.now,
            reply: entry.reply,
            maxBodyLines: _showAll ? null : 6,
            onLike: () => widget.onLike(entry.reply),
            onReply: () => _replyTo(entry.reply),
            onMore: () => widget.onMore(entry.reply),
            onOpenAuthor: widget.onOpenAuthor == null ? null : () => widget.onOpenAuthor!(entry.reply),
          ),
        ),
      );
    }

    if (widget.loading && post.replies.isEmpty) {
      rows.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
        ),
      );
    }

    if (hidden > 0) {
      rows.add(
        ThreadBranch(
          look: widget.look,
          gap: home ? HomeReplyDesign.gapPill : ReplyDesign.gapPill,
          armY: home ? HomeReplyDesign.armPill : ReplyDesign.armPill,
          indent: tail,
          child: MoreRepliesPill(look: widget.look, count: hidden, onTap: () => setState(() => _showAll = true)),
        ),
      );
    } else if (_showAll && widget.onOpenThread != null && post.comments > 0) {
      rows.add(
        ThreadBranch(
          look: widget.look,
          gap: home ? HomeReplyDesign.gapPill : ReplyDesign.gapPill,
          armY: home ? HomeReplyDesign.armPill : ReplyDesign.armPill,
          indent: tail,
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const ValueKey('open-thread'),
              onPressed: widget.onOpenThread,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                backgroundColor: ReplyDesign.pillFill,
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: const StadiumBorder(),
              ),
              child: Text('Open the whole discussion', style: ReplyDesign.pill),
            ),
          ),
        ),
      );
    }

    final target = _replyingTo ?? _defaultTarget;
    rows.add(
      ThreadBranch(
        look: widget.look,
        gap: rows.isEmpty ? 10 : (home ? HomeReplyDesign.gapBox : ReplyDesign.gapBox),
        armY: home ? HomeReplyDesign.armBox : ReplyDesign.armBox,
        last: true,
        indent: tail,
        child: ReplyBox(
          look: widget.look,
          viewer: widget.viewer,
          controller: _input,
          focusNode: _focus,
          sending: _sending,
          hint: 'Reply to ${target?.author.name ?? post.replyTo ?? post.author.name}...',
          onSend: _send,
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(g.inset, 0, home ? HomeLook.pad : 16, home ? 12 : 7),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
    );
  }
}
