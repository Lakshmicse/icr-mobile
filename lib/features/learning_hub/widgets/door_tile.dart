import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../learning/learning_styles.dart';
import '../../learning/widgets/course_card.dart';
import '../hub_styles.dart';
import '../learning_doors.dart';

/// One door of the Learning Center as an artwork tile, on the frame of the
/// Learning grid's course card (10 dp corners, a 1 dp `#EDEDED` edge, the cover
/// on top at 16:10): the website's artwork for the door with its glyph over the
/// top left, then the title, one line of what the door is, and its call to
/// action. The whole tile is the button.
class DoorTile extends StatelessWidget {
  const DoorTile({super.key, required this.door, required this.onTap});

  final LearningDoor door;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${door.title}. ${door.blurb}',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: HubColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('door-${door.name}'),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: CourseCard.coverAspect,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      door.image,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (_, _, _) => const ColoredBox(color: LearningColors.coverPlate),
                    ),
                    Positioned(left: 8, top: 9.5, child: _GlyphChip(door.icon)),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(11.5, 8, 11.5, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(door.title, style: HubText.doorTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Text(door.blurb, style: HubText.doorBlurb, maxLines: 2, overflow: TextOverflow.ellipsis),
                      const Spacer(),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(door.cta, style: HubText.doorCta, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 4),
                          const Icon(LucideIcons.arrowRight, size: 14, color: AppColors.primary),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The website's frosted square with the door's glyph, over the artwork.
class _GlyphChip extends StatelessWidget {
  const _GlyphChip(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: LearningColors.pillCardFill,
            border: Border.all(color: LearningColors.pillBorder),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: Colors.white),
        ),
      ),
    );
  }
}
