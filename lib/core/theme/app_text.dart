import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The app's one typeface and one size scale (owner's call, 27 Oct 2026: the text was too small and did not
/// match from screen to screen — the Figma exports had some 70 different sizes, 230 of the styles under
/// 10.5 sp). Everything is Roboto, as Home, the bar and Android's own apps are, on LinkedIn's steps:
/// 12 · 13 · 14 · 16 · 18 · 22 sp and up, nothing under 12. A style still names the size its design drew
/// (`plexSans(10.5, …)`); [sp] snaps it to the step it belongs to, so a screen can be built from a design's
/// numbers and still read at the app's sizes.
class AppText {
  AppText._();

  /// The one family. `work` and `plex` are the names the Figma styles used (Work Sans, IBM Plex Sans).
  static const roboto = 'Roboto';
  static const work = roboto;
  static const plex = roboto;

  /// A design's size on the app's scale: 12 for anything under 11.5, then 13, 14, 16 (14.25–16.25), 18, 22,
  /// and display sizes as drawn.
  static double sp(double size) {
    if (size < 11.5) return 12;
    if (size < 12.75) return 13;
    if (size < 14.25) return 14;
    if (size < 16.25) return 16;
    if (size < 19) return 18;
    if (size < 23) return 22;
    return size;
  }

  static TextStyle _style(double size, FontWeight weight, Color color, double? lineHeight, double? spacing) {
    final fitted = sp(size);
    // A design's line height was set for its own size: keep the proportion, between a tight 1.2 and an airy 1.4.
    final ratio = lineHeight == null ? null : (lineHeight / size).clamp(1.2, 1.4).toDouble();
    return TextStyle(
      fontFamily: roboto,
      fontSize: fitted,
      fontWeight: weight,
      color: color,
      height: ratio,
      // Roboto keeps its own tracking: the designs' negative tracking was tuned to Plex and Work Sans, and
      // Material's positive tracking is not wanted; uppercase labels keep a little.
      letterSpacing: (spacing ?? 0).clamp(0, 0.5).toDouble(),
      leadingDistribution: TextLeadingDistribution.even,
    );
  }

  /// Body and label text at a size, weight and colour; `lineHeight` in dp (see [sp]).
  static TextStyle plexSans(double size, FontWeight weight, Color color, {double? lineHeight, double? spacing}) =>
      _style(size, weight, color, lineHeight, spacing);

  /// Names and headings at a size, weight and colour; `lineHeight` in dp (see [sp]).
  static TextStyle workSans(double size, FontWeight weight, Color color, {double? lineHeight, double? spacing}) =>
      _style(size, weight, color, lineHeight, spacing);

  // Header (.srch, .pill, .chip)
  static final searchHint = plexSans(14, FontWeight.w600, AppColors.outline, lineHeight: 20);
  static final searchInput = plexSans(14, FontWeight.w500, AppColors.onSurface, lineHeight: 20);
  static final composer = plexSans(13, FontWeight.w500, AppColors.onSurface);
  static final chip = plexSans(10, FontWeight.w600, AppColors.onSurfaceVariant, lineHeight: 16, spacing: 0.24);
  static final chipLarge = plexSans(12, FontWeight.w600, AppColors.onSurfaceVariant, lineHeight: 16, spacing: 0.24);

  // Post (.nm, .fol, .role, .tm, .t2, .bd, .tags, .stat)
  static final authorName = workSans(12, FontWeight.w600, AppColors.onSurface, lineHeight: 16);
  static final follow = plexSans(10, FontWeight.w600, AppColors.primary, lineHeight: 16);
  static final authorHeadline = plexSans(8, FontWeight.w600, AppColors.outline, lineHeight: 15, spacing: 0.24);
  static final postMeta = plexSans(8, FontWeight.w500, AppColors.outline, lineHeight: 15, spacing: 0.275);
  static final topicTag = plexSans(8, FontWeight.w600, AppColors.tertiary, lineHeight: 15, spacing: 0.275);
  static final postTitle = workSans(12, FontWeight.w700, AppColors.onSurface, lineHeight: 18);
  static final postBody = plexSans(10, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 18);
  static final tag = plexSans(8, FontWeight.w700, AppColors.primary);
  static final reactionCount = plexSans(12, FontWeight.w500, AppColors.onSurfaceVariant);
  static final engagement = plexSans(12, FontWeight.w500, AppColors.outline);
  static final imageCaption = plexSans(12, FontWeight.w600, AppColors.onImage, lineHeight: 16, spacing: 0.24);
  static final morePhotos = workSans(12, FontWeight.w700, AppColors.onImage, lineHeight: 20);

  // Replies (.bub .n/.s/p/.f, the thread pill and the reply box)
  static final replyName = plexSans(12, FontWeight.w600, AppColors.onSurface);
  static final replyMeta = plexSans(8, FontWeight.w500, AppColors.outline);
  static final replyBody = plexSans(10, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 15);
  static final replyAction = plexSans(8, FontWeight.w500, AppColors.outline);
  static final moreReplies = plexSans(8, FontWeight.w600, AppColors.onSurfaceVariant);
  static final replyHint = plexSans(10, FontWeight.w600, AppColors.outline, spacing: 0.24);
  static final replyInput = plexSans(10, FontWeight.w500, AppColors.onSurface, spacing: 0.24);

