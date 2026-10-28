import 'dart:convert';

import 'package:flutter/material.dart';

/// A QR Code (ISO/IEC 18004) for a short text: byte mode, error correction
/// level M, versions 1 to 10 (up to 213 bytes, plenty for an event's web
/// address). Drawn by [QrView]; the pass dialog uses it so a member's pass
/// carries a scannable code without a new package.
///
/// The encoder follows the standard step by step: version choice, the bit
/// stream (mode, count, bytes, terminator, pad bytes), Reed-Solomon codewords
/// per block over GF(256) (primitive polynomial 0x11D), block interleaving,
/// the function patterns (finders, timing, alignment, format and version
/// information), the zig-zag placement, and the mask of the lowest penalty.
class QrCode {
  QrCode._(this.version, this.mask, this._modules) : size = _modules.length;

  /// 1 to 10.
  final int version;

  /// The mask pattern (0 to 7) the encoder chose, or was told to use.
  final int mask;

  /// Modules per side: `17 + 4 * version`.
  final int size;
  final List<List<bool>> _modules;

  /// True for a dark module; [row] and [col] count from the top left.
  bool isDark(int row, int col) => _modules[row][col];

  /// The most bytes a code can hold.
  static const maxBytes = 213;

  /// Whether [text] fits (as UTF-8).
  static bool fits(String text) => utf8.encode(text).length <= maxBytes;

  /// Encodes [text]; null when it is too long. [mask] forces a mask pattern
  /// (tests compare against a reference that does the same).
  static QrCode? tryEncode(String text, {int? mask}) {
    final bytes = utf8.encode(text);
    final version = _versionFor(bytes.length);
    if (version == null) return null;
    return _build(version, bytes, mask);
  }

  /// Like [tryEncode], but throws an [ArgumentError] for a text that is too long.
  factory QrCode.encode(String text, {int? mask}) =>
      tryEncode(text, mask: mask) ?? (throw ArgumentError.value(text.length, 'text', 'too long for a QR code'));

  /// The modules as rows of '#' and '.', for tests and debugging.
  List<String> toRows() => [for (final row in _modules) row.map((d) => d ? '#' : '.').join()];

  // --- tables (level M) -------------------------------------------------------

  /// Error correction codewords per block, by version 1..10.
  static const _eccPerBlock = [10, 16, 26, 18, 24, 16, 18, 22, 22, 26];

  /// (blocks of the first kind, data codewords each, blocks of the second
  /// kind, data codewords each), by version 1..10.
  static const _blocks = <(int, int, int, int)>[
    (1, 16, 0, 0),
    (1, 28, 0, 0),
    (1, 44, 0, 0),
    (2, 32, 0, 0),
    (2, 43, 0, 0),
    (4, 27, 0, 0),
    (4, 31, 0, 0),
    (2, 38, 2, 39),
    (3, 36, 2, 37),
    (4, 43, 1, 44),
  ];

  static int _dataCodewords(int version) {
    final b = _blocks[version - 1];
    return b.$1 * b.$2 + b.$3 * b.$4;
  }

  /// The character-count field is 8 bits up to version 9 and 16 from 10.
  static int _countBits(int version) => version <= 9 ? 8 : 16;

  static int? _versionFor(int length) {
    for (var v = 1; v <= 10; v++) {
      if (4 + _countBits(v) + 8 * length <= _dataCodewords(v) * 8) return v;
    }
    return null;
  }

  // --- Reed-Solomon over GF(256) ----------------------------------------------

  static final List<int> _exp = List<int>.filled(512, 0);
  static final List<int> _log = List<int>.filled(256, 0);
  static bool _tablesReady = false;

  static void _initField() {
    if (_tablesReady) return;
    var x = 1;
    for (var i = 0; i < 255; i++) {
      _exp[i] = x;
      _log[x] = i;
      x <<= 1;
      if (x & 0x100 != 0) x ^= 0x11D;
    }
    for (var i = 255; i < 512; i++) {
      _exp[i] = _exp[i - 255];
    }
    _tablesReady = true;
  }

  static int _mul(int a, int b) => a == 0 || b == 0 ? 0 : _exp[_log[a] + _log[b]];

