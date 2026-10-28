import '../../core/config.dart';
import 'feed_models.dart';

/// The forum's JSON (`ForumThreadCardDto`, `ForumReplyDto`, `ForumAuthorDto`, `ForumPollDto`) as the cards draw
/// it. One mapping for the Home feed and the Forums tab, so a discussion reads the same in both.
class ForumJson {
  const ForumJson({required this.apiBase, required this.viewerId});

  /// The API's base URL, for turning `/uploads/...` paths into addresses.
  final String apiBase;
  final String? viewerId;

  /// The topics a green tag is drawn for: the design tints Sustainability and Site Audit green and the rest
  /// (Real Estate Tech, #POLL) blue. The forum files them under the taxonomy's level-1 categories, so the tint
  /// follows the family of the level-1 category.
  static const greenFamilies = {'SUSTAINABILITY_ESG', 'HEALTH_SAFETY_ENVIRONMENT', 'LANDSCAPE', 'CORPORATE_WELLNESS'};

  /// A discussion's card. [following] is who the reader follows: "Follow" is shown for everyone else.
  FeedPost post(Map<String, dynamic> row, {Set<String> following = const {}}) {
    final author = this.author(row['author'] as Map<String, dynamic>);
    final pollJson = row['poll'] as Map<String, dynamic>?;
    final isPoll = pollJson != null;
    final family = (row['category'] as Map<String, dynamic>?)?['key'] as String? ?? '';
    final category = (row['subcategory'] ?? row['category']) as Map<String, dynamic>?;
    final counts = <ReactionKind, int>{};
    for (final e in (row['reactions'] as Map<String, dynamic>? ?? const {}).entries) {
      final kind = reactionKindFromApi(e.key);
      if (kind != null) counts[kind] = (e.value as num).toInt();
    }
    final kinds = topReactionKinds(counts);
    final likes = (row['likes'] as num?)?.toInt() ?? 0;
    final status = row['status'] as String? ?? 'OPEN';
    return FeedPost(
      id: row['id'] as String,
      slug: row['slug'] as String,
      author: author,
      createdAt: DateTime.parse(row['createdAt'] as String),
      title: row['title'] as String? ?? '',
      body: row['excerpt'] as String? ?? '',
      topic: isPoll ? 'Poll' : topic(category?['name'] as String?),
      topicTone: !isPoll && greenFamilies.contains(family) ? TopicTone.green : TopicTone.blue,
      tags: (row['tags'] as List? ?? const []).map((t) => '#$t').toList(),
      reactions: likes,
      reactionKinds: kinds.isEmpty && likes > 0 ? const [ReactionKind.like] : kinds,
      reactionCounts: counts,
      myReaction: reactionKindFromApi(row['myReaction'] as String?) ?? (row['myVote'] == 1 ? ReactionKind.like : null),
      comments: (row['replyCount'] as num?)?.toInt() ?? 0,
      views: (row['viewCount'] as num?)?.toInt(),
      saved: row['saved'] == true,
      showFollow: viewerId != null && author.id != viewerId && !following.contains(author.id),
      poll: isPoll ? poll(pollJson, open: status == 'OPEN') : null,
      kind: threadKindFromApi(row['kind'] as String?),
      locked: status != 'OPEN',
      pinned: row['pinned'] == true,
      answered: row['hasAcceptedAnswer'] == true,
      categoryKey: family.isEmpty ? null : family,
      subcategoryKey: (row['subcategory'] as Map<String, dynamic>?)?['key'] as String?,
    );
  }

  FeedAuthor author(Map<String, dynamic> json) {
    final url = AppConfig.absoluteUrl(json['avatarUrl'] as String?, apiBase: apiBase);
    final name = '${json['firstName'] ?? ''} ${json['lastName'] ?? ''}'.trim();
    return FeedAuthor(
      id: json['id'] as String,
      name: name.isEmpty ? 'ICR member' : name,
      headline: json['headline'] as String?,
      photo: url == null ? null : FeedPicture.network(url),
    );
  }

