import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../feed/feed_models.dart' show FeedPicture;
import '../../learning/widgets/course_picture.dart';
import '../hub_styles.dart';

/// The design's photos for the grid cards, by position, when a record has no
/// cover of its own: the live screen then reads like the design.
const designCardCovers = [
  'assets/images/demo/learning/card_capital.jpg',
  'assets/images/demo/learning/card_collaboration.jpg',
  'assets/images/demo/learning/card_communication.jpg',
  'assets/images/demo/learning/card_compliance.jpg',
];

/// The cover for the card at [index]: its own, else the design's for that position.
FeedPicture coverFor(FeedPicture? own, int index) =>
    own ?? FeedPicture.asset(designCardCovers[index % designCardCovers.length]);

/// One card of the design's two-column grids (Assess Your Knowledge, Mock
/// Exams, ICR Certifications, Partner Courses): 172.5 dp wide with 12 dp
/// corners and a soft edge, a 130.75 dp photo with a white share disc at its
/// top right (and the "ICR" badge at its top left for a certification), then
/// the title in ICR blue (Work Sans 13.8, two lines allowed) beside a round
/// black-arrow button. The whole card is the button.
class LearnCard extends StatelessWidget {
  const LearnCard({super.key, required this.title, required this.cover, required this.onTap, this.badge, this.onShare});

  static const photoAspect = 172.5 / 130.75;
  static const radius = 12.0;

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
                    if (badge != null) Positioned(left: 0, top: 0, child: _Badge(badge!)),
                    Positioned(right: 9, top: 8.5, child: _ShareDisc(onTap: onShare)),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 40.75),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12.75, 7, 9.75, 7),
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
    );
  }
}

/// The white "ICR" tab in a certification card's top-left corner: 76 × 32 dp,
/// rounded only where it meets the photo.
class _Badge extends StatelessWidget {
  const _Badge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    // 32 dp at least: the tab grows with larger text rather than cutting "ICR" off.
    return Container(
      width: 76,
      constraints: const BoxConstraints(minHeight: 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(bottomRight: Radius.circular(LearnCard.radius)),
      ),
      child: Center(heightFactor: 1, child: Text(text, style: HubText.badge)),
    );
  }
}

/// The 22 dp white disc with the share glyph.
class _ShareDisc extends StatelessWidget {
  const _ShareDisc({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disc = Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Color(0x1F000000), blurRadius: 3, offset: Offset(0, 1))],
      ),
      child: const Icon(LucideIcons.share2, size: 11, color: HubColors.glyph),
    );
    if (onTap == null) return disc;
    return Semantics(
      button: true,
      label: 'Share',
      child: InkResponse(onTap: onTap, radius: 18, child: disc),
    );
  }
}

/// The 25 dp ringed disc with the black arrow.
class _ArrowDisc extends StatelessWidget {
  const _ArrowDisc();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 25,
      height: 25,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: HubColors.discRing, width: 1.5),
      ),
      child: const Icon(LucideIcons.arrowRight, size: 13, color: HubColors.glyph),
    );
  }
}

/// Two cards side by side on the design's frame: 15.5 dp in on the left, 15.75
/// on the right, 14.25 dp between, as tall as the taller; a lone last card sits
/// at the left.
class LearnGridRow extends StatelessWidget {
  const LearnGridRow({super.key, required this.left, this.right});

  static const padding = EdgeInsets.only(left: 15.5, right: 15.75);
  static const gap = 14.25;
  static const rowGap = 11.25;

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
    aspectRatio: 172.5 / 171.5,
    child: DecoratedBox(
      decoration: BoxDecoration(color: HubColors.skeleton, borderRadius: BorderRadius.circular(LearnCard.radius)),
    ),
  );
}
