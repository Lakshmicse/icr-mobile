/// What the Forums tab, a discussion's page and the composer draw. A discussion's card is the Home feed's
/// [FeedPost] (the same card in both places); this file adds what only the page and the composer need.
library;

import '../feed/feed_models.dart';

/// A taxonomy node a discussion is filed under (`ForumThreadDto.category` / `.subcategory`).
class ForumTopicRef {
  const ForumTopicRef({required this.id, required this.key, required this.name, required this.slug});

  final String id;
  final String key;
  final String name;
  final String slug;
}

/// The one file a discussion (or a reply) carries: a photo or a document (`POST /uploads`, purpose
/// `forum-attachment`).
class ForumAttachment {
  const ForumAttachment({required this.uploadId, this.fileName, this.fileSize, this.url, this.asset});

  /// The stored file's name, which the API takes back as `uploadId`.
  final String uploadId;
  final String? fileName;
  final int? fileSize;

  /// Where it is served (`/uploads/<uploadId>` beside the API).
  final String? url;

  /// A bundled picture standing in for it (the demo content).
  final String? asset;

  bool get isPicture => RegExp(r'\.(jpe?g|png|webp|gif)$', caseSensitive: false).hasMatch(fileName ?? uploadId);

  /// "Site photo.jpg · 76 KB".
  String get label {
    final name = fileName ?? uploadId;
    final size = fileSize;
    if (size == null || size <= 0) return name;
    final kb = size / 1024;
    final text = kb >= 1024 ? '${(kb / 1024).toStringAsFixed(1)} MB' : '${kb.round()} KB';
    return '$name · $text';
  }
}

/// A discussion as its own page has it (`ForumThreadDto`): the card, the whole body, and what the reader may do.
class ForumThread {
  const ForumThread({
    required this.card,
    required this.bodyHtml,
    required this.lastActivityAt,
    this.category,
    this.subcategory,
    this.attachment,
    this.images = const [],
    this.subscribed = false,
    this.canEdit = false,
    this.canModerate = false,
    this.acceptedReplyId,
    this.pending = false,
    this.followsAuthor = false,
    this.status = 'OPEN',
    this.moderation = 'APPROVED',
  });

  /// The discussion as a card: author, title, tags, reactions, poll, saved...
  final FeedPost card;

  /// The body as the forum stores it (sanitised HTML).
  final String bodyHtml;
  final DateTime lastActivityAt;
  final ForumTopicRef? category;
  final ForumTopicRef? subcategory;
  final ForumAttachment? attachment;

  /// Every photo: the attachment when it is one, then the images in the body.
  final List<FeedPicture> images;

  /// The reader follows the discussion (hears about new replies).
  final bool subscribed;

  /// The reader wrote it (or moderates): they may edit and delete it.
  final bool canEdit;
  final bool canModerate;
  final String? acceptedReplyId;

  /// Waiting for a moderator; only its author (and moderators) see it.
  final bool pending;

  /// The reader follows its author.
  final bool followsAuthor;

  /// `OPEN`, `LOCKED` or `ARCHIVED` (`ForumThreadStatus`): only an open discussion takes replies and poll votes.
  final String status;

  /// `PENDING`, `APPROVED` or `REJECTED` (`ModerationStatus`).
  final String moderation;

  bool get open => status == 'OPEN';

  /// Whether the body carries formatting the app's plain-text editor would flatten (bold, links, lists...).
  bool get hasRichBody => RegExp(r'<(?!/?(?:p|br)\b)[a-z][^>]*>', caseSensitive: false).hasMatch(bodyHtml);

  String get id => card.id;
  String get slug => card.slug;

  ForumThread copyWith({
    FeedPost? card,
    bool? subscribed,
    bool? followsAuthor,
    String? acceptedReplyId,
    bool clearAccepted = false,
  }) => ForumThread(
    card: card ?? this.card,
    bodyHtml: bodyHtml,
    lastActivityAt: lastActivityAt,
    category: category,
    subcategory: subcategory,
    attachment: attachment,
    images: images,
    subscribed: subscribed ?? this.subscribed,
    canEdit: canEdit,
    canModerate: canModerate,
    acceptedReplyId: clearAccepted ? null : (acceptedReplyId ?? this.acceptedReplyId),
    pending: pending,
    followsAuthor: followsAuthor ?? this.followsAuthor,
    status: status,
    moderation: moderation,
  );
}

/// One page of a discussion's replies, as the forum nests them.
class ForumReplyPage {
  const ForumReplyPage({required this.replies, required this.total, required this.hasMore});

