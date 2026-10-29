# Backend requests: Chapters, Digital Library, Get Involved & Volunteer

Additive only: every web response stays byte-for-byte what it is today. Each comes with the app's workaround, so nothing waits on them. Written 26 Oct 2026 after reading `backend/src/modules/association`, `documents`, `marketing` and `mentorship`.

## 1. `GET /documents/:id` (one document's card)

The documents module has no read of a single document. A screen opened by id alone (a notification, a deep link) makes the app read the library in pages of 100 (up to 800 documents) until it finds the id. Same `CARD_SELECT` and `toCard` as `list`, public with `OptionalJwtAuthGuard`, 404 `'Document not found'` for a deleted one. Declared **after** `categories`, `file-types` and `admin/reports` and before the `:id/*` routes.

```ts
// documents.controller.ts
@Public()
@UseGuards(OptionalJwtAuthGuard)
@Get(':id')
detail(@Param('id') id: string) {
  return this.documents.detail(id);
}
// documents.service.ts
async detail(id: string) {
  const row = await this.prisma.sharedDocument.findFirst({ where: { id, deletedAt: null }, select: CARD_SELECT });
  if (!row) throw new NotFoundException('Document not found');
  return toCard(row);
}
```

Unit spec: returns the card for a live document, 404 for a soft-deleted one, never returns `fileUrl`.

## 2. ~~A short-lived link to a download~~ — withdrawn, 28 Oct 2026

The Digital Library is now view-only on the phone (no download, no hand-over to other apps), so the app has no use for a link a browser or another viewer could open. Kept below for the record.

### Original request: a short-lived link to a download (so a document can open in the phone's own viewer)

`GET /documents/:id/download` needs the bearer token and the stored file is private, so `url_launcher` (which the brief asked for) cannot open it: the app fetches the bytes with its session and hands them to the share sheet instead. A signed, expiring link would let the phone open the file directly in a viewer:

```
GET /documents/:id/link?fileId=<id>&preview=true   (bearer)  ->  { url, expiresAt }
GET /documents/:id/download?fileId=&preview=&token=<signed>  (no bearer; the token proves who asked)
```

`url` is the download route with an HMAC token (`sub`, document, file, `preview`, 5 minute expiry); the download route accepts either the bearer or a valid token. A download through a token counts like any other; a preview does not. Unit spec: expired token refused, a token for another document or file refused, a token for a deleted document 404.

## 3. Saving a document

Neither the website nor the API can save (bookmark) a library document: `LibraryCard.tsx` says the comp's bookmark "does not exist". The app draws none. If ICR wants it:

```prisma
model DocumentSave {
  documentId String
  userId     String
  createdAt  DateTime @default(now())
  document   SharedDocument @relation(fields: [documentId], references: [id], onDelete: Cascade)
  user       User           @relation(fields: [userId], references: [id], onDelete: Cascade)
  @@id([documentId, userId])
  @@index([userId])
}
```

`POST|DELETE /documents/:id/save` (idempotent), `GET /documents?saved=true` (the caller's, like `mine`), and `saved: boolean` on each card for a signed-in caller (omitted signed out, so the public response is unchanged). The "Saved Items & Jobs" screen can then list them.

## 4. The content-level lock on documents, if it returns

`SharedDocument.planLevel` is in the schema but the service neither selects nor enforces it (the content levels left the plans in `06f57b1c`), so the list has no `locked` flag and a download is never refused for a plan. If it returns, the app needs two things and nothing else: a **403 with the sentence to show** on `GET /documents/:id/download` (it draws it as a lock card), and, to draw a lock on the card before the tap, `locked: true` and `lockMessage` on the card for a signed-in caller.

## 5. `GET /chapters/:slug` lists invite-only events

`upcomingEventsInclude` (association.mappers) does not apply `visibleEventsWhere(viewerId)` that `GET /events` does, and `GET /chapters/:slug` is `@Public()` with no optional auth, so the page (and the app's preview sheet) list an invite-only event to someone who was not asked. The app marks the row "INVITE ONLY" and shows the API's refusal on RSVP ("This event is invite-only."). The fix changes the web page too (it would stop listing closed events to strangers), so it is the lead's call: add `@UseGuards(OptionalJwtAuthGuard)` to `detail` and pass `viewerId` into `upcomingEventsInclude`.

## 6. Volunteer applications

There is no volunteer endpoint: the website links to the contact form with `topic=VOLUNTEER`, and the app sends the same `POST /contact` with the role, time and chapter composed into the message. If ICR wants applications as data:

```
POST /volunteer/applications   { roleKey, chapterId?, message, phone? }   (bearer)
GET  /volunteer/applications/mine                                          (bearer)  -> [{ id, roleKey, chapterId, status, createdAt }]
```

plus a `CpdSource.VOLUNTEER` so approved volunteer hours show as "Volunteering" on the CPD card instead of "Manually recorded". The app's Get Involved screen would then show the member's own applications and their status (today it can only say "Interest sent" for the visit).
