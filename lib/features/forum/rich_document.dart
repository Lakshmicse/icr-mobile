/// The composer's rich details: a document of text with a few marks on each character, and the forum's HTML both
/// ways. The website's editor (Tiptap) writes bold, italic, a level-3 heading, bulleted and numbered lists and links;
/// this is the same set, held as plain characters so a phone keyboard can type into it.
///
/// * A character carries [RichMark] bits (bold, italic, heading) and a link number.
/// * A list item is a line that starts with "• " or "1. ": the prefix is real text, so the field needs nothing but a
///   text controller, and Enter, Backspace and typing "- " behave as in the website's editor (`rich_text_controller`).
/// * A heading is a line whose first word carries the heading mark; every character of the line is kept in step.
///
/// Pure Dart: the field is `rich_text_controller.dart`, the screen's frame `widgets/rich_editor.dart`.
library;

import 'dart:math' as math;

import '../feed/forum_json.dart';
import 'forum_html.dart';

/// What a character of the details can carry. The bits above [heading] hold the link's number (1-based into
/// [RichDoc.links]; 0 is none).
class RichMark {
  RichMark._();

  static const bold = 1;
  static const italic = 2;
  static const heading = 4;
  static const inline = bold | italic;
  static const _linkShift = 3;

  static int link(int marks) => marks >> _linkShift;
  static int withLink(int marks, int id) => (marks & 7) | (id << _linkShift);
}

/// A bullet's prefix; a numbered item's is "1. ", "2. "...
const bulletPrefix = '• ';
final _numberPrefix = RegExp(r'\d{1,2}\. ');

/// How many characters of the line starting at [lineStart] are a list prefix (0 for a plain line).
int prefixAt(String text, int lineStart) {
  if (text.startsWith(bulletPrefix, lineStart)) return bulletPrefix.length;
  final match = _numberPrefix.matchAsPrefix(text, lineStart);
  return match == null ? 0 : match.end - lineStart;
}

enum RichLineKind { paragraph, heading, bullet, number }

/// One line of the details: where it sits in the text, how much of it is a list prefix, and what it is.
class RichLine {
  const RichLine(this.start, this.end, this.prefix, this.kind);

  /// The line's first character and the position of its newline (or the end of the text).
  final int start;
  final int end;
  final int prefix;
  final RichLineKind kind;

  int get contentStart => start + prefix;
  int get contentLength => end - start - prefix;
}

/// The lines of [text], read with [marks] for which of them are headings.
List<RichLine> richLines(String text, List<int> marks) {
  final out = <RichLine>[];
  var start = 0;
  while (true) {
    final newline = text.indexOf('\n', start);
    final end = newline < 0 ? text.length : newline;
    final prefix = prefixAt(text, start);
    final RichLineKind kind;
    if (prefix > 0) {
      kind = text.startsWith(bulletPrefix, start) ? RichLineKind.bullet : RichLineKind.number;
    } else if (end > start && (marks[start] & RichMark.heading) != 0) {
      kind = RichLineKind.heading;
    } else {
      kind = RichLineKind.paragraph;
    }
    out.add(RichLine(start, end, prefix, kind));
    if (newline < 0) return out;
    start = newline + 1;
  }
}

/// The characters a limit counts: the words, not the newlines nor the list prefixes (Tiptap's `CharacterCount`).
int richPlainLength(String text) {
  var n = 0;
  var start = 0;
  while (true) {
    final newline = text.indexOf('\n', start);
    final end = newline < 0 ? text.length : newline;
    n += end - start - prefixAt(text, start);
    if (newline < 0) return n;
    start = newline + 1;
  }
}

/// A snapshot of the details: text, a mark for each character, and the addresses its links go to.
class RichDoc {
  const RichDoc._(this.text, this.marks, this.links);

  static const empty = RichDoc._('', <int>[], <String>[]);

  /// What a person typed with no formatting: the lines as they are.
  factory RichDoc.fromPlain(String text) {
    final clean = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    return RichDoc._(clean, List<int>.filled(clean.length, 0), const <String>[]);
  }

