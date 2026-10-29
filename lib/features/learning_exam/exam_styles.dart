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

  // The Test Results and Mock Test designs (Oct 2026).
  static const ink = AppColors.onSurface;
  static const hairline = AppColors.outlineVariant;
  static const greyInk = AppColors.onSurfaceVariant;
  static const greyMuted = AppColors.outline;

  /// The deep navy of a filled "current" square.
  static const current = Color(0xFF0F2F55);
  static const green = Color(0xFF0E9F6E);
  static const red = Color(0xFFC62828);

  /// The exam's Finish button, and the answered square in its number strip.
  static const finish = Color(0xFFE12D39);
  static const stripAnswered = Color(0xFF1DAE7A);
  static const stripBlank = Color(0xFFEEF1F4);
  static const stripBlankInk = Color(0xFF5B6472);

  static const blueTint = Color(0xFFE8F0FA);
  static const redTint = Color(0xFFFDECEC);
  static const greenTint = Color(0xFFE8F7F0);
  static const greyTint = AppColors.surfaceContainer;
  static const chosenFill = Color(0xFFF3F7FC);
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

  // Test Results.
  static final barTitle = AppText.workSans(18, FontWeight.w700, ExamColors.ink, lineHeight: 24);
  static final resultHeadline = AppText.workSans(26, FontWeight.w700, ExamColors.ink, lineHeight: 32);
  static final resultSubline = AppText.plexSans(13, FontWeight.w400, ExamColors.greyMuted, lineHeight: 19);
  static final tag = AppText.plexSans(12, FontWeight.w600, AppColors.primary, lineHeight: 16, spacing: 0.5);
  static final tileValue = AppText.workSans(22, FontWeight.w700, ExamColors.ink, lineHeight: 28);
  static final tileLabel = AppText.plexSans(12, FontWeight.w400, ExamColors.greyMuted, lineHeight: 16);
  static final sectionTitle = AppText.workSans(17, FontWeight.w700, ExamColors.ink, lineHeight: 24);
  static final cardTitle = AppText.plexSans(15, FontWeight.w600, ExamColors.ink, lineHeight: 20);
  static final reviewQuestion = AppText.plexSans(16, FontWeight.w600, ExamColors.ink, lineHeight: 22.4);
  static final reviewOption = AppText.plexSans(15, FontWeight.w400, ExamColors.greyInk, lineHeight: 21);
  static final reviewLetter = AppText.workSans(15, FontWeight.w700, ExamColors.greyInk, lineHeight: 21);
  static final reviewMark = AppText.plexSans(13, FontWeight.w600, ExamColors.green, lineHeight: 18);
  static final rationaleTitle = AppText.workSans(15, FontWeight.w700, AppColors.primary, lineHeight: 20);
  static final rationale = AppText.plexSans(13, FontWeight.w400, ExamColors.greyInk, lineHeight: 19.5);
  static final topicPill = AppText.plexSans(12, FontWeight.w600, ExamColors.ink, lineHeight: 16);
  static final pagerLabel = AppText.plexSans(12, FontWeight.w400, ExamColors.greyMuted, lineHeight: 16);
  static final attemptNumber = AppText.workSans(15, FontWeight.w700, ExamColors.ink, lineHeight: 20);
  static final attemptDate = AppText.plexSans(15, FontWeight.w500, ExamColors.ink, lineHeight: 20);
  static final summaryValue = AppText.workSans(14, FontWeight.w700, ExamColors.ink, lineHeight: 20);

  // Mock Test.
  static final examTitle = AppText.workSans(20, FontWeight.w700, ExamColors.ink, lineHeight: 26);
  static final timeLeft = AppText.plexSans(13, FontWeight.w700, ExamColors.red, lineHeight: 18);
  static final stripNumber = AppText.workSans(15, FontWeight.w700, ExamColors.stripBlankInk, lineHeight: 20);
  static final examQuestionNumber = AppText.workSans(22, FontWeight.w700, ExamColors.ink, lineHeight: 28);
  static final difficulty = AppText.plexSans(12, FontWeight.w500, ExamColors.greyMuted, lineHeight: 16, spacing: 0.6);
  static final examPrompt = AppText.plexSans(18, FontWeight.w400, ExamColors.ink, lineHeight: 26);
  static final examOption = AppText.plexSans(16, FontWeight.w400, ExamColors.ink, lineHeight: 22.4);
  static final barButton = AppText.workSans(14, FontWeight.w700, Colors.white, lineHeight: 18);
}
