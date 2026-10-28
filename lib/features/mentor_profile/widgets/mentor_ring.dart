import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../mentor_profile_styles.dart';

/// The photo in LinkedIn's frame: a green half-ring along its lower arc with
/// MENTOR set on it. 83 dp across in the design, the photo 79 dp inside a
/// 2 dp white margin.
class MentorRing extends StatelessWidget {
  const MentorRing({super.key, required this.child, this.size = 83, this.word = 'MENTOR'});

  final Widget child;
  final double size;
  final String word;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: CustomPaint(
        foregroundPainter: _RingPainter(word),
        child: ClipOval(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.word);

  final String word;

  static const _thickness = 9.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - _thickness / 2;
    final ring = Paint()
      ..color = MentorColors.ring
      ..style = PaintingStyle.stroke
      ..strokeWidth = _thickness;
    // Angles run clockwise from 3 o'clock, so 0..pi is the lower half.
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), 0, math.pi, false, ring);

    final glyphs = [
      for (final ch in word.split(''))
        TextPainter(
          text: TextSpan(text: ch, style: MentorText.ringWord),
          textDirection: TextDirection.ltr,
        )..layout(),
    ];
    final total = glyphs.fold<double>(0, (n, g) => n + g.width);
    var travelled = 0.0;
    final start = math.pi / 2 + total / (2 * radius);
    for (final g in glyphs) {
      final theta = start - (travelled + g.width / 2) / radius;
      canvas.save();
      canvas.translate(center.dx + radius * math.cos(theta), center.dy + radius * math.sin(theta));
      canvas.rotate(theta - math.pi / 2);
      g.paint(canvas, Offset(-g.width / 2, -g.height / 2));
      canvas.restore();
      travelled += g.width;
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.word != word;
}
