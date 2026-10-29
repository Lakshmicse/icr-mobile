import 'dart:typed_data';

import 'cell_format.dart';
import 'cfb.dart';
import 'office_models.dart';
import 'text_codecs.dart';

/// An Excel 97 to 2003 workbook (`.xls`, BIFF8; Excel 5 and 95 text cells too) read for the viewer: each
/// worksheet as a grid of what its cells show. Formulas show their last result; charts, pictures and styling
/// are not shown.
SheetsPreview readXls(Cfb cfb) {
  final book = cfb.stream('Workbook') ?? cfb.stream('Book');
  if (book == null || !book.has(0, 4)) throw const OfficeProblem("This Excel file can't be read.");
  final w = _Workbook.read(book);
  final sheets = <SheetData>[];
  for (final s in w.sheets) {
    if (s.type != 0 || s.state == 2) continue; // worksheets only, and not the very hidden ones
    sheets.add(w.readSheet(book, s));
  }
  if (sheets.isEmpty) throw const OfficeProblem('This workbook has no sheets to show.');
  return SheetsPreview(sheets);
}

class _Rec {
  _Rec(this.type, this.at, this.length);

  final int type;

  /// Offset of the record's data.
  final int at;
  final int length;
}

class _Sheet {
  _Sheet(this.name, this.start, this.state, this.type);

  final String name;
  final int start;
  final int state;
  final int type;
}

const _bof = 0x0809;
const _eof = 0x000A;
const _continue = 0x003C;

class _Workbook {
  _Workbook(this.sheets, this.strings, this.xfFormats, this.date1904, this.biff5);

  final List<_Sheet> sheets;
  final List<String> strings;

  /// The number format of each XF (cell style), in file order.
  final List<CellFormat> xfFormats;
  final bool date1904;
  final bool biff5;

  static Iterable<_Rec> records(Uint8List b, int from) sync* {
    var o = from;
    while (b.has(o, 4)) {
      final type = b.u16(o);
      final len = b.u16(o + 2);
      if (!b.has(o + 4, len)) return;
      yield _Rec(type, o + 4, len);
      o += 4 + len;
    }
  }

  factory _Workbook.read(Uint8List b) {
    final sheets = <_Sheet>[];
    final custom = <int, CellFormat>{};
    final xfIds = <int>[];
    var strings = <String>[];
    var date1904 = false;
    var biff5 = false;
    var depth = 0;
    final recs = records(b, 0).toList();
    for (var i = 0; i < recs.length; i++) {
      final r = recs[i];
      switch (r.type) {
        case _bof:
          if (depth == 0 && b.has(r.at, 2)) biff5 = b.u16(r.at) == 0x0500;
          depth++;
        case _eof:
          depth--;
          if (depth <= 0) {
            return _Workbook(sheets, strings, _formats(xfIds, custom), date1904, biff5);
          }
        case 0x002F:
          throw const OfficeProblem("This workbook is password protected, so it can't be previewed.");
        case 0x0022:
          if (b.has(r.at, 2)) date1904 = b.u16(r.at) == 1;
        case 0x041E:
          if (b.has(r.at, 5)) {
            final id = b.u16(r.at);
            final code = _readString(b, r.at + 2, r.at + r.length, biff5);
            if (code != null) custom[id] = CellFormat.fromCode(code);
          }
        case 0x00E0:
          if (b.has(r.at, 4)) xfIds.add(b.u16(r.at + 2));
        case 0x0085:
          if (b.has(r.at, 8)) {
            final state = b.u8(r.at + 4);
            final type = b.u8(r.at + 5);
            final nameLen = b.u8(r.at + 6);
            var name = '';
            if (biff5) {
              final from = r.at + 7;
              if (b.has(from, nameLen)) name = decodeCp1252(b.sublist(from, from + nameLen));
            } else {
              final flags = b.u8(r.at + 7);
              final from = r.at + 8;
              final bytes = flags & 1 != 0 ? nameLen * 2 : nameLen;
              if (b.has(from, bytes)) {
                name = flags & 1 != 0
                    ? decodeUtf16le(b.sublist(from, from + bytes))
                    : decodeCp1252(b.sublist(from, from + bytes));
              }
            }
            sheets.add(_Sheet(name.isEmpty ? 'Sheet ${sheets.length + 1}' : name, b.u32(r.at), state, type));
          }
        case 0x00FC:
          // The shared string table, which may carry on in CONTINUE records.
          final chunks = <Uint8List>[b.sublist(r.at, r.at + r.length)];
          var j = i + 1;
          while (j < recs.length && recs[j].type == _continue) {
            chunks.add(b.sublist(recs[j].at, recs[j].at + recs[j].length));
            j++;
          }
          strings = _sharedStrings(chunks);
      }
    }
    return _Workbook(sheets, strings, _formats(xfIds, custom), date1904, biff5);
  }

