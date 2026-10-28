import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../feed/feed_models.dart' show FeedPicture;
import '../../learning/widgets/course_picture.dart';
import '../hub_styles.dart';

/// One deck in the design's "Flash Cards" rail: a 107.75 × 62 dp photo with 8
/// dp corners, darkened towards its foot, the deck's name and "45 Cards" in
/// white at the bottom left and an arrow at the bottom right.
class FlashTile extends StatelessWidget {
  const FlashTile({super.key, required this.title, required this.count, required this.cover, required this.onTap});

  static const width = 107.75;
  static const height = 62.0;
  static const gap = 6.25;

  final String title;
  final int count;
  final FeedPicture cover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cards = '$count ${count == 1 ? 'Card' : 'Cards'}';
    return Semantics(
      button: true,
      label: '$title, $cards',
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: width,
          height: height,
          child: Material(
            color: HubColors.glyph,
            child: InkWell(
              onTap: onTap,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CoursePicture(picture: cover),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [HubColors.tileScrimTop, HubColors.tileScrimBottom],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    right: 22,
                    bottom: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title, style: HubText.flashTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(cards, style: HubText.flashCount, maxLines: 1),
                      ],
                    ),
                  ),
                  const Positioned(
                    right: 6,
                    bottom: 7,
                    child: Icon(LucideIcons.arrowRight, size: 14, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
