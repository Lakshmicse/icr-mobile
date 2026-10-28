import 'hiring_models.dart';

/// Where the employer screens get the company's jobs and applicants: the API, or
/// sample content.
abstract class HiringRepository {
  /// Who is signed in and whether their company may publish (`GET /auth/me`, `GET /employer-verification/gate`).
  Future<HiringAccess> access();

  // --- the company's jobs ---------------------------------------------------------

  /// The company's postings (`GET /jobs/company`). [status] narrows to one; [mine] to the member's own.
  Future<PostedJobsPage> jobs({
    PostingStatus? status,
    String? search,
    bool mine = false,
    String sort = 'recent',
    int page = 1,
  });

  /// The figures across every posting and what needs doing (`GET /jobs/company/overview`).
  Future<HiringOverview> overview();

  /// One posting as its own team reads it, for the composer (`GET /jobs/:id`).
  Future<JobDraft> job(String id);

  /// `POST /jobs`: makes the posting. [status] DRAFT saves it; OPEN publishes it (the API checks it).
  Future<String> createJob(JobDraft draft, PostingStatus status);

  /// `PATCH /jobs/:id`: saves the changes; [status] moves it too (null leaves it).
  Future<void> updateJob(String id, JobDraft draft, {PostingStatus? status});

  /// `PATCH /jobs/:id { status }`: pause, resume, close or reopen.
  Future<void> setStatus(String id, PostingStatus status);

  /// `POST /jobs/:id/submit-review`: sends a draft to ICR's review instead of publishing it.
  Future<void> submitForReview(String id);

  /// `DELETE /jobs/:id`.
  Future<void> deleteJob(String id);

  /// The staff-managed job titles (`GET /job-titles`), for the title box's suggestions.
  Future<List<JobTitleOption>> jobTitles();

  /// Skills matching what was typed (`GET /jobs/skill-suggestions`).
  Future<List<String>> skillSuggestions(String query);

  /// The questions a job asks with an application (`GET /jobs/:id/screening-questions`).
  Future<List<ScreeningDraft>> screeningQuestions(String jobId);

  /// `PUT /jobs/:id/screening-questions`: replaces them, in order.
  Future<void> setScreeningQuestions(String jobId, List<ScreeningDraft> questions);

  // --- a job's applicants ------------------------------------------------------------

  /// The applicants of one job (`GET /jobs/:id/applications`); [stage] narrows to one stage.
  Future<ApplicantsPage> applicants(
    String jobId, {
    String? stage,
    String sort = 'recent',
    int? minRating,
    bool qualifiedOnly = false,
  });

  /// One application with its answers, rounds and offers (`GET /applications/:id`) and its activity.
  Future<ApplicantDetail> applicant(String applicationId);

  /// `PATCH /applications/:id/stage`.
  Future<void> moveStage(String applicationId, String stage, {String? note});

  /// `POST /applications/:id/notes`: an internal note and/or a 1-5 rating.
  Future<void> addNote(String applicationId, {String? note, int? rating});

  /// `POST /applications/:id/interviews`.
  Future<TeamInterview> scheduleInterview(String applicationId, InterviewDraft draft);

  /// `PATCH /interviews/:id`: a new time or place, or a status (CANCELLED, COMPLETED, NO_SHOW).
  Future<TeamInterview> updateInterview(String interviewId, {InterviewDraft? draft, String? status});

  /// `POST /applications/:id/offers`, then `POST /offers/:id/send` when [send].
  Future<TeamOffer> makeOffer(String applicationId, OfferDraft draft, {bool send = true});

  /// `PATCH /offers/:id`: changes a draft or sent offer.
  Future<TeamOffer> updateOffer(String offerId, OfferDraft draft);

  /// `POST /offers/:id/send`: sends a drafted offer; the application moves to Offer.
  Future<TeamOffer> sendOffer(String offerId);

  /// `POST /applications/:id/conversation`: the thread with the applicant; returns its id.
  Future<String?> messageApplicant(String applicationId);

  /// The people who can sit on an interview panel (`GET /team/members`).
  Future<List<TeamMember>> teamMembers();

  Future<int> unreadNotifications();
}
