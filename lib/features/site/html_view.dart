import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/config.dart';
import '../../core/theme/app_colors.dart';
import 'site_kit.dart';

/// A small renderer for the rich text the website stores (a blog post's body): paragraphs, headings, lists,
/// quotes, links, bold, italics, line breaks and pictures. Anything else is read as its text. No web view and no
/// package: the words are the app's own widgets, in the app's type.
class HtmlView extends StatefulWidget {
  const HtmlView({super.key, required this.html, this.onLink});

  final String html;

  /// A link in the text was pressed: its address as written.
  final void Function(String href)? onLink;

  @override
  State<HtmlView> createState() => _HtmlViewState();
}

class _HtmlViewState extends State<HtmlView> {
  final _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
    final blocks = parseHtml(widget.html);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final b in blocks) _block(b)]);
  }

  Widget _block(HtmlBlock b) {
    switch (b.kind) {
      case HtmlBlockKind.heading:
        return Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text.rich(_span(b.inline, b.level <= 2 ? SiteText.heading : SiteText.subheading)),
        );
      case HtmlBlockKind.image:
        final url = AppConfig.absoluteUrl(b.src);
        if (url == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Image.network(url, fit: BoxFit.fitWidth, errorBuilder: (_, _, _) => const SizedBox.shrink()),
        );
      case HtmlBlockKind.quote:
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.only(left: 12),
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: SiteColors.hairline, width: 3)),
          ),
          child: Text.rich(_span(b.inline, SiteText.secondary)),
        );
      case HtmlBlockKind.listItem:
        return Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 24, child: Text(b.ordered ? '${b.index}.' : '•', style: SiteText.body)),
              Expanded(child: Text.rich(_span(b.inline, SiteText.body))),
            ],
          ),
        );
      case HtmlBlockKind.paragraph:
        return Padding(padding: const EdgeInsets.only(bottom: 10), child: Text.rich(_span(b.inline, SiteText.body)));
    }
  }

  TextSpan _span(List<HtmlRun> runs, TextStyle base) => TextSpan(
    children: [
      for (final r in runs)
        TextSpan(
          text: r.text,
          style: base.copyWith(
            fontWeight: r.bold ? FontWeight.w700 : null,
            fontStyle: r.italic ? FontStyle.italic : null,
            color: r.href != null ? AppColors.primary : null,
          ),
          recognizer: r.href == null || widget.onLink == null ? null : _tap(r.href!),
        ),
    ],
  );

  TapGestureRecognizer _tap(String href) {
    final r = TapGestureRecognizer()..onTap = () => widget.onLink?.call(href);
    _recognizers.add(r);
    return r;
  }
}

enum HtmlBlockKind { paragraph, heading, listItem, quote, image }

class HtmlRun {
  const HtmlRun(this.text, {this.bold = false, this.italic = false, this.href});

  final String text;
  final bool bold;
  final bool italic;
  final String? href;
}

class HtmlBlock {
  const HtmlBlock(this.kind, this.inline, {this.level = 0, this.ordered = false, this.index = 0, this.src});

  final HtmlBlockKind kind;
  final List<HtmlRun> inline;
  final int level;
  final bool ordered;
  final int index;
  final String? src;
}

final _tag = RegExp(r'<(/?)([a-zA-Z][a-zA-Z0-9]*)([^>]*)>', dotAll: true);

String _decode(String s) => s
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&apos;', "'")
    .replaceAll('&rsquo;', '’')
    .replaceAll('&lsquo;', '‘')
    .replaceAll('&mdash;', '—')
    .replaceAll('&ndash;', '–')
    .replaceAll('&hellip;', '…');

String? _attr(String attrs, String name) {
  final m = RegExp('$name\\s*=\\s*("([^"]*)"|\'([^\']*)\')', caseSensitive: false).firstMatch(attrs);
  return m == null ? null : (m.group(2) ?? m.group(3));
}

/// The blocks of [html], in order. A text with no tags at all is one paragraph per blank-line-separated chunk.
List<HtmlBlock> parseHtml(String html) {
  if (!html.contains('<')) {
    return [
      for (final chunk in html.split(RegExp(r'\n\s*\n')))
        if (chunk.trim().isNotEmpty) HtmlBlock(HtmlBlockKind.paragraph, [HtmlRun(_decode(chunk.trim()))]),
    ];
  }
  final blocks = <HtmlBlock>[];
  var runs = <HtmlRun>[];
  var bold = 0;
  var italic = 0;
  String? href;
  var kind = HtmlBlockKind.paragraph;
  var level = 0;
  var inList = <String>[];
  var listIndex = <int>[];
  var inQuote = 0;

  void flush() {
    final trimmed = [
      for (final r in runs)
        if (r.text.isNotEmpty) r,
    ];
    final hasText = trimmed.any((r) => r.text.trim().isNotEmpty);
    if (hasText) {
      final ordered = inList.isNotEmpty && inList.last == 'ol';
      blocks.add(
        HtmlBlock(
          kind == HtmlBlockKind.paragraph && inQuote > 0 ? HtmlBlockKind.quote : kind,
          trimmed,
          level: level,
          ordered: ordered,
          index: ordered ? listIndex.last : 0,
        ),
      );
    }
    runs = [];
    kind = HtmlBlockKind.paragraph;
    level = 0;
  }

  void text(String raw) {
    final t = _decode(raw.replaceAll(RegExp(r'\s+'), ' '));
    if (t.trim().isEmpty && runs.isEmpty) return;
    runs.add(HtmlRun(t, bold: bold > 0, italic: italic > 0, href: href));
  }

  var pos = 0;
  for (final m in _tag.allMatches(html)) {
    if (m.start > pos) text(html.substring(pos, m.start));
    pos = m.end;
    final closing = m.group(1) == '/';
    final name = m.group(2)!.toLowerCase();
    final attrs = m.group(3) ?? '';
    switch (name) {
      case 'p':
      case 'div':
        flush();
      case 'br':
        runs.add(const HtmlRun('\n'));
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        flush();
        if (!closing) {
          kind = HtmlBlockKind.heading;
          level = int.parse(name.substring(1));
        }
      case 'ul':
      case 'ol':
        flush();
        if (closing) {
          if (inList.isNotEmpty) {
            inList.removeLast();
            listIndex.removeLast();
          }
        } else {
          inList = [...inList, name];
          listIndex = [...listIndex, 0];
        }
      case 'li':
        flush();
        if (!closing && inList.isNotEmpty) {
          listIndex[listIndex.length - 1] = listIndex.last + 1;
          kind = HtmlBlockKind.listItem;
        }
      case 'blockquote':
        flush();
        inQuote += closing ? -1 : 1;
        if (inQuote < 0) inQuote = 0;
      case 'strong':
      case 'b':
        bold += closing ? -1 : 1;
        if (bold < 0) bold = 0;
      case 'em':
      case 'i':
        italic += closing ? -1 : 1;
        if (italic < 0) italic = 0;
      case 'a':
        href = closing ? null : _attr(attrs, 'href');
      case 'img':
        flush();
        final src = _attr(attrs, 'src');
        if (src != null) blocks.add(HtmlBlock(HtmlBlockKind.image, const [], src: src));
      case 'script':
      case 'style':
        // Skip to the closing tag: its content is not text.
        if (!closing) {
          final end = html.toLowerCase().indexOf('</$name>', pos);
          if (end != -1) pos = end;
        }
    }
  }
  if (pos < html.length) text(html.substring(pos));
  flush();
  return blocks;
}
