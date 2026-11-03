import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/auth/session_user.dart';
import '../../core/config.dart';
import 'demo_feed_repository.dart';
import 'feed_models.dart';

/// The signed-in person as the feed's screens draw them (header photo, reply box, "your own" tests).
FeedAuthor viewerOf(SessionUser? user) {
  if (AppConfig.demoFeed) return DemoFeedRepository.me;
  final url = AppConfig.absoluteUrl(user?.avatarUrl);
  return FeedAuthor(
    id: user?.id ?? 'me',
    name: user?.fullName ?? 'You',
    photo: url == null ? null : FeedPicture.network(url),
  );
}

/// Builds a tab with the signed-in person as they are NOW. The shell builds each tab's widget once and keeps it, so a
/// tab handed the person when the app opened would keep their old photo and name after they changed them on the
/// profile page; this watches the session and builds again whenever it is read anew (`AuthController.refreshUser`).
class SessionViewer extends StatelessWidget {
  const SessionViewer({super.key, required this.builder});

  final Widget Function(BuildContext context, FeedAuthor viewer) builder;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user;
    return builder(context, viewerOf(user));
  }
}
