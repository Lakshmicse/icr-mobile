import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';

/// The empty, error and locked states of the study screens: a glyph, a heading, a sentence and up to two buttons.
class StudyNotice extends StatelessWidget {
  const StudyNotice({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    this.onAction,
    this.secondary,
    this.onSecondary,
    this.tint = AppColors.outline,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;
  final String? secondary;
  final VoidCallback? onSecondary;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 40, 32, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: tint),
            const SizedBox(height: 14),
            Text(title, textAlign: TextAlign.center, style: AppText.postTitle.copyWith(fontSize: 16, height: 1.3)),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center, style: AppText.small.copyWith(fontSize: 14, height: 1.45)),
            if (action != null) ...[
              const SizedBox(height: 20),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: onAction,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(action!, textAlign: TextAlign.center, style: AppText.button.copyWith(fontSize: 14)),
                ),
              ),
            ],
            if (secondary != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: TextButton(
                  onPressed: onSecondary,
                  child: Text(secondary!, style: AppText.link.copyWith(fontSize: 14)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
