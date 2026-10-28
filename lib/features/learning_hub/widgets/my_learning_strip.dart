import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../learning/widgets/course_card.dart';
import '../hub_styles.dart';
import 'hub_parts.dart';

/// What the strip needs to say about one of the member's places.
class MyLearningStat {
  const MyLearningStat({required this.value, required this.loading});

  /// Null when the count is unknown (still loading, or a refused read).
  final int? value;
  final bool loading;
}

/// "My learning": the member's places in the Learning Center as three tiles on
/// the Events screen's member tiles (white, 10 dp corners, a 1 dp edge): the
/// courses they hold a place on, their attempts and their certificates. Each
/// opens the screen that lists them.
class MyLearningStrip extends StatelessWidget {
  const MyLearningStrip({
    super.key,
    required this.courses,
    required this.attempts,
    required this.certificates,
    required this.onCourses,
    required this.onAttempts,
    required this.onCertificates,
  });

  final MyLearningStat courses;
  final MyLearningStat attempts;
  final MyLearningStat certificates;
  final VoidCallback onCourses;
  final VoidCallback onAttempts;
  final VoidCallback onCertificates;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: CourseGridRow.padding,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _StatTile(
                key: const ValueKey('my-learning-courses'),
                icon: LucideIcons.graduationCap,
                label: 'My courses',
                note: 'places held',
                stat: courses,
                onTap: onCourses,
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: _StatTile(
                key: const ValueKey('my-learning-attempts'),
                icon: LucideIcons.clipboardCheck,
                label: 'My attempts',
                note: 'papers taken',
                stat: attempts,
                onTap: onAttempts,
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: _StatTile(
                key: const ValueKey('my-learning-certificates'),
                icon: LucideIcons.award,
                label: 'Certificates',
                note: 'earned',
                stat: certificates,
                onTap: onCertificates,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.note,
    required this.stat,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String note;
  final MyLearningStat stat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final value = stat.value;
    final shown = value?.toString() ?? '–';
    return Semantics(
      button: true,
      label: value == null ? label : '$label, $value $note',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: HubColors.border),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 8, 8.5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 13,
                  child: Row(
                    children: [
                      Icon(icon, size: 12, color: AppColors.tertiary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(label, style: HubText.tileLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 26,
                  child: stat.loading && value == null
                      ? const Align(
                          alignment: Alignment.centerLeft,
                          child: HubSkeleton(width: 28, height: 18, radius: 4),
                        )
                      : Text(shown, style: HubText.tileCount),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(note, style: HubText.tileNote, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    const Icon(LucideIcons.chevronRight, size: 12, color: HubColors.link),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
