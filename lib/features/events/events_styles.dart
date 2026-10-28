import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';

/// Colours sampled from the Events designs that the shared palette lacks.
class EventsColors {
  EventsColors._();

  /// The "SPOTLIGHT EVENT" pill.
  static const navyPill = Color(0xFF00467A);

  /// Link text and icons (Manage & View, Overview, View Network, Show Pass, the session times, the clock and
  /// pin): a dark navy in the designs, darker than the primary blue that fills the buttons, chips and dots.
  /// Sampled from the strokes of those texts, whose cores measure about (21, 71, 116) once blurred.
  static const link = Color(0xFF0B4272);

  /// The "15 CPD CREDITS" pill over the spotlight photo.
  static const stonePill = Color(0xFFDCD7D3);

  /// "FLAGSHIP GLOBAL GATHERING" and the hero's small words.
  static const onPhotoSoft = Color(0xFFC9D4E4);

  /// "LIVE VIRTUAL".
  static const mintPill = Color(0xFF8FE1BD);
  static const mintInk = Color(0xFF0C714D);

  /// "CLOSED-DOOR".
  static const rosePill = Color(0xFFFFD8D9);

  /// The "4 Ready" pill.
  static const readyPill = Color(0xFFE9F0FF);
  static const readyInk = Color(0xFF30343F);

  /// Card and tile borders.
  static const border = Color(0xFFEDEDED);
  static const borderSoft = Color(0xFFF1F3F5);

  /// The CPD progress bar.
  static const progressFill = Color(0xFF005C3C);
  static const progressTrack = Color(0xFFE1E2E4);

  /// The light grey tiles and panels (category icon boxes, the pass card).
  static const panel = Color(0xFFF3F4F6);

  /// The sheet's status pill.
  static const confirmedPill = Color(0xFFA5F3CB);
  static const confirmedInk = Color(0xFF045E39);

  /// The sheet's CPD pill.
  static const cpdPill = Color(0xFFF0F2FF);

  /// The hero's kind chip over the photo.
  static const heroChip = Color(0xD90F172A);

  /// The pass card's date badge.
  static const badgeRed = Color(0xFFEE4444);

  /// "Active Pass".
  static const activePill = Color(0xFF97F5C8);
  static const activeInk = Color(0xFF00532E);

  /// Attendee circles.
  static const avatarBlue = Color(0xFF2061A1);
  static const avatarGreen = Color(0xFF006D4A);
  static const avatarSlate = Color(0xFF3A3F4C);
  static const avatarLavender = Color(0xFFDEE9FF);
  static const avatarMint = Color(0xFFB7F0D0);

  /// The highlight cards' tick.
  static const checkCircle = Color(0xFF9CF2C3);

  /// The timeline's rail.
  static const rail = Color(0xFFE5E8EC);

  /// "KEYNOTE".
  static const keynotePill = Color(0xFFECEEF1);

  /// "PANEL".
  static const panelPill = Color(0xFF9DF4C9);
}

/// Type for the Events screens, sized from the designs by measured width.
class EventsText {
  EventsText._();

  // The header.
  static final title = AppText.workSans(15.7, FontWeight.w700, AppColors.onSurface, lineHeight: 20);
  static final searchHint = AppText.plexSans(10.8, FontWeight.w600, AppColors.outline, lineHeight: 15);
  static final searchInput = AppText.plexSans(10.8, FontWeight.w500, AppColors.onSurface, lineHeight: 15);

