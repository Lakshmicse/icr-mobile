import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/chips.dart';
import '../chapters/community_kit.dart' show FeedPicture, PersonAvatar;
import '../site/site_kit.dart';
import 'talent_models.dart';

/// One candidate, as the website's `CandidateCard` but as a row of the app's member lists: the photo (ringed
/// green when they tell everyone they are ready), the name with Featured beside it, the headline, the
/// "Ready for next role" chip, the first five skills, then the facts — years, where, employer, what they expect,
/// when they are free. A match carries its "{n}% match" chip. The whole row opens the quick view.
class CandidateRow extends StatelessWidget {
  const CandidateRow({super.key, required this.candidate, required this.onOpen});

  final Candidate candidate;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final c = candidate;
    final facts = c.cardFacts;
    final match = c.matchScore;
    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CandidateAvatar(candidate: c, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              c.fullName,
                              style: SiteText.strong,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (c.featured) ...[
                            const SizedBox(width: 6),
                            IcrChip(
                              key: ValueKey('featured-${c.userId}'),
                              label: 'Featured',
                              tone: ChipTone.tinted,
                              fill: AppColors.amber50,
                              border: AppColors.amber500,
                              icon: LucideIcons.star,
                              iconSize: 11,
                              iconColor: AppColors.amber800,
                              height: 20,
                              padding: const EdgeInsets.symmetric(horizontal: 7),
                              gap: 3,
                              textStyle: SiteText.meta.copyWith(color: AppColors.amber800, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ],
                      ),
                      if (c.headline != null)
                        Text(c.headline!, style: SiteText.secondary, maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (c.nextRole != null) ...[const SizedBox(height: 4), NextRoleChip(nextRole: c.nextRole!)],
                    ],
                  ),
                ),
                if (match != null) ...[
                  const SizedBox(width: 8),
                  MatchChip(score: match, key: ValueKey('match-${c.userId}')),
                ],
              ],
            ),
            if (c.skills.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final s in c.skills.take(5)) IcrChip(label: s, tone: ChipTone.outlined, height: 24),
                  if (c.skills.length > 5)
                    IcrChip(label: '+${c.skills.length - 5}', tone: ChipTone.outlined, height: 24),
                ],
              ),
            ],
            if (facts.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(facts.join(' · '), style: SiteText.meta, key: ValueKey('facts-${c.userId}')),
            ],
          ],
        ),
      ),
    );
  }
}

/// The candidate's photo or initials, ringed in green when they tell everyone they are ready for their next role
/// (the website's `NextRoleRing`).
class CandidateAvatar extends StatelessWidget {
  const CandidateAvatar({super.key, required this.candidate, this.size = 44});

  final Candidate candidate;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = AppConfig.absoluteUrl(candidate.avatarUrl);
    final avatar = PersonAvatar(
      initials: candidate.initials,
      photo: url == null ? null : FeedPicture.network(url),
      size: size,
    );
    if (!(candidate.nextRole?.shownToEveryone ?? false)) return avatar;
    return Container(
      key: ValueKey('ring-${candidate.userId}'),
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        border: Border.fromBorderSide(BorderSide(color: AppColors.success, width: 2)),
      ),
      child: avatar,
    );
  }
}

/// "Ready for next role", green, with how keen they are, what they want and when they can start on a long press
/// (the website's tooltip).
class NextRoleChip extends StatelessWidget {
  const NextRoleChip({super.key, required this.nextRole});

  final NextRole nextRole;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: nextRole.summary,
      triggerMode: TooltipTriggerMode.longPress,
      child: IcrChip(
        label: 'Ready for Next Role',
        tone: ChipTone.tinted,
        fill: AppColors.emerald50,
        border: AppColors.emerald200,
        icon: LucideIcons.rocket,
        iconSize: 12,
        iconColor: AppColors.emerald700,
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        gap: 4,
        textStyle: SiteText.meta.copyWith(color: AppColors.emerald700, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// "{n}% match": green from 70, blue from 40, amber below (the website's `matchColor`).
class MatchChip extends StatelessWidget {
  const MatchChip({super.key, required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final (fill, ink) = score >= 70
        ? (AppColors.emerald50, AppColors.emerald700)
        : score >= 40
        ? (SiteColors.blueTint, AppColors.primary)
        : (AppColors.amber50, AppColors.amber800);
    return IcrChip(
      label: '$score% Match',
      tone: ChipTone.tinted,
      fill: fill,
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      textStyle: SiteText.meta.copyWith(color: ink, fontWeight: FontWeight.w700),
    );
  }
}
