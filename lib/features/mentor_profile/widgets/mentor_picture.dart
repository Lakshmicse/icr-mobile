import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../mentor_profile_models.dart';

/// A bundled or uploaded picture filling its box; [fallback] when there is none.
class MentorPicture extends StatelessWidget {
  const MentorPicture({
    super.key,
    required this.picture,
    this.alignment = Alignment.center,
    this.fallback,
    this.fit = BoxFit.cover,
  });

  final FeedPicture? picture;
  final Alignment alignment;
  final Widget? fallback;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final blank = fallback ?? const ColoredBox(color: AppColors.surfaceContainer);
    final asset = picture?.asset;
    final url = picture?.url;
    if (asset != null) {
      return SizedBox.expand(
        child: Image.asset(asset, fit: fit, alignment: alignment, filterQuality: FilterQuality.high),
      );
    }
    if (url != null) {
      return SizedBox.expand(
        child: CachedNetworkImage(
          imageUrl: url,
          fit: fit,
          alignment: alignment,
          errorWidget: (_, _, _) => blank,
          placeholder: (_, _) => blank,
        ),
      );
    }
    return SizedBox.expand(child: blank);
  }
}

/// Two letters on a soft tile, for a person with no photo.
class InitialsTile extends StatelessWidget {
  const InitialsTile({super.key, required this.name, this.style});

  final String name;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final initials = parts.isEmpty ? '?' : '${parts.first[0]}${parts.length > 1 ? parts.last[0] : ''}'.toUpperCase();
    return ColoredBox(
      color: AppColors.surfaceContainer,
      child: Center(
        child: Text(initials, style: style ?? TextStyle(fontSize: 18, color: AppColors.outline.withValues(alpha: 0.9))),
      ),
    );
  }
}

/// The navy gradient behind a title when a mentor or offering has no photo.
class NavyFallback extends StatelessWidget {
  const NavyFallback({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F1B30), Color(0xFF073258), AppColors.primary],
        ),
      ),
    );
  }
}