  // The spotlight.
  static final spotlightPill = AppText.plexSans(8.6, FontWeight.w700, Colors.white, lineHeight: 11);
  static final cpdPill = AppText.plexSans(8, FontWeight.w700, AppColors.onSurface, lineHeight: 11);
  static final badgeMonth = AppText.plexSans(9.5, FontWeight.w700, Colors.white, lineHeight: 12, spacing: 0.5);
  static final badgeDay = AppText.plexSans(16, FontWeight.w700, AppColors.onSurface, lineHeight: 20);
  static final kicker = AppText.plexSans(8, FontWeight.w600, EventsColors.onPhotoSoft, lineHeight: 11, spacing: 0.95);
  static final spotlightTitle = AppText.workSans(12.5, FontWeight.w700, Colors.white, lineHeight: 18);
  static final venue = AppText.plexSans(9, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 13);
  static final badgeLine = AppText.plexSans(9, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 13);
  static final attendees = AppText.plexSans(9, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 13);
  static final rsvpButton = AppText.workSans(10, FontWeight.w700, Colors.white, lineHeight: 14);
  static final avatarInitials = AppText.plexSans(8, FontWeight.w700, Colors.white, lineHeight: 10);

  // The two tiles.
  static final tileTitle = AppText.workSans(9.4, FontWeight.w700, AppColors.onSurface, lineHeight: 13);
  static final tileBody = AppText.plexSans(9, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 13);
  static final tileLink = AppText.plexSans(8.7, FontWeight.w600, EventsColors.link, lineHeight: 13);
  static final cpdValue = AppText.plexSans(8.9, FontWeight.w700, AppColors.tertiary, lineHeight: 13);
  static final cpdNote = AppText.plexSans(8, FontWeight.w400, AppColors.outline, lineHeight: 12);

  // Section headings.
  static final heading = AppText.workSans(11.7, FontWeight.w700, AppColors.onSurface, lineHeight: 16);
  static final headingAside = AppText.plexSans(9, FontWeight.w500, AppColors.outline, lineHeight: 13);
  static final readyPill = AppText.plexSans(7.6, FontWeight.w600, EventsColors.readyInk, lineHeight: 11);
  static final trackTitle = AppText.workSans(9.8, FontWeight.w700, AppColors.onSurface, lineHeight: 13);
  static final trackCount = AppText.plexSans(8, FontWeight.w400, AppColors.outline, lineHeight: 12);

  // Event cards.
  static final tag = AppText.plexSans(7.9, FontWeight.w700, AppColors.onSurface, lineHeight: 11);
  static final dateLine = AppText.plexSans(8.9, FontWeight.w600, Colors.white, lineHeight: 13);
  static final cardTitle = AppText.workSans(11.6, FontWeight.w700, AppColors.onSurface, lineHeight: 15);
  static final cardSpeaker = AppText.plexSans(10.3, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 18);
  static final cardVenue = AppText.plexSans(9.1, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 15);
  static final footerButton = AppText.plexSans(9.8, FontWeight.w600, AppColors.onSurface, lineHeight: 14);
  static final footerNote = AppText.plexSans(8.1, FontWeight.w500, AppColors.outline, lineHeight: 12);
  static final footerNoteGreen = AppText.plexSans(8, FontWeight.w600, EventsColors.mintInk, lineHeight: 12);
  static final footerCaps = AppText.plexSans(7.5, FontWeight.w600, AppColors.outline, lineHeight: 12, spacing: 0.7);
  static final footerDetails = AppText.plexSans(9.1, FontWeight.w600, AppColors.onSurfaceVariant, lineHeight: 13);

  // Host card.
  static final hostTitle = AppText.workSans(9.5, FontWeight.w700, AppColors.onSurface, lineHeight: 13);
  static final hostBody = AppText.plexSans(8, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 12);
  static final hostButton = AppText.workSans(9.5, FontWeight.w700, EventsColors.link, lineHeight: 13);

