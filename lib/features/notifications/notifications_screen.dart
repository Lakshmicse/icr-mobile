import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart';
import '../messaging/messaging_styles.dart';
import '../shell/app_shell.dart';
import '../feed/feed_styles.dart' show HomeLook;
import 'notification_styles.dart';
import '../messaging/widgets/states.dart';
import 'api_notifications_repository.dart';
import 'demo_notifications_repository.dart';
import 'notification_models.dart';
import 'notification_router.dart';
import 'notification_scope.dart';
import 'notification_target.dart';
import 'notifications_controller.dart';
import 'notifications_repository.dart';
import 'unread_counts.dart';
import 'widgets/notification_row.dart';
import 'widgets/preferences_view.dart';

/// Opens a notification's record. Given to [NotificationsScreen] it replaces
/// the app's [NotificationRouter] for taps on a row.
typedef NotificationTargetOpener = Future<void> Function(BuildContext context, NotificationTarget target);

/// Opens the notifications screen over whatever called it: what every
/// title bar's bell does.
Future<void> openNotifications(
  BuildContext context, {
  NotificationsTab tab = NotificationsTab.all,
  NotificationTargetOpener? onOpenTarget,
}) {
  final scope = NotificationScope.of(context);
  // Through the shell, so a record opened from a row can still reach the shell's menu and tabs.
  return AppShell.push<void>(
    context,
    (_) => scope.wrap(NotificationsScreen(initialTab: tab, onOpenTarget: onOpenTarget)),
  );
}

