import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/chips.dart';
import '../account/widgets/account_kit.dart' show AccountAvatar, AccountButton;
import '../site/site_kit.dart';
import 'project_models.dart';

/// A project in the list, as the website's card: the name (and "Private"), what it sources for, the description,
/// then its counts — candidates, each stage with people in it, "Archived". An archived project is dimmed.
class ProjectRow extends StatelessWidget {
  const ProjectRow({super.key, required this.project, required this.onTap});

  final Project project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = project;
    final n = p.candidateCount;
    return InkWell(
      onTap: onTap,
      child: Opacity(
        opacity: p.archived ? 0.65 : 1,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text(p.name, style: SiteText.strong)),
                  if (p.private) ...[
                    const SizedBox(width: 8),
                    IcrChip(label: 'Private', tone: ChipTone.filled, height: 24),
                  ],
                ],
              ),
              if (p.jobTitle != null) ...[
                const SizedBox(height: 2),
                Text('Sourcing for ${p.jobTitle}', style: SiteText.meta, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
              if (p.description != null) ...[
                const SizedBox(height: 8),
                Text(p.description!, style: SiteText.secondary, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  IcrChip(
                    label: '$n ${n == 1 ? 'candidate' : 'candidates'}',
                    tone: ChipTone.tinted,
                    height: 24,
                    fill: Colors.white,
                    border: AppColors.primary,
                    textStyle: AppText.chipLabel.copyWith(color: AppColors.primary),
                  ),
                  for (final s in sourcingBoardStages)
                    if ((p.stageCounts[s] ?? 0) > 0)
                      IcrChip(
                        label: '${sourcingStageLabel(s)} ${p.stageCounts[s]}',
                        tone: ChipTone.outlined,
                        height: 24,
                      ),
                  if (p.archived) IcrChip(label: 'Archived', tone: ChipTone.filled, height: 24),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A saved candidate, as the website's row: photo, name with the "Applied to {job} · {stage}" chip and the
/// company's tags, headline, the grey line (company · location · years · notice), the note; then the arrow that
/// moves them to the next stage and a menu to move them anywhere or take them out.
class CandidateRow extends StatelessWidget {
  const CandidateRow({
    super.key,
    required this.candidate,
    required this.onMove,
    required this.onRemove,
    this.busy = false,
    this.onOpenJob,
  });

  final ProjectCandidate candidate;
  final bool busy;
  final ValueChanged<String> onMove;
  final VoidCallback onRemove;

  /// Opens the job the "Applied to" chip names, when the app can.
  final ValueChanged<String>? onOpenJob;

  @override
  Widget build(BuildContext context) {
    final c = candidate;
    final next = nextSourcingStage(c.stage);
    final applied = c.appliedChip;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: AccountAvatar(url: c.avatarUrl, initials: c.initials, size: 36),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.name, style: SiteText.strong, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (applied != null || c.tags.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (applied != null)
                        IcrChip(
                          key: ValueKey('project.candidate.applied.${c.candidateId}'),
                          label: applied,
                          tone: ChipTone.tinted,
                          height: 22,
                          fill: AppColors.emerald50,
                          border: AppColors.emerald200,
                          textStyle: AppText.chipLabel.copyWith(color: AppColors.emerald700),
                          onTap: onOpenJob == null || c.applicationJobId == null
                              ? null
                              : () => onOpenJob!(c.applicationJobId!),
                        ),
                      for (final t in c.tags) IcrChip(label: t, tone: ChipTone.filled, height: 22),
                    ],
                  ),
                ],
                if (c.headline != null) ...[
                  const SizedBox(height: 2),
                  Text(c.headline!, style: SiteText.secondary, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
                if (c.meta.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(c.meta, style: SiteText.meta, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
                if (c.note != null) ...[
                  const SizedBox(height: 4),
                  Text(c.note!, style: SiteText.meta.copyWith(fontStyle: FontStyle.italic)),
                ],
              ],
            ),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else ...[
            if (next != null)
              IconButton(
                key: ValueKey('project.candidate.next.${c.candidateId}'),
                tooltip: 'Move to ${sourcingStageLabel(next)}',
                visualDensity: VisualDensity.compact,
                onPressed: () => onMove(next),
                icon: const Icon(LucideIcons.arrowRight, size: 18, color: AppColors.onSurfaceVariant),
              ),
            PopupMenuButton<String>(
              key: ValueKey('project.candidate.menu.${c.candidateId}'),
              tooltip: 'More Actions',
              icon: const Icon(LucideIcons.ellipsisVertical, size: 18, color: AppColors.onSurfaceVariant),
              onSelected: (v) => v == 'remove' ? onRemove() : onMove(v),
              itemBuilder: (_) => [
                for (final s in sourcingStages)
                  if (s != c.stage)
                    PopupMenuItem(
                      key: ValueKey('project.candidate.move.${c.candidateId}.$s'),
                      value: s,
                      child: Text('Move to ${sourcingStageLabel(s)}'),
                    ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  key: ValueKey('project.candidate.remove.${c.candidateId}'),
                  value: 'remove',
                  child: const Text('Remove from Project', style: TextStyle(color: AppColors.error)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Someone the criteria match, as the website's card: photo, name, the grey line, and Save.
class MatchRow extends StatelessWidget {
  const MatchRow({super.key, required this.match, required this.onSave, this.busy = false, this.disabled = false});

  final CandidateMatch match;
  final VoidCallback onSave;
  final bool busy;

  /// Another save is on its way: the website disables every Save then.
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final m = match;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          AccountAvatar(url: m.avatarUrl, initials: m.initials, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.name, style: SiteText.strong, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (m.meta.isNotEmpty) Text(m.meta, style: SiteText.meta, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AccountButton(
            key: ValueKey('project.match.save.${m.userId}'),
            label: 'Save',
            icon: LucideIcons.userPlus,
            outlined: true,
            expand: false,
            height: 34,
            busy: busy,
            onPressed: disabled ? null : onSave,
          ),
        ],
      ),
    );
  }
}

/// A calm full-page note: the page has no company to show, or is not this person's.
class ProjectsNotice extends StatelessWidget {
  const ProjectsNotice({super.key, required this.icon, required this.title, required this.text, this.action});

  final IconData icon;
  final String title;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      children: [
        Icon(icon, size: 40, color: AppColors.slate400),
        const SizedBox(height: 14),
        Text(title, style: SiteText.heading, textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(text, style: SiteText.secondary, textAlign: TextAlign.center),
        if (action != null) ...[const SizedBox(height: 18), Center(child: action!)],
      ],
    );
  }
}

/// A heading over a group of rows: the words, a count, and a hairline under it.
class ProjectSectionHeading extends StatelessWidget {
  const ProjectSectionHeading({super.key, required this.title, this.count});

  final String title;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Row(
        children: [
          Text(title, style: SiteText.subheading),
          if (count != null) ...[const SizedBox(width: 8), IcrChip(label: '$count', tone: ChipTone.filled, height: 22)],
        ],
      ),
    );
  }
}

/// The website's two tabs on the project page, as a LinkedIn-style underlined pair.
class ProjectTabs extends StatelessWidget {
  const ProjectTabs({
    super.key,
    required this.labels,
    required this.keys,
    required this.selected,
    required this.onSelect,
  });

  final List<String> labels;
  final List<Key> keys;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: SiteColors.hairline)),
      ),
      child: Row(
        children: [
          for (final (i, label) in labels.indexed)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == selected,
                child: InkWell(
                  key: keys[i],
                  onTap: () => onSelect(i),
                  child: Container(
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: i == selected ? AppColors.primary : Colors.transparent, width: 2),
                      ),
                    ),
                    child: Text(
                      label,
                      style: i == selected ? SiteText.strong : SiteText.secondary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
