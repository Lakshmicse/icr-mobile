import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Builders for the files the Digital Library previews, written byte by byte so a test controls exactly what
/// is in them: the old compound file ("OLE") container that holds .doc, .xls and .ppt, and the records inside
/// each. They follow MS-CFB, MS-DOC, MS-XLS and MS-PPT closely enough for the app's readers; the readers were
/// also run against real Word, Excel and PowerPoint files while they were written.

class Bytes {
  final _b = BytesBuilder();

  int get length => _b.length;

  Bytes u8(int v) {
    _b.addByte(v & 0xFF);
    return this;
  }

  Bytes u16(int v) {
    _b.add([v & 0xFF, (v >> 8) & 0xFF]);
    return this;
  }

  Bytes u32(int v) {
    _b.add([v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF]);
    return this;
  }

  Bytes f64(double v) {
    final d = ByteData(8)..setFloat64(0, v, Endian.little);
    _b.add(d.buffer.asUint8List());
    return this;
  }

  Bytes raw(List<int> bytes) {
    _b.add(bytes);
    return this;
  }

  Bytes zeros(int n) {
    _b.add(Uint8List(n));
    return this;
  }

  Bytes ascii(String s) {
    _b.add(latin1.encode(s));
    return this;
  }

  Bytes utf16(String s) {
    for (final c in s.codeUnits) {
      u16(c);
    }
    return this;
  }

  Uint8List toBytes() => _b.toBytes();
}

// ---------------------------------------------------------------------------
// Compound file
// ---------------------------------------------------------------------------

