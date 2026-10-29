/// The Digital Library against the LOCAL portal API, seeded by `tool/seed/library.ts` (31 documents in every
/// format, with real files): the app's own repository and controllers, the way the screens use them, with the
/// effect read back through the API.
///
/// Writes undo themselves where the API allows. A document the test uploads is deleted again (the stored
/// bytes stay in uploads/: there is no route that removes an upload); a report is resolved by the ICR admin
/// (Sana Admin, the e2e SUPER_ADMIN) as APPROVED, which closes it and leaves the document standing. What the
/// API cannot give back are its two popularity counters: a download and a first view each add one, on the
/// small seeded documents the tests use, and re-running `tool/seed/library.ts` counts from the designed
/// numbers again.
///
///     flutter test test/live/library_live_test.dart
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/features/library/api_library_repository.dart';
import 'package:icr_mobile/features/library/document_controller.dart';
import 'package:icr_mobile/features/library/library_controller.dart';
import 'package:icr_mobile/features/library/library_models.dart';
import 'package:icr_mobile/features/library/upload_controller.dart';

import 'live.dart';

const _admin = LivePerson('superadmin@icr.test', 'Test@12345', 'Sana Admin');

/// The seeded documents the tests lean on.
const _handover = 'design-doc-handover-checklist'; // Divya's PDF, a download target
const _assetRegister = 'design-doc-asset-register'; // a small CSV, the counters' guinea pig
const _scorecard = 'design-doc-sla-scorecard'; // Bharat's workbook
const _leasePack = 'design-doc-lease-workbook'; // Bharat's 3-file pack
const _visitorPolicy = 'design-doc-visitor-policy'; // Pooja's text file

Future<ApiLibraryRepository> _repository([LivePerson who = bharat]) async =>
    ApiLibraryRepository(api: await liveClient(who));

Future<LibraryController> _library([LivePerson who = bharat, LibraryQuery? initial]) async {
  final c = LibraryController(await _repository(who), initial: initial ?? const LibraryQuery());
  await c.start();
  expect(c.error, isNull, reason: 'the library should load from the local API');
  return c;
}

Future<List<Map<String, dynamic>>> _rows(ApiClient api, String path, [Map<String, dynamic>? query]) async {
  final res = await api.dio.get<Map<String, dynamic>>(path, queryParameters: {'limit': 100, ...?query});
  return (res.data!['data'] as List).cast<Map<String, dynamic>>();
}

/// Whether the designed library is in the database; the test is skipped (with a reason) when it is not.
Future<bool> _seeded(ApiLibraryRepository repo) async {
  try {
    await repo.document(_handover);
    return true;
  } on ApiError {
    markTestSkipped('the library is not seeded: run tool/seed/run.ps1 (library.ts)');
    return false;
  }
}

Future<LibraryDocument> _doc(ApiLibraryRepository repo, String id) => repo.document(id);

