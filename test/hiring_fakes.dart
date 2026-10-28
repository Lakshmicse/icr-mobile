import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/jobs/employer/demo_hiring_repository.dart';
import 'package:icr_mobile/features/jobs/employer/hiring_models.dart';
import 'package:icr_mobile/features/jobs/jobs_navigation.dart';

import 'jobs_fakes.dart';

/// The day the employer tests run on, so "closes in 2 days" and "applied 3 days ago" never drift.
final hiringNow = DateTime(2026, 10, 26, 9);

DateTime hiringClock() => hiringNow;

/// The demo employer source that writes down what it is asked and can be told to refuse. A test
/// reads `calls` (from the demo) and the typed lists below; `failures['updateJob'] = ApiError(...)`
/// makes the next such calls throw until the entry is removed.
class SpyHiring extends DemoHiringRepository {
  SpyHiring({DateTime? now, super.access}) : super(now: now ?? hiringNow);

  final Map<String, Object> failures = {};

  final created = <({JobDraft draft, PostingStatus status})>[];
  final updated = <({String id, JobDraft draft, PostingStatus? status})>[];
  final questionSets = <({String id, List<ScreeningDraft> questions})>[];
  final moves = <({String id, String stage, String? note})>[];
  final notes = <({String id, String? note, int? rating})>[];
  final booked = <({String app, InterviewDraft draft})>[];
  final changedRounds = <({String id, InterviewDraft? draft, String? status})>[];
  final offered = <({String app, OfferDraft draft, bool send})>[];
  final statuses = <({String id, PostingStatus status})>[];
  final applicantQueries = <({String jobId, String? stage, String sort, int? minRating, bool qualifiedOnly})>[];

  /// Answers one application's page in place of the demo's.
  Future<ApplicantDetail> Function(String applicationId)? applicantAnswer;

  final jobQueries = <({PostingStatus? status, String? search, bool mine, String sort, int page})>[];

  /// Answers the company's list in place of the demo's, for a test that needs its own postings.
  Future<PostedJobsPage> Function(({PostingStatus? status, String? search, bool mine, String sort, int page}) query)?
  jobsAnswer;

  void _check(String method) {
    final e = failures[method];
    if (e != null) throw e;
  }

  @override
  Future<HiringAccess> access() {
    _check('access');
    return super.access();
  }

  @override
  Future<PostedJobsPage> jobs({
    PostingStatus? status,
    String? search,
    bool mine = false,
    String sort = 'recent',
    int page = 1,
  }) {
    _check('jobs');
    final query = (status: status, search: search, mine: mine, sort: sort, page: page);
    jobQueries.add(query);
    final answer = jobsAnswer;
    if (answer != null) return answer(query);
    return super.jobs(status: status, search: search, mine: mine, sort: sort, page: page);
  }

  @override
  Future<HiringOverview> overview() {
    _check('overview');
    return super.overview();
  }

  @override
  Future<JobDraft> job(String id) {
    _check('job');
    return super.job(id);
  }

  @override
  Future<String> createJob(JobDraft draft, PostingStatus status) {
    _check('createJob');
    created.add((draft: draft, status: status));
    return super.createJob(draft, status);
  }

  @override
  Future<void> updateJob(String id, JobDraft draft, {PostingStatus? status}) {
    _check('updateJob');
    updated.add((id: id, draft: draft, status: status));
    return super.updateJob(id, draft, status: status);
  }

  @override
  Future<void> setStatus(String id, PostingStatus status) {
    _check('setStatus');
    statuses.add((id: id, status: status));
    return super.setStatus(id, status);
  }

  @override
  Future<void> submitForReview(String id) {
    _check('submitForReview');
    return super.submitForReview(id);
  }

  @override
  Future<void> deleteJob(String id) {
    _check('deleteJob');
    return super.deleteJob(id);
  }

  @override
  Future<void> setScreeningQuestions(String jobId, List<ScreeningDraft> questions) {
    _check('setScreeningQuestions');
    questionSets.add((id: jobId, questions: questions));
    return super.setScreeningQuestions(jobId, questions);
  }

