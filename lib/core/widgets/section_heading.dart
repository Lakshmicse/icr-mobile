import 'package:flutter/material.dart';

import '../theme/app_text.dart';

/// "Recommended Jobs for You ........ View More": the heading of a list
/// section, 20 dp tall, with the screens' 10 dp margin.
class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.title,
    this.action,
    this.onAction,
    this.padding = const EdgeInsets.only(left: 10, right: 21),
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            Expanded(
              child: Text(title, style: AppText.sectionTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            if (action != null)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onAction,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 3, top: 1),
                  child: Text(action!, style: AppText.sectionAction),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A 1 dp rule.
class Hairline extends StatelessWidget {
  const Hairline({super.key, this.color = const Color(0xFFE1E3E4), this.indent = 0, this.endIndent = 0});

  final Color color;
  final double indent;
  final double endIndent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: indent, right: endIndent),
      child: ColoredBox(
        color: color,
        child: const SizedBox(height: 1, width: double.infinity),
      ),
    );
  }
}
