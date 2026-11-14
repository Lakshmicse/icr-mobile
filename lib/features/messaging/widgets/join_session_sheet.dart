import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/util/join_window.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/detail_sheet.dart' show SheetHandle;
import '../../../core/widgets/section_heading.dart' show Hairline;
import '../messaging_format.dart';
import '../messaging_styles.dart';
import 'message_bubble.dart' show MeetingFacts;

/// The thread's booked session as its own record holds it: the call's address and when it may be joined.
class SessionJoin {
  const SessionJoin({this.link, this.windows = const [], this.inPerson = false, this.note, this.start, this.end});

  /// When the session runs by its record (the thread only knows its start, and assumes twenty minutes).
  final DateTime? start;
  final DateTime? end;

  /// Opens the call; null while the session has none (held in person, or no link added yet).
  final Uri? link;

  /// When the call may be joined (`core/util/join_window.dart`): several for a session held over several days, none
  /// when the record has no session still to come.
  final List<JoinWindow> windows;

  /// Held in a room, not on a call: there is nothing to join.
  final bool inPerson;

  /// Why there is no call to join yet, in the record's own terms ("Pay for the booking to confirm it.").
  final String? note;
}

/// Opens [JoinSessionSheet] over the thread.
Future<void> showJoinSessionSheet(
  BuildContext context, {
  required MeetingFacts facts,
  required Future<SessionJoin?> Function()? load,
  required ValueChanged<Uri> onJoin,
  required VoidCallback onAddToCalendar,
  VoidCallback? onOpenRecord,
  String recordLabel = 'View Details',
  DateTime Function() clock = DateTime.now,
}) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: Colors.white,
  isScrollControlled: true,
  useSafeArea: true,
  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
  builder: (sheet) => JoinSessionSheet(
    facts: facts,
    load: load,
    onJoin: onJoin,
    onAddToCalendar: onAddToCalendar,
    onOpenRecord: onOpenRecord,
    recordLabel: recordLabel,
    clock: clock,
  ),
);

/// What a thread's "Join" opens (owner, 14 Nov 2026: the old "Meet" pill landed on the record's page, which had no
/// Join of its own until the call was near). It is about this one session: what it is, when it runs, where the call
/// stands, and the Join itself — pressable from 15 minutes before the start until 30 minutes after the end (the
/// app's one join rule), greyed with the time it opens before that. The calendar and the record's own page sit
/// under it, as quiet links. The call's address is read from the session's record when the sheet opens, since the
/// thread does not carry it.
class JoinSessionSheet extends StatefulWidget {
  const JoinSessionSheet({
    super.key,
    required this.facts,
    required this.load,
    required this.onJoin,
    required this.onAddToCalendar,
    this.onOpenRecord,
    this.recordLabel = 'View Details',
    this.clock = DateTime.now,
  });

  final MeetingFacts facts;

  /// Reads the session's record; null when the app has no reader for it.
  final Future<SessionJoin?> Function()? load;
  final ValueChanged<Uri> onJoin;
  final VoidCallback onAddToCalendar;

  /// The session's record (the pairing, the booking, the group session); null draws no link.
  final VoidCallback? onOpenRecord;
  final String recordLabel;
  final DateTime Function() clock;

  @override
  State<JoinSessionSheet> createState() => _JoinSessionSheetState();
}

class _JoinSessionSheetState extends State<JoinSessionSheet> {
  bool _loading = true;
  SessionJoin? _join;

  @override
  void initState() {
    super.initState();
    unawaited(_read());
  }

