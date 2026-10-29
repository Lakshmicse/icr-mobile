# Digital Library

The Document Hub of the website (`/documents`): `LibraryScreen` (browse, search, filter, sort, My uploads), `DocumentScreen` (one document: who shared it, its files, Preview, report, delete, add files) and `UploadDocumentScreen` (share a document, or add files to your own).

**View-only on a phone (owner's call, 28 Oct 2026).** A document can be previewed in the app and nothing else: **no download, no Open in another app, no share of the file, and no screenshots or screen recording** while any library screen is up. The website keeps its Download. Every format the library accepts has a viewer in the app (see "The viewer"). There is **no design**: it is built in the language of the Councils and Events designs (stat tiles, pill chips, 10 dp bordered cards, Work Sans headings, IBM Plex Sans Medium body) from the website's `frontend/src/components/documents/**` and the portal's `documents` module.

Status (28 Oct 2026): **built and proved**: `test/library_test.dart`, `test/library_document_test.dart` (the page, the upload form, view-only), `test/library_viewer_test.dart` (the viewer, the screenshot guard, the channel), `test/library_office_test.dart` (the Word, Excel, PowerPoint, ZIP and old-format readers, damaged files), `test/live/library_live_test.dart` (live tests against the seeded API). Goldens are postponed (owner's call).

## Entry points (for the lead to wire)

```dart
// The list. Reads a LibraryController from Provider (convention of the other tab screens).
ChangeNotifierProvider<LibraryController>(
  create: (c) => LibraryController(
    sample ? DemoLibraryRepository() : ApiLibraryRepository(api: c.read<ApiClient>()),
  ),
  child: LibraryScreen(
    onBack: () => Navigator.of(ctx).pop(),
    onBell: () => ...,              // optional; the website's /notifications page when null
    onOpenMember: (userId) => ...,  // optional; the uploader's name is not tappable without it
    onOpenPlans: () => ...,         // optional; the lock card has no "See plans" button without it
  ),
)

// One document, by id (a notification, a deep link). No GET /documents/:id exists, so with no `initial`
// the library is read for it (see "What the API cannot do").
Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => documentPage(
  repository: repo,                // ApiLibraryRepository(api: ...) or DemoLibraryRepository()
  documentId: id,
  handoffs: LibraryHandoffs(onBell: ..., onOpenMember: ..., onOpenPlans: ...),
)));
// or openDocumentPage(context, repository:, documentId:, initial: doc, handoffs:, onChanged:, onRemoved:)
```

`LibraryHandoffs` also carries `device` (`LibraryDevice`: choosing files to share and opening a page; `SystemLibraryDevice` by default; **it has no way to take a document out of the app**), `share` (the library's link only), `pdf` (the PDF renderer, `PlatformPdfEngine` by default) and `runner` (reads Office and ZIP files in a background isolate, `runInBackground`; tests use `runHere`). `UploadDocumentScreen(repository:, target:, handoffs:, usedCategories:)` pops with the `LibraryDocument` the API answered with; `LibraryScreen` and `DocumentScreen` open it themselves.

## Endpoints

| Call | Used for |
|---|---|
| `GET /documents?page&limit=24&search&category&fileType&mine=true&sortBy&sortDir` | the list (the website's own parameters); `meta.total` is the count under the heading |
| `GET /documents/categories`, `GET /documents/file-types` | the category and format chips (a format's count is *documents*, not files) |
| `GET /documents?mine=true&limit=1` | the "Your uploads" tile (0 signed out) |
| `GET /documents` (pages of 100, up to 800 documents) | a document opened by id alone: the API has no `GET /documents/:id` |
| `GET /documents/:id/download?fileId=&preview=true` | Preview: the bytes for the in-app viewer, not counted as a download. **The only way the app reads a file**: `LibraryRepository.previewFile` always sends `preview=true`, and no repository method asks for a download. |
| `POST /documents/:id/view` | one opening of the document, counted the first time a file of a page is opened |
| `POST /uploads?purpose=document-hub` (multipart `file`) | one file's bytes, sequentially, with progress |
| `POST /documents` `{title, description?, category?, subcategory?, specialization?, files[]}` | files the entry |
| `POST /documents/:id/files` `{files[]}` | adds files to the member's own document |
| `DELETE /documents/:id/files/:fileId` | drops one file of a pack (the API refuses the last one) |
| `DELETE /documents/:id` | deletes the member's own document (a SUPER_ADMIN may delete any) |
| `POST /documents/:id/report` `{reason, note?}` | reports a document to the ICR admin team |
| `GET /categories/tree` | the platform's three-level taxonomy for the upload form's category pickers |
| `GET /auth/me` | who is signed in, to tell their own documents (and a SUPER_ADMIN) |
| `GET /notifications/unread-count` | the bell's dot |

## What the audit found

1. **The download needs the bearer token, so `url_launcher` cannot open it, and the app does not want it to.** `GET /documents/:id/download` is authenticated and the stored file is private (`/uploads/<name>` refuses anyone but its uploader). The app fetches the bytes with its own session (`?preview=true`) and draws them itself in `DocumentViewerScreen`. Until 28 Oct 2026 a non-image was handed to the share sheet (`LibraryDevice.handOver`, Save to Files, Open in…); that path is **gone**, and so is the signed-link request (`GET /documents/:id/link`), which was only there to open a file in another app. `url_launcher` is still used for the pages the app hands to the website (the bell's fallback).
2. **There is no plan-level lock in this tree.** `SharedDocument.planLevel` exists in the schema, but the documents service neither selects nor enforces it (the content levels left the plans in `06f57b1c`), and the list carries no `locked` field. There is therefore no "content level" filter and no lock on a card. The screen handles the day it returns the way the API would say it: a **403 on a preview** is drawn as a lock card, "Not included in your plan", with the **server's own sentence** and a "See plans" button when the shell wired `onOpenPlans`. A 401 is only a message. Proved with a refused read in `library_document_test.dart` ("a plan that does not open it…"); the live test checks the 401 reading (a lock card is only a 403).
3. **There is no save (bookmark) on a document**: neither the website (`LibraryCard.tsx` says the comp's bookmark "does not exist") nor the API has one. The app does not draw one. The app draws no save (the file itself cannot be kept: there is no download). (Backend request below.)
4. **A report cannot be undone by its sender.** Only a SUPER_ADMIN resolves it (`PATCH /documents/admin/reports/:id`); the live test resolves its report as APPROVED (the document stands). A second report while the first is open is a 409, which the page reads as "Reported". You cannot report your own document (the API says so; the page shows no Report button on it).
5. The two counters are one-way: a download and a first view each add one and nothing subtracts. The live tests use small seeded documents and say so; re-running `tool/seed/library.ts` restores the designed numbers.
6. An **upload leaves its bytes behind** when the document is deleted: there is no route that removes a stored upload.
7. `LIBRARY_KINDS` (Insights, SOPs, Checklists…) is a decoration on the website's banner: the API has no "kind" field. On a phone each is a **quick search** (it types its word into the search box), which the seeded titles and descriptions answer; a kind chip is on while the search equals its word.

## The list

Top to bottom: four tiles (Documents, Categories, Formats, **Your uploads**: tap = My uploads on/off), **Browse by kind** (ten quick-search chips), the search box (typed text searches after a 350 ms pause; the sliders glyph opens **Sort** — Most downloaded (the website's default), Newest, Most viewed, A to Z, Largest — and **Only my uploads**), the **category chips** (All Categories (n) + one per category in use), the **format chips** (All formats + PDF (18), Word (5)…), the heading ("Documents" or "Your uploads", the count pill, **Upload →**), Clear filters while any filter is on, a card per document, **Show more documents** (24 a page), and a "Share what you know" card.

A **card**: the format plate (the first file's badge on its colour; a pack's file count at the corner), title, what it holds ("PDF · 2.4 MB", or "3 files · XLSX, PDF · 541 KB"), two lines of description, its category pill, who shared it (photo, name), views, downloads, the date; "YOURS" on the member's own. Tap opens the page.

Empty ("The library is empty" / "No documents match" + Clear filters / My uploads with none says to share one), failed read ("Couldn't load the library" + Try again; a failed Show more keeps what was read), loading spinner, pull to refresh (list, chips, count, bell).

## The document page

The plate, title and where it is filed (category › sub-category › specialisation), "Shared by <name>" with their title and the date (tap = `onOpenMember`), four tiles (Views, Downloads, Size, Files), the lock card when the server refused (see 2), "About this document", and a card per file: its name, format, size and downloads, and **Preview** (opens the viewer). A file with no viewer (a format the library does not take) shows a line saying so instead of a button. There is **no Download and no Open**. Anyone may **Share** (the phone's share sheet with the library's link) and **Report**; the member who shared it (or a SUPER_ADMIN) also gets **Add files** (while there is room under 10), a remove glyph on each file of a pack (after asking), and **Delete** (after asking). After a read, a file added or dropped, the list behind the page follows (`onChanged`, `onRemoved`).

**Report**: a sheet with the six reasons (Copyright or confidential material, Inappropriate or offensive, Misleading or out of date, Spam or advertising, File is broken or will not open, Something else) and a note of at most 1,000 characters, **required for "Something else"**. Send is off until a reason is chosen. The API's refusal is shown in the sheet with what was typed kept; on success "Report sent" and the page reads "Reported".

## The viewer (view-only)

Preview opens `DocumentViewerScreen` (black bar with the file name and Back, nothing else). The bytes are read for the viewer, drawn, and dropped with the screen; nothing writes them to the phone, shares them or hands them to another app, and no text can be selected or copied. Every format the library accepts for upload has a viewer, chosen by the file's MIME type and, failing that, its name (`previewKindFor`):

| Format | How it is shown | Built on |
|---|---|---|
| PDF | the pages, drawn by **Android's own `PdfRenderer`** through a method channel (`PdfViewerChannel.kt`); page counter, zoom 100 / 150 / 200 / 300 % (sideways scroll when zoomed) | `pdf_engine.dart`. The bytes go into a private cache file that is deleted the moment it is open, so nothing is left on disk. Password-protected and damaged PDFs say so in words. |
| Images (PNG, JPG, WebP, GIF) | zoomable picture | `InteractiveViewer` |
| Text (.txt) | monospace lines (first 20,000) | `ViewerText` |
| CSV | a grid (first 2,000 rows, 40 columns) with a header row; tap a cell for its whole text | `DataGrid`, `csv_rows.dart` |
| Word (.docx) | title, headings, bold / italic / underline, bullets and numbers, tables; pictures show as "[Image]" | `office/docx_reader.dart` |
| Word 97–2003 (.doc, and Word 6/95) | the text in order, tables as rows, field codes left out | `office/doc_reader.dart` over `office/cfb.dart` |
| Excel (.xlsx) | one grid per sheet (tabs when there are several): text, numbers, dates (either date system), percentages, booleans, errors, formula results | `office/xlsx_reader.dart` |
| Excel 97–2003 (.xls) | the same, read from the BIFF8 records | `office/xls_reader.dart` |
| PowerPoint (.pptx) | one card per slide: title, then its lines at their levels; tables as rows | `office/pptx_reader.dart` |
| PowerPoint 97–2003 (.ppt) | the same, following the file's edit history so the current version of each slide is read | `office/ppt_reader.dart` |
| ZIP | the files inside; tap one to open it in the viewer on top (a ZIP in a ZIP too) | `office/zip_reader.dart` |

**An Office preview is the file's text and tables, not its look.** Layout, fonts, colours, pictures, charts, shapes, formulas, comments, headers and footers, and speaker notes are not reproduced, and a slide or document that is only pictures says so. An exact rendering would need a conversion service on the server (see "Left").

**Files are read by what is inside, not by their name** (`office_reader.dart`): a ZIP package is Word, Excel or PowerPoint by the parts it holds, an old binary file by the streams it holds, and text saved under an Office name (an HTML or tab-separated export called ".xls" is common) is shown as text. A password-protected file, a damaged one and one with nothing to show each say so in a sentence; none crashes the screen. Reading runs in a background isolate (`PreviewRunner`), with limits so a huge file cannot freeze the phone (`OfficeLimits`: 2,000 rows, 40 columns, 6,000 blocks, 300 slides, 1,000 archive entries, 25 MB per archive entry).

**Verified against real files.** The readers were run on the library's own seeded Word, Excel, PowerPoint and ZIP files and on about 540 Word, Excel and PowerPoint files from Apache POI's test collection (old and new formats, password-protected, deliberately corrupted): no crash, nothing slower than 2 s, and every refusal was a real one (encrypted, picture-only, damaged). Those collections are not committed; the committed tests use the library's seed files and byte-built fixtures (`test/helpers/office_fixtures.dart`).

## No screenshots

`ScreenGuard` (`screen_security.dart`) wraps `LibraryScreen`, `DocumentScreen` and `DocumentViewerScreen`. While any of them is on screen the window carries Android's **`FLAG_SECURE`** (set from `MainActivity.kt` over the `org.icr.icr_mobile/secure_screen` channel): the system refuses screenshots and screen recording, shows a blank card in the recent-apps list, and keeps the content off non-secure displays. The guard is **counted** (`ScreenSecurity.hold/release`), so the list, a document and the viewer stacking up ask the window once and release it only when the last one leaves. Other platforms are left alone. **It cannot stop a second device photographing the screen.**

## The upload form

The website's dialog as a screen: choose files first (the picker is the phone's; PDF, Word, Excel, PowerPoint, CSV, text, ZIP and images), then describe them. Rules, from the DTO and the dialog: **a title** (required, 200 characters; it starts as the first file's name with the extension off), a description (2,000), **a category** (required, 60: the platform's level-1 labels, then what the library already uses, then "Other (add your own)" to type one), an optional **sub-category** and **specialisation** from the tree under the one above (80 each, "Other" at the foot; under your own category they are typed), **one to ten files of at most 10 MB**, a format the library takes, no twins (same name and size). A file's name is edited in its base only (the extension stays; a path separator is swapped; empty falls back to the original). Sending uploads each file one at a time (a progress bar, "Uploading 2 of 3…"), then files the document. A refusal is shown under the form, everything stays, and a retry does not send a file that already went up. Back with something typed asks "Discard this upload?".

**Add files** (append mode, from your own document's page) asks only for files and says "They join “<title>”"; the room is 10 minus the files it has.

## Controls and the tests that prove them

`W` = `library_test.dart`, `D` = `library_document_test.dart`, `V` = `library_viewer_test.dart`, `O` = `library_office_test.dart`, `L` = `test/live/library_live_test.dart`.

| Control | Proved by |
|---|---|
| tiles, kind chips, chips, cards from the API | W "draws the tiles…", "the list is the API's page…"; L "the list is the API's…" |
| Back, bell (the shell's or the website's), bell dot | W "Back and the bell", "the bell wears its dot…" |
| search (waits for a pause), clear, Clear filters | W "the search runs on a pause…"; L "the filters, the kind searches and every sort…" |
| kind chips (type their word, again takes it out) | W "a kind chip types its word…"; W controller "a kind chip is a quick search…"; L every kind finds something |
| category and format chips | W "a category chip and a format chip narrow the cards…"; L the same live test |
| sort sheet (five sorts), Only my uploads, Reset | W "the sliders glyph opens the sorts…"; L every sort checked in order |
| Your uploads tile | W "the Your uploads tile is My uploads…"; L "Show more pages the library…" |
| Show more documents | W "Show more documents appends the next page"; L the same |
| card → document page; delete on the page leaves the list | W "a card opens the document's page", "a document deleted on its page leaves the list behind it" |
| Upload (heading and host card) → form → the list gains the document | W "Upload opens the form…", "the host card is the same Upload" |
| empty / failed / loading / pull to refresh | W the four matching tests |
| document page from the document in hand or by id; 404 + Try again | D "draws who shared it…", "opened by id alone…"; L "a document is found by id…" |
| uploader → profile; Share; pull to refresh | D the three tests |
| Preview (the viewer's read, not a download, one view counted once) | D "Preview reads the file for the viewer…"; L "the viewer reads the real bytes…", "every format of a pack opens…" |
| no Download, no Open, no file share anywhere | D "nothing on the page can save or hand a file over…"; V "it has no download, share or save control for any kind of file" |
| image Preview in the app, no Download glyph | D "an image opens in the app…" |
| screenshots blocked while a library screen is up (counted) | D "the document page and the viewer keep the window out of screenshots…"; V "screen protection is counted…", "asks the phone for the flag on Android…" |
| PDF pages, zoom, page counter, password / damaged | V the "PDF" group (including the channel protocol) |
| image, text, CSV, Word, Excel, PowerPoint, ZIP viewers | V "images, text and CSV", "Word, Excel, PowerPoint and ZIP" |
| every reader, old and new formats, damaged input | O `library_office_test.dart` |
| a phone with nothing to open the file | D "a phone with nothing to open the file says so" |
| the lock card (403) in the server's words, See plans; a 401 is a message | D "a plan that does not open it…", "the lock card has no button…"; L "signed out, a preview and a download are the API's 401…" |
| Report: reasons, note required for Something else, 409, refusal and retry | D the five "reporting" tests; L "a report…" (the admin queue holds it; resolved APPROVED) |
| no Report on your own; Delete/Add files/remove only for the owner or an admin | D "a document of my own has no Report", "a SUPER_ADMIN may…", "a signed-out reader…"; L "a member cannot report their own…", "a SUPER_ADMIN may change any…" |
| Delete (asks first, refusal shown), remove a file (asks; the last is refused) | D "Delete asks first…", "a refused delete…", "a file of a pack can be dropped…"; L "sharing a document…" |
| Add files → form in append mode → the page shows the new file | D "Add files opens the upload form…"; L "sharing a document…" |
| upload form: the rules (formats, 10 MB, twins, ten files, rename, per-field problems) | D "the upload form's rules" group (11 tests) |
| upload form screen: pick, rename, remove, pickers, Other, progress, refusal and retry, Discard | D "the upload form's screen" group (10 tests); L "sharing a document…", "the API refuses a format…" |
| the API's own limits and routes | W "the API mapping" group (13 tests) |

## Seed

`tool/seed/library.ts` (see `tool/seed/README.md`): 31 documents with real files, six packs, every format; Bharat 3 (one a 3-file pack) and Pooja 2; two pending reports. The files are made by `tool/seed/make_seed_files.py` from `seed_content_pdf.py`.

## Demo content

`DemoLibraryRepository` holds twelve sample documents (the member owns three), every format, with reports, uploads, deletions and counts kept in memory; a preview returns a 1-pixel picture for an image, a real one-page PDF (so the phone's renderer has something to draw) for a PDF, and a line of sample text for any other format.

## Handoffs kept

| Handoff | Why |
|---|---|
| Notifications (when `onBell` is null) | the shell opens its own screen; the website page is the fallback |
| *(none for files)* | a document never leaves the app; the share sheet carries only the library's link |

## Left

- **An exact rendering of Word, Excel and PowerPoint** (layout, pictures, charts) would need the server to convert them to PDF (for example LibreOffice behind a preview-only route) so the PDF viewer can show them. Not built; the in-app readers show text and tables.
- Bookmarks (backend request). The signed-link request is withdrawn: the library no longer opens files in other apps.
- iOS: the PDF renderer and the screenshot flag exist on Android only; on iOS a PDF says it cannot be previewed yet and screenshots are not blocked.
- A "content level" filter and a lock on cards, if the API brings the field back.
