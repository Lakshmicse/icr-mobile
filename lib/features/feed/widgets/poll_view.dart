import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../feed_models.dart';
import '../feed_styles.dart';

/// A poll's options as LinkedIn draws them: outlined blue pills, each filled to its share, the reader's vote
/// ticked and set in ink.
class PollView extends StatelessWidget {
  const PollView({
    super.key,
    required this.poll,
    required this.onVote,
    required this.onViewDiscussion,
    this.showLink = true,
  });

  final FeedPoll poll;
  final ValueChanged<String> onVote;
  final VoidCallback onViewDiscussion;

  /// "View Discussion" under the bars; the discussion's own page leaves it out.
  final bool showLink;

  @override
  Widget build(BuildContext context) {
    final percents = poll.percents;
    final footer = [
      '${poll.totalVotes} ${poll.totalVotes == 1 ? 'vote' : 'votes'}',
      // The API gives a poll no closing date, so a live one says what it knows: it takes votes, or it does not.
      if (!poll.open) 'Closed' else poll.timeLeft ?? 'Open',
    ].join(' • ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < poll.options.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _OptionBar(
            key: ValueKey('poll-option:${poll.options[i].id}'),
            option: poll.options[i],
            percent: percents[i],
            mine: poll.options[i].id == poll.myOptionId,
            onTap: poll.open ? () => onVote(poll.options[i].id) : null,
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: Text(footer, style: HomeType.pollFooter)),
            if (showLink)
              Semantics(
                button: true,
                child: GestureDetector(
                  key: const ValueKey('view-discussion'),
                  onTap: onViewDiscussion,
                  behavior: HitTestBehavior.opaque,
                  child: Text('View Discussion', style: HomeType.pollLink),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _OptionBar extends StatelessWidget {
  const _OptionBar({super.key, required this.option, required this.percent, required this.mine, required this.onTap});

  final FeedPollOption option;
  final int percent;
  final bool mine;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ink = mine ? HomeLook.ink : HomeLook.blue;
    return Semantics(
      button: onTap != null,
      selected: mine,
      label: '${option.label}, $percent percent${mine ? ', your vote' : ''}',
      excludeSemantics: true,
      child: Material(
        color: HomeLook.card,
        shape: StadiumBorder(side: BorderSide(color: ink, width: mine ? 1.5 : 1)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 36,
            child: Stack(
              children: [
                FractionallySizedBox(
                  widthFactor: percent / 100,
                  heightFactor: 1,
                  child: ColoredBox(color: mine ? HomeLook.searchFill : const Color(0xFFE8F3FB)),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        if (mine) ...[
                          const Icon(LucideIcons.circleCheck, size: 16, color: HomeLook.ink),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            mine ? '${option.label} (Your vote)' : option.label,
                            style: HomeType.pollOption.copyWith(color: ink),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text('$percent%', style: HomeType.pollPercent.copyWith(color: ink)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
