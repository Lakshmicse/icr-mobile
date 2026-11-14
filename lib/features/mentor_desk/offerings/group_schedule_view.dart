import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import 'composer_kit.dart';
import 'group_schedule.dart';
import 'offerings_rules.dart' show maxGroupDays, maxRepeatSessions, maxSessionMinutes, minSessionMinutes;

/// Step 2 of the group composer, "When", drawn for a phone (the website's `ScheduleSection`, `TimeAndLength`,
/// `ScheduleCalendar`, `DayAgenda`, `RepeatControl` and `DateList`): the start time the dates share, the length, the
/// zone, a month calendar to tap dates on (with the days already booked and the clashes marked), the day in view,
/// Repeat, how people register when there are several new dates, and every date with its verdict.
class ScheduleSection extends StatelessWidget {
  const ScheduleSection({super.key, required this.s, this.registered});

  final GroupSchedule s;

  /// Editing: how many people hold a seat (said with the locked days).
  final int? registered;

  @override
  Widget build(BuildContext context) {
    final verdict = s.verdict;
    final multi = s.rows.length > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Time, length and zone wrap one under another on a phone, as the website's row does in a narrow column.
        _StartTimeField(
          keyName: 'group-start-time',
          time: s.time,
          onTime: s.setTime,
          timezone: s.timezone,
          date: s.focused ?? verdict.rows.where((r) => !r.locked).firstOrNull?.date,
        ),
        LengthField(minutes: s.durationMin, onChanged: s.setDuration),
        ComposerField(
          label: 'Timezone',
          help: 'Attendees see the session start time in this time zone.',
          child: SelectBox(
            key: const ValueKey('group-timezone'),
            text: s.timezone,
            icon: LucideIcons.globe,
            onTap: () async {
              final zone = await pickTimezone(context, s.timezone);
              if (zone != null) s.pickZone(zone);
            },
          ),
        ),
        ScheduleCalendar(s: s, verdict: verdict),
        const SizedBox(height: 14),
        DayAgenda(s: s, verdict: verdict, multi: multi),
        const SizedBox(height: 18),
        RepeatControl(s: s),
        if (!s.editing && multi) _RegistrationChoice(s: s),
        DateList(s: s, verdict: verdict, registered: s.editing ? registered : null),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Fields
// ---------------------------------------------------------------------------

/// A field that opens a picker: drawn as the composer's outlined box, with its icon and a chevron.
class SelectBox extends StatelessWidget {
  const SelectBox({
    super.key,
    required this.text,
    required this.onTap,
    this.icon,
    this.enabled = true,
    this.muted = false,
  });

  final String text;
  final VoidCallback onTap;
  final IconData? icon;
  final bool enabled;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        isEmpty: false,
        decoration: composerDecoration('').copyWith(
          enabled: enabled,
          prefixIcon: icon == null ? null : Icon(icon, size: 18, color: AppColors.onSurfaceVariant),
          prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 20),
          suffixIcon: const Icon(LucideIcons.chevronDown, size: 18, color: AppColors.onSurfaceVariant),
          suffixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 20),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.outlineVariant),
          ),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: enabled && !muted ? ComposerText.body : ComposerText.bodyMuted.copyWith(color: AppColors.outline),
        ),
      ),
    );
  }
}

class _StartTimeField extends StatelessWidget {
  const _StartTimeField({
    required this.keyName,
    required this.time,
    required this.onTime,
    required this.timezone,
    this.date,
  });

  final String keyName;
  final int time;
  final ValueChanged<int> onTime;
  final String timezone;
  final String? date;

  @override
  Widget build(BuildContext context) {
    // A mentor whose phone sits in another zone sees what the time is on their own clock.
    String? own;
    if (date != null) {
      final instant = wallToUtc(date!, time, timezone);
      final local = instant.toLocal();
      final clock = fmtClock(local.hour * 60 + local.minute);
      if (clock != fmtClock(time)) own = '$clock on your clock';
    }
    return ComposerField(
      label: 'Start Time',
      help: own,
      child: SelectBox(
        key: ValueKey(keyName),
        text: fmtClock(time),
        icon: LucideIcons.clock,
        onTap: () async {
          final picked = await showTimePicker(
            context: context,
            initialTime: TimeOfDay(hour: time ~/ 60, minute: time % 60),
          );
          if (picked != null) onTime(picked.hour * 60 + picked.minute);
        },
      ),
    );
  }
}

/// The length chips (30 min, 45 min, 1 h, 1½ h, 2 h) and Custom, which opens the hours and minutes.
class LengthField extends StatefulWidget {
  const LengthField({super.key, required this.minutes, required this.onChanged, this.keyPrefix = 'length'});

  final int minutes;
  final ValueChanged<int> onChanged;
  final String keyPrefix;

  static const chips = {30: '30 min', 45: '45 min', 60: '1 h', 90: '1½ h', 120: '2 h'};

  @override
  State<LengthField> createState() => _LengthFieldState();
}

