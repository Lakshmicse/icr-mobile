import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../council_models.dart';
import '../councils_styles.dart';

/// A small stadium pill with a word in it, as the design's status pills.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.fill,
    required this.style,
    this.dot,
    this.icon,
    this.height = 17,
    this.padding = const EdgeInsets.symmetric(horizontal: 9),
    this.border,
    this.radius,
  });

  final String label;
  final Color fill;
  final TextStyle style;

  /// A 7 dp dot before the word, in this colour.
  final Color? dot;
  final IconData? icon;
  final double height;
  final EdgeInsets padding;
  final Color? border;

  /// A rounded rectangle of this radius instead of a stadium.
  final double? radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(radius ?? height / 2),
        border: border == null ? null : Border.all(color: border!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot != null) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
          ],
          if (icon != null) ...[Icon(icon, size: 10, color: style.color), const SizedBox(width: 4)],
          // Flexible: in a tight row the word gives way (an ellipsis) instead of overflowing.
          Flexible(
            child: Text(label, style: style, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

/// The glyph a council's cover tile carries, chosen like the website's
/// industry icon. The design draws them as Material symbols, bold, most of them
/// filled (the leaf, the chip and the hand holding a house are outlined).
IconData industryIcon(CouncilIndustry industry) => switch (industry) {
  CouncilIndustry.sustainability => Symbols.eco,
  CouncilIndustry.legal => Symbols.gavel,
  CouncilIndustry.construction => Symbols.construction,
  CouncilIndustry.finance => Symbols.account_balance,
  CouncilIndustry.tech => Symbols.memory,
  CouncilIndustry.health => Symbols.monitor_heart,
  CouncilIndustry.education => Symbols.school,
  CouncilIndustry.logistics => Symbols.local_shipping,
  CouncilIndustry.realEstate => Symbols.real_estate_agent,
  CouncilIndustry.hospitality => Symbols.storefront,
  CouncilIndustry.government => Symbols.location_city,
  CouncilIndustry.manufacturing => Symbols.factory,
  CouncilIndustry.security => Symbols.shield,
  CouncilIndustry.people => Symbols.apartment,
  CouncilIndustry.general => Symbols.hub,
};

/// A council's industry glyph at the weight the design draws it. [size] is the
/// icon's box: its ink is about three quarters of that (the design's tile glyph
/// is 20 dp across, so 26 here).
class IndustryGlyph extends StatelessWidget {
  const IndustryGlyph(this.industry, {super.key, this.size = 26, this.color = Colors.white});

  final CouncilIndustry industry;
  final double size;
  final Color color;

  static const _outlined = {CouncilIndustry.sustainability, CouncilIndustry.tech, CouncilIndustry.realEstate};

  @override
  Widget build(BuildContext context) {
    return Icon(
      industryIcon(industry),
      size: size,
      fill: _outlined.contains(industry) ? 0 : 1,
      weight: 500,
      color: color,
    );
  }
}

/// The website's deterministic banner hue for a council without a cover
/// (djb2 over the slug).
int _hashHue(String seed) {
  var h = 5381;
  for (final c in seed.codeUnits) {
    h = ((h * 33) ^ c) & 0xFFFFFFFF;
  }
  return h % 360;
}

/// A council's cover: its photo under the design's dark scrim, or the
/// website's two-tone gradient with the industry glyph when it has none.
class CouncilCover extends StatelessWidget {
  const CouncilCover({super.key, required this.council, this.height = 80});

  final Council council;
  final double height;

  @override
  Widget build(BuildContext context) {
    final cover = council.cover;
    Widget art;
    if (cover?.asset != null) {
      art = Image.asset(cover!.asset!, fit: BoxFit.cover, filterQuality: FilterQuality.medium);
    } else if (cover?.url != null) {
      art = CachedNetworkImage(imageUrl: cover!.url!, fit: BoxFit.cover, errorWidget: (_, _, _) => _gradient());
    } else {
      art = _gradient();
    }
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          art,
          // The bundled demo covers are cut from the design and already carry
          // its darkening; a second scrim would double it.
          if (cover?.asset == null)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [CouncilsColors.coverScrimTop, CouncilsColors.coverScrimBottom],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _gradient() {
    final h = _hashHue(council.slug).toDouble();
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HSLColor.fromAHSL(1, h, 0.55, 0.32).toColor(),
            HSLColor.fromAHSL(1, (h + 40) % 360, 0.6, 0.24).toColor(),
          ],
        ),
      ),
      child: Center(child: IndustryGlyph(council.industry, size: 48, color: Colors.white.withValues(alpha: 0.35))),
    );
  }
}
