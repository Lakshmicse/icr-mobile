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

  static const stripBlankInk = Color(0xFF5B6472);
  static const greyTint = AppColors.surfaceContainer;

  // The brief, exam window, Test Results and Review Answers designs (30 Oct 2026), sampled from their PNGs.
  /// Take test, Next, Retake test, the option that is chosen, a heading in the explanation.
  static const action = Color(0xFF004B83);

  /// The ink of the small chips ("TEST ANALYSIS", "Core Topic").
  static const chipInk = Color(0xFF001C37);

  /// Finish, in the exam's bar.
  static const finishRed = Color(0xFFDC2626);

  /// The strip: answered, and the open question.
  static const questionDone = Color(0xFF10B981);
  static const questionOpen = AppColors.slate900;

  /// The edge of a card, an option and a pager button; the slate the rest of Learning uses.
  static const line = AppColors.slate200;

  /// Right and wrong in the review and on the result, with the tints they sit on.
  static const right = AppColors.tertiary;
  static const rightTint = Color(0xFFEBFCF3);
  static const wrong = AppColors.error;
  static const wrongTint = Color(0xFFFFF8F7);

  /// The chip that means "wrong", and the pale blue of "Correct" and of an unanswered number.
  static const wrongChip = AppColors.errorContainer;
  static const wrongChipInk = AppColors.onErrorContainer;
  static const paleBlue = Color(0xFFE7EEFF);

  /// The ring round the question on show in the review's strip.
  static const ring = Color(0xFFCBDAE5);

  /// What the chosen option is filled with.
  static const optionChosen = Color(0xFFF6FAFF);
}

/// Type for the exam screens, on the app's own steps (12, 13, 14, 16, 18, 22 sp: `AppText.sp`).
///
/// The v2 designs (30 Oct 2026) were sized by measuring a line of each against Roboto, the app's face: a step is
/// the largest whose line is no wider than the design's, so nothing draws bigger than the design does. A style
/// names the step and the design's own line pitch (dp).
class ExamText {
  ExamText._();

  /// A style on [step], with the line pitch the design has. `AppText.sp` snaps a size to its step, so the step is
  /// given back as the size that snaps to itself (12 is asked for as 11, 13 as 12.5).
  static TextStyle at(double step, FontWeight weight, Color color, {required double line, double spacing = 0}) {
    final raw = switch (step) {
      12 => 11.0,
      13 => 12.5,
      _ => step,
    };
    return AppText.plexSans(raw, weight, color, spacing: spacing).copyWith(height: line / step);
  }

  // Shared by the sheets, the dialogs and the certificate screens.
  static final heroTitle = AppText.workSans(22, FontWeight.w800, AppColors.onSurface, lineHeight: 28);
  static final heading = AppText.workSans(16, FontWeight.w700, AppColors.onSurface, lineHeight: 22);
  static final subheading = AppText.workSans(14, FontWeight.w700, AppColors.onSurface, lineHeight: 20);
  static final body = AppText.plexSans(14, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 21);
  static final bodyStrong = AppText.plexSans(14, FontWeight.w600, AppColors.onSurface, lineHeight: 21);
  static final small = AppText.plexSans(12, FontWeight.w500, AppColors.inkMuted, lineHeight: 17);
  static final eyebrow = AppText.plexSans(11, FontWeight.w700, AppColors.primary, lineHeight: 15, spacing: 0.8);
  static final button = AppText.workSans(14, FontWeight.w700, Colors.white, lineHeight: 18);
  static final buttonQuiet = AppText.workSans(14, FontWeight.w700, AppColors.onSurface, lineHeight: 18);
  static final link = AppText.plexSans(13, FontWeight.w600, AppColors.primary, lineHeight: 18);
  static final statNumber = AppText.workSans(22, FontWeight.w800, AppColors.onSurface, lineHeight: 30);
  static final statLabel = AppText.plexSans(10.5, FontWeight.w700, AppColors.inkMuted, lineHeight: 14, spacing: 0.8);

