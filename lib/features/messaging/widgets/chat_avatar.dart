import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../messaging_format.dart';
import '../messaging_models.dart';

/// A person's round photo (their initials without one), a company's rounded
/// square logo, or a room's group glyph.
class ChatAvatar extends StatelessWidget {
  const ChatAvatar({super.key, required this.picture, required this.name, this.size = 44, this.company = false});

  /// How a conversation draws: its display's kind decides the shape.
  factory ChatAvatar.forDisplay(ConversationDisplay d, {double size = 44}) => switch (d.avatar) {
    AvatarKind.person => ChatAvatar(picture: d.person?.photo, name: d.name, size: size),
    AvatarKind.company => ChatAvatar(picture: d.company?.logo, name: d.name, size: size, company: true),
    AvatarKind.group => GroupAvatar(size: size),
  };

  final ChatPicture? picture;
  final String name;
  final double size;
  final bool company;

  @override
  Widget build(BuildContext context) {
    final fallback = _Initials(initials: initialsOf(name), size: size, company: company);
    final p = picture;
    Widget child;
    if (p?.asset != null) {
      child = Image.asset(p!.asset!, fit: BoxFit.cover, width: size, height: size);
    } else if (p?.url != null) {
      child = CachedNetworkImage(
        imageUrl: p!.url!,
        fit: company ? BoxFit.contain : BoxFit.cover,
        width: size,
        height: size,
        placeholder: (_, _) => fallback,
        errorWidget: (_, _, _) => fallback,
      );
    } else {
      child = fallback;
    }
    final box = SizedBox(width: size, height: size, child: child);
    return Semantics(
      image: true,
      label: name,
      child: company
          ? Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(size * 0.22),
                border: Border.all(color: AppColors.slate200),
              ),
              clipBehavior: Clip.antiAlias,
              child: box,
            )
          : ClipOval(child: box),
    );
  }
}

class GroupAvatar extends ChatAvatar {
  const GroupAvatar({super.key, super.size}) : super(picture: null, name: 'Group');

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(color: Color(0xFFE7EEFF), shape: BoxShape.circle),
    child: Icon(LucideIcons.users, size: size * 0.45, color: AppColors.primary),
  );
}

class _Initials extends StatelessWidget {
  const _Initials({required this.initials, required this.size, required this.company});

  final String initials;
  final double size;
  final bool company;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: company ? AppColors.slate100 : const Color(0xFFDCE6F2),
      child: Text(
        initials,
        style: TextStyle(
          fontFamily: AppText.work,
          fontWeight: FontWeight.w600,
          fontSize: size * 0.36,
          color: company ? AppColors.slate600 : AppColors.primary,
          height: 1,
        ),
      ),
    );
  }
}