  static List<CellFormat> _formats(List<int> xfIds, Map<int, CellFormat> custom) => [
    for (final id in xfIds) custom[id] ?? CellFormat.builtIn(id),
  ];

  SheetData readSheet(Uint8List b, _Sheet sheet) {
    final cells = <int, Map<int, String>>{};
    var truncated = false;
    var depth = 0;
    var started = false;
    int? pendingRow;
    int? pendingCol;

    void put(int row, int col, String text) {
      if (row >= OfficeLimits.maxRows || col >= OfficeLimits.maxColumns) {
        truncated = true;
        return;
      }
      if (text.isEmpty) return;
      (cells[row] ??= <int, String>{})[col] = text;
    }

    String number(double v, int xf) {
      final f = xf >= 0 && xf < xfFormats.length ? xfFormats[xf] : CellFormat.general;
      return f.format(v, date1904: date1904);
    }

    final recs = records(b, sheet.start);
    for (final r in recs) {
      if (r.type == _bof) {
        depth++;
        started = true;
        continue;
      }
      if (!started) return SheetData(sheet.name, const []);
      if (r.type == _eof) {
        depth--;
        if (depth <= 0) break;
        continue;
      }
      if (depth != 1) continue; // inside an embedded chart or macro sheet
      switch (r.type) {
        case 0x00FD: // LABELSST
          if (b.has(r.at, 10)) {
            final i = b.u32(r.at + 6);
            put(b.u16(r.at), b.u16(r.at + 2), i < strings.length ? strings[i] : '');
          }
        case 0x0203: // NUMBER
          if (b.has(r.at, 14)) put(b.u16(r.at), b.u16(r.at + 2), number(b.f64(r.at + 6), b.u16(r.at + 4)));
        case 0x027E: // RK
          if (b.has(r.at, 10)) put(b.u16(r.at), b.u16(r.at + 2), number(_rk(b.u32(r.at + 6)), b.u16(r.at + 4)));
        case 0x00BD: // MULRK
          if (b.has(r.at, 6)) {
            final row = b.u16(r.at);
            final first = b.u16(r.at + 2);
            final count = (r.length - 6) ~/ 6;
            for (var k = 0; k < count; k++) {
              final o = r.at + 4 + k * 6;
              put(row, first + k, number(_rk(b.u32(o + 2)), b.u16(o)));
            }
          }
        case 0x0204: // LABEL
          if (b.has(r.at, 8)) {
            final s = _readString(b, r.at + 6, r.at + r.length, biff5);
            if (s != null) put(b.u16(r.at), b.u16(r.at + 2), s);
          }
        case 0x0205: // BOOLERR
          if (b.has(r.at, 8)) {
            final v = b.u8(r.at + 6);
            put(b.u16(r.at), b.u16(r.at + 2), b.u8(r.at + 7) == 0 ? (v == 0 ? 'FALSE' : 'TRUE') : _error(v));
          }
        case 0x0006: // FORMULA
          if (b.has(r.at, 14)) {
            final row = b.u16(r.at);
            final col = b.u16(r.at + 2);
            if (b.u8(r.at + 12) == 0xFF && b.u8(r.at + 13) == 0xFF) {
              switch (b.u8(r.at + 6)) {
                case 0: // text, in the STRING record that follows
                  pendingRow = row;
                  pendingCol = col;
                case 1:
                  put(row, col, b.u8(r.at + 8) == 0 ? 'FALSE' : 'TRUE');
                case 2:
                  put(row, col, _error(b.u8(r.at + 8)));
              }
            } else {
              put(row, col, number(b.f64(r.at + 6), b.u16(r.at + 4)));
            }
          }
        case 0x0207: // STRING (the text result of the formula before it)
          if (pendingRow != null && pendingCol != null) {
            final s = _readString(b, r.at, r.at + r.length, biff5);
            if (s != null) put(pendingRow, pendingCol, s);
          }
          pendingRow = null;
          pendingCol = null;
      }
    }

    final rowIds = cells.keys.toList()..sort();
    final rows = <List<String>>[];
    if (rowIds.isNotEmpty) {
      final lastRow = rowIds.last;
      for (var r = 0; r <= lastRow; r++) {
        final row = cells[r];
        if (row == null) {
          rows.add(<String>[]);
          continue;
        }
        final lastCol = (row.keys.toList()..sort()).last;
        rows.add([for (var c = 0; c <= lastCol; c++) row[c] ?? '']);
      }
    }
    return SheetData(sheet.name, rows, truncated: truncated);
  }