  final List<FeedReply> replies;

  /// Every reply the discussion has (the forum counts rows, not top-level branches).
  final int total;
  final bool hasMore;
}

/// A level-1 category on the Forums tab's topic row (`GET /forum/categories`): only categories that hold a
/// discussion are listed.
class ForumTopic {
  const ForumTopic({required this.id, required this.name, required this.slug, this.threadCount = 0, this.blurb});

  final String id;
  final String name;
  final String slug;
  final int threadCount;
  final String? blurb;
}

/// A taxonomy category the composer offers (`GET /categories/tree?kind=SERVICE&depth=2`): every level-1 node and
/// its level-2 children, so a first discussion can land anywhere.
class TaxonomyNode {
  const TaxonomyNode({required this.key, required this.name, required this.slug, this.children = const []});

  final String key;
  final String name;
  final String slug;
  final List<TaxonomyNode> children;
}

/// The reader's standing in the forum (`GET /forum/me`).
class ForumAccess {
  const ForumAccess({this.reputation = 0, this.level = 'NEW', this.requiresApproval = false, this.canModerate = false});

  final int reputation;
  final String level;

  /// The reader's next post waits for a moderator.
  final bool requiresApproval;
  final bool canModerate;

  /// The ladder's names (`FORUM_LEVELS`).
  String get levelLabel => switch (level) {
    'CONTRIBUTOR' => 'Contributor',
    'TRUSTED' => 'Trusted',
    'EXPERT' => 'Expert',
    'LEADER' => 'Community leader',
    _ => 'New member',
  };
}

/// What the Forums tab lists. The first five are the Home feed's chips; the website adds the reader's saves and
/// own discussions.
enum ForumView { all, trending, following, unanswered, polls, saved, mine }

extension ForumViewLabel on ForumView {
  String get label => switch (this) {
    ForumView.all => 'All Feed',
    ForumView.trending => 'Trending',
    ForumView.following => 'Following',
    ForumView.unanswered => 'Unanswered',
    ForumView.polls => 'Polls',
    ForumView.saved => 'Saved',
    ForumView.mine => 'My posts',
  };
}

/// The website's sorts (`FORUM_SORTS`). Trending is "top" and Unanswered is "unanswered"; the others choose
/// between the first three.
enum ForumSort { latest, newest, top, unanswered }

extension ForumSortLabel on ForumSort {
  String get label => switch (this) {
    ForumSort.latest => 'Recent activity',
    ForumSort.newest => 'Newest',
    ForumSort.top => 'Most upvoted',
    ForumSort.unanswered => 'Unanswered questions',
  };

  String get api => name;
}

/// A question or a discussion, for the list's type filter (`kind`).
enum ForumKindFilter { any, questions, discussions }

extension ForumKindFilterLabel on ForumKindFilter {
  String get label => switch (this) {
    ForumKindFilter.any => 'Any type',
    ForumKindFilter.questions => 'Questions',
    ForumKindFilter.discussions => 'Discussions',
  };

  String? get api => switch (this) {
    ForumKindFilter.any => null,
    ForumKindFilter.questions => 'QUESTION',
    ForumKindFilter.discussions => 'DISCUSSION',
  };
}

/// What the Forums tab asks the forum for (`GET /forum/threads`).
class ForumQuery {
  const ForumQuery({
    this.view = ForumView.all,
    this.sort = ForumSort.latest,
    this.search = '',
    this.tag,
    this.category,
    this.subcategory,
    this.kind = ForumKindFilter.any,
  });

  final ForumView view;

  /// The sort the reader chose; Trending and Unanswered have their own.
  final ForumSort sort;
  final String search;

  /// A forum tag, without "#".
  final String? tag;
  final ForumTopic? category;
  final TaxonomyNode? subcategory;
  final ForumKindFilter kind;

  ForumSort get effectiveSort => switch (view) {
    ForumView.trending => ForumSort.top,
    ForumView.unanswered => ForumSort.unanswered,
    _ => sort,
  };

  /// Whether the reader may choose a sort for this view.
  bool get sortable => view != ForumView.trending && view != ForumView.unanswered;

  /// Filters beyond the view chip: what the filter button counts.
  int get refinements =>
      (sortable && sort != ForumSort.latest ? 1 : 0) +
      (kind != ForumKindFilter.any ? 1 : 0) +
      (subcategory != null ? 1 : 0) +
      (tag != null ? 1 : 0);

