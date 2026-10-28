import 'package:flutter/foundation.dart';

import '../feed/feed_models.dart';
import 'forum_models.dart';

/// What the forum's screens ask the rest of the app to do. Every field is optional: a screen given none still
/// works, and a missing one either does the nearest true thing (the bell opens the website's notifications page)
/// or leaves the control inert (a member's name, until the app has a member page to open).
class ForumCallbacks {
  const ForumCallbacks({this.onOpenMember, this.onBell, this.onOpenTag, this.onOpenTopic});

  /// A member's photo or name was tapped: open their profile. Gets the member's id.
  final ValueChanged<String>? onOpenMember;

  /// The bell in a title bar.
  final VoidCallback? onBell;

  /// A tag on a discussion: show the discussions with it (without the "#").
  final ValueChanged<String>? onOpenTag;

  /// The topic a discussion is filed under: show that topic's discussions.
  final ValueChanged<ForumTopicRef>? onOpenTopic;
}

/// What a discussion's page hands back when it is left, so the list that opened it can show what the reader did
/// there (their reaction, their save, a new reply count, the poll vote) or drop it when they deleted it.
class ThreadResult {
  const ThreadResult({this.post, this.deleted = false});

  /// The discussion as the page last had it, null if it was never read.
  final FeedPost? post;
  final bool deleted;
}