void main() {
  liveTest(
    'the list is the API\'s: every document a card, the numbers read from them, the chips from the facets',
    () async {
      final repo = await _repository();
      if (!await _seeded(repo)) return;
      final c = await _library();
      final api = await liveClient();
      final raw = (await api.dio.get<Map<String, dynamic>>('/documents', queryParameters: {'limit': 100})).data!;
      final total = (raw['meta'] as Map)['total'] as int;

      expect(c.total, total);
      expect(c.libraryTotal, total);
      expect(c.documents.length, LibraryQuery.pageSize.clamp(0, total));
      expect(c.hasNext, total > LibraryQuery.pageSize);
      // The default sort is the website's: most downloaded first.
      for (var i = 1; i < c.documents.length; i++) {
        expect(
          c.documents[i - 1].downloadCount >= c.documents[i].downloadCount,
          isTrue,
          reason: 'most downloaded first',
        );
      }
      // Every card carries what the screen draws.
      final rows = (raw['data'] as List).cast<Map<String, dynamic>>();
      final first = (await repo.documents(const LibraryQuery(limit: 100))).documents;
      expect(first.map((d) => d.id).toSet(), rows.map((r) => r['id']).toSet());
      for (final d in first) {
        expect(d.files, isNotEmpty, reason: d.title);
        expect(d.fileCount, d.files.length, reason: d.title);
        expect(d.totalSizeBytes, d.files.fold<int>(0, (n, f) => n + f.sizeBytes), reason: d.title);
        for (final f in d.files) {
          expect(f.fileType, LibraryFileType.classify(f.mimeType, f.fileName), reason: f.fileName);
        }
        expect(d.uploader, isNotNull, reason: d.title);
        expect(d.createdAt, isNotNull);
      }
      // The chips are the API's own facets.
      final cats = (await api.dio.get<List<dynamic>>('/documents/categories')).data!.cast<String>();
      expect(c.categories, cats);
      final types = (await api.dio.get<List<dynamic>>('/documents/file-types')).data!.cast<Map<String, dynamic>>();
      expect(c.fileTypes.map((t) => (t.type.api, t.count)), types.map((t) => (t['type'], t['count'])));
      // The seed holds every format the library takes.
      expect(
        c.fileTypes.map((t) => t.type),
        containsAll(LibraryFileType.values.where((t) => t != LibraryFileType.other)),
      );
    },
  );

  liveTest('the filters, the kind searches and every sort are the API\'s', () async {
    final repo = await _repository();
    if (!await _seeded(repo)) return;
    final c = await _library();
    final all = c.total;

    c.setCategory('Fire & Life Safety');
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(c.documents, isNotEmpty);
    expect(c.documents.every((d) => d.category == 'Fire & Life Safety'), isTrue);
    expect(c.total, lessThan(all));
    c.setCategory(null);

    c.setFileType(LibraryFileType.spreadsheet);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(c.documents, isNotEmpty);
    expect(c.documents.every((d) => d.files.any((f) => f.fileType == LibraryFileType.spreadsheet)), isTrue);
    expect(c.total, c.fileTypes.firstWhere((f) => f.type == LibraryFileType.spreadsheet).count);
    c.setFileType(null);

    // Every kind chip finds something in the seeded library: the words are in titles and descriptions.
    for (final k in libraryKinds) {
      c.toggleKind(k);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(c.documents, isNotEmpty, reason: '${k.label} (searching "${k.term}") should match a seeded document');
      c.toggleKind(k);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    c.setSearch('lease');
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(c.documents, isNotEmpty);
    expect(
      c.documents.every(
        (d) => '${d.title} ${d.description} ${d.category} ${d.files.map((f) => f.fileName).join(' ')}'
            .toLowerCase()
            .contains('lease'),
      ),
      isTrue,
    );
    c.setSearch('zzzzqqqq');
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(c.documents, isEmpty);
    c.clearFilters();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(c.total, all);

    c.setSort(LibrarySort.newest);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    for (var i = 1; i < c.documents.length; i++) {
      expect(
        c.documents[i - 1].createdAt!.isAfter(c.documents[i].createdAt!) ||
            c.documents[i - 1].createdAt == c.documents[i].createdAt,
        isTrue,
      );
    }
    c.setSort(LibrarySort.views);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    for (var i = 1; i < c.documents.length; i++) {
      expect(c.documents[i - 1].viewCount >= c.documents[i].viewCount, isTrue);
    }
    c.setSort(LibrarySort.az);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final titles = c.documents.map((d) => d.title.toLowerCase()).toList();
    expect(titles, [...titles]..sort());
    c.setSort(LibrarySort.largest);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    for (var i = 1; i < c.documents.length; i++) {
      expect(c.documents[i - 1].totalSizeBytes >= c.documents[i].totalSizeBytes, isTrue);
    }
  });

  liveTest('Show more pages the library without repeating a document, and My uploads is the member\'s own', () async {
    final repo = await _repository();
    if (!await _seeded(repo)) return;
    final c = await _library(bharat, const LibraryQuery(limit: 10));
    expect(c.documents, hasLength(10));
    expect(c.hasNext, isTrue);
    await c.loadMore();
    expect(c.documents, hasLength(20));
    expect(c.documents.map((d) => d.id).toSet(), hasLength(20));
    await c.loadMore();
    await c.loadMore();
    expect(c.documents.length, c.total);
    expect(c.hasNext, isFalse);

    expect(c.myUploads, greaterThanOrEqualTo(3));
    c.setMine(true);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(c.documents.every((d) => d.uploaderId == c.viewer!.id), isTrue);
    expect(c.total, c.myUploads);
    expect(c.documents.map((d) => d.id), containsAll([_scorecard, _leasePack]));
    // Pooja's are hers.
    final pooja = await _library(
      LivePerson('professional@icr.test', 'Test@12345', 'Pooja Professional'),
      const LibraryQuery(mine: true),
    );
    expect(pooja.documents.map((d) => d.id), containsAll([_visitorPolicy, 'design-doc-ppm-calendar']));
    expect(pooja.documents.every((d) => d.uploaderId == pooja.viewer!.id), isTrue);
    // Signed out, "mine" is nothing.
    final anon = LibraryController(ApiLibraryRepository(api: liveAnonymous()), initial: const LibraryQuery(mine: true));
    await anon.start();
    expect(anon.documents, isEmpty);
    expect(anon.viewer, isNull);
    expect(anon.myUploads, 0);
  });

  liveTest(
    'a document is found by id by reading the library, a pack keeps its files in order, and a missing one is a 404',
    () async {
      final repo = await _repository();
      if (!await _seeded(repo)) return;
      final pack = await _doc(repo, _leasePack);
      expect(pack.isPack, isTrue);
      expect(pack.files.map((f) => f.fileName), [
        'lease-audit-template.xlsx',
        'lease-audit-worked-example.xlsx',
        'lease-audit-method.pdf',
      ]);
      expect(pack.files.map((f) => f.sortOrder), [0, 1, 2]);
      expect(pack.formats, ['XLSX', 'PDF']);
      expect(pack.category, 'Corporate Real Estate');
      expect(pack.subcategory, 'Property Services');
      await expectLater(
        repo.document('no-such-document'),
        throwsA(isA<ApiError>().having((e) => e.statusCode, 'status', 404)),
      );
    },
  );

  liveTest(
    'the viewer reads the real bytes without counting a download (the app never downloads); the first view counts one',
    () async {
      final repo = await _repository();
      if (!await _seeded(repo)) return;
      final before = await _doc(repo, _handover);

      final preview = await repo.previewFile(before, before.files.first);
      expect(utf8.decode(preview.bytes.sublist(0, 5)), '%PDF-');
      expect(preview.fileName, 'fm-handover-checklist.pdf');
      expect(preview.mimeType, 'application/pdf');
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect((await _doc(repo, _handover)).downloadCount, before.downloadCount, reason: 'a preview is not a download');

      final views = await repo.recordView(_handover);
      expect(views, before.viewCount + 1);
      expect((await _doc(repo, _handover)).viewCount, views);
    },
  );

  liveTest(
    'every format of a pack opens with its own bytes: Word, Excel, CSV, text, ZIP, PowerPoint and an image',
    () async {
      final repo = await _repository();
      if (!await _seeded(repo)) return;
      final c = await _library(bharat, const LibraryQuery(limit: 100));
      final seen = <LibraryFileType>{};
      for (final d in c.documents.where((d) => d.id.startsWith('design-doc-'))) {
        for (final f in d.files) {
          if (!seen.add(f.fileType)) continue;
          final read = await repo.previewFile(d, f);
          expect(read.bytes.length, f.sizeBytes, reason: f.fileName);
          final head = read.bytes.sublist(0, 4);
          switch (f.fileType) {
            case LibraryFileType.pdf:
              expect(utf8.decode(head), '%PDF');
            case LibraryFileType.word ||
                LibraryFileType.spreadsheet ||
                LibraryFileType.presentation ||
                LibraryFileType.archive:
              if (f.mimeType != 'text/csv') {
                expect(head.sublist(0, 2), [0x50, 0x4B], reason: '${f.fileName} is a zip container');
              }
            case LibraryFileType.image:
              expect(head.sublist(1, 4), [0x50, 0x4E, 0x47]);
            default:
              break;
          }
          if (f.isImage) expect(f.mimeType, 'image/png');
        }
      }
      expect(seen, containsAll(LibraryFileType.values.where((t) => t != LibraryFileType.other)));
    },
  );

  liveTest('signed out, a preview is the API\'s 401 and the sentence it gives', () async {
    final repo = await _repository();
    if (!await _seeded(repo)) return;
    final doc = await _doc(repo, _assetRegister);
    final anon = ApiLibraryRepository(api: liveAnonymous());
    await expectLater(
      anon.previewFile(doc, doc.files.first),
      throwsA(
        isA<ApiError>().having((e) => e.statusCode, 'status', 401).having((e) => e.message, 'message', isNotEmpty),
      ),
    );
    // The controller turns it into a message, not a lock card (only a 403 is a lock).
    final page = DocumentController(repository: anon, documentId: _assetRegister, initial: doc);
    final out = await page.preview(doc.files.first);
    expect(out.file, isNull);
    expect(out.locked, isFalse);
    expect(page.lockMessage, isNull);
  });

  liveTest(
    'the document page\'s controller: counts a first view once (never a download) and knows who may change it',
    () async {
      final repo = await _repository();
      if (!await _seeded(repo)) return;
      final before = await _doc(repo, _assetRegister);
      final changed = <LibraryDocument>[];
      final page = DocumentController(repository: repo, documentId: _assetRegister, onChanged: changed.add);
      await page.start();
      expect(page.document!.title, before.title);
      expect(page.mayChange, isFalse, reason: 'it is the seeded people\'s, not Bharat\'s');
      expect(page.isMine, isFalse);

      final first = await page.preview(page.document!.files.first);
      expect(first.file, isNotNull);
      await page.preview(page.document!.files.first);
      expect(page.document!.viewCount, before.viewCount + 1, reason: 'one opening, however many reads');
      expect(page.document!.downloadCount, before.downloadCount, reason: 'a preview is never a download');

      final mine = DocumentController(repository: repo, documentId: _scorecard);
      await mine.start();
      expect(mine.isMine, isTrue);
      expect(mine.mayChange, isTrue);
    },
  );

  liveTest(
    'sharing a document: the form uploads the bytes, files the title and the three levels, and the API keeps them',
    () async {
      final repo = await _repository();
      if (!await _seeded(repo)) return;
      final api = await liveClient();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final taxonomy = await repo.taxonomy();
      expect(taxonomy.length, greaterThan(20));
      final fire = taxonomy.firstWhere((n) => n.label == 'Fire & Life Safety');
      expect(fire.children, isNotEmpty);

      final form = UploadController(repository: repo, taxonomy: taxonomy, usedCategories: await repo.categories());
      expect(form.categoryOptions, containsAll(['Fire & Life Safety', 'Board packs', otherOption]));
      form.pick([
        PickedFile(
          name: 'Night rounds $stamp.txt',
          bytes: Uint8List.fromList(utf8.encode('Round 1: lobby, B1, plant room.\nRound 2: roof.\n')),
          mimeType: 'text/plain',
        ),
        PickedFile(
          name: 'Rota $stamp.csv',
          bytes: Uint8List.fromList(utf8.encode('day,guard\nMon,A\nTue,B\n')),
          mimeType: 'text/csv',
        ),
      ]);
      expect(form.title, 'Night rounds $stamp');
      form
        ..setDescription('  Live test document: please ignore.  ')
        ..setCategory('Fire & Life Safety')
        ..setSubcategory(fire.children.first.label);
      expect(form.problems, isEmpty);

      LibraryDocument? doc;
      try {
        doc = await form.submit();
        expect(doc, isNotNull, reason: form.error);
        expect(form.progress, 1);
        expect(doc!.category, 'Fire & Life Safety');
        expect(doc.subcategory, fire.children.first.label);
        expect(doc.description, 'Live test document: please ignore.');
        expect(doc.files.map((f) => f.fileName), ['Night rounds $stamp.txt', 'Rota $stamp.csv']);
        expect(doc.files.map((f) => f.fileType), [LibraryFileType.text, LibraryFileType.spreadsheet]);
        expect(doc.uploaderId, (await repo.viewer())!.id);

        // Read back through the API: it is in My uploads, with its files, and the bytes are what went up.
        final mine = await _rows(api, '/documents', {'mine': 'true'});
        expect(mine.map((r) => r['id']), contains(doc.id));
        final back = await repo.document(doc.id);
        expect(back.fileCount, 2);
        final read = await repo.previewFile(back, back.files.first);
        expect(utf8.decode(read.bytes), startsWith('Round 1: lobby'));

        // Add a file to it (append mode), then drop it again.
        final more = UploadController(repository: repo, target: back);
        more.pick([
          PickedFile(name: 'Extra $stamp.txt', bytes: Uint8List.fromList(utf8.encode('extra')), mimeType: 'text/plain'),
        ]);
        final grown = await more.submit();
        expect(grown, isNotNull, reason: more.error);
        expect(grown!.fileCount, 3);
        await repo.removeFile(doc.id, grown.files.last.id);
        expect((await repo.document(doc.id)).fileCount, 2);
        // The API refuses to leave a document with no file: drop one, then the last one is refused with its own words.
        final page = DocumentController(repository: repo, documentId: doc.id, initial: await repo.document(doc.id));
        await page.start();
        expect(page.mayChange, isTrue);
        expect(await page.removeFile(page.document!.files.last), isNull);
        expect(page.document!.fileCount, 1);
        expect(
          await page.removeFile(page.document!.files.single),
          'That is the only file on this document. Remove the document instead.',
        );
        expect(page.document!.fileCount, 1);
      } finally {
        if (doc != null) await repo.delete(doc.id);
      }
      final gone = await _rows(api, '/documents', {'mine': 'true'});
      expect(gone.map((r) => r['id']), isNot(contains(doc.id)));
      await expectLater(repo.document(doc.id), throwsA(isA<ApiError>().having((e) => e.statusCode, 'status', 404)));
    },
  );

  liveTest(
    'the API refuses a format the library does not take, and a document with no category typed is the form\'s problem, not the API\'s',
    () async {
      final repo = await _repository();
      if (!await _seeded(repo)) return;
      await expectLater(
        repo.upload(
          PickedFile(name: 'tool.exe', bytes: Uint8List.fromList([1, 2, 3]), mimeType: 'application/x-msdownload'),
        ),
        throwsA(
          isA<ApiError>()
              .having((e) => e.statusCode, 'status', 400)
              .having((e) => e.message, 'message', contains('not an accepted file type')),
        ),
      );
      final form = UploadController(repository: repo);
      form.pick([PickedFile(name: 'notes.exe', bytes: Uint8List(10))]);
      expect(form.entries, isEmpty, reason: 'the form refuses it before the API is asked');
      expect(form.error, 'Not added: notes.exe is not a format the library takes.');
    },
  );

  liveTest(
    'a report: the member sends a reason and a note, the admin queue holds it, a second one is a 409; closing it leaves the document',
    () async {
      final repo = await _repository(LivePerson('professional@icr.test', 'Test@12345', 'Pooja Professional'));
      if (!await _seeded(repo)) return;
      final admin = await liveClient(_admin);
      final target = await _doc(repo, _scorecard);
      final marker = 'live-test-${DateTime.now().millisecondsSinceEpoch}';

      final page = DocumentController(repository: repo, documentId: _scorecard, initial: target);
      await page.start();
      expect(page.isMine, isFalse);
      Map<String, dynamic>? row;
      try {
        expect(await page.report(DocumentReportReason.brokenFile, note: marker), isNull);
        expect(page.reported, isTrue);

        final queue = await _rows(admin, '/documents/admin/reports', {'status': 'PENDING'});
        row = queue.firstWhere((r) => r['note'] == marker, orElse: () => <String, dynamic>{});
        expect(row, isNotEmpty, reason: 'the report is in the admin queue');
        expect(row['reason'], 'BROKEN_FILE');
        expect((row['document'] as Map)['title'], target.title);
        expect((row['reporter'] as Map)['firstName'], 'Pooja');

        // The same member again, while the first is open: the API's 409, which the page reads as "Reported".
        final again = DocumentController(repository: repo, documentId: _scorecard, initial: target);
        await again.start();
        expect(
          await again.report(DocumentReportReason.spam),
          'You have already reported this document. An admin is reviewing it.',
        );
        expect(again.reported, isTrue);
      } finally {
        if (row != null && row.isNotEmpty) {
          await admin.dio.patch<dynamic>('/documents/admin/reports/${row['id']}', data: {'status': 'APPROVED'});
        }
      }
      final stands = await _doc(repo, _scorecard);
      expect(stands.title, target.title, reason: 'APPROVED means the document stands');
      final queue = await _rows(admin, '/documents/admin/reports', {'status': 'PENDING'});
      expect(queue.where((r) => r['note'] == marker), isEmpty);
    },
  );

  liveTest(
    'a member cannot report their own document, change anyone else\'s, or add to it: each is the API\'s own sentence',
    () async {
      final bharatRepo = await _repository();
      if (!await _seeded(bharatRepo)) return;
      final own = DocumentController(repository: bharatRepo, documentId: _scorecard);
      await own.start();
      expect(await own.report(DocumentReportReason.spam), 'Delete your own document rather than reporting it.');

      final pooja = await _repository(LivePerson('professional@icr.test', 'Test@12345', 'Pooja Professional'));
      await expectLater(
        pooja.delete(_scorecard),
        throwsA(
          isA<ApiError>()
              .having((e) => e.statusCode, 'status', 403)
              .having((e) => e.message, 'message', 'You can only change a document you uploaded.'),
        ),
      );
      await expectLater(
        pooja.addFiles(_scorecard, const [
          StoredFile(url: '/uploads/none.pdf', name: 'none.pdf', size: 1, mimeType: 'application/pdf'),
        ]),
        throwsA(isA<ApiError>().having((e) => e.statusCode, 'status', 403)),
      );
      await expectLater(
        pooja.removeFile(_leasePack, 'whatever'),
        throwsA(isA<ApiError>().having((e) => e.statusCode, 'status', 403)),
      );
      final stillThere = await _doc(bharatRepo, _scorecard);
      expect(stillThere.fileCount, 1);
    },
  );

  liveTest('a SUPER_ADMIN may change any document: the form of an admin shows Delete on someone else\'s', () async {
    final admin = await _repository(_admin);
    if (!await _seeded(admin)) return;
    final page = DocumentController(repository: admin, documentId: _visitorPolicy);
    await page.start();
    expect(page.viewer!.isAdmin, isTrue);
    expect(page.isMine, isFalse);
    expect(page.mayChange, isTrue);
  });

  liveTest('the bell is the member\'s unread count and the library\'s link is the website\'s', () async {
    final repo = await _repository();
    final api = await liveClient();
    final raw = await api.dio.get<Map<String, dynamic>>('/notifications/unread-count');
    expect(await repo.unreadNotifications(), (raw.data!['unread'] as num).toInt());
    expect(repo.link().path, '/documents');
  });
}
