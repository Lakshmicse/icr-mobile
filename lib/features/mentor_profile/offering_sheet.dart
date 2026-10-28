import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/detail_sheet.dart';
import '../../core/widgets/section_heading.dart';
import 'mentor_profile_actions.dart';
import 'mentor_profile_controller.dart';
import 'mentor_profile_format.dart';
import 'mentor_profile_models.dart';
import 'mentor_profile_styles.dart';
import 'widgets/mentor_picture.dart';

/// Opens an offering over the profile, as the Offering design: its photo,
/// what it is, the programme details and roadmap, and the price bar with the
/// way in. Reads the page's [MentorProfileController] from [context].
///
/// A programme the mentor lists in several terms ("1 Month", "3 Months")
/// opens with a toggle between them; the roadmap, the tiles, the price and
/// the button all follow the term chosen. With one term there is no toggle.
Future<void> showOfferingSheet(BuildContext context, MentorOffering offering) async {
  final controller = context.read<MentorProfileController>();
  final pageContext = context;
  final terms = controller.variantsOf(offering);
  final selection = ValueNotifier<int>(math.max(0, terms.indexWhere((t) => t.id == offering.id)));
  await showDetailSheet<void>(
    context,
    topInset: 24,
    body: (_) => OfferingSheetBody(offering: offering, terms: terms, selection: selection),
    bottomBar: (sheet) => ListenableBuilder(
      listenable: Listenable.merge([controller, selection]),
      builder: (_, _) {
        final chosen = terms[selection.value.clamp(0, terms.length - 1)];
        final current = controller.offerings.firstWhere((o) => o.id == chosen.id, orElse: () => chosen);
        final plan = controller.featuredPlan;
        final showPlan = plan != null && plan.id != current.id;
        return OfferingSheetBar(
          offering: current,
          plan: showPlan ? plan : null,
          onPlans: showPlan
              ? () {
                  Navigator.pop(sheet);
                  showOfferingSheet(pageContext, plan);
                }
              : null,
          onPrimary: () async {
            final done = await runOfferingAction(sheet, controller, current);
            if (done && sheet.mounted) Navigator.pop(sheet);
          },
        );
      },
    ),
  );
}

IconData glyphIcon(OfferingGlyph glyph) => switch (glyph) {
  OfferingGlyph.calendar => LucideIcons.calendarDays,
  OfferingGlyph.clock => LucideIcons.clock,
  OfferingGlyph.list => LucideIcons.listOrdered,
  OfferingGlyph.chat => LucideIcons.messagesSquare,
  OfferingGlyph.person => LucideIcons.user,
  OfferingGlyph.sessions => LucideIcons.calendarClock,
  OfferingGlyph.download => LucideIcons.download,
  OfferingGlyph.group => LucideIcons.users,
  OfferingGlyph.infinity => LucideIcons.infinity,
};

/// The scrolling part of the sheet. [terms] are the terms one programme is
/// listed in (shortest first; omitted for a single offering) and [selection]
/// the index of the one shown, shared with the price bar.
class OfferingSheetBody extends StatefulWidget {
  const OfferingSheetBody({super.key, required this.offering, this.terms, this.selection});

  final MentorOffering offering;
  final List<MentorOffering>? terms;
  final ValueNotifier<int>? selection;

  @override
  State<OfferingSheetBody> createState() => _OfferingSheetBodyState();
}

class _OfferingSheetBodyState extends State<OfferingSheetBody> {
  final _own = ValueNotifier<int>(0);

  ValueNotifier<int> get _selection => widget.selection ?? _own;

  @override
  void dispose() {
    _own.dispose();
    super.dispose();
  }