class _LengthFieldState extends State<LengthField> {
  late bool _custom = !LengthField.chips.containsKey(widget.minutes);

  @override
  Widget build(BuildContext context) {
    final p = widget.keyPrefix;
    return ComposerField(
      label: 'Length',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final MapEntry(key: m, value: label) in LengthField.chips.entries)
                _Pill(
                  key: ValueKey('$p-$m'),
                  label: label,
                  selected: !_custom && widget.minutes == m,
                  onTap: () {
                    setState(() => _custom = false);
                    widget.onChanged(m);
                  },
                ),
              _Pill(
                key: ValueKey('$p-custom'),
                label: 'Custom',
                selected: _custom,
                onTap: () => setState(() => _custom = true),
              ),
            ],
          ),
          if (_custom) ...[
            const SizedBox(height: 12),
            DurationPicker(keyPrefix: '$p-duration', minutes: widget.minutes, onChanged: widget.onChanged),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE8EEF5) : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? AppColors.primary : AppColors.outlineVariant),
          ),
          // widthFactor 1: the pill is as wide as its words, never the row.
          child: Center(
            widthFactor: 1,
            child: Text(label, style: selected ? ComposerText.toggleOn : ComposerText.toggle),
          ),
        ),
      ),
    );
  }
}

/// The zones a session can be in, searchable; the current one heads the list when it is not one ICR lists.
Future<String?> pickTimezone(BuildContext context, String current) {
  final zones = [if (!groupTimezones.contains(current)) current, ...groupTimezones];
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
    builder: (_) => _ZoneSheet(zones: zones, current: current),
  );
}

class _ZoneSheet extends StatefulWidget {
  const _ZoneSheet({required this.zones, required this.current});

  final List<String> zones;
  final String current;

  @override
  State<_ZoneSheet> createState() => _ZoneSheetState();
}

class _ZoneSheetState extends State<_ZoneSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase().replaceAll(' ', '_');
    final shown = [
      for (final z in widget.zones)
        if (q.isEmpty || z.toLowerCase().contains(q)) z,
    ];
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('Timezone', style: ComposerText.sectionTitle),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              key: const ValueKey('timezone-search'),
              autofocus: false,
              onChanged: (v) => setState(() => _q = v),
              style: ComposerText.body,
              decoration: composerDecoration(
                'Search for a city, for example Dubai',
              ).copyWith(prefixIcon: const Icon(LucideIcons.search, size: 18, color: AppColors.onSurfaceVariant)),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final z in shown)
                  InkWell(
                    key: ValueKey('timezone-$z'),
                    onTap: () => Navigator.pop(context, z),
                    child: Container(
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                      child: Row(
                        children: [
                          Expanded(child: Text(z, style: ComposerText.body)),
                          if (z == widget.current) const Icon(LucideIcons.check, size: 18, color: AppColors.primary),
                        ],
                      ),
                    ),
                  ),
                if (shown.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('No time zone matches that.', style: ComposerText.bodyMuted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The calendar
// ---------------------------------------------------------------------------

/// The month view a mentor taps dates on: a date of this session is filled, one over a booking red, one that ran
/// grey; a day with something booked carries a dot. Past days cannot be picked.
class ScheduleCalendar extends StatelessWidget {
  const ScheduleCalendar({super.key, required this.s, required this.verdict});

  final GroupSchedule s;
  final ScheduleVerdict verdict;

  @override
  Widget build(BuildContext context) {
    final month = s.month;
    final today = s.today;
    final busyDays = <String>{
      for (final b in s.busy)
        if (b.blocking) wallOf(b.start, s.timezone).date,
    };
    final states = <String, String>{};
    for (final (i, r) in verdict.rows.indexed) {
      final issue = verdict.issues[r.key];
      states[r.date] = r.locked ? 'locked' : (issue is ClashIssue || s.serverClash?.day == i + 1 ? 'clash' : 'picked');
    }
    final gridStart = addDays('$month-01', -weekdayOf('$month-01'));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(fmtMonth(month), key: const ValueKey('cal-month'), style: ComposerText.label),
            ),
            IconButton(
              key: const ValueKey('cal-prev'),
              tooltip: 'Previous Month',
              onPressed: () => s.month = shiftMonth(month, -1),
              icon: const Icon(LucideIcons.chevronLeft, size: 20),
            ),
            IconButton(
              key: const ValueKey('cal-next'),
              tooltip: 'Next Month',
              onPressed: () => s.month = shiftMonth(month, 1),
              icon: const Icon(LucideIcons.chevronRight, size: 20),
            ),
          ],
        ),
        Row(
          children: [
            for (var w = 0; w < 7; w++)
              Expanded(
                child: Center(
                  child: Text(fmtWeekday(w, form: 'narrow'), style: ComposerText.help),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var week = 0; week < 6; week++)
          Row(
            children: [
              for (var d = 0; d < 7; d++)
                Expanded(
                  child: _DayCell(
                    date: addDays(gridStart, week * 7 + d),
                    inMonth: monthOf(addDays(gridStart, week * 7 + d)) == month,
                    today: today,
                    state: states[addDays(gridStart, week * 7 + d)],
                    busy: busyDays.contains(addDays(gridStart, week * 7 + d)),
                    focused: s.focused == addDays(gridStart, week * 7 + d),
                    onTap: s.toggleDate,
                  ),
                ),
            ],
          ),
        Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.only(top: 10),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.outlineVariant)),
          ),
          child: Wrap(
            spacing: 16,
            runSpacing: 6,
            children: const [
              _Legend(color: AppColors.primary, size: 12, label: 'This Session'),
              _Legend(color: AppColors.amber800, size: 6, label: 'Already Booked'),
              _Legend(color: AppColors.error, size: 12, label: 'Clash'),
            ],
          ),
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.inMonth,
    required this.today,
    required this.state,
    required this.busy,
    required this.focused,
    required this.onTap,
  });

  final String date;
  final bool inMonth;
  final String today;

  /// picked, clash, locked, or null.
  final String? state;
  final bool busy;
  final bool focused;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final past = date.compareTo(today) < 0;
    final lit = state == 'picked' || state == 'clash';
    final fill = switch (state) {
      'picked' => AppColors.primary,
      'clash' => AppColors.error,
      'locked' => AppColors.surfaceContainer,
      _ => Colors.transparent,
    };
    final ink = lit
        ? Colors.white
        : state == 'locked'
        ? AppColors.onSurfaceVariant
        : past
        ? AppColors.slate300
        : inMonth
        ? AppColors.onSurface
        : AppColors.slate400;
    final words = <String>[
      if (busy) 'booked',
      if (state == 'locked') 'already ran',
      if (state == 'picked') 'selected',
      if (state == 'clash') 'clashes with a booking',
      if (past && state != 'locked') 'past',
    ];
    return Semantics(
      button: !past,
      label: words.isEmpty ? fmtLongDay(date) : '${fmtLongDay(date)}, ${words.join(', ')}',
      child: InkWell(
        key: ValueKey('cal-$date'),
        onTap: past ? null : () => onTap(date),
        customBorder: const CircleBorder(),
        child: SizedBox(
          height: 44,
          child: Center(
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: fill,
                shape: BoxShape.circle,
                border: date == today && !lit
                    ? Border.all(color: AppColors.primary)
                    : (focused && !lit ? Border.all(color: AppColors.slate400) : null),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    '${int.parse(date.substring(8))}',
                    style: (state != null ? ComposerText.toggleOn : ComposerText.body).copyWith(color: ink),
                  ),
                  if (busy)
                    Positioned(
                      bottom: 4,
                      child: Container(
                        key: ValueKey('cal-dot-$date'),
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: lit ? Colors.white : AppColors.amber800,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.size, required this.label});

  final Color color;
  final double size;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(label, style: ComposerText.help),
    ],
  );
}

