import 'package:flutter/material.dart';

import '../../core/util/links.dart';
import '../feed/feed_models.dart';
import 'composer_controller.dart';
import 'forum_callbacks.dart';
import 'forum_models.dart';
import 'forum_repository.dart';
import 'new_thread_screen.dart';
import 'thread_screen.dart';

/// Starts a discussion: the composer, then, once the forum has it, the discussion's own page (or, when a moderator
/// must read it first, a line saying so). Returns what the forum stored, or null when the reader left the composer;
/// the caller shows the new card in its list.
Future<ForumThread?> startDiscussion(
  BuildContext context, {
  required ForumRepository repository,
  required FeedAuthor viewer,
  ForumCallbacks callbacks = const ForumCallbacks(),
  String? topicSlug,
  ComposerMode mode = ComposerMode.discussion,
  int unread = 0,
  String? initialTitle,
  String? initialBody,
}) async {
  final saved = await openComposer(
    context,
    repository: repository,
    topicSlug: topicSlug,
    mode: mode,
    initialTitle: initialTitle,
    initialBody: initialBody,
  );
  if (saved == null || !context.mounted) return saved;
  if (saved.moderation != 'APPROVED') {
    showMessage(context, 'Posted. A moderator will read it before it goes public.');
    return saved;
  }
  await openThreadPage(
    context,
    repository: repository,
    viewer: viewer,
    slug: saved.slug,
    preview: saved.card,
    unread: unread,
    callbacks: callbacks,
  );
  return saved;
}
