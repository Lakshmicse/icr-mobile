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

  /// "Still learning" and a lock: the amber pair; "Got it" and open: the green pair.
  static const amberFill = AppColors.amber100;
  static const amberInk = AppColors.amber800;
  static const greenFill = AppColors.successTint;
  static const greenInk = AppColors.successInk;

  /// The star.
  static const star = Color(0xFFF5A524);

  // The study screen (flashcards-study.png, sampled).

  /// The title over two lines, and the card's question.
  static const title = Color(0xFF1E293B);
  static const question = AppColors.slate900;

  /// A category chip: soft grey at rest, the primary blue when lit.
  static const chipFill = AppColors.slate100;
  static const chipInk = AppColors.slate600;
  static const rule = AppColors.slate200;

  /// The card's star, filled amber with a darker edge.
  static const cardStar = Color(0xFFFBBF24);
  static const cardStarEdge = Color(0xFFF59E0B);

  /// The card's own hairline: it is lifted by its shadow, not outlined.
  static const cardEdge = Color(0xFFF1F4F8);

  /// The footer of the card: its dashed rule, the dot before the hint, the Flip Card pill.
  static const dash = Color(0xFFE9EDF3);
  static const dot = Color(0xFF2B7EC9);
  static const flipFill = Color(0xFFF0F6FC);

  /// The player bar: its glyphs, the circle behind Previous, the progress.
  static const playerInk = AppColors.slate500;
  static const prevInk = AppColors.slate700;
  static const prevBorder = Color(0xFFE8EDF4);
  static const progressFill = Color(0xFF004B83);

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

  // The flash card. The design's sizes (a 13.3 question, 10 for the footer) are snapped to the app's steps.
  static final question = AppText.workSans(13.3, FontWeight.w700, StudyColors.question, lineHeight: 19.5);
  static final answer = AppText.plexSans(13.3, FontWeight.w400, AppColors.slate700, lineHeight: 19.5);
  static final faceLabel = AppText.plexSans(10.5, FontWeight.w700, AppColors.primary, lineHeight: 14, spacing: 0.5);
  static final faceTag = AppText.plexSans(11, FontWeight.w600, AppColors.onSurfaceVariant, lineHeight: 14);
  static final footerHint = AppText.plexSans(10, FontWeight.w400, AppColors.slate500, lineHeight: 14);
  static final flipPill = AppText.plexSans(9.8, FontWeight.w600, AppColors.primary, lineHeight: 14);
  static final example = AppText.plexSans(13.3, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 19.5);

  // The study screen's bar, categories and player.
  static final barTitle = AppText.workSans(15.5, FontWeight.w700, StudyColors.title, lineHeight: 16);
  static final barSearch = AppText.plexSans(13.3, FontWeight.w500, AppColors.onSurface, lineHeight: 18);
  static final barSearchHint = AppText.plexSans(13.3, FontWeight.w500, AppColors.outline, lineHeight: 18);
  static final categories = AppText.workSans(14, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 18);
  static final chip = AppText.workSans(10.7, FontWeight.w500, StudyColors.chipInk, lineHeight: 14);
  static final cardWord = AppText.workSans(11.2, FontWeight.w700, AppColors.slate700, lineHeight: 14);
  static final cardNumber = AppText.workSans(11.2, FontWeight.w700, AppColors.primary, lineHeight: 14);
  static final cardTotal = AppText.workSans(11.2, FontWeight.w400, AppColors.slate400, lineHeight: 14);
  static final tally = AppText.plexSans(12, FontWeight.w500, AppColors.outline, lineHeight: 16);
  static final verdict = AppText.workSans(14, FontWeight.w700, AppColors.onSurface, lineHeight: 18);

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