  Future<void> _read() async {
    final load = widget.load;
    SessionJoin? found;
    if (load != null) {
      try {
        found = await load();
      } catch (_) {
        // Unreadable: the sheet says so and keeps the record's page.
      }
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _join = found;
    });
  }

  /// Closes the sheet, then does [then] from the thread.
  void _closeThen(VoidCallback then) {
    Navigator.of(context).pop();
    then();
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.facts;
    final join = _join;
    // The record's own windows once read; the thread's own guess (its start, twenty minutes) until then.
    final windows = join == null || join.windows.isEmpty
        ? [JoinWindow(f.start, f.end.difference(f.start).inMinutes)]
        : join.windows;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: JoinWindowBuilder(
          windows: windows,
          clock: widget.clock,
          builder: (context, state, window) {
            final status = _status(join, state, window);
            final link = join?.link;
            final canJoin = !_loading && link != null && state == JoinState.open;
            return Column(
              key: const ValueKey('join-sheet'),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SheetHandle(rule: false, height: 28, top: 10),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(LucideIcons.video, size: 20, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(f.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: ChatText.sheetTitle),
                          const SizedBox(height: 2),
                          Text(f.sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: ChatText.meetingSub),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Hairline(),
                _Line(
                  key: const ValueKey('join-when'),
                  icon: LucideIcons.calendarClock,
                  text: meetingWhen(join?.start ?? f.start, join?.end ?? f.end, now: widget.clock()),
                ),
                _Line(
                  key: const ValueKey('join-status'),
                  icon: status.icon,
                  text: status.text,
                  color: status.color,
                ),
                const SizedBox(height: 14),
                PrimaryButton(
                  key: const ValueKey('join-now'),
                  label: !_loading && link != null && state == JoinState.early && window != null
                      ? 'Join from ${_opensLabel(window.opensAt)}'
                      : 'Join',
                  icon: LucideIcons.video,
                  height: 46,
                  onPressed: canJoin ? () => _closeThen(() => widget.onJoin(link)) : null,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _Quiet(
                        key: const ValueKey('join-calendar'),
                        icon: LucideIcons.calendarPlus,
                        label: 'Add to Calendar',
                        onTap: () => _closeThen(widget.onAddToCalendar),
                      ),
                    ),
                    if (widget.onOpenRecord != null)
                      Expanded(
                        child: _Quiet(
                          key: const ValueKey('join-record'),
                          icon: LucideIcons.arrowUpRight,
                          label: widget.recordLabel,
                          onTap: () => _closeThen(widget.onOpenRecord!),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  ({IconData icon, String text, Color color}) _status(SessionJoin? join, JoinState state, JoinWindow? window) {
    const quiet = AppColors.onSurfaceVariant;
    if (_loading) return (icon: LucideIcons.loader, text: "Getting the call's link…", color: quiet);
    if (join == null) {
      return (
        icon: LucideIcons.info,
        text: widget.onOpenRecord == null
            ? 'The call could not be read. Try again in a moment.'
            : "The call could not be read. Its link is on the session's page.",
        color: quiet,
      );
    }
    if (join.inPerson) return (icon: LucideIcons.mapPin, text: 'Held in person: there is no call to join.', color: quiet);
    if (join.windows.isEmpty) {
      return (icon: LucideIcons.calendarX, text: join.note ?? 'No session is booked on its record.', color: quiet);
    }
    if (join.link == null) {
      return (
        icon: LucideIcons.link2Off,
        text: join.note ?? 'No call link yet. It is added before the session.',
        color: quiet,
      );
    }
    return switch (state) {
      JoinState.open => (icon: LucideIcons.radio, text: 'The call is open. Join now.', color: AppColors.primary),
      JoinState.early => (
        icon: LucideIcons.clock,
        text: 'Opens at ${_opensLabel(window!.opensAt)}, 15 minutes before it starts.',
        color: quiet,
      ),
      JoinState.closed => (icon: LucideIcons.circleCheck, text: 'This session has ended.', color: quiet),
    };
  }

  /// "3:45 PM" today, else "Thu, 29 Oct, 3:45 PM".
  String _opensLabel(DateTime at) {
    final now = widget.clock();
    return sameDay(at, now) ? messageTime(at) : '${weekdayDate(at)}, ${messageTime(at)}';
  }
}

/// One fact under the title: a glyph and a line.
class _Line extends StatelessWidget {
  const _Line({super.key, required this.icon, required this.text, this.color = AppColors.onSurfaceVariant});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: ChatText.meetingLine.copyWith(color: color))),
      ],
    ),
  );
}

/// A quiet link under the Join: a glyph and a word, no box.
class _Quiet extends StatelessWidget {
  const _Quiet({super.key, required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 16),
    label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    style: TextButton.styleFrom(
      foregroundColor: AppColors.primary,
      minimumSize: const Size.fromHeight(44),
      textStyle: ChatText.fileAction,
    ),
  );
}
