import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/title_bar.dart';
import '../mentoring_models.dart';

/// Colours the mentoring screens add to the palette (the Mentor Profile's mint
/// pill, star and navy band, kept here so this folder stands on its own).
class MentoringColors {
  MentoringColors._();

  static const mint = Color(0xFF9DF4C8);
  static const mintInk = Color(0xFF0B3B27);
  static const green = Color(0xFF128A52);
  static const star = Color(0xFFF49400);
  static const navyDeep = Color(0xFF0F1B30);
  static const navyMid = Color(0xFF073258);
}

/// Type for the mentoring screens the designs do not draw: the Mentor
/// Profile's faces (Work Sans headings, IBM Plex Sans Medium text) at the
/// sizes a working screen needs, one step above the designs' 10 dp copy.
class MentoringText {
  MentoringText._();

  static final hero = AppText.workSans(16, FontWeight.w700, AppColors.onSurface, lineHeight: 21);
  static final section = AppText.workSans(13, FontWeight.w700, AppColors.onSurface, lineHeight: 18);
  static final cardTitle = AppText.workSans(12.5, FontWeight.w700, AppColors.onSurface, lineHeight: 17);
  static final name = AppText.workSans(12.5, FontWeight.w600, AppColors.onSurface, lineHeight: 17);
  static final body = AppText.plexSans(11.5, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 17);
  static final bodyStrong = AppText.plexSans(11.5, FontWeight.w600, AppColors.onSurface, lineHeight: 17);
  static final meta = AppText.plexSans(10.5, FontWeight.w500, AppColors.outline, lineHeight: 15);
  static final pill = AppText.plexSans(9.5, FontWeight.w700, AppColors.onSurfaceVariant, lineHeight: 12, spacing: 0.2);
  static final button = AppText.plexSans(11.5, FontWeight.w600, Colors.white, lineHeight: 16);
  static final buttonQuiet = AppText.plexSans(11.5, FontWeight.w600, AppColors.primary, lineHeight: 16);
  static final tab = AppText.plexSans(11, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 14);
  static final tabSelected = AppText.plexSans(11, FontWeight.w600, Colors.white, lineHeight: 14);
  static final statValue = AppText.workSans(17, FontWeight.w700, AppColors.onSurface, lineHeight: 21);
  static final statLabel = AppText.plexSans(10, FontWeight.w600, AppColors.outline, lineHeight: 13);
  static final quote = AppText.plexSans(
    11.5,
    FontWeight.w500,
    AppColors.onSurfaceVariant,
    lineHeight: 16,
  ).copyWith(fontStyle: FontStyle.italic);
  static final error = AppText.plexSans(11.5, FontWeight.w500, AppColors.error, lineHeight: 16);

  // Forms.
  static final formTitle = AppText.workSans(14, FontWeight.w700, AppColors.slate900, lineHeight: 20);
  static final formLabel = AppText.plexSans(11, FontWeight.w600, AppColors.onSurface, lineHeight: 16);
  static final formHelp = AppText.plexSans(11, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 16);
  static final formInput = AppText.plexSans(14, FontWeight.w400, AppColors.onSurface, lineHeight: 20);

  // The navy band.
  static final planKicker = AppText.plexSans(8, FontWeight.w700, const Color(0xFFDCE6F2), lineHeight: 10, spacing: 0.6);
  static final planTitle = AppText.workSans(13, FontWeight.w700, Colors.white, lineHeight: 18);
  static final planLine = AppText.plexSans(10, FontWeight.w400, Colors.white, lineHeight: 14);
  static final planButton = AppText.workSans(10.5, FontWeight.w700, AppColors.primary, lineHeight: 14);
}

/// A bundled or uploaded picture filling its box; [fallback] when there is none.
class Photo extends StatelessWidget {
  const Photo({super.key, required this.picture, this.fallback, this.fit = BoxFit.cover});

  final FeedPicture? picture;
  final Widget? fallback;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final blank = fallback ?? const ColoredBox(color: AppColors.surfaceContainer);
    final asset = picture?.asset;
    final url = picture?.url;
    if (asset != null) return SizedBox.expand(child: Image.asset(asset, fit: fit));
    if (url != null) {
      return SizedBox.expand(
        child: CachedNetworkImage(
          imageUrl: url,
          fit: fit,
          errorWidget: (_, _, _) => blank,
          placeholder: (_, _) => blank,
        ),
      );
    }
    return SizedBox.expand(child: blank);
  }
}

/// Two letters on a soft tile, for a person with no photo.
class InitialsTile extends StatelessWidget {
  const InitialsTile({super.key, required this.name, this.style});

