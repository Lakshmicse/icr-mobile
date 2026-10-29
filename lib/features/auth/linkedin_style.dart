import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/auth/social_sign_in.dart';
import '../../core/theme/app_text.dart';

/// The look of LinkedIn's own sign-in page, in ICR's colours: a plain page with
/// no card, a big "Sign in" and one line under it, outlined fields whose label
/// floats up, "Show" inside the password field, one pill button, "or", full
/// width outlined buttons for the other ways in, and "New to … Join now" at the
/// foot. The sign-in screen is the only one built with it; the join screens keep
/// the card in `auth_widgets.dart`.
///
/// Light and dark follow the phone, as the rest of the sign-in screens do.
class LiColors {
  const LiColors._({
    required this.isDark,
    required this.page,
    required this.ink,
    required this.secondary,
    required this.hairline,
    required this.fieldBorder,
    required this.accent,
    required this.link,
    required this.error,
    required this.logo,
  });

  final bool isDark;
  final Color page;

  /// The title and what is typed.
  final Color ink;

  /// The line under the title, field labels, "or" and the outlined buttons.
  final Color secondary;
  final Color hairline;
  final Color fieldBorder;

  /// The pill button and a field's focus ring.
  final Color accent;

  /// Links on the page ("Forgot password?", "Show", "Join now"): the accent in
  /// light, a lighter tint of it in dark so it reads on the dark page.
  final Color link;
  final Color error;
  final String logo;

  static const light = LiColors._(
    isDark: false,
    page: Color(0xFFFFFFFF),
    ink: Color(0xFF191919),
    secondary: Color(0xFF666666),
    hairline: Color(0xFFE0E0E0),
    fieldBorder: Color(0xFF8C8C8C),
    accent: Color(0xFF32629E),
    link: Color(0xFF32629E),
    error: Color(0xFFCC1016),
    logo: 'assets/images/brand/icr-logo.png',
  );

  static const dark = LiColors._(
    isDark: true,
    page: Color(0xFF1B1F23),
    ink: Color(0xFFE9E9E9),
    secondary: Color(0xFFA9ACAF),
    hairline: Color(0xFF38434F),
    fieldBorder: Color(0xFF7D8186),
    accent: Color(0xFF32629E),
    link: Color(0xFF8DB4E5),
    error: Color(0xFFF87171),
    logo: 'assets/images/brand/icr-logo-white.png',
  );

  /// The colours for the phone's current light or dark setting.
  static LiColors of(BuildContext context) =>
      MediaQuery.platformBrightnessOf(context) == Brightness.dark ? dark : light;

  SystemUiOverlayStyle get overlay => SystemUiOverlayStyle(
    statusBarColor: page,
    statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: page,
    systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
  );
}

/// Type, in Work Sans like the rest of the auth screens, sized as LinkedIn's
/// sign-in page sets it: a 32 title, 16 for everything a person reads or types.
class LiType {
  LiType._();

  static TextStyle title(LiColors c) => AppText.workSans(32, FontWeight.w600, c.ink, lineHeight: 40);
  static TextStyle subtitle(LiColors c) => AppText.workSans(16, FontWeight.w400, c.secondary, lineHeight: 22);
  static TextStyle input(LiColors c) => AppText.workSans(17, FontWeight.w400, c.ink, lineHeight: 22);
  static TextStyle label(LiColors c) => AppText.workSans(16, FontWeight.w400, c.secondary, lineHeight: 20);
  static TextStyle link(LiColors c) => AppText.workSans(16, FontWeight.w600, c.link, lineHeight: 20);
  static TextStyle body(LiColors c) => AppText.workSans(16, FontWeight.w400, c.ink, lineHeight: 20);
  static TextStyle button(Color color) => AppText.workSans(17, FontWeight.w600, color, lineHeight: 22);
  static TextStyle small(LiColors c) => AppText.workSans(14, FontWeight.w400, c.secondary, lineHeight: 18);
}

/// The page: white, the ICR logo at the top left, [children] below it, and
/// [footer] pinned to the bottom of the screen (or just under the form when the
/// screen is short or the keyboard is up, where the page scrolls instead).
class LiScaffold extends StatelessWidget {
  const LiScaffold({super.key, required this.children, required this.footer});

  final List<Widget> children;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final c = LiColors.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: c.overlay,
      child: Scaffold(
        backgroundColor: c.page,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: CustomScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Image.asset(
                              c.logo,
                              height: 40,
                              semanticLabel: 'ICR — Institute for Corporate Real Estate',
                              filterQuality: FilterQuality.high,
                            ),
                          ),
                          const SizedBox(height: 28),
                          ...children,
                          const SizedBox(height: 24),
                          const Spacer(),
                          footer,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An outlined field with its label inside, which floats to the border once
/// there is something to say, as LinkedIn's do. [suffix] sits inside the right
/// end ("Show").
class LiTextField extends StatelessWidget {
  const LiTextField({
    super.key,
    required this.fieldKey,
    required this.label,
    required this.controller,
    this.focusNode,
    this.suffix,
    this.enabled = true,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.autocorrect = true,
    this.onFieldSubmitted,
    this.validator,
  });

