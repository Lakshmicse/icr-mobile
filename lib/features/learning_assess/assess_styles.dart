import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';

/// Colours of the Assess and Mock Exams screens: the app's own palette plus the
/// few the website's level cards use (one colour per rung).
class AssessColors {
  AssessColors._();

  /// A card's edge: the Learning catalogue's slate hairline.
  static const cardBorder = AppColors.slate200;

  /// The plate behind a cover that has not loaded or does not exist.
  static const plate = Color(0xFF334756);

  /// The banner's navy and the bundle offer's gradient (the website's).
  static const navy = Color(0xFF0B1F3A);
  static const navyMid = Color(0xFF173A6B);
  static const navyLight = Color(0xFF1F5FA6);
  static const gold = Color(0xFFFFD54A);
  static const goldInk = Color(0xFF5A3B00);

  /// The accent on the banner's second line: 7.4:1 on the navy.
  static const bannerAccent = Color(0xFF8FB8E8);

  static const statStrip = Color(0xFFF4F7FB);
  static const panelBorder = Color(0xFFE3E8F0);
  static const successWash = Color(0xFFEAF8F1);
  static const ribbon = Color(0xFFE8442E);

  /// One look per rung: the badge disc, the name, the button.
  static const foundation = RungLook(
    main: Color(0xFF1F5FA6),
    ink: Color(0xFF174A82),
    wash: Color(0x241F5FA6),
    tagline: 'Build Your Basics',
  );
  static const professional = RungLook(
    main: Color(0xFF0B1F3A),
    ink: Color(0xFF0B1F3A),
    wash: Color(0x1F0B1F3A),
    tagline: 'Prove your Expertise',
  );
  static const advanced = RungLook(
    main: Color(0xFF0B6B43),
    ink: Color(0xFF0B5E3B),
    wash: Color(0x240E8A55),
    tagline: 'Go Deeper',
  );

  // The programme page and the sets page (the owner's designs of 29 Oct 2026).

  /// The knowledge-area chips, in the design's three tints: two blues and a green.
  static const topicBlue = Color(0xFFE7EEFF);
  static const topicBlueDeep = Color(0xFFDEE8FF);
  static const topicGreen = Color(0xFFC2F7DC);
  static const topicGreenInk = Color(0xFF0C714D);
  static const topicGreenDot = Color(0xFF059669);

  /// A card's edge on the programme page, and its soft shadow.
  static const levelCardShadow = Color(0x14000000);

  /// The "01" tag, the faint numeral behind it, the stats box and the filled Start Test button of a set.
  static const setTag = Color(0xFFD2E4FF);
  static const setTagInk = Color(0xFF001C37);
  static const setNumeral = Color(0xFFDDE8F1);
  static const setAction = Color(0xFF004B83);

  /// The small square book beside a programme's name.
  static const programmeIcon = Color(0xFF58A6C2);

  static RungLook rung(String? level) => switch (level) {
    'INTERMEDIATE' => professional,
    'ADVANCED' => advanced,
    _ => foundation,
  };

  static const foundationCard = LevelLook(
    name: Color(0xFF154672),
    accent: Color(0xFF1D63A3),
    discLight: Color(0xFF237AC9),
    discDark: Color(0xFF1E66A8),
    icon: Symbols.school,
  );
  static const advancedCard = LevelLook(
    name: Color(0xFF027D57),
    accent: Color(0xFF006445),
    discLight: Color(0xFF048F64),
    discDark: Color(0xFF016D4B),
    icon: Symbols.bar_chart,
  );
  static const professionalCard = LevelLook(
    name: Color(0xFF154672),
    accent: Color(0xFF001F3F),
    discLight: Color(0xFF143C6E),
    discDark: Color(0xFF001F3F),
    icon: Symbols.star,
  );

  /// What a level card on a programme's page wears; a paper at no known level borrows the Foundation look.
  static LevelLook levelCard(String? level) => switch (level) {
    'INTERMEDIATE' => professionalCard,
    'ADVANCED' => advancedCard,
    _ => foundationCard,
  };
}

