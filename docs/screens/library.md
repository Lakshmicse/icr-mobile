# Digital Library

The Document Hub of the website (`/documents`): `LibraryScreen` (browse, search, filter, sort, My uploads), `DocumentScreen` (one document: who shared it, its files, Preview, Download, Share, report, delete, add files) and `UploadDocumentScreen` (share a document, or add files to your own).

**Download, Share and screenshots, as on the website (owner, 5 Nov 2026).** Each file can be previewed in the app, **downloaded** (the phone's "Save as", counted by the API as the website's Download is) and **shared** (the file itself to the share sheet). Screenshots and screen recording are allowed everywhere. This undoes the owner's call of 28 Oct 2026, when the library was view-only on a phone and the window was kept out of screenshots (`FLAG_SECURE`); that guard and its channel are gone. Every format the library accepts has a viewer in the app (see "The viewer"). There is **no design**: it is built in the language of the Councils and Events designs (stat tiles, pill chips, 10 dp bordered cards, Work Sans headings, IBM Plex Sans Medium body) from the website's `frontend/src/components/documents/**` and the portal's `documents` module.

Status (28 Oct 2026): **built and proved**: `test/library_test.dart`, `test/library_document_test.dart` (the page, the upload form, Download and Share), `test/library_viewer_test.dart` (the viewer and its Download and Share), `test/library_office_test.dart` (the Word, Excel, PowerPoint, ZIP and old-format readers, damaged files), `test/live/library_live_test.dart` (live tests against the seeded API). Goldens are postponed (owner's call).

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

`LibraryHandoffs` also carries `device` (`LibraryDevice`: choosing files to share, opening a page, `save` (the "Save as" sheet) and `shareFile` (a file to the share sheet); `SystemLibraryDevice` by default), `share` (the library's link, the page's top Share), `pdf` (the PDF renderer, `PlatformPdfEngine` by default) and `runner` (reads Office and ZIP files in a background isolate, `runInBackground`; tests use `runHere`). `UploadDocumentScreen(repository:, target:, handoffs:, usedCategories:)` pops with the `LibraryDocument` the API answered with; `LibraryScreen` and `DocumentScreen` open it themselves.

## Endpoints

| Call | Used for |
|---|---|
| `GET /documents?page&limit=24&search&category&fileType&mine=true&sortBy&sortDir` | the list (the website's own parameters); `meta.total` is the count under the heading |
| `GET /documents/categories`, `GET /documents/file-types` | the category and format chips (a format's count is *documents*, not files) |
| `GET /documents?mine=true&limit=1` | the "Your uploads" tile (0 signed out) |
| `GET /documents` (pages of 100, up to 800 documents) | a document opened by id alone: the API has no `GET /documents/:id` |
| `GET /documents/:id/download?fileId=&preview=true` | Preview: the bytes for the in-app viewer, not counted as a download (`LibraryRepository.previewFile`). |
| `GET /documents/:id/download?fileId=` | Download and Share: the file, counted on the file and the document (`LibraryRepository.downloadFile`); the page's counts follow at once. |
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

1. **The download needs the bearer token, so `url_launcher` cannot open it, and the app does not want it to.** `GET /documents/:id/download` is authenticated and the stored file is private (`/uploads/<name>` refuses anyone but its uploader). The app fetches the bytes with its own session and draws them itself in `DocumentViewerScreen` (`?preview=true`), or saves or shares them (a counted download). The signed-link request (`GET /documents/:id/link`) is not used. `url_launcher` is still used for the pages the app hands to the website (the bell's fallback).
2. **There is no plan-level lock in this tree.** `SharedDocument.planLevel` exists in the schema, but the documents service neither selects nor enforces it (the content levels left the plans in `06f57b1c`), and the list carries no `locked` field. There is therefore no "content level" filter and no lock on a card. The screen handles the day it returns the way the API would say it: a **403 on a preview** is drawn as a lock card, "Not included in your plan", with the **server's own sentence** and a "See plans" button when the shell wired `onOpenPlans`. A 401 is only a message. Proved with a refused read in `library_document_test.dart` ("a plan that does not open it…"); the live test checks the 401 reading (a lock card is only a 403).
3. **There is no save (bookmark) on a document**: neither the website (`LibraryCard.tsx` says the comp's bookmark "does not exist") nor the API has one. The app does not draw one. The app draws no bookmark; the file itself is kept with Download. (Backend request below.)
4. **A report cannot be undone by its sender.** Only a SUPER_ADMIN resolves it (`PATCH /documents/admin/reports/:id`); the live test resolves its report as APPROVED (the document stands). A second report while the first is open is a 409, which the page reads as "Reported". You cannot report your own document (the API says so; the page shows no Report button on it).
5. The two counters are one-way: a download and a first view each add one and nothing subtracts. The live tests use small seeded documents and say so; re-running `tool/seed/library.ts` restores the designed numbers.
6. An **upload leaves its bytes behind** when the document is deleted: there is no route that removes a stored upload.
7. `LIBRARY_KINDS` (Insights, SOPs, Checklists…) is a decoration on the website's banner: the API has no "kind" field. On a phone each is a **quick search** (it types its word into the search box), which the seeded titles and descriptions answer; a kind chip is on while the search equals its word.

## The list

Top to bottom: four tiles (Documents, Categories, Formats, **Your uploads**: tap = My uploads on/off), **Browse by kind** (ten quick-search chips), the search box (typed text searches after a 350 ms pause; the sliders glyph opens **Sort** — Most downloaded (the website's default), Newest, Most viewed, A to Z, Largest — and **Only my uploads**), the **category chips** (All Categories (n) + one per category in use), the **format chips** (All formats + PDF (18), Word (5)…), the heading ("Documents" or "Your uploads", the count pill, **Upload →**), Clear filters while any filter is on, a card per document, **Show more documents** (24 a page), and a "Share what you know" card.

A **card**: the format plate (the first file's badge on its colour; a pack's file count at the corner), title, what it holds ("PDF · 2.4 MB", or "3 files · XLSX, PDF · 541 KB"), two lines of description, its category pill, who shared it (photo, name), views, downloads, the date; "YOURS" on the member's own. Tap opens the page.

Empty ("The library is empty" / "No documents match" + Clear filters / My uploads with none says to share one), failed read ("Couldn't load the library" + Try again; a failed Show more keeps what was read), loading spinner, pull to refresh (list, chips, count, bell).

## The document page

The plate, title and where it is filed (category › sub-category › specialisation), "Shared by <name>" with their title and the date (tap = `onOpenMember`), four tiles (Views, Downloads, Size, Files), the lock card when the server refused (see 2), "About this document", and a card per file: its name, format, size and downloads, **Preview** (opens the viewer), **Download** (saved through "Save as"; "Saved <name>." when it is) and a **Share** glyph (the file itself). A file with no viewer says "… can't be previewed in the app. Download it to read it." (the website's words) and keeps Download and Share. Anyone may **Share** the page (the phone's share sheet with the library's link) and **Report**; the member who shared it (or a SUPER_ADMIN) also gets **Add files** (while there is room under 10), a remove glyph on each file of a pack (after asking), and **Delete** (after asking). After a read, a file added or dropped, the list behind the page follows (`onChanged`, `onRemoved`).

**Report**: a sheet with the six reasons (Copyright or confidential material, Inappropriate or offensive, Misleading or out of date, Spam or advertising, File is broken or will not open, Something else) and a note of at most 1,000 characters, **required for "Something else"**. Send is off until a reason is chosen. The API's refusal is shown in the sheet with what was typed kept; on success "Report sent" and the page reads "Reported".

## The viewer

Preview opens `DocumentViewerScreen` (black bar with the file name, Back, **Download** and **Share**; from a document's page both fetch the file as a counted download, elsewhere — a résumé, a course brochure, a file inside a ZIP — they save and send the bytes shown). Every format the library accepts for upload has a viewer, chosen by the file's MIME type and, failing that, its name (`previewKindFor`):

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

## Screenshots

Allowed. Until 5 Nov 2026 a `ScreenGuard` (`screen_security.dart`) kept the window out of screenshots and screen recording (Android's `FLAG_SECURE`, over the `org.icr.icr_mobile/secure_screen` channel) while a library screen was up; the owner had it taken off with the view-only rule, and the guard, the channel and `MainActivity.kt`'s handler are gone.

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
| Download (counted, Save as, counts follow), a cancelled save, a refused download | D "Download fetches the file as a counted download…", "a cancelled \"Save as\"…", "a refused download…" |
| Share a file vs Share the page's link | D "Share on a file sends the file itself…" |
| the viewer's Download and Share (counted from a document; the bytes shown elsewhere) | D "the viewer has Download and Share…"; V the "Download and Share" group |
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

## 13 Nov 2026: copy refined to the client's standard

The client marked up the user manual with the wording wanted on a dozen screens and asked for the rest of the app to read the same way: Title Case for what a person taps or reads as a label, a short sentence with a full stop for everything else, plain international English, no dash inside a sentence. Wording only: no layout, colour or behaviour changed. Semantics-only labels (what a screen reader says for an icon) were left as they were. By the lead's ruling the title of an empty, locked or error state is a heading (Title Case, no full stop) with a sentence under it, and the retry button reads **Try Again** everywhere.

| Where | Old | New |
|---|---|---|
| Headings, buttons, chips to Title Case (17) | Browse by kind · Quick searches · All formats · Clear filters · Sort and filter · Sort by · Show documents · Edit document · About this document · Add files · Upload a document · Add more · File name · Report this document · Report sent · Send report · Not included in your plan | Browse by Kind · Quick Searches · All Formats · Clear Filters · Sort and Filter · Sort By · Show Documents · Edit Document · About This Document · Add Files · Upload a Document · Add More · File Name · Report This Document · Report Sent · Send Report · Not Included in Your Plan |
| More of the list | Show more documents | View More |
| The plan lock's button | See plans | View Plans |
| Not loaded | Couldn't load the library · Couldn't load this document · Could not open that file. · Could not download that file. · That didn't work. Try again. | Unable to Load the Library · Unable to Load This Document (titles, with **Try Again**) · Unable to open this file. · Unable to download this file. · Something went wrong. Try again. |
| A read already running | Please wait. | Wait a moment. |
| After an upload | "x" is in the library. | "x" was added to the library. |
| No match | No documents match | No Documents Match |
| Editing | hint "What it is and who it is for" · A title is needed. | Describe the document and who it is for. · Enter a title. |
| Deleting | It leaves the library for everyone, and its 3 files with it. This cannot be undone. · The rest of the document stays. | It will be removed from the library for everyone, with its 3 files. This cannot be undone. · The rest of the document will remain. |
| No description | The person who shared this did not add a description. | No description added. |
| A file with no preview | …can't be previewed in the app. Download it to read it. | …can't be previewed in the app. Download the file to read it. |
| Zoom (tooltips) | Zoom out · Zoom in | Zoom Out · Zoom In |
| Report reasons | Copyright or confidential material · Inappropriate or offensive · Misleading or out of date · Spam or advertising · File is broken or will not open · Something else | Copyright or Confidential Material · Inappropriate or Offensive · Misleading or Out of Date · Spam or Advertising · Damaged or Unreadable File · Something Else |
| The report sheet | What is wrong? (required) · Add a note (optional) · hint "A page number, a link, anything that helps the admin check it" | What is wrong? (Required) · Add a Note (Optional) · A page number, a link or other details that help the admin review it. |
| The report's thanks | Thanks. Your report on "x" is with the ICR admin team, who will look at it. The person who shared it is not told who reported it. | Thank you. The ICR admin team will review your report on "x". The person who shared it will not be told who reported it. |
| Upload: the picker | Choose a file · Choose files / PDF, Word, Excel, PowerPoint, CSV, images or a ZIP — up to 10 MB each / Pick several to file them under one title. | Select a File · Select Files / PDF, Word, Excel, PowerPoint, CSV, images or ZIP. Up to 10 MB each. / Select several files to group them under one title. |
| Upload: progress | Uploading x — 40% (1 of 3) | Uploading x: 40% (1 of 3) |
| Upload: adding to a document | They join "x", under the same description and category. · That is the 10-file limit for one document. | These files will be added to "x", with the same description and category. · You have reached the 10-file limit for one document. |
| Upload: helpers | One title for the whole set — what someone would search for. · What it is and when someone would reach for it. · Groups the document under a filter chip. · Rename it if you like — this is the name members see and download. | One title for all files. Use words people would search for. · Describe what it is and when to use it. · Used to group and filter documents. · You can rename it. Members see and download this name. |
| Upload: category fields | Your category * · Sub-category (optional) · Your sub-category · Specialization (optional) · Your specialization · Other (add your own) | Your Category * · Sub-category (Optional) · Your Sub-category · Specialization (Optional) · Your Specialization · Other (Add Your Own) |
| Upload: the pickers' hints | Narrow it down · Nothing listed under this category · Narrow it further · Nothing listed under this sub-category | Select a sub-category · No sub-categories in this category · Select a specialization · No specializations in this sub-category |
| Upload: refusals | x is not a format the library takes · x — the limit is 10 files · Choose at least one file. · …has too long a name (255 characters at most). · Give the document a title. · Type the category. · Choose a category. | x is not a supported format · x: the limit is 10 files · Select at least one file. · …has a name that is too long (maximum 255 characters). · Enter a title for the document. · Enter the category. · Select a category. |

Kept: **My Contributions**, **All Resources**, **Upload Resource**, **Start Building Your Library**, **Upload Your First Resource** and the empty library's sentence (the client's 12 Nov words); the ten Browse by Kind chips (search terms); the viewers' "This … can't be shown / read / previewed" sentences, which already say one plain thing each.
