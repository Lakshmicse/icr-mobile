import 'package:file_picker/file_picker.dart';

import 'forum_models.dart';

/// The types a discussion's file may be: the forum's upload takes a photo or a PDF.
const forumFileExtensions = ['pdf', 'png', 'jpg', 'jpeg', 'webp'];

/// Asks the phone for a photo or a PDF and reads it. Null when the reader backed out. The composer is handed a
/// picker (`NewThreadScreen.pickFile`) so a test can stand in for the phone's file chooser.
Future<ForumFile?> pickForumFile() async {
  final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: forumFileExtensions);
  if (file == null) return null;
  return ForumFile(bytes: await file.readAsBytes(), name: file.name);
}
