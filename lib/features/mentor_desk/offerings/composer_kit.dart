import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../mentorship_my/widgets/forms.dart' show fieldDecoration;
import '../../mentorship_my/widgets/kit.dart';

/// The pieces the website's offering composers are built from (`composer/sections.tsx`, `GroupSessionComposer`,
/// `PlanFormFields`), drawn for a phone (owner, 14 Nov 2026: "implement these in the mentorship in the mobile app as
/// it is fields with the mobile supportive width and design"): numbered sections stacked full width with a hairline
/// between them instead of cards, labels with an "Optional" badge or a red star, the Free / Paid toggle, the hours
/// and minutes of a session, the cover image, the Published switch, and the full-screen page with its Save bar.

/// The longest and shortest session the API takes (`MAX_SESSION_MINUTES`, `MIN_SESSION_MINUTES`).
const kMinSessionMinutes = 15;
const kMaxSessionMinutes = 480;

class ComposerText {
  ComposerText._();

  static final pageTitle = AppText.workSans(18, FontWeight.w700, AppColors.onSurface, lineHeight: 24);
  static final lead = AppText.plexSans(13, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 18);
  static final sectionTitle = AppText.workSans(16, FontWeight.w700, AppColors.onSurface, lineHeight: 22);
  static final sectionHint = AppText.plexSans(12, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 16);
  static final step = AppText.plexSans(13, FontWeight.w700, AppColors.primary, lineHeight: 16);
  static final label = AppText.plexSans(14, FontWeight.w600, AppColors.onSurface, lineHeight: 20);
  static final help = AppText.plexSans(12, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 16);
  static final error = AppText.plexSans(12, FontWeight.w500, AppColors.error, lineHeight: 16);
  static final badge = AppText.plexSans(12, FontWeight.w600, AppColors.primary, lineHeight: 16);
  static final body = AppText.plexSans(14, FontWeight.w400, AppColors.onSurface, lineHeight: 20);
  static final bodyMuted = AppText.plexSans(14, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 20);
  static final toggle = AppText.plexSans(14, FontWeight.w600, AppColors.onSurfaceVariant, lineHeight: 18);
  static final toggleOn = AppText.plexSans(14, FontWeight.w600, AppColors.primary, lineHeight: 18);
  static final link = AppText.plexSans(13, FontWeight.w600, AppColors.primary, lineHeight: 18);
}

/// A full-screen composer: a bar with Back and the title, the lead under it, the sections, then a bar pinned to the
/// foot with what still blocks the save, Cancel and the save button (the website's sticky footer). [problem] is the
/// API's refusal, shown above the footer with what was typed kept.
class ComposerPage extends StatelessWidget {
  const ComposerPage({
    super.key,
    required this.title,
    required this.sections,
    required this.saveLabel,
    required this.onSave,
    this.lead,
    this.blocker,
    this.problem,
    this.busy = false,
    this.busyLabel = 'Saving…',
    this.secondaryLabel,
    this.onSecondary,
    this.onCancel,
    this.scrollController,
    this.footnote,
  });

  /// A line over the buttons that says what saving does (the group composer's "Publish opens registration right
  /// away."); a [blocker] takes its place while there is one. It never greys the save.
  final String? footnote;

  final String title;
  final String? lead;
  final List<Widget> sections;
  final String saveLabel;
  final String busyLabel;

  /// Null disables the save (while busy). A blocker does not: tapping it says what is missing.
  final VoidCallback? onSave;

