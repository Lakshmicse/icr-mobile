import 'dart:typed_data';

import 'cfb.dart';
import 'office_models.dart';
import 'text_codecs.dart';

/// A Word 97 to 2003 document (`.doc`) read for the viewer: the body text in reading order, with tables as
/// rows of cells. Styles, pictures, headers, footnotes and text boxes are not shown.
///
/// The text is not stored in order in the file: a table in the "Table" stream (the CLX) lists pieces, each
/// saying where a run of characters sits in the "WordDocument" stream and whether it is 8-bit or UTF-16.
WordPreview readDoc(Cfb cfb) {
  final word = cfb.stream('WordDocument');
  if (word == null || !word.has(0, 0x200)) throw const OfficeProblem("This Word file can't be read.");
  final ident = word.u16(0);
  if (ident == 0xA5DC) return _word6(word);
  if (ident != 0xA5EC) {
    // Word 2 for Windows (1991) and anything else that only looks like a Word file.
    throw const OfficeProblem("This Word file is too old to preview.");
  }
  final flags = word.u16(0x0A);
  if (flags & 0x0100 != 0) {
    throw const OfficeProblem("This document is password protected, so it can't be previewed.");
  }

  // The FIB: a fixed header, then arrays of 16-bit values, 32-bit values and (offset, length) pairs.
  final csw = word.u16(0x20);
  final lwBase = 0x20 + 2 + csw * 2;
  final cslw = word.u16(lwBase);
  final ccpText = word.has(lwBase + 2 + 3 * 4, 4) ? word.i32(lwBase + 2 + 3 * 4) : 0;
  final pairsBase = lwBase + 2 + cslw * 4;
  final pairCount = word.u16(pairsBase);
  final clxAt = pairsBase + 2 + 33 * 8;

  String? text;
  if (pairCount > 33 && word.has(clxAt, 8)) {
    final table = cfb.stream((flags & 0x0200) != 0 ? '1Table' : '0Table');
    if (table != null) text = _pieces(word, table, word.u32(clxAt), word.u32(clxAt + 4), ccpText);
  }
  // A file saved without a piece table keeps its text in one run between two offsets in the header.
  text ??= _plainRun(word, ccpText);
  if (text == null) throw const OfficeProblem("This Word file can't be read.");
  return _blocks(text);
}

/// Word 6 and Word 95: no piece table, the text is one run of 8-bit characters between two offsets in the header.
WordPreview _word6(Uint8List word) {
  if (word.u16(0x0A) & 0x0100 != 0) {
    throw const OfficeProblem("This document is password protected, so it can't be previewed.");
  }
  final text = _plainRun(word, word.has(0x34, 4) ? word.u32(0x34) : 0);
  if (text == null) throw const OfficeProblem("This Word file can't be read.");
  return _blocks(text);
}

/// The first [ccp] characters of the pieces listed by the CLX at [fcClx].
String? _pieces(Uint8List word, Uint8List table, int fcClx, int lcbClx, int ccp) {
  if (lcbClx == 0 || !table.has(fcClx, lcbClx)) return null;
  var o = fcClx;
  final end = fcClx + lcbClx;
  // Property modifiers (type 1) come first and are skipped; the piece table (type 2) follows.
  while (o < end && table[o] == 0x01) {
    if (!table.has(o + 1, 2)) return null;
    o += 3 + table.u16(o + 1);
  }
  if (o >= end || table[o] != 0x02 || !table.has(o + 1, 4)) return null;
  final size = table.u32(o + 1);
  final plc = o + 5;
  if (size < 4 || !table.has(plc, size)) return null;
  final n = (size - 4) ~/ 12;
  if (n <= 0) return null;
  final pcd = plc + (n + 1) * 4;
  final out = StringBuffer();
  var taken = 0;
  for (var i = 0; i < n && (ccp <= 0 || taken < ccp); i++) {
    final from = table.u32(plc + i * 4);
    final to = table.u32(plc + (i + 1) * 4);
    var count = to - from;
    if (count <= 0) continue;
    if (ccp > 0 && taken + count > ccp) count = ccp - taken;
    final fc = table.u32(pcd + i * 8 + 2);
    final compressed = fc & 0x40000000 != 0;
    final offset = compressed ? (fc & 0x3FFFFFFF) ~/ 2 : fc;
    final bytes = compressed ? count : count * 2;
    if (!word.has(offset, bytes)) {
      // A piece running past the end of the stream: take what is there.
      if (offset >= word.length) break;
      final available = word.length - offset;
      out.write(
        compressed
            ? decodeCp1252(word.sublist(offset, offset + available))
            : decodeUtf16le(word.sublist(offset, offset + (available & ~1))),
      );
      break;
    }
    final slice = word.sublist(offset, offset + bytes);
    out.write(compressed ? decodeCp1252(slice) : decodeUtf16le(slice));
    taken += count;
  }
  return out.toString();
}

