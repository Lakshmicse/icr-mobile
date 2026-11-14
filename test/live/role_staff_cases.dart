/// The member screens a person can open in the app, each as the app builds it (`lib/app.dart`,
/// `lib/app_screens.dart`): one list the staff pass draws once per account.
library;

import 'package:flutter/material.dart';
import 'package:icr_mobile/app_screens.dart';
import 'package:icr_mobile/features/account/profile/my_profile_screen.dart';
import 'package:icr_mobile/features/account/settings/settings_screen.dart';
import 'package:icr_mobile/features/become_mentor/become_mentor_screen.dart';
import 'package:icr_mobile/features/career/career_routes.dart';
import 'package:icr_mobile/features/feed/feed_models.dart';
import 'package:icr_mobile/features/jobs/employer/hiring_routes.dart';
import 'package:icr_mobile/features/learning_hub/learning_doors.dart';
import 'package:icr_mobile/features/learning_hub/partner_courses_screen.dart';
import 'package:icr_mobile/features/mentor_desk/mentor_desk_screen.dart';
import 'package:icr_mobile/features/mentorship_my/group_sessions_screen.dart';
import 'package:icr_mobile/features/mentorship_my/my_mentoring_screen.dart';
import 'package:icr_mobile/features/mentorship_my/programmes_screen.dart';
import 'package:icr_mobile/features/messaging/inbox_screen.dart';
import 'package:icr_mobile/features/notifications/notifications_screen.dart';

/// Opens a pushed screen (the career hub, the employer's jobs) the moment it is first drawn.
class OpenOnDraw extends StatefulWidget {
  const OpenOnDraw(this.open, {super.key});

  final void Function(BuildContext context) open;

  @override
  State<OpenOnDraw> createState() => _OpenOnDrawState();
}

class _OpenOnDrawState extends State<OpenOnDraw> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.open(context));
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('opener'));
}

/// One screen and the words that show it drew: [probe] must be on screen once it settles.
class ScreenCase {
  const ScreenCase(this.name, this.build, this.probe);

  final String name;
  final Widget Function(BuildContext context) build;
  final String probe;
}

/// Every screen the staff pass opens directly.
List<ScreenCase> memberScreens() {
  final doors = inAppScreens(
    viewer: const FeedAuthor(id: 'staff', name: 'Staff'),
    demo: false,
  );
  const routes = LearningRoutes();
  return [
    ScreenCase('my profile', (c) => const MyProfileScreen(), 'Profile strength'),
    ScreenCase('settings', (c) => const SettingsScreen(), 'Sign-In & Security'),
    ScreenCase('notifications', (c) => const NotificationsScreen(), 'Notifications'),
    ScreenCase('messages', (c) => const InboxScreen(poll: false), 'Messages'),
    ScreenCase('the library', doors['/documents']!, 'Documents'),
    ScreenCase('chapters', doors['/chapters']!, 'Your Chapters'),
    ScreenCase('events', doors['/events']!, 'All Events'),
    ScreenCase('councils', doors['/councils']!, 'Your Joined Councils'),
    ScreenCase('get involved', doors['/get-involved']!, 'Volunteer Opportunities'),
    ScreenCase('saved items', doors['/career/saved']!, 'Saved Items'),
    ScreenCase('certificates', doors['/learning/certificates']!, 'My Certificates'),
    ScreenCase('my requirements', doors['/manage/requirements']!, "My RFQ's"),
    ScreenCase('post a requirement', doors['/rfq/new']!, 'Your details'),
    ScreenCase('found a company', doors['/account/companies/new?role=VENDOR']!, 'Company name *'),
    ScreenCase('my mentoring', (c) => const MyMentoringScreen(), 'My Mentoring'),
    ScreenCase('the mentor desk', (c) => const MentorDeskScreen(), 'Mentor Desk'),
    ScreenCase('become a mentor', (c) => const BecomeMentorScreen(), 'Become a Mentor'),
    ScreenCase('programmes', (c) => const ProgrammesScreen(), 'Programmes'),
    ScreenCase('group sessions', (c) => const GroupSessionsScreen(), 'Group Sessions'),
    ScreenCase('assess your knowledge', (c) => routes.assessment(c, () {}), 'Knowledge Assessments'),
    ScreenCase('mock exams', (c) => routes.mockTests(c, () {}), 'Mock Exams'),
    ScreenCase('flash cards', (c) => routes.flashCards(c, () {}), 'Flashcards'),
    ScreenCase('knowledge center', (c) => routes.knowledgeCenter(c, () {}), 'Knowledge Centre'),
    ScreenCase('my attempts', (c) => routes.myAttempts(c, () {}), 'My Assessment Attempts'),
    ScreenCase('partner courses', (c) => PartnerCoursesScreen(onBack: () {}), 'Partner Programmes'),
    ScreenCase('jobs you posted', (c) => OpenOnDraw((ctx) => hiringRoutesOf(ctx).jobs()), 'Jobs You Posted'),
    ScreenCase('post a job', (c) => OpenOnDraw((ctx) => hiringRoutesOf(ctx).postJob()), 'Post a Job'),
    ScreenCase('the career hub', (c) => OpenOnDraw((ctx) => careerRoutesOf(ctx).hub()), 'Your Career'),
  ];
}
