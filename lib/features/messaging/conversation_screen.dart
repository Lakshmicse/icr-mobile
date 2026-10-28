import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api/api_error.dart';
import '../../core/config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart';
import '../notifications/notification_router.dart';
import '../notifications/unread_counts.dart';
import 'conversation_controller.dart';
import 'messaging_context.dart';
import 'messaging_format.dart';
import 'messaging_launcher.dart';
import 'messaging_models.dart';
import 'messaging_repository.dart';
import 'messaging_styles.dart';
import 'widgets/chat_avatar.dart';
import 'widgets/composer.dart';
import 'widgets/conversation_tile.dart' show kindIcon;
import 'widgets/message_bubble.dart';
import 'widgets/record_picker.dart';
import 'widgets/states.dart';

/// Hands a downloaded attachment to the person: the share sheet by default
/// (save it, or open it in another app); a recorder in tests.
typedef AttachmentOpener = Future<void> Function(BuildContext context, ChatMessage message, Uint8List bytes);

Future<void> shareAttachment(BuildContext context, ChatMessage message, Uint8List bytes) async {
  final name = message.attachmentName ?? 'attachment';
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, name: name, mimeType: message.attachmentMime)],
      fileNameOverrides: [name],
    ),
  );
}

/// One conversation, as the website's chat pane: the newest messages with
/// earlier ones a scroll away, what the thread is about under the header,
/// text and files sent from the box below (a failed send stays with Retry),
/// "Seen" on a 1:1, and a long-press menu on each message (reply, copy,
/// delete your own, report someone else's). New messages arrive by polling
/// every few seconds while the screen is open: the app has no socket client,
/// so there is no "typing" signal.
class ConversationScreen extends StatefulWidget {
  const ConversationScreen({
    super.key,
    required this.conversationId,
    this.asCompanyId,
    this.focusMessageId,
    this.initial,
    this.repository,
    this.controller,
    this.pickAttachment,
    this.openAttachment = shareAttachment,
    this.poll = true,
    this.pollInterval = const Duration(seconds: 4),
    this.clock,
  });

  final String conversationId;

  /// Read the thread from this company's inbox.
  final String? asCompanyId;

  /// Scrolls to this message once the thread is open.
  final String? focusMessageId;

  /// The inbox row the thread was opened from: the header fills in at once.
  final Conversation? initial;

  /// Defaults to one provided above, else the API.
  final MessagingRepository? repository;

  /// A controller made outside (tests); the screen then leaves its lifetime and start to its maker.
  final ConversationController? controller;

  /// Picks a file to send; defaults to [MessagingLauncher.attachmentPicker]. Without one there is no paperclip.
  final AttachmentPicker? pickAttachment;
  final AttachmentOpener openAttachment;
  final bool poll;
  final Duration pollInterval;