  /// The coefficients (highest power first, the leading 1 left out) of
  /// (x - a^0)(x - a^1)...(x - a^(degree-1)).
  static List<int> _divisor(int degree) {
    final result = List<int>.filled(degree, 0)..[degree - 1] = 1;
    var root = 1;
    for (var i = 0; i < degree; i++) {
      for (var j = 0; j < degree; j++) {
        result[j] = _mul(result[j], root);
        if (j + 1 < degree) result[j] ^= result[j + 1];
      }
      root = _mul(root, 2);
    }
    return result;
  }

  static List<int> _remainder(List<int> data, List<int> divisor) {
    final result = List<int>.filled(divisor.length, 0, growable: true);
    for (final b in data) {
      final factor = b ^ result.removeAt(0);
      result.add(0);
      for (var i = 0; i < divisor.length; i++) {
        result[i] ^= _mul(divisor[i], factor);
      }
    }
    return result;
  }

  // --- building the symbol ------------------------------------------------------

  static QrCode _build(int version, List<int> payload, int? forcedMask) {
    _initField();
    final dataLen = _dataCodewords(version);

    // The bit stream: mode 0100 (bytes), the count, the bytes, a terminator,
    // padding to a whole byte, then the alternating pad codewords.
    final bits = <int>[];
    void put(int value, int count) {
      for (var i = count - 1; i >= 0; i--) {
        bits.add((value >> i) & 1);
      }
    }

    put(0x4, 4);
    put(payload.length, _countBits(version));
    for (final b in payload) {
      put(b, 8);
    }
    final room = dataLen * 8 - bits.length;
    put(0, room < 4 ? room : 4);
    put(0, (8 - bits.length % 8) % 8);
    final data = <int>[
      for (var i = 0; i < bits.length; i += 8) bits.sublist(i, i + 8).fold(0, (acc, bit) => (acc << 1) | bit),
    ];
    for (var pad = 0xEC; data.length < dataLen; pad ^= 0xEC ^ 0x11) {
      data.add(pad);
    }

    // Split into blocks, add each block's error correction, interleave.
    final spec = _blocks[version - 1];
    final lengths = [for (var i = 0; i < spec.$1; i++) spec.$2, for (var i = 0; i < spec.$3; i++) spec.$4];
    final divisor = _divisor(_eccPerBlock[version - 1]);
    final dataBlocks = <List<int>>[];
    final eccBlocks = <List<int>>[];
    var k = 0;
    for (final len in lengths) {
      final block = data.sublist(k, k + len);
      k += len;
      dataBlocks.add(block);
      eccBlocks.add(_remainder(block, divisor));
    }
    final codewords = <int>[];
    final longest = lengths.reduce((a, b) => a > b ? a : b);
    for (var i = 0; i < longest; i++) {
      for (final block in dataBlocks) {
        if (i < block.length) codewords.add(block[i]);
      }
    }
    for (var i = 0; i < divisor.length; i++) {
      for (final block in eccBlocks) {
        codewords.add(block[i]);
      }
    }

    final grid = _Grid(version);
    grid.drawFunctionPatterns();
    grid.placeCodewords(codewords);

    var best = forcedMask ?? 0;
    if (forcedMask == null) {
      var bestScore = 1 << 30;
      for (var m = 0; m < 8; m++) {
        grid.applyMask(m);
        grid.drawFormatBits(m);
        final score = grid.penalty();
        if (score < bestScore) {
          bestScore = score;
          best = m;
        }
        grid.applyMask(m); // a mask undoes itself
      }
    }
    grid.applyMask(best);
    grid.drawFormatBits(best);
    return QrCode._(version, best, [for (final row in grid.modules) List<bool>.unmodifiable(row)]);
  }
}

/// The square of modules while a code is built: which are dark, and which
/// belong to a function pattern (never masked, never holding data).
class _Grid {
  _Grid(this.version)
    : size = version * 4 + 17,
      modules = List.generate(version * 4 + 17, (_) => List<bool>.filled(version * 4 + 17, false)),
      _isFunction = List.generate(version * 4 + 17, (_) => List<bool>.filled(version * 4 + 17, false));

  final int version;
  final int size;
  final List<List<bool>> modules;
  final List<List<bool>> _isFunction;

