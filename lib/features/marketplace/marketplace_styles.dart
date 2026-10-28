import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';

/// Colours the Marketplace designs use beyond `AppColors`.
class MartColors {
  MartColors._();

  /// The card's border: slate-200.
  static const cardBorder = AppColors.slate200;

  /// The rule under a card's logo, and the hairlines inside the profile.
  static const rule = AppColors.outlineVariant;

  static const star = AppColors.amber500;

  /// The profile's star: a touch darker than the card's.
  static const profileStar = Color(0xFFDE9D30);

  /// The grab bar of the supplier sheet.
  static const handle = Color(0xFFDADDE4);

  /// The lettering of a live card's company name; the API has no brand colour.
  static const brand = Color(0xFF1A3A8F);

  /// The profile's logo tile (the design leaves it a flat blue-grey).
  static const logoTile = Color(0xFFD3E1EE);

  static const whatsapp = AppColors.tertiary;
  static const bandFill = AppColors.surfaceContainer;
  static const barFill = Color(0xFFF8F9FA);
}

/// Type for the Marketplace list and the supplier profile, sized from the
/// designs by measured width (`tool/design/fitfont.py`) and weighed against
/// the picture (`fontscore`): the list is IBM Plex Sans throughout; the
/// profile sets the name, its headings and its big numbers in Work Sans.
class MartText {
  MartText._();

  // ---- The list -------------------------------------------------------------------

  static final searchHint = AppText.plexSans(14, FontWeight.w500, AppColors.outline, lineHeight: 20);
  static final searchInput = AppText.plexSans(14, FontWeight.w500, AppColors.onSurface, lineHeight: 20);

  /// "Post RFQ", "My RFQ's", "Alerts".
  static final quickChip = AppText.plexSans(12, FontWeight.w600, AppColors.onSurface, lineHeight: 16);

  /// "Filters (3)", "Sort Top rated", "By ratings", "Verified only".
  static final filterChip = AppText.plexSans(12.3, FontWeight.w600, AppColors.onSurface, lineHeight: 16);
  static final chipCount = AppText.plexSans(9, FontWeight.w700, AppColors.primary, lineHeight: 12);
  static final chipPill = AppText.plexSans(11, FontWeight.w700, Colors.white, lineHeight: 14);

  /// A live card's company name, set beside its logo.
  static final cardName = AppText.workSans(14.5, FontWeight.w700, MartColors.brand, lineHeight: 18);
  static final cardRating = AppText.plexSans(14.6, FontWeight.w700, MartColors.star, lineHeight: 20);
  static final cardReviews = AppText.plexSans(12, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 16);
  static final cardTitle = AppText.plexSans(15.8, FontWeight.w700, AppColors.onSurface, lineHeight: 20);
  static final cardBody = AppText.plexSans(12, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 18.5);

  static final showing = AppText.plexSans(14.4, FontWeight.w600, AppColors.onSurfaceVariant, lineHeight: 20);
  static final loadMore = AppText.plexSans(14.3, FontWeight.w600, AppColors.primary, lineHeight: 20);

  // ---- The sheets the chips open ---------------------------------------------------------

  static final sheetTitle = AppText.workSans(15, FontWeight.w700, AppColors.onSurface, lineHeight: 20);
  static final sheetSection = AppText.workSans(12, FontWeight.w600, AppColors.onSurface, lineHeight: 16);
  static final sheetRow = AppText.plexSans(13, FontWeight.w500, AppColors.onSurface, lineHeight: 18);
  static final sheetRowMuted = AppText.plexSans(11.5, FontWeight.w400, AppColors.outline, lineHeight: 16);
  static final sheetButton = AppText.plexSans(13, FontWeight.w600, Colors.white, lineHeight: 18);
  static final sheetLink = AppText.plexSans(12.5, FontWeight.w600, AppColors.primary, lineHeight: 16);

  // ---- The profile ------------------------------------------------------------------------

