import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../messaging_format.dart';
import '../messaging_models.dart';

/// A person's round photo (their initials without one), a company's rounded
/// square logo (or, in the inbox, a round one), or a room's group glyph.
///
/// [online] draws the presence dot at the bottom-right corner: green for `true`, grey for `false`, none for
/// `null` (the API sends no presence, so a real person never gets one).
class ChatAvatar extends StatelessWidget {
  const ChatAvatar({
    super.key,
    required this.picture,
    required this.name,
    this.size = 44,
    this.company = false,
    this.round = false,
    this.online,
  });

  /// How a conversation draws: its display's kind decides the shape. [round] draws a company's logo (and its
  /// initials) in a circle like a person's, as the inbox does; [online] is the presence dot.
  factory ChatAvatar.forDisplay(ConversationDisplay d, {double size = 44, bool round = false, bool? online}) =>
      switch (d.avatar) {
        AvatarKind.person => ChatAvatar(picture: d.person?.photo, name: d.name, size: size, online: online),
        AvatarKind.company => ChatAvatar(
          picture: d.company?.logo,
          name: d.name,
          size: size,
          company: true,
          round: round,
          online: online,
        ),
        AvatarKind.group => GroupAvatar(size: size),
      };

  final ChatPicture? picture;
  final String name;
  final double size;
  final bool company;
  final bool round;
  final bool? online;

  /// The mint a company's initials sit on, and their ink (the inbox design's "VA").
  static const companyTint = Color(0xFFD1FAE5);
  static const companyInk = Color(0xFF065F46);

  /// The presence dot: the coloured disc's right and bottom edges sit on the avatar's box, in a white ring.
  static const dotSize = 10.0;
  static const dotRing = 2.0;

  @override
  Widget build(BuildContext context) {
    final fallback = _Initials(
      initials: company ? _companyInitials(name) : initialsOf(name),
      size: size,
      company: company,
    );
    final p = picture;
    final square = company && !round;
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
    final shape = square
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
        : company && (p?.asset != null || p?.url != null)
        // A round company logo: on white, with a hairline, kept whole inside the circle.
        ? Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.slate200),
            ),
            clipBehavior: Clip.antiAlias,
            padding: EdgeInsets.all(size * 0.14),
            child: child,
          )
        : ClipOval(child: box);
    final presence = online;
    return Semantics(
      image: true,
      label: name,
      child: presence == null
          ? shape
          : SizedBox(
              width: size,
              height: size,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(child: shape),
                  Positioned(
                    right: -dotRing,
                    bottom: -dotRing,
                    child: PresenceDot(online: presence),
                  ),
                ],
              ),
            ),
    );
  }
}

/// A 10 dp dot in a 2 dp white ring: green when [online], grey when not.
class PresenceDot extends StatelessWidget {
  const PresenceDot({super.key, required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) => Container(
    width: ChatAvatar.dotSize + 2 * ChatAvatar.dotRing,
    height: ChatAvatar.dotSize + 2 * ChatAvatar.dotRing,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: online ? AppColors.online : AppColors.slate300,
      border: Border.all(color: Colors.white, width: ChatAvatar.dotRing),
    ),
  );
}

/// A company's initials are its first two words' ("Vikasha Aero Tech" is VA), not its first and last.
String _companyInitials(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '';
  return words.take(2).map((w) => String.fromCharCode(w.runes.first).toUpperCase()).join();
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
      color: company ? ChatAvatar.companyTint : const Color(0xFFDCE6F2),
      child: Text(
        initials,
        style: TextStyle(
          fontFamily: AppText.work,
          fontWeight: company ? FontWeight.w700 : FontWeight.w600,
          fontSize: size * (company ? 0.29 : 0.36),
          color: company ? ChatAvatar.companyInk : AppColors.primary,
          height: 1,
        ),
      ),
    );
  }
}
