import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// The search page is drawn like LinkedIn's (owner's call, 27 Oct 2026): white,
/// Roboto, 90 % and 60 % black text, hairline rows, ICR blue for the chip that
/// is on and for links. The values are the Home feed's, kept here so this
/// feature does not depend on the feed's styles.
class SearchLook {
  SearchLook._();

  static const ink = Color(0xE6000000);
  static const soft = Color(0x99000000);
  static const hairline = Color(0xFFE0DFDC);
  static const fieldFill = Color(0xFFEDF3F8);
  static const tint = Color(0xFFEDF3F8);
  static const blue = AppColors.primary;
  static const chipBorder = Color(0xFFB8B8B8);

  static const pad = 16.0;
  static const avatar = 48.0;
}

/// Roboto at a size, weight and colour; the bundled font is Android's variable
/// one, so a heavier weight is asked for on its `wght` axis rather than faked.
TextStyle searchText(double size, FontWeight weight, Color color, {double? lineHeight}) => TextStyle(
  fontFamily: 'Roboto',
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: lineHeight == null ? null : lineHeight / size,
  letterSpacing: 0,
  leadingDistribution: TextLeadingDistribution.even,
  fontVariations: [FontVariation('wght', weight.value.toDouble())],
);

class SearchStyles {
  SearchStyles._();

  /// The query being typed, and its hint.
  static final input = searchText(16, FontWeight.w400, SearchLook.ink, lineHeight: 22);
  static final hint = searchText(16, FontWeight.w400, SearchLook.soft, lineHeight: 22);

  /// A hit's name, and the line under it.
  static final title = searchText(14, FontWeight.w600, SearchLook.ink, lineHeight: 18);
  static final sub = searchText(12, FontWeight.w400, SearchLook.soft, lineHeight: 16);
  static final kind = searchText(12, FontWeight.w400, SearchLook.soft, lineHeight: 16);

  /// A group's heading, and "See all".
  static final heading = searchText(16, FontWeight.w600, SearchLook.ink, lineHeight: 22);
  static final link = searchText(14, FontWeight.w600, SearchLook.blue, lineHeight: 20);

  /// A chip, on and off.
  static final chip = searchText(14, FontWeight.w600, SearchLook.soft, lineHeight: 18);
  static final chipOn = searchText(14, FontWeight.w600, Colors.white, lineHeight: 18);

  /// A recent search.
  static final recent = searchText(14, FontWeight.w400, SearchLook.ink, lineHeight: 20);

  /// An empty state's lead and its words.
  static final emptyTitle = searchText(16, FontWeight.w600, SearchLook.ink, lineHeight: 22);
  static final emptyBody = searchText(14, FontWeight.w400, SearchLook.soft, lineHeight: 20);
}
