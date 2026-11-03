import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../assess_format.dart';
import '../assess_models.dart';
import '../assess_styles.dart';
import 'paper_card.dart';

/// Under a programme's levels or a mock subject's sets, in a line: what the member's plan does here. Open the whole
/// thing with one of the plan's places while the plan has one (every level or set opens with it); once it has,
/// that it is open; else that the plan does not include it, with the plan that would. Nothing for staff, or a plan
/// that opens every one.
///
/// The website's `LearningOpenCard`, in its words, without the box (owner, 3 Nov 2026: no borders, and the "See
/// plans" banner was too large). The member's ICR credits are said once over the rows, not here.
class OpenPlanCard extends StatelessWidget {
  const OpenPlanCard({
    super.key,
    required this.kind,
    required this.access,
    required this.state,
    required this.opening,
    required this.onOpen,
    required this.onSeePlans,
  });

  final PaperKind kind;
  final MemberAccess access;
  final PlaceState state;
  final bool opening;
  final VoidCallback onOpen;
  final VoidCallback onSeePlans;

  bool get _exam => kind == PaperKind.mock;

  @override
  Widget build(BuildContext context) {
    final places = access.places(kind);
    final limit = places.limit;
    if (access.allOpen || limit == null) return const SizedBox.shrink();

    if (state == PlaceState.open) {
      return Padding(
        key: const ValueKey('plan-opened'),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: _Line(
          icon: LucideIcons.circleCheck,
          color: AppColors.successInk,
          text: _exam
              ? 'This mock exam is open with your plan: every set is yours to sit.'
              : 'This course is open with your plan: every level is yours to sit.',
        ),
      );
    }

    final pick = state == PlaceState.pick;
    final upgrade = _exam ? access.mockUpgradePlan : access.upgradePlan;
    // No plan that would open a mock exam: no upgrade link on its page.
    final offerPlans = !_exam || upgrade != null;
    final noun = _exam ? 'mock exam' : 'course';
    final left = places.left ?? 0;
    final planLine = limit == 0
        ? (_exam
              ? 'Mock exams are not included in your plan.'
              : 'Assess your knowledge courses are not included in your plan.')
        : pick
        ? 'Your plan includes ${plural(limit, noun, '${noun}s')}, and ${left == 1 ? '1 is' : '$left are'} still free.'
        : (limit == 1
              ? 'You have opened the 1 $noun your plan includes.'
              : 'You have opened all $limit ${noun}s your plan includes.');

    if (pick) {
      return Padding(
        key: const ValueKey('plan-open-card'),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Line(
              icon: LucideIcons.award,
              color: AppColors.primary,
              text: '$planLine ${_exam ? 'Every set opens with it.' : 'Every level opens with it.'}',
              textKey: const ValueKey('plan-line'),
            ),
            const SizedBox(height: 10),
            RowButton(
              label: opening ? 'Opening…' : 'Open with my plan',
              color: AppColors.primary,
              icon: LucideIcons.lockOpen,
              loading: opening,
              onPressed: opening ? null : onOpen,
            ),
          ],
        ),
      );
    }

    return Padding(
      key: const ValueKey('plan-open-card'),
      padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
      child: Row(
        children: [
          Expanded(
            child: _Line(
              icon: LucideIcons.award,
              color: AppColors.primary,
              text: planLine,
              textKey: const ValueKey('plan-line'),
            ),
          ),
          if (offerPlans)
            TextButton(
              onPressed: onSeePlans,
              child: Text(upgrade == null ? 'See plans' : 'See $upgrade', style: AssessText.noteLink),
            ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.color, required this.text, this.textKey});

  final IconData icon;
  final Color color;
  final String text;
  final Key? textKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, key: textKey, style: AssessText.noticeBody.copyWith(color: AppColors.onSurface))),
      ],
    );
  }
}
