import 'dart:convert';
import 'dart:typed_data';

import '../../core/api/api_error.dart';
import '../../core/config.dart';
import 'library_models.dart';
import 'library_repository.dart';

/// The sample source: a dozen documents in every format the library takes, one pack, three shared by the
/// member (so My uploads has something in it), with views and downloads. Reports, uploads, deletions and the
/// like are kept in memory.
class DemoLibraryRepository implements LibraryRepository {
  DemoLibraryRepository({DateTime? now}) : now = now ?? DateTime.utc(2026, 10, 24, 9);

  final DateTime now;

  /// Calls, for tests.
  final calls = <String>[];

  /// The member's id: what makes a document theirs.
  static const meId = 'demo-me';

  late final List<LibraryDocument> _docs = [
    _doc(
      'd1',
      'FM Handover Checklist: New Building Takeover',
      'A 60-point checklist for taking a new or refurbished building from the project team into operations.',
      'Integrated Facility Management',
      ['fm-handover-checklist.pdf'],
      downloads: 482,
      views: 1290,
      days: 12,
      who: _priya,
      subcategory: 'Handover & Commissioning',
    ),
    _doc(
      'd2',
      'Fire & Life Safety SOP: Alarm Response and Evacuation',
      'Step-by-step standard operating procedure for a fire alarm activation, with roles and drill records.',
      'Fire & Life Safety',
      ['fire-life-safety-sop.pdf'],
      downloads: 371,
      views: 980,
      days: 30,
      who: _arvind,
    ),
    _doc(
      'd3',
      'Vendor SLA Scorecard Template',
      'A monthly scorecard for hard and soft service vendors: response, resolution, quality and cost.',
      'Integrated Facility Management',
      ['vendor-sla-scorecard.xlsx'],
      downloads: 604,
      views: 1410,
      days: 5,
      who: _me,
    ),
    _doc(
      'd4',
      'BRSR Core Reporting Guide for Facility Teams',
      'What facilities has to collect for the BRSR Core energy, water and waste indicators, and where it comes from.',
      'Corporate Real Estate',
      ['brsr-core-guide.pdf'],
      downloads: 233,
      views: 700,
      days: 48,
      who: _radhika,
    ),
    _doc(
      'd5',
      'Lease Audit Workbook: Template and Worked Example',
      'A workbook, its filled-in example and a one-page method note for auditing a commercial lease.',
      'Corporate Real Estate',
      ['lease-audit-template.xlsx', 'lease-audit-worked-example.xlsx', 'lease-audit-method.pdf'],
      downloads: 318,
      views: 860,
      days: 21,
      who: _me,
      sizes: [88 * 1024, 142 * 1024, 311 * 1024],
    ),
    _doc(
      'd6',
      'MEP Commissioning Standard (Summary)',
      'The commissioning stages, witness points and acceptance criteria for MEP systems in office buildings.',
      'Technology',
      ['mep-commissioning-standard.docx'],
      downloads: 150,
      views: 420,
      days: 73,
      who: _vikram,
    ),
    _doc(
      'd7',
      'GCC Workplace Leadership: Quarterly Briefing',
      'Slides from the Council briefing on hybrid occupancy, seat ratios and campus consolidation.',
      'Corporate Real Estate',
      ['gcc-workplace-briefing.pptx'],
      downloads: 94,
      views: 260,
      days: 9,
      who: _ananya,
    ),
    _doc(
      'd8',
      'Energy Intensity Case Study: A 12,000-seat Campus',
      'How one campus cut energy intensity by 18% in two years: the measures, the meters and what did not work.',
      'Technology',
      ['energy-intensity-case-study.pdf'],
      downloads: 205,
      views: 540,
      days: 95,
      who: _radhika,
    ),
    _doc(
      'd9',
      'Chiller Plant Room Walk-down',
      'The checklist photo set used on a chiller plant room walk-down.',
      'Integrated Facility Management',
      ['plant-room-walkdown.png'],
      downloads: 41,
      views: 133,
      days: 3,
      who: _me,
    ),
    _doc(
      'd10',
      'Visitor Management Policy',
      'A short policy for registering, badging and escorting visitors at multi-tenant buildings.',
      'Security',
      ['visitor-management-policy.txt'],
      downloads: 62,
      views: 188,
      days: 120,
      who: _meera,
    ),
    _doc(
      'd11',
      'Contractor Induction Pack',
      'Induction deck, quiz and sign-in sheet in one archive.',
      'Integrated Facility Management',
      ['contractor-induction-pack.zip'],
      downloads: 77,
      views: 201,
      days: 64,
      who: _meera,
    ),
    _doc(
      'd12',
      'Preventive Maintenance Calendar (CSV)',
      'A year of PPM tasks by asset class as a CSV, ready to import into a CMMS.',
      'Integrated Facility Management',
      ['ppm-calendar.csv'],
      downloads: 120,
      views: 310,
      days: 150,
      who: _priya,
    ),
  ];

