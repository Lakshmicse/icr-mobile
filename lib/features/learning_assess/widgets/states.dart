import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../assess_styles.dart';

/// An empty, failed or not-found page: a glyph, a title, a line, and one button.
class AssessNotice extends StatelessWidget {
  const AssessNotice({
    super.key,
    required this.title,
    required this.body,
    this.action,
    this.onAction,
    this.icon = LucideIcons.clipboardCheck,
  });

  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: AppColors.outline),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: AssessText.noticeTitle),
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center, style: AssessText.noticeBody),
          if (action != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.outlineVariant),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(action!, style: AssessText.noteLink),
            ),
          ],
        ],
      ),
    );
  }
}

/// A grey block that stands for a card while its list loads.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.height, this.width, this.radius = 12});

  final double? height;
  final double? width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(color: AppColors.slate100, borderRadius: BorderRadius.circular(radius)),
    );
  }
}

/// The grid's loading state: two columns of card-shaped blocks.
class GridSkeleton extends StatelessWidget {
  const GridSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Column(
        children: [
          for (var row = 0; row < 3; row++) ...[
            if (row > 0) const SizedBox(height: 10),
            const Row(
              children: [
                Expanded(child: SkeletonBox(height: 214)),
                SizedBox(width: 10),
                Expanded(child: SkeletonBox(height: 214)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