  /// (x, y) = (column, row), as the standard's figures.
  void _setFunction(int x, int y, bool dark) {
    modules[y][x] = dark;
    _isFunction[y][x] = true;
  }

  static bool _bit(int value, int i) => (value >> i) & 1 != 0;

  void drawFunctionPatterns() {
    for (var i = 0; i < size; i++) {
      _setFunction(6, i, i % 2 == 0);
      _setFunction(i, 6, i % 2 == 0);
    }
    _finder(3, 3);
    _finder(size - 4, 3);
    _finder(3, size - 4);
    final positions = _alignmentPositions();
    final n = positions.length;
    for (var i = 0; i < n; i++) {
      for (var j = 0; j < n; j++) {
        // The three corners taken by the finders have no alignment pattern.
        if ((i == 0 && j == 0) || (i == 0 && j == n - 1) || (i == n - 1 && j == 0)) continue;
        _alignment(positions[i], positions[j]);
      }
    }
    drawFormatBits(0); // reserves the area; the real mask is written later
    _drawVersion();
  }

  List<int> _alignmentPositions() {
    if (version == 1) return const [];
    final count = version ~/ 7 + 2;
    final step = ((version * 4 + 4) / (count * 2 - 2)).ceil() * 2;
    final result = <int>[6];
    for (var pos = size - 7; result.length < count; pos -= step) {
      result.insert(1, pos);
    }
    return result;
  }

  void _finder(int cx, int cy) {
    for (var dy = -4; dy <= 4; dy++) {
      for (var dx = -4; dx <= 4; dx++) {
        final dist = dx.abs() > dy.abs() ? dx.abs() : dy.abs();
        final x = cx + dx;
        final y = cy + dy;
        if (x >= 0 && x < size && y >= 0 && y < size) _setFunction(x, y, dist != 2 && dist != 4);
      }
    }
  }

  void _alignment(int cx, int cy) {
    for (var dy = -2; dy <= 2; dy++) {
      for (var dx = -2; dx <= 2; dx++) {
        final dist = dx.abs() > dy.abs() ? dx.abs() : dy.abs();
        _setFunction(cx + dx, cy + dy, dist != 1);
      }
    }
  }

  /// The 15 format bits: level M (00) and the mask, BCH(15,5), xor 0x5412.
  void drawFormatBits(int mask) {
    final data = (0 << 3) | mask; // level M is 00
    var rem = data;
    for (var i = 0; i < 10; i++) {
      rem = (rem << 1) ^ ((rem >> 9) * 0x537);
    }
    final bits = ((data << 10) | rem) ^ 0x5412;
    for (var i = 0; i <= 5; i++) {
      _setFunction(8, i, _bit(bits, i));
    }
    _setFunction(8, 7, _bit(bits, 6));
    _setFunction(8, 8, _bit(bits, 7));
    _setFunction(7, 8, _bit(bits, 8));
    for (var i = 9; i < 15; i++) {
      _setFunction(14 - i, 8, _bit(bits, i));
    }
    for (var i = 0; i < 8; i++) {
      _setFunction(size - 1 - i, 8, _bit(bits, i));
    }
    for (var i = 8; i < 15; i++) {
      _setFunction(8, size - 15 + i, _bit(bits, i));
    }
    _setFunction(8, size - 8, true); // the always-dark module
  }

  /// The 18 version bits (BCH(18,6)), for version 7 and up.
  void _drawVersion() {
    if (version < 7) return;
    var rem = version;
    for (var i = 0; i < 12; i++) {
      rem = (rem << 1) ^ ((rem >> 11) * 0x1F25);
    }
    final bits = (version << 12) | rem;
    for (var i = 0; i < 18; i++) {
      final dark = _bit(bits, i);
      final a = size - 11 + i % 3;
      final b = i ~/ 3;
      _setFunction(a, b, dark);
      _setFunction(b, a, dark);
    }
  }

  /// Zig-zag up and down two-column strips from the bottom right, skipping
  /// the timing column and every function module; leftover modules stay light.
  void placeCodewords(List<int> codewords) {
    var i = 0;
    final total = codewords.length * 8;
    for (var right = size - 1; right >= 1; right -= 2) {
      if (right == 6) right = 5;
      for (var vert = 0; vert < size; vert++) {
        for (var j = 0; j < 2; j++) {
          final x = right - j;
          final upward = ((right + 1) & 2) == 0;
          final y = upward ? size - 1 - vert : vert;
          if (!_isFunction[y][x] && i < total) {
            modules[y][x] = _bit(codewords[i >> 3], 7 - (i & 7));
            i++;
          }
        }
      }
    }
  }

