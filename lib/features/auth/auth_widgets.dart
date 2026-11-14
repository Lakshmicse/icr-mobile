import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/auth/social_sign_in.dart';
import '../../core/theme/app_text.dart';
import 'auth_palette.dart';

/// The pieces the sign-in and join screens share, built to the Sign in designs
/// (`docs/designs/sign-in-light.png`, `sign-in-dark.png`): a card on a plain
/// page, a label above each field, icons inside the fields, one accent blue.
/// Every colour comes from [AuthPalette], so light and dark are one layout.

/// Type, sized by the width of the designs' text (their face is a little
/// narrower than Work Sans) and set in Work Sans throughout.
class AuthType {
  AuthType._();

  static TextStyle title(AuthPalette p) => AppText.workSans(29.4, FontWeight.w700, p.title, lineHeight: 36);
  static TextStyle label(AuthPalette p) => AppText.workSans(15.2, FontWeight.w700, p.text, lineHeight: 18);
  static TextStyle input(AuthPalette p) => AppText.workSans(19, FontWeight.w400, p.text, lineHeight: 23);
  static TextStyle hint(AuthPalette p) =>
      AppText.workSans(19, FontWeight.w400, p.muted.withValues(alpha: 0.7), lineHeight: 23);
  static TextStyle link(AuthPalette p) => AppText.workSans(14.5, FontWeight.w600, p.accent, lineHeight: 18);
  static TextStyle body(AuthPalette p) => AppText.workSans(16.5, FontWeight.w400, p.muted, lineHeight: 20);
  static TextStyle bodyLink(AuthPalette p) => AppText.workSans(16.8, FontWeight.w700, p.accent, lineHeight: 20);
  static TextStyle small(AuthPalette p) => AppText.workSans(13.5, FontWeight.w400, p.muted, lineHeight: 18);
  static TextStyle button = AppText.workSans(17.9, FontWeight.w700, Colors.white, lineHeight: 22);
}

/// The page and the card on it. Scrolls when the card is taller than the
/// screen (a small phone, or the keyboard up), and sits in the middle when it
/// is not.
///
/// [flat] draws no page colour around the card: the page takes the card's own
/// colour (white in light), edge to edge, so the form sits on one plain
/// background. The password recovery screens use it (the client's note on the
/// manual, 13 Nov 2026: "Background to be fully white").
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.child, this.flat = false});

  final Widget child;
  final bool flat;

  /// The width inside the card on this screen: the screen less the safe area
  /// and the page's 15 dp either side, at most 440, less the card's 25 dp.
  static double contentWidth(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);
    final page = MediaQuery.sizeOf(context).width - safe.left - safe.right - 2 * 15;
    return (page < 440 ? page : 440) - 2 * 25;
  }

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    final page = flat ? p.card : p.page;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: p.overlay.copyWith(statusBarColor: page, systemNavigationBarColor: page),
      child: Scaffold(
        backgroundColor: page,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(15, 8, 15, 8),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight - 16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(18)),
                      child: Padding(padding: const EdgeInsets.fromLTRB(25, 30, 25, 24), child: child),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The card's top line: the screen's name on the left, the ICR logo on the right.
