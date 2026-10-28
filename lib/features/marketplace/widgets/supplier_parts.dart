import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../marketplace_styles.dart';

/// A part of a profile that could not be read: what happened, and a way to try again.
class InlineNotice extends StatelessWidget {
  const InlineNotice({super.key, required this.message, this.onRetry, this.retryLabel = 'Try again'});

  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.errorContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(message, style: MartText.sheetRow.copyWith(color: AppColors.onErrorContainer, fontSize: 13)),
          ),
          if (onRetry != null)
            TextButton(
              key: const ValueKey('retry'),
              onPressed: onRetry,
              child: Text(retryLabel, style: MartText.sheetLink),
            ),
        ],
      ),
    );
  }
}

/// A small spinner for a tab that is still loading.
class PartSpinner extends StatelessWidget {
  const PartSpinner({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 36),
    child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))),
  );
}

/// A line of the profile's "Good to know": a label and what it says.
class FactRow extends StatelessWidget {
  const FactRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 92, child: Text(label, style: MartText.factLabel)),
          Expanded(child: Text(value, style: MartText.factValue)),
        ],
      ),
    );
  }
}

/// Said under a list with nothing in it.
class EmptyPart extends StatelessWidget {
  const EmptyPart({super.key, required this.title, this.body});

  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 24),
      child: Column(
        children: [
          Text(title, textAlign: TextAlign.center, style: MartText.heading),
          if (body != null) ...[
            const SizedBox(height: 6),
            Text(body!, textAlign: TextAlign.center, style: MartText.body),
          ],
        ],
      ),
    );
  }
}

/// A 1 dp rule, inset from either edge when asked.
class Hairline extends StatelessWidget {
  const Hairline({super.key, this.indent = 0, this.endIndent = 0});

  final double indent;
  final double endIndent;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(left: indent, right: endIndent),
    child: const ColoredBox(
      color: MartColors.rule,
      child: SizedBox(height: 1, width: double.infinity),
    ),
  );
}
