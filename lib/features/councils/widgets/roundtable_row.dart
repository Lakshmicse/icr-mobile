import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../council_format.dart';
import '../council_models.dart';
import '../councils_styles.dart';
import 'pills.dart';

/// One upcoming roundtable: the date tile, the mode pill and the time, the
/// title, who hosts it, and the calendar glyph. 80.67 dp and a 1 dp rule, as the design's rows.
class RoundtableRow extends StatelessWidget {
  const RoundtableRow({super.key, required this.roundtable, required this.onTap, required this.onCalendar});

  static const height = 80.67;

  final Roundtable roundtable;
  final VoidCallback onTap;
  final VoidCallback onCalendar;

  @override
  Widget build(BuildContext context) {
    final r = roundtable;
    final green = r.tone == RoundtableTone.green;
    final (pillFill, pillText) = switch (r.tone) {
      RoundtableTone.blue => (CouncilsColors.blue50, CouncilsColors.blue700),
      RoundtableTone.green => (CouncilsColors.green100, CouncilsColors.green700),
      RoundtableTone.dark => (CouncilsColors.greyPill, CouncilsColors.slate800),
    };
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Positioned(
              left: 14,
              top: 18,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: green ? CouncilsColors.green50 : CouncilsColors.greyPill,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: green ? CouncilsColors.green200 : CouncilsColors.rowRule),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      monthCaps(r.startsAt),
                      style: green
                          ? CouncilsText.dateMonth.copyWith(color: CouncilsColors.green700)
                          : CouncilsText.dateMonth,
                    ),
                    Text(
                      dayOfMonth(r.startsAt),
                      style: green
                          ? CouncilsText.dateDay.copyWith(color: CouncilsColors.green900)
                          : CouncilsText.dateDay,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 70,
              top: 10.5,
              right: 48,
              child: Row(
                children: [
                  StatusPill(
                    label: r.mode,
                    fill: pillFill,
                    style: CouncilsText.modePill.copyWith(color: pillText),
                    height: 18,
                    radius: 4.5,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      timeRange(r.startsAt, r.endsAt),
                      style: CouncilsText.time,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 70,
              top: 34,
              right: 48,
              child: Text(r.title, style: CouncilsText.roundtableTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            if (r.detail != null)
              Positioned(
                left: 70,
                top: 52,
                right: 48,
                child: Text(
                  r.detail!,
                  style: CouncilsText.roundtableDetail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            Positioned(
              right: 14,
              top: 26,
              child: Semantics(
                button: true,
                label: 'Add to calendar',
                child: InkResponse(
                  onTap: onCalendar,
                  radius: 20,
                  child: const SizedBox(
                    width: 28,
                    height: 28,
                    child: Icon(LucideIcons.calendarPlus, size: 16, color: AppColors.primary),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
