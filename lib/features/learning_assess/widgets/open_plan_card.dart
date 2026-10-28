import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../assess_format.dart';
import '../assess_models.dart';
import '../assess_styles.dart';
import 'paper_card.dart';

/// Above a programme's levels or a mock subject's sets: open the whole thing with one of the plan's places while
/// the plan has one (every level or set opens with it), else what ICR credits and a payment do, a level or set at
/// a time. Once the plan opened it, one line says so. Nothing for staff, or a plan that opens every one.
///
/// The website's `LearningOpenCard`, in its words.
class OpenPlanCard extends StatelessWidget {
  const OpenPlanCard({
    super.key,
    required this.kind,
    required this.access,
    required this.state,
    required this.opening,
    required this.anyPriced,
    required this.allPriced,
    required this.onOpen,
    required this.onSeePlans,
    required this.onEarnMore,
  });

  final PaperKind kind;
  final MemberAccess access;
  final PlaceState state;
  final bool opening;

  /// Some of its levels or sets can be bought one at a time; all of them can.
  final bool anyPriced;
  final bool allPriced;
  final VoidCallback onOpen;
  final VoidCallback onSeePlans;
  final VoidCallback onEarnMore;

  bool get _exam => kind == PaperKind.mock;

  @override
  Widget build(BuildContext context) {
    final places = access.places(kind);
    final limit = places.limit;
    if (access.allOpen || limit == null) return const SizedBox.shrink();

    if (state == PlaceState.open) {
      return Container(
        key: const ValueKey('plan-opened'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AssessColors.successWash,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.emerald200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(LucideIcons.circleCheck, size: 20, color: AppColors.successInk),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _exam
                    ? 'This mock exam is open with your plan: every set is yours to sit.'
                    : 'This course is open with your plan: every level is yours to sit.',
                style: AssessText.noticeBody.copyWith(color: AppColors.onSurface),
              ),
            ),
          ],
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
    return Container(
      key: const ValueKey('plan-open-card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x081D63A3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x591D63A3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(pick ? 'Open this $noun' : (_exam ? 'Unlock a set' : 'Unlock a level'), style: AssessText.section),
          const SizedBox(height: 4),
          Text(
            pick
                ? (_exam
                      ? 'Open the whole exam first: every set opens with it.'
                      : 'Open the whole course first: every level opens with it.')
                : (_exam
                      ? 'Each set opens on its own: redeem ICR credits or pay for it below.'
                      : 'Each level opens on its own: redeem ICR credits or pay for it below.'),
            style: AssessText.sectionHint,
          ),
          const SizedBox(height: 12),
          _Line(icon: LucideIcons.award, text: planLine, textKey: const ValueKey('plan-line')),
          if (!pick) ...[
            const SizedBox(height: 8),
            _Line(
              icon: LucideIcons.coins,
              textKey: const ValueKey('credits-line'),
              text:
                  'You have ${creditsLabel(access.icrCredits)}. 1 credit = ${rupees(access.rupeesPerCredit * 100)}: '
                  'a ${_exam ? 'set' : 'level'} costs its price in credits, or the credits set on it.',
              trailing: access.icrCredits == 0
                  ? GestureDetector(
                      onTap: onEarnMore,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('Invite colleagues to earn more', style: AssessText.noteLink),
                      ),
                    )
                  : null,
            ),
          ],
          if (pick) ...[
            const SizedBox(height: 14),
            ActionButton(
              label: opening ? 'Opening…' : 'Open with my plan',
              color: AppColors.primary,
              icon: LucideIcons.lockOpen,
              loading: opening,
              onPressed: opening ? null : onOpen,
            ),
          ] else if (offerPlans) ...[
            const SizedBox(height: 14),
            ActionButton(
              label: upgrade == null ? 'See plans' : 'See $upgrade',
              color: AppColors.primary,
              icon: LucideIcons.externalLink,
              filled: false,
              onPressed: onSeePlans,
            ),
          ],
          if (!pick && anyPriced) ...[
            const SizedBox(height: 10),
            Text(
              _exam
                  ? (allPriced
                        ? 'Or buy a single set below, without opening the whole exam.'
                        : 'Some sets below can also be bought on their own, without opening the whole exam.')
                  : (allPriced
                        ? 'Or pay for a single level below, without opening the whole course.'
                        : 'Some levels below can also be paid for on their own, without opening the whole course.'),
              style: AssessText.sectionHint,
            ),
          ],
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text, this.trailing, this.textKey});

  final IconData icon;
  final String text;
  final Widget? trailing;
  final Key? textKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text, key: textKey, style: AssessText.progressTitle),
              ?trailing,
            ],
          ),
        ),
      ],
    );
  }
}

/// "You enrolled into this course “Capital Planning” – “Foundation” with ICR referral credits." (the owner's wording).
class RedeemedNote extends StatelessWidget {
  const RedeemedNote({super.key, required this.group, required this.papers});

  final PaperGroup group;
  final List<AssessPaper> papers;

  @override
  Widget build(BuildContext context) {
    if (papers.isEmpty) return const SizedBox.shrink();
    final noun = group.kind == PaperKind.mock ? 'mock exam' : 'course';
    return Column(
      key: const ValueKey('redeemed-notes'),
      children: [
        for (final p in papers)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AssessColors.successWash,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.emerald200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(LucideIcons.circleCheck, size: 18, color: AppColors.successInk),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'You enrolled into this $noun “${group.title}” – “${p.levelName ?? p.title}” with ICR referral credits.',
                    style: AssessText.noticeBody.copyWith(color: AppColors.onSurface),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