/// The look of one level card on a programme's page: the name, the tagline and its rule, the button, and the
/// round badge (a pale ring around a gradient disc with a white glyph).
class LevelLook {
  const LevelLook({
    required this.name,
    required this.accent,
    required this.discLight,
    required this.discDark,
    required this.icon,
  });

  /// The level's name over the card.
  final Color name;

  /// The tagline, the rule under it and the Start button.
  final Color accent;
  final Color discLight;
  final Color discDark;
  final IconData icon;

  /// The pale ring: the disc's colour at half strength.
  Color get ring => discDark.withValues(alpha: 0.5);
}

class RungLook {
  const RungLook({required this.main, required this.ink, required this.wash, required this.tagline});

  /// The name and the button.
  final Color main;

  /// The tagline and its rule.
  final Color ink;

  /// The pale ring around the badge.
  final Color wash;
  final String tagline;
}

/// Type for the screens, sized for a phone (body 13-16) rather than measured from a
/// 390 dp frame: there is no PNG for these screens.
class AssessText {
  AssessText._();

  // The banner.
  static final bannerEyebrow = AppText.workSans(13, FontWeight.w700, Colors.white, lineHeight: 18);
  static final bannerHeadline = AppText.workSans(22, FontWeight.w700, AssessColors.bannerAccent, lineHeight: 28);
  static final bannerBody = AppText.plexSans(13, FontWeight.w400, const Color(0xFFDCE7F5), lineHeight: 19);
  static final bannerStep = AppText.plexSans(11.5, FontWeight.w600, Colors.white, lineHeight: 16);

  // Headings.
  static final pageTitle = AppText.workSans(20, FontWeight.w700, AppColors.onSurface, lineHeight: 26);
  static final section = AppText.workSans(16, FontWeight.w700, AppColors.onSurface, lineHeight: 22);
  static final sectionHint = AppText.plexSans(13, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 19);

  // The grid cards.
  static final cardTitle = AppText.workSans(14, FontWeight.w700, AppColors.onSurface, lineHeight: 18);
  static final cardMeta = AppText.plexSans(12, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 16);
  static final cardPill = AppText.plexSans(11, FontWeight.w700, AppColors.successInk, lineHeight: 14);
  static final coverPill = AppText.plexSans(10, FontWeight.w700, Colors.white, lineHeight: 12);

  // The paper cards.
  static final rungName = AppText.workSans(18, FontWeight.w800, AppColors.onSurface, lineHeight: 22);
  static final tagline = AppText.plexSans(13, FontWeight.w500, AppColors.onSurface, lineHeight: 18);
  static final setLabel = AppText.plexSans(11, FontWeight.w800, AppColors.primary, lineHeight: 14, spacing: 1.2);
  static final setTitle = AppText.workSans(17, FontWeight.w800, AppColors.onSurface, lineHeight: 22);
  static final setBody = AppText.plexSans(13, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 19);
  static final statValue = AppText.workSans(15, FontWeight.w800, AppColors.onSurface, lineHeight: 20);
  static final statLabel = AppText.plexSans(11, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 14);
  static final chip = AppText.plexSans(11, FontWeight.w800, Colors.white, lineHeight: 14, spacing: 0.6);
  static final progressTitle = AppText.plexSans(13, FontWeight.w600, AppColors.onSurface, lineHeight: 18);
  static final progressNote = AppText.plexSans(12, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 16);
  static final panelBig = AppText.workSans(22, FontWeight.w800, AppColors.primary, lineHeight: 28);
  static final panelTitle = AppText.workSans(16, FontWeight.w700, AppColors.onSurface, lineHeight: 22);
  static final panelNote = AppText.plexSans(12.5, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 17);
  static final strike = AppText.plexSans(
    13,
    FontWeight.w500,
    AppColors.slate400,
    lineHeight: 18,
  ).copyWith(decoration: TextDecoration.lineThrough);
  static final save = AppText.plexSans(12.5, FontWeight.w700, const Color(0xFF0B6B43), lineHeight: 17);
  static final button = AppText.workSans(14, FontWeight.w700, Colors.white, lineHeight: 20);
  static final buttonOutline = AppText.workSans(14, FontWeight.w700, AppColors.primary, lineHeight: 20);
  static final buttonNote = AppText.plexSans(12, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 16);
  static final facts = AppText.plexSans(12, FontWeight.w500, AppColors.inkMuted, lineHeight: 16);

