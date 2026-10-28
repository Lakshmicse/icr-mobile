import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The grab bar at the top of a sheet.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key, this.top = 13, this.height = 37, this.rule = true});

  /// Where the bar sits, from the sheet's top edge.
  final double top;

  /// The handle area's full height, the rule under it included.
  final double height;
  final bool rule;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          Positioned(
            top: top,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppColors.slate300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
          ),
          if (rule)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ColoredBox(color: AppColors.slate100, child: SizedBox(height: 1)),
            ),
        ],
      ),
    );
  }
}

/// A bottom sheet that blurs and dims the page behind it as it opens, like
/// the Discover sheet.
class BlurredSheetRoute<T> extends ModalBottomSheetRoute<T> {
  BlurredSheetRoute({
    required super.builder,
    required super.isScrollControlled,
    super.backgroundColor = Colors.transparent,
    super.modalBarrierColor = AppColors.sheetScrim,
    super.constraints,
    super.useSafeArea,
    super.enableDrag,
    this.blur = 2,
  });

  final double blur;

  @override
  Widget buildModalBarrier() {
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedBuilder(
          animation: animation!,
          builder: (context, _) => ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blur * animation!.value, sigmaY: blur * animation!.value),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        super.buildModalBarrier(),
      ],
    );
  }
}

/// Opens a detail sheet that leaves [topInset] of the page visible above it:
/// a white panel with the top corners rounded, a 1 dp top edge, the handle,
/// [body] scrolling under it and [bottomBar] pinned at the foot.
Future<T?> showDetailSheet<T>(
  BuildContext context, {
  required WidgetBuilder body,
  WidgetBuilder? bottomBar,
  double topInset = 72,
  double handleTop = 13,
  double handleHeight = 38,
}) {
  return Navigator.of(context).push(
    BlurredSheetRoute<T>(
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DetailSheetFrame(
        topInset: topInset,
        handleTop: handleTop,
        handleHeight: handleHeight,
        body: body(context),
        bottomBar: bottomBar?.call(context),
      ),
    ),
  );
}

class DetailSheetFrame extends StatelessWidget {
  const DetailSheetFrame({
    super.key,
    required this.body,
    this.bottomBar,
    this.topInset = 72,
    this.handleTop = 13,
    this.handleHeight = 38,
  });

  final Widget body;
  final Widget? bottomBar;
  final double topInset;
  final double handleTop;
  final double handleHeight;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height - MediaQuery.paddingOf(context).top - topInset;
    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: ColoredBox(
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ColoredBox(color: AppColors.slate200, child: SizedBox(height: 1)),
              SheetHandle(top: handleTop - 1, height: handleHeight - 1),
              Expanded(child: body),
              ?bottomBar,
            ],
          ),
        ),
      ),
    );
  }
}
