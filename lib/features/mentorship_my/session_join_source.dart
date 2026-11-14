import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/util/join_window.dart';
import '../messaging/messaging_models.dart';
import '../messaging/widgets/join_session_sheet.dart';
import 'mentoring_clock.dart';
import 'mentoring_format.dart';
import 'mentoring_models.dart';
import 'mentoring_repository.dart';

/// The messaging Join sheet's reader (`MessagingLauncher.sessionJoin`, set in `app.dart`): the thread's booked
/// session from its own record, in the order the thread's meeting card reads them — a booked 1:1 (its purchase),
/// else the pairing's next session, else the group session. Each gives its call's link and its windows by the rules
/// its own page's Join already follows, so the sheet and that page never disagree.
Future<SessionJoin?> loadSessionJoin(BuildContext context, ConversationContext about) =>
    readSessionJoin(MentoringRepository(api: context.read<ApiClient>()), about);

/// [loadSessionJoin] over a given repository and clock.
Future<SessionJoin?> readSessionJoin(
  MentoringRepository repo,
  ConversationContext about, {
  DateTime Function()? clock,
}) async {
  final now = (clock ?? mentoringNow)();

  final k = about.consultation;
  if (k != null && (k.oneOnOne || k.scheduledAt != null)) {
    final found = _fromPurchase(await repo.purchase(k.id), now);
    // A booking already over gives way to the pairing's next session, as the card does.
    if (found.windows.isNotEmpty || (about.mentorship == null && about.groupSession == null)) return found;
  }

  final m = about.mentorship;
  if (m != null) {
    final found = _fromPairing(await repo.sessions(m.id), m.nextSessionAt, now);
    if (found.windows.isNotEmpty || about.groupSession == null) return found;
  }

  final g = about.groupSession;
  if (g != null) return _fromGroup(await repo.groupSession(g.id), now);
  return null;
}

bool _inPerson(String mode) => mode == 'IN_PERSON';

DateTime _end(DateTime start, int minutes) => start.add(Duration(minutes: minutes));

/// A booked 1:1: joinable once it is scheduled and paid (the Purchases tab's rule).
SessionJoin _fromPurchase(ServicePurchase p, DateTime now) {
  final b = p.booking;
  if (b == null || !b.scheduled) return const SessionJoin(note: 'This booking has no confirmed time yet.');
  final window = JoinWindow(b.scheduledAt, b.durationMin);
  if (window.stateAt(now) == JoinState.closed) return const SessionJoin();
  final start = b.scheduledAt;
  final end = _end(start, b.durationMin);
  if (_inPerson(b.mode)) return SessionJoin(windows: [window], inPerson: true, start: start, end: end);
  if (p.status != PurchaseStatus.paid) {
    return SessionJoin(
      windows: [window],
      note: 'Pay for the booking to confirm it. The call opens once it is paid.',
      start: start,
      end: end,
    );
  }
  return SessionJoin(link: meetingUri(b.meetingLink), windows: [window], start: start, end: end);
}

/// A pairing: the scheduled session the thread names as next, else the earliest one still to come.
SessionJoin _fromPairing(List<PairingSession> sessions, DateTime? next, DateTime now) {
  final live =
      sessions
          .where(
            (s) =>
                s.status == SessionStatus.scheduled &&
                JoinWindow(s.scheduledAt, s.durationMin).stateAt(now) != JoinState.closed,
          )
          .toList()
        ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  if (live.isEmpty) return const SessionJoin(note: 'No session is booked yet.');
  final s = next == null
      ? live.first
      : live.firstWhere((s) => s.scheduledAt.isAtSameMomentAs(next), orElse: () => live.first);
  final window = JoinWindow(s.scheduledAt, s.durationMin);
  final end = _end(s.scheduledAt, s.durationMin);
  if (_inPerson(s.mode)) return SessionJoin(windows: [window], inPerson: true, start: s.scheduledAt, end: end);
  return SessionJoin(link: meetingUri(s.meetingLink), windows: [window], start: s.scheduledAt, end: end);
}

/// A group session: every scheduled day of it (its page's "Join Session" reads the same windows).
SessionJoin _fromGroup(GroupSession s, DateTime now) {
  final windows = s.occurrences.isEmpty
      ? [JoinWindow(s.scheduledAt, s.durationMin)]
      : [
          for (final o in s.occurrences)
            if (o.status == 'SCHEDULED') JoinWindow(o.scheduledAt, o.durationMin),
        ];
  final standing = joinStateOf(windows, now);
  if (!s.upcoming || standing.state == JoinState.closed) return const SessionJoin();
  // The day that is open now, else the next to open: its own start and end.
  final day = standing.window!;
  final start = day.opensAt.add(joinOpensBefore);
  final end = day.closesAt.subtract(joinClosesAfter);
  if (_inPerson(s.mode)) return SessionJoin(windows: windows, inPerson: true, start: start, end: end);
  return SessionJoin(
    link: meetingUri(s.meetingLink),
    windows: windows,
    note: s.isHost || s.holdsSeat ? null : 'Reserve a seat to get the call link.',
    start: start,
    end: end,
  );
}
