import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../hub_styles.dart';

/// The design's foot: "Upskill with Masterclasses — Webinars by the best in the industry! — Know more ›" on a
/// light-blue band the width of the screen, 92 dp tall (taller with larger text), with three overlapping faces
/// at the right (`docs/designs/learning-hub-v2.png`). Know more opens the Events screen.
class MasterclassBanner extends StatelessWidget {
  const MasterclassBanner({super.key, required this.onKnowMore});

  static const height = 92.0;

  final VoidCallback onKnowMore;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Upskill with Masterclasses. Webinars by the best in the industry. Know more',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [HubColors.bannerFill, HubColors.bannerFillEnd]),
            border: Border(
              top: BorderSide(color: HubColors.bannerEdge),
              bottom: BorderSide(color: HubColors.bannerEdge),
            ),
          ),
          child: InkWell(
            onTap: onKnowMore,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: height - 2),
              // As tall as the words need (92 dp at least), so the faces can centre on the band.
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(width: 18),
                    Expanded(
                      child: Padding(
                        // The title's cap line sits 18 dp under the band's top edge; the foot takes what is left.
                        padding: const EdgeInsets.only(top: 13, bottom: 13),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text.rich(
                              TextSpan(
                                text: 'Upskill with ',
                                style: HubText.masterTitle,
                                children: [TextSpan(text: 'Masterclasses', style: HubText.masterAccent)],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Webinars by the best in the industry!',
                              style: HubText.masterBody,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 1.4),
                            Row(
                              children: [
                                Text('Know more', style: HubText.masterLink),
                                const SizedBox(width: 2),
                                const Icon(LucideIcons.chevronRight, size: 16, color: HubColors.bannerLink),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 15.5),
                        child: Image.asset(
                          'assets/images/demo/learning/masterclass_faces.png',
                          width: 92.5,
                          filterQuality: FilterQuality.high,
                          errorBuilder: (_, _, _) => const SizedBox(width: 92.5, height: 37),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
