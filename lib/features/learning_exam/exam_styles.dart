import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';

/// Colours the exam screens add to `AppColors`.
class ExamColors {
  ExamColors._();

  /// The palette's conventional CBT colours: green answered, red seen but not
  /// answered, purple flagged, amber answered and flagged.
  static const answered = Color(0xFF15803D);
  static const notAnswered = Color(0xFFDC2626);
  static const flagged = Color(0xFF7C3AED);
  static const answeredFlagged = Color(0xFFF59E0B);
  static const answeredFlaggedInk = Color(0xFF1F2937);

  static const cardBorder = AppColors.slate200;
  static const sheetTint = Color(0xFFF8FAFC);
  static const optionSelectedFill = Color(0xFFEAF2FB);
  static const correctFill = Color(0xFFECFDF5);
  static const wrongFill = Color(0xFFFEF2F2);
  static const wrongBorder = Color(0xFFFCA5A5);
  static const warnFill = Color(0xFFFFFBEB);
  static const warnBorder = Color(0xFFFDE68A);
  static const gold = Color(0xFFBF9B3F);
  static const navy = Color(0xFF12406E);
  static const azure = Color(0xFF1B7FD7);
}

/// Type for the exam screens, sized for a phone (body 14 to 16, titles 18 to 24).
class ExamText {
  ExamText._();

  static final screenTitle = AppText.workSans(17, FontWeight.w700, AppColors.onSurface, lineHeight: 22);
  static final heroTitle = AppText.workSans(22, FontWeight.w800, AppColors.onSurface, lineHeight: 28);
  static final heading = AppText.workSans(16, FontWeight.w700, AppColors.onSurface, lineHeight: 22);
  static final subheading = AppText.workSans(14, FontWeight.w700, AppColors.onSurface, lineHeight: 20);
  static final body = AppText.plexSans(14, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 21);
  static final bodyStrong = AppText.plexSans(14, FontWeight.w600, AppColors.onSurface, lineHeight: 21);
  static final small = AppText.plexSans(12, FontWeight.w500, AppColors.inkMuted, lineHeight: 17);
  static final eyebrow = AppText.plexSans(11, FontWeight.w700, AppColors.primary, lineHeight: 15, spacing: 0.8);
  static final question = AppText.workSans(17, FontWeight.w600, AppColors.onSurface, lineHeight: 25);
  static final option = AppText.plexSans(15, FontWeight.w500, AppColors.onSurface, lineHeight: 22);
  static final optionLetter = AppText.workSans(13, FontWeight.w700, AppColors.slate600, lineHeight: 16);
  static final button = AppText.workSans(14, FontWeight.w700, Colors.white, lineHeight: 18);
  static final buttonQuiet = AppText.workSans(14, FontWeight.w700, AppColors.onSurface, lineHeight: 18);
  static final link = AppText.plexSans(13, FontWeight.w600, AppColors.primary, lineHeight: 18);
  static final statNumber = AppText.workSans(26, FontWeight.w800, AppColors.onSurface, lineHeight: 30);
  static final statLabel = AppText.plexSans(10.5, FontWeight.w700, AppColors.inkMuted, lineHeight: 14, spacing: 0.8);
  static final clock = AppText.workSans(16, FontWeight.w800, AppColors.primary, lineHeight: 20);
}
