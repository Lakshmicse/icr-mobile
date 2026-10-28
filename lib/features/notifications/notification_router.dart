import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/util/links.dart';
import '../messaging/messaging_launcher.dart';
import 'notification_target.dart';
import 'notifications_screen.dart';

/// Opens a notification's record in one of the app's screens. Returns false to
/// pass (the next opener, or in the end the website, takes it).
typedef NotificationOpener = bool Function(BuildContext context, NotificationTarget target);

/// Opens a page of the website: the browser in the app, a recorder in tests.
typedef SiteOpener = Future<void> Function(BuildContext context, String path);

/// Where a notification (or any ICR link a message carries: a shared record,
/// a thread's context) opens.
///
/// The screens that own a record register an opener for its kind; the lead
/// does that once where the app is put together:
///
///     final router = NotificationRouter()
///       ..register(NotificationKinds.job, (ctx, t) { openJob(ctx, t['jobId']!); return true; })
///       ..register(NotificationKinds.event, (ctx, t) { … });
///     Provider<NotificationRouter>.value(value: router, child: …)
///
/// Conversations, the inbox and the notifications themselves open here
/// without registering. A staff-only kind (the admin consoles) opens nothing: the app has no console. Anything
/// else no opener takes opens the website's page IN THE APP (its web view), never the phone's browser.
class NotificationRouter {
  NotificationRouter({Map<String, NotificationOpener>? openers, SiteOpener? openSite, this.onCompanySwitched})
    : openSite = openSite ?? _openWebsite {
    if (openers != null) _openers.addAll(openers);
  }

  final Map<String, NotificationOpener> _openers = {};
  final SiteOpener openSite;

  /// Called after opening a row switched the person to another company (a new
  /// session): the app can reload what it holds for the old one.
  void Function(BuildContext context, String companyId)? onCompanySwitched;

  /// The kinds this feature opens itself.
  static const builtInKinds = {
    NotificationKinds.conversation,
    NotificationKinds.messaging,
    NotificationKinds.notifications,
  };

  /// The pages that exist only in ICR's staff consoles on the website. The app has none, so a tap on one of
  /// these notifications only reads it.
  static const staffKinds = {
    NotificationKinds.adminJobReview,
    NotificationKinds.adminVerificationSupplier,
    NotificationKinds.adminVerificationCompany,
    NotificationKinds.adminCompany,
    NotificationKinds.adminMentorshipConcern,
    NotificationKinds.adminLearning,
    NotificationKinds.adminForum,
    NotificationKinds.adminBlogs,
    NotificationKinds.adminDocumentReports,
    NotificationKinds.adminMessageReports,
    NotificationKinds.adminSupportTicket,
    NotificationKinds.adminSubscriptions,
    NotificationKinds.adminMarketing,
    NotificationKinds.adminContact,
  };

  /// What a person is told when a record cannot be opened (deleted, no longer theirs, offline).
  static const unavailable = 'This is no longer available.';

  void register(String kind, NotificationOpener opener) => _openers[kind] = opener;

  void registerAll(Map<String, NotificationOpener> openers) => _openers.addAll(openers);

  void unregister(String kind) => _openers.remove(kind);

  /// The kinds an opener was registered for.
  Iterable<String> get registeredKinds => _openers.keys;

  /// Whether [kind] has an opener (registered, or this feature's own).
  bool opens(String kind) => _openers.containsKey(kind) || builtInKinds.contains(kind);

  /// Opens in the app (a registered opener, else this feature's own), else the website's page in the app's
  /// web view. An opener that throws shows "This is no longer available." instead of an error page.
  Future<void> open(BuildContext context, NotificationTarget target) async {
    try {
      final opener = _openers[target.kind];
      if (opener != null && opener(context, target)) return;
      if (_builtIn(context, target)) return;
      if (staffKinds.contains(target.kind)) {
        showMessage(context, "That one is for ICR's staff tools, which aren't in the app.");
        return;
      }
      if (target.kind == NotificationKinds.none || target.href.isEmpty) return;
      await openSite(context, target.href);
    } catch (_) {
      if (context.mounted) showMessage(context, unavailable);
    }
  }

  Future<void> openHref(BuildContext context, String href) => open(context, NotificationTarget.parse(href));

  bool _builtIn(BuildContext context, NotificationTarget target) {
    switch (target.kind) {
      case NotificationKinds.conversation:
        final id = target['conversationId'];
        if (id == null) return false;
        final inbox = target['inbox'];
        MessagingLauncher.openConversation(
          context,
          id,
          asCompanyId: inbox == null || inbox == 'personal' ? null : inbox,
          focusMessageId: target['messageId'],
        );
        return true;
      case NotificationKinds.messaging:
        MessagingLauncher.openInbox(context, inbox: target['inbox']);
        return true;
      case NotificationKinds.notifications:
        openNotifications(context);
        return true;
    }
    return false;
  }

  /// The router of the signed-in app, set by `InboxHost` so a screen pushed outside its providers (the
  /// notifications list, a search, a pushed profile) still opens every record in the app.
  static NotificationRouter? current;

  /// The router the app provided, else the signed-in app's, else one that opens everything but this
  /// feature's own screens on the website.
  static NotificationRouter of(BuildContext context) =>
      Provider.of<NotificationRouter?>(context, listen: false) ?? current ?? _fallback;

  static final _fallback = NotificationRouter();

  static Future<void> _openWebsite(BuildContext context, String href) {
    final uri = Uri.tryParse(href);
    if (uri != null && uri.hasScheme) return openUrl(context, uri);
    return openSitePage(context, href.startsWith('/') ? href : '/$href');
  }
}
