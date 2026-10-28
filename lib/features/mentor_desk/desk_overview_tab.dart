import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart';
import '../mentorship_my/mentoring_format.dart';
import '../mentorship_my/mentoring_links.dart';
import '../mentorship_my/mentoring_models.dart';
import '../mentorship_my/widgets/blocks.dart';
import '../mentorship_my/widgets/kit.dart';
import 'mentor_desk_controller.dart';
import 'mentor_desk_models.dart';

/// The first tab: how the mentor stands (mentees, places, requests, rating), what needs them, what is
/// next, whether they are listed, how complete the profile is, and what happened lately.
class OverviewTab extends StatelessWidget {
  const OverviewTab({
    super.key,
    required this.controller,
    required this.links,
    required this.onSelectTab,
    required this.onOpenPairing,
    this.onBecomeMentor,
  });

  final MentorDeskController controller;
  final MentorshipLinks links;
  final ValueChanged<DeskTab> onSelectTab;
  final ValueChanged<String> onOpenPairing;

  /// "Review my profile": where a paused mentor looks after their application.
  final void Function(BuildContext context)? onBecomeMentor;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final d = c.dashboard.data;
    final loading = d == null && c.dashboard.loading;
    final failed = d == null ? c.dashboard.error : null;
    final profile = d?.profile;
    final asks = _sessionAsks();
    final needs = <NeedItem>[
      if (c.freeRequests.isNotEmpty)
        NeedItem(
          icon: LucideIcons.inbox,
          text: '${countLabel(c.freeRequests.length, 'mentoring request')} to answer',
          onTap: () => onSelectTab(DeskTab.requests),
        ),
      if (c.sessionRequests.isNotEmpty)
        NeedItem(
          icon: LucideIcons.calendarPlus,
          text: '${countLabel(c.sessionRequests.length, 'session request')} to accept or decline',
          onTap: () => onSelectTab(DeskTab.requests),
        ),
      if (c.programmeRequests.isNotEmpty)
        NeedItem(
          icon: LucideIcons.layers,
          text: '${countLabel(c.programmeRequests.length, 'programme request')} to answer',
          onTap: () => onSelectTab(DeskTab.requests),
        ),
      if (asks.isNotEmpty)
        NeedItem(
          icon: LucideIcons.calendarClock,
          text: '${countLabel(asks.length, 'time')} your mentees asked for to approve',
          onTap: () => onOpenPairing(asks.first.mentorshipId),
        ),
      if (c.issues.isNotEmpty)
        NeedItem(
          icon: LucideIcons.triangleAlert,
          text: '${countLabel(c.issues.length, 'problem')} a buyer reported',
          onTap: () => onSelectTab(DeskTab.work),
          tone: PillTone.red,
        ),
      if (c.endedCalls.isNotEmpty)
        NeedItem(
          icon: LucideIcons.circleCheck,
          text: '${countLabel(c.endedCalls.length, 'paid call')} to confirm held',
          onTap: () => onSelectTab(DeskTab.work),
        ),
      if (c.moveRequests.isNotEmpty)
        NeedItem(
          icon: LucideIcons.calendarClock,
          text: '${countLabel(c.moveRequests.length, 'move')} asked of you',
          onTap: () => onSelectTab(DeskTab.work),
        ),
    ];
    final next = _next();
    return LoadedList(
      loading: loading,
      error: failed,
      errorTitle: "Couldn't load your desk",
      onRefresh: c.refresh,
      children: loading || failed != null || d == null
          ? const []
          : [
              if (profile?.status == DeskStatus.paused)
                Callout(
                  tone: PillTone.amber,
                  text:
                      'Your profile is paused: it is out of the directory and takes no new requests. '
                      'You keep serving the mentees you have.',
                  actions: [
                    if (onBecomeMentor != null)
                      QuietButton(label: 'Review my profile', onPressed: () => onBecomeMentor!(context)),
                  ],
                ),
              StatStrip(
                tiles: [
                  ('${d.menteesActive}', 'Active mentees'),
                  (d.capacityTotal == 0 ? '0' : '${d.capacityOpen} of ${d.capacityTotal}', 'Places open'),
                  ('${c.requestCount}', 'To answer'),
                ],
              ),
              StatStrip(
                tiles: [
                  (
                    profile == null || profile.ratingCount == 0 ? '-' : profile.rating.toStringAsFixed(1),
                    profile == null || profile.ratingCount == 0
                        ? 'No reviews yet'
                        : countLabel(profile.ratingCount, 'review'),
                  ),
                  ('${profile?.menteesHelped ?? 0}', 'Mentees helped'),
                  (d.answeredThisMonth == 0 ? '-' : '${d.acceptRatePct}%', 'Accepted this month'),
                ],
              ),
              if (d.capacityTotal > 0 && d.capacityOpen == 0 && c.freeRequests.isNotEmpty)
                Callout(
                  tone: PillTone.amber,
                  text:
                      'All ${d.capacityTotal} of your places are taken. You cannot accept another mentee until one frees up '
                      'or you raise your places under Settings.',
                  actions: [QuietButton(label: 'Open Settings', onPressed: () => onSelectTab(DeskTab.settings))],
                ),
              NeedsYouCard(items: needs, clear: 'Nothing is waiting on you.'),
              if (next != null) ...[
                const SectionTitle(title: 'Up next', top: 6),
                MentoringCard(
                  key: const ValueKey('up-next'),
                  onTap: () => onOpenPairing(next.mentorshipId),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(whenLabel(next.scheduledAt), style: MentoringText.cardTitle)),
                          StatusPill(daysFromNow(next.scheduledAt, now: c.now), tone: PillTone.mint),
                        ],
                      ),
                      MetaLine(
                        icon: LucideIcons.user,
                        text:
                            '${next.counterpart?.name ?? 'Your mentee'} · ${minutesLabel(next.durationMin)} · ${modeLabel(next.mode)}',
                      ),
                      if (next.agenda != null && next.agenda!.isNotEmpty)
                        MetaLine(icon: LucideIcons.notebookPen, text: next.agenda!),
                      if (meetingUri(next.meetingLink) != null)
                        ActionWrap(
                          children: [
                            SolidButton(
                              label: 'Join',
                              icon: LucideIcons.video,
                              onPressed: () => openUrl(context, meetingUri(next.meetingLink)!),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
              const SectionTitle(title: 'In the directory'),
              _Visibility(controller: c, dashboard: d),
              const SectionTitle(title: 'Your profile'),
              _Completeness(dashboard: d, links: links),
              if (d.recentActivity.isNotEmpty) ...[
                const SectionTitle(title: 'Lately'),
                for (final e in d.recentActivity.take(5))
                  Padding(
                    key: ValueKey('activity-${e.id}'),
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.only(top: 6, right: 10),
                          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.label, style: MentoringText.bodyStrong),
                              Text(whenLabel(e.createdAt), style: MentoringText.meta),
                              if (e.note != null) Text(e.note!, style: MentoringText.body),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
    );
  }

  /// Sessions mentees asked for inside a pairing, waiting on the mentor.
  List<PairingSession> _sessionAsks() => [
    for (final s in controller.mentoring.upcoming.data ?? const <PairingSession>[])
      if (s.status == SessionStatus.requested && (s.viewerIsMentor ?? false)) s,
  ];

  /// The next scheduled session across every mentee.
  PairingSession? _next() {
    final rows = [
      for (final s in controller.mentoring.upcoming.data ?? const <PairingSession>[])
        if (s.status == SessionStatus.scheduled && s.upcoming(controller.now)) s,
    ]..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return rows.firstOrNull;
  }
}

class _Visibility extends StatelessWidget {
  const _Visibility({required this.controller, required this.dashboard});

  final MentorDeskController controller;
  final DeskDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final profile = dashboard.profile!;
    final paused = profile.status == DeskStatus.paused;
    return MentoringCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Listed in the directory', style: MentoringText.cardTitle)),
              StatusPill(
                dashboard.isListed ? 'Listed' : 'Not listed',
                tone: dashboard.isListed ? PillTone.mint : PillTone.grey,
              ),
            ],
          ),
          const SizedBox(height: 4),
          SwitchListTile.adaptive(
            key: const ValueKey('visibility-switch'),
            contentPadding: EdgeInsets.zero,
            value: profile.discoverable,
            onChanged: paused
                ? null
                : (v) async {
                    final refusal = await controller.setVisibility(v);
                    if (context.mounted) {
                      showMessage(context, refusal ?? (v ? 'You are listed again.' : 'Hidden from the directory.'));
                    }
                  },
            title: Text('Let members find me', style: MentoringText.bodyStrong),
            subtitle: Text(
              profile.discoverable
                  ? (dashboard.isListed
                        ? 'Members can find you and ask for mentoring.'
                        : dashboard.capacityOpen == 0
                        ? 'Switched on, but all your places are taken, so you are not shown.'
                        : 'Switched on.')
                  : 'Switched off: nobody new can find you. Current mentees are not affected.',
              style: MentoringText.meta,
            ),
          ),
        ],
      ),
    );
  }
}

class _Completeness extends StatelessWidget {
  const _Completeness({required this.dashboard, required this.links});

  final DeskDashboard dashboard;
  final MentorshipLinks links;

  @override
  Widget build(BuildContext context) {
    final d = dashboard;
    return MentoringCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Profile completeness', style: MentoringText.cardTitle)),
              Text('${d.completenessScore}%', key: const ValueKey('completeness'), style: MentoringText.statValue),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: d.completenessScore / 100,
              minHeight: 6,
              backgroundColor: AppColors.surfaceContainer,
              color: d.completenessScore >= 100 ? MentoringColors.green : AppColors.primary,
            ),
          ),
          if (d.missing.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Nothing is missing.', style: MentoringText.body),
            )
          else ...[
            const SizedBox(height: 8),
            for (final m in d.missing) MetaLine(icon: LucideIcons.circle, text: m),
            ActionWrap(
              children: [
                QuietButton(
                  label: 'Finish my profile',
                  icon: LucideIcons.externalLink,
                  onPressed: () => links.openSite(context, '/profile'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