// ---------------------------------------------------------------------------
// The day in view
// ---------------------------------------------------------------------------

/// The chosen day under the calendar: this session's dates on it, everything already booked, and the mentor's
/// usual hours for that weekday, so a time is picked with the diary in view.
class DayAgenda extends StatelessWidget {
  const DayAgenda({super.key, required this.s, required this.verdict, required this.multi});

  final GroupSchedule s;
  final ScheduleVerdict verdict;
  final bool multi;

  @override
  Widget build(BuildContext context) {
    final date = s.focused;
    if (date == null) {
      return Column(
        key: const ValueKey('day-agenda'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Select a Date', style: ComposerText.label),
          const SizedBox(height: 2),
          Text('Select a date on the calendar to view existing bookings for that day.', style: ComposerText.bodyMuted),
        ],
      );
    }
    final tz = s.timezone;
    final lines = <Widget>[];
    for (final (i, r) in verdict.rows.indexed) {
      if (wallOf(startOf(r, tz), tz).date != date) continue;
      final issue = verdict.issues[r.key];
      final color = r.locked
          ? AppColors.slate400
          : issue is ClashIssue || issue is PastIssue || issue is OverlapIssue
          ? AppColors.error
          : issue is DraftIssue
          ? AppColors.amber500
          : AppColors.primary;
      final chip = multi ? 'Day ${i + 1} of this session' : 'This session';
      final label = r.locked
          ? '$chip · already ran'
          : (issue == null || issue is MinutesIssue ? '$chip · free in your calendar' : chip);
      lines.add(
        _AgendaLine(
          color: color,
          time: fmtRange(fmtInstantClock(startOf(r, tz), tz), fmtInstantClock(endOf(r, tz), tz)),
          label: label,
        ),
      );
    }
    for (final b in busyOnDay(s.busy, date, tz)) {
      lines.add(
        _AgendaLine(
          color: b.blocking ? AppColors.amber800 : AppColors.slate400,
          time: fmtRange(fmtInstantClock(b.start, tz), fmtInstantClock(b.end, tz)),
          label: b.words,
        ),
      );
    }
    final weekday = weekdayOf(date);
    final hours = [
      for (final w in [...s.windows]..sort((a, b) => a.startMin.compareTo(b.startMin)))
        if (w.weekday == weekday) fmtRange(fmtClock(w.startMin), fmtClock(w.endMin)),
    ];
    return Column(
      key: const ValueKey('day-agenda'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(fmtLongDay(date), style: ComposerText.label),
        const SizedBox(height: 6),
        if (lines.isEmpty) Text('Nothing else booked.', style: ComposerText.bodyMuted) else ...lines,
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(LucideIcons.calendarDays, size: 16, color: AppColors.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                s.windows.isEmpty
                    ? 'No usual hours set'
                    : hours.isEmpty
                    ? 'No usual hours on this day'
                    : 'Your usual hours: ${hours.join(', ')}',
                style: ComposerText.help,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AgendaLine extends StatelessWidget {
  const _AgendaLine({required this.color, required this.time, required this.label});

  final Color color;
  final String time;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(time, style: ComposerText.label),
              Text(label, style: ComposerText.bodyMuted),
            ],
          ),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Repeat
// ---------------------------------------------------------------------------

/// "Repeat": the shapes the first date suggests, how the repeat ends, and Custom for anything else. The rule only
/// fills the date list; every date it makes can still be moved or removed one by one.
class RepeatControl extends StatelessWidget {
  const RepeatControl({super.key, required this.s});

  final GroupSchedule s;

  @override
  Widget build(BuildContext context) {
    final first = s.anchor;
    final rule = s.rule;
    final cap = s.cap - s.lockedCount;
    final preset = rule == null || first == null ? null : presetOf(rule, first);
    final text = rule == null || first == null
        ? 'Does Not Repeat'
        : preset == null
        ? 'Custom: ${ruleWords(rule, first)}'
        : ruleWords(rule, first);
    final count = rule?.count ?? defaultRepeatCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ComposerField(
          label: 'Repeat',
          help: first == null ? 'Select the first session date before setting a recurrence pattern.' : null,
          child: SelectBox(
            key: const ValueKey('group-repeat'),
            text: text,
            icon: LucideIcons.repeat,
            enabled: first != null,
            onTap: () async {
              final choice = await showModalBottomSheet<String>(
                context: context,
                showDragHandle: true,
                backgroundColor: Colors.white,
                builder: (_) => _RepeatMenu(first: first!, count: (count < cap ? count : cap), current: rule),
              );
              if (choice == null || !context.mounted) return;
              if (choice == 'none') return s.setRule(null);
              if (choice == 'custom') {
                final next = await showCustomRepeat(
                  context,
                  first: first!,
                  cap: cap,
                  initial: rule ?? presetRule(RepeatPreset.weekly, first, defaultRepeatCount),
                );
                if (next != null) s.setRule(next);
                return;
              }
              final p = RepeatPreset.values.byName(choice);
              s.setRule(presetRule(p, first!, count < cap ? count : cap));
            },
          ),
        ),
        if (rule != null && first != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: EndsControl(keyPrefix: 'repeat-ends', rule: rule, first: first, cap: cap, onChanged: s.setRule),
          ),
      ],
    );
  }
}

class _RepeatMenu extends StatelessWidget {
  const _RepeatMenu({required this.first, required this.count, required this.current});

  final String first;
  final int count;
  final RepeatRule? current;

  @override
  Widget build(BuildContext context) {
    final now = current == null ? 'none' : (presetOf(current!, first)?.name ?? 'custom');
    Widget item(String value, String label) => InkWell(
      key: ValueKey('repeat-$value'),
      onTap: () => Navigator.pop(context, value),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Expanded(child: Text(label, style: ComposerText.body)),
            if (value == now) const Icon(LucideIcons.check, size: 18, color: AppColors.primary),
          ],
        ),
      ),
    );
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('Repeat', style: ComposerText.sectionTitle),
            ),
            item('none', 'Does Not Repeat'),
            for (final p in RepeatPreset.values) item(p.name, ruleWords(presetRule(p, first, count), first)),
            item('custom', 'Custom…'),
          ],
        ),
      ),
    );
  }
}

