import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../council_format.dart';
import '../council_models.dart';
import '../councils_styles.dart';

/// The navy "IN-PERSON SUMMITS" card at the foot: four city chapters with
/// their next date, and the way to the chapters directory.
class ChaptersFooter extends StatelessWidget {
  const ChaptersFooter({super.key, required this.chapters, required this.onChapter, required this.onDirectory});

  final List<ChapterSummit> chapters;
  final ValueChanged<ChapterSummit> onChapter;
  final VoidCallback onDirectory;

  static const tileWidth = 173.0;
  static const tileHeight = 39.0;

  @override
  Widget build(BuildContext context) {
    final rows = <List<ChapterSummit>>[];
    for (var i = 0; i < chapters.length; i += 2) {
      rows.add(chapters.sublist(i, i + 2 > chapters.length ? chapters.length : i + 2));
    }
    return ColoredBox(
      color: CouncilsColors.navy,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(17, 22, 16, 16.5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(color: CouncilsColors.summitTile, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(LucideIcons.building2, size: 16, color: AppColors.success),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('IN-PERSON SUMMITS', style: CouncilsText.summitKicker),
                      Text(
                        'Regional In-Person Chapters',
                        style: CouncilsText.summitTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Closed-door city roundtables & facility delegations. Pair council membership with local physical '
              'chapter assemblies:',
              style: CouncilsText.summitCopy,
            ),
            const SizedBox(height: 15.5),
            for (final (i, row) in rows.indexed) ...[
              if (i > 0) const SizedBox(height: 7.5),
              Row(
                children: [
                  for (final (j, chapter) in row.indexed) ...[
                    if (j > 0) const SizedBox(width: 10),
                    _CityTile(chapter: chapter, onTap: () => onChapter(chapter)),
                  ],
                ],
              ),
            ],
            if (rows.isEmpty)
              Text('City chapters are announced on the website.', style: CouncilsText.summitCopy)
            else
              const SizedBox(height: 10),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: onDirectory,
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  height: 40,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Symbols.apartment, size: 15, color: AppColors.slate900),
                      const SizedBox(width: 6),
                      Text('View Regional Chapters Directory', style: CouncilsText.directoryButton),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CityTile extends StatelessWidget {
  const _CityTile({required this.chapter, required this.onTap});

  final ChapterSummit chapter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = chapter.nextEventAt == null ? 'TBA' : monthDay(chapter.nextEventAt!);
    return Material(
      color: CouncilsColors.navyTile,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: CouncilsColors.navyTileBorder),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: ChaptersFooter.tileWidth,
          height: ChaptersFooter.tileHeight,
          child: Padding(
            padding: const EdgeInsets.only(left: 11, right: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(chapter.city, style: CouncilsText.city, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 6),
                Text(
                  date,
                  style: chapter.nextEventAt == null
                      ? CouncilsText.cityDate.copyWith(color: CouncilsColors.navyCopy)
                      : CouncilsText.cityDate,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
