import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../mentor_profile_format.dart';
import '../mentor_profile_models.dart';
import '../mentor_profile_styles.dart';

/// The dark "flagship" card at the foot of every tab: the mentor's ongoing
/// plan with its price, what it includes and the way in. Full width, 224 dp.
class PlanCard extends StatelessWidget {
  const PlanCard({super.key, required this.plan, required this.onApply});

  final MentorOffering plan;
  final VoidCallback onApply;

  /// The design's gradient: CSS `linear-gradient(150deg, …)`.
  static const _stops = [0.0, 0.5, 1.0];
  static const _colors = [MentorColors.navyDeep, Color(0xFF014B83), Color(0xFF1C62A2)];

  List<String> get _lines {
    if (plan.inclusions.isNotEmpty) return plan.inclusions.take(4).toList();
    final sessions = plan.sessionsPerMonth;
    return [
      if (sessions != null && sessions > 0)
        '$sessions live 1:1 session${sessions == 1 ? '' : 's'} each month'
            '${plan.sessionDurationMin == null ? '' : ' of ${plan.sessionDurationMin} min'}',
      if (plan.billingPeriodMonths != null)
        'Paid per ${plan.billingPeriodMonths == 1 ? 'month' : '${plan.billingPeriodMonths}-month term'}, never auto-renewed',
      'Private thread with the mentor between sessions',
    ];
  }

  @override
  Widget build(BuildContext context) {
    final price = plan.perMonthPaisa ?? plan.pricePaisa;
    return LayoutBuilder(
      builder: (context, box) {
        // CSS gradients run along an angle with their length sized to the box.
        const angle = 150 * math.pi / 180;
        final dx = math.sin(angle);
        final dy = -math.cos(angle);
        final w = box.maxWidth;
        const h = 224.6;
        final length = w * dx.abs() + h * dy.abs();
        final ax = dx * length / 2 / (w / 2);
        final ay = dy * length / 2 / (h / 2);
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18.2, 13.9, 17.6, 0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-ax, -ay),
              end: Alignment(ax, ay),
              colors: _colors,
              stops: _stops,
            ),
          ),
          height: h,
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 26.7,
                    padding: const EdgeInsets.symmetric(horizontal: 12.2),

                    decoration: BoxDecoration(color: MentorColors.planKicker, borderRadius: BorderRadius.circular(4)),
                    child: Center(
                      widthFactor: 1,
                      child: Text(plan.planKicker ?? 'ONGOING PLAN', style: MentorText.planKicker),
                    ),
                  ),
                  const SizedBox(height: 6.9),
                  SizedBox(
                    height: 19,
                    child: Text(plan.title, style: MentorText.planTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(height: 16.5),
                  for (final (i, line) in _lines.indexed) ...[
                    if (i > 0) const SizedBox(height: 12.8),
                    SizedBox(
                      height: 17,
                      child: Row(
                        children: [
                          const _Check(),
                          const SizedBox(width: 5.1),
                          Expanded(
                            child: Text(line, style: MentorText.planLine, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              Positioned(
                right: 0,
                top: 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SizedBox(
                      height: 17,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(price == 0 ? 'FREE' : inr(price), style: MentorText.planPrice),
                          if (price > 0) ...[const SizedBox(width: 4.7), Text('/mo', style: MentorText.planPer)],
                        ],
                      ),
                    ),
                    if (plan.seatsNote != null) ...[
                      const SizedBox(height: 9.6),
                      Container(
                        height: 26.7,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: MentorColors.pinkPill,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(widthFactor: 1, child: Text(plan.seatsNote!, style: MentorText.planSeats)),
                      ),
                    ],
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 155.7,
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: onApply,
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      height: 43.2,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(plan.applyLabel ?? 'Apply for ${plan.title}', style: MentorText.planButton),
                          const SizedBox(width: 4),
                          const Icon(LucideIcons.arrowRight, size: 12, color: AppColors.primary),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Check extends StatelessWidget {
  const _Check();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 11.4,
      height: 11.4,
      decoration: const BoxDecoration(color: MentorColors.planPrice, shape: BoxShape.circle),
      child: const Icon(LucideIcons.check, size: 7.5, color: MentorColors.navyDeep),
    );
  }
}
