import '../jobs/jobs_repository.dart';
import 'career_models.dart';

/// Where the career screens get a candidate's own job search: the API, or the
/// designs' sample content.
abstract class CareerRepository {
  /// The board's source, for opening a job's sheet from a career screen.
  JobsRepository get jobs;

  /// Every one of the member's applications, newest first (`GET /applications/mine`).
  Future<List<CareerApplication>> applications();

  /// One application with its answers and every round (`GET /applications/:id`).
  Future<CareerApplication> application(String id);

  /// `POST /applications/:id/withdraw`; the application as it now stands.
  Future<CareerApplication> withdraw(String id);

  /// `POST /offers/:id/respond`: accept or decline, with an optional note.
  Future<void> respondToOffer(String offerId, {required bool accept, String? note});

  /// A message to the job's hiring contact (`POST /messaging/conversations/job`):
  /// confirming an interview, asking for another time. Returns the thread's id.
  Future<String?> messageHiringTeam(String jobId, {String? message});

  /// Employers' invitations still waiting on the member (`GET /job-invites/mine`).
  Future<List<JobInvite>> invites();

  /// `PATCH /job-invites/:id`: VIEWED once opened, or DECLINED.
  Future<void> respondToInvite(String id, {required bool decline});

  /// Whether recruiters can find the member's résumé; null with no résumé.
  Future<bool?> discoverable();

  /// `PATCH /users/me/resume { discoverable }`.
  Future<void> setDiscoverable(bool on);

  /// The member's saved searches, each with its new matches (`GET /jobs/alerts`).
  Future<List<JobAlert>> alerts();

  /// `POST /jobs/alerts`.
  Future<JobAlert> createAlert({
    required String name,
    required Map<String, String> criteria,
    bool alertsEnabled = true,
    String frequency = 'DAILY',
  });

  /// `PATCH /jobs/alerts/:id`.
  Future<JobAlert> updateAlert(
    String id, {
    String? name,
    Map<String, String>? criteria,
    bool? alertsEnabled,
    String? frequency,
  });

  /// `DELETE /jobs/alerts/:id`.
  Future<void> deleteAlert(String id);

  /// `GET /jobs/alerts/:id/run`: the search's results (its "new" badge counted as seen).
  Future<JobPage> runAlert(String id, {int page = 1});

  /// The member's bookmarks, closed ones included (`GET /jobs/saved`).
  Future<JobPage> savedJobs({int page = 1});

  /// The jobs the member marked "Not interested" (`GET /jobs/actions`, then each job).
  Future<List<Job>> hiddenJobs();

  Future<SeekerQuota?> quota();

  /// How many jobs the member bookmarked and hid (`GET /jobs/actions`).
  Future<({int saved, int hidden})> shelfCounts();

  /// The résumé's strength and what is missing; null when it cannot be read.
  Future<ResumeInsights?> resumeInsights();

  /// Search appearances, profile views and recruiter actions in the last 30 days; null when unreadable.
  Future<ProfilePerformance?> profilePerformance();

  Future<int> unreadNotifications();

  // A company's side of things.

  /// The company's header: name, logo, kind, size, city (`GET /companies/:id`); null when it cannot be read.
  Future<JobCompany?> company(String companyId);

  Future<RatingSummary> ratingSummary(String companyId);

  /// Approved reviews, newest first (`GET /companies/:id/reviews`).
  Future<InsightPage<EmployerReview>> reviews(String companyId, {int page = 1});

  /// The member's own review, in whatever state moderation has it (`/reviews/mine`); null when there is none.
  Future<EmployerReview?> myReview(String companyId);

  /// `POST /companies/:id/reviews`: one per member per company; sending again replaces it and re-enters moderation.
  Future<void> submitReview(String companyId, ReviewDraft draft);

  Future<SalaryInsights> salaries(String companyId);

  /// `POST /companies/:id/salaries`: anonymous, shown only as an average of at least [SalaryInsights.minSample].
  Future<void> submitSalary(String companyId, SalaryDraft draft);

  /// Approved interview experiences, newest first, with the average difficulty and experience.
  Future<InsightPage<InterviewReview>> interviewReviews(String companyId, {int page = 1});

  /// `POST /companies/:id/interview-reviews`.
  Future<void> submitInterviewReview(String companyId, InterviewReviewDraft draft);

  /// The company's people with a public profile (`GET /companies/:id/people`).
  Future<InsightPage<CompanyPerson>> people(String companyId, {int page = 1});

  /// The company's open jobs (`GET /jobs?companyId=`).
  Future<JobPage> companyJobs(String companyId, {int page = 1});
}