/// A compound file holding [streams] (name to bytes) at the root. Streams under 4096 bytes live in the mini
/// stream and the rest in ordinary sectors, as in real files.
Uint8List buildCfb(Map<String, Uint8List> streams) {
  const sector = 512;
  const miniSector = 64;
  const endOfChain = 0xFFFFFFFE;
  const free = 0xFFFFFFFF;
  const fatSector = 0xFFFFFFFD;

  int sectorsFor(int bytes, int size) => (bytes + size - 1) ~/ size;

  // The mini stream and its allocation table.
  final mini = Bytes();
  final miniFat = <int>[];
  final starts = <String, int>{};
  streams.forEach((name, data) {
    if (data.length >= 4096 || data.isEmpty) return;
    final n = sectorsFor(data.length, miniSector);
    starts[name] = miniFat.length;
    for (var i = 0; i < n; i++) {
      miniFat.add(i == n - 1 ? endOfChain : miniFat.length + 1);
    }
    mini.raw(data).zeros(n * miniSector - data.length);
  });
  final miniBytes = mini.toBytes();

  // Plan the sectors: FAT, directory, mini FAT, mini stream, then each big stream.
  final entryCount = 1 + streams.length;
  final dirSectors = sectorsFor(entryCount * 128, sector);
  final miniFatSectors = miniFat.isEmpty ? 0 : sectorsFor(miniFat.length * 4, sector);
  final miniStreamSectors = sectorsFor(miniBytes.length, sector);
  final big = <String, int>{};
  var bigSectors = 0;
  streams.forEach((name, data) {
    if (data.length >= 4096) {
      big[name] = sectorsFor(data.length, sector);
      bigSectors += big[name]!;
    }
  });
  final others = dirSectors + miniFatSectors + miniStreamSectors + bigSectors;
  var fatCount = 1;
  while (fatCount * 128 < others + fatCount) {
    fatCount++;
  }
  final total = fatCount + others;

  final fat = List<int>.filled(fatCount * 128, free);
  var next = 0;
  void chain(int count) {
    for (var i = 0; i < count; i++) {
      fat[next + i] = i == count - 1 ? endOfChain : next + i + 1;
    }
    next += count;
  }

  for (var i = 0; i < fatCount; i++) {
    fat[next++] = fatSector;
  }
  final firstDir = next;
  chain(dirSectors);
  final firstMiniFat = miniFatSectors == 0 ? endOfChain : next;
  if (miniFatSectors > 0) chain(miniFatSectors);
  final miniStreamStart = miniStreamSectors == 0 ? endOfChain : next;
  if (miniStreamSectors > 0) chain(miniStreamSectors);
  final bigStart = <String, int>{};
  big.forEach((name, n) {
    bigStart[name] = next;
    chain(n);
  });
  assert(next == total);

  // Header.
  final h = Bytes()
    ..raw([0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1])
    ..zeros(16)
    ..u16(0x003E)
    ..u16(0x0003)
    ..u16(0xFFFE)
    ..u16(9)
    ..u16(6)
    ..zeros(6)
    ..u32(0) // directory sector count (version 3: zero)
    ..u32(fatCount)
    ..u32(firstDir)
    ..u32(0)
    ..u32(4096)
    ..u32(firstMiniFat)
    ..u32(miniFatSectors)
    ..u32(endOfChain)
    ..u32(0);
  for (var i = 0; i < 109; i++) {
    h.u32(i < fatCount ? i : free);
  }

  // Directory.
  Uint8List entry(String name, int type, int start, int size, {int right = free}) {
    final e = Bytes();
    final units = name.codeUnits;
    for (var i = 0; i < 32; i++) {
      e.u16(i < units.length ? units[i] : 0);
    }
    e
      ..u16(name.isEmpty ? 0 : (units.length + 1) * 2)
      ..u8(type)
      ..u8(1)
      ..u32(free) // left
      ..u32(right)
      ..u32(free) // child
      ..zeros(16) // CLSID
      ..u32(0)
      ..zeros(16) // times
      ..u32(start)
      ..u32(size)
      ..u32(0);
    return e.toBytes();
  }

  final dir = Bytes();
  dir.raw(entry('Root Entry', 5, miniStreamStart, miniBytes.length));
  var i = 0;
  streams.forEach((name, data) {
    final isBig = data.length >= 4096;
    final start = data.isEmpty ? endOfChain : (isBig ? bigStart[name]! : starts[name]!);
    dir.raw(entry(name, 2, start, data.length, right: i + 1 < streams.length ? i + 2 : free));
    i++;
  });
  final dirBytes = dir.toBytes();

  // Put it together.
  final out = Bytes()..raw(h.toBytes());
  for (final v in fat) {
    out.u32(v);
  }
  out.raw(dirBytes).zeros(dirSectors * sector - dirBytes.length);
  if (miniFatSectors > 0) {
    final mf = Bytes();
    for (final v in miniFat) {
      mf.u32(v);
    }
    final bytes = mf.toBytes();
    out.raw(bytes).zeros(miniFatSectors * sector - bytes.length);
  }
  if (miniStreamSectors > 0) out.raw(miniBytes).zeros(miniStreamSectors * sector - miniBytes.length);
  streams.forEach((name, data) {
    if (data.length < 4096) return;
    out.raw(data).zeros(big[name]! * sector - data.length);
  });
  return out.toBytes();
}

// ---------------------------------------------------------------------------
// Word 97 to 2003
// ---------------------------------------------------------------------------

