import 'package:file_picker/file_picker.dart';

import 'offerings_repository.dart';

/// What a file chooser gives back: null when the mentor backed out. The panel is handed one
/// (`OfferingsPanel.pickFile`) so a test can stand in for the phone's file chooser.
typedef OfferingFilePicker = Future<PickedUpload?> Function({required bool imageOnly});

/// A resource's file takes what the API's `mentor-resource` upload takes: a PDF or an image (10 MB at most).
const resourceExtensions = ['pdf', 'png', 'jpg', 'jpeg', 'webp'];

/// A cover is an image.
const coverExtensions = ['png', 'jpg', 'jpeg', 'webp'];

/// The API stops a file here (`MAX_BYTES`, 10 MB).
const maxUploadBytes = 10 * 1024 * 1024;

/// The type of a picked file, by its extension (the API stores it as the type it accepts).
String? mimeOfName(String name) {
  final dot = name.lastIndexOf('.');
  if (dot < 0) return null;
  return switch (name.substring(dot + 1).toLowerCase()) {
    'pdf' => 'application/pdf',
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    'webp' => 'image/webp',
    _ => null,
  };
}

/// Asks the phone for a PDF or image (an image only for a cover) and reads it.
Future<PickedUpload?> pickOfferingFile({required bool imageOnly}) async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: imageOnly ? coverExtensions : resourceExtensions,
  );
  if (file == null) return null;
  return PickedUpload(bytes: await file.readAsBytes(), name: file.name, mimeType: mimeOfName(file.name));
}

/// Why a picked file would be refused before it is sent, or null.
String? uploadProblem(PickedUpload file, {required bool imageOnly}) {
  final allowed = imageOnly ? coverExtensions : resourceExtensions;
  final dot = file.name.lastIndexOf('.');
  final ext = dot < 0 ? '' : file.name.substring(dot + 1).toLowerCase();
  if (!allowed.contains(ext)) {
    return imageOnly ? 'A cover is a PNG, JPG or WebP image.' : 'A resource is a PDF or an image (PNG, JPG, WebP).';
  }
  if (file.bytes.length > maxUploadBytes) return 'That file is over 10 MB.';
  return null;
}
