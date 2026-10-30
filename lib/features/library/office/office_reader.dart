import 'dart:convert';
import 'dart:typed_data';

import 'cfb.dart';
import 'doc_reader.dart';
import 'docx_reader.dart';
import 'office_models.dart';
import 'ooxml_xml.dart';
import 'ppt_reader.dart';
import 'pptx_reader.dart';
import 'xls_reader.dart';
import 'xlsx_reader.dart';
import 'zip_reader.dart';

/// What reading a file came to: the preview, or why there is none. A plain object so it can come back from a
/// background isolate whatever went wrong inside.
class OfficeOutcome {
  const OfficeOutcome.preview(OfficePreview this.preview) : problem = null;
  const OfficeOutcome.problem(String this.problem) : preview = null;

  final OfficePreview? preview;
  final String? problem;
}

/// Reads [job] for the viewer. Runs in a background isolate (`compute`), so it never throws: a file it cannot
/// read comes back as a [OfficeOutcome.problem] in words for the reader.
///
/// The file is read by what is inside it, not by its name or the type it was filed under: a ZIP package is
/// Word, Excel or PowerPoint by the parts it holds, and an old binary file by the streams it holds.
OfficeOutcome readOfficeJob(OfficeJob job) {
  try {
    return OfficeOutcome.preview(readOffice(job));
  } on OfficeProblem catch (e) {
    return OfficeOutcome.problem(e.message);
  } catch (_) {
    return const OfficeOutcome.problem("This file can't be previewed. It may be damaged.");
  }
}

OfficePreview readOffice(OfficeJob job) {
  final bytes = job.bytes;
  if (_isZip(bytes)) {
    if (job.format == 'archive') return listArchive(bytes);
    final zip = openPackage(bytes);
    if (findPart(zip, 'word/document.xml') != null) return readDocx(zip);
    if (findPart(zip, 'xl/workbook.xml') != null) return readXlsx(zip);
    if (findPart(zip, 'ppt/presentation.xml') != null) return readPptx(zip);
    if (findPart(zip, 'content.xml') != null && findPart(zip, 'mimetype') != null) {
      throw const OfficeProblem("This kind of document can't be previewed in the app.");
    }
    // A ZIP that is not an Office package, filed under an Office name.
    try {
      return listArchive(bytes);
    } on OfficeProblem {
      throw const OfficeProblem("This file can't be read. It may be damaged.");
    }
  }
  if (Cfb.looksLike(bytes)) {
    final cfb = Cfb.parse(bytes);
    if (cfb.has('EncryptedPackage')) {
      throw const OfficeProblem("This file is password protected, so it can't be previewed.");
    }
    if (cfb.has('WordDocument')) return readDoc(cfb);
    if (cfb.has('Workbook') || cfb.has('Book')) return readXls(cfb);
    if (cfb.has('PowerPoint Document')) return readPpt(cfb);
    throw const OfficeProblem("This file can't be previewed.");
  }
  if (job.format == 'archive') {
    throw const OfficeProblem("This ZIP file can't be read. It may be damaged.");
  }
  return _asText(bytes);
}

bool _isZip(Uint8List b) =>
    b.length >= 4 && b[0] == 0x50 && b[1] == 0x4B && (b[2] == 3 || b[2] == 5) && (b[3] == 4 || b[3] == 6);

/// A file that is none of the Office formats it claims: shown as text when it is text (an old export saved
/// as ".xls" is often HTML or tab-separated), else refused.
OfficePreview _asText(Uint8List bytes) {
  final head = bytes.length < 4096 ? bytes : Uint8List.sublistView(bytes, 0, 4096);
  if (head.contains(0)) {
    throw const OfficeProblem("This file isn't in a format the app can read.");
  }
  var text = utf8.decode(bytes, allowMalformed: true);
  if (text.startsWith('﻿')) text = text.substring(1);
  if (RegExp(
    r'<\s*(html|table|body)\b',
    caseSensitive: false,
  ).hasMatch(text.substring(0, text.length < 2000 ? text.length : 2000))) {
    text = _htmlText(text);
  }
  if (text.trim().isEmpty) throw const OfficeProblem('This file is empty.');
  if (text.length > 400000) text = text.substring(0, 400000);
  return TextOfficePreview(text);
}

String _htmlText(String html) {
  var t = html
      .replaceAll(RegExp(r'<(script|style)\b[\s\S]*?</\1>', caseSensitive: false), '')
      .replaceAll(RegExp(r'</(tr|p|div|li|h[1-6]|table)>|<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</(td|th)>', caseSensitive: false), '\t')
      .replaceAll(RegExp(r'<[^>]+>'), '');
  t = t
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&amp;', '&');
  return t.replaceAll(RegExp(r'[ \t]+\n'), '\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}

/// What opening one ZIP entry came to.
class EntryOutcome {
  const EntryOutcome.bytes(Uint8List this.bytes) : problem = null;
  const EntryOutcome.problem(String this.problem) : bytes = null;

  final Uint8List? bytes;
  final String? problem;
}

/// Reads one entry of a ZIP for the viewer; never throws (see [readOfficeJob]).
EntryOutcome readArchiveEntryJob(ArchiveReadJob job) {
  try {
    return EntryOutcome.bytes(readArchiveEntry(job));
  } on OfficeProblem catch (e) {
    return EntryOutcome.problem(e.message);
  } catch (_) {
    return const EntryOutcome.problem("That file can't be opened.");
  }
}
