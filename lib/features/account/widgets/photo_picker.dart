import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

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
  return 'The file is too large. Choose one under $mb MB.';
}

/// The longest side, in pixels, a picture is kept to when it has to be shrunk to be sent.
const photoMaxSide = 1600;

/// The types the API takes for a picture, by extension.
const _uploadableTypes = {'png', 'jpg', 'jpeg', 'webp'};

/// [file] as it should be sent. A picture already within [max] bytes, in a type the API takes, goes as it is. A
/// camera's picture is often 5 to 15 MB, and one from an iPhone may be HEIC, which the API refuses; the website's
/// uploader crops and shrinks before it sends, so the app does the same rather than turn a photo away for its weight:
/// the picture is decoded at no more than [side] pixels on its longer side and sent as a PNG, a little smaller each
/// time until it is within [max]. A file that cannot be read as a picture comes back unchanged (and is refused by
/// [photoProblem] if it is too heavy).
Future<PickedPhoto> fitForUpload(PickedPhoto file, {int max = maxPhotoBytes, int side = photoMaxSide}) async {
  final dot = file.name.lastIndexOf('.');
  final ext = dot < 0 ? '' : file.name.substring(dot + 1).toLowerCase();
  if (file.bytes.length <= max && _uploadableTypes.contains(ext)) return file;
  try {
    final source = file.bytes is Uint8List ? file.bytes as Uint8List : Uint8List.fromList(file.bytes);
    final buffer = await ui.ImmutableBuffer.fromUint8List(source);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    try {
      final wide = descriptor.width >= descriptor.height;
      var longest = math.min(side, math.max(descriptor.width, descriptor.height));
      for (var attempt = 0; attempt < 5 && longest >= 200; attempt++) {
        // One dimension only, so the picture keeps its proportions whatever its orientation.
        final codec = await descriptor.instantiateCodec(
          targetWidth: wide ? longest : null,
          targetHeight: wide ? null : longest,
        );
        final frame = await codec.getNextFrame();
        final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
        frame.image.dispose();
        codec.dispose();
        if (data == null) break;
        final png = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        if (png.length <= max) {
          final stem = dot < 0 ? file.name : file.name.substring(0, dot);
          return PickedPhoto(bytes: png, name: '${stem.isEmpty ? 'photo' : stem}.png', mimeType: 'image/png');
        }
        longest = (longest * 0.75).round();
      }
    } finally {
      descriptor.dispose();
      buffer.dispose();
    }
  } catch (_) {
    // Not a picture the phone can decode: sent (or refused for its weight) as chosen.
  }
  return file;
}

/// The phone's own picture chooser (the `file_picker` package, the system photo
/// picker on Android and iOS). A picture too heavy for the API, or in a format it
/// does not take, is shrunk first ([fitForUpload]).
Future<PickedPhoto?> pickImageFromDevice() async {
  final file = await FilePicker.pickFile(type: FileType.image);
  if (file == null) return null;
  return fitForUpload(PickedPhoto(bytes: await file.readAsBytes(), name: file.name));
}

/// A PDF or a picture of a certificate.
Future<PickedPhoto?> pickEvidenceFromDevice() async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
  );
  if (file == null) return null;
  return PickedPhoto(bytes: await file.readAsBytes(), name: file.name);
}
