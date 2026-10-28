import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../feed/feed_models.dart' show FeedPicture;
import '../study_format.dart';
import '../study_models.dart';
import '../study_styles.dart';

/// One flash-card deck in the grid, on the Learning catalogue's card frame: the cover on top with the card count
/// over its corner, the name (two lines), a meta line and a foot that says where the deck stands: "Study" for
/// one the plan opens, a lock for one it does not, and the member's starred cards on it. A deck that belongs with
/// an Assess your knowledge course says so under its name: "Opens with" and the course's name while it is closed
/// (the lock is the course's), "Included with" and its name once it is open.
class DeckCard extends StatelessWidget {
  const DeckCard({super.key, required this.deck, required this.state, required this.onTap, this.starred = 0});

  /// The cover is not the course card's 16:10: the decks' illustrations are close to square.
  static const coverAspect = 4 / 3;

  final StudyTopic deck;
  final DeckState state;
  final int starred;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final locked = state == DeckState.locked;
    final course = deck.linked ? deck.course?.title : null;
    return Semantics(
      button: true,
      label:
          '${deck.title}, ${cardsLabel(deck.cardCount)}'
          '${course == null ? '' : (locked ? ', opens with $course' : ', included with $course')}'
          '${locked ? ', locked' : ''}',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: StudyColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: coverAspect,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _Cover(picture: deck.cover, title: deck.title),
                    if (locked) const ColoredBox(color: Color(0x66FFFFFF)),
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Container(
                        height: 22,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xB3081422),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(cardsLabel(deck.cardCount).toUpperCase(), style: StudyText.coverPill),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(deck.title, style: StudyText.deckTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                      if (course != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          _courseNoteFor(deck.title, course, locked),
                          key: ValueKey('deck-course:${deck.id}'),
                          style: locked ? StudyText.deckMeta.copyWith(color: StudyColors.amberInk) : StudyText.deckMeta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const Spacer(),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (locked)
                            const _FootPill(
                              label: 'Locked',
                              fill: StudyColors.amberFill,
                              ink: StudyColors.amberInk,
                              icon: Symbols.lock,
                            )
                          else
                            SizedBox(
                              height: 22,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Study', style: StudyText.cta),
                                  const SizedBox(width: 3),
                                  const Icon(LucideIcons.arrowRight, size: 14, color: AppColors.primary),
                                ],
                              ),
                            ),
                          if (starred > 0)
                            _FootPill(
                              label: '$starred',
                              fill: const Color(0xFFFFF4DC),
                              ink: AppColors.amber800,
                              icon: Symbols.star,
                              filled: true,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What a deck says of its course under its name. A deck usually has the course's own name ("Capital Planning" and
/// the course "Capital Planning"), and repeating it in a half-width card only cuts it short: then "the course" does.
String _courseNoteFor(String deckTitle, String course, bool locked) {
  String key(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  if (key(deckTitle) == key(course)) return locked ? 'Opens with the course' : 'Included in the course';
  return locked ? 'Opens with $course' : 'Included with $course';
}

class _Cover extends StatelessWidget {
  const _Cover({required this.picture, required this.title});

  final FeedPicture? picture;
  final String title;

  @override
  Widget build(BuildContext context) {
    final p = picture;
    final plate = ColoredBox(
      color: StudyColors.coverPlate,
      child: Center(
        child: Icon(LucideIcons.layers, size: 34, color: AppColors.slate400, semanticLabel: title),
      ),
    );
    if (p?.asset != null) {
      return Image.asset(p!.asset!, fit: BoxFit.cover, filterQuality: FilterQuality.high, width: double.infinity);
    }
    if (p?.url != null) {
      return CachedNetworkImage(
        imageUrl: p!.url!,
        fit: BoxFit.cover,
        width: double.infinity,
        placeholder: (_, _) => const ColoredBox(color: StudyColors.coverPlate),
        errorWidget: (_, _, _) => plate,
      );
    }
    return plate;
  }
}

class _FootPill extends StatelessWidget {
  const _FootPill({
    required this.label,
    required this.fill,
    required this.ink,
    required this.icon,
    this.filled = false,
  });

  final String label;
  final Color fill;
  final Color ink;
  final IconData icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.only(left: 6, right: 8),
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(11)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, fill: filled ? 1 : 0, weight: 600, color: ink),
          const SizedBox(width: 3),
          Text(label, style: StudyText.pill.copyWith(color: ink, fontSize: 13)),
        ],
      ),
    );
  }
}

/// Two decks to a row on equal-height cards; a lone deck takes the left half.
class DeckGridRow extends StatelessWidget {
  const DeckGridRow({super.key, required this.left, this.right});

  static const margin = 12.0;
  static const gap = 10.0;
  static const rowGap = 10.0;

  final Widget left;
  final Widget? right;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: margin),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: left),
            const SizedBox(width: gap),
            Expanded(child: right ?? const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}
