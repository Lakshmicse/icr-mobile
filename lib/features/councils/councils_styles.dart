import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';

/// Colours sampled from the Councils design that the app's palette lacks.
class CouncilsColors {
  CouncilsColors._();

  /// The stat tiles and the grey pills.
  static const tile = Color(0xFFF8FAFC);
  static const tileRule = Color(0xFFE9EDF2);
  static const cardBorder = Color(0xFFE2E8F0);
  static const rowRule = Color(0xFFE2E8F0);

  static const green50 = Color(0xFFECFDF5);
  static const green100 = Color(0xFFD1FAE5);
  static const green200 = Color(0xFFA7F3D0);
  static const green700 = Color(0xFF047857);
  static const blue50 = Color(0xFFEFF6FF);
  static const blue700 = Color(0xFF1D4ED8);
  static const red50 = Color(0xFFFEF2F2);
  static const red600 = Color(0xFFDC2626);
  static const greyPill = Color(0xFFF1F5F9);
  static const slate800 = Color(0xFF1E293B);
  static const green900 = Color(0xFF064E3B);

  /// The hashtag pills.
  static const tagFill = Color(0xFFF2F4F6);

  /// "Join Council": a deeper blue than the primary.
  static const joinButton = Color(0xFF004B83);

  /// Over a cover photo. The darkening is mild on purpose: the seeded covers are the design's photos
  /// with exactly this taken back out (`tool/design/cut_council_covers.py`, keep the two in step), so
  /// the screen reads as the design.
  static const coverTile = Color(0x40FFFFFF);
  static const coverPill = Color(0x38FFFFFF);
  static const coverScrimTop = Color(0x1A0B1329);
  static const coverScrimBottom = Color(0x330B1329);

  /// The In-Person Summits footer.
  static const navy = Color(0xFF144174);
  static const navyTile = Color(0xFF1E4A7B);
  static const navyTileBorder = Color(0xFF2C5A8C);
  static const navyCopy = Color(0xFFC3D0DF);
  static const summitTile = Color(0xFF0F4E5E);
}

/// Type for the Councils screen, sized from the design by measured width.
class CouncilsText {
  CouncilsText._();

  // The stat tiles.
  static final statLabel = AppText.plexSans(8, FontWeight.w500, AppColors.slate500, lineHeight: 11);
  static final statValue = AppText.workSans(14, FontWeight.w700, AppColors.slate900, lineHeight: 18);
  static final statValueBlue = AppText.workSans(14, FontWeight.w700, AppColors.primary, lineHeight: 18);
  static final statPill = AppText.plexSans(9.5, FontWeight.w700, CouncilsColors.green700, lineHeight: 12);

  // Section headings.
  static final sectionTitle = AppText.workSans(12, FontWeight.w700, AppColors.slate900, lineHeight: 16);
  static final sectionPill = AppText.plexSans(10.5, FontWeight.w600, AppColors.slate700, lineHeight: 14);
  static final sectionLink = AppText.plexSans(10.5, FontWeight.w700, AppColors.primary, lineHeight: 14);
  static final sectionCaption = AppText.plexSans(10.5, FontWeight.w500, AppColors.slate400, lineHeight: 14);

  // The joined-councils rail.
  static final rolePill = AppText.plexSans(10.5, FontWeight.w600, CouncilsColors.green700, lineHeight: 13);
  static final joinedTitle = AppText.workSans(12, FontWeight.w700, AppColors.slate900, lineHeight: 19);
  static final joinedCopy = AppText.plexSans(8, FontWeight.w400, AppColors.slate500, lineHeight: 11.5);
  static final peers = AppText.plexSans(10, FontWeight.w500, AppColors.slate500, lineHeight: 14);
  static final roomLink = AppText.plexSans(10.8, FontWeight.w600, Colors.white, lineHeight: 14);
  static final meetingLink = AppText.plexSans(10.5, FontWeight.w700, AppColors.slate900, lineHeight: 14);

  // Upcoming roundtables.
  static final modePill = AppText.plexSans(9.5, FontWeight.w700, CouncilsColors.blue700, lineHeight: 12, spacing: 0.3);
  static final time = AppText.plexSans(10, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 12);
  static final dateMonth = AppText.plexSans(8, FontWeight.w700, AppColors.slate600, lineHeight: 11, spacing: 1.0);
  static final dateDay = AppText.workSans(16.5, FontWeight.w700, AppColors.slate900, lineHeight: 19);
  static final roundtableTitle = AppText.workSans(12, FontWeight.w700, AppColors.slate900, lineHeight: 16);
  static final roundtableDetail = AppText.plexSans(10.5, FontWeight.w400, AppColors.slate500, lineHeight: 14);

  // Search and chips.
  static final searchHint = AppText.plexSans(10.5, FontWeight.w600, AppColors.slate500, lineHeight: 14);
  static final searchInput = AppText.plexSans(10.5, FontWeight.w500, AppColors.onSurface, lineHeight: 14);
  static final chip = AppText.plexSans(11.5, FontWeight.w600, AppColors.slate600, lineHeight: 14);

  // Council cards.
  static final coverPill = AppText.plexSans(8, FontWeight.w700, Colors.white, lineHeight: 10, spacing: 0.4);
  static final coverPillSoft = AppText.plexSans(8, FontWeight.w500, Colors.white, lineHeight: 10);
  static final cardTitle = AppText.workSans(12, FontWeight.w700, AppColors.slate900, lineHeight: 16);
  static final chair = AppText.plexSans(10.4, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 13);
  static final chairName = AppText.plexSans(10.4, FontWeight.w600, AppColors.onSurface, lineHeight: 13);
  static final cardCopy = AppText.plexSans(12, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 16);
  static final tag = AppText.plexSans(9.3, FontWeight.w700, CouncilsColors.joinButton, lineHeight: 11);
  static final meta = AppText.plexSans(9, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 12);
  static final metaGreen = AppText.plexSans(9, FontWeight.w600, AppColors.tertiary, lineHeight: 12);
  static final joinButton = AppText.plexSans(7, FontWeight.w700, Colors.white, lineHeight: 10);
  static final loungeButton = AppText.plexSans(7, FontWeight.w700, AppColors.primary, lineHeight: 10);
  static final preview = AppText.plexSans(7.5, FontWeight.w600, AppColors.onSurfaceVariant, lineHeight: 10);

  // The In-Person Summits footer.
  static final summitKicker = AppText.plexSans(9.5, FontWeight.w700, AppColors.success, lineHeight: 13, spacing: 0.8);
  static final summitTitle = AppText.workSans(12, FontWeight.w700, Colors.white, lineHeight: 16);
  static final summitCopy = AppText.plexSans(10, FontWeight.w400, CouncilsColors.navyCopy, lineHeight: 15);
  static final city = AppText.plexSans(11, FontWeight.w600, Colors.white, lineHeight: 14);
  static final cityDate = AppText.plexSans(11, FontWeight.w500, AppColors.success, lineHeight: 14, spacing: 0.5);
  static final directoryButton = AppText.workSans(10, FontWeight.w700, AppColors.slate900, lineHeight: 14);

  // Sheets and notices.
  static final sheetTitle = AppText.workSans(14, FontWeight.w700, AppColors.slate900, lineHeight: 20);
  static final sheetRow = AppText.plexSans(14, FontWeight.w400, AppColors.onSurface, lineHeight: 20);
}
