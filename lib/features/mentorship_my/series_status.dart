import 'widgets/kit.dart' show PillTone;

/// Where a group session series stands, read from its days (owner, 16 Nov 2026: "Completed" when every session is
/// done; "In Progress" once a session has started and before they are all done; "Held" is no longer shown). The
/// mentor's offerings and the member's group sessions both read it, so the two lists say the same thing.
enum SeriesState {
  draft('Draft', PillTone.amber),
  open('Open for Registration', PillTone.mint),
  inProgress('In Progress', PillTone.blue),
  completed('Completed', PillTone.grey),
  cancelled('Cancelled', PillTone.grey);

  const SeriesState(this.label, this.tone);
  final String label;
  final PillTone tone;
}

/// A day of a series: when it starts and its own status (SCHEDULED, COMPLETED or CANCELLED).
typedef SeriesDay = ({DateTime at, String status});

/// The series' state from its own status (DRAFT, SCHEDULED, COMPLETED, CANCELLED) and its days. A scheduled series
/// whose every remaining day is done reads Completed even before the mentor closes it; one with a day done or begun
/// reads In Progress. A cancelled day counts for neither.
SeriesState seriesState(String status, Iterable<SeriesDay> days, DateTime now) {
  switch (status) {
    case 'DRAFT':
      return SeriesState.draft;
    case 'CANCELLED':
      return SeriesState.cancelled;
    case 'COMPLETED':
      return SeriesState.completed;
  }
  final live = [
    for (final d in days)
      if (d.status != 'CANCELLED') d,
  ];
  if (live.isEmpty) return SeriesState.open;
  if (live.every((d) => d.status == 'COMPLETED')) return SeriesState.completed;
  if (live.any((d) => d.status == 'COMPLETED' || !d.at.isAfter(now))) return SeriesState.inProgress;
  return SeriesState.open;
}

/// A single session's own word once it is over: "Completed" (it read "Held" until 16 Nov 2026).
const completedWord = 'Completed';
