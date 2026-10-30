import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Text drawn in a box shorter than its own lines, which Flutter clips without a sound: a design's fixed
/// heights were set for text smaller than the app's 12 sp floor. Returns one line per offender
/// ("Domain Expertise: 15.6 needed, 11.0 given"), empty when every paragraph has room.
List<String> clippedText(WidgetTester tester) {
  final found = <String>[];
  for (final p in tester.renderObjectList<RenderParagraph>(find.byType(RichText))) {
    if (!p.hasSize || p.size.isEmpty) continue;
    final needed = p.getMaxIntrinsicHeight(p.size.width);
    if (needed - p.size.height > 0.5) {
      found.add(
        '${p.text.toPlainText()}: ${needed.toStringAsFixed(1)} needed, ${p.size.height.toStringAsFixed(1)} given',
      );
    }
  }
  return found;
}
