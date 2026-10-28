import '../jobs/api_jobs_repository.dart';
import '../jobs/jobs_repository.dart';
import 'api_career_repository.dart';
import 'career_repository.dart';
import 'demo_career_repository.dart';

/// The career source that matches a jobs source: the API's one beside the API's
/// jobs (sharing its client and its bookmark state), the sample content beside
/// the demo's. Screens opened from the board use it so they read what the board reads.
CareerRepository careerRepositoryFor(JobsRepository jobs) =>
    jobs is ApiJobsRepository ? ApiCareerRepository(api: jobs.api, jobs: jobs) : DemoCareerRepository(jobs: jobs);