  // The sheet.
  static final statusPill = AppText.plexSans(8.5, FontWeight.w700, EventsColors.confirmedInk, lineHeight: 12);
  static final sheetCpdPill = AppText.plexSans(8.5, FontWeight.w700, EventsColors.link, lineHeight: 12);
  static final heroChip = AppText.plexSans(7.8, FontWeight.w700, Colors.white, lineHeight: 12, spacing: 0.55);
  static final heroAside = AppText.plexSans(7.8, FontWeight.w600, AppColors.slate300, lineHeight: 12, spacing: 0.55);
  static final heroKicker = AppText.plexSans(
    8.1,
    FontWeight.w600,
    EventsColors.onPhotoSoft,
    lineHeight: 12,
    spacing: 1.1,
  );
  static final heroTitle = AppText.workSans(14.3, FontWeight.w700, Colors.white, lineHeight: 18);
  static final heroOrganiser = AppText.plexSans(9.7, FontWeight.w400, AppColors.slate300, lineHeight: 13);
  static final passMonth = AppText.plexSans(9.5, FontWeight.w700, Colors.white, lineHeight: 12, spacing: 0.5);
  static final passDay = AppText.workSans(23, FontWeight.w700, AppColors.onSurface, lineHeight: 26);
  static final passTitle = AppText.workSans(9.7, FontWeight.w700, AppColors.onSurface, lineHeight: 13);
  static final activePill = AppText.plexSans(8, FontWeight.w700, EventsColors.activeInk, lineHeight: 11);
  static final passHolder = AppText.plexSans(8.1, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 12);
  static final passButton = AppText.plexSans(9.5, FontWeight.w700, EventsColors.link, lineHeight: 13);
  static final panelStrong = AppText.plexSans(9.9, FontWeight.w700, AppColors.onSurface, lineHeight: 14);
  static final panelSoft = AppText.plexSans(9.8, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 14);
  static final synced = AppText.plexSans(8.8, FontWeight.w700, EventsColors.activeInk, lineHeight: 12);
  static final attendeesTitle = AppText.workSans(10.5, FontWeight.w700, AppColors.onSurface, lineHeight: 14);
  static final attendeesNote = AppText.plexSans(9.1, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 12);
  static final sheetLink = AppText.plexSans(10, FontWeight.w700, EventsColors.link, lineHeight: 13);
  static final sheetAvatar = AppText.plexSans(8, FontWeight.w700, Colors.white, lineHeight: 10);
  static final sheetAvatarCount = AppText.plexSans(9, FontWeight.w700, AppColors.primary, lineHeight: 11);
  static final sectionLabel = AppText.plexSans(9.5, FontWeight.w600, AppColors.inkMuted, lineHeight: 13);
  static final sectionAction = AppText.plexSans(9.3, FontWeight.w700, EventsColors.link, lineHeight: 13);
  static final paragraph = AppText.plexSans(11.2, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 18);
  static final highlightTitle = AppText.workSans(10.6, FontWeight.w700, AppColors.onSurface, lineHeight: 14);
  static final highlightBody = AppText.plexSans(10.2, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 14);
  static final agendaHeading = AppText.plexSans(8.3, FontWeight.w600, AppColors.outline, lineHeight: 12, spacing: 0.9);
  static final agendaPill = AppText.plexSans(7.7, FontWeight.w600, EventsColors.link, lineHeight: 11);
  static final sessionTime = AppText.plexSans(9.5, FontWeight.w700, EventsColors.link, lineHeight: 13);
  static final sessionTag = AppText.plexSans(8, FontWeight.w700, AppColors.onSurface, lineHeight: 11, spacing: 0.5);
  static final sessionTitle = AppText.workSans(11, FontWeight.w700, AppColors.onSurface, lineHeight: 15);
  static final sessionSpeaker = AppText.plexSans(9.7, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 13);
  static final barTitle = AppText.workSans(9.6, FontWeight.w700, AppColors.onSurface, lineHeight: 14);
  static final barNote = AppText.plexSans(9.6, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 13);
  static final barCancel = AppText.workSans(10.6, FontWeight.w700, AppColors.onSurface, lineHeight: 14);
  static final barPrimary = AppText.workSans(10.4, FontWeight.w700, Colors.white, lineHeight: 14);
  static final body = AppText.plexSans(10, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 15);

  // Filters.
  static final formTitle = AppText.workSans(14, FontWeight.w700, AppColors.slate900, lineHeight: 20);
  static final formLabel = AppText.plexSans(11, FontWeight.w600, AppColors.onSurface, lineHeight: 16);
}
