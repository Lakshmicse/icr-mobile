import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../event_format.dart';
import '../event_models.dart';
import '../events_styles.dart';

/// A pill over a photo: "WEBINAR", "LIVE VIRTUAL", "15 CPD CREDITS".
class TagPill extends StatelessWidget {
  const TagPill(this.tag, {super.key, this.height = 28, this.radius = 6, this.padding = 8, this.style});

  final EventTag tag;
  final double height;
  final double radius;
  final double padding;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final (fill, ink) = switch (tag.tone) {
      TagTone.blue => (AppColors.primary, Colors.white),
      TagTone.white => (Colors.white, AppColors.primary),
      TagTone.whiteDark => (Colors.white, AppColors.onSurface),
      TagTone.green => (EventsColors.mintPill, EventsColors.mintInk),
      TagTone.greenSolid => (AppColors.tertiary, Colors.white),
      TagTone.red => (EventsColors.rosePill, AppColors.error),
      TagTone.dark => (EventsColors.heroChip, Colors.white),
    };
    return Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: padding),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(radius)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tag.live) ...[Icon(LucideIcons.radio, size: 10, color: ink), const SizedBox(width: 2.5)],
          Text(tag.label, style: (style ?? EventsText.tag).copyWith(color: ink)),
        ],
      ),
    );
  }
}

/// "OCT / 24": the month on a coloured head over the day on white.
class DateBadge extends StatelessWidget {
  const DateBadge({
    super.key,
    required this.at,
    this.width = 37.5,
    this.height = 44,
    this.headHeight = 17.5,
    this.color = AppColors.primary,
    this.radius = 7,
    this.monthStyle,
    this.dayStyle,
    this.shadow = true,
  });

  final DateTime at;
  final double width;
  final double height;
  final double headHeight;
  final Color color;
  final double radius;
  final TextStyle? monthStyle;
  final TextStyle? dayStyle;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow ? const [BoxShadow(color: Color(0x1F0F2A4A), blurRadius: 8, offset: Offset(0, 3))] : null,
      ),
      child: Column(
        children: [
          Container(
            height: headHeight,
            color: color,
            alignment: Alignment.center,
            child: Text(monthTag(at), style: monthStyle ?? EventsText.badgeMonth),
          ),
          Expanded(
            child: Center(child: Text('${ist(at).day}', style: dayStyle ?? EventsText.badgeDay)),
          ),
        ],
      ),
    );
  }
}

/// Overlapping initials circles ("MK", "TL", "RS", "+16").
class AvatarStack extends StatelessWidget {
  const AvatarStack({super.key, required this.avatars, this.size = 25, this.step = 14, this.ring = 2, this.style});

  final List<EventAvatar> avatars;
  final double size;
  final double step;
  final double ring;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    if (avatars.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      width: size + step * (avatars.length - 1),
      height: size,
      child: Stack(
        children: [
          for (final (i, a) in avatars.indexed)
            Positioned(
              left: i * step,
              child: Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: switch (a.tone) {
                    AvatarTone.blue => EventsColors.avatarBlue,
                    AvatarTone.mint => EventsColors.avatarMint,
                    AvatarTone.lavender => EventsColors.avatarLavender,
                    AvatarTone.green => EventsColors.avatarGreen,
                    AvatarTone.slate => EventsColors.avatarSlate,
                    AvatarTone.count => EventsColors.avatarLavender,
                  },
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: ring),
                ),
                child: Text(
                  a.initials,
                  style: (style ?? EventsText.avatarInitials).copyWith(
                    color: switch (a.tone) {
                      AvatarTone.mint => EventsColors.mintInk,
                      AvatarTone.lavender => AppColors.onSurface,
                      AvatarTone.count => AppColors.primary,
                      _ => Colors.white,
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// An event's cover photo, or a tinted stand-in when it has none.
class EventCover extends StatelessWidget {
  const EventCover({super.key, required this.event, this.scale = 2});

  final EventSummary event;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final cover = event.cover;
    if (cover?.asset != null) {
      return Image.asset(cover!.asset!, scale: scale, fit: BoxFit.cover, filterQuality: FilterQuality.medium);
    }
    final fallback = _Fallback(kind: event.kind);
    if (cover?.url != null) {
      return CachedNetworkImage(
        imageUrl: cover!.url!,
        fit: BoxFit.cover,
        placeholder: (_, _) => fallback,
        errorWidget: (_, _, _) => fallback,
      );
    }
    return fallback;
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.kind});

  final EventKind kind;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A5F), Color(0xFF0F172A)],
        ),
      ),
      child: Center(
        child: Icon(
          switch (kind) {
            EventKind.conference => LucideIcons.presentation,
            EventKind.webinar => LucideIcons.monitorPlay,
            EventKind.workshop => LucideIcons.wrench,
            EventKind.masterclass => LucideIcons.graduationCap,
            EventKind.roundtable => LucideIcons.messagesSquare,
            EventKind.chapterMeet => LucideIcons.building2,
          },
          size: 34,
          color: const Color(0x55FFFFFF),
        ),
      ),
    );
  }
}

/// A small glyph in a tap target.
class GlyphButton extends StatelessWidget {
  const GlyphButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.size = 14,
    this.box = 18,
    this.color = AppColors.outline,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double size;
  final double box;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 18,
        child: SizedBox(
          width: box,
          height: box,
          child: Icon(icon, size: size, color: color),
        ),
      ),
    );
  }
}
