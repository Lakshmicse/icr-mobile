import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';

/// Colours of the notifications and messages screens: the section screens'
/// palette (white page, slate-200 hairlines, 12-radius cards, the blue primary).
abstract final class ChatColors {
  static const page = Colors.white;
  static const rule = AppColors.slate200;
  static const cardBorder = AppColors.slate200;

  /// The tint behind an unread row, and behind the thread's context strip.
  static const unreadRow = Color(0xFFF2F7FD);
  static const strip = Color(0xFFF6F9FC);

  /// The other side's bubble, as the forum's reply bubbles.
  static const theirBubble = AppColors.slate100;
  static const myBubble = AppColors.primary;
  static const quoteBar = Color(0xFF9DBCDD);
  static const failed = AppColors.error;
  static const star = AppColors.amber500;

  // The designed inbox and thread (docs/designs/messaging-inbox.png, messaging-thread.png).
  /// The selected filter chip (the design's deep navy) and the unread row's left bar.
  static const search = Color(0xFFF2F4F6);

  /// The thread: its grey page, the white bubble's hairline, the meeting card's panel, the read ticks.
  static const composerChip = Color(0xFFF2F4F6);
}

abstract final class ChatText {
  // Lists (inbox rows, notification rows)
  static final rowName = AppText.workSans(14, FontWeight.w600, AppColors.onSurface, lineHeight: 18);
  static final rowNameUnread = AppText.workSans(14, FontWeight.w700, AppColors.onSurface, lineHeight: 18);
  static final rowTime = AppText.plexSans(11, FontWeight.w500, AppColors.outline, lineHeight: 14);
  static final rowTimeUnread = AppText.plexSans(11, FontWeight.w600, AppColors.primary, lineHeight: 14);
  static final rowPreview = AppText.plexSans(12.5, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 18);
  static final rowPreviewUnread = AppText.plexSans(12.5, FontWeight.w600, AppColors.onSurface, lineHeight: 18);
  static final rowAbout = AppText.plexSans(11, FontWeight.w500, AppColors.inkSoft, lineHeight: 14);
  static final kindBadge = AppText.plexSans(10, FontWeight.w600, AppColors.onSurfaceVariant, lineHeight: 12);
  static final count = AppText.plexSans(10, FontWeight.w700, Colors.white, lineHeight: 12);
  static final section = AppText.workSans(11, FontWeight.w600, AppColors.slate500, lineHeight: 16, spacing: 0.55);

  // Notifications
  static final noteTitle = AppText.plexSans(13, FontWeight.w400, AppColors.onSurface, lineHeight: 18);
  static final noteTitleUnread = AppText.plexSans(13, FontWeight.w600, AppColors.onSurface, lineHeight: 18);
  static final noteBody = AppText.plexSans(12, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 17);
  static final noteMeta = AppText.plexSans(11, FontWeight.w500, AppColors.outline, lineHeight: 14);
  static final lead = AppText.plexSans(12, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 16);
  static final tab = AppText.plexSans(13, FontWeight.w600, AppColors.onSurfaceVariant, lineHeight: 18);
  static final tabOn = AppText.plexSans(13, FontWeight.w600, AppColors.primary, lineHeight: 18);
  static final barAction = AppText.plexSans(12, FontWeight.w600, AppColors.primary, lineHeight: 16);

