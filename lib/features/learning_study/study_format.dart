/// How a Knowledge Center formula is stored and how the app reads it (the website's `resources/formula.ts`).
///
/// A formula card's `back` holds the expression first and, after a blank line, an optional note on how to read it.
/// The expression is LaTeX when it is wrapped in `$$ ... $$`; anything else is plain text, shown as typed.
library;

import 'study_models.dart';

/// Splits a card's `back` into the expression and the note after the first blank line.
({String expression, String note}) splitBack(String back) {
  final parts = back.split(RegExp(r'\n\s*\n'));
  final expression = parts.isEmpty ? '' : parts.first.trim();
  final note = parts.skip(1).join('\n\n');
  return (expression: expression, note: stripInvisible(note).trim().isEmpty ? '' : note.trim());
}

/// An expression as stored: typeset LaTeX (`tex`) or plain text (`text`), exactly one of them.
class FormulaExpression {
  const FormulaExpression.tex(String this.tex) : text = null;
  const FormulaExpression.text(String this.text) : tex = null;

  final String? tex;
  final String? text;

  bool get isTex => tex != null;
}

final _texBlock = RegExp(r'^\$\$([\s\S]*)\$\$$');

FormulaExpression parseExpression(String expression) {
  final m = _texBlock.firstMatch(expression.trim());
  return m == null ? FormulaExpression.text(expression.trim()) : FormulaExpression.tex(m.group(1)!.trim());
}

/// The invisible characters an editor's paste leaves in a formula (zero-width spaces and joiners, the byte-order
/// mark), and a no-break space as an ordinary one.
String stripInvisible(String s) =>
    s.replaceAll(RegExp('[\u200B\u200C\u200D\u2060\uFEFF]'), '').replaceAll('\u00A0', ' ');

// ---------------------------------------------------------------------------------------------------------------
// LaTeX preparation
// ---------------------------------------------------------------------------------------------------------------

const _symbols = <String, String>{
  '×': r' \times ', // times sign
  '÷': r' \div ', // division sign
  '−': ' - ', // minus sign: always a subtraction (a hyphen inside a word is the plain one)
  '–': ' - ', // en dash
  '—': ' - ', // em dash
  '∑': r' \sum ', // n-ary summation
  'Σ': r' \sum ', // capital sigma
  '≈': r' \approx ',
  '≥': r' \geq ',
  '≤': r' \leq ',
  '≠': r' \neq ',
  '±': r' \pm ',
  '·': r' \cdot ', // middle dot
  '•': r' \cdot ', // bullet
  '∞': r' \infty ',
  'π': r' \pi ',
  '²': '^{2}', // superscript two
  '³': '^{3}', // superscript three
  '₹': r'\text{Rs }', // rupee sign
  '→': r' \to ', // arrow
};

/// Commands whose braced argument is already text: copied as they are.
const _textCommands = {
  'text',
  'textbf',
  'textit',
  'mathrm',
  'mathbf',
  'mathit',
  'mbox',
  'operatorname',
  'textrm',
  'hbox',
};

bool _isLetter(String c) {
  final u = c.codeUnitAt(0);
  return (u >= 65 && u <= 90) || (u >= 97 && u <= 122);
}

/// What the website's KaTeX shows for these formulas is words run together in italics ("PortfolioOccupancy=..."),
/// because the editors type `Portfolio Occupancy= Occupied Area \div Total Area ×100` without wrapping the words
/// in `\text{}`, and math mode drops the spaces. This makes the expression read the way it was written:
///
///  * invisible characters are dropped and the typed symbols (× ÷ − ∑ ...) become their commands;
///  * a run of two or more letters, with the spaces and dots between its words, becomes `\text{...}`
///    (one letter stays a variable: `r`, `n`, `C`);
///  * a bare `%`, `&` or `#` is escaped, which TeX would otherwise read as a comment or an alignment.
///
/// Anything already inside `\text{}` or the like, and every other command, is left alone.
String prepareTex(String tex) {
  var s = stripInvisible(tex);
  _symbols.forEach((k, v) => s = s.replaceAll(k, v));
  final out = StringBuffer();
  var i = 0;
  while (i < s.length) {
    final c = s[i];
    if (c == r'\') {
      var j = i + 1;
      if (j < s.length && _isLetter(s[j])) {
        while (j < s.length && _isLetter(s[j])) {
          j++;
        }
        final name = s.substring(i + 1, j);
        if (_textCommands.contains(name)) {
          var k = j;
          while (k < s.length && s[k] == ' ') {
            k++;
          }
          if (k < s.length && s[k] == '{') {
            final close = _closingBrace(s, k);
            out.write(s.substring(i, close));
            i = close;
            continue;
          }
        }
        out.write(s.substring(i, j));
        i = j;
      } else {
        // An escaped symbol (`\%`, `\{`, `\,`) or a lone backslash at the end.
        final end = j < s.length ? j + 1 : j;
        out.write(s.substring(i, end));
        i = end;
      }
      continue;
    }
    if (c == '%' || c == '&' || c == '#') {
      out.write('\\$c');
      i++;
      continue;
    }
    if (_isLetter(c)) {
      var j = i;
      var lastLetter = i;
      while (j < s.length) {
        final d = s[j];
        if (_isLetter(d)) {
          lastLetter = j;
          j++;
        } else if (d == ' ' || d == '.' || d == "'" || (d == '-' && _hyphenInWord(s, j))) {
          j++;
        } else {
          break;
        }
      }
      final run = s.substring(i, lastLetter + 1);
      final letters = run.replaceAll(RegExp('[^A-Za-z]'), '').length;
      if (letters >= 2) {
        out.write('\\text{${run.replaceAll(RegExp(r'\s+'), ' ')}}');
        // What followed the last letter (a dot, a space) stays, so the words do not touch the next thing.
        final trailing = s.substring(lastLetter + 1, j);
        out.write(trailing.replaceAll(RegExp(r'\s+'), ''));
        if (trailing.contains(' ')) out.write(' ');
      } else {
        out.write(run);
        if (lastLetter + 1 < j) out.write(s.substring(lastLetter + 1, j));
      }
      i = j;
      continue;
    }
    out.write(c);
    i++;
  }
  return out.toString().replaceAll(RegExp(r' {2,}'), ' ').trim();
}

