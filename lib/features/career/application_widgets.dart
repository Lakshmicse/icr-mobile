import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../jobs/job_links.dart';
import '../jobs/widgets/job_row.dart';
import 'application_logic.dart';
import 'career_format.dart';
import 'career_models.dart';
import 'career_styles.dart';
import 'career_widgets.dart';

/// The pill each status wears.
PillTone toneOf(AppStatus s) => switch (s) {
  AppStatus.applied => PillTone.neutral,
  AppStatus.viewed || AppStatus.inReview || AppStatus.interviewing => PillTone.brand,
  AppStatus.offer => PillTone.warning,
  AppStatus.hired => PillTone.success,
  AppStatus.notSelected => PillTone.danger,
  AppStatus.offerDeclined || AppStatus.withdrawn => PillTone.neutral,
};

/// "Round 2 • Mon 27 Oct, 11:00 AM • Video call".
String interviewLine(CareerInterview iv) =>
    ['Round ${iv.round}', formatWhen(iv.scheduledAt), iv.mode.label].join(' • ');

/// "₹24,00,000 a year".
String offerAmount(CareerOffer o) {
  final per = switch (o.period) {
    'MONTHLY' => 'a month',
    'HOURLY' => 'an hour',
    _ => 'a year',
  };
  return '${formatMoney(o.salaryAmount, currency: o.currency)} $per';
}

/// "Reply by 31 Oct • 5 days left".
String replyBy(CareerOffer o, DateTime now) {
  final at = o.expiresAt;
  if (at == null) return '';
  final days = daysUntil(at, now);
  final by = 'Reply by ${formatDay(at, now: now)}';
  if (days < 0) return by;
  return switch (days) {
    0 => '$by • last day',
    1 => '$by • 1 day left',
    _ => '$by • $days days left',
  };
}

/// The five steps an application moves through: a dot each, the done ones filled,
/// the current one ringed, a locked one dashed (the plan hides the viewed receipt).
class ApplicationProgress extends StatelessWidget {
  const ApplicationProgress({super.key, required this.steps});

  final List<ProgressStep> steps;

  @override
  Widget build(BuildContext context) {
    final hired = steps.last.label == 'Hired' && steps.last.state == ProgressState.done;
    return Semantics(
      label: 'Progress: ${steps.where((s) => s.state == ProgressState.current).map((s) => s.label).join()}',
      child: Row(
        key: const ValueKey('progress'),
        children: [
          for (final (i, step) in steps.indexed)
            Expanded(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: i == 0
                            ? const SizedBox(height: 2)
                            : ColoredBox(
                                color: _reached(steps[i - 1].state) && _reached(step.state)
                                    ? _ink(hired)
                                    : AppColors.outlineVariant,
                                child: const SizedBox(height: 2),
                              ),
                      ),
                      _Dot(step: step, hired: hired),
                      Expanded(
                        child: i == steps.length - 1
                            ? const SizedBox(height: 2)
                            : ColoredBox(
                                color: _reached(step.state) && _reached(steps[i + 1].state)
                                    ? _ink(hired)
                                    : AppColors.outlineVariant,
                                child: const SizedBox(height: 2),
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    step.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: CareerText.meta.copyWith(
                      fontSize: 12,
                      color: step.state == ProgressState.current ? AppColors.onSurface : AppColors.outline,
                      fontWeight: step.state == ProgressState.current ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  if (step.at != null && step.state != ProgressState.todo)
                    Text(formatDay(step.at!), style: CareerText.meta.copyWith(fontSize: 12, color: AppColors.inkSoft)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static bool _reached(ProgressState s) => s == ProgressState.done || s == ProgressState.current;
  static Color _ink(bool hired) => hired ? AppColors.successInk : AppColors.primary;
}

class _Dot extends StatelessWidget {
  const _Dot({required this.step, required this.hired});

  final ProgressStep step;
  final bool hired;

  @override
  Widget build(BuildContext context) {
    const size = 18.0;
    switch (step.state) {
      case ProgressState.locked:
        return Tooltip(
          message: 'Your plan does not show when a recruiter opens your application.',
          child: Container(
            key: const ValueKey('step-locked'),
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceContainer,
              border: Border.all(color: AppColors.outline),
            ),
            child: const Icon(LucideIcons.lock, size: 10, color: AppColors.outline),
          ),
        );
      case ProgressState.done:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: hired ? AppColors.successInk : AppColors.primary),
          child: const Icon(LucideIcons.check, size: 12, color: Colors.white),
        );
      case ProgressState.current:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary,
            boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), spreadRadius: 3)],
          ),
          child: Center(
            child: Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
            ),
          ),
        );
      case ProgressState.todo:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.slate300, width: 1.5),
          ),
        );
    }
  }
}