  /// One roadmap term per listed term; a lone offering uses its own roadmap.
  List<RoadmapTerm> _roadmap(MentorOffering o, List<MentorOffering> terms) {
    if (terms.length < 2) return o.roadmap;
    return [
      for (final t in terms)
        RoadmapTerm(
          label: termLabel(t.termMonths ?? t.accessMonths ?? 1),
          modules: [for (final r in t.roadmap) ...r.modules],
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _selection,
      builder: (context, index, _) {
        final o = widget.offering;
        final terms = widget.terms ?? [o];
        final roadmap = _roadmap(o, terms);
        final at = roadmap.isEmpty ? 0 : index.clamp(0, roadmap.length - 1);
        // What the sheet describes follows the term chosen.
        final shown = terms.length > 1 ? terms[at.clamp(0, terms.length - 1)] : o;
        final title = shown.sheetTitle ?? shown.title;
        final blurb = shown.sheetBlurb ?? shown.blurb;
        final term = roadmap.isEmpty ? null : roadmap[at];
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(15.1, 6.2, 15.1, 0),
              child: _Photo(offering: shown, fallback: o.cover),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(15.6, 17.6, 15.6, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 22,
                    child: Text(title, style: MentorText.sheetTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  if (blurb != null && blurb.isNotEmpty) ...[
                    const SizedBox(height: 8.8),
                    Text(blurb, style: MentorText.sheetBlurb),
                  ],
                  if (shown.facts.isNotEmpty) ...[
                    const SizedBox(height: 8.7),
                    Wrap(spacing: 9.6, runSpacing: 8, children: [for (final f in shown.facts) _FactChip(fact: f)]),
                  ],
                  if (shown.details.isNotEmpty) ...[
                    const SizedBox(height: 12.8),
                    SizedBox(height: 16, child: Text('Program Details', style: MentorText.sheetSection)),
                    const SizedBox(height: 8.2),
                    _DetailGrid(details: shown.details),
                  ],
                  if (term != null) ...[
                    const SizedBox(height: 11.4),
                    SizedBox(height: 20, child: Text('Curriculum Roadmap', style: MentorText.sheetSectionWide)),
                    if (roadmap.length > 1) ...[
                      const SizedBox(height: 2.4),
                      _Segments(
                        labels: [for (final t in roadmap) t.label],
                        selected: at,
                        onSelect: (i) => _selection.value = i,
                      ),
                    ],
                    const SizedBox(height: 26.3),
                    for (final (i, m) in term.modules.indexed) ...[
                      if (i > 0) const SizedBox(height: 16),
                      _ModuleBlock(module: m, number: i + 1),
                    ],
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.offering, this.fallback});

  final MentorOffering offering;

  /// The first term's photo, for a term that has none of its own.
  final FeedPicture? fallback;

  @override
  Widget build(BuildContext context) {
    final o = offering;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 165.4,
        child: Stack(
          fit: StackFit.expand,
          children: [
            MentorPicture(picture: o.cover ?? fallback, alignment: Alignment.topCenter, fallback: const NavyFallback()),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00101828), Color(0xB3101828)],
                  stops: [0.5, 1],
                ),
              ),
            ),
            Positioned(
              left: 13.5,
              bottom: 12,
              child: Container(
                height: 20.8,
                padding: const EdgeInsets.symmetric(horizontal: 7.3),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: MentorColors.photoPill, borderRadius: BorderRadius.circular(6)),
                child: Text(o.kicker, style: MentorText.sheetKicker),
              ),
            ),
            if (o.ratingCount > 0)
              Positioned(
                right: 13,
                bottom: 13.5,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Symbols.star, fill: 1, size: 13, color: MentorColors.starMint),
                    const SizedBox(width: 3.5),
                    Text(
                      '${o.rating.toStringAsFixed(2)} (${o.ratingCount} review${o.ratingCount == 1 ? '' : 's'})',
                      style: MentorText.sheetRating,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FactChip extends StatelessWidget {
  const _FactChip({required this.fact});

  final OfferingFact fact;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 29.6,
      padding: const EdgeInsets.only(left: 9, right: 10.4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(glyphIcon(fact.glyph), size: 13, color: MentorColors.sheetInk),
          const SizedBox(width: 1.9),
          Text(fact.label, style: MentorText.sheetFact),
        ],
      ),
    );
  }
}

/// The 2 × 2 tiles; touching rows, a gap between the columns.
class _DetailGrid extends StatelessWidget {
  const _DetailGrid({required this.details});