/// A `-` between two words of two letters or more ("Semi-Variable", "Fit-Out") belongs to the word; between single
/// letters (`r-g`) it is a subtraction.
bool _hyphenInWord(String s, int at) {
  var before = 0;
  for (var i = at - 1; i >= 0 && _isLetter(s[i]); i--) {
    before++;
  }
  var after = 0;
  for (var i = at + 1; i < s.length && _isLetter(s[i]); i++) {
    after++;
  }
  return before >= 2 && after >= 2;
}

/// The index just past the `}` that closes the `{` at [open] (the end of the string when it never closes).
int _closingBrace(String s, int open) {
  var depth = 0;
  for (var i = open; i < s.length; i++) {
    if (s[i] == r'\') {
      i++;
    } else if (s[i] == '{') {
      depth++;
    } else if (s[i] == '}') {
      depth--;
      if (depth == 0) return i + 1;
    }
  }
  return s.length;
}

// ---------------------------------------------------------------------------------------------------------------
// Plain text
// ---------------------------------------------------------------------------------------------------------------

/// A formula as text a person can paste into a note or a spreadsheet: `PV = FV ÷ (1+r)^n`. LaTeX is turned back
/// into the words and signs it was typed from; a plain-text expression comes back as it is.
String plainFormula(FormulaExpression expression) {
  final tex = expression.tex;
  if (tex == null) return expression.text!.trim();
  var s = stripInvisible(tex);
  // `\frac{a}{b}` and `\sqrt{x}`, innermost first.
  final frac = RegExp(r'\\d?frac\s*\{([^{}]*)\}\s*\{([^{}]*)\}');
  final sqrt = RegExp(r'\\sqrt\s*\{([^{}]*)\}');
  for (var guard = 0; guard < 8 && (frac.hasMatch(s) || sqrt.hasMatch(s)); guard++) {
    s = s.replaceAllMapped(frac, (m) => '(${m[1]}) / (${m[2]})').replaceAllMapped(sqrt, (m) => '√(${m[1]})');
  }
  s = s
      .replaceAllMapped(
        RegExp(r'\\(?:text|textbf|textit|mathrm|mathbf|mathit|mbox|operatorname|textrm)\s*\{([^{}]*)\}'),
        (m) => m[1]!,
      )
      .replaceAll(RegExp(r'\\(?:left|right)'), '')
      .replaceAll(r'\div', ' ÷ ')
      .replaceAll(r'\times', ' × ')
      .replaceAll(r'\cdot', ' · ')
      .replaceAll(r'\sum', '∑')
      .replaceAll(r'\approx', ' ≈ ')
      .replaceAll(r'\geq', ' ≥ ')
      .replaceAll(r'\leq', ' ≤ ')
      .replaceAll(r'\neq', ' ≠ ')
      .replaceAll(r'\pm', ' ± ')
      .replaceAll(r'\pi', 'π')
      .replaceAll(r'\infty', '∞')
      .replaceAll(RegExp(r'\\[,;:! ]'), ' ')
      .replaceAll(r'\%', '%')
      .replaceAll(r'\&', '&')
      .replaceAll(r'\#', '#');
  // `^{n}` → `^n`, `^{n+1}` → `^(n+1)`, the same for subscripts.
  s = s.replaceAllMapped(RegExp(r'([\^_])\{([^{}]*)\}'), (m) {
    final inner = m[2]!.trim();
    return RegExp(r'^[A-Za-z0-9]+$').hasMatch(inner) ? '${m[1]}$inner' : '${m[1]}($inner)';
  });
  // The signs typed as characters read with air around them, as the ones that came from commands do.
  s = s
      .replaceAll('−', ' - ')
      .replaceAll('–', ' - ')
      .replaceAll('×', ' × ')
      .replaceAll('÷', ' ÷ ')
      .replaceAll(RegExp(r'\s*=\s*'), ' = ');
  return s.replaceAll(RegExp(r'[ \t]{2,}'), ' ').replaceAll(RegExp(r'\s*\n\s*'), ' ').trim();
}