/// A .doc whose text is [pieces]: each piece is stored 8-bit (Windows-1252) or UTF-16 in the order given.
/// [encrypted] sets the file's encryption flag.
Uint8List buildDoc(List<(String text, bool unicode)> pieces, {bool encrypted = false}) {
  const textAt = 0x400;
  final text = Bytes();
  final offsets = <int>[];
  final lengths = <int>[];
  for (final (t, unicode) in pieces) {
    offsets.add(textAt + text.length);
    lengths.add(t.length);
    if (unicode) {
      text.utf16(t);
    } else {
      text.raw(t.codeUnits.map((c) => c & 0xFF).toList());
    }
  }
  final ccpText = lengths.fold<int>(0, (a, b) => a + b);

  // The piece table in the 1Table stream.
  final plc = Bytes();
  var cp = 0;
  plc.u32(0);
  for (final n in lengths) {
    cp += n;
    plc.u32(cp);
  }
  for (var i = 0; i < pieces.length; i++) {
    final fc = pieces[i].$2 ? offsets[i] : ((offsets[i] * 2) | 0x40000000);
    plc.u16(0).u32(fc).u16(0);
  }
  final plcBytes = plc.toBytes();
  final clx = Bytes()
    ..u8(0x02)
    ..u32(plcBytes.length)
    ..raw(plcBytes);
  final clxBytes = clx.toBytes();
  final table = Bytes()
    ..zeros(16)
    ..raw(clxBytes);

  // The FIB.
  final fib = Uint8List(textAt + text.length + 16);
  final d = ByteData.sublistView(fib);
  d.setUint16(0, 0xA5EC, Endian.little);
  d.setUint16(2, 0x00C1, Endian.little);
  d.setUint16(0x0A, 0x0200 | (encrypted ? 0x0100 : 0), Endian.little); // uses 1Table
  d.setUint16(0x20, 14, Endian.little); // csw
  final lwBase = 0x20 + 2 + 14 * 2;
  d.setUint16(lwBase, 22, Endian.little); // cslw
  d.setInt32(lwBase + 2 + 12, ccpText, Endian.little); // ccpText
  final pairsBase = lwBase + 2 + 22 * 4;
  d.setUint16(pairsBase, 93, Endian.little); // cbRgFcLcb
  final clxAt = pairsBase + 2 + 33 * 8;
  d.setUint32(clxAt, 16, Endian.little); // fcClx
  d.setUint32(clxAt + 4, clxBytes.length, Endian.little); // lcbClx
  d.setUint32(0x18, textAt, Endian.little); // fcMin
  d.setUint32(0x1C, textAt + text.length, Endian.little); // fcMac
  fib.setRange(textAt, textAt + text.length, text.toBytes());

  final tableBytes = table.toBytes();
  return buildCfb({
    'WordDocument': fib,
    '1Table': Uint8List.fromList([...tableBytes, ...Uint8List(4096)]), // padded so it is a regular sector stream
  });
}

/// A Word 6/95 file: one run of 8-bit text between two offsets in the header.
Uint8List buildWord6(String text) {
  const textAt = 0x300;
  final fib = Uint8List(textAt + text.length + 8);
  final d = ByteData.sublistView(fib);
  d.setUint16(0, 0xA5DC, Endian.little);
  d.setUint16(2, 0x0065, Endian.little);
  d.setUint32(0x18, textAt, Endian.little);
  d.setUint32(0x1C, textAt + text.length, Endian.little);
  d.setUint32(0x34, text.length, Endian.little);
  fib.setRange(textAt, textAt + text.length, text.codeUnits);
  return buildCfb({'WordDocument': fib});
}

// ---------------------------------------------------------------------------
// Excel 97 to 2003
// ---------------------------------------------------------------------------

Uint8List _rec(int type, List<int> data) =>
    (Bytes()
          ..u16(type)
          ..u16(data.length)
          ..raw(data))
        .toBytes();

Uint8List _xlString16(String s) {
  // XLUnicodeString: 16-bit length, flags, characters (8-bit when every character fits).
  final wide = s.codeUnits.any((c) => c > 0xFF);
  final b = Bytes()
    ..u16(s.length)
    ..u8(wide ? 1 : 0);
  if (wide) {
    b.utf16(s);
  } else {
    b.raw(s.codeUnits);
  }
  return b.toBytes();
}

/// One worksheet cell for [buildXls].
class XlsCell {
  const XlsCell.text(this.row, this.col, String this.text) : number = null, xf = 0, formulaText = null;
  const XlsCell.number(this.row, this.col, double this.number, {this.xf = 0}) : text = null, formulaText = null;
  const XlsCell.formulaText(this.row, this.col, String this.formulaText) : text = null, number = null, xf = 0;

