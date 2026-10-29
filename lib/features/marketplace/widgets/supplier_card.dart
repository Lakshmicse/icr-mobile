import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../marketplace_models.dart';
import '../marketplace_styles.dart';

/// The width of a card on the phone design (a 390 dp frame holds two, 12 dp
/// from each edge with 6.5 dp between). A narrower cell (three columns on a
/// phone, a small phone) draws the card at the same shape, smaller.
const supplierCardBaseWidth = 179.75;

/// The height of a card at [supplierCardBaseWidth].
const supplierCardBaseHeight = 160.0;

/// A supplier on the Marketplace grid, as the design draws it: the logo and
/// name over a rule, the rating and its reviews, the title and two lines about
/// the supplier. Every card is the same height, so a row is always even.
///
/// A live supplier has a logo (drawn at half its pixel size, like every logo
/// the API serves) and a name set beside it; the design's own sample content
/// carries the logo and name as one picture ([Supplier.lockupAsset]).
class SupplierCard extends StatelessWidget {
  const SupplierCard({super.key, required this.supplier, required this.onTap, this.scale = 1, this.title});

  final Supplier supplier;
  final VoidCallback onTap;

  /// 1 at the phone design's card width; less when the cell is narrower.
  final double scale;

  /// Replaces the supplier's headline as the card's title (its main category,
  /// when the headline is missing).
  final String? title;

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12 * k),
      side: BorderSide(color: MartColors.cardBorder, width: 1.5 * k),
    );
    final name = supplier.name;
    final heading = supplier.headline ?? title ?? '';
    final body = supplier.blurb ?? '';
    return Semantics(
      button: true,
      label:
          '$name, rated ${supplier.ratingLabel} from ${supplier.ratingCount} '
          '${supplier.ratingCount == 1 ? 'review' : 'reviews'}. $heading',
      child: ExcludeSemantics(
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.2,
          child: Material(
            color: Colors.white,
            shape: shape,
            child: InkWell(
              customBorder: shape,
              onTap: onTap,
              child: SizedBox(
                height: supplierCardBaseHeight * k,
                child: Padding(
                  // The header is as tall as two lines of the name (40 dp; the design's 37 held two lines of smaller
                  // type), so 1.5 dp comes off the top and the rating row takes its share below.
                  padding: EdgeInsets.fromLTRB(13.5 * k, 9 * k, 13.5 * k, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: _headerHeight(k),
                        child: _Header(supplier: supplier, scale: k),
                      ),
                      Container(height: 1.5 * k, color: MartColors.rule),
                      SizedBox(height: 3.5 * k),
                      // As tall as its text (the rating's line is 22 dp, the star's box 20); the gaps either side
                      // each gave up 1 dp, so the row stays where the design put it.
                      Row(
                        children: [
                          // 20.25 dp of ink: the star glyph fills 78% of its box.
                          SizedBox(
                            width: 20.25 * k,
                            height: 20 * k,
                            child: OverflowBox(
                              maxWidth: 25 * k,
                              maxHeight: 25 * k,
                              child: Icon(Icons.star, size: 24.8 * k, color: MartColors.star),
                            ),
                          ),
                          SizedBox(width: 6.75 * k),
                          Text(supplier.ratingLabel, style: scaled(MartText.cardRating, k)),
                          SizedBox(width: 7 * k),
                          Flexible(
                            // The design sets the reviews a hair above the digits' centre line.
                            child: Padding(
                              padding: EdgeInsets.only(bottom: 3 * k),
                              child: Text(
                                '(${supplier.ratingCount} ${supplier.ratingCount == 1 ? 'review' : 'reviews'})',
                                style: scaled(MartText.cardReviews, k),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8 * k),
                      // The title and the two lines under it are as tall as their text: at a narrower cell the engine
                      // rounds a line up past the 20 * k and 37 * k the design gave them.
                      Text(heading, style: scaled(MartText.cardTitle, k), maxLines: 1, overflow: TextOverflow.ellipsis),
                      SizedBox(height: 5.5 * k),
                      Text(body, style: scaled(MartText.cardBody, k), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Two lines of the company's name, which is what the header must hold: 40 dp at the phone design's width. The
/// engine lays each line out on a whole dp, so a line is taken up, never rounded down; the design's own 37 dp is
/// the floor (the logo).
double _headerHeight(double k) {
  final name = scaled(MartText.cardName, k);
  return math.max(37 * k, 2 * (name.fontSize! * name.height!).ceilToDouble());
}

/// The logo and the name: the design's picture, or the company's own logo with
/// its name beside it.
class _Header extends StatelessWidget {
  const _Header({required this.supplier, required this.scale});

  final Supplier supplier;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final lockup = supplier.lockupAsset;
    if (lockup != null) {
      // The picture keeps its own 153 x 37 inside the header's 40.
      return Center(
        child: Image.asset(lockup, width: 153 * k, height: 37 * k, fit: BoxFit.fill, filterQuality: FilterQuality.high),
      );
    }
    final color = supplier.brandColor ?? MartColors.brand;
    return Row(
      children: [
        SizedBox(width: 15 * k),
        SupplierMark(supplier: supplier, maxWidth: 40 * k, height: 37 * k),
        SizedBox(width: 15.5 * k),
        Expanded(
          child: Text(
            supplier.name,
            style: scaled(MartText.cardName, k).copyWith(color: color),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// A supplier's logo as the cards and the profile draw it: the API's picture at
/// half its pixel size, shrunk only to fit; a tile with the first letter when
/// it has none (or when the picture will not load).
class SupplierMark extends StatelessWidget {
  const SupplierMark({super.key, required this.supplier, required this.maxWidth, required this.height});

  final Supplier supplier;
  final double maxWidth;
  final double height;

  @override
  Widget build(BuildContext context) {
    final url = supplier.logoUrl;
    final size = height < maxWidth ? height : maxWidth;
    Widget tile() => Container(
      width: size * 0.8,
      height: size * 0.8,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: (supplier.brandColor ?? MartColors.brand).withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      child: Text(
        supplier.initial,
        style: MartText.cardName.copyWith(
          fontSize: size * 0.42,
          height: 1,
          color: supplier.brandColor ?? MartColors.brand,
        ),
      ),
    );
    return SizedBox(
      width: url == null ? size : null,
      height: height,
      child: url == null
          ? Center(child: tile())
          : ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Image(
                image: CachedNetworkImageProvider(url, scale: 2),
                fit: BoxFit.scaleDown,
                filterQuality: FilterQuality.high,
                alignment: Alignment.centerLeft,
                errorBuilder: (_, _, _) => Center(child: tile()),
              ),
            ),
    );
  }
}

/// The empty tile of a card still loading (a grey card of the same shape).
class SupplierCardSkeleton extends StatelessWidget {
  const SupplierCardSkeleton({super.key, this.scale = 1});

  final double scale;

  @override
  Widget build(BuildContext context) {
    final k = scale;
    return Container(
      height: supplierCardBaseHeight * k,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12 * k),
        border: Border.all(color: MartColors.cardBorder, width: 1.5 * k),
      ),
      padding: EdgeInsets.fromLTRB(13.5 * k, 14 * k, 13.5 * k, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bar(120 * k, 16 * k),
          SizedBox(height: 18 * k),
          _bar(80 * k, 12 * k),
          SizedBox(height: 20 * k),
          _bar(110 * k, 14 * k),
          SizedBox(height: 10 * k),
          _bar(140 * k, 10 * k),
          SizedBox(height: 6 * k),
          _bar(90 * k, 10 * k),
        ],
      ),
    );
  }

  Widget _bar(double w, double h) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(4)),
  );
}
