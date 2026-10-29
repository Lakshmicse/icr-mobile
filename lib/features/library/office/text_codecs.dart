import 'dart:typed_data';

/// The characters 0x80 to 0x9F mean different things in Windows-1252 (what Office wrote on Windows) than in
/// Latin-1, which Dart's own codec uses.
const _cp1252High = <int>[
  0x20AC,
  0x0081,
  0x201A,
  0x0192,
  0x201E,
  0x2026,
  0x2020,
  0x2021,
  0x02C6,
  0x2030,
  0x0160,
  0x2039,
  0x0152,
  0x008D,
  0x017D,
  0x008F, //
  0x0090,
  0x2018,
  0x2019,
  0x201C,
  0x201D,
  0x2022,
  0x2013,
  0x2014,
  0x02DC,
  0x2122,
  0x0161,
  0x203A,
  0x0153,
  0x009D,
  0x017E,
  0x0178,
];

/// [bytes] read as Windows-1252 text.
String decodeCp1252(List<int> bytes) {
  final out = StringBuffer();
  for (final b in bytes) {
    out.writeCharCode(b >= 0x80 && b <= 0x9F ? _cp1252High[b - 0x80] : b);
  }
  return out.toString();
}

/// [bytes] read as UTF-16, little-endian. A lone half of a pair stays as it is.
String decodeUtf16le(List<int> bytes) {
  final units = <int>[];
  for (var i = 0; i + 1 < bytes.length; i += 2) {
    units.add(bytes[i] | (bytes[i + 1] << 8));
  }
  return String.fromCharCodes(units);
}

/// A little-endian view for the binary Office formats.
extension LittleEndianReads on Uint8List {
  ByteData get data => ByteData.sublistView(this);

  int u8(int o) => this[o];
  int u16(int o) => data.getUint16(o, Endian.little);
  int u32(int o) => data.getUint32(o, Endian.little);
  int i32(int o) => data.getInt32(o, Endian.little);
  double f64(int o) => data.getFloat64(o, Endian.little);

  /// Whether [count] bytes can be read at [o].
  bool has(int o, int count) => o >= 0 && count >= 0 && o + count <= length;
}
