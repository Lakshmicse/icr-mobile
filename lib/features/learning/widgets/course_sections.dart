import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../learning_format.dart';
import '../learning_models.dart';
import '../learning_styles.dart';
import 'course_picture.dart';

/// The 2 dp rule between the course sheet's sections.
class SectionRule extends StatelessWidget {
  const SectionRule({super.key, this.indent = 0, this.height = 2.0, this.color = LearningColors.rule});

  final double indent;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: indent),
      child: ColoredBox(
        color: color,
        child: SizedBox(height: height, width: double.infinity),
      ),
    );
  }
}

/// "Course Overview": the description, folded after four lines.
class CourseOverview extends StatefulWidget {
  const CourseOverview({super.key, required this.text});

  final String text;

  static const foldLines = 4;

  @override
  State<CourseOverview> createState() => _CourseOverviewState();
}

class _CourseOverviewState extends State<CourseOverview> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final text = plainText(widget.text);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20.5, 10.7, 20.5, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Course Overview', style: LearningText.section),
          const SizedBox(height: 6.1),
          LayoutBuilder(
            builder: (context, constraints) {
              final painter = TextPainter(
                text: TextSpan(text: text, style: LearningText.body),
                textDirection: TextDirection.ltr,
                maxLines: CourseOverview.foldLines,
              )..layout(maxWidth: constraints.maxWidth);
              final clipped = painter.didExceedMaxLines;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: LearningText.body,
                    maxLines: _open ? null : CourseOverview.foldLines,
                    overflow: _open ? TextOverflow.visible : TextOverflow.clip,
                  ),
                  if (clipped) ...[
                    const SizedBox(height: 2.9),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _open = !_open),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_open ? 'show less' : 'show more', style: LearningText.showMore),
                          const SizedBox(width: 1),
                          SizedBox(width: 12, height: 12, child: _Chevron(up: _open)),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// The design's bold blue chevron (Material's, 18 dp at weight 700), drawn in a
/// 12 dp box so it does not push the "show more" line any taller.
class _Chevron extends StatelessWidget {
  const _Chevron({required this.up});

  final bool up;

  @override
  Widget build(BuildContext context) {
    return OverflowBox(
      maxWidth: 18,
      maxHeight: 18,
      child: Icon(
        up ? Symbols.keyboard_arrow_up : Symbols.keyboard_arrow_down,
        size: 18,
        weight: 700,
        color: AppColors.primary,
      ),
    );
  }
}

/// "Key Takeaways": the learning outcomes on a numbered timeline.
class KeyTakeaways extends StatelessWidget {
  const KeyTakeaways({super.key, required this.outcomes});

