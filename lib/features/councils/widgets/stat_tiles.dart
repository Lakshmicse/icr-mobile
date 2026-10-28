import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../council_format.dart';
import '../council_models.dart';
import '../councils_styles.dart';
import 'pills.dart';

/// The 2 × 2 grid of grey tiles under the title bar: 176 × 55.5 each (a 1 dp
/// #F1F5F9 border inside that), 7 dp apart across and 3 dp down, with the
/// screen's 16 dp margin.
class StatTiles extends StatelessWidget {
  const StatTiles({super.key, required this.stats});

  final CouncilStats stats;

  static const tileWidth = 176.0;
  static const tileHeight = 55.5;
  static const gap = 7.0;
  static const rowGap = 3.0;
  static const height = tileHeight * 2 + rowGap;

  @override
  Widget build(BuildContext context) {
    final members = stats.peerMembersLabel ?? groupThousands(stats.peerMembers);
    final quarter = stats.newThisQuarter > 0 && stats.quarter != null
        ? '+${stats.newThisQuarter} ${stats.quarter}'
        : null;
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatTile(
                label: 'Active Councils',
                value: '${stats.activeCouncils}',
                valueStyle: CouncilsText.statValueBlue,
                trailing: quarter == null
                    ? null
                    : StatusPill(
                        label: quarter,
                        fill: CouncilsColors.green100,
                        style: CouncilsText.statPill,
                        height: 16,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                      ),
              ),
              const SizedBox(width: gap),
              StatTile(label: 'Peer Members', value: members),
            ],
          ),
          const SizedBox(height: rowGap),
          Row(
            children: [
              StatTile(label: 'Domains Covered', value: '${stats.domains}'),
              const SizedBox(width: gap),
              StatTile(
                label: 'Active Roundtables',
                value: '${stats.activeRoundtables}',
                valueStyle: CouncilsText.statValueBlue,
                trailing: stats.activeRoundtables > 0
                    ? Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.only(top: 2, right: 1),
                        decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                      )
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, this.valueStyle, this.trailing});

  final String label;
  final String value;
  final TextStyle? valueStyle;

  /// The pill or dot at the top right.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: StatTiles.tileWidth,
      height: StatTiles.tileHeight,
      decoration: BoxDecoration(
        color: CouncilsColors.tile,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.slate100),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 9,
            top: 7,
            right: 9,
            child: Text(label, style: CouncilsText.statLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Positioned(
            left: 9,
            // The pill beside the first tile's label makes that row taller, which pushes its figure down.
            top: trailing is StatusPill ? 28.5 : 26.5,
            right: 10,
            child: Text(
              value,
              style: valueStyle ?? CouncilsText.statValue,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) Positioned(right: 9.5, top: 7, child: trailing!),
        ],
      ),
    );
  }
}