  final int row;
  final int col;
  final String? text;
  final double? number;
  final String? formulaText;
  final int xf;
}

/// A .xls with [sheets] (name to cells). Text cells go through the shared string table, which is split into
/// a CONTINUE record in the middle of its second string; number formats: XF 1 is a percentage, XF 2 a
/// built-in date and XF 3 a custom "dd/mm/yyyy".
Uint8List buildXls(Map<String, List<XlsCell>> sheets, {bool date1904 = false, bool filepass = false}) {
  // Shared strings in order of first use.
  final strings = <String>[];
  for (final cells in sheets.values) {
    for (final c in cells) {
      if (c.text != null && !strings.contains(c.text)) strings.add(c.text!);
    }
  }

  Uint8List sstRecords() {
    // One SST record that stops inside the second string, then a CONTINUE with the rest.
    final out = Bytes();
    final body = Bytes()
      ..u32(strings.length)
      ..u32(strings.length);
    var continued = false;
    for (var i = 0; i < strings.length; i++) {
      final s = strings[i];
      final wide = s.codeUnits.any((c) => c > 0xFF);
      if (i == 1 && s.length > 4) {
        // Split: header and the first 3 characters here, the rest after a fresh flags byte.
        body
          ..u16(s.length)
          ..u8(wide ? 1 : 0);
        final head = s.substring(0, 3);
        final tail = s.substring(3);
        if (wide) {
          body.utf16(head);
        } else {
          body.raw(head.codeUnits);
        }
        out.raw(_rec(0x00FC, body.toBytes()));
        final cont = Bytes()..u8(wide ? 1 : 0);
        if (wide) {
          cont.utf16(tail);
        } else {
          cont.raw(tail.codeUnits);
        }
        for (var j = i + 1; j < strings.length; j++) {
          cont.raw(_xlString16(strings[j]));
        }
        out.raw(_rec(0x003C, cont.toBytes()));
        continued = true;
        break;
      }
      body.raw(_xlString16(s));
    }
    if (!continued) out.raw(_rec(0x00FC, body.toBytes()));
    return out.toBytes();
  }

  Uint8List bof(int dt) => _rec(
    0x0809,
    (Bytes()
          ..u16(0x0600)
          ..u16(dt)
          ..u16(0x0DBB)
          ..u16(0x07CC)
          ..u32(0)
          ..u32(0x06))
        .toBytes(),
  );
  final eof = _rec(0x000A, const []);

  Uint8List globals(List<int> sheetOffsets) {
    final g = Bytes()..raw(bof(0x0005));
    if (filepass) g.raw(_rec(0x002F, [0, 0, 0, 0]));
    g.raw(_rec(0x0022, (Bytes()..u16(date1904 ? 1 : 0)).toBytes()));
    g.raw(
      _rec(
        0x041E,
        (Bytes()
              ..u16(164)
              ..raw(_xlString16('dd/mm/yyyy')))
            .toBytes(),
      ),
    );
    for (final id in const [0, 9, 14, 164]) {
      g.raw(
        _rec(
          0x00E0,
          (Bytes()
                ..u16(0)
                ..u16(id)
                ..zeros(16))
              .toBytes(),
        ),
      );
    }
    var i = 0;
    for (final name in sheets.keys) {
      g.raw(
        _rec(
          0x0085,
          (Bytes()
                ..u32(sheetOffsets[i++])
                ..u8(0)
                ..u8(0)
                ..u8(name.length)
                ..u8(0)
                ..raw(name.codeUnits))
              .toBytes(),
        ),
      );
    }
    g.raw(sstRecords()).raw(eof);
    return g.toBytes();
  }

  Uint8List sheet(List<XlsCell> cells) {
    final s = Bytes()..raw(bof(0x0010));
    for (final c in cells) {
      if (c.text != null) {
        s.raw(
          _rec(
            0x00FD,
            (Bytes()
                  ..u16(c.row)
                  ..u16(c.col)
                  ..u16(c.xf)
                  ..u32(strings.indexOf(c.text!)))
                .toBytes(),
          ),
        );
      } else if (c.number != null) {
        final v = c.number!;
        if (v == v.truncateToDouble() && v >= 0 && v < 1 << 28 && c.row.isEven) {
          // Whole numbers on even rows as RK integers, to exercise both encodings.
          s.raw(
            _rec(
              0x027E,
              (Bytes()
                    ..u16(c.row)
                    ..u16(c.col)
                    ..u16(c.xf)
                    ..u32((v.toInt() << 2) | 2))
                  .toBytes(),
            ),
          );
        } else {
          s.raw(
            _rec(
              0x0203,
              (Bytes()
                    ..u16(c.row)
                    ..u16(c.col)
                    ..u16(c.xf)
                    ..f64(v))
                  .toBytes(),
            ),
          );
        }
      } else if (c.formulaText != null) {
        s.raw(
          _rec(
            0x0006,
            (Bytes()
                  ..u16(c.row)
                  ..u16(c.col)
                  ..u16(0)
                  ..raw([0, 0, 0, 0, 0, 0, 0xFF, 0xFF])
                  ..u16(0)
                  ..u32(0)
                  ..u16(0))
                .toBytes(),
          ),
        );
        s.raw(_rec(0x0207, _xlString16(c.formulaText!)));
      }
    }
    s.raw(eof);
    return s.toBytes();
  }

  // Two passes: the globals hold each sheet's offset, and the offsets depend on the globals' length.
  final bodies = [for (final c in sheets.values) sheet(c)];
  var offsets = List<int>.filled(sheets.length, 0);
  var g = globals(offsets);
  var at = g.length;
  offsets = [
    for (final b in bodies)
      () {
        final o = at;
        at += b.length;
        return o;
      }(),
  ];
  g = globals(offsets);
  final book = Bytes()..raw(g);
  for (final b in bodies) {
    book.raw(b);
  }
  final bytes = book.toBytes();
  // Streams under 4096 bytes would be stored in the mini stream; pad so a real Workbook stream is used.
  final padded = bytes.length >= 4096 ? bytes : Uint8List.fromList([...bytes, ...Uint8List(4096 - bytes.length)]);
  return buildCfb({'Workbook': padded});
}

