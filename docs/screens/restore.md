# Coming back to the app

`lib/core/util/screen_trail.dart` (`ScreenTrail`, `SitePlace`), `lib/features/shell/app_shell.dart` (`restorationId`,
`restoreState`), `lib/app.dart` (`restorationScopeId: 'icr'`, `navigatorObservers`).

## 14 Nov 2026: back on the screen you left, not on Home

The owner: "when we move from the ICR to other application and other application to ICR the ICR will refresh from
current screen to home screen."

**Cause.** An ordinary switch keeps the app as it was (checked on the emulator: same process, the typed text still
there). But Android ends an app in the background when another app needs the memory (a camera, a video, WhatsApp on
a phone with little to spare), and the app weighs about 107 MB on the sign-in screen alone. Coming back, Android starts it again
and hands it the state it saved, and the app saved none, so it opened on Home. `adb shell am kill
org.icr.icr_mobile` while the app is in the background reproduces it.

**Fix.** The app now saves state the way a native Android screen does:

- `MaterialApp(restorationScopeId: 'icr')` switches Flutter's state restoration on.
- The shell keeps the open tab (`RestorableEnum<AppTab>`) and the website page of the screen over the tabs
  (`RestorableStringN`, from `ScreenTrail.place`) under `shell-<user id>-<company id>`, so another account or another
  company never gets them. They are written whenever a screen opens or closes, and once more as the app is left.
- On a restore the shell opens on that tab, then opens the page again through `SiteRoutes.inApp`, the way a link to
  it opens. Back from it returns to the tab. Only the top screen comes back, not the screens under it.
- Android drops the saved state when the person closes the app themselves (swiped away from Recents), so a fresh
  start is still Home.

**Which page a screen stands for.** `ScreenTrail` watches the app's navigator (pages and sheets, never a dialog).
It reads the page in two ways:

1. A screen opened for a page of the website (a link, a notification row, Saathi, a drawer row, a Discover door)
   takes that page: `SiteRoutes.inApp` runs its opener through `ScreenTrail.opening`.
2. A screen opened by a tap says which page it is with `SitePlace(path: …)`. Marked so far: the job sheet
   (`/jobs/<id>`), a course sheet (`/learning/professional-development/<code>`), a discussion
   (`/community/<slug>`), a mentor (`/mentorship/mentors/<id>`), a member (`/members/<id>`), a company
   (`/companies/<id>`), a conversation (`/messaging?c=<id>`), the inbox, the notifications, an application
   (`/career/applications/<id>`), a requirement you posted (`/manage/requirements/<id>`), a chapter, a council, an event,
   a drawer workspace (the page on screen) and the in-app web view (its page).

The top-most screen with a page wins, so a form or a dialog over a job brings the job back. A new screen that
should come back gets a `SitePlace` with a path that `inAppSiteRoute` opens.

Tests: `test/screen_restore_test.dart` (`restartAndRestore` is Android's restore: the tab, a screen opened by link,
a screen marked by a tap under a dialog and an unmarked form, nothing after every screen is closed, nothing for
another account).
