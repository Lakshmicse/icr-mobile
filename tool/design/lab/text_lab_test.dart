// A text lab for fidelity audits (not part of the suite: it only runs when asked).
//
//   flutter test --no-pub tool/design/lab/text_lab_test.dart
//
// Reads build/lab/spec.json, a list of variants
//   {"id": "a", "text": "Smart Campuses", "fam": "plex" | "work", "w": 400, "size": 10.9, "sp": 0, "color": "414750", "bg": "FFFFFF"}
// and draws each one alone on its background at 2x into build/lab/<id>.png, so a design's text can be
// compared with candidate sizes, weights and trackings (tool/design/textfit.py does the comparing).
@Tags(['lab'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_text.dart';

import '../../../test/helpers/fonts.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('draws every variant in build/lab/spec.json', (tester) async {
    final specFile = File('build/lab/spec.json');
    final specs = (jsonDecode(specFile.readAsStringSync()) as List<dynamic>).cast<Map<String, dynamic>>();
    tester.view.physicalSize = const Size(2400, 200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    for (final spec in specs) {
      final key = GlobalKey();
      final color = Color(int.parse('FF${spec['color'] ?? '111C2D'}', radix: 16));
      final bg = Color(int.parse('FF${spec['bg'] ?? 'FFFFFF'}', radix: 16));
      final size = (spec['size'] as num).toDouble();
      final weight = FontWeight.values[((spec['w'] as num).toInt() ~/ 100) - 1];
      final sp = (spec['sp'] as num?)?.toDouble();
      final lh = (spec['lh'] as num?)?.toDouble();
      final style = spec['fam'] == 'work'
          ? AppText.workSans(size, weight, color, lineHeight: lh, spacing: sp)
          : AppText.plexSans(size, weight, color, lineHeight: lh, spacing: sp);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: RepaintBoundary(
              key: key,
              child: Container(
                color: bg,
                padding: const EdgeInsets.all(6),
                child: Text(spec['text'] as String, style: style, maxLines: 1, softWrap: false),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('build/lab/${spec['id']}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }
  });
}