  static final name = AppText.workSans(16, FontWeight.w700, AppColors.onSurface, lineHeight: 18);
  static final registration = AppText.plexSans(10.4, FontWeight.w600, AppColors.primary, lineHeight: 14);
  static final ratingValue = AppText.plexSans(9.9, FontWeight.w700, AppColors.onSurface, lineHeight: 14);
  static final ratingMeta = AppText.plexSans(10.65, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 14);
  static final tier = AppText.plexSans(9.9, FontWeight.w600, AppColors.tertiary, lineHeight: 14);
  static final tagline = AppText.plexSans(10, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 15);
  static final callHq = AppText.plexSans(9.8, FontWeight.w600, AppColors.onSurface, lineHeight: 14);
  static final whatsapp = AppText.plexSans(9.9, FontWeight.w600, MartColors.whatsapp, lineHeight: 14);
  static final website = AppText.plexSans(9.9, FontWeight.w600, AppColors.primary, lineHeight: 14);
  static final tab = AppText.plexSans(9.9, FontWeight.w600, AppColors.onSurfaceVariant, lineHeight: 14);
  static final tabOn = AppText.plexSans(9.9, FontWeight.w600, Colors.white, lineHeight: 14);
  static final heading = AppText.workSans(11.9, FontWeight.w600, AppColors.onSurface, lineHeight: 16);
  static final factLabel = AppText.plexSans(10, FontWeight.w500, AppColors.outline, lineHeight: 15);
  static final factValue = AppText.plexSans(10, FontWeight.w500, AppColors.onSurface, lineHeight: 15);
  static final itemTitle = AppText.workSans(20, FontWeight.w700, AppColors.onSurface, lineHeight: 26);
  static final itemPrice = AppText.workSans(22, FontWeight.w700, AppColors.primary, lineHeight: 28);
  static final sectionTitle = AppText.workSans(12, FontWeight.w700, AppColors.onSurface, lineHeight: 16);
  static final tileValue = AppText.workSans(13.7, FontWeight.w700, AppColors.onSurface, lineHeight: 18);
  static final tileCaption = AppText.plexSans(8, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 15);
  static final body = AppText.plexSans(10, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 15);
  static final readMore = AppText.plexSans(9.9, FontWeight.w600, AppColors.primary, lineHeight: 14);
  static final bandKicker = AppText.plexSans(8.2, FontWeight.w600, Colors.black, lineHeight: 12, spacing: 0.5);
  static final bandTitle = AppText.plexSans(12.1, FontWeight.w600, AppColors.onSurfaceVariant, lineHeight: 16);
  static final bandLine = AppText.plexSans(9, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 14);
  static final bandButton = AppText.plexSans(9.9, FontWeight.w600, AppColors.primary, lineHeight: 14);
  static final rfqButton = AppText.plexSans(10.1, FontWeight.w600, Colors.white, lineHeight: 14);

  // Products & services
  static final serviceName = AppText.workSans(12, FontWeight.w700, AppColors.onSurface, lineHeight: 16);
  static final serviceBody = AppText.plexSans(8.6, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 12);
  static final serviceMeta = AppText.plexSans(10.6, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 14);
  static final serviceButton = AppText.plexSans(10.5, FontWeight.w600, AppColors.onSurfaceVariant, lineHeight: 14);
  static final groupChip = AppText.plexSans(9.8, FontWeight.w600, AppColors.onSurface, lineHeight: 14);

  // Compliances & proofs
  static final proofTitle = AppText.workSans(10, FontWeight.w600, AppColors.onSurface, lineHeight: 15);
  static final proofDetail = AppText.plexSans(8.2, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 12);

  /// The licence number is set in a typewriter face (`Courier` is on both Android and iOS).
  static final proofNumber = const TextStyle(
    fontFamily: 'Courier',
    fontFamilyFallback: ['Courier New', 'monospace'],
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.onSurfaceVariant,
    height: 1.3,
    letterSpacing: 0,
  );
  static final proofStatus = AppText.workSans(9.4, FontWeight.w700, AppColors.tertiary, lineHeight: 14);
  static final proofStatusPlain = AppText.workSans(9.4, FontWeight.w700, AppColors.onSurface, lineHeight: 14);
  static final proofBy = AppText.workSans(9.5, FontWeight.w600, AppColors.onSurface, lineHeight: 20);
  static final proofRole = AppText.plexSans(8.2, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 12);
  static final proofQuote = AppText.plexSans(
    9.6,
    FontWeight.w400,
    AppColors.onSurfaceVariant,
    lineHeight: 19,
  ).copyWith(fontStyle: FontStyle.italic);
}

/// [style] drawn at [k] times its size, its line height following (the cards
/// shrink as a whole when their cell is narrower than the phone design's).
TextStyle scaled(TextStyle style, double k) {
  if (k == 1) return style;
  return style.copyWith(fontSize: style.fontSize! * k);
}