// ---------------------------------------------------------------------------------------------------------------
// The note: variables
// ---------------------------------------------------------------------------------------------------------------

/// "PV = Present Value": a symbol and what it stands for.
class FormulaVariable {
  const FormulaVariable(this.symbol, this.meaning);

  final String symbol;
  final String meaning;
}

final _variableLine = RegExp(r'^\s*([^=:\s][^=:]{0,13}?)\s*[=:]\s*(\S.*)$');

/// The note read as a list of variables, when every line of it is `symbol = meaning`; null for a note that is a
/// sentence or two, which the screen shows as it is.
List<FormulaVariable>? parseVariables(String note) {
  final lines = stripInvisible(note).split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
  if (lines.isEmpty) return null;
  final out = <FormulaVariable>[];
  for (final line in lines) {
    final m = _variableLine.firstMatch(line);
    if (m == null) return null;
    out.add(FormulaVariable(m.group(1)!.trim(), m.group(2)!.trim()));
  }
  return out;
}

// ---------------------------------------------------------------------------------------------------------------
// Examples
// ---------------------------------------------------------------------------------------------------------------

final _exampleSeparator = RegExp(r'\n[ \t]*-{3,}[ \t]*\n');

/// A free-text `example` field as one or more examples (separated by a line of `---`).
List<String> splitExamples(String? example) =>
    (example ?? '').split(_exampleSeparator).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

/// What a formula card shows as worked examples: its examples in parts when it has them, else its free text.
({List<FormulaExample> parts, List<String> text}) examplesOf(StudyCard card) {
  final parts = card.examples.where((e) => e.hasContent).toList();
  return (parts: parts, text: parts.isEmpty ? splitExamples(card.example) : const []);
}

// ---------------------------------------------------------------------------------------------------------------
// Searching
// ---------------------------------------------------------------------------------------------------------------

/// The words of a search, lower-cased; every one of them has to be somewhere in a card.
List<String> queryTerms(String query) => query.toLowerCase().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

bool matchesTerms(List<String> terms, Iterable<String?> haystacks) {
  if (terms.isEmpty) return true;
  final text = haystacks.whereType<String>().join(' \n ').toLowerCase();
  return terms.every(text.contains);
}

/// Both faces and the tags are searched: someone who remembers "the one about deferred maintenance" is remembering
/// the back of a card. A formula is also found by its expression, note and worked examples.
bool cardMatches(StudyCard card, List<String> terms) {
  if (terms.isEmpty) return true;
  final parts = <String?>[card.front, card.back, card.example, card.category, ...card.tags, card.topicTitle];
  for (final e in card.examples) {
    parts.addAll([
      for (final g in e.given) ...[g.label, g.value],
      e.working,
      e.result,
      e.analysis,
      e.decision,
    ]);
  }
  final expr = parseExpression(splitBack(card.back).expression);
  if (expr.isTex) parts.add(plainFormula(expr));
  return matchesTerms(terms, parts);
}

/// "1 card", "200 cards".
String cardsLabel(int n) => '$n ${n == 1 ? 'card' : 'cards'}';

/// "1 formula", "22 formulas".
String formulasLabel(int n) => '$n ${n == 1 ? 'formula' : 'formulas'}';

// ---------------------------------------------------------------------------------------------------------------
// Copying
// ---------------------------------------------------------------------------------------------------------------

/// What "Copy" puts on the clipboard for a formula: its name, the expression as plain text, then its variables (or
/// its note), one to a line:
///
///     Present Value (PV)
///     PV = FV ÷ (1+r)^n
///     PV = Present Value
///     FV = Future Value
String formulaCopyText(StudyCard card) {
  final parts = splitBack(card.back);
  final lines = <String>[card.front, plainFormula(parseExpression(parts.expression))];
  if (parts.note.isNotEmpty) {
    final variables = parseVariables(parts.note);
    if (variables != null) {
      lines.addAll([for (final v in variables) '${v.symbol} = ${v.meaning}']);
    } else {
      lines.add(parts.note);
    }
  }
  return lines.where((l) => l.trim().isNotEmpty).join('\n');
}
