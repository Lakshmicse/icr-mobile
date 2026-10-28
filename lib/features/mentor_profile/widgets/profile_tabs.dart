import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../mentor_profile_controller.dart';
import '../mentor_profile_styles.dart';

/// Overview | Offerings | Recommendations: a bordered strip with the open
/// tab on a blue pill. 39.8 dp tall, the pill 31.8 inside it.
class ProfileTabs extends StatelessWidget {
  const ProfileTabs({super.key, required this.selected, required this.onSelect});

  static const labels = {
    ProfileTab.overview: 'Overview',
    ProfileTab.offerings: 'Offerings',
    ProfileTab.recommendations: 'Recommendations',
  };

  final ProfileTab selected;
  final ValueChanged<ProfileTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(9.1, 0, 10.2, 0),
      child: Container(
        height: 39.8,
        padding: const EdgeInsets.only(left: 5.1),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Row(
          children: [
            for (final (i, tab) in ProfileTab.values.indexed) ...[
              if (i > 0) const SizedBox(width: 3),
              _Tab(label: labels[tab]!, selected: tab == selected, onTap: () => onSelect(tab)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 31.8,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.6),
              child: Center(
                widthFactor: 1,
                child: Text(label, style: selected ? MentorText.tabSelected : MentorText.tab),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