// ---------------------------------------------------------------------------
// PowerPoint 97 to 2003
// ---------------------------------------------------------------------------

Uint8List _pptRec(int type, List<int> body, {int ver = 0, int instance = 0}) =>
    (Bytes()
          ..u16((instance << 4) | ver)
          ..u16(type)
          ..u32(body.length)
          ..raw(body))
        .toBytes();

Uint8List _pptContainer(int type, List<List<int>> children, {int instance = 0}) =>
    _pptRec(type, [for (final c in children) ...c], ver: 0xF, instance: instance);

Uint8List _textChars(String s) => _pptRec(0x0FA0, (Bytes()..utf16(s)).toBytes());
Uint8List _textBytes(String s) => _pptRec(0x0FA8, s.codeUnits);
Uint8List _textHeader(int type) => _pptRec(0x0F9F, (Bytes()..u32(type)).toBytes());

/// One slide for [buildPpt]: [list] is its text in the deck's slide list (title and body, as `(headerType,
/// text, unicode)`), [boxes] the text boxes drawn on it.
class PptSlide {
  const PptSlide({this.list = const [], this.boxes = const []});

  final List<(int, String, bool)> list;
  final List<String> boxes;
}

/// A .ppt with [slides]. [staleBefore] puts an older, different version of the first slide earlier in the
/// stream (as a file saved several times does), which only the edit history tells apart from the real one.
Uint8List buildPpt(List<PptSlide> slides, {bool staleBefore = false, bool encrypted = false, bool history = true}) {
  final stream = Bytes();

  Uint8List slideContainer(PptSlide s, {List<String>? boxes}) => _pptContainer(0x03EE, [
    _pptContainer(0x040C, [
      _pptContainer(0xF002, [
        for (final t in boxes ?? s.boxes)
          _pptContainer(0xF004, [
            _pptContainer(0xF00D, [_textHeader(4), _textChars(t)]),
          ]),
      ]),
    ]),
  ]);

  // An older version of slide one that must not be shown.
  if (staleBefore) stream.raw(slideContainer(slides.first, boxes: const ['OLD TEXT FROM AN EARLIER SAVE']));

  // The slides first, so the Document can name their persist ids; offsets are fixed up afterwards.
  final slideBytes = [for (final s in slides) slideContainer(s)];
  final slideOffsets = <int>[];
  for (final b in slideBytes) {
    slideOffsets.add(stream.length);
    stream.raw(b);
  }

  Uint8List document() => _pptContainer(0x03E8, [
    _pptContainer(0x0FF0, [
      for (var i = 0; i < slides.length; i++) ...[
        _pptRec(
          0x03F3,
          (Bytes()
                ..u32(i + 2)
                ..u32(0)
                ..u32(0)
                ..u32(256 + i)
                ..u32(0))
              .toBytes(),
        ),
        for (final (header, text, unicode) in slides[i].list) ...[
          _textHeader(header),
          unicode ? _textChars(text) : _textBytes(text),
        ],
      ],
    ], instance: 0),
    // Masters' and notes' text are not the slides'.
    _pptContainer(0x0FF0, [
      _pptRec(
        0x03F3,
        (Bytes()
              ..u32(99)
              ..u32(0)
              ..u32(0)
              ..u32(1)
              ..u32(0))
            .toBytes(),
      ),
      _textHeader(1),
      _textChars('MASTER TEXT'),
    ], instance: 1),
  ]);

  final docAt = stream.length;
  stream.raw(document());

  final dirAt = stream.length;
  if (history) {
    // PersistDirectoryAtom: persist id 1 is the Document, ids 2.. the slides.
    final dir = Bytes()
      ..u32((1 + slides.length) << 20 | 1)
      ..u32(docAt);
    for (final o in slideOffsets) {
      dir.u32(o);
    }
    stream.raw(_pptRec(0x1772, dir.toBytes()));
    final editAt = stream.length;
    stream.raw(
      _pptRec(
        0x0FF5,
        (Bytes()
              ..u32(0)
              ..u16(0)
              ..u8(0)
              ..u8(3)
              ..u32(0)
              ..u32(dirAt)
              ..u32(1)
              ..u32(slides.length + 2)
              ..u16(0)
              ..u16(0))
            .toBytes(),
      ),
    );
    final user =
        (Bytes()
              ..u32(20)
              ..u32(encrypted ? 0xF3D1C4DF : 0xE391C05F)
              ..u32(history ? editAt : 0)
              ..zeros(8))
            .toBytes();
    final padded = stream.length >= 4096
        ? stream.toBytes()
        : Uint8List.fromList([...stream.toBytes(), ...Uint8List(4096 - stream.length)]);
    return buildCfb({
      'PowerPoint Document': padded,
      'Current User': Uint8List.fromList([0, 0, 0, 0, 0, 0, 0, 0, ...user]),
    });
  }
  final padded = stream.length >= 4096
      ? stream.toBytes()
      : Uint8List.fromList([...stream.toBytes(), ...Uint8List(4096 - stream.length)]);
  return buildCfb({'PowerPoint Document': padded});
}

