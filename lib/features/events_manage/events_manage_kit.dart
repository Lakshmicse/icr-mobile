import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/detail_sheet.dart' show SheetHandle;
import '../workspaces/page_kit.dart' show WsButton;
import 'events_manage_rules.dart' show EventStanding;

/// The small parts the staff Events console's pages share. White pages, dark and light grey text, a hairline
/// between rows and never a box round one (the owner's rule); tinted pills carry a status or a filter.
class EmText {
  EmText._();

  static final rowTitle = AppText.plexSans(14, FontWeight.w600, AppColors.onSurface, lineHeight: 20);
  static final body = AppText.plexSans(14, FontWeight.w400, AppColors.onSurface, lineHeight: 20);
  static final secondary = AppText.plexSans(13, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 18);
  static final meta = AppText.plexSans(12, FontWeight.w400, AppColors.outline, lineHeight: 16);
  static final heading = AppText.plexSans(16, FontWeight.w600, AppColors.onSurface, lineHeight: 22);
  static final pageTitle = AppText.plexSans(18, FontWeight.w600, AppColors.onSurface, lineHeight: 24);
  static final label = AppText.plexSans(13, FontWeight.w400, AppColors.outline, lineHeight: 18);
  static final link = AppText.plexSans(14, FontWeight.w600, AppColors.primary, lineHeight: 20);
  static final danger = AppText.plexSans(14, FontWeight.w600, AppColors.error, lineHeight: 20);
  static final tab = AppText.plexSans(14, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 20);
  static final tabOn = AppText.plexSans(14, FontWeight.w600, AppColors.primary, lineHeight: 20);
  static final pill = AppText.plexSans(13, FontWeight.w600, AppColors.onSurfaceVariant, lineHeight: 18);
}

/// The hairline between rows.
class EmHairline extends StatelessWidget {
  const EmHairline({super.key, this.indent = 0});

  final double indent;

  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, thickness: 1, color: AppColors.outlineVariant, indent: indent);
}

/// A page's tabs: words with a line under the open one and a hairline under the row; they scroll sideways when
/// they do not fit.
class EmTabs extends StatefulWidget {
  const EmTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelect,
    this.keyPrefix = 'em-tab',
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;
  final String keyPrefix;

  @override
  State<EmTabs> createState() => _EmTabsState();
}

class _EmTabsState extends State<EmTabs> {
  final Map<int, GlobalKey> _keys = {};

  List<String> get labels => widget.labels;
  int get selected => widget.selected;
  ValueChanged<int> get onSelect => widget.onSelect;
  String get keyPrefix => widget.keyPrefix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Every tab is built, so one off the edge can still be scrolled to.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              for (final (i, label) in labels.indexed)
                Semantics(
                  button: true,
                  selected: i == selected,
                  child: InkWell(
                    key: ValueKey('$keyPrefix-$i'),
                    onTap: () {
                      onSelect(i);
                      // A tab half off the edge is brought into view as it opens.
                      final tab = (_keys[i] ??= GlobalKey()).currentContext;
                      if (tab != null) {
                        Scrollable.ensureVisible(tab, alignment: 0.5, duration: const Duration(milliseconds: 200));
                      }
                    },
                    child: Container(
                      key: _keys[i] ??= GlobalKey(),
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: i == selected ? AppColors.primary : Colors.transparent, width: 2),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(label, style: i == selected ? EmText.tabOn : EmText.tab),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const EmHairline(),
      ],
    );
  }
}

/// A row of filter pills, scrolling sideways when they do not fit.
class EmPillRow extends StatelessWidget {
  const EmPillRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          for (final (i, child) in children.indexed) ...[if (i > 0) const SizedBox(width: 8), child],
        ],
      ),
    );
  }
}

/// A filter pill: filled blue when it is the one on, a grey tint otherwise; a caret when it opens a list.
class EmPill extends StatelessWidget {
  const EmPill({super.key, required this.label, required this.on, required this.onTap, this.caret = false});

  final String label;
  final bool on;
  final VoidCallback onTap;
  final bool caret;

  @override
  Widget build(BuildContext context) {
    final ink = on ? Colors.white : AppColors.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: on,
      child: Material(
        color: on ? AppColors.primary : AppColors.surfaceContainer,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Container(
            height: 32,
            padding: EdgeInsets.only(left: 14, right: caret ? 8 : 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: EmText.pill.copyWith(color: ink)),
                if (caret) Icon(Icons.expand_more, size: 18, color: ink),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The tones a status is drawn in.
enum EmTone { good, info, warn, bad, muted }

Color _dot(EmTone tone) => switch (tone) {
  EmTone.good => const Color(0xFF16A34A),
  EmTone.info => AppColors.primary,
  EmTone.warn => const Color(0xFFD97706),
  EmTone.bad => const Color(0xFFDC2626),
  EmTone.muted => AppColors.slate400,
};

/// An event's one status: live in green, hidden or ended in grey.
EmTone standingTone(EventStanding s) => s == EventStanding.published ? EmTone.good : EmTone.muted;

/// One status as a dot and a word (the website's list rows).
class EmStatus extends StatelessWidget {
  const EmStatus({super.key, required this.label, required this.tone});

  final String label;
  final EmTone tone;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: _dot(tone), shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: EmText.secondary.copyWith(color: AppColors.onSurface)),
      ],
    );
  }
}

/// A label and its value, one row of a details list.
class EmDetail extends StatelessWidget {
  const EmDetail({super.key, required this.label, this.value, this.child});