  /// The forum's HTML in the editor's terms: a paragraph is a line, a list item a prefixed line, a heading (any
  /// level) a heading line, quotes and code their words as paragraphs. Marks the editor has no use for (underline,
  /// strike, code) are dropped; the words are kept.
  factory RichDoc.fromHtml(String html) {
    final b = RichBuffer();
    for (final block in parseForumHtml(html)) {
      final heading = block.kind == BlockKind.heading;
      final lines = <List<InlineRun>>[[]];
      for (final run in block.runs) {
        final parts = run.text.split('\n');
        for (var i = 0; i < parts.length; i++) {
          if (i > 0) lines.add([]);
          if (parts[i].isEmpty) continue;
          lines.last.add(InlineRun(parts[i], bold: run.bold, italic: run.italic, href: run.href));
        }
      }
      var first = true;
      for (final runs in lines) {
        if (runs.every((r) => r.text.trim().isEmpty)) continue;
        var prefix = '';
        if (first && block.kind == BlockKind.listItem) {
          prefix = block.ordinal == null ? bulletPrefix : '${block.ordinal}. ';
        }
        first = false;
        b.appendLine(prefix, [
          for (final r in runs)
            (
              r.text,
              // A heading is bold already: its runs come from the parser bold, and the editor keeps only the heading.
              (heading ? RichMark.heading : (r.bold ? RichMark.bold : 0)) | (r.italic ? RichMark.italic : 0),
              r.href,
            ),
        ]);
      }
    }
    b.normalise(const []);
    return b.snapshot();
  }

  final String text;
  final List<int> marks;
  final List<String> links;

  /// The words alone, a line each: no list prefixes. What a validation or a search reads.
  String get plainText {
    final out = <String>[];
    for (final line in richLines(text, marks)) {
      out.add(text.substring(line.contentStart, line.end));
    }
    return out.join('\n');
  }

  /// How many characters the limit counts.
  int get plainLength => richPlainLength(text);

  bool get isBlank => text.trim().isEmpty || plainText.trim().isEmpty;

  /// The document as the forum's HTML: `<p>`, `<h3>`, `<ul>`/`<ol>` with `<li>`, `<strong>`, `<em>` and `<a href>`.
  /// Every character of text is escaped; a link goes out only when it is http, https or mailto. An empty line
  /// separates nothing and is dropped.
  String toHtml() {
    final out = StringBuffer();
    String? open;
    void close() {
      if (open != null) out.write('</$open>');
      open = null;
    }

    for (final line in richLines(text, marks)) {
      var from = line.contentStart;
      var to = line.end;
      while (from < to && _isSpace(text.codeUnitAt(from))) {
        from++;
      }
      while (to > from && _isSpace(text.codeUnitAt(to - 1))) {
        to--;
      }
      if (from >= to) {
        close();
        continue;
      }
      final heading = line.kind == RichLineKind.heading;
      final inner = _inline(from, to, heading);
      switch (line.kind) {
        case RichLineKind.bullet:
        case RichLineKind.number:
          final tag = line.kind == RichLineKind.bullet ? 'ul' : 'ol';
          if (open != tag) {
            close();
            out.write('<$tag>');
            open = tag;
          }
          out.write('<li>$inner</li>');
        case RichLineKind.heading:
          close();
          out.write('<h3>$inner</h3>');
        case RichLineKind.paragraph:
          close();
          out.write('<p>$inner</p>');
      }
    }
    close();
    return out.toString();
  }

  static bool _isSpace(int unit) => unit == 0x20 || unit == 0x09 || unit == 0xA0;

  /// [from, to) of one line as inline HTML: links outermost, then bold, then italic.
  String _inline(int from, int to, bool heading) {
    final out = StringBuffer();
    var i = from;
    while (i < to) {
      final link = RichMark.link(marks[i]);
      var j = i;
      while (j < to && RichMark.link(marks[j]) == link) {
        j++;
      }
      final href = link > 0 && link <= links.length ? links[link - 1] : null;
      final safe = href != null && _safeHref(href);
      if (safe) out.write('<a href="${ForumJson.escape(href)}">');
      var k = i;
      while (k < j) {
        final style = marks[k] & RichMark.inline;
        var m = k;
        while (m < j && (marks[m] & RichMark.inline) == style) {
          m++;
        }
        final bold = !heading && (style & RichMark.bold) != 0;
        final italic = (style & RichMark.italic) != 0;
        if (bold) out.write('<strong>');
        if (italic) out.write('<em>');
        out.write(ForumJson.escape(text.substring(k, m)));
        if (italic) out.write('</em>');
        if (bold) out.write('</strong>');
        k = m;
      }
      if (safe) out.write('</a>');
      i = j;
    }
    return out.toString();
  }
}

