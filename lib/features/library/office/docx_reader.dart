import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'office_models.dart';
import 'ooxml_xml.dart';

/// A Word 2007+ document (`.docx`) read for the viewer: headings, paragraphs with bold, italic and underline,
/// bullets and numbers, and tables, in reading order. Pictures show as "[Image]"; headers, footers, notes and
/// text boxes are left out.
WordPreview readDocx(Archive zip) {
  final doc = partXml(zip, 'word/document.xml');
  if (doc == null) throw const OfficeProblem("This Word file can't be read.");
  final body = kid(doc.rootElement, 'body');
  if (body == null) return const WordPreview([]);
  final reader = _DocxReader(_Styles.read(zip), _Numbering.read(zip));
  reader.blocks(body.children);
  return WordPreview(reader.out, truncated: reader.truncated);
}

class _StyleInfo {
  _StyleInfo(this.id, this.name, this.basedOn);

  final String id;
  final String name;
  final String? basedOn;
  int? outline;
  String? numId;
  int? ilvl;
}

class _Styles {
  _Styles(this._byId);

  final Map<String, _StyleInfo> _byId;

  static _Styles read(Archive zip) {
    final out = <String, _StyleInfo>{};
    final xml = partXml(zip, 'word/styles.xml');
    if (xml != null) {
      for (final s in kids(xml.rootElement, 'style')) {
        if (attr(s, 'type') != 'paragraph') continue;
        final id = attr(s, 'styleId');
        if (id == null) continue;
        final name = valOf(kid(s, 'name')) ?? id;
        final info = _StyleInfo(id, name, valOf(kid(s, 'basedOn')));
        final pPr = kid(s, 'pPr');
        if (pPr != null) {
          final o = kid(pPr, 'outlineLvl');
          if (o != null) info.outline = int.tryParse(attr(o, 'val') ?? '');
          final n = kid(pPr, 'numPr');
          if (n != null) {
            info.numId = valOf(kid(n, 'numId'));
            final il = kid(n, 'ilvl');
            if (il != null) info.ilvl = int.tryParse(attr(il, 'val') ?? '');
          }
        }
        out[id] = info;
      }
    }
    return _Styles(out);
  }

  /// The style and the ones it is based on, nearest first.
  Iterable<_StyleInfo> chain(String? id) sync* {
    var cur = id == null ? null : _byId[id];
    var guard = 0;
    while (cur != null && guard++ < 8) {
      yield cur;
      cur = cur.basedOn == null ? null : _byId[cur.basedOn];
    }
  }

  int headingOf(String? id) {
    for (final s in chain(id)) {
      final name = s.name.toLowerCase().replaceAll(' ', '');
      if (name == 'title') return WordParagraph.titleHeading;
      if (name == 'subtitle') return WordParagraph.subtitleHeading;
      final m = RegExp(r'^heading([1-9])$').firstMatch(name);
      if (m != null) return int.parse(m.group(1)!).clamp(1, 6);
      final o = s.outline;
      if (o != null && o >= 0 && o <= 8) return (o + 1).clamp(1, 6);
    }
    return 0;
  }

  (String? numId, int? ilvl) listOf(String? id) {
    String? numId;
    int? ilvl;
    for (final s in chain(id)) {
      numId ??= s.numId;
      ilvl ??= s.ilvl;
    }
    if (numId == null) {
      // The built-in list styles carry their numbering by name in files that do not spell it out.
      for (final s in chain(id)) {
        final name = s.name.toLowerCase();
        if (name.startsWith('list bullet')) return ('bullet', ilvl);
        if (name.startsWith('list number')) return ('number', ilvl);
      }
    }
    return (numId, ilvl);
  }
}

class _Level {
  _Level(this.format, this.start);

  final String format;
  final int start;
}

class _Numbering {
  _Numbering(this._abstract, this._nums);

  final Map<String, Map<int, _Level>> _abstract;
  final Map<String, String> _nums;

