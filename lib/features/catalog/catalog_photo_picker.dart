import 'package:file_picker/file_picker.dart';

import '../account/account_models.dart' show PickedPhoto;
import 'catalog_words.dart';

/// What a product photo may be (`ProductPhotoField`): a PNG, JPG or WEBP up to 2 MB.
const catalogPhotoExtensions = ['png', 'jpg', 'jpeg', 'webp'];
const catalogPhotoMaxBytes = 2 * 1024 * 1024;

/// Where the product editor reaches the phone's photos. Behind one seam, so a test hands the editor the photo the
/// chooser would have.
abstract class CatalogPhotoPicker {
  const CatalogPhotoPicker();

  /// Asks for one picture; null when the person backs out.
  Future<PickedPhoto?> pick();
}

class SystemCatalogPhotoPicker extends CatalogPhotoPicker {
  const SystemCatalogPhotoPicker();

  @override
  Future<PickedPhoto?> pick() async {
    // file_picker 13: `pickFile` is the single pick and answers null when nothing was chosen.
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: catalogPhotoExtensions);
    if (file == null) return null;
    return PickedPhoto(bytes: await file.readAsBytes(), name: file.name);
  }
}

/// Why [photo] cannot be uploaded, in the website's words, or null when it can.
String? catalogPhotoProblem(PickedPhoto photo) {
  final dot = photo.name.lastIndexOf('.');
  final ext = dot < 0 ? '' : photo.name.substring(dot + 1).toLowerCase();
  if (!catalogPhotoExtensions.contains(ext)) return CatalogWords.wrongType;
  if (photo.bytes.length > catalogPhotoMaxBytes) return CatalogWords.tooLarge;
  return null;
}
