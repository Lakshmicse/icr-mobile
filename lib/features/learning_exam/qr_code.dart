import 'dart:convert';

import 'package:flutter/material.dart';

/// A QR code for a short text (byte mode, error correction M, the smallest version that fits, versions 1 to 10:
/// up to 213 bytes), for the certificate's "scan to authenticate".
///
/// This is the algorithm the website's certificate runs (`qrcode-generator`: the same block tables, the same
/// mask choice by the same penalty, the format information left blank while the masks are scored), so the code
/// drawn here is module for module the one the website draws for the same text; `test/learning_exam_test.dart`
/// checks that against the website's own output.
class QrCode {
  QrCode._(this.version, this.modules);

  /// Encodes [text]; throws [ArgumentError] when it does not fit version 10.
  factory QrCode.encode(String text) {
    final bytes = utf8.encode(text);
    final version = _smallestVersion(bytes.length);
    final data = _codewords(version, bytes);
    var bestMask = 0;
    var best = 0.0;
    for (var mask = 0; mask < 8; mask++) {
      final lost = _penalty(_build(version, data, mask, scoring: true));
      if (mask == 0 || best > lost) {
        best = lost;
        bestMask = mask;
      }
    }
    return QrCode._(version, _build(version, data, bestMask, scoring: false));
  }

  final int version;

  /// Row by row, true for a dark module.
  final List<List<bool>> modules;

  int get size => modules.length;

  // --- capacity -------------------------------------------------------------------------------------------

  /// Error correction M, by version: (blocks, codewords per block, data codewords per block) groups.
  static const _blocks = <int, List<(int, int, int)>>{
    1: [(1, 26, 16)],
    2: [(1, 44, 28)],
    3: [(1, 70, 44)],
    4: [(2, 50, 32)],
    5: [(2, 67, 43)],
    6: [(4, 43, 27)],
    7: [(4, 49, 31)],
    8: [(2, 60, 38), (2, 61, 39)],
    9: [(3, 58, 36), (2, 59, 37)],
    10: [(4, 69, 43), (1, 70, 44)],
  };

  static const _alignment = <int, List<int>>{
    1: [],
    2: [6, 18],
    3: [6, 22],
    4: [6, 26],
    5: [6, 30],
    6: [6, 34],
    7: [6, 22, 38],
    8: [6, 24, 42],
    9: [6, 26, 46],
    10: [6, 28, 50],
  };

  static int _dataCodewords(int version) => _blocks[version]!.fold(0, (sum, g) => sum + g.$1 * g.$3);

  static int _countBits(int version) => version < 10 ? 8 : 16;

  static int _smallestVersion(int length) {
    for (var v = 1; v <= 10; v++) {
      if (4 + _countBits(v) + length * 8 <= _dataCodewords(v) * 8) return v;
    }
    throw ArgumentError('A QR code of this length is not supported ($length bytes).');
  }

  // --- the codewords --------------------------------------------------------------------------------------

  static List<int> _codewords(int version, List<int> bytes) {
    final bits = <int>[];
    void put(int value, int length) {
      for (var i = length - 1; i >= 0; i--) {
        bits.add((value >> i) & 1);
      }
    }

    put(4, 4); // byte mode
    put(bytes.length, _countBits(version));
    for (final b in bytes) {
      put(b, 8);
    }
    final capacity = _dataCodewords(version) * 8;
    if (bits.length + 4 <= capacity) put(0, 4);
    while (bits.length % 8 != 0) {
      bits.add(0);
    }
    final padding = [0xEC, 0x11];
    for (var i = 0; bits.length < capacity; i++) {
      put(padding[i % 2], 8);
    }
    final data = [for (var i = 0; i < bits.length; i += 8) bits.sublist(i, i + 8).fold(0, (a, b) => (a << 1) | b)];

    // Split into blocks, add each block's error correction, interleave.
    final groups = _blocks[version]!;
    final dataBlocks = <List<int>>[];
    final ecBlocks = <List<int>>[];
    var offset = 0;
    for (final (count, total, dataCount) in groups) {
      final ecCount = total - dataCount;
      final generator = _generator(ecCount);
      for (var b = 0; b < count; b++) {
        final block = data.sublist(offset, offset + dataCount);
        offset += dataCount;
        dataBlocks.add(block);
        ecBlocks.add(_remainder(block, generator));
      }
    }
    final out = <int>[];
    final maxData = dataBlocks.map((b) => b.length).reduce((a, b) => a > b ? a : b);
    for (var i = 0; i < maxData; i++) {
      for (final b in dataBlocks) {
        if (i < b.length) out.add(b[i]);
      }
    }
    final maxEc = ecBlocks.map((b) => b.length).reduce((a, b) => a > b ? a : b);
    for (var i = 0; i < maxEc; i++) {
      for (final b in ecBlocks) {
        if (i < b.length) out.add(b[i]);
      }
    }
    return out;
  }

