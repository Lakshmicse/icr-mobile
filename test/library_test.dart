import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/config.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/core/widgets/chips.dart';
import 'package:icr_mobile/features/library/api_library_repository.dart';
import 'package:icr_mobile/features/library/demo_library_repository.dart';
import 'package:icr_mobile/features/library/document_screen.dart';
import 'package:icr_mobile/features/library/library_controller.dart';
import 'package:icr_mobile/features/library/library_format.dart';
import 'package:icr_mobile/features/library/library_models.dart';
import 'package:icr_mobile/features/library/library_screen.dart';
import 'package:icr_mobile/features/library/upload_document_screen.dart';
import 'package:icr_mobile/features/library/widgets/document_card.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import 'helpers/community_fakes.dart';
import 'helpers/fonts.dart';

// The API's rows, as `GET /documents` gives them (the documents module's CARD_SELECT).

const _fileRow = {
  'id': 'f1',
  'fileName': 'FM handover checklist.pdf',
  'mimeType': 'application/pdf',
  'fileType': 'PDF',
  'sizeBytes': 2457600,
  'sortOrder': 0,
  'downloadCount': 12,
};

const _sheetRow = {
  'id': 'f2',
  'fileName': 'Scorecard.xlsx',
  'mimeType': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'fileType': 'SPREADSHEET',
  'sizeBytes': 90112,
  'sortOrder': 1,
  'downloadCount': 3,
};

const _docRow = {
  'id': 'd1',
  'title': 'FM handover checklist',
  'description': 'A 60-point list for taking over a building.',
  'category': 'Integrated Facility Management',
  'subcategory': 'Handover & Commissioning',
  'specialization': null,
  'fileCount': 1,
  'totalSizeBytes': 2457600,
  'files': [_fileRow],
  'downloadCount': 12,
  'viewCount': 40,
  'createdAt': '2026-10-12T04:30:00.000Z',
  'uploaderId': 'u1',
  'uploader': {
    'id': 'u1',
    'firstName': 'Priya',
    'lastName': 'Nambiar',
    'avatarUrl': '/uploads/priya.jpg',
    'title': 'Sustainability Lead',
  },
};

final _packRow = {
  ..._docRow,
  'id': 'd2',
  'title': 'Vendor SLA pack',
  'description': null,
  'category': null,
  'subcategory': null,
  'fileCount': 2,
  'totalSizeBytes': 2547712,
  'files': [_fileRow, _sheetRow],
  'uploaderId': 'u2',
  'uploader': {'id': 'u2', 'firstName': 'Arvind', 'lastName': 'Swamy', 'avatarUrl': null, 'title': null},
};

Map<String, dynamic> _page(List<Object> rows, {bool hasNext = false, int? total, int page = 1}) => {
  'data': rows,
  'meta': {
    'page': page,
    'limit': 24,
    'total': total ?? rows.length,
    'totalPages': hasNext ? page + 1 : page,
    'hasNext': hasNext,
    'hasPrev': page > 1,
  },
};

