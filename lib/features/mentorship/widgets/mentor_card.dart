import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../account/widgets/account_kit.dart' show CoverBand, profileCovers;
import '../../feed/widgets/feed_avatar.dart';
import '../mentorship_models.dart';
import '../mentorship_styles.dart';

/// One mentor in the grid: a landscape cover with a round photo centred over
/// its lower edge, then, centred, the name with its seal, the role line and
/// the expertise as one quiet line; then, with [onMessage], a
/// Message button at the foot (owner, 12 Nov 2026: "connect to message them and
/// click on the other space it will goes to profile"). The rest of the card
/// opens the profile.
class MentorCard extends StatelessWidget {
  const MentorCard({super.key, required this.mentor, required this.onTap, this.onMessage, this.bottomPad = 8.0});

  /// The cover and the photo that stands centred over its lower edge (owner's reference, 12 Nov 2026: the
  /// "people you may know" card — photo in the middle, the words centred under it, one pill button at the foot).
  static const coverHeight = 46.0;
  static const _photo = 68.0;
  static const _photoTop = 10.0;
  static const _headHeight = _photoTop + _photo + 3;

  final Mentor mentor;
  final VoidCallback onTap;

  /// Opens a conversation with the mentor; null draws no button.
  final VoidCallback? onMessage;

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
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: _headHeight,
                  child: _Head(mentor: mentor),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 9.5),
                  child: _Body(mentor: mentor),
                ),
                if (onMessage != null) ...[
                  // The cards of a row stand as tall as the taller; the button keeps to the foot of each.
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(9.5, 9, 9.5, 2),
                    child: _MessageButton(name: mentor.name, onTap: onMessage!),
                  ),
                ],
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
          left: 0,
          right: 0,
          top: 0,
          height: MentorCard.coverHeight,
          child: _Cover(mentor: mentor),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: MentorCard._photoTop - 2,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: FeedAvatar(photo: mentor.avatar, initials: mentor.initials, size: MentorCard._photo),
            ),
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

/// A ready-made cover as the mentor's profile draws it (its picture over its colours), or the brand blue when
/// there is none.
class _Band extends StatelessWidget {
  const _Band({this.preset});

  final String? preset;

  @override
  Widget build(BuildContext context) {
    if (preset != null && profileCovers.containsKey(preset)) return CoverBand(cover: preset);
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
    final expertise = mentor.expertise.take(3).join(' · ');
    return Column(
      children: [
        // A long name takes a second line rather than being cut, the seal beside it (owner, 12 Nov 2026).
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                mentor.name,
                style: MentorshipText.mentorName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (mentor.approved) ...[
              const SizedBox(width: 4.5),
              const Icon(Symbols.verified, fill: 1, size: 14.5, color: AppColors.primary),
            ],
          ],
        ),
        const SizedBox(height: 2),
        if (role.isNotEmpty)
          Text(
            role,
            style: MentorshipText.mentorRole,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        if (expertise.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            expertise,
            style: MentorshipText.expertise,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

/// The card's Message button: an outlined pill the card's width, the speech glyph and the word.
class _MessageButton extends StatelessWidget {
  const _MessageButton({required this.name, required this.onTap});

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      // Its own node with its own tap: inside the card's button it was otherwise lost to a screen reader.
      container: true,
      button: true,
      label: 'Message $name',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: Colors.white,
        shape: const StadiumBorder(side: BorderSide(color: AppColors.primary)),
        child: InkWell(
          key: const ValueKey('mentor-card-message'),
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: SizedBox(
            height: 32,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              // "Message" (owner, 13 Nov 2026: "the card having connect do it as Message"; it read "Connect" for a
              // day): it opens the conversation.
              children: [Text('Message', style: MentorshipText.message)],
            ),
          ),
        ),
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
    this.onMessage,
    this.viewerId,
    this.gap = 6.5,
    this.bottomPad = 8.0,
  });

  final Mentor left;
  final Mentor? right;
  final void Function(Mentor) onOpen;

  /// Messages a mentor from their card. Null: no card has a Message button.
  final void Function(Mentor)? onMessage;

  /// The signed-in member: their own card has no Message button.
  final String? viewerId;
  final double gap;
  final double bottomPad;

  /// The card's Message: only for a mentor with an account to reach who is not the viewer.
  VoidCallback? _messageFor(Mentor m) {
    final message = onMessage;
    if (message == null || m.userId == null || m.userId == viewerId) return null;
    return () => message(m);
  }

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: MentorCard(
              mentor: left,
              onTap: () => onOpen(left),
              onMessage: _messageFor(left),
              bottomPad: bottomPad,
            ),
          ),
          SizedBox(width: gap),
          Expanded(
            child: right == null
                ? const SizedBox.shrink()
                : MentorCard(
                    mentor: right!,
                    onTap: () => onOpen(right!),
                    onMessage: _messageFor(right!),
                    bottomPad: bottomPad,
                  ),
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
    this.onMessage,
    this.viewerId,
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

  /// As [MentorRow.onMessage] and [MentorRow.viewerId].
  final void Function(Mentor)? onMessage;
  final String? viewerId;
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
              onMessage: onMessage,
              viewerId: viewerId,
              bottomPad: i == 0 ? bottomPad - firstRowTrim : bottomPad,
            ),
          ],
        ],
      ),
    );
  }
}
