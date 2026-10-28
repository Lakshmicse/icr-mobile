import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_notifications.dart' show appJobsNavigation;
import 'app_screens.dart';
import 'core/api/api_client.dart';
import 'core/config.dart';
import 'core/util/links.dart' show showMessage;
import 'core/widgets/detail_sheet.dart';
import 'features/career/company_insights_controller.dart' show InsightsTab;
import 'features/career/company_insights_screen.dart' show openCompanyInsightsById;
import 'features/feed/feed_controller.dart';
import 'features/feed/feed_models.dart';
import 'features/forum/forum_callbacks.dart';
import 'features/forum/thread_screen.dart';
import 'features/jobs/job_detail_sheet.dart';
import 'features/jobs/jobs_controller.dart';
import 'features/learning/api_learning_repository.dart';
import 'features/learning/course_sheet.dart';
import 'features/learning/course_sheet_controller.dart';
import 'features/learning/demo_learning_repository.dart';
import 'features/learning/learning_models.dart';
import 'features/notifications/notification_router.dart';
import 'features/notifications/notifications_screen.dart' show openNotifications;
import 'features/rfq/rfq_navigation.dart';

/// Records the app opens from an id alone: a job, a discussion, a company, a course, a requirement. A notification
/// names one (`lib/app_notifications.dart`) and so does a link to the website (`inAppSiteRoute`, `lib/app_screens.dart`);
/// both open it the same way, here.
///
/// [shell] is a context below the signed-in app's providers (`JobsController`, `FeedController`…): a pushed route
/// (the notifications list, the search) sits above them, so an opener reads the providers from [shell] and pushes
/// over the context it was handed, [ctx].

/// Reads a record by its id, then opens its screen. A light spinner covers the wait; a record that cannot be read
/// (deleted, no longer the person's, offline) says so calmly and opens nothing.
Future<void> openRecord<T>(BuildContext ctx, Future<T> Function() load, FutureOr<void> Function(T value) open) async {
  final navigator = Navigator.of(ctx, rootNavigator: true);
  var covering = true;
  unawaited(
    showDialog<void>(
      context: ctx,
      barrierDismissible: false,
      useRootNavigator: true,
      // Never a dark frame while a record is read: a light veil over what the person was looking at.
      barrierColor: const Color(0xCCFFFFFF),
      builder: (_) => const PopScope(canPop: false, child: Center(child: CircularProgressIndicator())),
    ).whenComplete(() => covering = false),
  );
  T value;
  try {
    value = await load();
  } catch (_) {
    if (covering) navigator.pop();
    if (ctx.mounted) showMessage(ctx, NotificationRouter.unavailable);
    return;
  }
  if (covering) navigator.pop();
  if (!ctx.mounted) return;
  try {
    await open(value);
  } catch (_) {
    if (ctx.mounted) showMessage(ctx, NotificationRouter.unavailable);
  }
}

/// Runs an opener that reads its own record (a product page, a thread) and says so calmly when it cannot.
Future<void> quietly(BuildContext ctx, Future<void> Function() run) async {
  try {
    await run();
  } catch (_) {
    if (ctx.mounted) showMessage(ctx, NotificationRouter.unavailable);
  }
}

/// A requirement's page: the buyer's for one of their own, else the supplier's.
void openRfqRecord(BuildContext ctx, String id, {required bool owner, String? section, String? bidId}) {
  final hooks = appRfqHooks(ctx);
  if (owner) {
    pushRfqDetail(ctx, hooks, id, section: section, focusBid: bidId);
  } else {
    pushOpportunity(ctx, hooks, id, section: section);
  }
}

/// A course's sheet by its code (the learning list has no controller out here, so the sheet gets its own).
void openCourseByCode(BuildContext ctx, String code) {
  final repository = AppConfig.demo ? DemoLearningRepository() : ApiLearningRepository(api: ctx.read<ApiClient>());
  unawaited(
    openRecord<Course>(
      ctx,
      () async {
        final all = await repository.courses();
        return all.firstWhere((c) => c.code == code || c.slug == code);
      },
      (course) async {
        final controller = CourseSheetController(repository: repository, seed: course)..load();
        await showDetailSheet<void>(
          ctx,
          body: (_) => ChangeNotifierProvider.value(value: controller, child: const CourseSheetBody()),
          bottomBar: (_) => ChangeNotifierProvider.value(value: controller, child: const CourseSheetBar()),
        );
        controller.dispose();
      },
    ),
  );
}

/// A job's sheet by its id.
Future<void> openJobById(BuildContext shell, BuildContext ctx, String id) {
  final jobs = shell.read<JobsController>();
  final navigation = appJobsNavigation(shell);
  return openRecord(
    ctx,
    () => jobs.repository.detail(id),
    (job) => showJobDetail(
      ctx,
      job,
      repository: jobs.repository,
      links: jobs.links,
      navigation: navigation,
      onChanged: jobs.update,
      onApplied: jobs.applied,
      onHidden: jobs.hidden,
    ),
  );
}

/// A discussion's page by its slug (the website's `/community/<slug>`), scrolled to a reply when one is named.
Future<void> openThreadBySlug(BuildContext shell, BuildContext ctx, FeedAuthor viewer, String slug, {String? replyId}) {
  final feed = shell.read<FeedController>();
  return openThreadPage(
    ctx,
    repository: feed.repository.forum,
    viewer: viewer,
    slug: slug,
    focusReplyId: replyId,
    unread: feed.unread,
    callbacks: ForumCallbacks(onBell: () => openNotifications(ctx), onOpenMember: (id) => openMemberProfile(ctx, id)),
  );
}

/// A company's page (jobs, people, reviews, salaries, interviews) by its id.
Future<void> openCompanyById(BuildContext shell, String id, {InsightsTab tab = InsightsTab.jobs}) =>
    openCompanyInsightsById(shell, companyId: id, jobs: shell.read<JobsController>().repository, tab: tab);
