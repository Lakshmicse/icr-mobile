# Learning: the exam (brief, exam window, result, My attempts, My certificates)

There is no PNG for these screens. The reference is the website's Learning Center (`PaperBrief`, `PaperUnlock`, `ExamWindow`, `PaperExam`, `SubmitOverviewDialog`, `ResultSummary`, `AttemptSummary`, `MyAttempts`, `Certificate`, `CertificatePage`, `MyCertificatesPage`, `CertificateVerify`) and the API (`learning.service.ts` `getPaperForCandidate` / `submitAttempt` / `getMyAttempt`, `SubmitAttemptDto`, `paper-checkout.service.ts`, `learning-plan-access.service.ts`), done as a phone does it. Code: `lib/features/learning_exam/`. Tests: `test/learning_exam_test.dart` (logic, 71), `test/learning_exam_screen_test.dart` (screens, 124), `test/golden/learning_exam_golden_test.dart` (15 goldens at 390 x 844), `test/live/learning_exam_live_test.dart` (16, against the local API); fakes and recorded API answers in `test/learning_exam_fakes.dart` and `test/fixtures/learning_exam/`. Data: `tool/seed/learning-flows.ts`.

## How it is entered

* `Future<void> openPaper(BuildContext context, PaperRef paper, {ExamRepository? repository})` (`open_paper.dart`; `PaperRef` and the call are as the stub had them, `repository` is a seam for tests). It builds its own repository (`AppConfig.demo ? DemoExamRepository() : ApiExamRepository(api: context.read<ApiClient>())`), opens the **brief** as a sheet, then the **exam** as a plain `Navigator.push` route (no tab bar, no shell), then the **result** in its place. The future completes when the member has left the flow (closed the brief, left the exam, closed the result), so a landing can refresh its best scores and attempt counts after it.
* `MyAttemptsScreen({required VoidCallback onBack})` and `CertificatesScreen({required VoidCallback onBack})` are the hub's two doors; each builds its own controller. They draw their own title bar and expect the hub to push them under `ShellPage(tab: AppTab.learning)`. A result or certificate they open is a full-screen route over that.
* Signed-in person: `Provider<AuthController>` when there is one (its id keys a saved sitting, its first name greets the result). Without it (a bare test tree) the id is `me`.

## The flow, with the endpoints

1. **Brief** (`brief_sheet.dart`, `BriefController`). `GET /learning/papers/:slug` is the paper with its questions (the answer key stripped) and is also the access check: it answers 403 `PAPER_LOCKED` when the member has not opened it. Alongside: `GET /learning/me/attempts?paperId=` (attempts used, best score) and `GET /learning/me/certificates` (a certificate held for this paper); the saved sitting from the device store. If the paper is locked: its parameters come from the public `GET /learning/papers?kind=` (found by slug; the other kind is tried if the landing had it wrong), what it costs from `GET /learning/papers/:slug/quote`, and the way in from the 403's body (`reason`, `opens`, `remaining`, `plan`).
2. **Opening a locked paper**, three ways, exactly the website's `PaperUnlockPanel`: `POST /learning/me/opens {target, targetId}` ("Open with my plan", only when `reason` is `PICK`: the plan has a place free for the whole course or mock exam), `POST /learning/papers/:slug/redeem` (ICR credits, for good, with a confirmation naming what will be left), or the paper's page on the website (payment is PayU, which the app does not do). After either write the brief loads again and is ready.
3. **Exam** (`exam_screen.dart`, `ExamController`). One question at a time under the clock; answers, flags and the place in the paper live in the controller and are written to the device after every change.
4. **Submit** = `POST /learning/papers/:slug/attempts {startedAt: epoch ms, answers: [{questionId, selected: [int]}]}`, every served question in the list (an empty list would be scored against the whole bank), the picks sorted. The answer is `{attempt, certificate, review}`.
5. **Result** (`result_screen.dart`). Reopened later from My attempts with `GET /learning/me/attempts/:id` (the same shape).
6. **My certificates** reads `GET /learning/me/certificates`; the register is `GET /learning/certificates/:number` (public).

## Screens and controls (each control and the test that proves it)