  void applyMask(int mask) {
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final invert = switch (mask) {
          0 => (x + y) % 2 == 0,
          1 => y % 2 == 0,
          2 => x % 3 == 0,
          3 => (x + y) % 3 == 0,
          4 => (x ~/ 3 + y ~/ 2) % 2 == 0,
          5 => x * y % 2 + x * y % 3 == 0,
          6 => (x * y % 2 + x * y % 3) % 2 == 0,
          _ => ((x + y) % 2 + x * y % 3) % 2 == 0,
        };
        if (!_isFunction[y][x] && invert) modules[y][x] = !modules[y][x];
      }
    }
  }

  // --- the standard's four penalty rules ---------------------------------------

  int penalty() {
    var result = 0;
    for (var y = 0; y < size; y++) {
      result += _linePenalty((i) => modules[y][i]);
    }
    for (var x = 0; x < size; x++) {
      result += _linePenalty((i) => modules[i][x]);
    }
    for (var y = 0; y < size - 1; y++) {
      for (var x = 0; x < size - 1; x++) {
        final c = modules[y][x];
        if (c == modules[y][x + 1] && c == modules[y + 1][x] && c == modules[y + 1][x + 1]) result += 3;
      }
    }
    var dark = 0;
    for (final row in modules) {
      for (final m in row) {
        if (m) dark++;
      }
    }
    final total = size * size;
    final k = ((dark * 20 - total * 10).abs() / total).ceil() - 1;
    return result + k * 10;
  }

  /// Runs of five or more (rule 1) and 1:1:3:1:1 finder look-alikes (rule 3)
  /// along one row or column.
  int _linePenalty(bool Function(int) at) {
    var result = 0;
    var runColor = false;
    var runLength = 0;
    final history = List<int>.filled(7, 0, growable: true);

    void addHistory(int length) {
      if (history[0] == 0) length += size; // the light border before the first run
      history.removeLast();
      history.insert(0, length);
    }

    int countPatterns() {
      final n = history[1];
      final core = n > 0 && history[2] == n && history[3] == n * 3 && history[4] == n && history[5] == n;
      return (core && history[0] >= n * 4 && history[6] >= n ? 1 : 0) +
          (core && history[6] >= n * 4 && history[0] >= n ? 1 : 0);
    }

    for (var i = 0; i < size; i++) {
      if (at(i) == runColor) {
        runLength++;
        if (runLength == 5) {
          result += 3;
        } else if (runLength > 5) {
          result++;
        }
      } else {
        addHistory(runLength);
        if (!runColor) result += countPatterns() * 40;
        runColor = at(i);
        runLength = 1;
      }
    }
    // Close the line: the border after the last run is light.
    if (runColor) {
      addHistory(runLength);
      runLength = 0;
    }
    runLength += size;
    addHistory(runLength);
    return result + countPatterns() * 40;
  }
}

/// A [QrCode] drawn dark on white with the standard four-module quiet zone.
class QrView extends StatelessWidget {
  const QrView({super.key, required this.code, this.size = 180, this.dark = const Color(0xFF111C2D)});

  final QrCode code;

  /// The side of the whole square, quiet zone included.
  final double size;
  final Color dark;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'QR code',
      child: CustomPaint(size: Size.square(size), painter: _QrPainter(code, dark)),
    );
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.code, this.dark);

  final QrCode code;
  final Color dark;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final cells = code.size + 8;
    final cell = size.width / cells;
    final paint = Paint()
      ..color = dark
      ..isAntiAlias = false;
    for (var row = 0; row < code.size; row++) {
      for (var col = 0; col < code.size; col++) {
        if (!code.isDark(row, col)) continue;
        canvas.drawRect(Rect.fromLTWH((col + 4) * cell, (row + 4) * cell, cell + 0.35, cell + 0.35), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter old) => old.code != code || old.dark != dark;
}
