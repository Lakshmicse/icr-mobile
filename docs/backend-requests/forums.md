# Backend requests: Forums (additive only; nothing here is needed for what is built)

The app's forum screens work on the portal as it is today, against every route they use (proved by
`test/live/forum_live_test.dart`). The four items below would make four small things truer. Each is **additive**: a new
optional field or query parameter, so every web response stays byte-for-byte what it is today. None has been applied
(the portal is not edited from the app); each comes with the spec it would need.

## 1. "Following" and "Polls" as the forum's own filters (`GET /forum/threads`)

Today the website has no such filter, so the app's Following and Polls views read the latest 100 discussions and keep the
matching ones client-side (`ApiForumRepository.threads`): they cannot page, and a poll or a followed author's discussion
older than the latest 100 is never listed.

```ts
// forum/dto/forum.dto.ts  ForumThreadQueryDto
@ApiPropertyOptional({ description: 'Only threads by members the caller follows.' })
@IsOptional()
@Transform(({ obj }) => obj.followingOnly === true || obj.followingOnly === 'true')
@IsBoolean()
followingOnly?: boolean;

@ApiPropertyOptional({ description: 'Only threads that carry a poll.' })
@IsOptional()
@Transform(({ obj }) => obj.hasPoll === true || obj.hasPoll === 'true')
@IsBoolean()
hasPoll?: boolean;

// forum-threads.service.ts  list(): after the existing filters
if (query.hasPoll) where.poll = { isNot: null };
if (query.followingOnly) {
  if (!viewer) throw new ForbiddenException('Sign in to see the people you follow.');
  where.author = { followers: { some: { followerId: viewer.id } } };
}
```
Unit spec: `list({ hasPoll: true })` filters to threads with a poll; `list({ followingOnly: true })` as a signed-out
viewer is a 403 and as a member returns only followed authors' threads.

## 2. An edited reply says so (`ForumReplyDto.editedAt`)

`updatedAt` moves when anyone likes a reply (`bumpCounts` updates the row), so the app cannot tell an edited reply from a
liked one and shows "(edited)" only for a reply edited in the session.

```ts
// schema: ForumReply.editedAt DateTime? (migration: nullable column)
// forum-replies.service.ts update(): data: { bodyHtml, editedAt: new Date() }
// forum.mappers.ts toForumReplyFlat(): editedAt: row.editedAt?.toISOString() ?? null
// packages/shared dto.ts ForumReplyDto: editedAt?: string | null
```
Spec: `update` sets `editedAt`; a vote does not.

## 3. Taking a file off a discussion when editing it

`UpdateForumThreadDto` cannot clear the attachment (`uploadId` is a string, and an absent field means "unchanged"), so
the app's editor can replace a discussion's file but never remove it.

```ts
// UpdateForumThreadDto
@ApiPropertyOptional() @IsOptional() @Transform(({ obj }) => obj.removeAttachment === true || obj.removeAttachment === 'true')
@IsBoolean() removeAttachment?: boolean;

// forum-threads.service.ts update(): data: { ..., ...(dto.removeAttachment && { uploadId: null, fileName: null, fileSize: null }) }
```
Spec: `update(user, id, { removeAttachment: true })` nulls the three columns; an edit without it leaves them.

## 4. A poll's closing time (`ForumPollDto.closesAt`)

The Home design draws "842 votes • 2 days left"; the poll has no closing date, so the app prints "Open" or "Closed".
Optional `closesAt` on `ForumPoll` (and on `CreateForumThreadDto.pollCloses`), `votePoll` refusing after it. Until it
exists nothing in the app is wrong: it says what it knows.
