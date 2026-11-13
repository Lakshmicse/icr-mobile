import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../feed_models.dart';
import '../feed_styles.dart';

/// A poll's options as tinted pills with no outline, each filled to its share, the reader's vote
/// ticked and set in ink.
class PollView extends StatelessWidget {
  const PollView({
    super.key,
    required this.poll,
    required this.onVote,
    required this.onViewDiscussion,
    this.showLink = true,
    this.isAuthor = false,
    this.onVoters,
  });

  /// "N votes": who voted and for what (the website's voters dialog); absent, the count is plain text.
  final VoidCallback? onVoters;

  final FeedPoll poll;

  /// The reader wrote the poll: they see its results and cannot vote, as on the website.
  final bool isAuthor;
  final ValueChanged<String> onVote;
  final VoidCallback onViewDiscussion;

  /// "View Discussion" under the bars; the discussion's own page leaves it out.
  final bool showLink;

  @override
  Widget build(BuildContext context) {
    final percents = poll.percents;
    // The shares show once the reader has voted, to the author, or once the poll is closed; before that the
    // options are plain, as the website's, so a result never sways a vote.
    final showResults = poll.myOptionId != null || isAuthor || !poll.open;
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
            percent: showResults ? percents[i] : null,
            mine: poll.options[i].id == poll.myOptionId,
            onTap: poll.open && !isAuthor ? () => onVote(poll.options[i].id) : null,
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: onVoters != null && poll.totalVotes > 0
                  ? Semantics(
                      button: true,
                      label: '$footer. Who voted',
                      child: GestureDetector(
                        key: const ValueKey('poll-voters'),
                        behavior: HitTestBehavior.opaque,
                        onTap: onVoters,
                        child: Text(footer, style: HomeType.pollFooter),
                      ),
                    )
                  : Text(footer, style: HomeType.pollFooter),
            ),
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

  /// The option's share of the votes; null while the results are not shown.
  final int? percent;
  final bool mine;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ink = mine ? HomeLook.ink : HomeLook.blue;
    return Semantics(
      button: onTap != null,
      selected: mine,
      label: '${option.label}${percent == null ? '' : ', $percent percent'}${mine ? ', your vote' : ''}',
      excludeSemantics: true,
      // A tinted pill, no outline. A radio before each option while the reader may vote (owner, 7 Nov 2026:
      // "enable radio button for user to click if it's a poll"); the check and "(Your vote)" mark their own.
      child: Material(
        color: AppColors.surfaceContainer,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 36,
            child: Stack(
              children: [
                if (percent != null)
                  FractionallySizedBox(
                    widthFactor: percent! / 100,
                    heightFactor: 1,
                    child: ColoredBox(color: mine ? const Color(0xFFCFE0F2) : const Color(0xFFDCEAF6)),
                  ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        if (mine) ...[
                          const Icon(LucideIcons.circleCheck, size: 16, color: HomeLook.ink),
                          const SizedBox(width: 8),
                        ] else if (onTap != null) ...[
                          Icon(LucideIcons.circle, key: ValueKey('poll-radio:${option.id}'), size: 16, color: ink),
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
                        if (percent != null) Text('$percent%', style: HomeType.pollPercent.copyWith(color: ink)),
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
