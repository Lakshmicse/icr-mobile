import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../account_labels.dart';
import '../account_models.dart';
import '../widgets/account_kit.dart';
import 'company_words.dart';

/// "Is your company already on ICR?": companies that look like the one being
/// created (the same name without its legal form, the same website, or
/// colleagues on the person's own email domain). Joining beats a second copy,
/// which splits the team, the jobs and the reviews, so each offers "Ask to
/// join". A suggestion only: it never blocks creating the page.
class LookalikesCard extends StatelessWidget {
  const LookalikesCard({
    super.key,
    required this.companies,
    required this.asked,
    required this.onAsk,
    this.onView,
  });

  final List<CompanyLookalike> companies;

  /// Ids of the companies a request has already gone to.
  final Set<String> asked;
  final void Function(CompanyLookalike company) onAsk;
  final void Function(String companyId)? onView;

  @override
  Widget build(BuildContext context) {
    if (companies.isEmpty) return const SizedBox.shrink();
    return Container(
      key: const Key('create.lookalikes'),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FE),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFB9D8F4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Is your company already on ICR?', style: AccountText.itemTitle),
          const SizedBox(height: 2),
          Text(
            'Ask to join it instead of creating a second page. A duplicate splits your team, jobs and reviews. '
            'Its admins decide.',
            style: AccountText.meta,
          ),
          const SizedBox(height: 10),
          for (final c in companies) _row(context, c),
          const SizedBox(height: 2),
          Text('Not yours? Carry on below. This is only a suggestion.', style: AccountText.meta),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, CompanyLookalike c) {
    final sent = asked.contains(c.id);
    final facts = [
      ?CompanyWords.place(c.city, c.state),
      ?(c.industry == null ? null : industryLabel(c.industry)),
      c.reasonLabel,
    ].join(' · ');
    return Padding(
      key: Key('lookalike.${c.id}'),
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CompanyLogo(url: c.logoUrl, name: c.name, size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: AccountText.itemTitle),
                    Text(facts, maxLines: 2, overflow: TextOverflow.ellipsis, style: AccountText.meta),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 50),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (sent)
                  AccountChip(
                    key: Key('lookalike.sent.${c.id}'),
                    label: 'Request sent',
                    color: AppColors.emerald50,
                    ink: AppColors.emerald700,
                  )
                else
                  AccountButton(
                    key: Key('lookalike.ask.${c.id}'),
                    label: 'Ask to join',
                    outlined: true,
                    expand: false,
                    height: 36,
                    onPressed: () => onAsk(c),
                  ),
                if (onView != null)
                  TextButton(
                    key: Key('lookalike.view.${c.id}'),
                    onPressed: () => onView!(c.id),
                    child: const Text('View page'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
