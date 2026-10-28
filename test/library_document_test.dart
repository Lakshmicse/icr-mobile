import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/config.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/library/demo_library_repository.dart';
import 'package:icr_mobile/features/library/document_controller.dart';
import 'package:icr_mobile/features/library/document_screen.dart';
import 'package:icr_mobile/features/library/library_handoffs.dart';
import 'package:icr_mobile/features/library/library_models.dart';
import 'package:icr_mobile/features/library/upload_controller.dart';
import 'package:icr_mobile/features/library/upload_document_screen.dart';
import 'package:icr_mobile/features/library/widgets/image_preview_screen.dart';
import 'package:icr_mobile/features/library/widgets/report_sheet.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import 'helpers/community_fakes.dart';
import 'helpers/fonts.dart';

void _view(WidgetTester tester, {double height = 3000}) {
  tester.view.physicalSize = Size(780, height * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

class _Doc {
  _Doc(this.repo, this.id, {this.initial});

  final FakeLibrary repo;
  final String id;
  final LibraryDocument? initial;
  final device = FakeLibraryDevice();
  int backs = 0;
  int bells = 0;
  int plans = 0;
  final members = <String>[];
  final shared = <(String, Uri)>[];
  final changed = <LibraryDocument>[];
  final removed = <String>[];
}

/// A document's page: [id] of the sample library, opened with the document in hand unless [read] is set.
Future<_Doc> _pumpDoc(
  WidgetTester tester,
  String id, {
  FakeLibrary? repo,
  bool read = false,
  bool members = true,
  bool plans = true,
  bool ownBell = false,
  double height = 3000,
}) async {
  _view(tester, height: height);
  final fake = repo ?? FakeLibrary();
  final initial = read ? null : await fake.inner.document(id);
  final page = _Doc(fake, id, initial: initial);
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: ChangeNotifierProvider(
        create: (_) => DocumentController(
          repository: fake,
          documentId: id,
          initial: initial,
          onChanged: page.changed.add,
          onRemoved: page.removed.add,
        ),
        child: DocumentScreen(
          repository: fake,
          onBack: () => page.backs++,
          handoffs: LibraryHandoffs(
            onBell: ownBell ? () => page.bells++ : null,
            onOpenMember: members ? page.members.add : null,
            onOpenPlans: plans ? () => page.plans++ : null,
            device: page.device,
            share: (title, link) async => page.shared.add((title, link)),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return page;
}

/// The member's own document (d9, an image) and somebody else's (d1, a PDF) in the sample library.
const _mine = 'd9';
const _theirs = 'd1';

DocumentController _controller(WidgetTester tester) =>
    tester.element(find.byType(DocumentScreen)).read<DocumentController>();

void main() {
  setUpAll(loadAppFonts);

  group('a document’s page', () {
    testWidgets('draws who shared it, the numbers, the description and each file', (tester) async {
      await _pumpDoc(tester, _theirs);
      expect(find.text('Document'), findsOneWidget);
      expect(find.text('FM Handover Checklist: New Building Takeover'), findsOneWidget);
      expect(find.text('Integrated Facility Management › Handover & Commissioning'), findsOneWidget);
      expect(find.text('Shared by Priya Nambiar'), findsOneWidget);
      expect(find.textContaining('Sustainability Lead · '), findsOneWidget);
      for (final label in ['Views', 'Downloads', 'Size', 'Files']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('1,290'), findsOneWidget);
      expect(find.text('482'), findsOneWidget);
      expect(find.text('About this document'), findsOneWidget);
      expect(find.textContaining('60-point checklist'), findsOneWidget);
      expect(find.text('fm-handover-checklist.pdf'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Download'), findsOneWidget);
      // Somebody else's document: report it, never delete or add to it.
      expect(find.text('Report'), findsOneWidget);
      expect(find.text('Delete'), findsNothing);
      expect(find.text('Add files'), findsNothing);
      expect(find.text('YOU'), findsNothing);
    });

    testWidgets('a pack lists every file with its own size and count, and says "Files"', (tester) async {
      await _pumpDoc(tester, 'd5');
      expect(find.text('lease-audit-template.xlsx'), findsOneWidget);
      expect(find.text('lease-audit-worked-example.xlsx'), findsOneWidget);
      expect(find.text('lease-audit-method.pdf'), findsOneWidget);
      expect(find.text('Open'), findsNWidgets(3));
      expect(find.text('Files'), findsWidgets);
    });

    testWidgets('opened by id alone it reads the library for the document; an unknown id says so with Try again', (
      tester,
    ) async {
      final repo = FakeLibrary();
      await _pumpDoc(tester, _theirs, repo: repo, read: true);
      expect(repo.calls, contains('document:d1'));
      expect(find.text('FM Handover Checklist: New Building Takeover'), findsOneWidget);

      final missing = FakeLibrary();
      await _pumpDoc(tester, 'gone', repo: missing, read: true);
      expect(find.text("Couldn't load this document"), findsOneWidget);
      expect(find.text('That document is no longer in the library.'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(missing.count('document'), 2);
    });

    testWidgets('Back, and the bell (the shell’s or the website’s)', (tester) async {
      final page = await _pumpDoc(tester, _theirs);
      await tester.tap(find.byIcon(Symbols.arrow_back));
      expect(page.backs, 1);
      await tester.tap(find.byIcon(LucideIcons.bell));
      expect(page.device.opened.last, AppConfig.sitePage('/notifications'));
      final own = await _pumpDoc(tester, _theirs, ownBell: true);
      await tester.tap(find.byIcon(LucideIcons.bell));
      expect(own.bells, 1);
    });

    testWidgets('the uploader’s row opens their profile through the shell, and is not tappable without it', (
      tester,
    ) async {
      final page = await _pumpDoc(tester, _theirs);
      await tester.tap(find.text('Shared by Priya Nambiar'));
      expect(page.members, ['demo-priya']);
      await _pumpDoc(tester, _theirs, members: false);
      expect(find.byIcon(LucideIcons.chevronRight), findsNothing);
    });

    testWidgets('Share hands the title and the library’s link to the share sheet', (tester) async {
      final page = await _pumpDoc(tester, _theirs);
      await tester.tap(find.text('Share'));
      expect(page.shared.single.$1, 'FM Handover Checklist: New Building Takeover');
      expect(page.shared.single.$2, Uri.parse('https://icr.test/documents'));
    });

    testWidgets('pulling down reads the document again', (tester) async {
      final repo = FakeLibrary();
      await _pumpDoc(tester, _theirs, repo: repo, height: 800);
      expect(repo.count('document'), 1);
      await tester.fling(find.byType(ListView).first, const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(repo.count('document'), 2);
    });
  });

  group('reading and downloading', () {
    testWidgets('Open reads the file for the viewer (not a download), counts one opening, and hands it to the phone', (
      tester,
    ) async {
      final page = await _pumpDoc(tester, _theirs);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(page.repo.calls, contains('preview:d1-f0'));
      expect(page.repo.calls, contains('view:d1'));
      expect(page.device.handed.single.fileName, 'fm-handover-checklist.pdf');
      expect(page.device.handed.single.mimeType, 'application/pdf');
      // A preview is not a download: the card says 482 still, and one more opening.
      expect(find.text('482'), findsOneWidget);
      expect(find.text('1,291'), findsOneWidget);
      expect(page.changed.last.viewCount, 1291);

      // The same page counts one opening however many files are read.
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(page.repo.calls.where((c) => c == 'view:d1'), hasLength(1));
      expect(page.device.handed, hasLength(2));
    });

    testWidgets(
      'Download takes a copy through the API, counts it on the page and the list, and hands it to the phone',
      (tester) async {
        final page = await _pumpDoc(tester, _theirs);
        await tester.tap(find.text('Download'));
        await tester.pumpAndSettle();
        expect(page.repo.calls, contains('download:d1-f0'));
        expect(page.repo.calls.where((c) => c.startsWith('view:')), isEmpty);
        expect(page.device.handed.single.fileName, 'fm-handover-checklist.pdf');
        expect(find.text('483'), findsOneWidget);
        expect(find.textContaining('483 downloads'), findsOneWidget);
        expect(page.changed.last.downloadCount, 483);
        expect(page.changed.last.files.single.downloadCount, 483);
      },
    );

    testWidgets('an image opens in the app (Preview), and its Download glyph takes a copy', (tester) async {
      final page = await _pumpDoc(tester, _mine);
      expect(find.text('Preview'), findsOneWidget);
      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();
      expect(find.byType(ImagePreviewScreen), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(page.device.handed, isEmpty);
      expect(page.repo.calls, contains('preview:d9-f0'));

      await tester.tap(find.byTooltip('Download'));
      await tester.pumpAndSettle();
      expect(find.byType(ImagePreviewScreen), findsNothing);
      expect(page.repo.calls, contains('download:d9-f0'));
      expect(page.device.handed.single.fileName, 'plant-room-walkdown.png');
    });

    testWidgets('a phone with nothing to open the file says so', (tester) async {
      final page = await _pumpDoc(tester, _theirs);
      page.device.canHandOver = false;
      await tester.tap(find.text('Download'));
      await tester.pumpAndSettle();
      expect(find.text("Couldn't open fm-handover-checklist.pdf on this phone."), findsOneWidget);
    });

    testWidgets('a plan that does not open it: the server’s own sentence in a lock card, and See plans', (
      tester,
    ) async {
      final repo = FakeLibrary()
        ..failures['download'] = ApiError(
          'Your plan opens Limited documents. Upgrade to open this one.',
          statusCode: 403,
        );
      final page = await _pumpDoc(tester, _theirs, repo: repo);
      await tester.tap(find.text('Download'));
      await tester.pumpAndSettle();
      expect(find.text('Not included in your plan'), findsOneWidget);
      expect(find.text('Your plan opens Limited documents. Upgrade to open this one.'), findsOneWidget);
      expect(page.device.handed, isEmpty);
      await tester.tap(find.text('See plans'));
      expect(page.plans, 1);

      // The preview is refused the same way, and the card goes when a read works.
      repo.failures.clear();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Not included in your plan'), findsNothing);
      expect(page.device.handed, hasLength(1));
    });

    testWidgets('the lock card has no button without a shell callback; a sign-in wall is a message, not a lock', (
      tester,
    ) async {
      final repo = FakeLibrary()..failures['preview'] = ApiError('Not allowed.', statusCode: 403);
      await _pumpDoc(tester, _theirs, repo: repo, plans: false);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Not allowed.'), findsOneWidget);
      expect(find.text('See plans'), findsNothing);

      final signedOut = FakeLibrary()..failures['download'] = ApiError('Unauthorized', statusCode: 401);
      await _pumpDoc(tester, _theirs, repo: signedOut);
      await tester.tap(find.text('Download'));
      await tester.pumpAndSettle();
      expect(find.text('Unauthorized'), findsOneWidget);
      expect(find.text('Not included in your plan'), findsNothing);
    });

    testWidgets('a read that fails shows the API’s sentence and does not count an opening', (tester) async {
      final repo = FakeLibrary()..failures['preview'] = ApiError('The stored file is missing.', statusCode: 404);
      final page = await _pumpDoc(tester, _theirs, repo: repo);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('The stored file is missing.'), findsOneWidget);
      expect(page.repo.calls.where((c) => c.startsWith('view:')), isEmpty);
    });
  });

  group('reporting', () {
    testWidgets('a document of my own has no Report', (tester) async {
      await _pumpDoc(tester, _mine);
      expect(find.text('Report'), findsNothing);
      expect(find.text('YOU'), findsOneWidget);
    });

    testWidgets('the sheet lists the six reasons, asks for a note on "Something else", and sends the reason and note', (
      tester,
    ) async {
      final page = await _pumpDoc(tester, _theirs);
      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();
      expect(find.text('Report this document'), findsOneWidget);
      for (final r in DocumentReportReason.values) {
        expect(find.text(r.label), findsOneWidget);
      }
      // Nothing to send until a reason is chosen.
      expect(
        tester.widget<ReportSheet>(find.byType(ReportSheet)).title,
        'FM Handover Checklist: New Building Takeover',
      );
      await tester.tap(find.text('Send report'));
      await tester.pumpAndSettle();
      expect(page.repo.count('report'), 0);

      await tester.tap(find.text('Something else'));
      await tester.pumpAndSettle();
      expect(find.text('What is wrong? (required)'), findsOneWidget);
      await tester.tap(find.text('Send report'));
      await tester.pumpAndSettle();
      expect(page.repo.count('report'), 0, reason: 'a note is required for Something else');

      await tester.enterText(find.byType(TextField).last, 'Page 3 is the wrong lease');
      await tester.pump();
      await tester.tap(find.text('Send report'));
      await tester.pumpAndSettle();
      expect(page.repo.inner.calls, contains('report:d1:OTHER:Page 3 is the wrong lease'));
      expect(find.text('Report sent'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Report sent'), findsNothing);
      // The page remembers: Reported, and nothing more to send.
      expect(find.text('Reported'), findsOneWidget);
      expect(find.text('Report'), findsNothing);
    });

    testWidgets('a reason alone is enough for the other five, and the note is optional', (tester) async {
      final page = await _pumpDoc(tester, _theirs);
      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('File is broken or will not open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send report'));
      await tester.pumpAndSettle();
      expect(page.repo.inner.calls, contains('report:d1:BROKEN_FILE:'));
    });

    testWidgets('a second report while the first is open is the API’s 409, shown in the sheet with the note kept', (
      tester,
    ) async {
      final repo = FakeLibrary()
        ..failures['report'] = ApiError(
          'You have already reported this document. An admin is reviewing it.',
          statusCode: 409,
        );
      await _pumpDoc(tester, _theirs, repo: repo);
      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Spam or advertising'));
      await tester.enterText(find.byType(TextField).last, 'sells something');
      await tester.pump();
      await tester.tap(find.text('Send report'));
      await tester.pumpAndSettle();
      expect(find.text('You have already reported this document. An admin is reviewing it.'), findsOneWidget);
      expect(find.text('Report sent'), findsNothing);
      expect(find.text('sells something'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      // The API says it is under review, so the page reads Reported.
      expect(find.text('Reported'), findsOneWidget);
    });

    testWidgets('any other refusal is shown and the person may try again', (tester) async {
      final repo = FakeLibrary()
        ..failures['report'] = ApiError('That document is no longer in the library.', statusCode: 404);
      await _pumpDoc(tester, _theirs, repo: repo);
      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Misleading or out of date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send report'));
      await tester.pumpAndSettle();
      expect(find.text('That document is no longer in the library.'), findsOneWidget);
      repo.failures.clear();
      await tester.tap(find.text('Send report'));
      await tester.pumpAndSettle();
      expect(find.text('Report sent'), findsOneWidget);
    });
  });

  group('the member’s own documents', () {
    testWidgets('Delete asks first; Cancel keeps it; Delete takes it out, tells the list and goes back', (
      tester,
    ) async {
      final page = await _pumpDoc(tester, _mine);
      expect(find.text('Delete'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete “Chiller Plant Room Walk-down”?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(page.repo.count('delete'), 0);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Delete')));
      await tester.pumpAndSettle();
      expect(page.repo.calls, contains('delete:d9'));
      expect(page.removed, ['d9']);
      expect(page.backs, 1);
      expect(find.text('“Chiller Plant Room Walk-down” was deleted.'), findsOneWidget);
    });

    testWidgets('a refused delete says why and the page stays', (tester) async {
      final repo = FakeLibrary()
        ..failures['delete'] = ApiError('You can only change a document you uploaded.', statusCode: 403);
      final page = await _pumpDoc(tester, _mine, repo: repo);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Delete')));
      await tester.pumpAndSettle();
      expect(find.text('You can only change a document you uploaded.'), findsOneWidget);
      expect(page.backs, 0);
      expect(page.removed, isEmpty);
    });

    testWidgets('a SUPER_ADMIN may delete, add to and trim anyone’s document', (tester) async {
      final repo = FakeLibrary(viewer: const LibraryViewer(id: 'admin', isAdmin: true));
      await _pumpDoc(tester, 'd5', repo: repo);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Add files'), findsOneWidget);
      expect(find.byTooltip('Remove lease-audit-method.pdf'), findsOneWidget);
      expect(find.text('Report'), findsOneWidget, reason: 'an admin did not share it, so it can be reported');
    });

    testWidgets('a signed-out reader may report, never change', (tester) async {
      final repo = FakeLibrary(viewer: null);
      await _pumpDoc(tester, _theirs, repo: repo);
      expect(find.text('Delete'), findsNothing);
      expect(find.text('Add files'), findsNothing);
      expect(find.text('Report'), findsOneWidget);
    });

    testWidgets('a file of a pack can be dropped, after asking; the last file cannot (the API’s sentence)', (
      tester,
    ) async {
      final repo = FakeLibrary();
      final page = await _pumpDoc(tester, 'd5', repo: repo);
      expect(find.text('Open'), findsNWidgets(3));
      await tester.tap(find.byTooltip('Remove lease-audit-method.pdf'));
      await tester.pumpAndSettle();
      expect(find.text('Remove lease-audit-method.pdf?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repo.count('removeFile'), 0);
      await tester.tap(find.byTooltip('Remove lease-audit-method.pdf'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Remove')));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('removeFile:d5-f2'));
      expect(find.text('lease-audit-method.pdf'), findsNothing);
      expect(find.text('Open'), findsNWidgets(2));
      expect(page.changed.last.fileCount, 2);

      await tester.tap(find.byTooltip('Remove lease-audit-worked-example.xlsx'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Remove')));
      await tester.pumpAndSettle();
      // One file left: no remove glyph is drawn for it.
      expect(find.byTooltip('Remove lease-audit-template.xlsx'), findsNothing);
      expect(find.text('Open'), findsOneWidget);

      repo.failures['removeFile'] = ApiError(
        'That is the only file on this document. Remove the document instead.',
        statusCode: 400,
      );
      final c = _controller(tester);
      expect(
        await c.removeFile(c.document!.files.single),
        'That is the only file on this document. Remove the document instead.',
      );
    });

    testWidgets('Add files opens the upload form for this document, and the page shows the file it added', (
      tester,
    ) async {
      final page = await _pumpDoc(tester, _mine);
      page.device.picks.add([pickedFile('Plant room extra.pdf', size: 4096)]);
      // The page's own device is not the form's: the form is opened with the page's handoffs.
      await tester.tap(find.text('Add files'));
      await tester.pumpAndSettle();
      expect(find.byType(UploadDocumentScreen), findsOneWidget);
      expect(find.text('Add files'), findsWidgets);
      expect(find.text('They join “Chiller Plant Room Walk-down”'), findsOneWidget);
      // Append mode asks for no title and no category.
      expect(find.text('Title *'), findsNothing);
      await tester.tap(find.text('Choose files'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add to “Chiller Plant Room Walk-down”'));
      await tester.pumpAndSettle();
      expect(find.byType(UploadDocumentScreen), findsNothing);
      expect(page.repo.calls, containsAll(['upload:Plant room extra.pdf', 'addFiles:d9']));
      expect(find.text('Plant room extra.pdf'), findsOneWidget);
      expect(find.text('plant-room-walkdown.png'), findsOneWidget);
      expect(page.changed.last.fileCount, 2);
    });
  });

  group('the upload form’s rules', () {
    UploadController form({LibraryDocument? target, FakeLibrary? repo}) => UploadController(
      repository: repo ?? FakeLibrary(),
      target: target,
      taxonomy: const [
        TaxonomyNode(
          label: 'Fire & Life Safety',
          children: [
            TaxonomyNode(
              label: 'Fire Detection',
              children: [TaxonomyNode(label: 'Addressable Panels')],
            ),
            TaxonomyNode(label: 'Sprinklers'),
          ],
        ),
        TaxonomyNode(label: 'Technology'),
      ],
      usedCategories: const ['Technology', 'Board packs'],
    );

    test('the category choices are the platform’s, then what the library uses that it does not cover, then Other', () {
      final c = form();
      expect(c.categoryOptions, ['Fire & Life Safety', 'Technology', 'Board packs', otherOption]);
      c.setCategory('Fire & Life Safety');
      expect(c.subcategoryOptions, ['Fire Detection', 'Sprinklers', otherOption]);
      c.setSubcategory('Fire Detection');
      expect(c.specializationOptions, ['Addressable Panels', otherOption]);
      c.setSubcategory('Sprinklers');
      expect(c.specializationOptions, isEmpty);
      c.setCategory('Technology');
      expect(c.subcategoryOptions, isEmpty, reason: 'a category with no children is a typed field');
    });

    test(
      'a level is only sent under the one above, "Other" means what was typed, and choosing again clears the levels below',
      () {
        final c = form();
        c.setSubcategoryOther('orphan');
        expect(c.resolvedSubcategory, isEmpty);
        c.setCategory('Fire & Life Safety');
        expect(c.resolvedCategory, 'Fire & Life Safety');
        c.setSubcategory('Fire Detection');
        c.setSpecialization('Addressable Panels');
        expect(c.resolvedSpecialization, 'Addressable Panels');
        c.setSubcategory(otherOption);
        c.setSubcategoryOther('  Gas suppression ');
        expect(c.resolvedSubcategory, 'Gas suppression');
        expect(c.resolvedSpecialization, isEmpty, reason: 'the specialisation described the old sub-category');
        c.setCategory(otherOption);
        c.setCategoryOther(' Board packs ');
        expect(c.resolvedCategory, 'Board packs');
        expect(c.resolvedSubcategory, isEmpty);
        c.setSubcategoryOther('Quarterly');
        expect(
          c.resolvedSubcategory,
          'Quarterly',
          reason: 'under the uploader’s own category the sub-category is typed',
        );
        c.setSpecializationOther('Q3');
        expect(c.resolvedSpecialization, 'Q3');
      },
    );

    test(
      'files are taken minus what cannot go: a format the library does not take, over 10 MB, a twin, over the limit',
      () {
        final c = form();
        final rejected = c.pick([
          pickedFile('notes.exe'),
          PickedFile(name: 'big.pdf', bytes: Uint8List(10 * 1024 * 1024 + 1)),
          pickedFile('ok.PDF'),
          pickedFile('ok.PDF'),
          pickedFile('sheet.xlsx', size: 2048),
        ]);
        expect(rejected, ['notes.exe is not a format the library takes', 'big.pdf (10 MB) is over the 10 MB limit']);
        expect(c.entries.map((e) => e.file.name), ['ok.PDF', 'sheet.xlsx']);
        expect(c.error, startsWith('Not added: '));
        expect(c.title, 'ok', reason: 'the title starts as the first file’s name, extension off');
        // The rest of the selection is kept, never cleared.
        c.pick([pickedFile('more.pdf')]);
        expect(c.entries, hasLength(3));
        expect(c.error, isNull);
      },
    );

    test('a document holds ten files: the eleventh is left out, and a document that has some has less room', () {
      final c = form();
      final rejected = c.pick([for (var i = 0; i < 12; i++) pickedFile('f$i.pdf', size: 100 + i)]);
      expect(c.entries, hasLength(10));
      expect(rejected, ['f10.pdf: a document holds up to 10 files', 'f11.pdf: a document holds up to 10 files']);
    });

    test('adding to a document with files already leaves room for the rest only', () async {
      final doc = await DemoLibraryRepository().document('d5');
      final c = form(target: doc);
      expect(c.room, 7);
      final rejected = c.pick([for (var i = 0; i < 9; i++) pickedFile('g$i.pdf', size: 10 + i)]);
      expect(c.entries, hasLength(7));
      expect(rejected.first, 'g7.pdf: this document has room for 7 more');
      expect(c.title, isEmpty, reason: 'an append has no title');
    });

    test(
      'a file is renamed in its base only: the extension stays, a path separator is swapped, an empty name falls back',
      () {
        final c = form();
        c.pick([pickedFile('Handover.v2.PDF', size: 10)]);
        final e = c.entries.single;
        expect(e.name, 'Handover.v2');
        c.rename(e.id, 'Night / rounds');
        expect(e.fileName, 'Night - rounds.PDF');
        c.rename(e.id, '   ');
        expect(e.fileName, 'Handover.v2.PDF');
      },
    );

    test('what is wrong is said by field, only once a send was tried', () async {
      final c = form();
      expect(c.problems, {
        'files': 'Choose at least one file.',
        'title': 'Give the document a title.',
        'category': 'Choose a category.',
      });
      expect(c.problemFor('title'), isNull, reason: 'nothing is shown before a send was tried');
      expect(c.canSubmit, isFalse);
      expect(await c.submit(), isNull);
      expect(c.problemFor('title'), 'Give the document a title.');
      expect(c.problemFor('files'), 'Choose at least one file.');
      expect(c.problemFor('category'), 'Choose a category.');

      c.pick([pickedFile('a.pdf')]);
      c.setTitle('x' * 201);
      c.setCategory(otherOption);
      expect(c.problems['title'], 'A title is at most 200 characters.');
      expect(c.problems['category'], 'Type the category.');
      c.setCategoryOther('y' * 61);
      expect(c.problems['category'], 'A category is at most 60 characters.');
      c.setCategoryOther('Board packs');
      c.setSubcategoryOther('z' * 81);
      c.setSpecializationOther('w' * 81);
      c.setDescription('d' * 2001);
      expect(c.problems.keys.toSet(), {'title', 'subcategory', 'specialization', 'description'});
      c.setTitle('Fine');
      c.setSubcategoryOther('');
      c.setDescription('');
      expect(c.problems, isEmpty);
      expect(c.canSubmit, isTrue);
    });

    test('an append needs only a file', () async {
      final doc = await DemoLibraryRepository().document('d9');
      final c = form(target: doc);
      expect(c.problems.keys, ['files']);
      c.pick([pickedFile('x.pdf')]);
      expect(c.problems, isEmpty);
    });

    test('sending uploads each file in order, then files the document with the stored files and the words', () async {
      final repo = FakeLibrary();
      final c = form(repo: repo);
      c.pick([pickedFile('Night rounds.pdf', size: 3000), pickedFile('Rota.xlsx', size: 1000)]);
      c.setDescription('  Who walks where  ');
      c.setCategory('Fire & Life Safety');
      c.setSubcategory('Fire Detection');
      final seen = <double>[];
      c.addListener(() => seen.add(c.progress));
      final doc = await c.submit();
      expect(doc, isNotNull);
      expect(c.result, doc);
      expect(repo.calls.where((x) => x.startsWith('upload') || x.startsWith('create')), [
        'upload:Night rounds.pdf',
        'upload:Rota.xlsx',
        'create:Night rounds',
      ]);
      expect(doc!.category, 'Fire & Life Safety');
      expect(doc.subcategory, 'Fire Detection');
      expect(doc.description, 'Who walks where');
      expect(doc.files.map((f) => f.fileName), ['Night rounds.pdf', 'Rota.xlsx']);
      expect(c.busy, isFalse);
      expect(c.progress, 1);
      expect(seen.last, 1);
      expect(seen.every((p) => p >= 0 && p <= 1), isTrue);
    });

    test(
      'a failed send keeps everything typed, shows the API’s sentence, and a retry does not upload a file twice',
      () async {
        final repo = FakeLibrary();
        final c = form(repo: repo);
        c.pick([pickedFile('One.pdf', size: 100), pickedFile('Two.pdf', size: 100)]);
        c.setCategory('Technology');
        repo.failures['upload:Two.pdf'] = ApiError(
          'application/x-msdownload is not an accepted file type for this upload.',
          statusCode: 400,
        );
        expect(await c.submit(), isNull);
        expect(c.error, 'application/x-msdownload is not an accepted file type for this upload.');
        expect(c.entries, hasLength(2));
        expect(c.title, 'One');
        expect(c.resolvedCategory, 'Technology');
        expect(repo.count('create'), 0);

        repo.failures.clear();
        expect(await c.submit(), isNotNull);
        expect(repo.calls.where((x) => x == 'upload:One.pdf'), hasLength(1), reason: 'the first file already went up');
        expect(repo.calls.where((x) => x == 'upload:Two.pdf'), hasLength(2));

        // A refused filing keeps the stored files too, and a rename sends that file again.
        final other = FakeLibrary();
        final d = form(repo: other);
        d.pick([pickedFile('Solo.pdf', size: 100)]);
        d.setCategory('Technology');
        other.failures['create'] = ApiError('You can only share a file you uploaded.', statusCode: 403);
        expect(await d.submit(), isNull);
        expect(d.error, 'You can only share a file you uploaded.');
        other.failures.clear();
        d.rename(d.entries.single.id, 'Solo v2');
        await d.submit();
        expect(other.calls.where((x) => x.startsWith('upload')), ['upload:Solo.pdf', 'upload:Solo v2.pdf']);
      },
    );

    test('an append sends only the files, to the document’s own route', () async {
      final repo = FakeLibrary();
      final doc = await repo.inner.document('d9');
      final c = form(target: doc, repo: repo);
      c.pick([pickedFile('Extra.pdf')]);
      final updated = await c.submit();
      expect(repo.calls.where((x) => x.startsWith('addFiles') || x.startsWith('create')), ['addFiles:d9']);
      expect(updated!.fileCount, 2);
    });
  });

  group('the upload form’s screen', () {
    Future<(FakeLibrary, FakeLibraryDevice)> pumpForm(
      WidgetTester tester, {
      FakeLibrary? repo,
      LibraryDocument? target,
      void Function(LibraryDocument?)? onPopped,
      bool ownBell = false,
      List<List<PickedFile>> picks = const [],
    }) async {
      _view(tester, height: 2600);
      final fake = repo ?? FakeLibrary();
      final device = FakeLibraryDevice()..picks.addAll(picks);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    final doc = await Navigator.of(context).push<LibraryDocument>(
                      MaterialPageRoute(
                        builder: (_) => UploadDocumentScreen(
                          repository: fake,
                          target: target,
                          handoffs: LibraryHandoffs(device: device, onBell: ownBell ? () {} : null),
                          usedCategories: const ['Board packs'],
                        ),
                      ),
                    );
                    onPopped?.call(doc);
                  },
                  child: const Text('open form'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open form'));
      await tester.pumpAndSettle();
      return (fake, device);
    }

    testWidgets('it opens on "Choose files" with the limits, and the picker is the phone’s', (tester) async {
      final (_, device) = await pumpForm(
        tester,
        picks: [
          [pickedFile('Handover checklist.pdf', size: 2048)],
        ],
      );
      expect(find.text('Share a document'), findsOneWidget);
      expect(find.textContaining('up to 10 MB each · up to 10 files'), findsOneWidget);
      await tester.tap(find.text('Choose files'));
      await tester.pumpAndSettle();
      expect(device.pickerOpened, 1);
      // The file shows as a row with its size, and the title is filled in from its name.
      expect(find.text('1 file · 2 KB'), findsOneWidget);
      expect(find.text('.pdf'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('upload-title'))).controller!.text, 'Handover checklist');
      expect(find.text('Add more'), findsOneWidget);
    });

    testWidgets('a file’s name is edited in its base, "Add more" opens the picker again, and the x removes a file', (
      tester,
    ) async {
      final (_, device) = await pumpForm(
        tester,
        picks: [
          [pickedFile('First.pdf', size: 100)],
          [pickedFile('Second.xlsx', size: 200), pickedFile('First.pdf', size: 100)],
        ],
      );
      await tester.tap(find.text('Choose files'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add more'));
      await tester.pumpAndSettle();
      expect(device.pickerOpened, 2);
      // The twin of First.pdf is not added again.
      expect(find.text('2 files · 300 B'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Second'), 'Rota 2026');
      await tester.pump();
      expect(find.text('.xlsx'), findsOneWidget);
      await tester.tap(find.byTooltip('Remove First.pdf'));
      await tester.pumpAndSettle();
      expect(find.text('1 file · 200 B'), findsOneWidget);
    });

    testWidgets('the rejected files are named in a banner and the rest is kept', (tester) async {
      await pumpForm(
        tester,
        picks: [
          [pickedFile('virus.exe'), pickedFile('fine.pdf', size: 100)],
        ],
      );
      await tester.tap(find.text('Choose files'));
      await tester.pumpAndSettle();
      expect(find.text('Not added: virus.exe is not a format the library takes.'), findsOneWidget);
      expect(find.text('1 file · 100 B'), findsOneWidget);
    });

    testWidgets('a send with nothing filled in names each missing piece and sends nothing', (tester) async {
      final (repo, _) = await pumpForm(tester);
      await tester.tap(find.text('Share with the library'));
      await tester.pumpAndSettle();
      expect(find.text('Choose at least one file.'), findsOneWidget);
      expect(find.text('Give the document a title.'), findsOneWidget);
      expect(find.text('Choose a category.'), findsOneWidget);
      expect(repo.count('upload'), 0);
    });

    testWidgets(
      'the category pickers: the platform’s tree, Other for your own words, a sub-category only after a category',
      (tester) async {
        final (repo, _) = await pumpForm(
          tester,
          picks: [
            [pickedFile('Plan.pdf', size: 100)],
          ],
        );
        await tester.tap(find.text('Choose files'));
        await tester.pumpAndSettle();
        expect(find.text('Sub-category'), findsNothing);
        await tester.tap(find.text('Choose a category'));
        await tester.pumpAndSettle();
        for (final label in [
          'Integrated Facility Management',
          'Fire & Life Safety',
          'Board packs',
          'Other (add your own)',
        ]) {
          expect(find.text(label), findsOneWidget);
        }
        await tester.tap(find.text('Integrated Facility Management'));
        await tester.pumpAndSettle();
        expect(find.text('Sub-category'), findsOneWidget);
        await tester.tap(find.text('Optional').first);
        await tester.pumpAndSettle();
        expect(find.text('Housekeeping'), findsOneWidget);
        await tester.tap(find.text('Housekeeping'));
        await tester.pumpAndSettle();
        expect(find.text('Specialisation'), findsOneWidget);
        expect(repo.count('taxonomy'), 1);

        // Other: the person types the category, and the levels under the old one are gone.
        await tester.tap(find.text('Integrated Facility Management'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Other (add your own)'));
        await tester.pumpAndSettle();
        expect(find.text('Your category'), findsOneWidget);
        expect(find.text('Specialisation'), findsNothing);
        await tester.enterText(find.byKey(const Key('upload-category-other')), 'Board packs & minutes');
        await tester.pump();
        expect(find.text('Sub-category'), findsOneWidget);
        expect(find.byKey(const Key('upload-subcategory-text')), findsOneWidget);
      },
    );

    testWidgets('sending shows the progress, closes with the document, and files it under what was typed', (
      tester,
    ) async {
      final repo = FakeLibrary();
      final gate = Completer<void>();
      LibraryDocument? popped;
      await pumpForm(
        tester,
        repo: repo,
        onPopped: (d) => popped = d,
        picks: [
          [pickedFile('Plan.pdf', size: 100)],
        ],
      );
      await tester.tap(find.text('Choose files'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('upload-title')), 'Night rounds plan');
      await tester.enterText(find.byKey(const Key('upload-description')), 'Who walks where');
      await tester.tap(find.text('Choose a category'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fire & Life Safety'));
      await tester.pumpAndSettle();
      repo.gate = gate.future;
      await tester.tap(find.text('Share with the library'));
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Uploading 1 of 1…'), findsOneWidget);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('open form'), findsOneWidget);
      expect(popped!.title, 'Night rounds plan');
      expect(popped!.category, 'Fire & Life Safety');
      expect(popped!.description, 'Who walks where');
    });

    testWidgets('a refusal is shown under the form, everything typed stays, and sending again works', (tester) async {
      final repo = FakeLibrary()
        ..failures['create'] = ApiError('Upload the file before describing it.', statusCode: 400);
      LibraryDocument? popped;
      await pumpForm(
        tester,
        repo: repo,
        onPopped: (d) => popped = d,
        picks: [
          [pickedFile('Plan.pdf', size: 100)],
        ],
      );
      await tester.tap(find.text('Choose files'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose a category'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Technology'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Share with the library'));
      await tester.pumpAndSettle();
      expect(find.text('Upload the file before describing it.'), findsOneWidget);
      expect(find.text('Plan'), findsWidgets);
      expect(popped, isNull);
      repo.failures.clear();
      await tester.tap(find.text('Share with the library'));
      await tester.pumpAndSettle();
      expect(popped, isNotNull);
      expect(repo.calls.where((c) => c.startsWith('upload')), hasLength(1));
    });

    testWidgets('Back with something typed asks to discard; Cancel keeps the form, Discard closes it', (tester) async {
      await pumpForm(
        tester,
        picks: [
          [pickedFile('Plan.pdf', size: 100)],
        ],
      );
      await tester.tap(find.text('Choose files'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Symbols.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('Discard this upload?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Share a document'), findsOneWidget);
      await tester.tap(find.byIcon(Symbols.arrow_back));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.text('open form'), findsOneWidget);
    });

    testWidgets('an empty form goes back at once', (tester) async {
      await pumpForm(tester);
      await tester.tap(find.byIcon(Symbols.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('open form'), findsOneWidget);
    });

    testWidgets('the bell opens the website’s notifications page through the phone when the shell wired none', (
      tester,
    ) async {
      final (_, device) = await pumpForm(tester);
      await tester.tap(find.byIcon(LucideIcons.bell));
      expect(device.opened.single, AppConfig.sitePage('/notifications'));
    });
  });
}
