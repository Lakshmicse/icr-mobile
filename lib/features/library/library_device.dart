import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/util/links.dart' show SiteRoutes;
import 'api_library_repository.dart';
import 'library_models.dart';

/// Where the Library screens reach the phone: choosing files to share, saving and sending a document's file, and
/// opening a page. Behind one seam, so a test sees what would have happened and gives the files the picker would
/// have.
///
/// A document's file is fetched with the member's own session (the API's download route needs their bearer token)
/// and may be saved to the phone or sent on, as the website lets it be downloaded (owner, 5 Nov 2026: the
/// view-only library of 28 Oct, with its screenshot lock, was taken off).
abstract class LibraryDevice {
  const LibraryDevice();

  /// Asks the person to choose files to share; empty when they choose none.
  Future<List<PickedFile>> pickFiles();

  /// Opens [uri] outside the app; false when nothing could open it.
  Future<bool> open(Uri uri);

  /// Saves [file] where the person chooses (the system "Save as" sheet); false when they cancel.
  Future<bool> save(DocumentBytes file);

  /// Hands [file] to the phone's share sheet (another app, a chat, Drive…).
  Future<void> shareFile(DocumentBytes file);
}

/// The MIME type to hand the phone with a file: its own, else read from its name.
String _mimeOf(DocumentBytes file) => file.mimeType.isNotEmpty
    ? file.mimeType
    : ApiLibraryRepository.mimeForName(file.fileName) ?? 'application/octet-stream';

class SystemLibraryDevice extends LibraryDevice {
  const SystemLibraryDevice();

  @override
  Future<List<PickedFile>> pickFiles() async {
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: LibraryLimits.extensions);
    return [
      for (final f in files)
        PickedFile(name: f.name, bytes: await f.readAsBytes(), mimeType: ApiLibraryRepository.mimeForName(f.name)),
    ];
  }

  @override
  Future<bool> open(Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

  @override
  Future<bool> save(DocumentBytes file) async {
    final saved = await FilePicker.saveFile(
      fileName: file.fileName,
      bytes: file.bytes,
      mimeType: _mimeOf(file),
      dialogTitle: 'Save ${file.fileName}',
    );
    return saved != null;
  }

  @override
  Future<void> shareFile(DocumentBytes file) => SharePlus.instance
      .share(
        ShareParams(
          files: [XFile.fromData(file.bytes, name: file.fileName, mimeType: _mimeOf(file))],
          fileNameOverrides: [file.fileName],
          subject: file.fileName,
        ),
      )
      .then((_) {});
}

extension LibraryDeviceSite on LibraryDevice {
  /// A page of the ICR website: the app's own screen (or its web view) when it has one, else [open].
  Future<void> openPage(BuildContext context, Uri uri) async {
    final inApp = SiteRoutes.inApp(uri);
    if (inApp != null) return inApp(context);
    await open(uri);
  }
}
