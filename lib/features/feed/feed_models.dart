/// What the Home feed draws. The live source fills it from the forum API
/// (`ForumThreadCardDto`); the demo source holds the design's sample content.
library;

/// A picture is either bundled (demo) or a URL (live).
class FeedPicture {
  const FeedPicture.asset(String this.asset) : url = null;
  const FeedPicture.network(String this.url) : asset = null;

  final String? asset;
  final String? url;
}

class FeedAuthor {
  const FeedAuthor({required this.id, required this.name, this.headline, this.photo});

  final String id;
  final String name;
  final String? headline;
  final FeedPicture? photo;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return '$first$last'.toUpperCase();
  }
}

/// The forum's reaction kinds (`ForumReaction`).
enum ReactionKind { like, insightful, celebrate, support, sustainable }

ReactionKind? reactionKindFromApi(String? value) => switch (value) {
  'LIKE' => ReactionKind.like,
  'INSIGHTFUL' => ReactionKind.insightful,
  'CELEBRATE' => ReactionKind.celebrate,
  'SUPPORT' => ReactionKind.support,
  'SUSTAINABLE' => ReactionKind.sustainable,
  _ => null,
};

/// How the topic tag beside the time is tinted in the design.
enum TopicTone { green, blue }

/// What a discussion is (`ForumThreadKind`): only a question can have an accepted answer, and only a question
/// counts as unanswered.
enum ThreadKind { discussion, question, announcement }

ThreadKind threadKindFromApi(String? value) => switch (value) {
  'QUESTION' => ThreadKind.question,
  'ANNOUNCEMENT' => ThreadKind.announcement,
  _ => ThreadKind.discussion,
};

String reactionKindToApi(ReactionKind kind) => switch (kind) {
  ReactionKind.like => 'LIKE',
  ReactionKind.insightful => 'INSIGHTFUL',
  ReactionKind.celebrate => 'CELEBRATE',
  ReactionKind.support => 'SUPPORT',
  ReactionKind.sustainable => 'SUSTAINABLE',
};

/// The forum's words for each reaction (`FORUM_REACTION_META`), in the picker's order.
const reactionLabels = {
  ReactionKind.like: 'Like',
  ReactionKind.celebrate: 'Celebrate',
  ReactionKind.support: 'Support',
  ReactionKind.insightful: 'Insightful',
  ReactionKind.sustainable: 'Sustainable',
};

class FeedReply {
  const FeedReply({
    required this.id,
    required this.author,
    required this.body,
    required this.createdAt,
    this.meta,
    this.role,
    this.likes = 0,
    this.liked = false,
    this.children = const [],
    this.parentId,
    this.canEdit = false,
    this.accepted = false,
    this.pending = false,
    this.attachmentName,
    this.attachmentUrl,
    this.edited = false,
    this.bodyHtml,
  });

  final String id;
  final FeedAuthor author;
  final String body;
  final DateTime createdAt;

  /// The organisation or headline after the time ("Brookfield Properties").
  final String? meta;

  /// The author's role, drawn in the pill beside the name ("VP Sustainability"): the part of the headline before
  /// "at", "@" or "·". Null when the headline names no organisation (it is then the [meta] line whole).
  final String? role;
  final int likes;
  final bool liked;
  final List<FeedReply> children;

  /// The reply this one answers; null at the top of the thread.
  final String? parentId;

  /// The reader wrote it (or moderates): they may edit and delete it.
  final bool canEdit;

  /// The asker marked it as the answer.
  final bool accepted;

  /// Waiting for a moderator; only its author sees it.
  final bool pending;

  /// The one file a reply may carry (a photo or a document), by name and address.
  final String? attachmentName;
  final String? attachmentUrl;

  /// Its words were changed after it was posted. The forum keeps no edit time (a like moves `updatedAt` too), so
  /// only a reply edited in this session says so.
  final bool edited;

  /// The body as the forum stores it (sanitised HTML), which an edit starts from; null for sample content.
  final String? bodyHtml;