Screen tests are in `test/learning_exam_screen_test.dart` unless named otherwise; "logic" means `test/learning_exam_test.dart`; "live" means `test/live/learning_exam_live_test.dart`.

### The brief (sheet over the landing, 48 dp of it still showing)

What it draws: the cover (the paper's image, else a plate), the eyebrow ("FOUNDATION LEVEL" or the subject of a mock set) and the heading (the programme, so the rung is confirmed back; a mock set is headed by its own name, "ASHRAE BEMP - Set 1"), pills (Assessment / Mock exam, "Certificate on a qualifying pass", "Unlocked for you" on a priced paper the member holds), the description, the member's record (best score, a certificate held, a sitting in progress, attempts used), "Test parameters" (questions and minutes as tiles; total marks, passing criterion, attempts allowed "Unlimited" or "3 . 1 used"), and "Before you start": the paper's own instructions when it has them, else four short cards (Timed, Saved as you go, Move freely, Scored when you submit).

| Control | What it does | Proved by |
|---|---|---|
| Take test / Retake test | closes the sheet handing the sitting to the exam | `the brief: an open paper...`, `a member who has sat it sees the best score and Retake test...` |
| Take test, tapped twice | one sitting, the screen under the sheet stays | `two quick taps on Take test...` |
| Take test when attempts are used up / no questions | off, with a warning | `all the attempts used...`, `a paper with no questions...`; logic `all the attempts used closes the paper` |
| Resume - mm:ss left | picks the saved sitting up with its answers | `an unfinished sitting is resumed...`; logic `a sitting left unfinished is offered...` |
| Discard it and start over | asks (Keep it / Discard), then the next start is fresh | `discarding an unfinished sitting...` |
| Submit my saved answers | for a sitting whose time ran out while away | `a sitting whose time ran out while away...` |
| View certificate (held) | opens the certificate sheet | `a member who has sat it...` |
| Try again (load failed) | loads again | `a paper that will not load...`; logic `a paper that will not load fails...` |
| Redeem N credits | confirmation naming the credits left, then `redeem`, then ready; off, with "You need N more", when the credits are short | `Redeem asks first...`, `too few credits...`; live `redeem, fail on a blank sitting, pass on the key...` |
| Redeem refused | the API's sentence under the options, paper stays locked | `a refused redemption shows...`; logic `a refused redemption says why...`; live `a paper that costs more credits than she holds is refused...` |
| Open with my plan | confirmation, then `POST /me/opens`, then ready; absent unless the plan has a place | `a place left on the plan opens the whole course...`; logic `opening with the plan works only when...`; live `opening a course with a plan she does not have is refused...` |
| Pay on the website | opens the paper's page there; "Payment is not available" is off | `Pay on the website...`, `payment that is not available...` |
| See the {plan} plan | opens `/pricing/<slug>` on the website, only when the API names a plan | `the plan's upgrade is a link...` |
| Back (locked) | closes the sheet | `Back closes the sheet` |

### The exam window (full screen, no tab bar)

Drawn as the **Mock Test** design (owner's new design, Oct 2026). A white bar with a soft shadow: the back arrow (it asks "Leave the exam?", as the phone's own back does) and the kind of paper as the title, "Mock Test" for a mock set and "Assessment" for a level paper; the paper's own name is no longer on the bar (the overview still names it). Under it, centred and pinned, the clock as a 30 dp pill, "Time Left: 14:32", red on a red tint, and solid red with white words in the last five minutes (the pill is red all along in the design; the last five minutes still have to look different). Then, scrolling: the **number strip** (44 dp squares, 8 dp apart: green answered, deep navy the open question, light grey not answered, an amber outline when flagged for review; the four numbers around the open question, "…" and the last number, as the design's "5 6 7 8 … 30"; at the far right a 44 dp grid button that opens the palette sheet), the **question card** ("Question 7" and, when the API sent one, an EASY / MEDIUM / HARD chip; the prompt; "Select all that apply." on a multiple-choice question), "Answer" with "Clear" at its right, and the **options** as bordered cards, a 24 dp radio (a square tick on multiple choice) and the text; the chosen one has a 2 dp primary border and a pale blue fill. Pinned at the bottom: **Finish** (red), **Review** (a bookmark, filled amber when the question is flagged), **Skip** and **Submit & Next** ("Submit" on the last question), 56 dp tall. Review keeps only its bookmark below 340 dp.

