import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/util/links.dart' show showMessage;
import '../../library/library_models.dart' show DocumentBytes, PreviewKind, previewKindFor;
import '../../library/widgets/document_viewer_screen.dart';
import '../job_links.dart';
import 'hiring_repository.dart';

/// Opens an applicant's résumé in the app, as the website's `PrivateFileViewer` does. A résumé is a PRIVATE upload:
/// the API streams it only to a signed-in member of the hiring team (`uploads.controller.ts`), so a link handed to
/// the phone's browser, which has no session, is refused. The bytes are read with the session and drawn in the
/// app's document viewer, kept out of screenshots like any member's private file.
///
/// A source with no file behind the link (the sample content) opens the link as it is.
Future<void> openApplicantResume(
  BuildContext context, {
  required HiringRepository repository,
  required String url,
  required JobLinks links,
}) async {
  final List<int> bytes;
  try {
    bytes = await repository.fileBytes(url);
  } on UnsupportedError {
    final uri = Uri.tryParse(url);
    if (uri != null && context.mounted) await links.openUri(context, uri);
    return;
  } catch (_) {
    if (context.mounted) showMessage(context, "Couldn't open the résumé. Try again.");
    return;
  }
  if (!context.mounted) return;
  final name = resumeFileName(url);
  final kind = previewKindFor('', name);
  if (kind == PreviewKind.none) {
    showMessage(context, "This résumé's file type can't be shown in the app.");
    return;
  }
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => DocumentViewerScreen(
        file: DocumentBytes(bytes: Uint8List.fromList(bytes), fileName: name, mimeType: ''),
        kind: kind,
      ),
    ),
  );
}

/// "resume.pdf": the name the viewer reads the file's kind from (the website names it the same way).
String resumeFileName(String url) {
  final path = Uri.tryParse(url)?.path ?? url;
  final ext = RegExp(r'\.([a-z0-9]+)$', caseSensitive: false).firstMatch(path)?.group(1)?.toLowerCase();
  return 'resume.${ext ?? 'pdf'}';
}
