import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../job_links.dart';
import '../jobs_controller.dart';
import '../jobs_navigation.dart';
import 'applicants_screen.dart';
import 'employer_jobs_screen.dart';
import 'hiring_models.dart';
import 'hiring_repository.dart';
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

/// What a member who is not on a hiring team gets from "Post a job": jobs are posted for a company,
/// so the way in is to set one up (or to ask the company's admin for the recruiter role).
Future<void> showHirersOnly(BuildContext context, {required JobsNavigation navigation, required JobLinks links}) {
  return showDialog<void>(
    context: context,
    builder: (dialog) => AlertDialog(
      key: const ValueKey('hirers-only-dialog'),
      title: const Text('Jobs are posted for a company'),
      content: const Text(
        'Set up your company on ICR and you can post jobs, run applicants and make offers. '
        'If your company is already here, ask its admin to make you a recruiter.',
      ),
      actions: [
        TextButton(
          key: const ValueKey('hirers-only-later'),
          onPressed: () => Navigator.pop(dialog),
          child: const Text('Not now'),
        ),
        TextButton(
          key: const ValueKey('hirers-only-create'),
          onPressed: () {
            Navigator.pop(dialog);
            navigation.createCompany(context, links);
          },
          child: const Text('Create a company'),
        ),
      ],
    ),
  );
}
