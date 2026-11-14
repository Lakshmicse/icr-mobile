import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/chapters/chapter_links.dart';
import 'package:icr_mobile/features/chapters/chapter_models.dart';
import 'package:icr_mobile/features/chapters/resource_download.dart';
import 'package:icr_mobile/features/chapters/widgets/chapter_sections.dart';
import 'package:icr_mobile/features/chapters/widgets/resource_row.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'helpers/fonts.dart';
import 'helpers/resource_fakes.dart';

// Chapter and council resources: the website's Download button in the app, what the address turns out to be, and
// the sponsor tiles' links.

ChapterResource _resource({
  String id = 'r1',
  String title = 'Benchmark 2026',
  String kind = 'WHITEPAPER',
  String url = 'https://files.test/benchmark.pdf',
  String? sizeLabel = '2 MB',
}) => ChapterResource(id: id, title: title, kind: kind, url: url, sizeLabel: sizeLabel);

/// A Dio whose network is a single canned answer, recording the requests.
class _Net implements HttpClientAdapter {
  _Net(this.answer);

  final ResponseBody Function(RequestOptions options) answer;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return answer(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _bytes(List<int> body, {int status = 200, Map<String, String> headers = const {}}) =>
    ResponseBody.fromBytes(
      body,
      status,
      headers: {
        for (final e in headers.entries) e.key: [e.value],
      },
    );

SystemResourceDownloader _downloader(_Net net) => SystemResourceDownloader(dio: Dio()..httpClientAdapter = net);

Future<ResourceDownloadException> _refusal(Future<Object?> run) async {
  try {
    await run;
  } on ResourceDownloadException catch (e) {
    return e;
  }
  fail('Expected a ResourceDownloadException');
}

void main() {
  setUpAll(loadAppFonts);

  group('links', () {
    test('a web link is an absolute http or https address with a host; anything else is no link', () {
      expect(webLink('https://cbre.com/about'), Uri.parse('https://cbre.com/about'));
      expect(webLink('  http://cbre.com '), Uri.parse('http://cbre.com'));
      expect(webLink(null), isNull);
      expect(webLink(''), isNull);
      expect(webLink('cbre.com'), isNull);
      expect(webLink('/uploads/deck.pdf'), isNull);
      expect(webLink('javascript:alert(1)'), isNull);
      expect(webLink('mailto:a@b.com'), isNull);
      expect(webLink('file:///etc/passwd'), isNull);
    });

    test('the names reserved for examples are placeholders, and nothing real is', () {
      for (final url in [
        'https://example.com',
        'https://example.com/whitepaper.pdf',
        'https://www.example.org/x',
        'http://deck.example.net',
        'https://anything.example',
        'https://nobody.invalid',
      ]) {
        expect(isPlaceholderLink(Uri.parse(url)), isTrue, reason: url);
      }
      for (final url in ['https://cbre.com', 'https://notexample.com', 'https://example.com.au', 'https://cbre.test']) {
        expect(isPlaceholderLink(Uri.parse(url)), isFalse, reason: url);
      }
    });
  });

  group('the saved file name', () {
    final uri = Uri.parse('https://files.test/uploads/abc123.pdf');

    test('is the resource title with the extension its address gives', () {
      expect(resourceFileName(_resource(), uri), 'Benchmark 2026.pdf');
      expect(resourceFileName(_resource(title: 'Q2 deck.pdf'), uri), 'Q2 deck.pdf');
    });

    test('takes the extension from the media type, then from the kind, when the address names none', () {
      final bare = Uri.parse('https://files.test/download?id=9');
      expect(resourceFileName(_resource(), bare, type: 'application/pdf'), 'Benchmark 2026.pdf');
      expect(resourceFileName(_resource(kind: 'PRESENTATION'), bare), 'Benchmark 2026.pptx');
      expect(resourceFileName(_resource(kind: 'RECORDING'), bare), 'Benchmark 2026.mp4');
      expect(resourceFileName(_resource(kind: 'OTHER'), bare), 'Benchmark 2026');
    });

    test("prefers the host's own name, and never carries a path or a reserved character", () {
      expect(resourceFileName(_resource(), uri, disposition: 'attachment; filename="Report v2.pdf"'), 'Report v2.pdf');
      expect(
        resourceFileName(_resource(), uri, disposition: "attachment; filename*=UTF-8''Caf%C3%A9%20menu.pdf"),
        'Café menu.pdf',
      );
      expect(
        resourceFileName(_resource(title: 'Sustainability: panel / Q&A?'), uri),
        'Sustainability_ panel _ Q&A_.pdf',
      );
      expect(
        resourceFileName(_resource(), uri, disposition: 'attachment; filename="../../etc/passwd"'),
        '.._.._etc_passwd',
      );
    });
  });

  group('reading a resource', () {
    test('a file is read in full and named; no ICR session rides along', () async {
      final net = _Net(
        (_) => _bytes(utf8.encode('%PDF-1.4 body'), headers: {Headers.contentTypeHeader: 'application/pdf'}),
      );
      final out = await _downloader(net).fetch(_resource());
      final file = (out as ResourceFileOutcome).file;
      expect(file.fileName, 'Benchmark 2026.pdf');
      expect(file.mimeType, 'application/pdf');
      expect(utf8.decode(file.bytes), '%PDF-1.4 body');
      expect(net.requests.single.uri, Uri.parse('https://files.test/benchmark.pdf'));
      expect(net.requests.single.headers.containsKey('Authorization'), isFalse);
    });

    test("a bare download takes its type from the file's name", () async {
      final net = _Net((_) => _bytes([1, 2, 3], headers: {Headers.contentTypeHeader: 'application/octet-stream'}));
      final out = await _downloader(net).fetch(_resource(url: 'https://files.test/t.xlsx', title: 'Scorecard'));
      final file = (out as ResourceFileOutcome).file;
      expect(file.fileName, 'Scorecard.xlsx');
      expect(file.mimeType, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    });

    test('a web page is not a file: it is reported as a page and nothing is saved', () async {
      final net = _Net(
        (_) => _bytes(utf8.encode('<html></html>'), headers: {Headers.contentTypeHeader: 'text/html; charset=utf-8'}),
      );
      final out = await _downloader(net).fetch(_resource(kind: 'RECORDING', url: 'https://videos.test/watch/9'));
      expect((out as ResourcePageOutcome).page, Uri.parse('https://videos.test/watch/9'));
    });

    test('a page served without a type is told by its first bytes', () async {
      final net = _Net((_) => _bytes(utf8.encode('  <!DOCTYPE html><html><body>Sign in</body></html>')));
      final out = await _downloader(net).fetch(_resource());
      expect(out, isA<ResourcePageOutcome>());
    });

    test('a missing file says it is not there, naming the host and the status', () async {
      final net = _Net(
        (_) =>
            _bytes(utf8.encode('<h1>Not found</h1>'), status: 404, headers: {Headers.contentTypeHeader: 'text/html'}),
      );
      final e = await _refusal(_downloader(net).fetch(_resource()));
      expect(e.message, 'The file is no longer available (files.test returned 404).');
      expect(e.openInstead, isNull);
    });

    test('a refusal, a host in trouble and an unreachable host each say so', () async {
      Future<String> say(ResponseBody Function(RequestOptions) answer) async =>
          (await _refusal(_downloader(_Net(answer)).fetch(_resource()))).message;
      expect(
        await say((_) => _bytes([], status: 403)),
        'files.test does not allow the app to download this file (403).',
      );
      expect(
        await say((_) => _bytes([], status: 503)),
        'files.test had a problem sending the file (503). Try again later.',
      );
      expect(await say((_) => _bytes([], status: 418)), 'files.test refused the download (418).');
      expect(
        await say((o) => throw DioException(requestOptions: o, type: DioExceptionType.connectionError)),
        'Unable to reach files.test. Check your connection and try again.',
      );
      expect(
        await say((o) => throw DioException(requestOptions: o, type: DioExceptionType.connectionTimeout)),
        'Unable to reach files.test. Check your connection and try again.',
      );
    });

    test('an empty file, and a resource with no address, are said so', () async {
      final empty = await _refusal(_downloader(_Net((_) => _bytes([]))).fetch(_resource()));
      expect(empty.message, 'The file is empty.');
      final none = _Net((_) => _bytes([1]));
      final e = await _refusal(_downloader(none).fetch(_resource(url: '')));
      expect(e.message, 'This resource has no file attached yet.');
      expect(none.requests, isEmpty);
    });

    test('a placeholder address (the demo data) is not fetched: it has no real file', () async {
      final net = _Net((_) => _bytes([1]));
      final e = await _refusal(_downloader(net).fetch(_resource(url: 'https://example.com/whitepaper.pdf')));
      expect(e.message, '"Benchmark 2026" has no file yet. Its address is a placeholder.');
      expect(net.requests, isEmpty);
    });

    test('a file too large to hold is left to the browser', () async {
      final net = _Net(
        (_) => _bytes([1], headers: {Headers.contentLengthHeader: '${SystemResourceDownloader.maxBytes + 1}'}),
      );
      final e = await _refusal(
        _downloader(net).fetch(_resource(kind: 'RECORDING', url: 'https://videos.test/forum.mp4')),
      );
      expect(e.message, startsWith('The file is '));
      expect(e.message, endsWith('MB, too large to save from the app.'));
      expect(e.openInstead, Uri.parse('https://videos.test/forum.mp4'));
    });
  });

  group('the Download button', () {
    Future<(FakeResourceDownloader, List<Uri>)> pump(
      WidgetTester tester, {
      ChapterResource? resource,
      FakeResourceDownloader? downloader,
    }) async {
      final fake = downloader ?? FakeResourceDownloader();
      final opened = <Uri>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: ResourceRow(
              resource: resource ?? _resource(),
              downloader: fake,
              opener: (context, uri) async => opened.add(uri),
            ),
          ),
        ),
      );
      return (fake, opened);
    }

    testWidgets('a row has the tag, the title and kind, and an outlined Download; no external-link glyph', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('PDF'), findsOneWidget);
      expect(find.text('Benchmark 2026'), findsOneWidget);
      expect(find.text('Whitepaper · 2 MB'), findsOneWidget);
      expect(find.text('Download'), findsOneWidget);
      expect(find.byIcon(LucideIcons.download), findsOneWidget);
      expect(find.byIcon(LucideIcons.externalLink), findsNothing);
    });

