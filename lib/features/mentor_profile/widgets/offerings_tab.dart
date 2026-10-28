import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/section_heading.dart';
import '../mentor_profile_format.dart';
import '../mentor_profile_models.dart';
import '../mentor_profile_styles.dart';

/// The Offerings tab: the filter chips, the hint, and one row per offering.
class OfferingsTab extends StatelessWidget {
  const OfferingsTab({
    super.key,
    required this.filters,
    required this.filter,
    required this.onFilter,
    required this.rows,
    required this.onOpen,
    required this.onAction,
  });

  final List<OfferingFilter> filters;
  final OfferingFilter filter;
  final ValueChanged<OfferingFilter> onFilter;
  final List<MentorOffering> rows;
  final ValueChanged<MentorOffering> onOpen;
  final ValueChanged<MentorOffering> onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 9),
        SizedBox(
          height: 25,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 12.8, right: 12),
            itemCount: filters.length,
            separatorBuilder: (_, _) => const SizedBox(width: 5),
            itemBuilder: (context, i) => _FilterChip(
              label: filters[i].label,
              selected: filters[i] == filter,
              wide: i == 0,
              onTap: () => onFilter(filters[i]),
            ),
          ),
        ),
        const SizedBox(height: 9),
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 18.4),
          child: Container(
            height: 42.2,
            padding: const EdgeInsets.only(left: 6.8, right: 8, top: 0.5),
            decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                const SizedBox(width: 3),
                const Icon(Symbols.touch_app, size: 16, color: AppColors.primary),
                const SizedBox(width: 5.7),
                Expanded(
                  child: Text(
                    'Tap any offering to inspect curriculum breakdown & lock your schedule.',
                    style: MentorText.info,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 28, 18, 28),
            child: Text(
              'Nothing here yet. This mentor has not listed anything under this filter.',
              style: MentorText.body,
              textAlign: TextAlign.center,
            ),
          )
        else
          for (final (i, o) in rows.indexed)
            OfferingRow(offering: o, first: i == 0, onOpen: () => onOpen(o), onAction: () => onAction(o)),
        // The design leaves a sliver of white between the last row's rule and the plan card.
        const SizedBox(height: 2),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.wide, required this.onTap});

  final String label;
  final bool selected;
  final bool wide;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = StadiumBorder(side: selected ? BorderSide.none : const BorderSide(color: Color(0xFFEBECEE)));
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.primary : Colors.white,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: SizedBox(
            height: 25,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: wide ? 12.5 : 10),
              child: Center(
                widthFactor: 1,
                child: Text(label, style: selected ? MentorText.filterSelected : MentorText.filter),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One offering: its tags and price, title, two lines of copy and the way in.
/// 131 dp and a hairline, as the design's rows.
class OfferingRow extends StatelessWidget {
  const OfferingRow({
    super.key,
    required this.offering,
    required this.first,
    required this.onOpen,
    required this.onAction,
  });

  final MentorOffering offering;
  final bool first;
  final VoidCallback onOpen;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final o = offering;
    final hasGreen = o.tags.any((t) => t.green);
    final requested = o.myOpenRequestId != null;
    final booked = o.myUpcomingBookingAt != null;
    final hasPreview = o.previewLabel != null;
    return InkWell(
      onTap: onOpen,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, (first ? 16.3 : 21.3) + (hasGreen ? 3.6 : 0), 18, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 15.5,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(left: 0, top: 0, bottom: 0, child: _Tags(tags: o.tags)),
                      Positioned(
                        right: 0,
                        top: hasGreen ? 0.75 : (o.free ? 6.6 : 4.5),
                        child: _Price(offering: o),
                      ),
                    ],
                  ),
                ),
                // The design's row with a preview link sets its title a little lower and the link a little closer.
                SizedBox(height: hasGreen ? 6.9 : (hasPreview ? 11.5 : 10.5)),
                Text(o.title, style: MentorText.offeringTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 0.15),
                // Two lines of room at the blurb's own size and line height (never a fixed 29.8 dp, which cut the
                // second line at the app's 13 sp).
                if (o.blurb != null)
                  ConstrainedBox(
                    constraints: BoxConstraints(minHeight: _blurbTwoLines, maxWidth: 319),
                    child: Text(
                      o.blurb!,
                      style: MentorText.offeringBlurb,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                else
                  SizedBox(height: _blurbTwoLines),
                SizedBox(height: hasPreview ? 7.95 : 3.95),
                SizedBox(
                  height: 25.5,
                  child: Row(
                    children: [
                      if (o.previewLabel != null)
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    o.previewLabel!,
                                    style: MentorText.preview,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Icon(LucideIcons.chevronDown, size: 9, color: AppColors.primary),
                              ],
                            ),
                          ),
                        )
                      else
                        const Spacer(),
                      OutlinePillButton(
                        label: booked ? 'Booked' : (requested ? 'Requested' : o.ctaLabel),
                        onPressed: onAction,
                        height: 25.5,
                        padding: const EdgeInsets.symmetric(horizontal: 10.4),
                        textStyle: booked || requested
                            ? MentorText.pill.copyWith(color: AppColors.onSurfaceVariant)
                            : MentorText.pill,
                        borderColor: const Color(0xFFE6E6E6),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: hasPreview ? 9.8 : 10.3),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 15.2, right: 18.3),
            child: Hairline(color: Color(0xFFE4E4E4)),
          ),
        ],
      ),
    );
  }
}

class _Tags extends StatelessWidget {
  const _Tags({required this.tags});

  final List<OfferingTag> tags;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (i, t) in tags.indexed) ...[
          if (i > 0) SizedBox(width: t.green ? 5 : 7),
          if (t.green)
            Text(t.label, style: MentorText.tagGreen)
          else
            Container(
              height: 15.5,
              padding: const EdgeInsets.symmetric(horizontal: 5.4),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(8)),
              child: Text(
                t.label,
                style: t.label == t.label.toUpperCase() && t.label.contains(RegExp('[A-Z]'))
                    ? MentorText.tagStrong
                    : MentorText.tag,
              ),
            ),
        ],
      ],
    );
  }
}

class _Price extends StatelessWidget {
  const _Price({required this.offering});

  final MentorOffering offering;

  @override
  Widget build(BuildContext context) {
    final o = offering;
    if (o.free) return SizedBox(height: 12, child: Text('FREE', style: MentorText.free));
    return SizedBox(
      height: 14,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (o.compareAtPaisa != null && o.compareAtPaisa! > o.pricePaisa) ...[
            Text(inr(o.compareAtPaisa!), style: MentorText.wasPrice),
            const SizedBox(width: 3.4),
          ],
          Text(inr(o.pricePaisa), style: MentorText.price),
        ],
      ),
    );
  }
}

/// Two lines of the offering blurb, at its own size and line height.
double get _blurbTwoLines => 2 * (MentorText.offeringBlurb.fontSize ?? 12) * (MentorText.offeringBlurb.height ?? 1.3);