class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return Row(
      children: [
        Expanded(child: Text(title, style: AuthType.title(p), maxLines: 2)),
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

/// A label above a rounded field, with an icon inside at the left and, when
/// given, a [trailing] widget (the show/hide eye) at the right. [headerTrailing]
/// sits opposite the label ("Change Email").
class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.label,
    required this.controller,
    this.fieldKey,
    this.focusNode,
    this.icon,
    this.hint,
    this.trailing,
    this.headerTrailing,
    this.enabled = true,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.autocorrect = true,
    this.maxLength,
    this.letterSpacing,
    this.validator,
    this.onFieldSubmitted,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final Key? fieldKey;
  final FocusNode? focusNode;
  final IconData? icon;
  final String? hint;
  final Widget? trailing;
  final Widget? headerTrailing;
  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final bool autocorrect;
  final int? maxLength;
  final double? letterSpacing;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
    final fieldStyle = AuthType.input(p).copyWith(letterSpacing: letterSpacing);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Every label row is at least as tall as a link's tap area, so "Email" and
        // "Password" sit the same distance above their fields; a label that wraps
        // beside its link ("Email Verification Code" · "Change Email") takes more.
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 34),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: Text(label, style: AuthType.label(p))),
              ?headerTrailing,
            ],
          ),
        ),
        SizedBox(height: headerTrailing == null ? 2.5 : 3.5),
        TextFormField(
          key: fieldKey,
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          autofillHints: autofillHints,
          autocorrect: autocorrect,
          enableSuggestions: !obscureText,
          maxLength: maxLength,
          style: fieldStyle,
          cursorColor: p.accent,
          validator: validator,
          onFieldSubmitted: onFieldSubmitted,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AuthType.hint(p),
            counterText: '',
            filled: true,
            fillColor: p.fieldFill,
            isDense: false,
            contentPadding: EdgeInsets.fromLTRB(icon == null ? 20 : 0, 18, 14, 18),
            prefixIcon: icon == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(left: 18, right: 10),
                    child: Icon(icon, size: 25, color: p.fieldIcon),
                  ),
            prefixIconConstraints: const BoxConstraints(),
            suffixIcon: trailing,
            suffixIconConstraints: const BoxConstraints(),
            enabledBorder: border(p.fieldBorder),
            disabledBorder: border(p.fieldBorder.withValues(alpha: 0.5)),
            focusedBorder: border(p.accent, 2),
            errorBorder: border(p.error),
            focusedErrorBorder: border(p.error, 2),
            errorStyle: AuthType.small(p).copyWith(color: p.error, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

/// The show/hide glyph at the right end of the password field.
class AuthEyeButton extends StatelessWidget {
  const AuthEyeButton({super.key, required this.shown, required this.onPressed});

  final bool shown;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return IconButton(
      tooltip: shown ? 'Hide Password' : 'Show Password',
      onPressed: onPressed,
      iconSize: 26,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      icon: Icon(shown ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: p.eye),
    );
  }
}

/// A refusal under the form, read out when it appears.
class AuthErrorLine extends StatelessWidget {
  const AuthErrorLine({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(Icons.error_outline_rounded, size: 19, color: p.error),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AuthType.small(p).copyWith(color: p.error, fontWeight: FontWeight.w500, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// A link on the card screens: "Change Email", "Resend Link".
class AuthLink extends StatelessWidget {
  const AuthLink({super.key, required this.label, required this.onTap, this.style, this.padding});

  final String label;
  final VoidCallback onTap;
  final TextStyle? style;

  /// Around the words, which is also how much of the screen answers a tap.
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return Semantics(
      link: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: padding ?? const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
          child: Text(label, style: style ?? AuthType.link(p)),
        ),
      ),
    );
  }
}

/// The full-width accent button: "Join", "Agree & Join".
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.busyLabel,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final String busyLabel;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return SizedBox(
      height: 54,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: p.accent.withValues(alpha: 0.7),
          disabledForegroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: AuthType.button,
        ),
        child: busy
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  // Flexible: "Sending your code…" must not overflow a 320 dp phone.
                  Flexible(
                    child: Text(busyLabel, style: AuthType.button, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
              )
            : Text(label, style: AuthType.button),
      ),
    );
  }
}

/// The accent-outlined button beside the primary one ("Send code").
class AuthOutlinedButton extends StatelessWidget {
  const AuthOutlinedButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: p.accent,
          side: BorderSide(color: p.accent, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: AuthType.button,
        ),
        child: Text(label, style: AuthType.button.copyWith(color: p.accent, fontSize: 18)),
      ),
    );
  }
}

/// The colours a [SocialPillButton] draws with, from whichever palette its
/// screen uses: the card screens' [AuthPalette] (through [SocialPillStyle.of])
/// or the sign-in page's `LiColors`.
class SocialPillStyle {
  const SocialPillStyle({required this.border, required this.text, required this.spinner, required this.isDark});

  /// The card screens' colours.
  SocialPillStyle.of(AuthPalette p) : this(border: p.fieldBorder, text: p.text, spinner: p.accent, isDark: p.isDark);

  final Color border;
  final Color text;
  final Color spinner;
  final bool isDark;
}

