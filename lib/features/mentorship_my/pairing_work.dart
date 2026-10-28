import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart';
import 'mentoring_format.dart';
import 'mentoring_links.dart';
import 'mentoring_models.dart';
import 'my_mentoring_tabs.dart' show showCertificateSheet;
import 'pairing_controller.dart';
import 'pairing_forms.dart';
import 'pairing_sessions.dart' show report;
import 'widgets/forms.dart';
import 'widgets/kit.dart';

// ---------------------------------------------------------------------------
// The plan behind the pairing
// ---------------------------------------------------------------------------

/// The programme or plan that paid for this pairing: how many sessions are
/// left of it, and for a programme its syllabus in order.
class PlanSection extends StatelessWidget {
  const PlanSection({super.key, required this.controller});

  final PairingController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final t = c.term;
    if (t == null) return const SizedBox.shrink();
    final left = t.sessionsLeft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title: t.programme ? 'The programme' : 'Your plan', top: 14),
        MentoringCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(t.title, style: MentoringText.cardTitle)),
                  StatusPill(t.statusLabel, tone: t.status == 'ACTIVE' ? PillTone.mint : PillTone.grey),
                ],
              ),
              MetaLine(
                icon: LucideIcons.indianRupee,
                text: '${moneyLabel(t.totalPaisa)}${t.periodEnd == null ? '' : ' · runs to ${dayLabel(t.periodEnd!)}'}',
              ),
              if (t.sessionsAllowance > 0) ...[
                const SizedBox(height: 10),
                Text(
                  sessionsLeft(left, t.sessionsAllowance),
                  key: const ValueKey('plan-left'),
                  style: MentoringText.cardTitle,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    for (var i = 0; i < t.sessionsAllowance && i < 24; i++)
                      Expanded(
                        child: Container(
                          height: 6,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: i < t.sessionsUsed
                                ? (left == 0 ? AppColors.amber500 : MentoringColors.green)
                                : AppColors.surfaceContainer,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'A cancelled session gives its place back; a no-show does not.',
                    style: MentoringText.meta,
                  ),
                ),
              ],
              if (t.cancelAtPeriodEnd)
                const MetaLine(icon: LucideIcons.info, text: 'It will not renew: it ends at the close of this term.'),
              if (c.termIsMine && t.open && !t.programme && !t.cancelAtPeriodEnd && t.status == 'ACTIVE')
                ActionWrap(
                  children: [
                    QuietButton(
                      label: 'Do not renew',
                      onPressed: () => report(context, c.stopRenewing, done: 'It will not renew.'),
                    ),
                  ],
                ),
            ],
          ),
        ),
        if (t.programme && t.steps.isNotEmpty) ...[
          const SizedBox(height: 4),
          for (final s in t.steps)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    s.done ? LucideIcons.circleCheck : (s.booked ? LucideIcons.calendarCheck : LucideIcons.circle),
                    size: 18,
                    color: s.done ? MentoringColors.green : (s.booked ? AppColors.primary : AppColors.outline),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${s.position}. ${s.title}',
                          style: MentoringText.bodyStrong.copyWith(
                            color: s.isNext && !s.booked ? AppColors.primary : null,
                          ),
                        ),
                        Text(
                          s.done
                              ? 'Held'
                              : s.booked
                              ? 'Booked'
                              : (s.isNext ? 'Next to book' : 'Not booked yet'),
                          style: MentoringText.meta,
                        ),
                        if (s.outline != null) Text(s.outline!, style: MentoringText.meta),
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
}

// ---------------------------------------------------------------------------
// Goals and tasks
// ---------------------------------------------------------------------------

class GoalsSection extends StatelessWidget {
  const GoalsSection({super.key, required this.controller});

