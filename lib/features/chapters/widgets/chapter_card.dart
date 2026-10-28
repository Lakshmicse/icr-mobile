import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../chapter_format.dart';
import '../chapter_models.dart';
import '../community_kit.dart';
import 'chapter_cover.dart';

/// The pills over a chapter's banner: "✓ JOINED" and the member's standing, or
/// "NEW" for a chapter chartered in the last sixty days.
class ChapterCoverPills extends StatelessWidget {
  const ChapterCoverPills({super.key, required this.chapter, this.isNew = false});

  final ChapterSummary chapter;
  final bool isNew;

  static const _soft = Color(0x38FFFFFF);

  @override
  Widget build(BuildContext context) {
    final pills = <Widget>[];
    if (chapter.joined) {
      pills.add(
        CommunityPill(
          label: 'JOINED',
          icon: LucideIcons.check,
          fill: CommunityColors.green700,
          style: CommunityText.pill,
          height: 19,
          padding: const EdgeInsets.symmetric(horizontal: 7.5),
        ),
      );
      pills.add(
        CommunityPill(
          label: chapter.role == ChapterRole.lead ? 'Lead' : 'Member',
          fill: _soft,
          style: CommunityText.pill.copyWith(fontWeight: FontWeight.w500),
          height: 19,
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      );
    } else if (isNew) {
      pills.add(
        CommunityPill(
          label: 'NEW',
          fill: _soft,
          style: CommunityText.pill,
          height: 19,
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, pill) in pills.indexed) ...[if (i > 0) const SizedBox(width: 4), pill],
      ],
    );
  }
}

/// A chapter in the directory: banner, name, place, two lines of copy, the
/// members and meetups, then Join (or Open) beside Preview (or Leave; a
/// chapter lead has no Leave, as on the website, so theirs reads Preview).
class ChapterCard extends StatelessWidget {
  const ChapterCard({
    super.key,
    required this.chapter,
    required this.busy,
    required this.onJoin,
    required this.onLeave,
    required this.onOpen,
    required this.onPreview,
    this.isNew = false,
  });

  final ChapterSummary chapter;

  /// A join or leave is on its way to the API.
  final bool busy;
  final bool isNew;
  final VoidCallback onJoin;
  final VoidCallback onLeave;
  final VoidCallback onOpen;

  /// "Preview Chapter": the quick look, without leaving the board.
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final c = chapter;
    final next = nextLabel(c);
    final canLeave = c.joined && c.role != ChapterRole.lead;
    return CommunityCard(
      padding: EdgeInsets.zero,
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChapterCover(
            chapter: c,
            pills: ChapterCoverPills(chapter: c, isNew: isNew),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.name, style: CommunityText.cardTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(LucideIcons.mapPin, size: 11, color: AppColors.slate400),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        c.place,
                        style: CommunityText.personLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (c.description != null) ...[
                  const SizedBox(height: 8),
                  Text(c.description!, style: CommunityText.cardCopy, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(LucideIcons.users, size: 12, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(membersLabel(c.memberCount), style: CommunityText.meta),
                    if (c.upcomingEventCount > 0) ...[
                      const SizedBox(width: 12),
                      const Icon(LucideIcons.zap, size: 12, color: AppColors.tertiary),
                      const SizedBox(width: 3),
                      Text(eventsLabel(c.upcomingEventCount), style: CommunityText.metaGreen),
                    ],
                    const Spacer(),
                    if (next != null) Text(next, style: CommunityText.meta),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: CommunityColors.tileRule),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 14, 6),
            child: Row(
              children: [
                if (c.joined)
                  CommunityButton(
                    label: 'Open Chapter',
                    outlined: true,
                    icon: LucideIcons.arrowRight,
                    onPressed: onOpen,
                  )
                else
                  CommunityButton(label: 'Join Chapter', icon: LucideIcons.userPlus, busy: busy, onPressed: onJoin),
                const Spacer(),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: canLeave ? (busy ? null : onLeave) : onPreview,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                    child: Text(canLeave ? 'Leave' : 'Preview Chapter', style: CommunityText.buttonQuiet),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A chapter the member belongs to, as a card in the sideways rail.
class JoinedChapterCard extends StatelessWidget {
  const JoinedChapterCard({super.key, required this.chapter, required this.onOpen});

  final ChapterSummary chapter;
  final VoidCallback onOpen;

  static const width = 210.0;
  static const height = 150.0;

  @override
  Widget build(BuildContext context) {
    final c = chapter;
    final next = nextLabel(c);
    return SizedBox(
      width: width,
      height: height,
      child: CommunityCard(
        padding: EdgeInsets.zero,
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ChapterCover(
              chapter: c,
              height: 52,
              pills: CommunityPill(
                label: c.role == ChapterRole.lead ? 'Lead' : 'Member',
                fill: const Color(0x38FFFFFF),
                style: CommunityText.pill,
                height: 19,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.name, style: CommunityText.cardTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(c.place, style: CommunityText.personLine, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(LucideIcons.users, size: 11, color: AppColors.slate500),
                      const SizedBox(width: 4),
                      Text(membersLabel(c.memberCount), style: CommunityText.meta),
                      const Spacer(),
                      if (next != null) Text(next, style: CommunityText.metaGreen),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 9),
              child: Row(
                children: [
                  Text('Open chapter', style: CommunityText.link),
                  const SizedBox(width: 3),
                  const Icon(LucideIcons.arrowRight, size: 11, color: AppColors.primary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
