import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/util/links.dart';
import '../course_sheet_controller.dart';
import '../learning_format.dart';
import '../learning_models.dart';
import '../learning_styles.dart';

/// The member's place on the course, where "add to cart" was: what it is and what happens next, and "Withdraw"
/// to take it back, as the website's enrolment panel shows a place once it is held. A paid place is withdrawn by
/// ICR, so the API's refusal is shown here in its own words.
class PlaceStatus extends StatelessWidget {
  const PlaceStatus({super.key, required this.controller});

  final CourseSheetController controller;

  @override
  Widget build(BuildContext context) {
    final course = controller.course;
    final status = course.enrolment?.status ?? EnrolmentStatus.pending;
    final (fill, edge, icon, ink) = switch (status) {
      EnrolmentStatus.confirmed || EnrolmentStatus.completed => (
        AppColors.emerald50,
        AppColors.emerald200,
        LucideIcons.circleCheck,
        AppColors.emerald700,
      ),
      EnrolmentStatus.waitlisted => (AppColors.amber50, AppColors.amber100, LucideIcons.clock, AppColors.amber800),
      _ => (const Color(0xFFEFF5FC), const Color(0xFFCFE0F2), LucideIcons.info, AppColors.primary),
    };
    final refusal = controller.withdrawError;
    return Column(
      key: const ValueKey('place-status'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: edge),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(icon, size: 16, color: ink),
              ),
              const SizedBox(width: 9),
              Expanded(child: Text(placeStatusLine(course), style: LearningText.placeNote)),
            ],
          ),
        ),
        if (refusal != null) ...[
          const SizedBox(height: 8),
          Container(
            key: const ValueKey('withdraw-refused'),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF5FC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCFE0F2)),
            ),
            child: Text(refusal, style: LearningText.placeNote),
          ),
        ],
        if (controller.canWithdraw) ...[
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              key: const ValueKey('withdraw'),
              onPressed: controller.withdrawing ? null : () => withdrawPlace(context, controller),
              style: TextButton.styleFrom(foregroundColor: AppColors.error, minimumSize: const Size(0, 40)),
              child: controller.withdrawing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.error),
                    )
                  : Text('Withdraw', style: LearningText.withdraw),
            ),
          ),
        ],
      ],
    );
  }
}

/// Asks once, then takes the place back. A confirmed place is given up, so it says so; a request or a waitlist
/// place is only taken back. Leaves a sentence when the API refuses.
Future<void> withdrawPlace(BuildContext context, CourseSheetController controller) async {
  final course = controller.course;
  final status = course.enrolment?.status;
  final held = status == EnrolmentStatus.confirmed;
  final sure = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(held ? 'Withdraw your place?' : 'Withdraw your request?'),
      content: Text(
        held
            ? 'You will give up your place on ${course.title}. You can ask for one again afterwards, if seats remain.'
            : 'Your request for ${course.title} will be taken back. You can ask for a place again afterwards.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialog).pop(false), child: const Text('Keep it')),
        TextButton(
          onPressed: () => Navigator.of(dialog).pop(true),
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: const Text('Withdraw'),
        ),
      ],
    ),
  );
  if (sure != true || !context.mounted) return;
  final refused = await controller.withdraw();
  if (refused != null || !context.mounted) return;
  showMessage(context, held ? 'Your place was withdrawn.' : 'Your request was withdrawn.');
}
