import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/util/links.dart';
import '../notifications/unread_counts.dart';
import 'inbox_controller.dart';
import 'messaging_launcher.dart';
import 'messaging_models.dart';
import 'messaging_repository.dart';
import 'messaging_styles.dart';
import 'widgets/conversation_tile.dart';
import 'widgets/new_message_sheet.dart';
import 'widgets/states.dart';

/// The person's messages, as the designed inbox (docs/designs/messaging-inbox.png): "Messaging" with its
/// "N Active" pill, an options menu and the "New message" pencil, a search box, one row of filter chips and the
/// threads. The options menu holds "Mark all as read" and, for someone who answers for a company, the inbox
/// switcher (their own messages and each company inbox, with the other inbox's unread count). Search covers
/// people, companies and message text; a company inbox has Open / Unread / Mine / Done / Spam and its topics;
/// pinned threads sit on top; press and hold a row to star or pin it. The list refreshes by itself every half
/// minute while the screen is open: the app has no socket client.
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
        backgroundColor: Colors.white,
        body: SafeArea(
          bottom: false,
          child: ListenableBuilder(
            listenable: _c,
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Controls(controller: _c, search: _search, onCompose: _compose, onMarkAll: _markAll),
                const Divider(height: 1, thickness: 1, color: InboxColors.rule),
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
            separatorBuilder: (_, _) => const _Rule(),
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
      color: InboxColors.navy,
      onRefresh: _c.refresh,
      child: CustomScrollView(controller: _scroll, physics: const AlwaysScrollableScrollPhysics(), slivers: slivers),
    );
  }

  SliverList _list(List<Conversation> rows, String? meId, DateTime now) => SliverList.separated(
    itemCount: rows.length,
    separatorBuilder: (_, _) => const _Rule(),
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

/// The hairline between two rows.
class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) => const Divider(height: 1, thickness: 1, color: InboxColors.rule);
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
    child: Text(text.toUpperCase(), style: InboxText.heading.copyWith(letterSpacing: 0.5)),
  );
}

/// What the options menu's rows return.
enum _Choice { markAll }

/// The header, the search box and the filter chips (the design's white block above the list).
class _Controls extends StatelessWidget {
  const _Controls({required this.controller, required this.search, required this.onCompose, required this.onMarkAll});

  final InboxController controller;
  final TextEditingController search;
  final VoidCallback onCompose;
  final VoidCallback onMarkAll;

  /// Every conversation this view holds, pinned ones included.
  int get _viewTotal => controller.total + controller.pinned.length;

  bool _isKind(InboxKind kind, Conversation c) => switch (kind) {
    InboxKind.requirement => c.kind?.isRequirement ?? false,
    InboxKind.mentorship =>
      c.kind == ConversationKind.mentorship ||
          c.kind == ConversationKind.groupSession ||
          c.kind == ConversationKind.consultation,
    InboxKind.direct => c.kind == ConversationKind.direct || c.kind == ConversationKind.company,
  };

  /// How many threads of [kind] the person has: this view's total while it is the kind on, the count in the
  /// list while the list is the whole inbox, else unknown (no count is better than a wrong one).
  int? _kindCount(InboxKind kind) {
    final q = controller.query;
    if (q.kind == kind) return _viewTotal;
    final whole = q.filter == InboxFilter.all && q.kind == null && q.search.trim().isEmpty && !controller.hasMore;
    if (!whole) return null;
    return [...controller.pinned, ...controller.conversations].where((c) => _isKind(kind, c)).length;
  }

  String _label(String base, int? count) => count == null ? base : '$base ($count)';

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final q = c.query;
    final loaded = !(c.loading && c.conversations.isEmpty && c.pinned.isEmpty);
    final inbox = c.currentInbox;
    final whole = q.filter == InboxFilter.all && q.kind == null && q.search.trim().isEmpty;

    Widget pill(String key, String label, bool on, VoidCallback onTap) =>
        _FilterPill(key: ValueKey(key), label: label, on: on, onTap: onTap);

