import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../job_links.dart';
import '../jobs_controller.dart';
import '../jobs_navigation.dart';
import 'applicants_screen.dart';
import 'employer_jobs_screen.dart';
import 'hiring_models.dart';
import 'hiring_repository.dart';
import 'interview_brief_screen.dart';
import 'post_job_screen.dart';

/// Opens each part of the employer area over whatever is showing, with the source, the links and the
/// hand-overs they all share.
///
///     hiringRoutesOf(context).jobs();
class HiringRoutes {
  const HiringRoutes({
    required this.context,
    required this.repository,
    this.links = const SystemJobLinks(),
    this.navigation = JobsNavigation.none,
    this.clock,
  });

  final BuildContext context;
  final HiringRepository repository;
  final JobLinks links;
  final JobsNavigation navigation;
  final DateTime Function()? clock;

  Future<void> _push(Widget screen) => Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => screen));

  /// "Jobs you posted": the company's postings, on [status] (all when none).
  Future<void> jobs({PostingStatus? status}) => _push(
    EmployerJobsScreen(repository: repository, links: links, navigation: navigation, status: status, clock: clock),
  );

  /// "Post a job": the composer, empty or from [initial].
  Future<void> postJob({JobDraft? initial}) => _push(
    PostJobScreen(repository: repository, initial: initial, links: links, navigation: navigation, clock: clock),
  );

  /// "Edit job".
  Future<void> editJob(String jobId) =>
      _push(PostJobScreen(repository: repository, jobId: jobId, links: links, navigation: navigation, clock: clock));

  /// An interview's page for its panel (the website's `/manage/interviews/:id`). [onOpened] runs once it is up.
  Future<void> interview(String interviewId, {void Function(BuildContext context)? onOpened}) => _push(
    InterviewBriefScreen(
      repository: repository,
      interviewId: interviewId,
      links: links,
      navigation: navigation,
      onOpened: onOpened,
      clock: clock,
    ),
  );

  /// A job's applicants, on [stage] (all when none).
  Future<void> applicants(String jobId, {String? title, String? stage}) => _push(
    ApplicantsScreen(
      repository: repository,
      jobId: jobId,
      jobTitle: title,
      stage: stage,
      links: links,
      navigation: navigation,
      clock: clock,
    ),
  );
}

/// [HiringRoutes] for the screen at [context]: the app's Jobs source, its links, and the hand-overs
/// of the nearest [JobsNavigationScope]. Needs the `JobsController` the shell holds above its tabs.
HiringRoutes hiringRoutesOf(
  BuildContext context, {
  JobLinks? links,
  JobsNavigation? navigation,
  DateTime Function()? clock,
}) {
  final jobs = context.read<JobsController>();
  return HiringRoutes(
    context: context,
    repository: jobs.hiring,
    links: links ?? jobs.links,
    navigation: navigation ?? JobsNavigationScope.of(context),
    clock: clock,
  );
}

/// "Post a job" from anywhere — the Jobs board's chip, the Discover sheet's Hire and Post a Job, a link to the
/// website's `/manage/jobs/new`: the composer for someone on a company's hiring team, read afresh (a company
/// switch changes it). Anyone else gets [showHirersOnly], never the create-company screen while they have a
/// company (owner's report, 3 Nov 2026: Hire opened "create a company" for a member who already had one).
Future<void> openPostJob(BuildContext context, {JobsNavigation? navigation}) async {
  final jobs = context.read<JobsController>();
  final nav = navigation ?? JobsNavigationScope.of(context);
  final access = await jobs.hiringAccess(refresh: true);
  if (!context.mounted) return;
  if (access == null) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Unable to check your account. Try again in a moment.')));
    return;
  }
  if (access.canManage) {
    await hiringRoutesOf(context, navigation: nav).postJob();
    return;
  }
  await showHirersOnly(context, navigation: nav, links: jobs.links, access: access);
}

/// What a member who is not on a hiring team gets from "Post a job", in the website's order (`NoCompany` on
/// `/manage/jobs/new`): acting as themselves while they belong to companies, switch to one; belonging to none,
/// create one; acting for a company in a role that does not post, ask its admin for the recruiter role.
Future<void> showHirersOnly(
  BuildContext context, {
  required JobsNavigation navigation,
  required JobLinks links,
  HiringAccess? access,
}) {
  final actingForCompany = access?.companyId != null;
  final canSwitch = !actingForCompany && (access?.companiesHeld ?? 0) > 0;
  final (title, body) = actingForCompany
      ? (
          'Jobs Are Posted by the Hiring Team',
          'Your role at this company cannot post jobs. Ask its admin to make you a recruiter to post '
              'jobs, manage applicants and make offers.',
        )
      : canSwitch
      ? (
          'You Are Using Your Personal Account',
          'Jobs belong to a company. Switch to one of your companies to post a job on its behalf.',
        )
      : (
          'Jobs Are Posted for a Company',
          'Create your company on ICR to post jobs, manage applicants and make offers. '
              'If your company is already on ICR, ask its admin to make you a recruiter.',
        );
  return showDialog<void>(
    context: context,
    builder: (dialog) => AlertDialog(
      key: const ValueKey('hirers-only-dialog'),
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          key: const ValueKey('hirers-only-later'),
          onPressed: () => Navigator.pop(dialog),
          child: Text(actingForCompany ? 'OK' : 'Not Now'),
        ),
        if (canSwitch)
          TextButton(
            key: const ValueKey('hirers-only-switch'),
            onPressed: () {
              Navigator.pop(dialog);
              navigation.switchCompany(context, links);
            },
            child: const Text('Switch Company'),
          )
        else if (!actingForCompany)
          TextButton(
            key: const ValueKey('hirers-only-create'),
            onPressed: () {
              Navigator.pop(dialog);
              navigation.createCompany(context, links);
            },
            child: const Text('Create a Company'),
          ),
      ],
    ),
  );
}
