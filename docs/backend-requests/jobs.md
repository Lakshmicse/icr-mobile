# Backend requests: Jobs, Career and Hiring

The portal is the lead's to change. Every item is additive and leaves each existing web response unchanged. The app works without them: where one is missing the control does the nearest true thing (named below).

## 1. A candidate answers an interview invitation (not built; the app messages the hiring team instead)

**Why.** "Confirm" and "Ask for another time" on a candidate's interview (the application page, My applications, Interviews) have nothing to call. `InterviewsController` has `schedule`, `update` (the hiring team), `feedback` and `mine` (the **panel's** list: RECRUITER_TIER and HIRING_MANAGER, not the candidate's), and the `Interview` row has no field for the candidate's answer. Until then both buttons open the job thread with the hiring team (`POST /messaging/conversations/job`, 30 an hour) with the sentence written for them.

**Schema** (`Interview`): one nullable column, `candidateResponse CandidateInterviewResponse?` (`CONFIRMED`, `RESCHEDULE_REQUESTED`) and `candidateRespondedAt DateTime?`, reset to null whenever the team changes the time (`UpdateInterviewDto.scheduledAt`). A migration with the two columns and the enum.

**Endpoint** (`interviews.controller.ts`, beside `feedback`, for the person whose application it is):

```ts
@UseGuards(RolesGuard)
@Roles(...PERSON_ROLES)
@Post('interviews/:id/respond')
respond(@CurrentUser() user: AuthUser, @Param('id') id: string, @Body() dto: RespondInterviewDto) {
  return this.interviews.respond(user, id, dto);
}
```

```ts
export class RespondInterviewDto {
  @ApiProperty({ enum: CandidateInterviewResponse }) @IsEnum(CandidateInterviewResponse) response: CandidateInterviewResponse;
  @ApiPropertyOptional({ description: 'A line for the hiring team: the times that suit, or why.' })
  @IsOptional() @IsString() @MaxLength(500) note?: string;
}
```

**Service.** Load the interview with its application; `app.applicantId === user.id` or `notFound`; refuse a CANCELLED, COMPLETED or past round (`badRequest('errors.applications.interviewClosed')`); write the two columns; append an `INTERVIEW_UPDATED` event (visibility INTERNAL, note = the candidate's line); notify the recruiter and the panel (`notifications.create({ key: 'applications.interviewResponse', ... target: { kind: 'application.employer', ... } })`). Return the interview through the candidate view (`candidate-view.ts`), which gains `candidateResponse`.

**App side.** `CareerRepository.respondToInterview(interviewId, response, note)` is not written; the two buttons are the single place to switch (`confirmRoundMessage` / `rescheduleRoundMessage` in `application_dialogs.dart` become a call, and the strip shows "You confirmed" / "You asked for another time").

## 2. The hiring team withdraws an offer (not built; the app cannot, and says so)

**Why.** `OfferStatus` has `WITHDRAWN` and `offers.service.ts` treats it as ended (`TERMINAL` lets a new offer be made), but nothing ever sets it: `UpdateOfferDto` is `PartialType(CreateOfferDto)`, so a status cannot be sent, and there is no withdraw route. A recruiter who sent an offer by mistake can only change it (`PATCH /offers/:id`, allowed while DRAFT or SENT). The Offer card on the application page offers **Edit** and, for a draft, **Send**, and no Withdraw.

**Endpoint** (`interviews.controller.ts`, beside `offers/:id/send`, `@Roles(...RECRUITER_TIER)`):

```ts
@Post('offers/:id/withdraw')
withdrawOffer(@CurrentUser() user: AuthUser, @Param('id') id: string) {
  return this.offers.withdraw(user, id);
}
```

**Service** (`offers.service.ts`): `loadScoped`; only DRAFT or SENT may be withdrawn (`badRequest('errors.applications.offerNotWithdrawable')` otherwise); set `WITHDRAWN` and `respondedAt`; append an `OFFER_RESPONDED` event (visibility CANDIDATE, note "Withdrawn by the employer"); notify the candidate when it had been SENT. The application stays at OFFER (the team moves it, or rejects it, afterwards).

**App side.** `HiringRepository.withdrawOffer(offerId)` and a "Withdraw offer" button on a draft or sent offer's card (ask first) are one method and one button. The live offer test, which today ends with the person hired because an offer cannot be taken back, would withdraw instead and leave the sandbox applicant free for the next run.

## 3. A rating can be taken off (small)

`POST /applications/:id/notes` takes `rating` 1 to 5 and nothing clears it, so the pipeline's stars cannot be un-given (tapping the star already given does nothing). Accept `rating: 0` (or `null`) as "no rating" and set `Application.rating = null`; the `RATING` event then reads "Cleared the rating". The app then lets a second tap on the same star clear it.

## 4. The pipeline row carries the applicant's place (small)

`GET /jobs/:id/applications` returns the résumé's `headline`, `skills`, `experienceYears`, `currentCompany` and `fileUrl`, but not `currentLocation` or `noticePeriodDays` (the application page has both). Adding them to the list's `resume` select lets a row say "Pune • 60 days notice" (the two things a recruiter filters a pile by) without opening each application.

## 5. The company's live-posting room (optional)

A plan's `jobs.livePosts` limit is enforced when a posting is published (the API refuses with the plan's sentence), but no read says how many are left, so the composer cannot say "2 of 3 live posts used" before the recruiter tries. `GET /jobs/company/overview` could add `livePosts: { used, limit | null }` (the same `PlanGateService` count). The app shows it above Publish when `limit` is set and falls back to today's behaviour (the API's sentence after the tap) when it is absent.

## 6. Nothing else so far

Everything else the screens use is an existing endpoint: `/jobs`, `/jobs/company`, `/jobs/company/overview`, `/jobs/:id/applications`, `/jobs/:id/screening-questions`, `/job-titles`, `/jobs/skill-suggestions`, `/applications/*`, `/interviews/*`, `/offers/*`, `/employer-verification/gate`, `/team/members`, `/notifications`.
