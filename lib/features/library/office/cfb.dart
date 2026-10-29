import 'dart:typed_data';

import 'office_models.dart';

/// The container behind Word, Excel and PowerPoint files from before 2007 (`.doc`, `.xls`, `.ppt`): a small
/// file system of named streams (MS-CFB, "OLE compound file"). Only reading is supported.
class Cfb {
  Cfb._(this._data, this._shift, this._miniShift, this._cutoff, this._fat, this._miniFat, this._entries, this._mini);

  final Uint8List _data;
  final int _shift;
  final int _miniShift;
  final int _cutoff;
  final List<int> _fat;
  final List<int> _miniFat;
  final List<_Entry> _entries;
  final Uint8List _mini;

  static const _signature = [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1];
  static const _endOfChain = 0xFFFFFFFE;
  static const _freeSector = 0xFFFFFFFF;

  /// Whether [bytes] start like a compound file.
  static bool looksLike(Uint8List bytes) {
    if (bytes.length < 512) return false;
    for (var i = 0; i < _signature.length; i++) {
      if (bytes[i] != _signature[i]) return false;
    }
    return true;
  }

  /// Reads the directory of [data], or throws an [OfficeProblem].
  factory Cfb.parse(Uint8List data) {
    if (!looksLike(data)) throw const OfficeProblem("This file can't be read.");
    final view = ByteData.sublistView(data);
    int u16(int o) => view.getUint16(o, Endian.little);
    int u32(int o) => view.getUint32(o, Endian.little);

    final shift = u16(0x1E);
    final miniShift = u16(0x20);
    if (shift < 7 || shift > 16 || miniShift < 3 || miniShift > shift) {
      throw const OfficeProblem("This file can't be read. It may be damaged.");
    }
    final sectorSize = 1 << shift;
    final fatSectors = u32(0x2C);
    final firstDir = u32(0x30);
    final cutoff = u32(0x38);
    final firstMiniFat = u32(0x3C);
    final miniFatSectors = u32(0x40);
    final firstDifat = u32(0x44);
    final difatSectors = u32(0x48);

    int offsetOf(int sector) => (sector + 1) << shift;
    bool inside(int sector) => sector >= 0 && sector < 0xFFFFFFFA && offsetOf(sector) + sectorSize <= data.length;

    // The sectors that hold the FAT: 109 listed in the header, then a chain of DIFAT sectors.
    final fatIds = <int>[];
    for (var i = 0; i < 109 && fatIds.length < fatSectors; i++) {
      final id = u32(0x4C + i * 4);
      if (id != _freeSector && id != _endOfChain) fatIds.add(id);
    }
    var difat = firstDifat;
    var guard = 0;
    while (difatSectors > 0 && difat != _endOfChain && difat != _freeSector && guard++ < difatSectors + 1) {
      if (!inside(difat)) break;
      final base = offsetOf(difat);
      final per = sectorSize ~/ 4 - 1;
      for (var i = 0; i < per && fatIds.length < fatSectors; i++) {
        final id = u32(base + i * 4);
        if (id != _freeSector && id != _endOfChain) fatIds.add(id);
      }
      difat = u32(base + per * 4);
    }

    final fat = <int>[];
    for (final id in fatIds) {
      if (!inside(id)) continue;
      final base = offsetOf(id);
      for (var i = 0; i < sectorSize ~/ 4; i++) {
        fat.add(u32(base + i * 4));
      }
    }
    if (fat.isEmpty) throw const OfficeProblem("This file can't be read. It may be damaged.");

    Uint8List fatChain(int start, [int? length]) => _readChain(data, shift, fat, start, length);

    // The directory.
    final dir = fatChain(firstDir);
    final entries = <_Entry>[];
    final dv = ByteData.sublistView(dir);
    for (var o = 0; o + 128 <= dir.length; o += 128) {
      final type = dir[o + 0x42];
      final nameLen = dv.getUint16(o + 0x40, Endian.little);
      if (type == 0 || nameLen < 2 || nameLen > 64) {
        entries.add(_Entry('', 0, 0, 0));
        continue;
      }
      final chars = <int>[];
      for (var i = 0; i < nameLen - 2; i += 2) {
        chars.add(dv.getUint16(o + i, Endian.little));
      }
      entries.add(
        _Entry(
          String.fromCharCodes(chars),
          type,
          dv.getUint32(o + 0x74, Endian.little),
          dv.getUint32(o + 0x78, Endian.little),
        ),
      );
    }
    if (entries.isEmpty || entries.first.type != 5) {
      throw const OfficeProblem("This file can't be read. It may be damaged.");
    }

    // The mini stream (small streams live inside the root entry's stream) and its allocation table.
    final root = entries.first;
    final mini = root.size > 0 ? fatChain(root.start, root.size) : Uint8List(0);
    final miniFat = <int>[];
    if (miniFatSectors > 0 && firstMiniFat != _endOfChain) {
      final raw = fatChain(firstMiniFat);
      final mv = ByteData.sublistView(raw);
      for (var o = 0; o + 4 <= raw.length; o += 4) {
        miniFat.add(mv.getUint32(o, Endian.little));
      }
    }
    return Cfb._(data, shift, miniShift, cutoff, fat, miniFat, entries, mini);
  }

