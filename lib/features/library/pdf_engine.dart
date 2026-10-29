import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Why a PDF could not be shown, in words for the reader.
class PdfProblem implements Exception {
  const PdfProblem(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A PDF held in memory and opened for reading: how many pages it has, how big each is, and each page
/// drawn as a PNG at the width asked for.
abstract class PdfDocumentHandle {
  /// Every page's own size (points), so the viewer can lay the pages out before any is drawn.
  List<Size> get pageSizes;

  int get pageCount => pageSizes.length;

  /// Page [index] (from 0) drawn [widthPx] pixels wide, as PNG bytes.
  Future<Uint8List> render(int index, int widthPx);

  /// Lets go of the document. Safe to call twice.
  Future<void> close();
}

/// Opens a PDF for the viewer. The library never saves a document, so a PDF is read from the bytes in
/// memory and drawn here: it is not handed to another app.
abstract class PdfEngine {
  /// Throws [PdfProblem] when the file cannot be shown (damaged, password protected, no renderer).
  Future<PdfDocumentHandle> open(Uint8List bytes);
}

/// Android's own `PdfRenderer`, through `PdfViewerChannel.kt`. Other platforms have no renderer wired.
class PlatformPdfEngine implements PdfEngine {
  const PlatformPdfEngine();

  static const _channel = MethodChannel('org.icr.icr_mobile/pdf');

  @override
  Future<PdfDocumentHandle> open(Uint8List bytes) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw const PdfProblem("PDFs can't be previewed on this device yet.");
    }
    try {
      final out = await _channel.invokeMapMethod<String, Object?>('open', {'bytes': bytes});
      final id = out?['id'] as String?;
      final sizes = (out?['sizes'] as List?) ?? const [];
      if (id == null) throw const PdfProblem("This PDF can't be shown.");
      return _PlatformPdf(id, [
        for (final s in sizes)
          Size(
            ((s as List)[0] as num).toDouble().clamp(1, double.infinity),
            (s[1] as num).toDouble().clamp(1, double.infinity),
          ),
      ]);
    } on PlatformException catch (e) {
      throw PdfProblem(
        e.code == 'password'
            ? "This PDF is password protected, so it can't be previewed."
            : "This PDF can't be shown. It may be damaged.",
      );
    } on MissingPluginException {
      throw const PdfProblem("PDFs can't be previewed in this version of the app.");
    }
  }
}

class _PlatformPdf extends PdfDocumentHandle {
  _PlatformPdf(this.id, this.pageSizes);

  final String id;
  bool _closed = false;

  @override
  final List<Size> pageSizes;

  @override
  Future<Uint8List> render(int index, int widthPx) async {
    if (_closed) throw const PdfProblem('This page is closed.');
    try {
      final png = await PlatformPdfEngine._channel.invokeMethod<Uint8List>('render', {
        'id': id,
        'page': index,
        'width': widthPx,
      });
      if (png == null) throw const PdfProblem("This page can't be shown.");
      return png;
    } on PlatformException {
      throw const PdfProblem("This page can't be shown.");
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    try {
      await PlatformPdfEngine._channel.invokeMethod<void>('close', {'id': id});
    } on PlatformException {
      // Already gone.
    } on MissingPluginException {
      // Nothing to let go of.
    }
  }
}
