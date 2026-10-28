import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/util/links.dart' show SiteRoutes;
import 'api_library_repository.dart';
import 'library_models.dart';

/// Where the Library screens reach the phone: choosing files to share, handing a downloaded file to the
/// phone's own apps, and opening a page. Behind one seam, so a test sees what would have happened and
/// gives the files the picker would have.
///
/// Why a file is handed over instead of opened by address: the API's `GET /documents/:id/download`
/// needs the member's bearer token and the stored file is private (`/uploads/<name>` refuses anyone but
/// its uploader), so a browser given the link would be refused. The app fetches the bytes with its own
/// session and passes them to the phone's share sheet ("Save to Files", "Open in…").
abstract class LibraryDevice {
  const LibraryDevice();

  /// Asks the person to choose files to share; empty when they choose none.
  Future<List<PickedFile>> pickFiles();

  /// Hands a downloaded file to the phone: its share sheet saves it or opens it in another app. False when
  /// nothing could take it.
  Future<bool> handOver(DocumentBytes file);

  /// Opens [uri] outside the app; false when nothing could open it.
  Future<bool> open(Uri uri);
}

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
  Future<bool> handOver(DocumentBytes file) async {
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(file.bytes, name: file.fileName, mimeType: file.mimeType)],
        fileNameOverrides: [file.fileName],
        subject: file.fileName,
      ),
    );
    return result.status != ShareResultStatus.unavailable;
  }

  @override
  Future<bool> open(Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);
}

extension LibraryDeviceSite on LibraryDevice {
  /// A page of the ICR website: the app's own screen (or its web view) when it has one, else [open].
  Future<void> openPage(BuildContext context, Uri uri) async {
    final inApp = SiteRoutes.inApp(uri);
    if (inApp != null) return inApp(context);
    await open(uri);
  }
}