  static _Numbering read(Archive zip) {
    final abstract = <String, Map<int, _Level>>{};
    final nums = <String, String>{};
    final xml = partXml(zip, 'word/numbering.xml');
    if (xml != null) {
      for (final a in kids(xml.rootElement, 'abstractNum')) {
        final id = attr(a, 'abstractNumId');
        if (id == null) continue;
        final levels = <int, _Level>{};
        for (final l in kids(a, 'lvl')) {
          final il = int.tryParse(attr(l, 'ilvl') ?? '');
          if (il == null) continue;
          final fmt = valOf(kid(l, 'numFmt')) ?? 'decimal';
          final startEl = kid(l, 'start');
          levels[il] = _Level(fmt, int.tryParse(valOf(startEl) ?? '') ?? 1);
        }
        abstract[id] = levels;
      }
      for (final n in kids(xml.rootElement, 'num')) {
        final id = attr(n, 'numId');
        final a = kid(n, 'abstractNumId');
        final aid = valOf(a);
        if (id != null && aid != null) nums[id] = aid;
      }
    }
    return _Numbering(abstract, nums);
  }

  _Level? level(String numId, int ilvl) {
    final aid = _nums[numId];
    return aid == null ? null : _abstract[aid]?[ilvl];
  }
}

class _DocxReader {
  _DocxReader(this.styles, this.numbering);

  final _Styles styles;
  final _Numbering numbering;
  final out = <WordBlock>[];
  bool truncated = false;

  /// Counters per list and level, so a numbered list counts 1, 2, 3 and a deeper level starts again.
  final _counters = <String, List<int?>>{};

  bool get _full {
    if (out.length >= OfficeLimits.maxBlocks) truncated = true;
    return truncated;
  }

  void blocks(Iterable<XmlNode> children) {
    for (final n in children) {
      if (_full) return;
      if (n is! XmlElement) continue;
      switch (n.name.local) {
        case 'p':
          _paragraph(n);
        case 'tbl':
          _table(n);
        case 'sdt':
          final content = kid(n, 'sdtContent');
          if (content != null) blocks(content.children);
        case 'customXml' || 'ins' || 'smartTag':
          blocks(n.children);
      }
    }
  }

  void _paragraph(XmlElement p) {
    final pPr = kid(p, 'pPr');
    final styleId = pPr == null ? null : valOf(kid(pPr, 'pStyle'));
    var heading = styles.headingOf(styleId);
    final direct = pPr == null ? null : kid(pPr, 'outlineLvl');
    if (heading == 0 && direct != null) {
      final o = int.tryParse(attr(direct, 'val') ?? '');
      if (o != null && o >= 0 && o <= 5) heading = o + 1;
    }

    final runs = <WordRun>[];
    _runs(p, runs);
    final merged = _merge(runs);

    String? marker;
    var level = 0;
    final numPr = pPr == null ? null : kid(pPr, 'numPr');
    var (numId, ilvl) = styles.listOf(styleId);
    if (numPr != null) {
      final n = kid(numPr, 'numId');
      if (n != null) numId = attr(n, 'val');
      final l = kid(numPr, 'ilvl');
      if (l != null) ilvl = int.tryParse(attr(l, 'val') ?? '') ?? ilvl;
    }
    if (numId != null && numId != '0') {
      level = (ilvl ?? 0).clamp(0, 8);
      marker = _marker(numId, level);
    }

    // Consecutive empty paragraphs are one gap.
    final blank = merged.every((r) => r.text.trim().isEmpty);
    if (blank && marker == null) {
      if (out.isNotEmpty && out.last is WordParagraph && (out.last as WordParagraph).isBlank) return;
      if (out.isEmpty) return;
    }
    out.add(WordParagraph(merged, heading: heading, marker: marker, level: level));
  }

  String? _marker(String numId, int level) {
    if (numId == 'bullet') return '•';
    final lvl = numbering.level(numId, level);
    if (numId == 'number') return '${_next('number', level, 1)}.';
    if (lvl == null) return '•';
    switch (lvl.format) {
      case 'none':
        return null;
      case 'bullet':
        return const ['•', '◦', '▪'][level % 3];
      case 'lowerLetter':
        return '${_letters(_next(numId, level, lvl.start)).toLowerCase()}.';
      case 'upperLetter':
        return '${_letters(_next(numId, level, lvl.start))}.';
      case 'lowerRoman':
        return '${_roman(_next(numId, level, lvl.start)).toLowerCase()}.';
      case 'upperRoman':
        return '${_roman(_next(numId, level, lvl.start))}.';
      default:
        return '${_next(numId, level, lvl.start)}.';
    }
  }

