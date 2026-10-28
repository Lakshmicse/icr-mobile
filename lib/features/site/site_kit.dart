import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../account/widgets/account_kit.dart' show AccountBar;

/// The look of the small pages of the website that the app draws itself (the legal pages, blog posts, referrals,
/// advertising, the partner application): LinkedIn's — white on its light-grey canvas, hairlines, 90 % / 60 % black,
/// ICR blue for what can be pressed.
class SiteColors {
  SiteColors._();

  static const ink = Color(0xE6000000);
  static const secondary = Color(0x99000000);
  static const hairline = Color(0xFFE0DFDC);
  static const canvas = Color(0xFFF4F2EE);
  static const blueTint = Color(0xFFEDF3F8);
}

class SiteText {
  SiteText._();

  static final title = AppText.plexSans(22, FontWeight.w700, SiteColors.ink, lineHeight: 28);
  static final heading = AppText.plexSans(18, FontWeight.w600, SiteColors.ink, lineHeight: 24);
  static final subheading = AppText.plexSans(16, FontWeight.w600, SiteColors.ink, lineHeight: 22);
  static final body = AppText.plexSans(14, FontWeight.w400, SiteColors.ink, lineHeight: 20);
  static final secondary = AppText.plexSans(14, FontWeight.w400, SiteColors.secondary, lineHeight: 20);
  static final meta = AppText.plexSans(12, FontWeight.w400, SiteColors.secondary, lineHeight: 16);
  static final strong = AppText.plexSans(14, FontWeight.w600, SiteColors.ink, lineHeight: 20);
  static final link = AppText.plexSans(14, FontWeight.w600, AppColors.primary, lineHeight: 20);
  static final button = AppText.plexSans(14, FontWeight.w600, Colors.white, lineHeight: 20);
}

/// A page: the app's own title bar and back arrow over a body.
class SitePage extends StatelessWidget {
  const SitePage({super.key, required this.title, required this.child, this.onBack, this.canvas = false});

  final String title;
  final Widget child;
  final VoidCallback? onBack;

  /// LinkedIn's grey canvas behind white cards, for a page made of cards.
  final bool canvas;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: canvas ? SiteColors.canvas : Colors.white,
      appBar: AccountBar(title: title, onBack: onBack),
      body: SafeArea(top: false, child: child),
    );
  }
}

/// A white block on the canvas, edge to edge, with LinkedIn's hairlines.
class SiteCard extends StatelessWidget {
  const SiteCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border.symmetric(horizontal: BorderSide(color: SiteColors.hairline)),
      ),
      child: child,
    );
  }
}

/// A full-width button, the way LinkedIn draws one: a blue pill, or its outline.
class SiteButton extends StatelessWidget {
  const SiteButton({super.key, required this.label, required this.onPressed, this.busy = false, this.outlined = false});

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return OutlinedButton(
        onPressed: busy ? null : onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(44),
          side: const BorderSide(color: AppColors.primary),
          shape: const StadiumBorder(),
        ),
        child: Text(label, style: SiteText.link),
      );
    }
    return FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(44),
        backgroundColor: AppColors.primary,
        shape: const StadiumBorder(),
      ),
      child: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
            )
          : Text(label, style: SiteText.button),
    );
  }
}

/// What a page shows while it reads: the app's own white and a spinner, never a blank or dark frame.
class SiteLoading extends StatelessWidget {
  const SiteLoading({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)));
}

class SiteError extends StatelessWidget {
  const SiteError({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, style: SiteText.body, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            SizedBox(
              width: 160,
              child: SiteButton(label: 'Try again', onPressed: onRetry, outlined: true),
            ),
          ],
        ),
      ),
    );
  }
}