  static const _me = LibraryUploader(
    id: meId,
    firstName: 'Nikhil',
    lastName: 'Majjagi',
    title: 'Lead Operations Manager',
  );
  static const _priya = LibraryUploader(
    id: 'demo-priya',
    firstName: 'Priya',
    lastName: 'Nambiar',
    title: 'Sustainability Lead',
  );
  static const _arvind = LibraryUploader(
    id: 'demo-arvind',
    firstName: 'Arvind',
    lastName: 'Swamy',
    title: 'General Counsel',
  );
  static const _radhika = LibraryUploader(
    id: 'demo-radhika',
    firstName: 'Radhika',
    lastName: 'Iyer',
    title: 'VP Sustainable PropTech',
  );
  static const _vikram = LibraryUploader(
    id: 'demo-vikram',
    firstName: 'Vikram',
    lastName: 'Malhotra',
    title: 'Director ESG',
  );
  static const _ananya = LibraryUploader(
    id: 'demo-ananya',
    firstName: 'Ananya',
    lastName: 'Rao',
    title: 'Workplace Head',
  );
  static const _meera = LibraryUploader(
    id: 'demo-meera',
    firstName: 'Meera',
    lastName: 'Krishnan',
    title: 'Head of Security Operations',
  );

  LibraryDocument _doc(
    String id,
    String title,
    String description,
    String category,
    List<String> names, {
    required int downloads,
    required int views,
    required int days,
    required LibraryUploader who,
    String? subcategory,
    List<int>? sizes,
  }) {
    final files = [
      for (final (i, n) in names.indexed)
        LibraryFile(
          id: '$id-f$i',
          fileName: n,
          mimeType: _mime(n),
          sizeBytes: sizes?[i] ?? (180 + id.hashCode.abs() % 400) * 1024,
          fileType: LibraryFileType.classify(_mime(n), n),
          sortOrder: i,
          downloadCount: (downloads / names.length).round(),
        ),
    ];
    return LibraryDocument(
      id: id,
      title: title,
      description: description,
      category: category,
      subcategory: subcategory,
      files: files,
      fileCount: files.length,
      totalSizeBytes: files.fold(0, (n, f) => n + f.sizeBytes),
      downloadCount: downloads,
      viewCount: views,
      createdAt: now.subtract(Duration(days: days)),
      uploaderId: who.id,
      uploader: who,
    );
  }

