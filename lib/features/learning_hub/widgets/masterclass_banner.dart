import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../hub_styles.dart';

/// The design's foot: "Upskill with Masterclasses — Webinars by the best in the
/// industry! — Know more ›" on a light-blue band the width of the screen, 90.75
/// dp tall (taller with larger text), with three overlapping faces at the right. Know more opens the
/// Events screen.
class MasterclassBanner extends StatelessWidget {
  const MasterclassBanner({super.key, required this.onKnowMore});

  static const height = 90.75;

  final VoidCallback onKnowMore;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Upskill with Masterclasses. Webinars by the best in the industry. Know more',
      excludeSemantics: true,
      child: Material(
        color: HubColors.bannerFill,
        child: InkWell(
          onTap: onKnowMore,
          child: Container(
            constraints: const BoxConstraints(minHeight: height),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: HubColors.bannerEdge),
                bottom: BorderSide(color: HubColors.bannerEdge),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: 19),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 12),
                      Text.rich(
                        TextSpan(
                          text: 'Upskill with ',
                          style: HubText.masterTitle,
                          children: [TextSpan(text: 'Masterclasses', style: HubText.masterAccent)],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1.5),
                      Text(
                        'Webinars by the best in the industry!',
                        style: HubText.masterBody,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text('Know more', style: HubText.masterLink),
                          const SizedBox(width: 2),
                          const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.primary),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 25, right: 14),
                  child: Image.asset(
                    'assets/images/demo/learning/masterclass_faces.png',
                    scale: 2,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, _, _) => const SizedBox(width: 92.5, height: 41),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
