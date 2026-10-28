import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../chapter_format.dart';
import '../chapter_models.dart';
import '../community_kit.dart';

/// A chapter's banner: its photo (or the two-tone gradient the website hashes
/// from the slug) under a mild scrim, the place's glyph on a tile at the left
/// and whatever pills the caller lays over the right.
class ChapterCover extends StatelessWidget {
  const ChapterCover({super.key, required this.chapter, this.height = 80, this.tile = true, this.pills});

  final ChapterSummary chapter;
  final double height;

  /// The glyph tile at the top left.
  final bool tile;

  /// Laid over the top right.
  final Widget? pills;

  @override
  Widget build(BuildContext context) {
    final (from, to) = coverColors(chapter.slug);
    final gradient = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [from, to]),
      ),
    );
    final photo = chapter.cover;
    Widget background = gradient;
    if (photo != null) {
      background = photo.asset != null
          ? Image.asset(photo.asset!, fit: BoxFit.cover)
          : CachedNetworkImage(
              imageUrl: photo.url!,
              fit: BoxFit.cover,
              placeholder: (_, _) => gradient,
              errorWidget: (_, _, _) => gradient,
            );
    }
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          background,
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [CommunityColors.coverScrimTop, CommunityColors.coverScrimBottom],
              ),
            ),
          ),
          if (tile)
            Positioned(
              left: 13,
              top: 11,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(color: const Color(0x40FFFFFF), borderRadius: BorderRadius.circular(7)),
                child: Icon(placeIcon(chapter.placeKind), size: 16, color: Colors.white),
              ),
            ),
          if (pills != null) Positioned(right: 10, top: 13, child: pills!),
        ],
      ),
    );
  }
}
