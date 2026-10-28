import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';

/// Colours the Mentor Profile designs add to the palette.
class MentorColors {
  MentorColors._();

  /// The mint pill ("Next Slot", "Present", "Top 5% Mentor", "Trial: ₹0").
  static const mint = Color(0xFF9DF4C8);

  /// Ink on a mint pill.
  static const mintInk = Color(0xFF0B3B27);

  /// The MENTOR ring around the photo.
  static const ring = Color(0xFF016B48);

  /// "FREE", "Instant Download".
  static const green = Color(0xFF128A52);
  static const star = Color(0xFFF49400);
  static const starMint = Color(0xFF9DF3CE);

  /// The plan card's gradient.
  static const navyDeep = Color(0xFF0F1B30);
  static const navyMid = Color(0xFF073258);
  static const planKicker = Color(0x2EFFFFFF);
  static const planPrice = Color(0xFF7FE3B5);
  static const planCheck = Color(0xFF2ECB8A);
  static const pinkPill = Color(0xFFFDDCDC);
  static const pinkInk = Color(0xFFB91C1C);

  /// The dark pill over the offering's photo.
  static const photoPill = Color(0xE6505662);
  static const tileFill = Color(0xFFFAFAFA);
  static const tileBorder = Color(0xFFE4E4E4);
  static const timeline = Color(0xFFE1E3E4);
  static const sheetInk = Color(0xFF0F172A);
}

/// Type for the Mentor Profile screens, sized from the designs by measured width.
class MentorText {
  MentorText._();

  // The hero.
  static final name = AppText.workSans(15.5, FontWeight.w700, AppColors.onSurface, lineHeight: 20);
  static final headline = AppText.plexSans(14, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 18.2);
  static final headlineStrong = AppText.plexSans(14, FontWeight.w700, AppColors.onSurface, lineHeight: 18.2);
  static final fact = AppText.plexSans(11, FontWeight.w600, AppColors.onSurfaceVariant, lineHeight: 14);
  static final slot = AppText.plexSans(11, FontWeight.w600, MentorColors.mintInk, lineHeight: 14);
  static final ratingValue = AppText.workSans(11.5, FontWeight.w700, AppColors.onSurface, lineHeight: 14);
  static final ratingCount = AppText.plexSans(10.5, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 14);
  static final verifiedPill = AppText.plexSans(8.5, FontWeight.w600, AppColors.primary, lineHeight: 12);
  static final ringWord = AppText.plexSans(6.5, FontWeight.w700, Colors.white, lineHeight: 8, spacing: 1.4);
  static final primaryButton = AppText.plexSans(9.9, FontWeight.w500, Colors.white, lineHeight: 14);
  static final softButton = AppText.plexSans(9.9, FontWeight.w500, AppColors.onSurface, lineHeight: 14);
  static final tab = AppText.plexSans(9.5, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 13);
  static final tabSelected = AppText.plexSans(9.5, FontWeight.w600, Colors.white, lineHeight: 13);

  // The stats card.
  static final statValue = AppText.workSans(11.5, FontWeight.w700, AppColors.onSurface, lineHeight: 14);
  static final statCaption = AppText.plexSans(8, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 11);
  static final statBadge = AppText.plexSans(8, FontWeight.w700, MentorColors.mintInk, lineHeight: 10);
  static final statLabel = AppText.plexSans(8.5, FontWeight.w600, AppColors.onSurfaceVariant, lineHeight: 11);
  static final language = AppText.plexSans(8.5, FontWeight.w500, AppColors.onSurface, lineHeight: 11);

  // Sections.
  static final section = AppText.workSans(11.5, FontWeight.w700, AppColors.onSurface, lineHeight: 16);
  static final sectionWide = AppText.workSans(12, FontWeight.w700, AppColors.onSurface, lineHeight: 16);
  static final sectionNote = AppText.plexSans(8, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 11);
  static final body = AppText.plexSans(10, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 15);
  static final readMore = AppText.plexSans(10.5, FontWeight.w600, AppColors.primary, lineHeight: 14);

  // Career.
  static final roleTitle = AppText.workSans(10, FontWeight.w700, AppColors.onSurface, lineHeight: 14);
  static final roleOrg = AppText.plexSans(10, FontWeight.w600, AppColors.onSurface, lineHeight: 14);
  static final roleOrgLink = AppText.plexSans(10, FontWeight.w600, AppColors.primary, lineHeight: 14);
  static final roleMeta = AppText.plexSans(8.5, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 11);
  static final roleYears = AppText.plexSans(8, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 11);
  static final presentBadge = AppText.plexSans(8, FontWeight.w700, MentorColors.mintInk, lineHeight: 10);

  // Education.
  static final school = AppText.workSans(10, FontWeight.w700, AppColors.onSurface, lineHeight: 15);
  static final degree = AppText.plexSans(10, FontWeight.w600, AppColors.primary, lineHeight: 14);
  static final batch = AppText.plexSans(8, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 11);

  // Skills.
  static final skillLabel = AppText.plexSans(8.5, FontWeight.w600, AppColors.onSurfaceVariant, lineHeight: 11);
  static final skill = AppText.plexSans(9, FontWeight.w500, AppColors.onSurface, lineHeight: 12);

  // Recommendations.
  static final reviewer = AppText.workSans(12, FontWeight.w600, AppColors.onSurface, lineHeight: 16);
  static final reviewerLine = AppText.plexSans(7.5, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 10);
  static final quote = AppText.plexSans(10, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 15);
  static final viewAll = AppText.plexSans(10.5, FontWeight.w600, AppColors.primary, lineHeight: 14);

