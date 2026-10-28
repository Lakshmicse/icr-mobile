import 'package:flutter/material.dart';

/// The two tab icons the design draws itself (traced from it): a house with a
/// slot in its front, and a briefcase crossed by a curved band. Both are
/// filled, in the tab's colour.

/// 22.5 × 20.75 dp, the house as the design draws it.
class HouseIcon extends StatelessWidget {
  const HouseIcon({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(size: const Size(22.5, 20.75), painter: _HousePainter(color));
}

class _HousePainter extends CustomPainter {
  _HousePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
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
  bool shouldRepaint(_HousePainter old) => old.color != color;
}

/// 20 × 20.5 dp, the briefcase as the design draws it.
class BriefcaseIcon extends StatelessWidget {
  const BriefcaseIcon({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(size: const Size(20, 20.5), painter: _BriefcasePainter(color));
}

class _BriefcasePainter extends CustomPainter {
  _BriefcasePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
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
  bool shouldRepaint(_BriefcasePainter old) => old.color != color;
}
