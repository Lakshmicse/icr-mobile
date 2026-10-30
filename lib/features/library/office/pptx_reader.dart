import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'office_models.dart';
import 'ooxml_xml.dart';

/// A PowerPoint 2007+ presentation (`.pptx`) read for the viewer: each slide's title and text, and the cells
/// of its tables, in slide order. Pictures, charts, shapes and speaker notes are not shown.
SlidesPreview readPptx(Archive zip) {
  final pres = partXml(zip, 'ppt/presentation.xml');
  if (pres == null) throw const OfficeProblem("This PowerPoint file can't be read.");
  final rels = relationships(zip, 'ppt/presentation.xml');

  final paths = <String>[];
  final list = kid(pres.rootElement, 'sldIdLst');
  if (list != null) {
    for (final id in kids(list, 'sldId')) {
      final target = rels[attr(id, 'id') ?? ''];
      if (target != null) paths.add(target);
    }
  }
  if (paths.isEmpty) {
    // No slide list: the slides in the order of their numbers.
    final found = [
      for (final f in zip.files)
        if (f.isFile && RegExp(r'^ppt/slides/slide\d+\.xml$', caseSensitive: false).hasMatch(f.name)) f.name,
    ]..sort((a, b) => _number(a).compareTo(_number(b)));
    paths.addAll(found);
  }

  final slides = <SlideData>[];
  for (final path in paths.take(OfficeLimits.maxSlides)) {
    final xml = partXml(zip, path);
    if (xml == null) continue;
    slides.add(_slide(xml.rootElement, slides.length + 1));
  }
  if (slides.isEmpty) throw const OfficeProblem('This presentation has no slides to show.');
  return SlidesPreview(slides);
}

int _number(String path) => int.tryParse(RegExp(r'(\d+)\.xml$').firstMatch(path)?.group(1) ?? '') ?? 0;

SlideData _slide(XmlElement root, int number) {
  final tree = kid(kid(root, 'cSld') ?? root, 'spTree');
  final title = <String>[];
  final lines = <SlideLine>[];
  if (tree != null) _shapes(tree, title, lines);
  return SlideData(number, title: title.join(' ').trim(), lines: lines);
}

void _shapes(XmlElement parent, List<String> title, List<SlideLine> lines) {
  for (final c in parent.childElements) {
    switch (c.name.local) {
      case 'sp':
        final ph = _placeholder(c);
        if (ph == 'sldNum' || ph == 'dt' || ph == 'ftr' || ph == 'hdr') break;
        final body = kid(c, 'txBody');
        if (body == null) break;
        for (final p in kids(body, 'p')) {
          final text = _paragraph(p);
          if (text.isEmpty) continue;
          if (ph == 'title' || ph == 'ctrTitle') {
            title.add(text);
          } else {
            lines.add(SlideLine(text, level: (int.tryParse(attr(kid(p, 'pPr') ?? p, 'lvl') ?? '') ?? 0).clamp(0, 6)));
          }
        }
      case 'grpSp':
        _shapes(c, title, lines);
      case 'graphicFrame':
        for (final tbl in below(c, 'tbl')) {
          for (final tr in kids(tbl, 'tr')) {
            final cells = [
              for (final tc in kids(tr, 'tc'))
                [for (final p in below(tc, 'p')) _paragraph(p)].where((t) => t.isNotEmpty).join(' '),
            ];
            if (cells.any((t) => t.isNotEmpty)) lines.add(SlideLine(cells.join('  |  ')));
          }
        }
    }
  }
}

String? _placeholder(XmlElement sp) {
  final nv = kid(sp, 'nvSpPr');
  final nvPr = nv == null ? null : kid(nv, 'nvPr');
  final ph = nvPr == null ? null : kid(nvPr, 'ph');
  if (ph == null) return null;
  return attr(ph, 'type') ?? 'body';
}

String _paragraph(XmlElement p) {
  final b = StringBuffer();
  for (final c in p.childElements) {
    switch (c.name.local) {
      case 'r' || 'fld':
        for (final t in kids(c, 't')) {
          b.write(t.innerText);
        }
      case 'br':
        b.write(' ');
    }
  }
  return b.toString().trim();
}
