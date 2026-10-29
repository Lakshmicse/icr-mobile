/// What the Digital Library screens draw: the website's Document Hub (`/documents`) and its viewer,
/// upload and report dialogs, from the portal's `documents` module (`GET /documents`, `/categories`,
/// `/file-types`, `GET /documents/:id/download`, `POST /documents`, `POST /documents/:id/report`…).
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../chapters/community_kit.dart' show FeedPicture, initialsOf;

// ---------------------------------------------------------------------------
// Formats
// ---------------------------------------------------------------------------

/// The format buckets the hub filters by (`DocumentFileType`, `@icr/shared`).
enum LibraryFileType {
  pdf('PDF', 'PDF'),
  word('WORD', 'Word'),
  spreadsheet('SPREADSHEET', 'Spreadsheet'),
  presentation('PRESENTATION', 'Presentation'),
  image('IMAGE', 'Image'),
  archive('ARCHIVE', 'Archive'),
  text('TEXT', 'Text'),
  other('OTHER', 'Other');

  const LibraryFileType(this.api, this.label);

  /// The value the API takes (`?fileType=`) and answers.
  final String api;

  /// The chip's label: what a person would call the format.
  final String label;

  static LibraryFileType fromApi(String? v) {
    for (final t in values) {
      if (t.api == v) return t;
    }
    return other;
  }

  static const _byMime = <String, LibraryFileType>{
    'application/pdf': pdf,
    'application/msword': word,
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document': word,
    'application/vnd.ms-excel': spreadsheet,
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': spreadsheet,
    'text/csv': spreadsheet,
    'application/vnd.ms-powerpoint': presentation,
    'application/vnd.openxmlformats-officedocument.presentationml.presentation': presentation,
    'application/zip': archive,
    'application/x-zip-compressed': archive,
    'text/plain': text,
  };

  static const _byExtension = <String, LibraryFileType>{
    'pdf': pdf,
    'doc': word,
    'docx': word,
    'xls': spreadsheet,
    'xlsx': spreadsheet,
    'csv': spreadsheet,
    'ppt': presentation,
    'pptx': presentation,
    'zip': archive,
    'txt': text,
    'png': image,
    'jpg': image,
    'jpeg': image,
    'webp': image,
    'gif': image,
  };

  /// `classifyDocumentFile` of `@icr/shared`: MIME first, extension second.
  static LibraryFileType classify(String mimeType, String fileName) {
    final mime = mimeType.toLowerCase();
    final known = _byMime[mime];
    if (known != null) return known;
    if (mime.startsWith('image/')) return image;
    final dot = fileName.lastIndexOf('.');
    if (dot >= 0) {
      final byExt = _byExtension[fileName.substring(dot + 1).toLowerCase()];
      if (byExt != null) return byExt;
    }
    return other;
  }

  /// The glyph the chip and a plate may carry.
  IconData get icon => switch (this) {
    pdf => LucideIcons.fileText,
    word => LucideIcons.fileType,
    spreadsheet => LucideIcons.fileSpreadsheet,
    presentation => LucideIcons.presentation,
    image => LucideIcons.fileImage,
    archive => LucideIcons.fileArchive,
    text => LucideIcons.fileText,
    other => LucideIcons.file,
  };
}

/// How a file is shown in the app. The library is view-only on a phone: a file is read and drawn in the
/// app, never saved or handed to another app.
enum PreviewKind {
  /// Pages drawn by the phone's PDF renderer.
  pdf,

  /// A picture, zoomable.
  image,

  /// Plain text, line by line.
  text,

  /// A CSV file as a table.
  table,

  /// Word documents (.doc, .docx): headings, paragraphs, lists and tables.
  word,

  /// Excel workbooks (.xls, .xlsx): each sheet as a grid.
  sheets,

  /// PowerPoint decks (.ppt, .pptx): each slide's text.
  slides,

  /// ZIP files: the files inside, each opened in the viewer in turn.
  archive,

  /// Anything the app has no reader for (the library takes none of these).
  none,
}

