import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';

/// Colours of the study screens: the app's slate palette on white cards, as the Learning catalogue grid.
class StudyColors {
  StudyColors._();

  /// Behind the study screen, so the white card lifts off it.
  static const page = AppColors.slate50;
  static const border = AppColors.slate200;
  static const shadow = Color(0x140F172A);

  /// The strip along the foot of a flash card: quiet on the question, solid blue on the answer.
  static const frontBand = AppColors.slate100;
  static const backBand = AppColors.primary;

  /// "Still learning" and a lock: the amber pair; "Got it" and open: the green pair.
  static const amberFill = AppColors.amber100;
  static const amberInk = AppColors.amber800;
  static const greenFill = AppColors.successTint;
  static const greenInk = AppColors.successInk;

  /// The star.
  static const star = Color(0xFFF5A524);

  /// A formula's plate: the accent at 6 %.
  static const formulaPlate = Color(0x0F1D63A3);
  static const formulaPlateBorder = Color(0x2E1D63A3);

  /// Cover plate while a picture loads.
  static const coverPlate = AppColors.slate200;
}

/// Type of the study screens.
class StudyText {
  StudyText._();

  // The deck grid.
  static final deckTitle = AppText.workSans(13.5, FontWeight.w700, AppColors.onSurface, lineHeight: 18);
  static final deckMeta = AppText.plexSans(11.5, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 16);
  static final coverPill = AppText.plexSans(10, FontWeight.w700, Colors.white, lineHeight: 12, spacing: 0.3);
  static final cta = AppText.plexSans(12, FontWeight.w600, AppColors.primary, lineHeight: 16);
  static final pill = AppText.plexSans(11, FontWeight.w700, AppColors.successInk, lineHeight: 14);
  static final note = AppText.plexSans(12.5, FontWeight.w500, AppColors.slate700, lineHeight: 18);
  static final noteLink = AppText.plexSans(12.5, FontWeight.w700, AppColors.primary, lineHeight: 18);

  // The flash card.
  static final front = AppText.workSans(22, FontWeight.w700, AppColors.onSurface, lineHeight: 30);
  static final back = AppText.plexSans(17, FontWeight.w400, AppColors.onSurface, lineHeight: 26);
  static final faceLabel = AppText.plexSans(10.5, FontWeight.w700, AppColors.primary, lineHeight: 14, spacing: 0.5);
  static final faceTag = AppText.plexSans(11, FontWeight.w600, AppColors.onSurfaceVariant, lineHeight: 14);
  static final band = AppText.plexSans(13, FontWeight.w600, AppColors.slate600, lineHeight: 16);
  static final bandOnBlue = AppText.plexSans(13, FontWeight.w600, Colors.white, lineHeight: 16);
  static final example = AppText.plexSans(14, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 21);

  // The study screen.
  static final position = AppText.workSans(15, FontWeight.w700, AppColors.onSurface, lineHeight: 20);
  static final progressNote = AppText.plexSans(12, FontWeight.w500, AppColors.outline, lineHeight: 16);
  static final verdict = AppText.workSans(14, FontWeight.w700, AppColors.onSurface, lineHeight: 18);
  static final hint = AppText.plexSans(12.5, FontWeight.w500, AppColors.outline, lineHeight: 18);

  // The summary.
  static final summaryTitle = AppText.workSans(22, FontWeight.w700, AppColors.onSurface, lineHeight: 28);
  static final summaryLead = AppText.plexSans(14.5, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 21);
  static final statValue = AppText.workSans(24, FontWeight.w700, AppColors.onSurface, lineHeight: 28);
  static final statLabel = AppText.plexSans(11.5, FontWeight.w600, AppColors.onSurfaceVariant, lineHeight: 15);

  // The Knowledge Center.
  static final shelfTitle = AppText.workSans(14, FontWeight.w700, AppColors.onSurface, lineHeight: 18);
  static final shelfCount = AppText.plexSans(11.5, FontWeight.w500, AppColors.outline, lineHeight: 16);
  static final formulaName = AppText.workSans(14, FontWeight.w700, AppColors.onSurface, lineHeight: 19);
  static final formulaNumber = AppText.workSans(13, FontWeight.w700, AppColors.primary, lineHeight: 16);
  static final formulaPeek = AppText.plexSans(11.5, FontWeight.w500, AppColors.outline, lineHeight: 15);

  // The formula sheet.
  static final sheetTitle = AppText.workSans(20, FontWeight.w700, AppColors.onSurface, lineHeight: 26);
  static final blockTitle = AppText.workSans(15, FontWeight.w700, AppColors.onSurface, lineHeight: 20);
  static final body = AppText.plexSans(14, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 21);
  static final bodyStrong = AppText.plexSans(14, FontWeight.w600, AppColors.onSurface, lineHeight: 20);
  static final symbol = AppText.workSans(13, FontWeight.w700, AppColors.primary, lineHeight: 16);

  /// A formula's working and the plain-text fallback: a line of figures, not code, so the app's own face with
  /// tabular figures (no monospace family: Android has one, iOS names it differently).
  static final mono = AppText.plexSans(
    14.5,
    FontWeight.w500,
    AppColors.onSurface,
    lineHeight: 23,
  ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
  static final resultLabel = AppText.plexSans(12, FontWeight.w700, AppColors.primary, lineHeight: 16);
  static final result = AppText.workSans(16, FontWeight.w700, AppColors.onSurface, lineHeight: 22);
  static final decisionLabel = AppText.plexSans(12, FontWeight.w700, AppColors.successInk, lineHeight: 16);
}