  // Sponsored (.sp)
  static final sponsoredLabel = plexSans(8, FontWeight.w700, AppColors.primary, lineHeight: 24, spacing: 0.55);
  static final sponsoredTitle = workSans(14, FontWeight.w700, AppColors.onSurface, lineHeight: 22.5);
  static final sponsoredBody = plexSans(8, FontWeight.w600, AppColors.onSurfaceVariant, lineHeight: 15);
  static final sponsoredCta = plexSans(10, FontWeight.w600, AppColors.primary, lineHeight: 16, spacing: 0.24);

  // Poll (.opt, the footer)
  static final pollQuestion = workSans(12, FontWeight.w700, AppColors.onSurface, lineHeight: 18);
  static final pollHint = plexSans(8, FontWeight.w600, AppColors.outline, lineHeight: 12);
  static final pollOption = plexSans(10, FontWeight.w600, AppColors.onSurface, lineHeight: 20);
  static final pollPercent = plexSans(10, FontWeight.w700, AppColors.onSurfaceVariant, lineHeight: 16, spacing: 0.24);
  static final pollFooter = plexSans(10, FontWeight.w600, AppColors.outline, lineHeight: 16, spacing: 0.24);
  static final pollLink = plexSans(10, FontWeight.w600, AppColors.primary, lineHeight: 16, spacing: 0.24);

  // Bottom navigation: LinkedIn's Android label, 10 sp Roboto Regular (its
  // "Home" is 51 px wide on a 2x phone, which the variable Roboto draws at 10 sp).
  static const navLabel = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 10,
    fontWeight: FontWeight.w400,
    height: 12 / 10,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );

  // Profile drawer (Work Sans throughout, as the Profile Menu spec)
  static final drawerName = workSans(16, FontWeight.w700, AppColors.slate900, lineHeight: 20);
  static final drawerHeadline = workSans(13, FontWeight.w500, AppColors.slate600, lineHeight: 16.25);
  static final drawerLocation = workSans(11, FontWeight.w400, AppColors.slate400, lineHeight: 16.5);
  static final drawerMetric = workSans(12, FontWeight.w600, AppColors.slate900, lineHeight: 16);
  static final drawerMetricLabel = workSans(10, FontWeight.w400, AppColors.slate500, lineHeight: 15);
  static final drawerRowTitle = workSans(13, FontWeight.w600, AppColors.slate900, lineHeight: 19.5);
  static final drawerRowSubtitle = workSans(11, FontWeight.w400, AppColors.slate500, lineHeight: 16.5);
  static final drawerBadge = workSans(10, FontWeight.w600, AppColors.emerald700, lineHeight: 15);
  static final drawerCpd = workSans(10, FontWeight.w700, AppColors.amber800, lineHeight: 15);
  static final drawerSection = workSans(11, FontWeight.w600, AppColors.slate400, lineHeight: 16.5, spacing: 0.55);
  static final drawerLink = workSans(13, FontWeight.w500, AppColors.slate700, lineHeight: 19.5);
  static final drawerFooter = workSans(12, FontWeight.w500, AppColors.slate600, lineHeight: 16);

  // The section screens' shared pieces (Jobs design): bar title, the small
  // search, chips, section headings, buttons.
  static final barTitle = workSans(16, FontWeight.w700, AppColors.onSurface, lineHeight: 20);
  static final searchHintSmall = plexSans(12, FontWeight.w600, AppColors.outline, lineHeight: 16);
  static final searchInputSmall = plexSans(12, FontWeight.w500, AppColors.onSurface, lineHeight: 16);
  static final chipLabel = plexSans(10, FontWeight.w600, AppColors.onSurface, lineHeight: 14);
  static final badgeCount = plexSans(8, FontWeight.w600, AppColors.primary, lineHeight: 10);
  static final sectionTitle = workSans(12, FontWeight.w600, AppColors.onSurface, lineHeight: 16);
  static final sectionAction = workSans(10, FontWeight.w500, AppColors.sectionAction, lineHeight: 14);
  static final primaryButton = workSans(11.5, FontWeight.w700, Colors.white, lineHeight: 16);
  static final outlineButton = plexSans(10, FontWeight.w600, AppColors.onSurface, lineHeight: 14);

  // Discover sheet (Work Sans, as the Profile Menu)
  static final discoverTile = workSans(12, FontWeight.w600, AppColors.onSurfaceVariant, lineHeight: 16);
  static final discoverSection = workSans(11, FontWeight.w600, AppColors.onSurfaceVariant, lineHeight: 16);

  // Sign in
  static final screenTitle = workSans(32, FontWeight.w700, AppColors.onSurface, lineHeight: 40);
  static final screenLead = plexSans(15, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 22);
  static final fieldLabel = plexSans(13, FontWeight.w600, AppColors.onSurface);
  static final fieldInput = plexSans(16, FontWeight.w400, AppColors.onSurface);
  static final fieldHint = plexSans(16, FontWeight.w400, AppColors.outline);
  static final link = plexSans(13, FontWeight.w600, AppColors.primary);
  static final small = plexSans(13, FontWeight.w400, AppColors.onSurfaceVariant);
  static final button = plexSans(15, FontWeight.w600, Colors.white);
}
