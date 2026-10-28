import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// The bar at the top of a section screen, as the Jobs design: a back arrow
/// (or whatever `leading` is), the title, something in the middle if given
/// (Find Mentors puts the search there), and the bell. 56 dp, with the same
/// shadow as the Home header.
class TitleBar extends StatelessWidget {
  const TitleBar({
    super.key,
    this.title,
    this.onBack,
    this.leading,
    this.middle,
    this.unread = 0,
    required this.onBell,
  });

  static const height = 56.0;

  final String? title;
  final VoidCallback? onBack;

  /// Replaces the back arrow.
  final Widget? leading;
  final Widget? middle;
  final int unread;
  final VoidCallback onBell;

  @override
  Widget build(BuildContext context) {
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
          BellButton(unread: unread, onTap: onBell),
          const SizedBox(width: 13),
        ],
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
  Widget build(BuildContext context) {
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