/// How a file is shown, from its MIME type or, failing that, its name. The formats are the ones the library
/// accepts (`LibraryLimits.extensions`); the app reads each in its own viewer because a document cannot be
/// saved or handed to another app.
PreviewKind previewKindFor(String mimeType, String fileName) {
  final mime = mimeType.toLowerCase();
  if (mime == 'image/svg+xml') return PreviewKind.none;
  const byMime = <String, PreviewKind>{
    'application/pdf': PreviewKind.pdf,
    'text/plain': PreviewKind.text,
    'text/csv': PreviewKind.table,
    'application/msword': PreviewKind.word,
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document': PreviewKind.word,
    'application/vnd.ms-excel': PreviewKind.sheets,
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': PreviewKind.sheets,
    'application/vnd.ms-powerpoint': PreviewKind.slides,
    'application/vnd.openxmlformats-officedocument.presentationml.presentation': PreviewKind.slides,
    'application/zip': PreviewKind.archive,
    'application/x-zip-compressed': PreviewKind.archive,
  };
  final known = byMime[mime];
  if (known != null) return known;
  if (mime.startsWith('image/')) return PreviewKind.image;
  final dot = fileName.lastIndexOf('.');
  if (dot < 0) return PreviewKind.none;
  switch (fileName.substring(dot + 1).toLowerCase()) {
    case 'pdf':
      return PreviewKind.pdf;
    case 'txt':
      return PreviewKind.text;
    case 'csv':
      return PreviewKind.table;
    case 'doc' || 'docx':
      return PreviewKind.word;
    case 'xls' || 'xlsx':
      return PreviewKind.sheets;
    case 'ppt' || 'pptx':
      return PreviewKind.slides;
    case 'zip':
      return PreviewKind.archive;
    case 'png' || 'jpg' || 'jpeg' || 'webp' || 'gif':
      return PreviewKind.image;
  }
  return PreviewKind.none;
}

/// A format badge and its colour, for the plate on a document card (`fileGlyph` on the website).
class FileGlyph {
  const FileGlyph(this.label, this.color);

  final String label;
  final Color color;

  static const _byMime = <String, FileGlyph>{
    'application/pdf': FileGlyph('PDF', Color(0xFFC0392B)),
    'application/msword': FileGlyph('DOC', Color(0xFF2B579A)),
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document': FileGlyph('DOCX', Color(0xFF2B579A)),
    'application/vnd.ms-excel': FileGlyph('XLS', Color(0xFF1D6F42)),
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': FileGlyph('XLSX', Color(0xFF1D6F42)),
    'application/vnd.ms-powerpoint': FileGlyph('PPT', Color(0xFFB7472A)),
    'application/vnd.openxmlformats-officedocument.presentationml.presentation': FileGlyph('PPTX', Color(0xFFB7472A)),
    'text/csv': FileGlyph('CSV', Color(0xFF1D6F42)),
    'text/plain': FileGlyph('TXT', Color(0xFF5A6B7B)),
    'application/zip': FileGlyph('ZIP', Color(0xFFB45309)),
    'image/png': FileGlyph('PNG', Color(0xFF6B4EA8)),
    'image/jpeg': FileGlyph('JPG', Color(0xFF6B4EA8)),
    'image/webp': FileGlyph('WEBP', Color(0xFF6B4EA8)),
  };

  static const fallback = FileGlyph('FILE', Color(0xFF32629E));

  /// MIME first; a generic or unknown type falls back to the extension (capped so a long one fits the plate).
  static FileGlyph of(String mimeType, String fileName) {
    final known = _byMime[mimeType];
    if (known != null) return known;
    final dot = fileName.lastIndexOf('.');
    if (dot > 0) {
      final ext = fileName.substring(dot + 1);
      if (ext.isNotEmpty && ext.length <= 4) return FileGlyph(ext.toUpperCase(), fallback.color);
    }
    return fallback;
  }
}

// ---------------------------------------------------------------------------
// Documents
// ---------------------------------------------------------------------------

/// One file of a document (a pack holds up to ten).
class LibraryFile {
  const LibraryFile({
    required this.id,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    this.fileType = LibraryFileType.other,
    this.sortOrder = 0,
    this.downloadCount = 0,
  });

  final String id;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final LibraryFileType fileType;
  final int sortOrder;
  final int downloadCount;

  FileGlyph get glyph => FileGlyph.of(mimeType, fileName);

  /// An image the app can show itself (the viewer reads the bytes).
  bool get isImage => fileType == LibraryFileType.image && mimeType.startsWith('image/') && mimeType != 'image/svg+xml';

  /// How the app shows this file, or [PreviewKind.none] when it has no reader for it.
  PreviewKind get previewKind => previewKindFor(mimeType, fileName);

  bool get canPreview => previewKind != PreviewKind.none;

  LibraryFile copyWith({int? downloadCount}) => LibraryFile(
    id: id,
    fileName: fileName,
    mimeType: mimeType,
    sizeBytes: sizeBytes,
    fileType: fileType,
    sortOrder: sortOrder,
    downloadCount: downloadCount ?? this.downloadCount,
  );
}

/// Who shared a document: name, photo and one job title (the line the forum shows under a name).
class LibraryUploader {
  const LibraryUploader({required this.id, required this.firstName, required this.lastName, this.photo, this.title});