// ---------------------------------------------------------------------------
// Office Open XML
// ---------------------------------------------------------------------------

/// A ZIP of [files] (path to text).
Uint8List buildZip(Map<String, String> files) {
  final zip = Archive();
  files.forEach((path, text) {
    final data = utf8.encode(text);
    zip.add(ArchiveFile(path, data.length, data));
  });
  return Uint8List.fromList(ZipEncoder().encode(zip));
}

/// A ZIP of [files] (path to bytes), for files that are not text.
Uint8List buildZipBytes(Map<String, Uint8List> files) {
  final zip = Archive();
  files.forEach((path, data) => zip.add(ArchiveFile(path, data.length, data)));
  return Uint8List.fromList(ZipEncoder().encode(zip));
}

const _wNs =
    'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
    'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
    'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
    'xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"';

/// A .docx whose body is [body] (WordprocessingML) with [styles] and [numbering] parts.
Uint8List buildDocx(String body, {String styles = '', String numbering = ''}) => buildZip({
  '[Content_Types].xml': '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"/>',
  'word/document.xml': '<w:document $_wNs><w:body>$body</w:body></w:document>',
  if (styles.isNotEmpty) 'word/styles.xml': '<w:styles $_wNs>$styles</w:styles>',
  if (numbering.isNotEmpty) 'word/numbering.xml': '<w:numbering $_wNs>$numbering</w:numbering>',
});

