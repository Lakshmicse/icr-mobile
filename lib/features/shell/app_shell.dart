import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart';
import '../discover/discover_sheet.dart';
import 'icr_bottom_nav.dart';
import 'nav_icons.dart';
import 'scroll_hiding_bar.dart';
import 'upcoming_tab.dart';

/// The signed-in app: one screen per tab, kept alive while you switch, with
/// the bottom bar under them. Discover is not a screen but a sheet over the
/// open tab. Back closes the sheet, then returns to Home.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.home,
    this.drawer,
    this.learning,
    this.mentorship,
    this.forums,
    this.marketplace,
    this.jobs,
    this.doors = const {},
  });

  final Widget home;

  /// The tabs with screens of their own; a "coming to the app" screen when
  /// one is not given.
  final Widget? learning;
  final Widget? mentorship;
  final Widget? forums;
  final Widget? marketplace;
  final Widget? jobs;

  /// The profile menu, opened from the Home header's photo.
  final Widget? drawer;

  /// Screens the Discover sheet's doors open in the app, keyed by the door's
  /// website path (`/events`). A door with no entry opens the website.
  final Map<String, WidgetBuilder> doors;

  /// The shell a context belongs to: the one it is inside, or the one a screen
  /// pushed with [push] sits over.
  static _AppShellState? _of(BuildContext context) =>
      context.findAncestorStateOfType<_AppShellState>() ??
      context.getInheritedWidgetOfExactType<_ShellScope>()?.shell ??
      _live;

  /// The shell on screen. A route that is not a child of the shell and was not pushed with [push] (the
  /// notifications list, a sheet) still reaches its tabs through it: "open the Jobs tab" from anywhere.
  static _AppShellState? _live;

  /// Pushes a screen over the shell. A screen pushed any other way cannot reach
  /// the shell's menu or tabs, because a route sits above it.
  static Future<T?> push<T>(BuildContext context, WidgetBuilder builder) =>
      Navigator.of(context).push(_route<T>(_of(context), builder));

  static MaterialPageRoute<T> _route<T>(_AppShellState? shell, WidgetBuilder builder) => MaterialPageRoute<T>(
    builder: (_) => shell == null
        ? Builder(builder: builder)
        : _ShellScope(
            shell: shell,
            child: Builder(builder: builder),
          ),
  );

  /// Leaves every screen pushed over the shell, so the shell shows again.
  static void _backToShell(BuildContext context) => Navigator.of(context).popUntil((route) => route.isFirst);

  /// Opens the drawer from anywhere inside the shell, or from a screen pushed
  /// over it, which leaves that screen first.
  static void openDrawer(BuildContext context) {
    final shell = _of(context);
    if (shell == null) return;
    if (context.findAncestorStateOfType<_AppShellState>() == null) _backToShell(context);
    shell._scaffold.currentState?.openDrawer();
  }

  /// Opens a tab from a screen pushed over the shell, the way its bottom bar
  /// does: the screen is left and the tab shows.
  static void goToTab(BuildContext context, AppTab tab) {
    final shell = _of(context);
    if (shell == null) return;
    _backToShell(context);
    shell._select(tab);
  }

  /// Goes back to the Home tab from anywhere inside the shell.
  static void selectHome(BuildContext context) {
    context.findAncestorStateOfType<_AppShellState>()?._select(AppTab.home);
  }

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with SingleTickerProviderStateMixin {
  final _scaffold = GlobalKey<ScaffoldState>();
  AppTab _tab = AppTab.home;

  /// The tabs opened so far. A tab is built the first time it is shown, so
  /// opening the app loads Home alone (every tab starts its own requests, and
  /// the API rate-limits a device); after that it is kept, with its place.
  final _opened = <AppTab>{AppTab.home};

  late final AnimationController _discover = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    reverseDuration: const Duration(milliseconds: 200),
  )..addStatusListener((_) => setState(() {}));

  static const _tint = AppColors.primary;

  late final List<Widget> _tabs = [
    widget.home,
    widget.learning ??
        const UpcomingTab(
          title: 'Learning',
          icon: Icon(Symbols.school_rounded, fill: 1, size: 34, color: _tint),
          summary: 'Courses, mock exams, certificates and the resource library are on the website for now.',
          sitePath: '/learning',
        ),
    widget.mentorship ??
        const UpcomingTab(
          title: 'Mentorship',
          icon: Icon(Symbols.group_rounded, fill: 1, size: 34, color: _tint),
          summary: 'Find a mentor, book a session and follow a programme on the website for now.',
          sitePath: '/mentorship',
        ),
    widget.forums ??
        const UpcomingTab(
          title: 'Forums',
          icon: Icon(Symbols.forum_rounded, fill: 1, size: 32, color: _tint),
          summary: 'Browse every topic and start a discussion on the website. Your Home feed already shows the latest.',
          sitePath: '/community',
        ),
    widget.marketplace ??
        const UpcomingTab(
          title: 'Marketplace',
          icon: Icon(Symbols.storefront_rounded, fill: 1, size: 32, color: _tint),
          summary: 'Supplier Mart, products, services and requirements are on the website for now.',
          sitePath: '/vendors',
        ),
    widget.jobs ??
        UpcomingTab(
          title: 'Jobs',
          icon: Transform.scale(scale: 1.45, child: const BriefcaseIcon(color: _tint)),
          summary: 'Search roles, track your applications and get job alerts on the website for now.',
          sitePath: '/jobs',
        ),
  ];

  bool get _discoverOpen => _discover.isForwardOrCompleted;

  /// The profile menu. Back has to close it before anything else: left to the
  /// scaffold, a Back on Home exited the app with the menu open, and a Back on
  /// another tab went Home with the menu still open.
  bool _drawerOpen = false;

  /// The bottom bar leaves while the open tab scrolls down and returns on the way up.
  final _bar = BarVisibility();

  @override
  void initState() {
    super.initState();
    AppShell._live = this;
  }

  @override
  void dispose() {
    if (AppShell._live == this) AppShell._live = null;
    _bar.dispose();
    _discover.dispose();
    super.dispose();
  }

  void _select(AppTab tab) {
    // Choosing a tab (or Discover) always brings the bar back.
    _bar.show();
    if (tab == AppTab.discover) {
      _discoverOpen ? _discover.reverse() : _discover.forward();
      return;
    }
    _discover.reverse();
    setState(() {
      _tab = tab;
      _opened.add(tab);
    });
  }

  void _openDoor(DiscoverDoor door) {
    _discover.reverse();
    final screen = widget.doors[door.sitePath];
    if (screen == null) {
      openSitePage(context, door.sitePath);
      return;
    }
    Navigator.of(context).push(AppShell._route<void>(this, screen));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _tab == AppTab.home && !_discoverOpen && !_drawerOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_drawerOpen) {
          _scaffold.currentState?.closeDrawer();
        } else if (_discoverOpen) {
          _discover.reverse();
        } else {
          setState(() => _tab = AppTab.home);
        }
      },
      child: Scaffold(
        key: _scaffold,
        backgroundColor: Colors.white,
        drawer: widget.drawer,
        onDrawerChanged: (open) => setState(() => _drawerOpen = open),
        drawerScrimColor: AppColors.scrim,
        body: NotificationListener<ScrollNotification>(
          onNotification: (n) => _discoverOpen ? false : _bar.onScroll(n),
          child: Stack(
            fit: StackFit.expand,
            children: [
              IndexedStack(
                index: _tab.index,
                children: [
                  for (final (i, tab) in _tabs.indexed)
                    _opened.contains(AppTab.values[i]) ? tab : const SizedBox.shrink(),
                ],
              ),
              DiscoverLayer(controller: _discover, onClose: _discover.reverse, onOpen: _openDoor),
            ],
          ),
        ),
        bottomNavigationBar: HidingBar(
          controller: _bar,
          barHeight: IcrBottomNav.height,
          child: IcrBottomNav(current: _tab, onSelect: _select),
        ),
      ),
    );
  }
}

/// Lets a screen pushed over the shell reach the shell's menu.
class _ShellScope extends InheritedWidget {
  const _ShellScope({required this.shell, required super.child});

  final _AppShellState shell;

  @override
  bool updateShouldNotify(_ShellScope oldWidget) => shell != oldWidget.shell;
}
