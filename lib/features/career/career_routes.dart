import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../jobs/employer/hiring_routes.dart';
import '../jobs/job_links.dart';
import '../jobs/jobs_controller.dart';
import '../jobs/jobs_navigation.dart';
import 'application_detail_screen.dart';
import 'application_logic.dart';
import 'career_base.dart';
import 'career_factory.dart';
import 'career_hub_screen.dart';
import 'career_models.dart';
import 'career_repository.dart';
import 'interviews_screen.dart';
import 'invitations_screen.dart';
import 'job_alert_models.dart';
import 'job_alerts_screen.dart';
import 'my_applications_screen.dart';
import 'saved_jobs_controller.dart';
import 'saved_jobs_screen.dart';

/// Opens each part of the career area over whatever is showing, with the source, the
/// links and the hand-overs they all share. Screens that open another (the hub, the
/// board's chips, a notification) go through it.
///
///     careerRoutesOf(context).savedJobs();
class CareerRoutes {
  const CareerRoutes({
    required this.context,
    required this.repository,
    this.links = const SystemJobLinks(),
    this.navigation = JobsNavigation.none,
    this.clock,
    this.onChanged,
    this.postedJobs,
  });

  final BuildContext context;
  final CareerRepository repository;
  final JobLinks links;
  final JobsNavigation navigation;
  final CareerClock? clock;

  /// Tells the board a count it shows may have changed (alerts seen, one made).
  final VoidCallback? onChanged;

  /// "Jobs you posted", for a member on a company's hiring team; null hides the entry.
  final Future<void> Function()? postedJobs;

  Future<void> _push(Widget screen) => Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => screen));

  /// "Your career": the hub.
  Future<void> hub() => _push(
    CareerHubScreen(
      repository: repository,
      links: links,
      navigation: navigation,
      clock: clock,
      onChanged: onChanged,
      postedJobs: postedJobs,
    ),
  );

  /// "My applications", on [tab] (Active when none).
  Future<void> applications({ApplicationsTab? tab}) =>
      _push(MyApplicationsScreen(repository: repository, links: links, navigation: navigation, tab: tab, clock: clock));

  /// One application's own page.
  Future<void> application(CareerApplication app) => _push(
    ApplicationDetailScreen(
      repository: repository,
      application: app,
      links: links,
      navigation: navigation,
      clock: clock,
    ),
  );

  Future<void> interviews() =>
      _push(InterviewsScreen(repository: repository, links: links, navigation: navigation, clock: clock));

  /// "Saved jobs", on the saved or the hidden shelf.
  Future<void> savedJobs({SavedTab tab = SavedTab.saved}) =>
      _push(SavedJobsScreen(repository: repository, links: links, navigation: navigation, tab: tab));

  /// "Job alerts"; [create] opens the new-alert form, filled from [criteria].
  Future<void> alerts({bool create = false, AlertCriteria? criteria}) => openJobAlerts(
    context,
    repository: repository,
    links: links,
    navigation: navigation,
    create: create,
    criteria: criteria,
    onChanged: onChanged,
  );

  Future<void> invitations() => _push(InvitationsScreen(repository: repository, links: links, navigation: navigation));
}

/// The career source behind the app's Jobs tab (the API's beside the API's jobs, the sample
/// content beside the demo's). Needs the `JobsController` provider the shell holds above its tabs.
CareerRepository careerRepositoryOf(BuildContext context) =>
    careerRepositoryFor(context.read<JobsController>().repository);

/// [CareerRoutes] for the screen at [context]: the app's Jobs source, its links, and the
/// hand-overs of the nearest [JobsNavigationScope] unless others are given.
CareerRoutes careerRoutesOf(
  BuildContext context, {
  JobLinks? links,
  JobsNavigation? navigation,
  CareerClock? clock,
  VoidCallback? onChanged,
}) {
  final jobs = context.read<JobsController>();
  return CareerRoutes(
    context: context,
    repository: careerRepositoryFor(jobs.repository),
    links: links ?? jobs.links,
    navigation: navigation ?? JobsNavigationScope.of(context),
    clock: clock,
    onChanged: onChanged ?? jobs.refreshAlertCount,
    postedJobs: jobs.canHire ? () => hiringRoutesOf(context).jobs() : null,
  );
}
