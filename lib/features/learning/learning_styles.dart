import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';

/// Colours sampled from the Course page design that `AppColors` lacks.
class LearningColors {
  LearningColors._();

  /// Paragraphs, lessons and the quote.
  static const bodyInk = Color(0xFF313741);
  static const tabInactive = Color(0xFF656A75);
  static const tabRule = Color(0xFFECF0F5);
  static const tileBorder = Color(0xFFE6EBF2);

  /// The selected tile: white, ringed in 2 dp of this grey (sampled from the design).
  static const tileSelectedBorder = Color(0xFFDCDFE0);
  static const panelBorder = Color(0xFFE8EDF3);
  static const chipBorder = Color(0xFFE6E7E8);

  /// The 2 dp rules between the sections.
  static const rule = Color(0xFFE4E4E4);
  static const stepLine = Color(0xFFDDE4EE);
  static const whatsapp = Color(0xFF00B071);
  static const whatsappBorder = Color(0xFF54CDA5);
  static const quoteMark = Color(0xFFC7D7E3);
  static const reviewerTile = AppColors.slate200;
  static const reviewerGlyph = Color(0xFF626771);

  /// Behind a cover that has not loaded, and the plate of a course with none.
  static const coverPlate = Color(0xFF334756);

  /// The frosted pill on the cover: white at 20 % over the blurred picture, with
  /// a lighter hairline (rgba(255,255,255,.2) over that), as the design's.
  static const pillFill = Color(0x33FFFFFF);
  static const pillBorder = Color(0x33FFFFFF);

  /// The same pill on a catalogue card: tinted navy instead of white, so it reads over the light
  /// covers some courses have (the sheet's cover is a dark photograph).
  static const pillCardFill = Color(0x99081422);

  /// The catalogue card's edge, as the Events agenda's cards (1 dp, no shadow).
  static const cardBorder = Color(0xFFEDEDED);

  /// The credits chip on a card.
  static const cpdFill = AppColors.chipEmphasis;
}

/// Type for the Learning screens, sized from the design by measured width.
class LearningText {
  LearningText._();

  // The catalogue cards (the Events agenda card's type: Work Sans 11.6 title, two lines).
  static final cardTitle = AppText.workSans(11.6, FontWeight.w700, AppColors.onSurface, lineHeight: 15);
  static final cardProvider = AppText.workSans(9.3, FontWeight.w600, AppColors.onSurfaceVariant, lineHeight: 14);
  static final cardMeta = AppText.plexSans(9.1, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 14);
  static final cardPrice = AppText.plexSans(11, FontWeight.w700, AppColors.primary, lineHeight: 14);
  static final cardPill = AppText.plexSans(9, FontWeight.w700, AppColors.successInk, lineHeight: 12);
  static final cardBadge = AppText.plexSans(7.4, FontWeight.w700, Colors.white, lineHeight: 10);
  static final cardInitials = AppText.workSans(
    26,
    FontWeight.w700,
    Colors.white.withValues(alpha: 0.72),
    lineHeight: 30,
  );

  // The course sheet: the top.
  static final title = AppText.workSans(16, FontWeight.w700, AppColors.onSurface, lineHeight: 20);
  static final subtitle = AppText.plexSans(10, FontWeight.w500, LearningColors.bodyInk, lineHeight: 14.5);
  static final badge = AppText.plexSans(8.6, FontWeight.w700, Colors.white, lineHeight: 12);
  static final tab = AppText.plexSans(9, FontWeight.w700, AppColors.primary, lineHeight: 12);
  static final tabInactive = AppText.plexSans(9, FontWeight.w700, LearningColors.tabInactive, lineHeight: 12);
  static final selectDate = AppText.workSans(12, FontWeight.w700, AppColors.onSurface, lineHeight: 16);
  static final schedule = AppText.plexSans(7.5, FontWeight.w700, AppColors.primary, lineHeight: 12);
  static final tileCity = AppText.workSans(11.5, FontWeight.w600, AppColors.slate900, lineHeight: 14);
  static final tileDate = AppText.plexSans(9.75, FontWeight.w600, AppColors.primary, lineHeight: 13);
  static final tileDateQuiet = AppText.plexSans(9.75, FontWeight.w600, LearningColors.bodyInk, lineHeight: 13);
  static final tileStatus = AppText.plexSans(9.7, FontWeight.w500, AppColors.inkMuted, lineHeight: 12);
  static final tileConfirmed = AppText.plexSans(10.2, FontWeight.w700, AppColors.tertiary, lineHeight: 12);
  static final tileHeld = AppText.plexSans(10.2, FontWeight.w700, AppColors.primary, lineHeight: 12);
  static final tileSuggest = AppText.plexSans(9.8, FontWeight.w600, AppColors.onSurface, lineHeight: 14.4);
  static final tileEmpty = AppText.plexSans(9.75, FontWeight.w500, AppColors.inkMuted, lineHeight: 14);
  static final seeMore = AppText.plexSans(11.5, FontWeight.w700, AppColors.primary, lineHeight: 14);
  static final primaryButton = AppText.plexSans(10.5, FontWeight.w700, Colors.white, lineHeight: 14);
  static final outlineButton = AppText.plexSans(9.8, FontWeight.w700, AppColors.onSurface, lineHeight: 14);

