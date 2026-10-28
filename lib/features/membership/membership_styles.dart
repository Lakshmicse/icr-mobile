import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';

/// There is no design for the Membership screen: it is drawn in the language
/// of the designed ones (Work Sans titles, Plex body, hairline cards).
class MembershipColors {
  MembershipColors._();

  static const cardBorder = Color(0xFFE1E3E4);
  static const currentRing = AppColors.primary;
  static const benefitTick = AppColors.successInk;
  static const termGlyph = AppColors.slate500;
  static const noticeFill = Color(0xFFEFF7FF);
  static const noticeBorder = Color(0xFFD9E8F8);
}

class MembershipText {
  MembershipText._();

  static final lead = AppText.plexSans(12, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 17);
  static final tagline = AppText.workSans(13, FontWeight.w700, AppColors.primary, lineHeight: 18);
  static final planName = AppText.workSans(16, FontWeight.w700, AppColors.onSurface, lineHeight: 20);
  static final price = AppText.workSans(20, FontWeight.w700, AppColors.onSurface, lineHeight: 24);
  static final priceNote = AppText.plexSans(11, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 15);
  static final compareAt = AppText.plexSans(
    11,
    FontWeight.w400,
    AppColors.onSurfaceVariant,
    lineHeight: 15,
  ).copyWith(decoration: TextDecoration.lineThrough);
  static final description = AppText.plexSans(11.5, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 16);
  static final benefit = AppText.plexSans(11.5, FontWeight.w400, AppColors.onSurface, lineHeight: 16);
  static final termsHeading = AppText.plexSans(9.5, FontWeight.w600, AppColors.onSurfaceVariant, lineHeight: 13);
  static final yourPlanLabel = AppText.plexSans(9.5, FontWeight.w600, AppColors.onSurfaceVariant, lineHeight: 13);
  static final yourPlanName = AppText.workSans(16, FontWeight.w700, AppColors.onSurface, lineHeight: 20);
  static final yourPlanNote = AppText.plexSans(11, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 15);
  static final yourPlanWarning = AppText.plexSans(11, FontWeight.w500, AppColors.amber800, lineHeight: 15);
  static final link = AppText.plexSans(11.5, FontWeight.w600, AppColors.primary, lineHeight: 16);
  static final chip = AppText.plexSans(11, FontWeight.w600, AppColors.onSurface, lineHeight: 14);
  static final current = AppText.plexSans(9, FontWeight.w700, Colors.white, lineHeight: 12);
  static final notice = AppText.plexSans(11.5, FontWeight.w500, AppColors.onSurface, lineHeight: 16);
  static final termPlan = AppText.workSans(13, FontWeight.w700, AppColors.onSurface, lineHeight: 17);
  static final termMeta = AppText.plexSans(11, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 15);
  static final termAmount = AppText.plexSans(12, FontWeight.w600, AppColors.onSurface, lineHeight: 16);
}
