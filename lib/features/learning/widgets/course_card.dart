import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../learning_format.dart';
import '../learning_models.dart';
import '../learning_styles.dart';
import 'course_picture.dart';
import 'cover_pill.dart';

/// One course in the catalogue grid, drawn as the Events agenda's cards are:
/// the cover on top (16:10, the card's rounded corners clipping it) with the
/// course's pill over its top left, then the title (up to two lines), the
/// awarding body with its logo, the meta line (wrapping to a second line rather
/// than losing a word), and a footer pinned to the bottom with the price, the
/// member's place when they hold one, and the CPD credits.
///
/// The frame is the Events card's: 10 dp corners, a 1 dp `#EDEDED` edge, no
/// shadow. 184.5 dp wide in the design's two-column grid at 390 dp.
class CourseCard extends StatelessWidget {
  const CourseCard({super.key, required this.course, required this.onTap, this.showPlace = false});

  /// The Events photo is 184.5 × 114 dp.
  static const coverAspect = 184.5 / 114;

  /// A card's cover is cropped by this much at the bottom: the seeded cover is
  /// the design's thumbnail, cut with its own drop shadow along the foot, which
  /// would read as a pale strip under the picture.
  static const coverCrop = 1.04;

  final Course course;
  final VoidCallback onTap;

  /// "My courses": the meta line is the run the member holds a place on.
  final bool showPlace;

  @override
  Widget build(BuildContext context) {
    final place = showPlace ? enrolmentMeta(course.enrolment) : null;
    final meta = place ?? courseMeta(course);
    final metaIcon = place != null
        ? LucideIcons.calendar
        : courseMetaTimed(course)
        ? LucideIcons.clock3
        : LucideIcons.award;
    final provider = course.provider;
    final providerName = provider?.name ?? 'ICR Institute';
    final badge = course.badge;
    return Semantics(
      button: true,
      label: '${course.title}, $providerName',
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: LearningColors.cardBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: coverAspect,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRect(
                      child: Transform.scale(
                        scale: course.cover == null ? 1 : coverCrop,
                        alignment: Alignment.topCenter,
                        child: CoursePicture(
                          picture: course.cover,
                          child: Center(child: Text(courseInitials(course.title), style: LearningText.cardInitials)),
                        ),
                      ),
                    ),
                    if (badge != null)
                      Positioned(
                        left: 8,
                        top: 9.5,
                        right: 8,
                        child: Align(alignment: Alignment.topLeft, child: CoverPill(badge, compact: true)),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(11.5, 7, 11.5, 9),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(course.title, style: LearningText.cardTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 14,
                        child: Row(
                          children: [
                            if (provider?.logo != null) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CoursePicture(
                                    picture: provider!.logo,
                                    fit: BoxFit.contain,
                                    plate: AppColors.surfaceContainerLow,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                            Expanded(
                              child: Text(
                                providerName,
                                style: LearningText.cardProvider,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 1.5),
                            child: Icon(metaIcon, size: 11, color: AppColors.onSurfaceVariant),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              meta,
                              style: LearningText.cardMeta,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      const Spacer(),
                      CourseFooter(course: course),
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

/// The card's bottom row: the price (a green "Free" pill, or the amount), the
/// member's place when they hold one ("Enrolled", "Place requested"…), and the
/// CPD credits. It wraps rather than overflow on a narrow card.
class CourseFooter extends StatelessWidget {
  const CourseFooter({super.key, required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final mine = course.enrolled ? course.enrolment!.status : null;
    return Wrap(
      spacing: 5,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (course.free)
          const _Pill(label: 'Free', fill: AppColors.successTint, ink: AppColors.successInk)
        else
          SizedBox(
            height: 20,
            child: Center(
              widthFactor: 1,
              child: Text(priceLabel(course.priceAmount, course.priceCurrency), style: LearningText.cardPrice),
            ),
          ),
        if (mine != null) _statusPill(mine),
        if (course.cpdCredits > 0)
          _Pill(
            label: '${course.cpdCredits} CPD',
            fill: LearningColors.cpdFill,
            ink: AppColors.primary,
            icon: LucideIcons.award,
          ),
      ],
    );
  }

  /// A place that holds a seat is solid green with a tick; one still being
  /// decided is amber.
  Widget _statusPill(EnrolmentStatus status) => switch (status) {
    EnrolmentStatus.confirmed || EnrolmentStatus.completed => _Pill(
      label: status.label,
      fill: AppColors.successInk,
      ink: Colors.white,
      icon: Symbols.check,
      iconWeight: 700,
    ),
    _ => _Pill(
      label: status.label,
      fill: AppColors.amber100,
      ink: AppColors.amber800,
      icon: Symbols.schedule,
      iconWeight: 600,
    ),
  };
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.fill, required this.ink, this.icon, this.iconWeight});

  final String label;
  final Color fill;
  final Color ink;
  final IconData? icon;
  final double? iconWeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      padding: EdgeInsets.only(left: icon == null ? 8 : 6, right: 8),
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 11, weight: iconWeight, color: ink), const SizedBox(width: 3)],
          Flexible(
            child: Text(
              label,
              style: LearningText.cardPill.copyWith(color: ink),
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

/// Two cards side by side, as the Events agenda lays them (9 dp in on the left,
/// 9.5 on the right, 3 dp between), as tall as the taller of the two. A lone
/// last course sits at the left, half width.
class CourseGridRow extends StatelessWidget {
  const CourseGridRow({super.key, required this.left, this.right, required this.onOpen, this.showPlace = false});

  static const gap = 3.0;
  static const padding = EdgeInsets.only(left: 9, right: 9.5);

  /// Between one row and the next.
  static const rowGap = 4.0;

  final Course left;
  final Course? right;
  final void Function(Course) onOpen;
  final bool showPlace;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: CourseCard(key: ValueKey(left.id), course: left, showPlace: showPlace, onTap: () => onOpen(left)),
            ),
            const SizedBox(width: gap),
            Expanded(
              child: right == null
                  ? const SizedBox.shrink()
                  : CourseCard(
                      key: ValueKey(right!.id),
                      course: right!,
                      showPlace: showPlace,
                      onTap: () => onOpen(right!),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