  @override
  Future<ApplicantsPage> applicants(
    String jobId, {
    String? stage,
    String sort = 'recent',
    int? minRating,
    bool qualifiedOnly = false,
  }) {
    _check('applicants');
    applicantQueries.add((jobId: jobId, stage: stage, sort: sort, minRating: minRating, qualifiedOnly: qualifiedOnly));
    return super.applicants(jobId, stage: stage, sort: sort, minRating: minRating, qualifiedOnly: qualifiedOnly);
  }

  @override
  Future<ApplicantDetail> applicant(String applicationId) {
    _check('applicant');
    final answer = applicantAnswer;
    if (answer != null) return answer(applicationId);
    return super.applicant(applicationId);
  }

  @override
  Future<void> moveStage(String applicationId, String stage, {String? note}) {
    _check('moveStage');
    moves.add((id: applicationId, stage: stage, note: note));
    return super.moveStage(applicationId, stage, note: note);
  }

  @override
  Future<void> addNote(String applicationId, {String? note, int? rating}) {
    _check('addNote');
    notes.add((id: applicationId, note: note, rating: rating));
    return super.addNote(applicationId, note: note, rating: rating);
  }

  @override
  Future<TeamInterview> scheduleInterview(String applicationId, InterviewDraft draft) {
    _check('scheduleInterview');
    booked.add((app: applicationId, draft: draft));
    return super.scheduleInterview(applicationId, draft);
  }

  @override
  Future<TeamInterview> updateInterview(String interviewId, {InterviewDraft? draft, String? status}) async {
    _check('updateInterview');
    changedRounds.add((id: interviewId, draft: draft, status: status));
    try {
      return await super.updateInterview(interviewId, draft: draft, status: status);
    } on StateError {
      // A round only a test's own answer holds: the demo has nothing to change.
      return TeamInterview(
        id: interviewId,
        round: 1,
        scheduledAt: hiringNow,
        mode: 'VIDEO',
        status: status ?? 'SCHEDULED',
      );
    }
  }

  @override
  Future<TeamOffer> makeOffer(String applicationId, OfferDraft draft, {bool send = true}) {
    _check('makeOffer');
    offered.add((app: applicationId, draft: draft, send: send));
    return super.makeOffer(applicationId, draft, send: send);
  }

  @override
  Future<TeamOffer> updateOffer(String offerId, OfferDraft draft) {
    _check('updateOffer');
    return super.updateOffer(offerId, draft);
  }

  @override
  Future<TeamOffer> sendOffer(String offerId) {
    _check('sendOffer');
    return super.sendOffer(offerId);
  }

  @override
  Future<String?> messageApplicant(String applicationId) {
    _check('messageApplicant');
    return super.messageApplicant(applicationId);
  }

  @override
  Future<List<TeamMember>> teamMembers() {
    _check('teamMembers');
    return super.teamMembers();
  }
}

/// Puts [screen] on a route above a plain home page, on a tall phone so every section is built,
/// and opens it: leaving the screen then lands on the home page, as in the app.
Future<RecordingLinks> openOnPhone(
  WidgetTester tester,
  Widget Function(BuildContext context, RecordingLinks links) screen, {
  Size size = const Size(390, 3200),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final links = RecordingLinks();
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              key: const ValueKey('open-screen'),
              onPressed: () =>
                  Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => screen(context, links))),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open-screen')));
  await tester.pumpAndSettle();
  return links;
}

/// A [JobsNavigation] that writes down where each hand-over went.
class RecordingNavigation {
  final calls = <String>[];

  late final JobsNavigation navigation = JobsNavigation(
    onOpenCompany: (id) => calls.add('company $id'),
    onOpenConversation: (id) => calls.add('conversation $id'),
    onOpenProfile: (id) => calls.add('profile $id'),
    onBell: () => calls.add('bell'),
    onFindJobs: (q) => calls.add('find ${q ?? ''}'.trim()),
    onEditProfile: () => calls.add('edit-profile'),
    onCreateCompany: () => calls.add('create-company'),
    onVerifyCompany: () => calls.add('verify-company'),
    onDemonstrateSkills: () => calls.add('assessments'),
  );
}
