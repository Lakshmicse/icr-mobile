import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../feed_models.dart';
import '../feed_styles.dart';
import 'feed_avatar.dart';

/// "Start a post": the reader's photo beside an outlined pill that opens the composer, as LinkedIn's. Without
/// a photo (the Forums tab), the pill alone.
class ComposerBar extends StatelessWidget {
  const ComposerBar({super.key, required this.onTap, this.label = 'Start a post', this.photo, this.initials});

  final VoidCallback onTap;

  /// The words in the pill; the Forums tab asks for a discussion.
  final String label;

  /// The reader, drawn at the pill's left when given.
  final FeedPicture? photo;
  final String? initials;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: HomeLook.pad),
      child: Row(
        children: [
          if (initials != null) ...[
            FeedAvatar(photo: photo, initials: initials!, size: 36),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Material(
              color: HomeLook.card,
              shape: const StadiumBorder(side: BorderSide(color: HomeLook.soft, width: 1)),
              child: InkWell(
                key: const ValueKey('home-composer'),
                onTap: onTap,
                customBorder: const StadiumBorder(),
                child: SizedBox(
                  height: 40,
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(label, style: HomeType.composerHint, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      const Icon(LucideIcons.image, size: 20, color: HomeLook.soft),
                      const SizedBox(width: 14),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// All Feed · Trending · Following · Unanswered · Polls, then the topic chips (the tags the discussions carry,
/// most used first), scrolling sideways. One chip is active at a time.
class FeedFilterChips extends StatelessWidget {
  const FeedFilterChips({
    super.key,
    required this.selected,
    required this.selectedTag,
    required this.onSelected,
    required this.onTopic,
    this.topics = const [],
  });

  final FeedFilter selected;
  final String? selectedTag;

  /// The topic chips; none, none drawn.
  final List<FeedTopic> topics;
  final ValueChanged<FeedFilter> onSelected;
  final ValueChanged<String> onTopic;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      for (final filter in FeedFilter.values)
        FeedChip(
          label: filter.label,
          large: filter == FeedFilter.polls,
          active: selectedTag == null && filter == selected,
          onTap: () => onSelected(filter),
        ),
      for (final topic in topics)
        FeedChip(
          label: topic.label,
          large: true,
          active: selectedTag?.toLowerCase() == topic.tag.toLowerCase(),
          onTap: () => onTopic(topic.tag),
        ),
    ];
    return SizedBox(
      height: FeedChip.height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: HomeLook.pad),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) => chips[i],
      ),
    );
  }
}

/// One pill of the chip rows (the Home feed's, the Forums tab's), as LinkedIn draws a filter: a small outlined
/// pill in 60 % black, filled near-black when it is on. [large] and [emphasis] are kept for callers; the look
/// draws every chip the same.
class FeedChip extends StatelessWidget {
  const FeedChip({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
    this.large = false,
    this.emphasis = false,
  });

  static const height = 32.0;

  final String label;
  final bool active;
  final bool large;
  final bool emphasis;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = StadiumBorder(
      side: active ? BorderSide.none : const BorderSide(color: HomeLook.soft, width: 1),
    );
    return Semantics(
      selected: active,
      button: true,
      child: Material(
        color: active ? HomeLook.chipActive : HomeLook.card,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: SizedBox(
            height: height,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                widthFactor: 1,
                child: Text(label, style: HomeType.chip.copyWith(color: active ? Colors.white : HomeLook.soft)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
