import 'package:flutter/material.dart';

import '../../core/theme/app_text.dart';
import '../../core/util/links.dart';
import 'auth_palette.dart';
import 'auth_widgets.dart';
import 'signup_rules.dart';

/// The sign-up screens' own pieces, in the Sign in card's language: every
/// colour from [AuthPalette], Work Sans throughout, 12 dp radii, 1 dp borders.

/// "STEP 1 OF 3" over the screen's name, the logo opposite (the website's
/// `RegisterForm` heading).
class SignupHeader extends StatelessWidget {
  const SignupHeader({super.key, required this.step, required this.title});

  final int step;
  final String title;

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'STEP $step OF 3',
                key: const Key('signup.step'),
                style: AppText.workSans(12, FontWeight.w600, p.muted, lineHeight: 16, spacing: 0.7),
              ),
              const SizedBox(height: 4),
              Semantics(header: true, child: Text(title, style: AuthType.title(p))),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Image.asset(
          p.logo,
          height: 43.7,
          semanticLabel: 'ICR — Institute for Corporate Real Estate',
          filterQuality: FilterQuality.high,
        ),
      ],
    );
  }
}

/// A grey line under a field: the field's problem in the error colour, or its
/// helper.
class AuthHelperLine extends StatelessWidget {
  const AuthHelperLine({super.key, this.error, this.helper});

  final String? error;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    final text = error ?? helper;
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 2),
      child: Text(
        text,
        style: AuthType.small(
          p,
        ).copyWith(color: error != null ? p.error : p.muted, fontWeight: error != null ? FontWeight.w500 : null),
      ),
    );
  }
}

/// The code a non-production API handed back instead of sending it, shown
/// where it is typed, as the website's `DevCodeNote`: "Test mode: your code is
/// 123456." and "Use code", which fills the field. Draws nothing without a code.
class DevCodeNote extends StatelessWidget {
  const DevCodeNote({super.key, required this.code, required this.onUse});

  final String? code;
  final ValueChanged<String> onUse;

  static const _warning = Color(0xFFB45309);
  static const _warningDark = Color(0xFFFBBF24);

  @override
  Widget build(BuildContext context) {
    final value = code;
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    final p = AuthPalette.of(context);
    final ink = p.isDark ? _warningDark : _warning;
    final style = AuthType.small(p).copyWith(color: ink);
    return Padding(
      key: const Key('signup.devCode'),
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Flexible(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Test mode: your code is '),
                  TextSpan(
                    text: value,
                    style: style.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.6),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
              style: style,
            ),
          ),
          const SizedBox(width: 6),
          AuthLink(
            key: const Key('signup.useCode'),
            label: 'Use code',
            style: AuthType.link(p).copyWith(fontSize: 14),
            onTap: () => onUse(value),
          ),
        ],
      ),
    );
  }
}

