import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Rows of cell text drawn as a grid that scrolls both ways: a row-number gutter, a hairline between cells,
/// and column widths that follow the longest text near the top. Rows are built as they scroll into view, so a
/// sheet of thousands of rows stays light. Text is not selectable, since nothing may be copied out.
class DataGrid extends StatelessWidget {
  const DataGrid({super.key, required this.rows, this.headerRow = false});

  final List<List<String>> rows;

  /// Style the first row as a header (a CSV's column names).
  final bool headerRow;

  static const _gutter = 44.0;
  static const _rowHeight = 34.0;
  static const _minColumn = 64.0;
  static const _maxColumn = 260.0;
  static const _line = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    final columns = rows.fold<int>(0, (m, r) => math.max(m, r.length));
    if (columns == 0) return const SizedBox.shrink();
    final widths = _widths(columns);
    final total = _gutter + widths.fold<double>(0, (a, b) => a + b);
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: math.max(total, box.maxWidth),
          height: box.maxHeight.isFinite ? box.maxHeight : null,
          child: ListView.builder(
            itemCount: rows.length,
            itemExtent: _rowHeight,
            itemBuilder: (_, r) => _Row(index: r, cells: rows[r], widths: widths, header: headerRow && r == 0),
          ),
        ),
      ),
    );
  }

  /// A width for each column from the longest of the first 200 rows, so a narrow code and a long sentence
  /// both read well.
  List<double> _widths(int columns) {
    final longest = List<int>.filled(columns, 0);
    for (var r = 0; r < rows.length && r < 200; r++) {
      final row = rows[r];
      for (var c = 0; c < row.length; c++) {
        final len = row[c].length;
        if (len > longest[c]) longest[c] = len;
      }
    }
    return [for (final len in longest) (len * 7.4 + 22).clamp(_minColumn, _maxColumn)];
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.index, required this.cells, required this.widths, required this.header});

  final int index;
  final List<String> cells;
  final List<double> widths;
  final bool header;

  @override
  Widget build(BuildContext context) {
    final fill = header ? const Color(0xFFF1F5F9) : (index.isOdd ? const Color(0xFFFAFBFC) : Colors.white);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        border: const Border(bottom: BorderSide(color: DataGrid._line)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: DataGrid._gutter,
            child: Center(
              child: Text(header ? '' : '${index + 1}', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            ),
          ),
          for (var c = 0; c < widths.length; c++)
            InkWell(
              onTap: (c < cells.length && cells[c].isNotEmpty) ? () => _showCell(context, cells[c]) : null,
              child: Container(
                width: widths[c],
                height: DataGrid._rowHeight - 1,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: const BoxDecoration(
                  border: Border(left: BorderSide(color: DataGrid._line)),
                ),
                child: Text(
                  c < cells.length ? cells[c] : '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: const Color(0xFF0F172A),
                    fontWeight: header ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A cell's whole text, for one too long for its column. Not selectable: nothing is copied out of the library.
void _showCell(BuildContext context, String text) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.6),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Text(text, style: const TextStyle(fontSize: 14.5, height: 1.45, color: Color(0xFF0F172A))),
        ),
      ),
    ),
  );
}
