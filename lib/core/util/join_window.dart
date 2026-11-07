/// When a call may be joined: the one rule every Join button in the app reads.
///
/// The website's (`canJoinSession` in the portal's `@icr/shared/meetings.ts`):
/// from 15 minutes before the start until 30 minutes after the call was due to
/// end, the window ICR Meet's own rooms keep. Before it, a Join is drawn but
/// cannot be pressed; after it, no Join is drawn, so a session whose hour has
/// gone by stops offering a call (owner, 4 Nov 2026: "Past dates sessions also
/// can join").
library;

import 'dart:async';

import 'package:flutter/widgets.dart';

/// A call's room opens this long before it starts…
const joinOpensBefore = Duration(minutes: 15);

/// …and stays open this long after it was due to end, for one that overruns.
const joinClosesAfter = Duration(minutes: 30);

enum JoinState { early, open, closed }

/// One call's window.
class JoinWindow {
  JoinWindow(DateTime startsAt, int durationMin)
    : opensAt = startsAt.subtract(joinOpensBefore),
      closesAt = startsAt.add(Duration(minutes: durationMin)).add(joinClosesAfter);

  final DateTime opensAt;
  final DateTime closesAt;

  JoinState stateAt(DateTime now) {
    if (now.isBefore(opensAt)) return JoinState.early;
    if (now.isAfter(closesAt)) return JoinState.closed;
    return JoinState.open;
  }
}

/// Where a call, or a multi-day one's several days, stands at [now]: open while
/// any day's window is, else early with the next day to open, else closed.
({JoinState state, JoinWindow? window}) joinStateOf(Iterable<JoinWindow> windows, DateTime now) {
  JoinWindow? next;
  for (final w in windows) {
    final state = w.stateAt(now);
    if (state == JoinState.open) return (state: JoinState.open, window: w);
    if (state == JoinState.early && (next == null || w.opensAt.isBefore(next.opensAt))) next = w;
  }
  return next == null ? (state: JoinState.closed, window: null) : (state: JoinState.early, window: next);
}

/// Whether a Join belongs on the card at all: true until the last window closes.
/// A row of buttons asks this before it adds one, so a closed call leaves no gap.
bool joinShown(DateTime startsAt, int durationMin, DateTime now) =>
    JoinWindow(startsAt, durationMin).stateAt(now) != JoinState.closed;

/// Builds with where [windows] stand now, and again whenever that changes, so a
/// Join turns pressable when the call opens and goes when it closes while the
/// screen stays open. Checks every half minute, as the website's button does.
class JoinWindowBuilder extends StatefulWidget {
  const JoinWindowBuilder({super.key, required this.windows, required this.builder, this.clock = DateTime.now});

  final List<JoinWindow> windows;

  /// "Now"; a screen passes the clock its tests pin.
  final DateTime Function() clock;

  /// [window] is the open one, or the next to open when early; null once closed.
  final Widget Function(BuildContext context, JoinState state, JoinWindow? window) builder;

  @override
  State<JoinWindowBuilder> createState() => _JoinWindowBuilderState();
}

class _JoinWindowBuilderState extends State<JoinWindowBuilder> {
  Timer? _tick;
  JoinState? _shown;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (joinStateOf(widget.windows, widget.clock()).state != _shown) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final at = joinStateOf(widget.windows, widget.clock());
    _shown = at.state;
    return widget.builder(context, at.state, at.window);
  }
}
