# Backend requests: messaging and notifications

The portal is the lead's to change. Every item is additive and leaves each existing web response unchanged. The app works without them: where one is missing the control does the nearest true thing (named below).

## 1. A message to another PERSON writes no bell row (a bug in `othersThan`)

**What happens.** A person writing in a thread of people (a plain thread, a mentoring thread, a group room: every thread whose readers are `participants`, with no company party) notifies nobody. Reproduce with two seeded accounts and a plain thread: `POST /messaging/conversations/<id>/messages` as one, then `GET /notifications` as the other. Empty, however many messages are sent. The recipient's *message badge* is right (it counts unread messages, not notifications) and the live socket push is right (`everyoneBut`); only the bell row (and its grouping, "sent you 3 messages") is missing. A message between a person and a company inbox does notify (checked: a persona's enquiry to a supplier gives each of its sellers a row), which is why the company-inbox work did not show it.

**Why.** `sendMessage` calls `notifyOthers(..., othersThan(audience, side, userId), ...)`. `othersThan` drops the whole audience entry of the writer's own side. For a person writing as themselves the side is `null`, and `null` is also the key of every other participant, so they are dropped with the writer (`backend/src/modules/messaging/conversation-access.ts`):

```ts
export function othersThan(audience: Map<Side, string[]>, side: Side, exceptUserId: string): string[] {
  const ids = [...audience].filter(([s]) => s !== side).flatMap(([, ids]) => ids);
  return [...new Set(ids)].filter((id) => id !== exceptUserId);
}
```

**The fix.** Keep the writer's own side only when it is the people's side, because the people on it are each other's other side (the writer is removed by `exceptUserId`). A company side stays dropped (its colleagues already see the push; they are not "news"):

```ts
export function othersThan(audience: Map<Side, string[]>, side: Side, exceptUserId: string): string[] {
  // The writer's own company is not told; the people in the thread as themselves are told about each other.
  const ids = [...audience].filter(([s]) => s !== side || s === null).flatMap(([, ids]) => ids);
  return [...new Set(ids)].filter((id) => id !== exceptUserId);
}
```

**Spec** (`company-inbox.spec.ts`, beside "tells the other side…"): the existing two expectations still hold (`['member']` and `['s1', 's2']`, because `member` is the only participant). Add:

```ts
it('tells the other people in a thread of people', async () => {
  const audience = await audienceOf(db([]) as never, { participantIds: ['a', 'b', 'c'], parties: [] });
  expect(othersThan(audience, null, 'a')).toEqual(['b', 'c']);
});
```

**Until then.** The app's bell and Messages badge are driven by what the API counts, so a plain-thread message still lights the Messages badge; it just has no row in Notifications. The live test (`test/live/notifications_live_test.dart`) generates its bell rows through a company inbox, which does notify.

## 2. The notification list could name each row's target (optional; the app reads it from the page today)

`GET /notifications` sends only `link` (the page `notificationHref` made). The app turns it back into the target's kind and ids (`NotificationTarget.parse`, tested against every kind in `notification-targets.ts` and against the real rows), so nothing is missing; a `target: { kind, id }` beside `link` (from the row's `targetKind`/`targetId`, already stored) would let the app stop parsing paths and would make `PATCH /notifications/seen` calls unambiguous. Additive: `toNotificationDto` adds `target: row.targetKind ? { kind: row.targetKind, id: row.targetId } : null`; the web ignores it.

## 3. Not a request: the socket

The app has no socket.io client (`socket_io_client` is not in `pubspec.yaml`), so it polls (open thread 4 s, list 30 s, bell 60 s) and has no typing indicator. See `docs/screens/messaging.md` → "Not done".