/// "Ends: after N times, or on a date".
class EndsControl extends StatelessWidget {
  const EndsControl({
    super.key,
    required this.rule,
    required this.first,
    required this.cap,
    required this.onChanged,
    this.keyPrefix = 'ends',
  });

  final RepeatRule rule;
  final String first;
  final int cap;
  final ValueChanged<RepeatRule> onChanged;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final byCount = rule.count != null;
    final count = rule.count ?? defaultRepeatCount;
    final until = rule.until;
    final most = cap < 2 ? 2 : cap;
    return RadioGroup<bool>(
      groupValue: byCount,
      onChanged: (v) =>
          onChanged(v == true ? rule.copyWith(count: count) : rule.copyWith(endsByCount: false, until: until ?? first)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ends', style: ComposerText.label),
          const SizedBox(height: 4),
          Row(
            children: [
              Radio<bool>(key: ValueKey('$keyPrefix-count'), value: true),
              Text('After', style: ComposerText.body),
              const SizedBox(width: 10),
              _Stepper(
                keyPrefix: '$keyPrefix-times',
                value: count,
                min: 2,
                max: most,
                enabled: byCount,
                onChanged: (n) => onChanged(rule.copyWith(count: n)),
              ),
              const SizedBox(width: 10),
              Text('times', style: ComposerText.body),
            ],
          ),
          Row(
            children: [
              Radio<bool>(key: ValueKey('$keyPrefix-until'), value: false),
              Text('On a Date', style: ComposerText.body),
              const SizedBox(width: 10),
              Expanded(
                child: SelectBox(
                  key: ValueKey('$keyPrefix-until-date'),
                  text: until == null ? 'Last date' : fmtDay(until),
                  icon: LucideIcons.calendarDays,
                  enabled: !byCount,
                  muted: until == null,
                  onTap: () async {
                    final start = parseDateKey(first);
                    final current = until == null ? start : parseDateKey(until);
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime(current.year, current.month, current.day),
                      firstDate: DateTime(start.year, start.month, start.day),
                      lastDate: DateTime(start.year + 2, start.month, start.day),
                    );
                    if (picked != null) {
                      onChanged(
                        rule.copyWith(endsByCount: false, until: dateKeyOf(picked.year, picked.month, picked.day)),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// − N + for a small whole number.
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.keyPrefix,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.enabled = true,
  });

  final String keyPrefix;
  final int value;
  final int min;
  final int max;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget button(String key, IconData icon, int? next) => InkWell(
      key: ValueKey('$keyPrefix-$key'),
      onTap: enabled && next != null ? () => onChanged(next) : null,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 36,
        height: 36,
        child: Icon(icon, size: 16, color: enabled && next != null ? AppColors.primary : AppColors.slate300),
      ),
    );
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button('less', LucideIcons.minus, value > min ? value - 1 : null),
          SizedBox(
            width: 28,
            child: Text(
              '$value',
              key: ValueKey('$keyPrefix-value'),
              textAlign: TextAlign.center,
              style: enabled ? ComposerText.label : ComposerText.label.copyWith(color: AppColors.slate400),
            ),
          ),
          button('more', LucideIcons.plus, value < max ? value + 1 : null),
        ],
      ),
    );
  }
}

/// The custom repeat: every N days, weeks or months; the weekdays of a weekly repeat; the nth weekday or the same
/// date of a monthly one; how it ends; and what it comes to.
Future<RepeatRule?> showCustomRepeat(
  BuildContext context, {
  required String first,
  required int cap,
  required RepeatRule initial,
}) => showModalBottomSheet<RepeatRule>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  backgroundColor: Colors.white,
  builder: (_) => _CustomRepeatSheet(first: first, cap: cap, initial: initial),
);

