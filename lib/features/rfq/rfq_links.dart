import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/util/links.dart' show SiteRoutes;

/// Where a tap on the requirements screens leaves the app (the website, for
/// files and for what the app does not do). Behind one seam, so a test sees
/// where a control would have gone.
abstract class RfqLinks {
  const RfqLinks();

  /// Opens [uri] outside the app; false when nothing could open it.
  Future<bool> open(Uri uri);

  /// Hands a file saved on the phone to the phone's own viewers and share sheet (a supplier's quotation is a
  /// private upload: the app fetches it with the person's session and passes it on from here). False when
  /// nothing could take it.
  Future<bool> shareFile(String path, String name) async => false;

  /// Asks the person to choose files from the phone, for an attachment; empty when they choose none.
  Future<List<PickedRfqFile>> pickFiles({bool images = false}) async => const [];
}

/// A file chosen on the phone, read into memory to be uploaded.
class PickedRfqFile {
  const PickedRfqFile({required this.name, required this.bytes, this.mimeType});

  final String name;
  final List<int> bytes;
  final String? mimeType;

  int get size => bytes.length;
}

/// The clock the requirements screens read deadlines against, so a golden can
/// hold it still.
class RfqClock {
  RfqClock._();

  static DateTime Function() now = DateTime.now;

  static void reset() => now = DateTime.now;
}

class SystemRfqLinks extends RfqLinks {
  const SystemRfqLinks();

  @override
  Future<bool> open(Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

  @override
  Future<bool> shareFile(String path, String name) async {
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path, name: name)],
        subject: name,
      ),
    );
    return result.status != ShareResultStatus.unavailable;
  }

  @override
  Future<List<PickedRfqFile>> pickFiles({bool images = false}) async {
    final files = await FilePicker.pickFiles(type: images ? FileType.image : FileType.any);
    return [for (final f in files) PickedRfqFile(name: f.name, bytes: await f.readAsBytes())];
  }
}

extension RfqLinksOpening on RfqLinks {
  /// Opens [uri] — the app's own screen when it has one for that page of the
  /// website — and says so when the phone has nothing to open it with.
  Future<void> openUri(BuildContext context, Uri uri) async {
    final inApp = SiteRoutes.inApp(uri);
    if (inApp != null) return inApp(context);
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await open(uri);
    } catch (_) {
      // Treated as "could not open" below.
    }
    if (!opened) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text("Couldn't open ${uri.host}${uri.path}")));
    }
  }
}
