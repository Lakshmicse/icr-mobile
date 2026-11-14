import 'package:flutter/material.dart';

/// The two tab icons the design draws itself (traced from it): a house with a
/// slot in its front, and a briefcase crossed by a curved band, in the tab's
/// colour. Each is filled, or drawn as its outline ([filled] false): the bar
/// shows a tab's outline until it is the open one (owner, 13 Nov 2026).

/// The outline's line: the weight of Material's outlined glyphs at this size.
const _line = 1.7;

Paint _stroke(Color color) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = _line
  ..strokeJoin = StrokeJoin.round
  ..strokeCap = StrokeCap.round;

/// 22.5 × 20.75 dp, the house as the design draws it.
class HouseIcon extends StatelessWidget {
  const HouseIcon({super.key, required this.color, this.filled = true});

  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(22.5, 20.75), painter: _HousePainter(color, filled));
}

class _HousePainter extends CustomPainter {
  _HousePainter(this.color, this.filled);

  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    if (!filled) {
      // The same house, as its line: the roof's eaves, the walls, and the slot as a short bar.
      const h = _line / 2;
      final outline = Path()
        ..moveTo(11.25, h + 0.3)
        ..lineTo(22.5 - h - 0.6, 10.1)
        ..lineTo(20.25 - h, 10.1)
        ..lineTo(20.25 - h, 20.75 - h)
        ..lineTo(3.25 + h, 20.75 - h)
        ..lineTo(3.25 + h, 10.1)
        ..lineTo(h + 0.6, 10.1)
        ..close();
      canvas.drawPath(outline, _stroke(color));
      canvas.drawLine(const Offset(8.4, 15.4), const Offset(15.1, 15.4), _stroke(color));
      return;
    }
    final roof = Path()
      ..moveTo(11.25, 0)
      ..lineTo(22.5, 10.25)
      ..lineTo(0, 10.25)
      ..close();
    final body = Path()
      ..addRRect(
        RRect.fromLTRBAndCorners(
          3.25,
          10,
          20.25,
          20.75,
          bottomLeft: const Radius.circular(1),
          bottomRight: const Radius.circular(1),
        ),
      );
    final slot = Path()..addRRect(RRect.fromLTRBR(7.75, 14.25, 15.75, 16.25, const Radius.circular(0.4)));
    final house = Path.combine(PathOperation.difference, Path.combine(PathOperation.union, roof, body), slot);
    canvas.drawPath(house, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_HousePainter old) => old.color != color || old.filled != filled;
}

/// 20 × 20.5 dp, the briefcase as the design draws it.
class BriefcaseIcon extends StatelessWidget {
  const BriefcaseIcon({super.key, required this.color, this.filled = true});

  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(20, 20.5), painter: _BriefcasePainter(color, filled));
}

class _BriefcasePainter extends CustomPainter {
  _BriefcasePainter(this.color, this.filled);

  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    if (!filled) {
      // The same case, as its line: the body, the handle over it, and the band dipping across.
      const h = _line / 2;
      final paint = _stroke(color);
      canvas.drawRRect(RRect.fromLTRBR(h, 3 + h, 20 - h, 20.5 - h, const Radius.circular(2.5)), paint);
      canvas.drawPath(
        Path()
          ..moveTo(7.2, 3.6)
          ..lineTo(7.2, 2.4)
          ..quadraticBezierTo(7.2, h, 8.9, h)
          ..lineTo(11.6, h)
          ..quadraticBezierTo(13.3, h, 13.3, 2.4)
          ..lineTo(13.3, 3.6),
        paint,
      );
      canvas.drawPath(
        Path()
          ..moveTo(h + 0.2, 10.4)
          ..quadraticBezierTo(10, 14.9, 20 - h - 0.2, 10.4),
        paint,
      );
      return;
    }
    final handle = Path.combine(
      PathOperation.difference,
      Path()..addRRect(RRect.fromLTRBR(6.5, 0, 14, 4, const Radius.circular(2))),
      Path()..addRect(const Rect.fromLTRB(8.5, 2, 12, 4)),
    );
    final body = Path()..addRRect(RRect.fromLTRBR(0, 3, 20, 20.5, const Radius.circular(2.5)));
    // The band dips from the sides to the middle, like the case's flap.
    final band = Path()
      ..moveTo(-1, 9.75)
      ..quadraticBezierTo(10, 13.75 + 0.2, 21, 9.75)
      ..lineTo(21, 11.25)
      ..quadraticBezierTo(10, 15.75 + 0.2, -1, 11.25)
      ..close();
    final briefcase = Path.combine(PathOperation.difference, Path.combine(PathOperation.union, handle, body), band);
    canvas.drawPath(briefcase, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_BriefcasePainter old) => old.color != color || old.filled != filled;
}
