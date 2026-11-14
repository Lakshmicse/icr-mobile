# Splash

What shows from the tap on the app's icon until the session is known.

1. **The Android launch window** (`LaunchTheme` in `android/app/src/main/res/values*/styles.xml`): plain white. On
   Android 12+ the system splash icon is an empty drawable (owner, 9 Nov 2026: no eagle-only logo first).
2. **The app's own splash** (`_Splash` in `lib/app.dart`, key `splash`): white, the ICR logo in its own colours
   (`AuthPalette.light.logo`), 180 dp wide, centred, while `AuthController.restore()` reads the saved session.

## 13 Nov 2026: light whatever the phone's theme

The owner: "the ICR Splash screen changing for the dark ground or dark mode, white for the light mode. Now the
mobile version is light only, there is no dark theme yet." Both steps followed the phone's dark mode (a black
window, then a dark page with the white logo) and then opened a white app.

- `_Splash` no longer reads `AuthPalette.of(context)`: always white with the light logo, dark status-bar icons.
- `values-night/styles.xml`: `LaunchTheme` and `NormalTheme` inherit `Theme.Light.NoTitleBar` (they were
  `Theme.Black`), and the window behind Flutter is white.
- `values-night-v31/styles.xml`: `NormalTheme`'s window background is white.
- `drawable-v21/launch_background.xml`: white, not `?android:colorBackground`.
- Test: `test/splash_light_test.dart` (white and the light logo with the phone in light and in dark mode).

Still following the phone's dark mode, by their own designs (`sign-in-dark.png`): the sign-in, sign-up and password
screens (`AuthPalette.of`, `LiColors.of`). When the app gets a dark theme, the splash follows it again from here.