  /// The names of the streams in the file.
  List<String> get streamNames => [
    for (final e in _entries)
      if (e.type == 2) e.name,
  ];

  bool has(String name) => _find(name) != null;

  _Entry? _find(String name) {
    final want = name.toLowerCase();
    for (final e in _entries) {
      if (e.type == 2 && e.name.toLowerCase() == want) return e;
    }
    return null;
  }

  /// The bytes of the stream called [name], or null when the file has none.
  Uint8List? stream(String name) {
    final e = _find(name);
    if (e == null) return null;
    if (e.size < _cutoff) return _miniChain(e.start, e.size);
    return _bigChain(e.start, e.size);
  }

  Uint8List _bigChain(int start, int length) => _readChain(_data, _shift, _fat, start, length);

  Uint8List _miniChain(int start, int length) {
    final size = 1 << _miniShift;
    final out = BytesBuilder(copy: false);
    var s = start;
    var n = 0;
    var have = 0;
    while (s != _endOfChain && s != _freeSector && s < _miniFat.length && n++ <= _miniFat.length && have < length) {
      final o = s << _miniShift;
      if (o + size > _mini.length) break;
      out.add(_mini.sublist(o, o + size));
      have += size;
      s = _miniFat[s];
    }
    final all = out.toBytes();
    return length < all.length ? Uint8List.sublistView(all, 0, length) : all;
  }
}

/// The bytes of the sector chain beginning at [start], cut to [length] when given. A loop or a sector past the
/// end of the file stops the chain rather than hanging.
Uint8List _readChain(Uint8List data, int shift, List<int> fat, int start, int? length) {
  const endOfChain = 0xFFFFFFFE;
  const freeSector = 0xFFFFFFFF;
  final size = 1 << shift;
  final out = BytesBuilder(copy: false);
  var s = start;
  var steps = 0;
  var have = 0;
  while (s != endOfChain &&
      s != freeSector &&
      s < fat.length &&
      steps++ <= fat.length &&
      (length == null || have < length)) {
    final o = (s + 1) << shift;
    if (o >= data.length) break;
    final end = o + size > data.length ? data.length : o + size;
    out.add(Uint8List.sublistView(data, o, end));
    have += end - o;
    s = fat[s];
  }
  final all = out.toBytes();
  return length != null && length < all.length ? Uint8List.sublistView(all, 0, length) : all;
}

class _Entry {
  _Entry(this.name, this.type, this.start, this.size);

  final String name;
  final int type;
  final int start;
  final int size;
}
