import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart';
import '../../core/widgets/detail_sheet.dart';
import '../../core/widgets/section_heading.dart';
import 'course_sheet_controller.dart';
import 'learning_controller.dart';
import 'learning_format.dart';
import 'learning_models.dart';
import 'learning_styles.dart';
import 'widgets/course_bottom_bar.dart';
import 'widgets/course_picture.dart';
import 'widgets/cover_pill.dart';
import 'widgets/course_sections.dart';
import 'widgets/enquiry_sheet.dart';
import 'widgets/run_tile.dart';

/// Opens a course over the list, as the Course page design.
Future<void> showCourseSheet(BuildContext context, Course course) async {
  final learning = context.read<LearningController>();
  final controller = CourseSheetController(repository: learning.repository, seed: course, onChanged: learning.update)
    ..load();
  await showDetailSheet<void>(
    context,
    body: (_) => ChangeNotifierProvider.value(value: controller, child: const CourseSheetBody()),
    bottomBar: (_) => ChangeNotifierProvider.value(value: controller, child: const CourseSheetBar()),
  );
  controller.dispose();
}

/// The scrolling part of the sheet.
class CourseSheetBody extends StatelessWidget {
  const CourseSheetBody({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CourseSheetController>();
    final course = controller.course;
    final overview = course.description ?? course.summary;
    final contact = course.contact;
    final about = course.aboutCertificate;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const SizedBox(height: 11.7),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.5),
          child: Text(course.title, style: LearningText.title),
        ),
        if (course.summary != null) ...[
          const SizedBox(height: 5.7),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.5),
            child: Text(course.summary!, style: LearningText.subtitle),
          ),
        ],
        const SizedBox(height: 13.3),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9.5),
          child: _Cover(course: course),
        ),
        if (controller.loading && !course.detailLoaded)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2))),
          )
        else if (controller.error != null && !course.detailLoaded)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(controller.error!, style: LearningText.body),
          )
        else ...[
          if (course.runs.isNotEmpty) ...[
            const SizedBox(height: 14.4),
            _ModeTabs(controller: controller),
            const SizedBox(height: 12.2),
            _SelectDateRow(controller: controller),
            const SizedBox(height: 12),
            _RunGrid(controller: controller),
            const SizedBox(height: 11.5),
            Padding(
              padding: const EdgeInsets.only(left: 16.5),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => controller.hasMoreRuns
                    ? controller.toggleAllDates()
                    : openUrl(context, controller.repository.link(course)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(controller.allDates ? 'Show Fewer Dates' : 'See More Dates', style: LearningText.seeMore),
                    const SizedBox(width: 4),
                    Icon(
                      controller.allDates ? LucideIcons.chevronUp : LucideIcons.arrowRight,
                      size: 15,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8.4),
          ] else ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15.5),
              child: _NoRuns(course: course),
            ),
            const SizedBox(height: 12),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15.5),
            child: _WideButton(
              label: controller.ctaLabel,
              icon: course.enrolled ? LucideIcons.check : Symbols.shopping_bag,
              iconWeight: 600,
              filled: true,
              held: course.enrolled,
              enabled: controller.canAct,
              onPressed: () => addToCart(context, controller),
            ),
          ),
          const SizedBox(height: 9.5),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15.5),
            child: _WideButton(
              label: 'DOWNLOAD BROCHURE',
              icon: Symbols.download,
              iconWeight: 700,
              height: 40,
              enabled: course.brochureUrl != null,
              onPressed: () => openBrochure(context, course),
            ),
          ),
          const SizedBox(height: 24.6),
          const Hairline(color: AppColors.outlineVariant),
          if (overview != null) ...[CourseOverview(text: overview), const SizedBox(height: 6.6), const SectionRule()],
          if (course.outcomes.isNotEmpty) ...[
            KeyTakeaways(outcomes: course.outcomes),
            const SizedBox(height: 24.3),
            const SectionRule(),
          ],
          if (course.modules.isNotEmpty) ...[
            CourseOutline(modules: course.modules),
            const SizedBox(height: 9.3),
            const SectionRule(),
          ],
          if (course.audience.isNotEmpty) ...[
            WhoShouldAttend(audience: course.audience),
            const SizedBox(height: 8.2),
            const SectionRule(),
          ],
          if (contact != null) ...[
            ContactBlock(
              contact: contact,
              email: contact.email ?? icrEnquiryEmail,
              talkLabel: contact.whatsapp != null ? "let's talk on whatsapp" : 'ask the institute',
              onTalk: () =>
                  contact.whatsapp != null ? openUrl(context, contact.whatsapp!) : askInstitute(context, controller),
              onEmail: () => openUrl(context, mailTo(contact.email ?? icrEnquiryEmail, course)),
              onInHouse: () => inHouse(context, controller),
            ),
            const SizedBox(height: 8.6),
            const SectionRule(indent: 10),
          ],
          if (about != null) AboutCertificate(badges: course.certificateBadges, text: about),
          if (controller.reviews.isNotEmpty)
            Testimonials(
              reviews: controller.reviews,
              total: controller.reviewTotal,
              expanded: controller.allReviews,
              onToggle: controller.toggleAllReviews,
              onMore: () => openUrl(context, controller.repository.link(course)),
            ),
          const SizedBox(height: 24),
        ],
      ],
    );
  }

  /// What a place the member holds is, in a sentence.
  static String placeMessage(Course course) => switch (course.enrolment?.status) {
    EnrolmentStatus.confirmed => 'Your place on ${course.title} is confirmed.',
    EnrolmentStatus.waitlisted => 'You are on the waitlist for ${course.title}.',
    EnrolmentStatus.completed => 'You have completed ${course.title}.',
    _ => 'Place requested. ICR will confirm it by email.',
  };

  /// "Add to cart": a free place (or a waitlist place) is taken here; a paid
  /// one is bought on the website's enrolment panel; a place already held says so.
  static Future<void> addToCart(BuildContext context, CourseSheetController controller) async {
    if (controller.course.enrolled) {
      showMessage(context, placeMessage(controller.course));
      return;
    }
    if (!controller.canAct) return;
    if (controller.paidPlace) {
      await openUrl(context, controller.repository.checkoutLink(controller.course, controller.selectedRun));
      return;
    }
    final message = await controller.enrol();
    if (!context.mounted) return;
    showMessage(context, message ?? placeMessage(controller.course));
  }

  static Future<void> openBrochure(BuildContext context, Course course) async {
    final url = course.brochureUrl;
    if (url == null) {
      showMessage(context, 'This course has no brochure yet.');
      return;
    }
    await openUrl(context, Uri.parse(url));
  }

  /// "mailto:" with the course in the subject.
  static Uri mailTo(String address, Course course) =>
      Uri.parse('mailto:$address?subject=${Uri.encodeComponent('${course.title} (${course.code})')}');

  /// The institute's enquiry form, or - for ICR's own course, which has no
  /// institute to write to - the website's contact page with the subject filled.
  static Future<void> _write(
    BuildContext context,
    CourseSheetController controller,
    EnquiryKind kind,
    String subject,
  ) async {
    final course = controller.course;
    if (!controller.canEnquire) {
      final full = Uri.encodeQueryComponent('$subject${course.title} (${course.code})');
      await openSitePage(context, '/contact?subject=$full');
      return;
    }
    await showEnquirySheet(context, controller, kind: kind);
  }

  static Future<void> askInstitute(BuildContext context, CourseSheetController controller) =>
      _write(context, controller, EnquiryKind.question, '');

  /// "Suggest A Date & Location": a date and location request to the institute.
  static Future<void> suggestDate(BuildContext context, CourseSheetController controller) =>
      _write(context, controller, EnquiryKind.dateRequest, 'Date and location request: ');

  /// "take this course as in-house": a corporate enquiry to the institute.
  static Future<void> inHouse(BuildContext context, CourseSheetController controller) =>
      _write(context, controller, EnquiryKind.inHouse, 'In-house delivery: ');
}

