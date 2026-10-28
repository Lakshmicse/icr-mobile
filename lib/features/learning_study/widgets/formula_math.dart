import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../../../core/theme/app_colors.dart';
import '../study_format.dart';
import '../study_styles.dart';

/// A formula drawn as math: fractions, exponents and sums laid out as on paper (`flutter_math_fork`, the KaTeX
/// port; the website draws the same strings with KaTeX).
///
/// The stored LaTeX goes through [prepareTex] first, because the editors type words without `\text{}`. A long
/// formula wraps across lines after its `=` and its top-level operators (never inside brackets), the way a long
/// equation is set; a formula that fits is one line. An expression that is not LaTeX, or LaTeX the renderer cannot
/// read, is shown as plain text in a monospace line: a formula is never blank and never an error message.
class FormulaMath extends StatelessWidget {
  const FormulaMath({super.key, required this.expression, this.fontSize = 22});

  final FormulaExpression expression;
  final double fontSize;

  /// The parse of an expression, or null when it cannot be drawn.
  @visibleForTesting
  static Math? parse(String tex, {double fontSize = 22, Color color = AppColors.onSurface, String? fallback}) {
    final prepared = prepareTex(tex);
    if (prepared.isEmpty) return null;
    final math = _math(prepared, fontSize, color, fallback);
    return math.parseError == null ? math : null;
  }

  static Math _math(String tex, double fontSize, Color color, String? fallback) => Math.tex(
    tex,
    mathStyle: MathStyle.display,
    textStyle: TextStyle(fontSize: fontSize, color: color),
    settings: const TexParserSettings(strict: Strict.ignore),
    // A formula the layout cannot build is its plain text, never the renderer's error message.
    onErrorFallback: (_) => Text(fallback ?? tex, style: StudyText.mono),
  );

  @override
  Widget build(BuildContext context) {
    final plain = plainFormula(expression);
    final tex = expression.tex;
    final whole = tex == null ? null : parse(tex, fontSize: fontSize, fallback: plain);
    return Semantics(
      label: 'Formula: $plain',
      excludeSemantics: true,
      child: whole == null
          ? SelectableText(
              plain,
              key: const ValueKey('formula-plain'),
              style: StudyText.mono,
              textAlign: TextAlign.center,
            )
          : _Lines(key: const ValueKey('formula-math'), tex: prepareTex(tex!), fontSize: fontSize, plain: plain),
    );
  }
}

/// One piece of a formula: the maths up to a top-level sign, and the sign.
@visibleForTesting
class FormulaPiece {
  const FormulaPiece(this.tex, this.sign, {this.relation = false});

  final String tex;

  /// The sign the piece ends with (`=`, `+`, `\div`), or null for the last piece.
  final String? sign;
  final bool relation;
}

const _relations = {r'\approx', r'\geq', r'\leq', r'\neq', r'\to'};
const _operators = {r'\times', r'\div', r'\cdot', r'\pm'};

/// Cuts prepared LaTeX after each `=`, `<`, `>`, `+`, `-` and each of the signs above that stands outside every
/// bracket, brace and `\text{}`. A sign with nothing before it (a minus in front, or one after another sign) is a
/// sign of the number, and stays with its piece.
@visibleForTesting
List<FormulaPiece> splitPieces(String tex) {
  final pieces = <FormulaPiece>[];
  final current = StringBuffer();
  var depth = 0;
  var i = 0;

  void sign(String s, {required bool relation}) {
    if (current.toString().trim().isEmpty) {
      current.write(s); // unary
      return;
    }
    pieces.add(FormulaPiece(current.toString().trim(), s, relation: relation));
    current.clear();
  }

  final letter = RegExp('[A-Za-z]');
  while (i < tex.length) {
    final c = tex[i];
    if (c == r'\') {
      var j = i + 1;
      while (j < tex.length && letter.hasMatch(tex[j])) {
        j++;
      }
      if (j == i + 1) j = (i + 2).clamp(0, tex.length); // an escaped symbol: \% \{ \,
      final command = tex.substring(i, j);
      if (depth == 0 && _relations.contains(command)) {
        sign(command, relation: true);
      } else if (depth == 0 && _operators.contains(command)) {
        sign(command, relation: false);
      } else {
        current.write(command);
      }
      i = j;
      continue;
    }
    if ('{(['.contains(c)) depth++;
    if ('})]'.contains(c)) depth = depth > 0 ? depth - 1 : 0;
    if (depth == 0 && (c == '=' || c == '<' || c == '>')) {
      sign(c, relation: true);
    } else if (depth == 0 && (c == '+' || c == '-')) {
      sign(c, relation: false);
    } else {
      current.write(c);
    }
    i++;
  }
  pieces.add(FormulaPiece(current.toString().trim(), null));
  return [
    for (final p in pieces)
      if (p.tex.isNotEmpty || p.sign != null) p,
  ];
}

/// The formula in as many lines as it needs. TeX puts 5/18 em round a relation and 4/18 em round an operator;
/// each piece is drawn on its own with that space put back by hand, and a sign stays at the end of its line with the
/// piece before it.
class _Lines extends StatelessWidget {
  const _Lines({super.key, required this.tex, required this.fontSize, required this.plain});

  final String tex;
  final double fontSize;
  final String plain;

  @override
  Widget build(BuildContext context) {
    final pieces = splitPieces(tex);
    Widget draw(String t) => FormulaMath._math(t, fontSize, AppColors.onSurface, plain);
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 6,
      children: [
        for (final p in pieces)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (p.tex.isNotEmpty) draw(p.tex),
              if (p.sign != null) ...[
                SizedBox(width: fontSize * (p.relation ? 5 / 18 : 4 / 18)),
                draw(p.sign!),
                SizedBox(width: fontSize * (p.relation ? 5 / 18 : 4 / 18)),
              ],
            ],
          ),
      ],
    );
  }
}
