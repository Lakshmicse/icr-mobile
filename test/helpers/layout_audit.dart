import 'package:flutter/rendering.dart';

/// Looks over whatever is on screen for the ways a design's fixed numbers go wrong once the text is bigger than
/// they were drawn for (the app's 12 sp floor, 27 Oct 2026): text cut off by a box shorter than its lines, and
/// chips or other pieces set side by side at different heights, so a row reads crooked. Walks the render tree
/// directly, so it can run from a frame callback as well as inside a test.
///
/// Each finding is one line, `kind | where | detail`; an empty list means nothing was found.
List<String> layoutProblems() {
  final out = <String>[];
  for (final view in RendererBinding.instance.renderViews) {
    _walk(view, out);
  }
  return out;
}

void _walk(RenderObject node, List<String> out) {
  if (node is RenderParagraph) _clipped(node, out);
  if (node is RenderFlex && node.direction == Axis.horizontal) _crookedRow(node, out);
  if (node is RenderWrap && node.direction == Axis.horizontal) _crookedWrap(node, out);
  node.visitChildren((child) => _walk(child, out));
}

/// Text drawn in a box shorter than its own lines: Flutter clips it without a sound. An icon is a glyph from a
/// private-use code point drawn as text; its font's line height is not the icon's box, so it is left alone.
void _clipped(RenderParagraph p, List<String> out) {
  if (!p.hasSize || p.size.isEmpty) return;
  final text = p.text.toPlainText().trim();
  if (text.isEmpty || _isIcon(text)) return;
  final needed = p.getMaxIntrinsicHeight(p.size.width);
  if (needed - p.size.height > 0.5) {
    out.add(
      'clipped | ${_short(text)} | ${needed.toStringAsFixed(1)} needed, ${p.size.height.toStringAsFixed(1)} given',
    );
  }
}

bool _isIcon(String text) {
  if (text.runes.length != 1) return false;
  final c = text.runes.first;
  return (c >= 0xE000 && c <= 0xF8FF) || (c >= 0xF0000 && c <= 0x10FFFF);
}

/// A row whose pieces are not centred on each other and differ in height: a 24 dp chip beside a 30 dp one, a
/// label a few pixels above its neighbour. Rows that centre their children cannot be crooked; rows of tall
/// pieces (a photo beside two lines of text) are laid out from the top on purpose and are left alone.
void _crookedRow(RenderFlex row, List<String> out) {
  if (row.crossAxisAlignment == CrossAxisAlignment.center ||
      row.crossAxisAlignment == CrossAxisAlignment.stretch ||
      row.crossAxisAlignment == CrossAxisAlignment.baseline) {
    return;
  }
  final kids = _boxes(row);
  if (kids.length < 2) return;
  final heights = kids.map((k) => k.size.height).toList();
  final tallest = heights.reduce((a, b) => a > b ? a : b);
  final shortest = heights.reduce((a, b) => a < b ? a : b);
  if (tallest > 48 || tallest - shortest <= 3) return;
  // Only pieces a person reads as one line each: a chip, a word, an icon.
  if (!kids.every(_leafLike)) return;
  out.add(
    'crooked row | ${kids.map(_label).join(' · ')} | heights ${heights.map((h) => h.toStringAsFixed(0)).join('/')}',
  );
}

/// Chips in a Wrap of different heights, not centred on each other: each run is as tall as its tallest chip,
/// and the shorter ones sit at its top, so the line steps up and down.
void _crookedWrap(RenderWrap wrap, List<String> out) {
  if (wrap.crossAxisAlignment == WrapCrossAlignment.center) return;
  final kids = _boxes(wrap);
  if (kids.length < 2) return;
  final heights = kids.map((k) => k.size.height).toList();
  final tallest = heights.reduce((a, b) => a > b ? a : b);
  final shortest = heights.reduce((a, b) => a < b ? a : b);
  if (tallest > 64 || tallest - shortest <= 2) return;
  out.add(
    'uneven chips | ${kids.map(_label).join(' · ')} | heights ${heights.map((h) => h.toStringAsFixed(0)).join('/')}',
  );
}

List<RenderBox> _boxes(RenderObject parent) {
  final kids = <RenderBox>[];
  parent.visitChildren((c) {
    if (c is RenderBox && c.hasSize && !c.size.isEmpty) kids.add(c);
  });
  return kids;
}

/// Whether a piece reads as one line: it holds at most one paragraph, and that paragraph is one line tall.
bool _leafLike(RenderBox box) {
  var paragraphs = 0;
  var multiLine = false;
  void visit(RenderObject n) {
    if (n is RenderParagraph) {
      paragraphs++;
      if (n.hasSize && n.size.height > 1.6 * (n.text.style?.fontSize ?? 14) * (n.text.style?.height ?? 1.3)) {
        multiLine = true;
      }
    }
    n.visitChildren(visit);
  }

  visit(box);
  return paragraphs <= 1 && !multiLine;
}

String _label(RenderBox box) {
  String? found;
  void visit(RenderObject n) {
    if (found != null) return;
    if (n is RenderParagraph) {
      found = _short(n.text.toPlainText());
      return;
    }
    n.visitChildren(visit);
  }

  visit(box);
  return found ?? box.runtimeType.toString().replaceFirst('Render', '');
}

String _short(String text) {
  final t = text.replaceAll('\n', ' ').trim();
  return t.length > 40 ? '${t.substring(0, 40)}…' : t;
}
