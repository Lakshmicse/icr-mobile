# Company workspace — "My Company"

The website's `/company` page (`components/company/CompanyWorkspace.tsx`), drawn by the app since 12 Nov 2026: the
company the member acts for, its details, its company check and supplier level, and its certifications. It is the
"Dashboard" row under Company in the drawer. The owner's instruction was "take the reference of the Web and do as it
is"; the words are the website's with the owner's recommended wording laid over them (the company-workspace review,
`05-company-workspace`).

## Files

`lib/features/company/`

- `company_models.dart` — the profile's company row (kept whole, read by column), the listing, completeness, the
  employer gate and dossier, the re-verification request, the supplier access, evidence and history, plans, the
  person's companies, certifications and types.
- `company_fields.dart` — the app's copy of `@icr/shared`'s `COMPANY_FIELDS`, `COMPANY_DOCUMENTS` and the KYC rules:
  labels, sections, `isCompanyFieldLocked` (with the sentence the API refuses with), `missingKycFields`,
  `kycChecklist` / `reverifyChecklist`, `dossierFromCompany` / `dossierForReverification`, `canFileInState`, and the
  role lists (`COMPANY_PROFILE_EDITORS`, `TEAM_MANAGER_ROLES`, the KYC filers…).
- `company_rules.dart` — PAN (shape and holder letter), GSTIN (shape, state code, check character, carries the PAN),
  year of establishment, PIN, work email on the company's own domain, contact phone — each with the website's
  sentence.
- `supplier_checklist.dart` — `checklistFor` from `verification-checklist.ts` (the list the reviewer judges a level
  request by), the ladder, `certificationHeld` / `certificationDaysLeft` on India's calendar day.
- `company_words.dart` — every sentence the page shows.
- `company_repository.dart` — `CompanyRepository`, `ApiCompanyRepository`, `DemoCompanyRepository` (a sample
  company with a listing, two certifications, evidence and history; every write in `sent`).
- `company_controller.dart` — `CompanyController`: the profile first (it decides the tabs), then each card's read on
  its own, so one failed read never blanks the page; the writes.
- `company_workspace_screen.dart` — `CompanyWorkspaceScreen`.
- `widgets/` — `company_kit.dart` (sections, rows, chips, tabs, the ladder, the level badge), `company_header.dart`,
  `overview_tab.dart`, `identity_tab.dart`, `identity_sheets.dart`, `verification_card.dart`,
  `certifications_tab.dart`, `no_company_view.dart`.

```dart
const CompanyWorkspaceScreen({
  super.key,
  required this.onBack,
  this.tab,                // the website's ?tab=: overview, identity, verification, certifications (null = overview)
  this.onOpenCompanyPage,  // void Function(String id): the company's public page in the app
  this.onOpenTeam,         // VoidCallback: the team page in the app
  this.repository,         // tests; Demo in FEED_SOURCE=demo, else the API
  this.pickPhoto,          // the logo picker (tests)
  this.pickDocument,       // the document picker (tests)
  this.now,                // the clock renewals read (tests)
});
```

## What it shows

A white page, sections the full width parted by hairlines, nothing boxed. `TitleBar` ("My Company", back, bell).