  ForumQuery copyWith({
    ForumView? view,
    ForumSort? sort,
    String? search,
    String? tag,
    bool clearTag = false,
    ForumTopic? category,
    bool clearCategory = false,
    TaxonomyNode? subcategory,
    bool clearSubcategory = false,
    ForumKindFilter? kind,
  }) => ForumQuery(
    view: view ?? this.view,
    sort: sort ?? this.sort,
    search: search ?? this.search,
    tag: clearTag ? null : (tag ?? this.tag),
    category: clearCategory ? null : (category ?? this.category),
    subcategory: clearSubcategory || clearCategory ? null : (subcategory ?? this.subcategory),
    kind: kind ?? this.kind,
  );
}

/// A new discussion, or the changes to one (`CreateForumThreadDto` / `UpdateForumThreadDto`).
class ForumDraft {
  const ForumDraft({
    required this.categoryKey,
    required this.title,
    this.body,
    this.bodyHtml,
    this.subcategoryKey,
    this.kind = ThreadKind.discussion,
    this.tags = const [],
    this.attachment,
    this.pollOptions,
  });

  /// The taxonomy key of the topic; null on an edit that leaves the topic alone (the forum then re-checks nothing).
  final String? categoryKey;
  final String? subcategoryKey;
  final String title;

  /// What was typed, as plain words: sent as escaped paragraphs when there is no [bodyHtml]. Null on an edit
  /// leaves the stored body exactly as it is (a body the website's editor formatted is not flattened by an edit of
  /// the title or the tags).
  final String? body;

  /// The details as the forum's HTML (the composer's rich editor); sent as it is, in place of [body].
  final String? bodyHtml;
  final ThreadKind kind;
  final List<String> tags;
  final ForumAttachment? attachment;

  /// A poll's options; a new post only (a poll is fixed once posted).
  final List<String>? pollOptions;
}

/// The forum's limits (`MAX_FORUM_TAGS`, `FORUM_POLL_LIMITS`, the DTO's title length).
class ForumLimits {
  ForumLimits._();

  static const titleMin = 8;
  static const titleMax = 160;
  static const bodyMax = 20000;
  static const tags = 5;
  static const tagChars = 32;
  static const pollMin = 2;
  static const pollMax = 4;
  static const optionChars = 80;
  static const noteMax = 1000;
  static const replyMax = 20000;
}

/// Why a member flags a post (`ForumReportReason`, worded as `FORUM_REPORT_REASON_LABELS`).
enum ReportReason { spam, abuse, offTopic, selfPromotion, misinformation, other }

extension ReportReasonApi on ReportReason {
  String get api => switch (this) {
    ReportReason.spam => 'SPAM',
    ReportReason.abuse => 'ABUSE',
    ReportReason.offTopic => 'OFF_TOPIC',
    ReportReason.selfPromotion => 'SELF_PROMOTION',
    ReportReason.misinformation => 'MISINFORMATION',
    ReportReason.other => 'OTHER',
  };

  String get label => switch (this) {
    ReportReason.spam => 'Spam',
    ReportReason.abuse => 'Abuse or harassment',
    ReportReason.offTopic => 'Off topic',
    ReportReason.selfPromotion => 'Undisclosed self-promotion',
    ReportReason.misinformation => 'Misleading or incorrect',
    ReportReason.other => 'Something else',
  };
}

/// Someone who reacted (`GET /forum/threads/:id/reactions`).
class ForumReactor {
  const ForumReactor({required this.person, required this.reaction, required this.at});

  final FeedAuthor person;
  final ReactionKind reaction;
  final DateTime at;
}

/// Someone who read a discussion (`GET /forum/threads/:id/viewers`).
class ForumViewer {
  const ForumViewer({required this.person, required this.viewedAt});

  final FeedAuthor person;
  final DateTime viewedAt;
}

/// A page of "who viewed": the readers the reader may see, and how many others there were (`hidden`: readers whose
/// profile is not public, counted but not named).
class ForumViewersPage {
  const ForumViewersPage({required this.viewers, required this.total, required this.hidden, required this.hasMore});

  final List<ForumViewer> viewers;
  final int total;
  final int hidden;
  final bool hasMore;
}

/// A page of discussions for the Forums tab.
class ForumPage {
  const ForumPage({required this.posts, required this.hasMore, this.total});

  final List<FeedPost> posts;
  final bool hasMore;

  /// How many discussions match, when the forum counted them (not for the views it cannot filter).
  final int? total;
}

/// A file picked to attach: its bytes and name. The app hands the composer a picker (`NewThreadScreen.pickFile`).
class ForumFile {
  const ForumFile({required this.bytes, required this.name});

  final List<int> bytes;
  final String name;
}
