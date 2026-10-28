import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart';
import '../../core/widgets/chips.dart';
import '../../core/widgets/search_field.dart';
import '../notifications/unread_counts.dart';
import 'inbox_controller.dart';
import 'messaging_launcher.dart';
import 'messaging_models.dart';
import 'messaging_repository.dart';
import 'messaging_styles.dart';
import 'widgets/conversation_tile.dart';
import 'widgets/new_message_sheet.dart';
import 'widgets/states.dart';

/// The person's messages, as the website's inbox on a phone: their own and
/// each company inbox they answer for (switch between them), search across
/// people and message text, All / Unread / Starred and a kind filter (a
/// company inbox has Open / Unread / Mine / Done / Spam and its topics),
/// pinned threads on top, mark all read, a long-press menu to star or pin,
/// and "New message". The list refreshes by itself every half minute while
/// the screen is open: the app has no socket client.
class InboxScreen extends StatefulWidget {
  const InboxScreen({
    super.key,
    this.initialInbox,
    this.repository,
    this.controller,
    this.poll = true,
    this.pickAttachment,
    this.clock,
  });

  /// `personal`, or a company's id: opens on that inbox.
  final String? initialInbox;

  /// Defaults to one provided above, else the API.
  final MessagingRepository? repository;

  /// A controller made outside (tests); the screen then leaves its lifetime and start to its maker.
  final InboxController? controller;
  final bool poll;

  /// Passed to the conversations opened from here.
  final AttachmentPicker? pickAttachment;

  /// The screen's "now", for each row's stamp; pinned by a golden or a test.
  final DateTime Function()? clock;

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> with WidgetsBindingObserver {
  late final InboxController _c;
  late final bool _owns;
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final unread = Provider.of<UnreadCounts?>(context, listen: false);
    _owns = widget.controller == null;
    _c =
        widget.controller ??
        InboxController(
          widget.repository ?? MessagingLauncher.repositoryOf(context),
          viewerId: MessagingLauncher.viewerIdOf(context),
          clock: widget.clock,
          onRead: unread == null ? null : () => unawaited(unread.refresh()),
        );
    _scroll.addListener(_maybeLoadMore);
    _search.addListener(_typing);
    if (_owns) {
      unawaited(_start());
      if (widget.poll) _c.startPolling();
    }
  }