    testWidgets('a recording is labelled Download too, as on the website', (tester) async {
      await pump(
        tester,
        resource: _resource(kind: 'RECORDING', title: 'Forum', sizeLabel: '58 min'),
      );
      expect(find.text('MP4'), findsOneWidget);
      expect(find.text('Recording · 58 min'), findsOneWidget);
      expect(find.text('Download'), findsOneWidget);
    });

    testWidgets('the row itself does nothing: Download is its only control', (tester) async {
      final (fake, opened) = await pump(tester);
      await tester.tap(find.text('Benchmark 2026'));
      await tester.pump();
      expect(fake.fetched, isEmpty);
      expect(opened, isEmpty);
    });

    testWidgets('Download reads the file, offers the Save as sheet and says it is saved', (tester) async {
      final (fake, opened) = await pump(tester);
      await tester.tap(find.text('Download'));
      await tester.pump();
      await tester.pump();
      expect(fake.fetched.single.id, 'r1');
      expect(fake.saved.single.fileName, 'Benchmark 2026.pdf');
      expect(find.text('Saved Benchmark 2026.pdf.'), findsOneWidget);
      expect(opened, isEmpty);
    });

    testWidgets('cancelling the Save as sheet says nothing', (tester) async {
      final fake = FakeResourceDownloader()..saves = false;
      await pump(tester, downloader: fake);
      await tester.tap(find.text('Download'));
      await tester.pump();
      await tester.pump();
      expect(fake.saved, hasLength(1));
      expect(find.textContaining('Saved'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('while the file is coming the button is busy and a second tap is not sent', (tester) async {
      final gate = Completer<void>();
      final fake = FakeResourceDownloader()..gate = gate.future;
      await pump(tester, downloader: fake);
      await tester.tap(find.text('Download'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Download'));
      await tester.pump();
      expect(fake.fetched, hasLength(1));
      gate.complete();
      await tester.pump();
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(fake.saved, hasLength(1));
    });

    testWidgets('a download that fails says why, in the app, and saves nothing', (tester) async {
      final fake = FakeResourceDownloader()
        ..answers['r1'] = const ResourceDownloadException('The file is no longer available (files.test returned 404).');
      final (_, opened) = await pump(tester, downloader: fake);
      await tester.tap(find.text('Download'));
      await tester.pump();
      await tester.pump();
      expect(find.text('The file is no longer available (files.test returned 404).'), findsOneWidget);
      expect(fake.saved, isEmpty);
      expect(opened, isEmpty);
      expect(find.text('Download'), findsOneWidget);
    });

    testWidgets('any other failure still says so', (tester) async {
      final fake = FakeResourceDownloader()..answers['r1'] = StateError('boom');
      await pump(tester, downloader: fake);
      await tester.tap(find.text('Download'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Unable to download "Benchmark 2026". Try again.'), findsOneWidget);
    });

    testWidgets('a file too large for the app offers the browser, only when asked', (tester) async {
      final page = Uri.parse('https://videos.test/forum.mp4');
      final fake = FakeResourceDownloader()
        ..answers['r1'] = ResourceDownloadException(
          'The file is 400 MB, too large to save from the app.',
          openInstead: page,
        );
      final (_, opened) = await pump(
        tester,
        resource: _resource(kind: 'RECORDING'),
        downloader: fake,
      );
      await tester.tap(find.text('Download'));
      await tester.pump();
      await tester.pump();
      expect(find.text('The file is 400 MB, too large to save from the app.'), findsOneWidget);
      expect(opened, isEmpty);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Open'));
      await tester.pump();
      expect(opened, [page]);
    });

    testWidgets('a recording that is a web page is opened, as the website opens its link', (tester) async {
      final page = Uri.parse('https://videos.test/watch/9');
      final fake = FakeResourceDownloader()..answers['r1'] = ResourcePageOutcome(page);
      final (_, opened) = await pump(
        tester,
        resource: _resource(kind: 'RECORDING'),
        downloader: fake,
      );
      await tester.tap(find.text('Download'));
      await tester.pump();
      await tester.pump();
      expect(opened, [page]);
      expect(fake.saved, isEmpty);
    });

    testWidgets('any other kind that is a web page says so, and opens it only on Open page', (tester) async {
      final page = Uri.parse('https://drive.test/folder/9');
      final fake = FakeResourceDownloader()..answers['r1'] = ResourcePageOutcome(page);
      final (_, opened) = await pump(tester, downloader: fake);
      await tester.tap(find.text('Download'));
      await tester.pump();
      await tester.pump();
      expect(find.text('"Benchmark 2026" is a web page, not a file you can save.'), findsOneWidget);
      expect(opened, isEmpty);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Open Page'));
      await tester.pump();
      expect(opened, [page]);
    });
  });

  group('sponsors', () {
    Future<List<Uri>> pump(WidgetTester tester, List<ChapterSponsor> sponsors) async {
      final opened = <Uri>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: SponsorsSection(sponsors: sponsors, onOpen: opened.add),
          ),
        ),
      );
      return opened;
    }

    testWidgets("a sponsor's website opens, as on the website", (tester) async {
      final opened = await pump(tester, const [
        ChapterSponsor(id: 's1', name: 'CBRE', tier: 'Gold', url: 'https://cbre.com/in'),
      ]);
      await tester.tap(find.text('CBRE'));
      expect(opened, [Uri.parse('https://cbre.com/in')]);
    });

    testWidgets('a sponsor with no website, or an address that is not one, is a plain tile', (tester) async {
      final opened = await pump(tester, const [
        ChapterSponsor(id: 's1', name: 'Sodexo India'),
        ChapterSponsor(id: 's2', name: 'Schneider Electric', url: 'schneider'),
      ]);
      await tester.tap(find.text('Sodexo India'));
      await tester.tap(find.text('Schneider Electric'));
      await tester.pump();
      expect(opened, isEmpty);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a placeholder website (the demo data) is not opened: the tap says there is none yet', (tester) async {
      final opened = await pump(tester, const [
        ChapterSponsor(id: 's1', name: 'CBRE', tier: 'Gold', url: 'https://example.com'),
      ]);
      await tester.tap(find.text('CBRE'));
      await tester.pump();
      expect(opened, isEmpty);
      expect(find.text('CBRE has not shared its website yet.'), findsOneWidget);
    });
  });
}