  /// A second action beside the save (the group composer's Save as Draft).
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  final VoidCallback? onCancel;
  final String? blocker;
  final String? problem;
  final bool busy;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              height: 56,
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1))],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 6),
                  IconButton(
                    key: const ValueKey('composer-back'),
                    tooltip: 'Back',
                    onPressed: onCancel ?? () => Navigator.maybePop(context),
                    icon: const Icon(Symbols.arrow_back, size: 24, color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(title, style: ComposerText.pageTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 16),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                key: const ValueKey('composer-scroll'),
                controller: scrollController,
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  if (lead != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
                      child: Text(lead!, style: ComposerText.lead),
                    ),
                  ...sections,
                ],
              ),
            ),
            if (problem != null)
              Container(
                width: double.infinity,
                color: AppColors.errorContainer,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Text(
                  problem!,
                  key: const ValueKey('composer-problem'),
                  style: ComposerText.error.copyWith(color: AppColors.onErrorContainer),
                ),
              ),
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.outlineVariant)),
              ),
              padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (blocker != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(blocker!, key: const ValueKey('composer-blocker'), style: ComposerText.help),
                    )
                  else if (footnote != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(footnote!, key: const ValueKey('composer-footnote'), style: ComposerText.help),
                    ),
                  Row(
                    children: [
                      TextButton(
                        key: const ValueKey('composer-cancel'),
                        onPressed: busy ? null : (onCancel ?? () => Navigator.maybePop(context)),
                        child: Text('Cancel', style: ComposerText.link),
                      ),
                      const SizedBox(width: 8),
                      // A Wrap, right-aligned: a long pair ("Save 3 Drafts", "Publish 3 Sessions") puts the save
                      // on a second line instead of overflowing a narrow phone.
                      Expanded(
                        child: Wrap(
                          alignment: WrapAlignment.end,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (secondaryLabel != null)
                              OutlinedButton(
                                key: const ValueKey('composer-secondary'),
                                onPressed: busy ? null : onSecondary,
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 40),
                                  side: const BorderSide(color: AppColors.primary),
                                  shape: const StadiumBorder(),
                                ),
                                child: Text(secondaryLabel!, style: ComposerText.link),
                              ),
                            FilledButton(
                              key: const ValueKey('composer-save'),
                              onPressed: busy ? null : onSave,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 40),
                                backgroundColor: blocker == null ? AppColors.primary : AppColors.slate400,
                                shape: const StadiumBorder(),
                                padding: const EdgeInsets.symmetric(horizontal: 18),
                              ),
                              child: Text(
                                busy ? busyLabel : saveLabel,
                                style: MentoringText.button.copyWith(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

/// Opens a composer full screen, over the desk. Resolves true when it saved.
Future<bool> pushComposer(BuildContext context, WidgetBuilder builder) async {
  // A message from the last save ("Added.") would otherwise sit over this page's Save bar while it shows.
  ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
  final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: builder, fullscreenDialog: true));
  return saved == true;
}

/// One numbered section (the website's `FormSection`): the step in a tinted circle, the title and the line under
/// it, then the fields. Sections are separated by a hairline, never boxed.
class ComposerSection extends StatelessWidget {
  const ComposerSection({
    super.key,
    required this.step,
    required this.title,
    required this.children,
    this.subtitle,
    this.trailing,
    this.first = false,
  });

  final int step;
  final String title;
  final String? subtitle;
  final List<Widget> children;

  /// Beside the title (the syllabus's "3 of 24").
  final Widget? trailing;
  final bool first;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: first ? null : const Border(top: BorderSide(color: AppColors.outlineVariant)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: Color(0xFFE8EEF5), shape: BoxShape.circle),
                child: Text('$step', style: ComposerText.step),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: ComposerText.sectionTitle),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: ComposerText.sectionHint),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

/// "Optional", in a small tinted pill beside a label.
class OptionalBadge extends StatelessWidget {
  const OptionalBadge({super.key, this.text = 'Optional'});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
    decoration: BoxDecoration(color: const Color(0x1A1D63A3), borderRadius: BorderRadius.circular(999)),
    child: Text(text, style: ComposerText.badge),
  );
}

/// A field's label: the words, a red star when it is required, an Optional badge when it is not asked for,
/// and anything else at the end of the line (Manage in Settings).
class ComposerLabel extends StatelessWidget {
  const ComposerLabel(this.text, {super.key, this.optional = false, this.required = false, this.trailing});

  final String text;
  final bool optional;
  final bool required;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      // The label and its badge take what they need; a trailing link (Manage in Settings) has the rest, so the
      // label never wraps to leave room for it.
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text.rich(
                    TextSpan(
                      text: text,
                      children: [
                        if (required)
                          TextSpan(text: ' *', style: ComposerText.label.copyWith(color: AppColors.error)),
                      ],
                    ),
                    style: ComposerText.label,
                  ),
                ),
                if (optional) ...[const SizedBox(width: 8), const OptionalBadge()],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

/// A labelled field with its helper (or its problem, in red) under it, and the gap before the next one.
class ComposerField extends StatelessWidget {
  const ComposerField({
    super.key,
    required this.child,
    this.label,
    this.optional = false,
    this.required = false,
    this.help,
    this.error,
    this.trailing,
  });

  final String? label;
  final bool optional;
  final bool required;
  final Widget child;
  final String? help;

  /// Shown in place of [help] while there is one.
  final String? error;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final note = error ?? help;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (label != null) ComposerLabel(label!, optional: optional, required: required, trailing: trailing),
          child,
          if (note != null) ...[
            const SizedBox(height: 6),
            Text(note, style: error != null ? ComposerText.error : ComposerText.help),
          ],
        ],
      ),
    );
  }
}

