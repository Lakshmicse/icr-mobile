import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';

/// The look of a workspace page (Nov 2026 redesign): white sections edge to edge on a light grey page, one 8 dp
/// step between them and a hairline between rows, never a box or a border round a card (the owner's rule). A page
/// is a [WsScroll] of [WsSection]s; a section holds rows ([WsRow]), a grid of figures ([WsKpiGrid]), bars
/// ([WsBar]) and rings ([WsRing]), with pill buttons ([WsButton]) and text links ([WsLink]) for what it offers.
class WsColors {
  WsColors._();

  /// The page behind the sections.
  static const page = Color(0xFFF2F4F6);
  static const hairline = AppColors.outlineVariant;

  /// The brand's quiet fills: a track, a tonal button, a date tile.
  static const tint = Color(0xFFE8F0F9);
  static const tintInk = AppColors.primary;
  static const good = Color(0xFF128A52);
  static const goodTint = Color(0xFFE6F6EE);
  static const warn = Color(0xFFB45309);
  static const warnTint = Color(0xFFFFF4E0);
  static const grey = Color(0xFFEEF1F4);
}

class WsText {
  WsText._();

  static final sectionTitle = AppText.workSans(15, FontWeight.w700, AppColors.onSurface, lineHeight: 20);
  static final sectionNote = AppText.plexSans(11.5, FontWeight.w500, AppColors.outline, lineHeight: 16);
  static final link = AppText.plexSans(12.5, FontWeight.w600, AppColors.primary, lineHeight: 16);
  static final title = AppText.workSans(13.5, FontWeight.w600, AppColors.onSurface, lineHeight: 18);
  static final body = AppText.plexSans(12, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 17);
  static final bodyStrong = AppText.plexSans(12, FontWeight.w600, AppColors.onSurface, lineHeight: 17);
  static final meta = AppText.plexSans(11, FontWeight.w500, AppColors.outline, lineHeight: 15);
  static final kpiLabel = AppText.plexSans(11, FontWeight.w600, AppColors.onSurfaceVariant, lineHeight: 14);
  static final kpiValue = AppText.workSans(22, FontWeight.w700, AppColors.onSurface, lineHeight: 26);
  static final kpiSuffix = AppText.plexSans(12, FontWeight.w600, AppColors.outline, lineHeight: 16);
  static final kpiSub = AppText.plexSans(11, FontWeight.w500, AppColors.outline, lineHeight: 15);
  static final chip = AppText.plexSans(10.5, FontWeight.w600, AppColors.onSurfaceVariant, lineHeight: 13);
  static final button = AppText.plexSans(12, FontWeight.w600, Colors.white, lineHeight: 16);
  static final big = AppText.workSans(28, FontWeight.w700, AppColors.primary, lineHeight: 32);
}

/// A workspace page's body: its sections on the grey page, pull to refresh, and the loading and failed states.
class WsScroll extends StatelessWidget {
  const WsScroll({
    super.key,
    required this.children,
    required this.onRefresh,
    this.loading = false,
    this.error,
    this.errorTitle = 'Unable to Load This Page',
    this.header,
  });

  final List<Widget> children;
  final Future<void> Function() onRefresh;
  final bool loading;
  final String? error;
  final String errorTitle;

  /// Drawn above the sections, on white (a row of tabs).
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final List<Widget> body;
    if (loading && children.isEmpty) {
      body = const [
        SizedBox(
          height: 320,
          child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4))),
        ),
      ];
    } else if (error != null && children.isEmpty) {
      body = [
        WsSection(
          children: [
            WsEmpty(
              icon: Icons.cloud_off_outlined,
              title: errorTitle,
              body: error!,
              action: 'Try Again',
              onAction: onRefresh,
            ),
          ],
        ),
      ];
    } else {
      body = [
        for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 8), children[i]],
      ];
    }
    return ColoredBox(
      color: WsColors.page,
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            if (header != null) ColoredBox(color: Colors.white, child: header),
            if (header != null) const SizedBox(height: 8),
            ...body,
          ],
        ),
      ),
    );
  }
}

