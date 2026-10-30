import 'dart:typed_data';

import 'office_models.dart';
import 'ooxml_xml.dart';

/// A ZIP file listed for the viewer: every file it holds, with its size. Nothing is unpacked here, and nothing
/// is ever written to the phone; an entry is read into memory only when the person opens it.
ArchivePreview listArchive(Uint8List bytes) {
  final zip = openPackage(bytes);
  final entries = <ArchiveEntryInfo>[];
  var truncated = false;
  for (var i = 0; i < zip.files.length; i++) {
    final f = zip.files[i];
    final path = f.name.replaceAll('\\', '/');
    if (path.startsWith('__MACOSX/') || path.endsWith('.DS_Store') || path.split('/').last.startsWith('._')) continue;
    if (f.isSymbolicLink) continue;
    if (!f.isFile) continue; // a folder is shown by the path of the files in it
    if (entries.length >= OfficeLimits.maxArchiveEntries) {
      truncated = true;
      break;
    }
    entries.add(ArchiveEntryInfo(index: i, path: path, size: f.size));
  }
  if (entries.isEmpty) throw const OfficeProblem('This ZIP file is empty.');
  return ArchivePreview(entries, truncated: truncated);
}

/// One archive entry to read again: the ZIP's bytes and the entry's position.
class ArchiveReadJob {
  const ArchiveReadJob(this.bytes, this.index);

  final Uint8List bytes;
  final int index;
}

/// The bytes of one entry of a ZIP, to show in the viewer. Throws an [OfficeProblem] for one too large to open.
Uint8List readArchiveEntry(ArchiveReadJob job) {
  final zip = openPackage(job.bytes);
  if (job.index < 0 || job.index >= zip.files.length) {
    throw const OfficeProblem("That file isn't in the ZIP any more.");
  }
  final f = zip.files[job.index];
  if (f.size > OfficeLimits.maxEntryBytes) {
    throw const OfficeProblem('That file is too large to preview.');
  }
  final Uint8List? bytes;
  try {
    bytes = f.readBytes();
  } catch (_) {
    throw const OfficeProblem("That file can't be opened. It may be password protected.");
  }
  if (bytes == null) throw const OfficeProblem("That file can't be opened.");
  return bytes;
}
