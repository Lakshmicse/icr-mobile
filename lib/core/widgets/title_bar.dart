import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../features/notifications/unread_counts.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'workspace_embed.dart';

/// The bar at the top of a section screen, as the Jobs design: a back arrow
/// (or whatever `leading` is), the title, something in the middle if given
/// (Find Mentors puts the search there), and the bell. 56 dp, with the same
/// shadow as the Home header. In a workspace's tab ([WorkspaceEmbed]) it is the page's heading: title and middle.
class TitleBar extends StatelessWidget {
  const TitleBar({
    super.key,
    this.title,
    this.onBack,
    this.leading,
    this.middle,
    this.actions = const [],
    this.unread = 0,
    required this.onBell,
  });

  static const height = 56.0;

  /// The room a screen leaves above its body for this bar: [height], or nothing in a workspace's tab when the bar
  /// carries no [middle] and so draws nothing there.
  static double reserved(BuildContext context, {bool middle = false}) =>
      !middle && WorkspaceEmbed.of(context) ? 0 : height;

  final String? title;
  final VoidCallback? onBack;

  /// Replaces the back arrow.
  final Widget? leading;
  final Widget? middle;

  /// Drawn left of the bell (a record's pencil for the person who may edit it; owner, 12 Nov 2026).
  final List<Widget> actions;
  final int unread;
  final VoidCallback onBell;

  @override
  Widget build(BuildContext context) {
    // Inside a workspace's tab the workspace's bar has the back arrow and the bell; this row keeps the page's title
    // as its heading and a search in the middle, in the same 56 dp the screens leave for it.
    if (WorkspaceEmbed.of(context)) {
      // The tab names the page, so its title is not drawn again (owner, 9 Nov 2026: "wherever it is remove it");
      // the row keeps only what else it carried (a search), and goes when that is nothing.
      if (middle == null) return const SizedBox.shrink();
      return Container(
        height: height,
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [Expanded(child: middle!)]),
      );
    }
    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Row(
        children: [
          if (leading != null)
            leading!
          else ...[
            const SizedBox(width: 17.75),
            Semantics(
              button: true,
              label: 'Back',
              child: InkResponse(
                onTap: onBack ?? () => Navigator.maybePop(context),
                radius: 24,
                child: const SizedBox(
                  width: 24,
                  height: 56,
                  child: Icon(Symbols.arrow_back, size: 24, color: AppColors.onSurfaceVariant),
                ),
              ),
            ),
          ],
          if (title != null) ...[const SizedBox(width: 18.75), Text(title!, style: AppText.barTitle)],
          if (middle != null) ...[const SizedBox(width: 12), Expanded(child: middle!)] else const Spacer(),
          ...actions,
          BellButton(unread: unread, onTap: onBell),
          const SizedBox(width: 13),
        ],
      ),
    );
  }
}

/// The pencil left of the bell: "edit this" (or "manage these", for the staff who run a section), shown to the
/// person who may.
class BarEditButton extends StatelessWidget {
  const BarEditButton({super.key, required this.onTap, this.label = 'Edit'});

  final VoidCallback onTap;

  /// What a screen reader calls it.
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkResponse(
        key: const ValueKey('bar-edit'),
        onTap: onTap,
        radius: 24,
        child: const SizedBox(
          width: 40,
          height: 56,
          child: Icon(LucideIcons.pencil, size: 19, color: AppColors.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// The bell with its red dot, 36 wide.
class BellButton extends StatelessWidget {
  const BellButton({super.key, required this.unread, required this.onTap});

  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => LiveUnread(fallback: unread, builder: _bell);

  Widget _bell(BuildContext context, int unread) {
    return Semantics(
      button: true,
      label: unread > 0 ? 'Notifications, $unread unread' : 'Notifications',
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: SizedBox(
          width: 36,
          height: 56,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(LucideIcons.bell, size: 24, color: AppColors.onSurfaceVariant),
              if (unread > 0)
                Positioned(
                  left: 26,
                  top: 14.25,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
