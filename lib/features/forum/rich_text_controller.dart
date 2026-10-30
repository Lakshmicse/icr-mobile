import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'rich_document.dart';

/// The text controller behind the composer's details: a plain text field whose text carries marks. It draws bold,
/// italic, headings and links as they are written, keeps the marks on the right characters as the reader types,
/// pastes and deletes, applies the list rules (Enter, Backspace, "- "), and offers what the toolbar does.
///
/// The text in the field is the document's text, list prefixes ("• ", "1. ") included; [doc] is the snapshot a
/// screen sends and [RichDoc.toHtml] is the forum's HTML.
class RichTextController extends TextEditingController {
  RichTextController({RichDoc? doc, this.maxChars = 20000})
    : _buf = RichBuffer.of(doc ?? RichDoc.empty),
      super(text: doc?.text);

  /// The most words the details can hold (the forum's 20,000).
  final int maxChars;

  final RichBuffer _buf;

  /// The toolbar's choices for the next typed characters, when nothing is selected: bit → on or off.
  final Map<int, bool> _pending = {};

  /// Counts every change to the text or its marks, so a screen can tell them from a selection moving.
  int revision = 0;

  RichDoc get doc => _buf.snapshot();

  /// The characters the limit counts.
  int get plainLength => richPlainLength(_buf.text);

  // --- the field's edits -----------------------------------------------------------------------------------

  @override
  set value(TextEditingValue newValue) {
    if (newValue.text == _buf.text) {
      if (newValue.selection != value.selection) _pending.clear();
      super.value = newValue;
      return;
    }
    final length = newValue.text.length;
    final sel = newValue.selection;
    final extent = sel.isValid ? sel.extentOffset.clamp(0, length) : length;
    final base = sel.isValid ? sel.baseOffset.clamp(0, length) : length;
    final result = _buf.applyEdit(newValue.text, base, extent, pending: _pending, maxChars: maxChars);
    _pending.clear();
    revision++;
    if (!result.changed) {
      super.value = newValue;
      return;
    }
    super.value = TextEditingValue(
      text: result.text,
      selection: TextSelection(baseOffset: result.base, extentOffset: result.extent),
    );
  }

  /// Replaces the whole document (loading one), keeping its marks.
  void load(RichDoc doc) {
    _buf
      ..text = doc.text
      ..marks = List<int>.of(doc.marks)
      ..links = List<String>.of(doc.links);
    _pending.clear();
    revision++;
    _show(TextSelection.collapsed(offset: doc.text.length));
  }

  /// Shows the buffer as it is, without reading it back as an edit.
  void _show(TextSelection selection) {
    super.value = TextEditingValue(text: _buf.text, selection: selection);
    notifyListeners();
  }

  // --- what is drawn ---------------------------------------------------------------------------------------

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final base = style ?? const TextStyle();
    final text = _buf.text;
    if (text.isEmpty || text != value.text) return TextSpan(style: base, text: text);

    TextStyle styleOf(int m) {
      var s = base;
      if ((m & RichMark.heading) != 0) {
        s = s.copyWith(fontSize: (base.fontSize ?? 16) + 2, fontWeight: FontWeight.w700, height: 1.3);
      } else if ((m & RichMark.bold) != 0) {
        s = s.copyWith(fontWeight: FontWeight.w700);
      }
      if ((m & RichMark.italic) != 0) s = s.copyWith(fontStyle: FontStyle.italic);
      if (RichMark.link(m) > 0) {
        s = s.copyWith(color: AppColors.primary, decoration: TextDecoration.underline, decorationColor: AppColors.primary);
      }
      return s;
    }