  final String id;
  final String firstName;
  final String lastName;
  final FeedPicture? photo;
  final String? title;

  String get name => '$firstName $lastName'.trim();
  String get initials => initialsOf(firstName, lastName);
}

/// A library entry: a title and the files filed under it.
class LibraryDocument {
  const LibraryDocument({
    required this.id,
    required this.title,
    required this.uploaderId,
    this.description,
    this.category,
    this.subcategory,
    this.specialization,
    this.files = const [],
    this.fileCount = 1,
    this.totalSizeBytes = 0,
    this.downloadCount = 0,
    this.viewCount = 0,
    this.createdAt,
    this.uploader,
  });

  final String id;
  final String title;
  final String? description;
  final String? category;
  final String? subcategory;
  final String? specialization;
  final List<LibraryFile> files;
  final int fileCount;
  final int totalSizeBytes;
  final int downloadCount;
  final int viewCount;
  final DateTime? createdAt;
  final String uploaderId;
  final LibraryUploader? uploader;

  /// The file the card shows its plate for and the viewer opens on.
  LibraryFile? get first => files.isEmpty ? null : files.first;

  bool get isPack => fileCount > 1;

  /// "Fire & Life Safety › Fire Detection & Alarm Systems".
  String? get categoryPath {
    final parts = [category, subcategory, specialization].whereType<String>().where((s) => s.isNotEmpty);
    return parts.isEmpty ? null : parts.join(' › ');
  }

  /// The distinct formats in the pack, in order ("PDF", "XLSX").
  List<String> get formats {
    final seen = <String>[];
    for (final f in files) {
      final label = f.glyph.label;
      if (!seen.contains(label)) seen.add(label);
    }
    return seen;
  }

  LibraryDocument copyWith({
    List<LibraryFile>? files,
    int? fileCount,
    int? totalSizeBytes,
    int? downloadCount,
    int? viewCount,
  }) => LibraryDocument(
    id: id,
    title: title,
    description: description,
    category: category,
    subcategory: subcategory,
    specialization: specialization,
    files: files ?? this.files,
    fileCount: fileCount ?? this.fileCount,
    totalSizeBytes: totalSizeBytes ?? this.totalSizeBytes,
    downloadCount: downloadCount ?? this.downloadCount,
    viewCount: viewCount ?? this.viewCount,
    createdAt: createdAt,
    uploaderId: uploaderId,
    uploader: uploader,
  );
}

/// One format chip with its count (`GET /documents/file-types`: documents, not files).
class FileTypeFacet {
  const FileTypeFacet({required this.type, required this.label, required this.count});

  final LibraryFileType type;
  final String label;
  final int count;
}

// ---------------------------------------------------------------------------
// Browsing
// ---------------------------------------------------------------------------

/// The sorts the library offers (the server's sortable columns).
enum LibrarySort {
  downloads('Most downloaded', 'downloadCount', 'desc'),
  newest('Newest', 'createdAt', 'desc'),
  views('Most viewed', 'viewCount', 'desc'),
  az('A to Z', 'title', 'asc'),
  largest('Largest', 'sizeBytes', 'desc');

  const LibrarySort(this.label, this.sortBy, this.sortDir);
  final String label;
  final String sortBy;
  final String sortDir;
}

/// What the list is narrowed by; every part is a query parameter the API takes.
class LibraryQuery {
  const LibraryQuery({
    this.search = '',
    this.category,
    this.fileType,
    this.mine = false,
    this.sort = LibrarySort.downloads,
    this.page = 1,
    this.limit = pageSize,
  });

  static const pageSize = 24;

  final String search;
  final String? category;
  final LibraryFileType? fileType;
  final bool mine;
  final LibrarySort sort;
  final int page;
  final int limit;

  /// A search, a category, a format or "My uploads" is on (the sort alone is not a filter).
  bool get filtered => search.trim().isNotEmpty || category != null || fileType != null || mine;

  LibraryQuery copyWith({
    String? search,
    String? category,
    bool clearCategory = false,
    LibraryFileType? fileType,
    bool clearFileType = false,
    bool? mine,
    LibrarySort? sort,
    int? page,
  }) => LibraryQuery(
    search: search ?? this.search,
    category: clearCategory ? null : category ?? this.category,
    fileType: clearFileType ? null : fileType ?? this.fileType,
    mine: mine ?? this.mine,
    sort: sort ?? this.sort,
    page: page ?? this.page,
    limit: limit,
  );
}

class LibraryPage {
  const LibraryPage({required this.documents, required this.total, required this.page, required this.hasNext});

