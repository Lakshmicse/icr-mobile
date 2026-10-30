import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/util/links.dart' show SiteRoutes;
import 'api_library_repository.dart';
import 'library_models.dart';

/// Where the Library screens reach the phone: choosing files to share, and opening a page. Behind one seam,
/// so a test sees what would have happened and gives the files the picker would have.
///
/// **There is no way to take a document out of the app through here, on purpose** (owner's call, 28 Oct
/// 2026: the Digital Library on a phone is view-only). A document is fetched with the member's own session
/// (the API's download route needs their bearer token), drawn by the in-app viewer and dropped with it. It
/// is never saved, shared or handed to another app.
abstract class LibraryDevice {
  const LibraryDevice();

  /// Asks the person to choose files to share; empty when they choose none.
  Future<List<PickedFile>> pickFiles();

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
