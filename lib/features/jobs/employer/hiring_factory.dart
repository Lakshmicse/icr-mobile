import '../api_jobs_repository.dart';
import '../jobs_repository.dart';
import 'api_hiring_repository.dart';
import 'demo_hiring_repository.dart';
import 'hiring_models.dart';
import 'hiring_repository.dart';

/// The employer source that matches a jobs source: the API's beside the API's jobs (one client,
/// one sign-in), the sample content beside the demo's. In the demo the member is a professional,
/// not a hirer, so the board shows what the design shows; a showcase of the employer screens builds
/// `DemoHiringRepository()` itself, which is a recruiter.
HiringRepository hiringRepositoryFor(JobsRepository jobs) => jobs is ApiJobsRepository
    ? ApiHiringRepository(api: jobs.api)
    : DemoHiringRepository(
        access: const HiringAccess(userId: 'me', role: 'PROFESSIONAL'),
      );