const _sNs =
    'xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
    'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"';

/// A .xlsx with one sheet per entry of [sheets] (name to `<sheetData>` XML), shared strings and styles.
Uint8List buildXlsx(
  Map<String, String> sheets, {
  List<String> shared = const [],
  String styles = '',
  bool date1904 = false,
}) {
  final files = <String, String>{
    '[Content_Types].xml': '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"/>',
    'xl/workbook.xml':
        '<workbook $_sNs><workbookPr${date1904 ? ' date1904="1"' : ''}/><sheets>'
        '${[for (var i = 0; i < sheets.length; i++) '<sheet name="${sheets.keys.elementAt(i)}" sheetId="${i + 1}" r:id="rId${i + 1}"/>'].join()}'
        '</sheets></workbook>',
    'xl/_rels/workbook.xml.rels':
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '${[for (var i = 0; i < sheets.length; i++) '<Relationship Id="rId${i + 1}" Target="worksheets/sheet${i + 1}.xml"/>'].join()}'
        '</Relationships>',
    if (shared.isNotEmpty)
      'xl/sharedStrings.xml': '<sst $_sNs>${[for (final s in shared) '<si><t>$s</t></si>'].join()}</sst>',
    if (styles.isNotEmpty) 'xl/styles.xml': '<styleSheet $_sNs>$styles</styleSheet>',
  };
  for (var i = 0; i < sheets.length; i++) {
    files['xl/worksheets/sheet${i + 1}.xml'] =
        '<worksheet $_sNs><sheetData>${sheets.values.elementAt(i)}</sheetData></worksheet>';
  }
  return buildZip(files);
}

const _pNs =
    'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
    'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
    'xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"';

/// A .pptx whose slides are [slides] (the `<p:spTree>` content of each), listed in the order given.
Uint8List buildPptx(List<String> slides) {
  final files = <String, String>{
    '[Content_Types].xml': '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"/>',
    'ppt/presentation.xml':
        '<p:presentation $_pNs><p:sldIdLst>'
        '${[for (var i = 0; i < slides.length; i++) '<p:sldId id="${256 + i}" r:id="rId${i + 1}"/>'].join()}'
        '</p:sldIdLst></p:presentation>',
    'ppt/_rels/presentation.xml.rels':
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '${[for (var i = 0; i < slides.length; i++) '<Relationship Id="rId${i + 1}" Target="slides/slide${i + 1}.xml"/>'].join()}'
        '</Relationships>',
  };
  for (var i = 0; i < slides.length; i++) {
    files['ppt/slides/slide${i + 1}.xml'] = '<p:sld $_pNs><p:cSld><p:spTree>${slides[i]}</p:spTree></p:cSld></p:sld>';
  }
  return buildZip(files);
}
