import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/features/events/widgets/qr_code.dart';

/// The QR encoder the event pass draws. It was checked against two outside
/// implementations when it was written: every code it makes (all eight masks,
/// versions 1 to 10, UTF-8 text) matched the Python `qrcode` library module for
/// module, and OpenCV's QR detector read back what it encoded. The reference
/// vectors below are the SHA-256 of that library's output, so these tests keep
/// the encoder equal to it.
void main() {
  group('the encoder\'s size and capacity', () {
    test('picks the smallest version that holds the bytes (level M)', () {
      int version(int bytes) => QrCode.encode('a' * bytes).version;
      expect(version(1), 1);
      expect(version(14), 1);
      expect(version(15), 2);
      expect(version(26), 2);
      expect(version(27), 3);
      expect(version(42), 3);
      expect(version(43), 4);
      expect(version(106), 6);
      expect(version(107), 7);
      expect(version(152), 8);
      expect(version(213), 10);
    });

    test('a side is 17 + 4 × version modules', () {
      for (final n in [1, 15, 27, 63, 107, 153, 213]) {
        final q = QrCode.encode('a' * n);
        expect(q.size, 17 + 4 * q.version);
        expect(q.toRows(), hasLength(q.size));
        expect(q.toRows().every((r) => r.length == q.size), isTrue);
      }
    });

    test('text past 213 bytes does not fit, and says so', () {
      expect(QrCode.fits('a' * 213), isTrue);
      expect(QrCode.fits('a' * 214), isFalse);
      expect(QrCode.tryEncode('a' * 214), isNull);
      expect(() => QrCode.encode('a' * 214), throwsArgumentError);
    });

    test('counts UTF-8 bytes, not characters', () {
      expect(QrCode.fits('é' * 106), isTrue);
      expect(QrCode.fits('é' * 107), isFalse, reason: '107 two-byte letters are 214 bytes');
      expect(QrCode.encode('café').version, 1);
    });

    test('is the same code every time, and honours a mask it is told to use', () {
      expect(
        QrCode.encode('https://icr.org.in/events/x').toRows(),
        QrCode.encode('https://icr.org.in/events/x').toRows(),
      );
      for (var mask = 0; mask < 8; mask++) {
        expect(QrCode.encode('ICR', mask: mask).mask, mask);
      }
      final chosen = QrCode.encode('https://icr.org.in/events/future-of-business-innovation-summit-design');
      expect(chosen.mask, inInclusiveRange(0, 7));
    });
  });

  group('the symbol\'s fixed parts', () {
    final q = QrCode.encode('https://icr.org.in/events/future-of-business-innovation-summit-design');
    final n = q.size;

    bool finderDark(int dy, int dx) {
      final ring = dy == 0 || dy == 6 || dx == 0 || dx == 6;
      final core = dy >= 2 && dy <= 4 && dx >= 2 && dx <= 4;
      return ring || core;
    }

    test('three finder patterns in the corners, each with its light separator', () {
      for (final (top, left) in [(0, 0), (0, n - 7), (n - 7, 0)]) {
        for (var dy = 0; dy < 7; dy++) {
          for (var dx = 0; dx < 7; dx++) {
            expect(q.isDark(top + dy, left + dx), finderDark(dy, dx), reason: 'finder at $top,$left ($dy,$dx)');
          }
        }
      }
      for (var i = 0; i < 8; i++) {
        expect(q.isDark(7, i), isFalse, reason: 'separator under the top left finder');
        expect(q.isDark(i, 7), isFalse, reason: 'separator beside the top left finder');
        expect(q.isDark(7, n - 1 - i), isFalse, reason: 'separator under the top right finder');
        expect(q.isDark(n - 8, i), isFalse, reason: 'separator over the bottom left finder');
      }
    });

    test('timing patterns alternate between the finders, starting dark', () {
      for (var i = 8; i < n - 8; i++) {
        expect(q.isDark(6, i), i % 2 == 0, reason: 'row 6, column $i');
        expect(q.isDark(i, 6), i % 2 == 0, reason: 'column 6, row $i');
      }
    });

    test('the always-dark module, and an alignment pattern for version 2 and up', () {
      expect(q.isDark(n - 8, 8), isTrue);
      expect(q.version, greaterThanOrEqualTo(2));
      // The bottom right alignment pattern is centred 7 modules in from the corner.
      final c = n - 7;
      for (var dy = -2; dy <= 2; dy++) {
        for (var dx = -2; dx <= 2; dx++) {
          final dist = dy.abs() > dx.abs() ? dy.abs() : dx.abs();
          expect(q.isDark(c + dy, c + dx), dist != 1, reason: 'alignment ($dy,$dx)');
        }
      }
    });

    int readFormat(QrCode code, {required bool first}) {
      final size = code.size;
      bool d(int x, int y) => code.isDark(y, x); // the standard's (column, row)
      final bits = List<bool>.filled(15, false);
      if (first) {
        for (var i = 0; i <= 5; i++) {
          bits[i] = d(8, i);
        }
        bits[6] = d(8, 7);
        bits[7] = d(8, 8);
        bits[8] = d(7, 8);
        for (var i = 9; i < 15; i++) {
          bits[i] = d(14 - i, 8);
        }
      } else {
        for (var i = 0; i < 8; i++) {
          bits[i] = d(size - 1 - i, 8);
        }
        for (var i = 8; i < 15; i++) {
          bits[i] = d(8, size - 15 + i);
        }
      }
      return [
        for (var i = 0; i < 15; i++)
          if (bits[i]) 1 << i,
      ].fold(0, (a, b) => a | b);
    }

    /// Level M (00) and the mask, BCH(15,5) with 0x537, xor 0x5412 — written out again from the standard.
    int expectedFormat(int mask) {
      var rem = mask;
      for (var i = 0; i < 10; i++) {
        rem = (rem << 1) ^ ((rem >> 9) * 0x537);
      }
      return ((mask << 10) | rem) ^ 0x5412;
    }

    test('both copies of the format information say level M and the mask used', () {
      for (final text in ['ICR', 'https://icr.org.in/events/x', 'a' * 150]) {
        for (var mask = 0; mask < 8; mask++) {
          final code = QrCode.encode(text, mask: mask);
          expect(readFormat(code, first: true), expectedFormat(mask), reason: '$text, mask $mask, first copy');
          expect(readFormat(code, first: false), expectedFormat(mask), reason: '$text, mask $mask, second copy');
        }
      }
      expect(readFormat(q, first: true), expectedFormat(q.mask));
    });

    test('version 7 and up carry their version information twice', () {
      final code = QrCode.encode('a' * 150); // version 8
      expect(code.version, 8);
      var rem = code.version;
      for (var i = 0; i < 12; i++) {
        rem = (rem << 1) ^ ((rem >> 11) * 0x1F25);
      }
      final expected = (code.version << 12) | rem;
      final size = code.size;
      for (var i = 0; i < 18; i++) {
        final bit = (expected >> i) & 1 == 1;
        final a = size - 11 + i % 3;
        final b = i ~/ 3;
        expect(code.isDark(b, a), bit, reason: 'bit $i, top right block');
        expect(code.isDark(a, b), bit, reason: 'bit $i, bottom left block');
      }
    });
  });

  group('the data modules', () {
    String digest(QrCode code) => sha256.convert(utf8.encode(code.toRows().join('\n'))).toString();

    // SHA-256 of the rows ('#' dark, '.' light, joined by newlines) of the reference library's code for
    // the same text, version and mask.
    test('are the reference implementation\'s, module for module (version 1, 5, 9 and 10)', () {
      expect(digest(QrCode.encode('ICR', mask: 3)), '5242fee67a9fa7afd532bb7f47655bfe918942ca688dffb6ae8edc78c40eaa24');
      expect(
        digest(QrCode.encode('https://icr.org.in/events/future-of-business-innovation-summit-design', mask: 5)),
        '6806d1165f9c7472c488a6cbde2d793d4b6e0e86c31cadc42d5b4eaef02ef779',
      );
      expect(
        digest(QrCode.encode('https://icr.org.in/events/${'c' * 150}', mask: 1)),
        'be3a5a342ffd66a4e3098d33d608065868ba178540cb67f717763e54669efa27',
      );
      expect(
        digest(QrCode.encode('a' * 213, mask: 0)),
        'd58f13f591f9fd411517e19edd90c33c4d5975dbaea3604d20cf56e576b6caf0',
      );
    });

    test('the four codes are the versions the capacity table gives', () {
      expect(QrCode.encode('ICR').version, 1);
      expect(QrCode.encode('https://icr.org.in/events/future-of-business-innovation-summit-design').version, 5);
      expect(QrCode.encode('https://icr.org.in/events/${'c' * 150}').version, 9);
      expect(QrCode.encode('a' * 213).version, 10);
    });
  });

  testWidgets('QrView draws the code on a white square with a four-module quiet zone', (tester) async {
    final code = QrCode.encode('https://icr.org.in/events/x');
    await tester.pumpWidget(
      MaterialApp(
        home: Center(child: QrView(code: code, size: 200)),
      ),
    );
    expect(tester.getSize(find.byType(QrView)), const Size(200, 200));
    expect(find.bySemanticsLabel('QR code'), findsOneWidget, reason: 'a screen reader is told what it is');
    expect(find.descendant(of: find.byType(QrView), matching: find.byType(CustomPaint)), findsWidgets);
  });
}
