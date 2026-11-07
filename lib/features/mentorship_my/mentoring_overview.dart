import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart' show openSitePage, openUrl;
import '../workspaces/page_kit.dart';
import 'mentoring_clock.dart';
import 'mentoring_format.dart';
import 'mentoring_links.dart';
import 'mentoring_models.dart';
import 'my_mentoring_controller.dart';
import 'widgets/kit.dart' show PersonAvatar;

const _cadences = {'WEEKLY': 'Weekly', 'FORTNIGHTLY': 'Every two weeks', 'MONTHLY': 'Monthly', 'ADHOC': 'As needed'};
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// How many goals the card lists, as the website's (`GoalsProgressCard`): the rest are a tap away on each pairing.
const _goalsShown = 4;

/// How far ahead paid calls are read (the website's `PAID_DAYS`).
const _paidDays = 30;

/// "6h", "5h 30m", "45m": the time a mentee has had with their mentors.
String _hours(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

/// Whole calendar days from today: "today", "tomorrow", "in 3 days".
String _inDays(DateTime at) {
  final now = mentoringNow();
  final a = DateTime(at.toLocal().year, at.toLocal().month, at.toLocal().day);
  final b = DateTime(now.year, now.month, now.day);
  final days = a.difference(b).inDays;
  return switch (days) {
    0 => 'today',
    1 => 'tomorrow',
    _ => 'in $days days',
  };
}

String _shortDay(DateTime at) => '${at.toLocal().day} ${_months[at.toLocal().month - 1]}';

/// A call's room opens 15 minutes before it and stays open 30 minutes after it ends (the API's `meetingWindow`).
bool _joinOpen(DateTime at, int durationMin) {
  final now = mentoringNow();
  return !now.isBefore(at.subtract(const Duration(minutes: 15))) &&
      !now.isAfter(at.add(Duration(minutes: durationMin + 30)));
}

/// A session on the mentee's diary: a pairing session or a paid 1:1 call (the website's `MenteeUpcoming`).
class _Upcoming {
  const _Upcoming({
    required this.at,
    required this.durationMin,
    required this.mode,
    this.who,
    this.agenda,
    this.link,
    this.mentorshipId,
    this.purchaseId,
    this.title,
    this.paid = false,
  });

  final DateTime at;
  final int durationMin;
  final String mode;
  final Person? who;
  final String? agenda;
  final String? link;
  final String? mentorshipId;
  final String? purchaseId;
  final String? title;
  final bool paid;
}

/// A mentor the API suggests (`GET /mentorship/mentors/recommended`).
class _Recommended {
  const _Recommended(this.mentorProfileId, this.person, this.matchScore);

  final String mentorProfileId;
  final Person person;
  final double? matchScore;
}

/// What the overview reads beyond the controller: the mentee's paid calls, the API's suggestions and the two
/// matching signals the app's mentee profile does not carry (a target certification, a phone number).
class _Extras {
  const _Extras({this.paid = const [], this.recommended = const [], this.targetCertification, this.hasPhone = false});

  final List<_Upcoming> paid;
  final List<_Recommended> recommended;
  final String? targetCertification;
  final bool hasPhone;
}

/// My mentoring's first tab, redesigned (Nov 2026) as the website's mentee overview (`MenteeOverview`): the numbers
/// at a glance, what needs the member, the people mentoring them, what is next, the goals they are working towards,
/// their matching profile, plans, suggested and saved mentors. Only the mentee side is read: since 31 Oct 2026 the
/// website keeps a mentor's own people and requests on Engagements, which a mentor reaches from here.
class MentoringOverview extends StatefulWidget {
  const MentoringOverview({
    super.key,
    required this.controller,
    required this.links,
    required this.onOpenPairing,
    required this.onSelectTab,
  });

  final MyMentoringController controller;
  final MentorshipLinks links;
  final ValueChanged<String> onOpenPairing;
  final ValueChanged<MyTab> onSelectTab;

  @override
  State<MentoringOverview> createState() => _MentoringOverviewState();
}

class _MentoringOverviewState extends State<MentoringOverview> {
  late Future<_Extras> _extras = _loadExtras();

  MyMentoringController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    // What the cards read beyond the first screenful: goals and the mentee's intent, the shortlist, plan terms.
    // After the frame: a load tells the controller's listeners at once, and the screen above is building now.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _c.ensureTab(MyTab.goals);
      _c.saved.ensure();
      _c.book.terms.ensure();
    });
  }

  Future<_Extras> _loadExtras() async {
    final api = _c.repository.api.dio;
    Future<T?> quietly<T>(Future<T> Function() read) async {
      try {
        return await read();
      } catch (_) {
        return null;
      }
    }

    final from = mentoringNow();
    final day = DateTime(from.year, from.month, from.day);
    final results = await Future.wait([
      quietly(
        () => api.get<dynamic>(
          '/mentor-services/bookings/range',
          queryParameters: {
            'from': day.toUtc().toIso8601String(),
            'to': day.add(const Duration(days: _paidDays)).toUtc().toIso8601String(),
          },
        ),
      ),
      quietly(() => api.get<dynamic>('/mentorship/mentors/recommended')),
      quietly(() => api.get<dynamic>('/mentorship/mentees/me')),
      quietly(() => api.get<dynamic>('/users/me/profile')),
    ]);
    List<Map<String, dynamic>> rows(Object? data) {
      if (data is List) return data.whereType<Map<String, dynamic>>().toList();
      if (data is Map && data['data'] is List) return (data['data'] as List).whereType<Map<String, dynamic>>().toList();
      return const [];
    }

    final now = mentoringNow();
    final paid = <_Upcoming>[
      for (final b in rows(results[0]?.data))
        if (b['side'] == 'MENTEE' && b['status'] == 'SCHEDULED')
          if (DateTime.tryParse(b['scheduledAt'] as String? ?? '') case final at? when at.isAfter(now))
            _Upcoming(
              at: at,
              durationMin: (b['durationMin'] as num?)?.toInt() ?? 30,
              mode: b['mode'] as String? ?? 'VIDEO',
              who: b['counterpart'] is Map<String, dynamic>
                  ? _c.repository.personFrom(b['counterpart'] as Map<String, dynamic>)
                  : null,
              link: b['meetingLink'] as String?,
              purchaseId: b['purchaseId'] as String?,
              title: b['title'] as String?,
              paid: true,
            ),
    ];
    final recommended = <_Recommended>[
      for (final m in rows(results[1]?.data))
        if (m['id'] is String)
          _Recommended(
            m['id'] as String,
            _c.repository.personFrom(
              m['user'] as Map<String, dynamic>?,
              subline: (m['headline'] as String?)?.trim().isEmpty ?? true ? null : m['headline'] as String,
            ),
            (m['matchScore'] as num?)?.toDouble(),
          ),
    ];
    final mentee = results[2]?.data;
    final me = results[3]?.data;
    final user = me is Map && me['user'] is Map ? me['user'] as Map : me;
    return _Extras(
      paid: paid,
      recommended: recommended,
      targetCertification: mentee is Map ? mentee['targetCertification'] as String? : null,
      hasPhone: user is Map && ((user['phone'] as String?)?.trim().isNotEmpty ?? false),
    );
  }

  Future<void> _refresh() async {
    final extras = _loadExtras();
    setState(() {
      _extras = extras;
    });
    await Future.wait([_c.refresh(), _c.goals.load(), _c.intent.load(), _c.saved.load(), _c.book.terms.load(), extras]);
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final loading = !c.pairings.loaded && c.pairings.loading;
    return FutureBuilder<_Extras>(
      future: _extras,
      builder: (context, snap) {
        final extras = snap.data ?? const _Extras();
        return WsScroll(
          loading: loading,
          error: c.pairings.error,
          errorTitle: "Couldn't load your mentoring",
          onRefresh: _refresh,
          children: loading || (c.pairings.error != null && !c.pairings.loaded) ? const [] : _sections(context, extras),
        );
      },
    );
  }

  List<Widget> _sections(BuildContext context, _Extras extras) {
    final c = _c;
    final now = mentoringNow();
    final mine = [
      for (final p in c.livePairings)
        if (!p.viewerIsMentor) p,
    ];
    final mineIds = {for (final p in mine) p.id};
    final goals = [
      for (final g in c.goals.data ?? const <PairingGoal>[])
        if (mineIds.contains(g.mentorshipId) && g.status != GoalStatus.dropped) g,
    ];
    final achieved = goals.where((g) => g.status == GoalStatus.achieved).length;
    final terms = [
      for (final t in c.book.terms.data ?? const <PlanTerm>[])
        if (t.status == 'ACTIVE') t,
    ];
    final sessions = <_Upcoming>[
      for (final s in c.upcoming.data ?? const <PairingSession>[])
        if (s.upcoming(now) && s.viewerIsMentor != true && mineIds.contains(s.mentorshipId))
          _Upcoming(
            at: s.scheduledAt,
            durationMin: s.durationMin,
            mode: s.mode,
            who: s.counterpart,
            agenda: s.agenda,
            link: s.meetingLink,
            mentorshipId: s.mentorshipId,
          ),
      ...extras.paid,
    ]..sort((a, b) => a.at.compareTo(b.at));
    final finished = c.finishedPairings.where((p) => !p.viewerIsMentor).toList();

    // Someone who only mentors: the website sends them to Engagements, so this page is the way there.
    if (c.actsAsMentor && !c.actsAsMentee) return [?_needs(context, sessions), _engagements(context)];

    return [
      _glance(mine, goals, achieved, sessions),
      ?_needs(context, sessions),
      _mentors(context, mine, terms, sessions),
      _upNext(context, sessions),
      _goals(goals, achieved, mine),
      ?_matching(extras),
      if (terms.any((t) => t.sessionsAllowance > 0)) _plans(terms),
      if (extras.recommended.isNotEmpty) _recommended(context, extras.recommended),
      if (c.saved.data?.isNotEmpty ?? false) _saved(context, c.saved.data!),
      if (finished.isNotEmpty) _past(context, finished),
      if (c.actsAsMentor) _engagements(context),
    ];
  }

  // --- At a glance -------------------------------------------------------------------------------------------------

  Widget _glance(List<Pairing> mine, List<PairingGoal> goals, int achieved, List<_Upcoming> sessions) {
    final c = _c;
    final pending = c.pendingSent.length;
    final held = mine.fold<int>(0, (n, p) => n + p.sessionsCount);
    final minutes = mine.fold<int>(0, (n, p) => n + p.totalMinutes);
    final open = goals.length - achieved;
    final next = sessions.isEmpty ? null : sessions.first;
    final nextAt = next?.at.toLocal();
    return WsSection(
      title: 'At a glance',
      children: [
        WsKpiGrid(
          items: [
            WsKpi(
              key: const ValueKey('kpi-mentors'),
              label: 'Active mentors',
              value: '${mine.length}',
              icon: LucideIcons.users,
              sub: pending > 0 ? '${countLabel(pending, 'request')} pending' : 'no requests waiting',
            ),
            WsKpi(
              key: const ValueKey('kpi-sessions'),
              label: 'Sessions completed',
              value: '$held',
              icon: LucideIcons.circleCheck,
              sub: held == 0 ? 'none yet — book the first' : '${_hours(minutes)} with your mentors',
            ),
            WsKpi(
              key: const ValueKey('kpi-goals'),
              label: 'Goals achieved',
              value: c.goals.loaded ? '$achieved' : '—',
              suffix: c.goals.loaded && goals.isNotEmpty ? '/ ${goals.length}' : null,
              meter: goals.isNotEmpty ? achieved / goals.length : null,
              icon: LucideIcons.target,
              sub: open > 0 ? '$open in progress' : 'nothing outstanding',
            ),
            WsKpi(
              key: const ValueKey('kpi-next'),
              label: 'Next session',
              value: nextAt == null ? '—' : '${_weekdays[nextAt.weekday - 1]} ${nextAt.day}',
              suffix: nextAt == null ? null : _months[nextAt.month - 1],
              icon: LucideIcons.calendarClock,
              sub: next == null
                  ? 'nothing booked'
                  : next.who == null
                  ? timeLabel(next.at)
                  : '${timeLabel(next.at)} · with ${next.who!.firstName}',
              warn: next == null,
            ),
          ],
        ),
      ],
    );
  }

  // --- Needs you ---------------------------------------------------------------------------------------------------

  Widget? _needs(BuildContext context, List<_Upcoming> sessions) {
    final c = _c;
    final now = mentoringNow();
    final today = [
      for (final s in sessions)
        if (!s.paid && s.at.toLocal().day == now.day && s.at.difference(now).inHours < 24) s,
    ];
    final rows = <Widget>[
      if (c.pendingSent.isNotEmpty)
        _need(
          icon: LucideIcons.hourglass,
          text: '${countLabel(c.pendingSent.length, 'request')} waiting',
          action: 'Review',
          onTap: () => widget.onSelectTab(MyTab.requests),
        ),
      for (final s in today.take(2))
        _need(
          icon: LucideIcons.calendarClock,
          text: 'Session with ${s.who?.firstName ?? 'your mentor'} today, ${timeLabel(s.at)}',
          action: 'Open',
          onTap: () => widget.onOpenPairing(s.mentorshipId!),
        ),
      if (c.actsAsMentor && c.pendingReceived.isNotEmpty)
        _need(
          icon: LucideIcons.inbox,
          text: '${countLabel(c.pendingReceived.length, 'mentoring request')} awaiting your response',
          action: 'Review',
          onTap: () => _openEngagements(context),
        ),
    ];
    if (rows.isEmpty) return null;
    return WsSection(
      key: const ValueKey('needs-you'),
      title: 'Needs you',
      children: [WsRows(children: rows)],
    );
  }

  Widget _need({required IconData icon, required String text, required String action, required VoidCallback onTap}) =>
      WsRow(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 10),
        leading: WsIconDot(icon: icon, tone: WsTone.warn, size: 34),
        title: text,
        trailing: WsLink(label: action, onTap: onTap),
      );

  // --- My mentors --------------------------------------------------------------------------------------------------

  Widget _mentors(BuildContext context, List<Pairing> mine, List<PlanTerm> terms, List<_Upcoming> sessions) {
    return WsSection(
      key: const ValueKey('my-mentors'),
      title: 'My mentors',
      note: mine.isEmpty ? null : '${mine.length} active',
      action: mine.isEmpty ? null : 'Find another',
      onAction: () => widget.links.directory(context),
      children: [
        if (mine.isEmpty)
          WsEmpty(
            icon: LucideIcons.handshake,
            title: 'No mentor yet',
            body: 'Ask a mentor to guide you. Most replies come within a few days.',
            action: 'Find a mentor',
            onAction: () => widget.links.directory(context),
          )
        else
          WsRows(
            children: [
              for (final p in mine)
                _MentorRow(
                  pairing: p,
                  term: terms.where((t) => t.mentorshipId == p.id).firstOrNull,
                  next: sessions.where((s) => s.mentorshipId == p.id).firstOrNull,
                  onOpen: () => widget.onOpenPairing(p.id),
                  onMentor: () => widget.links.mentor(context, p.mentorProfileId),
                  onMessage: () => widget.links.messagePairing(context, _c.repository, p.id),
                ),
            ],
          ),
      ],
    );
  }

  // --- Up next -----------------------------------------------------------------------------------------------------

  Widget _upNext(BuildContext context, List<_Upcoming> sessions) {
    return WsSection(
      key: const ValueKey('up-next'),
      title: 'Up next',
      action: 'View calendar',
      onAction: () => widget.onSelectTab(MyTab.calendar),
      children: [
        if (sessions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text('Nothing booked. Your mentor confirms a time once you ask for one.', style: WsText.body),
          )
        else
          WsRows(
            indent: 58,
            children: [
              for (var i = 0; i < sessions.length && i < 3; i++) _session(context, sessions[i], first: i == 0),
            ],
          ),
      ],
    );
  }

  Widget _session(BuildContext context, _Upcoming s, {required bool first}) {
    final who = s.who?.name;
    final link = meetingUri(s.link);
    final open = s.paid ? () => widget.onSelectTab(MyTab.purchases) : () => widget.onOpenPairing(s.mentorshipId!);
    return WsRow(
      onTap: open,
      leading: WsDateTile(at: s.at, highlight: first),
      title: s.paid ? (s.title ?? 'Paid session') : (who == null ? 'Session' : '1:1 with $who'),
      subtitle: '${timeLabel(s.at)} · ${s.durationMin} min · ${modeLabel(s.mode)} · ${_inDays(s.at)}',
      meta: s.agenda != null && s.agenda!.trim().isNotEmpty
          ? 'Agenda: ${s.agenda!.trim()}'
          : s.paid
          ? (who == null ? null : 'With $who')
          : 'No agenda yet — add one so your mentor can prepare',
      trailing: s.paid ? const WsChip('Paid', tone: WsTone.brand) : null,
      below: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (link != null && _joinOpen(s.at, s.durationMin))
            WsButton(label: 'Join call', icon: LucideIcons.video, filled: true, onPressed: () => openUrl(context, link))
          else if (link == null && s.mode == 'VIDEO')
            Text('Link not shared yet', style: WsText.meta),
          WsButton(label: 'Details', onPressed: open),
        ],
      ),
    );
  }

  // --- Development goals -------------------------------------------------------------------------------------------

  Widget _goals(List<PairingGoal> goals, int achieved, List<Pairing> mine) {
    final rows = [...goals]
      ..sort((a, b) {
        final ad = a.status == GoalStatus.achieved;
        final bd = b.status == GoalStatus.achieved;
        return ad == bd ? 0 : (ad ? 1 : -1);
      });
    final open = goals.length - achieved;
    final average = goals.isEmpty ? 0 : (goals.fold<int>(0, (n, g) => n + g.progress) / goals.length).round();
    return WsSection(
      key: const ValueKey('development-goals'),
      title: 'Development goals',
      note: goals.isEmpty ? null : '$achieved of ${goals.length} achieved',
      action: mine.isEmpty ? null : 'Add goal',
      onAction: mine.isEmpty ? null : () => widget.onOpenPairing(mine.first.id),
      children: [
        if (goals.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              'Nothing agreed yet. A goal is what the two of you are actually working towards — set one on any '
              'mentorship.',
              style: WsText.body,
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 12),
            child: Row(
              children: [
                WsRing(
                  value: achieved / goals.length,
                  center: Text('${(achieved * 100 / goals.length).round()}%', style: WsText.title),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _legend(WsColors.good, 'Achieved', '$achieved'),
                      const SizedBox(height: 6),
                      _legend(const Color(0xFFC9DAEE), 'In progress', '$open'),
                      const SizedBox(height: 6),
                      _legend(AppColors.primary, 'Average progress', '$average%'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const WsDivider(),
          WsRows(indent: 34, children: [for (final g in rows.take(_goalsShown)) _goal(g)]),
        ],
      ],
    );
  }

  Widget _legend(Color color, String label, String value) => Row(
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 8),
      Expanded(child: Text(label, style: WsText.body)),
      Text(value, style: WsText.bodyStrong),
    ],
  );

  Widget _goal(PairingGoal g) {
    final done = g.status == GoalStatus.achieved;
    final who = g.counterpartName == null ? null : 'With ${g.counterpartName!.split(' ').first}';
    final line = [?who, if (g.targetDate != null) 'target ${_shortDay(g.targetDate!)}'].join(' · ');
    return WsRow(
      onTap: () => widget.onOpenPairing(g.mentorshipId),
      leading: Padding(
        padding: const EdgeInsets.only(top: 1),
        child: done
            ? const WsIconDot(icon: LucideIcons.check, tone: WsTone.good, size: 22)
            : const WsIconDot(icon: LucideIcons.target, tone: WsTone.grey, size: 22),
      ),
      title: g.title,
      subtitle: line.isEmpty ? null : line,
      below: done ? null : WsBar(value: g.progress / 100),
      trailing: done
          ? const WsChip('Achieved', tone: WsTone.good)
          : Text('${g.progress}%', style: WsText.title.copyWith(color: AppColors.primary)),
    );
  }

  // --- Your matching profile ---------------------------------------------------------------------------------------

  /// The six signals mentors are matched on, as the website counts them (`signalsFor`).
  Widget? _matching(_Extras extras) {
    final intent = _c.intent;
    if (!intent.loaded) return null;
    final p = intent.data;
    final signals = <(String, bool)>[
      ('Career stage', p != null && p.careerStage.isNotEmpty),
      ('Mentoring goals', p != null && p.focusAreas.isNotEmpty),
      ('Target certification', extras.targetCertification?.trim().isNotEmpty ?? false),
      ('Meeting frequency', p?.cadence?.isNotEmpty ?? false),
      ('Your objective, in your own words', p?.goalSummary?.trim().isNotEmpty ?? false),
      ('Phone number', extras.hasPhone),
    ];
    final done = signals.where((s) => s.$2).length;
    final strength = (done * 100 / signals.length).round();
    final missing = [
      for (final s in signals)
        if (!s.$2) s.$1,
    ];
    return WsSection(
      key: const ValueKey('matching-profile'),
      title: 'Your matching profile',
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('$strength%', style: WsText.big),
            const SizedBox(width: 10),
            Expanded(child: Text('$done of ${signals.length} signals mentors match on', style: WsText.body)),
          ],
        ),
        const SizedBox(height: 8),
        WsBar(value: strength / 100, color: strength >= 80 ? WsColors.good : AppColors.primary),
        const SizedBox(height: 12),
        if (missing.isEmpty)
          Text('Every signal mentors match on is filled in.', style: WsText.body)
        else ...[
          Text('Still missing', style: WsText.bodyStrong),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [for (final m in missing) WsChip(m, icon: LucideIcons.plus)]),
        ],
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: WsButton(
            label: missing.isEmpty ? 'Edit goals' : 'Finish in My goals',
            onPressed: () => widget.onSelectTab(MyTab.goals),
          ),
        ),
      ],
    );
  }

  // --- Your plans --------------------------------------------------------------------------------------------------

  Widget _plans(List<PlanTerm> terms) {
    return WsSection(
      key: const ValueKey('your-plans'),
      title: 'Your plans',
      footer: 'See purchases',
      onFooter: () => widget.onSelectTab(MyTab.purchases),
      children: [
        WsRows(
          children: [
            for (final t in terms.where((t) => t.sessionsAllowance > 0))
              WsRow(
                leading: const WsIconDot(icon: LucideIcons.layers),
                title: t.title,
                subtitle: [
                  'with ${t.counterpart?.name ?? 'your mentor'}',
                  if (t.periodEnd != null) 'use by ${_shortDay(t.periodEnd!)}',
                ].join(' · '),
                below: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text('Sessions left', style: WsText.meta)),
                        Text('${t.sessionsLeft} of ${t.sessionsAllowance}', style: WsText.bodyStrong),
                      ],
                    ),
                    const SizedBox(height: 4),
                    WsBar(value: t.sessionsLeft / t.sessionsAllowance),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  // --- Recommended, saved, past ------------------------------------------------------------------------------------

  Widget _recommended(BuildContext context, List<_Recommended> mentors) {
    return WsSection(
      key: const ValueKey('recommended'),
      title: 'Recommended for you',
      footer: 'Browse all mentors',
      onFooter: () => widget.links.directory(context),
      children: [
        WsRows(
          indent: 54,
          children: [
            for (final m in mentors.take(3))
              WsRow(
                onTap: () => widget.links.mentor(context, m.mentorProfileId),
                leading: PersonAvatar(person: m.person, size: 42),
                title: m.person.name,
                subtitle: m.person.subline,
                trailing: m.matchScore == null ? null : WsChip('${m.matchScore!.round()}% match', tone: WsTone.good),
              ),
          ],
        ),
      ],
    );
  }

  Widget _saved(BuildContext context, List<SavedMentor> saved) {
    return WsSection(
      key: const ValueKey('saved-mentors'),
      title: 'Saved mentors',
      footer: 'See all saved',
      onFooter: () => widget.onSelectTab(MyTab.saved),
      children: [
        WsRows(
          indent: 54,
          children: [
            for (final m in saved.take(3))
              WsRow(
                onTap: () => widget.links.mentor(context, m.mentorProfileId),
                leading: PersonAvatar(person: m.person, size: 42),
                title: m.person.name,
                subtitle: m.headline,
                trailing: const Icon(LucideIcons.bookmark, size: 18, color: AppColors.primary),
              ),
          ],
        ),
      ],
    );
  }

  Widget _past(BuildContext context, List<Pairing> finished) {
    return WsSection(
      key: const ValueKey('past-mentorships'),
      title: 'Past mentorships',
      note: '${finished.length}',
      children: [
        WsRows(
          indent: 54,
          children: [
            for (final p in finished)
              WsRow(
                onTap: () => widget.onOpenPairing(p.id),
                leading: PersonAvatar(person: p.mentor, size: 42),
                title: p.mentor.name,
                subtitle: [
                  countLabel(p.sessionsCount, 'session'),
                  if (p.completedAt != null) 'finished ${_shortDay(p.completedAt!)}',
                ].join(' · '),
                trailing: WsChip(p.status.label),
              ),
          ],
        ),
      ],
    );
  }

  // --- A mentor's own side -----------------------------------------------------------------------------------------

  /// The people the member mentors, each opening its pairing, and the way to Engagements (the website's mentor
  /// dashboard, `?tab=work`), where everything asked of them as a mentor is answered.
  Widget _engagements(BuildContext context) {
    final waiting = _c.pendingReceived.length;
    final mentees = [
      for (final p in _c.livePairings)
        if (p.viewerIsMentor) p,
    ];
    return WsSection(
      key: const ValueKey('engagements'),
      title: 'Your mentees',
      note: mentees.isEmpty ? null : '${mentees.length} active',
      children: [
        WsRows(
          indent: 54,
          children: [
            for (final p in mentees)
              WsRow(
                onTap: () => widget.onOpenPairing(p.id),
                leading: PersonAvatar(person: p.mentee, size: 42),
                title: p.mentee.name,
                subtitle: p.mentee.subline,
                meta: '${countLabel(p.sessionsCount, 'session')} · since ${_shortDay(p.startedAt)}',
                trailing: p.status == PairingStatus.active ? null : WsChip(p.status.label, tone: WsTone.warn),
              ),
            WsRow(
              leading: const WsIconDot(icon: LucideIcons.briefcaseBusiness, size: 42),
              title: waiting > 0 ? '${countLabel(waiting, 'request')} waiting on you' : 'Engagements',
              subtitle:
                  'Requests asked of you — to mentor someone, for a session or for a programme — are on Engagements, '
                  'under Action needed.',
              below: Align(
                alignment: Alignment.centerLeft,
                child: WsButton(label: 'Open Engagements', filled: true, onPressed: () => _openEngagements(context)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _openEngagements(BuildContext context) => openSitePage(context, '/mentorship/mentor?tab=work');
}

/// One mentor (the website's `MyMentorRow`): who they are, what this pairing is (a programme or free mentoring),
/// how far through it the member is, and what comes next, with Message and Open.
class _MentorRow extends StatelessWidget {
  const _MentorRow({
    required this.pairing,
    required this.onOpen,
    required this.onMentor,
    required this.onMessage,
    this.term,
    this.next,
  });

  final Pairing pairing;
  final PlanTerm? term;
  final _Upcoming? next;
  final VoidCallback onOpen;
  final VoidCallback onMentor;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context) {
    final p = pairing;
    final t = term;
    final allowance = t?.sessionsAllowance ?? 0;
    final used = t == null ? 0 : t.sessionsUsed.clamp(0, allowance);
    final step = t?.steps.where((s) => s.isNext).firstOrNull;
    final about = next?.agenda?.trim().isNotEmpty ?? false ? next!.agenda!.trim() : null;
    final nextLine = next != null
        ? 'Next: ${_weekdays[next!.at.toLocal().weekday - 1]} ${_shortDay(next!.at)}, ${timeLabel(next!.at)}'
              '${about == null ? '' : ' — $about'}'
        : step != null
        ? 'Next step: ${step.title}${t?.periodEnd == null ? '' : ' · use by ${_shortDay(t!.periodEnd!)}'}'
        : 'No session booked yet — open the mentorship to book one';
    final chips = <Widget>[
      if (t == null) const WsChip('Free mentorship', tone: WsTone.brand),
      if (t == null && _cadences[p.cadence] != null) WsChip(_cadences[p.cadence]!),
      if (p.status != PairingStatus.active) WsChip(p.status.label, tone: WsTone.warn),
    ];
    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: onMentor,
                  child: PersonAvatar(person: p.mentor, size: 48),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // A programme's title leads; a free pairing has none, so the mentor does.
                      Text(
                        t?.title ?? p.mentor.name,
                        style: WsText.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        t == null ? (p.mentor.subline ?? '') : 'with ${p.mentor.name}',
                        style: WsText.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (chips.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(spacing: 6, runSpacing: 6, children: chips),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (t != null && allowance > 0) ...[
              Row(
                children: [
                  Expanded(child: Text('Sessions used', style: WsText.meta)),
                  Text('$used of $allowance', style: WsText.bodyStrong),
                ],
              ),
              const SizedBox(height: 4),
              WsBar(value: used / allowance),
            ] else
              Text('${countLabel(p.sessionsCount, 'session')} · since ${_shortDay(p.startedAt)}', style: WsText.meta),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(color: WsColors.page, borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  Icon(LucideIcons.calendarDays, size: 15, color: next != null ? WsColors.good : AppColors.outline),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(nextLine, style: WsText.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: WsButton(
                    label: 'Message',
                    icon: LucideIcons.messageSquare,
                    expand: true,
                    onPressed: onMessage,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: WsButton(label: 'Open', filled: true, expand: true, onPressed: onOpen),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
