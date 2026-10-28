import '../../core/config.dart';
import '../forum/forum_repository.dart';
import 'feed_models.dart';

/// Where the Home feed comes from: the forum API, or the design's sample
/// content (`FEED_SOURCE=demo`).
abstract class FeedRepository {
  /// [tag] narrows to one forum tag (a topic chip), on top of [filter].
  Future<FeedPage> load(FeedFilter filter, {int page = 1, String? search, String? tag});

  /// The placement drawn after the second post.
  SponsoredCard get sponsored;

  /// The same forum, for a discussion's page, the composer and the Forums tab (as the same reader).
  ForumRepository get forum;

  /// Posts whose comments start open (the design shows the first one open).
  Set<String> get initiallyOpen => const {};

  /// Whether the first post's comments open by themselves when the feed first loads, as the design's do. The
  /// live feed does; a person closes them like any other.
  bool get opensLeadThread => false;

  Future<int> unreadNotifications();

  /// Reacts to a discussion with [kind], or clears the reader's reaction when it is null.
  Future<void> setReaction(FeedPost post, ReactionKind? kind);
  Future<void> setSaved(FeedPost post, bool saved);
  Future<void> follow(FeedAuthor author);
  Future<FeedPoll> vote(FeedPost post, String optionId);

  /// The discussion's whole text and photos, which its card in the list does not carry; null when the list's
  /// card already holds everything (the sample content).
  Future<FeedPostDetail?> detail(FeedPost post) async => null;

  Future<List<FeedReply>> replies(FeedPost post);
  Future<void> reply(FeedPost post, String text, {String? parentId});
  Future<void> deleteReply(FeedReply reply);
  Future<void> setReplyLiked(FeedReply reply, bool like);

  /// The post's page on the ICR website, or one of its replies on that page.
  Uri link(FeedPost post, {FeedReply? reply});
}

/// A discussion's page on the website: `/community/<slug>`, with the reply the website scrolls to
/// (`#reply-<id>`) when one is given.
Uri discussionLink(FeedPost post, [FeedReply? reply]) {
  final page = AppConfig.sitePage('/community/${post.slug}');
  return reply == null ? page : page.replace(fragment: 'reply-${reply.id}');
}
