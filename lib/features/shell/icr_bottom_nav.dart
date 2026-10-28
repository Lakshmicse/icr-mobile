import 'package:flutter/material.dart';

import '../../core/theme/app_text.dart';
import 'nav_icons.dart';

enum AppTab { home, learning, mentorship, forums, marketplace, jobs, discover }

extension AppTabLabel on AppTab {
  String get label => switch (this) {
    AppTab.home => 'Home',
    AppTab.learning => 'Learning',
    AppTab.mentorship => 'Mentorship',
    AppTab.forums => 'Forums',
    AppTab.marketplace => 'Marketplace',
    AppTab.jobs => 'Jobs',
    AppTab.discover => 'Discover',
  };
}

/// The bottom bar, drawn like LinkedIn's on Android (owner's call, 27 Oct
/// 2026; measured from their phone's screenshot): five equal slots under a
/// hairline, a filled glyph, a 10 sp Roboto label, near-black for the open tab
/// and 60 % black for the rest, and the open tab marked by a 3 dp line along
/// the bar's top edge. Six equal slots: Home, Learning, Mentorship,
/// Marketplace, Jobs, Discover (the owner added Marketplace back on 27 Oct 2026).
///
/// Forums is still a tab of the shell ([AppTab]) but has no slot here.
///
/// The glyphs come from Flutter's own Material Icons font, never from
/// `material_symbols_icons`: a release build tree-shakes every icon font, and
/// the subset it cuts from that package's variable fonts drew `school` and
/// `group` as nothing on a phone while the debug build drew them (27 Oct 2026).
class IcrBottomNav extends StatelessWidget {
  const IcrBottomNav({super.key, required this.current, required this.onSelect});

  /// The tabs the bar shows, left to right.
  static const tabs = [
    AppTab.home,
    AppTab.learning,
    AppTab.mentorship,
    AppTab.marketplace,
    AppTab.jobs,
    AppTab.discover,
  ];

  /// The hairline included, without the bottom inset the bar adds.
  static const height = 52.0;

  /// LinkedIn's text colours on white: 90% black for the open tab, 60% for the rest.
  static const active = Color(0xE6000000);
  static const inactive = Color(0x99000000);
  static const _rule = Color(0xFFD5D5D5);

  final AppTab current;
  final ValueChanged<AppTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _rule, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: height,
          child: Row(
            children: [
              for (final tab in tabs)
                Expanded(
                  child: _NavItem(tab: tab, selected: tab == current, onTap: () => onSelect(tab)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.tab, required this.selected, required this.onTap});

  final AppTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? IcrBottomNav.active : IcrBottomNav.inactive;
    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 32,
        containedInkWell: false,
        highlightShape: BoxShape.circle,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            // The open tab's line, over the hairline, a little short of the slot's edges.
            if (selected)
              const Positioned(
                top: 0,
                left: 3,
                right: 3,
                height: 3,
                child: DecoratedBox(decoration: BoxDecoration(color: IcrBottomNav.active)),
              ),
            Positioned(
              top: 7,
              child: SizedBox(width: 24, height: 24, child: Center(child: _icon(color))),
            ),
            // A slot is a sixth of the screen (60 dp on a 360 dp phone): "Marketplace" shrinks to fit it.
            Positioned(
              top: 33,
              left: 1,
              right: 1,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(tab.label, maxLines: 1, style: AppText.navLabel.copyWith(color: color)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _icon(Color color) => switch (tab) {
    AppTab.home => HouseIcon(color: color),
    AppTab.learning => Icon(Icons.school_rounded, size: 24, color: color),
    // The people glyph has more air in its box than the others; 27 puts its ink
    // at the 20 dp of the house and the briefcase.
    AppTab.mentorship => Icon(Icons.group_rounded, size: 27, color: color),
    AppTab.forums => Icon(Icons.forum_rounded, size: 24, color: color),
    AppTab.marketplace => Icon(Icons.storefront_rounded, size: 24, color: color),
    AppTab.jobs => BriefcaseIcon(color: color),
    AppTab.discover => Icon(Icons.grid_view_rounded, size: 24, color: color),
  };
}
