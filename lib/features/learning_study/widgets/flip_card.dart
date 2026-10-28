import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A card that turns over: [front] until [showBack] goes true, then a half turn about its vertical axis (with
/// perspective, so the near edge grows as it comes round) to [back]. The face is swapped at the edge-on moment,
/// and the back is drawn mirrored so its text reads the right way.
///
/// The flip is driven by [showBack] (the controller owns whether the card is turned), not by taps: [onTap] is
/// told about them. With the system's "remove animations" setting on, the faces swap with no turn.
class FlipCard extends StatefulWidget {
  const FlipCard({
    super.key,
    required this.showBack,
    required this.front,
    required this.back,
    required this.onTap,
    this.duration = const Duration(milliseconds: 520),
    this.semanticLabel,
  });

  /// Strength of the perspective: enough to see the near edge grow, not enough to swing the card over its neighbours.
  static const perspective = 0.0008;

  final bool showBack;
  final Widget front;
  final Widget back;
  final VoidCallback onTap;
  final Duration duration;

  /// What a screen reader says for the card as a whole (the face that is showing, and what a tap does).
  final String? semanticLabel;

  @override
  State<FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<FlipCard> with SingleTickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.showBack ? 1 : 0,
  );
  late final Animation<double> _curve = CurvedAnimation(parent: _turn, curve: Curves.easeInOutCubic);

  @override
  void didUpdateWidget(FlipCard old) {
    super.didUpdateWidget(old);
    if (old.showBack == widget.showBack) return;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _turn.value = widget.showBack ? 1 : 0;
    } else {
      _turn.animateTo(widget.showBack ? 1 : 0);
    }
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: widget.semanticLabel,
      onTap: widget.onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _curve,
          builder: (context, _) {
            final angle = _curve.value * math.pi;
            final onBack = angle > math.pi / 2;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, FlipCard.perspective)
                ..rotateY(angle),
              child: onBack
                  ? Transform(alignment: Alignment.center, transform: Matrix4.rotationY(math.pi), child: widget.back)
                  : widget.front,
            );
          },
        ),
      ),
    );
  }
}