  FeedPoll poll(Map<String, dynamic> json, {required bool open}) => FeedPoll(
    id: json['id'] as String,
    totalVotes: (json['totalVotes'] as num?)?.toInt() ?? 0,
    myOptionId: json['myOptionId'] as String?,
    open: open,
    options: (json['options'] as List)
        .cast<Map<String, dynamic>>()
        .map(
          (o) => FeedPollOption(
            id: o['id'] as String,
            label: o['label'] as String? ?? '',
            votes: (o['votes'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList(),
  );

  /// A reply and the answers the forum nested under it.
  FeedReply reply(Map<String, dynamic> json) {
    final author = this.author(json['author'] as Map<String, dynamic>);
    final attachment = json['attachment'] as Map<String, dynamic>?;
    final uploadId = attachment?['uploadId'] as String?;
    final created = DateTime.parse(json['createdAt'] as String);
    return FeedReply(
      id: json['id'] as String,
      author: author,
      body: plainText(json['bodyHtml'] as String? ?? ''),
      createdAt: created,
      meta: organisationOf(author.headline),
      role: roleOf(author.headline),
      likes: (json['likes'] as num?)?.toInt() ?? 0,
      liked: json['myReaction'] != null || json['myVote'] == 1,
      parentId: json['parentId'] as String?,
      canEdit: json['canEdit'] == true,
      accepted: json['accepted'] == true,
      pending: json['moderation'] == 'PENDING',
      attachmentName: uploadId == null ? null : (attachment?['fileName'] as String? ?? uploadId),
      attachmentUrl: uploadId == null ? null : AppConfig.absoluteUrl('/uploads/$uploadId', apiBase: apiBase),
      bodyHtml: json['bodyHtml'] as String?,
      children: (json['children'] as List? ?? const []).cast<Map<String, dynamic>>().map(reply).toList(),
    );
  }

  static final _separator = RegExp(r'\s(?:at|@|·)\s+');

  /// The organisation a headline names, for the line under a reply's name: "General Counsel at Brookfield
  /// Properties" and "Director · Brookfield" both give the part after the separator; a headline with neither
  /// is shown whole.
  static String? organisationOf(String? headline) {
    final text = headline?.trim();
    if (text == null || text.isEmpty) return null;
    final match = RegExp(r'\s(?:at|@|·)\s+(.+)$').firstMatch(text);
    return match?.group(1)?.trim() ?? text;
  }

  /// The role a headline names, for the pill beside a reply's name: "VP Sustainability at Brookfield
  /// Properties" gives "VP Sustainability". A headline with no organisation in it has no role of its own (it is
  /// the line under the name, whole).
  static String? roleOf(String? headline) {
    final text = headline?.trim();
    if (text == null || text.isEmpty) return null;
    final match = _separator.firstMatch(text);
    if (match == null) return null;
    final role = text.substring(0, match.start).trim();
    return role.isEmpty ? null : role;
  }

  /// A category's name as the card's meta line prints it, in the forum's own words ("Other / Specialty Services"):
  /// a label, never a hashtag. A tag a person typed is a real `#tag` and sits under the words.
  static String? topic(String? name) {
    final label = name?.trim();
    return label == null || label.isEmpty ? null : label;
  }

  static bool isPicture(String file) => RegExp(r'\.(jpe?g|png|webp|gif)$', caseSensitive: false).hasMatch(file);

  /// A photo's name as a caption ("BIM Feasibility Lab.jpg" → "BIM Feasibility Lab"), when it reads as words:
  /// letters and spaces, short. A camera's "IMG_2041.jpg" is no caption.
  static String? caption(String? fileName) {
    if (fileName == null) return null;
    final words = fileName.replaceFirst(RegExp(r'\.[A-Za-z0-9]{2,5}$'), '').replaceAll(RegExp(r'[_-]+'), ' ').trim();
    return RegExp(r"^[A-Za-z][A-Za-z' ]{2,31}$").hasMatch(words) ? words : null;
  }

  /// The `src` of each `<img>` in a body, in order.
  static List<String> imageSources(String html) => [
    for (final m in RegExp(r'''<img\b[^>]*?\bsrc\s*=\s*["']([^"']+)["']''', caseSensitive: false).allMatches(html))
      m.group(1)!,
  ];

  static String decodeEntities(String text) => text
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&#x27;', "'")
      .replaceAll('&amp;', '&');

  /// A body as plain text, paragraphs on their own lines.
  static String plainText(String html) => decodeEntities(
    html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</(p|div|li|h\d|blockquote)>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), ''),
  ).replaceAll(RegExp(r'\n{2,}'), '\n').trim();

  static String escape(String text) =>
      text.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

  /// What a person typed, as the forum's HTML: escaped (it is words, not markup), one `<p>` per paragraph (a blank
  /// line), single line breaks kept.
  static String textToHtml(String text) {
    final paragraphs = text.trim().split(RegExp(r'\n\s*\n')).map((p) => p.trim()).where((p) => p.isNotEmpty);
    return paragraphs.map((p) => '<p>${escape(p).replaceAll('\n', '<br>')}</p>').join();
  }

  /// The forum's HTML as text a person can edit: the inverse of [textToHtml] for what the app wrote, and the
  /// words of anything richer the website's editor wrote.
  static String htmlToText(String html) => decodeEntities(
    html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</(p|div|h\d|blockquote|ul|ol)>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '• ')
        .replaceAll(RegExp(r'</li>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<img\b[^>]*>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<[^>]+>'), ''),
  ).replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}
