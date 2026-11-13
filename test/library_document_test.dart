import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/config.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/chapters/community_kit.dart' show CommunityButton;
import 'package:icr_mobile/features/library/demo_library_repository.dart';
import 'package:icr_mobile/features/library/document_controller.dart';
import 'package:icr_mobile/features/library/document_screen.dart';
import 'package:icr_mobile/features/library/library_handoffs.dart';
import 'package:icr_mobile/features/library/library_models.dart';
import 'package:icr_mobile/features/library/upload_controller.dart';
import 'package:icr_mobile/features/library/upload_document_screen.dart';
import 'package:icr_mobile/features/library/preview_runner.dart';
import 'package:icr_mobile/features/library/widgets/document_viewer_screen.dart';
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
  final pdf = FakePdfEngine();
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
  LibraryDocument? doc,
}) async {
  _view(tester, height: height);
  final fake = repo ?? FakeLibrary();
  final initial = doc ?? (read ? null : await fake.inner.document(id));
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
            pdf: page.pdf,
            runner: runHere,
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
      expect(find.text('About This Document'), findsOneWidget);
      expect(find.textContaining('60-point checklist'), findsOneWidget);
      expect(find.text('fm-handover-checklist.pdf'), findsOneWidget);
      // Each file: Preview in the app, Download and Share (the website's Download, owner 5 Nov 2026).
      expect(find.text('Preview'), findsOneWidget);
      expect(find.text('Download'), findsOneWidget);
      expect(find.byTooltip('Share fm-handover-checklist.pdf'), findsOneWidget);
      // Somebody else's document: report it, never delete or add to it.
      expect(find.text('Report'), findsOneWidget);
      expect(find.text('Delete'), findsNothing);
      expect(find.text('Add Files'), findsNothing);
      expect(find.text('YOU'), findsNothing);
    });

    testWidgets('a pack lists every file with its own size and count, and says "Files"', (tester) async {
      await _pumpDoc(tester, 'd5');
      expect(find.text('lease-audit-template.xlsx'), findsOneWidget);
      expect(find.text('lease-audit-worked-example.xlsx'), findsOneWidget);
      expect(find.text('lease-audit-method.pdf'), findsOneWidget);
      // Every file of the pack, Excel and PDF alike, has its own Preview and Download.
      expect(find.text('Preview'), findsNWidgets(3));
      expect(find.text('Download'), findsNWidgets(3));
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
      expect(find.text("Unable to Load This Document"), findsOneWidget);
      expect(find.text('That document is no longer in the library.'), findsOneWidget);
      await tester.tap(find.text('Try Again'));
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

  group('reading, downloading and sharing', () {
    testWidgets('Preview reads the file for the viewer (not a download), counts one opening, and opens it in the app', (
      tester,
    ) async {
      final page = await _pumpDoc(tester, _theirs);
      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();
      expect(page.repo.calls, contains('preview:d1-f0'));
      expect(page.repo.calls, contains('view:d1'));
      expect(page.repo.calls.where((c) => c.startsWith('download')), isEmpty, reason: 'a preview is not a download');
      // The PDF is drawn by the in-app viewer from the bytes the API streamed.
      expect(find.byType(DocumentViewerScreen), findsOneWidget);
      expect(page.pdf.opened, hasLength(1));
      expect(find.text('Page 1 of 3'), findsOneWidget);
      expect(find.text('fm-handover-checklist.pdf'), findsOneWidget);
      // A preview is not a download: 482 downloads still, and one more opening.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('482'), findsOneWidget);
      expect(find.text('1,291'), findsOneWidget);
      expect(page.changed.last.viewCount, 1291);
      expect(page.changed.last.downloadCount, 482);

      // The same page counts one opening however many files are read.
      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();
      expect(page.repo.calls.where((c) => c == 'view:d1'), hasLength(1));
      expect(page.pdf.opened, hasLength(2));
    });

    testWidgets('the viewer lets the PDF go when it closes', (tester) async {
      final page = await _pumpDoc(tester, _theirs);
      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();
      expect(page.pdf.closed, 0);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(page.pdf.closed, 1);
    });

    testWidgets('Download fetches the file as a counted download, saves it through "Save as", and the counts follow', (
      tester,
    ) async {
      final page = await _pumpDoc(tester, _theirs);
      await tester.tap(find.text('Download'));
      await tester.pumpAndSettle();
      expect(page.repo.calls, contains('download:d1-f0'));
      expect(page.repo.calls.where((c) => c.startsWith('preview')), isEmpty, reason: 'a download, not the viewer');
      expect(page.device.saved, ['fm-handover-checklist.pdf']);
      expect(find.text('Saved fm-handover-checklist.pdf.'), findsOneWidget);
      // 482 downloads become 483, on the page and in the list behind it.
      expect(find.text('483'), findsOneWidget);
      expect(page.changed.last.downloadCount, 483);
      expect(page.changed.last.files.first.downloadCount, page.changed.last.downloadCount);
    });

    testWidgets('a cancelled "Save as" says nothing; the download was still counted, as the API counts it', (
      tester,
    ) async {
      final page = await _pumpDoc(tester, _theirs);
      page.device.saveAnswer = false;
      await tester.tap(find.text('Download'));
      await tester.pumpAndSettle();
      expect(page.device.saved, isEmpty);
      expect(find.textContaining('Saved '), findsNothing);
    });

    testWidgets('Share on a file sends the file itself; Share at the top still sends the library’s link', (
      tester,
    ) async {
      final page = await _pumpDoc(tester, 'd5');
      await tester.tap(find.byTooltip('Share lease-audit-method.pdf'));
      await tester.pumpAndSettle();
      expect(page.device.sharedFiles, ['lease-audit-method.pdf']);
      expect(page.repo.calls.where((c) => c.startsWith('download:')), hasLength(1));
      await tester.tap(find.text('Share'));
      expect(page.shared.single.$2, Uri.parse('https://icr.test/documents'));
    });

    testWidgets('a refused download shows the API’s sentence and saves nothing', (tester) async {
      final repo = FakeLibrary()..failures['download'] = ApiError('The stored file is missing.', statusCode: 404);
      final page = await _pumpDoc(tester, _theirs, repo: repo);
      await tester.tap(find.text('Download'));
      await tester.pumpAndSettle();
      expect(find.text('The stored file is missing.'), findsOneWidget);
      expect(page.device.saved, isEmpty);
      expect(find.text('482'), findsOneWidget);
    });

    testWidgets('the viewer has Download and Share, and both fetch the file as a download', (tester) async {
      final page = await _pumpDoc(tester, _mine);
      expect(find.text('Preview'), findsOneWidget);
      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();
      expect(find.byType(DocumentViewerScreen), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(page.repo.calls, contains('preview:d9-f0'));
      expect(page.pdf.opened, isEmpty);

      await tester.tap(find.byTooltip('Download'));
      await tester.pumpAndSettle();
      expect(page.repo.calls, contains('download:d9-f0'));
      expect(page.device.saved, hasLength(1));

      await tester.tap(find.byTooltip('Share'));
      await tester.pumpAndSettle();
      expect(page.device.sharedFiles, hasLength(1));
      expect(page.repo.calls.where((c) => c.startsWith('download:')), hasLength(2));
    });

    testWidgets('a format the viewer reads as text (a sample workbook) opens too, not a hand-over', (tester) async {
      final page = await _pumpDoc(tester, 'd3');
      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();
      expect(find.byType(DocumentViewerScreen), findsOneWidget);
      expect(page.repo.calls, contains('preview:d3-f0'));
    });

    testWidgets('a plan that does not open it: the server’s own sentence in a lock card, and See plans', (
      tester,
    ) async {
      final repo = FakeLibrary()
        ..failures['preview'] = ApiError(
          'Your plan opens Limited documents. Upgrade to open this one.',
          statusCode: 403,
        );
      final page = await _pumpDoc(tester, _theirs, repo: repo);
      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();
      expect(find.text('Not Included in Your Plan'), findsOneWidget);
      expect(find.text('Your plan opens Limited documents. Upgrade to open this one.'), findsOneWidget);
      expect(find.byType(DocumentViewerScreen), findsNothing);
      await tester.tap(find.text('View Plans'));
      expect(page.plans, 1);

      // The card goes when a read works.
      repo.failures.clear();
      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();
      expect(find.byType(DocumentViewerScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Not Included in Your Plan'), findsNothing);
    });

    testWidgets('the lock card has no button without a shell callback; a sign-in wall is a message, not a lock', (
      tester,
    ) async {
      final repo = FakeLibrary()..failures['preview'] = ApiError('Not allowed.', statusCode: 403);
      await _pumpDoc(tester, _theirs, repo: repo, plans: false);
      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();
      expect(find.text('Not allowed.'), findsOneWidget);
      expect(find.text('View Plans'), findsNothing);

      final signedOut = FakeLibrary()..failures['preview'] = ApiError('Unauthorized', statusCode: 401);
      await _pumpDoc(tester, _theirs, repo: signedOut);
      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();
      expect(find.text('Unauthorized'), findsOneWidget);
      expect(find.text('Not Included in Your Plan'), findsNothing);
    });

    testWidgets('a read that fails shows the API’s sentence and does not count an opening', (tester) async {
      final repo = FakeLibrary()..failures['preview'] = ApiError('The stored file is missing.', statusCode: 404);
      final page = await _pumpDoc(tester, _theirs, repo: repo);
      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();
      expect(find.text('The stored file is missing.'), findsOneWidget);
      expect(page.repo.calls.where((c) => c.startsWith('view:')), isEmpty);
    });

    testWidgets('a format with no reader says so and offers Download instead of Preview', (tester) async {
      final repo = FakeLibrary();
      const odd = LibraryDocument(
        id: 'odd',
        title: 'CAD drawing',
        uploaderId: 'demo-priya',
        files: [LibraryFile(id: 'odd-f0', fileName: 'plan.dwg', mimeType: 'application/acad', sizeBytes: 2048)],
      );
      await _pumpDoc(tester, 'odd', repo: repo, doc: odd);
      expect(find.text('Preview'), findsNothing);
      // The website's words: download it to read it, and the Download is there.
      expect(find.text("Other files can't be previewed in the app. Download the file to read it."), findsOneWidget);
      expect(find.text('Download'), findsOneWidget);
    });
  });

  group('reporting', () {
    testWidgets('a document of my own has no Report', (tester) async {
      await _pumpDoc(tester, _mine);
      expect(find.text('Report'), findsNothing);
      expect(find.text('YOU'), findsOneWidget);
    });

    testWidgets('the sheet lists the six reasons, asks for a note on "Something Else", and sends the reason and note', (
      tester,
    ) async {
      final page = await _pumpDoc(tester, _theirs);
      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();
      expect(find.text('Report This Document'), findsOneWidget);
      for (final r in DocumentReportReason.values) {
        expect(find.text(r.label), findsOneWidget);
      }
      // Nothing to send until a reason is chosen.
      expect(
        tester.widget<ReportSheet>(find.byType(ReportSheet)).title,
        'FM Handover Checklist: New Building Takeover',
      );
      await tester.tap(find.text('Send Report'));
      await tester.pumpAndSettle();
      expect(page.repo.count('report'), 0);

      await tester.tap(find.text('Something Else'));
      await tester.pumpAndSettle();
      expect(find.text('What is wrong? (Required)'), findsOneWidget);
      await tester.tap(find.text('Send Report'));
      await tester.pumpAndSettle();
      expect(page.repo.count('report'), 0, reason: 'a note is required for Something else');

      await tester.enterText(find.byType(TextField).last, 'Page 3 is the wrong lease');
      await tester.pump();
      await tester.tap(find.text('Send Report'));
      await tester.pumpAndSettle();
      expect(page.repo.inner.calls, contains('report:d1:OTHER:Page 3 is the wrong lease'));
      expect(find.text('Report Sent'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Report Sent'), findsNothing);
      // The page remembers: Reported, and nothing more to send.
      expect(find.text('Reported'), findsOneWidget);
      expect(find.text('Report'), findsNothing);
    });

    testWidgets('a reason alone is enough for the other five, and the note is optional', (tester) async {
      final page = await _pumpDoc(tester, _theirs);
      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Damaged or Unreadable File'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send Report'));
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
      await tester.tap(find.text('Spam or Advertising'));
      await tester.enterText(find.byType(TextField).last, 'sells something');
      await tester.pump();
      await tester.tap(find.text('Send Report'));
      await tester.pumpAndSettle();
      expect(find.text('You have already reported this document. An admin is reviewing it.'), findsOneWidget);
      expect(find.text('Report Sent'), findsNothing);
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
      await tester.tap(find.text('Misleading or Out of Date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send Report'));
      await tester.pumpAndSettle();
      expect(find.text('That document is no longer in the library.'), findsOneWidget);
      repo.failures.clear();
      await tester.tap(find.text('Send Report'));
      await tester.pumpAndSettle();
      expect(find.text('Report Sent'), findsOneWidget);
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

    testWidgets('Edit changes the title and the description, tells the list, and the page shows them', (tester) async {
      final page = await _pumpDoc(tester, _mine);
      // The pencil left of the bell (owner, 12 Nov 2026); no Edit button in the page.
      expect(find.widgetWithText(CommunityButton, 'Edit'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('bar-edit')));
      await tester.pumpAndSettle();
      expect(find.text('Edit Document'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('edit-title')), 'Chiller plant walk-down, revised');
      await tester.enterText(find.byKey(const ValueKey('edit-description')), 'The 2026 sheet.');
      await tester.tap(find.widgetWithText(CommunityButton, 'Save'));
      await tester.pumpAndSettle();
      expect(page.repo.calls, contains('update:d9'));
      expect(find.text('Chiller plant walk-down, revised'), findsWidgets);
      expect(find.text('The 2026 sheet.'), findsWidgets);
      expect(page.changed.map((d) => d.title), ['Chiller plant walk-down, revised']);
      expect(find.text('Saved.'), findsOneWidget);
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
      expect(find.text('Add Files'), findsOneWidget);
      expect(find.byTooltip('Remove lease-audit-method.pdf'), findsOneWidget);
      expect(find.text('Report'), findsOneWidget, reason: 'an admin did not share it, so it can be reported');
    });

    testWidgets('a signed-out reader may report, never change', (tester) async {
      final repo = FakeLibrary(viewer: null);
      await _pumpDoc(tester, _theirs, repo: repo);
      expect(find.text('Delete'), findsNothing);
      expect(find.text('Add Files'), findsNothing);
      expect(find.text('Report'), findsOneWidget);
    });

    testWidgets('a file of a pack can be dropped, after asking; the last file cannot (the API’s sentence)', (
      tester,
    ) async {
      final repo = FakeLibrary();
      final page = await _pumpDoc(tester, 'd5', repo: repo);
      expect(find.text('Preview'), findsNWidgets(3));
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
      expect(find.text('Preview'), findsNWidgets(2));
      expect(page.changed.last.fileCount, 2);

      await tester.tap(find.byTooltip('Remove lease-audit-worked-example.xlsx'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Remove')));
      await tester.pumpAndSettle();
      // One file left: no remove glyph is drawn for it.
      expect(find.byTooltip('Remove lease-audit-template.xlsx'), findsNothing);
      expect(find.text('Preview'), findsOneWidget);

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
      await tester.tap(find.text('Add Files'));
      await tester.pumpAndSettle();
      expect(find.byType(UploadDocumentScreen), findsOneWidget);
      expect(find.text('Add Files'), findsWidgets);
      expect(
        find.text(
          'These files will be added to “Chiller Plant Room Walk-down”, with the same description and category.',
        ),
        findsOneWidget,
      );
      // Append mode asks for no title and no category.
      expect(find.text('Title *'), findsNothing);
      await tester.tap(find.text('Select Files'));
      await tester.pumpAndSettle();
      expect(find.text('Add Files'), findsWidgets);
      await tester.tap(find.text('Add 1 file'));
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
      expect(c.specializationOptions, [otherOption], reason: 'nothing is listed under it but Other');
      expect(c.hasSpecializations, isFalse);
      c.setCategory('Technology');
      expect(c.subcategoryOptions, [otherOption], reason: 'a category with no children offers only Other');
      expect(c.hasSubcategories, isFalse);
      c.setCategory(null);
      expect(c.subcategoryOptions, isEmpty, reason: 'no sub-category without a category');
    });

    test('the category box searches every level of the tree, categories first, Other last', () {
      final c = form();
      // Empty: the categories alone, then Other.
      expect(c.searchCategories('').map((p) => p.label), [
        'Fire & Life Safety',
        'Technology',
        'Board packs',
        otherOption,
      ]);
      // Typed: each word must be in the path; a deeper hit shows under its category.
      final hits = c.searchCategories('fire panel');
      expect(hits.map((p) => p.path), [
        ['Fire & Life Safety', 'Fire Detection', 'Addressable Panels'],
        [otherOption],
      ]);
      expect(c.searchCategories('sprinkler').map((p) => p.path), [
        ['Fire & Life Safety', 'Sprinklers'],
        [otherOption],
      ]);
      // A category that matches comes before the deeper ones that match through it.
      expect(c.searchCategories('fire').map((p) => p.path), [
        ['Fire & Life Safety'],
        ['Fire & Life Safety', 'Fire Detection'],
        ['Fire & Life Safety', 'Fire Detection', 'Addressable Panels'],
        ['Fire & Life Safety', 'Sprinklers'],
        [otherOption],
      ]);
      expect(c.searchCategories('zzzz').map((p) => p.path), [
        [otherOption],
      ], reason: 'writing your own stays one pick away');
    });

    test('picking a deeper node fills the levels above it; a category alone clears the old levels', () {
      final c = form();
      c.chooseCategory(['Fire & Life Safety', 'Fire Detection', 'Addressable Panels']);
      expect(c.category, 'Fire & Life Safety');
      expect(c.subcategory, 'Fire Detection');
      expect(c.specialization, 'Addressable Panels');
      expect(
        (c.resolvedCategory, c.resolvedSubcategory, c.resolvedSpecialization),
        ('Fire & Life Safety', 'Fire Detection', 'Addressable Panels'),
      );
      c.chooseCategory(['Technology']);
      expect(c.subcategory, isNull);
      expect(c.specialization, isNull);
      expect(c.resolvedSubcategory, isEmpty);
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
        expect(c.subcategoryOptions, [otherOption], reason: 'nothing is listed under a category of your own');
        c.setSubcategory(otherOption);
        c.setSubcategoryOther('Quarterly');
        expect(c.resolvedSubcategory, 'Quarterly', reason: 'under your own category the sub-category is typed');
        c.setSpecialization(otherOption);
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
        // The website's sentences: "<name> is <size>" for a file over 10 MB.
        expect(rejected, ['notes.exe is not a supported format', 'big.pdf is 10 MB']);
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
      expect(rejected, ['f10.pdf: the limit is 10 files', 'f11.pdf: the limit is 10 files']);
    });

    test('adding to a document with files already leaves room for the rest only', () async {
      final doc = await DemoLibraryRepository().document('d5');
      final c = form(target: doc);
      expect(c.room, 7);
      final rejected = c.pick([for (var i = 0; i < 9; i++) pickedFile('g$i.pdf', size: 10 + i)]);
      expect(c.entries, hasLength(7));
      expect(rejected.first, 'g7.pdf: the limit is 10 files');
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
        'files': 'Select at least one file.',
        'title': 'Enter a title for the document.',
        'category': 'Select a category.',
      });
      expect(c.problemFor('title'), isNull, reason: 'nothing is shown before a send was tried');
      expect(c.canSubmit, isFalse);
      expect(await c.submit(), isNull);
      expect(c.problemFor('title'), 'Enter a title for the document.');
      expect(c.problemFor('files'), 'Select at least one file.');
      expect(c.problemFor('category'), 'Select a category.');

      c.pick([pickedFile('a.pdf')]);
      c.setTitle('x' * 201);
      c.setCategory(otherOption);
      expect(c.problems['title'], 'A title is at most 200 characters.');
      expect(c.problems['category'], 'Enter the category.');
      c.setCategoryOther('y' * 61);
      expect(c.problems['category'], 'A category is at most 60 characters.');
      c.setCategoryOther('Board packs');
      c.setSubcategory(otherOption);
      c.setSubcategoryOther('z' * 81);
      c.setSpecialization(otherOption);
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

    testWidgets('it opens on "Select Files" with the website’s words, and the picker is the phone’s', (tester) async {
      final (_, device) = await pumpForm(
        tester,
        picks: [
          [pickedFile('Handover checklist.pdf', size: 2048)],
        ],
      );
      expect(find.text('Upload a Document'), findsOneWidget);
      expect(find.text('PDF, Word, Excel, PowerPoint, CSV, images or ZIP. Up to 10 MB each.'), findsOneWidget);
      expect(find.text('Select several files to group them under one title.'), findsOneWidget);
      await tester.tap(find.text('Select Files'));
      await tester.pumpAndSettle();
      expect(device.pickerOpened, 1);
      // The file shows as a row with its size, and the title is filled in from its name.
      expect(find.text('1 file · 2 KB'), findsOneWidget);
      expect(find.text('.pdf'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('upload-title'))).controller!.text, 'Handover checklist');
      expect(find.text('Add More'), findsOneWidget);
      // The name it will be saved under is a field of its own, with the website's helper.
      expect(find.text('File Name'), findsOneWidget);
      expect(find.text('You can rename it. Members see and download this name.'), findsOneWidget);
    });

    testWidgets('the fields and their words are the website’s, in its order', (tester) async {
      await pumpForm(
        tester,
        picks: [
          [pickedFile('Plan.pdf', size: 100), pickedFile('Rota.xlsx', size: 100)],
        ],
      );
      await tester.tap(find.text('Select Files'));
      await tester.pumpAndSettle();
      final order = ['Title *', 'Description', 'Category *'].map((t) => tester.getTopLeft(find.text(t)).dy).toList();
      expect([...order]..sort(), order, reason: 'files, then Title, Description, Category');
      expect(find.text('One title for all files. Use words people would search for.'), findsOneWidget);
      expect(find.text('Describe what it is and when to use it.'), findsOneWidget);
      expect(find.text('Type a category, sub-category or specialization'), findsOneWidget);
      expect(find.text('Used to group and filter documents.'), findsOneWidget);
      // Nothing below a category until one is chosen.
      expect(find.text('Sub-category (Optional)'), findsNothing);
      expect(find.text('Specialization (Optional)'), findsNothing);
      // The app's old wording is gone.
      expect(find.text('Share with the library'), findsNothing);
    });

    testWidgets('a file’s name is edited in its base, "Add More" opens the picker again, and the x removes a file', (
      tester,
    ) async {
      final (_, device) = await pumpForm(
        tester,
        picks: [
          [pickedFile('First.pdf', size: 100)],
          [pickedFile('Second.xlsx', size: 200), pickedFile('First.pdf', size: 100)],
        ],
      );
      await tester.tap(find.text('Select Files'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add More'));
      await tester.pumpAndSettle();
      expect(device.pickerOpened, 2);
      // The twin of First.pdf is not added again.
      expect(find.text('2 files · 300 B'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Second'), 'Rota 2026');
      await tester.pump();
      expect(find.text('.xlsx'), findsOneWidget);
      expect(find.text('Will be saved as “Rota 2026.xlsx”'), findsOneWidget);
      await tester.tap(find.byTooltip('Remove First.pdf'));
      await tester.pumpAndSettle();
      expect(find.text('1 file · 200 B'), findsOneWidget);
    });

    testWidgets('an emptied file name goes back to the original', (tester) async {
      await pumpForm(
        tester,
        picks: [
          [pickedFile('Night rounds.pdf', size: 100)],
        ],
      );
      await tester.tap(find.text('Select Files'));
      await tester.pumpAndSettle();
      // The title box also holds "Night rounds"; the file's name field is the one under "File Name".
      final name = find.descendant(
        of: find.ancestor(of: find.text('File Name'), matching: find.byType(Column)).first,
        matching: find.byType(TextField),
      );
      await tester.enterText(name.first, '   ');
      await tester.pump();
      // Leaving the box (focus to the title) puts the original back instead of saving ".pdf".
      await tester.tap(find.byKey(const Key('upload-title')));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(name.first).controller!.text, 'Night rounds');
    });

    testWidgets('the rejected files are named in a banner and the rest is kept', (tester) async {
      await pumpForm(
        tester,
        picks: [
          [pickedFile('virus.exe'), pickedFile('fine.pdf', size: 100)],
        ],
      );
      await tester.tap(find.text('Select Files'));
      await tester.pumpAndSettle();
      expect(find.text('Not added: virus.exe is not a supported format.'), findsOneWidget);
      expect(find.text('1 file · 100 B'), findsOneWidget);
    });

    testWidgets('Upload waits for a file, a title and a category, as the website’s button does', (tester) async {
      final (repo, _) = await pumpForm(
        tester,
        picks: [
          [pickedFile('Plan.pdf', size: 100)],
        ],
      );
      bool enabled() =>
          tester.widget<CommunityButton>(find.widgetWithText(CommunityButton, 'Upload')).onPressed != null;
      expect(enabled(), isFalse, reason: 'no file yet');
      await tester.tap(find.text('Select Files'));
      await tester.pumpAndSettle();
      expect(enabled(), isFalse, reason: 'a file and a title, but no category');
      await tester.tap(find.text('Type a category, sub-category or specialization'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Technology'));
      await tester.pumpAndSettle();
      expect(enabled(), isTrue);
      await tester.enterText(find.byKey(const Key('upload-title')), '   ');
      await tester.pump();
      expect(enabled(), isFalse, reason: 'a blank title is no title');
      // Choosing Other and typing nothing is no category either.
      await tester.enterText(find.byKey(const Key('upload-title')), 'Plan');
      await tester.tap(find.text('Technology'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Other (Add Your Own)'));
      await tester.pumpAndSettle();
      expect(enabled(), isFalse);
      await tester.enterText(find.byKey(const Key('upload-category-other')), 'Board papers');
      await tester.pump();
      expect(enabled(), isTrue);
      expect(repo.count('upload'), 0);
    });

    testWidgets(
      'the category box searches the whole tree; a deeper pick fills the levels above and Other asks for your own words',
      (tester) async {
        final (repo, _) = await pumpForm(
          tester,
          picks: [
            [pickedFile('Plan.pdf', size: 100)],
          ],
        );
        await tester.tap(find.text('Select Files'));
        await tester.pumpAndSettle();
        expect(find.text('Sub-category (Optional)'), findsNothing);
        await tester.tap(find.text('Type a category, sub-category or specialization'));
        await tester.pumpAndSettle();
        // Empty: the categories, the library's own after them, and Other at the foot.
        for (final label in ['Integrated Facility Management', 'Fire & Life Safety', 'Board packs', otherOption]) {
          expect(find.text(label), findsOneWidget);
        }
        expect(find.text('Housekeeping'), findsNothing, reason: 'a sub-category is not listed until it is searched');

        // Typed: "housekeeping" finds the sub-category and its specialization under their category.
        await tester.enterText(find.byKey(const Key('category-search')), 'housekeeping');
        await tester.pumpAndSettle();
        expect(find.text('Integrated Facility Management'), findsOneWidget, reason: 'the group heading');
        expect(find.text('Housekeeping'), findsOneWidget);
        expect(find.textContaining('Deep cleaning'), findsOneWidget);
        expect(find.text('Fire & Life Safety'), findsNothing);
        await tester.tap(find.textContaining('Deep cleaning'));
        await tester.pumpAndSettle();
        // All three levels are filled in from the one pick.
        expect(find.text('Integrated Facility Management'), findsOneWidget);
        expect(find.text('Housekeeping'), findsOneWidget);
        expect(find.text('Deep cleaning'), findsOneWidget);
        expect(find.text('Sub-category (Optional)'), findsOneWidget);
        expect(find.text('Specialization (Optional)'), findsOneWidget);
        expect(repo.count('taxonomy'), 1);

        // The sub-category list: its children, then Other; the hint says when there are none.
        await tester.tap(find.byTooltip('Clear Specialization (Optional)'));
        await tester.pumpAndSettle();
        expect(find.text('Deep cleaning'), findsNothing);
        await tester.tap(find.byTooltip('Clear Sub-category (Optional)'));
        await tester.pumpAndSettle();
        expect(find.text('Select a sub-category'), findsOneWidget);
        await tester.tap(find.text('Select a sub-category'));
        await tester.pumpAndSettle();
        expect(find.text('Handover & Commissioning'), findsOneWidget);
        expect(find.text('Other (Add Your Own)'), findsOneWidget);
        await tester.tap(find.text('Handover & Commissioning'));
        await tester.pumpAndSettle();
        expect(find.text('No specializations in this sub-category'), findsOneWidget);

        // Other: the person types the category, and the levels under the old one are gone.
        await tester.tap(find.text('Integrated Facility Management'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Other (Add Your Own)'));
        await tester.pumpAndSettle();
        expect(find.text('Your Category *'), findsOneWidget);
        expect(find.text('e.g. Board papers'), findsOneWidget);
        expect(find.text('Specialization (Optional)'), findsNothing);
        await tester.enterText(find.byKey(const Key('upload-category-other')), 'Board packs & minutes');
        await tester.pump();
        // Under a category of your own the sub-category list offers only Other, which asks for your words too.
        expect(find.text('Sub-category (Optional)'), findsOneWidget);
        expect(find.text('No sub-categories in this category'), findsOneWidget);
        await tester.tap(find.text('No sub-categories in this category'));
        await tester.pumpAndSettle();
        // The sheet's Other (the category box behind it shows its own).
        await tester.tap(find.text('Other (Add Your Own)').last);
        await tester.pumpAndSettle();
        expect(find.text('Your Sub-category'), findsOneWidget);
        await tester.enterText(find.byKey(const Key('upload-subcategory-other')), 'Quarterly');
        await tester.pump();
        expect(find.text('Specialization (Optional)'), findsOneWidget);
      },
    );

    testWidgets(
      'sending shows the website’s progress words, closes with the document, and files it under what was typed',
      (tester) async {
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
        await tester.tap(find.text('Select Files'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('upload-title')), 'Night rounds plan');
        await tester.enterText(find.byKey(const Key('upload-description')), 'Who walks where');
        await tester.tap(find.text('Type a category, sub-category or specialization'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Fire & Life Safety'));
        await tester.pumpAndSettle();
        repo.gate = gate.future;
        await tester.tap(find.text('Upload'));
        await tester.pump();
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        expect(find.text('Starting…'), findsOneWidget);
        gate.complete();
        await tester.pumpAndSettle();
        expect(find.text('open form'), findsOneWidget);
        expect(popped!.title, 'Night rounds plan');
        expect(popped!.category, 'Fire & Life Safety');
        expect(popped!.description, 'Who walks where');
      },
    );

    test('the progress names the file and its place in the batch, from "Starting…" to "Saving…"', () async {
      final c = UploadController(repository: FakeLibrary());
      c.pick([pickedFile('One.pdf', size: 300), pickedFile('Two.pdf', size: 100)]);
      c.setCategory(otherOption);
      c.setCategoryOther('Board papers');
      final seen = <String>[];
      c.addListener(() {
        if (!c.busy) return;
        seen.add(
          c.starting
              ? 'starting'
              : c.saving
              ? 'saving'
              : '${c.uploadingName} ${c.uploadingIndex}',
        );
      });
      expect(await c.submit(), isNotNull, reason: c.error);
      expect(seen.first, 'starting');
      expect(seen, contains('One.pdf 1'));
      expect(seen.last, 'saving', reason: 'every byte is up and the document is being filed');
    });

    testWidgets('a refusal is shown at the top of the form, everything typed stays, and sending again works', (
      tester,
    ) async {
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
      await tester.tap(find.text('Select Files'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Type a category, sub-category or specialization'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Technology'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Upload'));
      await tester.pumpAndSettle();
      final refusal = find.text('Upload the file before describing it.');
      expect(refusal, findsOneWidget);
      expect(
        tester.getTopLeft(refusal).dy,
        lessThan(tester.getTopLeft(find.text('Title *')).dy),
        reason: 'the website’s alert sits above the files and the fields',
      );
      expect(find.text('Plan'), findsWidgets);
      expect(popped, isNull);
      repo.failures.clear();
      await tester.tap(find.text('Upload'));
      await tester.pumpAndSettle();
      expect(popped, isNotNull);
      expect(repo.calls.where((c) => c.startsWith('upload')), hasLength(1));
    });

    testWidgets('Back goes back at once, with nothing asked: the website’s form has no discard step', (tester) async {
      await pumpForm(
        tester,
        picks: [
          [pickedFile('Plan.pdf', size: 100)],
        ],
      );
      await tester.tap(find.text('Select Files'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Symbols.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('Discard this upload?'), findsNothing);
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
