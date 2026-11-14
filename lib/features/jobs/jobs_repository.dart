import 'job_models.dart';

/// Where the Jobs screens get their jobs: the API, or the designs' sample
/// content.
abstract class JobsRepository {
  /// The board at rest: the recommended, preferred and saved-search (or latest)
  /// jobs, with the member's counts. [scoped] false leaves the saved search's
  /// section out for the latest jobs (the member dropped its scope).
  Future<JobsOverview> overview({bool scoped = true});

  /// The board narrowed by a search or filters; [scope] (the saved search the
  /// board is scoped to) narrows it further.
  Future<JobPage> search(JobFilters filters, {int page = 1, JobContext? scope});

  /// The latest open jobs, unscoped.
  Future<JobPage> latest({int page = 1});

  /// The next page of a board section.
  Future<JobPage> more(JobSection section, int page);

  /// Runs the member's saved search: its first page of results, and the "new"
  /// badge counted as seen.
  Future<JobPage> runAlert(JobContext alert);

  /// New matches across the member's saved searches (the "2 new" on Alerts).
  Future<int> newAlertMatches();

  /// The member's applications and saved jobs ("My jobs").
  Future<MyJobs> myJobs();

  Future<Job> detail(String id);

  /// How well the member fits the job, when that can be known.
  Future<JobMatch?> match(Job job);

  Future<CompanyPeople?> peopleAt(JobCompany company);

  Future<void> setSaved(Job job, bool saved);

  /// Where the member sits on [company]'s hiring team: a poster (admin, office admin or recruiter) or a hiring
  /// manager of it by any of their memberships, not only the company they act for (the website and the API read it
  /// the same way). Nobody on a company's hiring team applies to its jobs.
  Future<HiringTeamSeat> hiringTeamSeatAt(JobCompany company);

  /// Whether the member already has a phone on file; applying needs one.
  Future<bool> hasPhone();

  /// `POST /jobs/:id/apply`: the number (when the profile has none), the note,
  /// the résumé chosen, the expected salary, the screening answers, a LinkedIn link, and, for a
  /// posting that asks, the diversity groups the member declares and their gender.
  Future<void> apply(
    Job job, {
    String? phone,
    String? coverNote,
    String? resumeId,
    num? expectedSalary,
    Map<String, String>? answers,
    String? linkedinUrl,
    List<String>? diversityIdentities,
    String? gender,
  });

  /// The member's résumés, the default first (`GET /users/me/resumes`).
  Future<List<ResumeChoice>> resumes();

  /// The month's application allowance, when the plan has one.
  Future<SeekerQuota?> quota();

  /// "Not interested": the job leaves the member's board (`POST /jobs/:id/hide`),
  /// or comes back (`DELETE`).
  Future<void> setHidden(Job job, bool hidden);

  /// Opens a conversation with the job's contact, with [message] as its first
  /// (or next) message when given, and returns its id.
  Future<String?> messageContact(Job job, {String? message});

  Future<int> unreadNotifications();

  Uri link(Job job);
}
