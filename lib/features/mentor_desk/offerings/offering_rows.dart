import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../mentorship_my/mentoring_format.dart' show countLabel, minutesLabel;
import '../../mentorship_my/widgets/kit.dart';
import 'group_form.dart';
import 'offering_fields.dart';
import 'offerings_models.dart';

/// A service the mentor lists, with what it earns and the buttons that fit.
class ServiceRow extends StatelessWidget {
  const ServiceRow({
    super.key,
    required this.service,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final OfferedService service;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final s = service;
    final blocker = !s.active ? s.blocker : null;
    return MentoringCard(
      key: ValueKey('service-${s.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(s.title, style: MentoringText.cardTitle)),
              StatusPill(s.active ? 'Live' : 'Paused', tone: s.active ? PillTone.mint : PillTone.grey),
            ],
          ),
          MetaLine(
            icon: LucideIcons.tag,
            text: '${s.kind.label} · ${priceLine(s.pricePaisa, compareAt: s.compareAtPaisa)}',
          ),
          if (s.durationMin != null || s.seats != null)
            MetaLine(
              icon: LucideIcons.clock,
              text: [
                if (s.durationMin != null) minutesLabel(s.durationMin!),
                if (s.seats != null) countLabel(s.seats!, 'seat'),
              ].join(' · '),
            ),
          if (s.fileName != null) MetaLine(icon: LucideIcons.file, text: s.fileName!),
          MetaLine(
            icon: LucideIcons.chartNoAxesColumn,
            text:
                '${countLabel(s.salesCount, 'sale')}'
                '${s.ratingCount > 0 ? ' · ${s.rating.toStringAsFixed(1)} from ${countLabel(s.ratingCount, 'review')}' : ''}',
          ),
          if (blocker != null) MetaLine(icon: LucideIcons.info, text: blocker, color: AppColors.amber800),
          ActionWrap(
            children: [
              QuietButton(label: 'Edit', icon: LucideIcons.pencil, onPressed: onEdit),
              if (s.active) QuietButton(label: 'Pause', icon: LucideIcons.pause, onPressed: onToggle),
              if (!s.active && blocker == null)
                SolidButton(label: 'Resume', icon: LucideIcons.play, onPressed: onToggle),
              QuietButton(label: 'Delete', icon: LucideIcons.trash2, danger: true, onPressed: onDelete),
            ],
          ),
        ],
      ),
    );
  }
}

/// An ongoing plan or a programme the mentor lists.
class PlanRow extends StatelessWidget {
  const PlanRow({super.key, required this.plan, required this.onEdit, required this.onToggle, required this.onDelete});

  final OfferedPlan plan;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final p = plan;
    return MentoringCard(
      key: ValueKey('plan-${p.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(p.title, style: MentoringText.cardTitle)),
              StatusPill(p.active ? 'Live' : 'Paused', tone: p.active ? PillTone.mint : PillTone.grey),
            ],
          ),
          MetaLine(
            icon: LucideIcons.tag,
            text:
                '${p.programme ? 'Programme' : 'Ongoing plan'} · ${priceLine(p.pricePaisa, compareAt: p.compareAtPaisa)}'
                '${p.free || p.programme ? '' : (p.billingPeriodMonths == 1 ? ' a month' : ' every ${p.billingPeriodMonths} months')}',
          ),
          MetaLine(
            icon: LucideIcons.layers,
            text: p.programme
                ? '${countLabel(p.totalSessions ?? p.steps.length, 'session')}'
                      '${p.accessMonths == null ? '' : ' · ${p.accessMonths} months to use them'}'
                : '${countLabel(p.sessionsPerMonth, 'session')} a month'
                      '${p.sessionDurationMin == null ? '' : ' of ${minutesLabel(p.sessionDurationMin!)}'}',
          ),
          MetaLine(icon: LucideIcons.users, text: countLabel(p.subscribersCount, 'member')),
          ActionWrap(
            children: [
              QuietButton(label: 'Edit', icon: LucideIcons.pencil, onPressed: onEdit),
              if (p.active) QuietButton(label: 'Pause', icon: LucideIcons.pause, onPressed: onToggle),
              if (!p.active) SolidButton(label: 'Resume', icon: LucideIcons.play, onPressed: onToggle),
              QuietButton(label: 'Delete', icon: LucideIcons.trash2, danger: true, onPressed: onDelete),
            ],
          ),
        ],
      ),
    );
  }
}

/// A group session the mentor hosts.
class SessionRow extends StatelessWidget {
  const SessionRow({super.key, required this.session, required this.onOpen, this.onPublish});

  final HostedSession session;
  final VoidCallback onOpen;
  final VoidCallback? onPublish;

  @override
  Widget build(BuildContext context) {
    final s = session;
    return MentoringCard(
      key: ValueKey('session-${s.id}'),
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(s.title, style: MentoringText.cardTitle)),
              StatusPill(
                s.statusLabel,
                tone: switch (s.status) {
                  'SCHEDULED' => PillTone.mint,
                  'DRAFT' => PillTone.amber,
                  'COMPLETED' => PillTone.blue,
                  _ => PillTone.grey,
                },
              ),
            ],
          ),
          MetaLine(icon: LucideIcons.calendarClock, text: seriesLine(s)),
          MetaLine(
            icon: LucideIcons.users,
            text:
                '${s.pricePaisa == null ? 'Free' : priceLine(s.pricePaisa!)} · '
                '${s.seatsTaken}${s.capacity == null ? '' : ' of ${s.capacity}'} seats'
                '${s.waitlistCount > 0 ? ' · ${s.waitlistCount} waiting' : ''}',
          ),
          ActionWrap(
            children: [
              QuietButton(label: 'Details', icon: LucideIcons.listChecks, onPressed: onOpen),
              if (s.draft && onPublish != null)
                SolidButton(label: 'Publish', icon: LucideIcons.send, onPressed: onPublish),
            ],
          ),
        ],
      ),
    );
  }
}
