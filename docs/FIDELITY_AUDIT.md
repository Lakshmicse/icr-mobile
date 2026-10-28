# Fidelity audit (26 Oct 2026): comparing a render with the owner's hi-res design

For screens that already exist. Run from `E:\ICR\icr-mobile`. The goldens (`flutter test test/golden/<x>_golden_test.dart`) write the 2x render to `build/screens/<name>.png` **before** they compare, so a failing golden still gives you the picture. Re-record a golden (`--update-goldens`, that file only) once the change is the design.

## Tools (`tool/design/`, Python with Pillow + numpy: use `python`, not `python -I`)

| Tool | What it answers |
|---|---|
| `strip_diff.py DESIGN RENDER --top 6 --out build/audit/side` | Which bands of the screen differ most (0 = same, 255 = opposite). Aligns a design that sits in a shadow margin. `--out` writes design-beside-render crops of the worst bands: look at them. |
| `line_widths.py DESIGN.png RENDER.png "x0,y0,x1,y1"` | Every text line in a box (2x px): its left/right edge in the design and the render, and the ratio. Names are relative to `docs/designs/hires/` and `build/screens/`. |
| `line_match.py DESIGN.png RENDER.png [--min-ink 300 --flag 1.2]` | Matches every text line of the render with the design's line and lists the ones whose width differs by more than 2% or whose ink is heavier. Also prints the page's median width and ink ratio. |
| `ink_ratio.py DESIGN.png RENDER.png "name=x0,y0,x1,y1" ...` | Ink (how heavy the text is) and pixel difference of named boxes. |

## What the audit found (so far)

1. **The layout is right.** Total heights match the designs to within half a dp on events, event sheet, mentor profile (both tabs) and the course sheet; the median width ratio of matched text lines is 1.00 on every screen.
2. **Body text was a weight step too light.** The designs set 10 dp body paragraphs and the mentor's headline in IBM Plex Sans **Medium (500)**, not Regular. Proof: at weight 500 and the same size the about paragraph's lines come out at 545/601 px against the design's 545/601 (at 400 they were 534/590, 2% short, and 30% lighter in ink). Fixed so far: mentor profile `body` (w500), `headline` (w500), `headlineStrong` (w700), the career description box widened from 303 to 310 dp (the design's longest line is 307 dp); course sheet `body`, `takeaway`, `lesson`, `subtitle` (w500). The signature of the same mistake elsewhere: **every line of a paragraph is 2% wider in the design and the render's ink is 1.2 to 1.5 times lighter**.
3. **Changing a weight changes wrapping.** Fix the cause: if a line now wraps differently, widen the box to what the design's longest line needs (not more than the next word allows) and check `strip_diff.py` shows no band shifted. Never narrow the font to hide a wrap.
4. Councils: the render drifts lower than the design as you go down (+1 dp near the top, +8 dp at the bottom). Card text lines are up to 5% wider and heavier in the design.
5. Events goldens used the real clock: the demo event is dated Oct 24 2026 and read "Ended" from Oct 25. `eventsNow` (`event_models.dart`) is the module's clock; goldens pin it.

## Rules

- Never change a size to fix a weight problem. Fit weight and size on **line widths** (they match at 1.000 when right), then look at ink.
- Only change files in your folders. `lib/core`, the shell, `lib/app.dart`, `pubspec.yaml` belong to the lead: send the exact diff.
- Keep every control working: run the folder's widget tests and the live test after each change.

## State at the end of the flow build (27 Oct 2026, measured with `tool/design/strip_diff.py` against `docs/designs/hires/`)

The three design audits were parked when the owner put flows first. The first two were stopped mid-edit, so their goldens and the screens disagree. What the full non-live suite showed (about 1,550 pass) and what it means:

| Screen | Mean diff vs design, before the audit edits | now | Golden |
|---|---|---|---|
| Councils | 21.5 | **10.8** (text line widths ratio 1.000, 8 dp longer than the design) | re-recorded 27 Oct, passes |
| Mentorship landing | 26.0 | 24.3 (design is 52 dp taller than the render: 2881 vs 2829 dp; worst bands at 830 to 1830 dp, 53 to 66) | **still fails** (recorded copy predates the edits) |
| Find Mentors | 10.3 | **14.0, worse** (worst bands at 510 and 690 to 750 dp, 33 to 43) | **still fails**; do NOT re-record until fixed |
| Find Mentors on a company chip | n/a | n/a | **still fails** (same cause) |

Pixel pass, in this order: (1) Find Mentors: find which of the audit's half-applied layout edits moved the card grid and the chips (compare `build/screens/find_mentors.png` with the recorded copy in `test/golden/failures/find_mentors_masterImage.png`), fix it, then re-record the three Mentorship goldens; (2) Mentorship landing: the 52 dp the design has that the render lacks; (3) Events and the sheets; (4) the tablet Marketplace comp and the 240 dp band on the supplier tabs (`docs/screens/marketplace.md`, "Pixel pass later"); (5) Learning: look unchanged, flows only.
