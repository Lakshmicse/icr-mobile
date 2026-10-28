import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';

/// Colours of the Learning Centre design (`docs/designs/hires/learning-centre.png`,
/// a 390-wide frame at 4x) that the shared palette lacks, plus the ones the
/// institute screens kept from the Events and Learning-grid card language.
class HubColors {
  HubColors._();

  /// Link text and glyphs in the member tiles (the Events tile's "Manage & View").
  static const link = Color(0xFF0B4272);

  /// A card's and a tile's edge (the Events agenda's, 1 dp).
  static const border = Color(0xFFEDEDED);

  /// A skeleton bar.
  static const skeleton = AppColors.surfaceContainer;

  /// Behind an institute's logo.
  static const logoPlate = AppColors.surfaceContainerLow;

  // --- the design ---------------------------------------------------------------

  /// "View More" (sampled #334C65).
  static const viewMore = Color(0xFF334C65);

  /// The rules between the sections (#E1E3E4).
  static const rule = Color(0xFFE1E3E4);

  /// A grid card's edge: a soft grey, no shadow.
  static const cardEdge = Color(0xFFE6E8EA);

  /// The arrow disc's ring.
  static const discRing = Color(0xFFD9DCE0);

  /// The arrow and share glyphs.
  static const glyph = Color(0xFF1C2430);

  /// A flash-card tile's darkening, top to bottom, so the white words read.
  static const tileScrimTop = Color(0x33000000);
  static const tileScrimBottom = Color(0xA6000000);

  /// The Masterclasses banner.
  static const bannerFill = Color(0xFFEFF7FF);
  static const bannerEdge = Color(0xFFDBEAFE);
}

/// Type for the hub, sized from the design by measured width (`fitfont.py`).
class HubText {
  HubText._();

  /// "Catalogue", "Assess Your Knowledge": Work Sans bold, 77 dp for "Catalogue".
  static final section = AppText.workSans(15.6, FontWeight.w700, AppColors.onSurface, lineHeight: 20);

  /// "View More", 71.25 dp wide.
  static final viewMore = AppText.plexSans(14.5, FontWeight.w600, HubColors.viewMore, lineHeight: 20);

  /// A catalogue tile's caption: "Assess your" 69.75 dp.
  static final tileCaption = AppText.workSans(11.9, FontWeight.w700, AppColors.onSurfaceVariant, lineHeight: 14);

  /// A grid card's title: "Capital Planning" 111 dp, in ICR blue.
  static final cardTitle = AppText.workSans(13.8, FontWeight.w700, AppColors.primary, lineHeight: 18);

  /// The "ICR" badge on a certification card.
  static final badge = AppText.workSans(19, FontWeight.w700, AppColors.primary, lineHeight: 22);

  /// A flash-card tile: the deck's name and its count, in white.
  static final flashTitle = AppText.workSans(14.5, FontWeight.w700, Colors.white, lineHeight: 18);
  static final flashCount = AppText.plexSans(10.5, FontWeight.w400, const Color(0xE6FFFFFF), lineHeight: 14);

  /// The Masterclasses banner: "Upskill with Masterclasses" 212 dp, the line under it 195 dp, "Know more" 77 dp.
  static final masterTitle = AppText.workSans(15.9, FontWeight.w700, AppColors.onSurface, lineHeight: 20);
  static final masterAccent = AppText.workSans(15.9, FontWeight.w700, AppColors.primary, lineHeight: 20);
  static final masterBody = AppText.plexSans(11.9, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 16);
  static final masterLink = AppText.plexSans(14.8, FontWeight.w500, AppColors.primary, lineHeight: 20);

  // --- the institute screens (unchanged) -------------------------------------------
  static final doorTitle = AppText.workSans(13, FontWeight.w700, AppColors.onSurface, lineHeight: 17);
  static final doorBlurb = AppText.plexSans(10.5, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 15);
  static final doorCta = AppText.plexSans(10.5, FontWeight.w700, AppColors.primary, lineHeight: 14);
  static final tileLabel = AppText.workSans(9.4, FontWeight.w700, AppColors.onSurface, lineHeight: 13);
  static final tileCount = AppText.workSans(22, FontWeight.w700, AppColors.onSurface, lineHeight: 26);
  static final tileNote = AppText.plexSans(9, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 13);
  static final tileLink = AppText.plexSans(8.7, FontWeight.w600, HubColors.link, lineHeight: 13);
  static final instituteName = AppText.workSans(16, FontWeight.w700, AppColors.onSurface, lineHeight: 20);
  static final instituteBody = AppText.plexSans(12, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 18);
  static final instituteLink = AppText.plexSans(11.5, FontWeight.w600, AppColors.primary, lineHeight: 16);
  static final bannerTitle = AppText.workSans(13, FontWeight.w700, AppColors.onSurface, lineHeight: 17);
  static final bannerBody = AppText.plexSans(10.5, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 15);
}