/// The offer waiting on the member, on its row: the terms, the reply-by date, Decline and Accept.
class OfferStrip extends StatelessWidget {
  const OfferStrip({super.key, required this.offer, required this.now, required this.onRespond, this.busy = false});

  final CareerOffer offer;
  final DateTime now;
  final void Function(bool accept) onRespond;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final by = replyBy(offer, now);
    final joining = offer.joiningDate;
    return NoteStrip(
      key: const ValueKey('offer-strip'),
      icon: LucideIcons.fileText,
      color: AppColors.amber500,
      actions: [
        StripButton(label: 'Decline', onTap: busy ? null : () => onRespond(false)),
        StripButton(label: 'Accept', filled: true, onTap: busy ? null : () => onRespond(true)),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: 'Offer: ', style: CareerText.bodyStrong),
                TextSpan(text: offerAmount(offer), style: CareerText.bodyStrong),
                if (joining != null)
                  TextSpan(
                    text: ' • joining ${formatDay(joining, now: now)}',
                    style: CareerText.body,
                  ),
              ],
            ),
          ),
          if (by.isNotEmpty)
            Text(
              by,
              style: CareerText.meta.copyWith(color: AppColors.amber800, fontWeight: FontWeight.w700),
            ),
        ],
      ),
    );
  }
}

/// The next round, on its row: when, how, and the way in.
class InterviewStrip extends StatelessWidget {
  const InterviewStrip({super.key, required this.interview, required this.links});

  final CareerInterview interview;
  final JobLinks links;

  @override
  Widget build(BuildContext context) {
    final join = interview.joinUrl;
    final map = interview.mapUrl;
    return NoteStrip(
      key: const ValueKey('interview-strip'),
      icon: LucideIcons.calendarClock,
      color: AppColors.primary,
      actions: [
        if (join != null)
          StripButton(
            label: 'Join call',
            icon: LucideIcons.video,
            filled: true,
            onTap: () => links.openUri(context, join),
          )
        else if (map != null)
          StripButton(label: 'Open in Maps', icon: LucideIcons.mapPin, onTap: () => links.openUri(context, map)),
      ],
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: 'Interview: ', style: CareerText.bodyStrong),
            TextSpan(text: interviewLine(interview), style: CareerText.body),
          ],
        ),
      ),
    );
  }
}

/// One application on the tracker: who and where, how it stands, how far it has come,
/// the one thing it waits on, and its actions.
class ApplicationRow extends StatelessWidget {
  const ApplicationRow({
    super.key,
    required this.app,
    required this.now,
    required this.links,
    required this.onOpen,
    required this.onOpenJob,
    required this.onMessage,
    required this.onWithdraw,
    required this.onRespond,
    this.onFindSimilar,
    this.busy = false,
  });

  final CareerApplication app;
  final DateTime now;
  final JobLinks links;

  /// The row, its title or "View application": the application's own page.
  final VoidCallback onOpen;

  /// "View job" in the menu, and in an ended application's outcome line.
  final VoidCallback onOpenJob;
  final VoidCallback onMessage;
  final VoidCallback onWithdraw;
  final void Function(bool accept) onRespond;

  /// "Find similar jobs" under a "Not selected".
  final VoidCallback? onFindSimilar;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final status = statusOf(app);
    final progress = progressOf(app);
    final next = nextStepOf(app, now);
    final ended = endedAt(app);
    final activity = lastActivityAt(app);
    final updated = activity != app.createdAt && !isArchived(app);
    final where = [?app.companyName, ?app.city].join(' • ');
    final company = JobCompany(id: app.companyId ?? '', name: app.companyName ?? app.jobTitle, logo: app.companyLogo);
    final outcome = switch (status) {
      AppStatus.notSelected =>
        'Not selected${ended == null ? '' : ' • ${formatDay(ended, now: now)}'}. The employer moved ahead with other candidates.',
      AppStatus.withdrawn =>
        'You withdrew this application${ended == null ? '' : ' on ${formatDay(ended, now: now)}'}.',
      AppStatus.offerDeclined => 'You declined this offer${ended == null ? '' : ' on ${formatDay(ended, now: now)}'}.',
      _ => null,
    };