  final List<OfferingDetail> details;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < details.length; i += 2) {
      rows.add(
        SizedBox(
          height: 90,
          child: Row(
            children: [
              Expanded(child: _DetailTile(detail: details[i])),
              const SizedBox(width: 9.9),
              Expanded(child: i + 1 < details.length ? _DetailTile(detail: details[i + 1]) : const SizedBox.shrink()),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({required this.detail});

  final OfferingDetail detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(7.8, 7.1, 7, 0),
      decoration: BoxDecoration(
        color: MentorColors.tileFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MentorColors.tileBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 0),
            child: Icon(glyphIcon(detail.glyph), size: 19.5, color: MentorColors.sheetInk),
          ),
          const SizedBox(width: 7.5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 18,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(detail.title, style: MentorText.tileTitle, maxLines: 1),
                  ),
                ),
                const SizedBox(height: 2.7),
                SizedBox(
                  width: 127.8,
                  child: Text(detail.body, style: MentorText.tileBody, maxLines: 3, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Segments extends StatelessWidget {
  const _Segments({required this.labels, required this.selected, required this.onSelect});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 35.9,
      padding: const EdgeInsets.symmetric(horizontal: 4.2, vertical: 4.15),
      decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          for (final (i, label) in labels.indexed)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == selected,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSelect(i),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == selected ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(label, style: i == selected ? MentorText.segmentSelected : MentorText.segment),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ModuleBlock extends StatelessWidget {
  const _ModuleBlock({required this.module, required this.number});

  final RoadmapModule module;
  final int number;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 24.4,
            child: Row(
              children: [
                Container(
                  width: 22.9,
                  height: 22.9,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: AppColors.surfaceContainer, shape: BoxShape.circle),
                  child: Text('$number', style: MentorText.moduleNumber),
                ),
                const SizedBox(width: 9.4),
                Expanded(
                  child: Text(
                    module.title,
                    style: MentorText.moduleTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (module.badge != null)
                  Container(
                    height: 24.4,
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(6)),
                    child: Text(module.badge!, style: MentorText.moduleBadge),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4.9),
          for (final (i, step) in module.steps.indexed) ...[
            _Step(text: step),
            if (i < module.steps.length - 1) const Hairline(color: AppColors.blockRule),
          ],
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final cut = text.indexOf(':');
    return SizedBox(
      height: 45.8,
      child: Align(
        alignment: Alignment.centerLeft,
        child: cut < 0
            ? Text(text, style: MentorText.step)
            : Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: text.substring(0, cut + 1), style: MentorText.stepLead),
                    TextSpan(text: text.substring(cut + 1), style: MentorText.step),
                  ],
                ),
              ),
      ),
    );
  }
}

/// What the bar says about the money.
class _BarPricing {
  const _BarPricing({required this.label, required this.amount, this.per, this.compareAt, this.pill, this.note});

  final String label;
  final String amount;
  final String? per;
  final String? compareAt;
  final String? pill;
  final String? note;
}

_BarPricing _pricingFor(MentorOffering o, MentorOffering? plan) {
  final trial = o.isRequested && o.kind != OfferingKind.query && o.free;
  if (trial && plan != null) {
    return _BarPricing(
      label: 'Starts at',
      amount: inr(plan.perMonthPaisa ?? plan.pricePaisa),
      per: '/mo',
      pill: 'Trial: ₹0',
      note: '+ applicable taxes',
    );
  }
  final note = switch (o.kind) {
    OfferingKind.resource => 'Instant download',
    OfferingKind.query => 'Answer within ${o.slaHours ?? 72}h',
    OfferingKind.plan => '+ applicable taxes',
    OfferingKind.program => 'Pay after the mentor accepts',
    OfferingKind.groupSession => o.seatsLeft == null ? null : '${o.seatsLeft} seats left',
    OfferingKind.oneOnOne => o.free ? 'The mentor sets the time' : 'Pay after the mentor accepts',
  };
  if (o.free) return _BarPricing(label: 'Price', amount: 'Free', pill: 'Trial: ₹0', note: note);
  return _BarPricing(
    // A plan starts at its monthly price; a programme costs its term's price.
    label: o.kind == OfferingKind.plan ? 'Starts at' : 'Price',
    amount: inr(o.kind == OfferingKind.plan ? (o.perMonthPaisa ?? o.pricePaisa) : o.pricePaisa),
    per: o.kind == OfferingKind.plan ? '/mo' : null,
    compareAt: o.compareAtPaisa != null && o.compareAtPaisa! > o.pricePaisa ? inr(o.compareAtPaisa!) : null,
    note: note,
  );
}

/// The bar under the sheet: the price at the left, "Plans", and the way in.
class OfferingSheetBar extends StatelessWidget {
  const OfferingSheetBar({super.key, required this.offering, this.plan, this.onPlans, this.onPrimary});

  final MentorOffering offering;

  /// The mentor's ongoing plan, for "Starts at … /mo" and the Plans button.
  final MentorOffering? plan;
  final VoidCallback? onPlans;
  final VoidCallback? onPrimary;

  @override
  Widget build(BuildContext context) {
    final o = offering;
    final pricing = _pricingFor(o, plan);
    final trial = o.isRequested && o.kind != OfferingKind.query && o.free;
    final requested = o.myOpenRequestId != null;
    final label = requested
        ? 'Requested'
        : trial
        ? 'Book Trial (₹0)'
        : o.free
        ? '${o.ctaLabel} (₹0)'
        : o.ctaLabel;
    final icon = switch (o.kind) {
      OfferingKind.resource => LucideIcons.download,
      OfferingKind.query => LucideIcons.messageSquare,
      _ => LucideIcons.calendar,
    };
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20.6, 13, 12.5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 18,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text('${pricing.label} ', style: MentorText.startsAt),
                          if (pricing.compareAt != null) ...[
                            Text(pricing.compareAt!, style: MentorText.wasPrice.copyWith(fontSize: 12)),
                            const SizedBox(width: 4),
                          ],
                          Text(pricing.amount, style: MentorText.startsPrice),
                          if (pricing.per != null) Text(' ${pricing.per}', style: MentorText.startsPer),
                        ],
                      ),
                    ),
                    const SizedBox(height: 5.6),
                    // The trial pill and the tax note share a line while they fit and stack when they do not
                    // (the note was cut at the card's edge at the app's text size).
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6.4,
                      runSpacing: 2,
                      children: [
                        if (pricing.pill != null)
                          IntrinsicWidth(
                            child: Container(
                              height: 23.9,
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: MentorColors.mint,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(pricing.pill!, style: MentorText.trialPill),
                            ),
                          ),
                        if (pricing.note != null) Text(pricing.note!, style: MentorText.taxes),
                      ],
                    ),
                  ],
                ),
              ),
              if (onPlans != null) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4.6),
                  child: SizedBox(
                    width: 59.8,
                    height: 35.4,
                    child: Material(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: onPlans,
                        borderRadius: BorderRadius.circular(8),
                        child: Center(child: Text('Plans', style: MentorText.plansButton)),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 7.8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4.6),
                child: SizedBox(
                  width: 143,
                  height: 35.4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.28),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Material(
                      color: requested || onPrimary == null
                          ? AppColors.primary.withValues(alpha: 0.5)
                          : AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: requested ? null : onPrimary,
                        borderRadius: BorderRadius.circular(8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(icon, size: 12.5, color: Colors.white),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                label,
                                style: MentorText.sheetButton,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