  // A thread
  static final headerName = AppText.workSans(15, FontWeight.w700, AppColors.onSurface, lineHeight: 19);
  static final headerSub = AppText.plexSans(11, FontWeight.w500, AppColors.inkSoft, lineHeight: 14);
  static final bubble = AppText.plexSans(14, FontWeight.w400, AppColors.onSurface, lineHeight: 20);
  static final bubbleMine = AppText.plexSans(14, FontWeight.w400, Colors.white, lineHeight: 20);
  static final sender = AppText.workSans(11.5, FontWeight.w600, AppColors.onSurfaceVariant, lineHeight: 15);
  static final meta = AppText.plexSans(10.5, FontWeight.w500, AppColors.outline, lineHeight: 13);
  static final day = AppText.plexSans(11, FontWeight.w600, AppColors.slate500, lineHeight: 14);
  static final deleted = AppText.plexSans(
    13,
    FontWeight.w400,
    AppColors.outline,
    lineHeight: 18,
  ).copyWith(fontStyle: FontStyle.italic);
  static final quoteName = AppText.plexSans(11, FontWeight.w600, AppColors.primary, lineHeight: 14);
  static final quoteText = AppText.plexSans(12, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 16);
  static final stripKind = AppText.plexSans(10.5, FontWeight.w500, AppColors.inkSoft, lineHeight: 13);
  static final stripTitle = AppText.plexSans(13, FontWeight.w600, AppColors.sectionAction, lineHeight: 17);
  static final composerHint = AppText.plexSans(13, FontWeight.w500, AppColors.outline, lineHeight: 18);
  static final composer = AppText.plexSans(14, FontWeight.w400, AppColors.onSurface, lineHeight: 20);
  static final event = AppText.plexSans(11.5, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 15);
  static final cardTitle = AppText.workSans(13, FontWeight.w600, AppColors.onSurface, lineHeight: 17);
  static final cardMeta = AppText.plexSans(11, FontWeight.w500, AppColors.inkSoft, lineHeight: 14);
  static final sheetTitle = AppText.workSans(16, FontWeight.w700, AppColors.onSurface, lineHeight: 20);
  static final label = AppText.plexSans(12, FontWeight.w600, AppColors.onSurface, lineHeight: 16);
  static final hint = AppText.plexSans(11, FontWeight.w400, AppColors.inkSoft, lineHeight: 15);

  // The designed inbox (docs/designs/messaging-inbox.png; sizes measured at 2x).

  // The designed thread (docs/designs/messaging-thread.png).
  static final contactName = AppText.workSans(16, FontWeight.w700, AppColors.onSurface, lineHeight: 20);
  static final contactSub = AppText.plexSans(13, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 17);
  static final dayPill = AppText.plexSans(12.5, FontWeight.w600, AppColors.onSurfaceVariant, lineHeight: 16);
  static final senderName = AppText.workSans(14, FontWeight.w600, AppColors.onSurface, lineHeight: 18);
  static final senderTime = AppText.plexSans(12, FontWeight.w400, AppColors.outline, lineHeight: 16);
  static final bubbleTheirs = AppText.plexSans(14, FontWeight.w400, AppColors.onSurface, lineHeight: 21);
  static final bubbleMineText = AppText.plexSans(14, FontWeight.w400, Colors.white, lineHeight: 21);
  static final sentTime = AppText.plexSans(12, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 16);
  static final fileName = AppText.plexSans(13, FontWeight.w600, AppColors.onSurface, lineHeight: 17);
  static final fileMeta = AppText.plexSans(12, FontWeight.w400, AppColors.outline, lineHeight: 16);
  static final fileAction = AppText.plexSans(13, FontWeight.w600, AppColors.primary, lineHeight: 17);
  static final meetingTitle = AppText.workSans(14, FontWeight.w700, AppColors.onSurface, lineHeight: 18);
  static final meetingSub = AppText.plexSans(12, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 16);
  static final meetingLine = AppText.plexSans(12.5, FontWeight.w600, AppColors.onSurfaceVariant, lineHeight: 16);
  static final meetingButton = AppText.plexSans(13, FontWeight.w600, AppColors.onSurface, lineHeight: 17);
  static final meetingButtonOn = AppText.plexSans(13, FontWeight.w600, Colors.white, lineHeight: 17);
  static final composerChip = AppText.plexSans(13, FontWeight.w600, AppColors.onSurface, lineHeight: 17);
  static final draftSaved = AppText.plexSans(12.5, FontWeight.w400, AppColors.outline, lineHeight: 16);
  static final composerHintDesign = AppText.plexSans(14, FontWeight.w400, AppColors.outline, lineHeight: 20);
}

