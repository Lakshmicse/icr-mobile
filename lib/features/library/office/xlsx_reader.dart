import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'cell_format.dart';
import 'office_models.dart';
import 'ooxml_xml.dart';

/// An Excel 2007+ workbook (`.xlsx`) read for the viewer: each sheet as a grid of the values its cells show.
/// Text, numbers, dates, percentages, booleans and errors are shown; formulas show their last calculated
/// result; charts, pictures and cell styling are not.
SheetsPreview readXlsx(Archive zip) {
  final workbook = partXml(zip, 'xl/workbook.xml');
  if (workbook == null) throw const OfficeProblem("This Excel file can't be read.");
  final root = workbook.rootElement;
  final pr = kid(root, 'workbookPr');
  final date1904 = pr != null && (attr(pr, 'date1904') == '1' || attr(pr, 'date1904') == 'true');
  final rels = relationships(zip, 'xl/workbook.xml');
  final strings = _sharedStrings(zip);
  final formats = _cellFormats(zip);

  final sheets = <SheetData>[];
  final list = kid(root, 'sheets');
  if (list != null) {
    for (final s in kids(list, 'sheet')) {
      final name = attr(s, 'name') ?? 'Sheet ${sheets.length + 1}';
      final target = rels[attr(s, 'id') ?? ''];
      if (target == null || target.contains('chartsheets/') || target.contains('dialogsheets/')) continue;
      if (attr(s, 'state') == 'veryHidden') continue;
      sheets.add(_readSheet(zip, name, target, strings, formats, date1904));
    }
  }
  if (sheets.isEmpty) throw const OfficeProblem('This workbook has no sheets to show.');
  return SheetsPreview(sheets);
}

List<String> _sharedStrings(Archive zip) {
  final xml = partXml(zip, 'xl/sharedStrings.xml');
  if (xml == null) return const [];
  final out = <String>[];
  for (final si in kids(xml.rootElement, 'si')) {
    out.add(_richText(si));
  }
  return out;
}

/// The text of a `<si>` or `<is>`: its `<t>`, or its `<r>` runs' `<t>`s, without the phonetic guide.
String _richText(XmlElement e) {
  final b = StringBuffer();
  for (final c in e.childElements) {
    switch (c.name.local) {
      case 't':
        b.write(c.innerText);
      case 'r':
        for (final t in kids(c, 't')) {
          b.write(t.innerText);
        }
    }
  }
  return b.toString();
}

/// The number format of each cell style, by the style's position in `cellXfs`.
List<CellFormat> _cellFormats(Archive zip) {
  final xml = partXml(zip, 'xl/styles.xml');
  if (xml == null) return const [];
  final custom = <int, CellFormat>{};
  final fmts = kid(xml.rootElement, 'numFmts');
  if (fmts != null) {
    for (final f in kids(fmts, 'numFmt')) {
      final id = int.tryParse(attr(f, 'numFmtId') ?? '');
      final code = attr(f, 'formatCode');
      if (id != null && code != null) custom[id] = CellFormat.fromCode(code);
    }
  }
  final xfs = kid(xml.rootElement, 'cellXfs');
  if (xfs == null) return const [];
  return [
    for (final xf in kids(xfs, 'xf'))
      () {
        final id = int.tryParse(attr(xf, 'numFmtId') ?? '') ?? 0;
        return custom[id] ?? CellFormat.builtIn(id);
      }(),
  ];
}

SheetData _readSheet(
  Archive zip,
  String name,
  String path,
  List<String> strings,
  List<CellFormat> formats,
  bool date1904,
) {
  var text = partText(zip, path);
  if (text == null) return SheetData(name, const []);
  // Rows past the limit are never shown, so a huge sheet is cut after its last shown row rather than parsed whole.
  text = _firstRows(text, OfficeLimits.maxRows + 1);
  final XmlDocument xml;
  try {
    xml = XmlDocument.parse(text);
  } on XmlException {
    return SheetData(name, const []);
  }
  final data = kid(xml.rootElement, 'sheetData');
  final rows = <List<String>>[];
  var truncated = false;
  if (data != null) {
    var lastRow = 0;
    for (final row in kids(data, 'row')) {
      final index = int.tryParse(attr(row, 'r') ?? '') ?? lastRow + 1;
      if (index > OfficeLimits.maxRows) {
        truncated = true;
        break;
      }
      while (rows.length < index - 1) {
        rows.add(<String>[]);
      }
      lastRow = index;
      final cells = <String>[];
      var col = 0;
      for (final c in kids(row, 'c')) {
        final ref = attr(c, 'r');
        if (ref != null) col = _column(ref);
        if (col >= OfficeLimits.maxColumns) {
          truncated = true;
          col++;
          continue;
        }
        while (cells.length < col) {
          cells.add('');
        }
        cells.add(_cellText(c, strings, formats, date1904));
        col++;
      }
      rows.add(cells);
    }
  }
  while (rows.isNotEmpty && rows.last.every((c) => c.isEmpty)) {
    rows.removeLast();
  }
  return SheetData(name, rows, truncated: truncated);
}

/// [xml] cut after its [count]th row, with its closing tags put back, so a very large sheet is cheap to parse.
String _firstRows(String xml, int count) {
  final data = RegExp(r'<(?:(\w+):)?sheetData\b').firstMatch(xml);
  if (data == null) return xml;
  final prefix = data.group(1) == null ? '' : '${data.group(1)}:';
  final close = '</${prefix}row>';
  var from = data.end;
  var found = 0;
  while (found < count) {
    final at = xml.indexOf(close, from);
    if (at < 0) return xml;
    from = at + close.length;
    found++;
  }
  // Is anything left? If only closing tags follow, the sheet was never longer than the limit.
  final rest = xml.indexOf('<${prefix}row', from);
  if (rest < 0) return xml;
  final root = RegExp(r'<(?:(\w+):)?worksheet\b').firstMatch(xml);
  final rootName = root == null ? 'worksheet' : '${root.group(1) == null ? '' : '${root.group(1)}:'}worksheet';
  return '${xml.substring(0, from)}</${prefix}sheetData></$rootName>';
}

/// The zero-based column of a reference such as "AB12".
int _column(String ref) {
  var n = 0;
  for (var i = 0; i < ref.length; i++) {
    final c = ref.codeUnitAt(i);
    if (c >= 65 && c <= 90) {
      n = n * 26 + (c - 64);
    } else if (c >= 97 && c <= 122) {
      n = n * 26 + (c - 96);
    } else {
      break;
    }
  }
  return n - 1;
}

String _cellText(XmlElement c, List<String> strings, List<CellFormat> formats, bool date1904) {
  final type = attr(c, 't');
  final v = kid(c, 'v')?.innerText;
  switch (type) {
    case 's':
      final i = int.tryParse(v ?? '');
      return i != null && i >= 0 && i < strings.length ? strings[i] : '';
    case 'inlineStr':
      final inline = kid(c, 'is');
      return inline == null ? '' : _richText(inline);
    case 'str' || 'd':
      return v ?? '';
    case 'b':
      return v == '1' ? 'TRUE' : 'FALSE';
    case 'e':
      return v ?? '';
  }
  if (v == null || v.isEmpty) return '';
  final number = double.tryParse(v);
  if (number == null) return v;
  final style = int.tryParse(attr(c, 's') ?? '');
  final format = style != null && style >= 0 && style < formats.length ? formats[style] : CellFormat.general;
  return format.format(number, date1904: date1904);
}
