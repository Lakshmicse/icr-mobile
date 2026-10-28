import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart';
import '../../core/widgets/title_bar.dart';
import '../feed/feed_models.dart';
import '../feed/forum_json.dart';
import 'forum_callbacks.dart';
import 'forum_models.dart';
import 'forum_repository.dart';
import 'new_thread_screen.dart';
import 'thread_controller.dart';
import 'widgets/forum_bits.dart';
import 'widgets/forum_sheets.dart';
import 'widgets/reply_section.dart';
import 'widgets/thread_header.dart';

/// Opens a discussion's page over the screen that asked (the Home feed, the Forums tab, a notification). Returns
/// what the reader did there, for that screen to show on its own card; null when the page was left unread.
///
/// [preview] is the discussion's card as the list had it, drawn while the page is read. [focusReplyId] brings one
/// reply into view (a notification's target). [unread] is the bell's count.
Future<ThreadResult?> openThreadPage(
  BuildContext context, {
  required ForumRepository repository,
  required FeedAuthor viewer,
  required String slug,
  FeedPost? preview,
  String? focusReplyId,
  int unread = 0,
  ForumCallbacks callbacks = const ForumCallbacks(),
  bool scrollToReplies = false,
}) {
  return Navigator.of(context).push<ThreadResult>(
    MaterialPageRoute<ThreadResult>(
      builder: (_) => ChangeNotifierProvider<ThreadController>(
        create: (_) => ThreadController(
          repository: repository,
          slug: slug,
          viewer: viewer,
          preview: preview,
          focusReplyId: focusReplyId,
        )..start(),
        // The editor opens over the page, from the same forum.
        child: Builder(
          builder: (page) => ThreadScreen(
            unread: unread,
            callbacks: callbacks,
            scrollToReplies: scrollToReplies,
            onEdit: (thread) => openComposer(page, repository: repository, editing: thread),
          ),
        ),
      ),
    ),
  );
}

/// One discussion: its page as the community forum has it, with the replies nested under it and a box to answer
/// in. Reads its [ThreadController] from Provider (see [openThreadPage]).
class ThreadScreen extends StatefulWidget {
  const ThreadScreen({
    super.key,
    this.unread = 0,
    this.callbacks = const ForumCallbacks(),
    this.onEdit,
    this.scrollToReplies = false,
  });

  final int unread;
  final ForumCallbacks callbacks;

  /// Opens with the replies in view, as the speech bubble on a card asks.
  final bool scrollToReplies;

  /// Opens the editor for the discussion (its author, or a moderator); gets the discussion and returns what was
  /// saved, or null when the editor was left. Absent, the menu has no Edit.
  final Future<ForumThread?> Function(ForumThread thread)? onEdit;

  @override
  State<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends State<ThreadScreen> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  final _keys = <String, GlobalKey>{};

  FeedReply? _replyingTo;
  FeedReply? _editing;
  bool _sending = false;
  String? _sendError;
  bool _deleted = false;
  bool _scrolledToFocus = false;
  bool _scrolledToReplies = false;
  final _repliesKey = GlobalKey(debugLabel: 'replies');