/// The text box every composer field uses: the app's outlined field, a hint inside, a ₹ in front of a price.
InputDecoration composerDecoration(String hint, {bool rupee = false, bool error = false}) {
  final base = fieldDecoration(hint);
  return base.copyWith(
    hintStyle: ComposerText.bodyMuted.copyWith(color: AppColors.outline),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    prefixText: rupee ? '₹ ' : null,
    prefixStyle: ComposerText.body,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: error ? AppColors.error : AppColors.outlineVariant),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: error ? AppColors.error : AppColors.primary, width: 1.5),
    ),
  );
}

/// Two segments side by side (the website's ToggleButtonGroup): Free | Paid, or any two choices.
class ComposerToggle extends StatelessWidget {
  const ComposerToggle({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.keyPrefix = 'toggle',
    this.disabled = const {},
  });

  final List<String> options;
  final int selected;
  final ValueChanged<int> onChanged;
  final String keyPrefix;

  /// Options that cannot be chosen (the group composer's Paid while the storefront is closed, both once a seat is
  /// sold): drawn greyed, no tap.
  final Set<int> disabled;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < options.length; i++) ...[
              if (i > 0) Container(width: 1, height: 40, color: AppColors.outlineVariant),
              Semantics(
                button: true,
                selected: i == selected,
                enabled: !disabled.contains(i),
                child: InkWell(
                  key: ValueKey('$keyPrefix-${options[i].toLowerCase()}'),
                  onTap: disabled.contains(i) ? null : () => onChanged(i),
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    alignment: Alignment.center,
                    color: i == selected ? const Color(0xFFE8EEF5) : Colors.white,
                    child: Text(
                      options[i],
                      style: disabled.contains(i)
                          ? ComposerText.toggle.copyWith(color: AppColors.slate400)
                          : (i == selected ? ComposerText.toggleOn : ComposerText.toggle),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Free or Paid, and the line under Free.
class FreePaidToggle extends StatelessWidget {
  const FreePaidToggle({
    super.key,
    required this.paid,
    required this.onChanged,
    this.freeNote,
    this.keyPrefix = 'price',
    this.enabled = true,
    this.paidEnabled = true,
  });

  final bool paid;
  final ValueChanged<bool> onChanged;
  final String? freeNote;
  final String keyPrefix;

  /// False locks both (a price seats were sold at); [paidEnabled] false locks Paid alone (a closed storefront).
  final bool enabled;
  final bool paidEnabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ComposerToggle(
            keyPrefix: keyPrefix,
            options: const ['Free', 'Paid'],
            selected: paid ? 1 : 0,
            onChanged: (i) => onChanged(i == 1),
            disabled: {if (!enabled) ...[0, 1] else if (!paidEnabled && !paid) 1},
          ),
          if (!paid && freeNote != null) ...[
            const SizedBox(height: 10),
            Text(freeNote!, key: ValueKey('$keyPrefix-free-note'), style: ComposerText.bodyMuted),
          ],
        ],
      ),
    );
  }
}

/// A session length picked as hours and minutes (the website's `DurationSelect`): 0 to 8 hours, minutes in steps
/// of five, never outside 15 minutes to 8 hours. Callers deal in minutes.
class DurationPicker extends StatelessWidget {
  const DurationPicker({super.key, required this.minutes, required this.onChanged, this.keyPrefix = 'duration', this.enabled = true});

  final int minutes;
  final ValueChanged<int> onChanged;
  final String keyPrefix;
  final bool enabled;

  static int clamp(int m) => m.clamp(kMinSessionMinutes, kMaxSessionMinutes);

  @override
  Widget build(BuildContext context) {
    final total = clamp(minutes);
    final hours = total ~/ 60;
    final mins = total % 60;
    void pickHours(int h) {
      final m = h == 0 ? (mins < kMinSessionMinutes ? kMinSessionMinutes : mins) : (h * 60 >= kMaxSessionMinutes ? 0 : mins);
      onChanged(clamp(h * 60 + m));
    }

    void pickMinutes(int m) => onChanged(clamp(hours * 60 + m));
    return Row(
      children: [
        Expanded(
          child: _Select(
            key: ValueKey('$keyPrefix-hours'),
            label: 'Hours',
            value: hours,
            items: [for (var h = 0; h <= kMaxSessionMinutes ~/ 60; h++) h],
            text: (h) => '$h',
            enabledItem: (h) => !(h * 60 > kMaxSessionMinutes),
            onChanged: enabled ? pickHours : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Select(
            key: ValueKey('$keyPrefix-minutes'),
            label: 'Minutes',
            value: mins,
            items: [for (var m = 0; m < 60; m += 5) m],
            text: (m) => m.toString().padLeft(2, '0'),
            enabledItem: (m) {
              final t = hours * 60 + m;
              return t >= kMinSessionMinutes && t <= kMaxSessionMinutes;
            },
            onChanged: enabled ? pickMinutes : null,
          ),
        ),
      ],
    );
  }
}

class _Select extends StatelessWidget {
  const _Select({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.text,
    required this.enabledItem,
    required this.onChanged,
  });

