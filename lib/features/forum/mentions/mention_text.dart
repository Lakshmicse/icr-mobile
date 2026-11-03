/// Mentions in the words a person types, as pure Dart: where the "@" being typed is, what replaces it when a person is
/// picked, which picked people are still in the text, and the forum's HTML with each of them as a link to their
/// profile. The controller that watches a field is `mention_controller.dart`; the widgets are `mention_widgets.dart`.
library;

import '../../../core/util/site_policy.dart';
import '../../feed/feed_models.dart';
import '../../feed/forum_json.dart';

/// The "@" a person is typing a name after, as the caret sees it.
class MentionQuery {
  const MentionQuery({required this.start, required this.text});

  /// Where the "@" is in the text.
  final int start;

  /// What was typed after it, up to the caret ("ra sh").
  final String text;

  /// Where the query ends (the caret).
  int get end => start + 1 + text.length;

  /// What a search asks for: the words, trimmed.
  String get search => text.trim();

  @override
  bool operator ==(Object other) => other is MentionQuery && other.start == start && other.text == text;

  @override
  int get hashCode => Object.hash(start, text);

  @override
  String toString() => 'MentionQuery($start, "$text")';
}

/// The most characters a query may run to: a name is not longer, so a stray "@" far back in a line ends it.
const mentionQueryMax = 40;

final _nameChar = RegExp(r"[\p{L}\p{N}'’\-]", unicode: true);
final _wordChar = RegExp(r'[\p{L}\p{N}_.\-+]', unicode: true);
final _letterOrDigit = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// The mention being typed when the caret is at [caret] in [text], or null.
///
/// It is one when the caret sits right after an "@" that starts a word (an address like `a@b.com` is not one) and
/// the letters typed since: a name, then at most one space and a second word ("@ra sh"). A second space in a row, a
/// newline, punctuation, or an "@" followed by a space ends it.
MentionQuery? mentionQueryAt(String text, int caret) {
  if (caret < 1 || caret > text.length) return null;
  var i = caret - 1;
  var spaces = 0;
  while (i >= 0) {
    final c = text[i];
    if (c == '@') break;
    if (c == ' ') {
      // Two words at most, and never two spaces running.
      if (++spaces > 1 || (i + 1 < caret && text[i + 1] == ' ')) return null;
    } else if (!_nameChar.hasMatch(c)) {
      return null;
    }
    i--;
    if (caret - i > mentionQueryMax + 1) return null;
  }
  if (i < 0) return null;
  if (i > 0 && _wordChar.hasMatch(text[i - 1])) return null;
  final typed = text.substring(i + 1, caret);
  // "@ " is an at-sign in a sentence, not a name begun.
  if (typed.startsWith(' ')) return null;
  return MentionQuery(start: i, text: typed);
}

/// [text] with the typed "@query" ([query], up to [caret]) replaced by "@Name " and where the caret goes after it.
/// No second space is added when one follows already.
({String text, int caret}) insertMention(String text, MentionQuery query, int caret, String name) {
  final before = text.substring(0, query.start);
  final after = text.substring(caret.clamp(query.start, text.length));
  final spaced = after.isNotEmpty && RegExp(r'^[\s.,;:!?)]').hasMatch(after);
  final handle = '@$name${spaced ? '' : ' '}';
  return (text: '$before$handle$after', caret: before.length + handle.length);
}

/// Where one picked person stands in a text.
typedef MentionSpan = ({int start, int end, Mention mention});

/// Where each of [mentions] still stands in [text], in order: "@Name" with no letter or digit right before the "@" or
/// right after the name. A person the text no longer holds (the mention was deleted, or edited into other words) is
/// not in the list, so nothing is sent for them. A longer name wins over a shorter one it begins ("@Ravi Kumar
/// Singh" over "@Ravi Kumar"), and each place is used once. Two different people who share a name are told apart by
/// the order they were picked in: the first "@Rajesh Sharma" in the text is the first Rajesh picked, the second the second.
List<MentionSpan> mentionSpans(String text, List<Mention> mentions) {
  if (mentions.isEmpty || text.isEmpty) return const [];
  final byHandle = <String, List<Mention>>{};
  for (final m in mentions) {
    byHandle.putIfAbsent(m.handle, () => []).add(m);
  }
  final handles = byHandle.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
  final taken = <MentionSpan>[];
  bool overlaps(int start, int end) => taken.any((s) => start < s.end && end > s.start);
  for (final handle in handles) {
    final people = byHandle[handle]!;
    var nth = 0;
    var from = 0;
    while (true) {
      final at = text.indexOf(handle, from);
      if (at < 0) break;
      final end = at + handle.length;
      from = at + 1;
      if (at > 0 && _wordChar.hasMatch(text[at - 1])) continue;
      if (end < text.length && _letterOrDigit.hasMatch(text[end])) continue;
      if (overlaps(at, end)) continue;
      taken.add((start: at, end: end, mention: people[nth < people.length ? nth : people.length - 1]));
      nth++;
    }
  }
  taken.sort((a, b) => a.start.compareTo(b.start));
  return taken;
}

/// Each person once, whose "@Name" is still in [text].
List<Mention> mentionsStillIn(String text, List<Mention> mentions) {
  final seen = <String>{};
  return [
    for (final s in mentionSpans(text, mentions))
      if (seen.add(s.mention.id)) s.mention,
  ];
}

/// What a person typed, as the forum's HTML, with each mention as `<a href="/members/{id}">@Name</a>`. Everything else
/// is escaped as [ForumJson.textToHtml] does (one `<p>` per paragraph, single line breaks kept), so with no mention
/// in the text this is that function's answer.
String mentionedHtml(String text, List<Mention> mentions) {
  final paragraphs = text.trim().split(RegExp(r'\n\s*\n')).map((p) => p.trim()).where((p) => p.isNotEmpty);
  return paragraphs.map((p) => '<p>${_inline(p, mentions)}</p>').join();
}

String _inline(String paragraph, List<Mention> mentions) {
  String plain(String s) => ForumJson.escape(s).replaceAll('\n', '<br>');
  final out = StringBuffer();
  var at = 0;
  for (final s in mentionSpans(paragraph, mentions)) {
    out
      ..write(plain(paragraph.substring(at, s.start)))
      ..write('<a href="/members/${ForumJson.escape(s.mention.id)}">${ForumJson.escape(s.mention.handle)}</a>');
    at = s.end;
  }
  out.write(plain(paragraph.substring(at)));
  return out.toString();
}

/// The members a post's or reply's HTML tags: each `<a href="/members/{id}">@Name</a>`, once.
List<Mention> mentionsInHtml(String? html) => ForumJson.mentionsIn(html);

/// A root-relative `/members/{id}` link.
final memberPath = RegExp(r'^/members/([A-Za-z0-9_\-]+)$');

/// The member a link to the website's `/members/{id}` page names (a mention's anchor, once made absolute), or null
/// for any other link.
String? memberIdOf(Uri uri) {
  if (uri.hasAuthority && !SitePolicy.isSite(uri)) return null;
  return memberPath.firstMatch(uri.path)?.group(1);
}
