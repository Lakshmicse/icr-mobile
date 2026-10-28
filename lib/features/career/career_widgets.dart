import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/title_bar.dart';
import 'career_styles.dart';

/// The frame every career screen shares: the title bar over a body that scrolls
/// under it (the body brings its own pull-to-refresh).
class CareerScaffold extends StatelessWidget {
  const CareerScaffold({
    super.key,
    required this.title,
    required this.body,
    required this.onBell,
    this.onBack,
    this.unread = 0,
    this.bottomBar,
    this.actions,
  });

  final String title;
  final Widget body;
  final VoidCallback onBell;

  /// The arrow at the top left; the route pops when null.
  final VoidCallback? onBack;
  final int unread;

  /// Pinned under the body (a primary action).
  final Widget? bottomBar;

  /// Beside the bell: a glyph button for the screen's own action.
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    // The pinned action is the Scaffold's own bottom bar, so a message (a snack bar) rises above it
    // instead of covering the button the member has to press next.
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: bottomBar,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            TitleBar(title: title, onBack: onBack, unread: unread, onBell: onBell, middle: _middle()),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  Widget? _middle() {
    final a = actions;
    if (a == null || a.isEmpty) return null;
    return Row(mainAxisAlignment: MainAxisAlignment.end, children: a);
  }
}

/// A centred spinner for a screen with nothing to show yet.
class CareerLoading extends StatelessWidget {
  const CareerLoading({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 56),
    child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4))),
  );
}

/// An empty or failed state: an icon, a title, a line, and one action.
class CareerNotice extends StatelessWidget {
  const CareerNotice({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    this.onAction,
    this.secondary,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;
  final String? secondary;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 44, 28, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 34, color: AppColors.outline),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: AppText.postTitle.copyWith(fontSize: 16, height: 1.3)),
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center, style: CareerText.body),
          if (action != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.outlineVariant),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(action!, style: CareerText.link),
            ),
          ],
          if (secondary != null)
            TextButton(
              onPressed: onSecondary,
              child: Text(secondary!, style: CareerText.link),
            ),
        ],
      ),
    );
  }
}

/// The colours a status pill can wear.
enum PillTone {
  neutral(AppColors.surfaceContainer, AppColors.onSurfaceVariant),
  brand(AppColors.chipEmphasis, AppColors.primary),
  success(AppColors.successTint, AppColors.successInk),
  warning(AppColors.amber100, AppColors.amber800),
  danger(AppColors.errorContainer, AppColors.onErrorContainer);

  const PillTone(this.fill, this.ink);
  final Color fill;
  final Color ink;
}

/// A small rounded status word ("Interviewing", "88% match").
class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key, this.tone = PillTone.neutral, this.icon});

  final String label;
  final PillTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: tone.fill, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 11, color: tone.ink), const SizedBox(width: 4)],
          Text(label, style: CareerText.pill.copyWith(color: tone.ink, fontSize: 12)),
        ],
      ),
    );
  }
}

/// A month over a day number on a tinted square: when something happens.
class DateBlock extends StatelessWidget {
  const DateBlock({super.key, required this.month, required this.day, this.size = 44});

  final String month;
  final String day;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: AppColors.chipEmphasis, borderRadius: BorderRadius.circular(8)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(month, style: AppText.plexSans(9, FontWeight.w600, AppColors.primary, lineHeight: 11, spacing: 0.5)),
          Text(day, style: AppText.workSans(17, FontWeight.w800, AppColors.slate900, lineHeight: 20)),
        ],
      ),
    );
  }
}

/// A tinted strip with a glyph and a line: what an application is waiting on.
class NoteStrip extends StatelessWidget {
  const NoteStrip({super.key, required this.icon, required this.color, required this.child, this.actions = const []});

  final IconData icon;
  final Color color;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 8),
          Expanded(child: child),
          for (final a in actions) ...[const SizedBox(width: 6), a],
        ],
      ),
    );
  }
}

/// The small pill button on a strip ("Join call", "Accept").
class StripButton extends StatelessWidget {
  const StripButton({super.key, required this.label, required this.onTap, this.filled = false, this.icon});

  final String label;
  final VoidCallback? onTap;
  final bool filled;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : AppColors.primary;
    return Material(
      color: filled ? AppColors.primary : Colors.white,
      shape: StadiumBorder(side: BorderSide(color: filled ? AppColors.primary : AppColors.outlineVariant)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 4)],
              Text(label, style: CareerText.link.copyWith(color: fg, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The bar of a long list's tail: "View More", or the spinner while it loads.
class ViewMoreRow extends StatelessWidget {
  const ViewMoreRow({super.key, required this.loading, required this.onTap});

  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: loading
          ? const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          : TextButton(
              key: const ValueKey('view-more'),
              onPressed: onTap,
              child: Text('View More', style: CareerText.link),
            ),
    );
  }
}

/// A row of tabs as chips with their counts, scrolling sideways.
class CountTabs<T extends Enum> extends StatelessWidget {
  const CountTabs({
    super.key,
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelect,
    this.count,
    this.keyPrefix = 'tab',
  });

  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onSelect;
  final int Function(T)? count;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 5),
        itemBuilder: (context, i) {
          final v = values[i];
          final on = v == selected;
          final n = count?.call(v);
          final text = n == null || n < 0 ? label(v) : '${label(v)} $n';
          return Semantics(
            button: true,
            selected: on,
            child: Material(
              color: on ? AppColors.primary : Colors.white,
              shape: StadiumBorder(side: BorderSide(color: on ? AppColors.primary : AppColors.outlineVariant)),
              child: InkWell(
                key: ValueKey('$keyPrefix-${v.name}'),
                customBorder: const StadiumBorder(),
                onTap: () => onSelect(v),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  child: Center(
                    child: Text(text, style: CareerText.tabLabel.copyWith(color: on ? Colors.white : null)),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A tappable white card with a hairline border.
class TapCard extends StatelessWidget {
  const TapCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(12)});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// A refusal under a form, in red.
class FormProblem extends StatelessWidget {
  const FormProblem(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(LucideIcons.circleAlert, size: 14, color: AppColors.error),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            message,
            key: const ValueKey('form-problem'),
            style: CareerText.body.copyWith(color: AppColors.error),
          ),
        ),
      ],
    ),
  );
}
