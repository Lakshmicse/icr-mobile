import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';

/// A door on the Discover sheet. Each piece of artwork has its own extent, so
/// the artwork and the label sit where the design puts them, measured per
/// door, rather than by one rule.
class DiscoverDoor {
  const DiscoverDoor(
    this.label, {
    required this.icon,
    required this.iconLeft,
    required this.textLeft,
    required this.sitePath,
  });

  final String label;

  /// Under assets/images/icons/, cut from the design at 2x.
  final String icon;

  /// From the door's outer left edge.
  final double iconLeft;
  final double textLeft;

  /// The page on the website this door opens.
  final String sitePath;
}

/// Two doors side by side; the design gives each row its own height.
class DiscoverRow {
  const DiscoverRow(this.height, this.left, this.right);

  final double height;
  final DiscoverDoor left;
  final DiscoverDoor right;
}

/// The Discover sheet: the association's doors, then the business ones.
class DiscoverSheet extends StatelessWidget {
  const DiscoverSheet({super.key, required this.onOpen});

  /// Called with the door tapped.
  final ValueChanged<DiscoverDoor> onOpen;

  /// Handle, two rows, the "For Business" rule and two more rows.
  static const height = 270.0;
  static const radius = 16.0;

  static const community = [
    DiscoverRow(
      42,
      DiscoverDoor(
        'Regional Chapters',
        icon: 'discover_chapters.png',
        iconLeft: 9,
        textLeft: 43.5,
        sitePath: '/chapters',
      ),
      DiscoverDoor(
        'Working Councils',
        icon: 'discover_councils.png',
        iconLeft: 8.5,
        textLeft: 44,
        sitePath: '/councils',
      ),
    ),
    DiscoverRow(
      46,
      DiscoverDoor(
        'Digital Library',
        icon: 'discover_library.png',
        iconLeft: 10,
        textLeft: 46.5,
        sitePath: '/documents',
      ),
      DiscoverDoor('Events', icon: 'discover_events.png', iconLeft: 7.5, textLeft: 44.5, sitePath: '/events'),
    ),
  ];

  static const business = [
    DiscoverRow(
      35,
      DiscoverDoor(
        'Hire',
        icon: 'discover_hire.png',
        iconLeft: 14,
        textLeft: 45.5,
        sitePath: '/account/companies/new?role=COMPANY_ADMIN',
      ),
      DiscoverDoor(
        'Sell',
        icon: 'discover_sell.png',
        iconLeft: 12.5,
        textLeft: 41.5,
        sitePath: '/account/companies/new?role=VENDOR',
      ),
    ),
    DiscoverRow(
      35,
      DiscoverDoor(
        'Post requirement',
        icon: 'discover_post_requirement.png',
        iconLeft: 17.5,
        textLeft: 45.5,
        sitePath: '/rfq/new',
      ),
      DiscoverDoor('Advertise', icon: 'discover_advertise.png', iconLeft: 10.5, textLeft: 42, sitePath: '/advertise'),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(radius)),
      child: Container(
        height: height,
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Rule(AppColors.slate200),
            // The handle: 40 × 4, ten down from the top edge.
            SizedBox(
              height: 33,
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 9),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: AppColors.slate300, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
              ),
            ),
            const _Rule(AppColors.slate100),
            const SizedBox(height: 17),
            // The design's margins: 21 on the left, 19 on the right.
            Padding(
              padding: const EdgeInsets.only(left: 21, right: 19),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, row) in community.indexed) ...[
                    if (i > 0) const SizedBox(height: 10),
                    _DoorRow(row, onOpen: onOpen),
                  ],
                  const _ForBusiness(),
                  for (final (i, row) in business.indexed) ...[
                    if (i > 0) const SizedBox(height: 10),
                    _DoorRow(row, onOpen: onOpen),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) => ColoredBox(color: color, child: const SizedBox(height: 1));
}

class _DoorRow extends StatelessWidget {
  const _DoorRow(this.row, {required this.onOpen});

  final DiscoverRow row;
  final ValueChanged<DiscoverDoor> onOpen;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: row.height,
      child: Row(
        children: [
          Expanded(child: _Door(row.left, onOpen: onOpen)),
          const SizedBox(width: 10),
          Expanded(child: _Door(row.right, onOpen: onOpen)),
        ],
      ),
    );
  }
}

class _Door extends StatelessWidget {
  const _Door(this.door, {required this.onOpen});

  final DiscoverDoor door;
  final ValueChanged<DiscoverDoor> onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onOpen(door),
        child: Stack(
          children: [
            Positioned(
              left: door.iconLeft,
              top: 0,
              bottom: 0,
              child: Center(
                child: Image.asset('assets/images/icons/${door.icon}', scale: 2, filterQuality: FilterQuality.high),
              ),
            ),
            Positioned(
              left: door.textLeft,
              top: 0,
              bottom: 0,
              child: Center(child: Text(door.label, style: AppText.discoverTile)),
            ),
          ],
        ),
      ),
    );
  }
}

/// "For Business" between two hairlines, centred in a 31 dp band.
class _ForBusiness extends StatelessWidget {
  const _ForBusiness();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 31,
      child: Padding(
        padding: const EdgeInsets.only(left: 10, right: 10.5),
        child: Row(
          children: [
            const Expanded(child: _Rule(AppColors.surfaceContainer)),
            const SizedBox(width: 12),
            // The design's caps sit half a dp above the rule's centre.
            Transform.translate(
              offset: const Offset(0, -0.5),
              child: Text('For Business', style: AppText.discoverSection),
            ),
            const SizedBox(width: 12),
            const Expanded(child: _Rule(AppColors.surfaceContainer)),
          ],
        ),
      ),
    );
  }
}

/// The sheet over the open tab. The page behind it blurs and dims as the
/// sheet slides up; the bar underneath stays as it is. Tapping the page, the
/// Discover tab again, Back, or dragging the sheet down closes it.
class DiscoverLayer extends StatelessWidget {
  const DiscoverLayer({super.key, required this.controller, required this.onClose, required this.onOpen});

  /// 0 closed, 1 open; owned by the shell so Back and the tab can drive it.
  final AnimationController controller;
  final VoidCallback onClose;
  final ValueChanged<DiscoverDoor> onOpen;

  /// How soft the page behind the sheet goes, in dp.
  static const blur = 2.0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: DiscoverSheet(onOpen: onOpen),
      builder: (context, sheet) {
        final t = controller.value;
        if (t == 0) return const SizedBox.shrink();
        return Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClose,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: blur * t, sigmaY: blur * t),
                  child: ColoredBox(color: AppColors.sheetScrim.withValues(alpha: AppColors.sheetScrim.a * t)),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: -(1 - t) * DiscoverSheet.height,
              child: GestureDetector(
                onVerticalDragUpdate: (d) => controller.value -= (d.primaryDelta ?? 0) / DiscoverSheet.height,
                onVerticalDragEnd: (d) {
                  if ((d.primaryVelocity ?? 0) > 300 || controller.value < 0.5) {
                    controller.reverse();
                  } else {
                    controller.forward();
                  }
                },
                child: sheet,
              ),
            ),
          ],
        );
      },
    );
  }
}