/// The bar under the sheet: the brochure glyph and the short "add to cart".
class CourseSheetBar extends StatelessWidget {
  const CourseSheetBar({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CourseSheetController>();
    final course = controller.course;
    return CourseBottomBar(
      label: course.enrolled ? course.enrolment!.status.label.toLowerCase() : controller.ctaLabel.toLowerCase(),
      icon: course.enrolled ? LucideIcons.check : Symbols.shopping_bag,
      enabled: controller.canAct,
      held: course.enrolled,
      onAction: () => CourseSheetBody.addToCart(context, controller),
      onBrochure: () => CourseSheetBody.openBrochure(context, course),
    );
  }
}

/// The cover with its badge; the demo's picture carries the design's own.
class _Cover extends StatelessWidget {
  const _Cover({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: 160,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CoursePicture(
              picture: course.cover,
              child: Center(
                child: Icon(Symbols.school_rounded, fill: 1, size: 40, color: Colors.white.withValues(alpha: 0.5)),
              ),
            ),
            if (course.badge != null)
              Positioned(left: CoverPill.left, bottom: CoverPill.bottom, child: CoverPill(course.badge!)),
          ],
        ),
      ),
    );
  }
}

/// "Face to Face On site Training | Live Virtual Training".
class _ModeTabs extends StatelessWidget {
  const _ModeTabs({required this.controller});