/// A phone 390 dp wide and [height] dp tall: tall enough that a lazy list builds the whole screen.
void _view(WidgetTester tester, {double height = 4200}) {
  tester.view.physicalSize = Size(780, height * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

class _Lib {
  _Lib(this.repo, {LibraryQuery? initial})
    : controller = LibraryController(repo, initial: initial ?? const LibraryQuery());

  final FakeLibrary repo;
  final LibraryController controller;
  final device = FakeLibraryDevice();
  int backs = 0;
  int bells = 0;
  int plans = 0;
  final members = <String>[];
  final shared = <(String, Uri)>[];
}

Future<_Lib> _pumpLibrary(
  WidgetTester tester, {
  FakeLibrary? repo,
  LibraryQuery? initial,
  double height = 4200,
  bool ownBell = false,
}) async {
  _view(tester, height: height);
  final lib = _Lib(repo ?? FakeLibrary(), initial: initial);
  // A fresh tree, so a second pump in one test starts its screen again.
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: ChangeNotifierProvider.value(
        value: lib.controller,
        child: LibraryScreen(
          onBack: () => lib.backs++,
          onBell: ownBell ? () => lib.bells++ : null,
          onOpenMember: lib.members.add,
          onOpenPlans: () => lib.plans++,
          device: lib.device,
          share: (title, link) async => lib.shared.add((title, link)),
          searchDelay: const Duration(milliseconds: 50),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return lib;
}

LibraryDocument _doc(String id, {int files = 1, String? category, String? sub, String? spec}) => LibraryDocument(
  id: id,
  title: 'Doc $id',
  uploaderId: 'u',
  category: category,
  subcategory: sub,
  specialization: spec,
  fileCount: files,
  totalSizeBytes: files * 2 * 1024 * 1024,
  files: [
    const LibraryFile(
      id: 'a',
      fileName: 'a.pdf',
      mimeType: 'application/pdf',
      sizeBytes: 2 * 1024 * 1024,
      fileType: LibraryFileType.pdf,
    ),
    if (files > 1)
      const LibraryFile(
        id: 'b',
        fileName: 'b.xlsx',
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        sizeBytes: 2 * 1024 * 1024,
        fileType: LibraryFileType.spreadsheet,
      ),
  ],
);

/// The chip [label] in the [row]th sideways row (kinds, categories, formats), scrolled into view: a
/// sideways list builds only what is on screen.
Future<Finder> _chip(WidgetTester tester, int row, String label) async {
  final chip = find.widgetWithText(IcrChip, label);
  if (chip.evaluate().isEmpty) {
    final scrollable = find.descendant(of: find.byType(ChipRow).at(row), matching: find.byType(Scrollable));
    // Rightwards for a chip further along the row, leftwards when the row was already scrolled past it.
    try {
      await tester.scrollUntilVisible(chip, 120, scrollable: scrollable, maxScrolls: 30);
    } on StateError {
      await tester.scrollUntilVisible(chip, -120, scrollable: scrollable, maxScrolls: 30);
    }
    await tester.pumpAndSettle();
  }
  return chip;
}

void main() {
  setUpAll(loadAppFonts);

  group('formats and words', () {
    test('a file’s format is its MIME type first, its extension second, and any image/* is an image', () {
      expect(LibraryFileType.classify('application/pdf', 'x.bin'), LibraryFileType.pdf);
      expect(LibraryFileType.classify('application/octet-stream', 'plan.XLSX'), LibraryFileType.spreadsheet);
      expect(LibraryFileType.classify('text/csv', 'a.csv'), LibraryFileType.spreadsheet);
      expect(LibraryFileType.classify('application/x-zip-compressed', 'a.zip'), LibraryFileType.archive);
      expect(LibraryFileType.classify('image/heic', 'photo'), LibraryFileType.image);
      expect(LibraryFileType.classify('application/octet-stream', 'noext'), LibraryFileType.other);
      expect(LibraryFileType.fromApi('PRESENTATION'), LibraryFileType.presentation);
      expect(LibraryFileType.fromApi('???'), LibraryFileType.other);
      expect(LibraryFileType.values.map((t) => t.label), [
        'PDF',
        'Word',
        'Spreadsheet',
        'Presentation',
        'Image',
        'Archive',
        'Text',
        'Other',
      ]);
    });

    test('the plate names the format: MIME first, a short extension next, FILE last', () {
      expect(FileGlyph.of('application/pdf', 'a.pdf').label, 'PDF');
      expect(
        FileGlyph.of('application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'a.docx').label,
        'DOCX',
      );
      expect(FileGlyph.of('application/octet-stream', 'notes.md').label, 'MD');
      expect(FileGlyph.of('application/octet-stream', 'x.thisisnotanextension').label, 'FILE');
      expect(FileGlyph.of('application/octet-stream', 'noext').label, 'FILE');
    });

    test('a card’s line names the format and size, or the pack’s files and formats', () {
      final demo = DemoLibraryRepository();
      expect(contentsLine(_doc('a', files: 1)), 'PDF · 2.0 MB');
      expect(contentsLine(_doc('b', files: 2)), '2 files · PDF, XLSX · 4.0 MB');
      expect(demo.now, DateTime.utc(2026, 10, 24, 9));
    });

    test('counts stay short and dates read on the Indian clock', () {
      expect(compactCount(980), '980');
      expect(compactCount(1290), '1,290');
      expect(compactCount(12400), '12.4k');
      expect(compactCount(10000), '10k');
      expect(compactCount(250000), '250k');
      expect(shortDate(DateTime.utc(2026, 10, 12, 20)), '13 Oct 2026');
      expect(filesLabel(1), '1 file');
      expect(documentsLabel(1), '1 document');
      expect(documentsLabel(1200), '1,200 documents');
      expect(percentLabel(0.636), '64%');
    });

    test('a document names where it is filed and the formats of its pack', () {
      final d = _doc('x', files: 2, category: 'A', sub: 'B', spec: 'C');
      expect(d.categoryPath, 'A › B › C');
      expect(_doc('y').categoryPath, isNull);
      expect(d.formats, ['PDF', 'XLSX']);
      expect(d.isPack, isTrue);
    });

    test('the query is filtered by a search, a category, a format or My uploads, not by the sort', () {
      expect(const LibraryQuery().filtered, isFalse);
      expect(const LibraryQuery(sort: LibrarySort.az).filtered, isFalse);
      expect(const LibraryQuery(search: ' ').filtered, isFalse);
      expect(const LibraryQuery(search: 'sop').filtered, isTrue);
      expect(const LibraryQuery(category: 'x').filtered, isTrue);
      expect(const LibraryQuery(fileType: LibraryFileType.pdf).filtered, isTrue);
      expect(const LibraryQuery(mine: true).filtered, isTrue);
      expect(const LibraryQuery().copyWith(category: 'x').copyWith(clearCategory: true).category, isNull);
    });

    test('the kinds the website lists are the ten quick searches', () {
      expect(libraryKinds.map((k) => k.label), [
        'Insights',
        'Best Practices',
        'SOPs',
        'Checklists',
        'Policies',
        'Processes',
        'Templates',
        'Standards',
        'Research',
        'Case Studies',
      ]);
      expect(libraryKinds.firstWhere((k) => k.label == 'SOPs').term, 'SOP');
    });
  });

  group('the API mapping', () {
    TableApi api() => TableApi({
      'GET /documents': (o) => _page([_docRow, _packRow], total: 31, hasNext: true),
      'GET /documents/categories': (_) => ['Integrated Facility Management', 'Fire & Life Safety'],
      'GET /documents/file-types': (_) => [
        {'type': 'PDF', 'label': 'PDF', 'count': 5},
        {'type': 'SPREADSHEET', 'label': 'Spreadsheet', 'count': 2},
      ],
      'GET /categories/tree': (_) => [
        {
          'name': 'Corporate Real Estate',
          'level': 1,
          'children': [
            {'name': 'Real Estate Advisory', 'level': 2, 'children': <Object>[]},
          ],
        },
        {'name': 'Technology', 'level': 1, 'children': <Object>[]},
      ],
      'GET /auth/me': (_) => {'id': 'u1', 'firstName': 'Bharat', 'lastName': 'Buyer', 'email': 'b@x', 'role': 'BUYER'},
      'GET /notifications/unread-count': (_) => {'unread': 4},
    });

    test('the list is the API’s page, with each query part sent as the API names it', () async {
      final table = api();
      final repo = ApiLibraryRepository(api: table.client());
      final page = await repo.documents(
        const LibraryQuery(
          search: ' checklist ',
          category: 'Fire & Life Safety',
          fileType: LibraryFileType.spreadsheet,
          mine: true,
          sort: LibrarySort.largest,
          page: 2,
        ),
      );
      expect(table.queryOf('GET /documents'), {
        'page': 2,
        'limit': 24,
        'search': 'checklist',
        'category': 'Fire & Life Safety',
        'fileType': 'SPREADSHEET',
        'mine': 'true',
        'sortBy': 'sizeBytes',
        'sortDir': 'desc',
      });
      expect(page.total, 31);
      expect(page.hasNext, isTrue);
      await repo.documents(const LibraryQuery());
      expect(table.queryOf('GET /documents'), {'page': 1, 'limit': 24, 'sortBy': 'downloadCount', 'sortDir': 'desc'});
    });

    test('a card carries the files, the counts, who shared it and where it is filed', () async {
      final repo = ApiLibraryRepository(api: api().client());
      final page = await repo.documents(const LibraryQuery());
      final d = page.documents.first;
      expect(d.title, 'FM handover checklist');
      expect(d.category, 'Integrated Facility Management');
      expect(d.subcategory, 'Handover & Commissioning');
      expect(d.specialization, isNull);
      expect(d.categoryPath, 'Integrated Facility Management › Handover & Commissioning');
      expect(d.viewCount, 40);
      expect(d.downloadCount, 12);
      expect(d.createdAt, DateTime.utc(2026, 10, 12, 4, 30));
      expect(d.uploaderId, 'u1');
      expect(d.uploader!.name, 'Priya Nambiar');
      expect(d.uploader!.title, 'Sustainability Lead');
      expect(d.uploader!.photo!.url, 'http://api.test/uploads/priya.jpg');
      final f = d.files.single;
      expect(f.fileType, LibraryFileType.pdf);
      expect(f.sizeBytes, 2457600);
      expect(f.downloadCount, 12);
      expect(f.isImage, isFalse);
      final pack = page.documents.last;
      expect(pack.isPack, isTrue);
      expect(pack.files.map((f) => f.glyph.label), ['PDF', 'XLSX']);
      expect(pack.description, isNull);
      expect(pack.category, isNull);
      expect(pack.uploader!.photo, isNull);
    });

    test('the chips are the categories in use, and the formats with how many documents each', () async {
      final repo = ApiLibraryRepository(api: api().client());
      expect(await repo.categories(), ['Integrated Facility Management', 'Fire & Life Safety']);
      final types = await repo.fileTypes();
      expect(types.map((t) => t.type), [LibraryFileType.pdf, LibraryFileType.spreadsheet]);
      expect(types.map((t) => t.count), [5, 2]);
      expect(types.last.label, 'Spreadsheet');
    });

    test('My uploads is a count read through ?mine=true, and zero signed out', () async {
      final table = api();
      table.routes['GET /documents'] = (o) =>
          o.queryParameters['mine'] == 'true' ? _page([_docRow], total: 7) : _page([]);
      expect(await ApiLibraryRepository(api: table.client()).myUploadCount(), 7);
      expect(table.queryOf('GET /documents'), {'mine': 'true', 'limit': 1});
      table.routes['GET /documents'] = (_) => (401, '{"message":"Unauthorized"}');
      expect(await ApiLibraryRepository(api: table.client()).myUploadCount(), 0);
    });

    test('a document is found by id by reading the library (the API has no GET /documents/:id)', () async {
      final table = api();
      table.routes['GET /documents'] = (o) {
        final page = o.queryParameters['page'] as int;
        return page == 1 ? _page([_docRow], hasNext: true) : _page([_packRow], page: 2);
      };
      final repo = ApiLibraryRepository(api: table.client());
      expect((await repo.document('d2')).title, 'Vendor SLA pack');
      expect(table.count('GET /documents'), 2);
      expect(table.queryOf('GET /documents')['limit'], 100);
      await expectLater(
        repo.document('gone'),
        throwsA(
          isA<ApiError>()
              .having((e) => e.statusCode, 'status', 404)
              .having((e) => e.message, 'message', contains('no longer in the library')),
        ),
      );
    });

    test('the taxonomy is three levels of names; the viewer is who the API says is signed in', () async {
      final repo = ApiLibraryRepository(api: api().client());
      final tree = await repo.taxonomy();
      expect(tree.map((n) => n.label), ['Corporate Real Estate', 'Technology']);
      expect(tree.first.children.single.label, 'Real Estate Advisory');
      final v = await repo.viewer();
      expect(v!.id, 'u1');
      expect(v.isAdmin, isFalse);
      expect(await repo.unreadNotifications(), 4);
      final table = api()..routes['GET /auth/me'] = (_) => (401, '{"message":"Unauthorized"}');
      expect(await ApiLibraryRepository(api: table.client()).viewer(), isNull);
      expect(const LibraryViewer(id: 'a', isAdmin: true).mayChange(_doc('x')), isTrue);
    });

    test(
      'a file is read with the member’s session by id, always as the viewer’s read (preview=true), never a download',
      () async {
        final table = api();
        table.routes['GET /documents/d1/download'] = (_) => utf8.encode('%PDF bytes');
        final repo = ApiLibraryRepository(api: table.client());
        final doc = (await repo.documents(const LibraryQuery())).documents.first;
        final read = await repo.previewFile(doc, doc.files.first);
        expect(table.queryOf('GET /documents/d1/download'), {'fileId': 'f1', 'preview': 'true'});
        expect(read.bytes, utf8.encode('%PDF bytes'));
        expect(read.fileName, 'FM handover checklist.pdf');
        expect(read.mimeType, 'application/pdf');
      },
    );

    test('a refusal on a download is the API’s own sentence, decoded from the bytes it arrived as', () async {
      final table = api();
      table.routes['GET /documents/d1/download'] = (_) =>
          (403, '{"message":"Your plan does not include this document.","statusCode":403}');
      final repo = ApiLibraryRepository(api: table.client());
      final doc = (await repo.documents(const LibraryQuery())).documents.first;
      await expectLater(
        repo.previewFile(doc, doc.files.first),
        throwsA(
          isA<ApiError>()
              .having((e) => e.statusCode, 'status', 403)
              .having((e) => e.message, 'message', 'Your plan does not include this document.'),
        ),
      );
      table.routes['GET /documents/d1/download'] = (_) => (401, '{"message":"Unauthorized"}');
      await expectLater(
        repo.previewFile(doc, doc.files.first),
        throwsA(
          isA<ApiError>()
              .having((e) => e.statusCode, 'status', 401)
              .having((e) => e.message, 'message', 'Unauthorized'),
        ),
      );
      table.routes['GET /documents/d1/download'] = (_) => (500, 'not json');
      await expectLater(
        repo.previewFile(doc, doc.files.first),
        throwsA(
          isA<ApiError>()
              .having((e) => e.statusCode, 'status', 500)
              .having((e) => e.message, 'message', contains('Something went wrong')),
        ),
      );
    });

    test('the view counter is POST /documents/:id/view', () async {
      final table = api()..routes['POST /documents/d1/view'] = (_) => {'viewCount': 41};
      expect(await ApiLibraryRepository(api: table.client()).recordView('d1'), 41);
    });

    test('an upload is multipart to /uploads with the document-hub purpose, under the file’s name and type', () async {
      final table = api()
        ..routes['POST /uploads'] = (_) => {
          'url': '/uploads/abc.pdf',
          'name': 'Plan.pdf',
          'size': 3,
          'mimeType': 'application/pdf',
        };
      final repo = ApiLibraryRepository(api: table.client());
      final progress = <double>[];
      final stored = await repo.upload(
        PickedFile(name: 'Plan.pdf', bytes: Uint8List.fromList([1, 2, 3])),
        onProgress: progress.add,
      );
      expect(table.queryOf('POST /uploads'), {'purpose': 'document-hub'});
      final form = table.lastOf('POST /uploads').data as FormData;
      expect(form.files.single.key, 'file');
      expect(form.files.single.value.filename, 'Plan.pdf');
      expect(form.files.single.value.contentType.toString(), 'application/pdf');
      expect(stored.url, '/uploads/abc.pdf');
      expect(stored.toJson(), {
        'fileUrl': '/uploads/abc.pdf',
        'fileName': 'Plan.pdf',
        'mimeType': 'application/pdf',
        'sizeBytes': 3,
      });
      expect(ApiLibraryRepository.mimeForName('a.JPG'), 'image/jpeg');
      expect(ApiLibraryRepository.mimeForName('a.exe'), isNull);
    });

    test('filing a document sends the title, the three levels and the stored files, in order', () async {
      final table = api()..routes['POST /documents'] = (_) => _docRow;
      final repo = ApiLibraryRepository(api: table.client());
      final doc = await repo.create(
        const DocumentDraft(title: 'T', description: 'D', category: 'C', subcategory: 'S', specialization: 'P'),
        const [
          StoredFile(url: '/uploads/a.pdf', name: 'a.pdf', size: 10, mimeType: 'application/pdf'),
          StoredFile(url: '/uploads/b.xlsx', name: 'b.xlsx', size: 20, mimeType: 'application/vnd.ms-excel'),
        ],
      );
      expect(doc.id, 'd1');
      expect(table.lastOf('POST /documents').data, {
        'title': 'T',
        'description': 'D',
        'category': 'C',
        'subcategory': 'S',
        'specialization': 'P',
        'files': [
          {'fileUrl': '/uploads/a.pdf', 'fileName': 'a.pdf', 'mimeType': 'application/pdf', 'sizeBytes': 10},
          {'fileUrl': '/uploads/b.xlsx', 'fileName': 'b.xlsx', 'mimeType': 'application/vnd.ms-excel', 'sizeBytes': 20},
        ],
      });
      await repo.create(const DocumentDraft(title: 'Only'), const [
        StoredFile(url: '/uploads/a.pdf', name: 'a.pdf', size: 1, mimeType: 'application/pdf'),
      ]);
      expect((table.lastOf('POST /documents').data as Map).keys, containsAll(['title', 'files']));
      expect((table.lastOf('POST /documents').data as Map).containsKey('description'), isFalse);
    });

    test('adding files, dropping one, deleting and reporting are the API’s routes and bodies', () async {
      final table = api();
      table.routes['POST /documents/d1/files'] = (_) => _packRow;
      table.routes['DELETE /documents/d1/files/f2'] = (_) => {'success': true};
      table.routes['DELETE /documents/d1'] = (_) => {'success': true};
      table.routes['POST /documents/d1/report'] = (_) => {'id': 'r1', 'status': 'PENDING'};
      final repo = ApiLibraryRepository(api: table.client());
      expect(
        (await repo.addFiles('d1', const [
          StoredFile(url: '/uploads/z.pdf', name: 'z.pdf', size: 5, mimeType: 'application/pdf'),
        ])).fileCount,
        2,
      );
      expect((table.lastOf('POST /documents/d1/files').data as Map)['files'], hasLength(1));
      await repo.removeFile('d1', 'f2');
      await repo.delete('d1');
      await repo.report('d1', DocumentReportReason.brokenFile, note: '  page 3 is blank ');
      expect(table.lastOf('POST /documents/d1/report').data, {'reason': 'BROKEN_FILE', 'note': 'page 3 is blank'});
      await repo.report('d1', DocumentReportReason.spam);
      expect(table.lastOf('POST /documents/d1/report').data, {'reason': 'SPAM'});
      expect(table.calls, containsAll(['DELETE /documents/d1/files/f2', 'DELETE /documents/d1']));
    });

    test('the report reasons are the API’s six, worded as the website words them', () {
      expect(DocumentReportReason.values.map((r) => r.api), [
        'COPYRIGHT',
        'INAPPROPRIATE',
        'MISLEADING',
        'SPAM',
        'BROKEN_FILE',
        'OTHER',
      ]);
      expect(DocumentReportReason.copyright.label, 'Copyright or confidential material');
      expect(DocumentReportReason.other.label, 'Something else');
    });
  });

  group('the list’s controller', () {
    Future<LibraryController> started([FakeLibrary? repo, LibraryQuery? initial]) async {
      final c = LibraryController(repo ?? FakeLibrary(), initial: initial ?? const LibraryQuery());
      await c.start();
      return c;
    }

    test('it reads the first page, the chips’ facets, the member’s own count and the bell', () async {
      final repo = FakeLibrary(unread: 2);
      final c = await started(repo);
      expect(c.documents, hasLength(12));
      expect(c.total, 12);
      expect(c.libraryTotal, 12);
      expect(c.categories, hasLength(5));
      expect(c.fileTypes.map((f) => f.type), [
        LibraryFileType.pdf,
        LibraryFileType.word,
        LibraryFileType.spreadsheet,
        LibraryFileType.presentation,
        LibraryFileType.image,
        LibraryFileType.archive,
        LibraryFileType.text,
      ]);
      expect(c.myUploads, 3);
      expect(c.viewer!.id, DemoLibraryRepository.meId);
      expect(c.unread, 2);
      // Most downloaded first, the website's default.
      expect(c.documents.first.title, 'Vendor SLA Scorecard Template');
    });

    test('each filter is a query the API runs, and the first page is read again', () async {
      final repo = FakeLibrary();
      final c = await started(repo);
      c.setCategory('Technology');
      await Future<void>.delayed(Duration.zero);
      expect(c.documents.map((d) => d.id).toSet(), {'d6', 'd8'});
      expect(c.total, 2);
      c.setFileType(LibraryFileType.pdf);
      await Future<void>.delayed(Duration.zero);
      expect(c.documents.map((d) => d.id), ['d8']);
      c.setFileType(null);
      c.setCategory(null);
      c.setMine(true);
      await Future<void>.delayed(Duration.zero);
      expect(c.documents.map((d) => d.id).toSet(), {'d3', 'd5', 'd9'});
      c.setMine(false);
      c.setSort(LibrarySort.az);
      await Future<void>.delayed(Duration.zero);
      expect(c.documents.first.title, 'BRSR Core Reporting Guide for Facility Teams');
      c.setSort(LibrarySort.newest);
      await Future<void>.delayed(Duration.zero);
      expect(c.documents.first.id, 'd9');
      c.setSort(LibrarySort.views);
      await Future<void>.delayed(Duration.zero);
      expect(c.documents.first.id, 'd3');
      c.setSort(LibrarySort.largest);
      await Future<void>.delayed(Duration.zero);
      expect(c.documents.first.id, 'd5');
      c.setSearch('  lease ');
      await Future<void>.delayed(Duration.zero);
      expect(c.query.search, 'lease');
      expect(c.documents.map((d) => d.id), ['d5']);
      // The library's own size is the unfiltered total, kept while a filter is on.
      expect(c.libraryTotal, 12);
      expect(c.filtered, isTrue);
      c.clearFilters();
      await Future<void>.delayed(Duration.zero);
      expect(c.filtered, isFalse);
      expect(c.documents, hasLength(12));
      expect(c.query.sort, LibrarySort.largest, reason: 'the sort stays: it is not a filter');
    });

    test('a kind chip is a quick search; the same chip again takes it out', () async {
      final c = await started();
      final sops = libraryKinds.firstWhere((k) => k.label == 'SOPs');
      c.toggleKind(sops);
      await Future<void>.delayed(Duration.zero);
      expect(c.query.search, 'SOP');
      expect(c.activeKind, sops);
      expect(c.documents.map((d) => d.id), ['d2']);
      c.toggleKind(sops);
      await Future<void>.delayed(Duration.zero);
      expect(c.activeKind, isNull);
      expect(c.documents, hasLength(12));
      c.setSearch('something else');
      expect(c.activeKind, isNull);
    });

    test('Show more reads the next page and appends it, once each document', () async {
      final repo = FakeLibrary();
      final c = await started(repo, const LibraryQuery(limit: 5));
      expect(c.documents, hasLength(5));
      expect(c.hasNext, isTrue);
      await c.loadMore();
      expect(c.documents, hasLength(10));
      expect(c.query.page, 2);
      await c.loadMore();
      expect(c.documents, hasLength(12));
      expect(c.hasNext, isFalse);
      expect(c.documents.map((d) => d.id).toSet(), hasLength(12));
      await c.loadMore();
      expect(repo.count('documents'), 3);
    });

    test(
      'a failed read keeps the sentence until a refresh reads again; a failed Show more keeps what was read',
      () async {
        final repo = FakeLibrary()..failures['documents'] = ApiError('Library is down', statusCode: 500);
        final c = await started(repo);
        expect(c.documents, isEmpty);
        expect(c.error, 'Library is down');
        repo.failures.clear();
        await c.refresh();
        expect(c.error, isNull);
        expect(c.documents, hasLength(12));

        final more = await started(FakeLibrary(), const LibraryQuery(limit: 5));
        (more.repository as FakeLibrary).failures['documents:2'] = ApiError('Try later', statusCode: 500);
        await more.loadMore();
        expect(more.moreError, 'Try later');
        expect(more.documents, hasLength(5));
      },
    );

    test('a stale answer is dropped: the last query wins', () async {
      final repo = FakeLibrary();
      final c = await started(repo);
      c.setSearch('lease');
      c.setSearch('chiller');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(c.query.search, 'chiller');
      expect(c.documents.map((d) => d.id), ['d9']);
    });

    test('a change made on a document’s page reaches the list; a delete takes it out and counts down', () async {
      final c = await started();
      final d = c.documents.firstWhere((d) => d.id == 'd1');
      c.documentChanged(d.copyWith(viewCount: 999));
      expect(c.documents.firstWhere((x) => x.id == 'd1').viewCount, 999);
      c.documentRemoved('d3');
      expect(c.documents.any((x) => x.id == 'd3'), isFalse);
      expect(c.total, 11);
      expect(c.libraryTotal, 11);
      expect(c.myUploads, 2);
    });

    test('a document shared reads the list and the facets again', () async {
      final repo = FakeLibrary();
      final c = await started(repo);
      await repo.inner.create(const DocumentDraft(title: 'New one', category: 'Brand new category'), const [
        StoredFile(url: '/uploads/n.pdf', name: 'n.pdf', size: 10, mimeType: 'application/pdf'),
      ]);
      await c.documentAdded();
      expect(c.documents, hasLength(13));
      expect(c.categories, contains('Brand new category'));
      expect(c.myUploads, 4);
      expect(c.libraryTotal, 13);
    });
  });

  group('the Digital Library screen', () {
    testWidgets('draws the tiles, the kinds, the chips and a card per document, as the API gave them', (tester) async {
      await _pumpLibrary(tester);
      expect(find.text('Digital Library'), findsOneWidget);
      for (final label in ['Categories', 'Formats', 'Your uploads']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('Documents'), findsNWidgets(2)); // the tile and the list's heading
      expect(find.text('Browse by kind'), findsOneWidget);
      for (final k in libraryKinds.take(3)) {
        expect(find.text(k.label), findsOneWidget);
      }
      expect(find.text('All Categories (5)'), findsOneWidget);
      expect(find.text('All formats'), findsOneWidget);
      expect(find.text('PDF (5)'), findsOneWidget);
      expect(find.text('12 documents'), findsOneWidget);
      expect(find.byType(DocumentCard), findsNWidgets(12));
      expect(find.text('FM Handover Checklist: New Building Takeover'), findsOneWidget);
      // The pack's card names its files and formats; the member's own cards say so.
      expect(find.text('3 files · XLSX, PDF · 541 KB'), findsOneWidget);
      expect(find.text('YOURS'), findsNWidgets(3));
      expect(find.text('Share what you know'), findsOneWidget);
    });

    testWidgets('Back and the bell', (tester) async {
      final lib = await _pumpLibrary(tester);
      await tester.tap(find.byIcon(Symbols.arrow_back));
      expect(lib.backs, 1);
      await tester.tap(find.byIcon(LucideIcons.bell));
      expect(lib.device.opened.last, AppConfig.sitePage('/notifications'));

      final own = await _pumpLibrary(tester, ownBell: true);
      await tester.tap(find.byIcon(LucideIcons.bell));
      expect(own.bells, 1);
      expect(own.device.opened, isEmpty);
    });

    testWidgets('the bell wears its dot while something is unread', (tester) async {
      await _pumpLibrary(tester, repo: FakeLibrary(unread: 3));
      expect(find.bySemanticsLabel('Notifications, 3 unread'), findsOneWidget);
    });

    testWidgets(
      'the search runs on a pause, narrows the cards, says when nothing matches, and Clear filters brings them back',
      (tester) async {
        final lib = await _pumpLibrary(tester);
        await tester.enterText(find.byType(TextField), 'lease');
        await tester.pump(const Duration(milliseconds: 10));
        // Typing waits for a pause: nothing was asked yet.
        expect(lib.repo.calls.where((c) => c.startsWith('documents')).length, 1);
        await tester.pump(const Duration(milliseconds: 80));
        await tester.pumpAndSettle();
        expect(find.byType(DocumentCard), findsOneWidget);
        expect(find.text('1 document'), findsOneWidget);
        expect(find.text('Clear filters'), findsOneWidget);

        await tester.enterText(find.byType(TextField), 'zzzz');
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();
        expect(find.text('No documents match'), findsOneWidget);
        await tester.tap(find.text('Clear filters').last);
        await tester.pumpAndSettle();
        expect(find.byType(DocumentCard), findsNWidgets(12));
        expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
      },
    );

    testWidgets('a kind chip types its word into the box and searches; the same chip takes it out', (tester) async {
      await _pumpLibrary(tester);
      await tester.tap(await _chip(tester, 0, 'Checklists'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Checklist');
      expect(find.byType(DocumentCard), findsNWidgets(2));
      await tester.tap(await _chip(tester, 0, 'Checklists'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
      expect(find.byType(DocumentCard), findsNWidgets(12));
    });

    testWidgets('a category chip and a format chip narrow the cards; again, or All, widens', (tester) async {
      await _pumpLibrary(tester);
      await tester.tap(await _chip(tester, 1, 'Technology'));
      await tester.pumpAndSettle();
      expect(find.byType(DocumentCard), findsNWidgets(2));
      await tester.tap(await _chip(tester, 2, 'PDF (5)'));
      await tester.pumpAndSettle();
      expect(find.byType(DocumentCard), findsOneWidget);
      expect(find.text('Energy Intensity Case Study: A 12,000-seat Campus'), findsOneWidget);
      await tester.tap(await _chip(tester, 2, 'PDF (5)'));
      await tester.pumpAndSettle();
      expect(find.byType(DocumentCard), findsNWidgets(2));
      await tester.tap(await _chip(tester, 1, 'All Categories (5)'));
      await tester.pumpAndSettle();
      expect(find.byType(DocumentCard), findsNWidgets(12));
      await tester.tap(await _chip(tester, 2, 'Image (1)'));
      await tester.pumpAndSettle();
      expect(find.byType(DocumentCard), findsOneWidget);
      await tester.tap(await _chip(tester, 2, 'All formats'));
      await tester.pumpAndSettle();
      expect(find.byType(DocumentCard), findsNWidgets(12));
    });

    testWidgets('the sliders glyph opens the sorts and "Only my uploads"; each acts and Reset undoes them', (
      tester,
    ) async {
      final lib = await _pumpLibrary(tester);
      await tester.tap(find.bySemanticsLabel('Sort and filter documents'));
      await tester.pumpAndSettle();
      for (final label in ['Most downloaded', 'Newest', 'Most viewed', 'A to Z', 'Largest']) {
        expect(find.text(label), findsOneWidget);
      }
      await tester.tap(find.text('A to Z'));
      await tester.pumpAndSettle();
      expect(lib.controller.query.sort, LibrarySort.az);
      await tester.tap(find.text('Only my uploads'));
      await tester.pumpAndSettle();
      expect(lib.controller.query.mine, isTrue);
      await tester.tap(find.text('Show documents'));
      await tester.pumpAndSettle();
      expect(find.byType(DocumentCard), findsNWidgets(3));
      expect(find.text('Your uploads'), findsWidgets);
      expect(
        tester.widget<DocumentCard>(find.byType(DocumentCard).first).document.title,
        'Chiller Plant Room Walk-down',
      );

      await tester.tap(find.bySemanticsLabel('Sort and filter documents'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      expect(lib.controller.query.sort, LibrarySort.downloads);
      expect(lib.controller.query.mine, isFalse);
      expect(find.byType(DocumentCard), findsNWidgets(12));
    });

    testWidgets('the Your uploads tile is My uploads: it narrows to the member’s own and again takes it off', (
      tester,
    ) async {
      final lib = await _pumpLibrary(tester);
      expect(find.text('3'), findsWidgets);
      await tester.tap(find.text('Your uploads').first);
      await tester.pumpAndSettle();
      expect(lib.controller.query.mine, isTrue);
      expect(find.byType(DocumentCard), findsNWidgets(3));
      await tester.tap(find.text('Your uploads').first);
      await tester.pumpAndSettle();
      expect(find.byType(DocumentCard), findsNWidgets(12));
    });

    testWidgets('Show more documents appends the next page', (tester) async {
      final lib = await _pumpLibrary(tester, initial: const LibraryQuery(limit: 5));
      expect(find.byType(DocumentCard), findsNWidgets(5));
      await tester.tap(find.text('Show more documents'));
      await tester.pumpAndSettle();
      expect(find.byType(DocumentCard), findsNWidgets(10));
      await tester.tap(find.text('Show more documents'));
      await tester.pumpAndSettle();
      expect(find.byType(DocumentCard), findsNWidgets(12));
      expect(find.text('Show more documents'), findsNothing);
      expect(lib.repo.count('documents'), greaterThanOrEqualTo(3));
    });

    testWidgets('a card opens the document’s page', (tester) async {
      await _pumpLibrary(tester);
      await tester.tap(find.text('Visitor Management Policy'));
      await tester.pumpAndSettle();
      expect(find.byType(DocumentScreen), findsOneWidget);
      expect(find.text('Document'), findsOneWidget);
      expect(find.text('visitor-management-policy.txt'), findsOneWidget);
    });

    testWidgets('Upload opens the form, and a document shared there is in the list when it closes', (tester) async {
      final lib = await _pumpLibrary(tester);
      lib.device.picks.add([pickedFile('Night rounds.pdf', size: 2048)]);
      await tester.tap(find.text('Upload').first);
      await tester.pumpAndSettle();
      expect(find.byType(UploadDocumentScreen), findsOneWidget);
      await tester.tap(find.text('Choose files'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose a category'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Security').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Share with the library'));
      await tester.pumpAndSettle();
      expect(find.byType(UploadDocumentScreen), findsNothing);
      expect(find.text('“Night rounds” is in the library.'), findsOneWidget);
      expect(lib.repo.calls, containsAll(['upload:Night rounds.pdf', 'create:Night rounds']));
      expect(find.text('13 documents'), findsOneWidget);
      expect(find.text('Night rounds'), findsOneWidget);
    });

    testWidgets('the host card is the same Upload', (tester) async {
      final lib = await _pumpLibrary(tester);
      await tester.ensureVisible(find.text('Share what you know'));
      await tester.tap(find.widgetWithText(InkWell, 'Upload').last);
      await tester.pumpAndSettle();
      expect(find.byType(UploadDocumentScreen), findsOneWidget);
      expect(lib.backs, 0);
    });

    testWidgets(
      'a search with no match says so and Clear filters brings the library back; My uploads with none says what to do',
      (tester) async {
        final lib = await _pumpLibrary(tester, initial: const LibraryQuery(search: 'no such thing'));
        expect(find.text('No documents match'), findsOneWidget);
        await tester.tap(find.text('Clear filters').last);
        await tester.pumpAndSettle();
        expect(find.byType(DocumentCard), findsNWidgets(12));
        expect(lib.controller.filtered, isFalse);

        final mine = await _pumpLibrary(
          tester,
          repo: FakeLibrary(),
          initial: const LibraryQuery(mine: true, category: 'Security'),
        );
        expect(find.text('No documents match'), findsOneWidget);
        expect(find.textContaining("You haven't shared a document yet"), findsOneWidget);
        expect(mine.controller.query.mine, isTrue);
      },
    );

    testWidgets('a failed read offers Try again, which reads again', (tester) async {
      final repo = FakeLibrary()..failures['documents'] = ApiError('Server down', statusCode: 500);
      await _pumpLibrary(tester, repo: repo);
      expect(find.text("Couldn't load the library"), findsOneWidget);
      expect(find.text('Server down'), findsOneWidget);
      repo.failures.clear();
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.byType(DocumentCard), findsNWidgets(12));
    });

    testWidgets('while the first read is on its way there is a spinner and no cards', (tester) async {
      _view(tester);
      final repo = FakeLibrary();
      final gate = Completer<void>();
      repo.gate = gate.future;
      final controller = LibraryController(repo);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ChangeNotifierProvider.value(
            value: controller,
            child: LibraryScreen(onBack: () {}),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(find.byType(DocumentCard), findsNothing);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(DocumentCard), findsNWidgets(12));
    });

    testWidgets('pulling down reads the library, the chips and the bell again', (tester) async {
      final lib = await _pumpLibrary(tester, height: 800);
      expect(lib.repo.count('documents'), 1);
      lib.repo.unread = 2;
      await tester.fling(find.byType(ListView).first, const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(lib.repo.count('documents'), 2);
      expect(lib.repo.count('categories'), 2);
      expect(lib.controller.unread, 2);
    });

    testWidgets('a document deleted on its page leaves the list behind it', (tester) async {
      final lib = await _pumpLibrary(tester);
      await tester.tap(find.text('Chiller Plant Room Walk-down'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Delete'));
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Delete')));
      await tester.pumpAndSettle();
      expect(find.byType(DocumentScreen), findsNothing);
      expect(find.text('Chiller Plant Room Walk-down'), findsNothing);
      expect(find.text('11 documents'), findsOneWidget);
      expect(lib.repo.calls, contains('delete:d9'));
    });
  });
}