  final String label;
  final String? value;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 116, child: Text(label, style: EmText.label)),
              const SizedBox(width: 12),
              Expanded(child: child ?? Text(value ?? '—', style: EmText.body)),
            ],
          ),
        ),
        const EmHairline(),
      ],
    );
  }
}

/// A list's heading inside a tab ("Packages"), with one action at its end.
class EmHeading extends StatelessWidget {
  const EmHeading({super.key, required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(child: Text(title, style: EmText.heading)),
          ?action,
        ],
      ),
    );
  }
}

/// A tinted note: something to know (blue), something that went through (green), or something to mind (amber).
class EmNote extends StatelessWidget {
  const EmNote({super.key, required this.text, this.title, this.tone = EmTone.info, this.onClose});

  final String text;
  final String? title;
  final EmTone tone;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final (fill, ink, icon) = switch (tone) {
      EmTone.good => (const Color(0xFFE6F6EE), const Color(0xFF128A52), Icons.check_circle_outline),
      EmTone.warn => (AppColors.amber50, AppColors.amber800, Icons.info_outline),
      EmTone.bad => (const Color(0xFFFFF1F2), AppColors.error, Icons.error_outline),
      _ => (const Color(0xFFE8F0F9), AppColors.primary, Icons.info_outline),
    };
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 18, color: ink),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null) Text(title!, style: EmText.rowTitle),
                  Text(text, style: EmText.secondary.copyWith(color: AppColors.onSurface)),
                ],
              ),
            ),
          ),
          if (onClose != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Semantics(
                button: true,
                label: 'Dismiss',
                child: InkResponse(
                  onTap: onClose,
                  radius: 18,
                  child: SizedBox(width: 20, height: 20, child: Icon(Icons.close, size: 18, color: ink)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Nothing to list: a title, a sentence and, when something can be done about it, one button.
class EmEmpty extends StatelessWidget {
  const EmEmpty({super.key, required this.title, this.body, this.action, this.onAction});

  final String title;
  final String? body;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: EmText.rowTitle),
          if (body != null) ...[const SizedBox(height: 4), Text(body!, style: EmText.secondary)],
          if (action != null) ...[const SizedBox(height: 12), WsButton(label: action!, onPressed: onAction)],
        ],
      ),
    );
  }
}

/// A read still on its way.
class EmLoading extends StatelessWidget {
  const EmLoading({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 48),
    child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4))),
  );
}

/// A read that failed: the API's own sentence and "Try Again".
class EmError extends StatelessWidget {
  const EmError({super.key, required this.message, required this.onRetry, this.title = 'Unable to Load This Page'});

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => EmEmpty(title: title, body: message, action: 'Try Again', onAction: onRetry);
}

/// "Show More" under a list that has further pages.
class EmMore extends StatelessWidget {
  const EmMore({super.key, required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: busy ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Center(
          child: busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text('Show More', style: EmText.link),
        ),
      ),
    );
  }
}

/// The search box of a console list: a grey field with no frame, searching as it is typed.
class EmSearch extends StatelessWidget {
  const EmSearch({super.key, required this.controller, required this.hint, required this.onChanged, this.fieldKey});

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => TextField(
        key: fieldKey,
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: EmText.body,
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: AppColors.surfaceContainer,
          hintText: hint,
          hintStyle: EmText.body.copyWith(color: AppColors.outline),
          hintMaxLines: 1,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.outline),
          prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          suffixIcon: value.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear Search',
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                  icon: const Icon(Icons.close, size: 18, color: AppColors.outline),
                ),
          suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        ),
      ),
    );
  }
}

/// [text] with the typed words emphasised wherever they appear (the website's `Highlight`).
TextSpan highlighted(String text, String query, TextStyle style) {
  final q = query.trim();
  final at = q.isEmpty ? -1 : text.toLowerCase().indexOf(q.toLowerCase());
  if (at < 0) return TextSpan(text: text, style: style);
  return TextSpan(
    style: style,
    children: [
      TextSpan(text: text.substring(0, at)),
      TextSpan(
        text: text.substring(at, at + q.length),
        style: const TextStyle(backgroundColor: AppColors.amber100),
      ),
      TextSpan(text: text.substring(at + q.length)),
    ],
  );
}

/// The frame of a sheet that shows a record and offers a decision on it: a title, what there is to read, the
/// API's refusal if one came back, and the buttons at the foot. Opened with `showEditSheet`, over everything.
class EmSheet extends StatelessWidget {
  const EmSheet({
    super.key,
    required this.title,
    required this.children,
    this.kicker,
    this.error,
    this.actions = const [],
  });

  final String title;

  /// A small line over the title ("Request to host events").
  final String? kicker;
  final List<Widget> children;
  final String? error;

  /// The foot's buttons, the main one last.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Material(
          color: Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetHandle(height: 24, top: 10, rule: false),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 2, 8, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (kicker != null) Text(kicker!, style: EmText.meta),
                          Text(title, style: EmText.pageTitle),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: AppColors.outline),
                    ),
                  ],
                ),
              ),
              const EmHairline(),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
                ),
              ),
              if (error != null)
                Container(
                  key: const Key('sheet.error'),
                  margin: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(10)),
                  child: Text(error!, style: EmText.secondary.copyWith(color: AppColors.error)),
                ),
              if (actions.isNotEmpty) ...[
                const EmHairline(),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8, children: actions),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
