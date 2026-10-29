/// Role matrix, part 7: the Digital Library and Get Involved & Volunteer for the four accounts that belong to no
/// company. A document goes round a ring (one account shares it, the next one reads, downloads and reports it, the
/// author deletes it; staff close the report). The file a document is made of cannot be removed from the server's
/// uploads folder, so each document is one tiny PDF. An application to volunteer is taken out of the ICR inbox by staff.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/features/library/api_library_repository.dart';
import 'package:icr_mobile/features/library/library_controller.dart';
import 'package:icr_mobile/features/library/library_models.dart';
import 'package:icr_mobile/features/library/library_screen.dart';
import 'package:icr_mobile/features/volunteer/api_volunteer_repository.dart';
import 'package:icr_mobile/features/volunteer/get_involved_screen.dart';
import 'package:icr_mobile/features/volunteer/volunteer_controller.dart';
import 'package:icr_mobile/features/volunteer/volunteer_data.dart';
import 'package:icr_mobile/features/volunteer/volunteer_models.dart';
import 'package:provider/provider.dart';

import '../helpers/fonts.dart';
import 'career_live_support.dart';
import 'live.dart';
import 'role_buyer_support.dart';

final _libraries = <String, ApiLibraryRepository>{};
ApiLibraryRepository libraryOf(Who w) => _libraries.putIfAbsent(w.email, () => ApiLibraryRepository(api: w.api));

final _volunteers = <String, ApiVolunteerRepository>{};
ApiVolunteerRepository volunteerOf(Who w) => _volunteers.putIfAbsent(w.email, () => ApiVolunteerRepository(api: w.api));

/// A tiny but real PDF.
Uint8List _pdf(String title) => Uint8List.fromList(
  utf8.encode('%PDF-1.4\n1 0 obj << /Type /Catalog /Title ($title) >> endobj\ntrailer << /Root 1 0 R >>\n%%EOF\n'),
);

