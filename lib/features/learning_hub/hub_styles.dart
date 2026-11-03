import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';

/// Colours of the Learning hub design (`docs/designs/learning-hub-v2.png`, a 390-wide frame at 1x; the
/// earlier `docs/designs/hires/learning-centre.png` before it) that the shared palette lacks, plus the ones
/// the institute screens kept from the Events and Learning-grid card language.
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

  /// A grid card's edge (sampled #E9EAEB, 1 dp).
  static const cardEdge = Color(0xFFE9EAEB);

  /// A grid card's soft lift: the export's shadow reads 10% black at the foot, gone 5 dp under it.
  static const cardShadow = Color(0x1A000000);

  /// The first catalogue tile's lift, softer and wider than a card's (6% black, 5 dp to the side).
  static const tileShadow = Color(0x0F000000);

  /// The arrow disc's ring (sampled #E7E9E9, 1 dp).
  static const discRing = Color(0xFFE7E9E9);

  /// The arrow in a grid card's disc (pure black in the export).
  static const arrow = Color(0xFF000000);

  /// The share glyph on a photo (#111C2D) and the dark behind a flash-card tile.
  static const glyph = Color(0xFF111C2D);

  /// A flash-card tile's darkening, top to bottom, so the white words read.
  static const tileScrimTop = Color(0x33000000);
  static const tileScrimBottom = Color(0xA6000000);

  /// The Masterclasses banner: its fill, #EFF7FF at the left running to #EDF2FE at the right (the faces' own
  /// background follows the same run), its 1 dp edge, and "Know more" (a darker blue than the links, #154B7C).
  static const bannerFill = Color(0xFFEFF7FF);
  static const bannerFillEnd = Color(0xFFEDF2FE);
  static const bannerEdge = Color(0xFFDBEAFE);
  static const bannerLink = Color(0xFF154B7C);
}

/// Type for the hub, sized from the design by measured width (`fitfont.py`).
class HubText {
  HubText._();

  /// "Catalogue", "Assess Your Knowledge": Work Sans bold, 77 dp for "Catalogue", 183 for "Assess Your Knowledge".
  static final section = AppText.workSans(15.6, FontWeight.w700, AppColors.onSurface, lineHeight: 20);

  /// "View More", 72 dp wide.
  static final viewMore = AppText.plexSans(14.9, FontWeight.w600, HubColors.viewMore, lineHeight: 20);

  /// A catalogue tile's caption: "Assess your" 75 dp (Work Sans 12.7), 16 dp between its two lines.
  static final tileCaption = AppText.workSans(12.7, FontWeight.w600, AppColors.onSurfaceVariant, lineHeight: 16);

  /// A grid card's title: "Capital Planning" 103 dp, in ICR blue; two lines sit 14.7 dp apart in the export.
  static final cardTitle = AppText.workSans(12.7, FontWeight.w700, AppColors.primary, lineHeight: 14.7);

  /// The "ICR" tab on a certification card: 31 dp wide, 13 dp tall caps.
  static final badge = AppText.workSans(18.3, FontWeight.w700, AppColors.primary, lineHeight: 22);

  /// A flash-card tile: the deck's name (IBM Plex 13.9 bold, "HVAC Systems" 95 dp) and its count (10.8), in white.
  static final flashTitle = AppText.plexSans(13.9, FontWeight.w700, Colors.white, lineHeight: 18);
  static final flashCount = AppText.plexSans(10.8, FontWeight.w400, const Color(0xE6FFFFFF), lineHeight: 14);

  /// The Masterclasses banner: "Upskill with Masterclasses" 212 dp, the line under it 195 dp, "Know more ›" 86 dp.
  static final masterTitle = AppText.workSans(15.9, FontWeight.w700, AppColors.slate900, lineHeight: 20);
  static final masterAccent = AppText.workSans(15.9, FontWeight.w700, AppColors.primary, lineHeight: 20);
  static final masterBody = AppText.plexSans(11.9, FontWeight.w400, AppColors.slate600, lineHeight: 16);
  static final masterLink = AppText.plexSans(14.8, FontWeight.w500, HubColors.bannerLink, lineHeight: 20);

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