  static String _error(int code) => switch (code) {
    0x00 => '#NULL!',
    0x07 => '#DIV/0!',
    0x0F => '#VALUE!',
    0x17 => '#REF!',
    0x1D => '#NAME?',
    0x24 => '#NUM!',
    0x2A => '#N/A',
    _ => '#ERROR',
  };

  /// An RK value: a 30-bit integer or the top 30 bits of a double, optionally divided by 100.
  static double _rk(int rk) {
    final div100 = rk & 1 != 0;
    final isInt = rk & 2 != 0;
    double v;
    if (isInt) {
      var n = rk >> 2;
      if (n & 0x20000000 != 0) n -= 0x40000000;
      v = n.toDouble();
    } else {
      final bytes = ByteData(8)..setUint32(4, rk & 0xFFFFFFFC, Endian.little);
      v = bytes.getFloat64(0, Endian.little);
    }
    return div100 ? v / 100 : v;
  }
}

/// A string at [from] holding a 16-bit length then (in BIFF8) a flags byte, or in Excel 5 just 8-bit
/// characters. [limit] is the end of the record.
String? _readString(Uint8List b, int from, int limit, bool biff5) {
  if (!b.has(from, 2)) return null;
  final cch = b.u16(from);
  if (biff5) {
    if (from + 2 + cch > limit) return null;
    return decodeCp1252(b.sublist(from + 2, from + 2 + cch));
  }
  if (!b.has(from + 2, 1)) return null;
  final flags = b.u8(from + 2);
  var o = from + 3;
  if (flags & 8 != 0) o += 2; // rich text run count
  if (flags & 4 != 0) o += 4; // phonetic data size
  final wideChars = flags & 1 != 0;
  final bytes = wideChars ? cch * 2 : cch;
  if (o + bytes > limit || !b.has(o, bytes)) return null;
  final raw = b.sublist(o, o + bytes);
  return wideChars ? decodeUtf16le(raw) : decodeCp1252(raw);
}

/// The strings of an SST record and the CONTINUE records after it. A string's characters may be split across
/// two records, and the part in the next record starts with its own flags byte saying 8-bit or 16-bit.
List<String> _sharedStrings(List<Uint8List> chunks) {
  final out = <String>[];
  var chunk = 0;
  var pos = 8; // after the two counts
  if (chunks.first.length < 8) return out;
  final unique = chunks.first.u32(4).clamp(0, 1000000);

  bool atEnd() => chunk >= chunks.length;

  // Moves to the next record when this one is used up.
  void settle() {
    while (chunk < chunks.length && pos >= chunks[chunk].length) {
      chunk++;
      pos = 0;
    }
  }

  int? byte() {
    settle();
    if (atEnd()) return null;
    return chunks[chunk][pos++];
  }

  int? u16() {
    final a = byte();
    final c = byte();
    return a == null || c == null ? null : a | (c << 8);
  }

  void skip(int n) {
    var left = n;
    while (left > 0) {
      settle();
      if (atEnd()) return;
      final take = (chunks[chunk].length - pos).clamp(0, left);
      pos += take;
      left -= take;
    }
  }

  for (var s = 0; s < unique; s++) {
    settle();
    if (atEnd()) break;
    final cch = u16();
    final flags = byte();
    if (cch == null || flags == null) break;
    var runs = 0;
    var ext = 0;
    if (flags & 8 != 0) runs = u16() ?? 0;
    if (flags & 4 != 0) {
      final lo = u16() ?? 0;
      final hi = u16() ?? 0;
      ext = lo | (hi << 16);
    }
    var wide = flags & 1 != 0;
    final text = StringBuffer();
    var remaining = cch;
    while (remaining > 0) {
      if (chunk < chunks.length && pos >= chunks[chunk].length) {
        // The characters carry on in the next record, which opens with a fresh flags byte.
        chunk++;
        pos = 0;
        if (atEnd()) break;
        wide = (chunks[chunk][pos++] & 1) != 0;
      }
      if (atEnd()) break;
      final data = chunks[chunk];
      final unit = wide ? 2 : 1;
      final fit = ((data.length - pos) ~/ unit).clamp(0, remaining);
      if (fit == 0) {
        pos = data.length;
        continue;
      }
      final slice = data.sublist(pos, pos + fit * unit);
      text.write(wide ? decodeUtf16le(slice) : decodeCp1252(slice));
      pos += fit * unit;
      remaining -= fit;
    }
    skip(runs * 4 + ext);
    out.add(text.toString());
  }
  return out;
}
