import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../study_styles.dart';

/// The bar over a study screen (flashcards-study.png): the back arrow, the deck's name over up to two lines, a
/// search glyph and a ⋮ menu. The search glyph turns the name into a field that narrows the cards; [menu] is the
/// ⋮ button, built by the screen because what it offers depends on the pass.
///
/// 54 dp tall, so a name over two lines sits in it with room above and below; the back arrow and the glyphs keep
/// the design's centres (30, 337 and 373 dp from the left on a 390 dp phone).
class StudyBar extends StatelessWidget {
  const StudyBar({
    super.key,
    required this.title,
    required this.onBack,
    this.search,
    this.searching = false,
    this.searchHint = 'Search this deck',
    this.onSearch,
    this.onCloseSearch,
    this.onSearchChanged,
    this.menu,
  });

  static const height = 54.0;

  final String title;
  final VoidCallback onBack;

  /// The search field's controller; null with no search (a screen with nothing to search yet).
  final TextEditingController? search;

  /// Whether the title is a search field.
  final bool searching;
  final String searchHint;
  final VoidCallback? onSearch;
  final VoidCallback? onCloseSearch;
  final ValueChanged<String>? onSearchChanged;

  /// The ⋮ button; none when there is nothing to offer.
  final Widget? menu;

  @override
  Widget build(BuildContext context) {
    final canSearch = search != null;
    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Row(
        children: [
          const SizedBox(width: 6),
          Semantics(
            button: true,
            label: 'Back',
            excludeSemantics: true,
            child: InkResponse(
              key: const ValueKey('study-back'),
              onTap: onBack,
              radius: 24,
              child: const SizedBox(
                width: 48,
                height: height,
                child: Icon(Symbols.arrow_back, size: 24, color: AppColors.onSurfaceVariant),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: searching && search != null
                ? TextField(
                    key: const ValueKey('study-search'),
                    controller: search,
                    autofocus: true,
                    onChanged: onSearchChanged,
                    // Search puts the keyboard away, so the cards it found have the room.
                    onSubmitted: (_) => FocusScope.of(context).unfocus(),
                    textInputAction: TextInputAction.search,
                    style: StudyText.barSearch,
                    cursorColor: AppColors.primary,
                    decoration: InputDecoration(
                      hintText: searchHint,
                      hintStyle: StudyText.barSearchHint,
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  )
                : Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      key: const ValueKey('study-title'),
                      style: StudyText.barTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
          ),
          if (canSearch)
            Semantics(
              button: true,
              label: searching ? 'Close the search' : 'Search the cards',
              excludeSemantics: true,
              child: InkResponse(
                key: const ValueKey('study-search-button'),
                onTap: searching ? onCloseSearch : onSearch,
                radius: 22,
                child: SizedBox(
                  width: 40,
                  height: height,
                  child: Icon(
                    searching ? Symbols.close : LucideIcons.search,
                    size: searching ? 22 : 19,
                    color: onSearch == null && !searching ? AppColors.slate300 : StudyColors.chipInk,
                  ),
                ),
              ),
            ),
          if (menu != null) SizedBox(width: 33, height: height, child: menu) else const SizedBox(width: 12),
        ],
      ),
    );
  }
}

/// The ⋮ button's face: three dots in the bar's ink, in the 33 dp the design leaves for it.
class StudyMenuGlyph extends StatelessWidget {
  const StudyMenuGlyph({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: Icon(Icons.more_vert, size: 22, color: StudyColors.chipInk));
}
