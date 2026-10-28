import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../messaging/messaging_repository.dart';
import 'notification_router.dart';
import 'notifications_repository.dart';
import 'unread_counts.dart';

/// What the notifications and messages screens read from above them: the
/// app-wide [UnreadCounts] and [NotificationRouter], and (for tests and the
/// demo) the repositories.
///
/// A route pushed on the app's navigator is not below the providers of the
/// screen that pushed it, so whoever pushes one of these screens captures the
/// scope from its own context and lays it over the new route. That way the
/// counts and the registered openers reach the pushed screens wherever the
/// app provided them.
class NotificationScope {
  NotificationScope._(this.unread, this.router, this.messaging, this.notifications);

  factory NotificationScope.of(BuildContext context) => NotificationScope._(
    Provider.of<UnreadCounts?>(context, listen: false),
    Provider.of<NotificationRouter?>(context, listen: false),
    Provider.of<MessagingRepository?>(context, listen: false),
    Provider.of<NotificationsRepository?>(context, listen: false),
  );

  final UnreadCounts? unread;
  final NotificationRouter? router;
  final MessagingRepository? messaging;
  final NotificationsRepository? notifications;

  Widget wrap(Widget child) {
    var w = child;
    if (notifications != null) w = Provider<NotificationsRepository>.value(value: notifications!, child: w);
    if (messaging != null) w = Provider<MessagingRepository>.value(value: messaging!, child: w);
    if (router != null) w = Provider<NotificationRouter>.value(value: router!, child: w);
    if (unread != null) w = ChangeNotifierProvider<UnreadCounts>.value(value: unread!, child: w);
    return w;
  }

  /// A route for [child] that carries this scope.
  Route<T> route<T>(Widget child) => MaterialPageRoute<T>(builder: (_) => wrap(child));
}
