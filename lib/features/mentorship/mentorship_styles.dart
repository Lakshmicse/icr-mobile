import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';

/// Colours sampled from the Mentorship designs that `AppColors` lacks.
class MentorshipColors {
  MentorshipColors._();

  /// The small grey text under a heading ("Learn from top leaders…").
  static const hint = AppColors.outline;

  /// A mentor's role line.
  static const role = AppColors.outline;

  /// The chips on a mentor card.
  static const expertiseChip = Color(0xFFF1F4F9);

  /// A card's and an outlined chip's edge.
  static const cardBorder = Color(0xFFE1E1E1);
  static const chipBorder = Color(0xFFEEEEEE);
  static const tileBorder = Color(0xFFF2F3F5);

  /// The "8+ Domains" pill.
  static const domainsPill = Color(0xFFD0E5FF);

  /// The "Become an ICR Mentor" band, top to bottom.
  static const bannerStart = Color(0xFF2F4F6F);
  static const bannerEnd = Color(0xFF2E6995);
  static const bannerInk = Color(0xFF1E3A5F);

  /// Behind the cohort card.
  static const cohortStart = Color(0xFFEFEDEB);
  static const cohortEnd = Color(0xFFDAD6D3);
  static const liveDot = AppColors.error;

  /// Laid over the programme's cover so it reads as the design's washed-out photo.
  static const cohortWash = Color(0xCCEFEDEB);

  /// Topic chips the design tints, and the one that is on.
  static const topicBlue = Color(0xFF4F7FAA);
  static const topicRed = Color(0xFFD04A4A);
  static const topicOn = Color(0xFFF3F3F3);

  /// The load-more progress track.
  static const track = Color(0xFFE2E3E5);
  static const panelBorder = Color(0xFFF0F0F0);

  /// The green pill of the free diagnostic call.
  static const pillGreenInk = Color(0xFF015C33);

  /// The "View More" links: the design's slate grey, a shade less blue than the
  /// Jobs screen's.
  static const viewMore = AppColors.slate600;

  /// Wordmarks in the company tiles (ARGB ints), sampled from the design: its
  /// near-black for most employers, a deep red for JLL and a steel blue for CBRE.
  static const wordmarkInk = 0xFF111C2D;
  static const wordmarkRed = 0xFFBA1A1A;
  static const wordmarkBlue = 0xFF1D63A3;

  /// Ready-made profile covers (the website's `PROFILE_COVERS` bands).
  static const covers = <String, List<Color>>{
    'blueprint': [Color(0xFF0F2A4A), Color(0xFF13426D)],
    'skyline': [Color(0xFF1B2D57), Color(0xFF7A4C7E), Color(0xFFF2A65A)],
    'campus': [Color(0xFFBFE0F5), Color(0xFFEAF4FA)],
    'brand': [Color(0xFF13426D), Color(0xFF32629E), Color(0xFF2EB3FC)],
    'teal': [Color(0xFF2FA8BE), Color(0xFF3B2A78)],
    'waves': [Color(0xFFF08A3C), Color(0xFF8E2DE2)],
    'marble': [Color(0xFFA9C6F5), Color(0xFF5B6FE0)],
    'ink': [Color(0xFF0B4F6C), Color(0xFFE2582B)],
  };
  static const coverFallback = [Color(0xFF13426D), Color(0xFF1D63A3)];
}

/// Type for the Mentorship screens, sized from the designs by measured width.
class MentorshipText {
  MentorshipText._();

  // Headings.
  static final heading = AppText.workSans(15.95, FontWeight.w700, AppColors.onSurface, lineHeight: 20);
  static final headingAction = AppText.workSans(14.1, FontWeight.w600, MentorshipColors.viewMore, lineHeight: 20);
  static final matches = AppText.plexSans(10.4, FontWeight.w600, AppColors.onSurfaceVariant, lineHeight: 14);
  static final lead = AppText.plexSans(12.2, FontWeight.w600, MentorshipColors.hint, lineHeight: 18, spacing: 0.57);
  static final domainsPill = AppText.plexSans(11.5, FontWeight.w600, AppColors.primary, lineHeight: 14);

