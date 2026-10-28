/// Stand-ins for the Jobs tests: the links a tap would have followed, and the
/// demo source with every call written down and any answer replaceable.
library;

import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/features/jobs/demo_jobs_repository.dart';
import 'package:icr_mobile/features/jobs/job_links.dart';
import 'package:icr_mobile/features/jobs/job_models.dart';

/// Where each tap would have gone, instead of the browser and the share sheet.
class RecordingLinks extends JobLinks {
  final opened = <Uri>[];
  final shared = <String>[];

  /// What [open] answers: false is "nothing could open it".
  bool opens = true;

  /// The paths (and queries) of the opened site pages, `https://icr.org.in` dropped.
  List<String> get paths => [for (final u in opened) '${u.path}${u.hasQuery ? '?${u.query}' : ''}'];

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return opens;
  }

  @override
  Future<void> share({required String text, String? subject}) async => shared.add(text);
}

/// A job a board row can show.
Job fakeJob(
  String id, {
  String title = 'Facilities Manager',
  bool easyApply = true,
  String? applyUrl,
  bool saved = false,
  bool applied = false,
}) => Job(
  id: id,
  title: title,
  company: JobCompany(id: 'c-$id', name: 'Company $id'),
  city: 'Mumbai',
  country: 'India',
  workMode: WorkMode.onsite,
  easyApply: easyApply,
  applyUrl: applyUrl,
  saved: saved,
  applied: applied,
);

/// The demo source, with its calls recorded and its answers replaceable.
class SpyJobsRepository extends DemoJobsRepository {
  final calls = <String>[];
  final searches = <({JobFilters filters, int page, JobContext? scope})>[];
  final applications =
      <
        ({
          String jobId,
          String? phone,
          String? note,
          String? resumeId,
          num? expectedSalary,
          Map<String, String>? answers,
          String? linkedinUrl,
          List<String>? diversityIdentities,
          String? gender,
        })
      >[];
  final messages = <String?>[];
  final saves = <({String jobId, bool saved})>[];

  /// Replaces what the board's overview answers.
  JobsOverview Function(bool scoped)? overviewAnswer;

  /// Replaces what a search answers.
  JobPage Function(JobFilters filters, int page)? searchAnswer;

  /// Replaces what "View More" fetches.
  JobPage Function(JobSection section, int page)? moreAnswer;

  /// The job the sheet opens, in place of the demo's.
  Job? detailAnswer;

  /// What the sheet's match card and people strip read; null leaves them out.
  JobMatch? matchAnswer;
  bool matchSet = false;

  /// When set, saving, applying and messaging fail with it.
  ApiError? setSavedError;
  ApiError? applyError;
  ApiError? messageError;

  bool phoneOnFile = true;
  String? conversationId = 'conv-1';
  int alertMatches = 2;

  @override
  Future<JobsOverview> overview({bool scoped = true}) {
    calls.add('overview scoped=$scoped');
    final answer = overviewAnswer;
    return answer == null ? super.overview(scoped: scoped) : Future.value(answer(scoped));
  }

  @override
  Future<JobPage> search(JobFilters filters, {int page = 1, JobContext? scope}) {
    calls.add('search');
    searches.add((filters: filters, page: page, scope: scope));
    final answer = searchAnswer;
    return answer == null ? super.search(filters, page: page, scope: scope) : Future.value(answer(filters, page));
  }

  @override
  Future<JobPage> latest({int page = 1}) {
    calls.add('latest');
    return super.latest(page: page);
  }

  @override
  Future<JobPage> more(JobSection section, int page) {
    calls.add('more ${section.key} $page');
    final answer = moreAnswer;
    return answer == null ? super.more(section, page) : Future.value(answer(section, page));
  }

  @override
  Future<JobPage> runAlert(JobContext alert) {
    calls.add('runAlert');
    alertMatches = 0;
    return super.runAlert(alert);
  }

  @override
  Future<int> newAlertMatches() async => alertMatches;

  @override
  Future<MyJobs> myJobs() {
    calls.add('myJobs');
    return super.myJobs();
  }

  @override
  Future<Job> detail(String id) async => detailAnswer ?? await super.detail(id);

  @override
  Future<JobMatch?> match(Job job) => matchSet ? Future.value(matchAnswer) : super.match(job);

  @override
  Future<void> setSaved(Job job, bool saved) async {
    saves.add((jobId: job.id, saved: saved));
    final error = setSavedError;
    if (error != null) throw error;
    await super.setSaved(job, saved);
  }

  @override
  Future<bool> hasPhone() async => phoneOnFile;

  @override
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
  }) async {
    applications.add((
      jobId: job.id,
      phone: phone,
      note: coverNote,
      resumeId: resumeId,
      expectedSalary: expectedSalary,
      answers: answers,
      linkedinUrl: linkedinUrl,
      diversityIdentities: diversityIdentities,
      gender: gender,
    ));
    final error = applyError;
    if (error != null) throw error;
    await super.apply(
      job,
      phone: phone,
      coverNote: coverNote,
      resumeId: resumeId,
      expectedSalary: expectedSalary,
      answers: answers,
      linkedinUrl: linkedinUrl,
      diversityIdentities: diversityIdentities,
      gender: gender,
    );
  }

  @override
  Future<String?> messageContact(Job job, {String? message}) async {
    calls.add('message');
    messages.add(message);
    final error = messageError;
    if (error != null) throw error;
    return conversationId;
  }
}
