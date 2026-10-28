import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The colours of the sign-in screens in light and in dark, measured from the
/// two designs (`docs/designs/sign-in-light.png`, `sign-in-dark.png`).
///
/// The screens follow the phone's own setting, so a phone in dark mode opens on
/// the dark card. The rest of the app is light for now.
class AuthPalette {
  const AuthPalette({
    required this.isDark,
    required this.page,
    required this.card,
    required this.cardBorder,
    required this.title,
    required this.text,
    required this.muted,
    required this.rule,
    required this.fieldFill,
    required this.fieldBorder,
    required this.fieldIcon,
    required this.eye,
    required this.accent,
    required this.checkboxBorder,
    required this.orText,
    required this.error,
    required this.logo,
  });

  final bool isDark;

  /// Behind the card.
  final Color page;
  final Color card;
  final Color cardBorder;

  /// "Sign in".
  final Color title;

  /// Field labels and what is typed in a field.
  final Color text;

  /// "Remember me", "New to ICR?", hints.
  final Color muted;

  /// The hairline either side of "OR".
  final Color rule;
  final Color fieldFill;
  final Color fieldBorder;
  final Color fieldIcon;

  /// The show/hide-password glyph.
  final Color eye;

  /// Links, the primary button and a field's focus ring.
  final Color accent;
  final Color checkboxBorder;
  final Color orText;
  final Color error;

  /// The ICR logo that reads on the card.
  final String logo;

  static const light = AuthPalette(
    isDark: false,
    page: Color(0xFFF4F2EE),
    card: Color(0xFFFFFFFF),
    cardBorder: Color(0xFFE2E8F0),
    title: Color(0xFF0F2A4A),
    text: Color(0xFF334155),
    muted: Color(0xFF64748B),
    rule: Color(0xFFE2E8F0),
    fieldFill: Color(0xFFF6F8FB),
    fieldBorder: Color(0xFFBDBFC1),
    fieldIcon: Color(0xFF989A9C),
    eye: Color(0xFF717273),
    accent: Color(0xFF32629E),
    checkboxBorder: Color(0xFF778599),
    orText: Color(0xFF9E9E9E),
    error: Color(0xFFBA1A1A),
    logo: 'assets/images/brand/icr-logo.png',
  );

  static const dark = AuthPalette(
    isDark: true,
    page: Color(0xFF0B1120),
    card: Color(0xFF111827),
    cardBorder: Color(0xFF29303D),
    title: Color(0xFFF1F5F9),
    text: Color(0xFFF1F5F9),
    muted: Color(0xFF94A3B8),
    rule: Color(0xFF29303D),
    fieldFill: Color(0xFF111827),
    fieldBorder: Color(0xFF484D59),
    fieldIcon: Color(0xFF888C93),
    eye: Color(0xFFFFFFFF),
    accent: Color(0xFF32629E),
    checkboxBorder: Color(0xFF8492A6),
    orText: Color(0xFF888C93),
    error: Color(0xFFF87171),
    logo: 'assets/images/brand/icr-logo-white.png',
  );

  /// The palette for the phone's current light or dark setting.
  static AuthPalette of(BuildContext context) =>
      MediaQuery.platformBrightnessOf(context) == Brightness.dark ? dark : light;

  /// Status and navigation bars that sit on [page].
  SystemUiOverlayStyle get overlay => SystemUiOverlayStyle(
    statusBarColor: page,
    statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: page,
    systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
  );
}
