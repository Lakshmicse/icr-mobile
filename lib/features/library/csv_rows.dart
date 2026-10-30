/// The rows of a comma-separated file for the viewer's table: quoted cells (with commas, line breaks and
/// doubled quotes inside) are read as one cell, and Windows or Unix line ends both end a row. Reading
/// stops after [maxRows] rows; [truncated] says there were more.
class CsvRows {
  const CsvRows(this.rows, {this.truncated = false});

  final List<List<String>> rows;
  final bool truncated;

  int get columns => rows.fold(0, (m, r) => r.length > m ? r.length : m);
}

CsvRows parseCsv(String text, {int maxRows = 500}) {
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  var any = false; // something has been read since the last row ended
  var truncated = false;

  void endCell() {
    row.add(cell.toString());
    cell.clear();
  }

  void endRow() {
    endCell();
    // A blank line is not a row.
    if (!(row.length == 1 && row.first.isEmpty)) rows.add(row);
    row = <String>[];
    any = false;
  }

  final n = text.length;
  for (var i = 0; i < n; i++) {
    if (rows.length >= maxRows) {
      truncated = true;
      break;
    }
    final c = text[i];
    if (quoted) {
      if (c == '"') {
        if (i + 1 < n && text[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        cell.write(c);
      }
      continue;
    }
    switch (c) {
      case '"':
        quoted = true;
        any = true;
      case ',':
        endCell();
        any = true;
      case '\r':
        if (i + 1 < n && text[i + 1] == '\n') i++;
        endRow();
      case '\n':
        endRow();
      default:
        cell.write(c);
        any = true;
    }
  }
  if (!truncated && (any || cell.isNotEmpty || row.isNotEmpty)) endRow();
  // A byte-order mark belongs to the file, not to the first cell.
  if (rows.isNotEmpty && rows.first.isNotEmpty && rows.first.first.startsWith('﻿')) {
    rows.first[0] = rows.first.first.substring(1);
  }
  return CsvRows(rows, truncated: truncated);
}