**Header** — the logo (a camera badge on it: a new logo is uploaded and saved at once, as the website's), the eyebrow
COMPANY PROFILE, the name with its trust mark (the listing's supplier level for a company that sells, never the
company row's; a "Verified" chip for one that does not, once the company check has passed), the facts (industry,
size, city, website), "Changes are visible to all company members.", and View Public Profile / Switch Company (the
latter only for someone in more than one company).

**Tabs** — Overview, Company Details ("Organization Details" for a buyer, as the website), Certifications, and Team
for the roles that run the team when the lead wires `onOpenTeam` (it opens the app's team page: one team manager,
never a second copy). `?tab=verification` is not a tab but a place: it opens Company Details at the company check.
`?tab=team` opens the team page.

**Overview** — Company Profile Completeness (score, the first four missing items each with Add — the map pin opens
`/manage/locations`, the rest Company Details — and Edit Company Profile), shown only while something is missing: a
complete page has no card and opens on Trust & Verification (owner, 14 Nov 2026: the 100% card was fixed space with
nothing to act on); Trust & Verification (Company Verification
with its status, sentence and View Details / Verify / Respond / Resubmit, only View for someone who cannot file;
Supplier Trust Level "Verified – Level 2", trust score, the five-rung ladder, Upgrade Trust Level or Respond, or Start
selling for a company that does not sell); Company Overview (Members, Office Locations, Active Job Listings, Products
Listed, Services Listed, Certifications Uploaded — by role, as the website — each opening its page); Membership &
Subscriptions (Job Portal Plan, Marketplace Plan once it sells, See Plans / Manage Plan, View Plans & Payment
History); Company Public Profile (the address, Copy Profile Link, View Public Profile).

**Company Details** — the company check (below), the "N details are missing" strip, the Company Logo row (Upload Logo,
saved at once, as the header's camera), then four read-only sections in
the field table's order — Company Details, Legal & Registration Details (with the three documents beside their
numbers), Business Location & Coverage, Company Contact Details — each edited in a sheet from its pencil. A sheet
asks the same fields with the same rules and sentences as the website's form, sends **only the fields that changed**
(`PATCH /companies/me`), and keeps what was typed when the API refuses. A verified company's PAN, GSTIN and their
documents are disabled ("PAN and GSTIN cannot be edited after verification. Contact ICR Support for changes."), and
the registered legal name and organisation type once set, with the API's own sentences; an open re-verification
request unlocks the documents it asks for. Changing the organisation type drops a registration certificate that no
longer applies. The registration and contact sections carry a privacy note (the owner's review asked for one).

**Company Verification** — the status chip (Ready to submit / Not filed, or the dossier's), the re-verification chip,
the state in one sentence with its date, ICR's note and reason, the checklist of facts and documents the check reads
(each missing one opens its section), "not registered for GST", what verification unlocks, the submit button for a
company admin in a state that allows filing (Submit for verification / Resubmit / Send to ICR), and Need help with
verification? Contact ICR Support. The sections save as they close, so the check is filed from the company as saved
(`POST /employer-verification/submit`, the dossier composed as the website composes it).

**Certifications** — for a company that sells: Supplier Trust Levels; Your Verification Status (the level badge with
"ICR Verified Supplier", Apply for Certified Status / Upload requested documents / under review, the Certified Level
Requirements checklist with Completed / Under review / Pending Upload and the fix for each — Add Details, Add
Certification, Upload Document); a request sheet that uploads evidence (`purpose=verification`) and sends
`PATCH /vendors/:id/request-upgrade`; the verification history; Certificates & Renewals (days left, expired and
soon alerts); Company Certifications (on your public profile, shows once verified, expired, Certificates Pending Upload,
replaced by a renewal, not accepted) with Add Certification — a sheet with the certification, the certificate upload
(`purpose=certification`), the issuing body (filled in when ICR knows one), number, dates and note, refusing a second
record of one already held. For a company that does not sell: "Your company has no supplier listing yet" and Start
selling (`POST /vendors`).

**No company** — someone acting for no company gets the website's `NoCompany`: Switch Company when they belong to
companies, else Create a company (not for ICR staff) and Contact support. A role that does not edit the company
profile (recruiter, office admin) is told so: the website refuses it the page.

## API calls

`GET /users/me/profile` · `GET /employer-verification/gate` · `GET /employer-verification/me` ·
`GET /vendors/me/access` · `GET /subscriptions/me?audience=COMPANY|SUPPLIER` · `GET /me/companies` ·
`GET /branches?companyId=` · `GET /jobs|/products|/services?companyId=&limit=1` (their `meta.total`) ·
`GET /certifications/me` (workspace roles) or `/certifications/verified?companyId=` · `GET /certifications/types` ·
`GET /vendors/:id/verification-documents` · `GET /vendors/:id/verification-history` · `GET /masters` ·
`GET /locations/states` · `GET /locations/cities` · `PATCH /companies/me` · `POST /uploads?purpose=` (`company`,
`employer-kyc`, `verification`, `certification`) · `POST /employer-verification/submit` ·
`PATCH /vendors/:id/request-upgrade` · `POST /certifications/me` · `POST /vendors`.

## What the website does that the app leaves out, and why

- **The Team tab's content.** The website mounts its team manager inside the tab; the app's team page is its own
  screen (another builder's), so the tab opens it through `onOpenTeam`.
- **One form for all four sections.** The website edits every section in one long form with one Save; the app
  shows them read-only and edits each in a sheet, as the person's profile does (owner's LinkedIn-like rule). Each
  sheet still sends only what changed. The website's "Save and submit for verification" became a Submit button on
  the verification card that files the company as saved.
- **The QR code** on the public page card: the app has no QR package, and adding one is outside this folder. The
  address, Copy Profile Link and View Public Profile are there.
- **The welcome panel** (`?welcome=1`, `NewCompanyWelcome`): the app's create-company screen already ends on its own
  welcome state with the same four steps.
- **The editor under the NoCompany notice** for a buyer, seller or admin with no company (where saving the name
  founds one): the app founds companies on its create-company screen, so the notice alone is shown, with its way on.
- **The map pin** is set on `/manage/locations`, as on the website; the completeness item opens that page.
- **City and state** are chosen from ICR's lists (the city also typed), not the website's worldwide place search.
- Words still in English everywhere, as the rest of the app.

## Owner's wording applied

Two of the owner's text documents cover this page: `05-company-workspace` (the page's own) and `07-supplier-mart`
pages 4–5 (the same page as a supplier sees it). Where they name the same thing differently, **doc 05 is used**: it
is the page's own document, its wording is the same on its three pages about it (10–12, 14, 17), and the lead's first
instructions mapped it row by row. Every sentence is in `company_words.dart`, so a different choice is a one-line
change.

From doc 05: View public page → View Public Profile; Every member sees the changes → Changes are visible to all
company members; Profile completeness → Company Profile Completeness (with "See how much of your company profile is
visible to buyers and candidates." and "85% Complete"); Trust and verification → Trust & Verification; What ICR has
checked → Your Company's Verification Status; Company check → Company Verification; Supplier level → Supplier Trust
Level ("Verified – Level 2"); Raise level → Upgrade Trust Level; Company at a glance → Company Overview ("A snapshot of
your company's presence and activity on ICR.") with Members / Office Locations / Active Job Listings / Products Listed
/ Services Listed / Certifications Uploaded; Membership → Membership & Subscriptions, Job Portal Plan, Marketplace
Plan, Plans and receipts → View Plans & Payment History; Public page → Company Public Profile, Profile URL, Copy
Profile Link; the tabs Overview / Company Details / Certifications / Team; Company Verification's caption, "Verified
on … Your company can publish jobs and connect with candidates on ICR." and "Need help with verification? Contact ICR
Support"; Legal identity → Legal & Registration Details, Location & reach → Business Location & Coverage, Who to
contact → Company Contact Details, with their blurbs; Company Logo / Upload Logo; the field labels and helpers (Company
Name, "Your brand name as displayed on ICR.", Registered / Office Address, PIN Code, Where you operate → Operating
Regions, Alternative Contact Number…); "PAN and GSTIN cannot be edited after verification. Contact ICR Support for
changes."; Save Changes; Supplier Level → Supplier Trust Levels; Verification Status → Your Verification Status; Your
trust level as buyers see it → Your current verification status and supplier trust level; ICR Verified & Trusted →
ICR Verified Supplier; Request Certified Verification → Apply for Certified Status; To reach Certified → Certified
Level Requirements; Add on company profile → Add Details; Done → Completed; Missing → Pending (an item put right on
the profile) and Pending Upload (an item put right by an upload or a certificate) — the doc's two tables give both;
Upload → Upload Document; Years in business → Business Experience, "8 years stated" → "8 Years"; Office / location →
Business Locations; ISO / certifications → Quality & ISO Certifications; "— certificate not on file" → "– Certificate
pending upload"; "The ICR team reviews the same list…" → "ICR reviews these details and supporting documents to
determine your vendor partner trust level."; Renewals → Certificates & Renewals with its caption and empty sentence;
Certifications → Company Certifications with its blurb; Certificate not on file → Certificates Pending Upload; Add a
certification → Add Certification; Add certificate → Upload Certificate; the "ICR does not issue certifications…"
note and the privacy line.

From doc 07 (no conflict with doc 05): the supplier level's line "Build your supplier credentials to unlock higher
trust levels and improve visibility."; "use Public Profile consistently"; a clear mark on what is private (the
registration and contact sections carry one).

Doc 07 rows **not** used because doc 05 names the same thing differently: Profile Completion (doc 05: Company Profile
Completeness), Upgrade Level (Upgrade Trust Level), Supplier Level (Supplier Trust Level), Membership & Plans
(Membership & Subscriptions), Plans & Billing (View Plans & Payment History), Public Company Profile / Profile Link /
Copy Link (Company Public Profile / Profile URL / Copy Profile Link), Team Members / Certifications (Members /
Certifications Uploaded), Legal Information, Locations and Operations, Primary Contact, Operating Reach (doc 05's
headings and Operating Regions), the header's "shared with authorised team members" (doc 05's sentence).

Not applied, and why: the logo helper's "PNG, JPG or SVG" reads "PNG, JPG or WEBP" — the upload API refuses SVG; the
"Your profile is 30% complete" banner (docs 05 p. 18, 07 pp. 4–5) is the person's profile banner, not this page's; the
welcome panel's wording (doc 05 p. 14) belongs to the create-company screen's welcome state, not this folder; doc 05
pages 1–2 are marked "need to discuss"; the team, locations, integrations, talent and reports pages and doc 07's
marketplace pages are other screens. "Supplier Mart" reads "the Marketplace", the app's name.

## Tests

`test/company_workspace_test.dart`, against `DemoCompanyRepository`: the header and its facts; the completeness card
and where Add goes, and no card at all on a complete page; the trust card's two answers; the overview panel, plans and public profile; a section's sheet
sending only the field that changed, and nothing when nothing changed; the verified locks with their sentences; an
unverified PAN checked before anything is sent; the verified company check; filing the check from the profile; the
checklist's missing items opening their sections; the level request with its evidence; Pending Upload and Add Details;
renewals and recording a certification; Start selling; no company (create, and switch); a role that may not edit; the
Team tab; the error state.

## 13 Nov 2026: copy refined to the client's standard

The client's marked-up manual (13 Nov 2026) asks for crisp, international wording: Title Case for the names of things
a person taps or reads as a label, plain sentences with a full stop, no dash used as punctuation, "Select" and "Enter"
for "Pick", "Choose" and "Type", "Unable to load" for "could not be loaded". The owner's 12 Nov words (docs 05 and 07,
above) are kept; only their capitalisation was brought into line. Wording only: no layout or behaviour changed. The
team page (`lib/features/team`) and the companies directory (`lib/features/directory`) have no file of their own
here, so their changes are listed below too.

### My Company (`lib/features/company`)

The lead's rulings of the same day are applied too: an empty-state, locked-state or error *title* is a heading (Title Case, no full stop) and the line under it a sentence; the retry button reads "Try Again".

| Where | Was | Now |
|---|---|---|
| Buttons, headings, field labels and chips to Title Case (54 strings) | Add details · Submit for verification · Submit for review · What verification unlocks · Verification history · Upload requested documents · Edit listing · Start selling · Create a company · Contact support · Trust score 82 · On your public profile · Shows once your company is verified · Replaced by a renewal · Not accepted · Team & trust · Issuing body (optional) · Certificate number (optional) · Issue date (optional) · Expiry date (optional) · Note (optional) | Add Details · Submit for Verification · Submit for Review · What Verification Unlocks · Verification History · Upload Requested Documents · Edit Listing · Start Selling · Create a Company · Contact Support · Trust Score 82 · On Your Public Profile · Shows Once Your Company Is Verified · Replaced by a Renewal · Not Accepted · Team & Trust · Issuing Body (Optional) · Certificate Number (Optional) · Issue Date (Optional) · Expiry Date (Optional) · Note (Optional) |
| Status chips | Not filed · Ready to submit · Under review · More information needed · Not approved · Verification withdrawn · Re-verify by 30 Nov 2026 · Re-verification under review · Expires today | Not Filed · Ready to Submit · Under Review · More Information Needed · Not Approved · Verification Withdrawn · Re-Verify by 30 Nov 2026 · Re-Verification Under Review · Expires Today |
| The field table's row labels (the read-only rows and the check's list) | Company name · Company website · Company size · Year of establishment · Company logo · Registered legal name · Organisation type · Registration certificate · PAN card · GST certificate · Street address · PIN code · Work email · Contact person · Alternative contact number | Company Name · Company Website · Company Size · Year of Establishment · Company Logo · Registered Legal Name · Organisation Type · Registration Certificate · PAN Card · GST Certificate · Street Address · PIN Code · Work Email · Contact Person · Alternative Contact Number |
| The supplier checklist's item names | Company registration · Company website · Client references · Financial documents | Company Registration · Company Website · Client References · Financial Documents |
| A failed read | The company check could not be loaded. · Your certifications could not be loaded. · The list of states could not be loaded. Type the state instead. | Unable to load the company check. · Unable to load your certifications. · Unable to load the list of states. Enter the state instead. |
| The check, withdrawn | ICR withdrew the verification. Fix what ICR’s note says and file again. | ICR withdrew the verification. Resolve the issue in ICR’s note and file again. |
| The check, re-verification | Verified — ICR asked for new documents by 30 Nov 2026. | Verified. ICR asked for new documents by 30 Nov 2026. |
| Link copied | Link copied | Link copied. |
| Not filed yet | …Jobs for Acme can be drafted meanwhile; they go live once ICR has confirmed the company. | …Jobs for Acme can be drafted in the meantime. They go live once ICR has confirmed the company. |
| Ready to file | Everything the check reads is filled in. Submit it below. · …Your company admin submits it. | All details the check needs are complete. Submit it below. · …Your company admin submits it. |
| Submitted | We’re checking your details. This usually takes one business day — we’ll email you the moment it’s done. | We are checking your details. This usually takes one business day. We will email you when it is complete. |
| Withdrawn, documents late | The documents ICR asked for didn’t arrive by the due date… | The documents ICR asked for did not arrive by the due date… |
| Re-verification open and sent | …send them by 30 Nov 2026 — Acme stays verified until then. · …ICR is reviewing them; Acme stays verified meanwhile. | …send them by 30 Nov 2026. Acme stays verified until then. · …ICR is reviewing them. Acme stays verified in the meantime. |
| The snapshot note | …as they were when submitted; changes saved now are not part of this review. | …as they were when submitted. Changes saved now are not part of this review. |
| The private note | Private — read only by ICR’s review team and your company’s admins. | Private. Visible only to ICR’s review team and your company’s admins. |
| Documents requested | Please upload the requested documents. | Upload the requested documents. |
| Preferred and Elite | …buyer feedback — they can’t be self-requested. This is what they look at. | …buyer feedback. They cannot be requested. This is what the team reviews. |
| The request sheet | …Name each file for what it is — the checklist recognises it by name. Certifications are recorded further down this page, not here… · Submit requested documents — Certified review | …Name each file for what it is. The checklist recognises it by name. Certifications are recorded lower on this page, not here… · Submit Requested Documents: Certified Review |
| Verification history rows | Approved — Certified · Requested — Certified | Approved: Certified · Requested: Certified |
| Expired alert | 2 certifications have expired — record the renewed certificate below to stay compliant. | 2 certifications have expired. Record the renewed certificate below to stay compliant. |
| No certifications | Nothing recorded yet. Add one your company already holds and upload the certificate. | No certifications recorded yet. Add one your company holds and upload the certificate. |
| A replaced certificate, a pending one | valid to 1 Jan 2027 — replaced 2 Feb 2026 · ISO 14001 — Upload Certificate · — (ICR's note) | valid to 1 Jan 2027 · replaced 2 Feb 2026 · ISO 14001: Upload Certificate · (ICR's note, with no dash) |
| Add Certification sheet | Choose a certification. · Upload the certificate your issuing body gave you. It goes on your company’s record straight away — ICR does not issue certifications. · Filled in from the certification — change it if… · Any accredited body may issue this one. Pick yours, or type another. · Who issued the certificate — BSI, TUV SUD, etc. · …so ICR can look it up. · Choose a date · Your company already holds this one. · That didn’t save. Please try again. | Select a certification. · Upload the certificate from your issuing body. It is added to your company’s record immediately. ICR does not issue certifications. · Filled in from the certification. Change it if… · Any accredited body may issue this certification. Select yours or enter another. · The body that issued the certificate, e.g. BSI or TUV SUD. · …so ICR can check it. · Select a date · Your company already holds this certification. · Unable to save. Try again. |
| Add Certification sheet, refusals | Write the issuing body’s name in full (at least N characters). · The expiry date must be today or later — an already-expired certificate cannot be added. · Check the expiry date — it is more than N years away. | Enter the issuing body’s full name (at least N characters). · The expiry date must be today or later. An expired certificate cannot be added. · Check the expiry date. It is more than N years away. |
| Start selling failed | Could not start selling. Please try again. | Unable to start selling. Try again. |
| No company | …invite this email address: accepting the invite links your account. If it isn’t on ICR yet, create it: you become its admin. | …invite this email address. Accepting the invite links your account. If it is not on ICR yet, create it and you become its admin. |
| Not an editor | The company page of Acme is kept by its admins, sellers and buyers. Ask an admin for a change to it. | The company page of Acme is managed by its admins, sellers and buyers. Ask an admin to change it. |
| Names | Enter the company name — it needs at least one letter. · Enter the registered legal name — it needs at least one letter. | Enter the company name. It needs at least one letter. · Enter the registered legal name. It needs at least one letter. |
| GSTIN check character (same meaning) | This GSTIN’s last character doesn’t match the rest — check it for a typo. | This GSTIN’s last character does not match the rest. Check it for a typing error. |
| Work email | Use an email address on your company’s own domain — Gmail, Yahoo, Outlook and other public providers are not accepted. | Use an email address on your company’s own domain. Gmail, Yahoo, Outlook and other public providers are not accepted. |
| Documents the facts call for | Required with the GSTIN — verification reads it. · Required for a private limited — verification reads it. | Required with the GSTIN. Verification uses it. · Required for a private limited. Verification uses it. |
| Contact phone | Enter a phone number of 10 to 15 digits | Enter a phone number of 10 to 15 digits. |
| Logo | That is not an image. Choose a PNG, JPG or WEBP file. · That image is over 5 MB. Compress it or choose a smaller one. · Upload failed. Please try again. | This file is not an image. Select a PNG, JPG or WEBP file. · This image is over 5 MB. Compress it or select a smaller one. · Upload failed. Try again. |
| Locked and empty titles (the lead's ruling; the personal-account gate reads as it does in the jobs area) | You’re using your personal account · Your account isn’t linked to a company · Your role does not edit the company profile · Your company has no supplier listing yet | You Are Using Your Personal Account · Your Account Isn’t Linked to a Company · Your Role Does Not Edit the Company Profile · Your Company Has No Supplier Listing Yet |

Left as they were: every heading, caption, label and helper the owner worded on 12 Nov; the PAN sentences ("Enter a
valid PAN…", the 4th-letter sentence) and the other GSTIN sentences (state code, the PAN it carries), which already
comply and must keep their meaning; the sentences the API refuses a locked field with (`lockedMessage`,
"PAN and GSTIN cannot be edited after verification…"); "Phone" for the company's line (it is not the person's own
number); the reasons ICR gives (`companyActionReasonLabels`); the demo repository's sample failure
("Could not load your company.").

### Team Management (`lib/features/team`)

The owner's 12 Nov words are kept: Team Management, Add Existing ICR Member, Invite Team Member, Pending Access
Requests, Pending Invitations, Edit Access, Assign Role, Inbox Permissions.

| Where | Was | Now |
|---|---|---|
| Buttons, headings, labels and chips to Title Case (14 strings) | Send invite · Ask them to join · Learning roles · Waiting to accept (1) · Office (optional) · Company-wide · Search ICR members by name · Member (learning roles only) · Create a company · Invite a team member · Remove Rahul from the team? · Decline Pooja’s request? · Sales & quotes · Requirements & buying | Send Invite · Ask Them to Join · Learning Roles · Waiting to Accept (1) · Office (Optional) · Company-Wide · Search ICR Members by Name · Member (Learning Roles Only) · Create a Company · Invite a Team Member · Remove Rahul from the Team? · Decline Pooja’s Request? · Sales & Quotes · Requirements & Buying |
| Locked, empty and error titles (the lead's ruling) | This page is for your company’s team admins · No team members yet · Could not load the team. (as the error's title) | This Page Is for Your Company’s Team Admins · No Team Members Yet · Unable to Load the Team |
| A failed read | Could not load the team. | Unable to load the team. |
| Empty Requests | Nobody is waiting to join. Requests to join your company show here. | No pending requests. Requests to join your company will appear here. |
| Empty Pending | Nothing is waiting. People you add or invite show here until they answer. | Nothing is pending. People you add or invite will appear here until they respond. |
| Remove dialog | They lose access to this company’s work at once. Their ICR account, and any other company they belong to, stay theirs. | They will lose access to this company’s work immediately. Their ICR account and their other companies are not affected. |
| Decline dialog | They are told it was declined. They can ask again later. | They will be notified that it was declined. They can ask again later. |
| Add Existing ICR Member | Type a name · Nobody found · They are told, and join once they accept from My companies. To make someone an admin, send an invite instead. | Enter a name · No members found. · They will be notified and will join once they accept from My Companies. To make someone an admin, send an invite instead. |
| Invite Team Member notes | This address has an ICR account. They will get an invite to accept. · Not on ICR yet. They will get an email to join ICR and your team. · You already added this person. They have not accepted yet; take it back from the Pending tab to ask again. · They are asked in-app and join once they accept from My companies. · An invite to this address is already waiting. Sending again replaces it. · Company Admin rights need an invite they accept, so this sends an invite. · Optional — the member covers this office and everything inside it | This email has an ICR account. They will receive an invite to accept. · Not on ICR yet. They will receive an email to join ICR and your team. · You have already added this person and they have not accepted yet. Cancel it in the Pending tab to ask again. · They will be asked in the app and will join once they accept from My Companies. · An invite to this email is already pending. Sending again replaces it. · Company Admin rights require an invite the person accepts, so this sends an invite. · Optional. The member covers this office and everything inside it. |
| Roles | Choose a role · Asked as Recruiter. You name the role they join with. · Tick any number. Each opens its pages in the Learning console. · Pick at least one learning role for a member. | Select a role · Requested as Recruiter. Select the role they will join with. · Select any number. Each opens its pages in the Learning console. · Select at least one learning role for a member. |
| Snackbars | Took back the add for Asha. · Saved Asha. · Asked. They join once they accept. · Another change is still running. | Cancelled the request to add Asha. · Saved changes for Asha. · Request sent. They will join once they accept. · Another change is in progress. |

### Companies directory (`lib/features/directory`)

| Where | Was | Now |
|---|---|---|
| Search field | Search companies | Search Companies |
| Nothing found | No companies match that search. | No companies match your search. |