  @override
  void initState() {
    super.initState();
    _input.addListener(() {
      if (_sendError != null && _input.text.isNotEmpty) setState(() => _sendError = null);
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(String id) => _keys.putIfAbsent(id, () => GlobalKey(debugLabel: 'reply-$id'));

  ThreadController get _c => context.read<ThreadController>();

  Future<void> _run(Future<String?> action) async {
    final message = await action;
    if (message != null && mounted) showMessage(context, message);
  }

  ThreadResult _result() => ThreadResult(post: _c.post, deleted: _deleted);

  void _scrollTo(String id) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _keys[id]?.currentContext;
      if (target != null && mounted) {
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          alignment: 0.15,
        );
      }
    });
  }

  // --- reactions, saves, follows ---------------------------------------------------------------------------

  Future<void> _pickReaction(Rect anchor) async {
    final c = _c;
    if (c.isOwn) return _run(c.react(ReactionKind.like));
    final picked = await showReactionPicker(context, anchor: anchor, current: c.post?.myReaction);
    if (picked == null || !mounted) return;
    // Picking the reaction one already has takes it back.
    await _run(c.react(picked == c.post?.myReaction ? null : picked));
  }

  void _share() {
    final c = _c;
    final post = c.post;
    if (post == null) return;
    SharePlus.instance.share(ShareParams(text: '${post.title}\n${c.link()}', subject: post.title));
  }

  Future<void> _copyLink({FeedReply? reply}) async {
    await Clipboard.setData(ClipboardData(text: _c.link(reply: reply).toString()));
    if (mounted) showMessage(context, 'Link copied');
  }

  Future<void> _report({FeedReply? reply}) async {
    final c = _c;
    final sent = await showReportSheet(
      context,
      reply: reply != null,
      onSend: (reason, note) => c.report(reply: reply, reason: reason, note: note),
    );
    if (sent && mounted) showMessage(context, 'Thanks. A moderator will take a look.');
  }

  Future<void> _deleteThread() async {
    final sure = await confirm(
      context,
      title: 'Delete this discussion?',
      body: 'It is taken down for everyone, replies included.',
      action: 'Delete',
    );
    if (!sure || !mounted) return;
    final message = await _c.deleteThread();
    if (!mounted) return;
    if (message != null) {
      showMessage(context, message);
      return;
    }
    _deleted = true;
    Navigator.of(context).pop(_result());
  }

  Future<void> _edit() async {
    final thread = _c.thread;
    final edit = widget.onEdit;
    if (thread == null || edit == null) return;
    final saved = await edit(thread);
    if (saved != null && mounted) {
      _c.adoptEdited(saved);
      showMessage(context, 'Saved');
    }
  }

  void _threadMenu() {
    final c = _c;
    final thread = c.thread;
    if (thread == null) return;
    showActionSheet(
      context,
      title: thread.card.title,
      actions: [
        if (thread.canEdit && widget.onEdit != null)
          SheetAction(key: const ValueKey('menu-edit'), label: 'Edit', icon: LucideIcons.pencil, onTap: _edit),
        if (thread.canEdit)
          SheetAction(
            key: const ValueKey('menu-delete'),
            label: 'Delete',
            icon: LucideIcons.trash2,
            destructive: true,
            onTap: _deleteThread,
          ),
        SheetAction(key: const ValueKey('menu-copy'), label: 'Copy link', icon: LucideIcons.link, onTap: _copyLink),
        SheetAction(key: const ValueKey('menu-viewers'), label: 'Who viewed', icon: LucideIcons.eye, onTap: _viewers),
        if (!c.isOwn)
          SheetAction(key: const ValueKey('menu-report'), label: 'Report', icon: LucideIcons.flag, onTap: _report),
      ],
    );
  }

  void _viewers() => showViewersSheet(context, load: _c.viewers, onOpenMember: widget.callbacks.onOpenMember);

  void _reactors() => showReactorsSheet(context, load: _c.reactors, onOpenMember: widget.callbacks.onOpenMember);

  // --- replies -----------------------------------------------------------------------------------------------

  void _replyTo(FeedReply? reply) {
    setState(() {
      _replyingTo = reply;
      _editing = null;
    });
    _focus.requestFocus();
  }

  void _startEditing(FeedReply reply) {
    setState(() {
      _editing = reply;
      _replyingTo = null;
      _sendError = null;
      _input.text = ForumJson.htmlToText(reply.bodyHtml ?? reply.body);
      _input.selection = TextSelection.collapsed(offset: _input.text.length);
    });
    _focus.requestFocus();
  }

  void _clearTarget() {
    setState(() {
      if (_editing != null) _input.clear();
      _replyingTo = null;
      _editing = null;
      _sendError = null;
    });
  }

  Future<void> _submit() async {
    final c = _c;
    final text = _input.text;
    if (text.trim().isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _sendError = null;
    });
    final editing = _editing;
    final message = editing != null
        ? await c.editReply(editing, text)
        : await c.sendReply(text, parentId: _replyingTo?.id);
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (message == null) {
        _input.clear();
        _replyingTo = null;
        _editing = null;
        _focus.unfocus();
      } else {
        // What was typed stays; the refusal reads above the box.
        _sendError = message;
      }
    });
    if (message == null && editing == null && c.lastSentId != null) _scrollTo(c.lastSentId!);
  }

  Future<void> _deleteReply(FeedReply reply) async {
    final sure = await confirm(
      context,
      title: 'Delete your reply?',
      body: 'It is taken out of the discussion for everyone.',
      action: 'Delete',
    );
    if (sure && mounted) {
      if (_editing?.id == reply.id) _clearTarget();
      _run(_c.deleteReply(reply));
    }
  }

  void _replyMenu(FeedReply reply) {
    final c = _c;
    final mine = reply.author.id == c.viewer.id;
    showActionSheet(
      context,
      title: reply.author.name,
      actions: [
        if (reply.canEdit)
          SheetAction(
            key: const ValueKey('reply-menu-edit'),
            label: 'Edit',
            icon: LucideIcons.pencil,
            onTap: () => _startEditing(reply),
          ),
        if (reply.canEdit)
          SheetAction(
            key: const ValueKey('reply-menu-delete'),
            label: 'Delete',
            icon: LucideIcons.trash2,
            destructive: true,
            onTap: () => _deleteReply(reply),
          ),
        SheetAction(
          key: const ValueKey('reply-menu-copy'),
          label: 'Copy link',
          icon: LucideIcons.link,
          onTap: () => _copyLink(reply: reply),
        ),
        if (!mine)
          SheetAction(
            key: const ValueKey('reply-menu-report'),
            label: 'Report',
            icon: LucideIcons.flag,
            onTap: () => _report(reply: reply),
          ),
      ],
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) await openUrl(context, uri);
  }

  // --- the page ----------------------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ThreadController>();
    // Bring the reply a link named, and then the reply just sent, into view once they are on the page.
    if (c.focusReplyId != null && c.focusFound && !_scrolledToFocus) {
      _scrolledToFocus = true;
      _scrollTo(c.focusReplyId!);
    }
    if (widget.scrollToReplies && !_scrolledToReplies && c.thread != null && !c.repliesLoading) {
      _scrolledToReplies = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _repliesKey.currentContext;
        if (target != null && mounted) {
          Scrollable.ensureVisible(target, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        }
      });
    }
    final target = _editing != null
        ? ReplyTarget.editing()
        : _replyingTo != null
        ? ReplyTarget.reply(_replyingTo!)
        : ReplyTarget.discussion();
    final showBar = c.thread != null;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_result());
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.white),
        child: Scaffold(
          backgroundColor: Colors.white,
          resizeToAvoidBottomInset: true,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                TitleBar(
                  title: 'Discussion',
                  onBack: () => Navigator.of(context).pop(_result()),
                  unread: widget.unread,
                  onBell: widget.callbacks.onBell ?? () => openSitePage(context, '/notifications'),
                ),
                Expanded(child: _body(c)),
                if (showBar)
                  ReplyComposerBar(
                    viewer: c.viewer,
                    input: _input,
                    focus: _focus,
                    sending: _sending,
                    target: target,
                    error: _sendError,
                    lockedReason: c.lockedReason,
                    onSend: _submit,
                    onClearTarget: _clearTarget,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(ThreadController c) {
    final post = c.post;
    if (post == null) {
      if (c.loading) return const ForumSpinner();
      return ForumMessage(
        icon: c.notFound ? LucideIcons.searchX : LucideIcons.cloudOff,
        title: c.notFound ? "This discussion isn't here" : "Couldn't load this discussion",
        body: c.notFound
            ? 'It may have been taken down, or the link is wrong.'
            : (c.error ?? 'Something went wrong. Try again.'),
        action: c.notFound ? null : 'Try again',
        onAction: c.start,
      );
    }
    if (c.thread == null && !c.loading && c.error != null) {
      return ForumMessage(
        icon: c.notFound ? LucideIcons.searchX : LucideIcons.cloudOff,
        title: c.notFound ? "This discussion isn't here" : "Couldn't load this discussion",
        body: c.notFound ? 'It may have been taken down, or the link is wrong.' : c.error!,
        action: c.notFound ? null : 'Try again',
        onAction: c.start,
      );
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: c.refresh,
      child: ListView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ThreadHeader(
            controller: c,
            actions: ThreadHeaderActions(
              onMenu: _threadMenu,
              onFollowAuthor: () => _run(c.toggleFollowAuthor()),
              onLike: () => _run(c.toggleLike()),
              onPickReaction: _pickReaction,
              onReply: () => _replyTo(_replyingTo),
              onSubscribe: () => _run(c.toggleSubscribed()),
              onSave: () => _run(c.toggleSave()),
              onShare: _share,
              onVote: (option) => _run(c.votePoll(option)),
              onReactors: _reactors,
              onViewers: _viewers,
              onOpenAuthor: widget.callbacks.onOpenMember == null
                  ? null
                  : () => widget.callbacks.onOpenMember!(post.author.id),
              onTag: widget.callbacks.onOpenTag == null ? null : (tag) => _openTag(tag),
              onTopic: widget.callbacks.onOpenTopic == null ? null : (topic) => _openTopic(topic),
              onLink: _openUrl,
              onOpenAttachment: (a) => a.url == null ? null : _openUrl(a.url!),
            ),
          ),
          if (c.thread != null && c.thread!.moderation == 'APPROVED')
            ReplySection(
              key: _repliesKey,
              controller: c,
              keyFor: _keyFor,
              focusId: c.focusReplyId,
              onLike: (reply) => _run(c.toggleReplyLike(reply)),
              onReplyTo: _replyTo,
              onMore: _replyMenu,
              onAccept: (reply) => _run(c.accept(reply)),
              onOpenAuthor: widget.callbacks.onOpenMember == null
                  ? null
                  : (reply) => widget.callbacks.onOpenMember!(reply.author.id),
              onOpenUrl: _openUrl,
            )
          else if (c.loading && c.thread == null)
            const Padding(padding: EdgeInsets.symmetric(vertical: 28), child: ForumSpinner()),
        ],
      ),
    );
  }

  void _openTag(String tag) {
    final result = _result();
    Navigator.of(context).pop(result);
    widget.callbacks.onOpenTag!(tag);
  }

  void _openTopic(ForumTopicRef topic) {
    final result = _result();
    Navigator.of(context).pop(result);
    widget.callbacks.onOpenTopic!(topic);
  }
}