  static String _mime(String name) {
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'pdf' => 'application/pdf',
      'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'pptx' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'png' => 'image/png',
      'zip' => 'application/zip',
      'csv' => 'text/csv',
      'txt' => 'text/plain',
      _ => 'application/octet-stream',
    };
  }

  final Set<String> _reported = {};
  int _next = 100;

  @override
  Future<LibraryPage> documents(LibraryQuery q) async {
    calls.add('documents:${q.page}:${q.search}:${q.category ?? ''}:${q.fileType?.api ?? ''}:${q.mine}:${q.sort.name}');
    var rows = _docs.toList();
    final s = q.search.trim().toLowerCase();
    if (s.isNotEmpty) {
      rows = rows
          .where(
            (d) =>
                d.title.toLowerCase().contains(s) ||
                (d.description ?? '').toLowerCase().contains(s) ||
                (d.category ?? '').toLowerCase().contains(s) ||
                d.files.any((f) => f.fileName.toLowerCase().contains(s)),
          )
          .toList();
    }
    if (q.category != null) rows = rows.where((d) => d.category == q.category).toList();
    if (q.fileType != null) rows = rows.where((d) => d.files.any((f) => f.fileType == q.fileType)).toList();
    if (q.mine) rows = rows.where((d) => d.uploaderId == meId).toList();
    int by(LibraryDocument a, LibraryDocument b) => switch (q.sort) {
      LibrarySort.downloads => b.downloadCount - a.downloadCount,
      LibrarySort.newest => (b.createdAt ?? now).compareTo(a.createdAt ?? now),
      LibrarySort.views => b.viewCount - a.viewCount,
      LibrarySort.az => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      LibrarySort.largest => b.totalSizeBytes - a.totalSizeBytes,
    };
    rows.sort(by);
    final from = (q.page - 1) * q.limit;
    final slice = rows.skip(from).take(q.limit).toList();
    return LibraryPage(documents: slice, total: rows.length, page: q.page, hasNext: from + q.limit < rows.length);
  }

  @override
  Future<List<String>> categories() async {
    calls.add('categories');
    final counts = <String, int>{};
    for (final d in _docs) {
      final c = d.category;
      if (c != null) counts[c] = (counts[c] ?? 0) + 1;
    }
    return (counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!)));
  }

  @override
  Future<List<FileTypeFacet>> fileTypes() async {
    calls.add('fileTypes');
    final counts = <LibraryFileType, int>{};
    for (final d in _docs) {
      for (final t in {for (final f in d.files) f.fileType}) {
        counts[t] = (counts[t] ?? 0) + 1;
      }
    }
    return [
      for (final t in LibraryFileType.values)
        if (counts.containsKey(t)) FileTypeFacet(type: t, label: t.label, count: counts[t]!),
    ];
  }

  @override
  Future<int> myUploadCount() async => _docs.where((d) => d.uploaderId == meId).length;

  @override
  Future<LibraryDocument> document(String id) async {
    calls.add('document:$id');
    return _docs.firstWhere(
      (d) => d.id == id,
      orElse: () => throw ApiError('That document is no longer in the library.', statusCode: 404),
    );
  }

  @override
  Future<List<TaxonomyNode>> taxonomy() async => const [
    TaxonomyNode(
      label: 'Integrated Facility Management',
      children: [
        TaxonomyNode(
          label: 'Housekeeping',
          children: [TaxonomyNode(label: 'Deep cleaning')],
        ),
        TaxonomyNode(label: 'Handover & Commissioning'),
      ],
    ),
    TaxonomyNode(
      label: 'Corporate Real Estate',
      children: [TaxonomyNode(label: 'Lease Advisory')],
    ),
    TaxonomyNode(label: 'Fire & Life Safety'),
    TaxonomyNode(label: 'Technology'),
    TaxonomyNode(label: 'Security'),
  ];

  @override
  Future<LibraryViewer?> viewer() async => const LibraryViewer(id: meId);

  @override
  Future<DocumentBytes> fetchFile(LibraryDocument document, LibraryFile file, {bool preview = false}) async {
    calls.add('${preview ? 'preview' : 'download'}:${document.id}:${file.id}');
    if (!preview) _bump(document.id, file.id);
    final bytes = file.isImage ? _png : Uint8List.fromList(utf8.encode('%PDF-1.4 sample of ${file.fileName}'));
    return DocumentBytes(bytes: bytes, fileName: file.fileName, mimeType: file.mimeType);
  }

  void _bump(String docId, String fileId) {
    final i = _docs.indexWhere((d) => d.id == docId);
    if (i < 0) return;
    final d = _docs[i];
    _docs[i] = d.copyWith(
      downloadCount: d.downloadCount + 1,
      files: [for (final f in d.files) f.id == fileId ? f.copyWith(downloadCount: f.downloadCount + 1) : f],
    );
  }

  @override
  Future<int> recordView(String id) async {
    calls.add('view:$id');
    final i = _docs.indexWhere((d) => d.id == id);
    if (i < 0) throw ApiError('Document not found', statusCode: 404);
    _docs[i] = _docs[i].copyWith(viewCount: _docs[i].viewCount + 1);
    return _docs[i].viewCount;
  }

  @override
  Future<StoredFile> upload(PickedFile file, {void Function(double)? onProgress}) async {
    calls.add('upload:${file.name}');
    onProgress?.call(1);
    return StoredFile(
      url: '/uploads/demo-${_next++}-${file.name}',
      name: file.name,
      size: file.size,
      mimeType: file.mimeType ?? _mime(file.name),
    );
  }

  List<LibraryFile> _filesOf(String id, List<StoredFile> stored, int from) => [
    for (final (i, s) in stored.indexed)
      LibraryFile(
        id: '$id-n${from + i}',
        fileName: s.name,
        mimeType: s.mimeType,
        sizeBytes: s.size,
        fileType: LibraryFileType.classify(s.mimeType, s.name),
        sortOrder: from + i,
      ),
  ];

  @override
  Future<LibraryDocument> create(DocumentDraft draft, List<StoredFile> files) async {
    calls.add('create:${draft.title}');
    final id = 'd${_next++}';
    final list = _filesOf(id, files, 0);
    final doc = LibraryDocument(
      id: id,
      title: draft.title,
      description: draft.description,
      category: draft.category,
      subcategory: draft.category == null ? null : draft.subcategory,
      specialization: draft.subcategory == null ? null : draft.specialization,
      files: list,
      fileCount: list.length,
      totalSizeBytes: list.fold(0, (n, f) => n + f.sizeBytes),
      createdAt: now,
      uploaderId: meId,
      uploader: _me,
    );
    _docs.insert(0, doc);
    return doc;
  }

  @override
  Future<LibraryDocument> addFiles(String id, List<StoredFile> files) async {
    calls.add('addFiles:$id:${files.length}');
    final i = _docs.indexWhere((d) => d.id == id);
    if (i < 0) throw ApiError('Document not found', statusCode: 404);
    final d = _docs[i];
    if (d.fileCount + files.length > LibraryLimits.maxFiles) {
      throw ApiError(
        'A document holds at most ${LibraryLimits.maxFiles} files; this one already has ${d.fileCount}.',
        statusCode: 400,
      );
    }
    final more = _filesOf(id, files, d.fileCount);
    _docs[i] = d.copyWith(
      files: [...d.files, ...more],
      fileCount: d.fileCount + more.length,
      totalSizeBytes: d.totalSizeBytes + more.fold(0, (n, f) => n + f.sizeBytes),
    );
    return _docs[i];
  }

  @override
  Future<void> removeFile(String documentId, String fileId) async {
    calls.add('removeFile:$documentId:$fileId');
    final i = _docs.indexWhere((d) => d.id == documentId);
    if (i < 0) throw ApiError('Document not found', statusCode: 404);
    final d = _docs[i];
    if (d.fileCount <= 1) {
      throw ApiError('That is the only file on this document. Remove the document instead.', statusCode: 400);
    }
    final gone = d.files.firstWhere((f) => f.id == fileId);
    _docs[i] = d.copyWith(
      files: [
        for (final f in d.files)
          if (f.id != fileId) f,
      ],
      fileCount: d.fileCount - 1,
      totalSizeBytes: d.totalSizeBytes - gone.sizeBytes,
    );
  }

  @override
  Future<void> delete(String id) async {
    calls.add('delete:$id');
    _docs.removeWhere((d) => d.id == id);
  }

  @override
  Future<void> report(String id, DocumentReportReason reason, {String? note}) async {
    calls.add('report:$id:${reason.api}:${note ?? ''}');
    final d = _docs.firstWhere(
      (d) => d.id == id,
      orElse: () => throw ApiError('That document is no longer in the library.', statusCode: 404),
    );
    if (d.uploaderId == meId) {
      throw ApiError('Delete your own document rather than reporting it.', statusCode: 400);
    }
    if (!_reported.add(id)) {
      throw ApiError('You have already reported this document. An admin is reviewing it.', statusCode: 409);
    }
  }

  @override
  Future<int> unreadNotifications() async => 3;

  @override
  Uri link() => AppConfig.sitePage('/documents');

  /// A 1 x 1 PNG: what a sample image document is when the app shows it.
  static final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  );
}
