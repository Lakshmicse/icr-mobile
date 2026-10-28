import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';

/// The discussion page's and the Forums tab's own colours and type. The pages have no design of their own: they are
/// built in the Home feed's visual language (Work Sans for names and headings, IBM Plex Sans for the rest, the same
/// card edges, chips and rules), with the reply thread drawn as the "Branching Nested Replies Section" design.
class ForumDesign {
  ForumDesign._();

  /// The page gutter, as the Home feed's.
  static const gutter = 16.0;

  static const noticeInfoFill = Color(0xFFF1F5F9);
  static const noticeWarnFill = Color(0xFFFFF7E6);
  static const noticeWarnBorder = Color(0xFFFDE68A);
  static const noticeWarnInk = Color(0xFF92400E);
  static const successFill = Color(0xFFECFDF5);
  static const successBorder = Color(0xFFA7F3D0);
  static const successInk = Color(0xFF047857);

  static final threadTitle = AppText.workSans(18, FontWeight.w700, AppColors.onSurface, lineHeight: 25);
  static final body = AppText.plexSans(13, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 21);
  static final meta = AppText.plexSans(10.5, FontWeight.w500, AppColors.outline, lineHeight: 15);
  static final metaLink = AppText.plexSans(10.5, FontWeight.w600, AppColors.primary, lineHeight: 15);
  static final author = AppText.workSans(13, FontWeight.w600, AppColors.onSurface, lineHeight: 17);
  static final headline = AppText.plexSans(10.5, FontWeight.w500, AppColors.outline, lineHeight: 14);
  static final sectionTitle = AppText.workSans(14, FontWeight.w700, AppColors.onSurface, lineHeight: 20);
  static final chip = AppText.plexSans(10, FontWeight.w600, AppColors.onSurfaceVariant, lineHeight: 14);
  static final tag = AppText.plexSans(10, FontWeight.w700, AppColors.primary, lineHeight: 14);
  static final action = AppText.plexSans(10.5, FontWeight.w600, AppColors.icon, lineHeight: 14);
  static final notice = AppText.plexSans(11, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 16);
  static final noticeTitle = AppText.plexSans(11.5, FontWeight.w700, AppColors.onSurface, lineHeight: 16);
  static final sheetTitle = AppText.workSans(16, FontWeight.w700, AppColors.onSurface, lineHeight: 22);
  static final sheetRow = AppText.plexSans(13, FontWeight.w500, AppColors.onSurface, lineHeight: 18);
  static final sheetHint = AppText.plexSans(11, FontWeight.w500, AppColors.outline, lineHeight: 16);
  static final field = AppText.plexSans(13, FontWeight.w500, AppColors.onSurface, lineHeight: 19);
  static final fieldHint = AppText.plexSans(13, FontWeight.w500, AppColors.outline, lineHeight: 19);
  static final fieldLabel = AppText.plexSans(
    11,
    FontWeight.w700,
    AppColors.onSurfaceVariant,
    lineHeight: 14,
    spacing: 0.4,
  );
  static final button = AppText.workSans(13, FontWeight.w700, Colors.white, lineHeight: 18);
  static final count = AppText.plexSans(10, FontWeight.w600, AppColors.outline, lineHeight: 14);
}