  int _next(String numId, int level, int start) {
    final counters = _counters.putIfAbsent(numId, () => List<int?>.filled(9, null));
    final cur = counters[level];
    final next = cur == null ? start : cur + 1;
    counters[level] = next;
    for (var i = level + 1; i < counters.length; i++) {
      counters[i] = null;
    }
    return next;
  }

  static String _letters(int n) {
    if (n < 1) return 'A';
    var s = '';
    var x = n;
    while (x > 0) {
      x -= 1;
      s = String.fromCharCode(65 + x % 26) + s;
      x ~/= 26;
    }
    return s;
  }

  static String _roman(int n) {
    if (n < 1 || n > 3999) return '$n';
    const numerals = [
      (1000, 'M'),
      (900, 'CM'),
      (500, 'D'),
      (400, 'CD'),
      (100, 'C'),
      (90, 'XC'),
      (50, 'L'),
      (40, 'XL'),
      (10, 'X'),
      (9, 'IX'),
      (5, 'V'),
      (4, 'IV'),
      (1, 'I'),
    ];
    var s = '';
    var x = n;
    for (final (value, text) in numerals) {
      while (x >= value) {
        s += text;
        x -= value;
      }
    }
    return s;
  }

  /// The runs under [parent], in order, looking through links, insertions, content controls and smart tags.
  void _runs(XmlElement parent, List<WordRun> into) {
    for (final c in parent.childElements) {
      switch (c.name.local) {
        case 'r':
          _run(c, into);
        case 'hyperlink' || 'ins' || 'smartTag' || 'fldSimple' || 'customXml' || 'dir' || 'bdo':
          _runs(c, into);
        case 'sdt':
          final content = kid(c, 'sdtContent');
          if (content != null) _runs(content, into);
        // `del` (deleted by a tracked change) and everything else is left out.
      }
    }
  }

  void _run(XmlElement r, List<WordRun> into) {
    final rPr = kid(r, 'rPr');
    final bold = rPr != null && flagOn(kid(rPr, 'b'));
    final italic = rPr != null && flagOn(kid(rPr, 'i'));
    final underline = rPr != null && flagOn(kid(rPr, 'u'));
    final text = StringBuffer();
    void flush() {
      if (text.isEmpty) return;
      into.add(WordRun(text.toString(), bold: bold, italic: italic, underline: underline));
      text.clear();
    }

    for (final c in r.childElements) {
      switch (c.name.local) {
        case 't':
          text.write(c.innerText);
        case 'tab':
          text.write('\t');
        case 'br' || 'cr':
          if (attr(c, 'type') == 'page') {
            text.write('\n');
          } else {
            text.write('\n');
          }
        case 'noBreakHyphen':
          text.write('-');
        case 'sym':
          // A symbol-font bullet or arrow has no text to show.
          break;
        case 'drawing' || 'pict' || 'object':
          if (below(c, 'blip').isNotEmpty || below(c, 'imagedata').isNotEmpty) {
            flush();
            into.add(const WordRun('[Image]', italic: true, muted: true));
          }
      }
    }
    flush();
  }

  /// Neighbouring runs that look alike are one, so a paragraph is a few spans rather than hundreds.
  static List<WordRun> _merge(List<WordRun> runs) {
    final out = <WordRun>[];
    for (final r in runs) {
      if (out.isNotEmpty) {
        final last = out.last;
        if (last.bold == r.bold && last.italic == r.italic && last.underline == r.underline && last.muted == r.muted) {
          out[out.length - 1] = WordRun(
            last.text + r.text,
            bold: r.bold,
            italic: r.italic,
            underline: r.underline,
            muted: r.muted,
          );
          continue;
        }
      }
      out.add(r);
    }
    return out;
  }

  void _table(XmlElement tbl) {
    final rows = <List<String>>[];
    for (final tr in kids(tbl, 'tr')) {
      final cells = <String>[];
      for (final tc in tr.childElements) {
        if (tc.name.local != 'tc') continue;
        final lines = <String>[];
        for (final p in below(tc, 'p')) {
          final runs = <WordRun>[];
          _runs(p, runs);
          final line = runs.map((r) => r.text).join().trim();
          if (line.isNotEmpty) lines.add(line);
        }
        cells.add(lines.join('\n'));
      }
      if (cells.isNotEmpty) rows.add(cells);
    }
    if (rows.isNotEmpty) out.add(WordTable(rows));
  }
}