void roleBuyerLibrary() {
  setUpAll(loadAppFonts);

  group('Library', () {
    liveTest('browse, search, categories, formats and My uploads read for every account', () async {
      for (final w in await everyone()) {
        final repo = libraryOf(w);
        final page = await repo.documents(const LibraryQuery());
        expect(page.documents, isNotEmpty, reason: '${w.email}: the library has documents');
        expect(page.total, greaterThan(0));
        final first = page.documents.first;
        final hit = await repo.documents(LibraryQuery(search: first.title.split(' ').first));
        expect(hit.documents, isNotEmpty);
        for (final sort in LibrarySort.values) {
          expect((await repo.documents(LibraryQuery(sort: sort))).documents, isNotEmpty, reason: '$sort');
        }
        final categories = await repo.categories();
        expect(categories, isNotEmpty);
        expect((await repo.documents(LibraryQuery(category: categories.first))).documents, isNotEmpty);
        final types = await repo.fileTypes();
        expect(types, isNotEmpty);
        await repo.documents(LibraryQuery(fileType: types.first.type));
        await repo.documents(const LibraryQuery(mine: true));
        expect(await repo.myUploadCount(), greaterThanOrEqualTo(0));
        await repo.viewer();
        await repo.taxonomy();
        final doc = await repo.document(first.id);
        expect(doc.id, first.id);
        record('Library: browse, search, sorts, categories, formats, My uploads', w.person, 'works');
      }
    });

    liveTest(
      'a document is shared, read, downloaded, reported and deleted: each account shares one, the next uses it',
      () async {
        final people = await everyone();
        for (var i = 0; i < people.length; i++) {
          final author = people[i];
          final reader = people[(i + 1) % people.length];
          final a = libraryOf(author);
          final b = libraryOf(reader);
          final stamp = DateTime.now().millisecondsSinceEpoch;
          final title = 'Role matrix note ${author.first} $stamp';
          final marker = 'role-matrix-$stamp';
          final stored = await a.upload(
            PickedFile(name: 'role-matrix-$stamp.pdf', bytes: _pdf(title), mimeType: 'application/pdf'),
          );
          final category = (await a.categories()).first;
          LibraryDocument? doc;
          try {
            doc = await a.create(
              DocumentDraft(
                title: title,
                description: 'Made by the role matrix; deleted straight after.',
                category: category,
              ),
              [stored],
            );
            expect((await a.documents(const LibraryQuery(mine: true))).documents.map((d) => d.id), contains(doc.id));
            record(
              'Library: upload a document',
              author.person,
              'works',
              'one tiny PDF (the uploads folder keeps the bytes)',
            );

            // The next account finds it, previews it (a view; the app never downloads) and reports it.
            final found = await b.documents(LibraryQuery(search: title));
            expect(found.documents.map((d) => d.id), contains(doc.id), reason: '${reader.email} finds it');
            final seen = found.documents.firstWhere((d) => d.id == doc!.id);
            final file = seen.files.first;
            final preview = await b.previewFile(seen, file);
            expect(preview.bytes, isNotEmpty);
            expect(String.fromCharCodes(preview.bytes.take(5)), '%PDF-');
            final views = await b.recordView(doc.id);
            expect(views, greaterThan(0));
            await b.report(doc.id, DocumentReportReason.other, note: marker);
            record('Library: preview, report', reader.person, 'works', 'two-person with ${author.first}');
          } finally {
            final d = doc;
            if (d != null) {
              await _closeReports(marker);
              await a.delete(d.id);
            }
          }
          expect(
            (await a.documents(LibraryQuery(search: title))).documents,
            isEmpty,
            reason: 'the document is deleted',
          );
        }
      },
      timeout: const Timeout(Duration(minutes: 4)),
    );
  });

  group('Get Involved & Volunteer', () {
    liveTest(
      'the CPD ledger, the form sender and the chapters read for every account; one application goes through',
      () async {
        final people = await everyone();
        for (final w in people) {
          final repo = volunteerOf(w);
          final cpd = await repo.cpd();
          expect(cpd, isNotNull, reason: '${w.email}: a ledger, even an empty one');
          final sender = await repo.sender();
          expect(sender?.email, w.email);
          expect(await repo.chapters(), isNotEmpty);
          expect(await repo.unreadNotifications(), greaterThanOrEqualTo(0));
          record('Volunteer: CPD ledger, form sender, chapters', w.person, 'works');
        }
        // One application, from the account with the thinnest profile; staff take it out of the inbox.
        final w = people.last;
        final stamp = DateTime.now().millisecondsSinceEpoch;
        final marker = 'role-matrix-$stamp';
        final sender = (await volunteerOf(w).sender())!;
        try {
          await volunteerOf(w).apply(
            VolunteerApplication(
              name: sender.name,
              email: sender.email,
              message: 'Role matrix, please ignore: $marker',
              role: volunteerRoles.firstWhere((r) => r.key == 'speaker'),
              chapter: 'ICR Bengaluru Chapter',
            ),
          );
          record(
            'Volunteer: apply (Apply, form, sent)',
            w.person,
            'works',
            'a contact message and lead, put away by staff',
          );
        } finally {
          await putAwayContact(marker, topic: 'VOLUNTEER');
        }
      },
    );
  });

  group('the Library and Get Involved screens, drawn for every account', () {
    testWidgets('the library list and Get Involved draw for every account', tags: const ['live'], (tester) async {
      if (!await liveScreenReady(tester)) return;
      for (final w in (await tester.runAsync(everyone))!) {
        final library = LibraryController(libraryOf(w));
        await loadScreen(
          tester,
          LibraryScreen(onBack: () {}),
          providers: [ChangeNotifierProvider<LibraryController>.value(value: library)],
          size: const Size(390, 2200),
        );
        await waitFor(tester, find.textContaining('Documents'));
        var text = expectHealthy(tester, 'the Library as ${w.email}');
        expect(text, contains('Your uploads'));
        expect(text, contains('Browse by kind'));
        await unmount(tester);

        final volunteer = VolunteerController(volunteerOf(w));
        await loadScreen(
          tester,
          GetInvolvedScreen(onBack: () {}),
          providers: [ChangeNotifierProvider<VolunteerController>.value(value: volunteer)],
          appProviders: [Provider<ApiClient>.value(value: w.api)],
          size: const Size(390, 2600),
        );
        text = expectHealthy(tester, 'Get Involved as ${w.email}');
        expect(text, contains('Volunteer Opportunities'));
        expect(text, contains('Your CPD'));
        await unmount(tester);
        record('Library and Get Involved: screens', w.person, 'works');
      }
    });
  });
}

/// Staff close any report whose note is [marker] (approved: the document stands).
Future<void> _closeReports(String marker) async {
  final staff = sana;
  if (staff == null) return;
  final admin = await liveClient(staff);
  try {
    final res = await admin.dio.get<Map<String, dynamic>>(
      '/documents/admin/reports',
      queryParameters: {'status': 'PENDING', 'limit': 50},
    );
    for (final row in (res.data!['data'] as List).cast<Map<String, dynamic>>()) {
      if (row['note'] == marker) {
        await admin.dio.patch<dynamic>('/documents/admin/reports/${row['id']}', data: {'status': 'APPROVED'});
      }
    }
  } catch (_) {
    // A queue that cannot be read is left for staff.
  }
}
