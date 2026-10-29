import 'dart:typed_data';

/// What the Digital Library shows for a Word, Excel, PowerPoint or ZIP file. The app has no office viewer
/// and nothing may be saved or handed to another app, so each file is read here and drawn as plain data:
/// the text, tables and slide text it holds. Layout, pictures and formulas are not reproduced.
///
/// Everything in this file is plain data (strings, numbers, lists), so a result can be built in a background
/// isolate and sent back to the screen.
sealed class OfficePreview {
  const OfficePreview();
}

/// A document's reading order: headings, paragraphs, list items and tables.
class WordPreview extends OfficePreview {
  const WordPreview(this.blocks, {this.truncated = false});

  final List<WordBlock> blocks;

  /// More content followed than is shown.
  final bool truncated;
}

sealed class WordBlock {
  const WordBlock();
}

/// One paragraph: its styled [runs], whether it is a heading, and the bullet or number in front of it.
class WordParagraph extends WordBlock {
  const WordParagraph(this.runs, {this.heading = 0, this.marker, this.level = 0});

  final List<WordRun> runs;

  /// 0 for body text; 1 to 6 for Heading 1 to 6; [titleHeading] for the Title style; [subtitleHeading] for Subtitle.
  final int heading;

  /// "•", "1." and so on, or null when the paragraph is not a list item.
  final String? marker;

  /// Indent depth of a list item (0 is the first).
  final int level;

  String get text => runs.map((r) => r.text).join();

  bool get isBlank => runs.every((r) => r.text.trim().isEmpty);

  static const titleHeading = 7;
  static const subtitleHeading = 8;
}

class WordRun {
  const WordRun(this.text, {this.bold = false, this.italic = false, this.underline = false, this.muted = false});

  final String text;
  final bool bold;
  final bool italic;
  final bool underline;

  /// A note the reader adds rather than the author's words, such as "[Image]".
  final bool muted;
}

/// A table: one list of cell texts per row.
class WordTable extends WordBlock {
  const WordTable(this.rows);

  final List<List<String>> rows;
}

/// A workbook: its sheets in order.
class SheetsPreview extends OfficePreview {
  const SheetsPreview(this.sheets);

  final List<SheetData> sheets;
}

class SheetData {
  const SheetData(this.name, this.rows, {this.truncated = false});

  final String name;

  /// Cell texts, row by row; a short row is padded by the grid.
  final List<List<String>> rows;

  /// More rows or columns followed than are shown.
  final bool truncated;

  int get columns => rows.fold(0, (m, r) => r.length > m ? r.length : m);
}

/// A presentation: its slides in order.
class SlidesPreview extends OfficePreview {
  const SlidesPreview(this.slides);

  final List<SlideData> slides;
}

class SlideData {
  const SlideData(this.number, {this.title = '', this.lines = const []});

  final int number;
  final String title;

  /// The slide's other text, one entry per paragraph.
  final List<SlideLine> lines;
}

class SlideLine {
  const SlideLine(this.text, {this.level = 0});

  final String text;
  final int level;
}

/// A ZIP file: what it holds. Entries are read one at a time when opened.
class ArchivePreview extends OfficePreview {
  const ArchivePreview(this.entries, {this.truncated = false});

  final List<ArchiveEntryInfo> entries;
  final bool truncated;
}

class ArchiveEntryInfo {
  const ArchiveEntryInfo({required this.index, required this.path, required this.size, this.isDirectory = false});

  /// Position in the archive, to read this entry again when it is opened.
  final int index;
  final String path;
  final int size;
  final bool isDirectory;

  String get name {
    final trimmed = path.endsWith('/') ? path.substring(0, path.length - 1) : path;
    final slash = trimmed.lastIndexOf('/');
    return slash < 0 ? trimmed : trimmed.substring(slash + 1);
  }

  /// The folder the entry sits in, or empty.
  String get folder {
    final trimmed = path.endsWith('/') ? path.substring(0, path.length - 1) : path;
    final slash = trimmed.lastIndexOf('/');
    return slash < 0 ? '' : trimmed.substring(0, slash);
  }
}

/// A file that opened as something other than it said, shown as plain text.
class TextOfficePreview extends OfficePreview {
  const TextOfficePreview(this.text);

  final String text;
}

/// Why a file could not be shown, in words for the reader.
class OfficeProblem implements Exception {
  const OfficeProblem(this.message);

  final String message;

  @override
  String toString() => message;
}

/// One file to read in the background: its bytes, its name and the format it was filed as.
class OfficeJob {
  const OfficeJob(this.bytes, this.fileName, this.format);

  final Uint8List bytes;
  final String fileName;

  /// `word`, `sheets`, `slides` or `archive` (the name of the `PreviewKind` the file was filed as).
  final String format;
}

/// Largest figures shown, so a huge file cannot freeze the phone.
class OfficeLimits {
  OfficeLimits._();

  static const maxRows = 2000;
  static const maxColumns = 40;
  static const maxBlocks = 6000;
  static const maxSlides = 300;
  static const maxArchiveEntries = 1000;

  /// An archive entry larger than this (uncompressed) is listed but not opened.
  static const maxEntryBytes = 25 * 1024 * 1024;
}
