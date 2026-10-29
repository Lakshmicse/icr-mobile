import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import 'exam_styles.dart';

/// Pops the route [context] belongs to, once. A second tap landing before the route has gone (two fingers, a
/// double tap in the same frame) must not pop the screen under it too: it asks whether the route is still the
/// one on top. Returns whether it popped.
bool popOnce<T>(BuildContext context, [T? result]) {
  final route = ModalRoute.of(context);
  if (route == null || !route.isCurrent) return false;
  Navigator.of(context).pop(result);
  return true;
}

/// The bar at the top of the result and the exam: white, a soft shadow below, a back arrow and the title.
/// [backLabel] is what a screen reader hears for the arrow ("Leave the exam" in the exam).
class ExamTitleBar extends StatelessWidget {
  const ExamTitleBar({super.key, required this.title, required this.onBack, this.style, this.backLabel = 'Back'});

  final String title;
  final VoidCallback onBack;
  final TextStyle? style;
  final String backLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: backLabel,
            excludeSemantics: true,
            child: InkResponse(
              onTap: onBack,
              radius: 26,
              child: const SizedBox(
                width: 56,
                height: 56,
                child: Icon(Symbols.arrow_back, size: 24, color: AppColors.onSurfaceVariant),
              ),
            ),
          ),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: style ?? ExamText.barTitle),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}

/// A white card with the hairline edge the Learning cards wear.
class ExamCard extends StatelessWidget {
  const ExamCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = Colors.white,
    this.borderColor = ExamColors.cardBorder,
    this.radius = 12,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: borderColor),
    );
    return Material(
      color: color,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : InkWell(
              onTap: onTap,
              customBorder: shape,
              child: Padding(padding: padding, child: child),
            ),
    );
  }
}

/// A small rounded label: an optional glyph and a few words.
class InfoPill extends StatelessWidget {
  const InfoPill({
    super.key,
    required this.label,
    this.icon,
    this.color = AppColors.primary,
    this.fill,
    this.border,
    this.semanticsLabel,
  });

  final String label;
  final IconData? icon;
  final Color color;
  final Color? fill;
  final Color? border;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel ?? label,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: fill ?? Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border ?? color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 15, color: color), const SizedBox(width: 5)],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.plexSans(12, FontWeight.w700, color, lineHeight: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum NoticeTone { info, success, warning, error }

/// A message with a glyph, tinted by what it says; an action may sit under it.
class Notice extends StatelessWidget {
  const Notice({super.key, required this.text, this.tone = NoticeTone.info, this.action, this.onAction, this.child});

  final String text;
  final NoticeTone tone;
  final String? action;
  final VoidCallback? onAction;

  /// Extra content under the text.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color ink, Color fill, Color edge) = switch (tone) {
      NoticeTone.info => (LucideIcons.info, AppColors.primary, const Color(0xFFEFF6FF), const Color(0xFFBFDBFE)),
      NoticeTone.success => (
        LucideIcons.circleCheck,
        AppColors.emerald700,
        ExamColors.correctFill,
        AppColors.emerald200,
      ),
      NoticeTone.warning => (LucideIcons.triangleAlert, AppColors.amber800, ExamColors.warnFill, ExamColors.warnBorder),
      NoticeTone.error => (LucideIcons.circleAlert, AppColors.error, ExamColors.wrongFill, ExamColors.wrongBorder),
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: edge),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 18, color: ink),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: AppText.plexSans(13.5, FontWeight.w500, AppColors.onSurface, lineHeight: 20)),
                ?child,
                if (action != null) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onAction,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(action!, style: ExamText.link.copyWith(color: ink)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The wide button the exam screens end on: 48 dp, a solid fill or an outline.
class ExamButton extends StatelessWidget {
  const ExamButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.quiet = false,
    this.busy = false,
    this.color = AppColors.primary,
    this.height = 48,
    this.radius = 12,
    this.borderColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// An outline instead of a fill.
  final bool quiet;

  /// A spinner in place of the glyph; the button does not answer taps meanwhile.
  final bool busy;
  final Color color;
  final double height;
  final double radius;

  /// The outline of a quiet button; by default the button's colour at half strength.
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final ink = quiet ? color : Colors.white;
    final style = (quiet ? ExamText.buttonQuiet.copyWith(color: color) : ExamText.button);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: quiet
          ? BorderSide(color: enabled ? (borderColor ?? color.withValues(alpha: 0.5)) : AppColors.slate300)
          : BorderSide.none,
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: quiet ? Colors.white : (enabled ? color : color.withValues(alpha: 0.45)),
        shape: shape,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          customBorder: shape,
          child: SizedBox(
            height: height,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (busy)
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: ink))
                else if (icon != null)
                  Icon(icon, size: 17, color: enabled || !quiet ? ink : AppColors.slate400),
                if (busy || icon != null) const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: quiet && !enabled ? style.copyWith(color: AppColors.slate400) : style,
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

/// A whole-screen message for an empty list or a failed load, with an action.
class ScreenNotice extends StatelessWidget {
  const ScreenNotice({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 38, color: AppColors.outline),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: ExamText.heading),
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center, style: ExamText.body),
          if (action != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: 200,
              child: ExamButton(label: action!, quiet: true, onPressed: onAction),
            ),
          ],
        ],
      ),
    );
  }
}

/// A centred spinner.
class ExamSpinner extends StatelessWidget {
  const ExamSpinner({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.6)));
}

/// A big number over a small caps label, in a tinted tile.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.unit,
    this.icon,
    this.color = AppColors.primary,
  });

  final String value;
  final String? unit;
  final String label;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$value${unit == null ? '' : ' $unit'} $label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[Icon(icon, size: 19, color: color), const SizedBox(height: 8)],
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value, style: ExamText.statNumber.copyWith(color: color)),
                if (unit != null) ...[
                  const SizedBox(width: 4),
                  Text(unit!, style: AppText.plexSans(13, FontWeight.w600, AppColors.inkMuted)),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(label.toUpperCase(), style: ExamText.statLabel),
          ],
        ),
      ),
    );
  }
}

/// A circular percentage: an arc over a pale ring, the number in the middle.
class ScoreDial extends StatelessWidget {
  const ScoreDial({super.key, required this.percent, required this.color, this.size = 132, this.caption = 'SCORE'});

  final int percent;
  final Color color;
  final double size;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final value = percent.clamp(0, 100) / 100;
    return Semantics(
      label: 'Score $percent percent',
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: 1,
                strokeWidth: 9,
                color: AppColors.slate100,
                strokeCap: StrokeCap.round,
              ),
            ),
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(value: value, strokeWidth: 9, color: color, strokeCap: StrokeCap.round),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$percent',
                      style: AppText.workSans(size * 0.30, FontWeight.w800, color, lineHeight: size * 0.34),
                    ),
                    Text('%', style: AppText.workSans(size * 0.14, FontWeight.w800, color)),
                  ],
                ),
                Text(caption, style: ExamText.statLabel),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