/// The advisory password meter (the website's `PasswordStrength`): four
/// segments, the bucket's name, "A guide, not a gate", and the four rules
/// ticked as they are met. Only eight characters blocks the button.
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({super.key, required this.value});

  final String value;

  static Color colorFor(PasswordStrengthLevel level, AuthPalette p) => switch (level) {
    PasswordStrengthLevel.weak => p.error,
    PasswordStrengthLevel.fair => p.isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
    PasswordStrengthLevel.good => p.isDark ? const Color(0xFF60A5FA) : const Color(0xFF0284C7),
    PasswordStrengthLevel.strong => p.isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
  };

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    final p = AuthPalette.of(context);
    final score = passwordScore(value);
    final color = colorFor(score.level, p);
    final ok = colorFor(PasswordStrengthLevel.strong, p);
    return Padding(
      key: const Key('signup.strength'),
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (var i = 0; i < passwordRules.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 4,
                    decoration: BoxDecoration(
                      color: i < score.passed ? color : p.rule,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Semantics(
                liveRegion: true,
                label: 'Password strength: ${score.label}',
                excludeSemantics: true,
                child: Text(score.label, style: AppText.workSans(13, FontWeight.w600, color, lineHeight: 17)),
              ),
              const Spacer(),
              Flexible(
                flex: 6,
                child: Text(
                  'A guide, not a gate — only 8 characters are required.',
                  textAlign: TextAlign.right,
                  style: AuthType.small(p).copyWith(fontSize: 13, height: 15 / 11.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              for (final rule in passwordRules)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      rule.test(value) ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      size: 14,
                      color: rule.test(value) ? ok : p.muted.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      rule.label,
                      style: AuthType.small(p).copyWith(fontSize: 13, color: rule.test(value) ? ok : p.muted),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "I'm working | Between roles": two halves of one outlined box, the chosen
/// one filled with the accent.
class AuthSegmented<T> extends StatelessWidget {
  const AuthSegmented({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.semanticLabel,
  });

  final T value;
  final List<(T, String)> options;
  final ValueChanged<T>? onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return Semantics(
      label: semanticLabel,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: p.fieldFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.fieldBorder),
        ),
        padding: const EdgeInsets.all(3),
        child: Row(
          children: [
            for (final (option, label) in options)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: option == value,
                  child: Material(
                    color: option == value ? p.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    child: InkWell(
                      key: Key('signup.segment.$option'),
                      borderRadius: BorderRadius.circular(9),
                      onTap: onChanged == null ? null : () => onChanged!(option),
                      child: Center(
                        child: Text(
                          label,
                          style: AppText.workSans(
                            15,
                            FontWeight.w600,
                            option == value ? Colors.white : p.text,
                            lineHeight: 19,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A checkbox whose words may wrap and hold links: the consent line, "Ask to
/// join", "Let recruiters know". The box is the sign-in card's 19 dp box.
class AuthCheckLine extends StatelessWidget {
  const AuthCheckLine({super.key, required this.value, required this.onChanged, required this.child, this.label});

  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget child;

  /// What a screen reader says for the box.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          checked: value,
          enabled: onChanged != null,
          label: label,
          child: InkResponse(
            onTap: onChanged == null ? null : () => onChanged!(!value),
            radius: 22,
            child: SizedBox(
              width: 34,
              height: 34,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 19,
                  height: 19,
                  decoration: BoxDecoration(
                    color: value ? p.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(3.5),
                    border: Border.all(color: value ? p.accent : p.checkboxBorder, width: 2),
                  ),
                  child: value ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onChanged == null ? null : () => onChanged!(!value),
            child: Padding(padding: const EdgeInsets.only(top: 7), child: child),
          ),
        ),
      ],
    );
  }
}

/// "I agree to ICR's Terms of Service and Privacy Policy." — the two names
/// open the website's pages.
class TermsSentence extends StatelessWidget {
  const TermsSentence({super.key, this.lead = 'I agree to ICR’s', this.center = false});

  final String lead;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    final linkStyle = AuthType.link(p).copyWith(fontSize: 14);
    Widget link(String label, String path) => GestureDetector(
      key: Key('signup.legal$path'),
      onTap: () => openSitePage(context, path),
      child: Text(label, style: linkStyle),
    );
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$lead '),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: link('Terms of Service', '/terms'),
          ),
          const TextSpan(text: ' and '),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: link('Privacy Policy', '/privacy'),
          ),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: center ? TextAlign.center : TextAlign.start,
      style: AuthType.small(p),
    );
  }
}

/// A field that opens a list to choose from ("Year you started", "Where you
/// are based"), drawn like [AuthField]: a label, then a rounded box with the
/// choice or a hint, and a chevron.
class AuthPickerField extends StatelessWidget {
  const AuthPickerField({
    super.key,
    required this.label,
    required this.hint,
    required this.value,
    required this.onTap,
    this.icon,
    this.error,
    this.onClear,
  });

  final String label;
  final String hint;
  final String? value;
  final VoidCallback? onTap;
  final IconData? icon;
  final String? error;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    final borderColor = error != null ? p.error : p.fieldBorder;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 34,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(label, style: AuthType.label(p)),
          ),
        ),
        const SizedBox(height: 2.5),
        Semantics(
          button: true,
          label: value == null ? '$label, $hint' : '$label, $value',
          excludeSemantics: true,
          child: Material(
            color: p.fieldFill,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: borderColor),
            ),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 59,
                child: Row(
                  children: [
                    SizedBox(width: icon == null ? 20 : 18),
                    if (icon != null) ...[Icon(icon, size: 25, color: p.fieldIcon), const SizedBox(width: 10)],
                    Expanded(
                      child: Text(
                        value ?? hint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: value == null ? AuthType.hint(p) : AuthType.input(p),
                      ),
                    ),
                    if (value != null && onClear != null)
                      IconButton(
                        tooltip: 'Clear',
                        onPressed: onClear,
                        icon: Icon(Icons.close_rounded, size: 20, color: p.eye),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: Icon(Icons.expand_more_rounded, size: 24, color: p.fieldIcon),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        AuthHelperLine(error: error),
      ],
    );
  }
}

/// A list to choose one from, in a sheet over the card, with a search box when
/// it is long. Returns the chosen item, or null when closed.
Future<T?> showAuthPicker<T>(
  BuildContext context, {
  required String title,
  required List<T> items,
  required String Function(T) labelOf,
  String Function(T)? subtitleOf,
  bool searchable = false,
  String searchHint = 'Search',
}) {
  final p = AuthPalette.of(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: p.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    builder: (context) => _PickerSheet<T>(
      palette: p,
      title: title,
      items: items,
      labelOf: labelOf,
      subtitleOf: subtitleOf,
      searchable: searchable,
      searchHint: searchHint,
    ),
  );
}

class _PickerSheet<T> extends StatefulWidget {
  const _PickerSheet({
    required this.palette,
    required this.title,
    required this.items,
    required this.labelOf,
    required this.subtitleOf,
    required this.searchable,
    required this.searchHint,
  });

  final AuthPalette palette;
  final String title;
  final List<T> items;
  final String Function(T) labelOf;
  final String Function(T)? subtitleOf;
  final bool searchable;
  final String searchHint;

  @override
  State<_PickerSheet<T>> createState() => _PickerSheetState<T>();
}

class _PickerSheetState<T> extends State<_PickerSheet<T>> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final q = _query.trim().toLowerCase();
    final shown = q.isEmpty
        ? widget.items
        : widget.items.where((i) {
            final sub = widget.subtitleOf?.call(i) ?? '';
            return widget.labelOf(i).toLowerCase().contains(q) || sub.toLowerCase().contains(q);
          }).toList();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.72,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: p.rule, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: Text(widget.title, style: AppText.workSans(18, FontWeight.w700, p.title, lineHeight: 24)),
          ),
          if (widget.searchable)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                key: const Key('picker.search'),
                autofocus: false,
                onChanged: (v) => setState(() => _query = v),
                style: AuthType.input(p).copyWith(fontSize: 16),
                cursorColor: p.accent,
                decoration: InputDecoration(
                  hintText: widget.searchHint,
                  hintStyle: AuthType.hint(p).copyWith(fontSize: 16),
                  prefixIcon: Icon(Icons.search_rounded, color: p.fieldIcon),
                  filled: true,
                  fillColor: p.fieldFill,
                  isDense: true,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: p.fieldBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: p.accent, width: 2),
                  ),
                ),
              ),
            ),
          Expanded(
            child: shown.isEmpty
                ? Center(child: Text('Nothing matches “$_query”.', style: AuthType.small(p)))
                : ListView.builder(
                    itemCount: shown.length,
                    itemBuilder: (context, i) {
                      final item = shown[i];
                      final sub = widget.subtitleOf?.call(item);
                      return ListTile(
                        title: Text(widget.labelOf(item), style: AuthType.input(p).copyWith(fontSize: 16)),
                        subtitle: sub == null || sub.isEmpty ? null : Text(sub, style: AuthType.small(p)),
                        onTap: () => Navigator.of(context).pop(item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Suggestions under a field as it is typed (job titles, ICR's companies),
/// drawn in the card itself rather than floating, so they scroll with it.
class AuthSuggestions<T> extends StatelessWidget {
  const AuthSuggestions({
    super.key,
    required this.items,
    required this.labelOf,
    required this.onPick,
    this.subtitleOf,
    this.max = 6,
  });

  final List<T> items;
  final String Function(T) labelOf;
  final String? Function(T)? subtitleOf;
  final ValueChanged<T> onPick;
  final int max;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final p = AuthPalette.of(context);
    final shown = items.take(max).toList();
    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.fieldBorder.withValues(alpha: 0.8)),
      ),
      child: Column(
        children: [
          for (final (i, item) in shown.indexed) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: p.rule),
            InkWell(
              onTap: () => onPick(item),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            labelOf(item),
                            style: AuthType.input(p).copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          if (subtitleOf?.call(item) case final sub? when sub.isNotEmpty)
                            Text(sub, style: AuthType.small(p).copyWith(fontSize: 13)),
                        ],
                      ),
                    ),
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

/// A notice on the card: the success-tinted "Continuing with Google as …", or
/// the amber one a partly-saved step leaves.
class AuthNotice extends StatelessWidget {
  const AuthNotice({super.key, required this.child, this.warning = false});

  final Widget child;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    final (fill, border) = warning
        ? (p.isDark ? const Color(0x33F59E0B) : const Color(0xFFFFF7E6), const Color(0xFFF59E0B))
        : (p.isDark ? const Color(0x2610B981) : const Color(0xFFECFDF5), const Color(0xFF34D399));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border.withValues(alpha: 0.7)),
      ),
      child: DefaultTextStyle.merge(
        style: AuthType.small(p).copyWith(color: p.text, fontSize: 14),
        child: child,
      ),
    );
  }
}