    return Container(
      key: ValueKey('app-${app.id}'),
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.cardRule)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onOpen,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CompanyLogoTile(company: company, width: 48, height: 52),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(app.jobTitle, style: CareerText.cardTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                      if (where.isNotEmpty)
                        Text(where, style: CareerText.companyMeta, maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(
                        [
                          'Applied ${formatDay(app.createdAt, now: now)}',
                          if (app.resumeTitle != null) 'with “${app.resumeTitle}”',
                          if (updated) 'Updated ${_ago(activity, now)}',
                        ].join(' • '),
                        style: CareerText.meta,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              KeyedSubtree(
                key: const ValueKey('application-status'),
                child: StatusPill(status.label, tone: toneOf(status)),
              ),
              if (app.matchScore != null)
                StatusPill(
                  '${app.matchScore}% match',
                  tone: app.matchScore! >= 70
                      ? PillTone.success
                      : app.matchScore! >= 45
                      ? PillTone.brand
                      : PillTone.neutral,
                ),
            ],
          ),
          if (progress != null) ...[const SizedBox(height: 12), ApplicationProgress(steps: progress)],
          if (next != null) ...[
            const SizedBox(height: 10),
            switch (next) {
              OfferStep(:final offer) => OfferStrip(offer: offer, now: now, onRespond: onRespond, busy: busy),
              InterviewStep(:final interview) => InterviewStrip(interview: interview, links: links),
              HiredStep(:final offer) => NoteStrip(
                key: const ValueKey('hired-strip'),
                icon: LucideIcons.circleCheck,
                color: AppColors.successInk,
                child: Text(
                  offer?.respondedAt == null
                      ? 'You were hired for this role.'
                      : 'You accepted this offer on ${formatDay(offer!.respondedAt!, now: now)}.',
                  style: CareerText.body,
                ),
              ),
              ClosedStep() => NoteStrip(
                key: const ValueKey('closed-strip'),
                icon: LucideIcons.circleMinus,
                color: AppColors.outline,
                child: Text(
                  'This job is no longer accepting applications. Yours is still with ${app.companyName ?? 'the employer'}.',
                  style: CareerText.body,
                ),
              ),
            },
          ],
          if (outcome != null) ...[
            const SizedBox(height: 10),
            Row(
              key: const ValueKey('outcome'),
              children: [
                const Icon(LucideIcons.info, size: 15, color: AppColors.outline),
                const SizedBox(width: 6),
                Expanded(child: Text(outcome, style: CareerText.body)),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const ValueKey('outcome-link'),
                onPressed: status == AppStatus.notSelected ? onFindSimilar : onOpenJob,
                child: Text(status == AppStatus.notSelected ? 'Find similar jobs' : 'View job', style: CareerText.link),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton(
                key: const ValueKey('view-application'),
                onPressed: onOpen,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.outlineVariant),
                  visualDensity: VisualDensity.compact,
                  shape: const StadiumBorder(),
                ),
                child: Text('View application', style: CareerText.link),
              ),
              const Spacer(),
              PopupMenuButton<_RowAction>(
                key: const ValueKey('row-menu'),
                tooltip: 'More actions for ${app.jobTitle}',
                icon: const Icon(LucideIcons.ellipsisVertical, size: 18, color: AppColors.onSurfaceVariant),
                onSelected: (a) => switch (a) {
                  _RowAction.job => onOpenJob(),
                  _RowAction.message => onMessage(),
                  _RowAction.withdraw => onWithdraw(),
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _RowAction.job,
                    child: Text('View job', style: AppText.small.copyWith(color: AppColors.onSurface)),
                  ),
                  PopupMenuItem(
                    value: _RowAction.message,
                    child: Text('Message hiring team', style: AppText.small.copyWith(color: AppColors.onSurface)),
                  ),
                  if (canWithdraw(app))
                    PopupMenuItem(
                      value: _RowAction.withdraw,
                      child: Text('Withdraw application', style: AppText.small.copyWith(color: AppColors.error)),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _ago(DateTime at, DateTime now) {
    final d = now.difference(at);
    if (d.inMinutes < 60) return 'just now';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return formatDay(at, now: now);
  }
}

enum _RowAction { job, message, withdraw }
