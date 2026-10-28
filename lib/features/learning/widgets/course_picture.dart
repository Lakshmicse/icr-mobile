import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../learning_models.dart';
import '../learning_styles.dart';

/// A bundled or fetched picture filling its box; a plate when there is none.
class CoursePicture extends StatelessWidget {
  const CoursePicture({super.key, required this.picture, this.fit = BoxFit.cover, this.plate, this.child});

  final FeedPicture? picture;
  final BoxFit fit;

  /// The colour behind a missing picture.
  final Color? plate;

  /// Drawn on the plate when there is no picture (initials, a glyph).
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final p = picture;
    if (p?.asset != null) {
      return Image.asset(p!.asset!, fit: fit, filterQuality: FilterQuality.high, width: double.infinity);
    }
    if (p?.url != null) {
      return CachedNetworkImage(
        imageUrl: p!.url!,
        fit: fit,
        width: double.infinity,
        placeholder: (_, _) => ColoredBox(color: plate ?? LearningColors.coverPlate),
        errorWidget: (_, _, _) => ColoredBox(color: plate ?? LearningColors.coverPlate, child: child),
      );
    }
    return ColoredBox(color: plate ?? LearningColors.coverPlate, child: child);
  }
}