  final String name;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final initials = parts.isEmpty ? '?' : '${parts.first[0]}${parts.length > 1 ? parts.last[0] : ''}'.toUpperCase();
    return ColoredBox(
      color: AppColors.surfaceContainer,
      child: Center(
        child: Text(initials, style: style ?? TextStyle(fontSize: 18, color: AppColors.outline.withValues(alpha: 0.9))),
      ),
    );
  }
}

/// A section screen of the mentoring flow: the title bar (back, title, bell)
/// over [body], with an optional bar pinned at the foot.
class MentoringPage extends StatelessWidget {
  const MentoringPage({
    super.key,
    required this.title,
    required this.body,
    required this.onBell,
    this.onBack,
    this.unread = 0,
    this.bottomBar,
  });

  final String title;
  final Widget body;
  final VoidCallback? onBack;
  final VoidCallback onBell;
  final int unread;
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.white),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          bottom: bottomBar == null,
          child: Column(
            children: [
              TitleBar(title: title, onBack: onBack, unread: unread, onBell: onBell),
              Expanded(child: body),
              ?bottomBar,
            ],
          ),
        ),
      ),
    );
  }
}

/// Loading, failed-with-Retry or the content, inside a pull-to-refresh list.
class LoadedList extends StatelessWidget {
  const LoadedList({
    super.key,
    required this.loading,
    required this.error,
    required this.onRefresh,
    required this.children,
    this.errorTitle = "Couldn't load this",
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 28),
  });

  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;
  final List<Widget> children;
  final String errorTitle;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final Widget content;
    if (loading && children.isEmpty) {
      content = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(
            height: 360,
            child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4))),
          ),
        ],
      );
    } else if (error != null && children.isEmpty) {
      content = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          EmptyNote(
            icon: LucideIcons.cloudOff,
            title: errorTitle,
            body: error!,
            action: 'Try again',
            onAction: onRefresh,
          ),
        ],
      );
    } else {
      content = ListView(physics: const AlwaysScrollableScrollPhysics(), padding: padding, children: children);
    }
    return RefreshIndicator(color: AppColors.primary, onRefresh: onRefresh, child: content);
  }
}

/// A centred icon, title, sentence and optional button: an empty list or a failure.
class EmptyNote extends StatelessWidget {
  const EmptyNote({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: compact ? const EdgeInsets.fromLTRB(16, 20, 16, 20) : const EdgeInsets.fromLTRB(32, 48, 32, 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 28 : 36, color: AppColors.outline),
          const SizedBox(height: 10),
          Text(title, textAlign: TextAlign.center, style: MentoringText.section),
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center, style: MentoringText.body),
          if (action != null) ...[const SizedBox(height: 14), QuietButton(label: action!, onPressed: onAction)],
        ],
      ),
    );
  }
}

/// The white card of these screens: a hairline edge, 10 dp corners.
class MentoringCard extends StatelessWidget {
  const MentoringCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(14)});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: const BorderSide(color: AppColors.cardRule),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// "Sessions ........ Book a session": a heading with an optional action.
class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title, this.action, this.onAction, this.top = 18});

  final String title;
  final String? action;
  final VoidCallback? onAction;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(title, style: MentoringText.section)),
          if (action != null)
            Semantics(
              button: true,
              child: InkWell(
                onTap: onAction,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Text(action!, style: MentoringText.buttonQuiet),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

enum PillTone { mint, blue, amber, grey, red }

/// A small status word in a tinted pill ("Active", "Awaiting reply").
class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key, this.tone = PillTone.grey});

  final String label;
  final PillTone tone;

  @override
  Widget build(BuildContext context) {
    final (fill, ink) = switch (tone) {
      PillTone.mint => (MentoringColors.mint, MentoringColors.mintInk),
      PillTone.blue => (const Color(0xFFE7EEFF), AppColors.primary),
      PillTone.amber => (AppColors.amber100, AppColors.amber800),
      PillTone.grey => (AppColors.surfaceContainer, AppColors.onSurfaceVariant),
      PillTone.red => (AppColors.errorContainer, AppColors.onErrorContainer),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: MentoringText.pill.copyWith(color: ink)),
    );
  }
}

