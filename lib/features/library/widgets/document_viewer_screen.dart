import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../csv_rows.dart';
import '../library_device.dart';
import '../library_models.dart';
import '../office/office_models.dart';
import '../pdf_engine.dart';
import '../preview_runner.dart';
import 'data_grid.dart';
import 'office_views.dart';

/// A file read in the app: a PDF's pages, a zoomable picture, plain text, a CSV or Excel sheet as a grid, a Word
/// document's text and tables, a presentation's slide text, or the files inside a ZIP (each opens in this viewer
/// in turn). Used for library documents, applicants' résumés and course brochures.
///
/// Its bar has **Download** (the phone's "Save as") and **Share** (the file to another app), as the website's
/// viewer lets a file be downloaded; screenshots and screen recording are allowed (owner, 5 Nov 2026: the
/// view-only library of 28 Oct, with its screenshot lock, was taken off). A library document passes
/// [onDownload] and [onShare] so the file is fetched as a download the API counts; anything else saves and sends
/// the bytes it shows.
class DocumentViewerScreen extends StatelessWidget {
  const DocumentViewerScreen({
    super.key,
    required this.file,
    required this.kind,
    this.pdf = const PlatformPdfEngine(),
    this.runner = runInBackground,
    this.device = const SystemLibraryDevice(),
    this.onDownload,
    this.onShare,
  });

  final DocumentBytes file;

  /// How to draw [file] (`LibraryFile.previewKind`).
  final PreviewKind kind;

  /// Draws a PDF's pages; the phone's own renderer unless a test gives another.
  final PdfEngine pdf;

  /// Runs the reading of an Office or ZIP file off the screen's thread.
  final PreviewRunner runner;

  /// Saves and shares the file shown when [onDownload] or [onShare] is not given. Tests give their own.
  final LibraryDevice device;

  /// Download in place of saving the bytes shown (a library document: the API counts it).
  final Future<void> Function()? onDownload;

  /// Share in place of sending the bytes shown.
  final Future<void> Function()? onShare;

  static const _pdfBackdrop = Color(0xFF3B3E42);

  bool get _dark => kind == PreviewKind.pdf || kind == PreviewKind.image || kind == PreviewKind.none;

  Future<void> _download(BuildContext context) async {
    final go = onDownload;
    if (go != null) return go();
    final messenger = ScaffoldMessenger.maybeOf(context);
    final saved = await device.save(file);
    if (saved) {
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Saved ${file.fileName}.')));
    }
  }

  Future<void> _share() => onShare?.call() ?? device.shareFile(file);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _dark ? (kind == PreviewKind.pdf ? _pdfBackdrop : Colors.black) : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          file.fileName,
          style: const TextStyle(fontSize: 14, color: Colors.white),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          ViewerAction(tooltip: 'Download', icon: LucideIcons.download, onPressed: () => _download(context)),
          ViewerAction(tooltip: 'Share', icon: LucideIcons.share2, onPressed: _share),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    switch (kind) {
      case PreviewKind.pdf:
        return _PdfBody(bytes: file.bytes, engine: pdf);
      case PreviewKind.image:
        return _ImageBody(bytes: file.bytes);
      case PreviewKind.text:
        return ViewerText(_decode(file.bytes));
      case PreviewKind.table:
        return _CsvBody(bytes: file.bytes);
      case PreviewKind.word || PreviewKind.sheets || PreviewKind.slides || PreviewKind.archive:
        return OfficeBody(
          bytes: file.bytes,
          fileName: file.fileName,
          kind: kind,
          runner: runner,
          onOpenFile: (name, bytes) => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => DocumentViewerScreen(
                file: DocumentBytes(bytes: bytes, fileName: name, mimeType: ''),
                kind: previewKindFor('', name),
                pdf: pdf,
                runner: runner,
                device: device,
              ),
            ),
          ),
        );
      case PreviewKind.none:
        return const ViewerMessage(
          icon: LucideIcons.eyeOff,
          text: "This kind of file can't be previewed in the app. Download it to open it.",
          dark: true,
        );
    }
  }
}

/// A button of the viewer's bar that shows a spinner while what it started runs (a download can take a moment).
class ViewerAction extends StatefulWidget {
  const ViewerAction({super.key, required this.tooltip, required this.icon, required this.onPressed});

  final String tooltip;
  final IconData icon;
  final Future<void> Function() onPressed;

  @override
  State<ViewerAction> createState() => _ViewerActionState();
}

class _ViewerActionState extends State<ViewerAction> {
  bool _busy = false;

  Future<void> _run() async {
    setState(() => _busy = true);
    try {
      await widget.onPressed();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)
          ?..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Something went wrong. Try again.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: widget.tooltip,
    onPressed: _busy ? null : _run,
    icon: _busy
        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : Icon(widget.icon, size: 20, color: Colors.white),
  );
}

// ---------------------------------------------------------------------------
// Image
// ---------------------------------------------------------------------------