/// A link a post may carry: http, https or mailto.
bool _safeHref(String href) {
  final uri = Uri.tryParse(href);
  if (uri == null || !uri.hasScheme) return false;
  return const {'http', 'https', 'mailto'}.contains(uri.scheme.toLowerCase());
}

/// Whether [href] reads as an address the editor's Link button may attach: the website adds `https://` to an
/// address that has no scheme, and so does [normaliseLink].
String? normaliseLink(String raw) {
  final value = raw.trim();
  if (value.isEmpty || value.contains(RegExp(r'\s'))) return null;
  final withScheme = RegExp(r'^(https?://|mailto:)', caseSensitive: false).hasMatch(value) ? value : 'https://$value';
  final uri = Uri.tryParse(withScheme);
  if (uri == null || !_safeHref(withScheme)) return null;
  if (uri.scheme != 'mailto' && uri.host.isEmpty) return null;
  return withScheme;
}

/// HTML tags the editor cannot hold: quotes, code and rules read as plain paragraphs once the post is edited.
bool htmlHasFormattingEditorLoses(String html) =>
    RegExp(r'<(blockquote|pre|code|hr|table|img)\b', caseSensitive: false).hasMatch(html);

/// The document being edited: the same lists as a [RichDoc], changed in place by the field and the toolbar.
class RichBuffer {
  RichBuffer({this.text = '', List<int>? marks, List<String>? links})
    : marks = marks == null ? <int>[] : List<int>.of(marks),
      links = links == null ? <String>[] : List<String>.of(links) {
    if (marks == null) this.marks.addAll(List<int>.filled(text.length, 0));
  }

  factory RichBuffer.of(RichDoc doc) => RichBuffer(text: doc.text, marks: doc.marks, links: doc.links);

  String text;
  List<int> marks;
  List<String> links;

  RichDoc snapshot() => RichDoc._(text, List<int>.unmodifiable(marks), List<String>.unmodifiable(links));

  List<RichLine> lines() => richLines(text, marks);