  final CourseSheetController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15.5),
      child: Column(
        children: [
          SizedBox(
            height: 14,
            child: Row(
              children: [
                for (final mode in DeliveryMode.values)
                  Expanded(
                    child: _ModeTab(
                      mode: mode,
                      active: controller.mode == mode,
                      alignment: mode == DeliveryMode.inPerson ? Alignment.centerLeft : Alignment.center,
                      onTap: () => controller.selectMode(mode),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 7.1),
          SizedBox(
            height: 3,
            child: Stack(
              children: [
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ColoredBox(color: LearningColors.tabRule, child: SizedBox(height: 1)),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Row(
                    children: [
                      for (final mode in DeliveryMode.values)
                        Expanded(
                          child: ColoredBox(
                            color: controller.mode == mode ? AppColors.primary : Colors.transparent,
                            child: const SizedBox(height: 2.5),
                          ),
                        ),
                    ],
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

class _ModeTab extends StatelessWidget {
  const _ModeTab({required this.mode, required this.active, required this.alignment, required this.onTap});

  final DeliveryMode mode;
  final bool active;
  final Alignment alignment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : LearningColors.tabInactive;
    return Semantics(
      button: true,
      selected: active,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Align(
          alignment: alignment,
          child: Padding(
            padding: EdgeInsets.only(left: mode == DeliveryMode.inPerson ? 4 : 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  mode == DeliveryMode.inPerson ? Symbols.groups : Symbols.devices,
                  size: mode == DeliveryMode.inPerson ? 20 : 16,
                  color: color,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    mode.label,
                    style: active ? LearningText.tab : LearningText.tabInactive,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Select Date ............ 2024 Schedule".
class _SelectDateRow extends StatelessWidget {
  const _SelectDateRow({required this.controller});

  final CourseSheetController controller;

  @override
  Widget build(BuildContext context) {
    final schedule = scheduleLabel(controller.runsInMode);
    return Padding(
      padding: const EdgeInsets.only(left: 16.5, right: 16.5),
      child: SizedBox(
        height: 16,
        child: Row(
          children: [
            Text('Select Date', style: LearningText.selectDate),
            const Spacer(),
            if (schedule != null)
              Semantics(
                button: true,
                child: GestureDetector(
                  key: const ValueKey('schedule-link'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => openUrl(context, controller.repository.link(controller.course)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Symbols.calendar_month, size: 13, weight: 700, color: AppColors.primary),
                      const SizedBox(width: 1.5),
                      Text(schedule, style: LearningText.schedule),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The 2 × n grid of runs, the "Suggest A Date" tile last.
class _RunGrid extends StatelessWidget {
  const _RunGrid({required this.controller});

  final CourseSheetController controller;

  @override
  Widget build(BuildContext context) {
    final runs = controller.shownRuns;
    final course = controller.course;
    final held = course.enrolment;
    final tiles = <Widget>[
      for (final run in runs)
        RunTile(
          run: run,
          selected: controller.selectedRun?.id == run.id,
          mine: held != null && held.status.active && held.runId == run.id ? held.status : null,
          onTap: () => controller.selectRun(run),
        ),
      SuggestDateTile(onTap: () => CourseSheetBody.suggestDate(context, controller)),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (runs.isEmpty) ...[
            Text('No ${controller.mode.label.toLowerCase()} dates are scheduled yet.', style: LearningText.tileEmpty),
            const SizedBox(height: 8),
          ],
          Wrap(spacing: 10.3, runSpacing: 8.5, children: tiles),
        ],
      ),
    );
  }
}

/// A course that schedules no runs: its own cohort date, or "on enquiry".
class _NoRuns extends StatelessWidget {
  const _NoRuns({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final starts = course.batchStartsAt;
    final parts = [
      if (starts != null) 'Next cohort starts ${runDates(starts, null)}' else 'Dates on enquiry',
      ?course.durationLabel,
      ?course.deliveryMode,
    ];
    return Row(
      children: [
        const Icon(LucideIcons.calendar, size: 13, color: AppColors.primary),
        const SizedBox(width: 6),
        Expanded(child: Text(parts.join(' • '), style: LearningText.tileDateQuiet)),
      ],
    );
  }
}

/// The wide buttons under the grid: filled blue, or white with a hairline.
class _WideButton extends StatelessWidget {
  const _WideButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.iconWeight,
    this.filled = false,
    this.held = false,
    this.enabled = true,
    this.height = 39,
  });

  final String label;
  final IconData icon;

  /// The weight of a Material Symbol (the design's glyphs are bold).
  final double? iconWeight;
  final VoidCallback onPressed;
  final bool filled;

  /// The member already holds a place: drawn solid, as done, not dimmed as unavailable.
  final bool held;
  final bool enabled;
  final double height;

  @override
  Widget build(BuildContext context) {
    final style = filled ? LearningText.primaryButton : LearningText.outlineButton;
    final live = enabled || held;
    final ink = live ? style.color! : style.color!.withValues(alpha: 0.6);
    return Material(
      color: filled ? (live ? AppColors.primary : AppColors.primary.withValues(alpha: 0.5)) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: filled ? BorderSide.none : const BorderSide(color: AppColors.outlineVariant),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: height,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, weight: iconWeight, color: ink),
              const SizedBox(width: 5.5),
              Text(label, style: style.copyWith(color: ink)),
            ],
          ),
        ),
      ),
    );
  }
}
