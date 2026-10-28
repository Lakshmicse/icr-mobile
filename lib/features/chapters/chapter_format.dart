/// Small rules the Chapters screens share: the banner colours a chapter without
/// a photo gets, the glyph for its place, and the words for dates and roles.
library;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'chapter_models.dart';
import 'community_kit.dart';

/// The website's string hash (djb2, `placeGradient` in its chapters helpers).
int _hash(String seed) {
  var h = 5381;
  for (final unit in seed.codeUnits) {
    h = ((h * 33) ^ unit) & 0xFFFFFFFF;
  }
  return h;
}

/// The two colours of a chapter's banner when it has no photo: the website's
/// `hsl(h 55% 32%)` to `hsl(h+40 60% 24%)`, h hashed from the chapter's slug.
(Color, Color) coverColors(String seed) {
  final h = _hash(seed) % 360;
  final h2 = (h + 40) % 360;
  return (
    HSLColor.fromAHSL(1, h.toDouble(), 0.55, 0.32).toColor(),
    HSLColor.fromAHSL(1, h2.toDouble(), 0.60, 0.24).toColor(),
  );
}

/// The glyph a chapter's banner carries, by its place.
IconData placeIcon(PlaceKind kind) => switch (kind) {
  PlaceKind.coastal => LucideIcons.waves,
  PlaceKind.capital => LucideIcons.landmark,
  PlaceKind.tech => LucideIcons.cpu,
  PlaceKind.industrial => LucideIcons.factory,
  PlaceKind.heritage => LucideIcons.castle,
  PlaceKind.metro => LucideIcons.building2,
  PlaceKind.general => LucideIcons.mapPin,
};

/// "Chapter lead" / "Member".
String roleWord(ChapterRole role) => role.label;

/// "Next: Nov 01", or null when the chapter has nothing coming.
String? nextLabel(ChapterSummary c) => c.nextEventAt == null ? null : 'Next: ${monthDay(c.nextEventAt!)}';

/// "Est. 2014" from a founding year.
String establishedLabel(int year) => 'Est. $year';

/// The "N members" and "N events" figures as short phrases.
String membersLabel(int n) => plural(n, 'member');
String eventsLabel(int n) => plural(n, 'upcoming event');

/// How a filter chip names the country row's first chip.
String allCountriesLabel(int n) => 'All Countries ($n)';

/// "Joined Mar 2026".
String joinedLabel(DateTime t) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final d = inIst(t);
  return 'Joined ${months[d.month - 1]} ${d.year}';
}

/// A filled-in hour string such as "11:00 – 14:00 IST".
String timeRange(DateTime start, DateTime? end) {
  final from = clock(start);
  if (end == null) return '$from IST';
  return '$from – ${clock(end)} IST';
}
