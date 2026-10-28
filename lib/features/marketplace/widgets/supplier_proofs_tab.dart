import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/util/links.dart' show showMessage;
import '../marketplace_models.dart';
import '../marketplace_styles.dart';
import '../supplier_controller.dart';
import 'rate_sheet.dart';
import 'supplier_parts.dart';

/// "Compliances & Proofs": what the company holds that ICR shows buyers, and
/// the ratings members have left. The API publishes no name with a rating, so a
/// proof reads "Verified buyer" where the design has the reviewer's company.
class SupplierProofsTab extends StatelessWidget {
  const SupplierProofsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<SupplierController>();
    final part = c.compliances;
    final s = c.supplier;
    final rows = part.value ?? const <Compliance>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Hairline(),
        const SizedBox(height: 19.5),
        Padding(
          padding: const EdgeInsets.fromLTRB(15.5, 0, 15, 0),
          child: SizedBox(
            height: 20,
            child: Row(
              children: [
                Expanded(child: Text('Compliances & Audited Proofs', style: MartText.sectionTitle)),
                const Icon(LucideIcons.badgeCheck, size: 20, color: AppColors.tertiary),
              ],
            ),
          ),
        ),
        const SizedBox(height: 9.5),
        if (part.loading && !part.loaded)
          const PartSpinner()
        else if (part.error != null && !part.loaded)
          InlineNotice(message: part.error!, onRetry: () => c.reload(SupplierTab.proofs))
        else if (rows.isEmpty) ...[
          const Hairline(indent: 15, endIndent: 15),
          const EmptyPart(
            title: 'No compliances on file',
            body: 'This supplier has not recorded a licence, certification or policy that ICR shows buyers.',
          ),
        ] else
          for (final (i, row) in rows.indexed)
            ComplianceRow(key: ValueKey('compliance-${row.id}'), compliance: row, first: i == 0),
        const SizedBox(height: 19.5),
        Padding(
          padding: const EdgeInsets.fromLTRB(15.5, 0, 15, 0),
          child: Text('Audited Enterprise Proofs', style: MartText.sectionTitle),
        ),
        const SizedBox(height: 4.25),
        if (s.reviews.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              s.ratingCount > 0
                  ? '${s.reviewsLabel}, none written up yet.'
                  : 'No ratings yet. Be the first to rate ${s.name}.',
              style: MartText.body,
            ),
          )
        else
          for (final r in s.reviews) ProofItem(key: ValueKey('proof-${r.id}'), review: r),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OutlinedButton.icon(
            key: const ValueKey('rate-supplier'),
            onPressed: () => showRateSheet(context),
            icon: const Icon(LucideIcons.star, size: 15),
            label: Text('Rate this supplier', style: MartText.sheetLink),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(38),
              side: const BorderSide(color: MartColors.cardBorder, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }
}

/// The glyph at the left of a compliance row.
IconData complianceIcon(ComplianceGlyph glyph) => switch (glyph) {
  ComplianceGlyph.licence => Symbols.military_tech,
  ComplianceGlyph.quality => Symbols.verified_user,
  ComplianceGlyph.safety => Symbols.health_and_safety,
  ComplianceGlyph.insurance => Symbols.assured_workload,
  ComplianceGlyph.green => Symbols.eco,
  ComplianceGlyph.membership => Symbols.groups,
  ComplianceGlyph.generic => Symbols.verified,
};

Color complianceColor(ComplianceGlyph glyph) => switch (glyph) {
  ComplianceGlyph.licence || ComplianceGlyph.safety => AppColors.primary,
  ComplianceGlyph.quality || ComplianceGlyph.green => AppColors.tertiary,
  _ => AppColors.onSurface,
};

class ComplianceRow extends StatelessWidget {
  const ComplianceRow({super.key, required this.compliance, this.first = false});

  final Compliance compliance;

  /// The first row sits tight under its heading; every other row is at least 58 dp tall, as the design's.
  final bool first;

  @override
  Widget build(BuildContext context) {
    final c = compliance;
    final detail = c.detail;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: MartColors.rule, width: 1)),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: first ? 0 : 58),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 10.5, 20.75, 5.5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 57.5,
                  child: Center(
                    child: Icon(complianceIcon(c.glyph), size: 17, color: complianceColor(c.glyph), weight: 500),
                  ),
                ),
                // The title takes what the status leaves it, less a gap of 87 dp (the design wraps "Escrow & Trade Assurance
                // Policy" and not "DGCA Commercial Drone License", which is wider, because "Insured" is wider than "Active").
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 87),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.title, style: MartText.proofTitle),
                        if (detail != null) ...[
                          const SizedBox(height: 0),
                          // A licence number runs on; a sentence keeps to about 147 dp.
                          if (c.detailIsNumber)
                            Text(detail, style: MartText.proofNumber, maxLines: 1)
                          else
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 147),
                              child: Text(detail, style: MartText.proofDetail),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
                Text(
                  c.status,
                  style: c.tone == ComplianceTone.positive ? MartText.proofStatus : MartText.proofStatusPlain,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A rating as the design's "Audited Enterprise Proofs" lay a client out: who it
/// is, what they are, five stars at the right, and what they said in italics.
class ProofItem extends StatelessWidget {
  const ProofItem({super.key, required this.review});

  final SupplierReview review;

  @override
  Widget build(BuildContext context) {
    final r = review;
    final who = r.byline ?? 'Verified buyer';
    final role = r.role ?? _memberLine(r);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: MartColors.rule, width: 1)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8.5, 13.25, 8, 7.75),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Who and what they are on the left, the stars centred against both.
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 150),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(who, style: MartText.proofBy),
                            if (role != null) ...[const SizedBox(height: 1), Text(role, style: MartText.proofRole)],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Stars(score: r.score),
                ],
              ),
              if (r.written) ...[
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: Text('"${r.comment!.trim()}"', style: MartText.proofQuote),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// With no reviewer line from the API: "ICR member • Oct 2026", from when it was left.
  static String? _memberLine(SupplierReview r) {
    final at = r.createdAt;
    if (at == null) return 'ICR member';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return 'ICR member • ${months[at.toLocal().month - 1]} ${at.toLocal().year}';
  }
}

/// Five stars, [score] of them filled.
class Stars extends StatelessWidget {
  const Stars({super.key, required this.score, this.size = 13});

  final int score;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$score out of 5 stars',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 1; i <= 5; i++)
              Icon(Icons.star, size: size, color: i <= score ? MartColors.profileStar : AppColors.outlineVariant),
          ],
        ),
      ),
    );
  }
}

/// Shown when the sheet has something to say about a rating the member left.
void showRated(BuildContext context) => showMessage(context, 'Thanks, your rating is saved.');