  // The sections.
  static final section = AppText.workSans(12, FontWeight.w700, AppColors.onSurface, lineHeight: 16);
  static final body = AppText.plexSans(10, FontWeight.w500, LearningColors.bodyInk, lineHeight: 18);
  static final showMore = AppText.plexSans(9, FontWeight.w600, AppColors.primary, lineHeight: 12);
  static final takeaway = AppText.plexSans(10, FontWeight.w500, LearningColors.bodyInk, lineHeight: 15);
  static final stepNumber = AppText.plexSans(11, FontWeight.w600, AppColors.primary, lineHeight: 14);
  static final outlineToggle = AppText.plexSans(11, FontWeight.w600, AppColors.onSurface, lineHeight: 14);
  static final moduleTitle = AppText.plexSans(10.5, FontWeight.w700, AppColors.onSurface, lineHeight: 14);
  static final lesson = AppText.plexSans(10, FontWeight.w500, LearningColors.bodyInk, lineHeight: 14);
  static final chip = AppText.plexSans(10, FontWeight.w500, AppColors.onSurface, lineHeight: 14);
  static final contactName = AppText.workSans(13.5, FontWeight.w700, AppColors.onSurface, lineHeight: 18);
  static final contactRole = AppText.plexSans(11, FontWeight.w600, AppColors.primary, lineHeight: 14);
  static final contactEmail = AppText.plexSans(10, FontWeight.w400, LearningColors.bodyInk, lineHeight: 14);
  static final whatsapp = AppText.plexSans(10, FontWeight.w600, LearningColors.whatsapp, lineHeight: 14);
  static final inHouse = AppText.plexSans(11, FontWeight.w700, Colors.white, lineHeight: 14);
  static final certificate = AppText.plexSans(10.2, FontWeight.w400, LearningColors.bodyInk, lineHeight: 15);
  static final quote = AppText.plexSans(
    10.2,
    FontWeight.w400,
    LearningColors.bodyInk,
    lineHeight: 19.4,
  ).copyWith(fontStyle: FontStyle.italic);
  static final quoteMark = AppText.workSans(
    20,
    FontWeight.w700,
    LearningColors.quoteMark,
    lineHeight: 24,
    spacing: -1.2,
  );
  static final reviewer = AppText.workSans(9.5, FontWeight.w700, AppColors.onSurface, lineHeight: 13);
  static final reviewerRole = AppText.plexSans(8, FontWeight.w400, AppColors.inkMuted, lineHeight: 12);
  static final barButton = AppText.workSans(12.1, FontWeight.w700, Colors.white, lineHeight: 16);

  // The enquiry form.
  static final formTitle = AppText.workSans(14, FontWeight.w700, AppColors.slate900, lineHeight: 20);
  static final formLabel = AppText.plexSans(11, FontWeight.w600, AppColors.onSurface, lineHeight: 16);
  static final formHelp = AppText.plexSans(11, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 16);
  static final formInput = AppText.plexSans(14, FontWeight.w400, AppColors.onSurface, lineHeight: 20);
}
