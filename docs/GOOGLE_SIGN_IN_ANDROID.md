# Google / LinkedIn sign-in on Android, against the server as deployed

No backend change is needed. The API's callback sends the browser back to the
website (`https://icr.org.in/auth/callback?code=…`), the website swaps that
one-time code for tokens, and the app does the same: it takes the return
address from Chrome's **Auth Tab** (`flutter_web_auth_2` 5.x,
`SocialFlow.website` in `lib/core/auth/social_sign_in.dart`) and posts the code
to `POST /auth/social/exchange` (the website's own call, no secret).

## What Android needs: the website has to vouch for the app

Chrome hands an `https` address to an app only when the site says the app is
its own (Digital Asset Links). So `icr.org.in` must serve

    https://icr.org.in/.well-known/assetlinks.json

The file is in the portal: `frontend/public/.well-known/assetlinks.json` (a
static file, served by the frontend as-is). It names `org.icr.icr_mobile` and
the SHA-256 of the key the APK is signed with. **Until the frontend carrying it
is deployed, Google sign-in from the app cannot come back to the app** (it ends
on the website's page, which is what happened before).

The fingerprint in the file is the debug key of the machine that builds the
APK (`~/.android/debug.keystore`; `release` builds are signed with it too until
a release key exists). Add the Play / release key's fingerprint to the same
list when there is one:

    keytool -list -v -keystore <keystore> -alias <alias>   # SHA256 line

## Checking it

    curl -s https://icr.org.in/.well-known/assetlinks.json          # the file, as JSON
    adb shell pm verify-app-links --re-verify org.icr.icr_mobile
    adb shell pm get-app-links org.icr.icr_mobile                    # icr.org.in: verified

Chrome 137 or newer uses the Auth Tab; an older Chrome opens a normal tab and
the sign-in ends on the website.

## What the person sees

- Someone with an ICR account (the common case): Google, back to the app,
  signed in.
- Someone new to ICR: the website's `/register?social=…` page is a different
  address, so it opens in the tab; they finish sign-up there (or close the tab).
  The app's own short sign-up with Google is for the day the mobile addition to
  the API is deployed (`--dart-define=SOCIAL_FLOW=app`, the default against a
  local API).
- A refusal (`/login?error=…`) shows the website's own sentence in the tab.