/// One white section: a heading (with a note beside it and a link or button at its end), then its content.
class WsSection extends StatelessWidget {
  const WsSection({
    super.key,
    this.title,
    this.note,
    this.action,
    this.onAction,
    this.trailing,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 14),
    this.footer,
    this.onFooter,
  });

  final String? title;

  /// A short fact beside the heading ("1 of 4 achieved").
  final String? note;

  /// A text link at the heading's end ("View calendar").
  final String? action;
  final VoidCallback? onAction;

  /// Anything else at the heading's end, in place of [action].
  final Widget? trailing;
  final List<Widget> children;
  final EdgeInsets padding;

  /// A full-width link under a hairline ("See all saved").
  final String? footer;
  final VoidCallback? onFooter;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (title != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // The heading and its note take what the link at the end leaves.
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(child: Text(title!, style: WsText.sectionTitle)),
                              if (note != null) ...[
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    note!,
                                    style: WsText.sectionNote,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (trailing != null)
                          trailing!
                        else if (action != null)
                          WsLink(label: action!, onTap: onAction),
                      ],
                    ),
                  ),
                ...children,
              ],
            ),
          ),
          if (footer != null) ...[
            const WsDivider(),
            InkWell(
              onTap: onFooter,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(footer!, style: WsText.link),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward, size: 15, color: AppColors.primary),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The hairline between rows.
class WsDivider extends StatelessWidget {
  const WsDivider({super.key, this.indent = 0});

  final double indent;

  @override
  Widget build(BuildContext context) => Divider(height: 1, thickness: 1, color: WsColors.hairline, indent: indent);
}

/// A row: something at the start (a face, a date, an icon), a title with lines under it, and something at the end.
class WsRow extends StatelessWidget {
  const WsRow({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.meta,
    this.trailing,
    this.below,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(vertical: 12),
    this.titleMaxLines = 2,
  });

  final Widget? leading;
  final String title;
  final String? subtitle;
  final String? meta;
  final Widget? trailing;

  /// Under the lines, full width of the text column (a bar, chips, buttons).
  final Widget? below;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final int titleMaxLines;

  @override
  Widget build(BuildContext context) {
    // A row of one line sits centred on what is beside it; a taller one hangs from the top.
    final single = (subtitle == null || subtitle!.isEmpty) && (meta == null || meta!.isEmpty) && below == null;
    final row = Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: single ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: WsText.title, maxLines: titleMaxLines, overflow: TextOverflow.ellipsis),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: WsText.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                if (meta != null && meta!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(meta!, style: WsText.meta, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                if (below != null) ...[const SizedBox(height: 8), below!],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      ),
    );
    return onTap == null ? row : InkWell(onTap: onTap, child: row);
  }
}

/// Rows with a hairline between each.
class WsRows extends StatelessWidget {
  const WsRows({super.key, required this.children, this.indent = 0});

  final List<Widget> children;
  final double indent;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < children.length; i++) ...[if (i > 0) WsDivider(indent: indent), children[i]],
    ],
  );
}

/// One figure of a [WsKpiGrid].
class WsKpi {
  const WsKpi({
    required this.label,
    required this.value,
    this.suffix,
    this.sub,
    this.icon,
    this.meter,
    this.warn = false,
    this.key,
  });

  final String label;
  final String value;

  /// After the value, quieter ("/ 4", "Nov").
  final String? suffix;
  final String? sub;
  final IconData? icon;

  /// 0–1: a bar under the value.
  final double? meter;

  /// The line under it reads as a warning ("nothing booked").
  final bool warn;
  final Key? key;
}

/// Figures two to a row, a hairline between them: the website's "At a glance" card.
class WsKpiGrid extends StatelessWidget {
  const WsKpiGrid({super.key, required this.items});

  final List<WsKpi> items;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += 2) {
      if (i > 0) rows.add(const WsDivider());
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _cell(items[i], left: true)),
              const VerticalDivider(width: 1, thickness: 1, color: WsColors.hairline),
              Expanded(child: i + 1 < items.length ? _cell(items[i + 1], left: false) : const SizedBox()),
            ],
          ),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }

  Widget _cell(WsKpi k, {required bool left}) {
    return Padding(
      key: k.key,
      padding: EdgeInsets.fromLTRB(left ? 0 : 14, 12, left ? 14 : 0, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (k.icon != null) ...[Icon(k.icon, size: 14, color: AppColors.primary), const SizedBox(width: 6)],
              Expanded(
                child: Text(k.label, style: WsText.kpiLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(k.value, style: WsText.kpiValue, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              if (k.suffix != null) ...[const SizedBox(width: 4), Text(k.suffix!, style: WsText.kpiSuffix)],
            ],
          ),
          if (k.meter != null) ...[const SizedBox(height: 6), WsBar(value: k.meter!, color: WsColors.good)],
          if (k.sub != null) ...[
            const SizedBox(height: 4),
            Text(
              k.sub!,
              style: k.warn ? WsText.kpiSub.copyWith(color: WsColors.warn) : WsText.kpiSub,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

/// A 6 dp rounded bar on the brand's tint.
class WsBar extends StatelessWidget {
  const WsBar({super.key, required this.value, this.color = AppColors.primary, this.height = 6});

  /// 0–1.
  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(height),
    child: LinearProgressIndicator(
      value: value.clamp(0, 1).toDouble(),
      minHeight: height,
      backgroundColor: WsColors.tint,
      valueColor: AlwaysStoppedAnimation(color),
    ),
  );
}

/// A ring filled to [value] (0–1) with [center] inside.
class WsRing extends StatelessWidget {
  const WsRing({
    super.key,
    required this.value,
    this.size = 76,
    this.stroke = 8,
    this.color = WsColors.good,
    this.center,
  });

  final double value;
  final double size;
  final double stroke;
  final Color color;
  final Widget? center;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      painter: _RingPainter(value.clamp(0, 1).toDouble(), stroke, color),
      child: Center(child: center),
    ),
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.stroke, this.color);

  final double value;
  final double stroke;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = WsColors.tint;
    canvas.drawArc(arc, 0, math.pi * 2, false, track);
    if (value <= 0) return;
    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(arc, -math.pi / 2, math.pi * 2 * value, false, fill);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value || old.color != color || old.stroke != stroke;
}

/// The tone of a [WsChip].
enum WsTone { grey, brand, good, warn }

/// A small pill on a fill, never an outline.
class WsChip extends StatelessWidget {
  const WsChip(this.label, {super.key, this.tone = WsTone.grey, this.icon});

  final String label;
  final WsTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (bg, ink) = switch (tone) {
      WsTone.grey => (WsColors.grey, AppColors.onSurfaceVariant),
      WsTone.brand => (WsColors.tint, AppColors.primary),
      WsTone.good => (WsColors.goodTint, WsColors.good),
      WsTone.warn => (WsColors.warnTint, WsColors.warn),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: ink), const SizedBox(width: 4)],
          Text(label, style: WsText.chip.copyWith(color: ink)),
        ],
      ),
    );
  }
}

