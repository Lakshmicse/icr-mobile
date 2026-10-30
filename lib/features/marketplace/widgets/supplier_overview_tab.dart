import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../marketplace_models.dart';
import '../marketplace_styles.dart';
import '../supplier_controller.dart';
import 'hubs_sheet.dart';
import 'supplier_parts.dart';

/// The Overview tab: the track record in four tiles, the company's own
/// description, the hubs band, and what else a buyer asks first.
class SupplierOverviewTab extends StatefulWidget {
  const SupplierOverviewTab({super.key});

  @override
  State<SupplierOverviewTab> createState() => _SupplierOverviewTabState();
}

class _SupplierOverviewTabState extends State<SupplierOverviewTab> {
  bool _charter = false;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<SupplierController>();
    final s = c.supplier;
    final tiles = s.trackRecord;
    final about = s.about?.trim();
    final dispatch = s.dispatch;
    final facts = supplierFacts(s);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (c.detail.error != null && !c.hasDetail)
          InlineNotice(message: c.detail.error!, onRetry: () => c.reload(SupplierTab.overview)),
        if (tiles.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text('Enterprise Track Record', style: MartText.heading),
          ),
          const SizedBox(height: 3.5),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: _Tiles(tiles: tiles),
          ),
        ],
        if (about != null && about.isNotEmpty) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('About Organization', style: MartText.heading),
          ),
          const SizedBox(height: 6.25),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _About(text: about, expanded: _charter, onToggle: () => setState(() => _charter = !_charter)),
          ),
        ],
        if (dispatch != null) ...[const SizedBox(height: 26.25), _DispatchBand(band: dispatch, supplier: s)],
        if (facts.isNotEmpty) ...[
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Good to know', style: MartText.heading),
          ),
          const SizedBox(height: 4),
          for (final fact in facts) FactRow(label: fact.$1, value: fact.$2),
        ],
      ],
    );
  }
}

/// What a buyer asks next, from what the listing declares: only the facts it has.
List<(String, String)> supplierFacts(Supplier s) => [
  if (s.foundedYear != null) ('Founded', '${s.foundedYear}'),
  if (s.size != null) ('Team size', '${s.size} employees'),
  if (s.responseTime != null && responseTimeLabel(s.responseTime).isNotEmpty)
    ('Replies', responseTimeLabel(s.responseTime)[0].toUpperCase() + responseTimeLabel(s.responseTime).substring(1)),
  ('New work', s.acceptingWork ? 'Open for new work' : 'Not taking new work right now'),
  if (s.serviceAreas.isNotEmpty) ('Serves', s.serviceAreas.join(', ')),
  if (s.certificationNames.isNotEmpty) ('Certifications', s.certificationNames.join(', ')),
];

class _Tiles extends StatelessWidget {
  const _Tiles({required this.tiles});

  final List<TrackTile> tiles;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: 4.75));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _Tile(tile: tiles[i])),
              const SizedBox(width: 8.5),
              Expanded(child: i + 1 < tiles.length ? _Tile(tile: tiles[i + 1]) : const SizedBox()),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.tile});

  final TrackTile tile;

  @override
  Widget build(BuildContext context) {
    final color = switch (tile.tone) {
      TrackTone.blue => AppColors.primary,
      TrackTone.green => AppColors.tertiary,
      TrackTone.ink => AppColors.onSurface,
    };
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: MartColors.cardBorder, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(7.5, 7.5, 7.5, 7.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tile.value,
                  style: MartText.tileValue.copyWith(color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                width: 25,
                height: 25,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: AppColors.surfaceContainer, shape: BoxShape.circle),
                child: Icon(trackIcon(tile.glyph), size: 17, color: AppColors.onSurface, weight: 500),
              ),
            ],
          ),
          const SizedBox(height: 5.25),
          Text(tile.caption, style: MartText.tileCaption),
        ],
      ),
    );
  }
}

/// The glyph in a track-record tile's circle.
IconData trackIcon(TrackGlyph glyph) => switch (glyph) {
  TrackGlyph.check => Symbols.domain_verification,
  TrackGlyph.shield => Symbols.shield,
  TrackGlyph.building => Symbols.apartment,
  TrackGlyph.hubs => Symbols.hub,
  TrackGlyph.handshake => Symbols.handshake,
  TrackGlyph.calendar => Symbols.calendar_month,
};

class _About extends StatelessWidget {
  const _About({required this.text, required this.expanded, required this.onToggle});

  final String text;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: MartText.body),
          textDirection: TextDirection.ltr,
          maxLines: 2,
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: box.maxWidth);
        final clipped = painter.didExceedMaxLines;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              key: const ValueKey('about'),
              style: MartText.body,
              maxLines: expanded ? null : 2,
              overflow: expanded ? TextOverflow.visible : TextOverflow.clip,
            ),
            if (clipped) ...[
              const SizedBox(height: 3.75),
              InkWell(
                key: const ValueKey('charter'),
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(expanded ? 'Show less' : 'Read full company charter', style: MartText.readMore),
                      const SizedBox(width: 6),
                      Icon(
                        expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                        size: 13,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _DispatchBand extends StatelessWidget {
  const _DispatchBand({required this.band, required this.supplier});

  final DispatchBand band;
  final Supplier supplier;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: MartColors.bandFill,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(band.kicker, style: MartText.bandKicker),
          const SizedBox(height: 6),
          // The button sits on the title's own line, centred on it (it hung 3.5 dp below, at the design's smaller
          // type); the line shrank by that much, so the gap under it grew by the same.
          Row(
            children: [
              Expanded(child: Text(band.title, style: MartText.bandTitle)),
              const SizedBox(width: 12),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(5),
                child: InkWell(
                  key: const ValueKey('view-hubs'),
                  borderRadius: BorderRadius.circular(5),
                  onTap: () => showHubsSheet(context, supplier),
                  child: Container(
                    height: 17,
                    padding: const EdgeInsets.symmetric(horizontal: 12.5),
                    alignment: Alignment.center,
                    child: Text('View Hubs', style: MartText.bandButton),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8.5),
          Text(band.line, style: MartText.bandLine),
        ],
      ),
    );
  }
}
