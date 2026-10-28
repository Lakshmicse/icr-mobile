import 'package:flutter/material.dart';

import '../hub_styles.dart';
import '../learning_doors.dart';

/// "Catalogue": the design's rail of four photo tiles — Assess your knowledge,
/// Mock Exams, Flash Cards, Knowledge Centre — 109 × 80.75 dp photos with 8 dp
/// corners, 4 dp apart from 15.25 dp in, a two-line caption under each (Work
/// Sans 11.9 bold). The fourth tile runs off the edge: the rail scrolls.
class CatalogueRail extends StatelessWidget {
  const CatalogueRail({super.key, required this.onOpen});

  final ValueChanged<LearningDoor> onOpen;

  static const doors = [
    LearningDoor.assessment,
    LearningDoor.mockTests,
    LearningDoor.flashCards,
    LearningDoor.knowledgeCenter,
  ];

  /// The design's words for each tile.
  static String caption(LearningDoor door) => switch (door) {
    LearningDoor.assessment => 'Assess your knowledge',
    LearningDoor.mockTests => 'Mock Exams',
    LearningDoor.flashCards => 'Flash Cards',
    LearningDoor.knowledgeCenter => 'Knowledge Centre',
    _ => door.title,
  };

  static const tileWidth = 109.0;
  static const photoHeight = 80.75;

  /// The photo, 3 dp, and two caption lines (16 dp each at the app's 12 sp caption).
  static const height = photoHeight + 3 + 32;

  @override
  Widget build(BuildContext context) {
    // The caption's two lines grow with the phone's text size; the rail grows with them.
    final captionLines = MediaQuery.textScalerOf(context).scale(32);
    return SizedBox(
      height: photoHeight + 3 + captionLines,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 15.25, right: 12),
        itemCount: doors.length,
        separatorBuilder: (_, _) => const SizedBox(width: 4),
        itemBuilder: (_, i) => _Tile(door: doors[i], onTap: () => onOpen(doors[i])),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.door, required this.onTap});

  final LearningDoor door;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final caption = CatalogueRail.caption(door);
    return Semantics(
      button: true,
      label: caption,
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('catalogue-${door.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: CatalogueRail.tileWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: CatalogueRail.tileWidth,
                  height: CatalogueRail.photoHeight,
                  child: Image.asset(
                    door.image,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, _, _) => const ColoredBox(color: HubColors.skeleton),
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(caption, style: HubText.tileCaption, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