/// "Sign In Using" / "Sign Up Using" over the providers side by side, each a
/// [SocialPillButton] keyed `<keyPrefix>.<provider>` (owner, 12 Nov 2026: the
/// marks moved under the form, headed, with larger logos). On a page too narrow
/// for two pills with their names (under 280 dp: a 320 dp phone) they stack.
/// Only the providers the server offers are drawn; with none, nothing is.
///
/// The choice is made from [width], the page's content width, not with a
/// `LayoutBuilder`: the sign-in page measures its column's intrinsic height
/// (`SliverFillRemaining`), which a `LayoutBuilder` cannot answer.
class SocialProvidersBlock extends StatelessWidget {
  const SocialProvidersBlock({
    super.key,
    required this.heading,
    required this.headingStyle,
    required this.keyPrefix,
    required this.style,
    required this.width,
    required this.available,
    required this.busy,
    required this.enabled,
    required this.onPressed,
    this.above = const [],
  });

  final String heading;
  final TextStyle headingStyle;
  final String keyPrefix;
  final SocialPillStyle style;

  /// What separates the block from the form over it (the gap and the hairline): drawn only with the block.
  final List<Widget> above;

  /// The width the block is laid out in: `LiScaffold.contentWidth` on the
  /// sign-in page, [AuthScaffold.contentWidth] on the card.
  final double width;

  /// The providers this server has keys for.
  final Set<SocialProvider> available;

  /// The provider whose round trip is running, if any.
  final SocialProvider? busy;
  final bool enabled;
  final ValueChanged<SocialProvider> onPressed;

  /// Narrower than this, the pills go one under the other.
  static const sideBySideMinWidth = 280.0;
  static const gap = 12.0;

  @override
  Widget build(BuildContext context) {
    // Only what this server offers (owner, 13 Nov 2026): a provider with no keys here is not drawn, and with
    // none the whole block goes, its hairline with it. They come back by themselves once the server has keys.
    final pills = [
      for (final provider in SocialProvider.values)
        if (available.contains(provider))
          SocialPillButton(
            key: Key('$keyPrefix.${provider.name}'),
            provider: provider,
            style: style,
            available: true,
            busy: busy == provider,
            onPressed: enabled ? () => onPressed(provider) : null,
          ),
    ];
    if (pills.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...above,
        Text(heading, key: Key('$keyPrefix.using'), style: headingStyle),
        const SizedBox(height: 12),
        if (width < sideBySideMinWidth)
          for (final (i, pill) in pills.indexed) ...[if (i > 0) const SizedBox(height: 10), pill]
        else
          Row(
            children: [
              for (final (i, pill) in pills.indexed) ...[if (i > 0) const SizedBox(width: gap), Expanded(child: pill)],
            ],
          ),
      ],
    );
  }
}

/// One provider as an outlined pill: its mark, 28 dp, and its name. Drawn faded
/// when this server has no keys for it, as the website does; it still answers a
/// tap, to say so. The spinner takes the mark's place while its round trip runs.
class SocialPillButton extends StatelessWidget {
  const SocialPillButton({
    super.key,
    required this.provider,
    required this.style,
    required this.available,
    required this.busy,
    required this.onPressed,
  });

  final SocialProvider provider;
  final SocialPillStyle style;
  final bool available;
  final bool busy;
  final VoidCallback? onPressed;

  static const markSize = 28.0;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onPressed != null,
    label: 'Continue with ${provider.label}',
    excludeSemantics: true,
    child: Opacity(
      opacity: available ? 1 : (style.isDark ? 0.6 : 0.5),
      child: SizedBox(
        height: 52,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            shape: const StadiumBorder(),
            side: BorderSide(color: style.border),
            foregroundColor: style.text,
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: markSize,
                height: markSize,
                child: busy
                    ? Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.2, color: style.spinner),
                        ),
                      )
                    : SvgPicture.asset(provider.icon, width: markSize, height: markSize),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  provider.label,
                  style: AppText.workSans(16, FontWeight.w600, style.text, lineHeight: 20),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// "Remember Me": a 19 dp box with a 2 dp outline, filled with the accent when on.
class AuthCheckbox extends StatelessWidget {
  const AuthCheckbox({super.key, required this.value, required this.onChanged, required this.label});

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return Semantics(
      checked: value,
      enabled: onChanged != null,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 40,
          child: Row(
            children: [
              const SizedBox(width: 7),
              AnimatedContainer(
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
              const SizedBox(width: 16),
              Text(label, style: AppText.workSans(16.7, FontWeight.w400, p.muted, lineHeight: 20)),
            ],
          ),
        ),
      ),
    );
  }
}
