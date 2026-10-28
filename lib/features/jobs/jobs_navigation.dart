import 'package:flutter/material.dart';

import '../../core/config.dart';
import 'job_links.dart';

/// Where the Jobs, Career and Hiring screens hand over to the rest of the app:
/// a company's page (the marketplace builder's), a conversation (messaging's)
/// and a member's profile. The lead wires the callbacks in `lib/app.dart`;
/// until a callback is given, each falls back to the same page on the website,
/// so a tap is never dead.
class JobsNavigation {
  const JobsNavigation({
    this.onOpenCompany,
    this.onOpenConversation,
    this.onOpenProfile,
    this.onBell,
    this.onFindJobs,
    this.onEditProfile,
    this.onCreateCompany,
    this.onVerifyCompany,
    this.onDemonstrateSkills,
  });

  /// Nothing wired: every hand-over opens the website.
  static const none = JobsNavigation();

  /// A company's page, by its id.
  final ValueChanged<String>? onOpenCompany;

  /// A conversation's thread, by its id.
  final ValueChanged<String>? onOpenConversation;

  /// A member's profile, by their user id.
  final ValueChanged<String>? onOpenProfile;

  /// The bell in every title bar: the app's notifications.
  final VoidCallback? onBell;

  /// The Jobs tab, with a search typed in (null: just the tab): "Find similar jobs", "Find jobs".
  final ValueChanged<String?>? onFindJobs;

  /// The member's own profile, to edit their résumé and career history.
  final VoidCallback? onEditProfile;

  /// "Create a company" (the account builder's screen): a member who is not on a hiring team posts jobs
  /// from a company page they found.
  final VoidCallback? onCreateCompany;

  /// The company's verification (its KYC check, the account builder's screen): a posting cannot go live
  /// until the company is verified.
  final VoidCallback? onVerifyCompany;

  /// "Demonstrate skills" on the board: the Learning area's assessments.
  final VoidCallback? onDemonstrateSkills;

  /// The skills assessments: the app's, else `/learning/assessment` on the website.
  Future<void> demonstrateSkills(BuildContext context, JobLinks links) async {
    final open = onDemonstrateSkills;
    if (open != null) {
      open();
      return;
    }
    await links.openSite(context, '/learning/assessment');
  }

  /// Verifying the company: the app's screen, else `/company?tab=verification` on the website.
  Future<void> verifyCompany(BuildContext context, JobLinks links) async {
    final open = onVerifyCompany;
    if (open != null) {
      open();
      return;
    }
    await links.openSite(context, '/company?tab=verification');
  }

  /// Founding a company: the app's screen, else `/account/companies/new` on the website.
  Future<void> createCompany(BuildContext context, JobLinks links) async {
    final open = onCreateCompany;
    if (open != null) {
      open();
      return;
    }
    await links.openSite(context, '/account/companies/new');
  }

  /// The member's profile editor: the app's, else `/profile` on the website.
  Future<void> editProfile(BuildContext context, JobLinks links) async {
    final open = onEditProfile;
    if (open != null) {
      open();
      return;
    }
    await links.openSite(context, '/profile');
  }

  /// The job board: the app's Jobs tab, else `/jobs` (with `?q=`) on the website.
  Future<void> findJobs(BuildContext context, JobLinks links, {String? query}) async {
    final open = onFindJobs;
    if (open != null) {
      open(query);
      return;
    }
    final q = query == null || query.trim().isEmpty ? '' : '?q=${Uri.encodeQueryComponent(query.trim())}';
    await links.openSite(context, '/jobs$q');
  }

  /// The notifications: the app's, else `/notifications` on the website.
  Future<void> openNotifications(BuildContext context, JobLinks links) async {
    final open = onBell;
    if (open != null) {
      open();
      return;
    }
    await links.openSite(context, '/notifications');
  }

  /// The company's page: the app's, else `/companies/:id` on the website.
  Future<void> openCompany(BuildContext context, JobLinks links, String companyId, {String? tab}) async {
    final open = onOpenCompany;
    if (open != null) {
      open(companyId);
      return;
    }
    final query = tab == null ? '' : '?tab=$tab';
    await links.openSite(context, '/companies/${Uri.encodeComponent(companyId)}$query');
  }

  /// The thread: the app's, else `/messaging?c=<id>` on the website.
  Future<void> openConversation(BuildContext context, JobLinks links, String? conversationId) async {
    final open = onOpenConversation;
    if (open != null && conversationId != null) {
      open(conversationId);
      return;
    }
    await links.openUri(context, conversationLink(conversationId));
  }

  /// The member's profile: the app's, else `/members/:id` on the website.
  Future<void> openProfile(BuildContext context, JobLinks links, String userId) async {
    final open = onOpenProfile;
    if (open != null) {
      open(userId);
      return;
    }
    await links.openSite(context, '/members/${Uri.encodeComponent(userId)}');
  }

  /// The website's thread for [conversationId] (the inbox when there is none).
  static Uri conversationLink(String? conversationId) => AppConfig.sitePage(
    conversationId == null ? '/messaging' : '/messaging?c=${Uri.encodeQueryComponent(conversationId)}',
  );
}

/// Hands a [JobsNavigation] down a screen, so a sheet opened from anywhere in
/// it (a job, My jobs, an applicant) takes the same hand-overs with it.
class JobsNavigationScope extends InheritedWidget {
  const JobsNavigationScope({super.key, required this.navigation, required super.child});

  final JobsNavigation navigation;

  /// The nearest scope's, else [JobsNavigation.none] (the website).
  static JobsNavigation of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<JobsNavigationScope>()?.navigation ?? JobsNavigation.none;

  @override
  bool updateShouldNotify(JobsNavigationScope oldWidget) => navigation != oldWidget.navigation;
}
