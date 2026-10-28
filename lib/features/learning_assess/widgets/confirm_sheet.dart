import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/detail_sheet.dart';
import '../assess_styles.dart';
import 'paper_card.dart';

/// A short sheet that asks before something is spent: a title that names what, a line of what it costs and what is
/// left, and two 48 dp buttons. Resolves true on the confirm button, false on Cancel or a swipe away.
Future<bool> showConfirmSheet(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  Color color = AppColors.primary,
}) async {
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _ConfirmSheet(title: title, body: body, confirmLabel: confirmLabel, color: color),
  );
  return confirmed == true;
}

class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({required this.title, required this.body, required this.confirmLabel, required this.color});

  final String title;
  final String body;
  final String confirmLabel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(height: 30, rule: false),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: AssessText.section),
                  const SizedBox(height: 8),
                  Text(body, style: AssessText.setBody),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ActionButton(
                          label: 'Cancel',
                          color: AppColors.slate600,
                          filled: false,
                          onPressed: () => Navigator.of(context).pop(false),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ActionButton(
                          label: confirmLabel,
                          color: color,
                          onPressed: () => Navigator.of(context).pop(true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
