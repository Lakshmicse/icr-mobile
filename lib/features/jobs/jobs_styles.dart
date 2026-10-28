import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';

/// Type for the Jobs screens, sized from the designs by measured width.
class JobsText {
  JobsText._();

  // The board.
  static final rowTitle = AppText.workSans(12, FontWeight.w600, AppColors.onSurface, lineHeight: 16);
  static final rowCompany = AppText.workSans(10, FontWeight.w700, AppColors.onSurfaceVariant, lineHeight: 14);
  static final rowMeta = AppText.plexSans(10, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 14);
  static final contextLabel = AppText.plexSans(10, FontWeight.w600, AppColors.onSurface, lineHeight: 14);
  static final contextPlace = AppText.plexSans(10.5, FontWeight.w500, AppColors.outline, lineHeight: 14);

  /// The filter chips ("Filters (3)", "Easy Apply", "Date posted"): a touch
  /// larger than the chips above them, as the design sets them.
  static final filterChip = AppText.plexSans(10.5, FontWeight.w600, AppColors.onSurface, lineHeight: 14);

  /// "2 new" in the Alerts chip.
  static final pill = AppText.plexSans(8, FontWeight.w600, Colors.white, lineHeight: 10);

  // The job sheet.
  static final kicker = AppText.plexSans(
    8.5,
    FontWeight.w600,
    AppColors.onSurfaceVariant,
    lineHeight: 10,
    spacing: 0.4,
  );
  static final companyName = AppText.workSans(11.5, FontWeight.w600, AppColors.slate900, lineHeight: 16);
  static final companyTagline = AppText.plexSans(8.5, FontWeight.w500, AppColors.inkMuted, lineHeight: 12);
  static final title = AppText.workSans(13, FontWeight.w700, AppColors.slate900, lineHeight: 18);
  static final highlight = AppText.plexSans(9.7, FontWeight.w600, AppColors.primary, lineHeight: 14);
  static final meta = AppText.plexSans(10.5, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 14);
  static final metaSoft = AppText.plexSans(10.5, FontWeight.w500, AppColors.inkSoft, lineHeight: 14);
  static final status = AppText.plexSans(8.5, FontWeight.w600, AppColors.tertiary, lineHeight: 12);
  static final statusMeta = AppText.plexSans(8.5, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 12);
  static final chip = AppText.plexSans(10, FontWeight.w600, AppColors.onSurfaceVariant, lineHeight: 13);
  static final chipMatch = AppText.plexSans(10, FontWeight.w600, AppColors.successInk, lineHeight: 13);
  static final section = AppText.workSans(12, FontWeight.w700, AppColors.slate900, lineHeight: 17);
  static final body = AppText.plexSans(10, FontWeight.w500, AppColors.slate900, lineHeight: 16);
  static final bullet = AppText.plexSans(10, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 15);
  static final skill = AppText.plexSans(10, FontWeight.w500, AppColors.onSurface, lineHeight: 14);
  static final checkTitle = AppText.workSans(9.5, FontWeight.w600, AppColors.onSurface, lineHeight: 14);
  static final checkDetail = AppText.plexSans(8.5, FontWeight.w500, const Color(0xFF4C525A), lineHeight: 12);
  static final insights = AppText.plexSans(10, FontWeight.w600, AppColors.primary, lineHeight: 14);
  static final contactName = AppText.workSans(11.5, FontWeight.w600, AppColors.slate900, lineHeight: 16);
  static final contactDegree = AppText.workSans(11.5, FontWeight.w400, AppColors.inkMuted, lineHeight: 16);
  static final contactLine = AppText.plexSans(10.5, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 15);
  static final contactLink = AppText.plexSans(10.5, FontWeight.w600, AppColors.primary, lineHeight: 15);
  static final network = AppText.plexSans(10.5, FontWeight.w600, AppColors.slate700, lineHeight: 15);
  static final networkInitials = AppText.plexSans(9, FontWeight.w700, Colors.white, lineHeight: 12);
  static final aboutMeta = AppText.plexSans(10, FontWeight.w500, AppColors.inkMuted, lineHeight: 16);
  static final follow = AppText.plexSans(10, FontWeight.w600, AppColors.onSurfaceVariant, lineHeight: 14);
  static final description = AppText.plexSans(10, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 14.5);

  // Applying.
  static final formTitle = AppText.workSans(14, FontWeight.w700, AppColors.slate900, lineHeight: 20);
  static final formLabel = AppText.plexSans(11, FontWeight.w600, AppColors.onSurface, lineHeight: 16);
  static final formHelp = AppText.plexSans(11, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 16);
  static final formInput = AppText.plexSans(14, FontWeight.w400, AppColors.onSurface, lineHeight: 20);
}
