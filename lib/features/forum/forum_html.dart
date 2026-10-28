/// The forum's sanitised HTML (`sanitizeRichText` on the API: paragraphs, headings, lists, quotes, code, links,
/// bold, italic, underline, strike) read into blocks a screen can draw, so a post written in the website's editor
/// keeps its shape in the app. Pure Dart: the widget is `forum_rich_text.dart`.
library;

import '../feed/forum_json.dart';

/// A run of text with the marks it carries.
class InlineRun {
  const InlineRun(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.code = false,
    this.href,
  });

  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;
  final bool code;

  /// Where a link goes.
  final String? href;

  @override
  String toString() => 'InlineRun($text${bold ? ' b' : ''}${italic ? ' i' : ''}${href == null ? '' : ' -> $href'})';
}

enum BlockKind { paragraph, heading, listItem, quote, codeBlock }

class RichBlock {
  const RichBlock(this.kind, this.runs, {this.level = 0, this.ordinal, this.depth = 0});

  final BlockKind kind;
  final List<InlineRun> runs;

  /// A heading's level (1 to 6).
  final int level;

  /// A list item's number in an ordered list; null in a bulleted one.
  final int? ordinal;

  /// How deeply a list item is nested (0 at the top).
  final int depth;

  String get text => runs.map((r) => r.text).join();
}

/// [html] as blocks, in order. Unknown tags are looked through (their text is kept), `<img>` is left out (the
/// discussion page draws a post's pictures itself), and an `href` that is not http, https or mailto is dropped.
List<RichBlock> parseForumHtml(String html) {
  final blocks = <RichBlock>[];
  var runs = <InlineRun>[];
  var bold = 0, italic = 0, underline = 0, strike = 0, code = 0;
  final links = <String?>[];
  // Open lists: null for a bulleted one, the next number for an ordered one.
  final lists = <int?>[];
  var inQuote = 0;
  var inPre = 0;
  var headingLevel = 0;
  // The list item whose own text is being collected.
  var itemOrdinal = -1;
  var inItem = false;

  void flush(BlockKind kind, {int level = 0, int? ordinal, int depth = 0}) {
    // Trim the edges of a block, so whitespace between tags is layout and not words.
    final cleaned = <InlineRun>[];
    for (final r in runs) {
      if (r.text.isNotEmpty) cleaned.add(r);
    }
    runs = <InlineRun>[];
    if (cleaned.isEmpty) return;
    if (kind != BlockKind.codeBlock) {
      final first = cleaned.first;
      cleaned[0] = _copy(first, first.text.replaceFirst(RegExp(r'^\s+'), ''));
      final last = cleaned.last;
      cleaned[cleaned.length - 1] = _copy(last, last.text.replaceFirst(RegExp(r'\s+$'), ''));
      cleaned.removeWhere((r) => r.text.isEmpty);
      if (cleaned.isEmpty) return;
    }
    blocks.add(RichBlock(kind, cleaned, level: level, ordinal: ordinal, depth: depth));
  }

  void flushCurrent() {
    if (inPre > 0) {
      flush(BlockKind.codeBlock);
    } else if (headingLevel > 0) {
      flush(BlockKind.heading, level: headingLevel);
    } else if (inItem) {
      flush(BlockKind.listItem, ordinal: itemOrdinal < 0 ? null : itemOrdinal, depth: (lists.length - 1).clamp(0, 6));
    } else if (inQuote > 0) {
      flush(BlockKind.quote);
    } else {
      flush(BlockKind.paragraph);
    }
  }

  final token = RegExp(r'<(/?)([a-zA-Z][a-zA-Z0-9]*)([^>]*)>|([^<]+)|<');
  for (final m in token.allMatches(html)) {
    final text = m.group(4);
    if (text != null) {
      var value = ForumJson.decodeEntities(text);
      if (inPre == 0) value = value.replaceAll(RegExp(r'\s+'), ' ');
      if (value.isEmpty) continue;
      runs.add(
        InlineRun(
          value,
          bold: bold > 0 || headingLevel > 0,
          italic: italic > 0,
          underline: underline > 0 || (links.isNotEmpty && links.last != null),
          strike: strike > 0,
          code: code > 0,
          href: links.isEmpty ? null : links.last,
        ),
      );
      continue;
    }
    final closing = m.group(1) == '/';
    final tag = (m.group(2) ?? '').toLowerCase();
    final attrs = m.group(3) ?? '';
    switch (tag) {
      case 'p':
      case 'div':
        flushCurrent();
      case 'br':
        runs.add(const InlineRun('\n'));
      case 'strong':
      case 'b':
        bold += closing ? (bold > 0 ? -1 : 0) : 1;
      case 'em':
      case 'i':
        italic += closing ? (italic > 0 ? -1 : 0) : 1;
      case 'u':
        underline += closing ? (underline > 0 ? -1 : 0) : 1;
      case 's':
      case 'strike':
      case 'del':
        strike += closing ? (strike > 0 ? -1 : 0) : 1;
      case 'code':
        if (inPre == 0) code += closing ? (code > 0 ? -1 : 0) : 1;
      case 'a':
        if (closing) {
          if (links.isNotEmpty) links.removeLast();
        } else {
          links.add(_safeHref(attrs));
        }
      case 'h1' || 'h2' || 'h3' || 'h4' || 'h5' || 'h6':
        flushCurrent();
        headingLevel = closing ? 0 : int.parse(tag.substring(1));
      case 'ul':
      case 'ol':
        flushCurrent();
        if (closing) {
          if (lists.isNotEmpty) lists.removeLast();
        } else {
          lists.add(tag == 'ol' ? 1 : null);
        }
      case 'li':
        flushCurrent();
        if (closing) {
          inItem = false;
        } else {
          inItem = true;
          if (lists.isNotEmpty && lists.last != null) {
            itemOrdinal = lists.last!;
            lists[lists.length - 1] = itemOrdinal + 1;
          } else {
            itemOrdinal = -1;
          }
        }
      case 'blockquote':
        flushCurrent();
        inQuote += closing ? (inQuote > 0 ? -1 : 0) : 1;
      case 'pre':
        flushCurrent();
        inPre += closing ? (inPre > 0 ? -1 : 0) : 1;
    }
  }
  flushCurrent();
  return blocks;
}

InlineRun _copy(InlineRun r, String text) => InlineRun(
  text,
  bold: r.bold,
  italic: r.italic,
  underline: r.underline,
  strike: r.strike,
  code: r.code,
  href: r.href,
);

/// The link in an `<a href="...">`, when it is one a person may follow.
String? _safeHref(String attrs) {
  final m = RegExp(r'''href\s*=\s*(?:"([^"]*)"|'([^']*)')''', caseSensitive: false).firstMatch(attrs);
  final raw = ForumJson.decodeEntities(m?.group(1) ?? m?.group(2) ?? '').trim();
  if (raw.isEmpty) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null) return null;
  if (!uri.hasScheme) return null;
  return const {'http', 'https', 'mailto'}.contains(uri.scheme.toLowerCase()) ? raw : null;
}
