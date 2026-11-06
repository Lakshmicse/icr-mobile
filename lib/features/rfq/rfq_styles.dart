import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';

/// Type for the requirements screens. There is no design for them: they take
/// the Marketplace and Supplier Overview designs' language (Work Sans names and
/// headings, IBM Plex Sans for the rest, slate ink, 12-radius cards).
class RfqText {
  RfqText._();

  static final kicker = AppText.plexSans(9.5, FontWeight.w600, AppColors.primary, lineHeight: 12, spacing: 0.5);
  static final cardTitle = AppText.workSans(13.5, FontWeight.w600, AppColors.slate900, lineHeight: 18);
  static final pageTitle = AppText.workSans(17, FontWeight.w700, AppColors.slate900, lineHeight: 22);
  static final section = AppText.workSans(14.5, FontWeight.w600, AppColors.slate900, lineHeight: 20);

  /// A requirement kind's name on the composer's two cards ("ENQUIRY", "RFQ"): the website's 18 px, extra bold, spaced.
  static final kindName = AppText.workSans(17, FontWeight.w800, AppColors.slate900, lineHeight: 22, spacing: 0.6);
  static final meta = AppText.plexSans(11, FontWeight.w500, AppColors.slate600, lineHeight: 15);
  static final metaStrong = AppText.plexSans(11, FontWeight.w600, AppColors.slate900, lineHeight: 15);
  static final body = AppText.plexSans(12, FontWeight.w400, AppColors.slate700, lineHeight: 18);
  static final bodyStrong = AppText.plexSans(12, FontWeight.w600, AppColors.slate900, lineHeight: 18);
  static final small = AppText.plexSans(10.5, FontWeight.w500, AppColors.slate500, lineHeight: 14);
  static final pill = AppText.plexSans(9.5, FontWeight.w600, AppColors.slate700, lineHeight: 12);
  static final amount = AppText.workSans(15, FontWeight.w700, AppColors.slate900, lineHeight: 20);
  static final figure = AppText.workSans(18, FontWeight.w700, AppColors.primary, lineHeight: 22);
  static final figureLabel = AppText.plexSans(10.5, FontWeight.w500, AppColors.slate600, lineHeight: 14);
  static final link = AppText.plexSans(11.5, FontWeight.w600, AppColors.primary, lineHeight: 15);
  static final tab = AppText.plexSans(12, FontWeight.w600, AppColors.slate700, lineHeight: 16);
  static final error = AppText.plexSans(11, FontWeight.w500, AppColors.error, lineHeight: 15);

  // Forms.
  static final formLabel = AppText.plexSans(12, FontWeight.w600, AppColors.slate900, lineHeight: 16);
  static final formHelp = AppText.plexSans(11, FontWeight.w400, AppColors.slate500, lineHeight: 15);
  static final formInput = AppText.plexSans(14, FontWeight.w400, AppColors.onSurface, lineHeight: 20);
  static final formHint = AppText.plexSans(14, FontWeight.w400, AppColors.slate400, lineHeight: 20);
  static final step = AppText.plexSans(10, FontWeight.w700, Colors.white, lineHeight: 12);
  static final sheetTitle = AppText.workSans(16, FontWeight.w700, AppColors.slate900, lineHeight: 22);
}

/// The cards' look: a pale slate tint, 12 radius, no frame.
const rfqCardDecoration = BoxDecoration(color: AppColors.slate50, borderRadius: BorderRadius.all(Radius.circular(12)));

/// The light panel behind a band of figures (the Overview's "PAN-INDIA" strip); a shade darker than the
/// card it often sits in.
const rfqPanelColor = AppColors.slate100;

/// A colour pair for a status pill.
class Tone {
  const Tone(this.fill, this.ink);

  final Color fill;
  final Color ink;

  static const slate = Tone(AppColors.slate100, AppColors.slate600);
  static const green = Tone(AppColors.emerald50, AppColors.emerald700);
  static const blue = Tone(AppColors.chipEmphasis, AppColors.primary);
  static const amber = Tone(AppColors.amber50, AppColors.amber800);
  static const red = Tone(AppColors.errorContainer, AppColors.onErrorContainer);
}
