import 'package:file_picker/file_picker.dart';

import '../account_models.dart';

/// Chooses a picture (or, for a credential's evidence, a scan) on the phone.
/// Null when the person backs out. Screens take one of these in their
/// constructor so a test can hand in a file without a platform picker.
typedef PhotoPicker = Future<PickedPhoto?> Function();

/// The most a picture may weigh, as the website's uploader: 5 MB.
const maxPhotoBytes = 5 * 1024 * 1024;

/// What the API accepts for a credential's evidence: a PDF or a picture, 10 MB.
const maxEvidenceBytes = 10 * 1024 * 1024;

/// The sentence for a file that is too heavy, or null when it is fine.
String? photoProblem(PickedPhoto file, {int max = maxPhotoBytes}) {
  if (file.bytes.length <= max) return null;
  final mb = max ~/ (1024 * 1024);
  return 'That file is too big. Choose one under $mb MB.';
}

/// The phone's own picture chooser (the `file_picker` package, the system photo
/// picker on Android and iOS).
Future<PickedPhoto?> pickImageFromDevice() async {
  final file = await FilePicker.pickFile(type: FileType.image);
  if (file == null) return null;
  return PickedPhoto(bytes: await file.readAsBytes(), name: file.name);
}

/// A PDF or a picture of a certificate.
Future<PickedPhoto?> pickEvidenceFromDevice() async {
  final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'webp']);
  if (file == null) return null;
  return PickedPhoto(bytes: await file.readAsBytes(), name: file.name);
}