/// Every notification the person has had, as the website's page: All or
/// Unread (grouped Today, This week, Earlier, a page at a time), mark one or
/// all read, and the Preferences tab. Tapping a row reads it and opens its
/// record in the app through the [NotificationRouter] (the website when no
/// screen of the app takes it), switching to the row's company first when the
/// person is acting for another.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    this.initialTab = NotificationsTab.all,
    this.repository,
    this.controller,
    this.onOpenTarget,
    this.clock,
  });

  final NotificationsTab initialTab;

  /// Where a tapped row's record opens. Without it, the app's
  /// [NotificationRouter] (the website for a page no screen of the app takes).
  final NotificationTargetOpener? onOpenTarget;

  /// Defaults to one provided above, else the API (the demo with `FEED_SOURCE=demo`).
  final NotificationsRepository? repository;

  /// The screen's "now", for its groups and ages; pinned by a golden or a test.
  final DateTime Function()? clock;

  /// A controller made outside (tests, goldens); the screen then leaves its lifetime to its maker.
  final NotificationsController? controller;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final NotificationsController _c;
  late final bool _owns;
  final _scroll = ScrollController();
  bool _opening = false;

  static DemoNotificationsRepository? _demo;

  @override
  void initState() {
    super.initState();
    _owns = widget.controller == null;
    final unread = Provider.of<UnreadCounts?>(context, listen: false);
    _c =
        widget.controller ??
        NotificationsController(_repository(), clock: widget.clock, onUnreadChanged: unread?.setNotifications);
    _scroll.addListener(_maybeLoadMore);
    if (_owns) {
      unawaited(_c.start());
      if (widget.initialTab != NotificationsTab.all) unawaited(_c.setTab(widget.initialTab));
    }
  }

  NotificationsRepository _repository() {
    final provided = widget.repository ?? Provider.of<NotificationsRepository?>(context, listen: false);
    if (provided != null) return provided;
    if (AppConfig.demo) return _demo ??= DemoNotificationsRepository();
    return ApiNotificationsRepository(api: context.read<ApiClient>());
  }

  @override
  void dispose() {
    _scroll.dispose();
    if (_owns) _c.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.extentAfter < 240) _c.loadMore();
  }

  Future<void> _open(AppNotification n) async {
    if (_opening) return;
    _opening = true;
    try {
      // Reads at once; a refusal puts the dot back and is shown (over whichever page is on top).
      unawaited(
        _c.markRead(n).then((refusal) {
          if (refusal != null && mounted) showMessage(context, refusal);
        }),
      );
      final target = NotificationTarget.parse(n.link);
      if (target.kind == NotificationKinds.none) return;
      final router = NotificationRouter.of(context);
      final open = widget.onOpenTarget;
      if (_c.needsSwitch(n)) {
        final refusal = await _c.switchTo(n.company!);
        if (!mounted) return;
        if (refusal != null) {
          showMessage(context, refusal);
          return;
        }
        showMessage(context, 'Now working as ${n.company!.name}');
        router.onCompanySwitched?.call(context, n.company!.id);
      }
      if (open != null) {
        await open(context, target);
      } else {
        await router.open(context, target);
      }
    } finally {
      _opening = false;
    }
  }

  /// The ⋮ sheet: read it, turn its category off, or go to the settings.
  Future<void> _showMenu(AppNotification n) async {
    final category = n.category;
    final action = await showModalBottomSheet<_RowAction>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (n.unread)
              _SheetRow(
                key: const ValueKey('note-menu-read'),
                icon: Icons.done_all,
                title: 'Mark as read',
                onTap: () => Navigator.pop(sheet, _RowAction.read),
              ),
            if (!category.locked)
              _SheetRow(
                key: const ValueKey('note-menu-off'),
                icon: Icons.notifications_off_outlined,
                title: 'Turn off ${category.label} notifications',
                hint: 'You can turn them back on in the settings.',
                onTap: () => Navigator.pop(sheet, _RowAction.turnOff),
              ),
            _SheetRow(
              key: const ValueKey('note-menu-settings'),
              icon: Icons.settings_outlined,
              title: 'Notification settings',
              onTap: () => Navigator.pop(sheet, _RowAction.settings),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _RowAction.read:
        final refusal = await _c.markRead(n);
        if (refusal != null && mounted) showMessage(context, refusal);
      case _RowAction.turnOff:
        final refusal = await _c.turnOffCategory(category);
        if (!mounted) return;
        showMessage(context, refusal ?? '${category.label} notifications are off.');
      case _RowAction.settings:
        await _c.setTab(NotificationsTab.preferences);
    }
  }

  Future<void> _markAll() async {
    final error = await _c.markAllRead();
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
                  title: 'Notifications',
                  actions: [
                    if (_c.tab != NotificationsTab.preferences)
                      TextButton.icon(
                        key: const ValueKey('mark-all-read'),
                        onPressed: _c.unread == 0 ? null : _markAll,
                        icon: const Icon(LucideIcons.checkCheck, size: 16),
                        label: Text('Mark all read', style: ChatText.barAction.copyWith(color: null)),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          disabledForegroundColor: AppColors.slate400,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    // The preferences, one tap from the list as the gear is on LinkedIn's.
                    Semantics(
                      button: true,
                      label: 'Notification settings',
                      child: InkResponse(
                        key: const ValueKey('tab-preferences'),
                        onTap: () => _c.setTab(
                          _c.tab == NotificationsTab.preferences ? NotificationsTab.all : NotificationsTab.preferences,
                        ),
                        radius: 22,
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: Icon(
                            Icons.settings_outlined,
                            size: 24,
                            color: _c.tab == NotificationsTab.preferences ? NoteLook.blue : NoteLook.soft,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                _Header(controller: _c),
                Expanded(child: _body()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_c.tab == NotificationsTab.preferences) {
      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _c.loadPreferences,
        child: PreferencesView(controller: _c),
      );
    }
    final slivers = <Widget>[];
    if (!_c.loaded && _c.error != null) {
      slivers.add(
        SliverFillRemaining(
          hasScrollBody: false,
          child: ChatNotice(
            icon: LucideIcons.bellOff,
            title: 'Your notifications could not be loaded.',
            body: _c.error,
            action: 'Retry',
            onAction: _c.refresh,
          ),
        ),
      );
    } else if (_c.loading && _c.items.isEmpty) {
      slivers.add(const SliverFillRemaining(hasScrollBody: false, child: ChatSpinner()));
    } else if (_c.visibleItems.isEmpty) {
      final unreadTab = _c.tab == NotificationsTab.unread;
      final category = _c.categoryId == null ? null : categoryById(_c.categoryId!);
      slivers.add(
        SliverFillRemaining(
          hasScrollBody: false,
          child: ChatNotice(
            icon: unreadTab ? LucideIcons.checkCheck : LucideIcons.bell,
            title: unreadTab
                ? 'Nothing unread'
                : category != null
                ? 'Nothing under ${category.label} yet'
                : 'No notifications yet',
            body: unreadTab
                ? 'You have read everything. Older notifications are under All.'
                : category != null
                ? 'Notifications of this kind will show up here.'
                : 'Replies, applications, bookings and rewards will show up here.',
          ),
        ),
      );
    } else {
      final now = _c.clock();
      for (final (bucket, items) in _c.groups) {
        slivers.add(
          SliverToBoxAdapter(
            child: Container(
              color: NoteLook.page,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Text(bucket.label, style: NoteType.section),
            ),
          ),
        );
        slivers.add(
          SliverList.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1, thickness: 1, color: NoteLook.rule),
            itemBuilder: (context, i) => NotificationRow(
              key: ValueKey('notification-${items[i].id}'),
              notification: items[i],
              showCompany: _c.showsCompanyOf(items[i]),
              now: now,
              onTap: () => _open(items[i]),
              onMenu: () => _showMenu(items[i]),
            ),
          ),
        );
      }
      slivers.add(SliverToBoxAdapter(child: _footer()));
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _c.refresh,
      child: CustomScrollView(controller: _scroll, physics: const AlwaysScrollableScrollPhysics(), slivers: slivers),
    );
  }

  Widget _footer() {
    if (_c.loadingMore) return const Padding(padding: EdgeInsets.all(20), child: ChatSpinner(size: 20));
    if (!_c.hasMore) return const SizedBox(height: 32);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Center(
        child: TextButton(
          key: const ValueKey('show-older'),
          onPressed: _c.loadMore,
          child: Text('Show older notifications', style: ChatText.barAction),
        ),
      ),
    );
  }
}

