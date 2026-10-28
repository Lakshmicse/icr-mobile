import '../forum/demo_forum_content.dart';
import '../forum/demo_forum_repository.dart';
import '../forum/forum_repository.dart';
import 'feed_models.dart';
import 'feed_repository.dart';

const _demo = 'assets/images/demo';

/// The Home design's sample content, word for word, for reviewing the screen
/// without a seeded database (`--dart-define=FEED_SOURCE=demo`). Actions
/// succeed locally and are not sent anywhere.
class DemoFeedRepository implements FeedRepository {
  DemoFeedRepository({DateTime? now}) : _now = now ?? DateTime.now();

  final DateTime _now;

  static const me = DemoForumContent.me;

  /// The same sample content for a discussion's page, the composer and the Forums tab.
  @override
  late final ForumRepository forum = DemoForumRepository(now: _now);

  @override
  SponsoredCard get sponsored => const SponsoredCard(
    label: 'SPONSORED PARTNER',
    title: 'The Future of FM Operations',
    body:
        'Automated spatial control, predictive fault detection, and seamless BMS telemetry.\n'
        'Benchmark leases and cut OPEX by 18%.',
    cta: 'Learn More',
    link: '/vendors',
    background: '$_demo/sponsored_bg.jpg',
  );

  @override
  Set<String> get initiallyOpen => const {'iot-hvac'};

  @override
  bool get opensLeadThread => false;

  /// The sample cards already hold their whole text and photos.
  @override
  Future<FeedPostDetail?> detail(FeedPost post) async => null;

  /// The design's four posts: Sarah Jenkins's (its comments open, Arvind Swamy's reply first), David Chen's,
  /// Marcus Reed's poll and Elena Rostova's photos.
  List<FeedPost> get _posts => DemoForumContent(now: _now).designed;

  @override
  Future<FeedPage> load(FeedFilter filter, {int page = 1, String? search, String? tag}) async {
    var posts = _posts;
    final q = search?.trim().toLowerCase() ?? '';
    if (q.isNotEmpty) {
      posts = posts.where((p) => '${p.title} ${p.body} ${p.tags.join(' ')}'.toLowerCase().contains(q)).toList();
    }
    if (tag != null) posts = posts.where((p) => p.tags.contains('#$tag')).toList();
    posts = switch (filter) {
      FeedFilter.all || FeedFilter.trending => posts,
      FeedFilter.following => posts.where((p) => !p.showFollow).toList(),
      FeedFilter.unanswered => const [],
      FeedFilter.polls => posts.where((p) => p.poll != null).toList(),
    };
    return FeedPage(posts: page == 1 ? posts : const [], hasMore: false);
  }

  @override
  Future<int> unreadNotifications() async => 3;

  @override
  Future<void> setReaction(FeedPost post, ReactionKind? kind) async {}

  @override
  Future<void> setSaved(FeedPost post, bool saved) async {}

  @override
  Future<void> follow(FeedAuthor author) async {}

  @override
  Future<FeedPoll> vote(FeedPost post, String optionId) async {
    final poll = post.poll!;
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
    );
  }

  @override
  Future<List<FeedReply>> replies(FeedPost post) async =>
      _posts.firstWhere((p) => p.id == post.id, orElse: () => post).replies;

  @override
  Future<void> reply(FeedPost post, String text, {String? parentId}) async {}

  @override
  Future<void> deleteReply(FeedReply reply) async {}

  @override
  Future<void> setReplyLiked(FeedReply reply, bool like) async {}

  @override
  Uri link(FeedPost post, {FeedReply? reply}) => discussionLink(post, reply);
}