  // GF(256), primitive polynomial 0x11D.
  static final List<int> _exp = _expTable();
  static final List<int> _log = _logTable();

  static List<int> _expTable() {
    final t = List<int>.filled(256, 0);
    for (var i = 0; i < 8; i++) {
      t[i] = 1 << i;
    }
    for (var i = 8; i < 256; i++) {
      t[i] = t[i - 4] ^ t[i - 5] ^ t[i - 6] ^ t[i - 8];
    }
    return t;
  }

  static List<int> _logTable() {
    final t = List<int>.filled(256, 0);
    for (var i = 0; i < 255; i++) {
      t[_exp[i]] = i;
    }
    return t;
  }

  /// (x + a^0)(x + a^1)...(x + a^(count-1)), the highest power first.
  static List<int> _generator(int count) {
    var poly = <int>[1];
    for (var i = 0; i < count; i++) {
      final next = List<int>.filled(poly.length + 1, 0);
      for (var j = 0; j < poly.length; j++) {
        next[j] ^= poly[j];
        next[j + 1] ^= _exp[(_log[poly[j]] + i) % 255];
      }
      poly = next;
    }
    return poly;
  }

  /// The remainder of `data * x^n` divided by [generator]: the block's error correction codewords.
  static List<int> _remainder(List<int> data, List<int> generator) {
    final res = [...data, ...List<int>.filled(generator.length - 1, 0)];
    for (var i = 0; i < data.length; i++) {
      final lead = res[i];
      if (lead == 0) continue;
      final l = _log[lead];
      for (var j = 0; j < generator.length; j++) {
        res[i + j] ^= _exp[(l + _log[generator[j]]) % 255];
      }
    }
    return res.sublist(data.length);
  }

  // --- the matrix -----------------------------------------------------------------------------------------

  /// With [scoring] the format information is left light, as the website's generator scores its masks.
  static List<List<bool>> _build(int version, List<int> data, int mask, {required bool scoring}) {
    final n = version * 4 + 17;
    final m = List<List<bool?>>.generate(n, (_) => List<bool?>.filled(n, null));

    void probe(int row, int col) {
      for (var r = -1; r <= 7; r++) {
        if (row + r <= -1 || n <= row + r) continue;
        for (var c = -1; c <= 7; c++) {
          if (col + c <= -1 || n <= col + c) continue;
          m[row + r][col + c] =
              (0 <= r && r <= 6 && (c == 0 || c == 6)) ||
              (0 <= c && c <= 6 && (r == 0 || r == 6)) ||
              (2 <= r && r <= 4 && 2 <= c && c <= 4);
        }
      }
    }

    probe(0, 0);
    probe(n - 7, 0);
    probe(0, n - 7);

    final pos = _alignment[version]!;
    for (final row in pos) {
      for (final col in pos) {
        if (m[row][col] != null) continue;
        for (var r = -2; r <= 2; r++) {
          for (var c = -2; c <= 2; c++) {
            m[row + r][col + c] = r == -2 || r == 2 || c == -2 || c == 2 || (r == 0 && c == 0);
          }
        }
      }
    }

    for (var r = 8; r < n - 8; r++) {
      m[r][6] ??= r % 2 == 0;
    }
    for (var c = 8; c < n - 8; c++) {
      m[6][c] ??= c % 2 == 0;
    }

    // Format information: error correction M (bits 00) and the mask.
    final format = _bch15(mask);
    for (var i = 0; i < 15; i++) {
      final dark = !scoring && ((format >> i) & 1) == 1;
      if (i < 6) {
        m[i][8] = dark;
      } else if (i < 8) {
        m[i + 1][8] = dark;
      } else {
        m[n - 15 + i][8] = dark;
      }
      if (i < 8) {
        m[8][n - i - 1] = dark;
      } else if (i < 9) {
        m[8][15 - i - 1 + 1] = dark;
      } else {
        m[8][15 - i - 1] = dark;
      }
    }
    m[n - 8][8] = !scoring;

    if (version >= 7) {
      final bits = _bch18(version);
      for (var i = 0; i < 18; i++) {
        final dark = !scoring && ((bits >> i) & 1) == 1;
        m[i ~/ 3][i % 3 + n - 8 - 3] = dark;
        m[i % 3 + n - 8 - 3][i ~/ 3] = dark;
      }
    }

    // The data, in 2-column strips from the bottom right, up then down, skipping the timing column.
    var inc = -1;
    var row = n - 1;
    var bitIndex = 7;
    var byteIndex = 0;
    for (var col = n - 1; col > 0; col -= 2) {
      if (col == 6) col -= 1;
      while (true) {
        for (var c = 0; c < 2; c++) {
          if (m[row][col - c] == null) {
            var dark = byteIndex < data.length && ((data[byteIndex] >>> bitIndex) & 1) == 1;
            if (_masked(mask, row, col - c)) dark = !dark;
            m[row][col - c] = dark;
            bitIndex--;
            if (bitIndex == -1) {
              byteIndex++;
              bitIndex = 7;
            }
          }
        }
        row += inc;
        if (row < 0 || n <= row) {
          row -= inc;
          inc = -inc;
          break;
        }
      }
    }
    return [
      for (final r in m) [for (final v in r) v ?? false],
    ];
  }