  // Chips.
  static TextStyle categoryChip({required bool selected, double size = 12.6}) =>
      AppText.plexSans(size, FontWeight.w600, selected ? Colors.white : AppColors.onSurfaceVariant, lineHeight: 16);
  static final filterChip = AppText.plexSans(12.2, FontWeight.w600, AppColors.onSurface, lineHeight: 16);
  static final filterPrefix = AppText.plexSans(10, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 16);
  static TextStyle topicChip(Color color) => AppText.plexSans(10.9, FontWeight.w600, color, lineHeight: 14);

  // The mentor card.
  static final mentorName = AppText.workSans(13.8, FontWeight.w700, AppColors.onSurface, lineHeight: 17.3);
  static final mentorRole = AppText.plexSans(12.4, FontWeight.w600, MentorshipColors.role, lineHeight: 16.5);
  static final expertise = AppText.plexSans(10.9, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 13);

  // Company tiles.
  static final wordmark = AppText.workSans(12.4, FontWeight.w700, AppColors.onSurface, lineHeight: 16);

  // The banner and the cohort card.
  static final bannerTitle = AppText.workSans(15.9, FontWeight.w700, Colors.white, lineHeight: 18);
  static final bannerBody = AppText.plexSans(12.2, FontWeight.w400, const Color(0xFFE4EEF9), lineHeight: 15);
  static final bannerButton = AppText.plexSans(12.7, FontWeight.w600, MentorshipColors.bannerInk, lineHeight: 16);
  static final cohortKicker = AppText.plexSans(11.13, FontWeight.w700, AppColors.onSurface, lineHeight: 14, spacing: 0.4);
  static final cohortTitle = AppText.workSans(14, FontWeight.w700, AppColors.onSurface, lineHeight: 17);
  static final cohortButton = AppText.plexSans(12.3, FontWeight.w700, AppColors.primary, lineHeight: 16);
  static final cohortMeta = AppText.plexSans(11.9, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 16);
  static final cohortInitials = AppText.plexSans(6.5, FontWeight.w700, Colors.white, lineHeight: 9);

  // Session cards.
  static final pill = AppText.plexSans(11, FontWeight.w700, AppColors.onSurface, lineHeight: 14);
  static final pillFeatured = AppText.plexSans(11, FontWeight.w700, MentorshipColors.pillGreenInk, lineHeight: 14);
  static final serviceTitle = AppText.workSans(16, FontWeight.w700, AppColors.onSurface, lineHeight: 20);
  static final serviceBody = AppText.plexSans(13.4, FontWeight.w400, AppColors.inkMuted, lineHeight: 15);
  static final serviceButton = AppText.plexSans(13.4, FontWeight.w600, Colors.white, lineHeight: 16);
  static final serviceButtonOutlined = AppText.plexSans(13.4, FontWeight.w600, AppColors.onSurface, lineHeight: 16);

  // Find Mentors' foot.
  static final showing = AppText.plexSans(12.6, FontWeight.w600, AppColors.onSurfaceVariant, lineHeight: 16);
  static final loadMore = AppText.plexSans(12, FontWeight.w600, AppColors.onSurface, lineHeight: 16);

  // Sheets and notices.
  static final formTitle = AppText.workSans(14, FontWeight.w700, AppColors.slate900, lineHeight: 20);
  static final formLabel = AppText.plexSans(11, FontWeight.w600, AppColors.onSurface, lineHeight: 16);
  static final option = AppText.plexSans(14, FontWeight.w400, AppColors.onSurface, lineHeight: 20);
}

/// The wordmark colour of an employer's tile. The design colours JLL red and
/// CBRE blue and sets every other name in ink; the API has no brand colours,
/// so this small palette is keyed by the company's name.
class MentorshipBrand {
  MentorshipBrand._();

  static const ink = Color(MentorshipColors.wordmarkInk);
  static const jll = Color(MentorshipColors.wordmarkRed);
  static const cbre = Color(MentorshipColors.wordmarkBlue);

  /// Names a palette entry answers to, matched on whole words of the lowered,
  /// punctuation-free name ("JLL India" is JLL, "Jollibee" is not).
  static final _palette = <RegExp, Color>{
    RegExp(r'\bjll\b|\bjones lang lasalle\b'): jll,
    RegExp(r'\bcbre\b|\bcb richard ellis\b'): cbre,
  };

  static Color wordmark(String company) {
    final name = company.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
    for (final entry in _palette.entries) {
      if (entry.key.hasMatch(name)) return entry.value;
    }
    return ink;
  }
}
