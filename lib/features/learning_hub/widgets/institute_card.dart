import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../learning/learning_styles.dart';
import '../../learning/widgets/course_card.dart';
import '../../learning/widgets/course_picture.dart';
import '../hub_models.dart';
import '../hub_styles.dart';

/// One partner institute as a card on the frame of the Learning grid's course
/// card: its mark centred on a light plate (the initials on a navy one when it
/// has no mark), its name over two lines, how many courses it has published,
/// and "Verified by ICR" when ICR has verified it. It opens the institute's page.
class InstituteCard extends StatelessWidget {
  const InstituteCard({super.key, required this.institute, required this.onTap});

  final Institute institute;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final logo = institute.logo;
    return Semantics(
      button: true,
      label: '${institute.name}, ${institute.courseCountLabel}',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: HubColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('institute-${institute.id}'),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: CourseCard.coverAspect,
                child: logo == null
                    ? ColoredBox(
                        color: LearningColors.coverPlate,
                        child: Center(child: Text(institute.initials, style: LearningText.cardInitials)),
                      )
                    : ColoredBox(
                        color: HubColors.logoPlate,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          child: CoursePicture(
                            picture: logo,
                            fit: BoxFit.contain,
                            plate: HubColors.logoPlate,
                            child: Center(child: Text(institute.initials, style: LearningText.cardInitials)),
                          ),
                        ),
                      ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(11.5, 7, 11.5, 9),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(institute.name, style: LearningText.cardTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(
                        institute.courseCountLabel,
                        style: LearningText.cardMeta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      if (institute.verified) ...[const SizedBox(height: 6), const _VerifiedPill()],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VerifiedPill extends StatelessWidget {
  const _VerifiedPill();

  @override
  Widget build(BuildContext context) {
    // 20 dp at least, taller when larger text needs it.
    return Container(
      constraints: const BoxConstraints(minHeight: 20),
      padding: const EdgeInsets.only(left: 6, right: 8),
      decoration: BoxDecoration(color: AppColors.successTint, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.badgeCheck, size: 11, color: AppColors.successInk),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              'Verified by ICR',
              style: LearningText.cardPill,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// The institute's mark at a small size (its page's header), or its initials.
class InstituteMark extends StatelessWidget {
  const InstituteMark({super.key, required this.institute, this.size = 56});

  final Institute institute;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: size,
        height: size,
        child: institute.logo == null
            ? ColoredBox(
                color: LearningColors.coverPlate,
                child: Center(
                  child: Text(institute.initials, style: LearningText.cardInitials.copyWith(fontSize: size * 0.4)),
                ),
              )
            : ColoredBox(
                color: HubColors.logoPlate,
                child: Padding(
                  padding: EdgeInsets.all(size * 0.12),
                  child: CoursePicture(
                    picture: institute.logo,
                    fit: BoxFit.contain,
                    plate: HubColors.logoPlate,
                    child: Center(child: Text(institute.initials, style: LearningText.cardInitials)),
                  ),
                ),
              ),
      ),
    );
  }
}