  final List<String> outcomes;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(30.5, 14.5, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Key Takeaways', style: LearningText.section),
          const SizedBox(height: 11.9),
          for (final (i, outcome) in outcomes.indexed)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 36,
                    child: Column(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.primary, width: 2),
                          ),
                          child: Text('${i + 1}', style: LearningText.stepNumber),
                        ),
                        // The line runs on below the last circle too, as the design draws it.
                        const Expanded(
                          child: Center(
                            child: SizedBox(
                              width: 1,
                              height: double.infinity,
                              child: ColoredBox(color: LearningColors.stepLine),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14.5),
                  // The design's text column, narrower than the room: a fixed
                  // width, since a tight flex width would win over a maximum.
                  SizedBox(
                    width: 222,
                    child: Padding(
                      padding: EdgeInsets.only(top: 2.9, bottom: i < outcomes.length - 1 ? 16.6 : 1),
                      child: Text(outcome, style: LearningText.takeaway),
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

/// "Course Outline": the syllabus, module by module, the first open.
class CourseOutline extends StatefulWidget {
  const CourseOutline({super.key, required this.modules});

  final List<CourseModule> modules;

  @override
  State<CourseOutline> createState() => _CourseOutlineState();
}

class _CourseOutlineState extends State<CourseOutline> {
  bool _full = false;
  late final Set<String> _open = {if (widget.modules.isNotEmpty) widget.modules.first.id};

  @override
  Widget build(BuildContext context) {
    final modules = widget.modules;
    return Padding(
      padding: const EdgeInsets.fromLTRB(19.6, 9.4, 19.6, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 28,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 1),
                  child: Text('Course Outline', style: LearningText.section),
                ),
                const Spacer(),
                if (modules.length > 1)
                  Material(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: LearningColors.tileBorder),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() {
                        _full = !_full;
                        if (_full) {
                          _open.addAll(modules.map((m) => m.id));
                        } else {
                          _open
                            ..clear()
                            ..add(modules.first.id);
                        }
                      }),
                      child: SizedBox(
                        width: 105.2,
                        height: 28,
                        child: Center(
                          child: Text(
                            _full ? 'collapse outline' : 'view full outline',
                            style: LearningText.outlineToggle,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16.4),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: LearningColors.panelBorder),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.only(top: 16.5, bottom: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, module) in modules.indexed) ...[
                  if (i > 0) ...[
                    const SizedBox(height: 19.7),
                    const SectionRule(height: 1, color: LearningColors.panelBorder),
                    const SizedBox(height: 16.4),
                  ],
                  _ModuleRow(
                    index: i + 1,
                    module: module,
                    open: _open.contains(module.id),
                    onTap: () =>
                        setState(() => _open.contains(module.id) ? _open.remove(module.id) : _open.add(module.id)),
                  ),
                  if (_open.contains(module.id)) ...[
                    const SizedBox(height: 17.3),
                    Padding(
                      padding: const EdgeInsets.only(left: 49.5, right: 15.5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (module.summary != null) ...[
                            Text(module.summary!, style: LearningText.lesson),
                            if (module.lessons.isNotEmpty) const SizedBox(height: 9.75),
                          ],
                          for (final (j, lesson) in module.lessons.indexed) ...[
                            if (j > 0) const SizedBox(height: 9.75),
                            Text(lesson, style: LearningText.lesson),
                          ],
                          if (module.summary == null && module.lessons.isEmpty)
                            Text('Detail for this module is on its way.', style: LearningText.lesson),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleRow extends StatelessWidget {
  const _ModuleRow({required this.index, required this.module, required this.open, required this.onTap});

  final int index;
  final CourseModule module;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(left: 15.5, right: 15.5),
        child: Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // Blue while the module is open, grey when it is folded, as the design.
                border: Border.all(color: open ? AppColors.primary : LearningColors.tabInactive, width: 1.5),
              ),
            ),
            const SizedBox(width: 10.9),
            Expanded(
              child: Text(
                'Module $index: ${module.title}',
                style: LearningText.moduleTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(open ? LucideIcons.chevronUp : LucideIcons.chevronDown, size: 14, color: AppColors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// "Who Should Attend": the audience, two chips across.
class WhoShouldAttend extends StatelessWidget {
  const WhoShouldAttend({super.key, required this.audience});

  final List<String> audience;

  static const chipWidth = 150.6;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(30.5, 13.4, 30, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Who Should Attend', style: LearningText.section),
          const SizedBox(height: 11.9),
          Wrap(
            spacing: 28.2,
            runSpacing: 7.2,
            children: [
              for (final who in audience)
                Container(
                  width: chipWidth,
                  height: 31,
                  padding: const EdgeInsets.only(left: 13.4, right: 10),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    border: Border.all(color: LearningColors.chipBorder),
                    borderRadius: BorderRadius.circular(15.5),
                  ),
                  child: Text(who, style: LearningText.chip, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The enrolment specialist: photo, name, role, how to reach them, and the
/// in-house enquiry.
class ContactBlock extends StatelessWidget {
  const ContactBlock({
    super.key,
    required this.contact,
    required this.email,
    required this.onTalk,
    required this.onInHouse,
    required this.onEmail,
    this.talkLabel = "let's talk on whatsapp",
  });

  final CourseContact contact;

  /// The line under the role: the specialist's own address on the demo, ICR's
  /// published enquiries address on a live course.
  final String email;
  final VoidCallback onTalk;
  final VoidCallback onInHouse;
  final VoidCallback onEmail;
  final String talkLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(19.6, 9.3, 19.6, 0),
      child: Column(
        children: [
          Container(
            width: 61,
            height: 61,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.surfaceContainer),
            clipBehavior: Clip.antiAlias,
            child: CoursePicture(
              picture: contact.photo,
              plate: AppColors.surfaceContainer,
              child: Center(
                child: Text(
                  contact.name.isEmpty ? '?' : contact.name[0].toUpperCase(),
                  style: LearningText.contactName.copyWith(fontSize: 22, color: AppColors.outline),
                ),
              ),
            ),
          ),
          const SizedBox(height: 1.4),
          Text(contact.name, style: LearningText.contactName, textAlign: TextAlign.center),
          const SizedBox(height: 7),
          Text(contact.role, style: LearningText.contactRole, textAlign: TextAlign.center),
          const SizedBox(height: 11.7),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onEmail,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.mail, size: 13, color: LearningColors.bodyInk),
                const SizedBox(width: 6.5),
                Text(email, style: LearningText.contactEmail),
              ],
            ),
          ),
          const SizedBox(height: 7),
          Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: LearningColors.whatsappBorder, width: 1.5),
            ),
            child: InkWell(
              onTap: onTalk,
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 39,
                child: Center(child: Text(talkLabel, style: LearningText.whatsapp)),
              ),
            ),
          ),
          const SizedBox(height: 3.3),
          Material(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: onInHouse,
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 42,
                child: Center(child: Text('take this course as in-house', style: LearningText.inHouse)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "About the Certificate": the marks and the paragraph.
class AboutCertificate extends StatelessWidget {
  const AboutCertificate({super.key, required this.badges, required this.text});

  final List<FeedPicture> badges;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(30.5, 15.5, 28, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('About the Certificate', style: LearningText.section),
          if (badges.isNotEmpty) ...[
            const SizedBox(height: 15),
            Row(
              children: [
                for (final (i, badge) in badges.indexed) ...[
                  if (i > 0) const SizedBox(width: 15.5),
                  SizedBox(
                    width: 52,
                    height: 29,
                    child: CoursePicture(picture: badge, fit: BoxFit.contain, plate: AppColors.surfaceContainerLow),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 11.3),
            const SectionRule(height: 1, color: LearningColors.panelBorder),
            const SizedBox(height: 11.4),
          ] else
            const SizedBox(height: 11.4),
          Text(text, style: LearningText.certificate),
        ],
      ),
    );
  }
}

/// What a past learner said, with the big quote mark.
class Testimonial extends StatelessWidget {
  const Testimonial({super.key, required this.review});

  final CourseReview review;

  @override
  Widget build(BuildContext context) {
    final body = review.body.trim();
    final quoted = body.startsWith('"') || body.startsWith('“') ? body : '"$body"';
    return Padding(
      padding: const EdgeInsets.fromLTRB(26.8, 20.4, 22, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: SizedBox(width: 24, child: Text('66', style: LearningText.quoteMark, softWrap: false)),
              ),
              const SizedBox(width: 7),
              Expanded(child: Text(quoted, style: LearningText.quote)),
            ],
          ),
          const SizedBox(height: 12.7),
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 35,
                  height: 35,
                  decoration: BoxDecoration(color: LearningColors.reviewerTile, borderRadius: BorderRadius.circular(8)),
                  clipBehavior: Clip.antiAlias,
                  child: CoursePicture(
                    picture: review.photo,
                    plate: LearningColors.reviewerTile,
                    child: const Center(child: Icon(LucideIcons.user, size: 16, color: LearningColors.reviewerGlyph)),
                  ),
                ),
                const SizedBox(width: 10.4),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2.8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(review.author, style: LearningText.reviewer),
                        if (review.role != null) ...[
                          const SizedBox(height: 3.6),
                          Text(review.role!, style: LearningText.reviewerRole),
                        ],
                      ],
                    ),
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

/// The reviews: the first as the design's testimonial, and — when the course
/// has more — "see all N reviews" unfolding the rest in the same layout.
class Testimonials extends StatelessWidget {
  const Testimonials({
    super.key,
    required this.reviews,
    required this.total,
    required this.expanded,
    required this.onToggle,
    required this.onMore,
  });

  final List<CourseReview> reviews;

  /// How many reviews the course has in all (the API's count, which can exceed [reviews]).
  final int total;
  final bool expanded;
  final VoidCallback onToggle;

  /// Opens the rest of a long list where it lives, on the website.
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) return const SizedBox.shrink();
    final more = total > reviews.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Testimonial(review: reviews.first),
        if (expanded)
          for (final review in reviews.skip(1)) Testimonial(key: ValueKey('review-${review.id}'), review: review),
        if (reviews.length > 1 || more)
          Padding(
            padding: const EdgeInsets.fromLTRB(58.8, 14, 22, 0),
            child: GestureDetector(
              key: const ValueKey('reviews-toggle'),
              behavior: HitTestBehavior.opaque,
              onTap: expanded && more ? onMore : onToggle,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    expanded
                        ? (more ? 'read all $total reviews on the website' : 'show fewer reviews')
                        : 'see all $total reviews',
                    style: LearningText.showMore,
                  ),
                  const SizedBox(width: 1),
                  if (expanded && more)
                    const Icon(LucideIcons.arrowUpRight, size: 11, color: AppColors.primary)
                  else
                    SizedBox(width: 12, height: 12, child: _Chevron(up: expanded)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
