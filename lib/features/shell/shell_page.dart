import 'package:flutter/material.dart';

import 'app_shell.dart';
import 'icr_bottom_nav.dart';
import 'scroll_hiding_bar.dart';

/// A screen pushed over the shell that its design draws with the bottom bar:
/// the bar sits under it with [tab] lit, and any tab leaves the screen for that
/// tab. The bar leaves while the screen scrolls down and returns on the way up,
/// as the shell's does. A screen the design draws with a back arrow instead
/// needs none of this.
class ShellPage extends StatefulWidget {
  const ShellPage({super.key, required this.tab, required this.child});

  final AppTab tab;
  final Widget child;

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  final _bar = BarVisibility();

  @override
  void dispose() {
    _bar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: NotificationListener<ScrollNotification>(onNotification: _bar.onScroll, child: widget.child),
      bottomNavigationBar: HidingBar(
        controller: _bar,
        barHeight: IcrBottomNav.height,
        child: IcrBottomNav(current: widget.tab, onSelect: (next) => AppShell.goToTab(context, next)),
      ),
    );
  }
}