  final Key fieldKey;
  final String label;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final Widget? suffix;
  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool autocorrect;
  final ValueChanged<String>? onFieldSubmitted;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    final c = LiColors.of(context);
    OutlineInputBorder border(Color color, double width) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: color, width: width));
    return TextFormField(
      key: fieldKey,
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      autocorrect: autocorrect,
      enableSuggestions: !obscureText && autocorrect,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      cursorColor: c.accent,
      style: LiType.input(c),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: LiType.label(c),
        floatingLabelStyle: WidgetStateTextStyle.resolveWith(
          (states) => LiType.label(c).copyWith(
            color: states.contains(WidgetState.error)
                ? c.error
                : states.contains(WidgetState.focused)
                ? c.link
                : c.secondary,
          ),
        ),
        errorStyle: AppText.workSans(13.5, FontWeight.w500, c.error, lineHeight: 18),
        errorMaxLines: 2,
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        enabledBorder: border(c.fieldBorder, 1),
        disabledBorder: border(c.hairline, 1),
        focusedBorder: border(c.accent, 2),
        errorBorder: border(c.error, 1.5),
        focusedErrorBorder: border(c.error, 2),
      ),
    );
  }
}

/// The text-only button inside the password field: "Show" / "Hide".
class LiShowButton extends StatelessWidget {
  const LiShowButton({super.key, required this.shown, required this.onPressed});

  final bool shown;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = LiColors.of(context);
    return Tooltip(
      message: shown ? 'Hide password' : 'Show password',
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: c.link,
          minimumSize: const Size(56, 48),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(shown ? 'Hide' : 'Show', style: LiType.link(c).copyWith(fontSize: 15)),
      ),
    );
  }
}

/// A link on the page: "Forgot password?", "Join now". The padding is the part of
/// the screen that answers a tap.
class LiLink extends StatelessWidget {
  const LiLink({super.key, required this.label, required this.onTap, this.padding});

  final String label;
  final VoidCallback onTap;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final c = LiColors.of(context);
    return Semantics(
      link: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: padding ?? const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
          child: Text(label, style: LiType.link(c)),
        ),
      ),
    );
  }
}

/// The one filled button: a pill in the accent, 52 dp tall, the width of the page.
class LiPrimaryButton extends StatelessWidget {
  const LiPrimaryButton({
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
    final c = LiColors.of(context);
    final style = LiType.button(Colors.white);
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: c.accent.withValues(alpha: 0.7),
          disabledForegroundColor: Colors.white,
          shape: const StadiumBorder(),
          textStyle: style,
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
                  Flexible(
                    child: Text(busyLabel, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
              )
            : Text(label, style: style),
      ),
    );
  }
}

/// "Continue with Google" / "Continue with LinkedIn": an outlined pill the width
/// of the page with the provider's mark at the left and the words centred. Drawn
/// faded when the server has no keys for it, as the website does; it still
/// answers a tap, to say so.
class LiSocialButton extends StatelessWidget {
  const LiSocialButton({
    super.key,
    required this.provider,
    required this.available,
    required this.busy,
    required this.onPressed,
  });

  final SocialProvider provider;
  final bool available;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = LiColors.of(context);
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: 'Continue with ${provider.label}',
      excludeSemantics: true,
      child: Opacity(
        opacity: available ? 1 : (c.isDark ? 0.6 : 0.5),
        child: SizedBox(
          height: 52,
          child: OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              shape: const StadiumBorder(),
              side: BorderSide(color: c.fieldBorder),
              foregroundColor: c.secondary,
              padding: const EdgeInsets.symmetric(horizontal: 18),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: busy
                      ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2, color: c.link))
                      : SvgPicture.asset(provider.icon, width: 22, height: 22),
                ),
                // Room either side for the mark, so the words stay centred.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 34),
                  child: Text(
                    'Continue with ${provider.label}',
                    style: LiType.button(c.isDark ? c.ink : c.secondary),
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
}

/// "—— or ——"
class LiOrDivider extends StatelessWidget {
  const LiOrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final c = LiColors.of(context);
    final line = Expanded(child: Divider(color: c.hairline, thickness: 1, height: 1));
    return SizedBox(
      height: 20,
      child: Row(
        children: [
          line,
          Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text('or', style: LiType.small(c))),
          line,
        ],
      ),
    );
  }
}