  /// The screen's "now" (day separators, "closes in…" lines); pinned by a golden or a test.
  final DateTime Function()? clock;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> with WidgetsBindingObserver {
  late final ConversationController _c;
  late final bool _owns;
  late final MessagingRepository _repository;
  final _text = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  final _keys = <String, GlobalKey>{};
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _repository = widget.repository ?? MessagingLauncher.repositoryOf(context);
    final unread = Provider.of<UnreadCounts?>(context, listen: false);
    _owns = widget.controller == null;
    _c =
        widget.controller ??
        ConversationController(
          _repository,
          conversationId: widget.conversationId,
          asCompanyId: widget.asCompanyId,
          initial: widget.initial,
          viewerId: MessagingLauncher.viewerIdOf(context),
          pollInterval: widget.pollInterval,
          clock: widget.clock,
          onRead: unread == null ? null : () => unawaited(unread.refresh()),
        );
    _scroll.addListener(_maybeLoadOlder);
    if (_owns) {
      unawaited(_c.start());
      if (widget.poll) _c.startPolling();
    }
    _c.addListener(_focusOnce);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _c.removeListener(_focusOnce);
    _scroll.dispose();
    _text.dispose();
    _focus.dispose();
    if (_owns) _c.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_owns || !widget.poll) return;
    if (state == AppLifecycleState.resumed) {
      unawaited(_c.poll());
      _c.startPolling();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _c.stopPolling();
    }
  }

  void _maybeLoadOlder() {
    if (!_scroll.hasClients) return;
    // The list is reversed: the far end is the oldest message.
    if (_scroll.position.extentAfter < 300) unawaited(_c.loadOlder());
  }

  /// Scrolls to the message the thread was opened on, once it has loaded. A hit
  /// older than the newest window is paged back to first.
  void _focusOnce() {
    final id = widget.focusMessageId;
    if (_focused || id == null || !_c.loaded) return;
    _focused = true;
    unawaited(() async {
      final found = await _c.ensureLoaded(id);
      if (!mounted) return;
      if (!found) {
        showMessage(context, 'That message is no longer in this conversation.');
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_jumpTo(id, quiet: true)));
    }());
  }

  /// Brings a message into view: scrolls toward it until it has been built, then centres it.
  Future<void> _jumpTo(String id, {bool quiet = false}) async {
    for (var step = 0; step < 40; step++) {
      if (!mounted) return;
      final target = _keys[id]?.currentContext;
      if (target != null && target.mounted) {
        await Scrollable.ensureVisible(target, duration: const Duration(milliseconds: 250), alignment: 0.4);
        return;
      }
      if (!_scroll.hasClients || !mounted) break;
      final items = _c.timeline;
      final at = items.indexWhere((i) => i is MessageItem && i.message.id == id);
      if (at < 0) break;
      // The list is reversed: older messages are further along the scroll extent.
      final p = _scroll.position;
      final next = (p.pixels + p.viewportDimension * 0.8).clamp(0.0, p.maxScrollExtent);
      if (next == p.pixels) break;
      _scroll.jumpTo(next);
      await WidgetsBinding.instance.endOfFrame;
    }
    if (!quiet && mounted) {
      showMessage(context, 'That message is further back. Scroll up to load earlier messages.');
    }
  }

  // --- actions ---------------------------------------------------------------

  Future<void> _send() async {
    final text = _text.text;
    final problem = _c.problemWith(text);
    if (problem != null) {
      showMessage(context, problem);
      return;
    }
    _text.clear();
    // A refusal stays in the thread as a failed message with Retry, so nothing typed is lost.
    unawaited(_c.send(text));
    if (_scroll.hasClients) {
      unawaited(_scroll.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut));
    }
  }

  Future<void> _attach() async {
    final pick = widget.pickAttachment ?? MessagingLauncher.attachmentPicker;
    if (pick == null) return;
    final file = await pick(context);
    if (file == null || !mounted) return;
    final problem = await _c.attach(file);
    if (problem != null && mounted) showMessage(context, problem);
  }

  Future<void> _shareRecord() async {
    final picked = await showRecordPicker(context, _repository);
    if (picked == null || !mounted) return;
    final link = '${AppConfig.siteUrl}${picked.ref.path}';
    final current = _text.text;
    final joined = current.trim().isEmpty ? link : '${current.trimRight()}\n$link';
    _text.value = TextEditingValue(
      text: joined,
      selection: TextSelection.collapsed(offset: joined.length),
    );
    _focus.requestFocus();
  }

  Future<void> _openAttachment(ChatMessage m) async {
    final url = m.attachmentUrl;
    if (url == null) return;
    try {
      final bytes = await _c.attachmentBytes(url);
      if (bytes.isEmpty) throw StateError('empty');
      if (!mounted) return;
      await widget.openAttachment(context, m, bytes);
    } catch (e) {
      if (mounted) {
        final why = e is StateError ? 'Try again.' : ApiError.from(e).message;
        showMessage(context, "The file couldn't be opened. $why");
      }
    }
  }

  /// A link in a message: an ICR page opens in the app (or the website), anything else in the browser.
  void _openLink(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (recordOrigins().contains(uri.origin)) {
      final path = '${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}${uri.hasFragment ? '#${uri.fragment}' : ''}';
      unawaited(NotificationRouter.of(context).openHref(context, path.isEmpty ? '/' : path));
    } else {
      unawaited(openUrl(context, uri));
    }
  }

  void _openHref(String href) => unawaited(NotificationRouter.of(context).openHref(context, href));

  Future<void> _messageMenu(ChatMessage m) async {
    if (m.deleted) return;
    final mine = _c.isMine(m);
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            _SheetRow(icon: LucideIcons.reply, label: 'Reply', value: 'reply'),
            if (m.body.trim().isNotEmpty) _SheetRow(icon: LucideIcons.copy, label: 'Copy text', value: 'copy'),
            if (mine) _SheetRow(icon: LucideIcons.trash2, label: 'Delete message', value: 'delete', danger: true),
            if (!mine) _SheetRow(icon: LucideIcons.flag, label: 'Report message', value: 'report'),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'reply':
        _c.setReplyTo(m);
        _focus.requestFocus();
      case 'copy':
        await Clipboard.setData(ClipboardData(text: m.body));
        if (mounted) showMessage(context, 'Copied');
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete this message?'),
            content: const Text('It is removed for everyone in the conversation.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              TextButton(
                key: const ValueKey('confirm-delete'),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (ok != true || !mounted) return;
        final error = await _c.delete(m);
        if (error != null && mounted) showMessage(context, error);
      case 'report':
        await _report(m);
    }
  }

  Future<void> _report(ChatMessage m) async {
    final result = await showModalBottomSheet<({String reason, String note})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => const _ReportSheet(),
    );
    if (result == null || !mounted) return;
    final error = await _c.report(m, result.reason, note: result.note);
    if (!mounted) return;
    showMessage(context, error ?? 'Thanks. ICR will review this message.');
  }

  Future<void> _toggle(Future<String?> Function() action) async {
    final error = await action();
    if (error != null && mounted) showMessage(context, error);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.white),
      child: Scaffold(
        backgroundColor: ChatColors.page,
        body: SafeArea(
          bottom: false,
          child: ListenableBuilder(
            listenable: _c,
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(controller: _c, onProfile: _openHref, onToggle: _toggle),
                _Strip(controller: _c, onOpen: _openHref, now: _c.clock()),
                Expanded(child: _body()),
                if (_c.loaded && !_c.cannotOpen)
                  Composer(
                    controller: _c,
                    text: _text,
                    focus: _focus,
                    onSend: _send,
                    onAttach: (widget.pickAttachment ?? MessagingLauncher.attachmentPicker) == null ? null : _attach,
                    onShareRecord: _shareRecord,
                    asCompany: _c.side == null ? null : _c.myParty?.name,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (!_c.loaded) {
      if (_c.error != null) {
        return Center(
          child: SingleChildScrollView(
            child: ChatNotice(
              icon: _c.cannotOpen ? LucideIcons.lock : LucideIcons.cloudOff,
              title: _c.error!,
              body: _c.cannotOpen ? 'It may belong to another account, or you may have left it.' : null,
              action: _c.cannotOpen ? 'Back to messages' : 'Retry',
              onAction: _c.cannotOpen ? () => Navigator.maybePop(context) : _c.retry,
            ),
          ),
        );
      }
      return const ChatSpinner();
    }
    final items = _c.timeline;
    if (items.isEmpty) return _Empty(controller: _c, onStarter: _fill);
    final display = _c.display;
    final room = display.avatar == AvatarKind.group;
    final seenId = _c.seenMessageId;
    final count = items.length + (_c.hasMore ? 1 : 0);
    return ListView.builder(
      key: const ValueKey('thread'),
      controller: _scroll,
      reverse: true,
      cacheExtent: 2000,
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      itemCount: count,
      itemBuilder: (context, i) {
        if (i == items.length) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Center(
              child: _c.loadingOlder
                  ? const ChatSpinner(size: 20)
                  : TextButton(
                      key: const ValueKey('load-earlier'),
                      onPressed: _c.loadOlder,
                      child: Text('Load earlier messages', style: ChatText.barAction),
                    ),
            ),
          );
        }
        final item = items[items.length - 1 - i];
        return switch (item) {
          DayItem() => DayDivider(date: item.date, now: _c.clock()),
          EventItem() => Builder(
            builder: (context) {
              final line = eventLine(item.event, _c.context);
              return EventLine(
                title: line.title,
                action: line.action,
                onAction: line.href == null ? null : () => _openHref(line.href!),
              );
            },
          ),
          PendingItem() => PendingBubble(
            key: ValueKey(item.pending.localId),
            pending: item.pending,
            onRetry: () => unawaited(_c.retrySend(item.pending)),
            onDiscard: () {
              final body = _c.discard(item.pending);
              if (_text.text.trim().isEmpty) _text.text = body;
            },
          ),
          MessageItem() => KeyedSubtree(
            key: _keys.putIfAbsent(item.message.id, GlobalKey.new),
            child: MessageBubble(
              message: item.message,
              mine: _c.isMine(item.message),
              continued: item.continued,
              showSender: room || item.message.senderCompany != null,
              seen: item.message.id == seenId && _c.isMine(item.message),
              controller: _c,
              onLongPress: () => _messageMenu(item.message),
              onLink: _openLink,
              onOpenAttachment: _openAttachment,
              onOpenRecord: (ref) => _openHref(ref.path),
              onJumpToReply: (id) => unawaited(_jumpTo(id)),
            ),
          ),
        };
      },
    );
  }

  void _fill(String text) {
    _text.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _focus.requestFocus();
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({required this.icon, required this.label, required this.value, this.danger = false});

  final IconData icon;
  final String label;
  final String value;
  final bool danger;

  @override
  Widget build(BuildContext context) => ListTile(
    key: ValueKey('action-$value'),
    leading: Icon(icon, size: 20, color: danger ? AppColors.error : AppColors.slate600),
    title: Text(label, style: ChatText.label.copyWith(fontSize: 14, color: danger ? AppColors.error : null)),
    onTap: () => Navigator.of(context).pop(value),
  );
}

/// The thread's header: back, who it is with (a tap opens their page), and a menu.
class _Header extends StatelessWidget {
  const _Header({required this.controller, required this.onProfile, required this.onToggle});

  final ConversationController controller;
  final ValueChanged<String> onProfile;
  final Future<void> Function(Future<String?> Function() action) onToggle;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final conversation = c.conversation;
    final display = c.display;
    final kind = c.context?.kind ?? conversation?.kind;
    final sub = <String>[
      ?kind?.label,
      if (display.secondary != null) display.secondary!,
      if (display.avatar == AvatarKind.group && conversation != null)
        '${conversation.participants.length} people'
      else if (display.avatar == AvatarKind.person && display.company != null)
        display.company!.name,
    ].join(' · ');
    final href = switch (display.avatar) {
      AvatarKind.company when display.company != null && display.company!.id.isNotEmpty => companyHref(
        display.company!.id,
      ),
      AvatarKind.person when display.person != null && display.person!.id.isNotEmpty => memberHref(display.person!.id),
      _ => null,
    };
    final party = c.myParty;
    return Container(
      height: 60,
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back, color: AppColors.onSurfaceVariant),
          ),
          Expanded(
            child: InkWell(
              key: const ValueKey('thread-header'),
              onTap: href == null ? null : () => onProfile(href),
              child: Row(
                children: [
                  ChatAvatar.forDisplay(display, size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(display.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ChatText.headerName),
                        if (sub.isNotEmpty)
                          Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: ChatText.headerSub),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (conversation != null)
            PopupMenuButton<String>(
              key: const ValueKey('thread-menu'),
              tooltip: 'More',
              icon: const Icon(LucideIcons.ellipsisVertical, size: 20, color: AppColors.onSurfaceVariant),
              onSelected: (v) {
                switch (v) {
                  case 'star':
                    onToggle(c.toggleStar);
                  case 'pin':
                    onToggle(c.togglePin);
                  case 'done':
                    onToggle(() => c.setStatus(ThreadStatus.done));
                  case 'spam':
                    onToggle(() => c.setStatus(ThreadStatus.spam));
                  case 'open':
                    onToggle(() => c.setStatus(ThreadStatus.open));
                  case 'assign':
                    onToggle(c.assignToMe);
                  case 'unassign':
                    onToggle(c.unassign);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'star', child: Text(conversation.starred ? 'Remove star' : 'Star conversation')),
                PopupMenuItem(value: 'pin', child: Text(conversation.pinned ? 'Unpin from top' : 'Pin to top')),
                if (party != null) ...[
                  const PopupMenuDivider(),
                  if (party.status == ThreadStatus.open) ...[
                    const PopupMenuItem(value: 'done', child: Text('Mark done')),
                    const PopupMenuItem(value: 'spam', child: Text('Mark as spam')),
                  ] else
                    const PopupMenuItem(value: 'open', child: Text('Move back to open')),
                  if (party.assignee == null)
                    const PopupMenuItem(value: 'assign', child: Text('Assign to me'))
                  else
                    const PopupMenuItem(value: 'unassign', child: Text('Unassign')),
                ],
              ],
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }
}

/// What the thread is about, one tap from the record.
class _Strip extends StatelessWidget {
  const _Strip({required this.controller, required this.onOpen, required this.now});

  final ConversationController controller;
  final ValueChanged<String> onOpen;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final model = contextStripModel(controller.context, controller.conversation?.title, now: now);
    if (model == null) return const SizedBox.shrink();
    final lines = model.lines;
    final kind = controller.context?.kind ?? controller.conversation?.kind;
    return Material(
      color: ChatColors.strip,
      child: InkWell(
        key: const ValueKey('context-strip'),
        onTap: model.href == null ? null : () => onOpen(model.href!),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: ChatColors.rule)),
          ),
          padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.slate200),
                ),
                child: Icon(kind == null ? LucideIcons.fileText : kindIcon(kind), size: 15, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (lines.line != null)
                      Text(lines.line!, maxLines: 1, overflow: TextOverflow.ellipsis, style: ChatText.stripKind),
                    Text(lines.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ChatText.stripTitle),
                  ],
                ),
              ),
              if (model.href != null) const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.slate500),
            ],
          ),
        ),
      ),
    );
  }
}

