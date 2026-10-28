# Building one screen family (checklist for a parallel build)

Read `docs/DESIGN_REPLICATION.md` first. `lib/features/jobs/` is the worked example: models, an abstract repository, an API repository, a demo repository with the design's sample content, a controller, the screen, a detail sheet, styles, tests and goldens. Copy its shape.

## Where you may write

- `lib/features/<feature>/**`
- `assets/images/demo/<feature>/**` (the directory is already registered in `pubspec.yaml`)
- `test/<feature>_test.dart`, `test/golden/<feature>_golden_test.dart`
- `docs/screens/<feature>.md`

Nothing else: not `pubspec.yaml`, not `lib/app.dart`, not `lib/features/shell/`, not `lib/core/**`, not `README.md`, not other features. If a shared widget in `lib/core/widgets/` does not fit, make your own copy inside your feature and say so in your report. New colours and text styles go in `lib/features/<feature>/<feature>_styles.dart` (`AppText.workSans(...)`, `AppText.plexSans(...)`).

## What a feature delivers

1. **Models** that name what the design draws, with demo-only fields marked as such.
2. **`<Feature>Repository`** (abstract) with `Api<Feature>Repository` on the real API and `Demo<Feature>Repository` holding the design's sample content. The API is `irc-portal` (`E:\ICR\irc-portal`): read its `CLAUDE.md`, then the module's controller and DTOs under `backend/src/modules/<module>/`, and the website's hooks under `frontend/src/features/` or `frontend/src/components/` for how the web reads the same data. Use `ApiClient.dio` (bearer token handled). Uploads: `AppConfig.absoluteUrl(path, apiBase: api.dio.options.baseUrl)`. Pages: `{ data, meta.hasNext }`.
3. **A controller** (`ChangeNotifier`) with optimistic actions that roll back on an `ApiError` and return its message.
4. **Screens** built to the measured design, with public constructors the shell can call: a tab screen takes `required VoidCallback onBack` and reads its controller from `Provider`; a detail opens through `Future<void> show<Thing>Sheet(BuildContext context, <Thing> thing)` using `showDetailSheet` from `lib/core/widgets/detail_sheet.dart`.
5. **Demo artwork** cut from the design (`measure.py --crop`), stored at the design's pixel scale and drawn with `Image.asset(..., scale: <scale>)`.
6. **Links** for what the app does not do: `openSitePage(context, '/path')` to the website's real route (check `frontend/src/app/` for the route).
7. **Tests**: the mapping from API JSON (use an `HttpClientAdapter` table as `test/jobs_test.dart` does), the controller's rollback, and one golden per screen at the design's frame, exporting `build/screens/<name>.png`.
8. **`docs/screens/<feature>.md`**: the screens, the endpoints used, every place the design shows something the API cannot give and what the screen shows instead, the demo content, and how to wire the screens (constructor, provider).

## Done means

- `dart format lib test` (120 columns), `flutter analyze` clean, `flutter test` green (all tests, not only yours).
- `python tool/design/compare.py <flat design> build/screens/<name>.png --out side.png` shows the main bands starting within 2 dp; where they cannot (the API lacks the content, a font draws taller), say so.
- Flutter commands share one lock: if one says it is waiting for another, wait. Do not run `flutter clean`, `flutter pub get` or the emulator; do not commit.
