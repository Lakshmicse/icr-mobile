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
}
