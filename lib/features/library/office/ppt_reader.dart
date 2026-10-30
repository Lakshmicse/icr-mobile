import 'dart:typed_data';

import 'cfb.dart';
import 'office_models.dart';
import 'text_codecs.dart';

/// A PowerPoint 97 to 2003 presentation (`.ppt`) read for the viewer: each slide's title and text, in slide
/// order. Pictures, shapes, tables and speaker notes are not shown.
///
/// The "PowerPoint Document" stream is a tree of records (an 8-byte header, then a body that is either more
/// records or data). A file saved several times keeps its older versions in the stream, so the current deck is
/// found through the edit history ("Current User" -> UserEditAtom -> persist directory), which says where
/// the Document and each Slide container now are. Slide text sits in text atoms in two places: the slide list
/// kept for the whole deck, and the text boxes drawn on each slide. Both are read and a line found in both is
/// shown once.
SlidesPreview readPpt(Cfb cfb) {
  final b = cfb.stream('PowerPoint Document');
  if (b == null || !b.has(0, 8)) throw const OfficeProblem("This PowerPoint file can't be read.");

  // A password-protected deck says so in its "Current User" stream, and its text is scrambled.
  final user = cfb.stream('Current User');
  if (user != null && user.has(12, 4) && user.u32(12) == 0xF3D1C4DF) {
    throw const OfficeProblem("This presentation is password protected, so it can't be previewed.");
  }

  var perSlide = _currentDeck(cfb, b);
  perSlide ??= _scanDeck(b);

  final slides = <SlideData>[];
  for (var i = 0; i < perSlide.length && i < OfficeLimits.maxSlides; i++) {
    final title = <String>[];
    final lines = <SlideLine>[];
    final seen = <String>{};
    for (final t in perSlide[i]) {
      if (t.text.isEmpty || !seen.add(t.text)) continue;
      if (t.kind == 0 || t.kind == 6) {
        title.add(t.text);
      } else {
        lines.add(SlideLine(t.text));
      }
    }
    slides.add(SlideData(i + 1, title: title.join(' ').trim(), lines: lines));
  }
  if (slides.isEmpty) throw const OfficeProblem('This presentation has no slides to show.');
  return SlidesPreview(slides);
}

class _Text {
  _Text(this.text, this.kind);

  final String text;

  /// The TextHeaderAtom type: 0 title, 6 centred title, 1 body, 4 other...
  final int kind;
}

/// The deck as saved last: its slide list, then each slide's own container, found through the persist directory.
List<List<_Text>>? _currentDeck(Cfb cfb, Uint8List b) {
  final dir = _persistDirectory(cfb, b);
  if (dir == null) return null;
  final docAt = dir.offsets[dir.documentRef];
  if (docAt == null || !b.has(docAt, 8) || b.u16(docAt + 2) != 0x03E8) return null;
  final doc = _Walk(b)..run(docAt, _end(b, docAt), _Where.top, 0);
  if (doc.persistIds.isEmpty) return null;

  final out = <List<_Text>>[];
  for (var i = 0; i < doc.persistIds.length; i++) {
    final texts = <_Text>[...doc.list[i]];
    final at = dir.offsets[doc.persistIds[i]];
    if (at != null && b.has(at, 8) && b.u16(at + 2) == 0x03EE) {
      final slide = _Walk(b)..run(at, _end(b, at), _Where.top, 0);
      for (final box in slide.boxes) {
        texts.addAll(box);
      }
    }
    out.add(texts);
  }
  return out;
}

/// Where the record at [at] ends.
int _end(Uint8List b, int at) {
  final end = at + 8 + b.u32(at + 4);
  return end > b.length ? b.length : end;
}

/// Without an edit history, every slide container in the stream in file order.
List<List<_Text>> _scanDeck(Uint8List b) {
  final all = _Walk(b)..run(0, b.length, _Where.top, 0);
  final count = all.boxes.isNotEmpty ? all.boxes.length : all.list.length;
  return [
    for (var i = 0; i < count; i++)
      [if (i < all.list.length) ...all.list[i], if (i < all.boxes.length) ...all.boxes[i]],
  ];
}

class _Directory {
  _Directory(this.offsets, this.documentRef);

  /// Persist id to the offset of its record in the stream.
  final Map<int, int> offsets;
  final int documentRef;
}