/// A pill button: filled for the one thing a section asks, tonal (the brand's tint) otherwise. No outline.
class WsButton extends StatelessWidget {
  const WsButton({super.key, required this.label, this.icon, this.onPressed, this.filled = false, this.expand = false});

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool filled;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final ink = filled ? Colors.white : AppColors.primary;
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: 15, color: ink), const SizedBox(width: 6)],
        Flexible(
          child: Text(
            label,
            style: WsText.button.copyWith(color: ink),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
    // Its own node: without `container` the button flag merges up and a reader announces the whole section.
    return Semantics(
      container: true,
      button: true,
      child: Material(
        color: filled ? AppColors.primary : WsColors.tint,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onPressed,
          // No alignment: an aligned box grows to the width it is offered, and a button is as wide as its words.
          child: Container(height: 34, padding: const EdgeInsets.symmetric(horizontal: 14), child: child),
        ),
      ),
    );
  }
}

/// A text link ("View calendar").
class WsLink extends StatelessWidget {
  const WsLink({super.key, required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(6),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Text(label, style: WsText.link),
    ),
  );
}

/// An empty section: an icon in a tinted circle, a title, a sentence and a button.
class WsEmpty extends StatelessWidget {
  const WsEmpty({super.key, required this.icon, required this.title, required this.body, this.action, this.onAction});

  final IconData icon;
  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(color: WsColors.tint, shape: BoxShape.circle),
          child: Icon(icon, size: 24, color: AppColors.primary),
        ),
        const SizedBox(height: 10),
        Text(title, style: WsText.title, textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(body, style: WsText.body, textAlign: TextAlign.center),
        if (action != null) ...[
          const SizedBox(height: 12),
          WsButton(label: action!, filled: true, onPressed: onAction),
        ],
      ],
    ),
  );
}

const _weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
const _months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];

/// A day as a tile: the month, the date large, the weekday.
class WsDateTile extends StatelessWidget {
  const WsDateTile({super.key, required this.at, this.highlight = false});

  final DateTime at;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final d = at.toLocal();
    final ink = highlight ? Colors.white : AppColors.primary;
    return Container(
      width: 46,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: highlight ? AppColors.primary : WsColors.tint,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(_months[d.month - 1], style: WsText.chip.copyWith(color: ink, fontSize: 9.5, letterSpacing: 0.4)),
          Text('${d.day}', style: AppText.workSans(18, FontWeight.w700, ink, lineHeight: 22)),
          Text(_weekdays[d.weekday - 1], style: WsText.chip.copyWith(color: ink, fontSize: 9.5, letterSpacing: 0.4)),
        ],
      ),
    );
  }
}

/// An icon in a tinted circle, at the start of a row.
class WsIconDot extends StatelessWidget {
  const WsIconDot({super.key, required this.icon, this.tone = WsTone.brand, this.size = 36});

  final IconData icon;
  final WsTone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (bg, ink) = switch (tone) {
      WsTone.grey => (WsColors.grey, AppColors.onSurfaceVariant),
      WsTone.brand => (WsColors.tint, AppColors.primary),
      WsTone.good => (WsColors.goodTint, WsColors.good),
      WsTone.warn => (WsColors.warnTint, WsColors.warn),
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(icon, size: size * 0.48, color: ink),
    );
  }
}