  // The title bar of the exam, the result and the review.
  static final barTitle = at(16, FontWeight.w700, ExamColors.ink, line: 24);

  // The brief.
  static final briefTitle = at(18, FontWeight.w700, ExamColors.ink, line: 24);
  static final briefHeading = at(16, FontWeight.w700, ExamColors.ink, line: 22);
  static final briefLine = at(13, FontWeight.w400, ExamColors.greyInk, line: 20);
  static final detailLabel = at(14, FontWeight.w500, ExamColors.greyInk, line: 20);
  static final detailValue = at(16, FontWeight.w700, ExamColors.ink, line: 22);
  static final attemptsCount = at(13, FontWeight.w400, ExamColors.greyMuted, line: 18);
  static final attemptNumber = at(13, FontWeight.w700, ExamColors.ink, line: 18);
  static final attemptDate = at(16, FontWeight.w400, ExamColors.ink, line: 22);
  static final figureLabel = at(13, FontWeight.w400, ExamColors.greyMuted, line: 16);
  static final figureValue = at(14, FontWeight.w700, ExamColors.ink, line: 20);

  // The exam window.
  static final timeLeft = at(12, FontWeight.w700, ExamColors.wrong, line: 16);
  static final stripNumber = at(12, FontWeight.w600, ExamColors.stripBlankInk, line: 16);
  static final examQuestionNumber = at(18, FontWeight.w700, ExamColors.ink, line: 24);
  static final difficulty = at(12, FontWeight.w500, ExamColors.greyMuted, line: 16, spacing: 0.4);
  static final examPrompt = at(16, FontWeight.w400, ExamColors.ink, line: 26);
  static final examOption = at(14, FontWeight.w400, ExamColors.ink, line: 19.5);
  static final barButton = at(14, FontWeight.w700, Colors.white, line: 20);

  // Test Results.
  static final tag = at(13, FontWeight.w600, ExamColors.chipInk, line: 16);
  static final resultHeadline = at(18, FontWeight.w700, ExamColors.ink, line: 28);
  static final resultSubline = at(14, FontWeight.w400, ExamColors.greyInk, line: 20);
  static final tileValue = at(18, FontWeight.w700, ExamColors.ink, line: 24);
  static final tileLabel = at(13, FontWeight.w400, ExamColors.greyMuted, line: 16);
  static final cardTitle = at(14, FontWeight.w600, ExamColors.ink, line: 20);

  // Review Answers.
  static final sectionTitle = at(16, FontWeight.w700, ExamColors.ink, line: 22);
  static final filterChip = at(13, FontWeight.w600, ExamColors.greyInk, line: 18);
  static final reviewNumber = at(12, FontWeight.w600, ExamColors.greyMuted, line: 16);
  static final reviewTag = at(12, FontWeight.w500, ExamColors.ink, line: 16);
  static final reviewOutcome = at(12, FontWeight.w600, ExamColors.ink, line: 16);
  static final reviewMarks = at(13, FontWeight.w500, ExamColors.greyMuted, line: 18);
  static final reviewQuestion = at(16, FontWeight.w600, ExamColors.ink, line: 24);
  static final reviewOption = at(14, FontWeight.w400, ExamColors.greyInk, line: 20);
  static final reviewLetter = at(14, FontWeight.w700, ExamColors.ink, line: 20);
  static final reviewMark = at(13, FontWeight.w600, ExamColors.right, line: 18);
  static final rationaleTitle = at(14, FontWeight.w700, ExamColors.action, line: 20);
  static final rationale = at(12, FontWeight.w400, ExamColors.greyInk, line: 18);
  static final topicPill = at(12, FontWeight.w600, ExamColors.chipInk, line: 16);
  static final pagerLabel = at(13, FontWeight.w600, ExamColors.greyInk, line: 18);
}
