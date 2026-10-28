import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../marketplace_links.dart';
import '../marketplace_models.dart';
import '../marketplace_navigation.dart';
import '../marketplace_styles.dart';
import 'market_sheets.dart';

/// "View Hubs": the supplier's offices, head office first, each with its place,
/// its address, a phone to call and its place on the map.
Future<void> showHubsSheet(BuildContext context, Supplier supplier) {
  return showMartSheet<void>(context, builder: (_) => HubsSheet(supplier: supplier));
}

class HubsSheet extends StatelessWidget {
  const HubsSheet({super.key, required this.supplier});

  final Supplier supplier;

  @override
  Widget build(BuildContext context) {
    final hubs = [...supplier.hubs.where((h) => h.headOffice), ...supplier.hubs.where((h) => !h.headOffice)];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text('${supplier.name} offices', style: MartText.sheetTitle),
          const SizedBox(height: 4),
          Text(hubs.length == 1 ? '1 operating hub' : '${hubs.length} operating hubs', style: MartText.sheetRowMuted),
          const SizedBox(height: 12),
          if (hubs.isEmpty) Text('This supplier has not listed an office yet.', style: MartText.sheetRowMuted),
          for (final hub in hubs) _HubCard(hub: hub),
        ],
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  const _HubCard({required this.hub});

  final SupplierHub hub;

  @override
  Widget build(BuildContext context) {
    final links = MarketplaceScope.linksOf(context);
    final place = [?hub.address, if (hub.place.isNotEmpty) hub.place].join(', ');
    final map = hub.latitude != null && hub.longitude != null
        ? Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': '${hub.latitude},${hub.longitude}'})
        : (place.isEmpty
              ? null
              : Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': '${hub.name} $place'}));
    return Container(
      key: ValueKey('hub-${hub.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
      decoration: BoxDecoration(
        border: Border.all(color: MartColors.cardBorder, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(hub.name, style: MartText.serviceName)),
              if (hub.headOffice)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(8)),
                  child: Text('Head office', style: MartText.groupChip.copyWith(fontSize: 12)),
                ),
            ],
          ),
          if (place.isNotEmpty) ...[const SizedBox(height: 3), Text(place, style: MartText.sheetRowMuted)],
          const SizedBox(height: 6),
          Row(
            children: [
              if (hub.phone != null)
                TextButton.icon(
                  key: ValueKey('hub-call-${hub.id}'),
                  onPressed: () => links.call(context, hub.phone!),
                  icon: const Icon(LucideIcons.phone, size: 14),
                  label: Text(hub.phone!, style: MartText.sheetLink),
                ),
              const Spacer(),
              if (map != null)
                TextButton.icon(
                  key: ValueKey('hub-map-${hub.id}'),
                  onPressed: () => links.openUri(context, map),
                  icon: const Icon(LucideIcons.mapPin, size: 14),
                  label: Text('Map', style: MartText.sheetLink),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
