import '../../core/api/api_error.dart';
import '../feed/feed_models.dart';
import '../feed/forum_json.dart';
import 'api_forum_repository.dart' show threadLink;
import 'demo_forum_content.dart';
import 'forum_models.dart';
import 'forum_repository.dart';

/// The designs' sample content as a forum that lives in memory (`--dart-define=FEED_SOURCE=demo`): reading works,
/// and every write changes this copy only, so the screens can be reviewed and clicked through without a database.
class DemoForumRepository implements ForumRepository {
  DemoForumRepository({DateTime? now}) : _content = DemoForumContent(now: now) {
    _posts = [..._content.designed, ..._content.more];
    _replies = {
      'implementing-iot-sensors-for-hvac-efficiency': _content.sarahReplies,
      'shortlisting-a-bms-retrofit-partner-for-a-12-site-campus-portfolio': [
        for (final r in _content.sarahReplies.skip(1)) r,
      ],
    };
  }

  final DemoForumContent _content;
  late List<FeedPost> _posts;
  late Map<String, List<FeedReply>> _replies;
  final _subscribed = <String>{};
  final _following = <String>{'marcus', 'elena'};
  var _sequence = 0;

  @override
  String? get viewerId => DemoForumContent.me.id;

  static const topicsList = [
    ForumTopic(id: 'esg', name: 'ESG & Sustainability', slug: 'esg-sustainability', threadCount: 2),
    ForumTopic(id: 'tech', name: 'Technology', slug: 'technology', threadCount: 3),
    ForumTopic(id: 'proc', name: 'Procurement & Supply Chain', slug: 'procurement-supply-chain', threadCount: 1),
  ];

  @override
  Future<ForumPage> threads(ForumQuery query, {int page = 1}) async {
    var posts = [..._posts];
    final q = query.search.trim().toLowerCase();
    if (q.isNotEmpty) {
      posts = posts.where((p) => '${p.title} ${p.body} ${p.tags.join(' ')}'.toLowerCase().contains(q)).toList();
    }
    if (query.tag != null) posts = posts.where((p) => p.tags.contains('#${query.tag}')).toList();
    if (query.kind == ForumKindFilter.questions) posts = posts.where((p) => p.kind == ThreadKind.question).toList();
    if (query.kind == ForumKindFilter.discussions) posts = posts.where((p) => p.kind != ThreadKind.question).toList();
    posts = switch (query.view) {
      ForumView.all => posts,
      ForumView.trending => [...posts]..sort((a, b) => b.reactions.compareTo(a.reactions)),
      ForumView.following => posts.where((p) => _following.contains(p.author.id)).toList(),
      ForumView.unanswered => posts.where((p) => p.kind == ThreadKind.question && p.comments == 0).toList(),
      ForumView.polls => posts.where((p) => p.poll != null).toList(),
      ForumView.saved => posts.where((p) => p.saved).toList(),
      ForumView.mine => posts.where((p) => p.author.id == viewerId).toList(),
    };
    return ForumPage(posts: page == 1 ? posts : const [], hasMore: false, total: posts.length);
  }

  @override
  Future<List<ForumTopic>> topics() async => topicsList;

  @override
  Future<List<TaxonomyNode>> taxonomy() async => const [
    TaxonomyNode(
      key: 'SUSTAINABILITY_ESG',
      name: 'ESG & Sustainability',
      slug: 'esg-sustainability',
      children: [
        TaxonomyNode(key: 'CARBON', name: 'Carbon & Net Zero', slug: 'carbon-net-zero'),
        TaxonomyNode(key: 'ESG_REPORTING', name: 'ESG Reporting', slug: 'esg-reporting'),
      ],
    ),
    TaxonomyNode(
      key: 'TECHNOLOGY_INNOVATION',
      name: 'Technology',
      slug: 'technology',
      children: [
        TaxonomyNode(key: 'BMS', name: 'Building Management Systems', slug: 'bms'),
        TaxonomyNode(key: 'IWMS', name: 'IWMS & CAFM', slug: 'iwms-cafm'),
      ],
    ),
    TaxonomyNode(key: 'PROCUREMENT_SUPPLY_CHAIN', name: 'Procurement & Supply Chain', slug: 'procurement-supply-chain'),
  ];

  @override
  Future<ForumAccess> access() async => const ForumAccess(reputation: 85, level: 'CONTRIBUTOR');

  @override
  Future<int> unreadNotifications() async => 3;

  FeedPost _find(String idOrSlug) => _posts.firstWhere(
    (p) => p.id == idOrSlug || p.slug == idOrSlug,
    orElse: () => throw ApiError('Discussion not found', statusCode: 404),
  );

  void _put(FeedPost post) => _posts = [for (final p in _posts) p.id == post.id ? post : p];

  @override
  Future<ForumThread> thread(String slug) async {
    final post = _find(slug);
    return ForumThread(
      card: post.copyWith(detailLoaded: true),
      bodyHtml: ForumJson.textToHtml(post.body.replaceAll('\n', ' ')),
      lastActivityAt: post.createdAt,
      category: const ForumTopicRef(id: 'esg', key: 'SUSTAINABILITY_ESG', name: 'ESG & Sustainability', slug: 'esg'),
      images: [...post.images],
      subscribed: _subscribed.contains(post.id),
      canEdit: post.author.id == viewerId,
      followsAuthor: _following.contains(post.author.id),
    );
  }

