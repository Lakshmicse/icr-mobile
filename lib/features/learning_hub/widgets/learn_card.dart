import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:lucide_icons_flutter/lucide_icons_600.dart';

import '../../feed/feed_models.dart' show FeedPicture;
import '../../learning/widgets/course_picture.dart';
import '../hub_styles.dart';

/// The design's photos for the grid cards, by position, when a record has no
/// cover of its own: the live screen then reads like the design. 342 × 160 px
/// (171 × 80 dp at 2x), cut from the earlier covers at the window the export
/// frames, with the share disc those carried painted out (the card draws its
/// own).
const designCardCovers = [
  'assets/images/demo/learning/hub_card_capital.jpg',
  'assets/images/demo/learning/hub_card_collaboration.jpg',
  'assets/images/demo/learning/hub_card_communication.jpg',
  'assets/images/demo/learning/hub_card_compliance.jpg',
];

/// The cover for the card at [index]: its own, else the design's for that position.
FeedPicture coverFor(FeedPicture? own, int index) =>
    own ?? FeedPicture.asset(designCardCovers[index % designCardCovers.length]);

/// One card of the design's two-column grids (Assess Your Knowledge, Mock
/// Exams, ICR Certifications, Partner Courses), as `docs/designs/learning-hub-v2.png`
/// draws it: 171 × 120 dp with 8 dp corners, a 1 dp edge and a soft lift; an
/// 80 dp photo with a 19 dp white share disc on it (21 in from the right, 10
/// down) and, for a certification, the white **ICR** tab hanging from the top
/// edge 10 in from the left; then a 40 dp pane with the title in ICR blue (two
/// lines allowed) beside a 27 dp ringed disc holding a heavy black arrow. The
/// whole card is the button.
class LearnCard extends StatelessWidget {
  const LearnCard({super.key, required this.title, required this.cover, required this.onTap, this.badge, this.onShare});

  /// The photo's shape: 171 × 80.
  static const photoAspect = 171 / 80;

  /// The card's own height on the design's 390 dp frame.
  static const height = 120.0;
  static const radius = 8.0;

  /// The pane under the photo, at least this tall.
  static const paneHeight = 40.0;

  final String title;
  final FeedPicture cover;
  final VoidCallback onTap;

  /// "ICR" on a certification card.
  final String? badge;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: const [BoxShadow(color: HubColors.cardShadow, blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
            side: const BorderSide(color: HubColors.cardEdge),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: photoAspect,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CoursePicture(picture: cover),
                      if (badge != null) Positioned(left: 10, top: 0, child: _Badge(badge!)),
                      Positioned(right: 21, top: 10, child: _ShareDisc(onTap: onShare)),
                    ],
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: paneHeight),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(11, 3, 9, 3),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(title, style: HubText.cardTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 6),
                        const _ArrowDisc(),
                      ],
                    ),
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

/// The white "ICR" tab hanging from a certification card's top edge: 68 dp wide, 31 tall, rounded where it
/// meets the photo.
class _Badge extends StatelessWidget {
  const _Badge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    // 31 dp at least: the tab grows with larger text rather than cutting "ICR" off.
    return Container(
      width: 68,
      constraints: const BoxConstraints(minHeight: 31),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(LearnCard.radius)),
      ),
      child: Center(heightFactor: 1, child: Text(text, style: HubText.badge)),
    );
  }
}

/// The 19 dp white disc with the share glyph and a 1 dp edge.
class _ShareDisc extends StatelessWidget {
  const _ShareDisc({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disc = Container(
      width: 19,
      height: 19,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: HubColors.cardEdge),
      ),
      child: const Icon(LucideIcons.share2, size: 12.5, color: HubColors.glyph),
    );
    if (onTap == null) return disc;
    return Semantics(
      button: true,
      label: 'Share',
      child: InkResponse(onTap: onTap, radius: 18, child: disc),
    );
  }
}

/// The 27 dp disc with a 1 dp ring and the heavy black arrow (12.7 dp wide, 2.3 dp stroke in the export).
class _ArrowDisc extends StatelessWidget {
  const _ArrowDisc();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 27,
      height: 27,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: HubColors.discRing),
      ),
      child: const Icon(LucideIcons600.arrowRight, size: 18, color: HubColors.arrow),
    );
  }
}

/// Two cards side by side on the design's frame: 16 dp in on both sides, 16 dp between, as tall as the taller;
/// a lone last card sits at the left.
class LearnGridRow extends StatelessWidget {
  const LearnGridRow({super.key, required this.left, this.right});

  static const padding = EdgeInsets.symmetric(horizontal: 16);
  static const gap = 16.0;

  /// Between one row and the next: the cards are 120 dp tall and 127.5 dp apart.
  static const rowGap = 7.5;

  final Widget left;
  final Widget? right;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: left),
            const SizedBox(width: gap),
            Expanded(child: right ?? const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}

/// A grey card-shaped box while a section loads, the card's own size.
class LearnCardSkeleton extends StatelessWidget {
  const LearnCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 171 / LearnCard.height,
    child: DecoratedBox(
      decoration: BoxDecoration(color: HubColors.skeleton, borderRadius: BorderRadius.circular(LearnCard.radius)),
    ),
  );
}
