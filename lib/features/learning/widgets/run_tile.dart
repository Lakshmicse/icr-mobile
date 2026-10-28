import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../learning_format.dart';
import '../learning_models.dart';
import '../learning_styles.dart';

/// One run in the "Select Date" grid: where, when, the delivery glyph and the
/// corner word. 174 × 74 dp, as the design's tiles. The corner word is the
/// member's own place when they hold one on this run (CONFIRMED in green), else
/// how many places are left (Open, Limited, Full).
class RunTile extends StatelessWidget {
  const RunTile({super.key, required this.run, required this.selected, required this.onTap, this.mine});

  /// Two across the 359 dp content width with a 10.3 dp gap.
  static const width = 174.3;
  static const height = 78.0;

  final CourseRun run;
  final bool selected;
  final VoidCallback onTap;

  /// The member's place on this run, when they hold one.
  final EnrolmentStatus? mine;

  /// The corner word and its style.
  (String, TextStyle) get status {
    if (run.confirmed || mine == EnrolmentStatus.confirmed || mine == EnrolmentStatus.completed) {
      return ('CONFIRMED', LearningText.tileConfirmed);
    }
    if (mine == EnrolmentStatus.pending) return ('REQUESTED', LearningText.tileHeld);
    if (mine == EnrolmentStatus.waitlisted) return ('WAITLISTED', LearningText.tileHeld);
    return (run.availability.label, LearningText.tileStatus);
  }

  @override
  Widget build(BuildContext context) {
    final (word, wordStyle) = status;
    return Semantics(
      button: true,
      selected: selected,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7.5),
          boxShadow: selected ? const [BoxShadow(color: Color(0x14000000), blurRadius: 3, offset: Offset(0, 1))] : null,
        ),
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(7.5),
            side: BorderSide(
              color: selected ? LearningColors.tileSelectedBorder : LearningColors.tileBorder,
              width: selected ? 2 : 1,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(7.5),
            child: SizedBox(
              width: width,
              height: height,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(13, 11, 13, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      run.location ??
                          run.title ??
                          (run.mode == DeliveryMode.inPerson ? 'Venue to be announced' : 'Online'),
                      style: LearningText.tileCity,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      runDates(run.startsAt, run.endsAt),
                      style: selected ? LearningText.tileDate : LearningText.tileDateQuiet,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 7.5),
                    Row(
                      children: [
                        Icon(
                          run.mode == DeliveryMode.inPerson ? Symbols.groups : Symbols.devices,
                          size: 18,
                          color: selected ? AppColors.primary : AppColors.inkMuted,
                        ),
                        const Spacer(),
                        Text(word, style: wordStyle),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The last tile: "Suggest A Date & Location", which asks the ICR team.
class SuggestDateTile extends StatelessWidget {
  const SuggestDateTile({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(7.5),
          side: const BorderSide(color: LearningColors.tileBorder),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(7.5),
          child: SizedBox(
            width: RunTile.width,
            height: RunTile.height,
            child: Column(
              children: [
                const SizedBox(height: 12),
                const Icon(LucideIcons.mapPinPlus, size: 16, color: AppColors.primary),
                const SizedBox(height: 5.5),
                Text('Suggest A Date &\nLocation', style: LearningText.tileSuggest, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }

  final VoidCallback onTap;
}