class _CustomRepeatSheet extends StatefulWidget {
  const _CustomRepeatSheet({required this.first, required this.cap, required this.initial});

  final String first;
  final int cap;
  final RepeatRule initial;

  @override
  State<_CustomRepeatSheet> createState() => _CustomRepeatSheetState();
}

class _CustomRepeatSheetState extends State<_CustomRepeatSheet> {
  late RepeatRule _draft = widget.initial;

  static const _nth = {1: 'first', 2: 'second', 3: 'third', 4: 'fourth', 5: 'fifth'};

  @override
  Widget build(BuildContext context) {
    final first = widget.first;
    final weekdays = _draft.weekdays.isEmpty ? [weekdayOf(first)] : _draft.weekdays;
    final dates = repeatDates(first, _draft, widget.cap);
    String unit(RepeatFreq f) => switch (f) {
      RepeatFreq.day => _draft.interval == 1 ? 'day' : 'days',
      RepeatFreq.week => _draft.interval == 1 ? 'week' : 'weeks',
      RepeatFreq.month => _draft.interval == 1 ? 'month' : 'months',
    };
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Custom Repeat', style: ComposerText.sectionTitle),
            const SizedBox(height: 14),
            Row(
              children: [
                Text('Repeat Every', style: ComposerText.label),
                const SizedBox(width: 10),
                _Stepper(
                  keyPrefix: 'custom-interval',
                  value: _draft.interval,
                  min: 1,
                  max: 12,
                  onChanged: (n) =>
                      setState(() => _draft = _draft.copyWith(interval: n, endsByCount: _draft.count != null)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final f in RepeatFreq.values)
                        _Pill(
                          key: ValueKey('custom-unit-${f.name}'),
                          label: unit(f),
                          selected: _draft.freq == f,
                          onTap: () => setState(
                            () => _draft = RepeatRule(
                              freq: f,
                              interval: _draft.interval,
                              weekdays: f == RepeatFreq.week ? weekdays : const [],
                              monthlyByWeekday: _draft.monthlyByWeekday,
                              count: _draft.count,
                              until: _draft.until,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (_draft.freq == RepeatFreq.week) ...[
              const SizedBox(height: 16),
              Text('On', style: ComposerText.label),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final d in const [1, 2, 3, 4, 5, 6, 0])
                    Semantics(
                      label: fmtWeekday(d),
                      selected: weekdays.contains(d),
                      button: true,
                      child: InkWell(
                        key: ValueKey('custom-weekday-$d'),
                        customBorder: const CircleBorder(),
                        onTap: () {
                          final next = weekdays.contains(d) ? (weekdays.toList()..remove(d)) : [...weekdays, d];
                          if (next.isEmpty) return;
                          setState(() => _draft = _draft.copyWith(weekdays: next, endsByCount: _draft.count != null));
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: weekdays.contains(d) ? AppColors.primary : Colors.white,
                            border: Border.all(
                              color: weekdays.contains(d) ? AppColors.primary : AppColors.outlineVariant,
                            ),
                          ),
                          child: Text(
                            fmtWeekday(d, form: 'narrow'),
                            style: ComposerText.toggle.copyWith(
                              color: weekdays.contains(d) ? Colors.white : AppColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
            if (_draft.freq == RepeatFreq.month) ...[
              const SizedBox(height: 12),
              RadioGroup<bool>(
                groupValue: _draft.monthlyByWeekday,
                onChanged: (v) => setState(
                  () => _draft = _draft.copyWith(monthlyByWeekday: v ?? true, endsByCount: _draft.count != null),
                ),
                child: Column(
                  children: [
                    for (final byWeekday in const [true, false])
                      InkWell(
                        key: ValueKey('custom-monthly-${byWeekday ? 'weekday' : 'date'}'),
                        onTap: () => setState(
                          () =>
                              _draft = _draft.copyWith(monthlyByWeekday: byWeekday, endsByCount: _draft.count != null),
                        ),
                        child: Row(
                          children: [
                            Radio<bool>(value: byWeekday),
                            Expanded(
                              child: Text(
                                byWeekday
                                    ? 'The ${_nth[nthWeekdayOf(first)]} ${fmtWeekday(weekdayOf(first))} of the month'
                                    : 'The ${int.parse(first.substring(8))}th of the month',
                                style: ComposerText.body,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            EndsControl(
              keyPrefix: 'custom-ends',
              rule: _draft,
              first: first,
              cap: widget.cap,
              onChanged: (r) => setState(() => _draft = r),
            ),
            const SizedBox(height: 14),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: ruleWords(_draft, first), style: ComposerText.label),
                  TextSpan(
                    text: ' · ${dates.length} dates · ${fmtDay(dates.first)} – ${fmtDay(dates.last)}',
                    style: ComposerText.body,
                  ),
                ],
              ),
              key: const ValueKey('custom-summary'),
            ),
            const SizedBox(height: 2),
            Text('Up to ${widget.cap} dates.', style: ComposerText.help),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: ComposerText.link),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: const ValueKey('custom-done'),
                  onPressed: () => Navigator.pop(context, _draft),
                  style: FilledButton.styleFrom(shape: const StadiumBorder()),
                  child: const Text('Done'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// How people register, and the dates
// ---------------------------------------------------------------------------

class _RegistrationChoice extends StatelessWidget {
  const _RegistrationChoice({required this.s});

  final GroupSchedule s;

  @override
  Widget build(BuildContext context) {
    final n = s.rows.length;
    Widget option(RegistrationMode mode, String title, String body) => InkWell(
      key: ValueKey('registration-${mode.name}'),
      onTap: () => s.setMode(mode),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Radio<RegistrationMode>(value: mode),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: ComposerText.label.copyWith(color: s.mode == mode ? AppColors.primary : null)),
                    Text(body, style: ComposerText.help),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return ComposerField(
      label: 'How People Register',
      child: RadioGroup<RegistrationMode>(
        groupValue: s.mode,
        onChanged: (m) => s.setMode(m ?? RegistrationMode.series),
        child: Column(
          children: [
            option(
              RegistrationMode.series,
              'One Registration for All $n Dates',
              'A series: people sign up once and attend every date. Up to $maxGroupDays dates.',
            ),
            option(
              RegistrationMode.separate,
              'Each Date Is Its Own Session',
              '$n separate drafts: people choose the dates they want. Up to $maxRepeatSessions.',
            ),
          ],
        ),
      ),
    );
  }
}

/// Every date of the session in the order the API will number them, each with its verdict, its own time if it needs
/// one, and its topic. The red row is the one the save would be refused for.
class DateList extends StatelessWidget {
  const DateList({super.key, required this.s, required this.verdict, this.registered});

  final GroupSchedule s;
  final ScheduleVerdict verdict;
  final int? registered;

  @override
  Widget build(BuildContext context) {
    final rows = verdict.rows;
    final undated = [
      for (final r in s.rows)
        if (!r.dated) r,
    ];
    final multi = s.rows.length > 1;
    final series = s.mode == RegistrationMode.series;
    final open = s.rows.where((r) => !r.locked).length;
    final lastLocked = rows.where((r) => r.locked).length;
    final total = s.rows.length;
    final title = total == 0
        ? 'No Dates Selected Yet'
        : total == 1
        ? '1 Date'
        : rows.length < 2
        ? '$total Dates'
        : '$total Dates · ${fmtShortDay(wallOf(startOf(rows.first, s.timezone), s.timezone).date)} – '
              '${fmtShortDay(wallOf(startOf(rows.last, s.timezone), s.timezone).date)}';
    final outsideKey = verdict.outsideHours.firstOrNull;
    final outside = outsideKey == null ? null : rows.firstWhere((r) => r.key == outsideKey);
    return Column(
      key: const ValueKey('date-list'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title, key: const ValueKey('date-list-title'), style: ComposerText.label),
            ),
            if (open > 0)
              TextButton(
                key: const ValueKey('dates-clear'),
                onPressed: s.clear,
                child: Text('Clear All', style: ComposerText.link),
              ),
          ],
        ),
        if (verdict.overCap > 0)
          _Notice(
            key: const ValueKey('dates-over-cap'),
            icon: LucideIcons.circleAlert,
            color: AppColors.error,
            text: series
                ? 'A series holds up to ${s.cap} dates. Remove some, or make each date its own session.'
                : 'Up to ${s.cap} separate sessions at once. Remove some.',
          ),
        if (outside != null)
          _Notice(
            key: const ValueKey('dates-outside-hours'),
            icon: LucideIcons.triangleAlert,
            color: AppColors.amber800,
            text:
                '${fmtClock(outside.time ?? 0)} is outside your usual hours (${_hoursOn(s, outside)}). You can keep it. '
                'This is only a reminder.',
          ),
        if ((registered ?? 0) > 0)
          _Notice(
            icon: LucideIcons.info,
            color: AppColors.onSurfaceVariant,
            text: lastLocked == 0
                ? 'One registration covers every date · $registered registered.'
                : 'One registration covers every date · $registered registered. New dates are added after Day $lastLocked.',
          ),
        for (final (i, r) in rows.indexed)
          _DateRowView(
            s: s,
            row: r,
            day: i + 1,
            multi: multi,
            series: series,
            issue: verdict.issues[r.key],
            serverMessage: s.serverClash?.day == i + 1 ? s.serverClash!.message : null,
          ),
        for (final (i, r) in undated.indexed) _UndatedRowView(s: s, row: r, day: rows.length + i + 1, multi: multi),
        const SizedBox(height: 8),
        Text(
          s.editing && lastLocked > 0
              ? 'Tap a day on the calendar, or choose Repeat, to add dates after Day $lastLocked.'
              : total <= 1
              ? 'Select more dates on the calendar, or choose Repeat.'
              : series
              ? 'Tap a day on the calendar to add or remove it. Up to ${s.cap} dates in a series.'
              : 'Tap a day on the calendar to add or remove it. Up to ${s.cap} separate sessions.',
          style: ComposerText.help,
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  static String _hoursOn(GroupSchedule s, DateRow row) {
    final tz = s.windowsTz ?? s.timezone;
    final weekday = weekdayOf(wallOf(startOf(row, s.timezone), tz).date);
    final same = [
      for (final w in s.windows)
        if (w.weekday == weekday) fmtRange(fmtClock(w.startMin), fmtClock(w.endMin)),
    ];
    return same.isEmpty ? 'No usual hours on this day' : same.join(', ');
  }
}

class _Notice extends StatelessWidget {
  const _Notice({super.key, required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: ComposerText.body.copyWith(color: color)),
        ),
      ],
    ),
  );
}

class _DateRowView extends StatelessWidget {
  const _DateRowView({
    required this.s,
    required this.row,
    required this.day,
    required this.multi,
    required this.series,
    required this.issue,
    required this.serverMessage,
  });

  final GroupSchedule s;
  final DateRow row;
  final int day;
  final bool multi;
  final bool series;
  final RowIssue? issue;
  final String? serverMessage;

  @override
  Widget build(BuildContext context) {
    final tz = s.timezone;
    final chip = multi ? 'Day $day' : 'Date';
    final start = startOf(row, tz);
    final end = endOf(row, tz);
    final when = '${fmtInstantDay(start, tz)} · ${fmtRange(fmtInstantClock(start, tz), fmtInstantClock(end, tz))}';
    var tone = 'ok';
    var status = 'Free in your calendar';
    final i = issue;
    if (row.locked) {
      tone = 'muted';
      status = row.status == 'CANCELLED'
          ? 'Cancelled on ${fmtInstantDay(start, tz)}. The date cannot change.'
          : 'Ran on ${fmtInstantDay(start, tz)}. The date cannot change.';
    } else if (serverMessage != null) {
      tone = 'bad';
      status = serverMessage!;
    } else if (i is ClashIssue || i is DraftIssue) {
      final w = i is ClashIssue ? i.with_ : (i as DraftIssue).with_;
      final range = fmtRange(fmtInstantClock(w.start, tz), fmtInstantClock(w.end, tz));
      tone = i is ClashIssue ? 'bad' : 'warn';
      status = i is ClashIssue
          ? 'Clashes with ${w.words}, $range. Change the time or remove this date.'
          : 'Overlaps ${w.words}, $range. Allowed, but one of them will have to move.';
    } else if (i is PastIssue) {
      tone = 'bad';
      status = 'This time has passed. Choose a later one.';
    } else if (i is OverlapIssue) {
      tone = 'bad';
      status = 'Overlaps Day ${i.day}.';
    } else if (i is MinutesIssue) {
      tone = 'bad';
      status = '$minSessionMinutes–$maxSessionMinutes minutes.';
    }
    final color = switch (tone) {
      'bad' => AppColors.error,
      'warn' => AppColors.amber800,
      'ok' => AppColors.successInk,
      _ => AppColors.onSurfaceVariant,
    };
    final icon = switch (tone) {
      'muted' => LucideIcons.lock,
      'bad' => LucideIcons.circleAlert,
      'warn' => LucideIcons.triangleAlert,
      _ => LucideIcons.check,
    };
    return Container(
      key: ValueKey('date-row-${day - 1}'),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Chip(label: chip, tone: tone),
              const SizedBox(width: 10),
              Expanded(
                child: Text(when, key: ValueKey('date-when-${day - 1}'), style: ComposerText.label),
              ),
              if (!row.locked) ...[
                // "Change time" as a clock, so the date keeps its line on a phone.
                IconButton(
                  key: ValueKey('date-time-${day - 1}'),
                  tooltip: 'Change Time',
                  onPressed: () => _ownTime(context, chip),
                  icon: const Icon(LucideIcons.clock, size: 18, color: AppColors.primary),
                ),
                IconButton(
                  key: ValueKey('date-remove-${day - 1}'),
                  tooltip: 'Remove $chip',
                  onPressed: () => s.removeRow(row.key),
                  icon: const Icon(LucideIcons.x, size: 18, color: AppColors.onSurfaceVariant),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  status,
                  key: ValueKey('date-status-${day - 1}'),
                  style: ComposerText.body.copyWith(color: color, fontWeight: tone == 'bad' ? FontWeight.w600 : null),
                ),
              ),
            ],
          ),
          if (series && multi) ...[
            const SizedBox(height: 8),
            TextFormField(
              key: ValueKey('date-topic-${day - 1}'),
              initialValue: row.title,
              maxLength: 160,
              buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
              onChanged: (v) => s.updateRow(row.key, title: v),
              style: ComposerText.body,
              decoration: composerDecoration(day == 1 ? 'Before the keys' : 'Day $day topic (optional)'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _ownTime(BuildContext context, String chip) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (_) => ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final r = s.rows.where((x) => x.key == row.key).firstOrNull;
        if (r == null) return const SizedBox.shrink();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('$chip · Its Own Time', style: ComposerText.sectionTitle),
                const SizedBox(height: 14),
                _StartTimeField(
                  keyName: 'row-start-time',
                  time: r.time ?? s.time,
                  onTime: (t) => s.updateRow(r.key, time: t),
                  timezone: s.timezone,
                  date: r.date,
                ),
                LengthField(
                  keyPrefix: 'row-length',
                  minutes: r.durationMin,
                  onChanged: (m) => s.updateRow(r.key, durationMin: m),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    key: const ValueKey('row-time-done'),
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(shape: const StadiumBorder()),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// A copied day that has no date yet ("Run it again"): the next calendar tap gives it one.
class _UndatedRowView extends StatelessWidget {
  const _UndatedRowView({required this.s, required this.row, required this.day, required this.multi});

  final GroupSchedule s;
  final DateRow row;
  final int day;
  final bool multi;

  @override
  Widget build(BuildContext context) {
    final chip = multi ? 'Day $day' : 'Date';
    return Container(
      key: ValueKey('date-undated-${day - 1}'),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: Row(
        children: [
          _Chip(label: chip, tone: 'muted'),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              row.title.isEmpty
                  ? 'No date yet. Tap a day on the calendar to give it one.'
                  : '${row.title} · No date yet. Tap a day on the calendar to give it one.',
              style: ComposerText.bodyMuted,
            ),
          ),
          IconButton(
            key: ValueKey('date-undated-remove-${day - 1}'),
            tooltip: 'Remove $chip',
            onPressed: () => s.removeRow(row.key),
            icon: const Icon(LucideIcons.x, size: 18, color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.tone});

  final String label;
  final String tone;

  @override
  Widget build(BuildContext context) {
    final bad = tone == 'bad';
    final muted = tone == 'muted';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bad ? AppColors.error : (muted ? AppColors.surfaceContainer : Colors.white),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: bad ? AppColors.error : (muted ? AppColors.surfaceContainer : AppColors.primary)),
      ),
      child: Text(
        label,
        style: ComposerText.badge.copyWith(
          color: bad ? Colors.white : (muted ? AppColors.onSurfaceVariant : AppColors.primary),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
