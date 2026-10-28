# Learning: the exam (brief, exam window, result, My attempts, My certificates)

There is no PNG for these screens. The reference is the website's Learning Center (`PaperBrief`, `PaperUnlock`, `ExamWindow`, `PaperExam`, `SubmitOverviewDialog`, `ResultSummary`, `AttemptSummary`, `MyAttempts`, `Certificate`, `CertificatePage`, `MyCertificatesPage`, `CertificateVerify`) and the API (`learning.service.ts` `getPaperForCandidate` / `submitAttempt` / `getMyAttempt`, `SubmitAttemptDto`, `paper-checkout.service.ts`, `learning-plan-access.service.ts`), done as a phone does it. Code: `lib/features/learning_exam/`. Tests: `test/learning_exam_test.dart` (logic, 71), `test/learning_exam_screen_test.dart` (screens, 100), `test/golden/learning_exam_golden_test.dart` (14 goldens at 390 x 844), `test/live/learning_exam_live_test.dart` (16, against the local API); fakes and recorded API answers in `test/learning_exam_fakes.dart` and `test/fixtures/learning_exam/`. Data: `tool/seed/learning-flows.ts`.

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

Top bar: leave (x), the paper's name with "Question 3 of 10 . 2 answered", the clock chip (turns red under five minutes), the palette. Under it a progress bar at "N of M". The pane: "QUESTION n . TOPIC", a Flagged pill, the prompt, "Select all that apply." on a multiple-choice question, the options as 56 dp cards with a letter (a circle for single choice, a square with a tick for multiple). Bottom: Flag for review / Unflag, Clear, Submit, then Previous and Next (the last question says "Review & submit").