_Directory? _persistDirectory(Cfb cfb, Uint8List b) {
  final user = cfb.stream('Current User');
  if (user == null || !user.has(0, 20)) return null;
  var edit = user.u32(16);
  final offsets = <int, int>{};
  int? documentRef;
  var guard = 0;
  // Each edit points at the one before it; what a later edit says wins.
  while (edit != 0 && guard++ < 1000) {
    if (!b.has(edit, 8 + 24) || b.u16(edit + 2) != 0x0FF5) break;
    final body = edit + 8;
    final previous = b.u32(body + 8);
    final directoryAt = b.u32(body + 12);
    documentRef ??= b.u32(body + 16);
    if (b.has(directoryAt, 8) && b.u16(directoryAt + 2) == 0x1772) {
      final end = _end(b, directoryAt);
      var o = directoryAt + 8;
      while (o + 4 <= end) {
        final head = b.u32(o);
        o += 4;
        final first = head & 0xFFFFF;
        final count = head >> 20;
        for (var i = 0; i < count && o + 4 <= end; i++, o += 4) {
          offsets.putIfAbsent(first + i, () => b.u32(o));
        }
      }
    }
    edit = previous;
  }
  if (documentRef == null || offsets.isEmpty) return null;
  return _Directory(offsets, documentRef);
}

enum _Where { top, slideList, slide, ignore }

class _Walk {
  _Walk(this.b);

  final Uint8List b;

  /// Text of each slide from the deck's slide list.
  final list = <List<_Text>>[];

  /// The persist id of each slide in that list, to find its container.
  final persistIds = <int>[];

  /// Text of each slide from the text boxes drawn on it.
  final boxes = <List<_Text>>[];

  int _kind = 4;

  void run(int start, int end, _Where where, int depth) {
    if (depth > 48) return; // a damaged file can nest records without end
    var o = start;
    while (o + 8 <= end) {
      final verInstance = b.u16(o);
      final type = b.u16(o + 2);
      final len = b.u32(o + 4);
      final body = o + 8;
      final bodyEnd = body + len > end ? end : body + len;
      final ver = verInstance & 0xF;
      final instance = verInstance >> 4;

      if (ver == 0xF) {
        var inner = where;
        switch (type) {
          case 0x0FF0: // SlideListWithText: instance 0 is the slides, 1 the masters, 2 the notes
            inner = instance == 0 ? _Where.slideList : _Where.ignore;
          case 0x03EE: // a slide
            boxes.add([]);
            inner = _Where.slide;
          case 0x03F8 || 0x03F0 || 0x0FC9: // a master, a notes page, the handouts
            inner = _Where.ignore;
        }
        run(body, bodyEnd, inner, depth + 1);
      } else {
        switch (where) {
          case _Where.slideList:
            _listAtom(type, body, bodyEnd);
          case _Where.slide:
            _boxAtom(type, body, bodyEnd);
          case _Where.top || _Where.ignore:
            break;
        }
      }
      o = bodyEnd;
    }
  }

  void _listAtom(int type, int body, int end) {
    switch (type) {
      case 0x03F3: // SlidePersistAtom: the next slide starts
        list.add([]);
        persistIds.add(b.has(body, 4) ? b.u32(body) : -1);
        _kind = 4;
      case 0x0F9F:
        if (b.has(body, 4)) _kind = b.u32(body);
      case 0x0FA0 || 0x0FA8:
        if (list.isNotEmpty) list.last.addAll(_texts(type, body, end));
    }
  }

  void _boxAtom(int type, int body, int end) {
    switch (type) {
      case 0x0F9F:
        if (b.has(body, 4)) _kind = b.u32(body);
      case 0x0FA0 || 0x0FA8:
        if (boxes.isNotEmpty) boxes.last.addAll(_texts(type, body, end));
        _kind = 4;
    }
  }

  List<_Text> _texts(int type, int body, int end) {
    final raw = b.sublist(body, end);
    final text = type == 0x0FA0 ? decodeUtf16le(raw) : decodeCp1252(raw);
    return [
      for (final line in text.split(RegExp(r'[\r\n]+')))
        if (line.replaceAll('\u000b', ' ').trim().isNotEmpty) _Text(line.replaceAll('\u000b', ' ').trim(), _kind),
    ];
  }
}