/// The colours of the designed inbox (docs/designs/messaging-inbox.png), sampled from the picture: the
/// export is Tailwind's slate and sky, with ICR's own navy for what is selected or unread.
abstract final class InboxColors {
  /// The selected filter chip, the "5 Active" ink, the unread bar, count and time, the compose button.
  static const navy = Color(0xFF004B83);

  /// The blue context chip and the "5 Active" pill.
  static const blueTint = Color(0xFFDBEAFE);

  /// The unread row's background.
  static const unreadTint = Color(0xFFF4F9FF);

  /// A requirement's chip (amber 50, its 1 dp edge, amber 800 ink).
  static const amberTint = Color(0xFFFFFBEB);
  static const amberEdge = Color(0xFFFEEEB1);
  static const amberInk = AppColors.amber800;

  /// The search box, the idle filter chips, the grey context chip, the hairlines between rows.
  static const grey = AppColors.slate100;
  static const greyInk = AppColors.slate600;

  /// A mentor's shield and a requirement thread's unread count.
  static const green = Color(0xFF059669);

  static const ink = AppColors.slate900;
  static const soft = AppColors.slate500;
  static const faint = AppColors.slate400;
  static const rule = AppColors.slate100;
}

/// The designed inbox's type, sized as the design draws it (Work Sans for names, IBM Plex Sans for the rest)
/// and let through the app's scale ([AppText.sp]) like every other screen, with the design's line pitch.
abstract final class InboxText {
  static TextStyle _plex(double size, FontWeight weight, Color color, double line) {
    final base = AppText.plexSans(size, weight, color);
    return base.copyWith(height: line / base.fontSize!);
  }

  static TextStyle _work(double size, FontWeight weight, Color color, double line) {
    final base = AppText.workSans(size, weight, color);
    return base.copyWith(height: line / base.fontSize!);
  }

  // The header and its controls.
  static final title = _work(15, FontWeight.w700, InboxColors.ink, 20);
  static final activePill = _plex(10.8, FontWeight.w600, InboxColors.navy, 16);
  static final searchHint = _plex(11.9, FontWeight.w400, InboxColors.faint, 18);
  static final searchInput = _plex(11.9, FontWeight.w400, InboxColors.ink, 18);
  static final filter = _plex(10.5, FontWeight.w600, InboxColors.greyInk, 16);
  static final filterOn = _plex(10.5, FontWeight.w600, Colors.white, 16);
  static final heading = _work(10.5, FontWeight.w600, InboxColors.soft, 16);

  // A row.
  static final name = _work(11.8, FontWeight.w700, InboxColors.ink, 18.5);
  static final time = _plex(10.9, FontWeight.w400, InboxColors.faint, 18.5);
  static final timeUnread = _plex(10.9, FontWeight.w700, InboxColors.navy, 18.5);
  static final headline = _plex(10.9, FontWeight.w400, InboxColors.soft, 18.5);
  static final chipBlue = _plex(10, FontWeight.w600, InboxColors.navy, 16);
  static final chipGrey = _plex(10, FontWeight.w600, InboxColors.greyInk, 16);
  static final chipAmber = _plex(10, FontWeight.w600, InboxColors.amberInk, 16);
  static final preview = _plex(11, FontWeight.w400, InboxColors.soft, 18.5);
  static final previewUnread = _plex(11, FontWeight.w400, AppColors.slate700, 18.5);
  static final count = _plex(9, FontWeight.w700, Colors.white, 14);
}

/// What the thread design (docs/designs/messaging-thread.png) draws that `ChatColors` does not hold, sampled
/// from the export: its page grey, the deep blue of the file tile, the verified badge and the video glyph, the
/// green of the read ticks, the meeting card's panel and the hairline round every card.
abstract final class ThreadColors {
  static const page = Color(0xFFFAFBFC);
  static const deepBlue = Color(0xFF004B83);
  static const tick = AppColors.tertiary;
  static const panel = AppColors.surfaceContainerLow;
  static const edge = AppColors.outlineVariant;

  /// The faint lift under a white bubble or card.
  static const lift = [BoxShadow(color: Color(0x0A000000), blurRadius: 2, offset: Offset(0, 1))];
}
