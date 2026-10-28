import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../catalog_models.dart';
import '../marketplace_styles.dart';

/// Under the toolbar while a search is on: the services and requirements the
/// words also match, so a search for "duct cleaning" finds the supplier, the
/// service and the buyer asking for it.
class SearchExtrasSection extends StatelessWidget {
  const SearchExtrasSection({
    super.key,
    required this.query,
    required this.extras,
    required this.onService,
    required this.onRfq,
  });

  final String query;
  final SearchExtras extras;
  final ValueChanged<CatalogService> onService;
  final ValueChanged<RfqHit> onRfq;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (extras.services.isNotEmpty) ...[
            Text('Services matching "$query"', style: MartText.sheetSection),
            const SizedBox(height: 6),
            for (final s in extras.services)
              _Row(
                key: ValueKey('extra-service-${s.id}'),
                icon: LucideIcons.wrench,
                title: s.name,
                line: [?s.supplierName, ?s.rateLabel].join(' • '),
                onTap: () => onService(s),
              ),
          ],
          if (extras.rfqs.isNotEmpty) ...[
            if (extras.services.isNotEmpty) const SizedBox(height: 10),
            Text('Requirements matching "$query"', style: MartText.sheetSection),
            const SizedBox(height: 6),
            for (final r in extras.rfqs)
              _Row(
                key: ValueKey('extra-rfq-${r.id}'),
                icon: LucideIcons.fileText,
                title: r.title,
                line: [?r.city, if (r.mine) 'Your requirement'].join(' • '),
                onTap: () => onRfq(r),
              ),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({super.key, required this.icon, required this.title, required this.line, required this.onTap});

  final IconData icon;
  final String title;
  final String line;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, size: 16, color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: MartText.sheetRow, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (line.isNotEmpty)
                    Text(line, style: MartText.sheetRowMuted, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.outline),
          ],
        ),
      ),
    );
  }
}