  // The plan card.
  static final planKicker = AppText.plexSans(8, FontWeight.w700, const Color(0xFFDCE6F2), lineHeight: 10, spacing: 0.6);
  static final planTitle = AppText.workSans(13, FontWeight.w700, Colors.white, lineHeight: 18);
  static final planPrice = AppText.workSans(13, FontWeight.w700, MentorColors.planPrice, lineHeight: 16);
  static final planPer = AppText.plexSans(8.5, FontWeight.w400, Colors.white, lineHeight: 12);
  static final planSeats = AppText.plexSans(7.5, FontWeight.w700, MentorColors.pinkInk, lineHeight: 10);
  static final planLine = AppText.plexSans(10, FontWeight.w400, Colors.white, lineHeight: 14);
  static final planButton = AppText.workSans(10.5, FontWeight.w700, AppColors.primary, lineHeight: 14);

  // The bottom bar.
  static final barButton = AppText.plexSans(10.1, FontWeight.w600, Colors.white, lineHeight: 14);

  // Offerings.
  static final filter = AppText.plexSans(9, FontWeight.w500, AppColors.onSurface, lineHeight: 12);
  static final filterSelected = AppText.plexSans(9, FontWeight.w700, Colors.white, lineHeight: 12);
  static final info = AppText.plexSans(9.5, FontWeight.w400, AppColors.onSurface, lineHeight: 13);
  static final tag = AppText.plexSans(9, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 12);
  static final tagStrong = AppText.plexSans(
    8,
    FontWeight.w700,
    AppColors.onSurfaceVariant,
    lineHeight: 12,
    spacing: 0.3,
  );
  static final tagGreen = AppText.plexSans(8, FontWeight.w600, MentorColors.green, lineHeight: 12);
  static final free = AppText.plexSans(8.5, FontWeight.w700, MentorColors.green, lineHeight: 12);
  static final wasPrice = AppText.plexSans(
    8.7,
    FontWeight.w500,
    AppColors.onSurfaceVariant,
    lineHeight: 14,
  ).copyWith(decoration: TextDecoration.lineThrough, decorationColor: AppColors.onSurfaceVariant);
  static final price = AppText.workSans(11, FontWeight.w700, AppColors.onSurface, lineHeight: 14);
  static final offeringTitle = AppText.workSans(10, FontWeight.w700, AppColors.onSurface, lineHeight: 14);
  static final offeringBlurb = AppText.plexSans(10, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 15);
  static final preview = AppText.plexSans(8.5, FontWeight.w600, AppColors.primary, lineHeight: 12);
  static final pill = AppText.plexSans(10, FontWeight.w600, AppColors.primary, lineHeight: 14);
  static final requestNote = AppText.plexSans(8.5, FontWeight.w600, AppColors.onSurfaceVariant, lineHeight: 12);

  // The offering sheet (the design's larger scale).
  static final sheetKicker = AppText.plexSans(10.5, FontWeight.w700, Colors.white, lineHeight: 14, spacing: 1);
  static final sheetRating = AppText.plexSans(14, FontWeight.w400, Colors.white, lineHeight: 18);
  static final sheetTitle = AppText.workSans(15, FontWeight.w700, MentorColors.sheetInk, lineHeight: 22);
  static final sheetBlurb = AppText.plexSans(12, FontWeight.w500, const Color(0xFF42464F), lineHeight: 15.6);
  static final sheetFact = AppText.plexSans(11, FontWeight.w500, MentorColors.sheetInk, lineHeight: 14);
  static final sheetSection = AppText.workSans(12, FontWeight.w700, MentorColors.sheetInk, lineHeight: 16);
  static final sheetSectionWide = AppText.workSans(16, FontWeight.w700, MentorColors.sheetInk, lineHeight: 20);
  static final tileTitle = AppText.plexSans(14, FontWeight.w600, MentorColors.sheetInk, lineHeight: 18);
  static final tileBody = AppText.plexSans(11, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 14.5);
  static final segment = AppText.plexSans(11.5, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 14);
  static final segmentSelected = AppText.plexSans(12, FontWeight.w600, Colors.white, lineHeight: 14);
  static final moduleNumber = AppText.plexSans(12, FontWeight.w600, MentorColors.sheetInk, lineHeight: 14);
  static final moduleTitle = AppText.workSans(14, FontWeight.w700, MentorColors.sheetInk, lineHeight: 18);
  static final moduleBadge = AppText.plexSans(11, FontWeight.w600, AppColors.primary, lineHeight: 14);
  static final stepLead = AppText.plexSans(14, FontWeight.w700, MentorColors.sheetInk, lineHeight: 18);
  static final step = AppText.plexSans(14, FontWeight.w500, MentorColors.sheetInk, lineHeight: 18);
  static final startsAt = AppText.plexSans(11.5, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 14);
  static final startsPrice = AppText.workSans(15, FontWeight.w700, MentorColors.sheetInk, lineHeight: 18);
  static final startsPer = AppText.plexSans(10, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 14);
  static final trialPill = AppText.plexSans(12, FontWeight.w700, MentorColors.mintInk, lineHeight: 14);
  static final taxes = AppText.plexSans(10.5, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 14);
  static final plansButton = AppText.plexSans(13, FontWeight.w500, MentorColors.sheetInk, lineHeight: 16);
  static final sheetButton = AppText.plexSans(13.5, FontWeight.w600, Colors.white, lineHeight: 16);

  // Forms.
  static final formTitle = AppText.workSans(14, FontWeight.w700, AppColors.slate900, lineHeight: 20);
  static final formLabel = AppText.plexSans(11, FontWeight.w600, AppColors.onSurface, lineHeight: 16);
  static final formHelp = AppText.plexSans(11, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 16);
  static final formInput = AppText.plexSans(14, FontWeight.w400, AppColors.onSurface, lineHeight: 20);
}