  final List<LibraryDocument> documents;
  final int total;
  final int page;
  final bool hasNext;
}

/// What the library holds, as the website's banner lists it (a decoration there). On a phone each is a
/// quick search: the API has no "kind" field, so the word is searched in titles, descriptions and
/// categories.
class LibraryKind {
  const LibraryKind(this.label, this.icon, {String? term}) : term = term ?? label;

  final String label;
  final IconData icon;

  /// What the chip types into the search.
  final String term;
}

const libraryKinds = <LibraryKind>[
  LibraryKind('Insights', LucideIcons.lightbulb),
  LibraryKind('Best Practices', LucideIcons.badgeCheck, term: 'Best Practice'),
  LibraryKind('SOPs', LucideIcons.listOrdered, term: 'SOP'),
  LibraryKind('Checklists', LucideIcons.listChecks, term: 'Checklist'),
  LibraryKind('Policies', LucideIcons.shieldCheck, term: 'Policy'),
  LibraryKind('Processes', LucideIcons.workflow, term: 'Process'),
  LibraryKind('Templates', LucideIcons.fileText, term: 'Template'),
  LibraryKind('Standards', LucideIcons.ruler, term: 'Standard'),
  LibraryKind('Research', LucideIcons.flaskConical),
  LibraryKind('Case Studies', LucideIcons.bookOpen, term: 'Case Study'),
];

// ---------------------------------------------------------------------------
// Reporting
// ---------------------------------------------------------------------------

/// Why a member flags a document (`DocumentReportReason`).
enum DocumentReportReason {
  copyright('COPYRIGHT', 'Copyright or confidential material'),
  inappropriate('INAPPROPRIATE', 'Inappropriate or offensive'),
  misleading('MISLEADING', 'Misleading or out of date'),
  spam('SPAM', 'Spam or advertising'),
  brokenFile('BROKEN_FILE', 'File is broken or will not open'),
  other('OTHER', 'Something else');

  const DocumentReportReason(this.api, this.label);
  final String api;
  final String label;
}

/// The API's limit on a report's note (`CreateDocumentReportDto`).
const reportNoteLimit = 1000;

// ---------------------------------------------------------------------------
// Uploading
// ---------------------------------------------------------------------------

/// The API's limits for a library entry (`CreateDocumentDto`, `MAX_DOCUMENT_FILES`, the uploads' 10 MB).
class LibraryLimits {
  LibraryLimits._();

  static const title = 200;
  static const description = 2000;
  static const category = 60;
  static const subcategory = 80;
  static const specialization = 80;
  static const fileName = 255;
  static const maxFiles = 10;
  static const maxBytes = 10 * 1024 * 1024;

  /// The formats a library upload takes (the website's accepted extensions).
  static const extensions = [
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
    'csv',
    'txt',
    'zip',
    'png',
    'jpg',
    'jpeg',
    'webp',
  ];
}

/// A file the person chose, read into memory.
class PickedFile {
  const PickedFile({required this.name, required this.bytes, this.mimeType});

  final String name;
  final Uint8List bytes;
  final String? mimeType;

  int get size => bytes.length;
}

/// A file the uploads endpoint stored: the path the document will carry.
class StoredFile {
  const StoredFile({required this.url, required this.name, required this.size, required this.mimeType});

  final String url;
  final String name;
  final int size;
  final String mimeType;

  Map<String, dynamic> toJson() => {'fileUrl': url, 'fileName': name, 'mimeType': mimeType, 'sizeBytes': size};
}

/// A new library entry's words (`CreateDocumentDto`); the files go up first.
class DocumentDraft {
  const DocumentDraft({required this.title, this.description, this.category, this.subcategory, this.specialization});

  final String title;
  final String? description;
  final String? category;
  final String? subcategory;
  final String? specialization;
}

/// One node of the platform taxonomy the category pickers offer (`GET /categories/tree`): three levels.
class TaxonomyNode {
  const TaxonomyNode({required this.label, this.children = const []});

  final String label;
  final List<TaxonomyNode> children;
}

/// The bytes of one file (what `GET /documents/:id/download` streams) and the name to save them under.
class DocumentBytes {
  const DocumentBytes({required this.bytes, required this.fileName, required this.mimeType});

  final Uint8List bytes;
  final String fileName;
  final String mimeType;
}

/// The signed-in person, for "is this mine": the uploader or a SUPER_ADMIN may change a document.
class LibraryViewer {
  const LibraryViewer({required this.id, this.isAdmin = false});

  final String id;
  final bool isAdmin;

  bool mayChange(LibraryDocument d) => isAdmin || d.uploaderId == id;
}
