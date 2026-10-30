import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../feed/widgets/feed_avatar.dart';
import '../mentorship_models.dart';
import '../mentorship_styles.dart';

/// One mentor in the grid, as the Find Mentors design draws them: a landscape
/// cover with a round photo over its lower edge, the name with its seal, the
/// role line and up to three small expertise chips.
class MentorCard extends StatelessWidget {
  const MentorCard({super.key, required this.mentor, required this.onTap, this.bottomPad = 8.0});

  /// The cover and the photo that overlaps it.
  static const coverHeight = 36.5;
  static const _headHeight = 58.55;
  static const _photo = 47.0;

  final Mentor mentor;
  final VoidCallback onTap;

  /// Under the last chip. The landing's cards stand a little taller than Find Mentors'.
  final double bottomPad;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${mentor.name}, ${mentor.roleLine}',
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: MentorshipColors.cardBorder, width: 0.5),
          boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 3, offset: Offset(0, 1))],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: _headHeight,
                  child: _Head(mentor: mentor),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 9.5),
                  child: _Body(mentor: mentor),
                ),
                SizedBox(height: bottomPad),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Head extends StatelessWidget {
  const _Head({required this.mentor});

  final Mentor mentor;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 2.5,
          right: 2.5,
          top: 0,
          height: MentorCard.coverHeight,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
            child: _Cover(mentor: mentor),
          ),
        ),
        Positioned(
          left: 8.1,
          top: 8.1,
          child: Container(
            width: 50,
            height: 50,
            padding: const EdgeInsets.all(1.5),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: FeedAvatar(photo: mentor.avatar, initials: mentor.initials, size: MentorCard._photo),
          ),
        ),
      ],
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.mentor});

  final Mentor mentor;

  @override
  Widget build(BuildContext context) {
    final band = _Band(preset: mentor.coverPreset);
    final picture = mentor.cover;
    if (picture?.asset != null) {
      return Image.asset(picture!.asset!, fit: BoxFit.cover, width: double.infinity, height: MentorCard.coverHeight);
    }
    if (picture?.url != null) {
      return CachedNetworkImage(
        imageUrl: picture!.url!,
        fit: BoxFit.cover,
        placeholder: (_, _) => band,
        errorWidget: (_, _, _) => band,
      );
    }
    return band;
  }
}

/// A ready-made cover's gradient (or the brand blue) when there is no photo.
class _Band extends StatelessWidget {
  const _Band({this.preset});

  final String? preset;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: MentorshipColors.covers[preset] ?? MentorshipColors.coverFallback),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.mentor});

  final Mentor mentor;

  @override
  Widget build(BuildContext context) {
    final role = mentor.roleLine;
    final chips = mentor.expertise.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The name's line is as tall as its text (a fixed 17.3 cut it at the app's 14 sp). The design's role
        // line stands 2 dp lower under the name than the name's own line height gives; at this size the
        // line's own 18 leaves 1.3 dp of that.
        Row(
          children: [
            Flexible(
              child: Text(mentor.name, style: MentorshipText.mentorName, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            if (mentor.approved) ...[
              const SizedBox(width: 4.5),
              const Icon(Symbols.verified, fill: 1, size: 14.5, color: AppColors.primary),
            ],
          ],
        ),
        const SizedBox(height: 1.3),
        if (role.isNotEmpty) Text(role, style: MentorshipText.mentorRole, maxLines: 2, overflow: TextOverflow.ellipsis),
        if (chips.isNotEmpty) ...[
          const SizedBox(height: 5.5),
          Wrap(spacing: 4, runSpacing: 4, children: [for (final c in chips) _ExpertiseChip(c)]),
        ],
      ],
    );
  }
}

class _ExpertiseChip extends StatelessWidget {
  const _ExpertiseChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    // A chip is as wide as its words; a Container with an alignment would
    // take the whole row.
    return Container(
      height: 15,
      padding: const EdgeInsets.symmetric(horizontal: 8.6),
      decoration: BoxDecoration(color: MentorshipColors.expertiseChip, borderRadius: BorderRadius.circular(7.5)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(label, style: MentorshipText.expertise, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

/// Two cards side by side, as tall as the taller one.
class MentorRow extends StatelessWidget {
  const MentorRow({
    super.key,
    required this.left,
    this.right,
    required this.onOpen,
    this.gap = 6.5,
    this.bottomPad = 8.0,
  });

  final Mentor left;
  final Mentor? right;
  final void Function(Mentor) onOpen;
  final double gap;
  final double bottomPad;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: MentorCard(mentor: left, onTap: () => onOpen(left), bottomPad: bottomPad),
          ),
          SizedBox(width: gap),
          Expanded(
            child: right == null
                ? const SizedBox.shrink()
                : MentorCard(mentor: right!, onTap: () => onOpen(right!), bottomPad: bottomPad),
          ),
        ],
      ),
    );
  }
}

/// A two-column grid of mentor cards, 5 dp between rows.
class MentorGrid extends StatelessWidget {
  const MentorGrid({
    super.key,
    required this.mentors,
    required this.onOpen,
    this.padding = 17.25,
    this.rowGap = 5,
    this.bottomPad = 8.0,
    this.firstRowTrim = firstRowTrimDefault,
  });

  /// The design's first row stands 3 dp shorter than the rows below it (its two
  /// chip lines end 6.5 dp above the card's edge, the others' 9.5).
  static const firstRowTrimDefault = 3.0;

  final List<Mentor> mentors;
  final void Function(Mentor) onOpen;
  final double padding;
  final double rowGap;
  final double bottomPad;

  /// Taken from the first row's bottom padding.
  final double firstRowTrim;

  @override
  Widget build(BuildContext context) {
    final rows = (mentors.length + 1) ~/ 2;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding),
      child: Column(
        children: [
          for (var i = 0; i < rows; i++) ...[
            if (i > 0) SizedBox(height: rowGap),
            MentorRow(
              left: mentors[i * 2],
              right: i * 2 + 1 < mentors.length ? mentors[i * 2 + 1] : null,
              onOpen: onOpen,
              bottomPad: i == 0 ? bottomPad - firstRowTrim : bottomPad,
            ),
          ],
        ],
      ),
    );
  }
}