/// A round photo, or the person's initials.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({super.key, required this.person, this.size = 40});

  final Person person;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: Photo(
          picture: person.photo,
          fallback: InitialsTile(
            name: person.name,
            style: AppText.workSans(size * 0.36, FontWeight.w600, AppColors.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

/// A person on one line: photo, name, a line under it, and something at the end.
class PersonRow extends StatelessWidget {
  const PersonRow({super.key, required this.person, this.subline, this.trailing, this.size = 40});

  final Person person;
  final String? subline;
  final Widget? trailing;
  final double size;

  @override
  Widget build(BuildContext context) {
    final line = subline ?? person.subline;
    return Row(
      children: [
        PersonAvatar(person: person, size: size),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(person.name, style: MentoringText.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              if (line != null && line.isNotEmpty)
                Text(line, style: MentoringText.meta, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}

/// A glyph and a short fact ("Sat 24 Oct, 7:00 PM").
class MetaLine extends StatelessWidget {
  const MetaLine({super.key, required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 13, color: color ?? AppColors.outline),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: MentoringText.meta.copyWith(color: color ?? AppColors.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}

/// The blue button of these screens, 36 dp, 8 dp corners.
class SolidButton extends StatelessWidget {
  const SolidButton({super.key, required this.label, required this.onPressed, this.icon, this.busy = false});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return Semantics(
      button: true,
      enabled: enabled,
      child: Material(
        color: enabled ? AppColors.primary : AppColors.primary.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 36,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (busy)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  else if (icon != null)
                    Icon(icon, size: 15, color: Colors.white),
                  if (busy || icon != null) const SizedBox(width: 7),
                  Text(label, style: MentoringText.button),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The white outlined button beside it ("Message", "Withdraw").
class QuietButton extends StatelessWidget {
  const QuietButton({super.key, required this.label, required this.onPressed, this.icon, this.danger = false});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final ink = danger ? AppColors.error : AppColors.primary;
    final enabled = onPressed != null;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(color: AppColors.outlineVariant),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      child: Material(
        color: Colors.white,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onPressed,
          child: SizedBox(
            height: 36,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 15, color: enabled ? ink : AppColors.outline),
                    const SizedBox(width: 6),
                  ],
                  Text(label, style: MentoringText.buttonQuiet.copyWith(color: enabled ? ink : AppColors.outline)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Buttons in a row that wraps on a narrow phone.
class ActionWrap extends StatelessWidget {
  const ActionWrap({super.key, required this.children, this.top = 12});

  final List<Widget> children;
  final double top;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: top),
      child: Wrap(spacing: 8, runSpacing: 8, children: children),
    );
  }
}

/// The tab strip of the Mentor Profile (a bordered band with the open tab on a
/// blue pill), scrolling sideways when the labels outgrow the phone and
/// bringing the open tab into view.
class SegmentTabs extends StatefulWidget {
  const SegmentTabs({super.key, required this.labels, required this.selected, required this.onSelect, this.badges});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  /// A count beside a label ("Requests 2"); zero or missing draws none.
  final List<int>? badges;

  @override
  State<SegmentTabs> createState() => _SegmentTabsState();
}

class _SegmentTabsState extends State<SegmentTabs> {
  final _keys = <int, GlobalKey>{};

  GlobalKey _key(int i) => _keys.putIfAbsent(i, GlobalKey.new);

  @override
  void initState() {
    super.initState();
    _reveal();
  }

  @override
  void didUpdateWidget(SegmentTabs old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected || old.labels.length != widget.labels.length) _reveal();
  }

  void _reveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keys[widget.selected]?.currentContext;
      if (ctx != null && mounted) {
        Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 200), alignment: 0.5);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final labels = widget.labels;
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++) ...[if (i > 0) const SizedBox(width: 3), _tab(i, labels[i])],
          ],
        ),
      ),
    );
  }

  Widget _tab(int i, String label) {
    final on = i == widget.selected;
    final badge = widget.badges != null && i < widget.badges!.length ? widget.badges![i] : 0;
    return Semantics(
      key: _key(i),
      button: true,
      selected: on,
      child: Material(
        color: on ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => widget.onSelect(i),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11),
            child: Row(
              children: [
                Text(label, style: on ? MentoringText.tabSelected : MentoringText.tab),
                if (badge > 0) ...[
                  const SizedBox(width: 5),
                  Container(
                    constraints: const BoxConstraints(minWidth: 16),
                    height: 16,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: on ? Colors.white : AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$badge',
                      style: MentoringText.pill.copyWith(color: on ? AppColors.primary : Colors.white),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A number over a caption, for a strip of totals.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: MentoringText.statValue),
            const SizedBox(height: 2),
            Text(label, style: MentoringText.statLabel, maxLines: 2),
          ],
        ),
      ),
    );
  }
}

/// A tinted band that says what is waiting, with its own buttons.
class Callout extends StatelessWidget {
  const Callout({super.key, required this.text, this.tone = PillTone.blue, this.actions = const []});

  final String text;
  final PillTone tone;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final fill = switch (tone) {
      PillTone.mint => AppColors.emerald50,
      PillTone.amber => AppColors.amber50,
      PillTone.red => const Color(0xFFFEF2F2),
      PillTone.grey => AppColors.slate50,
      PillTone.blue => const Color(0xFFF0F5FC),
    };
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: MentoringText.body.copyWith(color: AppColors.onSurface)),
          if (actions.isNotEmpty) ActionWrap(top: 8, children: actions),
        ],
      ),
    );
  }
}