  @override
  Future<ForumReplyPage> replies(String slug, {int page = 1}) async {
    final post = _find(slug);
    final replies = page == 1 ? _replies[post.slug] ?? const <FeedReply>[] : const <FeedReply>[];
    return ForumReplyPage(replies: replies, total: post.comments, hasMore: false);
  }

  @override
  Future<void> recordView(String threadId) async {}

  @override
  Future<void> react(String threadId, ReactionKind? kind) async {
    final post = _find(threadId);
    if (post.author.id == viewerId) throw ApiError('You cannot vote on your own discussion.', statusCode: 400);
  }

  @override
  Future<void> setSaved(String threadId, bool saved) async => _put(_find(threadId).copyWith(saved: saved));

  @override
  Future<void> setSubscribed(String threadId, bool subscribed) async =>
      subscribed ? _subscribed.add(threadId) : _subscribed.remove(threadId);

  @override
  Future<void> setFollowing(String memberId, bool follow) async =>
      follow ? _following.add(memberId) : _following.remove(memberId);

  @override
  Future<bool> follows(String memberId) async => _following.contains(memberId);

  @override
  Future<FeedPoll> vote(String threadId, String optionId, {required bool open}) async {
    final poll = _find(threadId).poll!;
    final options = [
      for (final o in poll.options)
        FeedPollOption(
          id: o.id,
          label: o.label,
          votes: o.votes + (o.id == optionId ? 1 : 0) - (o.id == poll.myOptionId ? 1 : 0),
        ),
    ];
    return FeedPoll(
      id: poll.id,
      options: options,
      totalVotes: poll.totalVotes + (poll.myOptionId == null ? 1 : 0),
      myOptionId: optionId,
      timeLeft: poll.timeLeft,
      open: open,
    );
  }

  @override
  Future<List<ForumReactor>> reactors(String threadId) async => [
    ForumReactor(person: DemoForumContent.arvind, reaction: ReactionKind.insightful, at: _content.now),
    ForumReactor(person: DemoForumContent.priya, reaction: ReactionKind.like, at: _content.now),
    ForumReactor(person: DemoForumContent.vikram, reaction: ReactionKind.celebrate, at: _content.now),
  ];

  @override
  Future<ForumViewersPage> viewers(String threadId, {int page = 1}) async => ForumViewersPage(
    viewers: [
      ForumViewer(person: DemoForumContent.vikram, viewedAt: _content.now.subtract(const Duration(minutes: 20))),
      ForumViewer(person: DemoForumContent.priya, viewedAt: _content.now.subtract(const Duration(hours: 1))),
    ],
    total: 2,
    hidden: 3,
    hasMore: false,
  );

  @override
  Future<ForumThread> create(ForumDraft draft) async {
    final id = 'demo-${++_sequence}';
    final post = FeedPost(
      id: id,
      slug: id,
      author: DemoForumContent.me,
      createdAt: DateTime.now(),
      title: draft.title.trim(),
      body: (draft.body ?? '').trim(),
      tags: [for (final t in draft.tags) '#$t'],
      kind: draft.kind,
      detailLoaded: true,
      poll: draft.pollOptions == null
          ? null
          : FeedPoll(
              id: 'poll-$id',
              totalVotes: 0,
              options: [
                for (final (i, label) in draft.pollOptions!.indexed) FeedPollOption(id: 'o$i', label: label, votes: 0),
              ],
            ),
    );
    _posts = [post, ..._posts];
    return thread(id);
  }

  @override
  Future<ForumThread> update(String threadId, ForumDraft draft) async {
    final post = _find(threadId);
    _put(
      post.copyWith(
        title: draft.title.trim(),
        body: (draft.body ?? '').trim(),
        tags: [for (final t in draft.tags) '#$t'],
      ),
    );
    return thread(threadId);
  }

  @override
  Future<void> deleteThread(String threadId) async => _posts = [
    for (final p in _posts)
      if (p.id != threadId) p,
  ];

  @override
  Future<FeedReply> reply(String threadId, String text, {String? parentId}) async {
    final post = _find(threadId);
    final reply = FeedReply(
      id: 'demo-reply-${++_sequence}',
      author: DemoForumContent.me,
      body: text.trim(),
      createdAt: DateTime.now(),
      parentId: parentId,
      canEdit: true,
    );
    final list = _replies[post.slug] ?? const <FeedReply>[];
    _replies[post.slug] = parentId == null
        ? [...list, reply]
        : mapReplies(list, parentId, (r) => r.copyWith(children: [...r.children, reply]));
    _put(post.copyWith(comments: post.comments + 1));
    return reply;
  }

  @override
  Future<FeedReply> editReply(String replyId, String text) async {
    late FeedReply edited;
    _replies = {
      for (final e in _replies.entries)
        e.key: mapReplies(e.value, replyId, (r) => edited = r.copyWith(body: text.trim())),
    };
    return edited;
  }

  @override
  Future<void> deleteReply(String replyId) async {
    _replies = {for (final e in _replies.entries) e.key: removeReply(e.value, replyId)};
  }

  @override
  Future<void> setReplyLiked(String replyId, bool like) async {}

  @override
  Future<void> accept(String threadId, String replyId) async {}

  @override
  Future<void> report({String? threadId, String? replyId, required ReportReason reason, String? note}) async {}

  @override
  Future<ForumAttachment> upload(ForumFile file) async =>
      ForumAttachment(uploadId: 'demo-${file.name}', fileName: file.name, fileSize: file.bytes.length);

  @override
  Uri link(String slug, {String? replyId}) => threadLink(slug, replyId: replyId);
}
