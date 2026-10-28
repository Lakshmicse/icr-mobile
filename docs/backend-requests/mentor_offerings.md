# Backend request: a resource that already has its file can be saved or resumed without uploading it again

From the mentor desk's Offerings panel (`lib/features/mentor_desk/offerings/`), 26 Oct 2026. One request, additive, with a unit spec. Every web response that works today stays byte for byte what it is.

## What happens today

`PATCH /mentor-services/mine/:id` takes the whole shape (`UpsertMentorServiceDto`). For a `RESOURCE` it refuses `active: true` unless the body carries `uploadId`:

```
PATCH /mentor-services/mine/<a live resource> { "type": "RESOURCE", "title": "Renamed", "pricePaisa": 0, "active": true }
400 "Upload the file before publishing a resource."
```

Proved against the local API (a resource with a stored file: pausing works, **resuming it fails, and so does renaming it while it stays live**). `validateShape` reads `dto.uploadId` only, and the update path never looks at the file the row already holds (`uploadId: dto.uploadId ?? existing.uploadId` is applied one step later, too late for the check). `MentorServiceDto` does not expose `uploadId` (it is private), so no client can send it back: the only way round is to upload the file again.

The website's `ServiceFormDialog` has the same limit (its `uploadId` state starts empty on an edit). The app copes: "Resume" on a resource the API will not publish opens the edit form so the file is chosen again, and the refusal's own sentence is shown.

## The diff

`backend/src/modules/mentor-services/mentor-services-catalog.service.ts`

```diff
-  private validateShape(dto: UpsertMentorServiceDto) {
+  /** [existing] is the stored row on an update: a resource that already has its file keeps it. */
+  private validateShape(dto: UpsertMentorServiceDto, existing?: { uploadId: string | null }) {
 ...
-    if (dto.type === MentorServiceType.RESOURCE && dto.active && !dto.uploadId) {
+    if (dto.type === MentorServiceType.RESOURCE && dto.active && !(dto.uploadId ?? existing?.uploadId)) {
       throw new BadRequestException('Upload the file before publishing a resource.');
     }
```

and in `update(...)`:

```diff
-    this.validateShape(dto);
+    this.validateShape(dto, existing);
```

`create` is unchanged (`this.validateShape(dto)`): a new resource still needs its file to go live.

## Unit spec

`mentor-services-catalog.service.spec.ts` (or the nearest existing spec): an update of a `RESOURCE` row that has `uploadId: 'abc.pdf'` with `{ active: true }` and no `uploadId` succeeds and keeps the file; the same row with no stored file still answers "Upload the file before publishing a resource."; a create with `active: true` and no `uploadId` still answers it.

## Not requested

Nothing else. The app reads `GET /mentor-services/mine`, `GET /mentor-plans/mine`, `GET /mentorship/group-sessions?mine=true` and a session's detail as they are.