  /// The line holding [offset].
  int lineIndexOf(List<RichLine> lines, int offset) {
    var index = 0;
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].start <= offset) index = i;
    }
    return index;
  }

  int linkNumber(String href) {
    final i = links.indexOf(href);
    if (i >= 0) return i + 1;
    links.add(href);
    return links.length;
  }

  /// One line at the end: [prefix] (marks 0), then the pieces `(text, marks, href)`.
  void appendLine(String prefix, List<(String, int, String?)> pieces) {
    if (text.isNotEmpty) {
      text += '\n';
      marks.add(0);
    }
    text += prefix;
    marks.addAll(List<int>.filled(prefix.length, 0));
    for (final (piece, m, href) in pieces) {
      text += piece;
      final withLink = href == null || !_safeHref(href) ? m : RichMark.withLink(m, linkNumber(href));
      marks.addAll(List<int>.filled(piece.length, withLink));
    }
  }

  // --- rewriting by line ------------------------------------------------------------------------------------

  /// Rewrites each line [edit] has an answer for: its list prefix (the text before its words) and whether its
  /// words are a heading (null keeps them as they are). Returns [offsets] moved through the change.
  List<int> rewriteLines(List<int> offsets, ({String prefix, bool? heading})? Function(int index, RichLine line) edit) {
    final spans = lines();
    final out = StringBuffer();
    final outMarks = <int>[];
    final starts = <int>[];
    final prefixes = <int>[];
    for (var i = 0; i < spans.length; i++) {
      final line = spans[i];
      if (i > 0) {
        out.write('\n');
        outMarks.add(0);
      }
      starts.add(outMarks.length);
      final answer = edit(i, line);
      final prefix = answer?.prefix ?? text.substring(line.start, line.contentStart);
      final heading = answer?.heading;
      prefixes.add(prefix.length);
      out.write(prefix);
      outMarks.addAll(List<int>.filled(prefix.length, 0));
      for (var k = line.contentStart; k < line.end; k++) {
        var m = marks[k];
        if (heading == true) {
          m = (m | RichMark.heading) & ~RichMark.bold;
        } else if (heading == false) {
          m &= ~RichMark.heading;
        }
        out.write(text[k]);
        outMarks.add(m);
      }
    }
    final newText = out.toString();
    if (newText == text && _same(outMarks, marks)) return offsets;
    final mapped = [
      for (final o in offsets) _remap(o, spans, starts, prefixes),
    ];
    text = newText;
    marks = outMarks;
    return mapped;
  }

  static bool _same(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  int _remap(int offset, List<RichLine> spans, List<int> starts, List<int> prefixes) {
    var i = 0;
    for (var k = 0; k < spans.length; k++) {
      if (spans[k].start <= offset) i = k;
    }
    final line = spans[i];
    final rel = offset - line.start;
    final newPrefix = prefixes[i];
    if (rel >= line.prefix) return starts[i] + newPrefix + (rel - line.prefix);
    return starts[i] + math.min(rel, newPrefix);
  }

  /// Puts the document right after an edit: numbered items count on from 1 in each run, a list item is never a
  /// heading, and a line is a heading all the way or not at all. Returns [offsets] moved through the change.
  List<int> normalise(List<int> offsets) {
    var n = 0;
    return rewriteLines(offsets, (i, line) {
      if (line.kind == RichLineKind.number) {
        n++;
        return (prefix: '$n. ', heading: false);
      }
      n = 0;
      if (line.kind == RichLineKind.bullet) return (prefix: bulletPrefix, heading: false);
      final heading = line.contentLength > 0 && (marks[line.start] & RichMark.heading) != 0;
      return (prefix: '', heading: heading);
    });
  }

  // --- marks ------------------------------------------------------------------------------------------------

  /// The stretches of [from, to) that are words: not a newline, not a list prefix.
  List<(int, int)> wordRanges(int from, int to) {
    final out = <(int, int)>[];
    for (final line in lines()) {
      final a = math.max(from, line.contentStart);
      final b = math.min(to, line.end);
      if (a < b) out.add((a, b));
    }
    return out;
  }

  /// Whether every word in [from, to) carries [bit] (false when there are none).
  bool allHave(int from, int to, int bit) {
    var any = false;
    for (final (a, b) in wordRanges(from, to)) {
      for (var k = a; k < b; k++) {
        any = true;
        if ((marks[k] & bit) == 0) return false;
      }
    }
    return any;
  }

  void setMark(int from, int to, int bit, bool on) {
    for (final (a, b) in wordRanges(from, to)) {
      for (var k = a; k < b; k++) {
        marks[k] = on ? marks[k] | bit : marks[k] & ~bit;
      }
    }
  }

  void setLink(int from, int to, String? href) {
    final id = href == null ? 0 : linkNumber(href);
    for (final (a, b) in wordRanges(from, to)) {
      for (var k = a; k < b; k++) {
        marks[k] = RichMark.withLink(marks[k], id);
      }
    }
  }

  /// The stretch of the link that holds [offset] (or the character before it), or null.
  (int, int)? linkRangeAt(int offset) {
    int? at;
    if (offset < text.length && text.codeUnitAt(offset) != 10 && RichMark.link(marks[offset]) > 0) {
      at = offset;
    } else if (offset > 0 && text.codeUnitAt(offset - 1) != 10 && RichMark.link(marks[offset - 1]) > 0) {
      at = offset - 1;
    }
    if (at == null) return null;
    final id = RichMark.link(marks[at]);
    var a = at;
    var b = at + 1;
    while (a > 0 && text.codeUnitAt(a - 1) != 10 && RichMark.link(marks[a - 1]) == id) {
      a--;
    }
    while (b < text.length && text.codeUnitAt(b) != 10 && RichMark.link(marks[b]) == id) {
      b++;
    }
    return (a, b);
  }

  String? hrefAt(int offset) {
    final range = linkRangeAt(offset);
    if (range == null) return null;
    final id = RichMark.link(marks[range.$1]);
    return id > 0 && id <= links.length ? links[id - 1] : null;
  }

  // --- the field's edits ------------------------------------------------------------------------------------

  /// Takes what the text field now holds. [newText] replaced the text; [base] and [extent] are its selection in
  /// the new text. The characters that changed are found, the marks follow them, a typed character takes the
  /// marks of its neighbours (and the toolbar's [pending] choices), and the list rules run: Enter in an item
  /// starts the next (or ends the list from an empty one), Backspace over a prefix removes all of it, and "- "
  /// at the start of a line becomes a bullet. At most [maxChars] words are kept. Returns the text and selection
  /// the field should now show.
  RichEdit applyEdit(String newText, int base, int extent, {required Map<int, bool> pending, required int maxChars}) {
    final old = text;
    var (start, oldEnd, newEnd) = _diff(old, newText, extent);
    var inserted = newText.substring(start, newEnd);
    var rewritten = false;
    var autoPrefix = 0;

    final lineStart = _lineStartOf(old, start);
    final prefix = prefixAt(old, lineStart);

    // Enter with the caret inside a marker acts at the end of it.
    if (inserted == '\n' && oldEnd == start && prefix > 0 && start > lineStart && start < lineStart + prefix) {
      start = oldEnd = lineStart + prefix;
    }

    if (inserted.isEmpty && oldEnd > start && prefix > 0) {
      // Backspace over a list prefix takes the whole of it.
      if (start >= lineStart && start < lineStart + prefix && oldEnd <= lineStart + prefix) {
        start = lineStart;
        oldEnd = lineStart + prefix;
        rewritten = true;
      }
    } else if (_endsWithOneNewline(inserted) && prefix > 0 && start >= lineStart + prefix) {
      // Enter, alone or with the word a keyboard just corrected before it ("one" becomes "One" and the line breaks).
      final head = inserted.substring(0, inserted.length - 1);
      if (head.isEmpty && oldEnd == start && _lineEndOf(old, start) == lineStart + prefix) {
        // Enter on an empty item ends the list.
        start = lineStart;
        oldEnd = lineStart + prefix;
        inserted = '';
      } else {
        final next = old.startsWith(bulletPrefix, lineStart)
            ? bulletPrefix
            : '${(int.tryParse(old.substring(lineStart, lineStart + prefix - 2)) ?? 0) + 1}. ';
        inserted = '$head\n$next';
        autoPrefix = next.length;
      }
      rewritten = true;
    } else if (inserted == ' ' &&
        oldEnd == start &&
        start == lineStart + 1 &&
        (old[lineStart] == '-' || old[lineStart] == '*') &&
        _lineEndOf(old, start) == start) {
      // "- " or "* " at the start of an empty line is a bullet.
      start = lineStart;
      oldEnd = lineStart + 1;
      inserted = bulletPrefix;
      autoPrefix = bulletPrefix.length;
      rewritten = true;
    }

    // The limit counts words; what does not fit is left off the end of what was typed.
    final before = old.substring(0, start);
    final after = old.substring(oldEnd);
    if (inserted.isNotEmpty && richPlainLength(before + inserted + after) > maxChars) {
      var lo = 0;
      var hi = inserted.length;
      while (lo < hi) {
        final mid = (lo + hi + 1) >> 1;
        if (richPlainLength(before + inserted.substring(0, mid) + after) <= maxChars) {
          lo = mid;
        } else {
          hi = mid - 1;
        }
      }
      inserted = inserted.substring(0, lo);
      autoPrefix = 0;
      rewritten = true;
    }
    String assembled() => before + inserted + after;

    final insertedMarks = _insertedMarks(
      old,
      inserted,
      start,
      oldEnd,
      lineStart + prefix,
      pending,
      autoPrefix,
    );
    final newMarks = <int>[...marks.sublist(0, start), ...insertedMarks, ...marks.sublist(oldEnd)];
    text = assembled();
    marks = newMarks;

    var offsets = rewritten ? [start + inserted.length, start + inserted.length] : [base, extent];
    offsets = normalise(offsets);
    final changed = rewritten || text != newText;
    return RichEdit(text, offsets[0], offsets[1], changed);
  }

  /// The marks for [inserted] going in at [start] (replacing up to [oldEnd]): the neighbours' bold and italic
  /// and the line's heading, a link only when both sides are in the same one, then the toolbar's choices.
  List<int> _insertedMarks(
    String old,
    String inserted,
    int start,
    int oldEnd,
    int contentStart,
    Map<int, bool> pending,
    int autoPrefix,
  ) {
    if (inserted.isEmpty) return const [];
    final prev = start > 0 && start - 1 >= contentStart && old.codeUnitAt(start - 1) != 10 ? marks[start - 1] : null;
    final next = oldEnd < old.length && old.codeUnitAt(oldEnd) != 10 ? marks[oldEnd] : null;
    // Words that replace others (a keyboard's correction) take the look of the ones they replace.
    final replaced = oldEnd > start && start >= contentStart && old.codeUnitAt(start) != 10 ? marks[start] : null;
    var base = (replaced ?? prev ?? next ?? 0) & (RichMark.inline | RichMark.heading);
    if (replaced != null) {
      if (RichMark.link(replaced) == RichMark.link(marks[oldEnd - 1])) {
        base = RichMark.withLink(base, RichMark.link(replaced));
      }
    } else if (prev != null && next != null && RichMark.link(prev) == RichMark.link(next)) {
      base = RichMark.withLink(base, RichMark.link(prev));
    }
    pending.forEach((bit, on) {
      base = on ? base | bit : base & ~bit;
    });
    if ((base & RichMark.heading) != 0) base &= ~RichMark.bold;
    final out = <int>[];
    var firstLine = true;
    var skipPrefix = 0;
    for (var i = 0; i < inserted.length; i++) {
      final c = inserted.codeUnitAt(i);
      if (c == 10) {
        out.add(0);
        firstLine = false;
        skipPrefix = autoPrefix;
        continue;
      }
      if (skipPrefix > 0) {
        out.add(0);
        skipPrefix--;
        continue;
      }
      out.add(firstLine ? base : base & ~RichMark.heading);
    }
    return out;
  }

  /// Where [a] became [b]: the first changed character, and where the change ends in each. [caret] (the new
  /// selection's end) says where a typed or deleted stretch finished, which settles repeated characters.
  static (int, int, int) _diff(String a, String b, int caret) {
    if (caret >= 0 && caret <= b.length) {
      final tail = b.substring(caret);
      if (tail.length <= a.length && a.endsWith(tail)) {
        final oldEnd = a.length - tail.length;
        var p = 0;
        final limit = math.min(oldEnd, caret);
        while (p < limit && a.codeUnitAt(p) == b.codeUnitAt(p)) {
          p++;
        }
        return (p, oldEnd, caret);
      }
    }
    var p = 0;
    final limit = math.min(a.length, b.length);
    while (p < limit && a.codeUnitAt(p) == b.codeUnitAt(p)) {
      p++;
    }
    var s = 0;
    while (s < limit - p && a.codeUnitAt(a.length - 1 - s) == b.codeUnitAt(b.length - 1 - s)) {
      s++;
    }
    return (p, a.length - s, b.length - s);
  }

  static bool _endsWithOneNewline(String s) => s.endsWith('\n') && s.indexOf('\n') == s.length - 1;

  static int _lineStartOf(String text, int offset) {
    if (offset <= 0) return 0;
    final i = text.lastIndexOf('\n', offset - 1);
    return i < 0 ? 0 : i + 1;
  }

  static int _lineEndOf(String text, int offset) {
    final i = text.indexOf('\n', offset);
    return i < 0 ? text.length : i;
  }
}

/// What the field should show after an edit, and whether it differs from what the field sent.
class RichEdit {
  const RichEdit(this.text, this.base, this.extent, this.changed);

  final String text;
  final int base;
  final int extent;

  /// The text is not the text the field sent (a list rule ran, the limit cut it, or a number was renumbered).
  final bool changed;
}
