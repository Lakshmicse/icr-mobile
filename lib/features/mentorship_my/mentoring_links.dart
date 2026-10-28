import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api/api_error.dart';
import '../../core/util/links.dart';
import '../mentor_profile/mentor_profile_screen.dart';
import '../messaging/messaging_launcher.dart';
import '../notifications/notifications_screen.dart' as notifications_screen;
import 'mentoring_repository.dart';

/// Opens a page of the website: the browser by default, a recorder in tests.
typedef OpenSitePath = Future<void> Function(BuildContext context, String path);

/// Opens a conversation of the messaging feature by its id.
typedef OpenConversation = Future<void> Function(BuildContext context, String conversationId);

/// Opens a thread through a record of mentoring (a pairing, a bought session, a group session), by its id.
typedef OpenRecordThread = Future<void> Function(BuildContext context, String recordId);

/// Hands a downloaded file to the person: the share sheet by default (save it, or open it in another app).
typedef ShareFile = Future<void> Function(BuildContext context, String name, Uint8List bytes);

Future<void> shareBytes(BuildContext context, String name, Uint8List bytes) => SharePlus.instance.share(
  ShareParams(
    files: [XFile.fromData(bytes, name: name)],
    fileNameOverrides: [name],
  ),
);

/// What the mentoring screens open outside their own folders. The lead wires
/// these once, above the shell:
///
/// ```dart
/// Provider<MentorshipLinks>.value(
///   value: MentorshipLinks(
///     openConversation: MessagingLauncher.openConversation,
///     openDirectory: (context) => openFindMentors(context, ...),
///   ),
///   child: AppShell(...),
/// )
/// ```
///
/// or per screen through each public constructor's `links`, or its four named
/// callbacks (`onOpenConversation`, `onOpenMentor`, `onBell`, `onOpenWebsite`),
/// which [resolve] folds in. Every callback is optional: "Message" falls back to
/// opening the thread through the API and then the website's `/messaging?c=<id>`,
/// "Find a mentor" to going back, a mentor's name to the in-app profile.
class MentorshipLinks {
  const MentorshipLinks({
    this.openConversation,
    this.openPairingThread,
    this.openPurchaseThread,
    this.openGroupThread,
    this.openMentor,
    this.openDirectory,
    this.openNotifications,
    this.openSite = openSitePage,
    this.shareFile = shareBytes,
  });

  /// Opens a thread by its id (`MessagingLauncher.openConversation`).
  final OpenConversation? openConversation;

  /// "Message" on a pairing, by its id (`MessagingLauncher.forMentorship`). Preferred over [openConversation].
  final OpenRecordThread? openPairingThread;

  /// "Message" on a bought session, by the purchase id (`MessagingLauncher.forPurchase`).
  final OpenRecordThread? openPurchaseThread;

  /// "Message" on a group session, by its id (`MessagingLauncher.forGroupSession`).
  final OpenRecordThread? openGroupThread;

  /// Opens a mentor's profile by mentor profile id; the in-app profile by default.
  final void Function(BuildContext context, String mentorProfileId)? openMentor;

  /// "Find a mentor": the directory. Going back to wherever the member came from by default.
  final void Function(BuildContext context)? openDirectory;

  /// The bell; the website's `/notifications` by default.
  final void Function(BuildContext context)? openNotifications;
  final OpenSitePath openSite;
  final ShareFile shareFile;

  /// What the screens do when nobody gave them links: every "Message" opens the app's own conversation and the bell
  /// the app's notifications. A screen pushed over the shell by another feature (a mentor's profile opening My
  /// mentoring) sits above the shell's providers and finds none, and it must not fall back to the website.
  static const inApp = MentorshipLinks(
    openConversation: _openThread,
    openPairingThread: MessagingLauncher.forMentorship,
    openPurchaseThread: MessagingLauncher.forPurchase,
    openGroupThread: MessagingLauncher.forGroupSession,
    openNotifications: _openBell,
  );

  static void _openBell(BuildContext context) => notifications_screen.openNotifications(context);