String? _plainRun(Uint8List word, int ccp) {
  if (!word.has(0x18, 8)) return null;
  final min = word.u32(0x18);
  final max = word.u32(0x1C);
  if (max <= min || min >= word.length) return null;
  final to = max > word.length ? word.length : max;
  return decodeCp1252(word.sublist(min, ccp > 0 && min + ccp < to ? min + ccp : to));
}

/// Word's control characters made into paragraphs and table rows.
WordPreview _blocks(String text) {
  final out = <WordBlock>[];
  var truncated = false;
  final line = StringBuffer();
  var cells = <String>[];
  var tableRows = <List<String>>[];
  var fields = <bool>[]; // true while inside a field's instruction, whose text is not for the reader
  var lastWasCellMark = false;

  void flushTable() {
    if (tableRows.isNotEmpty) out.add(WordTable(tableRows));
    tableRows = <List<String>>[];
  }

  void endParagraph() {
    final t = line.toString();
    line.clear();
    flushTable();
    if (t.trim().isEmpty) {
      if (out.isNotEmpty && !(out.last is WordParagraph && (out.last as WordParagraph).isBlank)) {
        out.add(const WordParagraph([]));
      }
      return;
    }
    out.add(WordParagraph([WordRun(t)]));
  }

  for (var i = 0; i < text.length; i++) {
    if (out.length >= OfficeLimits.maxBlocks) {
      truncated = true;
      break;
    }
    final c = text.codeUnitAt(i);
    switch (c) {
      case 0x13:
        fields.add(true);
        continue;
      case 0x14:
        if (fields.isNotEmpty) fields[fields.length - 1] = false;
        continue;
      case 0x15:
        if (fields.isNotEmpty) fields.removeLast();
        continue;
    }
    if (fields.contains(true)) continue;
    if (c == 0x07) {
      if (lastWasCellMark) {
        // A second mark in a row ends the row.
        if (cells.isNotEmpty) tableRows.add(cells);
        cells = <String>[];
        lastWasCellMark = false;
      } else {
        cells.add(line.toString().trim());
        line.clear();
        lastWasCellMark = true;
      }
      continue;
    }
    lastWasCellMark = false;
    switch (c) {
      case 0x0D || 0x0C:
        endParagraph();
      case 0x0B:
        line.write('\n');
      case 0x09:
        line.write('\t');
      case 0x1E:
        line.write('-');
      case 0x01 || 0x08:
        break; // a picture or drawn object: nothing to read
      default:
        if (c >= 0x20) line.writeCharCode(c);
    }
  }
  if (line.toString().trim().isNotEmpty) endParagraph();
  flushTable();
  while (out.isNotEmpty && out.last is WordParagraph && (out.last as WordParagraph).isBlank) {
    out.removeLast();
  }
  if (out.isEmpty) {
    throw const OfficeProblem('This document has no text to show. Pictures and drawings are not previewed.');
  }
  return WordPreview(out, truncated: truncated);
}