  // Notices.
  static final noticeTitle = AppText.workSans(15, FontWeight.w700, AppColors.onSurface, lineHeight: 20);
  static final noticeBody = AppText.plexSans(13, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 19);
  static final noteLink = AppText.plexSans(13, FontWeight.w600, AppColors.primary, lineHeight: 19);

  // The bundle offer.
  static final bundleKicker = AppText.plexSans(11, FontWeight.w800, Colors.white, lineHeight: 14, spacing: 1);
  static final bundleTitle = AppText.workSans(20, FontWeight.w800, Colors.white, lineHeight: 26);
  static final bundleBody = AppText.plexSans(13, FontWeight.w400, const Color(0xFFDCE7F5), lineHeight: 19);
  static final bundleChip = AppText.plexSans(12, FontWeight.w700, Colors.white, lineHeight: 16);

  // The programme page.
  static final programmeName = AppText.workSans(17.3, FontWeight.w700, AppColors.onSurface, lineHeight: 24);
  static final areasBlurb = AppText.plexSans(11.3, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 16);
  static final topicChip = AppText.plexSans(10.5, FontWeight.w500, AppColors.onSurface, lineHeight: 16);
  static final topicCount = AppText.plexSans(10.6, FontWeight.w700, AppColors.successInk, lineHeight: 16);
  static final levelName = AppText.workSans(16, FontWeight.w800, AppColors.onSurface, lineHeight: 20);
  static final levelTagline = AppText.plexSans(10.4, FontWeight.w500, AppColors.onSurface, lineHeight: 16);
  static final levelButton = AppText.workSans(11, FontWeight.w600, Colors.white, lineHeight: 16);
  static final levelNote = AppText.plexSans(10.5, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 16);
  static final levelNoteStrong = AppText.plexSans(10.5, FontWeight.w700, AppColors.onSurface, lineHeight: 16);

  // The sets page.
  static final examTitle = AppText.workSans(22, FontWeight.w700, AppColors.onSurface, lineHeight: 28);
  // The design's lines are 22 dp apart (1.57 of the type); the kit's own cap on line height is 1.4.
  static final examSub = AppText.plexSans(
    13.7,
    FontWeight.w400,
    AppColors.onSurfaceVariant,
    lineHeight: 22,
  ).copyWith(height: 1.57);
  static final setTag = AppText.plexSans(10.5, FontWeight.w700, AssessColors.setTagInk, lineHeight: 14);
  static final setName = AppText.workSans(16.1, FontWeight.w700, AppColors.onSurface, lineHeight: 22);
  static final setDesc = AppText.plexSans(12.4, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 18);
  static final setStatValue = AppText.plexSans(12.1, FontWeight.w700, AppColors.onSurface, lineHeight: 18);
  static final setStatLabel = AppText.plexSans(10, FontWeight.w500, AppColors.outline, lineHeight: 16);
  static final setButton = AppText.workSans(13, FontWeight.w700, Colors.white, lineHeight: 18);
  static final setNumeral = AppText.workSans(60, FontWeight.w400, AssessColors.setNumeral, lineHeight: 60);

  // What opening a closed paper takes, set small for a card 127 dp wide.
  static final priceBig = AppText.workSans(16, FontWeight.w800, AppColors.primary, lineHeight: 22);
  static final strikeSmall = AppText.plexSans(
    11,
    FontWeight.w500,
    AppColors.slate400,
    lineHeight: 16,
  ).copyWith(decoration: TextDecoration.lineThrough);
  static final saveSmall = AppText.plexSans(11, FontWeight.w700, const Color(0xFF0B6B43), lineHeight: 16);
}
