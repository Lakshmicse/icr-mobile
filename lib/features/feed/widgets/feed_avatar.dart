import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../feed_models.dart';

/// A round photo, or the person's initials when there is none.
class FeedAvatar extends StatelessWidget {
  const FeedAvatar({super.key, required this.photo, required this.initials, required this.size, this.label});

  final FeedPicture? photo;
  final String initials;
  final double size;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final fallback = _Initials(initials: initials, size: size);
    final picture = photo;
    Widget child;
    if (picture?.asset != null) {
      child = Image.asset(picture!.asset!, fit: BoxFit.cover, width: size, height: size);
    } else if (picture?.url != null) {
      child = CachedNetworkImage(
        imageUrl: picture!.url!,
        fit: BoxFit.cover,
        width: size,
        height: size,
        placeholder: (_, _) => fallback,
        errorWidget: (_, _, _) => fallback,
      );
    } else {
      child = fallback;
    }
    return Semantics(
      image: true,
      label: label,
      child: ClipOval(
        child: SizedBox(width: size, height: size, child: child),
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.initials, required this.size});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: const Color(0xFFDCE6F2),
      child: Text(
        initials,
        style: TextStyle(
          fontFamily: AppText.work,
          fontWeight: FontWeight.w600,
          fontSize: size * 0.38,
          color: AppColors.primary,
          height: 1,
        ),
      ),
    );
  }
}
