# Backend requests: account (profile, member pages, settings, companies, sign-up)

**None are needed.** Every screen of this feature runs on what the API serves today, checked against the running API with `test/live/account_live_test.dart`. Nothing in the portal was touched.

Two things the app works around, both additive and optional if the lead ever wants them:

1. **`GET /users/me/profile` does not carry `emailVerified` or `locale`.** The profile's blue tick reads `emailVerified` from the session (`GET /auth/me`, which `AuthController` already holds), and Settings reads the language from `GET /auth/me` (`locale`) through `AccountRepository.accountLocale()`. If the profile payload's `user` carried both, the page could stop depending on the session for the tick. Additive: add `emailVerifiedAt: Date | null` (or `emailVerified: boolean`) and `locale: string | null` to the `user` select of `UsersService.getMyProfile`. The web response would gain two fields it ignores.
2. **`SessionUser` ignores `phone` / `phoneVerified`,** which `/auth/me` already returns. The phone-needed helper (`askForPhone`, `PhoneNeededController`) therefore asks `GET /users/me/profile` once per use. If the lead adds `phone` to `SessionUser` (core), `PhoneNeededController.lookup` can read it from the session with no call. No backend change.

## Things that cannot be undone through the API (the live tests say so, `tool/seed/account.ts` cleans up)

- A phone confirmed by code (`phoneVerifiedAt` stays): `account.ts` resets the persona's number.
- An uploaded file (avatar, cover, credential scan) stays on disk after the row that held it is cleared.
- `DELETE /users/me` anonymises the row (`deleted-<id>@icr.invalid`), it does not delete it; the live test's throwaway people are removed by `account.ts --cleanup-live` (users whose email ends `@account-live.icr.test` or whose slug starts `acctlive-tester`, the companies named `Account Live Test Co …`, contact messages from that domain).
- A conversation opened with "Message" is reused by the next run.
- A company founded has no delete endpoint (founders cannot leave), so the live test's companies are removed by the seed.

## Rate limits the live tests respect (per IP, per window)

`POST /auth/forgot-password` 5 an hour, `POST /auth/email/send-code` 20 an hour, `POST /auth/register` 10 a minute, `POST /contact` 5 a minute. A full run of `account_live_test.dart` uses 1, 11, 11 and 1.