    final composing = withComposing && value.composing.isValid && !value.composing.isCollapsed
        ? value.composing
        : TextRange.empty;
    final cuts = <int>{0, text.length};
    for (var i = 1; i < text.length; i++) {
      if (_buf.marks[i] != _buf.marks[i - 1]) cuts.add(i);
    }
    if (composing.isValid && !composing.isCollapsed) {
      cuts
        ..add(composing.start.clamp(0, text.length))
        ..add(composing.end.clamp(0, text.length));
    }
    final points = cuts.toList()..sort();
    final children = <InlineSpan>[];
    for (var i = 0; i + 1 < points.length; i++) {
      final from = points[i];
      final to = points[i + 1];
      var s = styleOf(_buf.marks[from]);
      if (composing.isValid && !composing.isCollapsed && from >= composing.start && to <= composing.end) {
        s = s.merge(const TextStyle(decoration: TextDecoration.underline));
      }
      children.add(TextSpan(text: text.substring(from, to), style: s));
    }
    return TextSpan(style: base, children: children);
  }

  // --- the toolbar -----------------------------------------------------------------------------------------

  (int, int) get _range {
    final s = selection;
    final length = _buf.text.length;
    if (!s.isValid) return (length, length);
    return (s.start.clamp(0, length), s.end.clamp(0, length));
  }

  bool get _collapsed => _range.$1 == _range.$2;

  /// The marks a character typed now would take: the toolbar's choices over those of the characters around.
  int get _typingMarks {
    final (at, _) = _range;
    final lines = _buf.lines();
    final line = lines[_buf.lineIndexOf(lines, at)];
    var m = 0;
    if (at > line.contentStart && at - 1 < _buf.marks.length) {
      m = _buf.marks[at - 1];
    } else if (at < line.end && at >= line.contentStart) {
      m = _buf.marks[at];
    }
    m &= RichMark.inline | RichMark.heading;
    _pending.forEach((bit, on) {
      m = on ? m | bit : m & ~bit;
    });
    return m;
  }

  bool _inlineActive(int bit) {
    final (a, b) = _range;
    if (a == b) return (_typingMarks & bit) != 0;
    return _buf.allHave(a, b, bit);
  }

  bool get isBold => _inlineActive(RichMark.bold);
  bool get isItalic => _inlineActive(RichMark.italic);

  /// The lines the selection touches (a selection ending at the start of a line does not touch it).
  List<RichLine> get _touched {
    final (a, b) = _range;
    final lines = _buf.lines();
    final first = _buf.lineIndexOf(lines, a);
    var last = _buf.lineIndexOf(lines, b);
    if (b > a && last > first && lines[last].start == b) last--;
    return lines.sublist(first, last + 1);
  }

  bool get isHeading {
    final lines = _touched;
    if (_collapsed && lines.single.kind != RichLineKind.heading && lines.single.contentLength == 0) {
      return _pending[RichMark.heading] ?? false;
    }
    return lines.every((l) => l.kind == RichLineKind.heading);
  }

  bool get isBulleted => _touched.every((l) => l.kind == RichLineKind.bullet);
  bool get isNumbered => _touched.every((l) => l.kind == RichLineKind.number);

  void toggleBold() => _toggleInline(RichMark.bold);
  void toggleItalic() => _toggleInline(RichMark.italic);

  void _toggleInline(int bit) {
    final (a, b) = _range;
    if (a == b) {
      _pending[bit] = !((_typingMarks & bit) != 0);
      notifyListeners();
      return;
    }
    final on = !_buf.allHave(a, b, bit);
    _buf.setMark(a, b, bit, on);
    // Bold under a heading is the heading's own; the heading keeps the weight.
    _changedMarks();
  }

  /// Makes the lines the selection touches a heading, or plain again when they all are one.
  void toggleHeading() {
    final lines = _touched;
    final turnOn = !isHeading;
    final selection = _range;
    final touched = {for (final l in lines) l.start};
    final offsets = _buf.rewriteLines([selection.$1, selection.$2], (i, line) {
      if (!touched.contains(line.start)) return null;
      return (prefix: '', heading: turnOn);
    });
    if (_collapsed && lines.single.contentLength == 0) {
      _pending[RichMark.heading] = turnOn;
    } else {
      _pending.remove(RichMark.heading);
    }
    _afterLines(offsets);
  }

  void toggleBullets() => _toggleList(RichLineKind.bullet);
  void toggleNumbers() => _toggleList(RichLineKind.number);

  void _toggleList(RichLineKind kind) {
    final lines = _touched;
    final turnOn = !lines.every((l) => l.kind == kind);
    final selection = _range;
    final touched = {for (final l in lines) l.start};
    final offsets = _buf.rewriteLines([selection.$1, selection.$2], (i, line) {
      if (!touched.contains(line.start)) return null;
      if (!turnOn) return (prefix: '', heading: null);
      return (prefix: kind == RichLineKind.bullet ? bulletPrefix : '1. ', heading: false);
    });
    _pending.remove(RichMark.heading);
    // Numbers count on from 1 in each run.
    final fixed = _buf.normalise(offsets);
    _afterLines(fixed);
  }

  /// The address of the link at the selection, or null.
  String? get currentLink {
    final (a, b) = _range;
    return _buf.hrefAt(a == b ? a : a);
  }

  /// A link needs words to attach to: a selection, or the caret on a link already.
  bool get canLink {
    final (a, b) = _range;
    if (a == b) return _buf.linkRangeAt(a) != null;
    return _buf.wordRanges(a, b).isNotEmpty;
  }

  /// Links the selected words (or the link under the caret) to [href]; null or empty takes the link off.
  void setLink(String? href) {
    final (a, b) = _range;
    var from = a;
    var to = b;
    if (a == b) {
      final r = _buf.linkRangeAt(a);
      if (r == null) return;
      from = r.$1;
      to = r.$2;
    } else {
      // A selection that touches a link takes the whole of it.
      final startLink = _buf.linkRangeAt(a);
      final endLink = _buf.linkRangeAt(b);
      if (startLink != null && startLink.$1 < from) from = startLink.$1;
      if (endLink != null && endLink.$2 > to) to = endLink.$2;
    }
    _buf.setLink(from, to, href == null || href.trim().isEmpty ? null : href.trim());
    _changedMarks();
  }

  void _changedMarks() {
    revision++;
    _show(selection.isValid ? selection : TextSelection.collapsed(offset: _buf.text.length));
  }

  void _afterLines(List<int> offsets) {
    revision++;
    _show(TextSelection(baseOffset: offsets[0], extentOffset: offsets[1]));
  }
}