/// An empty thread: who it is with, what to say, and openers for the context.
class _Empty extends StatelessWidget {
  const _Empty({required this.controller, required this.onStarter});

  final ConversationController controller;
  final ValueChanged<String> onStarter;

  @override
  Widget build(BuildContext context) {
    final context0 = controller.context;
    final chips = starters(context0);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ChatAvatar.forDisplay(controller.display, size: 64),
            const SizedBox(height: 12),
            Text(controller.display.name, textAlign: TextAlign.center, style: ChatText.sheetTitle),
            const SizedBox(height: 6),
            Text(introText(context0), textAlign: TextAlign.center, style: ChatText.rowPreview),
            if (chips.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('Start with', style: ChatText.hint),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in chips)
                    ActionChip(
                      key: ValueKey('starter-${s.key}'),
                      label: Text(s.text, style: ChatText.label),
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: AppColors.slate200),
                      onPressed: () => onStarter(s.text),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet();

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  String? _reason;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Report this message', style: ChatText.sheetTitle),
            const SizedBox(height: 4),
            Text(
              'ICR reviews reports and may remove the message. The sender is not told who reported it.',
              style: ChatText.hint,
            ),
            const SizedBox(height: 8),
            RadioGroup<String>(
              groupValue: _reason,
              onChanged: (v) => setState(() => _reason = v),
              child: Column(
                children: [
                  for (final e in messageReportReasons.entries)
                    RadioListTile<String>(
                      key: ValueKey('reason-${e.key}'),
                      value: e.key,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(e.value, style: ChatText.label.copyWith(fontSize: 14)),
                    ),
                ],
              ),
            ),
            TextField(
              controller: _note,
              maxLength: 1000,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(hintText: 'Add a note (optional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('send-report'),
                onPressed: _reason == null
                    ? null
                    : () => Navigator.of(context).pop((reason: _reason!, note: _note.text.trim())),
                child: const Text('Report'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
