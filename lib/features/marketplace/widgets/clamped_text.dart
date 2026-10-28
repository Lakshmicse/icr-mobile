import 'package:flutter/material.dart';

/// Text kept to [maxLines] lines, cut at a word and ended with an ellipsis set
/// close against the last word ("...IAQ particulate…"), as the designs set a
/// clamped description. Flutter's own ellipsis keeps the space before it.
class ClampedText extends StatelessWidget {
  const ClampedText(this.text, {super.key, required this.style, this.maxLines = 2});

  final String text;
  final TextStyle style;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, box) {
        final shown = clampToLines(text, style, box.maxWidth, maxLines, scaler);
        return Text(shown, style: style, maxLines: maxLines, softWrap: true);
      },
    );
  }
}

/// [text] cut to what fits in [maxLines] lines of [width] with a closing "…", or
/// all of it when it fits.
String clampToLines(
  String text,
  TextStyle style,
  double width,
  int maxLines, [
  TextScaler scaler = TextScaler.noScaling,
]) {
  bool fits(String candidate) {
    final painter = TextPainter(
      text: TextSpan(text: candidate, style: style),
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      textScaler: scaler,
    )..layout(maxWidth: width);
    final exceeded = painter.didExceedMaxLines;
    painter.dispose();
    return !exceeded;
  }

  final trimmed = text.trim();
  if (width <= 0 || fits(trimmed)) return trimmed;
  var words = trimmed.split(RegExp(r'\s+'));
  while (words.length > 1) {
    words = words.sublist(0, words.length - 1);
    final cut = words.join(' ').replaceFirst(RegExp(r'[\s,;:.\-–—]+$'), '');
    if (fits('$cut…')) return '$cut…';
  }
  return '${words.first}…';
}