enum _RowAction { read, turnOff, settings }

class _SheetRow extends StatelessWidget {
  const _SheetRow({super.key, required this.icon, required this.title, required this.onTap, this.hint});

  final IconData icon;
  final String title;
  final String? hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: NoteLook.soft),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: NoteType.sheetRow),
                if (hint != null) ...[const SizedBox(height: 2), Text(hint!, style: NoteType.sheetHint)],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// The filter chips, LinkedIn's: All, Unread, then one for each kind of notification that has a row.
class _Header extends StatelessWidget {
  const _Header({required this.controller});

  final NotificationsController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final onPrefs = c.tab == NotificationsTab.preferences;
    Widget chip(Key key, String label, bool on, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: on ? HomeLook.chipActive : Colors.white,
        shape: StadiumBorder(side: BorderSide(color: on ? HomeLook.chipActive : const Color(0xFF8C8C8C))),
        child: InkWell(
          key: key,
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            child: Text(label, style: on ? NoteType.chipOn : NoteType.chip),
          ),
        ),
      ),
    );

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: NoteLook.rule)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            chip(
              const ValueKey('tab-all'),
              'All',
              !onPrefs && c.tab == NotificationsTab.all && c.categoryId == null,
              () => c.setTab(NotificationsTab.all),
            ),
            chip(
              const ValueKey('tab-unread'),
              c.unread > 0 ? 'Unread (${c.unread})' : 'Unread',
              !onPrefs && c.tab == NotificationsTab.unread,
              () => c.setTab(NotificationsTab.unread),
            ),
            if (!onPrefs)
              for (final category in c.categoriesPresent)
                chip(
                  ValueKey('chip-${category.id}'),
                  chipLabelOf(category.id),
                  !onPrefs && c.categoryId == category.id,
                  () => c.selectCategory(category.id),
                ),
          ],
        ),
      ),
    );
  }
}
