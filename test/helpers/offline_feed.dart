import 'package:icr_mobile/features/feed/feed_models.dart';
import 'package:icr_mobile/features/feed/feed_repository.dart';
import 'package:icr_mobile/features/forum/forum_repository.dart';

/// A feed source with its network pictures swapped for bundled ones: a widget test has no network (and no
/// platform cache) to fetch photos from. [assets] maps an upload's file name to a file under
/// `assets/images/demo/`; a picture whose name is not listed is dropped, so its avatar draws initials and its
/// photo is left out. Everything else, and every write, is the inner source's own.
class OfflineFeed implements FeedRepository {
  OfflineFeed(this.inner, {this.assets = const {}});

  final FeedRepository inner;
  final Map<String, String> assets;

  FeedPicture? _offline(FeedPicture? picture) {
    final url = picture?.url;
    if (url == null) return picture;
    final asset = assets[Uri.parse(url).pathSegments.last];
    return asset == null ? null : FeedPicture.asset('assets/images/demo/$asset');
  }

  FeedAuthor _author(FeedAuthor a) =>
      FeedAuthor(id: a.id, name: a.name, headline: a.headline, photo: _offline(a.photo));

  FeedPost _post(FeedPost p) => FeedPost(
    id: p.id,
    slug: p.slug,
    author: _author(p.author),
    createdAt: p.createdAt,
    title: p.title,
    body: p.body,
    topic: p.topic,
    topicTone: p.topicTone,
    tags: p.tags,
    images: [for (final i in p.images) ?_offline(i)],
    imageCaption: p.imageCaption,
    morePhotos: p.morePhotos,
    reactions: p.reactions,
    reactionKinds: p.reactionKinds,
    reactionCounts: p.reactionCounts,
    myReaction: p.myReaction,
    comments: p.comments,
    shares: p.shares,
    views: p.views,
    saved: p.saved,
    showFollow: p.showFollow,
    poll: p.poll,
    replies: p.replies,
    repliesLoaded: p.repliesLoaded,
    moreRepliesOverride: p.moreRepliesOverride,
    replyTo: p.replyTo,
    detailLoaded: p.detailLoaded,
    kind: p.kind,
    locked: p.locked,
    pinned: p.pinned,
    answered: p.answered,
    categoryKey: p.categoryKey,
    subcategoryKey: p.subcategoryKey,
  );

  FeedReply _reply(FeedReply r) => FeedReply(
    id: r.id,
    author: _author(r.author),
    body: r.body,
    createdAt: r.createdAt,
    meta: r.meta,
    role: r.role,
    likes: r.likes,
    liked: r.liked,
    children: r.children.map(_reply).toList(),
    parentId: r.parentId,
    canEdit: r.canEdit,
    accepted: r.accepted,
    pending: r.pending,
  );

  @override
  Future<FeedPage> load(FeedFilter filter, {int page = 1, String? search, String? tag}) async {
    final loaded = await inner.load(filter, page: page, search: search, tag: tag);
    return FeedPage(posts: loaded.posts.map(_post).toList(), hasMore: loaded.hasMore);
  }

  @override
  Future<FeedPostDetail?> detail(FeedPost post) async {
    final d = await inner.detail(post);
    return d == null
        ? null
        : FeedPostDetail(
            body: d.body,
            images: [for (final i in d.images) ?_offline(i)],
            caption: d.caption,
            morePhotos: d.morePhotos,
          );
  }

  @override
  Future<List<FeedReply>> replies(FeedPost post) async => (await inner.replies(post)).map(_reply).toList();

  @override
  SponsoredCard get sponsored => inner.sponsored;
  @override
  ForumRepository get forum => inner.forum;
  @override
  Set<String> get initiallyOpen => inner.initiallyOpen;
  @override
  bool get opensLeadThread => inner.opensLeadThread;
  @override
  Future<int> unreadNotifications() => inner.unreadNotifications();
  @override
  Future<void> setReaction(FeedPost post, ReactionKind? kind) => inner.setReaction(post, kind);
  @override
  Future<void> setSaved(FeedPost post, bool saved) => inner.setSaved(post, saved);
  @override
  Future<void> follow(FeedAuthor author) => inner.follow(author);
  @override
  Future<FeedPoll> vote(FeedPost post, String optionId) => inner.vote(post, optionId);
  @override
  Future<void> reply(FeedPost post, String text, {String? parentId}) => inner.reply(post, text, parentId: parentId);
  @override
  Future<void> deleteReply(FeedReply reply) => inner.deleteReply(reply);
  @override
  Future<void> setReplyLiked(FeedReply reply, bool like) => inner.setReplyLiked(reply, like);
  @override
  Uri link(FeedPost post, {FeedReply? reply}) => inner.link(post, reply: reply);
}
