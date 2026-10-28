import 'dart:async';

import 'package:flutter/material.dart';

/// Whether the bottom bar is showing, moved by what the person scrolls, as
/// LinkedIn does: down hides the bar, up brings it back, and it is always there
/// at the top of a page. Feed the screen's scroll notifications to [onScroll]:
///
///     NotificationListener<ScrollNotification>(onNotification: bar.onScroll, child: …)
class BarVisibility extends ChangeNotifier {
  /// Scrolling this far down (dp) hides the bar; this far up brings it back.
  static const hideAfter = 24.0;
  static const showAfter = 12.0;

  /// A page that scrolls less than this never hides the bar: hiding it would
  /// grow the viewport past the content and the page would jump back.
  static const minScrollable = 160.0;

  /// A change of the bar's size moves every list's extents for a moment; what
  /// that does to the scroll offset is not the person scrolling.
  static const settle = Duration(milliseconds: 350);

  bool _shown = true;
  bool get shown => _shown;

  double _travel = 0;
  bool _settling = false;
  Timer? _timer;

  /// Always false, so a scroll keeps bubbling to whoever else listens.
  bool onScroll(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical || n is! ScrollUpdateNotification || _settling) return false;
    final m = n.metrics;
    if (m.pixels <= m.minScrollExtent + 2) {
      _travel = 0;
      show();
      return false;
    }
    if (m.maxScrollExtent - m.minScrollExtent < minScrollable) return false;
    final delta = n.scrollDelta ?? 0;
    if (delta == 0) return false;
    // A change of direction starts the count again.
    if ((delta > 0) != (_travel > 0)) _travel = 0;
    _travel += delta;
    if (_travel > hideAfter) {
      _set(false);
    } else if (_travel < -showAfter) {
      _set(true);
    }
    return false;
  }

  void show() => _set(true);

  void _set(bool shown) {
    _travel = 0;
    if (_shown == shown) return;
    _shown = shown;
    _settling = true;
    _timer?.cancel();
    _timer = Timer(settle, () => _settling = false);
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// A bar that slides away (and gives its room back to the page) while
/// [controller] says hidden. The strip under it that the system's own bar
/// covers stays, so the page never runs under the gesture area.
class HidingBar extends StatelessWidget {
  const HidingBar({super.key, required this.controller, required this.barHeight, required this.child});

  final BarVisibility controller;

  /// The bar's own height, without the bottom inset it adds.
  final double barHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewPaddingOf(context).bottom;
    final hiddenFactor = inset / (barHeight + inset);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => ClipRect(
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.bottomCenter,
          heightFactor: controller.shown ? 1 : hiddenFactor,
          child: IgnorePointer(ignoring: !controller.shown, child: child),
        ),
      ),
    );
  }
}
