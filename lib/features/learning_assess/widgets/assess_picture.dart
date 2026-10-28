import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../assess_models.dart';
import '../assess_styles.dart';

/// A bundled or fetched picture filling its box; a plate (with [child] on it) when there is none or it fails.
class AssessPicture extends StatelessWidget {
  const AssessPicture({super.key, required this.picture, this.fit = BoxFit.cover, this.child});

  final FeedPicture? picture;
  final BoxFit fit;

  /// Drawn on the plate when there is no picture (a glyph or initials).
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final p = picture;
    if (p?.asset != null) {
      return Image.asset(p!.asset!, fit: fit, width: double.infinity, height: double.infinity);
    }
    if (p?.url != null) {
      return CachedNetworkImage(
        imageUrl: p!.url!,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        placeholder: (_, _) => const ColoredBox(color: AssessColors.plate),
        errorWidget: (_, _, _) => ColoredBox(color: AssessColors.plate, child: child),
      );
    }
    return ColoredBox(color: AssessColors.plate, child: child);
  }
}