  FeedReply copyWith({
    int? likes,
    bool? liked,
    String? body,
    String? bodyHtml,
    List<FeedReply>? children,
    bool? accepted,
    bool? edited,
  }) => FeedReply(
    id: id,
    author: author,
    body: body ?? this.body,
    createdAt: createdAt,
    meta: meta,
    role: role,
    likes: likes ?? this.likes,
    liked: liked ?? this.liked,
    children: children ?? this.children,
    parentId: parentId,
    canEdit: canEdit,
    accepted: accepted ?? this.accepted,
    pending: pending,
    attachmentName: attachmentName,
    attachmentUrl: attachmentUrl,
    edited: edited ?? this.edited,
    bodyHtml: bodyHtml ?? this.bodyHtml,
  );

  /// This reply and every answer under it, in tree order.
  Iterable<FeedReply> get descendants sync* {
    for (final c in children) {
      yield c;
      yield* c.descendants;
    }
  }
}

/// Every reply of a thread in tree order.
List<FeedReply> flattenReplies(List<FeedReply> replies) => [
  for (final r in replies) ...[r, ...r.descendants],
];

/// The tree with one reply changed by [change] (found at any depth); the rest kept as they are.
List<FeedReply> mapReplies(List<FeedReply> replies, String id, FeedReply Function(FeedReply) change) => [
  for (final r in replies)
    if (r.id == id)
      change(r)
    else if (r.children.isEmpty)
      r
    else
      r.copyWith(children: mapReplies(r.children, id, change)),
];

/// The tree without one reply (and the answers under it).
List<FeedReply> removeReply(List<FeedReply> replies, String id) => [
  for (final r in replies)
    if (r.id != id) r.children.isEmpty ? r : r.copyWith(children: removeReply(r.children, id)),
];

class FeedPollOption {
  const FeedPollOption({required this.id, required this.label, required this.votes});

  final String id;
  final String label;
  final int votes;
}

class FeedPoll {
  const FeedPoll({
    required this.id,
    required this.options,
    required this.totalVotes,
    this.myOptionId,
    this.open = true,
    this.timeLeft,
  });

  final String id;
  final List<FeedPollOption> options;
  final int totalVotes;
  final String? myOptionId;
  final bool open;

  /// "2 days left". The API has no closing date, so live polls leave it out.
  final String? timeLeft;

  /// Whole-number shares that add up to 100 (largest remainder).
  List<int> get percents {
    if (totalVotes <= 0) return List.filled(options.length, 0);
    final raw = options.map((o) => o.votes * 100 / totalVotes).toList();
    final floors = raw.map((r) => r.floor()).toList();
    var left = 100 - floors.fold<int>(0, (a, b) => a + b);
    final order = List.generate(raw.length, (i) => i)
      ..sort((a, b) => (raw[b] - floors[b]).compareTo(raw[a] - floors[a]));
    for (final i in order) {
      if (left <= 0) break;
      floors[i]++;
      left--;
    }
    return floors;
  }
}

/// What reading a discussion adds to its card: the whole text and its photos. The forum's list carries a
/// 220-character excerpt and no photos, so the live feed reads the discussion itself (`GET /forum/threads/:slug`)
/// for each card that comes on screen.
class FeedPostDetail {
  const FeedPostDetail({required this.body, this.images = const [], this.caption, this.morePhotos = 0});

  /// The body as plain text, paragraphs on their own lines.
  final String body;

  /// The first two photos, drawn as the design draws them.
  final List<FeedPicture> images;

  /// The photo's caption, when there is one photo and its file name reads as words.
  final String? caption;

  /// Photos beyond the two drawn ("+3 photos").
  final int morePhotos;
}