    Widget row(List<Widget> chips) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SizedBox(
        height: 25,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: chips.length,
          separatorBuilder: (_, _) => const SizedBox(width: 6),
          itemBuilder: (_, i) => chips[i],
        ),
      ),
    );

    final pillText = !loaded
        ? null
        : q.companyInbox
        ? '${inbox?.name ?? 'Company'} · $_viewTotal Active'
        : '$_viewTotal Active';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 10, 7),
            child: SizedBox(
              height: 34,
              child: Row(
                children: [
                  if (Navigator.of(context).canPop()) const _BackButton(),
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 1),
                            child: Text('Messaging', style: InboxText.title),
                          ),
                          if (pillText != null) ...[
                            const SizedBox(width: 8),
                            Flexible(child: _ActivePill(text: pillText)),
                          ],
                        ],
                      ),
                    ),
                  ),
                  _OptionsMenu(controller: c, onMarkAll: onMarkAll),
                  _ComposeButton(onTap: onCompose),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _SearchBox(
              controller: search,
              onSubmitted: (v) {
                if (v.trim().isEmpty && search.text.isNotEmpty) search.clear();
                c.setSearch(v);
              },
            ),
          ),
          const SizedBox(height: 11.5),
          if (!q.companyInbox)
            row([
              pill(
                'filter-all',
                _label('Focused', whole && loaded ? _viewTotal : null),
                q.filter == InboxFilter.all && q.kind == null,
                () async {
                  if (q.kind != null) await c.setKind(null);
                  if (c.query.filter != InboxFilter.all) await c.setFilter(InboxFilter.all);
                },
              ),
              pill(
                'filter-unread',
                _label('Unread', c.unreadHere > 0 ? c.unreadHere : null),
                q.filter == InboxFilter.unread,
                () => c.setFilter(InboxFilter.unread),
              ),
              pill(
                'kind-requirement',
                _label('Vendor RFQs', loaded ? _kindCount(InboxKind.requirement) : null),
                q.kind == InboxKind.requirement,
                () => c.setKind(InboxKind.requirement),
              ),
              pill(
                'kind-mentorship',
                _label('Mentorship', loaded ? _kindCount(InboxKind.mentorship) : null),
                q.kind == InboxKind.mentorship,
                () => c.setKind(InboxKind.mentorship),
              ),
              pill(
                'filter-starred',
                'Starred',
                q.filter == InboxFilter.starred,
                () => c.setFilter(InboxFilter.starred),
              ),
              pill(
                'kind-direct',
                _label('Direct', loaded ? _kindCount(InboxKind.direct) : null),
                q.kind == InboxKind.direct,
                () => c.setKind(InboxKind.direct),
              ),
            ])
          else ...[
            row([
              for (final v in CompanyInboxView.values) pill('view-${v.name}', v.label, q.view == v, () => c.setView(v)),
            ]),
            if ((inbox?.topics.length ?? 0) > 1) ...[
              const SizedBox(height: 8),
              row([
                pill('topic-all', 'All topics', q.topic == null, () => c.setTopic(null)),
                for (final t in inbox!.topics)
                  pill('topic-$t', messageTopicLabels[t] ?? t, q.topic == t, () => c.setTopic(q.topic == t ? null : t)),
              ]),
            ],
          ],
        ],
      ),
    );
  }
}

/// "Back", for a screen pushed over another (the design's inbox has none: it is drawn as a tab's page).
class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Back',
    child: InkResponse(
      onTap: () => Navigator.maybePop(context),
      radius: 22,
      child: const SizedBox(
        width: 32,
        height: 34,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Icon(Symbols.arrow_back, size: 22, color: AppColors.onSurfaceVariant),
        ),
      ),
    ),
  );
}

/// "5 Active": a blue pill after the title.
class _ActivePill extends StatelessWidget {
  const _ActivePill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    height: 20.5,
    padding: const EdgeInsets.symmetric(horizontal: 8.5),
    decoration: BoxDecoration(color: InboxColors.blueTint, borderRadius: BorderRadius.circular(10.25)),
    child: Center(
      widthFactor: 1,
      child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: InboxText.activePill),
    ),
  );
}

/// The sliders button: a menu with "Mark all as read" and, for a company's people, the inbox switcher.
class _OptionsMenu extends StatelessWidget {
  const _OptionsMenu({required this.controller, required this.onMarkAll});

  final InboxController controller;
  final VoidCallback onMarkAll;