  final String label;
  final int value;
  final List<int> items;
  final String Function(int) text;
  final bool Function(int) enabledItem;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      isDense: true,
      style: ComposerText.body,
      decoration: composerDecoration('').copyWith(labelText: label, labelStyle: ComposerText.help),
      items: [
        for (final i in items) DropdownMenuItem(value: i, enabled: enabledItem(i), child: Text(text(i))),
      ],
      onChanged: onChanged == null ? null : (v) => v == null ? null : onChanged!(v),
    );
  }
}

/// "Published" with its switch, and the sentence that says what it means either way.
class PublishedSwitch extends StatelessWidget {
  const PublishedSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onText,
    required this.offText,
    this.keyName = 'composer-published',
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String onText;
  final String offText;
  final String keyName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Switch.adaptive(key: ValueKey(keyName), value: value, onChanged: onChanged),
          const SizedBox(width: 8),
          Expanded(child: Text(value ? onText : offText, style: ComposerText.body)),
        ],
      ),
    );
  }
}

/// A switch with its words on one line (the group composer's Limit the Seats, Keep a Waitlist).
class LabelledSwitch extends StatelessWidget {
  const LabelledSwitch({super.key, required this.label, required this.value, required this.onChanged, this.keyName});

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? keyName;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ValueKey<String>, not the ValueKey<String?> a nullable field infers: keys compare by type too.
        Switch.adaptive(key: keyName == null ? null : ValueKey<String>(keyName!), value: value, onChanged: onChanged),
        const SizedBox(width: 6),
        Flexible(child: Text(label, style: ComposerText.body)),
      ],
    );
  }
}

/// The cover image: a square preview (a picture glyph until there is one), Upload Image / Replace Image, Remove,
/// and the helper under it. Uploading is the caller's ([onPick]); this only draws.
class CoverImageField extends StatelessWidget {
  const CoverImageField({
    super.key,
    required this.url,
    required this.onPick,
    this.onRemove,
    this.busy = false,
    this.problem,
    this.help = 'PNG, JPG or WEBP, up to 2 MB.',
    this.keyPrefix = 'offering-cover',
  });

  final String? url;
  final VoidCallback onPick;
  final VoidCallback? onRemove;
  final bool busy;
  final String? problem;
  final String help;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final src = AppConfig.absoluteUrl(url);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          key: ValueKey('$keyPrefix-preview'),
          width: 96,
          height: 64,
          decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(8)),
          clipBehavior: Clip.antiAlias,
          child: src == null
              ? const Icon(LucideIcons.image, size: 22, color: AppColors.outline)
              : Image.network(
                  src,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Icon(LucideIcons.image, size: 22, color: AppColors.outline),
                ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    key: ValueKey(keyPrefix),
                    onPressed: busy ? null : onPick,
                    icon: busy
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(LucideIcons.upload, size: 16, color: AppColors.primary),
                    label: Text(busy ? 'Uploading…' : (url == null ? 'Upload Image' : 'Replace Image'), style: ComposerText.link),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  if (url != null && onRemove != null && !busy)
                    TextButton(
                      key: ValueKey('$keyPrefix-remove'),
                      onPressed: onRemove,
                      child: Text('Remove', style: ComposerText.link.copyWith(color: AppColors.error)),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(problem ?? help, style: problem != null ? ComposerText.error : ComposerText.help),
            ],
          ),
        ),
      ],
    );
  }
}

/// A tinted note with an icon and a link at its end (the composer's Availability line).
class ComposerNote extends StatelessWidget {
  const ComposerNote({
    super.key,
    required this.icon,
    required this.text,
    this.action,
    this.onAction,
    this.actionBelow = false,
  });

  final IconData icon;

  /// May carry a bold lead-in: a [TextSpan] built by the caller.
  final InlineSpan text;
  final String? action;
  final VoidCallback? onAction;

  /// Puts the action under the text, at the end, instead of beside it: for a sentence too long to share a phone's
  /// width with a three-word link (the 1:1 composer's Availability line).
  final bool actionBelow;

  @override
  Widget build(BuildContext context) {
    final button = action == null
        ? null
        : TextButton(onPressed: onAction, child: Text(action!, style: ComposerText.link));
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.fromLTRB(14, 12, 10, actionBelow && button != null ? 2 : 12),
      decoration: BoxDecoration(color: const Color(0x0F1D63A3), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(child: Text.rich(text, style: ComposerText.body)),
              if (button != null && !actionBelow) ...[const SizedBox(width: 8), button],
            ],
          ),
          if (button != null && actionBelow) Align(alignment: Alignment.centerRight, child: button),
        ],
      ),
    );
  }
}
