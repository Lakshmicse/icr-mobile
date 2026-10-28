# Building a screen from a design export

The designs come as PNG exports of a 390 dp-wide phone frame, usually at 2x (780 px wide), sometimes at 1x. There is no Figma access, so every size is measured from the picture. The goal is the design to the pixel, fed by the real API, with the design's own sample content available as demo data for review.

## 1. Measure

Tools in `tool/design/` (Python with Pillow and numpy):

```
python tool/design/measure.py design.png --flatten --out flat.png --frame 16,14,796,2075   # drop the shadow/transparency, cut the frame
python tool/design/measure.py flat.png --y0 0 --y1 960                                      # bands and boxes, sizes in dp
python tool/design/measure.py flat.png --ink 145,515,700,542 --dark 120 --gap 8             # word boxes inside a region
python tool/design/measure.py flat.png --colors 146,559,308,572                              # the text colour of a region
python tool/design/measure.py flat.png --crop 0,0,780,420 --out zoom.png --zoom 1.5          # something to look at
python tool/design/fitfont.py "Recommended" 86.5                                             # the font size for a measured width
```

Work from the bands: each band is a row of the layout; each box inside it an icon, a word, a chip. Convert everything to dp (divide by the scale). Record, per element: left, top, width, height, colour, and for text the font size that gives the measured width.

## 2. Fonts and colours

- Names, titles and headings: **Work Sans**. Everything else: **IBM Plex Sans**. Weights 400/500/600/700 are bundled.
- Size text **by its measured width** (`fitfont.py`), not by its cap height. The mocks are set in a slightly narrower face, so a width-fitted size is about 1 px shorter than the design's glyphs; a cap-fitted size would overflow and wrap differently.
- `letterSpacing: 0` always (Material 3 tracks body text out; the designs do not). Set `height` (line height) to the design's line pitch.
- Colours: use `AppColors` when the sampled colour is there (ink #111C2D, #414750, #727781, borders #E1E3E4, chips #F2F4F6, primary #1D63A3, the slate palette for sheets). Add a feature's own colours in its own styles file, not in `app_colors.dart`.
- Define a feature's text styles in `lib/features/<feature>/<feature>_styles.dart` with `AppText.workSans(...)` / `AppText.plexSans(...)`.

## 3. Build

- One feature folder: `lib/features/<feature>/` with `<feature>_models.dart`, `<feature>_repository.dart` (abstract), `api_<feature>_repository.dart`, `demo_<feature>_repository.dart`, `<feature>_controller.dart` (ChangeNotifier), the screen, and `widgets/`.
- Reuse `lib/core/widgets/`: `TitleBar` (back arrow, title, bell), `IcrSearchField`, `IcrChip`, `SectionHeading`, `Hairline`, `PrimaryButton`, `SheetHandle` and `showDetailSheet` (the blurred, draggable detail sheet).
- Artwork the design draws (logos, photos, custom icons) is cut from the export with `measure.py --crop` into `assets/images/demo/<feature>/` (2x pixels, drawn with `Image.asset(..., scale: 2)`), after turning white to transparency where it sits on a tinted surface.
- Icons: Lucide (`lucide_icons_flutter`) first, Material Symbols (`material_symbols_icons`) when Lucide has no match; size them so the glyph's ink is as wide as the design's, not the nominal size.
- API: the backend is `irc-portal` (NestJS, `/api/v1`, bearer JWT through `ApiClient`); read `irc-portal/CLAUDE.md` and the module's controller and DTOs before mapping. Where the design shows something the API cannot give, show the nearest honest thing and say so in the docs; never invent numbers.
- Demo data: the design's sample content, bundled, behind `AppConfig.demo` (`--dart-define=FEED_SOURCE=demo`), so the golden can be compared with the design.
- Paths to the website for things the app does not do yet: `openSitePage(context, '/path')`.

## 4. Verify

- `dart format lib test` (120 columns, pinned in `analysis_options.yaml`), `flutter analyze` clean, `flutter test` green.
- A golden test per screen in `test/golden/<feature>_golden_test.dart` at the design's frame (`tester.view.physicalSize = Size(780, H)`, `devicePixelRatio = 2`) that also exports `build/screens/<name>.png`.
- `python tool/design/compare.py flat.png build/screens/<name>.png --out side.png` — the bands must start on the same rows; look at `side.png`.
- Then on the emulator: `adb shell wm density 443` makes the 1080 px emulator 390 dp wide; `adb shell wm density reset` after.