  static final _item = AppText.plexSans(12, FontWeight.w500, InboxColors.ink).copyWith(height: 1.3);

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final q = c.query;
    return PopupMenuButton<String>(
      key: const ValueKey('inbox-options'),
      tooltip: 'Inbox options',
      padding: EdgeInsets.zero,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      position: PopupMenuPosition.under,
      onSelected: (value) {
        if (value == _Choice.markAll.name) {
          onMarkAll();
        } else if (value.startsWith('inbox:')) {
          c.setInbox(value.substring(6));
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          key: const ValueKey('mark-all-read'),
          value: _Choice.markAll.name,
          enabled: c.unreadHere > 0,
          child: Row(
            children: [
              const Icon(LucideIcons.checkCheck, size: 18, color: InboxColors.navy),
              const SizedBox(width: 10),
              Text('Mark all as read', style: _item),
            ],
          ),
        ),
        if (c.companyInboxes.isNotEmpty) ...[
          const PopupMenuDivider(),
          for (final i in c.inboxes)
            PopupMenuItem<String>(
              key: ValueKey('inbox-${i.id}'),
              value: 'inbox:${i.id}',
              child: Row(
                children: [
                  Icon(i.personal ? LucideIcons.user : LucideIcons.building2, size: 18, color: InboxColors.soft),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      i.personal ? 'My messages' : (i.name ?? 'Company'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _item,
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (i.id == q.inbox)
                    const Icon(LucideIcons.check, size: 16, color: InboxColors.navy, semanticLabel: 'Open')
                  else if (i.unread > 0)
                    Container(
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(color: InboxColors.navy, borderRadius: BorderRadius.circular(8)),
                      child: Center(
                        widthFactor: 1,
                        heightFactor: 1,
                        child: Text('${i.unread}', style: InboxText.count),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ],
      child: SizedBox(
        width: 32,
        height: 34,
        child: Stack(
          alignment: const Alignment(0.0625, 0),
          children: [
            const Icon(Symbols.tune, size: 18, color: AppColors.slate500, semanticLabel: 'Inbox options'),
            // Another inbox has something waiting.
            if (c.unreadElsewhere > 0)
              Positioned(
                top: 6,
                right: 4,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The filled square with a pencil: "New message".
class _ComposeButton extends StatelessWidget {
  const _ComposeButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'New message',
    child: Tooltip(
      message: 'New message',
      excludeFromSemantics: true,
      child: InkResponse(
        key: const ValueKey('compose'),
        onTap: onTap,
        radius: 20,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Center(
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: InboxColors.navy, borderRadius: BorderRadius.circular(6)),
              child: const Icon(Symbols.edit_square, size: 18, color: Colors.white),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The grey search box with its magnifier and the design's hint.
class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.controller, required this.onSubmitted});

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) => Container(
    height: 32,
    padding: const EdgeInsets.only(left: 8),
    decoration: BoxDecoration(color: InboxColors.grey, borderRadius: BorderRadius.circular(4)),
    child: Row(
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 4),
          child: Icon(Symbols.search, size: 16, color: InboxColors.faint),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    style: InboxText.searchInput,
                    textAlignVertical: TextAlignVertical.center,
                    textInputAction: TextInputAction.search,
                    onSubmitted: onSubmitted,
                    cursorColor: InboxColors.navy,
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: 'Search messages, contacts, RFQs...',
                      hintStyle: InboxText.searchHint,
                      hintMaxLines: 1,
                    ),
                  ),
                ),
                if (value.text.isNotEmpty)
                  IconButton(
                    tooltip: 'Clear search',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    iconSize: 16,
                    onPressed: () {
                      controller.clear();
                      onSubmitted('');
                    },
                    icon: const Icon(LucideIcons.x, color: InboxColors.faint),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

/// A filter chip: navy with white words while it is the one on, light grey otherwise.
class _FilterPill extends StatelessWidget {
  const _FilterPill({super.key, required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: on,
    child: Material(
      color: on ? InboxColors.navy : InboxColors.grey,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 25,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          child: Text(label, maxLines: 1, style: on ? InboxText.filterOn : InboxText.filter),
        ),
      ),
    ),
  );
}