  static Future<void> _openThread(BuildContext context, String conversationId) =>
      MessagingLauncher.openConversation(context, conversationId);

  /// [given], else the one provided above, else the in-app defaults.
  static MentorshipLinks of(BuildContext context, [MentorshipLinks? given]) {
    if (given != null) return given;
    try {
      return Provider.of<MentorshipLinks?>(context, listen: false) ?? inApp;
    } on ProviderNotFoundException {
      return inApp;
    }
  }

  /// The links a screen uses: [given] (or the provided ones) with the screen's own named callbacks laid over them.
  static MentorshipLinks resolve(
    BuildContext context,
    MentorshipLinks? given, {
    OpenConversation? onOpenConversation,
    void Function(BuildContext context, String mentorProfileId)? onOpenMentor,
    void Function(BuildContext context)? onBell,
    OpenSitePath? onOpenWebsite,
  }) {
    final base = of(context, given);
    if (onOpenConversation == null && onOpenMentor == null && onBell == null && onOpenWebsite == null) return base;
    return MentorshipLinks(
      openConversation: onOpenConversation ?? base.openConversation,
      openPairingThread: base.openPairingThread,
      openPurchaseThread: base.openPurchaseThread,
      openGroupThread: base.openGroupThread,
      openMentor: onOpenMentor ?? base.openMentor,
      openDirectory: base.openDirectory,
      openNotifications: onBell ?? base.openNotifications,
      openSite: onOpenWebsite ?? base.openSite,
      shareFile: base.shareFile,
    );
  }

  /// Opens the thread [conversationId]; says so when the API gave none.
  Future<void> conversation(BuildContext context, String? conversationId) async {
    if (conversationId == null || conversationId.isEmpty) {
      showMessage(context, "Couldn't open the conversation. Try again.");
      return;
    }
    if (openConversation != null) return openConversation!(context, conversationId);
    return openSite(context, '/messaging?c=$conversationId');
  }

  /// "Message" on a pairing: through the record when wired, else the API opens the thread.
  Future<void> messagePairing(BuildContext context, MentoringRepository repository, String mentorshipId) =>
      _viaRecord(context, openPairingThread, mentorshipId, () => repository.pairingConversation(mentorshipId));

  /// "Message" on a bought session.
  Future<void> messagePurchase(BuildContext context, MentoringRepository repository, String purchaseId) =>
      _viaRecord(context, openPurchaseThread, purchaseId, () => repository.purchaseConversation(purchaseId));

  /// "Message" on a group session (the room's thread).
  Future<void> messageGroup(BuildContext context, MentoringRepository repository, String sessionId) =>
      _viaRecord(context, openGroupThread, sessionId, () => repository.groupConversation(sessionId));

  Future<void> _viaRecord(
    BuildContext context,
    OpenRecordThread? direct,
    String recordId,
    Future<String?> Function() open,
  ) async {
    if (direct != null) return direct(context, recordId);
    try {
      final id = await open();
      if (context.mounted) await conversation(context, id);
    } catch (e) {
      if (context.mounted) showMessage(context, ApiError.from(e).message);
    }
  }

  void mentor(BuildContext context, String mentorProfileId) {
    if (openMentor != null) return openMentor!(context, mentorProfileId);
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (route) => mentorProfileRoute(route, mentorProfileId)));
  }

  void directory(BuildContext context) {
    if (openDirectory != null) return openDirectory!(context);
    Navigator.of(context).maybePop();
  }

  void notifications(BuildContext context) {
    if (openNotifications != null) return openNotifications!(context);
    openSite(context, '/notifications');
  }

  /// Downloads a private file with the session's token and hands it to the share sheet. Says why when it cannot.
  Future<void> download(BuildContext context, Future<Uint8List> Function() fetch, String name) async {
    try {
      final bytes = await fetch();
      if (!context.mounted) return;
      await shareFile(context, name, bytes);
    } catch (e) {
      if (context.mounted) showMessage(context, ApiError.from(e).message);
    }
  }
}
