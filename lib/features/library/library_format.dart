/// Small words and numbers the Library screens share.
library;

import '../chapters/community_kit.dart' show fileSizeLabel, groupThousands, inIst;
import 'library_models.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// 1290 → "1,290"; 12400 → "12.4k": a card's counts stay short.
String compactCount(int n) {
  if (n < 10000) return groupThousands(n);
  final k = n / 1000;
  return '${k >= 100 ? k.round() : k.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '')}k';
}

/// "12 Oct 2026" on the Indian clock.
String shortDate(DateTime t) {
  final d = inIst(t);
  return '${d.day} ${_months[d.month - 1]} ${d.year}';
}

/// What a card says under its title: "PDF · 2.4 MB", or for a pack "3 files · PDF, XLSX · 541 KB".
String contentsLine(LibraryDocument d) {
  final size = fileSizeLabel(d.totalSizeBytes);
  if (d.isPack) return '${d.fileCount} files · ${d.formats.join(', ')} · $size';
  final first = d.first;
  return first == null ? size : '${first.glyph.label} · $size';
}

/// "1 file" / "3 files".
String filesLabel(int n) => n == 1 ? '1 file' : '$n files';

/// "1 document" / "26 documents".
String documentsLabel(int n) => n == 1 ? '1 document' : '${groupThousands(n)} documents';

/// The fraction of an upload as the form words it: "64%".
String percentLabel(double p) => '${(p * 100).round()}%';
