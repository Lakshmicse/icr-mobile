import 'package:flutter/material.dart';

import 'supplier_card.dart';

/// How many cards a row holds: two on a phone, three from 600 dp wide (the
/// tablet design). [force] is for tests, which draw the tablet's three columns
/// on the phone's frame.
int marketColumns(double width, {int? force}) => force ?? (width >= 600 ? 3 : 2);

/// Where the cards sit in a row of [columns] across [width].
class GridMetrics {
  const GridMetrics._(this.margin, this.gap, this.cell, this.scale);

  factory GridMetrics.of(double width, int columns) {
    const margin = 12.0;
    // The tablet comp packs three cards into a phone's width with 4 dp between;
    // a real tablet has room for the phone's 6.5.
    final gap = columns >= 3 && width < 500 ? 4.0 : 6.5;
    final cell = (width - margin * 2 - gap * (columns - 1)) / columns;
    final scale = (cell / supplierCardBaseWidth).clamp(0.4, 1.0);
    return GridMetrics._(margin, gap, cell, scale.toDouble());
  }

  final double margin;
  final double gap;

  /// The width of one card.
  final double cell;

  /// How much smaller than the phone design's card a cell draws it.
  final double scale;
}

/// The grid of cards as a sliver: rows of [columns], built as they scroll into
/// view. [cardAt] builds the [index]th card at [scale].
class SupplierGridSliver extends StatelessWidget {
  const SupplierGridSliver({super.key, required this.count, required this.cardAt, this.forceColumns});

  final int count;
  final Widget Function(BuildContext context, int index, double scale) cardAt;
  final int? forceColumns;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.crossAxisExtent;
        final columns = marketColumns(width, force: forceColumns);
        final m = GridMetrics.of(width, columns);
        final rows = (count / columns).ceil();
        return SliverList.builder(
          itemCount: rows,
          itemBuilder: (context, row) => Padding(
            padding: EdgeInsets.fromLTRB(m.margin, row == 0 ? 0 : 9 * m.scale.clamp(0.7, 1.0), m.margin, 0),
            child: Row(
              children: [
                for (var c = 0; c < columns; c++) ...[
                  if (c > 0) SizedBox(width: m.gap),
                  SizedBox(
                    width: m.cell,
                    child: row * columns + c < count ? cardAt(context, row * columns + c, m.scale) : null,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
