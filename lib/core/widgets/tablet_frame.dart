import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// On a wide window — a tablet held sideways, a desktop window — the app sits in a centred column no wider than
/// [maxWidth], white at the sides with a hairline at each edge: the website's centred page frame, so a feed line,
/// a list row or a form never runs the width of a 10-inch screen (owner, 6 Nov 2026: the app should be friendly
/// with tablets). A phone, or a tablet held upright (under [from] dp — Material's "expanded" width), is left alone. What is inside reads the
/// column's width from `MediaQuery`, so a screen that lays itself out by the window width sees the column.
class TabletFrame extends StatelessWidget {
  const TabletFrame({super.key, required this.child, this.maxWidth = 840, this.from = 840});

  final Widget child;

  /// The column's width on a wide window.
  final double maxWidth;

  /// The window width from which the column applies.
  final double from;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < from) return child;
        final media = MediaQuery.of(context);
        return ColoredBox(
          color: Colors.white,
          child: Center(
            child: Container(
              key: const ValueKey('tablet-frame'),
              // The hairlines sit outside the column, so what is inside has the whole [maxWidth].
              width: maxWidth + 2,
              decoration: const BoxDecoration(
                border: Border.symmetric(vertical: BorderSide(color: AppColors.outlineVariant)),
              ),
              child: MediaQuery(
                data: media.copyWith(size: Size(maxWidth, media.size.height)),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