class _ImageBody extends StatelessWidget {
  const _ImageBody({required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: InteractiveViewer(
        maxScale: 5,
        child: Image.memory(
          bytes,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) =>
              const ViewerMessage(icon: LucideIcons.imageOff, text: "This image can't be shown.", dark: true),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Text and CSV
// ---------------------------------------------------------------------------

String _decode(Uint8List bytes) => utf8.decode(bytes, allowMalformed: true);

class _CsvBody extends StatelessWidget {
  const _CsvBody({required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    final csv = parseCsv(_decode(bytes), maxRows: OfficeLimits.maxRows);
    if (csv.rows.isEmpty) {
      return const ViewerMessage(icon: LucideIcons.table, text: 'This file is empty.');
    }
    final wide = csv.columns > OfficeLimits.maxColumns;
    final rows = wide ? [for (final r in csv.rows) r.take(OfficeLimits.maxColumns).toList()] : csv.rows;
    return Column(
      children: [
        Expanded(child: DataGrid(rows: rows, headerRow: true)),
        if (csv.truncated || wide)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Only the first part of this file is shown.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// PDF
// ---------------------------------------------------------------------------

class _PdfBody extends StatefulWidget {
  const _PdfBody({required this.bytes, required this.engine});

  final Uint8List bytes;
  final PdfEngine engine;

  @override
  State<_PdfBody> createState() => _PdfBodyState();
}

class _PdfBodyState extends State<_PdfBody> {
  static const _zooms = [1.0, 1.5, 2.0, 3.0];
  static const _gap = 8.0;
  static const _margin = 8.0;

  PdfDocumentHandle? _doc;
  String? _problem;
  bool _gone = false;
  int _zoomStep = 0;
  int _page = 1;
  double _viewWidth = 0;
  final _scroll = ScrollController();

  double get _zoom => _zooms[_zoomStep];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_track);
    unawaited(_open());
  }

  Future<void> _open() async {
    try {
      final doc = await widget.engine.open(widget.bytes);
      if (_gone) {
        unawaited(doc.close());
        return;
      }
      setState(() => _doc = doc);
    } on PdfProblem catch (e) {
      if (!_gone) setState(() => _problem = e.message);
    } catch (_) {
      if (!_gone) setState(() => _problem = "This PDF can't be shown.");
    }
  }

  @override
  void dispose() {
    _gone = true;
    _scroll.dispose();
    final doc = _doc;
    if (doc != null) unawaited(doc.close());
    super.dispose();
  }

  double _pageHeight(PdfDocumentHandle doc, int i, double width) {
    final s = doc.pageSizes[i];
    return width * s.height / s.width;
  }

  /// The page under the top third of the screen.
  void _track() {
    final doc = _doc;
    if (doc == null || !_scroll.hasClients || _viewWidth <= 0) return;
    final width = _viewWidth * _zoom - _margin * 2;
    final probe = _scroll.offset + _scroll.position.viewportDimension / 3;
    var top = _margin;
    var page = doc.pageCount;
    for (var i = 0; i < doc.pageCount; i++) {
      top += _pageHeight(doc, i, width) + _gap;
      if (probe < top) {
        page = i + 1;
        break;
      }
    }
    if (page != _page) setState(() => _page = page);
  }

  void _zoomBy(int step) {
    final next = (_zoomStep + step).clamp(0, _zooms.length - 1);
    if (next != _zoomStep) setState(() => _zoomStep = next);
  }

  @override
  Widget build(BuildContext context) {
    final problem = _problem;
    if (problem != null) return ViewerMessage(icon: LucideIcons.fileX, text: problem, dark: true);
    final doc = _doc;
    if (doc == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    if (doc.pageCount == 0) {
      return const ViewerMessage(icon: LucideIcons.fileX, text: 'This PDF has no pages.', dark: true);
    }
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              _viewWidth = box.maxWidth;
              final width = box.maxWidth * _zoom - _margin * 2;
              final pixels = (width * dpr).round().clamp(200, 2600);
              Widget pages = ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.symmetric(horizontal: _margin, vertical: _margin),
                addAutomaticKeepAlives: false,
                itemCount: doc.pageCount,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: _gap),
                  child: _PdfPage(
                    key: ValueKey('page-$i-$pixels'),
                    doc: doc,
                    index: i,
                    width: width,
                    height: _pageHeight(doc, i, width),
                    pixels: pixels,
                  ),
                ),
              );
              if (_zoom > 1) {
                pages = SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(width: box.maxWidth * _zoom, child: pages),
                );
              }
              return pages;
            },
          ),
        ),
        Container(
          color: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          height: 44,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Zoom Out',
                icon: const Icon(LucideIcons.zoomOut, size: 20, color: Colors.white),
                onPressed: _zoomStep == 0 ? null : () => _zoomBy(-1),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Page $_page of ${doc.pageCount}',
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                ),
              ),
              IconButton(
                tooltip: 'Zoom In',
                icon: const Icon(LucideIcons.zoomIn, size: 20, color: Colors.white),
                onPressed: _zoomStep == _zooms.length - 1 ? null : () => _zoomBy(1),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One page: a white sheet of the right proportions while it is drawn, then the drawing. A page that
/// scrolls out of reach is let go of and drawn again when it returns.
class _PdfPage extends StatefulWidget {
  const _PdfPage({
    super.key,
    required this.doc,
    required this.index,
    required this.width,
    required this.height,
    required this.pixels,
  });

  final PdfDocumentHandle doc;
  final int index;
  final double width;
  final double height;
  final int pixels;

  @override
  State<_PdfPage> createState() => _PdfPageState();
}

class _PdfPageState extends State<_PdfPage> {
  late final Future<Uint8List> _png = widget.doc.render(widget.index, widget.pixels);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Color(0x66000000), blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: FutureBuilder<Uint8List>(
          future: _png,
          builder: (context, snap) {
            if (snap.hasError) {
              return const Center(
                child: Text("This page can't be shown.", style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              );
            }
            final png = snap.data;
            if (png == null) {
              return const Center(
                child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            return Image.memory(png, fit: BoxFit.fill, gaplessPlayback: true);
          },
        ),
      ),
    );
  }
}