class FeedPost {
  const FeedPost({
    required this.id,
    required this.slug,
    required this.author,
    required this.createdAt,
    required this.title,
    required this.body,
    this.topic,
    this.topicTone = TopicTone.green,
    this.tags = const [],
    this.images = const [],
    this.imageCaption,
    this.morePhotos = 0,
    this.reactions = 0,
    this.reactionKinds = const [],
    this.reactionCounts = const {},
    this.myReaction,
    this.comments = 0,
    this.shares,
    this.views,
    this.saved = false,
    this.showFollow = false,
    this.poll,
    this.replies = const [],
    this.repliesLoaded = false,
    this.moreRepliesOverride,
    this.replyTo,
    this.detailLoaded = false,
    this.kind = ThreadKind.discussion,
    this.locked = false,
    this.pinned = false,
    this.answered = false,
    this.categoryKey,
    this.subcategoryKey,
  });

  final String id;
  final String slug;

  /// The taxonomy keys the discussion is filed under (`category.key`, `subcategory.key`): what a repost is filed
  /// under. Null for a post the API did not describe (the demo's).
  final String? categoryKey;
  final String? subcategoryKey;
  final FeedAuthor author;
  final DateTime createdAt;
  final String title;
  final String body;

  /// The post's category as the forum names it ("Sustainability", "Poll"), written beside the time.
  final String? topic;
  final TopicTone topicTone;
  final List<String> tags;
  final List<FeedPicture> images;
  final String? imageCaption;

  /// Photos beyond the two shown ("+3 photos").
  final int morePhotos;
  final int reactions;

  /// The kinds drawn in the reaction stack, most used first (up to three).
  final List<ReactionKind> reactionKinds;

  /// How many members reacted with each kind (`ForumThreadCardDto.reactions`), which the stack above is made from.
  final Map<ReactionKind, int> reactionCounts;
  final ReactionKind? myReaction;
  final int comments;

  /// The API counts no shares, so live posts leave this null.
  final int? shares;

  /// How often the discussion was opened (`viewCount`). The live card prints it where the design prints shares.
  final int? views;
  final bool saved;
  final bool showFollow;
  final FeedPoll? poll;

  /// Replies shown under the post once its comments are open.
  final List<FeedReply> replies;
  final bool repliesLoaded;

  /// The design counts "+8 replies in this thread" by its own rule; live
  /// posts count every comment not shown.
  final int? moreRepliesOverride;

  /// Whose name the reply box addresses ("Reply to Priya Nambiar..."). Live posts leave it null: the box then
  /// addresses the newest reply in the thread (see [replyTargetFor]).
  final String? replyTo;

  /// True once the discussion's own page was read (its whole text and photos are on the card).
  final bool detailLoaded;

  final ThreadKind kind;

  /// Locked or archived: it takes no replies and its poll no votes.
  final bool locked;
  final bool pinned;

  /// A question whose asker marked an answer.
  final bool answered;

  static int _count(List<FeedReply> replies) => replies.fold(0, (n, r) => n + 1 + _count(r.children));

  /// "+N replies in this thread": the preview draws the first reply and its first answer (`forum-replies.png`),
  /// and the pill counts what that thread still holds out of sight, which is what the design counts. When the
  /// thread has nothing more, it counts every reply still out of sight, so the pill is always there to open the
  /// rest. The design's own sample sets it by hand.
  int get moreReplies {
    final override = moreRepliesOverride;
    if (override != null) return override;
    if (replies.isEmpty) return 0;
    final first = replies.first;
    final drawnAnswer = first.children.isEmpty ? 0 : 1;
    final inThread = _count(first.children) - drawnAnswer;
    if (inThread > 0) return inThread;
    final everyReply = _count(replies);
    return ((everyReply > comments ? everyReply : comments) - 1 - drawnAnswer).clamp(0, 1 << 30);
  }