  Future<void> _start() async {
    final inbox = widget.initialInbox;
    if (inbox != null && inbox != MessagingInbox.personalId) {
      await _c.setInbox(inbox);
    }
    await _c.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    if (_owns) _c.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_owns || !widget.poll) return;
    if (state == AppLifecycleState.resumed) {
      unawaited(_c.refreshQuietly());
      _c.startPolling();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _c.stopPolling();
    }
  }

  void _maybeLoadMore() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.extentAfter < 240) unawaited(_c.loadMore());
  }

  /// Searches as the person types, a moment after they pause.
  void _typing() {
    _debounce?.cancel();
    if (_search.text.trim() == _c.query.search.trim()) return;
    _debounce = Timer(const Duration(milliseconds: 450), () => _c.setSearch(_search.text));
  }

  Future<void> _open(String id, {String? asCompanyId, Conversation? initial, String? focusMessageId}) async {
    await MessagingLauncher.openConversation(
      context,
      id,
      asCompanyId: asCompanyId,
      focusMessageId: focusMessageId,
      initial: initial,
      repository: _c.repository,
      pickAttachment: widget.pickAttachment,
    );
    if (!mounted) return;
    // Back from the thread: its row has lost its count.
    _c.markedRead(id);
    unawaited(_c.refreshQuietly());
    final unread = Provider.of<UnreadCounts?>(context, listen: false);
    if (unread != null) unawaited(unread.refresh());
  }

  Future<void> _compose() async {
    final id = await showNewMessage(context, _c.repository);
    if (id != null && mounted) await _open(id);
  }

  Future<void> _markAll() async {
    final error = await _c.markAllRead();
    if (!mounted) return;
    showMessage(context, error ?? 'All marked as read');
  }

  Future<void> _menu(Conversation c) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              key: const ValueKey('menu-star'),
              leading: Icon(c.starred ? Icons.star_rounded : Icons.star_outline_rounded, color: ChatColors.star),
              title: Text(c.starred ? 'Remove star' : 'Star conversation'),
              onTap: () => Navigator.pop(context, 'star'),
            ),
            ListTile(
              key: const ValueKey('menu-pin'),
              leading: const Icon(LucideIcons.pin, color: AppColors.slate600),
              title: Text(c.pinned ? 'Unpin from top' : 'Pin to top'),
              onTap: () => Navigator.pop(context, 'pin'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    final error = action == 'star' ? await _c.toggleStar(c) : await _c.togglePin(c);
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
                ChatTitleBar(
                  title: 'Messages',
                  actions: [
                    IconButton(
                      key: const ValueKey('mark-all-read'),
                      tooltip: 'Mark all as read',
                      onPressed: _c.unreadHere == 0 ? null : _markAll,
                      icon: const Icon(LucideIcons.checkCheck, size: 20),
                      color: AppColors.primary,
                      disabledColor: AppColors.slate400,
                    ),
                    IconButton(
                      key: const ValueKey('compose'),
                      tooltip: 'New message',
                      onPressed: _compose,
                      icon: const Icon(LucideIcons.squarePen, size: 20),
                      color: AppColors.primary,
                    ),
                  ],
                ),
                _Controls(controller: _c, search: _search),
                const Divider(height: 1, color: ChatColors.rule),
                Expanded(child: _body()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    final slivers = <Widget>[];
    final empty = _c.conversations.isEmpty && _c.pinned.isEmpty && _c.hits.isEmpty;
    if (_c.error != null && empty) {
      slivers.add(
        SliverFillRemaining(
          hasScrollBody: false,
          child: ChatNotice(
            icon: LucideIcons.cloudOff,
            title: 'Your messages could not be loaded.',
            body: _c.error,
            action: 'Retry',
            onAction: _c.refresh,
          ),
        ),
      );
    } else if (_c.loading && empty) {
      slivers.add(const SliverFillRemaining(hasScrollBody: false, child: ChatSpinner()));
    } else if (empty) {
      slivers.add(SliverFillRemaining(hasScrollBody: false, child: _emptyNotice()));
    } else {
      final now = _c.clock();
      final meId = _c.viewerId;
      final company = _c.query.companyInbox ? _c.query.inbox : null;
      if (_c.hits.isNotEmpty) {
        slivers.add(const SliverToBoxAdapter(child: _Heading('Messages')));
        slivers.add(
          SliverList.separated(
            itemCount: _c.hits.length,
            separatorBuilder: (_, _) => const Divider(height: 1, thickness: 1, color: ChatColors.rule, indent: 16),
            itemBuilder: (context, i) {
              final h = _c.hits[i];
              return SearchHitTile(
                key: ValueKey('hit-${h.messageId}'),
                hit: h,
                meId: meId,
                now: now,
                onTap: () => _open(h.conversationId, asCompanyId: company, focusMessageId: h.messageId),
              );
            },
          ),
        );
      }
      if (_c.pinned.isNotEmpty) {
        slivers.add(const SliverToBoxAdapter(child: _Heading('Pinned')));
        slivers.add(_list(_c.pinned, meId, now));
      }
      if (_c.conversations.isNotEmpty) {
        if (_c.pinned.isNotEmpty || _c.hits.isNotEmpty) {
          slivers.add(SliverToBoxAdapter(child: _Heading(_c.searching ? 'Conversations' : 'All messages')));
        }
        slivers.add(_list(_c.conversations, meId, now));
      }
      slivers.add(SliverToBoxAdapter(child: _footer()));
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _c.refresh,
      child: CustomScrollView(controller: _scroll, physics: const AlwaysScrollableScrollPhysics(), slivers: slivers),
    );
  }

  SliverList _list(List<Conversation> rows, String? meId, DateTime now) => SliverList.separated(
    itemCount: rows.length,
    separatorBuilder: (_, _) => const Divider(height: 1, thickness: 1, color: ChatColors.rule, indent: 74),
    itemBuilder: (context, i) {
      final c = rows[i];
      return ConversationTile(
        key: ValueKey('conversation-${c.id}'),
        conversation: c,
        meId: meId,
        now: now,
        onTap: () => _open(c.id, asCompanyId: c.asCompanyId, initial: c),
        onLongPress: () => _menu(c),
      );
    },
  );

  Widget _emptyNotice() {
    final q = _c.query;
    if (_c.searching) {
      return ChatNotice(
        icon: LucideIcons.searchX,
        title: 'No matches',
        body: 'Nothing in your messages matches "${q.search.trim()}".',
      );
    }
    if (q.companyInbox) {
      return ChatNotice(icon: LucideIcons.inbox, title: q.view.empty);
    }
    return switch (q.filter) {
      InboxFilter.unread => const ChatNotice(
        icon: LucideIcons.checkCheck,
        title: "You're all caught up",
        body: 'Nothing is waiting for a reply.',
      ),
      InboxFilter.starred => const ChatNotice(
        icon: LucideIcons.star,
        title: 'Nothing starred',
        body: 'Press and hold a conversation to star it.',
      ),
      InboxFilter.all => ChatNotice(
        icon: LucideIcons.messageCircle,
        title: q.kind == null ? 'No messages yet' : 'Nothing here',
        body: q.kind == null
            ? 'Message a person, a supplier or a company from their page, or tap the pencil to start one.'
            : 'No ${q.kind!.label.toLowerCase()} conversations.',
        action: q.kind == null ? 'New message' : null,
        onAction: q.kind == null ? _compose : null,
      ),
    };
  }

  Widget _footer() {
    if (_c.loadingMore) return const Padding(padding: EdgeInsets.all(20), child: ChatSpinner(size: 20));
    if (!_c.hasMore) return const SizedBox(height: 32);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Center(
        child: TextButton(
          key: const ValueKey('load-more'),
          onPressed: _c.loadMore,
          child: Text('Show more conversations', style: ChatText.barAction),
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
    child: Text(text.toUpperCase(), style: ChatText.section),
  );
}

/// The inbox switcher, the search box and the filter chips.
class _Controls extends StatelessWidget {
  const _Controls({required this.controller, required this.search});

  final InboxController controller;
  final TextEditingController search;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final q = c.query;
    Widget chip(String key, String label, bool on, VoidCallback onTap, {Widget? trailing, IconData? icon}) => IcrChip(
      key: ValueKey(key),
      label: label,
      tone: on ? ChipTone.primary : ChipTone.outlined,
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      icon: icon,
      iconSize: 13,
      iconColor: on ? Colors.white : AppColors.slate500,
      trailing: trailing,
      trailingGap: 6,
      textStyle: ChatText.label.copyWith(color: on ? Colors.white : AppColors.onSurface),
      onTap: onTap,
    );

    Widget row(List<Widget> chips) => SizedBox(
      height: 30,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) => chips[i],
      ),
    );

    Widget dot(int n) => n > 0
        ? Container(
            constraints: const BoxConstraints(minWidth: 16),
            height: 16,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(8)),
            child: Text('$n', style: ChatText.count),
          )
        : const SizedBox.shrink();

    final inbox = c.currentInbox;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(top: 10, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (c.companyInboxes.isNotEmpty) ...[
            row([
              for (final i in c.inboxes)
                chip(
                  'inbox-${i.id}',
                  i.personal ? 'My messages' : (i.name ?? 'Company'),
                  i.id == q.inbox,
                  () => c.setInbox(i.id),
                  icon: i.personal ? LucideIcons.user : LucideIcons.building2,
                  trailing: i.id == q.inbox ? null : dot(i.unread),
                ),
            ]),
            const SizedBox(height: 10),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: IcrSearchField(
              controller: search,
              height: 36,
              hint: 'Search people, companies and messages',
              onSubmitted: (v) {
                if (v.trim().isEmpty && search.text.isNotEmpty) search.clear();
                c.setSearch(v);
              },
            ),
          ),
          const SizedBox(height: 10),
          if (!q.companyInbox) ...[
            row([
              chip('filter-all', 'All', q.filter == InboxFilter.all, () => c.setFilter(InboxFilter.all)),
              chip(
                'filter-unread',
                'Unread',
                q.filter == InboxFilter.unread,
                () => c.setFilter(InboxFilter.unread),
                trailing: q.filter == InboxFilter.unread ? null : dot(c.unreadHere),
              ),
              chip(
                'filter-starred',
                'Starred',
                q.filter == InboxFilter.starred,
                () => c.setFilter(InboxFilter.starred),
              ),
              for (final k in InboxKind.values) chip('kind-${k.name}', k.label, q.kind == k, () => c.setKind(k)),
            ]),
          ] else ...[
            row([
              for (final v in CompanyInboxView.values) chip('view-${v.name}', v.label, q.view == v, () => c.setView(v)),
            ]),
            if ((inbox?.topics.length ?? 0) > 1) ...[
              const SizedBox(height: 8),
              row([
                chip('topic-all', 'All topics', q.topic == null, () => c.setTopic(null)),
                for (final t in inbox!.topics)
                  chip('topic-$t', messageTopicLabels[t] ?? t, q.topic == t, () => c.setTopic(q.topic == t ? null : t)),
              ]),
            ],
          ],
        ],
      ),
    );
  }
}