  final PairingController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          title: 'Goals',
          action: c.live ? 'Add goal' : null,
          onAction: () async {
            final sent = await showFormSheet(context, (_) => GoalForm(controller: c));
            if (sent && context.mounted) showMessage(context, 'Goal added.');
          },
        ),
        if (c.goals.isEmpty)
          Text('No goals yet. A goal is what the two of you are working towards.', style: MentoringText.body),
        for (final g in c.goals) _GoalCard(controller: c, goal: g),
      ],
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.controller, required this.goal});

  final PairingController controller;
  final PairingGoal goal;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final g = goal;
    final open = g.status == GoalStatus.open;
    return MentoringCard(
      child: Column(
        key: ValueKey('goal-${g.id}'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(g.title, style: MentoringText.cardTitle)),
              StatusPill(
                g.status.label,
                tone: switch (g.status) {
                  GoalStatus.achieved => PillTone.mint,
                  GoalStatus.dropped => PillTone.grey,
                  GoalStatus.open => PillTone.blue,
                },
              ),
            ],
          ),
          if (g.detail != null && g.detail!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(g.detail!, style: MentoringText.body),
            ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: g.progress / 100,
              minHeight: 6,
              backgroundColor: AppColors.surfaceContainer,
              color: g.status == GoalStatus.achieved ? MentoringColors.green : AppColors.primary,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${g.progress}%${g.targetDate == null ? '' : ' · by ${dayLabel(g.targetDate!)}'}'
              '${g.createdByName == null || g.createdByName!.isEmpty ? '' : ' · added by ${g.createdByName}'}',
              style: MentoringText.meta,
            ),
          ),
          if (c.live)
            ActionWrap(
              children: [
                if (open)
                  SolidButton(
                    label: 'Achieved',
                    icon: LucideIcons.check,
                    onPressed: () =>
                        report(context, () => c.setGoalStatus(g, GoalStatus.achieved), done: 'Goal achieved.'),
                  ),
                if (open)
                  QuietButton(
                    label: 'Progress',
                    onPressed: () => showFormSheet(context, (_) => ProgressForm(controller: c, goal: g)),
                  ),
                if (open)
                  QuietButton(
                    label: 'Drop',
                    onPressed: () => report(context, () => c.setGoalStatus(g, GoalStatus.dropped)),
                  ),
                if (!open)
                  QuietButton(
                    label: 'Reopen',
                    onPressed: () => report(context, () => c.setGoalStatus(g, GoalStatus.open)),
                  ),
                QuietButton(label: 'Remove', danger: true, onPressed: () => report(context, () => c.removeGoal(g))),
              ],
            ),
        ],
      ),
    );
  }
}

class TasksSection extends StatelessWidget {
  const TasksSection({super.key, required this.controller});

  final PairingController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          title: 'Between sessions',
          action: c.live ? 'Add task' : null,
          onAction: () async {
            final sent = await showFormSheet(context, (_) => TaskForm(controller: c));
            if (sent && context.mounted) showMessage(context, 'Task added.');
          },
        ),
        if (c.tasks.isEmpty)
          Text('Nothing on the list. Agree the next steps after a session.', style: MentoringText.body),
        for (final t in c.tasks)
          Padding(
            key: ValueKey('task-${t.id}'),
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Checkbox(
                  value: t.status == TaskStatus.done,
                  onChanged: c.live && t.status != TaskStatus.dropped
                      ? (_) => report(context, () => c.toggleTask(t))
                      : null,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.title,
                        style: MentoringText.bodyStrong.copyWith(
                          decoration: t.status == TaskStatus.done ? TextDecoration.lineThrough : null,
                          color: t.status == TaskStatus.done ? AppColors.outline : null,
                        ),
                      ),
                      if (t.dueAt != null)
                        Text(
                          '${t.overdue ? 'Overdue · ' : ''}Due ${dayLabel(t.dueAt!)}',
                          style: MentoringText.meta.copyWith(color: t.overdue ? AppColors.error : null),
                        ),
                    ],
                  ),
                ),
                if (t.isMine)
                  IconButton(
                    tooltip: 'Delete task',
                    icon: const Icon(LucideIcons.trash2, size: 16, color: AppColors.outline),
                    onPressed: () => report(context, () => c.deleteTask(t)),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared resources, notes
// ---------------------------------------------------------------------------

/// Links and files the pair share. A file is read with the session's token and handed to the share sheet.
class ResourcesSection extends StatelessWidget {
  const ResourcesSection({super.key, required this.controller, required this.links, this.pickFile = pickShareFile});

  final PairingController controller;
  final MentorshipLinks links;
  final SharePicker pickFile;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          title: 'Shared resources',
          action: c.live ? 'Share a link or file' : null,
          onAction: () async {
            final sent = await showFormSheet(context, (_) => ResourceLinkForm(controller: c, pickFile: pickFile));
            if (sent && context.mounted) showMessage(context, 'Shared.');
          },
        ),
        if (c.resources.isEmpty)
          Text('Nothing shared yet. Links and files you share show up for both of you.', style: MentoringText.body),
        for (final r in c.resources)
          MentoringCard(
            key: ValueKey('resource-${r.id}'),
            padding: const EdgeInsets.all(12),
            onTap: () => _open(context, r),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(r.isUpload ? LucideIcons.fileDown : LucideIcons.link, size: 18, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.title, style: MentoringText.cardTitle),
                      Text(
                        '${r.kindLabel}${r.fileSize == null ? '' : ' · ${fileSizeLabel(r.fileSize!)}'}'
                        '${r.addedByName.isEmpty ? '' : ' · ${r.addedByName}'}',
                        style: MentoringText.meta,
                      ),
                      if (r.note != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(r.note!, style: MentoringText.body),
                        ),
                    ],
                  ),
                ),
                if (r.canRemove)
                  IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(LucideIcons.trash2, size: 16, color: AppColors.outline),
                    onPressed: () => report(context, () => c.removeResource(r), done: 'Removed.'),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  void _open(BuildContext context, SharedResource r) {
    if (r.url == null) return;
    if (r.isUpload) {
      links.download(context, () => controller.download(r), r.fileName ?? r.title);
      return;
    }
    final uri = meetingUri(r.url);
    if (uri != null) openUrl(context, uri);
  }
}

