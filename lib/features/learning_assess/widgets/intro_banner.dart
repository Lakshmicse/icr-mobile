import 'package:flutter/material.dart';

import '../assess_styles.dart';

/// The navy banner under the toolbar: what the door is, in the website's words, and its steps as small chips
/// (the levels of the assessment ladder, or assess / improve / practice).
class IntroBanner extends StatelessWidget {
  const IntroBanner({
    super.key,
    required this.eyebrow,
    required this.headline,
    required this.body,
    required this.steps,
  });

  final String eyebrow;
  final String headline;
  final String body;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AssessColors.navy, AssessColors.navyMid],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(eyebrow, style: AssessText.bannerEyebrow),
          Text(headline, style: AssessText.bannerHeadline),
          const SizedBox(height: 8),
          Text(body, style: AssessText.bannerBody),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (i, step) in steps.indexed)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0x26FFFFFF), borderRadius: BorderRadius.circular(999)),
                  child: Text('${i + 1}  $step', style: AssessText.bannerStep),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
