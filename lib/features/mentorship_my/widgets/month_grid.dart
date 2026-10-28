import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../mentoring_format.dart';
import '../mentoring_models.dart';
import 'kit.dart';
import '../mentoring_clock.dart';

/// A month as a grid of days (weeks start on Monday), a dot under each day that
/// holds something, the picked day lit. [marks] says which kinds of thing a day
/// holds, keyed by the day of the month.
class MonthGrid extends StatelessWidget {
  const MonthGrid({
    super.key,
    required this.month,
    required this.selected,
    required this.marks,
    required this.onSelect,
    required this.onPrevious,
    required this.onNext,
    this.today,
  });

  /// The first day of the month shown.
  final DateTime month;
  final DateTime selected;
  final Map<int, Set<CalendarKind>> marks;
  final ValueChanged<DateTime> onSelect;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final DateTime? today;

  static Color kindColor(CalendarKind kind) => switch (kind) {
    CalendarKind.session => AppColors.primary,
    CalendarKind.booking => MentoringColors.green,
    CalendarKind.group => MentoringColors.star,
  };

  @override
  Widget build(BuildContext context) {
    final now = today ?? mentoringNow();
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final lead = month.weekday - 1; // blank cells before the 1st
    final cells = ((lead + daysInMonth + 6) ~/ 7) * 7;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardRule),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Previous month',
                onPressed: onPrevious,
                icon: const Icon(LucideIcons.chevronLeft, size: 18, color: AppColors.onSurfaceVariant),
              ),
              Expanded(
                child: Text(monthLabel(month), textAlign: TextAlign.center, style: MentoringText.section),
              ),
              IconButton(
                tooltip: 'Next month',
                onPressed: onNext,
                icon: const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
          Row(
            children: [
              for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                Expanded(
                  child: Center(child: Text(d, style: MentoringText.meta)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (var week = 0; week < cells ~/ 7; week++)
            Row(
              children: [
                for (var col = 0; col < 7; col++) Expanded(child: _cell(week * 7 + col - lead + 1, daysInMonth, now)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _cell(int day, int daysInMonth, DateTime now) {
    if (day < 1 || day > daysInMonth) return const SizedBox(height: 40);
    final date = DateTime(month.year, month.month, day);
    final isSelected = selected.year == date.year && selected.month == date.month && selected.day == date.day;
    final isToday = now.year == date.year && now.month == date.month && now.day == date.day;
    final kinds = marks[day] ?? const <CalendarKind>{};
    return Semantics(
      button: true,
      selected: isSelected,
      label: '${weekdayDay(date)}${kinds.isEmpty ? '' : ', ${kinds.length == 1 ? 'one kind of event' : 'events'}'}',
      child: InkWell(
        key: ValueKey('day-$day'),
        borderRadius: BorderRadius.circular(8),
        onTap: () => onSelect(date),
        child: SizedBox(
          height: 40,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  shape: BoxShape.circle,
                  border: isToday && !isSelected ? Border.all(color: AppColors.primary) : null,
                ),
                child: Text(
                  '$day',
                  style: AppText.plexSans(
                    12,
                    isToday || isSelected ? FontWeight.w700 : FontWeight.w500,
                    isSelected ? Colors.white : AppColors.onSurface,
                    lineHeight: 16,
                  ),
                ),
              ),
              SizedBox(
                height: 6,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final k in CalendarKind.values)
                      if (kinds.contains(k))
                        Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(color: kindColor(k), shape: BoxShape.circle),
                        ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
