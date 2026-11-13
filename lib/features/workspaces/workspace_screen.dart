import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/util/links.dart';
import '../../core/widgets/workspace_embed.dart';
import 'workspaces.dart';

/// Builds the app's own screen for a workspace page, or null when the app has none (the website's page opens then).
typedef WorkspacePageBuilder = Widget? Function(BuildContext context, WorkspaceItem item);

/// A workspace option from the profile menu (owner, 4 Nov 2026): the option's name in the bar (Mentorship, My
/// career…), its pages as a row of tabs under it, and the page chosen below — the website's menu under that heading,
/// as tabs. Each page is the app's own screen for it, built the first time its tab is opened and kept while the
/// option is open; its own top bar steps aside ([WorkspaceEmbed]).
class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({super.key, required this.section, required this.pageFor, this.initialIndex = 0});

  final WorkspaceSection section;
  final WorkspacePageBuilder pageFor;
  final int initialIndex;

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  late int _index = widget.initialIndex.clamp(0, widget.section.items.length - 1);

  /// Pages built so far, by tab; a tab not yet opened has none.
  final Map<int, Widget> _pages = {};
  late final List<GlobalKey> _tabKeys = [for (final _ in widget.section.items) GlobalKey()];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(_index, animate: false));
  }

  void _select(int i) {
    if (i == _index) return;
    setState(() => _index = i);
    _reveal(i);
  }

  /// Scrolls the strip so the chosen tab is in view.
  void _reveal(int i, {bool animate = true}) {
    final tab = _tabKeys[i].currentContext;
    if (tab == null) return;
    Scrollable.ensureVisible(
      tab,
      alignment: 0.5,
      duration: animate ? const Duration(milliseconds: 250) : Duration.zero,
    );
  }

  Widget _page(int i) {
    final item = widget.section.items[i];
    final page = widget.pageFor(context, item) ?? _WebsitePage(item: item);
    return WorkspaceEmbed(
      openTab: _openTab,
      child: MediaQuery.removePadding(context: context, removeTop: true, child: page),
    );
  }

  /// A page asked for another page of this workspace (`/mentorship/mentors`): its tab, when the workspace has one.
  bool _openTab(String path) {
    final want = Uri.parse(path);
    final i = widget.section.items.indexWhere((item) {
      final have = Uri.parse(item.path);
      return have.path == want.path && have.queryParameters['tab'] == want.queryParameters['tab'];
    });
    if (i < 0 || !mounted) return false;
    _select(i);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    _pages.putIfAbsent(_index, () => _page(_index));
    final items = widget.section.items;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            _Bar(title: widget.section.title),
            // One page needs no row of tabs: the bar names it.
            if (items.length > 1) _Tabs(items: items, index: _index, keys: _tabKeys, onSelect: _select),
            Expanded(
              child: IndexedStack(
                index: _index,
                children: [for (var i = 0; i < items.length; i++) _pages[i] ?? const SizedBox.shrink()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The workspace's bar: ICR blue under the status bar, the back arrow and the workspace's name.
class _Bar extends StatelessWidget {
  const _Bar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.only(top: top),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF1D63A3), Color(0xFF2F7FCB)],
        ),
      ),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            const SizedBox(width: 4),
            IconButton(
              key: const ValueKey('workspace-back'),
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                title,
                style: AppText.plexSans(22, FontWeight.w600, Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The option's pages as tabs: one line of names that scrolls sideways when they do not fit, the open one in ICR
/// blue and underlined.
class _Tabs extends StatelessWidget {
  const _Tabs({required this.items, required this.index, required this.keys, required this.onSelect});

  final List<WorkspaceItem> items;
  final int index;
  final List<GlobalKey> keys;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final selected = i == index;
          return Semantics(
            selected: selected,
            button: true,
            child: InkWell(
              key: keys[i],
              onTap: () => onSelect(i),
              child: Container(
                key: ValueKey('workspace-tab-$i'),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: selected ? AppColors.primary : Colors.transparent, width: 3),
                  ),
                ),
                child: Text(
                  items[i].label,
                  maxLines: 1,
                  softWrap: false,
                  style: AppText.plexSans(
                    14,
                    selected ? FontWeight.w600 : FontWeight.w500,
                    selected ? AppColors.primary : AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A page the app has no screen of its own for: it opens the website's page (in the app's web view).
class _WebsitePage extends StatelessWidget {
  const _WebsitePage({required this.item});

  final WorkspaceItem item;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item.icon, size: 40, color: AppColors.primary),
            const SizedBox(height: 12),
            Text(item.label, style: AppText.plexSans(18, FontWeight.w600, AppColors.onSurface)),
            const SizedBox(height: 16),
            FilledButton(
              key: ValueKey('workspace-open-${item.path}'),
              onPressed: () => openSitePage(context, item.path),
              child: Text('Open ${item.label}'),
            ),
          ],
        ),
      ),
    );
  }
}
