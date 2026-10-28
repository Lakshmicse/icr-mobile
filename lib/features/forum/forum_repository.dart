import '../feed/feed_models.dart';
import 'forum_models.dart';

/// Where the Forums tab, a discussion's page and the composer read and write: the community forum
/// (`/forum/*` on the API), or the design's sample content.
abstract class ForumRepository {
  /// The signed-in reader, or null for a visitor.
  String? get viewerId;

  /// A page of discussions (`GET /forum/threads`).
  Future<ForumPage> threads(ForumQuery query, {int page = 1});

  /// The level-1 categories that hold a discussion (`GET /forum/categories`).
  Future<List<ForumTopic>> topics();

  /// Every category a discussion may be filed under, with its sub-categories (`GET /categories/tree`).
  Future<List<TaxonomyNode>> taxonomy();

  /// The reader's standing, and whether their next post waits for a moderator (`GET /forum/me`).
  Future<ForumAccess> access();

  Future<int> unreadNotifications();

  /// A discussion's own page (`GET /forum/threads/:slug`). The forum reads a discussion by its slug only.
  Future<ForumThread> thread(String slug);

  /// A page of its replies, nested (`GET /forum/threads/:slug/replies`).
  Future<ForumReplyPage> replies(String slug, {int page = 1});

  /// Counts a read (`POST /forum/threads/:id/view`), once per opening.
  Future<void> recordView(String threadId);

  /// Reacts with [kind], or takes the reader's reaction back when it is null.
  Future<void> react(String threadId, ReactionKind? kind);
  Future<void> setSaved(String threadId, bool saved);

  /// Follows the discussion (new replies reach the reader's notifications), or stops.
  Future<void> setSubscribed(String threadId, bool subscribed);

  /// Follows a member, or stops.
  Future<void> setFollowing(String memberId, bool follow);

  /// Whether the reader follows [memberId].
  Future<bool> follows(String memberId);
  Future<FeedPoll> vote(String threadId, String optionId, {required bool open});

  /// Who reacted to a discussion (`GET /forum/threads/:id/reactions`).
  Future<List<ForumReactor>> reactors(String threadId);

  /// Who read a discussion (`GET /forum/threads/:id/viewers`): everyone for its author, public profiles for the rest.
  Future<ForumViewersPage> viewers(String threadId, {int page = 1});

  Future<ForumThread> create(ForumDraft draft);
  Future<ForumThread> update(String threadId, ForumDraft draft);
  Future<void> deleteThread(String threadId);

  /// Sends a reply (under [parentId] when it answers one) and returns it as the forum stored it.
  Future<FeedReply> reply(String threadId, String text, {String? parentId});
  Future<FeedReply> editReply(String replyId, String text);
  Future<void> deleteReply(String replyId);
  Future<void> setReplyLiked(String replyId, bool like);

  /// Marks a reply as the answer to a question (`POST /forum/threads/:id/accept/:replyId`).
  Future<void> accept(String threadId, String replyId);

  /// Flags a discussion or a reply for the moderators (`POST /forum/reports`).
  Future<void> report({String? threadId, String? replyId, required ReportReason reason, String? note});

  /// Stores a file to attach (`POST /uploads`, purpose `forum-attachment`).
  Future<ForumAttachment> upload(ForumFile file);

  /// The discussion's page on the website, or one of its replies on that page.
  Uri link(String slug, {String? replyId});
}