  FeedPost copyWith({
    String? title,
    String? body,
    List<String>? tags,
    List<FeedPicture>? images,
    String? imageCaption,
    int? morePhotos,
    bool? detailLoaded,
    int? reactions,
    List<ReactionKind>? reactionKinds,
    Map<ReactionKind, int>? reactionCounts,
    ReactionKind? myReaction,
    bool clearMyReaction = false,
    int? comments,
    bool? saved,
    bool? showFollow,
    FeedPoll? poll,
    List<FeedReply>? replies,
    bool? repliesLoaded,
    bool? answered,
  }) => FeedPost(
    id: id,
    slug: slug,
    author: author,
    createdAt: createdAt,
    title: title ?? this.title,
    body: body ?? this.body,
    topic: topic,
    topicTone: topicTone,
    tags: tags ?? this.tags,
    images: images ?? this.images,
    imageCaption: imageCaption ?? this.imageCaption,
    morePhotos: morePhotos ?? this.morePhotos,
    reactions: reactions ?? this.reactions,
    reactionKinds: reactionKinds ?? this.reactionKinds,
    reactionCounts: reactionCounts ?? this.reactionCounts,
    myReaction: clearMyReaction ? null : (myReaction ?? this.myReaction),
    comments: comments ?? this.comments,
    shares: shares,
    views: views,
    saved: saved ?? this.saved,
    showFollow: showFollow ?? this.showFollow,
    poll: poll ?? this.poll,
    replies: replies ?? this.replies,
    repliesLoaded: repliesLoaded ?? this.repliesLoaded,
    moreRepliesOverride: moreRepliesOverride,
    replyTo: replyTo,
    detailLoaded: detailLoaded ?? this.detailLoaded,
    kind: kind,
    locked: locked,
    pinned: pinned,
    answered: answered ?? this.answered,
    categoryKey: categoryKey,
    subcategoryKey: subcategoryKey,
  );
}

/// The three kinds drawn in a reaction stack: the ones with the most reactions, most first (ties in the picker's
/// order).
List<ReactionKind> topReactionKinds(Map<ReactionKind, int> counts) {
  final order = reactionLabels.keys.toList();
  final kinds = counts.entries.where((e) => e.value > 0).map((e) => e.key).toList()
    ..sort((a, b) {
      final byCount = counts[b]!.compareTo(counts[a]!);
      return byCount != 0 ? byCount : order.indexOf(a).compareTo(order.indexOf(b));
    });
  return kinds.take(3).toList();
}

/// The reply a thread's box continues by default: the newest one that is not the reader's own. The design's
/// box reads "Reply to Priya Nambiar...", the person who spoke last; null when nobody else has replied.
FeedReply? replyTargetFor(List<FeedReply> replies, String viewerId) {
  FeedReply? best;
  void visit(List<FeedReply> list) {
    for (final r in list) {
      if (r.author.id != viewerId && (best == null || r.createdAt.isAfter(best!.createdAt))) best = r;
      visit(r.children);
    }
  }

  visit(replies);
  return best;
}

/// A paid or house placement drawn between posts.
class SponsoredCard {
  const SponsoredCard({
    required this.label,
    required this.title,
    required this.body,
    required this.cta,
    required this.link,
    required this.background,
  });

  final String label;
  final String title;
  final String body;
  final String cta;

  /// A path on the ICR website.
  final String link;
  final String background;
}

enum FeedFilter { all, trending, following, unanswered, polls }

extension FeedFilterLabel on FeedFilter {
  String get label => switch (this) {
    FeedFilter.all => 'All Feed',
    FeedFilter.trending => 'Trending',
    FeedFilter.following => 'Following',
    FeedFilter.unanswered => 'Unanswered',
    FeedFilter.polls => 'Polls',
  };
}

/// A topic chip after the filters ("#hvac"): a tag the discussions in the feed actually carry, never a fixed
/// list. [FeedController.topics] ranks them by how often they appear.
class FeedTopic {
  const FeedTopic(this.tag);

  /// The forum tag, without "#".
  final String tag;

  String get label => '#$tag';
}

class FeedPage {
  const FeedPage({required this.posts, required this.hasMore});

  final List<FeedPost> posts;
  final bool hasMore;
}
