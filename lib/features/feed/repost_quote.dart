/// What a repost's words carry about the original. The forum has no repost record: a repost (`forum/repost.dart`)
/// is a new discussion that opens with "↻ Reposted from" and the author, the original's title in quotes and its link, and
/// may go on with the reposter's own words. Reading those lines back is how a card knows to draw the original inside
/// the repost, with its photos and poll (owner, 11 Nov 2026: "reposted post sharing the link rather than images,
/// and poll not coming").
class RepostQuote {
  const RepostQuote({required this.author, required this.title, required this.slug, required this.rest});

  final String author;
  final String title;

  /// The original discussion's slug, from its link.
  final String slug;

  /// The reposter's own words with the quote taken out; empty for an instant repost.
  final String rest;

  static final _pattern = RegExp(
    r'↻ Reposted from (?<author>[^\n]+?)\s*\n\s*[“"](?<title>[^”"]*)[”"]\s*\n\s*'
    r'(?<link>\S*/community/(?<slug>[A-Za-z0-9._~-]+)\S*)',
  );

  /// The quote in [body], or null when the words are not a repost's.
  static RepostQuote? of(String body) {
    final m = _pattern.firstMatch(body);
    if (m == null) return null;
    return RepostQuote(
      author: m.namedGroup('author')!.trim(),
      title: m.namedGroup('title')!.trim(),
      slug: m.namedGroup('slug')!,
      rest: body.replaceRange(m.start, m.end, '').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim(),
    );
  }
}