| Control | Proved by |
|---|---|
| Option tap (single: moves the choice; multiple: toggles), `Semantics` checked / mutually exclusive / "Option B. text" | `tapping an option selects it...`, `a multiple-choice question says so and ticks...`, `options can be read by a screen reader...`; logic `a single-choice question takes the one option tapped...`, `a multiple-choice question toggles each option...` |
| Next / Previous, off at the first, last says Review & submit | `Next and Previous move through the paper and stop at the ends...` |
| Flag for review / Unflag | `Flag for review flags the question...` |
| Clear (off until answered) | `Clear is off until there is an answer...` |
| Palette: five states (not visited, not answered, answered, flagged, answered and flagged), a legend with counts, the current question ringed, tap jumps; Review & submit | `the palette shows every question by state...`, `Review & submit in the palette opens the overview`, `two quick taps on a palette number...` |
| Submit (any time) and the **overview**: "12 answered, 3 skipped, 2 flagged", a warning for skipped, a note for flagged, a number to go back to each question, the time left, Back to test, Submit test | `the overview counts answered, skipped and flagged...`, `Back to test closes the overview and sends nothing`, `Submit test sends the answers and shows the result`, `two quick taps on Submit test...` |
| The clock: counts down by the wall clock, red under five minutes | `the clock turns red under five minutes...`; logic `the clock counts down by the wall clock and submits...`, `the periodic timer drives the same countdown` |
| At zero the answers are sent for the candidate ("Time's up"), under an open sheet too | `at zero the answers are sent for the candidate...`, `the clock running out under an open overview...` |
| Leave (x, or the phone's back): asks "Leave the exam?"; Keep going / Leave (the sitting is kept to resume) | `leaving asks first...` |
| A failed send: "Your answers didn't go" with the API's sentence; Try again (a second quick tap sends nothing more), Back to the test (while time is left), Leave for now | `a send that fails keeps the answers...`, `after a failed send with time left...` |
| A refusal that cannot be undone (403, the attempts are used up): no Try again, Close gives the sitting up | `a refusal that cannot be undone...`; logic `a refusal that cannot be undone is not offered a retry` |

### Correctness of the exam (the part that must not fail)

* **The clock is the wall clock.** The time left is always `startedAt + time limit - now`, recomputed on every tick and when the app returns to the front (`WidgetsBindingObserver`), so a throttled or stopped timer in the background can neither grant nor lose time. The server does not enforce time (the DTO only takes `startedAt`); the app does. Proved: logic `time spent in the background is still spent...`, screen `the app going to the background and coming back recomputes the clock`, `the app coming back after the time ran out sends the answers`.
* **Answers survive.** They are in the controller, not the widgets, so a rebuild or a rotation cannot lose one (`a rotation keeps the question, the answers and the clock`); and every change is written to the keystore (`flutter_secure_storage`, a copy in memory if it fails) as a snapshot of the sitting, the questions exactly as served (a randomised paper resumes in the order the candidate saw), when the clock started, where they were, what they answered and flagged. A killed app finds it again on the brief ("Resume - 18:00 left") or, if the time ran out meanwhile, sends what was answered (`a whole new screen on a saved sitting...`, `a screen opened on a sitting whose time ran out sends its answers at once`, logic `a sitting picked up after its time ran out is sent at once`, `the answers are kept to the store as they change...`, `a failing store does not stop the exam`).
* **One submit, one attempt.** Two `submit()` calls share one send (logic `pressing Submit twice sends one sitting`; live `pressing Submit twice makes one attempt`). Nothing is editable once a send has started (logic `nothing is writable once the answers are on their way`).
* **A failed send keeps everything and can be retried**, and a retry first asks the API whether the sitting already landed (it looks for an attempt with the same `startedAt` and reads it back through `GET /me/attempts/:id`), so a reply that never arrived does not become a second attempt. Proved in logic (`a retry first looks for the sitting that may have landed...`) and live (`a reply that never arrived is not sent twice...`: the real API recorded the sitting, the app was told it failed, the retry created no second attempt).

### The result

Headline by what the paper is: a certifying paper says "Outstanding result" (85% or more), "Well done" or "Not quite there yet" with the first name; a practice paper just says "You scored 60%". The score dial, chips (accuracy, time taken, "9 of 10 correct", Passed / "Not passed . 70% to pass" / "Below the 70% pass mark" for a practice paper), a "Certificate issued: number, on attempt n" notice with View certificate, a ring with correct / incorrect / skipped, "By topic" (weakest first; derived from the `category` of each reviewed question, since the API returns no topic breakdown), then "Review your answers": filters (All / Incorrect / Skipped / Correct, with counts) over one card per question with its topic, an outcome pill, every option marked (green for the right one, red for a wrong pick, "Correct answer" / "Your answer"), and the explanation under "Rationale". A sitting whose questions were removed from the bank since says how many are not shown.

| Control | Proved by |
|---|---|
| Headlines, dial, chips, pass or fail | `a pass on a certifying paper...`, `Passed with under 85%...`, `a miss on a certifying paper...`, `a practice paper just says...`, `a practice paper above the pass mark...`, `without a name the headline is bare` |
| Review cards, key, pick, explanation | `every question is worked through...`; live `a past sitting comes back with the key, the explanation and the certificate it earned` |
| Filters | `the filters narrow the review...` |
| By topic | `a result by topic appears...` |
| Removed questions | `questions removed from the bank since the sitting are counted, not hidden` |
| View certificate | `View certificate opens the certificate` |
| Retake (closes the result, starts the paper again; tapped twice, once) / Back | `Retake closes the result and starts the paper again...`, `two quick taps on Retake test...`, `with nothing to retake there is only Back`, `with a certificate the bar offers Retake...` |
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
* **Leaving is allowed** (the website has no way out but Submit or the timer): it asks first, the clock keeps running, and the sitting can be resumed until time runs out, after which it is sent as it stands.
* **The screen is not kept awake** (no wake-lock plugin in `pubspec.yaml`); a long paper on a phone that sleeps simply resumes, since the clock does not depend on the screen.
* **Narrow phones**: at 320 dp (the screen tests' `a 320 dp phone with long names`) "Flag for review" is shortened to "Flag" (a screen reader still hears the long one) and an awarding body's long name is cut with an ellipsis in its filter chip; nothing overflows.
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