| Control | Proved by |
|---|---|
| Option tap (single: moves the choice; multiple: toggles), `Semantics` checked / mutually exclusive / "Option B. text" | `tapping an option selects it...`, `a multiple-choice question says so and ticks...`, `options can be read by a screen reader...`; logic `a single-choice question takes the one option tapped...`, `a multiple-choice question toggles each option...` |
| Skip and Submit & Next both move on (the answer given stays); Skip is off on the last question, where Submit & Next reads "Submit" and opens the overview | `Skip and Submit & Next move on, a number goes back...`, `Submit & Next keeps the answer given, and Skip leaves...` |
| The number strip: a number goes to that question (this is also the way back, there is no Previous button); its window and "…"; answered, open and flagged marks; the grid button opens the palette | `the strip shows the numbers around the open question...`, `the strip marks answered, open and flagged questions`, `shows what it is, the clock, the number strip...` |
| Review flags the question and unflags it (spoken as "Flag for review" / "Unflag"); the strip and the button both show it | `Review flags the question, the strip and the button show it...` |
| Clear (off until answered) | `Clear is off until there is an answer...` |
| The kind of paper as the title; a difficulty chip only when the API sent one | `a mock set is a Mock Test...`, `a question the API gave no difficulty for shows no chip` |
| Palette: five states (not visited, not answered, answered, flagged, answered and flagged), a legend with counts, the current question ringed, tap jumps; Review & submit | `the palette shows every question by state...`, `Review & submit in the palette opens the overview`, `two quick taps on a palette number...` |
| Finish (and Submit on the last question) opens the **overview**: "12 answered, 3 skipped, 2 flagged", a warning for skipped, a note for flagged, a number to go back to each question, the time left, Back to test, Submit test | `the overview counts answered, skipped and flagged...`, `Back to test closes the overview and sends nothing`, `Submit test sends the answers and shows the result`, `two quick taps on Submit test...` |
| The clock: counts down by the wall clock, solid red under five minutes | `the clock turns red under five minutes...`; logic `the clock counts down by the wall clock and submits...`, `the periodic timer drives the same countdown` |
| At zero the answers are sent for the candidate ("Time's up"), under an open sheet too | `at zero the answers are sent for the candidate...`, `the clock running out under an open overview...` |
| Leave (the back arrow, or the phone's back): asks "Leave the exam?"; Keep going / Leave (the sitting is kept to resume) | `leaving asks first...` |
| A failed send: "Your answers didn't go" with the API's sentence; Try again (a second quick tap sends nothing more), Back to the test (while time is left), Leave for now | `a send that fails keeps the answers...`, `after a failed send with time left...` |
| A refusal that cannot be undone (403, the attempts are used up): no Try again, Close gives the sitting up | `a refusal that cannot be undone...`; logic `a refusal that cannot be undone is not offered a retry` |
| 320 and 360 dp: nothing overflows or is cut off | `a 320 dp phone with long names`, `a 360 dp phone` |

### Correctness of the exam (the part that must not fail)

* **The clock is the wall clock.** The time left is always `startedAt + time limit - now`, recomputed on every tick and when the app returns to the front (`WidgetsBindingObserver`), so a throttled or stopped timer in the background can neither grant nor lose time. The server does not enforce time (the DTO only takes `startedAt`); the app does. Proved: logic `time spent in the background is still spent...`, screen `the app going to the background and coming back recomputes the clock`, `the app coming back after the time ran out sends the answers`.
* **Answers survive.** They are in the controller, not the widgets, so a rebuild or a rotation cannot lose one (`a rotation keeps the question, the answers and the clock`); and every change is written to the keystore (`flutter_secure_storage`, a copy in memory if it fails) as a snapshot of the sitting, the questions exactly as served (a randomised paper resumes in the order the candidate saw), when the clock started, where they were, what they answered and flagged. A killed app finds it again on the brief ("Resume - 18:00 left") or, if the time ran out meanwhile, sends what was answered (`a whole new screen on a saved sitting...`, `a screen opened on a sitting whose time ran out sends its answers at once`, logic `a sitting picked up after its time ran out is sent at once`, `the answers are kept to the store as they change...`, `a failing store does not stop the exam`).
* **One submit, one attempt.** Two `submit()` calls share one send (logic `pressing Submit twice sends one sitting`; live `pressing Submit twice makes one attempt`). Nothing is editable once a send has started (logic `nothing is writable once the answers are on their way`).
* **A failed send keeps everything and can be retried**, and a retry first asks the API whether the sitting already landed (it looks for an attempt with the same `startedAt` and reads it back through `GET /me/attempts/:id`), so a reply that never arrived does not become a second attempt. Proved in logic (`a retry first looks for the sitting that may have landed...`) and live (`a reply that never arrived is not sent twice...`: the real API recorded the sitting, the app was told it failed, the retry created no second attempt).

### The result

Drawn as the **Test Results** design (owner's new design, Oct 2026), one page: a white bar with the back arrow and "Test Results"; two chips, "TEST ANALYSIS — SET 1" (the paper's own title, the rung or set, with the date after it on a reopened sitting) and the kind of paper, **Formative** for a practice paper and **Summative** for one that certifies (the design's word is Formative; the model has only `certificateEnabled`, so its opposite is the other word); the headline, "You scored 0%" with the percentage red, or green when the pass mark was met (a certifying paper keeps its own headline, "Outstanding result" / "Well done" / "Not quite there yet" with the first name, in red when missed) and the subline, "Practice paper — no certificate is issued." (a certifying paper keeps its sentence about the pass mark); a line saying whether the pass mark was met (Passed / "Not passed . 70% to pass" / "Below the 70% pass mark" for a practice paper); a "Certificate issued: number, on attempt n" notice with View certificate; six tiles (Score "5 / 10", Percentage, Correct, Wrong, Unanswered, Time taken); the Attempt Count card ("#3"); Retake test (filled) and Review answers (outlined, scrolls to the review) side by side; "By topic" (weakest first; derived from the `category` of each reviewed question, since the API returns no topic breakdown); then **Question Review & Explanations**: filter chips (All, Incorrect, Correct, and Unanswered only when there is one, each with its count), a strip of 40 dp question squares that scrolls sideways (green border correct, red border incorrect, grey unanswered, filled deep navy the one on show), the question on show in a card (a "Question 7" pill, how it turned out, "0 / 1 Mark"; the prompt; every option with its letter, the right one green with "Correct Answer" or "Your Answer (Correct)", a wrong pick red with "Your Answer (Incorrect)"; "Detailed Explanation & Rationale" with "Core Topic: ..." when the question has an explanation, no panel when it has none), and Previous / "Question 7 of 30" / Next, off at the ends of the filtered questions; **My attempts**: the member's sittings of this paper, newest first ("3 attempts recorded"), each "#2", its date and time, a document icon, and a card with Score, Result (red or green) and Duration. A sitting whose questions were removed from the bank since says how many are not shown. The bar under the page: View certificate (or Back when there is none) and Retake Test.

"My attempts" reads `GET /learning/me/attempts?paperId=` through the same repository as the exam (it is empty-handed in a bare test tree, and then lists only the sitting on show, as it does when the read fails). The document icon of another sitting opens that sitting's result (`GET /me/attempts/:id`) as a result of its own, with Retake closing both; on the sitting on show it opens its certificate, or goes back to the top of the page when it earned none.

| Control | Proved by |
|---|---|
| Headlines, tiles, pass line, chips, pass or fail | `a pass on a certifying paper...`, `the tiles count what went wrong too...`, `Passed with under 85%...`, `a miss on a certifying paper...`, `a practice paper says what was scored...`, `a practice paper above the pass mark...`, `without a name the headline is bare`, `the tag names the set of a mock paper` |
| Review: the key, the pick, the mark, the explanation (and none without one) | `every question is worked through...`; live `a past sitting comes back with the key, the explanation and the certificate it earned` |
| What a question was worth: from the review, from the sitting, one a question when the paper is worth one a question, else not shown | `what a question was worth...`, `a paper with marks that differ...` |
| The strip, the pager, the filters | `the strip numbers each question...`, `the pager walks the questions...`, `the filters narrow the review...`, `a filter nothing falls under says so...` |
| Review answers | `Retake test and Review answers sit side by side...`, `a result with nothing to review...` |
| By topic | `a result by topic appears...` |
| Removed questions | `questions removed from the bank since the sitting are counted, not hidden` |
| View certificate | `View certificate opens the certificate` |
| Retake (closes the result, starts the paper again; tapped twice, once; from the bar too) / Back | `Retake test closes the result...`, `the bar offers Retake Test as well...`, `two quick taps on Retake test...`, `with nothing to retake there is only Back...`, `with a certificate the bar offers View certificate beside Retake Test` |
| My attempts: the list, opening another sitting, the sitting on show, retaking from an older one, a history that will not load | the six `My attempts` tests under `the result` |
| 320 and 360 dp | `the result, with its review and certificate, does not overflow`, `at 360 dp` |
| The whole way: brief, exam, result, Retake, `openPaper` completing | `openPaper: brief, exam, result and Retake, end to end`, `closing the brief completes openPaper without an exam` |

### My attempts (`GET /learning/me/attempts`)

Three tiles (attempts, passed, best), filter chips (All / Assessments / Mock exams), one card per sitting newest first (paper name, "Attempt #3 . date", pass / fail, score, correct, time) opening the result again (`GET /me/attempts/:id`), with Retake from there.

| Control | Proved by |
|---|---|
| The list | `lists the sittings newest first...`; live `his history lists the seeded sittings newest first...` |
| Filter chips | `the filters narrow the list...`, `a filter with nothing in it says so...`; logic `the history can be narrowed...`; live `My attempts and My certificates read the same through their controllers` |
| A card opens its result (spinner, error with Try again) | `a sitting opens its result again...`, `a result that will not load says why...` |
| Retake on an old result opens that paper's brief | `Retake on an old result opens that paper brief` |
| Empty state ("Back to Learning"), error state (Try again), pull to refresh, back arrow | `no sittings yet...`, `a history that will not load...`, `pulling down reads the history again`, `the back arrow goes back` |
| Someone else's sitting is a 404 | live `another person's sitting is not found` |

### My certificates (`GET /learning/me/certificates`)

Tiles (earned, best score), awarding-body chips when there is more than one, one card per credential (a small stand-in for the certificate as the website's cards draw it, title, who awarded it, a Verified pill, issued, credential ID), View certificate, Share, Copy number, and a Verification card with "Check a certificate number".

**The certificate** (`certificate_view.dart`, the QR code in `qr_code.dart`, a small QR encoder written for this: versions 1 to 10, error correction M, a port of the website's generator so the code is the same module for module) is drawn as `Certificate.tsx` draws it: two panels on an A4 landscape sheet scaled to the width (ICR lockup, the Knowledge Builds Excellence seal, the partner, the awarding body when it is not ICR; CERTIFICATE OF KNOWLEDGE ASSESSMENT, the holder in gold italics, the credential, the level between stars, the date cleared, the signatory, the QR code, issued date and number), pinch to zoom, with its facts under it and Share / Copy number / Download PDF on the website / Check it in the register / Add to LinkedIn. The brand images are copied from `frontend/public/brand` into `assets/images/demo/learning/cert_*.png` (the seal and partner mark resized).

**The register** (`verify_sheet.dart`): a number typed (any case, spaces trimmed) is looked up through the public `GET /learning/certificates/:number` and says "Certificate verified / Genuine" with holder, credential, awarding body, level, result and date, or that no certificate has that number.

| Control | Proved by |
|---|---|
| Cards and facts | `each credential is a card...`; live `his certificates carry the seeded one, and anyone can check its number` |
| View certificate (list, brief, result) | `View certificate opens the certificate itself`; `is drawn with its holder, credential, level, dates and number...` |
| Share (hands the verification link to the share sheet) | `Share hands the verification link to the share sheet`, `a card's Share and Copy number work from the list` |
| Copy number (clipboard, "Number copied") | `Copy number puts the credential number on the clipboard` |
| Download PDF, Check it in the register, Add to LinkedIn (the website, with the LinkedIn `profile/add` parameters) | `the PDF stays on the website; the register and LinkedIn open there too` |
| The QR code (a scan opens the certificate's page in the register) | logic `the certificate QR code is module for module the code the website draws for the same text, from one module to version 10`, `a text that does not fit version 10 is refused...`, `a verification link of a certificate makes a 33 by 33 code` (the first compares eleven texts, versions 1 to 10, against the website's own `qrcode-generator` output in `test/fixtures/learning_exam/qr_website.json`) |
| Awarding-body chips | `with more than one awarding body...`, `with one awarding body there is nothing to filter by`; logic `certificates are narrowed by who awarded them...` |
| The register | the five `the register` tests (opens, found, not found, failed look-up with Try again, the website link); logic `a certificate number is looked up in the public register...`; live the anonymous look-up in `his certificates carry the seeded one...` |
| Empty / error states | `none yet...`, `certificates that will not load...` |

## What the API cannot do, and what the screens do instead

* **It never enforces the time limit** (the DTO takes only `startedAt`), and holds no sitting in progress. The clock and the saved sitting are the app's (above). A sitting sent after its time (the app was away) is sent as it is; the server records a `timeTakenMs` longer than the limit.
* **It cannot delete an attempt** or give back credits. The live tests that sit papers leave their attempts (see the test's header) and the one that redeems does it as the throwaway Exam Persona.
* **A locked paper's parameters are not on the 403.** The brief reads them from the public list (`GET /learning/papers`, about 100 KB, only for a locked paper), and the price from the quote.
* **There is no per-topic breakdown.** The result derives one from the `category` of each reviewed question (and says nothing when there is no category).
* **The review is rebuilt from the live question bank** (`getMyAttempt`): a question edited since changes what an old sitting appears to have been marked against; one deleted is missing, and the result says so. A later pass returns the certificate already held in its own result (the website says the same), but a reopened later sitting does not claim it (live test `redeem, fail on a blank sitting, pass on the key...` covers both).
* **Payment** is PayU on the website: "Pay on the website" opens the paper's page.
* **The certificate PDF** stays on the website (the owner's call): "Download PDF on the website" opens `/learning/certificates/<paper slug>`, which asks the browser to be signed in.
* **Question types.** `SINGLE` and `MULTIPLE` exist. The website draws both as radio buttons (a multiple-choice question there can never score); the app draws and sends a multiple-choice answer properly (live `a multiple-choice question is right only when every right option is picked`).

## Deviations from the brief and from the website

* **The link Share hands over is the register's page** (`/learning/verify?id=<number>`), not `/learning/certificates/<id>`: on the website `/learning/certificates/[slug]` is the holder's own copy, found by *paper slug* and behind sign-in, so it cannot take a certificate number; the verify page is the public one (the website's own "Share" uses it too).
* **The holder's name is in Work Sans italic**, not Tangerine (not bundled), and the on-screen certificate is a scaled sheet you pinch, not a re-flowed page.
* **No "Preparing your assessment" interstitial** (the website holds the candidate for 2.4 s): the clock starts when the exam opens, which is when Take test is tapped.
* **A practice (mock) paper's result still says whether the pass mark was met**, in neutral words ("Below the 70% pass mark"), because the brief asks for pass or fail against the mark; the website only says "You scored". A certifying paper fails in red.
* **The exam and the result were redrawn from two new designs (Oct 2026), Mock Test and Test Results**, and a few things the designs do not draw are kept or named: Previous is gone from the exam (a number in the strip goes back; the strip shows the two before the open question and the one after it); Clear sits at the right of "Answer"; the paper's name and "N answered" are off the exam bar (the strip's colours say what is answered, the overview names the paper); a flagged question is an amber outline on its number and a filled bookmark on Review, where the palette sheet keeps its own five colours.
* **"Download PDF" is not on the result's bar.** The app has no PDF of a result, and the certificate's PDF is the website's (above), so the left button is "View certificate" when the sitting earned one and "Back" otherwise; nothing that does nothing is drawn. The design's "Retake test" and "Retake Test" (top and bar) are both there, as the owner's spec spells them.
* **"Formative" / "Summative"**: the chip beside the tag is the design's word for a practice paper, and "Summative" for a paper that certifies; the model carries only `certificateEnabled`, not a kind of that name.
* **Marks per question** ("0 / 1 Mark") are not in the API's review. The result uses the review's `marks` if it ever sends one, else the marks of the sitting just taken (from the served questions), else one a question when the attempt's total marks equal its number of questions, and otherwise draws no mark line rather than guess. The API could send `marks` (and `difficulty` on a review) with each reviewed question; nothing else would change.
* **A question's topic** is shown only in the explanation panel ("Core Topic: ..."); a question with no explanation shows neither, as the design hides the panel.
* **Leaving is allowed** (the website has no way out but Submit or the timer): it asks first, the clock keeps running, and the sitting can be resumed until time runs out, after which it is sent as it stands.
* **The screen is not kept awake** (no wake-lock plugin in `pubspec.yaml`); a long paper on a phone that sleeps simply resumes, since the clock does not depend on the screen.
* **Narrow phones**: at 320 dp (the screen tests' `a 320 dp phone with long names`) the exam bar's Review button keeps only its bookmark (a screen reader still hears "Flag for review"), the number strip's squares shrink a little, and an awarding body's long name is cut with an ellipsis in its filter chip; nothing overflows.
* **A sitting left unfinished is found again on that paper's brief** ("Resume - 18:00 left", or "Submit my saved answers" once the time has run out). There is no list of unfinished sittings in the app.
* **Landscape** works (the pane scrolls, the bars stay) but is not designed for; a rotation is proved not to lose anything.

## The data (`tool/seed/learning-flows.ts`, see `tool/seed/README.md`)

* The local question banks are placeholders ("Practice question 3 for Foundation (placeholder...)", "Option A" to "Option D", no explanation, no topic, nothing multiple-choice). The seed switches off the placeholders of two papers and adds ten real questions to each: `capital-planning-foundation` (Bharat's, certifying, 50 min, ten single-choice, each with an explanation and a topic) and `ashrae-bemp-set-1` (Pooja's mock set, eight single and two multiple-choice). `--remove` switches the same placeholders back on.
* **Bharat Buyer's history** (so My attempts and My certificates are not empty): three sittings of Capital Planning - Foundation at 40 %, 60 % and 90 % (the last passed and earned `ICR-CP-2026-DSGNLF01`) and one failed sitting of Capital Planning - Advanced.
* **The Exam Persona** `exam.sitter@learning-flows.icr.test` / `Exam@12345`: a PROFESSIONAL with the 10 signup credits and a plan that opens nothing, so every paper is locked to her until she redeems credits (Procurement Management - Foundation costs 5). Each run of the script resets her (unlocks, attempts, certificates), which is what lets the redeem-and-pass live test run from the start.
* To see it on the emulator: as **Bharat** open Learning, Assess Your Knowledge, Capital Planning, Foundation (his record, the certificate, Retake) and My attempts / My certificates; as **Pooja** open Mock Exams, ASHRAE BEMP, Set 1 (multiple choice), or any locked level (the credits and the price); as the **Exam Persona** redeem and sit a paper from scratch.

## Notes for the lead

* Nothing was added to `pubspec.yaml`; `assets/images/demo/learning/cert_seal.png`, `cert_partner.png`, `cert_signature.png` are new bundled files (the ICR lockup is the existing `assets/images/brand/icr-logo.png`).
* `whole suite`: my files are green; at the time of writing the failures in the suite are in the ASSESS builder's `learning_assess_golden_test.dart` (goldens not yet recorded) and one case of `learning_assess_test.dart`.
* The live tests share the API's 120-requests-a-minute allowance with the other builders' live tests; `liveClient` waits out a 429. If the API restarts mid-run the file skips itself.
