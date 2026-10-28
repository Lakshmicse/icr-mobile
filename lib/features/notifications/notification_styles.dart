import 'package:flutter/material.dart';

import '../feed/feed_styles.dart';

/// The notifications list is drawn like the Android LinkedIn one (owner's call, 27 Oct 2026): white rows with
/// hairline rules, an unread row on a pale-blue tint with a dot, 14 sp sentences with the name in bold, 12 sp
/// detail and age at 60 % black. The colours and type are Home's (`HomeLook`, `roboto`), so the two read as one app.
abstract final class NoteLook {
  static const page = Colors.white;
  static const rule = HomeLook.hairline;
  static const unreadRow = HomeLook.searchFill;
  static const ink = HomeLook.ink;
  static const soft = HomeLook.soft;
  static const blue = HomeLook.blue;
}

abstract final class NoteType {
  /// A row's sentence, the person or company in [sentenceBold].
  static final sentence = roboto(14, FontWeight.w400, NoteLook.ink, lineHeight: 18);
  static final sentenceBold = roboto(14, FontWeight.w600, NoteLook.ink, lineHeight: 18);
  static final body = roboto(12, FontWeight.w400, NoteLook.soft, lineHeight: 16);
  static final age = roboto(12, FontWeight.w400, NoteLook.soft, lineHeight: 16);
  static final ageUnread = roboto(12, FontWeight.w600, NoteLook.blue, lineHeight: 16);
  static final company = roboto(12, FontWeight.w400, NoteLook.soft, lineHeight: 16);

  /// "Today", "This week", "Earlier".
  static final section = roboto(16, FontWeight.w600, NoteLook.ink, lineHeight: 20);

  /// The filter chips and the bottom-sheet rows.
  static final chip = roboto(13, FontWeight.w600, NoteLook.soft, lineHeight: 16);
  static final chipOn = roboto(13, FontWeight.w600, Colors.white, lineHeight: 16);
  static final sheetTitle = roboto(16, FontWeight.w600, NoteLook.ink, lineHeight: 20);
  static final sheetRow = roboto(14, FontWeight.w500, NoteLook.ink, lineHeight: 18);
  static final sheetHint = roboto(12, FontWeight.w400, NoteLook.soft, lineHeight: 16);
}

/// The short name a filter chip wears (the preferences keep the long ones): "Jobs", not "Jobs and applications".
String chipLabelOf(String categoryId) => switch (categoryId) {
  'messages' => 'Messages',
  'jobs' => 'Jobs',
  'procurement' => 'Requirements',
  'mentoring' => 'Mentoring',
  'learning' => 'Learning',
  'events' => 'Events',
  'community' => 'Community',
  'verification' => 'Verification',
  'team' => 'Team',
  'membership' => 'Membership',
  'onboarding' => 'Getting started',
  'payments' => 'Payments',
  'support' => 'Support',
  'security' => 'Security',
  _ => 'Other',
};