  static bool _masked(int mask, int i, int j) => switch (mask) {
    0 => (i + j) % 2 == 0,
    1 => i % 2 == 0,
    2 => j % 3 == 0,
    3 => (i + j) % 3 == 0,
    4 => (i ~/ 2 + j ~/ 3) % 2 == 0,
    5 => (i * j) % 2 + (i * j) % 3 == 0,
    6 => ((i * j) % 2 + (i * j) % 3) % 2 == 0,
    _ => ((i * j) % 3 + (i + j) % 2) % 2 == 0,
  };

  static int _digits(int v) {
    var d = 0;
    while (v != 0) {
      d++;
      v >>>= 1;
    }
    return d;
  }

  static int _bch15(int mask) {
    const g15 = 0x537;
    const maskBits = 0x5412;
    final data = (0 << 3) | mask; // error correction M is 0
    var d = data << 10;
    while (_digits(d) - _digits(g15) >= 0) {
      d ^= g15 << (_digits(d) - _digits(g15));
    }
    return ((data << 10) | d) ^ maskBits;
  }

  static int _bch18(int version) {
    const g18 = 0x1F25;
    var d = version << 12;
    while (_digits(d) - _digits(g18) >= 0) {
      d ^= g18 << (_digits(d) - _digits(g18));
    }
    return (version << 12) | d;
  }

  /// How badly the masked matrix reads, by the generator's four rules (lower is better).
  static double _penalty(List<List<bool>> q) {
    final n = q.length;
    var lost = 0.0;
    for (var row = 0; row < n; row++) {
      for (var col = 0; col < n; col++) {
        var same = 0;
        final dark = q[row][col];
        for (var r = -1; r <= 1; r++) {
          if (row + r < 0 || n <= row + r) continue;
          for (var c = -1; c <= 1; c++) {
            if (col + c < 0 || n <= col + c) continue;
            if (r == 0 && c == 0) continue;
            if (dark == q[row + r][col + c]) same++;
          }
        }
        if (same > 5) lost += 3 + same - 5;
      }
    }
    for (var row = 0; row < n - 1; row++) {
      for (var col = 0; col < n - 1; col++) {
        var count = 0;
        if (q[row][col]) count++;
        if (q[row + 1][col]) count++;
        if (q[row][col + 1]) count++;
        if (q[row + 1][col + 1]) count++;
        if (count == 0 || count == 4) lost += 3;
      }
    }
    for (var row = 0; row < n; row++) {
      for (var col = 0; col < n - 6; col++) {
        if (q[row][col] &&
            !q[row][col + 1] &&
            q[row][col + 2] &&
            q[row][col + 3] &&
            q[row][col + 4] &&
            !q[row][col + 5] &&
            q[row][col + 6]) {
          lost += 40;
        }
      }
    }
    for (var col = 0; col < n; col++) {
      for (var row = 0; row < n - 6; row++) {
        if (q[row][col] &&
            !q[row + 1][col] &&
            q[row + 2][col] &&
            q[row + 3][col] &&
            q[row + 4][col] &&
            !q[row + 5][col] &&
            q[row + 6][col]) {
          lost += 40;
        }
      }
    }
    var darkCount = 0;
    for (final r in q) {
      for (final v in r) {
        if (v) darkCount++;
      }
    }
    final ratio = (100 * darkCount / n / n - 50).abs() / 5;
    return lost + ratio * 10;
  }
}

/// A QR code drawn as crisp squares (no anti-aliasing, so a scan of the screen does not see grey edges).
class QrView extends StatelessWidget {
  const QrView({super.key, required this.data, this.size, this.color = const Color(0xFF1A1A1A)});

  final String data;

  /// Side in dp; fills the space it is given when null.
  final double? size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final code = QrCode.encode(data);
    final painter = CustomPaint(painter: _QrPainter(code, color), size: Size.square(size ?? 0));
    return Semantics(
      image: true,
      label: 'QR code that opens $data',
      excludeSemantics: true,
      child: size == null
          ? AspectRatio(aspectRatio: 1, child: painter)
          : SizedBox.square(dimension: size, child: painter),
    );
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.code, this.color);

  final QrCode code;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..isAntiAlias = false;
    final cell = size.width / code.size;
    for (var r = 0; r < code.size; r++) {
      for (var c = 0; c < code.size; c++) {
        if (code.modules[r][c]) {
          // A hair over each cell, so neighbouring squares meet without a seam.
          canvas.drawRect(Rect.fromLTWH(c * cell, r * cell, cell + 0.4, cell + 0.4), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter old) => old.code != code || old.color != color;
}
