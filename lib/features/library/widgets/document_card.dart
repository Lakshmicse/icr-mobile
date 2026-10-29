import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../chapters/community_kit.dart';
import '../library_format.dart';
import '../library_models.dart';

/// The coloured square a file's format is drawn on: its badge ("PDF", "XLSX") on its colour, and for a pack
/// the number of files at the corner.
class FilePlate extends StatelessWidget {
  const FilePlate({super.key, required this.glyph, this.size = 44, this.count});

  final FileGlyph glyph;
  final double size;

  /// A pack's file count, drawn at the corner when above one.
  final int? count;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: glyph.color, borderRadius: BorderRadius.circular(size * 0.2)),
            child: Text(
              glyph.label,
              style: AppText.plexSans(size * 0.2, FontWeight.w700, Colors.white, lineHeight: size * 0.26),
            ),
          ),
          if (count != null && count! > 1)
            Positioned(
              right: -5,
              bottom: -5,
              child: Container(
                constraints: const BoxConstraints(minWidth: 19),
                height: 19,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: CommunityColors.border),
                ),
                child: Text(
                  '$count',
                  style: AppText.plexSans(8.5, FontWeight.w700, AppColors.slate700, lineHeight: 11),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A document in the list: its format plate, title, where it is filed, what it holds, the first lines of
/// its description, who shared it and how often it was read and taken.
class DocumentCard extends StatelessWidget {
  const DocumentCard({super.key, required this.document, required this.onOpen, this.mine = false});

  final LibraryDocument document;
  final VoidCallback onOpen;

  /// The member shared it: a "Yours" pill.
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final d = document;
    final first = d.first;
    final glyph = first?.glyph ?? FileGlyph.fallback;
    return CommunityCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FilePlate(glyph: glyph, count: d.fileCount),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.title, style: CommunityText.cardTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(
                      contentsLine(d),
                      style: CommunityText.personLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (mine) ...[
                const SizedBox(width: 6),
                CommunityPill(
                  label: 'YOURS',
                  fill: CommunityColors.blue50,
                  style: CommunityText.pill.copyWith(color: CommunityColors.blue700),
                  height: 17,
                ),
              ],
            ],
          ),
          if (d.description != null) ...[
            const SizedBox(height: 8),
            Text(d.description!, style: CommunityText.body, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          if (d.category != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: CommunityPill(
                label: d.category!,
                fill: CommunityColors.tagFill,
                style: CommunityText.tag,
                height: 20,
                padding: const EdgeInsets.symmetric(horizontal: 9),
              ),
            ),
          ],
          const SizedBox(height: 10),
          const Divider(height: 1, thickness: 1, color: CommunityColors.tileRule),
          const SizedBox(height: 8),
          Row(
            children: [
              if (d.uploader != null) ...[
                PersonAvatar(initials: d.uploader!.initials, photo: d.uploader!.photo, size: 20),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    d.uploader!.name,
                    style: CommunityText.meta.copyWith(fontWeight: FontWeight.w600, color: AppColors.slate700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              const Spacer(),
              const Icon(LucideIcons.eye, size: 11, color: AppColors.slate400),
              const SizedBox(width: 3),
              Text(compactCount(d.viewCount), style: CommunityText.meta),
              const SizedBox(width: 10),
              const Icon(LucideIcons.download, size: 11, color: AppColors.slate400),
              const SizedBox(width: 3),
              Text(compactCount(d.downloadCount), style: CommunityText.meta),
              if (d.createdAt != null) ...[
                const SizedBox(width: 10),
                Text(shortDate(d.createdAt!), style: CommunityText.meta),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
