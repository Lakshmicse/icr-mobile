import 'package:flutter/material.dart';

import '../become_mentor/become_mentor_screen.dart';
import '../mentorship_my/my_mentoring_controller.dart' show MyTab;
import '../mentorship_my/my_mentoring_screen.dart';
import '../mentorship_my/pairing_screen.dart';
import '../messaging/messaging_launcher.dart';
import '../notifications/notifications_screen.dart' show openNotifications;

/// Where a mentor's profile hands over to the rest of the app: the person's goals, their purchases, a pairing, a
/// conversation, the bell, the mentor application. Each opens the app's own screen unless a callback replaces it
/// (a test records them; the lead can wire others), so nothing here sends the person to the website.
class MentorProfileNavigation {
  const MentorProfileNavigation({
    this.onGoals,
    this.onPurchases,
    this.onPairing,
    this.onConversation,
    this.onNotifications,
    this.onEditMentorProfile,
  });

  /// "Tell Us Your Goals First": My mentoring on its Goals tab, where a mentee profile is made.
  final void Function(BuildContext context)? onGoals;

  /// A session or programme already asked for: My mentoring on its Purchases tab.
  final void Function(BuildContext context)? onPurchases;

  /// "Open Our Mentorship": the pairing's page, by its id.
  final void Function(BuildContext context, String mentorshipId)? onPairing;

  /// "Send Message" on a live pairing: the thread, by its id (null: the API gave none).
  final void Function(BuildContext context, String? conversationId)? onConversation;

  /// The bell.
  final void Function(BuildContext context)? onNotifications;

  /// "Edit My Profile" on the mentor's own page.
  final void Function(BuildContext context)? onEditMentorProfile;

  Future<void> goals(BuildContext context) async {
    final open = onGoals;
    if (open != null) return open(context);
    await openMyMentoring(context, tab: MyTab.goals);
  }

  Future<void> purchases(BuildContext context) async {
    final open = onPurchases;
    if (open != null) return open(context);
    await openMyMentoring(context, tab: MyTab.purchases);
  }

  Future<void> pairing(BuildContext context, String mentorshipId) async {
    final open = onPairing;
    if (open != null) return open(context, mentorshipId);
    await openPairing(context, mentorshipId);
  }

  Future<void> conversation(BuildContext context, String? conversationId) async {
    final open = onConversation;
    if (open != null) return open(context, conversationId);
    if (conversationId == null || conversationId.isEmpty) {
      await MessagingLauncher.openInbox(context);
    } else {
      await MessagingLauncher.openConversation(context, conversationId);
    }
  }

  Future<void> notifications(BuildContext context) async {
    final open = onNotifications;
    if (open != null) return open(context);
    await openNotifications(context);
  }

  Future<void> editMentorProfile(BuildContext context) async {
    final open = onEditMentorProfile;
    if (open != null) return open(context);
    await openBecomeMentor(context);
  }
}
