import 'package:flutter/material.dart';

import '../hub_styles.dart';
import '../learning_doors.dart';

/// "Catalogue": the design's rail of four photo tiles — Assess your knowledge, Mock Exams, Flash Cards,
/// Knowledge Centre — 109 × 80 dp photos with 8 dp corners, 4 dp apart from 15.25 dp in, a caption under each
/// (Work Sans 12.7 semibold, two lines 16 dp apart, centred in a pane 41.6 dp tall). The first tile is drawn
/// lifted, as `docs/designs/learning-hub-v2.png` has it: a white card with a soft shadow round photo and caption.
/// The fourth tile runs off the edge: the rail scrolls.
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
  static const photoHeight = 80.0;
  static const gap = 4.0;

  /// Above and below the caption's two lines.
  static const panePadding = 4.4;

  /// The pane under a photo: two caption lines and their padding, 41.6 dp at the design's size.
  static double paneHeight(BuildContext context) {
    final style = HubText.tileCaption;
    final line = style.fontSize! * (style.height ?? 1.2);
    return MediaQuery.textScalerOf(context).scale(2 * line) + 2 * panePadding;
  }

  @override
  Widget build(BuildContext context) {
    // The caption's two lines grow with the phone's text size; the rail grows with them.
    final pane = paneHeight(context);
    return SizedBox(
      height: photoHeight + pane,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        // The first tile's shadow falls outside the rail's own box.
        clipBehavior: Clip.none,
        padding: const EdgeInsets.only(left: 15.25, right: 12),
        itemCount: doors.length,
        separatorBuilder: (_, _) => const SizedBox(width: gap),
        itemBuilder: (_, i) => _Tile(door: doors[i], pane: pane, lifted: i == 0, onTap: () => onOpen(doors[i])),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.door, required this.pane, required this.lifted, required this.onTap});

  final LearningDoor door;
  final double pane;
  final bool lifted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final caption = CatalogueRail.caption(door);
    final photo = SizedBox(
      width: CatalogueRail.tileWidth,
      height: CatalogueRail.photoHeight,
      child: Image.asset(
        door.image,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) => const ColoredBox(color: HubColors.skeleton),
      ),
    );
    final words = SizedBox(
      height: pane,
      child: Padding(
        // The export's words sit a dp higher than centred.
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 2),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(caption, style: HubText.tileCaption, maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
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
          child: lifted
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [BoxShadow(color: HubColors.tileShadow, blurRadius: 10, offset: Offset(0, 2))],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [photo, words]),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(borderRadius: BorderRadius.circular(8), child: photo),
                    words,
                  ],
                ),
        ),
      ),
    );
  }
}
