import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/widgets/title_bar.dart';
import 'notification_router.dart';
import 'notifications_screen.dart';
import 'unread_counts.dart';

/// Everything a title bar needs for its bell, so each screen wires it in one line:
///
///     TitleBar(title: 'Jobs', unread: bellUnread(context), onBell: () => openNotifications(context))
///
/// [bellUnread] listens to the app-wide [UnreadCounts] (0 when none is provided
/// above, so a screen in a test or a demo needs nothing). A screen that draws
/// its own bell can use [NotificationsBell], the same 36 dp bell with the red
/// dot, which opens the notifications screen.
int bellUnread(BuildContext context) => Provider.of<UnreadCounts?>(context)?.notifications ?? 0;

/// The unread messages, for a Messages entry's badge (see [UnreadCounts.messages]).
int messagesUnread(BuildContext context) => Provider.of<UnreadCounts?>(context)?.messages ?? 0;

class NotificationsBell extends StatelessWidget {
  const NotificationsBell({super.key, this.onTap});

  /// Replaces opening the notifications screen.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) =>
      BellButton(unread: bellUnread(context), onTap: onTap ?? () => openNotifications(context));
}

/// Provides what the bell and the Messages screens read, once, above the
/// signed-in app: the app-wide [UnreadCounts] (started, stopped with the
/// person's session) and the [NotificationRouter] that opens a notification's
/// record. Put it just above the shell:
///
///     InboxHost(
///       api: context.read<ApiClient>(),
///       router: NotificationRouter(openers: {NotificationKinds.job: (ctx, t) { …; return true; }}),
///       child: AppShell(…),
///     )
class InboxHost extends StatefulWidget {
  const InboxHost({super.key, required this.api, required this.child, this.router, this.counts});

  final ApiClient api;
  final NotificationRouter? router;

  /// Replaces the counts the host would make (tests).
  final UnreadCounts? counts;
  final Widget child;

  @override
  State<InboxHost> createState() => _InboxHostState();
}

class _InboxHostState extends State<InboxHost> {
  late final UnreadCounts _counts;
  late final bool _owns;
  late final NotificationRouter _router;

  @override
  void initState() {
    super.initState();
    _owns = widget.counts == null;
    _counts = widget.counts ?? UnreadCounts.api(widget.api);
    _router = widget.router ?? NotificationRouter();
    NotificationRouter.current = _router;
    if (_owns) _counts.start();
  }

  @override
  void dispose() {
    if (identical(NotificationRouter.current, _router)) NotificationRouter.current = null;
    if (_owns) _counts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider<UnreadCounts>.value(value: _counts),
      Provider<NotificationRouter>.value(value: _router),
    ],
    child: widget.child,
  );
}
