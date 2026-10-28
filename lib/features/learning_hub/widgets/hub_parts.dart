import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../learning/widgets/course_card.dart';
import '../hub_styles.dart';

/// An empty or failed list: a glyph, a title, a line and, when something can be
/// done, the one button that does it. The pattern the other Learning screens use.
class HubNotice extends StatelessWidget {
  const HubNotice({
    super.key,
    required this.title,
    required this.body,
    this.action,
    this.onAction,
    this.icon = LucideIcons.graduationCap,
    this.padding = const EdgeInsets.fromLTRB(32, 40, 32, 40),
  });

  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;
  final IconData icon;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: AppColors.outline),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: AppText.postTitle.copyWith(fontSize: 16, height: 1.3)),
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center, style: AppText.small),
          if (action != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                minimumSize: const Size(48, 48),
                side: const BorderSide(color: AppColors.outlineVariant),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(action!, style: AppText.link),
            ),
          ],
        ],
      ),
    );
  }
}

/// A rail's heading with its "View All": the title and an action whose tap target is 48 dp tall
/// (the shared `SectionHeading` is a 20 dp strip, a small target for a thumb), on the same margins and type.
class HubHeading extends StatelessWidget {
  const HubHeading({super.key, required this.title, this.action, this.onAction});

  static const height = 48.0;

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        children: [
          const SizedBox(width: 10),
          Expanded(
            child: Text(title, style: AppText.sectionTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (action != null)
            Semantics(
              button: true,
              label: '$action, $title',
              excludeSemantics: true,
              onTap: onAction,
              child: InkWell(
                onTap: onAction,
                child: SizedBox(
                  height: height,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Center(child: Text(action!, style: AppText.sectionAction)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A grey box that stands where a card or a number is still loading.
class HubSkeleton extends StatelessWidget {
  const HubSkeleton({super.key, this.width, this.height, this.radius = 10});

  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: HubColors.skeleton, borderRadius: BorderRadius.circular(radius)),
    );
  }
}

/// Two cards side by side on the frame of the Events agenda and the Learning
/// grid (9 dp in on the left, 9.5 on the right, 3 dp between), as tall as the
/// taller; a lone last card sits at the left, half width.
class TwoUpRow extends StatelessWidget {
  const TwoUpRow({super.key, required this.left, this.right});

  final Widget left;
  final Widget? right;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: CourseGridRow.padding,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: left),
            const SizedBox(width: CourseGridRow.gap),
            Expanded(child: right ?? const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}