class TimelineSection extends StatefulWidget {
  const TimelineSection({super.key, required this.controller});

  final PairingController controller;

  @override
  State<TimelineSection> createState() => _TimelineSectionState();
}

class _TimelineSectionState extends State<TimelineSection> {
  static const _preview = 4;
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    // The API sends oldest first: the page reads newest first.
    final rows = c.timeline.reversed.toList();
    final shown = _all ? rows : rows.take(_preview).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          title: 'Timeline',
          action: c.live ? 'Add a note' : null,
          onAction: () async {
            final sent = await showFormSheet(context, (_) => NoteForm(controller: c));
            if (sent && context.mounted) showMessage(context, 'Note added.');
          },
        ),
        if (rows.isEmpty)
          Text('Nothing recorded yet. Notes you add, and what happens, show up here.', style: MentoringText.body),
        for (final e in shown)
          Padding(
            key: ValueKey('event-${e.id}'),
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.only(top: 6, right: 10),
                  decoration: BoxDecoration(
                    color: switch (e.type) {
                      'GOAL_ACHIEVED' || 'SESSION_COMPLETED' || 'CERTIFICATE_ISSUED' => MentoringColors.green,
                      'ENDED_EARLY' => AppColors.error,
                      'PAUSED' || 'SESSION_CANCELLED' => AppColors.outline,
                      _ => AppColors.primary,
                    },
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(child: Text(e.label, style: MentoringText.bodyStrong)),
                          if (!e.shared) ...[const SizedBox(width: 6), const StatusPill('Private')],
                        ],
                      ),
                      Text(
                        '${whenLabel(e.createdAt)}${e.actorName == null || e.actorName!.isEmpty ? '' : ' · ${e.actorName}'}',
                        style: MentoringText.meta,
                      ),
                      if (e.note != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(e.note!, style: MentoringText.body),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (rows.length > _preview)
          InkWell(
            key: const ValueKey('timeline-all'),
            onTap: () => setState(() => _all = !_all),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(_all ? 'Show less' : 'All ${rows.length} entries', style: MentoringText.buttonQuiet),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// The end: the review and the certificate
// ---------------------------------------------------------------------------

class FeedbackSection extends StatelessWidget {
  const FeedbackSection({super.key, required this.controller, this.links});

  final PairingController controller;
  final MentorshipLinks? links;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final p = c.pairing!;
    if (p.status != PairingStatus.completed) return const SizedBox.shrink();
    final f = c.feedback;
    final cert = c.certificate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: 'Your review'),
        if (f == null)
          Callout(
            text: 'This mentorship is complete. How did it go? Your rating helps other members choose.',
            actions: [
              SolidButton(
                label: 'Rate this mentorship',
                icon: LucideIcons.star,
                onPressed: () => showReviewSheet(
                  context,
                  title: 'Rate your mentorship with ${p.counterpart.firstName}',
                  subtitle: p.viewerIsMentor
                      ? 'Seen by ICR only.'
                      : 'Shown on the mentor\'s profile without your name.',
                  flagLabel: p.viewerIsMentor ? null : 'I would recommend this mentor',
                  onSend: (rating, comment, flag) =>
                      c.sendFeedback(rating: rating, comment: comment, wouldRecommend: p.viewerIsMentor ? null : flag),
                ),
              ),
            ],
          )
        else
          MentoringCard(
            key: const ValueKey('my-review'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    for (var i = 1; i <= 5; i++)
                      Icon(
                        i <= f.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 18,
                        color: i <= f.rating ? MentoringColors.star : AppColors.outline,
                      ),
                  ],
                ),
                if (f.comment != null && f.comment!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(f.comment!, style: MentoringText.quote),
                  ),
              ],
            ),
          ),
        if (cert != null) ...[
          const SectionTitle(title: 'Your certificate', top: 10),
          MentoringCard(
            key: const ValueKey('certificate-card'),
            onTap: () => showCertificateSheet(context, cert, links: links),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: AppColors.chipEmphasis, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(LucideIcons.award, size: 22, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cert.title, style: MentoringText.cardTitle),
                      Text('Issued ${dayLabel(cert.issuedAt)} · ${cert.certificateId}', style: MentoringText.meta),
                    ],
                  ),
                ),
                const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.outline),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
