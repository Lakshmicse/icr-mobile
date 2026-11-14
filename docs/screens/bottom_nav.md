# Bottom bar

`lib/features/shell/icr_bottom_nav.dart` (`IcrBottomNav`), glyphs in `nav_icons.dart`. Six tabs: Home, Learning,
Mentorship, Marketplace, Jobs, Discover. White, a hairline over it, a 3 dp line over the open tab, 90 % black for
the open tab and 60 % for the rest.

## 13 Nov 2026: even spacing, outlined until selected

The owner: "Bottom navigation bar has uneven spacing some icons have the space more some small space . and the
icons before selection it should be outlined icons once selected convert it to filled and line as it is coming now."

- **Spacing.** Six equal slots put "Mentorship" and "Marketplace" 13 dp apart and "Jobs" and "Discover" 36. Each
  tab now takes the width of its own label (never less than the 24 dp glyph box, `glyphWidth`) plus an equal share of
  the spare room (`contentWidths`), so the gap between two neighbours is the same all along the bar. The slots still
  fill the bar edge to edge, so the tap areas meet. Under `minGap` (a very large font) it falls back to equal slots
  and the labels shrink to fit.
- **Glyphs.** A tab draws its outline until it is the open one, then the filled glyph. Flutter's own static pairs
  (`school_outlined`/`school_rounded`, `group_outlined`/`group_rounded`, `storefront_outlined`/`storefront_rounded`,
  `grid_view_outlined`/`grid_view_rounded`); the house and the briefcase, which the app paints itself, take
  `filled: false` and draw the same shapes as a 1.7 dp line. Never `material_symbols_icons` here: a release build
  dropped its glyphs (27 Oct 2026).
- The line over the open tab is unchanged; it is as wide as the tab's slot.

Tests: `test/bottom_nav_spacing_test.dart` (equal gaps at 360, 390 and 412 dp, the glyph over its label, the
large-font fallback, outline and filled per tab). Golden: `bottom_nav.png`, and every screen golden that draws the bar.
